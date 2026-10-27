import Db
import Nightlies
import Text

## Epochs and inferred facts (slice 033, Resolution 4, R-EP10 to R-EP14). Part A (pure) of TESTING.md 2.2: no `Fx`, no clock, the same inputs give the same output (R-EP10, G3).
## No command calls it yet (slice 036 wires it into the oracle loop).
##
## The design signature is `epochs : List(Release), Facts -> { epochs, inferred }`. Here `Release` is `Nightlies.Release` (only `id` is read) and `Facts` is `List(Db.Fact)`.
##
## | Part | Value | Rule |
## | --- | --- | --- |
## | Domain D | The list as given, in the order of the caller (`Nightlies.order`, R-NS1). Not sorted, not filtered. A release with no asset for the host is in D (`asset` is not read). | R-EP11, R-NS1 |
## | Facts | Real facts of rank 1 only in P1 (rank 2 is P2). Only rows with target `any` (the unit check, R-LD2) count (Registry 6, R-MX4: "epochs use unit checks only"). A row with another target (a build) is not read: no source, no pair. A row with a `nightly` that is not in D is not read. Two rows for one key (hash, nightly, `any`) never come: the caller applies R-EF3 first. | R-EP12 |
## | Code result | outcome `Pass` or `Fail` | R-EP1 |
## | Fault | outcome `Hang` or `Crash`. A real fact of its pair, but not a code result: never a source, never a boundary, never gives an inferred fact. | R-EP1, R-EP5 |
## | Adjacent | Two releases with no release of D between them: neighbors in the list | R-EP1 |
## | Epochs | A partition of D into non-empty intervals of adjacent releases, in the order of D, as ids | R-EP13 |
## | P1 epochs | No matrix (`direct`): each release is an epoch of its own (`partition`). The matrix rules (R-EP2, R-EP3) are P2: they will give `infer` another list of intervals. | R-EP4 |
## | No interval | In `infer`, a release of D that no interval holds is an epoch of its own (as the registry epochs of R-AP17: "a compiler that no listed epoch holds is an epoch of its own"). An interval with an id that is not in D holds nothing. | R-EP4 |
##
## `infer` (R-EP6): for each hash that has a real fact, and each release r of D where the hash has no real fact (a code result and a fault both count as a fact), two cases:
##
## | Case | Condition | Source releases (`from`) |
## | --- | --- | --- |
## | (a) same epoch | the hash has a code result X on a release in the epoch of r | each release of that epoch where the hash has the code result X |
## | (b) between | the nearest release before r with a code result of the hash and the nearest one after r have the same code result X (a fault or no fact is skipped) | those two releases |
##
## The result for the pair: the set of the X that the cases give. One X: an inferred fact. Both `Pass` and `Fail` (one case gives each, or one case gives both): no inferred fact (the pair stays unknown, R-EP6). No X: none. `from` is the sources of the cases that gave the result,
## in the order of D, with no repeat. A `Pass` has no modules. A `Fail` has the union of the failing modules of its sources, sorted, no repeat (Q1 of the slice file, answered by the manager: provisional, U4 of `PLAN-P1.md`).
##
## `inferred` is sorted by hash (`Text.compare`), then by the position of the release in D (R-EP10: the order of the input facts does not change it).
Epochs :: [].{

	## An epoch: the ids of its first and its last release, both in it. One release: `from` and `to` are equal (R-EP13).
	Interval : { from : Str, to : Str }

	## R-EP14: a fact for a pair with no real fact. It is marked by being in this list. `from` names the real facts it comes from: the releases (ids) where the same hash has the real code result, in the order of D. The target of the fact is `any`.
	Inferred : { hash : Str, nightly : Str, outcome : [Pass, Fail], modules : List(Str), from : List(Str) }

	## The result of `epochs`.
	Found : { epochs : List(Epochs.Interval), inferred : List(Epochs.Inferred) }

	## R-EP10 to R-EP14: the epochs of D and the inferred facts. It is `partition` and `infer` with those epochs (so in P1 only case (b) infers, R-EP4).
	epochs : List(Nightlies.Release), List(Db.Fact) -> Epochs.Found
	epochs = |domain, facts| {
		parts = partition(domain)
		{ epochs: parts, inferred: infer({ domain, epochs: parts, facts }) }
	}

	## R-EP4, R-EP11, R-EP13: with no matrix, each release of D is an epoch of its own, in the order of D. An empty D gives no epoch.
	partition : List(Nightlies.Release) -> List(Epochs.Interval)
	partition = |domain| domain.map(|r| { from: r.id, to: r.id })

	## R-EP5, R-EP6, R-EP14: the inferred facts for the given epochs (a partition of D, as `partition` or the matrix of P2 gives it). See the table above.
	infer : { domain : List(Nightlies.Release), epochs : List(Epochs.Interval), facts : List(Db.Fact) } -> List(Epochs.Inferred)
	infer = |run| {
		ids = run.domain.map(|r| r.id)
		groups = groups_of(ids, run.epochs)
		units = run.facts.keep_if(|f| f.target == "any")
		Text.sorted_unique(units.map(|f| f.hash)).join_map(|hash| infer_hash(ids, groups, hash, units.keep_if(|f| f.hash == hash)))
	}
}

