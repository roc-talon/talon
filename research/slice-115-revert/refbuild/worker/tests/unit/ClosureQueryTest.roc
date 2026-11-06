import lib.ClosureQuery
import lib.Problem
import lib.Version
import records.Closure
import records.Release
import semver.VersionReq

ClosureQueryTest :: [].{}

# W0 tests of worker/lib/ClosureQuery.roc (slice 110). The ids, base58 texts and stored version bounds below are made by
# research/slice-110-revert/gen/ids.py with python (hashlib): no expected id comes from the Roc code. The range bounds come from
# `Version.range_bounds` (slice 105), because their key form is the rule of `roc-semver` (R-GP5: not tested again here).

h1 : List(U8)
h1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]

b1 : Str
b1 = "1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE"

id1 : Str
id1 = "5265119941757224538"

h2 : List(U8)
h2 = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233, 232, 231, 230, 229, 228, 227, 226, 225, 224]

b2 : Str
b2 = "JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3"

id2 : Str
id2 = "5499626537489496528"

g1 : Str
g1 = "github.com/o/a/releases/download/{v}/"

g2 : Str
g2 = "github.com/o/e/releases/download/{v}/"

g3 : Str
g3 = "example.com/g/{v}/"

g4 : Str
g4 = "github.com/o/b/releases/download/{v}/"

t1 : Str
t1 = "nightly-2026-10-21-5349569"

t2 : Str
t2 = "nightly-2026-October-31-f7bef6b"

parse_text : Str -> Try(ClosureQuery.Query, _)
parse_text = |text| ClosureQuery.parse(text.to_utf8())

# The answer of a refused request: a 400 is the plain problem, a 413 is `Problem.to_json_with` with `field` and `limit` (R-AP21, R-AP46).
reject_status : ClosureQuery.Reject -> U16
reject_status = |r| match r {
	Bad(p) => p.http_status()
	TooLarge(p, _) => p.http_status()
}

reject_json : ClosureQuery.Reject -> Str
reject_json = |r| match r {
	Bad(p) => p.to_json()
	TooLarge(p, extra) => Problem.to_json_with(p, extra)
}

status_of : Str -> U16
status_of = |text| match parse_text(text) {
	Ok(_) => 200
	Err(r) => reject_status(r)
}

json_of : Str -> Str
json_of = |text| match parse_text(text) {
	Ok(_) => ""
	Err(r) => reject_json(r)
}

groups_text : U64, Str -> Str
groups_text = |n, group| {
	one = "{\"group\":\"${group}\"}"
	"[${Str.join_with(List.repeat(one, n), ",")}]"
}

# R-AP48, R-AP62: the limits (row 4) come before the checks of the values (row 6): a bad series in 301 groups is still 413.
groups_bad_series : U64 -> Str
groups_bad_series = |n| "[${Str.join_with(List.repeat("{\"group\":\"${g1}\",\"series\":\"0\"}", n), ",")}]"

hashes_text : U64 -> Str
hashes_text = |n| "[${Str.join_with(List.repeat("\"${b1}\"", n), ",")}]"

body : Str, Str -> Str
body = |groups, hashes| "{\"groups\":${groups},\"hashes\":${hashes}}"

# ---- tests ----

# R-AP46, R-AP48 row 4: the body limit is 256 KB (262,144 bytes). One byte more is 413 with `field` and `limit`, before the parse (the text is no JSON).
expect {
	ok = body("[]", "[]")
	at_limit = "${ok}${" ".repeat(ClosureQuery.body_limit - ok.count_utf8_bytes())}"
	over = "x".repeat(ClosureQuery.body_limit + 1)
	ClosureQuery.body_limit == 262_144
		and status_of(at_limit) == 200
		and status_of(over) == 413
		and json_of(over).contains("\"type\":\"/errors/too-large\"")
		and json_of(over).contains("\"field\":\"body\"")
		and json_of(over).contains("\"limit\":262144")
		and reject_json(ClosureQuery.too_large("body", 262_144)) == json_of(over)
		and reject_status(ClosureQuery.too_large("groups", 300)) == 413
}

