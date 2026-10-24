# 039c `tln upgrade X`: held moves with the nightly (R-RP4)

Phase: P1. Status: done

Slice 039c is the plan row 039c of `PLAN-P1.md`. It needs 038, 039, 039b and 017. It adds the nightly to the held move of the second search (R-RP4), the lag note for the nightly (R-UP2, slice 039 Q4), and the tests of `--no-probe` with a free nightly (R-LF2, slice 039 Q5).

The private reference has about 230 added lines of code (without comments and empty lines): `Solver` 25, `Oracle` 6, `OracleRequest` 8, `NightlyPlan` 28, `Lags` 55, `NightlyFlow` 30, `PickLoop` 12, `PickFlow` 50, `InstallFlow` 3. The limit is 450, so no split is needed. The reference is in `research/slice-039c-revert/reference/` (private: the code agent does not read it, TW18).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-RP4 | A held move of `upgrade X` can move the nightly. It is a movable variable of the second search | L0 `moves.roc` expects 3, 4. L0 `oraclefree.roc` expect 3. L0 `nightlyplan.roc` expects 7, 8. L2 `ur6-moves` runs 1 to 6, 8, 10, 12 |
| R-SP23 | Only `upgrade` moves a held variable. `update` never does | L2 `ur6-moves` run 7. L0 `moves.roc` expect 4 (no `current`: not movable) |
| R-SP24 | Order of the second search: movable packages, then the compiler (last slot), then the free packages. The nightly keeps H when a tuple exists with H, else it moves the smallest step | L0 `moves.roc` expects 3, 4 (rows of a movable compiler). L2 runs 1, 12 |
| R-SP16 | The report of a held move names each moved variable. With no tuple in the second search the failure is the one of the first search | L2 runs 1, 9, 12. L0 `nightlyplan.roc` expect 8 |
| R-SP17 | With no consent in CI the report and exit 13. Nothing is written | L2 runs 1, 6 |
| R-SP25 | The move names the member files that it writes | L2 runs 1, 10. L0 expect 8 (members) |
| R-SP26 | `--dry-run` shows the report and the diff, and writes nothing | L2 run 5 |
| R-NI3, R-NM8 | The prompt names the nightly. Enter is No | L2 runs 3, 4 |
| R-UP13 | `upgrade X` holds the nightly. The free nightly (`upgrade X roc`) is no held move | L2 runs 8, 14 |
| R-RP2 | `update` never moves the nightly | L2 run 7 |
| R-RP3, R-WS1 | A member with no pin gets `+ roc` | L2 run 10 |
| R-J5 | `--json`: `error.details.moves` has the nightly row | L2 run 6 |
| R-UP2 (nightly lag) | A note when N is not used: `roc <N> is not used, <got> is chosen: <why>` | L0 `upgrade.roc` expects 5, 6. L2 runs 13, 15, and the changed old cases (section 8) |
| R-EP14 | The reason may come from an inferred fail (the note ends with `(inferred)`) | L0 expect 5 (`Lags.blame`). L2 run 15 |
| R-LF2, R-EP9 | `--no-probe` with a free nightly: a real or inferred fail decides, no unit probe runs | L0 `oraclefree.roc` expect 4 (passes in red: it pins old behavior). L2 runs 13, 14, 15 |
| R-CV1 | A compiler id in the other tag form is the same compiler | L0 expect 7, expect 8 (`Pin.same_id`) |
| R-C7 | The nightly of a held move is not one that min-release-age hides | L0 expect 7. L2 world (n14 is hidden) |

## 2. Public signatures (stubs, `crash "todo: slice 039c"`)

| Name | Signature | File |
| --- | --- | --- |
| `Solver.step_moves` | unchanged type. A slot of kind Compiler with a `current` is movable when its name is in the movable list | `packages/resolve/Solver.roc:101` |
| `Oracle.step_moved` | `OracleBase.Input, OracleBase.Compat, List(Str) -> OracleBase.Free` (the third value is the movable names) | `cli/lib/Oracle.roc:55` |
| `NightlyPlan.movable` | `{ releases, req, now, min_age, snapshot, nightly : Bool, held : Str, installed : List(Str) } -> List(Str)` | `cli/lib/NightlyPlan.roc:68` |
| `NightlyPlan.roc_move` | `{ held, nightly : Try(Str, [None]), why, members } -> Try({ alias, name, from, to, why, members }, [Same])` | `cli/lib/NightlyPlan.roc:73` |
| `Lags.blame` | `{ releases, compiler, checks, inferred, used } -> Try(Str, [None])` | `cli/lib/Lags.roc:37` |
| `Lags.nightly` | `{ newest : Try(Str, [NoneKnown]), got : Try(Str, [None]), releases, checks, inferred, used } -> Try(Lags.Lag, [NoLag])` | `cli/lib/Lags.roc:43` |

