import lib.Ingest
import lib.Problem
import lib.Publish
import records.Release
import semver.Semver

PublishTest :: [].{}

# W0 tests of worker/lib/Publish.roc (slice 114, docs/slices/114-publish.md section 4). The nightly ids (R-IK4) were computed with node (days since 1970-01-01 times 2^28 plus the hex of the
# sha), not with the Roc code. h1, h2 are the base58 of 32 bytes of 1 and 2; h31 is 31 bytes of 7.

h1 = "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi"

h2 = "8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR"

h31 = "7DUeBUtEcb7nujVZRJmeBju3X1mo6PpnWNtJ9EBhdY"

app_form = "github.com/acme/app/releases/download/{v}/"

url = "https://github.com/acme/app/releases/download/2.0.0/${h1}.tar.zst"

n1 = "nightly-2026-10-31-f7bef6b"

n2 = "nightly-2026-10-14-38a3029"

fact = |nightly, target, result, digest| "{\"nightly\":\"${nightly}\",\"target\":\"${target}\",\"result\":\"${result}\",\"error_digest\":${digest}}"

with_compat = |compat| "{\"url\":\"${url}\",\"compat\":${compat}}"

body = |text| Publish.parse_body(text.to_utf8())

bad = |why| Problem.new(BadRequest, "the publish request body is not valid: ${why}")

# The 400 of a decode fault: the text after the colon is the `BadJson` text of records.Compat (not fixed), so the test checks the status, the type and the start of the detail.
is_bad_body = |got| match got {
	Err(Bad(p)) => p.http_status() == 400 and p.to_json().contains("/errors/bad-request") and p.to_json().contains("the publish request body is not valid: ")
	_ => Bool.False
}

# ---- parse_body: the body, the facts, the limit, the values (R-AP26, R-AP51, R-AP71, R-MX5, R-AP46; the checks before the token) ----

# R-AP71: compat is optional (missing or null is no facts, an empty list is no facts); R-AP44: an unknown member is ignored. Facts are kept in the order of the body: nightly id (R-IK4), result
# code, error_digest null or text (R-AP58). hang is a valid result of a fact. The limit is 500 facts (500 pass).
expect {
	f1 = fact(n1, "any", "pass", "null")
	f2 = fact(n2, "any", "fail", "\"abc\"")
	f3 = fact(n1, "any", "hang", "null")
	f4 = fact(n2, "any", "crash", "\"\"")
	got = [
		body("{\"url\":\"${url}\"}"),
		body("{\"url\":\"${url}\",\"compat\":null}"),
		body(with_compat("[]")),
		body("{\"url\":\"${url}\",\"unknown\":[1,{\"a\":null}],\"compat\":[${f1}]}"),
		body(with_compat("[${f1},${f2},${f3},${f4}]")),
	]
	facts = [
		{ nightly: 5572174540651, result: Pass, error_digest: Err(None) },
		{ nightly: 5567410745385, result: Fail, error_digest: Ok("abc") },
		{ nightly: 5572174540651, result: Hang, error_digest: Err(None) },
		{ nightly: 5567410745385, result: Crash, error_digest: Ok("") },
	]
	many = body(with_compat("[${Str.join_with(List.repeat(f1, 500), ",")}]"))
	got
		== [
			Ok({ url, facts: [] }),
			Ok({ url, facts: [] }),
			Ok({ url, facts: [] }),
			Ok({ url, facts: [facts.get(0) ?? { nightly: 0, result: Pass, error_digest: Err(None) }] }),
			Ok({ url, facts }),
		]
		and many.map_ok(|p| p.facts.len()) == Ok(500)
}

