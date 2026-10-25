app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Diff
import lib.Fail
import lib.JsonDoc
import lib.Locked
import lib.PatchCmd
import lib.Removal

main! = |_args| Ok({})

# The options as a tuple: `names`, then `force`, `dry_run`, `no_check`. A failure is its text (the compiler of this nightly crashes on a record with a `Bool` in an `Err`).
view = |words| match Args.parse(words) {
	Err(stop) => Err(Fail.line(stop.fail))
	Ok(args) => match Removal.opts(args) {
		Ok(o) => Ok((o.names, [o.force, o.dry_run, o.no_check]))
		Err(f) => Err(Fail.line(f))
	}
}

# R-CM3 R-CM19 R-FL12 R-FL7 R-FL13 R-FL5 R-FL10 R-EC2 (slice 008): the options of `remove` and `rm`, which are one command. The flags of the command are `--force`, `--dry-run` and `--no-check`. The global flags and the
# resolve flags that `remove` does not use are read and change nothing. All failures are usage (exit 2). The order of the checks: the registry, the strategy, `--frozen`, no name. A `remove` with
# no name is question Q2 of the slice (default: usage).
expect {
	frozen = "tln: error[usage]: flag '--frozen' works only for tln install with no names"
	rows = [
		(["remove", "json"], Ok((["json"], [Bool.False, Bool.False, Bool.False]))),
		(["rm", "json", "util", "--force", "--dry-run", "--no-check"], Ok((["json", "util"], [Bool.True, Bool.True, Bool.True]))),
		(["remove", "acme/json", "--force"], Ok((["acme/json"], [Bool.True, Bool.False, Bool.False]))),
		(["remove", "json", "--json", "--yes", "--quiet", "--offline", "--registry", "direct", "--strategy", "lowest", "--no-probe", "--slots", "4", "--snapshot", "2026-10-10T00:00:00Z"], Ok((["json"], [Bool.False, Bool.False, Bool.False]))),
		(["remove", "json", "--frozen"], Err(frozen)),
		(["remove", "--frozen"], Err(frozen)),
		(["remove"], Err("tln: error[usage]: tln remove needs one name or more")),
		(["rm", "--dry-run"], Err("tln: error[usage]: tln remove needs one name or more")),
		(["remove", "json", "--strategy", "middle"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
		(["remove", "json", "--registry", "https://registry.example"], Err("tln: error[usage]: --registry 'https://registry.example': no registry exists in this version of tln. Use --registry direct.")),
		(["remove", "--registry", "https://r.example", "--strategy", "middle", "--frozen"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
		(["remove", "--strategy", "middle", "--frozen"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
	]
	bad = rows.keep_if(|(words, want)| view(words) != want).map(|(words, _)| (words, view(words)))
	dbg bad
	bad == []
}

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h_json1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_http = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

cli_url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst"

json1 = "https://github.com/someone/roc-json/releases/download/2.1.0/${h_json1}.tar.zst"

http1 = "https://github.com/roc-lang/http/releases/download/1.9.0/${h_http}.tar.zst"

odd = "https://example.com/pkg/latest.tar.gz"

app_text = "app [main!] {\n\tpf: platform \"${cli_url}\",\n\tjson: \"${json1}\",\n\tutil: \"../util/main.roc\",\n\todd: \"${odd}\",\n\thttp: \"${http1}\",\n\troc: \"nightly-2026-10-09-258ab27\",\n}\n\nmain! = |_| Ok({})\n"

# The platform has the alias `shell`, and a package has the alias `pf`: the platform is the row with `is_platform`, not the alias `pf` (R-AD31).
alias_text = "app [main!] {\n\tshell: platform \"${cli_url}\",\n\tpf: \"${json1}\",\n}\n\nmain! = |_| Ok({})\n"

pkg_text = "package [Parser] {\n\tjson: \"${json1}\",\n}\n"

toml_text = "[dependencies]\njson = \"^2.1\"   # the json range\nhttp = \"^1\"\n\n[overrides]\njson = \"someone/roc-json@^2.1.3\"\n\n[patch]\njson = { path = \"./.talon/patches/json/main.roc\", base = \"${h_json1}\" }\n"

# The plan of one entry as a value that the test compares: what it was, the keys, the dir of the patch. A failure is its text.
plan = |text, alias, toml, shared| match Locked.read({ path: "/p/main.roc", text }) {
	Err(f) => Err(Fail.line(f))
	Ok(locked) => match Removal.plan({ alias, rows: locked.rows, toml, shared }) {
		Ok(p) => Ok((p.what, p.keys.map(|k| (k.table, k.key)), p.patch_dir))
		Err(f) => Err(Fail.line(f))
	}
}

# R-CM3 R-RV1 R-RV3 R-RV4 R-RV5 R-H4 R-H9 R-WS14 R-OV1 R-PA11 R-PA12 (slice 008, slice 015): what `remove` does for one entry. A release, a path entry and a foreign URL are removed in the same way (R-RV5, R-H9: the user names the alias, and an unmanaged entry goes as a whole).
# The keys are the ones that the nearest `talon.toml` has for the alias, in the order `[dependencies]`, `[overrides]`, `[patch]`. A `[patch]` key keeps its files: `patch_dir` is the dir of `.talon/patches/<alias>/`
# next to that `talon.toml`. The platform is a usage failure (R-RV3). When another member under that `talon.toml` has the alias, no key goes (question Q3 of the slice).
expect {
	toml = Ok({ path: "/p/talon.toml", text: toml_text })
	unmanaged_toml = Ok({ path: "/p/talon.toml", text: "[dependencies]\nutil = \"^1\"\nodd = \"^2\"\n\n[overrides]\nutil = \"acme/util@^1.2\"\nodd = \"acme/odd@^2\"\n" })
	json_what = Release({ name: "someone/roc-json", version: "2.1.0" })
	rows = [
		("a release with the 3 keys and a patch", plan(app_text, "json", toml, Bool.False), Ok((json_what, [(Dependencies, "json"), (Overrides, "json"), (Patch, "json")], Ok("/p/.talon/patches/json/")))),
		("a release with a key in [dependencies] only", plan(app_text, "http", toml, Bool.False), Ok((Release({ name: "roc-lang/http", version: "1.9.0" }), [(Dependencies, "http")], Err(None)))),
		("a path entry has no key", plan(app_text, "util", toml, Bool.False), Ok((Path("../util/main.roc"), [], Err(None)))),
		("a foreign URL has no key", plan(app_text, "odd", toml, Bool.False), Ok((Foreign(odd), [], Err(None)))),
		# R-RV5 (slice 015): the key of the alias in `[dependencies]` and `[overrides]` goes with a path entry and with a foreign URL. The file that the path names is not touched (no `Plan` field for it).
		("a path entry with keys in 2 tables", plan(app_text, "util", unmanaged_toml, Bool.False), Ok((Path("../util/main.roc"), [(Dependencies, "util"), (Overrides, "util")], Err(None)))),
		("a foreign URL with keys in 2 tables", plan(app_text, "odd", unmanaged_toml, Bool.False), Ok((Foreign(odd), [(Dependencies, "odd"), (Overrides, "odd")], Err(None)))),
		("a path entry with keys, another member has the alias: no key", plan(app_text, "util", unmanaged_toml, Bool.True), Ok((Path("../util/main.roc"), [], Err(None)))),
		("a release in a package header", plan(pkg_text, "json", toml, Bool.False), Ok((json_what, [(Dependencies, "json"), (Overrides, "json"), (Patch, "json")], Ok("/p/.talon/patches/json/")))),
		("a talon.toml in another dir: the patch dir is next to it", plan(app_text, "json", Ok({ path: "/p/apps/a/talon.toml", text: toml_text }), Bool.False), Ok((json_what, [(Dependencies, "json"), (Overrides, "json"), (Patch, "json")], Ok("/p/apps/a/.talon/patches/json/")))),
		("another member has the alias: no key, no patch dir", plan(app_text, "json", toml, Bool.True), Ok((json_what, [], Err(None)))),
		("no talon.toml", plan(app_text, "json", Err(NoToml), Bool.False), Ok((json_what, [], Err(None)))),
		("a talon.toml with no key of the alias", plan(app_text, "json", Ok({ path: "/p/talon.toml", text: "[dependencies]\nhttp = \"^1\"\n" }), Bool.False), Ok((json_what, [], Err(None)))),
		("an alias that has only a key in [overrides]: no patch dir", plan(app_text, "json", Ok({ path: "/p/talon.toml", text: "[overrides]\njson = \"someone/roc-json@^2.1.3\"\n" }), Bool.False), Ok((json_what, [(Overrides, "json")], Err(None)))),
		("the platform under another alias", plan(alias_text, "shell", toml, Bool.False), Err("tln: error[usage]: shell is the platform of the app. An app needs a platform. Use tln add --platform <name> to change it.")),
		("a package with the alias pf is no platform", plan(alias_text, "pf", toml, Bool.False), Ok((json_what, [], Err(None)))),
		("the platform", plan(app_text, "pf", toml, Bool.False), Err("tln: error[usage]: pf is the platform of the app. An app needs a platform. Use tln add --platform <name> to change it.")),
		("an alias that is not in the header", plan(app_text, "nope", toml, Bool.False), Err("tln: error[internal]: nope is not in the header")),
		("a talon.toml that is not TOML", plan(app_text, "json", Ok({ path: "/p/talon.toml", text: "[dependencies\n" }), Bool.False), Err("tln: error[input]: /p/talon.toml:1: not valid TOML")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-NI5 R-FL12 R-DL5 (slice 025): `remove` runs the ladder, so it can need a compiler download. `--allow-downloads` is `Ok(Yes)` when set. `--probe-downloads` is read and changes nothing (R-NI4 does not list `remove`: it has no optional probe).
expect {
	flag = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Removal.opts(args) {
			Ok(o) => Ok(o.allow_downloads)
			Err(f) => Err(Fail.line(f))
		}
	}
	rows = [
		(["remove", "json"], Ok(Err(NoFlag))),
		(["remove", "json", "--allow-downloads"], Ok(Ok(Yes))),
		(["rm", "json", "--probe-downloads"], Ok(Err(NoFlag))),
		(["rm", "json", "--allow-downloads", "--probe-downloads", "--yes"], Ok(Ok(Yes))),
	]
	bad = rows.keep_if(|(words, want)| flag(words) != want).map(|(words, _)| (words, flag(words)))
	dbg bad
	bad == []
}

# R-FL11 R-FL7 R-LF2 R-PP7 (slice 031): `remove` resolves, so `--slots` and `--no-probe` are its flags too: `Opts.slots` and `Opts.no_probe` are the values that `Opts.read` gives.
expect {
	probe = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Removal.opts(args) {
			Ok(o) => Ok((o.slots, o.no_probe))
			Err(f) => Err(Fail.line(f))
		}
	}
	rows = [
		(["remove", "json"], Ok((Err(Unset), Bool.False))),
		(["rm", "json", "--slots", "3"], Ok((Ok(3), Bool.False))),
		(["remove", "json", "--no-probe", "--slots=2"], Ok((Ok(2), Bool.True))),
		(["remove", "json", "--slots", "0"], Err("tln: error[usage]: --slots must be a whole number of 1 or more, not '0'")),
	]
	wrong = rows.keep_if(|(words, want)| probe(words) != want).map(|(words, want)| (words, want, probe(words)))
	dbg wrong
	wrong == []
}

# R-CM10 R-PA1 R-PA2 R-PA3 R-PA8 R-PA14 R-FL5 R-EC2 (slice 042): the line of `tln patch`. One name, and `--diff` or not. No name and 2 names are usage failures (the text of the check, after the checks of `Opts.read`). A flag that `patch` does not take
# is a failure of `Args.parse`: `--commit` (R-PA2: `tln patch` has no `--commit`), `--dry-run` and the resolve flags.
expect {
	patch_line = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match PatchCmd.read(args) {
			Ok(p) => Ok((p.name, p.diff))
			Err(f) => Err(Fail.line(f))
		}
	}
	rows = [
		(["patch", "json"], Ok(("json", Bool.False))),
		(["patch", "json", "--diff"], Ok(("json", Bool.True))),
		(["patch", "--diff", "acme/json@2", "--file", "p/main.roc", "--json", "--yes", "--quiet", "--offline"], Ok(("acme/json@2", Bool.True))),
		(["patch"], Err("tln: error[usage]: tln patch takes one name")),
		(["patch", "--diff"], Err("tln: error[usage]: tln patch takes one name")),
		(["patch", "json", "http"], Err("tln: error[usage]: tln patch takes one name")),
		(["patch", "json", "--commit"], Err("tln: error[usage]: flag '--commit' is not for 'patch'")),
		(["patch", "json", "--dry-run"], Err("tln: error[usage]: flag '--dry-run' is not for 'patch'")),
		(["patch", "json", "--registry", "https://r.example"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
		(["list", "--diff"], Err("tln: error[usage]: flag '--diff' is not for 'list'")),
	]
	bad = rows.keep_if(|(words, want)| patch_line(words) != want).map(|(words, _)| (words, patch_line(words)))
	dbg bad
	bad == []
}

# R-PA8 R-PA14 R-SC1 R-SC6 R-SC7 R-SC8 R-SC16 R-PA9 (slice 042): the entry that a name selects, and the refusals. The name is read as `why` and `remove` read it: the alias, the full name, the short name, with the filter `@sel`. Only the entries of
# the header are names. A release gives its facts (the hash is the hash of the URL). The platform (also by its full name), a path entry and a foreign URL are usage failures with a text of their own, and nothing else is told (no block).
expect {
	url_of = |hash, version, repo| "https://github.com/${repo}/releases/download/${version}/${hash}.tar.zst"
	entry = |header, text| match Locked.read({ path: "/p/main.roc", text: header }) {
		Err(f) => Err(Fail.line(f))
		Ok(locked) => match PatchCmd.entry({ text, rows: locked.rows }) {
			Ok(t) => Ok(t)
			Err(e) => Err("${Fail.line(e.fail)} block=${Str.inspect(e.block)}")
		}
	}
	json_target = Ok({ alias: "json", name: "someone/roc-json", version: "2.1.0", url: json1, hash: h_json1 })
	http_target = Ok({ alias: "http", name: "roc-lang/http", version: "1.9.0", url: http1, hash: h_http })
	pf_refused = Err("tln: error[usage]: pf is the platform of the app. tln patch does not copy a platform: its archive holds host binaries. Use a fork and its release, or a path entry. block=\"\"")
	rows = [
		("the alias", entry(app_text, "json"), json_target),
		("the full name", entry(app_text, "roc-lang/http"), http_target),
		("the short name", entry(app_text, "roc-json"), json_target),
		("a selector in the series of the entry", entry(app_text, "json@2"), json_target),
		("the full name with a selector", entry(app_text, "someone/roc-json@^2.1"), json_target),
		("a selector that the entry does not satisfy", entry(app_text, "json@3"), Err("tln: error[usage]: 'json@3' is not in the project block=\"\"")),
		("a name that is not in the header", entry(app_text, "nope"), Err("tln: error[usage]: 'nope' is not in the project block=\"\"")),
		("the platform by its alias", entry(app_text, "pf"), pf_refused),
		("the platform by its full name", entry(app_text, "roc-lang/basic-cli"), pf_refused),
		("a path entry", entry(app_text, "util"), Err("tln: error[usage]: util is a path entry. It is local code: edit its file. block=\"\"")),
		("a foreign URL", entry(app_text, "odd"), Err("tln: error[usage]: odd is a foreign URL. It has no release, so tln patch cannot copy it. block=\"\"")),
	]
	# The url of the facts is the text of the header.
	same_url = url_of(h_json1, "2.1.0", "someone/roc-json") == json1
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == [] and same_url
}

# R-PA1 R-PA9 R-PA11 R-PA12 R-PA3 R-OUT2 R-OUT4 (slice 042, proposal TW24 for the texts): where the copy goes, the dir that a `[patch]` entry names, the failure of a dir that exists, and the output of the 2 modes.
# The copy is `<dir of talon.toml>/.talon/patches/<alias>/` and the entry path is `./.talon/patches/<alias>/main.roc` (the form of R-PA9). The dir of an entry is the dir of its `path`, as `Text.resolve` sees it.
expect {
	target = { alias: "json", name: "someone/roc-json", version: "2.1.0", url: json1, hash: h_json1 }
	place = PatchCmd.place({ toml: "/p/talon.toml", alias: "json" })
	place_sub = PatchCmd.place({ toml: "/p/apps/a/talon.toml", alias: "http" })
	made = PatchCmd.created({ target, dir: "/p/.talon/patches/json/", toml: "/p/talon.toml", toml_created: Bool.False })
	made_new = PatchCmd.created({ target, dir: "/p/.talon/patches/json/", toml: "/p/talon.toml", toml_created: Bool.True })
	text_of = |toml_line| "copied: /p/.talon/patches/json/ (someone/roc-json 2.1.0)\n${toml_line}\nedit the copy, then commit it and talon.toml. Review it with: tln patch json --diff\n"
	data_of = |created| "{\"alias\":\"json\",\"name\":\"someone/roc-json\",\"version\":\"2.1.0\",\"base\":\"${h_json1}\",\"dir\":\"/p/.talon/patches/json/\",\"toml\":\"/p/talon.toml\",\"toml_created\":${created}}"
	changes = Diff.make({
		base: [{ path: "a.txt", content: Utf8("x\n") }, { path: "b.bin", content: Binary("h1") }, { path: "gone.txt", content: Utf8("g\n") }, { path: "same", content: Utf8("s\n") }],
		copy: [{ path: "a.txt", content: Utf8("y\n") }, { path: "b.bin", content: Binary("h2") }, { path: "new.txt", content: Utf8("n\n") }, { path: "same", content: Utf8("s\n") }],
	})
	review = PatchCmd.shown({ alias: "json", base: "abc", dir: "/p/.talon/patches/json/", changes })
	same = PatchCmd.shown({ alias: "json", base: "abc", dir: "/p/.talon/patches/json/", changes: [] })
	list = "[{\"path\":\"a.txt\",\"change\":\"modified\"},{\"path\":\"b.bin\",\"change\":\"replaced\"},{\"path\":\"gone.txt\",\"change\":\"deleted\"},{\"path\":\"new.txt\",\"change\":\"added\"}]"
	rows = [
		("place: next to the talon.toml", "${place.dir} ${place.entry_path}", "/p/.talon/patches/json/ ./.talon/patches/json/main.roc"),
		("place: the talon.toml of a subdir", "${place_sub.dir} ${place_sub.entry_path}", "/p/apps/a/.talon/patches/http/ ./.talon/patches/http/main.roc"),
		("copy_dir: the entry of R-PA9", PatchCmd.copy_dir({ toml: "/p/talon.toml", path: "./.talon/patches/json/main.roc" }), "/p/.talon/patches/json/"),
		("copy_dir: a path with .. and a subdir", PatchCmd.copy_dir({ toml: "/p/apps/talon.toml", path: "../vendor/json/src/main.roc" }), "/p/vendor/json/src/"),
		("copy_dir: an absolute path", PatchCmd.copy_dir({ toml: "/p/talon.toml", path: "/q/json/main.roc" }), "/q/json/"),
		("the failure of a dir that exists names the dir", Fail.line(PatchCmd.exists("/p/.talon/patches/json/")), "tln: error[usage]: /p/.talon/patches/json/ exists already. Edit the copy, or remove it to start again."),
		("created: the lines", made.text, text_of("/p/talon.toml: + [patch] json")),
		("created: a new talon.toml", made_new.text, text_of("/p/talon.toml: + [patch] json (new file)")),
		("created: the data", made.data.render(), data_of("false")),
		("created: the data of a new file", made_new.data.render(), data_of("true")),
		("shown: stdout is the diff and nothing else", review.text, Diff.render(changes)),
		("shown: no note when there are changes", review.note, ""),
		("shown: the data", review.data.render(), "{\"alias\":\"json\",\"base\":\"abc\",\"dir\":\"/p/.talon/patches/json/\",\"changes\":${list},\"diff\":${JsonDoc.Text(review.text).render()}}"),
		("shown: no changes", "${same.text}|${same.note}", "|json: no changes against abc\n"),
		("shown: the data of no changes", same.data.render(), "{\"alias\":\"json\",\"base\":\"abc\",\"dir\":\"/p/.talon/patches/json/\",\"changes\":[],\"diff\":\"\"}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
