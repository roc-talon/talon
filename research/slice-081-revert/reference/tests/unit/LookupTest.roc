import lib.Fail
import lib.Lookup
import lib.Ref
import lib.Scope

LookupTest :: [].{}

# One entity: the alias, the full name, the series, the version and the note.
ent = |alias, name, series, version, note| { alias, name, series, version: Ok(version), note }

# An unmanaged entry (a path entry or a foreign URL, R-SC6): no full name, no series, no version.
unmanaged = |alias, note| { alias, name: "", series: "", version: Err(None), note }

# The reference is parsed with the code of `Ref` (tested in `ref.roc`). The failure is one text: the stderr line and the block.
shown = |found| match found {
	Ok(f) => Ok(f)
	Err(e) => Err("${Fail.line(e.fail)}|${e.block}")
}

find = |scope, text, entities| match Ref.parse(text, scope, Bool.False) {
	Err(f) => Err("ref: ${Fail.line(f)}")
	Ok(ref) => shown(Lookup.find(scope, ref, entities))
}

# The same for a command that moves an entry (`update`).
find_move = |scope, text, entities| match Ref.parse(text, scope, Bool.False) {
	Err(f) => Err("ref: ${Fail.line(f)}")
	Ok(ref) => shown(Lookup.find_move(scope, ref, entities))
}

existing = |alias, name, series| Ok(Lookup.Existing({ alias, name, series }))

tie_text = |name, n, last, lines| Err("tln: error[usage]: \"${name}\" matches ${n} packages. ${last}|\"${name}\" matches ${n} packages:\n${Str.join_with(lines, "")}")

use_list = "Use a name from the list."

header = [
	ent("pf", "roc-lang/basic-cli", "0.25", "0.25.0", "platform (pf)"),
	ent("json", "someone/roc-json", "2", "2.1.0", "direct (json)"),
	ent("parser", "lukewilliamboswell/roc-parser", "2", "2.0.0", "direct (parser)"),
]

# R-SC6 R-SC7 R-AD1 R-AD2 R-AD6 R-SC2: `tln add X` with no registry. A header alias names that entry (form 1).
# A full name is not looked up in the project: it is `New` (no search). A short name that is not an alias is an error:
# GitHub has no index of short names.
expect {
	rows = [
		("json", existing("json", "someone/roc-json", "2")),
		("pf", existing("pf", "roc-lang/basic-cli", "0.25")),
		("someone/roc-json", Ok(Lookup.New("someone/roc-json"))),
		("roc-lang/unicode", Ok(Lookup.New("roc-lang/unicode"))),
		("roc-lang/unicode@4", Ok(Lookup.New("roc-lang/unicode"))),
		("example.com/pkgs/yaml", Ok(Lookup.New("example.com/pkgs/yaml"))),
		(
			"yaml",
			Err("tln: error[usage]: 'yaml' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).|"),
		),
	]
	bad = rows.keep_if(|(text, want)| find(Scope.Install, text, header) != want).map(|(text, want)| (text, want, find(Scope.Install, text, header)))
	dbg bad
	bad == []
}

# R-SC15 R-SC1 R-SC14 R-SC16 R-WS8 (slice 014): the one entity builder. A release gives its name, series and version, an unmanaged entry has no name, series or version. The note
# is `platform (<alias>)`, `direct (<alias>)` or `via <alias>`. A fact with an alias that repeats an earlier one (same alias, name and series: a workspace member has the same entry) is left out. The same alias with
# another group stays (R-WS8). Facts with no alias stay. `printed` is the name that the user types: the full name, with `@series` when the scope has 2 series of it (R-SC15), the alias for an unmanaged entry.
expect {
	rel = |name, series, version| Release({ name, series, version })
	facts = [
		{ alias: "pf", what: rel("roc-lang/basic-cli", "0.25", "0.25.0"), role: Platform },
		{ alias: "json", what: rel("acme/json", "2", "2.1.0"), role: Direct },
		{ alias: "util", what: Unmanaged, role: Direct },
		{ alias: "", what: rel("acme/text", "1", "1.1.0"), role: Via("web") },
		{ alias: "", what: rel("acme/text", "2", "2.0.0"), role: Via("util") },
		{ alias: "json", what: rel("acme/json", "2", "2.0.0"), role: Direct },
		{ alias: "pf", what: rel("roc-lang/basic-webserver", "0.12", "0.12.0"), role: Platform },
		{ alias: "", what: Unmanaged, role: Via("util") },
		{ alias: "", what: rel("acme/text", "1", "1.1.0"), role: Via("web") },
	]
	want = [
		ent("pf", "roc-lang/basic-cli", "0.25", "0.25.0", "platform (pf)"),
		ent("json", "acme/json", "2", "2.1.0", "direct (json)"),
		unmanaged("util", "direct (util)"),
		ent("", "acme/text", "1", "1.1.0", "via web"),
		ent("", "acme/text", "2", "2.0.0", "via util"),
		ent("pf", "roc-lang/basic-webserver", "0.12", "0.12.0", "platform (pf)"),
		unmanaged("", "via util"),
		ent("", "acme/text", "1", "1.1.0", "via web"),
	]
	built = Lookup.build(facts)
	dbg built
	printed = built.map(|e| Lookup.printed(built, e))
	want_printed = ["roc-lang/basic-cli", "acme/json", "util", "acme/text@1", "acme/text@2", "roc-lang/basic-webserver", "", "acme/text@1"]
	dbg printed
	built == want and printed == want_printed and Lookup.build([]) == []
}

