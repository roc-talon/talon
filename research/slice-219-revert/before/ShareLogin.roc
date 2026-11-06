import Args
import Fail
import Fx
import JsonDoc
import ShareJson

## `tln share login` (slice 219; CLI 1 R-SH7, R-SH10, R-SH12, R-SH13, R-EV28; Registry R-AP37, R-CT8; CLI 3 R-EC13). The GitHub device flow, then `POST /v1/tokens`, then the JWT in `share.json`.
## The pure decisions are the functions below (tests/unit/ShareloginTest.roc). `login!` orders the calls (L2 cases `share/sh23` to `share/sh29`).
##
## | Step of `login!` | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Roots.of_run!` | |
## | 2 | `read_files!` of `config.toml` (a missing file is the empty text), `Share.setting`, `Net.registry`. `Direct`: failure of kind `Usage` (exit 2) with `login_direct`, and no other call. | R-SH10 |
## | 3 | `read_files!` of `share.json`, `ShareJson.read` (the id; a failure is exit 19 and no request goes). A missing file: question Q1 of the slice file (no test). | R-SH5, R-TF3, R-TF6 |
## | 4 | `intro_lines` to stderr (R-J2: progress is human text on stderr, also without `--json`). | R-SH7 |
## | 5 | `http_send!` of `code_request` (`web_of` of the environment), `clock!` (the start), `code_answer`. A failure ends the command. Then `code_lines` to stderr. | R-SH12 rows 1, 7 |
## | 6 | The poll loop. Each turn: `sleep!` of `wait` seconds in ms (also `sleep 0`), `clock!`, `expired` (true: failure of kind `Consent`, exit 13, and no poll), `http_send!` of `poll_request`, `poll_answer`. `Wait(n)` sets `wait` to `n` and goes on. `Token` leaves the loop. | R-SH12 rows 2 to 7, 9, 10 |
## | 7 | `http_send!` of `token_request` with the registry `origin` and the id of step 3, `token_answer`. | R-SH7, R-AP37 |
## | 8 | `Fx.locked!` on `share.json`: `read_files!`, `stored`, the write of 213b (`random!` for the temp name, `write_atomic!`, `chmod 0600`, `rename!`). `ShareFlow.totals_write!` is this step. | R-SH5, R-SH13 |
## | 9 | stdout: `done_lines`, or with `--json` only the envelope with `done_data`. | R-OUT2, R-OUT4 |
##
## The GitHub token is only in memory: it is in the body of the one request of step 7 and nowhere else (no file, no output, no message).
ShareLogin :: [].{

	## Registry R-CT8 row 1: the client id of the OAuth App `Talon`. A constant of the binary.
	client_id : Str
	client_id = "Ov23li2sxWgMaAvjaUbQ"

	## R-SH12, R-EV28: the base URL of the 2 device flow requests when `TALON_GITHUB_WEB` is not set.
	default_web : Str
	default_web = "https://github.com"

	## The timeout of each of the 3 requests, in seconds (a proposal, R-OUT2: the value of the closure query, ClosureIndex.query_timeout_s, R-DA9).
	timeout_s : U64
	timeout_s = 20

	## The answer of `Fx.http_send!`.
	Reply : Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])

	Request : { method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 }

	## The answer of step 1 of R-SH12, kept: `interval` in seconds (5 when the answer has none), `ends` is the clock value of the answer plus `expires_in`.
	Code : { device_code : Str, user_code : Str, interval : U64, ends : U64 }

	## The answer of R-AP37: the JWT, `expires_at` in milliseconds (R-AP50), the account.
	Granted : { token : Str, expires_at : U64, account : { id : U64, login : Str } }

	## R-EV28: `TALON_GITHUB_WEB` when it is set and not empty, else `default_web`.
	web_of : List((Str, Str)) -> Str
	web_of = |_env| crash "todo: slice 219"

	## R-SH7: the text before the code. It says that a login ties this machine to the GitHub account, that the results sent before move to the account and the next ones count for it, that the registry keeps them
	## until `tln share forget` or until their compiler is 12 months old (then only the totals). It has no URL and no code. Proposal for the review (R-OUT2).
	## Each line of `intro_lines`, `code_lines` and `done_lines` ends with `\n`, as the lines of `Share`.
	intro_lines : {} -> List(Str)
	intro_lines = |_none| crash "todo: slice 219"

	## R-SH7, R-SH12 row 1: the lines with `<web>/login/device` and the `user_code` (not the `verification_uri` of the answer). Proposal for the review (R-OUT2).
	code_lines : { web : Str, user_code : Str } -> List(Str)
	code_lines = |_facts| crash "todo: slice 219"

	## R-SH12 row 1: `POST <web>/login/device/code`, headers `Accept: application/json` and `Content-Type: application/x-www-form-urlencoded` (in this order, nothing else: question Q2), body `client_id=<client_id>` (no `scope`), `timeout_s`.
	code_request : { web : Str } -> Request
	code_request = |_facts| crash "todo: slice 219"

	## R-SH12 rows 1, 9, 10: the answer of step 1. A 2xx answer with `device_code`, `user_code`, `expires_in` and `interval`: `Ok`; `interval` is 5 when the answer has none and is used as it is otherwise (0 too); `ends` is `now + expires_in`.
	## No answer, a 5xx answer, or a body that is not JSON: kind `Network` (15). A body with an `error` member: kind `Internal` (1), and the message has the `error` text.
	code_answer : { reply : Reply, now : U64 } -> Try(Code, Fail)
	code_answer = |_facts| crash "todo: slice 219"

	## R-SH12 row 3: `POST <web>/login/oauth/access_token`, the same 2 headers, body `client_id=<client_id>&device_code=<device_code>&grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code`
	## (form encoding: `Registry.encode` of the values, question Q3), `timeout_s`.
	poll_request : { web : Str, device_code : Str } -> Request
	poll_request = |_facts| crash "todo: slice 219"

	## R-SH12 rows 4 to 10: what one poll answer does. `wait` is the wait now, in seconds.
	##
	## | Answer | Result |
	## | --- | --- |
	## | `access_token` | `Ok(Token(text))` |
	## | `authorization_pending` | `Ok(Wait(wait))` |
	## | `slow_down` with an `interval` | `Ok(Wait(interval))` |
	## | `slow_down` with no `interval` | `Ok(Wait(wait + 5))` |
	## | `access_denied`, `expired_token` | kind `Consent` (13) |
	## | another `error` text | kind `Internal` (1), the message has the `error` text |
	## | no answer, a 5xx answer, a body that is not JSON | kind `Network` (15) |
	poll_answer : { reply : Reply, wait : U64 } -> Try([Token(Str), Wait(U64)], Fail)
	poll_answer = |_facts| crash "todo: slice 219"

	## R-SH12 row 7: true when `expires_in` seconds have passed: `now >= ends`. Talon sends no poll then.
	expired : { now : U64, ends : U64 } -> Bool
	expired = |_facts| crash "todo: slice 219"

	## R-SH7, R-AP37, R-SH5: `POST <origin>/v1/tokens`, headers `Registry.headers` (`User-Agent`, `Content-Type: application/json`) then `Talon-Contributor: <contributor>`. No `Authorization`.
	## Body `{"github_token":"<github_token>"}`.
	token_request : { origin : Str, version : Str, contributor : Str, github_token : Str } -> Request
	token_request = |_facts| crash "todo: slice 219"

	## R-AP37, R-E6, R-SH7: the answer of step 7. 201 with a body `{token, expires_at, account}` (`records.Account.decode_token`): `Ok`. No answer: `Registry.no_answer` (15). An error status: `Registry.refuse` with the method `Post`
	## (400: 1, 401: 20, 429 and 5xx: 15). A 2xx body that does not decode: kind `Network` (15), R-E6 last row.
	token_answer : { origin : Str, version : Str, reply : Reply } -> Try(Granted, Fail)
	token_answer = |_facts| crash "todo: slice 219"

	## R-SH7, R-SH13: `share.json` after the login. `token` is the JWT, `token_expires_at` is `expires_at` (ms) in whole seconds as RFC 3339 UTC text, `account` is `{ id, login }`.
	## Every other member stays as it is (`id`, the 3 totals, the times, `extra`). A token and an account that were there are replaced.
	stored : { doc : ShareJson.Doc, granted : Granted } -> ShareJson.Doc
	stored = |_facts| crash "todo: slice 219"

	## R-SH10: the text of the `Usage` failure for the registry `direct`. Proposal for the review (R-OUT2).
	login_direct : {} -> Str
	login_direct = |_none| crash "todo: slice 219"

	## R-SH7, R-OUT2: stdout after a good login. Proposal for the review.
	done_lines : { login : Str } -> List(Str)
	done_lines = |_facts| crash "todo: slice 219"

	## R-OUT4: the `data` of `--json`: `{"account":{"id":<id>,"login":"<login>"},"token_expires_at":"<RFC 3339>"}`. Proposal for the review. The JWT is not in it.
	done_data : { account : { id : U64, login : Str }, token_expires_at : Str } -> JsonDoc
	done_data = |_facts| crash "todo: slice 219"

	## The steps in the table above. Returns the exit code.
	login! : Fx, Args => I32
	login! = |_fx, _args| crash "todo: slice 219"
}
