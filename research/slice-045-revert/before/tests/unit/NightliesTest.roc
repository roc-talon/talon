import lib.Clock
import lib.Fail
import lib.Nightlies

NightliesTest :: [].{}

# The expected value of each row is the design text, not the code. A wrong row prints with `dbg`.
# The tags and the times in the rows are real ones from `roc-lang/nightlies` (the answer of 2026-10-22), unless a comment says that a row is made up.

# Seconds since the epoch of an RFC 3339 time.
at : Str -> U64
at = |text| match Clock.parse_utc(text) {
	Ok(t) => t
	Err(_) => 0
}

hex64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

## One asset of the answer, with fields that Talon does not read. `digest` is the JSON text of the field, or the empty text for no field.
asset : { name : Str, size : U64, digest : Str } -> Str
asset = |a| {
	digest = if a.digest == "" "" else ",\"digest\":${a.digest}"
	"{\"id\":9,\"name\":\"${a.name}\",\"size\":${a.size.to_str()}${digest},\"content_type\":\"application/gzip\",\"browser_download_url\":\"http://127.0.0.1:1/dl/x/${a.name}\"}"
}

## One release of the answer. `published` is a time or `null`. `assets` is `Err(Missing)` for a release with no `assets` field.
release : { tag : Str, draft : Bool, pre : Bool, published : Str, assets : Try(List(Str), [Missing]) } -> Str
release = |r| {
	published = if r.published == "null" "null" else "\"${r.published}\""
	assets = match r.assets {
		Ok(list) => ",\"assets\":[${Str.join_with(list, ",")}]"
		Err(Missing) => ""
	}
	"{\"id\":1,\"tag_name\":\"${r.tag}\",\"name\":\"${r.tag}\",\"draft\":${if r.draft "true" else "false"},\"prerelease\":${if r.pre "true" else "false"},\"published_at\":${published},\"body\":\"notes\",\"author\":{\"login\":\"github-actions[bot]\",\"id\":2}${assets}}"
}

plain : { tag : Str, published : Str, assets : List(Str) } -> Str
plain = |r| release({ tag: r.tag, draft: Bool.False, pre: Bool.False, published: r.published, assets: Ok(r.assets) })

page : List(Str) -> Str
page = |releases| "[${Str.join_with(releases, ",")}]"

## The assets of one nightly as roc publishes them (2026-10-21): 5 hosts, 2 source archives, wasm files.
full_assets : Str -> List(Str)
full_assets = |date_sha| [
	asset({ name: "echo.wasm.zst", size: 7615928, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-linux_arm64-${date_sha}.tar.gz", size: 11, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-linux_x86_64-${date_sha}.tar.gz", size: 22, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-macos_apple_silicon-${date_sha}.tar.gz", size: 33, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-macos_x86_64-${date_sha}.tar.gz", size: 44, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-source-${date_sha}.tar.gz", size: 55, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-source-${date_sha}.zip", size: 66, digest: "\"sha256:${hex64}\"" }),
	asset({ name: "roc_nightly-windows_x86_64-${date_sha}.zip", size: 77, digest: "\"sha256:${hex64}\"" }),
]

rel : Str, Str -> Nightlies.Release
rel = |id, published| { id, published_at: at(published), asset: Err(NoAsset) }

ids_of : List(Nightlies.Release) -> List(Str)
ids_of = |list| list.map(|r| r.id)

