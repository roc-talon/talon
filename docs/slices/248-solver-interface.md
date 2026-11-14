# 248 The solver interface and the `no_tuple` text

Phase: P2 CLI (P0 and P1 rules with no test: `MISSING=1 scripts/rules.sh R-AL` listed R-AL10, R-AL11, R-AL13 to R-AL17). Status: done (2026-11-14; Design Q628, G-C258). On 2026-11-14 the user approved Q-248-1 and Q-248-2 as recommended, and allowed the code agent to edit `packages/resolve` for B8 (`packages/records` stays off limits). The design ids: Q628 (G-C258). Test agent: 2026-11-14.

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-AL13 | A variable is a slot (a free direct dep, the platform, `roc`). A transitive group is no variable. Values: the candidates of section 2, best first (semver, `highest` or `lowest`); 2 ids of one version in byte order; a version that does not parse is no value; a range still excludes the header value. The compiler slot: the releases of D, in the order of D. |
| R-AL14 | The request: slots, rules (`now`, `min-release-age`, `snapshot`, `strategy`), header facts, conflicts of the caller (for example 2 slots of one group, R-WS2), the compatibility record (D, checks, used modules, probe mode `Allowed` or `Off`). |
| R-AL15 | The answer: `Need(List(Ask))` (`Header(id)` or `Probe(id, nightly)`, for the best tuple only, headers before probes), `Done(List(Chosen))`, `Fail(Why)`. A release with no fact is fit. R-C3 only with exactly one platform slot. R-C2 and R-C3 only between the slots. |
| R-AL16 | PubGrub with unit propagation and conflict learning. A learned incompatibility and a caller conflict have one form. |
| R-AL17 | `Why`: a graph of steps. Terms in the order of the slots, ids best first, a term with all values left out. Causes `Probe`, `Dep`, `Pf`, `Given`, `NoValue`, `Derived`. The part of the graph that the last step needs, in the order of the search. |
| R-AL10 | First line: `tln: error[no_tuple]: no tuple works: ` + `the unit check on <H> fails for <blame>; <blame>`, with `(<Module>.roc)` or `(no module is named)`. |
| R-AL11 | One cause line for each blamed release: `  <label> fails on <from> .. <to>`; `hangs`, `crashes` for a fault; `on <id>` for a run of one compiler; no line for H alone; `(inferred on <id>, ...)`. |
| R-AL12 | Has tests already (slice 065). Named again in the L2 case of this slice. |

Source: DESIGN-RESOLUTION.md section 5 ("The solver step", the failure output), R-EP7 to R-EP11, R-VA6, R-C1 to R-C9, R-RP2, R-SP8, R-SP24; DESIGN.md R-WS2, R-PH10; DESIGN-CLI.md section 3 (exit code 10 = `no_tuple`).

## Scope (facts found in the code before any change)

Almost all of the rules are built. Old tests check most of the behaviors, but no test named R-AL10, R-AL11, R-AL13 to R-AL17.

| Rule | Where | Old tests that check it without the id |
| --- | --- | --- |
| R-AL13 | `packages/resolve/Solver.roc` `var_of` (packages: `Domain.values`, the kind filter, `Semver.parse`; compiler: the candidates in D, D reversed for `Highest`), `moved_var` | `packages/resolve/tests/domain.roc`, `solver.roc` |
| R-AL14 | `packages/resolve/SolverBase.roc` `Request`, `Compat`, `Domain.Rules`; `cli/lib/OracleRequest.roc` `request_of`, `same_group` (R-WS2), `given` (R-AL5) | `solver.roc`, `conflicts.roc`, `tests/unit/OracleprobeTest.roc` |
| R-AL15 | `Solver.step_moves` (the `Allowed`/`Off` table), `asks_of` (headers first, then probes), `kind_fits` (no fact: fit), `pf_incs` (one platform slot), `dep_incs` (slot groups only); the closure walk: `cli/lib/OracleSearch.roc` | `solver.roc`, `conflicts.roc`, `tests/unit/PickclosureTest.roc` |
| R-AL16 | `packages/resolve/Search.roc` (`run`, `resolve`), `SolverBase.Inc` (one form for all causes) | `conflicts.roc` (coloring, the 9-slot row) |
| R-AL17 | `SolverBase.Cause`, `Step`, `Why`; `packages/resolve/SolverWhy.roc` `why_of` (the cone of the last row) | `conflicts.roc` (proof check, leaves) |
| R-AL10 | `cli/lib/OracleCause.roc` `failure`, `blame_text`, `label_of`; `Units.judge` has the same text (R-PH13) | `tests/unit/OracleprobeTest.roc`, `probe/dm1-domain`, `probe/un*`, L3 `exit/ex3-no-tuple-yaml` |
| R-AL11 | `cli/lib/Explain.roc` `lines`, `cause_line`; `OracleCause.causes_of` (the kind of a fault) | `tests/unit/ExplainTest.roc`, `probe/dm1-domain` |

