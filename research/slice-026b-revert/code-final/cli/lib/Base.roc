import Common
import Compiler
import Fail
import Fx
import Intent
import Locked
import OnPath
import Pin
import Project
import Roots
import Text

## The compiler that Resolution 13 selects for a target file (R-SO1 to R-SO14), for the `roc` proxy (`Proxy.go!`) and for the base of a relative step (slice 026, R-SL7, R-PD16, R-PD7, R-NS3).
## A leaf module: `Proxy` imports `RocInstall`, and `RocInstall.offer!` needs the base, so the code that both use is here (as `Common` and `Start` were made in slice 025).
## `Nightlies.pick` takes the result of `selected!` as its `base` (`Nightlies.PickError` has `NoBase` and `BaseNotListed`).
##
## | Part | Kind | Used by |
## | --- | --- | --- |
## | `select`, `facts`, `in_proxy` | A, pure | `Proxy.select`, `Proxy.in_proxy`, `selected!`, `Proxy.go!` |
## | `find!`, `project_files`, `load!`, `times!` | C, the reads of the ranks 3 to 6 | `Proxy.go!`, `selected!` |
## | `choose!` | C, the choice and the `roc` on `PATH` (rank 7) | `Proxy.go!`, `selected!` |
## | `selected!` | C, the base | `RocInstall.offer!` |
Base :: [].{

	## The rank that selected the compiler: `Compiler.Rank` with the header pin (rank 3) between `Env` and `Range`.
	Rank : [Argument, Env, Pin, Range, VersionFile, Default, Path]

	## A compiler that a rank selected. `Missing` is an id that is not installed.
	Selected : { id : Str, rank : Base.Rank, state : [Installed, Missing] }

	## The project of the target file and the result of its header.
	Found : { project : Project, header : Try({}, Fail) }

	## What the ranks 3 to 6 read (step 6 of the table of `Proxy`). `req_text` is the text of the range, for the failure of `NoneInRange`.
	Loaded : { pin : Try(Str, [NoPin]), req : Try(Pin.Req, [Unset]), req_text : Str, nightly : Try(Bool, [Unset]), toml_nightly : Try(Bool, [Unset]), config_nightly : Try(Bool, [Unset]), min_age : U64, has_toml : Bool, version_file : Try(Str, [None]), default : Try(Str, [Unset]) }

	## What `load!` reads when there is nothing to read (`ROC_TOOLCHAIN` or `roc +<id>` is used: no file counts).
	no_facts : Base.Loaded
	no_facts = { pin: Err(NoPin), req: Err(Unset), req_text: "", nightly: Err(Unset), toml_nightly: Err(Unset), config_nightly: Err(Unset), min_age: 172800, has_toml: Bool.False, version_file: Err(None), default: Err(Unset) }

	## R-EV17, R-SO9: `TALON_IN_PROXY=1` is set. Any other value, and no variable, is false. A proxy that sees it does not look at `PATH` (rank 7).
	in_proxy : List((Str, Str)) -> Bool
	in_proxy = |env| env.contains(("TALON_IN_PROXY", "1"))

	## R-SO1 to R-SO7, R-SO10, R-SO12 to R-SO14, R-CV1 (the ranks of the proxy). `pin` is the `roc:` entry of the header of the target file. `facts` are the facts of `Compiler.select`: `argument` is rank 1, `env` is rank 2.
	## The first rank that has a value wins, in the order 1, 2, 3, 4, 5, 6, 7. Ranks 1, 2, 4, 5, 6, 7 are `Compiler.select`. Rank 3 (the pin) is the id of the pin, with no `nightly` switch and no range
	## (R-SO19: the proxy has no gate). A pin names an installed compiler when `Pin.same_id` holds for one id of `facts.installed` (the other tag form of one nightly, R-CV1): `id` is then the installed id.
	## It is also installed when it is the id of `facts.path` (R-SO10). Else `state` is `Missing` (the pin is the id as it is). `NoneInRange` and `NoCompiler` are as in `Compiler.select`.
	select : { pin : Try(Str, [NoPin]), facts : Compiler.Facts } -> Try(Base.Selected, [NoCompiler, NoneInRange])
	select = |run| match (run.facts.argument, run.facts.env, run.pin) {
		(Err(Unset), Err(Unset), Ok(pin)) => Ok(pinned(pin, run.facts))
		_ => Compiler.select(run.facts).map_ok(|sel| { id: sel.id, rank: rank_of(sel.rank), state: sel.state })
	}

	## The facts of `Compiler.select` from what the steps read. `env_nightly` is `Common.nightly_of`: it wins over the `nightly` of `talon.toml` and `config.toml`, and with none of them the switch is on (R-NS3).
	facts : { argument : Try(Str, [Unset]), toolchain : Try(Str, [Unset]), loaded : Base.Loaded, env_nightly : Try(Bool, [Unset]), installed : List(Str), times : List({ id : Str, published_at : U64 }) } -> Compiler.Facts
	facts = |run| {
		nightly = match (run.env_nightly, run.loaded.nightly) {
			(Ok(flag), _) => flag
			(_, Ok(flag)) => flag
			_ => Bool.True
		}
		{
			argument: run.argument,
			env: run.toolchain,
			req: run.loaded.req,
			nightly,
			has_toml: run.loaded.has_toml,
			version_file: run.loaded.version_file,
			default: run.loaded.default,
			path: Err(NoCompiler),
			installed: run.installed,
			times: run.times,
		}
	}

	## Step 8 of `Proxy`, R-SO7, R-SO9, R-EV17: `select` with `path: Err(NoCompiler)`. A result `Installed` of a rank other than `Range` is the compiler. Else, and not `TALON_IN_PROXY=1`:
	## `OnPath.file!` (`path_roc!` and the calls of slice 022b), then `select` again with the id of that file. `on_path` is the answer of `OnPath.file!` (`Err(NoCompiler)` when it was not called).
	choose! : Fx, { roots : Roots, env : List((Str, Str)), pin : Try(Str, [NoPin]), facts : Compiler.Facts } => { selected : Try(Base.Selected, [NoCompiler, NoneInRange]), on_path : Try({ id : Str, path : Str }, [NoCompiler]) }
	choose! = |fx, run| {
		first = Base.select({ pin: run.pin, facts: run.facts })
		on_path = match first {
			Ok(sel) if sel.state == Installed and sel.rank != Range => Err(NoCompiler)
			_ => if Base.in_proxy(run.env) Err(NoCompiler) else OnPath.file!(fx, run.roots)
		}
		selected = match on_path {
			Ok(file) => Base.select({ pin: run.pin, facts: { ..run.facts, path: Ok(file.id) } })
			Err(NoCompiler) => first
		}
		{ selected, on_path }
	}

	## R-SL7, R-PD16, R-PD7, R-NS3: the base of a relative step, the compiler that Resolution 13 selects for the target file `main.roc` of the current directory, as the proxy selects it for `roc` with no argument
	## (`Proxy.go!`), with these differences: no download, no `.last-use`, no record in `projects.json` (a `tln roc` command uses no project, R-PD16), no `exec!`.
	## `env` is the environment, `roots` the cache dirs, `installed` the ids of `<cache>/toolchains` (`Compiler.installed`), `config` is `config.toml` (`default-roc`, `nightly`).
	## The result is the id of the selected compiler, also when it is not installed (the base is a position in the list, not a compiler to run). `Err(None)` is no base (R-SO14).
	##
	## | Rank | Source | Base |
	## | --- | --- | --- |
	## | 2 | `ROC_TOOLCHAIN` (a failure of `Compiler.toolchain_of` is its failure, exit 2) | the id. No file is read. |
	## | 3 | The `roc:` pin of the header of `main.roc` | the pin, or the installed id of the other tag form |
	## | 4 | `[toolchain] roc` of the `talon.toml` of that file | the newest installed compiler in the range |
	## | 5 | `.roc-version`, when there is no `talon.toml` | the id |
	## | 6 | `default-roc` of `config.toml` | the id |
	## | 7 | The `roc` on `PATH` (`OnPath.file!`) | its id |
	## | none | | `Err(None)` |
	##
	## | Step | Does | Rule |
	## | --- | --- | --- |
	## | 1 | `Compiler.toolchain_of(env)` (no call). A value is rank 2: the steps 2 to 4 make no call. | R-SO2 |
	## | 2 | `cwd!`, then `find!` with `main.roc` (the calls of `Project.find_loose!`). A search that fails is no project. | R-PD7, R-TF5 |
	## | 3 | One `read_files!` of the project file, the `talon.toml` and the `.roc-version`, those that exist (`load!` with `Given`) | R-SO3 to R-SO5 |
	## | 4 | A range and a non-empty `installed`: one `read_files!` of the `.talon.json` of each (`times!`) | R-NS1 |
	## | 5 | `choose!` | R-SO7, R-SO9, R-SO10 |
	## | 6 | `Ok(id)` is the base. `NoCompiler` and `NoneInRange` are `Err(None)` (question Q3 of the slice file). | R-SO14 |
	selected! : Fx, { env : List((Str, Str)), roots : Roots, installed : List(Str), config : Intent.Config } => Try(Try(Str, [None]), Fail)
	selected! = |fx, run| {
		toolchain = Compiler.toolchain_of(run.env)?
		found = if toolchain.is_ok() Err(NoProject) else Base.find!(fx, { target: Main, skip: Bool.False, cwd: fx.cwd!(), env: run.env })
		read = if toolchain.is_ok() Ok(Base.no_facts) else Base.load!(fx, run.roots, found, Given(run.config))
		loaded = read?
		times = if loaded.req.is_ok() and !run.installed.is_empty() Base.times!(fx, run.roots, run.installed) else []
		compiler = Base.facts({ argument: Err(Unset), toolchain, loaded, env_nightly: Common.nightly_of(run.env), installed: run.installed, times })
		match Base.choose!(fx, { roots: run.roots, env: run.env, pin: loaded.pin, facts: compiler }).selected {
			Ok(sel) => Ok(Ok(sel.id))
			Err(NoCompiler) | Err(NoneInRange) => Ok(Err(None))
		}
	}

	# Step 4, R-PD7, R-TF5: the project of the target file. No target, or `skip`, or a failure of the search: no project.
	find! : Fx, { target : [File(Str), Main, NoFile], skip : Bool, cwd : Str, env : List((Str, Str)) } => Try(Base.Found, [NoProject])
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
	project_files : Try(Base.Found, [NoProject]) -> List(Str)
	project_files = |found| match found {
		Ok(project) => match project.project.file {
			Ok(file) => [file]
			Err(NoCurrent) => []
		}
		Err(NoProject) => []
	}

	# Step 6, R-SO3 to R-SO6, R-TF4, R-TF5: one `read_files!`: the project file, the `talon.toml`, `config.toml` (only for `Read`) and the `.roc-version`, those that exist.
	load! : Fx, Roots, Try(Base.Found, [NoProject]), [Read, Given(Intent.Config)] => Try(Base.Loaded, Fail)
	load! = |fx, roots, found, source| {
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
		own = match source {
			Read => [config_path]
			Given(_) => []
		}
		paths = files.concat(tomls).concat(own).concat(versions)
		read = paths.map2(fx.read_files!(paths), |path, result| (path, result))
		pin = match (found, files) {
			(Ok(project), [file]) => pin_of(read, file, project.header)
			_ => Err(NoPin)
		}
		toolchain = read_toolchain(read, tomls)?
		config = match source {
			Read => read_config(read, config_path)?
			Given(given) => given
		}
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
		Ok({ pin, req: toolchain.roc, req_text: toolchain.roc_text ?? "", nightly, toml_nightly: toolchain.nightly, config_nightly: config.nightly, min_age: config.min_release_age ?? 172800, has_toml, version_file, default: config.default_roc })
	}

	# Step 7, R-NS1: the `published_at` of the installed compilers, for the order of rank 4.
	times! : Fx, Roots, List(Str) => List({ id : Str, published_at : U64 })
	times! = |fx, roots, installed| {
		paths = installed.map(|id| Roots.item(roots, ToolchainMeta(id)))
		Compiler.times(installed.map2(fx.read_files!(paths), |id, text| { id, text }))
	}
}

