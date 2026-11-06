## The index queue (Registry R-PU11, R-PU13, R-PU35, R-PU45, R-WH14 `INDEX` and `INDEX_DLQ`; slice 118). The decisions are in `lib/Webhook.roc` (pure, W0). The tests are W2: `worker/tests/cases/webhook/`.
## `main.roc` declares `IndexQueue.index` in `Worker.new({ bindings })` and its `queue!` calls `IndexQueue.consume!`. Every body here is a stub until the code agent writes it (TW18).
import pf.Queue
import pf.Cbor
import pf.D1
import pf.Http
import pf.Log
import pf.Request
import pf.Sql
import pf.Time
import lib.Webhook
import GithubRead

IndexQueue :: [].{

	## The producer binding `INDEX` (R-WH14): the queue `Webhook.queue_name`, messages of the type `Webhook.Message` (content type `json`).
	index : Queue(Webhook.Message)
	index = Queue.json("INDEX")

	## The consumer of the Worker: one `queue!` for all the queues of the Worker. `Queue.Batch.queue` is the name of the queue.
	## - `Webhook.dlq_name`: for each message write ONE log line and ack it: `Log.error!("index job dead", fields)`. `fields` are `event`, `action`, `repository_id`, `release_id` of the message (no name, R-PU32).
	##   A body that is not a `Webhook.Message`: the line `Log.error!("index job dead", { readable: Bool.False })`, and ack it.
	## - `Webhook.queue_name`: one message at a time, in the order of the batch. Do not use `Queue.each!`: it acks after an `Ok` and retries with no delay after an `Err`. Read the body with
	##   `Cbor.parse(Queue.Message.body(m))` as a `Webhook.Message`, then `Webhook.job_of`, then run the job (below). The result of a job:
	##   `Ok` is `m.ack!()`. `Err(why)` is a failure: `Webhook.retry_delay_ms(m.attempts())`: `Ok(ms)` is `m.retry_with!({ delay_ms: ms })`, `Err(GiveUp)` is `m.retry!()` (the platform moves the message to the dead letter queue, R-PU45; only if the first-deploy edge check of R-PU45 fails, the consumer sends the message to `INDEX_DLQ` itself and acks it: a later change, with its own tests). A failure also writes one
	##   `Log.warn!("index job failed", { event, action, repository_id, attempts, error })` (no name). A body that is not a message, or `Err(Unknown)` from `job_of`, is a failure.
	##   `Release(..)`: slice 118b. Until then it is a failure with the error `not done`.
	## - `Privatized(id)` (R-PU33, R-PU31, R-PU12): `GET https://api.github.com/repositories/<id>` (the headers of the other GitHub reads), then `Webhook.repository_outcome` with the status and the body text. `Err(Upstream)`, and
	##   no answer, is a failure. `Stale` writes nothing. `Withdraw` is one `batch!` on the primary (a repository with no `repos` row writes nothing, R-PU32): for each `repos` row with `repository_id` = id and
	##   `state` not `moved` that `Identity.went_missing` changes: `UPDATE repos` (guarded by the old state) and one `repo_events` row `Missing` (`WHERE changes() > 0`); and for the releases of EVERY row with that
	##   `repository_id` (also `moved`): `UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = <now> WHERE repo IN (..) AND withdrawn IS NULL`. The clock is `Time.now_ms!()` once.
	## - `Publicized(id)` (R-PU33, Design Q324): no GitHub read. `UPDATE repo_checks SET next_check_at = <now> WHERE repo IN (the `repos` rows with that `repository_id` and `state` not `moved`)`. The state of `repos` and `withdrawn` do not change
	##   (the next reconcile does that, R-PU24, slice 119). A repository with no row: nothing is written.
	## - `AppInstalled({ repository_ids, installed })` (R-PU26, Design Q322, Q324): `UPDATE repo_checks SET app_installed = <1 or 0> WHERE repo IN (EVERY `repos` row, also `moved`, with `repository_id` in the list)`. An id with no row writes nothing:
	##   no row is added (R-PU32). No GitHub read. No change of `next_check_at`.
	## No job counts as a D1 call of a request (R-AP41): the consumer has no limit on the count.
	consume! : Queue.Batch => Try({}, [Fault(Str)])
	consume! = |batch| {
		queue = batch.queue()
		if queue == Webhook.dlq_name {
			for m in batch.messages() {
				dead!(m)
			}
			Ok({})
		} else if queue == Webhook.queue_name {
			for m in batch.messages() {
				work!(m)
			}
			Ok({})
		} else {
			Err(Fault("the Worker has no consumer for the queue ${queue}"))
		}
	}

	## The dead letter queue: one log line for each message, then ack (R-PU35, R-PU32: the ids only).
	dead! : Queue.Message => {}
	dead! = |m| {
		read : Try(Webhook.Message, _)
		read = Cbor.parse(m.body())
		match read {
			Ok(x) => Log.error!("index job dead", { event: x.event, action: x.action, repository_id: x.repository_id, release_id: x.release_id })
			Err(_) => Log.error!("index job dead", { readable: Bool.False })
		}
		m.ack!()
	}

	## One job: ack after `Ok`. After `Err`: a log line, then the retry with the delay of the attempt, or with no delay at the last attempt (R-PU13, R-PU35).
	work! : Queue.Message => {}
	work! = |m| match run!(m) {
		Ok({}) => m.ack!()
		Err(why) => {
			attempts = m.attempts()
			Log.warn!("index job failed", { attempts, error: why })
			match Webhook.retry_delay_ms(attempts) {
				Ok(ms) => m.retry_with!({ delay_ms: ms })
				Err(GiveUp) => m.retry!()
			}
		}
	}

	run! : Queue.Message => Try({}, Str)
	run! = |m| {
		read : Try(Webhook.Message, _)
		read = Cbor.parse(m.body())
		message = read.map_err(|_| "the body is not an index message")?
		job = Webhook.job_of(message).map_err(|_| "the message is not a job of this Worker")?
		job!(job)
	}

	job! : Webhook.Job => Try({}, Str)
	job! = |job| match job {
		Release(_) => Err("not done")
		Privatized(id) => privatized!(id)
		Publicized(id) => publicized!(id)
		AppInstalled({ repository_ids, installed }) => app_installed!(repository_ids, installed)
	}

	db = D1.binding("DB")

	fault = |e| Str.inspect(e)

	privatized! : U64 => Try({}, Str)
	privatized! = |id| {
		res = GithubRead.send!(Request.get("https://api.github.com/repositories/${id.to_str()}")).map_err(|e| "the repository read failed: ${Str.inspect(e)}")?
		status = res.status()
		body = if (status == 200) res.text!().map_err(|_| "the repository answer has no text")? else ""
		outcome = match Webhook.repository_outcome({ status, body }) {
			Ok(o) => o
			Err(Upstream(text)) => return Err(text)
		}
		match outcome {
			Stale => Ok({})
			Withdraw => withdraw!(id)
		}
	}

	## R-PU33, R-PU24, R-TP11, R-TP19: the row of the current name becomes `missing` with its event; the releases of every row of the repository get `repo-missing`. A repository with no row writes nothing.
	withdraw! : U64 => Try({}, Str)
	withdraw! = |id| {
		now = Time.now_ms!()
		session = db.with_session!(Primary).map_err(fault)?
		event = Sql.stmt(
			"INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 4, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, r.successor, NULL, ?2 FROM repos r WHERE r.repository_id = ?1 AND r.state = 0",
			(id, now),
		)
		state = Sql.stmt("UPDATE repos SET state = 1, state_at = ?2 WHERE repository_id = ?1 AND state = 0", (id, now))
		releases = Sql.stmt(
			"UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = ?2 WHERE withdrawn IS NULL AND repo IN (SELECT repo FROM repos WHERE repository_id = ?1)",
			(id, now),
		)
		session.batch!([event, state, releases]).map_ok(|_| {}).map_err(fault)
	}

	## R-PU33, Q324: the rows that are not `moved` are checked now. The state and `withdrawn` stay.
	publicized! : U64 => Try({}, Str)
	publicized! = |id| {
		now = Time.now_ms!()
		stmt = Sql.stmt("UPDATE repo_checks SET next_check_at = ?2 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1 AND state <> 2)", (id, now))
		db.batch!([stmt]).map_ok(|_| {}).map_err(fault)
	}

	## R-PU26, Q322, Q324: every row of each repository, also `moved`. No row is added.
	app_installed! : List(U64), Bool => Try({}, Str)
	app_installed! = |ids, installed| {
		if ids.is_empty() {
			return Ok({})
		}
		flag : U8
		flag = if (installed) 1 else 0
		stmts = ids.map(|id| Sql.stmt("UPDATE repo_checks SET app_installed = ?2 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1)", (id, flag)))
		db.batch!(stmts).map_ok(|_| {}).map_err(fault)
	}
}
