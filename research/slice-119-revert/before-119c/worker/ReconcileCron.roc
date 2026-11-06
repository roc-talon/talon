## The reconcile cron (Registry R-PU21 to R-PU25, R-PU35 to R-PU37, R-RE14; slice 119b, docs/slices/119-reconcile.md section 3). The decisions are in `lib/Reconcile.roc` (pure, W0).
## The tests are W2: `worker/tests/cases/reconcile/`. `main.roc` registers it with `Worker.cron(Reconcile.cron, ReconcileCron.run!)`.
##
## Flow (the clock is `Time.now_ms!()` once, Design Q345):
## 1. The claim: ONE `db.all!(Reconcile.claim_sql(), (now, Reconcile.max_rows))` on the primary. A failed claim writes `Log.warn!("reconcile claim failed", { error })` and the run ends `Ok({})`.
## 2. Each claimed row, one at a time (Q370: the order), with `interval = Reads.interval_ms(app_installed)`:
##    a. `GithubRead.send!(GET https://api.github.com/repositories/<repository_id>)` (R-PU31, R-TP10). `Webhook.repository_outcome`: `Withdraw` (404, private, internal): ONE batch on the
##       primary with the statements of `IndexQueue.withdraw!` (R-PU24, R-PU33, R-TP11: the row of the current name `missing` and its event, `repo-missing` on the releases of every name of the
##       repository id that have no value) and the pass update of the row (below, with no `etag` change). No list read. `Stale` (public): the `full_name` (`Identity.full_name_of`), go on.
##       `Err(Upstream)`, `NoAnswer`, `Token(_)`, a body with no `full_name`: the row fails.
##    b. `GithubRead.send!(GET Reconcile.list_url(full_name))` with the header `if-none-match: <etag>` when the row has an `etag` (no header when it has none). `Reconcile.list_outcome`.
##       `NotModified` (304): ONE batch with only the pass update (R-PU23: `etag` stays; Design Q374: a 304 is a pass, so `fail_count` = 0 and the interval).
##       `Changed({ etag, list })` (200): `Reconcile.list_work`. When `candidates` is not empty: FIRST `IndexQueue.index.send_batch!` of `Reconcile.message_of(repository_id, id)` for each one
##       (R-PU37 row 5). A failed send: the row fails (nothing of the list is written, the etag is not stored). Then ONE batch: the `changes` (as `IndexQueue.write_changes!` writes them:
##       `UPDATE releases SET withdrawn = ?2, withdrawn_at = <now> WHERE log_index = ?1 AND withdrawn IS NULL`; a clear sets both to NULL) and the pass update with the new `etag`
##       (`NULL` when the answer has none). A failed batch: the row fails (D1 rolls the batch back, so nothing of it stays).
##       `Err(Failed(text))`: the row fails.
##    The pass update: `UPDATE repo_checks SET checked_at = <now>, next_check_at = Reconcile.next_check(now, interval, 0), fail_count = 0 [, etag = ?] WHERE repo = CAST(? AS INTEGER)`.
##    A failed row (R-PU37 rows 2 to 4): ONE batch `UPDATE repo_checks SET fail_count = <n>, next_check_at = Reconcile.next_check(now, interval, n)` with n = the claimed `fail_count` + 1
##    (`checked_at` and `etag` stay), and ONE log line `Log.warn!("reconcile row failed", { job: "reconcile", repository_id, fail_count: n, error })` (no name, R-PU32; the texts are proposals, TW24).
##    The run goes on with the next row.
##    c. R-PU25, Design Q377: after each GitHub answer of the row, `Reconcile.reserve` of its headers. `Ok(at)`: the row still does ALL its work (its list read too, also when the reserve came from the visibility read), then ONE statement moves every claimed row that was not started:
##       `UPDATE repo_checks SET next_check_at = <at> WHERE repo IN (...)` (`fail_count` stays), ONE line `Log.warn!("reconcile rate reserve", { reset_ms: <at>, moved: <the count of rows moved> })`, and the run stops.
## 3. The result is `Ok({})` when the run ran (R-PU37 row 2: one failed row is a log line, not an `Err`). A trap stops the run; the claim makes the rows due again after 15 min (R-PU37 row 1).
import pf.Worker
import pf.D1
import pf.Log
import pf.Request
import pf.Response
import pf.Sql
import pf.Time
import lib.Identity
import lib.Reads
import lib.Reconcile
import lib.Webhook
import GithubRead
import IndexQueue

