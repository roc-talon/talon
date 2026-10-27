import lib.Intent
import lib.Locked
import lib.Vars

VarsTest :: [].{}

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h_web = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"

h_json1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_json2 = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h_json0 = "6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS"

h_http1 = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

h_http2 = "7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW"

h_parser = "HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU"

gh = |owner, repo, version, hash| "https://github.com/${owner}/${repo}/releases/download/${version}/${hash}.tar.zst"

cli = gh("roc-lang", "basic-cli", "0.25.0", h_cli)

web = gh("roc-lang", "basic-webserver", "0.12.0", h_web)

json1 = gh("someone", "roc-json", "2.1.0", h_json1)

json2 = gh("someone", "roc-json", "2.3.0", h_json2)

json0 = gh("someone", "roc-json", "2.0.0", h_json0)

http1 = gh("roc-lang", "http", "1.9.0", h_http1)

http2 = gh("roc-lang", "http", "2.0.0", h_http2)

parser = gh("lukewilliamboswell", "roc-parser", "2.0.0", h_parser)

odd = "https://example.com/lib/1.0.0/${h_http1}.tar.zst"

json_form = "github.com/someone/roc-json/releases/download/{v}/"

## A member: the file, the text of its header, and its `talon.toml` (path, text and role), or none.
member = |file, header, toml| {
	locked = match Locked.read({ path: file, text: header }) {
		Ok(l) => l
		Err(e) => crash e.line()
	}
	parsed = match toml {
		Err(NoToml) => Err(NoToml)
		Ok({ path, text, role }) => match Intent.read({ path, text, role }) {
			Ok({ intent, .. }) => Ok({ path, intent })
			Err(e) => crash e.line()
		}
	}
	{ file, locked, toml: parsed }
}

app_header = |entries| "app [main!] {\n${Str.join_with(entries.map(|e| "\t${e},"), "\n")}\n}\n"

view_var = |v| (v.name, v.group.series, v.is_platform, v.host, v.uses.map(|u| (u.file, u.alias, u.version)), v.ranges.map(|r| (r.range, r.from)))

view_want = |w| (w.key, w.table, w.name, w.range, w.from, w.members, w.stale)

shown_build = |r| match r {
	Ok(b) => Ok((b.vars.map(view_var), b.wants.map(view_want)))
	Err(e) => Err(e.line())
}

# R-VA2 R-VA3 R-VA4 R-VA6 R-VA5 R-I3 R-I4 R-I5 R-I6 R-I8 R-I9 R-C1 R-C4 R-DI11 R-OV1 R-H4: the variables of one project. One variable for each group: a path entry (`util`) is not a variable. The range of a use
# is the key of its alias in `talon.toml` (R-I3, an anchor `=2.0.0` is a range), else the implied range of the header version (R-I4). The order is the packages in header order, then the platform
# (R-VA6), and `priority` goes first (a name that matches no variable is ignored). A host that is not `github.com` has no index: the variable is fixed (R-DI11). A key of `talon.toml` that
# the header does not have is a want (R-I5): a full name, a short name, an override key, or a key that is the group of a header entry under another alias (`js` for `json`, R-I8: stale, R-I9: no second entry).
expect {
	header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "util: \"../util/main.roc\"", "fixed: \"${odd}\""])
	toml_text = "[dependencies]\npf = \"0.25.*\"\nparser = \"=2.0.0\"\nhttp = \"roc-lang/http@^1\"\njs = \"someone/roc-json@^2\"\nyaml = \"yaml@2\"\nnone = \"^1\"\n\n[overrides]\nunicode = \"roc-lang/unicode@^4.2\"\n"
	one = member("/p/main.roc", header, Ok({ path: "/p/talon.toml", text: toml_text, role: Standalone }))
	built = Vars.build({ members: [one], priority: Err(Unset) })
	json_var = (Ok("someone/roc-json"), "2", Bool.False, Indexed, [("/p/main.roc", "json", "2.1.0")], [(">=2.1.0, <3.0.0", "implied by /p/main.roc")])
	parser_var = (Ok("lukewilliamboswell/roc-parser"), "2", Bool.False, Indexed, [("/p/main.roc", "parser", "2.0.0")], [("=2.0.0", "/p/talon.toml:3")])
	fixed_var = (Err(NoName), "1", Bool.False, Fixed("example.com"), [("/p/main.roc", "fixed", "1.0.0")], [(">=1.0.0, <2.0.0", "implied by /p/main.roc")])
	pf_var = (Ok("roc-lang/basic-cli"), "0.25", Bool.True, Indexed, [("/p/main.roc", "pf", "0.25.0")], [("0.25.*", "/p/talon.toml:2")])
	wants = [
		("http", Dependencies, Ok("roc-lang/http"), "^1", "/p/talon.toml:4", ["/p/main.roc"], Err(None)),
		("js", Dependencies, Ok("someone/roc-json"), "^2", "/p/talon.toml:5", ["/p/main.roc"], Ok("json")),
		("yaml", Dependencies, Err(Short("yaml")), "2", "/p/talon.toml:6", ["/p/main.roc"], Err(None)),
		("none", Dependencies, Err(Short("none")), "^1", "/p/talon.toml:7", ["/p/main.roc"], Err(None)),
		("unicode", Overrides, Ok("roc-lang/unicode"), "^4.2", "/p/talon.toml:10", ["/p/main.roc"], Err(None)),
	]
	want_built = Ok(([json_var, parser_var, fixed_var, pf_var], wants))
	dbg shown_build(built)

	prio = Vars.build({ members: [one], priority: Ok(["parser", "nosuch", "roc", "pf"]) })
	prio_order = match prio {
		Ok(b) => b.vars.map(|v| v.uses.map(|u| u.alias))
		Err(e) => [[e.line()]]
	}
	no_toml = member("/p/main.roc", header, Err(NoToml))
	plain = Vars.build({ members: [no_toml], priority: Err(Unset) })
	plain_view = match plain {
		Ok(b) => Ok((b.vars.map(|v| (v.uses.map(|u| u.alias), v.ranges.map(|r| r.range))), b.wants))
		Err(e) => Err(e.line())
	}
	want_plain = Ok(([(["json"], [">=2.1.0, <3.0.0"]), (["parser"], [">=2.0.0, <3.0.0"]), (["fixed"], [">=1.0.0, <2.0.0"]), (["pf"], [">=0.25.0, <0.26.0"])], []))
	# R-OV1: an alias that is only in `[overrides]` has the range of that key, and it is not a want.
	over_header = app_header(["pf: platform \"${cli}\"", "parser: \"${parser}\""])
	over = member("/p/main.roc", over_header, Ok({ path: "/p/talon.toml", text: "[overrides]\nparser = \"=2.0.0\"\n", role: Standalone }))
	over_view = match Vars.build({ members: [over], priority: Err(Unset) }) {
		Ok(b) => Ok((b.vars.map(|v| (v.uses.map(|u| u.alias), v.ranges.map(|r| (r.range, r.from)))), b.wants.map(|w| w.key)))
		Err(e) => Err(e.line())
	}
	want_over = Ok(([(["parser"], [("=2.0.0", "/p/talon.toml:2")]), (["pf"], [(">=0.25.0, <0.26.0", "implied by /p/main.roc")])], []))
	dbg [prio_order, [[Str.inspect(plain_view)]], [[Str.inspect(over_view)]]]
	shown_build(built) == want_built and prio_order == [["parser"], ["pf"], ["json"], ["fixed"]] and plain_view == want_plain and over_view == want_over
}

