# 050c Windows `.del` files: the sweep at each start, the renames of the tools

Phase: P1. Status: done

Slice 050c is the part of R-ST10 that slice 050 left out (050 Q-W1 and Q-W2, the plan row 050c). On Windows a running `.exe` cannot be deleted or overwritten, but it can be renamed. So Talon renames a `.exe` to `<name>.<16hex>.del` before it replaces or deletes it, and each start of `tln` tries to delete the `.del` files of the bin dir and the data bin dir. Slice 050 has the pure parts (`TalonUpdate.is_del`, `stale`, `del_moves`) and the renames of `tool update talon`. Slice 051 has the renames of `tool remove talon` (and its own detached cleanup). This slice adds:

| Part | What | Where |
| --- | --- | --- |
| Sweep | Each start of `tln` on Windows: list the bin dir and the data bin dir, delete the `.del` files. A failed delete is no failure. | `Run.run!` (first call), `DelFlow.sweep!`, `Del.dirs`, `Del.found` |
| Install of a tool | `tool install` of an installed tool, `tool update`, `tool rebuild` (one shared step): the data file and the bin dir entry that exist are renamed to `.del` files before the new files go in | `ToolBuild.install!`, `DelFlow.rename_away!`, `Del.replaced` |
| Remove of a tool | `tool remove`: the entry (when it is Talon's) and the data file are renamed to `.del` files, then deleted. A failed delete leaves the `.del` file for the sweep | `ToolManageFlow.remove_locked!`, `Del.removed` |

Size (TW19): the plan row says 100 lines. The private reference (`research/slice-050c-revert/reference/`, deleted at the review) had 70 lines in `Del` and 47 in `DelFlow` (about 60 code lines without comments and blank lines), 16 changed lines in `ToolBuild`, 14 in `ToolManageFlow`, and the wiring (`Run` 4, `Fx` 6, `RealFx` 7, `fxprobe` 3) that is complete in the stub state. About 100 code lines. No split. No module is over 490 lines.

Live reads: none. No real network. L2 uses the fake `Fx` with the fake machine `os=windows`. There is no Windows machine in L2 or L3: the real Windows rename and the real running `.exe` stay with the Windows CI job (out of scope).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-ST10 (sweep) | "Each start of `tln` tries to delete the `*.del` files in the bin dir and the data bin dir. A delete fails while the file runs, and the next start tries again." On Linux and macOS there is no `.del` file and no sweep | L0 `DelTest` 1, 2. L2 `tool/dl1-sweep` runs 1 to 6, `tool/dl1b-denied` runs 1 to 3, `tool/dl2-tool-windows` run 2, the 5 Windows cases of earlier slices (`ts5-windows`, `ts5b-winfresh`, `rm3-windows`, `rm5-win-path`, `roc/ri1-flow`: the first calls). L3 `tools/dl1-linux-keeps-del`, `fx/wi1-real-fx-windows` |
| R-ST10 (rename before replace) | On Windows, Talon renames a `.exe` before it replaces it: to `<name>.<16hex>.del` in the same dir. Here for the tools (the data file, then the bin dir entry, only files that exist) | L0 `DelTest` 3. L2 `tool/dl2-tool-windows` run 1 |
| R-ST10 (rename before delete) | The same before it deletes it: `tool remove` renames the entry and the data file, then deletes the `.del` files | L0 `DelTest` 4. L2 `tool/dl2-tool-windows` run 2 |
| R-S3, R-T7 | `tool rebuild` and `tool update` replace the files: the new binary is made as before (the `calls.log` is that of `tool/tr1-rebuild` run 1, with the renames and the `random!` added) | L2 `tool/dl2-tool-windows` run 1 |
| R-B6 | `tool remove` deletes the binary and the entry | L2 `tool/dl2-tool-windows` run 2 |
| R-ST8 | `roc` is a start of `tln` (the proxy): the sweep runs before it | L2 `tool/dl1-sweep` run 5 |
| R-ST6, R-ST11 | A bin dir entry that tln did not write (fate `Keep`) is not renamed. An entry that is a dir is not renamed | L0 `DelTest` 3, 4 |

Other rule ids that the tests name (the slice does not own them): R-ST9, R-ST7, R-LY8 (the bin dir of Windows), R-T3 (the data bin dir), R-CC6 (the renames are under the lock of `tools.json`).

Rule check: `MISSING=1 scripts/rules.sh R-ST` shows no id of this slice without a test (R-ST10 has the new tests, see section 11).

## 2. Files

New files (also in `research/slice-050c-revert/before/NEW.txt`). The code agent writes the bodies of the 2 stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/Del.roc` (stub) | 29, 70 | Part A: `dirs`, `found`, `replaced`, `removed`, and the types `Listing` and `Have` |
| `cli/lib/DelFlow.roc` (stub) | 24, 47 | Part C: `sweep!`, `rename_away!`. The calls are in its doc comment |
| `tests/unit/DelTest.roc` | 100 | L0, 4 `expect`s. Imported by the driver `tests/unit/l0-5.roc` |
| `tests/commands/cases/tool/dl1-sweep`, `dl1b-denied`, `dl2-tool-windows`, `dl3-rename-edges` | | L2, 13 runs |
| `tests/scenarios/tools/dl1-linux-keeps-del`, `tests/scenarios/fx/wi1-real-fx-windows` | | L3 |
| `research/slice-050c-revert/` | | `before/`, `stubs/`, `restore.sh` (`stubs`, `before`), `gen-del.py` (writes the given, fx, entry and rules files and the L3 `cmd` files, no `expect/`), `red-run.log`, `reference/` (deleted at the review, 2026-10-25: it had the reference code, `mut.py` and the mutation logs) |

Changed files (a copy of each is in `research/slice-050c-revert/before/`). In the stub state the wiring is complete and `ToolBuild` and `ToolManageFlow` are as before:

| File | Change | State |
| --- | --- | --- |
| `cli/lib/Fx.roc` | New field `windows! : () => Bool`, its wrapper and its doc row | complete (stub state) |
| `cli/RealFx.roc` | The field `windows!` (`Env.platform!` is Windows) | complete |
| `cli/lib/Run.roc` | `run!` calls `DelFlow.sweep!(fx)` first, when `fx.windows!()` | complete |
| `cli/lib/main.roc` | Exposes `Del` and `DelFlow` | complete |
| `cli/fxprobe.roc` | The word `windows` (prints `windows true` or `windows false`) | complete |
| `tests/commands/FakeFx.roc` | The field `windows!`: true when the row of `fx/platform` that the next `platform!` call gets has `os=windows`. It writes no line to `calls.log` | test file, done |
| `cli/lib/ToolBuild.roc` | 050c: `install!` reads `old` and `have` of the entry (no new read) and calls `DelFlow.rename_away!` after the check of the entry and before `write_binary!` | not changed (code agent) |
| `cli/lib/ToolManageFlow.roc` | 050c: `remove_locked!` has the field `os`, and on Windows renames, then deletes the `.del` files | not changed (code agent) |
| `cli/lib/TalonUpdate.roc` | Only a doc comment: the text of `stale` that says the call is not in slice 050 (Q-W1) is old | not changed (code agent) |

Old tests that this slice changed (TW21, the expected files were read, copies in `research/slice-050c-revert/before/tests/commands/cases/`):

| Case | Change |
| --- | --- |
| `tool/ts5-windows` | `calls.log`: each run starts with `env_all` and `list_dirs`. Run 2 also has one `delete` of the 3 `.del` files of run 1. `tree.diff`: the `.del` file of the data bin dir is gone at the end. `rules` text of runs 1 and 2 |
| `tool/ts5b-winfresh`, `tool/rm3-windows`, `tool/rm5-win-path` | `calls.log`: each run starts with `env_all` and one `list_dirs` of the 2 dirs (no `.del` file, so no `delete`). A line at the end of `rules` |
| `roc/ri1-flow` | `calls.log`: the run that has the row `os=windows` of `fx/platform` starts with `env_all` and one `list_dirs` of the data bin dir (the case has no `USERPROFILE`, so no bin dir) |
| `tests/unit/l0-5.roc` | `import DelTest` (the driver with the smallest time after `l0-6`, which got `TalonRemoveTest`) |

Every other L2 and L3 case is unchanged: a start on Linux or macOS has the same `calls.log` (`windows!` is not in it).

## 3. Public signatures

| Function | Type |
| --- | --- |
| `Del.dirs` | `List((Str, Str)) -> List(Str)` (the environment gives the bin dir, then the data bin dir) |
| `Del.found` | `{ dirs : List(Str), listed : List(Del.Listing) } -> List(Str)` |
| `Del.replaced` | `{ data_file : Str, entry : Str, old : Try(Str, [NotFound]), have : Del.Have } -> List(Str)` |
| `Del.removed` | `{ data_file : Str, entry : Str, old : Try(Str, [NotFound]), fate : [Remove, Gone, Keep] } -> List(Str)` |
| `DelFlow.sweep!` | `Fx => {}` |
| `DelFlow.rename_away!` | `Fx, { os : Setup.Os, files : List(Str) } => Try(List(Str), Fail)` (gives the new `.del` paths) |
| `Fx.windows!` | `Fx => Bool` |

`TalonUpdate.is_del`, `stale` and `del_moves` are used as they are (no second copy). `TalonUpdateFlow` is not changed: it keeps its own `moved!`.

## 4. Tests

### L0 (`DelTest`, 4 `expect`s)

| # | Rows | Rules |
| --- | --- | --- |
| 1 | `dirs`: both dirs, a `\` at the end of `USERPROFILE`, `XDG_DATA_HOME` (absolute wins, relative is ignored), no `HOME` with the 3 XDG dirs, only `USERPROFILE`, only `HOME`, empty values, no variable, empty environment | R-ST10, R-LY8 |
| 2 | `found`: 2 dirs with byte order in each dir, a dir with a `.del` name, upper case hex, 15 and 17 hex digits, `plain.del`, `.del.tmp`, a name with dots, an empty name; a dir that is not there, denied, `Other`; no dir | R-ST10 |
| 3 | `replaced`: the 2 results of `old` against the 4 forms of `have` (8 rows) | R-ST10, R-S3, R-ST11 |
| 4 | `removed`: the 3 fates against the 2 results of `old` (6 rows) | R-ST10, R-B6, R-ST6 |

### L2 and L3

| Case | Content |
| --- | --- |
| L2 `tool/dl1-sweep` (6 runs, fake Windows) | The bin dir and the data bin dir have `.del` files, names that are no `.del` file, and a dir with a `.del` name. 1 `--version` with a `USERPROFILE` whose bin dir is not there: the data bin dir is swept. 2 `--version` with an empty `HOME`: only the bin dir is listed. 3 `--version`: both dirs, nothing to delete, no `delete` call. 4 `tool list`. 5 `@roc --version` (the proxy). 6 `no-such-command` (exit 2). Each run starts with `env_all`, `list_dirs`, then the `delete` (if any), then `args`. The tree: only the `.del` files are gone. Stdout and stderr have only what the command prints |
| L2 `tool/dl3-rename-edges` (2 runs, gap step) | The home of `dl2-tool-windows` with 2 tools: `foo` has its files, `bar` has none. `fx/rename` `exists .del`. 1 `tool rebuild bar`: no file exists, so no `.del` rename and no second `random!` (D8). 2 `tool rebuild foo`: the first rename gives `Exists`: exit 18 `cannot move <from> to <to>: Exists`, nothing renamed, the old files and `tools.json` stay, the temp dir is deleted (Q-R1) |
| L2 `tool/dl1b-denied` (3 runs) | `fx/delete` refuses one `.del` file. Run 1: one `delete` of 2 files, one goes, one stays, no text, exit 0. Run 2 and 3 (`--version`, `tool list`): the next start tries again (one `delete` of the file that stays), no text, exit 0, the command runs as usual |
| L2 `tool/dl2-tool-windows` (2 runs, fake Windows) | The home of `tr1-rebuild` with the tool `foo` only, files with `.exe`, the entry and the data file have the same text. 1 `tool rebuild foo`: under the lock, one `random!`, `rename!` of the data file and of the entry to `foo.<hex>.del` (data first), then the new files as before. The 2 `.del` files stay. 2 `tool rm foo`: the sweep deletes the 2 `.del` files, then under the lock `random!`, `rename!` of the entry and of the data file (entry first), one `delete!` of the 2 `.del` files, `tools.json` without `foo`. The tree: `foo.exe` is gone in both dirs |
| L3 `tools/dl1-linux-keeps-del` | The real `tln` on Linux: a `.del` file in the bin dir and in the data bin dir stays after `tln --version` and `tln tool list` (the real `Fx` answers `windows!` false, so no sweep) |
| L3 `fx/wi1-real-fx-windows` | `fxprobe windows`: `windows false` on this machine (TW4: one L3 case for the new `Fx` call). Windows is tested by the fake in L2 |

The 2 L3 cases pass in the stub state, because `Fx` and `Run` are complete there. They guard the Linux side: without the check `fx.windows!()` the first one fails.

## 5. Output (proposed, R-OUT2, TW24)

The sweep prints nothing, never changes an exit code and never writes to stderr (Q-S1). The renames print nothing. The text of `tool rebuild`, `tool update` and `tool remove` is as before. The one new text is the failure of a rename (exit 18, kind `Environment`): `cannot move <from> to <to>: <error>` (the text of `TalonUpdateFlow`). It has no test (Q-R1).

## 6. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The sweep is the first call of `Run.run!`, before `args!` and before the proxy split. So each start of `tln` has it: the help, the version, a parse failure, each command and `roc`. `tln run` inner runs (`Run.tln!`) do not repeat it | `main.roc` (no L2 test, and logic in the app). After the command. Commands only (no help, no proxy) |
| D2 | Windows is found by a new `Fx` call `windows!`, which the fake does not write to `calls.log` (as `program_name!`) | `platform!` (a `platform` line in each Linux `calls.log`, and the rows of `fx/platform` shift). `env_all!` (the same, and no sure variable). The program name (`tln` can run with no `.exe`) |
| D3 | The dirs: the bin dir (`Setup.bin_dir`, `USERPROFILE`), then the data bin dir (`Roots.item` `Bin`). A dir whose variable is missing is left out with no failure | A failure of the command. No sweep when one dir is missing |
| D4 | One `list_dirs!` with both dirs, one `delete!` with all the files. No call when there is no dir, and no `delete!` when there is no file. Each result is ignored | One `delete!` for each file. A text on stderr for a failed delete |
| D5 | Subdirs are not walked, and a dir with a `.del` name stays (only files) | A recursive sweep |
| D6 | `tool install` of an installed tool, `tool update` and `tool rebuild` share `ToolBuild.install!`, so one change gives the renames for the 3 commands. The data file first, then the entry, only the files that exist. The `.del` files stay (the next start deletes them) | A change in 3 flows. A delete right after the replace |
| D7 | The `.del` renames are under the lock of `tools.json`, after the check of the entry, before the copy of the new file | Before the lock |
| D8 | One `random!` for the renames of one command, called only when there is a file to rename. So no Linux, macOS or first install on Windows has a new `random` line | One `random!` for each rename. A `random!` for each install |
| D9 | `tool remove` on Windows: the entry (fate `Remove`), then the data file, are renamed, then one `delete!` of the new `.del` files. A failed delete is no failure. It replaces the old `delete!` of the two paths on Windows. Linux and macOS keep it | No delete (a `.del` file stays until the next start). Both: the rename and the old `delete!` |
| D10 | Read of the entry: `ToolBuild.install!` gets `old` and `have` from the reads that it makes already (`entry_state!`), so no new `sha256_file!` or `list_dirs!` | A second read |

## 7. Out of scope

| Rule | What | Reason |
| --- | --- | --- |
| R-ST10 (real Windows) | A real rename of a running `.exe`, a real failed delete | There is no Windows machine in L2 or L3. L2 fixes the order of the calls. The Windows CI job runs `check fmt l0` only |
| R-ST10 (other places) | `tln setup` that makes an entry `tln.exe`, `roc.exe` or a tool entry again (R-ST9), the take-over of an `x` entry (`XTake`, R-B4), `tool install --as`, and any other replace of a `.exe` | R-ST10 is general, so the design fixes it, but the plan row 050c names `tool update`, `tool rebuild` and `tool rm`. Follow-up row 050d in `PLAN-P1.md` (manager, review 2026-10-25) |
| R-RM5, R-IS5 | The detached cleanup of `tool remove talon` (slice 051) and the rename of the install script (slice 052) | Other slices. A `.del` file that they leave is swept by the next start of a `tln` that is installed again |
| `TalonUpdateFlow` | One shared `moved!` | Not needed: it keeps its behavior |

## 8. Design gaps

The manager review (2026-10-25) accepted all of these as design gaps. The tests pin the default. There is no open question.

| Id | Gap | Pinned default | Rejected |
| --- | --- | --- | --- |
| Q-S1 | R-ST10 says a delete fails and the next start tries again. It does not say what the command prints or does when the sweep fails (no delete, no dir, a dir that cannot be listed) | Nothing: no text, no exit code, no stop | A warning on stderr. A `--verbose` line |
| Q-D1 | R-ST10 says "each start of `tln`". Is the `roc` proxy (R-ST8) a start? Are `--help` and `--version` starts? | Yes for all (D1) | Only the commands. Only `tln`, not `roc` |
| Q-D2 | Other places replace a `.exe`: `tln setup` (R-ST9), the take-over of an `x` entry (R-B4), `tool install --as`. The design fixes this (R-ST10 is general), but the slice does not do it | Not changed here. Follow-up row 050d in `PLAN-P1.md` | The same helper in each place |
| Q-D3 | R-LY5 to R-LY7 give `%LOCALAPPDATA%` and `%APPDATA%` for the roots of Windows. `Roots.from_env` reads `HOME` and `XDG_*` only, so on a real Windows with no `HOME` the sweep lists only the bin dir. Not new in this slice. Recorded in `PLAN-P1.md` 5b | `Roots.from_env` as it is | A Windows form of `Roots` here |
| Q-R1 | A `rename!` that fails (not `NotFound`) in `rename_away!`: exit 18 `cannot move <from> to <to>: <error>`, no rollback of the files renamed before it (as slice 051 G9). Tested for the first rename (`tool/dl3-rename-edges` run 2); the rollback is not | The code of `TalonUpdateFlow` | A rollback. A skip |
| Q-R2 | `tool remove` on Windows: `.del` files that cannot be deleted at once stay until the next start, with no text. Not tested | No text | A warning with the paths |

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| `Fx.windows!` must not show in `calls.log` (Linux `calls.log` files stay) | The fake reads `fx/platform` with no log line. The row is the one that the next `platform!` would get, so a case with one row for each run gives each run its system |
| The L2 fake keeps a bin dir of Windows as a dir with `\` in its name (`home/u\.local\bin`) | The cases put `USERPROFILE` under `home/`, so the tree diff shows the bin dir (the older Windows cases have it outside `home/` and the diff does not show it) |
| `Str` joins of the sweep paths use `/` (`TalonUpdate.stale`) | As in slice 050: the paths of `calls.log` are `<dir>/<name>` |
| A literal `Bool.False` as an `if` input is a warning | Not used |

## 10. Notes for the code agent

| Note | Text |
| --- | --- |
| 1 | The docs of the stubs say what each function does. The tests give the values. The reference was deleted: write the code from the docs and the tests |
| 2 | `Del`: `dirs` uses `Setup.bin_dir` with the os `Windows` and `Roots.from_env` and `Roots.item(roots, Item.Bin)`. `found` uses `TalonUpdate.stale` for each dir that was listed. Do not write `is_del` again |
| 3 | `DelFlow.sweep!`: the calls of its doc table. `DelFlow.rename_away!`: no call when the os is not Windows or there is no file. Else `random!`, `Temp.hex`, `TalonUpdate.del_moves`, one `rename!` each |
| 4 | `ToolBuild.install!`: the same reads as now (the `calls.log` of every tool case on Linux must not change). Give `old` and `have` of the entry to `Del.replaced`. Call `rename_away!` after the check of the entry and before `write_binary!` |
| 5 | `ToolManageFlow.remove_locked!`: Linux and macOS keep the `delete!` of `gone` and its failure. Windows: `rename_away!` with `Del.removed`, then one `delete!` of the new paths (no call for no path), results ignored. The os comes from `removal!` (`machine.os`) |
| 6 | `Run`, `Fx`, `RealFx`, `fxprobe`, `main.roc` are done. Do not change a test (TW18). Change the old text of `TalonUpdate.stale` (a doc comment: it says the call of the sweep is not in slice 050, question Q-W1). The manager updates the rows of slice 050 and `PLAN-P1.md` at the close |

## 11. Red run, revert check

Red run with the stubs (`research/slice-050c-revert/red-run.log`): `scripts/test.sh`.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest, l1 | pass | the stubs compile with no warning |
| l0 | 4 failed | `DelTest` 1 to 4: `ROC CRASHED todo: slice 050c`. 73 other `expect`s of `l0-5` pass |
| l2 | 8 failed, 154 passed | `tool/dl1-sweep`, `dl1b-denied`, `dl2-tool-windows` and the 5 old Windows cases that start with the sweep (`ts5-windows`, `ts5b-winfresh`, `rm3-windows`, `rm5-win-path`, `roc/ri1-flow`): `ROC CRASHED todo: slice 050c` (the sweep). All Linux cases pass |
| l3 | pass | The 2 new cases test the Linux side of the wiring (see section 4) |

Green run with the reference (`green-run.log`): `scripts/test.sh` exits 0 (check 1.7, fmt 0.3, l0 7.7, l2 8.5, l3 10.0, selftest 2.9, l1 34.7 s).

Revert check (`reference/mut.py`, 10 hand mutations of the most tricky behaviors, the reference is put back after each one; each ran L0 (all), L2 `tool/` and `roc/ri1`, L3 `tools/dl1` and `fx/wi1`; the logs are `reference/mut-*.log`). Every mutation is killed by at least one layer.

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| m1 the sweep runs on every system (no `windows!` check in `Run`) | survived (wiring) | killed (every Linux case gets the sweep lines) | killed |
| m2 `dirs` gives the data bin dir first | killed | killed | survived (Windows is L2 only) |
| m3 `dirs` gives no dir when one variable is missing | killed | killed (`dl1-sweep` runs 1, 2) | survived |
| m4 a failed delete of the sweep is printed on stderr | survived (flow) | killed (`dl1b-denied`) | survived |
| m5 `found` takes a dir with a `.del` name | killed | killed (`dl1-sweep`) | survived |
| m6 `replaced` also renames an entry that is not there | killed | survived (no Windows first install of a tool in L2, Q-D2 note) | survived |
| m7 `rename_away!` calls `random!` also for no file (all systems) | survived (flow) | killed (the Linux tool cases get a `random` line) | survived |
| m8 `replaced` gives the entry before the data file | killed | killed (`dl2-tool-windows` run 1) | survived |
| m9 `removed` gives the data file before the entry | killed | killed (`dl2-tool-windows` run 2) | survived |
| m10 `tool remove` renames but does not delete the `.del` files | survived (flow) | killed (`dl2-tool-windows` run 2) | survived |

m6 is caught only by L0: a tool that is new on Windows has no L2 case (a `tool install` flow with the whole build is a large case for one row). The rule is the 8 rows of `DelTest` 3.

## Review (manager, 2026-10-25)

Accepted as built: D1 to D10 and the TW21 changes of the old Windows cases (`ts5-windows`, `ts5b-winfresh`, `rm3-windows`, `rm5-win-path`, `roc/ri1-flow`). Q-S1, Q-D1, Q-D3, Q-R1, Q-R2 accepted with the pinned defaults, all as design gaps (section 8). Q-D2 is not in this slice: follow-up row 050d in `PLAN-P1.md` (Out of scope). No test changed in the review, so no new mutation. The private reference was deleted. Status: `code`.

## Verify results (code agent)

Result of `scripts/test.sh` (exit 0): check pass 1.6 s, fmt pass 0.2 s, l0 pass 7.6 s (`l0-5`: 77 `expect`s, `DelTest` 4 of them), l2 pass 9.1 s (162 cases passed, 0 failed: `tool/dl1-sweep`, `dl1b-denied`, `dl2-tool-windows` and the 5 old Windows cases), l3 pass 10.0 s (83 passed, 1 skipped), selftest pass 2.9 s, l1 pass 34.3 s.

Code files: `research/slice-050c-revert/code-final/` and `code-final.sha256` (`sha256sum -c` from the repo root).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Del.roc` | 63 | the 4 bodies |
| `cli/lib/DelFlow.roc` | 48 | `sweep!`, `rename_away!` |
| `cli/lib/ToolBuild.roc` | 255 | new `entry_read!` (the reads of `entry_state!`, with `old` and `have`; `entry_state!` calls it), `install!` checks the verdict and calls `rename_away!` before `write_binary!` |
| `cli/lib/ToolManageFlow.roc` | 211 | `remove_locked!`: field `os`, Windows path with `rename_away!` and one `delete!` of the `.del` files; doc row 6 |
| `cli/lib/TalonUpdate.roc` | 335 | doc comment of `stale` only |

Decisions that the slice does not fix: `entry_verdict!` and `entry_state!` keep their signatures (XTake, ToolGitFlow, ToolFlow, ToolUpdateFlow use them); the new `entry_read!` is public in `ToolBuild` (rejected: a second read, a change of the type of `entry_state!`). `Del.dirs` uses `Setup.bin_dir` with `Windows` and `Roots.from_env` and drops each `Err` (no failure). No test, fixture or expected file was changed (no dispute rows).

Revert check (filtered runs: L0 all, or `tests/commands/run.sh` with the given filter; the code was put back after each one, and `diff` with a copy made before the mutations shows no change). Caught 7 of 8.

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | `Del.dirs` gives the data bin dir first | L0 `l0-5` (`DelTest` 1) |
| 2 | `rename_away!` calls `random!` also for an empty file list on Windows (check `files.is_empty()` removed) | not caught (`tool/` all 33 cases pass: no Windows first install of a tool in L2, as m6 of the test agent; the rule is in the doc of `rename_away!` only) |
| 3 | `remove_locked!` on Windows does not delete the `.del` files | L2 `tool/dl2-tool-windows` |
| 4 | `Del.replaced` gives the entry before the data file | L2 `tool/dl2-tool-windows` |
| 5 | `sweep!` deletes only when there is more than one file | L2 `tool/dl1b-denied` |
| 6 | `rename_away!` does not check the os (all systems rename) | L2 `tool/tr1-rebuild` |
| 7 | `remove_locked!` keeps the old `delete!` also on Windows | L2 `tool/dl2-tool-windows` |
| 8 | `install!` ignores a `Foreign` verdict | L2 `tool/ti2-refusals` |

Questions (TW17): none. Compiler limits met: a `match` result that is a list needs `_ =` as a statement (the warning fails the build).

## Gap tests (test agent, 2026-10-25)

Input: the code is in (status verify), `code-final.sha256`. No code changed: after each hand mutation the file was put back, and `sha256sum -c research/slice-050c-revert/code-final.sha256` gave OK for all files. One new L2 case, 2 runs, `tests/commands/cases/tool/dl3-rename-edges` (generator `research/slice-050c-revert/gen-del.py`, which writes no `expect/`; TW21: only the `expect/` of this case was written with `UPDATE=1 tests/commands/run.sh tool/dl3` and read). No old expected file changed.

| Item | Result |
| --- | --- |
| Code miss m2: `rename_away!` calls `random!` also for an empty list (a Windows first install) | Cheap row found: a manifest entry whose files are gone (`bar`) is the same state for `install!` (`old` is `NotFound`, `have` is `Absent`, so the list is empty). `dl3-rename-edges` run 1 (`tool rebuild bar`) has no `random` between the check of the entry and `make_dirs`. Hand mutation: `rename_away!` checks only the os, not `files.is_empty()`: run 1 fails (an extra `random` line). A real `tool install` of a new tool on Windows is the same code path, so no large case is needed |
| `install!` has `_ = rename_away!(...)?` | The `?` is there: only the `Ok` value (the new paths) is dropped, an `Err` returns from `install!`, so the lock body, `finish!` and the command fail with the `Fail` (kind `Environment`, exit 18). This agrees with Q-R1. Row: `dl3-rename-edges` run 2 (`fx/rename` `exists .del`): exit 18 `cannot move ... foo.0123456789abcdef.del: Exists`, no rename, `tools.json` not written, temp dir deleted. Hand mutation: the `?` removed: run 2 fails (the rebuild goes on and exits 0) |

Totals: L2 has 4 cases of slice 050c (13 runs). L0 and L3 are as before.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-050c-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.7, fmt 0.2, l0 7.3, l2 9.2, l3 10.0, selftest 2.9, l1 37.1 s |
| Code pass | 7 of 8 mutations caught; the miss (m2) is now caught by a gap row |
| Gap tests | L2 `tool/dl3-rename-edges`: no `random!` with no file to rename; a refused first rename is exit 18 and nothing changes; 2 hand mutations caught; no code bug |
| Design gaps | Section 8 (Q-S1, Q-D1, Q-D2, Q-D3, Q-R1, Q-R2), recorded in PLAN-P1 5b; Q-D2 is slice 050d |
