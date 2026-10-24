# 036b2 The used-module scan in the loop

Phase: P1. Status: done

Slice 036b2 is the plan row 036b2 of `PLAN-P1.md`. It needs 036b (done). The reference (the private implementation of the test agent, deleted at the review) has 82 added lines of code (without comments and empty lines). The row said about 100.

## 1. Scope

| Item | Where | Rule |
| --- | --- | --- |
| The scan of the used modules after `Done` (036 Q3, manager answer): a chosen release that has a real unit fail with modules and no scan result gets a scan, then the step runs again | `Oracle.step_probed` (new verdict `Scan`), `PickLoop.run!` | R-UM1, R-AL5, R-AL4 |
| B10 of the 036b close: a case with 2 free groups and a failing module that the app imports | L2 `probe/sc1-scan` run 1 (see section 9, finding F1) | R-UM1, R-AL5 |
| One run that sets `probe.max` for a held-move second search | L2 `moves/hm3-budget` | R-P5, R-UP7 |
| Q7 of the 036b code agent: the lines that `finish!` prints before the ladder, when the ladder drops a tuple | proposal in section 8, L2 `probe/sc1-scan` run 4 | R-PH13, TW24 |

## 2. Rules

| Rule | What the part does with it | Tested by |
| --- | --- | --- |
| R-UM1 (a unit fail counts only for a used module) in the loop | The loop scans the app for the modules that it uses in a chosen release with a known fail. A fail in a used module (or in `main.roc`) drops the release. A fail in a module that the app does not use is no blame | L0 `oracleprobe` 8 and 1, L2 `sc1-scan` runs 1 to 3, `un1-units` runs 6, 14, 18 (changed) |
| R-AL5 (a fail in a used module adds an incompatibility for the hash) | The conflict names the failing release only: its probe cause. The other releases of the tuple stay | L2 `sc1-scan` run 1 (parser 1.2.0 stays, so only json 2.0.5 is probed) |
| R-AL4 (a unit probe for each pair with no fact) | A scan result is kept for the whole command: a scanned release is not scanned again, also after the ladder drops a tuple | L2 `sc1-scan` run 3 |
| R-AL6 (the ladder after the units) | A tuple that the loop drops never reaches the ladder: no ladder call, no line `note: tuple dropped` | L2 `un1-units` (changed), `sc1-scan` runs 1 and 2 |
| R-P5, R-UP7 (one budget for the whole command) | The probes of the second search of a held move count for the ladder | L2 `moves/hm3-budget` |
| R-PH13 (the lines of a failed tuple) | Q7: see section 8 | L2 `sc1-scan` run 4 |

## 3. Public signatures (the code agent keeps them)

| Item | Signature |
| --- | --- |
| `Oracle.Compat` (`cli/lib/Oracle.roc`) | New field `used : List({ id : Str, modules : List(Str) })`: for a release URL, the modules of that release that the app uses (`path` relative to the package dir). A row with `modules: []` is a scan that found no module |
| `Oracle.Verdict` | New tag `Scan({ ids : List(Str), chosen : List(Pick.Chosen) })` |
| `Oracle.step` | Unchanged. It has no compiler, so it never gives `Scan` (it gives an `Internal` failure if it did) |

The stubs are in `research/slice-036b2-revert/stubs/cli/lib/` (`Oracle.roc`: the type and the doc table with the contract, the step is the old one. `PickLoop.roc`: `used: []` in the compat, and the arm `Scan(_)` is a failure that says `todo`). They are installed in `cli/lib/`. The rest of the reference (`Setup.members`, `Probed.used`, `scan!`, the `seen` lines of `InstallFlow.attempts!`) is no test surface: the L2 cases show it by calls. The code agent can build it in another way.

### What `Oracle.step_probed` does (the doc table in `Oracle.roc` has it too)

