# Slice 252 mutation check (TW12, `tln update <alias>` follows a successor; R-PU28, R-SN8, Q632)

Script: `research/slice-252-revert/mutate.sh [mutant names]` (pattern of slice 250). Logs: `run.log` (main run), `run-s11.log` (s11 re-run, see below). Each mutant is a `sed` edit of a mirror (`.tmp/slice-252-mut/`, deleted at the end; the working tree is not changed); a `cmp` check reports "SED DID NOT APPLY" (none did). Compiler: `$ROC` of `scripts/env.sh`. Each test run holds `.tmp/heavy.lock` and runs capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one at a time. Tests per mutant: the `l0-4` driver and `tests/commands/run.sh registry/ update/ upgrade/ outdated/` (the successor cases are `registry/su1` to `su12`; the outdated cases are `outdated/od*` and `registry/*outdated*`). In `run.log` a failed expect prints `exit=1 ... 0 compiler errors`; a pass prints `All (133) tests passed`. Baseline: l0-4 133 passed, L2 182 passed. No cap hit, no loop.

Result: 13 mutants. 11 caught, 2 NOT caught (s4, s13), and no mutant is equivalent. s1, s3 are caught at L0 only; s6 to s12 at L2 only (flow code).

The first s11 (`Update | Upgrade` to `Update`) did not compile (a non-exhaustive match: a compile error, not a test result). It was replaced by `Update => True, Upgrade => False` and re-run alone (`run-s11.log`).

| # | Mutant (place) | Behavior | Result |
| --- | --- | --- | --- |
| s1 | `Successor.decide`: a run with no named alias follows | R-PU28 (named only) | caught: l0-4 only. L2 passes: `SuccessorFlow.follow!` computes `named` before it calls `decide`, so the `named` test in `decide` is a second check (W1) |
| s2 | `decide`: an item with no successor follows | R-PU28 | caught: l0-4, L2 registry/yf10-update-held-count, yf4-update-named-yanked |
| s3 | `walk`: limit 5 links (off by one) | R-TP14 | caught: l0-4 only. L2 passes: no case has a chain of 5 links (W2) |
| s4 | `walk`: names are case sensitive | R-SN8 (lower case) | NOT caught (G1) |
| s5 | `walk`: a cycle is not detected | R-TP14 | caught: l0-4, L2 su6-follow-cycle |
| s6 | `SuccessorFlow.check` off | Q252-3 | caught: L2 su5-follow-no-release |
| s7 | `read!`: `--offline` with no kept copy does not stop | Q252-8 | caught: L2 su10-follow-offline-missing |
| s8 | `Outdated.is_shown`: a moved row at the newest release is not shown | Q252-9 | caught: L2 su11-outdated-successor |
| s9 | `Outdated.row_doc`: the `successor` member is always there (null) | R-J6 | caught: L2 outdated/od1, od2, od3 and 4 registry cases |
| s10 | `ResolveBase.set_edits`: the old repo name is not named | R-UP3 | caught: L2 su1 to su4, su6 to su8 and more |
| s11 | `upgrade` does not follow | Q252-1 | caught: L2 su2-upgrade-follow, su3-series-limit |
| s12 | `follow!`: the followed variable loses its series | Q252-2 | caught: L2 su1 to su8 and more |
| s13 | `as_moved`: a missing start with a successor is not forced to `moved` | Q252-4, B7 | NOT caught (G2) |

## Gaps (not caught)

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | s4 (case-sensitive walk) | No fixture has a `repos` item or a successor whose name differs in case from the name that links to it. | L0 `Successor.walk`: start `Acme/Json` with items `acme/json` (moved, successor `Acme/Roc-Json`) and `acme/roc-json` (active). Expect `end` `acme/roc-json`, state `Active`, 1 link, `Reached`. L2: a `repos` item `Acme/Old` in the answer for a header `acme/old`. |
| G2 | s13 (a `missing` start with a successor is not followed) | su cases have a `moved` start only. B7 (Q252-4: any state, a `missing` item with a successor follows) has no test through the flow. | L2 `registry/su13-follow-missing`: the `repos` item of the header name is `missing` with a successor `acme/new`. Expect `update <alias>` follows to `acme/new`. L0: `Successor.walk` with the start `missing` (the flow forces `moved`; the L0 test for the flow helper `as_moved` needs it public). |

## Weak spots

| # | Note | Suggested test |
| --- | --- | --- |
| W1 | s1: the `named` test of `decide` duplicates the one of `follow!`. A mutant of one is invisible while the other holds. | None needed. The code agent can drop one. |
| W2 | s3: the limit of 4 links is tested at L0 only. | L2: a chain of 5 links (su7 has fewer): expect the `note: ... more than 4 links. Talon stops at <4th link>.` on stdout. |

## Second run (2026-11-17): the tests for G1, G2 and W2

New tests: L0 `SuccessorTest.roc` 2 expects with names in mixed case (G1); L2 `registry/su13-follow-missing` (G2); L2 `registry/su14-follow-cut`, a chain of 5 links, cut note on stdout (W2). All pass on the code (L2 715 pass, 0 fail; l0-4 135 pass), so the code has no bug here.

| # | Mutant | Result |
| --- | --- | --- |
| s3 | `walk`: limit 5 links | caught: l0-4 and L2 su14-follow-cut (W2 closed) |
| s4 | `walk`: names are case sensitive | caught: l0-4 (the 2 new expects). L2 passes: no fixture has a name that differs in case, and none was added (L0 is enough: `walk` is pure) |
| s13 | `as_moved`: a `missing` start is not forced to `moved` | caught: L2 su13-follow-missing (G2 closed). L0 passes: `decide` and `walk` do not read `as_moved` |

Now 13 of 13 mutants are caught. W1 stays (no test needed).
