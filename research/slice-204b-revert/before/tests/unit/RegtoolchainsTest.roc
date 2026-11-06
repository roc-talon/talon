import lib.Fail
import lib.Nightlies
import lib.RegistryToolchains
import lib.Roots

RegtoolchainsTest :: [].{}

# Slice 204 (docs/slices/204-registry-toolchains.md). Pure: the toolchain row file, the pages, the hide of `log:N`, and the rows as `Nightlies` releases.
# The flows `RegistryToolchains.list!` and `Nightlies.list_registry!` are the L2 cases `registry/ap5-toolchain-rows` and `registry/cv1-registry-nightlies`.
# The expected value of each row is the design text, not the code. The members of a row are those of Registry R-AP49 (Toolchain), as `records.Toolchain.encode_row` writes them.

roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }

origin = "http://127.0.0.1:9"

h1 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

h2 = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"

row = |n, tag, target| { tag, target, asset_name: "roc_nightly-${target}-x.tar.gz", sha256: h1, published_at: 1792065600000 + n, log_index: n }

r10 = row(10, "nightly-2026-10-09-258ab27", "linux_x86_64")

r11 = row(11, "nightly-2026-10-09-258ab27", "linux_arm64")

r14 = row(14, "nightly-2026-10-12-2664a27", "linux_x86_64")

r_text = |r| "{\"tag\":\"${r.tag}\",\"target\":\"${r.target}\",\"asset_name\":\"${r.asset_name}\",\"sha256\":\"${r.sha256}\",\"published_at\":${r.published_at.to_str()},\"log_index\":${r.log_index.to_str()}}"

# R-IX4, R-IX1, R-TF1: the path of the file, in the dir of one registry, and its text: `format` 1 and the rows in log index order, one line, a line end. The rows have the members of R-AP49 in the order of `records`.
expect {
	path_ok = RegistryToolchains.path({ roots, origin }) == "/c/roc/talon/index/registry/http_127.0.0.1_9/toolchains.json"
	path_v6_ok = RegistryToolchains.path({ roots, origin: "https://registry.example.org" }) == "/c/roc/talon/index/registry/https_registry.example.org/toolchains.json"
	text_ok = RegistryToolchains.file_text([r10, r14]) == "{\"format\":1,\"rows\":[${r_text(r10)},${r_text(r14)}]}\n"
	empty_ok = RegistryToolchains.file_text([]) == "{\"format\":1,\"rows\":[]}\n"
	path_ok and path_v6_ok and text_ok and empty_ok
}

# R-IX4, R-TF2, R-TF3, R-TF6, R-AP51: the file read. A round trip keeps the rows and their order. Not JSON, no `format`, no `rows`, a row with a missing member, a member of the wrong type: `Bad`
# (the file is deleted and the read starts at `after=0`). A `format` above 1 is `Newer`. An unknown member of the top object or of a row is ignored.
expect {
	round_ok = RegistryToolchains.parse_file(RegistryToolchains.file_text([r10, r11, r14])) == Ok([r10, r11, r14])
	empty_ok = RegistryToolchains.parse_file(RegistryToolchains.file_text([])) == Ok([])
	extra_ok = RegistryToolchains.parse_file("{\"format\":1,\"note\":\"x\",\"rows\":[{\"log_index\":10,\"tag\":\"${r10.tag}\",\"target\":\"${r10.target}\",\"asset_name\":\"${r10.asset_name}\",\"sha256\":\"${r10.sha256}\",\"published_at\":${r10.published_at.to_str()},\"more\":1}]}") == Ok([r10])
	bad : List(Str)
	bad = [
		"",
		"not json",
		"[]",
		"{}",
		"{\"format\":1}",
		"{\"rows\":[]}",
		"{\"format\":\"1\",\"rows\":[]}",
		"{\"format\":1,\"rows\":{}}",
		"{\"format\":1,\"rows\":null}",
		"{\"format\":1,\"rows\":[{\"tag\":\"nightly-2026-10-09-258ab27\"}]}",
		"{\"format\":1,\"rows\":[${r_text(r10).replace_each("\"log_index\":10", "\"log_index\":\"10\"")}]}",
	]
	bad_ok = bad.all(|text| RegistryToolchains.parse_file(text) == Err(Bad))
	newer_ok = RegistryToolchains.parse_file("{\"format\":2,\"rows\":[]}") == Err(Newer) and RegistryToolchains.parse_file("{\"format\":7,\"future\":true}") == Err(Newer)
	round_ok and empty_ok and extra_ok and bad_ok and newer_ok
}

# R-IX4, R-AP47, R-AP5, R-AP69: `after_of` is the `log_index` of the last row, not a count (the log has other rows: the first row here is 10), 0 for no row. The URL of a page has `after` and no `target`.
expect {
	after_ok = RegistryToolchains.after_of([r10, r11, r14]) == 14 and RegistryToolchains.after_of([r10]) == 10 and RegistryToolchains.after_of([]) == 0
	url_ok = RegistryToolchains.page_url({ origin, after: 0 }) == "http://127.0.0.1:9/v1/toolchains?after=0" and RegistryToolchains.page_url({ origin: "https://registry.example.org", after: 2500 }) == "https://registry.example.org/v1/toolchains?after=2500"
	after_ok and url_ok
}

