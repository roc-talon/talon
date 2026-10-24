app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Sqlite
import pf.Path
import pf.Stdout
import pf.Sleep

## Spike for slice 030: what basic-cli Sqlite can do for compat.db (R-CC8).
## Usage: spike single <db> | writer <db> <tag> <n> <busy_ms> <gap_ms> | hold <db> <hold_ms> <busy_ms> | busy <db> <busy_ms>
main! = |args| {
	words = args.map(|a| a.display())
	match words {
		["single", db] => single!(db)
		["writer", db, tag, n, busy, gap] => writer!(db, tag, U64.from_str(n) ?? 0, U64.from_str(busy) ?? 0, U64.from_str(gap) ?? 0)
		["hold", db, hold, busy] => hold!(db, U64.from_str(hold) ?? 0, U64.from_str(busy) ?? 0)
		["count", db] => count!(db)
		["version", db] => version!(db)
		["vars", db, n] => vars!(db, U64.from_str(n) ?? 0)
		["busy", db, busy] => try_write!(db, U64.from_str(busy) ?? 0)
		_ => {
			Stdout.line!("usage: see spike.roc")?
			Err(Exit(2))
		}
	}
}

say! = |text| Stdout.line!(text)

fail! = |what, err| {
	say!("ERR ${what}: ${Str.inspect(err)}")?
	Err(Exit(1))
}

## PRAGMA that returns one text row.
pragma_str! = |db, name, column| Sqlite.query!({
	path: Path.utf8(db),
	query: "PRAGMA ${name}",
	bindings: [],
	row: Sqlite.str(column),
})

## PRAGMA that returns one integer row.
pragma_int! = |db, name, column| Sqlite.query!({
	path: Path.utf8(db),
	query: "PRAGMA ${name}",
	bindings: [],
	row: Sqlite.i64(column),
})

setup! = |db, busy| {
	match pragma_int!(db, "busy_timeout=${U64.to_str(busy)}", "timeout") {
		Ok(n) => say!("busy_timeout set, returned ${I64.to_str(n)}")?
		Err(e) => return fail!("busy_timeout", e)
	}
	match pragma_str!(db, "journal_mode=WAL", "journal_mode") {
		Ok(mode) => say!("journal_mode=${mode}")?
		# R-CC8: a failed WAL switch is not fatal. The default journal and the busy timeout stay.
		Err(e) => say!("journal_mode failed, go on: ${Str.inspect(e)}")?
	}
	Ok({})
}

exec! = |db, sql, what| {
	match Sqlite.execute!({ path: Path.utf8(db), query: sql, bindings: [] }) {
		Ok(_) => Ok({})
		Err(e) => fail!(what, e)
	}
}

single! = |db| {
	setup!(db, 5000)?
	# does busy_timeout persist to the next call (connection cache)?
	match pragma_int!(db, "busy_timeout", "timeout") {
		Ok(n) => say!("busy_timeout read back in a later call: ${I64.to_str(n)}")?
		Err(e) => return fail!("busy_timeout read", e)
	}
	match pragma_int!(db, "user_version", "user_version") {
		Ok(n) => say!("user_version before: ${I64.to_str(n)}")?
		Err(e) => return fail!("user_version", e)
	}
	exec!(db, "PRAGMA user_version=7", "set user_version")?
	match pragma_int!(db, "user_version", "user_version") {
		Ok(n) => say!("user_version after: ${I64.to_str(n)}")?
		Err(e) => return fail!("user_version", e)
	}
	exec!(db, "CREATE TABLE IF NOT EXISTS facts (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, result TEXT NOT NULL, PRIMARY KEY (hash, nightly, target)) STRICT, WITHOUT ROWID", "create")?
	# one INSERT with 2 rows: one statement, so one atomic write
	match Sqlite.execute!({
		path: Path.utf8(db),
		query: "INSERT OR REPLACE INTO facts (hash, nightly, target, result) VALUES (:h1, :n, :t, :r1), (:h2, :n, :t, :r2)",
		bindings: [
			{ name: ":h1", value: String("aaa") },
			{ name: ":h2", value: String("bbb") },
			{ name: ":n", value: String("nightly-2026-10-14-38a3029") },
			{ name: ":t", value: String("any") },
			{ name: ":r1", value: String("pass") },
			{ name: ":r2", value: String("fail") },
		],
	}) {
		Ok(_) => say!("insert ok")?
		Err(e) => return fail!("insert", e)
	}
	rows = Sqlite.query_many!({
		path: Path.utf8(db),
		query: "SELECT hash, result FROM facts ORDER BY hash",
		bindings: [],
		rows: Sqlite.decode_record(Sqlite.str("hash"), Sqlite.str("result"), |h, r| "${h}=${r}"),
	})
	match rows {
		Ok(list) => say!("rows: ${Str.join_with(list, ",")}")?
		Err(e) => return fail!("select", e)
	}
	# BEGIN and COMMIT in separate calls: same connection?
	exec!(db, "BEGIN IMMEDIATE", "begin")?
	exec!(db, "INSERT OR REPLACE INTO facts VALUES ('ccc', 'n', 'any', 'pass')", "tx insert")?
	exec!(db, "COMMIT", "commit")?
	say!("transaction over 3 calls ok")
}

