import lib.Ident
import lib.Index

IndexTest :: [].{}

# Real hashes (base58 of 32 bytes).
h1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h2 = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h3 = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h4 = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

h5 = "6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS"

h6 = "7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW"

h7 = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"

h8 = "HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU"

# Not hashes: a letter that is not in the base58 alphabet (0), and a text of 39 characters (fewer than 32 bytes).
bad_alphabet = "0LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

too_short = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8Q"

## One release of the GitHub answer, with fields that Talon does not read. `assets` are (name, size) pairs.
release : { repo : Str, tag : Str, draft : Bool, pre : Bool, published : Str, assets : List((Str, U64)) } -> Str
release = |r| {
	asset = |(name, size)| "{\"id\":7,\"name\":\"${name}\",\"size\":${size.to_str()},\"download_count\":3,\"browser_download_url\":\"https://github.com/acme/${r.repo}/releases/download/${r.tag}/${name}\"}"
	published = if r.published == "null" "null" else "\"${r.published}\""
	"{\"id\":1,\"tag_name\":\"${r.tag}\",\"name\":\"x\",\"draft\":${if r.draft "true" else "false"},\"prerelease\":${if r.pre "true" else "false"},\"published_at\":${published},\"body\":\"notes with \\\"quotes\\\"\",\"author\":{\"login\":\"a\",\"id\":2},\"assets\":[${Str.join_with(r.assets.map(asset), ",")}]}"
}

page : List(Str) -> Str
page = |releases| "[${Str.join_with(releases, ",")}]"

view : Try({ list : List(Index.Candidate), warnings : List(Str) }, [BadPage(U64)]) -> Try({ list : List((Str, Str, Str, Str, U64, U64, Str)), warnings : List(Str) }, [BadPage(U64)])
view = |r| match r {
	Ok(found) => Ok({ list: found.list.map(|c| (c.tag, c.ident.version, c.ident.series, c.ident.group.form, c.published_at, c.size, c.url)), warnings: found.warnings })
	Err(e) => Err(e)
}

