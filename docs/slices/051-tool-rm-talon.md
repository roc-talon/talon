# 051 `tln tool remove talon`: the prompt, the groups, `--dry-run`, the order of the removal

Phase: P1. Status: done

Slice 051 adds `tln tool remove talon [--dry-run] [--remove-tools | --keep-all]` (CLI 6.5 "Remove Talon": R-S5, R-RM1 to R-RM10, R-NI10, and the profile line of R-ST4). The command shows what Talon also manages (tools, compilers, Talon data) with the sizes, asks for one of 4 options, and removes the chosen groups. Talon itself goes last: the entry `roc`, `roc.old` back to `roc`, the entry `tln`, and the file `tln` of the data bin dir. R-RM2 (links) already has tests (slice 034 and the `roc remove` slices). The `.del` sweep of R-ST10 (the delete of old `.del` files at each start) is slice 050c, and is not here.

Size (TW19): the private reference (`research/slice-051-revert/reference/`, deleted at the review, 2026-10-25) had 399 lines in `TalonRemove` (about 290 code lines without comments and blank lines), 391 in `TalonRemoveFlow` (333 code lines), 8 in `Setup`, 4 in `ToolManage`, 7 in `Fx`, 25 in `RealFx`, 3 in `Run`, 2 in `main.roc`. That is about 670 code lines. The plan row says about 250, so the slice is split in 3 parts, one test set, 3 code passes one after another (the manager decided at the review):

| Part | Code | Tests that turn green |
| --- | --- | --- |
| 051a | `TalonRemove` (all pure functions, about 290 code lines), `Setup.profiles` and `Setup.profile_strip`, `ToolManage` (the 2 changes, 4 lines) | L0: `TalonRemoveTest` 1 to 8, `SetupTest` 11, `ToolManageTest` 1 |
| 051b | `TalonRemoveFlow`: `remove!`, the steps 1 to 13 and `unix!` (about 290 code lines). `windows!` is the stub `crash "todo: slice 051c"` | L2: `tool/rm1-default`, `rm2-options`, `rm4-stops`. L3: `tools/rm1-remove-talon`, `tools/rm2-remove-all` |
| 051c | `windows!` (about 45 lines), `RealFx.spawn_detached!` (25 lines) | L2: `tool/rm3-windows`, `tool/rm5-win-path`. L3: `fx/sd1-real-fx-spawn-detached` |

Each test is in one part. `ToolsJson` is not changed (460 lines): `ToolsJson.drop` works on the raw pairs and needs no new function. `Run`, `main.roc`, `Fx` and `FakeFx` are complete in the stub state (wiring), so no part touches them. No module is over 490 lines.

| Part | Make green | Command |
| --- | --- | --- |
| 051a | L0 `TalonRemoveTest` 1 to 8. `SetupTest` 11. `ToolManageTest` 1. All old L0 `expect`s | `scripts/test.sh l0` |
| 051b | L2 `tool/rm1-default`, `rm2-options`, `rm4-stops`. L3 `tools/rm1-remove-talon`, `tools/rm2-remove-all`. The old L2 and L3 cases | `tests/commands/run.sh tool/rm1 tool/rm2 tool/rm4`, `tests/run.sh tools/rm1-remove-talon tools/rm2-remove-all`, then `scripts/test.sh` |
| 051c | L2 `tool/rm3-windows`, `tool/rm5-win-path`. L3 `fx/sd1-real-fx-spawn-detached`. All cases | `tests/commands/run.sh tool/rm3 tool/rm5`, `tests/run.sh fx/sd1`, then `scripts/test.sh` |

