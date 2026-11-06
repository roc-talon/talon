import records.Closure as Wire
import Db
import Epochs
import Nightlies
import resolve.Solver

## The registry evidence of a closure answer (slice 209; Resolution 3 R-EF1 ranks 2 and 6, R-EF3; Resolution 4 R-EP2, R-EP3, R-EP4, R-EP6, R-EP15; Registry 4.1 R-AP17, R-AP19, R-AP58; Resolution 4 R-SM6; Design R-SE5). Part A (pure).
## `Matrix` (R-EP15) is the registry data that the epochs read: the `epochs` of the closure answer. The `runs` and `nearest` of the answer are the rank 2 facts (R-EP12). The `hints` are rank 6: they only order the search (R-SE5), they are never a fact.
##
## | Part | Value | Rule |
## | --- | --- | --- |
## | D | The compilers of the command, in R-NS1 order (`Nightlies.order`), as `Epochs` reads them | R-EP11 |
## | A compiler tag of the answer in D | The release of D that is `PinOrder.same_id` with it (R-CV1) | R-CV1 |
## | An interval `[from, to]` of the answer (a run, an epoch) | Each release `c` of D with `from` <= `c` <= `to` in R-NS1 order (`PinOrder.order_of` with the `published_at` of D). An end that D does not have (a hidden compiler, R-AP19) is placed by that order too, so the interval holds only the compilers that the client knows | R-AP17, R-AP19 |
## | `error_digest` | `Err(None)` for `null`, `Ok("")` for an empty text: 2 different digests (R-AP58) | R-AP58 |
##
## Design Q393 (Resolution R-EF3): a rank 2 `fail` has an unknown set of failing modules (the wire has only an `error_digest`). An unknown set touches each module that the app uses, and such a fail does not decide alone, as an inferred fact (R-EP8): `unknown_sets` marks its check. The tests do not read `modules` of a registry fact in `real`.
Matrix :: [].{

	## One registry row on one compiler, before the precedence of R-EF3. `nightly` is the compiler: a release id of D for a run, the tag of the answer for a `nearest` row.
	Row : { hash : Str, nightly : Str, target : Str, source : [Bot, Author], result : [Pass, Fail, Hang, Crash], error_digest : Try(Str, [None]) }

	## The rank 6 hint of one pair (R-EF3): `Pass` when `pass_count` > `fail_count` + `crash_count`, `Fail` when `fail_count` + `crash_count` > `pass_count`. The counts as the answer has them.
	Shared : { result : [Pass, Fail], pass_count : U64, fail_count : U64, crash_count : U64 }

	## R-AP17, R-AP19, R-AP58, R-SM6: the rows of `runs` and `nearest`.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | A run gives one row for each release of D in its interval, in the order of D, with the `id` of the release of D as `nightly`. A run with no release of D in it gives none |
	## | 2 | A `nearest` row gives one row, with its `nightly` as the answer has it |
	## | 3 | The order: the runs in the order of the answer, then the `nearest` rows in the order of the answer |
	## | 4 | `hash`, `target`, `source`, `result` and `error_digest` are those of the item. Each target (a smoke row of a host target too, R-SM6) |
	rows : { runs : List(Wire.Run), nearest : List(Wire.Nearest), domain : List(Nightlies.Release) } -> List(Matrix.Row)
	rows = |_| crash "todo: slice 209"

	## R-EF1, R-EF3, R-EP12: the real facts of rank 1 and rank 2 of the command.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | Each row of `local` (rank 1, `compat.db`) as it is, first, in its order |
	## | 2 | Then one fact for each key (`hash`, `nightly`, `target`) of `rows` that `local` does not have (a rank 1 row wins over rank 2: the key is the text, as in `Evidence.of_pair`), in the order of the first row of the key |
	## | 3 | For a key with a `bot` row and an `author` row: the `bot` row (R-EF3), also when the `author` row comes first |
	## | 4 | The fact: `outcome` is the `result`, `closure` is `""`. `modules` are not fixed by the tests: the oracle reads the set of a rank 2 `fail` through `unknown_sets` (Q393) |
	real : { local : List(Db.Fact), rows : List(Matrix.Row) } -> List(Db.Fact)
	real = |_| crash "todo: slice 209"

	## R-EP2, R-EP3, R-EP4, R-EP13, R-EP15: the epochs of D with the matrix, a partition of D in the order of D.
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | Only the epochs of the answer with the target `any` (R-MX4: epochs use unit checks only) |
	## | 2 | An epoch of the answer holds the releases of D in its interval. Each transition in it is covered and not a boundary of case (a) of R-EP3 (R-EP2) |
	## | 3 | Case (b) of R-EP3, only inside an epoch of the answer: the transition (r0, r1) of 2 adjacent releases of D is a boundary when 2 or more hashes have a code result (`Pass` or `Fail`, R-EP1) on both in `facts` (target `any`) and the 2 results of the hash are different. A fault is not compared (R-EP5). A boundary splits the epoch |
	## | 4 | A transition between 2 epochs of the answer is a boundary or not covered: 2 epochs are never joined (R-EP3) |
	## | 5 | A release of D that no epoch of the answer holds is an epoch of its own (R-EP4) |
	## | 6 | No epoch of the answer (no registry): `Epochs.partition` (R-EP15) |
	intervals : { domain : List(Nightlies.Release), epochs : List(Wire.Epoch), facts : List(Db.Fact) } -> List(Epochs.Interval)
	intervals = |_| crash "todo: slice 209"

	## R-EP10 with the matrix (R-EP15): `intervals`, and `Epochs.infer` with them. With no epoch of the answer it is `Epochs.epochs(domain, facts)`.
	found : { domain : List(Nightlies.Release), epochs : List(Wire.Epoch), facts : List(Db.Fact) } -> Epochs.Found
	found = |_| crash "todo: slice 209"

	## R-EF1 rank 6, R-EF3, R-SE5: the hint of a pair from the `hints` of the answer: the first row with the `hash`, the `target` and a `nightly` that is `PinOrder.same_id` with the given one. Equal counts, or no row: `Err(None)`.
	shared : { hints : List(Wire.Hint), hash : Str, nightly : Str, target : Str } -> Try(Matrix.Shared, [None])
	shared = |_| crash "todo: slice 209"

	## Design Q393, Resolution R-EF3, R-EP8, R-UM1, R-EP7: the checks of the oracle (`OracleDomain.checks`) with the rank 2 `fail`s marked. A check whose key (the hash of its release URL `id`, `nightly`, the target `any`) has no row in `local` (rank 1), and whose fact of
	## rank 2 (after the precedence of `real`: a `bot` row wins) is a `fail` of `rows`, becomes `source: Inferred` with `modules: []` (an unknown set: it touches each used module, and it never decides alone, so the step asks for the local unit probe).
	## Every other check stays as it is: a rank 2 `pass`, a rank 2 `hang` or `crash`, a rank 1 row, an inferred fact, the assumed pass. The order of the checks stays.
	unknown_sets : { checks : List(Solver.Check), local : List(Db.Fact), rows : List(Matrix.Row) } -> List(Solver.Check)
	unknown_sets = |_| crash "todo: slice 209"
}
