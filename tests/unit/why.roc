app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.Why

main! = |_args| Ok({})

file = "/p/main.roc"

pfx = "https://github.com/acme/pfx/releases/download/0.1.1/pfxhash.tar.zst"

json = "https://github.com/acme/json/releases/download/2.1.0/jsonhash.tar.zst"

lex = "https://github.com/acme/lex/releases/download/1.0.0/lexhash.tar.zst"

ext = "https://x.org/e.zst"

util = "/p/util/main.roc"

inner = "/p/util/in/main.roc"

rel = |id, alias, name, version, series, facts| { id, kind: Release, alias, name, form: "form", version, series, direct: facts.via == Err(None), via: facts.via, raised: facts.raised, is_platform: facts.is_pf }

other = |kind, id, alias, name, via| { id, kind, alias, name, form: "", version: "", series: "", direct: via == Err(None), via, raised: Err(None), is_platform: Bool.False }

plain = |via| { via, raised: Err(None), is_pf: Bool.False }

# The closure of `listing.roc` (a platform, a raised package, a path entry, a foreign URL, a package under `json`, a path entry under `util` that names `json` twice, and a nested path entry).
walked = {
	rows: [
		rel(pfx, "pf", "acme/pfx", "0.1.1", "0.1", { via: Err(None), raised: Err(None), is_pf: Bool.True }),
		rel(json, "json", "acme/json", "2.1.0", "2", { via: Err(None), raised: Ok("2.0.0"), is_pf: Bool.False }),
		other(Path, util, "util", "../util/main.roc", Err(None)),
		other(Foreign, ext, "ext", ext, Err(None)),
		rel(lex, "lex", "acme/lex", "1.0.0", "1", plain(Ok("json"))),
		other(Path, inner, "inner", "./in/main.roc", Ok("util")),
	],
	links: [
		{ from: Err(Header), alias: "pf", to: pfx },
		{ from: Err(Header), alias: "json", to: json },
		{ from: Err(Header), alias: "util", to: util },
		{ from: Err(Header), alias: "ext", to: ext },
		{ from: Ok(json), alias: "lex", to: lex },
		{ from: Ok(util), alias: "j", to: json },
		{ from: Ok(util), alias: "k", to: json },
		{ from: Ok(util), alias: "inner", to: inner },
	],
}

step = |alias, id, kind| { alias, id, kind }

row_of = |id| match walked.rows.find_first(|r| r.id == id) {
	Ok(r) => r
	Err(_) => crash "no such row"
}

