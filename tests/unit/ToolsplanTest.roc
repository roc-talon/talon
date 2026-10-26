import lib.Args
import lib.Consent
import lib.Fail
import lib.Gc
import lib.Ident
import lib.Index
import lib.Intent
import lib.ToolInstall
import lib.ToolsCmd
import lib.ToolsPlan
import lib.ToolsToml
import lib.XCache
import lib.XCacheIo

ToolsplanTest :: [].{}

# Slice 056, project tools `[tools]` (CLI 6.4, R-PT1 to R-PT16). Part A: the pure decisions of `Intent.read` (the table), `ToolsToml`, `ToolsPlan` and `ToolsCmd`.

lines = |list| "${Str.join_with(list, "\n")}\n"

h_foo10 = "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW"

h_foo11 = "AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY"

h_foo20 = "Gjd7Us4DTdcWjQgC2FQUo4eXgXbJ7xCiTYUFdUajzWvq"

h_bar10 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"

foo10 = "https://github.com/acme/foo/releases/download/1.0.0/${h_foo10}.tar.zst"

foo11 = "https://github.com/acme/foo/releases/download/1.1.0/${h_foo11}.tar.zst"

foo20 = "https://github.com/acme/foo/releases/download/2.0.0/${h_foo20}.tar.zst"

bar10 = "https://github.com/acme/bar/releases/download/1.0.0/${h_bar10}.tar.zst"

# What `Intent.read` of the text gives for `[tools]`: the entries and the warnings, or the failure as `<code> <message>`.
read_tools = |text, role| match Intent.read({ path: "talon.toml", text, role }) {
	Ok(r) => Ok((r.intent.tools, r.warnings))
	Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
}

# R-PT1, R-PT5, R-TF4: the forms of `[tools]`. An entry has `ref` and a `url` (or only `ref`, before `tln install` locks it). The entries are in the order of their lines, and a `ref` with no selector is read as it is written.
expect {
	text = lines([
		"[tools]", # 1
		"roc-cfw = { ref = \"acme/foo@^1\", url = \"${foo11}\" }  # the lock", # 2
		"fmt = { ref = \"acme/fmt\" }", # 3
		"\"v2.x_y\" = { ref = \"acme/bar@latest\", note = \"x\" }", # 4
	])
	read_tools(text, Standalone) == Ok((
		[
			{ key: "roc-cfw", ref: "acme/foo@^1", url: Ok(foo11), line: 2 },
			{ key: "fmt", ref: "acme/fmt", url: Err(Unset), line: 3 },
			{ key: "v2.x_y", ref: "acme/bar@latest", url: Err(Unset), line: 4 },
		],
		["talon.toml:4: unknown key tools.v2.x_y.note"],
	))
}

# R-PT1, R-TF4 (exit code 19): a form that is not valid, by line. Each failure names the key and says why.
expect {
	rows = [
		("[tools]\nFoo = { ref = \"acme/foo\" }\n", "19 talon.toml:2: tools.Foo: the key is not a tool name (lower case letters, digits, '.', '_' and '-', and the first one a letter or a digit)"),
		("[tools]\nfoo = \"acme/foo\"\n", "19 talon.toml:2: tools.foo: must be a table with ref and url"),
		("[tools]\nfoo = { url = \"${foo11}\" }\n", "19 talon.toml:2: tools.foo.ref: must be a string"),
		("[tools]\nfoo = { ref = \"foo\" }\n", "19 talon.toml:2: tools.foo.ref: 'foo' is not an owner/app name"),
		("[tools]\nfoo = { ref = \"acme/foo@dd03c09e\" }\n", "19 talon.toml:2: tools.foo.ref: 'dd03c09e' is not a release selector (a version, a range or latest)"),
		("[tools]\nfoo = { ref = \"acme/foo\", url = \"https://example.com/x.tar.zst\" }\n", "19 talon.toml:2: tools.foo.url: 'https://example.com/x.tar.zst' is not a release URL with a version and a hash"),
		("[tools]\nfoo = { ref = \"acme/foo\", url = 3 }\n", "19 talon.toml:2: tools.foo.url: must be a string"),
		# R-ID5 R-H4 (slice 076): a hash that is not a safe path part is no hash, so the `url` is not a release URL (the key of a cloned repository must not name a path outside `packages/`)
		("[tools]\nfoo = { ref = \"acme/foo\", url = \"https://github.com/acme/foo/releases/download/1.1.0/...tar.zst\" }\n", "19 talon.toml:2: tools.foo.url: 'https://github.com/acme/foo/releases/download/1.1.0/...tar.zst' is not a release URL with a version and a hash"),
		("[tools]\nfoo = { ref = \"acme/foo\", url = \"https://github.com/acme/foo/releases/download/1.1.0/a\\\\b.tar.zst\" }\n", "19 talon.toml:2: tools.foo.url: 'https://github.com/acme/foo/releases/download/1.1.0/a\\b.tar.zst' is not a release URL with a version and a hash"),
		("tools = 1\n", "19 talon.toml:1: tools: must be a table"),
	]
	rows.all(|(text, want)| read_tools(text, Standalone) == Err(want))
}

