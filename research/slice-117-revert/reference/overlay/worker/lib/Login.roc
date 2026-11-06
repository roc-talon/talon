## PRIVATE REFERENCE of slice 117 (research/slice-117-revert/reference/). The code agent does not read it (TW18).
import records.Account
import jwt.Jwt
import jwt.Jwk
import Compat
import Hints
import Oidc
import Problem

Login :: [].{

	token_ttl_ms : U64
	token_ttl_ms = 2_592_000_000

	user_url : Str
	user_url = "https://api.github.com/user"

	limit_binding : Str
	limit_binding = "RL_LOGIN"

	algs : List(Jwt.Alg)
	algs = [EdDSA]

	token_max_bytes : U64
	token_max_bytes = 512

	too_large : Compat.Reject
	too_large = TooLarge(Problem.new(TooLarge, "the body of the login request is larger than its limit of 262144"), { field: "body", limit: 262_144 })

	invalid : Str -> Compat.Reject
	invalid = |why| Bad(Problem.new(BadRequest, "the login request body is not valid: ${why}"))

	Wire : { github_token : Try(Str, [Missing]) }

	login_token : List(U8) -> Try(Str, Compat.Reject)
	login_token = |body| {
		if body.len() > Compat.body_limit {
			return Err(too_large)
		}
		text = Str.from_utf8(body).map_err(|_| invalid("it is not UTF-8"))?
		wire : Try(Login.Wire, _)
		wire = Json.parse(text)
		parsed = wire.map_err(|_| invalid("it is not a JSON object with the member github_token"))?
		token = parsed.github_token.map_err(|_| invalid("github_token is missing"))?
		bytes = token.to_utf8()
		if bytes.is_empty() {
			Err(invalid("github_token is empty"))
		} else if bytes.len() > token_max_bytes {
			Err(invalid("github_token is longer than 512 bytes"))
		} else if !bytes.all(|b| b >= 33 and b <= 126) {
			Err(invalid("github_token has a byte that is not allowed in a token"))
		} else {
			Ok(token)
		}
	}

	GithubUser : { id : U64, login : Str }

	github_user : U16, Str -> Try(Login.GithubUser, Problem)
	github_user = |status, body| {
		if status == 401 {
			Err(user_refused)
		} else if status != 200 {
			Err(Problem.new(Upstream, "the GitHub user read failed with status ${status.to_str()}"))
		} else {
			not_user = Problem.new(Upstream, "the GitHub user read gave an answer that is not a user")
			parsed : Try(Login.GithubUser, _)
			parsed = Json.parse(body)
			user = parsed.map_err(|_| not_user)?
			if user.id == 0 or user.login.is_empty() { Err(not_user) } else { Ok(user) }
		}
	}

	user_refused : Problem
	user_refused = Problem.new(Unauthenticated, "GitHub refused the token")

	user_no_answer : Problem
	user_no_answer = Problem.new(Upstream, "the GitHub user read failed: no answer")

	rate_problem : Problem
	rate_problem = Problem.new(RateLimited, "too many login requests from this address: try again in a minute")

	missing_token : Problem
	missing_token = Problem.new(Unauthenticated, "the request has no Authorization header: this route needs a registry token")

	bad_signature : Problem
	bad_signature = Problem.new(Unauthenticated, "the token signature is not valid")

	no_account : Problem
	no_account = Problem.new(Unauthenticated, "the account of the token has no data in this registry: log in again")

	revoked_problem : Problem
	revoked_problem = Problem.new(Unauthenticated, "the token was issued before the last revoke of the tokens of its account: log in again")

	not_good : Problem
	not_good = Problem.new(Unauthenticated, "the token is revoked or its account has no data in this registry: log in again")

	SigningKey : { kid : Str, public_json : Str }

	signing_key : Str -> Try(Login.SigningKey, [BadKey])
	signing_key = |text| {
		key = Jwk.parse(text) ? |_| BadKey
		kid = key.kid ? |Missing| BadKey
		if kid.is_empty() {
			return Err(BadKey)
		}
		match key.material {
			Okp({ crv: Ed25519, x: _ }) => Ok({ kid, public_json: Jwk.to_public_json(key) })
			_ => Err(BadKey)
		}
	}

	seconds_text : U64 -> Str
	seconds_text = |ms| {
		frac = (ms % 1000).to_str()
		pad = Str.repeat("0", 3 - frac.count_utf8_bytes())
		"${(ms // 1000).to_str()}.${pad}${frac}"
	}

	signing_input : { kid : Str, sub : U64, now_ms : U64, audience : Str } -> Str
	signing_input = |x| {
		header = "{\"alg\":\"EdDSA\",\"kid\":${Json.to_str(x.kid)},\"typ\":\"JWT\"}"
		payload = "{\"aud\":${Json.to_str(x.audience)},\"exp\":${seconds_text(x.now_ms + token_ttl_ms)},\"iat\":${seconds_text(x.now_ms)},\"iss\":${Json.to_str(x.audience)},\"sub\":\"${x.sub.to_str()}\"}"
		"${b64u(header.to_utf8())}.${b64u(payload.to_utf8())}"
	}

	token_text : Str, List(U8) -> Str
	token_text = |input, signature| "${input}.${b64u(signature)}"

	expires_at : U64 -> U64
	expires_at = |now_ms| now_ms + token_ttl_ms

	alphabet : List(U8)
	alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".to_utf8()

	b64u : List(U8) -> Str
	b64u = |bytes| {
		var $out = []
		var $i = 0
		n = bytes.len()
		while $i < n {
			b0 = bytes.get($i) ?? 0
			b1 = bytes.get($i + 1) ?? 0
			b2 = bytes.get($i + 2) ?? 0
			word : U32
			word = b0.to_u32() * 65536 + b1.to_u32() * 256 + b2.to_u32()
			sextet = |div| alphabet.get((word // div % 64).to_u64()) ?? 65
			$out = $out.append(sextet(262144)).append(sextet(4096))
			if $i + 1 < n {
				$out = $out.append(sextet(64))
			}
			if $i + 2 < n {
				$out = $out.append(sextet(1))
			}
			$i = $i + 3
		}
		Str.from_utf8($out) ?? ""
	}

	Decoded : { claims : Jwt.Claims, signing_input : List(U8), signature : List(U8) }

	decode : Str, Str -> Try(Login.Decoded, Problem)
	decode = |text, kid| {
		token = Jwt.decode(text, Jwt.Options.{ algs }) ? |err| jwt_problem(err, "")
		got = token.header.kid ? |Missing| Problem.new(Unauthenticated, "the token kid is missing")
		if got != kid {
			return Err(Problem.new(Unauthenticated, "the token kid \"${got}\" is not the key of this registry"))
		}
		Ok({ claims: token.claims, signing_input: token.signing_input, signature: token.signature })
	}

	jwt_problem : Jwt.Error, Str -> Problem
	jwt_problem = |err, audience| {
		detail = match err {
			AlgMissing => "the token alg is missing"
			AlgNone => "the token alg is \"none\", expected \"EdDSA\""
			AlgNotAllowed(alg) => "the token alg is \"${alg}\", expected \"EdDSA\""
			WrongIssuer(iss) => "token claim iss is \"${iss}\", expected \"${audience}\""
			_ => Oidc.jwt_detail(err, audience)
		}
		Problem.new(Unauthenticated, detail)
	}

	Verified : { account : U64, iat_ms : U64 }

	check : Login.Decoded, { audience : Str, now_ms : U64 } -> Try(Login.Verified, Problem)
	check = |decoded, x| {
		rules = Jwt.Rules.{ now_ms: x.now_ms, leeway_s: 60, aud: OneOf([x.audience]), iss: OneOf([x.audience]), require: [Exp, Iat, Sub] }
		Jwt.check(decoded.claims, rules) ? |err| jwt_problem(err, x.audience)
		sub = decoded.claims.sub ? |Missing| Problem.new(Unauthenticated, "token claim sub is missing")
		not_id = Problem.new(Unauthenticated, "token claim sub is \"${sub}\", expected a GitHub user id")
		bytes = sub.to_utf8()
		account = if !bytes.is_empty() and bytes.all(|b| b >= '0' and b <= '9') { U64.from_str(sub) ? |_| not_id } else { return Err(not_id) }
		if account == 0 {
			return Err(not_id)
		}
		iat = decoded.claims.iat ? |Missing| Problem.new(Unauthenticated, "token claim iat is missing")
		iat_ms = (iat * 1000).floor_to_i128().to_u64_wrap()
		Ok({ account, iat_ms })
	}

	revoked : { iat_ms : U64, tokens_after : U64 } -> Bool
	revoked = |x| x.iat_ms < x.tokens_after

	delete_proof : { authorization : Try(Str, [NotFound]), contributor : Try(Str, [NotFound]) } -> [Account(Str), Machine(Str), Refuse(Problem)]
	delete_proof = |x| match x.authorization {
		Ok(_) => match Oidc.bearer(x.authorization) {
			Token(text) => Account(text)
			Refuse(problem) => Refuse(problem)
			NoToken => Refuse(missing_token)
		}
		Err(NotFound) => match x.contributor {
			Ok(id) => match Hints.machine_id(id) {
				Ok(found) => Machine(found)
				Err(problem) => Refuse(problem)
			}
			Err(NotFound) => Refuse(Problem.new(BadRequest, "the request needs the header Authorization (an account) or the header Talon-Contributor (one machine)"))
		}
	}

	account_sql : () -> Str
	account_sql = || "INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (CAST(?1 AS INTEGER), ?2, ?3, ?3, ?3) ON CONFLICT (contributor) DO UPDATE SET login = excluded.login, last_time = excluded.last_time"

	machine_sqls : () -> List(Str)
	machine_sqls = || [
		"INSERT INTO links (machine, contributor, time) VALUES (CAST(?2 AS INTEGER), CAST(?1 AS INTEGER), ?3) ON CONFLICT (machine) DO UPDATE SET contributor = excluded.contributor, time = excluded.time",
		"UPDATE OR IGNORE contributions SET contributor = CAST(?1 AS INTEGER) WHERE contributor = CAST(?2 AS INTEGER)",
		"DELETE FROM contributions WHERE contributor = CAST(?2 AS INTEGER)",
		"INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time) SELECT CAST(?1 AS INTEGER), counted, first, agreed, disagreed, unconfirmed, first_time, last_time FROM contributor_totals WHERE contributor = CAST(?2 AS INTEGER) ON CONFLICT (contributor) DO UPDATE SET counted = counted + excluded.counted, first = first + excluded.first, agreed = agreed + excluded.agreed, disagreed = disagreed + excluded.disagreed, unconfirmed = unconfirmed + excluded.unconfirmed, first_time = MIN(first_time, excluded.first_time), last_time = MAX(last_time, excluded.last_time)",
		"DELETE FROM contributor_totals WHERE contributor = CAST(?2 AS INTEGER)",
	]

	AccountRow : { login : Str, tokens_after : U64 }

	account_row_sql : () -> Str
	account_row_sql = || "SELECT login, tokens_after FROM contributors WHERE contributor = CAST(?1 AS INTEGER)"

	TrackerRow : {
		machines : U64,
		counted : U64,
		first : U64,
		agreed : U64,
		disagreed : U64,
		unconfirmed : U64,
		first_time : Try(U64, [Missing]),
		last_time : Try(U64, [Missing]),
	}

	tracker_sql : () -> Str
	tracker_sql = || {
		pair = |a| "${a}.artifact = p.artifact AND ${a}.nightly = p.nightly AND ${a}.target = p.target"
		"SELECT (SELECT COUNT(*) FROM links WHERE contributor = CAST(?1 AS INTEGER)) AS machines, l.counted + COALESCE(t.counted, 0) AS counted, l.first + COALESCE(t.first, 0) AS first, l.agreed + COALESCE(t.agreed, 0) AS agreed, l.disagreed + COALESCE(t.disagreed, 0) AS disagreed, l.unconfirmed + COALESCE(t.unconfirmed, 0) AS unconfirmed, COALESCE(MIN(l.first_time, t.first_time), l.first_time, t.first_time) AS first_time, COALESCE(MAX(l.last_time, t.last_time), l.last_time, t.last_time) AS last_time FROM (SELECT COUNT(*) AS counted, COALESCE(SUM(NOT EXISTS (SELECT 1 FROM compat c WHERE ${pair("c")} AND c.time < p.time) AND NOT EXISTS (SELECT 1 FROM contributions o WHERE ${pair("o")} AND o.contributor <> p.contributor AND (o.time < p.time OR (o.time = p.time AND o.contributor < p.contributor)))), 0) AS first, COALESCE(SUM(EXISTS (SELECT 1 FROM compat c WHERE ${pair("c")} AND c.source = 0 AND c.result = p.result)), 0) AS agreed, COALESCE(SUM(EXISTS (SELECT 1 FROM compat c WHERE ${pair("c")} AND c.source = 0 AND c.result <> p.result)), 0) AS disagreed, COALESCE(SUM(NOT EXISTS (SELECT 1 FROM compat c WHERE ${pair("c")} AND c.source = 0)), 0) AS unconfirmed, MIN(p.time) AS first_time, MAX(p.time) AS last_time FROM contributions p WHERE p.contributor = CAST(?1 AS INTEGER)) l LEFT JOIN contributor_totals t ON t.contributor = CAST(?1 AS INTEGER)"
	}

	tracker_of : Login.GithubUser, Login.TrackerRow -> Account.Tracker
	tracker_of = |who, row| {
		account: { id: who.id, login: who.login },
		machines: row.machines,
		counted: row.counted,
		first: row.first,
		agreed: row.agreed,
		disagreed: row.disagreed,
		unconfirmed: row.unconfirmed,
		first_time: row.first_time.map_err(|_| None),
		last_time: row.last_time.map_err(|_| None),
	}

	revoke_sql : () -> Str
	revoke_sql = || "UPDATE contributors SET tokens_after = ?2 WHERE contributor = CAST(?1 AS INTEGER) AND tokens_after <= ?3 RETURNING 1 AS revoked"

	forget_account_sqls : () -> List(Str)
	forget_account_sqls = || {
		guard = "NOT EXISTS (SELECT 1 FROM contributors g WHERE g.contributor = CAST(?1 AS INTEGER) AND g.tokens_after > ?2)"
		[
			"SELECT 1 AS revoked FROM contributors WHERE contributor = CAST(?1 AS INTEGER) AND tokens_after > ?2",
			"DELETE FROM contributions WHERE contributor = CAST(?1 AS INTEGER) AND ${guard}",
			"DELETE FROM links WHERE contributor = CAST(?1 AS INTEGER) AND ${guard}",
			"DELETE FROM contributor_totals WHERE contributor = CAST(?1 AS INTEGER) AND ${guard}",
			"DELETE FROM contributors WHERE contributor = CAST(?1 AS INTEGER) AND ${guard}",
		]
	}

	forget_machine_sqls : () -> List(Str)
	forget_machine_sqls = || [
		"DELETE FROM contributions WHERE contributor = CAST(?1 AS INTEGER)",
		"DELETE FROM contributor_totals WHERE contributor = CAST(?1 AS INTEGER)",
		"DELETE FROM links WHERE machine = CAST(?1 AS INTEGER)",
	]
}
