# 228 own-sort: `Sorted.sort_with` in the Worker build

Phase: P2 (registry). Status: code (green).

## Why

| Item | Value |
| --- | --- |
| Fault | The compiler makes a full copy of its `List.sort_with` at each call site: 140 to 250 KB of wasm for each site (`cloudflare-workers/research/bigfn2/README.md` sections 1 and 2). The call sites together are about 1.9 MB of the 5.17 MB code section of `worker/app.wasm`. |
| Fix | A stable merge sort in Roc, `Sorted.sort_with`, for every call site. Each site then costs a few KB. |
| Evidence | Variant `m2` of `research/bigfn2/` (all sites changed): `app.wasm` 5,260,039 to 3,393,205 bytes. 35.5 percent smaller. The largest function falls from 243 KB to 177 KB. |
| Ready diff | `cloudflare-workers/research/bigfn2/sort-fix.diff`. Test start: `cloudflare-workers/research/bigfn2/sorted-test/`. Both are read only for this slice. |

## Rules

The design has no rule id for this change. It is a build-size change. The tests below are named by what they check.

| Item | State |
| --- | --- |
| Rule change | None |
| Response change | None: the status, the headers and the body of each answer stay the same, byte for byte (ETag rules R-AP24, R-AP49 and R-AP53 hold because the result of the sort does not change) |
| Contract of the new function | The same as `List.sort_with`: stable, `Same` keeps the input order. A comparator that is not a total order is out of scope (the result is then not defined). |

## Scope

New module `packages/records/Sorted.roc`:

```roc
Sorted.sort_with : List(a), (a, a -> [Before, Same, After]) -> List(a)
```

`packages/records/main.roc` exposes `Sorted` (done in the test step). The sort is a merge sort that splits at the middle, so it takes O(n log n) time and keeps the order of equal items.

### The call sites

The sources at the start of the slice (HEAD 32f92022) have 12 calls of the builtin `sort_with`. `research/bigfn2/README.md` says 11 (3 in records and 8 in worker/). The sources and `sort-fix.diff` both have 9 in `worker/` (Shorts and Ingest have 2 and 3 calls), so the count is 12. The check below uses the real count.

| # | File:line | Element | Comparator |
| --- | --- | --- | --- |
| 1 | `packages/records/Artifact.roc:61` | dep record | `compare(a.alias, b.alias)` |
| 2 | `packages/records/Artifact.roc:62` | `Str` | `compare` |
| 3 | `packages/records/Code.roc:112` | `Str` | `compare_bytes` of the UTF-8 bytes |
| 4 | `worker/lib/ArchiveRead.roc:313` | `Str` | `Artifact.compare` |
| 5 | `worker/lib/Ingest.roc:282` | dep record | `Artifact.compare` of the alias |
| 6 | `worker/lib/Ingest.roc:297` | name record | `order_relative_to` of the id |
| 7 | `worker/lib/Ingest.roc:321` | `Str` | `Artifact.compare` |
| 8 | `worker/lib/Reads.roc:371` | repo item | `Artifact.compare` of the name |
| 9 | `worker/lib/Shorts.roc:187` | `Str` | `Artifact.compare` |
| 10 | `worker/lib/Shorts.roc:222` | `(rank, Str)` | rank, then `Artifact.compare` |
| 11 | `worker/lib/Version.roc:98` | `Semver` | `order_relative_to` |
| 12 | `worker/ReconcileCron.roc:65` | 10-field row | `by_repo` |

Not in scope: the sorts in `packages/resolve/` (the CLI, not the Worker build) and in `worker/tests/`.

## Tests

The tests of a `packages/records` module are W0 tests: a module `packages/records/tests/<Name>Test.roc`, imported by the driver `packages/records/tests/w0.roc`. The step `w0` of `scripts/test.sh` runs the driver with both compilers (`ROC_TAG` and `ROC_TAG_WORKER`, `step_records`, R-PK7). The step `l0` does not run it (`unit_files` of `tests/lib.sh` leaves `packages/records/` out).

