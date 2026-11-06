# 209b Bot smoke results in the ladder

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 209b of `PLAN-P2-CLI.md`. Slice 209 gives a `bot` smoke row only as a rank 2 fact of its target (`Matrix.rows`, `Matrix.real`). This slice uses it in ladder step 3 (R-SM6 row 1): a `bot` smoke `fail` is a step 3 fail with no build. The second half of the row, the learned interval for the target, is answered by Design Q557 to Q559 (round 2 below).

## Rules

R-SM6 (rows 1, 2, 3), R-LD5, R-LD6, R-EF3, R-TG2. As used: R-BS1, R-LD8, R-CV1, R-P4, R-PH10, R-AL6, R-E1, R-PP4.
Design: Resolution 4 R-SM6, R-LD5, R-TG2; Resolution 3 R-EF3; Registry R-MX10 (the bot rows).

## Scope

| In | Out (where) |
| --- | --- |
| Ladder step 3 (`Ladder.build_round!`, for `update`, `install`, `verify`): after `BuildFlow.before!` knows the build key (platform hash, compiler, target), a `bot` smoke `fail` row of the answer for that key is a fail of step 3 with no build probe | The learned interval (R-EP7) for the target: question Q1 |
| `Matrix.smoke_fail` (pure, new): the decision on the rows | A `hang` or `crash` row: question Q2. A local build row (R-BS1, R-P4) against a `bot` smoke `fail`: question Q3 |
| A smoke `pass` and a row of another target or compiler change nothing (R-SM6 rows 2 and 3) | `tln outdated` and `tln add --platform` show a row of another target (R-SM6 row 3): not in the plan row |

## The flow as I read it