## Behaviors

| # | Behavior | Rules | State |
| --- | --- | --- | --- |
| B1 | Values best first by semver; 2 ids of one version in byte order (both strategies); a version that does not parse is no value; a range excludes the header value | R-AL13 | green |
| B2 | The compiler slot: the releases of D (newest first with `highest`, oldest first with `lowest`); a candidate not in D is no value; no candidate in D gives `NoValue(roc)`; a dep on a transitive group is not read | R-AL13 | green |
| B3 | The rules of the request hide a young release and a release after the snapshot; the R-WS2 conflicts make 2 slots of one group take one value; `Allowed` asks a probe, `Off` takes the pair as fit | R-AL14 | green |
| B4 | `Need`: headers of the best tuple only, before any probe, in the order of the slots; `Done` with all facts; a release with no header is fit; a wrong kind gives the next value; `Fail` | R-AL15 | green |
| B5 | R-C3 only with exactly one platform slot; R-C2 only between the slots | R-AL15 | green |
| B6 | A probe fail and a caller conflict with the same terms give the same answer and the same leaf terms; a coloring with no tuple; 9 free slots before a conflict: fast | R-AL16 | green |
| B7 | The causes `Dep`, `Pf`, `Given`, `Probe`, `NoValue` with their data; the last step has no term; a `Derived` names earlier steps | R-AL17 | green |
| B8 | In the second search (`step_moves`) the terms are still in the order of the slots | R-AL17 | **red** |
| B9 | The first line: a hard fail, a used module, a platform, 2 blamed releases joined with `; ` | R-AL10 | green |
| B10 | Cause lines: a run around H; no line for a fail or a hang on H alone; the inferred mark | R-AL11 | green |
| B11 | A run of one compiler that is not H has the line `  <label> fails on <id>` (`tln upgrade roc`) | R-AL11 | **red** |
| B12 | A hang on a compiler that is not H: the word `hangs`, not `crashes` (first line and cause line) | R-AL11, R-AL10 (Q-248-1) | **red** |
| B13 | A fault on H: the first line has `(hangs)` or `(crashes)` (also for the platform), and no cause line (Q-248-1) | R-AL10, R-AL11, R-PH13 | green |
| B14 | In a `Fail` of `step_moves`, the ids of a term of a movable slot are in the R-SP24 rule 2 order: the current value first, then the nearest (`highest` and `lowest`) (Q-248-2) | R-AL17, R-SP24 | green |

## Tests

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| L0 | `tests/unit/SolverifaceTest.roc` (new, driver `l0-2`; the driver header now also names `resolve: "../../packages/resolve/main.roc"`, as `l0-1` names `records`). 13 expects (2 added for the answers: Q-248-2 "R-AL17 R-SP24", Q-248-1 "R-AL10 R-PH13") | R-AL10, R-AL11, R-AL13 to R-AL17 | 11 green, 2 **red** (B8, B11 + B12) |
| L0 | `tests/unit/SolverformTest.roc` (new, driver `l0-3`, which runs no solver search; its header now also names `resolve`). 2 expects: `SolverBase.norm` alone, and the same-group conflicts of `OracleRequest.request_of`. Added for W1 of `research/slice-248-revert/RESULT.md`: mutants m8 and m9 made the searches loop, so they were caught only by the time limit. Now they fail on these expects in seconds | R-AL14, R-WS2, R-AL16, R-AL17 | green |
| L2 | `tests/commands/cases/upgrade/ur9-no-tuple-run` (new): 2 runs of `tln upgrade roc`, no compiler works. Run 1: the platform fails on n12 alone. Run 2: it hangs on n12 | R-AL10, R-AL11, R-AL12, R-AL17, R-EP7, R-SP8, R-SP12, R-SP24, R-RP2 | **red** (stderr only) |

