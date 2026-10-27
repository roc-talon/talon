import lib.Clock
import lib.Lookup
import lib.Ref
import lib.Roots
import lib.Scope
import lib.Selector
import lib.ToolsJson
import lib.XCache

XCacheTest :: [].{}

# Slice 049 (docs/slices/049-x.md): the `x` cache and build reuse. The expected value of each row is the design text (CLI 6.4: R-X2, R-B1 to R-B4, R-B9, R-B10, R-GC7, R-TF1, R-TF3, R-TF6) or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts and forms that the design does not give are the proposals of the slice file (TW24). The Fx calls and the files are in the L2 cases `x/x1-run`, `x/x2-offline`, `tool/tk1-takeover` and `gc/gc4-x`.

roots : Roots
roots = { cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }

url_of : Str, Str -> Str
url_of = |repo, version| "https://github.com/${repo}/releases/download/${version}/B${version}.tar.zst"

# One manifest: the release `version` of `name`.
ent : Str, Str, Str -> XCache.Entry
ent = |name, version, target| {
	name,
	source: Release({ version, url: url_of(name, version) }),
	hashes: ["H1", "H2"],
	nightly: "nightly-2026-10-14-38a3029",
	target,
	sha256: "S${version}",
	libs: [],
	bundle: "B${version}",
	last_run: "2026-10-15T12:00:00Z",
}

found : Str, XCache.Entry -> XCache.Found
found = |dir, entry| { dir: "/c/roc/talon/x/${dir}", entry, has_bin: Bool.True }

tool : Str, Str, Str, Str -> ToolsJson.Tool
tool = |key, name, version, target| {
	key,
	name,
	source: Release({ version, url: url_of(name, version) }),
	path: Err(None),
	hashes: ["H1", "H2"],
	nightly: "nightly-2026-10-14-38a3029",
	target,
	sha256: "T${version}",
	libs: [],
	installed_at: "2026-10-01T10:00:00Z",
}

# The manifest of `ent` as the file has it.
manifest : Str, Str, Str, Str -> Str
manifest = |name, version, last_run, bundle| "{\"format\":1,\"name\":\"${name}\",\"source\":{\"kind\":\"release\",\"version\":\"${version}\",\"url\":\"${url_of(name, version)}\"},\"build\":{\"hashes\":[\"H1\",\"H2\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S${version}\",\"libs\":[],\"bundle\":\"${bundle}\",\"last_run\":\"${last_run}\"}\n"

# The answer of `choose` as a text: `installed <key> <version>`, `cached <dir> <version>`, or `none`.
shown : XCache.Choice -> Str
shown = |choice| match choice {
	Installed(t) => "installed ${t.key}"
	Cached(f) => "cached ${Str.drop_prefix(f.dir, "/c/roc/talon/x/")}"
	NoMatch => "none"
}

