import Fail
import TomlKeys
import toml.Toml
import toml.Value

## Slice 238 (R-CH1, R-CH2, R-CH3, R-CH10): the channel tables. A user channel is a table `[channels.<name>]` in `config.toml` and in the root `talon.toml`.
## This module holds the pure decisions: the name rules, the built-in table, the read of the tables of one file, and the equality of the two files.
Channel :: [].{

	## One user table as read: the name, the line of its header, and the values of its keys. A key that is not in the file is `Err(Unset)`.
	Table : { name : Str, line : U64, shape : Try(Str, [Unset]), source : Try(Str, [Unset]), tag_prefix : Try(Str, [Unset]) }

	## R-CH3: the syntax of a name first (`[a-z][a-z0-9-]*`, 2 to 24 characters, no `-` at the end), then the reserved list.
	name_check : Str -> Try({}, [BadName, Reserved])
	name_check = |name| {
		bytes = name.to_utf8()
		first_ok = match bytes.first() {
			Ok(b) => is_lower(b)
			Err(_) => Bool.False
		}
		last_ok = match bytes.last() {
			Ok(b) => b != '-'
			Err(_) => Bool.False
		}
		if first_ok and last_ok and bytes.len() >= 2 and bytes.len() <= 24 and bytes.all(|b| is_lower(b) or is_digit(b) or b == '-') {
			if reserved.contains(name) Err(Reserved) else Ok({})
		} else {
			Err(BadName)
		}
	}

	## R-CH2: the built-in tables. Only `nightly` has one. A reserved name with no table (`stable`) gives `NotBuiltIn`.
	builtin : Str -> Try({ shape : Str, source : Str, tag_prefix : Str }, [NotBuiltIn])
	builtin = |name| if name == "nightly" Ok({ shape: "github-release", source: "roc-lang/nightlies", tag_prefix: "nightly-" }) else Err(NotBuiltIn)

	## The shapes that this tln knows (R-CH10). A word that is not here is a value that a newer tln may know (R-TF8).
	shapes : List(Str)
	shapes = ["github-release"]

	## R-TF8, Design Q613 items 1 and 2: a reserved name, a bad name and a missing key are not a value of a known key, so its failure has no hint line.
	hintless : Str -> Bool
	hintless = |message| message.ends_with("is a reserved channel name") or message.ends_with("is not a channel name") or message.contains(": missing key ")

	## R-CH10: the tables `[channels.<name>]` of one parsed file. `issues` are failures (the caller sorts them by line), `warnings` go on (an unknown key).
	read : Toml, Str -> { tables : List(Table), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }
	read = |doc, text| {
		rows = names_of(doc, text).map(|name| read_one(doc, text, name))
		{ tables: rows.keep_oks(|r| r.table), issues: not_tables(doc).concat(rows.join_map(|r| r.issues)), warnings: rows.join_map(|r| r.warnings) }
	}

	## R-CH10: a name in both files must have equal tables, else exit 19. The check compares the known keys (the order and the spaces of the file do not count).
	## A text that is not TOML has no tables here: the read of that file gives the failure.
	## Design Q613 item 5: the unknown keys are not part of the table.
	compare : { talon : { path : Str, text : Str }, config : { path : Str, text : Str } } -> Try({}, Fail)
	compare = |x| match (Toml.parse(x.talon.text), Toml.parse(x.config.text)) {
		(Ok(a), Ok(b)) => {
			mine = read(a, x.talon.text).tables
			theirs = read(b, x.config.text).tables
			differ = mine.keep_oks(
				|t| match theirs.find_first(|u| u.name == t.name) {
					Ok(u) => if same(t, u) Err(Equal) else Ok((t, u))
					Err(_) => Err(Equal)
				},
			)
			match differ {
				[(t, u), ..] => Err(Fail.new(Input, "${x.talon.path}:${t.line.to_str()}: channels.${t.name} is not equal to channels.${t.name} in ${x.config.path}:${u.line.to_str()}"))
				[] => Ok({})
			}
		}
		_ => Ok({})
	}
}

reserved : List(Str)
reserved = ["nightly", "stable", "git", "link", "copy", "zig", "debug", "local", "compat"]

table_keys : List(Str)
table_keys = ["shape", "source", "tag-prefix"]

is_lower : U8 -> Bool
is_lower = |b| b >= 'a' and b <= 'z'

is_digit : U8 -> Bool
is_digit = |b| b >= '0' and b <= '9'

same : Channel.Table, Channel.Table -> Bool
same = |a, b| a.shape == b.shape and a.source == b.source and a.tag_prefix == b.tag_prefix