# R-AP51, R-AP71, R-MX5: the body faults, each a 400 with a detail that starts with the same text: empty, not UTF-8, not JSON, an array, url missing, null or not text, compat of a wrong type
# (a number, a text, an object), a fact that is not an object, a fact with a member missing (each of the four), a wrong JSON type in a fact.
expect {
	f = fact(n1, "any", "pass", "null")
	got = [
		Publish.parse_body([]),
		Publish.parse_body([255, 254]),
		body("not json"),
		body("[]"),
		body("{}"),
		body("{\"url\":null}"),
		body("{\"url\":5}"),
		body(with_compat("5")),
		body(with_compat("\"x\"")),
		body(with_compat("{}")),
		body(with_compat("[5]")),
		body(with_compat("[{\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]")),
		body(with_compat("[{\"nightly\":\"${n1}\",\"result\":\"pass\",\"error_digest\":null}]")),
		body(with_compat("[{\"nightly\":\"${n1}\",\"target\":\"any\",\"error_digest\":null}]")),
		body(with_compat("[{\"nightly\":\"${n1}\",\"target\":\"any\",\"result\":\"pass\"}]")),
		body(with_compat("[{\"nightly\":5,\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null}]")),
		body(with_compat("[${f},{\"nightly\":null}]")),
	]
	got.all(is_bad_body)
}

# R-AP71, R-MX5, Design Q176: a fact with a member hash or source (any value, null too, an escaped key) is 400, and the detail names the members. A text that only holds the word is no member.
expect {
	base = "\"nightly\":\"${n1}\",\"target\":\"any\",\"result\":\"pass\",\"error_digest\":null"
	named = bad("member hash or source is not allowed in a fact")
	got = [
		body(with_compat("[{${base},\"hash\":\"${h1}\"}]")),
		body(with_compat("[{${base},\"hash\":null}]")),
		body(with_compat("[{${base},\"source\":\"bot\"}]")),
		body(with_compat("[{${base},\"source\":null}]")),
		body(with_compat("[{${base},\"so\\u0075rce\":\"x\"}]")),
		body(with_compat("[{${base}},{${base},\"hash\":\"x\"}]")),
	]
	digest = body(with_compat("[{\"nightly\":\"${n1}\",\"target\":\"any\",\"result\":\"fail\",\"error_digest\":\"source hash\"}]"))
	got == List.repeat(Err(Bad(named)), 6) and digest.is_ok()
}

# R-AP46, R-AP71 (as Design Q143 for the compat bot): the limit comes before the values. 501 facts is 413 with field compat and limit 500, also when a fact is bad. Then the values, fact by fact in the
# order of the body, and in a fact nightly, then target, then result (Q291, R-AP71 order of the values; R-AP75 row 5). target is any only (Registry R-AP71); hang is a result.
expect {
	f = fact(n1, "any", "pass", "null")
	too_many = Err(TooLarge(Problem.new(TooLarge, "the compat member of the publish request has more than 500 facts"), { field: "compat", limit: 500 }))
	bad_nightly = Err(Bad(Problem.new(BadRequest, "the nightly nightly-2026 of a fact is not a nightly tag")))
	bad_target = Err(Bad(Problem.new(BadRequest, "the target linux_x64 of a fact is not any")))
	bad_result = Err(Bad(Problem.new(BadRequest, "the result bogus of a fact is not pass, fail, hang or crash")))
	got = [
		body(with_compat("[${Str.join_with(List.repeat(f, 501), ",")}]")),
		body(with_compat("[${Str.join_with(List.repeat(fact(n1, "any", "bogus", "null"), 501), ",")}]")),
		body(with_compat("[${fact("nightly-2026", "any", "pass", "null")}]")),
		body(with_compat("[${fact("nightly-2026-02-30-f7bef6b", "any", "pass", "null")}]")),
		body(with_compat("[${fact(n1, "linux_x64", "pass", "null")}]")),
		body(with_compat("[${fact(n1, "Any", "pass", "null")}]")),
		body(with_compat("[${fact(n1, "any", "bogus", "null")}]")),
		body(with_compat("[${fact(n1, "any", "Pass", "null")}]")),
		body(with_compat("[${f},${fact(n1, "any", "bogus", "null")},${fact("x", "any", "pass", "null")}]")),
		body(with_compat("[${fact("nightly-2026", "linux_x64", "bogus", "null")}]")),
		body(with_compat("[${fact(n1, "linux_x64", "bogus", "null")}]")),
	]
	got
		== [
			too_many,
			too_many,
			bad_nightly,
			Err(Bad(Problem.new(BadRequest, "the nightly nightly-2026-02-30-f7bef6b of a fact is not a nightly tag"))),
			bad_target,
			Err(Bad(Problem.new(BadRequest, "the target Any of a fact is not any"))),
			bad_result,
			Err(Bad(Problem.new(BadRequest, "the result Pass of a fact is not pass, fail, hang or crash"))),
			bad_result,
			bad_nightly,
			bad_target,
		]
}