# R-PT2, R-WS5: `[tools]` is a table of the root file and of a standalone file. A member file of a workspace has no `[tools]`: exit code 19, on the line of the table. The table is no unknown table (no warning).
expect {
	text = "# the tools\n[tools]\nfoo = { ref = \"acme/foo\" }\n"
	member = read_tools(text, Member)
	root = read_tools(text, Root)
	member == Err("19 talon.toml:2: the table [tools] is not allowed in a workspace member file (it has only dependencies, overrides, patch and build)") and root == Ok(([{ key: "foo", ref: "acme/foo", url: Err(Unset), line: 3 }], []))
}

# R-PT3, R-PT5: `ToolsToml.put` changes only its own bytes. A new key goes after the last entry, a key that is there is replaced where it is (the comment stays), a missing table goes at the end after a blank line, the empty text gets the table and the entry.
expect {
	entry = { ref: "acme/foo@^1.1.0", url: foo11 }
	line = |key, e| "${key} = { ref = \"${e.ref}\", url = \"${e.url}\" }"
	put = |text, key, e| ToolsToml.put({ path: "talon.toml", text, key, ref: e.ref, url: e.url })
	base = lines(["# tools", "[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\" }  # keep", "", "[dependencies]", "json = \"^1\""])
	added = put(base, "b", entry)
	replaced = put(base, "a", entry)
	fresh = put(lines(["[dependencies]", "json = \"^1\""]), "foo", entry)
	empty = put("", "foo", entry)
	added == Ok(lines(["# tools", "[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\" }  # keep", line("b", entry), "", "[dependencies]", "json = \"^1\""])) and replaced == Ok(lines(["# tools", "[tools]", "${line("a", entry)}  # keep", "", "[dependencies]", "json = \"^1\""])) and fresh == Ok(lines(["[dependencies]", "json = \"^1\"", "", "[tools]", line("foo", entry)])) and empty == Ok("[tools]\n${line("foo", entry)}\n")
}

# R-PT3, R-CC7: `drop` removes the entries (the lines of the entry go, the other bytes stay), `spans` has the text of each key for the check before the write (`""` for a key that is not there).
expect {
	text = lines(["[tools]", "a = { ref = \"acme/a\", url = \"${foo10}\" }", "b = { ref = \"acme/b\" }  # b", "c = { ref = \"acme/c\" }"])
	dropped = ToolsToml.drop({ path: "talon.toml", text, keys: ["a", "b"] })
	none = ToolsToml.drop({ path: "talon.toml", text, keys: [] })
	missing = match ToolsToml.drop({ path: "talon.toml", text, keys: ["z"] }) {
		Ok(_) => "ok"
		Err(e) => "${e.kind.code().to_str()} ${e.message}"
	}
	spans = ToolsToml.spans({ text, keys: ["b", "z"] })
	dropped == Ok(lines(["[tools]", "c = { ref = \"acme/c\" }"])) and none == Ok(text) and missing == "1 talon.toml: the key 'z' is not there" and spans == ["{ ref = \"acme/b\" }", ""]
}

# R-PT2, NC2: the `talon.toml` of the tools. A workspace has it in the root (also for a member), a standalone project in the directory of its project file (also inside a workspace directory). No file and no workspace is a usage failure.
expect {
	ws = Ok({ root: "/w", members: ["/w/a/main.roc"] })
	rows = [
		(ws, Ok("/w/a/main.roc"), Ok("/w/talon.toml")),
		(ws, Err(NoCurrent), Ok("/w/talon.toml")),
		(Err(Standalone), Ok("/p/app/main.roc"), Ok("/p/app/talon.toml")),
		(Err(Standalone), Err(NoCurrent), Err("2 no project file found. Pass --file <path>.")),
	]
	rows.all(
		|(workspace, file, want)| match ToolsPlan.home({ workspace, file }) {
			Ok(path) => Ok(path) == want
			Err(e) => Err("${e.kind.code().to_str()} ${e.message}") == want
		},
	)
}

