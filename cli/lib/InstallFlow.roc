import Compiler
import Closure
import Consent
import Db
import Fail
import Frozen
import Fx
import HeldRoc
import IndexQuery
import LogSnapshot
import Matrix
import NightlyFlow
import Nightlies
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
import Fetch
import Report
import ResolveBase
import ResolveLoad
import ResolveSelect
import ShareHook
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
	install! = |fx, request| Ok(InstallFlow.install_with!(fx, request, Err(None))?.outcome)

	## Slice 073: what `install_with!` gives. `tools` are the rows of the tools step (`[]` for no step or no entry): `--json` puts them in `data.tools` (`ToolsPlan.with_tools`). `Report.Outcome` does not hold them.
	## Slice 206e4 (R-SH4, R-AP30): `ran` is the run that sent a closure query (`ShareHook.ran_of`): the index notes and the send of the share queue at the end of the command. `Err(None)`: no request.
	Done : { outcome : Report.Outcome, tools : List(ToolsStep.JsonRow), ran : Try(Fail.Ran, [None]), fell : Try({ registry : Str, cause : Str }, [None]) }

	## Slice 056 (R-PT5 to R-PT7, D2, D16): `install!` with the tools step. `tools` is `Ok(args)` for the commands that run it (`Resolve.install_with!`: `tln install`, `tln update`, `tln upgrade`), `Err(None)` for the other callers. The step runs after the header flow and has
	## the phase `Install` (no names), `Frozen` (`--frozen`: after the line `the header satisfies talon.toml`). The line `nothing to change` is printed once, at the end, and only when neither the header nor the tools change (D16): while the tools step runs, the header flow gets an `Fx` that drops it.
	install_with! : Fx, Request, Try(Args, [None]) => Try(InstallFlow.Done, Fail)
	install_with! = |fx, asked, tools| run!(fx, asked, tools, Bool.False)

	## Slice 072e (R-IN2, R-IN4): `install_with!` for `init`. The header is new, so the pin of the held compiler is a change of the run: the ladder checks it, and it is written also when no release moves.
	install_fresh! : Fx, Request, Try(Args, [None]) => Try(InstallFlow.Done, Fail)
	install_fresh! = |fx, asked, tools| run!(fx, asked, tools, Bool.True)

	## Slice 206e: the registry setting of a run after the load (`with_setting`), for `VerifyFlow.verify!`.
	setting_of : Request, Loaded -> Try(Request, Fail)
	setting_of = |request, loaded| with_setting(request, loaded)

	## Slice 206e: the R-DT5 log size of a run with a registry answer (`log_of`), for `VerifyFlow.verify!`.
	log_size : Request -> Try(U64, [None])
	log_size = |request| log_of(request)
}

# Prepared : the files, the variables and the pin of the compiler (`ResolveLoad.prepared!`).
Prepared : { loaded : Loaded, built : { vars : List(Vars.Var), wants : List(Vars.Want) }, decision : Pin.Decision, range_note : Try(Str, [None]), listed : Bool }

# R-SO19, R-SO22, Q-D2, Q-E1 (slice 072e): does the run start a probe? `--no-check` and `--frozen` run none. A plain `install` with no names whose `--frozen` check passes (R-LF1) has nothing to change: no probe, so no pick.
will_probe : Request, Prepared -> Bool
will_probe = |request, start| {
	if request.no_check or request.frozen {
		Bool.False
	} else if request.command == Install and request.names.is_empty() {
		!nothing_to_change(request, start)
	} else {
		Bool.True
	}
}

# The pure check of `--frozen` (R-LF1). A scope that fails is a run that has something to do.
nothing_to_change : Request, Prepared -> Bool
nothing_to_change = |request, start| {
	settings = ResolveBase.settings_of(request, start.loaded)
	match Vars.scope({ command: Install, names: [], fixed: [], selectors: [], vars: start.built.vars }) {
		Ok(scoped) => Frozen.check({ scoped, wants: start.built.wants, outside: start.decision.outside, req_text: start.loaded.intent.toolchain.roc_text, nightly: settings.nightly }).is_ok()
		Err(_) => Bool.False
	}
}

