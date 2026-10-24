# 036 The oracle loop

Phase: P1. Status: done

Slice 036 is the plan row 036 of `PLAN-P1.md`. The row is too big for one slice (the reference of the whole row is about 1000 lines of code, the budget is 300 to 400 for each part). This file proposes a split into 036 (a), 036b and 036c. It has red tests for 036 (a) only. The manager decides the split at review.

## 1. Split of the row (proposal)

| Part | Content | Rules | Size (lines of code) | `scripts/test.sh` after the part |
| --- | --- | --- | --- | --- |
| 036 (a) | The pure step `Oracle.step` (a drop-in for `Pick.step`, same input, output and texts) over the new `Solver.step_moves`. The held-move second search as a decision order. A closure problem is a conflict (034 Q3). The path entry `cli/lib` to `resolve`. `PickLoop` calls `Oracle.step`. `probes: Off`, no facts of probes | R-AL3, R-AL9, R-SP24, R-PH10, R-PH13, R-WS2 | about 250 (reference: Oracle 190, Solver +60, Pick +20) | green. No L2 or L3 expected file changes |
| 036b | Known evidence in the loop: the used-module scan of the chosen releases, the probe rounds (`Allowed` and `Off`), `--no-probe`, the budget over both searches, exit 12, the ladder takes the facts of the loop, a ladder failure is a conflict (Q2). The explanation text for probe causes (TW24) | R-AL6, R-AL7, R-SP24, R-LF2, R-UP7, R-OV2, R-PH13, 035 Q1, 035 Q2, U3 | about 400. If it is over 450: split the scan from the rounds | green. Many `calls.log` files of L2 and L3 change (the order of the db and probe calls) |
| 036c | The list D (Epochs, 033) for the commands that resolve (Q1). Optional downloads: the cap R-DL6, the line `skipped N compiler downloads`, the one prompt R-NI4 and R-DL1 (Q4). `fix:` lines. The hint "the oldest nightly that works" (R-RP2) | R-DL1, R-DL6, R-NI4, R-RP2, R-EP9, 025b | about 350. If it is over 450: split the optional downloads | green. L2 cases of the prompt change |

036b needs 036 (a). 036c needs 036b (the probe rounds are where an optional download is asked for). The order keeps `scripts/test.sh` green after each part.

## 2. Rules (part 036 (a))

| Id | What the part does with it | Tested by |
| --- | --- | --- |
| R-AL3 (PubGrub, learning that does not repeat work) | The commands that resolve use the solver (034, 035) in place of the one-tuple search of P0. A pair conflict is learned at once | L0 `oracle` 3 (16 free slots, no pair of `x` and `y`), 4 (a pair of one group, 16 free slots) |
| R-AL9 (the closure is walked after Done) | After `Done` the step walks the closure of the tuple. A problem is fed back as a conflict of the whole tuple. As many times as it takes | L0 `oracle` 1, `pickclosure` (all rows) |
| R-SP24 (the second search: the nearest values first) | `Solver.step_moves`: movable slots first, `current` first, then the nearest values | L0 `moves` 1 to 4, `pickmoves` |
| R-PH10, R-PH13 (same result and texts as P0) | `Oracle.step` gives what `Pick.step` gave: `Need`, `Done` and the failure lines | L0 `oracle` 5 (480 worlds, differential), `pick`, `pickclosure`, `pickmoves` (they run on `Oracle.step`) |
| R-WS2, R-WS8 (one value for a group, slots by place) | A pair conflict for 2 slots of one group. The solver slot name is `s<index>` | L0 `oracle` 2, 4 |
| R-C1, R-C2, R-C3, R-C4, R-C6, R-C7, R-C9, R-SP1, R-VA6, R-DT2 (named) | The constraints of a movable slot are those of a free slot. Only the order of values differs | L0 `moves` 3, 4, `oracle` 5 |
| R-SP23 (named) | The compiler slot is never movable | L0 `moves` 3 |
| The wiring: `PickLoop` calls `Oracle.step`, `cli/lib` has the path entry to `resolve` | No L2 or L3 case can tell the two steps apart (the same output), so the selftest reads the 2 files | selftest `oracle` |

Rules of the row that part (a) does not do: section 8.

## 3. Public signatures (the code agent keeps them)