`Solver.step_moves` is a real change of a pure function, not a stub: see section 8 (the old solver row changes by design). Only `Oracle.step_moved`, `NightlyPlan.movable`, `NightlyPlan.roc_move`, `Lags.blame` and `Lags.nightly` have `crash` bodies. `Oracle.step_moved` is a new function, and `Lags.blame` and `Lags.nightly` are new. The wiring is not stubbed (section 11).

## 3. The tested reading (the rules of the command)

| # | Rule | Source |
| --- | --- | --- |
| 1 | The second search of `upgrade X` (no `roc` in the names) makes the nightly a movable variable. The trigger is the old `second_wanted` ("do not fit together" and a movable variable). A unit fail on H alone does not start it, because the first search assumes a pass for a header value | R-RP4, R-SP16, D4 of slice 017 |
| 2 | Order of the slots: movable packages, the compiler, the free packages. So the compiler keeps H when a tuple exists with H | R-SP24 |
| 3 | The values of a movable compiler follow the order of D (oldest first). With Highest: `current`, then the compilers after it from old to new, then the ones before it from new to old. Lowest mirrors this. A compiler slot with no `current` is not movable | R-SP24 |
| 4 | The values of the movable nightly (`NightlyPlan.movable`): the allowed compilers (`Toolchain.range_allowed`, so R-C7 hides n14) that are installed and not older than H by `Pin.order`, plus H itself. No download | D1, D2 |
| 5 | The nightly moves to the nearest installed compiler above H for which a tuple exists, not to the newest. A free nightly (`upgrade X roc`, `upgrade roc`, bare `upgrade`) takes the newest compiler that works | R-UP13, R-SP9 |
| 6 | The consent item of a held move: `NightlyPlan.roc_move` gives a row with alias `roc`, name `roc`, the ids as `from` and `to`, the `why` of `Lags.blame` on H, and the member files. `Err(Same)` when H and the chosen compiler are the same id (`Pin.same_id`) or no compiler was chosen | R-SP16, R-SP25, R-CV1 |
| 7 | The pin is written for a held move with the other consented moves. A member with no pin gets `+ roc` | R-RP3, R-WS1 |
| 8 | `Lags.nightly`: a lag exists when N is known, got is known, `!same_id` and `Pin.order(got, N) == Before`. The `why` is `Lags.blame` on N, else `it does not fit the closure of the tuple`. No time is compared | R-UP2 |
| 9 | `Lags.blame`: the first release (in the order of the tuple) with a real row that touches the compiler: `<alias> <version> <fails or hangs or crashes> the unit check on <compiler>`. Else the first inferred fail that touches, with ` (inferred)` | R-EP14 |
| 10 | `--no-probe` with a free nightly: N is fit unless a real or inferred fact excludes it (R-EP9). No unit probe runs | R-LF2, R-EP9 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `packages/resolve/tests/moves.roc` expect 3 (1 changed row, 1 control row) and expect 4 (new, 14 rows) | movable compiler order with Highest and Lowest, no `current` means not movable, `current` not in D, a movable package and the compiler, a free package gives way before the compiler moves, no tuple | R-RP4 R-SP24 R-SP23 |
| L0 | `tests/unit/oraclefree.roc` expect 3 (11 rows) | `Oracle.step_moved`: the compiler moves to the nearest value, keeps H when a tuple exists, no tuple gives a `Fail`, a Held json | R-RP4 R-SP24 |
| L0 | `tests/unit/oraclefree.roc` expect 4 (9 rows, probes Off) | `--no-probe`: a real fail, an inferred fail, no fact; Allowed asks the pair of the best tuple | R-LF2 R-EP9 |
| L0 | `tests/unit/nightlyplan.roc` expect 7 (17 rows) | `NightlyPlan.movable`: installed only, not older than H, H is added when absent, hidden by age, range, other tag form, switch off, empty list | R-RP4 R-C7 R-CV1 R-CV2 |
| L0 | `tests/unit/nightlyplan.roc` expect 8 (5 rows) | `NightlyPlan.roc_move`: a move, same id, other tag form, no compiler, members | R-SP16 R-SP25 R-CV1 |
| L0 | `tests/unit/upgrade.roc` expect 5 (17 rows) | `Lags.blame`: fails, hangs, crashes, first release wins, inferred last, no touch | R-UP2 R-EP14 |
| L0 | `tests/unit/upgrade.roc` expect 6 (10 rows, and the `Lags.note` text) | `Lags.nightly`: lag, no lag (same id, newer, no N, no got), the `why` text | R-UP2 R-EP14 |
| L2 | `upgrade/ur6-moves` (new, 15 runs, entry `commands`) | The table below | R-RP4 R-SP16 R-SP17 R-SP23 R-SP24 R-SP25 R-SP26 R-NI3 R-NM8 R-UP13 R-RP2 R-RP3 R-WS1 R-J5 R-UP2 R-LF2 R-EP9 R-EP14 |