# R-SO19, R-SO23, R-SO24 (slice 072e): no compiler is selected and a probe will run. The compiler is picked as an id (`HeldRoc.picked!`, no download) before the index and before any write, and `Pin.decide` runs again with it.
# `request.selected` stays empty, so the first probe knows that no compiler was selected (`PickLoop.begin!`).
# Slice 206e2 (R-CV1, R-IX4): with a registry the pick reads the registry list, so the request that comes back is `listed` (the later reads use the kept file).
picked! : Fx, Request, Prepared => Try({ start : Prepared, request : Request }, Fail)
picked! = |fx, request, start| match start.decision.held {
	Ok(_) => Ok({ start, request })
	Err(NoCompiler) => if will_probe(request, start) {
		loaded = ResolveLoad.with_pick(start.loaded, HeldRoc.picked!(fx, request, start.loaded)?)
		Ok({ start: { ..start, loaded, decision: ResolveLoad.decide(request, loaded, Lock)? }, request: ResolveBase.listed(request) })
	} else {
		Ok({ start, request })
	}
}

# Slice 206b (R-RG1, R-RG2, R-RG7, R-DT3, R-AP19): the registry setting of a run with `Setting`, after the load (the text of `config.toml` is in that read). `direct` gives `Off`: the run is as before the slice.
# A registry gives `Read` with its snapshot (`log:N` is valid). `--offline` with a registry (slice 206d): `Off` with the index `Offline(origin)`.
with_setting : Request, Loaded -> Try(Request, Fail)
with_setting = |request, loaded| match request.registry {
	Setting(flag) => match IndexQuery.setting({ flag, env: request.net.registry, config: loaded.config.registry })? {
		Direct => Ok({ ..request, registry: Off })
		Registry(origin) => if request.offline {
			# Slice 206d (R-IX6, R-AD37, R-IX5): the index is the kept copies of the registry reads. No guard, no request.
			Ok({ ..request, registry: Off, index: Offline(origin) })
		} else {
			snapshot = IndexQuery.snapshot({ registry: Bool.True, flag: request.snapshot, config: loaded.intent.resolution.snapshot })?
			Ok({ ..request, registry: Read({ origin, snapshot, window: None, listed: Bool.False, share: loaded.config.share, source: IndexQuery.source({ flag, env: request.net.registry, config: loaded.config.registry }) }) })
		}
	}
	_ => Ok(request)
}

# Slice 206g (Design Q560): `init` (`fresh`) reads the compiler list from the registry and nothing else: the platform and package lists stay GitHub lists. A `Read` becomes `Compilers`. `--offline` (`Offline`): the index stays, the compiler list is the kept file.
# Slice 206i (Q560, Q564, Q565): an `init` of an app (`has_platform`) keeps `Read`: the platform is a group of the closure query. `init package` (no platform) reads only the compiler list.
compilers_only : Request, Bool, Bool -> Request
compilers_only = |request, fresh, has_platform| if !fresh request else match (request.registry, request.index) {
	(Read(_), _) if has_platform => request
	(Read(query), _) => { ..request, registry: Compilers(query) }
	(_, Offline(origin)) => { ..request, registry: Compilers({ origin, snapshot: None, window: None, listed: Bool.False, share: Err(Unset), source: "the registry setting" }) }
	_ => request
}

