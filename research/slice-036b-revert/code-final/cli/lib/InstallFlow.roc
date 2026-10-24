import Add
import BuildSkip
import Clock
import Closure
import Consent
import Fail
import Frozen
import Fx
import Ident
import IntentEdit
import Ladder
import Locked
import Pick
import PickFlow
import PickLoop
import Pin
import Prompt
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect
import Text
import Vars

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

Edit : ResolveBase.Edit

Pair : ResolveBase.Pair

Rename : ResolveBase.Rename

Kept : ResolveBase.Kept

Asked : ResolveBase.Asked

Row : ResolveBase.Row

FreshRow : ResolveBase.FreshRow

Ran : ResolveBase.Ran

Finish : ResolveBase.Finish

## The flow of `install`, `update` and `add` (`Resolve.install!`): the pick, the plan, the ladder and the write. Split from `Resolve` in slice 010.
InstallFlow :: [].{

	## The flow of `Resolve.install!`. The steps are in the doc of `Resolve.install!`.
	install! : Fx, Request => Try(Report.Outcome, Fail)
	install! = |fx, request| {
		start = ResolveLoad.prepared!(fx, request, Lock)?
		loaded = start.loaded
		built = start.built
		decision = start.decision
		# R-SO18: `install` and `add` (not `update`) warn when `.roc-version` and the header pin differ.
		if request.command == Install {
			for line in ResolveBase.roc_version_warnings(loaded) {
				fx.err!("warning: ${line}\n")
			}
		}
		if request.frozen {
			frozen!(fx, request, loaded, built, decision)?
			Ok(idle(request, request.now))
		} else {
			resolve!(fx, request, loaded, built, decision)
		}
	}
}

# What the new names of `add` do to the header and to `talon.toml`, with the notes and the entries that `add` finds in the header (R-AD21).
Planned : { header : List(Row), edits : List(Edit), pairs : List(Pair), kept : List(Kept), notes : List(Str) }

# The facts of a finished run for `Report.Outcome`. `touched` are the files that were written (planned, with `--dry-run`).
Done : { at : U64, touched : List(Str), edits : List(Edit), pairs : List(Pair), renames : List(Rename), kept : List(Kept), notes : List(Str), ran : Ran }

# The outcome of a run that changes nothing (`--frozen`, R-LF1).
idle : Request, U64 -> Report.Outcome
idle = |request, at| {
	at: Clock.format_utc(at),
	probes: 0,
	downloads: 0,
	dry_run: request.dry_run,
	check: NotRun,
	build: NotRun,
	added: [],
	moved: [],
	kept: [],
	pinned: Err(None),
	toml: [],
	renamed: [],
	notes: [],
	written: [],
}

# `--frozen` (R-LF1): the pure check, then the hash check of the packages of the header. No index call, no write.
frozen! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try({}, Fail)
frozen! = |fx, request, loaded, built, decision| {
	settings = ResolveBase.settings_of(request, loaded)
	scoped = Vars.scope({ command: Install, names: [], selectors: [], vars: built.vars })?
	Frozen.check({ scoped, wants: built.wants, outside: decision.outside, req_text: loaded.intent.toolchain.roc_text, nightly: settings.nightly })?
	closures = ResolveBase.closure!(fx, request, { members: loaded.members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, []) }), known: [] })?
	ResolveBase.closure_notes!(fx, request, closures)
	fx.out!("the header satisfies talon.toml\n")
	Ok({})
}

# `install`, `update` and `add`: the steps of the flow in the slice file.
resolve! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try(Report.Outcome, Fail)
resolve! = |fx, request, loaded, built, decision| {
	settings = ResolveBase.settings_of(request, loaded)
	ResolveBase.check_pin(loaded, settings, decision, Lock)?
	pin_notes = ResolveBase.pin_notes(decision)
	for note in pin_notes {
		fx.out!("note: ${note}\n")
	}
	snapshot = ResolveSelect.snapshot_of(request, loaded.intent)?
	# R-SO22, U3: `--no-check` runs no probe and no lookup. Else the probe rounds use the held compiler.
	held = if request.no_check Err(None) else decision.held.map_err(|_| None)
	ready = PickFlow.prepare!(fx, request, loaded, built, settings, snapshot, held)?
	first = PickFlow.search!(fx, request, ready, PickLoop.start(ready.setup, ready.prepared.facts))?
	outcome = attempts!(fx, request, loaded, ready, { picked: first, first: Err(None) })?
	# R-SO20: the note of the pin is the first of `data.notes`.
	Ok({ ..outcome, notes: pin_notes.concat(outcome.notes) })
}

