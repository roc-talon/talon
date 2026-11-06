import lib.Fail
import lib.JsonDoc
import lib.ShareJson
import lib.ShareLogin

ShareloginTest :: [].{}

# Slice 219 (CLI 1 R-SH7, R-SH10, R-SH12, R-SH13, R-EV28; Registry R-AP37, R-CT8; CLI 3 R-EC13, R-E6): the pure part of `tln share login`. The flow is the L2 cases `share/sh23` to `share/sh29`.
# The texts (`intro_lines`, `code_lines`, `done_lines`, `done_data`, `login_direct`) are proposals for the review (R-OUT2, TW24). The facts in them are from R-SH7.

gh = "http://127.0.0.1:8"

registry = "http://127.0.0.1:9"

form = "application/x-www-form-urlencoded"

grant = "urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code"

reply : U16, Str -> ShareLogin.Reply
reply = |status, body| Ok({ status, headers: [], body })

# "ok", or the name of the kind of the failure.
kind_of : Try(a, Fail) -> Str
kind_of = |result| match result {
	Ok(_) => "ok"
	Err(fail) => fail.kind.name()
}

message_of : Try(a, Fail) -> Str
message_of = |result| match result {
	Ok(_) => ""
	Err(fail) => fail.message
}

code_body = |extra| "{\"device_code\":\"DC1\",\"user_code\":\"WDJB-MJHT\",\"verification_uri\":\"https://github.com/login/device\",\"expires_in\":900${extra}}"

problem = |type, status| "{\"type\":\"${type}\",\"title\":\"T\",\"status\":${status},\"detail\":\"D\"}"

# R-CT8 row 1: the client id of the OAuth App `Talon` is a constant of the binary.
expect {
	ShareLogin.client_id == "Ov23li2sxWgMaAvjaUbQ" and ShareLogin.default_web == "https://github.com"
}

# R-EV28: `TALON_GITHUB_WEB` replaces `https://github.com`. Not set, or empty, gives the default. The name is exact (`TALON_GITHUB_API` is another hook).
expect {
	ShareLogin.web_of([("HOME", "/h")]) == "https://github.com"
		and ShareLogin.web_of([("TALON_GITHUB_WEB", gh)]) == gh
			and ShareLogin.web_of([("TALON_GITHUB_WEB", "")]) == "https://github.com"
				and ShareLogin.web_of([("TALON_GITHUB_API", gh)]) == "https://github.com"
}

# R-SH12 row 1, Q471: `POST <web>/login/device/code`, `Accept: application/json`, `User-Agent: tln/<version>` (after `Accept`), a form body with `client_id` and no `scope`.
expect {
	req = ShareLogin.code_request({ web: gh, version: "0.9.0" })
	req == { method: Post, url: "${gh}/login/device/code", headers: [("Accept", "application/json"), ("User-Agent", "tln/0.9.0"), ("Content-Type", form)], body: "client_id=Ov23li2sxWgMaAvjaUbQ", timeout_s: 20 }
		and !req.body.contains("scope")
}

# R-SH12 row 3: the poll has `client_id`, `device_code` and the `grant_type` (form encoded). The device code is encoded.
expect {
	req = ShareLogin.poll_request({ web: gh, device_code: "3584d83530", version: "0.9.0" })
	odd = ShareLogin.poll_request({ web: gh, device_code: "a b&c", version: "0.9.0" })
	req == { method: Post, url: "${gh}/login/oauth/access_token", headers: [("Accept", "application/json"), ("User-Agent", "tln/0.9.0"), ("Content-Type", form)], body: "client_id=Ov23li2sxWgMaAvjaUbQ&device_code=3584d83530&grant_type=${grant}", timeout_s: 20 }
		and odd.body == "client_id=Ov23li2sxWgMaAvjaUbQ&device_code=a%20b%26c&grant_type=${grant}"
}

# R-SH7: the text before the code. It tells: the login ties this machine to the GitHub account; the results that it sent before move to the account; the next ones count for it; the registry keeps them until
# `tln share forget`, or until their compiler is 12 months old, and then keeps only the totals. It has no URL and no code (they come after it).
expect {
	text = Str.join_with(ShareLogin.intro_lines({}), "")
	text.contains("GitHub account") and text.contains("machine") and text.contains("before") and text.contains("`tln share forget`") and text.contains("12 months") and text.contains("totals")
		and !text.contains("https://") and !text.contains("login/device")
}

# R-SH7, R-SH12 row 1: the lines of the code (each ends with a line end, as the lines of `Share`): `<web>/login/device` and the `user_code`. The `verification_uri` of the answer is not shown.
expect {
	ShareLogin.code_lines({ web: gh, user_code: "WDJB-MJHT" }) == ["Open ${gh}/login/device\n", "Enter the code: WDJB-MJHT\n", "Talon waits until you approve the code in GitHub.\n"]
		and ShareLogin.code_lines({ web: "https://github.com", user_code: "AB-12" }).first() == Ok("Open https://github.com/login/device\n")
}