After 051a and before 051b, `tool remove talon` still ends in the stub of the flow (`todo: slice 051b`): the 5 tests of 051b stay red until then. After 051b, a Windows run ends in the stub `windows!` (`todo: slice 051c`): `tool/rm3-windows` and `fx/sd1` stay red until 051c. Live reads: none. No network. L2 uses the fake `Fx`. L3 uses the real `Fx` in a copy of the home on tmpfs (hard links made by the `cmd` file with `ln`), with the real sha256, `rename`, `delete`, `tree_info`, locks and `write_atomic`.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-S5 | `tool rm talon` asks what to remove (prompt R-NI10), then removes it. `rm` and `remove` are the same command | L0 `TalonRemoveTest` 1, `ToolManageTest` 1. L2 rm1 runs 3 to 5. L3 rm1 |
| R-NI10 | The prompt: kind Default, 4 options, default 1, the screen of the design with the 3 groups and their sizes, the note on `roc`, the word `Choose`. A reply is a number from 1 to 4, Enter is 1, another reply asks again | L0 `TalonRemoveTest` 1, 2, 5. L2 rm1 runs 3, 4, rm2 runs 3, 4, 5 |
| R-RM3 | Option 1 is the default. With no person the answer is option 1 with no prompt. `--yes` is option 1. `--remove-tools` is option 2, `--keep-all` is option 3, in both modes. A flag wins over `--yes` (R-NM10) | L0 `TalonRemoveTest` 1, 5. L2 rm1 runs 4, 5, rm2 runs 1 to 5. L3 rm1 step 2, rm2 |
| R-RM4 | `--dry-run` prints the table with the sizes and removes nothing (no prompt, no lock, no write) | L0 `TalonRemoveTest` 4, 6, 7. L2 rm1 runs 1, 2. L3 rm1 step 1 |
| R-RM7 | Talon: the file `tln` of the data bin dir, the entries `tln` and `roc` of the bin dir, the entry `talon` of `tools.json`. Removed in each option | L0 `TalonRemoveTest` 2. L2 rm1 run 4, rm2 runs 1, 2, 4, 5. L3 rm1, rm2 |
| R-RM8 | Tools: the other tool files, their bin dir entries, `tools.json`, the profile line of `tln setup`. Removed only in option 2 | L0 `TalonRemoveTest` 2, `SetupTest` 11. L2 rm2 runs 1, 5, rm3 run 1. L3 rm2 |
| R-RM9 | Compilers: `toolchains/<id>/`, `toolchains/zig-<v>/`, the `compat-<id>/` dir of each removed compiler. Options 1 and 2 | L0 `TalonRemoveTest` 2, 3, 4. L2 rm1 run 4, rm2 runs 1, 2. L3 rm1 step 2, rm2 |
| R-RM10 | Talon data: `<cache>/talon`, `config.toml`, `share.json`. Options 1 and 2 | L0 `TalonRemoveTest` 2, 4. L2 rm1 run 4, rm2 runs 1, 2, rm4. L3 rm1 step 2, rm2 |
| R-RM1 | Never removed: `packages/`, the build cache of a compiler that Talon did not install, the app installs of `roc install` | L0 `TalonRemoveTest` 4 (no ask names them). L2 rm1 run 4 (the tree). L3 rm1 step 2, rm2 |
| R-RM5 | Talon last: the file `tln` of the data bin dir is the last path. Windows: each running `.exe` is renamed to `<name>.<hex>.del`, one detached `cmd.exe /d /c` waits and deletes them. When it does not start, the renamed files stay, with a warning | L0 `TalonRemoveTest` 6, 8. L2 rm1 run 4, rm3 runs 1, 2, rm4. L3 rm1, sd1 |
| R-RM6 | The `roc` launcher always goes. The path of each compiler that stays (option 3) is printed (a link prints its target). `roc.old` moves back to `roc`. A compiler whose path was `roc.old` (`link-system`) is printed at the path where it is after the move | L0 `TalonRemoveTest` 6, 8. L2 rm1 run 4, rm2 runs 2, 4, rm3 run 2. L3 rm1 step 2, rm2 |
| R-ST6, R-ST11 | A bin dir entry that tln did not write (its sha256 is not the one of the data file) stays, with a warning. A foreign `roc` also keeps `roc.old` where it is | L0 `TalonRemoveTest` 6. L2 rm2 runs 1, 2, 4, rm3 run 2. L3 rm2 |
| R-ST4 | The profile line has the marker `# talon: added by tln setup`. Option 2 removes it from the 3 profiles. Windows: exactly the bin dir of the user `Path` | L0 `SetupTest` 11. L2 rm2 run 1, rm3 run 1. L3 rm2 |
| R-ST10 | Windows: the `.del` renames, in the order `roc.exe`, `tln.exe`, the data file. (The sweep at each start is slice 050c) | L0 `TalonRemoveTest` 8. L2 rm3 runs 1, 2 |
| R-CC6, R-CC10 | `tools.json` is changed in its lock. Each compiler and each Zig is removed in its own lock | L2 rm1 run 4 (the `calls.log`) |
| R-J1 to R-J4, R-OUT2, R-OUT4 | The text goes to stdout (stderr with `--json`). `--json` gives the `data` of `tool rm` with one outcome | L0 `TalonRemoveTest` 6, 7. L2 rm1 run 2, rm2 run 1 |
| R-FL12, R-CM16, R-CM19 | `--dry-run`, `--remove-tools`, `--keep-all` are for `tool remove talon` only. The 2 answer flags together: exit 2. `rm talon foo`: exit 2 | L0 `TalonRemoveTest` 1, `ToolManageTest` 1. L2 rm2 run 3, `tm1-manage` run 5 |
| R-HF11 | Windows: the user `Path` is changed with one `exec!` of `powershell` (`Setup.windows_path`, `Remove`) | L0 `TalonRemoveTest` 8. L2 rm3 run 1 |

Other rule ids that the tests name (the slice does not own them): R-NM4, R-NM6, R-NM8, R-NM10, R-NR2, R-NR3, R-B6, R-T4, R-ST13, R-DA7, R-LY8, R-RM2 (a link is removed, the target stays: rm1, rm2).

Rule check: `MISSING=1 scripts/rules.sh R-RM R-S R-NI` lists only R-NI11, R-NI15 and R-NI16 (prompts of other commands). R-S5, R-RM1, R-RM3 to R-RM10 and R-NI10 each have a test.

## 2. Files

