import Clock
import Fail
import Pin
import Ranges
import Text
import toml.Toml
import toml.Value

## The intent of a project: the `talon.toml` (Design 4.3, R-I1 to R-I9, R-TF4, R-WS5). The file is read and edited with `roc-toml`
## (`Toml.parse`, `get`, `line`, `replace`, `insert`): an edit changes only its own bytes, so comments, order and blank lines stay.
##
## The tables and keys of P0:
##
## | Table | Key | Value | Field |
## | --- | --- | --- | --- |
## | `[toolchain]` | `roc` | `"*"`, `">=<id>"`, `"=<id>"` or a semver range (`Pin.parse_req`) | `toolchain.roc` |
## | `[toolchain]` | `nightly` | `true` or `false` (R-NS9) | `toolchain.nightly` |
## | `[dependencies]` | an alias | `"<range>"`, or `"<name>@<range>"` (R-I2) | `deps` |
## | `[overrides]` | an alias | the same value forms (R-OV1) | `overrides` |
## | `[resolution]` | `priority` | a list of aliases (R-VA6) | `resolution.priority` |
## | `[resolution]` | `strategy` | `"highest"` or `"lowest"` | `resolution.strategy` |
## | `[resolution]` | `min-release-age` | `"<n>d"`: a whole number of days (question Q10). `"0d"` turns it off (R-C7). | `resolution.min_release_age`, in seconds |
## | `[resolution]` | `snapshot` | `"log:<n>"` or an RFC 3339 UTC time (R-DT3, R-DT4) | `resolution.snapshot` |
## | `[resolution]` | `probe` | a table (P1: known, not read in P0) | |
## | `[workspace]` | `members` | a list of patterns (read by `Project.workspace_of`, slice 002) | |
## | `[audit]`, `[patch]` | any | P3 and P1: known tables, the content is not read in P0 | |
##
## `Dep`: `key` is the alias. `name` is the part before the `@` of the value (`Err(None)` when the value is a range only). `range` is the
## part after it. `line` is the 1-based line of the key. A value that has no `@` is the range text. A `@` splits at its first place.
Intent := {
	toolchain : { roc : Try(Pin.Req, [Unset]), roc_text : Try(Str, [Unset]), nightly : Try(Bool, [Unset]) },
	deps : List(Dep),
	overrides : List(Dep),
	resolution : {
		priority : Try(List(Str), [Unset]),
		strategy : Try([Highest, Lowest], [Unset]),
		min_release_age : Try(U64, [Unset]),
		snapshot : Try([Log(U64), Time(U64)], [Unset]),
	},
}.{
	is_eq : _

	Dep : { key : Str, name : Try(Str, [None]), range : Str, line : U64 }

	## The kind of a `talon.toml` in a project (R-WS5): `Standalone` (no `[workspace]` table anywhere on its project), `Root` (the file with
	## `[workspace]`), `Member` (another `talon.toml` of a workspace).
	Role : [Standalone, Root, Member]

	## Reads the text of a `talon.toml`. `path` is for the messages. The result has the intent and the warnings (R-TF4: an unknown key or table is a
	## warning and the command goes on).
	##
	## Allowed tables (R-WS5): `Standalone` and `Root`: `workspace`, `toolchain`, `resolution`, `audit`, `dependencies`, `overrides`, `patch`.
	## `Member`: `dependencies`, `overrides`, `patch` only.
	##
	## Failures have the kind `Input` (exit 19, R-EC19, R-TF4, R-WS5). The messages name the file and the line (a proposal, TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | Text that is not TOML | `<path>:<line>: not valid TOML` |
	## | A known table that the role does not allow (R-WS5). The line of the table. A `Standalone` file has no `workspace` table: the caller gives it the role `Root` | `<path>:<line>: the table [<name>] is not allowed in a workspace member file (it has only dependencies, overrides and patch)` |
	## | A known key with a value of the wrong type or form: a key of `[dependencies]` or `[overrides]` that is not a string, a range that `Ranges.check` refuses, a `[toolchain] roc` that `Pin.parse_req` refuses, a `nightly` that is not a boolean, a `strategy` that is not `highest` or `lowest`, a `min-release-age` that is not `<n>d`, a `snapshot` that is not `log:<n>` or a UTC time, a `priority` that is not a list of strings | `<path>:<line>: <table>.<key>: <why>` with `<why>` one of `must be a string`, `'<text>' is not a version range`, `'<text>' is not a compiler range`, `must be true or false`, `must be "highest" or "lowest"`, `must be a number of days, for example "2d"`, `must be "log:<n>" or a UTC time`, `must be a list of strings` |
	##
	## Warnings: `<path>:<line>: unknown table [<name>]` and `<path>:<line>: unknown key <table>.<key>`, in the order of the file.
	## Keys of `[dependencies]`, `[overrides]` and `[patch]` are never unknown. The warning for a `[resolution]` key other than the 5 above.
	read : { path : Str, text : Str, role : Role } -> Try({ intent : Intent, warnings : List(Str) }, Fail)
	read = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => {
			scan = read_tables(doc, facts.role, facts.text)
			match scan.issues.sort_with(|a, b| compare_lines(a.line, b.line)) {
				[first, ..] => Err(Fail.new(Input, "${facts.path}:${first.line.to_str()}: ${first.message}"))
				[] => Ok({ intent: scan.intent, warnings: scan.warnings.sort_with(|a, b| compare_lines(a.line, b.line)).map(|w| "${facts.path}:${w.line.to_str()}: ${w.message}") })
			}
		}
	}

	## The edit of `talon.toml` for the keys that Talon writes (R-AD23 to R-AD28, R-UP11, R-WS14): each `{ key, value }` sets `[dependencies] <key> = "<value>"`.
	## A key that is there gets a new string value (`Toml.replace`), so the comment on its line stays. A key that is not there is added after the last
	## entry of the table (`Toml.insert`), and the table is made when it is not there. The empty text gives a new file with the table. A key whose
	## value is the text already: no change. Else all other bytes stay. A text that is not TOML is the failure of `read` (kind `Input`).
	apply : { path : Str, text : Str, writes : List({ key : Str, value : Str }) } -> Try(Str, Fail)
	apply = |facts| if facts.writes.is_empty() {
		Ok(facts.text)
	} else {
		match Toml.parse(facts.text) {
			Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
			Ok(doc) => facts.writes.fold_try(doc, |current, w| write_key(facts.path, current, w)).map_ok(|done| done.to_str())
		}
	}

	## R-CC7: the text of the value of each key in `[dependencies]` (the text that `Toml.get` gives, printed with `Value.print`), `""` for a key that is not there,
	## in the order of `keys`. Used as the span texts for `Guard.check_all`.
	spans : { text : Str, keys : List(Str) } -> List(Str)
	spans = |facts| match Toml.parse(facts.text) {
		Ok(doc) => facts.keys.map(
			|key| match Toml.get(doc, ["dependencies", key]) {
				Ok(value) => Value.print(value)
				Err(NotFound) => ""
			},
		)
		Err(_) => facts.keys.map(|_| "")
	}

	## R-NI1, R-I8 (slice 007): the edit of `talon.toml` that renames stale keys. Each `{ from, to }` renames the key `from` of `[dependencies]` to `to` (a stale key of `[overrides]` is out of scope in slice 007). Only the bytes of the key change: the value, the comment on the line, the order and all other bytes stay (R-H1 style).
	## The key may be bare or quoted: the new key has the form of the old one. `Guard` gets the spans of `spans({ text, keys: <the from keys> })` (R-CC7).
	##
	## | Case | Result |
	## | --- | --- |
	## | A `from` key that is not in the file | Failure of kind `Internal`: `<path>: the key '<from>' is not there` |
	## | A `to` key that is already in the table | Failure of kind `Usage`: `<path>: the key '<to>' is already there` |
	## | A text that is not TOML | The failure of `read` (kind `Input`) |
	## | No rename | The text as it is |
	rename : { path : Str, text : Str, renames : List({ from : Str, to : Str }) } -> Try(Str, Fail)
	rename = |facts| if facts.renames.is_empty() {
		Ok(facts.text)
	} else {
		match Toml.parse(facts.text) {
			Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
			Ok(doc) => facts.renames.fold_try(doc, |current, r| rename_key(facts.path, current, r)).map_ok(|done| done.to_str())
		}
	}

	## A table of `talon.toml` whose keys are header aliases: `[dependencies]` (R-I2), `[overrides]` (R-OV1), `[patch]` (R-PA12). Slice 008.
	Table : [Dependencies, Overrides, Patch]

	## R-CM3, R-RV1, R-RV4 (slice 008): the edit of `talon.toml` that removes keys. Each `{ table, key }` removes the entry `key` of that table
	## (`Toml.remove`: the lines of the entry go, with the comment on its last line, and the comment lines above and the header of a table that becomes empty
	## stay). All other bytes stay. A `[patch]` entry is an inline table (`json = { path = "...", base = "..." }`): it goes whole. The order of the keys does not
	## change the result.
	##
	## | Case | Result |
	## | --- | --- |
	## | A key that is not in the table | Failure of kind `Internal`: `<path>: the key '<key>' is not there` |
	## | A text that is not TOML | The failure of `read` (kind `Input`) |
	## | No key | The text as it is |
	remove : { path : Str, text : Str, keys : List({ table : Table, key : Str }) } -> Try(Str, Fail)
	remove = |facts| if facts.keys.is_empty() {
		Ok(facts.text)
	} else {
		match Toml.parse(facts.text) {
			Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
			Ok(doc) => facts.keys.fold_try(doc, |current, k| remove_key(facts.path, current, k)).map_ok(|done| done.to_str())
		}
	}

	## R-CC7: the text of the value of each `{ table, key }` (the text that `Toml.get` gives, printed with `Value.print`), `""` for a key that is not there, in the order
	## of `keys`. The spans for `Guard.check_all` of a write that removes keys (`spans` has `[dependencies]` only).
	table_spans : { text : Str, keys : List({ table : Table, key : Str }) } -> List(Str)
	table_spans = |facts| match Toml.parse(facts.text) {
		Ok(doc) => facts.keys.map(
			|k| match Toml.get(doc, [Intent.table_name(k.table), k.key]) {
				Ok(value) => Value.print(value)
				Err(NotFound) => ""
			},
		)
		Err(_) => facts.keys.map(|_| "")
	}

	## The name of a `Table` in `talon.toml` and in the output: `dependencies`, `overrides`, `patch`.
	table_name : Table -> Str
	table_name = |table| match table {
		Dependencies => "dependencies"
		Overrides => "overrides"
		Patch => "patch"
	}

	## R-DT3: with `direct` there is no registry log, so a `log:<n>` snapshot is a failure of kind `Usage` (exit 2, R-EC2):
	## `snapshot log:<n> needs a registry: direct has no log. Use a UTC time, for example 2026-10-12T00:00:00Z.` A time is the cutoff for `Pick` (R-DT4). No snapshot: `Ok(Err(None))`.
	direct_snapshot : Try([Log(U64), Time(U64)], [Unset]) -> Try(Try(U64, [None]), Fail)
	direct_snapshot = |snapshot| match snapshot {
		Err(Unset) => Ok(Err(None))
		Ok(Time(seconds)) => Ok(Ok(seconds))
		Ok(Log(n)) => Err(Fail.new(Usage, "snapshot log:${n.to_str()} needs a registry: direct has no log. Use a UTC time, for example 2026-10-12T00:00:00Z."))
	}

	## R-PD6: the `talon.toml` files that can be the nearest one of a member, nearest first: the directory of the member file, each parent directory, up to `root` (the
	## workspace root, included). All paths are absolute and end with `/talon.toml`. A member whose directory is not under `root`: only the root file. The command reads
	## all of them with one `read_files!` and takes the first that exists.
	paths : { member : Str, root : Str } -> List(Str)
	paths = |facts| {
		dir = Text.dir_of(facts.member)
		prefix = if facts.root.ends_with("/") facts.root else "${facts.root}/"
		if dir == facts.root or dir.starts_with(prefix) {
			climb(dir, facts.root, [])
		} else {
			[Text.join(facts.root, "talon.toml")]
		}
	}
}

