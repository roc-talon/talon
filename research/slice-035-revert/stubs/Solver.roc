import Domain
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

	## One variable. `name` is its name (the alias of its first use). `group` is the group of its releases (the key of a dep). `kind` is the kind that a release must have (R-C4), or `Compiler` for `roc`: then only `id` of each candidate is read. The rest is `Domain.Query` without the rules.
	Slot : { name : Str, group : Str, kind : [Package, Platform, Compiler], candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]) }

	## A dep of a release: the group and the lowest version that the release needs (`X.Y.Z`).
	Dep : { group : Str, version : Str }

	## The header facts of one release: its kind (the first keyword of its header), its platform (`pf`, the URL, `Err(None)` for none), and its deps.
	Fact : { id : Str, kind : [Package, Platform, App], pf : Try(Str, [None]), deps : List(Solver.Dep) }

	## A term of a conflict: the value of the variable `name` is `In` the ids, or `NotIn` the ids. An id that is not a value of the variable is not in either set.
	Term : { name : Str, ids : List(Str), sign : [In, NotIn] }

	## One unit result (R-EP12, a row of `Db.Fact` with the target `any`, or an inferred fact of `Epochs.Inferred`): the release `id` on the compiler `nightly`. `modules` are the failing modules of a `Fail`. `source` marks an inferred fact (R-EP14). A pair has one check.
	Check : { id : Str, nightly : Str, outcome : [Pass, Fail, Hang, Crash], modules : List(Str), source : [Real, Inferred] }

	## The modules of the release `id` that the app uses (R-UM1).
	Use : { id : Str, modules : List(Str) }

	## The probe knowledge: D, the checks, the used modules, and if the step may ask for probes (`Off`: `--no-probe`, or the budget is spent, R-EP9).
	Compat : { domain : List(Str), checks : List(Solver.Check), used : List(Solver.Use), probes : [Allowed, Off] }

	## `slots` are in the order of `priority`. `conflicts` are incompatibilities of the caller: the terms of one conflict cannot all be true. A conflict with a `name` that is no slot never applies.
	Request : { slots : List(Solver.Slot), rules : Domain.Rules, facts : List(Solver.Fact), conflicts : List(List(Solver.Term)), compat : Solver.Compat }

	## What the solver needs: the header facts of a release (R-AL8), or the unit result of a release on a compiler (R-AL4).
	Ask : [Header(Str), Probe({ id : Str, nightly : Str })]

	## One chosen value.
	Chosen : { name : Str, id : Str, version : Str }

	## Why an incompatibility holds. The reasons that exist (leaves): `Probe`, a learned interval (R-EP7) with `kind` (`Fail` or `Fault`), the release `id`, the first and the last compiler of the interval (`from` and `to`, ids of D), the failing modules that the app uses
	## (in the order of the first compiler that has them, then the order of the check, no repeat), and the compilers of the interval whose fail is inferred (in the order of D, R-EP9: always empty with `Allowed`); `Dep` (R-C2); `Pf` (R-C3, `pf` is the URL that the release names);
	## `Given` (a conflict of the caller: no number, so the explanation does not depend on the order of `conflicts`, R-DT2); `NoValue` (the slot with this name has no value: R-C1, R-C4, R-C6, R-C7, R-C9, or a compiler slot with no candidate in D). `Derived(a, b)`: the resolution of the steps `a` and `b` (places in `Why.steps`, both before this step).
	Cause : [Probe({ id : Str, kind : [Fail, Fault], from : Str, to : Str, modules : List(Str), inferred : List(Str) }), Dep({ id : Str, group : Str, version : Str }), Pf({ id : Str, pf : Str }), Given, NoValue(Str), Derived(U64, U64)]

	## One step of the explanation: the terms cannot all be true (an empty list: never true), and the cause. The terms are `In` terms, in the order of the slots, one for each slot: the ids are the values of the slot that the term holds, in the order of the values of the slot (the best first: with `Highest` the newest compiler
	## and the highest version first). A term that holds all values of its slot is left out. A `NoValue` step has no term.
	Step : { terms : List(Solver.Term), cause : Solver.Cause }

	## The explanation of a `Fail`: the steps that lead to the empty incompatibility, in a valid order (a `Derived` names earlier steps). The last step has no term. Each step follows from its leaves (the steps that are no `Derived`, reached through `Derived`): in each tuple of values that
	## makes all terms of the step true, all terms of one leaf are true.
	Why : { steps : List(Solver.Step) }

	## The step. `Need`: ask for these facts, and call again. `Done`: the best tuple, one `Chosen` for each slot, in the order of the slots. `Fail`: no tuple.
	step : Solver.Request -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]
	step = |req| {
		facts = Dict.from_list(req.facts.map(|f| (f.id, f)))
		vars = req.slots.map(|slot| var_of(req.rules, facts, slot))
		incs = fact_incs(vars, facts).concat(conflict_incs(vars, req.conflicts))
		match search(incs, vars.map(|v| v.vals.map_with_index(|_, p| p)), []) {
			NoTuple(_) => Fail({ steps: [] })
			Found(places) => {
				picked = vars.map2(places, |v, p| v.vals.get(p).map_ok(|x| (v.name, x.c))).keep_oks(|t| t)
				missing = picked.keep_if(|(_, c)| !facts.contains(c.id)).map(|(_, c)| c.id).fold([], |acc, id| if acc.contains(id) acc else acc.append(id))
				if missing.is_empty() {
					Done(picked.map(|(name, c)| { name, id: c.id, version: c.version }))
				} else {
					Need(missing.map(|id| Header(id)))
				}
			}
		}
	}
}