| Item | Signature |
| --- | --- |
| `Solver.step_moves` (`packages/resolve/Solver.roc:111`) | `Solver.Request, List(Str) -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]`. `step` equals `step_moves(req, [])`. The doc table has the 4 rules |
| `Oracle.step` (`cli/lib/Oracle.roc:26`) | The input and output of `Pick.step`. The doc table has the contract |
| `PickLoop.run!` (`cli/lib/PickLoop.roc`) | Calls `Oracle.step`. No other change |
| `cli/lib/main.roc` | Exposes `Oracle`. Has `resolve: "../../packages/resolve/main.roc"` (a path entry to a Talon package, allowed) |
| `Pick` (`cli/lib/Pick.roc`) | The reference makes `empty_domain`, `closure_verdict` and `chosen_for` public (about 20 lines moved out of `step`). `Pick.step` stays: it is the oracle of the differential row (`oracle` 5) |

## 4. Files

| File | Lines | Kind |
| --- | --- | --- |
| `docs/slices/036-oracle-loop.md` | this file | slice |
| `cli/lib/Oracle.roc` | 37 | stub (`crash "todo"`). The reference has 190 |
| `packages/resolve/Solver.roc` | +14 | stub of `step_moves` and its doc |
| `cli/lib/main.roc` | +2 | `Oracle` exposed, path entry |
| `tests/unit/oracle.roc` | 199 | new, 5 `expect`s |
| `packages/resolve/tests/moves.roc` | 220 | new, 4 `expect`s |
| `tests/unit/pick.roc`, `pickclosure.roc`, `pickmoves.roc` | 1 line each, plus `import lib.Oracle` | retargeted: `Pick.step(` is `Oracle.step(` |
| `tests/selftest.sh` | +10 | row `oracle`. `packages` link in the unit guard copy |
| `research/slice-036-revert/` | | before copies, stubs, reference, `swap.sh`, `mutate.py`, logs |

Changed old tests (TW21): the 3 L0 files above (the same rows, only the called step changes), `tests/selftest.sh` (the link, because `cli/lib` now has a path dependency on `packages/resolve`). No L2 or L3 expected file changes in part (a) (the reference gives equal output for all of them: `scripts/test.sh` was green with the reference).

## 5. Tests

| Test | `expect`s | Rules | What it catches |
| --- | --- | --- | --- |
| `tests/unit/oracle.roc` 1 | 1 (5 rows) | R-AL9, R-AL3, R-PH10, R-DT2 | 2 closure problems in a row, the same in other order, the second search, a missing fact, no tuple |
| `oracle` 2 | 1 (5 rows) | R-WS8, R-WS2 | slot names by place, 2 groups with one alias, a held and a free slot of one group |
| `oracle` 3 | 1 | R-AL3 | 16 free slots then a pair with no fit: a search that does not learn takes 24.8 s, the oracle 1 s |
| `oracle` 5 | 1 | R-PH13, R-PH10, R-C1 to R-C9, R-SP24, R-DT2 | `Oracle.step` equals `Pick.step` for 480 worlds, each also with the lists reversed. 157 Need, 292 Done (105 with moves), 31 failures |
| `oracle` 4 | 1 | R-WS2, R-AL3 | a pair conflict of one group, 16 free slots: without it the closure walk needs 2^16 tuples |
| `packages/resolve/tests/moves.roc` 1 | 1 (12 rows) | R-SP24 | the order of values |
| `moves` 2 | 1 (9 rows) | R-SP24, R-VA6 | the order of variables |
| `moves` 3 | 1 (8 rows) | R-C1, R-C4, R-C6, R-C7, R-C9, R-SP23 | the constraints of a movable slot, a compiler slot is not movable |
| `moves` 4 | 1 | R-SP24, R-VA6, R-DT2 | a brute-force search written from the rule text: 192 requests (24 seeds, movable sets, both strategies). 32 fail, 16 move a, 8 move c, 24 keep |
| `pick`, `pickclosure`, `pickmoves` | unchanged | R-PH10, R-AL9, R-SP24 | run on `Oracle.step` |
| selftest `oracle` | 1 row | wiring | `PickLoop.roc` has `Oracle.step(` and not `Pick.step(`. `main.roc` has the path entry |

New L0 expects: 9. Time: l0 is 7.6 s before and 8.3 s with the reference (budget 10 s). Selftest 8.6 s (the same), l1 30.2 s, l2 1.4 s, l3 9.8 s, check 1.2 s.

