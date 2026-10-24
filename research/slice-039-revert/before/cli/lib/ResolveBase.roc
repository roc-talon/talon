import Add
import Answer
import Closure
import Compiler
import ConfigToml
import Consent
import Db
import Epochs
import Fail
import Fx
import Gather
import Guard
import Ident
import Index
import Intent
import Ladder
import Lags
import LadderJudge
import Locked
import Mode
import Net
import Pick
import Pin
import Probe
import Project
import Release
import Report
import Roots
import Selector
import Setting
import Start
import Text
import Vars
import Walk

## The types and the helpers that the flows of `Resolve` share: `Request`, the load of the files, the pin and snapshot checks, the read of the releases, the edits of a header (slice 010 split of `Resolve`).
ResolveBase :: [].{

	## One run. `names` are the operands of `update` as typed (`json`, `json@^3`, `roc-lang/json`): `Ref.parse` and `Lookup.find` read them (slice 004).
	## `strategy` is `--strategy`. `nightly` is `TALON_NIGHTLY` (R-NS8). `compiler` is the id and the file of the `roc` on `PATH` (R-PH8; the file is new in slice 023c: a probe runs it by its path, R-PX2). `now` is `Clock.now`.
	## Slice 025 (R-NI4, R-NI5, R-DL5, R-EV6): `downloads` has the facts of the consent rules. `auto` is `TALON_AUTO_INSTALL` (`Consent.auto_install`). `allow` is `--allow-downloads` and `probe` is `--probe-downloads`
	## (`Ok(Yes)` when the flag is set). `env` is the environment of the process: the offer of a compiler (`RocInstall.offer!`) reads `TALON_NOW`, the cache dirs, the net settings and `TALON_NIGHTLY` from it.
	## `toolchain` is `ROC_TOOLCHAIN` (rank 2, R-SO2), a full compiler id (`Compiler.toolchain_of`), `Err(Unset)` when it is not set (slice 013: R-SO19 to R-SO22). It goes to `Pin.decide`.
	Request : {
		command : [Install, Update, Upgrade],
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
		downloads : { auto : [Ask, Yes, No], allow : Try(Answer, [NoFlag]), probe : Try(Answer, [NoFlag]), env : List((Str, Str)) },
		probe : { no_probe : Bool, slots : Try(U64, [Unset]) },
	}

	## Slice 031 (R-P5, R-LY4, R-FL11): the probe settings of the run. `Probe.settings` with the flag `--slots` (`request.probe.slots`), the `[resolution] probe` keys of the `talon.toml` of the run
	## (`loaded.intent.resolution.probe`) and the `[probe]` table of `config.toml` (`loaded.config.probe`).
	probe_settings : ResolveBase.Request, ResolveBase.Loaded -> Probe.Settings
	probe_settings = |request, loaded| Probe.settings({ flag_slots: request.probe.slots, project: loaded.intent.resolution.probe, user: loaded.config.probe })

	## Slice 025: the facts of the consent rules for the ladder (`Ladder.Downloads`). The flows pass them to `Ladder.run!` and `Ladder.verify!`: the mode, `--yes`, `--quiet` and `--offline` come from `request.prompt` and `request.offline`.
	ladder_downloads : ResolveBase.Request -> Ladder.Downloads
	ladder_downloads = |request| {
		auto: request.downloads.auto,
		allow: request.downloads.allow,
		yes: request.prompt.yes,
		mode: request.prompt.mode,
		quiet: request.prompt.quiet,
		offline: request.offline,
		env: request.downloads.env,
	}

	Fact : { url : Str, release : Release }

	Loaded : {
		members : List(Vars.Member),
		headers : List({ path : Str, text : Str }),
		tomls : List({ path : Str, text : Str }),
		intent : Intent,
		config : ConfigToml.Config,
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
	Ran : { probes : U64, downloads : U64, check : [Passed, Skipped, NotRun], build : [Passed, Skipped, NotRun], notes : List(Str) }

	# Steps H to J: the plan, the second read, the check of R-CC7, one `write_atomic!` call and the output.
	Finish : { scoped : List(Vars.Scoped), wants : List(Vars.Want), asked : Asked, prepared : Prepared, renames : List(Rename), snapshot : Try(U64, [None]), known : List(Fact), paths : List(Closure.Node), lags : List(Lags.Lag) }

	## Slice 036b (R-AL4, R-P5, R-AL6): what the probe rounds of the oracle loop know, for the whole command (both searches, and the tuples that the ladder dropped). `compiler` is the compiler of the facts (the held spelling,
	## then the id of the started compiler), `Err(None)` for no probe and no lookup. `checks` are the db rows that the command has. `looked` are the keys that it looked up. `count` is the number of probes that it started (the budget `probe.max`).
	## `started` is the compiler that the first probe started. `tried` are the tuples that the ladder dropped, for `Oracle.Compat.conflicts`.
	## Slice 036b2: `used` are the scan results (`Oracle.Compat.used`): one row for each release that the command scanned.
	## Slice 036c: `domain` is D (`Oracle.Compat.domain`): `Err(NotRead)` until the command reads the compiler list (the verdict `Wide`), then the ids oldest first, or `[compiler]` when the list cannot be read. `inferred` are the inferred facts of `Epochs.epochs` over D and the rows.
	Probed : { compiler : Try(Str, [None]), checks : List(Db.Fact), looked : List(Db.Key), count : U64, started : Try(Start.Started, [None]), tried : List(List({ at : U64, id : Str })), used : List({ id : Str, modules : List(Str) }), domain : Try(List(Str), [NotRead]), inferred : List(Epochs.Inferred) }

	# The tuple that the pick chose, with the facts that `finish!` and `verified!` need, and the facts of the probe rounds.
	Picked : { facts : Finish, chosen : List(Pick.Chosen), moves : List(Consent.Move), probed : Probed }

	## R-NS8 to R-NS10, R-C7, R-LY4: the settings. The priority is the flag or the environment, `talon.toml`, `config.toml`, the default.
	settings_of : ResolveBase.Request, Loaded -> Settings
	settings_of = |request, loaded| {
		intent = loaded.intent
		strategy = match request.strategy {
			Ok(s) => s
			Err(Unset) => if request.command == Upgrade Highest else intent.resolution.strategy ?? Highest
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

	## R-CC7, R-CC1: the end of each write of project files. `files` are the facts of `Guard.check_all` (the text of the first read, the text just before the write, and the spans). `edited` has the new text of each file. The files that `Guard.check_all` lets pass, in its order, are written with one `write_atomic!` call, and only those whose new text differs from the text just read. A conflict is the failure of `Guard.check_all` (exit 17). It gives the paths that were written, and makes no call when there are none.
	write_checked! : Fx, { files : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) }), edited : List({ path : Str, now : Str, new : Str }) } => Try(List(Str), Fail)
	write_checked! = |fx, run| {
		ordered = Guard.check_all(run.files)?
		changed = ordered.keep_oks(|o| run.edited.find_first(|e| e.path == o.path)).keep_if(|e| e.new != e.now)
		if changed.is_empty() return Ok([])
		match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new })) {
			Ok(_) => Ok(changed.map(|e| e.path))
			Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
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
		var $facts = ResolveBase.no_facts
		for g in got {
			release = Release.read({ path: g.path, text: g.text })?
			$facts = $facts.append({ url: g.id, release })
		}
		Ok($facts)
	}

	# The rows of the header of the current member, for `Add.decide`.
	current_rows : List(Vars.Member), Str -> List(Row)
	current_rows = |members, file| match members.find_first(|m| m.file == file) {
		Ok(m) => m.locked.rows.map(|r| { alias: r.alias, url: r.value, is_platform: r.is_platform })
		Err(_) => []
	}

	# The owner of the hash of each chosen value, with the flag that the entry moves (a new entry moves too).
	owner_rows : List(Vars.Scoped), List({ name : Str, is_platform : Bool }), List(Pick.Chosen) -> List({ owner : LadderJudge.Owner, moved : Bool })
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

	## Slice 038 (R-UP3): the chosen release is in another series than the variable has now (another group: a replace under the same alias).
	new_series : Vars.Scoped, Pick.Chosen -> Bool
	new_series = |s, c| match Ident.of_url(c.url) {
		Ok(ident) => ident.group != s.variable.group
		Err(_) => Bool.False
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
		.fold(ResolveBase.no_names, |found, text| if found.contains(text) found else found.append(text))

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
		lines = closures.join_map(|c| Closure.notes(c.walked.rows)).fold(ResolveBase.no_names, |found, line| if found.contains(line) found else found.append(line))
		if !request.prompt.quiet {
			for line in lines {
				fx.err!("${line}\n")
			}
		}
	}

	no_names : List(Str)
	no_names = []

	no_facts : List(Fact)
	no_facts = []
}

is_move : Pick.Chosen -> Bool
is_move = |c| match c.change {
	Move(_) => Bool.True
	Keep => Bool.False
}

# The owner of the hash of a chosen URL (R-PH13: the blame names `<name> <version>`).
owner_of : Str, Bool, Pick.Chosen -> Try(LadderJudge.Owner, [Foreign])
owner_of = |name, is_platform, c| Ident.of_url(c.url).map_ok(|ident| { hash: ident.hash, name, version: c.version, is_platform })

no_closures : List({ file : Str, walked : Closure.Walked })
no_closures = []
