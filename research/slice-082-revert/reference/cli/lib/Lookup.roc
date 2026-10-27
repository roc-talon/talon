import Fail
import Ident
import Ranges
import Ref
import Scope
import Selector

## Lookup of a name in a scope, with no registry (`direct`, CLI 2, R-SC1, R-SC6 to R-SC8, R-SC14 to R-SC16, R-WS8, R-AD1, R-AD2, R-AD6, R-AD7).
## The registry path (R-AD3 to R-AD5, R-AD34 to R-AD36) is a later slice. It adds a result and a parameter.
##
## Slice 014 (one name model, `docs/design-gaps/G-tie-names.md`): `add`, `update`, `remove` and `why` all build their entities with `build` (one builder) and read
## a name with `find` (a command that does not move an entry) or `find_move` (a command that moves an entry).
##
## `Existing(entity)` is an entity of the scope: its `alias`, `name` and `series` (the 3 fields name one entity). `New(name)` is a full name that is not looked up in the scope:
## `tln add` uses it with the index (R-AD2: no search).
##
## An entity (`Lookup.Entity`) is one package of the scope. One row for each entity:
##
## | Field | Holds |
## | --- | --- |
## | `alias` | The header alias of a direct entry, else `""` (a transitive package, an installed tool: its binary name) |
## | `name` | The full name: `owner/repo`, or `host/path`. Never has `@series`. `""` for an unmanaged entry (R-SC6: a path entry or a foreign URL has no full name, its alias is its only name). |
## | `series` | The series of the group (Design 2): `1`, `0.25`. `""` for an unmanaged entry. |
## | `version` | `Ok(<version>)` of a release. `Err(None)` for an unmanaged entry (R-SC16: it has no version). |
## | `note` | The text of the tie list (R-SC14): `platform (pf)`, `direct (json)`, `via web_utils` |
##
## The forms, in order, first match wins (R-SC6 to R-SC8):
##
## | # | Form | Matches an entity when | Scopes |
## | --- | --- | --- | --- |
## | 1 | Alias | `alias == text` (exact). 2 or more entities with this alias (R-WS8: members use one alias for 2 groups) are 2 or more matches. | all |
## | 2 | Full name | `name == text` | `Project`, `Tool`, `X`. In `Install`: no match in the entities, the result is `New(name)` (R-AD2). |
## | 3 | Short name | The repo name of `name`, or the repo name with a leading `roc-` dropped, equals the text. Only a `name` with exactly one `/` (R-SN3: `host/path` never matches). | `Project`, `Tool`, `X`. In `Install`: never, see below. |
##
## `Install` (R-AD1, R-SC2): only form 1 looks in the entities. A full name is `New(name)`.
## A short name is a failure with no registry (R-AD6).
##
## The selector of the ref narrows the matches of the form that matched (R-SC16), in the scopes `Project` and (for `find_move` only) `Install`. The scopes `Tool` and `X` ignore it.
##
## `find_move` with the scope `Install` (`tln add <full name>@sel`, slice 014 Q1: R-SC16 wins over the "no search" of R-AD2, which means no registry search): form 1 and form 2 look in the entities, there is no short name form.
## A full name with no entity is `New(name)`, a short name with no alias is the failure of R-AD6. `PickFlow.asked!` calls it for a full name that matches 2 or more entities of the member (one entity is Q11 of slice 004,
## `entry_of_repo`), when the command has no `--as` and no `--platform`. So `tln add roc-lang/http@3` with `http1` and `http2` is the tie with the alias line, `tln add roc-lang/http@2` is the entry `http2`.
## `find` with the scope `Install` is as before (form 1 only).
##
## | Command | `X@sel` means | 1 match | 2 or more matches |
## | --- | --- | --- | --- |
## | `find` (does not move: `why`, `remove`, `patch`, `probe`) | The version of the entity is in `sel`. `@2` is `^2` (R-SL4), `latest` is any version, an `Exact` version is that version. An unmanaged entry has no version: it never matches a name with a selector. | Must be in `sel`, else `'<x>' is not in the project` | Keep those in `sel`. 1 left: used. 0 left: `'<x>' is not in the project`. 2 or more: a tie. |
## | `find_move` (moves: `update`; `add` of an alias) | The target (R-SP5). It is no filter. | Used, also for a new series | Keep those in the series of `sel` (`series_of`). 1 left: used. Else a tie. A selector with no single series (`latest`, `0.x`, `*`) keeps all matches. |
##
## `<x>` is the name as typed, with `@<sel>` when the ref has a selector (`json@3`, `acme/text@2.5.0`). `<sel>` is the text of `Selector.Range` without a leading `^`, or the `Exact` version, or `latest`.
## The scope `Roc` is P1: `find` gives a failure of kind `Internal`, `scope 'roc' is not built yet`.
##
## Failures (all kind `Usage`, R-EC2). Texts are a proposal (slice 004 and slice 014, "Output"):
##
## | Case | Message | Block |
## | --- | --- | --- |
## | Short name, `Install`, no alias (R-AD6) | `'<x>' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).` | `""` |
## | Short name, `Tool` or `X`, no local match (R-AD7) | `'<x>' matches no installed tool or cached app. Use the full name (owner/repo).` | `""` |
## | No match, or none in `sel`, `Project` (question Q7) | `'<x>' is not in the project` | `""` |
## | A tie (R-SC14), also an alias of 2 groups (R-WS8) | `"<name>" matches <n> packages. Use a name from the list.` | The list, see below |
## | A tie of `find_move`, the selector has a series and no match is in it, and each match has its own alias | `"<name>" matches <n> packages. Use the alias of the entry to move: tln update <alias of the first match>@<sel>` | The list |
##
## `<name>` of a tie is the typed name with no selector. The block of a tie is printed on stderr before the failure line. It holds the first line `"<name>" matches <n> packages:`,
## then one line for each match in the order of the entities: 2 spaces, the printed name (`printed`), the spaces that pad to the longest printed name plus 6, the note.
## Each line ends with a newline. The printed names use the whole scope (R-SC15), not only the matches.
Lookup := [
	Existing({ alias : Str, name : Str, series : Str }),
	New(Str),
].{
	is_eq : _

	## One package of a scope (the table above).
	Entity : { alias : Str, name : Str, series : Str, version : Try(Str, [None]), note : Str }

	## What a command knows of one package of its scope. `build` makes an entity of it.
	##
	## | Field | Holds |
	## | --- | --- |
	## | `alias` | The header alias of a direct entry, else `""` |
	## | `what` | `Release` with the full name, the series and the version. `Unmanaged` for a path entry or a foreign URL (Design 4.2, R-H4, R-SC6). |
	## | `role` | `Platform` (the platform entry), `Direct` (another header entry), `Via(alias)` (a transitive package, `alias` is the header alias of the entry that needs it) |
	Fact : { alias : Str, what : [Release({ name : Str, series : Str, version : Str }), Unmanaged], role : [Platform, Direct, Via(Str)] }

	## The one entity builder of `add`, `update`, `remove` and `why` (R-SC1, R-SC14, R-SC15). One entity for each fact, in the order of the facts.
	##
	## | Fact | Entity |
	## | --- | --- |
	## | `Release` | `name`, `series` as given, `version: Ok(version)` |
	## | `Unmanaged` | `name: ""`, `series: ""`, `version: Err(None)` |
	## | `role` | `note`: `platform (<alias>)`, `direct (<alias>)`, `via <alias of Via>` |
	##
	## A fact with an alias (not `""`) whose `alias`, `name` and `series` equal those of an earlier fact is left out (members of a workspace share an entry).
	## Facts with no alias are never left out. The alias of a second group is not changed: the same alias with 2 groups is 2 entities (R-WS8).
	build : List(Lookup.Fact) -> List(Lookup.Entity)
	build = |facts| facts.fold(
		[],
		|built, fact| {
			entity = entity_of(fact)
			repeat = fact.alias != "" and built.any(|o| o.alias == entity.alias and o.name == entity.name and o.series == entity.series)
			if repeat built else built.append(entity)
		},
	)

	## The name of an entity that the user types (R-SC15): the full name, with `@<series>` when the scope (all of its entities, not only the matches) has 2 or more series of that full name.
	## An entity with no full name (an unmanaged entry) prints its alias.
	printed : List(Lookup.Entity), Lookup.Entity -> Str
	printed = |entities, entity| if entity.name == "" {
		entity.alias
	} else if entities.any(|o| o.name == entity.name and o.series != entity.series) {
		"${entity.name}@${entity.series}"
	} else {
		entity.name
	}

	## `find(scope, ref, entities)`: a command that does not move an entry (`why`, `remove`). The table above.
	find : Scope, Ref, List(Lookup.Entity) -> Try(Lookup, { fail : Fail, block : Str })
	find = |scope, ref, entities| match scope {
		Roc => Err({ fail: Fail.new(Internal, "scope 'roc' is not built yet"), block: "" })
		Install => find_install(ref, entities)
		_ => find_local(scope, ref, entities)
	}

	## `find_move(scope, ref, entities)`: a command that moves an entry (`update`, and `add` of an alias). The table above.
	find_move : Scope, Ref, List(Lookup.Entity) -> Try(Lookup, { fail : Fail, block : Str })
	find_move = |scope, ref, entities| match scope {
		Roc => Err({ fail: Fail.new(Internal, "scope 'roc' is not built yet"), block: "" })
		Install => find_move_install(ref, entities)
		Project => find_move_project(ref, entities)
		_ => find_local(scope, ref, entities)
	}
}

