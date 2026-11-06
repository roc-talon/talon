## REFERENCE (private) of worker/CompatRoutes.roc, slice 115a.
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Time
import lib.Compat
import lib.Problem
import lib.Reads
import Auth
import ReadRoutes
import "sql/compat/prefix.sql" as prefix_sql : Str
import "sql/compat/missing.sql" as missing_sql : Str

CompatRoutes :: [].{

	db = D1.binding("DB")

	post! : Request => Try(Response, ReadRoutes.Error)
	post! = |req| {
		bytes = match req.bytes_with!({ max_bytes: Compat.body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(too_large_answer(Compat.too_large("body", Compat.body_limit)))
			Err(BodyErr(_)) => []
		}
		match Compat.request_kind({ authorization: req.header("authorization"), contributor: req.header("talon-contributor") }) {
			Refuse(problem) => Err(Refuse(problem))
			Hint => Err(Fault("user hints are slice 116"))
			Bot => bot!(req, bytes)
		}
	}

	too_large_answer : Compat.Reject -> Response
	too_large_answer = |r| match r {
		TooLarge(problem, extra) => Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8())
		Bad(problem) => Response.from_bytes(400, "application/problem+json", problem.to_json().to_utf8())
	}

	bot! : Request, List(U8) => Try(Response, ReadRoutes.Error)
	bot! = |req, bytes| {
		post = match Compat.parse_post(bytes) {
			Ok(p) => p
			Err(Bad(problem)) => return Err(Refuse(problem))
			Err(TooLarge(problem, extra)) => return Ok(too_large_answer(TooLarge(problem, extra)))
		}
		match Auth.bot!(req) {
			Err(problem) => return Err(Refuse(problem))
			Ok(_) => {}
		}
		plan = read_plan!(post)?
		now = Time.now_ms!()
		rows_stmts = if (plan.is_empty()) [] else [Sql.stmt(Compat.rows_sql(), (Compat.rows_json(plan), now))]
		sweep_stmts = match post.sweep {
			Ok(s) => [Sql.stmt(Compat.sweep_sql(), (s.nightly, 0.I64, s.upto_log_index.to_i64_wrap(), now))]
			Err(None) => []
		}
		stmts = rows_stmts.concat(sweep_stmts)
		if stmts.is_empty() {
			return Ok(answer(0))
		}
		match db.batch!(stmts) {
			Ok(results) => {
				written = if (plan.is_empty()) 0 else (results.first().map_ok(|r| r.info().changes) ?? 0)
				Ok(answer(written))
			}
			Err(Constraint(c)) => match Compat.failure_of(c) {
				Bad(problem) => Err(Refuse(problem))
				Fault(text) => Err(Fault(text))
				SweepIncomplete => incomplete!(post)
			}
			Err(other) => Err(Fault(Str.inspect(other)))
		}
	}

	answer : U64 -> Response
	answer = |written| Response.from_bytes(Compat.written_status(written), "application/json", Compat.written_body(written).to_utf8()).with_header("cache-control", "no-store")

	## D1 call 1: the facts of the rows. No row: no call.
	read_plan! : Compat.Post => Try(List(Compat.PlanRow), ReadRoutes.Error)
	read_plan! = |post| {
		if post.rows.is_empty() {
			return Ok([])
		}
		params = Compat.read_params(post)
		results = db.batch!(
			[
				Sql.stmt("SELECT CAST(artifact AS TEXT) AS artifact, kind FROM artifacts WHERE artifact IN (SELECT value FROM json_each(?1))", [params.artifacts_json]),
				Sql.stmt("SELECT name, CAST(target AS TEXT) AS target FROM targets WHERE name IN (SELECT value FROM json_each(?1))", [params.targets_json]),
				Sql.stmt("SELECT CAST(artifact AS TEXT) AS artifact, CAST(target AS TEXT) AS target FROM artifact_targets WHERE artifact IN (SELECT value FROM json_each(?1))", [params.artifacts_json]),
			],
		).map_err(|e| Fault(Str.inspect(e)))?
		facts = match results {
			[a, t, p] => {
				artifacts : List(Compat.ArtifactFact)
				artifacts = a.all().map_err(|e| Fault(Str.inspect(e)))?
				target_rows : List(Compat.TargetFact)
				target_rows = t.all().map_err(|e| Fault(Str.inspect(e)))?
				platform_targets : List(Compat.PlatformFact)
				platform_targets = p.all().map_err(|e| Fault(Str.inspect(e)))?
				{ artifacts, target_rows, platform_targets }
			}
			_ => return Err(Fault("compat: the read batch gave ${results.len().to_str()} results, not 3"))
		}
		Compat.plan(post, facts).map_err(|problem| Refuse(problem))
	}

	## D1 call 3 (R-MX9): the members with no bot row, then the 422.
	incomplete! : Compat.Post => Try(Response, ReadRoutes.Error)
	incomplete! = |post| {
		sweep = match post.sweep {
			Ok(s) => s
			Err(None) => return Err(Fault("sweep-incomplete without a sweep"))
		}
		rows : Try(List({ hash : List(U8) }), _)
		rows = db.all!("${prefix_sql}\n${missing_sql}", (sweep.nightly, 0.I64, sweep.upto_log_index.to_i64_wrap()))
		found = rows.map_err(|e| Fault(Str.inspect(e)))?
		missing = found.map_try(|r| Reads.base58_of_bytes(r.hash)).map_err(|e| match e { BadRow(text) => Fault(text) })?
		Err(Refuse(Compat.sweep_incomplete({ tag: sweep.tag, upto_log_index: sweep.upto_log_index, missing })))
	}
}