Run results (2026-11-14): `roc test tests/unit/l0-2.roc`: 106 tests, 104 passed, 2 failed (the 2 red expects of this slice; all old expects and the 2 expects of the answers pass). `tests/commands/run.sh ur9-no-tuple-run`: only `stderr` differs. `MISSING=1 scripts/rules.sh R-AL`: no rule left. `unit_modules_check tests/unit`: ok. `roc fmt --check`: ok.

### Why the red tests are red (the work of the code agent)

| # | Now | Design | Place |
| --- | --- | --- | --- |
| B11 | `Explain.lines` prints a cause line only when `from != to` or with an inferred mark. It does not know H, so a run of one compiler that is not H (possible only when the compiler is free: `upgrade roc`, `upgrade X roc`) gets no line. | R-AL11: "A run of one compiler has `on <id>` and no range, and no line when it is the held nightly alone". | `Explain.lines` / `OracleCause.failure` |
| B12 | `OracleCause.causes_of` takes the kind of a `Fault` from the row of the held compiler H (`row_of(compat.checks, compat.compiler, p.id)`). A hang on n5 with no row on H becomes `Crash`. | R-AL11: `hangs` for a hang. The fault is on `p.from` (= `p.to`). | `OracleCause.causes_of` |
| B8 | `SolverWhy.term_of` keeps the order of the search: in `step_moves` the movable slots are first, so a term of a movable slot comes before the term of an earlier slot. The doc of `Solver.step_moves` rule 4 says so (slice 036). | R-AL17: "the slots, in the order of the slots". No user text reads it today (the text comes from the `Probe` causes only), so it is an API fix. | `packages/resolve/SolverWhy.roc` (the code agent edits `packages/resolve`; the doc of `step_moves` rule 4 changes too) |

A note for the code agent: `tests/unit/ExplainTest.roc` row 3 ("a fail on the held compiler alone: no cause line", `from` = `to` = n3) calls `Explain.lines` with no H. The new tests do not fix the signature of `Explain.lines`: they go through `Oracle.step_probed`, `Oracle.step_free` and the L2 case. Keep the old contract of `Explain.lines` for that row (for example, a new function or field that knows H, used by `OracleCause.failure`), so no old test changes (TW18).

### calls.log of the L2 case (GUESS status)

`expect/stdout`, `expect/exit`, `expect/calls.log` and `expect/tree.diff` are the actual files of the run before the fix. The fix changes only the text of stderr, so I expect them to stay. I read each line (TW21): each run is exit 10 and its stdout has no error; the runs read the nightly list, the index of `acme/lib` and `acme/pfx`, the headers of lib 1.1.0 and pfx 0.1.0 (the second search, R-SP24), and 3 single-key db lookups; no probe, no download, no header write, no ladder. Only `expect/stderr` is written by hand (the design text). It is not a guess about calls: if the code agent's fix adds a db read (for example to find the row of the fault), the 3 `db_query ... facts=1` lines at the end of each run can change. That is the one GUESS.

## Output (proposed, TW24)

No new text: the cause line of B11 and the word of B12 are the text of R-AL11. The first line of run 2 of the L2 case has `(hangs)`: the approved answer of Q-248-1 (the text of `Units.judge`, slice 031). No `--json` change: `error.details.causes[].kind` already has `hang` (it will say `hang` in place of `crash` for B12).

## Questions (TW17)

Both were answered on 2026-11-14: the user approved each recommended answer. R-AL10 changes its wording (a fault gives `(hangs)` or `(crashes)`). The design ids are pending.