Rows in the tests are `(key, input position)`. The lists come from a fixed linear generator (seeds 1 and 987654321). The sizes are 0, 1, 2, 3, 4, 5, 7, 8, 9, 16, 17, 100, 101, 500 and 2000. The key ranges are 1 (all equal), 3, 50 and 1000000.

| Layer | Case (`packages/records/tests/SortedTest.roc`) | Checks |
| --- | --- | --- |
| W0 | line 58: the result is equal to `List.sort_with`, all sizes and ranges | same result as the builtin |
| W0 | line 66: the result is equal to a sort with the total order (key, position) | same result as an oracle that does not depend on a stable builtin |
| W0 | line 74: the keys never go down, and equal keys have their positions in rising order | stability |
| W0 | line 77: a hand-made list with ties | stability, a known result |
| W0 | lines 80 to 84: sizes 0, 1, 2 (swapped, in order, equal) | the small cases |
| W0 | line 90: a sorted list with ties, all sizes | already sorted input does not change |
| W0 | line 96: strictly descending keys, all sizes | reverse sorted input |
| W0 | line 99: descending positions with ties, all sizes | reverse sorted input with ties keeps the input order |
| W0 | line 112: all keys equal, a comparator on the key | all-equal input does not change |
| W0 | line 119: a comparator that says `Same` for each pair | all-equal input does not change |
| W0 | line 127: a comparator that goes down | the order is reversed, ties keep the input order |
| W0 | line 130: `Str` elements by length | other element type |
| W0 | line 132: record elements with a `Str` field | other element type |
| W0 | line 138: the input list is used after the sort | the sort is pure |
| Script | `worker/tests/frame.sh` (the step `w0`), block "Slice 228" | no call of the builtin `sort_with`, `sort_by` or `sort` in the build sources (`worker/`, `packages/records/`, not their tests, not `Sorted.roc`), and at least 12 uses of `Sorted.sort_with(` |

Evidence that the tests catch the fault:

| Change | Result |
| --- | --- |
| Stub `sort_with = \|list, _cmp\| list` (now in `packages/records/Sorted.roc`) | 10 of 117 tests fail, with both compilers (lines 58, 66, 74, 77, 82, 96, 99, 127, 130, 132). The 13 `frame.sh` lines fail (12 sites, then the count). |
| The sort of `sort-fix.diff` | 117 of 117 pass, with both compilers. `frame.sh` passes on a copy of the tree with `sort-fix.diff` applied (the 12 sites changed). |
| The same sort, but a tie goes to the right run (`Before \| Same` in `merge`, not `Before`) | 12 of 117 fail: lines 58, 66, 74, 77, 84, 90, 99, 112, 119, 127, 130, 132 (compiler 2026-10-14). |

## CPU check (measure, not a test)

`research/slice-228/run.sh` builds `research/slice-228/bench.roc` natively with `--opt=speed`, with both compilers. It sorts lists of 500 and 5000 rows many times and reports the time of one sort in microseconds (the time of the lists is taken away). Two shapes: `pair` is `(U64, U64)`, `record` is a 6-field record with 4 `Str` fields (sorted by a `Str` field as `by_repo`). Best of 5 runs. The sort of `sort-fix.diff` was measured, because `packages/records/Sorted.roc` is a stub in the test step (run it again after the code step: `research/slice-228/run.sh`).

Machine of the author, a single run, noisy. Time of one sort in microseconds:

| Compiler | Shape | Rows | `List.sort_with` | `Sorted.sort_with` | Ratio |
| --- | --- | --- | --- | --- | --- |
| 2026-10-14 (CLI) | pair | 500 | 97.8 | 661.1 | 6.8 |
| 2026-10-14 (CLI) | pair | 5000 | 1256.9 | 9778.0 | 7.8 |
| 2026-10-14 (CLI) | record | 500 | 503.4 | 1059.4 | 2.1 |
| 2026-10-14 (CLI) | record | 5000 | 6503.1 | 14605.8 | 2.2 |
| 2026-10-31 (Worker) | pair | 500 | 14.1 | 42.1 | 3.0 |
| 2026-10-31 (Worker) | pair | 5000 | 145.4 | 486.0 | 3.3 |
| 2026-10-31 (Worker) | record | 500 | 193.5 | 222.6 | 1.2 |
| 2026-10-31 (Worker) | record | 5000 | 2559.4 | 3113.2 | 1.2 |

