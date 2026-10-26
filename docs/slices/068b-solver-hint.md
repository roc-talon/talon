# 068b The solver asks for the `.roc-version` hint

Phase: P1. Status: done

Slice 068b is the plan row 068b of `PLAN-P1.md` (section 2c), from question Q2 of slice 068: no command calls `Github.hint!`, but R-DI8 says that the solver asks for the hint "only when the solver needs a hint for that candidate" (Resolution 3, rank 4). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files are in `research/slice-068b-revert/before/` (`NEW.txt` lists the new files).

## 1. Where a hint can change the choice (the test agent read the code)

R-EF2 says that a hint never decides: it "only orders the search". So rank 4 cannot change which release Talon writes (the real facts and the priority do that, R-AL3, R-EP12). It can change one thing: which unit probes run first. R-AL4 gives that order: "For each pair (hash, roc) with no fact, run a unit probe. Order: installed nightly first, then the strongest hint."

| Place | Ranks used today | Where the order matters | Hint here? |
| --- | --- | --- | --- |
| `Oracle*` and `Solver` (the choice of the tuple) | Rank 1 (db rows) and the inferred facts (R-EP6). No rank 3 to 6 | Never: the tuple is the first one in the order of `priority` that no real fact excludes (R-VA6, R-SP12) | No |
| `PickLoop.probe_round!` (the unit probes of the pairs that the solver asks for) | None | `Units.budget` cuts the round to `room` pairs when `probe.max` is smaller than the round (R-P5, `cut`): `pairs.take_first(budget.run)`. Only then the order decides which pairs run | Yes, only when `cut` is true |
| `UnitFlow.first!` (ladder step 1, the units of the final closure) | None | The same cut, in the order of the nodes of the closure | No (manager answer Q2) |
| `ProbeRange.step` (`tln probe --range`) | Ranks 1 and inferred | The bisection (R-PB3) has its own order. No rule says that a hint changes it | No |
| `EvidenceFlow.blocks!` (`tln why`) | Ranks 1, 3, 4 | Shows the line only. It reads the cache file, never asks (slice 068) | Done in 068 |

So the one place is `PickLoop.probe_round!`, when the budget cuts a round: the loop calls `Github.hint!` for the release of each pair of that round (R-DI8: the answer is cached, `--offline` uses only the cache), and the pairs with the hint run first. A round that the budget does not cut asks for no hint: all its pairs run, so the order cannot matter.

## 2. Rules

| Id | Text (short) | Tested by |
| --- | --- | --- |
| R-AL4 | The order of the unit probes: "installed nightly first, then the strongest hint". Here: a pair whose release has the rank 4 hint for its compiler runs before a pair that has none | L0 `OracleprobeTest` expects 9 and 10. L2 `upgrade/ug4-hint-order` run 1 |
| R-DI8 | The hint is asked for "only when the solver needs a hint for that candidate", one request for a tag with no cache file, the answer is kept, `--offline` uses the file only | L2 `ug4-hint-order` runs 1 and 2. Every other L2 case: no `.roc-version` call in a round that the budget does not cut (the `calls.log` of the old cases do not change) |
| R-EF1 rank 4, R-EF2 | The hint is a `pass` hint for the compiler that the file names (`Pin.same_id`, R-CV1: 2 tag forms are one compiler). A hint only orders: no result of a probe or of the solver changes | L0 expect 10. L2 run 1 (the 2 facts that ran are real facts of the probes) |
| R-P5, R-UP7, R-EC12 (as used) | The cut round: the pairs that did not run are `N unit checks did not run`, exit 12 | L2 `ug4-hint-order` runs 1 and 2 |
| R-DI9 (as used) | The request has no token | L2 `ug4-hint-order` run 1 (`calls.log`: only `User-Agent`) |

`MISSING=1 scripts/rules.sh R-DI R-EF R-AL` lists no id after this slice that it listed before.

## 3. Flow (what the L2 case fixes)

