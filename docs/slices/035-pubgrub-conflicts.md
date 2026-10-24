# 035 PubGrub conflicts

Phase: P1. Status: done

Slice 035 is the plan row 035 of `PLAN-P1.md`. It extends the solver step of slice 034 (`packages/resolve/Solver.roc`) with 4 things: conflict resolution of PubGrub (R-AL3), the incompatibilities that probe facts make (`not (h and roc in [a, b])`, R-EP7, R-AL5), the rules of `Need`, `Done` and `Fail` for real and inferred facts (R-EP8, R-EP9), and the explanation of a failure (Resolution 5 example, the type `Why`). No command calls the package yet (slice 036 does: the oracle loop, the flag `--no-probe`, exit 12, the output). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stub, the scripts and the logs are in `research/slice-035-revert/`.

## 1. Rules

| Id | What the slice does with it | Tested by |
| --- | --- | --- |
| R-EP7 (a fail run in D is an incompatibility `not (h and roc in [a, b])`) | `compat.checks` give maximal runs of adjacent releases of D with a fail that touches a used module. A real hang or crash is the interval of its compiler alone. The incompatibility is `{release, roc in interval}` | L0 `conflicts` 1, 4, 6. L1 |
| R-EP8 (probes only for the best tuple, a second pass when inferred facts blocked a better tuple) | `Allowed`: `Need` for A (best tuple with all facts) or for B (best tuple with real facts only) when A is blocked. `Fail` is made from real facts only | L0 `conflicts` 4, 6. L1 |
| R-EP9 (`--no-probe` or a spent budget: inferred facts decide, marked `inferred`) | `Off`: A only, no `Probe` ask, `Done` or `Fail` on inferred facts. The explanation names the inferred compilers of each interval | L0 `conflicts` 1, 4, 6. L1 |
| R-AL5 (a conflict becomes a learned incompatibility) | Conflict resolution gives learned incompatibilities, and probe facts give base incompatibilities in the same form | L0 `conflicts` 1, 2. L1 |
| R-AL3 (PubGrub: unit propagation, learning that does not repeat work) | The search of slice 034 ("learn the decisions, go back one") is replaced by conflict resolution (D5 of 034). A free slot is no part of a learned incompatibility | L0 `conflicts` 2, 3. L0 `solver` 1 to 5 (old rows, same values). L1 |
| R-UM1 (only used modules count) | A fail touches the app when it has no module (a hard fail, slice 030 Q4) or when one of its modules is in `compat.used` for that release. With no `Use` for the release no module is used | L0 `conflicts` 1, 4. L1 |
| R-VA6 (the best tuple by `priority` and `strategy`) | The compiler is a slot (D1), so it has the order of D (`Highest`: newest first). A slot before it keeps its best value | L0 `conflicts` 1, 2. L1 |
| R-DT2 (pure function) | The explanation is the same, also its steps, when the lists of the request are in another order | L0 `conflicts` 1 to 6 (each row also runs flipped). L1 |
| R-AL4, R-AL8 (named) | `Need` asks for the facts of the best tuple only, headers first (R-AL8), then probes (R-AL4), in the order of the slots | L0 `conflicts` 6. L1 |
| R-C1, R-C2, R-C3, R-C4, R-C6, R-C7, R-C9 (named) | The reasons `Dep`, `Pf` and `NoValue` of the explanation | L0 `conflicts` 5 |

`MISSING=1 scripts/rules.sh R-EP R-AL` after the slice: only R-EP2 and R-EP3 have no test (other slices). R-EP7, R-EP8, R-EP9 and R-AL5 are named.

## 2. Split of the slice

The private reference (`research/slice-035-revert/reference/packages/resolve/Solver.roc`) has 508 lines. Without comments and empty lines it has about 365 lines of code (the code of slice 034 has about 180, `Domain` 58). The code agent needs about 440 lines in all, a little over the 400 lines of TW19. The slice has 2 parts that can be split. The tests are written for both. The manager decided: no split (see Review).

| Part | Content | Tests |
| --- | --- | --- |
| 035a | Conflict resolution, and `Why` with the reasons `Given`, `Dep`, `Pf`, `NoValue` and `Derived` | `conflicts` 2, 3, 5. L1 with no compiler slot and no check |
| 035b | The compiler slot, probe facts, `Ask.Probe`, R-EP7, R-EP8, R-EP9 and the `Probe` reason | `conflicts` 1, 4, 6. The check part of L1 |

035b needs 035a (the explanation of a fail needs the resolution). The stub and the contract are one piece, so a split changes only who writes which function.

## 3. Public signatures (the code agent keeps them)

The new and changed items of `packages/resolve/Solver.roc` (the other signatures are as in slice 034, section 3). Time is in seconds. A version is `X.Y.Z`.