# R-X2 R-B9: the digest of a build is the sha256 of the text `<name>\n<bundle>\n<hashes joined by ,>\n<nightly>\n<target>\n`. Two builds that differ in one field have two digests (so two releases with the same dependencies have two dirs). The vectors come from `sha256sum`.
expect {
	base = { name: "acme/foo", bundle: "BundleHash1", hashes: ["H1", "H2"], nightly: "nightly-2026-10-14-38a3029", target: "x64musl" }
	d = XCache.digest(base)
	others = [
		XCache.digest({ ..base, name: "acme/bar" }),
		XCache.digest({ ..base, bundle: "BundleHash2" }),
		XCache.digest({ ..base, hashes: ["H1"] }),
		XCache.digest({ ..base, hashes: ["H2", "H1"] }),
		XCache.digest({ ..base, nightly: "nightly-2026-10-12-2664a27" }),
		XCache.digest({ ..base, target: "arm64musl" }),
	]
	rows = [
		(d, "25da40571b514223a1dd0b2909baad678a764bb5fb524b47def0a7a10901d17a"),
		(XCache.digest(base), d),
		(XCache.digest({ ..base, hashes: [] }), "7daade59427dec76525aa6bbc9087f8e2b15895a422726ab584f6700bae26665"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	dbg others
	bad == [] and !others.contains(d) and Str.join_with(others, ",").split_on(",").len() == 6 and others.all(|o| o.count_utf8_bytes() == 64)
}

# R-X2 R-CC1 R-CC11 R-GC7: the paths of an entry (`talon/x/<digest>`, the binary and `manifest.json` in it, the temp dir `<dir>.<hex>.tmp` that a build writes and renames), and the entry dirs of a listing: a directory, parent `talon/x`, no `.` in the name (a temp has dots). Sorted, each once.
expect {
	lay = XCache.layout({ roots, digest: "d1", hex: "0123456789abcdef", file: "foo" })
	listing = [
		{ path: "/c/roc/talon/x/b2", is_dir: Bool.True, mtime: 1 },
		{ path: "/c/roc/talon/x/a1", is_dir: Bool.True, mtime: 1 },
		{ path: "/c/roc/talon/x/a1.0123456789abcdef.tmp", is_dir: Bool.True, mtime: 1 },
		{ path: "/c/roc/talon/x/loose-file", is_dir: Bool.False, mtime: 1 },
		{ path: "/c/roc/talon/x/b2", is_dir: Bool.True, mtime: 1 },
		{ path: "/c/roc/talon/x/c3/deep", is_dir: Bool.True, mtime: 1 },
		{ path: "/c/roc/talon/tmp/a1", is_dir: Bool.True, mtime: 1 },
	]
	lay.dir == "/c/roc/talon/x/d1"
		and lay.bin == "/c/roc/talon/x/d1/foo"
			and lay.manifest == "/c/roc/talon/x/d1/manifest.json"
				and lay.temp == "/c/roc/talon/x/d1.0123456789abcdef.tmp"
					and lay.temp_bin == "/c/roc/talon/x/d1.0123456789abcdef.tmp/foo"
						and lay.temp_manifest == "/c/roc/talon/x/d1.0123456789abcdef.tmp/manifest.json"
							and XCache.manifest_of("/c/roc/talon/x/d1") == "/c/roc/talon/x/d1/manifest.json"
								and XCache.dirs_of({ roots, entries: listing }) == ["/c/roc/talon/x/a1", "/c/roc/talon/x/b2"]
									and XCache.dirs_of({ roots, entries: [] }) == []
}

# R-B9 R-TF1: the manifest text is one line with `format` 1 and the fields in this order: name, source, build, sha256, libs, bundle, last_run. A git build has the commit and the ref. `read` gives the entry back.
expect {
	e = ent("acme/foo", "1.1.0", "x64musl")
	text = XCache.manifest_text(e)
	git = { ..e, source: Git({ commit: "dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8", ref: "main" }), libs: ["libm.so.6"], bundle: "dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8" }
	git_text = XCache.manifest_text(git)
	back = match XCache.read({ path: "/m", text }) {
		Use(got) => got.name == e.name and got.hashes == e.hashes and got.nightly == e.nightly and got.target == e.target and got.sha256 == e.sha256 and got.libs == e.libs and got.bundle == e.bundle and got.last_run == e.last_run
		_ => Bool.False
	}
	git_back = match XCache.read({ path: "/m", text: git_text }) {
		Use(got) => match got.source {
			Git(g) => g.ref == "main" and g.commit == "dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8" and got.libs == ["libm.so.6"]
			Release(_) => Bool.False
		}
		_ => Bool.False
	}
	dbg text
	dbg git_text
	text == manifest("acme/foo", "1.1.0", "2026-10-15T12:00:00Z", "B1.1.0")
		and git_text == "{\"format\":1,\"name\":\"acme/foo\",\"source\":{\"kind\":\"git\",\"commit\":\"dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8\",\"ref\":\"main\"},\"build\":{\"hashes\":[\"H1\",\"H2\"],\"nightly\":\"nightly-2026-10-14-38a3029\",\"target\":\"x64musl\"},\"sha256\":\"S1.1.0\",\"libs\":[\"libm.so.6\"],\"bundle\":\"dd03c09e5f1a2b3c4d5e6f708192a3b4c5d6e7f8\",\"last_run\":\"2026-10-15T12:00:00Z\"}\n"
			and back
				and git_back
}

# R-TF1 R-TF3 R-TF6 R-B9: reading a manifest. A manifest can be made again by a build, so a newer `format` is ignored (no read, no write) and text that does not parse is deleted with a warning. An object that lacks the name, the source or the bundle is text that does not parse. A missing list or text is empty. An unknown field is ignored.
expect {
	warn = |path| "${path}: the content does not parse. Talon deletes it and makes it again."
	kind = |text| match XCache.read({ path: "/m/manifest.json", text }) {
		Use(got) => "use ${got.name} ${got.sha256}|${got.target}|${got.nightly}|${got.last_run}|${Str.join_with(got.hashes, ",")}|${Str.join_with(got.libs, ",")}"
		Ignore => "ignore"
		Delete(w) => "delete ${w}"
	}
	src = "\"source\":{\"kind\":\"release\",\"version\":\"1.0.0\",\"url\":\"u\"}"
	rows = [
		(kind(manifest("acme/foo", "1.1.0", "2026-10-15T12:00:00Z", "B")), "use acme/foo S1.1.0|x64musl|nightly-2026-10-14-38a3029|2026-10-15T12:00:00Z|H1,H2|"),
		(kind("{\"format\":2,\"name\":\"acme/foo\"}"), "ignore"),
		(kind("{\"format\":1,\"name\":\"acme/foo\",${src},\"bundle\":\"B\",\"new_field\":[1,2]}"), "use acme/foo |||||"),
		(kind("{\"format\":0,\"name\":\"acme/foo\",${src},\"bundle\":\"B\",\"sha256\":\"S\"}"), "use acme/foo S|||||"),
		(kind("garbage"), "delete ${warn("/m/manifest.json")}"),
		(kind(""), "delete ${warn("/m/manifest.json")}"),
		(kind("[1,2]"), "delete ${warn("/m/manifest.json")}"),
		(kind("{\"name\":\"acme/foo\",${src},\"bundle\":\"B\"}"), "delete ${warn("/m/manifest.json")}"),
		(kind("{\"format\":1,${src},\"bundle\":\"B\"}"), "delete ${warn("/m/manifest.json")}"),
		(kind("{\"format\":1,\"name\":\"acme/foo\",\"bundle\":\"B\"}"), "delete ${warn("/m/manifest.json")}"),
		(kind("{\"format\":1,\"name\":\"acme/foo\",\"source\":{\"kind\":\"zip\"},\"bundle\":\"B\"}"), "delete ${warn("/m/manifest.json")}"),
		(kind("{\"format\":1,\"name\":\"acme/foo\",${src}}"), "delete ${warn("/m/manifest.json")}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-X2 R-TF3 R-TF6: the entries of the dirs, in the order of the dirs. A manifest that cannot be read gives nothing. `Ignore` gives nothing. `Delete` gives the dir and the warning (both in the order of the dirs).
expect {
	dirs = ["/c/roc/talon/x/a", "/c/roc/talon/x/b", "/c/roc/talon/x/c", "/c/roc/talon/x/d", "/c/roc/talon/x/e"]
	reads = [
		Ok(manifest("acme/foo", "1.1.0", "2026-10-15T12:00:00Z", "B1")),
		Ok("garbage"),
		Err(NotFound),
		Ok("{\"format\":9}"),
		Ok(manifest("acme/bar", "2.0.0", "2026-10-15T12:00:00Z", "B2")),
	]
	got = XCache.entries_of({ dirs, reads })
	names = got.found.map(|f| "${f.dir}:${f.entry.name}")
	dbg names
	dbg got.warnings
	names == ["/c/roc/talon/x/a:acme/foo", "/c/roc/talon/x/e:acme/bar"]
		and got.delete == ["/c/roc/talon/x/b"]
			and got.warnings == ["/c/roc/talon/x/b/manifest.json: the content does not parse. Talon deletes it and makes it again."]
				and XCache.entries_of({ dirs: [], reads: [] }).found == []
}

# R-SC4 R-AD7: the names that a short name can match. One entity for each full name. The installed tools come first (alias is the key, a git tool has no version). An entry adds a name that no tool and no earlier entry has (alias empty). A short name finds a tool by its key, or by the repo name, or an entry by its repo name. A full name that a tool and an entry both have is no tie.
expect {
	tools = [
		{ key: "q", name: "acme/qux", source: Release({ version: "1.0.0", url: "u1" }) },
		{ key: "g", name: "acme/gee", source: Git({ commit: "c1", ref: "main" }) },
	]
	entries = [
		found("a", ent("acme/foo", "1.0.0", "x64musl")),
		found("b", ent("acme/foo", "1.1.0", "x64musl")),
		found("c", ent("acme/qux", "2.0.0", "x64musl")),
		found("d", ent("other/roc-bar", "3.0.0", "x64musl")),
	]
	es = XCache.entities({ tools, entries })
	lookup = |typed| match Ref.parse(typed, Scope.X, Bool.False) {
		Ok(ref) => match Lookup.find(Scope.X, ref, es) {
			Ok(Lookup.Existing(hit)) => "existing ${hit.name}"
			Ok(Lookup.New(name)) => "new ${name}"
			Err({ fail, block: _ }) => fail.line()
		}
		Err(fail) => fail.line()
	}
	cells = es.map(|e| "${e.alias}|${e.name}|${e.series}|${e.note}")
	versions = es.map(|e| e.version)
	dbg cells
	cells == ["q|acme/qux||", "g|acme/gee||", "|acme/foo||", "|other/roc-bar||"]
		and versions == [Ok("1.0.0"), Err(None), Ok("1.0.0"), Ok("3.0.0")]
			and lookup("q") == "existing acme/qux"
				and lookup("qux") == "existing acme/qux"
					and lookup("acme/qux") == "existing acme/qux"
						and lookup("foo") == "existing acme/foo"
							and lookup("bar") == "existing other/roc-bar"
								and lookup("roc-bar") == "existing other/roc-bar"
									and lookup("g") == "existing acme/gee"
										and lookup("acme/new") == "new acme/new"
											and lookup("nope") == "tln: error[usage]: 'nope' matches no installed tool or cached app. Use the full name (owner/repo)."
												and XCache.entities({ tools: [], entries: [] }) == []
}

# R-B1 R-B2 R-B3 R-B10 (online): the build that a request uses. A build matches when the full name, the source kind (release) and the target are equal. No selector: any version. A selector: the version is `first` (the version that the selector means). The highest version wins (numbers), the installed tool wins a tie. The winner must be a candidate of the list (R-B3):
# a version that is not in the list is yanked or deleted, and no other build is tried. The nightly is not compared. An entry with no binary in its dir (`has_bin` false, question Q-X3) is no build: it is not a match, and it does not hide an older entry. A version text that is no semver (`latest-build`, code decision of 049b) sorts below every version.
expect {
	name = "acme/foo"
	on = |first, listed| Online({ first, listed })
	req = |selector, check, installed, entries| shown(XCache.choose({ name, target: "x64musl", selector, check, installed, entries }))
	e10 = found("e10", ent(name, "1.0.0", "x64musl"))
	e11 = found("e11", ent(name, "1.1.0", "x64musl"))
	e19 = found("e19", ent(name, "1.9.0", "x64musl"))
	e110 = found("e110", ent(name, "1.10.0", "x64musl"))
	all = ["1.0.0", "1.1.0", "1.9.0", "1.10.0", "2.0.0"]
	t11 = Ok(tool("foo", name, "1.1.0", "x64musl"))
	t10 = Ok(tool("foo", name, "1.0.0", "x64musl"))
	other_nightly = found("on", { ..ent(name, "1.2.0", "x64musl"), nightly: "nightly-2026-09-01-abcdef0" })
	odd = found("odd", ent(name, "latest-build", "x64musl"))
	odd_listed = ["1.0.0", "1.1.0", "latest-build"]
	git_entry = found("g", { ..ent(name, "9.0.0", "x64musl"), source: Git({ commit: "c", ref: "main" }) })
	rows = [
		(req(Err(None), on("2.0.0", all), Err(None), []), "none"),
		(req(Err(None), on("2.0.0", all), Err(None), [e10]), "cached e10"),
		(req(Err(None), on("1.0.0", all), Err(None), [e10]), "cached e10"),
		(req(Ok(Latest), on("2.0.0", all), Err(None), [e10]), "none"),
		(req(Ok(Latest), on("1.0.0", all), Err(None), [e10]), "cached e10"),
		(req(Ok(Exact("1.0.0")), on("1.0.0", all), Err(None), [e10, e11]), "cached e10"),
		(req(Ok(Exact("1.1.0")), on("1.1.0", all), Err(None), [e10, e11]), "cached e11"),
		(req(Ok(Exact("1.2.0")), on("1.2.0", all), Err(None), [e10, e11]), "none"),
		(req(Ok(Range("^1")), on("1.10.0", all), Err(None), [e10, e11, e19, e110]), "cached e110"),
		(req(Ok(Range("^1")), on("1.10.0", all), Err(None), [e10, e11, e19]), "none"),
		(req(Err(None), on("2.0.0", all), Err(None), [e19, e110, e11]), "cached e110"),
		(req(Err(None), on("2.0.0", all), t11, [e11]), "installed foo"),
		(req(Err(None), on("2.0.0", all), t11, [e19]), "cached e19"),
		(req(Err(None), on("2.0.0", all), t10, [e11]), "cached e11"),
		(req(Err(None), on("2.0.0", all), t10, []), "installed foo"),
		(req(Ok(Latest), on("1.1.0", all), t10, [e11]), "cached e11"),
		(req(Ok(Latest), on("1.1.0", all), t10, []), "none"),
		(req(Err(None), on("1.1.0", ["1.0.0", "1.1.0"]), Err(None), [e11, e10]), "cached e11"),
		(req(Err(None), on("1.0.0", ["1.0.0"]), Err(None), [e11, e10]), "none"),
		(req(Err(None), on("1.0.0", ["1.0.0"]), t11, []), "none"),
		(req(Err(None), on("1.1.0", []), Err(None), [e11]), "none"),
		(req(Err(None), on("2.0.0", ["1.2.0", "2.0.0"]), Err(None), [other_nightly]), "cached on"),
		(req(Err(None), on("2.0.0", all), Err(None), [git_entry]), "none"),
		(req(Err(None), on("1.1.0", odd_listed), Err(None), [odd, e10]), "cached e10"),
		(req(Err(None), on("1.1.0", odd_listed), Err(None), [e10, odd]), "cached e10"),
		(req(Err(None), on("1.1.0", odd_listed), t10, [odd]), "installed foo"),
		(req(Err(None), on("1.1.0", odd_listed), Err(None), [odd]), "cached odd"),
		(req(Err(None), on("2.0.0", all), Err(None), [{ ..e11, has_bin: Bool.False }]), "none"),
		(req(Err(None), on("2.0.0", all), Err(None), [e10, { ..e11, has_bin: Bool.False }]), "cached e10"),
		(req(Err(None), on("2.0.0", all), t10, [{ ..e11, has_bin: Bool.False }]), "installed foo"),
		(req(Err(None), on("2.0.0", all), Ok({ ..tool("foo", name, "1.0.0", "x64musl"), source: Git({ commit: "c", ref: "main" }) }), []), "none"),
		(req(Err(None), on("2.0.0", all), Err(None), [found("t", ent(name, "1.1.0", "arm64musl"))]), "none"),
		(req(Err(None), on("2.0.0", all), Ok(tool("foo", name, "1.1.0", "arm64musl")), []), "none"),
		(req(Err(None), on("2.0.0", all), Err(None), [found("n", ent("acme/other", "1.1.0", "x64musl"))]), "none"),
		(req(Err(None), on("2.0.0", all), Ok(tool("foo", "acme/other", "1.1.0", "x64musl")), []), "none"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B7 R-B8 R-B2 (offline, no check online): the same match and the same winner. No selector: any version. `Exact(v)`: the version is `v`. Any other selector (`latest`, a range) matches no build (question Q-O2: the design does not say what the newest release is with no network). No list is read.
expect {
	name = "acme/foo"
	req = |selector, installed, entries| shown(XCache.choose({ name, target: "x64musl", selector, check: Offline, installed, entries }))
	e10 = found("e10", ent(name, "1.0.0", "x64musl"))
	e11 = found("e11", ent(name, "1.1.0", "x64musl"))
	rows = [
		(req(Err(None), Err(None), []), "none"),
		(req(Err(None), Err(None), [e10, e11]), "cached e11"),
		(req(Err(None), Ok(tool("foo", name, "1.1.0", "x64musl")), [e11]), "installed foo"),
		(req(Err(None), Ok(tool("foo", name, "1.0.0", "x64musl")), [e11]), "cached e11"),
		(req(Ok(Exact("1.0.0")), Err(None), [e10, e11]), "cached e10"),
		(req(Ok(Exact("1.0.0")), Ok(tool("foo", name, "1.0.0", "x64musl")), [e10]), "installed foo"),
		(req(Ok(Exact("2.0.0")), Err(None), [e10, e11]), "none"),
		(req(Ok(Latest), Err(None), [e10, e11]), "none"),
		(req(Ok(Range("^1")), Err(None), [e10, e11]), "none"),
		(req(Ok(Latest), Ok(tool("foo", name, "1.0.0", "x64musl")), []), "none"),
		(req(Err(None), Err(None), [found("g", { ..ent(name, "9.0.0", "x64musl"), source: Git({ commit: "c", ref: "main" }) })]), "none"),
		(req(Err(None), Err(None), [found("t", ent(name, "1.1.0", "arm64musl"))]), "none"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B3 R-B4 (NC3): the note of an older build compares numbers (`1.9.0` is older than `1.10.0`), and no note for the same or a newer version. `take_how`: an entry that the `[tools]` of a known project uses is copied and stays (the project tool keeps its build, R-PT13). Any other entry is moved.
expect {
	older = |have, newest| XCache.is_older({ have, newest })
	rows = [
		(older("1.0.0", "1.1.0"), Bool.True),
		(older("1.9.0", "1.10.0"), Bool.True),
		(older("1.10.0", "1.9.0"), Bool.False),
		(older("1.1.0", "1.1.0"), Bool.False),
		(older("2.0.0", "1.9.9"), Bool.False),
		(older("0.9.9", "1.0.0"), Bool.True),
		(older("latest-build", "1.0.0"), Bool.True),
		(older("1.0.0", "latest-build"), Bool.False),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
		and XCache.take_how({ project_uses: Bool.False }) == Move
			and XCache.take_how({ project_uses: Bool.True }) == Copy
}

# R-GC7 R-GC9 R-PT14: the entry dirs that GC removes. An entry goes when its `last_run` is more than `age` seconds before `now` (the time of Talon). Exactly `age` stays. A time in the future stays. An entry whose bundle is in `kept` (a `[tools]` URL of a live known project) stays, also when it is old.
# An entry that cannot be read, a newer `format`, text that does not parse and a `last_run` that is no time stay (question Q-G1: the design gives no rule).
expect {
	now = Clock.parse_utc("2026-10-15T12:00:00Z") ?? 0
	age = 2592000
	m = |run, bundle| Ok(manifest("acme/foo", "1.0.0", run, bundle))
	dirs = ["/x/boundary", "/x/old", "/x/fresh", "/x/future", "/x/kept", "/x/never", "/x/missing", "/x/garbage", "/x/newer", "/x/ancient"]
	reads = [
		m("2026-09-15T12:00:00Z", "B1"),
		m("2026-09-15T11:59:59Z", "B2"),
		m("2026-10-14T12:00:00Z", "B3"),
		m("2026-11-01T00:00:00Z", "B4"),
		m("2026-01-01T00:00:00Z", "BKEPT"),
		m("never", "B6"),
		Err(NotFound),
		Ok("garbage"),
		Ok("{\"format\":2}"),
		m("2020-01-01T00:00:00Z", "B7"),
	]
	got = XCache.expired({ dirs, reads, now, age, kept: ["BKEPT", "BOTHER"] })
	none_kept = XCache.expired({ dirs, reads, now, age, kept: [] })
	dbg got
	got == ["/x/old", "/x/ancient"]
		and none_kept == ["/x/old", "/x/kept", "/x/ancient"]
			and XCache.expired({ dirs: [], reads: [], now, age, kept: [] }) == []
				and XCache.expired({ dirs, reads, now, age: 0, kept: [] }) == ["/x/boundary", "/x/old", "/x/fresh", "/x/kept", "/x/ancient"]
}
