import Fail
import Ident
import Ref
import Scope
import Text
import ToolBin
import TomlKeys
import toml.Toml
import toml.Value

## The `[tools]` table of `talon.toml` (slice 056, CLI 6.4: R-PT1, R-PT2, R-PT3, R-PT5, R-TF4, R-CC7). Part A (pure, TESTING.md 2.2). `Intent.read` calls `read_table` (R-PT1: a form that is not valid is exit code 19, R-TF4), the commands
## call `put`, `drop` and `spans` for the edits. An edit changes only its own bytes (the file is edited with `roc-toml`), so the comments, the order and the blank lines of the file stay.
##
## One entry is an inline table with the key `ref` (required) and the key `url` (optional, because `tln install` writes it, R-PT5):
##
## ```toml
## [tools]
## roc-cfw = { ref = "Karakatiza666/roc-cloudflare-workers-cli@^1", url = "https://github.com/.../releases/download/1.0.3/<hash>.tar.zst" }
## ```
ToolsToml :: [].{

	## One entry of `[tools]`: the key (the name of the program in a step), the `ref` text as written, the `url` text as written (`Err(Unset)` when the entry has none), and the 1-based line of the key.
	Entry : { key : Str, ref : Str, url : Try(Str, [Unset]), line : U64 }

	## R-PT1: is the text a key of `[tools]`? The form is `[a-z0-9][a-z0-9._-]*`: lower case letters, digits, `.`, `_` and `-`, and it starts with a letter or a digit.
	is_key : Str -> Bool
	is_key = |text| match text.to_utf8() {
		[first, .. as rest] => key_head(first) and rest.all(|b| key_head(b) or b == '.' or b == '_' or b == '-')
		[] => Bool.False
	}

	## R-PT1, R-TF4: the entries of the table `[tools]` of a parsed document, in the order of their lines. No table gives no entry. `issues` are failures of kind `Input` (exit 19): the read of `Intent` takes the first one by line, as for the other tables. `warnings` do not stop the command.
	## The form of the messages is `<table>.<key>...: <why>` (`Intent.read` puts `<path>:<line>: ` before it). The texts are proposals (TW24):
	##
	## | Case | Message | Kind of note |
	## | --- | --- | --- |
	## | `[tools]` is not a table | `tools: must be a table` | issue |
	## | The key is not `is_key` | `tools.<key>: the key is not a tool name (lower case letters, digits, '.', '_' and '-', and the first one a letter or a digit)` | issue |
	## | The value is not a table | `tools.<key>: must be a table with ref and url` | issue |
	## | No `ref`, or a `ref` that is not a string | `tools.<key>.ref: must be a string` | issue |
	## | `ref` is not `Ref.parse` with the scope `Tool` | `tools.<key>.ref: <the failure message of Ref.parse>` | issue |
	## | `ref` is not a full name `owner/app` | `tools.<key>.ref: '<name>' is not an owner/app name` | issue |
	## | `ref` has a selector other than a version, a range or `latest` (a git sha, a compiler) | `tools.<key>.ref: '<selector text>' is not a release selector (a version, a range or latest)` | issue |
	## | `url` is not a string | `tools.<key>.url: must be a string` | issue |
	## | `url` is not a release URL (`Ident.of_url` fails) | `tools.<key>.url: '<url>' is not a release URL with a version and a hash` | issue |
	## | Another key of the entry | `unknown key tools.<key>.<name>` | warning |
	##
	## A `ref` with no selector and `@latest` are the same (R-PT1, R-T26). The `url` text is not compared with the `ref` here: that is R-PT7 (`ToolsPlan.frozen_check`).
	## Slice 091 (R-PT18): `bins` has one row for each entry that has the key `bin`, in the order of the entries: `false` is `Off`, a table is `Hashes` (in the text order of the targets). The key `bin` is no unknown key (no warning). A `bin` of another form is an issue of the entry (exit code 19, R-PT1, R-PT18).
	## The texts are proposals (TW24): `tools.<key>.bin: must be a table of target hashes, or false`, `tools.<key>.bin.<target>: not a target (arm64mac, arm64musl, x64mac, x64musl, x64win)`, `tools.<key>.bin.<target>: must be 64 lower case hex digits`.
	read_table : Toml -> { value : List(ToolsToml.Entry), bins : List({ key : Str, bin : ToolBin.Lock }), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }
	read_table = |doc| match Toml.get(doc, ["tools"]) {
		Err(NotFound) => { value: [], bins: [], issues: [], warnings: [] }
		Ok(Value.Table(t)) => {
			rows = t.to_list().map(|(key, value)| read_entry(doc, key, value)).sort_with(|a, b| TomlKeys.compare_lines(a.line, b.line))
			{
				value: rows.keep_oks(|r| r.entry),
				bins: rows.keep_oks(|r| r.bin),
				issues: rows.join_map(|r| r.issues),
				warnings: rows.join_map(|r| r.warnings),
			}
		}
		Ok(_) => { value: [], bins: [], issues: [{ line: TomlKeys.key_line(doc, ["tools"]), message: "tools: must be a table" }], warnings: [] }
	}

	## Slice 091, R-PT19, R-PT25: `put` also keeps `bin = false` of the entry that it replaces (no command changes or removes it), and drops a `bin` table of that entry (it belongs to the old `url`).
	## R-PT3, R-PT5: the text with the entry `<key> = { ref = "<ref>", url = "<url>" }` (the key `ref` first). The entry of `key` that is there is replaced where it is (the comment on its line stays). A new key goes after the last entry of `[tools]`. With no table, a new `[tools]` table goes
	## at the end of the text, after a blank line. The empty text gives `[tools]`, the entry, and the line end (not the form `[tools.<key>]`). A text with no line end at its end gets one first. All other bytes stay.
	##
	## | Case | Result |
	## | --- | --- |
	## | A text that is not TOML | Failure of kind `Input`: `<path>:<line>: not valid TOML` |
	## | The entry cannot be written (`tools` is a value that is not a table) | Failure of kind `Input`: `<path>: the key tools.<key> cannot be written` |
	put : { path : Str, text : Str, key : Str, ref : Str, url : Str } -> Try(Str, Fail)
	put = |facts| {
		value = Value.Table(Dict.from_list([("ref", Value.String(facts.ref)), ("url", Value.String(facts.url))]))
		if facts.text == "" {
			return Ok("[tools]\n${key_text(facts.key)} = ${Value.print(value)}\n")
		}
		match Toml.parse(facts.text) {
			Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
			Ok(doc) => put_key(doc, facts.key, keep_off(doc, facts.key, value)).map_ok(|done| done.to_str()).map_err(|_| Fail.new(Input, "${facts.path}: the key tools.${facts.key} cannot be written"))
		}
	}

	## R-PT18, R-PT19: the text with `bin = { <target> = "<sha256>", ... }` in the entry `key` (an entry that is there). The table has the keys in the order of the list (the list is in text order), as one inline table in the entry (`{ ref = "...", url = "...", bin = { x64musl = "..." } }`). A `bin` of the entry that is there is replaced (also `false`: the caller never asks). The empty list gives `bin = {}`.
	## All other bytes stay. A key that is not in `[tools]` is a failure of kind `Internal`: `<path>: the key '<key>' is not there`. A text that is not TOML is a failure of kind `Input`: `<path>:<line>: not valid TOML`.
	put_bin : { path : Str, text : Str, key : Str, bin : List(ToolBin.Hash) } -> Try(Str, Fail)
	put_bin = |facts| edit_bin(facts.path, facts.text, facts.key, |fields| fields.concat([("bin", bin_value(facts.bin))]))

	## Slice 091, R-PT19: the text without the key `bin` of the entry `key` (a table, not `false`). Nothing to remove gives the text as it is. Same failures as `put_bin`.
	drop_bin : { path : Str, text : Str, key : Str } -> Try(Str, Fail)
	drop_bin = |facts| edit_bin(facts.path, facts.text, facts.key, |fields| fields)

	## R-PT3: the text without the entries `keys` of `[tools]` (`Toml.remove`: the lines of the entry go, with the comment on its last line; the comment lines above and the header of a table that becomes empty stay). All other bytes stay.
	##
	## | Case | Result |
	## | --- | --- |
	## | A key that is not in `[tools]` | Failure of kind `Internal`: `<path>: the key '<key>' is not there` |
	## | A text that is not TOML | Failure of kind `Input`: `<path>:<line>: not valid TOML` |
	## | No key | The text as it is |
	drop : { path : Str, text : Str, keys : List(Str) } -> Try(Str, Fail)
	drop = |facts| if facts.keys.is_empty() {
		Ok(facts.text)
	} else {
		match Toml.parse(facts.text) {
			Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
			Ok(doc) => facts.keys.fold_try(doc, |current, key| drop_key(facts.path, current, key)).map_ok(|done| done.to_str())
		}
	}

	## R-PT1: the full name `owner/app` of a `ref` (the text before the first `@`).
	app_of : Str -> Str
	app_of = |ref| match ref.split_first("@") {
		Ok({ before, .. }) => before
		Err(_) => ref
	}

	## R-CC7: the text of the value of each key in `[tools]` (the text that `Toml.get` gives, printed with `Value.print`), `""` for a key that is not there, in the order of `keys`. They are the span texts for `Guard.check_all`.
	spans : { text : Str, keys : List(Str) } -> List(Str)
	spans = |facts| match Toml.parse(facts.text) {
		Ok(doc) => facts.keys.map(
			|key| match Toml.get(doc, ["tools", key]) {
				Ok(value) => Value.print(value)
				Err(NotFound) => ""
			},
		)
		Err(_) => facts.keys.map(|_| "")
	}
}