| Function or type | Signature |
| --- | --- |
| `Solver.Slot` | `{ name : Str, group : Str, kind : [Package, Platform, Compiler], candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]) }` (`Compiler` is new: the slot `roc`, D1) |
| `Solver.Check` | `{ id : Str, nightly : Str, outcome : [Pass, Fail, Hang, Crash], modules : List(Str), source : [Real, Inferred] }` |
| `Solver.Use` | `{ id : Str, modules : List(Str) }` |
| `Solver.Compat` | `{ domain : List(Str), checks : List(Solver.Check), used : List(Solver.Use), probes : [Allowed, Off] }`. `domain` is D, oldest first |
| `Solver.Request` | `{ slots, rules, facts, conflicts, compat : Solver.Compat }` (`compat` is new) |
| `Solver.Ask` | `[Header(Str), Probe({ id : Str, nightly : Str })]` (`Probe` is new) |
| `Solver.Cause` | `[Probe({ id : Str, kind : [Fail, Fault], from : Str, to : Str, modules : List(Str), inferred : List(Str) }), Dep({ id : Str, group : Str, version : Str }), Pf({ id : Str, pf : Str }), Given, NoValue(Str), Derived(U64, U64)]` |
| `Solver.Step` | `{ terms : List(Solver.Term), cause : Solver.Cause }` |
| `Solver.Why` | `{ steps : List(Solver.Step) }` (was `{ names }`) |
| `Solver.step` | `Solver.Request -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]` (unchanged) |

The docs of `packages/resolve/Solver.roc` have the contract as tables (the rules of the intervals, of A and B, and of the explanation). They are the text that the code agent follows. The stub (`research/slice-035-revert/stubs/Solver.roc`) is the code of slice 034 with the new types and docs. `step` keeps the old body, ignores `compat`, and returns `Fail({ steps: [] })`.

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `packages/resolve/Solver.roc` | 304 (was 55 + the code of 034) | Changed. The new types and docs. The stub (old body, `Fail({ steps: [] })`) |
| `packages/resolve/tests/conflicts.roc` | 406 | New. 6 `expect`s |
| `packages/resolve/tests/solver.roc` | 225 (was 224) | Changed, 3 mechanical edits (section 8) |
| `tests/fuzz/pubgrub.roc` | 820 (was about 411) | Rewritten. The model has the compiler slot, checks and the explanation |
| `tests/fuzz/pubgrub.roc` | +1 line | The line `# l1-runs: 8000` (the run count of this target in the fast set, section 16) |
| `scripts/test.sh` | | Changed (section 16): the L1 builds start at the start, `l1` is the last default step, a run count for each target (`# l1-runs: <n>`), `L1_DIR` |
| `tests/selftest.sh` | | Changed (section 16): 4 l1 rows edited (steps, pass, L1_RUNS, fail), 1 row added (the count of a target) |
| `research/slice-035-revert/` | | `before/` (also the old `scripts/test.sh` and `tests/selftest.sh`) (old files, `NEW.txt`), `stubs/`, `reference/` (private), `mutate.py`, logs |

No design file, no `TESTING.md`, no `cloudflare-workers/` file changed. `scripts/test.sh` needed no change.

## 5. Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `packages/resolve/tests/conflicts.roc` 1 (24 rows): the pairs that checks exclude with `Off`. A real fail, an inferred fail, a fail with no module, a fail that touches no used module, a hang, a crash, a pass, a check of a compiler that is not in D, of a release that is no value, `Highest` and `Lowest` | R-EP7 R-AL5 R-UM1 R-VA6 R-EP9 |
| L0 | `conflicts` 2 (6 rows): conflict resolution. 3 slots that all differ (no tuple), a ring of 4, a chain solved by propagation alone, free slots before the conflict | R-AL3 R-AL5 |
| L0 | `conflicts` 3 (1 row): 9 free slots with 2 values each, then x and y with no pair. The step of slice 034 needs about 32 s (K=9: 6.7 s for K=8, 127 s for K=10), this step a few ms | R-AL3 |
| L0 | `conflicts` 4 (4 rows): the leaves of the explanation of the Resolution 5 example (the app needs `parser` and `pf`, no compiler of D checks both). The reasons that every explanation has (`must`) and that it may have (`may`). The variant with inferred marks (`Off`), a fault and an inferred run, a run that is cut by a pass. Each row is checked as a proof (`sound`, brute force) and flipped (R-DT2) | R-EP7 R-EP8 R-EP9 R-DT2 |
| L0 | `conflicts` 5 (8 rows): the other reasons. `Given` (4 rows), a term with all values of its slot is left out, `Dep`, `Pf`, `NoValue` | R-C1 R-C2 R-C3 R-C4 R-DT2 |
| L0 | `conflicts` 6 (19 rows): `Need`, `Done` and `Fail` with real and inferred facts. `Allowed`: no B (`Fail`, real facts only), a header fact missing (`Need` for headers only), a pair with no real fact (`Need` with `Probe`, each pair once), A with all facts and B is A (`Done`), B better than A (`Need` for B), A does not exist (`Need` for B). `Off`: `Done`, `Fail` and never a `Probe`, a pair with no fact is fit | R-EP8 R-EP9 R-AL4 R-AL8 |
| L1 | `tests/fuzz/pubgrub.roc`: 2 numbers of 64 bits make a random world (1 to 3 package slots, a compiler slot with up to 5 compilers, up to 4 versions each, ranges, a header value, yanked and young releases, a snapshot, facts, 3 conflicts, 60 check cells, used modules, `Allowed` or `Off`). Properties: the step equals an oracle (brute force over all tuples, with the A and B rules); the loop of a command (step, the asks, step) ends with the oracle; each `Fail` explanation is a proof (soundness over all tuples, real leaves checked for each cause); the flipped request gives the same text (R-DT2). Costly checks run on a part of the inputs (gating bits) | R-EP7 R-EP8 R-EP9 R-AL3 R-AL5 R-VA6 R-DT2 |

