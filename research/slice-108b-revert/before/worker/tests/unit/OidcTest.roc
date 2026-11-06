import lib.Oidc
import lib.Problem

OidcTest :: [].{}

# W0 tests of worker/lib/Oidc.roc (slice 108). The base64url texts are from research/slice-108-revert/vectors/jwt_vectors.py (python, apart from any Roc code).

unauth = |detail| Problem.new(Unauthenticated, detail)

forbid = |detail| Problem.new(Forbidden, detail)

# A token of the compat bot (R-MX15) at the default time of a W2 case (1767225600 s): nbf 300 s before, exp 300 s after.
bot : Oidc.Claims
bot = {
	iss: Ok("https://token.actions.githubusercontent.com"),
	aud: Ok("https://registry.example"),
	exp: Ok(1767225900),
	nbf: Ok(1767225300),
	repository: Ok("roc-talon/talon"),
	repository_id: Ok("900001"),
	repository_owner_id: Ok("700001"),
	repository_visibility: Ok("public"),
	ref: Ok("refs/heads/main"),
	ref_type: Ok("branch"),
	event_name: Ok("schedule"),
	workflow_ref: Ok("roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main"),
	workflow_sha: Ok("abc"),
	job_workflow_ref: Ok("roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main"),
	run_id: Ok("42"),
	run_attempt: Ok("1"),
	actor_id: Ok("500001"),
	runner_environment: Ok("github-hosted"),
}

# A publish token: a tag push of acme/roc-json, tag 1.2.0.
pub : Oidc.Claims
pub = {
	..bot,
	repository: Ok("acme/roc-json"),
	repository_id: Ok("812345"),
	repository_owner_id: Ok("612345"),
	ref: Ok("refs/tags/1.2.0"),
	ref_type: Ok("tag"),
	event_name: Ok("push"),
	workflow_ref: Ok("acme/roc-json/.github/workflows/release.yml@refs/tags/1.2.0"),
}