# R-DI3 R-DI4 R-DI5 R-DI10 R-DI14 R-DA6: the candidates of a release list (2 pages). A draft and a prerelease are skipped (R-DI3). The package asset is the one asset
# `<hash>.tar.zst` with a base58 hash of 32 bytes: `docs.tar.gz`, `<hash>.tar.zst.intoto.jsonl`, a name with a bad hash and a bare hash with no `.tar.zst`
# (`1.5.0`: it is not a second asset, so the release is a candidate with no warning) do not count. None: no candidate.
# Two: no candidate and a warning (R-DI4). The version and the group come from the asset URL with the roc rule: a tag with no `X.Y.Z`, with 2 runs
# or `0.0.0` is not a candidate. The text of the tag around the run is part of the group: `v1.7.0` is not in the group of `2.1.0`, and `0.26.0-rc1`
# has its own group (R-DI5). The release time is `published_at` (R-DI10), the size is the size of the asset (R-DA6). The order of the pages stays.
expect {
	page1 = page([
		release({ repo: "json", tag: "2.1.0", draft: Bool.False, pre: Bool.False, published: "2026-10-10T10:00:00Z", assets: [("docs.tar.gz", 500), ("${h1}.tar.zst", 1000), ("${h1}.tar.zst.intoto.jsonl", 300)] }),
		release({ repo: "json", tag: "2.2.0-rc1", draft: Bool.False, pre: Bool.True, published: "2026-10-12T10:00:00Z", assets: [("${h2}.tar.zst", 1100)] }),
		release({ repo: "json", tag: "2.2.0", draft: Bool.True, pre: Bool.False, published: "null", assets: [("${h2}.tar.zst", 1100)] }),
		release({ repo: "json", tag: "2.0.5", draft: Bool.False, pre: Bool.False, published: "2026-09-01T09:30:00Z", assets: [("${h3}.tar.zst", 2000)] }),
		release({ repo: "json", tag: "1.9.0", draft: Bool.False, pre: Bool.False, published: "2026-08-01T08:00:00Z", assets: [("${h4}.tar.zst", 10), ("${h5}.tar.zst", 20)] }),
		release({ repo: "json", tag: "1.8.0", draft: Bool.False, pre: Bool.False, published: "2026-07-20T08:00:00Z", assets: [("docs.tar.gz", 5)] }),
		release({ repo: "json", tag: "1.8.1", draft: Bool.False, pre: Bool.False, published: "2026-07-21T08:00:00Z", assets: [("${bad_alphabet}.tar.zst", 5), ("${too_short}.tar.zst", 5)] }),
	])
	page2 = page([
		release({ repo: "json", tag: "v1.7.0", draft: Bool.False, pre: Bool.False, published: "2026-07-01T07:00:00Z", assets: [("${h6}.tar.zst", 3000)] }),
		release({ repo: "json", tag: "1.5.0", draft: Bool.False, pre: Bool.False, published: "2026-06-25T07:00:00Z", assets: [("${h2}", 7), ("${h3}.tar.zst", 8)] }),
		release({ repo: "json", tag: "nightly", draft: Bool.False, pre: Bool.False, published: "2026-06-20T07:00:00Z", assets: [("${h7}.tar.zst", 1)] }),
		release({ repo: "json", tag: "1.0.0-to-2.0.0", draft: Bool.False, pre: Bool.False, published: "2026-06-10T07:00:00Z", assets: [("${h7}.tar.zst", 1)] }),
		release({ repo: "json", tag: "0.0.0", draft: Bool.False, pre: Bool.False, published: "2026-06-05T07:00:00Z", assets: [("${h7}.tar.zst", 1)] }),
		release({ repo: "json", tag: "0.26.0-rc1", draft: Bool.False, pre: Bool.False, published: "2026-06-01T06:00:00Z", assets: [("${h8}.tar.zst", 4000)] }),
	])
	form = "github.com/acme/json/releases/download"
	want = Ok({
		list: [
			("2.1.0", "2.1.0", "2", "${form}/{v}/", 1791626400, 1000, "https://github.com/acme/json/releases/download/2.1.0/${h1}.tar.zst"),
			("2.0.5", "2.0.5", "2", "${form}/{v}/", 1788255000, 2000, "https://github.com/acme/json/releases/download/2.0.5/${h3}.tar.zst"),
			("v1.7.0", "1.7.0", "1", "${form}/v{v}/", 1782889200, 3000, "https://github.com/acme/json/releases/download/v1.7.0/${h6}.tar.zst"),
			("1.5.0", "1.5.0", "1", "${form}/{v}/", 1782370800, 8, "https://github.com/acme/json/releases/download/1.5.0/${h3}.tar.zst"),
			("0.26.0-rc1", "0.26.0", "0.26", "${form}/{v}-rc1/", 1780293600, 4000, "https://github.com/acme/json/releases/download/0.26.0-rc1/${h8}.tar.zst"),
		],
		warnings: ["acme/json 1.9.0: the release has 2 package assets (${h4}, ${h5}). It is not a candidate."],
	})
	got = view(Index.candidates({ owner: "acme", repo: "json", pages: [page1, page2], known: [] }))
	dbg got
	got == want
}

