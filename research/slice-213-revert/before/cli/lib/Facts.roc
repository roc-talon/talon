import Db
import Fail
import Fx
import Probe
import Roots
import Text

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
## | `pin_all!` | Slice 030b, for the compiler list (`Nightlies.list!`). No row: none. Else one `db_query!` with `Pinned(keys)` (one key for each listed row). `Err(Busy)` and `Err(Failed)`: the line `warning: <Db.on_err text>` on stderr, no write, the result is `[]` (the list is used as it is). `Err(TooNew)`: `Err(fail)` (exit 19). Else `first_seen_all`. No `new` row: no write. Else one `db_write!` with `Pinned(new)` (a row that exists stays). `Err(Busy)` and `Err(Failed)` on that write: the same warning, with the text for `Write`. The result is `changed` of `first_seen_all`, also after a failed write. | R-CV6, R-CC8, R-TF3 |
##
## Every call takes `Db.Open` with `path: Roots.item(roots, CompatDb)`, `busy_ms: Db.busy_ms` and `format: Db.format`.
Facts :: [].{

	## The answer of `pin!`. `New`: the first sha256 of the asset, now recorded. `Same`: the recorded sha256 is the listed one.
	Sighting : [New, Same]

	## R-CV6 (slice 030b): a recorded sha256 and a listed one that differ, for one asset (tag and target). `first` is the recorded row, `now` the listed row.
	Change : { first : Db.Pinned, now : Db.Pinned }

	## The result of `save!`. `Saved`: the rows are in the file. `Kept`: the db stayed busy (or failed), so the rows are only in memory.
	Round : [Saved, Kept]

	## R-P4, R-PP4, R-P3: the row for the result of one probe, or no row. `hash` and `nightly` are the key (`nightly` is the compiler id, R-NS12). `host` is the target of a build (the host).
	## `closure` is the used-closure digest (R-BS2). A build keeps it for every class (slice 032), a check has none. `errors` are the errors of the probe (`Probe.errors`).
	##
	## | `class` | `command` | Row | Rule |
	## | --- | --- | --- | --- |
	## | `NoFact` | any | `Err(NoFact)`: no row (a download error, a signal from outside) | R-P3 |
	## | `Pass` | `Check` | target `any`, outcome `Pass`, no modules, no closure | R-P4 |
	## | `Pass` | `Build` | target `host`, outcome `Pass`, no modules, `closure` as given | R-P4 |
	## | `Fail(_)` | `Check` or `Build` | target `any` or `host`, outcome `Fail`, `modules`, and `closure` for a build (none for a check). `modules` are the paths of the errors with a `Package` file of this `hash`, sorted, no repeat. An error of another file (the app, another package, no file) is not a module of this hash. A fail with no such error has no module. | R-P4 |
	## | `Hang` | any | target as for a pass of the command, outcome `Hang`, no modules, `closure` for a build (none for a check) | R-P3, R-PP4, R-BS2 |
	## | `Crash(_)` | any | the same with outcome `Crash` | R-P3, R-PP4, R-BS2 |
	of_probe : { hash : Str, nightly : Str, host : Str, command : Probe.Command, class : Probe.Class, errors : List(Probe.Err), closure : Str } -> Try(Db.Fact, [NoFact])
	of_probe = |facts| {
		target = match facts.command {
			Check => "any"
			Build(_) => facts.host
		}
		closure = match facts.command {
			Check => ""
			Build(_) => facts.closure
		}
		row = |outcome, modules, used| Ok({ hash: facts.hash, nightly: facts.nightly, target, outcome, modules, closure: used })
		match facts.class {
			NoFact(_) => Err(NoFact)
			Pass => row(Pass, [], closure)
			Fail(_) => row(Fail, failing_modules(facts.hash, facts.errors), closure)
			Hang => row(Hang, [], closure)
			Crash(_) => row(Crash, [], closure)
		}
	}

	## R-EF1 (rank 1): the facts that a query gave, by key. A check key has one fact. A build key can have one row for each digest (slice 032: the primary key has the closure), so the index is for the check facts (target `any`): `BuildSkip.decide` reads the build rows.
	index : List(Db.Fact) -> Dict(Db.Key, Db.Fact)
	index = |rows| Dict.from_list(rows.map(|row| ({ hash: row.hash, nightly: row.nightly, target: row.target }, row)))

	## R-CV6: the first-seen decision. `recorded` are the rows that the query for (`listed.tag`, `listed.target`) gave. No row with this tag and target: `New`. A row with the same `sha256`: `Same`
	## (a changed `source` is no change). A row with another `sha256`: `Changed`, with the recorded row as `first` and the listed one as `now`.
	first_seen : { recorded : List(Db.Pinned), listed : Db.Pinned } -> [New, Same, Changed({ first : Db.Pinned, now : Db.Pinned })]
	first_seen = |facts| match facts.recorded.find_first(|row| row.tag == facts.listed.tag and row.target == facts.listed.target) {
		Err(_) => New
		Ok(first) => if first.sha256 == facts.listed.sha256 Same else Changed({ first, now: facts.listed })
	}

	## R-CV6 (slice 030b): the first-seen decision for a whole list. `listed` are the rows of the list (one for each asset), `recorded` are the rows that a query for their keys gave.
	## `new` are the listed rows with no recorded row for their tag and target, in the order of `listed`, one row for each tag and target (a repeated tag and target is one row). `changed` are the
	## listed rows with another recorded sha256 (`first_seen` gives `Changed`), in the order of `listed`. A listed row with the same sha256 (also with another source) is in neither list.
	first_seen_all : { recorded : List(Db.Pinned), listed : List(Db.Pinned) } -> { new : List(Db.Pinned), changed : List(Facts.Change) }
	first_seen_all = |facts| {
		same_key = |a, b| a.tag == b.tag and a.target == b.target
		fold = |acc, listed| match Facts.first_seen({ recorded: facts.recorded, listed }) {
			New => if acc.new.any(|seen| same_key(seen, listed)) acc else { new: acc.new.append(listed), changed: acc.changed }
			Same => acc
			Changed(change) => { new: acc.new, changed: acc.changed.append(change) }
		}
		facts.listed.fold({ new: [], changed: [] }, fold)
	}

	## R-CV6: the failure for `Changed`: kind `Integrity` (exit 16). The message names the tag, the target, both values and both sources (proposal, TW24, R-OUT2):
	## `the sha256 of <tag> for <target> changed: first seen <first sha256> (<first source>), now <now sha256> (<now source>). Talon does not use this compiler. Select another compiler.`
	## The source words are `github-digest` and `registry`. There is no override.
	changed_fail : { first : Db.Pinned, now : Db.Pinned } -> Fail
	changed_fail = |facts| {
		first = facts.first
		now = facts.now
		Fail.new(
			Integrity,
			"the sha256 of ${now.tag} for ${now.target} changed: first seen ${first.sha256} (${Db.source_word(first.source)}), now ${now.sha256} (${Db.source_word(now.source)}). Talon does not use this compiler. Select another compiler.",
		)
	}

	## The facts of the keys (R-EF1). See the table above.
	load! : Fx, { roots : Roots, keys : List(Db.Key) } => Try(List(Db.Fact), Fail)
	load! = |fx, run| {
		if run.keys.is_empty() {
			Ok([])
		} else {
			open = open_of(run.roots)
			match fx.db_query!(open, Facts(run.keys)) {
				Ok(Facts(rows)) => Ok(rows)
				Ok(Pinned(_)) => Err(wrong_answer)
				Err(err) => match settle!(fx, { err, what: Read, path: open.path }) {
					Ok(_) => Ok([])
					Err(fail) => Err(fail)
				}
			}
		}
	}

	## One round of facts in one transaction (R-CC8). See the table above.
	save! : Fx, { roots : Roots, rows : List(Db.Fact), existing : [Replace, Keep] } => Try(Facts.Round, Fail)
	save! = |fx, run| {
		if run.rows.is_empty() {
			Ok(Saved)
		} else {
			open = open_of(run.roots)
			match fx.db_write!(open, Facts({ rows: run.rows, existing: run.existing })) {
				Ok(_) => Ok(Saved)
				Err(err) => match settle!(fx, { err, what: Write, path: open.path }) {
					Ok(_) => Ok(Kept)
					Err(fail) => Err(fail)
				}
			}
		}
	}

	## R-CV6 (slice 030b): record the first sha256 of each asset of a list, and give the assets that changed. See the table above. `Nightlies.list!` calls it once for each list that it reads.
	## It stops only for `TooNew` (exit 19). A change is not a failure here: the list drops the tag (`Nightlies.without_changed`), and a command that names the tag stops (`Toolchain.changed_failed`).
	pin_all! : Fx, { roots : Roots, listed : List(Db.Pinned) } => Try(List(Facts.Change), Fail)
	pin_all! = |fx, run| {
		if run.listed.is_empty() {
			Ok([])
		} else {
			open = open_of(run.roots)
			keys = run.listed.map(|row| { tag: row.tag, target: row.target })
			recorded = match fx.db_query!(open, Pinned(keys)) {
				Ok(Pinned(rows)) => Ok(Some(rows))
				Ok(Facts(_)) => Err(wrong_answer)
				Err(err) => match settle!(fx, { err, what: Read, path: open.path }) {
					Ok(_) => Ok(None)
					Err(fail) => Err(fail)
				}
			}
			match recorded {
				Err(fail) => Err(fail)
				Ok(None) => Ok([])
				Ok(Some(rows)) => {
					seen = Facts.first_seen_all({ recorded: rows, listed: run.listed })
					match record_new!(fx, open, seen.new) {
						Ok(_) => Ok(seen.changed)
						Err(fail) => Err(fail)
					}
				}
			}
		}
	}

	## R-CV6: record the first sha256 of an asset, or stop when it changed. See the table above. Slice 030b wires `pin_all!`, not this function, into the compiler list.
	pin! : Fx, { roots : Roots, listed : Db.Pinned } => Try(Facts.Sighting, Fail)
	pin! = |fx, run| {
		open = open_of(run.roots)
		key = { tag: run.listed.tag, target: run.listed.target }
		recorded = match fx.db_query!(open, Pinned([key])) {
			Ok(Pinned(rows)) => Ok(rows)
			Ok(Facts(_)) => Err(wrong_answer)
			Err(err) => match settle!(fx, { err, what: Read, path: open.path }) {
				Ok(_) => Ok([])
				Err(fail) => Err(fail)
			}
		}
		match recorded {
			Err(fail) => Err(fail)
			Ok(rows) => match Facts.first_seen({ recorded: rows, listed: run.listed }) {
				Same => Ok(Same)
				Changed(change) => Err(Facts.changed_fail(change))
				New => match fx.db_write!(open, Pinned([run.listed])) {
					Ok(_) => Ok(New)
					Err(err) => match settle!(fx, { err, what: Write, path: open.path }) {
						Ok(_) => Ok(New)
						Err(fail) => Err(fail)
					}
				}
			}
		}
	}
}

