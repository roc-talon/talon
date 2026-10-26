import Add
import BuildTarget
import Closure
import Db
import Epochs
import Explain
import Facts
import Fail
import Fx
import Gather
import Ident
import Launch
import Nightlies
import Oracle
import OracleBase
import Pin
import Pick
import PickOptional
import Probe
import Release
import ResolveBase
import Start
import Toolchain
import UnitFlow
import Units

## Step G of the flow: `Oracle.step_probed` (slice 036 and 036b: the solver, the probe facts of one compiler) until `Done` or `Fail` (slice 016, R-AL8, R-AL9). Split from `PickFlow` (module size).
## A `Need` goes to `Gather.get!`, the same call as the closure walk makes: one fetch and one read for all ids of the list. A release URL gives a fact
## (`Release.read`), a path file gives a node of the closure (`Release.entries_of`). The facts and the nodes stay for the walk after the pick (R-AL8, source 1).
## Slice 036b: a `Pairs` is a probe round. The keys that the command did not look up go to the db first (one `Facts.load!`). Then, with `Allowed`, the pairs are probed in one `probes!` call and the facts are written at once (R-PP4);
## the budget `probe.max` (R-P5) counts all probes of the command. A cut is exit 12 after the facts of the probes that ran are saved (R-UP7). With `Off` (`--no-probe`) the lookup is all that a round does (R-LF2).
## Slice 036b2: a `Scan` is the scan of the used modules of the tuple (R-UM1). One row for each release of the verdict, also with no module. The rows stay in `probed.used` for the whole command.
## Slice 036c: a `Wide` is the read of the compiler list D (`wide!`, once for the command: the next step has `Ok(D)`).
## The compiler starts at the first probe (`Start.run!`), and the ladder takes it (`Ladder.Loop`).
PickLoop :: [].{

	## `unmanaged` are the header entries that no slot owns, for each member (`Pick.step`). `want_slots` name the keys of `talon.toml` for the check of R-AD33.
	Input : {
		slots : List(Pick.Slot),
		strategy : [Highest, Lowest],
		min_age : U64,
		snapshot : Try(U64, [None]),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		second : Bool,
		want_slots : List({ key : Str, name : Str, urls : List(Str) }),
	}

	## What the probe rounds need and do not change: `held` is the compiler of D (`Err(None)` for no probe: `--no-check`, `verify`), `probes` is `Off` for `--no-probe`, `settings` are `probe.max`, `probe.timeout` and `probe.slots`.
	## Slice 039: `free` are the values of the compiler slot (`NightlyFlow.Plan.free`), `Err(Held)` when the slot has H only. The compiler of a tuple is `Looped.nightly`.
	## Slice 039b: `optional` are the optional compilers of a free nightly (`NightlyFlow.Plan.optional`): `ids` start `ResolveBase.Probed.optional.open`, and the values of the compiler slot are `free`, the open ones and the installed ones.
	## Slice 039c: `newest` is N of a free nightly (`NightlyFlow.Plan.newest`, for `Lags.nightly`). `movable` are the values of the movable compiler of the second search of `upgrade X` (`NightlyPlan.movable`): with `Ok` the loop calls `Oracle.step_moved` (R-RP4).
	## `members` are the project files of the workspace (kind and header text): the scan of the used modules starts at each of them (slice 036b2). Slice 054: `target` is the `[build] target` of the member (R-C10, `BuildTarget.wanted`).
	Setup : { held : Try(Str, [None]), free : Try(List(Str), [Held]), newest : Try(Str, [NoneKnown]), movable : Try(List(Str), [None]), optional : { ids : List(Str), sizes : List({ id : Str, size : U64 }) }, probes : [Allowed, Off], settings : Probe.Settings, members : List({ file : Str, kind : [App, Package, Platform], text : Str, target : Try(Str, [Unset]) }) }

	## What a search starts with: the facts and the nodes that the command has read, and the facts of the probe rounds.
	State : { facts : List(ResolveBase.Fact), paths : List(Closure.Node), probed : ResolveBase.Probed }

	Looped : { chosen : List(Pick.Chosen), nightly : Try(Str, [None]), facts : List(ResolveBase.Fact), paths : List(Closure.Node), probed : ResolveBase.Probed }

	## A search that ended with no tuple. `facts`, `paths` and `probed` are what the loop read and learned, so the second search of a held move starts with them (slice 017, R-AL8: no file is read twice; slice 036b: the budget goes on).
	Stuck : { fail : Fail, facts : List(ResolveBase.Fact), paths : List(Closure.Node), probed : ResolveBase.Probed }

	## The first state of a command: nothing read, nothing probed.
	start : PickLoop.Setup, List(ResolveBase.Fact) -> PickLoop.State
	start = |setup, facts| { facts, paths: [], probed: { compiler: setup.held, checks: [], looked: [], count: 0, started: Err(None), tried: [], used: [], domain: Err(NotRead), inferred: [], listed: Err(NotRead), optional: { open: setup.optional.ids, got: [], tried: 0, downloads: 0, dropped: 0 }, seen: [] } }

	## Slice 039c (Q3): the compiler list of the command, `[]` when it cannot be read. The command reads it at most once: the result is `ResolveBase.Probed.listed`.
	releases! : Fx, ResolveBase.Request => List(Nightlies.Release)
	releases! = |fx, request| listed!(fx, request) ?? []

	run! : Fx, ResolveBase.Request, PickLoop.Input, PickLoop.Setup, PickLoop.State => Try(PickLoop.Looped, PickLoop.Stuck)
	run! = |fx, request, input, setup, state| {
		probed = state.probed
		compat = { compiler: probed.compiler, checks: probed.checks, looked: probed.looked, probes: setup.probes, conflicts: probed.tried, used: probed.used, domain: probed.domain, inferred: probed.inferred, failed: Explain.failed_command({ command: request.command, names: request.names }) }
		if wants_domain(setup, probed) return match wide!(fx, request, input, probed) {
			Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
			Ok(next) => run!(fx, request, input, setup, { ..state, probed: next })
		}
		# R-C10, D1 of slice 054: a platform release that lacks the `[build] target` of a member is no candidate. The solver gets it as an `App` release (R-C4).
		wants = BuildTarget.wanted({ slots: input.slots.map(|s| { is_platform: s.is_platform, urls: slot_urls(s), files: s.files }), members: setup.members.map(|m| { file: m.file, target: m.target }) })
		# The platform that the header has now is read first, so the gate knows it before the solver asks (R-C10, R-TG1 rule 1).
		unread = unread_current(input.slots, wants, state.facts)
		if !unread.is_empty() return match read_all!(fx, request, unread, state.facts, state.paths) {
			Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
			Ok(read) => run!(fx, request, input, setup, { facts: read.facts, paths: read.paths, probed: { ..probed, seen: probed.seen.concat(read.seen) } })
		}
		gated = BuildTarget.gate({ facts: state.facts, seen: probed.seen, wanted: wants })
		step_input = { slots: input.slots, strategy: input.strategy, now: request.now, min_age: input.min_age, snapshot: input.snapshot, facts: gated, unmanaged: input.unmanaged, paths: state.paths, second: input.second }
		verdict = match setup.movable {
			Ok(values) => Oracle.step_moved(step_input, compat, values)
			Err(None) => Oracle.step_free(step_input, compat, setup.free.map_ok(|ids| ids.concat(probed.optional.open).concat(probed.optional.got)))
		}
		match verdict {
			Done(done) => Ok({ chosen: done.chosen, nightly: done.nightly, facts: state.facts, paths: state.paths, probed })
			Fail(fail) => Err({ fail: no_target(input.slots, { wants, seen: probed.seen, before: state.facts, after: gated }, fail), facts: state.facts, paths: state.paths, probed })
			Wide => match wide!(fx, request, input, probed) {
				Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
				Ok(next) => run!(fx, request, input, setup, { ..state, probed: next })
			}
			Need(ids) => match read_all!(fx, request, ids, state.facts, state.paths) {
				Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
				Ok(read) => match platform_wants(input.want_slots, read.facts) {
					Err(fail) => Err({ fail, facts: read.facts, paths: read.paths, probed })
					Ok(_) => run!(fx, request, input, setup, { facts: read.facts, paths: read.paths, probed: { ..probed, seen: probed.seen.concat(read.seen) } })
				}
			}
			Scan(scan) => {
				rows = scan_rows!(fx, request, input, setup, state, scan)
				run!(fx, request, input, setup, { ..state, probed: { ..probed, used: probed.used.concat(rows) } })
			}
			Pairs(pairs) => match round!(fx, request, setup, probed, pairs) {
				Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
				Ok(next) => run!(fx, request, input, setup, { ..state, probed: next })
			}
		}
	}
}