failure : Str -> { fail : Fail, block : Str }
failure = |message| { fail: Fail.new(Usage, message), block: "" }

Failed : { fail : Fail, block : Str }

entity_of : Lookup.Fact -> Lookup.Entity
entity_of = |fact| {
	note = match fact.role {
		Platform => "platform (${fact.alias})"
		Direct => "direct (${fact.alias})"
		Via(from) => "via ${from}"
	}
	match fact.what {
		Release({ name, series, version }) => { alias: fact.alias, name, series, version: Ok(version), note }
		Unmanaged => { alias: fact.alias, name: "", series: "", version: Err(None), note }
	}
}

existing : Lookup.Entity -> Lookup
existing = |e| Existing({ alias: e.alias, name: e.name, series: e.series })

# R-SC6 to R-SC8: the forms in order, first match wins. An alias is form 1, a full name form 2, a short name form 3.
candidates : Ref, List(Lookup.Entity) -> List(Lookup.Entity)
candidates = |ref, entities| {
	by_alias = if ref.form == Bare entities.keep_if(|e| e.alias == ref.name) else []
	if !by_alias.is_empty() {
		by_alias
	} else if ref.form == Bare {
		entities.keep_if(|e| short_matches(e.name, ref.name))
	} else {
		entities.keep_if(|e| e.name == ref.name)
	}
}