# R-DI15 R-DI14: a tag that is released again with a new asset hash. When the release has the label (group and version) of a URL that Talon knows with another hash, it
# is not a candidate, and a warning names the release and both hashes. The same hash, another version, another group (`v2.0.0` against `2.0.0`, another repo),
# and a URL that is not a package release URL do not count. A URL that is not known is a candidate.
expect {
	releases = page([
		release({ repo: "lib", tag: "2.0.0", draft: Bool.False, pre: Bool.False, published: "2026-10-03T10:00:00Z", assets: [("${h3}.tar.zst", 30)] }),
		release({ repo: "lib", tag: "1.1.0", draft: Bool.False, pre: Bool.False, published: "2026-10-02T10:00:00Z", assets: [("${h2}.tar.zst", 20)] }),
		release({ repo: "lib", tag: "1.0.0", draft: Bool.False, pre: Bool.False, published: "2026-10-01T10:00:00Z", assets: [("${h1}.tar.zst", 10)] }),
	])
	base = "https://github.com/acme/lib/releases/download"
	known = [
		"${base}/1.0.0/${h4}.tar.zst",
		"${base}/1.1.0/${h2}.tar.zst",
		"${base}/3.0.0/${h5}.tar.zst",
		"${base}/v2.0.0/${h6}.tar.zst",
		"https://github.com/other/lib/releases/download/2.0.0/${h7}.tar.zst",
		"../util/main.roc",
	]
	tags_of = |r| match view(r) {
		Ok(found) => Ok((found.list.map(|(tag, _, _, _, _, _, _)| tag), found.warnings))
		Err(e) => Err(e)
	}
	with_known = tags_of(Index.candidates({ owner: "acme", repo: "lib", pages: [releases], known }))
	want_known = Ok((["2.0.0", "1.1.0"], ["acme/lib 1.0.0: the release has the hash ${h1}, but Talon knows ${base}/1.0.0/${h4}.tar.zst with the hash ${h4}. It is not a candidate."]))
	without = tags_of(Index.candidates({ owner: "acme", repo: "lib", pages: [releases], known: [] }))
	want_without = Ok((["2.0.0", "1.1.0", "1.0.0"], []))
	dbg with_known
	dbg without
	with_known == want_known and without == want_without
}

# A page that is not a JSON array of objects, a release with no `tag_name`, and a release that is a candidate and has no `published_at` that
# parses are an error with the 1-based number of the page. A skipped release (a draft, a prerelease) is not read for the time.
# G2: a JSON number that is not an integer (a fraction, an exponent) in a field that Talon does not read is no error.
expect {
	with_float = "[{\"tag_name\":\"1.0.0\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-01T10:00:00Z\",\"score\":0.5,\"stats\":{\"rate\":1.5e2,\"big\":12345678901234567890},\"assets\":[{\"name\":\"${h1}.tar.zst\",\"size\":10,\"ratio\":-2.25E-1}]}]"
	ok_release = release({ repo: "json", tag: "1.0.0", draft: Bool.False, pre: Bool.False, published: "2026-10-01T10:00:00Z", assets: [("${h1}.tar.zst", 10)] })
	bad_time = release({ repo: "json", tag: "1.1.0", draft: Bool.False, pre: Bool.False, published: "yesterday", assets: [("${h2}.tar.zst", 10)] })
	pre_bad_time = release({ repo: "json", tag: "1.2.0", draft: Bool.False, pre: Bool.True, published: "yesterday", assets: [("${h3}.tar.zst", 10)] })
	rows = [
		("not JSON", ["not json"], Err(BadPage(1))),
		("an object", ["{}"], Err(BadPage(1))),
		("an array of numbers", ["[1]"], Err(BadPage(1))),
		("the second page", [page([ok_release]), "{}"], Err(BadPage(2))),
		("no tag", ["[{\"draft\":false}]"], Err(BadPage(1))),
		("a time that does not parse", [page([bad_time])], Err(BadPage(1))),
		("a prerelease is not read", [page([pre_bad_time])], Ok(0)),
		("an empty list", ["[]"], Ok(0)),
		("no pages", [], Ok(0)),
		("one release", [page([ok_release])], Ok(1)),
		("a float in a field that is not read (G2)", [with_float], Ok(1)),
	]
	count = |r| match r {
		Ok(found) => Ok(found.list.len())
		Err(e) => Err(e)
	}
	bad = rows.keep_if(|(_, pages, want)| count(Index.candidates({ owner: "acme", repo: "json", pages, known: [] })) != want).map(|(label, pages, want)| (label, want, count(Index.candidates({ owner: "acme", repo: "json", pages, known: [] }))))
	dbg bad
	bad == []
}

