import lib.Compat
import lib.Problem
import lib.Route
import records.Code

CompatTest :: [].{}

# W0 tests of worker/lib/Compat.roc (slice 115a). The ids, base58 texts and nightly ids below are made by
# research/slice-115-revert/gen/ids.py with python (hashlib): no expected id comes from the Roc code.
# The questions Q115-1 to Q115-8 are settled (Design Q139 to Q146, Registry R-AP66). The order of the checks of the bot path is the table of R-AP66.

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

# ---- helpers ----

# One row of a body. `digest` is the JSON text of the value ("null", "\"boom\"").
row : Str, Str, Str, Str, Str -> Str
row = |hash, nightly, target, result, digest| "{\"hash\":\"${hash}\",\"nightly\":\"${nightly}\",\"target\":\"${target}\",\"result\":\"${result}\",\"error_digest\":${digest}}"

good_row : Str
good_row = row(h1, t1, "any", "pass", "null")

body_rows : List(Str) -> Str
body_rows = |rows| "{\"rows\":[${Str.join_with(rows, ",")}]}"

parse_text : Str -> Try(Compat.Post, Compat.Reject)
parse_text = |text| Compat.parse_post(text.to_utf8())

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

# The `field` of a 413.
field_of : Str -> Str
field_of = |text| match parse_text(text) {
	Err(TooLarge(_, extra)) => "${extra.field}:${extra.limit.to_str()}"
	_ => ""
}

is_400 : Str -> Bool
is_400 = |text| match parse_text(text) {
	Err(Bad(p)) => p.http_status() == 400
	_ => Bool.False
}

# "H1" to "H<n>".
names_upto : U64 -> List(Str)
names_upto = |n| {
	var $out = []
	var $i = 1.U64
	while $i <= n {
		$out = $out.append("H${$i.to_str()}")
		$i = $i + 1
	}
	$out
}

is_fault : [SweepIncomplete, Bad(Problem), Fault(Str)] -> Bool
is_fault = |f| match f {
	Fault(_) => Bool.True
	_ => Bool.False
}

# ---- tests ----

# R-AP10, R-AP66, R-AP51, R-AP44, R-AP58, R-IK2, R-IK4, R-IK7, R-MX4: a good body. Rows in order, the ids (python), the 4 results, `null` and text digests (an empty text is a digest),
# the month-name tag form, a target other than `any`, a sweep, unknown members ignored in the body, a row and the sweep.
expect {
	body = "{\"extra\":1,\"rows\":[${row(h1, t1, "any", "pass", "null")},${row(h2, t2, "x64glibc", "fail", "\"boom\"")},{\"hash\":\"${h3}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"hang\",\"error_digest\":\"\",\"note\":[1]},${row(h4, t1, "wasm32", "crash", "\"a\\\"b\"")}],\"sweep\":{\"nightly\":\"${t2}\",\"target\":\"any\",\"upto_log_index\":24,\"x\":null}}"
	parse_text(body)
		== Ok({
			rows: [
				{ hash: h1, artifact: id1, nightly: n1, target: "any", result: Pass, error_digest: Err(None) },
				{ hash: h2, artifact: id2, nightly: n2, target: "x64glibc", result: Fail, error_digest: Ok("boom") },
				{ hash: h3, artifact: id3, nightly: n1, target: "any", result: Hang, error_digest: Ok("") },
				{ hash: h4, artifact: id4, nightly: n1, target: "wasm32", result: Crash, error_digest: Ok("a\"b") },
			],
			sweep: Ok({ tag: t2, nightly: n2, upto_log_index: 24 }),
		})
		and parse_text(body_rows([])) == Ok({ rows: [], sweep: Err(None) })
		and parse_text("{\"rows\":[],\"sweep\":null}") == Ok({ rows: [], sweep: Err(None) })
		and parse_text("{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":0}}") == Ok({ rows: [], sweep: Ok({ tag: t1, nightly: n1, upto_log_index: 0 }) })
		and parse_text("{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":9223372036854775807}}")
			== Ok({ rows: [], sweep: Ok({ tag: t1, nightly: n1, upto_log_index: 9223372036854775807 }) })
}

