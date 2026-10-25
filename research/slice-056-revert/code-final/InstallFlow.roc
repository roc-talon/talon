import Compiler
import Closure
import Consent
import Fail
import Frozen
import Fx
import NightlyFlow
import NightlyPlan
import InstallPlan
import InstallWrite
import Lags
import PatchApply
import Patched
import Pick
import PickFlow
import PickLoop
import Pin
import Args
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect
import ToolsPlan
import ToolsStep
import Vars

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

Finish : ResolveBase.Finish

## The flow of `install`, `update` and `add` (`Resolve.install!`): the pick, the plan, the ladder and the write. Split from `Resolve` in slice 010.
InstallFlow :: [].{

	## The flow of `Resolve.install!`. The steps are in the doc of `Resolve.install!`.
	install! : Fx, Request => Try(Report.Outcome, Fail)
	install! = |fx, request| InstallFlow.install_with!(fx, request, Err(None))

	## Slice 056 (R-PT5 to R-PT7, D2, D16): `install!` with the tools step. `tools` is `Ok(args)` for the commands that run it (`Resolve.install_with!`: `tln install`, `tln update`, `tln upgrade`), `Err(None)` for the other callers. The step runs after the header flow and has
	## the phase `Install` (no names), `Frozen` (`--frozen`: after the line `the header satisfies talon.toml`). The line `nothing to change` is printed once, at the end, and only when neither the header nor the tools change (D16): while the tools step runs, the header flow gets an `Fx` that drops it.
	install_with! : Fx, Request, Try(Args, [None]) => Try(Report.Outcome, Fail)
	install_with! = |fx, request, tools| {
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
		plan = tools_split(request, loaded, tools)?
		if request.frozen {
			frozen!(fx, request, loaded, built, decision, plan.phase.is_ok())?
			_ = tools_after!(fx, tools, { request, loaded, phase: plan.phase, keys: plan.keys })?
			Ok(InstallPlan.idle(request, request.now))
		} else {
			header = match plan.phase {
				Ok(_) => { ..fx, out!: |text| if text == "nothing to change\n" {} else fx.out!(text) }
				Err(None) => fx
			}
			outcome = if plan.header resolve!(header, plan.request, loaded, built, decision)? else InstallPlan.idle(plan.request, request.now)
			step = tools_after!(fx, tools, { request, loaded, phase: plan.phase, keys: plan.keys })?
			if plan.phase.is_ok() and !step.changed and !header_changed(outcome) {
				fx.out!("nothing to change\n")
			}
			Ok(outcome)
		}
	}
}

# Slice 056 (R-PT5, D3, D5): what the run does with the tools. `request` is the one that the header flow gets (with the names that are for the header). `phase` is the phase of the tools step (`Err(None)`: no step) with its `keys`
# (`[]` is each entry). `header` is false when the names are keys of `[tools]` only: the header flow does not run.
Plan : { request : Request, phase : Try(ToolsPlan.Phase, [None]), keys : List(Str), header : Bool }

# `tln install` with no names: `Install`, or `Frozen` with `--frozen`, for each entry (D3: names run no tools step). `update` and `upgrade` with no names: the phase for each entry. With names: `ToolsPlan.split` (a key that is no alias is a tool).
tools_split : Request, Loaded, Try(Args, [None]) -> Try(Plan, Fail)
tools_split = |request, loaded, tools| {
	none = { request, phase: Err(None), keys: [], header: Bool.True }
	step = |phase| if request.names.is_empty() Ok({ ..none, phase: Ok(phase) }) else tools_named(request, loaded, phase)
	match (tools, request.command) {
		(Err(None), _) => Ok(none)
		(Ok(_), Install) => Ok(if request.names.is_empty() { ..none, phase: Ok(if request.frozen Frozen else Install) } else none)
		(Ok(_), Update) => step(Update)
		(Ok(_), Upgrade) => step(Upgrade)
	}
}

# The names of `update` or `upgrade`: the keys of `[tools]` go to the tools step, the other names to the header flow.
tools_named : Request, Loaded, ToolsPlan.Phase -> Try(Plan, Fail)
tools_named = |request, loaded, phase| {
	word = if request.command == Upgrade "upgrade" else "update"
	aliases = loaded.members.join_map(|m| m.locked.rows.map(|r| r.alias))
	split = ToolsPlan.split({ command: word, names: request.names, keys: loaded.intent.tools.map(|e| e.key), aliases })?
	Ok({ request: { ..request, names: split.header }, phase: if split.tools.is_empty() Err(None) else Ok(phase), keys: split.tools, header: !split.header.is_empty() })
}