# `Install` has no short name form: only an alias or a full name (R-AD1, R-AD2, R-AD6).
install_candidates : Ref, List(Lookup.Entity) -> List(Lookup.Entity)
install_candidates = |ref, entities| if ref.form == Bare {
	entities.keep_if(|e| e.alias == ref.name)
} else {
	entities.keep_if(|e| e.name == ref.name)
}

# R-AD1, R-AD2, R-AD6: only a header alias is looked up. A full name is not searched. A short name has no index.
find_install : Ref, List(Lookup.Entity) -> Try(Lookup, Failed)
find_install = |ref, entities| match entities.find_first(|e| ref.form == Bare and e.alias == ref.name) {
	Ok(e) => Ok(existing(e))
	Err(NotFound) => install_missing(ref)
}

install_missing : Ref -> Try(Lookup, Failed)
install_missing = |ref| match ref.form {
	Bare => Err(failure("'${ref.name}' is a short name, and GitHub has no index of short names. Use the full name (owner/repo)."))
	_ => Ok(New(ref.name))
}

# `find` for `Project`, `Tool` and `X`. Only `Project` reads the selector (D5), as a version filter (R-SC16).
find_local : Scope, Ref, List(Lookup.Entity) -> Try(Lookup, Failed)
find_local = |scope, ref, entities| {
	all = candidates(ref, entities)
	matches = if scope == Project all.keep_if(|e| in_selector(ref, e)) else all
	match matches {
		[] => if all.is_empty() missing(scope, ref) else Err(failure("'${typed(ref)}' is not in the project"))
		[one] => Ok(existing(one))
		_ => Err(tie(ref.name, entities, matches, "Use a name from the list."))
	}
}

# `find_move` for `Project` (R-SC16, R-SP5): the selector is the target, not a filter.
find_move_project : Ref, List(Lookup.Entity) -> Try(Lookup, Failed)
find_move_project = |ref, entities| match candidates(ref, entities) {
	[] => missing(Project, ref)
	all => move_pick(ref, entities, all)
}

# `find_move` for `Install` (slice 014 Q1): form 1 and form 2 look in the entities of the member.
find_move_install : Ref, List(Lookup.Entity) -> Try(Lookup, Failed)
find_move_install = |ref, entities| match install_candidates(ref, entities) {
	[] => install_missing(ref)
	all => move_pick(ref, entities, all)
}

# One match is used. 2 or more: the series of the selector keeps the entities in it (R-SC16). With no match in the series, the alias of an entry can name the one to move.
move_pick : Ref, List(Lookup.Entity), List(Lookup.Entity) -> Try(Lookup, Failed)
move_pick = |ref, entities, all| {
	plain = Err(tie(ref.name, entities, all, "Use a name from the list."))
	match all {
		[one] => Ok(existing(one))
		_ => match ref.selector {
			Err(None) => plain
			Ok(selector) => match series_of(selector) {
				Err(NoSeries) => plain
				Ok(series) => match all.keep_if(|e| e.series == series) {
					[one] => Ok(existing(one))
					[] => Err(tie(ref.name, entities, all, alias_line(all, selector)))
					_ => plain
				}
			}
		}
	}
}

