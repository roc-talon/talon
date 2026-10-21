app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Closure
import lib.Fail
import lib.Release

main! = |_args| Ok({})

file = "/p/app/main.roc"

# A release URL of the fixture host. The hash is letters and digits only (a dot in it would be a second version in the URL).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

dep = |alias, value| { alias, value, is_platform: Bool.False }

plat = |alias, value| { alias, value, is_platform: Bool.True }

node = |id, entries| { id, entries }

form_of = |repo| "github.com/acme/${repo}/releases/download/{v}/"

# A release row. `via` is `Err(None)` for a direct row.
rel = |repo, ver, alias, facts| {
	id: u(repo, ver),
	kind: Release,
	alias,
	name: "acme/${repo}",
	form: form_of(repo),
	version: ver,
	series: facts.series,
	direct: facts.via == Err(None),
	via: facts.via,
	raised: facts.raised,
	is_platform: facts.is_pf,
}

# A row of a path entry or a foreign URL.
other = |kind, id, alias, name, via| { id, kind, alias, name, form: "", version: "", series: "", direct: via == Err(None), via, raised: Err(None), is_platform: Bool.False }

link = |from, alias, to| { from, alias, to }

no_raise = Err(None)

# R-H4 R-H7 R-AL2 R-CM2 R-CM9 R-ID2 R-FE1 (Design 2: only the winner's deps are followed): the walk of one header, round by round. The header has a platform, a package with deps, a package that is raised, a path entry
# (its URL entries are edges of a node, its own path entry is relative to its dir), and a foreign URL. Each round gives `Need` with the ids that the selection follows and that the nodes lack (a release URL, or the absolute file of a
# path entry). A foreign URL is never needed. A lower version that is named while a higher one wins (`core 1.0.0`) is never needed. The last round is `Done`: one row for each group, path file and foreign value, level by level.
expect {
	entries = [plat("pf", u("pfx", "0.1.1")), dep("web", u("web", "1.0.0")), dep("core", u("core", "1.1.0")), dep("util", "../util/main.roc"), dep("ext", "https://example.org/ext.tar.zst")]
	n_pf = node(u("pfx", "0.1.1"), [])
	n_web = node(u("web", "1.0.0"), [dep("core", u("core", "1.0.0")), dep("text", u("text", "1.0.0"))])
	n_core = node(u("core", "1.1.0"), [])
	n_util = node("/p/util/main.roc", [dep("core", u("core", "1.0.0")), dep("txt", u("text", "2.0.0")), dep("inner", "./inner/main.roc")])
	n_text1 = node(u("text", "1.0.0"), [dep("lex", u("lex", "1.0.0"))])
	n_text2 = node(u("text", "2.0.0"), [])
	n_inner = node("/p/util/inner/main.roc", [])
	n_lex = node(u("lex", "1.0.0"), [])
	step = |nodes| Closure.step({ file, entries, nodes })
	rounds = [
		("no node: the 4 entries that have a header", step([]), Need([u("pfx", "0.1.1"), u("web", "1.0.0"), u("core", "1.1.0"), "/p/util/main.roc"])),
		("level 2: core 1.0.0 is not needed", step([n_pf, n_web, n_core, n_util]), Need([u("text", "1.0.0"), u("text", "2.0.0"), "/p/util/inner/main.roc"])),
		("level 3", step([n_pf, n_web, n_core, n_util, n_text1, n_text2, n_inner]), Need([u("lex", "1.0.0")])),
	]
	bad_rounds = rounds.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rounds
	all = [n_pf, n_web, n_core, n_util, n_text1, n_text2, n_inner, n_lex]
	one = |series, via, raised, is_pf| { series, via, raised, is_pf }
	want_rows = [
		rel("pfx", "0.1.1", "pf", one("0.1", Err(None), no_raise, Bool.True)),
		rel("web", "1.0.0", "web", one("1", Err(None), no_raise, Bool.False)),
		rel("core", "1.1.0", "core", one("1", Err(None), Ok("1.0.0"), Bool.False)),
		other(Path, "/p/util/main.roc", "util", "../util/main.roc", Err(None)),
		other(Foreign, "https://example.org/ext.tar.zst", "ext", "https://example.org/ext.tar.zst", Err(None)),
		rel("text", "1.0.0", "text", one("1", Ok("web"), no_raise, Bool.False)),
		rel("text", "2.0.0", "txt", one("2", Ok("util"), no_raise, Bool.False)),
		other(Path, "/p/util/inner/main.roc", "inner", "./inner/main.roc", Ok("util")),
		rel("lex", "1.0.0", "lex", one("1", Ok("web"), no_raise, Bool.False)),
	]
	want_links = [
		link(Err(Header), "pf", u("pfx", "0.1.1")),
		link(Err(Header), "web", u("web", "1.0.0")),
		link(Err(Header), "core", u("core", "1.1.0")),
		link(Err(Header), "util", "/p/util/main.roc"),
		link(Err(Header), "ext", "https://example.org/ext.tar.zst"),
		link(Ok(u("web", "1.0.0")), "core", u("core", "1.1.0")),
		link(Ok(u("web", "1.0.0")), "text", u("text", "1.0.0")),
		link(Ok("/p/util/main.roc"), "core", u("core", "1.1.0")),
		link(Ok("/p/util/main.roc"), "txt", u("text", "2.0.0")),
		link(Ok("/p/util/main.roc"), "inner", "/p/util/inner/main.roc"),
		link(Ok(u("text", "1.0.0")), "lex", u("lex", "1.0.0")),
	]
	done = step(all)
	done_ok = done == Done({ rows: want_rows, links: want_links })
	if !done_ok {
		dbg done
	}
	bad_rounds == [] and done_ok
}

