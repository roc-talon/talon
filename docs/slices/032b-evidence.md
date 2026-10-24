# 032b Evidence lines

Phase: P1. Status: done

Slice 032b is the second half of the plan row 032 (`PLAN-P1.md`): the evidence lines of `tln why` (R-CM7, R-PH12 P1 column) in the order of the sources of R-EF1 with the precedence of R-EF3, and the unit-fail note in the summary of the commands that run the ladder (CLI 1 example, R-UM1). The questions E1 to E6 of `032-build-skip.md` (section 12) are answered by the manager (table in section 2). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stubs, the private reference and the scripts are in `research/slice-032b-revert/` (`before/NEW.txt` lists the new files).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-EF1 (the sources of the evidence of a pair (hash, compiler): rank 1 `compat.db`, rank 3 the `roc:` pin of the release header, rank 4 the cached `.roc-version`. P1 with `direct` has no rank 2, 5, 6) | `Evidence.of_pair`, `Evidence.pin_of`, `EvidenceFlow.blocks!` | L0 `evidence` 1, 2. L2 `ev1-why` runs 1 to 7, 9, 10, 12. L3 `why/wy2-evidence` |
| R-EF3 (the source with the lowest rank wins, the other sources are listed after it) | `Evidence.of_pair` (the order), `Evidence.text` (the mark `*`), `Evidence.fields` (`winner`) | L0 `evidence` 1, 3, 4. L2 `ev1-why` runs 1, 2, 3. L3 `wy2-evidence` run 3 |
| R-CM7 (`tln why X` gives the evidence for the version: the text and `--json`) | `Why.show`, `Why.shown_data`, `Why.run!`, `EvidenceFlow.blocks!` | L0 `evidence` 3, 4, 7. L2 `ev1-why`, `ev2-no-compiler`. L3 `wy2-evidence` |
| R-PH12 (P1 column: the evidence for each version) | all | all the cases above |
| R-UM1 (a unit fail is ignored when the app does not use the failing module: the note says so) | `Evidence.ignored`, `Evidence.note`, `UnitFlow.verdict!`, `Ladder` | L0 `evidence` 5, 6. L2 `ev3-summary`, `ev1-why` runs 1 to 3. Old L2 `bs2`, `un1`, `un3` |
| R-OUT4, R-OUT5, R-J3, R-J4 (`data` holds each fact that the text prints) | `Evidence.fields`, `Why.shown_data` | L0 `evidence` 4, 7. L2 `ev1-why` runs 2, 7, 8. L3 `wy1`, `wy2` |
| R-CC8, R-TF3 (a busy or failing db is a warning, a db with a newer format stops the command) | `Facts.load!` (no change) | L2 `ev1-why` runs 10, 11 |
| R-SO2, R-SO3, R-SO7, R-SO14 (the compiler of the member: pin, `ROC_TOOLCHAIN`, `PATH`, none) | `EvidenceFlow.blocks!`, `ResolveSelect.peek!` | L2 `ev1-why` runs 4 to 6, `ev2-no-compiler` |
| R-DI1 (`why` makes no index call) | `EvidenceFlow.blocks!` | the calls of L2 `ev1-why` (no `http_get`) |
| R-H4 (a path entry has no hash: no evidence) | `EvidenceFlow.blocks!` | L2 `ev1-why` run 8 |

`MISSING=1 scripts/rules.sh R-EF R-UM` lists no id after the slice. R-EF1 ranks 2, 5 and 6 are P2 (section 11).

## 2. Answers of the manager (E1 to E6 of `032-build-skip.md` section 12)

| # | Answer | Where it is fixed |
| --- | --- | --- |
| E1 | `why` uses the compiler that Resolution 13 selects for the member (the `roc:` pin first, then the other ranks), with no download and no probe. None selected: no evidence block | L2 `ev1-why` runs 4 to 6, `ev2-no-compiler` |
| E2 | `why` makes one `db_query!` for the keys (hash, compiler, `any`) of the packages that it shows. A busy or failing db: the R-CC8 warning, no local row | L2 `ev1-why` runs 1, 10, 11 |
| E3 | P1 shows rank 1 and rank 3. Rank 4 only from the cache of an earlier `Github.hint!` call, no new request. No rank 5. Ranks 2 and 6 are P2 | section 9, Q1 (that cache does not exist) |
| E4 | The note has no error title: `note: module <M> fails on <compiler>. Your app does not import it.` No new column | L0 `evidence` 6 |
| E5 | The note is in the summary of `install`, `add`, `update`, `upgrade` and `verify`, after the build line, for each unit fail that the scan ignored (R-UM1), and as an evidence line of `why` | L2 `ev3-summary`, `ev1-why` run 1, old L2 cases |
| E6 | Each source that has a value, in rank order, the winner (the first) marked `*`. `--json`: `data.members[].evidence` is a list of `{ rank, source, result }` | L0 `evidence` 3, 4. L2 `ev1-why` |