writer! = |db, tag, n, busy, gap| {
	setup!(db, busy)?
	exec!(db, "CREATE TABLE IF NOT EXISTS facts (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, result TEXT NOT NULL, PRIMARY KEY (hash, nightly, target)) STRICT, WITHOUT ROWID", "create")?
	var $errors = 0.U64
	var $i = 0.U64
	while $i < n {
		r = Sqlite.execute!({
			path: Path.utf8(db),
			query: "INSERT OR REPLACE INTO facts VALUES (:h, 'n', 'any', 'pass')",
			bindings: [{ name: ":h", value: String("${tag}-${U64.to_str($i)}") }],
		})
		match r {
			Ok(_) => {}
			Err(_) => { $errors = $errors + 1 }
		}
		$i = $i + 1
		if gap > 0 Sleep.millis!(gap)
	}
	say!("writer ${tag}: ${U64.to_str(n)} writes, ${U64.to_str($errors)} errors")
}

## Hold the write lock in an open transaction, then commit.
hold! = |db, hold_ms, busy| {
	setup!(db, busy)?
	exec!(db, "CREATE TABLE IF NOT EXISTS facts (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, result TEXT NOT NULL, PRIMARY KEY (hash, nightly, target)) STRICT, WITHOUT ROWID", "create")?
	exec!(db, "BEGIN IMMEDIATE", "begin")?
	say!("holding")?
	Sleep.millis!(hold_ms)
	exec!(db, "INSERT OR REPLACE INTO facts VALUES ('held', 'n', 'any', 'pass')", "held insert")?
	exec!(db, "COMMIT", "commit")?
	say!("released")
}

try_write! = |db, busy| {
	setup!(db, busy)?
	match Sqlite.execute!({ path: Path.utf8(db), query: "INSERT OR REPLACE INTO facts VALUES ('late', 'n', 'any', 'pass')", bindings: [] }) {
		Ok(_) => say!("write ok")
		Err(SqliteErr(code, text)) => say!("write failed: ${Sqlite.errcode_to_str(code)} ${text}")
		Err(other) => say!("write failed: ${Str.inspect(other)}")
	}
}

count! = |db| {
	match Sqlite.query!({ path: Path.utf8(db), query: "SELECT COUNT(*) AS n FROM facts", bindings: [], row: Sqlite.u64("n") }) {
		Ok(n) => say!("rows: ${U64.to_str(n)}")
		Err(e) => fail!("count", e)
	}
}

## Slice 030, C5: the version of the bundled SQLite.
version! = |db| match Sqlite.query!({ path: Path.utf8(db), query: "SELECT sqlite_version() AS v", bindings: [], row: Sqlite.str("v") }) {
	Ok(v) => say!("sqlite_version ${v}")
	Err(e) => fail!("version", e)
}

## Slice 030, C5: a query with `n` named bindings (the limit of variables). `n` bindings in one `IN` list.
vars! = |db, n| {
	names = U64.until(0, n).fold([], |kept, i| kept.append(":v${U64.to_str(i)}"))
	bindings = names.map(|name| { name, value: String("x") })
	marks = Str.join_with(names, ", ")
	match Sqlite.query!({ path: Path.utf8(db), query: "SELECT COUNT(*) AS n FROM (SELECT 'x' AS c) WHERE c IN (${marks})", bindings, row: Sqlite.u64("n") }) {
		Ok(c) => say!("${U64.to_str(n)} variables: ok, count ${U64.to_str(c)}")
		Err(e) => say!("${U64.to_str(n)} variables: failed ${Str.inspect(e)}")
	}
}
