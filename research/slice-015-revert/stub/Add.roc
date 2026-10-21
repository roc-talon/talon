import Alias
import Fail
import Ident
import Ranges
import Selector
import semver.Semver

## What `tln add` writes, as data: the header change and the `talon.toml` key (CLI 2, R-AD20 to R-AD33, Design 4.3).
## The command code (slice 007) applies the plan with the header edit (slice 005).
##
## `Plan`:
##
## | Field | Holds |
## | --- | --- |
## | `alias` | The alias of the entry |
## | `header` | `Insert`: a new entry. `Replace`: the entry of the alias gets a new URL: the platform entry (R-AD31), or an unmanaged entry that `--as` names (R-AD38). `Keep`: no change (R-AD21). `Update`: the entry moves inside the selector, as `tln update` does (R-AD22). |
## | `url` | For `Insert` and `Replace`: the URL to write. For `Keep` and `Update`: the URL that the header has now (for an unmanaged entry, its value as written). |
## | `toml` | `Ok({ key, value })`: write this key (the alias) and range to `talon.toml`. The file is created when it is missing (R-AD25, R-AD26). `Err(Nothing)`: write nothing, and do not create the file (R-AD24, G2). |
## | `note` | A text for the command to print, or `Err(None)` |
##
## The `talon.toml` value (R-AD23 to R-AD28, R-SL5):
##
## | Selector | `no_pin` | `toml` |
## | --- | --- | --- |
## | none | any | `Nothing` (R-AD24) |
## | `Latest` | any | `Nothing` (R-SL5: the same as no selector) |
## | `Exact("1.2.3")` | no | `=1.2.3` (R-AD25, R-AD28) |
## | `Exact("1.2.3")` | yes | `Nothing` (R-AD27) |
## | `Range(text)` | no | `text`: `^1.2`, `^1` (R-AD26) |
##
## `--no-pin` with a range is question Q8. The selectors `Nightly`, `Step`, `GitSha` and `GitRef` do not reach `Add`
## (`Ref.parse` stops them): the result for them is `Nothing`.
##
## `decide`: a full name of a candidate that the index gave (slice 003, 007):
##
## | Case | Result |
## | --- | --- |
## | `kind` is `Package`, no `--platform`, group not in the header | `Insert` with the alias of `Alias.choose` and the `talon.toml` value of the table (R-AD23 to R-AD27) |
## | The group is in the header (`Alias.choose` gives `Existing`) | As `decide_alias` for that alias (R-AD20) |
## | `--as <alias>` names an unmanaged entry (`Alias.choose` gives `Unmanaged`) | `Replace` under that alias, with the URL of the candidate, and the `talon.toml` value of the table (R-AD38, R-H9). The note is `entry changes: <old value> -> <name> <version>`. If the entry is the platform and the release is a package: failure `'<name>' is not a platform` (R-AD38, R-C4, R-AD32). If the entry is a package and the release is a platform: the failure of R-AD33. |
## | The default alias is an unmanaged entry | Failure of `Alias.choose` (`Taken`, R-AD18) with the text that names `--as <alias>` |
## | `--platform`, `kind` is `Package` | Failure: `'<name>' is not a platform` (R-AD32, R-C4) |
## | no `--platform`, `kind` is `Platform` | Failure: `'<name>' is a platform. Use tln add --platform <name>.` (R-AD33) |
## | `--platform`, the header has a platform | `Replace` under the alias of that platform, whatever the repo (R-AD31). `talon.toml`: the key of the old platform gets the value of the table. |
## | `--platform`, no platform in the header | `Insert` with the alias `pf`, or `--as` (R-AD30). |
##
## The note for `Replace` (R-SE7, proposal): `platform changes: <old name> <old version> -> <new name> <new version>`,
## when the two URLs differ. With a name that has no `name` (`Ident.name` is `Err(NoName)`), or no release (an unmanaged entry), the note names the old value as written: `platform changes: ../pf/main.roc -> acme/pf 0.1.0`.
## For a package that replaces an unmanaged entry (R-AD38) the note is `entry changes: <old value> -> <name> <version>`.
##
## `decide_alias`: the ref is a header alias (form 1), or its group is in the header:
##
## | Selector | Result |
## | --- | --- |
## | none | `Keep`, `toml` `Nothing`, note `<alias>: <name> <version> is in the header` and a second line `Run tln update <alias> to move it.` (R-AD21). Exit code 0. For an unmanaged entry (R-H9): `url` is its value as written, the note is `<alias>: <value> is in the header` with no second line (it names no command). |
## | `Latest` | The same as no selector (R-SL5, Q9 of slice 004) |
## | other | `Update`, `toml` by the table (R-AD22). For an unmanaged entry: the failure `never_changes` (exit 2, R-H9). |
##
## Failures have the kind `Usage` (R-EC2). Texts are a proposal (slice 004, "Output").
Add := {
	alias : Str,
	header : [Insert, Replace, Keep, Update],
	url : Str,
	toml : Try({ key : Str, value : Str }, [Nothing]),
	note : Try(Str, [None]),
}.{
	is_eq : _

	decide : {
		selector : Try(Selector, [None]),
		chosen : { name : Str, url : Str, kind : [Package, Platform] },
		platform_flag : Bool,
		no_pin : Bool,
		as_alias : Try(Str, [Unset]),
		header : List({ alias : Str, url : Str, is_platform : Bool }),
	} -> Try(Add, Fail)
	decide = |req| {
		name = req.chosen.name
		if req.platform_flag and req.chosen.kind == Package {
			Err(usage("'${name}' is not a platform"))
		} else if !req.platform_flag and req.chosen.kind == Platform {
			Err(usage("'${name}' is a platform. Use tln add --platform ${name}."))
		} else if req.platform_flag {
			decide_platform(req)
		} else {
			decide_package(req)
		}
	}

	decide_alias : {
		alias : Str,
		selector : Try(Selector, [None]),
		no_pin : Bool,
		header : List({ alias : Str, url : Str, is_platform : Bool }),
	} -> Try(Add, Fail)
	decide_alias = |req| match req.header.find_first(|row| row.alias == req.alias) {
		Err(NotFound) => Err(usage("'${req.alias}' is not in the header"))
		Ok(row) => if no_move(req.selector) {
			note = "${req.alias}: ${describe(row.url)} is in the header\nRun tln update ${req.alias} to move it."
			Ok({ alias: req.alias, header: Keep, url: row.url, toml: Err(Nothing), note: Ok(note) })
		} else {
			Ok({ alias: req.alias, header: Update, url: row.url, toml: toml_of(req.alias, req.selector, req.no_pin), note: Err(None) })
		}
	}

	## The usage failure for a command that would move an unmanaged entry: `tln update X`, `tln add X@sel` (R-H9, R-AD22; exit 2, R-EC2). `value` is the entry as written.
	## `PickFlow.asked!` uses it for `update` too. Text (proposal, TW24): `<alias> is a path entry: Talon never changes it. To replace it, run tln add <name> --as <alias>.`
	## A value with `://` is `a foreign URL` in place of `a path entry`. The message names the one command that can change the entry (R-H9, R-AD38).
	never_changes : { alias : Str, value : Str } -> Fail
	never_changes = |_facts| crash "todo"

	## `tln add a b --as x`: `--as` names one entry, so 2 or more names are a failure (R-AD28, R-FL12).
	## `names` is the number of names (operands). Text: `flag '--as' names one entry: got <n> names`.
	check_names : { names : U64, as_alias : Try(Str, [Unset]) } -> Try({}, Fail)
	check_names = |req| match req.as_alias {
		Ok(_) if req.names >= 2 => Err(usage("flag '--as' names one entry: got ${req.names.to_str()} names"))
		_ => Ok({})
	}

	## R-SL12 (slice 004 Q1, slice 007 Q2): `tln add` of a new name with a selector that no release matches. A usage failure (exit 2, R-EC2). `versions` are the versions of the
	## candidates of the repository (`Index.candidates`), in any order. The close versions are at most 3, shown newest first, joined with `, `:
	##
	## | Selector | Close versions |
	## | --- | --- |
	## | `Exact(v)` | The 3 versions nearest to `v` in the version order. The sorted list is split where `v` would go. Then the nearest below, the nearest above, the next below, ... until 3 or none are left. |
	## | Other (a range, a series) | The 3 newest versions |
	##
	## Message (proposal, TW24): `no release of <name> matches '<selector text>'. Close versions: <v>, <v>, <v>.` With no version at all: `no release of <name> matches '<selector text>'.`
	## `<selector text>` is the text that the user typed after `@` (`9.9.9`, `^3`).
	no_release : { name : Str, selector : Try(Selector, [None]), text : Str, versions : List(Str) } -> Fail
	no_release = |facts| {
		head = "no release of ${facts.name} matches '${facts.text}'"
		match close_versions(facts.selector, facts.versions) {
			[] => usage("${head}.")
			close => usage("${head}. Close versions: ${Str.join_with(close, ", ")}.")
		}
	}

	## R-SE7 (slice 009): the notice for a platform release that changes, in `tln add --platform` (`Replace`) and in `tln update` or `tln install X@sel` (a move of the platform entry). Text (proposal, TW24):
	## `platform changes: <old name> <old version> -> <new name> <new version>`. `Add.decide` gives the same text for `Replace`. The command prints it as `note: <text>` before the ladder lines and puts it in `data.notes`.
	platform_note : { from : { name : Str, version : Str }, to : { name : Str, version : Str } } -> Str
	platform_note = |facts| "platform changes: ${facts.from.name} ${facts.from.version} -> ${facts.to.name} ${facts.to.version}"

	## R-SL12 for `tln update X@sel` (slice 009, question Q5): the close versions that the failure `no tuple works: <id> has no release that satisfies <range> (...)` gets. The text is
	## ` Close versions: <v>, <v>, <v>.` (a space first, a full stop at the end) for the versions of `close_versions` (the table of `no_release`: 3 nearest to an exact version, else the 3 newest). It is the empty
	## text when no version parses. `versions` are the versions of all candidates of the repository, in any order. The exit code stays 10 (the answer of the manager to Q2 of slice 007).
	close_note : { selector : Try(Selector, [None]), versions : List(Str) } -> Str
	close_note = |facts| match close_versions(facts.selector, facts.versions) {
		[] => ""
		close => " Close versions: ${Str.join_with(close, ", ")}."
	}

	## Q9 of slice 007 (R-WS12, Resolution 9): a new entry for a group that another member holds. `held` are the members that have the group, with the version of their entry.
	## `range` is the range of the selector of the new entry (`=2.1.0` for `@2.1.0`, `*` for no selector). When the range admits each held version, `Ok({})`: the new entry
	## gets the held version. When it excludes one, a failure of kind `NoTuple` (exit 10): moving a held version needs the prompt R-NI3, which P0 cannot ask (R-SP16, R-SP17: design gap).
	## Message (proposal, TW24): `no tuple works: '<range>' for <name> excludes the version <v> held by <file>, <file>. Moving a held version needs consent (R-NI3), which this version of tln cannot ask. Nothing was written.`
	## `<v>` and the files are those of the first held version that the range excludes (the files in the order of `held` that have that version).
	check_held : { name : Str, range : Str, held : List({ file : Str, version : Str }) } -> Try({}, Fail)
	check_held = |facts| match facts.held.find_first(|h| !Ranges.admits({ ranges: [facts.range], version: h.version })) {
		Err(_) => Ok({})
		Ok(first) => {
			files = facts.held.keep_if(|h| h.version == first.version).map(|h| h.file)
			Err(
				Fail.new(
					NoTuple,
					"no tuple works: '${facts.range}' for ${facts.name} excludes the version ${first.version} held by ${Str.join_with(files, ", ")}. Moving a held version needs consent (R-NI3), which this version of tln cannot ask. Nothing was written.",
				),
			)
		}
	}
}

