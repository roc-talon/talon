import records.Closure as Wire
import Add
import ClosureIndex
import ClosureRequest
import Consent
import Fail
import Fx
import Help
import Ident
import IndexQuery
import Lags
import LogSnapshot
import Lookup
import NightlyFlow
import NightlyPlan
import Pick
import PickAsk
import PickIndex
import PickLoop
import PickMoves
import PrivacyGuard
import Prompt
import Ref
import ResolveBase
import Scope
import UnknownValues
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
	## Slice 206b: `request` is the request of the rest of the run: with a registry (`registry` is `Read`), its `index` is the `Answer` of the first closure query.
	Ready : {
		request : ResolveBase.Request,
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
		second : Try(PickFlow.Second, [None]),
	}

	## Slice 206d2 (Registry R-AP16 second query, R-AP19, Design Q403, Q404, Q460): what the second closure query of a held move needs, from the first query of a run with a registry. `Err(None)` with no registry answer.
	## `first` is the answer that the first search used (the answer of `UnknownValues.settle!`, not hidden), `compilers` the window of the first request, `keep` its `hashes`, `user` the N of `--snapshot log:N`, `anchors` the anchor URLs (R-DI11).
	Second : { origin : Str, first : Wire.Answer, compilers : Try(Wire.Window, [None]), keep : List(Str), user : Try(U64, [None]), anchors : List(Str) }

	## Slice 039: `free` are the values of the compiler slot (`NightlyFlow.Plan.free`). Slice 039b: `optional` are the optional compilers (`NightlyFlow.Plan.optional`). Slice 039c: `newest` is N (`NightlyFlow.Plan.newest`).
	prepare! : Fx, ResolveBase.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Settings, Try(U64, [None]), Try(Str, [None]), Try(List(Str), [Held]), Try(Str, [NoneKnown]), { ids : List(Str), sizes : List({ id : Str, size : U64 }) } => Try(PickFlow.Ready, Fail)
	prepare! = |fx, request, loaded, built, settings, snapshot, held, free, newest, optional| {
		asked = PickAsk.asked!(fx, request, loaded, built.vars)?
		# A named header entry is moved as `update X@sel` does it (R-AD22).
		command = match request.command {
			Upgrade => if NightlyPlan.scope(request.names).who == None NightlyOnly else Upgrade
			Install => if asked.names.is_empty() Install else Update
			Update => Update
		}
		everyone = Vars.scope({
			command,
			names: asked.names,
			fixed: request.fixed,
			selectors: asked.picks.keep_oks(|p| PickAsk.range_of_selector(p.selector).map_ok(|range| { alias: p.alias, range })),
			vars: built.vars,
		})?
		# `--platform` replaces the platform entry, so the old platform is no variable of the pick (R-AD31).
		scoped = if request.add.as_platform and !asked.fresh.is_empty() everyone.keep_if(|s| !s.variable.is_platform) else everyone
		# Slice 206d (reading 6, Design Q462): with a registry the `direct` text of a `Fixed` host (R-DI11) is not printed. With the `Offline` index it prints `<alias>: fixed: not in the registry index` (Design Q465).
		registry = match (request.registry, request.index) {
			(Read(_), _) | (_, Offline(_)) => Bool.True
			_ => Bool.False
		}
		for s in scoped {
			match s.note {
				Ok(_) if registry and s.variable.host != Indexed => {
					# Design Q465: offline, a value of another host prints the line of R-AP28, as online (online it comes from `settle!`).
					match request.index {
						Offline(_) => fx.out!("${s.variable.uses.first().map_ok(|u| u.alias) ?? ""}: fixed: not in the registry index\n")
						_ => {}
					}
				}
				Ok(note) => fx.out!("${note}\n")
				Err(None) => {}
			}
		}
		stale = live_wants!(fx, request, built.wants)?
		queried = query!(fx, request, loaded, IndexQuery.groups(scoped))?
		indexed = queried.request
		# Slice 206d2 (R-SP23, R-DI11): a fixed anchor of the closure answer is never movable.
		held_scope = IndexQuery.held_anchors({ scoped, anchors: queried.anchors })
		free_names = scoped.keep_if(|s| s.free).keep_oks(|s| s.variable.name.map_err(|_| None))
		want_names = stale.live.keep_oks(|w| w.name.map_err(|_| None))
		known = built.vars.join_map(|v| v.uses.map(|u| u.url))
		repos = free_names.concat(want_names).concat(asked.fresh.map(|f| f.name)).fold(ResolveBase.no_names, |found, name| if found.contains(name) found else found.append(name))
		found = anchored(PickIndex.index!(fx, indexed, repos, known)?, queried.anchors)
		offline_notes!(fx, indexed, held_scope, found)
		prepared = PickIndex.prepare!(fx, indexed, loaded, asked.fresh, found)?
		input = PickIndex.slots_of(held_scope, stale.live, found, asked, prepared.rows, settings, snapshot, PickAsk.unmanaged_of(loaded, asked, request.project.file ?? ""), request.project.file ?? "")
		setup = { held, free, newest, movable: Err(None), optional, probes: if request.probe.no_probe Off else Allowed, settings: ResolveBase.probe_settings(request, loaded), members: loaded.members.map(|m| { file: m.file, kind: m.locked.kind, text: ResolveBase.loaded_text(loaded, m.file), target: ResolveBase.member_target(m) }) }
		Ok({ request: indexed, loaded, settings, snapshot, scoped: held_scope, asked, stale, found, known, prepared, input, setup, second: queried.second })
	}

	## Slice 206e2 (R-AP16, R-AP74, R-RG4, R-DI1, R-CM6): the first closure query of a command that only reports (`tln outdated`), with its `groups` (`IndexQuery.report_groups`) and the window of `request` (`Report`).
	## The calls of `query!` (the guard, one query, `settle!`). The result is the request with the index of the answer. A request that is not `Read`: as it is (no call).
	report_query! : Fx, ResolveBase.Request, Loaded, List(ClosureRequest.Group) => Try(ResolveBase.Request, Fail)
	report_query! = |fx, request, loaded, groups| Ok(query!(fx, request, loaded, groups)?.request)

	## The oracle loop of the first search, and the second search of a held move (R-SP16, R-DI1). `state` has what the command read and probed before: the first call has `PickLoop.start`, the call after a dropped tuple has the facts, the count and the dropped tuples.
	search! : Fx, ResolveBase.Request, PickFlow.Ready, PickLoop.State => Try(Picked, Fail)
	search! = |fx, request, ready, state| {
		failed = |fail| with_close_versions(fail, { scoped: ready.scoped, asked: ready.asked, found: ready.found })
		searched = match PickLoop.run!(fx, request, ready.input, ready.setup, state) {
			Ok(c) => { looped: c, moves: [] }
			Err(stuck) => {
				if !PickMoves.second_wanted(stuck.fail, ready.scoped) return Err(failed(stuck.fail))
				# R-SP16, R-DI1: the second search of a held move. The index of the movable groups is read once, in the order of the slots. The facts of the first search stay (R-AL8).
				moved = second_index!(fx, request, ready, stuck.probed.second)?
				again = {
					..PickIndex.slots_of(ready.scoped, ready.stale.live, moved.found, ready.asked, ready.prepared.rows, ready.settings, ready.snapshot, PickAsk.unmanaged_of(ready.loaded, ready.asked, request.project.file ?? ""), request.project.file ?? ""),
					second: Bool.True,
				}
				held = held_nightly!(fx, request, ready, stuck)
				match PickLoop.run!(fx, moved.request, again, held.setup, { facts: stuck.facts, paths: stuck.paths, probed: { ..held.probed, second: moved.second, domain: wider(moved.request.index, held.probed.domain) } }) {
					Ok(c) => { looped: c, moves: PickMoves.moves_of({ scoped: ready.scoped, slots: again.slots, chosen: c.chosen, facts: c.facts }).concat(roc_moves(ready, { slots: again.slots, setup: held.setup }, c)) }
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
				exclude: ready.settings.exclude,
				snapshot: ready.snapshot,
				compiler: looped.nightly,
				checks: looped.probed.checks,
				used: looped.probed.used,
			}).concat(nightly_lags(ready, looped))
			_ => []
		}
		Ok({
			facts: { scoped: ready.scoped, wants: ready.stale.live, asked: ready.asked, prepared: ready.prepared, renames: ready.stale.renames, snapshot: ready.snapshot, known: looped.facts, paths: looped.paths, lags },
			chosen: looped.chosen,
			moves: searched.moves,
			nightly: looped.nightly,
			probed: looped.probed,
		})
	}
}

