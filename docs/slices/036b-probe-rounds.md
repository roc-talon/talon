# 036b Probe rounds

Phase: P1. Status: done

Slice 036b is the plan row 036b of `PLAN-P1.md`, part 2 of the split in `036-oracle-loop.md` section 1. It needs 036 (a) (done). The reference (the private implementation of the test agent, deleted at the review) has 358 added lines of code (without comments and empty lines). That is under 450, so the part is not split. One item is split off on purpose: the used-module scan in the loop (R-UM1, Q3 of slice 036) is part 036b2, see section 1.

## 1. Scope and split

| Item | Part | Why |
| --- | --- | --- |
| Probe rounds in the oracle loop (`Pairs`): the unit probe of a chosen release that has no fact, the db lookup, the fact write | 036b | R-AL4, R-EP8 |
| `--no-probe` (the input `Off` and a db lookup), `--no-check` (no probe, no lookup) | 036b | R-LF2, R-EP9, R-SO22, U3 |
| The budget `probe.max` over both searches, exit 12 | 036b | R-P5, R-UP7 |
| The ladder takes the facts of the loop (no second probe, no second query) | 036b | R-AL4, R-AL6 |
| A failure of the ladder goes back to the solver as a conflict: on the whole tuple, or on the releases that the blame names (Q2). The note `tuple dropped`. R-PH13: no other tuple gives the first failure | 036b | R-AL5, R-AL6, R-PH13, R-OV2 |
| The used-module scan in the loop (Q3): chosen releases with a known unit fail and no `Use` get a scan, then the step runs again | 036b2 (proposal, about 100 lines; also one run that sets `probe.max` for a held move, section 7 gap) | In this part the used modules are empty: a fail with modules touches nothing, and the ladder still judges it (R-UM1) |
| The list D of compilers (Q1), optional downloads, the text for a spent budget (`Off` explanation), `fix:` lines | 036c | Part 036c |

## 2. Rules

| Rule | What the part does with it | Tested by |
| --- | --- | --- |
| R-AL6 (ladder steps 2 and 3 after the units) | The units are checked in the loop. The ladder step 1 finds the facts of the loop and probes only the other units. A failure of step 2 or 3 is fed back, and the next tuple runs the whole ladder again | L2 `probe/lp1-loop` runs 1 to 4, L2 `probe/un1-units`, `ladder/ld-ladder-flow`, `ladder/bs3-build-record` (changed) |
| R-AL7 (write the header, print the tuple) | The header gets the tuple that passed after a dropped tuple | L2 `lp1-loop` runs 1 to 3 (json 2.0.5 is written) |
| R-LF2 (`--no-probe`) | `Off`: no new unit probe in the loop. A db lookup for the chosen releases that change and have no row | L0 `oracleprobe` 3, L2 `lp1-loop` runs 8 and 9 |
| R-OV2 (the raise can break a package) | An override is a fixed value. Its unit fail is the answer: exit 10 with the probe text | L0 `oracleprobe` 6, L2 `lp1-loop` run 11, `ld-ladder-flow` run 9 |
| R-UP7 (budget, exit 12) | The probe budget counts the probes of the loop and of the dropped tuples. A cut is exit 12 after the facts of the probes that ran are saved | L2 `lp1-loop` runs 4 and 10, `un1-units` runs 11, 16, 17 |
| R-EP8 (an inferred fact never decides) | The step gives `Done` only when each pair of the tuple has a real check. The value that the header has now is assumed to pass | L0 `oracleprobe` 1 and 2, L2 (a run that changes nothing probes nothing) |
| R-EP9 (`--no-probe`, spent budget) | `Off` lets a tuple pass on known evidence. A spent budget is exit 12 at once (question Q3 below) | L0 `oracleprobe` 3, L2 `lp1-loop` runs 8, 9, 10 |
| R-AL4 (known facts are not probed again) | The loop does not probe a pair that has a row. The ladder does not ask the db for the keys of the loop | L2 `lp1-loop` (calls) |
| R-PH13 (same result as P0 when no other tuple exists) | The final failure is the first failure of the ladder. Tests of a failed ladder use a case with no other tuple (anchors) | L2 `un1-units`, `ld-ladder-flow`, `bs3-build-record`, L3 `update/bs2-build-fail-replaced` (changed) |
| R-SO22 (`--no-check`: no probe), U3 | No probe and no lookup with `--no-check` | L0 `oracleprobe` 4, L2 `lp1-loop` run 12 |
| R-P3, R-EP7 (a hang, a crash, a hard fail) | A fault or a hard fail is an incompatibility of the release | L0 `oracleprobe` 1 and 6, L2 `lp1-loop` runs 5 and 6 |
| R-UM1 (named) | Interim: used modules are empty, so a fail with modules touches nothing in the loop | L0 `oracleprobe` 1, L2 `lp1-loop` run 7 |
| The wiring of R-EP8 and R-EP9 | `PickLoop` calls `Oracle.step_probed` | selftest `oracle` (changed), L2 `lp1-loop` |

The 036 review asked for an L2 case that shows the loop. It is `probe/lp1-loop`: the calls of each run show the probe rounds (the db query, the unit probe, the write, the second step).

