import lib.Fail
import lib.JsonDoc
import lib.YankCheck

YankcheckTest :: [].{}

# Slice 249 (CLI 1 R-CM21, R-EC2, R-RG9; Registry R-YK1, R-YK3, R-YK6, R-AP1, R-AP34, R-TP2; CLI 3 R-E6): the pure part of `tln yank`. The flow is the L2 cases `yank/yk1` to `yk12`.
# The texts and the `data` members are proposals for the review (R-OUT2, TW24). The tests of Q629-1 (order) and Q629-3 (client check of the reason) follow the recommendation of the slice file.
# ' stands for " in a JSON text.

h1 = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

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

# One release row (R-AP49). `tag` is a JSON text (`'2.1.0'` or `null`), `reason` is a JSON text (`'parse bug'` or `null`).
row : U64, Str, Bool, Str -> Str
row = |index, tag, yanked, reason| js("{'log_index':${index.to_str()},'hash':'${h1}','group':'github.com/acme/json/releases/download/{v}/','series':'2','version':'2.1.0','url':'https://github.com/acme/json/releases/download/2.1.0/${h1}.tar.zst','tag':${tag},'roc_version':null,'repo':'acme/json','published_at':1792065600000,'yanked':${if yanked "true" else "false"},'yank_reason':${reason},'withdrawn':null,'provenance':['oidc']}")

list_of = |rows| "{\"releases\":[${Str.join_with(rows, ",")}],\"checked\":null,\"repos\":[]}"

# R-CM21, R-RG9, R-EC2: a registry that is `direct` is exit 2; `--offline` is exit 15 (the model of R-PUB4 item 1, Q629-1). Each text names the command.
expect {
	YankCheck.direct({}).message == "tln yank needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
		and YankCheck.direct({}).kind.name() == "usage"
			and YankCheck.direct({}).kind.code() == 2
				and YankCheck.offline({}).message == "tln yank needs the network: --offline sends no request"
					and YankCheck.offline({}).kind.code() == 15
}

# R-CM21: the one operand is the tag. No operand, or an empty one, and 2 or more are exit 2.
expect {
	YankCheck.operand(["2.1.0"]) == Ok("2.1.0")
		and YankCheck.operand(["v1.0.0-rc1"]) == Ok("v1.0.0-rc1")
			and msg_of(YankCheck.operand([])) == "tln yank needs a tag: tln yank <tag> [--reason <text>] [--undo]"
				and msg_of(YankCheck.operand([""])) == "tln yank needs a tag: tln yank <tag> [--reason <text>] [--undo]"
					and msg_of(YankCheck.operand(["2.1.0", "2.2.0"])) == "tln yank takes one tag: unexpected '2.2.0'"
						and kind_of(YankCheck.operand([])) == "usage"
							and kind_of(YankCheck.operand(["a", "b", "c"])) == "usage"
}

# R-YK6, R-CM21 (Q629-3, follows the recommendation): the client checks the reason before any request, as the registry does. No reason, an empty one and 500 bytes are good. 501 bytes are too long (bytes, not characters: 251 times a 2-byte character is 502 bytes).
# A character of the category Cc is refused: a tab, a new line, U+007F and U+0080 (Q246-3). The length is checked first.
expect {
	long = |n| Str.join_with(List.repeat("a", n), "")
	two_byte = |n| Str.join_with(List.repeat("\u(e9)", n), "")
	YankCheck.reason(Err(None)) == Ok({})
		and YankCheck.reason(Ok("")) == Ok({})
			and YankCheck.reason(Ok("parse bug, use 2.1.1")) == Ok({})
				and YankCheck.reason(Ok(long(500))) == Ok({})
					and YankCheck.reason(Ok(two_byte(250))) == Ok({})
						and msg_of(YankCheck.reason(Ok(long(501)))) == "the reason is 501 bytes: the registry takes at most 500"
							and msg_of(YankCheck.reason(Ok(two_byte(251)))) == "the reason is 502 bytes: the registry takes at most 500"
								and msg_of(YankCheck.reason(Ok("a\tb"))) == "the reason has a control character: a reason is one line of plain text"
									and msg_of(YankCheck.reason(Ok("a\nb"))) == "the reason has a control character: a reason is one line of plain text"
										and msg_of(YankCheck.reason(Ok("a\u(7f)b"))) == "the reason has a control character: a reason is one line of plain text"
											and msg_of(YankCheck.reason(Ok("a\u(80)b"))) == "the reason has a control character: a reason is one line of plain text"
												and msg_of(YankCheck.reason(Ok("${long(600)}\n"))) == "the reason is 601 bytes: the registry takes at most 500"
													and kind_of(YankCheck.reason(Ok("a\tb"))) == "usage"
}

