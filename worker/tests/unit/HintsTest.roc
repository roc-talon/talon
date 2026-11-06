import lib.Hints
import lib.Compat
import records.Code

HintsTest :: [].{}

# W0 tests of worker/lib/Hints.roc (slice 116a). The ids, base58 texts and nightly ids below are the ones of CompatTest (made by research/slice-115-revert/gen/ids.py with python);
# the HMAC ids and the version keys are made by research/slice-116-revert/gen/vectors.mjs with node (crypto): no expected value comes from the Roc code.
# The design answers are Design Q170 to Q181 and R-AP70 (the order of the checks of the hint path: the tests of `parse`, `machine_id` and `check` follow its rows 5 to 8 and 11) (docs/slices/116a-user-hints.md section 12).

h1 : Str
h1 = "1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE"

id1 : I64
id1 = 5265119941757224538

h2 : Str
h2 = "JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3"

id2 : I64
id2 = 5499626537489496528

# [7] * 32: a negative id.
h3 : Str
h3 = "US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx"

id3 : I64
id3 = -3201922985822262901

# [0x11] * 32: a negative id.
h4 : Str
h4 = "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2"

id4 : I64
id4 = -4418864005132459968

t1 : Str
t1 = "nightly-2026-10-21-5349569"

n1 : I64
n1 = 5569317737833

t2 : Str
t2 = "nightly-2026-October-31-f7bef6b"

n2 : I64
n2 = 5572174540651

m1 : Str
m1 = "0123456789abcdef0123456789abcdef"

# ---- helpers ----

row : Str, Str, Str, Str -> Str
row = |hash, nightly, target, result| "{\"hash\":\"${hash}\",\"nightly\":\"${nightly}\",\"target\":\"${target}\",\"result\":\"${result}\"}"

body_of : Str, List(Str) -> Str
body_of = |version, rows| "{\"talon_version\":\"${version}\",\"rows\":[${Str.join_with(rows, ",")}]}"

parse_text : Str -> Try(Hints.Post, Compat.Reject)
parse_text = |text| Hints.parse(text.to_utf8())

status_of : Str -> U16
status_of = |text| match parse_text(text) {
	Ok(_) => 200
	Err(Bad(p)) => p.http_status()
	Err(TooLarge(p, _)) => p.http_status()
}

# The JSON of the problem of a refused body (the `detail` is in it).
detail_of : Str -> Str
detail_of = |text| match parse_text(text) {
	Ok(_) => ""
	Err(Bad(p)) => p.to_json()
	Err(TooLarge(p, _)) => p.to_json()
}

# The `field` and `limit` of a 413.
field_of : Str -> Str
field_of = |text| match parse_text(text) {
	Err(TooLarge(_, extra)) => "${extra.field}:${extra.limit.to_str()}"
	_ => ""
}

is_400 : Str -> Bool
is_400 = |text| status_of(text) == 400

good_row : Str
good_row = row(h1, t1, "any", "pass")

# The facts of the read batch: id1 a package (kind 1), id2 a platform (kind 2) that builds x64glibc (8), id3 an app (kind 0); id4 has no fact.
facts : Compat.Facts
facts = {
	artifacts: [{ artifact: id1, kind: 1 }, { artifact: id2, kind: 2 }, { artifact: id3, kind: 0 }],
	target_rows: [{ name: "x64glibc", target: 8 }, { name: "wasm32", target: 34 }],
	platform_targets: [{ artifact: id2, target: 8 }],
}

post_of : List((Str, I64, Str, Code.Result)) -> Hints.Post
post_of = |items| {
	talon_version: "0.4.1",
	rows: items.map(|(hash, artifact, target, result)| { hash, artifact, nightly: n1, target, result }),
}

check_detail : List((Str, I64, Str, Code.Result)) -> Str
check_detail = |items| match Hints.check(post_of(items), facts) {
	Err(p) => "${p.http_status().to_str()} ${p.to_json()}"
	Ok(_) => "ok"
}

# ---- tests ----