# R-AP46, R-AP62: 300 groups and 1000 hashes are allowed; 301 groups or 1001 hashes give 413 with the field and the limit. Groups are checked first.
expect {
	g300 = groups_text(300, g1)
	g301 = groups_text(301, g1)
	ClosureQuery.group_limit == 300
		and ClosureQuery.hash_limit == 1_000
		and status_of(body(g300, hashes_text(1000))) == 200
		and status_of(body(g301, "[]")) == 413
		and json_of(body(g301, "[]")).contains("\"field\":\"groups\"")
		and json_of(body(g301, "[]")).contains("\"limit\":300")
		and status_of(body("[]", hashes_text(1001))) == 413
		and json_of(body("[]", hashes_text(1001))).contains("\"field\":\"hashes\"")
		and json_of(body("[]", hashes_text(1001))).contains("\"limit\":1000")
		and json_of(body(g301, hashes_text(1001))).contains("\"field\":\"groups\"")
		and json_of(body(groups_bad_series(301), "[]")).contains("\"field\":\"groups\"")
		and json_of(body("[]", "[${Str.join_with(List.repeat("\"not a hash\"", 1001), ",")}]")).contains("\"field\":\"hashes\"")
}

# R-AP51, R-AP48 row 6, R-AP62: a body that does not decode, or a series or range that is not valid, is 400 `bad-request`. A tag with no nightly id is not 400 (R-AP60).
expect {
	bad = [
		"",
		"not json",
		"[]",
		"{}",
		"{\"groups\":[]}",
		"{\"hashes\":[]}",
		"{\"groups\":{},\"hashes\":[]}",
		"{\"groups\":[{\"series\":\"1\"}],\"hashes\":[]}",
		"{\"groups\":[{\"group\":null}],\"hashes\":[]}",
		"{\"groups\":[],\"hashes\":[1]}",
		"{\"groups\":[{\"group\":\"${g1}\",\"series\":\"0\"}],\"hashes\":[]}",
		"{\"groups\":[{\"group\":\"${g1}\",\"series\":\"1.2\"}],\"hashes\":[]}",
		"{\"groups\":[{\"group\":\"${g1}\",\"range\":\"abc\"}],\"hashes\":[]}",
		"{\"groups\":[{\"group\":\"${g1}\",\"range\":\"1.2.3+build\"}],\"hashes\":[]}",
		"{\"groups\":[],\"hashes\":[],\"compilers\":{\"from\":5}}",
		"{\"groups\":[],\"hashes\":[],\"compilers\":{\"to\":{}}}",
		"{\"groups\":[],\"hashes\":[],\"compilers\":[]}",
	]
	bad.all(|text| status_of(text) == 400 and json_of(text).contains("\"type\":\"/errors/bad-request\""))
}

# R-AP16, R-AP41 row 2, R-IK2, R-IK4, R-IK5: the 4 parameters. Group ids, series bounds (python), range bounds (Version.range_bounds),
# both (the larger lo, the smaller hi), none (the I64 ends). Hash ids in request order, also a repeat; a text that is no hash is not in ?2.
# Both tag forms of R-CV1 have a nightly id.
expect {
	text = "{\"groups\":[{\"group\":\"${g1}\",\"series\":\"1\"},{\"group\":\"${g2}\",\"range\":\">=0.3.0, <0.5.0\"},{\"group\":\"${g3}\"},{\"group\":\"${g4}\",\"series\":\"0.3\",\"range\":\"^0.3.1\"}],\"hashes\":[\"${b1}\",\"not a hash\",\"${b2}\",\"${b1}\"],\"compilers\":{\"from\":\"${t1}\",\"to\":\"${t2}\"}}"
	r2 = match VersionReq.parse(">=0.3.0, <0.5.0") {
		Ok(req) => Version.range_bounds(req)
		Err(_) => { lo: "x", hi: "x" }
	}
	r4 = match VersionReq.parse("^0.3.1") {
		Ok(req) => Version.range_bounds(req)
		Err(_) => { lo: "x", hi: "x" }
	}
	s03 = { lo: -9223372023969873920.I64, hi: -9223372019674906625.I64 }
	lo4 = I64.max(s03.lo, I64.from_str(r4.lo) ?? 0)
	hi4 = I64.min(s03.hi, I64.from_str(r4.hi) ?? 0)
	groups_json = "[{\"form\":-3692541221064081259,\"lo\":-9223090561878065152,\"hi\":-9222809086901354497},{\"form\":6788748434313465012,\"lo\":${r2.lo},\"hi\":${r2.hi}},{\"form\":-6694716967130615478,\"lo\":-9223372036854775808,\"hi\":9223372036854775807},{\"form\":-6243123884266634966,\"lo\":${I64.to_str(lo4)},\"hi\":${I64.to_str(hi4)}}]"
	parse_text(text)
		== Ok({
			groups_json,
			hashes_json: "[${id1},${id2},${id1}]",
			from: Ok(5569317737833),
			to: Ok(5572174540651),
			hash_texts: [b1, "not a hash", b2, b1],
			filters: [
				{ group: g1, series: Ok("1"), range: Err(None) },
				{ group: g2, series: Err(None), range: Ok(">=0.3.0, <0.5.0") },
				{ group: g3, series: Err(None), range: Err(None) },
				{ group: g4, series: Ok("0.3"), range: Ok("^0.3.1") },
			],
		})
}