| Step | Rule |
| --- | --- |
| 1 | `Scan` comes after the closure walk and after the lookups of `Off`, and before `Done`. So it is asked for a tuple that is good in all other ways, and with `Off` the rows come from the db |
| 2 | The ids of `Scan` are the chosen releases (no repeat, in the order of the slots) that have a real `Fail` row of the compiler with at least one module, no module is `main.roc`, and `compat.used` has no row for the release |
| 3 | `main.roc` is used by every release (roc reads it for each package of the closure, `Units.judge`). So a fail in `main.roc` touches at once. The solver already drops such a release, so the step never asks a scan for it (the two conditions "has modules" and "no `main.roc`" are redundant: mutations M4 and M5 are equivalent, section 10) |
| 4 | The command scans, and calls again with one `used` row for each id of `Scan`, also with no module. A row means "scanned". Without the row the step would ask again, for ever |
| 5 | The solver gets `used` for each release (the scan result and `main.roc`). A fail whose module is used drops the release with a probe cause, so the failure text and the named conflict are those of 036b |

### What the command does with `Scan` (the L2 cases fix the calls)

| Item | Behavior |
| --- | --- |
| Calls | One `read_files` for each level of the used modules, as `UnitFlow.scan_in!` does it. No call when the app imports nothing of the package. The scan makes no other call (the closure is built from the facts that the loop has) |
| Where | After the `db_write` of the facts of the round, before the next step. The scan is in the loop: the ladder does not run for a tuple that the scan drops |
| Members | One scan for each member of the workspace. The used modules of a release are the union (D8) |
| Kept | The `used` rows live as long as the facts: through the second search of a held move and through the tuples that the ladder drops |

## 4. Files

| File | Lines | Kind |
| --- | --- | --- |
| `docs/slices/036b2-scan-loop.md` | this file | slice |
| `tests/unit/oracleprobe.roc` | 251 (was 214) | changed: the `compat` helper and 2 literals have `used: []`, `view` has `Scan`, expect 1 row 7 is `scan` (was `done`), the comment of expect 1. New expect 8 (14 rows) |
| `tests/commands/cases/probe/sc1-scan/` | 43 files (`rules` 6, `fx/runs` 4, `fx/units`, `fx/probes` 20, `fx/new-parser.stderr`, `fx/unit-main.stderr`, 4 projects, 2 new module files of parser 1.2.0 in the given cache, expect: `calls.log` 260, `stdout` 32, `tree.diff` 86) | new L2 case, 4 runs. Made by `gen-sc1.py` |
| `tests/commands/cases/moves/hm3-budget/` | 31 files (`rules` 1, `fx/commands` 1, expect: `calls.log` 60, `stdout` 3, `stderr` 1) | new L2 case, 1 run. Made by `gen-hm3.py` |
| `cli/lib/Oracle.roc`, `cli/lib/PickLoop.roc` | stubs (the reference has +33 and +32 lines of code) | `Compat.used`, `Verdict.Scan` and the doc, `used: []` and the arm `Scan(_)` |
| `tests/commands/cases/probe/lp1-loop/rules` | text of run 7 | changed (TW21): the text said that the scan was a later part |
| `research/slice-036b2-revert/` | | `before/` (copies, `NEW.txt`), `reference/`, `stubs/`, `gen-sc1.py`, `gen-hm3.py`, `update-l2.sh`, `check-diff.py`, `mutate.py`, logs, the lists `cli-pre`, `cli-ref`, `cli-stub.sha256` |

## 5. Tests

| Test | `expect`s or runs | Rules | What it catches |
| --- | --- | --- | --- |
| L0 `oracleprobe` expect 8 (new, 14 rows) | 1 | R-UM1, R-AL5, R-AL4, R-LF2 | a fail with a module and no scan result is `Scan`. A scan that finds the module used drops the release (the next pair is asked for). Another module used: done. A row with no module: done, no second scan. The row of another release does not count. A fail in `main.roc` (alone, or with `Yaml.roc`): no scan, the next release. A fail of a release that is not chosen: no scan. Another compiler: no check. 2 slots: scanned in the order of the slots, once each, only the ones with a fail, and a slot with a result is not scanned again. The verdict has the whole tuple (one release for each slot). `Off` scans a db row too |
| L0 `oracleprobe` expect 1, row 7 (changed) | | R-UM1 | the interim row ("touches nothing") is now `scan` |
| L2 `probe/sc1-scan` | 5 runs | see section 2 | run 1 B10: 2 free groups, named conflict; 2 `main.roc` fail: no scan; 3 a kept scan result and a ladder drop; 4 Q7 |
| L2 `moves/hm3-budget` | 1 run | R-P5, R-UP7, R-SP16, R-SP24, R-DI1, R-EC12, R-PP4 | the probes of the second search count for the ladder: exit 12 `probe.max is 2 and 3 unit checks did not run` (a count that is lost gives `2 unit checks`) |