# R-CV1: the two tag forms that roc reads. `nightly-YYYY-MM-DD-<sha>`, and the month as an English name in full with a capital letter. The parts have the number of
# the month (all 12 names), so the two forms of one date give the same date. A text that is not a nightly tag is `NotNightly`: no `nightly-latest`, a release version,
# a tag with no sha, a sha that is not hex, a sha of fewer than 7 digits, a month name in lower case or short, a day that is not 2 digits.
expect {
	names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	by_name = names.map_with_index(|name, i| ("nightly-2026-${name}-05-abcdef1", Ok({ year: 2026, month: i + 1, day: 5, sha: "abcdef1" })))
	rows = by_name.concat([
		("nightly-2026-10-09-258ab27", Ok({ year: 2026, month: 10, day: 9, sha: "258ab27" })),
		("nightly-2026-July-31-123c5d7", Ok({ year: 2026, month: 7, day: 31, sha: "123c5d7" })),
		("nightly-2025-October-25-c3487d2", Ok({ year: 2025, month: 10, day: 25, sha: "c3487d2" })),
		("nightly-latest", Err(NotNightly)),
		("0.1.0", Err(NotNightly)),
		("v0.1.0", Err(NotNightly)),
		("nightly-2026-10-09", Err(NotNightly)),
		("nightly-2026-10-09-xyz1234", Err(NotNightly)),
		("nightly-2026-10-09-258ab2", Err(NotNightly)),
		("nightly-2026-10-09-abc12", Err(NotNightly)),
		("nightly-2026-july-31-123c5d7", Err(NotNightly)),
		("nightly-2026-Jul-31-123c5d7", Err(NotNightly)),
		("nightly-2026-10-9-258ab27", Err(NotNightly)),
		("nightly-2026-10-09-258ab27-extra", Err(NotNightly)),
		("", Err(NotNightly)),
	])
	bad = rows.keep_if(|(text, want)| Nightlies.parts(text) != want).map(|(text, want)| (text, want, Nightlies.parts(text)))
	dbg bad
	bad == []
}

# R-CV1 R-DI3 R-NS1: the list of a release list of 2 pages. The id is the tag text, in both forms. A draft and a prerelease are skipped (R-DI3), and a draft has no
# `published_at`. A tag that is not a nightly is not a compiler: `v0.1.0` (with a Linux asset), `nightly-latest`. A nightly with no asset stays in the list
# (the asset is `NoAsset`). The result is in the order of R-NS1, the oldest first, also across the pages. (The tags `nightly-2026-10-15-aaaaaaa`, `nightly-2026-10-16-bbbbbbb`,
# `v0.1.0` and `nightly-latest` are made up.)
expect {
	linux = |date_sha| [asset({ name: "roc_nightly-linux_x86_64-${date_sha}.tar.gz", size: 22, digest: "\"sha256:${hex64}\"" })]
	page1 = page([
		plain({ tag: "nightly-2026-10-14-38a3029", published: "2026-10-14T15:03:00Z", assets: linux("2026-10-14-38a3029") }),
		release({ tag: "nightly-2026-10-15-aaaaaaa", draft: Bool.True, pre: Bool.False, published: "null", assets: Ok(linux("2026-10-15-aaaaaaa")) }),
		release({ tag: "nightly-2026-10-16-bbbbbbb", draft: Bool.False, pre: Bool.True, published: "2026-10-16T15:00:00Z", assets: Ok(linux("2026-10-16-bbbbbbb")) }),
		plain({ tag: "v0.1.0", published: "2026-10-17T10:00:00Z", assets: linux("v0.1.0") }),
		plain({ tag: "nightly-latest", published: "2026-10-18T10:00:00Z", assets: linux("latest") }),
	])
	page2 = page([
		plain({ tag: "nightly-2026-August-05-24f0b47", published: "2026-08-05T11:00:00Z", assets: linux("2026-08-05-24f0b47") }),
		plain({ tag: "nightly-2025-November-03-4215483", published: "2025-11-03T09:26:27Z", assets: [] }),
		plain({ tag: "nightly-2026-July-31-f5556d8", published: "2026-07-31T11:56:54Z", assets: linux("2026-07-31-f5556d8") }),
	])
	got = match Nightlies.releases({ host: LinuxX64, pages: [page1, page2] }) {
		Ok(list) => Ok(list.map(|r| (r.id, r.published_at, r.asset.is_ok())))
		Err(e) => Err(e)
	}
	want = Ok([
		("nightly-2025-November-03-4215483", at("2025-11-03T09:26:27Z"), Bool.False),
		("nightly-2026-July-31-f5556d8", at("2026-07-31T11:56:54Z"), Bool.True),
		("nightly-2026-August-05-24f0b47", at("2026-08-05T11:00:00Z"), Bool.True),
		("nightly-2026-10-14-38a3029", at("2026-10-14T15:03:00Z"), Bool.True),
	])
	dbg got
	empty = Nightlies.releases({ host: LinuxX64, pages: [] }) == Ok([])
	got == want and empty
}