World of `ur6-moves`: the compilers n08 (PATH), h0 (H), n10, n11, n12 (N), n14 (hidden by min-release-age). Families: (lib, core) core 1.2.0 fails on h0 only. (libd, cored) cored 1.2.0 fails everywhere. (libp, corep) corep 1.2.0 passes everywhere. jb has 1.0.0 and 1.1.0. Each header was edited by hand (libX 1.0.0 needs coreX 1.2.0, the header holds coreX 1.0.0), as in `ug3-move` (slice 038).

| Run | Command | Result | Rules |
| --- | --- | --- | --- |
| 1 | CI, `upgrade jb` | report: `~ core`, `~ roc ... (held)`; exit 13; nothing written | R-RP4 R-SP16 R-SP17 R-SP24 R-SP25 |
| 2 | `--allow-moves` | core 1.2.0, jb 1.1.0 and the pin n10 written | R-RP4 R-RP3 |
| 3 | interactive, Enter | prompt `Move the held variables core, roc? [y/N]`; exit 13 | R-NI3 R-NM8 |
| 4 | interactive, `y` | the moves are written | R-NI3 |
| 5 | `--dry-run` | report, diff, exit 0, nothing written | R-SP26 |
| 6 | `--json` | exit 13, `details.moves` has 2 rows | R-J5 |
| 7 | `update jb` | exit 10, no move | R-RP2 R-SP23 |
| 8 | `upgrade jb roc --allow-moves` | only core is a held move; the pin goes to n12 | R-UP13 R-SP9 |
| 9 | cored fails everywhere | exit 10, first failure, no report | R-SP16 |
| 10 | workspace (a has pin, b has none) | `~ roc` in a, `+ roc` in b; `writes` lists both | R-SP25 R-RP3 R-WS1 |
| 11 | no conflict | no second search, the list is not read | R-RP4 (negative) |
| 12 | corep passes on H | the nightly stays; only corep is named | R-SP24 |
| 13 | `upgrade roc --no-probe`, real fail row on N | n11 chosen, lag note | R-LF2 R-EP9 R-UP2 |
| 14 | `--no-probe`, no fact | n12, no unit probe | R-LF2 R-EP9 |
| 15 | `--no-probe`, inferred fail on n12 | n10 chosen, note ends `(inferred)` | R-EP9 R-EP14 |

Deep case: one (`ur6-moves`, 15 runs, 15 projects, 15 homes). L3: no new scenario (the real `roc` needs real downloads, and the movable values are installed compilers only). The generator is `research/slice-039c-revert/gen-um.py`.

## 5. Output proposals (TW24, for the human review)

| Output | Text |
| --- | --- |
| Report line of the nightly move (stderr) | `~ roc: roc <from> -> <to> (held): <alias> <version> fails the unit check on <from>` and the next line `  writes <files>` |
| Prompt | `Move the held variables core, roc? [y/N]` |
| Answer line | `moved the held variables core, roc` |
| Lag note (stdout) | `note: roc <N> is not used, <got> is chosen: <why>` |
| `why` of a real row | `<alias> <version> fails the unit check on <compiler>` (also `hangs`, `crashes`) |
| `why` of an inferred fail | the same text with ` (inferred)` at the end |
| `why` with no touching fail | `it does not fit the closure of the tuple` |
| `--json` | `error.details.moves[]` has `{ alias: "roc", name: "roc", from, to, why, members }`. `data.notes` has the lag note (ur5-optional run 10) |