L0: 1 new `expect` (8 in the file now). Deep: 2 new L2 cases (6 runs). `MISSING=1 scripts/rules.sh R-UM R-AL R-P R-PH` prints no id of this slice.

Runs of `sc1-scan`:

| Run | Command | What it shows | Exit and result |
| --- | --- | --- | --- |
| 1 | `update json parser`, the app imports `json.Yaml` | json 2.1.0 and parser 1.2.0 are probed in one `probes 2`. json 2.1.0 fails in `Yaml.roc`. The scan reads `Yaml.roc` and `Wire.roc` of json 2.1.0 (2 levels). Only json 2.1.0 is dropped: parser 1.2.0 stays, the loop probes json 2.0.5 only. The ladder runs once | 0, json 2.0.5, parser 1.2.0, no `note: tuple dropped` |
| 2 | `update json`, the app imports `json.Yaml` | json 2.1.0 fails in `main.roc` of the package: no scan (no read of `Yaml.roc` of json 2.1.0), it is dropped at once | 0, json 2.0.5 |
| 3 | `update json parser`, the app imports `parser.Parser` | parser 1.2.0 fails in `Yaml.roc`. The scan reads `Parser.roc` once. The fail is no blame. The ladder drops json 2.1.0 (new error, named). The next tuple has parser 1.2.0 again: no second loop scan. The ladder scans on its own in each of its 2 runs (Q1) | 0, json 2.0.5, parser 1.2.0, note about module Yaml |
| 4 | `update json@2.2.0 parser` | the note `json 2.2.0 is 1d old` is printed once, then `note: tuple dropped: ...` for parser 1.2.0 (Q7 rule, proposal) | 0, json 2.2.0, parser 1.1.0 |

Time (budget in brackets, seconds), baseline then with the reference: check 1.1 then 1.2 [10]; fmt 0.2 [5]; l0 8.6 then 8.7 [10]; l1 29.7 then 28.9 [60]; l2 1.6 then 1.4 [30]; l3 9.8 then 9.8 [60]; selftest 9.1 then 9.0 [20]; whole run 60 s of 180. The new L0 `expect` adds about 0.1 s to l0. No new unit file.

## 6. Red run (stubs installed)

`research/slice-036b2-revert/red-run.log`. `check` and `fmt` pass. The failures are the new and the changed tests, by a wrong value:

| Step | Result | Failing |
| --- | --- | --- |
| l0 | FAIL | `oracleprobe`: 2 of 8 `expect`s (expect 1 row 7: `done` where `scan` is expected. Expect 8: the rows that need the scan or the used modules) |
| l2 | 82 passed, 4 failed | `probe/sc1-scan` (runs 1 to 3: the ladder runs and prints `note: tuple dropped`, no scan read), `probe/un1-units`, `evidence/ev3-summary`, `ladder/bs2-build-skip-verify` (changed, section 7) |
| l3, selftest, l1 | pass | |

`moves/hm3-budget` passes with the stubs: it is a gap test of old behavior (section 1). It is not red. Its row is checked by hand mutation (section 10, M9). With the reference all steps pass (`green-run.log`).

## 7. Changed old tests (TW21)

Made with `research/slice-036b2-revert/update-l2.sh` (the actual output of the reference goes into the expected files, `check-diff.py` lists each line that is not of an allowed kind). The old expected files are in `research/slice-036b2-revert/before/`. Each diff was read.