# R-PT5: the names of `update` and `upgrade` with no `--tool`. A name with an `@` whose first part is no key is for the header (a selector, R-CM4; slice 073 changed the row `foo@^2`: a selector on a key is exit code 2, expect 18). A key of `[tools]` that is no alias is a tool. An alias that is also a key is exit code 2 and names `--tool`.
expect {
	split = |names, keys, aliases| match ToolsPlan.split({ command: "update", names, keys, aliases }) {
		Ok(s) => Ok((s.header, s.tools))
		Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
	}
	split(["fmt", "json", "json@^2", "fmt2"], ["fmt", "foo"], ["json", "foo"]) == Ok((["json", "json@^2", "fmt2"], ["fmt"])) and split([], ["fmt"], ["json"]) == Ok(([], [])) and split(["foo"], ["foo"], ["foo"]) == Err("2 'foo' is a header alias and a key of [tools]. For the tool, run: tln update --tool foo")
}

# R-PT7, R-LF1: the check of `install --frozen` for the entries, in the order of the entries, one finding for an entry: no `url`, a version that the `ref` does not admit (a range, an exact version, `latest` and no selector admit what they admit), another app. Exit code 14.
expect {
	e = |key, ref, url, line| { key, ref, url, line }
	check = |tools| match ToolsPlan.frozen_check({ path: "/p/talon.toml", tools }) {
		Ok({}) => "ok"
		Err(f) => "${f.kind.code().to_str()} ${f.message}"
	}
	ok = [e("a", "acme/foo@^1", Ok(foo11), 2), e("b", "acme/foo", Ok(foo20), 3), e("c", "acme/foo@latest", Ok(foo10), 4), e("d", "acme/foo@1.0.0", Ok(foo10), 5)]
	bad = [e("a", "acme/foo@^1", Ok(foo20), 2), e("b", "acme/foo", Err(Unset), 3), e("c", "acme/bar@1.0.0", Ok(foo10), 4), e("d", "acme/foo@1.0.0", Ok(foo11), 5), e("e", "acme/foo@^1", Ok(foo11), 6)]
	check(ok) == "ok" and check([]) == "ok" and check(bad) == "14 the [tools] of /p/talon.toml are not locked: tools.a: the url has the version 2.0.0, which the ref acme/foo@^1 does not admit; tools.b has no url; tools.c: the url is of acme/foo, the ref is of acme/bar; tools.d: the url has the version 1.1.0, which the ref acme/foo@1.0.0 does not admit"
}

# R-PT4, R-DT4, R-PT3, R-PT5, R-UP5: the pure steps of the release choice and of the `ref` that a command writes. A snapshot hides a release that was published after it. `add` writes the selector as typed, or `^<version>`. `upgrade` moves the range to the new version, and a range with no form is a note.
expect {
	cand = |url, at| match Ident.of_url(url) {
		Ok(ident) => { url, ident, tag: ident.version, published_at: at, size: 1 }
		Err(_) => crash "bad url"
	}
	list = [cand(foo20, 300), cand(foo11, 200), cand(foo10, 100)]
	shown = |snapshot| ToolsPlan.visible({ list, snapshot }).map(|c| c.ident.version)
	sel_of = |phase, ref| ToolsPlan.selector_for({ phase, ref })
	add = |selector, version| ToolsPlan.add_ref({ name: "acme/foo", selector, version })
	up = |ref, version| ToolsPlan.upgrade_ref({ ref, version })
	shown(Err(None)) == ["2.0.0", "1.1.0", "1.0.0"] and shown(Ok(200)) == ["1.1.0", "1.0.0"] and shown(Ok(99)) == [] and sel_of(Update, "acme/foo@^1") == Ok(Range("^1")) and sel_of(Install, "acme/foo") == Err(None) and sel_of(Install, "acme/foo@latest") == Ok(Latest) and sel_of(Upgrade, "acme/foo@^1") == Err(None) and add(Err(None), "1.1.0") == "acme/foo@^1.1.0" and add(Ok(Latest), "1.1.0") == "acme/foo@latest" and add(Ok(Exact("1.0.0")), "1.1.0") == "acme/foo@1.0.0" and add(Ok(Range("^1")), "1.1.0") == "acme/foo@^1" and up("acme/foo@^1", "2.0.0") == Ok("acme/foo@^2") and up("acme/foo@^1", "1.2.0") == Ok("acme/foo@^1") and up("acme/foo@1.0.0", "2.0.0") == Ok("acme/foo@2.0.0") and up("acme/foo", "2.0.0") == Ok("acme/foo") and up("acme/foo@>=1.0, <1.5", "2.0.0") == Err(NoForm) and ToolsPlan.stuck_note({ key: "foo", ref: "acme/foo@>=1.0, <1.5", version: "2.0.0" }) == "tools.foo: the range >=1.0, <1.5 does not admit 2.0.0, change it by hand"
}