## 3. Flow (what the L2 cases fix)

`Why.run!` after the walk and `Why.answers`:

| Step | Call | Rule |
| --- | --- | --- |
| 1 | The compiler of each member file, once for each file: the `roc:` pin of its header, else `ROC_TOOLCHAIN`, else `ResolveSelect.peek!` (ranks 4 to 7; the `roc` on `PATH` is asked once for the run). None: no block, no more call for that member | E1 |
| 2 | A package that is not a `Release` row (path file, foreign URL) has no hash: the block has the compiler and no line | R-H4 |
| 3 | One `read_files!` of `<pkgs>/<hash>/main.roc` of each shown package that has a compiler (`Evidence.pin_of`) | E3 |
| 4 | One `db_query!` with the keys (hash, compiler, `any`) (`Facts.load!`). Busy or failed: the warning of R-CC8 and no row. `TooNew`: exit 19 | E2 |
| 5 | Rank 4: `Err(None)` for every package (no cache, Q1). No call | E3 |
| 6 | A package with a rank 1 fail that has modules: the scan of the used modules (`UnitFlow.scan_in!`, one `read_files!` for each level, the member text is the one that the load read) and `Evidence.ignored` with the empty baseline. Each entry is a note | E5 |
| 7 | `Evidence.of_pair` for each package: the block. Then `Why.show` for the text, or `Why.shown_data` for `--json` | R-EF3 |

The ladder (`install`, `add`, `update`, `verify`, `remove`): after the lines of the check and of the build, one line `note: module <M> fails on <compiler>. Your app does not import it.` for each entry of `verdict.ignored` (the unit fails that the scan of step 1 of the ladder ignored). With `--no-check` there is no ladder and no note. `Report.Outcome.notes` and `data.notes` have the text without the prefix, as for the other notes.

## 4. Public signatures (the code agent keeps them)

| Function | Signature |
| --- | --- |
| `Evidence.of_pair` | `{ hash : Str, compiler : Str, facts : List(Db.Fact), pin : Try(Str, [NoPin]), hint : Try(Str, [None]) } -> List(Evidence.Line)` |
| `Evidence.pin_of` | `{ path : Str, text : Str } -> Try(Str, [NoPin])` |
| `Evidence.text` | `Evidence.Block -> Str` |
| `Evidence.fields` | `Evidence.Block -> List((Str, JsonDoc))` |
| `Evidence.ignored` | `{ hashes : List(Str), facts : List(Db.Fact), nightly : Str, baseline : List(Probe.Err), used : List({ hash : Str, path : Str }) } -> List(Evidence.Ignored)` |
| `Evidence.module_name` | `Str -> Str` |
| `Evidence.note` | `{ path : Str, compiler : Str } -> Str` |
| `Evidence.Line` | `{ rank : U64, source : [Local, Pin, Hint], result : Db.Outcome, modules : List(Str) }` |
| `Evidence.Block` | `{ compiler : Try(Str, [None]), lines : List(Evidence.Line), notes : List(Str) }` |
| `Evidence.Ignored` | `{ hash : Str, path : Str }` |
| `Why.Shown` | `{ found : Why.Found, evidence : Evidence.Block }` |
| `Why.show` | `Why.Shown -> Str` |
| `Why.shown_data` | `List(Why.Shown) -> JsonDoc` |
| `EvidenceFlow.blocks!` | `Fx, { request : ResolveBase.Request, loaded : ResolveBase.Loaded }, List(EvidenceFlow.Shown) => Try(List(Evidence.Block), Fail)` |

`Why.Found`, `Why.text` and `Why.data` do not change, so the old L0 file `why` does not change. A field named `module` is a reserved word in Roc: the entries use `path`.