# R-CT1: the id of the header is 32 lower case hex characters. `Ok` gives the same text. Everything else is 400 `bad-request` and the `detail` names the header.
expect {
	bad = [
		"",
		"0123456789ABCDEF0123456789abcdef",
		"0123456789abcdef0123456789abcde",
		"0123456789abcdef0123456789abcdef0",
		"0123456789abcdef0123456789abcdeg",
		"0123456789abcdef 123456789abcdef",
		" 123456789abcdef0123456789abcdef",
		"0123456789abcdef0123456789abcdef\n",
		"0123456789abcdef0123456789abcdé",
	]
	refused = |id| match Hints.machine_id(id) {
		Err(p) => p.http_status() == 400 and p.to_json().contains("Talon-Contributor")
		Ok(_) => Bool.False
	}
	Hints.machine_id(m1) == Ok(m1)
		and Hints.machine_id("00000000000000000000000000000000") == Ok("00000000000000000000000000000000")
		and Hints.machine_id("ffffffffffffffffffffffffffffffff") == Ok("ffffffffffffffffffffffffffffffff")
		and bad.all(refused)
}

# R-AP10, R-CT2, R-IK2, R-IK4, R-IK7, R-AP44, R-CT12: a good body. The rows in order, the ids, the 3 results, the month-name tag form, any text as a `target` (a name with no code is a skip later, not a 400),
# any text as `talon_version` (also empty), unknown members ignored in the body and in a row, `rows: []`. A text that holds the word `source` or `error_digest` as a value is not a member.
expect {
	body = "{\"extra\":1,\"talon_version\":\"0.4.1\",\"rows\":[${row(h1, t1, "any", "pass")},${row(h2, t2, "x64glibc", "fail")},{\"hash\":\"${h3}\",\"nightly\":\"${t1}\",\"target\":\"no such target\",\"result\":\"crash\",\"note\":[1]}]}"
	words = body_of("source", [row(h1, t1, "source", "pass"), row(h1, t1, "error_digest", "pass")])
	parse_text(body)
		== Ok({
			talon_version: "0.4.1",
			rows: [
				{ hash: h1, artifact: id1, nightly: n1, target: "any", result: Pass },
				{ hash: h2, artifact: id2, nightly: n2, target: "x64glibc", result: Fail },
				{ hash: h3, artifact: id3, nightly: n1, target: "no such target", result: Crash },
			],
		})
		and parse_text(body_of("", [])) == Ok({ talon_version: "", rows: [] })
		and parse_text(body_of("banana", [good_row])) == Ok({ talon_version: "banana", rows: [{ hash: h1, artifact: id1, nightly: n1, target: "any", result: Pass }] })
		and status_of(words) == 200
}

# R-AP51, R-CT2, R-AP48 row 6: a body that does not decode is 400 `bad-request`. A missing member is named in the `detail` (R-AP51); a member of the wrong type or `null` is 400 and the `detail` is free (the derived reader
# does not name the member). `talon_version` is required, a text (R-AP51: `null` is 400 for a required member).
expect {
	bad = [
		("", ""),
		("not json", ""),
		("[]", ""),
		("{}", "rows"),
		("{\"talon_version\":\"0.4.1\"}", "rows"),
		("{\"talon_version\":\"0.4.1\",\"rows\":null}", ""),
		("{\"talon_version\":\"0.4.1\",\"rows\":{}}", ""),
		("{\"talon_version\":\"0.4.1\",\"rows\":[1]}", ""),
		("{\"rows\":[]}", "talon_version"),
		("{\"talon_version\":null,\"rows\":[]}", ""),
		("{\"talon_version\":1,\"rows\":[]}", ""),
		("{\"talon_version\":\"0.4.1\",\"rows\":[{\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\"}]}", "hash"),
		("{\"talon_version\":\"0.4.1\",\"rows\":[{\"hash\":\"${h1}\",\"target\":\"any\",\"result\":\"pass\"}]}", "nightly"),
		("{\"talon_version\":\"0.4.1\",\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"result\":\"pass\"}]}", "target"),
		("{\"talon_version\":\"0.4.1\",\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\"}]}", "result"),
		("{\"talon_version\":\"0.4.1\",\"rows\":[{\"hash\":null,\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\"}]}", ""),
		("{\"talon_version\":\"0.4.1\",\"rows\":[{\"hash\":1,\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\"}]}", ""),
	]
	not_utf8 = Hints.parse([0xFF, 0xFE, 0x7B])
	bad.all(|(text, member)| is_400(text) and detail_of(text).contains(member))
		and (
			match not_utf8 {
				Err(Bad(p)) => p.http_status() == 400
				_ => Bool.False
			}
		)
}

