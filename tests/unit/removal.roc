app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.Locked
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
