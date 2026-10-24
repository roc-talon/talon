import Add
import Consent
import Fail
import Fx
import Lags
import Lookup
import PickAsk
import PickIndex
import PickLoop
import PickMoves
import Prompt
import Ref
import ResolveBase
import Scope
import Vars

Loaded : ResolveBase.Loaded

Settings : ResolveBase.Settings

Rename : ResolveBase.Rename

Candidates : ResolveBase.Candidates

Asked : ResolveBase.Asked

Picked : ResolveBase.Picked

## The pick of `install`, `update`, `add` and `verify`: the names, the scope, the index and the oracle loop (steps 2 to 7 of `Resolve.install!`). Split from `Resolve` in slice 010.
## Slice 036b: `prepare!` is the part that runs once (the names, the scope, the index). `search!` is the oracle loop (`PickLoop.run!`) with the second search of a held move. The install flow calls `search!` again when the ladder drops a tuple (R-AL6).
PickFlow :: [].{

	## What `search!` needs: the result of `prepare!`. `input` is the input of the first search, `setup` has the probe rounds' settings (`held` is `Err(None)` for no probe).
	Ready : {
		loaded : Loaded,
		settings : Settings,
		snapshot : Try(U64, [None]),
		scoped : List(Vars.Scoped),
		asked : Asked,
		stale : { live : List(Vars.Want), renames : List(Rename) },
		found : List(Candidates),
		known : List(Str),
		prepared : ResolveBase.Prepared,
		input : PickLoop.Input,
		setup : PickLoop.Setup,
	}

	# Steps 2 to 7 of the flow: the names, the scope, the index and the pick (shared by `install!` and `verify!`). `held` is the compiler of the probe rounds (`Err(None)`: no probe and no lookup).
	pick! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Settings, Try(U64, [None]), Try(Str, [None]) => Try(Picked, Fail)
	pick! = |fx, request, loaded, built, settings, snapshot, held| {
		ready = PickFlow.prepare!(fx, request, loaded, built, settings, snapshot, held)?
		PickFlow.search!(fx, request, ready, PickLoop.start(ready.setup, ready.prepared.facts))
	}

	prepare! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Settings, Try(U64, [None]), Try(Str, [None]) => Try(PickFlow.Ready, Fail)
	prepare! = |fx, request, loaded, built, settings, snapshot, held| {
		asked = PickAsk.asked!(fx, request, loaded, built.vars)?
		# A named header entry is moved as `update X@sel` does it (R-AD22).
		command = match request.command {
			Upgrade => Upgrade
			Install => if asked.names.is_empty() Install else Update
			Update => Update
		}
		everyone = Vars.scope({
			command,
			names: asked.names,
			selectors: asked.picks.keep_oks(|p| PickAsk.range_of_selector(p.selector).map_ok(|range| { alias: p.alias, range })),
			vars: built.vars,
		})?
		# `--platform` replaces the platform entry, so the old platform is no variable of the pick (R-AD31).
		scoped = if request.add.as_platform and !asked.fresh.is_empty() everyone.keep_if(|s| !s.variable.is_platform) else everyone
		for s in scoped {
			match s.note {
				Ok(note) => fx.out!("${note}\n")
				Err(None) => {}
			}
		}
		stale = live_wants!(fx, request, built.wants)?
		free_names = scoped.keep_if(|s| s.free).keep_oks(|s| s.variable.name.map_err(|_| None))
		want_names = stale.live.keep_oks(|w| w.name.map_err(|_| None))
		known = built.vars.join_map(|v| v.uses.map(|u| u.url))
		repos = free_names.concat(want_names).concat(asked.fresh.map(|f| f.name)).fold(ResolveBase.no_names, |found, name| if found.contains(name) found else found.append(name))
		found = PickIndex.index!(fx, request, repos, known)?
		prepared = PickIndex.prepare!(fx, request, loaded, asked.fresh, found)?
		input = PickIndex.slots_of(scoped, stale.live, found, asked, prepared.rows, settings, snapshot, PickAsk.unmanaged_of(loaded, asked, request.project.file ?? ""), request.project.file ?? "")
		setup = { held, probes: if request.probe.no_probe Off else Allowed, settings: ResolveBase.probe_settings(request, loaded), members: loaded.members.map(|m| { file: m.file, kind: m.locked.kind, text: ResolveBase.loaded_text(loaded, m.file) }) }
		Ok({ loaded, settings, snapshot, scoped, asked, stale, found, known, prepared, input, setup })
	}

	## The oracle loop of the first search, and the second search of a held move (R-SP16, R-DI1). `state` has what the command read and probed before: the first call has `PickLoop.start`, the call after a dropped tuple has the facts, the count and the dropped tuples.
	search! : Fx, ResolveBase.Request, PickFlow.Ready, PickLoop.State => Try(Picked, Fail)
	search! = |fx, request, ready, state| {
		failed = |fail| with_close_versions(fail, { scoped: ready.scoped, asked: ready.asked, found: ready.found })
		searched = match PickLoop.run!(fx, request, ready.input, ready.setup, state) {
			Ok(c) => { looped: c, moves: [] }
			Err(stuck) => {
				if !PickMoves.second_wanted(stuck.fail, ready.scoped) return Err(failed(stuck.fail))
				# R-SP16, R-DI1: the second search of a held move. The index of the movable groups is read once, in the order of the slots. The facts of the first search stay (R-AL8).
				more = PickIndex.index!(fx, request, movable_names(ready.scoped, ready.found), ready.known)?
				again = {
					..PickIndex.slots_of(ready.scoped, ready.stale.live, ready.found.concat(more), ready.asked, ready.prepared.rows, ready.settings, ready.snapshot, PickAsk.unmanaged_of(ready.loaded, ready.asked, request.project.file ?? ""), request.project.file ?? ""),
					second: Bool.True,
				}
				match PickLoop.run!(fx, request, again, ready.setup, { facts: stuck.facts, paths: stuck.paths, probed: stuck.probed }) {
					Ok(c) => { looped: c, moves: PickMoves.moves_of({ scoped: ready.scoped, slots: again.slots, chosen: c.chosen, facts: c.facts }) }
					Err(second) => if second.fail.kind == NoTuple return Err(failed(stuck.fail)) else return Err(second.fail)
				}
			}
		}
		looped = searched.looped
		# R-UP2: only `upgrade` reports the variables that did not get their newest release.
		lags = match request.command {
			Upgrade => Lags.of({
				slots: ready.input.slots,
				chosen: looped.chosen,
				facts: looped.facts,
				now: request.now,
				min_age: ready.settings.min_age,
				snapshot: ready.snapshot,
				compiler: looped.probed.compiler,
				checks: looped.probed.checks,
				used: looped.probed.used,
			})
			_ => []
		}
		Ok({
			facts: { scoped: ready.scoped, wants: ready.stale.live, asked: ready.asked, prepared: ready.prepared, renames: ready.stale.renames, snapshot: ready.snapshot, known: looped.facts, paths: looped.paths, lags },
			chosen: looped.chosen,
			moves: searched.moves,
			probed: looped.probed,
		})
	}
}

