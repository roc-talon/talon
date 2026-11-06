import lib.Db
import FakeBase

## The `compat.db` calls of the fake `Fx` (slice 030, TESTING.md 2.4). The store is a text file next to the db path: `<dir>/compat.tsv` for `<dir>/compat.db`, in the line form of
## `Db.file_text` (the same lines as the dump that the L3 runner compares with `expect/facts.tsv`). The file is a real file in the case dir, so `tree.diff` shows each write.
## Rows that a case gives go in the given tree (`given/home/.cache/roc/talon/compat.tsv`).
##
## | File in `<w>/fx/` | Gives | Default |
## | --- | --- | --- |
## | `db` | One rule for each line: `<n>: busy`, `<n>: failed <text>`, `<n>: version <k>`. The n-th call of `db_query!` and `db_write!` in the case (counted from 1 over both) gives `Err(Busy)`, `Err(Failed(text))`, or `Err(TooNew(k))` (when `k` is larger than the format of the call) and changes no file. Lines that start with `#` are comments. | every call works |
##
## Log lines (`calls.log`): `db_query <path> busy_ms=<n> format=<n> facts=<count of keys>` or `pinned=<count of keys>`, and `db_write <path> busy_ms=<n> format=<n> facts=<count of rows> existing=replace` (or `keep`)
## or `pinned=<count of rows>`. The fake follows the same rules as the real `Fx` (the docs of `Fx.db_query!` and `Fx.db_write!`): a query of a file that does not exist gives the empty answer and makes no file, a write
## makes the file and the missing dirs (slice 213: `QueueCount` counts the lines of `share_queue.tsv` next to `compat.tsv`, 0 when `compat.tsv` is missing. `ClearQueue` empties that file and makes no file. Slice 215: `Queue` adds the lines `Db.queue_line` to it with the dedupe and the cap of the doc of `Db.Write`, and makes `compat.tsv` with the `format` line when it is missing. Its log line has `queue=<count of rows> cap=<n>`), a `format` line in the store that is larger than the format of the call gives `TooNew`, `Facts` with `Keep` and `Pinned` leave a row that exists, a write with no row changes nothing.
FakeDb :: [].{

	## The text file that holds the rows of the db path.
	store_path : Str -> Str
	store_path = |db_path| "${db_path.drop_suffix(".db")}.tsv"

	query! : Str, Db.Open, Db.Query => Try(Db.Answer, Db.Err)
	query! = |w, open, query| {
		summary = match query {
			Facts(keys) => "facts=${keys.len().to_str()}"
			Pinned(keys) => "pinned=${keys.len().to_str()}"
			QueueCount => "queue"
			QueueRows => "queue_rows"
		}
		rule = next_call!(w)
		FakeBase.log!(w, "db_query ${open.path} busy_ms=${open.busy_ms.to_str()} format=${open.format.to_str()} ${summary}")
		match rule_err(rule, open.format) {
			Err(err) => Err(err)
			Ok(_) => match load!(open) {
				Err(err) => Err(err)
				Ok(store) => Ok(
					match query {
						Facts(keys) => Facts(store.facts.keep_if(|f| keys.contains({ hash: f.hash, nightly: f.nightly, target: f.target })))
						Pinned(keys) => Pinned(store.pinned.keep_if(|p| keys.contains({ tag: p.tag, target: p.target })))
						QueueCount => QueueCount(if exists!(open) queue_rows!(open).len() else 0)
						QueueRows => QueueRows(if exists!(open) queue_rows!(open).keep_oks(Db.queue_of).sort_by(|item| item.seq) else [])
					},
				)
			}
		}
	}

	write! : Str, Db.Open, Db.Write => Try({}, Db.Err)
	write! = |w, open, write| {
		summary = match write {
			Facts({ rows, existing }) => "facts=${rows.len().to_str()} existing=${if existing == Replace "replace" else "keep"}"
			Pinned(rows) => "pinned=${rows.len().to_str()}"
			ClearQueue => "clear_queue"
			Queue({ rows, cap }) => "queue=${rows.len().to_str()} cap=${cap.to_str()}"
			Unqueue(seqs) => "unqueue=${seqs.len().to_str()}"
		}
		rule = next_call!(w)
		FakeBase.log!(w, "db_write ${open.path} busy_ms=${open.busy_ms.to_str()} format=${open.format.to_str()} ${summary}")
		match rule_err(rule, open.format) {
			Err(err) => Err(err)
			Ok(_) => match load!(open) {
				Err(err) => Err(err)
				Ok(store) => match write {
					ClearQueue => {
						# Slice 213 (R-SH4): a file that does not exist is not made. The rows of the queue are a text file of the fake.
						if exists!(open) and !queue_rows!(open).is_empty() {
							_ = FakeBase.write_with_parents!(queue_path(open), "")
						}
						Ok({})
					}
					Queue({ rows, cap }) => add_queue!(open, rows, cap)
					# Slice 216 (R-SH4): the lines with these `seq` go. A file that does not exist is not made. No `seq` or no such row: no change.
					Unqueue(seqs) => {
						have = queue_rows!(open).keep_oks(Db.queue_of)
						left = have.keep_if(|item| !seqs.contains(item.seq))
						if exists!(open) and left.len() != have.len() {
							_ = FakeBase.write_with_parents!(queue_path(open), left.fold("", |t, item| "${t}${Db.queue_line(item)}\n"))
						}
						Ok({})
					}
					_ => {
						changed = apply(store, write)
						if changed.same {
							Ok({})
						} else {
							_ = FakeBase.write_with_parents!(FakeDb.store_path(open.path), Db.file_text({ format: open.format, facts: changed.facts, pinned: changed.pinned }))
							Ok({})
						}
					}
				}
			}
		}
	}
}

