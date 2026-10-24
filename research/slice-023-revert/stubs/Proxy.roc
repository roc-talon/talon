import Compiler
import Fail
import Fx
import Roots

## The `roc` proxy (CLI 6.2, R-PX1 to R-PX7; slice 023). `tln` runs as the proxy when its program name is `roc` (R-ST8): it selects the compiler (Resolution 13),
## writes the `.last-use` of the compiler (R-CC9) and runs it in place of itself (R-HF6: a child with the terminal of the process, the exit code passes through, R-E1).
## `Run.run!` calls `Proxy.run!` when `Proxy.is_proxy(fx.program_name!())`. This module has the pure decisions (TESTING.md 2.2, part A) and the command code.
## Slice 023 has no download: a compiler that is not installed is a refusal (R-DL8, R-DL10). The install, the prompt and `TALON_AUTO_INSTALL=yes` are slice 023b.
## The probes of the other commands still run the name `roc` (slice 023c).
##
## The calls of `run!`, in order (the L2 case `proxy/px1-flow` fixes them). `program_name!` is called by `Run.run!` first and is not in `calls.log`.
## "Early" is: `roc +<id>` is used, or `ROC_TOOLCHAIN` is set (rank 1 or 2). "Opted out" is `TALON_PROXY=0`.
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `args!`, `env_all!`. `Roots.from_env` (a failure is exit 18), `Compiler.toolchain_of` (rank 2: a failure is exit 2), `Proxy.split`, `Proxy.target`, `Proxy.opted_out`. | R-EV13, R-SO1, R-SO2, R-SO8, R-PD7, R-EV7 |
## | 2 | Not opted out: `clock!` and `Clock.now` (`TALON_NOW`: a bad value is exit 2, Q7). Opted out: no `clock!` call. | R-EV22 |
## | 3 | `cwd!` | R-PD7 |
## | 4 | With a target file (`File` or `Main`), and not (opted out and early): `Project.find_loose!` (as `find!`, but a header that does not parse is no failure: the project is returned and only the `roc:` pin is dropped, R-TF5, review of Q6) with `file: Ok(<target>)`, `start: cwd`, `home`. Any other failure is no project (the proxy does not stop, roc reports the error itself). `Main` is the file `main.roc`. | R-PD7, R-PD1, R-PD3, R-PD5, R-PD6, R-TF5 |
## | 5 | A project that has a file, and not opted out: `Known.record_recent!` of `[project.file]`, before the selection (a run that fails later records, as slice 007 D2). A failure is returned. | R-PD9, R-PD10 |
## | 6 | Early: no `read_files!`. Else one `read_files!`, the paths in this order, only those that exist as a path: the project file, the `talon.toml` (the root `talon.toml` of a workspace, else `project.toml`), `config.toml`, `.roc-version`. With no project: `config.toml` only. The `roc:` pin is `Locked.read` of the header (a failure is no pin, R-TF5). A `talon.toml`, `config.toml` or `.roc-version` that does not parse is a failure (exit 19, R-TF4, R-SC12, Q5). | R-SO3 to R-SO6, R-TF4, R-TF5 |
## | 7 | One `list_dirs!` of `<cache>/toolchains` (a missing dir is empty, `Compiler.installed`) when early, or a pin, a range, a `.roc-version` with no `talon.toml`, or `default-roc` is set. Else no call. A range and a non-empty listing: one `read_files!` of the `.talon.json` of each installed id (sorted), for `Compiler.times`. | R-SO4, R-NS1 |
## | 8 | `Proxy.select` with `path: Err(NoCompiler)`. A result `Installed` of a rank other than `Range` is the compiler. Else, and not `Proxy.in_proxy`: `Install.on_path_file!` (`path_roc!` and the calls of slice 022b), then `Proxy.select` again with the id of the file. With `TALON_IN_PROXY=1` the call is never made. | R-SO7, R-SO9, R-EV17 |
## | 9 | `NoCompiler`: `Compiler.failure(NoCompiler)` (exit 18). `NoneInRange`: `Compiler.failure(NoneInRange(<range text>))` (exit 13). `Missing`: `Proxy.missing` (exit 13). No `exec!`. | R-SO13, R-SO14, R-DL8, R-DL10 |
## | 10 | The compiler is in the listing of step 7, and not opted out: `write_atomic!` of `<cache>/toolchains/<id>/.last-use` with `Proxy.last_use(now)`. A failure is ignored (Q7). The compiler on `PATH` has no `.last-use`. | R-CC9, R-PX2 |
## | 11 | Not opted out: `canonical!` of the directory of `roots.cache` (the path of `XDG_CACHE_HOME`) and of `roots.build` (one call, in this order). | R-PX6 |
## | 12 | `exec!` of `[Proxy.program(..)] ++ <the arguments after +<id>>` with `Proxy.child_env`. `Ok(code)`: the exit code of the run is `code`. `Err(NotStarted(text))`: `Proxy.start_failed` (Q8). | R-PX2, R-PX3, R-HF6, R-E1 |
##
## A failure prints `Fail.line` on stderr, as the other commands (R-E4). The proxy has no `--json` and no flag (R-PD17).
Proxy :: [].{

	## R-ST8, R-PX1, R-HF9: is the program name the proxy? The base name (the text after the last `/` or `\`) without a `.exe` at the end is `roc`. So `roc`, `/home/u/.local/bin/roc`, `roc.exe` and `C:\talon\bin\roc.exe` are the proxy.
	## `tln`, `tln.exe`, `rocky`, `Roc` and the empty text are not.
	is_proxy : Str -> Bool
	is_proxy = |_name| Bool.False

	## R-SO1: `roc +<id> <arguments>`. When the first argument starts with `+` and has more text, `argument` is `Ok(<text after the +>)` and `rest` is the other arguments. Else `argument` is `Err(Unset)` and
	## `rest` is the arguments as they are (a `+` that is not the first argument goes to roc). The id is not checked here (Q4).
	split : List(Str) -> { argument : Try(Str, [Unset]), rest : List(Str) }
	split = |_args| crash "todo"

	## R-SO8, R-PD7: the target file of the proxy, from the arguments after `split` (the path of the file as typed, relative to the current directory).
	##
	## | Arguments | Result |
	## | --- | --- |
	## | The first argument that ends in `.roc` (also `./x/app.roc`, `/a/b.roc`) | `File(<that argument>)`. It is looked for in all the arguments, so `roc check app.roc` and `roc --opt=speed app.roc` and `roc app.roc -- x.roc` all give `app.roc`. |
	## | No such argument, no subcommand or a subcommand that compiles a file (`check`, `build`, `test`, `docs`, `deps`, `run` with no source) | `Main` (roc reads `main.roc`) |
	## | `version`, `help`, `install ...`, `run <source>` where the source is not a `.roc` file (a bundle URL, an installed name), no `.roc` argument | `NoFile` |
	##
	## Not decided (questions Q2, Q3): the subcommands that this list does not name (`fmt`, `bundle`, `repl`, ...), and an option with a separate value (`--replace-dep OLD NEW`, `-j 4`). The tests have no row for them.
	target : List(Str) -> [File(Str), Main, NoFile]
	target = |_args| crash "todo"

	## R-PX7, R-EV7: `TALON_PROXY=0`. Any other value, and no variable, is false.
	opted_out : List((Str, Str)) -> Bool
	opted_out = |_env| crash "todo"

	## R-EV17, R-SO9: `TALON_IN_PROXY=1` is set. Any other value, and no variable, is false. A proxy that sees it does not look at `PATH` (rank 7).
	in_proxy : List((Str, Str)) -> Bool
	in_proxy = |_env| crash "todo"

	## The rank that selected the compiler: `Compiler.Rank` with the header pin (rank 3) between `Env` and `Range`.
	Rank : [Argument, Env, Pin, Range, VersionFile, Default, Path]

	## R-SO1 to R-SO7, R-SO10, R-SO12 to R-SO14, R-CV1 (the ranks of the proxy). `pin` is the `roc:` entry of the header of the target file. `facts` are the facts of `Compiler.select`: `argument` is rank 1, `env` is rank 2.
	## The first rank that has a value wins, in the order 1, 2, 3, 4, 5, 6, 7. Ranks 1, 2, 4, 5, 6, 7 are `Compiler.select`. Rank 3 (the pin) is the id of the pin, with no `nightly` switch and no range
	## (R-SO19: the proxy has no gate). A pin names an installed compiler when `Pin.same_id` holds for one id of `facts.installed` (the other tag form of one nightly, R-CV1): `id` is then the installed id.
	## It is also installed when it is the id of `facts.path` (R-SO10). Else `state` is `Missing` (the pin is the id as it is). `NoneInRange` and `NoCompiler` are as in `Compiler.select`.
	select : { pin : Try(Str, [NoPin]), facts : Compiler.Facts } -> Try({ id : Str, rank : Proxy.Rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])
	select = |_run| crash "todo"

	## R-PX2, R-SO10: the program that runs for the selected `id`. An id in `installed` is `<cache>/toolchains/<id>/roc` (`Roots.item` with `ToolchainRoc`): the managed copy wins when the `roc` on `PATH` has the same id.
	## Else the file of `path` (the path as `PATH` wrote it).
	program : { roots : Roots, id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Str
	program = |_run| crash "todo"

	## R-PX6, R-EV17, R-PX7: the variables that the proxy sets for the compiler. In this order: `XDG_CACHE_HOME` and `ROC_CACHE_DIR`, then `TALON_IN_PROXY=1`. `xdg` is the path of `XDG_CACHE_HOME` (the directory of
	## `Roots.cache`), `build` is `Roots.build`. `canonical` is what `Fx.canonical!` gave for the path. A path that does not exist (`Err(Failed)`) is the path with its `.` and `..` parts removed (`Text.resolve`), so a `..` never reaches roc (Q15 of the design).
	## Opted out (R-PX7): only `TALON_IN_PROXY=1` (Q1: the cache variables are extra work).
	child_env : { opted_out : Bool, xdg : { path : Str, canonical : Try(Str, [Failed]) }, build : { path : Str, canonical : Try(Str, [Failed]) } } -> List((Str, Str))
	child_env = |_facts| crash "todo"

	## R-CC9: the text of `.last-use`: the time of Talon as `Clock.format_utc` and a line end, for example `2026-10-22T12:00:00Z\n`. (The format is a proposal, TW24.)
	last_use : U64 -> Str
	last_use = |_now| crash "todo"

	## R-DL8, R-DL10, R-NI5: the refusal for a selected id that is not installed. Kind `Consent` (exit 13), before the compiler runs. The text names `tln roc install <id>` and `TALON_AUTO_INSTALL=yes`
	## (a proposal, TW24): `the compiler <id> (<source>) is not installed. Run: tln roc install <id>, or set TALON_AUTO_INSTALL=yes.` `<source>` is the rank: `roc +<id>` (`Argument`), `ROC_TOOLCHAIN` (`Env`),
	## `the roc: entry of the header` (`Pin`), `.roc-version` (`VersionFile`), `the global default` (`Default`). `Range` and `Path` never give `Missing`; the text for them is `the compiler range`
	## and `the roc on PATH`.
	missing : { id : Str, rank : Proxy.Rank } -> Fail
	missing = |_run| crash "todo"

	## R-E1: the child did not start. Kind `Environment` (exit 18), the text (a proposal, TW24): `cannot run <program>: <text>`.
	start_failed : { program : Str, text : Str } -> Fail
	start_failed = |_run| crash "todo"

	## The proxy: steps 1 to 12 of the table above. It gives the exit code of the child, or the code of a failure.
	run! : Fx => I32
	run! = |_fx| crash "todo"
}