# R-CT2, R-AP70 row 6 (Design Q176), R-MX5, R-AP10: the members that a hint request must not have are 400, with any value. `error_digest` in a row (a text, `null`, a number): no table keeps it.
# `source` in the body or in a row: text, `null`, number, object, a key written with an escape (`\u0073ource`), white space before the colon (R-MX5, G17: the reader ignores unknown members,
# so these need their own check). `sweep` in the body is for the bot only (R-AP10). The `detail` names the member when the value is a text or `null`.
expect {
	ok_row = row(h1, t1, "any", "pass")
	with_member = |member| "{\"talon_version\":\"0.4.1\",\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",${member}}]}"
	in_body = |member| "{\"talon_version\":\"0.4.1\",${member},\"rows\":[${ok_row}]}"
	digest = ["\"error_digest\":\"boom\"", "\"error_digest\":null", "\"error_digest\":1", "\"error_digest\":\"\""]
	source_row = ["\"source\":\"bot\"", "\"source\":null", "\"source\":1", "\"source\":{\"a\":[]}", "\"\\u0073ource\":\"bot\"", "\"source\" : \"bot\""]
	source_body = ["\"source\":\"author\"", "\"source\":null", "\"source\":true", "\"\\u0073ource\":1"]
	named = |text, member| is_400(text) and detail_of(text).contains(member)
	digest.all(|m| is_400(with_member(m)))
		and source_row.all(|m| is_400(with_member(m)))
		and source_body.all(|m| is_400(in_body(m)))
		and named(with_member("\"error_digest\":\"boom\""), "error_digest")
		and named(with_member("\"error_digest\":null"), "error_digest")
		and named(with_member("\"source\":\"bot\""), "source")
		and named(with_member("\"source\":null"), "source")
		and named(in_body("\"source\":\"author\""), "source")
		and named(in_body("\"source\":null"), "source")
		and is_400(in_body("\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":3}"))
}

# R-CT2, R-AP66 check 6 (as the bot path), R-IK4, R-IK7: the values. A `hash` that is not base58 of 32 bytes, a `nightly` with no nightly id, a `result` that is not `pass`, `fail` or `crash`
# (a `hang` is not a hint, "Pass" is not `pass`) are 400. In a row the order of the faults is `hash`, `nightly`, `result`, and the first bad row of the body wins.
expect {
	bad_hash = [row("abc", t1, "any", "pass"), row("", t1, "any", "pass"), row("0OIl", t1, "any", "pass"), row("${h4}${h4}", t1, "any", "pass")]
	bad_nightly = [row(h1, "nightly-2026-10-21", "any", "pass"), row(h1, "", "any", "pass"), row(h1, "nightly-2026-13-40-5349569", "any", "pass"), row(h1, "2026-10-21-5349569", "any", "pass")]
	bad_result = [row(h1, t1, "any", "hang"), row(h1, t1, "any", "maybe"), row(h1, t1, "any", "Pass"), row(h1, t1, "any", "")]
	d = |rows| detail_of(body_of("0.4.1", rows))
	bad_hash.all(|r| is_400(body_of("0.4.1", [r])))
		and bad_nightly.all(|r| is_400(body_of("0.4.1", [r])))
		and bad_result.all(|r| is_400(body_of("0.4.1", [r])))
		and d([row("abc", "nope", "any", "hang")]).contains("hash")
		and d([row(h1, "nope", "any", "hang")]).contains("nightly")
		and d([row(h1, t1, "any", "hang")]).contains("result")
		and d([good_row, row("abc", t1, "any", "pass"), row(h1, "nope", "any", "pass")]).contains("abc")
		and d([good_row, row(h1, "nope", "any", "pass"), row("abc", t1, "any", "pass")]).contains("nope")
}

# R-CT2, R-AP46, R-AP48 row 4: 500 rows are good and 501 are 413 with `field` `rows` and `limit` 500. A body of 262,144 bytes is good, one of 262,145 bytes is 413 `body`, also when it is not JSON.
# The limits come before the checks of the values: 501 rows with a bad hash are 413 (Design Q143 for the bot path).
expect {
	pad = |n| "{\"p\":\"${"x".repeat(n)}\",\"talon_version\":\"0.4.1\",\"rows\":[${good_row}]}"
	base = pad(0).count_utf8_bytes()
	at_limit = pad(Compat.body_limit - base)
	over = pad(Compat.body_limit - base + 1)
	r500 = body_of("0.4.1", List.repeat(good_row, 500))
	r501 = body_of("0.4.1", List.repeat(good_row, 501))
	bad501 = body_of("0.4.1", List.repeat(row("abc", t1, "any", "pass"), 501))
	garbage = "x".repeat(Compat.body_limit + 1)
	Compat.body_limit == 262_144
		and at_limit.count_utf8_bytes() == 262_144
		and status_of(at_limit) == 200
		and field_of(over) == "body:262144"
		and field_of(garbage) == "body:262144"
		and status_of(r500) == 200
		and field_of(r501) == "rows:500"
		and status_of(r501) == 413
		and field_of(bad501) == "rows:500"
}