# `install_with!` and `install_fresh!`. `fresh` is true for `init`.
run! : Fx, Request, Try(Args, [None]), Bool => Try(InstallFlow.Done, Fail)
run! = |fx, asked, tools, fresh| {
	first = ResolveLoad.prepared!(fx, asked, Lock)?
	set = { ..compilers_only(with_setting(asked, first.loaded)?, fresh, first.loaded.members.any(|m| m.locked.kind == App)), selected: Fetch.selected({ held: first.decision.held ?? "", default: first.loaded.config.default_roc ?? "" }), none: ResolveBase.no_rank(asked, first.loaded) }
	# Slice 206e2 (R-IX4): a range pick of `prepared!` that read the registry list.
	pick = picked!(fx, if first.listed ResolveBase.listed(set) else set, first)?
	request = pick.request
	start = pick.start
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
		step = tools_after!(fx, tools, { request, loaded, phase: plan.phase, keys: plan.keys })?
		Ok({ outcome: InstallPlan.idle(request, request.now), tools: step.rows, ran: Err(None), fell: Err(None) })
	} else {
		header = match plan.phase {
			Ok(_) => { ..fx, out!: |text| if text == "nothing to change\n" {} else fx.out!(text) }
			Err(None) => fx
		}
		outcome = if plan.header resolve!(header, plan.request, loaded, built, { decision, fresh, range_note: start.range_note })? else { outcome: InstallPlan.idle(plan.request, request.now), ran: Err(None), fell: Err(None) }
		step = tools_after!(fx, tools, { request, loaded, phase: plan.phase, keys: plan.keys })?
		if plan.phase.is_ok() and !step.changed and !header_changed(outcome.outcome) {
			fx.out!("nothing to change\n")
		}
		Ok({ outcome: outcome.outcome, tools: step.rows, ran: outcome.ran, fell: outcome.fell })
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

# R-IN2, R-IN4: `init` writes the pin of the held compiler for its new header, also when no release moves. It is a move of the pin, so the ladder checks it.
fresh_pin : Bool, Try(Str, [NoCompiler]) -> Try(Str, [Same])
fresh_pin = |fresh, held| if fresh held.map_err(|_| Same) else Err(Same)

# Slice 056 (D16): did the header flow change something? A run that wrote a file did. A `--dry-run` writes nothing, so it is the planned changes (the test of `Install.print!` for the line of R-DT5). A kept entry is a line of its own.
header_changed : Report.Outcome -> Bool
header_changed = |outcome| !outcome.written.is_empty() or !outcome.kept.is_empty() or !outcome.added.is_empty() or !outcome.moved.is_empty() or outcome.pinned.is_ok() or !outcome.toml.is_empty() or !outcome.renamed.is_empty()

# Slice 056: the tools step, or no call. `changed` is true when it printed a line.
tools_after! : Fx, Try(Args, [None]), { request : Request, loaded : Loaded, phase : Try(ToolsPlan.Phase, [None]), keys : List(Str) } => Try({ changed : Bool, rows : List(ToolsStep.JsonRow) }, Fail)
tools_after! = |fx, tools, run| match (tools, run.phase) {
	(Ok(args), Ok(phase)) => ToolsStep.after!(fx, args, { request: run.request, loaded: run.loaded, phase, keys: run.keys })
	_ => Ok({ changed: Bool.False, rows: [] })
}

# `--frozen` (R-LF1): the pure check, then the hash check of the packages of the header. No index call, no write.
frozen! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision, Bool => Try({}, Fail)
frozen! = |fx, request, loaded, built, decision, with_tools| {
	settings = ResolveBase.settings_of(request, loaded)
	scoped = Vars.scope({ command: Install, names: [], fixed: [], selectors: [], vars: built.vars })?
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
resolve! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, { decision : Pin.Decision, fresh : Bool, range_note : Try(Str, [None]) } => Try({ outcome : Report.Outcome, ran : Try(Fail.Ran, [None]), fell : Try({ registry : Str, cause : Str }, [None]) }, Fail)
resolve! = |fx, request, loaded, built, start| {
	decision = start.decision
	settings = ResolveBase.settings_of(request, loaded)
	# Slice 039 (R-UP6, D6): the range and the switch do not stop a free nightly. A run with no compiler does.
	free_nightly = request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Free
	if free_nightly {
		match decision.held {
			Err(NoCompiler) => return Err(Compiler.failure(NoCompiler))
			Ok(_) => {}
		}
	} else {
		# R-SO22, R-SO19: a run with no compiler here picked none, because no probe will run (`will_probe`).
		ResolveBase.check_pin(loaded, settings, decision, if request.no_check or decision.held.is_err() LockNoCheck else Lock)?
	}
	# R-C16 (slice 084): the note of a new rank 4 pick that only a pattern kept comes after the note of the pin (R-SO20).
	pin_notes = ResolveBase.pin_notes(decision).concat(start.range_note.map_ok(|text| [text]) ?? [])
	for note in pin_notes {
		fx.out!("note: ${note}\n")
	}
	# Slice 206b (R-DT4, R-AP19): with a registry the time form is the cutoff of the pick, and `log:N` hides the answer (`PickFlow.prepare!`).
	snapshot = match request.registry {
		Read(query) => match query.snapshot {
			Time(t) => Ok(t)
			_ => Err(None)
		}
		_ => ResolveSelect.snapshot_of(request, loaded.intent)?
	}
	# R-SO22, U3: `--no-check` runs no probe and no lookup. Else the probe rounds use the held compiler.
	held = if request.no_check Err(None) else decision.held.map_err(|_| None)
	plan = match decision.held {
		Ok(id) if free_nightly and !request.no_check => NightlyFlow.plan!(fx, request, loaded, settings, { held: id, snapshot })?
		_ => { free: Err(Held), releases: Err(NotRead), newest: Err(NoneKnown), optional: { ids: [], sizes: [] }, downloads: 0, note: Err(None), fell: Err(None) }
	}
	# Q1 of slice 039: the line that says why the nightly stays H.
	notes = plan.note.map_ok(|text| [text]) ?? []
	for note in notes {
		fx.out!("note: ${note}\n")
	}
	# Slice 206b (R-AP16): the window of the query is the held compiler. Slice 206e2 (R-AP16, R-CV1, Design Q489): the free nightly of `upgrade` with a registry list that was read has the `Free` window; an unread list keeps `Held`.
	# The plan read the list (`releases` is `Ok`), so the later reads of the command use the kept file (R-IX4).
	# R-RG9: a list read of the plan that fell back makes the run `direct`.
	after_plan = ResolveBase.routed(request, plan.fell)
	queried = match after_plan.registry {
		Read(query) => {
			window = match decision.held {
				Err(_) => None
				Ok(id) => match plan.releases {
					Ok(list) if !list.is_empty() => Free(ResolveBase.compiler_domain(request, loaded, settings, { releases: list, snapshot: query.snapshot }))
					_ => Held(id)
				}
			}
			{ ..after_plan, registry: Read({ ..query, window, listed: query.listed or plan.releases.is_ok() }) }
		}
		_ => after_plan
	}
	ready = PickFlow.prepare!(fx, queried, loaded, built, settings, snapshot, held, plan.free, plan.newest, plan.optional)?
	# Slice 206b: `ready.request` has the index of the query.
	# Slice 206e4 (R-SH4, Design Q533, Q541): a failure after the closure answer carries the run, so the command prints the index notes after the error text and sends the queue.
	ran = ShareHook.ran_of(ready.request, { notes: request.command != Install, second: Err(NotRead) })
	first = PickFlow.search!(fx, ready.request, ready, listed_start(PickLoop.start(ready.setup, ready.prepared.facts), plan.releases)).map_err(|fail| Fail.with_fell(ShareHook.attach(fail, ran, Bool.False), ResolveBase.fell_of(ready.request)))?
	ended = attempts!(fx, ready.request, loaded, ready, { picked: first, first: Err(None), seen: [], downloads: plan.downloads, fresh: start.fresh })?
	outcome = ended.outcome
	# R-SO20: the note of the pin is the first of `data.notes`.
	Ok({
		outcome: { ..outcome, notes: pin_notes.concat(notes).concat(outcome.notes) },
		ran: ended.ran,
		fell: ResolveBase.fell_of(ready.request),
	})
}

# Slice 089 (R-UP6, R-EP10, 039c D3): the first search starts with the compiler list that the plan read, so the oracle loop does not read it again.
listed_start : PickLoop.State, Try(List(Nightlies.Release), [NotRead]) -> PickLoop.State
listed_start = |state, releases| { ..state, probed: { ..state.probed, listed: releases } }

# R-AL6, R-PH13 (slice 036b): the ladder runs on the tuple of the pick. A failure of the ladder that is about the tuple (`Fail.again`) goes back to the oracle loop as a conflict, on the releases that the ladder blames (all of the tuple when it names none).
# The next tuple is picked with the facts that the command has. The line `note: tuple dropped: ...` says it (a proposal, TW24). `seen` are the lines before the ladder that the command printed for the tuples before (Q7: a line prints once). When no other tuple exists, the failure of the command is the first failure of the ladder.
attempts! : Fx, ResolveBase.Request, Loaded, PickFlow.Ready, { picked : ResolveBase.Picked, first : Try(Fail, [None]), seen : List(Str), downloads : U64, fresh : Bool } => Try({ outcome : Report.Outcome, ran : Try(Fail.Ran, [None]) }, Fail)
attempts! = |fx, request, loaded, ready, run| {
	picked = run.picked
	match finish!(fx, request, loaded, picked.facts, picked.chosen, picked.moves, picked.probed, { seen: run.seen, nightly: picked.nightly, downloads: run.downloads, fresh: run.fresh }) {
		Ok(ended) => Ok(ended)
		Err(fail) => match fail.again {
			Err(None) => Err(Fail.with_fell(ShareHook.attach(fail, ShareHook.ran_of(request, { notes: request.command != Install, second: picked.probed.second }), Bool.True), ResolveBase.fell_of(request)))
			Ok(again) => {
				fx.out!("note: tuple dropped: ${fail.message.drop_prefix("no tuple works: ")}\n")
				first = run.first ?? fail
				probed = { ..picked.probed, count: again.probes, tried: picked.probed.tried.append(InstallPlan.dropped(picked.chosen, again.blamed)), checks: smoke_facts(request, picked.probed, fail).concat(picked.probed.checks), domain: smoke_domain(picked.probed, fail) }
				match PickFlow.search!(fx, request, ready, { facts: picked.facts.known, paths: picked.facts.paths, probed }) {
					Ok(next) => attempts!(fx, request, loaded, ready, { picked: next, first: Ok(first), seen: run.seen.concat(InstallPlan.pre_lines(request, loaded, picked.facts, picked.chosen)).concat(index_lines(request, picked.probed)), downloads: run.downloads, fresh: run.fresh })
					Err(other) => {
						ran = ShareHook.ran_of(request, { notes: request.command != Install, second: picked.probed.second })
						if other.kind == NoTuple Err(ShareHook.attach(first, ran, Bool.True)) else Err(ShareHook.attach(other, ran, Bool.True))
					}
				}
			}
		}
	}
}

# Slice 209b (R-SM6, R-EP7, Design Q557): after a drop for a `bot` smoke fail, the smoke checks of the platform on each compiler of the smoke rows go to the next search, first, as facts of the target `any`: a `Real` `Fail` with no module touches each module and decides alone, so it holds over a unit `pass` of the key (`OracleDomain.row_of` takes the first row). Q562: always added; with no list read the domain is the compiler of the key.
smoke_facts : ResolveBase.Request, ResolveBase.Probed, Fail -> List(Db.Fact)
smoke_facts = |request, probed, fail| match (fail.smoke, ResolveBase.answer_of(request)) {
	(Ok(key), Ok(answer)) => {
		domain = probed.listed ?? [{ id: key.nightly, published_at: 0, asset: Err(NoAsset) }]
		rows = Matrix.rows({ runs: answer.runs, nearest: answer.nearest, domain })
		Matrix.smoke_checks({ rows, id: key.id, hash: key.hash, target: key.target }).map(|c| { hash: key.hash, nightly: c.nightly, target: "any", outcome: c.outcome, modules: [], closure: "" })
	}
	_ => []
}

# Slice 209b (Q562): a held compiler with no list read has the domain of its own: the compiler of the key. The smoke check on it then needs no read of the list (the oracle asks for D only to explain a probe cause).
smoke_domain : ResolveBase.Probed, Fail -> Try(List(Str), [NotRead])
smoke_domain = |probed, fail| match (probed.domain, probed.listed, fail.smoke) {
	(Err(NotRead), Err(NotRead), Ok(key)) => Ok([key.nightly])
	_ => probed.domain
}

# Q7 (slice 036b2): a line before the ladder that an earlier tuple printed (`seen`) is not printed again.
finish! : Fx, ResolveBase.Request, Loaded, Finish, List(Pick.Chosen), List(Consent.Move), ResolveBase.Probed, { seen : List(Str), nightly : Try(Str, [None]), downloads : U64, fresh : Bool } => Try({ outcome : Report.Outcome, ran : Try(Fail.Ran, [None]) }, Fail)
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
	# Slice 206e3 (R-EF3, Design Q500): the notes of the pairs of the tuple whose `bot` and `author` rows differ.
	differ_notes = PickLoop.differ_notes(request, chosen, probed, after.nightly)
	for note in differ_notes.keep_if(|n| !seen.contains("note: ${n}")) {
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
		Err(_) => match NightlyFlow.moved_to(request, unified.differ, decision.held, after.nightly) {
			Ok(id) => Ok(id)
			Err(Same) => fresh_pin(after.fresh, decision.held)
		}
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
	# Slice 206e4 (R-AP30, Design Q537, Q540): the index notes of `update` and `upgrade`, after the other `note:` lines.
	ran = ShareHook.ran_of(request, { notes: request.command != Install, second: probed.second })
	index_texts = match ran {
		Ok(found) if found.notes => ShareHook.notes(found)
		_ => []
	}
	for text in index_texts.keep_if(|n| !seen.contains("note: ${n}")) {
		fx.out!("note: ${text}\n")
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
			headers: ShareHook.headers_of(facts.known, probed.seen),
		},
	)
	PatchApply.clean!(fx, patch)
	done = settled?
	ran_done = { ..done.ran, downloads: done.ran.downloads + after.downloads + probed.optional.downloads }
	touched = done.touched
	if touched.is_empty() and kept.is_empty() {
		fx.out!("nothing to change\n")
	}
	# Slice 039b (R-DL6): the note of the cap, once, at the end of a successful run.
	cap = ResolveBase.probe_settings(request, loaded).max_toolchains
	if cap > 0 and probed.optional.dropped > 0 {
		fx.err!("${Consent.optional_capped({ cap, dropped: probed.optional.dropped })}\n")
	}
	outcome = InstallPlan.outcome_of(
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
			notes: pick_notes.concat(platform_notes).concat(differ_notes).concat(upgrade_notes).concat(plan.notes).concat(ran_done.notes).concat(index_texts),
			ran: ran_done,
		},
	)
	# Slice 218 (R-SM1): the builds of ladder step 3 go to the run for the smoke build before the send.
	sent = ran.map_ok(|found| { ..found, built: done.built })
	# The failure of a later step still has the run (`attempts!`): the notes are printed already.
	match log_of(request) {
		Ok(n) => Ok({ outcome: { ..outcome, at: if facts.snapshot.is_ok() outcome.at else LogSnapshot.at_text(n), log: Ok(n) }, ran: sent })
		Err(None) => Ok({ outcome, ran: sent })
	}
}

