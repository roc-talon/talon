# Slice 039s: module split and l0 time (OPT=speed)

Phase: P1. Status: done

Slice 039s is the plan row 039s of `PLAN-P1.md`. It is a refactor with no behavior change, as slices 031b and 036b3. `Oracle.roc` had 499 lines, so the slices 039b and 039c had no room. The threshold of this slice is 450 lines: four modules were over it. Each is split by topic.

No test, fixture or expected file changed (`calls.log` is the same: the md5 of each file under `tests/` and `packages/*/tests/` is the same before and after). No `expect` moved. Copies of the changed files are in `research/slice-039s-revert/before/`. The new files are in `research/slice-039s-revert/NEW.txt`.

## Result of the split

| Old module | Lines before | Lines after | New modules (lines) | What moved |
| --- | --- | --- | --- | --- |
| `cli/lib/Oracle.roc` | 499 | 76 | `OracleBase` (48), `OracleRequest` (146), `OracleSearch` (137), `OracleCause` (80), `OracleHint` (51) | `OracleBase`: the types `Input`, `Compat`, `Pair`, `Verdict`, `Free`, and `is_current`, `platform_of`. `OracleRequest`: `request_of`, `solver_slot`, `solver_fact`, `slot_group`, `same_group`, `given`, `used_of`, `checks_of`, `roc_slot`, `values_of`, `movable_of` and the small helpers. `OracleSearch`: `search`, `walked`, `scanned`, `lookups`, `needs_scan`, `fetch_first`, `pairs_of`, `optimistic`, `wants_domain`, `has_probe`, `chosen_of`. `OracleCause`: `failure`, `causes_of`, `blame_text`, `label_of`, `alias_of`. `OracleHint`: `hint`, `works_on`, `step_hint`, `settled`, `with_empty`. `Oracle` keeps `step_free`, `step`, `step_probed` and the module doc. |
| `cli/lib/Toolchain.roc` | 462 | 374 | `ToolchainFail` (60), `ToolchainReport` (63) | `ToolchainFail`: `download_failed`, `tar_failed`, `offline_missing`, `offline_no_list`, `program_name`, `ended_text`. `ToolchainReport`: `size_text`, `report`, `data`, `tenths_text`. |
| `cli/lib/Pin.roc` | 467 | 346 | `PinOrder` (135) | The order and the identity of compiler ids: `is_nightly`, `is_release`, `same_id`, `order_of`, `at_least`, `nightly_key`, `day_of`, `same_day`, `by_version`, `month_number` and the types and tables they use. |
| `cli/lib/ProbeCmd.roc` | 471 | 270 | `ProbeFlow` (214) | The command code: `run!`, `flow!`, `finish!`, `single!`, `ranged!`, `request_of`, `node_of!`, `materialise!`, `unbundle_program`, `rows_of`. `ProbeCmd` keeps the pure part (`read`, `entry`, `bundle_hash`, `unbundler`, `stop`, `text`, `data`, the types). |

No module of `packages/resolve` is over 450 lines (the largest is `Solver`, 344 after slice 036b3). The largest module of `cli/lib` is now `Pick` (443).

Changes of the code that are not a move:

| Where | Change | Why |
| --- | --- | --- |
| `OracleBase` | The file-level type `Step` of `Oracle` is gone. `OracleBase.Input` is the same record, so the types are equal. | One name for one type |
| `OracleSearch.search` | One new argument `hint_of` (a function), also a new field of the `run` record of `walked`. `OracleCause.failure` has one new argument `hint` (a value). | `failure` called `hint`, and `hint` calls `search`. The two cannot import each other. `search` calls `hint_of` only when `assume` is on and the proof has a probe cause (the same case as before: `causes_of` has an entry for each probe cause). |
| `OracleHint.step_hint` | It gives `search` a `hint_of` that is never called (`assume` is off). | See above |
| `Oracle.step_free` | It gives `search` the function `OracleHint.hint`. | See above |
| `ProbeFlow.run!` | The old `ProbeCmd.run!` is not kept. `Run.roc` calls `ProbeFlow.run!`. | No unit test calls `run!` |

## Names that stay in the old module

A unit test calls these names, so the old module keeps them as one line (`name = NewModule.name`, with the type line). Callers in `cli/lib` can call either name.

| Old name | Value |
| --- | --- |
| `Oracle.hint` | `OracleHint.hint` (`tests/unit/oracledomain.roc` calls it) |
| `Toolchain.download_failed`, `tar_failed`, `offline_missing`, `offline_no_list` | `ToolchainFail.<same name>` (`tests/unit/toolchain.roc`) |
| `Toolchain.size_text`, `report`, `data` | `ToolchainReport.<same name>` (`tests/unit/toolchain.roc`, `cacheview.roc`, `clean.roc`, `gc.roc`) |
| `Pin.is_nightly`, `Pin.same_id` | `PinOrder.<same name>` (`tests/unit/manage.roc`, `evidence.roc`, `gc.roc`). `Pin.order` and `Pin.admits` keep their text and call `PinOrder`. |

