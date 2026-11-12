import Fail
import JsonDoc
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

	## Slice 242 (R-CH12, R-CH13): a table as the commands read and print it. `shape` is always `github-release`.
	Entry : { name : Str, source : Str, tag_prefix : Str }

	## Slice 242 (R-CH12): the source of the URL of `tln roc channel add <name> <URL>`. The forms: `https://github.com/<owner>/<repo>` with `/`, `/releases` or `/releases/tag/<tag>` at the end, and `<owner>/<repo>`.
	## The source keeps its case and follows R-CH4 (`source_check`). Any other text is `BadUrl`.
	source_of_url : Str -> Try(Str, [BadUrl])
	source_of_url = |url| {
		github = "https://github.com/"
		parts = if url.starts_with(github) {
			match url.drop_prefix(github).split_on("/") {
				[owner, repo] => Ok((owner, repo))
				[owner, repo, ""] => Ok((owner, repo))
				[owner, repo, "releases"] => Ok((owner, repo))
				[owner, repo, "releases", "tag", tag] if !tag.is_empty() => Ok((owner, repo))
				_ => Err(BadUrl)
			}
		} else {
			match url.split_on("/") {
				[owner, repo] => Ok((owner, repo))
				_ => Err(BadUrl)
			}
		}
		match parts {
			Ok((owner, repo)) => {
				source = "${owner}/${repo}"
				if source_check(source).is_ok() Ok(source) else Err(BadUrl)
			}
			Err(_) => Err(BadUrl)
		}
	}

	## Slice 242 (R-CH12): the exit 2 text for a URL that is not a form. The hint is the text of the design.
	url_text : Str -> { message : Str, hint : Str }
	url_text = |url| { message: "${url} is not a channel source", hint: "known channel sources: github.com/<owner>/<repo>" }

	## Slice 242 (R-CH12, Design Q617 item 3): the tag-prefix of the tags of page 1. A tag that ends with `<date>-<sha>` gives the text before the date; the prefix must follow R-CH4 (`tag_prefix_check`, so it is never empty).
	## One prefix is the answer. None is `NoPrefix`. 2 or more are `Prefixes`, sorted, with no double.
	prefix_of_tags : List(Str) -> Try(Str, [NoPrefix, Prefixes(List(Str))])
	prefix_of_tags = |tags| {
		found = tags.keep_oks(|tag| prefix_in_tag(tag))
		unique = found.fold([], |acc, p| if acc.contains(p) acc else acc.append(p))
		match Text.sorted(unique) {
			[] => Err(NoPrefix)
			[one] => Ok(one)
			many => Err(Prefixes(many))
		}
	}

	## Slice 242 (R-CH12): the exit 2 text of `NoPrefix` and `Prefixes`.
	prefix_text : [NoPrefix, Prefixes(List(Str))] -> Str
	prefix_text = |failure| match failure {
		NoPrefix => "no release tag ends with <date>-<sha>. Pass --tag-prefix."
		Prefixes(list) => "release tags have ${list.len().to_str()} prefixes: ${Str.join_with(list, ", ")}. Pass --tag-prefix."
	}

	## Slice 242 (Design Q617 item 3): `--tag-prefix <given>`. A value that breaks R-CH4 is `BadPrefix` (before the tags). Else a tag must start with it and have `<date>-<sha>` after it: none is `NoTag`.
	prefix_given : { given : Str, tags : List(Str) } -> Try(Str, [BadPrefix, NoTag])
	prefix_given = |facts| match tag_prefix_check(facts.given) {
		Err(_) => Err(BadPrefix)
		Ok({}) => {
			listed = facts.tags.any(
				|tag| tag.starts_with(facts.given) and match tag.drop_prefix(facts.given).split_on("-") {
					[year, month, day, sha] => date_of({ names: Bool.False }, year, month, day, sha).is_ok()
					_ => Bool.False
				},
			)
			if listed Ok(facts.given) else Err(NoTag)
		}
	}

	## Slice 242 (Design Q617 item 3): the exit 2 text of the two failures of `prefix_given`.
	given_text : { given : Str, kind : [BadPrefix, NoTag], source : Str } -> Str
	given_text = |facts| match facts.kind {
		BadPrefix => "${facts.given} is not a tag prefix. A tag prefix has 1 to 40 characters of a-z, 0-9, . _ and -, and ends with -."
		NoTag => "no release tag on page 1 of github.com/${facts.source} starts with ${facts.given} and ends with <date>-<sha>"
	}

	## Slice 242 (Design Q617 item 1): `add <name> <URL>` when `config.toml` has a table of the name. The same source (the text, case kept) is `Same`; another is `Other(<the source in config.toml>)`.
	exists_check : { name : Str, source : Str, config : List(Channel.Entry) } -> [Absent, Same, Other(Str)]
	exists_check = |facts| match facts.config.find_first(|t| t.name == facts.name) {
		Ok(t) => if t.source == facts.source Same else Other(t.source)
		Err(_) => Absent
	}

	## Slice 242 (Design Q617 item 1): exit 0, the table is added already.
	already_text : { name : Str, source : Str } -> Str
	already_text = |facts| "channel ${facts.name} is already added (github.com/${facts.source})"

	## Slice 242 (Design Q617 item 1): exit 2, the table has another source.
	exists_text : { name : Str, source : Str, existing : Str } -> { message : Str, hint : Str }
	exists_text = |facts| {
		message: "channel ${facts.name} is added with the source ${facts.existing}, not ${facts.source}",
		hint: "To replace it, run: tln roc channel rm ${facts.name}",
	}

	## Slice 242 (R-CH12, R-CH5): exit 19 when an installed id of the name records another source. The ids are read from the right (`user_parts`); an id with no recorded source records no other source. The first one in the order of the list is the answer.
	source_conflict : { name : Str, source : Str, installed : List({ id : Str, source : Try(Str, [Unset]) }) } -> Try({}, [Conflict(Str)])
	source_conflict = |facts| {
		other = facts.installed.keep_oks(
			|row| match (user_parts(row.id), row.source) {
				(Ok(p), Ok(recorded)) if p.name == facts.name and recorded != facts.source => Ok(recorded)
				_ => Err(Fine)
			},
		)
		match other {
			[recorded, ..] => Err(Conflict(recorded))
			[] => Ok({})
		}
	}

	## Slice 242 (R-CH12): the exit 19 text of `source_conflict`.
	conflict_text : { name : Str, source : Str, recorded : Str } -> { message : Str, hint : Str }
	conflict_text = |facts| {
		message: "channel ${facts.name}: installed builds record the source ${facts.recorded}, not ${facts.source}",
		hint: "Remove them with tln roc remove <id>, or use another name.",
	}

	## Slice 242 (R-CH13, Design Q617 item R-CH13 (1)): `add <name>` with no URL. `NoTable`: the project has no table of the name (exit 2). `Copy`: the project has it and `config.toml` has not. `Equal`: both have it, equal (exit 0). `Differ`: both have it, not equal (exit 19).
	copy_check : { name : Str, config : List(Channel.Entry), project : List(Channel.Entry) } -> [NoTable, Copy(Channel.Entry), Equal, Differ]
	copy_check = |facts| match facts.project.find_first(|t| t.name == facts.name) {
		Err(_) => NoTable
		Ok(p) => match facts.config.find_first(|t| t.name == facts.name) {
			Err(_) => Copy(p)
			Ok(c) => if c.source == p.source and c.tag_prefix == p.tag_prefix Equal else Differ
		}
	}

	## Slice 242 (R-CH13, Design Q617): `rm <name>`. A table of `config.toml` is `Found`. The built-in name is `Builtin`. Any other name (also one that only the project has) is `Missing`.
	rm_check : { name : Str, config : List(Channel.Entry) } -> [Found, Builtin, Missing]
	rm_check = |facts| if builtin(facts.name).is_ok() {
		Builtin
	} else if facts.config.any(|t| t.name == facts.name) {
		Found
	} else {
		Missing
	}

	## Slice 242 (R-CH13, Design Q617): the exit 2 text of `Builtin` and `Missing`.
	rm_fail_text : { name : Str, kind : [Builtin, Missing], path : Str } -> Str
	rm_fail_text = |facts| match facts.kind {
		Builtin => "${facts.name} is a built-in channel and cannot be removed"
		Missing => "no channel ${facts.name} in ${facts.path}"
	}

	## Slice 242 (R-CH12, R-CH10): the table as the commands write it: 4 lines, each with a line end.
	table_text : Channel.Entry -> Str
	table_text = |t| "[channels.${t.name}]\nshape = \"github-release\"\nsource = \"${t.source}\"\ntag-prefix = \"${t.tag_prefix}\"\n"

	## Slice 242 (R-CH12, R-CC6): the new text of `config.toml` with the table added. The table goes at the end, after a blank line (none for an empty file). Every other byte stays. A text that is not TOML is a failure of kind `Input`.
	add_edit : { path : Str, text : Str, table : Channel.Entry } -> Try(Str, Fail)
	add_edit = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(_) => {
			kept = trim_end_lines(facts.text)
			if kept.is_empty() Ok(table_text(facts.table)) else Ok("${kept}\n\n${table_text(facts.table)}")
		}
	}

	## Slice 242 (R-CH13, R-CC6): the new text of `config.toml` without the table `name`: its header, its keys and the blank lines before it. Every other byte stays. No such table is `Same`. A text that is not TOML is a failure of kind `Input`.
	remove_edit : { path : Str, text : Str, name : Str } -> Try([Same, Set(Str)], Fail)
	remove_edit = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(_) => {
			lines = facts.text.split_on("\n")
			header = "[channels.${facts.name}]"
			match lines.find_first_index(|line| line.trim() == header) {
				Err(_) => Ok(Same)
				Ok(at) => {
					is_blank = |i| lines.get(i).map_ok(|line| line.trim().is_empty()) == Ok(Bool.True)
					is_header = |i| lines.get(i).map_ok(|line| line.trim().starts_with("[")) == Ok(Bool.True)
					start = back_over(at, is_blank, 0)
					next = forward_to(at + 1, lines.len(), is_header)
					stop = back_over(next, is_blank, at + 1)
					kept = lines.take_first(start).concat(lines.drop_first(stop))
					Ok(Set(Str.join_with(kept, "\n")))
				}
			}
		}
	}

	## Slice 242 (R-CH13, Design Q617 item 7): the text of `tln roc channel list`. A header, the built-in table, the tables of `config.toml` in file order, then the tables that only the project has. Each gap is the widest cell and 2 spaces; the last column has no padding. No end of line at the end.
	list_text : { config : List(Channel.Entry), project : List(Channel.Entry) } -> Str
	list_text = |facts| {
		rows = list_rows(facts)
		table = [["NAME", "SHAPE", "SOURCE", "FROM"]].concat(rows.map(|r| [r.entry.name, "github-release", r.entry.source, r.from]))
		widths = [0, 1, 2].map(|col| table.fold(0, |w, cells| w.max((cells.get(col) ?? "").count_utf8_bytes())))
		pad = |text, w| "${text}${" ".repeat(w - text.count_utf8_bytes())}"
		line = |cells| {
			shown = cells.map_with_index(|text, col| if col == 3 text else pad(text, widths.get(col) ?? 0))
			Str.join_with(shown.map(|cell| cell), "  ")
		}
		Str.join_with(table.map(line), "\n")
	}

	## Slice 242 (R-CH13, R-J1 to R-J3, Design Q617 item 7): the `data` of `tln roc channel list --json`. The keys are snake_case. `origin` is `built-in`, `config` or `project`; `added` is false for a table that only the project has.
	list_data : { config : List(Channel.Entry), project : List(Channel.Entry) } -> JsonDoc
	list_data = |facts| {
		doc = |r| JsonDoc.Obj([
			("name", JsonDoc.Text(r.entry.name)),
			("shape", JsonDoc.Text("github-release")),
			("source", JsonDoc.Text(r.entry.source)),
			("tag_prefix", JsonDoc.Text(r.entry.tag_prefix)),
			("origin", JsonDoc.Text(r.origin)),
			("added", JsonDoc.Flag(r.origin != "project")),
		])
		JsonDoc.Obj([("channels", JsonDoc.Arr(list_rows(facts).map(doc)))])
	}

	## Slice 242 (R-CH12, TW24): the print of `add <name> <URL>`. `read` is the number of releases of page 1. No end of line at the end. A newest build with no asset for `target` has no `Install:` part.
	added_text : { path : Str, table : Channel.Entry, read : U64, newest : { id : Str, has_asset : Bool }, target : Str } -> Str
	added_text = |facts| {
		noun = if facts.read == 1 "release" else "releases"
		last = if facts.newest.has_asset {
			"newest: ${facts.newest.id} (has ${facts.target}). Install: tln roc install ${facts.table.name}"
		} else {
			"newest: ${facts.newest.id} (no asset for ${facts.target})"
		}
		"read ${facts.read.to_str()} ${noun} of github.com/${facts.table.source}\nadded channel ${facts.table.name} to ${facts.path}:\n${indented(facts.table)}\n${last}"
	}

	## Slice 242 (R-CH13, TW24): the print of `add <name>` (a copy from the project). No end of line at the end.
	copied_text : { path : Str, from : Str, table : Channel.Entry } -> Str
	copied_text = |facts| "copied channel ${facts.table.name} from ${facts.from} to ${facts.path}:\n${indented(facts.table)}"

	## Slice 242 (Design Q618): exit 2, page 1 has no build.
	no_build_text : Str -> Str
	no_build_text = |source| "github.com/${source} has no build on page 1 (drafts and prereleases do not count)"

	## Slice 242 (R-CH13, TW24): the print of `rm`.
	removed_text : { path : Str, name : Str } -> Str
	removed_text = |facts| "removed channel ${facts.name} from ${facts.path}"

	## Slice 243 (R-CH15, R-CH8, R-CH5): the ref that `tln roc update` gives to `RocInstall.offer!`. A name gives `<name>@latest`. No name: the channel of the default (read from the right) gives `<name>@latest`; any other default, and no default, give `@latest`.
	update_ref : { name : Try(Str, [NoName]), default : Try(Str, [Unset]) } -> Str
	update_ref = |facts| match facts.name {
		Ok(name) => "${name}@latest"
		Err(NoName) => match facts.default {
			Ok(id) => match user_parts(id) {
				Ok(parts) => "${parts.name}@latest"
				Err(_) => "@latest"
			}
			Err(Unset) => "@latest"
		}
	}

	## Slice 243 (R-CH14, R-CH15): the text of `[toolchain] roc` of a root `talon.toml` text, when it is a string. No key, no table, a value that is no string and a text that is not TOML give `Err(None)`.
	pin_text : Str -> Try(Str, [None])
	pin_text = |text| match Toml.parse(text) {
		Ok(doc) => match Toml.get(doc, ["toolchain", "roc"]) {
			Ok(Value.String(value)) => Ok(value)
			_ => Err(None)
		}
		Err(_) => Err(None)
	}

	## Slice 243 (R-CH17, R-PD12, R-GC5, Design Q619 G1): the id of `[toolchain] roc = "=<id>"` in a root `talon.toml` text. The id is a user-channel build or a nightly (`parse_id`). A range (`*`, `>=...`, a semver range), a text that is no id, no key and a text that is not TOML give `Err(None)`.
	toml_pin : Str -> Try(Str, [None])
	toml_pin = |text| match pin_text(text) {
		Ok(value) if value.starts_with("=") and parse_id(value.drop_prefix("=")).is_ok() => Ok(value.drop_prefix("="))
		_ => Err(None)
	}

	## Slice 243 (R-CC7): the spans of a root `talon.toml` that `roc use` edits, for `Guard.check_all`: the text of `[toolchain] roc` (`""` for none).
	use_spans : Str -> List(Str)
	use_spans = |text| [pin_text(text) ?? ""]

	## Slice 243 (R-CH14, R-CH6, R-CC6, R-CC7, Design Q619 C1, C3, C5): the new text of the root `talon.toml` for `roc use <user id>`. It sets `[toolchain] roc = "=<id>"` (`Toml.replace` when the key is there, so its comment stays; else `Toml.insert`), and adds the table `[channels.<name>]` at the end
	## after a blank line, unless it is there (`Channel.table_text`). When the old value names a user build (`=<id>` or `>=<id>`) of another channel, only the table `[channels.<old>]` goes (with the blank lines before it). Every other byte stays. The empty text gives a new file. A text that is not TOML is a failure of kind `Input`.
	use_edit : { path : Str, text : Str, id : Str, table : Channel.Entry } -> Try(Str, Fail)
	use_edit = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(first) => {
			old_channel = match pin_text(facts.text) {
				Ok(value) => match user_range(value) {
					Ok(range) => channel_of_range(range)
					Err(_) => ""
				}
				Err(_) => ""
			}
			dropped = if old_channel != "" and old_channel != facts.table.name {
				without_table(facts.text, old_channel)
			} else {
				facts.text
			}
			doc = match Toml.parse(dropped) {
				Ok(d) => d
				Err(_) => first
			}
			value = Value.String("=${facts.id}")
			pinned = match Toml.get(doc, ["toolchain", "roc"]) {
				Ok(_) => Toml.replace(doc, ["toolchain", "roc"], value).map_err(|_| cannot_edit(facts.path))
				Err(NotFound) => Toml.insert(doc, ["toolchain", "roc"], value).map_err(|_| cannot_edit(facts.path))
			}
			done = pinned?
			text = done.to_str()
			has_table = match Toml.get(done, ["channels", facts.table.name]) {
				Ok(_) => Bool.True
				Err(NotFound) => Bool.False
			}
			if has_table Ok(text) else Ok("${trim_end_lines(text)}\n\n${table_text(facts.table)}")
		}
	}

	## Slice 243 (R-CH14, R-CC6, Design Q619 C2, C3): back to a nightly. When `[toolchain] roc` names a user build (`=<id>` or `>=<id>`), the key goes (`Toml.remove`) and the table `[channels.<name>]` of that channel goes with the blank lines before it. A `[toolchain]` table that is empty after that
	## goes too, with the blank lines before it. Other tables stay. Every other byte stays. Any other value, no key and the empty text are `Same`. A text that is not TOML is a failure of kind `Input`.
	unuse_edit : { path : Str, text : Str } -> Try([Same, Set(Str)], Fail)
	unuse_edit = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(_) => match pin_text(facts.text) {
			Err(_) => Ok(Same)
			Ok(value) => match user_range(value) {
				Err(_) => Ok(Same)
				Ok(range) => {
					dropped = without_table(facts.text, channel_of_range(range))
					match Toml.parse(dropped) {
						Err(_) => Err(cannot_edit(facts.path))
						Ok(doc) => match Toml.remove(doc, ["toolchain", "roc"]) {
							Err(NoEntry) => Err(cannot_edit(facts.path))
							Ok(done) => {
								empty = match Toml.get(done, ["toolchain"]) {
									Ok(Value.Table(t)) => t.is_empty()
									_ => Bool.False
								}
								if empty Ok(Set(without_table_header(done.to_str(), "toolchain"))) else Ok(Set(done.to_str()))
							}
						}
					}
				}
			}
		}
	}

	## Slice 243 (R-CH15, R-UP8, Design Q619 U2): `tln upgrade roc` for a pin. `text` is the value of `[toolchain] roc`; `newest` is the newest build of the channel that the switch and `min-release-age` allow. `=<user id>` gives `Move(newest)` when `Channel.user_order` puts `newest` after the pinned build, else `Same` (never down, never to another channel).
	## `>=<user id>` works as a `>=nightly-...` range: it does not move. Every value that names no user build is `NotUser`.
	pin_move : { text : Str, newest : Str, times : List({ id : Str, published_at : U64 }) } -> [NotUser, Same, Move(Str)]
	pin_move = |facts| match user_range(facts.text) {
		Ok(Exactly(id)) => match user_order(facts.newest, id, facts.times) {
			Ok(After) => Move(facts.newest)
			_ => Same
		}
		_ => NotUser
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

# Slice 242: the prefix in a tag that ends with `<date>-<sha>` (the ISO date). The prefix follows R-CH4, so it is never empty.
prefix_in_tag : Str -> Try(Str, [NoPrefix])
prefix_in_tag = |tag| {
	parts = tag.split_on("-")
	cut = parts.len().minus_saturated(4)
	prefix = if cut == 0 "" else "${Str.join_with(parts.take_first(cut), "-")}-"
	match parts.drop_first(cut) {
		[year, month, day, sha] if parts.len() >= 4 and Channel.date_of({ names: Bool.False }, year, month, day, sha).is_ok() and Channel.tag_prefix_check(prefix).is_ok() => Ok(prefix)
		_ => Err(NoPrefix)
	}
}

# Slice 242: the text without the line ends (and `\r`) at its end.
trim_end_lines : Str -> Str
trim_end_lines = |text| {
	bytes = text.to_utf8()
	n = bytes.len()
	keep = trim_count(bytes, n)
	Str.from_utf8_lossy(bytes.take_first(keep))
}

trim_count : List(U8), U64 -> U64
trim_count = |bytes, n| match bytes.get(n.minus_saturated(1)) {
	Ok(b) if n > 0 and (b == '\n' or b == '\r') => trim_count(bytes, n - 1)
	_ => n
}

# Slice 242: the index `i` moved back over the blank lines, down to `floor`.
back_over : U64, (U64 -> Bool), U64 -> U64
back_over = |i, is_blank, floor| if i > floor and is_blank(i - 1) back_over(i - 1, is_blank, floor) else i

# Slice 242: the first index from `i` that is a header, else `end`.
forward_to : U64, U64, (U64 -> Bool) -> U64
forward_to = |i, end, is_header| if i >= end or is_header(i) i else forward_to(i + 1, end, is_header)

# Slice 242: the rows of `list`: the built-in table, the tables of `config.toml`, then the tables that only the project has.
list_rows : { config : List(Channel.Entry), project : List(Channel.Entry) } -> List({ entry : Channel.Entry, from : Str, origin : Str })
list_rows = |facts| {
	built = { name: "nightly", source: "roc-lang/nightlies", tag_prefix: "nightly-" }
	mine = facts.config.map(|t| { entry: t, from: "config.toml", origin: "config" })
	only = facts.project.keep_if(|t| !facts.config.any(|c| c.name == t.name)).map(|t| { entry: t, from: "talon.toml (not added)", origin: "project" })
	[{ entry: built, from: "built-in", origin: "built-in" }].concat(mine).concat(only)
}

# Slice 242: the table with 2 spaces of indent, no end of line at the end.
indented : Channel.Entry -> Str
indented = |t| Str.join_with(Channel.table_text(t).split_on("\n").keep_if(|line| !line.is_empty()).map(|line| "  ${line}"), "\n")

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

cannot_edit : Str -> Fail
cannot_edit = |path| Fail.new(Internal, "${path}: cannot write [toolchain] roc")

# The channel name that a range of `user_range` names.
channel_of_range : [Exactly(Str), AtLeast(Str)] -> Str
channel_of_range = |range| {
	bound = match range {
		Exactly(id) => id
		AtLeast(id) => id
	}
	match Channel.user_parts(bound) {
		Ok(p) => p.name
		Err(_) => ""
	}
}

# The text without the table `[channels.<name>]`: its header, its keys and the blank lines before it (as `remove_edit`).
without_table : Str, Str -> Str
without_table = |text, name| without_table_header(text, "channels.${name}")

# The text without the table `[<path>]` (the header line, the lines up to the next header, and the blank lines before it). No such header: the text as it is.
without_table_header : Str, Str -> Str
without_table_header = |text, path| {
	lines = text.split_on("\n")
	header = "[${path}]"
	match lines.find_first_index(|line| line.trim() == header) {
		Err(_) => text
		Ok(at) => {
			is_blank = |i| lines.get(i).map_ok(|line| line.trim().is_empty()) == Ok(Bool.True)
			is_header = |i| lines.get(i).map_ok(|line| line.trim().starts_with("[")) == Ok(Bool.True)
			start = back_over(at, is_blank, 0)
			next = forward_to(at + 1, lines.len(), is_header)
			stop = back_over(next, is_blank, at + 1)
			Str.join_with(lines.take_first(start).concat(lines.drop_first(stop)), "\n")
		}
	}
}