# R-DI3 R-CV1: a page that is not a JSON array of objects, a release with no text `tag_name`, and a nightly (not draft, not prerelease) with no `published_at` that
# Talon reads, are `BadPage(n)` with the number of the page. The time of a draft is not read, so `null` there is no error. The time of a tag that is no nightly
# is not read either.
expect {
	ok_release = plain({ tag: "nightly-2026-10-14-38a3029", published: "2026-10-14T15:03:00Z", assets: [] })
	no_time = release({ tag: "nightly-2026-10-19-601b54c", draft: Bool.False, pre: Bool.False, published: "null", assets: Ok([]) })
	bad_time = plain({ tag: "nightly-2026-10-19-601b54c", published: "yesterday", assets: [] })
	no_tag = "{\"id\":1,\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-14T15:03:00Z\",\"assets\":[]}"
	skipped_time = release({ tag: "nightly-2026-10-20-7a8a800", draft: Bool.True, pre: Bool.False, published: "null", assets: Ok([]) })
	other_time = release({ tag: "v0.1.0", draft: Bool.False, pre: Bool.False, published: "null", assets: Ok([]) })
	run = |pages| Nightlies.releases({ host: LinuxX64, pages })
	rows = [
		(run([page([ok_release]), "{\"message\":\"Not Found\"}"]), Err(BadPage(2))),
		(run(["not json"]), Err(BadPage(1))),
		(run([page([ok_release]), page([no_time])]), Err(BadPage(2))),
		(run([page([bad_time])]), Err(BadPage(1))),
		(run([page([no_tag])]), Err(BadPage(1))),
		(run([page(["[1]"])]), Err(BadPage(1))),
	]
	bad = rows.map_with_index(|(got, want), i| (i, got.map_ok(|l| l.len()), want)).keep_if(|(_, got, want)| got != want)
	dbg bad
	fine = run([page([skipped_time, other_time, ok_release])]).map_ok(ids_of) == Ok(["nightly-2026-10-14-38a3029"])
	bad == [] and fine
}

