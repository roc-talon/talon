import lib.Fail
import lib.JsonDoc
import lib.ShareAccount
import lib.ShareJson
import lib.ShareLogin

ShareaccountTest :: [].{}

# Slice 220 (CLI 1 R-SH8, R-SH9, R-SH10, R-SH13; Registry R-AP35, R-AP36, R-AP38, R-CT7, R-CT16; CLI 3 R-E6): the pure part of `tln share logout`, `tln share forget` and the account part of `tln share`.
# The flows are the L2 cases `share/sh33` to `share/sh39`. The texts and the `data` members are proposals for the review (R-OUT2, TW24). The facts in them are from R-SH8 and R-SH9.

registry = "http://127.0.0.1:9"

id = "0123456789abcdeffedcba9876543210"

reply : U16, Str -> ShareLogin.Reply
reply = |status, body| Ok({ status, headers: [], body })

# "ok", or the name of the kind of the failure.
kind_of : Try(a, Fail) -> Str
kind_of = |result| match result {
	Ok(_) => "ok"
	Err(fail) => fail.kind.name()
}

problem = |type, status| "{\"type\":\"${type}\",\"title\":\"T\",\"status\":${status},\"detail\":\"D\"}"

tracker_body = "{\"account\":{\"id\":583231,\"login\":\"octocat\"},\"machines\":2,\"counted\":9,\"first\":4,\"agreed\":3,\"disagreed\":1,\"unconfirmed\":5,\"first_time\":1791590400500,\"last_time\":1792152000000}"

tracker = {
	account: { id: 583231, login: "octocat" },
	machines: 2,
	counted: 9,
	first: 4,
	agreed: 3,
	disagreed: 1,
	unconfirmed: 5,
	first_time: Ok(1791590400500),
	last_time: Ok(1792152000000),
}

# R-SH8, R-AP35: `GET /v1/contributors/me` with `User-Agent` and `Authorization: Bearer <JWT>`, no body. No `Talon-Contributor` (R-SH5: the id goes only with the hints, the login and the delete).
expect {
	ShareAccount.tracker_request({ origin: registry, version: "0.9.0", token: "eyJ.jwt.sig" })
		== { method: Get, url: "${registry}/v1/contributors/me", headers: [("User-Agent", "tln/0.9.0"), ("Authorization", "Bearer eyJ.jwt.sig")], body: "", timeout_s: 20 }
}

# R-SH9, R-AP38: `DELETE /v1/tokens` with `User-Agent` and `Authorization: Bearer <JWT>`, no body.
expect {
	ShareAccount.logout_request({ origin: registry, version: "0.9.0", token: "eyJ.jwt.sig" })
		== { method: Delete, url: "${registry}/v1/tokens", headers: [("User-Agent", "tln/0.9.0"), ("Authorization", "Bearer eyJ.jwt.sig")], body: "", timeout_s: 20 }
}

# R-SH9, R-AP36, R-CT16 row 7, R-SH5: `DELETE /v1/contributors/me`. With a JWT: `Authorization` and no id. With no JWT: `Talon-Contributor: <id>` and no `Authorization`. Never both.
expect {
	by_account = ShareAccount.forget_request({ origin: registry, version: "0.9.0", proof: Account("eyJ.jwt.sig") })
	by_machine = ShareAccount.forget_request({ origin: registry, version: "0.9.0", proof: Machine(id) })
	by_account == { method: Delete, url: "${registry}/v1/contributors/me", headers: [("User-Agent", "tln/0.9.0"), ("Authorization", "Bearer eyJ.jwt.sig")], body: "", timeout_s: 20 }
		and by_machine == { method: Delete, url: "${registry}/v1/contributors/me", headers: [("User-Agent", "tln/0.9.0"), ("Talon-Contributor", id)], body: "", timeout_s: 20 }
}

# R-SH8, R-AP35, R-E6: the tracker answer. 200 with the body of R-CT10: the tracker. 401: `Stopped` (R-SH8: the JWT expired or stopped). A 200 body that does not decode, and no answer: kind `network` (15).
expect {
	run = |r| ShareAccount.tracker_answer({ origin: registry, version: "0.9.0", reply: r })
	bad = run(reply(200, "{\"account\":{\"id\":1,\"login\":\"a\"}}"))
	run(reply(200, tracker_body)) == Ok(Tracker(tracker))
		and run(reply(401, problem("/errors/unauthenticated", "401"))) == Ok(Stopped)
			and kind_of(bad) == "network" and (
				match bad {
					Err(fail) => fail.message.contains("tracker")
					Ok(_) => Bool.False
				}
			)
				and kind_of(run(Err(Timeout))) == "network"
}

