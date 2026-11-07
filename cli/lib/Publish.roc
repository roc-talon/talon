import records.Compat
import records.Release
import Db
import Fail
import Github
import Ident
import Index
import JsonDoc
import ProbeShare
import QueueSend
import Registry

## `tln publish`, part A (slice 221; CLI 1 R-CM13, R-PUB1 to R-PUB3; Registry R-AP8, R-AP26, R-AP27, R-AP34, R-AP71, R-TP2, R-TP17, R-PU2, R-PU5; Resolution R-PB5; CLI 3 R-E6). Pure decisions. The command code is `PublishFlow`.
## Reuse, no second copy: `Registry.headers` (the headers of the request), `Registry.refuse` (the answer of an error: kind, `details`), `Registry.no_answer`, `Registry.retry_after_of` (the value of `Retry-After`),
## `Index` (the candidate of one release: R-DI3 to R-DI5; the code agent may expose its private asset reader), `Github.rate_limit` and `Github.rate_limit_failure` (R-DI13, R-RG3), `Github.status_failure`,
## `records.Compat.encode_publish` (R-AP71), `records.Release.decode` (the answer of R-AP8), `Db.Query` `FactsOf` (slice 217), `Fx.sleep!`.
##
## All texts are proposals for the review (R-OUT2, TW24), except the three of CLI 3 R-E6 (see `failure`) and the one of R-PUB3.
Publish :: [].{

	## What the job gives (R-PUB1). `tag` has no `refs/tags/`.
	Job : { owner : Str, repo : Str, tag : Str }

	## The OIDC variables of GitHub Actions (R-TP2): the request URL and the request token.
	Oidc : { url : Str, token : Str }

	## The answer of the GitHub API (`Fx.http_get!`) or of `Fx.http_send!`.
	Reply : QueueSend.Reply

	## A request of `Fx.http_send!`.
	Request : { method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 }

	## One fact of the `compat` member (R-AP71): `result` is the word of `Db.outcome_word`. Same shape as `records.Compat.Fact`.
	Fact : { nightly : Str, target : Str, result : Str, error_digest : Try(Str, [None]) }

	## R-PUB1, Registry R-AP27: `GITHUB_REPOSITORY` (`owner/repo`) and `GITHUB_REF` of the environment, no request. Checks in this order, each failure is kind `Usage` (exit 2):
	##
	## | Case | Message (proposal) |
	## | --- | --- |
	## | `GITHUB_REPOSITORY` missing or empty | `GITHUB_REPOSITORY is not set or is empty. tln publish runs in a GitHub Actions job.` |
	## | `GITHUB_REF` missing or empty | `GITHUB_REF is not set or is empty. tln publish runs in a GitHub Actions job.` |
	## | `GITHUB_REF` does not start with `refs/tags/` (`refs/heads/main`, `refs/pull/1/merge`) | `GITHUB_REF is <ref>, not a tag. The job must run on a tag: tln publish registers the release of the tag.` |
	##
	## | `GITHUB_REPOSITORY` is not 2 non-empty parts split by one `/`, each of ASCII letters, digits, `.`, `_`, `-` (R-PUB4 item 5) | `GITHUB_REPOSITORY is <value>, not of the form owner/repo.` |
	## | the tag has a byte that is not a letter, a digit, `.`, `_`, `-`, `+` or `~` (R-PUB4 item 8) | `the tag <tag> is not one safe part of an asset URL: use letters, digits, . _ - + ~. Name the tag with a version.` |
	##
	## An empty value is the same as no value. The checks run in the order of the table, so a bad repository comes before the ref.
	job : List((Str, Str)) -> Try(Publish.Job, Fail)
	job = |env| {
		repository = Publish.env_var(env, "GITHUB_REPOSITORY")
		repo_text = match repository {
			Ok(text) => text
			Err(Unset) => return Err(Fail.new(Usage, "GITHUB_REPOSITORY is not set or is empty. tln publish runs in a GitHub Actions job."))
		}
		parts = repo_text.split_on("/")
		bad_repo = Fail.new(Usage, "GITHUB_REPOSITORY is ${repo_text}, not of the form owner/repo.")
		if parts.len() != 2 {
			return Err(bad_repo)
		}
		owner = parts.first() ?? ""
		repo = parts.last() ?? ""
		if !Publish.safe_name(owner, "._-") or !Publish.safe_name(repo, "._-") {
			return Err(bad_repo)
		}
		ref = match Publish.env_var(env, "GITHUB_REF") {
			Ok(text) => text
			Err(Unset) => return Err(Fail.new(Usage, "GITHUB_REF is not set or is empty. tln publish runs in a GitHub Actions job."))
		}
		if !ref.starts_with("refs/tags/") {
			return Err(Fail.new(Usage, "GITHUB_REF is ${ref}, not a tag. The job must run on a tag: tln publish registers the release of the tag."))
		}
		tag = ref.drop_prefix("refs/tags/")
		if !Publish.safe_name(tag, "._-+~") {
			return Err(Fail.new(Usage, "the tag ${tag} is not one safe part of an asset URL: use letters, digits, . _ - + ~. Name the tag with a version."))
		}
		Ok({ owner, repo, tag })
	}

	## R-TP2, R-AP27: `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` of the environment (an empty value is no value). No request. A missing one is kind `Usage` (exit 2). The URL is checked first.
	## Message (proposal): `tln publish needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.` with `<NAME>` the first missing variable. The message names `id-token: write` (R-AP27).
	oidc : List((Str, Str)) -> Try(Publish.Oidc, Fail)
	oidc = |env| {
		url = match Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_URL") {
			Ok(text) => text
			Err(Unset) => return Err(Publish.no_oidc("ACTIONS_ID_TOKEN_REQUEST_URL"))
		}
		token = match Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_TOKEN") {
			Ok(text) => text
			Err(Unset) => return Err(Publish.no_oidc("ACTIONS_ID_TOKEN_REQUEST_TOKEN"))
		}
		Ok({ url, token })
	}

	## R-DI2 (R-PUB2): `<api>/repos/<owner>/<repo>/releases/tags/<tag>`, the parts as they are (the tag is one safe part: `job`, Q514).
	release_url : { api : Str, owner : Str, repo : Str, tag : Str } -> Str
	release_url = |input| "${input.api}/repos/${input.owner}/${input.repo}/releases/tags/${input.tag}"

	## R-PUB2, R-DI3, R-DI4, R-DI5, R-DI13: the asset URL (`Ok`) from the answer of `release_url`. `now` is for the rate limit time (`Github.rate_limit`).
	##
	## | Answer | Result |
	## | --- | --- |
	## | `Ok` 200 with a release that has one `<hash>.tar.zst` asset (base58 of 32 bytes) and is not a draft, not a prerelease, and `Ident.of_url(asset URL)` is `Ok` | `Ok(<browser_download_url>)` |
	## | 404 | `Usage`: `<owner>/<repo> has no release for the tag <tag>. Create the release and upload the package first, then run tln publish.` |
	## | draft | `Usage`: `the release <tag> of <owner>/<repo> is a draft. A draft is not published: publish the release first.` |
	## | prerelease | `Usage`: `the release <tag> of <owner>/<repo> is a prerelease. A prerelease is not used.` |
	## | no package asset (also an asset with another name) | `Usage`: `the release <tag> of <owner>/<repo> has no <hash>.tar.zst asset. The upload must run before tln publish.` |
	## | 2 or more package assets | `Usage`: `the release <tag> of <owner>/<repo> has 2 package assets (<hash>, <hash>). A release has one.` (the number and the hashes in the order of the assets) |
	## | the asset URL has no readable version (`Ident.of_url` is `Err`) | `Usage`: `the asset URL <url> has no version X.Y.Z that tln can read. Name the tag with a version.` |
	## | rate limit (403 or 429 with `x-ratelimit-remaining: 0` or `retry-after`) | `Github.rate_limit_failure` (kind `Network`, 15) |
	## | 5xx, a body that is not a release object, another status | `Network` (15): `Github.status_failure` (`GitHub answered <status> for <url>`), with `url` = `release_url` |
	## | `Err(Timeout)`, `Err(Failed(text))` | `Network` (15): `cannot reach <url>: <why>. Try again later.` (`why` is `no answer in 20 s` or the text) |
	asset : { api : Str, owner : Str, repo : Str, tag : Str, now : U64, reply : Publish.Reply } -> Try(Str, Fail)
	asset = |input| {
		url = Publish.release_url({ api: input.api, owner: input.owner, repo: input.repo, tag: input.tag })
		reply = match input.reply {
			Ok(found) => found
			Err(Timeout) => return Err(Publish.unreachable(url, "no answer in 20 s"))
			Err(Failed(why)) => return Err(Publish.unreachable(url, why))
		}
		match Github.rate_limit({ status: reply.status, headers: reply.headers, now: input.now }) {
			Ok(limit) => return Err(Github.rate_limit_failure({ reset: limit.reset }))
			Err(NotLimited) => {}
		}
		name = "${input.owner}/${input.repo}"
		if reply.status == 404 {
			return Err(Fail.new(Usage, "${name} has no release for the tag ${input.tag}. Create the release and upload the package first, then run tln publish."))
		}
		other = Github.status_failure({ url, status: reply.status })
		if reply.status != 200 {
			return Err(other)
		}
		pairs = match JsonDoc.parse(reply.body) {
			Ok(Obj(found)) => found
			_ => return Err(other)
		}
		if Publish.flag(pairs, "draft") {
			return Err(Fail.new(Usage, "the release ${input.tag} of ${name} is a draft. A draft is not published: publish the release first."))
		}
		if Publish.flag(pairs, "prerelease") {
			return Err(Fail.new(Usage, "the release ${input.tag} of ${name} is a prerelease. A prerelease is not used."))
		}
		found = Index.assets_of(pairs)
		match found {
			[] => Err(Fail.new(Usage, "the release ${input.tag} of ${name} has no <hash>.tar.zst asset. The upload must run before tln publish."))
			[one] => {
				asset_url = match Publish.download_url(pairs, one.name) {
					Ok(text) => text
					Err(None) => return Err(other)
				}
				match Ident.of_url(asset_url) {
					Ok(_) => Ok(asset_url)
					Err(Foreign) => Err(Fail.new(Usage, "the asset URL ${asset_url} has no version X.Y.Z that tln can read. Name the tag with a version."))
				}
			}
			_ => Err(Fail.new(Usage, "the release ${input.tag} of ${name} has ${found.len().to_str()} package assets (${Str.join_with(found.map(|a| a.hash), ", ")}). A release has one."))
		}
	}

	## R-TP2, R-TP17: the request of the OIDC token. `GET <oidc.url>&audience=<origin>`: `origin` is the base URL form (R-TP17), percent-encoded with `Registry.encode` (Q513, R-PUB4 item 7): `http://127.0.0.1:9` gives `http%3A%2F%2F127.0.0.1%3A9`. One header, in this
	## text: `Authorization: bearer <oidc.token>` (the word `bearer` in lower case, as R-TP2 writes it). `timeout_s` 20 (R-DA9).
	token_request : { oidc : Publish.Oidc, origin : Str } -> Publish.Request
	token_request = |input| {
		method: Get,
		url: "${input.oidc.url}&audience=${Registry.encode(input.origin)}",
		headers: [("Authorization", "bearer ${input.oidc.token}")],
		body: "",
		timeout_s: 20,
	}

	## R-TP2: the JWT from the answer of the token request. A 200 whose body is a JSON object with a text member `value` (the form of GitHub, not in the design: Q9) gives `Ok(value)`.
	## A 401 or a 403 is kind `Usage` (exit 2, Q515, R-PUB4 item 7): `the GitHub OIDC token request was refused (<status>). The job needs permissions: id-token: write.` Any other answer (another status such as 429 or 5xx, a body that is not JSON or has no text `value`, no answer)
	## is kind `Network` (15): `the GitHub OIDC token request failed: <why>` with `<why>` = `answered <status>`, `the answer has no token` or the text of the failure (`no answer in 20 s`). The token is in no message.
	token : Publish.Reply -> Try(Str, Fail)
	token = |reply| {
		failed = |why| Fail.new(Network, "the GitHub OIDC token request failed: ${why}")
		answer = match reply {
			Ok(found) => found
			Err(Timeout) => return Err(failed("no answer in 20 s"))
			Err(Failed(why)) => return Err(failed(why))
		}
		if answer.status == 401 or answer.status == 403 {
			return Err(Fail.new(Usage, "the GitHub OIDC token request was refused (${answer.status.to_str()}). The job needs permissions: id-token: write."))
		}
		if answer.status != 200 {
			return Err(failed("answered ${answer.status.to_str()}"))
		}
		match JsonDoc.parse(answer.body) {
			Ok(Obj(pairs)) => match pairs.find_first(|(key, _)| key == "value") {
				Ok((_, Text(jwt))) if !jwt.is_empty() => Ok(jwt)
				_ => Err(failed("the answer has no token"))
			}
			_ => Err(failed("the answer has no token"))
		}
	}

	## R-PU5, R-AP71, R-PB5: the facts of the `compat` member, from all stored rows (`Db.Query` `FactsOf`). A row goes when its `closure` is empty (a unit check, R-P4) and its `target` is `any` (R-AP71: another
	## target is 400). Each outcome goes (`pass`, `fail`, `hang`, `crash`: R-AP71 `result`). A row of another `hash` is ignored. `error_digest` is `Err(None)` (null) for each fact (Q509).
	## `list` is sorted by `nightly` (text order, the oldest tag first). More than 500 facts (Q510, R-PUB4 item 4): `list` has the 500 facts of the newest nightlies (the largest tags) and `warning` is
	## `Ok("sent 500 of <n> facts for <hash>: the registry takes at most 500 for a publish")` with `<n>` the number of facts that can go; else `Err(None)`.
	facts : { hash : Str, stored : List(Db.Fact) } -> { list : List(Publish.Fact), warning : Try(Str, [None]) }
	facts = |input| {
		mine = input.stored.keep_if(|f| f.hash == input.hash and f.closure.is_empty() and f.target == "any")
		sorted = mine.sort_with(|a, b| ProbeShare.by_text(a.nightly, b.nightly))
		count = sorted.len()
		list = sorted.map(|f| { nightly: f.nightly, target: f.target, result: Db.outcome_word(f.outcome), error_digest: Err(None) })
		if count > Publish.max_facts {
			{
				list: list.take_last(Publish.max_facts),
				warning: Ok("sent ${Publish.max_facts.to_str()} of ${count.to_str()} facts for ${input.hash}: the registry takes at most ${Publish.max_facts.to_str()} for a publish"),
			}
		} else {
			{ list, warning: Err(None) }
		}
	}

	## R-AP8, R-AP26, R-AP45, R-AP71, R-PUB3: `POST <origin>/v1/releases`. Headers, in this order: `Registry.headers({ version, body: Json })` (`User-Agent`, `Content-Type`), then `Authorization: Bearer <token>`.
	## The body is `Compat.encode_publish({ url, compat })`: `compat` is `Ok(facts)` for at least one fact, and `Err(None)` (the member is left out) for no fact (R-PUB3). `timeout_s` 20 (R-DA9, Q511).
	request : { origin : Str, version : Str, token : Str, url : Str, facts : List(Publish.Fact) } -> Publish.Request
	request = |input| {
		compat = if input.facts.is_empty() Err(None) else Ok(input.facts)
		{
			method: Post,
			url: "${input.origin}/v1/releases",
			headers: Registry.headers({ version: input.version, body: Json }).append(("Authorization", "Bearer ${input.token}")),
			body: Compat.encode_publish({ url: input.url, compat }),
			timeout_s: 20,
		}
	}

	## R-PUB3 (the text is the design text): `no probe facts for <hash>: run tln probe --range <bundle file> before tln publish`. The command prints it on stderr as `warning: <text>` (proposal) when `facts` is empty.
	no_facts : Str -> Str
	no_facts = |hash| "no probe facts for ${hash}: run tln probe --range <bundle file> before tln publish"

	## Q517, R-PUB4 item 10: the warning for a `compat.db` that is busy or cannot be read (a newer format is exit 19, not this): `compat.db could not be read (<cause>): publishing with no probe facts`. `cause` is `busy` for `Busy`, the text for `Failed(text)`.
	## The command prints it as `warning: <text>` on stderr, once, and then sends the body with no `compat` member. It does not print the `no_facts` warning too.
	unread : Str -> Str
	unread = |cause| "compat.db could not be read (${cause}): publishing with no probe facts"

	## Q508, R-PUB4 items 1, 2: `--offline` is kind `Network` (exit 15), no request: `tln publish needs the network: --offline sends no request` (proposal; as `ProbeShare.offline`).
	offline : {} -> Fail
	offline = |_none| Fail.new(Network, "tln publish needs the network: --offline sends no request")

	## Q508, R-PUB4 item 2: an operand is kind `Usage` (exit 2): `tln publish takes no argument: '<operand>'` (the first operand). No operand is `Ok({})`.
	operand : List(Str) -> Try({}, Fail)
	operand = |operands| match operands {
		[] => Ok({})
		[first, ..] => Err(Fail.new(Usage, "tln publish takes no argument: '${first}'"))
	}

	## R-AP34, R-E6: what to do after one answer. `retries` is the number of waits done so far (0 for the first answer). `renewed` is true when a new token was already fetched after a 401.
	##
	## | Answer | Result |
	## | --- | --- |
	## | `Ok` with status 200 or 201 | `Done` |
	## | `Ok` 401 and `renewed` is false | `Renew`: a new token (R-TP2), the request again, no wait (and `retries` does not change) |
	## | 429, a 5xx, `Err(Timeout)`, `Err(Failed(_))` and `retries` is below 3 | `Wait(ms)` and then the request again. `ms` is the `Retry-After` of the answer when it is a whole number of seconds (at most 60 s: a larger value gives 60000, and 0 gives 0; Q519, R-PUB4 item 12), else the schedule 2000, 8000, 30000 for `retries` 0, 1, 2 |
	## | the same and `retries` is 3 | `Stop` |
	## | any other answer (a 4xx, a second 401, 3xx, 202, ...) | `Stop` |
	next : { retries : U64, renewed : Bool, reply : Publish.Reply } -> [Done, Renew, Wait(U64), Stop]
	next = |input| match input.reply {
		Ok(answer) => if answer.status == 200 or answer.status == 201 {
			Done
		} else if answer.status == 401 and !input.renewed {
			Renew
		} else if answer.status == 429 or (answer.status >= 500 and answer.status <= 599) {
			Publish.wait(input.retries, Registry.retry_after_of(answer.headers))
		} else {
			Stop
		}
		Err(_) => Publish.wait(input.retries, "")
	}

	## R-E6, R-AP22, R-J7, R-AP34 (CLI 3 example text): the failure after `Stop`. `tries` is the number of requests that were sent (1 to 4). `Registry.refuse` with `method: Post` and `retry_after` gives the kind, the `details` and the
	## message. For a status with problem details the message changes in 3 cases (the texts of the CLI 3 R-E6 example, a proposal there):
	##
	## | Case | Message |
	## | --- | --- |
	## | 409 or 403 or any status, type `/errors/label-conflict` | `<detail> (/errors/label-conflict). The tag was released again. Release a new version.` |
	## | type `/errors/forbidden` | `<detail> (/errors/forbidden). Run tln publish in a job for the tag.` |
	## | `tries` above 1 and the answer was a 5xx other than a busy 503, with problem details | `the registry answered <status> (<type>) <tries> times. Try again later.` |
	## | `tries` above 1 and the answer was 429 (Q516, proposal) | the message of `Registry.refuse` with ` after <tries> requests` after `(<type>)`: `the registry answered 429 (<type>) after 4 requests. Try again in 7 s.` |
	## | `tries` above 1 and the answer was 503 `/errors/busy` (Q516, proposal) | `the registry is busy (503) after <tries> requests. Try again in <n> s.` (`Try again later.` with no `Retry-After`) |
	## | 401 with `renewed` true (Q516, proposal) | kind `Rejected` (20): `<detail> (<type>): the registry refused the new token too.` |
	## | `Err(Timeout)`, `Err(Failed(_))` | `Registry.no_answer` (kind 15). With `tries` above 1 (Q511, proposal): `the registry <origin> gave no answer <tries> times: <why>. The publish may be done. Run the command again.` |
	## | any other case | the message of `Registry.refuse` |
	failure : { origin : Str, version : Str, tries : U64, renewed : Bool, reply : Publish.Reply, source ?: Str } -> Fail
	failure = |input| match input.reply {
		Err(Timeout) => Publish.no_reply(input, "no answer in 20 s")
		Err(Failed(why)) => Publish.no_reply(input, why)
		Ok(answer) => {
			retry_after = Registry.retry_after_of(answer.headers)
			refused = Registry.refuse({ origin: input.origin, version: input.version, method: Post, reply: { status: answer.status, body: answer.body }, retry_after, source: input.?source ?? "", needs: Bool.True })
			match Registry.problem({ status: answer.status, body: answer.body }) {
				Err(NotProblem) => refused
				Ok(body) => {
					what = if body.detail.is_empty() body.title else body.detail
					type = body.type_text
					status = answer.status.to_str()
					tries = input.tries.to_str()
					# Q602: the source goes after the URL of the registry. Without a source the text is as before.
					source = input.?source ?? ""
					who = if source == "" "the registry" else "the registry ${input.origin} (${source})"
					text = if type == "/errors/label-conflict" {
						Ok("${what} (${type}). The tag was released again. Release a new version.")
					} else if type == "/errors/forbidden" {
						Ok("${what} (${type}). Run tln publish in a job for the tag.")
					} else if answer.status == 401 and input.renewed {
						Ok("${what} (${type}): the registry refused the new token too.")
					} else if input.tries > 1 and answer.status == 429 {
						Ok("${who} answered 429 (${type}) after ${tries} requests. ${Registry.wait_text(retry_after)}")
					} else if input.tries > 1 and answer.status == 503 and type == "/errors/busy" {
						Ok("${who} is busy (503) after ${tries} requests. ${Registry.wait_text(retry_after)}")
					} else if input.tries > 1 and answer.status >= 500 {
						Ok("${who} answered ${status} (${type}) ${tries} times. Try again later.")
					} else {
						Err(None)
					}
					match text {
						Ok(message) => { ..refused, message }
						Err(None) => refused
					}
				}
			}
		}
	}

	## R-AP8, R-AP51, R-E6: the answer of a good request. 201 is `created: true`, 200 is `created: false`. The body is `records.Release.decode`; a body that does not decode is kind `Network` (15):
	## `the answer of the registry <origin> is not a release: <text>`. `hash` and `version` are the members of the record.
	answer : { origin : Str, status : U16, body : Str } -> Try({ created : Bool, hash : Str, version : Str }, Fail)
	answer = |input| match Release.decode(input.body) {
		Ok(row) => Ok({ created: input.status == 201, hash: row.hash, version: row.version })
		Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${input.origin} is not a release: ${why}"))
	}

	## R-OUT2 (proposal): the stdout lines, each with a line end. 201: `published <owner>/<repo> <tag>: <hash>, <n> facts sent` (`1 fact`, and `no facts sent` for 0). 200: `<owner>/<repo> <tag> is published already: <hash>, <n> facts sent`.
	lines : { owner : Str, repo : Str, tag : Str, hash : Str, created : Bool, facts : U64 } -> List(Str)
	lines = |run| {
		name = "${run.owner}/${run.repo} ${run.tag}"
		sent = match run.facts {
			0 => "no facts sent"
			1 => "1 fact sent"
			n => "${n.to_str()} facts sent"
		}
		if run.created {
			["published ${name}: ${run.hash}, ${sent}\n"]
		} else {
			["${name} is published already: ${run.hash}, ${sent}\n"]
		}
	}

	## R-OUT2, R-OUT4 (proposal): the `--json` `data`: `{"publish":{"repository","tag","hash","created","facts"}}`, `repository` is `owner/repo`, `facts` the number of facts sent.
	data : { owner : Str, repo : Str, tag : Str, hash : Str, created : Bool, facts : U64 } -> JsonDoc
	data = |run| Obj([("publish", Obj([("repository", Text("${run.owner}/${run.repo}")), ("tag", Text(run.tag)), ("hash", Text(run.hash)), ("created", Flag(run.created)), ("facts", Num(run.facts.to_i64_wrap()))]))])

	## Q32 (Design), R-EC2: the `direct` registry is kind `Usage` (exit 2). `tln publish needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` (as `ShareAccount.direct_text`)
	direct : {} -> Fail
	direct = |_none| Fail.new(Usage, "tln publish needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.")

	## The largest number of facts of one publish (R-PUB4 item 4, R-AP71).
	max_facts : U64
	max_facts = 500

	## The value of an environment variable. An empty value is no value.
	env_var : List((Str, Str)), Str -> Try(Str, [Unset])
	env_var = |env, name| match env.find_first(|(n, _)| n == name) {
		Ok((_, value)) => if value.is_empty() Err(Unset) else Ok(value)
		Err(_) => Err(Unset)
	}

	## A text that is not empty and has only ASCII letters, digits and the bytes of `extra`.
	safe_name : Str, Str -> Bool
	safe_name = |text, extra| {
		extras = extra.to_utf8()
		!text.is_empty() and text.to_utf8().all(|b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or extras.contains(b))
	}

	no_oidc : Str -> Fail
	no_oidc = |name| Fail.new(Usage, "tln publish needs an OIDC token, and ${name} is not set. In a GitHub Actions job, set permissions: id-token: write.")

	unreachable : Str, Str -> Fail
	unreachable = |url, why| Fail.new(Network, "cannot reach ${url}: ${why}. Try again later.")

	## A member of a JSON object that is `true`.
	flag : List((Str, JsonDoc)), Str -> Bool
	flag = |pairs, key| match pairs.find_first(|(k, _)| k == key) {
		Ok((_, Flag(b))) => b
		_ => Bool.False
	}

	## The `browser_download_url` of the asset with this name.
	download_url : List((Str, JsonDoc)), Str -> Try(Str, [None])
	download_url = |pairs, name| match pairs.find_first(|(k, _)| k == "assets") {
		Ok((_, Arr(items))) => {
			urls = items.keep_oks(
				|item| match item {
					Obj(entry) => match (entry.find_first(|(k, _)| k == "name"), entry.find_first(|(k, _)| k == "browser_download_url")) {
						(Ok((_, Text(n))), Ok((_, Text(u)))) if n == name => Ok(u)
						_ => Err(None)
					}
					_ => Err(None)
				},
			)
			urls.first().map_err(|_| None)
		}
		_ => Err(None)
	}

	## The wait before the next request (R-AP34): `Retry-After` as whole seconds (at most 60 s), else 2 s, 8 s, 30 s.
	wait : U64, Str -> [Done, Renew, Wait(U64), Stop]
	wait = |retries, retry_after| {
		if retries >= 3 {
			Stop
		} else {
			text = retry_after.trim()
			if !text.is_empty() and text.to_utf8().all(|b| b >= '0' and b <= '9') {
				Wait(
					match U64.from_str(text) {
						Ok(n) => if n > 60 60000 else n * 1000
						Err(_) => 60000
					},
				)
			} else {
				Wait(
					match retries {
						0 => 2000
						1 => 8000
						_ => 30000
					},
				)
			}
		}
	}

	## Q602: ` (<source>)` after the URL, or nothing with no source.
	source_text : { origin : Str, version : Str, tries : U64, renewed : Bool, reply : Publish.Reply, source ?: Str } -> Str
	source_text = |input| match input.?source ?? "" {
		"" => ""
		source => " (${source})"
	}

	no_reply : { origin : Str, version : Str, tries : U64, renewed : Bool, reply : Publish.Reply, source ?: Str }, Str -> Fail
	no_reply = |input, why| if input.tries > 1 {
		Fail.new(Network, "the registry ${input.origin}${Publish.source_text(input)} gave no answer ${input.tries.to_str()} times: ${why}. The publish may be done. Run the command again.")
	} else {
		Registry.no_answer({ origin: input.origin, why, source: input.?source ?? "", needs: Bool.True })
	}
}