## 3. Public signatures (the code agent keeps them)

| Item | Signature |
| --- | --- |
| `Oracle.step_probed` (`cli/lib/Oracle.roc`) | `Oracle.Input, Oracle.Compat -> Oracle.Verdict` |
| `Oracle.Input` | The input of `Pick.step` (the record of 036 (a)) |
| `Oracle.Compat` | `{ compiler : Try(Str, [None]), checks : List(Db.Fact), looked : List(Db.Key), probes : [Allowed, Off], conflicts : List(List({ at : U64, id : Str })) }` |
| `Oracle.Pair` | `{ id : Str, nightly : Str, is_platform : Bool }` |
| `Oracle.Verdict` | `[Need(List(Str)), Pairs(List(Oracle.Pair)), Done(List(Pick.Chosen)), Fail(Fail)]` |
| `Oracle.step` | `Oracle.Input -> [Need(List(Str)), Done(List(Pick.Chosen)), Fail(Fail)]`. It is `step_probed` with no compiler and `Off` |
| `Fail` (`cli/lib/Fail.roc`) | New field `again : Try({ blamed : List(Str), probes : U64 }, [None])`. `Fail.new` gives `Err(None)`. `Fail.of_tuple : Str, List(Str) -> Fail` is `NoTuple` with `again: Ok` |
| The rest (`PickLoop.Setup`, `PickLoop.State`, `Ladder.Loop`, `ResolveBase.Picked.probed`, `PickFlow.prepare!`, `PickFlow.search!`) | The reference has them. They are no test surface: the L2 cases show them by calls |

The stubs are in `research/slice-036b-revert/stubs/cli/lib/`: `Oracle.roc` (the old step, the new types, `step_probed` ignores `Compat`) and `Fail.roc` (the new field and `of_tuple`, no behavior). They are installed in `cli/lib/`.

## 4. Files

| File | Lines | Kind |
| --- | --- | --- |
| `docs/slices/036b-probe-rounds.md` | this file | slice |
| `tests/unit/oracleprobe.roc` | 199 | new, 6 `expect`s |
| `tests/commands/cases/probe/lp1-loop/` | 58 files (`rules` 8, `fx/runs` 12, `fx/units`, `fx/probes`, `fx/env`, 11 projects, expect: `calls.log` 487, `stdout` 65, `tree.diff` 132) | new L2 case, 12 runs |
| `cli/lib/Oracle.roc`, `cli/lib/Fail.roc` | 212, 25 | stubs (the reference has 335 and 25) |
| `tests/unit/out.roc` | 1 line | changed (TW21): the `Fail` literal has the new field `again: Err(None)` |
| `tests/selftest.sh` | 3 lines | changed (TW21): row `oracle` greps `Oracle.step_probed(` |
| `research/slice-036b-revert/` | | before copies (`before/`, `NEW.txt`), `reference/`, `stubs/`, `gen-lp1.py`, `mutate.py`, `check-diff.py`, `update-l2.sh`, `bk.sh`, logs |

## 5. Tests

| Test | `expect`s or runs | Rules | What it catches |
| --- | --- | --- | --- |
| L0 `oracleprobe` 1 | 1 (11 rows) | R-AL4, R-EP7, R-EP8, R-UM1, R-DT2 | the pairs that are asked for; a hard fail, a hang, a crash take a release out; a fail with a module touches nothing; another compiler and a build row are no check; order does not matter; the header value is a pass unless a real row says other |
| `oracleprobe` 2 | 1 | R-AL4, R-LD3, R-WS2, R-C9 | which slots are asked for: a new name, the platform is marked, a held slot, an unchanged tuple |
| `oracleprobe` 3 | 1 | R-LF2, R-EP9, R-AL4 | `Off`: no probe. A lookup for a chosen release that changes and is not in `looked` |
| `oracleprobe` 4 | 1 | R-SO22, R-LF3, R-PH13 | no compiler gives the answer of `Oracle.step` (`--no-check`, U3) |
| `oracleprobe` 5 | 1 | R-AL5, R-AL6, R-PH13 | a dropped tuple is a conflict on the named releases only; pairs come after the header facts |
| `oracleprobe` 6 | 1 | R-PH13, R-LD3, R-EP7, R-OV2 | the text `no tuple works: the unit check on <compiler> fails for ...`: hard fail, hang, crash, platform, the cause cone |
| L2 `probe/lp1-loop` | 12 runs | see the table in section 2 | run 1 named blame; 2 whole tuple blame (crash); 3 named blame with 2 free groups; 4 budget and the count of a dropped tuple; 5 hard fail in the loop; 6 crash; 7 fail with an unused module; 8 and 9 `--no-probe`; 10 `probe.max = 1`; 11 override; 12 `--no-check` |
| selftest `oracle` | 1 row | wiring | `PickLoop.roc` calls `Oracle.step_probed(` and not `Pick.step(` |

New L0 expects: 6 (about 0.5 s alone, about 2 s in the parallel run). Deep L2 case: 1 (12 runs). Rules with no test: none (`MISSING=1 scripts/rules.sh R-AL6 R-AL7 R-LF2 R-OV2 R-UP7 R-EP8 R-EP9` prints only the header).