# R-CV2 R-CV7: the asset for a host is the one asset whose name starts with `roc_nightly-<target>-` and ends with `.tar.gz`, or `.zip` for Windows. The `-` after the
# target is part of the prefix (`linux_x86_64_musl` is not `linux_x86_64`: made up). A `.zip` for Linux and a `.tar.gz` for Windows are not it (made up). The source
# archives and the wasm files are not compilers. The url, the size and the name are the ones of the asset. The date and the sha of the asset name are not compared with the
# tag (the real release `nightly-2026-February-10-c95f04d` has `ea7058b`). A release with 2 assets for a host is `Several(2)` on that host only. A release with no
# assets (a missing field, an empty list) and one with only source and wasm assets is `NoAsset`. The release stays in the list in each case.
expect {
	tricky = [
		asset({ name: "roc_nightly-linux_x86_64_musl-2026-10-21-5349569.tar.gz", size: 1, digest: "\"sha256:${hex64}\"" }),
		asset({ name: "roc_nightly-linux_x86_64-2026-10-21-5349569.zip", size: 2, digest: "\"sha256:${hex64}\"" }),
		asset({ name: "roc_nightly-windows_x86_64-2026-10-21-5349569.tar.gz", size: 3, digest: "\"sha256:${hex64}\"" }),
		asset({ name: "roc_nightly-windows_arm64-2026-10-21-5349569.zip", size: 88, digest: "\"sha256:${hex64}\"" }),
	]
	main = plain({ tag: "nightly-2026-10-21-5349569", published: "2026-10-21T15:01:06Z", assets: full_assets("2026-10-21-5349569").concat(tricky) })
	feb = plain({ tag: "nightly-2026-February-10-c95f04d", published: "2026-02-10T10:13:03Z", assets: full_assets("2026-02-10-ea7058b") })
	two = plain({
		tag: "nightly-2026-January-01-2c1b41a",
		published: "2026-01-01T09:31:27Z",
		assets: [
			asset({ name: "roc_nightly-linux_x86_64-2026-01-01-aaaaaaa.tar.gz", size: 1, digest: "\"sha256:${hex64}\"" }),
			asset({ name: "roc_nightly-linux_x86_64-2026-01-01-bbbbbbb.tar.gz", size: 2, digest: "\"sha256:${hex64}\"" }),
			asset({ name: "roc_nightly-macos_x86_64-2026-01-01-aaaaaaa.tar.gz", size: 3, digest: "\"sha256:${hex64}\"" }),
		],
	})
	none = release({ tag: "nightly-2025-November-03-4215483", draft: Bool.False, pre: Bool.False, published: "2025-11-03T09:26:27Z", assets: Err(Missing) })
	only_other = plain({
		tag: "nightly-2025-November-02-186d4d2",
		published: "2025-11-02T09:21:40Z",
		assets: [asset({ name: "roc_nightly-source-2025-11-02-186d4d2.tar.gz", size: 1, digest: "" }), asset({ name: "playground.wasm", size: 2, digest: "" })],
	})
	pages = [page([main, feb, two, none, only_other])]
	# (id, name, size, url) of the asset of each release for a host, or the reason
	view = |host| match Nightlies.releases({ host, pages }) {
		Ok(list) => list.map(|r| (r.id, r.asset.map_ok(|a| (a.name, a.size, a.url)))).keep_if(|(id, _)| id != "nightly-2025-November-02-186d4d2" and id != "nightly-2025-November-03-4215483")
		Err(_) => []
	}
	url = |name| "http://127.0.0.1:1/dl/x/${name}"
	lin = view(LinuxX64)
	want_lin = [
		("nightly-2026-January-01-2c1b41a", Err(Several(2))),
		("nightly-2026-February-10-c95f04d", Ok(("roc_nightly-linux_x86_64-2026-02-10-ea7058b.tar.gz", 22, url("roc_nightly-linux_x86_64-2026-02-10-ea7058b.tar.gz")))),
		("nightly-2026-10-21-5349569", Ok(("roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz", 22, url("roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz")))),
	]
	pick_name = |rows| rows.map(|(id, a)| (id, a.map_ok(|(name, _, _)| name))).keep_if(|(id, _)| id == "nightly-2026-10-21-5349569")
	names = [
		(LinuxArm64, "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz"),
		(MacosApple, "roc_nightly-macos_apple_silicon-2026-10-21-5349569.tar.gz"),
		(MacosX64, "roc_nightly-macos_x86_64-2026-10-21-5349569.tar.gz"),
		(WindowsX64, "roc_nightly-windows_x86_64-2026-10-21-5349569.zip"),
		(WindowsArm64, "roc_nightly-windows_arm64-2026-10-21-5349569.zip"),
	]
	bad_names = names.keep_if(|(host, name)| pick_name(view(host)) != [("nightly-2026-10-21-5349569", Ok(name))])
	all_listed = Nightlies.releases({ host: LinuxX64, pages }).map_ok(ids_of) == Ok([
		"nightly-2025-November-02-186d4d2",
		"nightly-2025-November-03-4215483",
		"nightly-2026-January-01-2c1b41a",
		"nightly-2026-February-10-c95f04d",
		"nightly-2026-10-21-5349569",
	])
	no_asset = Nightlies.releases({ host: LinuxX64, pages }).map_ok(|l| l.keep_if(|r| r.id == "nightly-2025-November-03-4215483" or r.id == "nightly-2025-November-02-186d4d2").map(|r| r.asset.map_ok(|_| 0)))
	# the 2 assets of `two` are for Linux x86_64 only: macOS x86_64 has one
	mac_two = view(MacosX64).keep_if(|(id, _)| id == "nightly-2026-January-01-2c1b41a")
	# R-CV2, R-CV8: a nightly with no asset for the host is not a candidate on it. The newer nightlies have no `windows_arm64` asset (the real
	# `nightly-2026-02-10` too): `Err(NoAsset)`. Candidates are the nightlies with one asset: for Linux x86_64 the 3 with an asset and not the one with 2 assets, not the 2 with none.
	arm_feb = view(WindowsArm64).keep_if(|(id, _)| id == "nightly-2026-February-10-c95f04d")
	cands = |host| match Nightlies.releases({ host, pages }) {
		Ok(list) => Nightlies.candidates(list).map(|r| r.id)
		Err(_) => []
	}
	dbg lin
	dbg bad_names
	arm_feb == [("nightly-2026-February-10-c95f04d", Err(NoAsset))] and cands(LinuxX64) == ["nightly-2026-February-10-c95f04d", "nightly-2026-10-21-5349569"] and cands(WindowsArm64) == ["nightly-2026-10-21-5349569"] and lin == want_lin and bad_names == [] and all_listed and no_asset == Ok([Err(NoAsset), Err(NoAsset)]) and mac_two == [("nightly-2026-January-01-2c1b41a", Ok(("roc_nightly-macos_x86_64-2026-01-01-aaaaaaa.tar.gz", 3, url("roc_nightly-macos_x86_64-2026-01-01-aaaaaaa.tar.gz"))))]
}