L0 count: 6 `expect`s in the new file (the budget is 5 to 20) and 7 in the 2 old files (their rows pass with the stub and with the reference). Deep cases: 1 L1 target (the budget is 2 to 6; one target with 4 properties). No L2 or L3 case: no command calls the package before slice 036.

## 6. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `roc` is a slot of the kind `Compiler`. Its values are the candidates whose id is in `compat.domain`, in the order of D (`Highest`: newest first, `Lowest`: oldest first). Only `id` and `version` are read, `Chosen.version` is the `version` text. The solver never asks for a header fact of it | A special variable outside the slots. The oldest first for both strategies |
| D2 | One record `compat` in the request: D, the checks, the used modules, the mode. The solver derives the intervals from the raw checks (the caller needs no run code, and the L1 oracle checks the runs) | The caller passes the intervals |
| D3 | A run is a maximal run of adjacent releases of D, each with a fail that touches. A pass, a fail that touches no used module, a hang, a crash and a release with no check end it. A real hang or crash is the interval `[r, r]` | The run goes over a release with no check (the unknown) |
| D4 | A run of inferred fails with no real fail also gives an incompatibility (R-EP7 is silent, R-EP9 needs it for `Off`). A fault is real only: an inferred hang or crash is not read. With `RealOnly` semantics (the B search) the inferred checks are not read | An inferred fail only extends a real run |
| D5 | A fail with no module is a hard fail: it touches (slice 030 Q4). A fail with modules touches when one is in `used` for that release. The `modules` of a `Probe` reason are the failing modules that the app uses, not all | The module list of the check as is |
| D6 | The headers come before the probes. A probe needs the release, and a release with no header fact may be a wrong kind (R-AL8) | Both in one `Need` |
| D7 | A and B (section 1, R-EP8). `Allowed`: no B gives `Fail`. A with missing facts gives `Need` for A. A fully known and B equal to A gives `Done`. Otherwise (no A, or B better than A) `Need` for B, as for A | A inferred fail only orders the probes (Q3) |
| D8 | A spent budget and `--no-probe` are the same input (`Off`): A only, `Fail` and `Done` on inferred facts, never a `Probe`, a pair with no fact is fit, `Header` asks are still allowed (Q2, Q4) | Two inputs |
| D9 | `Why` is a DAG of steps. A leaf has a cause with a reason, `Derived(a, b)` names 2 earlier steps. `Given` has no index (R-DT2: the order of `conflicts` does not show). The explanation is the cone of the last step, in the order of the steps of the search, with `Derived` mapped to places in `Why.steps` | One text. A tree |
| D10 | A term of a step is `In`, in the order of the slots, the ids best first (the order of the values). A term with all values of its slot is left out. A `NoValue` step has no term. The last step has no term | `NotIn` terms. All terms kept |
| D11 | Canonical order of the base incompatibilities (R-DT2): the conflicts of the caller are normalized and sorted by their terms, facts follow the order of the slots and values, probes follow the order of slot, value and seed. So the steps of `Why` do not depend on the order of the lists | The order of the input |
| D12 | A check of a release that is not a value, of a compiler that is not in D, is not read. A pair has one check: the caller sends no second one, so no test has it | An error |
| D13 | No text of the explanation here. `Why` is data. The words, the `fix:` lines and `--json` are slice 036 | The text in the package |
| D14 | The types changed, so 3 mechanical edits of `solver.roc` are needed (section 8). No expected value changed | A second request type |
| D15 | The perf row has K=9 free slots (a few ms with the reference, about 32 s with the old search: it is a red row that is slow). L1 has gating bits (the costly checks run on a part of the inputs) because the step under coverage costs 0.35 ms for each step | K=60 (the old search does not end) |

