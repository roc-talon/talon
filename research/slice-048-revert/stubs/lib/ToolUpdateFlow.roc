import Args
import Fx

## The commands `tln tool update [tool]` and `tln tool rebuild [tool]` (slice 048, CLI 6.4: R-T7, R-T24, R-T25, R-T5, R-T6, R-T9, R-T26, R-DL1 to R-DL5, R-CC6, R-CC2, R-B6). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolUpdate` decides, `ToolBuild` builds and installs under the lock of `tools.json` (slice 046), the source steps of `ToolFlow` and `ToolGitFlow` are reused.
## `Run.run!` calls `update!` for `["tool", "update"]` and `rebuild!` for `["tool", "rebuild"]`. No operand: all tools of `tools.json`, in the order of the file. The calls, in order (the L2 cases `tool/tu1-update` and `tool/tr1-rebuild` and the L3 case `tools/ti3-tool-git` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolManage.read(args)` (a failure: `Common.failed!`, no `Fx` call). `ToolManageFlow.machine!` (the machine, `tools.json`, `config.toml`: one `clock!`, one `platform!`). One operand: `ToolManageFlow.find!` (the tool must be installed). No tool: the line of `ToolManage.ls_report`, exit 0. | R-T7, R-T25, R-SC3 |
## | 2 | Plan each tool, in order (no build yet). `update`, `ToolUpdate.way`: `Commit`: no call (`Pinned`). `Release`: `ToolFlow.release_list_for!`, `ToolInstall.pick` with `latest` and `ToolInstall.reuse`: `Keep` is `UpToDate`; else the notes, `entry_verdict!`, `first_app_for!` (the bundle of the newest release that is an app), `platform_for!`. `Branch`: `ToolGitFlow.head!` (the commit now), `ToolUpdate.moved`: `Same` is `UpToDate`; else `entry_verdict!`, `check_curl!`, `source!`, `platform_for!`. | R-T24, R-T9, R-T26 |
## | 2b | `rebuild`, `ToolUpdate.origin`: a release: `entry_verdict!`, `bundle_for!` (the bundle of the URL of the manifest), `platform_for!`. A git tool: `entry_verdict!`, `check_curl!`, `source!` with the commit of the manifest (no request for the commit), `platform_for!`. The compiler is the one of the manifest (R-T5). | R-T7, R-T5 |
## | 3 | The downloads of the command: `Launch.toolchains!`, `ToolUpdate.downloads` (the pins of the tools to build that no installed compiler covers). Not empty: one decision for the command (`Mode.from_env`, one `tty!` if `NeedsTty`, `ToolUpdate.want`). `Download`: `RocInstall.fetch_optional!` for each id. `Ask`: `RocInstall.offer!` for each id, one `Prompt.ask!` with `ToolUpdate.prompt`, then `RocInstall.install_offer!` for each. `Stop`: the failure (exit 13), nothing was changed. | R-T25, R-DL1 to R-DL5 |
## | 4 | For each tool in order: nothing to build: the line. Else `ToolBuild.finish!` with the compiler (no evidence, no option 2: the header pin of an update, the recorded compiler of a rebuild). The line of the tool is printed when it is done. A failure ends the command (question Q-U2): the tools done before stay changed. | R-T7, R-CC6, R-B6 |
## | 5 | `delete!` of the scratch dirs of the git sources (also after a failure, R-CC2). `--json`: one envelope with `ToolUpdate.data` (the text goes to stderr). | R-J1 to R-J4 |
ToolUpdateFlow :: [].{

	## `tln tool update`.
	update! : Fx, Args => I32
	update! = |_fx, _args| crash "todo: slice 048"

	## `tln tool rebuild`.
	rebuild! : Fx, Args => I32
	rebuild! = |_fx, _args| crash "todo: slice 048"
}