# R-PT6, R-PT9, R-B9: the `x` entry of a project tool. The bundle hash and the target must be equal, the entry needs its binary and a release source. A nightly, other hashes and the version do not matter. With more than one, the latest `last_run` wins, then the first dir.
expect {
	found = |dir, bundle, target, last_run, has_bin, source| { dir, entry: { name: "acme/foo", source, hashes: [], nightly: "nightly-2026-10-14-38a3029", target, sha256: "", libs: [], bundle, last_run }, has_bin }
	rel = Release({ version: "1.1.0", url: foo11 })
	git = Git({ commit: "dd03c09e5f0a3b6c7d8e9f001122334455667788", ref: "main" })
	t1 = "2026-10-01T00:00:00Z"
	t2 = "2026-10-02T00:00:00Z"
	pick = |entries, bundle, target| match ToolsPlan.cached({ entries, bundle, target }) {
		Ok(f) => f.dir
		Err(None) => "none"
	}
	entries = [
		found("/x/1", h_foo11, "x64musl", t1, Bool.True, rel),
		found("/x/2", h_foo11, "x64musl", t2, Bool.True, rel),
		found("/x/3", h_foo11, "x64musl", t2, Bool.True, rel),
		found("/x/4", h_foo11, "arm64musl", "2026-11-01T00:00:00Z", Bool.True, rel),
		found("/x/5", h_foo11, "x64musl", "2026-11-01T00:00:00Z", Bool.False, rel),
		found("/x/6", h_foo11, "x64musl", "2026-11-01T00:00:00Z", Bool.True, git),
		found("/x/7", h_foo10, "x64musl", "2026-11-01T00:00:00Z", Bool.True, rel),
	]
	pick(entries, h_foo11, "x64musl") == "/x/2" and pick(entries, h_foo11, "arm64musl") == "/x/4" and pick(entries, h_foo20, "x64musl") == "none" and pick(entries, h_foo10, "arm64musl") == "none" and pick([], h_foo11, "x64musl") == "none"
}

# R-PT14, R-PD9, R-B4 (NC3): the `talon.toml` files that GC and the take-over read, and the hashes. A header file gives the `talon.toml` of its directory and of each parent. A `talon.toml` entry is read itself. The walk stops at the first file with `[workspace]`. A text that is no TOML, an entry with no `url` or with a URL that is no release gives nothing.
expect {
	tools = |urls| "[tools]\n${Str.join_with(urls.map_with_index(|u, i| "t${i.to_str()} = { ref = \"acme/foo\", url = \"${u}\" }"), "\n")}\n"
	reads = [
		{ path: "/w/talon.toml", text: "[workspace]\nmembers = [\"a/main.roc\"]\n\n${tools([foo11, bar10])}" },
		{ path: "/w/a/talon.toml", text: "[dependencies]\njson = \"^1\"\n" },
		{ path: "/s/talon.toml", text: tools([foo10, "https://example.com/x.tar.zst"]) },
		{ path: "/t/talon.toml", text: "not toml [[[" },
		{ path: "/u/talon.toml", text: "[tools]\nx = { ref = \"acme/foo\" }\n" },
		{ path: "/up/talon.toml", text: tools([foo20]) },
		{ path: "/talon.toml", text: tools([foo20]) },
	]
	paths = ToolsPlan.held_paths({ files: ["/w/a/main.roc", "/t/talon.toml"] })
	by = |files| ToolsPlan.held_hashes({ files, reads })
	paths == ["/t/talon.toml", "/talon.toml", "/w/a/talon.toml", "/w/talon.toml"] and by(["/w/a/main.roc"]) == [h_bar10, h_foo11] and by(["/s/p/main.roc"]) == [h_foo10, h_foo20] and by(["/t/talon.toml", "/u/main.roc"]) == [h_foo20] and by(["/up/app/main.roc", "/s/talon.toml"]) == [h_foo10, h_foo20] and by([]) == []
}

