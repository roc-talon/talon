import Add
import Clock
import Fail
import Frozen
import Fx
import Guard
import Ident
import Intent
import Ladder
import Locked
import Pick
import PickFlow
import Pin
import Report
import ResolveBase
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
		start = ResolveBase.prepared!(fx, request)?
		loaded = start.loaded
		built = start.built
		decision = start.decision
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
	ResolveBase.check_pin(loaded, settings, decision)?
	snapshot = ResolveBase.snapshot_of(request, loaded.intent)?
	picked = PickFlow.pick!(fx, request, loaded, built, settings, snapshot)?
	finish!(fx, request, loaded, picked.facts, picked.chosen)
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
		Replace => match acc.header.find_first(|r| r.is_platform) {
			Ok(old) => if old.url == c.url {
				Ok(state)
			} else {
				from = { name: name_of(old.url), version: version_of(old.url) }
				edit = {
					file,
					op: Set({ alias: plan.alias, url: c.url }),
					line: "~ ${plan.alias}: ${from.name} ${from.version} -> ${c.version}",
					did: Moved({ alias: plan.alias, from, to: { name: f.name, version: c.version } }),
				}
				Ok({ ..state, edits: acc.edits.append(edit) })
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
no_ran = { probes: 0, check: NotRun, build: NotRun, notes: [] }

finish! : Fx, ResolveBase.Request, Loaded, Finish, List(Pick.Chosen) => Try(Report.Outcome, Fail)
finish! = |fx, request, loaded, facts, chosen| {
	scoped = facts.scoped
	wants = facts.wants
	count = scoped.len()
	var_chosen = chosen.take_first(count)
	want_chosen = chosen.drop_first(count).take_first(wants.len())
	fresh_chosen = chosen.drop_first(count + wants.len())
	pick_notes = chosen.keep_oks(|c| c.note)
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
		compiler: request.compiler,
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
		{ members: loaded.members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, changes) }), known: ResolveBase.known_nodes(facts.known) },
	)?
	ResolveBase.closure_notes!(fx, request, closures)
	news = wants.map(|w| { name: w.name ?? w.key, is_platform: Bool.False }).concat(facts.prepared.rows.map(|r| { name: r.fresh.name, is_platform: r.fresh.is_platform }))
	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision })?
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
ladder! : Fx, ResolveBase.Request, Loaded, { scoped : List(Vars.Scoped), news : List({ name : Str, is_platform : Bool }), chosen : List(Pick.Chosen), changes : List(Edit), decision : Pin.Decision } => Try(Ran, Fail)
ladder! = |fx, request, loaded, facts| {
	if request.no_check {
		fx.out!("check: skipped\n")
		Ok({ probes: 0, check: Skipped, build: Skipped, notes: [] })
	} else {
		rows = ResolveBase.owner_rows(facts.scoped, facts.news, facts.chosen)
		files = facts.changes.map(|e| e.file).fold(no_names, |found, file| if found.contains(file) found else found.append(file))
		members = files.keep_oks(|file| ladder_member(loaded, facts.changes, facts.decision, file))
		notes = Ladder.run!(
			fx,
			{
				roots: request.roots,
				path_roc: request.compiler,
				held: facts.decision.held ?? "",
				members,
				owners: rows.map(|r| r.owner),
				moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
			},
		)?
		Ok({
			probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),
			check: Passed,
			build: if members.any(|m| m.kind == App) Passed else NotRun,
			notes,
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
		spans_read = if is_header Locked.spans({ text: read, ops }) else Intent.spans({ text: read, keys })
		spans_now = if is_header Locked.spans({ text: now, ops }) else Intent.spans({ text: now, keys })
		new = if is_header Locked.edit({ path, text: now, ops })? else Intent.rename({ path, text: Intent.apply({ path, text: now, writes })?, renames: renames.map(|r| { from: r.from, to: r.to }) })?
		$files = $files.append({ path, read, now, spans_read, spans_now })
		$edited = $edited.append({ path, now, new })
	}
	ordered = Guard.check_all($files)?
	changed = ordered.keep_oks(|o| $edited.find_first(|e| e.path == o.path)).keep_if(|e| e.new != e.now)
	if changed.is_empty() return Ok([])
	match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new })) {
		Ok(_) => Ok(changed.map(|e| e.path))
		Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
}

no_files : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) })
no_files = []

no_edited : List({ path : Str, now : Str, new : Str })
no_edited = []

no_names : List(Str)
no_names = []

no_kept : List(Kept)
no_kept = []
