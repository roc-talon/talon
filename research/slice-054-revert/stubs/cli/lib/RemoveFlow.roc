import BuildSkip
import Fail
import Fx
import IntentEdit
import Ladder
import Locked
import Lookup
import Pin
import Ref
import Release
import Removal
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect
import Scan
import Scope
import Text
import UnitFlow
import Vars
import header.Header

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

Ran : ResolveBase.Ran

## The flow of `remove` (`Resolve.remove!`). Split from `Resolve` in slice 010.
RemoveFlow :: [].{

	## The flow of `Resolve.remove!`. The steps are in the doc of `Resolve.remove!`.
	remove! : Fx, Request, { names : List(Str), force : Bool } => Try(Report.RemoveOutcome, Fail)
	remove! = |fx, request, facts| {
		loaded = ResolveSelect.select!(fx, request, ResolveLoad.load!(fx, request)?)?
		current = request.project.file ?? ""
		member = match loaded.members.find_first(|m| m.file == current) {
			Ok(m) => m
			Err(_) => return Err(Fail.new(Usage, "no current member: pass --file <member file>"))
		}
		plans = removal_plans!(fx, loaded, member, facts.names)?
		aliases = plans.map(|p| p.alias)
		imported = import_hits!(fx, loaded, member, aliases)
		if !imported.is_empty() and !facts.force return Err(Fail.new(AppError, imports_text(imported)))
		forced = !imported.is_empty()
		skip_check = request.no_check or forced
		settings = ResolveBase.settings_of(request, loaded)
		decision = Pin.decide({
			members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: m.file == current }),
			compiler: loaded.selected.id,
			compiler_from: loaded.selected.from,
			toolchain: request.toolchain,
			role: Lock,
			req: loaded.intent.toolchain.roc,
			nightly: settings.nightly,
			no_check: skip_check,
		})?
		ResolveBase.check_pin(loaded, settings, decision, Lock)?
		pin_notes = ResolveBase.pin_notes(decision)
		for note in pin_notes {
			fx.out!("note: ${note}\n")
		}
		force_notes = imported.map(|h| still_imported(h))
		for note in force_notes {
			fx.out!("note: ${note}\n")
		}
		pins = decision.writes.keep_if(|w| w.file == current)
		ops : List(Locked.Op)
		ops = aliases.map(|alias| Remove(alias)).concat(pins.map(|w| Pin(w.id)))
		ran = if skip_check {
			if request.no_check fx.out!("check: skipped\n")
			{ probes: 0, downloads: 0, check: Skipped, build: Skipped, notes: [] }
		} else {
			removal_ladder!(fx, request, loaded, member, { aliases, ops, decision })?
		}
		keys = plans.join_map(|p| p.plan.keys)
		toml = member_toml(loaded, member)
		written = write_removal!(fx, request, loaded, { file: current, ops, toml, keys })?
		toml_path = match toml {
			Ok(t) => t.path
			Err(NoToml) => ""
		}
		removed_rows = plans.map(|p| removed_of(p.alias, p.plan.what))
		toml_rows = keys.map(|k| { path: toml_path, table: IntentEdit.table_name(k.table), key: k.key })
		patches = plans.keep_oks(|p| p.plan.patch_dir.map_ok(|dir| { alias: p.alias, dir }))
		fx.out!("${current}\n")
		for r in removed_rows {
			fx.out!("  - ${r.alias}: ${removed_text(r)}\n")
		}
		for w in pins {
			fx.out!("  + roc: ${w.id}\n")
		}
		for t in toml_rows {
			fx.out!("${t.path}: - [${t.table}] ${t.key}\n")
		}
		for p in patches {
			fx.out!("kept: ${p.dir} (the patch files of ${p.alias})\n")
		}
		Ok({
			probes: ran.probes,
			dry_run: request.dry_run,
			check: ran.check,
			build: ran.build,
			removed: removed_rows,
			toml: toml_rows,
			patches,
			pinned: match pins {
				[w, ..] => Ok(w.id)
				[] => Err(None)
			},
			# R-SO20: the note of the pin is the first of `data.notes`.
			notes: pin_notes.concat(force_notes).concat(ran.notes),
			written,
		})
	}
}

# One entry to remove: its alias and the decision of `Removal.plan`.
RemovePlan : { alias : Str, plan : Removal.Plan }

# The aliases that a scan found imported, with their import lines.
Imported : { alias : Str, hits : List(Scan.Hit) }