# A value of a variable: a release of the domain and its parsed version.
Val : { c : Domain.Candidate, ver : Semver }

# A variable. Its values are in the order of the domain, and a value is its place in `vals`.
Var : { name : Str, group : Str, kind : [Package, Platform, Compiler], vals : List(Val) }

# A term on places: the variable (its index) has one of these values.
Lit : { v : U64, set : List(U64) }

# An incompatibility: the terms cannot all be true.
Inc : List(Lit)

# The possible places of each variable.
State : List(List(U64))

Choice : { v : U64, at : U64 }

# R-C1, R-C4, R-C6, R-C7, R-C9: the domain, without the releases that a fact shows to have the wrong kind.
var_of : Domain.Rules, Dict(Str, Solver.Fact), Solver.Slot -> Var
var_of = |rules, facts, slot| {
	values = Domain.values({ candidates: slot.candidates, ranges: slot.ranges, current: slot.current, named: slot.named, rules })
	fits = values.keep_if(|c| kind_fits(slot.kind, facts, c.id))
	{ name: slot.name, group: slot.group, kind: slot.kind, vals: fits.keep_oks(|c| Semver.parse(c.version).map_ok(|ver| { c, ver })) }
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

# R-C2 and R-C3: one incompatibility for each dep and platform of each release of each variable.
fact_incs : List(Var), Dict(Str, Solver.Fact) -> List(Inc)
fact_incs = |vars, facts| {
	plats = vars.map_with_index(|vr, i| (vr, i)).keep_if(|(vr, _)| vr.kind == Platform).map(|(_, i)| i)
	vars.map_with_index(
		|vr, i| vr.vals.map_with_index(
			|x, p| match facts.get(x.c.id) {
				Ok(f) => dep_incs(vars, i, p, f).concat(pf_incs(vars, plats, i, p, f))
				Err(_) => []
			},
		).join(),
	).join()
}

# R-C2: the release (place `p` of variable `i`) needs the group of another variable at the version or above.
dep_incs : List(Var), U64, U64, Solver.Fact -> List(Inc)
dep_incs = |vars, i, p, f| f.deps.join_map(
	|dep| match Semver.parse(dep.version) {
		Ok(need) => vars.map_with_index(|other, k| (k, other)).keep_if(|(k, other)| k != i and other.group == dep.group).keep_oks(
			|(k, other)| {
				below = places(other, |x| x.ver.order_relative_to(need) == Before)
				if below.is_empty() Err(NoLimit) else Ok([{ v: i, set: [p] }, { v: k, set: below }])
			},
		)
		Err(_) => []
	},
)

# R-C3: with exactly one platform variable, the platform of a release is that variable's value. The platform variable's own release is not checked (D8).
pf_incs : List(Var), List(U64), U64, U64, Solver.Fact -> List(Inc)
pf_incs = |vars, plats, i, p, f| match (f.pf, plats) {
	(Ok(url), [pl]) => match vars.get(pl) {
		Ok(pv) => {
			others = places(pv, |x| x.c.id != url)
			if pl == i or others.is_empty() [] else [[{ v: i, set: [p] }, { v: pl, set: others }]]
		}
		Err(_) => []
	}
	_ => []
}

# The conflicts of the caller. A conflict never applies when a name is no slot, or when the terms of one slot have no common value (N3).
conflict_incs : List(Var), List(List(Solver.Term)) -> List(Inc)
conflict_incs = |vars, conflicts| conflicts.keep_oks(
	|terms| match terms.map_try(|t| lit_of(vars, t)) {
		Ok(lits) => {
			joined = join_lits(lits)
			if joined.any(|l| l.set.is_empty()) Err(Never) else Ok(joined)
		}
		Err(_) => Err(Never)
	},
)

lit_of : List(Var), Solver.Term -> Try(Lit, [Unknown])
lit_of = |vars, t| match vars.find_first_index(|x| x.name == t.name) {
	Ok(v) => match vars.get(v) {
		Ok(vr) => Ok({ v, set: places(vr, |x| t.ids.contains(x.c.id) == (t.sign == In)) })
		Err(_) => Err(Unknown)
	}
	Err(_) => Err(Unknown)
}

# Two terms of one variable become one term with the places that both hold.
join_lits : List(Lit) -> List(Lit)
join_lits = |lits| lits.fold(
	[],
	|acc, l| match acc.find_first_index(|a| a.v == l.v) {
		Ok(j) => acc.map_with_index(|a, k| if k == j { v: a.v, set: a.set.keep_if(|x| l.set.contains(x)) } else a)
		Err(_) => acc.append(l)
	},
)

# Unit propagation. A term is true when all possible places are in its set, false when none is. One false term: the incompatibility holds already. All true: a clash. One open term and the rest true: that term must be false.
propagate : List(Inc), State -> [Clash(List(U64)), Stable(State)]
propagate = |incs, state| match state.find_first_index(|s| s.is_empty()) {
	Ok(v) => Clash([v])
	Err(_) => match first_move(incs, state) {
		Moved(next) => propagate(incs, next)
		Stuck(vars) => Clash(vars)
		Quiet => Stable(state)
	}
}

first_move : List(Inc), State -> [Quiet, Moved(State), Stuck(List(U64))]
first_move = |incs, state| incs.fold_until(
	Quiet,
	|_, inc| match fire(inc, state) {
		Quiet => Continue(Quiet)
		found => Break(found)
	},
)

fire : Inc, State -> [Quiet, Moved(State), Stuck(List(U64))]
fire = |inc, state| {
	classes = inc.map(|l| (l, class_of(l, state)))
	if classes.any(|(_, c)| c == Contra) {
		Quiet
	} else {
		match classes.keep_if(|(_, c)| c == Open) {
			[] => Stuck(inc.map(|l| l.v))
			[(l, _)] => Moved(state.map_with_index(|s, v| if v == l.v s.keep_if(|x| !l.set.contains(x)) else s))
			_ => Quiet
		}
	}
}

class_of : Lit, State -> [Pro, Open, Contra]
class_of = |l, state| {
	s = state.get(l.v) ?? []
	if s.all(|x| l.set.contains(x)) {
		Pro
	} else if s.any(|x| l.set.contains(x)) {
		Open
	} else {
		Contra
	}
}

# The decisions are made again from the start each time (the state is data). A clash has the number of decisions that were in force when it showed.
replay : List(Inc), State, List(Choice) -> [Clash({ depth : U64, vars : List(U64) }), Stable(State)]
replay = |incs, init, decisions| decisions.fold_with_index(
	staged(0, propagate(incs, init)),
	|acc, d, k| match acc {
		Stable(state) => staged(k + 1, propagate(incs, state.map_with_index(|s, v| if v == d.v [d.at] else s)))
		clash => clash
	},
)

staged : U64, [Clash(List(U64)), Stable(State)] -> [Clash({ depth : U64, vars : List(U64) }), Stable(State)]
staged = |depth, r| match r {
	Clash(vars) => Clash({ depth, vars })
	Stable(state) => Stable(state)
}

# D5: a clash learns the decisions that gave it (they cannot all hold) and goes back one. A clash with no decision is the end: no tuple.
search : List(Inc), State, List(Choice) -> [Found(List(U64)), NoTuple(List(U64))]
search = |incs, init, decisions| match replay(incs, init, decisions) {
	Clash(c) => if c.depth == 0 {
		NoTuple(c.vars)
	} else {
		search(incs.append(decisions.take_first(c.depth).map(|d| { v: d.v, set: [d.at] })), init, decisions.take_first(c.depth - 1))
	}
	Stable(state) => match state.find_first_index(|s| s.len() > 1) {
		Ok(v) => search(incs, init, decisions.append({ v, at: (state.get(v) ?? []).first() ?? 0 }))
		Err(_) => Found(state.map(|s| s.first() ?? 0))
	}
}