New files (also in `research/slice-051-revert/before/NEW.txt`). The code agent writes the bodies of the 2 stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/TalonRemove.roc` | 173, 399 | Part A: the pure decisions. All functions are stubs except `is_target` |
| `cli/lib/TalonRemoveFlow.roc` | 28, 391 | Part C: `remove!`, the command code (stub: `crash "todo: slice 051b"`). `windows!` is `crash "todo: slice 051c"` in part 051b |
| `tests/unit/TalonRemoveTest.roc` | 312 | L0, 8 `expect`s. Imported by the driver `tests/unit/l0-6.roc` |
| `tests/commands/cases/tool/rm1-default`, `rm2-options`, `rm3-windows`, `rm4-stops` | | L2, 13 runs |
| `tests/scenarios/tools/rm1-remove-talon`, `rm2-remove-all`, `tests/scenarios/fx/sd1-real-fx-spawn-detached` | | L3 |
| `research/slice-051-revert/` | | `stubs/`, `before/`, `restore.sh` (`stubs` and `before`), `gen-remove.py`, `gen-l3.py`, `mutations.txt`, the logs. `reference/` is deleted, so `mkstubs.py` and `mut.py` no longer run |

Changed files. In the stub state the wiring is complete, the 3 other files are not changed (the code agent changes them: part 051a).

| File | Change | State |
| --- | --- | --- |
| `cli/lib/Fx.roc` | New field `spawn_detached! : { argv, env } => Try({}, [NotStarted(Str)])`, its wrapper and its doc | complete (stub state) |
| `cli/lib/main.roc` | Exposes `TalonRemove` and `TalonRemoveFlow` | complete |
| `cli/lib/Run.roc` | Imports both modules. `["tool", "remove"]` goes to `TalonRemoveFlow.remove!` when `TalonRemove.is_target(args)` | complete |
| `cli/RealFx.roc` | The field `spawn_detached!` | stub body (`crash "todo: slice 051c"`) |
| `cli/lib/Setup.roc` | `profiles`, `profile_strip` | 2 stubs (051a) |
| `cli/lib/ToolManage.roc` | `operand_ref` row 7 only for `rebuild`. `flag_check`: `"remove" => if talon [] else [flags]` | not changed. 051a: 4 lines |
| `tests/commands/FakeJobs.roc`, `FakeFx.roc`, `cli/fxprobe.roc` | The fake and the probe for `spawn_detached!` (`spawn_detached <args>` and `  env` lines in `calls.log`, the rules of `fx/exec`: only `notstarted:<text>` matters) | test files, done |

## 3. Public signatures

The L0 tests call these, so they are fixed (the stub files have the full types and doc comments):

| Function | Type |
| --- | --- |
| `TalonRemove.is_target` | `Args -> Bool` |
| `TalonRemove.read` | `Args -> Try(Plan, Fail)` (`Plan : { dry_run : Bool, flag : Try(Answer, [NoFlag]) }`) |
| `TalonRemove.choice_of` | `Answer -> Try(Choice, [Cancel])` (`Choice : [Default, WithTools, TalonOnly]`) |
| `TalonRemove.removes` | `{ choice : Choice, group : Group } -> Bool` (`Group : [Talon, Tools, Compilers, Data]`) |
| `TalonRemove.zig_versions` | `List({ name, is_dir, mtime }) -> List(Str)` |
| `TalonRemove.describe_tools`, `describe_compilers` | `List(Str) -> Str`, `{ ids : List(Str), zigs : List(Str) } -> Str` |
| `TalonRemove.asks` | `{ roots, file, tools, ids, compats, zigs } -> List(Ask)` |
| `TalonRemove.parts` | `{ asks, infos, tools, ids, zigs } -> List(Part)` |
| `TalonRemove.prompt` | `{ version : Str, parts : List(Part) } -> Prompt` |
| `TalonRemove.screen`, `label` | the text of the prompt, the name of a group |
| `TalonRemove.report`, `warnings` | `Done -> List(Str)` |
| `TalonRemove.data` | `Done -> JsonDoc` |
| `TalonRemove.kept_path` | `{ id, roc, link : Try(Str, [None]), moved : Try({ from : Str, to : Str }, [None]) } -> Str` |
| `TalonRemove.restores` | `{ old : Bool, roc : [Remove, Gone, Keep] } -> Bool` |
| `TalonRemove.cleanup_command` | `List(Str) -> { argv : List(Str), env : List((Str, Str)) }` |
| `TalonRemove.file` | `Setup.Os -> Str` |
| `Setup.profiles` | `{ home : Str } -> List(Str)` |
| `Setup.profile_strip` | `Str -> [Keep, Write(Str)]` |

`TalonRemoveFlow.remove! : Fx, Args => I32` is the one public function of the flow. Its private helpers are a proposal: the `calls.log` files fix the order of the `Fx` calls, not the names.

## 4. Tests

### L0 (`TalonRemoveTest`, 8 `expect`s, one new `expect` in `SetupTest`, one row set of `ToolManageTest`)

| # | Rows | Rules |
| --- | --- | --- |
| 1 | `read`: no flag, `--dry-run`, `--remove-tools` (option 2), `--keep-all` (option 3), `--dry-run` with an option, `--yes` is no part of the plan, both flags are a usage failure. `is_target`: `talon`, `roc-talon/talon`, another tool, `acme/talon`, no operand, 2 operands | R-NI10, R-RM3, R-RM4, R-FL12, R-S5 |
| 2 | `removes`: the 12 cells of the table of the groups. `choice_of`: options 1, 2, 3, and option 4, 0, 5, `Yes`, `No` give `Cancel` | R-RM7 to R-RM10, R-RM3, R-NI10 |
| 3 | `zig_versions`: a file, a lock dir, a temp dir, a compiler dir, a version with 2 or 4 numbers, a name with letters are no Zig, byte order. `describe_compilers`: the design example, one of each kind, plurals, only Zig, none. `describe_tools`: none, one, 3 in the order given | R-RM9, R-RM1, R-NR2 |
| 4 | `asks`: the paths in the order of the groups (the compat dirs of the recorded compat ids only, no `packages/`). `parts`: the sums of the 4 groups (a path that is missing or denied counts 0), the details. `.exe` on Windows | R-RM4, R-RM7 to R-RM10, R-RM1, R-NR2 |
| 5 | `prompt`: `Prompt.text` is the screen of the design plus `[1-4, default 1] `. `Prompt.decide` for no person, `--yes`, a flag, `--yes` with a flag (the flag wins), a person, no terminal. `Prompt.reply`: Enter, 1 to 4, `0`, `5`, `yes`. The 4 answer lines | R-NI10, R-NR2, R-NR3, R-NM4, R-RM3, R-NM10 |
| 6 | `report` for a real run (option 1, 2, 3), a dry run (options 1, 2), a cancel, with the lines for kept compilers, `roc.old` and the `PATH` entries. `warnings`: no warning, a kept entry, the renamed files that stay | R-RM4, R-RM6, R-RM3, R-ST6, R-RM5, R-OUT2 |
| 7 | `data`: a dry run, a real run of options 1, 2 and 3 with all lists, a cancel (the keys in order) | R-J3, R-J4, R-OUT4 |
| 8 | `kept_path` (a link has its target, another kind has `toolchains/<id>/roc`, a link whose target is the old path of the `roc.old` move is at the new path: `link-system`), `restores` (5 rows), `file` (Linux, macOS, Windows), `cleanup_command` for 3 files and for 1 file (`argv` and `env`) | R-RM6, R-RM5, R-ST10, R-HF11 |

`SetupTest` 11 (new): `profiles` (the 3 files) and `profile_strip` (no marker and the empty text are `Keep`, the line in the middle, last with and without a line end, only the line, the fish line, 2 lines with the marker, the marker with another dir, a line that only names talon stays). `ToolManageTest` 1 (the table of rows): `rm talon`, `rm roc-talon/talon`, `rm talon --dry-run`, `--keep-all`, `--remove-tools` are `remove talon`; `rm talon foo` is the usage failure for 2 operands; `rm talon --from-source` still fails at the parser; `rm foo --dry-run` and the other 2 flags still fail for a tool that is not Talon; `rebuild talon` is still `is not built yet`.

### L2 and L3

| Case | Content |
| --- | --- |
| L2 `tool/rm1-default` (5 runs, one Linux home) | 1 `--dry-run` (the 4 groups, nothing is removed, no prompt, no lock). 2 `--remove-tools --dry-run --json`. 3 a terminal, the answer 4: cancelled, exit 0. 4 a terminal, the answers `x` (asked again) and Enter: the removal of option 1, with the whole order of the calls (compilers and Zig each in a lock and a trash move, `tools.json` in its lock, the Talon data, the entry `roc`, `roc.old` back, the entry `tln`, the data file `tln` last). The link target, `foo`, `bar`, `baz`, `packages/`, `compat-other` stay. 5 the same line again: each path is gone, no failure |
| L2 `tool/rm2-options` (5 homes) | 1 `--remove-tools --json` (tools, `tools.json`, the profile line, baz keeps its entry with a warning). 2 `--keep-all` (kept compilers with paths, a link prints its target, `link-system` (its target is `roc.old`) is printed at `roc`, where `roc.old` moved to, a foreign `tln` stays with a warning, `roc.old` back). 3 both flags: exit 2. 4 `--yes` (a foreign `roc` stays, `roc.old` stays). 5 `--remove-tools --yes` (the flag wins, no `.bashrc`, no compilers) |
| L2 `tool/rm3-windows` (2 homes) | 1 option 2: the `powershell` exec, the `.del` renames in order, `roc.old.exe` back, one `spawn_detached` with 3 files in `TALON_DEL_1` to `TALON_DEL_3`. 2 option 3 with a foreign `roc.exe`: 2 files, the cleanup does not start (`fx/exec` `notstarted`), the warning names the 2 files, exit 0 |
| L2 `tool/rm5-win-path` (2 runs, gap step) | Windows, the user `Path` (R-RM8, R-ST4, R-HF11, R-EC18). 1 option 1 (`tool rm talon`, CI): the tools stay, so no `exec` of `powershell` and no `Path` line in the output. 2 `--remove-tools` with `fx/exec` `notstarted` for `powershell`: exit 18, `cannot start powershell`, the run stops at that step (no Talon data delete, no `.exe` rename, no `spawn_detached`), `tln` and `roc` stay |
| L2 `tool/rm4-stops` (1 run) | `fx/delete` refuses `share.json`: exit 18, `tln` and `roc`, `roc.old` and the data file `tln` are still there (Talon is last) |
| L3 `tools/rm1-remove-talon` | step 1 `--dry-run` (the state after it is the state before). Step 2 the removal with no terminal (option 1): the entries are hard links of the data file (real sha256), `roc.old` is `roc`, `foo` and `bar` stay as one file with their entries, `packages/` and `compat-other` stay, `tools.json` has no `talon` |
| L3 `tools/rm2-remove-all` | `--remove-tools`: the tools go with their entries (hard links), baz keeps its entry (warning), the `.bashrc` line is gone and the other lines stay, `tools.json` is gone |
| L3 `fx/sd1-real-fx-spawn-detached` | `fxprobe spawn-detached`: the call returns at once, the child runs after the probe ended (its file comes 1 s later), gets `env` and arguments, has no stdout and stderr of the probe. A program that is missing is `err` |

Old tests that changed: `tests/commands/cases/tool/tm1-manage` run 5 was `tool rm talon` (`is not built yet`), it is `tool rm talon foo` (exit 2, `takes one tool, got 2`) with its `fx/commands`, `rules`, `expect/stdout`, `expect/stderr`. `tests/unit/ToolManageTest.roc` rows (above) and its header comment. `tests/unit/SetupTest.roc` has 1 new `expect`. `tests/unit/l0-6.roc` imports `TalonRemoveTest`. Copies of each changed file are in `research/slice-051-revert/before/`. `UPDATE=1` ran only with the filters `tool/rm`, `tool/tm1`, `tools/rm1-remove`, `tools/rm2-remove`, `fx/sd1` (the first L3 run with the filter `talon` also matched `tools/ts1-update-talon` of slice 050: its `expect/http.log` was created, I deleted it, the other files did not change).

## 5. Output (proposed, R-OUT2, TW24)

| Item | Proposal |
| --- | --- |
| The screen (stderr, with the question) | The text of the design. The 3 groups are a table: the label, the content, the size, and for the tools the note `they run without Talon`. The columns are as wide as the widest cell, 3 spaces apart. The size is `Toolchain.size_text` (`42.0 MB`, `1.2 GB`: one decimal), right aligned as in the design example. The text keeps the decimal (the design shows `42 MB`; manager: keep `size_text`) |
| The answer line with no person (R-NM6) | Option 1: `removing Talon, the compilers and the data, keeping the tools`. Option 2: `removing Talon, the compilers, the data and the tools`. Option 3: `removing Talon only`. Option 4: `cancelled` |
| The table (stdout) | One row for each group: `<label>   <content>   <size>   <verb>`, the same columns as the screen. The verb is `removed` or `kept`, for a dry run `remove` or `keep` |
| `--dry-run` | The 4 rows, then `dry run: nothing was removed` |
| A cancel | `cancelled: nothing was removed`, exit 0 (as `cache clean`) |
| After the rows (a real run) | `kept <id>: <path>` for each compiler that stays (option 3; for `link-system` the path after `roc.old` moved back), `moved <from> back to <to>` for `roc.old`, `removed the PATH line from <file>` for each profile, `removed <dir> from the user Path` (Windows) |
| Warnings (stderr) | `warning: <path> is not a file that tln wrote, so tln keeps it` (the text of `tool remove`). `warning: tln could not start the cleanup of <n> renamed files, so they stay: <path>, <path>. A later install of Talon deletes them` |
| Usage failure | `tln tool remove talon takes --remove-tools or --keep-all, not both` (exit 2) |
| `--json` `data` | `outcome` (`removed`, `dry_run`, `cancelled`), `version`, `option` (1, 2, 3, null for a cancel), `groups` (array of `group`, `action`, `detail`, `bytes`; empty for a cancel), `compilers_kept` (array of `id`, `path`), `roc_restored` (path or null), `path` (array: a file or `the user Path`), `kept_entries`, `stuck`. The text goes to stderr |

## 6. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The order: the checks (sha256 of the data `tln`, the entries, the tool entries of option 2) before the first change. Then the compilers (each in its lock), `tools.json` in its lock (option 2: the tool files first, `tools.json` last, one delete), the `PATH` entry, the Talon data, and Talon last | Talon first. The Talon data before the tools |
| D2 | Options 1 and 3 write `tools.json` again without the entry `talon` (`ToolsJson.drop`). Option 2 deletes it | Option 2 writes an empty `tools` object |
| D3 | A cancel (option 4) is exit 0, with one line | Exit 1 |
| D4 | `--remove-tools` with `--keep-all` is a usage failure (exit 2) | The last flag wins |
| D5 | `--dry-run` never asks, even in a terminal. With no flag it shows option 1, with a flag that option | A prompt before the dry run |
| D6 | The cleanup of Windows is a new `Fx` call `spawn_detached!`, with the files in `TALON_DEL_<n>` variables of `env` (never in the script text: quoting) and 30 tries one second apart (`ping -n 2`) | `exec!` of `cmd /c start`. The paths in the script text |
| D7 | The compat dir of a compiler is removed with it (`Trash.move!`) only when its `.talon.json` has a compat id. The compat dirs of compilers that Talon did not install stay (R-RM1) | All `compat-*` dirs |
| D8 | An entry that tln did not write stays with a warning (R-ST6): `tln`, `roc`, or a tool entry (option 2). The data file `tln` and the tool data files are deleted anyway. A foreign `roc` keeps `roc.old` where it is | Delete the entry. Move `roc.old` over the foreign `roc` |
| D9 | Not removed: empty dirs (the bin dir, the data dir), stale temp and trash dirs of `toolchains/`, `tools.json.lock`, the shell completion files, an empty profile file (the line is removed, the file stays) | A sweep of empty dirs |
| D10 | A compiler that stays and is a link prints its target (`Link.target`). Other kinds print `toolchains/<id>/roc`. When the target of the link is the old path of the `roc.old` move (`link-system`), the printed path is the new path (`roc`): the path must be one that the user can put on `PATH` after the removal (manager, Q-RM2). `.talon.json` is not changed | The recorded target when it is stale. The dir of the compiler |
| D11 | `--quiet` hides the report lines. The warnings stay | Hide the warnings |
| D12 | The Windows `Path` step stops the run with exit 18 (`environment`) when `powershell` fails. Nothing after it runs, Talon stays | Go on and warn |
| D13 | A path that is already gone is no failure (a second run after a removal is exit 0) | A failure |
| D14 | The size column of the screen and of the table is right aligned (as in the design example). The text of the size is `Toolchain.size_text` (`42.0 MB`: one decimal), not the `42 MB` of the example (manager) | Left aligned. The size text of the example |
| D15 | Only Windows calls `spawn_detached!`. On Linux and macOS Talon deletes its own binary directly (R-RM5 names the detached `cmd.exe` for Windows). The L2 `calls.log` of rm1, rm2 and rm4 have no `spawn_detached` line (checked), rm3 has one for each run. `fx/sd1` tests the `Fx` call alone | A detached `sh` on Unix |

## 7. Out of scope

| Rule | What | Reason |
| --- | --- | --- |
| R-ST10 (the sweep) | The delete of `.del` files at each start of `tln` | Slice 050c |
| R-ST10 (real Windows) | A real rename of a running `.exe`, a real `cmd.exe`, the quoting of the script, a real `powershell` | There is no Windows machine in L2 or L3. L2 fixes the order of the calls and the text of the script. See Q-RM1 |
| R-RM1 (app installs of `roc install`) | That Talon never removes the app installs of `roc install` | The slice has no case with such an install (Design 2: it is a roc feature that Talon does not know). No path of the slice names it |
| R-RM2 | Links | Tested before (the removal of a `link-` compiler removes only the dir of the link). rm1 and rm2 name it again |
| R-NI10 (a real terminal) | The prompt on a pty | `Prompt.ask!` has L2 tests (the `fx/answers` of rm1). No L3 case with a pty for this prompt |
| R-ST4 (GITHUB_PATH) | A bin dir that `tln setup` appended to the file of `GITHUB_PATH` | Q-RM3 |

## 8. Questions (TW17) and design gaps

Questions and the answers of the manager (2026-10-25). The tests pin the answers.

| # | Question | Answer (pinned) |
| --- | --- | --- |
| Q-RM1 | R-RM5 says Talon starts "a detached `cmd.exe /d /c` that waits until Talon ends". basic-cli `Cmd.spawn!` is not detached: "final reference release terminates and reaps the process" (the L3 case `fx/sd1` found it). How does the real `Fx` detach? | Accepted as built: a launcher that ends at once. Unix `sh -c 'command -v "$1" ...; "$@" </dev/null >/dev/null 2>&1 &'`, Windows `cmd.exe /d /c start "" /b <argv>`. The Unix flow never calls `spawn_detached!` (D15). `fx/sd1` tests only the `Fx` call. The Windows launcher and the quoting of the script stay untested (design gap G1) |
| Q-RM2 | Option 3 keeps the compilers, and `link-system` (R-ST2) points to `roc.old`, which moves back to `roc` | Changed: the path that is printed is the path where the compiler is after the removal (`roc`). Tests: L0 `TalonRemoveTest` 8 (4 new rows), L2 `rm2-options` run 2 (a `link-system` compiler in h2) |
| Q-RM3 | R-ST4: option 2 and the file of `GITHUB_PATH` | Accepted: not handled (a CI job file does not persist). Design gap G4 |
| Q-RM4 | Locks for the delete of `talon/` in the cache | Accepted: no lock. Design gap G5 |
| Q-RM5 | A tool with a foreign entry (option 2) | Accepted: the data file is deleted, the entry stays. Design gap G6 |
| Q-RM6 | `--json` with no answer flag | Accepted: option 1 (R-RM3). Design gap G7 |
| Size column | Left or right aligned | Right aligned, with the `size_text` form (D14) |

### Design gaps

| # | Gap | Where | Pinned behavior |
| --- | --- | --- | --- |
| G1 | R-RM5 gives no mechanism for the detach. `Cmd.spawn!` cannot do it. The launcher of Windows (`start "" /b`, the quotes of the script) is a risk and has no test | R-RM5, Q-RM1 | The launcher of Q-RM1 |
| G2 | R-RM4 says "the table above", but the table above has the groups and no sizes | R-RM4 | A proposal: the screen columns with the sizes (D14, section 5) |
| G3 | R-RM6 says "Talon moves it back" and "prints the path of each compiler that stays", but does not say what the path of `link-system` is after the move | R-RM6, R-ST2 | The new path of `roc` (Q-RM2) |
| G4 | `tln setup` can append the bin dir to the file of `GITHUB_PATH`. Option 2 does not say if that is removed | R-ST4 | Not handled |
| G5 | Locks for the Talon data (`x` cache, `compat.db`) | R-CC10 | No lock |
| G6 | A tool whose bin dir entry is not Talon's, in option 2 | R-RM8, R-ST6 | The data file goes, the entry stays with a warning |
| G7 | `--json` with a prompt: the answer with no flag | R-RM3, R-NM | Option 1 |
| G8 | Windows, option 2: `powershell` that starts and exits with a code other than 0. The design fixes only `powershell` that is not on `PATH` (R-EC18: exit 18). The fake `exec` gives no exit code, so this has no test | R-HF11, R-ST4, R-EC18 | The same: exit 18, the run stops (D12) |
| G9 | Windows: a `.del` rename that fails. R-ST10 and R-RM5 do not say what happens. The files that were renamed before stay (no cleanup is started, no rollback), so `roc.exe` can be gone while `tln.exe` is not. Not a test: a rename error is rare and the fake gives only `Exists` | R-ST10, R-RM5 | A rename that gives `NotFound` is skipped, another error is exit 18 |

## 9. Compiler and tool limits met

| Limit | What was done |
| --- | --- |
| Reserved word `targets` (a name in a test) | Another name |
| A tuple field `.0` of a function argument is ambiguous | A function with 4 arguments |
| A record field with a function (`prompt.answer_line`) is no method | Bind it first: `line_of = prompt.answer_line` |
| `Str.inspect(Bool.True)` gives `True` | The rows say `True` |
| `Cmd.spawn!` ends the child when the handle is dropped | Q-RM1: a launcher |
| `roc fmt` changes the layout of multi-line `match` in tuples | The reference was formatted with `roc fmt` |

## 10. Notes for the code agent

| Note | Text |
| --- | --- |
| 1 | The docs of the stubs say what each function does. The tests give the texts. The reference is deleted: write the code from the docs and the tests. `kept_path` has the field `moved` (the `back` of `Done`), so `stays` is computed after the last step |
| 2 | `Prompt.ask!` does the mode, the flag, `--yes` and the answer line. Do not write them again. Use `Prompt.ask!` with `TalonRemove.prompt` |
| 3 | Reuse: `ToolManage.entry_fate`, `SetupIo.have_of!`, `Trash.move!`, `Fx.locked!`, `ToolsJson.drop`, `TalonUpdate.current` and `del_moves`, `Setup.windows_path`, `Link.target`, `Manage.compat_of`, `Compiler.installed`, `Common.shown_fx`, `Common.failed!` |
| 4 | `ToolManage`: row 7 of `operand_ref` is for `rebuild` only (`name == "rebuild"`). `flag_check`: `"remove" => if talon [] else [...]` |
| 5 | Keep the calls in the order of the `calls.log` files. One `list_dirs!` with 2 dirs, one `tree_info!`, one `delete!` for the Talon data, one `delete!` for the last paths |
| 6 | Part 051c: `spawn_detached!` of `RealFx`: see Q-RM1. A missing program must be `NotStarted` (the L3 case `fx/sd1`). `windows!` is the stub of 051b |
| 7 | Compiler limits: warnings fail the build (a stub param starts with `_`), no `to_i64` (use `to_i64_wrap`), no effectful function in `map_try`, `keep_oks().first()` crashes, a `roc test` segfault for an Err record with a Bool field |

## 11. Red run, revert check

Red run (`research/slice-051-revert/red-run.log`, stubs state): `check` pass, `fmt` pass, `selftest` pass.

| Step | Result | Reason |
| --- | --- | --- |
| L0 | `TalonRemoveTest` 8 of 8 fail (`Roc application crashed ... todo: slice 051a`). `SetupTest` 11 fails (the stub `profiles`: `todo: slice 051a`). 9 crashes with `todo: slice 051a` in all. `ToolManageTest` 1 fails (the rows give `tln tool remove talon is not built yet`). All other `expect`s pass | the stubs, and the old text of `ToolManage` |
| L2 | `tool/rm1-default`, `rm2-options`, `rm3-windows`, `rm4-stops` fail (`[ROC CRASHED] todo: slice 051b`). 154 old cases pass, including `tm1-manage` (run 5 is `tool rm talon foo`) | the stub of `remove!` |
| L3 | `tools/rm1-remove-talon`, `tools/rm2-remove-all`, `fx/sd1-real-fx-spawn-detached` fail (`[ROC CRASHED] todo: slice 051b` for the `tools/` cases, `todo: slice 051c` for `fx/sd1`). 78 old cases pass | the stubs |

Green run (reference, `research/slice-051-revert/green-run.log`, after the review changes): check, fmt, l0, l2, l3 and selftest pass in 31 s.

Revert check (hand mutations of the reference, 10 of the most tricky behaviors, `research/slice-051-revert/mut.py`, `mutations.txt`, the logs `mut-*.log`; each ran L0 (all), L2 `tool/rm`, L3 the 2 `tools/rm*` cases, and the reference was put back):

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| m1 tools are removed in option 3 too (`removes`) | killed | killed | survived (L3 has no option 3) |
| m2 the data file `tln` is not last | survived (flow) | killed | survived (the order is inside one delete) |
| m3 `roc.old` goes over a foreign `roc` (`restores`) | killed | killed | survived |
| m4 a foreign `tln` entry is deleted | survived (flow) | killed | survived |
| m6 the compat dir stays | survived (flow) | killed | killed |
| m7 option 3 deletes the Talon data | survived (flow) | killed | survived (L3 has no option 3) |
| m9 a foreign tool entry is deleted (option 2) | survived (flow) | killed | killed |
| m10 the `.del` renames in another order (Windows) | survived (flow) | killed | survived (Windows is L2 only) |
| m11 `tools.json` is changed with no lock | survived (flow) | killed | survived |
| m12 the renamed files that stay are not reported | survived (flow) | killed | survived (Windows is L2 only) |

Review changes (the right aligned size, Q-RM2), 3 more mutations of the changed tests:

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| m13 `kept_path` ignores the move (the stale path of `link-system`) | killed | killed (`rm2-options` run 2) | survived (L3 has no link) |
| m14 the size column of the report is left aligned | killed | killed | killed |
| m15 the size column of the screen is left aligned | killed | killed | survived (L3 has no terminal) |

Each mutation is killed by at least one layer. The flow has no L0 test by design (TESTING.md 2: the flow is tested by L2 with the fake `Fx`).

## Review (manager, 2026-10-25)

Decisions of section 6, the output and `--json` proposals and the note on `http.log` accepted. Three parts (051a, 051b, 051c). Q-RM1 accepted (the Unix flow never calls `spawn_detached!`), Q-RM2 changed (the path after the move), the size column right aligned, Q-RM3 to Q-RM6 accepted. The design gaps are in one table (section 8). The reference was deleted; the status is `code`.

## Verify results (code agent, part 051a)

L0 green (`scripts/test.sh l0`). Full run: only the 4 L2 and 3 L3 cases of 051b and 051c fail (the stubs). Revert check of 051a (6 mutations, run with `scripts/test.sh l0`, each put back and compared with a copy):

| Mutation | Result |
| --- | --- |
| `removes`: the tools go in option 3 too | caught (3 `expect`s fail) |
| `restores`: ignores a foreign `roc` | caught (`TalonRemoveTest` 8) |
| `kept_path`: each moved link goes to the new path | caught (`TalonRemoveTest` 8) |
| `profile_strip`: another marker test | caught (`SetupTest` 11) |
| `zig_versions`: a file `zig-X.Y.Z` is a Zig | caught (`TalonRemoveTest` 3) |
| `operand_ref`: row 7 for each name except `update` | caught (`ToolManageTest` 1) |

## Verify results (code agent, part 051b)

`TalonRemoveFlow` has `remove!` and `unix!`. `windows!` is the stub `crash "todo: slice 051c"` (it does the steps 10 to 12 for Windows, with `Scene` and `Plan` as arguments). L2 `tool/rm1-default`, `rm2-options`, `rm4-stops` and L3 `tools/rm1-remove-talon`, `tools/rm2-remove-all` are green. Revert check (7 mutations, run with `tests/commands/run.sh tool/rm` and `tests/run.sh tools/rm1-remove-talon tools/rm2-remove-all`, each put back and compared with a copy):

| Mutation | Result |
| --- | --- |
| The data file `tln` is the first path of the last `delete!` | caught (L2 `rm1-default`, `rm2-options`) |
| A foreign `tln` entry is deleted | caught (L2 `rm2-options`) |
| Option 3 deletes the Talon data | caught (L2 `rm2-options`) |
| `roc.old` goes over a foreign `roc` | caught (L2 `rm2-options`) |
| A foreign tool entry is deleted (option 2) | caught (L2 `rm2-options`, L3 `rm2-remove-all`) |
| Option 3 removes the compilers | caught (L2 `rm2-options`) |
| `link-system` is printed at the stale path | caught (L2 `rm2-options`) |

## Verify results (code agent, part 051c)

`windows!` (steps 10 to 12 for Windows: `user_path!`, the Talon data, `windows_last!`) and `RealFx.spawn_detached!` are written. `move_back!` is shared with `unix!`. L2 `tool/rm3-windows` and L3 `fx/sd1-real-fx-spawn-detached` are green. `scripts/test.sh` exits 0 (check, fmt, l0, l1, l2, l3, selftest). Final code files: `research/slice-051-revert/code-final/` and `code-final.sha256` (`sha256sum -c` from the repo root). Revert check (5 mutations, run with `tests/commands/run.sh tool/rm3` and `tests/run.sh fx/sd1`, each put back and compared with a copy):

| Mutation | Result |
| --- | --- |
| The data file is the first `.del` rename | caught (L2 `rm3-windows`) |
| The renamed files that stay are not reported (`stuck` is empty) | caught (L2 `rm3-windows` run 2) |
| The `Path` exec runs in option 1 too (`!= TalonOnly`) | not caught: no Windows case has option 1. The same code with option 3 (`!= Default`) is caught (L2 `rm3-windows` run 2) |
| `spawn_detached!` runs the child in the foreground (no `&`) | caught (L3 `fx/sd1`) |
| `spawn_detached!` does not test that the program exists | caught (L3 `fx/sd1`) |

The Windows launcher (`cmd.exe /d /c start "" /b`) and the quoting of the script stay untested (design gap G1).

## Gap tests (test agent, 2026-10-25)

Input: the code is in (status verify), `code-final.sha256`. No test changed, no code changed. One new L2 case, 2 runs, `tests/commands/cases/tool/rm5-win-path` (generator `research/slice-051-revert/gen-gap.py`). Both runs are green against the code. TW21: only `expect/` of this case was written (`UPDATE=1 tests/commands/run.sh tool/rm5`) and read.

| Row | Layer, file | Rules | Hand mutation (code put back, `sha256sum -c code-final.sha256` all OK) |
| --- | --- | --- | --- |
| Windows option 1: no `Path` exec | L2 `tool/rm5-win-path` run 1 | R-RM8, R-ST4, R-RM3 | `windows!`: `plan.choice != TalonOnly` in place of `== WithTools` for the `Path` step: run 1 fails (the miss of 051c) |
| `powershell` not on `PATH`: exit 18, the run stops | L2 `tool/rm5-win-path` run 2 | R-EC18, R-HF11, R-ST4, R-RM5 | `user_path!`: `Err(NotStarted(_)) => Ok(scene.bin)`: run 2 fails |

Checked, no row:

| Item | Result |
| --- | --- |
| `user_path!` with `powershell` that exits with a code other than 0 (exit 18, D12) | The design fixes only the not-started case (R-EC18), and a row for that is added. The other exit code is design gap G8 (the fake gives no exit code) |
| `.del` rename with `NotFound` skipped, another error exit 18, `NotStarted` puts all renamed files in `stuck` | R-RM5: "if that fails, the renamed files stay" is pinned by `rm3-windows` run 2 (all renamed files of the run are in `stuck`). A failed rename is not in the design: design gap G9. No row: a rename error is rare and the fake gives only `Exists` |
| Delete errors (`NotFound` is no failure, another error exit 18) | `rm4-stops` pins the text and the exit code. Nothing is missing |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-051-revert/code-final.sha256` | OK (the manager changed one stale doc comment of `TalonRemoveFlow.roc` line 44 and made the hash again) |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.6, fmt 0.3, l0 7.5, l2 8.5, l3 10.0, selftest 2.9, l1 36.8 s |
| Code pass | 051a 6 of 6, 051b 7 of 7, 051c 4 of 5 mutations caught; the miss is now caught by a gap row |
| Gap tests | L2 `tool/rm5-win-path` (Windows option 1 keeps the `Path` entry; `powershell` not started gives exit 18); 2 hand mutations caught; no code bug |
| Design gaps | G1 to G9 of section 8, recorded in PLAN-P1 5b. The Windows launcher and its quoting have no test (G1). |