| Case | Change | Reason |
| --- | --- | --- |
| L2 `evidence/ev3-summary` | `calls.log` only: 3 new lines `read_files <pkgs>/<hash>/<Module>.roc` (the scan of the loop: `Std.roc`, `Wire.roc`), before the ladder of the same run. The reads of the ladder stay | The loop scans a chosen release that has a unit fail with modules. The ladder scans again (Q1) |
| L2 `ladder/bs2-build-skip-verify` | `calls.log` only: 3 new lines `read_files` (`Std.roc`, `Parser.roc`, `Lib.roc`) | The same |
| L2 `probe/un1-units` | `stdout`: the line `note: tuple dropped: the unit check on ... fails for acme/json 2.1.0 (Yaml.roc)` is gone in runs 6, 14 and 18. `calls.log`: for these 3 runs the ladder calls are gone (16 lines: `db_query`, `copy_tree`, the check `probes 1`, `delete`, ...); the module reads stay (now in the loop). Exit codes, the error text on stderr and `tree.diff` are the same | These 3 runs have a unit fail in a module that the app imports. The loop catches it before the ladder (it was the ladder in 036b): same exit 10 and same text, no ladder, no note |
| L0 `tests/unit/oracleprobe.roc` | the helper `compat` and 2 record literals have `used: []`, `view` has `Scan`, expect 1 row 7 (`scan` where it was `done`), the comment | the new field and verdict, and the end of the interim row of 036b (D3 of 036b) |
| L2 `probe/lp1-loop` | `rules` text of run 7 only. The expected files are the same | The text said that the scan in the loop is a later part. Run 7 passes as before: the app imports nothing of json, so the scan reads no file |

No L3 case changes (the fake `roc` cannot make a unit probe fail alone). No selftest row changes.

## 8. Output (proposed, TW24)

| Output | Proposal |
| --- | --- |
| A tuple that the scan drops in the loop | No line, as for a hard fail in the loop (036b: `lp1-loop` runs 5 and 6). The failure text when no tuple is left is the one of 031 and 036b: `no tuple works: the unit check on <compiler> fails for <name> <version> (<module>)` |
| Q7: a line before the ladder (`note:` of the pick, the notes of a moved platform, the notes and the `kept` lines of `add`) when the ladder drops a tuple | The command prints each such line once. A line with the same text as a line that the command printed before for an earlier tuple is not printed again. A line that is new (the next tuple has another release with a note) is printed. The line `note: tuple dropped: ...` stays for each drop. Tested: run 4 of `sc1-scan` (the pick note). The code agent applies the rule to all 4 kinds of line. No test shows the other 3 (D10) |
| `--json` | No new field |

## 9. Findings and decisions

### F1 (the manager asked for B10)

The B10 mutation of the 036b check is "a unit fail that the ladder judges blames the whole tuple (`Units.judge`)". After this part the mutation cannot be killed, and it is not a test gap: the scan in the loop sees every unit fail of a chosen release before the ladder. A release with a fail in a used module is dropped by the solver with a named probe cause. The ladder then never judges a unit fail of a slot release (it has the same facts, and the scan gives the same used modules). The 3 runs of `un1-units` that the ladder judged in 036b (6, 14, 18) are now caught in the loop. A deeper node (not a slot release) can still fail in the ladder, but `InstallFlow.dropped` makes it the whole tuple anyway, so whole tuple and named blame are the same. The case that the manager asked for (2 free groups, an imported failing module) is run 1 of `sc1-scan`. It shows the named conflict: parser 1.2.0 stays. The mutation that it kills is the loop one (no scan: M1, no alias: M6, used modules lost: M11). The code agent may leave `Units.judge` with `Fail.of_tuple`: it is the answer for `verify`-like paths that have no loop, and no test can tell the two blames apart. Question to the manager: close B10 as unreachable (Q2).

### Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The step gives `Scan({ ids, chosen })`, the command answers with `compat.used` rows (a row means "scanned", also with no module). The scan is for the whole tuple, so one scan serves all ids | A scan for all candidates before the first step (036 Q3 (b)): it reads files for tuples that are never chosen |
| D2 | `main.roc` is used by every release at once (as `Units.judge` does): no scan for a fail in it | A scan even then: an extra read with the same result |
| D3 | The scan is after the pairs, the lookups and the closure walk: only for a tuple that is good in all other ways | A scan when a fail row becomes known |
| D4 | `Off` (`--no-probe`) scans too: the rows come from the db (`un1-units` run 14) | No scan with `Off`: a known fail in a used module would pass |
| D5 | A scanned release is scanned once for the command: the rows stay through a dropped tuple and through the second search (run 3) | A scan for each tuple: the same files are read again |
| D6 | The loop drops a scanned tuple with no line (as 036b does for a hard fail) | A `note:` line: the ladder line says that the whole-app check failed, and here no check ran |
| D7 | The used modules of a release do not depend on the tuple (the row is by release URL). The scan runs on the tuple at hand | A row for each (release, tuple): more scans, and the cases do not need it |
| D8 | A workspace: each member is scanned, and the used modules of a release are the union. A tuple is for the whole workspace, so a module that one member uses counts. No test (no workspace case here) | The first member only |
| D9 | The loop has no baseline output, so R-P6 (an error of the baseline is not new) is not used in the loop. The baseline can explain only the release that the header has now, and the loop does not check that value (D2 of 036b: assumed pass) | A baseline probe in the loop |
| D10 | Q7: print each pre-ladder line once, a new line prints (section 8) | Print them for each tuple (the C6 of 036b: no change, but the same note twice); print them only for the last tuple (the lines would come after the ladder lines, or the run must wait for the ladder) |