# Slice 206e3b (Design Q522, R-EP4, D8): the second search infers the facts again with the merged `epochs` of both answers: a domain that has more than the held compiler is read again (`PickLoop.wide!`, no new list read). A domain of the held compiler only has nothing to infer.
wider : ClosureIndex.Source, Try(List(Str), [NotRead]) -> Try(List(Str), [NotRead])
wider = |index, domain| match (index, domain) {
	(Answer(_), Ok(ids)) if ids.len() > 1 => Err(NotRead)
	_ => domain
}

# R-RP4, D3: `upgrade X` holds the nightly, and its second search can move it. The values are the installed compilers (`NightlyFlow.movable!`). The compiler list is read once for the command (`Probed.listed`, Q3).
held_nightly! : Fx, ResolveBase.Request, PickFlow.Ready, PickLoop.Stuck => { setup : PickLoop.Setup, probed : ResolveBase.Probed }
held_nightly! = |fx, request, ready, stuck| {
	moves = request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Held and ready.setup.held.is_ok()
	if !moves return { setup: ready.setup, probed: stuck.probed }
	releases = match stuck.probed.listed {
		Ok(list) => list
		Err(NotRead) => PickLoop.releases!(fx, request)
	}
	values = NightlyFlow.movable!(fx, request, { loaded: ready.loaded, settings: ready.settings }, { held: ready.setup.held ?? "", snapshot: ready.snapshot, releases })
	{ setup: { ..ready.setup, movable: Ok(values) }, probed: { ..stuck.probed, listed: Ok(releases) } }
}

