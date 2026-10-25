# l0 time: 86 `roc test` processes to 12

Task: PLAN-P1 section 5b, "l0 is at its budget". The l0 step of `scripts/test.sh` took 9 to 12.4 s in a full run (budget 10 s, TW20). Machine: 24 threads (12 cores), pinned roc nightly-2026-10-14-38a3029.

## 1. Cause

Data of one `roc test --no-cache --jobs=1` for each file alone, no other load (`per-file.sh`, `per-file-j1.txt`):

| Measure | Value |
| --- | --- |
| Files | 86 (82 in tests/unit, 4 in packages/resolve/tests) |
| Sum of the times of the 86 files | 43.2 s |
| Files under 0.2 s / 0.2 to 0.5 s / 0.5 to 1 s / over 1 s | 39 / 14 / 17 / 16 |
| Slowest file | upgrade.roc 1.9 s |
| Mean time of a file with 1 / 2 / 3 / 5 `import lib.X` lines | 0.14 / 0.47 / 0.41 / 1.13 s |
| One file that imports all modules that the 82 files import (no expect), `--jobs=1` | 1.5 s |
| All 428 expects in one process, `--jobs=1` | 16 s (type check 0.4 s, lowering and compile-time eval 4.8 s with 24 threads, run 1 s) |
| Peak memory: one file / all in one process | 0.3 to 0.5 GB / 3.6 GB |
| The l0 step, 24 processes at the same time (before) | 5.9 to 6.8 s wall, CPU 112 to 121 s (user + sys) |

Finding: no few slow files. The time of a file follows the number and the size of the modules that it imports (each file type checks and lowers its imports again). 86 processes spend 43 s for work that is 16 s in one process. A process also costs 0.3 to 0.5 GB, so 24 at the same time are memory-bound and the CPU time grows 2.8 times (121 s against 43 s). In a full run the 6 builds and the fuzz builds use the same CPU, so l0 went to 9 to 12.4 s.

## 2. Options measured

Only l0 (`sweep.sh`, same command as `step_l0`), no other load, wall seconds:

| Option | Wall (s) | Note |
| --- | --- | --- |
| Before: 86 files, -P 24, 1 thread | 5.9 to 6.8 | CPU 112 to 121 s |
| Before, -P 16 / 12 / 8, 1 thread | 6.2 / 6.7 / 8.3 | fewer jobs is slower |
| Before, 2 threads each, -P 24 / 12 / 8 | 6.6 / 6.7 / 7.8 | no gain |
| `--opt=interpreter` | no gain | measured on one file and on a driver (3.15 s against 3.06 s) |
| `--specialize=no` | 1.8 times slower | not used |
| All 82 files in 1 process, 24 threads | 8.0 | the lowering step does not scale to 24 threads; 3.6 GB |
| 2 / 3 / 4 / 6 / 8 / 12 groups (prototype) | 5.4 / 4.8 / 4.8 / 4.6 / 4.5 / 4.5 | threads for each process 12 / 8 / 6 / 4 / 3 / 1 or 2 |
| 8 groups, threads 1 / 2 / 3 / 4 | 5.5 / 4.8 / 4.5 / 4.5 | |
| Real tree, 8 drivers + 4 package tests, -P 12, threads 1 / 2 / 3 / 4 | 5.6 / 5.3 / 5.1 / 5.3 | the 4 package tests add 0.3 s |
| Roc test result cache (no `--no-cache`) | 0.26 s for a file with no change | Not used: a cached pass does not run the expects (`(cached)` in the output). The step uses `--no-cache` on purpose. |

Why a merge by `cat` was not used: 82 files have top-level helpers with the same name and a different value (`view` 11 times, `cand` 9, `u` 12, `now` 11, ...). A merge needs a rename in the expect bodies. The fix below moves no line of any expect.

## 3. Fix

The unit files are modules. Eight drivers import them.

| Part | Rule |
| --- | --- |
| Unit module | `tests/unit/<Name>Test.roc` (old name `foo.roc` gives `FooTest.roc`). No header. The line `app [main!] { lib: ... }` is gone. The line `main! = \|_args\| Ok({})` is now the line `<Name>Test :: [].{}` (a headerless file must define the type of its file name; the old header gives roc warning `module header deprecated`, exit 2). Every other line is the same. |
| Driver | `tests/unit/l0-<n>.roc`, n = 1 to 8: an app that imports its modules. Each module is in one driver. The modules are split by the time of the old file (largest first, to the driver with the smallest sum): `assign.txt`, `gen-drivers.sh`. |
| `unit_files` (tests/lib.sh) | The l0 files: the apps of tests/unit (the first line starts with `app `) and `packages/*/tests/*.roc`. `scripts/test.sh` and `tests/selftest.sh` use it. |
| `unit_modules_check` (tests/lib.sh) | Fails the l0 step when a module is imported by 0 or by 2 or more drivers. A module that no driver imports is never run, and `roc test` says nothing about it. It uses `read`, no process for each file (14 ms; with `head` and `grep` it was 1 s). |
| `L0_THREADS` | Default 2 (was 1). With 12 processes, 2 threads are faster than 1 (table 2). |
| Selftest | The rows that named `tests/unit/lock.roc` or counted `tests/unit/*.roc` use `units` (the first and the second of `unit_files`). The row l0_order expects `--jobs=2`. New row `unit_modules` (68 rows pass). |

Peak memory of a driver with 2 threads: 0.9 to 1.0 GB (the memory rule uses 1 GB for each l0 job; not changed).