# R-AP16, R-AP44, R-AP51, R-AP60: a tag with no nightly id is a missing end; no `compilers`, `compilers` null, one end only, null ends; unknown members are ignored, also `snapshot` (R-AP19: the client applies it).
expect {
	empty = { groups_json: "[]", hashes_json: "[]", from: Err(None), to: Err(None), hash_texts: [], filters: [] }
	parse_text("{\"groups\":[],\"hashes\":[]}") == Ok(empty)
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":null}") == Ok(empty)
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":{}}") == Ok(empty)
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":{\"from\":null,\"to\":\"${t1}\"}}") == Ok({ ..empty, to: Ok(5569317737833) })
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":{\"from\":\"${t2}\"}}") == Ok({ ..empty, from: Ok(5572174540651) })
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":{\"from\":\"v1.2.3\",\"to\":\"${t1}\"}}") == Ok({ ..empty, to: Ok(5569317737833) })
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":{\"from\":\"${t2}\",\"to\":\"nightly-2026-02-30-5349569\"}}") == Ok({ ..empty, from: Ok(5572174540651) })
		and parse_text("{\"groups\":[],\"hashes\":[],\"compilers\":{\"from\":\"nightly-2026-10-21-534956\",\"to\":\"\"}}") == Ok(empty)
		and parse_text("{\"snapshot\":\"log:3\",\"groups\":[],\"x\":{\"y\":[1]},\"hashes\":[]}") == Ok(empty)
		and parse_text("{\"groups\":[{\"group\":\"${g3}\",\"series\":null,\"range\":null,\"z\":1}],\"hashes\":[]}") == Ok({ ..empty, groups_json: "[{\"form\":-6694716967130615478,\"lo\":-9223372036854775808,\"hi\":9223372036854775807}]", filters: [{ group: g3, series: Err(None), range: Err(None) }] })
}

release : Str, Str, Str -> Release.Row
release = |group, series, version| {
	log_index: 1,
	hash: b1,
	group,
	series,
	version,
	url: "https://example.com/x.tar.zst",
	tag: Err(None),
	roc_version: Err(None),
	repo: Err(None),
	published_at: 0,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
}

# R-AP16 "with a range, only the candidates in it", R-AP41 row 4 (the filter in Roc), R-IK5 (the series of a saturated key is checked),
# R-AP63: a release whose hash is a text of `hashes` stays, also out of the filter.
expect {
	filters = [
		{ group: g1, series: Ok("1"), range: Err(None) },
		{ group: g2, series: Err(None), range: Ok(">1.2.0, <1.4.0") },
		{ group: g3, series: Ok("0.3"), range: Ok("^0.3.1") },
		{ group: g4, series: Ok("65535"), range: Err(None) },
	]
	q = { groups_json: "", hashes_json: "", from: Err(None), to: Err(None), hash_texts: ["not a hash"], filters }
	held = { ..q, hash_texts: ["x", b2] }
	keep = [
		release(g1, "1", "1.0.0"),
		release(g2, "1", "1.3.0"),
		release(g2, "1", "1.3.99"),
		release(g3, "0.3", "0.3.1"),
		release(g4, "65535", "65535.0.0"),
		release("github.com/other/x/releases/download/{v}/", "2", "2.0.0"),
	]
	drop = [
		release(g1, "2", "2.0.0"),
		release(g2, "1", "1.2.0"),
		release(g2, "1", "1.4.0"),
		release(g2, "1", "1.1.9"),
		release(g3, "0.3", "0.3.0"),
		release(g3, "0.4", "0.4.0"),
		release(g4, "65536", "65536.0.0"),
	]
	keep.all(|r| ClosureQuery.keep_release(q, r))
		and drop.all(|r| !ClosureQuery.keep_release(q, r))
		and ClosureQuery.keep_release({ ..q, filters: [] }, release(g1, "2", "2.0.0"))
		and drop.all(|r| ClosureQuery.keep_release(held, { ..r, hash: b2 }))
		and drop.all(|r| !ClosureQuery.keep_release(held, r))
}