# Slice 056 (D16): did the header flow change something? A run that wrote a file did. A `--dry-run` writes nothing, so it is the planned changes (the test of `Install.print!` for the line of R-DT5). A kept entry is a line of its own.
header_changed : Report.Outcome -> Bool
header_changed = |outcome| !outcome.written.is_empty() or !outcome.kept.is_empty() or !outcome.added.is_empty() or !outcome.moved.is_empty() or outcome.pinned.is_ok() or !outcome.toml.is_empty() or !outcome.renamed.is_empty()

# Slice 056: the tools step, or no call. `changed` is true when it printed a line.
tools_after! : Fx, Try(Args, [None]), { request : Request, loaded : Loaded, phase : Try(ToolsPlan.Phase, [None]), keys : List(Str) } => Try({ changed : Bool }, Fail)
tools_after! = |fx, tools, run| match (tools, run.phase) {
	(Ok(args), Ok(phase)) => ToolsStep.after!(fx, args, { request: run.request, loaded: run.loaded, phase, keys: run.keys })
	_ => Ok({ changed: Bool.False })
}

# `--frozen` (R-LF1): the pure check, then the hash check of the packages of the header. No index call, no write.
frozen! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision, Bool => Try({}, Fail)
frozen! = |fx, request, loaded, built, decision, with_tools| {
	settings = ResolveBase.settings_of(request, loaded)
	scoped = Vars.scope({ command: Install, names: [], selectors: [], vars: built.vars })?
	Frozen.check({ scoped, wants: built.wants, outside: decision.outside, req_text: loaded.intent.toolchain.roc_text, nightly: settings.nightly })?
	# R-PA6: `--frozen` fails with exit 14 for a patch whose base is not the hash of its header entry.
	stale = loaded.members.join_map(|m| Patched.stale(PatchApply.entries(m)))
	if !stale.is_empty() {
		return Err(Patched.stale_fail({ entries: stale, by: Frozen }))
	}
	# Slice 056 (R-PT7, R-LF1): the `[tools]` of `talon.toml` are locked, before the closure fetch.
	if with_tools {
		ToolsStep.frozen_check(request, loaded)?
	}
	closures = ResolveBase.closure!(fx, request, { members: loaded.members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, []) }), known: [] })?
	ResolveBase.closure_notes!(fx, request, closures)
	fx.out!("the header satisfies talon.toml\n")
	Ok({})
}

# `install`, `update` and `add`: the steps of the flow in the slice file.
resolve! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try(Report.Outcome, Fail)
resolve! = |fx, request, loaded, built, decision| {
	settings = ResolveBase.settings_of(request, loaded)
	# Slice 039 (R-UP6, D6): the range and the switch do not stop a free nightly. A run with no compiler does.
	free_nightly = request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Free
	if free_nightly {
		match decision.held {
			Err(NoCompiler) => return Err(Compiler.failure(NoCompiler))
			Ok(_) => {}
		}
	} else {
		ResolveBase.check_pin(loaded, settings, decision, Lock)?
	}
	pin_notes = ResolveBase.pin_notes(decision)
	for note in pin_notes {
		fx.out!("note: ${note}\n")
	}
	snapshot = ResolveSelect.snapshot_of(request, loaded.intent)?
	# R-SO22, U3: `--no-check` runs no probe and no lookup. Else the probe rounds use the held compiler.
	held = if request.no_check Err(None) else decision.held.map_err(|_| None)
	plan = match decision.held {
		Ok(id) if free_nightly and !request.no_check => NightlyFlow.plan!(fx, request, loaded, settings, { held: id, snapshot })?
		_ => { free: Err(Held), newest: Err(NoneKnown), optional: { ids: [], sizes: [] }, downloads: 0, note: Err(None) }
	}
	# Q1 of slice 039: the line that says why the nightly stays H.
	notes = plan.note.map_ok(|text| [text]) ?? []
	for note in notes {
		fx.out!("note: ${note}\n")
	}
	ready = PickFlow.prepare!(fx, request, loaded, built, settings, snapshot, held, plan.free, plan.newest, plan.optional)?
	first = PickFlow.search!(fx, request, ready, PickLoop.start(ready.setup, ready.prepared.facts))?
	outcome = attempts!(fx, request, loaded, ready, { picked: first, first: Err(None), seen: [], downloads: plan.downloads })?
	# R-SO20: the note of the pin is the first of `data.notes`.
	Ok({ ..outcome, notes: pin_notes.concat(notes).concat(outcome.notes) })
}

