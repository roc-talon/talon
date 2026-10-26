import pf.Duration
import pf.Path
import pf.Sqlite
import pf.Sqlite.Decoder
import lib.Db
import lib.Text

## The `compat.db` calls of the real `Fx` on basic-cli `Sqlite` (slice 030, R-CC8, R-TF1 to R-TF3). The SQL is here, the decisions are in `Db` and `Facts` (TW4).
## The docs of `Fx.db_query!` and `Fx.db_write!` have the steps. The spike `research/compat-db/RESULTS.md` has what `Sqlite` can do:
## basic-cli 0.26 gives one connection for each `Sqlite.open!`. Each `query!` and `write!` opens one connection and uses it for all of its statements,
## so the busy timeout (an open option) and a transaction of several statements hold; a statement with many `VALUES` rows is one write.
RealDb :: [].{

	query! : Db.Open, Db.Query => Try(Db.Answer, Db.Err)
	query! = |open, query| {
		if query_is_empty(query) {
			Ok(empty_answer(query))
		} else {
			match Path.exists!(Path.utf8(open.path)) {
				Ok(Bool.True) => match open_db!(open) {
					Err(err) => Err(err)
					Ok(db) => read_rows!(db, open, query)
				}
				Ok(Bool.False) => Ok(empty_answer(query))
				Err(PathErr(err, _)) => Err(Failed(Str.inspect(err)))
			}
		}
	}

	write! : Db.Open, Db.Write => Try({}, Db.Err)
	write! = |open, write| {
		if write_is_empty(write) {
			Ok({})
		} else {
			match make_parent!(open.path) {
				Err(err) => Err(err)
				Ok(_) => match open_db!(open) {
					Err(err) => Err(err)
					Ok(db) => match start!(db, open) {
						Err(err) => Err(err)
						Ok(version) => {
							made = if version == 0 create!(db, open) else Ok({})
							match made {
								Err(err) => Err(err)
								Ok(_) => insert!(db, write)
							}
						}
					}
				}
			}
		}
	}
}

query_is_empty : Db.Query -> Bool
query_is_empty = |query| match query {
	Facts(keys) => keys.is_empty()
	Pinned(keys) => keys.is_empty()
}

write_is_empty : Db.Write -> Bool
write_is_empty = |write| match write {
	Facts({ rows, existing: _ }) => rows.is_empty()
	Pinned(rows) => rows.is_empty()
}

empty_answer : Db.Query -> Db.Answer
empty_answer = |query| match query {
	Facts(_) => Facts([])
	Pinned(_) => Pinned([])
}

# R-CC8: `Busy` and `Locked` are a lock that stayed held. Any other error is a failure with its text.
err_of = |err| match err {
	SqliteErr(found) => sqlite_err(found)
	other => Failed(Str.inspect(other))
}

sqlite_err : Sqlite.Err -> Db.Err
sqlite_err = |err| match err {
	Failed({ code: Busy, extended_code: _, message: _ }) => Busy
	Failed({ code: Locked, extended_code: _, message: _ }) => Busy
	Failed({ code, extended_code: _, message }) => Failed("${Str.inspect(code)}: ${message}")
	_ => Failed(err.to_str())
}

# One connection for the whole call. R-CC8: the busy timeout is an option of the connection.
open_db! : Db.Open => Try(Sqlite.Db, Db.Err)
open_db! = |open| match Sqlite.open!(Path.utf8(open.path), { busy_timeout: Duration.millis(open.busy_ms) }) {
	Ok(db) => Ok(db)
	Err(err) => Err(err_of(err))
}

# SQL that the code makes at run time, with the values of its `?` marks in order.
sql : Str, List(Sqlite.Value) -> Sqlite.Query
sql = |text, values| Sqlite.Query.new(text, values)

exec! : Sqlite.Db, Str, List(Sqlite.Value) => Try({}, Db.Err)
exec! = |db, text, values| match db.execute!(sql(text, values)) {
	Ok(_) => Ok({})
	Err(err) => Err(err_of(err))
}

# The dirs of the file (R-CC8: a write makes them). A path with no dir part needs none.
make_parent! : Str => Try({}, Db.Err)
make_parent! = |file| {
	dir = Text.dir_of(file)
	if dir.is_empty() {
		Ok({})
	} else {
		match Path.create_all!(Path.utf8(dir)) {
			Ok(_) => Ok({})
			Err(PathErr(err, _)) => Err(Failed("cannot make ${dir}: ${Str.inspect(err)}"))
		}
	}
}

# The first calls of each file (D4 of the slice, F1 and F2 of the spike): the busy timeout first (`open_db!`), then the version (a newer one stops here, before the WAL switch changes the file header), then WAL.
# A failed WAL switch is no error (R-CC8, D9). The result is the version of the file (0 for a new file).
start! : Sqlite.Db, Db.Open => Try(U64, Db.Err)
start! = |db, open| match db.query_one!(sql("PRAGMA user_version", []), Decoder.i64("user_version")) {
	Err(err) => Err(err_of(err))
	Ok(found) => {
		version = I64.to_u64_try(found) ?? 0
		if version > open.format {
			Err(TooNew(version))
		} else {
			_ = db.query_one!(sql("PRAGMA journal_mode=WAL", []), Decoder.str("journal_mode"))
			Ok(version)
		}
	}
}

read_rows! : Sqlite.Db, Db.Open, Db.Query => Try(Db.Answer, Db.Err)
read_rows! = |db, open, query| match start!(db, open) {
	Err(err) => Err(err)
	Ok(version) => if version == 0 Ok(empty_answer(query)) else select!(db, query)
}

