import records.Index as WireIndex
import records.Release
import records.Yank as WireYank
import Registry
import Fail
import JsonDoc
import Publish

## `tln yank`, part A (slice 249, `docs/slices/249-yank.md`; CLI 1 R-CM21; Registry R-YK1 to R-YK7, R-AP1, R-AP34, R-AP27, R-TP2, R-TP8; CLI 3 R-E6, R-EC2). Pure decisions. The command code is `YankFlow` .
## Reuse, no second copy: `Publish.token` (the answer of the token request), `Publish.next` (the wait, the renew and the stop: the same rule for 200), `Publish.wait`, `Registry.headers`, `Registry.refuse`, `Registry.no_answer`, `records.Yank.encode_request` and `decode_answer`.
## All texts are proposals for the review (R-OUT2, TW24). The tests are `tests/unit/YankcheckTest.roc`.
YankCheck :: [].{

	## What a good run gives to the output (`lines`, `data`). `name` is `GITHUB_REPOSITORY` as it is. `version` and `log_index` are of the release row. `yanked` and `reason` are the state in the answer of the registry. `changed` is true when the state in the answer is not the state before (the row of the R-AP1 read).
	Done : { name : Str, tag : Str, version : Str, log_index : U64, yanked : Bool, reason : Try(Str, [None]), changed : Bool }

	## Registry R-RG9, R-EC2: the registry is `direct`. Kind `Usage` (exit 2): `tln yank needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.`
	direct : {} -> Fail
	direct = |_none| Fail.new(Usage, "tln yank needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.")

	## R-PUB4 item 1 as the model (Q629-1): `--offline` is kind `Network` (exit 15), no request: `tln yank needs the network: --offline sends no request`.
	offline : {} -> Fail
	offline = |_none| Fail.new(Network, "tln yank needs the network: --offline sends no request")

	## R-CM21 (the form `tln yank <tag>`): the operands of the command. One text that is not empty is the tag. No operand, or an empty text: kind `Usage`: `tln yank needs a tag: tln yank <tag> [--reason <text>] [--undo]`.
	## 2 or more: kind `Usage`: `tln yank takes one tag: unexpected '<second>'`.
	operand : List(Str) -> Try(Str, Fail)
	operand = |operands| match operands {
		[] | [""] => Err(Fail.new(Usage, "tln yank needs a tag: tln yank <tag> [--reason <text>] [--undo]"))
		[tag] => Ok(tag)
		[_, second, ..] => Err(Fail.new(Usage, "tln yank takes one tag: unexpected '${second}'"))
	}

	## Q629-2 (approved: exit 2; text and place are a proposal, slice 249 section 5 and B4): `--undo` with `--reason` (also an empty text). The `DELETE` has no body, so the reason would be lost. Kind `Usage`: `tln yank --undo takes no --reason`.
	## `undo` false, or no `--reason` (`Err(None)`): `Ok({})`. The flow calls it after `operand` and before `reason`.
	undo_reason : { undo : Bool, reason : Try(Str, [None]) } -> Try({}, Fail)
	undo_reason = |input| match (input.undo, input.reason) {
		(Bool.True, Ok(_)) => Err(Fail.new(Usage, "tln yank --undo takes no --reason"))
		_ => Ok({})
	}

	## R-YK6 on the client (Q629-3): the reason of `--reason`, before any request. `Err(None)` (no flag) and the empty text are good. More than 500 bytes of UTF-8 (the length is checked first), kind `Usage`: `the reason is <n> bytes: the registry takes at most 500`.
	## A character of the Unicode category Cc (U+0000 to U+001F, U+007F, U+0080 to U+009F), kind `Usage`: `the reason has a control character: a reason is one line of plain text`. Use `records.Yank.check_reason`.
	reason : Try(Str, [None]) -> Try({}, Fail)
	reason = |text| match text {
		Err(None) => Ok({})
		Ok(value) => match WireYank.check_reason(value) {
			Ok({}) => Ok({})
			Err(TooLong) => Err(Fail.new(Usage, "the reason is ${value.count_utf8_bytes().to_str()} bytes: the registry takes at most ${WireYank.reason_limit.to_str()}"))
			Err(ControlChar) => Err(Fail.new(Usage, "the reason has a control character: a reason is one line of plain text"))
		}
	}

	## R-YK3: the repository from `GITHUB_REPOSITORY` (`owner/repo`; 2 non-empty parts, each of ASCII letters, digits, `.`, `_`, `-`). An empty value is no value. Kind `Usage`:
	## `GITHUB_REPOSITORY is not set or is empty. tln yank runs in a GitHub Actions job.` and `GITHUB_REPOSITORY is <value>, not of the form owner/repo.` (as `Publish.job`, without `GITHUB_REF`: a yank runs in a `workflow_dispatch` job, on any ref).
	job : List((Str, Str)) -> Try({ owner : Str, repo : Str }, Fail)
	job = |env| {
		text = match Publish.env_var(env, "GITHUB_REPOSITORY") {
			Ok(value) => value
			Err(Unset) => return Err(Fail.new(Usage, "GITHUB_REPOSITORY is not set or is empty. tln yank runs in a GitHub Actions job."))
		}
		parts = text.split_on("/")
		bad = Fail.new(Usage, "GITHUB_REPOSITORY is ${text}, not of the form owner/repo.")
		if parts.len() != 2 {
			return Err(bad)
		}
		owner = parts.first() ?? ""
		repo = parts.last() ?? ""
		if !Publish.safe_name(owner, "._-") or !Publish.safe_name(repo, "._-") {
			return Err(bad)
		}
		Ok({ owner, repo })
	}

	## R-YK3, R-AP27, R-TP2: `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` (the URL is checked first). Kind `Usage`: `tln yank needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.`
	oidc : List((Str, Str)) -> Try(Publish.Oidc, Fail)
	oidc = |env| {
		url = match Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_URL") {
			Ok(text) => text
			Err(Unset) => return Err(YankCheck.no_oidc("ACTIONS_ID_TOKEN_REQUEST_URL"))
		}
		token = match Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_TOKEN") {
			Ok(text) => text
			Err(Unset) => return Err(YankCheck.no_oidc("ACTIONS_ID_TOKEN_REQUEST_TOKEN"))
		}
		Ok({ url, token })
	}

	## R-YK3, R-AP1, R-EC2: the release of the tag, from the answer of `GET <origin>/v1/packages/<owner>/<repo>/releases` (`status` and `body` of the answer).
	##
	## | Answer | Result |
	## | --- | --- |
	## | 200 with a `releases` list that has a row whose `tag` is the text `tag` (byte for byte, Q629-7) | `Ok(row)` |
	## | 200 and no such row (also a row with no tag) | kind `Usage`: `<owner>/<repo> has no indexed release for the tag <tag>. Run tln publish for the tag first, or wait until the registry indexes it.` |
	## | 404 (the repository has no indexed release, R-AP1) | the same `Usage` text |
	## | 200 and a body that is not a release list | kind `Network`: `the answer of the registry <origin> is not a release list: <why>` |
	## | another status | `Registry.refuse` with `method: Get`, `needs: True` and `source` (R-RG9: with a `source`, a 5xx is `the registry <origin> (<source>) answered <status>: <detail>.`) |
	release : { origin : Str, owner : Str, repo : Str, tag : Str, status : U16, body : Str, source ?: Str } -> Try(Release.Row, Fail)
	release = |input| {
		none = Fail.new(Usage, "${input.owner}/${input.repo} has no indexed release for the tag ${input.tag}. Run tln publish for the tag first, or wait until the registry indexes it.")
		if input.status == 404 {
			Err(none)
		} else if input.status == 200 {
			match WireIndex.decode_releases(input.body) {
				Ok(decoded) => match decoded.releases.keep_if(|row| row.tag == Ok(input.tag)) {
					[row] => Ok(row)
					[] => Err(none)
					[first, second, ..] => Err(Fail.new(Internal, "the registry gave 2 releases for the tag ${input.tag} (log indexes ${first.log_index.to_str()}, ${second.log_index.to_str()})"))
				}
				Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${input.origin} is not a release list: ${why}"))
			}
		} else {
			Err(Registry.refuse({ origin: input.origin, version: "", method: Get, reply: { status: input.status, body: input.body }, source: input.?source ?? "", needs: Bool.True }))
		}
	}

	## R-YK1, R-AP45, R-AP23: the request of the yank. `undo` false: `PUT <origin>/v1/releases/<log_index>/yank`, headers `Registry.headers({ version, body: Json })` then `Authorization: Bearer <token>`, body `records.Yank.encode_request` (`{"reason":"<text>"}`, or `{}` for no reason).
	## `undo` true: `DELETE` of the same URL, headers `Registry.headers({ version, body: None })` then `Authorization: Bearer <token>`, body `""` (the `reason` is not used). `timeout_s` 20 (R-DA9).
	request : { origin : Str, version : Str, token : Str, log_index : U64, undo : Bool, reason : Try(Str, [None]) } -> Publish.Request
	request = |input| {
		url = "${input.origin}/v1/releases/${input.log_index.to_str()}/yank"
		auth = ("Authorization", "Bearer ${input.token}")
		if input.undo {
			{ method: Delete, url, headers: Registry.headers({ version: input.version, body: None }).append(auth), body: "", timeout_s: 20 }
		} else {
			{ method: Put, url, headers: Registry.headers({ version: input.version, body: Json }).append(auth), body: WireYank.encode_request({ reason: input.reason }), timeout_s: 20 }
		}
	}

	## R-E6, R-AP22, R-AP34, R-RG9: the failure after `Publish.next` gave `Stop`. As `Publish.failure` (the same 401, 429, 503 and 5xx texts, `method` `Put` or `Delete`), with these changes: no `label-conflict` and no `forbidden` text (the default text of `Registry.refuse`),
	## and the end of the no-answer text after 2 or more requests is `The yank may be done. Run the command again.` (`The undo may be done.` when `undo`).
	failure : { origin : Str, version : Str, tries : U64, renewed : Bool, reply : Publish.Reply, undo : Bool, source ?: Str } -> Fail
	failure = |input| {
		done = if (input.undo) "undo" else "yank"
		method = if (input.undo) Delete else Put
		common = { origin: input.origin, version: input.version, tries: input.tries, renewed: input.renewed, reply: input.reply, source: input.?source ?? "" }
		match input.reply {
			Err(Timeout) => Publish.no_reply(common, "no answer in 20 s", done)
			Err(Failed(why)) => Publish.no_reply(common, why, done)
			Ok(got) => {
				retry_after = Registry.retry_after_of(got.headers)
				refused = Registry.refuse({ origin: input.origin, version: input.version, method, reply: { status: got.status, body: got.body }, retry_after, source: input.?source ?? "", needs: Bool.True })
				match Registry.problem({ status: got.status, body: got.body }) {
					Err(NotProblem) => refused
					Ok(body) => match Publish.retry_text(common, { status: got.status, retry_after, body }) {
						Ok(message) => { ..refused, message }
						Err(None) => refused
					}
				}
			}
		}
	}

	## R-YK1, R-AP49: the answer of a good request (200): `{"release": <record>}` (`records.Yank.decode_answer`). `before` is `yanked` of the row that the R-AP1 read gave. `changed` is `before != yanked of the answer`. `reason` is `yank_reason` of the answer (the old reason for a yank that changed nothing).
	## A body that does not decode: kind `Network`: `the answer of the registry <origin> is not a release: <why>`.
	answer : { origin : Str, name : Str, tag : Str, before : Bool, status : U16, body : Str } -> Try(YankCheck.Done, Fail)
	answer = |input| match WireYank.decode_answer(input.body) {
		Ok(row) => Ok({ name: input.name, tag: input.tag, version: row.version, log_index: row.log_index, yanked: row.yanked, reason: row.yank_reason, changed: input.before != row.yanked })
		Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${input.origin} is not a release: ${why}"))
	}

	## R-OUT2 (proposal): the stdout lines, each with a line end.
	##
	## | State | Line |
	## | --- | --- |
	## | yanked, `changed` | `yanked <name> <version> (tag <tag>): <reason>`, or `yanked <name> <version> (tag <tag>)` for no reason |
	## | not yanked, `changed` | `unyanked <name> <version> (tag <tag>)` |
	## | yanked, not `changed` | `<name> <version> (tag <tag>) is yanked already: <reason>`, or `... is yanked already` for no reason |
	## | not yanked, not `changed` | `<name> <version> (tag <tag>) is not yanked` |
	lines : YankCheck.Done -> List(Str)
	lines = |done| {
		who = "${done.name} ${done.version} (tag ${done.tag})"
		why = match done.reason {
			Ok(text) => ": ${text}"
			Err(None) => ""
		}
		if done.changed and done.yanked {
			["yanked ${who}${why}\n"]
		} else if done.changed {
			["unyanked ${who}\n"]
		} else if done.yanked {
			["${who} is yanked already${why}\n"]
		} else {
			["${who} is not yanked\n"]
		}
	}

	## R-OUT2, R-OUT4, CLI 3 catalog row `yank`: the `data` of `--json`, in this order: `name`, `tag`, `version`, `log_index`, `yanked`, `reason` (`null` for none), `changed`.
	data : YankCheck.Done -> JsonDoc
	data = |done| {
		shown = match done.reason {
			Ok(text) => Text(text)
			Err(None) => Null
		}
		Obj([("name", Text(done.name)), ("tag", Text(done.tag)), ("version", Text(done.version)), ("log_index", Num(done.log_index.to_i64_wrap())), ("yanked", Flag(done.yanked)), ("reason", shown), ("changed", Flag(done.changed))])
	}

	no_oidc : Str -> Fail
	no_oidc = |name| Fail.new(Usage, "tln yank needs an OIDC token, and ${name} is not set. In a GitHub Actions job, set permissions: id-token: write.")
}