Not changed: the 4 `packages/resolve/tests/*.roc` files stay one process each (the rule: no file of `packages/` goes away; they cost 3.4 s of CPU of 66 s). The budget is the same (10 s). No expect body, no rule comment changed.

## 4. Times

Full `scripts/test.sh`, cold (`full-runs.sh`: `$WORK/l0-times`, the order file, is removed before each run. The l0 step has no other cache: `roc test --no-cache`, and the roc result cache is off. The package cache stays, as in each run). l0 seconds:

| State | Run 1 | Run 2 | Run 3 | Note |
| --- | --- | --- | --- | --- |
| Before (`full-runs-before.sh`, the old script and the 86 old files from `before/`) | 12.4 | 10.7 | 11.7 | |
| Before, warm order file (one run, start of the task) | 9.0 | | | |
| After, set 1 | 7.2 | 6.8 | 7.0 | |
| After, set 2 | 16.9 | 6.7 | 6.3 | run 1: another process loaded the machine (check 5.3 s, fmt 0.7 s in the same run); not a result of the change |
| After, set 3 (the three that count) | 6.4 | 6.7 | 7.3 | all steps pass, no WARN |

l0 alone (`scripts/test.sh l0`, no other load): before 6.8 s, after 5.2 to 5.5 s. CPU of the step (user + sys, `sweep.sh`): before 112 s, after 65 s.

Variants of drivers and threads in the full run (2 cold runs each, l0 s; `matrix.sh`): 8 drivers 3 threads 7.1 and 6.5; 6 and 3: 6.9 and 7.7; 6 and 4: 6.3 and 7.9; 10 and 2: 6.9 and 7.3; 4 and 6: 7.0 and 7.0. All are inside the noise of the machine (+- 0.5 s), so 8 drivers and 2 threads stay. The floor in a full run is about 6.5 s: the builds of l1 use the CPU at the same time.

## 5. Checks

| Check | Before | After |
| --- | --- | --- |
| `expect` count (`count-expects.sh`) | 428 | 428 |
| Rule-id comment lines | 642 | 642 |
| Checksum of all rule ids (sorted) | b893cfeca690 | b893cfeca690 |
| Checksum of all lines except header, imports, `main!`, type line, blank lines (sorted, `LC_ALL=C`) | 1dbb00adb585 | 1dbb00adb585 |
| Tests that roc reports (`count-roc-tests.sh`) | 428 (86 files) | 428 (12 files) |
| `MISSING=1 scripts/rules.sh` | `rules-missing-before.txt` (453 lines) | `rules-missing-after.txt`: no difference (`diff`) |
| Mutation: the line `import IdentTest` removed from a driver | | l0 FAIL: `l0: tests/unit/IdentTest.roc: 0 drivers import IdentTest (it must be 1: ...)` (file restored) |
| `roc fmt --check` of the new files | | pass |

## 6. Files changed

| Path | Change |
| --- | --- |
| `tests/unit/*.roc` (82) | Each file became `tests/unit/<Name>Test.roc` (header and `main!` line only). Copies of the 82 old files: `research/l0-time/before/tests/unit/`. |
| `tests/unit/l0-1.roc` to `l0-8.roc` | New (the list is in `before/NEW.txt`) |
| `scripts/test.sh` | `UNIT` from `unit_files`; `L0_THREADS` default 2; `unit_modules_check` in `step_l0`. Copy: `before/scripts/test.sh` |
| `tests/lib.sh` | `unit_is_app`, `unit_files`, `unit_modules_check`. Copy: `before/tests/lib.sh` |
| `tests/selftest.sh` | `units`, the rows l0_par, l0_order, limit_l0, new row unit_modules. Copy: `before/tests/selftest.sh` |

Stale text: about 40 comments and files (code comments in `cli/lib`, `docs/slices`, a `rules` file of an L2 case) name the old path `tests/unit/foo.roc`. The new name is `tests/unit/FooTest.roc`. They are not changed (a rule comment must not change).

Tools in this dir: `per-file.sh`, `sweep.sh`, `full-runs.sh`, `full-runs-before.sh`, `matrix.sh`, `gen-drivers.sh`, `convert.sh` (the one-time conversion), `count-expects.sh`, `count-roc-tests.sh`, `gen-proto.sh`, `test-proto.sh` (the old `scripts/test.sh` with a unit list, for the baseline). `before/cli`, `before/packages`, `before/tests/fixtures` are symlinks, so the old files in `before/` still run.

## 7. Proposed text for TESTING.md (not edited)

Add to the L0 section (2 or 3), and one row to the table of TW rules:

| Id | Text |
| --- | --- |
| TW(new) | A unit file is a module: `tests/unit/<Name>Test.roc`, no header, with the line `<Name>Test :: [].{}` after its imports. A driver `tests/unit/l0-<n>.roc` (an app) imports it. Each module is in exactly one driver (`scripts/test.sh` checks it). A new module goes to the driver with the smallest time in `$WORK/l0-times`. The name of the module is not the name of a `lib` module (`ClockTest`, not `Clock`: a type cannot have the name of an import). `roc test` on a driver runs all expects of its modules. |
| (change of TW20 text) | The l0 step runs about 12 processes (8 drivers and the package tests), not one for each unit file. |

Rule ids in a module and the rule that "a test names the rule ids" are the same as before.

## 8. Open

| Point | Note |
| --- | --- |
| The roc test result cache would make an unchanged run 1 s | Not used: a cached pass runs no expect. A user decision. |
| The 4 package tests | Could be one driver; it saves about 1 s of CPU. They are in `packages/`. |
| PLAN-P1 section 5b row "l0 is at its budget" | Can be closed with this file. The manager edits PLAN-P1. |
