import Domain
import Search
import SolverBase
import SolverProbe
import SolverWhy
import semver.Semver

## The solver step (Resolution 5 steps 3 to 5, R-AL3, R-AL5, R-EP7 to R-EP9, R-PK6; TESTING.md 2.2, part B): PubGrub over variables with a finite list of values, with conflict resolution, the learned incompatibilities of the probe facts,
## and the explanation of a failure. Pure: the same request gives the same answer (R-DT2). The state is data. The caller (slice 036) calls `step` again with more facts after a `Need`.
##
## | Part | Meaning | Rule |
## | --- | --- | --- |
## | Variable | One `Slot`, in the order of `priority` (the first slot has the strongest rank). Its values are `Domain.values` without the releases that a fact shows to have the wrong kind. The slot of the kind `Compiler` (`roc`) has the candidates whose id is in `compat.domain`, in the order of that list: `Highest` the newest first, `Lowest` the oldest first. Only `id` and `version` of such a candidate are read (`Chosen.version` is the `version` text). The solver never asks for a header fact of a compiler. | R-VA6, R-C1, R-C4, R-C6, R-C7, R-C9 |
## | Term | A set of values of one variable: `In` the ids, or `NotIn` the ids. | |
## | Incompatibility | Terms that cannot all be true. It comes from a fact, from a probe, from the caller (`conflicts`), or from conflict resolution. | R-C2, R-C3, R-AL5 |
## | Unit propagation | An incompatibility with one open term takes that term out of the possible values. All terms true is a conflict. | |
## | Decision | The first variable (in the order of the slots) with more than one possible value takes its best value. So the result is the best tuple by `priority`. | R-VA6 |
## | Conflict resolution | The conflict incompatibility and the cause of its latest satisfier give a new incompatibility, until the incompatibility is satisfied by one decision of the latest level only (or by one derived change that is alone at its level, or it has no term). The solver learns it and goes back to the level of the other satisfiers. A conflict that no decision caused (no term left) is the end: no tuple. A search that learns only the decisions that gave the conflict is wrong: it repeats the work for the variables that are no part of the conflict. | R-AL3 |
##
## Facts that the solver reads (header facts, R-AL8), one `Fact` for each release that the caller has read:
##
## | Fact | Incompatibility | Rule |
## | --- | --- | --- |
## | `kind` is not the kind of the slot (`App` is never right) | The release is not a value of the slot | R-C4 |
## | A dep names the `group` of another slot with a version | `not (release and slot_value < version)`: the other slot has a value at or above the version | R-C2 |
## | `pf` is a URL, and the request has exactly one platform slot | `not (release and platform_slot is not that URL)` | R-C3 |
##
## Probe facts (`compat.checks`, R-EP7). `compat.domain` is D (every compiler release, oldest first, R-EP11): adjacent releases are neighbors in this list. A check is the unit result of a release (`id`, a value of a slot that is not the compiler) on a compiler (`nightly`, a release of D).
## A check of another release or of a compiler that is not in D is not read. A pair has one check. A fail touches a module that the app uses when it has no module (a hard fail), or when one of its modules is in `used` for that release (R-UM1: with no `Use` for the release, no module is used).
##
## | Check | Interval of D | Incompatibility |
## | --- | --- | --- |
## | A `Fail` that touches (real or inferred) | The maximal run of adjacent releases of D, each with a `Fail` that touches, real or inferred. A hang, a crash, a pass, a fail that touches no used module and a release with no check end the run. | `not (release and roc in interval)` |
## | A real `Hang` or `Crash` (a fault, R-EP5) | The compiler alone | the same |
## | A `Pass`, a `Fail` that touches no used module | none | none |
##
## An inferred fail makes an incompatibility also when no real fail is in its run (R-EP9: with no probe the inferred facts decide). With `RealOnly` (see below) the inferred checks are not read at all. An inferred hang or crash is not read (a fault is always real).
##
## What the step returns. A is the best tuple with the real and the inferred facts, B the best tuple with the real facts only (an inferred check is no check). A pair is (release of a slot that is not the compiler, value of the compiler slot). A pair has a real fact when a real check exists for it, whatever its outcome.
##
## | `compat.probes` | Case | Result |
## | --- | --- | --- |
## | `Allowed` | B does not exist | `Fail`. Its explanation has real facts only (R-EP8) |
## | `Allowed` | A exists, a header fact of A is missing | `Need` with `Header` for each such release, each once, in the order of the slots |
## | `Allowed` | A exists with all header facts, a pair of A has no real fact | `Need` with a `Probe` for each such pair, each once, in the order of the slots |
## | `Allowed` | A exists with all facts, and B is A | `Done` |
## | `Allowed` | A exists with all facts, and B is not A (B is better: an inferred fail blocked it) | `Need` for B as for A (the second pass of R-EP8) |
## | `Allowed` | A does not exist | `Need` for B as for A |
## | `Off` (`--no-probe`, or the budget is spent, R-EP9) | A does not exist | `Fail`. Its explanation can have inferred facts, and names them |
## | `Off` | A exists, a header fact is missing | `Need` with `Header` (a header fact is not a probe) |
## | `Off` | A exists with all header facts | `Done`. A pair with no fact is taken as fit. Never a `Probe` |
##
## A release with no header fact is taken as fit (optimistic). A dep with a group that no slot has (a transitive group), and the closure of the tuple, are not read here: the caller checks them and gives a failure back as a conflict (R-AL9, slice 036).
##
## The explanation (`Why`) is a list of steps. A step is an incompatibility with its cause: a reason that exists (a leaf) or the resolution of 2 earlier steps. The last step has no term: it is the proof that no tuple exists. R-DT2: the explanation is the same
## (also the order of the steps) when the lists of the request are in another order. So the incompatibilities that the search reads are in an order that does not depend on the order of the lists.
Solver :: [].{

	## The types of the API are in `SolverBase` (slice 036b3, to keep this module short). These names are the same types.

	Slot : SolverBase.Slot

	Dep : SolverBase.Dep

	Fact : SolverBase.Fact

	Term : SolverBase.Term

	Check : SolverBase.Check

	Use : SolverBase.Use

	Compat : SolverBase.Compat

	Request : SolverBase.Request

	Ask : SolverBase.Ask

	Chosen : SolverBase.Chosen

	Cause : SolverBase.Cause

	Step : SolverBase.Step

	Why : SolverBase.Why

	## The step of the second search of a held move (slice 036, R-SP24, R-PH10): `step` with a decision order for the slots in `movable` (the names of slots; a name that is no slot is ignored, an empty list gives `step`).
	## A movable slot is a held variable that the second search may move (R-SP23). The caller gives it `current` (the header value) and its candidates. The rules, in addition to those of `step`:
	##
	## | # | Rule | Source |
	## | --- | --- | --- |
	## | 1 | The order of the variables: the movable slots first, in the order of the slots (`priority`), then the other slots in the order of the slots. So a movable slot keeps its value when a tuple exists with it and the earlier movable slots. | R-SP24, R-VA6 |
	## | 2 | The order of the values of a movable slot: `current` first (when it is a value), then the nearest values. `Highest`: the higher versions from low to high, then the lower versions from high to low. `Lowest`: the lower versions from high to low, then the higher versions from low to high. A tie (one version, 2 ids) is in the byte order of the ids. The strategy does not change the order of any other slot. | R-SP24 |
	## | 3 | The values of a movable slot are those of `Domain.values` (R-C1, R-C6, R-C7, R-C9) less the releases that a fact shows to have the wrong kind: only the order differs. | R-SP23 |
	## | 4 | `Done` and `Need` are in the order of `req.slots` (each ask by the first slot that has the release, the order of the asks inside one slot stays). `Fail` has the steps of the search: its terms are in the order of the search, and the ids of a movable slot in the order of rule 2. | R-DT2 |
	##
	## Slice 039c (R-RP4, R-SP23): a `Compiler` slot is movable when its name is in `movable` and it has a `current` (the held compiler H): `tln upgrade X` holds the nightly, and a held move of `upgrade` can include it. Outside `upgrade` the caller never names it.
	## Rule 1 holds for it: it is decided after the movable packages (it is the last slot), before the free packages. Rule 2 for a compiler reads the order of D (`compat.domain`, oldest first), not a version: `current` first, then, with `Highest`, the compilers after it in D from old to new, then the compilers before it from new to old.
	## With `Lowest` the compilers before it from new to old, then the compilers after it from old to new. A `current` that is not a value gives each value as a lower one, newest first. Without a `current` (`Err(None)`) the slot is not movable: its order is the order of D (the newest first with `Highest`).
	## So the movable compiler stays H when a tuple exists with H, and else moves the smallest step (R-SP24).
	step_moves : Solver.Request, List(Str) -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]
	step_moves = |req, movable| {
		moved = |slot| slot.kind != Compiler and movable.contains(slot.name)
		places_of = req.slots.map_with_index(|slot, i| (slot, i))
		order = places_of.keep_if(|(slot, _)| moved(slot)).concat(places_of.keep_if(|(slot, _)| !moved(slot))).map(|(_, i)| i)
		any_moved = req.slots.any(moved)
		back = |items| if any_moved in_slot_order(order, items) else items
		facts = Dict.from_list(req.facts.map(|f| (f.id, f)))
		vars = order.keep_oks(|i| req.slots.get(i)).map(|slot| if moved(slot) moved_var(req, facts, slot) else var_of(req, facts, slot))
		sizes = vars.map(|v| v.vals.len())
		pre = novalue_incs(vars).concat(fact_incs(sizes, vars, facts))
		post = conflict_incs(sizes, vars, req.conflicts)
		table = |mode| pre.concat(SolverProbe.probe_incs(sizes, vars, req.compat, mode)).concat(post)
		ask = |asks| Need(if any_moved asks_in_slot_order(order, vars, asks) else asks)
		finish = |t| match asks_of(vars, facts, req.compat, t) {
			[] => Done(back(chosen(vars, t)))
			asks => ask(asks)
		}
		match req.compat.probes {
			Off => {
				incs = table(All)
				match solve(vars, incs) {
					NoTuple(f) => Fail(SolverWhy.why_of(vars, incs, f.rows, f.last))
					Found(t) => finish(t)
				}
			}
			Allowed => {
				incs = table(Real)
				match solve(vars, incs) {
					NoTuple(f) => Fail(SolverWhy.why_of(vars, incs, f.rows, f.last))
					Found(tb) => {
						a = if req.compat.checks.any(|c| c.source == Inferred) solve(vars, table(All)) else Found(tb)
						match a {
							Found(ta) => match asks_of(vars, facts, req.compat, ta) {
								[] => if ta == tb Done(back(chosen(vars, tb))) else finish(tb)
								asks => ask(asks)
							}
							NoTuple(_) => finish(tb)
						}
					}
				}
			}
		}
	}

	## The step. `Need`: ask for these facts, and call again. `Done`: the best tuple, one `Chosen` for each slot, in the order of the slots. `Fail`: no tuple. It is `step_moves(req, [])`.
	step : Solver.Request -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]
	step = |req| step_moves(req, [])
}