# Q629-2 (approved: exit 2; the text and the place are a proposal, pending review): `--undo` with `--reason` is a usage error, also for an empty reason. Other combinations are good. The flow checks it after the operand and before the content of the reason.
expect {
	both = YankCheck.undo_reason({ undo: Bool.True, reason: Ok("parse bug") })
	empty = YankCheck.undo_reason({ undo: Bool.True, reason: Ok("") })
	msg_of(both) == "tln yank --undo takes no --reason"
		and kind_of(both) == "usage"
			and kind_of(empty) == "usage"
				and YankCheck.undo_reason({ undo: Bool.True, reason: Err(None) }) == Ok({})
					and YankCheck.undo_reason({ undo: Bool.False, reason: Ok("parse bug") }) == Ok({})
						and YankCheck.undo_reason({ undo: Bool.False, reason: Err(None) }) == Ok({})
}

# R-YK3: the repository is `GITHUB_REPOSITORY`; `GITHUB_REF` is not read (a yank runs in a `workflow_dispatch` job, on any ref). The repository must be 2 non-empty parts split by one `/`, each of ASCII letters, digits, `.`, `_` and `-`. Each failure is exit 2 and names the variable.
expect {
	good = [("GITHUB_REPOSITORY", "acme/json"), ("HOME", "/h")]
	set_repo = |value| [("GITHUB_REPOSITORY", value)]
	run_text = "tln yank runs in a GitHub Actions job."
	YankCheck.job(good) == Ok({ owner: "acme", repo: "json" })
		and YankCheck.job(set_repo("Acme/roc-json_2.x")) == Ok({ owner: "Acme", repo: "roc-json_2.x" })
			and msg_of(YankCheck.job([("HOME", "/h")])) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
				and msg_of(YankCheck.job(set_repo(""))) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
					and msg_of(YankCheck.job(set_repo("acme"))) == "GITHUB_REPOSITORY is acme, not of the form owner/repo."
						and msg_of(YankCheck.job(set_repo("acme/json/x"))) == "GITHUB_REPOSITORY is acme/json/x, not of the form owner/repo."
							and msg_of(YankCheck.job(set_repo("acme/"))) == "GITHUB_REPOSITORY is acme/, not of the form owner/repo."
								and msg_of(YankCheck.job(set_repo("ac me/json"))) == "GITHUB_REPOSITORY is ac me/json, not of the form owner/repo."
									and kind_of(YankCheck.job(set_repo("acme"))) == "usage"
}

# R-YK3, R-AP27, R-TP2: the OIDC variables. The URL is checked first. The text names `id-token: write`. Exit 2. An empty value is no value.
expect {
	both = [("ACTIONS_ID_TOKEN_REQUEST_URL", "http://127.0.0.1:8/token?api-version=2.0"), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "req1")]
	only_url = [("ACTIONS_ID_TOKEN_REQUEST_URL", "http://127.0.0.1:8/token?api-version=2.0")]
	empty_url = [("ACTIONS_ID_TOKEN_REQUEST_URL", ""), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "req1")]
	YankCheck.oidc(both) == Ok({ url: "http://127.0.0.1:8/token?api-version=2.0", token: "req1" })
		and msg_of(YankCheck.oidc([])) == "tln yank needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."
			and msg_of(YankCheck.oidc(only_url)) == "tln yank needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_TOKEN is not set. In a GitHub Actions job, set permissions: id-token: write."
				and msg_of(YankCheck.oidc(empty_url)) == "tln yank needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write."
					and kind_of(YankCheck.oidc([])) == "usage"
}

# R-YK3, R-AP1: the release of the tag is the row of the answer whose `tag` is equal. Other rows and a row with no tag are not it.
expect {
	body = list_of([row(40, "'2.0.0'", Bool.False, "null"), row(41, "'2.1.0'", Bool.True, "'parse bug'"), row(42, "null", Bool.False, "null")])
	found = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "2.1.0", status: 200, body })
	first = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "2.0.0", status: 200, body })
	is_41 = match found {
		Ok(r) => r.log_index == 41 and r.yanked and r.yank_reason == Ok("parse bug") and r.version == "2.1.0"
		Err(_) => Bool.False
	}
	is_40 = match first {
		Ok(r) => r.log_index == 40 and !r.yanked and r.yank_reason == Err(None)
		Err(_) => Bool.False
	}
	is_41 and is_40
}

