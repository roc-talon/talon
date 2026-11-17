import lib.Fail
import lib.JsonDoc
import lib.MoveCheck

MovecheckTest :: [].{}

# Slice 251 (CLI 1 R-CM22, R-MV1 to R-MV5, R-EC2, R-RG9; Registry R-AP31, R-AP32, R-TP12, R-TP15, R-AP34; CLI 3 R-E6): the pure part of `tln move`. The flow is the L2 cases `move/mv1` to `mv14`.
# The texts and the `data` members are proposals for the review (R-OUT2, TW24), except the 3 lines of the catalog row `move` (CLI 3). The tests of Q251-1 (order), Q251-3 (unset variables), Q251-4 (the R-AP1 read before) and Q251-6 (`--undo` in the job of the successor) follow the recommendation of the slice file.
# ' stands for " in a JSON text.

origin = "http://127.0.0.1:9"

js = |text| text.replace_each("'", "\"")

# "ok", or the name of the kind of the failure.
kind_of : Try(a, Fail) -> Str
kind_of = |result| match result {
	Ok(_) => "ok"
	Err(fail) => fail.kind.name()
}

# The message of a failure, or "ok".
msg_of : Try(a, Fail) -> Str
msg_of = |result| match result {
	Ok(_) => "ok"
	Err(fail) => fail.message
}

nm = |owner, repo| { owner, repo }

# One `repos` item (R-AP32). `successor` is a JSON text (`'acme/roc-json'` or `null`).
item = |name, state, successor| js("{'name':'${name}','state':'${state}','successor':${successor},'state_at':1767000000000,'owner_changed':null}")

# The answer of R-AP1 (`releases` is empty: `before` reads `repos` only).
list_of = |items| "{\"releases\":[],\"checked\":null,\"repos\":[${Str.join_with(items, ",")}]}"

# R-RG9, R-EC2: a registry that is `direct` is exit 2; `--offline` is exit 15 (the model of `tln yank`, Q251-1). Each text names the command.
expect {
	MoveCheck.direct({}).message == "tln move needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
		and MoveCheck.direct({}).kind.name() == "usage"
			and MoveCheck.direct({}).kind.code() == 2
				and MoveCheck.offline({}).message == "tln move needs the network: --offline sends no request"
					and MoveCheck.offline({}).kind.code() == 15
}

# R-CM22: the one operand is the old name. No operand, or an empty one, and 2 or more are exit 2.
expect {
	MoveCheck.operand(["olddev/json"]) == Ok("olddev/json")
		and msg_of(MoveCheck.operand([])) == "tln move needs an old name: tln move <old-name> [--to <new-name>] [--undo]"
			and msg_of(MoveCheck.operand([""])) == "tln move needs an old name: tln move <old-name> [--to <new-name>] [--undo]"
				and msg_of(MoveCheck.operand(["a/b", "c/d"])) == "tln move takes one old name: unexpected 'c/d'"
					and kind_of(MoveCheck.operand([])) == "usage"
						and kind_of(MoveCheck.operand(["a/b", "c/d", "e/f"])) == "usage"
}

# R-MV1, R-MV2, R-SC7: a name is a full `github.com` name: 2 non-empty parts split by one `/`. The result is in lower case (R-IK2). A short name, a name with a host (3 parts) and a part with a space are exit 2. The text names what was checked.
expect {
	of = |text| MoveCheck.name({ what: "the old name", text })
	bad = |text| "the old name '${text}' is not a full github.com name (owner/repo)"
	of("olddev/json") == Ok(nm("olddev", "json"))
		and of("OldDev/Roc-JSON_2.x") == Ok(nm("olddev", "roc-json_2.x"))
			and msg_of(of("json")) == bad("json")
				and msg_of(of("gitlab.com/acme/json")) == bad("gitlab.com/acme/json")
					and msg_of(of("acme/")) == bad("acme/")
						and msg_of(of("/json")) == bad("/json")
							and msg_of(of("ac me/json")) == bad("ac me/json")
								and kind_of(of("json")) == "usage"
									and msg_of(MoveCheck.name({ what: "the value of --to", text: "x" })) == "the value of --to 'x' is not a full github.com name (owner/repo)"
}