# R-MX5, R-AP66 check 4 (Design Q139), R-AP44, G17 of docs/registry/PLAN.md: the derived JSON reader ignores an unknown member, so `source` needs its own check. A body with a member `source` is 400: any value
# (text, null, number, object), a key written with an escape (`\u0073ource`), white space before the colon. A text that holds the word is no member: the digest `source`, a digest
# that holds `"source":1`, a hash-like text. Those bodies are good.
expect {
	bad = [
		"{\"rows\":[],\"source\":\"bot\"}",
		"{\"rows\":[],\"source\":\"author\"}",
		"{\"source\":null,\"rows\":[]}",
		"{\"rows\":[],\"\\u0073ource\":\"bot\"}",
		"{\"rows\":[],\"source\" : \"bot\"}",
		"{\"rows\":[],\"sweep\":null,\"source\":\"bot\"}",
	]
	typed = [
		"{\"rows\":[],\"source\":1}",
		"{\"rows\":[],\"source\":{\"a\":[]}}",
		"{\"rows\":[],\"source\":[\"bot\"]}",
		"{\"rows\":[],\"source\":true}",
	]
	good = [
		body_rows([row(h1, t1, "any", "fail", "\"source\"")]),
		body_rows([row(h1, t1, "any", "fail", "\"x\\\"source\\\":1\"")]),
		body_rows([row(h1, t1, "any", "fail", "\"{\\\"source\\\": \\\"bot\\\"}\"")]),
	]
	bad.all(is_400)
		and typed.all(is_400)
		and bad.all(|t| detail_of(t).contains("source"))
		and good.all(|t| status_of(t) == 200)
		and parse_text(body_rows([row(h1, t1, "any", "fail", "\"{\\\"source\\\": \\\"bot\\\"}\"")]))
			== Ok({ rows: [{ hash: h1, artifact: id1, nightly: n1, target: "any", result: Fail, error_digest: Ok("{\"source\": \"bot\"}") }], sweep: Err(None) })
}

# R-AP51, R-AP66 check 4, R-AP48 row 6, R-MX4: a body that does not decode is 400 `bad-request`. A missing member is named in the `detail` (R-AP51).
expect {
	bad = [
		"",
		"not json",
		"[]",
		"{}",
		"{\"rows\":null}",
		"{\"rows\":{}}",
		"{\"rows\":1}",
		"{\"rows\":[1]}",
		"{\"rows\":[null]}",
		"{\"rows\":[\"${h1}\"]}",
		"{\"rows\":[{\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"result\":\"pass\",\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":null,\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":5,\"result\":\"pass\",\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":1,\"error_digest\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":5}]}",
		row(h1, t1, "any", "maybe", "null"),
		body_rows([row(h1, t1, "any", "maybe", "null")]),
		body_rows([row(h1, t1, "any", "Pass", "null")]),
		body_rows([row(h1, t1, "any", "", "null")]),
		body_rows([row(h1, "nightly-2026-02-30-5349569", "any", "pass", "null")]),
		body_rows([row(h1, "latest", "any", "pass", "null")]),
		body_rows([good_row, row(h2, "nightly-2026-10-21-534956", "any", "pass", "null")]),
		"{\"rows\":[],\"sweep\":1}",
		"{\"rows\":[],\"sweep\":[]}",
		"{\"rows\":[],\"sweep\":{\"target\":\"any\",\"upto_log_index\":1}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"upto_log_index\":1}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\"}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"nightly-2026-13-01-5349569\",\"target\":\"any\",\"upto_log_index\":1}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"x64glibc\",\"upto_log_index\":1}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"\",\"upto_log_index\":1}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":-1}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":1.5}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":\"24\"}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":null}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":9223372036854775808}}",
		"{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"upto_log_index\":18446744073709551615}}",
	]
	not_utf8 = Compat.parse_post([123, 34, 255, 254, 125])
	bad.all(is_400)
		and (
			match not_utf8 {
				Err(Bad(p)) => p.http_status() == 400
				_ => Bool.False
			}
		)
		and detail_of("{}").contains("rows")
		and detail_of("{\"rows\":[{\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]}").contains("hash")
		and detail_of("{\"rows\":[{\"hash\":\"${h1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]}").contains("nightly")
		and detail_of("{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"upto_log_index\":1}}").contains("target")
		and detail_of("{\"rows\":[],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\"}}").contains("upto_log_index")
}