# R-SO3, R-SO10, R-SO12, R-CV1: the pin is rank 3. It is installed under its own id, or the other tag form of it, or the id of the `roc` on `PATH`. Else it is `Missing`.
pinned : Str, Compiler.Facts -> Base.Selected
pinned = |pin, facts| match facts.installed.find_first(|id| Pin.same_id(pin, id)) {
	Ok(id) => { id, rank: Pin, state: Installed }
	Err(_) => match facts.path {
		Ok(on_path) if Pin.same_id(pin, on_path) => { id: on_path, rank: Pin, state: Installed }
		_ => { id: pin, rank: Pin, state: Missing }
	}
}

rank_of : Compiler.Rank -> Base.Rank
rank_of = |rank| match rank {
	Argument => Argument
	Env => Env
	Range => Range
	VersionFile => VersionFile
	Default => Default
	Path => Path
}

TomlToolchain : { roc : Try(Pin.Req, [Unset]), roc_text : Try(Str, [Unset]), nightly : Try(Bool, [Unset]) }

no_toolchain : TomlToolchain
no_toolchain = { roc: Err(Unset), roc_text: Err(Unset), nightly: Err(Unset) }

Reads : List((Str, Try(Str, [NotFound, Denied, Other(Str)])))

# R-TF5: the `roc:` pin of the project file. A header that does not parse, or a pin that is not a full id, is no pin.
pin_of : Reads, Str, Try({}, Fail) -> Try(Str, [NoPin])
pin_of = |read, file, header| match (header, text_of(read, file)) {
	(Ok({}), Ok(text)) => match Locked.read({ path: file, text }) {
		Ok(locked) => locked.roc
		Err(_) => Err(NoPin)
	}
	_ => Err(NoPin)
}

text_of : Reads, Str -> Try(Str, [NotFound, Denied, Other(Str)])
text_of = |read, path| match read.find_first(|(file, _)| file == path) {
	Ok((_, result)) => result
	Err(_) => Err(NotFound)
}

# R-SO4, R-TF4: the `[toolchain]` table of the `talon.toml`. A file that does not parse is exit 19 (Q5). The proxy prints no warning (D10).
read_toolchain : Reads, List(Str) -> Try(TomlToolchain, Fail)
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
read_config : Reads, Str -> Try(Intent.Config, Fail)
read_config = |read, path| match text_of(read, path) {
	Ok(text) => {
		scanned = Intent.read_config({ path, text })?
		Ok(scanned.config)
	}
	Err(NotFound) => Ok({ nightly: Err(Unset), min_release_age: Err(Unset), default_roc: Err(Unset) })
	Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
}

# R-SO5, R-SC12: the id of the `.roc-version`. An empty file is no file. A text that is no full id is exit 19.
read_version : Reads, List(Str) -> Try(Try(Str, [None]), Fail)
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
