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
import lib.Move
import lib.Problem
import jwt.Jwk

Auth :: [].{

	## The JWKS text of GitHub, kept in the isolate with its fetch time (API.md RN6, MODULES.md 9). `Oidc.key_for` decides when to read again
	## (1 h, and 60 s for an unknown `kid`: Q108-1, Q108-2, R-TP16). The `Memo` expiry is only a bound above that rule (slice 123): the platform clock is the case clock, and a `Memo`
	## expires at the pin time plus the age, or later, so a `Memo` of exactly 1 h would expire at `age == 3_600_000`, one ms before the rule `age > 3_600_000` of `Oidc.key_for`.
	## The value is the text, not a `List(Jwk.Key)`. Both forms round-trip through the CBOR form of the `Memo` in a `--opt=speed` build (slice 108b, section 9 P1).
	jwks : Memo(Oidc.KeySet)
	jwks = Memo.new("github-jwks", { max_age_ms: 7_200_000 })

	## R-TP3 rows 1 to 3 for a token text (the text after `Bearer `). The order (slice 108, section 3.3):
	## 1. `Oidc.decode` (401 for a bad form, an `alg` that is not RS256, no `kid`). No JWKS read for these.
	## 2. The keys: `jwks.get!(load!)`. `load!` is one `GET` of `Oidc.jwks_url`, kept as `{ fetched_ms: Time.now_ms!(), jwks: text }`. A status other than 200,
	##    a network fault, or a body that `Jwk.parse_set` refuses is 502 `Upstream` (R-AP21), and nothing is kept: the next request reads again.
	## 3. `Oidc.key_for(keys, jwt.header, Time.now_ms!())`. `Use(key)`: go on. `Refuse(problem)`: the answer. `Reload`: `jwks.clear!()`,
	##    `jwks.get!(load!)`, and `Oidc.key_for` once more with the new value (its `Reload` cannot come again: the age is 0).
	## 4. `WebCrypto.verify!` with `RsaPkcs1(Sha256)`, the key `Jwk(Jwk.to_public_json(key))`, the `signature` and the `signing_input` bytes.
	##    `BadSignature` is 401 `Oidc.bad_signature`. A `CryptoErr` (for example a key that WebCrypto cannot import) is also 401 `Oidc.bad_signature`.
	## 5. `Oidc.check_registered` with the setting `AUDIENCE` and `Time.now_ms!()`.
	## A missing setting is 500 `Internal` with the `detail` of slice 101: `the Worker failed to handle the request`.
	verify! : Str => Try(Oidc.Claims, Problem)
	verify! = |token| {
		jwt = Oidc.decode(token)?
		keys = jwks.get!(load!)?
		key = match Oidc.key_for(keys, jwt.header, Time.now_ms!()) {
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

	## One `GET` of the GitHub JWKS, kept with its fetch time when `Jwk.parse_set` accepts it. Each fault is 502 `Upstream`.
	load! : () => Try(Oidc.KeySet, Problem)
	load! = || {
		res = Http.get!(Oidc.jwks_url) ? |_| Oidc.jwks_no_answer
		status = res.status()
		if status != 200 {
			Err(Oidc.jwks_status(status))
		} else {
			text = res.text!() ? |_| Oidc.jwks_bad
			_keys = Jwk.parse_set(text) ? |_| Oidc.jwks_bad
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

	## R-TP3 for a publish (R-AP8, slice 114): `Oidc.bearer` of the `Authorization` header (`NoToken` is 401 `Oidc.missing_token`: the route calls this only when the header is there),
	## then `verify!` (rows 1 to 3), then `Oidc.check_publish` (rows 4, 6, 7, 8) with the host `github.com` and the `owner_repo` and `tag` of the asset URL. The result is the claims.
	## Row 5 (the ids against the `repos` row) is `Identity.decide` in the route. A missing setting is 500 `internal`.
	publish! : Request, { owner_repo : Str, tag : Str } => Try(Oidc.Claims, Problem)
	publish! = |req, asset| {
		token = match Oidc.bearer(req.header("authorization")) {
			Token(text) => text
			NoToken => return Err(Oidc.missing_token)
			Refuse(problem) => return Err(problem)
		}
		claims = verify!(token)?
		Oidc.check_publish(claims, { host: "github.com", owner_repo: asset.owner_repo, tag: asset.tag })?
		Ok(claims)
	}

	## R-TP15 for the move routes (R-AP31, slice 247): `Oidc.bearer` of the `Authorization` header (`NoToken` is 401 `Oidc.missing_token`), then the text is compared with the secret `OPERATOR_KEY` (R-YK2, a compare in constant time,
	## `WebCrypto.timing_safe_equal`): equal is `Operator` (no JWKS read, no claims). A text that is not equal is a token: `verify!` (rows 1 to 3), then `Move.check_token` (row 6 and `event_name` `workflow_dispatch`): `Token(claims)`.
	## A missing setting `OPERATOR_KEY` means that no text is the key (the route works for tokens only). The tests are W2: `worker/tests/cases/move/`. (If slice 246 adds a shared operator check, `move!` calls it.)
	move! : Request => Try([Operator, Token(Oidc.Claims)], Problem)
	move! = |req| {
		token = match Oidc.bearer(req.header("authorization")) {
			Token(text) => text
			NoToken => return Err(Oidc.missing_token)
			Refuse(problem) => return Err(problem)
		}
		if operator_match!(token) == Match {
			Ok(Operator)
		} else {
			claims = verify!(token)?
			Move.check_token(claims)?
			Ok(Token(claims))
		}
	}

	## R-YK1, R-YK2, Q246-5, Q246-6 for the yank routes (slice 246): `Oidc.bearer` of the `Authorization` header (`NoToken` is 401 `Oidc.missing_token`), then `operator_match!`.
	## `Match` is `Operator` (no JWKS read, no claims). `NoMatch` is a token: `verify!` (R-TP3 rows 1 to 3), the caller is `Author(claims)`. `NoKey` (the secret is missing or empty) is 500 `internal`.
	yank! : Request => Try([Operator, Author(Oidc.Claims)], Problem)
	yank! = |req| {
		token = match Oidc.bearer(req.header("authorization")) {
			Token(text) => text
			NoToken => return Err(Oidc.missing_token)
			Refuse(problem) => return Err(problem)
		}
		match operator_match!(token) {
			Match => Ok(Operator)
			NoKey => Err(Problem.new(Internal, "the Worker failed to handle the request"))
			NoMatch => Ok(Author(verify!(token)?))
		}
	}

	## R-YK2, Q246-5: is the bearer text the secret `OPERATOR_KEY`? Both texts are hashed with HMAC-SHA256 under the key (so the 2 values have the same length, 32 bytes), then compared with
	## `WebCrypto.timing_safe_equal!`: the time shows neither the length nor a prefix of the key. `NoKey`: the secret is missing or empty, and it never matches (Q246-6). A route that wants
	## "no key means no match" (the move routes) maps `NoKey` to `NoMatch`.
	operator_match! : Str => [Match, NoMatch, NoKey]
	operator_match! = |text| match Env.secret!("OPERATOR_KEY") {
		Ok(secret) if !secret.reveal().is_empty() => {
			key = secret.reveal().to_utf8()
			if (WebCrypto.timing_safe_equal!(WebCrypto.hmac_sha256(key, key), WebCrypto.hmac_sha256(key, text.to_utf8()))) Match else NoMatch
		}
		_ => NoKey
	}
}
