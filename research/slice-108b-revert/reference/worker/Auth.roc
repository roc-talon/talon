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
import jwt.Jwk
import lib.Problem

Auth :: [].{

	## The JWKS of GitHub, kept in the isolate with its fetch time (API.md RN6, MODULES.md 9). `Oidc.key_step` decides when to read again
	## (1 h, and 60 s for an unknown `kid`: Q108-1, Q108-2, R-TP16). The `Memo` expiry is only a bound: it uses the shim clock, not the case clock (section 9 P1).
	jwks : Memo(Oidc.KeySet)
	jwks = Memo.new("github-jwks", { max_age_ms: 3_600_000 })

	## R-TP3 rows 1 to 3 for a token text (the text after `Bearer `). The order (slice file section 3.3):
	## 1. `Oidc.parse` (401 for a bad form, an `alg` that is not RS256, no `kid`). No JWKS read for these.
	## 2. The keys: `jwks.get!(load!)`. `load!` is one `GET` of `Oidc.jwks_url`, kept as `{ fetched_ms: Time.now_ms!(), keys }`. A status other than 200,
	##    a network fault, or a body that `Oidc.parse_jwks` refuses is 502 `Upstream` (R-AP21), and nothing is kept: the next request reads again.
	## 3. `Oidc.key_step(cached, kid, Time.now_ms!())`. `Use(key)`: go on. `Refuse(problem)`: the answer. `Reload`: `jwks.clear!()`,
	##    `jwks.get!(load!)`, and `Oidc.key_step` once more with the new value (its `Reload` cannot come again: the age is 0).
	## 4. `WebCrypto.verify!` with `RsaPkcs1(Sha256)`, the key `Jwk(Oidc.jwk_text(key))`, the `signature` and the `signed` bytes.
	##    `BadSignature` is 401 `Oidc.bad_signature`. A `CryptoErr` (for example a key that WebCrypto cannot import) is also 401 `Oidc.bad_signature`.
	## 5. `Oidc.check_token` with the setting `AUDIENCE` and `Time.now_ms!()`.
	## A missing setting is 500 `Internal` with the `detail` of slice 101: `the Worker failed to handle the request`.
	verify! : Str => Try(Oidc.Claims, Problem)
	verify! = |token| {
		jwt = Oidc.decode(token)?
		cached = jwks.get!(load!)?
		key = match Oidc.key_for(cached, jwt.header, Time.now_ms!()) {
			Use(found) => found
			Refuse(problem) => return Err(problem)
			Reload => {
				jwks.clear!()
				fresh = jwks.get!(load!)?
				match Oidc.key_for(fresh, jwt.header, Time.now_ms!()) {
					Use(found) => found
					Refuse(problem) => return Err(problem)
					Reload => return Err(Oidc.unknown_kid(jwt.kid))
				}
			}
		}
		signature_ok = WebCrypto.verify!({ alg: RsaPkcs1(Sha256), key: Jwk(Jwk.to_public_json(key)), signature: jwt.signature, data: jwt.signing_input })
		match signature_ok {
			Ok({}) => {
				audience = setting!("AUDIENCE")?
				Oidc.check_registered(jwt.registered, { audience, now_ms: Time.now_ms!() })?
				Ok(jwt.claims)
			}
			Err(_) => Err(Oidc.bad_signature)
		}
	}

	## One `GET` of the GitHub JWKS, kept with its fetch time. Each fault is 502 `Upstream`.
	load! : () => Try(Oidc.KeySet, Problem)
	load! = || {
		res = Http.get!(Oidc.jwks_url) ? |_| Oidc.jwks_no_answer
		status = res.status()
		if status != 200 {
			Err(Oidc.jwks_status(status))
		} else {
			text = res.text!() ? |_| Oidc.jwks_bad
			_ = Jwk.parse_set(text) ? |_| Oidc.jwks_bad
			Ok({ fetched_ms: Time.now_ms!(), jwks: text })
		}
	}

	## A setting of R-WH14. A missing one is 500 `Internal` with the fixed `detail` of slice 101.
	setting! : Str => Try(Str, Problem)
	setting! = |name| Env.var!(name).map_err(|_| Problem.new(Internal, "the Worker failed to handle the request"))

	## R-TP7 for the bot routes (R-AP6, R-AP10 with a token): `Oidc.bearer` of the `Authorization` header (`NoToken` is 401 `Oidc.missing_token`),
	## then `verify!`, then `Oidc.check_bot` with the settings `BOT_REPOSITORY_ID` and `BOT_WORKFLOW_REF`.
	bot! : Request => Try(Oidc.Claims, Problem)
	bot! = |req| {
		token = match Oidc.bearer(req.header("authorization")) {
			Token(text) => text
			NoToken => return Err(Oidc.missing_token)
			Refuse(problem) => return Err(problem)
		}
		claims = verify!(token)?
		repository_id = setting!("BOT_REPOSITORY_ID")?
		workflow_ref = setting!("BOT_WORKFLOW_REF")?
		Oidc.check_bot(claims, { repository_id, workflow_ref })?
		Ok(claims)
	}
}