| # | Item | Reading |
| --- | --- | --- |
| 1 | Where the rows are | The `runs` and `nearest` of the closure answer (`Ladder.Loop.answer`, `Ladder.VerifyRequest.answer`, slice 206e3b). `Matrix.rank2` already gives the rows of given keys, but the oracle and `known_facts!` ask only for keys of the target `any`, so a smoke row of a real target is read by nobody today (`Matrix.rank2` `wanted`) |
| 2 | Where the target is known | Only in step 3: `BuildFlow.before!` reads the platform (`platform!`), the header of the platform release, `BuildTarget.pick` and `BuildTarget.key`. The key target is `[build] target`, else the host target, else the one target; with no `targets` list in the header (`Unlisted`) it is the host target (`x64musl` on the fake). The smoke row has the key (platform hash, compiler, that target) (R-TG2) |
| 3 | The decision (R-SM6 row 1) | A `bot` row `fail` of that key (the compiler by `PinOrder.same_id`, R-CV1; a `bot` row wins over an `author` row, R-EF3; the target of the row is equal, so a unit row of the target `any` is no smoke row) is a fail of step 3. `Matrix.smoke_fail` decides |
| 4 | What the fail is | The failure of step 3 for the platform (R-LD5): `Fail.of_tuple` with the platform hash as the blamed hash, as `LadderJudge.build` does for an error that no file owns. It has kind `NoTuple` (exit 10). In `update`, `install` and `upgrade` the tuple is dropped (`note: tuple dropped: ...`, `InstallFlow.attempts!`) and the search runs again. In `verify` the command stops (exit 10) |
| 5 | No build | No build probe, so no `probes` call, no `.last-use` touch for it, and the probe count does not grow. No fact is recorded: `BuildFlow.after!` is not called, because no build ran (R-P4: a recorded row is the result of a run) |
| 6 | What stays before the decision | The calls of `BuildFlow.before!` stay as they are today: `platform`, the read of the header of the platform release, one `db_query` of the build key. They give the target and the key that the smoke row needs. The test fixes this (doubt D1) |
| 7 | A smoke `pass` (R-SM6 row 2) | Not a pass of step 3. The build runs, or the build skip of R-BS1 applies, as with no row |
| 8 | A row of another target or compiler (R-SM6 row 3) | Not used by the resolve |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | (round 2) `MatrixTest`: `smoke_checks`: no row, 3 compilers with a fail (3 `Fail` checks, no module, `Real`, in order), a crash (`Crash` check), pass and hang give none, author only, R-EF3 both ways, another target and the unit target `any`, another hash, 2 tag forms of one compiler (one check). `smoke_fail` also: a bot crash is a row, a bot hang is none, a bot crash over an author pass, a bot hang over an author fail | R-SM6, R-EP7, R-UM1, R-EF3, R-CV1, Q557, Q558 |
| L2 | (round 2) `registry/sm6-interval` (1 run): `upgrade roc --dry-run` of `ef1-rank2-free` plus a bot smoke `fail` of pf 0.1.0 (`x64musl`) from 10-12 to 10-16, the 3 compilers of the list. One drop on N at step 3 (no build probe, no touch, no build fact), then the learned interval leaves no compiler: no second ladder run, exit 10, first failure | R-SM6, R-EP7, R-UM1, R-LD5, R-AL6, Q557 |
| L2 | (round 2) `registry/sm6-local-pass` (1 run): as `sm6-bot-fail`, with a local build `pass` of the key in `compat.tsv` (digest `abab...`). Step 3 runs the build (no skip: the digest differs) and passes; exit 0; the tree has the 2 rows of the key | R-SM6, R-EF3, R-P4, R-BS1, Q559 |
| L0 | `tests/unit/MatrixTest.roc` (driver `l0-5.roc`): `smoke_fail`: a bot fail gives the row (also with a null digest), no row, an author fail only, a bot pass, a bot pass over an author fail, a bot fail over an author pass, another target, the unit target `any`, another compiler, another hash, the other tag form of the compiler, the first bot row of 2 | R-SM6, R-EF3, R-CV1, R-TG2 |
| L2 | `registry/sm6-bot-fail` (1 run): `verify` of `ef1-rank2-verify` plus a `bot` smoke `fail` of pf 0.1.1 (target `x64musl`, digest `undefined symbol: roc_alloc`, from 10-12 to 10-16, so it covers H). Exit 10, no build probe, no build fact, the proposed text on stderr | R-SM6, R-LD5, R-LD6, R-EF3, R-TG2, R-E1 |
| L2 | `registry/sm6-bot-fail-update` (1 run): `update json --dry-run` of `ef1-rank2-ladder` plus a `bot` smoke `fail` of the held pf 0.1.0. The first tuple is dropped with no build probe (`note: tuple dropped: ...`), the second search moves pf to 0.1.1 (held move), and its build runs and passes (exit 0, `6 probes`). Nothing is written | R-SM6, R-LD5, R-AL6, R-PH10, R-TG2 |
| L2 | `registry/sm6-pass-builds` (1 run): a `bot` smoke `pass` of pf 0.1.1, and the fake build fails: the build probe runs and its fail stops the command (exit 10, the real title, the build fact is recorded) | R-SM6, R-LD5, R-BS1 |
| L2 | `registry/sm6-other-target` (1 run): a `bot` `fail` of the target `arm64mac` that covers H, and a `bot` `fail` of `x64musl` that ends before H. The build runs and passes (exit 0) | R-SM6, R-TG2, R-LD5 |

The cases are made by `research/slice-209b-revert/mkcases.py` (from `ef1-rank2-verify` and `ef1-rank2-ladder`; each case has a `rules` file with the detail). It deletes the dirs of these cases: do not run it again after the expect files exist (they are made by hand, below). `before/` has `Matrix.roc` and `MatrixTest.roc` as they were before the stub and the new `expect`.

### How the expect files were made

No private reference was built. `UPDATE=1 tests/commands/run.sh registry/sm6` ran once on the current code (no row changes anything today), then the files were edited by hand to the rules:

