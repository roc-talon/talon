import Fail
import JsonDoc
import Publish
import Registry
import records.Closure as WireClosure
import records.Index as WireIndex
import records.Move as WireMove
import records.Problem

## `tln move`, part A (slice 251, `docs/slices/251-move.md`; CLI 1 R-CM22, R-MV1 to R-MV5; Registry R-AP31, R-AP32, R-TP15, R-TP12, R-AP34, R-AP27, R-TP2; CLI 3 R-E6, R-EC2). Pure decisions. The command code is `MoveFlow`.

## Reuse, no second copy: `Publish.token`, `Publish.next`, `Publish.wait`, `Publish.no_reply`, `Publish.retry_text`, `Registry.headers`, `Registry.refuse`, `records.Move.encode_request`, `records.Closure.decode_repo`, `records.Index.decode_releases`.
## The tests are `tests/unit/MovecheckTest.roc`.
MoveCheck :: [].{

	## A full `github.com` name, in lower case (the key of R-IK2): `owner/repo`.
	Name : { owner : Str, repo : Str }

	## What the command sends (R-MV1). `Set(successor)`: `PUT` with the job repository as the successor (the move, or the acceptance of an offer). `Offer(successor)`: `PUT` from the job of the old name (`--to`). `Remove`: `DELETE` (`--undo`). The successor is `owner/repo` in lower case.
	Plan : [Set(Str), Offer(Str), Remove]

	## The successor of the old name before the request, from the R-AP1 read (Q251-4): `Unknown` (the answer was 404, or has no `repos` item of the old name), `Successor(name)`, `NoSuccessor`.
	Before : [Unknown, Successor(Str), NoSuccessor]

	## What a good run gives to the output. `name` is the old name as the answer item has it. `successor` and `state` are the members of the answer item. `offer` is the offered name for `Offered`, else none.
	Done : { name : Str, result : [Moved, Offered, Removed, Unchanged], successor : Try(Str, [None]), offer : Try(Str, [None]), state : [Active, Missing, Moved] }

	## R-RG9, R-EC2: the registry is `direct`. Kind `Usage` (exit 2): `tln move needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.`
	direct : {} -> Fail
	direct = |_none| Fail.new(Usage, "tln move needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.")

	## R-RG9, R-EC2 (Q251-1, the order of `tln yank`): `--offline` is kind `Network` (exit 15): `tln move needs the network: --offline sends no request`.
	offline : {} -> Fail
	offline = |_none| Fail.new(Network, "tln move needs the network: --offline sends no request")

	## R-CM22: the one operand is the old name. No operand, or an empty text: kind `Usage`: `tln move needs an old name: tln move <old-name> [--to <new-name>] [--undo]`.
	## 2 or more: kind `Usage`: `tln move takes one old name: unexpected '<second>'`.
	operand : List(Str) -> Try(Str, Fail)
	operand = |operands| match operands {
		[] | [""] => Err(Fail.new(Usage, "tln move needs an old name: tln move <old-name> [--to <new-name>] [--undo]"))
		[old] => Ok(old)
		[_, second, ..] => Err(Fail.new(Usage, "tln move takes one old name: unexpected '${second}'"))
	}

	## R-MV1, R-MV2, R-SC7: a full `github.com` name: 2 parts split by one `/`, each of ASCII letters, digits, `.`, `_` and `-`, not empty. The result is in lower case. Else kind `Usage`: `<what> '<text>' is not a full github.com name (owner/repo)`.
	## `what` is `the old name` or `the value of --to`.
	name : { what : Str, text : Str } -> Try(MoveCheck.Name, Fail)
	name = |input| {
		bad = Fail.new(Usage, "${input.what} '${input.text}' is not a full github.com name (owner/repo)")
		match input.text.split_on("/") {
			[owner, repo] => if Publish.safe_name(owner, "._-") and Publish.safe_name(repo, "._-") {
				Ok({ owner: owner.with_ascii_lowercased(), repo: repo.with_ascii_lowercased() })
			} else {
				Err(bad)
			}
			_ => Err(bad)
		}
	}

	## R-MV2: `--to` with `--undo` is kind `Usage`: `tln move --undo takes no --to`.
	flags : { undo : Bool, to : Try(Str, [None]) } -> Try({}, Fail)
	flags = |input| match (input.undo, input.to) {
		(Bool.True, Ok(_)) => Err(Fail.new(Usage, "tln move --undo takes no --to"))
		_ => Ok({})
	}

	## R-MV1, R-MV2: the job repository from `GITHUB_REPOSITORY` (R-YK3 form, in lower case). Kind `Usage`: `GITHUB_REPOSITORY is not set or is empty. tln move runs in a GitHub Actions job.` and `GITHUB_REPOSITORY is <value>, not of the form owner/repo.`
	job : List((Str, Str)) -> Try(MoveCheck.Name, Fail)
	job = |env| {
		text = match Publish.env_var(env, "GITHUB_REPOSITORY") {
			Ok(value) => value
			Err(Unset) => return Err(Fail.new(Usage, "GITHUB_REPOSITORY is not set or is empty. tln move runs in a GitHub Actions job."))
		}
		bad = Fail.new(Usage, "GITHUB_REPOSITORY is ${text}, not of the form owner/repo.")
		match text.split_on("/") {
			[owner, repo] => if Publish.safe_name(owner, "._-") and Publish.safe_name(repo, "._-") {
				Ok({ owner: owner.with_ascii_lowercased(), repo: repo.with_ascii_lowercased() })
			} else {
				Err(bad)
			}
			_ => Err(bad)
		}
	}

	## R-MV1, R-MV2: the request. The names are compared in lower case (R-IK2). The first rule that applies gives the result:
	##
	## | Case | Result |
	## | --- | --- |
	## | `undo` | `Ok(Remove)`. The check of the job repository is `holder` (it needs the R-AP1 read, Q251-6) |
	## | `to` is the old name | `Err`, kind `Usage`: `the old name and the new name are the same: <old>` |
	## | the job is the old name, no `to` | `Err`, kind `Usage`: `the job repository <job> is the old name, so --to <new-name> is needed: tln move <old> --to <new-name> offers the new name` |
	## | the job is the old name, `to` is another name | `Ok(Offer(to))` |
	## | the job is not the old name, no `to`, or `to` is the job | `Ok(Set(job))` |
	## | the job is not the old name, `to` is another name | `Err`, kind `Usage`: `the job repository <job> is neither the old name <old> nor the new name <to>. Run tln move in a job of <old> to offer the new name, or in a job of <to> to accept it.` |
	plan : { job : MoveCheck.Name, old : MoveCheck.Name, to : Try(MoveCheck.Name, [None]), undo : Bool } -> Try(MoveCheck.Plan, Fail)
	plan = |input| {
		who = MoveCheck.text(input.job)
		old = MoveCheck.text(input.old)
		if input.undo {
			return Ok(Remove)
		}
		match input.to {
			Ok(to) => {
				target = MoveCheck.text(to)
				if target == old {
					Err(Fail.new(Usage, "the old name and the new name are the same: ${old}"))
				} else if who == old {
					Ok(Offer(target))
				} else if who == target {
					Ok(Set(who))
				} else {
					Err(Fail.new(Usage, "the job repository ${who} is neither the old name ${old} nor the new name ${target}. Run tln move in a job of ${old} to offer the new name, or in a job of ${target} to accept it."))
				}
			}
			Err(None) => if who == old {
				Err(Fail.new(Usage, "the job repository ${who} is the old name, so --to <new-name> is needed: tln move ${old} --to <new-name> offers the new name"))
			} else {
				Ok(Set(who))
			}
		}
	}

	## R-MV2 (the registry checks the claim `event_name` too, R-TP15): `GITHUB_EVENT_NAME` must be `workflow_dispatch`. Kind `Usage`: `tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is <value>`, or `... GITHUB_EVENT_NAME is not set` for no value or an empty one (Q251-3).
	event : List((Str, Str)) -> Try({}, Fail)
	event = |env| match Publish.env_var(env, "GITHUB_EVENT_NAME") {
		Ok("workflow_dispatch") => Ok({})
		Ok(value) => Err(Fail.new(Usage, "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is ${value}"))
		Err(Unset) => Err(Fail.new(Usage, "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is not set"))
	}

	## R-MV2: `GITHUB_SERVER_URL` must be `https://github.com` (the text as it is, no trailing `/`). Kind `Usage`: `tln move runs on github.com only: GITHUB_SERVER_URL is <value>, not https://github.com`, or `... GITHUB_SERVER_URL is not set` (Q251-3).
	server : List((Str, Str)) -> Try({}, Fail)
	server = |env| match Publish.env_var(env, "GITHUB_SERVER_URL") {
		Ok("https://github.com") => Ok({})
		Ok(value) => Err(Fail.new(Usage, "tln move runs on github.com only: GITHUB_SERVER_URL is ${value}, not https://github.com"))
		Err(Unset) => Err(Fail.new(Usage, "tln move runs on github.com only: GITHUB_SERVER_URL is not set"))
	}

	## R-MV2, R-AP27, R-TP2: `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` (the URL is checked first). Kind `Usage`: `tln move needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.`
	oidc : List((Str, Str)) -> Try(Publish.Oidc, Fail)
	oidc = |env| {
		url = match Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_URL") {
			Ok(text) => text
			Err(Unset) => return Err(MoveCheck.no_oidc("ACTIONS_ID_TOKEN_REQUEST_URL"))
		}
		token = match Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_TOKEN") {
			Ok(text) => text
			Err(Unset) => return Err(MoveCheck.no_oidc("ACTIONS_ID_TOKEN_REQUEST_TOKEN"))
		}
		Ok({ url, token })
	}

	## R-MV3: the names that the privacy guard (R-RG6) checks: the successor of `Set` and of `Offer` (one name, in lower case). `Remove` has no successor: none. The old name is never in the list.
	guarded : MoveCheck.Plan -> List(Str)
	guarded = |chosen| match chosen {
		Set(successor) | Offer(successor) => [successor]
		Remove => []
	}

	## R-AP1 (Q251-4): the successor of the old name before the request, from the answer of `GET <origin>/v1/packages/<owner>/<repo>/releases` (`status` and `body`).
	##
	## | Answer | Result |
	## | --- | --- |
	## | 404 (the repository has no indexed release) | `Ok(Unknown)` |
	## | 200 and a `repos` item whose `name` is the old name (lower case) with a `successor` | `Ok(Successor(name))` |
	## | 200 and the item with no successor | `Ok(NoSuccessor)` |
	## | 200 and no item of the old name | `Ok(Unknown)` |
	## | 200 and a body that is not a release list | kind `Network`: `the answer of the registry <origin> is not a release list: <why>` |
	## | another status | `Registry.refuse` with `method: Get`, `needs: True` and `source` (R-RG9) |
	before : { origin : Str, old : MoveCheck.Name, status : U16, body : Str, source ?: Str } -> Try(MoveCheck.Before, Fail)
	before = |input| {
		if input.status == 404 {
			Ok(Unknown)
		} else if input.status == 200 {
			wanted = MoveCheck.text(input.old)
			match WireIndex.decode_releases(input.body) {
				Ok(decoded) => match decoded.repos.find_first(|item| item.name == wanted) {
					Ok(item) => match item.successor {
						Ok(successor) => Ok(Successor(successor))
						Err(None) => Ok(NoSuccessor)
					}
					Err(_) => Ok(Unknown)
				}
				Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${input.origin} is not a release list: ${why}"))
			}
		} else {
			Err(Registry.refuse({ origin: input.origin, version: "", method: Get, reply: { status: input.status, body: input.body }, source: input.?source ?? "", needs: Bool.True }))
		}
	}

	## R-MV1, R-MV2 (Q251-6): `--undo` in a job that is not the old name needs the job to be the successor of the old name. For `Set` and `Offer` it is `Ok({})`. For `Remove` and a job that is the old name: `Ok({})`. For `Remove`, another job and `Unknown`: `Ok({})` (the registry decides: R-AP31).
	## `Successor(s)` with `s` equal to the job: `Ok({})`. Else kind `Usage`: `the job repository <job> is neither the old name <old> nor its successor <s>. Run tln move --undo in a job of one of them.`, or for `NoSuccessor`: `the job repository <job> is not the old name <old>, and <old> has no successor. Run tln move --undo in a job of <old>.`
	holder : { plan : MoveCheck.Plan, job : MoveCheck.Name, old : MoveCheck.Name, before : MoveCheck.Before } -> Try({}, Fail)
	holder = |input| match input.plan {
		Remove => {
			who = MoveCheck.text(input.job)
			old = MoveCheck.text(input.old)
			if who == old {
				Ok({})
			} else {
				match input.before {
					Unknown => Ok({})
					Successor(s) => if s == who {
						Ok({})
					} else {
						Err(Fail.new(Usage, "the job repository ${who} is neither the old name ${old} nor its successor ${s}. Run tln move --undo in a job of one of them."))
					}
					NoSuccessor => Err(Fail.new(Usage, "the job repository ${who} is not the old name ${old}, and ${old} has no successor. Run tln move --undo in a job of ${old}."))
				}
			}
		}
		_ => Ok({})
	}

	## R-MV1, R-AP31, R-AP45, R-AP23: the request. `Set` and `Offer`: `PUT <origin>/v1/packages/<owner>/<repo>/successor` (the old name, lower case), headers `Registry.headers({ version, body: Json })` then `Authorization: Bearer <token>`, body `records.Move.encode_request({ name: <successor> })`.
	## `Remove`: `DELETE` of the same URL, headers `Registry.headers({ version, body: None })` then `Authorization: Bearer <token>`, body `""`. `timeout_s` 20 (R-DA9).
	request : { origin : Str, version : Str, token : Str, old : MoveCheck.Name, plan : MoveCheck.Plan } -> Publish.Request
	request = |input| {
		url = Registry.releases_of_repo_url({ origin: input.origin, owner: input.old.owner, repo: input.old.repo }).drop_suffix("/releases") |> Str.concat("/successor")
		auth = ("Authorization", "Bearer ${input.token}")
		match input.plan {
			Set(successor) | Offer(successor) => { method: Put, url, headers: Registry.headers({ version: input.version, body: Json }).append(auth), body: WireMove.encode_request({ name: successor }), timeout_s: 20 }
			Remove => { method: Delete, url, headers: Registry.headers({ version: input.version, body: None }).append(auth), body: "", timeout_s: 20 }
		}
	}

	## R-MV4, R-E6, R-AP22, R-AP34, R-TP12, R-RG9: the failure after `Publish.next` gave `Stop`. As `YankCheck.failure` (the texts of `Registry.refuse` and `Publish.retry_text`, the new-token text), with these changes (texts are proposals, Q251-8):
	##
	## | Case | Text |
	## | --- | --- |
	## | A refused write (kind `Rejected`, exit 20): 403, 404, 422 | `<detail> (<type>). Fix the names or the workflow, then run the command again.` |
	## | 403 `/errors/repository-changed` with `issues_url` (R-TP12) | `<detail>. Only the registry operator can change this. Open an issue: <issues_url>`. `details`: `status` and `type` |
	## | No answer, after 2 or more requests | `... gave no answer <n> times: <why>. The move may be done. Run the command again.` For `Offer`: `The offer may be done.`, for `Remove`: `The removal may be done.` |
	failure : { origin : Str, version : Str, tries : U64, renewed : Bool, reply : Publish.Reply, plan : MoveCheck.Plan, source ?: Str } -> Fail
	failure = |input| {
		done = match input.plan {
			Set(_) => "move"
			Offer(_) => "offer"
			Remove => "removal"
		}
		method = match input.plan {
			Remove => Delete
			_ => Put
		}
		source = input.?source ?? ""
		common = { origin: input.origin, version: input.version, tries: input.tries, renewed: input.renewed, reply: input.reply, source }
		match input.reply {
			Err(Timeout) => Publish.no_reply(common, "no answer in 20 s", done)
			Err(Failed(why)) => Publish.no_reply(common, why, done)
			Ok(answer) => {
				retry_after = Registry.retry_after_of(answer.headers)
				refused = Registry.refuse({ origin: input.origin, version: input.version, method, reply: { status: answer.status, body: answer.body }, retry_after, source, needs: Bool.True })
				match Registry.problem({ status: answer.status, body: answer.body }) {
					Err(NotProblem) => refused
					Ok(body) => match Publish.retry_text(common, { status: answer.status, retry_after, body }) {
						Ok(message) => { ..refused, message }
						Err(None) => {
							what = if body.detail.is_empty() body.title else body.detail
							if refused.kind.code() != 20 {
								refused
							} else {
								match Registry.operator_text(body) {
									Ok(message) => { ..refused, message }
									Err(None) => { ..refused, message: "${what} (${body.type_text}). Fix the names or the workflow, then run the command again." }
								}
							}
						}
					}
				}
			}
		}
	}

	## R-MV1, R-AP31, R-AP32, R-OUT2: the answer of a good request (`status` 200, 201 or 202): the `repos` item (`records.Closure.decode_repo`). A body that does not decode: kind `Network`: `the answer of the registry <origin> is not a package state: <why>`.
	##
	## | Plan | Status | Result |
	## | --- | --- | --- |
	## | `Set` | 201 | `Moved` |
	## | `Set` | 200 | `Unchanged` when `before` is `Successor(s)` and `s` is the successor of the item. Else `Moved` |
	## | `Offer` | 202 (or 200) | `Offered`, `offer` is the offered name |
	## | `Remove` | 200 | `Unchanged` when `before` is `NoSuccessor`. Else `Removed` |
	answer : { origin : Str, old : MoveCheck.Name, plan : MoveCheck.Plan, before : MoveCheck.Before, status : U16, body : Str } -> Try(MoveCheck.Done, Fail)
	answer = |input| match WireClosure.decode_repo(input.body) {
		Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${input.origin} is not a package state: ${why}"))
		Ok(item) => {
			result = match input.plan {
				Offer(_) => Offered
				Remove => match input.before {
					NoSuccessor => if input.status == 200 Unchanged else Removed
					_ => Removed
				}
				Set(_) => match input.before {
					Successor(s) => if input.status == 200 and item.successor == Ok(s) Unchanged else Moved
					_ => Moved
				}
			}
			offer = match input.plan {
				Offer(offered) => Ok(offered)
				_ => Err(None)
			}
			Ok({ name: item.name, result, successor: item.successor, offer, state: item.state })
		}
	}

	## R-OUT2 (proposal, the catalog row `move`): the stdout lines, each with a line end.
	##
	## | Result | Line |
	## | --- | --- |
	## | `Moved` | `moved: <old> to <successor>. Users see it in tln outdated, and follow it with tln update <alias>.` |
	## | `Offered` | `offered: <old> to <offer>. To accept, run tln move <old> in a workflow_dispatch job of <offer>.` |
	## | `Removed` | `removed: the successor of <old>` |
	## | `Unchanged` with a successor | `unchanged: <old> has the successor <successor> already` |
	## | `Unchanged` with no successor | `unchanged: <old> has no successor` |
	lines : MoveCheck.Done -> List(Str)
	lines = |done| {
		old = done.name
		successor = done.successor ?? ""
		offer = done.offer ?? ""
		match done.result {
			Moved => ["moved: ${old} to ${successor}. Users see it in tln outdated, and follow it with tln update <alias>.\n"]
			Offered => ["offered: ${old} to ${offer}. To accept, run tln move ${old} in a workflow_dispatch job of ${offer}.\n"]
			Removed => ["removed: the successor of ${old}\n"]
			Unchanged => match done.successor {
				Ok(s) => ["unchanged: ${old} has the successor ${s} already\n"]
				Err(None) => ["unchanged: ${old} has no successor\n"]
			}
		}
	}

	## R-OUT2, R-OUT4, CLI 3 catalog row `move`: the `data` of `--json`, in this order: `name`, `result` (`moved`, `offered`, `removed` or `unchanged`), `successor` (a name, or `null`), `offer` (a name, or `null`), `state` (`active`, `missing` or `moved`).
	data : MoveCheck.Done -> JsonDoc
	data = |done| {
		result = match done.result {
			Moved => "moved"
			Offered => "offered"
			Removed => "removed"
			Unchanged => "unchanged"
		}
		state = match done.state {
			Active => "active"
			Missing => "missing"
			Moved => "moved"
		}
		Obj([("name", Text(done.name)), ("result", Text(result)), ("successor", MoveCheck.text_or_null(done.successor)), ("offer", MoveCheck.text_or_null(done.offer)), ("state", Text(state))])
	}

	text : MoveCheck.Name -> Str
	text = |full| "${full.owner}/${full.repo}"

	text_or_null : Try(Str, [None]) -> JsonDoc
	text_or_null = |value| match value {
		Ok(t) => Text(t)
		Err(None) => Null
	}

	no_oidc : Str -> Fail
	no_oidc = |variable| Fail.new(Usage, "tln move needs an OIDC token, and ${variable} is not set. In a GitHub Actions job, set permissions: id-token: write.")
}