# Steps 2 and 3: the names are looked up in the header of the member (R-SC1, R-SC6 to R-SC8) and planned. One entry counts once.
removal_plans! : Fx, Loaded, Vars.Member, List(Str) => Try(List(RemovePlan), Fail)
removal_plans! = |fx, loaded, member, names| {
	entities = Lookup.build(member.locked.rows.map(row_fact))
	var $aliases = no_names
	for text in names {
		ref = Ref.parse(text, Scope.Project, Bool.False)?
		found = match Lookup.find(Scope.Project, ref, entities) {
			Ok(f) => f
			Err({ fail, block }) => {
				if !block.is_empty() fx.err!(block)
				return Err(fail)
			}
		}
		alias = match found {
			Lookup.Existing({ alias: a, .. }) => a
			Lookup.New(name) => return Err(Fail.new(Usage, "'${name}' is not in the project"))
		}
		if !$aliases.contains(alias) {
			$aliases = $aliases.append(alias)
		}
	}
	toml = member_toml(loaded, member)
	$aliases.map_try(
		|alias| Removal.plan({ alias, rows: member.locked.rows, toml, shared: shared_alias(loaded, member, toml, alias) }).map_ok(|plan| { alias, plan }),
	)
}

# The fact of one header entry for `Lookup.build`: a release, or an unmanaged entry (a path entry or a foreign URL).
row_fact : Locked.Row -> Lookup.Fact
row_fact = |r| {
	what = match r.what {
		Release(ident) => Release({ name: ident.name ?? ident.group.form, series: ident.series, version: ident.version })
		_ => Unmanaged
	}
	{ alias: r.alias, what, role: if r.is_platform Platform else Direct }
}

# R-WS14: the nearest `talon.toml` of the member, with its text.
member_toml : Loaded, Vars.Member -> Try({ path : Str, text : Str }, [NoToml])
member_toml = |loaded, member| match member.toml {
	Ok(found) => loaded.tomls.find_first(|t| t.path == found.path).map_err(|_| NoToml)
	Err(NoToml) => Err(NoToml)
}

# Question Q3: another member under the dir of that `talon.toml` has the alias, so its key stays.
shared_alias : Loaded, Vars.Member, Try({ path : Str, text : Str }, [NoToml]), Str -> Bool
shared_alias = |loaded, member, toml, alias| match toml {
	Ok(file) => {
		dir = Text.dir_of(file.path)
		prefix = if dir.ends_with("/") dir else "${dir}/"
		loaded.members.any(|m| m.file != member.file and m.file.starts_with(prefix) and m.locked.rows.any(|r| r.alias == alias))
	}
	Err(NoToml) => Bool.False
}

# Step 4, R-RV2, R-LD7: the lexical scan. It starts at the roots and reads one level of local modules with each `read_files!` call. A file that cannot be read is skipped (question Q7).
import_hits! : Fx, Loaded, Vars.Member, List(Str) => List(Imported)
import_hits! = |fx, loaded, member, aliases| {
	text = ResolveBase.loaded_text(loaded, member.file)
	exposed = match Header.parse(text) {
		Ok(header) => header.exposed()
		Err(_) => []
	}
	roots = Scan.roots({ kind: member.locked.kind, file: member.file, exposed })
	is_app = member.locked.kind == App
	var $sources = if is_app [{ path: member.file, text }] else []
	var $todo = if is_app [] else roots.keep_if(|file| file != member.file)
	var $seen = [member.file]
	var $found = aliases.map(|alias| { alias, hits: [] })
	while !$sources.is_empty() or !$todo.is_empty() {
		seen = $seen.concat($todo)
		sources = $sources.concat(UnitFlow.texts!(fx, $todo))
		levels = aliases.map(|alias| Scan.level({ alias, project_dir: Text.dir_of(member.file), sources, seen }))
		$found = $found.map2(levels, |f, level| { alias: f.alias, hits: f.hits.concat(level.hits) })
		$todo = match levels.first() {
			Ok(level) => level.next
			Err(_) => []
		}
		$seen = seen
		$sources = []
	}
	$found.keep_if(|f| !f.hits.is_empty())
}

# R-RV2, R-EC11 (proposal, TW24): the message of the failure. The import lines are in the message, so the `--json` error has them too.
imports_text : List(Imported) -> Str
imports_text = |imported| {
	aliases = Str.join_with(imported.map(|i| i.alias), ", ")
	lines = imported.join_map(|i| i.hits).map(|h| "${h.file}:${h.line.to_str()}: ${h.text}")
	"the app imports ${aliases}: ${Str.join_with(lines, "; ")}. Change these imports first, or pass --force to remove it anyway."
}

# R-RV2: the note of a forced run.
still_imported : Imported -> Str
still_imported = |i| {
	count = i.hits.len()
	lines = if count == 1 "1 line" else "${count.to_str()} lines"
	"${i.alias} is still imported in ${lines}. The app cannot check until you change the imports."
}