# R-SC1 R-SC6 R-SC7 R-SC8 R-SC14 R-SC15 R-SC16 Q12: a command that does not move an entry (`why`, `remove`). The forms in order: alias, full name, short name (the repo name, or the repo name without a
# leading `roc-`). An alias wins over a short name. A short name or a full name that matches 2 or more entities is a tie: Talon lists the printed names and ends with "Use a name from the list." (the design example). The
# series is in the printed name only when the scope has 2 series of that name (R-SC15). A selector keeps the entities whose version is in it (R-SC16, `@2` is `^2`): `text@1` (a short name with a series) and
# `roc-lang/http@2` (a full name with a series) name one entity, `json@3` names none (it is not the series-2 entry), a path entry never matches a selector.
expect {
	closure = [
		ent("pf", "roc-lang/basic-webserver", "0.12", "0.12.0", "platform (pf)"),
		ent("", "someone/basic-webserver", "1", "1.0.0", "via web_utils"),
		ent("json", "a/yaml", "2", "2.0.0", "direct (json)"),
		ent("", "b/roc-json", "1", "1.4.0", "via yaml_tools"),
		ent("", "lukewilliamboswell/roc-parser", "0", "0.9.0", "via x"),
		ent("", "example.com/pkgs/parser", "1", "1.0.0", "via y"),
		ent("", "roc-lang/unicode", "4", "4.2.0", "via z"),
		ent("http1", "roc-lang/http", "1", "1.9.0", "direct (http1)"),
		ent("http2", "roc-lang/http", "2", "2.0.0", "direct (http2)"),
		ent("", "acme/text", "1", "1.1.0", "via a"),
		ent("", "acme/text", "2", "2.0.0", "via b"),
		ent("", "other/text", "1", "1.0.0", "via c"),
		unmanaged("util", "direct (util)"),
	]
	not_in = |x| Err("tln: error[usage]: '${x}' is not in the project|")
	http_tie = tie_text("roc-lang/http", "2", use_list, ["  roc-lang/http@1      direct (http1)\n", "  roc-lang/http@2      direct (http2)\n"])
	web_tie = tie_text(
		"basic-webserver",
		"2",
		use_list,
		["  roc-lang/basic-webserver      platform (pf)\n", "  someone/basic-webserver       via web_utils\n"],
	)
	text_tie = tie_text("text", "3", use_list, ["  acme/text@1      via a\n", "  acme/text@2      via b\n", "  other/text       via c\n"])
	text1_tie = tie_text("text", "2", use_list, ["  acme/text@1      via a\n", "  other/text       via c\n"])
	rows = [
		("alias", find(Scope.Project, "pf", closure), existing("pf", "roc-lang/basic-webserver", "0.12")),
		("full name", find(Scope.Project, "someone/basic-webserver", closure), existing("", "someone/basic-webserver", "1")),
		("alias wins over a short name", find(Scope.Project, "json", closure), existing("json", "a/yaml", "2")),
		("short name, no roc-", find(Scope.Project, "unicode", closure), existing("", "roc-lang/unicode", "4")),
		("short name, roc- dropped (host/path never matches)", find(Scope.Project, "parser", closure), existing("", "lukewilliamboswell/roc-parser", "0")),
		("short name, the repo name with roc-", find(Scope.Project, "roc-parser", closure), existing("", "lukewilliamboswell/roc-parser", "0")),
		("short name tie: the design example", find(Scope.Project, "basic-webserver", closure), web_tie),
		# R-SC15 R-SC14: 2 entities of one repo. The name alone is a tie, the printed names have the series.
		("2 series, full name: a tie", find(Scope.Project, "roc-lang/http", closure), http_tie),
		# R-SC16 (P0 bug: `tln remove roc-lang/http@2` was always a tie): the version is in the selector.
		("2 series, full name with a series", find(Scope.Project, "roc-lang/http@2", closure), existing("http2", "roc-lang/http", "2")),
		("2 series, a range", find(Scope.Project, "roc-lang/http@^1.2", closure), existing("http1", "roc-lang/http", "1")),
		("2 series, an exact version", find(Scope.Project, "roc-lang/http@2.0.0", closure), existing("http2", "roc-lang/http", "2")),
		("2 series, latest keeps both: a tie", find(Scope.Project, "roc-lang/http@latest", closure), http_tie),
		("2 series, no entity in the selector", find(Scope.Project, "roc-lang/http@3", closure), not_in("roc-lang/http@3")),
		("2 series, the version is not in the series", find(Scope.Project, "roc-lang/http@2.5.0", closure), not_in("roc-lang/http@2.5.0")),
		# R-SC16 (P0 bug: `text@1`, a short name with a series, was always a tie).
		("a short name with a series", find(Scope.Project, "http@2", closure), existing("http2", "roc-lang/http", "2")),
		("a short name, 3 matches: the printed names use the whole scope", find(Scope.Project, "text", closure), text_tie),
		("a short name with a series: 2 left, `acme/text` keeps its series in the name", find(Scope.Project, "text@1", closure), text1_tie),
		("a short name with a series: 1 left", find(Scope.Project, "text@2", closure), existing("", "acme/text", "2")),
		# R-SC16 (P0 bug: `tln remove json@3` removed the series-2 entry): 1 match, the version is not in the selector.
		("1 match, not in the selector", find(Scope.Project, "json@3", closure), not_in("json@3")),
		("1 match, in the selector", find(Scope.Project, "json@2", closure), existing("json", "a/yaml", "2")),
		("1 match, an exact version", find(Scope.Project, "json@2.0.0", closure), existing("json", "a/yaml", "2")),
		("1 match, latest", find(Scope.Project, "json@latest", closure), existing("json", "a/yaml", "2")),
		("a full name, 1 match, not in the selector", find(Scope.Project, "roc-lang/unicode@5", closure), not_in("roc-lang/unicode@5")),
		# R-SC6 R-SC16: an unmanaged entry is named by its alias only, and it never matches a selector.
		("unmanaged entry, alias", find(Scope.Project, "util", closure), existing("util", "", "")),
		("unmanaged entry, a selector", find(Scope.Project, "util@1", closure), not_in("util@1")),
		("no match", find(Scope.Project, "zzz", closure), not_in("zzz")),
		("a full name that is not in the scope", find(Scope.Project, "acme/zzz", closure), not_in("acme/zzz")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-WS8 R-SC14 (slice 014): an alias that names 2 groups (members of a workspace use `pf` for 2 platforms) is a tie in the same list and with the same last line. It names no series of its own: the user types a
# name from the list. A selector keeps the entity whose version is in it (`pf@0.25`).
expect {
	workspace = [
		ent("pf", "roc-lang/basic-cli", "0.25", "0.25.0", "platform (pf)"),
		ent("pf", "roc-lang/basic-webserver", "0.12", "0.12.0", "platform (pf)"),
		ent("json", "acme/json", "2", "2.1.0", "direct (json)"),
	]
	pf_tie = tie_text("pf", "2", use_list, ["  roc-lang/basic-cli            platform (pf)\n", "  roc-lang/basic-webserver      platform (pf)\n"])
	rows = [
		("the alias of 2 groups", find(Scope.Project, "pf", workspace), pf_tie),
		("a name from the list", find(Scope.Project, "roc-lang/basic-cli", workspace), existing("pf", "roc-lang/basic-cli", "0.25")),
		("the alias with a selector", find(Scope.Project, "pf@0.12", workspace), existing("pf", "roc-lang/basic-webserver", "0.12")),
		("the alias of one group", find(Scope.Project, "json", workspace), existing("json", "acme/json", "2")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SC16 R-SC14 R-SC6 R-AU8 R-AD22 (slice 014): a command that moves an entry (`update`). The selector is the target, not a filter. One match is used, also for a new series (`json@3`, `http1@3`). With 2 or more matches the series
# of the selector keeps the entries in it. If no entry has that series, the last line asks for the alias of the entry to move, with the first alias (the design example). A selector with no series (`latest`, `*`, a range of
# 2 series) keeps all matches, so it is the plain tie. An alias that is the same for all matches (R-WS8) is no help: the plain tie.
expect {
	scoped = [
		ent("http1", "roc-lang/http", "1", "1.9.0", "direct (http1)"),
		ent("http2", "roc-lang/http", "2", "2.0.0", "direct (http2)"),
		ent("json", "acme/json", "2", "2.1.0", "direct (json)"),
		ent("t1", "acme/text", "1", "1.1.0", "direct (t1)"),
		ent("t2", "acme/text", "2", "2.0.0", "direct (t2)"),
		ent("pf", "roc-lang/basic-cli", "0.25", "0.25.0", "platform (pf)"),
		ent("pf", "roc-lang/basic-webserver", "0.12", "0.12.0", "platform (pf)"),
	]
	http_lines = ["  roc-lang/http@1      direct (http1)\n", "  roc-lang/http@2      direct (http2)\n"]
	move_text = "Use the alias of the entry to move: tln update http1@3"
	rows = [
		("1 match, a new series", find_move(Scope.Project, "json@3", scoped), existing("json", "acme/json", "2")),
		("1 match, no selector", find_move(Scope.Project, "json", scoped), existing("json", "acme/json", "2")),
		("an alias, a new series (the design example)", find_move(Scope.Project, "http1@3", scoped), existing("http1", "roc-lang/http", "1")),
		("2 matches, the series of the selector", find_move(Scope.Project, "roc-lang/http@2", scoped), existing("http2", "roc-lang/http", "2")),
		("2 matches, a range in a series", find_move(Scope.Project, "roc-lang/http@^2.1", scoped), existing("http2", "roc-lang/http", "2")),
		("2 matches, an exact version in a series", find_move(Scope.Project, "roc-lang/http@1.2.0", scoped), existing("http1", "roc-lang/http", "1")),
		("2 matches, a short name with a series", find_move(Scope.Project, "text@1", scoped), existing("t1", "acme/text", "1")),
		("2 matches, no entry has the series: the alias of the entry to move", find_move(Scope.Project, "roc-lang/http@3", scoped), tie_text("roc-lang/http", "2", move_text, http_lines)),
		("2 matches, a new series of a short name", find_move(Scope.Project, "http@3", scoped), tie_text("http", "2", move_text, http_lines)),
		("2 matches, no selector", find_move(Scope.Project, "roc-lang/http", scoped), tie_text("roc-lang/http", "2", use_list, http_lines)),
		("2 matches, latest has no series", find_move(Scope.Project, "roc-lang/http@latest", scoped), tie_text("roc-lang/http", "2", use_list, http_lines)),
		("2 matches, 0.x has no single series", find_move(Scope.Project, "roc-lang/http@0.x", scoped), tie_text("roc-lang/http", "2", use_list, http_lines)),
		("2 matches, * has no series", find_move(Scope.Project, "roc-lang/http@*", scoped), tie_text("roc-lang/http", "2", use_list, http_lines)),
		("2 matches, a range of 2 series", find_move(Scope.Project, "roc-lang/http@>=1.0.0", scoped), tie_text("roc-lang/http", "2", use_list, http_lines)),
		("the alias of 2 groups, a series", find_move(Scope.Project, "pf@0.12", scoped), existing("pf", "roc-lang/basic-webserver", "0.12")),
		(
			"the alias of 2 groups, no entry has the series: no alias to name",
			find_move(Scope.Project, "pf@0.13", scoped),
			tie_text("pf", "2", use_list, ["  roc-lang/basic-cli            platform (pf)\n", "  roc-lang/basic-webserver      platform (pf)\n"]),
		),
		("no match", find_move(Scope.Project, "zzz@1", scoped), Err("tln: error[usage]: 'zzz@1' is not in the project|")),
		# slice 014 Q1: `tln add <full name>@sel` (the scope `Install`) looks in the entities of the member for forms 1 and 2. A full name with no entity is `New`, a short name is the error of R-AD6.
		("add: a full name, the series of the selector", find_move(Scope.Install, "roc-lang/http@2", scoped), existing("http2", "roc-lang/http", "2")),
		("add: a full name, no entry has the series (R-SC16)", find_move(Scope.Install, "roc-lang/http@3", scoped), tie_text("roc-lang/http", "2", move_text, http_lines)),
		("add: a full name, no selector", find_move(Scope.Install, "roc-lang/http", scoped), tie_text("roc-lang/http", "2", use_list, http_lines)),
		("add: an alias, a new series", find_move(Scope.Install, "json@3", scoped), existing("json", "acme/json", "2")),
		("add: a full name that no entry has", find_move(Scope.Install, "roc-lang/unicode@4", scoped), Ok(Lookup.New("roc-lang/unicode"))),
		(
			"add: a short name that is no alias",
			find_move(Scope.Install, "yaml", scoped),
			Err("tln: error[usage]: 'yaml' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).|"),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SC3 R-SC4 R-AD7: `tool` and `x`. A short name must match an installed tool or an `x` cache entry. It never goes to an index.
# With no local match, and no registry, Talon stops and asks for the full name. A full name with no local match is `New`.
expect {
	tools = [ent("app", "owner/app", "1", "1.0.0", "tool"), ent("fmt", "owner/roc-fmt", "1", "1.0.0", "tool")]
	rows = [
		(Scope.Tool, "app", existing("app", "owner/app", "1")),
		(Scope.Tool, "fmt", existing("fmt", "owner/roc-fmt", "1")),
		(Scope.X, "roc-fmt", existing("fmt", "owner/roc-fmt", "1")),
		(Scope.Tool, "owner/other", Ok(Lookup.New("owner/other"))),
		(Scope.X, "owner/app", existing("app", "owner/app", "1")),
		(
			Scope.Tool,
			"other",
			Err("tln: error[usage]: 'other' matches no installed tool or cached app. Use the full name (owner/repo).|"),
		),
		(
			Scope.X,
			"other",
			Err("tln: error[usage]: 'other' matches no installed tool or cached app. Use the full name (owner/repo).|"),
		),
	]
	bad = rows.keep_if(|(scope, text, want)| find(scope, text, tools) != want).map(|(scope, text, want)| (text, want, find(scope, text, tools)))
	dbg bad
	bad == []
}

# R-SC6 R-SC16 R-H9 R-H4 R-AD22 R-AD21 (slice 015): the alias of an unmanaged entry is found by `update` and `add` (`find_move`, `find`), also with a selector (`util@3`). The lookup gives the entity, and the command then
# applies R-H9: `Add.decide_alias` keeps it for `add X` and stops with exit 2 for a selector, and `update X` stops. A full name does not match it (its name is ""). `find` with a selector stays "not in the project" (it never matches
# a version, as `why` and `remove` read it: `remove util@1` must not remove it).
expect {
	entities = [
		ent("json", "acme/json", "2", "2.1.0", "direct (json)"),
		unmanaged("util", "direct (util)"),
		unmanaged("odd", "direct (odd)"),
	]
	rows = [
		("update util", find_move(Scope.Project, "util", entities), existing("util", "", "")),
		("update util@3", find_move(Scope.Project, "util@3", entities), existing("util", "", "")),
		("update a foreign URL", find_move(Scope.Project, "odd@^1", entities), existing("odd", "", "")),
		("add util@^1", find_move(Scope.Install, "util@^1", entities), existing("util", "", "")),
		("add util", find(Scope.Install, "util", entities), existing("util", "", "")),
		("add a full name that no entity has", find(Scope.Install, "acme/util", entities), Ok(Lookup.New("acme/util"))),
		("remove util", find(Scope.Project, "util", entities), existing("util", "", "")),
		("remove util@1 (an unmanaged entry has no version)", find(Scope.Project, "util@1", entities), Err("tln: error[usage]: 'util@1' is not in the project|")),
		("remove odd@latest", find(Scope.Project, "odd@latest", entities), Err("tln: error[usage]: 'odd@latest' is not in the project|")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