missing : Oidc.Claims
missing = {
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

ctx = |now_ms| { audience: "https://registry.example", now_ms }

now = 1767225600000

bot_ids = { repository_id: "900001", workflow_ref: "roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main" }

asset = { host: "github.com", owner_repo: "acme/roc-json", tag: "1.2.0" }

# The parts of test tokens (jwt_vectors.py). `hdr`: {"alg":"RS256","kid":"kid-1","typ":"JWT","x5t":"zz"}. `full`: the claims of `bot` and 13 more
# that the Worker does not read (jti, sub, sha, actor, iat, ...). `min`: only iss and exp. `badtype`: `full` with the number 900001 as repository_id.
hdr = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImtpZC0xIiwidHlwIjoiSldUIiwieDV0IjoienoifQ"

full = "eyJqdGkiOiJqLTEiLCJzdWIiOiJyZXBvOnJvYy10YWxvbi90YWxvbjpyZWY6cmVmcy9oZWFkcy9tYWluIiwiYXVkIjoiaHR0cHM6Ly9yZWdpc3RyeS5leGFtcGxlIiwicmVmIjoicmVmcy9oZWFkcy9tYWluIiwic2hhIjoiYWJjIiwicmVwb3NpdG9yeSI6InJvYy10YWxvbi90YWxvbiIsInJlcG9zaXRvcnlfb3duZXIiOiJyb2MtdGFsb24iLCJyZXBvc2l0b3J5X293bmVyX2lkIjoiNzAwMDAxIiwicnVuX2lkIjoiNDIiLCJydW5fbnVtYmVyIjoiNyIsInJ1bl9hdHRlbXB0IjoiMSIsInJlcG9zaXRvcnlfdmlzaWJpbGl0eSI6InB1YmxpYyIsInJlcG9zaXRvcnlfaWQiOiI5MDAwMDEiLCJhY3Rvcl9pZCI6IjUwMDAwMSIsImFjdG9yIjoiYm90Iiwid29ya2Zsb3ciOiJjb21wYXQtYm90IiwiaGVhZF9yZWYiOiIiLCJiYXNlX3JlZiI6IiIsImV2ZW50X25hbWUiOiJzY2hlZHVsZSIsInJlZl90eXBlIjoiYnJhbmNoIiwid29ya2Zsb3dfcmVmIjoicm9jLXRhbG9uL3RhbG9uLy5naXRodWIvd29ya2Zsb3dzL2NvbXBhdC1ib3QueW1sQHJlZnMvaGVhZHMvbWFpbiIsIndvcmtmbG93X3NoYSI6ImFiYyIsImpvYl93b3JrZmxvd19yZWYiOiJyb2MtdGFsb24vdGFsb24vLmdpdGh1Yi93b3JrZmxvd3MvY29tcGF0LWJvdC55bWxAcmVmcy9oZWFkcy9tYWluIiwiam9iX3dvcmtmbG93X3NoYSI6ImFiYyIsInJ1bm5lcl9lbnZpcm9ubWVudCI6ImdpdGh1Yi1ob3N0ZWQiLCJpc3MiOiJodHRwczovL3Rva2VuLmFjdGlvbnMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwibmJmIjoxNzY3MjI1MzAwLCJleHAiOjE3NjcyMjU5MDAsImlhdCI6MTc2NzIyNTYwMH0"

min = "eyJpc3MiOiJodHRwczovL3Rva2VuLmFjdGlvbnMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwiZXhwIjoxNzY3MjI1OTAwfQ"

badtype = "eyJqdGkiOiJqLTEiLCJzdWIiOiJyZXBvOnJvYy10YWxvbi90YWxvbjpyZWY6cmVmcy9oZWFkcy9tYWluIiwiYXVkIjoiaHR0cHM6Ly9yZWdpc3RyeS5leGFtcGxlIiwicmVmIjoicmVmcy9oZWFkcy9tYWluIiwic2hhIjoiYWJjIiwicmVwb3NpdG9yeSI6InJvYy10YWxvbi90YWxvbiIsInJlcG9zaXRvcnlfb3duZXIiOiJyb2MtdGFsb24iLCJyZXBvc2l0b3J5X293bmVyX2lkIjoiNzAwMDAxIiwicnVuX2lkIjoiNDIiLCJydW5fbnVtYmVyIjoiNyIsInJ1bl9hdHRlbXB0IjoiMSIsInJlcG9zaXRvcnlfdmlzaWJpbGl0eSI6InB1YmxpYyIsInJlcG9zaXRvcnlfaWQiOjkwMDAwMSwiYWN0b3JfaWQiOiI1MDAwMDEiLCJhY3RvciI6ImJvdCIsIndvcmtmbG93IjoiY29tcGF0LWJvdCIsImhlYWRfcmVmIjoiIiwiYmFzZV9yZWYiOiIiLCJldmVudF9uYW1lIjoic2NoZWR1bGUiLCJyZWZfdHlwZSI6ImJyYW5jaCIsIndvcmtmbG93X3JlZiI6InJvYy10YWxvbi90YWxvbi8uZ2l0aHViL3dvcmtmbG93cy9jb21wYXQtYm90LnltbEByZWZzL2hlYWRzL21haW4iLCJ3b3JrZmxvd19zaGEiOiJhYmMiLCJqb2Jfd29ya2Zsb3dfcmVmIjoicm9jLXRhbG9uL3RhbG9uLy5naXRodWIvd29ya2Zsb3dzL2NvbXBhdC1ib3QueW1sQHJlZnMvaGVhZHMvbWFpbiIsImpvYl93b3JrZmxvd19zaGEiOiJhYmMiLCJydW5uZXJfZW52aXJvbm1lbnQiOiJnaXRodWItaG9zdGVkIiwiaXNzIjoiaHR0cHM6Ly90b2tlbi5hY3Rpb25zLmdpdGh1YnVzZXJjb250ZW50LmNvbSIsIm5iZiI6MTc2NzIyNTMwMCwiZXhwIjoxNzY3MjI1OTAwLCJpYXQiOjE3NjcyMjU2MDB9"

sig = "AQID"

not_jwt = unauth("the token is not a valid JWT")

# R-AP26, RFC 9110 11.1 (Q108-5): the scheme has no case. The header selects the path. No header: NoToken (an ingest). A header that is not `Bearer <token>`: 401, never an ingest.
expect {
	bad_header = Refuse(unauth("the Authorization header must be \"Bearer <token>\""))
	(Oidc.bearer(Err(NotFound)) == NoToken)
		and (Oidc.bearer(Ok("Bearer abc.def.ghi")) == Token("abc.def.ghi"))
		and (Oidc.bearer(Ok("bearer abc.def.ghi")) == Token("abc.def.ghi"))
		and (Oidc.bearer(Ok("BEARER abc.def.ghi")) == Token("abc.def.ghi"))
		and (Oidc.bearer(Ok("bEaReR abc.def.ghi")) == Token("abc.def.ghi"))
		and ["", "Bearer", "Bearer ", "Basic dXNlcjpwYXNz", "abc.def.ghi", "Token abc"].all(|h| Oidc.bearer(Ok(h)) == bad_header)
}

# R-AP21: the 401 of a route that needs a token, when the request has none.
expect Oidc.missing_token == unauth("the request has no Authorization header: this route needs a GitHub OIDC token")

# R-TP3 row 1: base64url with no padding (RFC 7515 2). The vectors of RFC 4648 10 and the two letters `-` and `_`.
expect {
	good = [("", []), ("Zg", [102]), ("Zm8", [102, 111]), ("Zm9v", [102, 111, 111]), ("Zm9vYg", [102, 111, 111, 98]), ("Zm9vYmE", [102, 111, 111, 98, 97]), ("Zm9vYmFy", [102, 111, 111, 98, 97, 114]), ("-_-_", [251, 255, 191]), ("AP-AP0A", [0, 255, 128, 63, 64])]
	good.all(|(text, bytes)| Oidc.base64url(text) == Ok(bytes))
}
expect ["Zg==", "+/+/", "Z", "Zm9vY", "Zm 9", "Zm9v.", "é"].all(|text| Oidc.base64url(text) == Err(BadBase64))

# R-TP3 row 1, R-TP6: parse reads the kid, the claims that the Worker reads or records (the other claims are ignored), the signed bytes and the signature.
expect Oidc.parse("${hdr}.${full}.${sig}") == Ok({ kid: "kid-1", claims: bot, signed: "${hdr}.${full}".to_utf8(), signature: [1, 2, 3] })

# A claim that the token does not have is Err(Missing). The check of its row fails later, so parse does not fail.
expect Oidc.parse("${hdr}.${min}.${sig}") == Ok({ kid: "kid-1", claims: { ..missing, iss: Ok("https://token.actions.githubusercontent.com"), exp: Ok(1767225900) }, signed: "${hdr}.${min}".to_utf8(), signature: [1, 2, 3] })

# R-TP3 row 1, R-AP21: a token that is not a valid JWT is 401: not 3 parts, a part that is not base64url, a header or claims that are not a JSON object,
# a claim of the wrong type (`badtype`), an empty signature.
expect {
	array = "WzEsMl0" # [1,2]
	text = "aGVsbG8" # hello
	bad = ["", "abc", "${hdr}.${full}", "${hdr}.${full}.${sig}.${sig}", "${hdr}.${full}.", "${hdr}.${full}.A+B", "${hdr}=.${full}.${sig}", "${array}.${full}.${sig}", "${text}.${full}.${sig}", "${hdr}.${array}.${sig}", "${hdr}.${text}.${sig}", "${hdr}.${badtype}.${sig}"]
	bad.all(|t| Oidc.parse(t) == Err(not_jwt))
}

# R-TP3 row 1: RS256 only. `alg` none and HS256 are refused before any key is read. A header with no kid is refused.
expect {
	hs256 = "eyJhbGciOiJIUzI1NiIsImtpZCI6ImtpZC0xIn0" # {"alg":"HS256","kid":"kid-1"}
	none = "eyJhbGciOiJub25lIiwia2lkIjoia2lkLTEifQ" # {"alg":"none","kid":"kid-1"}
	no_alg = "eyJraWQiOiJraWQtMSJ9" # {"kid":"kid-1"}
	no_kid = "eyJhbGciOiJSUzI1NiJ9" # {"alg":"RS256"}
	(Oidc.parse("${hs256}.${full}.${sig}") == Err(unauth("the token alg is \"HS256\", expected \"RS256\"")))
		and (Oidc.parse("${none}.${full}.${sig}") == Err(unauth("the token alg is \"none\", expected \"RS256\"")))
		and (Oidc.parse("${no_alg}.${full}.${sig}") == Err(unauth("the token alg is missing")))
		and (Oidc.parse("${no_kid}.${full}.${sig}") == Err(unauth("the token kid is missing")))
}

# R-TP3 row 1, API.md RN6: the RSA keys of the JWKS, by kid. Keys of another kty, or with no kid, n or e, are left out. Other members are ignored.
expect {
	jwks = "{\"keys\":[{\"kty\":\"RSA\",\"alg\":\"RS256\",\"use\":\"sig\",\"kid\":\"kid-1\",\"n\":\"n1\",\"e\":\"AQAB\",\"x5c\":[\"MII\"]},{\"kty\":\"EC\",\"kid\":\"kid-ec\",\"crv\":\"P-256\",\"x\":\"x\",\"y\":\"y\"},{\"kty\":\"RSA\",\"n\":\"n0\",\"e\":\"AQAB\"},{\"kty\":\"RSA\",\"kid\":\"kid-2\",\"n\":\"n2\",\"e\":\"AQAB\"}],\"other\":1}"
	keys = [{ kid: "kid-1", n: "n1", e: "AQAB" }, { kid: "kid-2", n: "n2", e: "AQAB" }]
	(Oidc.parse_jwks(jwks) == Ok(keys))
		and (Oidc.parse_jwks("{\"keys\":[]}") == Ok([]))
		and (["", "not json", "[]", "{}", "{\"keys\":1}"].all(|t| Oidc.parse_jwks(t) == Err(BadJwks)))
		and (Oidc.find_key(keys, "kid-2") == Ok({ kid: "kid-2", n: "n2", e: "AQAB" }))
		and (Oidc.find_key(keys, "kid-3") == Err(UnknownKid))
		and (Oidc.find_key([], "kid-1") == Err(UnknownKid))
}

# R-TP3 row 1, R-TP16 (Q108-1, Q108-2): the key step. Age = now - fetch time (0 when now is before it). Older than 1 h: read again, also for a known kid.
# A known kid: use it. An unknown kid: read again only when older than 60 s, else 401 at once. A fresh copy (age 0) never reads again.
expect {
	k1 = { kid: "kid-1", n: "n1", e: "AQAB" }
	cached = { fetched_ms: 1767225600000, keys: [k1, { kid: "kid-2", n: "n2", e: "AQAB" }] }
	t = 1767225600000
	refuse = Refuse(unauth("the token kid \"kid-9\" is not in the GitHub JWKS"))
	(Oidc.key_step(cached, "kid-1", t) == Use(k1))
		and (Oidc.key_step(cached, "kid-1", t + 3_600_000) == Use(k1))
		and (Oidc.key_step(cached, "kid-1", t + 3_600_001) == Reload)
		and (Oidc.key_step(cached, "kid-1", t - 5_000) == Use(k1))
		and (Oidc.key_step(cached, "kid-9", t) == refuse)
		and (Oidc.key_step(cached, "kid-9", t + 60_000) == refuse)
		and (Oidc.key_step(cached, "kid-9", t + 60_001) == Reload)
		and (Oidc.key_step(cached, "kid-9", t - 120_000) == refuse)
		and (Oidc.key_step(cached, "kid-9", t + 3_600_001) == Reload)
		and (Oidc.key_step({ fetched_ms: 0, keys: [] }, "kid-1", 0) == Refuse(unauth("the token kid \"kid-1\" is not in the GitHub JWKS")))
		and (Oidc.key_step({ fetched_ms: 0, keys: [k1] }, "kid-1", 60_001) == Use(k1))
		and (Oidc.max_age_ms == 3_600_000)
		and (Oidc.reread_after_ms == 60_000)
}

# The JWK text for WebCrypto: kty RSA, n and e, and no other member (the order is free, so the test parses the text back).
expect {
	parsed : Try({ kty : Str, n : Str, e : Str, kid : Try(Str, [Missing]), alg : Try(Str, [Missing]) }, _)
	parsed = Json.parse(Oidc.jwk_text({ kid: "kid-1", n: "n1", e: "AQAB" }))
	parsed == Ok({ kty: "RSA", n: "n1", e: "AQAB", kid: Err(Missing), alg: Err(Missing) })
}

# R-AP21: the fixed problems of the key and signature step.
expect (Oidc.unknown_kid("kid-9") == unauth("the token kid \"kid-9\" is not in the GitHub JWKS")) and (Oidc.bad_signature == unauth("the token signature is not valid"))

# R-TP3 rows 1 to 3: a good token passes, at the issue time and inside the leeway.
expect [now, 1767225300000, 1767225900000, 1767225240000, 1767225959999].all(|t| Oidc.check_token(bot, ctx(t)) == Ok({}))

# R-TP3 row 1: iss. Row 2: aud is exactly AUDIENCE (no trailing /, no case fold). Each fault is 401 and names the claim.
expect {
	cases = [
		({ ..bot, iss: Ok("https://token.actions.githubusercontent.com/") }, "token claim iss is \"https://token.actions.githubusercontent.com/\", expected \"https://token.actions.githubusercontent.com\""),
		({ ..bot, iss: Ok("https://accounts.google.com") }, "token claim iss is \"https://accounts.google.com\", expected \"https://token.actions.githubusercontent.com\""),
		({ ..bot, iss: Err(Missing) }, "token claim iss is missing"),
		({ ..bot, aud: Ok("https://registry.example/") }, "token claim aud is \"https://registry.example/\", expected \"https://registry.example\""),
		({ ..bot, aud: Ok("https://Registry.example") }, "token claim aud is \"https://Registry.example\", expected \"https://registry.example\""),
		({ ..bot, aud: Ok("sigstore") }, "token claim aud is \"sigstore\", expected \"https://registry.example\""),
		({ ..bot, aud: Err(Missing) }, "token claim aud is missing"),
	]
	cases.all(|(claims, detail)| Oidc.check_token(claims, ctx(now)) == Err(unauth(detail)))
}

# R-TP3 row 1 before row 2 before row 3: the first failing row names the claim.
expect {
	(Oidc.check_token({ ..bot, iss: Err(Missing), aud: Err(Missing), exp: Ok(0) }, ctx(now)) == Err(unauth("token claim iss is missing")))
		and (Oidc.check_token({ ..bot, aud: Err(Missing), exp: Ok(0) }, ctx(now)) == Err(unauth("token claim aud is missing")))
		and (Oidc.check_token({ ..bot, exp: Ok(0), nbf: Ok(1867225300) }, ctx(now)) == Err(unauth("token claim exp is 0: the token expired (now is 1767225600, leeway 60 s)")))
}

# R-TP3 row 3: exp and nbf with 60 s of leeway (RFC 7519 4.1.4, 4.1.5). Refused when now_ms >= (exp + 60) * 1000, or now_ms < (nbf - 60) * 1000.
# exp is 1767225900, nbf is 1767225300. The detail gives `now` in whole seconds, rounded down.
expect {
	(Oidc.check_token(bot, ctx(1767225960000)) == Err(unauth("token claim exp is 1767225900: the token expired (now is 1767225960, leeway 60 s)")))
		and (Oidc.check_token(bot, ctx(1767299999999)) == Err(unauth("token claim exp is 1767225900: the token expired (now is 1767299999, leeway 60 s)")))
		and (Oidc.check_token(bot, ctx(1767225239999)) == Err(unauth("token claim nbf is 1767225300: the token is not valid yet (now is 1767225239, leeway 60 s)")))
		and (Oidc.check_token({ ..bot, exp: Err(Missing) }, ctx(now)) == Err(unauth("token claim exp is missing")))
		and (Oidc.check_token({ ..bot, nbf: Err(Missing) }, ctx(now)) == Err(unauth("token claim nbf is missing")))
		and (Oidc.check_token({ ..bot, nbf: Ok(1767225000), exp: Ok(1767225000) }, ctx(now)) == Err(unauth("token claim exp is 1767225000: the token expired (now is 1767225600, leeway 60 s)")))
		and (Oidc.check_token({ ..bot, nbf: Ok(0), exp: Ok(0) }, ctx(0)) == Ok({}))
}

# R-TP7: the bot token passes with event schedule and workflow_dispatch.
expect (Oidc.check_bot(bot, bot_ids) == Ok({})) and (Oidc.check_bot({ ..bot, event_name: Ok("workflow_dispatch") }, bot_ids) == Ok({}))

# R-TP7, R-MX5: any other valid token gets 403, and the detail names the claim. The order: repository_id, workflow_ref, event_name.
expect {
	cases = [
		({ ..bot, repository_id: Ok("900002") }, "token claim repository_id is \"900002\", expected \"900001\""),
		({ ..bot, repository_id: Err(Missing) }, "token claim repository_id is missing"),
		({ ..bot, workflow_ref: Ok("roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/feature") }, "token claim workflow_ref is \"roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/feature\", expected \"roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main\""),
		({ ..bot, workflow_ref: Ok("roc-talon/talon/.github/workflows/other.yml@refs/heads/main") }, "token claim workflow_ref is \"roc-talon/talon/.github/workflows/other.yml@refs/heads/main\", expected \"roc-talon/talon/.github/workflows/compat-bot.yml@refs/heads/main\""),
		({ ..bot, workflow_ref: Err(Missing) }, "token claim workflow_ref is missing"),
		({ ..bot, event_name: Ok("push") }, "token claim event_name is \"push\", expected \"schedule\" or \"workflow_dispatch\""),
		({ ..bot, event_name: Ok("pull_request_target") }, "token claim event_name is \"pull_request_target\", expected \"schedule\" or \"workflow_dispatch\""),
		({ ..bot, event_name: Err(Missing) }, "token claim event_name is missing"),
		({ ..pub, event_name: Ok("schedule") }, "token claim repository_id is \"812345\", expected \"900001\""),
		({ ..bot, repository_id: Ok("1"), event_name: Ok("push") }, "token claim repository_id is \"1\", expected \"900001\""),
	]
	cases.all(|(claims, detail)| Oidc.check_bot(claims, bot_ids) == Err(forbid(detail)))
}

# R-TP1, R-TP3 rows 4, 6, 7, 8, R-TP4: a fixed rule with no per-repository config. A publish token passes for the events release, push and
# workflow_dispatch, and row 4 folds ASCII case.
expect {
	ok = [pub, { ..pub, event_name: Ok("release") }, { ..pub, event_name: Ok("workflow_dispatch") }, { ..pub, repository: Ok("Acme/Roc-JSON") }]
	ok.all(|c| Oidc.check_publish(c, asset) == Ok({})) and (Oidc.check_publish(pub, { ..asset, owner_repo: "ACME/roc-json" }) == Ok({}))
}

# R-TP3 rows 4 to 8, R-TP4: each fault is 403 and names the claim.
expect {
	cases = [
		(pub, { ..asset, host: "gitlab.com" }, "token claim repository: the asset URL host is \"gitlab.com\", expected \"github.com\""),
		(pub, { ..asset, owner_repo: "acme/roc-json2" }, "token claim repository is \"acme/roc-json\", expected \"acme/roc-json2\""),
		({ ..pub, repository: Ok("evil/roc-json") }, asset, "token claim repository is \"evil/roc-json\", expected \"acme/roc-json\""),
		({ ..pub, repository: Err(Missing) }, asset, "token claim repository is missing"),
		({ ..pub, repository_visibility: Ok("private") }, asset, "token claim repository_visibility is \"private\", expected \"public\""),
		({ ..pub, repository_visibility: Ok("internal") }, asset, "token claim repository_visibility is \"internal\", expected \"public\""),
		({ ..pub, repository_visibility: Err(Missing) }, asset, "token claim repository_visibility is missing"),
		({ ..pub, ref_type: Ok("branch"), ref: Ok("refs/heads/main") }, asset, "token claim ref_type is \"branch\", expected \"tag\""),
		({ ..pub, ref_type: Err(Missing) }, asset, "token claim ref_type is missing"),
		({ ..pub, ref: Ok("refs/tags/1.2.1") }, asset, "token claim ref is \"refs/tags/1.2.1\", expected \"refs/tags/1.2.0\""),
		({ ..pub, ref: Ok("refs/tags/V1.2.0") }, { ..asset, tag: "v1.2.0" }, "token claim ref is \"refs/tags/V1.2.0\", expected \"refs/tags/v1.2.0\""),
		({ ..pub, ref: Ok("refs/heads/1.2.0") }, asset, "token claim ref is \"refs/heads/1.2.0\", expected \"refs/tags/1.2.0\""),
		({ ..pub, ref: Err(Missing) }, asset, "token claim ref is missing"),
		({ ..pub, event_name: Ok("pull_request_target") }, asset, "token claim event_name is \"pull_request_target\", expected \"release\", \"push\" or \"workflow_dispatch\""),
		({ ..pub, event_name: Ok("workflow_run") }, asset, "token claim event_name is \"workflow_run\", expected \"release\", \"push\" or \"workflow_dispatch\""),
		({ ..pub, event_name: Ok("schedule") }, asset, "token claim event_name is \"schedule\", expected \"release\", \"push\" or \"workflow_dispatch\""),
		({ ..pub, event_name: Err(Missing) }, asset, "token claim event_name is missing"),
		({ ..pub, repository_visibility: Ok("private"), ref_type: Ok("branch"), event_name: Ok("schedule") }, asset, "token claim repository_visibility is \"private\", expected \"public\""),
		({ ..pub, ref_type: Ok("branch"), event_name: Ok("schedule") }, asset, "token claim ref_type is \"branch\", expected \"tag\""),
	]
	cases.all(|(claims, a, detail)| Oidc.check_publish(claims, a) == Err(forbid(detail)))
}

# R-TP3 row 5, R-TP5, R-TP9: with no repos row the row passes. With a row, one equal id is enough. Both ids different, or both claims missing: it fails.
expect {
	row = Ok({ repository_id: "812345", repository_owner_id: "612345" })
	(Oidc.binding_ok(pub, Err(NoRow)))
		and (Oidc.binding_ok(missing, Err(NoRow)))
		and (Oidc.binding_ok(pub, row))
		and (Oidc.binding_ok({ ..pub, repository_owner_id: Ok("1") }, row))
		and (Oidc.binding_ok({ ..pub, repository_id: Ok("1") }, row))
		and (Oidc.binding_ok({ ..pub, repository_id: Err(Missing) }, row))
		and !(Oidc.binding_ok({ ..pub, repository_id: Ok("1"), repository_owner_id: Ok("2") }, row))
		and !(Oidc.binding_ok({ ..pub, repository_id: Err(Missing), repository_owner_id: Err(Missing) }, row))
		and !(Oidc.binding_ok({ ..pub, repository_id: Ok("612345"), repository_owner_id: Ok("812345") }, row))
}