Wiring that the code agent writes (not stubs; the docs of `EvidenceFlow` have the same table):

| File | Change |
| --- | --- |
| `Ls.walk!` | A new public `Ls.walk_full!` gives `{ closures, request, loaded }`. `walk!` calls it and keeps its signature |
| `ResolveSelect` | A new public `peek!` : `Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Str, [None])`: steps 2 to 4 of `choose!` (one private function that `choose!` calls too), with no `ranged!` |
| `UnitFlow` | A new public `scan_in!` that takes `{ roots, member : { file, kind, text }, walked }`. `scan!` calls it. `verdict!` also gives `ignored : List(Evidence.Ignored)` (`[]` when no scan ran) |
| `Ladder` (`probe_in_copy!`, `probe_in_place!`) | After the lines of the check and of the build, one `note:` line for each entry of `verdict.ignored` (`compiler` is `held`) |
| `Why.run!` | `Ls.walk_full!`, `EvidenceFlow.blocks!`, then `Why.show` or `Why.shown_data` |
| `EvidenceFlow.blocks!` | The steps of section 3 |

## 5. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/Evidence.roc` | 90 | New. The contract is in the docs. Stubs `crash "todo"` with parameters `_x` |
| `cli/lib/EvidenceFlow.roc` | 38 | New. The doc table has the steps and the wiring. Stub `blocks!` |
| `cli/lib/Why.roc` | +12 (255 lines) | `Why.Shown`, `Why.show`, `Why.shown_data` (stubs). `run!` is as before the slice |
| `cli/lib/main.roc` | +2 | `Evidence`, `EvidenceFlow` in the exposed list |
| `tests/unit/evidence.roc` | 200 | New. 7 `expect`s |
| `tests/commands/cases/evidence/ev1-why`, `ev2-no-compiler`, `ev3-summary` | 12, 3, 6 runs | New L2 cases |
| `tests/scenarios/why/wy2-evidence` | 7 runs | New L3 case |
| Old expected files | 6 files | Section 7 |

## 6. Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `evidence` 1: `Evidence.of_pair` (20 rows: no source, each outcome, another compiler, another hash, the other tag form (rank 1 is the exact id, ranks 3 and 4 use `Pin.same_id`), a build row, pin and hint for the compiler and for another, all 3 sources, the order) | R-EF1 R-EF3 R-PH12 |
| L0 | `evidence` 2: `Evidence.pin_of` (7 rows: package and app header, no pin, the other tag form, a prefix, no header, empty) | R-EF1 R-SC12 |
| L0 | `evidence` 3: `Evidence.text` (9 rows: no compiler, no line, the mark `*`, a hint only, hang, crash, a fail with no, one and 2 modules, 2 notes) | R-CM7 R-PH12 R-EF3 R-OUT2 |
| L0 | `evidence` 4: `Evidence.fields` (4 rows: `compiler`, `evidence` with `winner`, `notes`) | R-OUT4 R-OUT5 R-J3 R-J4 |
| L0 | `evidence` 5: `Evidence.ignored` (18 rows: used, 2 modules, main.roc, baseline, a fail with no module, pass, hang, crash (also with modules), no row, another compiler, a build row, the order of the hashes) | R-UM1 R-P6 R-EF1 |
| L0 | `evidence` 6: `Evidence.note`, `Evidence.module_name` (4 rows) | R-UM1 R-OUT2 |
| L0 | `evidence` 7: `Why.show` and `Why.shown_data` (5 rows: the old text when there is no evidence, the lines after the paths, the 3 keys at the end of a member) | R-CM7 R-PH12 R-EF3 |
| L2 | `evidence/ev1-why` (12 runs on 5 projects: fail and pin with the note, `--json`, the used fail without a note, `PATH`, `ROC_TOOLCHAIN`, the pin wins over `ROC_TOOLCHAIN`, no value with a compiler (`--json`), a path entry (`--json`), a hint only, a busy db, a db too new, a fail with no module) | R-EF1 R-EF3 R-CM7 R-PH12 R-UM1 R-CC8 R-TF3 R-OUT4 R-SO2 R-SO3 R-SO7 R-H4 R-DI1 |
| L2 | `evidence/ev2-no-compiler` (3 runs: no `roc` on `PATH`, `--json`, a range with no installed compiler) | R-EF1 R-CM7 R-SO7 R-SO14 R-DL5 |
| L2 | `evidence/ev3-summary` (6 runs: `add`, `add --no-check`, `install`, `update` with a skipped build, `verify` of an app, `verify` of a package) | R-UM1 R-LD2 R-BL6 R-BS2 R-OUT4 E4 E5 |
| L2 | `evidence/ev4-baseline-note` (gap test, mutation u2: 1 run of `update`: a unit fail with 2 modules, the baseline explains one, the app imports none: one note for the other) | R-UM1 R-P6 R-EF1 R-PP4 E4 E5 |
| L2 | `evidence/ev5-workspace` (gap test, mutation f3b: 1 run of `why` in a workspace of 2 members with no pin: one `path_roc` call, one `db_query`, a block for each member) | R-EF1 R-EF3 R-CM7 R-SO7 R-PH12 E1 D11 |
| L3 | `why/wy2-evidence` (7 runs on the real binary: no db, the facts of a dry run, rank 1 and rank 3, `--json`, a platform, a package with no source) | R-EF1 R-EF3 R-CM7 R-PH12 R-OUT4 R-J3 R-J4 R-CC8 |

