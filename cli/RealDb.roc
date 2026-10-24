import pf.Path
import pf.Sqlite
import lib.Db
import lib.Text

## The `compat.db` calls of the real `Fx` on basic-cli `Sqlite` (slice 030, R-CC8, R-TF1 to R-TF3). The SQL is here, the decisions are in `Db` and `Facts` (TW4).
## The docs of `Fx.db_query!` and `Fx.db_write!` have the steps. The spike `research/compat-db/RESULTS.md` has what `Sqlite` can do:
## one connection for each path is kept for the process, so `PRAGMA busy_timeout` and a transaction of several calls hold; a statement with many `VALUES` rows is one write.
RealDb :: [].{

	query! : Db.Open, Db.Query => Try(Db.Answer, Db.Err)
	query! = |open, query| {
		if query_is_empty(query) {
			Ok(empty_answer(query))
		} else {
			match Path.exists!(Path.utf8(open.path)) {
				Ok(Bool.True) => read_rows!(open, query)
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
				Ok(_) => match start!(open) {
					Err(err) => Err(err)
					Ok(version) => {
						made = if version == 0 create!(open) else Ok({})
						match made {
							Err(err) => Err(err)
							Ok(_) => insert!(open, write)
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
	SqliteErr(Busy, _) => Busy
	SqliteErr(Locked, _) => Busy
	SqliteErr(code, text) => Failed("${Sqlite.errcode_to_str(code)}: ${text}")
	other => Failed(Str.inspect(other))
}

pragma_int! = |path, text, column| Sqlite.query!({ path, query: "PRAGMA ${text}", bindings: [], row: Sqlite.i64(column) })

pragma_str! = |path, text, column| Sqlite.query!({ path, query: "PRAGMA ${text}", bindings: [], row: Sqlite.str(column) })

exec! : Path.Path, Str, List(Sqlite.Binding) => Try({}, Db.Err)
exec! = |path, sql, bindings| match Sqlite.execute!({ path, query: sql, bindings }) {
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

# The first calls of each file (D4 of the slice, F1 and F2 of the spike): the busy timeout first, then the version (a newer one stops here, before the WAL switch changes the file header), then WAL.
# A failed WAL switch is no error (R-CC8, D9). The result is the version of the file (0 for a new file).
start! : Db.Open => Try(U64, Db.Err)
start! = |open| {
	path = Path.utf8(open.path)
	match pragma_int!(path, "busy_timeout=${U64.to_str(open.busy_ms)}", "timeout") {
		Err(err) => Err(err_of(err))
		Ok(_) => match pragma_int!(path, "user_version", "user_version") {
			Err(err) => Err(err_of(err))
			Ok(found) => {
				version = I64.to_u64_try(found) ?? 0
				if version > open.format {
					Err(TooNew(version))
				} else {
					_ = pragma_str!(path, "journal_mode=WAL", "journal_mode")
					Ok(version)
				}
			}
		}
	}
}

read_rows! : Db.Open, Db.Query => Try(Db.Answer, Db.Err)
read_rows! = |open, query| match start!(open) {
	Err(err) => Err(err)
	Ok(version) => if version == 0 Ok(empty_answer(query)) else select!(Path.utf8(open.path), query)
}

# R-TF2: the columns are named, never `SELECT *`.
# One query for all keys (R-EF1). The bundled SQLite is 3.49.1 and takes 32766 variables (measured, research/compat-db/RESULTS.md): 10000 fact keys use 30000. No chunks.
select! : Path.Path, Db.Query => Try(Db.Answer, Db.Err)
select! = |path, query| match query {
	Facts(keys) => {
		clause = Str.join_with(keys.map_with_index(|_, i| "(hash = :h${U64.to_str(i)} AND nightly = :n${U64.to_str(i)} AND target = :t${U64.to_str(i)})"), " OR ")
		bindings = keys.map_with_index(|key, i| fact_key_bindings(key, i)).join()
		sql = "SELECT hash, nightly, target, outcome, modules, closure FROM facts WHERE ${clause}"
		decoder = pair(Sqlite.str("hash"), pair(Sqlite.str("nightly"), pair(Sqlite.str("target"), pair(Sqlite.str("outcome"), pair(Sqlite.str("modules"), Sqlite.str("closure"))))))
		match Sqlite.query_many!({ path, query: sql, bindings, rows: decoder }) {
			Err(err) => Err(err_of(err))
			Ok(rows) => Ok(Facts(rows.keep_oks(fact_of)))
		}
	}
	Pinned(keys) => {
		clause = Str.join_with(keys.map_with_index(|_, i| "(tag = :t${U64.to_str(i)} AND target = :g${U64.to_str(i)})"), " OR ")
		bindings = keys.map_with_index(|key, i| [text(":t${U64.to_str(i)}", key.tag), text(":g${U64.to_str(i)}", key.target)]).join()
		sql = "SELECT tag, target, sha256, source FROM pinned WHERE ${clause}"
		decoder = pair(Sqlite.str("tag"), pair(Sqlite.str("target"), pair(Sqlite.str("sha256"), Sqlite.str("source"))))
		match Sqlite.query_many!({ path, query: sql, bindings, rows: decoder }) {
			Err(err) => Err(err_of(err))
			Ok(rows) => Ok(Pinned(rows.keep_oks(pinned_of)))
		}
	}
}

pair = |first, second| Sqlite.decode_record(first, second, |a, b| (a, b))

text : Str, Str -> Sqlite.Binding
text = |name, value| { name, value: String(value) }

fact_key_bindings : Db.Key, U64 -> List(Sqlite.Binding)
fact_key_bindings = |key, i| {
	n = U64.to_str(i)
	[text(":h${n}", key.hash), text(":n${n}", key.nightly), text(":t${n}", key.target)]
}

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
create! : Db.Open => Try({}, Db.Err)
create! = |open| {
	path = Path.utf8(open.path)
	match exec!(path, "BEGIN IMMEDIATE", []) {
		Err(err) => Err(err)
		Ok(_) => {
			steps = [
				"CREATE TABLE IF NOT EXISTS facts (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, outcome TEXT NOT NULL, modules TEXT NOT NULL, closure TEXT NOT NULL, PRIMARY KEY (hash, nightly, target, closure)) WITHOUT ROWID",
				"CREATE TABLE IF NOT EXISTS pinned (tag TEXT NOT NULL, target TEXT NOT NULL, sha256 TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY (tag, target)) WITHOUT ROWID",
				"PRAGMA user_version=${U64.to_str(open.format)}",
				"COMMIT",
			]
			var $failures = []
			for sql in steps {
				if $failures.is_empty() {
					match exec!(path, sql, []) {
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
					_ = exec!(path, "ROLLBACK", [])
					Err(err)
				}
			}
		}
	}
}

# R-CC8: one `INSERT` with all rows is one transaction. R-TF2: `Replace` is an upsert of the known columns, never a delete and an insert.
insert! : Db.Open, Db.Write => Try({}, Db.Err)
insert! = |open, write| {
	path = Path.utf8(open.path)
	match write {
		Facts({ rows, existing }) => {
			marks = Str.join_with(rows.map_with_index(|_, i| "(:h${U64.to_str(i)}, :n${U64.to_str(i)}, :t${U64.to_str(i)}, :o${U64.to_str(i)}, :m${U64.to_str(i)}, :c${U64.to_str(i)})"), ", ")
			conflict = match existing {
				Replace => "ON CONFLICT(hash, nightly, target, closure) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules"
				Keep => "ON CONFLICT DO NOTHING"
			}
			bindings = rows.map_with_index(|row, i| fact_bindings(row, i)).join()
			exec!(path, "INSERT INTO facts (hash, nightly, target, outcome, modules, closure) VALUES ${marks} ${conflict}", bindings)
		}
		Pinned(rows) => {
			marks = Str.join_with(rows.map_with_index(|_, i| "(:t${U64.to_str(i)}, :g${U64.to_str(i)}, :s${U64.to_str(i)}, :o${U64.to_str(i)})"), ", ")
			bindings = rows.map_with_index(|row, i| pinned_bindings(row, i)).join()
			exec!(path, "INSERT INTO pinned (tag, target, sha256, source) VALUES ${marks} ON CONFLICT DO NOTHING", bindings)
		}
	}
}

fact_bindings : Db.Fact, U64 -> List(Sqlite.Binding)
fact_bindings = |row, i| {
	n = U64.to_str(i)
	[
		text(":h${n}", row.hash),
		text(":n${n}", row.nightly),
		text(":t${n}", row.target),
		text(":o${n}", Db.outcome_word(row.outcome)),
		text(":m${n}", Db.modules_text(row.modules)),
		text(":c${n}", row.closure),
	]
}

pinned_bindings : Db.Pinned, U64 -> List(Sqlite.Binding)
pinned_bindings = |row, i| {
	n = U64.to_str(i)
	[text(":t${n}", row.tag), text(":g${n}", row.target), text(":s${n}", row.sha256), text(":o${n}", Db.source_word(row.source))]
}
