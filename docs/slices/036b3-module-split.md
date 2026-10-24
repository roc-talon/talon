# Slice 036b3: module split and l0 time

Phase: P1. Status: done

Slice 036b3 is the plan row 036b3 of `PLAN-P1.md`. It is a refactor with no behavior change, as slice 031b. Three modules were over 500 lines. They are split by topic, so slice 036c (the Epochs wiring, optional downloads, `fix:` lines) has room. The l0 step took 8.8 s of its 10 s budget. It is now 6.6 s.

No test, fixture or expected file changed (`calls.log` is the same). No `expect` moved between unit files. Copies of the changed files are in `research/slice-036b3-revert/before/`. The new files are in `research/slice-036b3-revert/NEW.txt`.

## Result of the split

| Old module | Lines before | Lines after | New modules (lines) | What moved |
| --- | --- | --- | --- | --- |
| `cli/lib/InstallFlow.roc` | 576 | 173 | `InstallPlan` (277), `InstallWrite` (163) | `InstallPlan`: `Planned`, `Done`, `idle`, `fresh_plan`, `fresh_step`, `replace_edit`, `add_edit`, `pairs_of`, `dropped`, `pick_notes_of`, `pre_lines`, `outcome_of`, `no_ran`, `name_of`, `version_of`. `InstallWrite`: `confirm_moves!`, `ladder!`, `ladder_member`, `write!`, `changed_files!`. `InstallFlow` keeps `install!`, `frozen!`, `resolve!`, `attempts!`, `finish!`. |
| `cli/lib/Manage.roc` | 525 | 399 | `ManageUse` (112), `ManageUpdate` (55) | `ManageUse`: `read_use`, `use_pinnable`, `use_plan`, `UseRow`, `use_note`, `use_report`, `use_data` and the texts of the refusal. `ManageUpdate`: `read_update`, `update_report`, `update_data`. `update_move` stays in `Manage` (it calls `kind_of`). |
| `packages/resolve/Solver.roc` | 508 | 344 | `SolverBase` (97), `SolverProbe` (94), `SolverWhy` (54) | `SolverBase`: the types of the API, `Val`, `Var`, `Inc`, `Env`, `Span`, and the builders `dedupe`, `norm`, `mk`. `SolverProbe`: `probe_incs` and the intervals of D. `SolverWhy`: `why_of` and the steps of the explanation. `Solver` keeps `step`, `step_moves` and the search. |

`Pin` (467) and `Toolchain` (456) are under 500 lines. They are not split.

## Names that stay in the old module

A unit test calls these names, so the old module keeps them as one line (`name = NewModule.name`). Callers in `cli/lib` use the new names.

| Old name | Value |
| --- | --- |
| `Manage.read_update`, `update_data`, `update_report` | `ManageUpdate.<same name>` |
| `Manage.read_use`, `use_data`, `use_note`, `use_pinnable`, `use_plan`, `use_report` | `ManageUse.<same name>` |
| `Solver.Slot`, `Dep`, `Fact`, `Term`, `Check`, `Use`, `Compat`, `Request`, `Ask`, `Chosen`, `Cause`, `Step`, `Why` | the type of the same name in `SolverBase` (a type alias: the same type) |

`InstallFlow` has no name that a test calls (`Resolve.install!` calls `InstallFlow.install!`). `RocUse` calls `ManageUse`, and `RocManage` calls `ManageUpdate`.

## Import rules

| Module | Imports | Why it is no cycle |
| --- | --- | --- |
| `InstallFlow` | `InstallPlan`, `InstallWrite`, `ResolveBase`, `ResolveLoad`, `ResolveSelect`, `PickFlow`, ... | the two new modules do not import `InstallFlow` |
| `InstallPlan`, `InstallWrite` | `ResolveBase` and the pure modules (`Add`, `Ident`, `Pin`, `Locked`, `Ladder`, ...) | `ResolveBase` and these modules import neither |
| `Manage` | `ManageUse`, `ManageUpdate` | they import `Args`, `Fail`, `JsonDoc`, `Pin`, `Locked`, `Compiler`, `Toolchain`, not `Manage` |
| `ManageUse`, `ManageUpdate` | no `Manage` | `UseRow` is in `ManageUse`; `text_or_null` is a private copy of 4 lines in each module |
| `Solver` | `SolverBase`, `SolverProbe`, `SolverWhy` | the three import `SolverBase` (and `Search`) only |
| `SolverProbe`, `SolverWhy` | `SolverBase` | `SolverBase` imports `Domain`, `Search`, `Semver` only |

The new modules are in the `package` lists of `cli/lib/main.roc` and `packages/resolve/main.roc`.

## l0 time