# R-CV3: the sha256 is the `digest` of the asset of the host: the text `sha256:` and 64 hex digits (lower case) give the digits. No field, null, another algorithm,
# a short or long digit run, a text with a digit that is not hex, and a text with no `sha256:` give no sha256 (`Err(None)`: the install stops with exit 16, R-CV4).
# The digest of another asset of the release does not count (the source archive has a good digest, the Linux asset has none). Made-up rows, except the good one.
expect {
	sha = |digest| {
		a = asset({ name: "roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz", size: 22, digest })
		other = asset({ name: "roc_nightly-source-2026-10-21-5349569.tar.gz", size: 55, digest: "\"sha256:${hex64}\"" })
		r = plain({ tag: "nightly-2026-10-21-5349569", published: "2026-10-21T15:01:06Z", assets: [other, a] })
		match Nightlies.releases({ host: LinuxX64, pages: [page([r])] }) {
			Ok([one]) => one.asset.map_ok(|x| x.sha256)
			_ => Err(NoAsset)
		}
	}
	rows = [
		("\"sha256:${hex64}\"", Ok(Ok(hex64))),
		("", Ok(Err(None))),
		("null", Ok(Err(None))),
		("\"sha1:0123456789abcdef0123456789abcdef01234567\"", Ok(Err(None))),
		("\"sha256:0123456789abcdef\"", Ok(Err(None))),
		("\"sha256:${hex64}0\"", Ok(Err(None))),
		("\"sha256:g123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"", Ok(Err(None))),
		("\"${hex64}\"", Ok(Err(None))),
		("\"sha256:\"", Ok(Err(None))),
		("7", Ok(Err(None))),
	]
	bad = rows.keep_if(|(digest, want)| sha(digest) != want).map(|(digest, want)| (digest, want, sha(digest)))
	dbg bad
	bad == []
}

# R-NS1: the order, the oldest first. The date of the tag first, with the month as its number: `October` is before `November` (as text it is after), and the 2 tag forms
# are one order. The same date: `published_at`, then the tag text in byte order. The real pair of `nightly-2026-July-23` is in the order of `published_at`, which is
# not the order of the tag text (`fdd77c3` is after `306abd6` as text). A later date is later also when its `published_at` is earlier (made up: `ccccccc`).
# Two with the same date and the same `published_at` are in the order of the tag text (made up). The order does not depend on the order of the input.
expect {
	g = rel("nightly-2025-October-25-c3487d2", "2025-10-25T09:05:00Z")
	h = rel("nightly-2025-November-03-4215483", "2025-11-03T09:26:27Z")
	f = rel("nightly-2026-July-23-fdd77c3", "2026-07-23T06:04:47Z")
	e = rel("nightly-2026-July-23-306abd6", "2026-07-23T11:30:53Z")
	a = rel("nightly-2026-July-31-f5556d8", "2026-07-31T11:56:54Z")
	b = rel("nightly-2026-08-06-61bbb59", "2026-08-06T11:50:16Z")
	c = rel("nightly-2026-09-01-24e3995", "2026-09-01T12:41:53Z")
	d = rel("nightly-2026-09-01-db83307", "2026-09-01T16:08:38Z")
	j = rel("nightly-2026-10-01-aaaaaaa", "2026-10-01T09:00:00Z")
	i = rel("nightly-2026-10-01-bbbbbbb", "2026-10-01T09:00:00Z")
	k = rel("nightly-2026-10-03-ccccccc", "2026-10-01T00:00:00Z")
	want = [g, h, f, e, a, b, c, d, j, i, k].map(|r| r.id)
	one = Nightlies.order([k, i, d, h, f, a, g, j, e, c, b]).map(|r| r.id)
	two = Nightlies.order([b, c, d, e, f, g, h, i, j, k, a]).map(|r| r.id)
	three = Nightlies.order([a, b, c, d, e, f, g, h, i, j, k]).map(|r| r.id)
	dbg one
	one == want and two == want and three == want and Nightlies.order([]) == []
}

# R-C7 R-NS3 R-RU1 R-DT4 R-C9: `min-release-age` and the time snapshot hide new compilers. A nightly is visible when it is at least `min_age` old: exactly 2 days is visible,
# 1 second less is not ("at least 2 days old"). `min_age` 0 hides nothing (`"0d"`). With a snapshot time, a nightly published after it is hidden, one published at that
# time is not. `keep` ids are never hidden (R-C9). The order of the list stays. Times are real ones, `now` is made up.
expect {
	now = at("2026-10-22T12:00:00Z")
	day = 86400
	r1 = rel("nightly-2026-10-19-601b54c", "2026-10-19T17:08:30Z")
	r2 = rel("nightly-2026-10-20-7a8a800", "2026-10-20T12:00:00Z")
	r3 = rel("nightly-2026-10-20-7a8a801", "2026-10-20T12:00:01Z")
	r4 = rel("nightly-2026-10-21-5349569", "2026-10-21T15:01:06Z")
	r5 = rel("nightly-2026-07-31-f5556d8", "2026-07-31T11:56:54Z")
	list = [r1, r2, r3, r4, r5]
	see = |facts| Nightlies.visible({ list, now, min_age: facts.min_age, snapshot: facts.snapshot, keep: facts.keep }).map(|r| r.id)
	age2 = see({ min_age: 2 * day, snapshot: Err(None), keep: [] })
	off = see({ min_age: 0, snapshot: Err(None), keep: [] })
	snap = see({ min_age: 0, snapshot: Ok(at("2026-10-19T17:08:30Z")), keep: [] })
	both = see({ min_age: 2 * day, snapshot: Ok(at("2026-10-19T17:08:29Z")), keep: [] })
	kept = see({ min_age: 2 * day, snapshot: Ok(at("2026-10-19T17:08:30Z")), keep: [r4.id, r2.id] })
	dbg age2
	dbg snap
	age2 == [r1.id, r2.id, r5.id]
		and off == [r1.id, r2.id, r3.id, r4.id, r5.id]
			and snap == [r1.id, r5.id]
				and both == [r5.id]
					and kept == [r1.id, r2.id, r4.id, r5.id]
}

# R-CV8: the target of each host in the name of an asset.
expect {
	rows = [
		(LinuxX64, "linux_x86_64"),
		(LinuxArm64, "linux_arm64"),
		(MacosApple, "macos_apple_silicon"),
		(MacosX64, "macos_x86_64"),
		(WindowsX64, "windows_x86_64"),
		(WindowsArm64, "windows_arm64"),
	]
	bad = rows.keep_if(|(host, want)| Nightlies.target(host) != want)
	dbg bad
	bad == []
}

ids = [
	"nightly-2025-October-25-c3487d2",
	"nightly-2026-July-23-fdd77c3",
	"nightly-2026-July-23-306abd6",
	"nightly-2026-July-31-f5556d8",
	"nightly-2026-08-06-61bbb59",
	"nightly-2026-09-01-24e3995",
	"nightly-2026-09-01-db83307",
	"nightly-2026-10-19-601b54c",
	"nightly-2026-10-21-5349569",
]

# R-SL5 R-SL7 R-NS3 R-NS4 R-CV1 R-NS1: `@latest` is the last id of `auto`. `@-N` and `@+N` are the id N places before and after the base in `auto` (the order of R-NS1:
# the 2 nightlies of one date are 2 steps). A base in the other tag form is found (R-CV1): its neighbors are the same. A step past the end is `OutOfRange` with the base and
# the step. No base is `NoBase`. A base that is not in the list is `BaseNotListed` (question Q3). An empty `auto` is `Empty`. A name is looked up in `named`, not in `auto`: the
# 2 newest nightlies are hidden from `auto` (min-release-age), and the full id of the newest still gives itself (R-NS4, R-C7).
expect {
	auto = ids.drop_last(2)
	pick = |text, base| Nightlies.pick({ text, named: ids, auto: ids, base })
	idx = |n| match ids.get(n) {
		Ok(id) => id
		Err(_) => "?"
	}
	rows = [
		(pick("@latest", Err(None)), Ok(idx(8))),
		(pick("@-1", Ok(idx(6))), Ok(idx(5))),
		(pick("@+1", Ok(idx(6))), Ok(idx(7))),
		(pick("@-2", Ok(idx(4))), Ok(idx(2))),
		(pick("@+2", Ok(idx(6))), Ok(idx(8))),
		(pick("@+3", Ok(idx(6))), Err(OutOfRange({ base: idx(6), step: 3 }))),
		(pick("@-1", Ok(idx(0))), Err(OutOfRange({ base: idx(0), step: -1 }))),
		(pick("@-1", Ok("nightly-2026-07-23-306abd6")), Ok(idx(1))),
		(pick("@+1", Ok("nightly-2026-07-31-f5556d8")), Ok(idx(4))),
		(pick("@-1", Err(None)), Err(NoBase)),
		(pick("@-1", Ok("nightly-2026-12-31-ffffff0")), Err(BaseNotListed("nightly-2026-12-31-ffffff0"))),
		(Nightlies.pick({ text: "@latest", named: ids, auto: [], base: Err(None) }), Err(Empty)),
		(Nightlies.pick({ text: "@latest", named: ids, auto, base: Err(None) }), Ok(idx(6))),
		(Nightlies.pick({ text: idx(8), named: ids, auto, base: Err(None) }), Ok(idx(8))),
		(Nightlies.pick({ text: "@+1", named: ids, auto, base: Ok(idx(6)) }), Err(OutOfRange({ base: idx(6), step: 1 }))),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	bad == []
}

# R-SC10 R-SC11 R-SC13 R-CV1 R-SL6: an argument of `tln roc ...` is expanded to the full id (`roc +<id>` and `tln roc default` use the same function, R-SC11 and R-SC13). A full id
# of `named` is itself. A full id in the other tag form (the same date and sha) is the id of `named`, so the tag text (R-CV1), also after `@` (R-SL6). A prefix is a prefix of the text in
# byte order: one match gives its id, 2 or more are `Ambiguous` with the ids in the order of `named`, none is `NoMatch`. A prefix of another kind of id (`git-`) works the same.
expect {
	named = ids.concat(["git-dd03c09e", "git-dd03c19f"])
	pick = |text| Nightlies.pick({ text, named, auto: ids, base: Err(None) })
	rows = [
		(pick("nightly-2026-10-21-5349569"), Ok("nightly-2026-10-21-5349569")),
		(pick("nightly-2026-10-21"), Ok("nightly-2026-10-21-5349569")),
		(pick("nightly-2025-Oct"), Ok("nightly-2025-October-25-c3487d2")),
		(pick("nightly-2026-10"), Err(Ambiguous({ text: "nightly-2026-10", ids: ["nightly-2026-10-19-601b54c", "nightly-2026-10-21-5349569"] }))),
		(pick("nightly-2026-09-01"), Err(Ambiguous({ text: "nightly-2026-09-01", ids: ["nightly-2026-09-01-24e3995", "nightly-2026-09-01-db83307"] }))),
		(pick("nightly-2026-July-23"), Err(Ambiguous({ text: "nightly-2026-July-23", ids: ["nightly-2026-July-23-fdd77c3", "nightly-2026-July-23-306abd6"] }))),
		(pick("git-dd03c0"), Ok("git-dd03c09e")),
		(pick("git-dd03"), Err(Ambiguous({ text: "git-dd03", ids: ["git-dd03c09e", "git-dd03c19f"] }))),
		(pick("nightly-2026-11"), Err(NoMatch("nightly-2026-11"))),
		(pick("nightly-2026-07-31-f5556d8"), Ok("nightly-2026-July-31-f5556d8")),
		(pick("@nightly-2026-07-31-f5556d8"), Ok("nightly-2026-July-31-f5556d8")),
		(pick("nightly-2026-August-06-61bbb59"), Ok("nightly-2026-08-06-61bbb59")),
		(pick("nightly-2026-07-31-0000000"), Err(NoMatch("nightly-2026-07-31-0000000"))),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	# An exact id wins over a longer id that it prefixes (the shas of 7 and of 8 digits), as a git ref does (review of slice 020, Q4). A shorter prefix of both is ambiguous.
	short = "nightly-2026-10-09-258ab27"
	long = "nightly-2026-10-09-258ab27f"
	two = |text| Nightlies.pick({ text, named: [short, long], auto: [], base: Err(None) })
	exact = [
		(two(short), Ok(short)),
		(two(long), Ok(long)),
		(two("nightly-2026-10-09-258ab2"), Err(Ambiguous({ text: "nightly-2026-10-09-258ab2", ids: [short, long] }))),
	]
	bad_exact = exact.keep_if(|(got, want)| got != want)
	dbg bad_exact
	bad == [] and bad_exact == []
}

# The failure of each `PickError` (a proposal, TW24): the kind and the text. `Empty` is the exit code 10 of R-NS2. A step of 1 is `1 step`, others are `steps`, `older` for a
# negative step and `newer` for a positive one. The failure of a missing base is the kind `Environment` of R-SO14 (exit 18).
expect {
	rows = [
		(Empty, Fail.new(NoTuple, "no compiler release is known")),
		(NoMatch("nightly-2026-11"), Fail.new(Usage, "no compiler matches nightly-2026-11")),
		(
			Ambiguous({ text: "nightly-2026-09-01", ids: ["nightly-2026-09-01-24e3995", "nightly-2026-09-01-db83307"] }),
			Fail.new(Usage, "nightly-2026-09-01 matches 2 compilers: nightly-2026-09-01-24e3995, nightly-2026-09-01-db83307. Use a longer prefix or the full id."),
		),
		(NoBase, Fail.new(Environment, "no compiler is selected, so a relative step has no start. Run: tln roc install @latest and tln roc default <id>")),
		(BaseNotListed("nightly-2026-12-31-ffffff0"), Fail.new(Usage, "nightly-2026-12-31-ffffff0 is not in the list of compilers, so a relative step has no start")),
		(OutOfRange({ base: "nightly-2025-October-25-c3487d2", step: -1 }), Fail.new(Usage, "no compiler is 1 step older than nightly-2025-October-25-c3487d2")),
		(OutOfRange({ base: "nightly-2026-09-01-db83307", step: 3 }), Fail.new(Usage, "no compiler is 3 steps newer than nightly-2026-09-01-db83307")),
	]
	bad = rows.keep_if(|(error, want)| Nightlies.failure(error) != want).map(|(error, want)| (error, want, Nightlies.failure(error)))
	dbg bad
	bad == [] and Nightlies.failure(Empty).kind.code() == 10 and Nightlies.failure(NoBase).kind.code() == 18
}