# R-AP66 check 4 and 6, R-MX5, R-AP58 (Design Q139, Q140, Q141): a `source` in a row is 400 (like the body); a row without `error_digest` is 400 and with `null` is good (R-AP51: the reader needs `null` for a
# member that the rule lets be none; the member is required, R-AP10 lists it); a `hash` that is not base58 of 32 bytes (a short text, a 31-byte hash, a text with `0`, an empty text) is 400.
expect {
	short = "thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE"
	bad = [
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null,\"source\":\"bot\"}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null,\"source\":null}]}",
		"{\"rows\":[{\"hash\":\"${h1}\",\"nightly\":\"${t1}\",\"target\":\"any\",\"result\":\"pass\"}]}",
		body_rows([row("abc", t1, "any", "pass", "null")]),
		body_rows([row(short, t1, "any", "pass", "null")]),
		body_rows([row("0OIl", t1, "any", "pass", "null")]),
		body_rows([row("", t1, "any", "pass", "null")]),
		body_rows([good_row, row("${h1}${h1}", t1, "any", "pass", "null")]),
	]
	bad.all(is_400)
		and detail_of(body_rows([row("abc", t1, "any", "pass", "null")])).contains("hash")
		and status_of(body_rows([row(h1, t1, "any", "pass", "null")])) == 200
}

# R-AP66 check 6, Design Q142: the values are checked row by row, and in a row `hash`, then `nightly`, then `result`. The first fault gives the `detail`. A fault of row 1 comes before
# a fault of row 2, and a fault of a later row is a 400 also when the rows before it are good.
expect {
	r = |hash, nightly, result| row(hash, nightly, "any", result, "null")
	detail_of(body_rows([r("abc", "latest", "maybe")])).contains("hash")
		and !detail_of(body_rows([r("abc", "latest", "maybe")])).contains("nightly")
		and detail_of(body_rows([r(h1, "latest", "maybe")])).contains("nightly")
		and !detail_of(body_rows([r(h1, "latest", "maybe")])).contains("result")
		and detail_of(body_rows([r(h1, t1, "maybe")])).contains("result")
		and detail_of(body_rows([r(h1, "latest", "pass"), r("abc", t1, "pass")])).contains("nightly")
		and detail_of(body_rows([r(h1, t1, "pass"), r(h2, t1, "pass"), r("abc", t1, "pass")])).contains("hash")
		and detail_of(body_rows([r(h1, t1, "maybe"), r("abc", t1, "pass")])).contains("result")
}

# R-AP46, R-AP66 checks 2 and 5, R-AP48 rows 4 and 6: the body limit is 256 KB (262,144 bytes), `rows` 500. One more is 413 with `field` and `limit`. The limits come before the checks of the values
# (R-AP66 checks 4 to 6, Design Q143, as R-AP62): 501 rows with a bad first row are 413. A body that does not decode and has 501 rows is 400. The body check is before the decode.
expect {
	ok = body_rows([good_row])
	pad = |n| "{\"rows\":[${row(h1, t1, "any", "fail", "\"${"x".repeat(n)}\"")}]}"
	base = pad(0).count_utf8_bytes()
	at_limit = pad(Compat.body_limit - base)
	over = pad(Compat.body_limit - base + 1)
	r500 = body_rows(List.repeat(good_row, 500))
	r501 = body_rows(List.repeat(good_row, 501))
	bad501 = body_rows(List.append(List.repeat(row("abc", t1, "any", "pass", "null"), 501), good_row))
	bad501b = body_rows(List.repeat(row(h1, t1, "any", "maybe", "null"), 501))
	broken501 = "{\"rows\":[${Str.join_with(List.repeat("1", 501), ",")}]}"
	Compat.body_limit == 262_144
		and Compat.row_limit == 500
		and status_of(ok) == 200
		and at_limit.count_utf8_bytes() == 262_144
		and status_of(at_limit) == 200
		and status_of(over) == 413
		and field_of(over) == "body:262144"
		and field_of("x".repeat(Compat.body_limit + 1)) == "body:262144"
		and status_of(r500) == 200
		and status_of(r501) == 413
		and field_of(r501) == "rows:500"
		and field_of(bad501) == "rows:500"
		and field_of(bad501b) == "rows:500"
		and status_of(broken501) == 400
		and Compat.too_large("rows", 500)
			== TooLarge(Problem.new(TooLarge, "the rows of the compat request is larger than its limit of 500"), { field: "rows", limit: 500 })
}

