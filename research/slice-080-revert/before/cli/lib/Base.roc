import Common
import Compiler
import ConfigToml
import Facts
import Fail
import Fx
import Intent
import LadderPlan
import Locked
import Nightlies
import NoRankPure
import OnPath
import Patched
import Pin
import Project
import Roots
import Text
import Toolchain

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

	## The rank that selected the compiler: `Compiler.Rank` with the header pin (rank 3) between `Env` and `Range`. `Picked` (slice 072e, R-SO14, R-PX4) is no rank: no rank selected a compiler, and the proxy picked one.
	Rank : [Argument, Env, Pin, Range, VersionFile, Default, Path, Picked]

	## A compiler that a rank selected. `Missing` is an id that is not installed.
	Selected : { id : Str, rank : Base.Rank, state : [Installed, Missing] }

	## The project of the target file and the result of its header.
	Found : { project : Project, header : Try({}, Fail) }

	## Slice 072e (R-SL7): what `selected!` found. `base` is the selected compiler. With none, `range` is the range of `talon.toml` when no installed compiler is in it (rank 4, `NoneInRange`), and `hashes` are the hashes of the header of `main.roc`.
	Basis : { base : Try(Str, [None]), hashes : List(Str), range : Try(Pin.Req, [None]) }

	## What the ranks 3 to 6 read (step 6 of the table of `Proxy`). `req_text` is the text of the range, for the failure of `NoneInRange`.
	## Slice 043 (R-PX5, R-PA6, R-PA10): `patch` has the patches of the header of the target file (`Patched.entries`: its rows and the `[patch]` table of the `talon.toml` that the step reads): `replace` are the `--replace-dep` pairs, `stale` are the entries whose `base` is not the hash of the header entry.
	## A target with no header, no `talon.toml` or no patch has both lists empty.
	Loaded : { pin : Try(Str, [NoPin]), req : Try(Pin.Req, [Unset]), req_text : Str, nightly : Try(Bool, [Unset]), toml_nightly : Try(Bool, [Unset]), config_nightly : Try(Bool, [Unset]), min_age : U64, has_toml : Bool, version_file : Try(Str, [None]), default : Try(Str, [Unset]), hashes : List(Str), patch : { replace : List(LadderPlan.Replace), stale : List(Patched.Entry) } }

	## What `load!` reads when there is nothing to read (`ROC_TOOLCHAIN` or `roc +<id>` is used: no file counts).
	no_facts : Base.Loaded
	no_facts = { pin: Err(NoPin), req: Err(Unset), req_text: "", nightly: Err(Unset), toml_nightly: Err(Unset), config_nightly: Err(Unset), min_age: 172800, has_toml: Bool.False, version_file: Err(None), default: Err(Unset), hashes: [], patch: { replace: [], stale: [] } }

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
	## The result is the id of the selected compiler, also when it is not installed (the base is a position in the list, not a compiler to run). `Err(None)` is no base: slice 072e (R-SL7, R-SO23) `Base.listed!` gives the base then.
	##
	## | Rank | Source | Base |
	## | --- | --- | --- |
	## | 2 | `ROC_TOOLCHAIN` (a failure of `Compiler.toolchain_of` is its failure, exit 2) | the id. No file is read. |
	## | 3 | The `roc:` pin of the header of `main.roc` | the pin, or the installed id of the other tag form |
	## | 4 | `[toolchain] roc` of the `talon.toml` of that file | the newest installed compiler in the range |
	## | 5 | `.roc-version`, when there is no `talon.toml` | the id |
	## | 6 | `default-roc` of `config.toml` | the id |
	## | 7 | The `roc` on `PATH` (`OnPath.file!`) | its id |
	## | 4 (none installed in the range) | | `Err(None)`, `range` is the range (R-SO13) |
	## | none | | `Err(None)`, `range` is `Err(None)`: nothing is installed and no rank selects (R-SO24) |
	##
	## | Step | Does | Rule |
	## | --- | --- | --- |
	## | 1 | `Compiler.toolchain_of(env)` (no call). A value is rank 2: the steps 2 to 4 make no call. | R-SO2 |
	## | 2 | `cwd!`, then `find!` with `main.roc` (the calls of `Project.find_loose!`). A search that fails is no project. | R-PD7, R-TF5 |
	## | 3 | One `read_files!` of the project file, the `talon.toml` and the `.roc-version`, those that exist (`load!` with `Given`) | R-SO3 to R-SO5 |
	## | 4 | A range and a non-empty `installed`: one `read_files!` of the `.talon.json` of each (`times!`) | R-NS1 |
	## | 5 | `choose!` | R-SO7, R-SO9, R-SO10 |
	## | 6 | `Ok(id)` is the base. `NoCompiler` and `NoneInRange` are `Err(None)`, with the range and the hashes of the header for `listed!` (slice 072e). | R-SO14 |
	selected! : Fx, { env : List((Str, Str)), roots : Roots, installed : List(Str), config : ConfigToml.Config } => Try(Base.Basis, Fail)
	selected! = |fx, run| {
		toolchain = Compiler.toolchain_of(run.env)?
		found = if toolchain.is_ok() Err(NoProject) else Base.find!(fx, { target: Main, skip: Bool.False, cwd: fx.cwd!(), env: run.env })
		read = if toolchain.is_ok() Ok(Base.no_facts) else Base.load!(fx, run.roots, found, Given(run.config))
		loaded = read?
		times = if loaded.req.is_ok() and !run.installed.is_empty() Base.times!(fx, run.roots, run.installed) else []
		compiler = Base.facts({ argument: Err(Unset), toolchain, loaded, env_nightly: Common.nightly_of(run.env), installed: run.installed, times })
		match Base.choose!(fx, { roots: run.roots, env: run.env, pin: loaded.pin, facts: compiler }).selected {
			Ok(sel) => Ok({ base: Ok(sel.id), hashes: loaded.hashes, range: Err(None) })
			Err(NoCompiler) => Ok({ base: Err(None), hashes: loaded.hashes, range: Err(None) })
			Err(NoneInRange) => Ok({ base: Err(None), hashes: loaded.hashes, range: loaded.req.map_err(|_| None) })
		}
	}

	## R-SL7, R-SO13, R-SO14, R-SO23 (slice 072e): the base of a relative step when `selected!` gave none, as an id only (no download, no default, no probe). `releases` is the list of the host and `auto` its channel ids (`Toolchain.domain`).
	## With a range and no installed compiler in it (`basis.range`): the newest release in the range (`Toolchain.range_pick`, R-SO13), and no fact is read. With no range: the pick of R-SO14 over the recorded passes of the hashes of the header
	## (one `Facts.load!`, no call when there is no hash; `NoRankPure.pick`). `Err(None)` when the channel has no release.
	listed! : Fx, { roots : Roots, basis : Base.Basis, releases : List(Nightlies.Release), auto : List(Str), now : U64, min_age : U64, nightly : Bool } => Try(Try(Str, [None]), Fail)
	listed! = |fx, run| match (run.basis.base, run.basis.range) {
		(Ok(id), _) => Ok(Ok(id))
		(Err(None), Ok(req)) => Ok(Toolchain.range_pick({ releases: run.releases, req, now: run.now, min_age: run.min_age, snapshot: Err(None), nightly: run.nightly }).map_err(|_| None))
		(Err(None), Err(None)) => {
			hashes = run.basis.hashes
			rows = Facts.load!(fx, { roots: run.roots, keys: NoRankPure.keys({ hashes, auto: run.auto }) })?
			Ok(NoRankPure.pick({ auto: run.auto, scope: Project(hashes), facts: rows }).map_err(|_| None))
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

	## Slice 070, R-PX5, R-PD6, R-PD7, R-WS5: the files that `load!` reads in one `read_files!`, in this order (a file that does not exist as a path is not in the lists). `files` is the project file (`project_files`, 0 or 1),
	## `root` is the `talon.toml` that holds `[toolchain]` (the root file of a workspace, else the file of a standalone project, else none), `nearest` is the `talon.toml` of the target file (`Project.toml`: the nearest one up to
	## the workspace root, R-PD6), `config` is `config.toml` and `versions` is the `.roc-version` (0 or 1).
	##
	## | `source` | Paths |
	## | --- | --- |
	## | `Read` | `files`, `root`, `nearest` (when it is not in `root`: a member with a `talon.toml` of its own), `config`, `versions` |
	## | `Given` | The same with no `config` |
	## | `Patches` | The ranks 1 and 2 (`roc +<id>`, `ROC_TOOLCHAIN`) read only what R-PX5 needs: `files` and `nearest`. With no `nearest`, or with no `files` (no header: no row can have a patch), nothing: no call at all, as before the slice |
	##
	## `[patch]` is read from `nearest` (R-PX5: Talon does not merge two files, R-WS5), `[toolchain]` from `root`.
	load_paths : { source : [Read, Given, Patches], files : List(Str), root : List(Str), nearest : Try(Str, [NoToml]), config : Str, versions : List(Str) } -> List(Str)
	load_paths = |x| {
		own = match x.nearest {
			Ok(path) if !x.root.contains(path) => [path]
			_ => []
		}
		shared = match x.nearest {
			Ok(path) => [path]
			Err(NoToml) => []
		}
		match x.source {
			Read => x.files.concat(x.root).concat(own).concat([x.config]).concat(x.versions)
			Given => x.files.concat(x.root).concat(own).concat(x.versions)
			Patches => if x.files.is_empty() or shared.is_empty() [] else x.files.concat(shared)
		}
	}

	# Step 6, R-SO3 to R-SO6, R-TF4, R-TF5: one `read_files!`: the project file, the `talon.toml`, `config.toml` (only for `Read`) and the `.roc-version`, those that exist.
	# Slice 070 (R-PX5): `Patches` is for the ranks 1 and 2 (`Proxy.go!`, not opted out, a project that has a `talon.toml`): the paths of `load_paths`, and the result is `Base.no_facts` with `patch` only (the pin, the range, the config
	# and the `.roc-version` do not count there: the compiler is given). The `patch` of every source comes from the `[patch]` table of the nearest `talon.toml` (`Intent.read` with the role `Root` for the root file, `Member` for another file).
	load! : Fx, Roots, Try(Base.Found, [NoProject]), [Read, Given(ConfigToml.Config), Patches] => Try(Base.Loaded, Fail)
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
		nearest = match found {
			Ok(project) => project.project.toml
			Err(NoProject) => Err(NoToml)
		}
		kind = match source {
			Read => Read
			Given(_) => Given
			Patches => Patches
		}
		paths = Base.load_paths({ source: kind, files, root: tomls, nearest, config: config_path, versions })
		read = if kind == Patches and paths.is_empty() [] else paths.map2(fx.read_files!(paths), |path, result| (path, result))
		locked = match (found, files) {
			(Ok(project), [file]) => locked_of(read, file, project.header)
			_ => Err(NoPin)
		}
		pin = match locked {
			Ok(l) => l.roc
			Err(NoPin) => Err(NoPin)
		}
		rooted = if kind == Patches Ok(unread) else read_toml(read, tomls)
		toml = rooted?
		table = patch_table(read, { nearest, root: tomls, rooted: toml, reuse: kind != Patches })?
		if kind == Patches {
			return Ok({ ..Base.no_facts, patch: patch_of(locked, { toolchain: no_toolchain, patches: table.patches, path: table.path }) })
		}
		toolchain = toml.toolchain
		config = match source {
			Read => read_config(read, config_path)?
			Given(given) => given
			Patches => no_config
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
		Ok({ pin, req: toolchain.roc, req_text: toolchain.roc_text ?? "", nightly, toml_nightly: toolchain.nightly, config_nightly: config.nightly, min_age: config.min_release_age ?? 172800, has_toml, version_file, default: config.default_roc, hashes: header_hashes(locked), patch: patch_of(locked, { toolchain: toml.toolchain, patches: table.patches, path: table.path }) })
	}

	# Step 7, R-NS1: the `published_at` of the installed compilers, for the order of rank 4.
	times! : Fx, Roots, List(Str) => List({ id : Str, published_at : U64 })
	times! = |fx, roots, installed| {
		paths = installed.map(|id| Roots.item(roots, ToolchainMeta(id)))
		Compiler.times(installed.map2(fx.read_files!(paths), |id, text| { id, text }))
	}
}

# R-SL7, R-SO23, R-PX4: the hashes of the release entries of the header, in the order of its rows.
header_hashes : Try(Locked, [NoPin]) -> List(Str)
header_hashes = |locked| match locked {
	Ok(l) => l.rows.keep_oks(
		|row| match row.what {
			Release(ident) => Ok(ident.hash)
			_ => Err(NotRelease)
		},
	)
	Err(NoPin) => []
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

# R-TF5: the header of the project file. A header that does not parse is no header: the pin and the patches are dropped (a pin that is not a full id is no pin, `Locked.roc`).
locked_of : Reads, Str, Try({}, Fail) -> Try(Locked, [NoPin])
locked_of = |read, file, header| match (header, text_of(read, file)) {
	(Ok({}), Ok(text)) => match Locked.read({ path: file, text }) {
		Ok(locked) => Ok(locked)
		Err(_) => Err(NoPin)
	}
	_ => Err(NoPin)
}

text_of : Reads, Str -> Try(Str, [NotFound, Denied, Other(Str)])
text_of = |read, path| match read.find_first(|(file, _)| file == path) {
	Ok((_, result)) => result
	Err(_) => Err(NotFound)
}

# R-SO4, R-TF4, R-PX5: the `[toolchain]` table and the `[patch]` table of the `talon.toml`. A file that does not parse is exit 19 (Q5). The proxy prints no warning (D10).
read_toml : Reads, List(Str) -> Try({ toolchain : TomlToolchain, patches : List(Intent.PatchEntry), path : Str }, Fail)
read_toml = |read, tomls| match tomls {
	[path] => match text_of(read, path) {
		Ok(text) => {
			scanned = Intent.read({ path, text, role: Root })?
			Ok({ toolchain: scanned.intent.toolchain, patches: scanned.intent.patches, path })
		}
		Err(NotFound) => Ok({ toolchain: no_toolchain, patches: [], path: "" })
		Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
	}
	_ => Ok({ toolchain: no_toolchain, patches: [], path: "" })
}

unread : { toolchain : TomlToolchain, patches : List(Intent.PatchEntry), path : Str }
unread = { toolchain: no_toolchain, patches: [], path: "" }

# R-PX5, R-PD6, R-WS5: the `[patch]` table comes from the nearest `talon.toml` of the target file, and from no other file (no merge). The root file is `reuse`d when it is the nearest one and it was read.
# Another file is a member file of its own (role `Member`). With `Patches` the root file is the nearest one too, and its role is `Root`.
patch_table : Reads, { nearest : Try(Str, [NoToml]), root : List(Str), rooted : { toolchain : TomlToolchain, patches : List(Intent.PatchEntry), path : Str }, reuse : Bool } -> Try({ patches : List(Intent.PatchEntry), path : Str }, Fail)
patch_table = |read, x| match x.nearest {
	Err(NoToml) => Ok({ patches: [], path: "" })
	Ok(path) => {
		is_root = x.root.contains(path)
		if is_root and x.reuse {
			Ok({ patches: x.rooted.patches, path: x.rooted.path })
		} else {
			match text_of(read, path) {
				Ok(text) => {
					scanned = Intent.read({ path, text, role: if is_root Root else Member })?
					Ok({ patches: scanned.intent.patches, path })
				}
				Err(NotFound) => Ok({ patches: [], path: "" })
				Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
			}
		}
	}
}

# R-PX5, R-PA6, R-PA10: the patches of the header of the target file.
patch_of : Try(Locked, [NoPin]), { toolchain : TomlToolchain, patches : List(Intent.PatchEntry), path : Str } -> { replace : List(LadderPlan.Replace), stale : List(Patched.Entry) }
patch_of = |locked, toml| match locked {
	Ok(l) => {
		entries = Patched.entries({ rows: l.rows, patches: toml.patches, toml: toml.path })
		{ replace: Patched.replaces(entries), stale: Patched.stale(entries) }
	}
	Err(NoPin) => { replace: [], stale: [] }
}

no_config : ConfigToml.Config
no_config = { nightly: Err(Unset), min_release_age: Err(Unset), default_roc: Err(Unset), gc_age: Err(Unset), probe: { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) } }

# R-SO6, R-TF4: `default-roc` and the settings of `config.toml`. A missing file gives no setting.
read_config : Reads, Str -> Try(ConfigToml.Config, Fail)
read_config = |read, path| match text_of(read, path) {
	Ok(text) => {
		scanned = ConfigToml.read({ path, text })?
		Ok(scanned.config)
	}
	Err(NotFound) => Ok(no_config)
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