| Case | Hand edit |
| --- | --- |
| `sm6-bot-fail` | `stdout` is the one of `sm6-pass-builds` (the note, then `exit 10`: a failed verify prints no lines of the ladder). `stderr` is the proposed text. `calls.log`: the build probe (3 lines) and the `db_write` after it removed. `tree.diff`: the build fact of pf 0.1.1 removed (3 lines in the hunk) |
| `sm6-bot-fail-update` | A temporary `fx/probes` with a failing build made the current code take the drop path (it is the same path as the new fail: a `Fail.of_tuple` of the platform). The file was then removed and the output edited: `stdout` line 1 has the proposed text, `6 probes` (the build probe of the first tuple is not run, so not counted: 7 to 6), `calls.log` has no build probe and no `db_write` of the first tuple, `tree.diff` has no fact of pf 0.1.0 |
| `sm6-pass-builds` | `UPDATE=1` with the `fx/probes` of the case (the build fails). Read: exit 10, `unsupported target`, the fail fact of the build recorded |
| `sm6-other-target` | `UPDATE=1`, unchanged (the output of `ef1-rank2-verify`) |

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `l0` | `l0-5` fails: `todo: slice 209b` (the new `expect` of `smoke_fail`). All other drivers pass |
| `l2` | 462 pass, 10 fail. 2 are of this slice: `sm6-bot-fail` (the build runs and passes: exit 0, a build probe, the build fact) and `sm6-bot-fail-update` (the first tuple is built and passes: no `tuple dropped` note, no platform note, no held-move report, `3 probes` for the expected `6 probes`, and a build probe in the first block of `calls.log`). The other 8 are slice 206g (`cv1-proxy-range`, `cv1-roc-default`, `cv1-roc-install-unread`, `cv1-roc-use`, `ix6-roc-update-offline`, `sh62-no-send-init`, `sh62-no-send-roc-install`, `sh62-no-send-roc-update`) |
| `l3` | pass |
| `sm6-pass-builds`, `sm6-other-target` | pass today. They guard the 2 rows of R-SM6 that must not change (row 2, row 3): a code that takes a smoke `pass` for a pass of step 3, or ignores the target or the compiler of the row, makes them fail |

## Expected exits (read, TW21)

| Case | Exit | Reason |
| --- | --- | --- |
| `sm6-bot-fail` | 10 | `no_tuple`: R-SM6 row 1, R-LD5. stderr: `tln: error[no_tuple]: no tuple works: the build for the host target failed on the platform acme/pfx 0.1.1: undefined symbol: roc_alloc (bot smoke build)` |
| `sm6-bot-fail-update` | 0 | The second tuple (pf 0.1.1) passes. stderr: the held-move report of `ef1-rank2-ladder`'s second search (`~ pf: ... (held): pf 0.1.0 does not fit the closure of the new tuple`, `writes ...`), as the drop path of `ladder/ld-ladder-flow` p6 gives |
| `sm6-pass-builds` | 10 | The build ran and failed (`unsupported target`): R-LD5. A smoke pass is no pass of step 3 |
| `sm6-other-target` | 0 | The build ran and passed |

## Code (stubs of the test step)

| File | Stub |
| --- | --- |
| `cli/lib/Matrix.roc` (round 2) | `Matrix.smoke_checks : { rows : List(Matrix.Row), id : Str, hash : Str, target : Str } -> List(Solver.Check)`, `crash "todo: slice 209b"`. The code gives these checks to the next search after the drop (the next search must also drop the tuple in the oracle state: `probed.checks`) |
| `cli/lib/Matrix.roc` | `Matrix.smoke_fail : { rows : List(Matrix.Row), hash : Str, nightly : Str, target : Str } -> Try(Matrix.Row, [None])`, `crash "todo: slice 209b"` (the doc comment has the rules) |

The wiring in `Ladder.build_round!` (read the rows with the answer, call `Matrix.smoke_fail` with the key of `plan.id`, return the failure) has no stub: the L2 cases fail by value.

## Proposals (R-OUT2, TW24)

| Item | Proposal |
| --- | --- |
| The text of the fail | `no tuple works: the build for the host target failed on the platform <name> <version>: <digest> (bot smoke build)`. It is the text of `LadderJudge.build` for an error that no file owns (`the target <t>` for a named target), with the digest of the row as the title and the suffix `(bot smoke build)`. Not tested: a row with a null digest. Proposed text for it: `...: bot smoke build failed` |
| `--json` | No new field. The failure is the `error` of the envelope as any `no_tuple` |
| `note: tuple dropped: ...` | The existing line, the text without `no tuple works: ` |

## Out of scope

The display of a row of another target in `tln outdated` and `tln add --platform` (R-SM6 row 3), the share queue and the bot (slice 218, Registry R-MX10).

## Questions (stop until answered)

Manager (2026-11-03): Q1 to Q3 went to TalonRegistry as G-C187 to G-C189. The code step waits for the answers.