# R-AP41 row 2: the lists of the read batch. The distinct ids in the order of the first row, as JSON integers (negative too); the distinct names other than `any`, as JSON strings with escapes.
expect {
	post = post_of([(h1, id1, "any", Pass), (h3, id3, "x64glibc", Pass), (h1, id1, "wasm32", Fail), (h4, id4, "x64glibc", Crash), (h2, id2, "a\"b", Pass)])
	Hints.read_params(post) == { artifacts_json: "[5265119941757224538,-3201922985822262901,-4418864005132459968,5499626537489496528]", targets_json: "[\"x64glibc\",\"wasm32\",\"a\\\"b\"]" }
		and Hints.read_params(post_of([])) == { artifacts_json: "[]", targets_json: "[]" }
		and Hints.read_params(post_of([(h1, id1, "any", Pass)])) == { artifacts_json: "[5265119941757224538]", targets_json: "[]" }
}

# R-CT2, R-CT14, R-MX10 (as the bot path): the 400 of a row against the facts. `any` is code 0 for every kind. A real target: package is 400 (also a name with no code); platform: the name needs a pair in
# `platform_targets` (R-CT2, Design Q173), a name with no code is a skip (`NoCode`); app: any name with a code. A hash with no fact is never a 400 (the batch skips it), also with a real target.
# The result lists all rows in the body order, with the index and the result code (pass 0, fail 1, crash 3).
expect {
	items = [
		(h1, id1, "any", Pass),
		(h2, id2, "x64glibc", Fail),
		(h3, id3, "wasm32", Crash),
		(h3, id3, "nonesuch", Pass),
		(h2, id2, "nonesuch", Pass),
		(h4, id4, "x64glibc", Pass),
		(h4, id4, "nonesuch", Fail),
		(h2, id2, "any", Pass),
		(h3, id3, "any", Pass),
	]
	first_bad = check_detail([(h3, id3, "any", Pass), (h1, id1, "x64glibc", Pass), (h2, id2, "wasm32", Pass)])
	Hints.check(post_of(items), facts)
		== Ok([
			{ index: 0, artifact: id1, nightly: n1, target: Ok(0), result: 0 },
			{ index: 1, artifact: id2, nightly: n1, target: Ok(8), result: 1 },
			{ index: 2, artifact: id3, nightly: n1, target: Ok(34), result: 3 },
			{ index: 3, artifact: id3, nightly: n1, target: Err(NoCode), result: 0 },
			{ index: 4, artifact: id2, nightly: n1, target: Err(NoCode), result: 0 },
			{ index: 5, artifact: id4, nightly: n1, target: Ok(8), result: 0 },
			{ index: 6, artifact: id4, nightly: n1, target: Err(NoCode), result: 1 },
			{ index: 7, artifact: id2, nightly: n1, target: Ok(0), result: 0 },
			{ index: 8, artifact: id3, nightly: n1, target: Ok(0), result: 0 },
		])
		and Hints.check(post_of([]), facts) == Ok([])
		and check_detail([(h1, id1, "x64glibc", Pass)]).starts_with("400 ")
		and check_detail([(h1, id1, "nonesuch", Pass)]).starts_with("400 ")
		and check_detail([(h2, id2, "wasm32", Pass)]).starts_with("400 ")
		and first_bad.starts_with("400 ")
		and first_bad.contains(h1)
		and !first_bad.contains(h2)
		and check_detail([(h1, id1, "x64glibc", Pass)]).contains("x64glibc")
}

# R-AP41 row 2, R-CT4: the parameter ?1 of the write statements: one JSON array, the members `i`, `artifact`, `nightly`, `target`, `result` in this order, ids as JSON integers (R-IK2: SQLite reads a 64-bit
# JSON integer exactly), `null` for a name with no code.
expect {
	rows = [
		{ index: 0, artifact: id1, nightly: n1, target: Ok(0), result: 0 },
		{ index: 3, artifact: id3, nightly: n2, target: Err(NoCode), result: 3 },
	]
	Hints.rows_json(rows)
		== "[{\"i\":0,\"artifact\":5265119941757224538,\"nightly\":5569317737833,\"target\":0,\"result\":0},{\"i\":3,\"artifact\":-3201922985822262901,\"nightly\":5572174540651,\"target\":null,\"result\":3}]"
		and Hints.rows_json([]) == "[]"
}

