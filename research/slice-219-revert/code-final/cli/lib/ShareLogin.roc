import records.Account
import Args
import Clock
import Common
import Fail
import Fx
import Help
import Item
import JsonDoc
import Net
import Out
import Registry
import RocInstall
import Roots
import Share
import ShareFlow
import ShareJson

## `tln share login` (slice 219; CLI 1 R-SH7, R-SH10, R-SH12, R-SH13, R-EV28; Registry R-AP37, R-CT8; CLI 3 R-EC13). The GitHub device flow, then `POST /v1/tokens`, then the JWT in `share.json`.
## The pure decisions are the functions below (tests/unit/ShareloginTest.roc). `login!` orders the calls (L2 cases `share/sh23` to `share/sh29`).
##
## | Step of `login!` | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Roots.of_run!` | |
## | 2 | `read_files!` of `config.toml` (a missing file is the empty text), `Share.setting`, `Net.registry`. `Direct`: failure of kind `Usage` (exit 2) with `login_direct`, and no other call. | R-SH10 |
## | 2b | `args.offline`: failure of kind `Network` (exit 15) with `login_offline`, and no other call (Q476). | Q476 |
## | 3 | `read_files!` of `share.json`, `ShareJson.read` (the id; a failure is exit 19 and no request goes). A missing file: `ShareFlow.ensure_doc!` makes it with a new id under its lock, before the intro (Q470, R-SH13). | R-SH5, R-SH13, R-TF3, R-TF6 |
## | 4 | `intro_lines` to stderr (R-J2: progress is human text on stderr, also without `--json` and with `--quiet`: the person needs the code, Q476). | R-SH7 |
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
	web_of = |env| match env.find_first(|(name, _)| name == "TALON_GITHUB_WEB") {
		Ok((_, value)) if !value.is_empty() => value
		_ => ShareLogin.default_web
	}

	## R-SH7: the text before the code. It says that a login ties this machine to the GitHub account, that the results sent before move to the account and the next ones count for it, that the registry keeps them
	## until `tln share forget` or until their compiler is 12 months old (then only the totals). It has no URL and no code. Proposal for the review (R-OUT2).
	## Each line of `intro_lines`, `code_lines` and `done_lines` ends with `\n`, as the lines of `Share`.
	intro_lines : {} -> List(Str)
	intro_lines = |_none| [
		"A login ties this machine to your GitHub account.\n",
		"The results that this machine sent before move to the account, and the next ones count for it.\n",
		"The registry keeps them until you run `tln share forget`, or until their compiler is 12 months old. Then it keeps only the totals.\n",
	]

	## R-SH7, R-SH12 row 1: the lines with `<web>/login/device` and the `user_code` (not the `verification_uri` of the answer). Proposal for the review (R-OUT2).
	code_lines : { web : Str, user_code : Str } -> List(Str)
	code_lines = |facts| [
		"Open ${facts.web}/login/device\n",
		"Enter the code: ${facts.user_code}\n",
		"Talon waits until you approve the code in GitHub.\n",
	]

	## R-SH12 row 1, Q471: `POST <web>/login/device/code`, headers `Accept: application/json`, `User-Agent: tln/<version>` and `Content-Type: application/x-www-form-urlencoded` (in this order, nothing else), body `client_id=<client_id>` (no `scope`), `timeout_s`.
	code_request : { web : Str, version : Str } -> Request
	code_request = |facts| {
		method: Post,
		url: "${facts.web}/login/device/code",
		headers: github_headers(facts.version),
		body: "client_id=${ShareLogin.client_id}",
		timeout_s: ShareLogin.timeout_s,
	}

	## R-SH12 rows 1, 9, 10: the answer of step 1. A 2xx answer with `device_code`, `user_code`, `expires_in` and `interval`: `Ok`; `interval` is 5 when the answer has none and is used as it is otherwise (0 too); `ends` is `now + expires_in`.
	## No answer, a 5xx answer, or a body that is not JSON: kind `Network` (15). A 2xx JSON body that misses `device_code`, `user_code` or `expires_in`: kind `Network` (15), the message has `code request` (Q475, R-SH12 row 11). A body with an `error` member: kind `Internal` (1), and the message has the `error` text.
	code_answer : { reply : Reply, now : U64 } -> Try(Code, Fail)
	code_answer = |facts| {
		doc = github_json(facts.reply)?
		match member(doc, "error") {
			Ok(Text(error)) => return Err(refused(error))
			_ => {}
		}
		missing = |name| Fail.new(Network, "GitHub answered the code request with no ${name}. Try again later.")
		device_code = match member(doc, "device_code") {
			Ok(Text(t)) => t
			_ => return Err(missing("device_code"))
		}
		user_code = match member(doc, "user_code") {
			Ok(Text(t)) => t
			_ => return Err(missing("user_code"))
		}
		expires_in = match member(doc, "expires_in") {
			Ok(Num(n)) if n >= 0 => n.to_u64_wrap()
			_ => return Err(missing("expires_in"))
		}
		interval = match member(doc, "interval") {
			Ok(Num(n)) if n >= 0 => n.to_u64_wrap()
			_ => 5
		}
		Ok({ device_code, user_code, interval, ends: facts.now + expires_in })
	}

	## R-SH12 row 3, Q471, Q472: `POST <web>/login/oauth/access_token`, the same 3 headers, body `client_id=<client_id>&device_code=<device_code>&grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code`
	## (form encoding: `Registry.encode` of the values), `timeout_s`.
	poll_request : { web : Str, device_code : Str, version : Str } -> Request
	poll_request = |facts| {
		method: Post,
		url: "${facts.web}/login/oauth/access_token",
		headers: github_headers(facts.version),
		body: "client_id=${ShareLogin.client_id}&device_code=${Registry.encode(facts.device_code)}&grant_type=${Registry.encode("urn:ietf:params:oauth:grant-type:device_code")}",
		timeout_s: ShareLogin.timeout_s,
	}

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
	## | a JSON body with neither `error` nor `access_token` | kind `Network` (15), the message has `poll` (Q475) |
	poll_answer : { reply : Reply, wait : U64 } -> Try([Token(Str), Wait(U64)], Fail)
	poll_answer = |facts| {
		doc = github_json(facts.reply)?
		match member(doc, "error") {
			Ok(Text("authorization_pending")) => Ok(Wait(facts.wait))
			Ok(Text("slow_down")) => match member(doc, "interval") {
				Ok(Num(n)) if n >= 0 => Ok(Wait(n.to_u64_wrap()))
				_ => Ok(Wait(facts.wait + 5))
			}
			Ok(Text("access_denied")) => Err(Fail.new(Consent, "the login was declined in GitHub"))
			Ok(Text("expired_token")) => Err(code_expired({}))
			Ok(Text(error)) => Err(refused(error))
			_ => match member(doc, "access_token") {
				Ok(Text(token)) => Ok(Token(token))
				_ => Err(Fail.new(Network, "GitHub answered the poll with neither an error nor an access_token. Try again later."))
			}
		}
	}

	## R-SH12 row 7: true when `expires_in` seconds have passed: `now >= ends`. Talon sends no poll then.
	expired : { now : U64, ends : U64 } -> Bool
	expired = |facts| facts.now >= facts.ends

	## R-SH7, R-AP37, R-SH5: `POST <origin>/v1/tokens`, headers `Registry.headers` (`User-Agent`, `Content-Type: application/json`) then `Talon-Contributor: <contributor>`. No `Authorization`.
	## Body `{"github_token":"<github_token>"}`.
	token_request : { origin : Str, version : Str, contributor : Str, github_token : Str } -> Request
	token_request = |facts| {
		method: Post,
		url: "${facts.origin}/v1/tokens",
		headers: Registry.headers({ version: facts.version, body: Json }).append(("Talon-Contributor", facts.contributor)),
		body: JsonDoc.render(JsonDoc.Obj([("github_token", JsonDoc.Text(facts.github_token))])),
		timeout_s: ShareLogin.timeout_s,
	}

	## R-AP37, R-E6, R-SH7: the answer of step 7. 201 with a body `{token, expires_at, account}` (`records.Account.decode_token`): `Ok`. No answer: `Registry.no_answer` (15). An error status: `Registry.refuse` with the method `Post`
	## (400: 1, 401: 20, 429 and 5xx: 15). A 2xx body that does not decode (also with no `token`): kind `Network` (15), R-E6 last row, the message has `registry login` (Q475).
	token_answer : { origin : Str, version : Str, reply : Reply } -> Try(Granted, Fail)
	token_answer = |facts| match facts.reply {
		Err(Timeout) => Err(Registry.no_answer({ origin: facts.origin, why: "no answer in ${ShareLogin.timeout_s.to_str()} s" }))
		Err(Failed(why)) => Err(Registry.no_answer({ origin: facts.origin, why }))
		Ok(answer) => if answer.status >= 200 and answer.status <= 299 {
			match Account.decode_token(answer.body) {
				Ok(granted) => Ok(granted)
				Err(BadJson(text)) => Err(Fail.new(Network, "the answer of the registry ${facts.origin} to the registry login is not a token answer: ${text}"))
			}
		} else {
			fail = Registry.refuse({ origin: facts.origin, version: facts.version, method: Post, reply: { status: answer.status, body: answer.body }, retry_after: Registry.retry_after_of(answer.headers) })
			Err(login_refused(facts.origin, answer, fail))
		}
	}

	## R-SH7, R-SH13: `share.json` after the login. `token` is the JWT, `token_expires_at` is `expires_at` (ms) in whole seconds as RFC 3339 UTC text, `account` is `{ id, login }`.
	## Every other member stays as it is (`id`, the 3 totals, the times, `extra`). A token and an account that were there are replaced.
	stored : { doc : ShareJson.Doc, granted : Granted } -> ShareJson.Doc
	stored = |facts| {
		granted = facts.granted
		{
			..facts.doc,
			token: Ok(granted.token),
			token_expires_at: Ok(Clock.format_utc(granted.expires_at // 1000)),
			account: Ok(granted.account),
		}
	}

	## Q476: the text of the `Network` failure (exit 15) of `--offline`, with no request: `tln share login needs the network, and --offline is set.` Proposal for the review (R-OUT2).
	login_offline : {} -> Str
	login_offline = |_none| "tln share login needs the network, and --offline is set."

	## R-SH10: the text of the `Usage` failure for the registry `direct`. Proposal for the review (R-OUT2).
	login_direct : {} -> Str
	login_direct = |_none| "tln share login needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."

	## R-SH7, R-OUT2: stdout after a good login. Proposal for the review.
	done_lines : { login : Str } -> List(Str)
	done_lines = |facts| ["Logged in as ${facts.login}.\n"]

	## R-OUT4: the `data` of `--json`: `{"account":{"id":<id>,"login":"<login>"},"token_expires_at":"<RFC 3339>"}`. Proposal for the review. The JWT is not in it.
	done_data : { account : { id : U64, login : Str }, token_expires_at : Str } -> JsonDoc
	done_data = |facts| JsonDoc.Obj([
		("account", JsonDoc.Obj([("id", JsonDoc.Num(facts.account.id.to_i64_wrap())), ("login", JsonDoc.Text(facts.account.login))])),
		("token_expires_at", JsonDoc.Text(facts.token_expires_at)),
	])

	## The steps in the table above. Returns the exit code.
	login! : Fx, Args => I32
	login! = |fx, args| match login_flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: ShareLogin.done_data({ account: done.account, token_expires_at: done.expires_text }) }))
			} else {
				for line in ShareLogin.done_lines({ login: done.account.login }) {
					fx.out!(line)
				}
			}
			0
		}
	}
}