# ---- claims_ids, claims_json (R-TP3 row 5, R-TP9, R-TP6, R-TP13, R-RE9) ----

no_claims = {
	iss: Err(Missing),
	aud: Err(Missing),
	exp: Err(Missing),
	nbf: Err(Missing),
	repository: Err(Missing),
	repository_id: Err(Missing),
	repository_owner_id: Err(Missing),
	repository_visibility: Err(Missing),
	ref: Err(Missing),
	ref_type: Err(Missing),
	event_name: Err(Missing),
	workflow_ref: Err(Missing),
	workflow_sha: Err(Missing),
	job_workflow_ref: Err(Missing),
	run_id: Err(Missing),
	run_attempt: Err(Missing),
	actor_id: Err(Missing),
	runner_environment: Err(Missing),
}

ids = |rid, oid| { ..no_claims, repository_id: rid, repository_owner_id: oid }

# R-TP3 row 5: the ids that the token claims, repository_id first. A claim that is missing, or not decimal digits, is 403 forbidden (Q293, R-AP75 row 8), and the first fault (repository_id) is the answer.
expect {
	forbidden = |d| Err(Problem.new(Forbidden, d))
	got = [
		Publish.claims_ids(ids(Ok("812345"), Ok("612345"))),
		Publish.claims_ids(ids(Ok("18446744073709551615"), Ok("0"))),
		Publish.claims_ids(ids(Err(Missing), Ok("612345"))),
		Publish.claims_ids(ids(Ok("812345"), Err(Missing))),
		Publish.claims_ids(ids(Err(Missing), Err(Missing))),
		Publish.claims_ids(ids(Ok("12a"), Ok("x"))),
		Publish.claims_ids(ids(Ok("812345"), Ok(""))),
		Publish.claims_ids(ids(Ok("-1"), Ok("1"))),
		Publish.claims_ids(ids(Ok("18446744073709551616"), Ok("1"))),
	]
	got
		== [
			Ok({ repository_id: 812345, owner_id: 612345 }),
			Ok({ repository_id: 18446744073709551615, owner_id: 0 }),
			forbidden("token claim repository_id is missing"),
			forbidden("token claim repository_owner_id is missing"),
			forbidden("token claim repository_id is missing"),
			forbidden("token claim repository_id is \"12a\", expected a number"),
			forbidden("token claim repository_owner_id is \"\", expected a number"),
			forbidden("token claim repository_id is \"-1\", expected a number"),
			forbidden("token claim repository_id is \"18446744073709551616\", expected a number"),
		]
}

