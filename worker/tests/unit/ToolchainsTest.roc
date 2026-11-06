import lib.Problem
import lib.Route
import lib.Toolchains

ToolchainsTest :: [].{}

# W0 tests of worker/lib/Toolchains.roc and of the toolchain rows of Route.decide (slice 109).
# The asset names, the digests and the times are real ones of roc-lang/nightlies (tests/fixtures/nightlies/, the answer of 2026-10-22).
# The times were computed with python (datetime), not with the Roc code.

hx = |c| c.repeat(64)

asset = |name, hex| { name, digest: Ok("sha256:${hex}"), size: Ok(1000) }

sized = |name, hex, size| { name, digest: Ok("sha256:${hex}"), size: Ok(size) }

# ---- Route.decide: GET /v1/toolchains (R-AP5) and PUT /v1/toolchains/{tag} (R-AP6), R-AP48 rows 1, 2 ----

input = |method, segments, content_type, has_body| { method, segments, content_type, has_body }

list_path = ["v1", "toolchains"]

tag_path = ["v1", "toolchains", "nightly-2026-10-21-5349569"]

# R-AP5, R-AP48: the list route serves GET only. Another method gets 405 with `Allow: GET`, also with a body of another media type (row 2 before row 5).
expect Route.decide(input("GET", list_path, Err(NotFound), Bool.False)) == Handle(GetToolchains)
expect Route.decide(input("POST", list_path, Ok("text/plain"), Bool.True)) == NotAllowed(Problem.new(MethodNotAllowed, "POST is not allowed on /v1/toolchains"), ["GET"])
expect Route.decide(input("PUT", list_path, Err(NotFound), Bool.False)) == NotAllowed(Problem.new(MethodNotAllowed, "PUT is not allowed on /v1/toolchains"), ["GET"])
expect Route.decide(input("DELETE", list_path, Err(NotFound), Bool.False)) == NotAllowed(Problem.new(MethodNotAllowed, "DELETE is not allowed on /v1/toolchains"), ["GET"])

# R-AP6, R-AP48: the tag route serves PUT only, and takes no body (so no media check). A path with one more segment is no route.
expect Route.decide(input("PUT", tag_path, Err(NotFound), Bool.False)) == Handle(PutToolchain("nightly-2026-10-21-5349569"))
expect Route.decide(input("PUT", tag_path, Ok("text/plain"), Bool.True)) == Handle(PutToolchain("nightly-2026-10-21-5349569"))
expect Route.decide(input("GET", tag_path, Err(NotFound), Bool.False)) == NotAllowed(Problem.new(MethodNotAllowed, "GET is not allowed on /v1/toolchains/nightly-2026-10-21-5349569"), ["PUT"])
expect Route.decide(input("PUT", ["v1", "toolchains", "a", "b"], Err(NotFound), Bool.False)) == Refuse(Problem.new(NotFound, "no route for PUT /v1/toolchains/a/b"))

# ---- constants ----

# R-CV8: the six targets, in byte order. R-CV2: the end of the name.
expect Toolchains.host_targets == ["linux_arm64", "linux_x86_64", "macos_apple_silicon", "macos_x86_64", "windows_arm64", "windows_x86_64"]
expect Toolchains.host_targets.map(Toolchains.archive_suffix) == [".tar.gz", ".tar.gz", ".tar.gz", ".tar.gz", ".zip", ".zip"]

# R-PU8: the one GitHub call.
expect Toolchains.release_url("nightly-2026-October-25-c3487d2") == "https://api.github.com/repos/roc-lang/nightlies/releases/tags/nightly-2026-October-25-c3487d2"

# ---- parse_time (R-RE4, R-AP50, R-AP57 step 5: only the form with `Z`; a GitHub time is whole seconds, the column is ms) ----

time_rows : List((Str, U64))
time_rows = [
	("1970-01-01T00:00:00Z", 0),
	("1999-12-31T23:59:59Z", 946684799000),
	("2000-02-29T00:00:00Z", 951782400000),
	("2025-10-25T09:05:00Z", 1761383100000),
	("2026-02-10T10:13:03Z", 1770718383000),
	("2026-10-21T15:01:06Z", 1792594866000),
	("2028-02-29T23:59:59Z", 1835481599000),
	("2100-02-28T23:59:59Z", 4107542399000),
]