# R-AU8: the last line of a tie of a move. It needs an alias for each match, and no alias twice (R-WS8 gives one alias to 2 groups).
alias_line : List(Lookup.Entity), Selector -> Str
alias_line = |all, selector| {
	aliases = all.map(|e| e.alias)
	distinct = aliases.all(|a| a != "" and aliases.keep_if(|b| b == a).len() == 1)
	match aliases.first() {
		Ok(first) if distinct => "Use the alias of the entry to move: tln update ${first}@${selector_text(selector)}"
		_ => "Use a name from the list."
	}
}

# R-SC8: the repo name, or the repo name with no leading `roc-`. The entity name has exactly one `/` (R-SN3).
short_matches : Str, Str -> Bool
short_matches = |name, short| match name.split_on("/") {
	[_, repo] => repo == short or repo.drop_prefix("roc-") == short
	_ => Bool.False
}

# What a name that matches nothing gives: R-AD6 and R-AD7 for a short name, Q7 for the project.
missing : Scope, Ref -> Try(Lookup, Failed)
missing = |scope, ref| match (scope, ref.form) {
	(Project, _) => Err(failure("'${typed(ref)}' is not in the project"))
	(_, Bare) => Err(failure("'${ref.name}' matches no installed tool or cached app. Use the full name (owner/repo)."))
	_ => Ok(New(ref.name))
}

# R-SC16: the version of the entity is in the selector. An unmanaged entry has no version, so a selector never matches it.
in_selector : Ref, Lookup.Entity -> Bool
in_selector = |ref, entity| match ref.selector {
	Err(None) => Bool.True
	Ok(selector) => match (range_of(selector), entity.version) {
		(Ok(range), Ok(version)) => Ranges.admits({ ranges: [range], version })
		_ => Bool.False
	}
}

range_of : Selector -> Try(Str, [NoRange])
range_of = |selector| match selector {
	Exact(version) => Ok("=${version}")
	Range(text) => Ok(text)
	Latest => Ok("*")
	_ => Err(NoRange)
}

# The selector as typed, with no `^` (`3`, not `^3`).
selector_text : Selector -> Str
selector_text = |selector| match selector {
	Exact(version) => version
	Range(text) => text.drop_prefix("^")
	Latest => "latest"
	Nightly(text) | GitSha(text) | GitRef(text) => text
	Step(_) => ""
}

# The name as typed, with `@<selector>` when there is one.
typed : Ref -> Str
typed = |ref| match ref.selector {
	Ok(selector) => "${ref.name}@${selector_text(selector)}"
	Err(None) => ref.name
}

# The series that a selector names (R-SC15): `^2`, `2.1.0` give `2`. `^0.25` gives `0.25`. `latest`, `*`, `0.x`, `>=1.0.0` and `^0` name no single series.
series_of : Selector -> Try(Str, [NoSeries])
series_of = |selector| match selector {
	Exact(version) => Ident.series_of(version).map_err(|_| NoSeries)
	Range(text) => {
		parts = text.drop_prefix("^").drop_prefix("=").split_on(".")
		if parts.all(is_number) {
			match parts {
				["0", minor, ..] => Ok("0.${minor}")
				[major, ..] if major != "0" => Ok(major)
				_ => Err(NoSeries)
			}
		} else {
			Err(NoSeries)
		}
	}
	_ => Err(NoSeries)
}

is_number : Str -> Bool
is_number = |text| !text.is_empty() and text.to_utf8().all(|b| b >= '0' and b <= '9')

# R-SC14: the failure line, and the block that goes to stderr before it. The names of the list are the printed names of the whole scope (R-SC15).
tie : Str, List(Lookup.Entity), List(Lookup.Entity), Str -> Failed
tie = |text, entities, matches, last| {
	count = matches.len().to_str()
	names = matches.map(|e| Lookup.printed(entities, e))
	width = (names.map(|n| n.count_utf8_bytes()).max() ?? 0) + 6
	lines = matches.map2(names, |e, n| "  ${n}${" ".repeat(width - n.count_utf8_bytes())}${e.note}\n")
	{
		fail: Fail.new(Usage, "\"${text}\" matches ${count} packages. ${last}"),
		block: "\"${text}\" matches ${count} packages:\n${Str.join_with(lines, "")}",
	}
}
