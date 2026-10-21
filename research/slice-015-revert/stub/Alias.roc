import Fail
import Ident

## The alias of a new header entry in `tln add` (CLI 2, R-AD8 to R-AD19).
## The value is the result of `choose`: `New(alias)` is the alias of an entry to add.
## `Existing(alias)` says that the header already has the group under this alias: `tln add` adds no entry
## and reports the alias (R-AD19, R-AD20, Design 4.3 R-I9).
## `Unmanaged(alias)` says that `--as <alias>` names an unmanaged entry (a path entry or a foreign URL, Design 4.2, R-H4): `tln add` replaces that whole entry
## with the release, under the same alias (R-AD38, R-H9). Only `--as` gives it: the default alias never replaces an entry (R-AD18).
##
## The default alias (`default`):
##
## | Step | Rule |
## | --- | --- |
## | 0 | Take the repo name, the text after the last `/` (R-AD8, R-AD9). For a platform the alias is `pf` (R-AD13), not this. |
## | 1 | Drop a leading `roc-` (R-AD11, R-AD12). No other prefix or suffix. |
## | 2 | Change each `-` and `.` to `_` (R-AD15) |
##
## The checks (R-AD14), for the default alias and for `--as`, in this order:
##
## | # | Check | Failure (kind `Usage`) |
## | --- | --- | --- |
## | 1 | Starts with a lowercase ASCII letter, and has only ASCII letters, digits and `_` (R-AD16) | `NotName` |
## | 2 | Is not a reserved word (R-AD17). The design names `app`, `package`, `module`, `import`, `if`, `match`, `for`. The full list is question Q5. | `Reserved` |
## | 3 | No header entry has this alias for another group (R-AD18). An alias of an unmanaged entry is free for `--as` (the result is `Unmanaged`, R-AD19, R-AD38), and taken for the default alias (R-AD18). Never a suffix. | `Taken` |
##
## Texts of the failures (proposal, slice 004, "Output"). `<a>` is the alias, `<name>` the full name:
##
## | Failure | Default alias | With `--as` |
## | --- | --- | --- |
## | `NotName` | `the default alias '<a>' for '<name>' is not a valid name. Use --as <alias>.` | `'<a>' is not a valid alias. Use letters, digits and _, and start with a lowercase letter.` |
## | `Reserved` | `the default alias '<a>' for '<name>' is a reserved word. Use --as <alias>.` | `'<a>' is a reserved word, not a valid alias.` |
## | `Taken` | `the default alias '<a>' for '<name>' is used by another package in the header. Use --as <alias>.` | `alias '<a>' is used by another package in the header.` |
## | `Taken`, the entry is a path entry or a foreign URL (default alias only, R-AD18, R-AD38) | `the default alias '<a>' for '<name>' is used by a path entry in the header. Use --as <alias>, or --as <a> to replace that entry.` (`a foreign URL` for a foreign entry) | (no failure: `Unmanaged`) |
Alias := [New(Str), Existing(Str), Unmanaged(Str)].{
	is_eq : _

	## The default alias text of a full name, after steps 0 to 2. It is not checked.
	default : Str -> Str
	default = |name| {
		repo = match name.split_last("/") {
			Ok({ after, .. }) => after
			Err(NotFound) => name
		}
		repo.drop_prefix("roc-").replace_each("-", "_").replace_each(".", "_")
	}

	## The checks 1 and 2 of an alias text.
	check : Str -> Try({}, [NotName, Reserved])
	check = |alias| {
		bytes = alias.to_utf8()
		first_ok = match bytes.first() {
			Ok(b) => b >= 'a' and b <= 'z'
			Err(ListWasEmpty) => Bool.False
		}
		if !(first_ok and bytes.all(is_name_byte)) {
			Err(NotName)
		} else if reserved.contains(alias) {
			Err(Reserved)
		} else {
			Ok({})
		}
	}

	## The alias for a new entry. `url` is the release URL of the candidate, `name` its full name.
	## `header` has one row for each entry of the header: its alias, its value (a URL, or a path), and whether it is the platform.
	## Order: when the group of `url` is in the header (an entry whose URL has the same group key, R-ID2)
	## the result is `Existing` with the alias of that entry, with no other check (R-AD19, R-I9).
	## Else `--as`, or `pf` for a platform (R-AD13, R-AD30), or the default alias, goes through the checks 1 to 3.
	choose : {
		name : Str,
		url : Str,
		is_platform : Bool,
		as_alias : Try(Str, [Unset]),
		header : List({ alias : Str, url : Str, is_platform : Bool }),
	} -> Try(Alias, Fail)
	choose = |req| match in_header(req.url, req.header) {
		Ok(alias) => Ok(Existing(alias))
		Err(NotFound) => new_alias(req)
	}
}

