import lib.CompatReads
import lib.Problem
import lib.Route

CompatReadsTest :: [].{}

# W0 tests of worker/lib/CompatReads.roc (slice 115b). The base58 texts are made by research/slice-115-revert/gen/ids.py with python.
# The questions Q115b-1 to Q115b-7 are settled (Design Q147 to Q152, Registry R-AP67).

h1 : List(U8)
h1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]

b1 : Str
b1 = "1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE"

h2 : List(U8)
h2 = [255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233, 232, 231, 230, 229, 228, 227, 226, 225, 224]

b2 : Str
b2 = "JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3"

t1 : Str
t1 = "nightly-2026-10-21-5349569"

t2 : Str
t2 = "nightly-2026-10-31-f7bef6b"

bad_audit : Str -> Try(U64, Problem)
bad_audit = |text| Err(Problem.new(BadRequest, "the query parameter audit must be a count (decimal digits), got ${text}"))

# ---- tests ----

# R-AP39, R-AP67, R-AP48 row 6, R-MX4 (Design Q147): the query parameter `target` is `any` or absent. Any other text, also an empty one, is 400, before any D1 call.
expect {
	bad = |text| Err(Problem.new(BadRequest, "the query parameter target must be any, got ${text}"))
	CompatReads.parse_sweep_target(Err(NotFound)) == Ok({})
		and CompatReads.parse_sweep_target(Ok("any")) == Ok({})
		and CompatReads.parse_sweep_target(Ok("x64glibc")) == bad("x64glibc")
		and CompatReads.parse_sweep_target(Ok("")) == bad("")
		and CompatReads.parse_sweep_target(Ok("ANY")) == bad("ANY")
		and CompatReads.parse_sweep_target(Ok("Any")) == bad("Any")
		and CompatReads.parse_sweep_target(Ok("0")) == bad("0")
		and CompatReads.parse_sweep_target(Ok("any ")) == bad("any ")
		and CompatReads.parse_sweep_target(Ok("wasm32")) == bad("wasm32")
}

# R-AP40, R-AP67, R-AP56, R-AP46: `audit` is required, decimal digits with no leading zero (only `0` itself), as `after` of R-AP56. 0 is 0. "At most 1000": a larger number gives 1000,
# also a number that does not fit in 63 or 64 bits. Anything else is 400. R-AP67 (Design Q148, Q149).
expect {
	CompatReads.audit_limit == 1000
		and CompatReads.parse_audit(Ok("0")) == Ok(0)
		and CompatReads.parse_audit(Ok("1")) == Ok(1)
		and CompatReads.parse_audit(Ok("200")) == Ok(200)
		and CompatReads.parse_audit(Ok("1000")) == Ok(1000)
		and CompatReads.parse_audit(Ok("1001")) == Ok(1000)
		and CompatReads.parse_audit(Ok("9223372036854775808")) == Ok(1000)
		and CompatReads.parse_audit(Ok("18446744073709551616")) == Ok(1000)
		and CompatReads.parse_audit(Ok("99999999999999999999999999")) == Ok(1000)
		and CompatReads.parse_audit(Err(NotFound)) == Err(Problem.new(BadRequest, "GET /v1/compat_hints needs the query parameter audit"))
		and ["", "-1", "+5", "1.5", "007", "00", "abc", " 5", "5 ", "1e3", "0x10", "٣"].all(|t| CompatReads.parse_audit(Ok(t)) == bad_audit(t))
}

# R-AP39, R-AP67: the 404 of a tag with no `toolchains` row (and of a text with no nightly id). R-AP21 `not-found`.
expect {
	CompatReads.no_tag(t1) == Problem.new(NotFound, "no toolchain for the tag ${t1}")
		and CompatReads.no_tag(t1).http_status() == 404
		and CompatReads.cache_control == "max-age=300"
		and CompatReads.sweep_cache_control == "no-store"
}

# R-AP39, R-AP67 (`members` counts distinct hashes, R-MX11 row 5), R-AP24, R-AP50: the body of `GET /v1/sweeps/{tag}`. Members in alphabetical order, times in ms. A row: `sweep` is the object. No row: `"sweep":null`. `missing` has every hash
# it is given (no cap: 120 hashes stay), in order. A tag with a quote is escaped.
expect {
	row = { upto_log_index: 24, time: 1767225600000 }
	many = List.repeat(b1, 120)
	CompatReads.sweep_body({ tag: t1, sweep: Ok(row), log_size: 24, members: 5, missing: [b1, b2] })
		== "{\"log_size\":24,\"members\":5,\"missing\":[\"${b1}\",\"${b2}\"],\"sweep\":{\"nightly\":\"${t1}\",\"target\":\"any\",\"time\":1767225600000,\"upto_log_index\":24}}"
		and CompatReads.sweep_body({ tag: t1, sweep: Err(None), log_size: 0, members: 0, missing: [] }) == "{\"log_size\":0,\"members\":0,\"missing\":[],\"sweep\":null}"
		and CompatReads.sweep_body({ tag: t1, sweep: Err(None), log_size: 9, members: 2, missing: [b2, b1] })
			== "{\"log_size\":9,\"members\":2,\"missing\":[\"${b2}\",\"${b1}\"],\"sweep\":null}"
		and CompatReads.sweep_body({ tag: t1, sweep: Err(None), log_size: 3, members: 120, missing: many }).split_on("\"${b1}\"").len() == 121
		and CompatReads.sweep_body({ tag: "a\"b", sweep: Ok(row), log_size: 1, members: 1, missing: [] }).contains("\"nightly\":\"a\\\"b\"")
}