## 7. Questions (TW17)

| # | Question | Options | Proposal | Effect |
| --- | --- | --- | --- | --- |
| Q1 | The Resolution 5 example has `fix:` lines. No rule gives their content | (a) in slice 036 with the text. (b) the package gives them | (a) | Not tested here. `Why` has the leaves that a text needs |
| Q2 | Is a spent probe budget (R-EP9) the same input as `--no-probe`? | (a) the same (`Off`). (b) another mode | (a): R-EP9 says "when the budget is spent or `--no-probe`" in one sentence | `conflicts` 6 `Off` rows |
| Q3 | R-EP8 "a second pass when inferred facts blocked a better tuple". The test reads it as: A (all facts) and B (real facts only). When A is blocked by inferred facts, the step asks for B | (a) A and B (D7). (b) inferred facts only order the probes | (a): with (b) an inferred fail never excludes a pair, so `Done` could name a pair that an inferred fail excludes | `conflicts` 6, L1 oracle |
| Q4 | `Off`: a pair with no fact at all (no real or inferred check) | (a) fit. (b) the step asks for it (a probe) | (a): `Off` never probes | `conflicts` 1 and 6 rows, L1 |

## 8. Changes to old tests (TW21)

| File | Change | Reason |
| --- | --- | --- |
| `packages/resolve/tests/solver.roc` | The `slot` helper annotation has `[Package, Platform, Compiler]`. The `req` helper adds `compat: { domain: [], checks: [], used: [], probes: Allowed }`. The helper `ask_id` has the arm `Probe(p) => "${p.id}@${p.nightly}"` | Type changes only: the new record field, the new tag and the new ask. No expected value changed. All old rows pass with the stub and with the reference |
| `scripts/test.sh`, `tests/selftest.sh` | The test setup for the l1 time: section 16. The old files are in `before/scripts/` and `before/tests/` | Review G7: the budget stays, the setup changes |
| `tests/fuzz/pubgrub.roc` | Rewritten with the compiler slot, the checks, the explanation properties. The old properties (step equals oracle, loop, order of lists) stay | The slice extends the model. `before/tests/fuzz/pubgrub.roc` has the old file |

## 9. Output (TW24, proposal for the review)

The package prints nothing. The proposal is the shape of `Why` (section 3, D9, D10): the code of slice 036 builds the text of Resolution 5 from the leaves. The words of the text, the `fix:` lines (Q1) and the `--json` `data` fields are slice 036 (R-OUT1 to R-OUT5).

## 10. Out of scope

| Id | Reason |
| --- | --- |
| R-AL6, R-AL7 (budget loop, held-move search) | Slice 036 |
| R-AL9 (the closure walk, the transitive pairs) | The caller walks the tuple and gives a failure back as a conflict (slice 034 Q3, slice 036) |
| R-UP7 (exit 12), the flag `--no-probe`, the budget count | Slice 036 (command wiring). The package has the input `probes : [Allowed, Off]` |
| R-EP12 rank 2 (the other target of a fact) | The caller maps facts to `checks` |
| The text of the explanation, the `fix:` lines | Slice 036 (D13, Q1) |
| L2 and L3 cases | No command calls the package |

## 11. Design gaps found

| # | Gap | Where | Proposal |
| --- | --- | --- | --- |
| G1 | The explanation has no data model: what a reason, a step and a cone are | Resolution 5 | Add the types of section 3 and D9, D10 to Resolution 5 |
| G2 | `TESTING.md` 2.2 writes `Need(List(Probe))`. The ask has headers and probes (`Need(List(Ask))`) | `TESTING.md` 2.2 | Change the signature text |
| G3 | R-EP7 is silent about a run of inferred fails with no real fail | R-EP7, R-EP9 | D4: it gives an incompatibility. Say so in R-EP7 |
| G4 | R-EP8 "a second pass" has no precise rule for B better than A | R-EP8 | D7, Q3 |
| G5 | R-EP9 says "when the budget is spent" and "`--no-probe`" with no word for the pair with no fact | R-EP9 | D8, Q2, Q4 |
| G6 | The example shows the ranges of "checks on" as the complement of the fail runs. R-EP7 gives the fail runs. `fix:` has no rule | Resolution 5 example | Q1 |
| G7 | The `l1` step took 61 s against the 60 s budget: the LLVM build of the solver (22 to 36 s) and the 20000 runs (24 s) were in the step, one after the other | `TESTING.md` 4 | Done in the test setup, with no change of the budget (section 16): l1 is 30.8 s |