HeaderRow : { alias : Str, url : Str, is_platform : Bool }

usage : Str -> Fail
usage = |message| Fail.new(Usage, message)

# R-SL5, R-AD21, Q9: no selector and `latest` both mean no move.
no_move : Try(Selector, [None]) -> Bool
no_move = |selector| match selector {
	Err(None) => Bool.True
	Ok(Latest) => Bool.True
	Ok(_) => Bool.False
}

# R-AD23 to R-AD28: the `talon.toml` pair for a selector. Q8: `--no-pin` only drops an exact version.
toml_of : Str, Try(Selector, [None]), Bool -> Try({ key : Str, value : Str }, [Nothing])
toml_of = |key, selector, no_pin| match selector {
	Ok(Exact(version)) => if no_pin Err(Nothing) else Ok({ key, value: "=${version}" })
	Ok(Range(text)) => Ok({ key, value: text })
	_ => Err(Nothing)
}

# `<name> <version>` of a release URL. A URL that Talon cannot read (a path) stands for itself.
describe : Str -> Str
describe = |url| match Ident.of_url(url) {
	Ok(ident) => "${ident.name ?? url} ${ident.version}"
	Err(Foreign) => url
}

# A new package (R-AD23). An entry of the header with the group, or (Q11) the only entry of the repo, is not a new entry.
decide_package : { selector : Try(Selector, [None]), chosen : { name : Str, url : Str, kind : [Package, Platform] }, platform_flag : Bool, no_pin : Bool, as_alias : Try(Str, [Unset]), header : List(HeaderRow) } -> Try(Add, Fail)
decide_package = |req| {
	chosen = Alias.choose({ name: req.chosen.name, url: req.chosen.url, is_platform: Bool.False, as_alias: req.as_alias, header: req.header })
	move = |alias| Add.decide_alias({ alias, selector: req.selector, no_pin: req.no_pin, header: req.header })
	match chosen {
		Ok(Alias.Existing(alias)) => move(alias)
		_ => match only_entry_of_repo(req.chosen.name, req.as_alias, req.header) {
			Ok(alias) => move(alias)
			Err(NoEntry) => match chosen {
				Ok(Alias.New(alias)) => Ok(insert(alias, req.chosen.url, req.selector, req.no_pin))
				Ok(Alias.Existing(alias)) => move(alias)
				Ok(Alias.Unmanaged(_alias)) => crash "todo"
				Err(fail) => Err(fail)
			}
		}
	}
}

