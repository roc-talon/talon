import records.Account
import Clock
import Fail
import JsonDoc
import Registry
import ShareJson

## `tln share logout`, `tln share forget` and the account part of `tln share` (slice 220; CLI 1 R-SH8, R-SH9, R-SH10, R-SH13; Registry R-AP35, R-AP36, R-AP38, R-CT7, R-CT16).
## The pure decisions are the functions below (tests/unit/ShareaccountTest.roc). The calls are in `ShareAccountFlow.logout!`, `ShareAccountFlow.forget!` and `ShareFlow.status_account!` (L2 cases `share/sh33` to `share/sh39`).
## This module imports neither `ShareFlow` nor `ShareLogin` (`ShareFlow` imports this module, and `ShareLogin` imports `ShareFlow`: an import cycle otherwise). The flow is in the slice file `docs/slices/220-share-logout-forget.md` (section The flow).
## Reuse, no new helper for these: `ShareFlow.totals_write!` (the file write), `Registry.headers`, `Registry.refuse`, `Registry.no_answer`, `Registry.retry_after_of`, `ShareAccount.Request`, `ShareAccount.Reply`, `Clock.parse_utc`, `Clock.format_utc`.
ShareAccount :: [].{

	## The timeout of each of the 3 requests, in seconds (R-DA9, the value of `ShareLogin.timeout_s`).
	timeout_s : U64
	timeout_s = 20

	## The argument of `Fx.http_send!`. The same type as `ShareLogin.Request`, written again because `ShareLogin` imports `ShareFlow` and `ShareFlow` imports this module (an import cycle otherwise).
	## The code agent may make `ShareLogin` use these two types and `timeout_s`, so that there is one copy.
	Request : { method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 }

	## The answer of `Fx.http_send!`. The same type as `ShareLogin.Reply`.
	Reply : Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])

	## R-SH9, R-AP38: the proof of a `DELETE /v1/contributors/me` (R-AP36): `Account(<JWT>)` is `Authorization: Bearer <JWT>` and no id; `Machine(<id>)` is `Talon-Contributor: <id>` and no `Authorization`.
	Proof : [Account(Str), Machine(Str)]

	## R-AP35 (GET /v1/contributors/me): `<origin>/v1/contributors/me`, headers `Registry.headers({ version, body: None })` (`User-Agent: tln/<version>`) then `Authorization: Bearer <token>`. No body. No `Talon-Contributor` (R-SH5). `timeout_s` is `ShareAccount.timeout_s`.
	tracker_request : { origin : Str, version : Str, token : Str } -> ShareAccount.Request
	tracker_request = |facts| {
		method: Get,
		url: "${facts.origin}/v1/contributors/me",
		headers: Registry.headers({ version: facts.version, body: None }).append(("Authorization", "Bearer ${facts.token}")),
		body: "",
		timeout_s: ShareAccount.timeout_s,
	}

	## R-AP38 (DELETE /v1/tokens): `<origin>/v1/tokens`, the headers of `tracker_request`. No body.
	logout_request : { origin : Str, version : Str, token : Str } -> ShareAccount.Request
	logout_request = |facts| {
		method: Delete,
		url: "${facts.origin}/v1/tokens",
		headers: Registry.headers({ version: facts.version, body: None }).append(("Authorization", "Bearer ${facts.token}")),
		body: "",
		timeout_s: ShareAccount.timeout_s,
	}

	## R-AP36, R-CT16 row 7 (DELETE /v1/contributors/me): `<origin>/v1/contributors/me`, `User-Agent`, then `Authorization: Bearer <JWT>` for `Account`, or `Talon-Contributor: <id>` for `Machine`. Never both. No body.
	forget_request : { origin : Str, version : Str, proof : ShareAccount.Proof } -> ShareAccount.Request
	forget_request = |facts| {
		agent = Registry.headers({ version: facts.version, body: None })
		header = match facts.proof {
			Account(token) => ("Authorization", "Bearer ${token}")
			Machine(id) => ("Talon-Contributor", id)
		}
		{
			method: Delete,
			url: "${facts.origin}/v1/contributors/me",
			headers: agent.append(header),
			body: "",
			timeout_s: ShareAccount.timeout_s,
		}
	}

	## R-AP35, R-SH8, R-E6: the answer of the tracker read. 200 with a body that `records.Account.decode_tracker` reads: `Ok(Tracker(..))`. 401: `Ok(Stopped)` (the JWT expired or stopped, R-SH8). No answer: `Registry.no_answer` (15).
	## Another status: `Registry.refuse` with the method `Get`. A 2xx body that does not decode: kind `Network` (15), R-E6 last row, the message has `tracker`. A 429 gives `Try again in <n> s.` from the header `Retry-After` of the reply (`Registry.retry_after_of`, Q424).
	tracker_answer : { origin : Str, version : Str, reply : ShareAccount.Reply } -> Try([Tracker(Account.Tracker), Stopped], Fail)
	tracker_answer = |facts| match facts.reply {
		Err(Timeout) => Err(Registry.no_answer({ origin: facts.origin, why: "no answer in ${ShareAccount.timeout_s.to_str()} s" }))
		Err(Failed(why)) => Err(Registry.no_answer({ origin: facts.origin, why }))
		Ok(answer) => if answer.status >= 200 and answer.status <= 299 {
			match Account.decode_tracker(answer.body) {
				Ok(tracker) => Ok(Tracker(tracker))
				Err(BadJson(text)) => Err(Fail.new(Network, "the answer of the registry ${facts.origin} is not a tracker answer: ${text}"))
			}
		} else if answer.status == 401 {
			Ok(Stopped)
		} else {
			Err(refused(facts.origin, facts.version, Get, answer, ""))
		}
	}

	## R-AP36, R-AP38, R-E6: the answer of a `DELETE`. A 2xx status (the design names 204): `Ok(Done)`. 401: `Ok(Stopped)`. No answer: `Registry.no_answer` (15). Another status: `Registry.refuse` with the method `Delete` (400: 1, 429 and 5xx: 15).
	delete_answer : { origin : Str, version : Str, reply : ShareAccount.Reply, source ?: Str } -> Try([Done, Stopped], Fail)
	delete_answer = |facts| match facts.reply {
		Err(Timeout) => Err(Registry.no_answer({ origin: facts.origin, why: "no answer in ${ShareAccount.timeout_s.to_str()} s", source: facts.?source ?? "", needs: Bool.True }))
		Err(Failed(why)) => Err(Registry.no_answer({ origin: facts.origin, why, source: facts.?source ?? "", needs: Bool.True }))
		Ok(answer) => if answer.status >= 200 and answer.status <= 299 {
			Ok(Done)
		} else if answer.status == 401 {
			Ok(Stopped)
		} else {
			Err(refused(facts.origin, facts.version, Delete, answer, facts.?source ?? ""))
		}
	}

	## R-SH13 (the JWT past `token_expires_at` is not sent), R-SH8: what the JWT of `share.json` is now. `now` is the clock of `Fx` in seconds. `None`: no `token`. `Live(token)`: `token` is set and `token_expires_at` is after `now`
	## (also when `token_expires_at` is not set). `Expired`: `token_expires_at` is at or before `now` (equal is expired, Design Q488).
	jwt : { doc : ShareJson.Doc, now : U64 } -> [None, Live(Str), Expired]
	jwt = |facts| match facts.doc.token {
		Err(Unset) => None
		Ok(token) => match facts.doc.token_expires_at {
			Err(Unset) => Live(token)
			Ok(text) => match Clock.parse_utc(text) {
				Ok(ends) if ends <= facts.now => Expired
				_ => Live(token)
			}
		}
	}

	## R-SH9, R-SH13: `share.json` after `logout`: `token`, `token_expires_at` and `account` are `Unset`. Every other member stays (`id`, the totals, the times, `extra`).
	logged_out : ShareJson.Doc -> ShareJson.Doc
	logged_out = |doc| { ..doc, token: Err(Unset), token_expires_at: Err(Unset), account: Err(Unset) }

	## R-SH9, R-SH13, R-SH5: `share.json` after `forget`: the new `id`, the 3 totals 0, and `Unset` for the 2 times, `token`, `token_expires_at` and `account`. `extra` stays (R-TF2). `id` is `ShareJson.id_of` of 2 `random!` numbers.
	forgotten : { doc : ShareJson.Doc, id : Str } -> ShareJson.Doc
	forgotten = |facts| { ..ShareJson.fresh(facts.id), extra: facts.doc.extra }

	## R-SH10: the `Usage` message (exit 2) for the registry `direct`: `tln share <command> needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.`
	## `command` is `login`, `logout` or `forget`. `ShareLogin.login_direct` calls this function.
	direct_text : { command : Str } -> Str
	direct_text = |facts| "tln share ${facts.command} needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."

	## R-SH8 (proposal, R-OUT2): the lines of the account part of `tln share`, each with a line end, in this order: `account: <login>`, `account machines: <n>`, `account counted: <n>`, `account first: <n>`,
	## `account agreed: <n>`, `account disagreed: <n>`, `account unconfirmed: <n>`, then `account first sent: <time>` and `account last sent: <time>` only when the time is set (`first_time`, `last_time`
	## in ms, RFC 3339 text in whole seconds, rounded down, as `Clock.format_utc`).
	account_lines : Account.Tracker -> List(Str)
	account_lines = |tracker| {
		counts = [
			"account: ${tracker.account.login}\n",
			"account machines: ${tracker.machines.to_str()}\n",
			"account counted: ${tracker.counted.to_str()}\n",
			"account first: ${tracker.first.to_str()}\n",
			"account agreed: ${tracker.agreed.to_str()}\n",
			"account disagreed: ${tracker.disagreed.to_str()}\n",
			"account unconfirmed: ${tracker.unconfirmed.to_str()}\n",
		]
		first = match time_text(tracker.first_time) {
			Ok(text) => ["account first sent: ${text}\n"]
			Err(None) => []
		}
		last = match time_text(tracker.last_time) {
			Ok(text) => ["account last sent: ${text}\n"]
			Err(None) => []
		}
		counts.concat(first).concat(last)
	}

	## R-SH8 (proposal, R-OUT2): the member `account` of the `data` of `tln share --json` when the account part was read: `{"id":<id>,"login":"<login>","machines":<n>,"counted":<n>,"first":<n>,"agreed":<n>,
	## "disagreed":<n>,"unconfirmed":<n>,"first_sent_at":<text or null>,"last_sent_at":<text or null>}`.
	account_data : Account.Tracker -> JsonDoc
	account_data = |tracker| {
		time_doc = |ms| match time_text(ms) {
			Ok(text) => JsonDoc.Text(text)
			Err(None) => JsonDoc.Null
		}
		JsonDoc.Obj([
			("id", JsonDoc.Num(tracker.account.id.to_i64_wrap())),
			("login", JsonDoc.Text(tracker.account.login)),
			("machines", num(tracker.machines)),
			("counted", num(tracker.counted)),
			("first", num(tracker.first)),
			("agreed", num(tracker.agreed)),
			("disagreed", num(tracker.disagreed)),
			("unconfirmed", num(tracker.unconfirmed)),
			("first_sent_at", time_doc(tracker.first_time)),
			("last_sent_at", time_doc(tracker.last_time)),
		])
	}

	## R-SH8: the line after a 401 or a JWT that is past its time: `run tln share login` with a line end. The JWT is removed first. The `--json` member `account` is then `null` (see `account_data`).
	login_needed_lines : {} -> List(Str)
	login_needed_lines = |_none| ["run tln share login\n"]

	## R-SH9 (proposal, R-OUT2): stdout after `logout`: `Logged out. Each token of the account stopped.` and the `data` `{"logged_out":true}`.
	logout_lines : {} -> List(Str)
	logout_lines = |_none| ["Logged out. Each token of the account stopped.\n"]

	logout_data : {} -> JsonDoc
	logout_data = |_none| JsonDoc.Obj([("logged_out", JsonDoc.Flag(Bool.True))])

	## R-SH9 (proposal, R-OUT2): stdout after `forget`, 3 lines with a line end. `Account`: `The registry removed the account, its results and the links of each machine to it.`
	## `Machine`: `The registry removed the results that this machine sent before a login.` Then `This machine has a new id, and its totals are 0.` Then
	## `The counts that went into compat_hints stay, because they hold no id.` The `data` is `{"removed":"account"}` or `{"removed":"machine"}`.
	forget_lines : { proof : [Account, Machine] } -> List(Str)
	forget_lines = |facts| {
		first = match facts.proof {
			Account => "The registry removed the account, its results and the links of each machine to it.\n"
			Machine => "The registry removed the results that this machine sent before a login.\n"
		}
		[first, "This machine has a new id, and its totals are 0.\n", "The counts that went into compat_hints stay, because they hold no id.\n"]
	}

	forget_data : { proof : [Account, Machine] } -> JsonDoc
	forget_data = |facts| {
		word = match facts.proof {
			Account => "account"
			Machine => "machine"
		}
		JsonDoc.Obj([("removed", JsonDoc.Text(word))])
	}

	## Q481, R-SH9: the failure of `forget` when the registry answers 401 (`Stopped`). Kind `Rejected` (20). The message: `the registry <origin> refused the account delete (<type>): <detail>. Run tln share login, and then tln share forget.`
	## `type` and `detail` are those of the problem details of `reply` (`detail` is the `title` when it is empty). A body that is not problem details: `the registry <origin> refused the account delete (401). Run tln share login, and then tln share forget.`
	forget_stopped : { origin : Str, reply : { status : U16, body : Str } } -> Fail
	forget_stopped = |facts| {
		advice = "Run tln share login, and then tln share forget."
		message = match Registry.problem(facts.reply) {
			Ok(body) => {
				what = if body.detail.is_empty() body.title else body.detail
				"the registry ${facts.origin} refused the account delete (${body.type_text}): ${what}. ${advice}"
			}
			Err(NotProblem) => "the registry ${facts.origin} refused the account delete (${facts.reply.status.to_str()}). ${advice}"
		}
		Fail.new(Rejected, message)
	}

	## Q483, R-SH9: the failure of `forget` with a JWT past `token_expires_at` (no request). Kind `Usage` (exit 2).
	forget_expired : {} -> Fail
	forget_expired = |_none| Fail.new(Usage, "the login has expired, so the registry cannot delete the account. Run tln share login, and then tln share forget.")

	## Q485, R-SH9: the text of the `Network` failure (exit 15) of `logout` and `forget` with `--offline`.
	offline_text : { command : Str } -> Str
	offline_text = |facts| "tln share ${facts.command} needs the network, and --offline is set."

	## Q480, R-SH9 (proposal): stdout of `logout` with no JWT or no `share.json`. The `data` is `{"logged_out":false}`.
	no_login_lines : {} -> List(Str)
	no_login_lines = |_none| ["There is no login on this machine.\n"]

	no_login_data : {} -> JsonDoc
	no_login_data = |_none| JsonDoc.Obj([("logged_out", JsonDoc.Flag(Bool.False))])

	## Q484, R-SH9 (proposal): stdout of `forget` with no `share.json`. The `data` is `{"removed":null}`.
	nothing_to_forget_lines : {} -> List(Str)
	nothing_to_forget_lines = |_none| ["There is nothing to forget on this machine.\n"]

	nothing_to_forget_data : {} -> JsonDoc
	nothing_to_forget_data = |_none| JsonDoc.Obj([("removed", JsonDoc.Null)])

	## Q477, Q488, R-SH8 (proposal): the members that the flow appends to the members of `Share.status_data`, always. `None` (no JWT, direct, `--offline`, a failed `GET`): `("account", null)`.
	## `Tracker(t)`: `("account", account_data(t))`. `LoginNeeded` (a 401 or an expired JWT): `("account", null)` then `("login_needed", true)`. `login_needed` is left out otherwise.
	status_members : [None, Tracker(Account.Tracker), LoginNeeded] -> List((Str, JsonDoc))
	status_members = |what| match what {
		None => [("account", JsonDoc.Null)]
		Tracker(tracker) => [("account", ShareAccount.account_data(tracker))]
		LoginNeeded => [("account", JsonDoc.Null), ("login_needed", JsonDoc.Flag(Bool.True))]
	}
}

num : U64 -> JsonDoc
num = |n| JsonDoc.Num(n.to_i64_wrap())

# A time in ms as RFC 3339 text in whole seconds, rounded down.
time_text : Try(U64, [None]) -> Try(Str, [None])
time_text = |ms| match ms {
	Ok(value) => Ok(Clock.format_utc(value // 1000))
	Err(None) => Err(None)
}

# Another status than 2xx and 401: `Registry.refuse` with the `Retry-After` of the answer.
refused : Str, Str, Registry.Method, { status : U16, headers : List((Str, Str)), body : Str }, Str -> Fail
refused = |origin, version, method, answer, source| Registry.refuse({ origin, version, method, reply: { status: answer.status, body: answer.body }, retry_after: Registry.retry_after_of(answer.headers), source, needs: Bool.True })