## 6. Decisions that the design does not fix (D, for the review)

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | The values of a movable nightly are installed compilers only (no download). The same list as the free nightly gets from `Launch.toolchains!`, plus the PATH compiler | Downloads for a held move (needs the consent text of R-NI12 and the cap; Q1) |
| D2 | The values are not older than H. `upgrade` moves up (D2 of slice 039). An early run moved the pin down to the PATH compiler n08 | Values below H (Q2) |
| D3 | (Q3, changed in review) The compiler list is read at most once for the command. The second search of `upgrade X` reuses the list that the first search read (`Probed.listed`). When the first search did not read it, the second search reads it once. `ug3-move` has one new list read in each run | Two reads (the first version of this slice), a read for each need |
| D4 | A free nightly is no consent item. `roc` is named in the report and the prompt only when the nightly is held (`upgrade X`) | Name `roc` also for a free nightly (Q4) |
| D5 | The lag compares ids by `Pin.order`. No release time | Compare times |
| D6 | The lag note shows for each run where got is older than N, also in the old cases | Show only with `--verbose` (this changes 4 old cases: section 8) |
| D7 | `--no-probe` with a free nightly follows R-EP9: N is fit unless a real or inferred fact excludes it | Always keep N with `--no-probe` (Q5) |
| D8 | The trigger of a held nightly move is the old `second_wanted`. It is not a unit fail on H, because the first search assumes a pass for a header value (`ur6-moves` uses a hand-edited header for this reason) | A first-search trigger |

## 7. Out of scope, questions (TW17)

| Id | Question | Status |
| --- | --- | --- |
| Q1 | May a held nightly move download a compiler (R-NI12, the cap R-DL6)? D1: no | closed by the review: accepted |
| Q2 | May the held nightly move below H (an older installed compiler)? D2: no | closed by the review: accepted |
| Q3 | The compiler list is read at most once for the command | closed by the review: D3 changed |
| Q4 | Should the prompt name `roc` for a free nightly? D4: no (a free nightly needs no consent) | closed by the review: accepted |
| Q5 | Confirm the reading of D7 (a fit N with `--no-probe` unless a fact excludes it) | closed by the review: accepted |

Design gaps: none found in the design files. The slice file asks for decisions only in Q1 to Q5.

| Out of scope rule | Reason |
| --- | --- |
| R-NI12 (downloads for a held move) | Q1 |
| R-NI4, R-DL1 to R-DL6 | Done in 039b. Not changed |
| R-UP6 | Done in 039b |
| R-SP13 (the ladder on the moved tuple) | Only checked as part of ur6 runs 1, 2 (check and build on n10). No new rule row |
| R-EP6 (the inference) | Used by run 15. Its own tests are in slice 036 |

## 8. Changed old tests (TW21)

All expected files were made with `UPDATE=1 tests/commands/run.sh <case>` and read with `diff` against `research/slice-039c-revert/before/`.

| Test | Change | Reason |
| --- | --- | --- |
| `packages/resolve/tests/moves.roc`, row `with_roc, ["roc","x"]` (expect 3) | expects `done x=1.2.0 roc=1(n-1)` (was: the compiler never moves). A control row with `["x"]` expects `roc=2(m-2)` | R-RP4: a compiler with a `current` is now movable |
| `tests/commands/cases/upgrade/ur1-roc/expect/stdout` | 5 new `note: roc <N> is not used, <chosen> is chosen: <pkg> <ver> fails the unit check on <N>` lines (runs 3, 4, 5, 15, 16). stderr, calls.log and tree are the same | R-UP2 nightly lag (slice 039 Q4): each run has a chosen compiler older than N |
| `tests/commands/cases/upgrade/ur4-candidate/expect/stdout` | the same note in 2 runs | same |
| `tests/commands/cases/upgrade/ur5-optional/expect/stdout`, `expect/stderr` | 13 note lines in stdout (12 runs, and run 10 `data.notes` in json). 1 note line in stderr | same |
| `tests/commands/cases/upgrade/ug3-move/expect/calls.log` | 10 new lines (5 in each of the 2 runs). The second search of `upgrade lib` reads the compiler list once (`platform`, `list_dirs`, `programs gh`, `http_get nightlies`, no route, so unreadable, the values are `[H]`, and no `toolchains` read). The first search did not read the list | D3 (Q3): the held nightly needs the list, and the second search reads it once |
| `tests/commands/cases/upgrade/ur6-moves/expect/calls.log` | not an old test. The first version of the slice had 2 list reads in 9 runs (4 lines of `platform`, `list_dirs`, `read_files`, `db_query pinned` each, 36 lines in all). The review change removes the second read. Copy of the first version: `research/slice-039c-revert/before-q3/` | D3 (Q3) |

