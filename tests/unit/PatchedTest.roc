import lib.Ident
import lib.Intent
import lib.LadderPlan
import lib.Locked
import lib.Patched

PatchedTest :: [].{}

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h_json0 = "6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS"

h_json1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_json2 = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h_parser = "HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU"

h_parser2 = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

gh = |owner, repo, version, hash| "https://github.com/${owner}/${repo}/releases/download/${version}/${hash}.tar.zst"

cli = gh("roc-lang", "basic-cli", "0.25.0", h_cli)

json0 = gh("someone", "roc-json", "2.0.0", h_json0)

json1 = gh("someone", "roc-json", "2.1.0", h_json1)

json2 = gh("someone", "roc-json", "2.3.0", h_json2)

parser = gh("lukewilliamboswell", "roc-parser", "2.0.0", h_parser)

parser2 = gh("lukewilliamboswell", "roc-parser", "2.1.0", h_parser2)

foreign = "https://example.org/a.tar.gz"

header_text = "app [main!] {\n\tpf: platform \"${cli}\",\n\tjson: \"${json1}\",\n\tparser: \"${parser}\",\n\tutil: \"../util/main.roc\",\n\tsrc: \"${foreign}\",\n\troc: \"nightly-2026-10-14-38a3029\",\n}\n"

rows_of = |text| match Locked.read({ path: "/p/main.roc", text }) {
	Ok(l) => l.rows
	Err(e) => crash e.line()
}

patches_of = |text| match Intent.read({ path: "/p/talon.toml", text, role: Standalone }) {
	Ok({ intent, .. }) => intent.patches
	Err(e) => crash e.line()
}

entry_text = |alias, path, base| "${alias} = { path = \"${path}\", base = \"${base}\" }\n"

default_entry = |alias, base| entry_text(alias, "./.talon/patches/${alias}/main.roc", base)

row = |label, got, want| (label, Str.inspect(got), Str.inspect(want))

view_entry = |e| (e.alias, e.hash, e.base, e.path, e.file, e.dir)