# R-AL6, R-PH13 (slice 036b): the ladder runs on the tuple of the pick. A failure of the ladder that is about the tuple (`Fail.again`) goes back to the oracle loop as a conflict, on the releases that the ladder blames (all of the tuple when it names none).
# The next tuple is picked with the facts that the command has. The line `note: tuple dropped: ...` says it (a proposal, TW24). When no other tuple exists, the failure of the command is the first failure of the ladder.
attempts! : Fx, ResolveBase.Request, Loaded, PickFlow.Ready, { picked : ResolveBase.Picked, first : Try(Fail, [None]) } => Try(Report.Outcome, Fail)
attempts! = |fx, request, loaded, ready, run| {
	picked = run.picked
	match finish!(fx, request, loaded, picked.facts, picked.chosen, picked.moves, picked.probed) {
		Ok(outcome) => Ok(outcome)
		Err(fail) => match fail.again {
			Err(None) => Err(fail)
			Ok(again) => {
				fx.out!("note: tuple dropped: ${fail.message.drop_prefix("no tuple works: ")}\n")
				first = run.first ?? fail
				probed = { ..picked.probed, count: again.probes, tried: picked.probed.tried.append(dropped(picked.chosen, again.blamed)) }
				match PickFlow.search!(fx, request, ready, { facts: picked.facts.known, paths: picked.facts.paths, probed }) {
					Ok(next) => attempts!(fx, request, loaded, ready, { picked: next, first: Ok(first) })
					Err(other) => if other.kind == NoTuple Err(first) else Err(other)
				}
			}
		}
	}
}

# The conflict of a dropped tuple: the chosen releases (by the place of their slot) that the ladder blames by hash, or the whole tuple.
dropped : List(Pick.Chosen), List(Str) -> List({ at : U64, id : Str })
dropped = |chosen, blamed| {
	all = chosen.map_with_index(|c, i| { at: i, id: c.url })
	named = all.keep_if(|x| Ident.of_url(x.id).map_ok(|ident| blamed.contains(ident.hash)) ?? Bool.False)
	if named.is_empty() all else named
}

no_edits : List(Edit)
no_edits = []

no_pairs : List(Pair)
no_pairs = []

fresh_plan : ResolveBase.Request, Loaded, List(FreshRow), List(Pick.Chosen) -> Try(Planned, Fail)
fresh_plan = |request, loaded, rows, chosen| {
	file = request.project.file ?? ""
	start = { header: ResolveBase.current_rows(loaded.members, file), edits: no_edits, pairs: no_pairs, kept: no_kept, notes: no_names }
	rows.map2(chosen, |r, c| (r, c)).fold_try(start, |acc, (r, c)| fresh_step(request, loaded, file, acc, r, c))
}

# `Add.decide` of one new name (R-AD23 to R-AD31): the header edit, the `talon.toml` key and the note.
fresh_step : ResolveBase.Request, Loaded, Str, Planned, FreshRow, Pick.Chosen -> Try(Planned, Fail)
fresh_step = |request, loaded, file, acc, row, c| {
	f = row.fresh
	plan = Add.decide({
		selector: f.selector,
		chosen: { name: f.name, url: c.url, kind: if f.is_platform Platform else Package },
		platform_flag: f.is_platform,
		no_pin: request.add.no_pin,
		as_alias: request.add.as_alias,
		header: acc.header,
	})?
	path = match loaded.members.find_first(|m| m.file == file) {
		Ok({ toml: Ok(t), .. }) => t.path
		_ => Text.join(Text.dir_of(file), "talon.toml")
	}
	pairs = match plan.toml {
		Ok({ key, value }) => [{ path, key, value }]
		Err(Nothing) => []
	}
	notes = match plan.note {
		Ok(text) => if plan.header == Replace [text] else []
		Err(None) => []
	}
	state = { ..acc, pairs: acc.pairs.concat(pairs), notes: acc.notes.concat(notes) }
	match plan.header {
		Insert => {
			edit = { file, op: Add({ alias: plan.alias, url: c.url, is_platform: f.is_platform }), line: "+ ${plan.alias}: ${f.name} ${c.version}", did: Added({ alias: plan.alias, name: f.name, version: c.version }) }
			Ok({ ..state, header: acc.header.append({ alias: plan.alias, url: c.url, is_platform: f.is_platform }), edits: acc.edits.append(edit) })
		}
		Replace => match acc.header.find_first(|r| r.alias == plan.alias) {
			Ok(old) => if old.url == c.url {
				Ok(state)
			} else {
				Ok({ ..state, edits: acc.edits.append(replace_edit(file, plan.alias, old.url, { name: f.name, version: c.version, url: c.url })) })
			}
			Err(_) => Ok(state)
		}
		_ => {
			name = name_of(plan.url)
			note = match plan.note {
				Ok(text) => text
				Err(None) => "${plan.alias}: ${name} ${version_of(plan.url)} is in the header\nRun tln update ${plan.alias} to move it."
			}
			Ok({ ..state, kept: acc.kept.append({ alias: plan.alias, name, version: version_of(plan.url), note }) })
		}
	}
}