# R-TP6: the 8 recorded claims in this order, each a JSON text (the escapes of Json.to_str); a missing claim is null; the other claims are not recorded. R-TP13: the same text is the claims of a repo_events row.
expect {
	full = {
		..no_claims,
		repository: Ok("acme/roc-json"),
		workflow_ref: Ok("acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0"),
		workflow_sha: Ok("89abcdef0123456789abcdef0123456789abcdef"),
		job_workflow_ref: Ok("acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0"),
		event_name: Ok("push"),
		run_id: Ok("77"),
		run_attempt: Ok("1"),
		actor_id: Ok("512345"),
		runner_environment: Ok("github-hosted"),
	}
	got = [Publish.claims_json(full), Publish.claims_json({ ..full, event_name: Err(Missing), run_id: Ok("a\"b\\c") }), Publish.claims_json(no_claims)]
	got
		== [
			"{\"workflow_ref\":\"acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0\",\"workflow_sha\":\"89abcdef0123456789abcdef0123456789abcdef\",\"job_workflow_ref\":\"acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0\",\"event_name\":\"push\",\"run_id\":\"77\",\"run_attempt\":\"1\",\"actor_id\":\"512345\",\"runner_environment\":\"github-hosted\"}",
			"{\"workflow_ref\":\"acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0\",\"workflow_sha\":\"89abcdef0123456789abcdef0123456789abcdef\",\"job_workflow_ref\":\"acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0\",\"event_name\":null,\"run_id\":\"a\\\"b\\\\c\",\"run_attempt\":\"1\",\"actor_id\":\"512345\",\"runner_environment\":\"github-hosted\"}",
			"{\"workflow_ref\":null,\"workflow_sha\":null,\"job_workflow_ref\":null,\"event_name\":null,\"run_id\":null,\"run_attempt\":null,\"actor_id\":null,\"runner_environment\":null}",
		]
}

# ---- after_read, candidate (R-PU14, R-PU16, R-PU19, R-PU6) ----

target = |hash| {
	url: "https://github.com/acme/app/releases/download/2.0.0/${hash}.tar.zst",
	owner: "acme",
	repo: "app",
	name: "acme/app",
	tag: "2.0.0",
	hash,
	form: app_form,
	version: Semver.new(2, 0, 0),
	column: { version: "-9222809086901288961", version_text: "" },
}

row = |bytes, has_oidc| {
	release: {
		log_index: 7,
		hash: bytes,
		form: app_form,
		version: "-9222809086901288961",
		version_text: "",
		url: "https://github.com/acme/app/releases/download/2.0.0/${h1}.tar.zst",
		tag: Ok("2.0.0"),
		roc_version: Err(Missing),
		repo: Ok("acme/app"),
		published_at: 1792497600000,
		yanked: Bool.False,
		withdrawn: Err(Missing),
		vias: if (has_oidc) Ok("3,0") else Ok("3"),
	},
	has_ingest: has_oidc,
}

record7 : Release.Row
record7 = {
	log_index: 7,
	hash: h1,
	group: app_form,
	series: "2",
	version: "2.0.0",
	url: "https://github.com/acme/app/releases/download/2.0.0/${h1}.tar.zst",
	tag: Ok("2.0.0"),
	roc_version: Err(None),
	repo: Ok("acme/app"),
	published_at: 1792497600000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["oidc", "ingest"],
}

nothing = { facts: Bool.False, events: Bool.False }

# R-PU14, R-PU16, R-PU19, R-AP41: no row is the whole flow. Another hash is 409 with that hash, also with facts and events. The same hash with an oidc row and nothing to write is the answer (200, no
# write). The same hash with no oidc row, or with a fact, or with an identity event, is a write with no release (R-PU16: the oidc row and the author facts of a label that an ingest or the webhook indexed).
expect {
	t = target(h1)
	got = [
		Publish.after_read(t, [], nothing),
		Publish.after_read(t, [], { facts: Bool.True, events: Bool.True }),
		Publish.after_read(t, [row(List.repeat(2, 32), Bool.True)], { facts: Bool.True, events: Bool.True }),
		Publish.after_read(t, [row(List.repeat(2, 32), Bool.False)], nothing),
		Publish.after_read(t, [row(List.repeat(1, 32), Bool.True)], nothing),
		Publish.after_read(t, [row(List.repeat(1, 32), Bool.False)], nothing),
		Publish.after_read(t, [row(List.repeat(1, 32), Bool.True)], { facts: Bool.True, events: Bool.False }),
		Publish.after_read(t, [row(List.repeat(1, 32), Bool.True)], { facts: Bool.False, events: Bool.True }),
	]
	got
		== [
			Ok(Index),
			Ok(Index),
			Ok(Conflict(Ingest.label_conflict(t, Ok(h2)))),
			Ok(Conflict(Ingest.label_conflict(t, Ok(h2)))),
			Ok(Answer(record7)),
			Ok(Write(7)),
			Ok(Write(7)),
			Ok(Write(7)),
		]
}