# R-SH12 rows 1, 2, 7: a good answer. `ends` is the clock value plus `expires_in`. No `interval` is 5 s, and 0 is used as it is.
expect {
	five = ShareLogin.code_answer({ reply: reply(200, code_body(",\"interval\":7")), now: 1000 })
	none = ShareLogin.code_answer({ reply: reply(200, code_body("")), now: 1000 })
	zero = ShareLogin.code_answer({ reply: reply(200, code_body(",\"interval\":0")), now: 50 })
	five == Ok({ device_code: "DC1", user_code: "WDJB-MJHT", interval: 7, ends: 1900 })
		and none == Ok({ device_code: "DC1", user_code: "WDJB-MJHT", interval: 5, ends: 1900 })
			and zero == Ok({ device_code: "DC1", user_code: "WDJB-MJHT", interval: 0, ends: 950 })
}

# R-SH12 row 10, R-SH7: no answer, a 5xx answer, a body that is not JSON: kind `Network` (exit 15).
expect {
	kind_of(ShareLogin.code_answer({ reply: Err(Timeout), now: 1 })) == "network"
		and kind_of(ShareLogin.code_answer({ reply: Err(Failed("refused")), now: 1 })) == "network"
			and kind_of(ShareLogin.code_answer({ reply: reply(503, code_body(",\"interval\":1")), now: 1 })) == "network"
				and kind_of(ShareLogin.code_answer({ reply: reply(502, "bad gateway"), now: 1 })) == "network"
					and kind_of(ShareLogin.code_answer({ reply: reply(200, "<html>login</html>"), now: 1 })) == "network"
}

# R-SH12 row 9: another `error` (the client id or the code of Talon is wrong) is kind `Internal` (exit 1), and the message has the `error` text.
expect {
	off = ShareLogin.code_answer({ reply: reply(200, "{\"error\":\"device_flow_disabled\",\"error_description\":\"x\"}"), now: 1 })
	bad = ShareLogin.code_answer({ reply: reply(200, "{\"error\":\"incorrect_client_credentials\"}"), now: 1 })
	kind_of(off) == "internal" and message_of(off).contains("device_flow_disabled")
		and kind_of(bad) == "internal" and message_of(bad).contains("incorrect_client_credentials")
}

# R-SH12 rows 4 and 8: a pending answer waits the same time again. A token ends the loop.
expect {
	pending = ShareLogin.poll_answer({ reply: reply(200, "{\"error\":\"authorization_pending\"}"), wait: 7 })
	zero = ShareLogin.poll_answer({ reply: reply(200, "{\"error\":\"authorization_pending\"}"), wait: 0 })
	token = ShareLogin.poll_answer({ reply: reply(200, "{\"access_token\":\"gho_x\",\"token_type\":\"bearer\",\"scope\":\"\"}"), wait: 7 })
	pending == Ok(Wait(7)) and zero == Ok(Wait(0)) and token == Ok(Token("gho_x"))
}

# R-SH12 row 5 (RFC 8628 3.5): `slow_down` with an `interval` takes it, also a smaller one; with no `interval` the wait grows by 5 s, also from 0.
expect {
	body = |extra| "{\"error\":\"slow_down\"${extra}}"
	slower = ShareLogin.poll_answer({ reply: reply(200, body(",\"interval\":12")), wait: 7 })
	smaller = ShareLogin.poll_answer({ reply: reply(200, body(",\"interval\":2")), wait: 7 })
	without = ShareLogin.poll_answer({ reply: reply(200, body("")), wait: 7 })
	from_zero = ShareLogin.poll_answer({ reply: reply(200, body("")), wait: 0 })
	slower == Ok(Wait(12)) and smaller == Ok(Wait(2)) and without == Ok(Wait(12)) and from_zero == Ok(Wait(5))
}

# R-SH12 rows 6, 7, R-SH7, R-EC13: `access_denied` and `expired_token` are kind `Consent` (exit 13).
expect {
	denied = ShareLogin.poll_answer({ reply: reply(200, "{\"error\":\"access_denied\"}"), wait: 5 })
	expired = ShareLogin.poll_answer({ reply: reply(200, "{\"error\":\"expired_token\"}"), wait: 5 })
	kind_of(denied) == "consent" and kind_of(expired) == "consent"
}

# R-SH12 row 9: each other `error` is kind `Internal` (exit 1) with the text in the message.
expect {
	one = |text| ShareLogin.poll_answer({ reply: reply(200, "{\"error\":\"${text}\"}"), wait: 5 })
	texts = ["device_flow_disabled", "incorrect_client_credentials", "incorrect_device_code", "unsupported_grant_type", "what_is_this"]
	texts.all(|t| kind_of(one(t)) == "internal" and message_of(one(t)).contains(t))
}