# R-AD31, R-AD38: the edit that replaces the value of an entry. An unmanaged old value (R-H4) needs `Replace`: `Set` refuses it. A release is moved with `Set`.
replace_edit : Str, Str, Str, { name : Str, version : Str, url : Str } -> Edit
replace_edit = |file, alias, old, new| match Ident.of_url(old) {
	Ok(ident) => {
		from = { name: ident.name ?? old, version: ident.version }
		{
			file,
			op: Set({ alias, url: new.url }),
			line: "~ ${alias}: ${from.name} ${from.version} -> ${new.version}",
			did: Moved({ alias, from, to: { name: new.name, version: new.version } }),
		}
	}
	Err(Foreign) => {
		file,
		op: Replace({ alias, url: new.url }),
		line: "~ ${alias}: ${old} -> ${new.name} ${new.version}",
		did: Moved({ alias, from: { name: old, version: "" }, to: { name: new.name, version: new.version } }),
	}
}

# The name and the version of a release URL. A URL that Talon cannot read stands for itself.
name_of : Str -> Str
name_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.name ?? url
	Err(Foreign) => url
}

version_of : Str -> Str
version_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.version
	Err(Foreign) => ""
}

no_ran : Ran
no_ran = { probes: 0, downloads: 0, check: NotRun, build: NotRun, notes: [] }

finish! : Fx, ResolveBase.Request, Loaded, Finish, List(Pick.Chosen), List(Consent.Move), ResolveBase.Probed => Try(Report.Outcome, Fail)
finish! = |fx, request, loaded, facts, chosen, moves, probed| {
	scoped = facts.scoped
	wants = facts.wants
	count = scoped.len()
	var_chosen = chosen.take_first(count)
	want_chosen = chosen.drop_first(count).take_first(wants.len())
	fresh_chosen = chosen.drop_first(count + wants.len())
	pick_notes = chosen.keep_oks(|c| c.note).fold(no_names, |found, note| if found.contains(note) found else found.append(note))
	for note in pick_notes {
		fx.out!("note: ${note}\n")
	}
	sets = scoped.map2(var_chosen, |s, c| (s, c)).join_map(|(s, c)| ResolveBase.set_edits(s, c))
	platform_notes = ResolveBase.moved_platform_notes(scoped, var_chosen)
	for note in platform_notes {
		fx.out!("note: ${note}\n")
	}
	adds = wants.map2(want_chosen, |w, c| (w, c)).map_try(|(w, c)| add_edit(loaded.members, w, c))?
	plan = fresh_plan(request, loaded, facts.prepared.rows, fresh_chosen)?
	changes = sets.concat(adds.join_map(|a| a)).concat(plan.edits)
	decision = Pin.decide({
		members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: changes.any(|e| e.file == m.file) }),
		compiler: loaded.selected.id,
		compiler_from: loaded.selected.from,
		toolchain: request.toolchain,
		role: Lock,
		req: loaded.intent.toolchain.roc,
		nightly: ResolveBase.settings_of(request, loaded).nightly,
		no_check: request.no_check,
	})?
	pins = decision.writes.map(|w| { file: w.file, op: Pin(w.id), line: "+ roc: ${w.id}", did: Pinned(w.id) })
	edits = changes.concat(pins)
	pairs = pairs_of(request, loaded.members, scoped, facts.asked)?.concat(plan.pairs)
	for note in plan.notes {
		fx.out!("note: ${note}\n")
	}
	kept = facts.asked.kept.concat(plan.kept)
	for k in kept {
		fx.out!("${k.note}\n")
	}
	closures = ResolveBase.closure!(
		fx,
		request,
		{ members: loaded.members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, changes) }), known: ResolveBase.known_nodes(facts.known).concat(facts.paths) },
	)?
	ResolveBase.closure_notes!(fx, request, closures)
	news = wants.map(|w| { name: w.name ?? w.key, is_platform: Bool.False }).concat(facts.prepared.rows.map(|r| { name: r.fresh.name, is_platform: r.fresh.is_platform }))
	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision, closures, probed })?
	confirm_moves!(fx, request, moves)?
	touched = write!(fx, request, loaded, edits, pairs, facts.renames)?
	if touched.is_empty() and kept.is_empty() {
		fx.out!("nothing to change\n")
	}
	Ok(
		outcome_of(
			request,
			{
				at: match facts.snapshot {
					Ok(time) => time
					Err(None) => request.now
				},
				touched,
				edits,
				pairs,
				renames: facts.renames,
				kept,
				notes: pick_notes.concat(platform_notes).concat(plan.notes).concat(ran.notes),
				ran,
			},
		),
	)
}

