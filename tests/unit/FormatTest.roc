import lib.BinRecord
import lib.Compiler
import lib.Gc
import lib.GitBuild
import lib.JsonDoc
import lib.Link
import lib.Manage
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

# Slice 235 (docs/slices/235-one-talon-json-reader.md), R-TF3 (the `.talon.json` exception), R-NS1, R-LY1, R-CV5, R-GC5: all readers of `toolchains/<id>/.talon.json` read a text with `format` plus 1 as no fields.
# The texts come from the real writers (Toolchain.meta, GitBuild.meta) and then `newer`, so the field names and the `format` are never a copy.
nightly_id = "nightly-2026-06-01-6666666"

git_id = "git-5a5a5a5a"

git_source = { owner: "roc-lang", repo: "roc", ref: "main" }

# The nightly record: `installed_at` and `published_at` are 2026-06-01 and 2026-05-31, `compat` is `6666666`.
nightly_text : Str
nightly_text = Toolchain.meta({ id: nightly_id, url: "https://example.com/roc.tar.gz", sha256: sha, typed: "@latest", compat: Ok("6666666"), now: 1780315200, published_at: 1780228800 })

git_text : Str
git_text = GitBuild.meta({ id: git_id, source: git_source, sha: Str.repeat("b", 40), sha256: sha, compat: Err(Unknown), now: 1780315200 })

# R-TF3 R-NS1 R-LY1: control. With the current `format` each reader gets its field.
expect {
	times = Compiler.times([{ id: nightly_id, text: Ok(nightly_text) }])
	rows = Manage.rows({ found: [{ id: nightly_id, meta: Ok(nightly_text), last_use: Err(NotFound) }], default: Err(Unset) })
	compat = Manage.compat_of(Ok(nightly_text))
	origins = Manage.origins([{ id: git_id, meta: Ok(git_text), last_use: Err(NotFound) }])
	picked = GitBuild.newest({ source: git_source, rows: [{ id: git_id, text: Ok(git_text) }] })
	dbg (times, rows.map(|r| r.installed_at), compat, origins.len(), picked)
	times.len() == 1 and rows.map(|r| r.installed_at) == [Ok(1780315200)] and compat == Ok("6666666") and origins.len() == 1 and picked == Ok(git_id)
}

# R-TF3 R-NS1 (F7): `Compiler.times` (used by `Base`, `ResolveSelect` and `RocManage`) gives no time for a newer `format`, as for a missing time. Rank 4 then falls back to the tag text.
expect {
	times = Compiler.times([{ id: nightly_id, text: Ok(newer(nightly_text)) }])
	dbg times
	times == []
}

# R-TF3 R-LY1 (F7): `Manage.rows` (`roc list`, `roc rm`, GC) gives `Unknown` for `installed_at` of a newer `format`.
expect {
	rows = Manage.rows({ found: [{ id: nightly_id, meta: Ok(newer(nightly_text)), last_use: Err(NotFound) }], default: Err(Unset) })
	dbg rows.map(|r| r.installed_at)
	rows.map(|r| r.installed_at) == [Err(Unknown)]
}

# R-TF3 R-GC5 (F7): GC keeps a compiler with a newer `format` and no `.last-use`: both times are unknown, so `Keep(NoTime)`. The same compiler with the current `format` is old (2026-06-01) and goes. No project, GC age 30 days, now is 2026-10-22.
expect {
	now = 1792670400
	verdict = |text| {
		rows = Manage.rows({ found: [{ id: nightly_id, meta: Ok(text), last_use: Err(NotFound) }], default: Err(Unset) })
		Gc.toolchains({ rows, projects: [], now, age: 30 * 86400 }).map(|c| c.verdict)
	}
	dbg (verdict(nightly_text), verdict(newer(nightly_text)))
	verdict(nightly_text) == [Remove] and verdict(newer(nightly_text)) == [Keep(NoTime)]
}

# R-TF3 R-GC3 (F7): `Manage.compat_of` gives no compat id for a newer `format`, so GC and `roc rm` remove no `compat-<id>/` dir that they cannot tie to the compiler.
expect {
	compat = Manage.compat_of(Ok(newer(nightly_text)))
	dbg compat
	compat == Err(None)
}

# R-TF3 R-R15 (F7): `Manage.origins` (the SOURCE column of `roc list`) gives no origin for a newer `format`.
expect {
	origins = Manage.origins([{ id: git_id, meta: Ok(newer(git_text)), last_use: Err(NotFound) }])
	dbg origins.len()
	origins.is_empty()
}

# R-TF3 R-R5 R-R6 (F7): `GitBuild.newest` (`roc default --git`, the probes) skips a build with a newer `format`: no match. The older build with the current `format` wins.
expect {
	older = GitBuild.meta({ id: "git-1111aaaa", source: git_source, sha: Str.repeat("a", 40), sha256: sha, compat: Err(Unknown), now: 1780228800 })
	only_newer = GitBuild.newest({ source: git_source, rows: [{ id: git_id, text: Ok(newer(git_text)) }] })
	both = GitBuild.newest({ source: git_source, rows: [{ id: "git-1111aaaa", text: Ok(older) }, { id: git_id, text: Ok(newer(git_text)) }] })
	dbg (only_newer, both)
	only_newer == Err(None) and both == Ok("git-1111aaaa")
}

# R-TF3 R-LK4 (F7): `Link.target` is the one reader that still stops. A newer `format` of a `link-*` record is exit 19 (kind Input), and the text names `tln tool update talon`.
expect {
	link = Link.meta({ id: "link-dev", kind: Link, path: "/r/roc", now: 1792670400 })
	got = Link.target({ id: "link-dev", path: "/c/roc/toolchains/link-dev/.talon.json", text: Ok(newer(link)) })
	dbg got
	match got {
		Err(fail) => fail.kind == Input and fail.message.contains("tln tool update talon")
		Ok(_) => Bool.False
	}
}