## 12. Compiler and tool limits met

| # | Limit |
| --- | --- |
| 1 | `has` is a reserved word (also as a function name): the fuzz target uses `is_fact` |
| 2 | `==` and `!=` on a `Try` do not compile: use `match` or `?? default` |
| 3 | `roc test` crashes (segfault) on an `Err` record with a `Bool` field. The tests use a tag or a `Str` |
| 4 | A mutation that leaves a variable unused does not compile (`roc build` exits 2 on a warning). The mutations read the variable |
| 5 | libFuzzer inputs that are small are zero padded. The gating bits come from the mixed words, not from the raw inputs |
| 6 | A local variable with the name of a method of its type module is a duplicate definition |

## 13. Red output

| Run | Result |
| --- | --- |
| `scripts/test.sh` with the stub (`research/slice-035-revert/red-run.log`) | `check` pass, `fmt` pass, `l0` FAIL (only `packages/resolve/tests/conflicts.roc`: 2 passed, 4 failed), `l1` FAIL (only `tests/fuzz/pubgrub.roc`), `l2` pass, `l3` pass, `selftest` pass |
| `l0` | `conflicts` 2 (R-AL3 results) and 3 (perf row) pass with the old search: its results are right. The perf row takes about 32 s with the old search, so `l0` is 37 s and prints `WARN` (red state only). `conflicts` 1, 4, 5, 6 fail with wrong values. The 7 old `expect`s of `solver.roc` and `domain.roc` pass |
| `l1` | `tests/fuzz/pubgrub.roc: FAILED (exit 77, seed 1)`: `the step differs from the oracle for the same facts. Got fail. Want need s0-1.9.0` |

With the private reference in place (`research/slice-035-revert/green-run.log`): `scripts/test.sh` exits 0. check 1.0 s, fmt 0.1 s, l0 6.2 s (budget 10), l1 61.0 s (budget 60: `WARN l1`) with the first test setup. With the new test setup (section 16): l1 30.8 s, l2 1.1 s, l3 9.9 s, selftest 8.6 s. The L1 time is the LLVM build of the reference solver (22 to 36 s) and 20000 runs (24 s). The L1 target passes 20000 runs for seed 1, and about 40000 other seeds in the checks of the reference.

## 14. Revert check (TW12)

`research/slice-035-revert/mutate.py` puts 50 small changes of the private reference in `packages/resolve/Solver.roc` (a copy over the file), each compiled with `roc check`, then the 2 L0 files (timeout 25 s each), then (only when L0 passes) the `l1` step. At the end the stub is copied back (`cmp` equal). Final log: `mutate.log` (`mutate-first.log` is the first run: it did not catch w03, n03 and p09, and 8 changes did not compile because of unused variables; the rows `term_text` sign, the module row of `runs` and the L1 code 15 were added after it).

| Group | Changes | L0 | L1 |
| --- | --- | --- | --- |
| Conflict resolution (the decision takes the last place or the last variable, the cause part lost in a resolution (c03, c09), the backjump level is the lowest, a true term kept, 2 terms of one variable joined by union, a conflict ignored by propagation, a learn at the latest level with no resolution, the trail keeps all levels, the learned incompatibility not kept) | c01 to c11 | caught. c03, c08, c10, c11 by a run that does not end (25 s timeout), c04 by `solver.roc` timeout | not needed |
| Explanation (the final step only, `Derived` names step 0 twice, `NotIn` terms, the reverse order, the first incompatibility as final, the given conflicts not sorted or sorted before they are normalized, a dep or a platform cause with a wrong release or URL, a slot with no value names no slot) | w01 to w10 | caught | not needed |
| Probe intervals (a fail with no module is not hard, each fail touches, inferred fails count in `RealOnly`, a fault is no interval, the run starts early, ends late, does not stop at a pass or is the seed alone, modules not cut to the used ones, inferred compilers not named, a fault names modules, `from` and `to` swapped, no used modules, the probe facts of a platform slot not read) | p01 to p14 | caught | not needed |
| The compiler slot (the order follows the wrong strategy, a candidate not in D is a value, a header fact asked for a compiler) | r01 to r03 | caught | not needed |
| `Need`, `Done`, `Fail` (`Done` with B not read, no A gives `Fail`, `Fail` with the inferred search in `Allowed`, probes before headers, an inferred check is a real fact, a probe asked twice, `Off` asks probes, `Off` fails on real facts only, the second pass asks for A, the probe names the first compiler, an unknown pair is not fit in `Off`) | n01 to n12 | caught, except n03 | n03 caught |