# R-AL6, R-PH13 (slice 036b): the ladder runs on the tuple of the pick. A failure of the ladder that is about the tuple (`Fail.again`) goes back to the oracle loop as a conflict, on the releases that the ladder blames (all of the tuple when it names none).
# The next tuple is picked with the facts that the command has. The line `note: tuple dropped: ...` says it (a proposal, TW24). `seen` are the lines before the ladder that the command printed for the tuples before (Q7: a line prints once). When no other tuple exists, the failure of the command is the first failure of the ladder.
attempts! : Fx, ResolveBase.Request, Loaded, PickFlow.Ready, { picked : ResolveBase.Picked, first : Try(Fail, [None]), seen : List(Str), downloads : U64 } => Try(Report.Outcome, Fail)
attempts! = |fx, request, loaded, ready, run| {
	picked = run.picked
	match finish!(fx, request, loaded, picked.facts, picked.chosen, picked.moves, picked.probed, { seen: run.seen, nightly: picked.nightly, downloads: run.downloads }) {
		Ok(outcome) => Ok(outcome)
		Err(fail) => match fail.again {
			Err(None) => Err(fail)
			Ok(again) => {
				fx.out!("note: tuple dropped: ${fail.message.drop_prefix("no tuple works: ")}\n")
				first = run.first ?? fail
				probed = { ..picked.probed, count: again.probes, tried: picked.probed.tried.append(InstallPlan.dropped(picked.chosen, again.blamed)) }
				match PickFlow.search!(fx, request, ready, { facts: picked.facts.known, paths: picked.facts.paths, probed }) {
					Ok(next) => attempts!(fx, request, loaded, ready, { picked: next, first: Ok(first), seen: run.seen.concat(InstallPlan.pre_lines(request, loaded, picked.facts, picked.chosen)), downloads: run.downloads })
					Err(other) => if other.kind == NoTuple Err(first) else Err(other)
				}
			}
		}
	}
}

