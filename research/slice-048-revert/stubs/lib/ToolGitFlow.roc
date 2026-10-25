import Args
import Fail
import Fx
import GitRef
import Net
import ToolBuild

## The command `tln tool install --git owner/app@ref [--path <dir>]` and `tln tool install owner/app@<sha>` (slice 048, CLI 6.4: R-T23, R-T26, R-T27, R-T28, R-T2, R-SL8, R-SL10, R-SE12, R-DA3, R-CC6). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolGit` decides, `GitRef` gives the commit requests (slice 045), `ToolBuild`
## builds and installs (the lock of `tools.json`, slice 046). `Run.run!` calls `run!` for the command `["tool", "install"]`: a line that is not a git source (`ToolGit.read` gives `NotGit`) goes to `ToolFlow.run!`, with no other call. `head!`, `check_curl!` and `source!` are also used by `ToolUpdateFlow`.
## The calls, in order (the L2 case `tool/tg1-git` and the L3 case `tools/ti3-tool-git` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolGit.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). `NotGit`: `ToolFlow.run!(fx, args)`. | R-T23, R-SL10, R-FL12 |
## | 2 | `ToolFlow.gather_for!` (steps 2 to 5 of `ToolFlow`: the environment, the roots, the network settings, one `clock!`, `platform!`, `tools.json`, `config.toml`, the lookup of the name in `tools.json`, the key, the clash). | R-T28, R-SC3, R-LY2 |
## | 3 | `--offline`: `GitRef.offline_failure` (exit 15), no request. | R-DI12 |
## | 4 | One `http_get!` of `GitRef.commit_url` with `GitRef.commit_headers({ token })`, `GitRef.commit_of`. The token is resolved as in `GitInstall` (`Net.token`, and for `AskGh` one `programs!(["gh"])` before the request). | R-T23, R-R3, R-RG3 |
## | 5 | `ToolGit.reuse`: `Keep` ends the command (no build): the answer `Present`. | R-T26 |
## | 6 | `ToolBuild.entry_verdict!` (the check of the bin dir entry before the download, as `ToolFlow` step 7b). | R-ST6, R-ST11 |
## | 7 | `check_curl!`: `programs!(["curl", "wget"])`, `Download.choose`. Wget: `ToolGit.needs_curl` (exit 18). | R-DA3, R-SE12 |
## | 8 | `source!`: `random!` (the hex of the temp dir), `ToolGit.layout`, `make_dirs!` of `src`, the curl job to the archive (`GitRef.archive_url`, limit 8), the tar job (`Toolchain.tar_command`, limit 1), `delete!` of the archive, one `read_files!` of `<dir>/main.roc`, `Release.read` (an app), `Locked.read`. | R-T23, R-R3, R-R7, R-SE12 |
## | 9 | `ToolFlow.platform_for!` (R-T2), then `ToolFlow.compile_for!` (the compiler choice and the build of slice 047, the lock and the install of `ToolBuild`: the source of the tool in `tools.json` is `Git({ commit, ref })` and `path`). | R-T2, R-T11 to R-T21, R-T3, R-T4 |
## | 10 | `delete!` of the temp dir of `source!`, after a success and after a failure (R-CC2). The answer: `ToolInstall.report` with the version text `ToolGit.source_text`, or with `--json` the text on stderr and `ToolGit.data` on stdout. | R-J1 to R-J4, R-OUT2 |
ToolGitFlow :: [].{

	## `tln tool install` with a git source.
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 048"

	## Step 4 (R-T23, R-R3, R-RG3): the commit of the ref now. The token is resolved before the request, as `GitInstall` does.
	head! : Fx, Net.Settings, GitRef.Source, U64 => Try(Str, Fail)
	head! = |_fx, _net, _source, _now| crash "todo: slice 048"

	## Step 7 (R-DA3, R-SE12): only curl refuses a redirect to http (a source archive has no published hash).
	check_curl! : Fx, Net.Settings => Try({}, Fail)
	check_curl! = |_fx, _net| crash "todo: slice 048"

	## Step 8 (R-T23, R-R3, R-R7, R-SE12): the source of the commit in a temp dir, and the app that `main.roc` of the app dir is. `temp` is the dir that the caller deletes (R-CC2). A failure after the dir is made deletes it here.
	source! : Fx, ToolBuild.Facts, { source : GitRef.Source, sha : Str, path : Try(Str, [None]) } => Try({ bundle : ToolBuild.Bundle, temp : Str }, Fail)
	source! = |_fx, _facts, _want| crash "todo: slice 048"
}