# `GitHub` request headers: Accept, User-Agent (Q471), Content-Type. No Authorization, no Talon-Contributor (R-SH5).
github_headers : Str -> List((Str, Str))
github_headers = |version| [("Accept", "application/json"), ("User-Agent", "tln/${version}"), ("Content-Type", "application/x-www-form-urlencoded")]

# One member of a JSON object.
member : JsonDoc, Str -> Try(JsonDoc, [Missing])
member = |doc, name| match doc {
	Obj(pairs) => match pairs.find_first(|(key, _)| key == name) {
		Ok((_, value)) => Ok(value)
		Err(_) => Err(Missing)
	}
	_ => Err(Missing)
}

# R-SH12 row 9: another `error` text.
refused : Str -> Fail
refused = |error| Fail.new(Internal, "GitHub refused the login (${error}). The client id or the code of tln is wrong.")

code_expired : {} -> Fail
code_expired = |_none| Fail.new(Consent, "the code expired before you approved it. Run tln share login again.")

# R-SH12 row 10: the body of a GitHub answer as JSON, or the Network failure (no answer, 5xx, not JSON).
github_json : ShareLogin.Reply -> Try(JsonDoc, Fail)
github_json = |reply| match reply {
	Err(Timeout) => Err(Fail.new(Network, "GitHub gave no answer in ${ShareLogin.timeout_s.to_str()} s. Try again later."))
	Err(Failed(why)) => Err(Fail.new(Network, "GitHub gave no answer: ${why}. Try again later."))
	Ok(answer) => if answer.status >= 500 {
		Err(Fail.new(Network, "GitHub answered ${answer.status.to_str()}. Try again later."))
	} else {
		JsonDoc.parse(answer.body).map_err(|BadJson| Fail.new(Network, "GitHub answered with text that is not JSON. Try again later."))
	}
}

