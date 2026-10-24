import Db
import Facts
import Fail
import Fx
import Launch
import Net
import Nightlies
import Probe
import ProbeRange
import Roots
import Toolchain
import Units

## The command code of `tln probe --range` (slice 037, R-PB3, R-PB4, R-PP2, R-PP4, R-P5, R-AL4, R-NS3, R-C7). The pure rounds are `ProbeRange.step`. The calls, in order (the L2 case `probe/pc2-range` fixes them):
##
## | Step | Call |
## | --- | --- |
## | 1 | `fx.platform!`, then `Nightlies.list!`: the compiler list (R-CV1). D is the candidates of the list in the order of R-NS1 (R-EP11). A list that cannot be read is the failure of the run |
## | 2 | One `Facts.load!` for all releases of D (R-AL4) |
## | 3 | `Launch.child_env!` (one `canonical!` call) |
## | 4 | Rounds. `ProbeRange.step`, `Units.budget` (R-P5), `Launch.program!` and `Launch.touch!` for each compiler (R-CC9), one `fx.probes!` call, `Units.results` for each probe, one `Facts.save!` with `Replace` (R-PP4) |
##
## The askable releases are the installed compilers that the `nightly` switch and `min-release-age` allow (`Toolchain.domain`, R-NS3, R-C7). No compiler is downloaded here (R-NI4, slice 037c).
ProbeSearch :: [].{

	## `hash` and `node` name the target. `installed` are the ids of `<cache>/toolchains`. `path` is the `roc` on `PATH` (the program of a link or a copy is not needed: an installed id has its own file).
	Run : {
		roots : Roots,
		net : Net.Settings,
		now : U64,
		offline : Bool,
		node : Units.Node,
		installed : List(Str),
		path : Try({ id : Str, path : Str }, [NoCompiler]),
		nightly : Bool,
		min_age : U64,
		probe : Probe.Settings,
	}

	## What the search found: the range, the number of probes that started, the failure of the budget when `probe.max` cut a round, and the number of releases of D with no fact (for `ProbeCmd.stop`).
	Found : { found : ProbeRange.Found, probes : U64, cut : Try(Fail, [None]), unseen : U64 }

	run! : Fx, ProbeSearch.Run => Try(ProbeSearch.Found, Fail)
	run! = |fx, run| {
		host = Toolchain.host(fx.platform!())?
		listed = Nightlies.list!(fx, { net: run.net, roots: run.roots, now: run.now, offline: run.offline, host })?
		domain = Nightlies.candidates(listed.releases).map(|r| r.id)
		allowed = Toolchain.domain({ releases: listed.releases, now: run.now, min_age: run.min_age, nightly: run.nightly }).auto
		askable = allowed.keep_if(|id| run.installed.contains(id))
		hash = run.node.hash
		rows = Facts.load!(fx, { roots: run.roots, keys: domain.map(|id| { hash, nightly: id, target: "any" }) })?
		env = Launch.child_env!(fx, run.roots, { opted_out: Bool.False })
		start = { facts: rows, probes: 0, cut: Err(None) }
		ended = rounds!(fx, run, { domain, askable, env }, start)?
		input = { hash, domain, askable, facts: ended.facts }
		Ok({
			found: ProbeRange.found(input),
			probes: ended.probes,
			cut: ended.cut,
			unseen: domain.count_if(|id| !ended.facts.any(|f| f.hash == hash and f.nightly == id and f.target == "any")),
		})
	}
}

World : { domain : List(Str), askable : List(Str), env : List((Str, Str)) }

State : { facts : List(Db.Fact), probes : U64, cut : Try(Fail, [None]) }

# One round and the next, until `step` is done or the budget cuts a round.
rounds! : Fx, ProbeSearch.Run, World, State => Try(State, Fail)
rounds! = |fx, run, world, state| match ProbeRange.step({ hash: run.node.hash, domain: world.domain, askable: world.askable, facts: state.facts }) {
	Done(_) => Ok(state)
	Need(ids) => {
		room = Units.budget({ max: run.probe.max, started: state.probes, fixed: 0, wanted: ids.len() }) ?? { run: 0, cut: Bool.True }
		asked = ids.take_first(room.run)
		cut = if room.cut Ok(Units.spent({ max: run.probe.max, left: ids.len() - asked.len() })) else Err(None)
		if asked.is_empty() {
			Ok({ ..state, cut })
		} else {
			made = round!(fx, run, world, asked)?
			next = { facts: state.facts.concat(made), probes: state.probes + asked.len(), cut }
			if room.cut Ok(next) else rounds!(fx, run, world, next)
		}
	}
}

# One round (R-PP2): the compilers are touched, the probes start in one call, the facts of the round are written at once (R-PP4). The first probe with no fact is the failure, after the facts are saved.
round! : Fx, ProbeSearch.Run, World, List(Str) => Try(List(Db.Fact), Fail)
round! = |fx, run, world, asked| {
	pkgs = run.roots.pkgs
	var $specs = []
	for id in asked {
		program = Launch.program!(fx, { roots: run.roots, id, installed: run.installed, path: run.path })?
		Launch.touch!(fx, run.roots, { id, now: run.now })
		$specs = $specs.concat(Units.specs({ nodes: [run.node], compiler: id, program, env: world.env, pkgs, timeout: run.probe.timeout }))
	}
	outputs = fx.probes!({ pool: run.probe.slots, specs: $specs })
	if outputs.len() != asked.len() return Err(Fail.new(Internal, "the probes gave no result for each probe"))
	results = asked.map2(outputs, |id, output| Units.results({ nodes: [run.node], outputs: [output], nightly: id, compiler: id, pkgs }))
	made = results.join_map(|r| r.facts)
	_ = Facts.save!(fx, { roots: run.roots, rows: made, existing: Replace })?
	match results.keep_oks(|r| r.failure).first() {
		Ok(fail) => Err(fail)
		Err(_) => Ok(made)
	}
}
