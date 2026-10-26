# 050d Windows `.del` files in the other places

Phase: P1. Status: done

Slice 050d is the part of R-ST10 that slice 050c left out (050c Q-D2, plan row 050d). On Windows a running `.exe` cannot be deleted or overwritten, but it can be renamed. So Talon renames a `.exe` to `<name>.<16hex>.del` before it replaces or deletes it. Slice 050c has the sweep at each start and the renames of `tool install`, `tool update`, `tool rebuild` and `tool rm`. This slice finds the other places in `cli/`, and covers the ones that are left with `DelFlow.rename_away!` and `Del` (one copy, no new helper).

Live reads: none. No real network. L2 uses the fake `Fx` with the fake machine `os=windows arch=x64`. No Windows machine is in L2 or L3: the real rename of a running `.exe` stays with the Windows CI job (out of scope, as 050c).

## 1. The places that replace or delete a file in the bin dir or the data bin dir

The list is made from `rename!`, `delete!`, `copy_file!`, `hard_link!`, `write_atomic!` and `copy_tree!` in `cli/lib/*.roc`. "Bin dirs" says if the file is in the bin dir or the data bin dir (the 2 dirs that the sweep of 050c lists).

| # | Place | What it does to a file | Bin dirs | `.del` today | Here |
| --- | --- | --- | --- | --- | --- |
| 1 | `ToolBuild.install!` with `write_binary!`, `link_entry!` (`tool install` of a new or installed tool, also `--as`, a git tool, `tool update`, `tool rebuild`, and the entry `tln` and the file `tln` of `tool update talon --from-source`) | the data file and the entry: rename over the old file | yes | 050c (`DelFlow.rename_away!`, `Del.replaced`) | no change |
| 2 | `ToolManageFlow.remove_locked!` (`tool remove <tool>`) | delete of the entry and the data file | yes | 050c (`Del.removed`) | no change |
| 3 | `TalonUpdateFlow.installed!` (`tool update talon`, prebuilt) | the data file and the entries `tln` and `roc`: rename over | yes | slice 050 (`TalonUpdate.del_moves`, its own `moved!`) | no change |
| 4 | `TalonRemoveFlow.windows_last!` (`tool remove talon`, Talon last) | rename of `roc.exe`, `tln.exe`, the data file, then the detached delete | yes | slice 051 (`TalonUpdate.del_moves`, R-RM5) | no change |
| 5 | `XTake.taken!` with `place!` and `ToolBuild.link_entry!` (the take-over of an `x` entry, R-B4) | the data file and the entry of an installed tool of the same name: rename over | yes | none | 050d, part A |
| 6 | `TalonUpdateFlow.installed_from!` (`tool update talon --from-source`): the entry `roc` again with `ToolBuild.link_entry!` | the entry `roc.exe`: rename over | yes | none (the entry `tln` and the file `tln` are place 1) | 050d, part B |
| 7 | `TalonRemoveFlow.update_tools!` (`tool remove talon --remove-tools`, option 2) | `delete!` of the entry and the data file of each tool | yes | none | 050d, part C |
| 8 | `SetupFlow.make_entry!` (`tln setup`, R-ST9) | a new entry: `hard_link!` or `copy_file!` to a temp name, `rename!` to the entry. `Setup.judge` gives `Make` only for an entry that is not there (`Absent`). An entry with another content is `Foreign` and is kept (R-ST6) | yes | not needed | no change (section 8, Q-S1) |
| 9 | `SetupFlow.move_roc!` (`--replace-roc`) | `rename!` of a foreign `roc` to `roc.old`. `roc.old` must not exist (exit 17) | yes | a rename, not a replace or a delete | no change |
| 10 | `SetupIo.dropped!`, the `delete!` of a temp name `<file>.<hex>.tmp` after a failed step | a temp file that no process runs | yes | not needed | no change |
| 11 | `XCacheIo.write!`, `XCacheIo.entries!`, `XTake.taken!` (`delete!` of the entry dir after `Move` or after a copy), `XFlow`, `ToolsStep` | files in `talon/x/` | no (cache) | none | no change (Q-X1) |
| 12 | `RocInstall`, `GitInstall`, `Toolchain`, `RocLink`, `Trash.move!`, `CacheGc`, `CacheClean`, `Fetch`, `ProbeBundle`, `Ladder`, `PatchApply`, `PatchFlow`, `Known`, `Github` | dirs and files in the cache (`toolchains/`, `packages/`, `talon/`) or in the project | no | none | no change: the sweep never lists the cache, so a `.del` file there would stay for ever |

