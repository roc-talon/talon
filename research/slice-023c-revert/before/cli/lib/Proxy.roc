import Answer
import Clock
import Compiler
import Consent
import Exit
import Fail
import Fx
import Install
import Intent
import Known
import Locked
import Mode
import Out
import Pin
import Project
import Prompt
import RocInstall
import Roots
import Text

## The `roc` proxy (CLI 6.2, R-PX1 to R-PX7; slice 023). `tln` runs as the proxy when its program name is `roc` (R-ST8): it selects the compiler (Resolution 13),
## writes the `.last-use` of the compiler (R-CC9) and runs it in place of itself (R-HF6: a child with the terminal of the process, the exit code passes through, R-E1).
## `Run.run!` calls `Proxy.run!` when `Proxy.is_proxy(fx.program_name!())`. This module has the pure decisions (TESTING.md 2.2, part A) and the command code.
## Slice 023 has no download: a compiler that is not installed is a refusal (R-DL8, R-DL10). Slice 023b adds the install (R-PX4): the prompt, `TALON_AUTO_INSTALL` and the lock (steps 9a to 9f below).
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
## Slice 023b, the install of a compiler that is not installed (R-PX4, R-DL1, R-DL8 to R-DL10, R-NI5, R-CC4). It replaces the refusal of step 9 for `Missing`. `NoCompiler` and `NoneInRange` stay as in step 9
## (R-SO13 is slice 025). The calls, in order (the L2 case `proxy/px2-install` fixes them). The steps 9a to 9d make no `Fx` call except `tty!` in 9b. `<auto>` is `Proxy.auto_install`.
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 9a | `Proxy.auto_install(env)`. `Mode.from_env({ env, json: Bool.False })`. | R-EV6 |
## | 9b | `Proxy.want({ id, auto, mode })`. `NeedTty`: one `tty!` call, `Mode.with_tty`, then `Proxy.want` again. `Refuse`: the failure `Proxy.missing` (exit 13), no more calls. | R-DL8, R-DL9, R-DL10, R-NI5 |
## | 9c | `RocInstall.offer!(fx, { id, env, offline: Bool.False })` (the steps 2 to 6 of `tln roc install`: the list, the pick, the digest). A failure is returned. `Present`: go to 9f. | R-CC4 step 1, R-CV4 |
## | 9d | `Install`: `Prompt.ask!` with `Consent.proxy_download({ id, source, size })`, `flag: Ok(Yes)` (the answer line goes to stderr, R-NM6). `Ask`: the same with `flag: Err(NoFlag)`, the mode of 9b (`Interactive`, so one `ask!` call). The answer `No`: `Consent.roc_install_declined(id)` (exit 13). No lock is taken yet (R-CC3 point 5, R-CC4 step 2). | R-DL1, R-DL3, R-DL5, R-NI5 |
## | 9e | `RocInstall.install_offer!(fx, offer)` (the steps 8 to 12 of `tln roc install`: the lock, the download, the default). A failure is returned (its kind gives the exit code). | R-CC4, R-SO15 |
## | 9f | The compiler is the `id` of the offer or of the result (the id of the list: the other tag form of a pin gives the id of the list). Steps 10 to 12 go on with it as an installed compiler: `.last-use` is written, `exec!` runs it. | R-CC9, R-PX2 |
##
## Where the output goes (slice 023 D10: the stdout and stderr of the proxy belong to roc): stdout gets nothing from the install, never. stderr gets only these lines: the prompt text (`Fx.ask!`), the answer line (R-NM6), the warnings of `config.toml` that `offer!` prints (D7 of slice 021), `waiting for another tln: <id>` (R-CC5)
## and the line of a failure (R-E4). No progress line (R-DA6 is not built). No `installed ...` line, no `... is now the default compiler` line, no compat warning (Q3).
##
## A failure prints `Fail.line` on stderr, as the other commands (R-E4). The proxy has no `--json` and no flag (R-PD17).
Proxy :: [].{

	## R-ST8, R-PX1, R-HF9: is the program name the proxy? The base name (the text after the last `/` or `\`) without a `.exe` at the end is `roc`. So `roc`, `/home/u/.local/bin/roc`, `roc.exe` and `C:\talon\bin\roc.exe` are the proxy.
	## `tln`, `tln.exe`, `rocky`, `Roc` and the empty text are not.
	is_proxy : Str -> Bool
	is_proxy = |name| {
		segment = Text.last_segment(name)
		base = segment.split_on("\\").last() ?? segment
		base == "roc" or base == "roc.exe"
	}

	## R-SO1: `roc +<id> <arguments>`. When the first argument starts with `+` and has more text, `argument` is `Ok(<text after the +>)` and `rest` is the other arguments. Else `argument` is `Err(Unset)` and
	## `rest` is the arguments as they are (a `+` that is not the first argument goes to roc). The id is not checked here (Q4).
	split : List(Str) -> { argument : Try(Str, [Unset]), rest : List(Str) }
	split = |args| match args {
		[first, .. as rest] if first.starts_with("+") and first != "+" => { argument: Ok(first.drop_prefix("+")), rest }
		_ => { argument: Err(Unset), rest: args }
	}

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
	target = |args| {
		own = match args.split_first("--") {
			Ok(parts) => parts.before
			Err(NotFound) => args
		}
		match own.find_first(is_source_file) {
			Ok(file) => File(file)
			Err(_) => if no_file_command(own) NoFile else Main
		}
	}

	## R-PX7, R-EV7: `TALON_PROXY=0`. Any other value, and no variable, is false.
	opted_out : List((Str, Str)) -> Bool
	opted_out = |env| env.contains(("TALON_PROXY", "0"))

	## R-EV17, R-SO9: `TALON_IN_PROXY=1` is set. Any other value, and no variable, is false. A proxy that sees it does not look at `PATH` (rank 7).
	in_proxy : List((Str, Str)) -> Bool
	in_proxy = |env| env.contains(("TALON_IN_PROXY", "1"))

	## The rank that selected the compiler: `Compiler.Rank` with the header pin (rank 3) between `Env` and `Range`.
	Rank : [Argument, Env, Pin, Range, VersionFile, Default, Path]

	## R-SO1 to R-SO7, R-SO10, R-SO12 to R-SO14, R-CV1 (the ranks of the proxy). `pin` is the `roc:` entry of the header of the target file. `facts` are the facts of `Compiler.select`: `argument` is rank 1, `env` is rank 2.
	## The first rank that has a value wins, in the order 1, 2, 3, 4, 5, 6, 7. Ranks 1, 2, 4, 5, 6, 7 are `Compiler.select`. Rank 3 (the pin) is the id of the pin, with no `nightly` switch and no range
	## (R-SO19: the proxy has no gate). A pin names an installed compiler when `Pin.same_id` holds for one id of `facts.installed` (the other tag form of one nightly, R-CV1): `id` is then the installed id.
	## It is also installed when it is the id of `facts.path` (R-SO10). Else `state` is `Missing` (the pin is the id as it is). `NoneInRange` and `NoCompiler` are as in `Compiler.select`.
	select : { pin : Try(Str, [NoPin]), facts : Compiler.Facts } -> Try({ id : Str, rank : Proxy.Rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])
	select = |run| match (run.facts.argument, run.facts.env, run.pin) {
		(Err(Unset), Err(Unset), Ok(pin)) => Ok(pinned(pin, run.facts))
		_ => Compiler.select(run.facts).map_ok(|sel| { id: sel.id, rank: proxy_rank(sel.rank), state: sel.state })
	}

	## R-PX2, R-SO10: the program that runs for the selected `id`. An id in `installed` is `<cache>/toolchains/<id>/roc` (`Roots.item` with `ToolchainRoc`): the managed copy wins when the `roc` on `PATH` has the same id.
	## Else the file of `path` (the path as `PATH` wrote it).
	program : { roots : Roots, id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Str
	program = |run| match run.path {
		Ok(found) if found.id == run.id and !run.installed.contains(run.id) => found.path
		_ => Roots.item(run.roots, ToolchainRoc(run.id))
	}

	## R-PX6, R-EV17, R-PX7: the variables that the proxy sets for the compiler. In this order: `XDG_CACHE_HOME` and `ROC_CACHE_DIR`, then `TALON_IN_PROXY=1`. `xdg` is the path of `XDG_CACHE_HOME` (the directory of
	## `Roots.cache`), `build` is `Roots.build`. `canonical` is what `Fx.canonical!` gave for the path. A path that does not exist (`Err(Failed)`) is the path with its `.` and `..` parts removed (`Text.resolve`), so a `..` never reaches roc (Q15 of the design).
	## Opted out (R-PX7): only `TALON_IN_PROXY=1` (Q1: the cache variables are extra work).
	child_env : { opted_out : Bool, xdg : { path : Str, canonical : Try(Str, [Failed]) }, build : { path : Str, canonical : Try(Str, [Failed]) } } -> List((Str, Str))
	child_env = |facts| {
		inside = ("TALON_IN_PROXY", "1")
		if facts.opted_out {
			[inside]
		} else {
			[("XDG_CACHE_HOME", clean(facts.xdg)), ("ROC_CACHE_DIR", clean(facts.build)), inside]
		}
	}

	## R-CC9: the text of `.last-use`: the time of Talon as `Clock.format_utc` and a line end, for example `2026-10-22T12:00:00Z\n`. (The format is a proposal, TW24.)
	last_use : U64 -> Str
	last_use = |now| "${Clock.format_utc(now)}\n"

	## R-EV6, R-DL8 to R-DL10: `TALON_AUTO_INSTALL`. `ask` and no variable are `Ask` (the default), `yes` is `Yes`, `no` is `No`. Any other text, also the empty text and a text in other letter case, counts as not set: `Ask`
	## (the answer of the user for `TALON_NIGHTLY`, `docs/slices/ANSWERS.md`: a bad value counts as not set). No failure, no warning.
	auto_install : List((Str, Str)) -> [Ask, Yes, No]
	auto_install = |env| match env.find_first(|(name, _)| name == "TALON_AUTO_INSTALL") {
		Ok((_, "yes")) => Yes
		Ok((_, "no")) => No
		_ => Ask
	}

	## R-PX4, R-DL8 to R-DL10, R-NI5, R-DL3: what the proxy does for a selected compiler that is not installed, before any request.
	##
	## | Case | Result |
	## | --- | --- |
	## | `id` is not a nightly tag (`Pin.is_nightly` is false: a prefix such as `nightly-2026-10`, `git-<sha8>`, `link-<name>`, `copy-<name>`, a release version, the empty text), whatever `auto` and `mode` are (question Q2: no source of compiler releases is known, R-NS2, and a build has no asset) | `Refuse` |
	## | `auto` is `No` | `Refuse`, in each mode (R-DL10) |
	## | `auto` is `Yes` | `Install`, in each mode (R-DL9): the answer is Yes with no prompt |
	## | `auto` is `Ask`, `mode` is `NonInteractive` | `Refuse` (R-DL8: the proxy never prompts in non-interactive mode, R-DL4) |
	## | `auto` is `Ask`, `mode` is `Interactive` | `Ask`: the prompt R-NI5 (default Yes for the proxy, R-DL3) |
	## | `auto` is `Ask`, `mode` is `NeedsTty` | `NeedTty`: the caller asks the terminal (R-HF1), then calls again with `Mode.with_tty` |
	##
	## `auto` `Yes` with `NeedsTty` never gives `NeedTty`: the answer needs no person, so the run makes no `tty!` call.
	want : { id : Str, auto : [Ask, Yes, No], mode : Mode } -> [Refuse, Install, Ask, NeedTty]
	want = |run| {
		if !Pin.is_nightly(run.id) or run.auto == No {
			Refuse
		} else if run.auto == Yes {
			Install
		} else {
			match run.mode {
				Interactive => Ask
				NeedsTty => NeedTty
				NonInteractive => Refuse
			}
		}
	}

	## R-DL8, R-DL10, R-NI5: the refusal for a selected id that is not installed. Kind `Consent` (exit 13), before the compiler runs. The text names `tln roc install <id>` and `TALON_AUTO_INSTALL=yes`
	## (a proposal, TW24): `the compiler <id> (<source>) is not installed. Run: tln roc install <id>, or set TALON_AUTO_INSTALL=yes.` `<source>` is the rank: `roc +<id>` (`Argument`), `ROC_TOOLCHAIN` (`Env`),
	## `the roc: entry of the header` (`Pin`), `.roc-version` (`VersionFile`), `the global default` (`Default`). `Range` and `Path` never give `Missing`; the text for them is `the compiler range`
	## and `the roc on PATH`.
	missing : { id : Str, rank : Proxy.Rank } -> Fail
	missing = |run| Fail.new(Consent, "the compiler ${run.id} (${source_text(run)}) is not installed. Run: tln roc install ${run.id}, or set TALON_AUTO_INSTALL=yes.")

	## R-E1: the child did not start. Kind `Environment` (exit 18), the text (a proposal, TW24): `cannot run <program>: <text>`.
	start_failed : { program : Str, text : Str } -> Fail
	start_failed = |run| Fail.new(Environment, "cannot run ${run.program}: ${run.text}")

	## The proxy: steps 1 to 12 of the table above. It gives the exit code of the child, or the code of a failure.
	run! : Fx => I32
	run! = |fx| match go!(fx) {
		Ok(code) => code
		Err(fail) => {
			fx.err!(Out.fail({ command: "roc", json: Bool.False, fail }).stderr)
			Exit.choose({ failures: [fail], child: Err(NoChild) })
		}
	}
}

Found : { project : Project, header : Try({}, Fail) }

Toolchain : { roc : Try(Pin.Req, [Unset]), roc_text : Try(Str, [Unset]), nightly : Try(Bool, [Unset]) }

# What the proxy reads for the ranks 3 to 6 (step 6). `req_text` is the text of the range, for the failure of `NoneInRange`.
Loaded : { pin : Try(Str, [NoPin]), req : Try(Pin.Req, [Unset]), req_text : Str, nightly : Try(Bool, [Unset]), has_toml : Bool, version_file : Try(Str, [None]), default : Try(Str, [Unset]) }

Read : List((Str, Try(Str, [NotFound, Denied, Other(Str)])))

# R-SO8: an argument that names the target file. An option and a URL are not a file.
is_source_file : Str -> Bool
is_source_file = |arg| arg.ends_with(".roc") and !arg.starts_with("-") and !arg.contains("://")

# R-SO8, Q2: the commands and flags that have no target file. `run` has none when it names a source that is not a file.
no_file_command : List(Str) -> Bool
no_file_command = |args| {
	flags = args.any(|arg| ["-h", "--help", "-V", "--version"].contains(arg))
	match args.first() {
		Ok("version") | Ok("help") | Ok("install") => Bool.True
		Ok("run") => args.drop_first(1).any(|arg| !arg.starts_with("-"))
		_ => flags
	}
}

# R-SO3, R-SO10, R-SO12, R-CV1: the pin is rank 3. It is installed under its own id, or the other tag form of it, or the id of the `roc` on `PATH`. Else it is `Missing`.
pinned : Str, Compiler.Facts -> { id : Str, rank : Proxy.Rank, state : [Installed, Missing] }
pinned = |pin, facts| match facts.installed.find_first(|id| Pin.same_id(pin, id)) {
	Ok(id) => { id, rank: Pin, state: Installed }
	Err(_) => match facts.path {
		Ok(on_path) if Pin.same_id(pin, on_path) => { id: on_path, rank: Pin, state: Installed }
		_ => { id: pin, rank: Pin, state: Missing }
	}
}

proxy_rank : Compiler.Rank -> Proxy.Rank
proxy_rank = |rank| match rank {
	Argument => Argument
	Env => Env
	Range => Range
	VersionFile => VersionFile
	Default => Default
	Path => Path
}

# R-PX6: a path with no `.` and no `..` part, for a path that `canonical!` could not resolve.
clean : { path : Str, canonical : Try(Str, [Failed]) } -> Str
clean = |dir| match dir.canonical {
	Ok(real) => real
	Err(Failed) => Text.resolve("/", dir.path)
}

source_text : { id : Str, rank : Proxy.Rank } -> Str
source_text = |run| match run.rank {
	Argument => "roc +${run.id}"
	Env => "ROC_TOOLCHAIN"
	Pin => "the roc: entry of the header"
	Range => "the compiler range"
	VersionFile => ".roc-version"
	Default => "the global default"
	Path => "the roc on PATH"
}

# The steps 1 to 12 of the table in the doc of `Proxy`.
go! : Fx => Try(I32, Fail)
go! = |fx| {
	words = fx.args!()
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	toolchain = Compiler.toolchain_of(env)?
	split = Proxy.split(words)
	off = Proxy.opted_out(env)
	early = split.argument.is_ok() or toolchain.is_ok()
	now = if off 0 else clock_now!(fx, env)?
	cwd = fx.cwd!()
	found = find!(fx, { target: Proxy.target(split.rest), skip: off and early, cwd, env })
	if !off {
		Known.record_recent!(fx, { roots, files: project_files(found), now })?
	}
	read = if early Ok(no_facts) else load!(fx, roots, found)
	loaded = read?
	nightly = match (Install.nightly_of(env), loaded.nightly) {
		(Ok(flag), _) => flag
		(_, Ok(flag)) => flag
		_ => Bool.True
	}
	lists = early or loaded.pin.is_ok() or loaded.req.is_ok() or (loaded.version_file.is_ok() and !loaded.has_toml) or loaded.default.is_ok()
	installed = if lists installed!(fx, roots) else []
	times = if loaded.req.is_ok() and !installed.is_empty() times!(fx, roots, installed) else []
	facts = {
		argument: split.argument,
		env: toolchain,
		req: loaded.req,
		nightly,
		has_toml: loaded.has_toml,
		version_file: loaded.version_file,
		default: loaded.default,
		path: Err(NoCompiler),
		installed,
		times,
	}
	first = Proxy.select({ pin: loaded.pin, facts })
	on_path = match first {
		Ok(sel) if sel.state == Installed and sel.rank != Range => Err(NoCompiler)
		_ => if Proxy.in_proxy(env) Err(NoCompiler) else Install.on_path_file!(fx, roots)
	}
	selected = match on_path {
		Ok(file) => Proxy.select({ pin: loaded.pin, facts: { ..facts, path: Ok(file.id) } })
		Err(NoCompiler) => first
	}
	chosen = match selected {
		Ok(sel) => sel
		Err(NoCompiler) => return Err(Compiler.failure(NoCompiler))
		Err(NoneInRange) => return Err(Compiler.failure(NoneInRange(loaded.req_text)))
	}
	missing = chosen.state == Missing
	id = if missing install_missing!(fx, { id: chosen.id, rank: chosen.rank, env })? else chosen.id
	have = if missing installed.append(id) else installed
	if !off and have.contains(id) {
		_ = fx.write_atomic!([{ path: Roots.item(roots, ToolchainLastUse(id)), content: Proxy.last_use(now) }])
	}
	canonical = if off [] else fx.canonical!([Text.dir_of(roots.cache), roots.build])
	program = Proxy.program({ roots, id, installed: have, path: on_path })
	child_env = Proxy.child_env({
		opted_out: off,
		xdg: { path: Text.dir_of(roots.cache), canonical: canonical_at(canonical, 0) },
		build: { path: roots.build, canonical: canonical_at(canonical, 1) },
	})
	match fx.exec!({ argv: [program].concat(split.rest), env: child_env }) {
		Ok(code) => Ok(code)
		Err(NotStarted(text)) => Err(Proxy.start_failed({ program, text }))
	}
}

# Steps 9a to 9f: the compiler that is not installed. It gives the id of the compiler that is installed after it.
install_missing! : Fx, { id : Str, rank : Proxy.Rank, env : List((Str, Str)) } => Try(Str, Fail)
install_missing! = |fx, run| {
	auto = Proxy.auto_install(run.env)
	mode = Mode.from_env({ env: Dict.from_list(run.env), json: Bool.False })
	first = Proxy.want({ id: run.id, auto, mode })
	known = if first == NeedTty Mode.with_tty(mode, fx.tty!()) else mode
	match Proxy.want({ id: run.id, auto, mode: known }) {
		Install => offer_and_install!(fx, run, { mode: known, flag: Ok(Yes) })
		Ask => offer_and_install!(fx, run, { mode: known, flag: Err(NoFlag) })
		Refuse | NeedTty => Err(Proxy.missing({ id: run.id, rank: run.rank }))
	}
}

# Steps 9c to 9f. The prompt comes after the offer (it needs the size) and before the lock (R-CC3 point 5).
offer_and_install! : Fx, { id : Str, rank : Proxy.Rank, env : List((Str, Str)) }, { mode : Mode, flag : Try(Answer, [NoFlag]) } => Try(Str, Fail)
offer_and_install! = |fx, run, how| match RocInstall.offer!(fx, { id: run.id, env: run.env, offline: Bool.False })? {
	Present(found) => Ok(found.id)
	Download(offer) => {
		prompt = Consent.proxy_download({ id: offer.id, source: source_text({ id: run.id, rank: run.rank }), size: offer.size })
		asked = Prompt.ask!(fx, prompt, { mode: how.mode, yes: Bool.False, quiet: Bool.False, flag: how.flag })?
		if asked.answer == Yes {
			done = RocInstall.install_offer!(fx, offer)?
			Ok(done.id)
		} else {
			Err(Consent.roc_install_declined(offer.id))
		}
	}
}

no_facts : Loaded
no_facts = { pin: Err(NoPin), req: Err(Unset), req_text: "", nightly: Err(Unset), has_toml: Bool.False, version_file: Err(None), default: Err(Unset) }

no_toolchain : Toolchain
no_toolchain = { roc: Err(Unset), roc_text: Err(Unset), nightly: Err(Unset) }

# Step 11: the result of `canonical!` for the path at `at`.
canonical_at : List(Try(Str, [NotFound, Denied, Other(Str)])), U64 -> Try(Str, [Failed])
canonical_at = |results, at| match results.get(at) {
	Ok(Ok(real)) => Ok(real)
	_ => Err(Failed)
}

# R-EV22, Q7: a bad `TALON_NOW` is exit 2, as in the other commands.
clock_now! : Fx, List((Str, Str)) => Try(U64, Fail)
clock_now! = |fx, env| {
	talon_now = match env.find_first(|(name, _)| name == "TALON_NOW") {
		Ok((_, text)) => Ok(text)
		Err(_) => Err(NotSet)
	}
	match Clock.now({ talon_now, real: fx.clock!() }) {
		Ok(now) => Ok(now)
		Err(BadTime(text)) => Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
	}
}

# Step 4, R-PD7, R-TF5: the project of the target file. No target, or `roc +<id>` or `ROC_TOOLCHAIN` with `TALON_PROXY=0`, or a failure of the search: no project.
find! : Fx, { target : [File(Str), Main, NoFile], skip : Bool, cwd : Str, env : List((Str, Str)) } => Try(Found, [NoProject])
find! = |fx, run| {
	file = match run.target {
		File(typed) => Ok(typed)
		Main => Ok("main.roc")
		NoFile => Err(NoFile)
	}
	home = match run.env.find_first(|(name, _)| name == "HOME") {
		Ok((_, dir)) => dir
		Err(_) => ""
	}
	match file {
		Ok(typed) if !run.skip => match Project.find_loose!(fx, { start: run.cwd, file: Ok(typed), home }) {
			Ok(found) => Ok(found)
			Err(_) => Err(NoProject)
		}
		_ => Err(NoProject)
	}
}

# Step 5, R-PD9: the project file is already canonical (step 4).
project_files : Try(Found, [NoProject]) -> List(Str)
project_files = |found| match found {
	Ok(project) => match project.project.file {
		Ok(file) => [file]
		Err(NoCurrent) => []
	}
	Err(NoProject) => []
}

# R-TF5: the `roc:` pin of the project file. A header that does not parse, or a pin that is not a full id, is no pin.
pin_of : Read, Str, Try({}, Fail) -> Try(Str, [NoPin])
pin_of = |read, file, header| match (header, text_of(read, file)) {
	(Ok({}), Ok(text)) => match Locked.read({ path: file, text }) {
		Ok(locked) => locked.roc
		Err(_) => Err(NoPin)
	}
	_ => Err(NoPin)
}

text_of : Read, Str -> Try(Str, [NotFound, Denied, Other(Str)])
text_of = |read, path| match read.find_first(|(file, _)| file == path) {
	Ok((_, result)) => result
	Err(_) => Err(NotFound)
}

# Step 6, R-SO3 to R-SO6, R-TF4, R-TF5: one `read_files!`: the project file, the `talon.toml`, `config.toml` and the `.roc-version`, those that exist.
load! : Fx, Roots, Try(Found, [NoProject]) => Try(Loaded, Fail)
load! = |fx, roots, found| {
	config_path = Roots.item(roots, Config)
	files = project_files(found)
	tomls = match found {
		Ok(project) => match project.project.workspace {
			Ok(ws) => [Text.join(ws.root, "talon.toml")]
			Err(Standalone) => match project.project.toml {
				Ok(path) => [path]
				Err(NoToml) => []
			}
		}
		Err(NoProject) => []
	}
	versions = match found {
		Ok(project) => match project.project.roc_version {
			Ok(path) => [path]
			Err(None) => []
		}
		Err(NoProject) => []
	}
	paths = files.concat(tomls).append(config_path).concat(versions)
	read = paths.map2(fx.read_files!(paths), |path, result| (path, result))
	pin = match (found, files) {
		(Ok(project), [file]) => pin_of(read, file, project.header)
		_ => Err(NoPin)
	}
	toolchain = read_toolchain(read, tomls)?
	config = read_config(read, config_path)?
	version_file = read_version(read, versions)?
	has_toml = match found {
		Ok(project) => project.project.toml.is_ok()
		Err(NoProject) => Bool.False
	}
	nightly = match (toolchain.nightly, config.nightly) {
		(Ok(flag), _) => Ok(flag)
		(_, Ok(flag)) => Ok(flag)
		_ => Err(Unset)
	}
	Ok({ pin, req: toolchain.roc, req_text: toolchain.roc_text ?? "", nightly, has_toml, version_file, default: config.default_roc })
}

# R-SO4, R-TF4: the `[toolchain]` table of the `talon.toml`. A file that does not parse is exit 19 (Q5). The proxy prints no warning (D10).
read_toolchain : Read, List(Str) -> Try(Toolchain, Fail)
read_toolchain = |read, tomls| match tomls {
	[path] => match text_of(read, path) {
		Ok(text) => {
			scanned = Intent.read({ path, text, role: Root })?
			Ok(scanned.intent.toolchain)
		}
		Err(NotFound) => Ok(no_toolchain)
		Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
	}
	_ => Ok(no_toolchain)
}

# R-SO6, R-TF4: `default-roc` and the settings of `config.toml`. A missing file gives no setting.
read_config : Read, Str -> Try(Intent.Config, Fail)
read_config = |read, path| match text_of(read, path) {
	Ok(text) => {
		scanned = Intent.read_config({ path, text })?
		Ok(scanned.config)
	}
	Err(NotFound) => Ok({ nightly: Err(Unset), min_release_age: Err(Unset), default_roc: Err(Unset) })
	Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
}

# R-SO5, R-SC12: the id of the `.roc-version`. An empty file is no file. A text that is no full id is exit 19.
read_version : Read, List(Str) -> Try(Try(Str, [None]), Fail)
read_version = |read, versions| match versions {
	[path] => match text_of(read, path) {
		Ok(text) => match Compiler.version_file({ path, text })? {
			Ok(id) => Ok(Ok(id))
			Err(Empty) => Ok(Err(None))
		}
		Err(NotFound) => Ok(Err(None))
		Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
	}
	_ => Ok(Err(None))
}

# Step 7: the compilers in `<cache>/toolchains`. A missing directory is empty.
installed! : Fx, Roots => List(Str)
installed! = |fx, roots| match fx.list_dirs!([Text.join(roots.cache, "toolchains")]) {
	[Ok(found)] => Compiler.installed(found)
	_ => []
}

# Step 7, R-NS1: the `published_at` of the installed compilers, for the order of rank 4.
times! : Fx, Roots, List(Str) => List({ id : Str, published_at : U64 })
times! = |fx, roots, installed| {
	paths = installed.map(|id| Roots.item(roots, ToolchainMeta(id)))
	Compiler.times(installed.map2(fx.read_files!(paths), |id, text| { id, text }))
}