L0 count: 7 `expect`s in 1 file. Deep cases: 5 L2 and 1 L3. The `rules` file of each L2 case and the head of the `cmd` of the L3 case say what each run checks.

## 7. Changes of old tests (TW21)

Script: `research/slice-032b-revert/update-l2.sh`, `update-l3.sh` (they save the old `expect/` dir in `before/` first, run the runner with `UPDATE=1`, and `check-diff.py` and `check-diff3.py` list each changed line that is not of an allowed kind: the note line, the same text in `data.notes`, the new reads and the db query of `why`). Each changed file was read.

| Case | File | Change |
| --- | --- | --- |
| L2 `closure/cl2-chain` | `calls.log` | 2 runs of `why`: 2 new lines each, the `read_files` of the header of the shown package and the `db_query` with 1 key. The header of p1 has a pin (run 1 wrote it), so there is no `path_roc` call |
| L2 `ladder/bs2-build-skip-verify` | `stdout`, `stderr` | `stdout` and `stderr` have the note line after the build line (or the check line) in the 5 text runs that print the summary, and `data.notes` of the 5 `--json` runs (run 3, and runs 8 to 11) has the note text. `remove` (run 11) has the note too (Q3) |
| L2 `probe/un1-units` | `stdout` | Run 5 (json fails in Yaml.roc, the app does not use it): the note line |
| L2 `probe/un3-verify-units` | `stdout` | Run 2: the note line |
| L3 `why/wy1-why` | `stdout` | `why pfx --json`: the 3 new keys. `compiler` is the `roc` on `PATH` of the fake `roc version` (`nightly-2026-10-14-38a3029`), `evidence` and `notes` are `[]`. Other runs have no evidence and print the old text |

No other old case changes. `un1` run 2 (the unit fail is explained by the baseline) has no note, and run 6 (the app uses the failing module) stops with exit 10 before the summary.

## 8. Output (proposed, TW24, R-OUT2: the human accepts or changes it at the review)

Human text of `tln why` (the lines after the path lines; nothing when there is no compiler or no source has a value, so the old output stays):

```text
$PROJECT/pa/main.roc
  acme/json 2.1.0 (direct)
    json
    evidence on nightly-2026-10-14-38a3029:
      * 1 local: fail (Yaml.roc)
        3 pin: pass
    note: module Yaml fails on nightly-2026-10-14-38a3029. Your app does not import it.
```

| Item | Proposal |
| --- | --- |
| Header line | 4 spaces, `evidence on <compiler>:` |
| A source line | 6 spaces, `*` for the winner (the first line) and a space for the others, a space, the rank (`1`, `3`, `4`), a space, the source word, `: `, the result |
| Source words | `local` (rank 1), `pin` (rank 3), `roc-version` (rank 4) |
| Result | `pass`, `hang`, `crash`, `fail`, or `fail (<module path>, ...)` with the failing modules of the row (as the row has them: `Yaml.roc`) |
| A pin or hint | A line only when it is the compiler of the block (`Pin.same_id`). The result is `pass` (the author says it passed) |
| Note line in `why` | 4 spaces, `note: `, then the note. One for each failing module that the app does not import. It needs a rank 1 fail with modules |
| Note text | `module <M> fails on <compiler>. Your app does not import it.` `<M>` is the path of the module without `.roc` (`Yaml`, `sub/Yaml`). No error title, no package name (E4) |
| Note in a summary | The line `note: <text>` after the lines of the check and of the build, in the lines of the member (with 2 members or more: the file in front). The text without the prefix is in `data.notes` |
| `why --json` | Each `data.members[]` keeps `file`, `package`, `paths` and has `compiler` (the id, or null), `evidence` (a list in rank order, `[]` for no value) and `notes` (a list of texts) after them. An item of `evidence`: `rank` (number), `source`, `result` (`pass`, `fail`, `hang`, `crash`), `modules` (a list, `[]` for no fail), `winner` (true for the first item only) |

