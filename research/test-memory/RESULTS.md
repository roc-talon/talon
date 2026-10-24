# Test memory (P1 section 5, follow-up item)

Roc: nightly-2026-10-14-38a3029. Machine: 24 cores, 91 GB RAM. An out-of-memory kill happened during a session of test runs (`journalctl -k -b -1`, 08:23:56).
Tools in this dir: `measure.sh` (peak RSS of each roc call, `/usr/bin/time -v`), `sample.sh` (samples a command tree every 0.2 s, kills it when MemAvailable is under `GUARD_GB`).

## 1. Cause

`roc check` and `roc build` read every file of the roc object cache (`$ROC_CACHE_DIR/compat-*/objects-v7`) into memory (anonymous memory, not mapped file pages: RssAnon 14.4 GB). Each edit of `cli/lib` adds a 13 MB file to `objects-v7/x64musl-dev/pkg/<hash>/`, and nothing removes it.
On 2026-10-23 the cache had 3751 files (11 GB; `mod/` had 14 GB more, which does no harm to memory).

| Experiment (`roc check cli/main.roc`) | Time | Peak RSS |
| --- | --- | --- |
| Cache as it was (3751 object files, 11 GB) | 3.7 s | 14.5 GB |
| Same cache, `objects-v7` moved away | 0.3 s | 0.47 GB |
| Fresh cache dir, cold, then warm | 4.4 s, then 0.3 s | 0.76 GB, then 0.47 GB |
| `--no-cache` | 1.0 s | 0.75 GB |
| Only `objects-v7/x64musl-dev/pkg` moved away | 1.1 s | 2.5 GB |
| Newest 100 files of the big dir kept (rest of the cache as it was) | 1.3 s | 4.2 GB |
| Newest 3 files of each dir kept (232 files, 68 MB) | 0.39 s | 0.59 GB |

The time is the "Shared Monotype Lowering" phase (3.3 s of 3.7 s, `--timings`). The cost is linear in the size of the cache. A small cache has no cost.
`cli/lib/main.roc` (a package, no lowering) and `cli/fxprobe.roc` stay at 0.1 s and 0.2 GB with the big cache. `cli/main.roc` and `tests/commands/main.roc` (the apps that import all of `lib`) are the two that go to 14 GB. Each of the 4 `roc build` calls did the same (12 to 14.7 GB).
It looks like a roc bug (it reads the files of all old versions of a package, not one): report it.

## 2. Peak RSS of each call, one at a time

Before = the cache as it was. After = after `prune_roc_objects` (87 MB, 236 files).

| Call | Before | After | Time before | Time after |
| --- | --- | --- | --- | --- |
| check `cli/main.roc` | 14217 MB | 613 MB | 3.8 s | 0.4 s |
| check `tests/commands/main.roc` | 14205 MB | 621 MB | 3.6 s | 0.4 s |
| check `cli/fxprobe.roc`, `cli/flowprobe.roc`, `cli/lib/main.roc` | 111 to 189 MB | 111 to 193 MB | 0.1 s | 0.1 s |
| build l2 (`tests/commands/main.roc`, dev) | 14691 MB | 1652 MB | 5.4 s | 2.2 s |
| build tln (`cli/main.roc`, dev) | 14608 MB | 1619 MB | 5.3 s | 2.2 s |
| build fxprobe, flowprobe (dev) | 11954 and 12018 MB | 210 and 373 MB | 3.0 s | 0.2 s |
| `roc test` of one unit file, `--no-cache` | 558 MB | 560 MB | 0.9 s | 0.8 s |

All 60 unit files with `--no-cache`: maximum 564 MB (`tests/unit/why.roc`), mean 220 MB.

## 3. One full `scripts/test.sh` run (OPT=dev, warm cache)

`sample.sh` sums the RSS of the whole process tree every 0.2 s. All runs: exit 0, no WARN (except the 4 GB row).

| Run | check | l0 | l2 | l3 | selftest | Total | Peak memory |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Before (big cache, 24 jobs) | 7.4 | 7.4 | 5.1 | 9.3 | 3.7 | 33 s | 48.1 GB (6.6 s above 20 GB) |
| After, default (budget 25 GB) | 0.8 | 5.0 | 1.3 | 9.4 | 3.7 to 7.0 | 24 s | 5.1 to 5.6 GB |
| After, `TEST_MEM_GB=12` | 0.8 | 6.6 | 0.8 | 9.4 | 9.6 | | 4.0 GB |
| After, `TEST_MEM_GB=4` | 0.8 | 15.4 (WARN) | 0.8 | 9.4 | 3.7 | | 3.4 GB |
| After, `OPT=speed` | 0.8 | 5.2 | 77.7 | 9.5 | 7.0 | | 7.1 GB |

Budgets (TW26): check 10, l0 10, l2 30, l3 60, selftest 20. `OPT=speed` has no WARN line (the LLVM build of l2 is slow on purpose).

## 4. Rule in `scripts/test.sh` and `tests/lib.sh`

| Part | Rule |
| --- | --- |
| Object cache | `prune_roc_objects` runs at the start. In each dir of `objects-v7` it keeps the `OBJ_KEEP` (default 3) newest files. A file under 10 minutes old stays (a run at the same time does not lose it). First run: 4.9 s (11 GB removed). A run with nothing to remove: 0.6 s. |
| Budget | `TEST_MEM_GB` (default: a third of MemAvailable, 25 GB here) |
| Jobs | `jobs_for cores budget reserve per_job` = min(cores, (budget - reserve) / per_job), at least 1. `JOBS` caps the cores. |
| check and l0 | per job 1000 MB (peak seen 620 MB). l0 reserves the memory of the builds that run at the same time. |
| Builds | per job 2000 MB (peak seen 1650 MB). At most min(4, budget / 2000) builds at the same time. With a budget under 8 GB the builds wait for a free slot. |
| Limit | With a budget of 4 GB, l0 runs 1 job and takes 15 s (over its budget of 10 s). The default budget has no such cost. |

Selftest row `s_mem`: `jobs_for` and `mem_budget_mb` with fixed numbers, `prune_roc_objects` on a made cache, and the l0 step with `TEST_MEM_GB=1` and `3` (1 job and 2 to 3 jobs at one time). Mutations checked: no cap by cores, no prune, a prune that ignores the age, l0 without `roc_jobs` (each makes a row fail).

## 5. Not done

| Item | Note |
| --- | --- |
| `mod/` cache: 14 GB, 10116 files | It grows by edit too, but it costs disk only (667 GB free). No prune rule yet. |
| `tests/run.sh` and `tests/commands/run.sh` alone | They do not prune. Run `scripts/test.sh` (or `scripts/test.sh check`) first. |
| Two `scripts/test.sh` runs in one repo | They share `.work/logs` and `.work/bin`. The memory rule is per run: two runs use two budgets. |