The types of `Oracle` (`Input`, `Compat`, `Pair`, `Verdict`, `Free`) have no alias. No unit test names them. The callers changed to `OracleBase.<Type>`: `PickLoop` (code), `ResolveBase` and `NightlyPlan` (doc comments).

## Import rules

| Module | Imports | Why it is no cycle |
| --- | --- | --- |
| `Oracle` | `OracleBase`, `OracleRequest`, `OracleSearch`, `OracleHint` | None of the four imports `Oracle` |
| `OracleHint` | `OracleBase`, `OracleRequest`, `OracleSearch` | `OracleSearch` takes the hint as a function argument, so it does not import `OracleHint` |
| `OracleSearch` | `OracleBase`, `OracleRequest`, `OracleCause`, `OracleDomain` | `OracleCause` gets the hint as a value |
| `OracleCause`, `OracleRequest` | `OracleBase`, `OracleDomain` | `OracleBase` imports only data modules (`Pick`, `Db`, `Epochs`, `Closure`, `Release`, `Fail`) |
| `Toolchain` | `ToolchainFail`, `ToolchainReport` | They import `Download`, `Fail`, `JsonDoc` only |
| `Pin` | `PinOrder` | `PinOrder` imports `Clock`, `Selector`, `Text`, `Semver`, not `Pin` (so `is_nightly` and `same_id` moved with the order) |
| `ProbeFlow` | `ProbeCmd`, `ProbeBundle`, `ProbeSearch`, `ProbeUnit`, ... | `ProbeCmd` does not import `ProbeFlow` (that is why `run!` moved) |

The new modules are in the `package` list of `cli/lib/main.roc`.

## l0 time with OPT=speed

The plan row says 10.0 s, at the budget of 10 s.

| Run | l0 (s) |
| --- | --- |
| `OPT=speed scripts/test.sh l0` (2 runs, l0 alone) | 5.8, 5.8 |
| `scripts/test.sh l0` (2 runs, l0 alone) | 5.6, 5.8 |
| `scripts/test.sh` (full, dev, 2 runs) | 7.9, 7.7 |
| `OPT=speed scripts/test.sh` (full) | 9.9 |

Finding: the l0 step does not depend on `OPT` (`roc test` has no `--opt`). With l0 alone, speed and dev are the same (5.8 s). In the full run the `roc build` of the test apps and of the fuzz targets run at the same time. With `OPT=dev` each build has `--jobs=1` (slice 036b3). With `OPT=speed` the builds are LLVM builds and keep all threads on purpose (`scripts/test.sh`, the comment above `BUILD_THREADS`), so they take the CPU of l0: 9.9 s against 7.8 s. The WARN line of the budget is for `OPT=dev` only (TW26), so the 9.9 s gives no warning.

Change needed: no. A change would make the LLVM builds slower (`--jobs=1` for an LLVM build of 150 s) or would start them after l0 (the whole run gets longer), to improve a time that has no budget check. `scripts/test.sh`, `tests/selftest.sh` and the selftest rows are not changed (`cmp` equal to the copies in `research/slice-039s-revert/before/`).

## Checks

| Check | Result |
| --- | --- |
| `roc check` of `cli/main.roc`, `cli/lib/main.roc`, `packages/resolve/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc`, `tests/commands/main.roc` | no error, no warning |
| `roc fmt --check` (the `fmt` step) | pass |
| `tests/unit/oracle*.roc`, `pick*.roc` (the rows that call `Oracle`) | pass, the same counts as before |
| `scripts/test.sh` (2 runs) | exit 0, no WARN. Last run: check 1.1, fmt 0.2, l0 7.7, l2 5.2, l3 9.8, selftest 11.2, l1 28.1 |
| `OPT=speed scripts/test.sh` | exit 0. check 1.1, fmt 0.2, l0 9.9, l2 150.6 (LLVM build, over its budget as before), l3 9.8, selftest 11.4, l1 17.0 |
| Files under `tests/` and `packages/*/tests/` | md5 equal before and after |
| Files of the slice in `git status` | `Oracle`, `Toolchain`, `Pin`, `ProbeCmd`, `Run`, `PickLoop`, `ResolveBase`, `NightlyPlan`, `main.roc` changed. 9 new modules. No other file |

## Close (manager, 2026-10-24)

Accepted. No file under tests/ changed (md5 equal). The Oracle cycle is broken by passing the hint as a function argument, with the old condition. The OPT=speed l0 time (9.9 s) comes from the LLVM builds at the same time; that run has no budget check (TW26), so no change. Status: done.