## 6. Decisions the design does not fix

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `Solver.step_moves(req, names)` is a new function. `step` stays as it is | A new field `movable` in `Solver.Slot`: `??` defaults are not allowed in a structural record type, so all old tests would change |
| D2 | `Oracle.step` has the input and output of `Pick.step`. It keeps `Pick.Slot` and the texts | A new input type: all L0 rows of P0 would change, and no row would show that the result is the same |
| D3 | The closure problem is the whole tuple as one conflict (034 Q3 (a)). The `Need` list uses the optimistic tuple (a release with no fact has an empty fact), so one `Need` has the slot releases and the deeper nodes, as in P0 | Ask for the nodes of the closure in a second `Need`: it changes the `Need` rows of `pickclosure.roc` and many `calls.log` files |
| D4 | The wiring is checked by the selftest (2 greps) | An L2 case: output is equal, so no case can fail |
| D5 | `Pick.step` stays after the slice (the oracle of the differential row). The code agent can move it to `tests/` later | Delete it: the row `oracle` 5 has no oracle then |
| D6 | The solver slot name is `s<index>` | The alias `id`: one alias names 2 groups (R-WS8) |
| D7 | The pair conflict for slots of one group is made by the step, for each release of the first slot | Leave it to the closure walk: same result, 2^16 tuples (row `oracle` 4) |

## 7. Questions (TW17)

| Q | Question | Options | Proposal |
| --- | --- | --- | --- |
| Q1 | Which compiler list D does a command that resolves use? The list read forces a fetch, and offline gives exit 15 (033). | (a) Always read it: `add` offline fails. (b) Read it only when a probe or a check needs it (036b). (c) The cached list, no fetch | (b). Part 036c |
| Q2 | A ladder failure (steps 2 and 3, R-AL6) feeds back as which conflict? | (a) The whole tuple. (b) The releases that the failure blames (the new errors name a module, R-SO19). R-PH13 says P1 tries other tuples | (a), then (b) when the blame is known. Part 036b |
| Q3 | Where is the used-module scan (R-UM1) done for a candidate? | (a) In the loop, after `Done`: chosen releases with a known fail and no `Use` need a scan, then step again. (b) For all candidates before the first step | (a). Part 036b |
| Q4 | How does one prompt accept the required download and refuse the optional ones (R-NI4, R-DL1)? | (a) The one prompt lists both, and one answer covers both. (b) Two prompts. (c) The required download in the prompt, the optional ones only with `--probe-downloads` | Not decided. R-NI4 default is "No download" for optional ones, so (c) fits the design. Part 036c |
| Q5 | The optional downloads of a held-nightly command: where does the list of other nightlies come from (R-RP2 "the oldest nightly that works")? | (a) D. (b) The installed ones only | (a) with the cap R-DL6. Part 036c |
| Q6 | U3 (R-BL6 and R-SO22): does `--no-check` run the unit probes? PLAN-P1 recommends R-SO22 (no probe at all). The loop needs the answer for `--no-probe` and `--no-check` together | (a) R-SO22 wins. (b) R-BL6 wins | (a). Part 036b |

U4 (the union of module sets of inferred fails) is decided and applied in 033. It needs no test here.

## 8. Out of scope of part (a)

| Rule or item | Part | Reason |
| --- | --- | --- |
| R-AL6, R-AL7, R-LF2 (`--no-probe`), R-OV2 | 036b | They need facts and probes in the loop |
| R-UP7 (budget over both searches, exit 12) | 036b | Same. 035 Q2: a spent budget and `--no-probe` are `probes: Off` |
| 035 Q1 (explanation text, `fix:` lines, `--json` for the causes) | 036b, 036c | Output proposals (TW24), after the probe causes exist |
| R-DL1, R-DL6, R-NI4, the line `skipped N compiler downloads` | 036c | Optional downloads |
| The Epochs wiring (033) | 036c | Q1 |

## 9. Output proposals (TW24)

Part (a) has no new output text: the failure lines and the notes are those of P0 (row `oracle` 5 proves it). The proposals for 036b and 036c (not tested yet):

| Output | Proposal |
| --- | --- |
| Budget spent | `tln: error[budget]: ... probe.max ...` exit 12, `--json` `error.code` `budget` |
| `skipped N compiler downloads` | one line on stderr after the pick, only when N is more than 0 |
| `fix:` lines | one line for each cause: `fix: tln add <pkg>@<older>` and `fix: run with --probe-downloads` |

## 10. Compiler limits met

| Limit | Handling |
| --- | --- |
| `??` default in a structural record type is rejected | Q: D1 (an additive function) |
| `List.range` does not exist | `List.repeat(0, n).map_with_index(|_, i| i)` |
| Typed literals | `0.U64` in the test files |
| The test step has no per-test time limit | the rows `oracle` 3 and 4 end in 1 s with a learning search and in more than 24 s without |

## 11. Verify results