## Types of the search. They are in `SolverBase`.
Val : SolverBase.Val

Var : SolverBase.Var

Inc : SolverBase.Inc

Env : SolverBase.Env

# R-C1, R-C4, R-C6, R-C7, R-C9: the domain, without the releases that a fact shows to have the wrong kind. The compiler slot has the candidates of D, in the order of D (D1).
var_of : Solver.Request, Dict(Str, Solver.Fact), Solver.Slot -> Var
var_of = |req, facts, slot| match slot.kind {
	Compiler => {
		ordered = if req.rules.strategy == Highest req.compat.domain.rev() else req.compat.domain
		{ name: slot.name, group: slot.group, kind: slot.kind, vals: ordered.keep_oks(|id| slot.candidates.find_first(|c| c.id == id).map_ok(|c| { c, ver: Err(NoVer) })) }
	}
	_ => {
		values = Domain.values({ candidates: slot.candidates, ranges: slot.ranges, current: slot.current, named: slot.named, rules: req.rules })
		fits = values.keep_if(|c| kind_fits(slot.kind, facts, c.id))
		{ name: slot.name, group: slot.group, kind: slot.kind, vals: fits.keep_oks(|c| Semver.parse(c.version).map_ok(|v| { c, ver: Ok(v) })) }
	}
}