ReconcileCron :: [].{

	run! : Worker.Scheduled => Try({}, [Fault(Str)])
	run! = |_s| {
		now = Time.now_ms!()
		claimed : Try(List(ReconcileCron.Claimed), _)
		claimed = db.all!(Reconcile.claim_sql(), (now, Reconcile.max_rows))
		match claimed {
			Err(e) => Log.warn!("reconcile claim failed", { error: Str.inspect(e) })
			Ok(rows) => rows!(now, rows.sort_with(by_repo))
		}
		Ok({})
	}

	## One row of the claim (`Reconcile.claim_sql`). `repo` and `repository_id` are 64-bit ids as text (R-IK2). An empty `etag` is NULL.
	Claimed : { repo : Str, repository_id : Try(Str, [Missing]), etag : Str, fail_count : U32, app_installed : Bool, releases : Str }

	db = D1.binding("DB")

	## Q370: the rows in the order of `repo` as a signed 64-bit integer.
	by_repo : ReconcileCron.Claimed, ReconcileCron.Claimed -> [Before, Same, After]
	by_repo = |a, b| {
		x = I64.from_str(a.repo) ?? 0
		y = I64.from_str(b.repo) ?? 0
		if (x < y) Before else if (x > y) After else Same
	}

	## Each row, one at a time. After a row that saw the reserve (R-PU25, Q377), the rows that were not started move to the reset time, and the run stops.
	rows! : U64, List(ReconcileCron.Claimed) => {}
	rows! = |now, rows| {
		var $started = 0
		for c in rows {
			$started = $started + 1
			match row!(now, c) {
				Err(Go) => {}
				Ok(at) => {
					move!(at, rows.drop_first($started))
					break
				}
			}
		}
	}

	## R-PU25: one statement for all the rows that were not started. `fail_count` stays.
	move! : U64, List(ReconcileCron.Claimed) => {}
	move! = |at, rest| {
		ids = Str.join_with(rest.map(|c| "\"${c.repo}\""), ",")
		if !rest.is_empty() {
			stmt = Sql.stmt("UPDATE repo_checks SET next_check_at = ?1 WHERE repo IN (SELECT CAST(value AS INTEGER) FROM json_each(?2))", (at, "[${ids}]"))
			match db.batch!([stmt]) {
				Ok(_) => {}
				Err(e) => Log.warn!("reconcile rate reserve move failed", { error: Str.inspect(e) })
			}
		}
		Log.warn!("reconcile rate reserve", { reset_ms: at, moved: rest.len() })
	}

	## One row: the check, or the failure update and its log line (R-PU37 rows 2 to 4). The result is the reserve of the answers of the row.
	row! : U64, ReconcileCron.Claimed => Try(U64, [Go])
	row! = |now, c| {
		interval = Reads.interval_ms(c.app_installed)
		repository_id = match c.repository_id {
			Ok(text) => U64.from_str(text) ?? 0
			Err(Missing) => 0
		}
		match check!(now, interval, repository_id, c) {
			Ok(reserve) => reserve
			Err({ error, reserve }) => {
				n = if (c.fail_count == U32.highest) c.fail_count else c.fail_count + 1
				stmt = Sql.stmt("UPDATE repo_checks SET fail_count = ?2, next_check_at = ?3 WHERE repo = CAST(?1 AS INTEGER)", (c.repo, n, Reconcile.next_check(now, interval, n)))
				_ = db.batch!([stmt])
				Log.warn!("reconcile row failed", { job: "reconcile", repository_id, fail_count: n, error })
				reserve
			}
		}
	}

	Failure : { error : Str, reserve : Try(U64, [Go]) }

	## The reserve of one GitHub answer (R-PU25).
	reserve_of : Response -> Try(U64, [Go])
	reserve_of = |res| Reconcile.reserve({ remaining: header(res, "x-ratelimit-remaining"), limit: header(res, "x-ratelimit-limit"), reset: header(res, "x-ratelimit-reset") })

	header : Response, Str -> Try(Str, [None])
	header = |res, name| res.header(name).map_err(|_| None)

	## The later of 2 reserves (Q377: the row does all its work, then the run moves the rest).
	either : Try(U64, [Go]), Try(U64, [Go]) -> Try(U64, [Go])
	either = |a, b| match (a, b) {
		(Ok(x), Ok(y)) => Ok(if (x > y) x else y)
		(Ok(x), Err(Go)) => Ok(x)
		(Err(Go), other) => other
	}

	## The pass update (R-PU23, Q374): `checked_at`, the interval, `fail_count` 0, and the etag when `etag` is `Set(..)`.
	pass : U64, U64, ReconcileCron.Claimed, [Keep, Set(Try(Str, [None]))] -> Sql.Stmt
	pass = |now, interval, c, etag| {
		next = Reconcile.next_check(now, interval, 0)
		match etag {
			Keep => Sql.stmt("UPDATE repo_checks SET checked_at = ?2, next_check_at = ?3, fail_count = 0 WHERE repo = CAST(?1 AS INTEGER)", (c.repo, now, next))
			Set(value) => Sql.stmt("UPDATE repo_checks SET checked_at = ?2, next_check_at = ?3, fail_count = 0, etag = ?4 WHERE repo = CAST(?1 AS INTEGER)", (c.repo, now, next, Sql.or_null(value)))
		}
	}

	## The writes of one change (as `IndexQueue.write_changes!`). A clear is guarded by state (R-PU36: a webhook job can write the row during the run).
	change_stmt : U64, Webhook.Change -> Sql.Stmt
	change_stmt = |now, change| match change.to {
		Ok(value) => Sql.stmt("UPDATE releases SET withdrawn = ?2, withdrawn_at = ?3 WHERE log_index = ?1 AND withdrawn IS NULL", (change.log_index, value, now))
		Err(Clear) => Sql.stmt("UPDATE releases SET withdrawn = NULL, withdrawn_at = NULL WHERE log_index = ?1 AND withdrawn IS NOT NULL AND withdrawn <> 'repo-missing'", [change.log_index])
	}

	## The visibility read, then the list read (R-PU23, R-PU24, R-PU31). `Ok` is a pass, with the reserve of its answers.
	check! : U64, U64, U64, ReconcileCron.Claimed => Try(Try(U64, [Go]), ReconcileCron.Failure)
	check! = |now, interval, repository_id, c| {
		if repository_id == 0 {
			return Err({ error: "the row has no repository id", reserve: Err(Go) })
		}
		res = GithubRead.send!(Request.get(Identity.repo_by_id_url(repository_id))).map_err(|e| { error: "the repository read failed: ${Str.inspect(e)}", reserve: Err(Go) })?
		first = reserve_of(res)
		at_first = |error| { error, reserve: first }
		status = res.status()
		body = if (status == 200) res.text!().map_err(|_| at_first("the repository answer has no text"))? else ""
		outcome = Webhook.repository_outcome({ status, body }).map_err(|Upstream(text)| at_first(text))?
		match outcome {
			Withdraw => {
				stmts = IndexQueue.withdraw_stmts(repository_id, now).append(pass(now, interval, c, Keep))
				_ = db.batch!(stmts).map_err(|e| at_first(Str.inspect(e)))?
				Ok(first)
			}
			Stale => {
				full_name = Identity.full_name_of(body).map_err(|_| at_first("the repository answer has no full name"))?
				list!(now, interval, repository_id, c, full_name, first)
			}
		}
	}

	## The list read with `If-None-Match` (R-PU23), the send of the candidates first, then ONE batch with the etag (R-PU37 row 5).
	list! : U64, U64, U64, ReconcileCron.Claimed, Str, Try(U64, [Go]) => Try(Try(U64, [Go]), ReconcileCron.Failure)
	list! = |now, interval, repository_id, c, full_name, first| {
		ask = Request.get(Reconcile.list_url(full_name))
		request = if (c.etag.is_empty()) ask else ask.with_header("if-none-match", c.etag)
		res = GithubRead.send!(request).map_err(|e| { error: "the release list read failed: ${Str.inspect(e)}", reserve: first })?
		reserve = either(first, reserve_of(res))
		fail = |error| { error, reserve }
		status = res.status()
		body = if (status == 200) res.text!().map_err(|_| fail("the release list answer has no text"))? else ""
		outcome = Reconcile.list_outcome({ status, etag: header(res, "etag"), link: header(res, "link"), body }).map_err(|Failed(text)| fail(text))?
		stmts = match outcome {
			NotModified => [pass(now, interval, c, Keep)]
			Changed({ etag, list }) => {
				rows = Reconcile.indexed_of(c.releases).map_err(|_| fail("the indexed releases of the claim are not valid"))?
				work = Reconcile.list_work({ full_name, rows, list })
				if !work.candidates.is_empty() {
					IndexQueue.index.send_batch!(work.candidates.map(|id| Reconcile.message_of(repository_id, id))).map_err(|e| fail("the send of the candidates failed: ${Str.inspect(e)}"))?
				}
				work.changes.map(|change| change_stmt(now, change)).append(pass(now, interval, c, Set(etag)))
			}
		}
		_ = db.batch!(stmts).map_err(|e| fail(Str.inspect(e)))?
		Ok(reserve)
	}
}
