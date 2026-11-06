import BuildSkip
import Clock
import Fail
import Fetch
import Fx
import HeldRoc
import InstallFlow
import Ladder
import LadderPlan
import LogSnapshot
import PatchApply
import Patched
import PickFlow
import PickLoop
import Pin
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect
import ShareHook

Request : ResolveBase.Request

Loaded : ResolveBase.Loaded

Picked : ResolveBase.Picked

## The flow of `verify` (`Resolve.verify!`): the part after the pick. Split from `Resolve` in slice 010.
VerifyFlow :: [].{

	## The flow of `Resolve.verify!`. The differences from `install!` are in the doc of `Resolve.verify!`.
	verify! : Fx, Request => Try({ outcome : Report.Outcome, ran : Try(Fail.Ran, [None]) }, Fail)
	verify! = |fx, asked| {
		start = ResolveLoad.prepared!(fx, asked, Verify)?
		# Slice 206e (R-AL2, R-RG1): the registry setting after the load, as `install`.
		request = { ..InstallFlow.setting_of(asked, start.loaded)?, selected: Fetch.selected({ held: start.decision.held ?? "", default: start.loaded.config.default_roc ?? "" }), none: ResolveBase.no_rank(asked, start.loaded) }
		settings = ResolveBase.settings_of(request, start.loaded)
		ResolveBase.check_pin(start.loaded, settings, start.decision, Verify)?
		# Slice 206e (R-DT4, R-AP19): with a registry the time form is the cutoff of the pick, and `log:N` hides the answer (`PickFlow.prepare!`).
		snapshot = match request.registry {
			Read(query) => match query.snapshot {
				Time(t) => Ok(t)
				_ => Err(None)
			}
			_ => ResolveSelect.snapshot_of(request, start.loaded.intent)?
		}
		# Slice 206e (R-AP16): the window of the query is the held pin.
		queried = match request.registry {
			Read(query) => {
				window = match start.decision.held {
					Ok(id) => Held(id)
					Err(_) => None
				}
				{ ..request, registry: Read({ ..query, window }) }
			}
			_ => request
		}
		ready = PickFlow.prepare!(fx, queried, start.loaded, start.built, settings, snapshot, Err(None), Err(Held), Err(NoneKnown), { ids: [], sizes: [] })?
		# `ready.request` has the index of the query.
		# Slice 206e4 (R-SH4, Design Q533, Q537): `verify` prints no index note, and a failure after the closure answer carries the run for the send.
		ran = ShareHook.ran_of(ready.request, { notes: Bool.False, second: Err(NotRead) })
		picked = PickFlow.search!(fx, ready.request, ready, PickLoop.start(ready.setup, ready.prepared.facts)).map_err(|fail| ShareHook.attach(fail, ran, Bool.False))?
		done = verified!(fx, ready.request, start.loaded, picked, start.decision).map_err(|fail| ShareHook.attach(fail, ran, Bool.False))?
		outcome = done.outcome
		# Slice 218 (R-SM1): the builds of ladder step 3 go to the run for the smoke build before the send.
		sent = ran.map_ok(|found| { ..found, built: done.built })
		# R-DT5 (Design Q438): the log size of a run with a registry answer, as `InstallFlow.finish!`.
		match InstallFlow.log_size(ready.request) {
			Ok(n) => Ok({ outcome: { ..outcome, at: if picked.facts.snapshot.is_ok() outcome.at else LogSnapshot.at_text(n), log: Ok(n) }, ran: sent })
			Err(None) => Ok({ outcome, ran: sent })
		}
	}
}

# Slice 009: the part of `verify!` after the pick (`Resolve.verify!`, rows 1 to 3 of its table): the notes, the ladder with `--replace-dep`, the plan. Nothing is written.
verified! : Fx, ResolveBase.Request, Loaded, Picked, Pin.Decision => Try({ outcome : Report.Outcome, built : List(Fail.Built) }, Fail)
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
	# Slice 206e3b (R-EF3, Design Q501): the note of the pairs of the tuple on the held compiler where the `bot` and the `author` row differ, after the platform notes, as `install`.
	differ_notes = PickLoop.differ_notes(request, picked.chosen, picked.probed, decision.held.map_err(|_| None))
	for note in differ_notes {
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
		{ probes: 0, downloads: 0, check: Skipped, build: Skipped, notes: [], built: [] }
	} else {
		rows = ResolveBase.owner_rows(facts.scoped, [], picked.chosen)
		held = HeldRoc.held!(fx, request, loaded, decision.held)?
		done = Ladder.verify!(
			fx,
			{
				roots: request.roots,
				now: request.now,
				path_roc: request.compiler,
				held,
				members: checked,
				replace,
				owners: rows.map(|r| r.owner),
				moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
				downloads: ResolveBase.ladder_downloads(request),
				probe: ResolveBase.probe_settings(request, loaded),
				no_probe: request.probe.no_probe,
				closures,
				answer: ResolveBase.answer_of(request),
				share: ShareHook.ran_of(request, { notes: Bool.False, second: Err(NotRead) }).map_ok(|found| { ..found, headers: ShareHook.headers_of(facts.known, picked.probed.seen) }),
			},
		)?
		{
			probes: done.probes,
			downloads: done.downloads,
			check: Passed,
			build: BuildSkip.state({ apps: checked.count_if(|m| m.kind == App), skipped: done.skipped }),
			notes: done.notes,
			built: done.built,
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
	outcome = {
		at: Clock.format_utc(
			match facts.snapshot {
				Ok(time) => time
				Err(None) => request.now
			},
		),
		log: Err(None),
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
		notes: pick_notes.concat(platform_notes).concat(differ_notes).concat(ran.notes),
		written: [],
	}
	Ok({ outcome, built: ran.built })
}

no_replace : List(LadderPlan.Replace)
no_replace = []

# The member files that `verify` checks: the current member when `--file` names one, else all members.
checked_members : ResolveBase.Request, Loaded -> List(Ladder.Checked)
checked_members = |request, loaded| {
	current = request.project.file ?? ""
	all = loaded.members.map(|m| { file: m.file, kind: m.locked.kind, text: ResolveBase.loaded_text(loaded, m.file), patch: Patched.replaces(PatchApply.entries(m)), target: ResolveBase.member_target(m) })
	named = all.keep_if(|m| m.file == current)
	if named.is_empty() all else named
}