# R-SP24: the values of a movable slot. `current` first, then the nearest: `Highest` the higher versions from low to high and then the lower ones from high to low, `Lowest` the lower ones and then the higher ones.
# A version equal to `current` (an other id) counts as lower. Without a `current` that parses, each value is lower.
moved_var : Solver.Request, Dict(Str, Solver.Fact), Solver.Slot -> Var
moved_var = |req, facts, slot| {
	at = |strategy| var_of({ ..req, rules: { ..req.rules, strategy } }, facts, slot)
	asc = at(Lowest)
	desc = at(Highest)
	cur = match slot.current {
		Ok(c) => c.id
		Err(_) => ""
	}
	old = match slot.current {
		Ok(c) => Semver.parse(c.version).map_err(|_| NoVer)
		Err(_) => Err(NoVer)
	}
	newer = |x| match (x.ver, old) {
		(Ok(a), Ok(b)) => a.order_relative_to(b) == After
		_ => Bool.False
	}
	own = asc.vals.keep_if(|x| x.c.id == cur)
	higher = asc.vals.keep_if(|x| x.c.id != cur and newer(x))
	lower = desc.vals.keep_if(|x| x.c.id != cur and !newer(x))
	{ ..asc, vals: if req.rules.strategy == Highest own.concat(higher).concat(lower) else own.concat(lower).concat(higher) }
}

