# Check speed (P1 section 5, follow-up item of 023c)

Roc: nightly-2026-10-14-38a3029. Machine: 24 cores, load average 10 to 18 during the runs (other programs), so the times move by 30 percent.

## 1. Does `roc test` fail on what `roc check` reports?

Variants are copies of `tests/unit/why.roc` (`run.sh` runs them). Exit codes of `roc check` and `roc test`, both with `--no-cache`:

| Variant | roc check | roc test | Same? |
| --- | --- | --- | --- |
| clean | 0 | 0 | yes |
| unused variable (warning) | 2 | 2 | yes, same message |
| type mismatch (error) | 1 | 1 | yes, same message |
| unknown name (error) | 1 | 1 | yes |
| unused import | 0 | 0 | yes (neither reports it) |

`roc test` also runs the tests. The l0 step fails on any exit code other than 0 (scripts/test.sh, `step_l0`), so a warning in a unit file fails l0.
Limit: `roc test` checks only the unit file and the modules it imports. Modules that no unit file imports stay covered by the `roc check` of `cli/main.roc` and `cli/lib/main.roc`.

## 2. Time per app (seconds)

| Case | Time |
| --- | --- |
| `roc check` of one unit file, cache warm | 0.03 to 0.4 |
| `roc check` of one unit file, `--no-cache` | 0.4 to 0.9 |
| `cli/main.roc`, cold cache, alone | 5.7 |
| `tests/commands/main.roc`, cold cache, alone | 5.1 |
| `cli/fxprobe.roc` or `cli/flowprobe.roc`, cold cache, alone | 4.8 to 5.0 |
| `cli/lib/main.roc`, cold cache, alone | 2.0 |
| Sum of the 60 calls one after the other (warm) | 10.3 |

The unit files are cheap one by one, but with a cold cache (after an edit in `cli/lib`) every call compiles the shared modules again at the same time.

## 3. The check step with a cold cache (all calls at the same time unless noted)

| Variant of the step | Seconds |
| --- | --- |
| Before: 60 apps in parallel | 6.6 to 7.1 (9.1 and 10.3 in full runs under load) |
| 5 apps in parallel (no unit files) | 8.3 to 8.9 |
| `cli/main.roc` first, then the 4 other apps in parallel | 4.6 to 5.7 |
| After: `cli/main.roc` first, then the rest, no unit files | 4.8 to 5.6 (warm cache: 0.3 to 0.6) |

Taking the unit files out alone is not enough: 5 cold apps at the same time are slower than 60 (the cache is empty for all of them). Running `cli/main.roc` first fills the cache for the others.

## 4. Change

| File | Change |
| --- | --- |
| `scripts/test.sh` | `APPS` has no unit file (l0 guards them). `step_check` runs `cli/main.roc` first, then the rest in parallel. |
| `tests/selftest.sh` | New row `s_unit_guard`: the real roc, the real l0 step, one unit file: clean passes, unused variable fails, type error fails. The row `s_chk_par` counts the 5 apps and checks that no `tests/unit` file is in the `check` calls. |

Both rows were checked against a mutation (l0 ignores the roc exit code): `s_unit_guard` and `s_l0_par` fail.