# R-AP5, R-AP51, R-AP44, R-E6: the reader of a page (the body form of `records.Toolchain.encode_page`). An unknown member is ignored. A body that does not decode is exit 15 and the message names the registry.
expect {
	good = "{\"toolchains\":[${r_text(r10)},${r_text(r14)}],\"more\":true}"
	got = RegistryToolchains.page({ origin, body: good })
	good_ok = match got {
		Ok(p) => p.toolchains == [r10, r14] and p.more
		Err(_) => Bool.False
	}
	empty_ok = match RegistryToolchains.page({ origin, body: "{\"toolchains\":[],\"more\":false}" }) {
		Ok(p) => p.toolchains.is_empty() and !p.more
		Err(_) => Bool.False
	}
	extra_ok = match RegistryToolchains.page({ origin, body: "{\"more\":false,\"toolchains\":[],\"next\":\"x\"}" }) {
		Ok(p) => p.toolchains.is_empty()
		Err(_) => Bool.False
	}
	bad : List(Str)
	bad = [
		"",
		"<html>",
		"{\"toolchains\":[]}",
		"{\"more\":false}",
		"{\"toolchains\":null,\"more\":false}",
		"{\"toolchains\":[],\"more\":null}",
		"{\"toolchains\":[],\"more\":\"no\"}",
		"{\"toolchains\":[{\"tag\":\"x\"}],\"more\":false}",
	]
	bad_ok = bad.all(
		|body| match RegistryToolchains.page({ origin, body }) {
			Ok(_) => Bool.False
			Err(f) => f.kind.code() == 15 and f.message.contains(origin) and f.message.contains("is not a toolchain list")
		},
	)
	good_ok and empty_ok and extra_ok and bad_ok
}

# R-AP47: what to read after a page. `more` false is done. `more` true goes on from the `log_index` of the last row (not the count). A page with `more` true and no row, or a last `log_index` that is not above `after`, would never end: exit 15.
expect {
	page = |rows, more| { toolchains: rows, more }
	done_ok = RegistryToolchains.next({ origin, after: 0, page: page([r10, r14], Bool.False) }) == Ok(Done) and RegistryToolchains.next({ origin, after: 14, page: page([], Bool.False) }) == Ok(Done)
	more_ok = RegistryToolchains.next({ origin, after: 0, page: page([r10, r14], Bool.True) }) == Ok(More(14))
	stuck = [
		RegistryToolchains.next({ origin, after: 0, page: page([], Bool.True) }),
		RegistryToolchains.next({ origin, after: 14, page: page([r10, r14], Bool.True) }),
		RegistryToolchains.next({ origin, after: 20, page: page([r14], Bool.True) }),
	]
	stuck_ok = stuck.all(
		|got| match got {
			Ok(_) => Bool.False
			Err(f) => f.kind.code() == 15 and f.message.contains(origin) and f.message.contains("does not move on")
		},
	)
	done_ok and more_ok and stuck_ok
}

# R-IX4: the file after a read is the kept rows and then the new ones. A new row at or below the largest kept log index is dropped (a row never changes, R-PU10). R-AP19: `log: Ok(n)` hides the rows above n and keeps the one at n, in order. No snapshot: all.
expect {
	merge_ok = RegistryToolchains.merge({ kept: [r10], fresh: [r11, r14] }) == [r10, r11, r14] and RegistryToolchains.merge({ kept: [], fresh: [r10, r14] }) == [r10, r14] and RegistryToolchains.merge({ kept: [r10, r11], fresh: [] }) == [r10, r11]
	dup = { ..r11, sha256: h2 }
	drop_ok = RegistryToolchains.merge({ kept: [r10, r14], fresh: [dup, r14, row(15, "nightly-2026-10-13-aaaaaaa", "linux_x86_64")] }) == [r10, r14, row(15, "nightly-2026-10-13-aaaaaaa", "linux_x86_64")]
	rows = [r10, r11, r14]
	vis_ok = RegistryToolchains.visible({ rows, log: Err(None) }) == rows and RegistryToolchains.visible({ rows, log: Ok(14) }) == rows and RegistryToolchains.visible({ rows, log: Ok(13) }) == [r10, r11] and RegistryToolchains.visible({ rows, log: Ok(11) }) == [r10, r11] and RegistryToolchains.visible({ rows, log: Ok(10) }) == [r10] and RegistryToolchains.visible({ rows, log: Ok(9) }) == [] and RegistryToolchains.visible({ rows: [], log: Ok(5) }) == []
	merge_ok and drop_ok and vis_ok
}