# R-AP41 row 2, R-IK2: the lists of the read batch. The ids are JSON integers (64-bit, negative ones too), distinct, in the order of the first row. The target names other than `any`
# are distinct JSON strings in the same order; a name with a quote or a backslash is escaped.
expect {
	r = |hash, id, target| { hash, artifact: id, nightly: n1, target, result: Pass, error_digest: Err(None) }
	post = |rows| { rows, sweep: Err(None) }
	Compat.read_params(post([r(h1, id1, "any"), r(h3, id3, "x64glibc"), r(h1, id1, "wasm32"), r(h2, id2, "x64glibc"), r(h3, id3, "any")]))
		== { artifacts_json: "[5265119941757224538,-3201922985822262901,5499626537489496528]", targets_json: "[\"x64glibc\",\"wasm32\"]" }
		and Compat.read_params(post([r(h1, id1, "any")])) == { artifacts_json: "[5265119941757224538]", targets_json: "[]" }
		and Compat.read_params(post([])) == { artifacts_json: "[]", targets_json: "[]" }
		and Compat.read_params(post([r(h1, id1, "a\"b\\c")])).targets_json == "[\"a\\\"b\\\\c\"]"
}

# R-AP10, R-AP66 check 8, R-MX10, R-IK7, R-RE20, R-AP56: `plan` against the facts of the read batch. `any` is code 0 for each kind (package 1, platform 2, app 0). A real target needs a platform
# whose `artifact_targets` has the code of the name: the codes 8 and 34 are the list of R-IK7, 36 is a name that the registry added. The first row that fails gives the problem,
# and for one row the 404 (no artifact fact) comes before the 400 (R-AP66 check 8, Design Q142): row 1 with a 400 and row 2 with a 404 gives the 400; row 1 with a 404 and row 2 with a
# 400 gives the 404; one row with a 404 and a bad target gives the 404.
expect {
	row_of = |hash, id, target, result| { hash, artifact: id, nightly: n1, target, result, error_digest: Err(None) }
	facts = {
		artifacts: [{ artifact: id1, kind: 1 }, { artifact: id2, kind: 2 }, { artifact: id3, kind: 0 }],
		target_rows: [{ name: "x64glibc", target: 8 }, { name: "wasm32", target: 34 }, { name: "x64mac", target: 1 }, { name: "zzz", target: 36 }],
		platform_targets: [{ artifact: id2, target: 8 }, { artifact: id2, target: 34 }, { artifact: id2, target: 36 }],
	}
	post = |rows| { rows, sweep: Err(None) }
	plan_of = |rows| Compat.plan(post(rows), facts)
	status_of_plan = |rows| match plan_of(rows) {
		Err(p) => p.http_status()
		Ok(_) => 200
	}
	problem_of = |rows| match plan_of(rows) {
		Err(p) => Ok(p)
		Ok(_) => Err(Planned)
	}
	good = [
		row_of(h1, id1, "any", Pass),
		row_of(h2, id2, "x64glibc", Fail),
		row_of(h2, id2, "wasm32", Crash),
		row_of(h2, id2, "zzz", Hang),
		row_of(h2, id2, "any", Pass),
	]
	plan_of(good)
		== Ok([
			{ artifact: id1, nightly: n1, target: 0, result: 0, error_digest: Err(None) },
			{ artifact: id2, nightly: n1, target: 8, result: 1, error_digest: Err(None) },
			{ artifact: id2, nightly: n1, target: 34, result: 3, error_digest: Err(None) },
			{ artifact: id2, nightly: n1, target: 36, result: 2, error_digest: Err(None) },
			{ artifact: id2, nightly: n1, target: 0, result: 0, error_digest: Err(None) },
		])
		and plan_of([{ hash: h3, artifact: id3, nightly: n2, target: "any", result: Fail, error_digest: Ok("e") }])
			== Ok([{ artifact: id3, nightly: n2, target: 0, result: 1, error_digest: Ok("e") }])
		and plan_of([]) == Ok([])
		and problem_of([row_of(h4, id4, "any", Pass)]) == Ok(Problem.new(NotFound, "no artifact ${h4}"))
		and problem_of([row_of(h4, id4, "x64glibc", Pass)]) == Ok(Problem.new(NotFound, "no artifact ${h4}"))
		and problem_of([row_of(h1, id1, "any", Pass), row_of(h4, id4, "any", Pass), row_of(h1, id1, "x64glibc", Pass)]) == Ok(Problem.new(NotFound, "no artifact ${h4}"))
		and status_of_plan([row_of(h1, id1, "x64glibc", Pass), row_of(h4, id4, "any", Pass)]) == 400
		and problem_of([row_of(h4, id4, "any", Pass), row_of(h1, id1, "x64glibc", Pass)]) == Ok(Problem.new(NotFound, "no artifact ${h4}"))
		and problem_of([row_of(h4, id4, "nosuch", Pass)]) == Ok(Problem.new(NotFound, "no artifact ${h4}"))
		and problem_of([row_of(h4, id4, "any", Pass), row_of(h2, id2, "nosuch", Pass)]) == Ok(Problem.new(NotFound, "no artifact ${h4}"))
		and [
			row_of(h1, id1, "x64glibc", Pass),
			row_of(h3, id3, "wasm32", Pass),
			row_of(h2, id2, "nosuch", Pass),
			row_of(h2, id2, "x64mac", Pass),
		].all(|r| status_of_plan([row_of(h2, id2, "any", Pass), r]) == 400)
		and (
			match problem_of([row_of(h2, id2, "nosuch", Pass)]) {
				Ok(p) => p.to_json().contains("nosuch")
				_ => Bool.False
			}
		)
		and (
			match problem_of([row_of(h2, id2, "x64mac", Pass)]) {
				Ok(p) => p.to_json().contains("x64mac")
				_ => Bool.False
			}
		)
}