bad_times = ["", "x", "2026-10-21", "2026-10-21 15:01:06Z", "2026-10-21T15:01:06", "2026-02-30T00:00:00Z", "2100-02-29T00:00:00Z", "2026-13-01T00:00:00Z", "2026-00-10T00:00:00Z", "2026-10-00T00:00:00Z", "2026-10-21T24:00:00Z", "2026-10-21T15:60:00Z", "2026-10-21T15:01:60Z", "26-10-21T15:01:06Z", "2026-10-21T15:01:06+00:00", "2026-10-21T15:01:06+02:00", "2026-10-21T15:01:06.000Z", "2026-10-21T15:01:06z"]

expect time_rows.map(|(text, _)| Toolchains.parse_time(text)) == time_rows.map(|(_, ms)| Ok(ms))
expect bad_times.map(Toolchains.parse_time) == bad_times.map(|_| Err(BadTime))

# ---- parse_release (R-PU8, R-AP44: unknown members are ignored) ----

# A release as GitHub sends it, with members that the Worker does not read, an asset with no `digest` and an asset with `digest` null (old uploads).
release_text = "{\"id\":1,\"tag_name\":\"nightly-2026-10-21-5349569\",\"name\":\"nightly\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-21T15:01:06Z\",\"author\":{\"login\":\"github-actions[bot]\",\"id\":41898282},\"assets\":[{\"id\":662862877,\"name\":\"echo.wasm.zst\",\"size\":7615928,\"digest\":\"sha256:217b5d49488058f425f18cfce75e8eb70dd35fecbfa52ff21d2b2227702888d2\",\"content_type\":\"application/zstd\",\"download_count\":3},{\"name\":\"old-a.tar.gz\"},{\"name\":\"old-b.tar.gz\",\"digest\":null}]}"

expect Toolchains.parse_release(release_text) == Ok({
	draft: Bool.False,
	prerelease: Bool.False,
	published_at: 1792594866000,
	assets: [
		{ name: "echo.wasm.zst", digest: Ok("sha256:217b5d49488058f425f18cfce75e8eb70dd35fecbfa52ff21d2b2227702888d2"), size: Ok(7615928) },
		{ name: "old-a.tar.gz", digest: Err(Missing), size: Err(Missing) },
		{ name: "old-b.tar.gz", digest: Err(Missing), size: Err(Missing) },
	],
})

# R-AP80, R-AP57 step 6: `size` is read as sent. A missing member, `null`, a number with a fraction and a negative number are `Err(Missing)`; 0 is `Ok(0)` (`select_assets` drops it).
# The release is not refused for such a `size`. The assets of a release with a bad `size` are read next to a good one, and the good one is kept as read.
size_assets = "[{\"name\":\"a\",\"size\":123},{\"name\":\"b\"},{\"name\":\"c\",\"size\":null},{\"name\":\"d\",\"size\":0},{\"name\":\"e\",\"size\":12.5},{\"name\":\"f\",\"size\":-5},{\"name\":\"g\",\"size\":69304823}]"

expect Toolchains.parse_release("{\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-21T15:01:06Z\",\"assets\":${size_assets}}").map_ok(|r| r.assets.map(|a| a.size)) == Ok([Ok(123), Err(Missing), Err(Missing), Ok(0), Err(Missing), Err(Missing), Ok(69304823)])

# A release with no asset (nightly-2025-November-03-4215483 is one), a draft and a prerelease (the flags are read as sent).
expect Toolchains.parse_release("{\"tag_name\":\"nightly-2025-November-03-4215483\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2025-11-03T09:26:27Z\",\"assets\":[]}") == Ok({ draft: Bool.False, prerelease: Bool.False, published_at: 1762161987000, assets: [] })
expect Toolchains.parse_release("{\"draft\":true,\"prerelease\":true,\"published_at\":\"2025-11-03T09:26:27Z\",\"assets\":[]}") == Ok({ draft: Bool.True, prerelease: Bool.True, published_at: 1762161987000, assets: [] })

# Not a release: not JSON, not an object, `assets` or `published_at` missing, null or of the wrong type, a bad time.
bad_releases = [
	"",
	"not json",
	"[]",
	"{}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-21T15:01:06Z\"}",
	"{\"draft\":false,\"prerelease\":false,\"assets\":[]}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":null,\"assets\":[]}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":\"yesterday\",\"assets\":[]}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":1792594866,\"assets\":[]}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-21T15:01:06+00:00\",\"assets\":[]}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-21T15:01:06Z\",\"assets\":\"none\"}",
	"{\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-21T15:01:06Z\",\"assets\":[{\"digest\":\"sha256:a\"}]}",
	"{\"message\":\"Not Found\",\"documentation_url\":\"https://docs.github.com/rest\"}",
]