# R-MV2: `--to` with `--undo` is exit 2. The other combinations are good.
expect {
	both = MoveCheck.flags({ undo: Bool.True, to: Ok("acme/roc-json") })
	msg_of(both) == "tln move --undo takes no --to"
		and kind_of(both) == "usage"
			and MoveCheck.flags({ undo: Bool.True, to: Err(None) }) == Ok({})
				and MoveCheck.flags({ undo: Bool.False, to: Ok("acme/roc-json") }) == Ok({})
					and MoveCheck.flags({ undo: Bool.False, to: Err(None) }) == Ok({})
}

# R-MV1, R-MV2: the job repository is `GITHUB_REPOSITORY` (the form `owner/repo`, in lower case). `GITHUB_REF` is not read. Each failure is exit 2 and names the variable.
expect {
	set_repo = |value| [("GITHUB_REPOSITORY", value)]
	run_text = "tln move runs in a GitHub Actions job."
	MoveCheck.job(set_repo("acme/roc-json")) == Ok(nm("acme", "roc-json"))
		and MoveCheck.job(set_repo("Acme/Roc-JSON")) == Ok(nm("acme", "roc-json"))
			and msg_of(MoveCheck.job([("HOME", "/h")])) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
				and msg_of(MoveCheck.job(set_repo(""))) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
					and msg_of(MoveCheck.job(set_repo("acme"))) == "GITHUB_REPOSITORY is acme, not of the form owner/repo."
						and msg_of(MoveCheck.job(set_repo("acme/json/x"))) == "GITHUB_REPOSITORY is acme/json/x, not of the form owner/repo."
							and kind_of(MoveCheck.job(set_repo("acme"))) == "usage"
}

# R-MV1 (the table of the 3 rows), R-MV2: the request from the job repository, the old name, `--to` and `--undo`.
expect {
	old = nm("olddev", "json")
	new = nm("acme", "roc-json")
	plan = |job, to, undo| MoveCheck.plan({ job, old, to, undo })
	# the job is not the old name: the successor is the job (the move, or the acceptance of an offer)
	plan(new, Err(None), Bool.False) == Ok(Set("acme/roc-json"))
		and plan(new, Ok(new), Bool.False) == Ok(Set("acme/roc-json"))
			# the job is the old name: `--to` is an offer
			and plan(old, Ok(new), Bool.False) == Ok(Offer("acme/roc-json"))
				# `--undo`, in a job of the old name or of another repository: `DELETE`
				and plan(old, Err(None), Bool.True) == Ok(Remove)
					and plan(new, Err(None), Bool.True) == Ok(Remove)
}

# R-MV2: the checks of the names, each exit 2 with its own text. The old name as the job needs `--to`. The old name and the new name are not equal. A job that is neither the old name nor the new name (nor the successor of `--to`) is refused.
expect {
	old = nm("olddev", "json")
	new = nm("acme", "roc-json")
	third = nm("third", "lib")
	plan = |job, to, undo| MoveCheck.plan({ job, old, to, undo })
	no_to = plan(old, Err(None), Bool.False)
	same = plan(old, Ok(old), Bool.False)
	neither = plan(third, Ok(new), Bool.False)
	msg_of(no_to) == "the job repository olddev/json is the old name, so --to <new-name> is needed: tln move olddev/json --to <new-name> offers the new name"
		and msg_of(same) == "the old name and the new name are the same: olddev/json"
			and msg_of(neither) == "the job repository third/lib is neither the old name olddev/json nor the new name acme/roc-json. Run tln move in a job of olddev/json to offer the new name, or in a job of acme/roc-json to accept it."
				and kind_of(no_to) == "usage"
					and kind_of(same) == "usage"
						and kind_of(neither) == "usage"
							# the equal check comes before the job check: a third job with `--to` equal to the old name
							and msg_of(plan(third, Ok(old), Bool.False)) == "the old name and the new name are the same: olddev/json"
}

