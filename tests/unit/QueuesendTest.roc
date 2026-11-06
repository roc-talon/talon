import lib.Db
import lib.JsonDoc
import lib.QueueSend
import lib.ShareJson

QueuesendTest :: [].{}

# Slice 216 (CLI 1 R-SH4, R-SH6; Registry R-AP10, R-CT1, R-CT2, R-CT4, R-CT14): the pure part of the send of the share queue. The flow is the L2 cases `share/sh11` to `share/sh16`.

version = "0.9.0"

queued : { hash : Str, talon_version : Str } -> Db.Queued
queued = |given| { hash: given.hash, nightly: "nightly-2026-10-14-38a3029", target: "any", result: Pass, talon_version: given.talon_version, queued_at: "2026-11-03T10:00:00Z" }

item : U64, Str -> Db.QueueItem
item = |seq, talon_version| { seq, row: queued({ hash: "H${seq.to_str()}", talon_version }) }

# The rows 1 to `n`, all of one version.
items : U64, Str -> List(Db.QueueItem)
items = |n, talon_version| U64.to(1, n).iter().map(|seq| item(seq, talon_version)).collect()

seqs : List(Db.QueueItem) -> List(U64)
seqs = |rows| rows.map(|r| r.seq)

# R-SH4: "at most 2 requests of at most 500 rows, in at most 5 s in total" (first guesses of the design). R-AP46: the Worker takes at most 500 rows (413 above).
expect {
	QueueSend.max_requests == 2 and QueueSend.batch_rows == 500 and QueueSend.budget_s == 5
}

# R-SH4: the plan. No row, no batch. Rows of the running version go in batches of 500, the smallest `seq` first, and at most 2 batches go: the rest waits for a later command.
expect {
	three = QueueSend.plan({ rows: items(3, version), talon_version: version })
	none = QueueSend.plan({ rows: [], talon_version: version })
	none == { stale: [], batches: [] } and three == { stale: [], batches: [items(3, version)] }
}

# R-SH4: the sizes. 500 rows are one request; 501 rows are 500 and 1; 1000 rows are two requests of 500; 1001 and 1200 rows are still two requests (rows 1 to 1000), the rest waits.
expect {
	sizes = |n| QueueSend.plan({ rows: items(n, version), talon_version: version }).batches.map(|b| b.len())
	last = |n| QueueSend.plan({ rows: items(n, version), talon_version: version }).batches.map(|b| seqs(b).last())
	sizes(500) == [500] and sizes(501) == [500, 1] and sizes(1000) == [500, 500] and sizes(1001) == [500, 500] and sizes(1200) == [500, 500]
		and last(1200) == [Ok(500), Ok(1000)] and last(501) == [Ok(500), Ok(501)]
}

# R-SH4: "oldest rows first" is the smallest `seq` first, also when the list is not in that order (the order of `seq` is the only order that counts, R-TF7).
expect {
	shuffled = [item(3, version), item(1, version), item(2, version)]
	QueueSend.plan({ rows: shuffled, talon_version: version }).batches.map(seqs) == [[1, 2, 3]]
}

# R-SH4, R-TF7: "the send takes only the rows of the version that runs. A row of another version leaves the queue with no send." Those rows are `stale` (smallest `seq` first), they are in no batch,
# and they do not count for the 500 of a batch. The version is compared as text (`0.9.0` is not `0.9.0-rc1`).
expect {
	mixed = [item(1, "0.8.0"), item(2, version), item(3, "0.8.0"), item(4, version), item(5, "0.9.0-rc1")]
	plan = QueueSend.plan({ rows: mixed, talon_version: version })
	many = QueueSend.plan({ rows: items(3, "0.8.0").concat(U64.to(4, 603).iter().map(|seq| item(seq, version)).collect()), talon_version: version })
	only_old = QueueSend.plan({ rows: items(2, "0.8.0"), talon_version: version })
	plan.stale == [1, 3, 5] and plan.batches.map(seqs) == [[2, 4]]
		and many.stale == [1, 2, 3] and many.batches.map(|b| b.len()) == [500, 100]
			and only_old == { stale: [1, 2], batches: [] }
}