# The names under `[channels]`, in the order of their lines. An entry that is not a table gives no name (`not_tables` gives its fault).
names_of : Toml, Str -> List(Str)
names_of = |doc, text| match Toml.get(doc, ["channels"]) {
	Ok(Value.Table(t)) => t.to_list().keep_oks(
		|(name, value)| match value {
			Value.Table(_) => Ok((name, header_line(doc, text, name)))
			_ => Err(NotTable)
		},
	).sort_with(|(_, a), (_, b)| TomlKeys.compare_lines(a, b)).map(|(name, _)| name)
	_ => []
}

# Design Q613 item 7: `channels` that is not a table, or an entry that is not a table, is a fault (with the R-TF8 hint).
not_tables : Toml -> List(TomlKeys.Note)
not_tables = |doc| match Toml.get(doc, ["channels"]) {
	Ok(Value.Table(t)) => t.to_list().keep_oks(
		|(name, value)| match value {
			Value.Table(_) => Err(IsTable)
			_ => Ok({ line: TomlKeys.key_line(doc, ["channels", name]), message: "channels.${name}: must be a table" })
		},
	)
	Ok(_) => [{ line: TomlKeys.key_line(doc, ["channels"]), message: "channels: must be a table" }]
	Err(_) => []
}

# One table. A reserved name or a bad name is the only fault of its table (Design Q613 items 1 and 2: the line of the header). A missing key is a fault too.
read_one : Toml, Str, Str -> { table : Try(Channel.Table, [Skipped]), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }
read_one = |doc, text, name| {
	line = header_line(doc, text, name)
	match Channel.name_check(name) {
		Err(Reserved) => { table: Err(Skipped), issues: [{ line, message: "channels.${name}: '${name}' is a reserved channel name" }], warnings: [] }
		Err(BadName) => { table: Err(Skipped), issues: [{ line, message: "channels.${name}: '${name}' is not a channel name" }], warnings: [] }
		Ok({}) => {
			shape = text_key(doc, name, "shape", |word| if Channel.shapes.contains(word) Ok(word) else Err("'${word}' is not a channel shape"))
			source = text_key(doc, name, "source", |word| Ok(word))
			# Design Q613 item 6: the shape (slice 239) checks the forms of `source` and `tag-prefix`. Here they are only strings.
			prefix = text_key(doc, name, "tag-prefix", |word| Ok(word))
			unknown = match Toml.get(doc, ["channels", name]) {
				Ok(Value.Table(t)) => t.keys().keep_if(|k| !table_keys.contains(k)).map(|k| { line: TomlKeys.key_line(doc, ["channels", name, k]), message: "unknown key channels.${name}.${k}" })
				_ => []
			}
			# Design Q613 item 1: a missing key is a fault on the line of the header, with no hint.
			missing = table_keys.keep_oks(
				|key| match Toml.get(doc, ["channels", name, key]) {
					Err(NotFound) => Ok({ line, message: "channels.${name}: missing key ${key}" })
					Ok(_) => Err(Present)
				},
			)
			{
				table: Ok({ name, line, shape: shape.value, source: source.value, tag_prefix: prefix.value }),
				issues: shape.issues.concat(source.issues).concat(prefix.issues).concat(missing),
				warnings: unknown,
			}
		}
	}
}

# A key of a channel table that must be a string, or the reason that it is wrong.
text_key : Toml, Str, Str, (Str -> Try(Str, Str)) -> { value : Try(Str, [Unset]), issues : List(TomlKeys.Note) }
text_key = |doc, name, key, check| match Toml.get(doc, ["channels", name, key]) {
	Err(NotFound) => { value: Err(Unset), issues: [] }
	Ok(found) => {
		checked = match found {
			Value.String(text) => check(text)
			_ => Err("must be a string")
		}
		match checked {
			Ok(text) => { value: Ok(text), issues: [] }
			Err(why) => { value: Err(Unset), issues: [{ line: TomlKeys.key_line(doc, ["channels", name, key]), message: "channels.${name}.${key}: ${why}" }] }
		}
	}
}

# The line of the header `[channels.<name>]`. The parser has no entry for a header, so the text is searched. A table with no such header (a dotted key) gives the line of the key `channels`.
header_line : Toml, Str, Str -> U64
header_line = |doc, text, name| {
	header = "[channels.${name}]"
	found = text.split_on("\n").map_with_index(|line, i| (line.trim(), i + 1)).find_first(|(line, _)| line == header)
	match found {
		Ok((_, n)) => n
		Err(_) => TomlKeys.key_line(doc, ["channels"])
	}
}