`tool install --as` is place 1 (the entry name comes from `facts.file`), so Q-D2 of 050c is closed for it.

## 2. Parts

| Part | Place | Change (command code, the code agent writes it) |
| --- | --- | --- |
| A | `XTake.taken!` | The second `ToolBuild.entry_verdict!` becomes `ToolBuild.entry_read!` with the same check of the verdict (the same `Fx` calls, so no Linux or macOS `calls.log` changes). After the check of the binary and the read of `projects.json` (`ToolsHeld.all!`), before `place!`: `DelFlow.rename_away!(fx, { os, files: Del.replaced({ data_file, entry, old, have }) })?` with `old` and `have` of the read |
| B | `TalonUpdateFlow.installed_from!` | The caller gives the verdict of the entry `roc` that `states!` read (`first.roc_have`). Before `ToolBuild.link_entry!` of `roc`: `DelFlow.rename_away!` with `Del.replaced` (`old` is `Err(NotFound)`: the data file was done by `install!`, `have` is the entry `roc`) |
| C | `TalonRemoveFlow.update_tools!`, `windows!`, `windows_last!` | The tool rows of `Check` get the field `old` (the sha256 read of the data file, already read in `checks!`). Option 2 on Windows, in the lock of `tools.json`: one `DelFlow.rename_away!` with the `Del.removed` files of all tools (the entry first, then the data file, for each tool in the order of `tools.json`), then `delete!` of `tools.json` only. The renamed paths go to `windows_last!`, and they are the first files of the one detached cleanup (the files of Talon follow). Option 2 on Linux and macOS: as before |

Size (TW19): the private reference differs from the old code in 9 lines of `XTake`, 14 of `TalonUpdateFlow` and 51 of `TalonRemoveFlow` (old and new lines, so about 45 new code lines; the plan row says 80). No split. No module is over 490 lines (`TalonRemoveFlow` 403 before, 414 after). The slice adds no `Fx` call, no signature of a public function and no pure function: `Del.replaced` and `Del.removed` of 050c decide (their L0 rows 3 and 4 hold), so there is no stub and no new L0 `expect`.

## 3. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-ST10 (rename before replace, other places) | The take-over of an `x` entry (part A) and the entry `roc` of `tool update talon --from-source` (part B) rename the file that exists to `<name>.<hex>.del` first. Only a file that exists: no rename and no `random!` for a first install or for an absent entry | L2 `tool/dx1-xtake-windows` runs 1 to 3, `tool/dx2-source-windows` runs 1, 2 |
| R-ST10 (rename before delete, other places) | `tool remove talon --remove-tools` renames the files of the tools, then the detached cleanup of R-RM5 deletes them (tools first, then Talon) | L2 `tool/rm6-tools-windows` run 1, `tool/rm3-windows` run 1, `tool/rm5-win-path` run 2 |
| R-ST9 | The entry is made again after the file is replaced: the entry `roc` of the source update, the entry of a take-over | L2 `tool/dx1-xtake-windows` run 3, `tool/dx2-source-windows` runs 1, 2 |
| R-B4 | The take-over moves the binary of the `x` entry to the data bin dir, makes the entry and removes the cache entry. The old data file and entry of the same tool go to `.del` first | L2 `tool/dx1-xtake-windows` runs 1 to 3 |
| R-ST6, R-ST11 | An entry that Talon did not write (`bar.exe`) is not renamed, only its data file is. A tool with no file is not renamed | L2 `tool/rm6-tools-windows` run 1 |
| R-RM5, R-RM8 | The cleanup has all the `.del` files, the tools first. Option 2 stops at the first failed rename (exit 18, `tools.json` stays) | L2 `tool/rm6-tools-windows` runs 1, 2 |
| R-T3, R-ST7, R-CC6, R-S2, R-T22 | Used as before (lock of `tools.json`, data bin dir, hard link) | the same cases |

