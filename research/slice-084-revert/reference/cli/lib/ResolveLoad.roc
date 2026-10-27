import Compiler
import ConfigToml
import Fail
import Fx
import Intent
import Locked
import NightlyPlan
import Pin
import Project
import ResolveBase
import ResolveSelect
import Roots
import Text
import Vars

## The first steps of `install`, `update` and `verify` (slice 031b: split from `ResolveBase`): the load of the files, and the pin of the compiler.
ResolveLoad :: [].{

	# Step A of the flow: the member files and the `talon.toml` candidates in one `read_files!` call (R-PD6).
	load! : Fx, ResolveBase.Request => Try(ResolveBase.Loaded, Fail)
	load! = |fx, request| {
		files = member_files(request.project)?
		root = match request.project.workspace {
			Ok(ws) => ws.root
			Err(Standalone) => files.first().map_ok(|f| Text.dir_of(f)) ?? ""
		}
		candidates = files.map(|f| Intent.paths({ member: f, root }))
		toml_paths = candidates.join_map(|c| c).fold([], |found, path| if found.contains(path) found else found.append(path))
		config_path = Roots.item(request.roots, Config)
		version_path = match request.project.roc_version {
			Ok(path) => [path]
			Err(None) => []
		}
		results = fx.read_files!(files.concat(toml_paths).append(config_path).concat(version_path))
		headers = files.map2(results.take_first(files.len()), |path, result| (path, result))
		toml_results = toml_paths.map2(results.drop_first(files.len()).take_first(toml_paths.len()), |path, result| (path, result))
		after = files.len() + toml_paths.len()
		config_result = match results.get(after) {
			Ok(r) => r
			Err(_) => Err(NotFound)
		}
		config = read_config!(fx, config_path, config_result)?
		version_file = match (version_path, results.get(after + 1)) {
			([path], Ok(Ok(text))) => match Compiler.version_file({ path, text })? {
				Ok(id) => Ok(id)
				Err(Empty) => Err(None)
			}
			([_], Ok(Err(NotFound))) => Err(None)
			([path], _) => return Err(Fail.new(Environment, "cannot read ${path}"))
			_ => Err(None)
		}
		var $texts = no_texts
		for (path, result) in headers {
			match result {
				Ok(text) => {
					$texts = $texts.append({ path, text })
				}
				Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
			}
		}
		var $tomls = no_texts
		for (path, result) in toml_results {
			match result {
				Ok(text) => {
					$tomls = $tomls.append({ path, text })
				}
				Err(NotFound) => {}
				Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
			}
		}
		root_toml = Text.join(root, "talon.toml")
		var $intents = no_intents
		for t in $tomls {
			role = match request.project.workspace {
				Ok(_) => if t.path == root_toml Root else Member
				Err(Standalone) => Root
			}
			read = Intent.read({ path: t.path, text: t.text, role })?
			for w in read.warnings {
				fx.err!("warning: ${w}\n")
			}
			$intents = $intents.append({ path: t.path, intent: read.intent })
		}
		members = files.map2(
			candidates,
			|file, paths| {
				locked = match $texts.find_first(|t| t.path == file) {
					Ok(t) => Locked.read({ path: file, text: t.text })
					Err(_) => Err(Fail.new(Environment, "cannot read ${file}"))
				}
				toml = match paths.find_first(|p| $intents.any(|i| i.path == p)) {
					Ok(p) => match $intents.find_first(|i| i.path == p) {
						Ok(i) => Ok({ path: i.path, intent: i.intent })
						Err(_) => Err(NoToml)
					}
					Err(_) => Err(NoToml)
				}
				(file, locked, toml)
			},
		)
		checked = members.map_try(|(file, locked, toml)| locked.map_ok(|l| { file, locked: l, toml }))?
		# R-TG3, R-TG4: a bad `[build] target` is exit 19 for the member that uses the file, when it is an app.
		for m in checked {
			match m.toml {
				Ok(t) => Intent.build_check({ path: t.path, bad: t.intent.build.bad, kind: m.locked.kind })?
				Err(NoToml) => {}
			}
		}
		settings_path = match request.project.workspace {
			Ok(_) => root_toml
			Err(Standalone) => files.first().map_ok(|f| Text.join(Text.dir_of(f), "talon.toml")) ?? ""
		}
		intent = match $intents.find_first(|i| i.path == settings_path) {
			Ok(i) => i.intent
			Err(_) => empty_intent({})?
		}
		Ok({ members: checked, headers: $texts, tomls: $tomls, intent, config, version_file, selected: { id: request.compiler.map_ok(|found| found.id), from: Path, note: Err(None) } })
	}

	# The first steps of `install!` and `verify!`: the files, the variables, and the pin of the compiler.
	prepared! : Fx, ResolveBase.Request, [Lock, Verify] => Try({ loaded : ResolveBase.Loaded, built : { vars : List(Vars.Var), wants : List(Vars.Want) }, decision : Pin.Decision }, Fail)
	prepared! = |fx, request, role| {
		loaded = ResolveSelect.select!(fx, request, ResolveLoad.load!(fx, request)?)?
		built = Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })?
		# R-WS6: only `install` and `add` stop for a key that no header has. `update` and `verify` ignore it (R-I5).
		if role == Lock and request.command == Install {
			Vars.check_keys(built.wants)?
		}
		decision = ResolveLoad.decide(request, loaded, role)?
		Ok({ loaded, built, decision })
	}

	## `Pin.decide` for the files of the run (R-SO19 to R-SO21). `prepared!` calls it, and `InstallFlow.install_with!` calls it again with `with_pick` when the run picked a compiler.
	decide : ResolveBase.Request, ResolveBase.Loaded, [Lock, Verify] -> Try(Pin.Decision, Fail)
	decide = |request, loaded, role| {
		settings = ResolveBase.settings_of(request, loaded)
		# Slice 039 (Q3): the members of a free nightly can have different pins.
		unified = NightlyPlan.unify({ members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: Bool.False }), free: request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Free })
		Pin.decide({
			members: unified.members,
			compiler: loaded.selected.id,
			compiler_from: loaded.selected.from,
			toolchain: request.toolchain,
			role,
			req: loaded.intent.toolchain.roc,
			nightly: settings.nightly,
			no_check: request.no_check,
		})
	}

	## R-SO19, R-SO23, R-SO24 (slice 072e): the files of the run with the picked compiler (`HeldRoc.picked!`) as the selected one. The rank is `Default`: the pick is the default compiler of the run, as the download sets it (R-SO15).
	with_pick : ResolveBase.Loaded, Str -> ResolveBase.Loaded
	with_pick = |loaded, id| { ..loaded, selected: { id: Ok(id), from: Default, note: Err(None) } }
}

