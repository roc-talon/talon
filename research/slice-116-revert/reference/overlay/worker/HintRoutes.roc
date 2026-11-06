## REFERENCE (private) of worker/HintRoutes.roc, slices 116a and 116b.
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Time
import pf.Env
import pf.Http
import pf.Memo
import pf.RateLimit
import pf.WebCrypto
import lib.Compat
import lib.Hints
import lib.Client
import lib.Problem
import ReadRoutes

HintRoutes :: [].{

	db = D1.binding("DB")

	limiter = RateLimit.binding("RL_HINTS")

	tags : Memo(List(Str))
	tags = Memo.new("talon-tags", { max_age_ms: 3_600_000 })

	post! : Request, Try(List(U8), Compat.Reject) => Try(Response, ReadRoutes.Error)
	post! = |req, bytes| {
		body = match bytes {
			Ok(found) => found
			Err(Bad(problem)) => return Err(Refuse(problem))
			Err(TooLarge(problem, extra)) => return Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8()))
		}
		header = match req.header("talon-contributor") {
			Ok(text) => text
			Err(NotFound) => ""
		}
		machine = Hints.machine_id(header).map_err(|problem| Refuse(problem))?
		post = match Hints.parse(body) {
			Ok(found) => found
			Err(Bad(problem)) => return Err(Refuse(problem))
			Err(TooLarge(problem, extra)) => return Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8()))
		}
		match limiter.limit!(Client.rate_key(req.header("cf-connecting-ip"))) {
			Ok({}) => {}
			Err(RateLimited) => return Ok(Response.from_bytes(429, "application/problem+json", Client.rate_problem().to_json().to_utf8()).with_header("retry-after", Client.limit_retry_after.to_str()))
			Err(Infra(e)) => return Err(Fault(Str.inspect(e)))
		}
		if post.rows.is_empty() {
			return Ok(answer(0, 0, []))
		}
		sent = facts!(post)?
		key_bytes = Env.secret!("CONTRIBUTOR_KEY").map_err(|e| Fault(Str.inspect(e)))?.reveal().to_utf8()
		contributor = Hints.contributor_id(WebCrypto.hmac_sha256(key_bytes, Hints.hmac_message(machine)))
		tag_list = match tags.get!(load!) {
			Ok(found) => found
			Err(_) => []
		}
		version = Hints.talon_key({ version: post.talon_version, tags: tag_list })
		write!(sent, contributor, version)
	}

	load! : () => Try(List(Str), [Failed])
	load! = || {
		res = Http.get!(Hints.tags_url) ? |_| Failed
		if res.status() != 200 {
			Err(Failed)
		} else {
			text = res.text!() ? |_| Failed
			Hints.tag_names(text).map_err(|_| Failed)
		}
	}

	facts! : Hints.Post => Try(List(Hints.Sent), ReadRoutes.Error)
	facts! = |post| {
		params = Hints.read_params(post)
		stmts = [
			Sql.stmt("SELECT CAST(artifact AS TEXT) AS artifact, kind FROM artifacts WHERE artifact IN (SELECT CAST(value AS INTEGER) FROM json_each(?1))", [params.artifacts_json]),
			Sql.stmt("SELECT name, target FROM targets WHERE name IN (SELECT value FROM json_each(?1))", [params.targets_json]),
			Sql.stmt("SELECT CAST(artifact AS TEXT) AS artifact, target FROM artifact_targets WHERE artifact IN (SELECT CAST(value AS INTEGER) FROM json_each(?1))", [params.artifacts_json]),
		]
		results = db.batch!(stmts).map_err(|e| Fault(Str.inspect(e)))?
		found = match results {
			[art, tgt, plat] => {
				artifacts : List(Compat.ArtifactFact)
				artifacts = all(art)?
				target_rows : List(Compat.TargetFact)
				target_rows = all(tgt)?
				platform_targets : List(Compat.PlatformFact)
				platform_targets = all(plat)?
				Ok({ artifacts, target_rows, platform_targets })
			}
			_ => Err(Fault("hints: the read batch gave ${results.len().to_str()} results, not 3"))
		}?
		Hints.check(post, found).map_err(|problem| Refuse(problem))
	}

	write! : List(Hints.Sent), I64, I64 => Try(Response, ReadRoutes.Error)
	write! = |sent, contributor, version| {
		now = Time.now_ms!()
		json = Hints.rows_json(sent)
		stmts = [
			Sql.stmt(Hints.first_sql(), (json, now)),
			Sql.stmt(Hints.skipped_sql(), (json, now)),
			Sql.stmt(Hints.insert_sql(), (json, now, contributor, version)),
		]
		results = match db.batch!(stmts) {
			Ok(found) => found
			Err(Constraint(c)) => return failed(c, now)
			Err(Infra(e)) => return Err(Fault(Str.inspect(e)))
		}
		match results {
			[first_res, skipped_res, insert_res] => {
				firsts : List({ first : U64 })
				firsts = all(first_res)?
				skipped : List(Hints.Skipped)
				skipped = all(skipped_res)?
				written : List({ artifact : Str })
				written = all(insert_res)?
				Ok(answer(written.len(), firsts.first().map_ok(|r| r.first) ?? 0, skipped))
			}
			_ => Err(Fault("hints: the write batch gave ${results.len().to_str()} results, not 3"))
		}
	}

	failed : Compat.Constraint, U64 -> Try(Response, ReadRoutes.Error)
	failed = |c, now| match Hints.failure_of(c) {
		Quota => Ok(Response.from_bytes(429, "application/problem+json", Hints.quota_problem().to_json().to_utf8()).with_header("retry-after", Hints.retry_after(now).to_str()))
		Fault(text) => Err(Fault(text))
	}

	answer : U64, U64, List(Hints.Skipped) -> Response
	answer = |written, first, skipped| Response.from_bytes(Compat.written_status(written), "application/json", Hints.answer_body({ written, first, skipped }).to_utf8()).with_header("cache-control", "no-store")

	all = |result| result.all().map_err(|e| Fault(Str.inspect(e)))
}
