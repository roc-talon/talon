import Args
import Fail
import Fx
import Ref
import ToolBuild
import ToolsJson

## The commands `tln tool list` and `tln tool remove` (slice 048, CLI 6.4: R-CM16, R-CM19, R-T4, R-T8, R-B6, R-ST6, R-ST11, R-SC3, R-CC1, R-CC6, R-PT12). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolManage` decides, this module orders the calls. `Run.run!` calls `list!` for the
## command `["tool", "list"]` and `remove!` for `["tool", "remove"]`. `machine!` is also the first step of `ToolUpdateFlow`. The calls, in order (the L2 case `tool/tm1-manage` and the L3 case `tools/ti3-tool-git` fix them):
##
## | Step | Command | Does | Rule |
## | --- | --- | --- | --- |
## | 1 | both | `ToolManage.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM16, R-CM19 |
## | 2 | list | `env_all!`, `Roots.from_env`, one `read_files!` of `tools.json` (a missing file is no tool), `ToolsJson.manifest`. No `clock!`, no `platform!`. | R-T4 |
## | 3 | list | The table (`ToolManage.ls_report`) on stdout, or with `--json` the envelope with `ToolManage.ls_data`. `--quiet` hides nothing (the table is the answer). | R-T8, R-J1 to R-J4 |
## | 4 | remove | `env_all!`, `Roots.from_env`, `platform!` (`Setup.bin_dir`, the file name), one `read_files!` of `tools.json`, `ToolsJson.manifest`, `Lookup.find` (scope `Tool`) and `ToolManage.pick`. A failure prints its block, then the failure. No request, no `clock!`, no project file (R-PT12). | R-SC3, R-PT12 |
## | 5 | remove | The lock of `tools.json` (`Fx.locked!` on `Roots.item(ToolsJson)`, `Wait`, R-CC3) for all the changes (R-CC6): `read_files!` and `ToolsJson.manifest` again (the tool must still be there), `list_dirs!` of the bin dir, `SetupIo.have_of!` (one `sha256_file!` of the entry), `sha256_file!` of the binary of the data bin dir, `ToolManage.entry_fate`. | R-CC6, R-ST11 |
## | 6 | remove | Still under the lock: one `delete!` of `[<bin dir entry>, <data bin file>]` for `Remove`, or of `[<data bin file>]` for `Gone` and `Keep` (a path that is not there is no failure). Then `write_atomic!` of `tools.json` (`ToolsJson.drop`). The files go first and the manifest last (a stop between gives a tool in `tools.json` with no files, and `tool remove` can run again). Nothing is written in `talon/x/` (R-B6). | R-B6, R-ST6, R-CC1 |
## | 7 | remove | `Keep`: the line of `ToolManage.kept_warning` on stderr. The answer `ToolManage.remove_report` on stdout (`--quiet` hides it), or with `--json` the text on stderr and the envelope with `ToolManage.remove_data` on stdout. | R-OUT2, R-J1 to R-J4 |
ToolManageFlow :: [].{

	## `tln tool list`.
	list! : Fx, Args => I32
	list! = |_fx, _args| crash "todo: slice 048"

	## `tln tool remove`.
	remove! : Fx, Args => I32
	remove! = |_fx, _args| crash "todo: slice 048"

	## The machine and the manifest, for the commands that go through the tools (`remove` and `ToolUpdateFlow`): the environment, the roots, the network settings, the time, the system (`platform!`), the bin dir, the build target, `config.toml` (`min-release-age`, the probe timeout)
	## and the tools of `tools.json`. `Facts` is the base of `ToolBuild.Facts`: `name`, `key` and `file` are empty, a tool command sets them for each tool.
	machine! : Fx => Try({ facts : ToolBuild.Facts, tools : List(ToolsJson.Tool) }, Fail)
	machine! = |_fx| crash "todo: slice 048"

	## The facts of one tool: the base with the name, the key and the file name of the tool (R-ST15).
	facts_of : ToolBuild.Facts, ToolsJson.Tool -> ToolBuild.Facts
	facts_of = |_base, _tool| crash "todo: slice 048"

	## The tool that the operand names (R-SC3): `Lookup.find` in the scope `Tool`, then `ToolManage.pick`. A failure of the lookup prints its block first.
	find! : Fx, { ref : Ref, tools : List(ToolsJson.Tool) } => Try(ToolsJson.Tool, Fail)
	find! = |_fx, _run| crash "todo: slice 048"
}