# The lines of the index notes that `finish!` printed (Q7: a repeat of the step does not print them again).
index_lines : ResolveBase.Request, ResolveBase.Probed -> List(Str)
index_lines = |request, probed| match ShareHook.ran_of(request, { notes: request.command != Install, second: probed.second }) {
	Ok(found) if found.notes => ShareHook.notes(found).map(|text| "note: ${text}")
	_ => []
}

# R-DT5 (slice 206b, slice 206d2, Design Q438): the log size of a run with the answer of a registry: `LogSnapshot.printed` (N of `--snapshot log:N`, else the `log_size` of the first answer).
# The `at` of such a run is the time of a time snapshot, else `log:<n>`; `Report.resolved_line` and `Report.data` add the log size. `Err(None)` for a run with no answer: the outcome as before.
log_of : ResolveBase.Request -> Try(U64, [None])
log_of = |request| match (request.index, request.registry) {
	(Answer(a), Read(query)) => {
		user = match query.snapshot {
			Log(n) => Ok(n)
			_ => Err(None)
		}
		Ok(LogSnapshot.printed({ snapshot: user, first: a.answer }))
	}
	_ => Err(None)
}

# The ladder, the report of the moves, the write of the files and the rebase of the patches (slice 043: split from `finish!` so that the temp dirs of `PatchApply` are deleted also after a failure, R-CC2).
settle! : Fx, ResolveBase.Request, Loaded, { scoped : List(Vars.Scoped), news : List({ name : Str, is_platform : Bool }), chosen : List(Pick.Chosen), moves : List(Consent.Move), probed : ResolveBase.Probed, checked : List(ResolveBase.Edit), edits : List(ResolveBase.Edit), pairs : List(ResolveBase.Pair), renames : List(ResolveBase.Rename), closures : List({ file : Str, walked : Closure.Walked }), decision : Pin.Decision, candidate : Try(Str, [None]), patch : PatchApply.Done, no_ladder : Bool, headers : List({ hash : Str, kind : [Package, Platform, App], names : List(Str) }) } => Try({ ran : ResolveBase.Ran, built : List(Fail.Built), touched : List(Str) }, Fail)
settle! = |fx, request, loaded, x| {
	ran = if x.no_ladder { ran: InstallPlan.no_ran, built: [] } else InstallWrite.ladder!(fx, request, loaded, { scoped: x.scoped, news: x.news, chosen: x.chosen, changes: x.checked, decision: x.decision, closures: x.closures, probed: x.probed, candidate: x.candidate, patch: x.patch, headers: x.headers })?
	InstallWrite.confirm_moves!(fx, request, x.moves)?
	written = InstallWrite.write!(fx, request, loaded, x.edits, x.pairs, x.renames, x.patch)?
	rebased = PatchApply.finish!(fx, request, x.patch)?
	Ok({ ran: ran.ran, built: ran.built, touched: written.concat(rebased.keep_if(|path| !written.contains(path))) })
}
