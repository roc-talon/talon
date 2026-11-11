import Fail
import Selector
import Text
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
			# Design Q614 item 4: a reserved word, or a reserved word and `-` at the start, is a reserved name.
			if reserved.contains(name) or reserved.any(|word| name.starts_with("${word}-")) Err(Reserved) else Ok({})
		} else {
			Err(BadName)
		}
	}

	## R-CH4, Design Q614 item 1: the form of `source`: `owner/repo`, 2 parts of `A-Z a-z 0-9 . _ -`. No part starts with `.`, the repo does not end with `.git`.
	source_check : Str -> Try({}, [BadSource])
	source_check = |text| match text.split_on("/") {
		[owner, repo] if good_part(owner) and good_part(repo) and !repo.ends_with(".git") => Ok({})
		_ => Err(BadSource)
	}

	## R-CH4, Design Q614 item 2: the form of `tag-prefix`: 1 to 40 characters of `a-z 0-9 . _ -`, and the last one is `-`.
	tag_prefix_check : Str -> Try({}, [BadTagPrefix])
	tag_prefix_check = |text| {
		bytes = text.to_utf8()
		ok = bytes.len() >= 1 and bytes.len() <= 40 and bytes.last() == Ok('-') and bytes.all(|b| is_lower(b) or is_digit(b) or b == '-' or b == '.' or b == '_')
		if ok Ok({}) else Err(BadTagPrefix)
	}

	## R-CH5, Design Q614 item 7: the date and the sha of a build, from the 4 parts of the end of a tag or an id. The year has 4 digits, the month and the day 2 digits,
	## the sha 7 or more hex digits. With `names` true the month can be an English name in full (the `nightly` table only).
	date_of : { names : Bool }, Str, Str, Str, Str -> Try({ year : U64, month : U64, day : U64, sha : Str }, [NotDate])
	date_of = |opts, year, month, day, sha| {
		month_n = if digits_of(month, 2) {
			U64.from_str(month).map_err(|_| NotDate)
		} else if opts.names {
			match months.find_first_index(|name| name == month) {
				Ok(i) => Ok(i + 1)
				Err(_) => Err(NotDate)
			}
		} else {
			Err(NotDate)
		}
		if digits_of(year, 4) and digits_of(day, 2) and sha.count_utf8_bytes() >= 7 and sha.to_utf8().all(is_hex) {
			match (U64.from_str(year), month_n, U64.from_str(day)) {
				(Ok(y), Ok(m), Ok(d)) => Ok({ year: y, month: m, day: d, sha })
				_ => Err(NotDate)
			}
		} else {
			Err(NotDate)
		}
	}

	## R-CH5: the id of a channel build, read from the right: sha, day, month, year. The rest is the name. The name follows R-CH3 (`nightly` is the one reserved name that is allowed).
	parse_id : Str -> Try({ name : Str, year : U64, month : U64, day : U64, sha : Str }, [NotChannelId])
	parse_id = |id| {
		parts = id.split_on("-")
		cut = parts.len().minus_saturated(4)
		name = Str.join_with(parts.take_first(cut), "-")
		name_ok = name == "nightly" or Channel.name_check(name).is_ok()
		match (parts.drop_first(cut), cut > 0 and name_ok) {
			([year, month, day, sha], Bool.True) => match Channel.date_of({ names: name == "nightly" }, year, month, day, sha) {
				Ok(d) => Ok({ name, year: d.year, month: d.month, day: d.day, sha: d.sha })
				Err(_) => Err(NotChannelId)
			}
			_ => Err(NotChannelId)
		}
	}

	## Slice 240 (R-CH11): the tables of a file that have `source` and `tag-prefix`, for `install_ref`. A table with a missing or bad key is a failure of the read of the file and is not here.
	entries : List(Channel.Table) -> List({ name : Str, source : Str, tag_prefix : Str })
	entries = |tables| tables.keep_oks(
		|t| match (t.source, t.tag_prefix) {
			(Ok(source), Ok(tag_prefix)) => Ok({ name: t.name, source, tag_prefix })
			_ => Err(Incomplete)
		},
	)

	## Slice 240 (R-CH11, R-CH8, R-CH5): what the operand of `tln roc install` names. `config` and `project` are the tables of `config.toml` and of the root `talon.toml`.
	## A bare name of a table is `Latest`. An id of a table (`parse_id`, read from the right) is `Build`. A table of `config.toml` wins. A table of the project only is `ProjectOnly` (no consent yet, exit 19).
	## The tables decide, not the form of the text: a nightly id, a sha prefix, `@latest` and a release are `NotChannel`.
	install_ref : { text : Str, config : List({ name : Str, source : Str, tag_prefix : Str }), project : List({ name : Str, source : Str, tag_prefix : Str }) } -> [NotChannel, Latest({ name : Str, source : Str, tag_prefix : Str }), Build({ name : Str, source : Str, tag_prefix : Str }, Str), ProjectOnly({ name : Str, source : Str, tag_prefix : Str })]
	install_ref = |facts| {
		bare = if name_check(facts.text).is_ok() Ok(facts.text) else Err(NoName)
		built = match parse_id(facts.text) {
			Ok(id) if id.name != "nightly" => Ok(id.name)
			_ => Err(NoName)
		}
		found = |name| match facts.config.find_first(|t| t.name == name) {
			Ok(t) => Ok(Config(t))
			Err(_) => match facts.project.find_first(|t| t.name == name) {
				Ok(t) => Ok(Project(t))
				Err(_) => Err(NoTable)
			}
		}
		by_bare = match bare {
			Ok(name) => found(name)
			Err(_) => Err(NoTable)
		}
		by_id = match built {
			Ok(name) => found(name)
			Err(_) => Err(NoTable)
		}
		match (by_bare, by_id) {
			(Ok(Config(t)), _) => Latest(t)
			(Ok(Project(t)), _) => ProjectOnly(t)
			(_, Ok(Config(t))) => Build(t, facts.text)
			(_, Ok(Project(t))) => ProjectOnly(t)
			_ => NotChannel
		}
	}

	## Slice 240 (R-CH11): the failure text of a table that only the project has (exit 19, kind Input). `source` is shown as written.
	trust_text : { name : Str, source : Str, .. } -> { message : Str, hint : Str }
	trust_text = |table| { message: "talon.toml uses compiler channel ${table.name} (github.com/${table.source}).", hint: "Run: tln roc channel add ${table.name}" }

	## Slice 240 (Design Q615 item 7): the exit 2 text for a name, or an id of a name, that has no table. A text that is all hex digits is a sha prefix, not a name (the old rules decide).
	unknown_text : Str -> Try(Str, [NotChannelText])
	unknown_text = |text| {
		name = match parse_id(text) {
			Ok(id) if id.name != "nightly" => Ok(id.name)
			_ => if name_check(text).is_ok() and !text.to_utf8().all(is_hex) Ok(text) else Err(NotChannelText)
		}
		match name {
			Ok(n) => Ok(unknown_name_text(n))
			Err(e) => Err(e)
		}
	}

	## Slice 241 (Design Q616 items 1 and 7): the exit 2 text for the name of a channel that has no table.
	unknown_name_text : Str -> Str
	unknown_name_text = |n| "unknown compiler channel ${n}. Add it: tln roc channel add ${n} <URL>"

	## Slice 241 (R-CH5, R-CH7): the parts of the id of a user-channel build. A nightly id is not one (`nightly` is the built-in channel).
	user_parts : Str -> Try({ name : Str, year : U64, month : U64, day : U64, sha : Str }, [NotUser])
	user_parts = |id| match parse_id(id) {
		Ok(p) if p.name != "nightly" => Ok(p)
		_ => Err(NotUser)
	}

	## Slice 241 (R-CH9, R-NS1, Design Q616 item 5): the order of two builds of one user channel: the date, then `published_at` when both are known and differ, then the tag text (the sha).
	## Two ids of different channels, or an id that is not a user build, have no order (`Err(NoOrder)`: there is no order across channels).
	user_order : Str, Str, List({ id : Str, published_at : U64 }) -> Try([Before, Same, After], [NoOrder])
	user_order = |a, b, times| match (user_parts(a), user_parts(b)) {
		(Ok(x), Ok(y)) if x.name == y.name => {
			if a == b {
				Ok(Same)
			} else {
				match compare_numbers([x.year, x.month, x.day], [y.year, y.month, y.day]) {
					Same => match (published_in(times, a), published_in(times, b)) {
						(Ok(p), Ok(q)) if p != q => Ok(if p < q Before else After)
						_ => Ok(Text.compare(x.sha, y.sha))
					}
					other => Ok(other)
				}
			}
		}
		_ => Err(NoOrder)
	}

	## Slice 241 (R-CH7): does `>=<bound>` admit the id? A build of the same channel that `user_order` does not put before the bound.
	user_at_least : Str, Str, List({ id : Str, published_at : U64 }) -> Bool
	user_at_least = |bound, id, times| match user_order(id, bound, times) {
		Ok(Before) => Bool.False
		Ok(_) => Bool.True
		Err(_) => Bool.False
	}

	## Slice 241 (R-CH7, R-CH8): the table for a name. The table of `config.toml` wins.
	table_for : { name : Str, config : List({ name : Str, source : Str, tag_prefix : Str }), project : List({ name : Str, source : Str, tag_prefix : Str }) } -> [Config({ name : Str, source : Str, tag_prefix : Str }), Project({ name : Str, source : Str, tag_prefix : Str }), Neither]
	table_for = |facts| match facts.config.find_first(|t| t.name == facts.name) {
		Ok(t) => Config(t)
		Err(_) => match facts.project.find_first(|t| t.name == facts.name) {
			Ok(t) => Project(t)
			Err(_) => Neither
		}
	}

	## Slice 241 (R-CH8, Design Q616 items 3 and 4): what `<name>@<selector>` names. `text` is the operand of a `tln roc` command. `config` and `project` are the tables of `config.toml` and of the root `talon.toml`.
	## The `Str` of `Builtin` and `User` is the selector for `Nightlies.pick` (`@latest`, `@-1`). `nightly` is the built-in channel (no table, no consent). A table of `config.toml` wins (`User`); the project only is `ProjectOnly`
	## (exit 19); no table is `NoTable` (exit 2). After a name only `latest` and a step can follow; any other selector is `BadSelector` (a table of the project only is `ProjectOnly` first). A bare `nightly` is `Builtin("@latest")`.
	## Any other text (a bare name, a selector with no name, a package ref, a bad name, an id) is `NotNamed`.
	named_ref : { text : Str, config : List({ name : Str, source : Str, tag_prefix : Str }), project : List({ name : Str, source : Str, tag_prefix : Str }) } -> [NotNamed, Builtin(Str), User({ name : Str, source : Str, tag_prefix : Str }, Str), ProjectOnly({ name : Str, source : Str, tag_prefix : Str }), NoTable(Str), BadSelector(Str)]
	named_ref = |facts| {
		if facts.text == "nightly" {
			Builtin("@latest")
		} else {
			match facts.text.split_first("@") {
				Err(_) => NotNamed
				Ok({ before, after }) => {
					name = before
					valid = match Selector.parse(after, Bool.False) {
						Ok(Latest) | Ok(Step(_)) => Bool.True
						_ => Bool.False
					}
					if after.is_empty() {
						NotNamed
					} else if name == "nightly" {
						if valid Builtin("@${after}") else BadSelector(after)
					} else if name_check(name).is_err() {
						NotNamed
					} else {
						match table_for({ name, config: facts.config, project: facts.project }) {
							Config(t) => if valid User(t, "@${after}") else BadSelector(after)
							Project(t) => ProjectOnly(t)
							Neither => NoTable(name)
						}
					}
				}
			}
		}
	}

	## Slice 241 (Design Q616 item 3): the exit 2 text (kind Usage) of a selector after a name other than `latest` and a step.
	bad_selector_text : { name : Str, selector : Str } -> { message : Str, hint : Str }
	bad_selector_text = |facts| {
		message: "${facts.name}@${facts.selector}: only latest or a step (-1, +1) can follow a channel name",
		hint: "To name one build, use its full id: tln roc install ${facts.name}-<date>-<sha>",
	}

	## Slice 241 (R-CH7, R-CH5): the range `=<user id>` or `>=<user id>` of the text of `[toolchain] roc`. Any other text names no user build.
	user_range : Str -> Try([Exactly(Str), AtLeast(Str)], [NoUser])
	user_range = |text| {
		at_least = text.drop_prefix(">=")
		exact = text.drop_prefix("=")
		if text.starts_with(">=") and user_parts(at_least).is_ok() {
			Ok(AtLeast(at_least))
		} else if text.starts_with("=") and user_parts(exact).is_ok() {
			Ok(Exactly(exact))
		} else {
			Err(NoUser)
		}
	}

	## Slice 241 (R-CH11, R-CH7, R-CH13, Design Q616 items 1 and 6, Design Q615 item 2): the trust of the compiler range `text` (`[toolchain] roc`).
	##
	## | Case | Result |
	## | --- | --- |
	## | The range names no user build (`*`, a semver range, a nightly, a release, a text that is no range) | `NoChannel` |
	## | `=<user id>` or `>=<user id>`, the table is in `config.toml` | `Free` |
	## | No table in `config.toml`, an installed id is in the range | `Free` (R-CH13: no list is needed) |
	## | The table is in the project only | `Stop(table)` (exit 19, before any request) |
	## | No table in either file | `NoTable(name)` (exit 2) |
	pin_trust : { text : Str, installed : List(Str), times : List({ id : Str, published_at : U64 }), config : List({ name : Str, source : Str, tag_prefix : Str }), project : List({ name : Str, source : Str, tag_prefix : Str }) } -> [NoChannel, Free, Stop({ name : Str, source : Str, tag_prefix : Str }), NoTable(Str)]
	pin_trust = |facts| match user_range(facts.text) {
		Err(_) => NoChannel
		Ok(range) => {
			bound = match range {
				Exactly(id) => id
				AtLeast(id) => id
			}
			name = match user_parts(bound) {
				Ok(p) => p.name
				Err(_) => ""
			}
			held = facts.installed.any(
				|id| match range {
					Exactly(a) => id == a
					AtLeast(a) => user_at_least(a, id, facts.times)
				},
			)
			match table_for({ name, config: facts.config, project: facts.project }) {
				Config(_) => Free
				_ if held => Free
				Project(t) => Stop(t)
				Neither => NoTable(name)
			}
		}
	}

	## Slice 241 (Design Q616 item 8, R-CH6): the warning (one line, no `warning: ` and no line end) for a pin that names a user build whose table is in `config.toml` and not in the project `talon.toml`. Else `Err(None)`.
	pin_warning : { text : Str, config : List({ name : Str, source : Str, tag_prefix : Str }), project : List({ name : Str, source : Str, tag_prefix : Str }) } -> Try(Str, [None])
	pin_warning = |facts| match user_range(facts.text) {
		Err(_) => Err(None)
		Ok(range) => {
			bound = match range {
				Exactly(id) => id
				AtLeast(id) => id
			}
			name = match user_parts(bound) {
				Ok(p) => p.name
				Err(_) => ""
			}
			match table_for({ name, config: facts.config, project: facts.project }) {
				Config(_) => if facts.project.any(|t| t.name == name) {
					Err(None)
				} else {
					Ok("talon.toml pins roc \"${facts.text}\", but it has no [channels.${name}] table. Other machines and CI cannot resolve the pin. Copy the table from config.toml to talon.toml.")
				}
				_ => Err(None)
			}
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
	hintless = |message| message.ends_with("is a reserved channel name") or message.ends_with("is not a channel name") or message.ends_with("is not owner/repo") or message.ends_with("is not a tag prefix") or message.contains(": missing key ")

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

published_in : List({ id : Str, published_at : U64 }), Str -> Try(U64, [NoTime])
published_in = |times, id| match times.find_first(|row| row.id == id) {
	Ok(row) => Ok(row.published_at)
	Err(_) => Err(NoTime)
}

compare_numbers : List(U64), List(U64) -> [Before, Same, After]
compare_numbers = |a, b| match (a, b) {
	([x, .. as xs], [y, .. as ys]) => if x < y Before else if x > y After else compare_numbers(xs, ys)
	_ => Same
}

reserved : List(Str)
reserved = ["nightly", "stable", "git", "link", "copy", "zig", "debug", "local", "compat"]

table_keys : List(Str)
table_keys = ["shape", "source", "tag-prefix"]

months : List(Str)
months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

digits_of : Str, U64 -> Bool
digits_of = |text, count| text.count_utf8_bytes() == count and text.to_utf8().all(is_digit)

is_hex : U8 -> Bool
is_hex = |b| is_digit(b) or (b >= 'a' and b <= 'f') or (b >= 'A' and b <= 'F')

# One part of `owner/repo`.
good_part : Str -> Bool
good_part = |part| {
	bytes = part.to_utf8()
	!bytes.is_empty() and bytes.first() != Ok('.') and bytes.all(|b| is_lower(b) or is_digit(b) or (b >= 'A' and b <= 'Z') or b == '-' or b == '_' or b == '.')
}

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
			# Design Q614 item 3: the shape `github-release` checks the forms of `source` and `tag-prefix`.
			source = text_key(doc, name, "source", |word| if Channel.source_check(word).is_ok() Ok(word) else Err("'${word}' is not owner/repo"))
			prefix = text_key(doc, name, "tag-prefix", |word| if Channel.tag_prefix_check(word).is_ok() Ok(word) else Err("'${word}' is not a tag prefix"))
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
