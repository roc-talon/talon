import Add
import Answer
import Clock
import Closure
import Compiler
import Consent
import Fail
import Fx
import Gather
import Ident
import Index
import Intent
import Ladder
import Locked
import Mode
import Net
import Pick
import Pin
import Project
import Release
import Report
import Roots
import Selector
import Setting
import Text
import Vars
import Walk

## The types and the helpers that the flows of `Resolve` share: `Request`, the load of the files, the pin and snapshot checks, the read of the releases, the edits of a header (slice 010 split of `Resolve`).
ResolveBase :: [].{

	## One run. `names` are the operands of `update` as typed (`json`, `json@^3`, `roc-lang/json`): `Ref.parse` and `Lookup.find` read them (slice 004).
	## `strategy` is `--strategy`. `nightly` is `TALON_NIGHTLY` (R-NS8). `compiler` is the id and the file of the `roc` on `PATH` (R-PH8; the file is new in slice 023c: a probe runs it by its path, R-PX2). `now` is `Clock.now`.
	## `toolchain` is `ROC_TOOLCHAIN` (rank 2, R-SO2), a full compiler id (`Compiler.toolchain_of`), `Err(Unset)` when it is not set (slice 013: R-SO19 to R-SO22). It goes to `Pin.decide`.
	Request : {
		command : [Install, Update],
		names : List(Str),
		frozen : Bool,
		no_check : Bool,
		project : Project,
		roots : Roots,
		net : Net.Settings,
		now : U64,
		offline : Bool,
		strategy : Try([Highest, Lowest], [Unset]),
		nightly : Try(Bool, [Unset]),
		compiler : Try({ id : Str, path : Str }, [NoCompiler]),
		toolchain : Try(Str, [Unset]),
		snapshot : Try(Str, [Unset]),
		dry_run : Bool,
		add : { as_platform : Bool, as_alias : Try(Str, [Unset]), no_pin : Bool },
		prompt : { mode : Mode, yes : Bool, quiet : Bool, rename_keys : Try(Answer, [NoFlag]), allow_moves : Try(Answer, [NoFlag]) },
	}

	Fact : { url : Str, release : Release }

	Loaded : {
		members : List(Vars.Member),
		headers : List({ path : Str, text : Str }),
		tomls : List({ path : Str, text : Str }),
		intent : Intent,
		config : Intent.Config,
		version_file : Try(Str, [None]),
		selected : Selected,
	}

	## Slice 022 (R-SO4 to R-SO7, R-SO19): the compiler that ranks 4 to 7 select when no header has a pin and `ROC_TOOLCHAIN` is not set, with the rank (`Pin.decide` input `compiler`, `compiler_from`).
	## `load!` makes it from the `roc` on `PATH` (rank 7). `select!` replaces it. `version_file` is the id of the nearest `.roc-version` (`Compiler.version_file`), read in the same `read_files!` call as the headers.
	Selected : { id : Try(Str, [NoCompiler]), from : [Range, VersionFile, Default, Path] }

	Settings : { nightly : Bool, nightly_from : Pin.Source, strategy : [Highest, Lowest], min_age : U64 }

	# What a planned change did, for `Report.Outcome` (the line of a change is in `Edit.line`).
	Did : [Added(Report.Entry), Moved({ alias : Str, from : { name : Str, version : Str }, to : { name : Str, version : Str } }), Pinned(Str)]

	# One planned change of a header, with its line of output (R-OUT2: the texts are a proposal).
	Edit : { file : Str, op : Locked.Op, line : Str, did : Did }

	Pair : { path : Str, key : Str, value : Str }

	# A stale key of `talon.toml` that the person agreed to rename (R-NI1).
	Rename : { path : Str, from : Str, to : Str }

	Candidates : { name : Str, list : List(Index.Candidate), missing : Bool }

	# An entry of the header that `add` found and keeps (R-AD21).
	Kept : { alias : Str, name : Str, version : Str, note : Str }

	# A new name of `add`: `range` is what the pick uses (`*` with no selector, the held version for a group that another member holds, Q9).
	Fresh : { name : Str, selector : Try(Selector, [None]), text : Str, range : Str, key : Str, is_platform : Bool }

	Asked : { names : List(Str), picks : List({ alias : Str, selector : Selector }), kept : List(Kept), fresh : List(Fresh) }

	Row : { alias : Str, url : Str, is_platform : Bool }

	# A new name with the candidates of its URL form and the kind of its newest candidate (R-AD32, R-AD33).
	FreshRow : { fresh : Fresh, list : List(Index.Candidate) }

	Prepared : { rows : List(FreshRow), facts : List(Fact) }

	# What the ladder did: the number of `roc` runs and the state of the steps (R-DT5, R-LF3).
	Ran : { probes : U64, check : [Passed, Skipped, NotRun], build : [Passed, Skipped, NotRun], notes : List(Str) }

	# Steps H to J: the plan, the second read, the check of R-CC7, one `write_atomic!` call and the output.
	Finish : { scoped : List(Vars.Scoped), wants : List(Vars.Want), asked : Asked, prepared : Prepared, renames : List(Rename), snapshot : Try(U64, [None]), known : List(Fact), paths : List(Closure.Node) }

	# The tuple that the pick chose, with the facts that `finish!` and `verified!` need.
	Picked : { facts : Finish, chosen : List(Pick.Chosen), moves : List(Consent.Move) }

	# Step A of the flow: the member files and the `talon.toml` candidates in one `read_files!` call (R-PD6).
	load! : Fx, ResolveBase.Request => Try(Loaded, Fail)
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
		settings_path = match request.project.workspace {
			Ok(_) => root_toml
			Err(Standalone) => files.first().map_ok(|f| Text.join(Text.dir_of(f), "talon.toml")) ?? ""
		}
		intent = match $intents.find_first(|i| i.path == settings_path) {
			Ok(i) => i.intent
			Err(_) => empty_intent({})?
		}
		Ok({ members: checked, headers: $texts, tomls: $tomls, intent, config, version_file, selected: { id: request.compiler.map_ok(|found| found.id), from: Path } })
	}

	## R-NS8 to R-NS10, R-C7, R-LY4: the settings. The priority is the flag or the environment, `talon.toml`, `config.toml`, the default.
	settings_of : ResolveBase.Request, Loaded -> Settings
	settings_of = |request, loaded| {
		intent = loaded.intent
		strategy = match request.strategy {
			Ok(s) => s
			Err(Unset) => intent.resolution.strategy ?? Highest
		}
		(nightly, nightly_from) = match (request.nightly, intent.toolchain.nightly, loaded.config.nightly) {
			(Ok(b), _, _) => (b, Env)
			(_, Ok(b), _) => (b, Toml)
			(_, _, Ok(b)) => (b, Config)
			_ => (Bool.True, Default)
		}
		{
			nightly,
			nightly_from,
			strategy,
			min_age: Setting.pick({ flag: Err(Unset), env: Err(Unset), project: intent.resolution.min_release_age, user: loaded.config.min_release_age }) ?? 172800,
		}
	}

	# R-RP2, R-NS2, R-NS4, R-NS5, R-SO13, R-SO19, G5: a pin that stops the command, then the gate of a held compiler that no pin gave.
	# A pin has no gate (the pin compiler is checked at the first probe). `Verify` runs the `ROC_TOOLCHAIN` compiler without a gate (R-NS4).
	check_pin : Loaded, Settings, Pin.Decision, [Lock, Verify] -> Try({}, Fail)
	check_pin = |loaded, settings, decision, role| match decision.outside {
		Ok(pin) => Err(Pin.outside_failure({ pin, req_text: loaded.intent.toolchain.roc_text, nightly: settings.nightly, source: settings.nightly_from }))
		Err(None) => match decision.held {
			Err(NoCompiler) => Err(Compiler.failure(NoCompiler))
			Ok(id) => {
				gate = |held_from| Pin.gate({ compiler: id, held_from, req: loaded.intent.toolchain.roc, req_text: loaded.intent.toolchain.roc_text, nightly: settings.nightly, source: settings.nightly_from })
				match (decision.held_from, role) {
					(Pin, _) => Ok({})
					(Env, Verify) => Ok({})
					(Env, Lock) => gate(Env)
					(Range, _) => gate(Range)
					(VersionFile, _) => gate(VersionFile)
					(Default, _) => gate(Default)
					(Path, _) => gate(Path)
				}
			}
		}
	}

	## R-SO4 to R-SO7, R-SO13, R-SO14, R-SO19, R-SO22 (slice 022): the selected compiler for a command that holds the nightly. It replaces `Loaded.selected`. The steps:
	##
	## | Step | Does |
	## | --- | --- |
	## | 1 | `request.frozen`, a header pin in a member, or `request.toolchain` set: no call. `loaded` stays (the pin and rank 2 are decisions of `Pin.decide`, and `--frozen` needs no compiler, R-SO22). |
	## | 2 | `req`, `loaded.version_file` or `config.default_roc` set: one `list_dirs!` of `<cache>/toolchains` (a missing dir is empty), `Compiler.installed`. Else no call. |
	## | 3 | `req` set (rank 4): one `read_files!` of `<cache>/toolchains/<id>/.talon.json` for each installed id, `Compiler.times`. Else no call. |
	## | 4 | `Compiler.select` with `argument` and `env` unset (a `tln` command has no rank 1, R-SO19), `has_toml` true when `request.project.toml` is `Ok`, the switch of `settings_of`. `Ok(sel)`: `selected` is `sel.id` and its rank (`Range`, `VersionFile`, `Default`, `Path`). `Err(NoCompiler)`: `selected.id` is `Err(NoCompiler)` (`check_pin` fails with `Compiler.failure(NoCompiler)`, R-SO14). `Err(NoneInRange)`: the failure `Compiler.failure(NoneInRange(<range text>))` (R-SO13, exit 13). |
	select! : Fx, ResolveBase.Request, Loaded => Try(Loaded, Fail)
	select! = |fx, request, loaded| {
		pinned = loaded.members.any(|m| m.locked.roc.is_ok())
		if request.frozen or pinned or request.toolchain.is_ok() {
			Ok(loaded)
		} else {
			choose!(fx, request, loaded)
		}
	}

	## R-SO18 (slice 022): the lines of the warning for a `.roc-version` that differs from the header pin, without `warning: ` and without a line end. One line for each different pin text of the members (`Text.sorted_unique`), in
	## byte order, from `Compiler.roc_version_note` with `loaded.version_file`. No `.roc-version`, or no pin, or the same compiler: no line. `install` and `ls` print them (`warning: <line>` on stderr).
	roc_version_warnings : Loaded -> List(Str)
	roc_version_warnings = |loaded| Text.sorted_unique(loaded.members.keep_oks(|m| m.locked.roc)).keep_oks(|pin| Compiler.roc_version_note({ pin: Ok(pin), version_file: loaded.version_file }))

	# R-SO20: the note of `Pin.decide` as a list of 0 or 1 lines.
	pin_notes : Pin.Decision -> List(Str)
	pin_notes = |decision| match decision.note {
		Ok(text) => [text]
		Err(None) => []
	}

	# R-EV1, R-DT3, R-DT4: `--snapshot` wins over `[resolution] snapshot` of `talon.toml`. A `log:<n>` needs a registry: direct has none.
	snapshot_of : ResolveBase.Request, Intent -> Try(Try(U64, [None]), Fail)
	snapshot_of = |request, intent| match request.snapshot {
		Err(Unset) => Intent.direct_snapshot(intent.resolution.snapshot)
		Ok(text) => if text.starts_with("log:") {
			match U64.from_str(text.drop_prefix("log:")) {
				Ok(n) => Intent.direct_snapshot(Ok(Log(n)))
				Err(_) => Err(bad_snapshot(text))
			}
		} else {
			match Clock.parse_utc(text) {
				Ok(seconds) => Ok(Ok(seconds))
				Err(BadTime) => Err(bad_snapshot(text))
			}
		}
	}

	# The text that the first read gave (`""` for a `talon.toml` that was not there).
	loaded_text : Loaded, Str -> Str
	loaded_text = |loaded, path| match loaded.headers.find_first(|t| t.path == path) {
		Ok(t) => t.text
		Err(_) => match loaded.tomls.find_first(|t| t.path == path) {
			Ok(t) => t.text
			Err(_) => ""
		}
	}

	# The header facts of release URLs (R-AL8, R-DI7): `Gather.get!`, then `Release.read` of each text.
	read_releases! : Fx, ResolveBase.Request, List(Str) => Try(List(Fact), Fail)
	read_releases! = |fx, request, urls| {
		got = Gather.get!(fx, { roots: request.roots, net: request.net, offline: request.offline }, urls)?
		var $facts = no_facts
		for g in got {
			release = Release.read({ path: g.path, text: g.text })?
			$facts = $facts.append({ url: g.id, release })
		}
		Ok($facts)
	}

	# The first steps of `install!` and `verify!`: the files, the variables, and the pin of the compiler.
	prepared! : Fx, ResolveBase.Request, [Lock, Verify] => Try({ loaded : Loaded, built : { vars : List(Vars.Var), wants : List(Vars.Want) }, decision : Pin.Decision }, Fail)
	prepared! = |fx, request, role| {
		loaded = ResolveBase.select!(fx, request, ResolveBase.load!(fx, request)?)?
		built = Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })?
		# R-WS6: only `install` and `add` stop for a key that no header has. `update` and `verify` ignore it (R-I5).
		if role == Lock and request.command == Install {
			Vars.check_keys(built.wants)?
		}
		settings = ResolveBase.settings_of(request, loaded)
		decision = Pin.decide({
			members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: Bool.False }),
			compiler: loaded.selected.id,
			compiler_from: loaded.selected.from,
			toolchain: request.toolchain,
			role,
			req: loaded.intent.toolchain.roc,
			nightly: settings.nightly,
			no_check: request.no_check,
		})?
		Ok({ loaded, built, decision })
	}

	# The rows of the header of the current member, for `Add.decide`.
	current_rows : List(Vars.Member), Str -> List(Row)
	current_rows = |members, file| match members.find_first(|m| m.file == file) {
		Ok(m) => m.locked.rows.map(|r| { alias: r.alias, url: r.value, is_platform: r.is_platform })
		Err(_) => []
	}

	# The owner of the hash of each chosen value, with the flag that the entry moves (a new entry moves too).
	owner_rows : List(Vars.Scoped), List({ name : Str, is_platform : Bool }), List(Pick.Chosen) -> List({ owner : Ladder.Owner, moved : Bool })
	owner_rows = |scoped, news, chosen| {
		count = scoped.len()
		var_rows = scoped.map2(chosen.take_first(count), |s, c| (s.variable.name ?? s.variable.group.form, s.variable.is_platform, c, is_move(c)))
		new_rows = news.map2(chosen.drop_first(count), |n, c| (n.name, n.is_platform, c, Bool.True))
		var_rows.concat(new_rows).keep_oks(|(name, is_platform, c, moved)| owner_of(name, is_platform, c).map_ok(|owner| { owner, moved }))
	}

	# R-H1: a header entry moves to the URL that was chosen, for each use of the variable.
	set_edits : Vars.Scoped, Pick.Chosen -> List(Edit)
	set_edits = |s, c| {
		name = s.variable.name ?? s.variable.group.form
		s.variable.uses
			.keep_if(|u| u.url != c.url)
			.map(
				|u| {
					file: u.file,
					op: Set({ alias: u.alias, url: c.url }),
					line: "~ ${u.alias}: ${name} ${u.version} -> ${c.version}",
					did: Moved({ alias: u.alias, from: { name, version: u.version }, to: { name, version: c.version } }),
				},
			)
	}

	# R-SE7, U2 of slice 009: the notice for a platform entry that moves (once for each change of the version, also when 2 members use it).
	moved_platform_notes : List(Vars.Scoped), List(Pick.Chosen) -> List(Str)
	moved_platform_notes = |scoped, chosen| scoped
		.map2(chosen, |s, c| (s, c))
		.keep_if(|(s, _)| s.variable.is_platform)
		.join_map(|(s, c)| ResolveBase.set_edits(s, c))
		.keep_oks(
			|e| match e.did {
				Moved(m) => Ok(Add.platform_note({ from: m.from, to: m.to }))
				_ => Err(NotMoved)
			},
		)
		.fold(no_names, |found, text| if found.contains(text) found else found.append(text))

	## Slice 010 (R-AL2): the entries of a member after the planned edits. A `Set` or `Replace` changes the value of an entry, an `Add` appends one. The pin write is no entry.
	entries_after : Vars.Member, List(Edit) -> List(Closure.Entry)
	entries_after = |member, edits| {
		ops = edits.keep_if(|e| e.file == member.file).map(|e| e.op)
		start = member.locked.rows.map(|r| { alias: r.alias, value: r.value, is_platform: r.is_platform })
		ops.fold(
			start,
			|rows, op| match op {
				Set({ alias, url }) => rows.map(|r| if r.alias == alias { ..r, value: url } else r)
				Replace({ alias, url }) => rows.map(|r| if r.alias == alias { ..r, value: url } else r)
				Add({ alias, url, is_platform }) => rows.append({ alias, value: url, is_platform })
				Remove(alias) => rows.keep_if(|r| r.alias != alias)
				Pin(_) => rows
			},
		)
	}

	## Slice 010: the headers that the pick read, as the nodes of the closure walk (D3). The pick keeps no alias, so the aliases of these nodes are empty. A platform entry is the first entry.
	known_nodes : List(Fact) -> List(Closure.Node)
	known_nodes = |facts| facts.map(|f| Pick.node_of(f))

	## Slice 010 (R-CM2, R-H7, R-AL2): the closure walk of the members, in the order of the list. A node that one walk read is not read again by the next. A failure of one walk is the failure.
	closure! : Fx, Request, { members : List({ file : Str, entries : List(Closure.Entry) }), known : List(Closure.Node) } => Try(List({ file : Str, walked : Closure.Walked }), Fail)
	closure! = |fx, request, facts| {
		var $nodes = facts.known
		var $done = no_closures
		for m in facts.members {
			run = Walk.run!(fx, { roots: request.roots, net: request.net, offline: request.offline, file: m.file, entries: m.entries, known: $nodes })?
			$nodes = run.nodes
			$done = $done.append({ file: m.file, walked: run.walked })
		}
		Ok($done)
	}

	## Slice 010 (R-C8, question Q11): the warnings of the closures on stderr, one line for each text, no repeat. `--quiet` hides them (question Q22).
	closure_notes! : Fx, Request, List({ file : Str, walked : Closure.Walked }) => {}
	closure_notes! = |fx, request, closures| {
		lines = closures.join_map(|c| Closure.notes(c.walked.rows)).fold(no_names, |found, line| if found.contains(line) found else found.append(line))
		if !request.prompt.quiet {
			for line in lines {
				fx.err!("${line}\n")
			}
		}
	}
}