# Slice 039: a free compiler slot needs D before the first step (`Wide` is the verdict for the other cases). Slice 039c: so does a movable one.
wants_domain : PickLoop.Setup, ResolveBase.Probed -> Bool
wants_domain = |setup, probed| (setup.free.is_ok() or setup.movable.is_ok()) and probed.compiler.is_ok() and (
	match probed.domain {
		Err(NotRead) => Bool.True
		Ok(_) => Bool.False
	}
)

# R-UM1, D1, D8: the scan of the used modules of a tuple, for each member of the workspace (`UnitFlow.scan_in!`, one read for each level). The closure of each member is built from the facts that the loop has. The modules of a release are the union over the members.
scan_rows! : Fx, ResolveBase.Request, PickLoop.Input, PickLoop.Setup, PickLoop.State, { ids : List(Str), chosen : List(Pick.Chosen) } => List({ id : Str, modules : List(Str) })
scan_rows! = |fx, request, input, setup, state, scan| {
	nodes = state.facts.map(|f| Pick.node_of(f)).concat(state.paths)
	picked = input.slots.map2(scan.chosen, |slot, c| { alias: slot.id, files: slot.files, is_platform: slot.is_platform, url: c.url })
	var $used = []
	for member in setup.members {
		mine = picked.keep_if(|p| p.files.is_empty() or p.files.contains(member.file)).map(|p| { alias: p.alias, value: p.url, is_platform: p.is_platform })
		unmanaged = match input.unmanaged.find_first(|u| u.file == member.file) {
			Ok(u) => u.entries
			Err(_) => []
		}
		match Closure.step({ file: member.file, entries: mine.concat(unmanaged), nodes }) {
			Done(walked) => {
				$used = $used.concat(UnitFlow.scan_in!(fx, { roots: request.roots, member: { file: member.file, kind: member.kind, text: member.text }, walked }))
			}
			_ => {}
		}
	}
	used = $used
	scan.ids.map(|id| { id, modules: used.keep_if(|u| u.hash == hash_of(id)).map(|u| u.path).fold([], |found, path| if found.contains(path) found else found.append(path)) })
}