# R-PT3, R-PT5, R-OUT2 (proposals, TW24), D8 of the review: the lines of the tool changes (with the line `would build` of `--dry-run`) and of the file, and the `data` of `--json` (with `would_build`).
expect {
	a = { key: "foo", name: "acme/foo", version: "1.1.0" }
	lines_ok = [
		ToolsPlan.line(Added(a)) == "added tool foo 1.1.0 (acme/foo)",
		ToolsPlan.line(Locked(a)) == "locked tool foo 1.1.0 (acme/foo)",
		ToolsPlan.line(Moved({ key: "foo", name: "acme/foo", old: "1.0.0", version: "1.1.0" })) == "moved tool foo 1.0.0 to 1.1.0 (acme/foo)",
		ToolsPlan.line(Built(a)) == "built tool foo 1.1.0 (acme/foo)",
		ToolsPlan.line(WouldBuild(a)) == "would build tool foo 1.1.0 (acme/foo)",
		ToolsPlan.line(Removed({ key: "foo", name: "acme/foo" })) == "removed tool foo (acme/foo)",
		ToolsPlan.file_line({ path: "/p/talon.toml", key: "foo", entry: Ok({ ref: "acme/foo@^1", url: foo11 }) }) == "/p/talon.toml: tools.foo = { ref = \"acme/foo@^1\", url = \"${foo11}\" }",
		ToolsPlan.file_line({ path: "/p/talon.toml", key: "foo", entry: Err(Removed) }) == "/p/talon.toml: tools.foo removed",
	]
	row = { key: "foo", name: "acme/foo", action: "moved", ref: Ok("acme/foo@^1"), url: Ok(foo11), version: Ok("1.1.0"), previous: Ok("1.0.0"), file: "/p/talon.toml", built: Bool.True, would_build: Bool.False }
	gone = { key: "bar", name: "acme/bar", action: "removed", ref: Err(None), url: Err(None), version: Err(None), previous: Err(None), file: "/p/talon.toml", built: Bool.False, would_build: Bool.True }
	json = ToolsPlan.data([row, gone]).render()
	lines_ok.all(|ok| ok) and json == "{\"tools\":[{\"key\":\"foo\",\"name\":\"acme/foo\",\"action\":\"moved\",\"ref\":\"acme/foo@^1\",\"url\":\"${foo11}\",\"version\":\"1.1.0\",\"previous\":\"1.0.0\",\"file\":\"/p/talon.toml\",\"built\":true,\"would_build\":false},{\"key\":\"bar\",\"name\":\"acme/bar\",\"action\":\"removed\",\"ref\":null,\"url\":null,\"version\":null,\"previous\":null,\"file\":\"/p/talon.toml\",\"built\":false,\"would_build\":true}]}"
}