# R-SP16, R-SP17, R-SP26, R-NI3: the report of the moves on stderr, then the prompt. It is the last step before the write. `--dry-run` asks nothing. No: exit 13.
confirm_moves! : Fx, ResolveBase.Request, List(Consent.Move) => Try({}, Fail)
confirm_moves! = |fx, request, moves| {
	if moves.is_empty() return Ok({})
	consent = Consent.move_held(moves)
	fx.err!(consent.report)
	if request.dry_run return Ok({})
	done = match Prompt.ask!(fx, consent.prompt, { mode: request.prompt.mode, yes: request.prompt.yes, quiet: request.prompt.quiet, flag: request.prompt.allow_moves }) {
		Ok(d) => d
		Err(fail) => return Err({ ..fail, details: Ok(consent.details) })
	}
	if done.answer == Yes Ok({}) else Err(Consent.declined(moves))
}

outcome_of : ResolveBase.Request, Done -> Report.Outcome
outcome_of = |request, done| {
	used = done.edits.keep_if(|e| done.touched.contains(e.file))
	added = used.keep_oks(
		|e| match e.did {
			Added(entry) => Ok(entry)
			_ => Err(NotAdded)
		},
	)
	moved = used.keep_oks(
		|e| match e.did {
			Moved(move) => Ok(move)
			_ => Err(NotMoved)
		},
	)
	pins = used.keep_oks(
		|e| match e.did {
			Pinned(id) => Ok(id)
			_ => Err(NotPinned)
		},
	)
	{
		at: Clock.format_utc(done.at),
		probes: done.ran.probes,
		downloads: done.ran.downloads,
		dry_run: request.dry_run,
		check: done.ran.check,
		build: done.ran.build,
		added,
		moved,
		kept: done.kept.map(|k| { alias: k.alias, name: k.name, version: k.version }),
		pinned: match pins {
			[id, ..] => Ok(id)
			[] => Err(None)
		},
		toml: done.pairs.keep_if(|p| done.touched.contains(p.path)),
		renamed: done.renames.keep_if(|r| done.touched.contains(r.path)),
		notes: done.notes,
		written: if request.dry_run [] else done.touched,
	}
}