# R-C2 R-OV1 R-CM9 (Design 2: highest wins, only the winner's deps are followed): the winner of a group changes when a node is read. `web` names `core 1.0.0` and `text 1.0.0`. `mid` names `text 1.1.0`. So `text 1.1.0` wins
# (`text 1.0.0` is never needed), and its node names `core 1.1.0`, which wins over the `core 1.0.0` that was needed in the round before. The rows are raised: the mark is of the package, with the lowest named version (question Q9).
expect {
	entries = [dep("mid", u("mid", "1.0.0")), dep("web", u("web", "1.0.0"))]
	n_mid = node(u("mid", "1.0.0"), [dep("text", u("text", "1.1.0"))])
	n_web = node(u("web", "1.0.0"), [dep("core", u("core", "1.0.0")), dep("text", u("text", "1.0.0"))])
	n_text = node(u("text", "1.1.0"), [dep("core", u("core", "1.1.0"))])
	n_core1 = node(u("core", "1.0.0"), [])
	n_core11 = node(u("core", "1.1.0"), [])
	step = |nodes| Closure.step({ file, entries, nodes })
	rounds = [
		("level 1", step([]), Need([u("mid", "1.0.0"), u("web", "1.0.0")])),
		("text 1.1.0 wins, core 1.0.0 for now", step([n_mid, n_web]), Need([u("text", "1.1.0"), u("core", "1.0.0")])),
		("core 1.1.0 wins: core 1.0.0 is dropped", step([n_mid, n_web, n_text, n_core1]), Need([u("core", "1.1.0")])),
	]
	bad_rounds = rounds.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rounds
	one = |series, via, raised| { series, via, raised, is_pf: Bool.False }
	want_rows = [
		rel("mid", "1.0.0", "mid", one("1", Err(None), no_raise)),
		rel("web", "1.0.0", "web", one("1", Err(None), no_raise)),
		rel("text", "1.1.0", "text", one("1", Ok("mid"), Ok("1.0.0"))),
		rel("core", "1.1.0", "core", one("1", Ok("web"), Ok("1.0.0"))),
	]
	want_links = [
		link(Err(Header), "mid", u("mid", "1.0.0")),
		link(Err(Header), "web", u("web", "1.0.0")),
		link(Ok(u("mid", "1.0.0")), "text", u("text", "1.1.0")),
		link(Ok(u("web", "1.0.0")), "core", u("core", "1.1.0")),
		link(Ok(u("web", "1.0.0")), "text", u("text", "1.1.0")),
		link(Ok(u("text", "1.1.0")), "core", u("core", "1.1.0")),
	]
	done = step([n_mid, n_web, n_text, n_core1, n_core11])
	done_ok = done == Done({ rows: want_rows, links: want_links })
	if !done_ok {
		dbg done
	}
	bad_rounds == [] and done_ok
}

