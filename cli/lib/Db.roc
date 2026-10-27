import Fail
import Text

## `talon/compat.db`: the types and the pure decisions of the store (slice 030, TESTING.md 2.2 part A). The file is SQLite. `Fx.db_query!` and `Fx.db_write!` reach it
## (the real `Fx` has the SQL, `cli/RealDb.roc`). The types are the rows of `compat.db` (R-PK7: they move to the package `records` when the registry app needs them).
##
## The schema, format 1 (R-TF1: the number is in `PRAGMA user_version`, 0 is a new file). The names are the contract of the real `Fx`:
##
## | Table | Columns (all TEXT, NOT NULL) | Primary key | Rule |
## | --- | --- | --- | --- |
## | `facts` | `hash`, `nightly`, `target`, `outcome`, `modules`, `closure` | (`hash`, `nightly`, `target`, `closure`) | R-P4, R-NS12, R-BS2 |
## | `pinned` | `tag`, `target`, `sha256`, `source` | (`tag`, `target`) | R-CV6 |
##
## `facts`: `nightly` is the compiler id, a nightly tag or a release (R-NS12). `target` is `any` for a check (R-P4). `outcome` is `pass`, `fail`, `hang` or `crash`.
## `modules` is the set of failing modules of a fail (R-P4), sorted, joined with `,` (the empty text for any other outcome). `closure` is the used-closure digest of a build (R-P4, R-BS2: a pass, a fail, a hang and a crash of a build have it),
## the empty text for a check row. Slice 032: the primary key has the digest, so a key (hash, nightly, target) has one row for each digest of a build, and one row for a check (its digest is empty). `pinned`: the first sha256 that Talon saw for the asset (tag, target) of a compiler (R-CV6). `source` is `github-digest` or `registry` (R-CV5).
## The real `Fx` reads the columns by name, never `SELECT *`, and a write changes only these columns, so a column that a later Talon adds with the same format is ignored and kept (R-TF2).
##
## The text form of a row (one line, fields split by a TAB) is used by the fake `Fx` (its store is a text file), by `tests/tools/dumpdb.py` (the dump that the L3 runner compares with
## `expect/facts.tsv`) and by `fxprobe`:
##
## | Line | Form |
## | --- | --- |
## | Format | `format<TAB><n>` |
## | Fact | `fact<TAB>hash<TAB>nightly<TAB>target<TAB>outcome<TAB>modules<TAB>closure` |
## | Pinned | `pinned<TAB>tag<TAB>target<TAB>sha256<TAB>source` |
Db :: [].{

	## R-TF1: the format that this Talon writes. R-TF3: a file with a larger number is never written.
	format : U64
	format = 1

	## R-CC8: the busy timeout (an option of the connection), in milliseconds. The command gives it to the `Fx` (the real `Fx` has no Talon constant, TW4).
	busy_ms : U64
	busy_ms = 5000

	## The result of a probe (R-RC1 to R-RC4). A hang and a crash are facts of their own class (R-P3).
	Outcome : [Pass, Fail, Hang, Crash]

	## (hash, nightly, target): the key of a fact (R-P4).
	Key : { hash : Str, nightly : Str, target : Str }

	## One row of `facts`. `modules` and `closure` as in the table above.
	Fact : { hash : Str, nightly : Str, target : Str, outcome : Outcome, modules : List(Str), closure : Str }

	## Where a sha256 came from (R-CV3, R-CV5).
	Source : [GithubDigest, Registry]

	## One row of `pinned`.
	Pinned : { tag : Str, target : Str, sha256 : Str, source : Source }

	## (tag, target): the key of a `pinned` row.
	PinKey : { tag : Str, target : Str }

	## A row of either table, for the text form.
	Row : [Fact(Fact), Pinned(Pinned)]

	## What an `Fx` db call needs to open the file. `path` is `Roots.item(roots, CompatDb)`. `busy_ms` is `Db.busy_ms`. `format` is `Db.format`.
	Open : { path : Str, busy_ms : U64, format : U64 }

	## What `db_query!` asks for: the rows of these keys (the rows that exist, in any order). A key can have more than one row (one for each `closure`, slice 032).
	Query : [Facts(List(Key)), Pinned(List(PinKey))]

	## What `db_query!` gives.
	Answer : [Facts(List(Fact)), Pinned(List(Pinned))]

	## What `db_write!` writes, in one transaction (R-CC8). `Facts` with `existing`: for a row with the same key and the same `closure` (the primary key), `Replace` changes the known columns of that row, `Keep` leaves it. A row with another `closure` is a new row.
	## `Pinned` always keeps the first row of a key (R-CV6: the first sha256 that was seen stays).
	Write : [Facts({ rows : List(Fact), existing : [Replace, Keep] }), Pinned(List(Pinned))]

	## What a call can fail with. `Busy`: another process held the lock for `busy_ms` (R-CC8). `TooNew(n)`: the file has the format `n`, which is larger than `format` (R-TF3): nothing was
	## read from it and nothing was written. `Failed(text)`: anything else (the file is not a database, the dir cannot be made, a disk error).
	Err : [Busy, TooNew(U64), Failed(Str)]

	## The words of the text column `outcome` and their reverse.
	outcome_word : Outcome -> Str
	outcome_word = |outcome| match outcome {
		Pass => "pass"
		Fail => "fail"
		Hang => "hang"
		Crash => "crash"
	}

	outcome_of : Str -> Try(Outcome, [BadWord])
	outcome_of = |text| match text {
		"pass" => Ok(Pass)
		"fail" => Ok(Fail)
		"hang" => Ok(Hang)
		"crash" => Ok(Crash)
		_ => Err(BadWord)
	}

	## The words of the text column `source` (`github-digest`, `registry`) and their reverse.
	source_word : Source -> Str
	source_word = |source| match source {
		GithubDigest => "github-digest"
		Registry => "registry"
	}

	source_of : Str -> Try(Source, [BadWord])
	source_of = |text| match text {
		"github-digest" => Ok(GithubDigest)
		"registry" => Ok(Registry)
		_ => Err(BadWord)
	}

	## The column `modules` (R-P4): the set of modules, sorted by byte order with no repeat, joined with `,`. The reverse splits at `,` (the empty text is no module).
	modules_text : List(Str) -> Str
	modules_text = |modules| Str.join_with(Text.sorted_unique(modules), ",")

	modules_of : Str -> List(Str)
	modules_of = |text| if text.is_empty() [] else text.split_on(",")

	## R-PK7: the line of a row, as the table above says (no line end).
	fact_line : Fact -> Str
	fact_line = |fact| Str.join_with(
		["fact", fact.hash, fact.nightly, fact.target, Db.outcome_word(fact.outcome), Db.modules_text(fact.modules), fact.closure],
		"\t",
	)

	pinned_line : Pinned -> Str
	pinned_line = |pinned| Str.join_with(
		["pinned", pinned.tag, pinned.target, pinned.sha256, Db.source_word(pinned.source)],
		"\t",
	)

	## The reverse of one line. A line with a wrong table word, a wrong field count or a wrong outcome or source word is `Err(BadLine)`. The `modules` field is read with `modules_of`.
	parse_line : Str -> Try(Row, [BadLine])
	parse_line = |line| match line.split_on("\t") {
		["fact", hash, nightly, target, outcome_text, modules, closure] => match Db.outcome_of(outcome_text) {
			Ok(outcome) => Ok(Fact({ hash, nightly, target, outcome, modules: Db.modules_of(modules), closure }))
			Err(BadWord) => Err(BadLine)
		}
		["pinned", tag, target, sha256, source_text] => match Db.source_of(source_text) {
			Ok(source) => Ok(Pinned({ tag, target, sha256, source }))
			Err(BadWord) => Err(BadLine)
		}
		_ => Err(BadLine)
	}

	## The text of a store: the line `format<TAB>n`, then the `fact` lines sorted by (hash, nightly, target, closure), then the `pinned` lines sorted by (tag, target). Each line ends with a line end.
	## The sort is by byte order (`Text.sorted`). The same rows give the same text in any input order.
	file_text : { format : U64, facts : List(Fact), pinned : List(Pinned) } -> Str
	file_text = |store| {
		facts = store.facts.sort_with(fact_order).map(Db.fact_line)
		pinned = store.pinned.sort_with(pinned_order).map(Db.pinned_line)
		lines = ["format\t${U64.to_str(store.format)}"].concat(facts).concat(pinned)
		lines.fold("", |text, line| "${text}${line}\n")
	}

	## The reverse of `file_text`. The empty text is `{ format: 0, facts: [], pinned: [] }` (a new file). A bad line, or no `format` line first in a text that is not empty, is `Err(BadLine)`.
	parse_file : Str -> Try({ format : U64, facts : List(Fact), pinned : List(Pinned) }, [BadLine])
	parse_file = |text| {
		if text.is_empty() {
			Ok({ format: 0, facts: [], pinned: [] })
		} else {
			lines = text.split_on("\n")
			# The text ends with a line end, so the last piece is empty.
			body = if lines.last() == Ok("") lines.drop_last(1) else lines
			match body {
				[head, .. as rest] => match head.split_on("\t") {
					["format", number] => match U64.from_str(number) {
						Ok(version) => parse_rows(rest, version)
						Err(_) => Err(BadLine)
					}
					_ => Err(BadLine)
				}
				[] => Err(BadLine)
			}
		}
	}

	## What a command does with a failed db call (R-CC8, R-TF3). `what` is `Read` or `Write`. `path` is the file.
	##
	## | `err` | Result | Rule |
	## | --- | --- | --- |
	## | `TooNew(n)` | `Stop(fail)`: kind `Input` (exit 19). The message names the file, the format `n` and `tln tool update talon`: `<path> has format <n>. This tln writes format <format>. Run: tln tool update talon` | R-TF3 |
	## | `Busy` | `Warn(text)`: a `Write` says that the facts of this command stay in memory and are not saved, a `Read` says that Talon goes on with no saved facts. The text names `compat.db`. | R-CC8 |
	## | `Failed(text)` | `Warn(text)`: as `Busy`, and the line names the file, the text of the failure and the fix: `cannot use <path> (<text>): <saved>. Removing the file resets the stored facts and the first-seen sha256 of compilers.` | R-CC8 (the same loss: a fact is evidence, a lost write costs a probe later) |
	##
	## The text of a `Warn` has no `warning: ` and no line end (the command adds them, as for the other warnings).
	on_err : { err : Err, what : [Read, Write], path : Str } -> [Stop(Fail), Warn(Str)]
	on_err = |facts| match facts.err {
		TooNew(found) => Stop(
			Fail.new(Input, "${facts.path} has format ${U64.to_str(found)}. This tln writes format ${U64.to_str(Db.format)}. Run: tln tool update talon"),
		)
		Busy => Warn(
			match facts.what {
				Write => "compat.db is busy: the facts of this command are not saved"
				Read => "compat.db is busy: Talon goes on with no saved facts"
			},
		)
		Failed(reason) => {
			effect = match facts.what {
				Write => "the facts of this command are not saved"
				Read => "Talon goes on with no saved facts"
			}
			Warn("cannot use ${facts.path} (${reason}): ${effect}. Removing the file resets the stored facts and the first-seen sha256 of compilers.")
		}
	}
}