Time (budget in brackets, seconds), baseline then with the reference: check 1.3 then 1.2 [10]; fmt 0.2 [5]; l0 8.5 then 8.7 [10]; l1 29.5 then 28.7 [60]; l2 1.4 then 1.6 [30]; l3 9.8 then 9.8 [60]; selftest 8.9 then 9.1 [20]; whole run 60 s of 180. The part adds about 0.2 s to l0 and l2.

The rekey of a pin with the long month (the held spelling `nightly-2026-October-13-91fa0c2` and the id that `Start.run!` finds) is shown by the old case `probe/pb1-ladder` run 4: its facts of the loop have the id of the installed dir, as the facts of the ladder.

## 6. Red run (stubs installed)

`research/slice-036b-revert/red-run.log` and `red-l0.log`. `check` and `fmt` pass. The failures are the new and the changed tests:

| Step | Result | Failing |
| --- | --- | --- |
| l0 | FAIL | `oracleprobe`: 5 of 6 `expect`s fail by a wrong value (`oracleprobe` 4 passes: the old step is the right answer with no compiler) |
| l2 | 59 passed, 24 failed | `probe/lp1-loop` and the 23 changed cases of section 9 |
| l3 | 61 passed, 1 failed | `update/bs2-build-fail-replaced` (changed) |
| selftest | 62 passed, 1 failed | `oracle` (changed) |
| l1 | pass | |

With the reference all steps pass (`green-run.log`). The reference was deleted at the review; `research/slice-036b-revert/stubs/` and `before/` stay.

## 7. Revert check

11 mutations of the reference (`research/slice-036b-revert/mutate.py`). Each runs `oracleprobe.roc` and all L2 cases. Reverts of the whole suite were not run (user rule 2026-10-23).

| Mutation | Killed by |
| --- | --- |
| No assumed pass for the header value | L0 `oracleprobe`, 28 L2 cases |
| `Off` still runs the probes | `lp1-loop`, `un1-units` |
| The budget does not count the probes that ran (`started: 0`) | `lp1-loop` (runs 4, 10) |
| No rekey of the held spelling to the id of the compiler | `pb1-ladder` run 4 |
| A ladder failure always blames the whole tuple | `lp1-loop` run 3 |
| The final failure is the last one, not the first (R-PH13) | `bs3-build-record`, `ld-ladder-flow`, `un1-units` |
| The ladder asks the db again for the keys of the loop | 22 L2 cases |
| A fail with modules counts as a hard fail | L0 `oracleprobe`, `lp1-loop` run 7, `un1-units`, `ev3-summary`, `bs2-build-skip-verify` |
| The count of probes is not carried through a dropped tuple | `lp1-loop` run 4 |
| The second search starts with a new state (facts, budget) | `hm1-noninteractive`, `hm2-interactive` |
| `verify` probes in the loop (Q-V) | 9 L2 cases (`pb2-verify`, `un3-verify-units`, `vf1-flow`, `dl2`, `g1-slice009`, ...) |

All 11 are killed. One gap: the budget that is shared by the first and the second (held-move) search is carried by the same state record as the facts, so the mutation of the second search is killed by the repeated calls, but no run sets `probe.max` for a held move. A run with `probe.max` in the `hm1` fixture would show it. The code agent keeps the one record (`PickLoop.State.probed`).

## 8. Decisions the design does not fix

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | D is the one held compiler (`Pin.Decision.held`). The list D is part 036c (Q1) | All installed compilers: needs the Epochs wiring |
| D2 | The value that a header has now is assumed to pass unless a real row says other. A run that changes nothing probes nothing | Probe each current value in the loop: a run with no change would probe all packages |
| D3 | Used modules are empty in this part: a fail with modules touches nothing, and a hard fail (no module), a hang and a crash take the release out | The scan in this part: 036b2 |
| D4 | `verify` has no probe in the loop and no feedback (Q-V): its tuple is the tuple of the version rules (R-LB2, "test with the newest versions") | Probe and fall to another tuple: `verify` would check a tuple that the files do not name |
| D5 | `--no-check` gives no probe and no db lookup (R-SO22 wins, U3) | Lookup only: the facts would be read and never written, and R-BL6 is not about the loop |
| D6 | `--no-probe` gives `Off`, and a lookup for the chosen releases that change, have no row and were not looked up | No lookup: R-LF2 says "use known evidence only", so the known fails must count |
| D7 | A spent budget: the facts of the probes that ran are saved, then exit 12 at once | Run the step once more with `Off` and exit 12 only on `Fail`: this is Q3 below |
| D8 | R-PH13: when no other tuple exists after a dropped tuple, the final failure is the first failure of the ladder (only for a solver failure of kind `NoTuple`) | The last failure: the text would be the one of the solver, not the one of P0 |
| D9 | The note of a dropped tuple stays on stdout after the final failure too | Print it only when the run ends well |
| D10 | The ladder blames by hash. A hang, a crash and a fail that names no release blame the whole tuple. A new error names its hashes. The build target error names the platform | Blame the whole tuple always (Q2 (a) only): run 3 of `lp1-loop` shows the difference |
| D11 | The probes of a failed attempt count (`Fail.again.probes`), also the ladder ones | Count the loop probes only: the budget would be too weak |
| D12 | `Fail` has a new field `again` (it is never in `--json`) | A second error type: all `Try(_, Fail)` signatures would change |
| D13 | The loop probes in one `probes!` call for all pairs of one round, and the db write follows at once (R-PP4) | One call for each pair: more calls |