# Steps 2 to 4 of `select!`.
choose! : Fx, ResolveBase.Request, Loaded => Try(Loaded, Fail)
choose! = |fx, request, loaded| {
	req = loaded.intent.toolchain.roc
	has_toml = request.project.toml.is_ok()
	default = loaded.config.default_roc
	lists = req.is_ok() or (loaded.version_file.is_ok() and !has_toml) or default.is_ok()
	dir = Text.join(request.roots.cache, "toolchains")
	installed = if lists {
		match fx.list_dirs!([dir]) {
			[Ok(found)] => Compiler.installed(found)
			_ => []
		}
	} else {
		[]
	}
	times = if req.is_ok() and !installed.is_empty() {
		paths = installed.map(|id| Text.join(Text.join(dir, id), ".talon.json"))
		Compiler.times(installed.map2(fx.read_files!(paths), |id, text| { id, text }))
	} else {
		[]
	}
	settings = ResolveBase.settings_of(request, loaded)
	picked = Compiler.select({ argument: Err(Unset), env: Err(Unset), req, nightly: settings.nightly, has_toml, version_file: loaded.version_file, default, path: request.compiler.map_ok(|found| found.id), installed, times })
	match picked {
		Ok(sel) => Ok({ ..loaded, selected: { id: Ok(sel.id), from: rank_from(sel.rank) } })
		Err(NoCompiler) => Ok({ ..loaded, selected: { id: Err(NoCompiler), from: Path } })
		Err(NoneInRange) => Err(Compiler.failure(NoneInRange(loaded.intent.toolchain.roc_text ?? "")))
	}
}

