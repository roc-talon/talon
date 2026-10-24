import Closure
import Db
import Fail
import Ident
import Pick
import Release
import Text
import resolve.Solver

## The pure step of the oracle loop (slice 036, Resolution 5 steps 3 and 5, R-AL3, R-SP24, R-PH10, R-PH13; TESTING.md 2.2 part B for the command). It is `Pick.step` over the solver step of the package `resolve` (`Solver.step_moves`):
## the same input, the same output, the same texts. `PickLoop.run!` calls it in place of `Pick.step`. Pure: the same input gives the same output (R-DT2).
##
## The input is the one of `Pick.step` (its doc has the fields). The output is `Need` (the ids of the nodes that have no fact: a release URL or the file of a path node), `Done` (one `Pick.Chosen` for each slot, in the order of the slots) or `Fail` (kind `NoTuple`).
##
## | Part | What the step does | Rule |
## | --- | --- | --- |
## | Slots | A slot is a solver slot with the name `s<index>` (the alias `id` of a slot is no key: one alias can name 2 groups in 2 members, R-WS8). Its group is the group of the releases (`Ident.group` of the header value, else of the first candidate). A `Free` slot, and a `Movable` slot with `second`, has its candidates and ranges. A `Held` slot, and a `Movable` slot with no `second`, has no candidate and no range: its one value is `current` (R-SP1, R-C9). `current` is `Err(None)` for a want (and for a value that is no release URL). | R-SP1, R-C1, R-C9 |
## | Facts | A fact is a `Solver.Fact` of a release URL: its kind, its platform, and its deps as (group, version) (a dep that is no release URL is dropped, R-H4). | R-C2, R-C3, R-C4, R-AL8 |
## | Rules | `now`, `min_age`, `snapshot` and `strategy` are the rules of the request (R-C7, R-DT4, R-VA6). The request has no compiler slot, no check and no used module, and `probes` is `Off`: the probe facts are slice 036b. | R-C7 |
## | Same group | Two slots of one group have one value (R-WS2, R-WS3): for each pair of slots with one group, a conflict of the caller says that the value of the second is the value of the first. | R-WS2, R-WS3 |
## | Search | `second: false`: `Solver.step`. `second: true`: `Solver.step_moves` with the names of the `Movable` slots: they are first in the search, in the order of the slots, and try `current` first, then the nearest values (R-SP24). `Done`, `Need` and `Fail` are in the order of the slots. | R-SP24, R-PH10 |
## | `Need` | The header facts that the best tuple lacks (`Solver.Need`, the releases of the slots), in the order of the slots, no repeat. After `Done` the closure of the tuple (below) can ask for more nodes, and then the step gives `Need` of those. | R-AL8, R-AL9 |
## | Closure | After `Done` of the solver, the step walks the closure of the tuple as `Pick.step` does (R-AL9: `Closure.step` for each member, the rules 1 to 4 of the table of `Pick.step`). A problem of the closure is a conflict of the caller: the releases of that tuple cannot all be chosen. The step asks the solver again, so the next tuple is the best one that has no problem. A tuple with nodes that have no fact gives `Need` of those nodes (an unknown node is taken as fit). | R-AL9, 034 Q3 |
## | `Fail` | The solver found no tuple. The text is the text of `Pick.step` for the same case (the doc of `Pick.step`, the table of `Fail`): a slot with no value gives the first message of that table, else `no tuple works: the releases of <id>, <id> do not fit together (R-C2, R-C3)`. | R-PH10, R-PH13 |
##
## Equal to `Pick.step`: the rows of `tests/unit/pick.roc`, `pickclosure.roc` and `pickmoves.roc` run on this step (slice 036: their `step` helper calls `Oracle.step`) and give the values that they gave before: the result, the failure texts and the `Need` lists.
Oracle :: [].{

	## The input of `step` (the one of `Pick.step`).
	Input : {
		slots : List(Pick.Slot),
		strategy : [Highest, Lowest],
		now : U64,
		min_age : U64,
		snapshot : Try(U64, [None]),
		facts : List({ url : Str, release : Release }),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		paths : List(Closure.Node),
		second : Bool,
	}

	## Slice 036b (R-AL4, R-EP8, R-EP9, R-LF2): what the step knows about probes. STUB: the step ignores it.
	Compat : { compiler : Try(Str, [None]), checks : List(Db.Fact), looked : List(Db.Key), probes : [Allowed, Off], conflicts : List(List({ at : U64, id : Str })) }

	## A pair that the step wants facts for. STUB: never given.
	Pair : { id : Str, nightly : Str, is_platform : Bool }

	## What `step_probed` gives.
	Verdict : [Need(List(Str)), Pairs(List(Oracle.Pair)), Done(List(Pick.Chosen)), Fail(Fail)]

	step : Oracle.Input -> [Need(List(Str)), Done(List(Pick.Chosen)), Fail(Fail)]
	step = |input| match Pick.empty_domain(input) {
		Ok(fail) => Fail(fail)
		Err(NoFailure) => search(input, request_of(input), movable_of(input), [])
	}

	## STUB (slice 036b): the old step, no probe, no fact. The code agent writes the real step.
	step_probed : Oracle.Input, Oracle.Compat -> Oracle.Verdict
	step_probed = |input, _compat| match Oracle.step(input) {
		Need(ids) => Need(ids)
		Done(chosen) => Done(chosen)
		Fail(fail) => Fail(fail)
	}
}