Note : { line : U64, message : Str }

Scan : { intent : Intent, issues : List(Note), warnings : List(Note) }

# `talon.toml` paths from the directory of the member up to the root (R-PD6).
climb : Str, Str, List(Str) -> List(Str)
climb = |dir, root, found| {
	next = found.append(Text.join(dir, "talon.toml"))
	if dir == root or dir.is_empty() next else climb(Text.dir_of(dir), root, next)
}

compare_lines : U64, U64 -> [Before, Same, After]
compare_lines = |a, b| if a < b Before else if a > b After else Same

cannot_write : Str, Str -> Fail
cannot_write = |path, key| Fail.new(Input, "${path}: the key dependencies.${key} cannot be written")

# One key of `[dependencies]`: a new string value, or no change when it is the text already.
write_key : Str, Toml, { key : Str, value : Str } -> Try(Toml, Fail)
write_key = |path, doc, w| match Toml.get(doc, ["dependencies", w.key]) {
	Ok(Value.String(old)) if old == w.value => Ok(doc)
	Ok(_) => Toml.replace(doc, ["dependencies", w.key], Value.String(w.value)).map_err(|_| cannot_write(path, w.key))
	Err(NotFound) => Toml.insert(doc, ["dependencies", w.key], Value.String(w.value)).map_err(|_| cannot_write(path, w.key))
}

