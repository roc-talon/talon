import BuildSkip
import Clock
import Fail
import Fx
import Ladder
import LadderPlan
import PickFlow
import Pin
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

Picked : ResolveBase.Picked

## The flow of `verify` (`Resolve.verify!`): the part after the pick. Split from `Resolve` in slice 010.
VerifyFlow :: [].{

	## The flow of `Resolve.verify!`. The differences from `install!` are in the doc of `Resolve.verify!`.
	verify! : Fx, Request => Try(Report.Outcome, Fail)
	verify! = |fx, request| {
		start = ResolveLoad.prepared!(fx, request, Verify)?
		settings = ResolveBase.settings_of(request, start.loaded)
		ResolveBase.check_pin(start.loaded, settings, start.decision, Verify)?
		snapshot = ResolveSelect.snapshot_of(request, start.loaded.intent)?
		picked = PickFlow.pick!(fx, request, start.loaded, start.built, settings, snapshot, Err(None))?
		verified!(fx, request, start.loaded, picked, start.decision)
	}
}

# Slice 009: the part of `verify!` after the pick (`Resolve.verify!`, rows 1 to 3 of its table): the notes, the ladder with `--replace-dep`, the plan. Nothing is written.
verified! : Fx, ResolveBase.Request, Loaded, Picked, Pin.Decision => Try(Report.Outcome, Fail)
verified! = |fx, request, loaded, picked, decision| {
	facts = picked.facts
	var_chosen = picked.chosen.take_first(facts.scoped.len())
	pick_notes = picked.chosen.keep_oks(|c| c.note)
	for note in pick_notes {
		fx.out!("note: ${note}\n")
	}
	platform_notes = ResolveBase.moved_platform_notes(facts.scoped, var_chosen)
	for note in platform_notes {
		fx.out!("note: ${note}\n")
	}
	checked = checked_members(request, loaded)
	files = checked.map(|m| m.file)
	pairs = facts.scoped.map2(var_chosen, |s, c| (s, c))
	edits = pairs.join_map(|(s, c)| ResolveBase.set_edits(s, c)).keep_if(|e| files.contains(e.file))
	replace = pairs
		.join_map(|(s, c)| s.variable.uses.keep_if(|u| u.url != c.url and files.contains(u.file)).map(|u| { old: u.url, new: c.url }))
		.fold(no_replace, |found, r| if found.contains(r) found else found.append(r))
	closures = ResolveBase.closure!(
		fx,
		request,
		{
			members: loaded.members.keep_if(|m| files.contains(m.file)).map(|m| { file: m.file, entries: ResolveBase.entries_after(m, edits) }),
			known: ResolveBase.known_nodes(facts.known).concat(facts.paths),
		},
	)?
	ResolveBase.closure_notes!(fx, request, closures)
	ran = if request.no_check {
		fx.out!("check: skipped\n")
		{ probes: 0, downloads: 0, check: Skipped, build: Skipped, notes: [] }
	} else {
		rows = ResolveBase.owner_rows(facts.scoped, [], picked.chosen)
		done = Ladder.verify!(
			fx,
			{
				roots: request.roots,
				now: request.now,
				path_roc: request.compiler,
				held: decision.held ?? "",
				members: checked,
				replace,
				owners: rows.map(|r| r.owner),
				moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
				downloads: ResolveBase.ladder_downloads(request),
				probe: ResolveBase.probe_settings(request, loaded),
				no_probe: request.probe.no_probe,
				closures,
			},
		)?
		{
			probes: done.probes,
			downloads: done.downloads,
			check: Passed,
			build: BuildSkip.state({ apps: checked.count_if(|m| m.kind == App), skipped: done.skipped }),
			notes: done.notes,
		}
	}
	for file in files {
		if edits.any(|e| e.file == file) {
			fx.out!("${file}\n")
			for e in edits.keep_if(|e| e.file == file) {
				fx.out!("  ${e.line}\n")
			}
		}
	}
	moved = edits.keep_oks(
		|e| match e.did {
			Moved(move) => Ok(move)
			_ => Err(NotMoved)
		},
	)
	Ok({
		at: Clock.format_utc(
			match facts.snapshot {
				Ok(time) => time
				Err(None) => request.now
			},
		),
		probes: ran.probes,
		downloads: ran.downloads,
		dry_run: Bool.False,
		check: ran.check,
		build: ran.build,
		added: [],
		moved,
		kept: [],
		pinned: Err(None),
		toml: [],
		renamed: [],
		notes: pick_notes.concat(platform_notes).concat(ran.notes),
		written: [],
	})
}

no_replace : List(LadderPlan.Replace)
no_replace = []

# The member files that `verify` checks: the current member when `--file` names one, else all members.
checked_members : ResolveBase.Request, Loaded -> List(Ladder.Checked)
checked_members = |request, loaded| {
	current = request.project.file ?? ""
	all = loaded.members.map(|m| { file: m.file, kind: m.locked.kind, text: ResolveBase.loaded_text(loaded, m.file) })
	named = all.keep_if(|m| m.file == current)
	if named.is_empty() all else named
}
