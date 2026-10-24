import Add
import Clock
import Fail
import Ident
import Pick
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

## The pure steps of the flow of `install`, `update` and `add` (slice 036b3: split from `InstallFlow`): the plan of the new names, the edits of the headers, and the outcome.
InstallPlan :: [].{

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

	fresh_plan : ResolveBase.Request, Loaded, List(FreshRow), List(Pick.Chosen) -> Try(Planned, Fail)
	fresh_plan = |request, loaded, rows, chosen| {
		file = request.project.file ?? ""
		start = { header: ResolveBase.current_rows(loaded.members, file), edits: no_edits, pairs: no_pairs, kept: no_kept, notes: ResolveBase.no_names }
		rows.map2(chosen, |r, c| (r, c)).fold_try(start, |acc, (r, c)| fresh_step(request, loaded, file, acc, r, c))
	}

	pick_notes_of : List(Pick.Chosen) -> List(Str)
	pick_notes_of = |chosen| chosen.keep_oks(|c| c.note).fold(ResolveBase.no_names, |found, note| if found.contains(note) found else found.append(note))

	# Q7: the lines that `finish!` prints before the ladder for a tuple, in the same order and the same text.
	pre_lines : ResolveBase.Request, Loaded, Finish, List(Pick.Chosen) -> List(Str)
	pre_lines = |request, loaded, facts, chosen| {
		count = facts.scoped.len()
		plan = InstallPlan.fresh_plan(request, loaded, facts.prepared.rows, chosen.drop_first(count + facts.wants.len()))
		plan_notes = match plan {
			Ok(p) => p.notes
			Err(_) => []
		}
		plan_kept = match plan {
			Ok(p) => p.kept
			Err(_) => []
		}
		picks = InstallPlan.pick_notes_of(chosen).map(|n| "note: ${n}")
		moved = ResolveBase.moved_platform_notes(facts.scoped, chosen.take_first(count)).map(|n| "note: ${n}")
		picks.concat(moved).concat(plan_notes.map(|n| "note: ${n}")).concat(facts.asked.kept.concat(plan_kept).map(|k| k.note))
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

	# The conflict of a dropped tuple: the chosen releases (by the place of their slot) that the ladder blames by hash, or the whole tuple.
	dropped : List(Pick.Chosen), List(Str) -> List({ at : U64, id : Str })
	dropped = |chosen, blamed| {
		all = chosen.map_with_index(|c, i| { at: i, id: c.url })
		named = all.keep_if(|x| Ident.of_url(x.id).map_ok(|ident| blamed.contains(ident.hash)) ?? Bool.False)
		if named.is_empty() all else named
	}

	no_ran : Ran
	no_ran = { probes: 0, downloads: 0, check: NotRun, build: NotRun, notes: [] }
}

no_edits : List(Edit)
no_edits = []

no_pairs : List(Pair)
no_pairs = []

no_kept : List(Kept)
no_kept = []

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