Extra to E6: `modules`, `winner` (R-OUT4: the text prints the modules and the mark), and `compiler` and `notes` on the member. The catalog row of `why` (CLI 3) needs these fields when the slice closes (R-OUT3).

## 9. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | A rank 3 pin or a rank 4 hint is a line only when it is the compiler of the block. R-EF1 says `works(hash, nightly)`: a pin for another compiler is no fact about this pair | A line `pin: <other id>` for any pin |
| D2 | Rank 1 matches the compiler id as text (the key of the store). Ranks 3 and 4 use `Pin.same_id` (R-CV1: the two tag forms of one nightly) | `same_id` for rank 1 (the store key is the text of `Start.Started.id`) |
| D3 | With no compiler, and with a compiler and no value, the human text has no block (the old output stays). `--json` always has `compiler`, `evidence`, `notes` | A line `evidence: none` (it changes each old `why` output) |
| D4 | The compiler of a member: its header pin, then `ROC_TOOLCHAIN`, then ranks 4 to 7 with no download (`ResolveSelect.peek!`). The pin wins over `ROC_TOOLCHAIN` (the answer of the user for R-SO20). `NoCompiler` and `NoneInRange` are no compiler | The order of the table of Resolution 13 (rank 2 before rank 3); `Base.selected!` (it reads `main.roc` of the current dir, not the member) |
| D5 | `why` also writes the rank 7 cache `talon/path-roc.json` (when no pin and no `ROC_TOOLCHAIN`: `OnPath.file!` as the other commands call it) and reads `compat.db`. E2 says that `why` writes only `projects.json` today: this is true only with a pin | A `roc version` call that keeps no cache |
| D6 | `why` stops with exit 19 when `compat.db` has a newer format (`Facts.load!`, R-TF3), as the other commands | A warning and no row |
| D7 | The note of `why` needs the scan of the used modules of the member, so `why` runs the scan (the reads of the imported modules) only for a package with a rank 1 fail that has modules | A note with no scan (it could not say "Your app does not import it"); no note in `why` |
| D8 | `Evidence.ignored`: a module of a rank 1 fail that the baseline does not explain, that is not `main.roc` and that is not in the used set. A `Hang` and a `Crash` give none (a fault is a blame, `Units.judge`) | Every module of a fail |
| D9 | The unit note is in the lines of each member of `Ladder.run!` and `Ladder.verify!`, so `remove` has it too (Q3). `roc use` has no closure and no note | A note in the flows of `install`, `add`, `update` and `verify` only |
| D10 | `Why.Found`, `Why.text` and `Why.data` stay. `Why.Shown`, `Why.show` and `Why.shown_data` are new, so no old L0 test changes | A new field in `Why.Found` (it changes every record in `why` L0) |
| D11 | The command code of `why` takes the compiler once for each member file and makes one db query for all members | One query for each member |
| D12 | Rank 4 is in the pure code (`hint` input of `Evidence.of_pair`, L0 rows). The command passes `Err(None)` (Q1) | No rank 4 in the pure code |

## 10. Questions (TW17)