## 10. Revert check

9 mutations of the private reference (`research/slice-036b2-revert/mutate.py`, log `mutate.log`). Each runs `oracleprobe.roc` and all L2 cases (the whole L2 step takes 1.4 s after the build). No sweep of the whole suite (user rule 2026-10-23).

| Id | Mutation | Killed by |
| --- | --- | --- |
| M1 | no scan is ever asked for | L0 `oracleprobe`, L2 (`sc1-scan`, `un1-units`) |
| M2 | the scan results are lost when the ladder drops a tuple (`InstallFlow.attempts!`) | L2 `sc1-scan` run 3 (a second loop scan of `Parser.roc`) |
| M3 | `main.roc` is not used by every release (`used_of`) | L0 `oracleprobe`, L2 |
| M4 | a hard fail (no module) is scanned | EQUIVALENT: the solver drops a hard-failed release before `Done`, so the step never sees one in a tuple |
| M5 | a fail in `main.roc` is scanned | EQUIVALENT: the same (`main.roc` is in the used modules of the solver) |
| M6 | the entries of the scan have no alias (`alias: ""`) | L2 `sc1-scan` run 1, `un1-units` |
| M8 | Q7: a line before the ladder prints again | L2 `sc1-scan` run 4 |
| M9 | the count of the second search is not carried to the ladder (`PickFlow.search!`) | L2 `moves/hm3-budget` (also 9 old cases: `hm1`, `hm2`, `up1-flow`, ...) |
| M11 | the used modules of the scan are ignored (`used_of`) | L0 `oracleprobe`, L2 |

7 killed, 2 equivalent (M4, M5: the conditions are in the doc as a contract, but the solver makes them true). The files of `cli/lib` are put back after each run. The state after the run: the stubs (`cli-stub.sha256`).

Gap of the held-move budget: `hm3-budget` closes the carry from the second search into the ladder. The carry into the second search (the first search probes, and then has no tuple with the text "do not fit together") has no run: the first search starts a probe only for a tuple that it can find, and a held group that conflicts gives no tuple. It needs a closure problem (R-AL9) after the probes, a fixture like `workspace/ws1-closure-keys` run 4 with a compiler. The mutation "the second search starts with a new state" is killed by `hm1` and `hm2` (036b section 7).

## 11. Out of scope

| Item | Reason |
| --- | --- |
| A run for the count that is carried into the second search of a held move (known gap, accepted at the review) | The first search starts a probe only for a tuple that it can find, and a held group that conflicts gives no tuple. It needs a closure problem (R-AL9) after the probes: a fixture like `workspace/ws1-closure-keys` run 4 with a compiler. `hm1` and `hm2` kill the mutation of a new state |
| A workspace run of the scan (D8) | One reference rule, no case: the loop scans each member and takes the union. The alias of a group that has 2 aliases in 2 members is the alias of the slot (`Pick.Slot.id`): not tested |
| The scan of a package with a platform or package member (`Scan.roots`) | The code of `UnitFlow.scan_in!` is not changed. `un1-units` run 18 has a package member in the ladder |
| R-EP10, the list D, the optional downloads, the `Off` explanation | 036c |
| Q7 for the notes of a moved platform and of `add` | The rule is for all 4 kinds of line. One case (the pick note) fixes it |

## 12. Questions (TW17)

