# 033 Epochs

Phase: P1. Status: done

Slice 033 is the plan row 033 of `PLAN-P1.md`: `epochs : List(Release), Facts -> { epochs, inferred }` (Resolution 4, R-EP10 to R-EP14), a pure function, and the `l1` step of `scripts/test.sh` (the first roc-fuzz target, `TESTING.md` 4). No command calls the function yet (slice 036). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stub, the private reference and the scripts are in `research/slice-033-revert/` (`before/NEW.txt` lists the new files).

## 1. Rules

| Id | What the slice does with it | Tested by |
| --- | --- | --- |
| R-EP1 (code result is `pass` or `fail`, a fault is not one, adjacent releases) | `Epochs.infer`: a fault is skipped when the nearest result is searched | L0 `epochs` 2, 3. L1 `epochs` |
| R-EP4 (an epoch is a maximal flat interval. With no matrix, each release is an epoch of its own) | `Epochs.partition`. A release that no interval holds is an epoch of its own (section 6, D5) | L0 `epochs` 1, 3, 4. L1 `epochs` |
| R-EP5 (a fault is never part of a boundary, never ends an epoch, never gives an inferred fact) | The partition does not read facts. A fault is no source and its pair gets no inferred fact | L0 `epochs` 1, 2, 3. L1 `epochs` (property: remove the faults) |
| R-EP6 (a) same epoch, (b) between, `pass` and `fail` together stay unknown, `fail` copies the modules | `Epochs.infer` | L0 `epochs` 2, 3, 4. L1 `epochs` (oracle) |
| R-EP10 (pure, same inputs give the same epochs) | `Epochs.epochs` | L0 `epochs` 4 (reversed and rotated facts). L1 `epochs` |
| R-EP11 (D is every release of the compiler list, in R-NS1 order, the switch and the range do not remove releases) | `Epochs.partition` and `infer` read `id` only. A release with no asset is in D. The order is the order of the caller | L0 `epochs` 1, 2 (releases with and with no asset) |
| R-EP12 (real facts only, ranks 1 and 2) | The input is `List(Db.Fact)`: rows, no hint. A row with a target other than `any` is not read (section 6, D4). Rank 2 and the precedence of R-EF3 are P2 | L0 `epochs` 2 (build rows) |
| R-EP13 (`epochs` is a partition of D into intervals of adjacent releases) | `Epochs.Interval` (ids) | L0 `epochs` 1, 4. L1 `epochs` |
| R-EP14 (an inferred fact is marked and names the real fact it comes from) | `Epochs.Inferred` with `from` | L0 `epochs` 2, 3, 4. L1 `epochs` |
| R-EP7, R-EP8, R-EP9 | Not in this slice. See section 8 | |

`MISSING=1 scripts/rules.sh R-EP` lists R-EP2, R-EP3, R-EP8 and R-EP9 after the slice. R-EP7 has 2 tests of slice 031. The first 4 are P2 or slice 035 (section 8).

## 2. Split of the slice

The row has 250 lines. The code (`cli/lib/Epochs.roc`) is about 120 lines (the private reference has 122), so there is no split. The L1 step and its self-test rows are about 125 lines of test tooling, written by the test agent (as the runner changes of earlier slices).

## 3. Public signatures (the code agent keeps them)

| Function or type | Signature |
| --- | --- |
| `Epochs.epochs` | `List(Nightlies.Release), List(Db.Fact) -> Epochs.Found` |
| `Epochs.partition` | `List(Nightlies.Release) -> List(Epochs.Interval)` |
| `Epochs.infer` | `{ domain : List(Nightlies.Release), epochs : List(Epochs.Interval), facts : List(Db.Fact) } -> List(Epochs.Inferred)` |
| `Epochs.Interval` | `{ from : Str, to : Str }` (ids, both in the epoch) |
| `Epochs.Inferred` | `{ hash : Str, nightly : Str, outcome : [Pass, Fail], modules : List(Str), from : List(Str) }` |
| `Epochs.Found` | `{ epochs : List(Epochs.Interval), inferred : List(Epochs.Inferred) }` |

