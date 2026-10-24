# 018 Test speed

Phase: P1. Status: done

This slice changes the test harness only. No Talon code changes. Source: `docs/slices/PLAN-P1.md` row 018 and section 3.4. The user accepted `--opt=dev` in the fast set, with `OPT=speed` before a merge and each night (`PLAN-P1.md`, "Answers of the user (2026-10-22)", row 3). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-018-revert/before/` (with `NEW.txt`).

Why: the fast set takes 118 s now, and 80 s of it is the LLVM build of the test apps. Each P1 slice adds code to both apps, so the fast set would pass the 180 s of TW20 in a few slices. Measured with a private reference of this change (deleted): the fast set takes 30 s.

## Rules

TW20 (changed), and 3 new rules that the code agent writes into `TESTING.md` (text in "TESTING.md text"): TW25 (build mode), TW26 (step budget), TW27 (slow tag). No design rule (R-xx) is in this slice.

## What changes

| # | Before | After | Rule |
| --- | --- | --- | --- |
| 1 | `scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh` build with the default LLVM backend (98 s for the L2 app, 87 s for `tln`) | They build with `--opt=dev` (5 s and 2 s). `OPT=speed` gives the LLVM build. Another value of `OPT` is an error (exit 2) | TW25 |
| 2 | `tests/run.sh` skips the tag `slow` with no way to run it | `SLOW=1` runs the cases with the tag `slow`. The tags `windows`, `exdev` and `real-roc` work as before | TW27 |
| 3 | The `l0` step runs the `roc test` files one after the other (14 to 19 s for 50 files) | The files run in parallel (at most `JOBS` at one time, the default is the CPU count). The log is still in the order of `sort -u`. A failed file fails the step, and its name and output show | TW20 |
| 4 | No time check | `scripts/test.sh` prints the budget of each step in the table, a `WARN` line for each step over its budget, and a `WARN` line for a run over 180 s. A warning does not change the exit code | TW26 |
| 5 | `scripts/env.sh` sets `WORK` always | `WORK` keeps the value that the caller sets. The selftest needs it to run `scripts/test.sh` in its own dir | TW25 |

## Public interface

There is no Roc code in this slice, so there are no stubs. The old harness files are the stubs: they do not have the behavior of the table, so the new rows fail.

| Item | Interface |
| --- | --- |
| `OPT` | Variable. Not set means `dev`. `dev` and `speed` are valid. Each `roc build` call of the three scripts has one flag `--opt=<mode>` (also for `speed`, so the log shows the mode). A bad value: the text `OPT must be dev or speed (got: <value>)` on stderr, exit 2, before any build. A good place for the check is one function in `tests/lib.sh` that the three scripts call |
| `SLOW` | Variable. `SLOW=1` makes `tests/run.sh` run the tag `slow`. It reaches `tests/run.sh` through the environment of `scripts/test.sh` (no change in `test.sh` for it) |
| `WORK` | `scripts/env.sh`: `WORK=${WORK:-$ROOT/.work}` |
| `JOBS` | Variable that exists. The `l0` step uses it too (`parallel_jobs` of `tests/lib.sh`) |
| `BUDGET_<STEP>` | Variable, seconds (a decimal number is valid). `BUDGET_CHECK`, `BUDGET_FMT`, `BUDGET_L0`, `BUDGET_L1`, `BUDGET_L2`, `BUDGET_L3`, `BUDGET_SELFTEST`. It changes the budget of one step for this run |
| `BUDGET_TOTAL` | Variable, seconds. The budget of the whole run, from the start of the script to the table. Default 180 |
| `ROC` | Variable that exists. The selftest sets it to a fake roc |

Default budgets (seconds):

| Step | Budget | Source |
| --- | --- | --- |
| check | 10 | Decision D1. Measured 3.5 to 6.4 s |
| fmt | 5 | Decision D1. Measured 0.1 s |
| l0 | 10 | `PLAN-P1.md` 3.4 row 5 |
| l1 | 60 | `PLAN-P1.md` 3.4 row 5 (the step does not exist yet) |
| l2 | 30 | `PLAN-P1.md` 3.4 row 5 |
| l3 | 60 | `PLAN-P1.md` 3.4 row 5 |
| selftest | 15 | Decision D1. Measured 6 s before this slice, 13 s with the new rows |
| total | 180 | TW20 |

## Output (proposed, TW24)

The table of `scripts/test.sh` gets a fourth column. The warning lines come after the table.

```text
step       result seconds  budget
check      pass   3.5      10
fmt        pass   0.1      5
l0         pass   3.6      10
selftest   pass   16.2     15
WARN selftest: 16.2 s is over the budget of 15 s (TW20)
WARN total: 190.4 s is over 180 s (TW20)
```

| Item | Format |
| --- | --- |
| Budget column | The value as the default table or `BUDGET_<STEP>` gives it. The selftest rows test only the form `^<step> +<result> +<seconds> +<budget>$` |
| Step warning | `WARN <step>: <seconds> s is over the budget of <budget> s (TW20)`. The rows test the start `WARN <step>` |
| Total warning | `WARN total: <seconds> s is over <budget> s (TW20)`. The rows test the start `WARN total` |
| L0 log | Unchanged: `<file>: <the roc test summary>` for a pass, `<file>: FAILED` and then the roc output for a failure |

## Tests

The tests are rows of the harness selftest (`tests/selftest.sh`, its section "Slice 018"). There are 7 rows. They run `scripts/test.sh`, `tests/run.sh` and `tests/commands/run.sh` with a fake roc (written by the selftest into its temp dir) and with their own `WORK` dir, so no row builds a real binary. The fake roc logs its calls, makes a no-op binary for `build` only under the `WORK` dir of the row, sleeps for `FAKE_ROC_SLEEP` s, and fails for the file in `FAKE_ROC_FAIL`.

| # | Layer | Row (`tests/selftest.sh`) | What it checks | Rules |
| --- | --- | --- | --- | --- |
| 1 | selftest | `OPT unset` | `scripts/test.sh check fmt l0 l2 l3` (4 builds), `tests/run.sh` (3 builds) and `tests/commands/run.sh` (1 build): each `roc build` call has exactly one `--opt` flag, and it is `--opt=dev`. `tests/run.sh` ends with exit 0 | TW25 |
| 2 | selftest | `OPT=speed` | The same 3 scripts: each build has `--opt=speed` | TW25 |
| 3 | selftest | `OPT=fast` | The 3 scripts end with exit 2 and the text `OPT must be dev or speed`, and no `roc build` call is logged | TW25 |
| 4 | selftest | budget column | The table of the run of row 1 has the budget of check (10), fmt (5), l0 (10), l2 (30) and l3 (60). The l2 and l3 steps fail (the builds fail): the budget shows for a failed step too | TW26 |
| 5 | selftest | `slow tag` | 3 L3 cases: `slow/ok` (tag `slow`, passes), `slow/bad` (tag `slow`, fails), `slow/win` (tag `windows`, fails). Fast set: `0 passed, 0 failed, 3 skipped`, exit 0. With `SLOW=1`: `FAIL slow/bad`, `1 passed, 1 failed, 1 skipped`, exit 1 (the `windows` tag stays skipped) | TW27 |
| 6 | selftest | `l0 in parallel` | `scripts/test.sh l0` with `JOBS=4`, a fake `roc test` that takes 0.2 s and fails for `tests/unit/lock.roc`: the step fails (`== l0: FAIL`), the log has `tests/unit/lock.roc: FAILED` and the roc output of that file, all other files pass, the files are in sorted order, and the fake saw at least 2 and at most 4 runs at one time | TW20 |
| 7 | selftest | `budget` | Three runs of `scripts/test.sh fmt` with a fake `fmt` that takes 0.6 s. `BUDGET_FMT=0.3`: a `WARN fmt` line, no `WARN total`, exit 0. `BUDGET_FMT=30 BUDGET_TOTAL=30`: no `WARN` line, exit 0. `BUDGET_FMT=30 BUDGET_TOTAL=0.3`: a `WARN total` line, no `WARN fmt`, exit 0 | TW26 |

Other changes in `tests/selftest.sh` (not rows):

| Change | Why |
| --- | --- |
| At the start, `OPT`, `SLOW`, `JOBS`, `VERBOSE`, `TAIL`, `REAL_ROC`, `TLN`, `L2BIN` and all `BUDGET_*` are unset (`OPT` is kept in `SELFTEST_OPT`) | A merge run (`OPT=speed SLOW=1 scripts/test.sh`) must not change the old rows: with `SLOW=1` the old row `runner/slow` would not be skipped |
| The standalone selftest builds the L2 app with `--opt="$SELFTEST_OPT"` (default `dev`) | A standalone run took 98 s with the LLVM build |

## Files

| File | Change |
| --- | --- |
| `tests/selftest.sh` | Done by the test agent: the 7 rows and the 2 changes above |
| `scripts/env.sh` | `WORK=${WORK:-$ROOT/.work}` (code agent) |
| `tests/lib.sh` | The `OPT` check as one function (code agent) |
| `scripts/test.sh` | `OPT`, the parallel `l0`, the budgets, the table and the `WARN` lines. Update the header comment (code agent) |
| `tests/run.sh` | `OPT` in the 3 builds. `SLOW=1`. Update the header comment (code agent) |
| `tests/commands/run.sh` | `OPT` in the build (code agent) |
| `TESTING.md` | The text of "TESTING.md text" (code agent, the user accepted it) |
| `docs/slices/PLAN-P1.md` | Section 3.3 and 3.4 stay as they are. The manager can mark row 018 done |

## TESTING.md text (proposal, the user accepted the change)

The code agent applies these edits. Each row gives the place, the old text and the new text.

| # | Place | Old | New |
| --- | --- | --- | --- |
| E1 | Section 1, after the layer table (a new paragraph and table) | (none) | See the block "E1" below |
| E2 | Section 2.4 or 2.5, the paragraph that starts "One `roc test` run of a small module" | `The build time of the full `tests/commands/` app is not measured yet.` | `The full `tests/commands/` app builds in 5 s with `--opt=dev` and in 98 s with `--opt=speed` (2026-10-22). Its 35 cases run in 0.5 s. The `tln` app builds in 2 s and in 87 s.` |
| E3 | Section 3.1, the line `tags` | `tags                optional: real-roc, slow, tty, windows, exdev` | Keep the line. Add the table "E3" below it |
| E4 | Section 3.2, the row `Parallel` | `Cases run in parallel. Each has its own dirs.` | `Cases run in parallel, at most `JOBS` at one time (default: the CPU count). Each has its own dirs. The L0 files run in parallel the same way.` |
| E5 | Section 3.2, new rows after `Parallel` | (none) | `Build mode` and `Slow cases`: see the block "E5" below |
| E6 | Section 7.1, step 4 (Verify), column "Done when" | `L0, L1 fast, L2 and L3 fast pass.` | `L0, L1 fast, L2 and L3 fast pass in fast mode (TW25).` |
| E7 | Section 7.3, rule TW20 | `Before each hand-off, the fast set (L0, L1 fast, L2, L3 fast) passes, in under 3 minutes.` | `Before each hand-off, the fast set (L0, L1 fast, L2, L3 fast) passes, in under 3 minutes. Each step has a share of this time (TW26).` |
| E8 | Section 7.3, after TW24 | (none) | The rules TW25, TW26 and TW27 (block "E8" below) |

Block E1 (section 1, after the layer table):

```markdown
The runs differ in the build mode and in the cases that they include:

| Run | Command | Test binaries | Cases | When |
| --- | --- | --- | --- | --- |
| Fast | `scripts/test.sh` | `--opt=dev` | No `slow` case | Before each hand-off (TW20) |
| Merge | `OPT=speed SLOW=1 scripts/test.sh` | `--opt=speed` (LLVM) | All `slow` cases | Before a merge, and each night |
| Nightly | `OPT=speed SLOW=1 REAL_ROC=1 scripts/test.sh`, and the long L1 runs | `--opt=speed` | The `slow` cases and L4 | Each night |

The dev backend and LLVM can give two results for one program. The merge run finds such a difference. A difference is a roc bug: report it. The case keeps the `speed` result (TW25).
```

Table E3 (section 3.1, below the `tags` line):

```markdown
| Tag | Meaning | In the fast set |
| --- | --- | --- |
| `slow` | The case takes more than 2 s with small limits (TW27) | Skipped. `SLOW=1` runs it. |
| `real-roc` | L4: the pinned roc, not the fake | Skipped. `REAL_ROC=1` runs it. |
| `tty` | A pseudo terminal (3.2) | Runs |
| `windows` | Windows only | Skipped on Linux |
| `exdev` | Needs two file systems | Skipped |
```

Block E5 (section 3.2, two rows):

```markdown
| Build mode | `OPT=dev` (default) or `OPT=speed`. The three scripts that build a test binary (`scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh`) pass `--opt=<mode>` to `roc build`. Another value: exit 2 (TW25). |
| Slow cases | A case with the tag `slow` is skipped. `SLOW=1` runs it (TW27). |
```

Block E8 (section 7.3, three rows):

```markdown
| TW25 | The fast set builds the test binaries (`l2`, `tln`, `fxprobe`, `flowprobe`) with `--opt=dev`. `OPT=speed` gives the LLVM build. The merge run and the nightly run use `OPT=speed`. If a case passes in one mode and fails in the other, it is a roc bug: report it. The case keeps the `speed` result. |
| TW26 | `scripts/test.sh` prints the budget of each step. It prints a `WARN` line for a step over its budget and for a run over 180 s. A warning does not fail the run. The budgets (seconds): check 10, fmt 5, l0 10, l1 60, l2 30, l3 60, selftest 15. `BUDGET_<STEP>=<s>` and `BUDGET_TOTAL=<s>` change them for one run. After a warning, the slice removes the cause before the hand-off (a slow case gets the tag `slow`, TW27), or the human changes a budget in this file. |
| TW27 | An L3 case with a real wait sets small limits (for example `probe.timeout = 1` in `config.toml`). A case that still takes more than 2 s has the tag `slow`. The fast set skips it. `SLOW=1` runs it. The merge run and the nightly run set `SLOW=1`. |
```

## Decisions that the design does not fix

The PLAN gives the idea of each change. These details are not in it. The test agent chose them, and the human can change them at the review.

| # | Point | Choice | Rejected |
| --- | --- | --- | --- |
| D1 | Budgets of check, fmt and selftest (the PLAN names l0, l1, l2, l3 only) | check 10, fmt 5, selftest 15. The shares add to 190 with l1: no run uses all shares, and the total of 180 is a second check | A budget for the 4 steps of the PLAN only (the 3 other steps would have no check). Shares that add to 180 exactly (selftest 5 s would warn at once) |
| D2 | The name of the flag for the slow cases | `SLOW=1`, like `REAL_ROC=1` | `--slow` (the scripts have no flags, only variables) |
| D3 | The name of the build variable | `OPT` is `dev` or `speed` (the PLAN names `OPT=speed`) | `--opt` pass-through of any value (a typo would build with the wrong mode, or fail late in roc) |
| D4 | `OPT=speed` | Passes `--opt=speed` explicitly | No flag (the default of roc): the log of a run would not show the mode, and the selftest could not tell it from `dev` with a missing flag |
| D5 | A warning | Prints, and the exit code stays 0 (PLAN: "a warning") | A failure above a limit: time depends on the machine (TW15) |
| D6 | Where the total starts | At the start of `scripts/test.sh`, so it includes the builds that run in the background | The sum of the step times (it would not show the start up) |
| D7 | The `slow` tag in L2 | Not added. L2 has no case tags, and all L2 cases take 0.5 s together | A `tags` file for L2 cases (no use now) |
| D8 | The selftest runs the scripts with a fake roc, not with a real build | Yes, so the rows take about 7 s and need no binary | A row that builds the real L2 app with both modes (about 100 s for `speed`) |

## Out of scope

| Item | Where |
| --- | --- |
| CI jobs (Linux, macOS, Windows, nightly) | Slice 018b |
| The tag `net` and its nightly run | Slice 053 |
| A check that finds an L3 case of more than 2 s with no tag `slow` | Question Q1 |
| The L1 step (roc-fuzz). Only its budget (60 s) is set | The first L1 target |
| Faster L3 cases with `probe.timeout = 1` (`PLAN-P1.md` 3.4 row 4): no L3 case has a real wait now (L3 takes 9 s) | The slices that add such cases follow TW27 |
| L4 (`REAL_ROC=1`): the variable passes through the environment, as now | Unchanged |
| Real check that the dev backend and LLVM agree on all cases | The merge run, with the first `OPT=speed SLOW=1 scripts/test.sh` after this slice |

## Questions (TW17)

| # | Question | Effect |
| --- | --- | --- |
| Q1 | Should `tests/run.sh` print a warning for an L3 case that takes more than 2 s and has no tag `slow` (`PLAN-P1.md` 3.4 row 4: "a case that still takes more than 2 s gets the tag `slow`")? The time of a case depends on the load of the machine (24 cases at the same time), so a warning can be wrong (TW15) | Default: no. TW27 is a rule for the author of the case, with no check. This part is not in the slice until the human answers |

## Disputes (from the code agent)

(none)

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | Do not edit `tests/selftest.sh` (TW18). If a row looks wrong, write a dispute here and stop |
| 2 | The rows run the scripts from the repo root with `ROC`, `WORK`, `TMPDIR` and the `FAKE_ROC_*` variables set. The scripts must read `ROC` and `WORK` from the environment (`scripts/env.sh` does for `ROC`) |
| 3 | `scripts/test.sh` must exit 2 for a bad `OPT` before it starts a build or a step. `tests/run.sh` and `tests/commands/run.sh` the same |
| 4 | For the parallel `l0`: print the lines in the order of `UNIT` (not in the order in which the runs end). The row compares the file order with `sort`. Use `--no-cache` as now. Run the real `l0` step 5 times to check that parallel `roc test` runs do not disturb each other |
| 5 | The row for `l0` uses `JOBS=4` and expects at most 4 runs at one time. Use the same `parallel_jobs` as the case runners |
| 6 | A warning must come after the table (the row only needs the line to start with `WARN <step>`) |
| 7 | Update the header comments of `scripts/test.sh` and `tests/run.sh` (`OPT`, `SLOW`, `BUDGET_*`) |
| 8 | After the code: run `scripts/test.sh` (fast), then `OPT=speed SLOW=1 scripts/test.sh` once. Write both tables in "Verify results". The second run is the first check that dev and LLVM agree |
| 9 | The rows set their own fake roc. They do not need a change in `tests/fakes/roc` |

## Red output

`research/slice-018-revert/red.md`. `scripts/test.sh` on the final tree: check, fmt, l0, l2 and l3 pass (the old tests). The selftest step fails with 7 rows (24 old rows pass):

| Row | Why it fails today |
| --- | --- |
| `OPT unset` | The builds have no `--opt` flag. Also `WORK` is not read from the caller, so the fake roc refuses the output of `tests/run.sh` |
| `OPT=speed` | Same |
| `OPT=fast` | The scripts do not check `OPT` (exit is not 2) |
| budget column | The table has 3 columns |
| `slow tag` | `SLOW=1` is ignored: the 3 cases are skipped |
| `l0 in parallel` | The files run one after the other (the most seen at one time is 1) |
| `budget` | No `WARN` line |

## Revert check

`research/slice-018-revert/results.md`. The test agent wrote a private reference of the harness change, ran the selftest with it (31 passed, 0 failed, and `scripts/test.sh` in 30 s), then deleted it (the files are the same as `before/`). 21 mutations of the reference, each alone: each makes at least one new row fail. The old rows pass with the reference.

## Verify results (code agent)

Run on 2026-10-22 with the pinned roc. Both runs exit 0 (7 new rows and 24 old rows of the selftest pass).

| Step | Budget | `scripts/test.sh` (dev) | `OPT=speed scripts/test.sh` |
| --- | --- | --- | --- |
| check | 10 | 3.6 | 4.2 |
| fmt | 5 | 0.1 | 0.1 |
| l0 | 10 | 3.6 | 5.5 |
| l2 | 30 | 0.5 | 82.2 (waits for the LLVM build, WARN) |
| l3 | 60 | 9.3 | 9.2 |
| selftest | 15 | 13.2 | 13.3 |
| whole run | 180 | 30.3 | 114.6 |

The `speed` run passes all L2 and L3 cases: dev and LLVM agree on them. `SLOW=1` was not run: no case has the tag `slow` yet. The real `l0` step ran 5 times in a row (3.3 to 3.5 s): 50 of 50 files pass each time, so parallel `roc test --no-cache` runs do not disturb each other.

Revert check: `research/slice-018-revert/code-mutate.py`, results in `research/slice-018-revert/code-results.md`. 20 mutations caught of 21. Not caught: M11 (the tag `exdev` is no longer skipped by `tests/run.sh`). This skip is old behavior, and no row of slice 018 or older rows uses an `exdev` case. The five harness files are equal to the copy in `research/slice-018-revert/code-before/` after the run.

## Review (manager, 2026-10-22)

D1 to D8 and the TESTING.md edits E1 to E8 (TW25, TW26, TW27, TW20) are accepted. The user approved the `--opt=dev` change (docs/slices/PLAN-P1.md, "Answers of the user"), so the code agent applies E1 to E8 to TESTING.md. Q1: the default (no warning for a slow L3 case). Status: code.

## Review of the code (manager, 2026-10-22)

`scripts/test.sh` passes (manager run: 30.5 s in total; check 3.9, fmt 0.1, l0 3.5, l2 0.5, l3 9.2, selftest 13.4). The code agent's `OPT=speed` run passes too (114.6 s). The revert check caught 20 of 21. M11 (the old `exdev` skip) is accepted as not caught. Note: the selftest budget (15 s) is close to the measured 13 to 15.5 s; slice 018b may raise it if CI runners are slower.