candidate : { url : Str, tag : Str, published : U64 } -> Index.Candidate
candidate = |c| match Ident.of_url(c.url) {
	Ok(ident) => { url: c.url, ident, tag: c.tag, published_at: c.published, size: 1 }
	Err(_) => crash "bad test URL"
}

# R-DI6: the candidates of a group are those with an equal group key. For a new entry (`tln add`) the URL form of the newest candidate by
# `published_at` wins (the first one in the list wins a tie), and all its series are candidates. A note names the other URL forms (in byte order), when the repository has any.
expect {
	base = "https://github.com/acme/json/releases/download"
	a = candidate({ url: "${base}/2.1.0/${h1}.tar.zst", tag: "2.1.0", published: 100 })
	b = candidate({ url: "${base}/2.0.5/${h2}.tar.zst", tag: "2.0.5", published: 50 })
	c = candidate({ url: "${base}/v1.7.0/${h3}.tar.zst", tag: "v1.7.0", published: 10 })
	d = candidate({ url: "${base}/3.0.0/${h4}.tar.zst", tag: "3.0.0", published: 200 })
	e = candidate({ url: "${base}/1.0.0/${h5}.tar.zst", tag: "1.0.0", published: 5 })
	f = candidate({ url: "${base}/json-4.0.0/${h6}.tar.zst", tag: "json-4.0.0", published: 1 })
	c_new = candidate({ url: "${base}/v1.7.0/${h3}.tar.zst", tag: "v1.7.0", published: 300 })
	a_tie = candidate({ url: "${base}/2.1.0/${h1}.tar.zst", tag: "2.1.0", published: 300 })
	f1 = "github.com/acme/json/releases/download/{v}/"
	f2 = "github.com/acme/json/releases/download/v{v}/"
	f3 = "github.com/acme/json/releases/download/json-{v}/"
	tags = |list| list.map(|x| x.tag)
	groups = [
		("series 2", { list: [a, b, c, d, e], group: { form: f1, series: "2" } }, ["2.1.0", "2.0.5"]),
		("series 3", { list: [a, b, c, d, e], group: { form: f1, series: "3" } }, ["3.0.0"]),
		("v form", { list: [a, b, c, d, e], group: { form: f2, series: "1" } }, ["v1.7.0"]),
		("no group", { list: [a, b, c, d, e], group: { form: f1, series: "9" } }, []),
	]
	bad_groups = groups.keep_if(|(_, facts, want)| tags(Index.in_group(facts)) != want).map(|(label, facts, want)| (label, want, tags(Index.in_group(facts))))
	dbg bad_groups

	shown = |r| match r {
		Ok(entry) => Ok((entry.form, tags(entry.list), entry.note))
		Err(NoCandidate) => Err(NoCandidate)
	}
	entries = [
		(
			"the newest is in the plain form: all series of it, a note for the v form",
			{ name: "acme/json", list: [a, b, c, d, e] },
			Ok((f1, ["2.1.0", "2.0.5", "3.0.0", "1.0.0"], Ok("acme/json also has releases in other URL forms: ${f2}"))),
		),
		(
			"the newest is in the v form",
			{ name: "acme/json", list: [a, c_new, d, e] },
			Ok((f2, ["v1.7.0"], Ok("acme/json also has releases in other URL forms: ${f1}"))),
		),
		("one form, no note", { name: "acme/json", list: [a, b, d] }, Ok((f1, ["2.1.0", "2.0.5", "3.0.0"], Err(None)))),
		(
			"3 forms: the other 2 in byte order (`j` is before `{`)",
			{ name: "acme/json", list: [f, c_new, a] },
			Ok((f2, ["v1.7.0"], Ok("acme/json also has releases in other URL forms: ${f3}, ${f1}"))),
		),
		(
			"a tie of `published_at`: the first one wins",
			{ name: "acme/json", list: [c_new, a_tie] },
			Ok((f2, ["v1.7.0"], Ok("acme/json also has releases in other URL forms: ${f1}"))),
		),
		(
			"a tie of `published_at`, the other order",
			{ name: "acme/json", list: [a_tie, c_new] },
			Ok((f1, ["2.1.0"], Ok("acme/json also has releases in other URL forms: ${f2}"))),
		),
		("no candidate", { name: "acme/json", list: [] }, Err(NoCandidate)),
	]
	bad_entries = entries.keep_if(|(_, facts, want)| shown(Index.new_entry(facts)) != want).map(|(label, facts, want)| (label, want, shown(Index.new_entry(facts))))
	dbg bad_entries
	bad_groups == [] and bad_entries == []
}