# R-SH9, R-AP36, R-AP38, R-E6: the answer of a `DELETE`. 204 (any 2xx): `Done`. 401: `Stopped`. 400: kind `internal` (1). 429 and 503: `network` (15). No answer: `network` (15).
expect {
	run = |r| ShareAccount.delete_answer({ origin: registry, version: "0.9.0", reply: r })
	run(reply(204, "")) == Ok(Done)
		and run(reply(401, problem("/errors/unauthenticated", "401"))) == Ok(Stopped)
			and kind_of(run(reply(400, problem("/errors/bad-request", "400")))) == "internal"
				and kind_of(run(reply(429, problem("/errors/rate-limited", "429")))) == "network"
					and kind_of(run(reply(503, problem("/errors/busy", "503")))) == "network"
						and kind_of(run(Err(Failed("connection reset")))) == "network"
}

# R-SH13, R-SH8, Q488: the JWT of the file. No `token`: `None`. A `token` whose `token_expires_at` is after the clock: `Live`. One second before the time it is `Live`; at the time (equal) and after it, `Expired`.
expect {
	fresh = ShareJson.fresh(id)
	with_token = { ..fresh, token: Ok("eyJ.jwt.sig"), token_expires_at: Ok("2026-11-14T12:00:00Z"), account: Ok({ id: 1, login: "a" }) }
	ShareAccount.jwt({ doc: fresh, now: 1792065600 }) == None
		and ShareAccount.jwt({ doc: with_token, now: 1794657599 }) == Live("eyJ.jwt.sig")
			and ShareAccount.jwt({ doc: with_token, now: 1794657600 }) == Expired
				and ShareAccount.jwt({ doc: with_token, now: 1794657601 }) == Expired
}

# R-SH9, R-SH13: `logged_out` writes `null` to `token`, `token_expires_at` and `account`. The id, the totals, the times and the unknown members stay.
expect {
	doc = {
		..ShareJson.fresh(id),
		sent: 9,
		counted: 7,
		first: 2,
		first_sent_at: Ok("2026-10-01T00:00:00Z"),
		last_sent_at: Ok("2026-10-14T00:00:00Z"),
		token: Ok("eyJ.jwt.sig"),
		token_expires_at: Ok("2026-11-14T12:00:00Z"),
		account: Ok({ id: 583231, login: "octocat" }),
		extra: [("note", JsonDoc.Text("kept"))],
	}
	ShareAccount.logged_out(doc) == { ..doc, token: Err(Unset), token_expires_at: Err(Unset), account: Err(Unset) }
}

# R-SH9, R-SH13, R-SH5, R-TF2: `forgotten` writes the new id, 0 for the 3 totals and `null` for the other members. The unknown members stay (R-TF2).
expect {
	doc = {
		..ShareJson.fresh(id),
		sent: 9,
		counted: 7,
		first: 2,
		first_sent_at: Ok("2026-10-01T00:00:00Z"),
		last_sent_at: Ok("2026-10-14T00:00:00Z"),
		token: Ok("eyJ.jwt.sig"),
		token_expires_at: Ok("2026-11-14T12:00:00Z"),
		account: Ok({ id: 583231, login: "octocat" }),
		extra: [("note", JsonDoc.Text("kept"))],
	}
	new_id = "ffffffffffffffff0000000000000000"
	ShareAccount.forgotten({ doc, id: new_id }) == { ..ShareJson.fresh(new_id), extra: [("note", JsonDoc.Text("kept"))] }
}

# R-SH10: the text for the registry `direct` (kind `Usage`, exit 2) names the command. The text for `login` is the text of slice 219.
expect {
	ShareAccount.direct_text({ command: "logout" }) == "tln share logout needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
		and ShareAccount.direct_text({ command: "forget" }) == "tln share forget needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
			and ShareAccount.direct_text({ command: "login" }) == ShareLogin.login_direct({})
}

# R-SH8, R-AP35, R-OUT2: the lines and the `data` of the account part. The 2 times are in whole seconds (ms rounded down) and are left out when they are null.
expect {
	none = { ..tracker, first_time: Err(None), last_time: Err(None) }
	ShareAccount.account_lines(tracker)
		== [
			"account: octocat\n",
			"account machines: 2\n",
			"account counted: 9\n",
			"account first: 4\n",
			"account agreed: 3\n",
			"account disagreed: 1\n",
			"account unconfirmed: 5\n",
			"account first sent: 2026-10-10T00:00:00Z\n",
			"account last sent: 2026-10-16T12:00:00Z\n",
		]
		and ShareAccount.account_lines(none).len() == 7
			and JsonDoc.render(ShareAccount.account_data(tracker))
				== "{\"id\":583231,\"login\":\"octocat\",\"machines\":2,\"counted\":9,\"first\":4,\"agreed\":3,\"disagreed\":1,\"unconfirmed\":5,\"first_sent_at\":\"2026-10-10T00:00:00Z\",\"last_sent_at\":\"2026-10-16T12:00:00Z\"}"
				and JsonDoc.render(ShareAccount.account_data(none)).contains("\"first_sent_at\":null,\"last_sent_at\":null")
}