# R-MX9, R-MX8: the mapping of a batch error. The kind and the whole message: `sweep-incomplete` and `sweep-bound` as a trigger text only. Another text, `sweep-smaller`,
# `leaf-missing`, the D1 raw form, a text that only has the words, another kind: 500 (`Fault`).
expect {
	trig = |m| Compat.failure_of({ kind: Trigger, message: m })
	trig("sweep-incomplete") == SweepIncomplete
		and trig("sweep-bound") == Bad(Problem.new(BadRequest, "the sweep upto_log_index is larger than the log size"))
		and is_fault(trig("sweep-smaller"))
		and is_fault(trig("leaf-missing"))
		and is_fault(trig("label-conflict"))
		and is_fault(trig("hint-quota"))
		and is_fault(trig("sweep-incomplete "))
		and is_fault(trig("Sweep-Incomplete"))
		and is_fault(trig("D1_ERROR: sweep-incomplete: SQLITE_CONSTRAINT"))
		and is_fault(trig("sweep-bound: x"))
		and is_fault(trig("a sweep-bound"))
		and is_fault(trig(""))
		and is_fault(Compat.failure_of({ kind: PrimaryKey, message: "sweep-incomplete" }))
		and is_fault(Compat.failure_of({ kind: Check, message: "sweep-bound" }))
		and is_fault(Compat.failure_of({ kind: Other, message: "sweep-incomplete" }))
		and is_fault(Compat.failure_of({ kind: PrimaryKey, message: "UNIQUE constraint failed: names.id" }))
}

# R-MX9, R-AP21, R-AP66 check 10 (Design Q145): the 422 `sweep-incomplete`. The `detail` lists at most 100 hashes (the first ones), then `and <n> more`. 1 hash, 100 hashes (no `more`),
# 101, 250. The list can be empty (another request wrote the missing rows between call 2 and call 3): the answer stays 422, with its own `detail`.
expect {
	hashes = names_upto
	problem = |n| Compat.sweep_incomplete({ tag: t1, upto_log_index: 24, missing: hashes(n) })
	p3 = problem(3)
	p100 = problem(100)
	p101 = problem(101)
	p250 = problem(250)
	has_tail = |p, tail| p.to_json().contains("${tail}\",\"status\"")
	Compat.missing_limit == 100
		and p3.http_status() == 422
		and problem(0).http_status() == 422
		and problem(0).to_json().contains("\"type\":\"/errors/sweep-incomplete\"")
		and problem(0)
			== Problem.new(SweepIncomplete, "the sweep of ${t1} up to the log index 24 was incomplete, but no member has no bot row now: send the request again")
		and p3.to_json().contains("\"type\":\"/errors/sweep-incomplete\"")
		and p3 == Problem.new(SweepIncomplete, "the sweep of ${t1} up to the log index 24 is incomplete: 3 members of the bot set have no bot row: H1, H2, H3")
		and problem(1) == Problem.new(SweepIncomplete, "the sweep of ${t1} up to the log index 24 is incomplete: 1 members of the bot set have no bot row: H1")
		and p100.to_json().contains("100 members")
		and has_tail(p100, ", H99, H100")
		and !p100.to_json().contains("more")
		and p101.to_json().contains("101 members")
		and has_tail(p101, ", H99, H100, and 1 more")
		and !p101.to_json().contains("H101")
		and p250.to_json().contains("250 members")
		and has_tail(p250, ", H99, H100, and 150 more")
		and !p250.to_json().contains("H101")
		and p250.to_json().contains("H1, H2, H3, H4")
}