# R-DT2: puts the items of the search (one for each variable, in the order of the search) back in the order of the slots. `order` has the place of each variable in `req.slots`.
in_slot_order : List(U64), List(a) -> List(a)
in_slot_order = |order, items| order.map2(items, |i, x| (i, x)).sort_with(|p, q| p.0.order_relative_to(q.0)).map(|p| p.1)

# R-SP24, rule 4: an ask belongs to the first slot (in the order of the slots) that has the release as a value. The asks of one slot keep their order.
asks_in_slot_order : List(U64), List(Var), List(Solver.Ask) -> List(Solver.Ask)
asks_in_slot_order = |order, vars, asks| {
	owner = |ask| {
		id = match ask {
			Header(x) => x
			Probe(p) => p.id
		}
		order.map2(vars, |i, v| (i, v)).keep_if(|(_, v)| v.vals.any(|x| x.c.id == id)).map(|(i, _)| i).fold(order.len(), |lowest, i| if i < lowest i else lowest)
	}
	keyed = asks.map_with_index(|ask, k| (owner(ask), k, ask))
	keyed.sort_with(
		|p, q| match p.0.order_relative_to(q.0) {
			Same => p.1.order_relative_to(q.1)
			other => other
		},
	).map(|p| p.2)
}

# R-C4: no fact means fit.
kind_fits : [Package, Platform, Compiler], Dict(Str, Solver.Fact), Str -> Bool
kind_fits = |kind, facts, id| match facts.get(id) {
	Ok(f) => match (kind, f.kind) {
		(Package, Package) => Bool.True
		(Platform, Platform) => Bool.True
		_ => Bool.False
	}
	Err(_) => Bool.True
}

places : Var, (Val -> Bool) -> List(U64)
places = |vr, test| vr.vals.map_with_index(|x, p| (p, x)).keep_if(|(_, x)| test(x)).map(|(p, _)| p)

# R-C1, R-C4, R-C6, R-C7, R-C9: a slot with no value is an incompatibility with no term.
novalue_incs : List(Var) -> List(Inc)
novalue_incs = |vars| vars.keep_if(|v| v.vals.is_empty()).map(|v| { lits: [], cause: NoValue(v.name) })

# R-C2 and R-C3: the incompatibilities of each release of each variable, in the order of the slots and values (D11).
fact_incs : List(U64), List(Var), Dict(Str, Solver.Fact) -> List(Inc)
fact_incs = |sizes, vars, facts| {
	plats = vars.map_with_index(|vr, i| (vr, i)).keep_if(|(vr, _)| vr.kind == Platform).map(|(_, i)| i)
	vars.map_with_index(
		|vr, i| vr.vals.map_with_index(
			|x, p| match facts.get(x.c.id) {
				Ok(f) => dep_incs(sizes, vars, i, p, x.c.id, f).concat(pf_incs(sizes, vars, plats, i, p, x.c.id, f))
				Err(_) => []
			},
		).join(),
	).join()
}

# R-C2: the release (place `p` of variable `i`) needs the group of another variable at the version or above.
dep_incs : List(U64), List(Var), U64, U64, Str, Solver.Fact -> List(Inc)
dep_incs = |sizes, vars, i, p, id, f| f.deps.join_map(
	|dep| match Semver.parse(dep.version) {
		Ok(need) => vars.map_with_index(|other, k| (k, other)).keep_if(|(k, other)| k != i and other.group == dep.group).join_map(
			|(k, other)| SolverBase.mk(sizes, [{ v: i, set: [p] }, { v: k, set: places(other, |x| is_below(x, need)) }], Dep({ id, group: dep.group, version: dep.version })),
		)
		Err(_) => []
	},
)