# R-SH4: the 5 s. The first request gets 5 s. Each next request gets what is left of the 5 s since `started` (whole seconds of `Fx.clock!`, proposal). With no time left there is no request.
expect {
	QueueSend.remaining({ started: 100, now: 100 }) == Send(5)
		and QueueSend.remaining({ started: 100, now: 101 }) == Send(4)
			and QueueSend.remaining({ started: 100, now: 104 }) == Send(1)
				and QueueSend.remaining({ started: 100, now: 105 }) == Stop
					and QueueSend.remaining({ started: 100, now: 900 }) == Stop
}

# R-AP10, R-AP23, R-AP45, R-CT1, R-CT2: the request. A POST to `<origin>/v1/compat`, `User-Agent` and `Content-Type`, then `Talon-Contributor` (the order is a proposal), never `Authorization`.
# The body has `rows` and `talon_version`; a row has `hash`, `nightly`, `result` and `target`, and no `error_digest` and no `source` (R-CT2). The `result` word is `pass`, `fail` or `crash`. The rows keep their order.
expect {
	id = "0123456789abcdeffedcba9876543210"
	rows = [
		queued({ hash: "HA", talon_version: version }),
		{ ..queued({ hash: "HB", talon_version: version }), result: Fail, target: "linux_x86_64" },
		{ ..queued({ hash: "HC", talon_version: version }), result: Crash },
	]
	req = QueueSend.request({ origin: "http://127.0.0.1:9", talon_version: version, contributor: id, rows, timeout_s: 3 })
	body = "{\"rows\":[{\"hash\":\"HA\",\"nightly\":\"nightly-2026-10-14-38a3029\",\"result\":\"pass\",\"target\":\"any\"},{\"hash\":\"HB\",\"nightly\":\"nightly-2026-10-14-38a3029\",\"result\":\"fail\",\"target\":\"linux_x86_64\"},{\"hash\":\"HC\",\"nightly\":\"nightly-2026-10-14-38a3029\",\"result\":\"crash\",\"target\":\"any\"}],\"talon_version\":\"0.9.0\"}"
	req.method == Post and req.url == "http://127.0.0.1:9/v1/compat" and req.timeout_s == 3 and req.body == body
		and req.headers == [("User-Agent", "tln/0.9.0"), ("Content-Type", "application/json"), ("Talon-Contributor", id)]
			and req.headers.all(|(name, _)| name != "Authorization")
}

reply : U16, Str -> QueueSend.Reply
reply = |status, body| Ok({ status, headers: [], body })

# R-SH4, R-SH6, R-CT4, R-CT14: a 200 or a 201 answer. All rows of the request leave (the rows in `skipped` too: the registry will not take them). The totals: `sent` is the number of rows of the request,
# `counted` is `written`, `first` is `first`. A request that was there already (`written` 0) is a 200 and the rows leave (R-CT4: a pair counts once). An unknown `reason` is a skip (R-AP44).
expect {
	answer : U64, U64, Str -> Str
	answer = |written, first, skipped| "{\"written\":${written.to_str()},\"first\":${first.to_str()},\"skipped\":[${skipped}]}"
	skips = "{\"row\":1,\"reason\":\"unknown-hash\"},{\"row\":2,\"reason\":\"a-new-reason\"}"
	QueueSend.settle({ count: 3, reply: reply(201, answer(3, 2, "")) }) == Leave({ sent: 3, counted: 3, first: 2 })
		and QueueSend.settle({ count: 3, reply: reply(200, answer(0, 0, "")) }) == Leave({ sent: 3, counted: 0, first: 0 })
			and QueueSend.settle({ count: 3, reply: reply(200, answer(1, 1, skips)) }) == Leave({ sent: 3, counted: 1, first: 1 })
				and QueueSend.settle({ count: 500, reply: reply(201, answer(400, 120, "")) }) == Leave({ sent: 500, counted: 400, first: 120 })
}

# R-SH4: "after a 4xx answer other than 429: the registry will not take that row." The rows leave and nothing is counted (R-SH6: `sent` is the rows of requests that got a 200 or a 201).
# The body of the answer is not read.
expect {
	gone = |status| QueueSend.settle({ count: 3, reply: reply(status, "{\"type\":\"about:blank\"}") }) == Leave({ sent: 0, counted: 0, first: 0 })
	gone(400) and gone(401) and gone(403) and gone(404) and gone(413) and gone(422) and gone(499) and gone(409)
}

