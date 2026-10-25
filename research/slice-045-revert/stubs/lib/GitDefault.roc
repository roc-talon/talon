import Args
import Fx
import RocManage

## `tln roc default --git <owner/repo@ref>` (slice 045, CLI 6.6, R-R5). The body is the work of the code agent. The stub forwards to `RocManage.default!`, so the old tests pass. The contract:
##
## | Step | What |
## | --- | --- |
## | 1 | `GitRef.read({ args, bare_sha: False })`. `NotGit`: `RocManage.default!(fx, args)`. A failure: `Common.failed!`. |
## | 2 | `Roots.from_env`, `Launch.toolchains!`, keep the ids that start with `git-`, one `read_files!` of their `.talon.json`. |
## | 3 | `GitBuild.newest`: the newest build of that repo and ref. None: `GitBuild.none_installed`. |
## | 4 | `RocManage.set_default!` with the id (the full id is stored, R-R5). |
GitDefault :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| RocManage.default!(fx, args)
}