# R-E6: a 401 to the token request has its own text (`Registry.refuse` names a release and a workflow for a write). The details stay.
login_refused : Str, { status : U16, headers : List((Str, Str)), body : Str }, Fail -> Fail
login_refused = |origin, answer, fail| if fail.kind.name() == "rejected" {
	match Registry.problem({ status: answer.status, body: answer.body }) {
		Ok(body) => {
			what = if body.detail.is_empty() body.title else body.detail
			{ ..fail, message: "the registry ${origin} refused the login (${body.type_text}): ${what}. Run tln share login again." }
		}
		Err(NotProblem) => fail
	}
} else {
	fail
}

# Steps 1 to 8.
login_flow! : Fx, Args => Try({ account : Account.Who, expires_text : Str }, Fail)
login_flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	registry = Net.registry({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry })
	origin = match registry {
		Direct => return Err(Fail.new(Usage, ShareLogin.login_direct({})))
		Url(url) => url
	}
	if args.offline {
		return Err(Fail.new(Network, ShareLogin.login_offline({})))
	}
	json_path = Roots.item(roots, Item.ShareJson)
	doc = match fx.read_files!([json_path]) {
		[Ok(text)] => ShareJson.read({ path: json_path, text })?
		_ => ShareFlow.ensure_doc!(fx, json_path)?
	}
	for line in ShareLogin.intro_lines({}) {
		fx.err!(line)
	}
	web = ShareLogin.web_of(env)
	version = Help.version
	reply = fx.http_send!(ShareLogin.code_request({ web, version }))
	started = fx.clock!()
	code = ShareLogin.code_answer({ reply, now: started })?
	for line in ShareLogin.code_lines({ web, user_code: code.user_code }) {
		fx.err!(line)
	}
	github_token = poll_loop!(fx, { web, version, code })?
	granted = ShareLogin.token_answer({
		origin,
		version,
		reply: fx.http_send!(ShareLogin.token_request({ origin, version, contributor: doc.id, github_token })),
	})?
	ShareFlow.totals_write!(fx, json_path, |current| ShareLogin.stored({ doc: current, granted }))?
	Ok({ account: granted.account, expires_text: Clock.format_utc(granted.expires_at // 1000) })
}

# Step 6: wait, read the clock, stop at the end time, poll.
poll_loop! : Fx, { web : Str, version : Str, code : ShareLogin.Code } => Try(Str, Fail)
poll_loop! = |fx, run| {
	var $wait = run.code.interval
	while Bool.True {
		fx.sleep!($wait * 1000)
		if ShareLogin.expired({ now: fx.clock!(), ends: run.code.ends }) {
			return Err(code_expired({}))
		}
		reply = fx.http_send!(ShareLogin.poll_request({ web: run.web, device_code: run.code.device_code, version: run.version }))
		match ShareLogin.poll_answer({ reply, wait: $wait }) {
			Err(fail) => return Err(fail)
			Ok(Token(token)) => return Ok(token)
			Ok(Wait(n)) => {
				$wait = n
			}
		}
	}
	Err(Fail.new(Internal, "the poll loop ended"))
}
