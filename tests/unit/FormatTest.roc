import lib.BinRecord
import lib.GitBuild
import lib.JsonDoc
import lib.Link
import lib.Setup
import lib.ToolBinUse
import lib.Toolchain
import lib.ToolsJson
import lib.XCache
import lib.Zig

FormatTest :: [].{}

# Slice 230 (docs/slices/230-format-constants.md), R-TF1 R-TF2 R-TF3: each file kind has one `format` number, and the writers and the readers of the kind use the same number.
# These tests do not name a constant (it does not exist yet). The writer is called, the `format` is read from its text, and the readers are called with that text and with the text that has the number plus 1.
# FormatconstTest has the tests that name the constants. If a writer and a reader of one kind use different numbers, a row here fails.

# The `format` of a text that a writer made, or 0 when the text has none.
format_of : Str -> U64
format_of = |text| match JsonDoc.parse(text) {
	Ok(Obj(pairs)) => match pairs.find_first(|(key, _)| key == "format") {
		Ok((_, Num(n))) => n.to_u64_wrap()
		_ => 0
	}
	_ => 0
}

# The same text with `format` plus 1. A writer puts `format` first (`TalonFile.render`), so the text starts with `{"format":<n>`.
newer : Str -> Str
newer = |text| {
	n = format_of(text)
	"{\"format\":${(n + 1).to_str()}${text.drop_prefix("{\"format\":${n.to_str()}")}"
}

sha = Str.repeat("a", 64)

built : ToolsJson.Built
built = { key: "foo", name: "acme/foo", version: "1.1.0", url: "https://example.com/foo.tar.zst", hashes: ["H1"], nightly: "nightly-2026-11-06-34f137a", target: "x64musl", sha256: sha, libs: [], installed_at: "2026-11-08T12:00:00Z" }

talon : ToolsJson.Talon
talon = { source: Prebuilt({ version: "0.1.0", url: "https://example.com/tln.tar.zst" }), hashes: [], nightly: "", target: "x64musl", sha256: sha, libs: [], installed_at: "2026-11-08T12:00:00Z" }

path = "/d/talon/tools.json"

# The 4 writers of tools.json (ToolsJson.add, ToolsJson.put_talon, BinRecord.set, BinRecord.record_all): a text.
tools_texts : {} -> Try(List(Str), _)
tools_texts = |_| {
	added = ToolsJson.add({ path, text: Err(NotFound), built })?
	with_talon = ToolsJson.put_talon({ path, text: Ok(added), talon })?
	with_bin = BinRecord.set({ path, text: Ok(added), key: "foo", bin: [("foo", sha)] })?
	recorded = BinRecord.record_all({ path, text: Ok(with_talon), made: [{ entry: "tln", sha256: sha }] })?
	Ok([added, with_talon, with_bin, recorded])
}

# R-TF1 R-TF3: every writer of tools.json gives the same `format`, and the 3 readers (ToolsJson.read, BinRecord.read, Setup.tool_names) take each text and refuse the text with `format` plus 1 (kind Input, exit 19).
expect {
	texts = tools_texts({}).ok_or([])
	formats = texts.map(format_of)
	ok = |text| ToolsJson.read({ path, text: Ok(text) }).is_ok() and BinRecord.read({ path, text: Ok(text) }).is_ok() and Setup.tool_names({ path, text }).is_ok()
	refused = |text| {
		t = newer(text)
		ToolsJson.read({ path, text: Ok(t) }).is_err() and BinRecord.read({ path, text: Ok(t) }).is_err() and Setup.tool_names({ path, text: t }).is_err() and BinRecord.set({ path, text: Ok(t), key: "foo", bin: [("foo", sha)] }).is_err()
	}
	dbg (formats, texts.map(ok), texts.map(refused))
	texts.len() == 4 and formats.all(|f| f == formats.first().ok_or(0) and f > 0) and texts.all(ok) and texts.all(refused)
}

# R-TF1 R-TF3 R-B9: the 2 writers of the manifests in `talon/x/` (XCache.manifest_text, ToolBinUse.manifest_text) give the same `format`. Their readers take the text. A text with `format` plus 1 is not read and not written (XCache.read: Ignore; ToolBinUse.read_manifest: NotPrebuilt, so the caller reads it as a source entry and gets Ignore).
expect {
	source_entry : XCache.Entry
	source_entry = { name: "acme/foo", source: Release({ version: "1.1.0", url: "https://example.com/foo.tar.zst" }), hashes: ["H1"], nightly: "nightly-2026-11-06-34f137a", target: "x64musl", sha256: sha, libs: [], bundle: "B1", last_run: "2026-11-08T12:00:00Z" }
	pre : ToolBinUse.Prebuilt
	pre = { name: "acme/foo", version: "1.1.0", bundle: "B1", target: "x64musl", sha256: sha, url: "https://example.com/foo.tar.zst", last_run: "2026-11-08T12:00:00Z" }
	x_text = XCache.manifest_text(source_entry)
	p_text = ToolBinUse.manifest_text(pre)
	x_ok = match XCache.read({ path: "m.json", text: x_text }) {
		Use(e) => e == source_entry
		_ => Bool.False
	}
	p_ok = ToolBinUse.read_manifest(p_text) == Ok(pre)
	x_new = match XCache.read({ path: "m.json", text: newer(x_text) }) {
		Ignore => Bool.True
		_ => Bool.False
	}
	p_new = ToolBinUse.read_manifest(newer(p_text)) == Err(NotPrebuilt)
	any_new = match XCache.read_any({ path: "m.json", text: newer(p_text) }) {
		Ignore => Bool.True
		_ => Bool.False
	}
	dbg (format_of(x_text), format_of(p_text), x_ok, p_ok, x_new, p_new, any_new)
	format_of(x_text) == format_of(p_text) and format_of(x_text) > 0 and x_ok and p_ok and x_new and p_new and any_new
}

# R-TF1 R-TF3 R-CV5 R-LK4: the 4 writers of `.talon.json` (Toolchain.meta, Zig.meta, GitBuild.meta, Link.meta for a link and for a copy) give the same `format`. The reader that checks it, `Link.target`, takes the text of a link and refuses a text with `format` plus 1 (exit 19, R-TF3: only the `link-*` target).
expect {
	tc = Toolchain.meta({ id: "nightly-2026-11-06-34f137a", url: "https://example.com/roc.tar.gz", sha256: sha, typed: "@latest", compat: Err(Unknown), now: 1792670400, published_at: 1792670000 })
	zig = Zig.meta({ version: "0.17.0", url: "https://ziglang.org/zig.tar.xz", sha256: sha, now: 1792670400 })
	git = GitBuild.meta({ id: "git-abc", source: { owner: "roc-lang", repo: "roc", ref: "main" }, sha: Str.repeat("b", 40), sha256: sha, compat: Err(Unknown), now: 1792670400 })
	link = Link.meta({ id: "link-dev", kind: Link, path: "/r/roc", now: 1792670400 })
	copy = Link.meta({ id: "copy-dev", kind: Copy, path: "/r/roc", now: 1792670400 })
	formats = [tc, zig, git, link, copy].map(format_of)
	target = |text| Link.target({ id: "link-dev", path: "/c/roc/toolchains/link-dev/.talon.json", text: Ok(text) })
	dbg (formats, target(link), target(newer(link)).is_err())
	formats.all(|f| f == format_of(tc) and f > 0) and target(link) == Ok("/r/roc") and target(newer(link)).is_err()
}