# One stale key of `[dependencies]` gets its new name (`Toml.rename` changes only the bytes of the key).
rename_key : Str, Toml, { from : Str, to : Str } -> Try(Toml, Fail)
rename_key = |path, doc, r| match Toml.rename(doc, ["dependencies", r.from], r.to) {
	Ok(done) => Ok(done)
	Err(NoEntry) => Err(Fail.new(Internal, "${path}: the key '${r.from}' is not there"))
	Err(KeyExists) => Err(Fail.new(Usage, "${path}: the key '${r.to}' is already there"))
}

# One key of one table goes (`Toml.remove` takes the lines of the entry).
remove_key : Str, Toml, { table : Intent.Table, key : Str } -> Try(Toml, Fail)
remove_key = |path, doc, k| match Toml.remove(doc, [Intent.table_name(k.table), k.key]) {
	Ok(done) => Ok(done)
	Err(NoEntry) => Err(Fail.new(Internal, "${path}: the key '${k.key}' is not there"))
}

dependency_tables : List(Str)
dependency_tables = ["dependencies", "overrides", "patch"]

known_tables : List(Str)
known_tables = ["workspace", "toolchain", "resolution", "audit", "dependencies", "overrides", "patch"]

# R-TF4, R-WS5: the whole file. The issues are failures, the warnings go on.
read_tables : Toml, [Standalone, Root, Member], Str -> Scan
read_tables = |doc, role, text| {
	toolchain = read_toolchain(doc)
	resolution = read_resolution(doc)
	deps = read_deps(doc, "dependencies")
	overrides = read_deps(doc, "overrides")
	shape = check_tables(doc, role, text)
	{
		intent: {
			toolchain: toolchain.value,
			deps: deps.value,
			overrides: overrides.value,
			resolution: resolution.value,
		},
		issues: shape.issues.concat(toolchain.issues).concat(resolution.issues).concat(deps.issues).concat(overrides.issues),
		warnings: shape.warnings.concat(toolchain.warnings).concat(resolution.warnings),
	}
}

