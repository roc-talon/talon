# 075 `--version` check for a source build of `tool update talon`

Phase: P1. Status: done

Slice 075 is the plan row 075 of `PLAN-P1.md` (section 2c). It closes Q-F2 of slice 050. R-S3 (design agent, 2026-10-25): the check of `--version` "runs for a source build too" and "reads the exit code only". R-S3 also says: "A binary that does not start never replaces the working one."

Today `tln tool update talon --from-source` builds through `ToolBuild.finish!` (the build of `tool install`) and has no `--version` run (slice 050 Q-F2: "No"). The prebuilt path runs `<temp> --version` before the lock and the rename (`TalonUpdateFlow.started!`, step 9).

## 1. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-S3 | `--from-source` runs `<new file> --version` before the `rename`. Only the exit code 0 counts. A failure is exit 1, the old `tln` stays | L2 `tool/ts6-source` run 1 (the call), `tool/ts7-source-nostart` (the failure) |
| R-S2 (as used) | The source build of the tag (slice 050, unchanged) | `ts6-source` |
| R-T22, R-CC2 (as used) | The prebuilt file is checked the same way. The scratch dirs go after a failure | `ts7-source-nostart` |

The pure decision exists: `TalonUpdate.version_check` (L0 `TalonUpdateTest` 6: exit 0 is `Ok`, another exit, a signal and a start that fails are kind `Internal`). The text is the one of the prebuilt file. No new L0 row is needed.

## 2. Public signatures

None. No new function, type or `Fx` call is needed: the tests fix a call of `spawn_all!` (limit 1) that the flow does not make today. They fail with a wrong `calls.log`, not with `todo`.

## 3. Where the code changes (for the code agent)

The flow of the source path (`TalonUpdateFlow.built_from_source!` then `installed_from!`) calls `ToolBuild.finish!` (build, then the install under the lock of `tools.json`, then delete of the temp dir). The check goes inside it, between the build and the lock.

| # | Place | Change |
| --- | --- | --- |
| 1 | `ToolBuild.finish!` path | After a `Pass` build and before `fx.locked!` (so before the `.del` renames of Windows, R-ST10, and before any write): one `fx.spawn_all!({ jobs: [{ argv: [<layout.output>, "--version"], cwd: Err(Inherit) }], limit: 1 })`, then `TalonUpdate.version_check({ version, ended })`. `layout.output` is the file that the build wrote (`<scratch dir>/tln`). Nothing for `chmod`: the build output is an executable |
| 2 | A failed check | The error goes up (kind `Internal`, exit 1). The temp dir of the build (`layout.temp`) is deleted as after the install (R-CC2), then `built_from_source!` deletes the scratch dir of the source as it does today. No lock, no copy, no rename, no write of `tools.json` |
| 3 | Who runs it | Only the `talon` flow. `tool install`, `tool update` of other tools and `x` keep `finish!` with no check (R-S3 and R-T22 name the Talon update only). The reference adds `ToolBuild.finish_started!` (a variant with the version text) and `finish!` calls the shared private function with no check. The code agent may choose another shape: the L2 files fix the calls only |
| 4 | The version text | `release.version` (`0.3.4`), so the failure text is the one of the prebuilt file: `the new tln 0.3.4 does not start (exit 1). The old tln stays.` (the text of the entry `git v0.3.4@d0d0d0d0` was the other choice) |

The reference changes 2 files (`ToolBuild.roc`, 276 lines, and `TalonUpdateFlow.roc`, about 8 changed lines). The modules stay under 490 lines.

## 4. Decisions of the test agent (for the review)

| # | Decision | Options that I rejected | Why |
| --- | --- | --- | --- |
| D1 | The check runs on the build output in the scratch dir (`<scratch>/tln`), after the build and before the lock | On the copy in the data bin dir (`tln.<hex>.tmp`, as the prebuilt file): the copy is made inside the lock, after the `.del` renames of Windows, so a failure there leaves the old `tln` moved away (no roll back, R-S4). R-S3 says "a temp file" and "before the rename": the build output is a new file that is not the old one | The design says "before the rename" and does not name the file. The output is the one file that exists before the lock |
| D2 | The error text is the text of the prebuilt file, with the tag version | A new text for a source build | R-S3: "It runs for a source build too": the same check, so the same text (TW24: no new output) |
| D3 | A new L2 case `ts7-source-nostart` | A run 5 in `ts6-source` | The fake `fx/jobs` answers by the needle `--version` for all runs of a case, so a failing run needs its own case |

## 5. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L2 | `tests/commands/cases/tool/ts6-source` (changed) | Run 1 (the build with the tag commit) has one more call after the build probe and before the lock: `spawn_all limit=1` with `job - $HOME/.cache/roc/talon/tmp/<hex>/tln --version`. The job rule `--version` (exit 0) is added to `fx/jobs`. The other 3 runs do not change. `rules` text for run 1 changed | R-S3, R-S2 |
| L2 | `tests/commands/cases/tool/ts7-source-nostart` (new, 1 run) | The same flow, with `--version` that exits with 1 (`Segmentation fault`): exit 1 `the new tln 0.3.4 does not start (exit 1). The old tln stays.`, no `lock`, `copy_file`, `rename`, `hard_link` or `write_atomic` after the check, `tree.diff` has no change of `tln`, `roc` or `tools.json`, 2 `delete` of the scratch dir (the build dir, then the source dir: the fake `random` gives one hex, so both have the same path) | R-S3, R-T22, R-CC2 |