| Q | Question | Options | Tested reading |
| --- | --- | --- | --- |
| Q1 | The ladder scans the used modules of its own (`UnitFlow.verdict!`) when a unit fail needs it. After the scan of the loop the same files are read again by the ladder (the cases `un1-units`, `ev3-summary`, `bs2-build-skip-verify`, `sc1-scan` run 3 show 2 reads of one file). Does the ladder reuse the result of the loop? | (a) Yes: one scan for each tuple. The loop gives its result to `Ladder.Loop`. (b) No: the ladder is not changed | (b). The closure of the ladder (`ResolveBase.closure!`) has the real aliases of the nodes that it reads, and the closure of the loop is built from the facts (no alias for the nodes below the slots), so the 2 scans can differ. If the answer is (a), the reads move and the `calls.log` of these 4 cases change |
| Q2 | B10 cannot be killed after this part (finding F1). Close it as unreachable? | (a) Close. (b) Remove the hash blame from `Units.judge` (it is dead for a slot release) | (a) |
| Q3 | Q7: print the lines before the ladder once (D10)? | (a) Once, a new line prints. (b) For each tuple (as now). (c) Only for the tuple that passes | (a). Run 4 of `sc1-scan` has the line once. If the answer is (b) the expected `stdout` of run 4 has the note 2 times |

## 13. Compiler limits met

| Limit | Handling |
| --- | --- |
| A local variable named `platform` is a reserved word | The reference uses `moved` |
| `roc build` exits 2 on a warning | The mutations of `mutate.py` keep each name used |
| `view` in `oracleprobe.roc` needs a case for each tag | The test file has `Scan` (the one file that matches a `Verdict`) |

## Review (manager, 2026-10-24)

Accepted. Status `code`. The reference is deleted (`research/slice-036b2-revert/reference/`).

| Item | Answer |
| --- | --- |
| Q1 | (b) accepted: no reuse. The ladder scans again with the real aliases. Reading the module files twice is cheap. It is a possible later speed item, not a bug |
| Q2 | Accepted. B10 is closed as unreachable for slot releases: the loop drops each slot-release unit fail before the ladder. `sc1-scan` run 1 is the case for the named blame |
| Q3 | Accepted: each line before the ladder prints once, a new line prints. The code agent applies it to all 4 kinds of line (D10). Only the pick note has a test, which is enough |
| D1 to D10 | Accepted |
| Held-move gap | Accepted as a known gap: the count carried into the second search has no run (section 11) |
| Changed old cases | Accepted: `un1-units` runs 6, 14, 18, `ev3-summary` and `bs2-build-skip-verify` `calls.log`, the `lp1-loop` run 7 text |

## 14. Next step

The human reviews the tests, the output proposal of section 8 and the questions Q1 to Q3. Then the code agent writes the scan (the contract of section 3). The tests are red (section 6). The private reference is deleted.

## Code result (code agent, 2026-10-24)

