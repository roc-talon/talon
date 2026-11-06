import records.Compat
import Clock
import Db
import Fx
import Item
import Roots
import Registry
import Share
import ShareFlow
import ShareJson
import ShareQueue

## The send of the share queue (slice 216; CLI 1 R-SH4, R-SH5, R-SH6; Registry R-AP10, R-AP34, R-CT1, R-CT2, R-CT4, R-CT14). The wire types are `records.Compat` (`HintPost`, `HintAnswer`, R-AP72).
## A command that sent a request to the registry calls `send!` at its end, after its output. Which commands do that is not decided here (slices 206b, 206e, 206f).
##
## `send!` never fails and never changes the exit code, the output or the `--json` of the command (R-SH4): it prints nothing and returns `{}` (the reading of the slice file, Q3).
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Share.state` of `sharing`: `Off(_)` ends the send, with no call (R-SH2: "again before it sends") | R-SH2 |
## | 2 | `db_query!` with `QueueRows`. An `Err` (busy, failed, `TooNew`) or no row ends the send, with no message (Q453). | R-SH4 |
## | 3 | `plan`. The rows of `stale` leave: one `db_write!` with `Unqueue(stale)`, when `stale` is not empty. No batch ends the send. | R-SH4, R-TF7 |
## | 4 | `read_files!` of `share.json`, `ShareJson.read`: the id (`Talon-Contributor`). A file that does not parse ends the send (Q453). A missing file: `Fx.locked!` on it, `read_files!`, `random!` twice, the new file (the write of R-SH5), and the id of that file is used with no new read (Q452). | R-SH5, R-SH13 |
## | 5 | For each batch, in order: `clock!` (for the first batch this is the start of the 5 s), `remaining` (`Stop` ends the send), `http_send!` of `request`, `settle`. `Stay` ends the send (Q458). `Leave`: one `db_write!` with `Unqueue(seqs)`; when it fails, no totals are written (Q459). | R-SH4 |
## | 6 | When a request got a 200 or a 201 answer (`Leave` with `sent` above 0) and no `Unqueue` failed: `Clock.now!` with `sharing.env` (one `clock!`, `TALON_NOW` applies, Q457), then `Fx.locked!` on `share.json`: `read_files!`, `totals`, the write of R-SH5 (`random!` for the temp name, `write_atomic!`, `chmod 0600`, `rename!`). | R-SH6, R-SH5 |
QueueSend :: [].{

	## R-SH4 (first guesses of the design): at most 2 requests, of at most 500 rows, in at most 5 s in total.
	max_requests : U64
	max_requests = 2

	batch_rows : U64
	batch_rows = 500

	budget_s : U64
	budget_s = 5

	## The answer of a request, as `Fx.http_send!` gives it.
	Reply : Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])

	## The totals that one request adds to `share.json` (R-SH6).
	Add : { sent : U64, counted : U64, first : U64 }

	## R-SH4, R-TF7: which rows to send. The rows of `talon_version` (the running `tln`), the smallest `seq` first, in `batches` of at most `batch_rows` rows, at most `max_requests` batches. The other rows of the version stay.
	## A row of another `talon_version` is in `stale`: it leaves the queue with no send (R-TF7, column `talon_version`). The order of `rows` does not matter: the result is sorted by `seq`.
	## The rows of other versions do not count for the 500.
	plan : { rows : List(Db.QueueItem), talon_version : Str } -> { stale : List(U64), batches : List(List(Db.QueueItem)) }
	plan = |run| {
		sorted = run.rows.sort_with(|a, b| a.seq.order_relative_to(b.seq))
		mine = sorted.keep_if(|r| r.row.talon_version == run.talon_version)
		stale = sorted.keep_if(|r| r.row.talon_version != run.talon_version).map(|r| r.seq)
		{ stale, batches: mine.chunks_of(QueueSend.batch_rows).take_first(QueueSend.max_requests) }
	}

	## R-SH4 (Q454): the time that is left for the next request. `started` and `now` are `Fx.clock!` values (whole seconds). The first request gets `budget_s`. `Send(n)`: `budget_s - (now - started)`, as the `timeout_s`
	## of the request. `Stop` when the elapsed time is `budget_s` or more.
	remaining : { started : U64, now : U64 } -> [Send(U64), Stop]
	remaining = |times| {
		used = if times.now > times.started times.now - times.started else 0
		if used >= QueueSend.budget_s Stop else Send(QueueSend.budget_s - used)
	}

	## R-AP10, R-AP23, R-AP45, R-CT1, R-CT2: the request of one batch. A `POST` to `<origin>/v1/compat`. The headers, in this order (Q5, proposal): `Registry.headers` for `{ version: talon_version, body: Json }`
	## (`User-Agent`, `Content-Type`), then `Talon-Contributor: <contributor>`. No `Authorization`. The body is `Compat.encode_hint_post` of `{ talon_version, rows }`: a row is `hash`, `nightly`, `target` and the `result` word
	## (`Db.outcome_word`). `timeout_s` as given.
	request : { origin : Str, talon_version : Str, contributor : Str, rows : List(Db.Queued), timeout_s : U64 } -> { method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 }
	request = |run| {
		rows = run.rows.map(|r| { hash: r.hash, nightly: r.nightly, target: r.target, result: Db.outcome_word(r.result) })
		{
			method: Post,
			url: "${run.origin}/v1/compat",
			headers: Registry.headers({ version: run.talon_version, body: Json }).append(("Talon-Contributor", run.contributor)),
			body: Compat.encode_hint_post({ talon_version: run.talon_version, rows }),
			timeout_s: run.timeout_s,
		}
	}

	## R-SH4, R-SH6, R-CT4, R-CT14: what one answer does. `count` is the number of rows of the request.
	##
	## | Answer | Result |
	## | --- | --- |
	## | 200 or 201 with a body that decodes as `Compat.HintAnswer` | `Leave({ sent: count, counted: written, first })`. The rows in `skipped` leave too. |
	## | 4xx other than 429 | `Leave({ sent: 0, counted: 0, first: 0 })`: the registry will not take the rows, and they are not counted |
	## | 429, 5xx, `Timeout`, `Failed(_)` | `Stay` |
	## | Another status (1xx, 2xx other than 200 and 201, 3xx) | `Stay` (Q455) |
	## | A 200 or 201 whose body does not decode | `Leave({ sent: count, counted: 0, first: 0 })` (Q456) |
	settle : { count : U64, reply : Reply } -> [Leave(Add), Stay]
	settle = |run| match run.reply {
		Err(_) => Stay
		Ok(answer) => if answer.status == 200 or answer.status == 201 {
			match Compat.decode_hint_answer(answer.body) {
				Ok(done) => Leave({ sent: run.count, counted: done.written, first: done.first })
				Err(_) => Leave({ sent: run.count, counted: 0, first: 0 })
			}
		} else if answer.status >= 400 and answer.status <= 499 and answer.status != 429 {
			Leave({ sent: 0, counted: 0, first: 0 })
		} else {
			Stay
		}
	}

	## R-SH6: `share.json` after the answers. `add` is added to `sent`, `counted` and `first`. `first_sent_at` is `now` when it is `Unset`, else it stays. `last_sent_at` is `now`. `now` is RFC 3339 UTC text (`Clock.format_utc`).
	## The other members (`id`, `token`, `token_expires_at`, `account`, `extra`) stay as they are (R-TF2).
	totals : { doc : ShareJson.Doc, add : Add, now : Str } -> ShareJson.Doc
	totals = |run| {
		doc = run.doc
		first_sent_at = match doc.first_sent_at {
			Ok(t) => Ok(t)
			Err(Unset) => Ok(run.now)
		}
		{ ..doc, sent: doc.sent + run.add.sent, counted: doc.counted + run.add.counted, first: doc.first + run.add.first, first_sent_at, last_sent_at: Ok(run.now) }
	}

	## The steps in the table above. `sharing` has the facts of `Share.state`. `talon_version` is the version of `tln` (the User-Agent and the rows). The origin of the request is the `Url` of `sharing.registry`;
	## with `Direct` (no registry) nothing is sent (that is `Off(Direct)` of `Share.state`).
	send! : Fx, { roots : Roots, sharing : ShareQueue.Sharing, talon_version : Str } => {}
	send! = |fx, run| match Share.state(run.sharing) {
		Off(_) => {}
		On => match run.sharing.registry {
			Direct => {}
			Url(origin) => send_to!(fx, run, origin)
		}
	}
}

# Steps 2 to 6.
send_to! : Fx, { roots : Roots, sharing : ShareQueue.Sharing, talon_version : Str }, Str => {}
send_to! = |fx, run, origin| {
	open = { path: Roots.item(run.roots, Item.CompatDb), busy_ms: Db.busy_ms, format: Db.format }
	rows = match fx.db_query!(open, QueueRows) {
		Ok(QueueRows(found)) => found
		_ => []
	}
	planned = QueueSend.plan({ rows, talon_version: run.talon_version })
	if !planned.stale.is_empty() {
		_ = fx.db_write!(open, Unqueue(planned.stale))
	}
	if planned.batches.is_empty() {
		{}
	} else {
		match contributor!(fx, Roots.item(run.roots, Item.ShareJson)) {
			Err(_) => {}
			Ok(id) => {
				sent = send_batches!(fx, open, { origin, talon_version: run.talon_version, contributor: id, batches: planned.batches })
				if sent.sent > 0 {
					record!(fx, run, sent)
				} else {
					{}
				}
			}
		}
	}
}

# Step 4: the id of `share.json`.
contributor! : Fx, Str => Try(Str, [Stop])
contributor! = |fx, path| match fx.read_files!([path]) {
	[Ok(text)] => match ShareJson.read({ path, text }) {
		Ok(doc) => Ok(doc.id)
		Err(_) => Err(Stop)
	}
	_ => match ShareFlow.ensure_doc!(fx, path) {
		Ok(doc) => Ok(doc.id)
		Err(_) => Err(Stop)
	}
}

# Step 5: the requests. The result is the sum of what the answers added.
send_batches! : Fx, Db.Open, { origin : Str, talon_version : Str, contributor : Str, batches : List(List(Db.QueueItem)) } => QueueSend.Add
send_batches! = |fx, open, run| {
	var $total = { sent: 0, counted: 0, first: 0 }
	var $started = 0
	var $stop = Bool.False
	var $index = 0
	for batch in run.batches {
		if !$stop {
			now = fx.clock!()
			if $index == 0 {
				$started = now
			}
			$index = $index + 1
			match QueueSend.remaining({ started: $started, now }) {
				Stop => {
					$stop = Bool.True
				}
				Send(timeout_s) => {
					req = QueueSend.request({ origin: run.origin, talon_version: run.talon_version, contributor: run.contributor, rows: batch.map(|r| r.row), timeout_s })
					match QueueSend.settle({ count: batch.len(), reply: fx.http_send!(req) }) {
						Stay => {
							$stop = Bool.True
						}
						Leave(add) => match fx.db_write!(open, Unqueue(batch.map(|r| r.seq))) {
							Err(_) => {
								$stop = Bool.True
							}
							Ok(_) => {
								$total = { sent: $total.sent + add.sent, counted: $total.counted + add.counted, first: $total.first + add.first }
							}
						}
					}
				}
			}
		}
	}
	$total
}

# Step 6: the totals of `share.json`.
record! : Fx, { roots : Roots, sharing : ShareQueue.Sharing, talon_version : Str }, QueueSend.Add => {}
record! = |fx, run, add| match Clock.now!(fx, run.sharing.env) {
	Err(_) => {}
	Ok(seconds) => {
		now = Clock.format_utc(seconds)
		_ = ShareFlow.totals_write!(fx, Roots.item(run.roots, Item.ShareJson), |doc| QueueSend.totals({ doc, add, now }))
		{}
	}
}