# Q5: the keywords of Roc on the pinned nightly (the list of the roc-syntax MCP), and `roc`, the key of the compiler pin.
reserved : List(Str)
reserved = [
	"app",
	"platform",
	"package",
	"packages",
	"requires",
	"provides",
	"exposes",
	"targets",
	"hosted",
	"import",
	"as",
	"exposing",
	"module",
	"interface",
	"generates",
	"with",
	"has",
	"implements",
	"where",
	"if",
	"else",
	"match",
	"var",
	"for",
	"while",
	"return",
	"break",
	"crash",
	"dbg",
	"expect",
	"in",
	"and",
	"or",
	"roc",
]

is_name_byte : U8 -> Bool
is_name_byte = |b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '_'

# R-AD19, R-I9: the alias of the header entry that has the group of the URL.
in_header : Str, List({ alias : Str, url : Str, is_platform : Bool }) -> Try(Str, [NotFound])
in_header = |url, header| match Ident.of_url(url) {
	Err(Foreign) => Err(NotFound)
	Ok(ident) => match header.find_first(|row| same_group(row.url, ident.group)) {
		Ok(row) => Ok(row.alias)
		Err(NotFound) => Err(NotFound)
	}
}

same_group : Str, { form : Str, series : Str } -> Bool
same_group = |url, group| match Ident.of_url(url) {
	Ok(other) => other.group == group
	Err(Foreign) => Bool.False
}

# R-AD13, R-AD30, R-AD14 to R-AD18: `--as`, or `pf`, or the default alias, through the 3 checks.
new_alias : { name : Str, url : Str, is_platform : Bool, as_alias : Try(Str, [Unset]), header : List({ alias : Str, url : Str, is_platform : Bool }) } -> Try(Alias, Fail)
new_alias = |req| {
	alias = match req.as_alias {
		Ok(a) => a
		Err(Unset) => if req.is_platform "pf" else Alias.default(req.name)
	}
	refuse = |why| Err(Fail.new(Usage, refusal(why, alias, req.name, req.as_alias.is_ok())))
	match Alias.check(alias) {
		Err(NotName) => refuse(NotName)
		Err(Reserved) => refuse(Reserved)
		Ok({}) => if req.header.any(|row| row.alias == alias) refuse(Taken) else Ok(New(alias))
	}
}

# The texts of the failures (proposal, slice 004, "Output"). `given` is true for `--as`.
refusal : [NotName, Reserved, Taken], Str, Str, Bool -> Str
refusal = |why, alias, name, given| {
	own = "the default alias '${alias}' for '${name}'"
	match (why, given) {
		(NotName, Bool.True) => "'${alias}' is not a valid alias. Use letters, digits and _, and start with a lowercase letter."
		(NotName, Bool.False) => "${own} is not a valid name. Use --as <alias>."
		(Reserved, Bool.True) => "'${alias}' is a reserved word, not a valid alias."
		(Reserved, Bool.False) => "${own} is a reserved word. Use --as <alias>."
		(Taken, Bool.True) => "alias '${alias}' is used by another package in the header."
		(Taken, Bool.False) => "${own} is used by another package in the header. Use --as <alias>."
	}
}