hash_of : Str -> Str
hash_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => ""
}

# One `Gather.get!` for the ids of a `Need`: a release URL gives a fact, a path file gives a node of the closure.
read_all! : Fx, ResolveBase.Request, List(Str), List(ResolveBase.Fact), List(Closure.Node) => Try({ facts : List(ResolveBase.Fact), paths : List(Closure.Node), seen : List(BuildTarget.Seen) }, Fail)
read_all! = |fx, request, ids, facts, paths| {
	got = Gather.get!(fx, { roots: request.roots, net: request.net, offline: request.offline, selected: request.selected, none: request.none }, ids)?
	var $facts = facts
	var $paths = paths
	var $seen = no_seen
	for g in got {
		match Ident.of_url(g.id) {
			Ok(_) => {
				release = Release.read({ path: g.path, text: g.text })?
				$facts = $facts.append({ url: g.id, release })
				if release.kind == Platform {
					$seen = $seen.append({ url: g.id, found: BuildTarget.targets_of(g.text) })
				}
			}
			Err(Foreign) => {
				$paths = $paths.append({ id: g.id, entries: Release.entries_of({ path: g.path, text: g.text })? })
			}
		}
	}
	Ok({ facts: $facts, paths: $paths, seen: $seen })
}

no_seen : List(BuildTarget.Seen)
no_seen = []

