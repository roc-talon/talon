import Consent
import Fail
import Frozen
import Fx
import InstallPlan
import InstallWrite
import Lags
import Pick
import PickFlow
import PickLoop
import Pin
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect
import Vars

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

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
			Ok(InstallPlan.idle(request, request.now))
		} else {
			resolve!(fx, request, loaded, built, decision)
		}
	}
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
	outcome = attempts!(fx, request, loaded, ready, { picked: first, first: Err(None), seen: [] })?
	# R-SO20: the note of the pin is the first of `data.notes`.
	Ok({ ..outcome, notes: pin_notes.concat(outcome.notes) })
}

# R-AL6, R-PH13 (slice 036b): the ladder runs on the tuple of the pick. A failure of the ladder that is about the tuple (`Fail.again`) goes back to the oracle loop as a conflict, on the releases that the ladder blames (all of the tuple when it names none).
# The next tuple is picked with the facts that the command has. The line `note: tuple dropped: ...` says it (a proposal, TW24). `seen` are the lines before the ladder that the command printed for the tuples before (Q7: a line prints once). When no other tuple exists, the failure of the command is the first failure of the ladder.
attempts! : Fx, ResolveBase.Request, Loaded, PickFlow.Ready, { picked : ResolveBase.Picked, first : Try(Fail, [None]), seen : List(Str) } => Try(Report.Outcome, Fail)
attempts! = |fx, request, loaded, ready, run| {
	picked = run.picked
	match finish!(fx, request, loaded, picked.facts, picked.chosen, picked.moves, picked.probed, run.seen) {
		Ok(outcome) => Ok(outcome)
		Err(fail) => match fail.again {
			Err(None) => Err(fail)
			Ok(again) => {
				fx.out!("note: tuple dropped: ${fail.message.drop_prefix("no tuple works: ")}\n")
				first = run.first ?? fail
				probed = { ..picked.probed, count: again.probes, tried: picked.probed.tried.append(InstallPlan.dropped(picked.chosen, again.blamed)) }
				match PickFlow.search!(fx, request, ready, { facts: picked.facts.known, paths: picked.facts.paths, probed }) {
					Ok(next) => attempts!(fx, request, loaded, ready, { picked: next, first: Ok(first), seen: run.seen.concat(InstallPlan.pre_lines(request, loaded, picked.facts, picked.chosen)) })
					Err(other) => if other.kind == NoTuple Err(first) else Err(other)
				}
			}
		}
	}
}

# Q7 (slice 036b2): a line before the ladder that an earlier tuple printed (`seen`) is not printed again.
finish! : Fx, ResolveBase.Request, Loaded, Finish, List(Pick.Chosen), List(Consent.Move), ResolveBase.Probed, List(Str) => Try(Report.Outcome, Fail)
finish! = |fx, request, loaded, facts, chosen, moves, probed, seen| {
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
	ran = if changes.is_empty() InstallPlan.no_ran else InstallWrite.ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision, closures, probed })?
	InstallWrite.confirm_moves!(fx, request, moves)?
	touched = InstallWrite.write!(fx, request, loaded, edits, pairs, facts.renames)?
	if touched.is_empty() and kept.is_empty() {
		fx.out!("nothing to change\n")
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