| # | Question | Default (the tests use it) |
| --- | --- | --- |
| Q1 | E3 says rank 4 comes from the cache of an earlier `Github.hint!` call. `Github.hint!` keeps no cache, and no command calls it (only `flowprobe`). R-DI8 gives no cache file. Where is the `.roc-version` of a tag kept? | `why` shows no rank 4 line (`hint: Err(None)`). The pure code has the rank (L0). A proposal for the slice that wires R-DI8: `talon/index/github/<owner>/<repo>/<tag>.roc-version`, kept with no end (a tag is fixed) |
| Q2 | `why` ignores `ROC_TOOLCHAIN` today. A bad value (`nightly-2026-10`) is exit 2 for the commands that resolve (R-SC12). Does `why` stop for it? | `why` ignores a bad value and goes on with the next rank. No test |
| Q3 | E5 lists `install`, `add`, `update`, `upgrade` and `verify`, and not `remove`. `remove` runs the same ladder, so with one code path it prints the note | `remove` prints the note too (`bs2` run 11 shows it) |
| Q4 | `upgrade` has no code yet (the name is in `Args`, `Run` has no flow). E5 names it | The note comes with the command: `Ladder` gives it with no change |

Design gaps found:

| Gap | Where |
| --- | --- |
| The CLI 1 example has `note: module Yaml fails on nightly-2026-10-09-258ab27 (redundant expose). Your app does not import it.` E4 drops the title, so the example and the note differ. The example needs the P2 data (the title is not in the facts, R-P4) or the text of E4 | CLI 1, R-RG |
| R-EF1 says `fail(error digest)`. `compat.db` keeps the failing modules only (R-P4), so `why` cannot show the digest | Resolution 3, Resolution 4 |
| R-EF3 says "Talon prints a note when a `bot` row and an `author` row of one pair have different results". P1 has no rank 2. The text of that note is for the P2 slice | Resolution 3 |
| E2 says that `why` writes only `projects.json`. With rank 7 it also writes `path-roc.json` (D5) | slice 032 section 12 |

## 11. Out of scope

| Rule or part | Reason |
| --- | --- |
| R-EF1 ranks 2 and 6, and the R-EF3 note for a `bot` row and an `author` row | P2: they need the registry |
| R-EF1 rank 5 (the release date) | E3: `why` makes no index call (R-DI1) |
| Rank 4 in the command | Q1: no cache exists. The pure rank has L0 rows |
| The unit note in the summary of `upgrade` | `upgrade` has no flow yet (Q4). `Ladder` gives the note to every command that uses it |
| `why` in a workspace with 3 members or more, or with a pin in one member | Q23 of slice 011. The case `evidence/ev5-workspace` has 2 members with no pin: it fixes one `path_roc` call and one `db_query` (D11) |
| `why` with `--offline` | No rule that is specific to `why` (slice 011) |
| A real `roc` run (L4) | The L3 case uses the fake `roc`. A unit fail with modules on the real binary needs the real roc: slice 053 |
| The L3 run of a rank 1 fail | The fake `roc` answers by its arguments, and a unit probe has the same arguments as the check of the app, so a unit probe cannot fail alone. L2 `ev1-why` and `ev3-summary` have the fail |

## 12. Red output

Run with the stubs in the tree and the private reference away (`research/slice-032b-revert/red-run.log`, `red-l0.log`, `red-l2.log`, `red-l3.log`).

| Step | Result |
| --- | --- |
| check | pass (1.3 s) |
| fmt | pass |
| l0 | FAIL (6.2 s): `evidence` 7 of 7 fail with `todo`. All other files pass |
| l2 | FAIL (1.6 s): 73 passed, 7 failed: the 3 new cases and the 4 old cases of section 7 (a wrong value: no evidence, no note) |
| l3 | FAIL (9.8 s): 60 passed, 2 failed, 1 skipped: `why/wy2-evidence` and `why/wy1-why` (a wrong value) |
| selftest | pass (8.1 s) |

The old tests of section 7 are red on purpose (their expected files changed with the slice). All other old tests pass. Budgets (TW26): check 10, l0 10, l2 30, l3 60, selftest 20: all inside. With the reference in the tree, `scripts/test.sh` exits 0 (`green-run.log`: check 1.3 s, l0 6.3 s, l2 1.5 s, l3 9.8 s, selftest 8.0 s).

## 13. Revert check (TW12)

Script: `research/slice-032b-revert/mutate.py` (the list and the result: `results.md`). 63 changes, one at a time, in the private reference (`reference/cli/lib/`, in the tree during the run), each with the steps that can see it (L0 `evidence`, L2 all cases, L3 `wy2`). The reference is put back after each change. Result: 60 caught, 3 not caught and not a test gap (equivalent: f13, f15, u2). One more change (f14) did not compile in any form and is not in the list. 2 changes were not caught at first and got a test row (e6: `evidence` 1, e27: `evidence` 5), and 4 did not compile in the first form and were redone (w4, f9, f11, f12).

