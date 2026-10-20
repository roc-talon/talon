app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Intent

main! = |_args| Ok({})

lines = |list| "${Str.join_with(list, "\n")}\n"

# The design example of Design 4.3, with a root `[workspace]`, an override and a snapshot. The comments are part of the file.
full_text = lines([
	"[workspace]", # 1
	"members = [\"apps/*/main.roc\"]", # 2
	"", # 3
	"[toolchain]", # 4
	"roc = \">=nightly-2026-10-09-258ab27\"   # the oldest compiler that our code needs", # 5
	"nightly = true", # 6
	"", # 7
	"[dependencies]", # 8
	"pf = \"0.25.*\"                  # the platform", # 9
	"parser = \"=2.0.0\"              # anchor: hard pin", # 10
	"json = \"^2.1\"", # 11
	"http = \"roc-lang/http@^1\"      # not in the header yet: tln install adds it (R-I5)", # 12
	"yaml = \"yaml@2\"", # 13
	"", # 14
	"[overrides]", # 15
	"unicode = \"roc-lang/unicode@^4.2\"", # 16
	"", # 17
	"[resolution]", # 18
	"priority = [\"parser\", \"pf\", \"roc\"]", # 19
	"strategy = \"lowest\"", # 20
	"min-release-age = \"3d\"", # 21
	"snapshot = \"2026-10-12T00:00:00Z\"", # 22
	"probe = { max = 100, max-toolchains = 10, slots = 12 }", # 23
	"", # 24
	"[audit]", # 25
	"ignore = [\"someone/roc-old@1.0.0:yanked\"]", # 26
	"", # 27
	"[patch]", # 28
	"anything = \"P1 content is not read\"", # 29
])

shown = |r| match r {
	Ok(read) => Ok(read)
	Err(e) => Err(e.line())
}

# R-I1 R-I2 R-I3 R-VA5 R-VA6 R-C7 R-NS7 R-NS9 R-DT3 R-DT4 R-OV1 R-WS5: the intent of `talon.toml`. A key of `[dependencies]` is a header alias. A value is a range, or `<name>@<range>`
# (R-I2: the key `http` with the value `roc-lang/http@^1`; a key that the header has needs only the range). `=2.0.0` is an anchor (it is a range). `[overrides]` has the same value forms
# (R-OV1). The resolution keys are `priority`, `strategy`, `min-release-age` (whole days, in seconds) and `snapshot` (`log:<n>` or a UTC time). The line of each key is 1-based.
# `[audit]`, `[patch]` and `probe` are known and not read in P0 (no warning). The role `Root` and the role `Member` read the same way when the tables are allowed.
expect {
	got = Intent.read({ path: "/r/talon.toml", text: full_text, role: Root })
	view = match got {
		Ok({ intent, warnings }) => Ok((
			(intent.toolchain.roc, intent.toolchain.roc_text, intent.toolchain.nightly),
			intent.deps.map(|d| (d.key, d.name, d.range, d.line)),
			intent.overrides.map(|d| (d.key, d.name, d.range, d.line)),
			(intent.resolution.priority, intent.resolution.strategy, intent.resolution.min_release_age, intent.resolution.snapshot),
			warnings,
		))
		Err(e) => Err(e.line())
	}
	want = Ok((
		(Ok(AtLeast("nightly-2026-10-09-258ab27")), Ok(">=nightly-2026-10-09-258ab27"), Ok(Bool.True)),
		[
			("pf", Err(None), "0.25.*", 9),
			("parser", Err(None), "=2.0.0", 10),
			("json", Err(None), "^2.1", 11),
			("http", Ok("roc-lang/http"), "^1", 12),
			("yaml", Ok("yaml"), "2", 13),
		],
		[("unicode", Ok("roc-lang/unicode"), "^4.2", 16)],
		(Ok(["parser", "pf", "roc"]), Ok(Lowest), Ok(259200), Ok(Time(1791763200))),
		[],
	))
	dbg view

	empty = Intent.read({ path: "/p/talon.toml", text: "", role: Standalone })
	empty_view = match empty {
		Ok({ intent, warnings }) => Ok((intent.toolchain, intent.deps, intent.overrides, intent.resolution, warnings))
		Err(e) => Err(e.line())
	}
	empty_want = Ok(({ roc: Err(Unset), roc_text: Err(Unset), nightly: Err(Unset) }, [], [], { priority: Err(Unset), strategy: Err(Unset), min_release_age: Err(Unset), snapshot: Err(Unset) }, []))
	dbg empty_view

	member_text = lines(["# a member", "[dependencies]", "json = \"^2.3\"", "", "[overrides]", "x = \"^1\"", "", "[patch]", "y = 1"])
	member = Intent.read({ path: "/r/apps/a/talon.toml", text: member_text, role: Member })
	member_view = match member {
		Ok({ intent, warnings }) => Ok((intent.deps.map(|d| (d.key, d.range, d.line)), warnings))
		Err(e) => Err(e.line())
	}
	logs = Intent.read({ path: "/p/talon.toml", text: "[resolution]\nsnapshot = \"log:184467\"\nmin-release-age = \"0d\"\n", role: Standalone })
	logs_view = match logs {
		Ok({ intent, .. }) => Ok((intent.resolution.snapshot, intent.resolution.min_release_age))
		Err(e) => Err(e.line())
	}
	dbg [member_view == Ok(([("json", "^2.3", 3)], [])), logs_view == Ok((Ok(Log(184467)), Ok(0)))]
	view == want and empty_view == empty_want and member_view == Ok(([("json", "^2.3", 3)], [])) and logs_view == Ok((Ok(Log(184467)), Ok(0)))
}