# The store of the db path. A missing file is a new store. A format that is larger than the format of the call is `TooNew`.
load! : Db.Open => Try({ facts : List(Db.Fact), pinned : List(Db.Pinned) }, Db.Err)
load! = |open| {
	text = FakeBase.read_or_empty!(FakeDb.store_path(open.path))
	match Db.parse_file(text) {
		Err(BadLine) => Err(Failed("the store file is not valid"))
		Ok(store) => if store.format > open.format Err(TooNew(store.format)) else Ok({ facts: store.facts, pinned: store.pinned })
	}
}

# Slice 213: the rows of `share_queue`, one for each line of `<dir>/share_queue.tsv`. The file db exists when its text file is not empty (a new file has the `format` line).
queue_path : Db.Open -> Str
queue_path = |open| "${FakeDb.store_path(open.path).drop_suffix("compat.tsv")}share_queue.tsv"

queue_rows! : Db.Open => List(Str)
queue_rows! = |open| FakeBase.lines(FakeBase.read_or_empty!(queue_path(open)))

# Slice 215 (R-SH3, R-SH4, R-TF7): the rows are added in order, each with the `seq` after the largest one in the file (1 for an empty file, as SQLite). A key (hash, nightly, target, talon_version) that is in the queue
# already stays as it is (also a repeat in the same call), and takes no `seq`. Then the oldest rows (the smallest `seq`, the first lines) are dropped until the queue has `cap` rows. No row: no change.
# A file that does not exist is made with the `format` line (the db has its tables), as the real `Fx`.
add_queue! : Db.Open, List(Db.Queued), U64 => Try({}, Db.Err)
add_queue! = |open, rows, cap| {
	if rows.is_empty() {
		Ok({})
	} else {
		if !exists!(open) {
			_ = FakeBase.write_with_parents!(FakeDb.store_path(open.path), Db.file_text({ format: open.format, facts: [], pinned: [] }))
		}
		same_key = |a, b| a.hash == b.hash and a.nightly == b.nightly and a.target == b.target and a.talon_version == b.talon_version
		have = queue_rows!(open).keep_oks(Db.queue_of)
		next = have.fold(0, |top, item| if item.seq > top item.seq else top) + 1
		added = rows.fold(
			{ items: have, next },
			|acc, row| if acc.items.any(|item| same_key(item.row, row)) acc else { items: acc.items.append({ seq: acc.next, row }), next: acc.next + 1 },
		)
		over = if added.items.len() > cap added.items.len() - cap else 0
		text = added.items.drop_first(over).fold("", |t, item| "${t}${Db.queue_line(item)}\n")
		_ = FakeBase.write_with_parents!(queue_path(open), text)
		Ok({})
	}
}

exists! : Db.Open => Bool
exists! = |open| !FakeBase.read_or_empty!(FakeDb.store_path(open.path)).is_empty()

# The primary key of `facts` (slice 032): the key and the used-closure digest. A check row has the digest "", so it has one row for each key.
same_row : Db.Fact, Db.Fact -> Bool
same_row = |a, b| a.hash == b.hash and a.nightly == b.nightly and a.target == b.target and a.closure == b.closure

# The rows after a write. `same` is true when no row changed.
apply : { facts : List(Db.Fact), pinned : List(Db.Pinned) }, Db.Write -> { facts : List(Db.Fact), pinned : List(Db.Pinned), same : Bool }
apply = |store, write| match write {
	Facts({ rows, existing }) => {
		kept = |f| rows.any(|r| same_row(r, f))
		facts = match existing {
			Replace => store.facts.keep_if(|f| !kept(f)).concat(rows)
			Keep => store.facts.concat(rows.keep_if(|r| !store.facts.any(|f| same_row(r, f))))
		}
		{ facts, pinned: store.pinned, same: rows.is_empty() }
	}
	Pinned(rows) => {
		fresh = rows.keep_if(|r| !store.pinned.any(|p| p.tag == r.tag and p.target == r.target))
		{ facts: store.facts, pinned: store.pinned.concat(fresh), same: fresh.is_empty() }
	}
	ClearQueue => { facts: store.facts, pinned: store.pinned, same: Bool.True }
	Queue(_) => { facts: store.facts, pinned: store.pinned, same: Bool.True }
	Unqueue(_) => { facts: store.facts, pinned: store.pinned, same: Bool.True }
}

# The rule of `fx/db` for the next call (the call number is the count of db calls in `calls.log` plus 1). No rule is the empty text.
next_call! : Str => Str
next_call! = |w| {
	log = FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log"))
	number = log.keep_if(|l| l.starts_with("db_query ") or l.starts_with("db_write ")).len() + 1
	rules = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/db")).keep_if(|l| !l.starts_with("#"))
	match rules.find_first(|l| l.starts_with("${number.to_str()}: ")) {
		Ok(line) => line.drop_prefix("${number.to_str()}: ")
		Err(_) => ""
	}
}

# The error that a rule gives. `format` is the format of the call: a `version` rule with a number that is not larger gives no error.
rule_err : Str, U64 -> Try({}, Db.Err)
rule_err = |rule, format| {
	if rule == "busy" {
		Err(Busy)
	} else if rule.starts_with("failed ") {
		Err(Failed(rule.drop_prefix("failed ")))
	} else if rule.starts_with("version ") {
		found = U64.from_str(rule.drop_prefix("version ")) ?? 0
		if found > format Err(TooNew(found)) else Ok({})
	} else {
		Ok({})
	}
}