# Q11: with no `--as`, a name that is in the header with one entry names that entry, also in another series.
only_entry_of_repo : Str, Try(Str, [Unset]), List(HeaderRow) -> Try(Str, [NoEntry])
only_entry_of_repo = |name, as_alias, header| match as_alias {
	Ok(_) => Err(NoEntry)
	Err(Unset) => match header.keep_if(|row| repo_of(row.url) == Ok(name)) {
		[one] => Ok(one.alias)
		_ => Err(NoEntry)
	}
}

repo_of : Str -> Try(Str, [NoName])
repo_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.name
	Err(Foreign) => Err(NoName)
}

insert : Str, Str, Try(Selector, [None]), Bool -> Add
insert = |alias, url, selector, no_pin| {
	alias,
	header: Insert,
	url,
	toml: toml_of(alias, selector, no_pin),
	note: Err(None),
}

# R-AD29 to R-AD31, R-SE7: a header has one platform. It is replaced under its alias, or a new one is added.
decide_platform : { selector : Try(Selector, [None]), chosen : { name : Str, url : Str, kind : [Package, Platform] }, platform_flag : Bool, no_pin : Bool, as_alias : Try(Str, [Unset]), header : List(HeaderRow) } -> Try(Add, Fail)
decide_platform = |req| match req.header.find_first(|row| row.is_platform) {
	Ok(old) => Ok({
		alias: old.alias,
		header: Replace,
		url: req.chosen.url,
		toml: toml_of(old.alias, req.selector, req.no_pin),
		note: if old.url == req.chosen.url Err(None) else Ok("platform changes: ${describe(old.url)} -> ${req.chosen.name} ${version_of(req.chosen.url)}"),
	})
	Err(NotFound) => match Alias.choose({ name: req.chosen.name, url: req.chosen.url, is_platform: Bool.True, as_alias: req.as_alias, header: req.header }) {
		Ok(Alias.New(alias)) => Ok(insert(alias, req.chosen.url, req.selector, req.no_pin))
		Ok(Alias.Existing(alias)) => Add.decide_alias({ alias, selector: req.selector, no_pin: req.no_pin, header: req.header })
		Ok(Alias.Unmanaged(_alias)) => crash "todo"
		Err(fail) => Err(fail)
	}
}

