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
##       `NotModified` (304): ONE batch with only the pass update (R-PU23: a 304 changes only `checked_at` and `next_check_at`; `etag` stays).
##       `Changed({ etag, list })` (200): `Reconcile.list_work`. When `candidates` is not empty: FIRST `IndexQueue.index.send_batch!` of `Reconcile.message_of(repository_id, id)` for each one
##       (R-PU37 row 5). A failed send: the row fails (nothing of the list is written, the etag is not stored). Then ONE batch: the `changes` (as `IndexQueue.write_changes!` writes them:
##       `UPDATE releases SET withdrawn = ?2, withdrawn_at = <now> WHERE log_index = ?1 AND withdrawn IS NULL`; a clear sets both to NULL) and the pass update with the new `etag`
##       (`NULL` when the answer has none). A failed batch: the row fails (D1 rolls the batch back, so nothing of it stays).
##       `Err(Failed(text))`: the row fails.
##    The pass update: `UPDATE repo_checks SET checked_at = <now>, next_check_at = Reconcile.next_check(now, interval, 0), fail_count = 0 [, etag = ?] WHERE repo = CAST(? AS INTEGER)`.
##    A failed row (R-PU37 rows 2 to 4): ONE batch `UPDATE repo_checks SET fail_count = <n>, next_check_at = Reconcile.next_check(now, interval, n)` with n = the claimed `fail_count` + 1
##    (`checked_at` and `etag` stay), and ONE log line `Log.warn!("reconcile row failed", { job: "reconcile", repository_id, fail_count: n, error })` (no name, R-PU32; the texts are proposals, TW24).
##    The run goes on with the next row.
##    c. R-PU25: after each GitHub answer of the row, `Reconcile.reserve` of its headers. `Ok(at)`: the row ends as above, then ONE statement moves every claimed row that was not started:
##       `UPDATE repo_checks SET next_check_at = <at> WHERE repo IN (...)` (`fail_count` stays), ONE line `Log.warn!("reconcile rate reserve", { reset_ms: <at>, moved: <the count of rows moved> })`, and the run stops.
## 3. The result is `Ok({})` when the run ran (R-PU37 row 2: one failed row is a log line, not an `Err`). A trap stops the run; the claim makes the rows due again after 15 min (R-PU37 row 1).
import pf.Worker
import pf.D1
import pf.Log
import pf.Request
import pf.Response
import pf.Sql
import pf.Time
import lib.Reconcile
import lib.Reads
import lib.Webhook
import lib.Identity
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
			Ok(rows) => {
				sorted = rows.sort_with(|a, b| (I64.from_str(a.repo) ?? 0).order_relative_to(I64.from_str(b.repo) ?? 0))
				var $reserve = Err(Go)
				var $rest = []
				for c in sorted {
					match $reserve {
						Ok(_) => {
							$rest = $rest.append(c.repo)
						}
						Err(Go) => {
							$reserve = row!(now, c)
						}
					}
				}
				match $reserve {
					Ok(at) =>
						if !$rest.is_empty() {
							ids = "[${Str.join_with($rest.map(|r| "\"${r}\""), ",")}]"
							_ = db.batch!([Sql.stmt("UPDATE repo_checks SET next_check_at = ?1 WHERE repo IN (SELECT CAST(value AS INTEGER) FROM json_each(?2))", (at, ids))])
							Log.warn!("reconcile rate reserve", { reset_ms: at, moved: $rest.len() })
						}
					Err(Go) => {}
				}
			}
		}
		Ok({})
	}

	Claimed : { repo : Str, repository_id : Str, etag : Try(Str, [Missing]), fail_count : U32, app_installed : U8, rows : Str }

	db = D1.binding("DB")

	## One row: the work, then the pass or the failure update. The result is the reserve of the answers of the row.
	row! : U64, ReconcileCron.Claimed => Try(U64, [Go])
	row! = |now, c| {
		repository_id = U64.from_str(c.repository_id) ?? 0
		interval = Reads.interval_ms(c.app_installed == 1)
		done = work!(now, c, repository_id, interval)
		match done.result {
			Ok({}) => {}
			Err(error) => {
				n = c.fail_count + 1
				_ = db.batch!([Sql.stmt("UPDATE repo_checks SET fail_count = ?2, next_check_at = ?3 WHERE repo = CAST(?1 AS INTEGER)", (c.repo, n, Reconcile.next_check(now, interval, n)))])
				Log.warn!("reconcile row failed", { job: "reconcile", repository_id, fail_count: n, error })
			}
		}
		done.reserve
	}

	reserve_of : Response -> Try(U64, [Go])
	reserve_of = |res| Reconcile.reserve({ remaining: header(res, "x-ratelimit-remaining"), limit: header(res, "x-ratelimit-limit"), reset: header(res, "x-ratelimit-reset") })

	header : Response, Str -> Try(Str, [None])
	header = |res, name| match res.header(name) {
		Ok(v) => Ok(v)
		Err(_) => Err(None)
	}

	either : Try(U64, [Go]), Try(U64, [Go]) -> Try(U64, [Go])
	either = |a, b| match a {
		Ok(x) => Ok(x)
		Err(Go) => b
	}

	pass : Str, U64, U64, [Keep, Set(Try(Str, [None]))] -> Sql.Stmt
	pass = |repo, now, interval, etag| match etag {
		Keep => Sql.stmt("UPDATE repo_checks SET checked_at = ?2, next_check_at = ?3, fail_count = 0 WHERE repo = CAST(?1 AS INTEGER)", (repo, now, Reconcile.next_check(now, interval, 0)))
		Set(e) => Sql.stmt("UPDATE repo_checks SET checked_at = ?2, next_check_at = ?3, fail_count = 0, etag = ?4 WHERE repo = CAST(?1 AS INTEGER)", (repo, now, Reconcile.next_check(now, interval, 0), Sql.or_null(e)))
	}

	batch! : List(Sql.Stmt) => Try({}, Str)
	batch! = |stmts| db.batch!(stmts).map_ok(|_| {}).map_err(|e| "d1 batch: ${Str.inspect(e)}")

	work! : U64, ReconcileCron.Claimed, U64, U64 => { result : Try({}, Str), reserve : Try(U64, [Go]) }
	work! = |now, c, repository_id, interval| {
		vis = match GithubRead.send!(Request.get("https://api.github.com/repositories/${repository_id.to_str()}")) {
			Ok(res) => res
			Err(e) => return { result: Err("repository read: ${Str.inspect(e)}"), reserve: Err(Go) }
		}
		r1 = reserve_of(vis)
		status = vis.status()
		body = if (status == 200) (vis.text!() ?? "") else ""
		outcome = match Webhook.repository_outcome({ status, body }) {
			Ok(o) => o
			Err(Upstream(text)) => return { result: Err(text), reserve: r1 }
		}
		full_name = match outcome {
			Withdraw => {
				event = Sql.stmt(
					"INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 4, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, r.successor, NULL, ?2 FROM repos r WHERE r.repository_id = ?1 AND r.state = 0",
					(repository_id, now),
				)
				state = Sql.stmt("UPDATE repos SET state = 1, state_at = ?2 WHERE repository_id = ?1 AND state = 0", (repository_id, now))
				releases = Sql.stmt("UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = ?2 WHERE withdrawn IS NULL AND repo IN (SELECT repo FROM repos WHERE repository_id = ?1)", (repository_id, now))
				return { result: batch!([event, state, releases, pass(c.repo, now, interval, Keep)]), reserve: r1 }
			}
			Stale => match Identity.full_name_of(body) {
				Ok(f) => f
				Err(_) => return { result: Err("the repository answer has no full name"), reserve: r1 }
			}
		}
		req0 = Request.get(Reconcile.list_url(full_name))
		req = match c.etag {
			Ok(e) => req0.with_header("if-none-match", e)
			Err(Missing) => req0
		}
		res = match GithubRead.send!(req) {
			Ok(r) => r
			Err(e) => return { result: Err("list read: ${Str.inspect(e)}"), reserve: r1 }
		}
		reserve = either(r1, reserve_of(res))
		lstatus = res.status()
		lbody = if (lstatus == 200) (res.text!() ?? "") else ""
		listed = Reconcile.list_outcome({ status: lstatus, etag: header(res, "etag"), link: header(res, "link"), body: lbody })
		result = match listed {
			Err(Failed(text)) => Err(text)
			Ok(NotModified) => batch!([pass(c.repo, now, interval, Keep)])
			Ok(Changed({ etag, list })) => {
				parsed : Try(List({ log_index : U64, tag : Str, hash : Str, withdrawn : Str }), _)
				parsed = Json.parse(c.rows)
				match parsed {
					Err(_) => Err("the claim rows are not valid")
					Ok(raw) => {
						rows = raw.map(|r| { log_index: r.log_index, tag: r.tag, hash: r.hash, withdrawn: if (r.withdrawn.is_empty()) Err(None) else Ok(r.withdrawn) })
						w = Reconcile.list_work({ full_name, rows, list })
						sent = if (w.candidates.is_empty()) Ok({}) else IndexQueue.index.send_batch!(w.candidates.map(|id| Reconcile.message_of(repository_id, id))).map_err(|e| "queue send: ${Str.inspect(e)}")
						match sent {
							Err(text) => Err(text)
							Ok({}) => {
								stmts = w.changes.map(
									|ch| match ch.to {
										Ok(value) => Sql.stmt("UPDATE releases SET withdrawn = ?2, withdrawn_at = ?3 WHERE log_index = ?1 AND withdrawn IS NULL", (ch.log_index, value, now))
										Err(Clear) => Sql.stmt("UPDATE releases SET withdrawn = NULL, withdrawn_at = NULL WHERE log_index = ?1 AND withdrawn IS NOT NULL AND withdrawn <> 'repo-missing'", [ch.log_index])
									},
								)
								batch!(stmts.append(pass(c.repo, now, interval, Set(etag))))
							}
						}
					}
				}
			}
		}
		{ result, reserve }
	}
}
