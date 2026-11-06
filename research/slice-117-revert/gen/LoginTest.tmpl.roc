import lib.Login
import lib.Route
import lib.Client
import lib.Problem
import lib.Compat
import records.Account

LoginTest :: [].{}

# W0 tests of worker/lib/Login.roc and the routes of slice 117 (docs/slices/117-login.md). This file is made by research/slice-117-revert/gen/mk_logintest.mjs from LoginTest.tmpl.roc:
# the token texts and the signature come from research/slice-117-revert/gen/vectors.mjs with node (crypto, the key of RFC 8037 A.1): no expected value comes from the Roc code.
# The answers of the design agent (Q300 to Q312, rule R-CT16) are in. The slice file section 11 maps each question to the tests.

aud : Str
aud = "https://registry.example"

# 2026-01-01T00:00:01Z, the clock of the W2 cases for the first request.
now : U64
now = 1_767_225_601_000

unauth : Str -> Try(a, Problem)
unauth = |text| Err(Problem.new(Unauthenticated, text))

bad : Str -> Try(a, Problem)
bad = |text| Err(Problem.new(BadRequest, text))

upstream : Str -> Try(a, Problem)
upstream = |text| Err(Problem.new(Upstream, text))

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-AP37, R-AP46 row 1, R-AP51, R-CT16 row 1 (Q303): the body of the login. The text `github_token` is the only member: not empty, at most 512 bytes, each byte from `!` to `~`.

body_of : Str -> Str
body_of = |text| match Login.login_token(text.to_utf8()) {
	Ok(t) => "ok ${t}"
	Err(Bad(p)) => "${p.http_status().to_str()} ${p.to_json()}"
	Err(TooLarge(p, extra)) => "${p.http_status().to_str()} ${extra.field} ${extra.limit.to_str()}"
}

starts400 : Str -> Bool
starts400 = |r| r.starts_with("400 ")

invalid : Str -> Str
invalid = |why| "400 ${Problem.new(BadRequest, "the login request body is not valid: ${why}").to_json()}"

