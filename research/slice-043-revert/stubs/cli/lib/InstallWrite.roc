import BuildSkip
import Closure
import Consent
import Fail
import Fx
import IntentEdit
import Ladder
import Lags
import Locked
import PatchApply
import Pick
import Pin
import Prompt
import ResolveBase
import Vars

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

Edit : ResolveBase.Edit

Pair : ResolveBase.Pair

Rename : ResolveBase.Rename

Ran : ResolveBase.Ran

## The last steps of the flow of `install`, `update` and `add` (slice 036b3: split from `InstallFlow`): the report of the moves and the prompt, the ladder, and the write of the files. Command code.
InstallWrite :: [].{

	# Slice 043 (R-PA5, R-CC7): the new `base` of each rebased patch is an edit of the `[patch]` table of its `talon.toml`. It is in the same second read, the same check and the same write as the keys (the span of the check is the value of the key of the alias in `[patch]`).
	# The second read, the check of R-CC7 and the write, in the order of `Guard.check_all` (Talon first). It gives the files that changed, in the order of the write.
	# With `--dry-run` there is no read and no write: it gives each file of the plan. The lines of the files are printed in both cases (R-LF4).
	write! : Fx, ResolveBase.Request, Loaded, List(Edit), List(Pair), List(Rename), PatchApply.Done => Try(List(Str), Fail)
	write! = |fx, request, loaded, edits, pairs, renames, _patch| {
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
				fx.out!("${p.path}: ${p.key} = \"${p.value}\"${was_text(loaded, p)}\n")
			}
		}
		for r in renames {
			if touched.contains(r.path) {
				fx.out!("${r.path}: key ${r.from} -> ${r.to}\n")
			}
		}
		Ok(touched)
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

	# Slice 006: the place of the probe ladder in the flow (Resolution 4, R-LD4, R-LD5, R-PH9, R-PH10): after the choice and before the write, when a header changes (R-AL6).
	# `facts.changes` are the planned changes of the headers (the pin write is not a change that makes the ladder run). `facts.decision` is the `Pin.decide` of `finish!`. `facts.news` are the wants
	# and the new names, in the order of the slots after `facts.scoped`.
	#
	# | Case | What the body does |
	# | --- | --- |
	# | `request.no_check` (R-BL6, R-LF3) | No `Fx` call. Prints `check: skipped` (a proposal, TW24) and gives `Skipped` for both steps. A pin is not written (`Pin.decide`, R-H6). |
	# | Else | Builds `Ladder.run!` input: one `Ladder.Member` for each member file in `facts.changes` (its `kind` and its text from `loaded`, its `ops` from the changes and from the pin write of `facts.decision.writes`), the `Ladder.Owner` of each hash of the candidate header (the uses of `facts.scoped` and the chosen URLs, with `Vars` names), `moved` (the chosen values that move: `Pick.Chosen.change` is `Move` and the new ones), `path_roc` is `request.compiler`, `held` is `facts.decision.held`, `roots` is `request.roots`. Calls `Ladder.run!`. The probes are 3 for an app and 2 for a package or a platform (D12). |
	ladder! : Fx, ResolveBase.Request, Loaded, { scoped : List(Vars.Scoped), news : List({ name : Str, is_platform : Bool }), chosen : List(Pick.Chosen), changes : List(Edit), decision : Pin.Decision, closures : List({ file : Str, walked : Closure.Walked }), probed : ResolveBase.Probed, candidate : Try(Str, [None]), patch : PatchApply.Done } => Try(Ran, Fail)
	ladder! = |fx, request, loaded, facts| {
		if request.no_check {
			fx.out!("check: skipped\n")
			Ok({ probes: 0, downloads: 0, check: Skipped, build: Skipped, notes: [] })
		} else {
			rows = ResolveBase.owner_rows(facts.scoped, facts.news, facts.chosen)
			files = facts.changes.map(|e| e.file).fold(ResolveBase.no_names, |found, file| if found.contains(file) found else found.append(file))
			members = files.keep_oks(|file| ladder_member(loaded, facts.changes, facts.decision, facts.patch, file))
			done = Ladder.run!(
				fx,
				{
					roots: request.roots,
					now: request.now,
					path_roc: request.compiler,
					held: match facts.candidate {
						Ok(id) => id
						Err(None) => facts.decision.held ?? ""
					},
					members,
					owners: rows.map(|r| r.owner),
					moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
					downloads: ResolveBase.ladder_downloads(request),
					probe: ResolveBase.probe_settings(request, loaded),
					no_probe: request.probe.no_probe,
					closures: facts.closures,
					loop: { started: facts.probed.started, looked: facts.probed.looked, checks: facts.probed.checks, count: facts.probed.count, base: loop_base(facts.candidate, facts.decision) },
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
}

# Slice 039 (R-BL3): with a new compiler as the candidate, the baseline check runs on the compiler H of the header.
loop_base : Try(Str, [None]), Pin.Decision -> Try(Str, [None])
loop_base = |candidate, decision| match candidate {
	Ok(_) => decision.held.map_err(|_| None)
	Err(None) => Err(None)
}

# Q6 (a) of slice 038: a toml line of a key that had another value ends with ` (was "<old>")`.
was_text : Loaded, Pair -> Str
was_text = |loaded, p| match Lags.was({ members: loaded.members, path: p.path, key: p.key }) {
	Ok(old) => if old == p.value "" else " (was \"${old}\")"
	Err(None) => ""
}

# A member file with its header text and the edits for the candidate: the planned changes, and the pin that the command writes after the check (R-RP3).
ladder_member : Loaded, List(Edit), Pin.Decision, PatchApply.Done, Str -> Try(Ladder.Member, [NoMember])
ladder_member = |loaded, changes, decision, patch, file| match loaded.members.find_first(|m| m.file == file) {
	Ok(m) => Ok({
		file,
		kind: m.locked.kind,
		text: ResolveBase.loaded_text(loaded, file),
		ops: changes.keep_if(|e| e.file == file).map(|e| e.op).concat(decision.writes.keep_if(|w| w.file == file).map(|w| Pin(w.id))),
		patch: PatchApply.member(patch, file),
	})
	Err(_) => Err(NoMember)
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
