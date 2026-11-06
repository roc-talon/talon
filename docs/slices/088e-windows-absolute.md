# 088e Windows absolute paths

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Source: slice 088d questions Q1 to Q3 and slice 088 question Q-W1. The design answer is G-C34, Design Q214, CLI R-PX6 and R-LY10 (2026-11-02). Slice 088 took `XDG_CACHE_HOME` on Windows as it is. R-LY10 now reverses this.

## 1. Rules

| Rule | Text (short) |
| --- | --- |
| R-PX6 (Q214) | A `..` at the root is dropped. Empty parts and a trailing separator are removed. The Windows root is `C:\` or the UNC prefix `\\server\share`. A `..` never removes a part of the root. A path that is not absolute is kept after the `.` and `..` steps |
| R-LY10 (Q214) | An empty variable is not set. On Windows, a root variable that is not absolute (`C:x`, `x\y`) is not set. A `\` at the end of a value is dropped |
| R-LY5, R-LY6, R-LY7 | The order: cache `XDG_CACHE_HOME`, `LOCALAPPDATA`, `HOME`. Config `APPDATA`, else `HOME`. Data `LOCALAPPDATA`, else `HOME` |

Root variables (the Windows column of 6.1): `XDG_CACHE_HOME`, `LOCALAPPDATA`, `APPDATA`, `HOME`. Absolute on Windows: a drive letter (any case), `:`, and `\` or `/`; or a UNC prefix `\\`. (The UNC form is a choice for the rows: the design gives `\\server\share`.)

## 2. Signatures

No new function and no new type. Two bodies change:

| Function | Change |
| --- | --- |
| `Launch.clean_text : { windows : Bool, path : Str } -> Str` (088d) | UNC root, relative path with no root, `..` never removes a root part |
| `Roots.from_env_on(Windows, env)` (private `windows_roots`) | A variable that is not absolute is skipped, so the next rule applies |

## 3. Gaps of the 088d code (the red rows)

| Input | Now | Right |
| --- | --- | --- |
| Windows `\\srv\sh\a` | `\srv\sh\a` (one `\` lost) | `\\srv\sh\a` |
| Windows `\\srv\sh\..\..\x` | `\x` | `\\srv\sh\x` |
| Windows `x\y\..\z`, `./x/./y`, `C:x\.\y` | a root `\` is a prefix | `x\z`, `x\y`, `C:x\y` |
| Linux `a/./b/../c`, `\\srv\sh\x` | a root `/` is a prefix | no prefix |
| Windows `XDG_CACHE_HOME` = `D:cache`, `cache\x`, `/x/cache` | used | not set |
| Windows `LOCALAPPDATA` = `x\y`, `APPDATA` = `C:x`, `HOME` = `C:h` | used | not set |

The rows for `..` at the root (`/../a`, `C:\..\a`), empty parts and a trailing separator pass with the 088d code already (checked: they are guards for the new body).

## 4. Tests

| Layer | File and case | What | Rules | State |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/LaunchTest.roc`, new last `expect` (driver `l0-1.roc`) | `Launch.clean_text`, 17 rows: Linux (`..` at root, `..` only, empty parts, root alone, relative, `\\` is a name); Windows (drive `..`, drive back to root, drive root alone, empty parts, UNC with `.`, UNC `..` x2, UNC `..` after the share, UNC with `/`, relative `\`, relative `/`, `C:x`) | R-PX6 | red: 9 rows |
| L0 | `tests/unit/RootsTest.roc`, new `expect` before the layout `expect` (driver `l0-8.roc`) | `Roots.from_env_on(Windows, env)`, 9 rows of (cache, config, data): 3 XDG forms not absolute, a lower case drive with `/`, `LOCALAPPDATA` relative, `APPDATA` `C:x`, git bash `HOME`, `HOME` `C:h` alone (failure `LOCALAPPDATA is not set`), a UNC value. Plus Linux: `XDG_CACHE_HOME` `D:\cache` is ignored | R-LY10, R-LY5, R-LY6, R-LY7 | red: 6 rows |

Old rows: no change. The old Windows rows already use absolute values (`D:\cache`, `C:\...`). The row "Windows, XDG_CACHE_HOME is taken as it is" stays valid. Only the doc comment of 088 Q-W1 is now old.

Red output (`.work` logs `088e-red-1.log`, `088e-red-8.log` in the scratchpad): l0-1 106 passed, 1 failed (`LaunchTest.roc:118`). l0-8 118 passed, 4 failed: `RootsTest.roc:137` (new) and 3 `ShareTest.roc` (slice 214, not this slice).

## 5. Output

No output text and no `data` field.

## 6. Out of scope

| Item | Reason |
| --- | --- |
| L2 and L3 | The fake host is Linux, and CI on Windows runs `check fmt l0` only (088d section 6) |
| `Roots.from_env` (Linux) | No change |

## 7. Questions (TW17), not tested

| Id | Question | Options |
| --- | --- | --- |
| Q1 | The result of a UNC root with no part after it (`\\srv\sh`, `\\srv\sh\..`): `\\srv\sh` or `\\srv\sh\`? Q214 writes the root as `\\server\share` | (a) `\\srv\sh` (as Q214 writes it). (b) `\\srv\sh\` (as the drive root `C:\`) |
| Q2 | A relative path that starts with `..` (`../a`, `a/../../b`): the `..` has nothing to remove | (a) kept (`../b`). (b) dropped. Q214 says "kept after the `.` and `..` steps" |
| Q3 | `ROC_CACHE_DIR` that is not absolute on Windows: is it a root variable of R-LY10? R-CR1 | (a) yes, not set. (b) no, used as it is (R-PX6 then cleans it as a relative path) |
| Q4 | A UNC prefix with `/` in a root variable (`//srv/share/L`), and a value `C:\` where the `\` at the end is dropped (`C:`, no longer absolute) | Is `//srv/share` absolute on Windows? Is the check before or after the drop of the `\`? |
| Q5 | `XDG_CONFIG_HOME` and `XDG_DATA_HOME` on Windows (088 Q-W2) | R-LY6 and R-LY7 name `APPDATA`, `LOCALAPPDATA` and `HOME` only, so the rows do not set them |

## 8. Revert check

The private reference (`Launch.roc` and `Roots.roc` with a `win_abs` check) passed all rows. It is deleted (manager rule). 6 hand mutations, all killed:

| Mutation | Killed by |
| --- | --- |
| UNC root loses one `\` | UNC rows |
| A relative path gets a root | relative rows |
| UNC share is a part, so `..` removes it | UNC `..` rows |
| No absolute check on Windows | the 088e Roots `expect` |
| A UNC value is not absolute | the UNC row |
| Drive needs `\` only (no `/`) | the row `d:/cache` |

## 9. For the code agent

1. `Launch.clean_text`: new body by section 1 (the reference is private: write it from the rules). Do not choose the Q1 to Q5 cases.
2. `windows_roots` in `Roots.roc`: skip a variable that is not absolute, for all 4 root variables (not `ROC_CACHE_DIR`, Q3). Update the doc comments that say `XDG_CACHE_HOME` is taken as it is.
3. Run `l0-1` and `l0-8`.

## 10. Disputes (from the code agent)

| Test | Problem | Design source | Action |
| --- | --- | --- | --- |
| L2 cases `ptool/pt4-bin-file`, `tool/dl2-tool-windows`, `tool/dl3-rename-edges`, `tool/dx2-source-windows` (tag windows; `fx/env`) | Their `LOCALAPPDATA` is `{w}/home/AppData/Local` and `APPDATA` is `{w}/home/AppData/Roaming`: a path that starts with `/`, with no drive. With R-LY10 (rows of the l0-8 `expect`: `/x/cache` is not absolute on Windows) the variables are not set. `HOME` is `{w}/home`, also not absolute. So `Roots.from_env_on(Windows)` fails with `LOCALAPPDATA is not set` (exit 18), and the cases show exit 18 where they expect exit 0. The `XDG_CACHE_HOME`, `canonical`, `list_dirs` and `read_files` path lines of the cases do not change except where the roots fail. | R-LY10, R-PX6 (Q214) | Code agent did not edit the fixtures (TW18). Option A: the test agent changes `fx/env` of the 4 cases to drive paths (`C:/...`), and the expected path lines. Option B: R-LY10 accepts a rooted path (`/x`) on the fake host. The l0-8 row for `/x/cache` rejects option B. Manager to decide. |

## 11. Verify results (code agent)

| Check | Result |
| --- | --- |
| `roc check cli/main.roc` | 0 errors |
| l0-1 | all 107 pass |
| l0-8 | all 122 pass (the 3 ShareTest rows pass now) |
| L2 windows cases | the 4 above fail (section 10) |
| Code | `Launch.clean_text` (UNC root, no root for a relative path), `Roots.windows_absolute` and `root_of` in `windows_roots` (not for `ROC_CACHE_DIR`, Q3). Copy: `research/slice-088e-revert/code-final/` and `code-final.sha256`. |
| Revert check | not done (the manager rule: only on request) |

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| Code (088e code agent) | l0-1 107 of 107, l0-8 122 of 122, `roc check` clean |
| Dispute (section 10) | Settled in slice 088f: the Windows L2 cases use the drive form `C:/...`, through a link `<W>/C:` to `home` that `tests/commands/run.sh` makes only for cases whose `fx/` has `C:/`. All 15 Windows cases pass with the 088e code. |
| Q1 to Q4 | Answered by Q216 (G-C36). The code changes for them are in slice 088f. |
| Revert check | Test step: 6 mutations caught. |