# The names of the movable variables that have no page yet (D6), no repeat.
movable_names : List(Vars.Scoped), List(Candidates) -> List(Str)
movable_names = |scoped, found| scoped
	.keep_if(|s| s.movable)
	.keep_oks(|s| s.variable.name.map_err(|_| None))
	.fold(ResolveBase.no_names, |names, name| if names.contains(name) or found.any(|c| c.name == name) names else names.append(name))

PickInput : PickLoop.Input

# R-SL12, U3 of slice 009: the failure "has no release that satisfies" of a variable with a selector (`update X@sel`) names the close versions of its repository.
with_close_versions : Fail, { scoped : List(Vars.Scoped), asked : Asked, found : List(Candidates) } -> Fail
with_close_versions = |fail, facts| {
	first_alias = |s| s.variable.uses.first().map_ok(|u| u.alias) ?? ""
	hit = facts.scoped.find_first(|s| s.free and fail.message.starts_with("no tuple works: ${first_alias(s)} has no release that satisfies "))
	pick_of = |s| facts.asked.picks.find_first(|p| s.variable.uses.any(|u| u.alias == p.alias))
	match (hit, fail.kind) {
		(Ok(s), NoTuple) => match (pick_of(s), s.variable.name) {
			(Ok(p), Ok(name)) => {
				versions = match facts.found.find_first(|c| c.name == name) {
					Ok(c) => c.list.map(|x| x.ident.version)
					Err(_) => []
				}
				Fail.new(NoTuple, "${fail.message}${Add.close_note({ selector: Ok(p.selector), versions })}")
			}
			_ => fail
		}
		_ => fail
	}
}

# R-I5, R-I8, R-NI1 (D8): a stale key of `[dependencies]` is the prompt of `install` and `add`: the report, then the question. `Yes` renames the key
# at the write, `No` keeps it. `update` and a stale key of `[overrides]` keep the warning. A key with a short name has no index (R-AD6).
live_wants! : Fx, ResolveBase.Request, List(Vars.Want) => Try({ live : List(Vars.Want), renames : List(Rename) }, Fail)
live_wants! = |fx, request, wants| {
	var $live = no_wants
	var $ask = no_wants
	for w in wants {
		match w.stale {
			Ok(alias) => if request.command == Install and w.table == Dependencies {
				$ask = $ask.append(w)
			} else {
				fx.err!("warning: ${w.from}: the key \"${w.key}\" names ${w.name ?? w.key}, which the header has as \"${alias}\"\n")
			}
			Err(None) => if request.command == Install {
				match w.name {
					Err(Short(text)) => return Err(short_failure(w.from, text))
					Ok(_) => {
						$live = $live.append(w)
					}
				}
			}
		}
	}
	Ok({ live: $live, renames: ask_rename!(fx, request, $ask)? })
}

ask_rename! : Fx, ResolveBase.Request, List(Vars.Want) => Try(List(Rename), Fail)
ask_rename! = |fx, request, stale| {
	if stale.is_empty() return Ok([])
	consent = Consent.rename_keys(stale.map(|w| { key: w.key, name: w.name ?? w.key, alias: w.stale ?? "" }))
	fx.err!(consent.report)
	done = Prompt.ask!(fx, consent.prompt, { mode: request.prompt.mode, yes: request.prompt.yes, quiet: request.prompt.quiet, flag: request.prompt.rename_keys })?
	if done.answer == Yes {
		Ok(
			stale.map(
				|w| {
					path = match w.from.split_last(":") {
						Ok({ before, .. }) => before
						Err(_) => w.from
					}
					{ path, from: w.key, to: w.stale ?? "" }
				},
			),
		)
	} else {
		Ok([])
	}
}

no_wants : List(Vars.Want)
no_wants = []

short_failure : Str, Str -> Fail
short_failure = |from, text| match Ref.parse(text, Scope.Install, Bool.False) {
	Err(fail) => Fail.new(fail.kind, "${from}: ${fail.message}")
	Ok(ref) => match Lookup.find(Scope.Install, ref, []) {
		Err({ fail, .. }) => Fail.new(fail.kind, "${from}: ${fail.message}")
		Ok(_) => Fail.new(Usage, "${from}: '${text}' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).")
	}
}