Counts: 0 new L0 `expect`s, 1 changed L2 case (1 `calls.log` change, 1 job rule), 1 new L2 case (1 run). New files (list in `research/slice-075-revert/before/NEW.txt`): the 22 files of `ts7-source-nostart`. The old copies are in `research/slice-075-revert/before/`.

The L2 `calls.log` fixes the number of `delete` calls after a failed check (2). A code agent that deletes both scratch dirs with one call must dispute (TW18) with the reason.

Red run (2026-10-25, the old code): `tests/commands/run.sh tool/ts`: 8 passed, 2 failed: `tool/ts6-source` (no `--version` call) and `tool/ts7-source-nostart` (exit 0, the update is installed). Full fast run with all 3 slices red: `check`, `fmt` and `selftest` pass, `l2` has 172 passed and 3 failed (`roc/ls1-list`, `tool/ts6-source`, `tool/ts7-source-nostart`), `l3` has 2 failed (`flags/fl12-bad-flags`, `compilers/mg1-manage`), `l0` has 7 `expect`s that fail (3 of 071, 4 of 069).

## 6. Out of scope

| Item | Reason |
| --- | --- |
| L3 for the source update | A real build needs a real `roc` and `zig` (L4). `tools/ts1-update-talon` covers the prebuilt check with the real `Fx` |
| `tool rebuild talon` | Exit 2 by R-S6 (slice 050) |
| A check of `--version` in `tool install` and `x` | R-S3 names the update of Talon |

## 7. Questions

None that stop the slice. D1 (which file) is the one point where the design is open: it is a decision for the review.

## 8. Revert check (private reference, deleted after the review)

| # | Mutation of the reference | Result |
| --- | --- | --- |
| 1 | The result of `--version` is ignored (the install goes on) | `ts7-source-nostart` fails |
| 2 | The check runs after the install | `ts6-source` and `ts7-source-nostart` fail |
| 3 | The scratch dir is not deleted after a failed check | `ts7-source-nostart` fails |

The reference passes `ts6-source` and `ts7-source-nostart` and `cli/main.roc` checks with 0 errors and the format check passes. After the check, `cli/lib/ToolBuild.roc` and `TalonUpdateFlow.roc` are the old files again (cmp with `before/`).

## 9. Review

Accepted by the manager, 2026-10-25: decisions D1 to D3.

## 10. Disputes (from the code agent)

| Test | Change | Design source |
| --- | --- | --- |
| L2 `tool/dx2-source-windows` (slice 050d) | `fx/jobs`: a rule `--version` with exit 0 added. `expect/calls.log`: for each of the 2 runs, `spawn_all limit=1` with `job - $HOME/<u>/.cache/roc/talon/tmp/0123456789abcdef/tln.exe --version` before the `lock` line. The case is a `--from-source` update, so the new check of R-S3 runs in it. Without the rule the fake gives exit 99 and the update fails. | R-S3 (a source build is checked before the rename), slice 075 section 1 |

## 11. Verify results (code agent)

Files: `cli/lib/ToolBuild.roc` (265 lines: `finish_checked!` with a check function; `finish!` calls it with a no-op check), `cli/lib/TalonUpdateFlow.roc` (371 lines: `file_started!`, shared by the prebuilt `started!` and the source build; `installed_from!` gets the release version in its record). Decision (slice 075 section 3, row 3 allows it): the check is a function argument, so `ToolBuild` does not import `TalonUpdate`; rejected: a second copy of `finish!` (`finish_started!`). The failure deletes `layout.temp` in `finish_checked!` and `built_from_source!` deletes the source dir: 2 separate `delete` calls.

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | The check result is ignored (the check runs, the install goes on) | `ts7-source-nostart` (also `ts6-source`, `dx2-source-windows`: the check call was dropped by the compiler in this form) |
| 2 | No `delete` of the build dir after a failed check | `ts7-source-nostart` |
| 3 | `--version` replaced by `-V` in the run | 9 cases (`ts1-update` to `ts7-source-nostart`, `dx2-source-windows`) |
| 4 | The source flow gives no check | `ts6-source`, `ts7-source-nostart`, `dx2-source-windows` |

Caught 4 of 4. `ToolBuild.roc` and `TalonUpdateFlow.roc` are the same as before the mutations (cmp).

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-075-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, all 3 slices in) | Exit 0, all 7 steps |
| Gap step | Skipped: all code-agent mutations caught (12 of 12 over the 3 slices), no new decision |
| Dispute (`tool/dx2-source-windows`) | Accepted: R-S3 now needs the `--version` check in that 050d case too. |