# R-NS10, R-C7: `config.toml` is read in the same `read_files!` call as the headers. A file that is not there gives no setting.
read_config! : Fx, Str, Try(Str, [NotFound, Denied, Other(Str)]) => Try(ConfigToml.Config, Fail)
read_config! = |fx, path, result| match result {
	Ok(text) => {
		read = ConfigToml.read({ path, text })?
		for w in read.warnings {
			fx.err!("warning: ${w}\n")
		}
		Ok(read.config)
	}
	Err(NotFound) => Ok({ nightly: Err(Unset), min_release_age: Err(Unset), min_release_age_exclude: [], default_roc: Err(Unset), gc_age: Err(Unset), probe: { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) } })
	Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
}

no_texts : List({ path : Str, text : Str })
no_texts = []

no_intents : List({ path : Str, intent : Intent })
no_intents = []

# The intent of a missing `talon.toml`: the read of the empty text.
empty_intent : {} -> Try(Intent, Fail)
empty_intent = |_| Intent.read({ path: "talon.toml", text: "", role: Root }).map_ok(|r| r.intent)

# R-PD5: the members of a workspace, or the current file of a standalone project.
member_files : Project -> Try(List(Str), Fail)
member_files = |project| match project.workspace {
	Ok(ws) => if ws.members.is_empty() Err(Fail.new(Usage, "the workspace at ${ws.root} has no member files")) else Ok(ws.members)
	Err(Standalone) => match project.file {
		Ok(file) => Ok([file])
		Err(NoCurrent) => Err(Fail.new(Usage, "no project file found. Pass --file <path>."))
	}
}