Step : {
	slots : List(Pick.Slot),
	strategy : [Highest, Lowest],
	now : U64,
	min_age : U64,
	snapshot : Try(U64, [None]),
	facts : List({ url : Str, release : Release }),
	unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
	paths : List(Closure.Node),
	second : Bool,
}

Searched : [Need(List(Str)), Done(List(Pick.Chosen)), Fail(Fail)]

# D6: the solver names a slot by its place.
slot_name : U64 -> Str
slot_name = |i| "s${i.to_str()}"

# R-SP24: only the second search moves the `Movable` slots.
movable_of : Step -> List(Str)
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

# R-AL3: the facts of the request are the header facts, `probes` is `Off` (the probes are slice 036b).
request_of : Step -> Solver.Request
request_of = |input| {
	slots = input.slots.map_with_index(|slot, i| solver_slot(slot, i, input.second))
	{
		slots,
		rules: { now: input.now, min_age: input.min_age, snapshot: input.snapshot, strategy: input.strategy },
		facts: input.facts.map(solver_fact),
		conflicts: same_group(slots),
		compat: { domain: [], checks: [], used: [], probes: Off },
	}
}

# D3: a release with no fact has an empty fact of the kind of its slot, so the tuple is the optimistic one and the closure walk can ask for the nodes below it.
optimistic : Solver.Request, Solver.Ask -> Try(Solver.Fact, [NoHeader])
optimistic = |req, ask| match ask {
	Header(id) => {
		holds = |slot| slot.candidates.any(|c| c.id == id) or (
			match slot.current {
				Ok(c) => c.id == id
				Err(_) => Bool.False
			}
		)
		kind = match req.slots.find_first(holds) {
			Ok(slot) => if slot.kind == Platform Platform else Package
			Err(_) => Package
		}
		Ok({ id, kind, pf: Err(None), deps: [] })
	}
	Probe(_) => Err(NoHeader)
}

# The best tuple of the solver, with the optimistic facts for the releases that it asks for.
first_tuple : Solver.Request, List(Str) -> Try(List(Solver.Chosen), [NoFit])
first_tuple = |req, movable| match Solver.step_moves(req, movable) {
	Done(chosen) => Ok(chosen)
	Fail(_) => Err(NoFit)
	Need(asks) => first_tuple({ ..req, facts: req.facts.concat(asks.keep_oks(|ask| optimistic(req, ask))) }, movable)
}

# R-AL9: a problem of the closure is a conflict of the whole tuple (034 Q3), and the solver gives the next tuple. `tried` are those conflicts.
search : Step, Solver.Request, List(Str), List(List(Solver.Term)) -> Searched
search = |input, req, movable, tried| match first_tuple({ ..req, conflicts: req.conflicts.concat(tried) }, movable) {
	Err(NoFit) => Fail(Fail.new(NoTuple, "no tuple works: the releases of ${Str.join_with(input.slots.map(|slot| slot.id), ", ")} do not fit together (R-C2, R-C3)"))
	Ok(chosen) => {
		verdict = Pick.closure_verdict({
			members: if input.unmanaged.is_empty() [{ file: "", entries: [] }] else input.unmanaged,
			nodes: input.facts.map(|f| Pick.node_of(f)).concat(input.paths),
			picked: input.slots.map2(chosen, |slot, c| { files: slot.files, is_platform: slot.is_platform, url: c.id }),
		})
		match verdict {
			Problem => search(input, req, movable, tried.append(chosen.map(|c| { name: c.name, ids: [c.id], sign: In })))
			Fine([]) => Done(input.slots.map2(chosen, |slot, c| chosen_of(input, slot, c)))
			Fine(ids) => Need(ids)
		}
	}
}

chosen_of : Step, Pick.Slot, Solver.Chosen -> Pick.Chosen
chosen_of = |input, slot, c| Pick.chosen_for({ slot, url: c.id, version: c.version, published_at: slot.candidates.find_first(|x| x.url == c.id).map_ok(|x| x.published_at) ?? 0, now: input.now, min_age: input.min_age })