Other rule ids that the tests name (the slice does not own them): R-T27 (`replaced qux 1.0.0 with 2.0.0`). A failed rename is exit 18 of kind `Environment` (as 050c Q-R1).

Rule check: `MISSING=1 scripts/rules.sh R-ST R-B` lists no id. R-ST10, R-ST9 and R-B4 have the new tests.

## 4. Tests

| Layer | Case | Content | Rules |
| --- | --- | --- | --- |
| L0 | none | The decisions are `Del.replaced` and `Del.removed` (DelTest 3 and 4 of 050c: the 8 and the 6 rows). No new pure function | R-ST10 |
| L2 | `tool/dx1-xtake-windows` (3 runs, fake Windows) | Home with `qux` 1.0.0 and `zed` 1.0.0 installed (data file and entry, same text), `x` entries of foo 1.1.0, qux 2.0.0, zed 2.0.0, `fx/rename` `exists bin/zed.0123456789abcdef.del`. 1 `tool install acme/foo`: nothing to rename, no second `random!`, the calls of `tk1-takeover` run 1 with `.exe`. 2 `tool install acme/zed@2.0.0`: the first rename gives `Exists`: exit 18 `cannot move <data file> to <.del>: Exists`, nothing is renamed, nothing changes (the entry dir and `tools.json` stay). 3 `tool install acme/qux@2.0.0`: the sweep deletes nothing, then under the lock one `random!`, `rename!` of the data file, then of the entry, to `qux.<hex>.del`, then the move, the entry, `tools.json`, the delete of the entry dir. The 2 `.del` files stay in the tree | R-ST10, R-B4, R-ST9, R-CC6, R-T27 |
| L2 | `tool/dx2-source-windows` (2 runs, fake Windows, 2 homes) | `tool update talon --from-source` (calls of `ts6-source` run 1). Home u1 has the entry `roc.exe`: after the install of `tln.exe` (050c renames) there are one more `random!` and a `rename!` of `roc.exe` to `roc.<hex>.del`, then the hard link and the rename over. Home u2 has no `roc.exe`: no rename and no second `random!`, the entry is made | R-ST10, R-ST9, R-S2 |
| L2 | `tool/rm6-tools-windows` (2 runs, fake Windows, 2 homes) | `tool rm talon --remove-tools`, 4 tools: `foo` (Talon's entry), `bar` (an entry of the user), `baz` (no entry), `qux` (no file). Run 1: `random!`, `rename!` of foo entry, foo data, bar data, baz data (not qux), `delete!` of `tools.json` only, the user `Path`, the data, one more `random!`, the 3 renames of Talon, one `spawn_detached` with 7 `TALON_DEL_n` (tools first). The warning for the entry of `bar`. Run 2: the rename of the entry `foo.exe` gives `Exists`: exit 18, nothing is renamed or deleted, no `Path` change, no cleanup | R-ST10, R-RM5, R-RM8, R-ST6, R-ST11 |
| L2 old | `tool/rm3-windows` run 1, `tool/rm5-win-path` run 2 | Changed (TW21): the 2 renames of `foo.exe` and the `tools.json` delete alone (`calls.log`), 5 `.del` files in the cleanup (rm3), the 2 `.del` files in the tree (`tree.diff`), the `rules` text | R-ST10, R-RM5 |
| L2 old | every other case | Not changed: the Linux and macOS cases have the same `calls.log` (`rename_away!` has no call when the os is not Windows, and `entry_read!` makes the calls of `entry_verdict!`). `tool/tk1-takeover`, `tool/ts6-source`, `tool/rm1-default`, `tool/rm2-options` guard this | |

The 3 new cases were generated by a private script (`gen-dx.py`, deleted at the review with the reference). Their `given/`, `fx/`, `entry` and `rules` files are plain files in the case dirs.

Files (also in `research/slice-050d-revert/before/NEW.txt`):

| File | Lines | State |
| --- | --- | --- |
| `docs/slices/050d-windows-del-other.md` | this file | |
| `tests/commands/cases/tool/dx1-xtake-windows` | 36 files (`calls.log` 98 lines) | new |
| `tests/commands/cases/tool/dx2-source-windows` | 27 files (`calls.log` 139 lines) | new |
| `tests/commands/cases/tool/rm6-tools-windows` | 29 files (`calls.log` 74 lines) | new |
| `tests/commands/cases/tool/rm3-windows`, `rm5-win-path` | `expect/calls.log`, `expect/tree.diff`, `rules` | changed (copies in `research/slice-050d-revert/before/tests/commands/cases/tool/`, with no `given/`) |
| `research/slice-050d-revert/` | | `before/` (3 code files, 2 old cases, `NEW.txt`), `restore.sh` (`reference`, `before`), `red-run.log`, `green-run.log`, `reference/` (the 3 code files of the reference, `gen-dx.py`, `mut.py`, `mut-m*.log`: deleted at the review, 2026-10-25) |

No code file of `cli/` is changed in the stub state (there is no stub). The 3 code files are the same as in `before/`.

## 5. Output (proposed, R-OUT2, TW24)

No new text. The sweep, the renames and the cleanup print nothing. A failed rename is the failure of 050c (`DelFlow.rename_away!`): exit 18, kind `Environment`, `cannot move <from> to <to>: <error>`. Tested for the first rename in `dx1-xtake-windows` run 2 and `rm6-tools-windows` run 2.

## 6. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | Part A renames after the check of the binary (R-B4 check before the move) and the read of `projects.json`, and before `place!`. Same order as 050c D7 (under the lock, after the check of the entry, before the new file). One `random!` only when there is a file to rename (050c D8) | A rename before the lock. A rename after `place!` (it would rename the new file) |
| D2 | `take!` of `XTake` reuses `ToolBuild.entry_read!` of 050c in place of the second `entry_verdict!`: the same calls, so no new read | A second read |
| D3 | Part B uses `Del.replaced` with `old` `Err(NotFound)` and the verdict of `states!` (read before the build, as `made` already is). No new pure function | A new function in `Del`. A new read under the lock (it would change the Linux `calls.log`) |
| D4 | Part C: on Windows the tool files are renamed in the lock of `tools.json` and not deleted at once. All the `.del` files go to the one detached cleanup of R-RM5, the tools first. Why: no later `tln` start deletes a `.del` file after Talon is removed (R-RM5), so a `delete!` that fails would leave the file for ever | A `delete!` of the `.del` files at once, with the failures ignored (050c D9 for one tool: here nothing sweeps later). Both |
| D5 | Part C: the rename of the tools is one `rename_away!` call (one `random!`) for all tools. The files of Talon in step 12 get their own `random!` (the code of 051 is not changed) | One `random!` for each tool. One shared hex for step 9 and step 12 |
| D6 | Part C: `tools.json` is deleted with its own `delete_all!` call after the renames (the manifest last, 051 D12). A failure of a rename stops before it | The manifest in the same `delete!` as the `.del` files |
| D7 | The tool rows of `Check` get the field `old` (no new read: `checks!` has the sha256 already) so `Del.removed` skips a data file that is not there | A rename of a path that is not there with `NotFound` ignored |

## 7. Out of scope

| Rule | What | Reason |
| --- | --- | --- |
| R-ST10 (real Windows) | A real rename of a running `.exe`, a real failed delete | No Windows machine in L2 or L3 (as 050c) |
| R-ST9, R-ST10 (setup) | `tln setup` that makes an entry again | Place 8: `Setup.judge` gives `Make` only for an entry that is not there, and a stale entry is `Foreign`. So setup never replaces a file and has no rename to make. If U1 (027 Q7, `PLAN-P1.md` 6) is settled so that setup replaces a differing entry, the one call `DelFlow.rename_away!` goes before `make_entry!` (a follow-up slice). Question Q-S1 |
| R-ST10 (x cache) | A `.del` file in `talon/x/`, `toolchains/`, `packages/` | The sweep lists only the bin dir and the data bin dir (R-ST10). Question Q-X1 |
| R-B4 (running `.exe`) | The `delete!` of the entry dir after a take-over that fell back to a copy because the `rename` of a running `.exe` failed | Q-X1 |

## 8. Design gaps and questions

| Id | Gap | Pinned default | Rejected |
| --- | --- | --- | --- |
| Q-S1 | R-ST9 and R-ST10 name `tln setup` as a place that replaces the entries. By R-ST11 a stale entry (the content of an older data file) is not Talon's, so `Setup.judge` makes no replace (027 Q7, U1 open with the user) | No change in setup. The place is a follow-up when U1 is settled | A `.del` rename for a `Foreign` entry (it would replace a file of a user) |
| Q-X1 | R-B4 (copy when the `rename` of a running `.exe` fails, then delete the cache entry) deletes a running `.exe` in `talon/x/<digest>/`. R-ST10 renames "in the same dir", but the sweep never lists `talon/x/`. A failed delete is ignored (`_ =`) and the entry waits for GC | No change: the delete result is ignored, as in 049 | A `.del` rename in the cache dir (nothing deletes it). A sweep of `talon/x/` at each start |
| Q-T1 | R-RM5 names the `.exe` of Talon only. R-RM8 removes the tool files with no word on Windows | D4: the tool files are renamed and go to the one cleanup | See D4 |
| Q-R1 | A rename that fails after an earlier rename: no rollback (050c Q-R1). In option 2 the compilers are removed before the tools (051 D1), so a refused rename of a tool file leaves the compilers deleted and Talon installed | No rollback. The command can run again (Talon is last) | A rollback of the renames. A check of all renames before the first change |
| Q-B1 | Part B reads the entry `roc` before the build and not again under the lock (as `TalonUpdate.entries` does today). An entry that goes during the build gives `NotFound` for the rename: exit 18 | As it is | A second read under the lock (it changes the calls of Linux) |

No question stops a part of the slice: each gap has a pinned default that the tests fix. The manager accepted all of them at the review (2026-10-25) as design gaps.

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| A rename of a missing file in the fake gives `NotFound`, and `DelFlow.rename_away!` fails for any error | The tests give `Del` only the files that exist (`old`, `have`). `dx2` run 2 and `rm6` `qux` pin it |
| `fx/rename` and `fx/delete` are one table for the whole case, not for each run | The refused rename has a suffix that only one run has (`bin/zed...` in `dx1`, `u2\.local\bin/foo...` in `rm6`) |
| The fake keeps the bin dir of Windows as a dir with `\` in its name (`home/u\.local\bin`) | The cases put `USERPROFILE` under `home/`, so the tree diff shows the bin dir (as 050c) |
| An `x` entry of Windows has the binary `<repo name>.exe`, the digest has the target `x64win` | The generator writes both. The digest is the one of `XCache.digest` |
| An unused parameter is a warning that fails a build | The mutation `m5` keeps the parameter used |

## 10. Notes for the code agent

| Note | Text |
| --- | --- |
| 1 | There is no stub. The 3 bodies change as section 2 says. Write them from this file and the tests. `DelFlow`, `Del`, `ToolBuild` are not changed. Do not write a second copy of `rename_away!` |
| 2 | `XTake.taken!`: the new rename is after the sha256 check of the binary and the `ToolsHeld.all!` read, before `place!`. Update the doc table of `XTake` (rows 1 and 3) |
| 3 | `TalonUpdateFlow`: only the from-source path. `prebuilt!` has its own renames (050): do not change it. Update the doc row 4g |
| 4 | `TalonRemoveFlow`: `update_tools!` gives the renamed paths, `windows!` and `windows_last!` take them (they start the `$renamed` list). Update the doc rows 9 and 12 and the type `Check` |
| 5 | The `calls.log` of every Linux and macOS case must not change. `scripts/test.sh` must exit 0 |

## 11. Red run, revert check

Red run with the code as before (`research/slice-050d-revert/red-run.log`): `scripts/test.sh`.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, l0, l3, selftest, l1 | pass | no Roc file is changed |
| l2 | 5 failed, 161 passed | `tool/dx1-xtake-windows` (run 2 succeeds, no rename), `tool/dx2-source-windows`, `tool/rm3-windows`, `tool/rm5-win-path`, `tool/rm6-tools-windows`: a wrong value (the `calls.log` has no `.del` rename). No crash. All Linux cases pass |

Green run with the private reference (`green-run.log`): `scripts/test.sh` exits 0 (check 1.9, fmt 0.3, l0 7.5, l2 8.5, l3 10.0, selftest 3.0, l1 36.4 s).

Revert check (`reference/mut.py`, 8 hand mutations of the most tricky behaviors; the reference is put back after each; each ran L2 `tool/dx`, `tool/rm`, `tool/tk`, `tool/ts6`, `tool/dl`). Every mutation is killed.

| Mutation | Killed by |
| --- | --- |
| m1 `XTake` has no `.del` rename | `dx1` |
| m2 `XTake` ignores a failed rename (the `?` is gone) | `dx1` run 2 |
| m3 `XTake` renames after the move of the new file | `dx1` run 3 |
| m4 from-source renames `roc.exe` also when it is not there | `dx2` run 2 |
| m5 the tool `.del` files are not in the cleanup | `rm3`, `rm6` |
| m6 a tool whose data file is gone is renamed | `rm6` (`qux`) |
| m7 `tools.json` is deleted before the renames | `rm3`, `rm5`, `rm6` |
| m8 the Windows branch of option 2 runs on every system | `rm2-options` (Linux tool files stay) |

## Review (manager, 2026-10-25)

Accepted as built: D1 to D7. Q-S1, Q-X1, Q-T1, Q-R1, Q-B1 accepted with the pinned defaults, all as design gaps (section 8 is the one table). Q-S1 waits for U1 (027 Q7). No test changed in the review, so no new mutation. The private reference (`research/slice-050d-revert/reference/`) was deleted. Status: `code`.

## Verify results (code agent)

`scripts/test.sh` exits 0 (check 1.8, fmt 0.3, l0 7.4, l2 9.6 with 166 passed, l3 10.0 with 83 passed and 1 skipped, selftest 2.9, l1 35.5 s). No test, fixture or expected file changed (no dispute rows). Code: `XTake` 173 lines, `TalonUpdateFlow` 367, `TalonRemoveFlow` 421. Final code and `sha256` in `research/slice-050d-revert/code-final/` and `code-final.sha256`.

Choices that the slice does not fix: part B passes `{ make, roc_have }` to `installed_from!` (a record in place of the `make` list; the function is private). Part C: `update_tools!` gives `Try(List(Str), Fail)` (the `.del` paths), and the new private function `tools_removed!` has the 2 branches of option 2 (Windows rename, other systems delete). `windows!` and `windows_last!` take the renamed paths as one more parameter (private).

Revert check (7 mutations, filtered L2 runs, code put back and compared with `cmp`): caught 7 of 7.

| Mutation | Killed by |
| --- | --- |
| m1 `XTake` ignores a failed rename (the `?` is gone) | `dx1` |
| m2 `XTake` renames after `place!` | `dx1` |
| m3 from-source renames `roc.exe` also when it is absent | `dx2` |
| m4 the Windows branch of option 2 runs on every system | `rm2-options` |
| m5 `tools.json` is deleted before the renames | `rm3-windows`, `rm5-win-path`, `rm6-tools-windows` |
| m6 a tool with no data file is renamed | `rm6-tools-windows` |
| m7 the tool `.del` files are not in the cleanup | `rm3-windows`, `rm6-tools-windows` |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-050d-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.6, fmt 0.2, l0 7.6, l2 9.7, l3 10.0, selftest 2.9, l1 36.3 s |
| Code pass | 7 of 7 mutations caught |
| Gap tests | None. The code decisions (order of `random!`, `rename_away!` and `place!`; the `.del` paths in the one cleanup) are pinned by the `calls.log` of `dx1`, `dx2` and `rm6`, and no mutation was missed. |
| Design gaps | Section 8 (Q-S1, Q-X1, Q-T1, Q-R1, Q-B1), recorded in PLAN-P1 5b |