# R-SH12 row 10, R-SH7: no answer, a 5xx answer (also with a good looking body), a body that is not JSON: kind `Network` (exit 15).
expect {
	kind_of(ShareLogin.poll_answer({ reply: Err(Timeout), wait: 5 })) == "network"
		and kind_of(ShareLogin.poll_answer({ reply: Err(Failed("reset")), wait: 5 })) == "network"
			and kind_of(ShareLogin.poll_answer({ reply: reply(500, "{\"access_token\":\"gho_x\"}"), wait: 5 })) == "network"
				and kind_of(ShareLogin.poll_answer({ reply: reply(503, "{\"error\":\"authorization_pending\"}"), wait: 5 })) == "network"
					and kind_of(ShareLogin.poll_answer({ reply: reply(200, "not json"), wait: 5 })) == "network"
}

# R-SH12 row 7: `expires_in` seconds passed since the answer: `now` is at the end time or after it. One second before, the poll goes.
expect {
	!ShareLogin.expired({ now: 1000, ends: 1900 }) and !ShareLogin.expired({ now: 1899, ends: 1900 })
		and ShareLogin.expired({ now: 1900, ends: 1900 }) and ShareLogin.expired({ now: 5000, ends: 1900 })
			and ShareLogin.expired({ now: 7, ends: 7 })
}

# R-SH7, R-AP37, R-SH5, R-CT8: `POST <registry>/v1/tokens` with the User-Agent, the JSON type and the contributor id (no `Authorization`: the GitHub token is in the body). The body is `{"github_token":".."}`.
expect {
	req = ShareLogin.token_request({ origin: registry, version: "0.9.0", contributor: "0123456789abcdeffedcba9876543210", github_token: "gho_x" })
	req == {
		method: Post,
		url: "${registry}/v1/tokens",
		headers: [("User-Agent", "tln/0.9.0"), ("Content-Type", "application/json"), ("Talon-Contributor", "0123456789abcdeffedcba9876543210")],
		body: "{\"github_token\":\"gho_x\"}",
		timeout_s: 20,
	}
		and !req.headers.any(|(name, _)| name.with_ascii_lowercased() == "authorization")
}

granted_body = "{\"account\":{\"id\":583231,\"login\":\"octocat\"},\"expires_at\":1794657600000,\"token\":\"eyJ.jwt.sig\"}"

# R-AP37: the 201 answer. The token, the expiry in ms and the account are kept.
expect {
	ShareLogin.token_answer({ origin: registry, version: "0.9.0", reply: reply(201, granted_body) })
		== Ok({ token: "eyJ.jwt.sig", expires_at: 1794657600000, account: { id: 583231, login: "octocat" } })
}

# R-AP37, R-E6, R-SH7: GitHub refuses the token (401): `Rejected` (20). 400: `Internal` (1). 429, 502 `upstream`, 503, no answer, a 2xx body that does not decode, and a non-problem body: `Network` (15).
expect {
	run = |r| ShareLogin.token_answer({ origin: registry, version: "0.9.0", reply: r })
	kind_of(run(reply(401, problem("/errors/unauthenticated", "401")))) == "rejected"
		and kind_of(run(reply(400, problem("/errors/bad-request", "400")))) == "internal"
			and kind_of(run(reply(429, problem("/errors/rate-limited", "429")))) == "network"
				and kind_of(run(reply(502, problem("/errors/upstream", "502")))) == "network"
					and kind_of(run(reply(503, problem("/errors/busy", "503")))) == "network"
						and kind_of(run(Err(Timeout))) == "network"
							and kind_of(run(Err(Failed("refused")))) == "network"
								and kind_of(run(reply(201, "{\"token\":\"x\"}"))) == "network"
									and kind_of(run(reply(201, "not json"))) == "network"
										and kind_of(run(reply(502, "<html>"))) == "network"
}