| Run (default `scripts/test.sh`, warm cache) | l0 (s) |
| --- | --- |
| Before the slice | 8.9 (8.8 in the plan) |
| Slowest first, 2 threads for each `roc test` | 7.9, 8.0 |
| Slowest first, 1 thread for each `roc test` | 7.6 |
| And 2 threads for each build | 7.0 |
| And 1 thread for each build (the final rule) | 6.6, 6.6, 6.6 |

Where the time went:

| Cause | Finding | Change |
| --- | --- | --- |
| `roc test` starts one compile thread for each CPU (24) | One file (`evidence.roc`) takes 1.0 s wall and 3.9 s of CPU with the default, and 1.0 s wall and 1.7 s of CPU with `--jobs=2`. 12 processes at the same time spend the CPU of 288 threads. | `roc test --jobs=$L0_THREADS`, default 1 |
| The builds start at the same time and use all CPUs too | 6 builds (l2, tln, fxprobe, flowprobe, 2 fuzz targets) with 24 threads each. `vmstat` showed 90 % CPU use and 35 runnable processes while l0 ran. | `roc build --jobs=$BUILD_THREADS`, default 1, only when the run has the l0 step and `OPT=dev` |
| Alphabetical start order | With the times of one run, 12 jobs: 7.4 s alphabetical, 6.7 s slowest first (ideal 6.6 s) | `l0_order`: the order of the last run, slowest first |
| A unit file that imports `lib` | Each of these files type checks and lowers the modules that it imports (about 0.5 s of CPU). This cost is the same for each file, so a split of a slow unit file adds CPU. | No unit file is split. No `expect` moved. |

Other results of the same measure:

| Measure | Result |
| --- | --- |
| All 76 unit files, one after the other, `--jobs=1` | 31 s. 48 files take less than 0.5 s. The slowest is `evidence.roc` (1.4 s). |
| All 76 files, 12 at the same time, no builds | 5.9 s with the default threads, 5.4 s with `--jobs=2`, 5.6 s with `--jobs=1` |
| `--opt=interpreter` for `roc test` | No gain (1.02 s against 1.17 s). Not used. |
| `nice` for the builds | No gain (7.6 s against 7.9 s). Not used. |

## Change of scripts/test.sh

| Part | Rule |
| --- | --- |
| `l0_order` and `$WORK/l0-times` | Lines `<ms> <file>`. The step writes them after each run. xargs starts the files slowest first. A file with no time goes first. The report stays in the order of the unit files. |
| `L0_THREADS` | `--jobs=` of each `roc test` (default 1) |
| `BUILD_THREADS` | `--jobs=` of each `roc build` (also the fuzz builds). Default 1 when the steps have `l0` and `OPT=dev`, else the default of roc. The memory rule (`jobs_for`, `CHECK_MB`, `BUILD_MB`) is the same. |

Rows in `tests/selftest.sh`:

| Row | What it checks |
| --- | --- |
| `l0_order` (new) | The files start with the file that has no time first, then the longest time first. Each `roc test` has `--jobs=1`. The step writes one time for each unit file. |
| `opt_dev` (one check added) | With `l0` in the steps, each build of `test.sh` has `--jobs=1`. The row `l1` (no l0 in the steps) keeps its text: no `--jobs`. |
| `opt_speed` (one check added) | With `OPT=speed`, no build of `test.sh` has `--jobs` |
| The `unset` line | `BUILD_THREADS` and `L0_THREADS` of the caller do not change the rows (the first run of the new rows failed on a value that the outer `test.sh` had exported) |

Hand mutation: in `scripts/test.sh` the line `l0_order | tr '\n' '\0' | xargs ...` was changed to `printf "%s\n" "${UNIT[@]}" | tr ...` (the alphabetical order). The row `l0_order` failed (`selftest: 65 passed, 1 failed`). The file was restored (`cmp` equal).

## Checks

| Check | Result |
| --- | --- |
| `roc check cli/main.roc`, `cli/lib/main.roc`, `packages/resolve/main.roc` | no error, no warning |
| `scripts/test.sh` (3 runs) | exit 0, no WARN. Last run: check 1.0, fmt 0.2, l0 6.6, l2 2.8, l3 9.8, selftest 10.6, l1 31.1 |
| `OPT=speed scripts/test.sh` | exit 0 (l2 174.9 s: the LLVM build, over its budget as before) |
| Files of tests, fixtures and expected files | not changed (`git status` shows only the files of this slice) |

## Close (manager, 2026-10-24)

Accepted. No test, fixture or expected file changed (only `tests/selftest.sh`: the `l0_order` row and the build `--jobs` checks). `scripts/test.sh` exits 0 with no WARN: l0 6.7 s (was 8.9 s), l2 2.9 s, selftest 10.3 s, l1 31.9 s. Status: done.
