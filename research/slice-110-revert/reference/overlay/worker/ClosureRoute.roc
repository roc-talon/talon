## The handler of `POST /v1/closure` (Registry R-AP3, R-AP16 to R-AP18, R-AP20, R-AP41, R-AP46; slice 110). The decisions are in `lib/ClosureQuery.roc` (pure, W0).
## The tests are W2: `worker/tests/cases/closure/`. The SQL is `sql/closure/*.sql` in this dir (W1: `sql/tests/cases/closure/`).
## The flow (the slice file section 3.3):
## 1. `req.bytes_with!({ max_bytes: ClosureQuery.body_limit })`. `Err(TooLarge)`: `Refuse(ClosureQuery.too_large("body", ClosureQuery.body_limit))`. Another `Err`: `Refuse` 400.
## 2. `ClosureQuery.parse(bytes)`. `Err(problem)`: `Refuse(problem)`. No D1 call before this step (R-AP46: 413 before any D1 call).
## 3. One call: `db.with_session!(Reads.session_of(req.header("talon-bookmark")))`, then one `batch!` of the 12 statements, in the order of the slice file
##    section 4. Each statement is the text of `sql/closure/prefix.sql`, a newline, and the text of `sql/closure/<name>.sql`, with the 4 parameters
##    `(query.groups_json, query.hashes_json, Sql.or_null(query.from), Sql.or_null(query.to))`. A batch is one transaction (R-AP18). The closure changes no state (R-AP20).
## 4. The rows (typed reads of each `D1.Result`) as `ClosureQuery.Rows`, then `ClosureQuery.answer(query, rows, Time.now_ms!())`. `Err(BadRow)`: `Fault` (500).
## 5. 200, `content-type: application/json`, `cache-control: ClosureQuery.cache_control` (`no-store`, R-AP3). No ETag, no Cache API (it is a POST).
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Time
import lib.ClosureQuery
import lib.Reads
import lib.Problem
import ReadRoutes
import "sql/closure/prefix.sql" as prefix_sql : Str
import "sql/closure/artifacts.sql" as artifacts_sql : Str
import "sql/closure/deps.sql" as deps_sql : Str
import "sql/closure/targets.sql" as targets_sql : Str
import "sql/closure/releases.sql" as releases_sql : Str
import "sql/closure/unknown.sql" as unknown_sql : Str
import "sql/closure/epochs.sql" as epochs_sql : Str
import "sql/closure/runs.sql" as runs_sql : Str
import "sql/closure/nearest.sql" as nearest_sql : Str
import "sql/closure/hints.sql" as hints_sql : Str
import "sql/closure/checked.sql" as checked_sql : Str
import "sql/closure/repos.sql" as repos_sql : Str
import "sql/closure/log_size.sql" as log_size_sql : Str

ClosureRoute :: [].{

	post! : Request => Try(Response, ReadRoutes.Error)
	post! = |req| {
		bytes = match req.bytes_with!({ max_bytes: ClosureQuery.body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(reject_response(ClosureQuery.too_large("body", ClosureQuery.body_limit)))
			Err(_) => []
		}
		query = match ClosureQuery.parse(bytes) {
			Ok(q) => q
			Err(Bad(p)) => return Err(Refuse(p))
			Err(TooLarge(p, extra)) => return Ok(reject_response(TooLarge(p, extra)))
		}
		params = (query.groups_json, query.hashes_json, Sql.or_null(query.from), Sql.or_null(query.to))
		texts = [artifacts_sql, deps_sql, targets_sql, releases_sql, unknown_sql, epochs_sql, runs_sql, nearest_sql, hints_sql, checked_sql, repos_sql, log_size_sql]
		stmts = texts.map(|t| Sql.stmt("${prefix_sql}\n${t}", params))
		session = db.with_session!(Reads.session_of(req.header("talon-bookmark"))).map_err(|e| Fault(Str.inspect(e)))?
		results = session.batch!(stmts).map_err(|e| Fault(Str.inspect(e)))?
		rows = rows_of(results)?
		body = ClosureQuery.answer(query, rows, Time.now_ms!()).map_err(
			|e| match e {
				BadRow(t) => Fault(t)
			},
		)?
		Ok(Response.from_bytes(200, "application/json", body.to_utf8()).with_header("cache-control", ClosureQuery.cache_control))
	}

	reject_response : ClosureQuery.Reject -> Response
	reject_response = |r| match r {
		Bad(p) => Response.from_bytes(p.http_status(), "application/problem+json", p.to_json().to_utf8())
		TooLarge(p, extra) => Response.from_bytes(p.http_status(), "application/problem+json", Problem.to_json_with(p, extra).to_utf8())
	}

	db = D1.binding("DB")

	fault = |e| Fault(Str.inspect(e))

	rows_of : List(D1.Result) -> Try(ClosureQuery.Rows, ReadRoutes.Error)
	rows_of = |results| match results {
		[art, dep, tgt, rel, unk, ep, run, near, hint, chk, rep, log] => {
			artifacts : List(Reads.ArtifactRow)
			artifacts = art.all().map_err(fault)?
			deps : List(ClosureQuery.DepRow)
			deps = dep.all().map_err(fault)?
			target_rows : List(ClosureQuery.TargetRow)
			target_rows = tgt.all().map_err(fault)?
			releases : List(Reads.ReleaseRow)
			releases = rel.all().map_err(fault)?
			unknown : List(ClosureQuery.UnknownRow)
			unknown = unk.all().map_err(fault)?
			epochs : List({ target : Str, from : Str, to : Str })
			epochs = ep.all().map_err(fault)?
			runs : List(ClosureQuery.RunRow)
			runs = run.all().map_err(fault)?
			nearest : List(ClosureQuery.NearestRow)
			nearest = near.all().map_err(fault)?
			hints : List(ClosureQuery.HintRow)
			hints = hint.all().map_err(fault)?
			checked : List(Reads.CheckRow)
			checked = chk.all().map_err(fault)?
			repos : List(Reads.RepoRow)
			repos = rep.all().map_err(fault)?
			sizes : List({ log_size : U64 })
			sizes = log.all().map_err(fault)?
			log_size = match sizes {
				[s, ..] => s.log_size
				[] => 0
			}
			Ok({ artifacts, deps, target_rows, releases, unknown, epochs, runs, nearest, hints, checked, repos, log_size })
		}
		_ => Err(Fault("closure: the batch gave ${U64.to_str(results.len())} results, not 12"))
	}
}