The copies before the change are in `research/slice-039c-revert/before/tests/commands/cases/upgrade/`. All other old L0, L2, L3 tests have no change.

## 9. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Baseline before this slice (`baseline-run.log`) | all pass: l0 7.7, l2 5.1, l3 9.7, selftest 11.1, l1 29.5 |
| Red (the stubs, `red-run.log`) | check, fmt, l3, l1 pass. l0 FAIL: `moves.roc` 3 passed and 2 failed (wrong values), `nightlyplan.roc` 2 failed (`todo: slice 039c`), `oraclefree.roc` 1 failed (todo), `upgrade.roc` 2 failed (todo). l2 FAIL (94 passed, 5 failed): `ug3-move` (Fx calls), `ur1-roc` (stdout), `ur4-candidate` (stdout), `ur5-optional` (stdout, stderr), `ur6-moves` (stdout, stderr, Fx calls, tree). selftest FAIL (66 passed, 1 failed, see the note below) |
| Green (the reference, `reference-run.log`) | all pass: check 1.2, fmt 0.1, l0 7.7, l2 4.4, l3 9.8, selftest 11.2, l1 31.3 (budgets 10, 5, 10, 30, 60, 20, 60) |

Red state notes:
- `oraclefree.roc` expect 4 passes in red. It pins old behavior (R-LF2, R-EP9), as the brief allows for a rule that only needs a test.
- The selftest row `s_unit_guard` runs `scripts/test.sh l0` on a symlinked `packages/`. The red `moves.roc` fails that clean control. It passes in green. The old solver row "compiler never movable" must change by design, so the red state is unavoidable (harness note for the manager).
- The step budget of l1 is 60 s. The green l1 is 31.3 s.

Revert check of the review change (Q3, `reference-run-q3.log` is the green run after it: check 1.4, fmt 0.1, l0 8.0, l2 4.2, l3 9.9, selftest 11.2, l1 29.1): 2 hand mutations, both caught by `ur6-moves` (`ug3-move` also catches the first). M1: the second search drops `Probed.listed`, so `wide!` reads again. M2: the second search reads the list again though the first search has it.

Revert check (`research/slice-039c-revert/mutate.py`, the reference in the tree, filtered runs only, `mutate.log`): 10 mutations, 10 caught. P5 was first written with a function that does not exist, and P10 with a constant `if` (a warning that fails `roc test`): both were fixed.

| Id | Mutation | Caught by |
| --- | --- | --- |
| P1 | `update` moves the nightly too | `ur6-moves` run 7 |
| P2 | a movable compiler takes the lower values first with Highest | `moves.roc` |
| P3 | the compiler is not movable in `Oracle.step_moved` | `oraclefree.roc` expect 3 |
| P4 | the other tag form is not the same id | `nightlyplan.roc` |
| P5 | a lag also when got is newer than N | `upgrade.roc` expect 6 |
| P6 | `Lags.blame` ignores inferred fails | `upgrade.roc` expect 5 |
| P7 | D is not read before the second search | `ur6-moves` run 1 |
| P8 | the move lists only the first member | `ur6-moves` run 10 |
| P9 | the pin is not written for a held move | `ur6-moves` run 2 |
| P10 | a free nightly is named as a held variable | `ur6-moves` run 8 |

## 10. Compiler and tool limits met

| Id | Limit | Workaround |
| --- | --- | --- |
| C1 | A closed record parameter does not take a wider record | `Lags.inferred_reason` and `Lags.probe_reason` take narrowed records |
| C2 | An unused variable is a warning, and a warning fails `roc test` (exit 2). A constant `if` also warns | a mutation uses a non-constant condition |
| C3 | `==` on a `Try` does not compile | L0 rows convert to Str or tuple first |
| C4 | `roc fmt` rewrites long lines | run `roc fmt` before the check |

## 11. Notes for the code agent