Result: 50 changes, 49 caught by L0 and 1 (n03, `Allowed`: the `Fail` has the explanation of the search with inferred facts) caught by L1 only (`R-EP8: with probes allowed, a reason names an inferred fact`, 40 s). No L0 row can be built for n03 with the available pairs. 0 changes are missed. 5 changes are caught by a run that does not end (c03, c04, c08, c10, c11): a non-ending test is a failed test.

## 15. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `packages/resolve/Solver.roc` have the contract. The signatures stay (section 3) |
| N2 | The search of the reference: per variable a list of the possible places. A trail of entries `{ v, left, cause (Decision or From(inc)), level }`. Unit propagation puts entries on the trail. A clash is an incompatibility with all terms true. Resolution: the satisfier of a term is the first state of the trail where the term is true. It stops (and learns) when the latest satisfier is a decision, or when the next level is below the level of the entry. It goes back to the highest level of the other satisfiers. Else it resolves with the cause of the satisfier: new terms are (the clash without that term) plus (the cause without its term on the variable) plus the union on that variable. 2 terms of one variable are joined. An empty result is `Fail` |
| N3 | Each resolvent goes in the list of incompatibilities. The explanation is the cone from the empty incompatibility: the steps in the order of the list, `Derived(a, b)` mapped to places in the cone |
| N4 | The roc slot has the candidates whose id is in D, in the order of D. A check is read for a pair only when the release is a value and the compiler is in D |
| N5 | The base incompatibilities have a canonical order (D11): conflicts of the caller normalized then sorted, facts in the order of slot and value, probes in the order of slot, value and seed. It is what makes `Why` equal under reversed lists |
| N6 | A search with learning but no unit propagation does not end. A search with no resolution (learn the decisions) is correct but exponential: the perf row of `conflicts` 3 (K=9: 32 s) |
| N7 | Do not edit a test (TW18). A question goes to the manager |
| N8 | `cli/` does not import `resolve` in this slice |
| N9 | `l1` is 30.8 s in the new test setup (section 16). The cost is the LLVM build of `Solver.roc` (about 30 s, in the background from the start of the run) and 8000 runs (16 s). A shorter code makes both smaller |

## 16. Test setup change for the l1 time (manager review, G7)

The budget stays 60 s. The test setup changed (TW21, `before/scripts/test.sh` and `before/tests/selftest.sh` are the old files). Measured with the private reference, on a warm cache, full `scripts/test.sh` (`research/slice-035-revert/green-run2.log`).

| Change | Where | Effect |
| --- | --- | --- |
| The `roc build --fuzz` of each target starts with the other builds (`plan_builds`, a build named `l1-<target>`), in the background, after `check`. They are parallel by the `jobs_for` rule (the same pool as `l2`, `tln`, `fxprobe`, `flowprobe`) | `scripts/test.sh` `l1_build`, `build_one`, `plan_builds` | The build (about 30 s) runs while `l0`, `l2`, `l3` and `selftest` run |
| `l1` is the last default step (`check fmt l0 l2 l3 selftest l1`). `step_l1` only waits for the build of each target (if it is not ready) and runs it | `scripts/test.sh` `STEPS`, `l1_run` | The step time is the run of the targets. A selftest row reads the order |
| A run count for each target: `L1_RUNS` if set (all targets, for the nightly run), else the line `# l1-runs: <n>` of the target file, else 20000. `tests/fuzz/pubgrub.roc` has 8000 | `scripts/test.sh` `l1_runs_of` | `pubgrub` runs 16 s (was 24 s for 20000 runs). `epochs` stays at 20000 (1 s) |
| `L1_DIR` (default `tests/fuzz`) | `scripts/test.sh` | A selftest row can use fake targets |

| Step | Before (first setup) | After |
| --- | --- | --- |
| l1 | 61.0 s | 30.8 s (the target is 45 s) |
| l0 | 6.2 s | 7.1 s (6 builds run at the same time: 2 more than before) |
| check, fmt, l2, l3, selftest | 1.0, 0.1, 1.1, 9.9, 8.6 s | 1.0, 0.2, 1.3, 9.9, 8.4 s |
| whole run | 88 s | 59 s |

The red state has the same result (`red-run2.log`): `l0` FAIL (only `conflicts.roc`, 38.2 s with the old search, red only), `l1` FAIL (only `pubgrub`: exit 77, 8000 runs), the other steps pass.

Selftest (`tests/selftest.sh`, section `l1`): the row of the default steps reads the new order. The rows "pass", "L1_RUNS" and "fail" accept a count that differs for each target (`--runs=[0-9]+`, "all targets run 7", "seed 1, <count> runs"). The new row `l1-cnt` uses 2 fake targets in `L1_DIR`: `# l1-runs: 123` gives `--runs=123`, no such line (or the text not at the start of a line) gives 20000, `L1_RUNS=9` gives 9 for both. Revert check: with `l1_runs_of` that ignores the line, the row fails. With `L1_RUNS` ignored, the row `l1-cnt` and the row "L1_RUNS=7" fail.