`PickLoop.probe_round!` (the new line is the one with the `hinted!` call, the rest is as before):

| Step | Work | Calls |
| --- | --- | --- |
| 1 | `Units.budget`: `Err(Spent)` or `run == 0` is exit 12, as before (no hint call) | none |
| 2 (new) | `budget.cut` (the round has more pairs than `room`): `ordered = hinted!(fx, request, pairs)`. Else `ordered = pairs`, no call | none when not cut |
| 2a | `PairOrder.asks(pairs)`: the release URLs of the pairs that are GitHub release URLs (`Github.hint_ref`), each once, in the order of the pairs | none (pure) |
| 2b | For each ask, in order: `Github.hint!` with `request.net`, `request.roots`, the owner, the repo, the tag and `request.offline`. The calls of `hint!` are the ones of slice 068 (a `read_files!` of the cache file, then for a missing file one `http_get!` of the raw URL and one `write_atomic!` for a 200 or a 404; `--offline`: no request). `Ok(Ok(compiler))` is the hint, any other result is no hint (D3) | the calls of `hint!` |
| 2c | `PairOrder.order({ pairs, hints })`: the pairs that have the hint first, then the others, each group in the old order | none (pure) |
| 3 | `PickOptional.step!` and the rest get `ordered.take_first(budget.run)` in place of `pairs.take_first(budget.run)` | as before |

The calls of step 2b come after the `db_query` of the round (`round!`) and before `list_dirs` of the toolchains (the start of the compiler).

## 4. Public signatures (the code agent keeps them)

| Function | Signature | Stub |
| --- | --- | --- |
| `PairOrder.asks` | `List(OracleBase.Pair) -> List({ id : Str, owner : Str, repo : Str, tag : Str })` | `crash "todo: slice 068b"` |
| `PairOrder.order` | `{ pairs : List(OracleBase.Pair), hints : List({ id : Str, hint : Try(Str, [None]) }) } -> List(OracleBase.Pair)` | same |

Wiring that the test agent wrote (it is not a stub): `cli/lib/main.roc` exposes `PairOrder`. The code agent writes: the 2 bodies, and in `PickLoop.probe_round!` the private `hinted!` (a `Fx` function: `PairOrder.asks`, `Github.hint!` for each ask, `PairOrder.order`) and the `ordered` line of step 2/3. `PickLoop` gets the imports `Github` and `PairOrder`. No other module changes.

## 5. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/PairOrder.roc` | 18 | New: the 2 stubs, docs |
| `cli/lib/main.roc` | 219 (+1) | `PairOrder` is exposed |
| `tests/unit/OracleprobeTest.roc` | 305 (+54) | 2 new `expect`s at the end (driver `l0-8`) and the import of `PairOrder` |
| `tests/commands/cases/upgrade/ug4-hint-order/` | 2 runs | New case (a copy of the fixtures of `upgrade/ug2-lag`: the runs of one case share the db, so a run with real facts has nothing to probe) |
| Old cases | 0 | No old expected file changes |

## 6. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L0 | `OracleprobeTest` expect 9 (6 rows) | `PairOrder.asks`: none, one pair (owner, repo, tag), the order of the pairs, the same release on 2 compilers once, a release URL of another host has no ask, a value that is no release URL | R-DI8 R-EF1 |
| L0 | `OracleprobeTest` expect 10 (9 rows) | `PairOrder.order`: no pair, no hint, a hint for the third pair, 2 hints (the order of the pairs, not of the hints), a hint for another compiler, the other tag form of the compiler, a failed or missing hint, a hint for a release that is not in the pairs, one release on 2 compilers (only the pair of the named compiler) | R-AL4 R-EF1 R-CV1 R-EF2 |
| L2 | `upgrade/ug4-hint-order` run 1 | `upgrade` with `probe.max = 2`, 4 pairs with no fact (json 2.2.0, text 2.0.0, parser 1.1.0, pfx 0.1.1). The round is cut. json has no cache file and the raw URL answers 404 (the empty file is written, no hint). text and pfx have a cache file with the compiler (no request, the hint). parser has no file and the raw URL answers 500 (not kept, no write, no hint, the command goes on). The probes are text and pfx, not json and text: exit 12, `2 unit checks did not run`. The 2 facts are in the db | R-AL4 R-DI8 R-EF1 R-EF2 R-DI9 R-P5 R-UP7 R-EC12 |
| L2 | same, run 2 | `upgrade --offline`, `probe.max = 1`, after run 1: 2 pairs are left (json, parser), cut to 1. The file of json (the 404 of run 1) is read, parser has no file: `--offline` makes no request. No hint, the old order: json is probed. exit 12, `1 unit check did not run`, the line `index: cached at <time>` | R-DI8 R-DI12 R-AL4 R-P5 R-EC12 |