# R-IK2: the names compare in lower case. The job `Acme/Roc-Json` (read by `job`) is the new name `acme/roc-json`. The caller gives the names in lower case (`name`, `job`), so the compare is a plain one.
expect {
	job = MoveCheck.job([("GITHUB_REPOSITORY", "OldDev/JSON")])
	old = MoveCheck.name({ what: "the old name", text: "olddev/Json" })
	match (job, old) {
		(Ok(j), Ok(o)) => j == o and MoveCheck.plan({ job: j, old: o, to: Ok(nm("acme", "x")), undo: Bool.False }) == Ok(Offer("acme/x"))
		_ => Bool.False
	}
}

# R-MV2 (Q251-3, follows the recommendation): the event is `workflow_dispatch` (the registry checks the claim too). Another value, no value and an empty value are exit 2. R-MV2: the server is `https://github.com`.
expect {
	event = |value| MoveCheck.event([("GITHUB_EVENT_NAME", value)])
	server = |value| MoveCheck.server([("GITHUB_SERVER_URL", value)])
	event("workflow_dispatch") == Ok({})
		and msg_of(event("push")) == "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is push"
			and msg_of(event("")) == "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is not set"
				and msg_of(MoveCheck.event([("HOME", "/h")])) == "tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is not set"
					and kind_of(event("push")) == "usage"
						and server("https://github.com") == Ok({})
							and msg_of(server("https://github.example.com")) == "tln move runs on github.com only: GITHUB_SERVER_URL is https://github.example.com, not https://github.com"
								and msg_of(server("https://github.com/")) == "tln move runs on github.com only: GITHUB_SERVER_URL is https://github.com/, not https://github.com"
									and msg_of(MoveCheck.server([])) == "tln move runs on github.com only: GITHUB_SERVER_URL is not set"
										and kind_of(server("http://github.com")) == "usage"
}

# R-MV2, R-AP27, R-TP2: the OIDC variables. The URL is checked first. The text names `id-token: write`. Exit 2. An empty value is no value.
expect {
	both = [("ACTIONS_ID_TOKEN_REQUEST_URL", "http://127.0.0.1:8/token?api-version=2.0"), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "req1")]
	only_url = [("ACTIONS_ID_TOKEN_REQUEST_URL", "http://127.0.0.1:8/token?api-version=2.0")]
	empty_url = [("ACTIONS_ID_TOKEN_REQUEST_URL", ""), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "req1")]
	MoveCheck.oidc(both) == Ok({ url: "http://127.0.0.1:8/token?api-version=2.0", token: "req1" })
		and msg_of(MoveCheck.oidc([])) == "tln move needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."
			and msg_of(MoveCheck.oidc(only_url)) == "tln move needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_TOKEN is not set. In a GitHub Actions job, set permissions: id-token: write."
				and msg_of(MoveCheck.oidc(empty_url)) == "tln move needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."
					and kind_of(MoveCheck.oidc([])) == "usage"
}

# R-MV3: the privacy guard checks the successor only. A `Set` and an `Offer` give the one successor. A `Remove` gives no name. The old name is never in the list.
expect {
	MoveCheck.guarded(Set("acme/roc-json")) == ["acme/roc-json"]
		and MoveCheck.guarded(Offer("acme/roc-json")) == ["acme/roc-json"]
			and MoveCheck.guarded(Remove) == []
}

# R-AP1 (Q251-4, follows the recommendation): the successor of the old name before the request, from the `repos` item of the read. 404 and no item of the old name are `Unknown`. An item of another name is not it.
expect {
	old = nm("olddev", "json")
	of = |status, body| MoveCheck.before({ origin, old, status, body })
	problem = "{\"type\":\"/errors/not-found\",\"title\":\"T\",\"status\":404,\"detail\":\"D\"}"
	moved = list_of([item("olddev/json", "moved", "'acme/roc-json'")])
	plain = list_of([item("olddev/json", "active", "null")])
	other = list_of([item("third/lib", "moved", "'acme/x'"), item("olddev/json", "active", "null")])
	of(200, moved) == Ok(Successor("acme/roc-json"))
		and of(200, plain) == Ok(NoSuccessor)
			and of(200, other) == Ok(NoSuccessor)
				and of(200, list_of([item("third/lib", "moved", "'acme/x'")])) == Ok(Unknown)
					and of(200, list_of([])) == Ok(Unknown)
						and of(404, problem) == Ok(Unknown)
}

