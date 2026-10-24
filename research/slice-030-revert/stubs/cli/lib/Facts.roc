import Db
import Fail
import Fx
import Probe
import Roots

## The facts of `compat.db` for the commands (slice 030): the row of a probe result (R-P4, R-PP4), the first-seen sha256 of a compiler (R-CV6) and the command side of the db calls
## (R-CC8, R-TF3). Parts A (pure) and C (direct style over `Fx`) of TESTING.md 2.2. The store is `Db`. Slice 031 writes unit probe facts, slice 032 reads build passes.
##
## The calls of the three effect functions (the L2 entry `db`, `tests/commands/cases/db/cc1-store`, fixes them):
##
## | Function | `Fx` calls | Rule |
## | --- | --- | --- |
## | `load!` | No keys: none. Else one `db_query!` with `Facts(keys)`. `Err(Busy)` and `Err(Failed)`: the line `warning: <Db.on_err text>` on stderr (`fx.err!`), and the answer is `[]`. `Err(TooNew)`: `Err(fail)` (exit 19). | R-EF1 (rank 1), R-CC8, R-TF3 |
## | `save!` | No rows: none. Else one `db_write!` with `Facts({ rows, existing })` (one transaction for the round). `Err(Busy)` and `Err(Failed)`: the same warning, and the result is `Kept` (the facts stay in memory in the command). `Err(TooNew)`: `Err(fail)`. | R-CC8, R-PP4, R-TF3 |
## | `pin!` | One `db_query!` with `Pinned([key])`. `New`: one `db_write!` with `Pinned([listed])`. `Same`: no write. `Changed`: `Err(changed_fail)`, no write. `Err(TooNew)`: `Err(fail)`. | R-CV6, R-TF3 |
##
## Every call takes `Db.Open` with `path: Roots.item(roots, CompatDb)`, `busy_ms: Db.busy_ms` and `format: Db.format`.
Facts :: [].{

	## The answer of `pin!`. `New`: the first sha256 of the asset, now recorded. `Same`: the recorded sha256 is the listed one.
	Sighting : [New, Same]

	## The result of `save!`. `Saved`: the rows are in the file. `Kept`: the db stayed busy (or failed), so the rows are only in memory.
	Round : [Saved, Kept]

	## R-P4, R-PP4, R-P3: the row for the result of one probe, or no row. `hash` and `nightly` are the key (`nightly` is the compiler id, R-NS12). `host` is the target of a build (the host).
	## `closure` is the used-closure digest (R-BS2), used for a build pass only. `errors` are the errors of the probe (`Probe.errors`).
	##
	## | `class` | `command` | Row | Rule |
	## | --- | --- | --- | --- |
	## | `NoFact` | any | `Err(NoFact)`: no row (a download error, a signal from outside) | R-P3 |
	## | `Pass` | `Check` | target `any`, outcome `Pass`, no modules, no closure | R-P4 |
	## | `Pass` | `Build` | target `host`, outcome `Pass`, no modules, `closure` as given | R-P4 |
	## | `Fail(_)` | `Check` or `Build` | target `any` or `host`, outcome `Fail`, `modules` and no closure. `modules` are the paths of the errors with a `Package` file of this `hash`, sorted, no repeat. An error of another file (the app, another package, no file) is not a module of this hash. A fail with no such error has no module. | R-P4 |
	## | `Hang` | any | target as for a pass of the command, outcome `Hang`, no modules, no closure | R-P3, R-PP4 |
	## | `Crash(_)` | any | the same with outcome `Crash` | R-P3, R-PP4 |
	of_probe : { hash : Str, nightly : Str, host : Str, command : Probe.Command, class : Probe.Class, errors : List(Probe.Err), closure : Str } -> Try(Db.Fact, [NoFact])
	of_probe = |_facts| crash "todo"

	## R-EF1 (rank 1): the facts that a query gave, by key. A key has one fact (it is the primary key).
	index : List(Db.Fact) -> Dict(Db.Key, Db.Fact)
	index = |_rows| crash "todo"

	## R-CV6: the first-seen decision. `recorded` are the rows that the query for (`listed.tag`, `listed.target`) gave. No row with this tag and target: `New`. A row with the same `sha256`: `Same`
	## (a changed `source` is no change). A row with another `sha256`: `Changed`, with the recorded row as `first` and the listed one as `now`.
	first_seen : { recorded : List(Db.Pinned), listed : Db.Pinned } -> [New, Same, Changed({ first : Db.Pinned, now : Db.Pinned })]
	first_seen = |_facts| crash "todo"

	## R-CV6: the failure for `Changed`: kind `Integrity` (exit 16). The message names the tag, the target, both values and both sources (proposal, TW24, R-OUT2):
	## `the sha256 of <tag> for <target> changed: first seen <first sha256> (<first source>), now <now sha256> (<now source>). Talon does not use this compiler. Select another compiler.`
	## The source words are `github-digest` and `registry`. There is no override.
	changed_fail : { first : Db.Pinned, now : Db.Pinned } -> Fail
	changed_fail = |_facts| crash "todo"

	## The facts of the keys (R-EF1). See the table above.
	load! : Fx, { roots : Roots, keys : List(Db.Key) } => Try(List(Db.Fact), Fail)
	load! = |_fx, _run| crash "todo"

	## One round of facts in one transaction (R-CC8). See the table above.
	save! : Fx, { roots : Roots, rows : List(Db.Fact), existing : [Replace, Keep] } => Try(Facts.Round, Fail)
	save! = |_fx, _run| crash "todo"

	## R-CV6: record the first sha256 of an asset, or stop when it changed. See the table above. Not wired into `tln roc install` or the compiler list in slice 030 (question Q1).
	pin! : Fx, { roots : Roots, listed : Db.Pinned } => Try(Facts.Sighting, Fail)
	pin! = |_fx, _run| crash "todo"
}
