import Fail
import Fx
import Intent
import Roots

## The base of a relative step (slice 026, R-SL7, R-PD16, R-PD7, R-NS3): the compiler that Resolution 13 selects for the target file `main.roc` of the current directory, as the `roc` proxy would select it
## for `roc` with no argument (`Proxy.go!`, steps 3 to 8 of its table), with these differences: no download, no `.last-use`, no record in `projects.json` (a `tln roc` command uses no project, R-PD16), no `exec!`.
## `Nightlies.pick` takes the result as its `base` (`Nightlies.PickError` has `NoBase` and `BaseNotListed`).
## The body is the work of the code agent. It cannot be in `Proxy` (`Proxy` imports `RocInstall`, and `RocInstall.offer!` calls it): move what the two share into this module, as `Common` and `Start` were made in slice 025.
Base :: [].{

	## `env` is the environment, `roots` the cache dirs, `installed` the ids of `<cache>/toolchains` (the caller read them: `Compiler.installed`), `config` is `config.toml` (the caller read it: `default-roc`, `nightly`,
	## `min-release-age`). The result is the id of the selected compiler, also when it is not installed (the base is a position in the list, not a compiler to run). The ranks, as for the proxy:
	##
	## | Rank | Source | Base |
	## | --- | --- | --- |
	## | 2 | `ROC_TOOLCHAIN` (a failure of `Compiler.toolchain_of` is its failure, exit 2) | the id. No file is read. |
	## | 3 | The `roc:` pin of the header of `main.roc` | the pin, or the installed id of the other tag form (`Proxy.select`) |
	## | 4 | `[toolchain] roc` of the `talon.toml` of that file | the newest installed compiler in the range |
	## | 5 | `.roc-version`, when there is no `talon.toml` | the id |
	## | 6 | `default-roc` of `config.toml` | the id |
	## | 7 | The `roc` on `PATH` (`Install.on_path_file!`) | its id |
	## | none | | `Err(None)` (`NoBase`, R-SO14) |
	##
	## The calls, in order (the L2 cases `roc/bs1-base` and `roc/bs2-no-pin` fix them). "Early" is `ROC_TOOLCHAIN` set (rank 2): the ranks 3 to 7 are not looked at.
	##
	## | Step | Does | Rule |
	## | --- | --- | --- |
	## | 1 | `Compiler.toolchain_of(env)` (no call; a failure is exit 2) | R-SO2 |
	## | 2 | Not early: `cwd!`, then `Project.find_loose!` with `file: Ok("main.roc")`, `start: <cwd>`, `home` (the calls of `Project.find!`: `canonical!` of main.roc, one `list_dirs!` for each dir of the walk, the `talon.toml` files, one `read_files!` of main.roc). A search that fails, or a `main.roc` that does not exist, is no project (no failure). | R-PD7, R-PD1, R-PD3, R-PD5, R-PD6 |
	## | 3 | Not early, and a project file: one `read_files!` with the project file, the `talon.toml` (the root one of a workspace, else the one of the project), the `.roc-version`, those that exist as a path. The pin is `Locked.read` of the header (a header that does not parse is no pin: R-TF5). A `talon.toml` or `.roc-version` that does not parse is a failure (exit 19). | R-SO3 to R-SO5, R-TF4, R-TF5 |
	## | 4 | A range and a non-empty `installed`: one `read_files!` of the `.talon.json` of each installed id (`Compiler.times`) | R-SO4, R-NS1 |
	## | 5 | `Proxy.select`-like choice with `path: Err(NoCompiler)`. A result that is installed and has a rank other than 4 is the base. Else, and not `TALON_IN_PROXY=1`: `Install.on_path_file!` (`path_roc!` and the calls of slice 022b), then the choice again with the id of that file. | R-SO7, R-SO9, R-SO10, R-EV17 |
	## | 6 | `Ok(id)`: the base. `NoCompiler` and `NoneInRange`: `Err(None)`. | R-SO14 |
	##
	## A range with no installed compiler in it (`NoneInRange`) has no base: `Err(None)` (question Q3 of the slice file). A file `main.roc` that does not exist or whose header does not parse is no target file: the ranks 3 and 4 and 5 do not apply (as in the proxy, R-TF5).
	selected! : Fx, { env : List((Str, Str)), roots : Roots, installed : List(Str), config : Intent.Config } => Try(Try(Str, [None]), Fail)
	selected! = |_fx, _facts| crash "todo"
}