expect {
	good = body_of("{\"github_token\":\"ghu_abcDEF0123456789\"}") == "ok ghu_abcDEF0123456789"
	extra = body_of("{\"github_token\":\"ghu_x\",\"other\":[1,2],\"talon_version\":\"0.4.1\"}") == "ok ghu_x"
	json_escape = body_of("{\"github_token\":\"gh\\u0075_x\"}") == "ok ghu_x"
	edge_len = body_of("{\"github_token\":\"${Str.repeat("a", 512)}\"}") == "ok ${Str.repeat("a", 512)}"
	too_long = body_of("{\"github_token\":\"${Str.repeat("a", 513)}\"}") == invalid("github_token is longer than 512 bytes")
	missing = body_of("{}") == invalid("github_token is missing")
	missing_other = body_of("{\"token\":\"ghu_x\"}") == invalid("github_token is missing")
	null_token = starts400(body_of("{\"github_token\":null}"))
	empty = body_of("{\"github_token\":\"\"}") == invalid("github_token is empty")
	space = body_of("{\"github_token\":\"ghu x\"}") == invalid("github_token has a byte that is not allowed in a token")
	newline = body_of("{\"github_token\":\"ghu_x\\r\\nx-evil: 1\"}") == invalid("github_token has a byte that is not allowed in a token")
	high = body_of("{\"github_token\":\"ghu_\u(e9)\"}") == invalid("github_token has a byte that is not allowed in a token")
	number = starts400(body_of("{\"github_token\":12}"))
	not_object = starts400(body_of("[\"ghu_x\"]"))
	not_json = starts400(body_of("ghu_x"))
	empty_body = starts400(body_of(""))
	not_utf8 = match Login.login_token([123, 255, 125]) {
		Err(Bad(p)) => p.http_status() == 400
		_ => Bool.False
	}
	big_edge = match Login.login_token(Str.repeat(" ", 262_144).to_utf8()) {
		Err(Bad(p)) => p.http_status() == 400
		_ => Bool.False
	}
	big = body_of(Str.repeat(" ", 262_145)) == "413 body 262144"
	big_before_json = body_of(Str.repeat("x", 262_145)) == "413 body 262144"
	good and extra and json_escape and edge_len and too_long and missing and missing_other and null_token and empty and space and newline and high and number and not_object and not_json and empty_body and not_utf8 and big_edge and big and big_before_json
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT8 rows 2, 4, R-AP37, R-AP21: the answer of GitHub as a decision. Only 401 is a refusal of the token (Q304).

expect {
	ok = Login.github_user(200, "{\"id\":4242,\"login\":\"someone\",\"type\":\"User\",\"site_admin\":false}") == Ok({ id: 4242, login: "someone" })
	big_id = Login.github_user(200, "{\"id\":9007199254740991,\"login\":\"x\"}") == Ok({ id: 9007199254740991, login: "x" })
	refused = Login.github_user(401, "") == Err(Login.user_refused)
	refused_body = Login.github_user(401, "{\"message\":\"Bad credentials\"}") == Err(Login.user_refused)
	s500 = Login.github_user(500, "") == upstream("the GitHub user read failed with status 500")
	s403 = Login.github_user(403, "{\"message\":\"rate limit\"}") == upstream("the GitHub user read failed with status 403")
	s429 = Login.github_user(429, "") == upstream("the GitHub user read failed with status 429")
	s404 = Login.github_user(404, "") == upstream("the GitHub user read failed with status 404")
	s302 = Login.github_user(302, "") == upstream("the GitHub user read failed with status 302")
	no_user = |body| Login.github_user(200, body) == upstream("the GitHub user read gave an answer that is not a user")
	no_user_all = no_user("") and no_user("not json") and no_user("[]") and no_user("{}") and no_user("{\"login\":\"x\"}") and no_user("{\"id\":4242}") and no_user("{\"id\":0,\"login\":\"x\"}")
		and no_user("{\"id\":-5,\"login\":\"x\"}") and no_user("{\"id\":4242,\"login\":\"\"}") and no_user("{\"id\":\"4242\",\"login\":\"x\"}") and no_user("{\"id\":4242,\"login\":null}") and no_user("{\"id\":4242.5,\"login\":\"x\"}")
	kinds = Login.user_refused.http_status() == 401 and Login.user_no_answer.http_status() == 502 and Login.rate_problem.http_status() == 429 and Login.missing_token.http_status() == 401
		and Login.bad_signature.http_status() == 401 and Login.no_account.http_status() == 401 and Login.revoked_problem.http_status() == 401 and Login.not_good.http_status() == 401
	ok and big_id and refused and refused_body and s500 and s403 and s429 and s404 and s302 and no_user_all and kinds
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9 (Q300): the secret TOKEN_KEY is the private JWK of an Ed25519 key with a kid. The key is the test key of RFC 8037 A.1.

key_text : Str
key_text = "{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"key-1\",\"x\":\"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo\",\"d\":\"nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A\"}"

expect {
	ok = match Login.signing_key(key_text) {
		Ok(k) => k.kid == "key-1" and k.public_json.contains("\"x\":\"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo\"") and k.public_json.contains("Ed25519") and !k.public_json.contains("nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A") and !k.public_json.contains("\"d\"")
		Err(_) => Bool.False
	}
	refuses = |text| Login.signing_key(text) == Err(BadKey)
	no_kid = refuses("{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"x\":\"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo\",\"d\":\"nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A\"}")
	empty_kid = refuses("{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"\",\"x\":\"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo\",\"d\":\"nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A\"}")
	no_x = refuses("{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"key-1\",\"d\":\"nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A\"}")
	rsa = refuses("{\"kty\":\"RSA\",\"kid\":\"key-1\",\"n\":\"AQAB\",\"e\":\"AQAB\"}")
	ec = refuses("{\"kty\":\"EC\",\"crv\":\"P-256\",\"kid\":\"key-1\",\"x\":\"f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU\",\"y\":\"x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0\"}")
	oct = refuses("{\"kty\":\"oct\",\"kid\":\"key-1\",\"k\":\"AAAA\"}")
	not_json = refuses("not a key") and refuses("") and refuses("[]")
	ok and no_kid and empty_kid and no_x and rsa and ec and oct and not_json
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9 (Q301): the form of `iat` and `exp`, the signing input, the token text and `expires_at` (R-AP37, R-AP50).

sig_bytes : List(U8)
sig_bytes = @@sig@@

expect {
	s1 = Login.seconds_text(1_767_225_601_234) == "1767225601.234"
	s2 = Login.seconds_text(1_767_225_600_000) == "1767225600.000"
	s3 = Login.seconds_text(5) == "0.005"
	s4 = Login.seconds_text(0) == "0.000"
	s5 = Login.seconds_text(1_999) == "1.999"
	s6 = Login.seconds_text(2_592_000_000) == "2592000.000"
	e1 = Login.expires_at(1_767_225_601_234) == 1_769_817_601_234
	e2 = Login.expires_at(0) == 2_592_000_000
	input = Login.signing_input({ kid: "key-1", sub: 4242, now_ms: 1_767_225_601_234, audience: aud })
	i1 = input == "@@input@@"
	i2 = Login.signing_input({ kid: "k\"1", sub: 9_007_199_254_740_993, now_ms: 0, audience: "https://r.example/a\\b" }) == "@@input2@@"
	t1 = Login.token_text(input, sig_bytes) == "@@token@@"
	# the token text decodes: the claims are the ones that were written (the signature is not checked here)
	d = Login.decode(Login.token_text(input, sig_bytes), "key-1")
	d1 = match d {
		Ok(x) => x.claims.sub == Ok("4242") and x.claims.iss == Ok(aud) and x.claims.aud == Ok([aud]) and x.claims.iat == Ok(1767225601.234) and x.claims.exp == Ok(1769817601.234) and x.signature == sig_bytes and x.signing_input == input.to_utf8()
		Err(_) => Bool.False
	}
	s1 and s2 and s3 and s4 and s5 and s6 and e1 and e2 and i1 and i2 and t1 and d1
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9 row `alg`, `kid`: the form of a token. The algorithm list is EdDSA only: a GitHub OIDC token (RS256) with the audience of the registry is not an account token. No D1 call, no crypto.

form : Str -> Try(Str, Str)
form = |text| match Login.decode(text, "key-1") {
	Ok(_) => Ok("ok")
	Err(p) => Err(p.to_json())
}

refused_form : Str -> Str
refused_form = |detail| Problem.new(Unauthenticated, detail).to_json()

expect {
	good = form("@@dec.good@@") == Ok("ok")
	none = form("@@dec.none@@") == Err(refused_form("the token alg is \"none\", expected \"EdDSA\""))
	hs256 = form("@@dec.hs256@@") == Err(refused_form("the token alg is \"HS256\", expected \"EdDSA\""))
	rs256 = form("@@dec.rs256@@") == Err(refused_form("the token alg is \"RS256\", expected \"EdDSA\""))
	no_alg = form("@@dec.noalg@@") == Err(refused_form("the token alg is missing"))
	no_kid = form("@@dec.nokid@@") == Err(refused_form("the token kid is missing"))
	other_kid = form("@@dec.otherkid@@") == Err(refused_form("the token kid \"key-2\" is not the key of this registry"))
	compact = form("@@dec.compact@@") == Err(refused_form("the token is not a valid JWT"))
	empty_sig = form("@@dec.empty@@") == Err(refused_form("the token is not a valid JWT"))
	short_sig = form("@@dec.short@@") == Err(refused_form("the token is not a valid JWT"))
	garbage = form("garbage") == Err(refused_form("the token is not a valid JWT")) and form("") == Err(refused_form("the token is not a valid JWT"))
	good and none and hs256 and rs256 and no_alg and no_kid and other_kid and compact and empty_sig and short_sig and garbage
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9 claims, R-CT16 row 6: `iss` and `aud` are the setting AUDIENCE, `exp` after now, `iat` not in the future, `sub` the GitHub user id. The clock is 1767225601000 ms. The
# leeway is 60 s (Q301): `exp` = clock - 60 s is refused, clock - 59.999 s is good; `iat` = clock + 60 s is good, clock + 60.001 s is refused. The
# first fault gives the answer: iss, aud, sub, exp, iat (the order of roc-jwt C8), and the user id last.

verdict : Str -> Try(Login.Verified, Problem)
verdict = |text| match Login.decode(text, "key-1") {
	Ok(d) => Login.check(d, { audience: aud, now_ms: now })
	Err(p) => Err(p)
}

expect {
	good = verdict("@@chk.good@@") == Ok({ account: 4242, iat_ms: 1_767_225_600_000 })
	frac = verdict("@@chk.frac@@") == Ok({ account: 4242, iat_ms: 1_767_225_600_500 })
	exp_edge = verdict("@@chk.exp_eq@@") == unauth("token claim exp is 1767225541: the token expired (now is 1767225601, leeway 60 s)")
	exp_ok = verdict("@@chk.exp_ok@@") == Ok({ account: 4242, iat_ms: 1_767_225_600_000 })
	future = verdict("@@chk.iat_future@@") == unauth("token claim iat is 1767225661: the token is issued in the future (now is 1767225601, leeway 60 s)")
	iat_eq = verdict("@@chk.iat_eq@@") == Ok({ account: 4242, iat_ms: 1_767_225_661_000 })
	iss = verdict("@@chk.iss@@") == unauth("token claim iss is \"https://other.example\", expected \"https://registry.example\"")
	aud_bad = verdict("@@chk.aud@@") == unauth("token claim aud is \"https://other.example\", expected \"https://registry.example\"")
	aud_list = verdict("@@chk.aud_list@@") == Ok({ account: 4242, iat_ms: 1_767_225_600_000 })
	aud_miss = verdict("@@chk.aud_miss@@") == unauth("token claim aud is missing")
	iat_miss = verdict("@@chk.iat_miss@@") == unauth("token claim iat is missing")
	exp_miss = verdict("@@chk.exp_miss@@") == unauth("token claim exp is missing")
	sub_miss = verdict("@@chk.sub_miss@@") == unauth("token claim sub is missing")
	iss_miss = verdict("@@chk.iss_miss@@") == unauth("token claim iss is missing")
	sub_bad = |text, sub| verdict(text) == unauth("token claim sub is \"${sub}\", expected a GitHub user id")
	subs = sub_bad("@@chk.sub_abc@@", "abc") and sub_bad("@@chk.sub_0@@", "0") and sub_bad("@@chk.sub_neg@@", "-5") and sub_bad("@@chk.sub_frac@@", "12.5") and sub_bad("@@chk.sub_plus@@", "+7")
		and sub_bad("@@chk.sub_empty@@", "") and sub_bad("@@chk.sub_big@@", "18446744073709551616")
	sub_num = match verdict("@@chk.sub_num@@") {
		Err(p) => p == Problem.new(Unauthenticated, "the token is not a valid JWT")
		Ok(_) => Bool.False
	}
	sub_max = verdict("@@chk.sub_max@@") == Ok({ account: 9_007_199_254_740_993, iat_ms: 1_767_225_600_000 })
	good and frac and exp_edge and exp_ok and future and iat_eq and iss and aud_bad and aud_list and aud_miss and iat_miss and exp_miss and sub_miss and iss_miss and subs and sub_num and sub_max
}

# R-CT9: `iat` not before `tokens_after`. Equal is good (a login in the same ms as a revoke works). One ms before is revoked.
expect {
	revoked = |iat_ms, tokens_after| Login.revoked({ iat_ms, tokens_after })
	!revoked(1_767_225_601_000, 0) and !revoked(1_767_225_601_000, 1_767_225_601_000) and revoked(1_767_225_600_999, 1_767_225_601_000) and revoked(0, 1) and !revoked(5, 5) and !revoked(1_767_225_601_001, 1_767_225_601_000)
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-AP36, R-CT7, R-CT16 row 7 (Q306): the proof of `DELETE /v1/contributors/me`. A header Authorization is the account form (a token wins, as R-CT1); only without it the header Talon-Contributor is a machine.

proof : Try(Str, [NotFound]), Try(Str, [NotFound]) -> Str
proof = |authorization, contributor| match Login.delete_proof({ authorization, contributor }) {
	Account(t) => "account ${t}"
	Machine(id) => "machine ${id}"
	Refuse(p) => p.to_json()
}

expect {
	id = "0123456789abcdef0123456789abcdef"
	nf = Err(NotFound)
	account = proof(Ok("Bearer abc.def.ghi"), nf) == "account abc.def.ghi" and proof(Ok("bearer abc.def.ghi"), nf) == "account abc.def.ghi"
	token_wins = proof(Ok("Bearer abc.def.ghi"), Ok(id)) == "account abc.def.ghi" and proof(Ok("Bearer abc.def.ghi"), Ok("not an id")) == "account abc.def.ghi"
	bad_scheme = proof(Ok("Basic abc"), Ok(id)) == Problem.new(Unauthenticated, "the Authorization header must be \"Bearer <token>\"").to_json()
	bad_empty = proof(Ok("Bearer"), nf) == Problem.new(Unauthenticated, "the Authorization header must be \"Bearer <token>\"").to_json()
	machine = proof(nf, Ok(id)) == "machine ${id}"
	bad_id = proof(nf, Ok("0123456789ABCDEF0123456789abcdef")) == Problem.new(BadRequest, "the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f").to_json()
	bad_short = proof(nf, Ok("abc")) == Problem.new(BadRequest, "the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f").to_json()
	neither = proof(nf, nf) == Problem.new(BadRequest, "the request needs the header Authorization (an account) or the header Talon-Contributor (one machine)").to_json()
	account and token_wins and bad_scheme and bad_empty and machine and bad_id and bad_short and neither
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-AP35, R-CT10: the tracker of the answer from the GitHub id, the login and the SQL row. `Missing` is `null`.

expect {
	row = { machines: 2, counted: 9, first: 4, agreed: 3, disagreed: 1, unconfirmed: 5, first_time: Ok(1_767_225_000_000), last_time: Ok(1_767_225_900_000) }
	none = { machines: 0, counted: 0, first: 0, agreed: 0, disagreed: 0, unconfirmed: 0, first_time: Err(Missing), last_time: Err(Missing) }
	full = Login.tracker_of({ id: 4242, login: "someone" }, row) == { account: { id: 4242, login: "someone" }, machines: 2, counted: 9, first: 4, agreed: 3, disagreed: 1, unconfirmed: 5, first_time: Ok(1_767_225_000_000), last_time: Ok(1_767_225_900_000) }
	empty = Login.tracker_of({ id: 7, login: "x" }, none) == { account: { id: 7, login: "x" }, machines: 0, counted: 0, first: 0, agreed: 0, disagreed: 0, unconfirmed: 0, first_time: Err(None), last_time: Err(None) }
	wire = Account.encode_tracker(Login.tracker_of({ id: 7, login: "x" }, none)).contains("\"first_time\":null")
	full and empty and wire
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT8 row 3, R-CT9, R-CT7, R-RE17, R-RE18, R-RE25, R-CT16 rows 5 and 8: the key words of the SQL texts. W2 pins what they do on local D1 (the 7 cases of `account/`).

expect {
	holds = |text, words| words.all(|w| text.contains(w))
	lacks = |text, words| words.all(|w| !text.contains(w))
	# the upsert of the account: tokens_after and first_time are never in the update part (Q307), no OR REPLACE
	account = Login.account_sql()
	update_part = match account.split_on("DO UPDATE SET") {
		[_, after] => after
		_ => ""
	}
	a1 = holds(account, ["INSERT INTO contributors", "ON CONFLICT", "DO UPDATE SET"]) and lacks(account, ["OR REPLACE", "OR IGNORE"])
	a2 = update_part.contains("login") and update_part.contains("last_time") and !update_part.contains("tokens_after") and !update_part.contains("first_time")
	m = Login.machine_sqls()
	m1 = m.len() == 5 and holds(m.get(0) ?? "", ["INSERT INTO links", "ON CONFLICT", "DO UPDATE SET"]) and holds(m.get(1) ?? "", ["UPDATE OR IGNORE contributions", "SET contributor"])
	m2 = holds(m.get(2) ?? "", ["DELETE FROM contributions"]) and holds(m.get(3) ?? "", ["contributor_totals", "ON CONFLICT", "first_time", "last_time"]) and holds(m.get(4) ?? "", ["DELETE FROM contributor_totals"])
	m3 = m.all(|s| !s.contains("INSERT OR REPLACE") and !s.contains("compat_hints") and !s.contains("INSERT INTO contributions"))
	r = Login.account_row_sql()
	r1 = holds(r, ["FROM contributors", "tokens_after", "login"])
	t = Login.tracker_sql()
	t1 = holds(t, ["contributions", "links", "contributor_totals", "compat", "machines", "unconfirmed", "first_time", "last_time"])
	v = Login.revoke_sql()
	v1 = holds(v, ["UPDATE contributors SET tokens_after", "tokens_after <=", "RETURNING"]) and lacks(v, ["DELETE"])
	fa = Login.forget_account_sqls()
	f1 = fa.len() == 5 and holds(fa.get(0) ?? "", ["SELECT 1 AS revoked", "tokens_after >"])
	f2 = holds(fa.get(1) ?? "", ["DELETE FROM contributions"]) and holds(fa.get(2) ?? "", ["DELETE FROM links"]) and holds(fa.get(3) ?? "", ["DELETE FROM contributor_totals"]) and holds(fa.get(4) ?? "", ["DELETE FROM contributors"])
	f3 = fa.drop_first(1).all(|s| s.contains("tokens_after >")) and fa.all(|s| !s.contains("compat_hints"))
	fm = Login.forget_machine_sqls()
	f4 = fm.len() == 3 and holds(fm.get(0) ?? "", ["DELETE FROM contributions"]) and holds(fm.get(1) ?? "", ["DELETE FROM contributor_totals"]) and holds(fm.get(2) ?? "", ["DELETE FROM links"])
	f5 = fm.all(|s| !s.contains("compat_hints") and !s.contains("tokens_after") and !s.contains("FROM contributors "))
	a1 and a2 and m1 and m2 and m3 and r1 and t1 and v1 and f1 and f2 and f3 and f4 and f5
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-AP35 to R-AP38, R-AP48 rows 1, 2, 5, R-AP23, R-AP45 (Q182): the routes. `/v1/tokens` serves POST (a JSON body) and DELETE, `/v1/contributors/me` serves GET and DELETE. The write routes
# are POST and DELETE tokens and DELETE me; the tracker is a read.

route : Str, List(Str), Try(Str, [NotFound]), Bool -> Route.Decision
route = |method, segments, content_type, has_body| Route.decide({ method, segments, content_type, has_body })

expect {
	nf = Err(NotFound)
	json = Ok("application/json")
	post = route("POST", ["v1", "tokens"], json, Bool.True) == Handle(PostTokens) and route("POST", ["v1", "tokens"], Ok("application/json; charset=utf-8"), Bool.True) == Handle(PostTokens) and route("POST", ["v1", "tokens"], nf, Bool.False) == Handle(PostTokens)
	post_media = route("POST", ["v1", "tokens"], Ok("text/plain"), Bool.True) == Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got text/plain")) and route("POST", ["v1", "tokens"], nf, Bool.True) == Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type"))
	delete_tokens = route("DELETE", ["v1", "tokens"], nf, Bool.False) == Handle(DeleteTokens) and route("DELETE", ["v1", "tokens"], Ok("text/plain"), Bool.True) == Handle(DeleteTokens)
	tokens_405 = route("GET", ["v1", "tokens"], nf, Bool.False) == NotAllowed(Problem.new(MethodNotAllowed, "GET is not allowed on /v1/tokens"), ["DELETE", "POST"]) and route("PUT", ["v1", "tokens"], json, Bool.True) == NotAllowed(Problem.new(MethodNotAllowed, "PUT is not allowed on /v1/tokens"), ["DELETE", "POST"])
	me = route("GET", ["v1", "contributors", "me"], nf, Bool.False) == Handle(GetMe) and route("DELETE", ["v1", "contributors", "me"], nf, Bool.False) == Handle(DeleteMe) and route("DELETE", ["v1", "contributors", "me"], Ok("text/plain"), Bool.True) == Handle(DeleteMe)
	me_405 = route("POST", ["v1", "contributors", "me"], json, Bool.True) == NotAllowed(Problem.new(MethodNotAllowed, "POST is not allowed on /v1/contributors/me"), ["DELETE", "GET"]) and route("PUT", ["v1", "contributors", "me"], nf, Bool.False) == NotAllowed(Problem.new(MethodNotAllowed, "PUT is not allowed on /v1/contributors/me"), ["DELETE", "GET"])
	other_paths = route("GET", ["v1", "contributors"], nf, Bool.False) == Refuse(Problem.new(NotFound, "no route for GET /v1/contributors")) and route("GET", ["v1", "contributors", "you"], nf, Bool.False) == Refuse(Problem.new(NotFound, "no route for GET /v1/contributors/you")) and route("DELETE", ["v1", "tokens", "x"], nf, Bool.False) == Refuse(Problem.new(NotFound, "no route for DELETE /v1/tokens/x"))
	writes = Client.is_write(PostTokens) and Client.is_write(DeleteTokens) and Client.is_write(DeleteMe) and !Client.is_write(GetMe) and Client.is_write(PostCompat) and !Client.is_write(PostClosure)
	post and post_media and delete_tokens and tokens_405 and me and me_405 and other_paths and writes
}
