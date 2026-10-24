import Add
import Closure
import Db
import Facts
import Fail
import Fx
import Gather
import Ident
import Oracle
import Pick
import Probe
import Release
import ResolveBase
import Start
import UnitFlow
import Units

## Step G of the flow: `Oracle.step_probed` (slice 036 and 036b: the solver, the probe facts of one compiler) until `Done` or `Fail` (slice 016, R-AL8, R-AL9). Split from `PickFlow` (module size).
## A `Need` goes to `Gather.get!`, the same call as the closure walk makes: one fetch and one read for all ids of the list. A release URL gives a fact
## (`Release.read`), a path file gives a node of the closure (`Release.entries_of`). The facts and the nodes stay for the walk after the pick (R-AL8, source 1).
## Slice 036b: a `Pairs` is a probe round. The keys that the command did not look up go to the db first (one `Facts.load!`). Then, with `Allowed`, the pairs are probed in one `probes!` call and the facts are written at once (R-PP4);
## the budget `probe.max` (R-P5) counts all probes of the command. A cut is exit 12 after the facts of the probes that ran are saved (R-UP7). With `Off` (`--no-probe`) the lookup is all that a round does (R-LF2).
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
	Setup : { held : Try(Str, [None]), probes : [Allowed, Off], settings : Probe.Settings }

	## What a search starts with: the facts and the nodes that the command has read, and the facts of the probe rounds.
	State : { facts : List(ResolveBase.Fact), paths : List(Closure.Node), probed : ResolveBase.Probed }

	Looped : { chosen : List(Pick.Chosen), facts : List(ResolveBase.Fact), paths : List(Closure.Node), probed : ResolveBase.Probed }

	## A search that ended with no tuple. `facts`, `paths` and `probed` are what the loop read and learned, so the second search of a held move starts with them (slice 017, R-AL8: no file is read twice; slice 036b: the budget goes on).
	Stuck : { fail : Fail, facts : List(ResolveBase.Fact), paths : List(Closure.Node), probed : ResolveBase.Probed }

	## The first state of a command: nothing read, nothing probed.
	start : PickLoop.Setup, List(ResolveBase.Fact) -> PickLoop.State
	start = |setup, facts| { facts, paths: [], probed: { compiler: setup.held, checks: [], looked: [], count: 0, started: Err(None), tried: [] } }

	run! : Fx, ResolveBase.Request, PickLoop.Input, PickLoop.Setup, PickLoop.State => Try(PickLoop.Looped, PickLoop.Stuck)
	run! = |fx, request, input, setup, state| {
		probed = state.probed
		compat = { compiler: probed.compiler, checks: probed.checks, looked: probed.looked, probes: setup.probes, conflicts: probed.tried, used: [] }
		match Oracle.step_probed({ slots: input.slots, strategy: input.strategy, now: request.now, min_age: input.min_age, snapshot: input.snapshot, facts: state.facts, unmanaged: input.unmanaged, paths: state.paths, second: input.second }, compat) {
			Done(chosen) => Ok({ chosen, facts: state.facts, paths: state.paths, probed })
			Fail(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
			Need(ids) => match read_all!(fx, request, ids, state.facts, state.paths) {
				Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
				Ok(read) => match platform_wants(input.want_slots, read.facts) {
					Err(fail) => Err({ fail, facts: read.facts, paths: read.paths, probed })
					Ok(_) => run!(fx, request, input, setup, { facts: read.facts, paths: read.paths, probed })
				}
			}
			Scan(_) => Err({ fail: Fail.new(Internal, "todo: the scan of the used modules (slice 036b2)"), facts: state.facts, paths: state.paths, probed })
			Pairs(pairs) => match round!(fx, request, setup, probed, pairs) {
				Err(fail) => Err({ fail, facts: state.facts, paths: state.paths, probed })
				Ok(next) => run!(fx, request, input, setup, { ..state, probed: next })
			}
		}
	}
}

# One `Gather.get!` for the ids of a `Need`: a release URL gives a fact, a path file gives a node of the closure.
read_all! : Fx, ResolveBase.Request, List(Str), List(ResolveBase.Fact), List(Closure.Node) => Try({ facts : List(ResolveBase.Fact), paths : List(Closure.Node) }, Fail)
read_all! = |fx, request, ids, facts, paths| {
	got = Gather.get!(fx, { roots: request.roots, net: request.net, offline: request.offline }, ids)?
	var $facts = facts
	var $paths = paths
	for g in got {
		match Ident.of_url(g.id) {
			Ok(_) => {
				$facts = $facts.append({ url: g.id, release: Release.read({ path: g.path, text: g.text })? })
			}
			Err(Foreign) => {
				$paths = $paths.append({ id: g.id, entries: Release.entries_of({ path: g.path, text: g.text })? })
			}
		}
	}
	Ok({ facts: $facts, paths: $paths })
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

key_of : Oracle.Pair -> Db.Key
key_of = |pair| {
	hash = match Ident.of_url(pair.id) {
		Ok(ident) => ident.hash
		Err(_) => ""
	}
	{ hash, nightly: pair.nightly, target: "any" }
}

# The unit of a pair, for `Units.specs` and `Units.results`.
node_of : Oracle.Pair -> Units.Node
node_of = |pair| match Ident.of_url(pair.id) {
	Ok(ident) => { hash: ident.hash, name: ident.name ?? pair.id, version: ident.version, is_platform: pair.is_platform }
	Err(_) => { hash: "", name: pair.id, version: "", is_platform: pair.is_platform }
}

# R-AL4, R-LF2: one round of the oracle loop. The keys that the command did not look up are asked of the db first (one call). Then the probes: R-P5 cuts them, the compiler starts, one `probes!` call runs the pairs, and the facts are written before the next step (R-PP4).
round! : Fx, ResolveBase.Request, PickLoop.Setup, ResolveBase.Probed, List(Oracle.Pair) => Try(ResolveBase.Probed, Fail)
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

probe_round! : Fx, ResolveBase.Request, PickLoop.Setup, ResolveBase.Probed, List(Oracle.Pair) => Try(ResolveBase.Probed, Fail)
probe_round! = |fx, request, setup, probed, pairs| {
	max = setup.settings.max
	budget = match Units.budget({ max, started: probed.count, fixed: 0, wanted: pairs.len() }) {
		Ok(done) => done
		Err(Spent) => return Err(Units.spent({ max, left: 0 }))
	}
	if budget.run == 0 return Err(Units.spent({ max, left: 0 }))
	begun = begin!(fx, request, setup, probed)?
	started = begun.started
	nodes = pairs.take_first(budget.run).map(node_of)
	pkgs = request.roots.pkgs
	specs = Units.specs({ nodes, compiler: started.id, program: started.program, env: started.env, pkgs, timeout: setup.settings.timeout })
	outputs = UnitFlow.probes!(fx, { roots: request.roots, now: request.now, pool: setup.settings.slots, started, base: started, specs })
	if outputs.len() != nodes.len() return Err(Fail.new(Internal, "the probes gave no result for each probe"))
	results = Units.results({ nodes, outputs, nightly: started.id, compiler: setup.held ?? started.id, pkgs })
	_ = Facts.save!(fx, { roots: request.roots, rows: results.facts, existing: Replace })?
	match results.failure {
		Ok(fail) => Err(fail)
		Err(None) => if budget.cut {
			Err(Units.spent({ max, left: pairs.len() - nodes.len() }))
		} else {
			Ok({ ..begun.probed, checks: begun.probed.checks.concat(results.facts), count: begun.probed.count + nodes.len() })
		}
	}
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