# R-FL7, R-FL12, R-PT3, R-PT5: the line with `--tool`. The flags that the command allows besides `--snapshot`, `--dry-run` and `--allow-downloads` are exit code 2. `add` takes one `owner/app` with no git ref. The operands of the other commands are keys of `[tools]`.
expect {
	run = |words| match Args.parse(words) {
		Err(_) => "parse"
		Ok(args) => match ToolsCmd.read(args) {
			Ok(c) => "ok ${Str.inspect(c.op)} keys=${Str.join_with(c.keys, ",")} as=${c.as_key ?? "-"} dry=${Str.inspect(c.dry_run)} snap=${c.snapshot ?? "-"}"
			Err(e) => "${e.kind.code().to_str()} ${e.message}"
		}
	}
	rows = [
		(["add", "--tool", "acme/foo"], "ok Add keys= as=- dry=False snap=-"),
		(["install", "--tool", "acme/foo@^1", "--as", "f", "--dry-run", "--snapshot", "2026-09-01T00:00:00Z"], "ok Add keys= as=f dry=True snap=2026-09-01T00:00:00Z"),
		(["rm", "--tool", "a", "b"], "ok Remove keys=a,b as=- dry=False snap=-"),
		(["update", "--tool"], "ok Update keys= as=- dry=False snap=-"),
		(["up", "--tool", "a"], "ok Update keys=a as=- dry=False snap=-"),
		(["upgrade", "--tool", "a", "--allow-downloads"], "ok Upgrade keys=a as=- dry=False snap=-"),
		(["add", "--tool", "acme/foo", "--no-pin"], "2 flag '--no-pin' is not for tln add --tool. It takes only --as, --snapshot, --dry-run and --allow-downloads"),
		(["update", "--tool", "--no-check"], "2 flag '--no-check' is not for tln update --tool. It takes only --snapshot, --dry-run and --allow-downloads"),
		(["add", "--tool"], "2 tln add --tool needs one app: owner/app"),
		(["add", "--tool", "acme/foo", "acme/bar"], "2 tln add --tool takes one app, got 2"),
		(["add", "--tool", "foo"], "2 'foo' is not an owner/app name: tln add --tool needs the full name"),
		(["add", "--tool", "acme/foo@dd03c09e"], "2 'dd03c09e' in 'acme/foo@dd03c09e' is not a release selector (a version, a range or latest)"),
		(["add", "--tool", "acme/foo", "--as", "Foo"], "2 'Foo' is not a key of [tools]: use lower case letters, digits, '.', '_' and '-', and start with a letter or a digit"),
		(["remove", "--tool"], "2 tln remove --tool needs a key of [tools]"),
		(["update", "--tool", "acme/foo@1"], "2 'acme/foo@1' is not a key of [tools]: use lower case letters, digits, '.', '_' and '-', and start with a letter or a digit"),
	]
	rows.all(|(words, want)| run(words) == want)
}

# R-PT3, R-T28, R-FL12: the key of a new tool is `--as`, else the binary name of the app. A name that is not a key (a capital) needs `--as`. A key that exists with another app is exit code 2. `op_of` is `Err(NoTool)` for a line with no `--tool`, and `Args` accepts `--tool` for 4 commands only.
expect {
	key = |as_key, name| match ToolsCmd.key_of({ as_key, name }) {
		Ok(k) => k
		Err(e) => "${e.kind.code().to_str()} ${e.message}"
	}
	op = |words| match Args.parse(words) {
		Ok(args) => match ToolsCmd.op_of(args) {
			Ok(o) => Str.inspect(o)
			Err(NoTool) => "none"
		}
		Err(_) => "parse"
	}
	taken = ToolsCmd.key_taken({ path: "/p/talon.toml", key: "foo", other: "acme/other" })
	none = ToolsCmd.no_key({ path: "/p/talon.toml", key: "zed", keys: ["a", "b"] })
	key(Err(Unset), "Karakatiza666/roc-cloudflare-workers-cli") == "roc-cloudflare-workers-cli" and key(Ok("cfw"), "acme/Foo") == "cfw" and key(Err(Unset), "acme/Foo") == "2 the binary name 'Foo' of acme/Foo is not a key of [tools]. Pass --as <key>" and taken.message == "foo is a tool of acme/other in /p/talon.toml. Pass --as <key> for another key, or run: tln remove --tool foo" and none.message == "no key 'zed' in [tools] of /p/talon.toml. Keys: a, b." and op(["install"]) == "none" and op(["add", "--tool", "acme/foo"]) == "Add" and op(["update", "--tool"]) == "Update" and op(["upgrade", "--tool"]) == "Upgrade" and op(["list", "--tool"]) == "parse" and op(["tool", "install", "--tool", "a/b"]) == "parse"
}

# R-PD12, R-PD13, R-PT14 (NC3): a known project that is a `talon.toml` (the entry of `tln run` or `tln x <key>`, R-PD9) has no header. It is live while its file is there and was used in the GC age, so its `[tools]` count. A missing file or an old entry goes. A file that cannot be read is not judged.
expect {
	now = 1000000
	age = 100
	entries = [
		{ path: "/p/talon.toml", last_use: now - 10 },
		{ path: "/q/talon.toml", last_use: now - 10 },
		{ path: "/r/talon.toml", last_use: now - 1000 },
		{ path: "/s/talon.toml", last_use: now - 10 },
		{ path: "/t/main.roc", last_use: now - 10 },
	]
	reads = [Ok("[tools]\nx = { ref = \"acme/foo\" }\n"), Err(NotFound), Ok("[tools]\n"), Err(Denied), Ok("[tools]\n")]
	got = Gc.projects({ entries, reads, now, age })
	got.live.map(|p| p.path) == ["/p/talon.toml", "/s/talon.toml"] and got.gone == ["/q/talon.toml", "/r/talon.toml", "/t/main.roc"]
}