Red run (stubs in the tree, `research/slice-036-revert/red-run.log`): `check` pass, `fmt` pass, `l2` pass, `l3` pass, `l1` pass.

| Step | Result | Why |
| --- | --- | --- |
| l0 | FAIL | `todo` in `oracle`, `moves`, `pick`, `pickclosure`, `pickmoves`. All other unit files pass |
| selftest | FAIL (2 rows) | `oracle` (the wiring, as designed). `unit guard`: its copy runs l0 with the new unit files, which fail while the stubs are in the tree. It is green with the code |

Green run with the reference (`green-run.log`): all 7 steps pass (l0 8.3 s, selftest 8.6 s, l1 30.2 s).

Revert check (13 mutations of the reference, filtered runs, `mutate.py`, `revert-results.txt`):

| Id | Change | Caught by |
| --- | --- | --- |
| O1 | a closure problem is no conflict, the step gives up | `pickclosure` |
| O2 | no pair conflict for one group | `oracle` (timeout: 2^16 tuples). Not caught by any other row: the closure walk gives the same result |
| O3 | no movable slot first | `pickmoves` |
| O4 | a movable slot is open in the first search | `pickmoves` |
| O5 | no optimistic tuple for `Need` | `pickclosure` |
| O6 | slot names by `id` | `oracle` |
| O7 | the text of an empty domain is lost | `pick` |
| S1, S2 | `Highest` and `Lowest` go the wrong way first | `moves` |
| S3 | the movable slots are last | `moves` |
| S4 | `Need` not in slot order | `moves` |
| S5 | `current` is not first | `moves` |

Test gap found and closed: O2 first was NOT CAUGHT, so row `oracle` 4 was added.

## 12. Notes for the code agent (N rows)

| N | Note |
| --- | --- |
| N1 | Make `Pick.empty_domain`, `Pick.closure_verdict` and `Pick.chosen_for` public (about 20 lines moved out of `Pick.step`). `Oracle.step` needs them for the failure text, the closure walk and the `Chosen` records |
| N2 | `cli/lib/PickLoop.roc`: replace `Pick.step(` by `Oracle.step(` and add `import Oracle`. No other change. The selftest row `oracle` checks this |
| N3 | `Oracle.step` is the contract of its doc table. `Solver.step_moves` has its 4 rules in its doc. `Solver.step` must equal `step_moves(req, [])` |
| N4 | `Need` uses the optimistic tuple (D3): one `Need` has the slot releases and the deeper closure nodes, as in P0 |
| N5 | `Pick.step` stays (D5). The private reference was deleted at the review: write the code from the contract and the tests |

## 13. Review (manager, 2026-10-24)

| Item | Answer |
| --- | --- |
| Split | Accepted. 036 is part (a). The manager added rows 036b (probe rounds) and 036c (Epochs, optional downloads, `fix:` lines) to `PLAN-P1.md` |
| Q1 to Q5 | Answered at the review of 036b and 036c |
| Q6 | It is the user's U3. Open |
| D1 to D7 | Accepted. D4 (wiring checked by a selftest grep) is accepted only because the output of part (a) is equal to P0. 036b must add an L2 case that shows the loop |
| Oracle row 4 (2^16 tuples, caught by timeout) | Keep only if the correct code runs it in well under 1 s. Measured with the reference: `oracle.roc` takes 0.87 to 0.89 s without row 4 and 0.91 to 1.08 s with it (4 and 5 `expect`s, compile included), so row 4 costs less than 0.2 s. Kept. `scripts/test.sh` has no per-test time limit yet, so a wrong code hangs the l0 step. The manager adds the limit after this slice |
| Notes for the code agent | Written as N1 to N5 (section 12) |
| Reference | `research/slice-036-revert/reference/` and `swap.sh` are deleted. `mutate.py` needs both, so it cannot run again |

## 14. Code result (code agent)