# Q7 (slice 036b2): a line before the ladder that an earlier tuple printed (`seen`) is not printed again.
finish! : Fx, ResolveBase.Request, Loaded, Finish, List(Pick.Chosen), List(Consent.Move), ResolveBase.Probed, { seen : List(Str), nightly : Try(Str, [None]), downloads : U64 } => Try(Report.Outcome, Fail)
finish! = |fx, request, loaded, facts, chosen, moves, probed, after| {
	seen = after.seen
	scoped = facts.scoped
	wants = facts.wants
	count = scoped.len()
	var_chosen = chosen.take_first(count)
	want_chosen = chosen.drop_first(count).take_first(wants.len())
	fresh_chosen = chosen.drop_first(count + wants.len())
	pick_notes = InstallPlan.pick_notes_of(chosen)
	for note in pick_notes.keep_if(|n| !seen.contains("note: ${n}")) {
		fx.out!("note: ${note}\n")
	}
	sets = scoped.map2(var_chosen, |s, c| (s, c)).join_map(|(s, c)| InstallPlan.marked(request, s, c, ResolveBase.set_edits(s, c)))
	platform_notes = ResolveBase.moved_platform_notes(scoped, var_chosen)
	for note in platform_notes.keep_if(|n| !seen.contains("note: ${n}")) {
		fx.out!("note: ${note}\n")
	}
	upgrade_notes = InstallPlan.upgrade_notes(request, loaded, facts, var_chosen)
	for note in upgrade_notes.keep_if(|n| !seen.contains("note: ${n}")) {
		fx.out!("note: ${note}\n")
	}
	adds = wants.map2(want_chosen, |w, c| (w, c)).map_try(|(w, c)| InstallPlan.add_edit(loaded.members, w, c))?
	plan = InstallPlan.fresh_plan(request, loaded, facts.prepared.rows, fresh_chosen)?
	changes = sets.concat(adds.join_map(|a| a)).concat(plan.edits)
	unified = NightlyFlow.unify(request, loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: changes.any(|e| e.file == m.file) }))
	decision = Pin.decide({
		members: unified.members,
		compiler: loaded.selected.id,
		compiler_from: loaded.selected.from,
		toolchain: request.toolchain,
		role: Lock,
		req: loaded.intent.toolchain.roc,
		nightly: ResolveBase.settings_of(request, loaded).nightly,
		no_check: request.no_check,
	})?
	# Slice 039 (R-RP1): a free nightly that moved writes the new pin to each member that does not have it. Else the pin of `Pin.decide` (R-RP3).
	# Slice 039c (R-RP4): a held move of the nightly (the row `roc` of the moves) writes the new pin with the other moves.
	moved = match moves.find_first(|m| m.alias == "roc") {
		Ok(held_move) => Ok(held_move.to)
		Err(_) => NightlyFlow.moved_to(request, unified.differ, decision.held, after.nightly)
	}
	pins = match moved {
		Ok(id) => loaded.members.keep_oks(|m| NightlyFlow.pin_edit(m, id))
		Err(Same) => decision.writes.map(|w| { file: w.file, op: Pin(w.id), line: "+ roc: ${w.id}", did: Pinned(w.id) })
	}
	edits = changes.concat(pins)
	rewrites = Lags.rewrites({ members: loaded.members, moves: InstallPlan.moves_of(request, scoped, var_chosen, facts.asked) })
	pairs = InstallPlan.pairs_of(request, loaded.members, scoped, facts.asked)?.concat(rewrites).concat(plan.pairs)
	for note in plan.notes.keep_if(|n| !seen.contains("note: ${n}")) {
		fx.out!("note: ${note}\n")
	}
	kept = facts.asked.kept.concat(plan.kept)
	for k in kept.keep_if(|k| !seen.contains(k.note)) {
		fx.out!("${k.note}\n")
	}
	closures = ResolveBase.closure!(
		fx,
		request,
		{ members: loaded.members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, changes) }), known: ResolveBase.known_nodes(facts.known).concat(facts.paths) },
	)?
	ResolveBase.closure_notes!(fx, request, closures)
	news = wants.map(|w| { name: w.name ?? w.key, is_platform: Bool.False }).concat(facts.prepared.rows.map(|r| { name: r.fresh.name, is_platform: r.fresh.is_platform }))
	# The pins of a move are edits of the candidate, so the ladder checks them (R-BL1). `decision.writes` is the other kind of pin (R-RP3).
	checked = if moved.is_ok() edits else changes
	ladder_decision = if moved.is_ok() { ..decision, writes: [] } else decision
	# R-PA5, R-PA10 (slice 043): the patches that move are applied to the new release in temp dirs before the ladder. A release on which a diff does not apply is dropped like a release that fails the ladder (`Fail.again`).
	patch = PatchApply.run!(fx, request, loaded, { scoped, chosen: var_chosen })?
	settled = settle!(
		fx,
		request,
		loaded,
		{
			scoped,
			news,
			chosen,
			moves,
			probed,
			checked,
			edits,
			pairs,
			renames: facts.renames,
			closures,
			decision: ladder_decision,
			candidate: moved.map_err(|_| None),
			patch,
			no_ladder: checked.is_empty(),
		},
	)
	PatchApply.clean!(fx, patch)
	done = settled?
	ran = { ..done.ran, downloads: done.ran.downloads + after.downloads + probed.optional.downloads }
	touched = done.touched
	if touched.is_empty() and kept.is_empty() {
		fx.out!("nothing to change\n")
	}
	# Slice 039b (R-DL6): the note of the cap, once, at the end of a successful run.
	cap = ResolveBase.probe_settings(request, loaded).max_toolchains
	if cap > 0 and probed.optional.dropped > 0 {
		fx.err!("${Consent.optional_capped({ cap, dropped: probed.optional.dropped })}\n")
	}
	Ok(
		InstallPlan.outcome_of(
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
				notes: pick_notes.concat(platform_notes).concat(upgrade_notes).concat(plan.notes).concat(ran.notes),
				ran,
			},
		),
	)
}

# The ladder, the report of the moves, the write of the files and the rebase of the patches (slice 043: split from `finish!` so that the temp dirs of `PatchApply` are deleted also after a failure, R-CC2).
settle! : Fx, ResolveBase.Request, Loaded, { scoped : List(Vars.Scoped), news : List({ name : Str, is_platform : Bool }), chosen : List(Pick.Chosen), moves : List(Consent.Move), probed : ResolveBase.Probed, checked : List(ResolveBase.Edit), edits : List(ResolveBase.Edit), pairs : List(ResolveBase.Pair), renames : List(ResolveBase.Rename), closures : List({ file : Str, walked : Closure.Walked }), decision : Pin.Decision, candidate : Try(Str, [None]), patch : PatchApply.Done, no_ladder : Bool } => Try({ ran : ResolveBase.Ran, touched : List(Str) }, Fail)
settle! = |fx, request, loaded, x| {
	ran = if x.no_ladder InstallPlan.no_ran else InstallWrite.ladder!(fx, request, loaded, { scoped: x.scoped, news: x.news, chosen: x.chosen, changes: x.checked, decision: x.decision, closures: x.closures, probed: x.probed, candidate: x.candidate, patch: x.patch })?
	InstallWrite.confirm_moves!(fx, request, x.moves)?
	written = InstallWrite.write!(fx, request, loaded, x.edits, x.pairs, x.renames, x.patch)?
	rebased = PatchApply.finish!(fx, request, x.patch)?
	Ok({ ran, touched: written.concat(rebased.keep_if(|path| !written.contains(path))) })
}
