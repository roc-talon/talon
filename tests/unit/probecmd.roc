app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.Db
import lib.Ident
import lib.JsonDoc
import lib.Roots
import lib.ProbeCmd

main! = |_args| Ok({})

# The 3 hashes of the fixture packages of `probe/pc1-targets` (real base58 names).
json_hash = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

pf_hash = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"

parser_hash = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"

json_url = "https://github.com/acme/json/releases/download/2.1.0/${json_hash}.tar.zst"

pf_url = "https://github.com/acme/pf/releases/download/0.1.0/${pf_hash}.tar.zst"

parser_url = "https://github.com/acme/roc-parser/releases/download/1.0.0/${parser_hash}.tar.zst"

json3_url = "https://github.com/acme/json/releases/download/3.0.0/${json_hash}.tar.zst"

# A header entry as `Locked.read` makes it.
release = |alias, url, is_platform| match Ident.of_url(url) {
	Ok(ident) => { alias, value: url, is_platform, what: Release(ident) }
	Err(_) => crash "bad test URL"
}

path_entry = { alias: "util", value: "../util/main.roc", is_platform: Bool.False, what: Path }

foreign_entry = { alias: "ext", value: "https://x.org/e.zst", is_platform: Bool.False, what: Foreign }

header = [
	release("pf", pf_url, Bool.True),
	release("json", json_url, Bool.False),
	release("parse", parser_url, Bool.False),
	path_entry,
	foreign_entry,
]

