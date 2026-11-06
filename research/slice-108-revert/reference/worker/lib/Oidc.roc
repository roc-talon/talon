## The pure part of the GitHub OIDC token check (Registry 7.1, R-TP1 to R-TP4, R-TP7, R-AP26; slice 108). No effect, no platform import.
## The effects (the JWKS read through `Memo`, the RS256 verify with `WebCrypto.verify!`, the clock, the settings) are in `worker/Auth.roc`.
## The tests are in `worker/tests/unit/OidcTest.roc` (W0) and `worker/tests/cases/oidc/` (W2).
## Each check gives the first failing row as a `Problem`: 401 `Unauthenticated` for R-TP3 rows 1 to 3, 403 `Forbidden` for the other rows
## and for R-TP7 (R-AP21). The `detail` texts are in `docs/slices/108-oidc.md` section 5 (proposal, TW24):
##   a claim with a wrong value:  token claim <name> is "<value>", expected "<want>"   (numbers with no quotes)
##   a claim that is missing:     token claim <name> is missing
import Problem

Oidc :: [].{

	## The claims that the Worker reads. A claim that is not in the token is `Err(Missing)`. A missing claim fails the row that checks it.
	## A claim of the wrong JSON type (for example a number for `repository_id`) makes the token not valid (`parse` gives 401).
	## `exp` and `nbf` are seconds since 1970 (RFC 7519 NumericDate, integers in GitHub tokens).
	## The last 6 claims and `workflow_ref`, `event_name` are the recorded claims of R-TP6 (slice 114 writes them). This slice does not check them,
	## except `workflow_ref` and `event_name` for R-TP7 and R-TP3 row 8.
	Claims : {
		iss : Try(Str, [Missing]),
		aud : Try(Str, [Missing]),
		exp : Try(U64, [Missing]),
		nbf : Try(U64, [Missing]),
		repository : Try(Str, [Missing]),
		repository_id : Try(Str, [Missing]),
		repository_owner_id : Try(Str, [Missing]),
		repository_visibility : Try(Str, [Missing]),
		ref : Try(Str, [Missing]),
		ref_type : Try(Str, [Missing]),
		event_name : Try(Str, [Missing]),
		workflow_ref : Try(Str, [Missing]),
		workflow_sha : Try(Str, [Missing]),
		job_workflow_ref : Try(Str, [Missing]),
		run_id : Try(Str, [Missing]),
		run_attempt : Try(Str, [Missing]),
		actor_id : Try(Str, [Missing]),
		runner_environment : Try(Str, [Missing]),
	}

	## A token after `parse`: its signature is not checked yet.
	## `kid`: the `kid` of the JOSE header. `signed`: the bytes that the signature covers, the ASCII text `<header>.<payload>` as sent.
	## `signature`: the base64url decode of the third part.
	Jwt : { kid : Str, claims : Oidc.Claims, signed : List(U8), signature : List(U8) }

	## One RSA key of the GitHub JWKS: the members `kid`, `n` and `e` as sent (base64url text). The value of the `Memo` (`worker/Auth.roc`) is a `List(Oidc.Key)`.
	Key : { kid : Str, n : Str, e : Str }

	Cached : { fetched_ms : U64, keys : List(Oidc.Key) }

	max_age_ms : U64
	max_age_ms = 3_600_000

	reread_after_ms : U64
	reread_after_ms = 60_000

	key_step : Oidc.Cached, Str, U64 -> [Use(Oidc.Key), Reload, Refuse(Problem)]
	key_step = |cached, kid, now_ms| {
		age = now_ms.minus_saturated(cached.fetched_ms)
		if age > max_age_ms {
			Reload
		} else {
			match find_key(cached.keys, kid) {
				Ok(k) => Use(k)
				Err(_) => if age > reread_after_ms Reload else Refuse(unknown_kid(kid))
			}
		}
	}

	## The issuer of GitHub Actions OIDC tokens (R-TP3 row 1).
	issuer : Str
	issuer = "https://token.actions.githubusercontent.com"

	## The JWKS of GitHub Actions (R-TP3 row 1, API.md RN6). The Worker reads it with no token.
	jwks_url : Str
	jwks_url = "https://token.actions.githubusercontent.com/.well-known/jwks"

	## The leeway of R-TP3 row 3, in seconds.
	leeway_s : U64
	leeway_s = 60

	## R-AP26: the `Authorization` header selects the path. `NoToken`: the request has no header (an ingest, or 401 on a route that needs a token).
	## `Token(text)`: the header is `Bearer <text>` with a text that is not empty. One space after `Bearer`. The scheme is compared as written: `Bearer`.
	## Any other value is `Refuse(401)` with the `detail` `the Authorization header must be "Bearer <token>"`: never an ingest (R-AP26).
	bearer : Try(Str, [NotFound]) -> [Token(Str), NoToken, Refuse(Problem)]
	bearer = |header| match header {
		Err(NotFound) => NoToken
		Ok(value) =>
			match value.split_first(" ") {
				Ok({ before, after }) if before.caseless_ascii_equals("Bearer") and after != "" and !after.contains(" ") => Token(after)
				_ => Refuse(Problem.new(Unauthenticated, "the Authorization header must be \"Bearer <token>\""))
			}
	}

	## The 401 of a route that needs a token, when the request has none (R-AP21, R-AP6, R-AP10).
	## `detail`: `the request has no Authorization header: this route needs a GitHub OIDC token`.
	missing_token : Problem
	missing_token = Problem.new(Unauthenticated, "the request has no Authorization header: this route needs a GitHub OIDC token")

	## base64url with no padding (RFC 7515 2, RFC 4648 5): the letters `A-Z a-z 0-9 - _`. A `+`, `/`, `=`, any other character,
	## or a length that leaves 1 character in the last group (length % 4 == 1) is `Err(BadBase64)`. The empty text is `Ok([])`.
	base64url : Str -> Try(List(U8), [BadBase64])
	base64url = |text| {
		bytes = text.to_utf8()
		if bytes.len() % 4 == 1 {
			return Err(BadBase64)
		}
		var $out = []
		var $acc = 0.U32
		var $bits = 0.U8
		for b in bytes {
			v = b64_value(b)?
			$acc = $acc.shl_wrap(6).bitwise_or(v).bitwise_and(0xFFFF)
			$bits = $bits + 6
			if $bits >= 8 {
				$bits = $bits - 8
				$out = $out.append($acc.shr_zf_wrap($bits).bitwise_and(0xFF).to_u8_wrap())
			}
		}
		Ok($out)
	}

	b64_value : U8 -> Try(U32, [BadBase64])
	b64_value = |b| {
		if b >= 65 and b <= 90 {
			Ok((b - 65).to_u32())
		} else if b >= 97 and b <= 122 {
			Ok((b - 71).to_u32())
		} else if b >= 48 and b <= 57 {
			Ok((b + 4).to_u32())
		} else if b == 45 {
			Ok(62)
		} else if b == 95 {
			Ok(63)
		} else {
			Err(BadBase64)
		}
	}

	## Split a compact JWS (RFC 7515 7.1) into its parts, and read the header and the claims (R-TP3 row 1, before the signature).
	## Each fault is 401 `Unauthenticated`:
	## - not 3 parts with `.`, a part that is not base64url, a header or claims that are not a JSON object of the right types: `the token is not a valid JWT`
	## - the header `alg` is not `RS256`: `the token alg is "<alg>", expected "RS256"` (also for `none` and `HS256`; a missing `alg` is `the token alg is missing`)
	## - the header has no `kid`: `the token kid is missing`
	parse : Str -> Try(Oidc.Jwt, Problem)
	parse = |token| {
		not_jwt = Problem.new(Unauthenticated, "the token is not a valid JWT")
		match token.split_on(".") {
			[h, p, s] => {
				hdr_bytes = base64url(h) ? |_| not_jwt
				claim_bytes = base64url(p) ? |_| not_jwt
				signature = base64url(s) ? |_| not_jwt
				if signature.is_empty() {
					return Err(not_jwt)
				}
				hdr_text = Str.from_utf8(hdr_bytes) ? |_| not_jwt
				claim_text = Str.from_utf8(claim_bytes) ? |_| not_jwt
				header : Try({ alg : Try(Str, [Missing]), kid : Try(Str, [Missing]) }, _)
				header = Json.parse(hdr_text)
				hd = header ? |_| not_jwt
				claims_try : Try(Oidc.Claims, _)
				claims_try = Json.parse(claim_text)
				claims = claims_try ? |_| not_jwt
				match hd.alg {
					Err(Missing) => Err(Problem.new(Unauthenticated, "the token alg is missing"))
					Ok(alg) if alg != "RS256" => Err(Problem.new(Unauthenticated, "the token alg is \"${alg}\", expected \"RS256\""))
					Ok(_) =>
						match hd.kid {
							Err(Missing) => Err(Problem.new(Unauthenticated, "the token kid is missing"))
							Ok(kid) => Ok({ kid, claims, signed: "${h}.${p}".to_utf8(), signature })
						}
				}
			}
			_ => Err(not_jwt)
		}
	}

	## The keys of a JWKS text (RFC 7517 5: `{"keys": [...]}`). A key with `kty` other than `RSA`, or with no `kid`, `n` or `e`, is left out.
	## Other members (`alg`, `use`, `x5c`, ...) are ignored. A text that is not JSON, or has no `keys` list, is `Err(BadJwks)`.
	parse_jwks : Str -> Try(List(Oidc.Key), [BadJwks])
	parse_jwks = |text| {
		parsed : Try({ keys : List({ kty : Try(Str, [Missing]), kid : Try(Str, [Missing]), n : Try(Str, [Missing]), e : Try(Str, [Missing]) }) }, _)
		parsed = Json.parse(text)
		match parsed {
			Err(_) => Err(BadJwks)
			Ok(doc) =>
				Ok(doc.keys.keep_oks(|k| {
					match (k.kty, k.kid, k.n, k.e) {
						(Ok("RSA"), Ok(kid), Ok(n), Ok(e)) => Ok({ kid, n, e })
						_ => Err(Skip)
					}
				}))
		}
	}

	## The key with this `kid`, the first one when there are more.
	find_key : List(Oidc.Key), Str -> Try(Oidc.Key, [UnknownKid])
	find_key = |keys, kid| keys.find_first(|k| k.kid == kid).map_err(|_| UnknownKid)

	## The JWK text of a public key for `WebCrypto.Jwk`: a JSON object with `kty` = `RSA`, `n` and `e`, and no other member.
	## The order of the members is free.
	jwk_text : Oidc.Key -> Str
	jwk_text = |key| Json.to_str({ kty: "RSA", n: key.n, e: key.e })

	## The 401 of a token whose `kid` is not in the JWKS, also after the one read again (`worker/Auth.roc`).
	## `detail`: `the token kid "<kid>" is not in the GitHub JWKS`.
	unknown_kid : Str -> Problem
	unknown_kid = |kid| Problem.new(Unauthenticated, "the token kid \"${kid}\" is not in the GitHub JWKS")

	## The 502 of a JWKS read that fails (R-AP21 `upstream`: a read from GitHub failed): a status other than 200, no answer, or a body that `parse_jwks` refuses.
	jwks_status : U16 -> Problem
	jwks_status = |status| Problem.new(Upstream, "the GitHub JWKS read failed with status ${status.to_str()}")

	jwks_no_answer : Problem
	jwks_no_answer = Problem.new(Upstream, "the GitHub JWKS read failed: no answer")

	jwks_bad : Problem
	jwks_bad = Problem.new(Upstream, "the GitHub JWKS is not a valid JWKS")

	## The 401 of a signature that `WebCrypto.verify!` refuses. `detail`: `the token signature is not valid`.
	bad_signature : Problem
	bad_signature = Problem.new(Unauthenticated, "the token signature is not valid")

	## R-TP3 rows 1 (`iss`), 2 (`aud`) and 3 (`exp`, `nbf`), in this order, after the signature. Each fault is 401 `Unauthenticated`.
	## Row 2: `aud` is equal to `audience` (the setting `AUDIENCE`, no trailing `/`): an exact compare, so `<audience>/` fails.
	## Row 3 (RFC 7519 4.1.4 and 4.1.5, with the leeway of 60 s): with `now` = `now_ms // 1000` (whole seconds, rounded down), the token is refused
	## when `now_ms >= (exp + 60) * 1000`, or when `now_ms < (nbf - 60) * 1000`. Row 3 checks `exp` first, then `nbf`.
	## `detail` of row 3: `token claim exp is <exp>: the token expired (now is <now>, leeway 60 s)`
	## and `token claim nbf is <nbf>: the token is not valid yet (now is <now>, leeway 60 s)`.
	check_token : Oidc.Claims, { audience : Str, now_ms : U64 } -> Try({}, Problem)
	check_token = |claims, ctx| {
		_ = same("iss", claims.iss, issuer, Unauthenticated)?
		_ = same("aud", claims.aud, ctx.audience, Unauthenticated)?
		now_s = ctx.now_ms // 1000
		exp = present("exp", claims.exp, Unauthenticated)?
		if ctx.now_ms >= (exp + leeway_s) * 1000 {
			return Err(Problem.new(Unauthenticated, "token claim exp is ${exp.to_str()}: the token expired (now is ${now_s.to_str()}, leeway 60 s)"))
		}
		nbf = present("nbf", claims.nbf, Unauthenticated)?
		if nbf > leeway_s and ctx.now_ms < (nbf - leeway_s) * 1000 {
			return Err(Problem.new(Unauthenticated, "token claim nbf is ${nbf.to_str()}: the token is not valid yet (now is ${now_s.to_str()}, leeway 60 s)"))
		}
		Ok({})
	}

	present : Str, Try(a, [Missing]), Problem.Kind -> Try(a, Problem)
	present = |name, value, kind| value.map_err(|_| Problem.new(kind, "token claim ${name} is missing"))

	same : Str, Try(Str, [Missing]), Str, Problem.Kind -> Try({}, Problem)
	same = |name, value, want, kind| {
		got = present(name, value, kind)?
		if got == want Ok({}) else Err(Problem.new(kind, "token claim ${name} is \"${got}\", expected \"${want}\""))
	}

	one_of : Str, Try(Str, [Missing]), List(Str), Str -> Try({}, Problem)
	one_of = |name, value, allowed, words| {
		got = present(name, value, Forbidden)?
		if allowed.contains(got) Ok({}) else Err(Problem.new(Forbidden, "token claim ${name} is \"${got}\", expected ${words}"))
	}

	## R-TP7: a compat bot token, after `check_token`. Each fault is 403 `Forbidden`. The order: `repository_id`, `workflow_ref`, `event_name`.
	## `repository_id` is equal to `BOT_REPOSITORY_ID`, `workflow_ref` is equal to `BOT_WORKFLOW_REF` (exact compares),
	## `event_name` is `schedule` or `workflow_dispatch`
	## (`detail`: `token claim event_name is "<value>", expected "schedule" or "workflow_dispatch"`).
	check_bot : Oidc.Claims, { repository_id : Str, workflow_ref : Str } -> Try({}, Problem)
	check_bot = |claims, bot| {
		_ = same("repository_id", claims.repository_id, bot.repository_id, Forbidden)?
		_ = same("workflow_ref", claims.workflow_ref, bot.workflow_ref, Forbidden)?
		one_of("event_name", claims.event_name, ["schedule", "workflow_dispatch"], "\"schedule\" or \"workflow_dispatch\"")
	}

	## R-TP3 rows 4, 6, 7 and 8 of a publish token, in this order, after `check_token`. Each fault is 403 `Forbidden`.
	## The caller (slice 114) gives the parts of the asset URL: `host`, `owner_repo` (`owner/repo`) and `tag`.
	## Row 4: `host` is `github.com` (`detail`: `token claim repository: the asset URL host is "<host>", expected "github.com"`),
	## and `repository` is equal to `owner_repo`, ASCII case-insensitive.
	## Row 6: `repository_visibility` is `public`. Row 7: `ref_type` is `tag`, then `ref` is `refs/tags/<tag>` (exact compare).
	## Row 8: `event_name` is `release`, `push` or `workflow_dispatch`
	## (`detail`: `token claim event_name is "<value>", expected "release", "push" or "workflow_dispatch"`).
	## Row 5 is `binding_ok`: it needs the `repos` row (D1).
	check_publish : Oidc.Claims, { host : Str, owner_repo : Str, tag : Str } -> Try({}, Problem)
	check_publish = |claims, asset| {
		if asset.host != "github.com" {
			return Err(Problem.new(Forbidden, "token claim repository: the asset URL host is \"${asset.host}\", expected \"github.com\""))
		}
		repo = present("repository", claims.repository, Forbidden)?
		if !repo.caseless_ascii_equals(asset.owner_repo) {
			return Err(Problem.new(Forbidden, "token claim repository is \"${repo}\", expected \"${asset.owner_repo}\""))
		}
		_ = same("repository_visibility", claims.repository_visibility, "public", Forbidden)?
		_ = same("ref_type", claims.ref_type, "tag", Forbidden)?
		_ = same("ref", claims.ref, "refs/tags/${asset.tag}", Forbidden)?
		one_of("event_name", claims.event_name, ["release", "push", "workflow_dispatch"], "\"release\", \"push\" or \"workflow_dispatch\"")
	}

	## R-TP3 row 5: with no `repos` row, `Bool.True`. With a row, `Bool.True` when the claim `repository_id` or the claim `repository_owner_id`
	## is equal to the id of the row. A missing claim is equal to no id. The problem of a `Bool.False` is open (question Q108-3), so this
	## function gives no `Problem`: slices 113 and 114 map it.
	binding_ok : Oidc.Claims, Try({ repository_id : Str, repository_owner_id : Str }, [NoRow]) -> Bool
	binding_ok = |claims, row| match row {
		Err(NoRow) => Bool.True
		Ok(r) => (claims.repository_id == Ok(r.repository_id)) or (claims.repository_owner_id == Ok(r.repository_owner_id))
	}
}