# R-H7 R-H4 R-C2: a path entry is part of the closure. Its URL entries are edges of a node, not root edges: `util` names `json 2.0.0` and the header has `json 2.1.0`, so `json` is raised and there is no failure. Its own path entry is
# relative to its dir (`./deep/main.roc` gives `/p/util/deep/main.roc`), and the deps of that file join the closure too. 2 aliases of one file give one row and 2 links. A path value in the header of a release is ignored, and a foreign URL
# in it is a row with `via`.
expect {
	entries = [dep("json", u("json", "2.1.0")), dep("util", "../util/main.roc"), dep("again", "../util/../util/main.roc"), dep("web", u("web", "1.0.0"))]
	n_json = node(u("json", "2.1.0"), [])
	n_util = node("/p/util/main.roc", [dep("j", u("json", "2.0.0")), dep("deep", "./deep/main.roc")])
	n_web = node(u("web", "1.0.0"), [dep("local", "./x/main.roc"), dep("old", "https://example.org/old.tar.zst")])
	n_deep = node("/p/util/deep/main.roc", [dep("lex", u("lex", "1.0.0"))])
	n_lex = node(u("lex", "1.0.0"), [])
	step = |nodes| Closure.step({ file, entries, nodes })
	rounds = [
		("level 1: one file for 2 aliases", step([]), Need([u("json", "2.1.0"), "/p/util/main.roc", u("web", "1.0.0")])),
		("level 2: the deep file, no file for the path value of the release, no foreign URL", step([n_json, n_util, n_web]), Need(["/p/util/deep/main.roc"])),
		("level 3", step([n_json, n_util, n_web, n_deep]), Need([u("lex", "1.0.0")])),
	]
	bad_rounds = rounds.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rounds
	want_rows = [
		rel("json", "2.1.0", "json", { series: "2", via: Err(None), raised: Ok("2.0.0"), is_pf: Bool.False }),
		other(Path, "/p/util/main.roc", "util", "../util/main.roc", Err(None)),
		rel("web", "1.0.0", "web", { series: "1", via: Err(None), raised: no_raise, is_pf: Bool.False }),
		other(Path, "/p/util/deep/main.roc", "deep", "./deep/main.roc", Ok("util")),
		other(Foreign, "https://example.org/old.tar.zst", "old", "https://example.org/old.tar.zst", Ok("web")),
		rel("lex", "1.0.0", "lex", { series: "1", via: Ok("util"), raised: no_raise, is_pf: Bool.False }),
	]
	want_links = [
		link(Err(Header), "json", u("json", "2.1.0")),
		link(Err(Header), "util", "/p/util/main.roc"),
		link(Err(Header), "again", "/p/util/main.roc"),
		link(Err(Header), "web", u("web", "1.0.0")),
		link(Ok("/p/util/main.roc"), "j", u("json", "2.1.0")),
		link(Ok("/p/util/main.roc"), "deep", "/p/util/deep/main.roc"),
		link(Ok(u("web", "1.0.0")), "old", "https://example.org/old.tar.zst"),
		link(Ok("/p/util/deep/main.roc"), "lex", u("lex", "1.0.0")),
	]
	done = step([n_json, n_util, n_web, n_deep, n_lex])
	done_ok = done == Done({ rows: want_rows, links: want_links })
	if !done_ok {
		dbg done
	}
	bad_rounds == [] and done_ok
}