# R-WS1 R-WS2 R-WS5 R-WS6 R-WS7 R-WS9 R-WS10 R-H8: a workspace. Entries are matched by group, not by alias: `json` in a, `js` in b and `json` in the package member c are one variable with the uses of all members.
# Its ranges are the range of each use: the key of the alias in the nearest `talon.toml` of that member (the root file for a, the own file of b and c), or the implied range. A range in one file limits
# the variable of all members (R-WS7). Two series of one package are 2 variables (R-WS10). A platform group is a variable, and the apps on 2 platforms have 2 (R-WS9). A key of the root file that
# no member under it has is a want, and it needs exactly one such member (R-WS6): with 2, `Vars.check_keys` (the stop of `install`) fails with exit 2 and names `tln add --file`. `build` itself does not fail (slice 017).
expect {
	a_header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "http: \"${http1}\""])
	b_header = app_header(["pf: platform \"${web}\"", "js: \"${json2}\"", "http2: \"${http2}\""])
	c_header = "package [Lib] {\n\tjson: \"${json0}\",\n}\n"
	d_header = app_header(["pf: platform \"${cli}\""])
	root_text = "[workspace]\nmembers = [\"apps/*/main.roc\", \"libs/*/main.roc\"]\n\n[dependencies]\njson = \"^2.2\"\nnewdep = \"acme/newdep@^1\"\n"
	root_toml = Ok({ path: "/w/talon.toml", text: root_text, role: Root })
	a = member("/w/apps/a/main.roc", a_header, root_toml)
	b = member("/w/apps/b/main.roc", b_header, Ok({ path: "/w/apps/b/talon.toml", text: "[dependencies]\njs = \"^2.3\"\n", role: Member }))
	c = member("/w/libs/c/main.roc", c_header, Ok({ path: "/w/libs/c/talon.toml", text: "# c has its own intent\n[dependencies]\njson = \"^2.0\"\n", role: Member }))
	d = member("/w/apps/d/main.roc", d_header, root_toml)
	# Slice 017 (slice 009 G2): `build` gives the wants of 2 members and does not fail. The stop of R-WS6 is `Vars.check_keys`, which only `install` calls.
	two_wants = match Vars.build({ members: [a, b, c, d], priority: Err(Unset) }) {
		Ok(built) => match Vars.check_keys(built.wants) {
			Ok(_) => "no failure"
			Err(e) => e.line()
		}
		Err(e) => "build: ${e.line()}"
	}
	want_two = "tln: error[usage]: /w/talon.toml:6: the key 'newdep' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> acme/newdep for one of them."
	built = Vars.build({ members: [a, b, c], priority: Err(Unset) })
	json_var = (
		Ok("someone/roc-json"),
		"2",
		Bool.False,
		Indexed,
		[("/w/apps/a/main.roc", "json", "2.1.0"), ("/w/apps/b/main.roc", "js", "2.3.0"), ("/w/libs/c/main.roc", "json", "2.0.0")],
		[("^2.2", "/w/talon.toml:5"), ("^2.3", "/w/apps/b/talon.toml:2"), ("^2.0", "/w/libs/c/talon.toml:3")],
	)
	http1_var = (Ok("roc-lang/http"), "1", Bool.False, Indexed, [("/w/apps/a/main.roc", "http", "1.9.0")], [(">=1.9.0, <2.0.0", "implied by /w/apps/a/main.roc")])
	http2_var = (Ok("roc-lang/http"), "2", Bool.False, Indexed, [("/w/apps/b/main.roc", "http2", "2.0.0")], [(">=2.0.0, <3.0.0", "implied by /w/apps/b/main.roc")])
	cli_var = (Ok("roc-lang/basic-cli"), "0.25", Bool.True, Indexed, [("/w/apps/a/main.roc", "pf", "0.25.0")], [(">=0.25.0, <0.26.0", "implied by /w/apps/a/main.roc")])
	web_var = (Ok("roc-lang/basic-webserver"), "0.12", Bool.True, Indexed, [("/w/apps/b/main.roc", "pf", "0.12.0")], [(">=0.12.0, <0.13.0", "implied by /w/apps/b/main.roc")])
	want_built = Ok(([json_var, http1_var, http2_var, cli_var, web_var], [("newdep", Dependencies, Ok("acme/newdep"), "^1", "/w/talon.toml:6", ["/w/apps/a/main.roc"], Err(None))]))
	dbg shown_build(built)
	dbg two_wants
	two_wants == want_two and shown_build(built) == want_built
}