# A command has no rank 1 and rank 2 is a decision of `Pin.decide`, so `select` gives only these ranks.
rank_from : Compiler.Rank -> [Range, VersionFile, Default, Path]
rank_from = |rank| match rank {
	Range => Range
	VersionFile => VersionFile
	Default => Default
	_ => Path
}

# R-NS10, R-C7: `config.toml` is read in the same `read_files!` call as the headers. A file that is not there gives no setting.
read_config! : Fx, Str, Try(Str, [NotFound, Denied, Other(Str)]) => Try(Intent.Config, Fail)
read_config! = |fx, path, result| match result {
	Ok(text) => {
		read = Intent.read_config({ path, text })?
		for w in read.warnings {
			fx.err!("warning: ${w}\n")
		}
		Ok(read.config)
	}
	Err(NotFound) => Ok({ nightly: Err(Unset), min_release_age: Err(Unset), default_roc: Err(Unset) })
	Err(_) => Err(Fail.new(Environment, "cannot read ${path}"))
}

bad_snapshot : Str -> Fail
bad_snapshot = |text| Fail.new(Usage, "--snapshot '${text}' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z.")

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

no_facts : List(Fact)
no_facts = []

is_move : Pick.Chosen -> Bool
is_move = |c| match c.change {
	Move(_) => Bool.True
	Keep => Bool.False
}

# The owner of the hash of a chosen URL (R-PH13: the blame names `<name> <version>`).
owner_of : Str, Bool, Pick.Chosen -> Try(Ladder.Owner, [Foreign])
owner_of = |name, is_platform, c| Ident.of_url(c.url).map_ok(|ident| { hash: ident.hash, name, version: c.version, is_platform })

no_names : List(Str)
no_names = []

no_closures : List({ file : Str, walked : Closure.Walked })
no_closures = []
