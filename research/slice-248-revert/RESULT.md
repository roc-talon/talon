# Slice 248 mutation check (TW12, R-AL10 to R-AL17)

Script: `research/slice-248-revert/mutate.sh [mutant names]`. Log: `run.log` (the main run), `run-m8.log` (a re-check of m8). Each mutant is a `sed` edit of a mirror (`.tmp/slice-248-mut/`, deleted at the end; the working tree is not changed; the mirror holds the uncommitted `packages/records` of the other session). Compiler: `$ROC` of `scripts/env.sh` (ROC_TAG nightly-2026-10-14-38a3029). Each test run holds `.tmp/heavy.lock` and runs capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one mutant at a time. L2 binary built with `--opt=dev`. Tests per mutant: the l0-2 driver (SolverifaceTest, ExplainTest, ...), the 4 `packages/resolve/tests/*.roc` (conflicts, domain, moves, solver), and `tests/commands/run.sh upgrade/ur9 probe/ resolve/`. The l0-9 driver is not used. Baseline: l0-2 106 passed, conflicts 6, domain 2, moves 5, solver 5, L2 60 passed.

Reading of `run.log`: a file that passes prints `All (N) tests passed`; a file that fails prints only `0 compiler errors` (the last line of the failure report). A file with no summary at all ran into the 600 s limit. The `exit=` words of `run.log` are wrong (a shell bug: they always show 0); the script now keeps the real exit code (124 = the limit). `run-m8.log` was made with the fixed script.

Result: 12 mutants. 11 caught, 1 equivalent (m4), 0 NOT caught. Two mutants (m8, m9) are caught by the time limit (a loop), not by a failed expect.

| # | Mutant (place) | Behavior (slice list) | Result |
| --- | --- | --- | --- |
| m1 | `Explain.lines_held`: a run of H alone gets a line | M1 | caught: l0-2, L2 probe/dm1-domain, lp1-loop, un1-units |
| m2 | `Explain.lines_held`: a run of one compiler that is not H gets no line (B11 reverted) | M2 | caught: l0-2, L2 upgrade/ur9-no-tuple-run |
| m3 | `OracleCause.causes_of`: the kind of a fault from the row of H (B12 reverted) | M3 | caught: l0-2, L2 ur9-no-tuple-run |
| m4 | `Solver.var_of`: keep a candidate whose version does not parse | M4 | EQUIVALENT: all tests pass, and `Domain.values` (called just before, rule 2 of its doc: "a version that does not parse is not a value") already leaves such a candidate out, so the `keep_oks` of `var_of` is a second filter |
| m5 | `Solver.var_of`: the compiler slot in the order of D for both strategies | M5 | caught: l0-2, conflicts, moves, L2 ur9 |
| m6 | `Solver.asks_of`: probes together with the missing headers | M6 | caught: l0-2, conflicts, moves, solver |
| m7 | `Solver.pf_incs`: R-C3 with 2 or more platform slots | M7 | caught: l0-2, solver |
| m8 | `OracleRequest.request_of`: drop `same_group` | M8 | caught by the time limit: l0-2 ran 600 s with no result (exit 124, confirmed in `run-m8.log`). The expect of R-AL14 row 5 does not fail: the solver loops with no `same_group` clash. L2 passes (60) |
| m9 | `SolverBase.norm`: keep a term that holds all values of its slot | M9 | caught by the time limit: l0-2, conflicts, moves, solver and the L2 run all hit 600 s (the search does not end) |
| m10 | `SolverWhy.step_of`: terms in the order of the search (B8 reverted) | M10 | caught: l0-2 only (L2 passes: no user text reads the order) |
| m11 | `OracleCause.blame_text`: a fault gives `(no module is named)` | M11 | caught: l0-2, L2 ur9-no-tuple-run |
| m12 | `SolverWhy.step_of`: the ids of a term in the reverse order (a strategy order, not R-SP24 rule 2) | M12 | caught: l0-2 and conflicts. L2 passes |


## Notes and weak spots

| # | Note | Suggested test |
| --- | --- | --- |
| W1 | m8 and m9 are caught only because the code loops, so a failing expect does not name the rule. A loop in `roc test` costs 600 s and may be killed by a slower limit in CI (`TEST_TIMEOUT`, 30 s for l0). | A test of R-AL14 row 5 that cannot loop: give the solver a step or size limit in the test (a request with 2 slots of one group, expect `Fail` with the clash term). For m9: an expect on `SolverBase.norm` alone (`norm(sizes, [lit with all places])` gives `Ok([])`) so the failure shows at once. |
| W2 | m10 is caught at l0 only (by design: no user text reads the order of the terms; Q-248 note). | None. |
| W3 | m4: the filter in `var_of` is dead code while `Domain.values` filters first. | Not a test gap. A cleanup for the code agent, or an expect on `var_of` with a candidate that the domain lets through. |

## W1 follow-up (test agent, 2026-11-14): m8 and m9 now fail on an expect

New module `tests/unit/SolverformTest.roc`, in the driver `l0-3` (its header now also names `resolve`). `l0-3` runs no solver search, so a mutant that makes the searches loop cannot hide these expects. In `l0-2` the loops stay (m8: the R-WS2 row of `OracleTest` with 16 free slots goes back to 2^16 tuples; m9: each search), and `roc test` prints nothing when it hits the limit, so a failing expect in `l0-2` is not seen.

| Expect | Rule | What it checks |
| --- | --- | --- |
| `SolverBase.norm` alone, sizes `[2, 3]` | R-AL16, R-AL17 | A term with all places is left out (`Ok([])`); a join of 2 terms of one variable; a term with no place is `Never` |
| `OracleRequest.request_of(...).conflicts` | R-AL14, R-WS2 | 2 free slots of acme/json series 1 give the conflict `s0 = 1.1.0 & s1 = 1.0.0`, before the conflict of the ladder |

Run: `L0F=tests/unit/l0-3.roc L2=0 research/slice-248-revert/mutate.sh m8 m9` (log `run-w1.log`): 8 s for both.

| # | Result |
| --- | --- |
| m8 | caught at once: l0-3 exit 1. The failing expect is `SolverformTest.roc:52` (R-AL14 R-WS2): got `s0:1.0.0` (the ladder conflict only), want `s0:1.1.0 & s1:1.0.0 \| s0:1.0.0` |
| m9 | caught at once: l0-3 exit 1. The failing expect is `SolverformTest.roc:36` (R-AL16 R-AL17): got `ok 0:0,1` for a term with all places, want `ok ` |

The names of the failing expects come from a manual re-run of the same 2 `sed` edits on a mirror under `.tmp/` (capped, under the heavy lock). Baseline after the change: l0-3 133 passed, l0-2 106 passed, `unit_modules_check` ok.