# The release URLs of a slot: its candidates and its current value (R-C10).
slot_urls : Pick.Slot -> List(Str)
slot_urls = |slot| slot.candidates.map(|c| c.url).concat(slot.current.map_ok(|url| [url]) ?? [])

# The URLs that platform slots have now, that a member wants a target of (R-C10), and that no fact has yet. A value that is no release URL is not read.
unread_current : List(Pick.Slot), List(BuildTarget.Want), List(ResolveBase.Fact) -> List(Str)
unread_current = |slots, wants, facts| slots
	.keep_if(|slot| slot.is_platform)
	.keep_oks(|slot| slot.current)
	.keep_if(|url| wants.any(|w| w.url == url) and Ident.of_url(url).is_ok() and !facts.any(|f| f.url == url))
	.fold(ResolveBase.no_names, |found, url| if found.contains(url) found else found.append(url))

# R-C10, OP10: when the gate left a platform slot with no release, the failure of the solver (R-C4) is the failure of the build target (exit 10). Another failure stays as it is.
no_target : List(Pick.Slot), { wants : List(BuildTarget.Want), seen : List(BuildTarget.Seen), before : List(ResolveBase.Fact), after : List(ResolveBase.Fact) }, Fail -> Fail
no_target = |slots, facts, fail| {
	out = |url| facts.before.any(|f| f.url == url and f.release.kind == Platform) and facts.after.any(|f| f.url == url and f.release.kind == App)
	read = |slot| slot_urls(slot).keep_if(|url| facts.before.any(|f| f.url == url))
	dead = slots.find_first(|slot| slot.is_platform and !read(slot).is_empty() and read(slot).all(out))
	lacking = |urls, w| urls.contains(w.url) and facts.seen.any(|s| s.url == w.url and (s.found.map_ok(|list| !list.contains(w.target)) ?? Bool.False))
	if fail.kind != NoTuple {
		fail
	} else {
		match dead {
			Ok(slot) => match facts.wants.find_first(|w| lacking(slot_urls(slot), w)) {
				Ok(w) => BuildTarget.no_release({ alias: slot.id, target: w.target })
				Err(_) => fail
			}
			Err(_) => fail
		}
	}
}

# Q2, R-AD33: a key of `talon.toml` whose release is a platform is not added as a package.
platform_wants : List({ key : Str, name : Str, urls : List(Str) }), List(ResolveBase.Fact) -> Try({}, Fail)
platform_wants = |wants, facts| {
	found = wants.join_map(|w| facts.keep_if(|f| f.release.kind == Platform and w.urls.contains(f.url)).map(|f| (w, f.url)))
	match found {
		[] => Ok({})
		[(w, url), ..] => match Add.decide({ selector: Err(None), chosen: { name: w.name, url, kind: Platform }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: [] }) {
			Err(fail) => Err(fail)
			Ok(_) => Ok({})
		}
	}
}

key_of : OracleBase.Pair -> Db.Key
key_of = |pair| {
	hash = match Ident.of_url(pair.id) {
		Ok(ident) => ident.hash
		Err(_) => ""
	}
	{ hash, nightly: pair.nightly, target: "any" }
}

# The unit of a pair, for `Units.specs` and `Units.results`.
node_of : OracleBase.Pair -> Units.Node
node_of = |pair| match Ident.of_url(pair.id) {
	Ok(ident) => { hash: ident.hash, name: ident.name ?? pair.id, version: ident.version, is_platform: pair.is_platform }
	Err(_) => { hash: "", name: pair.id, version: "", is_platform: pair.is_platform }
}

