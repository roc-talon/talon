import Fail
import toml.Toml
import toml.Value

## The edits of `talon.toml` (Design 4.3, R-AD23 to R-AD28, R-UP11, R-WS14, R-NI1, R-CM3, R-CC7). Split from `Intent` (slice 031b). An edit changes only its own bytes, so comments, order and blank lines stay.
IntentEdit :: [].{

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

	## R-PA1, R-PA9, R-PA12 (slice 042): the edit of `talon.toml` that adds the `[patch]` entry of `alias`: `<alias> = { path = "<entry>", base = "<base>" }` (the form of R-PA9: an inline table, the key `path` first). The rules of `Toml.insert`:
	## the entry goes after the last entry of `[patch]` when the table is there, else a new `[patch]` table goes at the end of the text, after a blank line. All other bytes stay. The empty text (a `talon.toml` that Talon makes, R-PA1)
	## gives `[patch]` and the entry, in the form of R-PA9 (not the form `[patch.<alias>]` that `Toml.print` gives). A text with no line end at its end gets one first.
	##
	## | Case | Result |
	## | --- | --- |
	## | A text that is not TOML | The failure of `read` (kind `Input`, `<path>:<line>: not valid TOML`) |
	## | The key `alias` is in `[patch]` already | The entry is replaced where it is (`Toml.replace`). `tln patch` refuses a copy dir that exists before, so this is the case of a key with no dir (answer Q3) |
	add_patch : { path : Str, text : Str, alias : Str, entry : Str, base : Str } -> Try(Str, Fail)
	add_patch = |_x| crash "todo: slice 042"

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
			|k| match Toml.get(doc, [IntentEdit.table_name(k.table), k.key]) {
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
}

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
remove_key : Str, Toml, { table : IntentEdit.Table, key : Str } -> Try(Toml, Fail)
remove_key = |path, doc, k| match Toml.remove(doc, [IntentEdit.table_name(k.table), k.key]) {
	Ok(done) => Ok(done)
	Err(NoEntry) => Err(Fail.new(Internal, "${path}: the key '${k.key}' is not there"))
}