# R-DL4, R-DL5, R-DL7, R-PT6 (Q-A, D8 and Q3 of the review): the compiler stop of a project tool names the flags that the command takes (`--allow-downloads`, `TALON_AUTO_INSTALL=yes`), not `--roc pinned`. Another failure stays as it is. `--allow-downloads` puts `TALON_AUTO_INSTALL=yes` first in the environment of the build, so it wins over the variable. The search for a project file that found none is the failure that `add --tool` turns into a `talon.toml` in the current directory.
expect {
	stop = ToolInstall.consent_stop("nightly-2026-10-12-2664a27")
	mapped = ToolsPlan.compiler_stop(stop)
	other = Fail.new(Consent, "the compiler nightly-2026-10-12-2664a27 is not installed. Run: tln roc install nightly-2026-10-12-2664a27.")
	usage = Fail.new(Usage, "x")
	env = [("HOME", "/h"), ("TALON_AUTO_INSTALL", "no")]
	auto = |list| Consent.auto_install(list)
	found = Fail.new(Usage, "no project file found. Checked: /a, /b. Pass --file <path>.")
	no_file = Fail.new(Usage, "no project file found. Pass --file <path>.")
	mapped.kind == Consent and mapped.message == "the compiler nightly-2026-10-12-2664a27 is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes." and ToolsPlan.compiler_stop(other).message == other.message and ToolsPlan.compiler_stop(usage).message == "x" and ToolsPlan.build_env({ env, allow: Bool.False }) == env and ToolsPlan.build_env({ env, allow: Bool.True }) == [("TALON_AUTO_INSTALL", "yes"), ("HOME", "/h"), ("TALON_AUTO_INSTALL", "no")] and auto(ToolsPlan.build_env({ env, allow: Bool.True })) == Yes and auto(ToolsPlan.build_env({ env, allow: Bool.False })) == No and ToolsPlan.no_project(found) and !ToolsPlan.no_project(no_file) and !ToolsPlan.no_project(Fail.new(Input, "no project file found. Checked: /a."))
}

# R-PT14, R-PD13 (gap test of slice 056, decision C13): GC never judges the form of an entry. An entry with a `ref` that is no string, or a `ref` that is no ref, still has a `url`, so its build is kept (GC keeps more, never less). `Intent.read` refuses the same file (exit code 19), so the entry never reaches a command. An entry with no `url` and an entry with a `url` that is not a release give no hash.
expect {
	text = "[tools]\na = { ref = 5, url = \"${foo11}\" }\nb = { ref = \"not a ref!\", url = \"${foo10}\" }\nc = { ref = \"acme/foo\" }\nd = { ref = \"acme/foo\", url = \"https://example.com/x.tar.zst\" }\n"
	reads = [{ path: "/g/talon.toml", text }]
	refused = match Intent.read({ path: "/g/talon.toml", text, role: Root }) {
		Err(fail) => fail.kind.code()
		Ok(_) => 0
	}
	ToolsPlan.held_hashes({ files: ["/g/talon.toml"], reads }) == [h_foo11, h_foo10] and refused == 19
}

# R-PT5 (slice 073, 056 Q2): a selector on a key of `[tools]` (`update foo@^2`, `upgrade foo@latest`) is exit code 2 and names `tln add --tool owner/app@<sel>`, which changes the `ref` (R-PT3). The selector is the text after the first `@`. A name that is no key keeps its old way: a header alias with a selector, an unknown
# name, and a full name `owner/app@sel` (a full name is no key) go to the header. The first name that fails gives the failure, also after names that are good. The failure is the same for `update` and `upgrade`. The text is a proposal (TW24). A name that is an alias and a key with a selector is also exit code 2 (the text of the alias rule or this one: not pinned).
expect {
	split = |command, names| match ToolsPlan.split({ command, names, keys: ["fmt", "foo"], aliases: ["json"] }) {
		Ok(s) => Ok((s.header, s.tools))
		Err(e) => Err(e.line())
	}
	stop = |name, sel| Err("tln: error[usage]: '${name}' is a selector on the [tools] key '${name.drop_suffix("@${sel}")}'. A selector changes its ref: run tln add --tool owner/app@${sel}")
	split("update", ["fmt@^2"]) == stop("fmt@^2", "^2")
		and split("upgrade", ["foo@latest"]) == stop("foo@latest", "latest")
			and split("update", ["json@^2", "fmt", "foo@1.0.0", "fmt@^2"]) == stop("foo@1.0.0", "1.0.0")
				and split("update", ["json@^2", "acme/fmt@^2", "zed@1", "fmt"]) == Ok((["json@^2", "acme/fmt@^2", "zed@1"], ["fmt"]))
					and split("upgrade", ["fmt", "foo"]) == Ok(([], ["fmt", "foo"]))
}