L0 count: 2 new `expect`s in 1 file (`OracleprobeTest`, driver `l0-8`). Deep cases: 1 new L2 case (2 runs).

## 7. Output (proposed, TW24, R-OUT2)

None new. The stderr texts are the old texts (`Units.spent`, `Github.hint!`). The hint calls write cache files only (R-DI8).

## 8. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The loop asks for hints only when the budget cuts the round (`budget.cut`). Else no call: the order cannot change which pairs run | A hint call for each pair of each round (many requests that change nothing: R-DI8 says "only when the solver needs a hint", and the cost table of CLI 7.3 has 1 small file for each hint). The mutation m1 shows that this choice is tested |
| D2 | The order is a stable partition: the pairs with a rank 4 hint for their compiler first, the others after, each group in the order of the solver | A sort by the rank of the hint (there is one rank in this slice, Q1). A sort by version or date (R-AL4 names no such key) |
| D3 | A `hint!` that fails (a request that gives 500, a network error, a write that fails) is no hint, and the command goes on, with no output. R-EF2: a hint only orders the search, so a failed ask must not stop the command. Slice 068 D4 left the decision to the command | Exit 15 (the command would fail for a hint) or a warning line (a new text for each failure, and the order is not worth a line) |
| D4 | One `hint!` for each distinct release URL of the round, in the order of the pairs. A release URL of another host has no ask (`hint_ref`, slice 068 D7) | One call for each pair (the same tag on 2 compilers would read the file twice) |
| D5 | The new case is a copy of the fixtures of `ug2-lag`, with the project `q1h` (budget 2) and `q1o` (budget 1) | A run in `ug2-lag`: its run 1 leaves the facts in the db, so the next run has no pair to probe |

## 9. Out of scope

| Part | Reason |
| --- | --- |
| The ladder (`UnitFlow.first!`, step 1 of the ladder on the final closure) | Manager answer Q2: the ladder keeps its order |
| Ranks 3, 5 and 6 and "installed nightly first" of R-AL4 | Manager answer Q1: rank 4 only for now |
| A hint for the range search of `tln probe --range` (R-PB3) | R-PB3 gives no hint rule. `ProbeRange.step` has its own bisection |
| `--no-probe` (`Off`): no probe, so no cut and no hint | R-EP9: the step never asks for a probe |
| The failing write of the cache file by `hint!` | Slice 068 D6 |
| L3 | The L2 case is the contract. The real `Fx` has the old case `index/di1-github-pages` for `hint!` |

## 10. Questions and manager answers (2026-10-26)

Decisions D1 to D5 are accepted. Answers:

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Which ranks does the order use, and is "installed first" part of it? | Rank 4 only for now (option (a)). Ranks 3 and 5 are a follow-up, rank 6 needs the registry (P2) |
| Q2 | Does the hint order apply to the ladder (`UnitFlow.first!`)? | No: the ladder keeps its order (option (a)) |

## 11. Red output

Run with the stubs in the tree and the private reference away (the reference of slice 070b is away too: its 2 cases are red).