# Q629-7 (approved: byte for byte, case-sensitive): the tag `V1.0.0` is not the tag `v1.0.0`, in either direction.
expect {
	lower = list_of([row(4, "'v1.0.0'", Bool.False, "null")])
	upper = list_of([row(4, "'V1.0.0'", Bool.False, "null")])
	no_release = |tag| "acme/json has no indexed release for the tag ${tag}. Run tln publish for the tag first, or wait until the registry indexes it."
	of = |tag, body| YankCheck.release({ origin, owner: "acme", repo: "json", tag, status: 200, body })
	msg_of(of("V1.0.0", lower)) == no_release("V1.0.0")
		and msg_of(of("v1.0.0", upper)) == no_release("v1.0.0")
			and kind_of(of("V1.0.0", lower)) == "usage"
				and kind_of(of("v1.0.0", lower)) == "ok"
}

# Q629-8 (approved: exit 1, internal): 2 rows with the same tag are a fault of the registry. The text names both log indexes.
expect {
	body = list_of([row(4, "'1.0.0'", Bool.False, "null"), row(9, "'1.0.0'", Bool.False, "null")])
	got = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "1.0.0", status: 200, body })
	kind_of(got) == "internal"
		and msg_of(got) == "the registry gave 2 releases for the tag 1.0.0 (log indexes 4, 9)"
}

# R-CM21, R-EC2: a tag with no indexed release is exit 2: the tag is not in the list, the row has no tag, the tag differs (`v2.1.0` is not `2.1.0`), or the answer is 404 (the repository has no indexed release).
expect {
	body = list_of([row(41, "'v2.1.0'", Bool.False, "null"), row(42, "null", Bool.False, "null")])
	none = |tag, status, text| YankCheck.release({ origin, owner: "acme", repo: "json", tag, status, body: text })
	no_release = |tag| "acme/json has no indexed release for the tag ${tag}. Run tln publish for the tag first, or wait until the registry indexes it."
	problem = "{\"type\":\"/errors/not-found\",\"title\":\"T\",\"status\":404,\"detail\":\"D\"}"
	msg_of(none("2.1.0", 200, body)) == no_release("2.1.0")
		and msg_of(none("2.2.0", 200, body)) == no_release("2.2.0")
			and msg_of(none("2.1.0", 404, problem)) == no_release("2.1.0")
				and msg_of(none("2.1.0", 200, list_of([]))) == no_release("2.1.0")
					and kind_of(none("2.1.0", 404, problem)) == "usage"
						and kind_of(none("2.1.0", 200, body)) == "usage"
}

# R-E6, R-RG9: another answer to the read is `Registry.refuse` (a `Get`: exit 15, never 20). With a `source` a 5xx is the stop text of R-RG9 with no advice for `direct` (a yank needs a registry). A 200 that is not a release list is exit 15.
expect {
	problem = |status, type| "{\"type\":\"/errors/${type}\",\"title\":\"T\",\"status\":${status.to_str()},\"detail\":\"D\"}"
	plain = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "2.1.0", status: 500, body: problem(500.U16, "internal") })
	set = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "2.1.0", status: 500, body: problem(500.U16, "internal"), source: "TALON_REGISTRY" })
	denied = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "2.1.0", status: 403, body: problem(403.U16, "forbidden") })
	bad = YankCheck.release({ origin, owner: "acme", repo: "json", tag: "2.1.0", status: 200, body: "<html>" })
	msg_of(plain) == "the registry answered 500 (/errors/internal). Try again later."
		and kind_of(plain) == "network"
			and msg_of(set) == "the registry ${origin} (TALON_REGISTRY) answered 500: D."
				and kind_of(set) == "network"
					and kind_of(denied) == "network"
						and kind_of(bad) == "network"
							and msg_of(bad).starts_with("the answer of the registry ${origin} is not a release list: ")
}