# R-PT5, R-OUT4, R-J3 (slice 073): the `data` of `--json` of `install`, `update` and `upgrade` has the key `tools` after the keys of the header flow, with one row for each entry that the tools step handled (the rows of `--tool`, an entry that did not change has the action `kept`). With no row the `data` has no `tools` key.
expect {
	base = Obj([("snapshot", Text("2026-10-15T12:00:00Z")), ("written", Arr([Text("/p/talon.toml")]))])
	moved = { key: "foo", name: "acme/foo", action: "moved", ref: Ok("acme/foo@^2"), url: Ok(foo20), version: Ok("2.0.0"), previous: Ok("1.1.0"), file: "/p/talon.toml", built: Bool.False, would_build: Bool.False }
	kept = { key: "bar", name: "acme/bar", action: "kept", ref: Ok("acme/bar@1.0.0"), url: Ok(foo10), version: Ok("1.0.0"), previous: Err(None), file: "/p/talon.toml", built: Bool.False, would_build: Bool.False }
	head = "{\"snapshot\":\"2026-10-15T12:00:00Z\",\"written\":[\"/p/talon.toml\"]"
	rows = ToolsPlan.with_tools({ base, rows: [moved, kept] }).render()
	one = ToolsPlan.with_tools({ base, rows: [kept] }).render()
	none = ToolsPlan.with_tools({ base, rows: [] }).render()
	rows == "${head},\"tools\":[{\"key\":\"foo\",\"name\":\"acme/foo\",\"action\":\"moved\",\"ref\":\"acme/foo@^2\",\"url\":\"${foo20}\",\"version\":\"2.0.0\",\"previous\":\"1.1.0\",\"file\":\"/p/talon.toml\",\"built\":false,\"would_build\":false},{\"key\":\"bar\",\"name\":\"acme/bar\",\"action\":\"kept\",\"ref\":\"acme/bar@1.0.0\",\"url\":\"${foo10}\",\"version\":\"1.0.0\",\"previous\":null,\"file\":\"/p/talon.toml\",\"built\":false,\"would_build\":false}]}"
		and one == "${head},\"tools\":[{\"key\":\"bar\",\"name\":\"acme/bar\",\"action\":\"kept\",\"ref\":\"acme/bar@1.0.0\",\"url\":\"${foo10}\",\"version\":\"1.0.0\",\"previous\":null,\"file\":\"/p/talon.toml\",\"built\":false,\"would_build\":false}]}"
			and none == "${head}}"
}

# R-B10, R-X2 (slice 073): an entry dir has the binary when it holds the file that the manifest names: a file, not a directory, with exactly the name that `XCache.layout` gives (the repo of the full name, `.exe` on Windows only). The file `manifest.json`, another file, a directory with the name, the name with the wrong suffix for the system, and a dir that cannot be listed are no binary.
expect {
	file = |name| { name, is_dir: Bool.False, mtime: 1 }
	dir = |name| { name, is_dir: Bool.True, mtime: 1 }
	holds = |names, want| XCacheIo.has_file(Ok(names), want)
	holds([file("manifest.json"), file("fmt")], "fmt")
		and holds([file("fmt.exe"), file("manifest.json")], "fmt.exe")
			and !holds([file("manifest.json")], "fmt")
				and !holds([file("manifest.json"), file("other")], "fmt")
					and !holds([file("manifest.json"), dir("fmt")], "fmt")
						and !holds([file("manifest.json"), file("fmt.exe")], "fmt")
							and !holds([file("manifest.json"), file("fmt")], "fmt.exe")
								and !holds([], "fmt")
									and !XCacheIo.has_file(Err(NotFound), "fmt")
										and !XCacheIo.has_file(Err(Denied), "fmt")
}