Note : TomlKeys.Note

# One entry of the table, read: the entry (or `Bad`), its issues and warnings, and the line of its key.
One : { line : U64, entry : Try(ToolsToml.Entry, [Bad]), bin : Try({ key : Str, bin : ToolBin.Lock }, [Unset]), issues : List(Note), warnings : List(Note) }

# The characters that start a key and the first group of the others: `a-z` and `0-9`.
key_head : U8 -> Bool
key_head = |b| (b >= 'a' and b <= 'z') or (b >= '0' and b <= '9')

# A key in the form of the text of a table: bare when it has letters, digits, `_` and `-` only, else quoted.
key_text : Str -> Str
key_text = |key| if key.to_utf8().all(|b| key_head(b) or b == '_' or b == '-') key else "\"${key}\""

# A new key is inserted, a key that is there is replaced in place.
put_key : Toml, Str, Value -> Try(Toml, [Unwritable])
put_key = |doc, key, value| match Toml.get(doc, ["tools", key]) {
	Ok(_) => Toml.replace(doc, ["tools", key], value).map_err(|_| Unwritable)
	Err(NotFound) => Toml.insert(doc, ["tools", key], value).map_err(|_| Unwritable)
}

# One key of `[tools]` goes (`Toml.remove` takes the lines of the entry).
drop_key : Str, Toml, Str -> Try(Toml, Fail)
drop_key = |path, doc, key| match Toml.remove(doc, ["tools", key]) {
	Ok(done) => Ok(done)
	Err(NoEntry) => Err(Fail.new(Internal, "${path}: the key '${key}' is not there"))
}