# R-TF4 R-WS5 R-EC19 R-I2: a `talon.toml` that is not valid TOML, or a known key with a value of the wrong type or form (a range that does not parse, an unknown `strategy`), stops the command
# with exit 19 and names the file, the line and the key. A known table that a workspace member file may not have (R-WS5) is the same failure, with the line of the table. An unknown key or table
# is a warning and the command goes on (a newer Talon can know it). The text of `roc-toml` is not shown.
expect {
	read = |text, role| Intent.read({ path: "/p/talon.toml", text, role })
	fails = |text, role| match read(text, role) {
		Ok(_) => "no failure"
		Err(e) => e.line()
	}
	failures = [
		("not TOML", "[dependencies]\njson = = 1\n", Standalone, "tln: error[input]: /p/talon.toml:2: not valid TOML"),
		("a range that does not parse", "[dependencies]\njson = \"latest\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: dependencies.json: 'latest' is not a version range"),
		("the range of a value with a name", "[dependencies]\n\nhttp = \"roc-lang/http@mian\"\n", Standalone, "tln: error[input]: /p/talon.toml:3: dependencies.http: 'mian' is not a version range"),
		# R-I2: the name ends at the first `@`, so the range is the rest, `^1@x`.
		("2 @ in a value: the range is after the first one", "[dependencies]\nhttp = \"roc-lang/http@^1@x\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: dependencies.http: '^1@x' is not a version range"),
		("an override with a bad range", "[overrides]\nx = \"^\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: overrides.x: '^' is not a version range"),
		("a dependency that is not a string", "[dependencies]\njson = 5\n", Standalone, "tln: error[input]: /p/talon.toml:2: dependencies.json: must be a string"),
		("a compiler range", "[toolchain]\nroc = \"latest\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: toolchain.roc: 'latest' is not a compiler range"),
		("nightly is not a boolean", "[toolchain]\nnightly = \"yes\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: toolchain.nightly: must be true or false"),
		("an unknown strategy", "[resolution]\nstrategy = \"middle\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: resolution.strategy: must be \"highest\" or \"lowest\""),
		("min-release-age in hours", "[resolution]\nmin-release-age = \"48h\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: resolution.min-release-age: must be a number of days, for example \"2d\""),
		("a snapshot", "[resolution]\nsnapshot = \"yesterday\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: resolution.snapshot: must be \"log:<n>\" or a UTC time"),
		("a priority that is not a list of strings", "[resolution]\npriority = [1]\n", Standalone, "tln: error[input]: /p/talon.toml:2: resolution.priority: must be a list of strings"),
		("[resolution] in a member file (R-WS5)", "# member\n[dependencies]\njson = \"^2\"\n\n[resolution]\nstrategy = \"lowest\"\n", Member, "tln: error[input]: /p/talon.toml:5: the table [resolution] is not allowed in a workspace member file (it has only dependencies, overrides and patch)"),
		("[toolchain] in a member file", "[toolchain]\nroc = \"*\"\n", Member, "tln: error[input]: /p/talon.toml:1: the table [toolchain] is not allowed in a workspace member file (it has only dependencies, overrides and patch)"),
		("[audit] in a member file", "[audit]\nignore = []\n", Member, "tln: error[input]: /p/talon.toml:1: the table [audit] is not allowed in a workspace member file (it has only dependencies, overrides and patch)"),
		("[workspace] in a member file", "[workspace]\nmembers = []\n", Member, "tln: error[input]: /p/talon.toml:1: the table [workspace] is not allowed in a workspace member file (it has only dependencies, overrides and patch)"),
		("the first one in file order", "[dependencies]\njson = \"latest\"\n\n[resolution]\nstrategy = \"x\"\n", Standalone, "tln: error[input]: /p/talon.toml:2: dependencies.json: 'latest' is not a version range"),
	]
	bad_failures = failures.keep_if(|(_, text, role, want)| fails(text, role) != want).map(|(label, text, role, want)| (label, want, fails(text, role)))
	dbg bad_failures

	warned = |text, role| match read(text, role) {
		Ok({ warnings, .. }) => warnings
		Err(e) => [e.line()]
	}
	warnings = [
		("an unknown table", "[extra]\nx = 1\n", Standalone, ["/p/talon.toml:1: unknown table [extra]"]),
		("an unknown key of a known table", "[toolchain]\nroc = \"*\"\nfoo = 1\n\n[resolution]\ncolor = \"red\"\n", Standalone, ["/p/talon.toml:3: unknown key toolchain.foo", "/p/talon.toml:6: unknown key resolution.color"]),
		("an unknown key at the top", "top = 1\n[dependencies]\njson = \"^2\"\n", Standalone, ["/p/talon.toml:1: unknown key top"]),
		("the known tables and keys of P1 and P3: no warning", "[audit]\nignore = []\n[patch]\nz = 1\n[resolution]\nprobe = { max = 5 }\n", Standalone, []),
		("a member file with an unknown table", "[dependencies]\njson = \"^2\"\n\n[x]\ny = 1\n", Member, ["/p/talon.toml:4: unknown table [x]"]),
	]
	bad_warnings = warnings.keep_if(|(_, text, role, want)| warned(text, role) != want).map(|(label, text, role, want)| (label, want, warned(text, role)))
	dbg bad_warnings
	bad_failures == [] and bad_warnings == []
}

