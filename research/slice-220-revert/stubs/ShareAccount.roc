import records.Account
import Fail
import JsonDoc
import ShareJson

## `tln share logout`, `tln share forget` and the account part of `tln share` (slice 220; CLI 1 R-SH8, R-SH9, R-SH10, R-SH13; Registry R-AP35, R-AP36, R-AP38, R-CT7, R-CT16).
## The pure decisions are the functions below (tests/unit/ShareaccountTest.roc). The calls are in `ShareAccountFlow.logout!`, `ShareAccountFlow.forget!` and `ShareFlow.status_account!` (L2 cases `share/sh33` to `share/sh39`).
## This module imports neither `ShareFlow` nor `ShareLogin` (`ShareFlow` imports this module, and `ShareLogin` imports `ShareFlow`: an import cycle otherwise). All stubs are `crash "todo: slice 220"`. The flow is in the slice file `docs/slices/220-share-logout-forget.md` (section The flow).
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
	tracker_request = |_facts| crash "todo: slice 220"

	## R-AP38 (DELETE /v1/tokens): `<origin>/v1/tokens`, the headers of `tracker_request`. No body.
	logout_request : { origin : Str, version : Str, token : Str } -> ShareAccount.Request
	logout_request = |_facts| crash "todo: slice 220"

	## R-AP36, R-CT16 row 7 (DELETE /v1/contributors/me): `<origin>/v1/contributors/me`, `User-Agent`, then `Authorization: Bearer <JWT>` for `Account`, or `Talon-Contributor: <id>` for `Machine`. Never both. No body.
	forget_request : { origin : Str, version : Str, proof : ShareAccount.Proof } -> ShareAccount.Request
	forget_request = |_facts| crash "todo: slice 220"

	## R-AP35, R-SH8, R-E6: the answer of the tracker read. 200 with a body that `records.Account.decode_tracker` reads: `Ok(Tracker(..))`. 401: `Ok(Stopped)` (the JWT expired or stopped, R-SH8). No answer: `Registry.no_answer` (15).
	## Another status: `Registry.refuse` with the method `Get`. A 2xx body that does not decode: kind `Network` (15), R-E6 last row, the message has `tracker`. A 429 gives `Try again in <n> s.` from the header `Retry-After` of the reply (`Registry.retry_after_of`, Q424).
	tracker_answer : { origin : Str, version : Str, reply : ShareAccount.Reply } -> Try([Tracker(Account.Tracker), Stopped], Fail)
	tracker_answer = |_facts| crash "todo: slice 220"

	## R-AP36, R-AP38, R-E6: the answer of a `DELETE`. A 2xx status (the design names 204): `Ok(Done)`. 401: `Ok(Stopped)`. No answer: `Registry.no_answer` (15). Another status: `Registry.refuse` with the method `Delete` (400: 1, 429 and 5xx: 15).
	delete_answer : { origin : Str, version : Str, reply : ShareAccount.Reply } -> Try([Done, Stopped], Fail)
	delete_answer = |_facts| crash "todo: slice 220"

	## R-SH13 (the JWT past `token_expires_at` is not sent), R-SH8: what the JWT of `share.json` is now. `now` is the clock of `Fx` in seconds. `None`: no `token`. `Live(token)`: `token` is set and `token_expires_at` is after `now`
	## (also when `token_expires_at` is not set). `Expired`: `token_expires_at` is at or before `now` (equal is expired, Design Q488).
	jwt : { doc : ShareJson.Doc, now : U64 } -> [None, Live(Str), Expired]
	jwt = |_facts| crash "todo: slice 220"

	## R-SH9, R-SH13: `share.json` after `logout`: `token`, `token_expires_at` and `account` are `Unset`. Every other member stays (`id`, the totals, the times, `extra`).
	logged_out : ShareJson.Doc -> ShareJson.Doc
	logged_out = |_doc| crash "todo: slice 220"

	## R-SH9, R-SH13, R-SH5: `share.json` after `forget`: the new `id`, the 3 totals 0, and `Unset` for the 2 times, `token`, `token_expires_at` and `account`. `extra` stays (R-TF2). `id` is `ShareJson.id_of` of 2 `random!` numbers.
	forgotten : { doc : ShareJson.Doc, id : Str } -> ShareJson.Doc
	forgotten = |_facts| crash "todo: slice 220"

	## R-SH10: the `Usage` message (exit 2) for the registry `direct`: `tln share <command> needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.`
	## `command` is `login`, `logout` or `forget`. For `login` the text is `ShareLogin.login_direct`: the code agent makes `login_direct` call this function (the text does not change).
	direct_text : { command : Str } -> Str
	direct_text = |_facts| crash "todo: slice 220"

	## R-SH8 (proposal, R-OUT2): the lines of the account part of `tln share`, each with a line end, in this order: `account: <login>`, `account machines: <n>`, `account counted: <n>`, `account first: <n>`,
	## `account agreed: <n>`, `account disagreed: <n>`, `account unconfirmed: <n>`, then `account first sent: <time>` and `account last sent: <time>` only when the time is set (`first_time`, `last_time`
	## in ms, RFC 3339 text in whole seconds, rounded down, as `Clock.format_utc`).
	account_lines : Account.Tracker -> List(Str)
	account_lines = |_tracker| crash "todo: slice 220"

	## R-SH8 (proposal, R-OUT2): the member `account` of the `data` of `tln share --json` when the account part was read: `{"id":<id>,"login":"<login>","machines":<n>,"counted":<n>,"first":<n>,"agreed":<n>,
	## "disagreed":<n>,"unconfirmed":<n>,"first_sent_at":<text or null>,"last_sent_at":<text or null>}`. The flow appends `("account", <this>)` to the members of `Share.status_data`;
	account_data : Account.Tracker -> JsonDoc
	account_data = |_tracker| crash "todo: slice 220"

	## R-SH8: the line after a 401 or a JWT that is past its time: `run tln share login` with a line end. The JWT is removed first. The `--json` member `account` is then `null` (see `account_data`).
	login_needed_lines : {} -> List(Str)
	login_needed_lines = |_none| crash "todo: slice 220"

	## R-SH9 (proposal, R-OUT2): stdout after `logout`: `Logged out. Each token of the account stopped.` and the `data` `{"logged_out":true}`.
	logout_lines : {} -> List(Str)
	logout_lines = |_none| crash "todo: slice 220"

	logout_data : {} -> JsonDoc
	logout_data = |_none| crash "todo: slice 220"

	## R-SH9 (proposal, R-OUT2): stdout after `forget`, 3 lines with a line end. `Account`: `The registry removed the account, its results and the links of each machine to it.`
	## `Machine`: `The registry removed the results that this machine sent before a login.` Then `This machine has a new id, and its totals are 0.` Then
	## `The counts that went into compat_hints stay, because they hold no id.` The `data` is `{"removed":"account"}` or `{"removed":"machine"}`.
	forget_lines : { proof : [Account, Machine] } -> List(Str)
	forget_lines = |_facts| crash "todo: slice 220"

	forget_data : { proof : [Account, Machine] } -> JsonDoc
	forget_data = |_facts| crash "todo: slice 220"

	## Q481, R-SH9: the failure of `forget` when the registry answers 401 (`Stopped`). Kind `Rejected` (20). The message: `the registry <origin> refused the account delete (<type>): <detail>. Run tln share login, and then tln share forget.`
	## `type` and `detail` are those of the problem details of `reply` (`detail` is the `title` when it is empty). A body that is not problem details: `the registry <origin> refused the account delete (401). Run tln share login, and then tln share forget.`
	forget_stopped : { origin : Str, reply : { status : U16, body : Str } } -> Fail
	forget_stopped = |_facts| crash "todo: slice 220"

	## Q483, R-SH9: the failure of `forget` with a JWT past `token_expires_at` (no request). Kind `Usage` (exit 2). The message: `the login has expired, so the registry cannot delete the account. Run tln share login, and then tln share forget.`
	forget_expired : {} -> Fail
	forget_expired = |_none| crash "todo: slice 220"

	## Q485, R-SH9: the text of the `Network` failure (exit 15) of `logout` and `forget` with `--offline`: `tln share <command> needs the network, and --offline is set.`
	offline_text : { command : Str } -> Str
	offline_text = |_facts| crash "todo: slice 220"

	## Q480, R-SH9 (proposal): stdout of `logout` with no JWT or no `share.json`: `There is no login on this machine.` The `data` is `{"logged_out":false}`.
	no_login_lines : {} -> List(Str)
	no_login_lines = |_none| crash "todo: slice 220"

	no_login_data : {} -> JsonDoc
	no_login_data = |_none| crash "todo: slice 220"

	## Q484, R-SH9 (proposal): stdout of `forget` with no `share.json`: `There is nothing to forget on this machine.` The `data` is `{"removed":null}`.
	nothing_to_forget_lines : {} -> List(Str)
	nothing_to_forget_lines = |_none| crash "todo: slice 220"

	nothing_to_forget_data : {} -> JsonDoc
	nothing_to_forget_data = |_none| crash "todo: slice 220"

	## Q477, Q488, R-SH8 (proposal): the members that the flow appends to the members of `Share.status_data`, always. `None` (no JWT, direct, `--offline`, a failed `GET`): `("account", null)`.
	## `Tracker(t)`: `("account", account_data(t))`. `LoginNeeded` (a 401 or an expired JWT): `("account", null)` then `("login_needed", true)`. `login_needed` is left out otherwise.
	status_members : [None, Tracker(Account.Tracker), LoginNeeded] -> List((Str, JsonDoc))
	status_members = |_what| crash "todo: slice 220"
}
