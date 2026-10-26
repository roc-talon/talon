import Args
import Fx

## The command `tln tool remove talon [--dry-run] [--remove-tools | --keep-all]` (slice 051, CLI 6.5 "Remove Talon": R-S5, R-RM1 to R-RM10, R-NI10, R-NR3, R-ST4, R-ST6, R-ST10, R-ST11, R-CC6, R-CC10). Direct style over `Fx` (TESTING.md 2.2 part C): `TalonRemove` decides,
## this module orders the calls. `Run.run!` calls `remove!` for `["tool", "remove"]` when `TalonRemove.is_target(args)`, else `ToolManageFlow.remove!`. The calls, in order (the L2 cases `tool/rm1-default` to `rm4-stops` and the L3 cases `tools/rm1-remove-talon`, `tools/rm2-remove-all` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolManage.read(args)`, then `TalonRemove.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM16, R-FL12 |
## | 2 | `env_all!`, `Roots.from_env`, `platform!`, `Setup.bin_dir`, one `read_files!` of `tools.json` (the tools and the entry `talon`, `TalonUpdate.current` for the version), one `list_dirs!` with 2 dirs: `<cache>/toolchains`, then the bin dir. | R-T4, R-IS6 |
## | 3 | One `read_files!` of the `.talon.json` of each compiler, in the order of the ids (no call for no compiler), for the compat ids and the links. | R-RM9, R-RM6 |
## | 4 | One `tree_info!` with `TalonRemove.asks`, then `TalonRemove.parts`: the 4 groups with their sizes. | R-RM4, R-NR2 |
## | 5 | `--dry-run`: the outcome `DryRun` with the choice of the flag (option 1 with no flag). No prompt, no more call. | R-RM4 |
## | 6 | `Mode.from_env` and `Prompt.ask!` with `TalonRemove.prompt` (the flag of `Plan.flag`, `yes`, `quiet`). `Prompt.ask!` calls `tty!` when the mode is `NeedsTty` and `ask!` for a person. With no person the answer is option 1 and the answer line goes to stderr (R-NM6). Option 4: the outcome `Cancelled`, exit 0, no more call. | R-NI10, R-RM3, R-NR3 |
## | 7 | The checks, before the first change: `sha256_file!` of the file `tln` of the data bin dir, then `SetupIo.have_of!` for the entries `tln` and `roc` of the bin dir (one `sha256_file!` for each entry that is there), `ToolManage.entry_fate` for each. Option 2: for each tool `sha256_file!` of its file and `have_of!` for its entry, `entry_fate`. | R-ST11, R-ST6 |
## | 8 | Compilers (options 1 and 2): for each compiler id in byte order, then each Zig: `Fx.locked!` (`Wait`) on `Roots.item(Toolchain(id))` (`Zig(v)`) and in it `Trash.move!` (`random!`, `rename!` to the trash name, one `delete!` of the trash dir and the compat dir). | R-RM9, R-CC10 |
## | 9 | `Fx.locked!` on `tools.json` (`Wait`, R-CC6): `read_files!` again. Option 2: one `delete!` of the entry and the file of each tool whose entry is Talon's (only the file when the entry is gone or not Talon's), then `tools.json`: the tool files first, the manifest last. Options 1 and 3: `write_atomic!` of `tools.json` with no `talon` entry (`ToolsJson.drop`), when it had one. | R-RM7, R-RM8, R-CC6, R-ST6 |
## | 10 | Option 2: the `PATH` entry. Linux and macOS: one `read_files!` of the 3 profiles (`Setup.profiles`), then one `write_atomic!` with the profiles that had the marker line (`Setup.profile_strip`). Windows: one `exec!` of `Setup.windows_path` with `Remove`. | R-RM8, R-ST4, R-HF11 |
## | 11 | Talon data (options 1 and 2): one `delete!` of `<cache>/talon`, `config.toml`, `share.json`. | R-RM10 |
## | 12 | Talon, last. Linux and macOS: `delete!` of the entry `roc` (when it is Talon's), `rename!` of `roc.old` to `roc` (`TalonRemove.restores`), then `delete!` of the entry `tln` (when it is Talon's) and the file `tln` of the data bin dir, which is the last path. Windows: one `random!`, `rename!` of each file to its `.del` name (`TalonUpdate.del_moves`: `roc.exe`, `tln.exe`, then the data file), `rename!` of `roc.old.exe` to `roc.exe`, then `spawn_detached!` of `TalonRemove.cleanup_command`. | R-RM5, R-RM6, R-ST10 |
## | 13 | The warnings on stderr, the lines on stdout (`--quiet` hides them, `--json` moves them to stderr), with `--json` the envelope with `TalonRemove.data`. | R-OUT2, R-J1 to R-J4 |
## Part 051b (this module): the command code (the order of the removal, the prompt, the checks, `unix!`). `windows!` is part 051c: in 051b it is `crash "todo: slice 051c"` (with `RealFx.spawn_detached!`). Part 051a (`TalonRemove`, `Setup.profiles`, `Setup.profile_strip`, `ToolManage`) comes first.
TalonRemoveFlow :: [].{

	## `tln tool remove talon`.
	remove! : Fx, Args => I32
	remove! = |_fx, _args| crash "todo: slice 051b"
}
