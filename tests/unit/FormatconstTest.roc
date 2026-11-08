import lib.BinRecord
import lib.GitBuild
import lib.JsonDoc
import lib.Link
import lib.TalonFile
import lib.ToolBinUse
import lib.Toolchain
import lib.ToolsJson
import lib.XCache
import lib.Zig

FormatconstTest :: [].{}

# Slice 230 (docs/slices/230-format-constants.md), R-TF1 R-TF2: these tests name the new constants, so they do not compile until the code agent adds them (red on purpose).
# The names are a proposal of the slice file: `ToolsJson.format` (tools.json), `TalonFile.manifest_format` (manifests in `talon/x/`), `TalonFile.record_format` (`.talon.json`).
# FormatTest has the same checks with no constant. Both are in l0-6: until the constants exist, l0-6 does not compile.

format_of : Str -> U64
format_of = |text| match JsonDoc.parse(text) {
	Ok(Obj(pairs)) => match pairs.find_first(|(key, _)| key == "format") {
		Ok((_, Num(n))) => n.to_u64_wrap()
		_ => 0
	}
	_ => 0
}

sha = Str.repeat("a", 64)

# R-TF1: the `format` of each writer is the constant of its file kind.
expect {
	built : ToolsJson.Built
	built = { key: "foo", name: "acme/foo", version: "1.1.0", url: "https://example.com/foo.tar.zst", hashes: ["H1"], nightly: "nightly-2026-11-06-34f137a", target: "x64musl", sha256: sha, libs: [], installed_at: "2026-11-08T12:00:00Z" }
	talon : ToolsJson.Talon
	talon = { source: Prebuilt({ version: "0.1.0", url: "https://example.com/tln.tar.zst" }), hashes: [], nightly: "", target: "x64musl", sha256: sha, libs: [], installed_at: "2026-11-08T12:00:00Z" }
	path = "/d/talon/tools.json"
	added = ToolsJson.add({ path, text: Err(NotFound), built }).ok_or("")
	with_talon = ToolsJson.put_talon({ path, text: Ok(added), talon }).ok_or("")
	with_bin = BinRecord.set({ path, text: Ok(added), key: "foo", bin: [("foo", sha)] }).ok_or("")
	recorded = BinRecord.record_all({ path, text: Ok(with_talon), made: [{ entry: "tln", sha256: sha }] }).ok_or("")
	source_entry : XCache.Entry
	source_entry = { name: "acme/foo", source: Release({ version: "1.1.0", url: "https://example.com/foo.tar.zst" }), hashes: ["H1"], nightly: "nightly-2026-11-06-34f137a", target: "x64musl", sha256: sha, libs: [], bundle: "B1", last_run: "2026-11-08T12:00:00Z" }
	pre : ToolBinUse.Prebuilt
	pre = { name: "acme/foo", version: "1.1.0", bundle: "B1", target: "x64musl", sha256: sha, url: "https://example.com/foo.tar.zst", last_run: "2026-11-08T12:00:00Z" }
	tc = Toolchain.meta({ id: "nightly-2026-11-06-34f137a", url: "https://example.com/roc.tar.gz", sha256: sha, typed: "@latest", compat: Err(Unknown), now: 1792670400, published_at: 1792670000 })
	zig = Zig.meta({ version: "0.17.0", url: "https://ziglang.org/zig.tar.xz", sha256: sha, now: 1792670400 })
	git = GitBuild.meta({ id: "git-abc", source: { owner: "roc-lang", repo: "roc", ref: "main" }, sha: Str.repeat("b", 40), sha256: sha, compat: Err(Unknown), now: 1792670400 })
	link = Link.meta({ id: "link-dev", kind: Link, path: "/r/roc", now: 1792670400 })
	copy = Link.meta({ id: "copy-dev", kind: Copy, path: "/r/roc", now: 1792670400 })
	tools_ok = [added, with_talon, with_bin, recorded].all(|t| format_of(t) == ToolsJson.format)
	manifest_ok = [XCache.manifest_text(source_entry), ToolBinUse.manifest_text(pre)].all(|t| format_of(t) == TalonFile.manifest_format)
	record_ok = [tc, zig, git, link, copy].all(|t| format_of(t) == TalonFile.record_format)
	dbg (tools_ok, manifest_ok, record_ok)
	tools_ok and manifest_ok and record_ok
}

# R-TF3: a reader refuses (or ignores) a text with the constant plus 1. The number comes from the constant, so a reader with its own literal fails here when the constant changes.
expect {
	path = "/d/talon/tools.json"
	tools_new = "{\"format\":${(ToolsJson.format + 1).to_str()},\"tools\":{}}"
	manifest_new = "{\"format\":${(TalonFile.manifest_format + 1).to_str()},\"name\":\"acme/foo\"}"
	record_new = "{\"format\":${(TalonFile.record_format + 1).to_str()},\"id\":\"link-dev\",\"path\":\"/r/roc\"}"
	tools_now = "{\"format\":${ToolsJson.format.to_str()},\"tools\":{}}"
	record_now = "{\"format\":${TalonFile.record_format.to_str()},\"id\":\"link-dev\",\"path\":\"/r/roc\"}"
	tools_refused = ToolsJson.read({ path, text: Ok(tools_new) }).is_err() and BinRecord.read({ path, text: Ok(tools_new) }).is_err()
	tools_read = ToolsJson.read({ path, text: Ok(tools_now) }) == Ok([]) and BinRecord.read({ path, text: Ok(tools_now) }) == Ok([])
	manifest_ignored = match XCache.read({ path: "m.json", text: manifest_new }) {
		Ignore => Bool.True
		_ => Bool.False
	}
	link_path = "/c/roc/toolchains/link-dev/.talon.json"
	link_refused = Link.target({ id: "link-dev", path: link_path, text: Ok(record_new) }).is_err()
	link_read = Link.target({ id: "link-dev", path: link_path, text: Ok(record_now) }) == Ok("/r/roc")
	dbg (tools_refused, tools_read, manifest_ignored, link_refused, link_read)
	tools_refused and tools_read and manifest_ignored and link_refused and link_read
}