# R-C2 R-EC10 R-AL9 (Design 2: an app pin that is lower than a dependency needs fails): the failures of `Mvs.select` come back as a problem, only when the nodes of all followed packages are read. The lists are in byte order (Mvs gives no order).
# A `Cycle` is not tested: its start is not fixed.
expect {
	step = |entries, nodes| Closure.step({ file, entries, nodes })
	pinned = [dep("core", u("core", "1.0.0")), dep("mid", u("mid", "1.0.0"))]
	n_core = node(u("core", "1.0.0"), [])
	n_mid = node(u("mid", "1.0.0"), [dep("text", u("text", "1.1.0"))])
	n_text = node(u("text", "1.1.0"), [dep("core", u("core", "1.1.0"))])
	roots = [dep("a", u("core", "1.0.0")), dep("b", u("core", "1.1.0"))]
	other_hash = "https://github.com/acme/core/releases/download/1.0.0/otherhash.tar.zst"
	content = [dep("web", u("web", "1.0.0")), dep("mid2", u("mid", "2.0.0"))]
	n_web = node(u("web", "1.0.0"), [dep("core", u("core", "1.0.0"))])
	n_mid2 = node(u("mid", "2.0.0"), [dep("core", other_hash)])
	rows = [
		("pinned core 1.0.0, mid needs text 1.1.0: the problem is not known before its node is read", step(pinned, [n_core, n_mid]), Need([u("text", "1.1.0")])),
		("VersionConflict", step(pinned, [n_core, n_mid, n_text]), Fail(VersionConflict([{ pinned: u("core", "1.0.0"), needed: u("core", "1.1.0"), by: u("text", "1.1.0") }]))),
		("RootConflict", step(roots, [node(u("core", "1.0.0"), []), node(u("core", "1.1.0"), [])]), Fail(RootConflict([u("core", "1.0.0"), u("core", "1.1.0")]))),
		("ContentConflict: one group and version, 2 hashes", step(content, [n_web, n_mid2, node(u("core", "1.0.0"), []), node(other_hash, [])]), Fail(ContentConflict([u("core", "1.0.0"), other_hash]))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad
	bad == []
}

# R-EC10 R-E4 R-AL9 (question Q16, now R-AL9; TW24): the failure of a problem: kind `no_tuple` (exit 10) and the texts, with the label `<name> <version>`.
expect {
	view = |problem| Fail.line(Closure.failure(problem))
	prefix = "tln: error[no_tuple]: "
	rows = [
		(Cycle([u("web", "1.0.0"), u("core", "1.0.0")]), "${prefix}the closure has a cycle: acme/web 1.0.0 -> acme/core 1.0.0"),
		(RootConflict([u("core", "1.0.0"), u("core", "1.1.0")]), "${prefix}the header names one package at 2 versions or more: acme/core 1.0.0, acme/core 1.1.0"),
		(ContentConflict([u("core", "1.0.0"), "https://github.com/acme/core/releases/download/1.0.0/otherhash.tar.zst"]), "${prefix}one release has 2 hashes in the closure: acme/core 1.0.0 (corex1x0x0), acme/core 1.0.0 (otherhash)"),
		(
			VersionConflict([{ pinned: u("core", "1.0.0"), needed: u("core", "1.1.0"), by: u("text", "1.1.0") }, { pinned: u("core", "1.0.0"), needed: u("core", "1.2.0"), by: u("mid", "1.0.0") }]),
			"${prefix}acme/text 1.1.0 needs acme/core 1.1.0, but the header names acme/core 1.0.0; acme/mid 1.0.0 needs acme/core 1.2.0, but the header names acme/core 1.0.0",
		),
		(PlatformMismatch([u("pfx", "0.1.0"), u("pfx", "0.1.1")]), "${prefix}the platforms in the closure are not one release: acme/pfx 0.1.0 (pfxx0x1x0), acme/pfx 0.1.1 (pfxx0x1x1)"),
	]
	bad = rows.keep_if(|(problem, want)| view(problem) != want).map(|(problem, _)| view(problem))
	dbg bad
	bad == []
}

# R-C8 R-CM9 (question Q11): 2 series of one package (one URL form) in the closure. One clash for each form, in the order of its first row. `via` is the alias of a direct row, else the `via` of the row. 3 series say `3`. Two forms
# with one name (the tag `v1.0.0` and the tag `1.0.0`) are 2 packages to Roc, so they are no clash. A path row and a foreign row are never a clash.
expect {
	crow = |name, form, series, alias, via| {
		id: "${name}${series}",
		kind: Release,
		alias,
		name,
		form,
		version: "${series}.0.0",
		series,
		direct: via == Err(None),
		via,
		raised: Err(None),
		is_platform: Bool.False,
	}
	json = "github.com/acme/json/releases/download/{v}/"
	xml = "github.com/acme/xml/releases/download/{v}/"
	json_v = "github.com/acme/json/releases/download/v{v}/"
	p = other(Path, "/p/a.roc", "a", "./a.roc", Err(None))
	f = other(Foreign, "https://x.org/e.zst", "e", "https://x.org/e.zst", Err(None))
	one = [crow("acme/json", json, "2", "json", Err(None)), crow("acme/parser", "github.com/acme/parser/releases/download/{v}/", "1", "parser", Err(None)), crow("acme/json", json, "1", "json1", Ok("parser"))]
	many = [
		crow("acme/json", json, "3", "json", Err(None)),
		crow("acme/xml", xml, "1", "xml", Err(None)),
		crow("acme/json", json, "2", "j2", Ok("a")),
		crow("acme/xml", xml, "2", "x2", Ok("b")),
		crow("acme/json", json, "1", "j1", Ok("c")),
	]
	none = [crow("acme/json", json, "1", "json", Err(None)), crow("acme/json", json_v, "2", "j2", Ok("a")), p, f, p, f]
	clashes = [
		("one clash", Closure.clashes(one), [{ name: "acme/json", series: [{ series: "2", via: "json" }, { series: "1", via: "parser" }] }]),
		(
			"2 clashes, 3 series",
			Closure.clashes(many),
			[
				{ name: "acme/json", series: [{ series: "3", via: "json" }, { series: "2", via: "a" }, { series: "1", via: "c" }] },
				{ name: "acme/xml", series: [{ series: "1", via: "xml" }, { series: "2", via: "b" }] },
			],
		),
		("2 forms, path and foreign rows", Closure.clashes(none), []),
		("no row", Closure.clashes([]), []),
	]
	notes = [
		("one", Closure.notes(one), ["warning: acme/json has 2 series in the closure: 2 via json, 1 via parser. The types of the 2 series are different types."]),
		(
			"many",
			Closure.notes(many),
			[
				"warning: acme/json has 3 series in the closure: 3 via json, 2 via a, 1 via c. The types of the 3 series are different types.",
				"warning: acme/xml has 2 series in the closure: 1 via xml, 2 via b. The types of the 2 series are different types.",
			],
		),
		("none", Closure.notes(none), []),
	]
	bad_clashes = clashes.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	bad_notes = notes.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_clashes
	dbg bad_notes
	bad_clashes == [] and bad_notes == []
}

# R-H7 R-C3 R-CM9: `Release.entries_of` gives each entry of the dependency record, with the alias and `is_platform`, in source order, and not the `roc` entry. An app and a package header have the platform entry in the list. A platform header
# gives its `packages` record.
expect {
	app_text = "app [main!] {\n\tpf: platform \"https://x.org/pf/1.0.0/pfhash.tar.zst\",\n\tjson: \"https://x.org/json/2.1.0/jsonhash.tar.zst\",\n\tutil: \"../util/main.roc\",\n\troc: \"nightly-2026-10-14-38a3029\",\n}\n\nmain! = |_| Ok({})\n"
	package_text = "package [Lib] {\n\tpf: platform \"https://x.org/pf/1.0.0/pfhash.tar.zst\",\n\tjson: \"https://x.org/json/2.1.0/jsonhash.tar.zst\",\n}\n"
	platform_text = "platform \"acme\"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {\n\t\tjson: \"https://x.org/json/2.1.0/jsonhash.tar.zst\",\n\t\tutil: \"../util/main.roc\",\n\t}\n\tprovides [main_for_host!]\n"
	empty_text = "package [Lib] {}\n"
	read = |text| match Release.entries_of({ path: "/p/main.roc", text }) {
		Ok(entries) => Ok(entries)
		Err(f) => Err(Fail.line(f))
	}
	pf = { alias: "pf", value: "https://x.org/pf/1.0.0/pfhash.tar.zst", is_platform: Bool.True }
	json = { alias: "json", value: "https://x.org/json/2.1.0/jsonhash.tar.zst", is_platform: Bool.False }
	util = { alias: "util", value: "../util/main.roc", is_platform: Bool.False }
	rows = [
		("app", read(app_text), Ok([pf, json, util])),
		("package", read(package_text), Ok([pf, json])),
		("platform", read(platform_text), Ok([json, util])),
		("no entry", read(empty_text), Ok([])),
		("no header", read("main = 1\n"), Err("tln: error[input]: /p/main.roc: the package has no app, package or platform header")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad
	bad == []
}