# R-AD25 R-AD26 R-UP11 R-WS14 R-H1: the edit of `talon.toml`. A key that is there gets a new string value: only the bytes of the old value change, so the comment on its line stays. A key that is not
# there is added after the last entry of `[dependencies]`; the table is made when it is missing; the empty text gives a new file. The same value is no change. R-CC7: `spans` is the printed value of each
# key. R-PD6: `paths` are the files that can be the nearest `talon.toml` of a member. R-DT3: a `log:` snapshot is a usage failure with `direct`.
expect {
	text = lines(["# our intent", "[dependencies]", "pf = \"0.25.*\"  # the platform", "json = \"^2.1\"   # keep me", "", "# other tables", "[resolution]", "strategy = \"lowest\""])
	apply = |t, writes| match Intent.apply({ path: "/p/talon.toml", text: t, writes }) {
		Ok(done) => Ok(done)
		Err(e) => Err(e.line())
	}
	json_up = apply(text, [{ key: "json", value: "^3" }])
	want_json_up = Ok(text.replace_each("\"^2.1\"", "\"^3\""))
	http_add = apply(text, [{ key: "http", value: "^1" }])
	want_http_add = Ok(text.replace_each("json = \"^2.1\"   # keep me\n", "json = \"^2.1\"   # keep me\nhttp = \"^1\"\n"))
	both = apply(text, [{ key: "json", value: "=3.0.2" }, { key: "http", value: "^1" }])
	want_both = Ok(text.replace_each("\"^2.1\"", "\"=3.0.2\"").replace_each("json = \"=3.0.2\"   # keep me\n", "json = \"=3.0.2\"   # keep me\nhttp = \"^1\"\n"))
	same = apply(text, [{ key: "json", value: "^2.1" }])
	no_table = "# only a resolution\n[resolution]\nstrategy = \"lowest\"\n"
	made = apply(no_table, [{ key: "json", value: "^2" }])
	want_made = Ok("${no_table}\n[dependencies]\njson = \"^2\"\n")
	new_file = apply("", [{ key: "json", value: "^2" }])
	not_toml = apply("[dependencies\n", [{ key: "json", value: "^2" }])
	nothing = apply("anything at all, not read", [])
	dbg [json_up, http_add]
	apply_rows = [
		("replace a value, keep the comment", json_up, want_json_up),
		("add a key after the last entry", http_add, want_http_add),
		("replace and add", both, want_both),
		("the same value: no change", same, Ok(text)),
		("add the table", made, want_made),
		("a new file", new_file, Ok("[dependencies]\njson = \"^2\"\n")),
		("not TOML", not_toml, Err("tln: error[input]: /p/talon.toml:1: not valid TOML")),
		("no writes: the text as it is", nothing, Ok("anything at all, not read")),
	]
	bad_apply = apply_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_apply

	spans = Intent.spans({ text, keys: ["json", "pf", "http"] })
	dbg spans
	paths = [
		("a member 2 levels below the root", { member: "/r/apps/a/main.roc", root: "/r" }, ["/r/apps/a/talon.toml", "/r/apps/talon.toml", "/r/talon.toml"]),
		("a member in the root dir", { member: "/r/main.roc", root: "/r" }, ["/r/talon.toml"]),
		("a member 1 level below", { member: "/r/examples/hello.roc", root: "/r" }, ["/r/examples/talon.toml", "/r/talon.toml"]),
		("a member that is not under the root", { member: "/other/main.roc", root: "/r" }, ["/r/talon.toml"]),
		("a root named like a prefix", { member: "/rx/a/main.roc", root: "/r" }, ["/r/talon.toml"]),
	]
	bad_paths = paths.keep_if(|(_, facts, want)| Intent.paths(facts) != want).map(|(label, facts, want)| (label, want, Intent.paths(facts)))
	dbg bad_paths

	snap = |s| match Intent.direct_snapshot(s) {
		Ok(t) => Ok(t)
		Err(e) => Err(e.line())
	}
	snaps = [
		(Err(Unset), Ok(Err(None))),
		(Ok(Time(1791763200)), Ok(Ok(1791763200))),
		(Ok(Log(184467)), Err("tln: error[usage]: snapshot log:184467 needs a registry: direct has no log. Use a UTC time, for example 2026-10-12T00:00:00Z.")),
	]
	bad_snaps = snaps.keep_if(|(s, want)| snap(s) != want)
	dbg bad_snaps
	bad_apply == [] and spans == ["\"^2.1\"", "\"0.25.*\"", ""] and bad_paths == [] and bad_snaps == []
}