# R-DI9: the order in which the solver asks. `Highest` is the newest version first, `Lowest` the oldest. The versions are numbers, not texts
# (`1.10.0` is above `1.9.0`), and the release time does not count. Two candidates of one version keep their order in the list.
expect {
	base = "https://github.com/acme/json/releases/download"
	c1 = candidate({ url: "${base}/1.2.0/${h1}.tar.zst", tag: "1.2.0", published: 500 })
	c2 = candidate({ url: "${base}/1.10.0/${h2}.tar.zst", tag: "1.10.0", published: 300 })
	c3 = candidate({ url: "${base}/1.9.0/${h3}.tar.zst", tag: "1.9.0", published: 900 })
	c4 = candidate({ url: "${base}/1.9.1/${h4}.tar.zst", tag: "1.9.1", published: 100 })
	# The same version in 2 URL forms (2 candidates of one version): they keep the order of the list, for both strategies.
	c5 = candidate({ url: "${base}/v1.9.0/${h5}.tar.zst", tag: "v1.9.0", published: 50 })
	tags = |list| list.map(|x| x.tag)
	highest = tags(Index.order([c1, c2, c3, c4], Highest))
	lowest = tags(Index.order([c1, c2, c3, c4], Lowest))
	empty = tags(Index.order([], Highest))
	same_a = tags(Index.order([c1, c3, c5, c4], Highest))
	same_b = tags(Index.order([c1, c5, c3, c4], Highest))
	same_c = tags(Index.order([c1, c3, c5, c4], Lowest))
	same_d = tags(Index.order([c1, c5, c3, c4], Lowest))
	dbg highest
	dbg lowest
	dbg [same_a, same_b, same_c, same_d]
	same_ok = same_a == ["1.9.1", "1.9.0", "v1.9.0", "1.2.0"] and same_b == ["1.9.1", "v1.9.0", "1.9.0", "1.2.0"] and same_c == ["1.2.0", "1.9.0", "v1.9.0", "1.9.1"] and same_d == ["1.2.0", "v1.9.0", "1.9.0", "1.9.1"]
	highest == ["1.10.0", "1.9.1", "1.9.0", "1.2.0"] and lowest == ["1.2.0", "1.9.0", "1.9.1", "1.10.0"] and empty == [] and same_ok
}

# R-DI11: only the host `github.com` has an index in `direct` mode. Any other host is fixed at its header value. The line that update, upgrade and
# outdated print is in the design.
expect {
	rows = [
		("github", "https://github.com/acme/lib/releases/download/1.0.0/${h1}.tar.zst", Indexed),
		("another host", "https://example.com/pkg/1.0.0/${h1}.tar.zst", Fixed("example.com")),
		("a loopback host with a port", "http://127.0.0.1:8080/pkg/1.0.0/${h1}.tar.zst", Fixed("127.0.0.1:8080")),
		("www.github.com is another host", "https://www.github.com/acme/lib/releases/download/1.0.0/${h1}.tar.zst", Fixed("www.github.com")),
		("github.com as a prefix", "https://github.com.example.org/acme/lib/releases/download/1.0.0/${h1}.tar.zst", Fixed("github.com.example.org")),
	]
	bad = rows.keep_if(|(_, url, want)| Index.host_kind(url) != want).map(|(label, url, want)| (label, want, Index.host_kind(url)))
	dbg bad
	bad == [] and Index.fixed_line("example.com") == "fixed: example.com has no index without a registry"
}