# A value of a known key, or the reason that it is wrong.
field : Toml, Str, Str, (Value -> Try(a, Str)) -> { value : Try(a, [Unset]), issues : List(Note) }
field = |doc, table, key, parse| match Toml.get(doc, [table, key]) {
	Err(NotFound) => { value: Err(Unset), issues: [] }
	Ok(found) => match parse(found) {
		Ok(parsed) => { value: Ok(parsed), issues: [] }
		Err(why) => { value: Err(Unset), issues: [{ line: key_line(doc, [table, key]), message: "${table}.${key}: ${why}" }] }
	}
}

key_line : Toml, List(Str) -> U64
key_line = |doc, path| match Toml.line(doc, path) {
	Ok(n) => n
	Err(NoEntry) => 1
}

# The keys of a table, in the order of their lines.
keys_of : Toml, Str -> List({ key : Str, value : Value, line : U64 })
keys_of = |doc, table| match Toml.get(doc, [table]) {
	Ok(Value.Table(t)) => t.to_list().map(|(key, value)| { key, value, line: key_line(doc, [table, key]) }).sort_with(|a, b| compare_lines(a.line, b.line))
	_ => []
}

unknown_keys : Toml, Str, List(Str) -> List(Note)
unknown_keys = |doc, table, known| keys_of(doc, table).keep_if(|k| !known.contains(k.key)).map(|k| { line: k.line, message: "unknown key ${table}.${k.key}" })