# R-E6, R-RG9: another answer to the read is `Registry.refuse` (a `Get`: exit 15, never 20). With a `source` a 5xx is the stop text of R-RG9 with no advice for `direct` (a move needs a registry). A 200 that is not a release list is exit 15.
expect {
	old = nm("olddev", "json")
	problem = |status, type| "{\"type\":\"/errors/${type}\",\"title\":\"T\",\"status\":${status.to_str()},\"detail\":\"D\"}"
	set = MoveCheck.before({ origin, old, status: 500, body: problem(500.U16, "internal"), source: "TALON_REGISTRY" })
	denied = MoveCheck.before({ origin, old, status: 403, body: problem(403.U16, "forbidden") })
	bad = MoveCheck.before({ origin, old, status: 200, body: "<html>" })
	msg_of(set) == "the registry ${origin} (TALON_REGISTRY) answered 500: D."
		and kind_of(set) == "network"
			and kind_of(denied) == "network"
				and kind_of(bad) == "network"
					and msg_of(bad).starts_with("the answer of the registry ${origin} is not a release list: ")
}

# R-MV1, R-MV2 (Q251-6, follows the recommendation): `--undo` in a job that is not the old name needs the job to be the successor of the old name. The old name as the job, and a name with an unknown successor, go on (the registry decides). `Set` and `Offer` have no such check.
expect {
	old = nm("olddev", "json")
	new = nm("acme", "roc-json")
	third = nm("third", "lib")
	of = |job, before| MoveCheck.holder({ plan: Remove, job, old, before })
	of(old, NoSuccessor) == Ok({})
		and of(old, Successor("acme/roc-json")) == Ok({})
			and of(new, Successor("acme/roc-json")) == Ok({})
				and of(third, Unknown) == Ok({})
					and msg_of(of(third, Successor("acme/roc-json"))) == "the job repository third/lib is neither the old name olddev/json nor its successor acme/roc-json. Run tln move --undo in a job of one of them."
						and msg_of(of(third, NoSuccessor)) == "the job repository third/lib is not the old name olddev/json, and olddev/json has no successor. Run tln move --undo in a job of olddev/json."
							and kind_of(of(third, NoSuccessor)) == "usage"
								and MoveCheck.holder({ plan: Set("third/lib"), job: third, old, before: NoSuccessor }) == Ok({})
									and MoveCheck.holder({ plan: Offer("acme/roc-json"), job: third, old, before: Successor("x/y") }) == Ok({})
}

