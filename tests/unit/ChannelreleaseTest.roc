import lib.Clock
import lib.Nightlies

ChannelreleaseTest :: [].{}

# Slice 239 (docs/slices/239-github-release-shape.md), R-CH4 R-CH5 R-CH9, Design Q612 (G-C242), Design Q614. Shape `github-release` over a channel table.
# New names for the code agent (a proposal; until they exist this file does not compile: red on purpose, as slice 238 did):
#   A channel entry is the record `{ name : Str, source : Str, tag_prefix : Str }` (the shape is `github-release`; `Channel.builtin` has the same values).
#   `Nightlies.parts_of : Str, Str -> Try({ year : U64, month : U64, day : U64, sha : Str }, [NotNightly])`   (tag-prefix, tag). `Nightlies.parts(tag)` is `parts_of("nightly-", tag)`.
#   `Nightlies.id_of : { name : Str, tag_prefix : Str, tag : Str } -> Try(Str, [NotBuild])`   (the id of a tag, R-CH5).
#   `Nightlies.asset_prefix : { tag_prefix : Str, host : Nightlies.Host } -> Str`   (R-CH4: "roc_" + tag-prefix + target + "-").
#   `Nightlies.releases_of : { host, pages, channel : <entry> } -> Try(List(Release), [BadPage(U64)])`. `Nightlies.releases(f)` is `releases_of` with the `nightly` entry.
#   `Nightlies.visible` gets two optional fields: `channels ?: List(<entry>)` (the tables that give the R-C15 name to an id) and `recorded ?: List({ id : Str, source : Str })` (the `source` of the `.talon.json` of an installed build, Design Q614 item 6).
# Design Q614 item 7: a user-channel tag has the form `<tag-prefix><YYYY-MM-DD>-<sha>`; an English month name is read for the `nightly` table only. Item 8: the asset URL is `browser_download_url`.
# The expected values are the design text (CLI 6.8 R-CH4, R-CH5, R-CH9; R-CV1, R-CV2, R-CV3), not the code.

nightly = { name: "nightly", source: "roc-lang/nightlies", tag_prefix: "nightly-" }

reify = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

mine = { name: "mine", source: "someone/roc-builds", tag_prefix: "v-" }

at : Str -> U64
at = |text| match Clock.parse_utc(text) {
	Ok(t) => t
	Err(_) => 0
}

hex64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

asset : { name : Str, size : U64, digest : Str } -> Str
asset = |a| {
	digest = if a.digest == "" "" else ",\"digest\":${a.digest}"
	"{\"id\":9,\"name\":\"${a.name}\",\"size\":${a.size.to_str()}${digest},\"content_type\":\"application/gzip\",\"browser_download_url\":\"http://127.0.0.1:1/dl/x/${a.name}\"}"
}

release : { tag : Str, draft : Bool, pre : Bool, published : Str, assets : List(Str) } -> Str
release = |r| {
	published = if r.published == "null" "null" else "\"${r.published}\""
	"{\"id\":1,\"tag_name\":\"${r.tag}\",\"name\":\"${r.tag}\",\"draft\":${if r.draft "true" else "false"},\"prerelease\":${if r.pre "true" else "false"},\"published_at\":${published},\"assets\":[${Str.join_with(r.assets, ",")}]}"
}

plain : { tag : Str, published : Str, assets : List(Str) } -> Str
plain = |r| release({ tag: r.tag, draft: Bool.False, pre: Bool.False, published: r.published, assets: r.assets })

page : List(Str) -> Str
page = |releases| "[${Str.join_with(releases, ",")}]"

linux : Str, Str -> Str
linux = |prefix, date_sha| asset({ name: "${prefix}linux_x86_64-${date_sha}.tar.gz", size: 22, digest: "\"sha256:${hex64}\"" })

rel : Str, Str -> Nightlies.Release
rel = |id, published| { id, published_at: at(published), asset: Err(NoAsset) }

