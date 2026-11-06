## Private reference of slice 118 (IndexQueue.roc). Not for the code agent (TW18).
import pf.Queue
import pf.Cbor
import pf.D1
import pf.Http
import pf.Log
import pf.Request
import pf.Sql
import pf.Time
import lib.Webhook

IndexQueue :: [].{

	index : Queue(Webhook.Message)
	index = Queue.json("INDEX")

	db = D1.binding("DB")

	consume! : Queue.Batch => Try({}, [Fault(Str)])
	consume! = |batch| {
		if batch.queue() == Webhook.dlq_name {
			for m in batch.messages() {
				dead!(m)
			}
		} else {
			for m in batch.messages() {
				one!(m)
			}
		}
		Ok({})
	}

	read : Queue.Message -> Try(Webhook.Message, _)
	read = |m| Cbor.parse(m.body())

	dead! : Queue.Message => {}
	dead! = |m| {
		parsed : Try(Webhook.Message, _)
		parsed = read(m)
		match parsed {
			Ok(x) => Log.error!("index job dead", { event: x.event, action: x.action, repository_id: x.repository_id, release_id: x.release_id })
			Err(_) => Log.error!("index job dead", { readable: Bool.False })
		}
		m.ack!()
	}

	one! : Queue.Message => {}
	one! = |m| {
		parsed : Try(Webhook.Message, _)
		parsed = read(m)
		outcome = match parsed {
			Err(_) => Err("the body is not a message")
			Ok(x) => match Webhook.job_of(x) {
				Err(Unknown) => Err("the message is of an unknown event or action")
				Ok(job) => job!(job)
			}
		}
		match outcome {
			Ok({}) => m.ack!()
			Err(why) => {
				Log.warn!("index job failed", { attempts: m.attempts(), error: why })
				match Webhook.retry_delay_ms(m.attempts()) {
					Ok(ms) => m.retry_with!({ delay_ms: ms })
					Err(GiveUp) => m.retry!()
				}
			}
		}
	}

	job! : Webhook.Job => Try({}, Str)
	job! = |job| match job {
		Release(_) => Err("not done")
		Privatized(id) => privatized!(id)
		Publicized(id) => publicized!(id)
		AppInstalled(x) => installed!(x)
	}

	run! : List(Sql.Stmt) => Try({}, Str)
	run! = |stmts| {
		session = db.with_session!(Primary).map_err(|e| Str.inspect(e))?
		_ = session.batch!(stmts).map_err(|e| Str.inspect(e))?
		Ok({})
	}

	privatized! : U64 => Try({}, Str)
	privatized! = |id| {
		request = Request.get("https://api.github.com/repositories/${id.to_str()}").with_header("user-agent", "talon-registry").with_header("accept", "application/vnd.github+json")
		res = Http.send!(request).map_err(|_| "the GitHub repository read failed: no answer")?
		status = res.status()
		text = if (status == 200) res.text!().map_err(|_| "the GitHub repository answer is not text")? else ""
		match Webhook.repository_outcome({ status, body: text }) {
			Err(Upstream(why)) => Err(why)
			Ok(Stale) => Ok({})
			Ok(Withdraw) => {
				now = Time.now_ms!()
				run!(
					[
						Sql.stmt("UPDATE repos SET state = 1, state_at = ?2 WHERE repository_id = ?1 AND state = 0", (id, now)),
						Sql.stmt(
							"INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT r.repo, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 4, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, NULL, NULL, ?2 FROM repos r WHERE r.repository_id = ?1 AND r.state = 1 AND r.state_at = ?2 AND changes() > 0",
							(id, now),
						),
						Sql.stmt("UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = ?2 WHERE withdrawn IS NULL AND repo IN (SELECT repo FROM repos WHERE repository_id = ?1)", (id, now)),
					],
				)
			}
		}
	}

	publicized! : U64 => Try({}, Str)
	publicized! = |id| run!([Sql.stmt("UPDATE repo_checks SET next_check_at = ?2 WHERE repo IN (SELECT repo FROM repos WHERE repository_id = ?1 AND state <> 2)", (id, Time.now_ms!()))])

	installed! : { repository_ids : List(U64), installed : Bool } => Try({}, Str)
	installed! = |x| {
		if x.repository_ids.is_empty() {
			return Ok({})
		}
		flag = if (x.installed) 1.U64 else 0.U64
		ids = "[${Str.join_with(x.repository_ids.map(|i| i.to_str()), ",")}]"
		run!([Sql.stmt("UPDATE repo_checks SET app_installed = ?1 WHERE repo IN (SELECT repo FROM repos WHERE repository_id IN (SELECT CAST(value AS INTEGER) FROM json_each(?2)))", (flag, ids))])
	}
}