# R-YK1, R-AP45, R-AP23, R-YK6: the request. `PUT` has the body `{"reason":"<text>"}` (JSON escapes), `{}` for no reason. `DELETE` has no body and no `Content-Type`, and does not use the reason. Both: `User-Agent`, then `Authorization: Bearer`, 20 s.
expect {
	put = |reason| YankCheck.request({ origin, version: "0.0.1", token: "jwt1", log_index: 41, undo: Bool.False, reason })
	delete = YankCheck.request({ origin, version: "0.0.1", token: "jwt1", log_index: 41, undo: Bool.True, reason: Ok("ignored") })
	put(Ok("parse bug")).method == Put
		and put(Ok("parse bug")).url == "http://127.0.0.1:9/v1/releases/41/yank"
			and put(Ok("parse bug")).body == "{\"reason\":\"parse bug\"}"
				and put(Ok("a\"b")).body == "{\"reason\":\"a\\\"b\"}"
					and put(Err(None)).body == "{}"
						and put(Ok("x")).headers == [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json"), ("Authorization", "Bearer jwt1")]
							and put(Ok("x")).timeout_s == 20
								and delete.method == Delete
									and delete.url == "http://127.0.0.1:9/v1/releases/41/yank"
										and delete.body == ""
											and delete.headers == [("User-Agent", "tln/0.0.1"), ("Authorization", "Bearer jwt1")]
												and delete.timeout_s == 20
}

problem = |status, type, detail| js("{'type':'/errors/${type}','title':'T','status':${status.to_str()},'detail':'${detail}'}")

# R-E6, R-AP22, R-J7, R-AP34: the failure of a write. A refused write is exit 20, with `details` (`status`, `type`). The default text of `Registry.refuse` (no text for `forbidden`: the detail of the registry says which claim failed). A 401 after the new token is exit 20 with `the registry refused the new token too`.
expect {
	of = |status, type, headers, tries, renewed| YankCheck.failure({ origin: "https://registry.example.org", version: "0.0.1", tries, renewed, undo: Bool.False, reply: Ok({ status, headers, body: problem(status, type, "D") }) })
	forbidden = of(403, "forbidden", [], 1, Bool.False)
	missing = of(404, "not-found", [], 1, Bool.False)
	refused = of(401, "unauthenticated", [], 2, Bool.True)
	forbidden.message == "D (/errors/forbidden). Fix the release or the workflow, then run the command again."
		and forbidden.kind.code() == 20
			and forbidden.details == Ok(JsonDoc.Obj([("status", Num(403)), ("type", Text("/errors/forbidden"))]))
				and missing.kind.code() == 20
					and refused.message == "D (/errors/unauthenticated): the registry refused the new token too."
						and refused.kind.code() == 20
							and of(400, "bad-request", [], 1, Bool.False).kind.code() == 1
}

# R-AP34, R-E6: after 4 requests a 429, a busy 503 and a 5xx are exit 15 with the number of requests; with one request the text of `Registry.refuse`.
expect {
	of = |status, type, headers, tries| YankCheck.failure({ origin: "https://registry.example.org", version: "0.0.1", tries, renewed: Bool.False, undo: Bool.False, reply: Ok({ status, headers, body: problem(status, type, "D") }) })
	of(429, "rate-limited", [("Retry-After", "7")], 4).message == "the registry answered 429 (/errors/rate-limited) after 4 requests. Try again in 7 s."
		and of(503, "busy", [], 4).message == "the registry is busy (503) after 4 requests. Try again later."
			and of(502, "upstream", [], 4).message == "the registry answered 502 (/errors/upstream) 4 times. Try again later."
				and of(502, "upstream", [], 4).kind.code() == 15
					and of(429, "rate-limited", [("Retry-After", "7")], 1).message == "the registry answered 429 (/errors/rate-limited). Try again in 7 s."
}

# R-AP34, R-E6, R-RG9: no answer. After 4 requests: exit 15, the number of requests, and the yank (or the undo) may be done. With a `source` the URL is followed by it. With one request: the text of `Registry.no_answer`.
expect {
	no_answer = |tries, undo, source| YankCheck.failure({ origin, version: "0.0.1", tries, renewed: Bool.False, undo, reply: Err(Timeout), source })
	one = YankCheck.failure({ origin, version: "0.0.1", tries: 1, renewed: Bool.False, undo: Bool.False, reply: Err(Failed("connection refused")) })
	no_answer(4, Bool.False, "").message == "the registry ${origin} gave no answer 4 times: no answer in 20 s. The yank may be done. Run the command again."
		and no_answer(4, Bool.True, "").message == "the registry ${origin} gave no answer 4 times: no answer in 20 s. The undo may be done. Run the command again."
			and no_answer(4, Bool.False, "TALON_REGISTRY").message == "the registry ${origin} (TALON_REGISTRY) gave no answer 4 times: no answer in 20 s. The yank may be done. Run the command again."
				and no_answer(4, Bool.False, "").kind.code() == 15
					and one.message == "the registry ${origin} gave no answer: connection refused. Try again later."
}

# R-YK1, R-AP49, R-OUT2: the answer of a good request. `changed` compares the state before (the R-AP1 row) with the state in the answer. The reason is the one of the answer.
expect {
	answer = |before, yanked, reason| YankCheck.answer({ origin, name: "acme/json", tag: "2.1.0", before, status: 200, body: "{\"release\":${row(41, "'2.1.0'", yanked, reason)}}" })
	yank = answer(Bool.False, Bool.True, "'parse bug'")
	bare = answer(Bool.False, Bool.True, "null")
	undo = answer(Bool.True, Bool.False, "null")
	same = answer(Bool.True, Bool.True, "'old reason'")
	none = answer(Bool.False, Bool.False, "null")
	yank == Ok({ name: "acme/json", tag: "2.1.0", version: "2.1.0", log_index: 41, yanked: Bool.True, reason: Ok("parse bug"), changed: Bool.True })
		and bare == Ok({ name: "acme/json", tag: "2.1.0", version: "2.1.0", log_index: 41, yanked: Bool.True, reason: Err(None), changed: Bool.True })
			and undo == Ok({ name: "acme/json", tag: "2.1.0", version: "2.1.0", log_index: 41, yanked: Bool.False, reason: Err(None), changed: Bool.True })
				and same == Ok({ name: "acme/json", tag: "2.1.0", version: "2.1.0", log_index: 41, yanked: Bool.True, reason: Ok("old reason"), changed: Bool.False })
					and none == Ok({ name: "acme/json", tag: "2.1.0", version: "2.1.0", log_index: 41, yanked: Bool.False, reason: Err(None), changed: Bool.False })
						and kind_of(YankCheck.answer({ origin, name: "acme/json", tag: "2.1.0", before: Bool.False, status: 200, body: "{\"x\":1}" })) == "network"
}

# R-OUT2 (proposal): the stdout lines of the 4 states (CLI 3 catalog row `yank`: `yanked <name> <version> (tag <tag>): <reason>` and `unyanked ...`; the 2 lines of a request that changed nothing are a proposal).
expect {
	done = |yanked, reason, changed| { name: "acme/json", tag: "v2.1.0", version: "2.1.0", log_index: 41, yanked, reason, changed }
	YankCheck.lines(done(Bool.True, Ok("parse bug"), Bool.True)) == ["yanked acme/json 2.1.0 (tag v2.1.0): parse bug\n"]
		and YankCheck.lines(done(Bool.True, Err(None), Bool.True)) == ["yanked acme/json 2.1.0 (tag v2.1.0)\n"]
			and YankCheck.lines(done(Bool.False, Err(None), Bool.True)) == ["unyanked acme/json 2.1.0 (tag v2.1.0)\n"]
				and YankCheck.lines(done(Bool.True, Ok("old reason"), Bool.False)) == ["acme/json 2.1.0 (tag v2.1.0) is yanked already: old reason\n"]
					and YankCheck.lines(done(Bool.True, Err(None), Bool.False)) == ["acme/json 2.1.0 (tag v2.1.0) is yanked already\n"]
						and YankCheck.lines(done(Bool.False, Err(None), Bool.False)) == ["acme/json 2.1.0 (tag v2.1.0) is not yanked\n"]
}

# R-OUT4, CLI 3 catalog row `yank`: the `data` members and their order: `name`, `tag`, `version`, `log_index`, `yanked`, `reason` (`null` for none), `changed`.
expect {
	done = |yanked, reason, changed| { name: "acme/json", tag: "2.1.0", version: "2.1.0", log_index: 41, yanked, reason, changed }
	YankCheck.data(done(Bool.True, Ok("parse bug"), Bool.True)).render() == js("{'name':'acme/json','tag':'2.1.0','version':'2.1.0','log_index':41,'yanked':true,'reason':'parse bug','changed':true}")
		and YankCheck.data(done(Bool.False, Err(None), Bool.False)).render() == js("{'name':'acme/json','tag':'2.1.0','version':'2.1.0','log_index':41,'yanked':false,'reason':null,'changed':false}")
}