version_of : Str -> Str
version_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.version
	Err(Foreign) => url
}

# R-SL12: at most 3 versions, newest first. An exact version gets the nearest ones (below first, then above, and so on).
close_versions : Try(Selector, [None]), List(Str) -> List(Str)
close_versions = |selector, versions| {
	newest_first = sorted(versions).rev()
	picked = match selector {
		Ok(Exact(wanted)) => match Semver.parse(wanted) {
			Ok(target) => {
				below = newest_first.keep_if(|v| is_before(v, target))
				above = newest_first.keep_if(|v| is_after(v, target)).rev()
				nearest(below, above, 3)
			}
			Err(_) => newest_first.take_first(3)
		}
		_ => newest_first.take_first(3)
	}
	sorted(picked).rev()
}

# The versions of the list that parse, in the version order (lowest first).
sorted : List(Str) -> List(Str)
sorted = |versions| versions
	.keep_oks(|text| Semver.parse(text).map_ok(|v| (text, v)))
	.sort_with(|(_, a), (_, b)| a.order_relative_to(b))
	.map(|(text, _)| text)

is_before : Str, Semver -> Bool
is_before = |text, other| match Semver.parse(text) {
	Ok(v) => v.order_relative_to(other) == Before
	Err(_) => Bool.False
}

is_after : Str, Semver -> Bool
is_after = |text, other| match Semver.parse(text) {
	Ok(v) => v.order_relative_to(other) == After
	Err(_) => Bool.False
}

# `below` (nearest first) and `above` (nearest first) take turns, below first.
nearest : List(Str), List(Str), U64 -> List(Str)
nearest = |below, above, count| if count == 0 {
	[]
} else {
	match below {
		[first, .. as rest] => [first].concat(nearest(above, rest, count - 1))
		[] => above.take_first(count)
	}
}