`scripts/test.sh` exit 0: check 1.7 s, fmt 0.1 s, l0 8.2 s (budget 10 s), l2 1.8 s, l3 9.8 s, selftest 8.6 s, l1 29.3 s. `OPT=speed scripts/test.sh` exit 0: l0 9.0 s, l2 114.5 s (over budget, known reason), the others in budget. No test, fixture or expected file changed (no dispute rows).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Oracle.roc` | 191 | `Oracle.step` (the stub is replaced) |
| `packages/resolve/Solver.roc` | 508 | `step_moves` (the stub is replaced). `step` is `step_moves(req, [])`. Helpers `moved_var`, `in_slot_order`, `asks_in_slot_order` |
| `cli/lib/Pick.roc` | 432 | N1: `empty_domain`, `closure_verdict`, `chosen_for` are public. `closure_of` and `step` call them |
| `cli/lib/PickLoop.roc` | 76 | N2: `import Oracle`, `Oracle.step(` |

`cli/lib/main.roc` has the path entry and `Oracle` already: no change.

How `Oracle.step` works (`cli/lib/Oracle.roc`): `Pick.empty_domain` first (the failure text of an empty domain), then `search` (line 174). `first_tuple` calls `Solver.step_moves` and, for a `Need`, adds an empty fact for each asked release and calls again (D3, N4: the tuple is the optimistic one). `Pick.closure_verdict` walks the closure: `Problem` adds the whole tuple as a conflict and the search goes on, `Fine(ids)` is `Need(ids)` or `Done`.

Signatures of the public functions in `Pick` (the slice file fixed only the names):

| Function | Signature |
| --- | --- |
| `empty_domain` | the input record of `step` `-> Try(Fail, [NoFailure])` |
| `closure_verdict` | `{ members, nodes, picked : List({ files, is_platform, url }) } -> [Problem, Fine(List(Str))]` |
| `chosen_for` | `{ slot, url, version, published_at, now, min_age } -> Chosen` |

Decisions that the slice does not fix:

| Decision | Rejected |
| --- | --- |
| `closure_verdict` takes `members` and `nodes`. `Oracle` builds them in 2 lines (as `Pick.step` does) | A 4th public function `closure_ctx` (N1 has 3 functions). The private `Pick.search` needs `nodes` once, not for each leaf |
| The text "do not fit together" of `Fail` is written again in `Oracle.search` (one line) | A 4th public function `Pick.no_fit` (not in N1) |
| `chosen_for` takes `url`, `version`, `published_at`, not an `Index.Candidate`: the solver `Chosen` has no candidate | `Oracle` builds a fake candidate |
| `Pick.too_young` (private) takes `now`, `min_age`, `published_at` (it was `Step`, `Cand`): `chosen_for` has no `Step` | A copy of the formula |
| The pair conflict (D7) is exact: for each release `a` of the first slot, the releases of the second slot in the group of `a` and not `a` (`Oracle.same_group`). It is `Pick.conflicts` for the pair | `NotIn [a]`: it also forbids a release of another series (a slot with candidates of 2 series, `any_series`) |
| The group of a slot (the solver `group`) is the group of `current`, else of the first candidate in the byte order of the URLs (R-DT2) | The first candidate in the given order |
| `Solver.step_moves` reorders the slots (movable first), builds a `Var` with `moved_var` for a movable slot (`Domain.values` in both strategies: ties stay in byte order of the ids) and puts `Done` and `Need` back in slot order. The reorder is off when no slot moves, so `step` is as before | A new field in `Solver.Slot` (D1), a second solver search |
| A `Need` ask is in the place of the first slot that has the release as a value (doc rule 4) | The place of the slot that chose it |
| A movable slot with no parsed `current`: every value is "lower" (as `Pick.nearest`) | Keep the order of the strategy: it differs from `Pick.step` for `Lowest` |

Questions (TW17): none. Compiler limits: none new.

## 15. Verify results (code agent)

Revert check of the code: 10 mutations of the tricky behaviors (order, guards, conflicts), filtered runs, `research/slice-036-revert/agent-mutate.py`, log `agent-mutate.log`, notes `agent-results.md`. Caught 10 of 10. The 4 files equal `code-final.sha256` after the run.

| Id | Change | Caught by |
| --- | --- | --- |
| A1 | a closure problem is no conflict, the step gives up | `pickclosure` |
| A2 | no pair conflict for slots of one group | `oracle` (timeout, 2^16 tuples) |
| A3 | no movable slot in the second search | `pickmoves` |
| A4 | a movable slot is open in the first search | `pickmoves` |
| A5 | the optimistic fact of a platform slot has the kind Package | `oracle` |
| A6 | slot names by `id` | `oracle` |
| A7 | `published_at` of the chosen release is 0 (no note) | `pick` |
| S1 | `Need` not in slot order | `moves` |
| S2 | `Done` not in slot order | `moves` |
| S3 | the compiler slot is movable | `moves` |

## Close (manager, 2026-10-24)

The code decisions of section 14 are accepted. The one-line "do not fit together" text in `Oracle.search` is a small copy of `Pick.step`; it goes away when 036b replaces `Pick.step`. The revert check (the user rule of 2026-10-23: about 10 tricky mutations) caught 10 of 10, so no gap rows are needed. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 8.3 s of 10 s, l1 30.6 s). Status: done.
