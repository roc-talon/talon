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

	## The JWKS as the Worker keeps it (the value of the `Memo` in `worker/Auth.roc`): the keys and the time of the read (`Time.now_ms!`).
	## The fetch time, not the `Memo` expiry, decides when to read again (Q108-1, Q108-2, R-TP16), so the case clock of W2 can test it.
	Cached : { fetched_ms : U64, keys : List(Oidc.Key) }

	## The kept JWKS is read again when it is older than this (1 h, Q108-2).
	max_age_ms : U64
	max_age_ms = 3_600_000

	## An unknown `kid` reads the JWKS again only when the kept copy is older than this (60 s, Q108-1).
	reread_after_ms : U64
	reread_after_ms = 60_000

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
	## `Token(text)`: the header is `Bearer <text>` with a text that is not empty and has no space. One space after `Bearer`.
	## The scheme is compared with no case (RFC 9110 11.1, Q108-5): `bearer`, `BEARER` and `Bearer` are accepted.
	## Any other value is `Refuse(401)` with the `detail` `the Authorization header must be "Bearer <token>"`: never an ingest (R-AP26).
	bearer : Try(Str, [NotFound]) -> [Token(Str), NoToken, Refuse(Problem)]
	bearer = |header| match header {
		Err(NotFound) => NoToken
		Ok(text) => match text.split_on(" ") {
			[scheme, token] if scheme.caseless_ascii_equals("bearer") and !token.is_empty() => Token(token)
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
			Err(BadBase64)
		} else {
			values = bytes.map_try(base64_value)?
			Ok(values.chunks_of(4).join_map(base64_group))
		}
	}

	## The 6-bit value of one base64url letter.
	base64_value : U8 -> Try(U8, [BadBase64])
	base64_value = |c| {
		if c >= 65 and c <= 90 {
			Ok(c - 65)
		} else if c >= 97 and c <= 122 {
			Ok(c - 71)
		} else if c >= 48 and c <= 57 {
			Ok(c + 4)
		} else if c == 45 {
			Ok(62)
		} else if c == 95 {
			Ok(63)
		} else {
			Err(BadBase64)
		}
	}

	## The bytes of a group of 2, 3 or 4 values (6 bits each). Each value is less than 64, so no step overflows a U8.
	base64_group : List(U8) -> List(U8)
	base64_group = |group| match group {
		[a, b, c, d] => [a * 4 + b // 16, (b % 16) * 16 + c // 4, (c % 4) * 64 + d]
		[a, b, c] => [a * 4 + b // 16, (b % 16) * 16 + c // 4]
		[a, b] => [a * 4 + b // 16]
		_ => []
	}

	## Split a compact JWS (RFC 7515 7.1) into its parts, and read the header and the claims (R-TP3 row 1, before the signature).
	## Each fault is 401 `Unauthenticated`:
	## - not 3 parts with `.`, a part that is not base64url, a header or claims that are not a JSON object of the right types: `the token is not a valid JWT`
	## - the header `alg` is not `RS256`: `the token alg is "<alg>", expected "RS256"` (also for `none` and `HS256`; a missing `alg` is `the token alg is missing`)
	## - the header has no `kid`: `the token kid is missing`
	parse : Str -> Try(Oidc.Jwt, Problem)
	parse = |token| match token.split_on(".") {
		[header, payload, signature] => parse_parts(header, payload, signature)
		_ => Err(not_jwt)
	}

	not_jwt : Problem
	not_jwt = Problem.new(Unauthenticated, "the token is not a valid JWT")

	## The JOSE header members that the Worker reads.
	Header : { alg : Try(Str, [Missing]), kid : Try(Str, [Missing]) }

	## The three parts of a compact JWS: the form, then `alg`, then `kid`, then the claims.
	parse_parts : Str, Str, Str -> Try(Oidc.Jwt, Problem)
	parse_parts = |header_text, payload_text, signature_text| {
		header_json = decode_text(header_text)?
		claims_json = decode_text(payload_text)?
		signature = base64url(signature_text) ? |_| not_jwt
		if signature.is_empty() {
			Err(not_jwt)
		} else {
			header : Oidc.Header
			header = Json.parse(header_json) ? |_| not_jwt
			match header.alg {
				Err(Missing) => Err(Problem.new(Unauthenticated, "the token alg is missing"))
				Ok(alg) if alg != "RS256" => Err(Problem.new(Unauthenticated, "the token alg is \"${alg}\", expected \"RS256\""))
				Ok(_) => match header.kid {
					Err(Missing) => Err(Problem.new(Unauthenticated, "the token kid is missing"))
					Ok(kid) => {
						claims : Oidc.Claims
						claims = Json.parse(claims_json) ? |_| not_jwt
						Ok({ kid, claims, signed: "${header_text}.${payload_text}".to_utf8(), signature })
					}
				}
			}
		}
	}

	## The UTF-8 text of one base64url part.
	decode_text : Str -> Try(Str, Problem)
	decode_text = |part| {
		bytes = base64url(part) ? |_| not_jwt
		Str.from_utf8(bytes).map_err(|_| not_jwt)
	}

	## The keys of a JWKS text (RFC 7517 5: `{"keys": [...]}`). A key with `kty` other than `RSA`, or with no `kid`, `n` or `e`, is left out.
	## Other members (`alg`, `use`, `x5c`, ...) are ignored. A text that is not JSON, or has no `keys` list, is `Err(BadJwks)`.
	parse_jwks : Str -> Try(List(Oidc.Key), [BadJwks])
	parse_jwks = |text| {
		jwks : Try({ keys : List(Oidc.Jwk) }, _)
		jwks = Json.parse(text)
		match jwks {
			Ok(set) => Ok(set.keys.keep_oks(rsa_key))
			Err(_) => Err(BadJwks)
		}
	}

	## One member of `keys` as sent. Only the members that `parse_jwks` reads.
	Jwk : { kty : Try(Str, [Missing]), kid : Try(Str, [Missing]), n : Try(Str, [Missing]), e : Try(Str, [Missing]) }

	## An RSA key with `kid`, `n` and `e`, else `Err(NotRsa)`.
	rsa_key : Oidc.Jwk -> Try(Oidc.Key, [NotRsa])
	rsa_key = |jwk| match (jwk.kty, jwk.kid, jwk.n, jwk.e) {
		(Ok("RSA"), Ok(kid), Ok(n), Ok(e)) => Ok({ kid, n, e })
		_ => Err(NotRsa)
	}

	## The key with this `kid`, the first one when there are more.
	find_key : List(Oidc.Key), Str -> Try(Oidc.Key, [UnknownKid])
	find_key = |keys, kid| match keys.find_first(|key| key.kid == kid) {
		Ok(key) => Ok(key)
		Err(NotFound) => Err(UnknownKid)
	}

	## The key step of R-TP3 row 1 (Q108-1, Q108-2, R-TP16). `age` is `now_ms - cached.fetched_ms`, or 0 when `now_ms` is before the fetch time.
	## 1. `age > max_age_ms`: `Reload` (also when the `kid` is there).
	## 2. The `kid` is in `cached.keys`: `Use(key)` (the first key with that `kid`).
	## 3. `age > reread_after_ms`: `Reload`.
	## 4. Else `Refuse(unknown_kid(kid))`: 401 with no read.
	## After a `Reload` the caller reads the JWKS, keeps it with the new time, and calls `key_step` once more. The age is then 0, so an unknown `kid`
	## gets `Refuse`: one read at most for each request.
	key_step : Oidc.Cached, Str, U64 -> [Use(Oidc.Key), Reload, Refuse(Problem)]
	key_step = |cached, kid, now_ms| {
		age = now_ms.minus_saturated(cached.fetched_ms)
		if age > max_age_ms {
			Reload
		} else {
			match find_key(cached.keys, kid) {
				Ok(key) => Use(key)
				Err(UnknownKid) => if (age > reread_after_ms) Reload else Refuse(unknown_kid(kid))
			}
		}
	}

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
		claim_is(Unauthenticated, "iss", claims.iss, issuer)?
		claim_is(Unauthenticated, "aud", claims.aud, ctx.audience)?
		now_s = ctx.now_ms // 1000
		exp = claims.exp ? |Missing| missing(Unauthenticated, "exp")
		if ctx.now_ms >= exp.plus_saturated(leeway_s).times_saturated(1000) {
			Err(Problem.new(Unauthenticated, "token claim exp is ${exp.to_str()}: the token expired (now is ${now_s.to_str()}, leeway 60 s)"))
		} else {
			nbf = claims.nbf ? |Missing| missing(Unauthenticated, "nbf")
			if ctx.now_ms < nbf.minus_saturated(leeway_s).times_saturated(1000) {
				Err(Problem.new(Unauthenticated, "token claim nbf is ${nbf.to_str()}: the token is not valid yet (now is ${now_s.to_str()}, leeway 60 s)"))
			} else {
				Ok({})
			}
		}
	}

	## The problem of a claim that the token does not have.
	missing : Problem.Kind, Str -> Problem
	missing = |kind, name| Problem.new(kind, "token claim ${name} is missing")

	## A claim that must be equal to `want` (an exact compare).
	claim_is : Problem.Kind, Str, Try(Str, [Missing]), Str -> Try({}, Problem)
	claim_is = |kind, name, claim, want| claim_in(kind, name, claim, [want], "\"${want}\"")

	## A claim that must be one of `wants`. `expected` is the text of `wants` in the `detail`.
	claim_in : Problem.Kind, Str, Try(Str, [Missing]), List(Str), Str -> Try({}, Problem)
	claim_in = |kind, name, claim, wants, expected| match claim {
		Err(Missing) => Err(missing(kind, name))
		Ok(value) => if (wants.contains(value)) Ok({}) else Err(Problem.new(kind, "token claim ${name} is \"${value}\", expected ${expected}"))
	}

	## R-TP7: a compat bot token, after `check_token`. Each fault is 403 `Forbidden`. The order: `repository_id`, `workflow_ref`, `event_name`.
	## `repository_id` is equal to `BOT_REPOSITORY_ID`, `workflow_ref` is equal to `BOT_WORKFLOW_REF` (exact compares),
	## `event_name` is `schedule` or `workflow_dispatch`
	## (`detail`: `token claim event_name is "<value>", expected "schedule" or "workflow_dispatch"`).
	check_bot : Oidc.Claims, { repository_id : Str, workflow_ref : Str } -> Try({}, Problem)
	check_bot = |claims, bot| {
		claim_is(Forbidden, "repository_id", claims.repository_id, bot.repository_id)?
		claim_is(Forbidden, "workflow_ref", claims.workflow_ref, bot.workflow_ref)?
		claim_in(Forbidden, "event_name", claims.event_name, ["schedule", "workflow_dispatch"], "\"schedule\" or \"workflow_dispatch\"")
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
			Err(Problem.new(Forbidden, "token claim repository: the asset URL host is \"${asset.host}\", expected \"github.com\""))
		} else {
			repository = claims.repository ? |Missing| missing(Forbidden, "repository")
			if !repository.caseless_ascii_equals(asset.owner_repo) {
				Err(Problem.new(Forbidden, "token claim repository is \"${repository}\", expected \"${asset.owner_repo}\""))
			} else {
				claim_is(Forbidden, "repository_visibility", claims.repository_visibility, "public")?
				claim_is(Forbidden, "ref_type", claims.ref_type, "tag")?
				claim_is(Forbidden, "ref", claims.ref, "refs/tags/${asset.tag}")?
				claim_in(Forbidden, "event_name", claims.event_name, ["release", "push", "workflow_dispatch"], "\"release\", \"push\" or \"workflow_dispatch\"")
			}
		}
	}

	## R-TP3 row 5: with no `repos` row, `Bool.True`. With a row, `Bool.True` when the claim `repository_id` or the claim `repository_owner_id`
	## is equal to the id of the row. A missing claim is equal to no id. The problem of a `Bool.False` is open (question Q108-3), so this
	## function gives no `Problem`: slices 113 and 114 map it.
	binding_ok : Oidc.Claims, Try({ repository_id : Str, repository_owner_id : Str }, [NoRow]) -> Bool
	binding_ok = |claims, row| match row {
		Err(NoRow) => Bool.True
		Ok(ids) => (claims.repository_id == Ok(ids.repository_id)) or (claims.repository_owner_id == Ok(ids.repository_owner_id))
	}
}