Reading: the own sort is 1.2 to 7.8 times slower natively. With the Worker compiler and a record row (the case of the Worker) it is 1.2 times slower: 500 rows cost 0.22 ms. The Worker lists have 500 rows or less (`Sorted.roc` comment of the diff), so the cost is small against a D1 call. The `.wasm` speed is not measured here (the check is native). The `check=` values of `builtin` and `own` in the bench output are equal (same result).

## Output

None. No `data` field and no text changes.

## Out of scope

| Item | Reason |
| --- | --- |
| A comparator that is not a total order | The result of a sort with it is not defined, also for `List.sort_with` |
| `packages/resolve/` sorts | The CLI build, not the Worker build |
| The compiler issue (`research/bigfn2/upstream-issue.md`) | Not posted, another session |

## Questions (stop until answered)

None.

## Disputes (from the code agent)

None yet.

## Verify results

Test step, 2026-11-07 (`scripts/test.sh check fmt l0`, then `scripts/test.sh w0`):

| Step | Result | Note |
| --- | --- | --- |
| check | pass | |
| fmt | pass | |
| l0 | pass | 10.9 s (budget 10, WARN). `l0` does not run `packages/records` tests. |
| w0 | FAIL (expected) | `SortedTest`: 10 of 117 fail with each compiler (the stub). `frame.sh`: 13 lines (12 sites and the count). All other W0 tests pass (449 of the worker driver). |

## Code results

Code step, 2026-11-07. `Sorted.roc` is the sort of `sort-fix.diff` (the doc comments are in ASD-STE; `if n < 2 {` without parentheses, because `roc fmt` of the Worker compiler needs it). The 12 call sites use `Sorted.sort_with`. No test file was changed.

| Step | Result | Seconds |
| --- | --- | --- |
| check | pass | 4.3 |
| fmt | pass | 0.2 |
| l0 | pass | 9.8 |
| w0 | pass (SortedTest 117 of 117 with both compilers, 449 of the worker driver, `frame.sh` Slice 228 block) | 6.5 |
| wbuild | pass | 50.7 |
| w2 | pass | 29.8 |
| l3w | pass | 3.6 |
| l2 | pass | 25.7 |
| l3 | pass | 12.4 |

| Item | Before | After |
| --- | --- | --- |
| `app.wasm` bytes (`.work/worker/1859798927-566021/app.wasm`) | 5,260,039 (m2 measure base) | 3,393,205 |
| Code section bytes | | 3,302,597 |
| Largest function (func 185) | 243 KB | 176,616 |
| Next functions | | 70,730; 66,237; 63,134; 62,679 |

CPU (`research/slice-228/run.sh`, native, best of 5, microseconds for one sort):

| Compiler | Shape | Rows | `List.sort_with` | `Sorted.sort_with` | Ratio |
| --- | --- | --- | --- | --- | --- |
| CLI | pair | 500 | 111.7 | 736.5 | 6.59 |
| CLI | pair | 5000 | 1452.4 | 10767.2 | 7.41 |
| CLI | record | 500 | 519.6 | 1018.0 | 1.96 |
| CLI | record | 5000 | 6832.1 | 14886.5 | 2.18 |
| Worker | pair | 500 | 14.3 | 44.4 | 3.11 |
| Worker | pair | 5000 | 155.5 | 522.9 | 3.36 |
| Worker | record | 500 | 202.9 | 230.4 | 1.14 |
| Worker | record | 5000 | 2852.4 | 3220.5 | 1.13 |

The Worker record case (the real case) is 1.14 times slower: 500 rows cost 0.23 ms.