The doc of `cli/lib/Epochs.roc` has the rules of the function as tables. It is the contract. The module is in the exposed list of `cli/lib/main.roc`.

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/Epochs.roc` | 53 | New. 3 stubs (`crash "todo"`, parameters `_x`) and the types. The doc has the contract |
| `cli/lib/main.roc` | +1 | `Epochs` in the exposed list |
| `tests/unit/epochs.roc` | 201 | New. 4 `expect`s |
| `tests/fuzz/epochs.roc` | 200 | New. The first roc-fuzz target (L1) |
| `scripts/test.sh` | +51 (227) | The step `l1`, `L1_RUNS`, `L1_SEED`, `L1_HOST`, `l1` in the default steps |
| `tests/selftest.sh` | +75 (592) | The fake roc makes a fake roc-fuzz target (`--fuzz`). 7 rows (`s_l1`) |
| `research/slice-033-revert/` | | `before/` (3 old files, `NEW.txt`), `stubs/`, `mutate.py`, `mutate-step.py`, `test.sh.final`, logs. The private reference and `swap.sh` are deleted |

No old expected file changed. No design file and no `cloudflare-workers/` file was changed.

## 5. Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `epochs` 1: `partition` and the `epochs` of `Epochs.epochs` (9 rows: empty D, one release, 6 releases with and with no asset, the order of the caller, no fact, all hashes agree on all releases, faults and different results, empty D with facts) | R-EP4 R-EP5 R-EP11 R-EP13 |
| L0 | `epochs` 2: case (b) through `Epochs.epochs` (23 rows: the sorted union of 2 sources with different modules (Q1), pass, fail with modules, fail with no module, pass then fail, fail then pass, no result before or after, 4 gaps, the nearest results, a hang and a crash between passes, a fault skipped in the search, faults only, build rows (no source, no real fact of a unit pair), a release that is not in D, 2 hashes with the input in another order) | R-EP1 R-EP4 R-EP5 R-EP6 R-EP12 R-EP14 |
| L0 | `epochs` 3: case (a) through `Epochs.infer` with epochs of more than one release (19 rows: the sorted union of 2 sources with different modules (Q1), pass, fail with modules, 2 sources, both cases with the same X (sources of both, in the order of D), a pass and a fail in the epoch, the ends of the epoch, a real fact for each pair, a fault in the epoch, faults only, no interval, an interval with ids that are not in D, 2 hashes, a build row) | R-EP5 R-EP6 R-EP14 R-EP4 |
| L0 | `epochs` 4: the whole function on a made-up sample of the Q11 shape (6 releases, 3 hashes, faults, a build row), the same output for the facts reversed and rotated, `epochs` is `partition` and `infer` | R-EP10 R-EP13 R-EP14 R-EP6 R-EP5 R-EP4 |
| L1 | `tests/fuzz/epochs.roc`: random domain (1 to 8 releases, some with an asset), random epochs (some releases held by no interval), random facts (24 cells: pass, fail with modules, hang, crash, build rows). 5 properties: the epochs are one interval for each release. The facts in another order give the same output. `epochs` is `partition` and `infer`. `infer` equals an oracle written from the rule text (index loops, no fold over facts) for the same pairs, outcomes, `from` and order. An inferred `fail` has the sorted union of the modules of its sources, a `pass` has none. Removing the faults changes no inferred fact except that the pairs with a fault become gaps | R-EP4 R-EP5 R-EP6 R-EP10 R-EP11 R-EP13 R-EP14 R-EP1 |
| Selftest | `s_l1` (7 rows): the calls and the report of the `l1` step (section 7) | TW6, TW26 |

L0 count: 4 `expect`s in 1 file (the budget is 5 to 20: each `expect` is a table of 6 to 23 rows, 57 rows in all). Deep cases: 1 L1 target. There is no L2 or L3 case: no command calls `Epochs` before slice 036, so no flow exists to test. The deep test of a pure function with many cases is the L1 property run. Slice 036 adds the L2 cases of the loop.

## 6. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `Release` is `Nightlies.Release` (only `id` is read), `Facts` is `List(Db.Fact)`. An interval is `{ from, to }` with ids (as `epochs` in R-AP17). | A list of ids as the domain (the design says `List(Release)`) |
| D2 | Three functions: `epochs` (the design signature), `partition` (R-EP4 with no matrix) and `infer` (R-EP6 for the epochs that it is given). Reason: with `partition` only, each epoch has one release, so case (a) of R-EP6 never runs in P1 and no test can reach it. The P2 matrix gives `infer` its intervals. | One function (case (a) untested until P2) |
| D3 | The domain is used in the order that the caller gives. The function does not sort. | A sort by `Nightlies.order` inside (R-EP11 says "in R-NS1 order" for the input) |
| D4 | Only rows with target `any` are facts. A build row is no source and has no inferred fact. Support: R-MX4 ("epochs use unit checks only"). | Build rows as sources |
| D5 | In `infer`, a release that no interval holds is an epoch of its own. An interval with ids that are not in D holds nothing. Support: the wording of R-AP17 `epochs` ("a compiler that no listed epoch holds is an epoch of its own"). | A crash, or one epoch of all the other releases |
| D6 | A pair gets no inferred fact when the cases give both `pass` and `fail`, also when both come from case (a) (a mixed epoch). Reading of "if one case gives `pass` and a case gives `fail`". | Case (a) first, then case (b) only when (a) gives nothing |
| D7 | `from` is the releases of the sources of the cases that gave the result (case (a): each release of the epoch with that result, case (b): the 2 nearest), in the order of D, no repeat. | Only the nearest source |
| D8 | `inferred` is sorted by hash (byte order, `Text.compare`), then by the place in D. A hash with no unit fact in D has no row. | The order of the input |
| D9 | A pair that has a real fault has a real fact, so it gets no inferred fact (R-EP5: "never gives an inferred fact"). | An inferred fact over a fault |
| D10 | Two rows for one key (hash, nightly, `any`) never come: the caller applies R-EF3 (rank 2 is P2, so P1 has one source). The result for such an input is not defined and not tested. | A rule in `Epochs` (it has no `source`) |
| D11 | The L1 build is `roc build --fuzz --opt=speed` for every `OPT` (roc: "`--fuzz` requires the LLVM backend"). The step is skipped with exit 0 on a system that has no roc-fuzz platform (Linux x86-64 and macOS Apple silicon have one; `TESTING.md` 4). | `--opt=dev` (refused by roc) |
| D12 | Each `l1` run uses a new dir `$WORK/l1/<name>/` (no old corpus: TW6) with a fixed count (`L1_RUNS`, 20000) and seed (`L1_SEED`, 1), and the targets run in parallel (at most `JOBS`). The build of a target is the step of the job of that target. | A corpus that stays between runs |

## 7. The `l1` step (TESTING.md 4, TW6, TW26)

| Item | Value |
| --- | --- |
| Targets | `tests/fuzz/*.roc`, one app on the platform `roc-fuzz` 0.4.3 (the URL is in the header of the file) |
| Build | `roc build --fuzz --opt=speed <file> --output=$WORK/l1/<name>/target` |
| Run | In `$WORK/l1/<name>/`: `./target run --runs=$L1_RUNS --seed=$L1_SEED --artifact-dir=$WORK/l1/<name>/art` |
| Failure | exit 1 for the step. The report has the line `<file>: FAILED (exit <n>, seed <s>, <r> runs)`, the lines of the log without the libFuzzer noise (`INFO`, `#`, the dictionary), and `replay: <target> replay <input file>` for each saved input. TW5: the minimized input becomes an `expect` of L0 before the fix. |
| Skip | `L1_HOST` (default `uname -s`-`uname -m`) not `Linux-x86_64` or `Darwin-arm64`: the line `l1: skipped, roc-fuzz has no platform for <host>`, exit 0. CI: Linux and macOS run it, the Windows job runs `check fmt l0` only. |
| Variables | `L1_RUNS` (20000), `L1_SEED` (1), `L1_HOST`. `BUDGET_L1` changes the budget |

Budget (the manager decides). `TESTING.md` 1 and TW26 give 60 s for `l1`, and the table of `scripts/test.sh` has it already, so the step keeps 60 s. `PLAN-P1.md` 3.4 gives 40 s for 4 targets at the end of P1, so about 10 s for one target, with its build. Measured here (2026-10-23, the private reference, dev run of `scripts/test.sh l1`):

| Part | Time |
| --- | --- |
| Build of `tests/fuzz/epochs.roc` (LLVM, with the `lib` package) | 4.5 s |
| 20000 inputs | 2 s |
| Step | 7.1 s (budget 60 s) |

Proposal: `L1_RUNS=20000` for all targets in the fast set. A target that needs more than about 10 s with its build gets a lower count in its own file, not a new variable. `nightly.yml` can set `L1_RUNS` high for the long runs (`TESTING.md` 1: "Long runs each night"). The slice does not change `nightly.yml`. Note: libFuzzer grows the input length slowly (the limit was 163 bytes after 20000 runs), so a property over long lists needs many runs, or `L0` rows for long inputs (mutation m23 of section 11).

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-EP2, R-EP3 (swept releases, covered transitions, boundaries) | They need the registry matrix (`sweeps` and `transitions`, P2). The design signature has no input for them (design gap G1). `infer` takes their result as intervals |
| R-EP7 (the learned incompatibility `not (h and roc in [a, b])`) | Plan row 035 names it (with R-EP8, R-EP9, R-AL5). It is the use of the facts by the solver, with the modules that the app uses (R-UM1). The design gives no function for it |
| R-EP8, R-EP9 (an inferred fact never decides, `--no-probe`) | Behavior of the solver step (slices 035 and 036) |
| R-EP12, rank 2 and the precedence of R-EF3 | P2 (no registry facts). The caller selects one row for each key (D10) |
| L2 and L3 cases | No command calls `Epochs` (section 5) |
| TESTING.md text | The human edits it (section 10, G2) |

## 9. Questions (TW17, stop until answered)

| # | Question | Options | Proposal | Effect |
| --- | --- | --- | --- | --- |
| Q1 (answered, see Review) | R-EP6: "An inferred `fail` copies the set of failing modules of its source." Case (b) has 2 sources and case (a) can have more. What is the set when the sources have different sets? | (a) the union. (b) the intersection. (c) the nearest source, the earlier one on a tie. (d) the earlier source in D. | (a): it keeps each module that a source blames, so the scan of R-UM1 and R-EP7 does not miss a used module. | `Epochs.infer` only. Answered by the manager: the union (see Review). L0 has 2 rows with different sets and L1 checks the union. |

## 10. Design gaps found

| # | Gap | Where | Proposal |
| --- | --- | --- | --- |
| G1 | The signature `epochs : List(Release), Facts -> ...` has no input for the registry matrix. R-EP2, R-EP3 and R-EP4 need the `sweeps` and `transitions` rows and the registry epochs (R-AP17 `epochs`). R-EP12 says that `Facts` are rank 1 and 2 facts only. | R-EP10, R-EP12, R-EP2 to R-EP4 | A P2 slice adds a function that gives the intervals from the matrix and the facts of case (b) of R-EP3, and `infer` takes them (D2). Change the signature text of R-EP10 then. |
| G2 | `TESTING.md` says L1 builds as the others (TW25: "test binaries with `--opt=dev`"), 4 and the target table have no `epochs` row, and the target text does not say that `--fuzz` needs LLVM. | `TESTING.md` 1, 4, TW25, TW26 | Add: l1 targets always build with `--opt=speed`. Add the `epochs` row to the table of 4. |
| G3 | R-EP6 does not say what an inferred `fail` copies when it has 2 sources (Q1). | R-EP6 | The answer to Q1 |
| G4 | R-EP6 case (a) says "h has a real code result X on a release in the epoch", with no rule for an epoch that has both `pass` and `fail` of one hash (a code island in an epoch). D6 reads it as "unknown". | R-EP6 | Confirm D6 in the text |

## 11. Compiler and tool limits met

| # | Limit |
| --- | --- |
| 1 | `roc build --fuzz --opt=dev` stops with "`--fuzz` requires the LLVM backend". The `l1` build is `--opt=speed` for every `OPT` (D11). |
| 2 | A tag union that the compiler infers from a `match` has no `map_ok`. Use `match` (or a `Try` annotation) before `map_ok`. |
| 3 | A list of tuples whose second parts have different types is a type error: the L0 rows of `epochs` 4 are `(Bool, label)`. |
| 4 | A mutation that leaves a variable unused or a condition constant does not compile (`roc build` exits 2 on a warning). The mutations are written to read the value (`take_first(0)`). |
| 5 | roc-fuzz writes its corpus to `.roc-fuzz/` in the working dir, so the step runs each target in `$WORK/l1/<name>/` (`.roc-fuzz` is in `.gitignore`). |

## 12. Red output

| Run | Result |
| --- | --- |
| `scripts/test.sh` with the stub (`research/slice-033-revert/red-run.log`) | `check` pass, `fmt` pass, `l0` FAIL (only `tests/unit/epochs.roc`, 68 other files pass), `l1` FAIL, `l2` pass, `l3` pass, `selftest` pass (with the 7 new rows) |
| `l0` | `Roc application crashed with this message: todo`, for `expect` 1 to 4 of `epochs.roc` |
| `l1` | `tests/fuzz/epochs.roc: FAILED (exit 77, seed 1, 20000 runs)`, `[roc crashed] todo`, and the replay line |

With the private reference in place (not kept in `cli/`): `roc test tests/unit/epochs.roc` gives "All (4) tests passed", and `scripts/test.sh l1` passes (7.1 s).

## 13. Revert check (TW12)

The private reference (122 lines) and `swap.sh` were deleted on the manager's order (Review). `mutate.py` needs the reference, so it cannot run again. `cli/lib/Epochs.roc` holds the stub (`cmp` with `stubs/Epochs.roc`: same).

Code: `mutate.py` put 25 small changes of the reference in `cli/lib/Epochs.roc`, one at a time, each compiled with `roc check cli/lib/main.roc` (0 errors and 0 warnings), then L0 and then the `l1` step. Logs: `mutate.log` (first run), `mutate2.log` (the rows that were changed after the first run).

| Group | Changes | L0 | L1 |
| --- | --- | --- | --- |
| `partition` (an empty `to`, reversed, releases with no asset left out) | m01 to m03 | caught | caught |
| What a fact is (a build row counted, a fault counted as a result, a fault pair counted as a gap, a crash dropped, only 8 facts read) | m04 to m06, m21, m22, m23 | caught | caught, except m23 |
| Case (b) (no result after counts, the farthest result, the nearest fact blocks) | m07, m08, m20 | caught | caught |
| The result (pass wins, fail wins, case (a) left out, case (b) left out, the first release of the epoch is no source) | m09 to m12, m19 | caught | caught |
| `from`, modules, order (repeats, no modules, unsorted modules, the hashes in input order, the releases in reverse) | m13 to m17 | caught | caught |
| A release that no interval holds belongs to all of D | m18 | caught | caught |

After the answer to Q1, m24 and m25 (the modules of the first or of the last source only) were added: both caught by L0 and L1 (`mutate3.log`). So 24 of 25 are caught by L1 and 25 of 25 by L0. Two gaps of the first run were closed in the tests (not in the code): m22 (a crash dropped inside `Epochs.epochs` only: no L0 row had a crash between 2 results, so the row "a crash has a real fact" was added to `epochs` 2) and m18 (the L1 epochs always covered D: a `2` in `cuts` now leaves a group out). m23 stays L0 only (the input length limit, section 7). Equivalent changes that were not made: "case (b) needs equal results" (the set logic gives the same), "sources of both outcomes in `from`" (a mixed result is unknown anyway), "the first source gives the modules" (Q1).

The l1 step: `mutate-step.py` changes `scripts/test.sh` in 16 ways, one at a time (the fuzz build follows `OPT`, no `--fuzz`, `--time` for `--runs`, no seed, the run in the repo dir, an old run dir stays, no skip, a failing run or build does not fail the step, no replay line, the noise stays, Darwin not supported, the skip fails, the budget 90, 5 default runs, no `l1` in the default steps). `scripts/test.sh selftest` failed for each of them (the rows `s_l1`; `mutate-step.log`). The file is restored from `test.sh.final` (`restored: True`).

## 14. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The doc of `cli/lib/Epochs.roc` has the contract. The signatures stay (section 3). |
| N2 | A local variable must not have the name of a function of its type module: `epochs` is a function of `Epochs`, so a local `epochs` is a duplicate definition. The fields `epochs` of a record are fine. |
| N3 | A tag union that `match` infers has no `map_ok`. Use `match` or a `Try` annotation. A closure that unpacks a tuple works (`|(f, i)| ...`). |
| N4 | Q1 is answered: the modules of an inferred `fail` are the sorted union (no repeat) of the modules of its sources. Provisional (U4 of `PLAN-P1.md`). |
| N5 | Do not edit a test (TW18). A question goes to the manager. |
| N6 | The code is about 120 lines. `Text.sorted_unique` and `Text.compare` exist. |

## 15. Next step

Review (the human): D1 to D12, the budget proposal (section 7), Q1, G1 to G4. Then the code agent. Slice 035 takes R-EP7 to R-EP9, slice 036 wires `Epochs` into the loop.

## Review (manager, 2026-10-23)

Accepted. Answers:

| # | Answer | Effect |
| --- | --- | --- |
| Q1, G3 | The union of the module sets of the sources, sorted. Provisional: it is U4 in `PLAN-P1.md` section 6 for the user | 2 L0 rows (`epochs` 2 and 3: sources with different sets) and the L1 property (the sorted union) fix it. Mutations m24 and m25 are caught |
| D1 to D5, D7 to D10, D12 | Accepted | |
| D6, G4 | Accepted: `pass` and `fail` of one hash in one epoch give unknown. It is a reading of R-EP6 "if one case gives pass and a case gives fail" | |
| D11 | Accepted. It matches `TESTING.md` section 1 ("A developer on another system skips L1") | |
| L1 budget | 60 s, `L1_RUNS=20000`. Do not change `nightly.yml` | |
| G1, G2 | Recorded by the manager in `PLAN-P1.md` 5b. `TESTING.md` and the design files are not edited | |
| 4 L0 `expect`s with 56 rows | Accepted | |

Done after the review: the 2 rows of Q1 (mutations m14, m15, m24 and m25 of section 13), the private reference and `swap.sh` deleted, red state confirmed again with `scripts/test.sh` (`research/slice-033-revert/red-run.log`): `check` pass, `fmt` pass, `l0` FAIL (only `tests/unit/epochs.roc`), `l1` FAIL (only `tests/fuzz/epochs.roc`), `l2`, `l3` and `selftest` pass.

## Code result

`cli/lib/Epochs.roc` is 143 lines (the stub had 53). The signatures and the doc are as in the stub. No test, fixture or script was changed.

| Function | Lines | What it does |
| --- | --- | --- |
| `Epochs.epochs` | 45 to 48 | `partition`, then `infer` with those intervals |
| `Epochs.partition` | 52 | One interval for each release, in the order of D |
| `Epochs.infer` | 56 to 61 | Keeps rows with target `any`. For each hash (`Text.sorted_unique`) it calls `infer_hash` |
| `groups_of`, `span_of`, `holds` | 68 to 84 | The epoch (a number) of each place in D. A place that no interval holds gets its own number (D5). An interval with an id that is not in D holds nothing |
| `cell_at`, `result_at`, `modules_at` | 86 to 107 | A release of one hash is `Gap`, `Done(Pass or Fail, modules)` or `Fault` (R-EP1, R-EP5) |
| `infer_hash`, `infer_at` | 109 to 143 | R-EP6 for each `Gap`. The sources are the code results in its epoch (case (a)) and the 2 nearest results when they agree (case (b)). One outcome in the sources gives a fact (D6). `from` is the sources in the order of D (D7). `modules` is the sorted union (Q1) |

Decisions that the slice does not fix: none. Reused: `Text.sorted_unique`. Roc limits met: `has` is a reserved word (a local `is_code` is used).

Results (2026-10-23):

| Run | Result |
| --- | --- |
| `roc check cli/lib/main.roc` | 0 errors, 0 warnings |
| `scripts/test.sh` | exit 0. check 0.9 s, fmt 0.1 s, l0 6.0 s (4 `expect`s of `epochs` pass), l1 4.7 s, l2 1.1 s, l3 9.8 s, selftest 8.2 s |
| `OPT=speed scripts/test.sh` | exit 0. l1 7.6 s. l2 83.9 s (the speed build of the L2 app, over the 30 s budget, not a result of this slice) |

## Disputes (from the code agent)

None. No test was changed.

## Verify results

Revert check (TW12): `research/slice-033-revert/agent-mutate.py`, 35 changes of `cli/lib/Epochs.roc`, one at a time. Each is compiled (0 errors, 0 warnings), then L0 (`tests/unit/epochs.roc`), then the `l1` step only when L0 passes. The file is restored from `code-final/` before and after each change. The table is `agent-results.md`, the log is `agent-mutate.log`. The first run had 3 changes that did not compile (a variable left unused: e17, e18, e19). They were rewritten to read the variable and run again.

| Group | Changes | Rule | Result |
| --- | --- | --- | --- |
| `partition` (empty `to`, reversed, no asset left out, domain reversed in `epochs`) | e1 to e4 | R-EP4, R-EP11, R-EP13 | caught by L0 |
| What a fact is (only 8 facts read, a build row read) | e5, e6 | R-EP10, R-EP12 | caught by L0 |
| Faults (hang or crash as a result, as a gap, a fault pair infers) | e7 to e11 | R-EP5 | caught by L0 |
| Modules of a fail copied (none) | e12 | R-EP6 | caught by L0 |
| Case (b) (the farthest result, `x != y`, no guard on `x == y`) | e13 to e16 | R-EP6 | e13, e14, e15 L0. e16 L1 only |
| Case (a) and (b) left out, case (a) reads the wrong epoch | e17 to e19 | R-EP6 | caught by L0 |
| The result (first outcome wins, pass wins) | e20, e21 | R-EP6 | caught by L0 |
| Modules (first source only, last source only, no sort, repeats) | e22 to e25 | R-EP6 (Q1) | caught by L0 |
| `from` (reversed, the first source only) | e26, e27 | R-EP14 | caught by L0 |
| Order (hashes reversed, places reversed) | e28, e29 | R-EP10 | caught by L0 |
| Epoch of a release that no interval holds, the span of an interval (`to` as `from`, `p < hi`, `lo < p`) | e30 to e33 | R-EP4 | caught by L0 |
| An interval with 1 id that is not in D | e34, e35 | R-EP4 | not caught at first, closed by gap rows (see below) |

Caught: 33 of 35 (32 by L0, 1 by L1 only). Not caught: 2.

| Id | Change | Class | Why |
| --- | --- | --- | --- |
| e16 | Case (b) takes its 2 nearest results with no check that they agree. L0 passes, L1 fails | Test gap in L0 (L1 catches it) | No L0 row has a pair where the 2 nearest results differ and case (a) still gives one result, for example epochs `n1..n3` and `n4..n6`, pass at `n1`, fail at `n4`, gap `n2`: the answer is `pass` from `n1` |
| e34, e35 | An interval with one id in D and one id not in D holds the places from that id to a made-up end (`99`) or from `0` | Test gap | The row "an interval with ids that are not in D" has 2 ids that are both not in D. D5 says "an interval with ids that are not in D holds nothing", so a half-known interval holds nothing too. The L1 epochs always use ids of D |

Both gaps are for the test agent (TW18). Closed on 2026-10-23: see "Gap tests (test agent, 2026-10-23)": e16, e34 and e35 are caught by new L0 rows (and by L1). The code is the same as before the changes: `sha256sum -c research/slice-033-revert/code-final.sha256` gives OK, and `cmp` with `code-final/cli/lib/Epochs.roc` is equal.

## Gap tests (test agent, 2026-10-23)

Only tests and this file changed. No file of `cli/` changed. The 3 mutations of `agent-mutate.py` were applied by hand (`research/slice-033-revert/gap-mutate.py`, log `gap-mutate.log`): the new row failed, and `cli/lib/Epochs.roc` was copied back from `code-final/` (`cmp` equal, `sha256sum -c research/slice-033-revert/code-final.sha256`: all OK).

| Mutation | New test | Result of the mutation |
| --- | --- | --- |
| e16 (case (b) with no check that the 2 nearest results agree) | L0 `epochs` 3, row "case (a) gives one result, the 2 nearest results of case (b) differ: case (b) gives none": epochs `n1..n3` and `n4..n6`, pass at `n1`, fail at `n4`: `n2` and `n3` are `pass` from `n1`, `n5` and `n6` are `fail` from `n4` | L0 caught (that row), L1 caught |
| e35 (an interval with a first id that is not in D holds the places from 0) | L0 `epochs` 3, row "an interval with a first id that is not in D holds nothing": interval `x1..n3`, pass at `n2`: no inferred fact | L0 caught (that row), L1 caught |
| e34 (an interval with a last id that is not in D holds the places up to 99) | L0 `epochs` 3, row "an interval with a last id that is not in D holds nothing": interval `n4..x2`, pass at `n5`: no inferred fact | L0 caught (that row), L1 caught |

L1: the generator `tests/fuzz/epochs.roc` has a new value 3 in `cuts`: a group gets an interval with one real id and the id `zz` (first or last, by the place), and the oracle treats its releases as held by no interval. So e34 and e35 are also found by L1 (they were not before). `epochs` 3 has 19 rows (the row count of section 5 is the exact count, 57 rows in the 4 `expect`s).

`scripts/test.sh` exits 0 with the code (`research/slice-033-revert/gap-green.log`: check 1.0, fmt 0.2, l0 6.1, l1 4.6, l2 1.0, l3 9.8, selftest 8.3 s, no WARN). No background process runs.

## Close (manager, 2026-10-23)

The code result is accepted (no new decision, no dispute). Of 35 mutations, 32 were caught by L0 and 1 by L1 only. The gap rows close e16, e34 and e35 in L0 and L1. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN. The Q1 answer (union) stays provisional until the user answers U4 of `PLAN-P1.md`. Status: done.