# R-TF2: the columns are named, never `SELECT *`.
# One query for all keys (R-EF1). The bundled SQLite is 3.49.1 and takes 32766 variables (measured, research/compat-db/RESULTS.md): 10000 fact keys use 30000. No chunks.
select! : Sqlite.Db, Db.Query => Try(Db.Answer, Db.Err)
select! = |db, query| match query {
	Facts(keys) => {
		clause = Str.join_with(keys.map(|_| "(hash = ? AND nightly = ? AND target = ?)"), " OR ")
		values = keys.map(|key| [String(key.hash), String(key.nightly), String(key.target)]).join()
		text = "SELECT hash, nightly, target, outcome, modules, closure FROM facts WHERE ${clause}"
		decoder = pair(Decoder.str("hash"), pair(Decoder.str("nightly"), pair(Decoder.str("target"), pair(Decoder.str("outcome"), pair(Decoder.str("modules"), Decoder.str("closure"))))))
		match db.query_all!(sql(text, values), decoder) {
			Err(err) => Err(err_of(err))
			Ok(rows) => Ok(Facts(rows.keep_oks(fact_of)))
		}
	}
	Pinned(keys) => {
		clause = Str.join_with(keys.map(|_| "(tag = ? AND target = ?)"), " OR ")
		values = keys.map(|key| [String(key.tag), String(key.target)]).join()
		text = "SELECT tag, target, sha256, source FROM pinned WHERE ${clause}"
		decoder = pair(Decoder.str("tag"), pair(Decoder.str("target"), pair(Decoder.str("sha256"), Decoder.str("source"))))
		match db.query_all!(sql(text, values), decoder) {
			Err(err) => Err(err_of(err))
			Ok(rows) => Ok(Pinned(rows.keep_oks(pinned_of)))
		}
	}
}

pair = |first, second| first.map2(second, |a, b| (a, b))

# A row with an outcome word that this Talon does not know is no fact (R-TF2 spirit: the row is ignored).
fact_of : (Str, (Str, (Str, (Str, (Str, Str))))) -> Try(Db.Fact, [BadWord])
fact_of = |(hash, (nightly, (target, (outcome_text, (modules, closure)))))| match Db.outcome_of(outcome_text) {
	Ok(outcome) => Ok({ hash, nightly, target, outcome, modules: Db.modules_of(modules), closure })
	Err(BadWord) => Err(BadWord)
}

pinned_of : (Str, (Str, (Str, Str))) -> Try(Db.Pinned, [BadWord])
pinned_of = |(tag, (target, (sha256, source_text)))| match Db.source_of(source_text) {
	Ok(source) => Ok({ tag, target, sha256, source })
	Err(BadWord) => Err(BadWord)
}

# R-CC8, R-TF1: a new file gets the 2 tables of `Db` and the version in one transaction. A second process that does the same at the same time waits for the lock (`IF NOT EXISTS`: both can run it).
create! : Sqlite.Db, Db.Open => Try({}, Db.Err)
create! = |db, open| {
	match exec!(db, "BEGIN IMMEDIATE", []) {
		Err(err) => Err(err)
		Ok(_) => {
			steps = [
				"CREATE TABLE IF NOT EXISTS facts (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, outcome TEXT NOT NULL, modules TEXT NOT NULL, closure TEXT NOT NULL, PRIMARY KEY (hash, nightly, target, closure)) WITHOUT ROWID",
				"CREATE TABLE IF NOT EXISTS pinned (tag TEXT NOT NULL, target TEXT NOT NULL, sha256 TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY (tag, target)) WITHOUT ROWID",
				"PRAGMA user_version=${U64.to_str(open.format)}",
				"COMMIT",
			]
			var $failures = []
			for step in steps {
				if $failures.is_empty() {
					match exec!(db, step, []) {
						Ok(_) => {}
						Err(err) => {
							$failures = [err]
						}
					}
				}
			}
			match $failures {
				[] => Ok({})
				[err, ..] => {
					_ = exec!(db, "ROLLBACK", [])
					Err(err)
				}
			}
		}
	}
}

# R-CC8: one `INSERT` with all rows is one transaction. R-TF2: `Replace` is an upsert of the known columns, never a delete and an insert.
insert! : Sqlite.Db, Db.Write => Try({}, Db.Err)
insert! = |db, write| match write {
	Facts({ rows, existing }) => {
		marks = Str.join_with(rows.map(|_| "(?, ?, ?, ?, ?, ?)"), ", ")
		conflict = match existing {
			Replace => "ON CONFLICT(hash, nightly, target, closure) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules"
			Keep => "ON CONFLICT DO NOTHING"
		}
		values = rows.map(fact_values).join()
		exec!(db, "INSERT INTO facts (hash, nightly, target, outcome, modules, closure) VALUES ${marks} ${conflict}", values)
	}
	Pinned(rows) => {
		marks = Str.join_with(rows.map(|_| "(?, ?, ?, ?)"), ", ")
		values = rows.map(|row| [String(row.tag), String(row.target), String(row.sha256), String(Db.source_word(row.source))]).join()
		exec!(db, "INSERT INTO pinned (tag, target, sha256, source) VALUES ${marks} ON CONFLICT DO NOTHING", values)
	}
}

fact_values : Db.Fact -> List(Sqlite.Value)
fact_values = |row| [
	String(row.hash),
	String(row.nightly),
	String(row.target),
	String(Db.outcome_word(row.outcome)),
	String(Db.modules_text(row.modules)),
	String(row.closure),
]