# The first line of the header of each table (`[name]`, `[name.sub]`, `[[name]]`).
header_lines : Str -> List((Str, U64))
header_lines = |text| text
	.split_on("\n")
	.map_with_index(|line, i| (line.trim(), i + 1))
	.keep_oks(
		|(line, n)| if line.starts_with("[") {
			inner = line.drop_prefix("[").drop_prefix("[")
			match inner.split_first("]") {
				Ok({ before, .. }) => match before.split_on(".").first() {
					Ok(name) => Ok((name.trim().replace_each("\"", ""), n))
					Err(_) => Err(NotHeader)
				}
				Err(_) => Err(NotHeader)
			}
		} else {
			Err(NotHeader)
		},
	)

# R-WS5, R-TF4: the tables of the file. A known table that the role does not allow is a failure. An unknown table or key is a warning.
check_tables : Toml, [Standalone, Root, Member], Str -> { issues : List(Note), warnings : List(Note) }
check_tables = |doc, role, text| {
	headers = header_lines(text)
	table_line = |name| match headers.find_first(|(h, _)| h == name) {
		Ok((_, n)) => n
		Err(_) => 1
	}
	rows = Toml.table(doc).to_list().map(
		|(name, value)| match value {
			Value.Table(_) => if !known_tables.contains(name) {
				{ issues: [], warnings: [{ line: table_line(name), message: "unknown table [${name}]" }] }
			} else if role == Member and !dependency_tables.contains(name) {
				{ issues: [{ line: table_line(name), message: "the table [${name}] is not allowed in a workspace member file (it has only dependencies, overrides and patch)" }], warnings: [] }
			} else {
				{ issues: [], warnings: [] }
			}
			_ => { issues: [], warnings: [{ line: key_line(doc, [name]), message: "unknown key ${name}" }] }
		},
	)
	{ issues: rows.join_map(|r| r.issues), warnings: rows.join_map(|r| r.warnings) }
}

read_toolchain : Toml -> { value : { roc : Try(Pin.Req, [Unset]), roc_text : Try(Str, [Unset]), nightly : Try(Bool, [Unset]) }, issues : List(Note), warnings : List(Note) }
read_toolchain = |doc| {
	roc = field(
		doc,
		"toolchain",
		"roc",
		|v| match v {
			Value.String(text) => Pin.parse_req(text).map_err(|BadReq| "'${text}' is not a compiler range")
			_ => Err("must be a string")
		},
	)
	nightly = field(
		doc,
		"toolchain",
		"nightly",
		|v| match v {
			Value.Boolean(b) => Ok(b)
			_ => Err("must be true or false")
		},
	)
	roc_text = match (roc.value, Toml.get(doc, ["toolchain", "roc"])) {
		(Ok(_), Ok(Value.String(text))) => Ok(text)
		_ => Err(Unset)
	}
	{
		value: { roc: roc.value, roc_text, nightly: nightly.value },
		issues: roc.issues.concat(nightly.issues),
		warnings: unknown_keys(doc, "toolchain", ["roc", "nightly"]),
	}
}