# R-SH7, R-TF1, R-TF2, R-SH13: `stored` puts the JWT, its expiry (whole seconds, RFC 3339 UTC) and the account in the file. The id, the totals, the times and the unknown members stay. A login again replaces the token and the account.
expect {
	granted = { token: "eyJ.jwt.sig", expires_at: 1794657600000, account: { id: 583231, login: "octocat" } }
	fresh = ShareJson.fresh("0123456789abcdeffedcba9876543210")
	doc = { ..fresh, sent: 9, counted: 7, first: 2, first_sent_at: Ok("2026-10-01T00:00:00Z"), last_sent_at: Ok("2026-10-14T00:00:00Z"), extra: [("note", JsonDoc.Text("kept"))] }
	after = ShareLogin.stored({ doc, granted })
	again = ShareLogin.stored({ doc: after, granted: { token: "new.jwt", expires_at: 1795659000000, account: { id: 7, login: "other" } } })
	ShareJson.text(ShareLogin.stored({ doc: fresh, granted }))
		== "{\"format\":1,\"id\":\"0123456789abcdeffedcba9876543210\",\"sent\":0,\"counted\":0,\"first\":0,\"first_sent_at\":null,\"last_sent_at\":null,\"token\":\"eyJ.jwt.sig\",\"token_expires_at\":\"2026-11-14T12:00:00Z\",\"account\":{\"id\":583231,\"login\":\"octocat\"}}\n"
		and after == { ..doc, token: Ok("eyJ.jwt.sig"), token_expires_at: Ok("2026-11-14T12:00:00Z"), account: Ok({ id: 583231, login: "octocat" }) }
			and again == { ..doc, token: Ok("new.jwt"), token_expires_at: Ok("2026-11-26T02:10:00Z"), account: Ok({ id: 7, login: "other" }) }
}

# R-SH10: the text for the registry `direct` (kind `Usage`, exit 2) says that the command needs a registry. R-OUT2: a proposal.
expect {
	ShareLogin.login_direct({}) == "tln share login needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
}

# R-SH7, R-OUT2, R-OUT4: the stdout after a login, and the `data` of `--json` (the account and the expiry, no token). A login does not turn sharing on, and the text says nothing of it.
expect {
	data = JsonDoc.render(ShareLogin.done_data({ account: { id: 583231, login: "octocat" }, token_expires_at: "2026-11-14T12:00:00Z" }))
	ShareLogin.done_lines({ login: "octocat" }) == ["Logged in as octocat.\n"]
		and data == "{\"account\":{\"id\":583231,\"login\":\"octocat\"},\"token_expires_at\":\"2026-11-14T12:00:00Z\"}"
}

# Q474: `expires_at` in ms is rounded down to whole seconds: 1794657600500 ms is 1794657600 s.
expect {
	granted = { token: "t", expires_at: 1794657600500, account: { id: 1, login: "a" } }
	almost = { token: "t", expires_at: 1794657600999, account: { id: 1, login: "a" } }
	ShareLogin.stored({ doc: ShareJson.fresh("0123456789abcdeffedcba9876543210"), granted }).token_expires_at == Ok("2026-11-14T12:00:00Z")
		and ShareLogin.stored({ doc: ShareJson.fresh("0123456789abcdeffedcba9876543210"), granted: almost }).token_expires_at == Ok("2026-11-14T12:00:00Z")
}

# Q475, R-SH12 row 11: a 2xx JSON answer of the code request that misses `device_code`, `user_code` or `expires_in` (also a member of the wrong type, and an empty object) is kind `network` (exit 15). The message names the step.
expect {
	bodies = [
		"{\"user_code\":\"A-B\",\"expires_in\":900}",
		"{\"device_code\":\"DC1\",\"expires_in\":900}",
		"{\"device_code\":\"DC1\",\"user_code\":\"A-B\"}",
		"{\"device_code\":\"DC1\",\"user_code\":\"A-B\",\"expires_in\":\"900\"}",
		"{}",
	]
	bodies.all(
		|b| {
			r = ShareLogin.code_answer({ reply: reply(200, b), now: 1 })
			kind_of(r) == "network" and message_of(r).contains("code request")
		},
	)
}

# Q475, R-SH12 row 11: a poll answer with neither `error` nor `access_token` is kind `network`, and the message names the poll. A token answer with no `token` (or no `expires_at`, or no `account`) is kind `network`, and the message names the registry login.
expect {
	poll = ShareLogin.poll_answer({ reply: reply(200, "{\"token_type\":\"bearer\"}"), wait: 5 })
	empty = ShareLogin.poll_answer({ reply: reply(200, "{}"), wait: 5 })
	run = |b| ShareLogin.token_answer({ origin: registry, version: "0.9.0", reply: reply(201, b) })
	bodies = [
		"{\"account\":{\"id\":1,\"login\":\"a\"},\"expires_at\":1794657600000}",
		"{\"token\":\"t\",\"account\":{\"id\":1,\"login\":\"a\"}}",
		"{\"token\":\"t\",\"expires_at\":1794657600000}",
	]
	kind_of(poll) == "network" and message_of(poll).contains("poll") and kind_of(empty) == "network" and message_of(empty).contains("poll")
		and bodies.all(|b| kind_of(run(b)) == "network" and message_of(run(b)).contains("registry login"))
}

# Q476: `--offline` is kind `network` (exit 15) with the text that the login needs the network. R-OUT2: a proposal.
expect {
	ShareLogin.login_offline({}) == "tln share login needs the network, and --offline is set."
}