# R-SH4, R-AP34, R-CT13: "after a 429 answer, a 5xx answer or no answer, the rows stay, and a later command sends them again."
expect {
	stays = |r| QueueSend.settle({ count: 3, reply: r }) == Stay
	stays(reply(429, "{}")) and stays(reply(500, "")) and stays(reply(502, "")) and stays(reply(503, "{}")) and stays(reply(599, "wrong header"))
		and stays(Err(Timeout)) and stays(Err(Failed("connection refused")))
}

# Q455: a status that R-SH4 does not name (1xx, 202, 204, 3xx) keeps the rows, as no answer does: only a 200, a 201 or another 4xx says what the registry did with them.
expect {
	stays = |status| QueueSend.settle({ count: 3, reply: reply(status, "{\"written\":3,\"first\":3,\"skipped\":[]}") }) == Stay
	stays(100) and stays(101) and stays(202) and stays(204) and stays(301) and stays(302) and stays(304) and stays(307)
}

# Q456, R-CT4: a 200 or a 201 whose body does not decode as the answer (R-AP51: the 3 members are required): the rows leave, `sent` counts them, `counted` and `first` add 0.
expect {
	took = |status, text| QueueSend.settle({ count: 3, reply: reply(status, text) }) == Leave({ sent: 3, counted: 0, first: 0 })
	took(200, "") and took(201, "not json") and took(200, "{\"written\":1}") and took(201, "[]") and took(200, "{\"written\":\"x\",\"first\":0,\"skipped\":[]}")
}

# Q454, R-SH4: whole seconds. The timeout of each request is the time that is left of the 5 s, at least 1 s: the values for 0 to 4 s are 5, 4, 3, 2, 1, and from 5 s there is no request (the real time of the send stays under 6 s).
expect {
	left = U64.to(0, 6).iter().map(|used| QueueSend.remaining({ started: 50, now: 50 + used })).collect()
	left == [Send(5), Send(4), Send(3), Send(2), Send(1), Stop, Stop]
}

# R-SH6: the totals of `share.json`. `sent`, `counted` and `first` are added. `first_sent_at` is set by the first send and stays; `last_sent_at` is the time of the last send. The id, the JWT, the account
# and a member that Talon does not know stay (R-TF2). The result is a valid file (`ShareJson.read` of its text gives it back).
expect {
	id = "0123456789abcdeffedcba9876543210"
	fresh = ShareJson.fresh(id)
	one = QueueSend.totals({ doc: fresh, add: { sent: 3, counted: 3, first: 2 }, now: "2026-11-03T10:05:00Z" })
	two = QueueSend.totals({ doc: one, add: { sent: 500, counted: 400, first: 120 }, now: "2026-11-03T11:00:00Z" })
	rich = {
		..fresh,
		sent: 7,
		counted: 6,
		first: 5,
		first_sent_at: Ok("2026-10-01T00:00:00Z"),
		token: Ok("jwt"),
		token_expires_at: Ok("2026-12-01T00:00:00Z"),
		account: Ok({ id: 42, login: "someone" }),
		extra: [("future", JsonDoc.Num(1))],
	}
	three = QueueSend.totals({ doc: rich, add: { sent: 1, counted: 1, first: 0 }, now: "2026-11-03T12:00:00Z" })
	one == { ..fresh, sent: 3, counted: 3, first: 2, first_sent_at: Ok("2026-11-03T10:05:00Z"), last_sent_at: Ok("2026-11-03T10:05:00Z") }
		and two == { ..fresh, sent: 503, counted: 403, first: 122, first_sent_at: Ok("2026-11-03T10:05:00Z"), last_sent_at: Ok("2026-11-03T11:00:00Z") }
			and three == { ..rich, sent: 8, counted: 7, first: 5, last_sent_at: Ok("2026-11-03T12:00:00Z") }
				and ShareJson.read({ path: "share.json", text: ShareJson.text(two) }) == Ok(two)
}