| # | Question |
| --- | --- |
| Q1 | R-SM6 row 1: "The solver learns `not (platform and roc in [a, b])` for that target (R-EP7) with no build". The solver step reads checks per (release id, compiler) and has no target. The oracle asks the db and the answer only for keys of the target `any` (`Matrix.rank2` `wanted`), and the build target is known only in step 3 (`BuildTarget.pick` needs the platform header and the host). So the design does not say how a smoke fail becomes an interval. Options: (a) only the drop of the tuple at step 3 (what the L2 cases fix; no other compiler is excluded in the run); (b) the ladder gives the smoke rows of the platform (the target of the build, all compilers of D in the rows' intervals) to the next search as `Fail` checks of the platform release, which decide alone and touch each module (no unknown set, unlike Q393), and `SolverProbe` learns the maximal interval; (c) the oracle reads the smoke rows before the pick when the target is known without the header (`[build] target` set). Also open: one check per (id, compiler), so a unit `pass` and a smoke `fail` of the same platform and compiler need a rule (which row the check holds). No test of the interval is written |
| Q2 | R-SM6 names a `bot` smoke `fail` and `pass` only. Is a `bot` smoke `hang` or `crash` a step 3 fail with no build, as a `fail`? A real build that hangs or crashes is a `NoTuple` failure too (`LadderJudge.build`, R-RC3) and R-EP7 gives a fault the interval [r, r]. `Matrix.smoke_fail` returns none for them until this is answered |
| Q3 | R-EF3 says that rank 1 wins over rank 2 for one pair. A local build row (R-P4, key platform hash, compiler, target and the digest of the used modules, R-BS1) with `pass` can skip the build. Does it win over a `bot` smoke `fail` of (platform hash, compiler, target)? Are they one pair? No test has a local build row with a smoke row |

Answers (design agent, 2026-11-03; Resolution R-SM6, R-EP7):

| Slice Q | Design Q | Answer | Test change |
| --- | --- | --- | --- |
| Q1 (G-C187) | Q557 | (b): the drop at step 3, then `Fail` checks of the platform release on each compiler of its smoke runs for the next search. They touch each module, decide alone, and hold over a unit `pass` of the key. | New L2 case: 2 compilers with the smoke `fail`: one drop, the second compiler is skipped with no step 3 |
| Q2 (G-C188) | Q558 | `crash`: a fail, interval [r, r]. `hang`: not used, step 3 builds. | L0 rows of `Matrix.smoke_fail` for `crash` and `hang` |
| Q3 (G-C189) | Q559 | A local build `pass` of the key (any digest) wins; the smoke row is not used | New L2 case: a local build pass and a smoke fail: step 3 runs |
| TW24 | Q559 | The 2 texts are accepted | None |
| G-C192 (review) | Q562 | (b): the `Fail` checks are always added, also for a held compiler; each no-tuple failure of the first search starts the held move (R-SP16), not only "do not fit together" | `PickMoves.second_wanted` reads each no-tuple failure; `sm6-bot-fail-update` keeps its expect (pf moves to 0.1.1); `sm6-interval` stays |
| G-C193 (dispute) | Q563 | (a): the held move starts for each no-tuple first search. `sm6-interval`: the interval is still learned, then pf 0.1.0 -> 0.1.1 on N (exit 0 with `--allow-moves` or `--yes`, else exit 13, R-SP17). `tg3-constraint`, `ex3-no-tuple-yaml`: the second search and its index read are expected, then exit 10 when it finds no tuple. | Update `sm6-interval`, `tg3-constraint` and `ex3-no-tuple-yaml` to these results |

## Doubts (no test, or a reading the code agent may dispute)

| # | Doubt |
| --- | --- |
| D1 | `sm6-bot-fail` fixes that `platform`, the header read and the `db_query` of the build key stay before the decision (they give the target and the key). A code that reads the smoke row first and stops before the `db_query` would write another `calls.log`. If so, the code agent writes a dispute |
| D2 | No fact is recorded for the smoke fail (the tree has no build fact). A smoke fail is not a build that ran, and the row would have no digest of the used modules without the scan that `before!` does. The design is silent |
| D3 | `sm6-bot-fail-update` fixes the blame on the platform and the second search: the held pf moves to 0.1.1 and the command exits 0. A code that blames the whole tuple (`Fail.of_tuple` with no hash) also gives it today (not checked), but another message order could differ. The `6 probes` count follows R-PP4 (no build, no probe) |
| D4 | The smoke row is read for the compiler of the ladder (`Start.Started.id`, the held or chosen compiler of the run). With a free compiler (`upgrade`) the ladder runs on the chosen compiler. No case runs `upgrade` with a smoke row |
| D5 | `tln install --frozen`, `x`, tool builds and `--no-check`: `--no-check` skips the ladder, so it skips this too (R-BL6). The tool build (CLI 6.4) is not ladder step 3; R-SM6 names the ladder only. Not tested |

## Round 2 (Design Q557 to Q559)

| Item | Reading |
| --- | --- |
| Q557 | `Matrix.smoke_checks` is the pure decision: one `Fail` check (`modules: []`, `Real`: touches each module, R-UM1) for each compiler of the rows with a bot smoke fail of (platform hash, target). `Crash` rows give a `Crash` check (Q558). The code adds them to the checks of the next search; a `Real` `Fail` holds over a unit `pass` of the key, so the checks replace the check of that (id, compiler) (not tested as a unit: the L2 case `sm6-interval` shows it by the result) |
| Q558 | `smoke_fail` returns a `crash` row; a `hang` gives none (step 3 builds). The text for a `crash` is the one of a `fail` (not tested) |
| Q559 | `sm6-local-pass`: the rank 1 build `pass` of the key (any digest) stops the use of the smoke row. Green today (the smoke row is not read): a guard for the code |
| Expect files | `sm6-local-pass`: `UPDATE=1`, read (exit 0, both rows of the key in `compat.tsv`). `sm6-interval`: `UPDATE=1` on the current code (exit 0, a build), then by hand: the build probe, its `.last-use` touch and its `db_write` removed from `calls.log`; the build fact removed from `tree.diff`; `stdout` the command line, one `note: tuple dropped: ...`, `exit 10`; `stderr` the download line and the error line (the text of `sm6-bot-fail-update`, pf 0.1.0) |
| Doubt D6 | `sm6-interval` pins that the second search needs no `Fx` call (all facts are known) and that the pf release is blamed on every compiler of the run, also the one with no unit row. If the second search needs a call (a `db_query`, a header read), the code agent writes a dispute |
| Doubt D7 | `sm6-interval` also pins the order inside one ladder run: `db_query` of the build key, then the smoke decision, then (no touch) `delete` |
| Red (round 2) | `l0-5` fails: `todo: slice 209b` (`smoke_fail` crash rows, `smoke_checks`). L2: `sm6-bot-fail`, `sm6-bot-fail-update`, `sm6-interval` fail (the build runs); `sm6-pass-builds`, `sm6-other-target`, `sm6-local-pass` pass today. The other L2 failures are slice 206g (`cv1-proxy-range-bad-registry`, `sh5-first-skips`, `sh62-no-send-init` in the last run). L3 pass |

## Code

| File | Change |
| --- | --- |
| `cli/lib/Matrix.roc` | `smoke_fail` (first row of the key by R-EF3, a bot `Fail` or `Crash` gives it) and `smoke_checks` (one `Real` check for each compiler with such a row) |
| `cli/lib/Fail.roc` | New field `smoke` (default `Err(None)`) and `with_smoke`: the key of the smoke fail for the next search. `again` is not changed (`PatchedTest` pins it) |
| `cli/lib/LadderJudge.roc` | `smoke_build`: the text of the fail (`... (bot smoke build)`, null digest: `bot smoke build failed`), blame on the platform |
| `cli/lib/BuildFlow.roc` | `Plan.local_pass`: a local build `pass` of the key with any digest (Q559). No new call |
| `cli/lib/Ladder.roc` | `build_round!` gets `answer`; `smoke_stop` after `BuildFlow.before!`: no build, no touch, no fact, the probe count stays (`with_probes`) |
| `cli/lib/InstallFlow.roc` | `attempts!`: after a drop with `fail.smoke`, `smoke_facts` puts the smoke checks first in `probed.checks` (facts of the target `any`, so `OracleDomain.row_of` takes them over a unit pass) |

## Review notes

| # | Note |
| --- | --- |
| 1 | (Replaced by Q562, see Disputes.) The smoke checks were given only when D was read. With no list (`update` with a held compiler) the first search after the drop would end with `the unit check on H fails for the platform ...`, and `PickMoves.second_wanted` reads only `do not fit together`: no held move, and `sm6-bot-fail-update` (a move of pf to 0.1.1) would fail. I chose not to change `second_wanted`: `sm6-interval` (`upgrade roc`) must not do a second search. Doubt: design Q557 says checks for every run; the 2 tests need this difference |
| 2 | The checks are `Db.Fact` rows of the target `any` in `probed.checks` (`Compat` has no field for a `Solver.Check`, the tests build it). `Matrix.smoke_checks` is used for the compilers and outcomes |
| 3 | D1, D6, D7: the calls are as the tests pin them, no dispute |
| 4 | L2: 474 pass, 2 fail (`cv1-proxy-range-bad-registry`, `sh5-first-skips`: 206g). L0, L3, check, fmt pass |

## Round 3 (Design Q562, G-C192)

L0 `MatrixTest` (driver `l0-5`): `PickMoves.second_wanted` accepts each no-tuple failure when a variable is movable ("do not fit together", "the unit check on H fails for the platform", the smoke drop text), and refuses no movable variable, no variable and another failure kind (R-SP16, R-SM6). It passes at once: `second_wanted` already reads each `NoTuple` (a guard). `sm6-bot-fail-update` and `sm6-interval` keep their expect files.

## Code (Q562 round)

| File | Change |
| --- | --- |
| `cli/lib/InstallFlow.roc` | `smoke_facts` always adds the checks (domain `[key nightly]` with no list). `smoke_domain` sets `probed.domain` to that when no list was read, so the oracle does not ask for D (no `toolchains` read, `sm6-bot-fail-update` keeps its calls) |
| `cli/lib/PickMoves.roc` | `second_wanted`: any `NoTuple` failure with a movable variable |

## Disputes (from the code agent)

| Test | Rule | Dispute |
| --- | --- | --- |
| `registry/sm6-interval` | R-SP16, R-SP23, Q562; `VarsTest` (`NightlyOnly`: held packages are movable) | With Q562, the first search after the drop ends with `the unit check on H fails for the platform acme/pfx 0.1.0` and the held move starts. In `upgrade roc` pf is movable (`VarsTest` pins it). The second closure query gives pf 0.1.1 (it is in the world), its ladder passes on N: exit 0, `~ pf: 0.1.0 -> 0.1.1 (held)`, a second `http_send`. The test pins exit 10 and no call. I found no rule that makes the second search find no tuple. Red: `sm6-interval` |

## Round 4 (Design Q563, G-C193)

`sm6-interval` is now the first search that learns the pf 0.1.0 smoke interval (one ladder run, no build probe for it), then the held move: pf 0.1.1 on N, its ladder builds (exit 0 with `--dry-run`, `6 probes`). D6 (no `Fx` call in the second search) is dropped. `target/tg3-constraint` (L2) has the second search and its index read in `calls.log` (`list_dirs`/`read_files` of `index/github/acme/pf`); `exit/ex3-no-tuple-yaml` (L3) has the extra `GET /api/repos/roc-lang/basic-cli/releases` and `basic-cli/1.json`. Both keep exit 10 and their text. No run with `--allow-moves` (the dry run already gives exit 0 and the report).

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-209b-revert/code-final.sha256` | OK, 7 files |
| `grep "todo: slice 209b" cli/` | nothing |
| Expected exits (read) | `sm6-bot-fail` 10 (no tuple, the platform blamed, no build); `sm6-bot-fail-update` 0 (held move, pf 0.1.1); `sm6-interval` 0 (`--dry-run`: the first search learns the smoke interval, then the held move finds pf 0.1.1, Q563); `sm6-pass-builds` 10 (the fake build fails); `sm6-other-target`, `sm6-local-pass` 0 |
| Changed older cases (Q562, Q563) | `target/tg3-constraint` and L3 `exit/ex3-no-tuple-yaml`: only the second search's index read was added; both still exit 10 with their old text |
| `scripts/test.sh check fmt l0 l2` (`JOBS=3 TEST_TIMEOUT=400`) and `l3` (`JOBS=1`) | all pass |
| Design answers | Q557, Q558, Q559, Q562, Q563 |
| Not tested | `sm6-interval` without `--dry-run` (exit 13, R-SP17); a smoke row in `upgrade` with names; tool builds |

