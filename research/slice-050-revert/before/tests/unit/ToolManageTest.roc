import lib.Args
import lib.JsonDoc
import lib.Lookup
import lib.ToolManage
import lib.ToolsJson

ToolManageTest :: [].{}

# Slice 048 (docs/slices/048-tool-manage.md): `tln tool list`, `tln tool remove` and the manifest of `tools.json` with all its fields. The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts that the design does not give are the proposals of the slice file (TW24). The Fx calls and the files are in the L2 case `tests/commands/cases/tool/tm1-manage`.

# The two tools of the rows: a release tool and a git tool with `--path`.
foo_url : Str
foo_url = "https://github.com/acme/foo/releases/download/1.1.0/J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr.tar.zst"

commit : Str
commit = "dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8"

t_foo : ToolsJson.Tool
t_foo = { key: "foo", name: "acme/foo", source: Release({ version: "1.1.0", url: foo_url }), path: Err(None), hashes: ["H1"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl", sha256: "S1", libs: [], installed_at: "2026-10-15T12:00:00Z" }

t_g : ToolsJson.Tool
t_g = { key: "g", name: "acme/g", source: Git({ commit, ref: "main" }), path: Ok("apps/cli"), hashes: ["H2", "H3"], nightly: "nightly-2026-09-01-abcdef0", target: "x64musl", sha256: "S2", libs: [], installed_at: "2026-09-02T08:00:00Z" }

foo_doc : Str
foo_doc = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"${foo_url}\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}"

g_doc : Str
g_doc = "{\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"commit\":\"${commit}\",\"ref\":\"main\",\"path\":\"apps/cli\"},\"build\":{\"hashes\":[\"H2\",\"H3\"],\"nightly\":\"nightly-2026-09-01-abcdef0\",\"target\":\"x64musl\"},\"sha256\":\"S2\",\"libs\":[],\"installed_at\":\"2026-09-02T08:00:00Z\"}"

sp : U64 -> Str
sp = |n| Str.repeat(" ", n)

# R-CM16 R-CM19 R-FL12 R-T7 R-T25 R-B6 R-SC3: the line of `tool list`, `tool update`, `tool rebuild` and `tool remove` (the texts of the failures use the long form of the command, R-CM19). `ls` and `rm` are the same commands as `list` and `remove`. `list` takes no name. `remove` takes exactly one tool. `update` and `rebuild` take
# one tool, or none for all tools (R-T25, the rule for `rebuild` with no name is the choice of the slice file, D1). A version is no part of a tool name. `talon` is for slices 050 and 051. `--dry-run`, `--remove-tools` and `--keep-all` are for `tool remove talon` (R-FL12), `--from-source` is for `tool update talon`.
expect {
	cmd = |words| match Args.parse(words) {
		Ok(args) => match ToolManage.read(args) {
			Ok(found) => {
				verb = match found.verb {
					Ls => "ls"
					Update => "update"
					Rebuild => "rebuild"
					Remove => "remove"
				}
				name = match found.ref {
					Ok(ref) => ref.name
					Err(None) => "-"
				}
				"${verb} ${name}"
			}
			Err(fail) => fail.line()
		}
		Err(stop) => "parse: ${stop.fail.line()}"
	}
	line = |text| "tln: error[usage]: ${text}"
	rows = [
		(cmd(["tool", "list"]), "ls -"),
		(cmd(["tool", "ls"]), "ls -"),
		(cmd(["tool", "ls", "foo"]), line("tln tool list takes no tool name, got 1")),
		(cmd(["tool", "remove", "foo"]), "remove foo"),
		(cmd(["tool", "rm", "acme/foo"]), "remove acme/foo"),
		(cmd(["tool", "rm"]), line("tln tool remove needs one tool: tln tool remove <tool>")),
		(cmd(["tool", "rm", "foo", "bar"]), line("tln tool remove takes one tool, got 2")),
		(cmd(["tool", "update"]), "update -"),
		(cmd(["tool", "update", "foo"]), "update foo"),
		(cmd(["tool", "update", "foo", "bar"]), line("tln tool update takes one tool, or none for all tools, got 2")),
		(cmd(["tool", "rebuild"]), "rebuild -"),
		(cmd(["tool", "rebuild", "acme/foo"]), "rebuild acme/foo"),
		(cmd(["tool", "rebuild", "a", "b", "c"]), line("tln tool rebuild takes one tool, or none for all tools, got 3")),
		(cmd(["tool", "update", "foo@1.2.0"]), line("tln tool update takes a tool name, not a version: 'foo@1.2.0'")),
		(cmd(["tool", "rm", "foo@latest"]), line("tln tool remove takes a tool name, not a version: 'foo@latest'")),
		(cmd(["tool", "rebuild", "acme/foo@dd03c09e"]), line("tln tool rebuild takes a tool name, not a version: 'acme/foo@dd03c09e'")),
		(cmd(["tool", "rm", "talon"]), line("tln tool remove talon is not built yet")),
		(cmd(["tool", "update", "talon"]), line("tln tool update talon is not built yet")),
		(cmd(["tool", "rebuild", "roc-talon/talon"]), line("tln tool rebuild talon is not built yet")),
		(cmd(["tool", "rm", "foo", "--dry-run"]), line("tln tool remove --dry-run works only for tln tool remove talon")),
		(cmd(["tool", "rm", "foo", "--keep-all"]), line("tln tool remove --keep-all works only for tln tool remove talon")),
		(cmd(["tool", "rm", "foo", "--remove-tools"]), line("tln tool remove --remove-tools works only for tln tool remove talon")),
		(cmd(["tool", "update", "foo", "--from-source"]), line("tln tool update --from-source works only for tln tool update talon")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-SC3 R-T7: the tool that the lookup found. An installed tool (by its key, `Lookup.Existing`) is the tool. A full name that no tool has (`Lookup.New`) is a failure of kind usage (exit 2). (A short name that no tool has is a failure of the lookup itself, R-AD6.)
expect {
	tools = [t_foo, t_g]
	pick = |found| match ToolManage.pick({ tools, found }) {
		Ok(tool) => tool.key
		Err(fail) => fail.line()
	}
	rows = [
		(pick(Lookup.Existing({ alias: "foo", name: "acme/foo", series: "1" })), "foo"),
		(pick(Lookup.Existing({ alias: "g", name: "acme/g", series: "" })), "g"),
		(pick(Lookup.New("acme/zzz")), "tln: error[usage]: 'acme/zzz' is not an installed tool. tln tool list shows the installed tools."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T4 R-T10 R-T23 R-T27: how a tool says where it came from: the version of a release, `git <ref>@<8 digits of the commit>` of a git tool (the same text in the list, in the reports and in `data`).
expect {
	other = { ..t_g, source: Git({ commit: "abc", ref: "v1.2" }), path: Err(None) }
	rows = [
		(ToolManage.source_text(t_foo), "1.1.0"),
		(ToolManage.source_text(t_g), "git main@dd03c09e"),
		(ToolManage.source_text(other), "git v1.2@abc"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T4 R-T5 R-T8 R-OUT2 (the table is a proposal, TW24): `tool list` prints one line for each tool, in the order of `tools.json`, with the columns TOOL NAME SOURCE COMPILER TARGET INSTALLED (the date of `installed_at`). A git tool with `--path` shows the path after its source text. Each column is as wide as its widest
# cell, the columns are 2 spaces apart, and a line has no space at its end. The column LIBS (R-T8) is there only if a tool has run-time libraries: `-` for a tool with no library. No tool: the line `no tool is installed. Run: tln tool install owner/app`. The table goes to stdout, nothing goes to stderr.
expect {
	both = ToolManage.ls_report([t_foo, t_g])
	libs = ToolManage.ls_report([{ ..t_foo, libs: ["libm.so.6", "libc.so.6"] }, t_g])
	head = "TOOL  NAME      SOURCE${sp(20)}  COMPILER${sp(18)}  TARGET   INSTALLED\n"
	row_foo = "foo   acme/foo  1.1.0${sp(21)}  nightly-2026-10-14-38a3029  x64musl  2026-10-15\n"
	row_g = "g     acme/g    git main@dd03c09e apps/cli  nightly-2026-09-01-abcdef0  x64musl  2026-09-02\n"
	rows = [
		(Str.inspect(both.stdout), Str.inspect([head, row_foo, row_g])),
		(Str.inspect(both.stderr), "[]"),
		(Str.inspect(ToolManage.ls_report([])), Str.inspect({ stdout: ["no tool is installed. Run: tln tool install owner/app\n"], stderr: [] })),
		(Str.inspect(libs.stdout.map(|l| l.ends_with("INSTALLED   LIBS\n"))), "[True, False, False]"),
		(Str.inspect(libs.stdout.map(|l| l.ends_with("2026-10-15  libm.so.6,libc.so.6\n"))), "[False, True, False]"),
		(Str.inspect(libs.stdout.map(|l| l.ends_with("2026-09-02  -\n"))), "[False, False, True]"),
		(Str.inspect(both.stdout.map(|l| l.contains("LIBS"))), "[False, False, False]"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-J3 R-J4 R-OUT4 (the `data` is a proposal, TW24): the `data` of `tool list --json`: `tools`, one object for each tool in the order of the file. The `source` object has the `kind` (`release`: version and url; `git`: commit, ref and, with `--path`, path). No tool: an empty array.
expect {
	render = |tools| JsonDoc.render(ToolManage.ls_data(tools))
	foo_json = "{\"tool\":\"foo\",\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"${foo_url}\"},\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\",\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}"
	g_json = "{\"tool\":\"g\",\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"commit\":\"${commit}\",\"ref\":\"main\",\"path\":\"apps/cli\"},\"nightly\":\"nightly-2026-09-01-abcdef0\",\"target\":\"x64musl\",\"sha256\":\"S2\",\"libs\":[],\"installed_at\":\"2026-09-02T08:00:00Z\"}"
	no_path = "{\"tool\":\"g\",\"name\":\"acme/g\",\"source\":{\"kind\":\"git\",\"commit\":\"${commit}\",\"ref\":\"main\"},\"nightly\":\"nightly-2026-09-01-abcdef0\",\"target\":\"x64musl\",\"sha256\":\"S2\",\"libs\":[\"libm.so.6\"],\"installed_at\":\"2026-09-02T08:00:00Z\"}"
	rows = [
		(render([]), "{\"tools\":[]}"),
		(render([t_foo, t_g]), "{\"tools\":[${foo_json},${g_json}]}"),
		(render([{ ..t_g, path: Err(None), libs: ["libm.so.6"] }]), "{\"tools\":[${no_path}]}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B6 R-ST6 R-ST11: what `tool remove` does with the bin dir entry. No entry: nothing to delete. An entry that is the file that Talon wrote (it has the sha256 of the binary in the data bin dir, R-ST11) is removed. Any other file, a dir, and a file that cannot be read are Keep: Talon does not delete what it did not write (R-ST6). An entry
# when the binary of the tool is gone (`Err(NotFound)`) is not provably Talon's: Keep.
expect {
	rows = [
		(ToolManage.entry_fate({ old: Ok("aa"), have: Absent }), Gone),
		(ToolManage.entry_fate({ old: Err(NotFound), have: Absent }), Gone),
		(ToolManage.entry_fate({ old: Ok("aa"), have: Sha("aa") }), Remove),
		(ToolManage.entry_fate({ old: Ok("aa"), have: Sha("bb") }), Keep),
		(ToolManage.entry_fate({ old: Err(NotFound), have: Sha("bb") }), Keep),
		(ToolManage.entry_fate({ old: Ok("aa"), have: Dir }), Keep),
		(ToolManage.entry_fate({ old: Ok("aa"), have: Unreadable }), Keep),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B6 R-ST6 R-OUT2 R-J3 R-J4 R-OUT4 (the texts and the `data` are proposals, TW24): the answer of `tool remove`: a line, the warning for a kept entry on stderr, and the `data` of `--json` (the keys in this order: tool, name, source, version, removed, kept). A git tool has `version` null.
expect {
	data = |facts| JsonDoc.render(ToolManage.remove_data(facts))
	rows = [
		(ToolManage.remove_report(t_foo), "removed foo 1.1.0 (acme/foo)\n"),
		(ToolManage.remove_report(t_g), "removed g git main@dd03c09e (acme/g)\n"),
		(ToolManage.kept_warning("/h/.local/bin/foo"), "warning: /h/.local/bin/foo is not a file that tln wrote, so tln keeps it"),
		(data({ tool: t_foo, removed: ["/h/.local/bin/foo", "/d/talon/bin/foo"], kept: [] }), "{\"tool\":\"foo\",\"name\":\"acme/foo\",\"source\":\"release\",\"version\":\"1.1.0\",\"removed\":[\"/h/.local/bin/foo\",\"/d/talon/bin/foo\"],\"kept\":[]}"),
		(data({ tool: t_g, removed: ["/d/talon/bin/g"], kept: ["/h/.local/bin/g"] }), "{\"tool\":\"g\",\"name\":\"acme/g\",\"source\":\"git\",\"version\":null,\"removed\":[\"/d/talon/bin/g\"],\"kept\":[\"/h/.local/bin/g\"]}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T4 R-T7 R-T5 R-LY2 R-TF1 R-TF3: `tools.json` with all the fields of each tool, in the order of the file (`rebuild` and `list` read them). The build id is `build`: the hashes of the header, the compiler (R-T5) and the target. A git tool has `commit`, `ref` and the optional `path`. A field that is not in the file is the empty text or the empty
# list. A missing file is no tool. The failures are those of `ToolsJson.read`: kind input (exit 19), and they name the file.
expect {
	path = "/d/talon/tools.json"
	read = |text| match ToolsJson.manifest({ path, text }) {
		Ok(tools) => Ok(tools.map(|t| Str.inspect((t.key, t.name, ToolManage.source_text(t), t.path, t.hashes, t.nightly, t.target, t.sha256, t.libs, t.installed_at))))
		Err(fail) => Err(fail.line())
	}
	input = |text| Err("tln: error[input]: ${path}: ${text}")
	libs_doc = "{\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"u\"},\"libs\":[\"libm.so.6\"],\"later\":1}"
	rows = [
		(read(Err(NotFound)), Ok([])),
		(read(Ok("{\"format\":1}")), Ok([])),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":${foo_doc},\"g\":${g_doc}}}")), Ok([Str.inspect(("foo", "acme/foo", "1.1.0", Err(None), ["H1"], "nightly-2026-10-14-38a3029", "x64musl", "S1", [], "2026-10-15T12:00:00Z")), Str.inspect(("g", "acme/g", "git main@dd03c09e", Ok("apps/cli"), ["H2", "H3"], "nightly-2026-09-01-abcdef0", "x64musl", "S2", [], "2026-09-02T08:00:00Z"))])),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":${libs_doc}}}")), Ok([Str.inspect(("foo", "acme/foo", "1.1.0", Err(None), [], "", "", "", ["libm.so.6"], ""))])),
		(read(Ok("not json")), input("the content does not parse")),
		(read(Ok("{\"format\":1,\"tools\":{\"foo\":{\"name\":\"acme/foo\"}}}")), input("tool foo: has no source that tln knows")),
		(read(Ok("{\"format\":2,\"tools\":{}}")), input("format 2 is newer than this tln (format 1). Run: tln tool update talon")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T4 R-T23 R-T26 R-T27 R-TF2 R-CC6: the text of `tools.json` after a build puts the tool (slice 048: also a git tool, with its `path`). A new tool is the last. A tool with the same key is replaced in its place, with its fields that Talon does not know (R-TF2); the other tools and the other top-level fields stay. A git tool replaces a release
# tool and the reverse (R-T27). The source of a release tool has no `path`. A missing file gives a new file with `format` 1.
expect {
	path = "/d/talon/tools.json"
	put = |text, tool| match ToolsJson.put({ path, text, tool }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	whole = |tools| "{\"format\":1,\"tools\":{${tools}}}"
	rows = [
		(put(Err(NotFound), t_foo), whole("\"foo\":${foo_doc}")),
		(put(Err(NotFound), t_g), whole("\"g\":${g_doc}")),
		(put(Ok("{\"format\":1,\"tools\":{\"foo\":${foo_doc}}}"), t_g), whole("\"foo\":${foo_doc},\"g\":${g_doc}")),
		(put(Ok("{\"format\":1,\"tools\":{\"g\":{\"name\":\"acme/g\",\"source\":{\"kind\":\"release\",\"version\":\"0.1.0\",\"url\":\"u\"}},\"foo\":${foo_doc}}}"), t_g), whole("\"g\":${g_doc},\"foo\":${foo_doc}")),
		(put(Ok("{\"format\":1,\"tools\":{\"foo\":${foo_doc}}}"), { ..t_foo, source: Git({ commit: "abc", ref: "main" }), path: Err(None) }), whole("\"foo\":{\"name\":\"acme/foo\",\"source\":{\"kind\":\"git\",\"commit\":\"abc\",\"ref\":\"main\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}")),
		(put(Ok("{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"old\"}}}"), t_foo), "{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.1.0\",\"url\":\"${foo_url}\"},\"build\":{\"hashes\":[\"H1\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1\",\"libs\":[],\"installed_at\":\"2026-10-15T12:00:00Z\"}}}"),
		(put(Ok("{\"format\":2,\"tools\":{}}"), t_foo), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B6 R-TF2 R-TF3 R-CC6: the text of `tools.json` after `tool remove`: the tool is gone from `tools`. The other tools and the other top-level fields stay as they are (R-TF2). The last tool gives `"tools":{}`. A key that is not there, and a file with no `tools` field, leave the text as it is. A missing file gives the empty text. A text
# that does not parse and a newer `format` are failures of kind input (exit 19), and the file is not written.
expect {
	path = "/d/talon/tools.json"
	drop = |text, key| match ToolsJson.drop({ path, text, key }) {
		Ok(out) => out.trim_end()
		Err(fail) => fail.line()
	}
	both = "{\"format\":1,\"tools\":{\"foo\":${foo_doc},\"g\":${g_doc}}}"
	rows = [
		(drop(Ok(both), "foo"), "{\"format\":1,\"tools\":{\"g\":${g_doc}}}"),
		(drop(Ok(both), "g"), "{\"format\":1,\"tools\":{\"foo\":${foo_doc}}}"),
		(drop(Ok("{\"format\":1,\"tools\":{\"foo\":${foo_doc}}}"), "foo"), "{\"format\":1,\"tools\":{}}"),
		(drop(Ok("{\"format\":1,\"note\":\"keep\",\"tools\":{\"foo\":{\"later\":7,\"name\":\"acme/foo\"}}}"), "foo"), "{\"format\":1,\"note\":\"keep\",\"tools\":{}}"),
		(drop(Ok(both), "zzz"), both),
		(drop(Ok("{\"format\":1}"), "foo"), "{\"format\":1}"),
		(drop(Err(NotFound), "foo"), ""),
		(drop(Ok("not json"), "foo"), "tln: error[input]: ${path}: the content does not parse"),
		(drop(Ok("{\"format\":2,\"tools\":{}}"), "foo"), "tln: error[input]: ${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