| Group | Changes | Caught by |
| --- | --- | --- |
| `Evidence.of_pair`, `pin_of` (the key, the compiler, the target, the pin and the hint, the order, the result and the modules) | e1 to e12 | L0 `evidence` 1, 2 |
| `Evidence.text`, `fields` (the mark, the header, the notes, the separators, `winner`, null, the keys) | e13 to e23 | L0 `evidence` 3, 4 |
| `Evidence.ignored`, `note`, `module_name` | e24 to e31 | L0 `evidence` 5, 6 |
| `Why.show`, `shown_data`, the use of the blocks in `run!` | w1 to w4 | L0 `evidence` 7, L2 `ev1-why` |
| `EvidenceFlow.blocks!` (the order pin, `ROC_TOOLCHAIN`, `PATH`; the read of the pin; the key of the query; no hint; the scan only for a fail with modules; the scan inputs) | f1 to f12 | L2 `ev1-why`, `ev2-no-compiler`, `cl2-chain` |
| The same on the real binary | f4b, f5b | L3 `wy2-evidence` |
| `Ladder` (the note in the 2 flows, with and without a build, after the build line, the prefix) | l1 to l7 | L2 `ev3-summary`, `bs2`, `un1`, `un3` |
| `UnitFlow.verdict!` (`ignored`, the facts of the round) | u1, u3 | L2 `ev3-summary`, `bs2`, `un1` |
| `ResolveSelect.peek!`, `picked!` | s1, s2 | L2 `ev2-no-compiler`, `ev1-why` and 5 old cases |

## 14. Next step

The human reviews the tests and the output proposals (section 8). Then the code agent writes the bodies of `Evidence` and `EvidenceFlow` and the wiring of section 4. The tests are red (section 12). The manager adds E1 to E6 to `PLAN-P1.md`. The private reference is deleted (see the review).

## Review (manager, 2026-10-23)

D1 to D12, the output proposals of section 8 and the changes of old tests (section 7) are accepted. Answers:

| # | Answer | Effect |
| --- | --- | --- |
| Q1 | No command shows rank 4 in P1, because no hint cache exists. Rank 4 stays in the pure ranking with its L0 rows, and the command passes `Err(None)`. The manager adds a follow-up item for a `.roc-version` hint cache | None in this slice |
| Q2 | `why` ignores a bad `ROC_TOOLCHAIN` | None |
| Q3 | `remove` prints the note | None (`bs2` run 11 shows it) |
| Q4 | The note comes with `upgrade` | None |

The design gaps stay recorded as design notes. The private reference is deleted (`research/slice-032b-revert/reference/`, `swap.sh`, `mutate.py` needs the reference, so it cannot run again). `research/slice-032b-revert/` keeps `before/`, `stubs/`, `results.md`, `mutate.py` and the logs. The red state is confirmed with `scripts/test.sh`. Status: code.

## Disputes (from the code agent)

None. No test, fixture or expected file changed.

## Code result