# R-CT3, R-IK2: the contributor id of a machine. The message of the HMAC is the 32 characters of the id as UTF-8 bytes (R-CT3, Design Q175). The id is the first 8 bytes of the HMAC-SHA256 output, big-endian, with the top
# bit set. The HMAC outputs and the ids are from research/slice-116-revert/gen/vectors.mjs (node crypto, key `test-contributor-key`; the HMAC itself is checked by the W2 case ct4-hint-batch). Always below 0.
expect {
	mac1 = [0x20, 0x5E, 0x42, 0x56, 0x1E, 0xB7, 0x11, 0xDB, 0x13, 0xB1, 0x62, 0x82, 0xAD, 0x94, 0x43, 0x17, 0x6B, 0xC1, 0x3F, 0x3E, 0x43, 0x23, 0xD3, 0x5A, 0xB1, 0xFC, 0x74, 0xF2, 0x59, 0xC8, 0x4D, 0xDA]
	mac2 = [0x51, 0x2B, 0xEF, 0xC0, 0x67, 0xF9, 0xB9, 0x77, 0x13, 0x9D, 0xBB, 0xFE, 0x10, 0x3A, 0x19, 0x2D, 0x1F, 0x93, 0x31, 0xCE, 0x87, 0x71, 0xD1, 0x90, 0x65, 0xD3, 0x67, 0x43, 0x33, 0x88, 0x15, 0x84]
	mac3 = [0x79, 0xB5, 0x6D, 0x70, 0xBE, 0x89, 0x13, 0x07, 0xFB, 0xD2, 0x3C, 0xDE, 0xBC, 0x1A, 0xAD, 0x89, 0xA4, 0x50, 0x22, 0x36, 0xE9, 0x97, 0x11, 0xBE, 0x51, 0xDD, 0x03, 0x03, 0x2F, 0xDB, 0x06, 0x00]
	Hints.hmac_message(m1) == m1.to_utf8()
		and Hints.hmac_message(m1).len() == 32
		and Hints.contributor_id(mac1) == -6890997442180345381
		and Hints.contributor_id(mac2) == -3374339886126876297
		and Hints.contributor_id(mac3) == -453335856480447737
		and Hints.contributor_id(List.repeat(0, 32)) == I64.lowest
		and Hints.contributor_id(List.repeat(0xFF, 32)) == -1
		and Hints.contributor_id([0x01, 0, 0, 0, 0, 0, 0, 0x02]) == -9151314442816847870
}

# R-CT12, R-IK5: `talon_version`. A release of Talon is a tag `v<version>` in the tag list; its key is the key of `Semver.to_key` (no flip, R-IK5, Design Q177), a pre-release has its own key. Anything else is 0 (`unknown`):
# not in the list, the `v` in the text, a number that is written another way (`0.4.01`), an empty text, a text that is no semver, an empty list. The values are from vectors.mjs.
expect {
	tags = ["v0.4.1", "v1.2.3", "v0.5.0-rc.1", "v0.10.0", "vbanana", "v"]
	k = |version| Hints.talon_key({ version, tags })
	k("0.4.1") == 17180000255
		and k("1.2.3") == 281483566907391
		and k("0.5.0-rc.1") == 21474844191
		and k("0.10.0") == 42949738495
		and k("0.4.2") == 0
		and k("v0.4.1") == 0
		and k("0.4.01") == 0
		and k("") == 0
		and k("banana") == 0
		and k("0.5.0") == 0
		and Hints.talon_key({ version: "0.4.1", tags: [] }) == 0
		and Hints.unknown_version == 0
}

# R-CT12: the names in the answer of the GitHub tag list. Other members are ignored; an empty array is good; an item with no text `name`, or text that is no array, is `BadTags`.
expect {
	text = "[{\"name\":\"v0.4.1\",\"zipball_url\":\"https://x\",\"commit\":{\"sha\":\"abc\"}},{\"name\":\"v0.4.0\"},{\"name\":\"nightly\",\"node_id\":\"x\"}]"
	Hints.tag_names(text) == Ok(["v0.4.1", "v0.4.0", "nightly"])
		and Hints.tag_names("[]") == Ok([])
		and Hints.tag_names("{\"name\":\"v1\"}") == Err(BadTags)
		and Hints.tag_names("[{\"name\":1}]") == Err(BadTags)
		and Hints.tag_names("[{\"tag\":\"v1\"}]") == Err(BadTags)
		and Hints.tag_names("not json") == Err(BadTags)
		and Hints.tag_names("") == Err(BadTags)
		and Hints.tags_url == "https://api.github.com/repos/roc-talon/talon/tags?per_page=100"
}

