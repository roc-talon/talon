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

ReconcileCron :: [].{

	run! : Worker.Scheduled => Try({}, [Fault(Str)])
	run! = |_s| crash "todo"
}