`scripts/test.sh` exits 0 (dev: check 1.3 s, fmt 0.1 s, l0 6.3 s, l2 1.5 s, l3 9.8 s, selftest 8.0 s). `OPT=speed scripts/test.sh` exits 0 too (the l2 build is 91 s with LLVM, there is no budget for it).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Evidence.roc` | 171 | The 6 bodies, and the private helpers `is_compiler`, `source_word`, `result_text`, `line_text`, `line_doc` |
| `cli/lib/EvidenceFlow.roc` | 158 | `blocks!` (steps 1 to 7) and the private `compilers_of!`, `pins_of!`, `scans_of!` |
| `cli/lib/Why.roc` | 268 | `show`, `shown_data` (`shown_doc`), `run!` calls `Ls.walk_full!` and `EvidenceFlow.blocks!` |
| `cli/lib/Ls.roc` | 97 | New `walk_full!`. `walk!` calls it |
| `cli/lib/ResolveSelect.roc` | 121 | New `peek!`. The steps 2 to 4 of `choose!` are the private `picked!`, which both call (the calls are the same as before) |
| `cli/lib/UnitFlow.roc` | 166 | New `scan_in!` (`scan!` calls it). `verdict!` gives `ignored` (private `ignored_of`) |
| `cli/lib/Ladder.roc` | 370 | `note_lines`. `probe_in_copy!` and `probe_in_place!` add the notes after the lines of the check and of the build |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `Why.run!` passes the `found` list to `EvidenceFlow.blocks!` as it is (`Why.Found` has the same fields as `EvidenceFlow.Shown`) | A copy of each record |
| C2 | A bad `ROC_TOOLCHAIN` is no value in `compilers_of!` (Q2 of the review) | A usage failure |
| C3 | `Evidence.fields` has `evidence` empty when `compiler` is `Err(None)`, as the doc says | The lines of the block with no compiler (a block with no compiler has no line, so no test sees the difference) |
| C4 | `UnitFlow.verdict!` uses `ctx.started.id` as the key of the facts (as `Units.judge` does) and `Ladder` uses `held` for the text of the note | `held` for both (the same text in every case) |
| C5 | `scans_of!` scans one time for each member file, and not for a package that has no fail with modules | A scan for each package |

No compiler bug. One note: `U64` has no `to_i64`, only `to_i64_wrap` (used for `rank`).

## Verify results

Script: `research/slice-032b-revert/agent-mutate.py`, result: `agent-results.md`. Files: `code-final/` (a copy of the 7 changed files before the mutations, restored before and after each change) and `code-final.sha256` (all of `cli/lib` and `cli/*.roc`). After the run, `sha256sum` of the tree is the same as the list, and `cmp` of the 7 files is the same. `scripts/test.sh` exits 0 after the run.

| Result | Count |
| --- | --- |
| Changes | 58 (53 compiled at the first try, 5 had an unused variable or a constant condition and were redone as f3b, f5b, f11b, f14b, u1b) |
| Caught | 55 of 58 |
| Not caught | 3: u2, f3b, f14b |

| Group | Changes | Caught by |
| --- | --- | --- |
| `Evidence` (of_pair, pin_of, text, fields, ignored, note) | e1 to e29 (25 of them) | L0 `evidence` 1 to 4 |
| `Why` | w1, w2 | L0 `evidence` 7. w4, w5: L2 `ev1-why` |
| `EvidenceFlow` | f1 to f15, f5b, f11b | L2 `ev1-why` (f7 and f10 also `cl2-chain`). The L3 step of f5b was not needed: L2 failed first |
| `Ladder`, `UnitFlow` | l1 to l8, u1b, u3, u5 | L2 `ev3-summary`, `bs2`, `un1`, `un3` |
| `ResolveSelect` | s1, s2 | L2 `ev2-no-compiler`, `ev1-why` and old cases |

| Not caught | Kind | Reason |
| --- | --- | --- |
| u2 (`verdict!` gives `baseline: []` to `Evidence.ignored`) | test gap, closed | New L2 case `evidence/ev4-baseline-note`: the baseline explains Parser.roc, the fail also has Yaml.roc, the app imports none, so the one note is for Yaml. With `baseline: []` the case fails (a second note for Parser) |
| f3b (`path_roc` asked for each member file, not once) | test gap, closed | New L2 case `evidence/ev5-workspace`: 2 members, one `path_roc` call in `calls.log`. With the change the case fails (the call is made for each member) |
| f14b (`kind != Foreign` for `kind == Release` when the hash is made) | equivalent | `Ident.of_url` of a path row or a foreign row is `Err` |

## Gap tests (test agent, 2026-10-23)

The manager asked for tests of u2 and f3b (the 2 changes of the code agent that no test saw). Only tests and this file changed. No file of `cli/` changed.

| Change | New case | Result of `agent-mutate.py` (L2, all cases) |
| --- | --- | --- |
| u2 | `tests/commands/cases/evidence/ev4-baseline-note` | caught by this case only |
| f3b | `tests/commands/cases/evidence/ev5-workspace` | caught by this case only |

After the run: `cmp` of the 7 files with `code-final/` is the same, `sha256sum -c code-final.sha256` has no difference, and `scripts/test.sh` exits 0. Output of the run: `research/slice-032b-revert/agent-results-part.md`. f14b stays equivalent.

## Close (manager, 2026-10-23)

The 5 decisions of the code agent (Code result) are accepted. Of 58 mutations, 55 were caught by the code agent's run. The gap rows `evidence/ev4-baseline-note` (u2) and `evidence/ev5-workspace` (f3b) catch 2 more. f14b is equivalent. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN. Status: done.
