import lib.Db
import lib.JsonDoc
import lib.ToolManage
import lib.ToolsJson

ToolnewerTest :: [].{}

# Slice 232 (docs/slices/232-unknown-tool-kind.md), R-TF8 R-TF6 R-TF7 R-TF2 R-EC19, Design Q607.
# The names `ToolsJson.Newer`, `ToolsJson.Item`, `ToolsJson.items`, `ToolsJson.newer_for`, `ToolsJson.newer_fail`, `ToolsJson.talon_repair`, `ToolManage.ls_report_items`, `ToolManage.ls_data_items` and
# `ToolManage.newer_warning` are proposals: until the code agent adds them this file does not compile (red on purpose, as slice 231). The texts are proposals (TW24).

path = "/d/talon/tools.json"

# The tool of the rows of `tool list` and of `put`: a release tool.
t_foo : ToolsJson.Tool
t_foo = { key: "foo", name: "acme/foo", source: Release({ version: "1.1.0", url: "u" }), path: Err(None), hashes: [], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S1", libs: [], installed_at: "2026-10-01T10:00:00Z" }

t_put : ToolsJson.Tool
t_put = { key: "foo", name: "acme/foo", source: Release({ version: "1.2.0", url: "https://x/foo2.tar.zst" }), path: Err(None), hashes: ["H1"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S1", libs: [], installed_at: "2026-10-15T12:00:00Z" }

fresh : ToolsJson.Talon
fresh = { source: Prebuilt({ version: "0.0.1", url: "https://h/v0.0.1/tln-x64musl" }), hashes: [], nightly: "", target: "x64musl", sha256: "S", libs: [], installed_at: "2026-10-22T12:00:00Z" }

hint = "A newer tln may know this value. Update tln: tln tool update talon"

foo_doc : Str
foo_doc = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"https://x/foo.tar.zst\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-01T10:00:00Z\"}"

g_doc : Str
g_doc = "{\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"commit\":\"aaaaaaaa5e8a\",\"ref\":\"main\"},\"build\":{\"hashes\":[],\"nightly\":\"nightly-2026-10-11-1a2b3c4\",\"target\":\"x64musl\"},\"sha256\":\"S2\",\"libs\":[],\"installed_at\":\"2026-09-02T08:00:00Z\"}"

# An entry with a source kind that this tln does not know, with a field and a member that it does not know either.
zed_doc : Str
zed_doc = "{\"name\":\"acme/zed\",\"source\":{\"kind\":\"zzz\",\"tag\":\"v9\"},\"future\":[1,2]}"

whole : Str -> Str
whole = |tools| "{\"format\":1,\"tools\":{${tools}}}"

# The items of a text as short lines: `known <key>` or `newer <key> <name> <kind>`. A failure is its line.
shown_items : Str -> Try(List(Str), Str)
shown_items = |text| match ToolsJson.items({ path, text: Ok(text) }) {
	Ok(items) => Ok(
		items.map(
			|item| match item {
				Known(tool) => "known ${tool.key}"
				Newer(n) => "newer ${n.key} ${n.name} ${n.kind}"
			},
		),
	)
	Err(fail) => Err(fail.line())
}

input = |what| Err("tln: error[input]: ${path}: ${what}")

# R-TF8 R-TF2 R-TF6: an entry with a source kind that is a word this tln does not know is a `Newer` item, in the place of the file. A known kind with a missing member is not: it is a bad file (R-TF6, exit 19, no hint).
# The kind must be a text (a number is no enum word). A kind word is an exact word (`Release` is not `release`). The checks of the entry come in the order object, name, source: an unknown kind with no name is a bad file.
expect {
	rows = [
		("known and unknown, in the order of the file", shown_items(whole("\"foo\":${foo_doc},\"zed\":${zed_doc},\"g\":${g_doc}")), Ok(["known foo", "newer zed acme/zed zzz", "known g"])),
		("the key talon is no item", shown_items(whole("\"talon\":${zed_doc},\"zed\":${zed_doc}")), Ok(["newer zed acme/zed zzz"])),
		("a kind in another case is another word", shown_items(whole("\"zed\":{\"name\":\"acme/zed\",\"source\":{\"kind\":\"Release\",\"version\":\"1\",\"url\":\"u\"}}")), Ok(["newer zed acme/zed Release"])),
		("the kind of the talon entry, prebuilt, is a word that a tool does not know", shown_items(whole("\"zed\":{\"name\":\"acme/zed\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"1\",\"url\":\"u\"}}")), Ok(["newer zed acme/zed prebuilt"])),
		("release with no version", shown_items(whole("\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"url\":\"u\"}}")), input("tool foo: has no source that tln knows")),
		("release with no url", shown_items(whole("\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1\"}}")), input("tool foo: has no source that tln knows")),
		("git with no commit", shown_items(whole("\"g\":{\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"ref\":\"main\"}}")), input("tool g: has no source that tln knows")),
		("git with no ref", shown_items(whole("\"g\":{\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"commit\":\"c\"}}")), input("tool g: has no source that tln knows")),
		("a source with no kind", shown_items(whole("\"foo\":{\"name\":\"acme/foo\",\"source\":{\"version\":\"1\"}}")), input("tool foo: has no source that tln knows")),
		("a kind that is a number", shown_items(whole("\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":5}}")), input("tool foo: has no source that tln knows")),
		("a source that is no object", shown_items(whole("\"foo\":{\"name\":\"acme/foo\",\"source\":\"zzz\"}")), input("tool foo: has no source that tln knows")),
		("no source", shown_items(whole("\"foo\":{\"name\":\"acme/foo\"}")), input("tool foo: has no source that tln knows")),
		("an unknown kind and no name", shown_items(whole("\"zed\":{\"source\":{\"kind\":\"zzz\"}}")), input("tool zed: has no name")),
		("an entry that is no object", shown_items(whole("\"zed\":3")), input("tool zed: is not an object")),
		("a bad entry after an unknown one still fails the file", shown_items(whole("\"zed\":${zed_doc},\"foo\":{\"name\":\"acme/foo\"}")), input("tool foo: has no source that tln knows")),
		("a bad entry before an unknown one fails the file", shown_items(whole("\"foo\":{\"name\":\"acme/foo\"},\"zed\":${zed_doc}")), input("tool foo: has no source that tln knows")),
		("a missing file", ToolsJson.items({ path, text: Err(NotFound) }).map_ok(|items| items.map(|_| "item")).map_err(|fail| fail.line()), Ok([])),
		("no tools field", shown_items("{\"format\":1}"), Ok([])),
		("a newer format", shown_items("{\"format\":2,\"tools\":{}}"), input("format 2 is newer than this tln (format 1). Run: tln tool update talon")),
		("not json", shown_items("not json"), input("the content does not parse")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TF8: `read` and `manifest` (the readers of the commands that work on the tools that tln knows) leave a `Newer` item out and fail only for a bad file. They give the known tools in the order of the file.
expect {
	text = whole("\"foo\":${foo_doc},\"zed\":${zed_doc},\"g\":${g_doc}")
	read = match ToolsJson.read({ path, text: Ok(text) }) {
		Ok(entries) => Ok(entries.map(|e| e.key))
		Err(fail) => Err(fail.line())
	}
	manifest = match ToolsJson.manifest({ path, text: Ok(text) }) {
		Ok(tools) => Ok(tools.map(|t| t.key))
		Err(fail) => Err(fail.line())
	}
	bad_member = match ToolsJson.read({ path, text: Ok(whole("\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"url\":\"u\"}},\"zed\":${zed_doc}")) }) {
		Ok(_) => Ok(0)
		Err(fail) => Err(fail.line())
	}
	read == Ok(["foo", "g"]) and manifest == Ok(["foo", "g"]) and bad_member == input("tool foo: has no source that tln knows")
}

# R-TF8 R-TF2: the file that tln writes keeps a `Newer` item as it is, in its place, with the fields and members that tln does not know: after a `put` of another tool (a new tool is the last, a replaced tool stays in its place), after a `drop` of
# another tool, and after `put_talon`. The text of the item is the same bytes.
expect {
	t_new = { ..t_put, key: "bar", name: "acme/bar" }
	put = |text, tool| match ToolsJson.put({ path, text: Ok(text), tool }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	drop = |text, key| match ToolsJson.drop({ path, text: Ok(text), key }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	before = whole("\"foo\":${foo_doc},\"zed\":${zed_doc},\"g\":${g_doc}")
	replaced_foo = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.2.0\",\"url\":\"https://x/foo2.tar.zst\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}"
	bar_doc = "{\"name\":\"acme/bar\",\"source\":{\"kind\":\"release\",\"version\":\"1.2.0\",\"url\":\"https://x/foo2.tar.zst\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}"
	rows = [
		(put(before, t_new), whole("\"foo\":${foo_doc},\"zed\":${zed_doc},\"g\":${g_doc},\"bar\":${bar_doc}")),
		(put(before, t_put), whole("\"foo\":${replaced_foo},\"zed\":${zed_doc},\"g\":${g_doc}")),
		(drop(before, "foo"), whole("\"zed\":${zed_doc},\"g\":${g_doc}")),
		(drop(before, "g"), whole("\"foo\":${foo_doc},\"zed\":${zed_doc}")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-TF8: which `Newer` item a command targets. The operand is the key (the binary name) or the full name, exactly. A known tool and the key `talon` are never a hit. An operand that no `Newer` item has is `Err(None)`.
expect {
	items : List(ToolsJson.Item)
	items = match ToolsJson.items({ path, text: Ok(whole("\"foo\":${foo_doc},\"zed\":${zed_doc},\"q\":{\"name\":\"other/q\",\"source\":{\"kind\":\"qqq\"}}")) }) {
		Ok(found) => found
		Err(_) => []
	}
	hit = |ref| match ToolsJson.newer_for({ items, ref }) {
		Ok(n) => Ok("${n.key} ${n.name} ${n.kind}")
		Err(None) => Err(None)
	}
	rows = [
		(hit("zed"), Ok("zed acme/zed zzz")),
		(hit("acme/zed"), Ok("zed acme/zed zzz")),
		(hit("q"), Ok("q other/q qqq")),
		(hit("other/q"), Ok("q other/q qqq")),
		(hit("foo"), Err(None)),
		(hit("acme/foo"), Err(None)),
		(hit("Zed"), Err(None)),
		(hit("acme/ze"), Err(None)),
		(hit("talon"), Err(None)),
		(hit(""), Err(None)),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == [] and ToolsJson.newer_for({ items: [], ref: "zed" }) == Err(None)
}

# R-TF8 R-EC19: the failure of a command that targets a `Newer` item: kind input (exit 19), the file, the key, the kind, and the hint line of slice 231 as the second line.
expect {
	fail = ToolsJson.newer_fail({ path, item: { key: "zed", name: "acme/zed", kind: "zzz" } })
	fail.kind.code() == 19 and fail.message == "${path}: tool zed: source kind \"zzz\" needs a newer tln\n${hint}" and fail.line() == "tln: error[input]: ${path}: tool zed: source kind \"zzz\" needs a newer tln\n${hint}"
}

# R-TF8: `tool update` with no operand skips a `Newer` item with a warning (one line, no hint).
expect {
	ToolManage.newer_warning({ key: "zed", name: "acme/zed", kind: "zzz" }) == "warning: tool zed: source kind \"zzz\" needs a newer tln, skipped"
}

# R-TF8 R-T4: `tool list` shows a `Newer` item as a row in its place: the key, the name, the source cell `needs a newer tln (source kind <kind>)`, and `-` for the compiler, the target, the date and the libraries. Known rows are as before.
# With only `Newer` items there are rows (the line of no tool is for no item at all). `--json`: an object `tool`, `name`, `source` (`kind` only) and `needs_newer_tln` true; a known tool has the same object as before.
expect {
	zed : ToolsJson.Item
	zed = Newer({ key: "zed", name: "acme/zed", kind: "zzz" })
	both : List(ToolsJson.Item)
	both = [Known(t_foo), zed]
	only : List(ToolsJson.Item)
	only = [zed]
	none : List(ToolsJson.Item)
	none = []
	render = |items| JsonDoc.render(ToolManage.ls_data_items(items))
	rows = [
		(Str.inspect(ToolManage.ls_report_items(both)), Str.inspect({ stdout: ["TOOL  NAME      SOURCE                               COMPILER                    TARGET   INSTALLED\n", "foo   acme/foo  1.1.0                                nightly-2026-10-14-38a3029  x64musl  2026-10-01\n", "zed   acme/zed  needs a newer tln (source kind zzz)  -                           -        -\n"], stderr: [] })),
		(Str.inspect(ToolManage.ls_report_items(only)), Str.inspect({ stdout: ["TOOL  NAME      SOURCE                               COMPILER  TARGET  INSTALLED\n", "zed   acme/zed  needs a newer tln (source kind zzz)  -         -       -\n"], stderr: [] })),
		(Str.inspect(ToolManage.ls_report_items(none)), Str.inspect({ stdout: ["no tool is installed. Run: tln tool install owner/app\n"], stderr: [] })),
		(Str.inspect(ToolManage.ls_report_items([Known(t_foo)])), Str.inspect(ToolManage.ls_report([t_foo]))),
		(render(both), "{\"tools\":[${JsonDoc.render(tools_first(ToolManage.ls_data([t_foo])))},{\"tool\":\"zed\",\"name\":\"acme/zed\",\"source\":{\"kind\":\"zzz\"},\"needs_newer_tln\":true}]}"),
		(render(none), "{\"tools\":[]}"),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (want, got))
	dbg bad
	bad == []
}

# The first tool object of the `data` of `tool list` (the object of a known tool, as slice 048 gives it).
tools_first : JsonDoc -> JsonDoc
tools_first = |doc| match doc {
	Obj([("tools", Arr([first]))]) => first
	_ => Null
}

# R-TF8 R-TF6: the entry `talon`. `ToolsJson.talon` (the reader of `tool update talon`, and of the commands that go through the tools) reads an entry with an unknown source kind as no entry: `Ok(Err(None))`, so `tool update talon`
# never stops on it. A known kind with a missing member, a source that is no object, and an entry that is no object stay exit 19 (R-TF6, no hint).
expect {
	talon = |text| match ToolsJson.talon({ path, text: Ok(text) }) {
		Ok(Ok(_)) => "entry"
		Ok(Err(None)) => "none"
		Err(fail) => fail.line()
	}
	entry = |source| "\"talon\":{\"name\":\"roc-talon/talon\",\"source\":${source}}"
	rows = [
		(talon(whole(entry("{\"kind\":\"zzz\",\"tag\":\"v9\"}"))), "none"),
		(talon(whole(entry("{\"kind\":\"install\"}"))), "none"),
		(talon(whole("${entry("{\"kind\":\"zzz\"}")},\"zed\":${zed_doc}")), "none"),
		(talon(whole(entry("{\"kind\":\"prebuilt\",\"version\":\"0.3.4\",\"url\":\"u\"}"))), "entry"),
		(talon(whole(entry("{\"kind\":\"prebuilt\",\"version\":\"0.3.4\"}"))), "tln: error[input]: ${path}: tool talon: has no source that tln knows"),
		(talon(whole(entry("{\"kind\":\"git\",\"commit\":\"c\"}"))), "tln: error[input]: ${path}: tool talon: has no source that tln knows"),
		(talon(whole(entry("\"install script\""))), "tln: error[input]: ${path}: tool talon: has no source that tln knows"),
		(talon(whole("\"talon\":{\"name\":\"roc-talon/talon\"}")), "tln: error[input]: ${path}: tool talon: has no source that tln knows"),
		(talon(whole("\"talon\":5")), "tln: error[input]: ${path}: tool talon: is not an object"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-TF8 R-IS6 R-TF3: `tln setup` replaces an entry `talon` that it cannot read: the binary that setup installed is the authority. `ToolsJson.talon_repair` is the reader of setup: any fault of the entry (an unknown kind, a missing member,
# a source that is no object, an entry that is no object) is `Ok(Err(None))`, and `put_talon` then writes the new entry in the place of the old one, with the other tools (also a `Newer` item) as they were. A fault of the file stays exit 19:
# not JSON, a newer `format`, `tools` that is no object. A good entry is read as `ToolsJson.talon` reads it.
expect {
	repair = |text| match ToolsJson.talon_repair({ path, text: Ok(text) }) {
		Ok(Ok(_)) => "entry"
		Ok(Err(None)) => "none"
		Err(fail) => fail.line()
	}
	good = "{\"kind\":\"prebuilt\",\"version\":\"0.3.4\",\"url\":\"u\"}"
	rows = [
		(repair(whole("\"talon\":{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"zzz\"}}")), "none"),
		(repair(whole("\"talon\":{\"name\":\"roc-talon/talon\",\"source\":${good}}")), "entry"),
		(repair(whole("\"talon\":{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"0.3.4\"}}")), "none"),
		(repair(whole("\"talon\":{\"source\":\"install script\"}")), "none"),
		(repair(whole("\"talon\":{\"name\":\"roc-talon/talon\"}")), "none"),
		(repair(whole("\"talon\":5")), "none"),
		(repair(whole("\"foo\":${foo_doc}")), "none"),
		(repair("not json"), "tln: error[input]: ${path}: the content does not parse"),
		(repair("{\"format\":2,\"tools\":{}}"), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
		(repair("{\"format\":1,\"tools\":5}"), "tln: error[input]: ${path}: tools is not an object"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

expect {
	fresh_doc = "{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"0.0.1\",\"url\":\"https://h/v0.0.1/tln-x64musl\"},\"build\":{\"hashes\":[],\"nightly\":\"\",\"target\":\"x64musl\"},\"sha256\":\"S\",\"libs\":[],\"installed_at\":\"2026-10-22T12:00:00Z\"}"
	put = |text| match ToolsJson.put_talon({ path, text: Ok(text), talon: fresh }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	old = "\"talon\":{\"name\":\"roc-talon/talon\",\"source\":{\"kind\":\"zzz\",\"tag\":\"v9\"}}"
	rows = [
		(put(whole("${old},\"zed\":${zed_doc},\"g\":${g_doc}")), whole("\"talon\":${fresh_doc},\"zed\":${zed_doc},\"g\":${g_doc}")),
		(put(whole("\"zed\":${zed_doc},${old}")), whole("\"zed\":${zed_doc},\"talon\":${fresh_doc}")),
		(put(whole("\"talon\":{\"name\":\"roc-talon/talon\",\"source\":\"install script\"},\"zed\":${zed_doc}")), whole("\"talon\":${fresh_doc},\"zed\":${zed_doc}")),
		(put(whole("\"talon\":5,\"zed\":${zed_doc}")), whole("\"talon\":${fresh_doc},\"zed\":${zed_doc}")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-TF7 (Design Q607, F11): a row of `compat.db` with a word that this tln does not know (an `outcome` of `smoke`, `share_queue` or `facts`, or a `source` of `pinned`) is no row: the reverse of the text form is `Err(BadLine)` and the word
# is `Err(BadWord)`, so no fact is made from it. A new word is a new column (R-TF2), so a word that a later release writes is always a word of a column that this tln does not read.
expect {
	h = "AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY"
	rows = [
		(Db.outcome_of("timeout") == Err(BadWord), "outcome timeout"),
		(Db.outcome_of("skipped") == Err(BadWord), "outcome skipped"),
		(Db.source_of("github") == Err(BadWord), "source github"),
		(Db.source_of("registry-v2") == Err(BadWord), "source registry-v2"),
		(Db.parse_line("fact\t${h}\tnightly-2026-10-14-38a3029\tany\ttimeout\t\t") == Err(BadLine), "fact timeout"),
		(Db.parse_line("pinned\t1.0.0\tlinux_x86_64\tabc\tregistry-v2") == Err(BadLine), "pinned registry-v2"),
		(Db.smoke_of("${h}\tnightly-2026-10-14-38a3029\tx64musl\ttimeout") == Err(BadLine), "smoke timeout"),
		(Db.queue_of("1\t${h}\tnightly-2026-10-14-38a3029\tx64musl\ttimeout\t0.1.0\t2026-10-15T12:00:00Z") == Err(BadLine), "queue timeout"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}