# The chosen releases with the alias of their slot, in the order of the slots.
chosen_rows : List(Pick.Slot), List(Pick.Chosen) -> List({ alias : Str, url : Str, version : Str })
chosen_rows = |slots, chosen| slots.map2(chosen, |slot, c| { alias: slot.id, url: c.url, version: c.version })

# R-RP4, R-SP16, R-SP25: the held move of the nightly, after the moves of the packages. None when the nightly stays H.
roc_moves : PickFlow.Ready, { slots : List(Pick.Slot), setup : PickLoop.Setup }, PickLoop.Looped -> List(Consent.Move)
roc_moves = |ready, second, looped| match second.setup.movable {
	Err(None) => []
	Ok(_) => {
		held = ready.setup.held ?? ""
		why = Lags.blame({ releases: chosen_rows(second.slots, looped.chosen), compiler: held, checks: looped.probed.checks, inferred: looped.probed.inferred, used: looped.probed.used }) ?? "it does not fit the closure of the tuple"
		match NightlyPlan.roc_move({ held, nightly: looped.nightly, why, members: ready.loaded.members.map(|m| m.file) }) {
			Ok(move) => [move]
			Err(Same) => []
		}
	}
}

# R-UP2: the lag of the nightly, when it is free and the search did not take N.
nightly_lags : PickFlow.Ready, PickLoop.Looped -> List(Lags.Lag)
nightly_lags = |ready, looped| match Lags.nightly({ newest: ready.setup.newest, got: looped.nightly, releases: chosen_rows(ready.input.slots, looped.chosen), checks: looped.probed.checks, inferred: looped.probed.inferred, used: looped.probed.used }) {
	Ok(lag) => [lag]
	Err(NoLag) => []
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

# Slice 206b (R-AL2 step 2, R-RG4, R-AP16, R-AP19, R-DI1, R-DI14): the first closure query of a run with a registry (`registry` is `Read`), after the scope and before the index.
# The guard checks what the query carries (`IndexQuery.sources`: the groups, then the URLs with a hash), then one query (`ClosureIndex.query!`) with the groups of the free variables (`IndexQuery.groups`), the header entries and the window of the query (`Query.window`: `Held`, `Free` for the free nightly of `upgrade` (slice 206e2), or none: Q437).
# `--snapshot log:N` hides the answer above N, with the `hashes` of the request as the keep list (Q403). The result is the request with `index` = `Answer`. Any other `registry`: the request as it is (no call).
# Slice 206d (R-AP28, R-AP65, R-DI7, R-DI11, R-C9, Design Q425, Q460, Q462): `UnknownValues.settle!` after the first query (the header values as `urls`, `snapshot` true for `log:N`), then `hide_above`. The index is the answer of `settle!`.
# Slice 206e (Design Q469): with no group and no hash (no source) there is no guard and no query: the request as it is.
# Each value whose `anchor_note` is `Ok` (no release of its group in the answer of `settle!`) prints `<alias>: <note>` on stdout, in the order of `unknown`, and is an anchor (`anchors`: its URL).
# Slice 206e2: `groups` are given by the caller (`IndexQuery.groups` of the scope, or `IndexQuery.report_groups` for `tln outdated`).
query! : Fx, ResolveBase.Request, Loaded, List(ClosureRequest.Group) => Try({ request : ResolveBase.Request, anchors : List(Str), second : Try(PickFlow.Second, [None]) }, Fail)
query! = |fx, request, loaded, groups| match request.registry {
	Read(query) => {
		entries = loaded.members.join_map(|m| m.locked.rows.map(|r| r.value))
		sources = IndexQuery.sources({ groups, entries })
		# Slice 206e (Design Q469, R-DI1): a run with no group and no hash sends no query (no guard): the run is as `direct`.
		if sources.is_empty() {
			return Ok({ request, anchors: [], second: Err(None) })
		}
		PrivacyGuard.check!(fx, { net: request.net, roots: request.roots, sources, offline: request.offline, frozen: request.frozen })?
		facts = { groups, entries, window: query.window }
		(keep, compilers) = match ClosureRequest.request(facts) {
			Ok(wire) => (wire.hashes, wire.compilers)
			Err(_) => ([], Err(None))
		}
		first = ClosureIndex.query!(fx, { origin: query.origin, version: Help.version, facts })?
		log = match query.snapshot {
			Log(_) => Bool.True
			_ => Bool.False
		}
		settled = UnknownValues.settle!(fx, { origin: query.origin, version: Help.version, roots: request.roots, facts, first, urls: entries, snapshot: log })?
		rows = loaded.members.join_map(|m| m.locked.rows)
		var $anchors = []
		for v in settled.values {
			match UnknownValues.anchor_note({ end: v.end, url: v.url, releases: settled.answer.releases }) {
				Ok(note) => {
					alias = rows.find_first(|r| r.value == v.url).map_ok(|r| r.alias) ?? ""
					fx.out!("${alias}: ${note}\n")
					$anchors = $anchors.append(v.url)
				}
				Err(None) => {}
			}
		}
		(shown, user) = match query.snapshot {
			Log(n) => (LogSnapshot.hide_above(settled.answer, { n, keep }), Ok(n))
			_ => (settled.answer, Err(None))
		}
		second = { origin: query.origin, first: settled.answer, compilers, keep, user, anchors: $anchors }
		Ok({ request: { ..request, index: Answer({ origin: query.origin, answer: shown }) }, anchors: $anchors, second: Ok(second) })
	}
	_ => Ok({ request, anchors: [], second: Err(None) })
}

# Slice 206d (R-AP28, R-DI11): the group of an anchor URL acts as a group with no index: its form is in `missing_forms` of its name, so the pick holds the header value (R-C9).
anchored : List(Candidates), List(Str) -> List(Candidates)
anchored = |found, anchors| {
	idents = anchors.keep_oks(Ident.of_url)
	found.map(
		|c| {
			lower = c.name.with_ascii_lowercased()
			forms = idents
				.keep_if(|ident| (ident.name.map_ok(|n| n.with_ascii_lowercased() == lower) ?? Bool.False))
				.map(|ident| ident.group.form)
				.fold(c.missing_forms, |list, form| if list.contains(form) list else list.append(form))
			{ ..c, missing_forms: forms }
		},
	)
}

# Slice 206d (R-IX6, Design Q462): with the index `Offline`, each variable whose group has no kept copy (`missing`, or its form in `missing_forms`) prints `<alias>: fixed: offline, no cached index` (the alias of its first use), in the order of the variables.
offline_notes! : Fx, ResolveBase.Request, List(Vars.Scoped), List(Candidates) => {}
offline_notes! = |fx, request, scoped, found| match request.index {
	Offline(_) => {
		for s in scoped {
			match s.variable.name {
				Ok(name) => match found.find_first(|c| c.name == name) {
					Ok(c) if c.missing or c.missing_forms.contains(s.variable.group.form) => {
						alias = s.variable.uses.first().map_ok(|u| u.alias) ?? ""
						fx.out!("${alias}: fixed: offline, no cached index\n")
					}
					_ => {}
				}
				Err(NoName) => {}
			}
		}
	}
	_ => {}
}

# Slice 206d2 (R-SP24, Registry R-AP16, R-AP19, R-AL8, Design Q404, Q460): the index of the second search. With no registry answer: the release lists of the movable names that have no page yet (R-DI1), as before.
# With a registry answer: one second closure query (`LogSnapshot.second!`), once per command (Design Q466: `kept` is the second answer of an earlier search of the command, for example before a ladder drop, and is used again with no request) with the groups of the movable variables (`IndexQuery.second_groups`). The candidates of the movable names come from the second answer (after the hide).
# The second search reads its facts from the records of both answers (the second first), so the facts of a moved release need no archive read. The request that `finish!` gets keeps the first answer (R-DT5: the first `log_size`).
second_index! : Fx, ResolveBase.Request, PickFlow.Ready, Try(Wire.Answer, [NotRead]) => Try({ request : ResolveBase.Request, found : List(Candidates), second : Try(Wire.Answer, [NotRead]) }, Fail)
second_index! = |fx, request, ready, kept| match (ready.second, request.index) {
	(Ok(q), Answer(a)) => {
		answer = match kept {
			Ok(got) => got
			Err(NotRead) => LogSnapshot.second!(fx, { origin: q.origin, version: Help.version, first: q.first, compilers: q.compilers, groups: IndexQuery.second_groups(ready.scoped), keep: q.keep, user: q.user })?
		}
		names = ready.scoped
			.keep_if(|s| s.movable)
			.keep_oks(|s| s.variable.name.map_err(|_| None))
			.fold(ResolveBase.no_names, |list, name| if list.contains(name) list else list.append(name))
		more = anchored(PickIndex.index!(fx, { ..request, index: Answer({ origin: q.origin, answer }) }, names, ready.known)?, q.anchors)
		both = LogSnapshot.merged({ first: a.answer, second: answer })
		Ok({ request: { ..request, index: Answer({ origin: a.origin, answer: both }) }, found: joined(ready.found, more), second: Ok(answer) })
	}
	_ => {
		more = PickIndex.index!(fx, request, movable_names(ready.scoped, ready.found), ready.known)?
		Ok({ request, found: ready.found.concat(more), second: kept })
	}
}

# The candidates of the first index with those of the second answer: a name in both gets the releases of the second answer that its list does not have.
joined : List(Candidates), List(Candidates) -> List(Candidates)
joined = |found, more| {
	merged = found.map(
		|c| match more.find_first(|m| m.name == c.name) {
			Ok(m) => { ..c, list: c.list.concat(m.list.keep_if(|x| !c.list.any(|y| y.url == x.url))) }
			Err(_) => c
		},
	)
	merged.concat(more.keep_if(|m| !found.any(|c| c.name == m.name)))
}
