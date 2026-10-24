import Db
import Nightlies

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
	epochs = |_domain, _facts| crash "todo"

	## R-EP4, R-EP11, R-EP13: with no matrix, each release of D is an epoch of its own, in the order of D. An empty D gives no epoch.
	partition : List(Nightlies.Release) -> List(Epochs.Interval)
	partition = |_domain| crash "todo"

	## R-EP5, R-EP6, R-EP14: the inferred facts for the given epochs (a partition of D, as `partition` or the matrix of P2 gives it). See the table above.
	infer : { domain : List(Nightlies.Release), epochs : List(Epochs.Interval), facts : List(Db.Fact) } -> List(Epochs.Inferred)
	infer = |_run| crash "todo"
}
