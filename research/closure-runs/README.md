# The closure facts as runs in a window of compilers (Registry R-AP16, R-AP17, R-AP42, Q50)

Question: the closure answer sent every matrix row of each hash on all compilers. That grows with each nightly: about 1.8 MB of JSON for 3 years of a closure of 26 hashes, on each resolve. Can the answer send only what the client needs for the compilers that the command can choose, and still give the client the same facts (real, inferred or unknown, Resolution 4, R-EP2 to R-EP6)?

Answer: yes. The client sends the window W of compilers that it can choose (`compilers`, R-AP16). The registry makes W larger to the ends of its epochs that W touches (E), and sends:

| Field | What | Why |
| --- | --- | --- |
| `epochs` | The epochs of the registry in E with 2 or more compilers: intervals where each transition has a `transitions` row with `changed` = 0 | They replace the `sweeps` and `transitions` rows. Case (a) of R-EP3 and the coverage of R-EP2 are in them. |
| `runs` | The matrix rows in E, as runs of one (hash, target, source) with one result and error digest on adjacent compilers. A compiler with no row ends a run. | Case (a) of R-EP6 reads each fact of the epoch of a compiler, and the epoch can go past W |
| `nearest` | For each (hash, target), the nearest code result before E and after E, after the precedence of R-EF3 | Case (b) of R-EP6 reads only these outside E |
| `hints` | The user hints in W, added up over the Talon versions | Search order only |

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs [sqlite] [cases]` | Random matrices (gaps, faults, `bot` and `author` rows, 3 targets, random sweeps) and random windows (one compiler, open end, short). For each case, the facts of the client in W from the answer must be equal to the facts from all rows. Local D1 (wrangler `getPlatformProxy`) and plain SQLite, the same cases on both. Default 400 cases. Exit code 1 if a case fails. |
| `MUTATE=noexpand node test.mjs sqlite` | W is not made larger to the epochs. Fails. |
| `MUTATE=nogap node test.mjs sqlite` | A run goes over a compiler with no row. Fails. |
| `MUTATE=nomerge node test.mjs sqlite` | `nearest` ignores the precedence of the sources. Fails. |
| `MUTATE=fault node test.mjs sqlite` | `nearest` can be a hang or a crash. Fails. |
| `node bench.mjs [years] [d1]` | Size and time of the old answer and of the new one, plain SQLite or local D1 |

The SQL is in `schema.mjs`: 4 statements with one CTE prefix, so one D1 batch (R-AP41). Needs Node 22 or later and a global `wrangler` (4.151.0). Delete `.wrangler/` after a run.

## Results (2026-10-18)

`node test.mjs 400`: 400 of 400 cases equal on local D1 and on SQLite (160 with one compiler, 2,578 inferred facts compared). Hints 400 of 400. With 1,000 cases each mutation fails: `noexpand` 363 cases, `nogap` 357, `nomerge` 18, `fault` 65.

`node bench.mjs 3`: 900 compilers, 26 closure hashes (25 packages, 1 platform with 7 targets), 300 other hashes, 114,324 rows in all. The bot checks each hash on each compiler for 18 months. About 1 compiler in 20 breaks code, and each hash then changes its result with a chance of 30%.

| Answer | Rows | JSON bytes | SQLite ms | Local D1 ms |
| --- | --- | --- | --- | --- |
| All rows of the closure (old) | 11,934 | 1,802,917 | 7 | 74 |
| One compiler (a held nightly) | 58 | 9,281 | 49 | 73 |
| The last 30 compilers | 58 | 9,281 | 49 | 72 |
| All compilers (a free nightly) | 333 | 49,086 | 56 | 82 |

The time is the 4 statements one after the other. Each statement computes the epochs again (11 to 17 ms of the time). The local D1 time of the old answer is mostly the transfer of 1.8 MB.

Found on the way: the first SQL joined the epoch CTE to itself to make W larger, which was quadratic (2 s for all compilers). An epoch number only grows with the order, so the epochs that W touches are one range of numbers, and the join is linear.

## What this does not prove

| Item | Status |
| --- | --- |
| Remote D1 | Not tested. `research/d1-remote/` has the setup. |
| The epoch CTE in each statement | A first cost. An `epochs` table that the `transitions` trigger (R-MX12) keeps would remove it. Not built. |
| The order of compilers | The test uses one list of compilers for all targets (the order of R-NS1). A target that a compiler has no asset for gives a compiler with no row, which ends a run: correct, but more runs. |
| A local fact of the client that is a fault on the compiler of a `nearest` row | The client then needs the code result before it, which the answer does not have. R-EP6 case (b) then gives nothing, and the pair can stay unknown: one more probe, never a wrong decision (R-EP8). |