# Slice 006: the place of the probe ladder in the flow (Resolution 4, R-LD4, R-LD5, R-PH9, R-PH10): after the choice and before the write, when a header changes (R-AL6).
# `facts.changes` are the planned changes of the headers (the pin write is not a change that makes the ladder run). `facts.decision` is the `Pin.decide` of `finish!`. `facts.news` are the wants
# and the new names, in the order of the slots after `facts.scoped`.
#
# | Case | What the body does |
# | --- | --- |
# | `request.no_check` (R-BL6, R-LF3) | No `Fx` call. Prints `check: skipped` (a proposal, TW24) and gives `Skipped` for both steps. A pin is not written (`Pin.decide`, R-H6). |
# | Else | Builds `Ladder.run!` input: one `Ladder.Member` for each member file in `facts.changes` (its `kind` and its text from `loaded`, its `ops` from the changes and from the pin write of `facts.decision.writes`), the `Ladder.Owner` of each hash of the candidate header (the uses of `facts.scoped` and the chosen URLs, with `Vars` names), `moved` (the chosen values that move: `Pick.Chosen.change` is `Move` and the new ones), `path_roc` is `request.compiler`, `held` is `facts.decision.held`, `roots` is `request.roots`. Calls `Ladder.run!`. The probes are 3 for an app and 2 for a package or a platform (D12). |
ladder! : Fx, ResolveBase.Request, Loaded, { scoped : List(Vars.Scoped), news : List({ name : Str, is_platform : Bool }), chosen : List(Pick.Chosen), changes : List(Edit), decision : Pin.Decision, closures : List({ file : Str, walked : Closure.Walked }), probed : ResolveBase.Probed } => Try(Ran, Fail)
ladder! = |fx, request, loaded, facts| {
	if request.no_check {
		fx.out!("check: skipped\n")
		Ok({ probes: 0, downloads: 0, check: Skipped, build: Skipped, notes: [] })
	} else {
		rows = ResolveBase.owner_rows(facts.scoped, facts.news, facts.chosen)
		files = facts.changes.map(|e| e.file).fold(no_names, |found, file| if found.contains(file) found else found.append(file))
		members = files.keep_oks(|file| ladder_member(loaded, facts.changes, facts.decision, file))
		done = Ladder.run!(
			fx,
			{
				roots: request.roots,
				now: request.now,
				path_roc: request.compiler,
				held: facts.decision.held ?? "",
				members,
				owners: rows.map(|r| r.owner),
				moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
				downloads: ResolveBase.ladder_downloads(request),
				probe: ResolveBase.probe_settings(request, loaded),
				no_probe: request.probe.no_probe,
				closures: facts.closures,
				loop: { started: facts.probed.started, looked: facts.probed.looked, checks: facts.probed.checks, count: facts.probed.count },
			},
		)?
		Ok({
			probes: done.probes,
			downloads: done.downloads,
			check: Passed,
			build: BuildSkip.state({ apps: members.count_if(|m| m.kind == App), skipped: done.skipped }),
			notes: done.notes,
		})
	}
}

# A member file with its header text and the edits for the candidate: the planned changes, and the pin that the command writes after the check (R-RP3).
ladder_member : Loaded, List(Edit), Pin.Decision, Str -> Try(Ladder.Member, [NoMember])
ladder_member = |loaded, changes, decision, file| match loaded.members.find_first(|m| m.file == file) {
	Ok(m) => Ok({
		file,
		kind: m.locked.kind,
		text: ResolveBase.loaded_text(loaded, file),
		ops: changes.keep_if(|e| e.file == file).map(|e| e.op).concat(decision.writes.keep_if(|w| w.file == file).map(|w| Pin(w.id))),
	})
	Err(_) => Err(NoMember)
}

# R-I5, R-I6: a key that no header has is added to the header of the one member under its `talon.toml` (the decision of `tln add`).
add_edit : List(Vars.Member), Vars.Want, Pick.Chosen -> Try(List(Edit), Fail)
add_edit = |members, w, c| match w.members {
	[file, ..] => {
		rows = match members.find_first(|m| m.file == file) {
			Ok(m) => m.locked.rows.map(|r| { alias: r.alias, url: r.value, is_platform: r.is_platform })
			Err(_) => []
		}
		name = w.name ?? w.key
		plan = Add.decide({ selector: Err(None), chosen: { name, url: c.url, kind: Package }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: rows })?
		match plan.header {
			Insert => Ok([{ file, op: Add({ alias: plan.alias, url: c.url, is_platform: Bool.False }), line: "+ ${plan.alias}: ${name} ${c.version}", did: Added({ alias: plan.alias, name, version: c.version }) }])
			_ => Ok([])
		}
	}
	[] => Ok([])
}

