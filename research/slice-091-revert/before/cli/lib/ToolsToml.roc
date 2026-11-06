import Fail
import Ident
import Ref
import Scope
import Text
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
	read_table : Toml -> { value : List(ToolsToml.Entry), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }
	read_table = |doc| match Toml.get(doc, ["tools"]) {
		Err(NotFound) => { value: [], issues: [], warnings: [] }
		Ok(Value.Table(t)) => {
			rows = t.to_list().map(|(key, value)| read_entry(doc, key, value)).sort_with(|a, b| TomlKeys.compare_lines(a.line, b.line))
			{
				value: rows.keep_oks(|r| r.entry),
				issues: rows.join_map(|r| r.issues),
				warnings: rows.join_map(|r| r.warnings),
			}
		}
		Ok(_) => { value: [], issues: [{ line: TomlKeys.key_line(doc, ["tools"]), message: "tools: must be a table" }], warnings: [] }
	}

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
			Ok(doc) => put_key(doc, facts.key, value).map_ok(|done| done.to_str()).map_err(|_| Fail.new(Input, "${facts.path}: the key tools.${facts.key} cannot be written"))
		}
	}

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
One : { line : U64, entry : Try(ToolsToml.Entry, [Bad]), issues : List(Note), warnings : List(Note) }

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
refused = |line, message| { line, entry: Err(Bad), issues: [{ line, message }], warnings: [] }

# The keys `ref` and `url` of an entry. Another key is a warning.
read_fields : Toml, Str, Dict(Str, Value), U64 -> One
read_fields = |doc, key, t, line| {
	at = |name| match Toml.line(doc, ["tools", key, name]) {
		Ok(n) => n
		Err(NoEntry) => line
	}
	unknown = Text.sorted(t.keys().keep_if(|k| k != "ref" and k != "url")).map(|k| { line: at(k), message: "unknown key tools.${key}.${k}" })
	fail = |name, why| { line, entry: Err(Bad), issues: [{ line: at(name), message: "tools.${key}.${name}: ${why}" }], warnings: unknown }
	good = |ref, url| { line, entry: Ok({ key, ref, url, line }), issues: [], warnings: unknown }
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
