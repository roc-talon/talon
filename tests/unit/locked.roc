app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Locked

main! = |_args| Ok({})

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h_json1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_json2 = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h_http = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

n1 = "nightly-2026-10-09-258ab27"

n2 = "nightly-2026-10-13-91fa0c2"

cli_url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst"

json1 = "https://github.com/someone/roc-json/releases/download/2.1.0/${h_json1}.tar.zst"

json2 = "https://github.com/someone/roc-json/releases/download/2.3.0/${h_json2}.tar.zst"

http1 = "https://github.com/roc-lang/http/releases/download/1.9.0/${h_http}.tar.zst"

## An app header with a comment above it, comments in the record, a trailing comment, tabs, a path entry, a foreign URL, and the `roc:` pin last.
app_text = "# my app\napp [main!] {\n\t# the platform\n\tpf: platform \"${cli_url}\", # trailing comment\n\tjson:   \"${json1}\",\n\tutil: \"../util/main.roc\",\n\todd: \"https://example.com/pkg/latest.tar.gz\",\n\troc: \"${n1}\",\n}\n\nimport pf.Stdout\n\nmain! = |_| Ok({})\n"

shown_row = |row| {
	what = match row.what {
		Release(i) => "release ${i.name ?? "?"} ${i.version} ${i.series}"
		Path => "path"
		Foreign => "foreign"
	}
	(row.alias, row.value, row.is_platform, what)
}

# R-H4 R-H7 R-H8 R-PD8 R-TF5 R-C4: the header as the lock. The rows are the entries of the dependency record, in source order, with no `roc:` entry (it is the pin). A row is a release
# (`Ident.of_url`), a path (no `://`: R-H7, the command reads that header later), or foreign (a URL that Talon cannot identify: R-H4). A package header is read as an app header is (R-H8).
# A platform header gives its `packages` record. No header is a usage failure and a header that does not parse is an input failure with the line (as `Project.check_header`).
expect {
	read_app = Locked.read({ path: "/p/main.roc", text: app_text })
	app_view = match read_app {
		Ok(l) => Ok((l.kind, l.rows.map(shown_row), l.roc, Locked.paths(l)))
		Err(e) => Err(e.line())
	}
	app_want = Ok((
		App,
		[
			("pf", cli_url, Bool.True, "release roc-lang/basic-cli 0.25.0 0.25"),
			("json", json1, Bool.False, "release someone/roc-json 2.1.0 2"),
			("util", "../util/main.roc", Bool.False, "path"),
			("odd", "https://example.com/pkg/latest.tar.gz", Bool.False, "foreign"),
		],
		Ok(n1),
		["../util/main.roc"],
	))
	dbg app_view

	pkg_text = "package [Parser] { unicode: \"https://github.com/roc-lang/unicode/releases/download/1.0.0/${h_http}.tar.zst\" }\n"
	read_pkg = Locked.read({ path: "/p/lib/main.roc", text: pkg_text })
	pkg_view = match read_pkg {
		Ok(l) => Ok((l.kind, l.rows.map(shown_row), l.roc))
		Err(e) => Err(e.line())
	}
	pkg_want = Ok((Package, [("unicode", "https://github.com/roc-lang/unicode/releases/download/1.0.0/${h_http}.tar.zst", Bool.False, "release roc-lang/unicode 1.0.0 1")], Err(NoPin)))
	dbg pkg_view

	plat_text = "platform \"cli\"\n\trequires {} { main! : () => {} }\n\texposes [Stdout]\n\tpackages { json: \"${json1}\" }\n\tprovides [main_for_host!]\n"
	read_plat = Locked.read({ path: "/p/platform/main.roc", text: plat_text })
	plat_view = match read_plat {
		Ok(l) => Ok((l.kind, l.rows.map(shown_row)))
		Err(e) => Err(e.line())
	}
	plat_want = Ok((Platform, [("json", json1, Bool.False, "release someone/roc-json 2.1.0 2")]))
	dbg plat_view

	none_view = match Locked.read({ path: "/p/x.roc", text: "main! = |_| Ok({})\n" }) {
		Ok(_) => "ok"
		Err(e) => e.line()
	}
	bad_view = match Locked.read({ path: "/p/y.roc", text: "app [main!] {\n\tpf: platform \"${cli_url}\"\n\tjson: 5,\n}\n" }) {
		Ok(_) => "ok"
		Err(e) => e.line()
	}
	dbg [none_view, bad_view]
	app_view == app_want and pkg_view == pkg_want and plat_view == plat_want and none_view == "tln: error[usage]: /p/x.roc has no app, package or platform header" and bad_view == "tln: error[input]: /p/y.roc:3: the header is not valid"
}