# `"<n>d"`: a whole number of days, in seconds (Q10).
days_of : Str -> Try(U64, [NotDays])
days_of = |text| match text.split_last("d") {
	Ok({ before, after }) if after.is_empty() and !before.is_empty() => U64.from_str(before).map_ok(|n| n * 86400).map_err(|_| NotDays)
	_ => Err(NotDays)
}

read_snapshot : Value -> Try([Log(U64), Time(U64)], Str)
read_snapshot = |v| {
	bad = "must be \"log:<n>\" or a UTC time"
	text = match v {
		Value.String(s) => Ok(s)
		Value.OffsetDateTime(_) => Ok(Value.print(v))
		_ => Err(bad)
	}?
	if text.starts_with("log:") {
		U64.from_str(text.drop_prefix("log:")).map_ok(|n| Log(n)).map_err(|_| bad)
	} else {
		Clock.parse_utc(text).map_ok(|t| Time(t)).map_err(|BadTime| bad)
	}
}

read_resolution : Toml -> { value : { priority : Try(List(Str), [Unset]), strategy : Try([Highest, Lowest], [Unset]), min_release_age : Try(U64, [Unset]), snapshot : Try([Log(U64), Time(U64)], [Unset]) }, issues : List(Note), warnings : List(Note) }
read_resolution = |doc| {
	priority = field(
		doc,
		"resolution",
		"priority",
		|v| match v {
			Value.Array(items) => items.map_try(
				|item| match item {
					Value.String(s) => Ok(s)
					_ => Err("must be a list of strings")
				},
			)
			_ => Err("must be a list of strings")
		},
	)
	strategy = field(
		doc,
		"resolution",
		"strategy",
		|v| match v {
			Value.String("highest") => Ok(Highest)
			Value.String("lowest") => Ok(Lowest)
			_ => Err("must be \"highest\" or \"lowest\"")
		},
	)
	age = field(
		doc,
		"resolution",
		"min-release-age",
		|v| match v {
			Value.String(text) => days_of(text).map_err(|NotDays| "must be a number of days, for example \"2d\"")
			_ => Err("must be a number of days, for example \"2d\"")
		},
	)
	snapshot = field(doc, "resolution", "snapshot", read_snapshot)
	{
		value: { priority: priority.value, strategy: strategy.value, min_release_age: age.value, snapshot: snapshot.value },
		issues: priority.issues.concat(strategy.issues).concat(age.issues).concat(snapshot.issues),
		warnings: unknown_keys(doc, "resolution", ["priority", "strategy", "min-release-age", "snapshot", "probe"]),
	}
}

# R-I2: `<range>` or `<name>@<range>`, split at the first `@`.
read_deps : Toml, Str -> { value : List(Intent.Dep), issues : List(Note) }
read_deps = |doc, table| {
	rows = keys_of(doc, table).map(
		|k| match k.value {
			Value.String(text) => {
				(name, range) = match text.split_first("@") {
					Ok({ before, after }) => (Ok(before), after)
					Err(NotFound) => (Err(None), text)
				}
				match Ranges.check(range) {
					Ok({}) => Ok({ key: k.key, name, range, line: k.line })
					Err(BadRange) => Err({ line: k.line, message: "${table}.${k.key}: '${range}' is not a version range" })
				}
			}
			_ => Err({ line: k.line, message: "${table}.${k.key}: must be a string" })
		},
	)
	{ value: rows.keep_oks(|r| r), issues: rows.keep_errs(|r| r) }
}
