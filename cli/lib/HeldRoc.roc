import Compiler
import Fail
import Fx
import Launch
import NoRank
import ResolveBase

## Slice 072d, 080 (R-SO14, R-SO24, R-SO23, R-SO15): the compiler of a command that runs a probe (`verify`, `probe`, `roc use`) when no rank selects one. Command code over `Fx` (TESTING.md 2.2 part C).
## A held compiler (a pin, `ROC_TOOLCHAIN`, `default-roc`, the newest installed one, `PATH`) is the answer and no call is made. With no held compiler nothing is installed (R-SO24), and `NoRank.ensure!` downloads one: the newest in the channel that resolves, else the latest. It becomes `default-roc`.
HeldRoc :: [].{

	## `Ok(id)` for a held compiler (no call). `Err(NoCompiler)`: `ResolveBase.no_rank`. `Stop` is the failure of exit code 18. `Download` runs `NoRank.ensure!` with the installed compilers of `Launch.toolchains!`.
	held! : Fx, ResolveBase.Request, ResolveBase.Loaded, Try(Str, [NoCompiler]) => Try(Str, Fail)
	held! = |fx, request, loaded, held| match held {
		Ok(id) => Ok(id)
		Err(NoCompiler) => match ResolveBase.no_rank(request, loaded) {
			Stop => Err(Compiler.failure(NoCompiler))
			Download(run) => {
				got = NoRank.ensure!(fx, { roots: request.roots, run, listed: Launch.toolchains!(fx, request.roots) })?
				Ok(got.id)
			}
		}
	}

	## Slice 072e (R-SO19, R-SO23, R-SL7): the compiler of a command that holds a nightly (`install`, `update`, `add`, `remove`, `upgrade`, `roc use`) when no compiler is selected, as an id only: no gate, no download, no default
	## (`NoRank.pick_id!`). The download is at the first probe (R-SO22), and it makes the default (R-SO24, `Start.run_picked!`). The caller calls it only when a probe will run: a run with nothing to check picks nothing.
	picked! : Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Str, Fail)
	picked! = |fx, request, loaded| match ResolveBase.no_rank(request, loaded) {
		Stop => Err(Compiler.failure(NoCompiler))
		Download(run) => {
			listed = Launch.toolchains!(fx, request.roots)
			NoRank.pick_id!(fx, { roots: request.roots, env: run.downloads.env, offline: run.downloads.offline, scope: run.scope, exclude: run.exclude, listed })
		}
	}
}
