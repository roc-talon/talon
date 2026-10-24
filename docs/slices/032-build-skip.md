# 032 Build skip

Phase: P1. Status: done

Slice 032 is the first half of the plan row 032 (`PLAN-P1.md`): the build skip of ladder step 3 with the used-closure digest (R-BS1, R-BS2), the build id (R-ID6), the record of the result of a build in `compat.db` (every result, one row for each key and digest: section 17) (R-P4) and the line `build: skipped (recorded pass)`. The second half (the evidence lines of `why` and of the summary: R-EF3, R-CM7, R-PH12) is split as 032b, with questions, and has no test yet (section 2). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files before the slice, the stubs, the private reference and the scripts are in `research/slice-032-revert/` (`before/NEW.txt` lists the new files).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-BS1 (skip step 3 only when a row has the key (platform hash, compiler, target), a build pass, and the digest of the candidate, and no fail, hang or crash is recorded for that digest. Step 2 passed first) | `BuildSkip.decide`, `BuildFlow.before!`, `Ladder.run!`, `Ladder.verify!` | L0 `buildskip` 3. L2 `ladder/bs1-build-skip` runs 2, 3, 6, 7. L2 `bs2-build-skip-verify` runs 2, 3, 5, 6. L2 `bs3-build-record` runs 5, 6. L3 `update/bs1-build-skip` |
| R-BS2 (the digest is a hash of the sorted hashes of the used packages. An unused package is not in it. A recorded fail never allows a skip. The line `build: skipped (recorded pass)`) | `BuildSkip.digest`, `BuildSkip.decide`, `BuildSkip.skipped_line` | L0 `buildskip` 1, 3, 4. L2 `bs1` runs 2, 5, 6. L2 `bs2` run 4. L3 |
| R-ID6 (build id: resolved hashes, compiler, target) | `BuildSkip.key`, `BuildSkip.pf_hash`, `BuildSkip.target` | L0 `buildskip` 2. L2 `bs1` runs 1, 4. L3 (the two keys in `facts.tsv`) |
| R-P4 (a build result is stored with the digest, for a pass, a fail, a hang and a crash. The target is the host target. One row for each key and digest) | `BuildSkip.row`, `Facts.of_probe`, `BuildFlow.after!`, `Facts.save!`, `Db` (primary key), `RealDb` | L0 `buildskip` 4, `facts` 1, `db` (new expect). L2 `bs1` runs 1, 5. `bs2` runs 4 to 7. `bs3` all runs. `tree.diff` of the cases. L3 `facts.tsv` (5 commands) |
| R-P3 (a hang and a crash of a build are facts. A signal from outside and a process that did not start are no fact) | `BuildSkip.row`, `BuildFlow.after!` | L0 `buildskip` 4, `facts` 1. L2 `bs3` runs 2, 3, 7 |
| R-EF2 (the whole-app check always runs, `--no-probe` does not turn it off) | `Ladder.run!` (no change: step 2 is before the skip) | L2 `bs1` run 3. L3 |
| R-PH9 (P1 column: `compat.db` and the build skip) | all | all the cases above |
| R-LD5, R-LD7 (the build is step 3. A package or a platform has no build, so no skip and no record) | `BuildFlow.before!` is called only when `LadderPlan` has a build | old L2 cases `probe/un1-units` (package project), `roc/us1-use` (`roc use` makes no `platform!` call) |
| R-PP4 (a skipped build starts no probe, so it is not counted) | `Ladder.run!`, `Ladder.verify!` | L2 `bs1`, `bs2` (`probes N`), L3 (`N probes`) |
| R-NS12, R-EF1, R-CC8, R-CM11, R-LB2, R-J3, R-OUT4 | The cases above | Named in the cases |

`MISSING=1 scripts/rules.sh BS ID EF` lists R-EF3 and R-ID7 only. R-EF3 is in 032b. R-ID7 is P2.

## 2. Split of the slice (proposal, TW19)

| Part | Content | Rules | State |
| --- | --- | --- | --- |
| 032 (this file) | Build skip, the digest, the build id, the record of a build pass, the summary line | R-BS1, R-BS2, R-ID6, R-EF2, R-P4 (build), R-PH9 | tests (red) |
| 032b | The evidence lines of `why` and of the summary: the sources of R-EF1 in rank order, the precedence of R-EF3, the unit-probe note of the CLI 1 example | R-EF3, R-CM7, R-PH12 (P1 column) | questions E1 to E6 below. No test, no stub |

Why a split: the build skip is a pure decision, one command step and one record (the reference has 90 lines in `BuildSkip` and 52 in `BuildFlow`). The evidence part needs 6 decisions that the design does not state (section 12), reads `compat.db` from a query command, and may need a network read for rank 4. Both parts together are more than one review (TW19).

## 3. Flow (what the L2 cases fix)

`Ladder.run!` and `Ladder.verify!` (`probe_in_copy!`, `probe_in_place!`) do these steps for a member that has a build, after `LadderJudge.check` passed. A member with no build (a package or a platform) and `Ladder.use!` (no closure) do none of them.

| Step | Call | Rule |
| --- | --- | --- |
| 1 | `BuildSkip.pf_hash(ctx.nodes)`. `Err(NoPlatform)`: the build runs, no id, no more call (a path platform, or `roc use`: no closure) | R-ID6, R-LD7 |
| 2 | `fx.platform!()`, then `BuildSkip.key`. `Err(Unknown)`: the build runs, no id, no more call | R-ID6 |
| 3 | The scan of the used modules: `UnitFlow.scan!`, one `read_files!` for each level. It runs once for a member: when the verdict of step 1 did it (a suspect, D6 of slice 031), its result is used | R-BS2, R-UM1 |
| 4 | `BuildSkip.digest(used)`, then `Facts.load!` with the one key: one `db_query!` with `Facts([key])` (a busy db: the warning of R-CC8 and no row) | R-BS1, R-CC8 |
| 5 | `BuildSkip.decide`. `Skip`: the member gives the line `build: skipped (recorded pass)` after the line of the check. No probe, no `.last-use`, no write. Go to the next member | R-BS1, R-BS2 |
| 6 | `Build`: `UnitFlow.step!` (round 3) | R-LD5 |
| 7 | The result of the build is recorded before `LadderJudge.build` judges it (a build that stops the command is recorded too): `Probe.classify` of the output, `Probe.errors` for a fail, `BuildSkip.row`, `Facts.save!` with `existing: Replace` (one `db_write!`, `facts=1`). `Err(NoFact)` (a signal from outside, a process that did not start), and no id (steps 1 or 2 gave none): no call | R-P4, R-P3, R-BS2, R-CC8 |
| 8 | `LadderJudge.build` as before (its verdict, its lines, its failures are unchanged) | R-LD5 |