# R-AP10: 201 when `written` is above 0, else 200 (each row was there). The body is `{"written":<n>}`.
expect {
	Compat.written_status(0) == 200
		and Compat.written_status(1) == 201
		and Compat.written_status(500) == 201
		and Compat.written_body(0) == "{\"written\":0}"
		and Compat.written_body(37) == "{\"written\":37}"
}

# R-MX5, R-CT1, R-AP66 check 3 (Design Q146): a token selects `Bot`; with no token a `Talon-Contributor` header selects `Hint` (slice 116); with neither the request is 400.
expect {
	Compat.request_kind({ authorization: Ok("Bearer x"), contributor: Err(NotFound) }) == Bot
		and Compat.request_kind({ authorization: Ok("Bearer x"), contributor: Ok("0123456789abcdef0123456789abcdef") }) == Bot
		and Compat.request_kind({ authorization: Err(NotFound), contributor: Ok("0123456789abcdef0123456789abcdef") }) == Hint
		and Compat.request_kind({ authorization: Err(NotFound), contributor: Err(NotFound) })
			== Refuse(Problem.new(BadRequest, "POST /v1/compat needs an Authorization header (the compat bot) or a Talon-Contributor header (a user hint)"))
}

# R-RE13 row 1, Q86, R-CT4, R-MX8: the row statement ends with `ON CONFLICT DO NOTHING` and has no `OR IGNORE` (it also drops a row that fails a `CHECK`, with no error). The sweep
# statement is an upsert that changes the row only to a larger bound (`ON CONFLICT (nightly, target) DO UPDATE ... WHERE`), never `OR REPLACE` (a delete and an insert: no UPDATE
# trigger stops a smaller bound), and never `OR IGNORE`. The row statement reads `json_each`, one parameter (R-AP41 row 2).
expect {
	rows = Compat.rows_sql()
	sweep = Compat.sweep_sql()
	rows.contains("INSERT INTO compat")
		and rows.contains("json_each(?1)")
		and rows.contains("ON CONFLICT")
		and rows.contains("DO NOTHING")
		and !rows.with_ascii_uppercased().contains("OR IGNORE")
		and !rows.with_ascii_uppercased().contains("OR REPLACE")
		and sweep.contains("INSERT INTO sweeps")
		and sweep.contains("ON CONFLICT (nightly, target) DO UPDATE")
		and sweep.contains("upto_log_index > sweeps.upto_log_index")
		and !sweep.with_ascii_uppercased().contains("OR REPLACE")
		and !sweep.with_ascii_uppercased().contains("OR IGNORE")
}

# R-AP48 rows 1, 2 and 5: `POST /v1/compat` takes a JSON body. Another method is 405 with `Allow: POST`; a body that is not JSON is 415; a request with no body goes to the handler
# (a route that needs a body answers 400, row 6).
expect {
	input = |method, content_type, has_body| { method, segments: ["v1", "compat"], content_type, has_body }
	Route.decide(input("POST", Ok("application/json"), Bool.True)) == Handle(PostCompat)
		and Route.decide(input("POST", Ok("application/json; charset=utf-8"), Bool.True)) == Handle(PostCompat)
		and Route.decide(input("POST", Err(NotFound), Bool.False)) == Handle(PostCompat)
		and Route.decide(input("GET", Err(NotFound), Bool.False)) == NotAllowed(Problem.new(MethodNotAllowed, "GET is not allowed on /v1/compat"), ["POST"])
		and Route.decide(input("PUT", Ok("application/json"), Bool.True)) == NotAllowed(Problem.new(MethodNotAllowed, "PUT is not allowed on /v1/compat"), ["POST"])
		and Route.decide(input("POST", Ok("text/plain"), Bool.True))
			== Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got text/plain"))
		and Route.decide(input("POST", Err(NotFound), Bool.True))
			== Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type"))
		and Route.decide({ method: "POST", segments: ["v1", "compat", "x"], content_type: Ok("application/json"), has_body: Bool.True })
			== Refuse(Problem.new(NotFound, "no route for POST /v1/compat/x"))
}