Mutations at 8000 runs (`mutate-l1.log`, `L1_ALL=1` runs L1 also when L0 catches the change): n03 (L1 only), p09, w03, c06, p03, p12, p13, n05, n08 are caught by L1. n12 is not caught by L1 (also not with 20000 runs, `mutate-l1-n12.log`): it changes the result only when a world has no check at all, which the L1 world rarely makes. L0 catches n12 (`conflicts` 1 and 6). So n03 is still caught with the shorter run.

## 17. Next step

The code agent. The review is below. Slice 036 wires `resolve` into the commands (the oracle loop, `--no-probe`, exit 12, the text of the explanation).

## Review (manager, 2026-10-23)

Accepted, no split (the code is about 440 lines, close to TW19, and a split would only reorder the tests). Answers:

| # | Answer | Effect |
| --- | --- | --- |
| Q1 | The `fix:` lines, the text of the explanation and `--json` are slice 036 | Not tested here |
| Q2 | Accepted: a spent budget and `--no-probe` are one input (`Off`) to the step. Slice 036 maps both to it and keeps exit 12 for a spent budget | `conflicts` 6 `Off` rows |
| Q3 | Accepted: the A and B reading of the R-EP8 second pass | `conflicts` 6, L1 oracle |
| Q4 | Accepted: in `Off`, a pair with no fact is fit (as 034 D6) | `conflicts` 1, 6 |
| D1 to D15 | Accepted. G3 (a run of inferred fails with no real fail gives an incompatibility): accepted, because that incompatibility is inferred, so by R-EP8 it never decides alone and gives a `Probe`. One L0 row shows that: the rows `pr(n5)` with `fi(n6)` and `two` of `conflicts` 6 (a comment above the `expect` names them; `Off`: done on n5, fail. `Allowed`: a need for n6, and for n2). No row was added: they were there | `conflicts` 6 |
| G1, G2, G4, G5, G6 | Recorded by the manager in `PLAN-P1.md` 5b. `TESTING.md` and the design files are not edited | |
| G7 | Do not raise the budget: fix it in the test setup (builds in parallel, a run count for each target, a selftest row). Done: section 16, l1 30.8 s | |
| Red `l0` 37 s | Accepted (red state only). The green time is 7.1 s (under 10 s) | |

Done after the review: section 16 (the test setup), the comment of G3, the status `code`, the private reference deleted (`mutate.py` stays as the record: it needs the reference, so it cannot run again). Red state confirmed again (`red-run2.log`).

## Code result (code agent)

`scripts/test.sh` exits 0: check 1.0 s, fmt 0.2 s, l0 7.5 s (budget 10), l2 1.2 s, l3 9.8 s, selftest 8.5 s, l1 43.2 s (budget 60). `OPT=speed scripts/test.sh` exits 0 too (l0 8.4 s, l1 16.5 s, l2 99 s: over budget for the known reason). No test, fixture, `scripts/test.sh` or `tests/` file changed (no dispute rows).

| File | Lines | State |
| --- | --- | --- |
| `packages/resolve/Search.roc` | 170 | New. The PubGrub core on integers: trail, unit propagation, decisions, conflict resolution. It knows no release, fact or probe |
| `packages/resolve/Solver.roc` | 440 (docs and types as in the stub) | The body of `step`: the rows (no value, facts, probe intervals, conflicts), the A and B searches, the asks, the `Why` cone |
| `packages/resolve/main.roc` | 11 | Lists `Search` |
| `packages/resolve/Domain.roc` | 90 | Not changed |

| # | Decision that the slice does not fix | Rejected |
| --- | --- | --- |
| C1 | A new module `Search` (generic core). `Solver` makes the rows and gives each base row a `Cause` by its place in the table. `Search.Row.from` is `Base` or `Derived(a, b)` | One module (about 610 lines) |
| C2 | The table order is: no-value rows, fact rows (slot, value), probe rows (slot, value, interval by D), conflicts of the caller (normalized, sorted by terms). Every resolvent is appended to the table, so the cone is complete | Resolvents that are not kept |
| C3 | Resolution follows N2, with one more rule: the previous satisfier counts the earlier state of the variable of the term itself (`Search.prior_level`). Removing it only lowers the back-jump level (see m04: no output changes) | Other satisfiers only |
| C4 | `Allowed` skips the A search when no check is inferred (A is B then) | Always two searches |
| C5 | `Allowed` with a B that needs no ask and is not A cannot happen (an inferred fail blocked it, so its pair has no real fact). The code gives `Done(B)` there, not a crash | A `crash` |
| C6 | A value of the compiler slot has no parsed version (`Val.ver` is a `Try`); a dep never limits a compiler | A dummy version |

