import Db
import Fx
import Roots
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
## | 2 | `db_query!` with `QueueRows`. An `Err` or no row ends the send. | R-SH4 |
## | 3 | `plan`. The rows of `stale` leave: one `db_write!` with `Unqueue(stale)`, when `stale` is not empty. No batch ends the send. | R-SH4, R-TF7 |
## | 4 | `read_files!` of `share.json`, `ShareJson.read`: the id (`Talon-Contributor`). An `Err` ends the send (a missing file: Q2). | R-SH5 |
## | 5 | For each batch, in order: `clock!` (for the first batch this is the start of the 5 s), `remaining` (`Stop` ends the send), `http_send!` of `request`, `settle`. A batch that leaves goes in one `db_write!` with `Unqueue(seqs)`. | R-SH4 |
## | 6 | When a request got a 200 or a 201 answer (`Leave` with `sent` above 0): `Fx.locked!` on `share.json`: `read_files!`, `totals` (the time is the `clock!` value of the last request, Q8), the write of R-SH5 (`random!` for the temp name, `write_atomic!`, `chmod 0600`, `rename!`). | R-SH6, R-SH5 |
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
	plan = |_run| crash "todo: slice 216"

	## R-SH4 (Q4, proposal): the time that is left for the next request. `started` and `now` are `Fx.clock!` values (whole seconds). The first request gets `budget_s`. `Send(n)`: `budget_s - (now - started)`, as the `timeout_s`
	## of the request. `Stop` when the elapsed time is `budget_s` or more.
	remaining : { started : U64, now : U64 } -> [Send(U64), Stop]
	remaining = |_times| crash "todo: slice 216"

	## R-AP10, R-AP23, R-AP45, R-CT1, R-CT2: the request of one batch. A `POST` to `<origin>/v1/compat`. The headers, in this order (Q5, proposal): `Registry.headers` for `{ version: talon_version, body: Json }`
	## (`User-Agent`, `Content-Type`), then `Talon-Contributor: <contributor>`. No `Authorization`. The body is `Compat.encode_hint_post` of `{ talon_version, rows }`: a row is `hash`, `nightly`, `target` and the `result` word
	## (`Db.outcome_word`). `timeout_s` as given.
	request : { origin : Str, talon_version : Str, contributor : Str, rows : List(Db.Queued), timeout_s : U64 } -> { method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 }
	request = |_run| crash "todo: slice 216"

	## R-SH4, R-SH6, R-CT4, R-CT14: what one answer does. `count` is the number of rows of the request.
	##
	## | Answer | Result |
	## | --- | --- |
	## | 200 or 201 with a body that decodes as `Compat.HintAnswer` | `Leave({ sent: count, counted: written, first })`. The rows in `skipped` leave too. |
	## | 4xx other than 429 | `Leave({ sent: 0, counted: 0, first: 0 })`: the registry will not take the rows, and they are not counted |
	## | 429, 5xx, `Timeout`, `Failed(_)` | `Stay` |
	## | Another status (1xx, 2xx other than 200 and 201, 3xx), and a 200 or 201 whose body does not decode | not decided (Q6, Q7) |
	settle : { count : U64, reply : Reply } -> [Leave(Add), Stay]
	settle = |_run| crash "todo: slice 216"

	## R-SH6: `share.json` after the answers. `add` is added to `sent`, `counted` and `first`. `first_sent_at` is `now` when it is `Unset`, else it stays. `last_sent_at` is `now`. `now` is RFC 3339 UTC text (`Clock.format_utc`).
	## The other members (`id`, `token`, `token_expires_at`, `account`, `extra`) stay as they are (R-TF2).
	totals : { doc : ShareJson.Doc, add : Add, now : Str } -> ShareJson.Doc
	totals = |_run| crash "todo: slice 216"

	## The steps in the table above. `sharing` has the facts of `Share.state`. `talon_version` is the version of `tln` (the User-Agent and the rows). The origin of the request is the `Url` of `sharing.registry`;
	## with `Direct` (no registry) nothing is sent (that is `Off(Direct)` of `Share.state`).
	send! : Fx, { roots : Roots, sharing : ShareQueue.Sharing, talon_version : Str } => {}
	send! = |_fx, _run| crash "todo: slice 216"
}