expect bad_releases.map(Toolchains.parse_release) == bad_releases.map(|_| Err(BadRelease))

# ---- select_assets (R-CV2, R-CV3, R-CV8) ----

# nightly-2026-10-21-5349569 as roc publishes it: 5 compilers, 2 source archives, 3 wasm files. There is no windows_arm64 asset.
full_2026_10_21 = [
	asset("echo.wasm.zst", hx("1")),
	asset("playground.wasm.zst", hx("2")),
	asset("repl.wasm.zst", hx("3")),
	sized("roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", "cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5", 69304823),
	sized("roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz", "70346ac60dd0b0507881447c5b47aed799fd1bea01c50bac56f82ed96897f4df", 72460515),
	sized("roc_nightly-macos_apple_silicon-2026-10-21-5349569.tar.gz", "a8a81b5436c69eb5bf14ddc48bd9f0ef71326fd485340a4a1a7a683db442e5a6", 69461382),
	sized("roc_nightly-macos_x86_64-2026-10-21-5349569.tar.gz", "31b1c15f5627a7144e66c26695bd3fd11c1dac2f619c256398f9134c7cc9bec6", 73451421),
	asset("roc_nightly-source-2026-10-21-5349569.tar.gz", "c902cb7305d06f94cd92523fb58498f607255736185fc304535a458d26a82613"),
	asset("roc_nightly-source-2026-10-21-5349569.zip", "d5ea0dba74e5691d935450ea48193295746e72f0cbe506c1e4da1dfebded3f23"),
	sized("roc_nightly-windows_x86_64-2026-10-21-5349569.zip", "105026125c36b57b17201380c7d15dafbfd9ce663767d52989e11ffd53d2bcf7", 70319525),
]