`scripts/test.sh` exits 0: check 1.2 s, fmt 0.2, l0 8.8 (budget 10), l2 1.6, l3 9.9, selftest 9.1, l1 29.1. `OPT=speed scripts/test.sh` passes all steps (l2 177.9 s, over budget for the known reason). No test, expected file or fixture was changed (no dispute rows).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Oracle.roc` | 376 | `used_of` (the scan rows and `main.roc` for each release, given to the solver), `scanned` and `needs_scan` (the verdict `Scan` before `Done`) |
| `cli/lib/PickLoop.roc` | 219 | arm `Scan`: `scan_rows!` runs `Closure.step` for each member and `UnitFlow.scan_in!` (reuse), then the rows go to `probed.used` and the loop runs again. `Setup.members` (new field) |
| `cli/lib/ResolveBase.roc` | 341 | `Probed.used` (new field) |
| `cli/lib/PickFlow.roc` | 204 | `setup.members` from `loaded.members` |
| `cli/lib/InstallFlow.roc` | 576 | Q7: `finish!` takes `seen`, `attempts!` carries it, `pre_lines` (pure) gives the lines of a tuple, `pick_notes_of` |

Decisions that the slice does not fix:

| Item | Choice | Rejected |
| --- | --- | --- |
| Where the scan results live | `ResolveBase.Probed.used`: they go with the count and the facts through the second search and the ladder drops, with no new carry code | A separate state record |
| Closure of the loop scan | `Closure.step` for each member, with the entries of the slots (alias is `Pick.Slot.id`) and the unmanaged entries of that member, over the facts and path nodes of the loop. The aliases of nodes below the slots are empty, so an `import` of a package file that uses a dep alias is not followed (Q1 of the slice: the ladder scans again with real aliases) | A new walk with reads |
| Members | `PickLoop.Setup.members` (file, kind, text of each `loaded.members`) | Only members with a change |
| Q7 | `finish!` filters each line against `seen`. `attempts!` adds `pre_lines` of the dropped tuple to `seen`. A drop (`fail.again`) comes only from the ladder, after all lines were printed, so `pre_lines` is the exact set. It repeats the order of the 4 kinds of line | `finish!` that returns the printed lines (it has many `?` exits) |
| Scan ids | The scan row of an id is the scan result for its hash (no other release) | |

Questions (TW17): none. Compiler limits: none new.

## Verify results

`research/slice-036b2-revert/agent-mutate.py`, log `agent-mutate.log`. Each run: L0 `oracleprobe` and all L2 cases. The final code is in `research/slice-036b2-revert/code-final/` (`code-final.sha256`, checked from the repo root: all files equal after the mutations).

| Id | Mutation | Result |
| --- | --- | --- |
| A1 | no scan is asked for (`needs_scan`: `Fail` to `Pass`) | caught: L0 `oracleprobe`, L2 |
| A2 | scan results lost when the ladder drops a tuple (`InstallFlow.attempts!`: `used: []`) | caught: L2 `probe/sc1-scan` |
| A3 | `main.roc` not used by every release (`used_of`) | caught: L0, L2 |
| A4 | the scan entries have no alias (`PickLoop.scan_rows!`) | caught: L2 |
| A5 | Q7: the pick note prints again (the filter against `seen` breaks) | caught: L2 `probe/sc1-scan` |
| A6 | Q7: `seen` is not carried to the next tuple | caught: L2 `probe/sc1-scan` |
| A7 | the count of the second search is not carried to the ladder (`PickFlow.search!`) | caught: L2 (`update/up1-flow` and others) |
| A8 | the used modules of the scan are ignored (`used_of`) | caught: L0, L2 |
| A9 | the modules of all scanned releases go to each id (`PickLoop.scan_rows!`: no filter by hash) | first NOT CAUGHT (test gap). CLOSED by `probe/sc1-scan` run 5 (section Gap tests): the run fails with the mutation |
| A10 | a release is not made unique in `ids` (`Oracle.scanned`) | NOT CAUGHT: equivalent. One URL is one group, so it fills one slot, and a repeat would give 2 equal rows (the solver reads the first) |

Caught 9 of 10 (A9 closed by the gap test, A10 equivalent). The log shows the exit code of L0 and L2 for each run.

## Gap tests (test agent, 2026-10-24)

The manager asked for a test of A9. Only tests and this file changed. No file of `cli/` changed.

| Change | New run | Result |
| --- | --- | --- |
| A9 | L2 `probe/sc1-scan` run 5 (`update json parser`, the app imports `json.Yaml`; the unit checks of json 2.1.0 and parser 1.2.0 both fail in `Yaml.roc`, one `probes 2` call). The step asks one scan for both releases. The app uses `Yaml.roc` of json only, so only json 2.1.0 is dropped and parser 1.2.0 stays (its fail gives only the note). The 2 failing modules have the same name, so the modules of all releases sent to each id would touch parser 1.2.0 too | With A9 applied (one hand mutation) the run fails: parser 1.1.0 is chosen and the note is gone. Only `probe/sc1-scan` fails. The files of `cli/lib` were put back from `code-final/`: `sha256sum -c research/slice-036b2-revert/code-final.sha256` is clean, `scripts/test.sh` exits 0 (`gap-green-run.log`: l0 8.8 s, l2 1.3 s). Runs 1 to 4 of the case have the same expected files as before |

## Close (manager, 2026-10-24)

The code decisions are accepted. The code agent ran 10 targeted mutations: 8 caught, A9 closed by `sc1-scan` run 5, A10 equivalent. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 8.8 s of 10 s). Status: done.
