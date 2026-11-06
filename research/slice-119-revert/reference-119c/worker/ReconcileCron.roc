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
## Slice 119c (docs/slices/119-reconcile.md sections 11 and 13; Design Q371, Q372, Q376, Q378 to Q380). Changes to the flow above:
## - a. The visibility read sends `if-none-match: <repo_etag>` when the claim gives one (Q371). A 304: public, the name of the row and the same ids: the list read of the NAME OF THE ROW, no identity
##   write, and the pass keeps `repo_etag`. A 200 public: the pass stores `Reconcile.repo_etag_of(..)`. A withdraw (Q376: `IndexQueue.withdraw_stmts` also sets `etag` and `repo_etag` NULL).
##   A failed row does not change `repo_etag`.
## - Identity, for a 200 public read (in the batch of the row, BEFORE the release changes and the pass; each statement with the SQL guards of slice 113, R-PU36; reuse the identity statements of
##   `IngestRoutes`). `F` = the `full_name` in lower case. (1) `F` is the name of the row: R-TP9 row 2 when `owner.id` is not the `repository_owner_id` of the row (the new owner id, event `transfer`,
##   Q379), then `found` when the row is `missing` (state `active`, event `found`, only when the statement changed the row, Q378). (2) `F` is another name (Q380, R-TP18 rows 1, 3, 4 with U = F):
##   `F` has no row: the `names` row, the `repos` row of `F` (`active`, the ids of the read, `state_at` and `time` now, event `rename` seq 1 with no ids before), the `repo_checks` row of `F`
##   (`app_installed` of the claimed row, `next_check_at` = now + the interval, the rest NULL or 0), and each row of the repository id that is not `moved` gets `moved`, successor `F`, `state_at` now,
##   event `rename`. The row of `F` is `moved` with the same id: R-TP18 row 3. The row of `F` is `active` or `missing` with the same id: (1) on the row of `F`. A row of `F` with ANOTHER
##   `repository_id`: no identity write. The list read is of the `full_name` as GitHub gave it, and the list work is on the releases of every name of the repository id (as 119b).
## - b. Pages (Q372): page 1 with `if-none-match` (a 304 ends the read); while `Reconcile.has_next(link)`, read `Reconcile.page_url(full_name, n)` (no `if-none-match`), at most `Reconcile.max_pages`;
##   a page 10 that still has a next page: the row fails with `the release list has more than 10 pages`. `Reconcile.merge_pages`. More than one page: the pass stores `etag` NULL.
## - The clear of `repo-missing` (R-PU24, Q379) comes from `list_work`. The guard of a clear changes: it is the value that the claim saw, `WHERE log_index = ?1 AND withdrawn = ?2` (R-PU36: a job
##   `privatized` can set `repo-missing` during the run, and that value must stay; test `pu36-state-guard`).
## 3. The result is `Ok({})` when the run ran (R-PU37 row 2: one failed row is a log line, not an `Err`). A trap stops the run; the claim makes the rows due again after 15 min (R-PU37 row 1).
import pf.Worker
import pf.D1
import pf.Log
import pf.Request
import pf.Response
import pf.Sql
import pf.Time
import lib.Identity
import lib.Ingest
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
	Claimed : { repo : Str, repository_id : Try(Str, [Missing]), etag : Str, fail_count : U32, app_installed : Bool, repo_etag : Str, name : Try(Str, [Missing]), releases : Str }

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

	## The pass update (R-PU23, Q374), with the list etag and the repo etag (Q371).
	pass : U64, U64, ReconcileCron.Claimed, [Keep, Set(Try(Str, [None]))], [Keep, Set(Try(Str, [None]))] -> Sql.Stmt
	pass = |now, interval, c, etag, repo_etag| {
		next = Reconcile.next_check(now, interval, 0)
		e = match etag {
			Keep => "etag"
			Set(_) => "?4"
		}
		r = match repo_etag {
			Keep => "repo_etag"
			Set(_) => "?5"
		}
		v = |x| match x {
			Keep => Sql.or_null(Err(None))
			Set(t) => Sql.or_null(t)
		}
		Sql.stmt("UPDATE repo_checks SET checked_at = ?2, next_check_at = ?3, fail_count = 0, etag = ${e}, repo_etag = ${r} WHERE repo = CAST(?1 AS INTEGER) AND (?4 IS NULL OR 1) AND (?5 IS NULL OR 1)", (c.repo, now, next, v(etag), v(repo_etag)))
	}

	## The writes of one change. A clear is guarded by the value that the claim saw (R-PU36, 119c).
	change_stmt : U64, List(Reconcile.Indexed), Webhook.Change -> Sql.Stmt
	change_stmt = |now, rows, change| match change.to {
		Ok(value) => Sql.stmt("UPDATE releases SET withdrawn = ?2, withdrawn_at = ?3 WHERE log_index = ?1 AND withdrawn IS NULL", (change.log_index, value, now))
		Err(Clear) => {
			old = match rows.find_first(|r| r.log_index == change.log_index) {
				Ok(r) => r.withdrawn ?? ""
				Err(_) => ""
			}
			Sql.stmt("UPDATE releases SET withdrawn = NULL, withdrawn_at = NULL WHERE log_index = ?1 AND withdrawn = ?2", (change.log_index, old))
		}
	}

	ev = "INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time)"

	## R-TP9 row 2, R-TP11, R-TP18 rows 1, 3, 4 with U = F (Q378 to Q380). Every statement is guarded, so the ones that do not apply change nothing.
	identity_stmts : U64, U64, ReconcileCron.Claimed, U64, U64, Str => List(Sql.Stmt)
	identity_stmts = |now, interval, c, id, owner, full_name| {
		f = full_name.with_ascii_lowercased()
		fid = match f.split_on("/") {
			[o, r] => Reads.repo_id(o, r)
			_ => 0
		}
		inst : U8
		inst = if (c.app_installed) 1 else 0
		marked = Sql.stmt("${ev} SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 2, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, ?1, NULL, ?2 FROM repos r WHERE r.repository_id = ?3 AND r.repo <> ?1 AND r.state = 2 AND r.successor = ?1 AND r.state_at = ?2 AND changes() > 0", (fid, now, id))
		[
			# R-TP9 row 2 on the claimed row first (Q381): the event transfer, then the new owner id.
			Sql.stmt("${ev} SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 1, r.repository_id, r.repository_id, r.repository_owner_id, ?3, r.successor, NULL, ?4 FROM repos r WHERE r.repo = CAST(?1 AS INTEGER) AND r.repository_id = ?2 AND r.repository_owner_id <> ?3 AND r.state <> 2", (c.repo, id, owner, now)),
			Sql.stmt("UPDATE repos SET repository_owner_id = ?3 WHERE repo = CAST(?1 AS INTEGER) AND repository_id = ?2 AND repository_owner_id <> ?3 AND state <> 2", (c.repo, id, owner)),
			Sql.stmt("INSERT INTO names (id, kind, value) SELECT ?1, 3, ?2 WHERE NOT EXISTS (SELECT 1 FROM names WHERE id = ?1)", (fid, f)),
			# R-TP18 row 1: F has no row.
			Sql.stmt("UPDATE repos SET state = 2, successor = ?1, state_at = ?2 WHERE repository_id = ?3 AND repo <> ?1 AND state <> 2 AND NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1)", (fid, now, id)),
			marked,
			Sql.stmt("INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) SELECT ?1, ?2, ?3, 0, NULL, ?4, ?4 WHERE NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1)", (fid, id, owner, now)),
			Sql.stmt("${ev} SELECT ?1, 1, 2, NULL, ?2, NULL, ?3, NULL, NULL, ?4 WHERE changes() > 0", (fid, id, owner, now)),
			Sql.stmt("INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) SELECT ?1, NULL, NULL, ?2, 0, ?3 WHERE NOT EXISTS (SELECT 1 FROM repo_checks WHERE repo = ?1)", (fid, now + interval, inst)),
			# R-TP18 row 3: the row of F is moved with the same id.
			Sql.stmt("UPDATE repos SET state = 2, successor = ?1, state_at = ?2 WHERE repository_id = ?3 AND repo <> ?1 AND state <> 2 AND EXISTS (SELECT 1 FROM repos WHERE repo = ?1 AND state = 2 AND repository_id = ?3)", (fid, now, id)),
			marked,
			Sql.stmt("UPDATE repos SET state = 0, successor = NULL, state_at = ?2 WHERE repo = ?1 AND state = 2 AND repository_id = ?3", (fid, now, id)),
			Sql.stmt("${ev} SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), 2, ?2, ?2, ?3, ?3, NULL, NULL, ?4 WHERE changes() > 0", (fid, id, owner, now)),
			# R-TP9 row 2 (Q379) on the row of F, then found (Q378).
			Sql.stmt("${ev} SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 1, r.repository_id, r.repository_id, r.repository_owner_id, ?3, r.successor, NULL, ?4 FROM repos r WHERE r.repo = ?1 AND r.repository_id = ?2 AND r.repository_owner_id <> ?3 AND r.state <> 2", (fid, id, owner, now)),
			Sql.stmt("UPDATE repos SET repository_owner_id = ?3 WHERE repo = ?1 AND repository_id = ?2 AND repository_owner_id <> ?3 AND state <> 2", (fid, id, owner)),
			Sql.stmt("UPDATE repos SET state = 0, state_at = ?3 WHERE repo = ?1 AND repository_id = ?2 AND state = 1", (fid, id, now)),
			Sql.stmt("${ev} SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 5, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, NULL, NULL, ?2 FROM repos r WHERE r.repo = ?1 AND changes() > 0", (fid, now)),
		]
	}

	## The visibility read (with `repo_etag`, Q371), the identity (119c), then the list read.
	check! : U64, U64, U64, ReconcileCron.Claimed => Try(Try(U64, [Go]), ReconcileCron.Failure)
	check! = |now, interval, repository_id, c| {
		if repository_id == 0 {
			return Err({ error: "the row has no repository id", reserve: Err(Go) })
		}
		ask = Request.get(Identity.repo_by_id_url(repository_id))
		request = if (c.repo_etag.is_empty()) ask else ask.with_header("if-none-match", c.repo_etag)
		res = GithubRead.send!(request).map_err(|e| { error: "the repository read failed: ${Str.inspect(e)}", reserve: Err(Go) })?
		first = reserve_of(res)
		at_first = |error| { error, reserve: first }
		status = res.status()
		if status == 304 {
			name = c.name ?? ""
			return list!(now, interval, repository_id, c, name, first, [], Keep)
		}
		body = if (status == 200) res.text!().map_err(|_| at_first("the repository answer has no text"))? else ""
		outcome = Webhook.repository_outcome({ status, body }).map_err(|Upstream(text)| at_first(text))?
		match outcome {
			Withdraw => {
				stmts = IndexQueue.withdraw_stmts(repository_id, now).append(pass(now, interval, c, Keep, Keep))
				_ = db.batch!(stmts).map_err(|e| at_first(Str.inspect(e)))?
				Ok(first)
			}
			Stale => {
				full_name = Identity.full_name_of(body).map_err(|_| at_first("the repository answer has no full name"))?
				repo = Ingest.parse_repo(body).map_err(|_| at_first("the repository answer is not a repository"))?
				ids = identity_stmts(now, interval, c, repository_id, repo.owner_id, full_name)
				stored = Reconcile.repo_etag_of({ public: Bool.True, row_name: c.name ?? "", full_name, etag: header(res, "etag") })
				list!(now, interval, repository_id, c, full_name, first, ids, Set(stored))
			}
		}
	}

	## The pages of the list (Q372), the send of the candidates first, then ONE batch with the etag (R-PU37 row 5).
	list! : U64, U64, U64, ReconcileCron.Claimed, Str, Try(U64, [Go]), List(Sql.Stmt), [Keep, Set(Try(Str, [None]))] => Try(Try(U64, [Go]), ReconcileCron.Failure)
	list! = |now, interval, repository_id, c, full_name, first, ids, repo_etag| {
		var $reserve = first
		var $pages = []
		var $etag = Err(None)
		var $n = 1
		var $more = Bool.True
		while $more {
			ask = Request.get(Reconcile.page_url(full_name, $n))
			request = if ($n == 1 and !c.etag.is_empty()) ask.with_header("if-none-match", c.etag) else ask
			r0 = $reserve
			res = GithubRead.send!(request).map_err(|e| { error: "the release list read failed: ${Str.inspect(e)}", reserve: r0 })?
			$reserve = either($reserve, reserve_of(res))
			r1 = $reserve
			fail = |error| { error, reserve: r1 }
			status = res.status()
			body = if (status == 200) res.text!().map_err(|_| fail("the release list answer has no text"))? else ""
			link = header(res, "link")
			outcome = Reconcile.list_outcome({ status, etag: header(res, "etag"), link, body }).map_err(|Failed(text)| fail(text))?
			match outcome {
				NotModified => {
					if $n == 1 {
						_ = db.batch!(ids.append(pass(now, interval, c, Keep, repo_etag))).map_err(|e| fail(Str.inspect(e)))?
						return Ok($reserve)
					}
					return Err(fail("a page after the first answered 304"))
				}
				Changed({ etag, list }) => {
					if $n == 1 {
						$etag = etag
					}
					$pages = $pages.append(list)
					if Reconcile.has_next(link) {
						if $n >= Reconcile.max_pages {
							return Err(fail("the release list has more than 10 pages"))
						}
						$n = $n + 1
					} else {
						$more = Bool.False
					}
				}
			}
		}
		r2 = $reserve
		fail2 = |error| { error, reserve: r2 }
		list = Reconcile.merge_pages($pages)
		etag = if ($n > 1) Err(None) else $etag
		rows = Reconcile.indexed_of(c.releases).map_err(|_| fail2("the indexed releases of the claim are not valid"))?
		work = Reconcile.list_work({ full_name, rows, list })
		if !work.candidates.is_empty() {
			IndexQueue.index.send_batch!(work.candidates.map(|id| Reconcile.message_of(repository_id, id))).map_err(|e| fail2("the send of the candidates failed: ${Str.inspect(e)}"))?
		}
		stmts = ids.concat(work.changes.map(|change| change_stmt(now, rows, change))).append(pass(now, interval, c, Set(etag), repo_etag))
		_ = db.batch!(stmts).map_err(|e| fail2(Str.inspect(e)))?
		Ok($reserve)
	}
}
