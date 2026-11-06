import Domain
import Search
import semver.Semver

## The types of the solver and the builders of its incompatibilities (slice 036b3: split from `Solver`). `Solver` has the API and the search. `SolverProbe` has the incompatibilities of the probe facts, `SolverWhy` the explanation.
SolverBase :: [].{

	## One variable. `name` is its name (the alias of its first use). `group` is the group of its releases (the key of a dep). `kind` is the kind that a release must have (R-C4), or `Compiler` for `roc`: then only `id` of each candidate is read. The rest is `Domain.Query` without the rules.
	Slot : { name : Str, group : Str, kind : [Package, Platform, Compiler], candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]) }

	## A dep of a release: the group and the lowest version that the release needs (`X.Y.Z`).
	Dep : { group : Str, version : Str }

	## The header facts of one release: its kind (the first keyword of its header), its platform (`pf`, the URL, `Err(None)` for none), and its deps.
	Fact : { id : Str, kind : [Package, Platform, App], pf : Try(Str, [None]), deps : List(SolverBase.Dep) }

	## A term of a conflict: the value of the variable `name` is `In` the ids, or `NotIn` the ids. An id that is not a value of the variable is not in either set.
	Term : { name : Str, ids : List(Str), sign : [In, NotIn] }

	## One unit result (R-EP12, a row of `Db.Fact` with the target `any`, or an inferred fact of `Epochs.Inferred`): the release `id` on the compiler `nightly`. `modules` are the failing modules of a `Fail`. `source` marks an inferred fact (R-EP14). A pair has one check.
	Check : { id : Str, nightly : Str, outcome : [Pass, Fail, Hang, Crash], modules : List(Str), source : [Real, Inferred] }

	## The modules of the release `id` that the app uses (R-UM1).
	Use : { id : Str, modules : List(Str) }

	## The probe knowledge: D, the checks, the used modules, and if the step may ask for probes (`Off`: `--no-probe`, or the budget is spent, R-EP9).
	Compat : { domain : List(Str), checks : List(SolverBase.Check), used : List(SolverBase.Use), probes : [Allowed, Off] }

	## `slots` are in the order of `priority`. `conflicts` are incompatibilities of the caller: the terms of one conflict cannot all be true. A conflict with a `name` that is no slot never applies.
	Request : { slots : List(SolverBase.Slot), rules : Domain.Rules, facts : List(SolverBase.Fact), conflicts : List(List(SolverBase.Term)), compat : SolverBase.Compat }

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
	Step : { terms : List(SolverBase.Term), cause : SolverBase.Cause }

	## The explanation of a `Fail`: the steps that lead to the empty incompatibility, in a valid order (a `Derived` names earlier steps). The last step has no term. Each step follows from its leaves (the steps that are no `Derived`, reached through `Derived`): in each tuple of values that
	## makes all terms of the step true, all terms of one leaf are true.
	Why : { steps : List(SolverBase.Step) }

	## A value of a variable: a release of the domain and its parsed version (a compiler has none).
	Val : { c : Domain.Candidate, ver : Try(Semver, [NoVer]) }

	## A variable. Its values are in the order of the domain, and a value is its place in `vals`.
	Var : { name : Str, group : Str, kind : [Package, Platform, Compiler], vals : List(SolverBase.Val) }

	## An incompatibility of the search with the reason that it holds.
	Inc : { lits : List(Search.Lit), cause : SolverBase.Cause }

	## The probe knowledge in the form that the intervals need. `All`: real and inferred checks. `Real`: real checks only.
	Env : { sizes : List(U64), cells : Dict(Str, SolverBase.Check), used : Dict(Str, List(Str)), domain : List(Str), mode : [All, Real], ri : U64 }

	## An interval of D (places in D).
	Span : { from : U64, to : U64, kind : [Fail, Fault] }

	## The texts of the list, without a repeat, in the order of the first one.
	dedupe : List(Str) -> List(Str)
	dedupe = |list| list.fold([], |acc, x| if acc.contains(x) acc else acc.append(x))

	## Joins the lits of one variable, leaves out the lits with all places, sorts by variable. `Never`: a lit has no place, so the incompatibility never holds.
	norm : List(U64), List(Search.Lit) -> Try(List(Search.Lit), [Never])
	norm = |sizes, lits| {
		joined = join_lits(lits)
		if joined.any(|l| l.set.is_empty()) {
			Err(Never)
		} else {
			Ok(joined.keep_if(|l| l.set.len() != (sizes.get(l.v) ?? 0)).sort_with(|a, b| a.v.order_relative_to(b.v)))
		}
	}

	## One incompatibility from the lits, with the cause, or none when `norm` says `Never`.
	mk : List(U64), List(Search.Lit), SolverBase.Cause -> List(SolverBase.Inc)
	mk = |sizes, lits, cause| match norm(sizes, lits) {
		Ok(ls) => [{ lits: ls, cause }]
		Err(_) => []
	}
}

# Two terms of one variable become one term with the places that both hold.
join_lits : List(Search.Lit) -> List(Search.Lit)
join_lits = |lits| lits.fold(
	[],
	|acc, l| match acc.find_first_index(|a| a.v == l.v) {
		Ok(j) => acc.map_with_index(|a, k| if k == j { v: a.v, set: a.set.keep_if(|x| l.set.contains(x)) } else a)
		Err(_) => acc.append(l)
	},
)