# R-AD22, R-AD26, D10: the `talon.toml` key of an alias that `update X@sel` or `add X@sel` names, in the nearest `talon.toml` of its first use. Q1: a new file next to the member.
pairs_of : ResolveBase.Request, List(Vars.Member), List(Vars.Scoped), Asked -> Try(List(Pair), Fail)
pairs_of = |request, members, scoped, asked| asked.picks
	.keep_oks(
		|p| match scoped.find_first(|s| s.free and s.variable.uses.any(|u| u.alias == p.alias)) {
			Ok(s) => match s.variable.uses.find_first(|u| u.alias == p.alias) {
				Ok(u) => Ok((p, s, u))
				Err(_) => Err(NoPair)
			}
			Err(_) => Err(NoPair)
		},
	)
	.map_try(
		|(p, s, u)| {
			plan = Add.decide_alias({ alias: p.alias, selector: Ok(p.selector), no_pin: request.add.no_pin, header: [{ alias: u.alias, url: u.url, is_platform: s.variable.is_platform }] })?
			path = match members.find_first(|m| m.file == u.file) {
				Ok({ toml: Ok(t), .. }) => t.path
				_ => Text.join(Text.dir_of(u.file), "talon.toml")
			}
			match plan.toml {
				Ok({ key, value }) => Ok([{ path, key, value }])
				Err(Nothing) => Ok([])
			}
		},
	)
	.map_ok(|lists| lists.join_map(|l| l))

# The second read, the check of R-CC7 and the write, in the order of `Guard.check_all` (Talon first). It gives the files that changed, in the order of the write.
# With `--dry-run` there is no read and no write: it gives each file of the plan. The lines of the files are printed in both cases (R-LF4).
write! : Fx, ResolveBase.Request, Loaded, List(Edit), List(Pair), List(Rename) => Try(List(Str), Fail)
write! = |fx, request, loaded, edits, pairs, renames| {
	header_files = loaded.members.keep_if(|m| edits.any(|e| e.file == m.file)).map(|m| m.file)
	toml_files = pairs.map(|p| p.path).concat(renames.map(|r| r.path)).fold([], |found, path| if found.contains(path) found else found.append(path))
	paths = header_files.concat(toml_files)
	if paths.is_empty() return Ok([])
	touched = if request.dry_run paths else changed_files!(fx, loaded, { header_files, paths, edits, pairs, renames })?
	for path in header_files {
		if touched.contains(path) {
			fx.out!("${path}\n")
			for e in edits.keep_if(|e| e.file == path) {
				fx.out!("  ${e.line}\n")
			}
		}
	}
	for p in pairs {
		if touched.contains(p.path) {
			fx.out!("${p.path}: ${p.key} = \"${p.value}\"\n")
		}
	}
	for r in renames {
		if touched.contains(r.path) {
			fx.out!("${r.path}: key ${r.from} -> ${r.to}\n")
		}
	}
	Ok(touched)
}

# Reads each file again, checks it (R-CC7), and writes the files that change with one `write_atomic!` call. The rename of the keys is after the key writes.
changed_files! : Fx, Loaded, { header_files : List(Str), paths : List(Str), edits : List(Edit), pairs : List(Pair), renames : List(Rename) } => Try(List(Str), Fail)
changed_files! = |fx, loaded, plan| {
	now_texts = plan.paths.map2(fx.read_files!(plan.paths), |path, result| (path, result))
	var $files = no_files
	var $edited = no_edited
	for (path, result) in now_texts {
		is_header = plan.header_files.contains(path)
		read = ResolveBase.loaded_text(loaded, path)
		now = match result {
			Ok(text) => text
			Err(NotFound) => if is_header return Err(Fail.new(Environment, "cannot read ${path}")) else ""
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
		ops = plan.edits.keep_if(|e| e.file == path).map(|e| e.op)
		mine = plan.pairs.keep_if(|p| p.path == path)
		renames = plan.renames.keep_if(|r| r.path == path)
		keys = mine.map(|p| p.key).concat(renames.map(|r| r.from))
		writes = mine.map(|p| { key: p.key, value: p.value })
		spans_read = if is_header Locked.spans({ text: read, ops }) else IntentEdit.spans({ text: read, keys })
		spans_now = if is_header Locked.spans({ text: now, ops }) else IntentEdit.spans({ text: now, keys })
		new = if is_header Locked.edit({ path, text: now, ops })? else IntentEdit.rename({ path, text: IntentEdit.apply({ path, text: now, writes })?, renames: renames.map(|r| { from: r.from, to: r.to }) })?
		$files = $files.append({ path, read, now, spans_read, spans_now })
		$edited = $edited.append({ path, now, new })
	}
	ResolveBase.write_checked!(fx, { files: $files, edited: $edited })
}

no_files : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) })
no_files = []

no_edited : List({ path : Str, now : Str, new : Str })
no_edited = []

no_names : List(Str)
no_names = []

no_kept : List(Kept)
no_kept = []