# R-AP40, R-AP24: the body of `GET /v1/compat_hints`. The items are in the order of the rows, members in alphabetical order, the hash in base58. A hash of other than 32 bytes is `BadRow`.
expect {
	row = { hash: h1, nightly: t1, target: "any", pass_count: 3, fail_count: 1, crash_count: 0 }
	CompatReads.pairs_body([row, { ..row, hash: h2, nightly: t2, target: "wasm32", pass_count: 0, fail_count: 0, crash_count: 7 }])
		== Ok(
			"{\"pairs\":[{\"crash_count\":0,\"fail_count\":1,\"hash\":\"${b1}\",\"nightly\":\"${t1}\",\"pass_count\":3,\"target\":\"any\"},{\"crash_count\":7,\"fail_count\":0,\"hash\":\"${b2}\",\"nightly\":\"${t2}\",\"pass_count\":0,\"target\":\"wasm32\"}]}",
		)
		and CompatReads.pairs_body([]) == Ok("{\"pairs\":[]}")
		and CompatReads.pairs_body([{ ..row, hash: [1, 2, 3] }]) == Err(BadRow("a hash has 3 bytes, not 32"))
}

# R-AP4, R-AP17, R-AP58, R-RE3, R-IK7, R-AP67: the body of `GET /v1/artifacts/{hash}/compat`. Runs and hints have the bytes of the closure answer: the codes 0 and 1 are `bot` and `author`,
# 0 to 3 are `pass`, `fail`, `hang` and `crash`; a NULL digest is `null`, an empty digest is `""`; hints keep their order. An unknown code is `BadRow`.
expect {
	run = { hash: h1, target: "any", source: 0, result: 0, error_digest: Err(Missing), from: t1, to: t2 }
	hint = { hash: h1, nightly: t2, target: "any", pass_count: 3, fail_count: 1, crash_count: 0 }
	CompatReads.compat_body({ runs: [run, { ..run, source: 1, result: 1, error_digest: Ok("d1"), from: t2 }, { ..run, result: 2, error_digest: Ok("") }, { ..run, result: 3, target: "wasm32" }], hints: [hint] })
		== Ok(
			"{\"hints\":[{\"crash_count\":0,\"fail_count\":1,\"hash\":\"${b1}\",\"nightly\":\"${t2}\",\"pass_count\":3,\"target\":\"any\"}],\"runs\":[{\"error_digest\":null,\"from\":\"${t1}\",\"hash\":\"${b1}\",\"result\":\"pass\",\"source\":\"bot\",\"target\":\"any\",\"to\":\"${t2}\"},{\"error_digest\":\"d1\",\"from\":\"${t2}\",\"hash\":\"${b1}\",\"result\":\"fail\",\"source\":\"author\",\"target\":\"any\",\"to\":\"${t2}\"},{\"error_digest\":\"\",\"from\":\"${t1}\",\"hash\":\"${b1}\",\"result\":\"hang\",\"source\":\"bot\",\"target\":\"any\",\"to\":\"${t2}\"},{\"error_digest\":null,\"from\":\"${t1}\",\"hash\":\"${b1}\",\"result\":\"crash\",\"source\":\"bot\",\"target\":\"wasm32\",\"to\":\"${t2}\"}]}",
		)
		and CompatReads.compat_body({ runs: [], hints: [] }) == Ok("{\"hints\":[],\"runs\":[]}")
		and CompatReads.compat_body({ runs: [{ ..run, result: 4 }], hints: [] }) == Err(BadRow("the result code 4 is not known"))
		and CompatReads.compat_body({ runs: [{ ..run, source: 2 }], hints: [] }) == Err(BadRow("the source code 2 is not known"))
		and CompatReads.compat_body({ runs: [], hints: [{ ..hint, hash: [1] }] }) == Err(BadRow("a hash has 1 bytes, not 32"))
}

# R-AP48 rows 1 and 2, R-AP4, R-AP39, R-AP40: the three routes serve `GET` only (405 with `Allow: GET`). Other paths of the same words are 404.
expect {
	input = |method, segments| { method, segments, content_type: Err(NotFound), has_body: Bool.False }
	not_allowed = |method, path| NotAllowed(Problem.new(MethodNotAllowed, "${method} is not allowed on ${path}"), ["GET"])
	Route.decide(input("GET", ["v1", "sweeps", t1])) == Handle(GetSweep(t1))
		and Route.decide(input("GET", ["v1", "compat_hints"])) == Handle(GetCompatHints)
		and Route.decide(input("GET", ["v1", "artifacts", b1, "compat"])) == Handle(GetArtifactCompat(b1))
		and Route.decide(input("GET", ["v1", "artifacts", b1])) == Handle(GetArtifact(b1))
		and Route.decide(input("POST", ["v1", "sweeps", t1])) == not_allowed("POST", "/v1/sweeps/${t1}")
		and Route.decide(input("PUT", ["v1", "compat_hints"])) == not_allowed("PUT", "/v1/compat_hints")
		and Route.decide(input("DELETE", ["v1", "artifacts", b1, "compat"])) == not_allowed("DELETE", "/v1/artifacts/${b1}/compat")
		and Route.decide(input("GET", ["v1", "sweeps"])) == Refuse(Problem.new(NotFound, "no route for GET /v1/sweeps"))
		and Route.decide(input("GET", ["v1", "sweeps", t1, "x"])) == Refuse(Problem.new(NotFound, "no route for GET /v1/sweeps/${t1}/x"))
		and Route.decide(input("GET", ["v1", "artifacts", b1, "compat", "x"])) == Refuse(Problem.new(NotFound, "no route for GET /v1/artifacts/${b1}/compat/x"))
		and Route.decide(input("GET", ["v1", "artifacts", b1, "other"])) == Refuse(Problem.new(NotFound, "no route for GET /v1/artifacts/${b1}/other"))
}
