import Fail
import Ident
import Ref
import Scope
import Selector

## Lookup of a name in a scope, with no registry (`direct`, CLI 2, R-SC6 to R-SC8, R-SC14, R-AD1, R-AD2, R-AD6, R-AD7).
## The registry path (R-AD3 to R-AD5, R-AD34 to R-AD36) is a later slice. It adds a result and a parameter.
##
## `Existing(entity)` is an entity of the scope. `New(name)` is a full name that is not looked up in the scope:
## `tln add` uses it with the index (R-AD2: no search).
##
## The entities (`entities`) are given by the caller. One row for each entity:
##
## | Field | Holds |
## | --- | --- |
## | `alias` | The header alias of a direct entry, else `""` (a transitive package, an installed tool: its binary name) |
## | `name` | The full name: `owner/repo`, or `host/path` |
## | `note` | The text of the tie list (R-SC14): `platform (pf)`, `via web-utils` |
##
## The forms, in order, first match wins (R-SC6 to R-SC8):
##
## | # | Form | Matches an entity when | Scopes |
## | --- | --- | --- | --- |
## | 1 | Alias | `alias == text` (exact) | all |
## | 2 | Full name | `name == text` | `Project`, `Tool`, `X`. In `Install`: no match in the entities, the result is `New(name)` (R-AD2). |
## | 3 | Short name | The repo name of `name`, or the repo name with a leading `roc-` dropped, equals the text. Only a `name` with exactly one `/` (R-SN3: `host/path` never matches). It must match one entity (R-SC8). | `Project`, `Tool`, `X`. In `Install`: never, see below. |
##
## `Install` (R-AD1, R-SC2): only form 1 looks in the entities. A full name is `New(name)`.
## A short name is a failure with no registry (R-AD6).
##
## The scope `Roc` is P1: `find` gives a failure of kind `Internal`, `scope 'roc' is not built yet`.
##
## Failures (all kind `Usage`, R-EC2). Texts are a proposal (slice 004, "Output"):
##
## | Case | Message | Block |
## | --- | --- | --- |
## | Short name, `Install`, no alias (R-AD6) | `'<x>' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).` | `""` |
## | Short name, `Tool` or `X`, no local match (R-AD7) | `'<x>' matches no installed tool or cached app. Use the full name (owner/repo).` | `""` |
## | No match, `Project` (question Q7) | `'<x>' is not in the project` | `""` |
## | 2 or more matches of form 3 (R-SC14) | `"<x>" matches <n> packages. Use the full name.` | The list of the design, see below |
##
## The block of a tie is printed on stderr before the failure line. It holds the first line `"<x>" matches <n> packages:`,
## then one line for each match in the order of the entities: 2 spaces, the name, the spaces that pad to the longest name plus 6,
## the note. Each line ends with a newline.
Lookup := [
	Existing({ alias : Str, name : Str }),
	New(Str),
].{
	is_eq : _

	## `find(scope, ref, entities)`. The selector of `ref` is read only to pick one of 2 or more entries of one repo (Q12).
	## The caller gives such an entry with its series in the name: `roc-lang/http@1` and `roc-lang/http@2`
	## (R-SC15). The typed name `roc-lang/http` with the selector `@2` or `@^2.1` is the series-2 entry.
	## Forms 2 and 3 compare the name with no `@series`. No match of the series is a tie (R-SC14).
	find : Scope, Ref, List({ alias : Str, name : Str, note : Str }) -> Try(Lookup, { fail : Fail, block : Str })
	find = |scope, ref, entities| match scope {
		Roc => Err({ fail: Fail.new(Internal, "scope 'roc' is not built yet"), block: "" })
		Install => find_install(ref, entities)
		_ => find_local(scope, ref, entities)
	}
}

Entity : { alias : Str, name : Str, note : Str }

failure : Str -> { fail : Fail, block : Str }
failure = |message| { fail: Fail.new(Usage, message), block: "" }

# The name of an entity with no `@series` (Q12).
base_name : Str -> Str
base_name = |name| match name.split_first("@") {
	Ok({ before, .. }) => before
	Err(NotFound) => name
}

by_alias : Ref, List(Entity) -> Try(Lookup, [NotFound])
by_alias = |ref, entities| match ref.form {
	Bare => match entities.find_first(|e| e.alias == ref.name) {
		Ok(e) => Ok(Existing({ alias: e.alias, name: e.name }))
		Err(NotFound) => Err(NotFound)
	}
	_ => Err(NotFound)
}