# R-SP1 R-SP2 R-SP3 R-SP5 R-SP10 R-SP11 R-SP14 R-SP19 R-SP20 R-SP21 R-WS3 R-WS8 R-VA5 R-DI11: the free and held variables of a command. `install` with no names frees a variable that has a use outside the
# intersection of its ranges (R-SP20, R-WS3: the members hold 2.1.0, 2.3.0 and 2.0.0, and the ranges are `^2.2`, `^2.3`, `^2.0`), and holds the others (R-SP19). With no `talon.toml` and one member nothing
# is free (R-SP21). `update` with no names frees each variable that has an index (R-SP2), and holds a fixed host with a note (R-DI11). `update X Y` frees only the named (R-SP3, R-SP11). `update X@sel`
# replaces the ranges of X with the selector and opens the series (R-SP5). A name is an alias of some member: `pf` is 2 groups in the workspace (R-WS8): exit 2 and the line of the tie of R-SC14 (`Lookup.find` prints the list before it, slice 014). The picker of `update -i`
# lists the free variables of `update` in order (R-SP14).
expect {
	a = member("/w/apps/a/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "http: \"${http1}\""]), Ok({ path: "/w/talon.toml", text: "[workspace]\nmembers = []\n\n[dependencies]\njson = \"^2.2\"\n", role: Root }))
	b = member("/w/apps/b/main.roc", app_header(["pf: platform \"${web}\"", "js: \"${json2}\"", "http2: \"${http2}\""]), Ok({ path: "/w/apps/b/talon.toml", text: "[dependencies]\njs = \"^2.3\"\n", role: Member }))
	c = member("/w/libs/c/main.roc", "package [Lib] {\n\tjson: \"${json0}\",\n}\n", Ok({ path: "/w/libs/c/talon.toml", text: "# c has its own intent\n[dependencies]\njson = \"^2.0\"\n", role: Member }))
	vars = match Vars.build({ members: [a, b, c], priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	one = member("/p/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "fixed: \"${odd}\""]), Err(NoToml))
	one_vars = match Vars.build({ members: [one], priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	view = |r| match r {
		Ok(scoped) => Ok(scoped.map(|s| (s.variable.uses.map(|u| u.alias), s.free, s.any_series, s.note)))
		Err(e) => Err(e.line())
	}
	scope = |command, names, selectors, vs| Vars.scope({ command, names, selectors, fixed: [], vars: vs })
	fixed_note = Ok("fixed: example.com has no index without a registry")
	rows = [
		(
			"install: the group that the members hold at 3 versions is free (R-SP20, R-WS3)",
			view(scope(Install, [], [], vars)),
			Ok([(["json", "js", "json"], Bool.True, Bool.False, Err(None)), (["http"], Bool.False, Bool.False, Err(None)), (["http2"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None))]),
		),
		(
			"install, no talon.toml, one member: nothing is free (R-SP21, R-SP19)",
			view(scope(Install, [], [], one_vars)),
			Ok([(["json"], Bool.False, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Err(None)), (["fixed"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None))]),
		),
		(
			"update: each indexed variable, the fixed host is held with a note (R-SP2, R-DI11)",
			view(scope(Update, [], [], one_vars)),
			Ok([(["json"], Bool.True, Bool.False, Err(None)), (["parser"], Bool.True, Bool.False, Err(None)), (["fixed"], Bool.False, Bool.False, fixed_note), (["pf"], Bool.True, Bool.False, Err(None))]),
		),
		(
			"update parser json: only these 2 (R-SP3)",
			view(scope(Update, ["parser", "json"], [], one_vars)),
			Ok([(["json"], Bool.True, Bool.False, Err(None)), (["parser"], Bool.True, Bool.False, Err(None)), (["fixed"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None))]),
		),
		(
			"update js: the alias of one member names the group (R-WS1)",
			view(scope(Update, ["js"], [], vars)),
			Ok([(["json", "js", "json"], Bool.True, Bool.False, Err(None)), (["http"], Bool.False, Bool.False, Err(None)), (["http2"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None))]),
		),
		(
			"update fixed: a fixed host stays held, also when named (R-VA5, R-DI11)",
			view(scope(Update, ["fixed"], [], one_vars)),
			Ok([(["json"], Bool.False, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Err(None)), (["fixed"], Bool.False, Bool.False, fixed_note), (["pf"], Bool.False, Bool.False, Err(None))]),
		),
		(
			"update json@^3: free, any series (R-SP5)",
			view(scope(Update, ["json"], [{ alias: "json", range: "^3" }], one_vars)),
			Ok([(["json"], Bool.True, Bool.True, Err(None)), (["parser"], Bool.False, Bool.False, Err(None)), (["fixed"], Bool.False, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Err(None))]),
		),
		("update nope", view(scope(Update, ["nope"], [], vars)), Err("tln: error[usage]: 'nope' is not in the project")),
		("update pf: 2 groups (R-WS8)", view(scope(Update, ["pf"], [], vars)), Err("tln: error[usage]: \"pf\" matches 2 packages. Use a name from the list.")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad

	ranges_of = |r, alias| match r {
		Ok(scoped) => match scoped.find_first(|s| s.variable.uses.any(|u| u.alias == alias)) {
			Ok(s) => s.variable.ranges.map(|x| (x.range, x.from))
			Err(_) => []
		}
		Err(_) => []
	}
	selector_ranges = ranges_of(scope(Update, ["json"], [{ alias: "json", range: "^3" }], one_vars), "json")
	picks = [Vars.picker(one_vars), Vars.picker([])]
	dbg [selector_ranges.len() == 1, picks.len() == 2]
	bad == [] and selector_ranges == [("^3", "selector")] and picks == [["json", "parser", "pf"], []]
}

# R-H9 R-H4 R-I3 R-I5 R-OV1 (slice 015): a key of `talon.toml` whose alias is an unmanaged entry (a path entry or a foreign URL) is no constraint and adds no entry. The entry is no variable (R-H7), so the key has no variable to
# limit, and the header has the alias, so the key is no want (R-I5): not for `[dependencies]`, not for `[overrides]`, and not when the value names a repo (`roc-lang/http@^2`). The key of a release in the same file still
# gives its range (R-I3). So `install`, `update` and `verify` with no names keep the unmanaged entries byte for byte, and the key applies again when the entry is a release.
expect {
	header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "util: \"../util/main.roc\"", "odd: \"https://example.com/pkg/latest.tar.gz\""])
	toml_text = "[dependencies]\nutil = \"^1\"\nodd = \"roc-lang/http@^2\"\njson = \"^2.1\"\n\n[overrides]\nutil = \"=1.0.0\"\nodd = \"roc-lang/http@=2.0.0\"\n"
	one = member("/p/main.roc", header, Ok({ path: "/p/talon.toml", text: toml_text, role: Standalone }))
	view = match Vars.build({ members: [one], priority: Err(Unset) }) {
		Ok(b) => Ok((b.vars.map(|v| (v.uses.map(|u| u.alias), v.ranges.map(|r| (r.range, r.from)))), b.wants.map(view_want)))
		Err(e) => Err(e.line())
	}
	want = Ok(([(["json"], [("^2.1", "/p/talon.toml:4")]), (["pf"], [(">=0.25.0, <0.26.0", "implied by /p/main.roc")])], []))
	dbg view
	view == want
}

# R-SP23 R-SP3 R-SP4 R-SP7 R-SP19 R-WS12 R-VA5 R-DI11 R-SP2 R-SP5 (slice 017): which held variable the second search of a held move may move (`Scoped.movable`). A variable is movable when the command holds it only because the user
# did not name it: `install` with no names holds each variable in range (R-SP19), `update X` and `update X@sel` hold all others (R-SP3, R-SP5), and a group that other members have is held (R-WS12). A free variable is not movable
# (it is free), and these are never movable: an anchor (a range with `=`, R-VA5) and a fixed host (R-DI11, also when it is named). `update` with no names frees each indexed variable, so nothing is held and nothing is movable (R-SP2).
expect {
	one = member("/p/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "fixed: \"${odd}\""]), Err(NoToml))
	anchor = member("/p/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "fixed: \"${odd}\""]), Ok({ path: "/p/talon.toml", text: "[dependencies]\nparser = \"=2.0.0\"\n", role: Standalone }))
	a = member("/w/apps/a/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "http: \"${http1}\""]), Ok({ path: "/w/talon.toml", text: "[workspace]\nmembers = []\n\n[dependencies]\njson = \"^2.2\"\n", role: Root }))
	b = member("/w/apps/b/main.roc", app_header(["pf: platform \"${web}\"", "js: \"${json2}\"", "http2: \"${http2}\""]), Ok({ path: "/w/apps/b/talon.toml", text: "[dependencies]\njs = \"^2.3\"\n", role: Member }))
	vars_of = |members| match Vars.build({ members, priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	view = |r| match r {
		Ok(scoped) => Ok(scoped.map(|s| (s.variable.uses.map(|u| u.alias), s.free, s.movable)))
		Err(e) => Err(e.line())
	}
	scope = |command, names, selectors, vs| Vars.scope({ command, names, selectors, fixed: [], vars: vs })
	rows = [
		(
			"install, no names: each held variable is movable, the fixed host is not (R-SP19, R-DI11)",
			view(scope(Install, [], [], vars_of([one]))),
			Ok([(["json"], Bool.False, Bool.True), (["parser"], Bool.False, Bool.True), (["fixed"], Bool.False, Bool.False), (["pf"], Bool.False, Bool.True)]),
		),
		(
			"update, no names: nothing is held, so nothing is movable (R-SP2)",
			view(scope(Update, [], [], vars_of([one]))),
			Ok([(["json"], Bool.True, Bool.False), (["parser"], Bool.True, Bool.False), (["fixed"], Bool.False, Bool.False), (["pf"], Bool.True, Bool.False)]),
		),
		(
			"update parser json: the others are held by the user's choice, pf is movable (R-SP3)",
			view(scope(Update, ["parser", "json"], [], vars_of([one]))),
			Ok([(["json"], Bool.True, Bool.False), (["parser"], Bool.True, Bool.False), (["fixed"], Bool.False, Bool.False), (["pf"], Bool.False, Bool.True)]),
		),
		(
			"update fixed: a fixed host is never movable, also when named (R-DI11)",
			view(scope(Update, ["fixed"], [], vars_of([one]))),
			Ok([(["json"], Bool.False, Bool.True), (["parser"], Bool.False, Bool.True), (["fixed"], Bool.False, Bool.False), (["pf"], Bool.False, Bool.True)]),
		),
		(
			"update json@^3 (R-SP5, R-SP4: the picker gives the same names): the others are movable",
			view(scope(Update, ["json"], [{ alias: "json", range: "^3" }], vars_of([one]))),
			Ok([(["json"], Bool.True, Bool.False), (["parser"], Bool.False, Bool.True), (["fixed"], Bool.False, Bool.False), (["pf"], Bool.False, Bool.True)]),
		),
		(
			"update json: an anchor (parser = \"=2.0.0\") is held and never movable (R-VA5, R-SP23)",
			view(scope(Update, ["json"], [], vars_of([anchor]))),
			Ok([(["json"], Bool.True, Bool.False), (["parser"], Bool.False, Bool.False), (["fixed"], Bool.False, Bool.False), (["pf"], Bool.False, Bool.True)]),
		),
		(
			"install in a workspace: json is free (3 versions are out of range), the groups that the members hold are movable (R-WS12, R-SP19)",
			view(scope(Install, [], [], vars_of([a, b]))),
			Ok([(["json", "js"], Bool.True, Bool.False), (["http"], Bool.False, Bool.True), (["http2"], Bool.False, Bool.True), (["pf"], Bool.False, Bool.True), (["pf"], Bool.False, Bool.True)]),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-WS6 R-I5 R-WS5 R-PD5 (slice 017, slice 009 G2): `Vars.check_keys` is the stop of `install` for a key of the root `talon.toml` that no header has, when 2 or more members are under the file. A stale key (the group is in a header under
# another alias, R-I8) is no failure. A key of a file with one member is no failure (`install` adds the entry to that member). A short name has no repository: the line names the key. No want, no failure.
expect {
	root_text = "[workspace]\nmembers = [\"apps/*/main.roc\"]\n\n[dependencies]\njs = \"someone/roc-json@^2\"\nyaml = \"yaml@2\"\nnewdep = \"acme/newdep@^1\"\n"
	root_toml = Ok({ path: "/w/talon.toml", text: root_text, role: Root })
	a = member("/w/apps/a/main.roc", app_header(["pf: platform \"${cli}\"", "json: \"${json1}\""]), root_toml)
	d = member("/w/apps/d/main.roc", app_header(["pf: platform \"${cli}\""]), root_toml)
	wants_of = |members| match Vars.build({ members, priority: Err(Unset) }) {
		Ok(built) => built.wants
		Err(e) => crash e.line()
	}
	check = |wants, keys| match Vars.check_keys(wants.keep_if(|w| keys.contains(w.key))) {
		Ok(_) => "ok"
		Err(e) => e.line()
	}
	two = wants_of([a, d])
	one = wants_of([a])
	rows = [
		("a stale key is no failure (R-I8)", check(two, ["js"]), "ok"),
		("a short name with 2 members names the key", check(two, ["yaml"]), "tln: error[usage]: /w/talon.toml:6: the key 'yaml' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> yaml for one of them."),
		("a full name with 2 members: the first key that fails is the failure", check(two, ["js", "yaml", "newdep"]), "tln: error[usage]: /w/talon.toml:6: the key 'yaml' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> yaml for one of them."),
		("a full name with 2 members", check(two, ["newdep"]), "tln: error[usage]: /w/talon.toml:7: the key 'newdep' is in no header, and 2 members are under /w: /w/apps/a/main.roc, /w/apps/d/main.roc. Run tln add --file <member file> acme/newdep for one of them."),
		("one member under the file: no failure (install adds the entry)", check(one, ["js", "yaml", "newdep"]), "ok"),
		("no want", check([], []), "ok"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP6 R-SP7 R-UP1 R-VA5 R-DI11 R-SP23 R-UP12 R-UP13 (slice 038): the scope of `tln upgrade` (`Vars.scope` with the command `Upgrade`). With no names, each indexed variable is free (R-SP6), except an anchor (a range with `=`),
# which is held and gets the note `<alias>: anchor, held` (R-UP1, R-VA5), and a fixed host, which is held with its note (R-DI11). With names, only the named are free (R-SP7): a named anchor is free, and a named
# fixed host is held. A free variable has no range (R-UP1) and opens every series (`any_series`). A movable variable (held only because the user did not name it, R-SP23) has no range either, so a move is not
# bounded by the key of `talon.toml` (R-SP23: "none in upgrade"). A held anchor keeps its range. The nightly is not a variable here (slice 039 frees it: R-UP12, R-UP13).
expect {
	toml = |text| Ok({ path: "/p/talon.toml", text, role: Standalone })
	header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "fixed: \"${odd}\""])
	plain = member("/p/main.roc", header, Err(NoToml))
	anchored = member("/p/main.roc", header, toml("[dependencies]\nparser = \"=2.0.0\"\njson = \"^2.1\"\n"))
	vars_of = |m| match Vars.build({ members: [m], priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	view = |r| match r {
		Ok(scoped) => Ok(scoped.map(|s| (s.variable.uses.map(|u| u.alias), s.free, s.movable, s.any_series, s.note, s.variable.ranges.map(|x| x.range))))
		Err(e) => Err(e.line())
	}
	scope = |names, vs| view(Vars.scope({ command: Upgrade, names, selectors: [], fixed: [], vars: vs }))
	fixed_note = Ok("fixed: example.com has no index without a registry")
	rows = [
		(
			"upgrade, no talon.toml: each indexed variable is free with no range, a fixed host is held with its note (R-SP6, R-UP1, R-DI11)",
			scope([], vars_of(plain)),
			Ok([
				(["json"], Bool.True, Bool.False, Bool.True, Err(None), []),
				(["parser"], Bool.True, Bool.False, Bool.True, Err(None), []),
				(["fixed"], Bool.False, Bool.False, Bool.False, fixed_note, [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.True, Bool.False, Bool.True, Err(None), []),
			]),
		),
		(
			"upgrade, an anchor and a key: the anchor is held with its note and keeps its range, the key `^2.1` of a free variable is dropped (R-UP1, R-VA5)",
			scope([], vars_of(anchored)),
			Ok([
				(["json"], Bool.True, Bool.False, Bool.True, Err(None), []),
				(["parser"], Bool.False, Bool.False, Bool.False, Ok("parser: anchor, held"), ["=2.0.0"]),
				(["fixed"], Bool.False, Bool.False, Bool.False, fixed_note, [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.True, Bool.False, Bool.True, Err(None), []),
			]),
		),
		(
			"upgrade parser: a named anchor is free, with no range, and the others are held and movable with no range (R-SP7, R-VA5, R-SP23)",
			scope(["parser"], vars_of(anchored)),
			Ok([
				(["json"], Bool.False, Bool.True, Bool.False, Err(None), []),
				(["parser"], Bool.True, Bool.False, Bool.True, Err(None), []),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None), [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.False, Bool.True, Bool.False, Err(None), []),
			]),
		),
		(
			"upgrade json: only json is free, an unnamed anchor is neither free nor movable and has no note (R-SP7, R-SP23)",
			scope(["json"], vars_of(anchored)),
			Ok([
				(["json"], Bool.True, Bool.False, Bool.True, Err(None), []),
				(["parser"], Bool.False, Bool.False, Bool.False, Err(None), ["=2.0.0"]),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None), [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.False, Bool.True, Bool.False, Err(None), []),
			]),
		),
		(
			"upgrade fixed: a named fixed host stays held and keeps its note (R-DI11)",
			scope(["fixed"], vars_of(plain)),
			Ok([
				(["json"], Bool.False, Bool.True, Bool.False, Err(None), []),
				(["parser"], Bool.False, Bool.True, Bool.False, Err(None), []),
				(["fixed"], Bool.False, Bool.False, Bool.False, fixed_note, [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.False, Bool.True, Bool.False, Err(None), []),
			]),
		),
		("upgrade nope: the name is no alias (R-SC14)", scope(["nope"], vars_of(plain)), Err("tln: error[usage]: 'nope' is not in the project")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP8 R-SP23 R-UP13 (slice 039): the scope of `tln upgrade roc` (`Vars.scope` with the command `NightlyOnly`: the nightly is free, the packages are held). No package is free (R-SP8) and none opens a series. A held package that
# is not an anchor and has an indexed host is movable, with no range, as in `upgrade <name>` (R-SP23, question Q2 of slice 039). An anchor keeps its range and is not movable. A fixed host is not movable. No note is printed:
# the notes `<alias>: anchor, held` belong to a run that frees the packages (R-UP1).
expect {
	toml = |text| Ok({ path: "/p/talon.toml", text, role: Standalone })
	header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "fixed: \"${odd}\""])
	plain = member("/p/main.roc", header, Err(NoToml))
	anchored = member("/p/main.roc", header, toml("[dependencies]\nparser = \"=2.0.0\"\njson = \"^2.1\"\n"))
	vars_of = |m| match Vars.build({ members: [m], priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	view = |r| match r {
		Ok(scoped) => Ok(scoped.map(|s| (s.variable.uses.map(|u| u.alias), s.free, s.movable, s.any_series, s.note, s.variable.ranges.map(|x| x.range))))
		Err(e) => Err(e.line())
	}
	scope = |vs| view(Vars.scope({ command: NightlyOnly, names: [], selectors: [], fixed: [], vars: vs }))
	rows = [
		(
			"upgrade roc, no talon.toml: no package is free, the indexed ones are movable with no range, the fixed host is neither (R-SP8, R-SP23)",
			scope(vars_of(plain)),
			Ok([
				(["json"], Bool.False, Bool.True, Bool.False, Err(None), []),
				(["parser"], Bool.False, Bool.True, Bool.False, Err(None), []),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None), [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.False, Bool.True, Bool.False, Err(None), []),
			]),
		),
		(
			"upgrade roc, an anchor and a key: the anchor keeps its range and is not movable, with no note (R-SP8, R-VA5)",
			scope(vars_of(anchored)),
			Ok([
				(["json"], Bool.False, Bool.True, Bool.False, Err(None), []),
				(["parser"], Bool.False, Bool.False, Bool.False, Err(None), ["=2.0.0"]),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None), [">=1.0.0, <2.0.0"]),
				(["pf"], Bool.False, Bool.True, Bool.False, Err(None), []),
			]),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP23 R-IN10 R-SP8 (slice 085): `fixed` is a list of aliases that the command never moves. `tln init --platform owner/repo@<version>` fixes `pf`: the user named the release, so the second search (R-SP24) must not move the platform.
# The scope is the one of `tln upgrade roc` (`NightlyOnly`: no package is free, the held ones are movable). With `fixed: ["pf"]` the platform is held and not movable, and the other held packages stay movable. With `fixed: []` the platform is
# movable, as before. An alias that no variable has changes nothing. The fixed variable keeps its state otherwise: not free, no series, no note. A `Fixed` host stays not movable also when it is not in the list.
expect {
	header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\"", "fixed: \"${odd}\""])
	plain = member("/p/main.roc", header, Err(NoToml))
	vars_of = |m| match Vars.build({ members: [m], priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	view = |r| match r {
		Ok(scoped) => Ok(scoped.map(|s| (s.variable.uses.map(|u| u.alias), s.free, s.movable, s.any_series, s.note)))
		Err(e) => Err(e.line())
	}
	scope = |command, names, fixed| view(Vars.scope({ command, names, selectors: [], fixed, vars: vars_of(plain) }))
	rows = [
		(
			"upgrade roc, fixed pf: the platform is held and not movable, json and parser stay movable (R-SP23, R-IN10)",
			scope(NightlyOnly, [], ["pf"]),
			Ok([
				(["json"], Bool.False, Bool.True, Bool.False, Err(None)),
				(["parser"], Bool.False, Bool.True, Bool.False, Err(None)),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None)),
				(["pf"], Bool.False, Bool.False, Bool.False, Err(None)),
			]),
		),
		(
			"upgrade roc, nothing fixed: the platform is movable as before (R-SP8, R-SP23)",
			scope(NightlyOnly, [], []),
			Ok([
				(["json"], Bool.False, Bool.True, Bool.False, Err(None)),
				(["parser"], Bool.False, Bool.True, Bool.False, Err(None)),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None)),
				(["pf"], Bool.False, Bool.True, Bool.False, Err(None)),
			]),
		),
		(
			"upgrade roc, an alias that no variable has: nothing changes",
			scope(NightlyOnly, [], ["nosuch"]),
			scope(NightlyOnly, [], []),
		),
		(
			"upgrade roc, two fixed aliases: both are not movable",
			scope(NightlyOnly, [], ["pf", "json"]),
			Ok([
				(["json"], Bool.False, Bool.False, Bool.False, Err(None)),
				(["parser"], Bool.False, Bool.True, Bool.False, Err(None)),
				(["fixed"], Bool.False, Bool.False, Bool.False, Err(None)),
				(["pf"], Bool.False, Bool.False, Bool.False, Err(None)),
			]),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA4 R-SP23 R-SP6 R-SP7 R-SP3 R-SP19 R-SP20 R-PA12 (slice 043): a patched entry is an anchor in `update` and `upgrade`. A variable is patched when a use is an entry (not the platform) whose alias is a key of the `[patch]` table of the `talon.toml` of its
# member. With no names it is held, it is never movable (R-SP23), and `update` and `upgrade` print the note `<alias>: patched, held` (the alias of its first use). A command that names it frees it (R-SP3, R-SP7). `install` holds it as it holds a variable
# that satisfies its range (R-SP19), with no note, and frees it when it is outside its range (R-SP20). A `[patch]` key of the platform or of a name that the header does not have makes no variable patched. In a workspace, a use in one member is enough:
# the group has one value (R-WS2).
expect {
	entry = |alias| "${alias} = { path = \"./.talon/patches/${alias}/main.roc\", base = \"${h_json1}\" }\n"
	header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "parser: \"${parser}\""])
	toml = |extra| Ok({ path: "/p/talon.toml", text: "[dependencies]\njson = \"^2.1\"\n\n[patch]\n${entry("json")}${extra}", role: Standalone })
	patched = member("/p/main.roc", header, toml(""))
	out_of_range = member("/p/main.roc", header, Ok({ path: "/p/talon.toml", text: "[dependencies]\njson = \"^2.3\"\n\n[patch]\n${entry("json")}", role: Standalone }))
	platform_key = member("/p/main.roc", header, Ok({ path: "/p/talon.toml", text: "[patch]\n${entry("pf")}${entry("ghost")}", role: Standalone }))
	with_anchor = member("/p/main.roc", header, Ok({ path: "/p/talon.toml", text: "[dependencies]\njson = \"=2.1.0\"\n\n[patch]\n${entry("json")}", role: Standalone }))
	fixed_header = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\"", "fixed: \"${odd}\""])
	fixed_patched = member("/p/main.roc", fixed_header, Ok({ path: "/p/talon.toml", text: "[patch]\n${entry("fixed")}", role: Standalone }))
	fixed_note = Ok("fixed: example.com has no index without a registry")
	vars_of = |ms| match Vars.build({ members: ms, priority: Err(Unset) }) {
		Ok(built) => built.vars
		Err(e) => crash e.line()
	}
	view = |r| match r {
		Ok(scoped) => Ok(scoped.map(|s| (s.variable.uses.map(|u| u.alias), s.variable.patched, s.free, s.movable, s.note)))
		Err(e) => Err(e.line())
	}
	scope = |command, names, ms| view(Vars.scope({ command, names, selectors: [], fixed: [], vars: vars_of(ms) }))
	note = Ok("json: patched, held")
	rows = [
		(
			"update, no names: json is held, not movable, with the note (R-PA4, R-SP6)",
			scope(Update, [], [patched]),
			Ok([(["json"], Bool.True, Bool.False, Bool.False, note), (["parser"], Bool.False, Bool.True, Bool.False, Err(None)), (["pf"], Bool.False, Bool.True, Bool.False, Err(None))]),
		),
		(
			"update json: the named entry is free (R-SP3), the others are held and movable",
			scope(Update, ["json"], [patched]),
			Ok([(["json"], Bool.True, Bool.True, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Bool.True, Err(None)), (["pf"], Bool.False, Bool.False, Bool.True, Err(None))]),
		),
		(
			"update parser: json is held and never movable, and has no note (R-SP23, R-SP3)",
			scope(Update, ["parser"], [patched]),
			Ok([(["json"], Bool.True, Bool.False, Bool.False, Err(None)), (["parser"], Bool.False, Bool.True, Bool.False, Err(None)), (["pf"], Bool.False, Bool.False, Bool.True, Err(None))]),
		),
		(
			"upgrade, no names: json is held with the note, the others are free (R-SP6, R-PA4)",
			scope(Upgrade, [], [patched]),
			Ok([(["json"], Bool.True, Bool.False, Bool.False, note), (["parser"], Bool.False, Bool.True, Bool.False, Err(None)), (["pf"], Bool.False, Bool.True, Bool.False, Err(None))]),
		),
		(
			"upgrade json: a named patched entry is free (R-SP7)",
			scope(Upgrade, ["json"], [patched]),
			Ok([(["json"], Bool.True, Bool.True, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Bool.True, Err(None)), (["pf"], Bool.False, Bool.False, Bool.True, Err(None))]),
		),
		(
			"upgrade roc (NightlyOnly): no package is free, json is not movable, the others are (R-SP8, R-SP23)",
			scope(NightlyOnly, [], [patched]),
			Ok([(["json"], Bool.True, Bool.False, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Bool.True, Err(None)), (["pf"], Bool.False, Bool.False, Bool.True, Err(None))]),
		),
		(
			"install, no names: json satisfies its range, so it is held and not movable, with no note (R-SP19, R-SP23)",
			scope(Install, [], [patched]),
			Ok([(["json"], Bool.True, Bool.False, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Bool.True, Err(None)), (["pf"], Bool.False, Bool.False, Bool.True, Err(None))]),
		),
		(
			"install, the key ^2.3 does not admit json 2.1.0: json is free (R-SP20), not movable",
			scope(Install, [], [out_of_range]),
			Ok([(["json"], Bool.True, Bool.True, Bool.False, Err(None)), (["parser"], Bool.False, Bool.False, Bool.True, Err(None)), (["pf"], Bool.False, Bool.False, Bool.True, Err(None))]),
		),
		(
			"upgrade, no names: a patched entry with a `=` range has the note `patched, held`, not `anchor, held` (gap row: the patch is named first)",
			scope(Upgrade, [], [with_anchor]),
			Ok([(["json"], Bool.True, Bool.False, Bool.False, note), (["parser"], Bool.False, Bool.True, Bool.False, Err(None)), (["pf"], Bool.False, Bool.True, Bool.False, Err(None))]),
		),
		(
			"update, no names: a patched entry with a fixed host has the note of the fixed host, not `patched, held` (gap row, R-DI11)",
			scope(Update, [], [fixed_patched]),
			Ok([(["json"], Bool.False, Bool.True, Bool.False, Err(None)), (["fixed"], Bool.True, Bool.False, Bool.False, fixed_note), (["pf"], Bool.False, Bool.True, Bool.False, Err(None))]),
		),
		(
			"a [patch] key of the platform and of a name that the header has not: nothing is patched (R-PA12)",
			scope(Update, [], [platform_key]),
			Ok([(["json"], Bool.False, Bool.True, Bool.False, Err(None)), (["parser"], Bool.False, Bool.True, Bool.False, Err(None)), (["pf"], Bool.False, Bool.True, Bool.False, Err(None))]),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA4 R-WS2 R-PA12 (slice 043): in a workspace the patch is a fact of the member that has the `[patch]` key. Member a has the key `json`, member b has the same release as `j2` and no key. The group is one variable and one value (R-WS2), so it is
# patched, and its note names the alias of its first use. Without the key in any member, nothing is patched.
expect {
	header_a = app_header(["pf: platform \"${cli}\"", "json: \"${json1}\""])
	header_b = app_header(["pf: platform \"${cli}\"", "j2: \"${json1}\""])
	a = member("/w/a/main.roc", header_a, Ok({ path: "/w/a/talon.toml", text: "[patch]\njson = { path = \"./.talon/patches/json/main.roc\", base = \"${h_json1}\" }\n", role: Member }))
	b = member("/w/b/main.roc", header_b, Err(NoToml))
	view = |ms| match Vars.build({ members: ms, priority: Err(Unset) }) {
		Ok(built) => match Vars.scope({ command: Update, names: [], selectors: [], fixed: [], vars: built.vars }) {
			Ok(scoped) => scoped.map(|s| (s.variable.uses.map(|u| (u.file, u.alias)), s.variable.patched, s.free, s.note))
			Err(e) => crash e.line()
		}
		Err(e) => crash e.line()
	}
	rows = [
		(
			"the key is in member a: the group is patched and held, the note has the alias of the first use",
			view([a, b]),
			[(([("/w/a/main.roc", "json"), ("/w/b/main.roc", "j2")]), Bool.True, Bool.False, Ok("json: patched, held")), ([("/w/a/main.roc", "pf"), ("/w/b/main.roc", "pf")], Bool.False, Bool.True, Err(None))],
		),
		(
			"the key is in no member: no patch",
			view([member("/w/a/main.roc", header_a, Err(NoToml)), b]),
			[([("/w/a/main.roc", "json"), ("/w/b/main.roc", "j2")], Bool.False, Bool.True, Err(None)), ([("/w/a/main.roc", "pf"), ("/w/b/main.roc", "pf")], Bool.False, Bool.True, Err(None))],
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
