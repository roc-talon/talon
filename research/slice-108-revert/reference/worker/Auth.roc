## The effectful part of the GitHub OIDC token check (Registry 7.1, R-TP3 rows 1 to 3, R-TP7, API.md RN6; slice 108).
## The decisions are in `lib/Oidc.roc` (pure, W0). This module only orders the effects: the settings, the clock, the JWKS read, the verify.
## The tests are W2: `worker/tests/cases/oidc/` (the fake JWKS of the fake GitHub, tokens that the runner signs).
## Each `Err` is the problem of the answer. A route gives it as the answer with `problem_response` of `main.roc`, not as `Internal`.
import pf.Request
import pf.Http
import pf.Memo
import pf.WebCrypto
import pf.Env
import pf.Time
import lib.Oidc
import lib.Problem

Auth :: [].{

	## The JWKS of GitHub, kept in the isolate (API.md RN6, MODULES.md 9). The max age is a proposal (question Q108-2): 1 h, as the example of MODULES.md 9.
	jwks : Memo(Oidc.Cached)
	jwks = Memo.new("github-jwks", { max_age_ms: 3_600_000 })

	## R-TP3 rows 1 to 3 for a token text (the text after `Bearer `). The order (slice file section 3.3):
	## 1. `Oidc.parse` (401 for a bad form, an `alg` that is not RS256, no `kid`). No JWKS read for these.
	## 2. The keys: `jwks.get!(load!)`. `load!` is one `GET` of `Oidc.jwks_url`. A status other than 200, a network fault, or a body that
	##    `Oidc.parse_jwks` refuses is 502 `Upstream` (R-AP21), and nothing is kept: the next request reads again.
	## 3. `Oidc.find_key` with the `kid`. When the `kid` is not there: `jwks.clear!()`, then `jwks.get!(load!)` once more (one read again for each
	##    request, question Q108-1). Still not there: 401 `Oidc.unknown_kid(kid)`.
	## 4. `WebCrypto.verify!` with `RsaPkcs1(Sha256)`, the key `Jwk(Oidc.jwk_text(key))`, the `signature` and the `signed` bytes.
	##    `BadSignature` is 401 `Oidc.bad_signature`. A `CryptoErr` (for example a key that WebCrypto cannot import) is also 401 `Oidc.bad_signature`.
	## 5. `Oidc.check_token` with the setting `AUDIENCE` and `Time.now_ms!()`.
	## A missing setting is 500 `Internal` with the `detail` of slice 101: `the Worker failed to handle the request`.
	verify! : Str => Try(Oidc.Claims, Problem)
	verify! = |token| {
		jwt = Oidc.parse(token)?
		key = key!(jwt.kid)?
		match WebCrypto.verify!({ alg: RsaPkcs1(Sha256), key: Jwk(Oidc.jwk_text(key)), signature: jwt.signature, data: jwt.signed }) {
			Ok({}) => {}
			Err(_) => return Err(Oidc.bad_signature)
		}
		audience = setting!("AUDIENCE")?
		Oidc.check_token(jwt.claims, { audience, now_ms: Time.now_ms!() })?
		Ok(jwt.claims)
	}

	key! : Str => Try(Oidc.Key, Problem)
	key! = |kid| {
		cached = jwks.get!(load!)?
		match Oidc.key_step(cached, kid, Time.now_ms!()) {
			Use(k) => Ok(k)
			Refuse(p) => Err(p)
			Reload => {
				jwks.clear!()
				again = jwks.get!(load!)?
				match Oidc.key_step(again, kid, Time.now_ms!()) {
					Use(k) => Ok(k)
					Refuse(p) => Err(p)
					Reload => Err(Oidc.unknown_kid(kid))
				}
			}
		}
	}

	load! : () => Try(Oidc.Cached, Problem)
	load! = || {
		res = Http.send!(Request.get(Oidc.jwks_url)) ? |_| Oidc.jwks_no_answer
		if res.status() != 200 {
			return Err(Oidc.jwks_status(res.status()))
		}
		text = res.text!() ? |_| Oidc.jwks_bad
		keys = Oidc.parse_jwks(text) ? |_| Oidc.jwks_bad
		Ok({ fetched_ms: Time.now_ms!(), keys })
	}

	setting! : Str => Try(Str, Problem)
	setting! = |name| Env.var!(name).map_err(|_| Problem.new(Internal, "the Worker failed to handle the request"))

	## R-TP7 for the bot routes (R-AP6, R-AP10 with a token): `Oidc.bearer` of the `Authorization` header (`NoToken` is 401 `Oidc.missing_token`),
	## then `verify!`, then `Oidc.check_bot` with the settings `BOT_REPOSITORY_ID` and `BOT_WORKFLOW_REF`.
	bot! : Request => Try(Oidc.Claims, Problem)
	bot! = |req| {
		token = match Oidc.bearer(req.header("authorization")) {
			Token(t) => t
			NoToken => return Err(Oidc.missing_token)
			Refuse(p) => return Err(p)
		}
		claims = verify!(token)?
		repository_id = setting!("BOT_REPOSITORY_ID")?
		workflow_ref = setting!("BOT_WORKFLOW_REF")?
		Oidc.check_bot(claims, { repository_id, workflow_ref })?
		Ok(claims)
	}
}
