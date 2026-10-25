app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.JsonDoc
import lib.Listing

main! = |_args| Ok({})

file = "/p/main.roc"

pfx = "https://github.com/acme/pfx/releases/download/0.1.1/pfxhash.tar.zst"

json = "https://github.com/acme/json/releases/download/2.1.0/jsonhash.tar.zst"

lex = "https://github.com/acme/lex/releases/download/1.0.0/lexhash.tar.zst"

ext = "https://x.org/e.zst"

# The closure of a header with a platform, a raised package, a path entry, a foreign URL, a package under `json`, a path entry under `util` that names `json` again, and a nested path entry. Rows and links as `Closure.step` gives them.
walked = {
	rows: [
		{ id: pfx, kind: Release, alias: "pf", name: "acme/pfx", form: "github.com/acme/pfx/releases/download/{v}/", version: "0.1.1", series: "0.1", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.True },
		{ id: json, kind: Release, alias: "json", name: "acme/json", form: "github.com/acme/json/releases/download/{v}/", version: "2.1.0", series: "2", direct: Bool.True, via: Err(None), raised: Ok("2.0.0"), is_platform: Bool.False },
		{ id: "/p/util/main.roc", kind: Path, alias: "util", name: "../util/main.roc", form: "", version: "", series: "", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
		{ id: ext, kind: Foreign, alias: "ext", name: ext, form: "", version: "", series: "", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
		{ id: lex, kind: Release, alias: "lex", name: "acme/lex", form: "github.com/acme/lex/releases/download/{v}/", version: "1.0.0", series: "1", direct: Bool.False, via: Ok("json"), raised: Err(None), is_platform: Bool.False },
		{ id: "/p/util/in/main.roc", kind: Path, alias: "inner", name: "./in/main.roc", form: "", version: "", series: "", direct: Bool.False, via: Ok("util"), raised: Err(None), is_platform: Bool.False },
	],
	links: [
		{ from: Err(Header), alias: "pf", to: pfx },
		{ from: Err(Header), alias: "json", to: json },
		{ from: Err(Header), alias: "util", to: "/p/util/main.roc" },
		{ from: Err(Header), alias: "ext", to: ext },
		{ from: Ok(json), alias: "lex", to: lex },
		{ from: Ok("/p/util/main.roc"), alias: "j", to: json },
		{ from: Ok("/p/util/main.roc"), alias: "inner", to: "/p/util/in/main.roc" },
	],
}

# R-CM9 R-CM19 R-FL5 R-FL7 R-EC2 R-E4 (Q6 of slice 009 for the name): the options of `list` and `ls`. `--tree` is the one option. A name is rejected (R-CM9 has no operand). The checks of `Opts.read` come first (the registry).
expect {
	view = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Listing.read(args) {
			Ok(opts) => Ok(opts.tree)
			Err(f) => Err(Fail.line(f))
		}
	}
	rows = [
		(["list"], Ok(Bool.False)),
		(["ls"], Ok(Bool.False)),
		(["list", "--tree"], Ok(Bool.True)),
		(["ls", "--tree", "--json", "--quiet", "--offline", "--file", "app/main.roc"], Ok(Bool.True)),
		(["list", "json"], Err("tln: error[usage]: tln list takes no name")),
		(["ls", "--tree", "json", "parser"], Err("tln: error[usage]: tln list takes no name")),
		(["list", "--registry", "https://r.example", "json"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
	]
	bad = rows.keep_if(|(words, want)| view(words) != want).map(|(words, _)| (words, view(words)))
	dbg bad
	bad == []
}

# R-CM9 R-H4 R-C8 R-OUT2 (proposal, TW24): the flat list. 2 spaces, the alias, the label, the marks. The columns are padded to the longest alias and the longest label, and 2 more. The marks: `direct`, or `via <alias>`, then
# `raised from <version>` (question Q9), then `foreign` for a path entry and a foreign URL (R-H4), joined by `; `. A closure with no row is the file line only.
expect {
	want = "/p/main.roc\n  pf     acme/pfx 0.1.1       direct\n  json   acme/json 2.1.0      direct; raised from 2.0.0\n  util   ../util/main.roc     direct; foreign\n  ext    https://x.org/e.zst  direct; foreign\n  lex    acme/lex 1.0.0       via json\n  inner  ./in/main.roc        via util; foreign\n"
	got = Listing.text({ file, walked, patched: [] })
	empty = Listing.text({ file, walked: { rows: [], links: [] }, patched: [] })
	dbg got
	got == want and empty == "/p/main.roc\n"
}

# R-CM9 R-H4 (proposal, TW24): the tree of `--tree`. One line for each link, depth first, 2 spaces for each level. The marks are `direct`, `raised from <version>` and `foreign`, in parentheses, with no `via`. The first line of a row has its marks,
# a later line of the same row says `(shown above)` and has no children. A row with no mark has no parentheses. A row that is direct and also named by a package shows `direct` at its first line.
expect {
	want = "/p/main.roc\n  pf: acme/pfx 0.1.1 (direct)\n  json: acme/json 2.1.0 (direct; raised from 2.0.0)\n    lex: acme/lex 1.0.0\n  util: ../util/main.roc (direct; foreign)\n    j: acme/json 2.1.0 (shown above)\n    inner: ./in/main.roc (foreign)\n  ext: https://x.org/e.zst (direct; foreign)\n"
	got = Listing.tree({ file, walked, patched: [] })
	# A package that is named first by a package: its first line has `direct`, and the header entry later says `shown above`.
	nested = {
		rows: [
			{ id: json, kind: Release, alias: "json", name: "acme/json", form: "", version: "2.1.0", series: "2", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
			{ id: lex, kind: Release, alias: "lex", name: "acme/lex", form: "", version: "1.0.0", series: "1", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
		],
		links: [
			{ from: Err(Header), alias: "lex", to: lex },
			{ from: Err(Header), alias: "json", to: json },
			{ from: Ok(lex), alias: "json", to: json },
		],
	}
	deep = Listing.tree({ file, walked: nested, patched: [] })
	dbg got
	dbg deep
	got == want and deep == "/p/main.roc\n  lex: acme/lex 1.0.0 (direct)\n    json: acme/json 2.1.0 (direct)\n  json: acme/json 2.1.0 (shown above)\n" and Listing.tree({ file, walked: { rows: [], links: [] }, patched: [] }) == "/p/main.roc\n"
}

# R-CM9 R-OUT4 R-OUT5 R-J3 R-J4 (proposal, TW24): the `data` of `list --json`. Keys in order: `members` (`file`, `packages`, `links`, `series`). A package has `alias`, `name`, `version` (null for a path or foreign row), `kind`,
# `id`, `direct`, `via`, `raised`, `foreign`, `platform`. A link has `from` (null for a header entry), `alias`, `to`. `series` has the clashes of R-C8 (the same facts as the warning).
expect {
	pkg = |alias, name, version, kind, id, direct, via, raised, foreign, is_pf| "{\"alias\":\"${alias}\",\"name\":\"${name}\",\"version\":${version},\"kind\":\"${kind}\",\"id\":\"${id}\",\"direct\":${direct},\"via\":${via},\"raised\":${raised},\"foreign\":${foreign},\"platform\":${is_pf},\"patched\":false}"
	pkgs = [
		pkg("pf", "acme/pfx", "\"0.1.1\"", "release", pfx, "true", "null", "null", "false", "true"),
		pkg("json", "acme/json", "\"2.1.0\"", "release", json, "true", "null", "\"2.0.0\"", "false", "false"),
		pkg("util", "../util/main.roc", "null", "path", "/p/util/main.roc", "true", "null", "null", "true", "false"),
		pkg("ext", ext, "null", "foreign", ext, "true", "null", "null", "true", "false"),
		pkg("lex", "acme/lex", "\"1.0.0\"", "release", lex, "false", "\"json\"", "null", "false", "false"),
		pkg("inner", "./in/main.roc", "null", "path", "/p/util/in/main.roc", "false", "\"util\"", "null", "true", "false"),
	]
	lnk = |from, alias, to| "{\"from\":${from},\"alias\":\"${alias}\",\"to\":\"${to}\"}"
	links = [
		lnk("null", "pf", pfx),
		lnk("null", "json", json),
		lnk("null", "util", "/p/util/main.roc"),
		lnk("null", "ext", ext),
		lnk("\"${json}\"", "lex", lex),
		lnk("\"/p/util/main.roc\"", "j", json),
		lnk("\"/p/util/main.roc\"", "inner", "/p/util/in/main.roc"),
	]
	want = "{\"members\":[{\"file\":\"/p/main.roc\",\"packages\":[${Str.join_with(pkgs, ",")}],\"links\":[${Str.join_with(links, ",")}],\"series\":[]}]}"
	got = Listing.data([{ file, walked, patched: [] }]).render()
	clash = {
		rows: [
			{ id: "a1", kind: Release, alias: "json", name: "acme/json", form: "f", version: "2.0.0", series: "2", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
			{ id: "a2", kind: Release, alias: "j1", name: "acme/json", form: "f", version: "1.0.0", series: "1", direct: Bool.False, via: Ok("parser"), raised: Err(None), is_platform: Bool.False },
		],
		links: [],
	}
	two = Listing.data([{ file: "/a.roc", walked: { rows: [], links: [] }, patched: [] }, { file: "/b.roc", walked: clash, patched: [] }]).render()
	want_two_prefix = "{\"members\":[{\"file\":\"/a.roc\",\"packages\":[],\"links\":[],\"series\":[]},{\"file\":\"/b.roc\",\"packages\":["
	want_two_suffix = "],\"links\":[],\"series\":[{\"name\":\"acme/json\",\"series\":[{\"series\":\"2\",\"via\":\"json\"},{\"series\":\"1\",\"via\":\"parser\"}]}]}]}"
	dbg got
	dbg two
	got == want and two.starts_with(want_two_prefix) and two.ends_with(want_two_suffix)
}

# R-CM9 R-PA12 R-OUT2 (slice 042, proposal TW24): the mark `patched`. A row is patched when it is a header entry (`direct`) and its alias is a key of the `[patch]` table of the member (the facts `patched`). It is the last mark, in the flat list, in
# the tree and as the last key `patched` of a package in `--json` (true or false in each package). A key that no row has is no mark, and a package that no header names (`lex` is `via json`) is never patched, also when its alias is a key.
# `tln why` has no `patched` key (`Listing.object_of`).
expect {
	patched = ["json", "lex", "nosuch"]
	text = Listing.text({ file, walked, patched })
	want_text = "/p/main.roc\n  pf     acme/pfx 0.1.1       direct\n  json   acme/json 2.1.0      direct; raised from 2.0.0; patched\n  util   ../util/main.roc     direct; foreign\n  ext    https://x.org/e.zst  direct; foreign\n  lex    acme/lex 1.0.0       via json\n  inner  ./in/main.roc        via util; foreign\n"
	tree = Listing.tree({ file, walked, patched })
	want_tree = "/p/main.roc\n  pf: acme/pfx 0.1.1 (direct)\n  json: acme/json 2.1.0 (direct; raised from 2.0.0; patched)\n    lex: acme/lex 1.0.0\n  util: ../util/main.roc (direct; foreign)\n    j: acme/json 2.1.0 (shown above)\n    inner: ./in/main.roc (foreign)\n  ext: https://x.org/e.zst (direct; foreign)\n"
	data = Listing.data([{ file, walked, patched }]).render()
	json_row = "{\"alias\":\"json\",\"name\":\"acme/json\",\"version\":\"2.1.0\",\"kind\":\"release\",\"id\":\"${json}\",\"direct\":true,\"via\":null,\"raised\":\"2.0.0\",\"foreign\":false,\"platform\":false,\"patched\":true}"
	lex_end = "\"via\":\"json\",\"raised\":null,\"foreign\":false,\"platform\":false,\"patched\":false}"
	one_member = Listing.data([{ file, walked, patched: [] }]).render()
	dbg text
	dbg tree
	dbg data
	text == want_text and tree == want_tree and data.contains(json_row) and data.contains(lex_end) and data.split_on("\"patched\":true").len() == 2 and !one_member.contains("\"patched\":true") and !Listing.object_of(
		{ id: json, kind: Release, alias: "json", name: "acme/json", form: "", version: "2.1.0", series: "2", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
	).render().contains("patched")
}