No question (TW17). No new compiler limit.

## Verify results (revert check, TW12, reduced by the user to the tricky behaviors: 11 changes)

Script `research/slice-035-revert/agent-mutate.py`, logs `agent-run.log` (first run) and `agent-run2.log` (4 changes redone: a constant `if` does not compile, so they use a condition that the compiler cannot fold). Order: `roc check`, the 2 L0 files with a timeout of 25 s, and L1 (8000 runs) only when L0 passes. Final code in `research/slice-035-revert/code-final/`, `code-final.sha256`: `sha256sum -c` is OK after the last mutation.

| Id | Change | Result |
| --- | --- | --- |
| m01 | Resolution: the back-jump goes to the level of the satisfier, not below | Closed by the gap test (section "Gap tests"): the new row of `conflicts` 2 does not end under m01 (timeout 25 s). Before: L0 pass, caught by L1 only (a run that does not end, 200 s) |
| m02 | Resolution: it learns the conflict row and never resolves | L0 `conflicts` and `solver`: no end (timeout). Caught |
| m03 | Resolution: the union term of a resolvent uses `and` | L0 no end (timeout). Caught |
| m04 | Resolution: the previous satisfier of the term itself is not read | Not caught (L0 and L1 pass) |
| m05 | Unit propagation: a false lit does not stop a row | L0 no end (timeout). Caught |
| m06 | R-EP8: B better than A gives `Done` with B | L0 `conflicts` 6 "R-EP8 second pass". Caught |
| m07 | R-EP8: the B search and the `Fail` read inferred checks | L0 `conflicts` 6 (also "R-EP8: no tuple ..."). Caught |
| m08 | R-EP9: `Off` reads real checks only | L0 `conflicts` 1 and 6. Caught |
| m09 | R-EP9: `Off` asks for probes | L0 `conflicts` 1 and 6. Caught |
| m10 | `Why`: `Derived` names the first step twice | L0 `conflicts` 4 (proof check). Caught |
| m11 | R-EP7: a pass does not end a run | L0 `conflicts` 1 "a pass between 2 fails stays a value". Caught |

Caught 10 of 11. m02, m05, m09 and m10 first did not compile (a constant `if`, an unused variable), and were redone.

Not caught: m04 is an equivalent change for the output. A lower back-jump level is still sound (the learned row is a row that holds, and after the jump it is a unit row), so the result and the proof stay right; only the learning is weaker. No test gap. m01 has no L0 row: only L1 sees it (a non-ending search). A deeper L0 row (a conflict that needs a back-jump over 2 levels) would catch it in L0: a test gap that the manager may want to close (the code agent does not edit tests, TW18).

## Gap tests

| Id | Gap | Row | Check |
| --- | --- | --- | --- |
| m01 | The back-jump goes to the level of the satisfier, not below it. No L0 row reached the branch (the row learned after a resolution whose latest satisfier is a derived value, alone at its level) | `packages/resolve/tests/conflicts.roc` `expect` 2 (R-AL3), the first row: `a b c d u x y`, 2 values each, 4 conflicts. After `a=2 b=2 c=2 d=2` (levels 1 to 4): `d=2 a=2` gives `u=1`, `u=1` gives `x=1` and `y=1`, and the conflict `x=1 y=1 a=2` has 3 lits at level 4. The resolution ends at `a=2 u=1` (the derived `u` is alone at level 4, its other lit is at level 1): the solver learns it and goes back over levels 2 and 3 to level 1. Result `done a=2 b=2 c=2 d=1 u=2 x=2 y=2` | One hand change (m01 only, no sweep): with `back: e.level` the learned row is still a conflict at that level, so the search does not end. `roc test conflicts.roc` runs until the timeout (25 s in this check, no output). With the final code it takes 0.4 s. `scripts/test.sh` has no timeout of its own for `l0`: a hang there is the catch, and the person sees it as a step that does not end (the budget `WARN` comes only at the end). The code is restored by `cp` from `code-final/`: `sha256sum -c code-final.sha256` OK, `scripts/test.sh` exit 0 (`gap-run.log`: l0 7.6 s, l1 42.4 s) |

m04 is an equivalent change (no gap test), as written in "Verify results". No other file changed: the test file `conflicts.roc` (1 row added to `expect` 2, 7 rows now) and this file.

## Close (manager, 2026-10-23)

Code decisions C1 to C6 are accepted. The code agent ran 11 targeted mutations (the user rule of 2026-10-23: only the tricky behaviors): 10 caught, m04 equivalent. The gap row of `conflicts` 2 catches m01 (the search does not end under it). `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 7.6 s, l1 42.4 s). Status: done.
