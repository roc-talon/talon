# 078b Bin records in the tool flows

Phase: P1. Status: done

Slice 078b is the plan row 078b of `PLAN-P1.md` (section 2c). It follows slice 078 (review Q1, option b, manager 2026-10-26). Slice 078 made `tools.json` record the sha256 of each bin dir entry that Talon made (`bin`), and the pure decisions `ToolInstall.verdict_bin` and `ToolManage.fate_bin`. No flow uses them yet. This slice puts them in the flows. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files and the private reference are in `research/slice-078b-revert/`.

## 1. Rules

| Rule | Text (short) | Where |
| --- | --- | --- |
| R-ST11 (2) | An entry is Talon's when its sha256 is the one of its data file, or the one that `bin.<name>` records. A stale entry that is recorded is Talon's. | all flows below |
| R-ST9 | A stale entry (left on the old file by a stopped step) is Talon's, so the install, update, rebuild, take-over and `tool update talon` replace it with no stop. | the install family, `TalonUpdateFlow` |
| R-ST6 | An entry with no record, or with a record of another file, is foreign: exit 2 before the download, and `remove` keeps it. | same |
| R-RM6, R-B6 | `tool remove` and `tool remove talon` delete a stale recorded entry (it is Talon's). | `ToolManageFlow`, `TalonRemoveFlow` |
| R-T4 | The new sha256 replaces the old one in `bin.<name>` (slice 078 writes it). | `ti5`, `tk3`, `ts9` |
| R-CC6 | The check under the lock has the text of `tools.json` already: no new read. | `ti5`, `tk3` |

## 2. The rule of the manager (Q1 of slice 078)

| Place | Rule |
| --- | --- |
| The check before the download (`ToolBuild.entry_verdict!`, `entry_state!`, `TalonUpdateFlow.states!`) | The first check is the old one (the sha256 of the data file). `tools.json` is read (one `read_files`) only when the entry is a file (`Sha`) that is not Talon's by the data file. A missing entry, a directory and an unreadable entry read nothing. |
| The check under the lock (`ToolBuild.install!`, `XTake.taken!`, `TalonUpdateFlow.installed!`) | The text of `tools.json` is read already (step 11 or 10). The record comes from it: no new call. |
| The remove path (`ToolManageFlow.remove_locked!`, `TalonRemoveFlow` step 7) | The text is read already (under the lock, and in step 2). No new call. |

## 3. What the code does today

| Part | Today |
| --- | --- |
| `ToolBuild.entry_read!` (all tool flows, `XTake`) | `ToolInstall.verdict({ old, have })`: a stale entry is `Foreign`. |
| `TalonUpdateFlow.states!` | `ToolInstall.verdict` for `tln` and `roc`. |
| `ToolManageFlow.remove_locked!`, `TalonRemoveFlow.fate_of!` | `ToolManage.entry_fate`. |

## 4. Where the code changes (for the code agent)

No public signature of a module of `cli/lib/main.roc` changes. The reference changes these private functions (a proposal, the code agent may choose another shape):

| # | Place | Change |
| --- | --- | --- |
| 1 | `ToolBuild.entry_read!` | New 3rd argument `known : [Fresh, Text(Try(Str, [NotFound]))]`. When `ToolInstall.verdict({ old, have })` is `Foreign` and `have` is `Sha(_)`: the text is `known`'s, or (`Fresh`) `SetupIo.read_text!` of `tools.json`. `BinRecord.read`, the pair of the file name (no `.exe`), `ToolInstall.verdict_bin`. Else the old verdict, no read. |
| 2 | `ToolBuild.entry_state!`, `entry_verdict!` | `Fresh` (the check before the download). |
| 3 | `ToolBuild.install!`, `XTake.taken!` | `Text(text)`: the text that the step read under the lock. |
| 4 | `TalonUpdateFlow.states!` | The same 3rd argument. `Fresh` in the 2 checks before the download (prebuilt, `--from-source`), `Text(text)` in `installed!`. One read for both entries. `tln` and `roc` are looked up by the names `tln` and `roc`. |
| 5 | `ToolManageFlow.remove_locked!` | `BinRecord.read` of the text in hand, `ToolManage.fate_bin`. |
| 6 | `TalonRemoveFlow.Scene` | New field `records : List((Str, Str))` (`BinRecord.read` of the text of step 2), `fate_of!` uses `ToolManage.fate_bin`. |

`ToolInstall.verdict`, `ToolManage.entry_fate`, `Setup.judge` stay (D8 of slice 078).

## 5. Tests

| Layer | Case | Content | Rule ids |
| --- | --- | --- | --- |
| L2 new | `tool/ti5-stale-recorded` (2 runs) | Run 1: `tool install acme/z@2.0.0` with a stale entry that `bin.z` records: the early check reads `tools.json` once and passes, the build runs, the entry is made again, `bin.z` has the new sha256. Run 2: `tool install acme/qux@2.0.0` with a stale entry and a record of another file: exit 2 before the download. | R-ST11 R-ST9 R-ST6 R-T4 R-CC6 |
| L2 new | `tool/tk3-takeover-stale` (1 run) | The take-over of an `x` entry with a stale recorded entry: replaced, no new read under the lock, `bin.qux` has the new sha256. | R-B4 R-ST11 R-ST9 R-T4 |
| L2 new | `tool/ts9-stale-recorded` (1 run) | `tool update talon` with a stale recorded `tln` and a stale recorded `roc`: both are made again, no warning, `bin.tln` and `bin.roc` have the new sha256. | R-ST9 R-ST11 R-S3 R-T4 |
| L2 new | `tool/tm2-remove-stale` (2 runs) | `tool rm foo`: the stale recorded entry and the binary are deleted, no warning. `tool rm g --json`: a record of another file, the entry is kept with the warning (`kept`). | R-B6 R-RM6 R-ST11 R-ST6 |
| L2 new | `tool/rm7-stale-recorded` (2 runs) | `tool rm talon --remove-tools --json` and `--keep-all`: a stale recorded `tln` and a stale recorded `foo` entry are deleted, `baz` (record of another file) is kept with the warning. | R-RM6 R-ST11 R-ST9 R-RM3 |
| L2 changed | `tool/ti2-refusals`, `tg2-gitstops`, `tr2-rebuildstops`, `ts3b-foreign`, `ts4-rocforeign` (`expect/calls.log`) | One new line `read_files $HOME/.local/share/talon/tools.json` after the `sha256_file` lines of the check, in each stop of a foreign file (6 lines in all: `ti2` 1, `tg2` 1, `tr2` 2, `ts3b` 1, `ts4` 1). Stdout, stderr, exit code and tree do not change. | R-ST6 R-ST11 |

L0: no change (slice 078 has the L0 rows). L3: no change (the real `Fx` has no logic here, TW4). Test counts: 5 new L2 cases (8 runs), 5 changed `calls.log` files.

Old `calls.log` lines are in `research/slice-078b-revert/before/`. Each diff is one added line (TW21): the 5 stops are the ones that the manager named.

## 6. Output (proposed, TW24)

None. No new text, no new `data` field. The stops and the warnings keep their text.

## 7. Out of scope

| Item | Reason |
| --- | --- |
| `tln setup` | Slice 078 did it (`SetupFlow` reads the record). |
| The check of `tool update talon` under the lock when the entry changes during the download | Same code as `ts9` (`states!` with the text in hand). No extra case. |
| Windows (`.exe` names) | The record has no `.exe` (slice 078). The Windows CI job. |

## 8. Questions (TW17)

None. The manager decided the shape (option b, Q1 of slice 078). One note for the review: `TalonUpdateFlow` and `TalonRemoveFlow` already hold the text of `tools.json` in some steps. For `tool update talon` the check before the download has no text in hand (`ToolManageFlow.machine!` does not keep it), so it reads again, as the manager's list of 5 cases says. The reference does the same.

## 9. Red output

With the old code (the reference away). `scripts/test.sh check fmt l0 l2` before my change: all pass.

| Step | Result |
| --- | --- |
| check, fmt | pass (no change of a `.roc` file) |
| l0 | pass |
| l2 | FAIL, 10 cases: the 5 changed (`Fx calls` lacks the `read_files` line) and the 5 new ones. `ti5` run 1, `tk3` and `ts9` stop with exit 2 (the stale entry is foreign), `tm2` and `rm7` keep the stale entry with a warning. |

With the private reference: `scripts/test.sh` passes (check, fmt, l0, l2, l3, selftest, l1).

## 10. Revert check (TW12)

7 changes of the reference, one at a time (`research/slice-078b-revert/mutate.py`). All are caught.

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | `entry_read!` ignores the record | `ti5` run 1, `tk3` |
| m2 | `install!` passes `Fresh` (a read under the lock) | `ti5` (calls), `ti2` |
| m4 | `states!` ignores the record | `ts9` |
| m5 | `states!` looks up `roc` by the name `tln` | `ts9` |
| m6 | `tool remove` ignores the record | `tm2` |
| m7 | `tool remove talon` ignores the record | `rm7` |
| m8 | `XTake` passes `Fresh` under the lock | `tk3` |

## Review (manager, 2026-10-26)

| Item | Result |
| --- | --- |
| Slice, tests | Accepted. |
| Output proposals | None. |
| Differences from the manager list (`ts3b`, `ts4` change) | Accepted. |
| Next | Code agent: green. |

The private reference and `mutate.py` are deleted. `research/slice-078b-revert/before/` stays.

## Disputes (from the code agent)

None.

## Verify results (code agent)

Code: `ToolBuild` (new type `Known`, `bin_pairs!`, `verdict_in`, `recorded`; `entry_read!`, `entry_state!`, `entry_verdict!` take `known`; `install!` passes `Text(text)`), `XTake` (`Fresh` before the move, `Text(text)` under the lock), `ToolFlow`, `ToolGitFlow`, `ToolUpdateFlow` (`Fresh`), `TalonUpdateFlow.states!` (one read for `tln` and `roc`, only when an entry is a file that the data file does not vouch for; `Text(text)` in `installed!`), `ToolManageFlow.remove_locked!` and `TalonRemoveFlow` (`Scene.records`, `fate_bin`) read the record from the text in hand. No public signature of `cli/lib/main.roc` changes. No dispute, no question.

`scripts/test.sh` exit 0 (check, fmt, l0, l2, l3, selftest, l1), run once with the code of the 3 slices 078b, 079b and 072d. Revert check: `research/slice-072d-revert/agent-mutate.py` (filtered L2 runs, one change at a time; the file goes back from a copy after each run). Result: caught 5 of 5.

| Id | Change | Result |
| --- | --- | --- |
| a1 | `ToolBuild.recorded` never finds a name (the record is ignored) | `ti5`, `tk3` |
| a2 | `install!` reads `tools.json` again (`Fresh`) | `ti5` (calls) |
| a3 | `states!` looks up `roc` by the name `tln` | `ts9` |
| a4 | `tool remove` ignores the record | `tm2` |
| a5 | `tool remove talon` ignores the record | `rm7` |

The code is the same as before the mutations (`sha256sum -c` of `research/slice-078b-revert/code-final.sha256` against `cli/lib`; the copy is in `research/slice-078b-revert/code-final/`).

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Disputes, questions | none |