# R-AL4, R-LF2: one round of the oracle loop. The keys that the command did not look up are asked of the db first (one call). Then the probes: R-P5 cuts them, the compiler starts, one `probes!` call runs the pairs, and the facts are written before the next step (R-PP4).
round! : Fx, ResolveBase.Request, PickLoop.Setup, ResolveBase.Probed, List(OracleBase.Pair) => Try(ResolveBase.Probed, Fail)
round! = |fx, request, setup, probed, pairs| {
	unknown = pairs.map(key_of).keep_if(|key| !probed.looked.contains(key))
	if !unknown.is_empty() {
		rows = Facts.load!(fx, { roots: request.roots, keys: unknown })?
		Ok({ ..probed, checks: probed.checks.concat(rows), looked: probed.looked.concat(unknown) })
	} else if setup.probes == Off {
		Err(Fail.new(Internal, "the lookup of the facts gave no result for each pair"))
	} else {
		probe_round!(fx, request, setup, probed, pairs)
	}
}

probe_round! : Fx, ResolveBase.Request, PickLoop.Setup, ResolveBase.Probed, List(OracleBase.Pair) => Try(ResolveBase.Probed, Fail)
probe_round! = |fx, request, setup, probed, pairs| {
	max = setup.settings.max
	budget = match Units.budget({ max, started: probed.count, fixed: 0, wanted: pairs.len() }) {
		Ok(done) => done
		Err(Spent) => return Err(Units.spent({ max, left: 0 }))
	}
	if budget.run == 0 return Err(Units.spent({ max, left: 0 }))
	# Slice 039b (R-P5): a download is for a probe that can start, so the step runs after the budget and before the compiler starts.
	stepped = PickOptional.step!(fx, request, { settings: setup.settings, sizes: setup.optional.sizes, pairs: pairs.take_first(budget.run) }, probed.optional)?
	if stepped.pairs.is_empty() return Ok({ ..probed, optional: stepped.state })
	begun = begin!(fx, request, setup, { ..probed, optional: stepped.state })?
	started = { ..begun.started, installed: begun.started.installed.concat(stepped.state.got) }
	run = stepped.pairs
	pkgs = request.roots.pkgs
	var $groups = no_groups
	var $specs = []
	# One compiler can have 2 spellings (R-CV1): the started compiler keeps its id.
	of = |p| if Pin.same_id(p.nightly, started.id) started.id else p.nightly
	for id in run.map(of).fold([], |found, nightly| if found.contains(nightly) found else found.append(nightly)) {
		nodes = run.keep_if(|p| of(p) == id).map(node_of)
		on = on_compiler!(fx, request, started, id)?
		$groups = $groups.append({ id, nodes })
		$specs = $specs.concat(Units.specs({ nodes, compiler: id, program: on.program, env: on.env, pkgs, timeout: setup.settings.timeout }))
	}
	outputs = UnitFlow.probes!(fx, { roots: request.roots, now: request.now, pool: setup.settings.slots, started, base: started, specs: $specs })
	if outputs.len() != $specs.len() return Err(Fail.new(Internal, "the probes gave no result for each probe"))
	var $facts = []
	var $failure = Err(None)
	var $at = 0
	for g in $groups {
		results = Units.results({ nodes: g.nodes, outputs: outputs.drop_first($at).take_first(g.nodes.len()), nightly: g.id, compiler: if g.id == started.id setup.held ?? started.id else g.id, pkgs })
		$facts = $facts.concat(results.facts)
		$at = $at + g.nodes.len()
		match ($failure, results.failure) {
			(Err(None), Ok(fail)) => {
				$failure = Ok(fail)
			}
			_ => {}
		}
	}
	_ = Facts.save!(fx, { roots: request.roots, rows: $facts, existing: Replace })?
	match $failure {
		Ok(fail) => Err(fail)
		Err(None) => if budget.cut {
			Err(Units.spent({ max, left: pairs.len() - run.len() }))
		} else {
			Ok({ ..begun.probed, checks: begun.probed.checks.concat($facts), count: begun.probed.count + run.len() })
		}
	}
}

no_groups : List({ id : Str, nodes : List(Units.Node) })
no_groups = []