The calls of a run, in the L2 log: `platform`, `read_files` (the scan, when it has files to read), `db_query ... facts=1`, then `probes 1` with the build (or none), then `db_write ... facts=1 existing=replace` (also when the build failed, hung or crashed, and the command stops after it). `--no-check` skips the ladder, so none of this happens (R-BL6). `--no-probe` does not skip it (R-EF2).

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/BuildSkip.roc` | 73 | New. Stubs `crash "todo"` for `digest`, `target`, `pf_hash`, `key`, `decide`, `row`. `skipped_line` is `""` (a constant must not crash: roc runs it at compile time). The contract is in the docs |
| `cli/lib/BuildFlow.roc` | 36 | New. Stubs `before!` and `after!`. The doc table has the wiring that the code agent writes |
| `cli/lib/main.roc` | +2 | `BuildFlow`, `BuildSkip` in the exposed list |
| `tests/unit/buildskip.roc` | 138 | New. 4 `expect`s |
| `tests/unit/facts.roc`, `tests/unit/db.roc` | 4 rows changed or added, +11 | Changed rows of `Facts.of_probe` (section 7) and one new `expect` for the primary key (section 6) |
| `cli/lib/Db.roc`, `cli/lib/Facts.roc` | docs only | The primary key has the digest, a build keeps the digest for every outcome. The code stays as it is before the slice (section 9) |
| `tests/commands/FakeDb.roc`, `tests/tools/dumpdb.py` | small | The fake and the dump follow the new primary key and the new order of the rows |
| `tests/commands/cases/ladder/bs1-build-skip/` | 7 runs | New L2 case: `entry resolve`, 6 projects, a given `compat.tsv` with 3 rows |
| `tests/commands/cases/ladder/bs3-build-record/` | 7 runs | New L2 case: `entry resolve`, 7 projects, the record of a pass, a fail, a hang and a crash (manager review) |
| `tests/commands/cases/ladder/bs2-build-skip-verify/` | 7 runs | New L2 case: `entry commands`, the tuple of `probe/un3-verify-units` |
| `tests/scenarios/update/bs1-build-skip/` | 8 runs, 2 edits | New L3 case, the project of `update/up2-unit-flags` with 2 import lines |
| 21 old L2 cases, 11 old L3 cases | expected files | Section 7 |
| `tests/unit/facts.roc` | changed rows | Section 7 |
| `research/slice-032-revert/` | | `before/`, `stubs/`, `mutate.py` and `mutate2.py` (they need the reference, which is deleted: the lists of the changes stay as the record), `results.md`, `update-l2.sh`, `update-l3.sh`, `check-diff.py`, `check-diff3.py`, `red-*.log` |

No other file of `cli/` changed. The code agent also changes `Ladder`, `UnitFlow`, `InstallFlow`, `RemoveFlow`, `VerifyFlow`, `Facts`, `Db` and `cli/RealDb.roc` (section 9). The private reference is deleted (manager review).

## 5. Public signatures (the code agent keeps them)

| Item | Type | Rule |
| --- | --- | --- |
| `BuildSkip.System` | `{ os : [Linux, Macos, Windows, Other(Str)], arch : [X64, Arm64, Other(Str)] }` (the result of `Fx.platform!`) | R-ID6 |
| `BuildSkip.Used` | `{ hash : Str, path : Str }` (a row of `Uses.level`) | R-BS2 |
| `BuildSkip.Id` | `{ key : Db.Key, digest : Str }` | R-ID6 |
| `BuildSkip.digest` | `List(Used) -> Str` | R-BS2 |
| `BuildSkip.target` | `System -> Try(Str, [Unknown])` | R-ID6, R-HF10 |
| `BuildSkip.pf_hash` | `List(Units.Node) -> Try(Str, [NoPlatform])` | R-ID6 |
| `BuildSkip.key` | `{ pf : Str, nightly : Str, system : System } -> Try(Db.Key, [Unknown])` | R-ID6, R-P4 |
| `BuildSkip.decide` | `{ facts : List(Db.Fact), key : Db.Key, digest : Str } -> [Skip, Build]` | R-BS1, R-BS2 |
| `BuildSkip.row` | `{ key : Db.Key, digest : Str, class : Probe.Class, errors : List(Probe.Err) } -> Try(Db.Fact, [NoFact])` | R-P4, R-P3 |
| `BuildSkip.skipped_line` | `Str` (`build: skipped (recorded pass)`) | R-BS2 |
| `BuildFlow.Plan` | `{ skip : Bool, id : Try(BuildSkip.Id, [NoId]) }` | R-BS1 |
| `BuildFlow.before!` | `Fx, UnitFlow.Ctx, { used : Try(List(BuildSkip.Used), [NotScanned]) } => Try(BuildFlow.Plan, Fail)` | R-BS1, R-BS2 |
| `BuildFlow.after!` | `Fx, UnitFlow.Ctx, { id : Try(BuildSkip.Id, [NoId]), output : Probe.Output, dir : Str, pkgs : Str } => Try({}, Fail)` | R-P4, R-P3 |

`platform`, `package` and `app` are reserved words in Roc: the field of `key` is `pf`, and the function is `pf_hash`.

The exact contract of each function is in the docs of `BuildSkip` (the table of `target`, the text of the digest, the rows of `decide`).

## 6. Tests

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/buildskip.roc` 1: `digest` (8 rows) | SHA-256 vectors from `sha256sum` (the text is the sorted unique hashes, each with a line end): 2 packages, order, 2 modules of one package, the module path, a package that is not used, the byte order (a capital first), a real pair of hashes, no package | R-BS2, R-ID6 |
| L0 | `buildskip` 2: `target`, `pf_hash`, `key` (15 rows) | the 5 targets, windows arm64 and other systems have none, the platform node, no platform node, an empty closure, the key of another compiler and of another target | R-ID6, R-P4, R-LD5, R-HF10 |
| L0 | `buildskip` 3: `decide` (22 rows) | a pass with the same digest skips (also among rows of other digests, of another compiler and of other outcomes). No row, another digest, no digest (also on both sides), another platform, compiler or target, a check pass (target `any`). A fail, a hang and a crash of the digest never skip. A fail, a hang or a crash of the same digest blocks a pass of the same digest (the order of the list does not matter). A fail of another digest or of another compiler does not block | R-BS1, R-BS2 |
| L0 | `buildskip` 4: `row`, `skipped_line` (7 rows) | the row of a pass, a fail with a module of the platform (a module of the app or of another package is not one), a hang and a crash (the digest in `closure` for each), no row for a signal from outside and for a process that did not start, the text form (6 columns), the text of the line | R-P4, R-P3, R-BS2 |
| L0 | `tests/unit/facts.roc` 1 (changed rows) | a build keeps the digest for a fail, a hang and a crash (3 rows changed), a check drops it for a hang and a fail (2 rows added) | R-P4, R-P3, R-BS2 |
| L0 | `tests/unit/db.roc` (1 new `expect`) | the `fact` lines are sorted by (hash, nightly, target, closure): rows of one key with 2 digests, in any input order | R-P4, R-BS2 |
| L2 | `ladder/bs1-build-skip` (7 runs, `update` with the fake probes) | Run 1: no row, the build runs, the row is written. Run 2: an unused package moves, same digest: `build: skipped (recorded pass)`, no build probe, no write. Run 3 (`--no-probe`): the check runs, the build is skipped. Run 4: same digest on another compiler: build, a second row. Run 5: a used package moves: the build runs and its pass is a second row of the same key, the row of run 1 stays. Run 6: a pass and a fail of the same digest are in the db (hand-made): the build runs, and the new pass replaces both. Run 7: the row is a pass with no digest: build | R-BS1, R-BS2, R-ID6, R-P4, R-EF2, R-PH9, R-PP4, R-NS12 |
| L2 | `ladder/bs2-build-skip-verify` (7 runs, `verify`) | Run 1: the build runs and is recorded. The scan runs once (the verdict did it: json 2.1.0 has a unit fail). Run 2: skipped, 2 probes. Run 3 (`--json`): `data.build` is `"skipped"`, `data.check` is `"passed"`. Run 4: an app that does not import json has another digest: build, and its pass is a second row of the same key. Run 5 (p1 again) and run 6 (p2 again): both skip (two projects with one platform and compiler do not replace each other's row). Run 7: an app with another digest, the build fails for the host target: the fail is recorded, then exit 10 (the `verify` path) | R-BS1, R-BS2, R-ID6, R-P4, R-P3, R-CM11, R-LB2, R-UM1, R-J3, R-OUT4 |
| L2 | `ladder/bs3-build-record` (7 runs, `update`) | Run 1 (digest A): the build fails for the host target, exit 10: a fail row for A. Run 2 (B): the build hangs, exit 10: a hang row. Run 3 (C): the build crashes, exit 10: a crash row. Run 4 (D): the build fails: a fail row. Run 5 (D again): the fail blocks the skip, the build runs and passes: the pass replaces the fail row of D. Run 6 (D again): skip, no write (the fail, hang and crash rows of A, B, C and the given row are other digests). Run 7 (E): the build does not start (`NoFact`): exit 1, no `db_write`, no row. Digests checked with `sha256sum` | R-BS1, R-BS2, R-P3, R-P4, R-ID6, R-LD5, R-PP4, R-CC8 |
| L3 | `update/bs1-build-skip` (8 runs and 2 edits of the project file, real `Fx`) | A dry run records the build. The same run with `--json` skips (the real SQLite store, `platform!` gives `x64musl`, real reads of the scan). `update json` and `update parser` skip (parser is not imported). `verify` has another platform hash: build, a second row. `verify --json` skips. The app drops the import of json (a comment line): the digest is new for the key of `verify`, so the build runs and its pass is a second row of the same key. The import is back: `verify` skips (the first digest of the key is still recorded). `facts.tsv` has 3 build rows, 2 with the same hash, compiler and target (digests checked with `sha256sum`): the old primary key of the real SQLite store fails this. `roc.log` has 3 builds | R-BS1, R-BS2, R-ID6, R-P4, R-EF2, R-CM11, R-OUT4 |

Counts: 4 L0 `expect`s in `buildskip.roc` (52 rows), 1 new `expect` in `db.roc`, 5 changed or new rows in `facts.roc`, 3 deep L2 cases (21 runs) and 1 L3 case (8 runs). The brief asks for about 5 to 20 L0 `expect`s: the pure part of this half is small, so it has 4.

## 7. Changes of old tests (on purpose, TW21)

A build result is recorded now, and a later run with the same key and digest skips a recorded pass. So the calls, the printed probe count, the build line and the file tree of old cases change. The scripts are `research/slice-032-revert/update-l2.sh` and `update-l3.sh`. Each one saves the old `expect/` to `before/`, writes the new one, and `check-diff.py` (`check-diff3.py` for L3) lists each changed line that is not of an allowed kind. I read the other changes (the L3 rows with fake `roc` lines in stdout) by hand.

| Kind of change | Where |
| --- | --- |
| `calls.log`: the lines `platform`, `db_query ... facts=1`, `db_write ... facts=1 existing=replace` for each member that has a build, `read_files` of the scan when the app has imports. Fewer lines: the build probe of a skip (and its `env` line and `.last-use`) | 21 L2 cases |
| `tree.diff`: the build row `fact <platform hash> <compiler> x64musl <outcome> <modules> <digest>` in `compat.tsv` (a pass, and a fail, hang or crash for a build that stopped the command), and the hunk header | 21 L2 cases (`ladder/ld-ladder-flow` has a fail row for its failed build) |
| `stdout`, `stderr`: `build: skipped (recorded pass)` for `build: passed` of a later run with the same key, and the printed probe count | 15 L2 cases |
| `facts.tsv`, `roc.log` (fewer `build` lines), `stdout`, `stderr` | 10 L3 cases (`add/ad1`, `add/ad2`, `compilers/dl1`, `dl3`, `pb1`, `remove/rm1`, `rm2`, `update/up1`, `up2`, `verify/vf1`) and `compilers/dl2-consent-tty` (stdout only) |

Old L0 tests changed on purpose: `tests/unit/facts.roc` (3 rows: a build fail, hang and crash keep the digest, the old rows said they have none). Old L2 cases changed in the manager review round: `ladder/ld-ladder-flow` and `remove/rm1-flow` (the fail row of a failed build, the new rows of the primary key). Old L3 cases: none more. Fake and tool: `tests/commands/FakeDb.roc` (`same_row` has the digest), `tests/tools/dumpdb.py` (the sort has the digest).

Changes of the input of 2 old L2 cases (old files are in `before/`):

| Case | Change | Reason |
| --- | --- | --- |
| `ladder/ld-ladder-flow` | `given/project/p6`, `p7`: one line `import pf.Std`. `p8`: `import pf.Std` and `import json.Parser` | The 9 runs use one compiler and no app has an import, so one build pass (run 1) made each later build a skip. Run 6 (the build fails for the host target) and run 7 (the build has the errors of the baseline) test the build, so they need a digest that no earlier run recorded. The expected output of the 9 runs is the same, with the new calls |
| `install/in1-flow` | `fx/hooks`: `after-probes 8` is `after-probes 7` | The hook fires after the n-th `probes` call. The 2 builds that are skipped in the runs before it make the count 1 smaller (the hook fires after the check of the same run, so the exit 17 case stays) |

## 8. Output (proposed, TW24, R-OUT2)

| Text | Where |
| --- | --- |
| `build: skipped (recorded pass)` (the words are the design, R-BS2). One line after `check: passed`, with the file path in front for 2 or more members, as `build: passed` | `BuildSkip.skipped_line` |
| `resolved at <time>, <n> probes`: `n` does not count a skipped build (R-PP4) | `Ladder.run!`, `Ladder.verify!` |
| `--json` `data.build` is `"skipped"` when every app member skipped the build, `"passed"` when one built, null when no member is an app. `"skipped"` has 2 reasons: `--no-check` (then `data.check` is `"skipped"` too) and a recorded pass (`data.check` is `"passed"`). A program tells them apart by `data.check` | `Report.Outcome.build` (`Skipped`), `build_state` of the 3 flows |
| `compat.db` row of a build pass: `fact <platform hash> <compiler> <target> pass <empty modules> <digest>` | `BuildSkip.row` |

The doc of `Report` says that `Skipped` is `--no-check`. The code agent adds the second reason there.

## 9. Notes for the code agent

| # | Note |
| --- | --- |
| 1 | `BuildSkip` and `BuildFlow`: write the bodies. The private reference is deleted. The contract is the docs and the tests (TW18) |
| 2 | `UnitFlow.verdict!` gives `{ used : Try(List({ hash : Str, path : Str }), [NotScanned]) }`: `Ok` when it did the scan, else `Err(NotScanned)`. `Ladder` passes it to `BuildFlow.before!` |
| 3 | `Ladder.run!`, `Ladder.verify!`: the steps of section 3 in `probe_in_copy!` and `probe_in_place!`. `Ran` and the results of `run!` and `verify!` get `skipped : U64`. `Ladder.use!` stays: it has no closure, so no call |
| 4 | `InstallFlow`, `RemoveFlow`, `VerifyFlow`: `build` of the outcome is `NotRun` with no app member, `Skipped` when each app member skipped, else `Passed` |
| 5 | `Crypto.SHA256.hash(text.to_utf8()).to_hex()` gives the digest (a builtin, no import). The pure `Str` helpers `Text.sorted_unique` sorts by byte order |
| 6 | Manager review: `Facts.of_probe` keeps `closure` for a build in every class (a fail, a hang, a crash). `Db.fact_order` has `closure` as the fourth key. `cli/RealDb.roc`: the primary key is (`hash`, `nightly`, `target`, `closure`) and the upsert is `ON CONFLICT(hash, nightly, target, closure)`. The tests `facts` 1, `db` 7, the L2 cases and the L3 case `update/bs1-build-skip` fix these |
| 7 | `BuildFlow.after!` runs before `LadderJudge.build` (the order of section 3), in `probe_in_copy!` and in `probe_in_place!` |
| 8 | Compiler limits met by the reference: `platform` is a reserved word (also as a field), a local `target` inside `BuildSkip` is a duplicate definition of the method `target`, a constant `if` is a warning and `roc build` exits 2 on a warning |

## 10. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The digest text is the sorted unique hashes of the used modules, each followed by `\n`. The digest is the SHA-256 of its UTF-8 bytes, 64 lowercase hex digits. The platform counts when the app imports one of its modules, as any package | A hash of the sorted list with a separator; the platform always in it; the module paths in it |
| D2 | One more `db_query!` for the one build key, after step 2 and the scan. The first query of the ladder stays as it is | The build key in the first query (it needs `platform!` before step 1, and changes the `facts=N` of each ladder run, also for a package) |
| D3 | The scan of the used modules runs for each member that reaches the build, also when no unit fail needs it. It runs once for a member: the result of the verdict is reused | A scan only for a suspect (the digest needs it); a second scan |
| D4 | The host target is a name of `BuildSkip.target`: `x64musl`, `arm64musl`, `x64mac`, `arm64mac`, `x64win` (the 5 targets of R-HF10). Another system has no key: the build runs and nothing is recorded | The asset names of R-CV8 (`linux_x86_64`: they name a compiler, not a build target); `x64glibc` for Linux; a failure for an unknown system |
| D5 | (Manager review: changed.) Every result of a build that started is recorded, with the digest: a pass, a fail, a hang and a crash. `NoFact` is not. The row is written before `LadderJudge.build` judges the output, from the class of the probe (`Probe.classify`), so a build that has the errors of the baseline (judged as a pass) is a `Fail` row and never skips | Only a pass (the first draft) |
| D6 | (Manager review: changed.) One row for each key and digest: the primary key of `facts` is (hash, nightly, target, closure). The row is written with `existing: Replace`, so a later result for the same digest replaces the old one. A key can have more than one build row | One row for each key (the first draft: two projects replaced the digest of each other); `Keep` |
| D7 | A member with no platform hash (the platform is a path entry or a foreign URL) and a run with no closure (`roc use`, `Ladder.use!`) have no key: no `platform!` call, no query, no record, the build runs | A skip with a key of the path |
| D8 | A skipped build starts no probe: it is not counted, and `.last-use` is not touched for it | A count of 1 |
| D9 | `data.build` is `"skipped"` for a recorded pass (section 8) | A new word `"recorded"` (it needs a new tag in `Report.Outcome`) |
| D10 | A new L2 case for `verify` (`bs2`), and the old cases of `update`, `remove` and `install` cover the other flows | One case for all |

## 11. Questions (TW17)

| # | Question | Default in the tests |
| --- | --- | --- |
| Q1 | R-LD5 and R-P4 say "the host target" and give no name. R-T8 says that `roc build` with no `--target` uses the musl target of the platform, else its glibc target, so a platform with a glibc target only builds for `x64glibc` while the key says `x64musl`. Which name goes in the key? | D4: the 5 names of R-HF10. A platform with another target is a gap |
| Q2 | (Answered by the manager: record the result for a pass and a fail, and a hang and a crash as their R-P3 facts. A fail, hang or crash row for the key and digest blocks the skip. A fail with errors only in app files blocks only that digest, because the row has the digest.) | D5 |
| Q3 | (Answered by the manager: one row for each (key, digest), so two projects with the same platform and compiler do not replace each other's row. Skip only when a pass row with the same digest exists and no fail row for that digest.) | D6 |
| Q4 | Does `tln roc use` skip the build? R-U3 says steps 2 and 3. `roc use` has no closure walk, so it has no used modules | D7: no. It builds as before and records nothing |
| Q5 | R-BS2 counts "their patches and overrides" in the digest. Patches are slice 042 | An override changes the hash of its entry, so it is in the digest. Patches: slice 042 |
| Q6 | R-BS1 condition 3 says "step 2 passed for the candidate with no new errors". An app that has errors the same as the baseline passes step 2 (R-P6). May that candidate skip? R-BS2 says that a skip does not claim that the source builds | Yes for the skip rule (it only looks at the key and the digest). But a build with the errors of the baseline is recorded as a `Fail` row (D5), so it never skips. The old case `ladder/ld-ladder-flow` run 7 shows the row |

Design gaps found:

| Gap | Where |
| --- | --- |
| R-BS1 and R-BS2 do not name the target string of the key (Q1) | Resolution 4 |
| R-P4 says one row for each key and that the closure is for a build pass only. The review decides one row for each (key, digest) and the digest for every build result. R-P4 and the schema text of Resolution 4 and `DESIGN-REGISTRY.md` need this change (the manager) | Resolution 4 |
| The primary key is part of format 1 (R-TF1). A `compat.db` that an older Talon made has the old key (`CREATE TABLE IF NOT EXISTS` keeps it) and its upsert fails with the new `ON CONFLICT`. Nothing is released, so format 1 stays. Question for the manager: bump to format 2, or leave it | R-TF1, R-TF2 |
| `Report.Outcome.build` `Skipped` has 2 reasons now (section 8) | CLI 3 catalog |
| R-EF1 says `fail(error digest)`, and R-P4 stores the failing modules only. The CLI 1 example note has the error title (`redundant expose`). Facts do not hold it (E4) | Resolution 3, Resolution 4, CLI 1 |

## 12. Part 032b: evidence (questions only, no test, no stub)

R-CM7 asks `tln why X` for "why this version (evidence)". R-PH12 puts the evidence in P1. R-EF3 gives the precedence of the sources of one pair. The design has no text and no field for it (R-OUT2: a proposal), but it has facts to decide, so these are questions.

| # | Question | Proposal (not a decision) |
| --- | --- | --- |
| E1 | Which compiler does the evidence of `why` use? `why` makes no compiler call and no selection today (slice 011, Q24) | The `roc:` pin of the member header. With no pin: no evidence block |
| E2 | May `why` read `compat.db` (one `db_query!`, with the warning of R-CC8)? Today `why` writes only `projects.json` | Yes, one query for the key (hash, compiler, `any`) of the package. A busy db: the warning, no local row |
| E3 | Which sources does P1 show with `direct` (R-EF1 ranks 1, 3, 4, 5; ranks 2 and 6 need the registry)? Rank 3 is the `roc:` pin in the release header (the walk read the header). Rank 4 is `.roc-version` at the tag (`Github.hint!`: a network read). Rank 5 is the release date (the index) | Ranks 1 and 3. Rank 4 only from the cache of an earlier `Github.hint!` call: `why` makes no new request. Rank 5: no (`why` makes no index call, R-DI1) |
| E4 | The CLI 1 example note is `note: module Yaml fails on <compiler> (redundant expose). Your app does not import it.` The fact stores the failing modules only (R-P4), not the title. Which text? | `note: module Yaml fails on <compiler>. Your app does not import it.` (no title). The other way is a new column `error` in `facts` (R-TF2 allows it), which is a schema change |
| E5 | Where is the unit-fail note printed? The CLI 1 example is a P2 example (it also has the short name and the `log:` snapshot) | In the summary of `install`, `add`, `update`, `upgrade` and `verify`, after the build line, for each unit fail that the used-module scan ignored (R-UM1), and as an evidence line of `why` |
| E6 | R-EF3: a rank 1 fact and a rank 3 hint for one pair. The fact wins. May `why` print both, with the winner marked? | Print each source that has a value, in rank order, and mark the first with `*`. `--json`: `data.members[].evidence` is a list of `{ rank, source, result }` |

Plan for 032b: after the answers, `Evidence.of_pair` (pure: the sources of a pair to the sorted lines), `Why.text` and `Why.data` get the block, one L0 file, and one L2 case that extends `closure/cl2-chain` with a seeded `compat.tsv`.

## 13. Out of scope

| Rule or part | Reason |
| --- | --- |
| R-EF3, R-CM7 (evidence), R-PH12 (P1 column) | Part 032b (section 12) |
| Patches in the digest (R-BS2 "their patches") | Slice 042 and 043: there is no patch yet |
| The build skip in `tln roc use` | Q4. `roc use` has no closure |
| The smoke build (R-SM3, R-SM4: "also when it used the build skip of R-BS1") | P2 (sharing). The smoke result is not evidence for the skip (R-SM4) |
| A build of a tool (R-T21, R-B5) with the key (app hash, compiler, target) | Slices 046 to 049 |
| R-BS1 with a registry (`bot` rows of rank 2) | R-BS1 reads `compat.db` only. The registry is P2 |
| A real nightly build on the real `Fx` and the real `roc` (L4) | The L3 case uses the fake `roc`. The `real-roc` runs are for slice 053 |

## 14. Red output

Run with the stubs in the tree and the private reference deleted (manager review round, 2026-10-23: `research/slice-032-revert/red-run.log`, `red-l0.log`, `red-l2.log`, `red-l3.log`).

| Step | Result |
| --- | --- |
| check | pass (1.9 s) |
| fmt | pass |
| l0 | FAIL (5.7 s): `buildskip` 4 of 4 fail (`todo`), `db` 1 fail (the new `expect`: the old order has no digest), `facts` 1 fail (the changed rows). All other files pass |
| l2 | FAIL (3.7 s): 53 passed, 24 failed: the 3 new cases (`ladder/bs1-build-skip`, `bs2-build-skip-verify`, `bs3-build-record`) and the 21 old cases of section 7 (a wrong value: the old code builds each time and records no build) |
| l3 | FAIL (9.8 s): 48 passed, 12 failed, 1 skipped: `update/bs1-build-skip` and the 11 old cases of section 7 |
| selftest | pass (8.0 s) |

All other old tests pass. Budgets (TW26): check 10, l0 10, l2 30, l3 60, selftest 20: all inside. With the reference in the tree, `scripts/test.sh` exited 0 before it was deleted (`research/slice-032-revert/green-run.log`).

## 15. Revert check (TW12)

First round: 37 changes, one at a time, of the private reference (`research/slice-032-revert/mutate.py`, list and result in `results.md`): 37 caught. 2 were not caught at first, and each got a test row: b11 (a pass with no digest skips when the digest of the candidate is empty too: a row in `buildskip` 3), f16 (`install` and `update` give `build: Passed` for a skip: `update/bs1-build-skip` got a `--dry-run --json` run). The independent check of the digests: 4 values in the expected files and in `buildskip` were computed with `sha256sum` of the text of D1.

Manager review round: 19 changes of the changed rows (`research/slice-032-revert/mutate2.py`, table in `results.md`): 19 caught. n12 (the record after the verdict, in the `verify` path) was not caught at first: run 7 of `bs2-build-skip-verify` was added. The digests of `bs3` (A to E), of run 7 of `bs2` and of the new rows of the L3 case were computed with `sha256sum`. The entries b9 to b16, f14 and f15 of the first round are replaced by n1 to n5, n9, n11, n12 and n16 to n19.

| Group | Changes | Caught by |
| --- | --- | --- |
| `BuildSkip` (digest, target, platform, key, line) | b1 to b8, b12 to b14, b17 | L0 `buildskip` |
| `BuildSkip.decide`, `BuildSkip.row` | n1 to n5, n16 to n19 | L0 `buildskip` |
| `Facts.of_probe`, `Db.fact_order` | n6 to n8, n13 | L0 `facts`, `db` |
| `BuildFlow` (no call without a platform, the scan once, the key of the query, the digest, `Replace`, `Keep`, only a pass) | f1 to f6, f12, f13, f19, n9, n10 | L2 `bs1`, `bs2`, `bs3`, `consent/dl1-resolve`, `resolve/rs-highest-use` |
| `Ladder` (count of a skip, the skip itself, the line, the record after the verdict) | f8a to f10b, n11, n12 | L2 `install/in1-flow`, `bs2`, `bs3`, `consent/dl2-verify-workspace` |
| The flows (`build` of the outcome) | f11, f16, f17 | L2 `bs2`, L3 `update/bs1-build-skip`, `remove/rm1-remove-entries` |
| `RealDb`, `FakeDb` (the primary key) | n14, n15 | L3 `update/bs1-build-skip`, L2 `bs1` |

## 16. Next step

The code agent writes `BuildSkip`, `BuildFlow`, the wiring of section 9 and the changes of `Facts`, `Db` and `cli/RealDb.roc` (note 6 of section 9). The tests are red (section 14). 032b (section 12) has its own scope step.

## 17. Review (manager, 2026-10-23)

The manager accepted the split (032 build skip, 032b evidence with E1 to E6, which the manager adds to `PLAN-P1.md`), D1 to D4, D7 to D9, the output proposals, the changes of old tests and old inputs, and the defaults of Q1 (D4: a glibc-only platform stays a recorded gap), Q4, Q5 and Q6. Two changes:

| # | Change | Done |
| --- | --- | --- |
| 1 | Q2 and D5: R-BS2 says "a recorded fail never allows a skip", so a build fail is recorded. Record the build result for a pass and a fail, and a hang or a crash as their R-P3 facts. A fail, hang or crash row for the key and digest blocks the skip. A fail with errors only in app files blocks only that digest, because the row has the digest | `BuildSkip.row` (new signature with the class and the errors), `BuildSkip.decide` (the rows of the digest decide, a fail, hang or crash blocks), `BuildFlow.after!` (new signature, before the verdict of the build), `Facts.of_probe` (a build keeps the digest for every class), L0 `buildskip` 3 and 4, `facts` 1, L2 `bs3-build-record`, `bs2` run 7 |
| 2 | Q3 and D6: one row for each (key, digest), not one for each key, so two projects with the same platform and compiler do not replace each other's row. Skip only when a pass row with the same digest exists and no fail row for that digest. `bs2` run 4 shows both projects skip on their second run | The primary key of `facts` is (hash, nightly, target, closure): `Db` docs and `Db.fact_order`, `cli/RealDb.roc`, `FakeDb`, `dumpdb.py`, L0 `db`, L2 `bs2` runs 4 to 6 and `bs1` runs 5 and 6, L3 `update/bs1-build-skip` (2 edits, 2 runs) |

Consequences that the review has to confirm:

| # | Consequence |
| --- | --- |
| C1 | A build with the errors of the baseline (`LadderJudge.build` gives a pass) is recorded from the class of the probe: a `Fail` row. It never skips. The old case `ladder/ld-ladder-flow` run 7 shows it |
| C2 | The schema change is in format 1 (section 11, design gaps). R-P4 and the schema text in the design files have to change (the manager) |
| C3 | `Facts.index` is by key and has one row for a key: it is for the check facts. The build rows of a key are read by `BuildSkip.decide` from the query |

The private reference (`research/slice-032-revert/reference/`) and `swap.sh` are deleted. `scripts/test.sh` shows the red state of section 14. No background process runs.

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Code result

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/BuildSkip.roc` | 108 | Bodies of `digest`, `target`, `pf_hash`, `key`, `decide`, `row`, and the text of `skipped_line`. `row` calls `Facts.of_probe` (no copy). New pure helper `state` (see decisions) |
| `cli/lib/BuildFlow.roc` | 71 | `before!` (steps 1 to 5 of section 3) and `after!` (step 7) |
| `cli/lib/Ladder.roc` | 362 | New `build_round!` (one function for `probe_in_copy!` and `probe_in_place!`: `before!`, skip or step, `after!` before `LadderJudge.build`). `Ran`, `run!` and `verify!` have `skipped : U64` |
| `cli/lib/UnitFlow.roc` | 153 | `verdict!` gives `{ used : Try(List(..), [NotScanned]) }` (note 2) |
| `cli/lib/InstallFlow.roc`, `RemoveFlow.roc`, `VerifyFlow.roc` | 519, 318, 141 | `build` of the outcome is `BuildSkip.state` (note 4), +1 import each |
| `cli/lib/Facts.roc` | 234 | `of_probe`: a build keeps `closure` for Fail, Hang and Crash (note 6) |
| `cli/lib/Db.roc` | 239 | `fact_order` has `closure` as the fourth key |
| `cli/RealDb.roc` | 248 | primary key (`hash`, `nightly`, `target`, `closure`), `ON CONFLICT(hash, nightly, target, closure)`, `closure` is no longer in the `DO UPDATE SET` (it is the key) |
| `cli/lib/Report.roc` | 190 | Docs only: the second reason of `Skipped` for `build` (section 8) |

Decisions that the slice does not fix (the signatures of section 5 are kept; one pure function is added):

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | New `BuildSkip.state : { apps : U64, skipped : U64 } -> [Passed, Skipped, NotRun]` for note 4 (no app: `NotRun`, each app skipped: `Skipped`, else `Passed`). The 3 flows share it | The same `if` in 3 flows |
| C2 | `build_round!` is one private function in `Ladder`, used by both probe functions. It takes `compiler` and `timeout` from `ctx` (`held`, `probe.timeout`: the same values as before) | A copy of the block in each probe function |
| C3 | `BuildFlow.before!` takes the nightly of the key from `ctx.started.id` (the compiler that runs the ladder, R-NS12) | `ctx.held` (it is a message id, equal in the tests) |
| C4 | `BuildFlow.after!` calls `Probe.errors` for every class and `BuildSkip.row` uses the errors only for a fail | A call only for a fail (more code, no gain) |
| C5 | `UnitFlow.verdict!` gives `Err(NotScanned)` when there was no suspect. `Units.judge` gets `scanned ?? []` as before | A second scan |

Test result: `scripts/test.sh` exit 0 (dev): check 1.5 s, fmt 0.1 s, l0 6.1 s (68 files), l2 1.5 s (77 cases), l3 9.7 s (60 passed, 1 skipped), selftest 8.0 s. `OPT=speed scripts/test.sh`: exit 0 (l2 88.9 s: LLVM build, the budgets are for dev). L3 `fx/db1`, `fx/db2`, `update/bs1` 3 times in a row: 3 of 3 pass each time. Not run: a real `roc` build (L4, section 13).

Compiler limits met: `SHA256` is `Crypto.SHA256` (no import). A `verdict` that no code reads is a warning, so a mutation must read it (the mutation list has this).

## Verify results

Revert check (TW12): 58 small changes, one at a time, in the final code (`research/slice-032-revert/agent-mutate.py`, result in `agent-results.md`, log in `agent-mutate.log`). The final code is in `code-final/`: each file is restored before and after each run, and at the end `cmp` shows that all 11 files are the same as before. The steps of a change: L0 file for the pure code, else `l2` then L3 `update/bs1`. Caught 51 of 58. 3 changes did not compile at first (an unused `verdict`: a warning) and were redone as l6, l7, l12.

| Group | Changes | Caught by |
| --- | --- | --- |
| `BuildSkip` pure (digest, target, pf_hash, key, decide, row, line) | b1 to b17 (17) | L0 `buildskip` |
| `BuildSkip.state` | b19 | L2 `gaps/g1-slice009`. b18 not caught |
| `BuildFlow` | f1 to f7, f10, f11 (9) | L2 `resolve/rs-highest-use`, `ladder/bs2`, `consent/dl1-resolve`, `dl2-verify-workspace`, `probe/pb1-ladder` |
| `Ladder`, `UnitFlow` | l1 to l5, l7 to l14 (13) | L2 `bs2`, `bs3`, `install/in1-flow`, `consent/dl1-resolve`, `probe/un1-units`, `gaps/g1-slice009`. l9 by L3 `update/bs1` |
| Flows | w2, w4, w5, w6 | L3 `update/bs1`, L2 `bs2`, `gaps/g1-slice009`, `remove/rm1-flow` |
| `Facts`, `Db`, `RealDb` | n1 to n7 | L0 `facts`, `db`. L3 `update/bs1` for the key of `RealDb` |

Changes that no test caught (all are test gaps, not equivalent changes; the code agent does not edit tests, TW18):

| Id | Change | Why no test sees it | Proposed test |
| --- | --- | --- | --- |
| b18 | `BuildSkip.state`: `skipped >= apps` is `skipped > 0` | No flow case has 2 app members where only one skips | L0 row for `state` (apps 2, skipped 1: `Passed`), and an L2 `verify` run with 2 apps |
| w1 | `InstallFlow`: `apps` is `members.len()` | No `install` or `update` case with a package member (build `NotRun`) or a mix | L0 `state` row plus an L2 `update` run on a package project that checks `data.build` null |
| w3 | `RemoveFlow`: `skipped` is 0 | A `remove` run that skips the build shows no `build` state (`--json` is not in a case) | An L2 `remove --json` run after a recorded pass: `data.build` is `"skipped"` |
| l6 | `Ladder.probe_in_copy!` throws away the scan of the verdict (a second scan) | The only case where the verdict scans (a unit fail) is the `verify` case `bs2` (the `place` path, l7 is caught) | An L2 `update` run with a suspect (a unit fail of a package that the app does not use) and a build: one `read_files` for the scan |
| f8, f9 | `BuildFlow.after!`: `Probe.errors` with no text, or with `pkgs` as `dir` | No case has a failed build with an error in a file of the platform package, so `modules` of the fail row is always empty | An L2 run in which the build fails in a module of the platform: the fail row has `modules` |
| n8 | `RealDb`: `outcome` is not in `DO UPDATE SET` | The L3 case writes only passes. A replace of another outcome for the same digest is only in L2 (the fake db) | An L3 run with a fail row of a digest and then a pass of the same digest (as `bs3` run 5) and `facts.tsv` |

Questions (TW17): none new. The format question of section 11 (bump to format 2 or not) is answered by the manager: format 1.

## Gap rows (test agent)

Tests only, no `cli/` edit. Each mutation of `agent-mutate.py` was applied by hand (`research/slice-032-revert/gap-mutate.py`), the new test failed, and the file was restored (`cmp` and `sha256sum -c` against `code-final/`: all 11 files the same). Only the one test that must see the change ran for each.

| Gap | Layer | New test | Result of the mutation |
| --- | --- | --- | --- |
| b18 | L0 (a pure function) | `tests/unit/buildskip.roc` 5: `BuildSkip.state` (8 rows: no app, 1 app built or skipped, 2 apps with none, one or both skipped, 3 apps with 2 skipped) | caught |
| w1 | L2 | `ladder/bs2-build-skip-verify` run 10: `update --json` on a package project, `data.build` is null | caught |
| w3 | L2 | `bs2` run 11: `remove parser --json` after a recorded pass of the same digest, `data.build` is `"skipped"` | caught |
| l6 | L2 | `bs2` run 8: `update json --json` where json 2.1.0 has a unit fail (a suspect) and the build runs: one scan (`read_files`) in the `update` path (the copy), `data.build` is `"passed"`. Run 9: the same digest, `"skipped"` | caught |
| f8, f9 | L2 | `ladder/bs3-build-record` run 8: the build fails in `Std.roc` of the platform (fixtures `fx/build-platform.stdout` and `.stderr`): exit 10, the fail row has the module `Std.roc` | caught (both) |
| n8 | L3 (the real SQLite store) | new case `update/bs2-build-fail-replaced` (3 runs, the fake roc rule is changed between runs): a failed build is recorded, a pass of the same digest replaces it (`facts.tsv` has the pass row), the next run skips. 3 runs of the case: 3 of 3 pass | caught |

The L2 and L3 cost is small: 4 runs added to `bs2`, 1 run added to `bs3`, one L3 case (about 4 s with the other cases in parallel). `scripts/test.sh`: exit 0, no WARN (`research/slice-032-revert/gap-green.log`: check 1.4 s, fmt 0.1 s, l0 6.1 s, l2 1.6 s, l3 9.8 s, selftest 8.0 s). No background process runs.

## Close (manager, 2026-10-23)

C1 to C5 of the code agent are accepted. The 7 uncaught mutations (b18, w1, w3, l6, f8, f9, n8) are caught by the gap rows. `scripts/test.sh` exits 0 with no WARN. 032b (evidence) is its own row. Status: done.