| Step | Result |
| --- | --- |
| check, fmt | pass (the stubs compile, `roc fmt --check` exits 0) |
| l0 | FAIL (7.6 s): `l0-8` (`OracleprobeTest`): 81 passed, 2 failed, the 2 new expects (`todo: slice 068b`). All other files pass |
| l2 | FAIL (9.8 s): `upgrade/ug4-hint-order` (the hint calls are missing in `calls.log`, the probes are json and text, in place of text and pfx: a wrong value). 2 more cases are red for slice 070b. The other cases pass |
| l3, selftest, l1 | pass |

With the reference in the tree the 2 new expects and the 180 L2 cases pass (no old case changes).

## 12. Revert check (TW12)

7 changes of the private reference, one at a time, compile-checked, with filtered runs (L0 `l0-8`, L2 `upgrade/ probe/ moves/ resolve/`). The reference is put back after each change. All 7 are caught. The script and the reference are deleted (manager, 2026-10-26).

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | The loop asks for hints in every round, not only in a cut round (D1) | L2: at least 8 old cases (`moves/hm1`, `hm2`, `hm3`, `probe/dm1`, `lp1`, `lp2`, `pb1`, `sc1`: a `.roc-version` call that they do not have) |
| m2 | `hint!` gets `offline: Bool.False` | L2 `ug4-hint-order` run 2 (a request in `calls.log`) |
| m3 | The pairs with the hint come last | L0 expect 10, L2 `ug4-hint-order` |
| m4 | The group with the hint is reversed (not stable) | L0 expect 10, L2 `ug4-hint-order` |
| m5 | `asks` does not drop a repeated release URL | L0 expect 9 |
| m6 | `order` compares the compiler ids with `==` (not `Pin.same_id`) | L0 expect 10 |
| m7 | The cut takes the pairs in the old order (the order is computed, not used) | L2 `ug4-hint-order` run 1 |

## 13. Next step

The manager accepted the tests and answered Q1 and Q2 (section 10). The code agent writes the 2 bodies and the `hinted!` function (section 4). The private reference is deleted.

## 14. Disputes (from the code agent)

| Test | Change | Design source |
| --- | --- | --- |
| `tests/unit/OracleprobeTest.roc`, `expect` 9 and 10 | A plain bug: the test did not compile (`duplicate definition`: the parameter `nightly` of `pair` and the local `json` hid the top-level `nightly` and `json`). The parameter is now `compiler` (the field is still `nightly`), the local `json` of expect 9 is `jv`. No row, no value and no expected result changes | none needed (a name clash, TW18 allows a plain bug) |

## 15. Verify results (code agent, TW12)

6 mutations, one at a time, each put back (the files are equal to `research/slice-068b-revert/code-final/`).

| Id | Mutation | Result |
| --- | --- | --- |
| m1 | `hinted!` is called in every round (`pairs.len() > 0` in place of `budget.cut`) | Caught: L2 `consent/dl1-resolve`, `dl3-rank4`, `evidence/ev3-summary` and more (a `.roc-version` call that they do not have) |
| m2 | `hint!` gets `offline: Bool.False` | Caught: L2 `upgrade/ug4-hint-order` |
| m3 | The pairs with the hint come last | Caught: L0 `l0-8` (expect 10) |
| m4 | `asks` keeps a repeated release URL | Caught: L0 `l0-8` (expect 9) |
| m5 | `order` compares the compiler ids with `==` | Caught: L0 `l0-8` (expect 10) |
| m6 | The order is computed but the cut takes the old order | Caught: L2 `upgrade/ug4-hint-order` |

Not caught: none.

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-068b-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, both slices in) | Exit 0, all 7 steps |
| Gap step | Skipped: 11 of 11 code-agent mutations caught, no new decision that needs a test |
| Dispute (`OracleprobeTest` expects 9, 10) | Accepted: a name clash (`duplicate definition`) fixed by renaming a parameter and a local; no row or value changed. |