expect Toolchains.select_assets(full_2026_10_21) == [
	{ target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", sha256: "cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5", size: 69304823 },
	{ target: "linux_x86_64", asset_name: "roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz", sha256: "70346ac60dd0b0507881447c5b47aed799fd1bea01c50bac56f82ed96897f4df", size: 72460515 },
	{ target: "macos_apple_silicon", asset_name: "roc_nightly-macos_apple_silicon-2026-10-21-5349569.tar.gz", sha256: "a8a81b5436c69eb5bf14ddc48bd9f0ef71326fd485340a4a1a7a683db442e5a6", size: 69461382 },
	{ target: "macos_x86_64", asset_name: "roc_nightly-macos_x86_64-2026-10-21-5349569.tar.gz", sha256: "31b1c15f5627a7144e66c26695bd3fd11c1dac2f619c256398f9134c7cc9bec6", size: 73451421 },
	{ target: "windows_x86_64", asset_name: "roc_nightly-windows_x86_64-2026-10-21-5349569.zip", sha256: "105026125c36b57b17201380c7d15dafbfd9ce663767d52989e11ffd53d2bcf7", size: 70319525 },
]

# R-CV2: the date and the sha in the name are not compared with the tag. nightly-2025-October-25-c3487d2 has `2025-10-25-2b89aee` in its names, and has all 6 hosts.
# The rows come in the order of `host_targets`, not the order of the assets (the assets here are in reverse order).
odd_sha = [
	sized("roc_nightly-windows_x86_64-2025-10-25-2b89aee.zip", "bdf77086fcc9da7e97df7236fde35519b1b486e56c1e7b1535e00ac7c38b69df", 35611689),
	sized("roc_nightly-windows_arm64-2025-10-25-2b89aee.zip", "f8b76a608cd8e1a573d13e90d507cea40f2b61fa1fe074e5a7b33b40f548a4f4", 32676676),
	sized("roc_nightly-macos_x86_64-2025-10-25-2b89aee.tar.gz", "22bc3a93c39170a65ad1be3e0b20f1da75019ab9741379e003f70a7ff2279332", 37302420),
	sized("roc_nightly-macos_apple_silicon-2025-10-25-2b89aee.tar.gz", "b23806251bbc1a2043db5a16e9ae00f781ce19952b1f1b59445c297bf0ab47cc", 34638701),
	sized("roc_nightly-linux_x86_64-2025-10-25-2b89aee.tar.gz", "b8effe57b39f38e1e780ac6a57d98b5983b95fc01f369ed689487901f4cdbe23", 44431265),
	sized("roc_nightly-linux_arm64-2025-10-25-2b89aee.tar.gz", "6edf3f221dd0a15036436c60dda9f78417629f41ceffffc719a1c4e021cbc045", 42789570),
]

expect Toolchains.select_assets(odd_sha).map(|p| p.target) == Toolchains.host_targets
expect Toolchains.select_assets(odd_sha).map(|p| p.asset_name) == [
	"roc_nightly-linux_arm64-2025-10-25-2b89aee.tar.gz",
	"roc_nightly-linux_x86_64-2025-10-25-2b89aee.tar.gz",
	"roc_nightly-macos_apple_silicon-2025-10-25-2b89aee.tar.gz",
	"roc_nightly-macos_x86_64-2025-10-25-2b89aee.tar.gz",
	"roc_nightly-windows_arm64-2025-10-25-2b89aee.zip",
	"roc_nightly-windows_x86_64-2025-10-25-2b89aee.zip",
]
expect Toolchains.select_assets(odd_sha).map(|p| p.size) == [42789570, 44431265, 34638701, 37302420, 32676676, 35611689]
expect Toolchains.select_assets(odd_sha).map(|p| p.sha256) == [
	"6edf3f221dd0a15036436c60dda9f78417629f41ceffffc719a1c4e021cbc045",
	"b8effe57b39f38e1e780ac6a57d98b5983b95fc01f369ed689487901f4cdbe23",
	"b23806251bbc1a2043db5a16e9ae00f781ce19952b1f1b59445c297bf0ab47cc",
	"22bc3a93c39170a65ad1be3e0b20f1da75019ab9741379e003f70a7ff2279332",
	"f8b76a608cd8e1a573d13e90d507cea40f2b61fa1fe074e5a7b33b40f548a4f4",
	"bdf77086fcc9da7e97df7236fde35519b1b486e56c1e7b1535e00ac7c38b69df",
]

# R-CV2: the names that are not an asset of a host. Each row is one name and the targets that the list `[that name, the good arm64 asset]` gives; the good
# asset (linux_arm64) is always there, so a name that counts for nothing leaves exactly it.
good_arm64 = asset("roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", hx("a"))

arm64_only = [{ target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", sha256: hx("a"), size: 1000 }]

no_asset_names = [
	"roc_nightly-linux_x86_64.tar.gz",
	"roc_nightly-linux_x86_64-1.tar.gz.sig",
	"roc_nightly-linux_x86_64-1.zip",
	"roc_nightly-windows_x86_64-1.tar.gz",
	"roc_nightly-windows_arm64-1.tar.gz",
	"Roc_nightly-linux_x86_64-1.tar.gz",
	"roc_nightly-linux_x86_64-1.TAR.GZ",
	"xroc_nightly-linux_x86_64-1.tar.gz",
	"roc_nightly-freebsd_x86_64-1.tar.gz",
	"roc_nightly-linux_x86-1.tar.gz",
	"roc_nightly-source-1.tar.gz",
	"roc_nightly-source-1.zip",
	"echo.wasm.zst",
	"playground.wasm",
	"",
	# not a safe path part (R-SE18): a name with `/` or `\` is not an asset, so it does not make the second asset of a host either
	"roc_nightly-linux_x86_64-a/b.tar.gz",
	"roc_nightly-macos_x86_64-a\\b.tar.gz",
	"roc_nightly-windows_x86_64-../x.zip",
]

expect no_asset_names.map(|name| Toolchains.select_assets([asset(name, hx("b")), good_arm64])) == no_asset_names.map(|_| arm64_only)
expect Toolchains.select_assets([]) == []
expect Toolchains.select_assets([asset("roc_nightly-source-1.zip", hx("b"))]) == []

# R-AP57 step 6, Q109-4: an asset whose `digest` is missing, `null` (both are `Err(Missing)`), or not `sha256:` and exactly 64 lower-case hex digits is not an asset for its host.
# The host gets no row, and the other hosts stay.
bad_digests : List(Try(Str, [Missing]))
bad_digests = [
	Err(Missing),
	Ok(""),
	Ok("sha256:"),
	Ok("sha256:${"a".repeat(63)}"),
	Ok("sha256:${"a".repeat(65)}"),
	Ok("sha256:${"A".repeat(64)}"),
	Ok("sha256:${"g".repeat(64)}"),
	Ok("sha512:${"a".repeat(64)}"),
	Ok("SHA256:${"a".repeat(64)}"),
	Ok("${"a".repeat(64)}"),
	Ok(" sha256:${"a".repeat(64)}"),
]

expect bad_digests.map(|dg| Toolchains.select_assets([{ name: "roc_nightly-linux_x86_64-a.tar.gz", digest: dg, size: Ok(1000) }, good_arm64])) == bad_digests.map(|_| arm64_only)

# A bad digest also does not count for the rule of 2 assets: the other asset of the host is the one asset.
expect Toolchains.select_assets([{ name: "roc_nightly-linux_x86_64-a.tar.gz", digest: Err(Missing), size: Ok(1000) }, good_arm64, asset("roc_nightly-linux_x86_64-b.tar.gz", hx("d"))]) == [
	{ target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", sha256: hx("a"), size: 1000 },
	{ target: "linux_x86_64", asset_name: "roc_nightly-linux_x86_64-b.tar.gz", sha256: hx("d"), size: 1000 },
]

# Two assets that both have a valid digest are still 2.
# R-AP80, R-AP57 step 6: an asset whose `size` is missing (or `null`, a fraction, a negative number: all `Err(Missing)`) or 0 is not an asset for its host. The other hosts stay.
bad_sizes : List(Try(U64, [Missing]))
bad_sizes = [Err(Missing), Ok(0)]

expect bad_sizes.map(|sz| Toolchains.select_assets([{ name: "roc_nightly-linux_x86_64-a.tar.gz", digest: Ok("sha256:${hx("c")}"), size: sz }, good_arm64])) == bad_sizes.map(|_| arm64_only)

# A bad `size` also does not count for the rule of 2 assets, and the size of the good asset is the one in the row. A size of 1 is good.
expect Toolchains.select_assets([{ name: "roc_nightly-linux_x86_64-a.tar.gz", digest: Ok("sha256:${hx("c")}"), size: Ok(0) }, good_arm64, sized("roc_nightly-linux_x86_64-b.tar.gz", hx("d"), 1)]) == [
	{ target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", sha256: hx("a"), size: 1000 },
	{ target: "linux_x86_64", asset_name: "roc_nightly-linux_x86_64-b.tar.gz", sha256: hx("d"), size: 1 },
]

# R-CV2: a host with 2 or more assets is not a candidate on that host. The other hosts stay.
expect Toolchains.select_assets([asset("roc_nightly-linux_x86_64-a.tar.gz", hx("c")), good_arm64, asset("roc_nightly-linux_x86_64-b.tar.gz", hx("d"))]) == arm64_only
expect Toolchains.select_assets([good_arm64, asset("roc_nightly-windows_x86_64-a.zip", hx("c")), asset("roc_nightly-windows_x86_64-b.zip", hx("d")), asset("roc_nightly-windows_x86_64-c.zip", hx("e"))]) == arm64_only

# R-CV2: an asset with a quote in the name counts (the rule is the safe path part only). Its name is kept as it is.
expect Toolchains.select_assets([asset("roc_nightly-linux_arm64-a\"b.tar.gz", hx("f"))]) == [{ target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-a\"b.tar.gz", sha256: hx("f"), size: 1000 }]

# ---- leaf_of, writes_of (R-SG3, R-SG8 rows 1, 2, 6, R-PU9) ----

# R-SG3: the group, the version and the hash of a compiler leaf. R-SG8 row 2: the time is the time of the write.
expect Toolchains.leaf_of({ target: "linux_x86_64", tag: "nightly-2026-10-21-5349569", sha256: hx("a"), now_ms: 1767225600000 }) == {
	grp: "roc-lang/nightlies:linux_x86_64",
	version: "nightly-2026-10-21-5349569",
	hash: "sha256:${hx("a")}",
	time: 1767225600000,
}

# The tag text is kept as it is (the other form of CLI 6.2, R-CV1, stays a tag text).
expect Toolchains.leaf_of({ target: "windows_arm64", tag: "nightly-2025-October-25-c3487d2", sha256: hx("0"), now_ms: 5 }).version == "nightly-2025-October-25-c3487d2"

# R-PU9, R-AP80: one write for each asset, with the `size` of the asset and the leaf of the asset (the leaf has no `size`). The nightly id (R-IK4) and `published_at` are the same in each.
picked_two = [
	{ target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-a.tar.gz", sha256: hx("a"), size: 4096 },
	{ target: "windows_x86_64", asset_name: "roc_nightly-windows_x86_64-a.zip", sha256: hx("b"), size: 8192 },
]

expect Toolchains.writes_of({ tag: "nightly-2025-October-25-c3487d2", nightly: 5472529975250, published_at: 1761383100000, now_ms: 1767225600000, picked: picked_two }) == [
	{
		nightly: 5472529975250,
		tag: "nightly-2025-October-25-c3487d2",
		target: "linux_arm64",
		asset_name: "roc_nightly-linux_arm64-a.tar.gz",
		sha256: hx("a"),
		size: 4096,
		published_at: 1761383100000,
		leaf: { grp: "roc-lang/nightlies:linux_arm64", version: "nightly-2025-October-25-c3487d2", hash: "sha256:${hx("a")}", time: 1767225600000 },
	},
	{
		nightly: 5472529975250,
		tag: "nightly-2025-October-25-c3487d2",
		target: "windows_x86_64",
		asset_name: "roc_nightly-windows_x86_64-a.zip",
		sha256: hx("b"),
		size: 8192,
		published_at: 1761383100000,
		leaf: { grp: "roc-lang/nightlies:windows_x86_64", version: "nightly-2025-October-25-c3487d2", hash: "sha256:${hx("b")}", time: 1767225600000 },
	},
]
expect Toolchains.writes_of({ tag: "t", nightly: 1, published_at: 2, now_ms: 3, picked: [] }) == []

# ---- the steps of PUT (R-AP57) ----

rec = |tag, target, i| { tag, target, asset_name: "a", sha256: hx("a"), size: 4096, published_at: 1761383100000, log_index: i }

# Step 1: a tag with no nightly id is 422 and nothing else happens (no D1 call, no GitHub call). Else the next action is the D1 read of the id: D1 comes first, GitHub is
# not an action here (step 2 before step 3).
expect Toolchains.start("v1.2.3", Err(NotANightly)) == Refuse(Problem.new(NotACandidate, "the tag v1.2.3 is not a nightly tag"))
expect Toolchains.start("nightly-2026-02-30-1234567", Err(NotANightly)) == Refuse(Toolchains.not_nightly("nightly-2026-02-30-1234567"))
expect Toolchains.start("nightly-2025-October-25-c3487d2", Ok(5472529975250)) == ReadRows(5472529975250)
expect Toolchains.not_nightly("x").http_status() == 422

# Step 2: no row: read GitHub. Rows of this tag (one or all): answer with them, no GitHub call. A row of another tag text with the same id: 422 with that tag.
expect Toolchains.after_rows("nightly-2025-October-25-c3487d2", []) == ReadGithub
expect Toolchains.after_rows("nightly-2025-October-25-c3487d2", [rec("nightly-2025-October-25-c3487d2", "linux_arm64", 1)]) == Answer([rec("nightly-2025-October-25-c3487d2", "linux_arm64", 1)])
expect Toolchains.after_rows("nightly-2025-October-25-c3487d2", [rec("nightly-2025-October-25-c3487d2", "linux_arm64", 1), rec("nightly-2025-October-25-c3487d2", "windows_x86_64", 2)]) == Answer([rec("nightly-2025-October-25-c3487d2", "linux_arm64", 1), rec("nightly-2025-October-25-c3487d2", "windows_x86_64", 2)])
expect Toolchains.after_rows("nightly-2025-10-25-c3487d2", [rec("nightly-2025-October-25-c3487d2", "linux_arm64", 1), rec("nightly-2025-October-25-c3487d2", "windows_x86_64", 2)]) == Refuse(Toolchains.id_taken("nightly-2025-10-25-c3487d2", "nightly-2025-October-25-c3487d2"))
expect Toolchains.after_rows("nightly-2025-October-25-c3487d2", [rec("nightly-2025-10-25-c3487d2", "macos_x86_64", 3)]) == Refuse(Toolchains.id_taken("nightly-2025-October-25-c3487d2", "nightly-2025-10-25-c3487d2"))

# Steps 4 and 6: a draft or a prerelease is 422 for the whole tag, also with good assets. A release with no asset left is 422. Else the picked assets.
full_release = { draft: Bool.False, prerelease: Bool.False, published_at: 1792594866000, assets: full_2026_10_21 }

expect Toolchains.candidates("nightly-2026-10-21-5349569", full_release) == Ok(Toolchains.select_assets(full_2026_10_21))
expect Toolchains.candidates("nightly-2026-10-21-5349569", { ..full_release, draft: Bool.True }) == Err(Toolchains.not_final("nightly-2026-10-21-5349569"))
expect Toolchains.candidates("nightly-2026-10-21-5349569", { ..full_release, prerelease: Bool.True }) == Err(Toolchains.not_final("nightly-2026-10-21-5349569"))
expect Toolchains.candidates("nightly-2026-10-21-5349569", { ..full_release, draft: Bool.True, prerelease: Bool.True, assets: [] }) == Err(Toolchains.not_final("nightly-2026-10-21-5349569"))
expect Toolchains.candidates("nightly-2025-November-03-4215483", { ..full_release, assets: [] }) == Err(Toolchains.no_candidate("nightly-2025-November-03-4215483"))
expect Toolchains.candidates("nightly-2026-10-28-fffffff", { ..full_release, assets: [asset("roc_nightly-source-1.zip", hx("b")), { name: "roc_nightly-linux_arm64-1.tar.gz", digest: Err(Missing), size: Ok(1000) }] }) == Err(Toolchains.no_candidate("nightly-2026-10-28-fffffff"))
expect Toolchains.candidates("nightly-2026-10-28-fffffff", { ..full_release, assets: [{ name: "roc_nightly-linux_arm64-1.tar.gz", digest: Ok("sha256:${hx("a")}"), size: Ok(0) }, { name: "roc_nightly-macos_x86_64-1.tar.gz", digest: Ok("sha256:${hx("a")}"), size: Err(Missing) }] }) == Err(Toolchains.no_candidate("nightly-2026-10-28-fffffff"))
expect Toolchains.not_final("x").http_status() == 422

# Step 7: 201 when a `toolchains` statement of the batch changed a row. 200 when the batch wrote nothing, because another request wrote the tag between the two D1 calls (a race that W2 cannot make).
expect [[1, 1, 1, 1, 1], [1], [0, 1], [0, 0, 0, 1, 0], [0, 0], [0], []].map(Toolchains.put_status) == [201, 201, 201, 201, 200, 200, 200]

# ---- parse_query (R-AP5, R-AP56, R-AP48 row 6) ----

query = |after, target| { after, target }

none = Err(NotFound)

expect Toolchains.parse_query(query(none, none)) == Ok({ after: 0, target: Err(None) })
expect Toolchains.parse_query(query(Ok("0"), none)) == Ok({ after: 0, target: Err(None) })
expect Toolchains.parse_query(query(Ok("1000"), none)) == Ok({ after: 1000, target: Err(None) })
expect Toolchains.parse_query(query(Ok("9223372036854775807"), none)) == Ok({ after: 9223372036854775807, target: Err(None) })
expect Toolchains.parse_query(query(Ok("10"), none)) == Ok({ after: 10, target: Err(None) })
expect Toolchains.parse_query(query(none, Ok("linux_x86_64"))) == Ok({ after: 0, target: Ok("linux_x86_64") })
expect Toolchains.parse_query(query(Ok("17"), Ok("windows_arm64"))) == Ok({ after: 17, target: Ok("windows_arm64") })

# R-AP56: `target` is any text, also an empty one and one that the registry does not know (200 with no rows, not 400).
expect Toolchains.parse_query(query(none, Ok(""))) == Ok({ after: 0, target: Ok("") })
expect Toolchains.parse_query(query(none, Ok("x64musl"))) == Ok({ after: 0, target: Ok("x64musl") })

# R-AP56: `after` is decimal digits with no leading zero, at most 2^63 - 1. The text is in the `detail` as it was sent.
bad_after = ["", "-1", "+1", "1.5", "abc", "1e3", " 1", "1 ", "0x10", "007", "00", "01", "9223372036854775808", "18446744073709551615", "18446744073709551616", "99999999999999999999"]

expect bad_after.map(|text| Toolchains.parse_query(query(Ok(text), none))) == bad_after.map(|text| Err(Problem.new(BadRequest, "the query parameter after must be a log index (decimal digits), got ${text}")))
expect Toolchains.parse_query(query(Ok("x"), Ok("linux_x86_64"))) == Err(Problem.new(BadRequest, "the query parameter after must be a log index (decimal digits), got x"))

# ---- page_of (R-AP5, R-AP47) ----

row = |i| rec("t", "linux_x86_64", i)

rows_to = |n| Iter.fold(U64.to(1, n), [], |acc, i| acc.append(row(i)))

page_sizes = |n| {
	page = Toolchains.page_of(rows_to(n))
	(page.rows.len(), page.more)
}

# R-AP5: at most 1000 rows; `more` is true only when a row follows the page. 1000 rows exactly: no more. 1001 rows: 1000 and more.
expect [0, 1, 999, 1000, 1001, 1500].map(page_sizes) == [(0, Bool.False), (1, Bool.False), (999, Bool.False), (1000, Bool.False), (1000, Bool.True), (1000, Bool.True)]

# R-AP47: the page keeps the first rows in the order given, so the next `after` is the `log_index` of the last row.
expect Toolchains.page_of(rows_to(1001)).rows.map(|r| r.log_index) == Iter.fold(U64.to(1, 1000), [], |acc, i| acc.append(i))
expect Toolchains.page_of([row(5), row(9)]) == { rows: [row(5), row(9)], more: Bool.False }

# ---- the bodies (R-AP5, R-AP6, R-AP24) ----

one = { tag: "nightly-2026-10-21-5349569", target: "linux_arm64", asset_name: "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz", sha256: "cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5", size: 69304823, published_at: 1792594866000, log_index: 7 }

one_text = "{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_arm64\",\"asset_name\":\"roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz\",\"sha256\":\"cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5\",\"size\":69304823,\"published_at\":1792594866000,\"log_index\":7}"

# R-AP80: the member order is fixed (`size` after `sha256`), there is no white space, and a list of rows is in the order given.
expect Toolchains.put_body([]) == "{\"toolchains\":[]}"
expect Toolchains.put_body([one]) == "{\"toolchains\":[${one_text}]}"
expect Toolchains.put_body([one, { ..one, log_index: 8, target: "windows_arm64" }]) == "{\"toolchains\":[${one_text},{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"windows_arm64\",\"asset_name\":\"roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz\",\"sha256\":\"cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5\",\"size\":69304823,\"published_at\":1792594866000,\"log_index\":8}]}"
expect Toolchains.page_body({ rows: [], more: Bool.False }) == "{\"toolchains\":[],\"more\":false}"
expect Toolchains.page_body({ rows: [one], more: Bool.True }) == "{\"toolchains\":[${one_text}],\"more\":true}"

# An asset name can have a quote (R-SE18 allows it): the text is escaped as JSON.
expect Toolchains.put_body([{ ..one, asset_name: "roc_nightly-linux_arm64-a\"b.tar.gz" }]) == "{\"toolchains\":[{\"tag\":\"nightly-2026-10-21-5349569\",\"target\":\"linux_arm64\",\"asset_name\":\"roc_nightly-linux_arm64-a\\\"b.tar.gz\",\"sha256\":\"cb6cbe82e45ba284d5b01910e8e91a978701ffed3c2baf2c9a88baa4adc369f5\",\"size\":69304823,\"published_at\":1792594866000,\"log_index\":7}]}"

# ---- the problems (R-AP6, R-AP21): the kind, the status and the text ----

expect Toolchains.no_release("nightly-2026-10-21-5349569") == Problem.new(NotFound, "roc-lang/nightlies has no release with the tag nightly-2026-10-21-5349569")
expect Toolchains.no_release("nightly-2026-10-21-5349569").http_status() == 404
expect Toolchains.no_candidate("nightly-2025-November-03-4215483").http_status() == 422
expect Toolchains.id_taken("nightly-2025-10-25-c3487d2", "nightly-2025-October-25-c3487d2") == Problem.new(NotACandidate, "the tag nightly-2025-10-25-c3487d2 has the same nightly id as the recorded tag nightly-2025-October-25-c3487d2")
expect [Toolchains.github_status(500), Toolchains.github_status(403), Toolchains.github_no_answer, Toolchains.github_bad].map(|p| p.http_status()) == [502, 502, 502, 502]
expect Toolchains.github_status(403) == Problem.new(Upstream, "the GitHub release read failed with status 403")