# R-AP17 `unknown`, R-AP28, R-AP59: the texts that are no hash and the hashes that the batch does not index, in request order, each once.
expect {
	q = { groups_json: "[]", hashes_json: "[${id1},${id2},${id1}]", from: Err(None), to: Err(None), hash_texts: [b1, "not a hash", b2, b1, "not a hash", "x"], filters: [] }
	ClosureQuery.unknown_of(q, []) == ["not a hash", "x"]
		and ClosureQuery.unknown_of(q, [1]) == ["not a hash", b2, "x"]
		and ClosureQuery.unknown_of(q, [0, 1]) == [b1, "not a hash", b2, "x"]
		and ClosureQuery.unknown_of({ ..q, hash_texts: [b1, b2, b1], hashes_json: "[${id1},${id2},${id1}]" }, [0]) == [b1]
}

rows : ClosureQuery.Rows
rows = {
	artifacts: [
		{ hash: h1, kind: 1, exposed_json: "[\"A\",\"B\"]", platform_hash: Err(Missing), roc_pin: Err(Missing), size: 10 },
		{ hash: h2, kind: 2, exposed_json: "[]", platform_hash: Err(Missing), roc_pin: Ok(t1), size: 20 },
	],
	deps: [{ owner: h1, alias: "pf", hash: h2, form: Ok(g4), version: Ok("-9223090561877999617"), version_text: Ok(""), url: "https://github.com/o/b/releases/download/1.0.0/pf.tar.zst" }],
	target_rows: [{ owner: h2, name: "arm64linux" }, { owner: h2, name: "x64musl" }],
	releases: [
		{ log_index: 1, hash: h1, form: g1, version: "-9223090561877999617", version_text: "", url: "https://github.com/o/a/releases/download/1.0.0/a.tar.zst", tag: Ok("1.0.0"), roc_version: Err(Missing), repo: Ok("o/a"), published_at: 1000, yanked: Bool.False, withdrawn: Err(Missing) },
		{ log_index: 2, hash: [7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7], form: g1, version: "-9222809086901288961", version_text: "", url: "https://github.com/o/a/releases/download/2.0.0/a.tar.zst", tag: Ok("2.0.0"), roc_version: Err(Missing), repo: Ok("o/a"), published_at: 2000, yanked: Bool.False, withdrawn: Ok("deleted") },
	],
	unknown: [{ idx: 1 }],
	epochs: [{ target: "any", from: t1, to: t2 }],
	runs: [
		{ hash: h1, target: "any", source: 0, result: 0, error_digest: Err(Missing), from: t1, to: t2 },
		{ hash: h1, target: "x64musl", source: 1, result: 1, error_digest: Ok("d1"), from: t1, to: t1 },
	],
	nearest: [
		{ hash: h1, target: "any", source: 0, result: 1, error_digest: Ok("d2"), nightly: t1, side: "before" },
		{ hash: h2, target: "any", source: 1, result: 0, error_digest: Err(Missing), nightly: t2, side: "after" },
	],
	hints: [{ hash: h2, nightly: t2, target: "x64musl", pass_count: 3, fail_count: 1, crash_count: 0 }],
	checked: [{ name: "o/a", checked_at: Ok(1000), app_installed: Bool.False }],
	repos: [{ name: "o/a", state: 2, successor: Ok("o/b"), state_at: 5 }],
	log_size: 9,
}

query : ClosureQuery.Query
query = { groups_json: "", hashes_json: "[${id1},${id2}]", from: Err(None), to: Err(None), hash_texts: ["bad", b1, b2], filters: [{ group: g1, series: Ok("1"), range: Err(None) }] }