is_below : Val, Semver -> Bool
is_below = |x, need| match x.ver {
	Ok(v) => v.order_relative_to(need) == Before
	Err(_) => Bool.False
}

# R-C3: with exactly one platform variable, the platform of a release is that variable's value. The platform variable's own release is not checked (034 D8).
pf_incs : List(U64), List(Var), List(U64), U64, U64, Str, Solver.Fact -> List(Inc)
pf_incs = |sizes, vars, plats, i, p, id, f| match (f.pf, plats) {
	(Ok(url), [pl]) => match vars.get(pl) {
		Ok(pv) => if pl == i [] else SolverBase.mk(sizes, [{ v: i, set: [p] }, { v: pl, set: places(pv, |x| x.c.id != url) }], Pf({ id, pf: url }))
		Err(_) => []
	}
	_ => []
}

# The conflicts of the caller (R-AL5), normalized, then sorted by their terms (D11). A conflict never applies when a name is no slot.
conflict_incs : List(U64), List(Var), List(List(Solver.Term)) -> List(Inc)
conflict_incs = |sizes, vars, conflicts| conflicts.keep_oks(
	|terms| match terms.map_try(|t| lit_of(vars, t)) {
		Ok(lits) => SolverBase.norm(sizes, lits).map_ok(|ls| { lits: ls, cause: Given })
		Err(_) => Err(Never)
	},
).sort_with(|a, b| cmp_lits(a.lits, b.lits))

lit_of : List(Var), Solver.Term -> Try(Search.Lit, [Unknown])
lit_of = |vars, t| match vars.find_first_index(|x| x.name == t.name) {
	Ok(v) => match vars.get(v) {
		Ok(vr) => Ok({ v, set: places(vr, |x| t.ids.contains(x.c.id) == (t.sign == In)) })
		Err(_) => Err(Unknown)
	}
	Err(_) => Err(Unknown)
}

cmp_nums : List(U64), List(U64) -> [Before, Same, After]
cmp_nums = |a, b| match (a, b) {
	([x, .. as ra], [y, .. as rb]) => match x.order_relative_to(y) {
		Same => cmp_nums(ra, rb)
		other => other
	}
	([], []) => Same
	([], _) => Before
	(_, []) => After
}

cmp_lits : List(Search.Lit), List(Search.Lit) -> [Before, Same, After]
cmp_lits = |a, b| match (a, b) {
	([x, .. as ra], [y, .. as rb]) => match x.v.order_relative_to(y.v) {
		Same => match cmp_nums(x.set, y.set) {
			Same => cmp_lits(ra, rb)
			other => other
		}
		other => other
	}
	([], []) => Same
	([], _) => Before
	(_, []) => After
}

solve : List(Var), List(Inc) -> Search.Outcome
solve = |vars, incs| Search.run(incs.map(|i| { lits: i.lits, from: Base }), vars.map(|v| v.vals.len()))

picks : List(Var), List(U64) -> List((Var, Val))
picks = |vars, at| vars.map2(at, |v, p| v.vals.get(p).map_ok(|x| (v, x))).keep_oks(|t| t)

chosen : List(Var), List(U64) -> List(Solver.Chosen)
chosen = |vars, at| picks(vars, at).map(|(vr, x)| { name: vr.name, id: x.c.id, version: x.c.version })

# R-AL8, R-AL4: what the tuple lacks. The header facts first, each once, in the order of the slots (never for the compiler). Else, with probes allowed, the pairs (release, compiler) with no real check.
asks_of : List(Var), Dict(Str, Solver.Fact), Solver.Compat, List(U64) -> List(Solver.Ask)
asks_of = |vars, facts, compat, at| {
	picked = picks(vars, at)
	rels = picked.keep_if(|(vr, _)| vr.kind != Compiler).map(|(_, x)| x.c.id)
	heads = SolverBase.dedupe(rels.keep_if(|id| !facts.contains(id)))
	if heads.is_empty() {
		match picked.find_first(|(vr, _)| vr.kind == Compiler) {
			Ok((_, roc)) => if compat.probes == Allowed SolverBase.dedupe(rels.keep_if(|id| !compat.checks.any(|c| c.id == id and c.nightly == roc.c.id and c.source == Real))).map(|id| Probe({ id, nightly: roc.c.id })) else []
			Err(_) => []
		}
	} else {
		heads.map(|id| Header(id))
	}
}