# R-CH4 R-CH5: `parts_of` reads `<tag-prefix><date>-<sha>`. The prefix may hold `-`. A tag of another channel is `NotNightly` for this table: the nightly table does not read
# `nightly-reify-...` (the rest is not a date), and the reify table does not read `nightly-2026-11-09-9e85de7`. The month name form works for each prefix. A tag with `-safe` is no build.
expect {
	d = |y, m, day, sha| Ok({ year: y, month: m, day, sha })
	rows = [
		("nightly: number form", Nightlies.parts_of("nightly-", "nightly-2026-10-09-258ab27"), d(2026, 10, 9, "258ab27")),
		("nightly: month name", Nightlies.parts_of("nightly-", "nightly-2026-July-31-123c5d7"), d(2026, 7, 31, "123c5d7")),
		("nightly: reify tag", Nightlies.parts_of("nightly-", "nightly-reify-2026-11-03-1708298"), Err(NotNightly)),
		("nightly: -safe tag", Nightlies.parts_of("nightly-", "nightly-2026-11-09-9e85de7-safe"), Err(NotNightly)),
		("reify: its tag", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-11-03-1708298"), d(2026, 11, 3, "1708298")),
		("reify: month name is no build (Q614 item 7)", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-July-31-123c5d7"), Err(NotNightly)),
		("v-: month name is no build", Nightlies.parts_of("v-", "v-2026-July-31-123c5d7"), Err(NotNightly)),
		("reify: nightly tag", Nightlies.parts_of("nightly-reify-", "nightly-2026-11-09-9e85de7"), Err(NotNightly)),
		("reify: no prefix", Nightlies.parts_of("nightly-reify-", "2026-11-03-1708298"), Err(NotNightly)),
		("reify: short sha", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-11-03-170829"), Err(NotNightly)),
		("reify: sha not hex", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-11-03-170829z"), Err(NotNightly)),
		("reify: day of 1 digit", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-11-3-1708298"), Err(NotNightly)),
		("reify: month in lower case", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-july-31-123c5d7"), Err(NotNightly)),
		("reify: extra part", Nightlies.parts_of("nightly-reify-", "nightly-reify-2026-11-03-1708298-safe"), Err(NotNightly)),
		("reify: the prefix only", Nightlies.parts_of("nightly-reify-", "nightly-reify-"), Err(NotNightly)),
		("v-: its tag", Nightlies.parts_of("v-", "v-2026-11-03-abcdef1"), d(2026, 11, 3, "abcdef1")),
		("v-: a version tag", Nightlies.parts_of("v-", "v-1.2.3"), Err(NotNightly)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH2 main guard: `parts` is the nightly table. The same answer as `parts_of("nightly-", ...)` for the tag forms that exist.
expect {
	tags = ["nightly-2026-10-09-258ab27", "nightly-2026-July-31-123c5d7", "nightly-2025-October-25-c3487d2", "nightly-reify-2026-11-03-1708298", "nightly-latest", "0.1.0", ""]
	bad = tags.keep_if(|t| Nightlies.parts(t) != Nightlies.parts_of("nightly-", t))
	dbg bad
	bad == [] and Nightlies.parts("nightly-2026-July-31-123c5d7") == Ok({ year: 2026, month: 7, day: 31, sha: "123c5d7" })
}

# R-CH5: the id is `<name>-<date>-<sha>`. For `nightly` it is the tag text, also with the month name. For `reify` the id drops the tag-prefix and takes the name. For
# `mine` (tag-prefix `v-`) the id is `mine-` and the date and sha. A tag that this table does not read has no id.
expect {
	rows = [
		("nightly: number form", Nightlies.id_of({ name: "nightly", tag_prefix: "nightly-", tag: "nightly-2026-11-09-9e85de7" }), Ok("nightly-2026-11-09-9e85de7")),
		("nightly: month name", Nightlies.id_of({ name: "nightly", tag_prefix: "nightly-", tag: "nightly-2026-July-31-123c5d7" }), Ok("nightly-2026-July-31-123c5d7")),
		("reify", Nightlies.id_of({ name: "reify", tag_prefix: "nightly-reify-", tag: "nightly-reify-2026-11-03-1708298" }), Ok("reify-2026-11-03-1708298")),
		("mine", Nightlies.id_of({ name: "mine", tag_prefix: "v-", tag: "v-2026-11-03-abcdef1" }), Ok("mine-2026-11-03-abcdef1")),
		("reify: month name tag", Nightlies.id_of({ name: "reify", tag_prefix: "nightly-reify-", tag: "nightly-reify-2026-July-31-123c5d7" }), Err(NotBuild)),
		("reify: a nightly tag", Nightlies.id_of({ name: "reify", tag_prefix: "nightly-reify-", tag: "nightly-2026-11-09-9e85de7" }), Err(NotBuild)),
		("nightly: a reify tag", Nightlies.id_of({ name: "nightly", tag_prefix: "nightly-", tag: "nightly-reify-2026-11-03-1708298" }), Err(NotBuild)),
		("reify: -safe", Nightlies.id_of({ name: "reify", tag_prefix: "nightly-reify-", tag: "nightly-reify-2026-11-03-1708298-safe" }), Err(NotBuild)),
		("mine: a version", Nightlies.id_of({ name: "mine", tag_prefix: "v-", tag: "v-1.2.3" }), Err(NotBuild)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH4: the asset prefix is `"roc_" + <tag-prefix> + <target> + "-"`, for each host. `nightly` keeps `roc_nightly-<target>-` (R-CV2).
expect {
	hosts = [LinuxX64, LinuxArm64, MacosApple, MacosX64, WindowsX64, WindowsArm64]
	nightly_got = hosts.map(|h| Nightlies.asset_prefix({ tag_prefix: "nightly-", host: h }))
	reify_got = hosts.map(|h| Nightlies.asset_prefix({ tag_prefix: "nightly-reify-", host: h }))
	nightly_want = ["roc_nightly-linux_x86_64-", "roc_nightly-linux_arm64-", "roc_nightly-macos_apple_silicon-", "roc_nightly-macos_x86_64-", "roc_nightly-windows_x86_64-", "roc_nightly-windows_arm64-"]
	reify_want = ["roc_nightly-reify-linux_x86_64-", "roc_nightly-reify-linux_arm64-", "roc_nightly-reify-macos_apple_silicon-", "roc_nightly-reify-macos_x86_64-", "roc_nightly-reify-windows_x86_64-", "roc_nightly-reify-windows_arm64-"]
	dbg reify_got
	nightly_got == nightly_want and reify_got == reify_want
		and Nightlies.asset_prefix({ tag_prefix: "v-", host: LinuxX64 }) == "roc_v-linux_x86_64-"
}

# R-CH4 R-DI3 R-CV2 R-CV3: the builds of a `reify` list for LinuxX64. A draft and a prerelease are skipped. A nightly tag and a tag with `-safe` are skipped. A release of another
# prefix is skipped. The id is `reify-<date>-<sha>`. The asset is the one that starts with `roc_nightly-reify-linux_x86_64-`: the asset of a nightly (`roc_nightly-linux_x86_64-...`)
# and `roc_nightly-reify-source-...` are not compilers, so a build that has only those has `NoAsset`. 2 assets for the host: `Several(2)`. The sha256 is the digest.
# The month name tag is no build of a user channel (Q614 item 7). The URL is the `browser_download_url` of the answer (Q614 item 8). The tags and times are made up, except `nightly-reify-2026-11-03-1708298` (the real release of 2026-11-03).
expect {
	p = "roc_nightly-reify-"
	page1 = page([
		plain({ tag: "nightly-reify-2026-11-03-1708298", published: "2026-11-03T10:00:00Z", assets: [linux(p, "2026-11-03-1708298")] }),
		release({ tag: "nightly-reify-2026-11-04-aaaaaaa", draft: Bool.True, pre: Bool.False, published: "null", assets: [linux(p, "2026-11-04-aaaaaaa")] }),
		release({ tag: "nightly-reify-2026-11-05-bbbbbbb", draft: Bool.False, pre: Bool.True, published: "2026-11-05T10:00:00Z", assets: [linux(p, "2026-11-05-bbbbbbb")] }),
		plain({ tag: "nightly-2026-11-06-ccccccc", published: "2026-11-06T10:00:00Z", assets: [linux("roc_nightly-", "2026-11-06-ccccccc")] }),
		plain({ tag: "nightly-reify-2026-11-03-1708298-safe", published: "2026-11-03T10:00:01Z", assets: [linux(p, "2026-11-03-1708298")] }),
		plain({ tag: "nightly-reify-2026-July-31-123c5d7", published: "2026-07-31T10:00:00Z", assets: [linux(p, "2026-07-31-123c5d7")] }),
	])
	page2 = page([
		plain({ tag: "nightly-reify-2026-11-07-ddddddd", published: "2026-11-07T10:00:00Z", assets: [linux("roc_nightly-", "2026-11-07-ddddddd"), asset({ name: "roc_nightly-reify-source-2026-11-07-ddddddd.tar.gz", size: 5, digest: "" })] }),
		plain({ tag: "nightly-reify-2026-11-08-eeeeeee", published: "2026-11-08T10:00:00Z", assets: [linux(p, "2026-11-08-eeeeeee"), asset({ name: "${p}linux_x86_64-2026-11-08-eeeeeee.zip", size: 6, digest: "" }), asset({ name: "${p}linux_x86_64-x.tar.gz", size: 7, digest: "" })] }),
	])
	got = match Nightlies.releases_of({ host: LinuxX64, pages: [page1, page2], channel: reify }) {
		Ok(list) => Ok(list.map(|r| (r.id, r.published_at, r.asset.map_ok(|a| (a.name, a.url, a.sha256)).map_err(|e| e))))
		Err(e) => Err(e)
	}
	want = Ok([
		("reify-2026-11-03-1708298", at("2026-11-03T10:00:00Z"), Ok(("roc_nightly-reify-linux_x86_64-2026-11-03-1708298.tar.gz", "http://127.0.0.1:1/dl/x/roc_nightly-reify-linux_x86_64-2026-11-03-1708298.tar.gz", Ok(hex64)))),
		("reify-2026-11-07-ddddddd", at("2026-11-07T10:00:00Z"), Err(NoAsset)),
		("reify-2026-11-08-eeeeeee", at("2026-11-08T10:00:00Z"), Err(Several(2))),
	])
	dbg got
	got == want
}

# R-CH4 main guard (R-CV1, R-CV2): the `nightly` table through the generic code gives the same list as `releases`: the id is the tag text, a reify tag is skipped, the month name tag
# stays in its form, the asset is `roc_nightly-<target>-`.
expect {
	l = |date_sha| [linux("roc_nightly-", date_sha)]
	pages = [
		page([
			plain({ tag: "nightly-2026-10-14-38a3029", published: "2026-10-14T15:03:00Z", assets: l("2026-10-14-38a3029") }),
			plain({ tag: "nightly-reify-2026-11-03-1708298", published: "2026-11-03T10:00:00Z", assets: [linux("roc_nightly-reify-", "2026-11-03-1708298")] }),
			plain({ tag: "nightly-2026-July-31-f5556d8", published: "2026-07-31T11:56:54Z", assets: l("2026-07-31-f5556d8") }),
			plain({ tag: "nightly-2026-11-09-9e85de7-safe", published: "2026-11-09T11:00:00Z", assets: l("2026-11-09-9e85de7") }),
		]),
	]
	via_old = Nightlies.releases({ host: LinuxX64, pages })
	via_table = Nightlies.releases_of({ host: LinuxX64, pages, channel: nightly })
	ids = match via_table {
		Ok(list) => list.map(|r| r.id)
		Err(_) => []
	}
	dbg ids
	via_old == via_table and ids == ["nightly-2026-July-31-f5556d8", "nightly-2026-10-14-38a3029"]
}

# R-CH4 (BadPage, as `releases`): a page that is not a list, and a build with a bad time, are `BadPage(n)` for a user channel too. A tag of another prefix has its time unread.
expect {
	ok_build = plain({ tag: "nightly-reify-2026-11-03-1708298", published: "2026-11-03T10:00:00Z", assets: [] })
	bad_time = plain({ tag: "nightly-reify-2026-11-04-1708299", published: "yesterday", assets: [] })
	other_time = release({ tag: "nightly-2026-11-05-ccccccc", draft: Bool.False, pre: Bool.False, published: "null", assets: [] })
	run = |pages| Nightlies.releases_of({ host: LinuxX64, pages, channel: reify }).map_ok(|l| l.len())
	run([page([ok_build]), "{\"message\":\"Not Found\"}"]) == Err(BadPage(2))
		and run([page([bad_time])]) == Err(BadPage(1))
			and run([page([other_time])]) == Ok(0)
				and run([]) == Ok(0)
}

# R-CH9 R-NS1: a channel is ordered alone, by the date of the id (the year, the month, the day), then `published_at`, then the text. A later
# date is later also when its `published_at` is earlier. The id `reify-...` has a date for the order (before slice 239 it had none, so only `published_at` counted).
expect {
	a = rel("reify-2026-11-03-1708298", "2026-11-09T10:00:00Z")
	b = rel("reify-2026-11-05-bbbbbbb", "2026-11-05T10:00:00Z")
	c = rel("reify-2026-07-31-123c5d7", "2026-12-01T10:00:00Z")
	d = rel("reify-2026-11-05-aaaaaaa", "2026-11-05T09:00:00Z")
	e = rel("reify-2026-11-05-ccccccc", "2026-11-05T09:00:00Z")
	got = Nightlies.order([b, a, e, c, d]).map(|r| r.id)
	dbg got
	got == [c.id, a.id, d.id, e.id, b.id]
}

# R-CH9: `min-release-age` uses `published_at` (R-C7) for a build of a user channel as for a nightly. The R-C15 name of a build is the `source` of its channel: the pattern
# `Karakatiza666/roc-reify-nightlies` and `Karakatiza666/*` lift the age of `reify-...`; `roc-lang/nightlies` and `roc-lang/*` do not. A nightly keeps `roc-lang/nightlies`
# (so `Karakatiza666/*` does not lift it). 2 days old or more is visible; the order stays. `now` is made up.
expect {
	now = at("2026-11-09T12:00:00Z")
	day = 86400
	old_n = rel("nightly-2026-11-05-ccccccc", "2026-11-05T12:00:00Z")
	new_n = rel("nightly-2026-11-09-9e85de7", "2026-11-09T06:00:00Z")
	old_r = rel("reify-2026-11-03-1708298", "2026-11-03T10:00:00Z")
	new_r = rel("reify-2026-11-08-eeeeeee", "2026-11-08T10:00:00Z")
	list = [old_r, old_n, new_r, new_n]
	see = |exclude, min_age| Nightlies.visible({ list, now, min_age, snapshot: Err(None), keep: [], exclude, channels: [nightly, reify] }).map(|r| r.id)
	rows = [
		("no pattern: the old builds", see([], 2 * day), [old_r.id, old_n.id]),
		("min_age 0: all", see([], 0), [old_r.id, old_n.id, new_r.id, new_n.id]),
		("the source of reify", see(["Karakatiza666/roc-reify-nightlies"], 2 * day), [old_r.id, old_n.id, new_r.id]),
		("the owner wildcard of reify", see(["Karakatiza666/*"], 2 * day), [old_r.id, old_n.id, new_r.id]),
		("roc-lang/nightlies: only the nightly", see(["roc-lang/nightlies"], 2 * day), [old_r.id, old_n.id, new_n.id]),
		("roc-lang/roc: none", see(["roc-lang/roc"], 2 * day), [old_r.id, old_n.id]),
		("both sources", see(["roc-lang/nightlies", "Karakatiza666/*"], 2 * day), [old_r.id, old_n.id, new_r.id, new_n.id]),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH9 R-C15 (Design Q614 item 6): a build whose table is unknown has the name of the `source` that its `.talon.json` recorded. With no recorded source no pattern matches, so the age
# hides it (also for `*/*`-like patterns that match nothing, and `Karakatiza666/*`). A known table wins nothing here: the recorded source is used only when the table is missing.
expect {
	now = at("2026-11-09T12:00:00Z")
	day = 86400
	new_r = rel("reify-2026-11-08-eeeeeee", "2026-11-08T10:00:00Z")
	recorded = [{ id: new_r.id, source: "Karakatiza666/roc-reify-nightlies" }]
	see = |exclude, rec| Nightlies.visible({ list: [new_r], now, min_age: 2 * day, snapshot: Err(None), keep: [], exclude, channels: [], recorded: rec }).map(|r| r.id)
	see(["Karakatiza666/*"], recorded) == [new_r.id]
		and see(["Karakatiza666/roc-reify-nightlies"], recorded) == [new_r.id]
			and see(["roc-lang/*"], recorded) == []
				and see(["Karakatiza666/*"], []) == []
					and see([], recorded) == []
}