# The rows after the `format` line. A line that is not a row of the right table is `BadLine`.
parse_rows : List(Str), U64 -> Try({ format : U64, facts : List(Db.Fact), pinned : List(Db.Pinned) }, [BadLine])
parse_rows = |lines, version| {
	var $facts = []
	var $pinned = []
	var $bad = Bool.False
	for line in lines {
		match Db.parse_line(line) {
			Ok(Fact(fact)) => {
				$facts = $facts.append(fact)
			}
			Ok(Pinned(pinned)) => {
				$pinned = $pinned.append(pinned)
			}
			Err(BadLine) => {
				$bad = Bool.True
			}
		}
	}
	if $bad Err(BadLine) else Ok({ format: version, facts: $facts, pinned: $pinned })
}

# Compare the first key, and the second one only when the first are the same.
then_by : [Before, Same, After], [Before, Same, After] -> [Before, Same, After]
then_by = |first, second| match first {
	Same => second
	_ => first
}

fact_order : Db.Fact, Db.Fact -> [Before, Same, After]
fact_order = |a, b| Text.compare(a.hash, b.hash)
	|> then_by(Text.compare(a.nightly, b.nightly))
	|> then_by(Text.compare(a.target, b.target))
	|> then_by(Text.compare(a.closure, b.closure))

pinned_order : Db.Pinned, Db.Pinned -> [Before, Same, After]
pinned_order = |a, b| Text.compare(a.tag, b.tag) |> then_by(Text.compare(a.target, b.target))