# R-H1 R-H2 R-H3 R-H4 R-H6 R-H8 R-RP3 R-CC7 R-RV5: the span edits. Each edit changes only its own bytes: comments, order, tabs, spaces inside an entry, the keyword `platform`, the line ends and the file
# after the header stay byte for byte (the expected text is the old text with one replaced piece). `roc:` is set when it is there, else it is added as the last entry. The URL that Talon
# writes must be a release URL (R-H3). A path or foreign row is never set (R-H4): the failure is a Talon fault (kind `internal`). `Remove` works for them (R-RV5, slice 008). P0 has no mirror, so the URL of an op is the URL of an index
# candidate (R-H5). `spans` gives the text that each op changes (R-CC7).
expect {
	edit = |text, ops| Locked.edit({ path: "/p/main.roc", text, ops })
	shown = |r| match r {
		Ok(text) => Ok(text)
		Err(e) => Err(e.line())
	}
	cli2 = "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/${h_json2}.tar.zst"
	set_json = edit(app_text, [Set({ alias: "json", url: json2 })])
	want_set_json = Ok(app_text.replace_each(json1, json2))
	set_pf = edit(app_text, [Set({ alias: "pf", url: cli2 })])
	want_set_pf = Ok(app_text.replace_each(cli_url, cli2))
	add_http = edit(app_text, [Add({ alias: "http", url: http1, is_platform: Bool.False })])
	want_add_http = Ok(app_text.replace_each("\troc: \"${n1}\",\n", "\troc: \"${n1}\",\n\thttp: \"${http1}\",\n"))
	remove_json = edit(app_text, [Remove("json")])
	want_remove_json = Ok(app_text.replace_each("\tjson:   \"${json1}\",\n", ""))
	remove_path = edit(app_text, [Remove("util")])
	want_remove_path = Ok(app_text.replace_each("\tutil: \"../util/main.roc\",\n", ""))
	remove_foreign = edit(app_text, [Remove("odd")])
	want_remove_foreign = Ok(app_text.replace_each("\todd: \"https://example.com/pkg/latest.tar.gz\",\n", ""))
	pin_set = edit(app_text, [Pin(n2)])
	want_pin_set = Ok(app_text.replace_each(n1, n2))
	no_roc = app_text.replace_each("\troc: \"${n1}\",\n", "")
	pin_add = edit(no_roc, [Pin(n2)])
	want_pin_add = Ok(no_roc.replace_each("\todd: \"https://example.com/pkg/latest.tar.gz\",\n", "\todd: \"https://example.com/pkg/latest.tar.gz\",\n\troc: \"${n2}\",\n"))
	crlf = app_text.replace_each("\n", "\r\n")
	set_crlf = edit(crlf, [Set({ alias: "json", url: json2 })])
	want_set_crlf = Ok(crlf.replace_each(json1, json2))
	one_line = "app [main!] { pf: platform \"${cli_url}\", json: \"${json1}\" }\n"
	add_one = edit(one_line, [Add({ alias: "http", url: http1, is_platform: Bool.False })])
	want_add_one = Ok(one_line.replace_each(" }\n", ", http: \"${http1}\" }\n"))
	ops_in_order = edit(app_text, [Set({ alias: "json", url: json2 }), Add({ alias: "http", url: http1, is_platform: Bool.False }), Pin(n2)])
	want_ops = Ok(app_text.replace_each(json1, json2).replace_each("\troc: \"${n1}\",\n", "\troc: \"${n2}\",\n\thttp: \"${http1}\",\n"))
	pkg_text = "package [Parser] {\n\tjson: \"${json1}\", # lowest version that works\n}\n"
	set_pkg = edit(pkg_text, [Set({ alias: "json", url: json2 })])
	want_set_pkg = Ok(pkg_text.replace_each(json1, json2))
	dbg [shown(set_json), shown(add_http)]
	edits = [
		("set a URL", set_json, want_set_json),
		("set a platform URL: the keyword stays", set_pf, want_set_pf),
		("add an entry after the last one", add_http, want_add_http),
		("remove a whole line", remove_json, want_remove_json),
		("remove a path entry (R-RV5 gives way over R-H4)", remove_path, want_remove_path),
		("remove a foreign URL (R-RV5)", remove_foreign, want_remove_foreign),
		("set the roc pin", pin_set, want_pin_set),
		("add the roc pin as the last entry", pin_add, want_pin_add),
		("CRLF line ends stay", set_crlf, want_set_crlf),
		("one line header", add_one, want_add_one),
		("ops in order", ops_in_order, want_ops),
		("a package header (R-H8)", set_pkg, want_set_pkg),
	]
	bad_edits = edits.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad_edits

	refusals = [
		("set a path entry", [Set({ alias: "util", url: json2 })], "tln: error[internal]: util is a path entry or a foreign URL: tln never changes it (R-H4)"),
		("set a foreign URL", [Set({ alias: "odd", url: json2 })], "tln: error[internal]: odd is a path entry or a foreign URL: tln never changes it (R-H4)"),
		("remove an alias that is not there", [Remove("nope")], "tln: error[internal]: nope is not in the header"),
		("a URL with no version and no hash (R-H3)", [Set({ alias: "json", url: "https://example.com/json-main.tar.gz" })], "tln: error[internal]: https://example.com/json-main.tar.gz is not a release URL with a version and a hash (R-H3)"),
		("add a URL with no version (R-H3)", [Add({ alias: "x", url: "../x/main.roc", is_platform: Bool.False })], "tln: error[internal]: ../x/main.roc is not a release URL with a version and a hash (R-H3)"),
		("set an alias that is not there", [Set({ alias: "nope", url: json2 })], "tln: error[internal]: nope is not in the header"),
		("add an alias that is there", [Add({ alias: "json", url: json2, is_platform: Bool.False })], "tln: error[internal]: json is already in the header"),
		("add the alias roc", [Add({ alias: "roc", url: json2, is_platform: Bool.False })], "tln: error[internal]: roc is already in the header"),
		("a value that needs an escape", [Set({ alias: "json", url: "https://github.com/someone/roc-json/releases/download/2.3.0/a\$b.tar.zst" })], "tln: error[internal]: https://github.com/someone/roc-json/releases/download/2.3.0/a\$b.tar.zst cannot be written to a header"),
	]
	bad_refusals = refusals.keep_if(|(_, ops, want)| shown(edit(app_text, ops)) != Err(want)).map(|(label, ops, want)| (label, want, shown(edit(app_text, ops))))
	dbg bad_refusals

	ops = [Set({ alias: "json", url: json2 }), Add({ alias: "http", url: http1, is_platform: Bool.False }), Pin(n2), Remove("util"), Set({ alias: "gone", url: json2 })]
	spans = Locked.spans({ text: app_text, ops })
	dbg spans
	spans_ok = spans == [json1, "", n1, "../util/main.roc", ""] and Locked.spans({ text: no_roc, ops: [Pin(n2)] }) == [""]
	bad_edits == [] and bad_refusals == [] and spans_ok
}
