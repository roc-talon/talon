import lib.Fail
import lib.UnknownValues

UnknownvaluesTest :: [].{}

# Slice 208 (docs/slices/208-unknown-header-values.md). Pure: which header value is unknown in which way (R-AP28 cases 1 to 3), the ingest requests, the meaning of an ingest answer, the largest bookmark, the headers of the second query.

h0 = "F2uojbw8Z1W8LEjqfqePSQ2ednxYYBsCFB4fX6BAkZ1n"

h1 = "9h4nsRG1qGiGW9gC8Newrxf2RCkXdBokefenYAGQU442"

h2 = "22gWCNuGan7puGi2skkrFoo97hJ81kL3zX57fPbxqCAX"

h3 = "DkSWmeYfEsnJEVMZnXzfLpjkphazX5m8crUoTBRSSsZz"

h4 = "6MNdByQtgh57U5jndGwTvc8Do2LiwisinxHENWemofGt"

h5 = "6tTnMBxZHpCDaNQn6CXuHgkg7TJ6kmAKQeVzPmzspt2b"

h6 = "482rrQu1iQ4UEGAti3rZZ3b5pntTbJWQLjQcyUDhExm1"

g_lib = "github.com/acme/lib/releases/download/{v}/"

g_other = "github.com/acme/other/releases/download/{v}/"

gh = |repo, version, hash| "https://github.com/acme/${repo}/releases/download/${version}/${hash}.tar.zst"

# A release row of the answer (R-AP49): the group, the version and the hash are the label and its hash.
row = |group, version, hash| {
	log_index: 7,
	hash,
	group,
	series: "1",
	version,
	url: "https://github.com/acme/lib/releases/download/${version}/${hash}.tar.zst",
	tag: Ok(version),
	roc_version: Err(None),
	repo: Ok("acme/lib"),
	published_at: 1790848800000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["webhook"],
}

url_a = gh("lib", "1.0.0", h0)

url_b = gh("other", "2.0.0", h1)

url_ex = "https://example.org/lib/releases/download/1.0.0/${h2}.tar.zst"

url_loop = "http://127.0.0.1:8000/lib/releases/download/1.0.0/${h3}.tar.zst"

url_raw = "https://raw.githubusercontent.com/acme/lib/releases/download/1.0.0/${h4}.tar.zst"

url_lab = gh("lib", "1.1.0", h5)

all_urls = [url_a, url_b, url_ex, url_loop, url_raw, url_lab]

classify = |unknown, releases, snapshot| UnknownValues.classify({ unknown, urls: all_urls, releases, snapshot }).map(|v| (v.hash, v.case))

# R-AP28 case 2, R-ID7 (a hash that a human wrote in the header): a `github.com` release asset URL of a checked repository gets an ingest, in the order of `unknown` (not of the entries). R-RG4.
expect classify([h1, h0], [], Bool.False) == [(h1, Ingest), (h0, Ingest)]

# R-AP28 case 3, R-PU40, R-DI7, R-DI11: another host, a loopback host and `raw.githubusercontent.com` get no ingest. A URL on `github.com` next to them still gets one.
expect classify([h2, h0, h3, h4], [], Bool.False) == [(h2, Archive), (h0, Ingest), (h3, Archive), (h4, Archive)]

# R-AP28 case 3, R-AD36: with `--snapshot log:N` no value gets an ingest.
expect classify([h0, h1, h2], [], Bool.True) == [(h0, Archive), (h1, Archive), (h2, Archive)]

# R-AP28 case 1, R-AP65 source 1: the answer has the label (group and version) of the URL with another hash. The case holds before any ingest: the github URL is not an `Ingest`.
expect classify([h5, h0], [row(g_lib, "1.1.0", h6)], Bool.False) == [(h5, Label({ other: Ok(h6) })), (h0, Ingest)]

# R-AP65 source 1: with case 3 conditions (a snapshot) the client sees case 1 from source 1 only, so the label still gives `Label`.
expect classify([h5], [row(g_lib, "1.1.0", h6)], Bool.True) == [(h5, Label({ other: Ok(h6) }))]

# R-AP28 case 1 is before case 3: the label of a URL of another host (another group) is also `Label`.
expect UnknownValues.classify({ unknown: [h2], urls: [url_ex], releases: [row("example.org/lib/releases/download/{v}/", "1.0.0", h6)], snapshot: Bool.False }).map(|v| v.case) == [Label({ other: Ok(h6) })]

# R-AP65: the label is the group AND the version. Another version in the same group, or the same version in another group, is not the label.
expect classify([h5], [row(g_lib, "1.2.0", h6)], Bool.False) == [(h5, Ingest)]

expect classify([h5], [row(g_other, "1.1.0", h6)], Bool.False) == [(h5, Ingest)]

