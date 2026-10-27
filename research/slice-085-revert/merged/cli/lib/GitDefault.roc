import Args
import Common
import Fail
import Fx
import GitBuild
import GitRef
import Launch
import RocManage
import Roots

## `tln roc default --git <owner/repo@ref>` (slice 045, CLI 6.6, R-R5). A word that is not a git ref goes to `RocManage.default!`. The contract:
##
## | Step | What |
## | --- | --- |
## | 1 | `GitRef.read({ args, bare_sha: False })`. `NotGit`: `RocManage.default!(fx, args)`. A failure: `Common.failed!`. |
## | 2 | `Roots.from_env`, `Launch.toolchains!`, keep the ids that start with `git-`, one `read_files!` of their `.talon.json`. |
## | 3 | `GitBuild.newest`: the newest build of that repo and ref. None: `GitBuild.none_installed`. |
## | 4 | `RocManage.set_default!` with the id (the full id is stored, R-R5). |
GitDefault :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match GitRef.read({ args, bare_sha: Bool.False }) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(Err(NotGit)) => RocManage.default!(fx, args)
		Ok(Ok(source)) => match newest!(fx, source) {
			Ok(run) => RocManage.set_default!(fx, args, run)
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# Steps 2 and 3: the newest installed build of the repo and the ref. One `read_files!` of the `.talon.json` of each `git-*` id.
newest! : Fx, GitRef.Source => Try({ roots : Roots, id : Str }, Fail)
newest! = |fx, source| {
	roots = Roots.from_env(fx.env_all!())?
	ids = Launch.toolchains!(fx, roots).keep_if(|id| id.starts_with("git-"))
	metas = if ids.is_empty() [] else fx.read_files!(ids.map(|id| Roots.item(roots, ToolchainMeta(id))))
	rows = ids.map2(metas, |id, text| { id, text })
	match GitBuild.newest({ source, rows }) {
		Ok(id) => Ok({ roots, id })
		Err(None) => Err(GitBuild.none_installed(source))
	}
}