# Step 8, R-RV1, R-LD4, R-LD5: the ladder for the one member. A candidate with a new error stops the run (no tuple: `remove` moves no other entry).
removal_ladder! : Fx, ResolveBase.Request, Loaded, Vars.Member, { aliases : List(Str), ops : List(Locked.Op), decision : Pin.Decision } => Try(Ran, Fail)
removal_ladder! = |fx, request, loaded, member, facts| {
	owners = member.locked.rows
		.keep_if(|r| !facts.aliases.contains(r.alias))
		.keep_oks(
			|r| match r.what {
				Release(ident) => Ok({ hash: ident.hash, name: ident.name ?? r.value, version: ident.version, is_platform: r.is_platform })
				_ => Err(NotRelease)
			},
		)
	candidate = { file: member.file, kind: member.locked.kind, text: ResolveBase.loaded_text(loaded, member.file), ops: facts.ops, patch: { base: [], candidate: [] }, target: Err(Unset) }
	# R-LD2, R-CM2: the closure of the header without the removed entries gives the packages of the unit probes.
	entries = ResolveBase.entries_after(member, []).keep_if(|e| !facts.aliases.contains(e.alias))
	closures = ResolveBase.closure!(fx, request, { members: [{ file: member.file, entries }], known: [] })?
	result = Ladder.run!(
		fx,
		{ roots: request.roots, now: request.now, path_roc: request.compiler, held: facts.decision.held ?? "", members: [candidate], owners, moved: [], downloads: ResolveBase.ladder_downloads(request), probe: ResolveBase.probe_settings(request, loaded), no_probe: request.probe.no_probe, closures, loop: Ladder.no_loop },
	)
	match result {
		Ok(done) => Ok({
			probes: done.probes,
			downloads: done.downloads,
			check: Passed,
			build: BuildSkip.state({ apps: if member.locked.kind == App 1 else 0, skipped: done.skipped }),
			notes: done.notes,
		})
		Err(fail) => if fail.kind == NoTuple {
			Err(Fail.new(NoTuple, "${fail.message}. tln remove moves no other entry. Pass --no-check to remove ${Str.join_with(facts.aliases, ", ")} anyway."))
		} else {
			Err(fail)
		}
	}
}

# Step 9, R-CC7, R-CC1: the second read, the check, and one `write_atomic!` call (the `talon.toml` first). With `--dry-run` there is no read and no write.
write_removal! : Fx, ResolveBase.Request, Loaded, { file : Str, ops : List(Locked.Op), toml : Try({ path : Str, text : Str }, [NoToml]), keys : List({ table : IntentEdit.Table, key : Str }) } => Try(List(Str), Fail)
write_removal! = |fx, request, loaded, facts| {
	if request.dry_run return Ok([])
	toml_paths = match facts.toml {
		Ok(t) if !facts.keys.is_empty() => [t.path]
		_ => []
	}
	paths = toml_paths.concat([facts.file])
	var $now = no_edited
	for (path, result) in paths.map2(fx.read_files!(paths), |path, result| (path, result)) {
		match result {
			Ok(text) => {
				$now = $now.append({ path, now: text, new: text })
			}
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
	}
	edited = $now.map_try(
		|f| {
			is_header = f.path == facts.file
			new = if is_header {
				Locked.edit({ path: f.path, text: f.now, ops: facts.ops })?
			} else {
				IntentEdit.remove({ path: f.path, text: f.now, keys: facts.keys })?
			}
			Ok({ path: f.path, now: f.now, new })
		},
	)?
	checked = edited.map(
		|f| {
			is_header = f.path == facts.file
			read = ResolveBase.loaded_text(loaded, f.path)
			spans = |text| if is_header Locked.spans({ text, ops: facts.ops }) else IntentEdit.table_spans({ text, keys: facts.keys })
			{ path: f.path, read, now: f.now, spans_read: spans(read), spans_now: spans(f.now) }
		},
	)
	ResolveBase.write_checked!(fx, { files: checked, edited })
}

# One entry of the outcome and its line (`- <alias>: <what>`).
removed_of : Str, Removal.What -> Report.Removed
removed_of = |alias, what| match what {
	Release({ name, version }) => { alias, kind: Release, name, version: Ok(version) }
	Path(path) => { alias, kind: Path, name: path, version: Err(None) }
	Foreign(url) => { alias, kind: Foreign, name: url, version: Err(None) }
}

removed_text : Report.Removed -> Str
removed_text = |r| match r.version {
	Ok(version) => "${r.name} ${version}"
	Err(None) => r.name
}

no_edited : List({ path : Str, now : Str, new : Str })
no_edited = []

no_names : List(Str)
no_names = []
