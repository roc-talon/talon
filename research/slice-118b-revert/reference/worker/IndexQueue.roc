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
import lib.Problem
import lib.Ingest
import lib.Identity
import lib.Reads
import IngestRoutes
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
		job!(job, m.attempts())
	}

	job! : Webhook.Job, U32 => Try({}, Str)
	job! = |job, attempts| match job {
		Release(r) => release!(r, attempts)
		Privatized(id) => privatized!(id)
		Publicized(id) => publicized!(id)
		AppInstalled({ repository_ids, installed }) => app_installed!(repository_ids, installed)
	}

	## Slice 118b: the job `Release`, in the order of the comment of `Webhook` (section 118b). `attempts` is the attempt of the message (the first delivery is 1): a release with no package asset at the fifth attempt ends with `Ok` and the
	## info line `Log.info!("index job no asset", { repository_id, release_id })` (Design Q334). `Ok({})` is an ack. `Err(text)` is a failure: the consumer retries (`work!`).
	release! : { action : Str, repository_id : U64, release_id : U64, installation_id : U64 }, U32 => Try({}, Str)
	release! = |job, attempts| {
		repository = read_text!("https://api.github.com/repositories/${job.repository_id.to_str()}")?
		body = match repository {
			Gone => return withdraw!(job.repository_id)
			Text(text) => text
		}
		repo = Ingest.parse_repo(body).map_err(|_| "the repository answer is not a repository")?
		if !repo.public {
			return withdraw!(job.repository_id)
		}
		full_name = Identity.full_name_of(body).map_err(|_| "the repository answer has no full_name")?
		if job.installation_id >= 1 {
			batch_db!([Sql.stmt("UPDATE repo_checks SET app_installed = 1 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1)", [job.repository_id])])?
		}
		if job.action == "deleted" {
			now = Time.now_ms!()
			return db.batch!([Sql.stmt("UPDATE repo_checks SET next_check_at = ?2 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1 AND state <> 2)", (job.repository_id, now))]).map_ok(|_| {}).map_err(fault)
		}
		text = match read_text!("https://api.github.com/repos/${full_name}/releases/${job.release_id.to_str()}")? {
			Gone => return Ok({})
			Text(t) => t
		}
		read = Webhook.parse_release(text).map_err(|_| "the release answer is not a release")?
		step = Webhook.release_step({ action: job.action, full_name, read })
		session = db.with_session!(Primary).map_err(fault)?
		rows : Try(List({ log_index : U64, hash : Str, withdrawn : Try(Str, [Missing]) }), _)
		rows = session.all!("SELECT r.log_index AS log_index, l.hash AS hash, r.withdrawn AS withdrawn FROM releases r JOIN log l ON l.idx = r.log_index WHERE r.tag = ?2 AND r.repo IN (SELECT repo FROM repos WHERE repository_id = ?1) ORDER BY r.log_index", (job.repository_id, read.tag))
		indexed = rows.map_err(fault)?.map(|r| { log_index: r.log_index, hash: r.hash, withdrawn: r.withdrawn.map_err(|_| None) })
		state = match step {
			Withdraw(value) => Withdrawn(value)
			Index(_) => Final({ assets: read.release.assets, candidate: Bool.True })
			_ => Final({ assets: read.release.assets, candidate: Bool.False })
		}
		now = Time.now_ms!()
		changes = Webhook.row_changes({ state, rows: indexed }).map(
			|c| match c.to {
				Ok(value) => Sql.stmt("UPDATE releases SET withdrawn = ?2, withdrawn_at = ?3 WHERE log_index = ?1", (c.log_index, value, now))
				Err(Clear) => Sql.stmt("UPDATE releases SET withdrawn = NULL, withdrawn_at = NULL WHERE log_index = ?1", [c.log_index])
			},
		)
		match step {
			Index(url) => {
				done = index!(session, job, repo, full_name, url)
				apply!(session, changes)?
				done
			}
			NoAsset => {
				apply!(session, changes)?
				match Webhook.after_no_asset(attempts) {
					Retry(_) => Err("the release has no package asset")
					Done => {
						Log.info!("index job no asset", { repository_id: job.repository_id, release_id: job.release_id })
						Ok({})
					}
				}
			}
			_ => {
				apply!(session, changes)?
				Ok({})
			}
		}
	}

	apply! : D1.Session, List(Sql.Stmt) => Try({}, Str)
	apply! = |session, stmts| if stmts.is_empty() Ok({}) else session.batch!(stmts).map_ok(|_| {}).map_err(fault)

	batch_db! : List(Sql.Stmt) => Try({}, Str)
	batch_db! = |stmts| db.batch!(stmts).map_ok(|_| {}).map_err(fault)

	## The `type` member of a problem (the kind is not visible outside `Problem`).
	type_of : Problem -> Str
	type_of = |problem| {
		parsed : Try({ type : Str }, _)
		parsed = Json.parse(problem.to_json())
		parsed.map_ok(|p| p.type) ?? "unknown"
	}

	## One GitHub `GET`: the text of a 200, `Gone` for a 404, an error text for another status or no answer.
	read_text! : Str => Try([Text(Str), Gone], Str)
	read_text! = |url| {
		res = GithubRead.send!(Request.get(url)).map_err(|e| "the read of GitHub failed: ${Str.inspect(e)}")?
		match res.status() {
			200 => res.text!().map_ok(|t| Text(t)).map_err(|_| "the GitHub answer has no text")
			404 => Ok(Gone)
			status => Err("GitHub answered with status ${status.to_str()}")
		}
	}

	## The index of the asset `url` (R-PU13, R-PU14, R-PU15): the pre-read of the label with `via` 1, then the three paths of `Ingest.after_read`.
	index! : D1.Session, { action : Str, repository_id : U64, release_id : U64, installation_id : U64 }, Ingest.Repo, Str, Str => Try({}, Str)
	index! = |session, job, repo, full_name, url| {
		target = match Ingest.parse_url(url) {
			Ok(t) => t
			Err(_) => return Ok({})
		}
		repo_id = Reads.repo_id(target.owner, target.repo)
		first = session.batch!([Sql.stmt(IngestRoutes.label_sql_of(1), IngestRoutes.label_params(target)), Sql.stmt(IngestRoutes.repo_sql, [repo_id])]).map_err(fault)?
		rows = IngestRoutes.label_rows(first.first().map_err(|_| "the pre-read gave no result")?.all()).map_err(fault)?
		old = IngestRoutes.old_row(first, 1, repo_id).map_err(fault)?
		now = Time.now_ms!()
		installed = Sql.stmt("UPDATE repo_checks SET app_installed = 1 WHERE repo = ?1", [repo_id])
		match Ingest.after_read(target, rows).map_err(|_| "the label row is not valid")? {
			Conflict(_) => {
				Log.warn!("index label conflict", { repository_id: job.repository_id, release_id: job.release_id, group: target.form, version: target.version.to_str() })
				Ok({})
			}
			Answer(_) => Ok({})
			AddProvenance(log_index) => {
				provenance = Sql.stmt("INSERT INTO provenance (release, via, claims, time) SELECT ?1, 1, NULL, ?2 WHERE NOT EXISTS (SELECT 1 FROM provenance WHERE release = ?1 AND via = 1)", (log_index, now))
				apply!(session, [provenance])
			}
			Index => {
				identity = match IngestRoutes.identity!(target, repo_id, { repo, full_name }, old, now, Err(None)).map_err(fault)? {
					Stop(_) => return Ok({})
					Go(done) => done.stmts
				}
				grows = if (old == Err(None) and job.installation_id >= 1) {
					[installed, Sql.stmt("UPDATE repo_checks SET next_check_at = ?2 WHERE repo = ?1", (repo_id, now + Reads.interval_ms(Bool.True)))]
				} else {
					[]
				}
				flow = {
					repo,
					identity,
					now,
					via: 1,
					claims: Err(None),
					extra: grows,
					candidate: Ingest.candidate,
					no_release: Ingest.no_release,
				}
				match IngestRoutes.index!(session, target, flow) {
					Ok(_) => Ok({})
					Err(Refuse(problem)) => {
						if problem.http_status() >= 500 {
							Err("the index was refused: ${problem.to_json()}")
						} else {
							Log.warn!("index job refused", { repository_id: job.repository_id, release_id: job.release_id, type: type_of(problem) })
							Ok({})
						}
					}
					Err(Fault(text)) => Err(text)
				}
			}
		}
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
