import Answer
import Db
import Facts
import Fail
import Fx
import Launch
import Mode
import Net
import Nightlies
import Probe
import ProbeRange
import Roots
import Toolchain
import Units

## The command code of `tln probe --range` (slice 037, R-PB3, R-PB4, R-PP2, R-PP4, R-P5, R-AL4, R-NS3, R-C7; slice 037c: R-NI4, R-DL1, R-DL4, R-DL5, R-DL6). The pure rounds are `ProbeRange.step`. The calls, in order (the L2 cases `probe/pc2-range` and `probe/pd1-downloads` fix them):
##
## | Step | Call |
## | --- | --- |
## | 1 | `fx.platform!`, then `Nightlies.list!`: the compiler list (R-CV1). D is the candidates of the list in the order of R-NS1 (R-EP11). A list that cannot be read is the failure of the run |
## | 2 | One `Facts.load!` for all releases of D (R-AL4) |
## | 3 | `Launch.child_env!` (one `canonical!` call) |
## | 4 | Phase 1 (R-P5 "installed nightlies are tried first"). Rounds. `ProbeRange.step` with the installed candidates as `askable`, `Units.budget` (R-P5), `Launch.program!` and `Launch.touch!` for each compiler (R-CC9), one `fx.probes!` call, `Units.results` for each probe, one `Facts.save!` with `Replace` (R-PP4) |
## | 5 | Phase 2, only when phase 1 ended with no cut. `ProbeRange.step` with all the candidates that the `nightly` switch and `min-release-age` allow as `askable` (R-NS3, R-C7). A `Done` ends the search. A `Need` is one more round, with the table below |
##
## Phase 2 (slice 037c, the tested reading: questions Q1 to Q6 of `docs/slices/037c-probe-downloads.md`). `ids` are the releases of the `Need`. The steps of one round, in this order:
##
## | # | Step | Rule |
## | --- | --- | --- |
## | 1 | `Units.budget` over `ids.len()` (a download is for a probe that can start: no room, no download). `wanted` is the first `room.run` ids. A `cut` ends the search after this round, as in phase 1 | R-P5 |
## | 2 | `Consent.optional_round` with `wanted`, the installed ids, `left` (the cap `probe.max-toolchains` minus the downloads tried so far) and the sizes of the list | R-DL6 |
## | 3 | `Consent.optional_want` with `count` = `fetch.len()`, the mode, `--yes` and `--probe-downloads`. `Nothing`: the search ends. `Skip`: `fx.err!` of `Consent.optional_skipped`, then the search ends (no `tty!` call, no prompt). `Download`: step 4 | R-NI4, R-DL4 |
## | 4 | For each id of `fetch`, in order: `RocInstall.offer!` (`Present`: the compiler is installed, no download), then `fx.err!` of `Consent.optional_line`, then `RocInstall.install_offer!`. A failure of `offer!` or of `install_offer!` is a warning on stderr (`Consent.optional_failed`): the release gets no fact (R-P3) and is not asked again. A failed download counts for the cap | R-DL6, R-P3 |
## | 5 | The round of probes for `asked` without the ids that failed, with the installed list that has the new ids (steps of phase 1). The ids that the cap dropped, and the ids that failed, are not askable for the rest of the search | R-PP2, R-PP4 |
##
## At the end of phase 2, when the cap is above 0 and the cap dropped releases, one line `Consent.optional_capped` on stderr. The number of downloads that went well is `Found.downloads` (`data.downloads`, as slice 025 Q7).
ProbeSearch :: [].{

	## `hash` and `node` name the target. `installed` are the ids of `<cache>/toolchains`. `path` is the `roc` on `PATH` (the program of a link or a copy is not needed: an installed id has its own file). `env` is the environment of the process (`RocInstall.offer!`).
	## `flag`, `yes` and `mode` are the facts of `Consent.optional_want`: `--probe-downloads`, `--yes` and the mode of the run. The cap is `probe.max_toolchains`.
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
		env : List((Str, Str)),
		flag : Try(Answer, [NoFlag]),
		yes : Bool,
		mode : Mode,
	}

	## What the search found: the range, the number of probes that started, the failure of the budget when `probe.max` cut a round, the number of releases of D with no fact (for `ProbeCmd.stop`), and the number of compilers that the search downloaded.
	Found : { found : ProbeRange.Found, probes : U64, cut : Try(Fail, [None]), unseen : U64, downloads : U64 }

	# STUB (slice 037c): phase 1 only, as slice 037. `run.env`, `run.flag`, `run.yes` and `run.mode` are not read yet. The code agent writes phase 2 (the doc of `ProbeSearch`).
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
			downloads: 0,
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