| Id | Question | Recommended answer |
| --- | --- | --- |
| Q-248-1 | R-AL10 says the first line has `(no module is named)` "when the fail has no module (a platform fail, a fault)". The code (`Units.judge`, `OracleCause.blame_text`, R-PH13 slice 031, and the L2 cases `probe/un*`) prints `(hangs)` and `(crashes)` for a fault. With R-AL11 ("no line when it is the held nightly alone") and R-EP7 (a fault is the interval of its compiler alone), a hang on H would then show no word `hangs` anywhere. Which text is right? | Keep `(hangs)` and `(crashes)` on the first line. Change the R-AL10 text to: `(no module is named)` for a fail with no module, `(hangs)` or `(crashes)` for a fault. The L2 case `ur9-no-tuple-run` run 2 expects `(hangs)`. No L0 row checks the first line of a fault until the answer. |
| Q-248-2 | R-AL17 says the ids of a term are "best first". In the second search (`step_moves`, R-SP24) a movable slot orders its values as `current`, then the nearest. Is "best first" that order, or the strategy order? | The order of the values in that search (R-SP24 rule 2): it is the order in which the search prefers them. Only the order of the terms (B8) is a red test; no test checks the id order of a movable slot. |

A reading note, not a question: R-AL13 says the compiler values are "in the order of D". D is oldest first (R-EP11, R-NS1). R-VA6 says `strategy = "lowest"` minimizes each variable of `priority`, and `roc` is one. The tests read "best first in the order of D": the newest first with `highest`, the oldest first with `lowest` (as the code does).

## Tricky behaviors (for the revert check, TW12)

| # | Mutation | Test that must fail |
| --- | --- | --- |
| M1 | `Explain.lines` (or the new H filter): print a line also for a run of H alone | SolverifaceTest R-AL11 rows "a fail on H alone", "a hang on H alone"; `probe/dm1-domain` run 2 |
| M2 | Revert B11 (no line for a run of one compiler that is not H) | SolverifaceTest R-AL11 upgrade row 3; `ur9-no-tuple-run` run 1 |
| M3 | Revert B12 (the kind of a fault from the row of H) | SolverifaceTest R-AL11 upgrade rows 4, 5; `ur9-no-tuple-run` run 2 |
| M4 | `var_of`: keep a candidate whose version does not parse | SolverifaceTest R-AL13 rows "does not parse" (3 rows) |
| M5 | `var_of`: the compiler slot in the order of D for both strategies | SolverifaceTest R-AL13 compiler rows 1, 2 |
| M6 | `asks_of`: give the probes of the tuple together with the missing headers | SolverifaceTest R-AL15 rows 1, 2 |
| M7 | `pf_incs`: check R-C3 with 2 or more platform slots | SolverifaceTest R-AL15 R-C3 row 2 |
| M8 | `OracleRequest.request_of`: drop `same_group` | SolverifaceTest R-AL14 row 5 |
| M9 | `SolverBase.norm`: keep a term that holds all values of its slot | SolverifaceTest R-AL16 leaves row, R-AL17 `Dep` row |
| M10 | Revert B8 (terms in the order of the search) | SolverifaceTest R-AL17 `step_moves` row 4 |
| M11 | `OracleCause.blame_text`: a fault gives `(no module is named)` | SolverifaceTest R-AL10 R-PH13 rows; `probe/un*` cases |
| M12 | The B8 fix also sorts the ids of a movable slot by the strategy (not by R-SP24 rule 2) | SolverifaceTest R-AL17 R-SP24 rows (Q-248-2) |

## Split

None. The code work is 3 small changes (B8, B11, B12), well under 400 lines (TW19). B8 is in `packages/resolve`; B11 and B12 are in `cli/lib`.

## Out of scope

R-AL1 to R-AL9 (tested). R-AL12 (slice 065; named again here). The `--json` form of `error.details` (R-J5, slice 036c). The text of a `Fail` with no probe cause (`the releases of ... do not fit together`).

## Disputes (from the code agent)

## Verify results