# R-IX4, R-TF6: the warning for a file that does not parse. It names the path and the registry.
expect {
	RegistryToolchains.bad_file_warning({ path: "/c/roc/talon/index/registry/http_127.0.0.1_9/toolchains.json", origin })
		== "warning: /c/roc/talon/index/registry/http_127.0.0.1_9/toolchains.json is not a toolchain list file and is removed: Talon reads the list again from http://127.0.0.1:9"
}

# Rows for the `Nightlies` source (R-CV1, R-CV2, R-CV3, R-AP50, R-NS1).
t_oct14 = "nightly-2026-10-14-38a3029"

t_jul = "nightly-2026-July-31-123c5d7"

t_oct09 = "nightly-2026-10-09-258ab27"

t_oct12 = "nightly-2026-10-12-2664a27"

lin = |n, tag, name, sha, ms| { tag, target: "linux_x86_64", asset_name: name, sha256: sha, published_at: ms, log_index: n }

dl = |tag, name| "https://github.com/roc-lang/nightlies/releases/download/${tag}/${name}"

# R-CV2, R-CV3, R-AP50, R-NS1: one release for each row of the target of the host. `id` is the tag as the registry has it (the month name form stays). `published_at` is the row in seconds (the milliseconds are cut). The asset has the row `asset_name` and `sha256`, size 0 (no size in a row),
# and the GitHub download URL of the tag and the asset (Q1). A sha256 that is not 64 lower-case hex digits is `Err(None)`. An `asset_name` that is not a safe path part is `NoAsset`. A row of another target, a tag that is no nightly, and a second row of one tag and target give no release. The order is R-NS1 (the date, the month name read as a number).
expect {
	rows = [
		lin(1, t_oct14, "roc_nightly-linux_x86_64-2026-10-14-38a3029.tar.gz", h1, 1792065600123),
		{ ..lin(2, t_oct14, "roc_nightly-macos_x86_64-2026-10-14-38a3029.tar.gz", h2, 1792065600123), target: "macos_x86_64" },
		lin(3, t_jul, "roc_nightly-linux_x86_64-2026-07-31-aaaaaaa.tar.gz", h2, 1785500000999),
		lin(4, t_oct09, "roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz", "ABC", 1791500000000),
		lin(5, t_oct12, "a/b.tar.gz", h1, 1791800000000),
		lin(6, "v1.0.0", "roc_nightly-linux_x86_64-x.tar.gz", h1, 1791900000000),
		lin(7, t_oct14, "roc_nightly-linux_x86_64-other.tar.gz", h2, 1792065700000),
	]
	got = Nightlies.from_rows({ host: LinuxX64, rows })
	want = [
		{ id: t_jul, published_at: 1785500000, asset: Ok({ name: "roc_nightly-linux_x86_64-2026-07-31-aaaaaaa.tar.gz", url: dl(t_jul, "roc_nightly-linux_x86_64-2026-07-31-aaaaaaa.tar.gz"), size: 0, sha256: Ok(h2) }) },
		{ id: t_oct09, published_at: 1791500000, asset: Ok({ name: "roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz", url: dl(t_oct09, "roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz"), size: 0, sha256: Err(None) }) },
		{ id: t_oct12, published_at: 1791800000, asset: Err(NoAsset) },
		{ id: t_oct14, published_at: 1792065600, asset: Ok({ name: "roc_nightly-linux_x86_64-2026-10-14-38a3029.tar.gz", url: dl(t_oct14, "roc_nightly-linux_x86_64-2026-10-14-38a3029.tar.gz"), size: 0, sha256: Ok(h1) }) },
	]
	other = Nightlies.from_rows({ host: MacosX64, rows })
	other_ok = other.map(|r| r.id) == [t_oct14] and other.map(|r| r.asset.map_ok(|a| a.sha256)) == [Ok(Ok(h2))]
	got == want and other_ok and Nightlies.from_rows({ host: WindowsX64, rows }) == [] and Nightlies.from_rows({ host: LinuxX64, rows: [] }) == []
}

# R-CV3, R-CV5, R-CV6: the rows to record. One for each release with an asset and a sha256, in the order of the list, with the source `Registry` (the sha256 is from the registry, not a GitHub `digest`). The target is the one of the host.
expect {
	rows = [
		lin(1, t_oct14, "roc_nightly-linux_x86_64-2026-10-14-38a3029.tar.gz", h1, 1792065600123),
		lin(3, t_jul, "roc_nightly-linux_x86_64-2026-07-31-aaaaaaa.tar.gz", h2, 1785500000999),
		lin(4, t_oct09, "roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz", "ABC", 1791500000000),
		lin(5, t_oct12, "a/b.tar.gz", h1, 1791800000000),
	]
	releases = Nightlies.from_rows({ host: LinuxX64, rows })
	pins = Nightlies.registry_pins({ host: LinuxX64, releases })
	pins == [{ tag: t_jul, target: "linux_x86_64", sha256: h2, source: Registry }, { tag: t_oct14, target: "linux_x86_64", sha256: h1, source: Registry }] and Nightlies.registry_pins({ host: LinuxX64, releases: [] }) == []
}