# R-NI1 R-I8 R-H1 R-CC7 (slice 007): the rename of a stale key. Only the bytes of the key change: the value, the comment on the line, the order, the other tables and all other bytes stay.
# The key of `[dependencies]` is renamed. A missing key and a new key that is already there are failures. No rename gives the text as it is.
# `spans` of the old keys is what `Guard` compares (R-CC7).
expect {
	text = lines(["# our intent", "[dependencies]", "pf = \"0.25.*\"  # the platform", "js = \"acme/json@^2\"   # keep me", "json_old = \"^1\"", "", "[overrides]", "p = \"acme/parser@^1\"", "", "[resolution]", "strategy = \"lowest\""])
	rename = |renames| match Intent.rename({ path: "/p/talon.toml", text, renames }) {
		Ok(done) => Ok(done)
		Err(e) => Err(e.line())
	}
	rows = [
		("one key, the comment stays", rename([{ from: "js", to: "json" }]), Ok(text.replace_each("js = \"acme/json@^2\"   # keep me", "json = \"acme/json@^2\"   # keep me"))),
		(
			"2 keys",
			rename([{ from: "js", to: "json" }, { from: "json_old", to: "older" }]),
			Ok(text.replace_each("js = ", "json = ").replace_each("json_old = ", "older = ")),
		),
		("no rename", rename([]), Ok(text)),
		("a key that is not there", rename([{ from: "nosuch", to: "x" }]), Err("tln: error[internal]: /p/talon.toml: the key 'nosuch' is not there")),
		("a new key that is there", rename([{ from: "js", to: "pf" }]), Err("tln: error[usage]: /p/talon.toml: the key 'pf' is already there")),
		(
			"not TOML",
			match Intent.rename({ path: "/p/talon.toml", text: "[dependencies\n", renames: [{ from: "js", to: "json" }] }) {
				Ok(done) => Ok(done)
				Err(e) => Err(e.line())
			},
			Err("tln: error[input]: /p/talon.toml:1: not valid TOML"),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == [] and Intent.spans({ text, keys: ["js", "json_old"] }) == ["\"acme/json@^2\"", "\"^1\""]
}

# R-CM3 R-RV1 R-RV4 R-OV1 R-PA12 R-H1 R-CC7 (slice 008): the removal of the keys of an alias. Only the lines of the keys go (with the comment on the line). The comment lines above, the header of a table that
# becomes empty, the other keys and all other bytes stay. A `[patch]` entry is an inline table: it goes whole. The order of the keys makes no difference. A key that is not there is a failure (the command
# must never ask for it), and a text that is not TOML is the failure of `read`. No key gives the text as it is. `table_spans` is what `Guard` compares (R-CC7).
expect {
	text = lines([
		"# our intent",
		"[dependencies]",
		"pf = \"0.25.*\"  # the platform",
		"# the range of json",
		"json = \"^2.1\"   # keep me",
		"http = \"^1\"",
		"",
		"[overrides]",
		"json = \"someone/roc-json@^2.1.3\"",
		"",
		"[patch]",
		"json = { path = \"./.talon/patches/json/main.roc\", base = \"abc\" }",
		"other = { path = \"./.talon/patches/other/main.roc\", base = \"def\" }",
		"",
		"[resolution]",
		"strategy = \"lowest\"",
	])
	remove = |input, keys| match Intent.remove({ path: "/p/talon.toml", text: input, keys }) {
		Ok(done) => Ok(done)
		Err(e) => Err(e.line())
	}
	dep_json = { table: Dependencies, key: "json" }
	ov_json = { table: Overrides, key: "json" }
	patch_json = { table: Patch, key: "json" }
	all_three = text.replace_each("json = \"^2.1\"   # keep me\n", "").replace_each("json = \"someone/roc-json@^2.1.3\"\n", "").replace_each("json = { path = \"./.talon/patches/json/main.roc\", base = \"abc\" }\n", "")
	rows = [
		("one key: the comment on its line goes, the comment above stays", remove(text, [dep_json]), Ok(text.replace_each("json = \"^2.1\"   # keep me\n", ""))),
		("the 3 keys: an empty table keeps its header", remove(text, [dep_json, ov_json, patch_json]), Ok(all_three)),
		("the order of the keys does not matter", remove(text, [patch_json, dep_json, ov_json]), Ok(all_three)),
		("an inline table goes whole, the next entry stays", remove(text, [patch_json]), Ok(text.replace_each("json = { path = \"./.talon/patches/json/main.roc\", base = \"abc\" }\n", ""))),
		("no key", remove(text, []), Ok(text)),
		("a key that is not there", remove(text, [{ table: Dependencies, key: "nosuch" }]), Err("tln: error[internal]: /p/talon.toml: the key 'nosuch' is not there")),
		("the key of another table", remove(text, [{ table: Overrides, key: "http" }]), Err("tln: error[internal]: /p/talon.toml: the key 'http' is not there")),
		("not TOML", remove("[dependencies\n", [dep_json]), Err("tln: error[input]: /p/talon.toml:1: not valid TOML")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	spans = Intent.table_spans({ text, keys: [dep_json, ov_json, patch_json, { table: Overrides, key: "http" }, { table: Dependencies, key: "nosuch" }] })
	dbg spans
	bad == [] and spans == ["\"^2.1\"", "\"someone/roc-json@^2.1.3\"", "{ path = \"./.talon/patches/json/main.roc\", base = \"abc\" }", "", ""]
}