# R-PT1, R-TF4: one entry of the table. The first problem of an entry is its one issue.
read_entry : Toml, Str, Value -> One
read_entry = |doc, key, value| {
	line = TomlKeys.key_line(doc, ["tools", key])
	if !ToolsToml.is_key(key) {
		return refused(line, "tools.${key}: the key is not a tool name (lower case letters, digits, '.', '_' and '-', and the first one a letter or a digit)")
	}
	match value {
		Value.Table(t) => read_fields(doc, key, t, line)
		_ => refused(line, "tools.${key}: must be a table with ref and url")
	}
}

refused : U64, Str -> One
refused = |line, message| { line, entry: Err(Bad), bin: Err(Unset), issues: [{ line, message }], warnings: [] }

# The keys `ref` and `url` of an entry. Another key is a warning.
read_fields : Toml, Str, Dict(Str, Value), U64 -> One
read_fields = |doc, key, t, line| {
	at = |name| match Toml.line(doc, ["tools", key, name]) {
		Ok(n) => n
		Err(NoEntry) => line
	}
	unknown = Text.sorted(t.keys().keep_if(|k| k != "ref" and k != "url" and k != "bin")).map(|k| { line: at(k), message: "unknown key tools.${key}.${k}" })
	fail = |name, why| { line, entry: Err(Bad), bin: Err(Unset), issues: [{ line: at(name), message: "tools.${key}.${name}: ${why}" }], warnings: unknown }
	good = |ref, url| match read_bin(t) {
		Err({ name, why }) => fail(name, why)
		Ok(lock) => { line, entry: Ok({ key, ref, url, line }), bin: lock.map_ok(|b| { key, bin: b }), issues: [], warnings: unknown }
	}
	match t.get("ref") {
		Ok(Value.String(ref)) => match check_ref(ref) {
			Err(why) => fail("ref", why)
			Ok({}) => match t.get("url") {
				Err(_) => good(ref, Err(Unset))
				Ok(Value.String(url)) => match Ident.of_url(url) {
					Ok(_) => good(ref, Ok(url))
					Err(Foreign) => fail("url", "'${url}' is not a release URL with a version and a hash")
				}
				Ok(_) => fail("url", "must be a string")
			}
		}
		_ => fail("ref", "must be a string")
	}
}