# R-AP28: each `Value` has the URL of its entry.
expect UnknownValues.classify({ unknown: [h1, h0], urls: all_urls, releases: [], snapshot: Bool.False }).map(|v| v.url) == [url_b, url_a]

# R-AP28 case 1, R-AP65 (proposal, TW24): the warning names the release and both hashes (source 1). With no `other` (source 2, a 409: Q164) it says "another hash".
expect UnknownValues.label_warning({ url: url_lab, hash: h5, other: Ok(h6) }) == "warning: acme/lib 1.1.0: the registry has this release with the hash ${h6}, the header has ${h5}. Talon does not use the registry's release for this value. Ask the author to release a new version."

expect UnknownValues.label_warning({ url: url_lab, hash: h5, other: Err(None) }) == "warning: acme/lib 1.1.0: the registry has this release with another hash, the header has ${h5}. Talon does not use the registry's release for this value. Ask the author to release a new version."

# R-AP9, R-AP28 case 2, R-DA8 rule 1, R-AP45, R-AP23: the ingest requests: one for each URL in order, `Post`, no credential header, the JSON body `{"url":...}`.
expect UnknownValues.ingest_requests({ origin: "http://127.0.0.1:9", version: "0.0.1", urls: [url_a, url_b] }) == [
	{ method: Post, url: "http://127.0.0.1:9/v1/releases", headers: [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json")], body: "{\"url\":\"${url_a}\"}", timeout_s: 20 },
	{ method: Post, url: "http://127.0.0.1:9/v1/releases", headers: [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json")], body: "{\"url\":\"${url_b}\"}", timeout_s: 20 },
]

# R-DA8 rule 1, Design Q228: no request of the list has `Authorization` or `Talon-Contributor` (any case).
expect UnknownValues.ingest_requests({ origin: "https://r.example", version: "0.0.1", urls: [url_a, url_b] }).all(
	|r| r.headers.all(|(name, _)| name.with_ascii_lowercased() != "authorization" and name.with_ascii_lowercased() != "talon-contributor"),
)

verdict = |status, headers, body| UnknownValues.ingest_verdict({ origin: "http://127.0.0.1:9", version: "0.0.1", result: Ok({ status, headers, body }) })

no_reply = |result| UnknownValues.ingest_verdict({ origin: "http://127.0.0.1:9", version: "0.0.1", result })

conflict = "{\"type\":\"/errors/label-conflict\",\"title\":\"Conflict\",\"status\":409,\"detail\":\"x\"}"

collision = "{\"type\":\"/errors/id-collision\",\"title\":\"Conflict\",\"status\":409,\"detail\":\"x\"}"

unprocessable = "{\"type\":\"/errors/not-a-candidate\",\"title\":\"Unprocessable\",\"status\":422,\"detail\":\"x\"}"

limited = "{\"type\":\"/errors/rate-limited\",\"title\":\"Too many\",\"status\":429,\"detail\":\"x\"}"

# R-AP28 case 2, R-AP9, R-AP41 row 5: 200 and 201 indexed the release. The bookmark is the header `Talon-Bookmark`: the name in any case, white space cut. No header, or an empty value: none.
expect verdict(201, [("Content-Type", "application/json"), ("Talon-Bookmark", "bm1")], "{}") == Ok(Indexed({ bookmark: Ok("bm1") }))

expect verdict(200, [("talon-bookmark", "  bm2 ")], "{}") == Ok(Indexed({ bookmark: Ok("bm2") }))

expect verdict(201, [("Content-Type", "application/json")], "{}") == Ok(Indexed({ bookmark: Err(None) }))

expect verdict(200, [("TALON-BOOKMARK", "  ")], "{}") == Ok(Indexed({ bookmark: Err(None) }))

# R-AP65 source 2: a 409 `label-conflict` is case 1 for its URL.
expect verdict(409, [("Content-Type", "application/problem+json")], conflict) == Ok(Label)

# R-AP65: another error of an ingest (409 `id-collision`, 422, a 409 with no problem details) is case 3 for its URL, with no exit code.
expect verdict(409, [("Content-Type", "application/problem+json")], collision) == Ok(Archive)

expect verdict(422, [("Content-Type", "application/problem+json")], unprocessable) == Ok(Archive)

expect verdict(409, [], "not json") == Ok(Archive)

# R-AP28 case 3, Q421: another 4xx (400, 403) is case 3 with no warning, as 422.
expect verdict(403, [], "{}") == Ok(Archive)

expect verdict(400, [("Content-Type", "application/problem+json")], unprocessable) == Ok(Archive)

# R-AP28 case 2, Q421: no answer, a 5xx, a 3xx and a 202 give no index for the URL: `Unindexed` with the status as text, or `no answer`. Not an exit code, not a retry (R-AP34).
expect no_reply(Err(Timeout)) == Ok(Unindexed({ what: "no answer" }))

expect no_reply(Err(Failed("connection refused"))) == Ok(Unindexed({ what: "no answer" }))

expect verdict(502, [("Content-Type", "application/problem+json")], "{}") == Ok(Unindexed({ what: "502" }))

expect verdict(302, [("Location", "https://x.example/")], "") == Ok(Unindexed({ what: "302" }))

expect verdict(202, [], "{}") == Ok(Unindexed({ what: "202" }))

# Q421 (proposal, TW24): the one warning.
expect UnknownValues.unindexed_warning({ url: url_a, what: "502" }) == "warning: ${url_a}: the registry did not index this release (502). Talon reads the archive."

expect UnknownValues.unindexed_warning({ url: url_a, what: "no answer" }) == "warning: ${url_a}: the registry did not index this release (no answer). Talon reads the archive."

# R-AP25, R-AD35 step 3, Q424: a 429 stops the command with exit code 15 (kind `network`). The message gives the time of `Retry-After` (the name in any case, white space cut).
message_of = |result| match result {
	Err(fail) => if fail.kind.code() == 15 fail.message else "wrong kind ${fail.message}"
	Ok(_) => "no failure"
}

expect message_of(verdict(429, [("Retry-After", "30")], limited)) == "the registry answered 429 (/errors/rate-limited). Try again in 30 s."

expect message_of(verdict(429, [("retry-after", " 120 ")], limited)) == "the registry answered 429 (/errors/rate-limited). Try again in 120 s."

# Q424: no header, or a value that is not a whole number: no time.
expect message_of(verdict(429, [], limited)) == "the registry answered 429 (/errors/rate-limited). Try again later."

expect message_of(verdict(429, [("Retry-After", "soon")], limited)) == "the registry answered 429 (/errors/rate-limited). Try again later."

expect message_of(verdict(429, [("Retry-After", "1.5")], limited)) == "the registry answered 429 (/errors/rate-limited). Try again later."

# R-AP41 row 5: the largest of the bookmarks (bookmarks of one width in lower-case hex: Q3). Not the first and not the last.
expect UnknownValues.largest(["00000005-00000010-00004c60-8e61", "0000000b-00000020-00004c70-1f22", "00000008-00000030-00004c68-9a10"]) == Ok("0000000b-00000020-00004c70-1f22")

# The segment before the last decides before a later one: the first segment is equal here.
expect UnknownValues.largest(["0000000b-00000020-00004c70-1f22", "0000000b-00000021-00004c01-0000"]) == Ok("0000000b-00000021-00004c01-0000")

# Q422: the longer text is larger, also when its first byte is smaller. Of one length the byte order decides.
expect UnknownValues.largest(["ffff-ffff", "0001-0000-00"]) == Ok("0001-0000-00")

expect UnknownValues.largest(["0001-0000-00", "ffff-ffff", "0000-0000-01"]) == Ok("0001-0000-00")

expect UnknownValues.largest(["a1"]) == Ok("a1")

expect UnknownValues.largest([]) == Err(None)

# R-AP28 case 2, R-AP43 case 1 and 2, R-AP41 row 5, Q422, Q423: the headers of the second query (the order is not a contract; the tests use this one). With no bookmark: `no-cache` only, no `Talon-Bookmark` (Q423).
expect UnknownValues.again_headers({ version: "0.0.1", bookmark: Ok("bm9") }) == [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json"), ("Cache-Control", "no-cache"), ("Talon-Bookmark", "bm9")]

expect UnknownValues.again_headers({ version: "0.0.1", bookmark: Err(None) }) == [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json"), ("Cache-Control", "no-cache")]

# R-AP28 (the note after case 3), R-DI11 (registry), R-C9: a case 3 value whose group has no row in the answer is an anchor: `fixed: not in the registry index`. The text has no host.
expect UnknownValues.anchor_note({ end: Archive, url: url_ex, releases: [row(g_lib, "1.0.0", h6)] }) == Ok("fixed: not in the registry index")

expect UnknownValues.anchor_note({ end: Archive, url: url_a, releases: [] }) == Ok("fixed: not in the registry index")

# R-AP28: the answer has a release of the group (another version, another hash): the candidates come from the registry, no note.
expect UnknownValues.anchor_note({ end: Archive, url: url_a, releases: [row(g_other, "2.0.0", h6), row(g_lib, "1.5.0", h6)] }) == Err(None)

# An indexed value is not an anchor.
expect UnknownValues.anchor_note({ end: Indexed, url: url_a, releases: [] }) == Err(None)

# Q425: a `Label` value has the note by the rule of case 3. A 409 gives the label with no row in the answer: the note. A label of source 1 has a row of the group: none.
expect UnknownValues.anchor_note({ end: Label({ other: Err(None) }), url: url_lab, releases: [] }) == Ok("fixed: not in the registry index")

expect UnknownValues.anchor_note({ end: Label({ other: Ok(h6) }), url: url_lab, releases: [row(g_lib, "1.1.0", h6)] }) == Err(None)