# R-CM7 R-FL5 R-FL7 R-FL12 R-EC2 R-E4 (Q25): the operand of `why` is one name. No name and 2 names or more are a usage failure. The checks of `Opts.read` come first (the registry). A flag that `why` does not take
# (`--strategy`, `--frozen`, `--tree`) stops in `Args.parse` (R-FL7): the failure is the one of the parser.
expect {
	view = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Why.read(args) {
			Ok(r) => Ok(r.name)
			Err(f) => Err(Fail.line(f))
		}
	}
	rows = [
		(["why", "json"], Ok("json")),
		(["why", "roc-lang/http@2"], Ok("roc-lang/http@2")),
		(["why", "json", "--json", "--quiet", "--offline", "--file", "app/main.roc"], Ok("json")),
		(["why"], Err("tln: error[usage]: tln why takes one name")),
		(["why", "json", "parser"], Err("tln: error[usage]: tln why takes one name")),
		(["why", "json", "--registry", "https://r.example"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
		(["why", "json", "--strategy", "lowest"], Err("tln: error[usage]: flag '--strategy' is not for 'why'")),
		(["why", "json", "--frozen"], Err("tln: error[usage]: flag '--frozen' is not for 'why'")),
		(["why", "json", "--tree"], Err("tln: error[usage]: flag '--tree' is not for 'why'")),
	]
	bad = rows.keep_if(|(words, want)| view(words) != want).map(|(words, _)| (words, view(words)))
	dbg bad
	bad == []
}

# R-SC1 R-SC6 R-SC15 (slice 014): `Why.row_facts` gives one fact for each row of the closure, in the order of the rows: the alias only for a direct row (R-SC6: an alias of a package header is no alias), a path entry
# or a foreign URL is unmanaged (no name, series or version), the role is `Platform`, `Direct` or `Via(<alias>)`.
expect {
	r = |id, alias, name, version, series, facts| rel(id, alias, name, version, series, facts)
	tie_rows = [
		r("pfurl", "pf", "roc-lang/basic-webserver", "0.1.0", "0.1", { via: Err(None), raised: Err(None), is_pf: Bool.True }),
		r("utilsurl", "web_utils", "acme/web-utils", "1.0.0", "1", plain(Err(None))),
		r("wsurl", "ws", "someone/basic-webserver", "1.0.0", "1", plain(Ok("web_utils"))),
		r("parurl", "parser", "lukewilliamboswell/roc-parser", "0.9.0", "0.9", plain(Err(None))),
		other(Path, "/p/util/main.roc", "util", "../util/main.roc", Err(None)),
		other(Foreign, ext, "ext", ext, Ok("util")),
	]
	series_rows = [
		r("t1", "text", "acme/text", "1.1.0", "1", plain(Ok("web"))),
		r("t2", "txt", "acme/text", "2.0.0", "2", plain(Ok("util"))),
		r(json, "json", "acme/json", "2.1.0", "2", plain(Err(None))),
	]
	rel_fact = |name, series, version| Release({ name, series, version })
	want_tie_facts = [
		{ alias: "pf", what: rel_fact("roc-lang/basic-webserver", "0.1", "0.1.0"), role: Platform },
		{ alias: "web_utils", what: rel_fact("acme/web-utils", "1", "1.0.0"), role: Direct },
		{ alias: "", what: rel_fact("someone/basic-webserver", "1", "1.0.0"), role: Via("web_utils") },
		{ alias: "parser", what: rel_fact("lukewilliamboswell/roc-parser", "0.9", "0.9.0"), role: Direct },
		{ alias: "util", what: Unmanaged, role: Direct },
		{ alias: "", what: Unmanaged, role: Via("util") },
	]
	want_series_facts = [
		{ alias: "", what: rel_fact("acme/text", "1", "1.1.0"), role: Via("web") },
		{ alias: "", what: rel_fact("acme/text", "2", "2.0.0"), role: Via("util") },
		{ alias: "json", what: rel_fact("acme/json", "2", "2.1.0"), role: Direct },
	]
	bad = Why.row_facts(tie_rows) != want_tie_facts or Why.row_facts(series_rows) != want_series_facts or Why.row_facts([]) != []
	dbg Why.row_facts(tie_rows)
	!bad
}

# R-SC1 R-SC6 R-SC7 R-SC8 R-SC14 R-SC15 R-SC16 (Q7 of slice 004, slice 014): the lookup of a name over the closure. `Why.row_facts` gives one fact for each row (the alias only for a direct row, R-SC6: an alias of a package
# header is no alias; a path entry or a foreign URL is unmanaged; the role is `Platform`, `Direct` or `Via(<alias>)`). `Lookup.build` makes the entities, with the full name and the series in their own fields (R-SC15: the printed name
# has `@<series>` only in the tie list). The note of the tie list: `platform (<alias>)`, `direct (<alias>)`, `via <alias>`. A short name is the repo name or the repo name without `roc-` (R-SC8). The design example of
# R-SC14: 2 packages with the repo name basic-webserver, the platform and a package under `web_utils`. The tie is a failure line with the list before it (the block). A selector keeps the rows whose version is in it (R-SC16):
# `acme/text@2.0.0` is the series-2 row, `acme/text@2.5.0` is in no row, a path entry never matches a selector.
expect {
	r = |id, alias, name, version, series, facts| rel(id, alias, name, version, series, facts)
	pf_url = "https://github.com/roc-lang/basic-webserver/releases/download/0.1.0/pfhash.tar.zst"
	utils_url = "https://github.com/acme/web-utils/releases/download/1.0.0/uthash.tar.zst"
	ws_url = "https://github.com/someone/basic-webserver/releases/download/1.0.0/wshash.tar.zst"
	parser_url = "https://github.com/lukewilliamboswell/roc-parser/releases/download/0.9.0/parhash.tar.zst"
	text1 = "https://github.com/acme/text/releases/download/1.1.0/text1hash.tar.zst"
	text2 = "https://github.com/acme/text/releases/download/2.0.0/text2hash.tar.zst"
	tie_rows = [
		r(pf_url, "pf", "roc-lang/basic-webserver", "0.1.0", "0.1", { via: Err(None), raised: Err(None), is_pf: Bool.True }),
		r(utils_url, "web_utils", "acme/web-utils", "1.0.0", "1", plain(Err(None))),
		r(ws_url, "ws", "someone/basic-webserver", "1.0.0", "1", plain(Ok("web_utils"))),
		r(parser_url, "parser", "lukewilliamboswell/roc-parser", "0.9.0", "0.9", plain(Err(None))),
		other(Path, "/p/util/main.roc", "util", "../util/main.roc", Err(None)),
	]
	series_rows = [
		r(text1, "text", "acme/text", "1.1.0", "1", plain(Ok("web"))),
		r(text2, "txt", "acme/text", "2.0.0", "2", plain(Ok("util"))),
		r(json, "json", "acme/json", "2.1.0", "2", plain(Err(None))),
	]
	found = |text, rows| match Why.find({ text, rows }) {
		Ok(row) => Ok(row.id)
		Err({ fail, block }) => Err((fail.line(), block))
	}
	tie_block = "\"basic-webserver\" matches 2 packages:\n  roc-lang/basic-webserver      platform (pf)\n  someone/basic-webserver       via web_utils\n"
	text_block = "\"acme/text\" matches 2 packages:\n  acme/text@1      via web\n  acme/text@2      via util\n"
	short_block = "\"text\" matches 2 packages:\n  acme/text@1      via web\n  acme/text@2      via util\n"
	not_in = |x| Err(("tln: error[usage]: '${x}' is not in the project", ""))
	rows = [
		("alias of a direct row", found("pf", tie_rows), Ok(pf_url)),
		("alias of a path entry", found("util", tie_rows), Ok("/p/util/main.roc")),
		("a path entry has no version (R-SC16)", found("util@1", tie_rows), not_in("util@1")),
		("full name", found("someone/basic-webserver", tie_rows), Ok(ws_url)),
		("short name, one match", found("web-utils", tie_rows), Ok(utils_url)),
		("short name, the repo name without roc-", found("parser", tie_rows), Ok(parser_url)),
		("the design example of R-SC14", found("basic-webserver", tie_rows), Err(("tln: error[usage]: \"basic-webserver\" matches 2 packages. Use a name from the list.", tie_block))),
		("the alias of a package header is no alias (R-SC6)", found("ws", tie_rows), not_in("ws")),
		("no match", found("zzz", tie_rows), not_in("zzz")),
		("a full name that is not in the closure", found("acme/zzz", tie_rows), not_in("acme/zzz")),
		("2 series: the name alone is a tie (R-SC15)", found("acme/text", series_rows), Err(("tln: error[usage]: \"acme/text\" matches 2 packages. Use a name from the list.", text_block))),
		("2 series: the series of the selector picks the row (Q12)", found("acme/text@2", series_rows), Ok(text2)),
		("2 series: a range picks by its version", found("acme/text@^1.0", series_rows), Ok(text1)),
		("2 series: an exact version picks the row (R-SC16)", found("acme/text@2.0.0", series_rows), Ok(text2)),
		("2 series: a version that no row has (R-SC16)", found("acme/text@2.5.0", series_rows), not_in("acme/text@2.5.0")),
		("2 series: the short name is a tie too", found("text", series_rows), Err(("tln: error[usage]: \"text\" matches 2 packages. Use a name from the list.", short_block))),
		("2 series: the short name with a series picks the row (R-SC16)", found("text@1", series_rows), Ok(text1)),
		("1 row, the version is not in the selector (R-SC16)", found("json@3", series_rows), not_in("json@3")),
		("1 row, the version is in the selector", found("json@2", series_rows), Ok(json)),
		("a bad ref is a usage failure from Ref.parse", found("a/b/c", tie_rows), Err(("tln: error[usage]: 'a/b/c' is not a package name: use a short name, owner/repo or host/path", ""))),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_rows
	bad_rows == []
}

# R-CM7 R-PH12 R-H4 R-H7 (Q13, Q15): the paths from the header to a row. All paths are listed, depth first in the order of the links. A row that 2 routes reach has 2 paths, and 2 links with 2 aliases from one package to one
# row are 2 paths. A direct row has its own path of one step. The path of a path entry ends with a step of kind `Path`. A target that no link reaches has no path.
expect {
	paths = |id| Why.paths({ walked, target: id })
	rows = [
		("direct and 2 aliases below util", paths(json), [[step("json", json, Release)], [step("util", util, Path), step("j", json, Release)], [step("util", util, Path), step("k", json, Release)]]),
		("every route to a row below json", paths(lex), [[step("json", json, Release), step("lex", lex, Release)], [step("util", util, Path), step("j", json, Release), step("lex", lex, Release)], [step("util", util, Path), step("k", json, Release), step("lex", lex, Release)]]),
		("a nested path entry", paths(inner), [[step("util", util, Path), step("inner", inner, Path)]]),
		("a foreign URL", paths(ext), [[step("ext", ext, Foreign)]]),
		("the platform", paths(pfx), [[step("pf", pfx, Release)]]),
		("a row that no link reaches", paths("/p/none"), []),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	# a chain of 3 levels: the app names a, a names b, b names c; c is also named by the app. The order is depth first.
	chain = {
		rows: [rel("A", "a", "x/a", "1.0.0", "1", plain(Err(None))), rel("B", "b", "x/b", "1.0.0", "1", plain(Ok("a"))), rel("C", "c", "x/c", "1.0.0", "1", plain(Err(None)))],
		links: [
			{ from: Err(Header), alias: "a", to: "A" },
			{ from: Err(Header), alias: "c", to: "C" },
			{ from: Ok("A"), alias: "b", to: "B" },
			{ from: Ok("B"), alias: "c2", to: "C" },
		],
	}
	deep = Why.paths({ walked: chain, target: "C" })
	dbg deep
	want_deep = [[step("a", "A", Release), step("b", "B", Release), step("c2", "C", Release)], [step("c", "C", Release)]]
	bad == [] and deep == want_deep
}

# R-CM7 R-PH12 R-H4 R-C2 R-OUT2 (proposal, TW24, Q15): the text of one member. The first line is the project file. The second line has the label of the package (`<name> <version>`, else the name as written) and the marks in
# parentheses: `direct`, `raised from <version>`, `foreign`, joined by `; ` (no `via`: the paths say it). Then one line for each path: 4 spaces, the aliases joined by ` -> `. A step of kind `Path` has ` (path)` after the alias.
expect {
	text = |id| Why.text({ file, walked, target: row_of(id) })
	rows = [
		("direct, raised, 3 paths", text(json), "/p/main.roc\n  acme/json 2.1.0 (direct; raised from 2.0.0)\n    json\n    util (path) -> j\n    util (path) -> k\n"),
		("not direct, no mark, 3 routes", text(lex), "/p/main.roc\n  acme/lex 1.0.0\n    json -> lex\n    util (path) -> j -> lex\n    util (path) -> k -> lex\n"),
		("a path entry below a path entry", text(inner), "/p/main.roc\n  ./in/main.roc (foreign)\n    util (path) -> inner (path)\n"),
		("a foreign URL", text(ext), "/p/main.roc\n  https://x.org/e.zst (direct; foreign)\n    ext\n"),
		("the platform", text(pfx), "/p/main.roc\n  acme/pfx 0.1.1 (direct)\n    pf\n"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CM7 R-OUT4 R-OUT5 R-J3 R-J4 (proposal, TW24): the `data` of `why --json`. `members`: for each member `file`, `package` (the object of `list --json`), `paths` (lists of `alias`, `kind`, `id`). The text has the marks and the
# `(path)` of the step kind, so the data has them as `raised`, `foreign` and `kind`.
expect {
	pkg = |alias, name, version, kind, id, direct, via, raised, foreign, is_pf| "{\"alias\":\"${alias}\",\"name\":\"${name}\",\"version\":${version},\"kind\":\"${kind}\",\"id\":\"${id}\",\"direct\":${direct},\"via\":${via},\"raised\":${raised},\"foreign\":${foreign},\"platform\":${is_pf}}"
	st = |alias, kind, id| "{\"alias\":\"${alias}\",\"kind\":\"${kind}\",\"id\":\"${id}\"}"
	member = |f, pk, paths| "{\"file\":\"${f}\",\"package\":${pk},\"paths\":[${Str.join_with(paths.map(|p| "[${Str.join_with(p, ",")}]"), ",")}]}"
	json_pkg = pkg("json", "acme/json", "\"2.1.0\"", "release", json, "true", "null", "\"2.0.0\"", "false", "false")
	inner_pkg = pkg("inner", "./in/main.roc", "null", "path", inner, "false", "\"util\"", "null", "true", "false")
	want_one = "{\"members\":[${member(file, json_pkg, [[st("json", "release", json)], [st("util", "path", util), st("j", "release", json)], [st("util", "path", util), st("k", "release", json)]])}]}"
	want_two = "{\"members\":[${member(file, json_pkg, [[st("json", "release", json)], [st("util", "path", util), st("j", "release", json)], [st("util", "path", util), st("k", "release", json)]])},${member("/q/main.roc", inner_pkg, [[st("util", "path", util), st("inner", "path", inner)]])}]}"
	one = Why.data([{ file, walked, target: row_of(json) }]).render()
	ext_pkg = pkg("ext", ext, "null", "foreign", ext, "true", "null", "null", "true", "false")
	want_three = "${want_two.drop_suffix("]}")},${member("/r/main.roc", ext_pkg, [[st("ext", "foreign", ext)]])}]}"
	two = Why.data([{ file, walked, target: row_of(json) }, { file: "/q/main.roc", walked, target: row_of(inner) }]).render()
	three = Why.data([{ file, walked, target: row_of(json) }, { file: "/q/main.roc", walked, target: row_of(inner) }, { file: "/r/main.roc", walked, target: row_of(ext) }]).render()
	dbg one
	dbg two
	dbg three
	one == want_one and two == want_two and three == want_three
}