# R-PT1: a `ref` is `owner/app` with no selector, or a version, a range or `latest`.
check_ref : Str -> Try({}, Str)
check_ref = |ref| match Ref.parse(ref, Scope.Tool, Bool.False) {
	Err(fail) => Err(fail.message)
	Ok(parsed) => match parsed.form {
		Full => match parsed.selector {
			Ok(GitSha(_)) | Ok(GitRef(_)) => Err("'${selector_text(ref)}' is not a release selector (a version, a range or latest)")
			_ => Ok({})
		}
		_ => Err("'${parsed.name}' is not an owner/app name")
	}
}

# The text after the first `@`.
selector_text : Str -> Str
selector_text = |ref| match ref.split_first("@") {
	Ok({ after, .. }) => after
	Err(_) => ""
}

# R-PT19: `put` keeps `bin = false` of the entry that it replaces, and drops a `bin` table.
keep_off : Toml, Str, Value -> Value
keep_off = |doc, key, value| match (value, Toml.get(doc, ["tools", key, "bin"])) {
	(Value.Table(t), Ok(Value.Boolean(b))) if !b => Value.Table(t.insert("bin", Value.Boolean(Bool.False)))
	_ => value
}

# R-PT18: the value of a `bin` table.
bin_value : List(ToolBin.Hash) -> Value
bin_value = |hashes| Value.Table(Dict.from_list(hashes.map(|h| (h.target, Value.String(h.sha256)))))

# R-PT18, R-PT19: the entry `key` with its fields changed by `change`. The key `bin` goes first, `change` can add it again.
edit_bin : Str, Str, Str, (List((Str, Value)) -> List((Str, Value))) -> Try(Str, Fail)
edit_bin = |path, text, key, change| match Toml.parse(text) {
	Err(TomlErr(e)) => Err(Fail.new(Input, "${path}:${e.line.to_str()}: not valid TOML"))
	Ok(doc) => match Toml.get(doc, ["tools", key]) {
		Ok(Value.Table(t)) => {
			kept = t.to_list().keep_if(|(name, _)| name != "bin")
			fields = change(kept)
			Toml.replace(doc, ["tools", key], Value.Table(Dict.from_list(fields))).map_ok(|done| done.to_str()).map_err(|_| Fail.new(Internal, "${path}: the key '${key}' is not there"))
		}
		_ => Err(Fail.new(Internal, "${path}: the key '${key}' is not there"))
	}
}

# R-PT18: the key `bin` of an entry. A missing key is `Ok(Err(Unset))`, another form is the name and the reason of the issue.
read_bin : Dict(Str, Value) -> Try(Try(ToolBin.Lock, [Unset]), { name : Str, why : Str })
read_bin = |t| match t.get("bin") {
	Err(_) => Ok(Err(Unset))
	Ok(Value.Boolean(b)) => if b Err({ name: "bin", why: bin_form }) else Ok(Ok(Off))
	Ok(Value.Table(bt)) => match Text.sorted(bt.keys()).find_first(|k| !ToolBin.all_targets.contains(k)) {
		Ok(k) => Err({ name: "bin.${k}", why: "not a target (arm64mac, arm64musl, x64mac, x64musl, x64win)" })
		Err(_) => read_hashes(bt)
	}
	Ok(_) => Err({ name: "bin", why: bin_form })
}

bin_form = "must be a table of target hashes, or false"

# The values of a `bin` table, in the text order of the targets.
read_hashes : Dict(Str, Value) -> Try(Try(ToolBin.Lock, [Unset]), { name : Str, why : Str })
read_hashes = |bt| {
	rows = ToolBin.all_targets.keep_oks(|target| bt.get(target).map_ok(|v| (target, v)))
	bad = rows.find_first(
		|(_, v)| match v {
			Value.String(s) => !ToolBin.is_sha256(s)
			_ => Bool.True
		},
	)
	match bad {
		Ok((target, _)) => Err({ name: "bin.${target}", why: "must be 64 lower case hex digits" })
		Err(_) => Ok(
			Ok(
				Hashes(
					rows.keep_oks(
						|(target, v)| match v {
							Value.String(sha256) => Ok({ target, sha256 })
							_ => Err(Skip)
						},
					),
				),
			),
		)
	}
}