# R-SH8: after a 401 or a JWT past its time, the line is `run tln share login`.
expect {
	ShareAccount.login_needed_lines({}) == ["run tln share login\n"]
}

# R-SH9, R-OUT2, R-OUT4: the stdout and the `data` of `logout`.
expect {
	ShareAccount.logout_lines({}) == ["Logged out. Each token of the account stopped.\n"]
		and JsonDoc.render(ShareAccount.logout_data({})) == "{\"logged_out\":true}"
}

# R-SH9, R-CT7, R-OUT2, R-OUT4: the stdout and the `data` of `forget`. With a JWT the registry removed the account; with no JWT the results of this machine. Both say that the machine has a new id and totals of 0,
# and that the counts in `compat_hints` stay because they hold no id (the message that R-SH9 asks for).
expect {
	account = ShareAccount.forget_lines({ proof: Account })
	machine = ShareAccount.forget_lines({ proof: Machine })
	text = |lines| Str.join_with(lines, "")
	text(account).contains("removed the account") and text(machine).contains("sent before a login") and !text(machine).contains("removed the account")
		and [account, machine].all(|l| text(l).contains("compat_hints") and text(l).contains("new id") and text(l).contains("0") and text(l).contains("hold no id"))
			and JsonDoc.render(ShareAccount.forget_data({ proof: Account })) == "{\"removed\":\"account\"}"
				and JsonDoc.render(ShareAccount.forget_data({ proof: Machine })) == "{\"removed\":\"machine\"}"
}

# Q479, Q424, R-SH8: a 429 of the tracker read gives the wait time of `Retry-After` in the message (the warning of the status shows it).
expect {
	limited = Ok({ status: 429, headers: [("Retry-After", "7")], body: problem("/errors/rate-limited", "429") })
	match ShareAccount.tracker_answer({ origin: registry, version: "0.9.0", reply: limited }) {
		Err(fail) => fail.kind.name() == "network" and fail.message.contains("Try again in 7 s.")
		Ok(_) => Bool.False
	}
}

# Q481, R-SH9: `forget` with a 401 is kind `rejected` (exit 20) and says to run `tln share login`, and then `tln share forget`. `forget` with a JWT past its time is kind `usage` (exit 2, Q483) with the same advice.
expect {
	stopped = ShareAccount.forget_stopped({ origin: registry, reply: { status: 401, body: problem("/errors/unauthenticated", "401") } })
	plain = ShareAccount.forget_stopped({ origin: registry, reply: { status: 401, body: "x" } })
	expired = ShareAccount.forget_expired({})
	stopped.kind.name() == "rejected"
		and stopped.message == "the registry ${registry} refused the account delete (/errors/unauthenticated): D. Run tln share login, and then tln share forget."
			and plain.kind.name() == "rejected" and plain.message == "the registry ${registry} refused the account delete (401). Run tln share login, and then tln share forget."
				and expired.kind.name() == "usage" and expired.message == "the login has expired, so the registry cannot delete the account. Run tln share login, and then tln share forget."
}

# Q485, R-SH9: the text of `--offline` for `logout` and `forget` (kind `network`, exit 15, as `login`, Q476).
expect {
	ShareAccount.offline_text({ command: "logout" }) == "tln share logout needs the network, and --offline is set."
		and ShareAccount.offline_text({ command: "forget" }) == "tln share forget needs the network, and --offline is set."
}

# Q480, Q484, R-SH9, R-OUT2, R-OUT4: the stdout and the `data` of `logout` with no login, and of `forget` with no `share.json`.
expect {
	ShareAccount.no_login_lines({}) == ["There is no login on this machine.\n"]
		and JsonDoc.render(ShareAccount.no_login_data({})) == "{\"logged_out\":false}"
			and ShareAccount.nothing_to_forget_lines({}) == ["There is nothing to forget on this machine.\n"]
				and JsonDoc.render(ShareAccount.nothing_to_forget_data({})) == "{\"removed\":null}"
}

# Q477, Q488, R-SH8, R-OUT4: the members that the status `data` gets. Always `account` (`null` with no tracker). `login_needed` only when true, after `account`.
expect {
	with_tracker = ShareAccount.status_members(Tracker(tracker))
	ShareAccount.status_members(None) == [("account", JsonDoc.Null)]
		and ShareAccount.status_members(LoginNeeded) == [("account", JsonDoc.Null), ("login_needed", JsonDoc.Flag(Bool.True))]
			and with_tracker == [("account", ShareAccount.account_data(tracker))]
}