# A hash in the row that is not 32 bytes is a fault (500), not an answer.
expect {
	match Publish.after_read(target(h1), [row(List.repeat(1, 31), Bool.True)], nothing) {
		Err(BadRow(_)) => Bool.True
		_ => Bool.False
	}
}

ghr = |draft, prerelease, published_at, assets| { draft, prerelease, published_at, assets }

# R-PU16: a draft is 422 with the publish text (a draft first when it is also a prerelease). The other releases give what Ingest.candidate gives: the good release is published_at in ms.
# R-PU6: a prerelease, 0 or 2 package assets, another asset, a missing published_at.
expect {
	t = target(h1)
	pk = "${h1}.tar.zst"
	draft = Err(Problem.new(NotACandidate, "the release 2.0.0 is a draft: publish the GitHub release before tln publish"))
	releases = [
		ghr(Bool.False, Bool.True, Ok(5000), [pk]),
		ghr(Bool.False, Bool.False, Ok(5000), ["docs.tar.gz", "${h1}.tar.zst.intoto.jsonl"]),
		ghr(Bool.False, Bool.False, Ok(5000), [pk, "${h2}.tar.zst"]),
		ghr(Bool.False, Bool.False, Ok(5000), ["${h2}.tar.zst"]),
		ghr(Bool.False, Bool.False, Err(None), [pk]),
		ghr(Bool.False, Bool.False, Ok(5000), [pk]),
	]
	got = [
		Publish.candidate(t, ghr(Bool.True, Bool.False, Err(None), [pk])),
		Publish.candidate(t, ghr(Bool.True, Bool.True, Ok(5000), [pk])),
		Publish.candidate(t, ghr(Bool.True, Bool.False, Ok(5000), [])),
	]
	got == [draft, draft, draft] and releases.all(|r| Publish.candidate(t, r) == Ingest.candidate(t, r)) and Publish.candidate(t, ghr(Bool.False, Bool.False, Ok(5000), [pk])) == Ok(5000)
}

# R-PU16: the two texts name the draft and say what to do (the 404 of a release that the Worker cannot see is also a draft).
expect {
	Publish.draft("2.0.0") == Problem.new(NotACandidate, "the release 2.0.0 is a draft: publish the GitHub release before tln publish")
		and Publish.no_release("v1")
			== Problem.new(NotACandidate, "the repository has no published release with the tag v1: a draft is not published, so publish the GitHub release before tln publish")
}

# ---- fact_rows (R-PU5, R-RE3, R-RE13): the rows for Compat.rows_json ----

# One row for each fact, in the order of the facts: the artifact id, the nightly id, target 0 (any), the result code (pass 0, fail 1, hang 2, crash 3), the error digest.
expect {
	facts = [
		{ nightly: 5572174540651, result: Pass, error_digest: Err(None) },
		{ nightly: 5567410745385, result: Fail, error_digest: Ok("abc") },
		{ nightly: 5572174540651, result: Hang, error_digest: Err(None) },
		{ nightly: 5572174540651, result: Crash, error_digest: Ok("") },
	]
	Publish.fact_rows(facts, -77)
		== [
			{ artifact: -77, nightly: 5572174540651, target: 0, result: 0, error_digest: Err(None) },
			{ artifact: -77, nightly: 5567410745385, target: 0, result: 1, error_digest: Ok("abc") },
			{ artifact: -77, nightly: 5572174540651, target: 0, result: 2, error_digest: Err(None) },
			{ artifact: -77, nightly: 5572174540651, target: 0, result: 3, error_digest: Ok("") },
		]
		and Publish.fact_rows([], 5) == []
}