# R-AP10, R-CT4, R-CT14: the answer. The members `written`, `first`, `skipped` in this order; `skipped` is always there; the items keep the order given. The status is 201 when `written` is above 0 (`Compat.written_status`).
expect {
	two = [{ row: 0, reason: "unknown-hash" }, { row: 3, reason: "bot-row" }]
	Hints.answer_body({ written: 2, first: 1, skipped: two }) == "{\"written\":2,\"first\":1,\"skipped\":[{\"row\":0,\"reason\":\"unknown-hash\"},{\"row\":3,\"reason\":\"bot-row\"}]}"
		and Hints.answer_body({ written: 0, first: 0, skipped: [] }) == "{\"written\":0,\"first\":0,\"skipped\":[]}"
		and Compat.written_status(2) == 201
		and Compat.written_status(0) == 200
}

# R-CT13, R-MX9, R-AP25: the failed batch. `Trigger` with the whole text `hint-quota` is `Quota`; any other kind, any other text, a text that only contains it, is a `Fault`. `Retry-After` is the time to the next
# UTC day in whole seconds, rounded up (R-CT13, Design Q179). The problem is `rate-limited` (429).
expect {
	is_quota = |c| Hints.failure_of(c) == Quota
	is_fault = |c| match Hints.failure_of(c) {
		Fault(_) => Bool.True
		Quota => Bool.False
	}
	day = 1_767_225_600_000
	is_quota({ kind: Trigger, message: "hint-quota" })
		and is_fault({ kind: Check, message: "hint-quota" })
		and is_fault({ kind: Other, message: "hint-quota" })
		and is_fault({ kind: Trigger, message: "hint-quota: more" })
		and is_fault({ kind: Trigger, message: "Hint-Quota" })
		and is_fault({ kind: Trigger, message: "sweep-incomplete" })
		and is_fault({ kind: Check, message: "CHECK constraint failed" })
		and Hints.retry_after(day) == 86_400
		and Hints.retry_after(day + 1_000) == 86_399
		and Hints.retry_after(day + 1) == 86_400
		and Hints.retry_after(day + 43_200_000) == 43_200
		and Hints.retry_after(day + 86_399_500) == 1
		and Hints.retry_after(day + 86_399_999) == 1
		and Hints.retry_after(day + 86_400_000) == 86_400
		and Hints.quota_problem().http_status() == 429
		and Hints.quota_problem().to_json().contains("rate-limited")
}

# R-CT4, R-CT13, R-CT14, R-RE16 (Design Q174: 12 months are 31,536,000,000 ms): the SQL texts. The key words that W2 can not see in every case. The statements read the rows with `json_each(?1)`. The insert never uses `OR IGNORE` or `OR REPLACE`
# (R-CT4: `OR IGNORE` drops a row that fails a `CHECK`), ends with the conflict target of the primary key and `DO NOTHING`, and has `RETURNING` (`written` is the count of returned rows, R-CT4) and the link lookup of R-CT3.
# The skip reasons are the 5 texts of R-CT14, and no statement uses a parameter above ?4.
expect {
	first = Hints.first_sql()
	skipped = Hints.skipped_sql()
	insert = Hints.insert_sql()
	all = [first, skipped, insert]
	all.all(|s| s.contains("json_each(?1)"))
		and !all.any(|s| s.contains("?5"))
		and first.contains("compat_hints")
		and first.contains("compat")
		and skipped.contains("unknown-hash")
		and skipped.contains("unknown-nightly")
		and skipped.contains("unknown-target")
		and skipped.contains("bot-row")
		and skipped.contains("old-nightly")
		and skipped.contains("31536000000")
		and insert.contains("INSERT INTO contributions")
		and insert.contains("ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING")
		and insert.contains("RETURNING")
		and insert.contains("COALESCE")
		and insert.contains("links")
		and !insert.contains("OR IGNORE")
		and !insert.contains("OR REPLACE")
		and !all.any(|s| s.contains("INSERT OR"))
}