## 9. Changed old tests (TW21)

Made with `research/slice-036b-revert/update-l2.sh` (the actual output goes into the expected files, `check-diff.py` lists the lines that are not of an allowed kind) and by hand where stated. The old expected files are in `research/slice-036b-revert/before/`.

| Case | Change | Reason |
| --- | --- | --- |
| L2 `consent/dl1-resolve`, `consent/dl3-rank4`, `evidence/ev3-summary`, `evidence/ev4-baseline-note`, `ladder/bs1-build-skip`, `ladder/bs2-build-skip-verify`, `ladder/ld-no-check-refuse`, `moves/hm1-noninteractive`, `moves/hm2-interactive`, `probe/pb1-ladder`, `resolve/rs-install-add-key`, `resolve/rs-new-toml`, `resolve/rs-unmanaged`, `resolve/rs-update-scope`, `resolve/rs-workspace-shared-group`, `roc/so1-ranks`, `update/up1-flow` | `calls.log` only | The loop adds the db query, the unit probe and the write for the changed release, and the ladder asks for fewer keys and probes fewer units |
| L2 `install/in1-flow` | `calls.log` only. `fx/hooks`: the hook numbers 3 and 5 are 7 and 10 | The hook counts the `probes` calls of the whole case, and the loop adds some. The hooks fire at the same place of the runs |
| L2 `roc/cv1-pins` | `calls.log` only. `fx/db`: the rules 16 and 17 are 18 and 19. The comments in `fx/commands` and `rules` have the new call numbers | The loop adds 2 db calls before them (the facts of run 11 and run 13) |
| L2 `ladder/bs3-build-record` | One line `note: tuple dropped: ...` before each exit 10, and `calls.log`. `given/project/p*/talon.toml` has the anchors of pf, json and parser | R-AL6 and R-PH13: with no anchor the ladder failure goes to another tuple. With the anchors there is no other tuple, and the verdicts, the exit codes and the rows of `tree.diff` are those of P0 |
| L2 `ladder/ld-ladder-flow` | The same: the note before each failure of the ladder, `calls.log`, anchors in `talon.toml` (p8 and p9: pf and parser only) | The same |
| L2 `probe/un1-units` | The note before the 5 failures of the ladder, `calls.log`, anchors in `talon.toml`. `tree.diff`: in run 7 and run 9 the facts of pf and parser are not written | The same. In run 7 (hard fail of json 2.1.0) and run 9 (SIGKILL) the loop stops at the unit probe of json, so the other units are not probed (R-P3) |
| L2 `resolve/rs-want-platform` | `calls.log`, and `tree.diff` has one more row in `compat.tsv`: the unit fact of the new platform release | The loop probes the unit of a changed release (the platform) |
| L3 `update/bs2-build-fail-replaced` | `stdout` has the note before exit 10, `http.log` has the request for the index of acme/parser and `tree.diff` has the index file. `given/project/talon.toml` has the anchor of the platform | The same as `bs3`. The solver reads the index of the other movable group to prove that no tuple is left (R-DI1) |
| L0 `tests/unit/out.roc` | `Fail.{ ... }` has `again: Err(None)` | New field of `Fail` (D12). The expected output is the same |
| selftest `oracle` | `Oracle.step_probed(` | `PickLoop` calls the new step |

No expected file of a verify case changed (`probe/pb2-verify`, `probe/un3-verify-units`, `verify/vf1-flow`, `consent/dl2-verify-workspace`, `workspace/ws2-verify-members`, `gaps/g1-slice009`): D4.

## 10. Output (proposed, TW24)

| Output | Proposal |
| --- | --- |
| A dropped tuple | One line on stdout before the next try: `note: tuple dropped: <message of the failure without "no tuple works: ">`. The line stays when the run ends with a failure |
| A unit fail of a release (the failure of the solver) | `no tuple works: the unit check on <compiler> fails for <blame>; <blame>`. A blame is `<name> <version>` (`the platform <name> <version>` for the platform) and `(<module>.roc)`, `(no module is named)`, `(hangs)` or `(crashes)`. It is the text of `Units.judge` of slice 031 |
| Budget spent | The text of slice 031: `tln: error[budget]: the probe budget is spent: probe.max is <n>. Set probe.max higher.`, exit 12 |
| `--json` | No new field. `Fail.again` is never in the envelope |

## 11. Questions (TW17)