# What one hash has on one release of D: no fact, a code result, or a fault (R-EP1, R-EP5).
Cell : [Gap, Done([Pass, Fail], List(Str)), Fault]

# The epoch of each release of D, by place. A release that no interval holds gets a group of its own (R-EP4).
groups_of : List(Str), List(Epochs.Interval) -> List(U64)
groups_of = |ids, intervals| {
	spans = intervals.map(|iv| span_of(ids, iv))
	ids.map_with_index(|_, p| spans.find_first_index(|s| holds(s, p)) ?? (spans.len() + p))
}

span_of : List(Str), Epochs.Interval -> Try((U64, U64), [NotInD])
span_of = |ids, iv| match (ids.find_first_index(|id| id == iv.from), ids.find_first_index(|id| id == iv.to)) {
	(Ok(lo), Ok(hi)) => Ok((lo, hi))
	_ => Err(NotInD)
}

holds : Try((U64, U64), [NotInD]), U64 -> Bool
holds = |span, p| match span {
	Ok((lo, hi)) => lo <= p and p <= hi
	Err(_) => Bool.False
}

cell_at : List(Db.Fact), Str -> Cell
cell_at = |facts, id| match facts.keep_if(|f| f.nightly == id).first() {
	Err(_) => Gap
	Ok(f) => match f.outcome {
		Pass => Done(Pass, [])
		Fail => Done(Fail, f.modules)
		Hang => Fault
		Crash => Fault
	}
}

result_at : List(Cell), U64 -> Try([Pass, Fail], [NoResult])
result_at = |cells, p| match cells.get(p) {
	Ok(Done(outcome, _)) => Ok(outcome)
	_ => Err(NoResult)
}

modules_at : List(Cell), U64 -> List(Str)
modules_at = |cells, p| match cells.get(p) {
	Ok(Done(_, modules)) => modules
	_ => []
}

infer_hash : List(Str), List(U64), Str, List(Db.Fact) -> List(Epochs.Inferred)
infer_hash = |ids, groups, hash, facts| {
	cells = ids.map(|id| cell_at(facts, id))
	places = ids.map_with_index(|_, p| p)
	places.keep_oks(|r| infer_at({ ids, groups, cells, places, hash }, r))
}

# R-EP6 for the release at place r: case (a) the results in its epoch, case (b) the nearest results before and after.
infer_at : { ids : List(Str), groups : List(U64), cells : List(Cell), places : List(U64), hash : Str }, U64 -> Try(Epochs.Inferred, [Unknown])
infer_at = |ctx, r| match ctx.cells.get(r) {
	Ok(Gap) => {
		is_code = |p| result_at(ctx.cells, p).is_ok()
		group = |p| ctx.groups.get(p) ?? 0
		between = match (ctx.places.keep_if(|p| p < r and is_code(p)).last(), ctx.places.keep_if(|p| p > r and is_code(p)).first()) {
			(Ok(b), Ok(a)) => match (result_at(ctx.cells, b), result_at(ctx.cells, a)) {
				(Ok(x), Ok(y)) if x == y => [b, a]
				_ => []
			}
			_ => []
		}
		sources = ctx.places.keep_if(|p| is_code(p) and (group(p) == group(r) or between.contains(p)))
		outcomes = sources.keep_oks(|p| result_at(ctx.cells, p))
		match outcomes.first() {
			Ok(x) if outcomes.all(|o| o == x) => Ok({
				hash: ctx.hash,
				nightly: ctx.ids.get(r) ?? "",
				outcome: x,
				modules: Text.sorted_unique(sources.join_map(|p| modules_at(ctx.cells, p))),
				from: sources.keep_oks(|p| ctx.ids.get(p)),
			})
			_ => Err(Unknown)
		}
	}
	_ => Err(Unknown)
}