| Topic | Note |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/upgrade/ur6-moves/rules` has the text of each run. `research/slice-039c-revert/run-log.py <case> <n>` prints the calls of one run |
| `Solver.step_moves` | `moved = movable.contains(slot.name) and (slot.kind != Compiler or slot.current.is_ok())`. A new `moved_compiler`: the asc order of the Lowest request, `place` is the index of `current`, `higher` follows, `lower` is reversed. Highest: own, higher, lower. Lowest: own, lower, higher |
| `Oracle.step_moved` | first `Pick.empty_domain(input)` (a `Fail` when a slot has no value), then `OracleSearch.search` with a request where the compiler slot has `current` (`OracleRequest.moving`) and the movable names are `OracleRequest.movable_of(input)` plus `roc` |
| `NightlyFlow` | `Plan` gets `newest : Try(Str, [NoneKnown])`. A new `movable!` reads the list (`Launch.toolchains!`, PATH compiler) and calls `NightlyPlan.movable`. It gives `[H]` when the list is unreadable |
| `PickLoop` | `Setup` gets `newest` and `movable : Try(List(Str), [None])`. `run!` calls `Oracle.step_moved` when `movable` is Ok, else `step_free`. `wants_domain` is true also when `movable` is Ok |
| `PickFlow` | `prepare!` gets a parameter `newest` (after `free`) and sets `movable: Err(None)`. `pick!` passes `Err(NoneKnown)`. In `search!`: `nightly_moves` is `request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Held and setup.held.is_ok()`. Only then the second search has `movable: Ok(...)`. After it: `why = Lags.blame(...) ?? "it does not fit the closure of the tuple"`, `roc = NightlyPlan.roc_move(...)` appended after the package moves. The `lags` list adds `Lags.nightly` |
| `InstallFlow` | passes `plan.newest` to `prepare!`. The default Plan literal has `newest: Err(NoneKnown)`. The pin of a held move is written with the other moves |
| `Lags` | `probe_reason` takes `{ compiler, checks, used }`. `inferred_reason` is new. Imports `Epochs`, `Pin` |
| Q3, list read once | `ResolveBase.Probed` gets `listed : Try(List(Nightlies.Release), [NotRead])` (`ResolveBase` imports `Nightlies`). `PickLoop.start` sets `Err(NotRead)`. A new public `PickLoop.releases! : Fx, Request => List(Nightlies.Release)` (`[]` when unreadable). `wide!` uses `probed.listed` when `Ok`, else `PickLoop.releases!`, and stores `listed: Ok(releases)`. `PickFlow.search!` in the second search of a held nightly move: `listed` is `stuck.probed.listed` or `PickLoop.releases!`, and the second state has `probed: { ..stuck.probed, listed: Ok(listed) }`. `NightlyFlow.movable!` takes `releases` in its `run` record and does not read the list. It returns `[held]` when `releases` is empty, before the `toolchains` read |
| Size | About 230 lines of code. `PickFlow.roc` is the largest change (about 50). If it grows past the module limit, move the new part of `search!` to `PickMoves.roc` |

## 12. Files

| File | State |
| --- | --- |
| `docs/slices/039c-nightly-moves.md` | new (this file) |
| `packages/resolve/Solver.roc` | doc of `step_moves` (R-RP4 movable compiler). The code of the old rule stays, so the red `moves.roc` fails by value |
| `cli/lib/Oracle.roc`, `cli/lib/NightlyPlan.roc`, `cli/lib/Lags.roc` | new stubs with docs |
| `packages/resolve/tests/moves.roc` | expect 3 changed, expect 4 new (257 lines). Expect 5 (brute force) is the same |
| `tests/unit/oraclefree.roc` | expects 3, 4 new (177 lines) |
| `tests/unit/nightlyplan.roc` | expects 7, 8 new (224 lines) |
| `tests/unit/upgrade.roc` | expects 5, 6 new (358 lines) |
| `tests/commands/cases/upgrade/ur6-moves/` | new (15 runs) |
| `tests/commands/cases/upgrade/{ur1-roc,ur4-candidate,ur5-optional,ug3-move}/expect/` | changed (section 8) |
| `cli/lib/ResolveBase.roc` | in the reference only (`Probed.listed`, Q3) |
| `research/slice-039c-revert/` | `before-q3/` (the first versions of `ug3-move` and `ur6-moves`), `before/` (with `NEW.txt`), `reference/` (deleted after the review), `stubs/`, `gen-um.py`, `ur6-rules.txt`, `mutate.py`, `mutate.log`, `run-log.py`, `bk.sh`, `flip.sh`, `red-run.log`, `reference-run.log`, `baseline-run.log`, `l2-ref-old.log` |

## Review (manager, 2026-10-24)

Accepted, with one change (Q3).

| Question or decision | Answer |
| --- | --- |
| Q1 (D1) | Accepted. A held nightly moves only to installed compilers, with no download (the R-NI4 default is no download) |
| Q2 (D2) | Accepted. No move below H |
| Q3 (D3) | Change. Read the compiler list at most once for the command. When the first search (or the free-nightly plan) already read it, the second search reuses it. When the first search did not need it, the second search reads it once. `ug3-move` gets one list read, not two |
| Q4 (D4) | Accepted. A free nightly is no consent item |
| Q5 (D7) | Accepted |
| D5, D6, D8 | Accepted. The 4 old cases with the new lag note line are accepted |
| `s_unit_guard` (red selftest row) | Accepted (red state only) |

Test agent, after the review: D3 and sections 6, 7, 8, 9, 11, 12 are changed for Q3. The free-nightly plan (`NightlyFlow.plan!`) reads the list before the search, and the search does not use that list (`Probed.listed` starts as `Err(NotRead)`). So the free-nightly plan and the search read the list separately (`NightlyFlow.plan!`, `PickLoop.wide!`), as before this slice. The slice does not change that case (no old expected file differs). The review text says "or the free-nightly plan": a code agent that wants this case too can pass `plan.releases` into `Probed.listed`, but then the calls.log of the old free-nightly cases change (a TW21 change for the human review).

Red run after the review change (`red-run-q3.log`): check, fmt, l3, l1 pass. l0, l2 (94 passed, 5 failed: ug3-move, ur1-roc, ur4-candidate, ur5-optional, ur6-moves) and selftest FAIL, as in the first red run. `reference/` is deleted (the review change is in `reference-run-q3.log` only).

## Code result (code agent)

| Item | Result |
| --- | --- |
| `scripts/test.sh` | exit 0: check 1.2, fmt 0.1, l0 8.2, l2 3.5, l3 9.8, selftest 11.1, l1 30.0 s. `OPT=speed`: all pass, l0 9.9, l2 208.9 (over budget, the known reason), l1 16.9 s |
| Changed tests | none (no dispute rows) |
| Questions (TW17) | none |

| File | Lines | Change |
| --- | --- | --- |
| `packages/resolve/Solver.roc` | 374 | `moved` (a compiler slot with a `current`), `moved_var` splits into `moved_package` and new `moved_compiler` |
| `cli/lib/Oracle.roc` | 86 | `step_moved` |
| `cli/lib/OracleRequest.roc` | 157 | new `moving` (the request with `current` H on the compiler slot) |
| `cli/lib/NightlyPlan.roc` | 115 | `movable`, `roc_move`, a private `askable_of` that `pick` also uses |
| `cli/lib/Lags.roc` | 282 | `blame`, `nightly`, new `inferred_reason`, `touching`. `probe_reason` takes `{ compiler, checks, used }` |
| `cli/lib/NightlyFlow.roc` | 163 | `Plan.newest`, `movable!` |
| `cli/lib/PickLoop.roc` | 332 | `Setup.newest` and `movable`, `Probed.listed` start value, public `releases!`, `wide!` reuses `listed`, `step_moved` call, `wants_domain` |
| `cli/lib/PickFlow.roc` | 271 | `prepare!` parameter `newest`, `held_nightly!`, `roc_moves`, `nightly_lags`, `chosen_rows` |
| `cli/lib/ResolveBase.roc` | 353 | `Probed.listed` (imports `Nightlies`) |
| `cli/lib/InstallFlow.roc` | 220 | `plan.newest` to `prepare!`, `moved` is the pin of the `roc` row of the moves |

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| `why` of the `roc` row | `Lags.blame` over the chosen releases of the tuple (slot alias, chosen url and version) on H. The expected `core 1.2.0 fails ...` is a chosen release, not a header value | The header values (the doc of `roc_move` says so, but the expected stderr names the chosen core 1.2.0) |
| Pin of a held move | `InstallFlow.finish!`: `moved` is `Ok(to)` of the row `roc` of the moves, else `NightlyFlow.moved_to`. The ladder then checks the pin as for a free nightly | A new field in `Picked` |
| Members of the `roc` row | each member file of the workspace (`loaded.members`) | the files of the moved packages |
| Shared code of `pick` and `movable` | one private `askable_of(f, extra)` (`extra` is N for `pick`, none for `movable`) | a second copy of the `fit` rule |
| Lag of a re-search | the re-search after a dropped tuple builds the second search again and reads the installed compilers again (the list is not read again: `listed`) | keep the values in `Probed` |

## Verify results (code agent)

Revert check: 10 mutations, 9 caught, 1 not caught (B2, closed later by a gap test: 10 of 10 now) (`research/slice-039c-revert/agent-mutate.py`, `agent-mutate.log`, `agent-results.md`). Code copy: `code-final/`, `code-final.sha256`. Final compare: SAME. Filtered runs only.

| Id | Mutation | Test that failed |
| --- | --- | --- |
| B1 | the lower compilers of a movable compiler are not nearest first | L0 `moves.roc` |
| B2 | a compiler slot with no `current` is movable | closed by the gap test: L0 `moves.roc` expect 4, the new `Lowest` row (see "Gap tests") |
| B3 | a compiler older than H is a value of the movable nightly | L0 `nightlyplan.roc` |
| B4 | an inferred fail wins over a real row of a later release | L0 `upgrade.roc` |
| B5 | the lag reason is blamed on the chosen compiler, not on N | L0 `upgrade.roc` |
| B6 | the pin of a held nightly move is not written | L2 `ur6-moves` |
| B7 | `wide!` reads the compiler list again | L2 `ur6-moves` |
| B8 | the installed compilers are read when the list is empty | L2 `ug3-move` |
| B9 | a free nightly (`upgrade X roc`) is a held move | L2 `ur6-moves` |
| B10 | the compiler list is not read before the second search | L2 `ur6-moves` |

B2 is a test gap. With a named compiler slot that has no `current`, `moved_compiler` gives all values as lower ones, newest first. That is the order of D with `Highest` (the only strategy that the row "a compiler slot with no header value is not movable" in `moves.roc` expect 4 uses), so the change shows only with `Lowest` (oldest first expected). Proposal for the test agent: one row with `Lowest` and `current: Err(None)`.


## Gap tests (test agent, 2026-10-24)

| Id | Gap | Change | Check |
| --- | --- | --- | --- |
| B2 | A compiler slot with no `current` that is movable was not caught: the only row used `Highest`, where the mutated order equals the order of D | `packages/resolve/tests/moves.roc` expect 4: one new row, `Lowest` with `current: Err(None)` and `x` failing on roc-3. Expected `roc=1` (the order of D, oldest first). A movable compiler with no `current` gives `roc=5` | One hand mutation of `Solver.step_moves` (`moved = |slot| movable.contains(slot.name)`): only the new row fails (the `dbg` shows its text). Restored from `research/slice-039c-revert/code-final/`. `sha256sum -c research/slice-039c-revert/code-final.sha256` is OK. `scripts/test.sh` exits 0 (check 1.7, fmt 0.2, l0 8.0, l2 5.0, l3 9.9, selftest 11.1, l1 29.8) |

Doc fix: the doc of `NightlyPlan.roc_move` (`cli/lib/NightlyPlan.roc:64`) said that the `why` is `Lags.blame` over "the header values on H". The tests are the contract: `ur6-moves` names `core 1.2.0`, a chosen release of the tuple, and the code uses the chosen releases. The sentence is now "over the chosen releases of the tuple, on H". Only the doc comment changed, no code. `code-final/cli/lib/NightlyPlan.roc` and its line in `code-final.sha256` have the same doc change. Section 3 rule 6 and the `PickFlow` note in section 11 already say "chosen" (no change).

## Close (manager, 2026-10-24)

The code decisions are accepted. The code agent ran 10 targeted mutations: 9 caught, B2 closed by a `Lowest` row in `moves.roc` expect 4. The `roc_move` doc now says "the chosen releases of the tuple", as the tests expect (doc only; `code-final.sha256` updated for that file). `scripts/test.sh` exits 0 with no WARN (l0 8.0 s). Note: the code agent read the test agent's `mutate.py`, which shows parts of the reference; the tests pass, and BRIEF-code.md now forbids it. Status: done.