| Q | Question | Options | Tested reading |
| --- | --- | --- | --- |
| Q1 | U3 (open question of the user): does `--no-check` run the unit probes of the loop, or a db lookup? | (a) R-SO22 wins: no probe, no lookup. (b) R-BL6 wins: a lookup, or the probes | (a). `lp1-loop` run 12 and `oracleprobe` 4 have the row. They change if the user says (b) |
| Q2 | Does `verify` probe in the loop (D4)? R-LB2 says "test with the newest versions" | (a) No probe, no feedback. (b) The same loop as `update` | (a). `pb2-verify`, `un3-verify-units`, `vf1-flow` keep their old output |
| Q3 | After a spent budget, does the loop run the step once more with `Off` (R-EP9: the explanation can use inferred facts) and give exit 12 only when that step has no tuple? Or exit 12 at once (D7)? The answer of the manager (035 Q2) says "a spent budget is `Off`" and "gives exit 12" | (a) At once. (b) `Off` step first, exit 12 on `Fail` | (a) now, because the text of the `Off` explanation is part 036c. Run 10 of `lp1-loop` shows (a) |
| Q4 | R-PH13 says P1 gives the same result as P0 when no other tuple exists. When other tuples exist and all fail by the ladder, which failure is the final one: the first (D8), or the last? | (a) First. (b) Last. (c) All of them | (a). The tests of P0 need it. The notes show the other ones (D9) |
| Q5 | R-P5 says `probe.max` counts checks. Do the loop probes count, and the probes of a dropped tuple (D11)? | (a) Yes, both. (b) Only the probes of the last attempt | (a). Run 4 of `lp1-loop` |
| Q6 | The loop with a spent budget and `--no-probe` can pick a tuple on facts that are known only for the changed releases (D6). Is a release with no row and no probe a pass? R-EP9 says an inferred fact can decide with `--no-probe` | (a) Yes, it passes (the ladder steps 2 and 3 still run). (b) It is a fail | (a). Runs 8 and 9 of `lp1-loop` |

Design gap: the design does not say that the user sees a dropped tuple. The line `note: tuple dropped: ...` is a proposal (section 10). The line is printed with `Fx.out!` as the other `note:` lines are.

## 12. Out of scope

| Rule or item | Part | Reason |
| --- | --- | --- |
| R-UM1 in the loop (the scan, Q3 of slice 036) | 036b2 | D3. About 100 lines. The scan needs `read_files` of the module files of the chosen release and a second step |
| R-EP10 (wiring) | 036c | The list D |
| R-DL1, R-DL6, R-NI4, `skipped N compiler downloads` | 036c | Optional downloads |
| The `Off` explanation text, `fix:` lines, `--json` causes | 036c | 035 Q1 |
| Budget of the held-move second search by a dedicated run | later | Section 7 |

## 13. Compiler limits met

| Limit | Handling |
| --- | --- |
| A private type with the name of a public one (`Verdict`) in the module of a nominal type is a redeclaration | The stub renames the private one |
| A new field in `Fail` breaks each record literal `Fail.{ ... }` | One test row has it (`out.roc`, D12) |
| `roc build` exits 2 on a warning | The mutations of `mutate.py` keep each variable used |
| A `dbg` in an `expect` prints nothing for a rebuilt row | The rows are a list that is compared with `==` |

## 14. Code result (code agent)