# R-MV1, R-AP31, R-AP45, R-AP23: the request. `Set` and `Offer` are a `PUT` with the body `{"name":"<successor>"}`. `Remove` is a `DELETE` with no body and no `Content-Type`. The URL has the old name in lower case. Both: `User-Agent`, then `Authorization: Bearer`, 20 s.
expect {
	old = nm("olddev", "json")
	put = |plan| MoveCheck.request({ origin, version: "0.0.1", token: "jwt1", old, plan })
	delete = put(Remove)
	put(Set("acme/roc-json")).method == Put
		and put(Set("acme/roc-json")).url == "http://127.0.0.1:9/v1/packages/olddev/json/successor"
			and put(Set("acme/roc-json")).body == "{\"name\":\"acme/roc-json\"}"
				and put(Offer("acme/roc-json")).body == "{\"name\":\"acme/roc-json\"}"
					and put(Offer("acme/roc-json")).method == Put
						and put(Set("acme/roc-json")).headers == [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json"), ("Authorization", "Bearer jwt1")]
							and put(Set("acme/roc-json")).timeout_s == 20
								and delete.method == Delete
									and delete.url == "http://127.0.0.1:9/v1/packages/olddev/json/successor"
										and delete.body == ""
											and delete.headers == [("User-Agent", "tln/0.0.1"), ("Authorization", "Bearer jwt1")]
												and delete.timeout_s == 20
}

problem = |status, type, detail| js("{'type':'/errors/${type}','title':'T','status':${status.to_str()},'detail':'${detail}'}")

# R-MV4, R-E6, R-AP22, R-J7: a refused write is exit 20, with `details` (`status`, `type`). The detail of the registry is in the message: for 403, 404 and 422 (the check that failed). A 400 is a fault of tln (exit 1). A 401 after the new token says so.
expect {
	of = |status, type, detail, tries, renewed| MoveCheck.failure({ origin: "https://registry.example.org", version: "0.0.1", tries, renewed, plan: Set("acme/roc-json"), reply: Ok({ status, headers: [], body: problem(status, type, detail) }) })
	forbidden = of(403, "forbidden", "token claim repository is third/lib: it is not olddev/json and it is not acme/roc-json", 1, Bool.False)
	missing = of(404, "not-found", "no package named olddev/json has a repos row", 1, Bool.False)
	mismatch = of(422, "successor-mismatch", "the successor acme/roc-json fails the exposes check: the newest candidate of the successor does not expose the modules Encode", 1, Bool.False)
	refused = of(401, "unauthenticated", "D", 2, Bool.True)
	missing.message == "no package named olddev/json has a repos row (/errors/not-found). Fix the names or the workflow, then run the command again."
		and missing.kind.code() == 20
			and missing.details == Ok(JsonDoc.Obj([("status", Num(404)), ("type", Text("/errors/not-found"))]))
				and mismatch.message == "the successor acme/roc-json fails the exposes check: the newest candidate of the successor does not expose the modules Encode (/errors/successor-mismatch). Fix the names or the workflow, then run the command again."
					and mismatch.kind.code() == 20
						and forbidden.kind.code() == 20
							and refused.message == "D (/errors/unauthenticated): the registry refused the new token too."
								and refused.kind.code() == 20
									and of(400, "bad-request", "D", 1, Bool.False).kind.code() == 1
}

# R-TP12, R-MV4 (Q251-8, follows the recommendation): a 403 `repository-changed` has `issues_url`. The message is the detail, then the advice of R-TP12, then the URL. Exit 20, `details` has `status` and `type`.
expect {
	body = js("{'type':'/errors/repository-changed','title':'Repository changed','status':403,'detail':'the name olddev/json is bound to another GitHub account (repository id 100)','issues_url':'https://github.com/roc-talon/talon/issues'}")
	got = MoveCheck.failure({ origin, version: "0.0.1", tries: 1, renewed: Bool.False, plan: Offer("acme/roc-json"), reply: Ok({ status: 403, headers: [], body }) })
	got.message == "the name olddev/json is bound to another GitHub account (repository id 100). Only the registry operator can change this. Open an issue: https://github.com/roc-talon/talon/issues"
		and got.kind.code() == 20
			and got.details == Ok(JsonDoc.Obj([("status", Num(403)), ("type", Text("/errors/repository-changed"))]))
}

# R-AP34, R-E6: after 4 requests a 429, a busy 503 and a 5xx are exit 15 with the number of requests; with one request the text of `Registry.refuse`.
expect {
	of = |status, type, headers, tries| MoveCheck.failure({ origin: "https://registry.example.org", version: "0.0.1", tries, renewed: Bool.False, plan: Set("acme/roc-json"), reply: Ok({ status, headers, body: problem(status, type, "D") }) })
	of(429, "rate-limited", [("Retry-After", "7")], 4).message == "the registry answered 429 (/errors/rate-limited) after 4 requests. Try again in 7 s."
		and of(503, "busy", [], 4).message == "the registry is busy (503) after 4 requests. Try again later."
			and of(502, "upstream", [], 4).message == "the registry answered 502 (/errors/upstream) 4 times. Try again later."
				and of(502, "upstream", [], 4).kind.code() == 15
					and of(429, "rate-limited", [("Retry-After", "7")], 1).message == "the registry answered 429 (/errors/rate-limited). Try again in 7 s."
}

# R-AP34, R-E6, R-RG9: no answer. After 4 requests: exit 15, the number of requests, and the move, the offer or the removal may be done. With a `source` the URL is followed by it. With one request: the text of `Registry.no_answer`.
expect {
	no_answer = |tries, plan, source| MoveCheck.failure({ origin, version: "0.0.1", tries, renewed: Bool.False, plan, reply: Err(Timeout), source })
	one = MoveCheck.failure({ origin, version: "0.0.1", tries: 1, renewed: Bool.False, plan: Set("acme/roc-json"), reply: Err(Failed("connection refused")) })
	no_answer(4, Set("acme/roc-json"), "").message == "the registry ${origin} gave no answer 4 times: no answer in 20 s. The move may be done. Run the command again."
		and no_answer(4, Offer("acme/roc-json"), "").message == "the registry ${origin} gave no answer 4 times: no answer in 20 s. The offer may be done. Run the command again."
			and no_answer(4, Remove, "").message == "the registry ${origin} gave no answer 4 times: no answer in 20 s. The removal may be done. Run the command again."
				and no_answer(4, Set("acme/roc-json"), "TALON_REGISTRY").message == "the registry ${origin} (TALON_REGISTRY) gave no answer 4 times: no answer in 20 s. The move may be done. Run the command again."
					and no_answer(4, Set("acme/roc-json"), "").kind.code() == 15
						and one.message == "the registry ${origin} gave no answer: connection refused. Try again later."
}

# R-AP31, R-AP32, R-OUT2 (Q251-4): the answer of a good request. 201 is `moved`. 202 is `offered`. A 200 of a `Set` is `unchanged` when the read before had this successor, else `moved`. A 200 of a `Remove` is `unchanged` when the read before had no successor, else `removed`. The members come from the answer item.
expect {
	old = nm("olddev", "json")
	answer = |plan, before, status, body| MoveCheck.answer({ origin, old, plan, before, status, body })
	set = Set("acme/roc-json")
	moved_item = item("olddev/json", "moved", "'acme/roc-json'")
	active_item = item("olddev/json", "active", "null")
	created = answer(set, NoSuccessor, 201, moved_item)
	replaced = answer(set, Successor("third/lib"), 200, moved_item)
	same = answer(set, Successor("acme/roc-json"), 200, moved_item)
	unknown = answer(set, Unknown, 200, moved_item)
	offered = answer(Offer("acme/roc-json"), Unknown, 202, active_item)
	removed = answer(Remove, Successor("acme/roc-json"), 200, active_item)
	none = answer(Remove, NoSuccessor, 200, active_item)
	created == Ok({ name: "olddev/json", result: Moved, successor: Ok("acme/roc-json"), offer: Err(None), state: Moved })
		and replaced == Ok({ name: "olddev/json", result: Moved, successor: Ok("acme/roc-json"), offer: Err(None), state: Moved })
			and same == Ok({ name: "olddev/json", result: Unchanged, successor: Ok("acme/roc-json"), offer: Err(None), state: Moved })
				and unknown == Ok({ name: "olddev/json", result: Moved, successor: Ok("acme/roc-json"), offer: Err(None), state: Moved })
					and offered == Ok({ name: "olddev/json", result: Offered, successor: Err(None), offer: Ok("acme/roc-json"), state: Active })
						and removed == Ok({ name: "olddev/json", result: Removed, successor: Err(None), offer: Err(None), state: Active })
							and none == Ok({ name: "olddev/json", result: Unchanged, successor: Err(None), offer: Err(None), state: Active })
								and kind_of(answer(set, Unknown, 201, "{\"x\":1}")) == "network"
}

# R-OUT2 (the 3 lines of the catalog row `move` are exact, the 2 lines of `unchanged` are a proposal): the stdout lines of the 5 results.
expect {
	done = |result, successor, offer| { name: "olddev/json", result, successor, offer, state: Active }
	MoveCheck.lines(done(Moved, Ok("acme/roc-json"), Err(None))) == ["moved: olddev/json to acme/roc-json. Users see it in tln outdated, and follow it with tln update <alias>.\n"]
		and MoveCheck.lines(done(Offered, Err(None), Ok("acme/roc-json"))) == ["offered: olddev/json to acme/roc-json. To accept, run tln move olddev/json in a workflow_dispatch job of acme/roc-json.\n"]
			and MoveCheck.lines(done(Removed, Err(None), Err(None))) == ["removed: the successor of olddev/json\n"]
				and MoveCheck.lines(done(Unchanged, Ok("acme/roc-json"), Err(None))) == ["unchanged: olddev/json has the successor acme/roc-json already\n"]
					and MoveCheck.lines(done(Unchanged, Err(None), Err(None))) == ["unchanged: olddev/json has no successor\n"]
}

# R-OUT4, CLI 3 catalog row `move`: the `data` members and their order: `name`, `result`, `successor` (`null` for none), `offer` (`null` for none), `state`.
expect {
	done = |result, successor, offer, state| { name: "olddev/json", result, successor, offer, state }
	MoveCheck.data(done(Moved, Ok("acme/roc-json"), Err(None), Moved)).render() == js("{'name':'olddev/json','result':'moved','successor':'acme/roc-json','offer':null,'state':'moved'}")
		and MoveCheck.data(done(Offered, Err(None), Ok("acme/roc-json"), Active)).render() == js("{'name':'olddev/json','result':'offered','successor':null,'offer':'acme/roc-json','state':'active'}")
			and MoveCheck.data(done(Removed, Err(None), Err(None), Active)).render() == js("{'name':'olddev/json','result':'removed','successor':null,'offer':null,'state':'active'}")
				and MoveCheck.data(done(Unchanged, Err(None), Err(None), Missing)).render() == js("{'name':'olddev/json','result':'unchanged','successor':null,'offer':null,'state':'missing'}")
}

# R-AP31, R-OUT2 (G1, G2 of the mutation check): the status is part of the rule. `Unchanged` of a `Set` needs the status 200 (a 201 is a creation, so `Moved` even when the item has the successor of the read). `Unchanged` of a `Remove` with no successor before needs the status 200 (`Removed` for another 2xx).
expect {
	old = nm("olddev", "json")
	answer = |plan, before, status, body| MoveCheck.answer({ origin, old, plan, before, status, body })
	moved_item = item("olddev/json", "moved", "'a/b'")
	active_item = item("olddev/json", "active", "null")
	set = answer(Set("a/b"), Successor("a/b"), 201, moved_item)
	gone_204 = answer(Remove, NoSuccessor, 204, active_item)
	gone_202 = answer(Remove, NoSuccessor, 202, active_item)
	set == Ok({ name: "olddev/json", result: Moved, successor: Ok("a/b"), offer: Err(None), state: Moved })
		and gone_204 == Ok({ name: "olddev/json", result: Removed, successor: Err(None), offer: Err(None), state: Active })
			and gone_202 == Ok({ name: "olddev/json", result: Removed, successor: Err(None), offer: Err(None), state: Active })
}

# R-TP12, R-MV4 (slice 253, mutation gap G1): a 403 `forbidden` that has an `issues_url` member keeps the generic refusal text, not the operator text.
expect {
	body = js("{'type':'/errors/forbidden','title':'T','status':403,'detail':'D','issues_url':'https://github.com/roc-talon/talon/issues'}")
	got = MoveCheck.failure({ origin, version: "0.0.1", tries: 1, renewed: Bool.False, plan: Set("acme/roc-json"), reply: Ok({ status: 403, headers: [], body }) })
	got.message == "D (/errors/forbidden). Fix the names or the workflow, then run the command again."
		and got.kind.code() == 20
}
