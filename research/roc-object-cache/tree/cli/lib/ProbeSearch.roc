import Answer
import Consent
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
import RocInstall
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
		first = rounds!(fx, run, { domain, askable, env }, start)?
		wide = { allowed, sizes: sizes_of(listed.releases) }
		more = { facts: first.facts, probes: first.probes, cut: first.cut, have: run.installed, tried: 0, downloads: 0, removed: [], dropped: 0 }
		ended = if first.cut.is_ok() Ok(more) else more!(fx, run, { domain, askable, env }, wide, more)
		last = ended?
		if run.probe.max_toolchains > 0 and last.dropped > 0 {
			fx.err!("${Consent.optional_capped({ cap: run.probe.max_toolchains, dropped: last.dropped })}\n")
		}
		input = { hash, domain, askable, facts: last.facts }
		Ok({
			found: ProbeRange.found(input),
			probes: last.probes,
			cut: last.cut,
			unseen: domain.count_if(|id| !last.facts.any(|f| f.hash == hash and f.nightly == id and f.target == "any")),
			downloads: last.downloads,
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

# Phase 2 (R-NI4): `allowed` are the releases that the switch and `min-release-age` allow. `sizes` are the asset sizes of the list.
Wide : { allowed : List(Str), sizes : List({ id : Str, size : U64 }) }

# `have` are the installed ids (also the downloaded ones). `tried` counts the downloads that started (a failed one too, R-DL6). `removed` are the ids that are not asked again (failed or dropped by the cap). `dropped` counts the ids that the cap dropped.
More : { facts : List(Db.Fact), probes : U64, cut : Try(Fail, [None]), have : List(Str), tried : U64, downloads : U64, removed : List(Str), dropped : U64 }

sizes_of : List(Nightlies.Release) -> List({ id : Str, size : U64 })
sizes_of = |releases| releases.keep_oks(
	|r| match r.asset {
		Ok(asset) => Ok({ id: r.id, size: asset.size })
		Err(_) => Err(NoAsset)
	},
)

# One round of phase 2: the budget, the downloads that the cap and the opt-in allow, the probes, then the next round.
more! : Fx, ProbeSearch.Run, World, Wide, More => Try(More, Fail)
more! = |fx, run, world, wide, state| {
	askable = wide.allowed.keep_if(|id| !state.removed.contains(id))
	match ProbeRange.step({ hash: run.node.hash, domain: world.domain, askable, facts: state.facts }) {
		Done(_) => Ok(state)
		Need(ids) => {
			room = Units.budget({ max: run.probe.max, started: state.probes, fixed: 0, wanted: ids.len() }) ?? { run: 0, cut: Bool.True }
			wanted = ids.take_first(room.run)
			cut = if room.cut Ok(Units.spent({ max: run.probe.max, left: ids.len() - wanted.len() })) else Err(None)
			if wanted.is_empty() {
				Ok({ ..state, cut })
			} else {
				plan = Consent.optional_round({ ids: wanted, installed: state.have, left: run.probe.max_toolchains - state.tried, sizes: wide.sizes })
				match Consent.optional_want({ count: plan.fetch.len(), mode: run.mode, yes: run.yes, flag: run.flag }) {
					Nothing => Ok({ ..state, dropped: state.dropped + plan.dropped.len() })
					Skip => {
						fx.err!("${Consent.optional_skipped({ count: plan.fetch.len(), size: plan.size })}\n")
						Ok(state)
					}
					Download => {
						got = fetch!(fx, run, plan.fetch, state)
						next = probed!(fx, run, world, { plan, got, cut, state })?
						if room.cut Ok(next) else more!(fx, run, world, wide, next)
					}
				}
			}
		}
	}
}

Plan : { asked : List(Str), fetch : List({ id : Str, size : U64 }), dropped : List(Str), size : U64 }

Got : { have : List(Str), failed : List(Str), tried : U64, downloads : U64 }

# The probes of the asked releases that did not fail to download, with the new ids in the installed list.
probed! : Fx, ProbeSearch.Run, World, { plan : Plan, got : Got, cut : Try(Fail, [None]), state : More } => Try(More, Fail)
probed! = |fx, run, world, step| {
	ids = step.plan.asked.keep_if(|id| !step.got.failed.contains(id))
	made = if ids.is_empty() Ok([]) else round!(fx, { ..run, installed: step.got.have }, world, ids)
	Ok({
		facts: step.state.facts.concat(made?),
		probes: step.state.probes + ids.len(),
		cut: step.cut,
		have: step.got.have,
		tried: step.got.tried,
		downloads: step.got.downloads,
		removed: step.state.removed.concat(step.got.failed).concat(step.plan.dropped),
		dropped: step.state.dropped + step.plan.dropped.len(),
	})
}

# The downloads of one round, in order. A failure is a warning: the release gets no fact (R-P3) and is not asked again.
fetch! : Fx, ProbeSearch.Run, List({ id : Str, size : U64 }), More => Got
fetch! = |fx, run, list, state| {
	var $got = { have: state.have, failed: [], tried: state.tried, downloads: state.downloads }
	for item in list {
		match fetch_one!(fx, run, item.id) {
			Ok(Present) => {
				$got = { ..$got, have: $got.have.append(item.id) }
			}
			Ok(Installed) => {
				$got = { ..$got, have: $got.have.append(item.id), tried: $got.tried + 1, downloads: $got.downloads + 1 }
			}
			Err(fail) => {
				fx.err!("${Consent.optional_failed({ id: item.id, text: fail.message })}\n")
				$got = { ..$got, failed: $got.failed.append(item.id), tried: $got.tried + 1 }
			}
		}
	}
	$got
}

# `Present`: another process installed the release, so no download was made.
fetch_one! : Fx, ProbeSearch.Run, Str => Try([Present, Installed], Fail)
fetch_one! = |fx, run, id| match RocInstall.offer!(fx, { id, env: run.env, offline: run.offline })? {
	Present(_) => Ok(Present)
	Download(offer) => {
		fx.err!("${Consent.optional_line({ id: offer.id, size: offer.size })}\n")
		_ = RocInstall.install_offer!(fx, offer)?
		Ok(Installed)
	}
}