# R-AD1, R-AD2, R-AD6: only a header alias is looked up. A full name is not searched. A short name has no index.
find_install : Ref, List(Entity) -> Try(Lookup, { fail : Fail, block : Str })
find_install = |ref, entities| match by_alias(ref, entities) {
	Ok(found) => Ok(found)
	Err(NotFound) => match ref.form {
		Bare => Err(failure("'${ref.name}' is a short name, and GitHub has no index of short names. Use the full name (owner/repo)."))
		_ => Ok(New(ref.name))
	}
}

# R-SC6 to R-SC8: the forms in order, first match wins.
find_local : Scope, Ref, List(Entity) -> Try(Lookup, { fail : Fail, block : Str })
find_local = |scope, ref, entities| match by_alias(ref, entities) {
	Ok(found) => Ok(found)
	Err(NotFound) => match ref.form {
		Bare => pick(ref, entities.keep_if(|e| short_matches(e.name, ref.name)), missing(scope, ref))
		_ => pick(ref, entities.keep_if(|e| base_name(e.name) == ref.name), full_missing(scope, ref))
	}
}

# R-SC8: the repo name, or the repo name with no leading `roc-`. The entity name has exactly one `/` (R-SN3).
short_matches : Str, Str -> Bool
short_matches = |name, short| match base_name(name).split_on("/") {
	[_, repo] => repo == short or repo.drop_prefix("roc-") == short
	_ => Bool.False
}

# What a name that matches nothing gives: R-AD6 and R-AD7 for a short name, Q7 for the project.
missing : Scope, Ref -> Try(Lookup, { fail : Fail, block : Str })
missing = |scope, ref| match scope {
	Project => Err(failure("'${ref.name}' is not in the project"))
	_ => Err(failure("'${ref.name}' matches no installed tool or cached app. Use the full name (owner/repo)."))
}

# A full name with no entity: `Tool` and `X` give `New` (the index), `Project` stops.
full_missing : Scope, Ref -> Try(Lookup, { fail : Fail, block : Str })
full_missing = |scope, ref| match scope {
	Project => Err(failure("'${ref.name}' is not in the project"))
	_ => Ok(New(ref.name))
}

# One match is the result. 2 or more: the series of the selector picks one (Q12), else a tie (R-SC14).
pick : Ref, List(Entity), Try(Lookup, { fail : Fail, block : Str }) -> Try(Lookup, { fail : Fail, block : Str })
pick = |ref, matches, none| match matches {
	[] => none
	[one] => Ok(Existing({ alias: one.alias, name: one.name }))
	_ => match by_series(ref, matches) {
		Ok(one) => Ok(Existing({ alias: one.alias, name: one.name }))
		Err(NotFound) => Err(tie(ref.name, matches))
	}
}

by_series : Ref, List(Entity) -> Try(Entity, [NotFound])
by_series = |ref, matches| match ref.selector {
	Err(None) => Err(NotFound)
	Ok(selector) => match series_of(selector) {
		Err(NoSeries) => Err(NotFound)
		Ok(series) => {
			named = matches.keep_if(|e| e.name == "${ref.name}@${series}")
			match named {
				[one] => Ok(one)
				_ => Err(NotFound)
			}
		}
	}
}

# The series that a selector names (R-SC15): `^2`, `2.1.0` give `2`. `^0.25` gives `0.25`.
series_of : Selector -> Try(Str, [NoSeries])
series_of = |selector| match selector {
	Exact(version) => Ident.series_of(version).map_err(|_| NoSeries)
	Range(text) => match text.drop_prefix("^").drop_prefix("=").split_on(".") {
		["0", minor, ..] => Ok("0.${minor}")
		[major, ..] if major != "0" and major != "" => Ok(major)
		_ => Err(NoSeries)
	}
	_ => Err(NoSeries)
}

# R-SC14: the failure line, and the block that goes to stderr before it.
tie : Str, List(Entity) -> { fail : Fail, block : Str }
tie = |text, matches| {
	count = matches.len().to_str()
	width = (matches.map(|e| e.name.count_utf8_bytes()).max() ?? 0) + 6
	lines = matches.map(|e| "  ${e.name}${" ".repeat(width - e.name.count_utf8_bytes())}${e.note}\n")
	{
		fail: Fail.new(Usage, "\"${text}\" matches ${count} packages. Use the full name."),
		block: "\"${text}\" matches ${count} packages:\n${Str.join_with(lines, "")}",
	}
}