# Slice 039: the program and the variables of a compiler of the probes. The compiler that started keeps its own. Another compiler is installed (the command downloaded it), so it needs no start: its `.last-use` is written (R-CC9).
on_compiler! : Fx, ResolveBase.Request, Start.Started, Str => Try({ program : Str, env : List((Str, Str)) }, Fail)
on_compiler! = |fx, request, started, id| {
	if id == started.id return Ok({ program: started.program, env: started.env })
	program = Launch.program!(fx, { roots: request.roots, id, installed: started.installed, path: request.compiler })?
	if started.installed.contains(id) {
		Launch.touch!(fx, request.roots, { id, now: request.now })
	}
	Ok({ program, env: started.env })
}

# The compiler of the probes starts once for the command (R-SO22, R-PH7). The facts that were read with the spelling of the held compiler get its id (R-CV1: one compiler, 2 spellings).
begin! : Fx, ResolveBase.Request, PickLoop.Setup, ResolveBase.Probed => Try({ started : Start.Started, probed : ResolveBase.Probed }, Fail)
begin! = |fx, request, setup, probed| match probed.started {
	Ok(started) => Ok({ started, probed })
	Err(None) => {
		held = setup.held ?? ""
		started = Start.run!(fx, { roots: request.roots, path_roc: request.compiler, held, downloads: ResolveBase.ladder_downloads(request) })?
		Ok({ started, probed: rekey({ ..probed, started: Ok(started) }, held, started.id) })
	}
}

rekey : ResolveBase.Probed, Str, Str -> ResolveBase.Probed
rekey = |probed, old, id| if old == id {
	probed
} else {
	{
		..probed,
		compiler: Ok(id),
		checks: probed.checks.map(|f| if f.nightly == old { ..f, nightly: id } else f),
		looked: probed.looked.map(|k| if k.nightly == old { ..k, nightly: id } else k),
	}
}

# R-EP10, R-EP11, Q1 (b) of slice 036: D is the compiler list (`Nightlies.list!` with the clock of the command) when it has the held compiler H, else `[H]` with no inferred fact. A list that cannot be read is no failure of the command.
# Then one `Facts.load!` for the rows of the releases of the slots on each compiler of D that the command has not looked up, and `Epochs.epochs` for the inferred facts.
wide! : Fx, ResolveBase.Request, PickLoop.Input, ResolveBase.Probed => Try(ResolveBase.Probed, Fail)
wide! = |fx, request, input, probed| {
	held = probed.compiler ?? ""
	releases = match probed.listed {
		Ok(list) => list
		Err(NotRead) => PickLoop.releases!(fx, request)
	}
	next = { ..probed, listed: Ok(releases) }
	if releases.any(|r| r.id == held) {
		keys = domain_keys(input, releases, probed.looked)
		rows = Facts.load!(fx, { roots: request.roots, keys })?
		checks = probed.checks.concat(rows)
		Ok({ ..next, domain: Ok(releases.map(|r| r.id)), checks, looked: probed.looked.concat(keys), inferred: Epochs.epochs(releases, checks).inferred })
	} else {
		Ok({ ..next, domain: Ok([held]) })
	}
}

listed! : Fx, ResolveBase.Request => Try(List(Nightlies.Release), [Unread])
listed! = |fx, request| match Toolchain.host(fx.platform!()) {
	Err(_) => Err(Unread)
	Ok(host) => match Nightlies.list!(fx, { net: request.net, roots: request.roots, now: request.now, offline: request.offline, host }) {
		Ok(found) => Ok(found.releases)
		Err(_) => Err(Unread)
	}
}

# The keys of each release of the slots (the candidates and the header value) on each compiler of D, less the keys that the command looked up.
domain_keys : PickLoop.Input, List(Nightlies.Release), List(Db.Key) -> List(Db.Key)
domain_keys = |input, releases, looked| input.slots
	.join_map(|slot| slot.candidates.map(|c| c.url).concat(slot.current.map_ok(|url| [url]) ?? []))
	.fold([], |found, url| if found.contains(url) found else found.append(url))
	.join_map(|url| releases.map(|r| { hash: hash_of(url), nightly: r.id, target: "any" }))
	.keep_if(|key| !looked.contains(key))
