import Domain

## The solver step (Resolution 5 step 3, R-AL3, R-PK6; TESTING.md 2.2, part B): PubGrub over variables with a finite list of values. Pure: the same request gives the same answer (R-DT2).
## The state is data. The caller (slice 036) calls `step` again with more facts after a `Need`.
##
## | Part | Meaning | Rule |
## | --- | --- | --- |
## | Variable | One `Slot`, in the order of `priority` (the first slot has the strongest rank). Its values are `Domain.values` without the releases that a fact shows to have the wrong kind. | R-VA6, R-C1, R-C4, R-C6, R-C7, R-C9 |
## | Term | A set of values of one variable: `In` the ids, or `NotIn` the ids. The solver keeps one set of possible values for each variable. | |
## | Incompatibility | Terms that cannot all be true. It is built from a fact, or the caller gives it (`conflicts`). | R-C2, R-C3 |
## | Unit propagation | An incompatibility with one open term takes that term out of the possible values. All terms true is a conflict. | |
## | Decision | The first variable (in the order of the slots) with more than one possible value takes its best value (the order of `Domain.values`). So the result is the best tuple by `priority`. | R-VA6 |
## | Conflict | The solver learns the decisions that gave it, goes back one decision and goes on. A conflict with no decision is `Fail`. (The conflict resolution of PubGrub and the explanation are slice 035.) | |
##
## Facts that the solver reads (header facts, R-AL8), one `Fact` for each release that the caller has read:
##
## | Fact | Incompatibility | Rule |
## | --- | --- | --- |
## | `kind` is not the kind of the slot (`App` is never right) | The release is not a value of the slot | R-C4 |
## | A dep names the `group` of another slot with a version | `not (release and slot_value < version)`: the other slot has a value at or above the version | R-C2 |
## | `pf` is a URL, and the request has exactly one platform slot | `not (release and platform_slot is not that URL)` | R-C3 |
##
## A release with no fact is taken as fit (optimistic). The solver finds the best tuple with the facts that it has. If a release of that tuple has no fact, the answer is `Need` with the ids of these releases, in the order of the slots. A release that is not in the tuple is never asked for (R-AL9: the facts of a version that does not win are never asked for). `Done` is only for a tuple of which each release has a fact.
##
## A dep with a group that no slot has (a transitive group), and the closure of the tuple, are not read here: the caller checks them and gives a failure back as a conflict (R-AL9, slice 036).
Solver :: [].{

	## One variable. `name` is its name (the alias of its first use). `group` is the group of its releases (the key of a dep). `kind` is the kind that a release must have (R-C4). The rest is `Domain.Query` without the rules.
	Slot : { name : Str, group : Str, kind : [Package, Platform], candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]) }

	## A dep of a release: the group and the lowest version that the release needs (`X.Y.Z`).
	Dep : { group : Str, version : Str }

	## The header facts of one release: its kind (the first keyword of its header), its platform (`pf`, the URL, `Err(None)` for none), and its deps.
	Fact : { id : Str, kind : [Package, Platform, App], pf : Try(Str, [None]), deps : List(Solver.Dep) }

	## A term of a conflict: the value of the variable `name` is `In` the ids, or `NotIn` the ids. An id that is not a value of the variable is not in either set.
	Term : { name : Str, ids : List(Str), sign : [In, NotIn] }

	## `slots` are in the order of `priority`. `conflicts` are incompatibilities of the caller: the terms of one conflict cannot all be true. A conflict with a `name` that is no slot never applies.
	Request : { slots : List(Solver.Slot), rules : Domain.Rules, facts : List(Solver.Fact), conflicts : List(List(Solver.Term)) }

	## What the solver needs: the header facts of a release (R-AL8).
	Ask : [Header(Str)]

	## One chosen value.
	Chosen : { name : Str, id : Str, version : Str }

	## The reason of `Fail`: the names of the variables of the incompatibility that was true with no decision, in the order of the slots. It is not an explanation (slice 035).
	Why : { names : List(Str) }

	## The step. `Need`: ask for these facts, and call again. `Done`: the best tuple, one `Chosen` for each slot, in the order of the slots. `Fail`: no tuple.
	step : Solver.Request -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]
	step = |_req| crash "todo"
}