# R-CV6, R-CC8: one write for the new rows. A busy or failed write is a warning.
record_new! : Fx, Db.Open, List(Db.Pinned) => Try({}, Fail)
record_new! = |fx, open, new| if new.is_empty() {
	Ok({})
} else {
	match fx.db_write!(open, Pinned(new)) {
		Ok(_) => Ok({})
		Err(err) => settle!(fx, { err, what: Write, path: open.path })
	}
}

open_of : Roots -> Db.Open
open_of = |roots| { path: Roots.item(roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }

wrong_answer : Fail
wrong_answer = Fail.new(Internal, "compat.db gave the answer of another table")

# R-CC8, R-TF3: a failed call is a warning on stderr (the command goes on), or a stop.
settle! : Fx, { err : Db.Err, what : [Read, Write], path : Str } => Try({}, Fail)
settle! = |fx, call| match Db.on_err(call) {
	Stop(fail) => Err(fail)
	Warn(text) => {
		fx.err!("warning: ${text}\n")
		Ok({})
	}
}

# The paths of the errors in a package of this hash (R-P4).
failing_modules : Str, List(Probe.Err) -> List(Str)
failing_modules = |hash, errors| Text.sorted_unique(
	errors.keep_oks(
		|err| match err.file {
			Package(found) => if found.hash == hash Ok(found.path) else Err(NotThis)
			_ => Err(NotThis)
		},
	),
)
