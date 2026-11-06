## PRIVATE REFERENCE of slice 117 (research/slice-117-revert/reference/). The code agent does not read it (TW18).
import pf.Request
import pf.Response
import pf.RateLimit
import pf.D1
import pf.Sql
import pf.Time
import pf.Http
import pf.Env
import pf.WebCrypto
import records.Account
import lib.Client
import lib.Compat
import lib.Hints
import lib.Login
import lib.Oidc
import lib.Problem
import ReadRoutes
import jwt.Jwk

LoginRoutes :: [].{

	db = D1.binding("DB")

	limiter = RateLimit.binding("RL_LOGIN")

	json_answer : U16, Str -> Response
	json_answer = |status, body| Response.from_bytes(status, "application/json", body.to_utf8()).with_header("cache-control", "no-store")

	no_content : Response
	no_content = Response.from_status(204).with_header("cache-control", "no-store")

	all = |result| result.all().map_err(|e| Fault(Str.inspect(e)))

	fault = |e| Fault(Str.inspect(e))

	## The rate limit: `Ok({})` or the 429 answer.
	limit! : Request => Try({}, [Limited, Fault(Str)])
	limit! = |req| match limiter.limit!(Client.rate_key(req.header("cf-connecting-ip"))) {
		Ok({}) => Ok({})
		Err(RateLimited) => Err(Limited)
		Err(Infra(e)) => Err(Fault(Str.inspect(e)))
	}

	limited_response : () -> Response
	limited_response = || Response.from_bytes(429, "application/problem+json", Login.rate_problem.to_json().to_utf8()).with_header("retry-after", "60")

	setting! : Str => Try(Str, ReadRoutes.Error)
	setting! = |name| Env.var!(name).map_err(fault)

	key! : () => Try({ kid : Str, public_json : Str, secret : Str }, ReadRoutes.Error)
	key! = || {
		secret = Env.secret!("TOKEN_KEY").map_err(fault)?
		text = secret.reveal()
		key = Login.signing_key(text).map_err(|_| Fault("TOKEN_KEY is not an Ed25519 key"))?
		Ok({ kid: key.kid, public_json: key.public_json, secret: text })
	}

	machine! : Str => Try(I64, ReadRoutes.Error)
	machine! = |hex| {
		secret = Env.secret!("CONTRIBUTOR_KEY").map_err(fault)?
		Ok(Hints.contributor_id(WebCrypto.hmac_sha256(secret.reveal().to_utf8(), Hints.hmac_message(hex))))
	}

	## The proof of an account route: the header, the form, the signature, the claims. No D1 call.
	proof! : Request => Try(Login.Verified, ReadRoutes.Error)
	proof! = |req| match Oidc.bearer(req.header("authorization")) {
		Token(text) => verified!(text)
		NoToken => Err(Refuse(Login.missing_token))
		Refuse(problem) => Err(Refuse(problem))
	}

	verified! : Str => Try(Login.Verified, ReadRoutes.Error)
	verified! = |text| {
		key = key!()?
		decoded = Login.decode(text, key.kid).map_err(|p| Refuse(p))?
		match WebCrypto.verify!({ alg: Ed25519, key: Jwk(key.public_json), signature: decoded.signature, data: decoded.signing_input }) {
			Ok({}) => {}
			Err(_) => return Err(Refuse(Login.bad_signature))
		}
		audience = setting!("AUDIENCE")?
		Login.check(decoded, { audience, now_ms: Time.now_ms!() }).map_err(|p| Refuse(p))
	}

	post_tokens! : Request => Try(Response, ReadRoutes.Error)
	post_tokens! = |req| {
		bytes = match req.bytes_with!({ max_bytes: Compat.body_limit }) {
			Ok(found) => found
			Err(TooLarge) => return too_large()
			Err(BodyErr(_)) => []
		}
		machine_hex = match req.header("talon-contributor") {
			Ok(text) => Ok(Hints.machine_id(text).map_err(|p| Refuse(p))?)
			Err(NotFound) => Err(None)
		}
		token = match Login.login_token(bytes) {
			Ok(t) => t
			Err(Bad(p)) => return Err(Refuse(p))
			Err(TooLarge(p, extra)) => return Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(p, extra).to_utf8()))
		}
		match limit!(req) {
			Ok({}) => {}
			Err(Limited) => return Ok(limited_response())
			Err(Fault(text)) => return Err(Fault(text))
		}
		user = fetch_user!(token)?
		now = Time.now_ms!()
		key = key!()?
		audience = setting!("AUDIENCE")?
		input = Login.signing_input({ kid: key.kid, sub: user.id, now_ms: now, audience })
		signature = WebCrypto.sign!({ alg: Ed25519, key: Jwk(key.secret), data: input.to_utf8() }).map_err(fault)?
		id = user.id.to_str()
		stmts = match machine_hex {
			Err(None) => [Sql.stmt(Login.account_sql(), (id, user.login, now))]
			Ok(hex) => {
				machine = machine!(hex)?.to_str()
				sqls = Login.machine_sqls()
				pick = |i| sqls.get(i) ?? ""
				[
					Sql.stmt(Login.account_sql(), (id, user.login, now)),
					Sql.stmt(pick(0), (id, machine, now)),
					Sql.stmt(pick(1), (id, machine)),
					Sql.stmt(pick(2), (id, machine)),
					Sql.stmt(pick(3), (id, machine)),
					Sql.stmt(pick(4), (id, machine)),
				]
			}
		}
		_ = db.batch!(stmts).map_err(fault)?
		body = Account.encode_token({ token: Login.token_text(input, signature), expires_at: Login.expires_at(now), account: { id: user.id, login: user.login } })
		Ok(json_answer(201, body))
	}

	too_large : () -> Try(Response, ReadRoutes.Error)
	too_large = || Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(Problem.new(TooLarge, "the body of the login request is larger than its limit of 262144"), { field: "body", limit: 262_144 }).to_utf8()))

	fetch_user! : Str => Try(Login.GithubUser, ReadRoutes.Error)
	fetch_user! = |token| {
		request = Request.get(Login.user_url).with_header("authorization", "Bearer ${token}").with_header("accept", "application/vnd.github+json").with_header("user-agent", "talon-registry")
		res = Http.send!(request) ? |_| Refuse(Login.user_no_answer)
		status = res.status()
		text = if status == 200 { res.text!() ? |_| Refuse(Login.user_no_answer) } else { "" }
		Login.github_user(status, text).map_err(|p| Refuse(p))
	}

	delete_tokens! : Request => Try(Response, ReadRoutes.Error)
	delete_tokens! = |req| {
		v = proof!(req)?
		now = Time.now_ms!()
		results = db.batch!([Sql.stmt(Login.revoke_sql(), (v.account.to_str(), now, v.iat_ms))]).map_err(fault)?
		rows : List({ revoked : U64 })
		rows = match results {
			[first] => all(first)?
			_ => return Err(Fault("delete_tokens: the batch gave ${results.len().to_str()} results, not 1"))
		}
		if rows.is_empty() { Err(Refuse(Login.not_good)) } else { Ok(no_content) }
	}

	get_me! : Request => Try(Response, ReadRoutes.Error)
	get_me! = |req| {
		v = proof!(req)?
		id = v.account.to_str()
		results = db.batch!([Sql.stmt(Login.account_row_sql(), [id]), Sql.stmt(Login.tracker_sql(), [id])]).map_err(fault)?
		match results {
			[account_result, tracker_result] => {
				accounts : List(Login.AccountRow)
				accounts = all(account_result)?
				tracked : List(Login.TrackerRow)
				tracked = all(tracker_result)?
				row = match accounts {
					[one] => one
					_ => return Err(Refuse(Login.no_account))
				}
				if Login.revoked({ iat_ms: v.iat_ms, tokens_after: row.tokens_after }) {
					return Err(Refuse(Login.revoked_problem))
				}
				stats = match tracked {
					[one] => one
					_ => return Err(Fault("get_me: the tracker gave ${tracked.len().to_str()} rows, not 1"))
				}
				Ok(json_answer(200, Account.encode_tracker(Login.tracker_of({ id: v.account, login: row.login }, stats))))
			}
			_ => Err(Fault("get_me: the batch gave ${results.len().to_str()} results, not 2"))
		}
	}

	delete_me! : Request => Try(Response, ReadRoutes.Error)
	delete_me! = |req| match Login.delete_proof({ authorization: req.header("authorization"), contributor: req.header("talon-contributor") }) {
		Refuse(problem) => Err(Refuse(problem))
		Account(jwt_text) => {
			v = verified!(jwt_text)?
			match limit!(req) {
				Ok({}) => {}
				Err(Limited) => return Ok(limited_response())
				Err(Fault(text)) => return Err(Fault(text))
			}
			id = v.account.to_str()
			stmts = Login.forget_account_sqls().map(|sql| Sql.stmt(sql, (id, v.iat_ms)))
			results = db.batch!(stmts).map_err(fault)?
			stale : List({ revoked : U64 })
			stale = match results {
				[first, ..] => all(first)?
				[] => []
			}
			if stale.is_empty() { Ok(no_content) } else { Err(Refuse(Login.not_good)) }
		}
		Machine(hex) => {
			match limit!(req) {
				Ok({}) => {}
				Err(Limited) => return Ok(limited_response())
				Err(Fault(text)) => return Err(Fault(text))
			}
			machine = machine!(hex)?.to_str()
			stmts = Login.forget_machine_sqls().map(|sql| Sql.stmt(sql, [machine]))
			_ = db.batch!(stmts).map_err(fault)?
			Ok(no_content)
		}
	}
}