`scripts/test.sh` exit 0: check 1.2 s, fmt 0.1 s, l0 8.8 s (budget 10 s), l2 1.4 s, l3 9.8 s, selftest 9.4 s, l1 29.1 s. No test, fixture or expected file changed (no dispute rows). `OPT=speed scripts/test.sh` exit 0: l0 9.3 s, l2 154.9 s (over budget, known reason), the others in budget.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Oracle.roc` | 339 | `step_probed` (the stub is replaced). `step` is `step_probed` with no compiler. The compiler slot, the checks, the conflicts, `Pairs`, the text of a unit fail |
| `cli/lib/PickLoop.roc` | 184 | `run!` with `Setup` and `State`: the probe rounds (`round!`, `probe_round!`, `begin!`, `rekey`), the db lookup, the budget R-P5, the fact write |
| `cli/lib/PickFlow.roc` | 204 | `pick!` is `prepare!` and `search!`. `Ready` is the result of `prepare!`. `pick!` takes the held compiler (`Try(Str, [None])`) |
| `cli/lib/InstallFlow.roc` | 554 | `attempts!`: the ladder failure goes back to `PickFlow.search!` as a conflict (`dropped`), the note `tuple dropped`, the first failure at the end (D8). `finish!` takes `probed` and gives it to the ladder |
| `cli/lib/Ladder.roc` | 384 | `Ladder.Loop` and `Ladder.no_loop`. `run!` takes the loop: it starts the compiler only when the loop did not, it asks the db for the keys that the loop did not look up, the count of probes goes on. A failure of step 1, 2 or 3 gets `Fail.with_probes` |
| `cli/lib/LadderJudge.roc`, `cli/lib/Units.roc` | 224, 191 | A `NoTuple` failure is `Fail.of_tuple` with the blamed hashes (D10) |
| `cli/lib/Fail.roc` | 32 | New method `with_probes` (the ladder fills `again.probes`) |
| `cli/lib/ResolveBase.roc` | 340 | New type `Probed`, new field `Picked.probed` |
| `cli/lib/VerifyFlow.roc`, `cli/lib/RemoveFlow.roc` | 141, 318 | `verify` gives no compiler to the pick (D4). `remove` gives `Ladder.no_loop` |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `Oracle.step` calls `step_probed` with no compiler. One code path (the L0 rows of `oracle`, `pick*` still pass) | Keep the old private search next to the new one |
| C2 | A round does the db lookup of the keys that are not in `looked` first, then the budget check, then `Start.run!`, then the probes. `Start.run!` runs once, at the first probe | The budget check after `Start.run!`: a spent budget would start a compiler for nothing |
| C3 | A cut of the budget in a round: the first `run` probes start, the facts are saved, then `Units.spent({ max, left })` with `left` the pairs that did not run (0 when none ran: the text of `probe.max` only) | A new text |
| C4 | The facts that were read with the held spelling get the id of the started compiler (`rekey`, `old == id` test). The oracle then uses the id | Rekey with `Pin.same_id` for all rows: the keys of the first query were made with the held spelling, so the rekey is only for the rows and keys that were read |
| C5 | After a dropped tuple the whole `search!` runs again (first search, then the second search of a held move), with the facts, the nodes and the `Probed` of the first. The index of the movable groups is read again in that second search | Keep the index of the movable groups in `Ready`: it is read only in the second search, so it is not known at `prepare!` |
| C6 | `finish!` runs again for the next tuple. Its lines before the ladder (the notes of the pick, the kept entries) print again | A split of `finish!` so that these lines print once: a bigger change of `InstallFlow`, and no test shows it (question Q7) |
| C7 | A unit fail that the ladder judges blames the hash of each blamed node (also a hang and a crash). A hash that is no chosen slot release is the whole tuple (`InstallFlow.dropped`) | Whole tuple for a hang and a crash (D10 names the check and the build) |
| C8 | `Probed` is in `ResolveBase` (it is a field of `Picked`): `PickLoop` imports `ResolveBase`, so the type cannot be in `PickLoop` | `PickLoop.Probed` |
| C9 | `Outcome.probes` is the count of all probes of the command, the loop ones too (the ladder starts its count with `loop.count`) | Count the ladder probes only: the budget and the number would differ |

Questions (TW17):

| Q | Question |
| --- | --- |
| Q7 | A tuple that the ladder drops makes `finish!` run again, so the lines before the ladder (`note:` of the pick, `kept` lines) are printed again for the next tuple (C6). Print them once, or for each tuple? No case has such a line and a dropped tuple |
| Q8 | The tests fix this order of the calls: the unit probe of a release in the loop runs before the fetch of its package (`Gather.get!` follows the round: `lp1-loop` run 1). A unit probe is `roc check` in `<cache>/packages/<hash>/`, so a release that is not in the cache has no dir. The fake `Fx` does not tell. Does the real `Fx` fetch before the probe? If not, the loop needs a fetch of the pair before the probe (the calls of all L2 cases that probe in the loop change) |

Q8 answer (evidence, `research/slice-036b-revert/q8/`): the loop probes a pair before its package is fetched. `Oracle.search` (`cli/lib/Oracle.roc:261`) turns each `Header` ask of the solver into an optimistic fact, so `Pairs` come before `Need`, and `Gather.get!` (which calls `Fetch.packages!`) runs only after the round. The real `Fx` starts a probe with `cwd` = `<cache>/packages/<hash>`, and a missing dir is `not started: NotFound`. The scratch L3 copy of `update/bs2-build-fail-replaced` with the json package dirs removed gives exit 1: `the unit check of acme/json 2.1.0 on <compiler> gave no result: not started: NotFound` (no `roc` call). A release new to the machine and a release whose dir was removed (`tln cache clean`, GC) are the same case: a header fact exists only after `Gather.get!`, no header is kept apart from the package dir. Every L2 and L3 case of the slice has the dirs in the given cache, so no test sees it. Smallest fix, for the next slice: in `PickLoop.probe_round!` call `Fetch.packages!` for the ids of the pairs before `probes!` (about 8 lines). The L2 `calls.log` files that have a loop probe round (`lp1-loop` and the changed cases of section 9 with a unit probe in the loop) get `random` and `list_dirs packages` before the probe (plus the download calls of a fake that lacks the dir). L3 `http.log` and `roc.log` stay.

Compiler limits: none new.

## 15. Verify results (code agent)

Revert check: 10 mutations, filtered runs (L0 file or the L2 cases with a filter), `research/slice-036b-revert/agent-mutate.py`, log `agent-mutate.log`, notes `agent-results.md`. Caught 9 of 10. The 11 files equal `code-final.sha256` after the run (`sha256sum -c`, repo root).

| Id | Change | Caught by |
| --- | --- | --- |
| B1 | `Off` looks up a release that was looked up (`Oracle.lookups`, no `looked` test) | L0 `oracleprobe` |
| B2 | A conflict of the ladder names place 0 in place of its slot (`Oracle.given`) | L0 `oracleprobe` |
| B3 | The budget does not count the probes that ran (`started: 0`) | L2 `probe/lp1-loop` |
| B4 | No rekey of the held spelling to the id of the started compiler | L2 `probe/pb1-ladder` |
| B5 | A ladder failure always drops the whole tuple | L2 `probe/lp1-loop` (run 3) |
| B6 | The count of a dropped tuple is not carried (`count: picked.probed.count`) | L2 `probe/lp1-loop` (run 4) |
| B7 | The final failure is the last, not the first (R-PH13) | L2 `ladder/bs3-build-record`, `ladder/ld-ladder-flow`, `probe/un1-units` |
| B8 | The ladder asks the db again for the keys of the loop | L2 `probe/lp1-loop`, `resolve/rs-new-toml`, `ladder/ld-ladder-flow` |
| B9 | A new error in a hash blames the whole tuple (`LadderJudge.judge_check`) | L2 `probe/lp1-loop` (run 3) |
| B10 | A unit fail that the ladder judges blames the whole tuple (`Units.judge`) | NOT CAUGHT: a test gap (see below) |

B10 is a test gap, not an equivalent change. A named blame and the whole tuple give another next tuple when 2 groups are free. The unit fails of the ladder need a used module (R-UM1: the loop catches a hard fail, a hang and a crash of a release that changes), and the scan in the loop is 036b2. A case needs a free group with an imported module that fails on the compiler, with a second free group: `update json parser` where `json` 2.1.0 has a `Yaml.roc` fail and the app imports `Yaml`. The manager can add it to 036b2.

## Review (manager, 2026-10-24)

Accepted, with one check (answered below). Status `code`. The reference is deleted.

| Item | Answer |
| --- | --- |
| Split | Accepted. The used-module scan in the loop is 036b2 (the manager adds the row). The held-move budget gap (one run that sets `probe.max` for a held move) is in the scope of 036b2 |
| Q1 (U3) | The user's question, open. The tested reading and the U3 marks stay |
| Q2 | Accepted: `verify` has no probe and no feedback in the loop (it does not resolve) |
| Q3 | Accepted: exit 12 at once. R-UP7: "When the budget is spent, Talon writes nothing and stops with exit code 12. The error names `probe.max`." The explanation with inferred facts (R-EP9) is 036c |
| Q4 | Accepted: the first ladder failure |
| Q5 | Accepted: every check counts for `probe.max` (R-P5) |
| Q6 | Accepted: with `--no-probe` a release with no row is fit (035 Q4), and ladder steps 2 and 3 still run (R-EP9) |
| D rows, the note `tuple dropped` (TW24) | Accepted |
| Anchors in `bs3-build-record`, `ld-ladder-flow`, `un1-units` and the L3 `bs2` case | Accepted: `lp1-loop` covers the fall-through, and R-PH13 needs a case with no other tuple |

The check: `un1-units` runs 7 and 9 do not write the facts of pf and parser. Answer: (a). The step asks for the pairs of the best tuple that have no real check. In those runs pf and parser keep the value that the header has now (D2: assumed to pass), so only json 2.1.0 has no check, and the round has one pair. pf and parser never start, so no probe that ran loses its fact. It is not a round with one probe per round. A round has all pairs without a check, and the probes of one round run in one `probes!` call with the pool of `probe.slots` (R-PP1): `lp1-loop` run 3 has json 2.1.0 and parser 1.2.0 in one `probes 2` call. A new round starts only after a tuple is dropped, because the next tuple needs new pairs. So N pairs are one round, and slice 031 behavior (parallel probes, a fact for each probe that ran, written before the verdict, R-PP4) is the same. What changes against 031 is only that the unit probes of unchanged packages (pf, parser) are not run when the loop already ends with a failure before the ladder (run 7, hard fail) or before any write (run 9, SIGKILL gives no fact, R-P3).

## Fix F1 (manager, 2026-10-24)

Q8 of the code agent: the loop probes a release before its package is fetched. The real `Fx` starts a unit probe in `<cache>/packages/<hash>`, a missing dir is `not started: NotFound`, and no test saw it because each given cache had the dirs. Decision of the manager: fix option 2 (the design order, 035 and R-AL8): with a compiler set, `Oracle.search` gives `Need(headers)` before `Pairs`, so `Gather.get!` fetches the packages and gives the header facts before any probe of that release. Rejected: a fetch inside `probe_round!` (it probes a tuple whose closure is not known yet). Status `code` again: the code agent writes the fix, the tests are red.

| Item | What |
| --- | --- |
| Guard (L2, all cases) | `tests/commands/FakeJobs.roc` `probes!`: a unit probe in a package dir that is not in the fake tree gives `NotStarted("NotFound")`, as the real `Fx`. The table in `tests/commands/FakeFx.roc` (`units`) says so. It was not too large (4 lines). No old case changes by the guard: each given cache has its dirs (83 cases pass with `code-final`) |
| New case (L2) | `probe/lp2-fetch` (2 runs, `gen-lp2.py`, `lp2-rules.txt`). The dirs of json 2.1.0 and json 2.0.5 are not in the cache, and `fx/jobs` has the fake download and unbundle. Run 1: the best tuple has json 2.1.0: the calls are `random`, `list_dirs` of the packages, download, unbundle, `read_files` of its header, and only then `db_query`, `probes 1` and `db_write`. Run 2: the unit check of json 2.1.0 fails, and json 2.0.5 is new to the machine: its fetch is before its probe |
| New row (L0) | `tests/unit/oracleprobe.roc` expect 7 (3 rows, R-AL8, R-AL4): no header fact gives `need` of the best release, also when the header of another release is known; with the header known, the pair |
| Mutation (one, by hand) | The code is `code-final` (the probe is before the fetch). `lp2-fetch` fails with exit 1 and `tln: error[internal]: the unit check of acme/json 2.1.0 on <compiler> gave no result: not started: NotFound`. `oracleprobe` 7 fails (`pairs` where `need` is expected). The 24 other changed cases fail by the order of the calls. With a private reference of option 2 (4 lines in `Oracle.search`) all steps pass: check, fmt, l0, l1, l2, l3, selftest |

Changed old tests (TW21). The expected files were made with a private reference of option 2 by `UPDATE=1` and read with `check-diff.py` (the old files are in `research/slice-036b-revert/before-f1/`). The reference is deleted and `code-final` is installed again.

| Case | Change | Reason |
| --- | --- | --- |
| L2 `consent/dl1-resolve`, `consent/dl3-rank4`, `evidence/ev3-summary`, `evidence/ev4-baseline-note`, `install/in1-flow`, `ladder/bs1-build-skip`, `ladder/bs2-build-skip-verify`, `ladder/bs3-build-record`, `ladder/ld-ladder-flow`, `ladder/ld-no-check-refuse`, `moves/hm1-noninteractive`, `moves/hm2-interactive`, `probe/pb1-ladder`, `probe/un1-units`, `resolve/rs-install-add-key`, `resolve/rs-new-toml`, `resolve/rs-update-scope`, `resolve/rs-workspace-shared-group`, `roc/cv1-pins`, `roc/so1-ranks`, `update/up1-flow` | `calls.log` only (stdout, stderr, exit and tree.diff are the same) | `random`, `list_dirs` of the package cache and `read_files` of the header of each release of a pair come before its unit probe. The read of the same header after the pick is gone, so the count of lines of the reads is the same |
| L2 `probe/lp1-loop` | `calls.log` only. Runs 5 and 6 (the hard fail and the crash of json 2.1.0): the header of json 2.1.0 is read before its probe, and the header of json 2.0.5 is read before the second probe (it was read after it) | The same. The results and the facts are the same |
| L2 `resolve/rs-unmanaged` | `calls.log` only. The path entry `unm/json/main.roc` is read in its own call after the packages | The same: the packages of the pairs are read first |
| L2 `resolve/rs-want-platform` | `calls.log` and `tree.diff`: no `db_query`, no unit probe, no `db_write`, and no `compat.tsv` row for the platform. The run still ends with exit 2 | The header of the platform is read before the probe, and the check of the key `talon.toml` (R-AD33, a platform is no package) fails on that header, so the command stops before any probe. This is the order that the design gives |
| L3 | none | `http.log` and `roc.log` are the same |
| `tests/commands/FakeJobs.roc`, `FakeFx.roc` | The guard above | A fake that is more like the real `Fx` |

The 6 verify cases and `probe/lp2-fetch` run 1 and 2 have no other change. `rules.sh` shows no missing rule: `lp2-fetch` names R-AL8, R-AL4, R-AL6, R-DI1, R-CM2, R-EP8.


### Fix F1 code result (code agent)

`scripts/test.sh` exit 0: check 1.2 s, fmt 0.2 s, l0 8.9 s, l2 1.6 s, l3 9.9 s, selftest 9.1 s, l1 29.2 s. No test or expected file changed.

| File | Change |
| --- | --- |
| `cli/lib/Oracle.roc` (345 lines) | New `fetch_first`: when the solver asks only for probes, the pair releases that have no fact in `input.facts` are a `Need` (so `Gather.get!` fetches the package and reads its header), else `Pairs`. `Off` lookups are not changed. The doc table has the rule |

Revert check (one hand mutation): `Pairs(pairs_of(input, asks))` in place of `fetch_first(...)` (the probe before the fetch). `probe/lp2-fetch` fails (exit 1, the unit check gave no result: not started). The code was put back, and `code-final/` and `code-final.sha256` have the new `Oracle.roc` (the 11 files match).

## Close (manager, 2026-10-24)

Code decisions C1 to C9 are accepted. The revert check caught 9 of 10. B10 (the unit judge blames the whole tuple, not the blamed hashes) is a test gap that needs the used-module scan in the loop, so it goes to 036b2 with Q7 (pre-ladder lines print again after a dropped tuple). Q8 was a real bug (a probe before the fetch of its package); fix F1 (headers before probes, the design order) is in, and the fake Fx now fails a probe with no package dir, so every L2 case guards it. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 8.7 s). Status: done.

Note (manager, 2026-10-24, from the 036b2 review): B10 is unreachable for slot releases, because the loop of 036b2 drops each slot-release unit fail before the ladder. `probe/sc1-scan` run 1 is the case for the named blame. B10 is closed.