# R-AP17, R-AP32, R-AP29, R-AP49, R-AP50, R-RE13 row 4: the answer from the rows. The release of 2.0.0 is out of the series of its group (R-AP16), and its hash
# is not in `hashes` (R-AP63).
# R-AP58: `error_digest` NULL is `null`. The stale rule is R-AP29 (slice 106). The expected text is `Closure.encode_answer` of the record (slice 104), with
# the lists `runs` and `nearest` written here as text (members in alphabetical order, as the derived encoder of `records` writes them), so the test does
# not depend on the type of `error_digest` in `records` (it becomes nullable in slice 104).
expect {
	now = 1000 + 2 * 3_600_000 + 1
	want : Closure.Answer
	want = {
		artifacts: [
			{ hash: b1, kind: Package, exposed: ["A", "B"], platform_hash: Err(None), roc_pin: Err(None), size: 10, deps: [{ alias: "pf", hash: b2, group: g4, series: Ok("1"), version: Ok("1.0.0"), url: "https://github.com/o/b/releases/download/1.0.0/pf.tar.zst" }], target_names: [] },
			{ hash: b2, kind: Platform, exposed: [], platform_hash: Err(None), roc_pin: Ok(t1), size: 20, deps: [], target_names: ["arm64linux", "x64musl"] },
		],
		releases: [{ log_index: 1, hash: b1, group: g1, series: "1", version: "1.0.0", url: "https://github.com/o/a/releases/download/1.0.0/a.tar.zst", tag: Ok("1.0.0"), roc_version: Err(None), repo: Ok("o/a"), published_at: 1000, yanked: Bool.False, yank_reason: Err(None), withdrawn: Err(None) }],
		epochs: [{ target: "any", from: t1, to: t2 }],
		runs: [],
		nearest: [],
		hints: [{ hash: b2, nightly: t2, target: "x64musl", pass_count: 3, fail_count: 1, crash_count: 0 }],
		log_size: 9,
		unknown: ["bad", b2],
		checked: [{ name: "o/a", checked_at: Ok(1000), stale: Bool.True }],
		repos: [{ name: "o/a", state: Moved, successor: Ok("o/b"), state_at: 5 }],
	}
	runs = "[{\"error_digest\":null,\"from\":\"${t1}\",\"hash\":\"${b1}\",\"result\":\"pass\",\"source\":\"bot\",\"target\":\"any\",\"to\":\"${t2}\"},{\"error_digest\":\"d1\",\"from\":\"${t1}\",\"hash\":\"${b1}\",\"result\":\"fail\",\"source\":\"author\",\"target\":\"x64musl\",\"to\":\"${t1}\"}]"
	nearest = "[{\"error_digest\":\"d2\",\"hash\":\"${b1}\",\"nightly\":\"${t1}\",\"result\":\"fail\",\"side\":\"before\",\"source\":\"bot\",\"target\":\"any\"},{\"error_digest\":null,\"hash\":\"${b2}\",\"nightly\":\"${t2}\",\"result\":\"pass\",\"side\":\"after\",\"source\":\"author\",\"target\":\"any\"}]"
	text = Closure.encode_answer(want).replace_first("\"runs\":[]", "\"runs\":${runs}").replace_first("\"nearest\":[]", "\"nearest\":${nearest}")
	ClosureQuery.answer(query, rows, now) == Ok(text)
}

# R-AP17: no rows give the empty lists and the log size. R-AP48: a row that does not convert is `BadRow` (500 `internal`), never a crash.
expect {
	none = { artifacts: [], deps: [], target_rows: [], releases: [], unknown: [], epochs: [], runs: [], nearest: [], hints: [], checked: [], repos: [], log_size: 0 }
	empty_q = { ..query, hashes_json: "[]", hash_texts: [], filters: [] }
	bad_result = { ..none, runs: [{ hash: h1, target: "any", source: 0, result: 7, error_digest: Err(Missing), from: t1, to: t1 }] }
	bad_source = { ..none, nearest: [{ hash: h1, target: "any", source: 2, result: 0, error_digest: Err(Missing), nightly: t1, side: "before" }] }
	bad_side = { ..none, nearest: [{ hash: h1, target: "any", source: 0, result: 0, error_digest: Err(Missing), nightly: t1, side: "middle" }] }
	bad_hash = { ..none, hints: [{ hash: h1.drop_last(1), nightly: t1, target: "any", pass_count: 1, fail_count: 0, crash_count: 0 }] }
	bad_exposes = { ..none, artifacts: [{ hash: h1, kind: 1, exposed_json: "A", platform_hash: Err(Missing), roc_pin: Err(Missing), size: 1 }] }
	is_bad = |r| match ClosureQuery.answer(empty_q, r, 0) {
		Err(BadRow(_)) => Bool.True
		Ok(_) => Bool.False
	}
	nothing : Closure.Answer
	nothing = { artifacts: [], releases: [], epochs: [], runs: [], nearest: [], hints: [], log_size: 0, unknown: [], checked: [], repos: [] }
	ClosureQuery.answer(empty_q, none, 0) == Ok(Closure.encode_answer(nothing))
		and [bad_result, bad_source, bad_side, bad_hash, bad_exposes].all(is_bad)
}
