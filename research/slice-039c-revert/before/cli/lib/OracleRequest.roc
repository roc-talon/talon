import Ident
import Pick
import Release
import Text
import OracleBase
import OracleDomain
import resolve.Solver

## The solver request of the oracle step (slice 039s: split from `Oracle`): the slots, the facts, the conflicts and the compiler slot with the checks of D (R-AL3, R-EP7, R-SP1, R-WS2). Pure.
OracleRequest :: [].{

	# D6: the solver names a slot by its place.
	slot_name : U64 -> Str
	slot_name = |i| "s${i.to_str()}"

	# R-SP24: only the second search moves the `Movable` slots.
	movable_of : OracleBase.Input -> List(Str)
	movable_of = |input| if input.second input.slots.map_with_index(|slot, i| (slot, i)).keep_if(|(slot, _)| slot.hold == Movable).map(|(_, i)| slot_name(i)) else []

	group_key : { form : Str, series : Str } -> Str
	group_key = |g| "${g.form} ${g.series}"

	# The group of the header value, else of the first candidate in the byte order of the URLs (R-DT2).
	slot_group : Pick.Slot -> Str
	slot_group = |slot| {
		of_first = match slot.candidates.sort_with(|a, b| Text.compare(a.url, b.url)).first() {
			Ok(c) => group_key(c.ident.group)
			Err(_) => ""
		}
		match slot.current {
			Ok(url) => Ident.of_url(url).map_ok(|ident| group_key(ident.group)) ?? of_first
			Err(None) => of_first
		}
	}

	# R-SP1, R-C9: a closed slot has the one value `current`, with no candidate and no range.
	solver_slot : Pick.Slot, U64, Bool -> Solver.Slot
	solver_slot = |slot, i, second| {
		open = slot.hold == Free or (slot.hold == Movable and second)
		{
			name: slot_name(i),
			group: slot_group(slot),
			kind: if slot.is_platform Platform else Package,
			candidates: if open slot.candidates.map(|c| { id: c.url, version: c.ident.version, published_at: c.published_at, yanked: Bool.False }) else [],
			ranges: if open slot.ranges else [],
			current: match slot.current {
				Ok(url) => Ident.of_url(url).map_ok(|ident| { id: url, version: ident.version }).map_err(|_| None)
				Err(None) => Err(None)
			},
			named: if open slot.named else Err(None),
		}
	}

	# R-H4: a dep that is no release URL is dropped.
	solver_fact : { url : Str, release : Release } -> Solver.Fact
	solver_fact = |f| { id: f.url, kind: f.release.kind, pf: f.release.pf, deps: f.release.deps.keep_oks(|dep| Ident.of_url(dep).map_ok(|ident| { group: group_key(ident.group), version: ident.version })) }

	# The values of a solver slot with the group of each (the candidates and `current`).
	releases : Solver.Slot -> List((Str, Str))
	releases = |slot| {
		listed = slot.candidates.map(|c| c.id)
		ids = match slot.current {
			Ok(c) => if listed.contains(c.id) listed else listed.append(c.id)
			Err(_) => listed
		}
		ids.keep_oks(|id| Ident.of_url(id).map_ok(|ident| (id, group_key(ident.group))))
	}

	# D7, R-WS2: 2 slots have one value for a group. For each release of the first slot, the releases of the second slot in that group (other than it) cannot go with it.
	same_group : List(Solver.Slot) -> List(List(Solver.Term))
	same_group = |slots| {
		rows = slots.map(|slot| (slot.name, releases(slot)))
		rows.map_with_index(|(name, mine), i| (name, mine, rows.drop_first(i + 1))).join_map(
			|(name, mine, later)| later.join_map(
				|(other, theirs)| mine.join_map(
					|(a, g)| {
						clash = theirs.keep_if(|(b, h)| h == g and b != a).map(|(b, _)| b)
						if clash.is_empty() [] else [[{ name, ids: [a], sign: In }, { name: other, ids: clash, sign: In }]]
					},
				),
			),
		)
	}

	# R-AL3, R-EP7: the request. The compiler slot is the last one, so the decision order of the other slots does not change.
	request_of : OracleBase.Input, OracleBase.Compat, Bool, Try(List(Str), [Held]) -> Solver.Request
	request_of = |input, compat, assume, askable| {
		slots = input.slots.map_with_index(|slot, i| solver_slot(slot, i, input.second))
		base = {
			slots,
			rules: { now: input.now, min_age: input.min_age, snapshot: input.snapshot, strategy: input.strategy },
			facts: input.facts.map(solver_fact),
			conflicts: same_group(slots).concat(given(compat.conflicts)),
			compat: { domain: [], checks: [], used: [], probes: Off },
		}
		match compat.compiler {
			Ok(nightly) => {
				domain = OracleDomain.space(compat.domain, nightly)
				{ ..base, slots: slots.append(roc_slot(values_of(askable, nightly))), compat: { domain, checks: checks_of(input, compat, { domain, assumed: if assume Ok(nightly) else Err(None) }), used: used_of(input, compat), probes: compat.probes } }
			}
			Err(None) => base
		}
	}

	roc_name : Str
	roc_name = "roc"

	# The values of the compiler slot: the askable compilers, and H (always a value, the last). The solver keeps those that are in D, newest first.
	values_of : Try(List(Str), [Held]), Str -> List(Str)
	values_of = |askable, held| match askable {
		Ok(ids) => ids.keep_if(|id| id != held).append(held)
		Err(Held) => [held]
	}

	# The compiler variable: the values are compilers of D (the solver reads the `id` of a candidate only).
	roc_slot : List(Str) -> Solver.Slot
	roc_slot = |values| { name: roc_name, group: roc_name, kind: Compiler, candidates: values.map(|id| { id, version: id, published_at: 0, yanked: Bool.False }), ranges: [], current: Err(None), named: Err(None) }

	# R-AL5: a tuple that the ladder dropped is a conflict of the caller. A place that is no slot never applies.
	given : List(List({ at : U64, id : Str })) -> List(List(Solver.Term))
	given = |conflicts| conflicts.map(|terms| terms.map(|t| { name: slot_name(t.at), ids: [t.id], sign: In }))

	current_of : Pick.Slot -> List(Str)
	current_of = |slot| match slot.current {
		Ok(url) => [url]
		Err(None) => []
	}

	# R-UM1: the used modules of each release: the scan result, and `main.roc` (roc reads it for each package of the closure, `Units.judge`).
	used_of : OracleBase.Input, OracleBase.Compat -> List(Solver.Use)
	used_of = |input, compat| {
		urls = input.slots.join_map(|slot| slot.candidates.map(|c| c.url).concat(current_of(slot)))
		urls.map(|url| { id: url, modules: (compat.used.find_first(|u| u.id == url).map_ok(|u| u.modules) ?? []).append("main.roc") })
	}

	# R-EP7, R-EP8, R-EP14, D2: the checks of each release of the slots on each compiler of D (`OracleDomain.checks`).
	checks_of : OracleBase.Input, OracleBase.Compat, { domain : List(Str), assumed : Try(Str, [None]) } -> List(Solver.Check)
	checks_of = |input, compat, on| OracleDomain.checks({
		urls: input.slots.join_map(|slot| slot.candidates.map(|c| c.url).concat(current_of(slot))),
		current: input.slots.join_map(current_of),
		rows: compat.checks,
		inferred: compat.inferred,
		domain: on.domain,
		assumed: on.assumed,
	})
}