# R-CM8 R-PB1 R-PB6 R-FL7 R-FL11 R-NI4 R-NI5 (slice 037, questions R1 and R2 of the slice file): the operand and the flags of a `probe` line. `Args.parse` has checked which flags are allowed (R-FL12), `ProbeCmd.read` reads the rest.
# A view of a plan: the target and then a word for each flag that is set. A failure is its last line on stderr (kind `usage`, exit 2).
expect {
	view = |words| match Args.parse(words) {
		Err(e) => "args: ${Fail.line(e.fail)}"
		Ok(args) => match ProbeCmd.read(args) {
			Err(fail) => Fail.line(fail)
			Ok(plan) => {
				target = match plan.target {
					Project => "project"
					Alias(text) => "alias ${text}"
					Bundle(path) => "bundle ${path}"
				}
				slots = match plan.opts.slots {
					Ok(n) => [" slots ${n.to_str()}"]
					Err(Unset) => []
				}
				probe = if plan.opts.probe_downloads.is_ok() [" probe-downloads"] else []
				allow = if plan.opts.allow_downloads.is_ok() [" allow-downloads"] else []
				"${target}${if plan.range " range" else ""}${Str.join_with(slots.concat(probe).concat(allow), "")}"
			}
		}
	}
	share = "tln: error[usage]: tln probe --share needs a registry, and this version of tln has only --registry direct"
	rows = [
		("no operand: the project file", view(["probe"]), "project"),
		("a header alias", view(["probe", "json"]), "alias json"),
		("a full name with a selector is an alias operand", view(["probe", "acme/json@2"]), "alias acme/json@2"),
		("a path that ends with .tar.zst is a bundle file", view(["probe", "out/${json_hash}.tar.zst"]), "bundle out/${json_hash}.tar.zst"),
		("--range with an alias", view(["probe", "--range", "json"]), "alias json range"),
		("--range with a bundle file", view(["probe", "--range", "${json_hash}.tar.zst"]), "bundle ${json_hash}.tar.zst range"),
		("2 operands", view(["probe", "a", "b"]), "tln: error[usage]: tln probe takes one name or one bundle file"),
		("--range with no operand: the project file has no hash (question R1)", view(["probe", "--range"]), "tln: error[usage]: tln probe --range needs a header alias or a bundle file: the project file has no hash"),
		("--share with no operand (R-PB6: no hash)", view(["probe", "--share"]), share),
		("--share with an alias (R-PB6: no registry)", view(["probe", "--share", "json"]), share),
		("--share with a bundle file (R-PB6)", view(["probe", "--share", "x.tar.zst"]), share),
		("--share is checked before the operands", view(["probe", "a", "b", "--share"]), share),
		("--share is checked before --range", view(["probe", "--share", "--range"]), share),
		("--slots is read by Opts", view(["probe", "--slots", "4", "json"]), "alias json slots 4"),
		("--slots 0 is the failure of Opts.read (R-FL11)", view(["probe", "--slots", "0", "json"]), "tln: error[usage]: --slots must be a whole number of 1 or more, not '0'"),
		("--probe-downloads and --allow-downloads are read (R-NI4, R-NI5)", view(["probe", "--probe-downloads", "--allow-downloads", "json"]), "alias json probe-downloads allow-downloads"),
		("--registry other: the failure of Opts.read", view(["probe", "--registry", "other", "json"]), "tln: error[usage]: --registry 'other': no registry exists in this version of tln. Use --registry direct."),
		("--registry direct is fine", view(["probe", "--registry", "direct"]), "project"),
		("a flag that probe does not take is a failure of the parser (R-FL7: --frozen)", view(["probe", "--frozen"]), "args: tln: error[usage]: flag '--frozen' is not for 'probe'"),
		("--json and --file are global and fine", view(["probe", "--json", "--file", "p/main.roc", "json"]), "alias json"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB1 R-SC1 R-SC6 R-SC7 R-SC8 R-SC14 R-SC16 R-WS8 R-LD3 R-H4 (slice 037, question T1 of the slice file): `ProbeCmd.entry`, the header entry that a name selects. The result is the node of the entry (hash, name, version, platform), or the line of the failure and its block.
# The names are read as `why` and `update` read them (alias, full name, short name, `@sel`: the version of the entry is in `sel`). Only the header entries are names: a package of the closure that no header names is not found (R-SC1).
expect {
	show = |found| match found {
		Ok(node) => "${node.hash} ${node.name} ${node.version}${if node.is_platform " (platform)" else ""}"
		Err(e) => "${Fail.line(e.fail)}|${e.block}"
	}
	find = |text, rows| show(ProbeCmd.entry({ text, rows }))
	json_node = "${json_hash} acme/json 2.1.0"
	not_in = |name| "tln: error[usage]: '${name}' is not in the project|"
	two_series = header.concat([release("json", json3_url, Bool.False)])
	tie = ProbeCmd.entry({ text: "json", rows: two_series })
	rows = [
		("an alias", find("json", header), json_node),
		("the alias of the platform: the node is marked (R-LD3)", find("pf", header), "${pf_hash} acme/pf 0.1.0 (platform)"),
		("a full name", find("acme/json", header), json_node),
		("a short name: the repo name without roc-", find("parser", header), "${parser_hash} acme/roc-parser 1.0.0"),
		("a short name: the repo name", find("roc-parser", header), "${parser_hash} acme/roc-parser 1.0.0"),
		("an alias that is not the repo name (R-SC6)", find("parse", header), "${parser_hash} acme/roc-parser 1.0.0"),
		("a selector that the version satisfies (R-SC16: a filter)", find("json@2", header), json_node),
		("an exact selector", find("json@2.1.0", header), json_node),
		("a selector that no version satisfies", find("json@3", header), not_in("json@3")),
		("no entry has the name", find("yaml", header), not_in("yaml")),
		("a package that the closure has and no header names is not a name", find("acme/lex", header), not_in("acme/lex")),
		("a path entry has no hash (question T1)", find("util", header), "tln: error[usage]: 'util' is a path entry or a foreign URL: it has no hash to probe|"),
		("a foreign URL has no hash", find("ext", header), "tln: error[usage]: 'ext' is a path entry or a foreign URL: it has no hash to probe|"),
		("the same entry in 2 members counts once", find("json", header.concat(header)), json_node),
		("a selector with a path entry: it has no version, so no match", find("util@1", header), not_in("util@1")),
		(
			"2 entries with one alias and 2 series (R-WS8): a tie, with the list on stderr",
			match tie {
				Err(e) => "${Fail.line(e.fail)}|${if e.block.starts_with("\"json\" matches 2 packages:") "list" else "no list"}"
				Ok(_) => "no tie"
			},
			"tln: error[usage]: \"json\" matches 2 packages. Use a name from the list.|list",
		),
		("the tie is ended by a selector that names one series", find("json@3", two_series), "${json_hash} acme/json 3.0.0"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB1 R-FE2 (slice 037): the hash of a bundle file is its file name without `.tar.zst`. The directories of the path are dropped, with `/` and with `\`. `roc unbundle` checks the characters and the content (exit 16), so this function does not.
expect {
	view = |path| match ProbeCmd.bundle_hash(path) {
		Ok(hash) => hash
		Err(fail) => Fail.line(fail)
	}
	bad_name = |path| "tln: error[usage]: '${path}' is not a package archive: the file name must be <hash>.tar.zst"
	rows = [
		("a path", view("/home/u/out/${json_hash}.tar.zst"), json_hash),
		("a name", view("${json_hash}.tar.zst"), json_hash),
		("a relative path", view("./${json_hash}.tar.zst"), json_hash),
		("a path of Windows", view("C:\\out\\${json_hash}.tar.zst"), json_hash),
		("an empty name", view("out/.tar.zst"), bad_name("out/.tar.zst")),
		("only the end", view(".tar.zst"), bad_name(".tar.zst")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB4 R-EC12 R-UP7 (slice 037, question S4 of the slice file): `ProbeCmd.stop`, the failure with exit 12 (kind budget) or none. The first row that fits wins: a cut of the budget, then an end that is not a real fact, then no pass with releases that have no fact.
expect {
	cut = Fail.new(Budget, "the probe budget is spent: probe.max is 4")
	real_end = |id| { id, real: Bool.True }
	unknown_end = |id| { id, real: Bool.False }
	both_real = Range({ from: real_end("n2"), to: real_end("n5") })
	view = |found, cut_in, unseen| match ProbeCmd.stop({ found, cut: cut_in, unseen }) {
		Ok(fail) => Fail.line(fail)
		Err(None) => "none"
	}
	two = "tln: error[budget]: the range has 2 ends that are not a real fact (unknown): no installed compiler can show them. Run tln roc install for more compilers."
	one = "tln: error[budget]: the range has 1 end that is not a real fact (unknown): no installed compiler can show it. Run tln roc install for more compilers."
	rows = [
		("a cut of the budget is the failure as it is", view(both_real, Ok(cut), 0), "tln: error[budget]: the probe budget is spent: probe.max is 4"),
		("the cut comes before an unknown end", view(Range({ from: unknown_end("n2"), to: unknown_end("n5") }), Ok(cut), 0), "tln: error[budget]: the probe budget is spent: probe.max is 4"),
		("the cut comes before no pass", view(NoPass, Ok(cut), 7), "tln: error[budget]: the probe budget is spent: probe.max is 4"),
		("2 unknown ends", view(Range({ from: unknown_end("n2"), to: unknown_end("n5") }), Err(None), 0), two),
		("an unknown lower end", view(Range({ from: unknown_end("n2"), to: real_end("n5") }), Err(None), 0), one),
		("an unknown upper end", view(Range({ from: real_end("n2"), to: unknown_end("n5") }), Err(None), 0), one),
		("2 real ends: no failure, exit 0", view(both_real, Err(None), 0), "none"),
		("releases with no fact do not matter when the range has real ends", view(both_real, Err(None), 4), "none"),
		("no pass and 3 releases with no fact", view(NoPass, Err(None), 3), "tln: error[budget]: no installed compiler gave a real pass, and no real fact exists for 3 releases of the list. Run tln roc install for more compilers."),
		("no pass and 1 release with no fact", view(NoPass, Err(None), 1), "tln: error[budget]: no installed compiler gave a real pass, and no real fact exists for 1 release of the list. Run tln roc install for more compilers."),
		("no pass and a fact for each release: the answer is complete, exit 0", view(NoPass, Err(None), 0), "none"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB1 R-PB2 R-PB3 R-PB4 R-LD2 R-LD3 R-LD7 R-P2 R-RC3 R-RC4 R-OUT2 (slice 037, TW24: the texts are a proposal): `ProbeCmd.text`, the human output of a run.
expect {
	json = { hash: json_hash, name: "acme/json", version: "2.1.0", is_platform: Bool.False }
	pf = { hash: pf_hash, name: "acme/pf", version: "0.1.0", is_platform: Bool.True }
	bundle = { hash: json_hash, name: json_hash, version: "", is_platform: Bool.False }
	fact = |outcome, modules| { hash: json_hash, nightly: "n3", target: "any", outcome, modules, closure: "" }
	unit = |node, outcome, modules| ProbeCmd.text(Unit({ node, compiler: "n3", fact: fact(outcome, modules), probes: 1 }))
	err = |file, title| { file, title, message: "" }
	passed = { class: Pass, errors: [] }
	failed = |errors| { class: Fail(errors.len()), errors }
	project = |kind, check, build| ProbeCmd.text(Project({ file: "/p/main.roc", kind, compiler: "n3", check, build, probes: 1 }))
	range = |node, found| ProbeCmd.text(Range({ node, found, probes: 5, downloads: 0 }))
	both = Range({ from: { id: "n2", real: Bool.True }, to: { id: "n5", real: Bool.False } })
	rows = [
		("unit: pass", unit(json, Pass, []), "unit check of acme/json 2.1.0 on n3: pass\n"),
		("unit: fail with modules", unit(json, Fail, ["Wire.roc", "Yaml.roc"]), "unit check of acme/json 2.1.0 on n3: fail (Wire.roc, Yaml.roc)\n"),
		("unit: fail with no module (R-UM1)", unit(json, Fail, []), "unit check of acme/json 2.1.0 on n3: fail (no module is named)\n"),
		("unit: hang (R-RC3)", unit(json, Hang, []), "unit check of acme/json 2.1.0 on n3: hang\n"),
		("unit: crash (R-RC4)", unit(json, Crash, []), "unit check of acme/json 2.1.0 on n3: crash\n"),
		("unit: a platform", unit(pf, Pass, []), "unit check of the platform acme/pf 0.1.0 on n3: pass\n"),
		("unit: a bundle file has the hash for a label", unit(bundle, Pass, []), "unit check of ${json_hash} on n3: pass\n"),
		("project: an app that passes", project(App, passed, Ok(passed)), "/p/main.roc on n3\ncheck: passed\nbuild: passed\n"),
		("project: a package has no build", project(Package, passed, Err(NotRun)), "/p/main.roc on n3\ncheck: passed\nbuild: not run (a package has no app)\n"),
		("project: a platform has no build", project(Platform, passed, Err(NotRun)), "/p/main.roc on n3\ncheck: passed\nbuild: not run (a platform has no app)\n"),
		("project: 1 error, the place of an app file", project(App, failed([err(App("main.roc"), "type mismatch")]), Err(NotRun)), "/p/main.roc on n3\ncheck: failed, 1 error\n  main.roc: type mismatch\n"),
		("project: 2 errors, the place of a package file and no file", project(Package, failed([err(Package({ hash: "H", path: "Wire.roc" }), "type mismatch"), err(NoFile, "target")]), Err(NotRun)), "/p/main.roc on n3\ncheck: failed, 2 errors\n  package H Wire.roc: type mismatch\n  no file: target\n"),
		("project: a hang", project(App, { class: Hang, errors: [] }, Err(NotRun)), "/p/main.roc on n3\ncheck: hang\n"),
		("project: a crash with its text", project(App, { class: Crash("signal 11"), errors: [] }, Err(NotRun)), "/p/main.roc on n3\ncheck: crash (signal 11)\n"),
		("project: the build fails", project(App, passed, Ok(failed([err(NoFile, "link")]))), "/p/main.roc on n3\ncheck: passed\nbuild: failed, 1 error\n  no file: link\n"),
		("range: a real lower end and an unknown upper end", range(json, both), "acme/json 2.1.0 passes on n2 .. n5\n  lower end: n2 (real)\n  upper end: n5 (unknown)\n"),
		("range: a platform", range(pf, both), "the platform acme/pf 0.1.0 passes on n2 .. n5\n  lower end: n2 (real)\n  upper end: n5 (unknown)\n"),
		("range: no pass", range(json, NoPass), "acme/json 2.1.0: no release of the compiler list has a real pass\n"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB1 R-PB3 R-J3 R-J4 R-J5 R-OUT4 R-OUT5 (slice 037, TW24: the keys are a proposal): `ProbeCmd.data`, the `data` of `--json` (with exit 12 it is `error.details`). The keys keep this order.
expect {
	json = { hash: json_hash, name: "acme/json", version: "2.1.0", is_platform: Bool.False }
	fact = { hash: json_hash, nightly: "n3", target: "any", outcome: Fail, modules: ["Yaml.roc"], closure: "" }
	done = { class: Fail(1), errors: [{ file: App("main.roc"), title: "type mismatch", message: "" }] }
	render = |shown| JsonDoc.render(ProbeCmd.data(shown))
	rows = [
		("unit", render(Unit({ node: json, compiler: "n3", fact, probes: 1 })), "{\"kind\":\"unit\",\"hash\":\"${json_hash}\",\"label\":\"acme/json 2.1.0\",\"compiler\":\"n3\",\"outcome\":\"fail\",\"modules\":[\"Yaml.roc\"],\"probes\":1}"),
		("project: a failed check and no build", render(Project({ file: "/p/main.roc", kind: App, compiler: "n3", check: done, build: Err(NotRun), probes: 1 })), "{\"kind\":\"project\",\"file\":\"/p/main.roc\",\"compiler\":\"n3\",\"check\":{\"outcome\":\"fail\",\"errors\":[{\"place\":\"main.roc\",\"title\":\"type mismatch\"}]},\"build\":null,\"probes\":1}"),
		("project: a pass and a build", render(Project({ file: "/p/main.roc", kind: App, compiler: "n3", check: { class: Pass, errors: [] }, build: Ok({ class: Hang, errors: [] }), probes: 2 })), "{\"kind\":\"project\",\"file\":\"/p/main.roc\",\"compiler\":\"n3\",\"check\":{\"outcome\":\"pass\",\"errors\":[]},\"build\":{\"outcome\":\"hang\",\"errors\":[]},\"probes\":2}"),
		("range", render(Range({ node: json, found: Range({ from: { id: "n2", real: Bool.True }, to: { id: "n5", real: Bool.False } }), probes: 5, downloads: 0 })), "{\"kind\":\"range\",\"hash\":\"${json_hash}\",\"label\":\"acme/json 2.1.0\",\"range\":{\"from\":{\"id\":\"n2\",\"real\":true},\"to\":{\"id\":\"n5\",\"real\":false}},\"probes\":5,\"downloads\":0}"),
		# R-NI4 R-DL1 (slice 037c): the number of compilers that the search downloaded, as `data.downloads` of slice 025.
		("range: 2 downloads", render(Range({ node: json, found: Range({ from: { id: "n2", real: Bool.True }, to: { id: "n5", real: Bool.True } }), probes: 7, downloads: 2 })), "{\"kind\":\"range\",\"hash\":\"${json_hash}\",\"label\":\"acme/json 2.1.0\",\"range\":{\"from\":{\"id\":\"n2\",\"real\":true},\"to\":{\"id\":\"n5\",\"real\":true}},\"probes\":7,\"downloads\":2}"),
		("range: no pass", render(Range({ node: json, found: NoPass, probes: 0, downloads: 0 })), "{\"kind\":\"range\",\"hash\":\"${json_hash}\",\"label\":\"acme/json 2.1.0\",\"range\":null,\"probes\":0,\"downloads\":0}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-FE4 R-FE2 R-PB1 R-LB3 (slice 037): `ProbeCmd.unbundler`, the program that runs `roc unbundle` for a bundle file: the selected compiler when it is installed, else the newest installed compiler, else the `roc` on PATH (rank 7), else a required download.
expect {
	roots = match Roots.from_env([("HOME", "/h"), ("XDG_CACHE_HOME", "/c")]) {
		Ok(r) => r
		Err(_) => crash "roots"
	}
	path = Ok({ id: "nightly-2026-10-14-38a3029", path: "/bin/roc" })
	three = ["nightly-2026-10-03-3d3d3d3", "nightly-2026-10-10-0e0e0e0", "nightly-2026-10-05-5f5f5f5"]
	view = |selected, installed, on_path| match ProbeCmd.unbundler({ selected, installed, path: on_path, roots }) {
		Ok(program) => program
		Err(NoCompiler) => "none"
	}
	file = |id| "/c/roc/toolchains/${id}/roc"
	rows = [
		("the selected compiler is installed (rule 1): not the newest", view("nightly-2026-10-03-3d3d3d3", three, path), file("nightly-2026-10-03-3d3d3d3")),
		("the selected compiler is not installed: the newest installed (rule 2)", view("nightly-2026-10-02-2c2c2c2", three, path), file("nightly-2026-10-10-0e0e0e0")),
		("no compiler is selected (--range): the newest installed", view("", three, path), file("nightly-2026-10-10-0e0e0e0")),
		("the selected compiler is the roc on PATH and is not installed: an installed one wins", view("nightly-2026-10-14-38a3029", three, path), file("nightly-2026-10-10-0e0e0e0")),
		("the order is by the day of the tag, the other tag form too", view("", ["nightly-2026-10-10-0e0e0e0", "nightly-2026-October-13-91fa0c2", "nightly-2026-10-12-1a1a1a1"], path), file("nightly-2026-October-13-91fa0c2")),
		("nothing installed: the roc on PATH (rule 3)", view("nightly-2026-10-14-38a3029", [], path), "/bin/roc"),
		("nothing installed and no roc on PATH: a required download (rule 4)", view("nightly-2026-10-14-38a3029", [], Err(NoCompiler)), "none"),
		("the selected id is installed and is also the one on PATH: the managed copy", view("nightly-2026-10-14-38a3029", ["nightly-2026-10-14-38a3029"], path), file("nightly-2026-10-14-38a3029")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