# R-PA12 R-PX5 R-PA10 R-PA6 R-PA14 R-PA8 R-PA9 (slice 043): the patches of one header. A `[patch]` entry is a patch of the header when its key is the alias of a release entry that is not the platform. The order is the order of the `[patch]` lines. The key of
# the platform, of a path entry, of a foreign URL and of a name that the header has not is no patch of this header: no entry, no failure (question Q5). `file` is the `path` of the entry seen from the dir of the `talon.toml` (`.` and `..` removed, an
# absolute path stays), `dir` is the dir of that file. `replaces` is the `--replace-dep` pair of each entry: the URL of the header entry and the file. `stale` are the entries whose `base` is not the hash of the header entry (R-PA6).
expect {
	rows = rows_of(header_text)
	all = patches_of("[patch]\n${default_entry("parser", h_parser)}${default_entry("json", h_json0)}${default_entry("pf", h_cli)}${default_entry("util", h_json1)}${default_entry("src", h_json1)}${default_entry("ghost", h_json1)}")
	moved = patches_of("[patch]\n${entry_text("json", "/x/shared/main.roc", h_json1)}${entry_text("parser", "../copies/parser/./main.roc", h_parser)}")
	only_json = Patched.entries({ rows, patches: all, toml: "/p/talon.toml" }).keep_if(|e| e.alias == "json")
	rows_checked = [
		row(
			"the managed entries, in the order of the table: parser, json. pf, util, src and ghost are no patch",
			Patched.entries({ rows, patches: all, toml: "/p/talon.toml" }).map(view_entry),
			[
				("parser", h_parser, h_parser, "./.talon/patches/parser/main.roc", "/p/.talon/patches/parser/main.roc", "/p/.talon/patches/parser"),
				("json", h_json1, h_json0, "./.talon/patches/json/main.roc", "/p/.talon/patches/json/main.roc", "/p/.talon/patches/json"),
			],
		),
		row(
			"an absolute path stays, a path with .. and . is resolved from the dir of the talon.toml",
			Patched.entries({ rows, patches: moved, toml: "/p/sub/talon.toml" }).map(view_entry),
			[
				("json", h_json1, h_json1, "/x/shared/main.roc", "/x/shared/main.roc", "/x/shared"),
				("parser", h_parser, h_parser, "../copies/parser/./main.roc", "/p/copies/parser/main.roc", "/p/copies/parser"),
			],
		),
		row("no [patch] entry: no patch", Patched.entries({ rows, patches: [], toml: "/p/talon.toml" }).map(view_entry), []),
		row("the url of the entry is the value of the header", only_json.map(|e| e.url), [json1]),
		row(
			"replaces: the url of the header entry and the main file of the copy, in the order of the entries",
			Patched.replaces(Patched.entries({ rows, patches: all, toml: "/p/talon.toml" })),
			[{ old: parser, new: "/p/.talon/patches/parser/main.roc" }, { old: json1, new: "/p/.talon/patches/json/main.roc" }],
		),
		row("replaces of no entry", Patched.replaces([]), []),
		row("stale: only json has a base that is not its hash", Patched.stale(Patched.entries({ rows, patches: all, toml: "/p/talon.toml" })).map(|e| e.alias), ["json"]),
		row("stale: none when each base is the hash", Patched.stale(Patched.entries({ rows, patches: patches_of("[patch]\n${default_entry("json", h_json1)}"), toml: "/p/talon.toml" })).map(|e| e.alias), []),
	]
	bad = rows_checked.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA6 R-EC14 (slice 043): the failure for a stale patch. Kind `Frozen` (exit 14, `frozen`). The text names each stale entry, with its base and the hash of the header entry, and `tln install`. The proxy and `tln install --frozen` have each their own text
# (a proposal, TW24): `--frozen` says that it does not rebase.
expect {
	rows = rows_of(header_text)
	entries = Patched.entries({ rows, patches: patches_of("[patch]\n${default_entry("json", h_json0)}${default_entry("parser", h_parser2)}"), toml: "/p/talon.toml" })
	one = entries.keep_if(|e| e.alias == "json")
	rows_checked = [
		row(
			"the proxy, one entry",
			Patched.stale_fail({ entries: one, by: Proxy }).line(),
			"tln: error[frozen]: stale patch: json (base ${h_json0}, the header has ${h_json1}). Run: tln install",
		),
		row(
			"the proxy, 2 entries, in the order of the list",
			Patched.stale_fail({ entries, by: Proxy }).line(),
			"tln: error[frozen]: stale patch: json (base ${h_json0}, the header has ${h_json1}), parser (base ${h_parser2}, the header has ${h_parser}). Run: tln install",
		),
		row(
			"tln install --frozen",
			Patched.stale_fail({ entries: one, by: Frozen }).line(),
			"tln: error[frozen]: stale patch: json (base ${h_json0}, the header has ${h_json1}). tln install --frozen does not rebase a patch. Run: tln install",
		),
		row("the exit code of the failure is 14 (R-EC14)", Patched.stale_fail({ entries: one, by: Proxy }).kind.code(), 14.I32),
	]
	bad = rows_checked.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PX5 R-PX3 R-PX7 R-PA10 (slice 043): the arguments that the proxy gives to the compiler. `--replace-dep <old> <new>` for each pair, in order, at the end of the arguments that come before the first `--` (the arguments after it are for the app).
# No pair, no target file (`version`, `help`, `install`, `run <installed name>`) and a first word that is no command of `roc check` (the commands that have the flag: `check`, `build`, `run`, `test`, `docs`, `deps`) give the arguments as they are.
# The form `roc [options] [file]` has the flag. The rows for `fmt`, `bundle`, `repl` and the other commands are not written (question Q4).
expect {
	one = [{ old: "OLD", new: "/p/copy/main.roc" }]
	two = one.append({ old: "OLD2", new: "/p/copy2/main.roc" })
	flags = |pairs| pairs.join_map(|r| ["--replace-dep", r.old, r.new])
	args = |words, target, replace| Patched.proxy_args({ args: words, target, replace })
	rows = [
		row("check: after the file", args(["check", "app.roc"], File("app.roc"), one), ["check", "app.roc"].concat(flags(one))),
		row("build with an option: at the end", args(["build", "app.roc", "--opt=speed"], File("app.roc"), one), ["build", "app.roc", "--opt=speed"].concat(flags(one))),
		row("the bare form with -- : before it", args(["app.roc", "--", "a", "b"], File("app.roc"), one), ["app.roc"].concat(flags(one)).concat(["--", "a", "b"])),
		row("run with --: before it", args(["run", "app.roc", "--", "x"], File("app.roc"), one), ["run", "app.roc"].concat(flags(one)).concat(["--", "x"])),
		row("2 pairs: in order", args(["check", "app.roc"], File("app.roc"), two), ["check", "app.roc"].concat(flags(two))),
		row("test", args(["test", "app.roc"], File("app.roc"), one), ["test", "app.roc"].concat(flags(one))),
		row("docs, no file: main.roc", args(["docs"], Main, one), ["docs"].concat(flags(one))),
		row("deps", args(["deps", "app.roc"], File("app.roc"), one), ["deps", "app.roc"].concat(flags(one))),
		row("no argument: roc runs main.roc", args([], Main, one), flags(one)),
		row("an option first, then the file", args(["--opt=speed", "app.roc"], File("app.roc"), one), ["--opt=speed", "app.roc"].concat(flags(one))),
		row("no pair: the arguments as they are", args(["check", "app.roc"], File("app.roc"), []), ["check", "app.roc"]),
		row("no pair, with --", args(["app.roc", "--", "a"], File("app.roc"), []), ["app.roc", "--", "a"]),
		row("version: no target file", args(["version"], NoFile, one), ["version"]),
		row("help", args(["help"], NoFile, one), ["help"]),
		row("install of a bundle: no target file", args(["install", "name", "https://x.org/b.tar.zst"], NoFile, one), ["install", "name", "https://x.org/b.tar.zst"]),
		row("run of an installed name: no target file", args(["run", "tool"], NoFile, one), ["run", "tool"]),
		row("--help", args(["--help"], NoFile, one), ["--help"]),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA5 R-PA6 R-PA4 (slice 043): which patches a command rebases (`Patched.need`). An entry needs a rebase when the hash of its URL after the command is not its `base`, and the entry moves (its URL changes), or the command is `tln install` with no names
# (`install`: R-PA6, a stale patch is applied to the header release). The url and hash are the new ones. A stale patch in another command is not rebased (question Q6). A URL that is no release needs nothing. The order is the order of the entries.
expect {
	rows = rows_of(header_text)
	entries = |json_base, parser_base| Patched.entries({ rows, patches: patches_of("[patch]\n${default_entry("json", json_base)}${default_entry("parser", parser_base)}"), toml: "/p/talon.toml" })
	view = |needs| needs.map(|n| (n.entry.alias, n.url, n.hash))
	need = |es, chosen, install| view(Patched.need({ entries: es, chosen, install }))
	fresh = entries(h_json1, h_parser)
	stale = entries(h_json0, h_parser)
	rows_checked = [
		row("json moves to another release: rebase", need(fresh, [{ alias: "json", url: json2 }], Bool.False), [("json", json2, h_json2)]),
		row("nothing moves and each base is the hash: none", need(fresh, [], Bool.False), []),
		row("nothing moves, install, each base is the hash: none", need(fresh, [{ alias: "json", url: json1 }], Bool.True), []),
		row("a stale patch, no move: not rebased by update and upgrade (Q6)", need(stale, [], Bool.False), []),
		row("a stale patch, tln install with no names: rebased on the header release (R-PA6)", need(stale, [], Bool.True), [("json", json1, h_json1)]),
		row("the user rebased by hand: the new hash is the base already", need(entries(h_json2, h_parser), [{ alias: "json", url: json2 }], Bool.False), []),
		row("2 entries, one moves: one rebase", need(fresh, [{ alias: "parser", url: parser2 }, { alias: "json", url: json1 }], Bool.False), [("parser", parser2, h_parser2)]),
		row("2 entries, both move: in the order of the entries", need(fresh, [{ alias: "parser", url: parser2 }, { alias: "json", url: json2 }], Bool.False), [("json", json2, h_json2), ("parser", parser2, h_parser2)]),
		row("a chosen url that is no release: no rebase", need(fresh, [{ alias: "json", url: foreign }], Bool.False), []),
		row("an alias that is not in the list of chosen keeps its url", need(stale, [{ alias: "other", url: json2 }], Bool.True), [("json", json1, h_json1)]),
	]
	bad = rows_checked.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

utf8 = |path, text| { path, content: Utf8(text) }

bin = |path, hash| { path, content: Binary(hash) }

numbered = |from, to| {
	var $out = ""
	var $k = from
	while $k <= to {
		$out = "${$out}l${$k.to_str()}\n"
		$k = $k + 1
	}
	$out
}

# R-PA5 R-PA7 (slice 043): the diff of the copy against the base package, applied to the files of the new release (`Patched.rebase`: `Diff.make` of base and copy, `Diff.apply` on the target; `Diff` has its own rows). `Ok` has what `apply` does with each file, in the
# order of the paths. `Err` has all the paths that do not apply, in the order of the changes, and nothing is done for a file with a failed hunk. The base is the side that the old lines come from: a diff that was made the wrong way round would fail on the target.
expect {
	base_json = numbered(1, 30)
	copy_json = "l1\nl2\nl3 patched\nl4\n${numbered(5, 15)}l15 after\n${numbered(16, 30)}"
	moved_json = "top1\ntop2\ntop3\n${base_json}"
	moved_want = "top1\ntop2\ntop3\nl1\nl2\nl3 patched\nl4\n${numbered(5, 15)}l15 after\n${numbered(16, 30)}"
	base = [utf8("Json.roc", base_json), utf8("Old.roc", "# old\n"), bin("data.bin", "aa"), utf8("keep.roc", "same\n")]
	copy = [utf8("Json.roc", copy_json), utf8("New.roc", "# new\n"), bin("data.bin", "bb"), utf8("keep.roc", "same\n")]
	target = [utf8("Json.roc", moved_json), utf8("Old.roc", "# old\n"), bin("data.bin", "aa"), utf8("keep.roc", "same\n"), utf8("Extra.roc", "# extra\n")]
	changed_line = [utf8("Json.roc", "top1\nl1\nl2\nl3 upstream\n${numbered(4, 30)}"), utf8("Old.roc", "# old\n"), bin("data.bin", "aa"), utf8("keep.roc", "same\n")]
	rows = [
		row(
			"every kind of file applies: the hunks move by 3 lines, the deleted file is removed, the added file is written, the binary file comes from the copy",
			Patched.rebase({ base, copy, target }),
			Ok([
				{ path: "Json.roc", what: Write(moved_want) },
				{ path: "New.roc", what: Write("# new\n") },
				{ path: "Old.roc", what: Remove },
				{ path: "data.bin", what: FromCopy },
			]),
		),
		row(
			"a changed line in a hunk, a deleted file with other content and a binary file with other bytes: all 3 are listed, in the order of the changes, and no file is done",
			Patched.rebase({ base, copy, target: changed_line.map(|f| if f.path == "Old.roc" utf8("Old.roc", "# changed\n") else if f.path == "data.bin" bin("data.bin", "cc") else f) }),
			Err(["Json.roc", "Old.roc", "data.bin"]),
		),
		row("only one file fails: only that one is listed", Patched.rebase({ base, copy, target: changed_line }), Err(["Json.roc"])),
		row("the copy is the base: no change, nothing to do", Patched.rebase({ base, copy: base, target }), Ok([])),
		row("the target is the base: the diff applies to it as it is", Patched.rebase({ base: [utf8("a.roc", "x\ny\n")], copy: [utf8("a.roc", "x\nz\n")], target: [utf8("a.roc", "x\ny\n")] }), Ok([{ path: "a.roc", what: Write("x\nz\n") }])),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA5 R-AL6 R-EC10 (slice 043): the failure for a release on which the diff does not apply. It is not a candidate for the entry, so the failure is of kind `NoTuple` (exit 10), and it has `again` with the hash of the release: the oracle loop drops that
# release and tries another tuple. The text lists the files that do not apply and names the 2 fixes: edit the copy, or remove the `[patch]` entry (R-PA5). A proposal (TW24).
expect {
	fail = Patched.not_applied({ alias: "json", name: "someone/roc-json", version: "2.3.0", hash: h_json2, dir: "/p/.talon/patches/json", files: ["Json.roc", "data.bin"] })
	rows = [
		row(
			"the text lists the files and the 2 fixes",
			fail.line(),
			"tln: error[no_tuple]: no tuple works: the patch of json does not apply to someone/roc-json 2.3.0: Json.roc, data.bin. Edit the copy /p/.talon/patches/json/, or remove the [patch] entry json.",
		),
		row("the kind is no_tuple, exit 10 (R-PA5)", fail.kind.code(), 10.I32),
		row("the release is dropped by its hash", fail.again, Ok({ blamed: [h_json2], probes: 0.U64 })),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA10 R-PX5 R-BL1 R-BL2 R-CM11 (slice 043): the probes of the ladder have the `--replace-dep` pairs of the patches (`LadderPlan.with_patches`). `base` goes to the baseline check (the current header: the copies), `candidate` goes to the candidate check
# and to the build (the new header: the temp copy of a patch that moves). The pairs are at the end of the arguments, after the pairs of `plan_replace` (R-CM11, `tln verify`) and after `--output=` of the build. Empty lists give the same plan. The unit probes
# are not part of the plan (question Q3).
expect {
	copy = "/c/talon/tmp/0123456789abcdef"
	facts = { compiler: "nightly-2026-10-14-38a3029", program: "/h/roc", env: [("TALON_IN_PROXY", "1")], kind: App, dir: "/p/app", file: "main.roc", copy, timeout: 30 }
	plain = LadderPlan.plan(facts)
	base = [{ old: "OLD", new: "/p/app/.talon/patches/json/main.roc" }]
	candidate = [{ old: "NEW", new: "/c/talon/tmp/patch-0123456789abcdef/json/main.roc" }]
	flags = |pairs| pairs.join_map(|r| ["--replace-dep", r.old, r.new])
	patched = LadderPlan.with_patches({ plan: plain, base, candidate })
	for_package = LadderPlan.with_patches({ plan: LadderPlan.plan({ ..facts, kind: Package }), base, candidate })
	tmp = "/c/talon/tmp/9999"
	tuple = [{ old: "A", new: "B" }]
	verify_plan = LadderPlan.plan_replace({ compiler: facts.compiler, program: facts.program, env: facts.env, kind: App, dir: "/p/app", file: "main.roc", tmp, replace: tuple, timeout: 30 })
	verify_patched = LadderPlan.with_patches({ plan: verify_plan, base, candidate: base })
	rows = [
		row("baseline: the pairs of the base", patched.first.first().map_ok(|s| s.args), Ok(["check", "main.roc"].concat(flags(base)))),
		row("candidate check: the pairs of the candidate", patched.first.last().map_ok(|s| s.args), Ok(["check", "main.roc"].concat(flags(candidate)))),
		row("build: the pairs of the candidate, after --output", patched.build.map_ok(|s| s.args), Ok(["build", "main.roc", "--output=${copy}/tln-probe.out"].concat(flags(candidate)))),
		row("the other fields of a probe do not change", patched.first.map(|s| { ..s, args: [] }), plain.first.map(|s| { ..s, args: [] })),
		row("a package has no build and keeps its 2 checks", (for_package.build, for_package.first.map(|s| s.args)), (Err(None), [["check", "main.roc"].concat(flags(base)), ["check", "main.roc"].concat(flags(candidate))])),
		row("empty lists: the same plan", LadderPlan.with_patches({ plan: plain, base: [], candidate: [] }), plain),
		row("empty lists on a plan for verify: the same plan", LadderPlan.with_patches({ plan: verify_plan, base: [], candidate: [] }), verify_plan),
		row(
			"verify: the pairs of the tuple come first, then the pairs of the patches; the baseline has only the patches",
			(verify_patched.first.map(|s| s.args), verify_patched.build.map_ok(|s| s.args)),
			(
				[["check", "main.roc"].concat(flags(base)), ["check", "main.roc", "--replace-dep", "A", "B"].concat(flags(base))],
				Ok(["build", "main.roc", "--output=${tmp}/tln-probe.out", "--replace-dep", "A", "B"].concat(flags(base))),
			),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA13 (slice 070): the release of the group of an entry that has the hash `base`. The group is the URL form and the series of the header URL of the entry. A release of another series, of
# another repository, a URL that is no release, an empty list and a hash that no URL has give `NoRelease`. The first URL in the order of the list wins when 2 releases of the group have the hash.
expect {
	group = match Ident.of_url(json1) {
		Ok(ident) => ident.group
		Err(Foreign) => crash "json1 is a release URL"
	}
	h_other = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"
	json3 = gh("someone", "roc-json", "3.0.0", h_other)
	same_hash_next = gh("someone", "roc-json", "2.1.1", h_json1)
	elsewhere = gh("someone", "roc-json2", "2.0.0", h_other)
	list = [json0, json1, json2]
	rows_checked = [
		row("the oldest release of the group", Patched.base_release({ urls: list, group, base: h_json0 }), Ok(json0)),
		row("the header release itself", Patched.base_release({ urls: list, group, base: h_json1 }), Ok(json1)),
		row("a hash that no release has", Patched.base_release({ urls: list, group, base: h_other }), Err(NoRelease)),
		row("a release of another series has the hash", Patched.base_release({ urls: list.append(json3), group, base: h_other }), Err(NoRelease)),
		row("a release of another repository has the hash", Patched.base_release({ urls: list.append(elsewhere), group, base: h_other }), Err(NoRelease)),
		row("no URL", Patched.base_release({ urls: [], group, base: h_json0 }), Err(NoRelease)),
		row("a URL that is no release is skipped", Patched.base_release({ urls: ["./util/main.roc", foreign, json0], group, base: h_json0 }), Ok(json0)),
		row("2 releases have the hash: the first in the list", Patched.base_release({ urls: [same_hash_next, json1], group, base: h_json1 }), Ok(same_hash_next)),
	]
	bad = rows_checked.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA13 R-PA5 R-EC14 (slice 070): the failure for a base that no release has. Kind `Frozen` (exit 14, `frozen`). The text names the base, the alias, the repository and the 2 fixes of R-PA5 (the copy dir has no `/` in
# the entry and one at the end in the text). A proposal (TW24).
expect {
	fail = Patched.base_missing({ alias: "json", name: "someone/roc-json", base: h_json0, dir: "/p/.talon/patches/json" })
	rows_checked = [
		row(
			"the line",
			fail.line(),
			"tln: error[frozen]: the patch of json has the base ${h_json0}, and no release of someone/roc-json has that hash, so Talon cannot take the diff of the copy. Edit the copy /p/.talon/patches/json/, or remove the [patch] entry json.",
		),
		row("the exit code is 14 (R-EC14)", fail.kind.code(), 14.I32),
	]
	bad = rows_checked.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PA12 R-PA9 R-RUN8 R-EC19 (slice 076, Q2): the copy dir of a `[patch]` entry is deleted and written by a rebase (`tln install`, `tln update`), so it must be inside the repository, as the `in` dir of a script (R-RUN8, exit 19), and
# it is checked before any read, delete or write. The repository is the stop dir: the workspace root for a workspace, else the dir of the `talon.toml` (`Patched.stop`, decision D6 of the slice file). Strictly inside: the copy dir
# that is the stop dir itself (`path = "./main.roc"`) is refused too, because a rebase would delete the repository. A dir with the same start (`/p2` for the stop `/p`) is outside. An absolute path counts like any other. The first bad entry is the failure.
expect {
	rows = rows_of(header_text)
	check = |path, stop| {
		entries = Patched.entries({ rows, patches: patches_of("[patch]\n${entry_text("json", path, h_json1)}"), toml: "/p/talon.toml" })
		Patched.check_inside({ entries, stop }).map_err(|e| e.line())
	}
	outside = |path| Err("tln: error[input]: patch.json.path: '${path}' is outside the repository (/p)")
	two = Patched.check_inside({
		entries: Patched.entries({ rows, patches: patches_of("[patch]\n${default_entry("parser", h_parser)}${entry_text("json", "../x/main.roc", h_json1)}"), toml: "/p/talon.toml" }),
		stop: "/p",
	}).map_err(|e| e.line())
	checks = [
		row("the default copy dir", check("./.talon/patches/json/main.roc", "/p"), Ok({})),
		row("a copy dir below the stop dir, with ..", check("./a/../b/main.roc", "/p"), Ok({})),
		row("an absolute path inside the repository", check("/p/sub/main.roc", "/p"), Ok({})),
		row("a path that climbs out", check("../outside/main.roc", "/p"), outside("../outside/main.roc")),
		row("a path that climbs out below the stop dir", check("./.talon/../../x/main.roc", "/p"), outside("./.talon/../../x/main.roc")),
		row("an absolute path outside", check("/x/shared/main.roc", "/p"), outside("/x/shared/main.roc")),
		row("a dir with the same start as the stop dir", check("../p2/main.roc", "/p"), outside("../p2/main.roc")),
		row("the stop dir itself", check("./main.roc", "/p"), outside("./main.roc")),
		row("a stop dir that is the file system root", check("/x/main.roc", "/"), Ok({})),
		row("no entry", Patched.check_inside({ entries: [], stop: "/p" }).map_err(|e| e.line()), Ok({})),
		row("the first bad entry is the failure", two, Err("tln: error[input]: patch.json.path: '../x/main.roc' is outside the repository (/p)")),
		row("the stop dir of a workspace is its root", Patched.stop({ workspace: Ok({ root: "/ws", members: ["/ws/a/main.roc"] }), toml: "/ws/a/talon.toml" }), "/ws"),
		row("the stop dir of a standalone project is the dir of its talon.toml", Patched.stop({ workspace: Err(Standalone), toml: "/p/sub/talon.toml" }), "/p/sub"),
	]
	bad = checks.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
