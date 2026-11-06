import lib.Db
import lib.Fail
import lib.JsonDoc
import lib.Publish

PublishTest :: [].{}

# Slice 221 (CLI 1 R-CM13, R-PUB1 to R-PUB3; Registry R-AP8, R-AP27, R-AP34, R-AP71, R-TP2, R-TP17; Resolution R-PB5; CLI 3 R-E6): the pure part of `tln publish`. The flow is the L2 cases `publish/pu1` to `pu8`.
# The texts and the `data` members are proposals for the review (R-OUT2, TW24), except the 3 texts of the CLI 3 R-E6 example and the text of R-PUB3. A fact that the design does not give is a question in the slice file (Q3 to Q11).
# ' stands for " in a JSON text.

h1 = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

h2 = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"

asset_url = "https://github.com/acme/json/releases/download/2.1.0/${h1}.tar.zst"

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

# R-PUB1, R-AP27: the job. A good environment gives the repository and the tag (no `refs/tags/`). Each failure is `Usage` (exit 2) with the text that names the variable, and a branch ref says that the job must run on a tag.
expect {
	good = [("GITHUB_REPOSITORY", "acme/json"), ("GITHUB_REF", "refs/tags/2.1.0"), ("HOME", "/h")]
	set_var = |name, value| good.map(|(n, v)| if n == name (n, value) else (n, v))
	drop_var = |name| good.keep_if(|(n, _)| n != name)
	run_text = "tln publish runs in a GitHub Actions job."
	Publish.job(good) == Ok({ owner: "acme", repo: "json", tag: "2.1.0" })
		and msg_of(Publish.job(drop_var("GITHUB_REPOSITORY"))) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
			and msg_of(Publish.job(set_var("GITHUB_REPOSITORY", ""))) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
				and msg_of(Publish.job(drop_var("GITHUB_REF"))) == "GITHUB_REF is not set or is empty. ${run_text}"
					and msg_of(Publish.job(set_var("GITHUB_REF", ""))) == "GITHUB_REF is not set or is empty. ${run_text}"
						and msg_of(Publish.job(set_var("GITHUB_REF", "refs/heads/main"))) == "GITHUB_REF is refs/heads/main, not a tag. The job must run on a tag: tln publish registers the release of the tag."
							and msg_of(Publish.job(set_var("GITHUB_REF", "refs/pull/1/merge"))) == "GITHUB_REF is refs/pull/1/merge, not a tag. The job must run on a tag: tln publish registers the release of the tag."
								and kind_of(Publish.job(drop_var("GITHUB_REF"))) == "usage"
									and kind_of(Publish.job(set_var("GITHUB_REF", "refs/heads/main"))) == "usage"
										# Q512, R-PUB4 item 5: the repository is 2 non-empty parts of letters, digits, . _ - split by one /. Q514, item 8: the tag is one safe path part. Both are exit 2.
										and ["a", "a/b/c", "/b", "a/", "a b/c", "a/b c", "a/b%1", ""].all(|repo| kind_of(Publish.job(set_var("GITHUB_REPOSITORY", repo))) == "usage")
											and msg_of(Publish.job(set_var("GITHUB_REPOSITORY", "a/b/c"))) == "GITHUB_REPOSITORY is a/b/c, not of the form owner/repo."
												and Publish.job(set_var("GITHUB_REPOSITORY", "Ac_me-1.x/j.s_o-n")) == Ok({ owner: "Ac_me-1.x", repo: "j.s_o-n", tag: "2.1.0" })
													and msg_of(Publish.job(set_var("GITHUB_REF", "refs/tags/pkg/v1"))) == "the tag pkg/v1 is not one safe part of an asset URL: use letters, digits, . _ - + ~. Name the tag with a version."
														and ["v 1", "v%1", "v?x", "a/b", "v1#"].all(|tag| kind_of(Publish.job(set_var("GITHUB_REF", "refs/tags/${tag}"))) == "usage")
															and Publish.job(set_var("GITHUB_REF", "refs/tags/v1.0.0-rc.1+b~2_x")) == Ok({ owner: "acme", repo: "json", tag: "v1.0.0-rc.1+b~2_x" })
																# The repository is checked first when both are missing.
																and msg_of(Publish.job([])) == "GITHUB_REPOSITORY is not set or is empty. ${run_text}"
}

# R-AP27, R-TP2: no OIDC variable, no token, exit 2 (`Usage`). The message names `id-token: write` and the first missing variable (the URL first). An empty value is no value.
expect {
	good = [("ACTIONS_ID_TOKEN_REQUEST_URL", "http://r/token?api-version=2.0"), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "req1")]
	text = |name| "tln publish needs an OIDC token, and ${name} is not set. In a GitHub Actions job, set permissions: id-token: write."
	Publish.oidc(good) == Ok({ url: "http://r/token?api-version=2.0", token: "req1" })
		and msg_of(Publish.oidc([])) == text("ACTIONS_ID_TOKEN_REQUEST_URL")
			and msg_of(Publish.oidc([("ACTIONS_ID_TOKEN_REQUEST_URL", ""), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "req1")])) == text("ACTIONS_ID_TOKEN_REQUEST_URL")
				and msg_of(Publish.oidc([("ACTIONS_ID_TOKEN_REQUEST_URL", "http://r/t?x=1")])) == text("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
					and msg_of(Publish.oidc([("ACTIONS_ID_TOKEN_REQUEST_URL", "http://r/t?x=1"), ("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "")])) == text("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
						and kind_of(Publish.oidc([])) == "usage"
}

# R-PUB2: the URL of the release of the tag, on the API base of the run (R-EV19).
expect {
	Publish.release_url({ api: "https://api.github.com", owner: "acme", repo: "json", tag: "2.1.0" }) == "https://api.github.com/repos/acme/json/releases/tags/2.1.0"
		and Publish.release_url({ api: "http://127.0.0.1:5", owner: "o", repo: "r", tag: "v1.0.0" }) == "http://127.0.0.1:5/repos/o/r/releases/tags/v1.0.0"
}

release = |tag, flags, assets| js("{'tag_name':'${tag}',${flags}'published_at':'2026-10-14T10:00:00Z','assets':[${Str.join_with(assets, ",")}]}")

pkg = |tag, hash| js("{'name':'${hash}.tar.zst','size':1234,'browser_download_url':'https://github.com/acme/json/releases/download/${tag}/${hash}.tar.zst'}")

asset_of = |reply| Publish.asset({ api: "https://api.github.com", owner: "acme", repo: "json", tag: "2.1.0", now: 1792065600, reply })

ok_reply = |body| Ok({ status: 200, headers: [], body })

status_reply = |status, headers| Ok({ status, headers, body: js("{'message':'x'}") })

# R-PUB2, R-DI3, R-DI4, R-DI5: the asset URL of a good release, and each release that is no candidate: exit 2 (`Usage`), the message names the case. The upload must run before `tln publish` (R-PB5).
expect {
	good = release("2.1.0", "'draft':false,'prerelease':false,", [pkg("2.1.0", h1)])
	other = js("{'name':'docs.tar.gz','size':5,'browser_download_url':'https://github.com/acme/json/releases/download/2.1.0/docs.tar.gz'}")
	asset_of(ok_reply(good)) == Ok(asset_url)
		and asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':false,", [other, pkg("2.1.0", h1)]))) == Ok(asset_url)
			and msg_of(asset_of(status_reply(404, []))) == "acme/json has no release for the tag 2.1.0. Create the release and upload the package first, then run tln publish."
				and msg_of(asset_of(ok_reply(release("2.1.0", "'draft':true,'prerelease':false,", [pkg("2.1.0", h1)])))) == "the release 2.1.0 of acme/json is a draft. A draft is not published: publish the release first."
					and msg_of(asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':true,", [pkg("2.1.0", h1)])))) == "the release 2.1.0 of acme/json is a prerelease. A prerelease is not used."
						and msg_of(asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':false,", [other])))) == "the release 2.1.0 of acme/json has no <hash>.tar.zst asset. The upload must run before tln publish."
							and msg_of(asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':false,", [])))) == "the release 2.1.0 of acme/json has no <hash>.tar.zst asset. The upload must run before tln publish."
								and msg_of(asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':false,", [pkg("2.1.0", h1), pkg("2.1.0", h2)])))) == "the release 2.1.0 of acme/json has 2 package assets (${h1}, ${h2}). A release has one."
									and kind_of(asset_of(status_reply(404, []))) == "usage"
										and kind_of(asset_of(ok_reply(release("2.1.0", "'draft':true,'prerelease':false,", [pkg("2.1.0", h1)])))) == "usage"
											and kind_of(asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':false,", [])))) == "usage"
												and kind_of(asset_of(ok_reply(release("2.1.0", "'draft':false,'prerelease':false,", [pkg("2.1.0", h1), pkg("2.1.0", h2)])))) == "usage"
}

# R-PUB2, R-DI5: an asset URL with no version that Talon reads (here the tag `rolling`) is exit 2, with the URL in the message.
expect {
	bad = release("rolling", "'draft':false,'prerelease':false,", [pkg("rolling", h1)])
	url = "https://github.com/acme/json/releases/download/rolling/${h1}.tar.zst"
	msg_of(asset_of(ok_reply(bad))) == "the asset URL ${url} has no version X.Y.Z that tln can read. Name the tag with a version."
		and kind_of(asset_of(ok_reply(bad))) == "usage"
}

# R-PUB2, R-DI13: a 5xx answer, another status, a body that is no release, no answer: exit 15 (`Network`). A rate limit (403 with `x-ratelimit-remaining: 0`) has the text of R-DI13 (`Github.rate_limit_failure`) and exit 15.
expect {
	url = "https://api.github.com/repos/acme/json/releases/tags/2.1.0"
	limited = status_reply(403, [("x-ratelimit-remaining", "0"), ("x-ratelimit-reset", "1792069200")])
	kind_of(asset_of(status_reply(502, []))) == "network"
		and msg_of(asset_of(status_reply(502, []))) == "GitHub answered 502 for ${url}"
			and kind_of(asset_of(status_reply(500, []))) == "network"
				and kind_of(asset_of(status_reply(403, []))) == "network"
					and kind_of(asset_of(ok_reply("not json"))) == "network"
						and msg_of(asset_of(Err(Timeout))) == "cannot reach ${url}: no answer in 20 s. Try again later."
							and msg_of(asset_of(Err(Failed("connection refused")))) == "cannot reach ${url}: connection refused. Try again later."
								and kind_of(asset_of(Err(Timeout))) == "network"
									and kind_of(asset_of(limited)) == "network"
										and msg_of(asset_of(limited)) == "GitHub API rate limit reached. It resets at 2026-10-15T13:00:00Z. Set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login)."
}

# R-TP2, R-TP17: the token request is a GET of the request URL of GitHub Actions and `&audience=<registry base URL>` (the text B, percent-encoded: Q513), with the one header `Authorization: bearer <request token>` (the word in lower case). 20 s (R-DA9).
expect {
	got = Publish.token_request({ oidc: { url: "https://pipelines.actions.githubusercontent.com/x/y?api-version=2.0", token: "req1" }, origin: "https://registry.example.org" })
	got
		== {
			method: Get,
			url: "https://pipelines.actions.githubusercontent.com/x/y?api-version=2.0&audience=https%3A%2F%2Fregistry.example.org",
			headers: [("Authorization", "bearer req1")],
			body: "",
			timeout_s: 20,
		}
		and Publish.token_request({ oidc: { url: "http://127.0.0.1:8/token?api-version=2.0", token: "t" }, origin: origin }).url == "http://127.0.0.1:8/token?api-version=2.0&audience=http%3A%2F%2F127.0.0.1%3A9"
}

# R-TP2, Q515: the JWT is the member `value` of a 200 answer. A 401 or 403 is exit 2 with the `id-token: write` text. No answer, 5xx, 429, a body that is not JSON or has no text `value`: exit 15.
expect {
	ok = Ok({ status: 200, headers: [], body: js("{'count':1,'value':'jwt1'}") })
	Publish.token(ok) == Ok("jwt1")
		and kind_of(Publish.token(Ok({ status: 200, headers: [], body: js("{'count':1}") }))) == "network"
			and msg_of(Publish.token(Ok({ status: 200, headers: [], body: js("{'count':1}") }))) == "the GitHub OIDC token request failed: the answer has no token"
				and msg_of(Publish.token(Ok({ status: 403, headers: [], body: "" }))) == "the GitHub OIDC token request was refused (403). The job needs permissions: id-token: write."
					and msg_of(Publish.token(Ok({ status: 401, headers: [], body: "" }))) == "the GitHub OIDC token request was refused (401). The job needs permissions: id-token: write."
						and kind_of(Publish.token(Ok({ status: 403, headers: [], body: "" }))) == "usage"
							and kind_of(Publish.token(Ok({ status: 401, headers: [], body: "" }))) == "usage"
								and msg_of(Publish.token(Ok({ status: 429, headers: [], body: "" }))) == "the GitHub OIDC token request failed: answered 429"
									and kind_of(Publish.token(Ok({ status: 429, headers: [], body: "" }))) == "network"
										and kind_of(Publish.token(Ok({ status: 503, headers: [], body: "" }))) == "network"
											and kind_of(Publish.token(Ok({ status: 200, headers: [], body: "not json" }))) == "network"
												and kind_of(Publish.token(Ok({ status: 200, headers: [], body: js("{'value':5}") }))) == "network"
													and msg_of(Publish.token(Err(Timeout))) == "the GitHub OIDC token request failed: no answer in 20 s"
														and msg_of(Publish.token(Err(Failed("refused")))) == "the GitHub OIDC token request failed: refused"
															and kind_of(Publish.token(Err(Timeout))) == "network"
}

nights : U64 -> List(Str)
nights = |n| List.repeat("", n).map_with_index(
	|_, i| {
		pad = |k| if k < 10 "0${k.to_str()}" else k.to_str()
		"nightly-${(2020 + i // 336).to_str()}-${pad(1 + (i % 336) // 28)}-${pad(1 + i % 28)}-0000${(1000 + i).to_str()}"
	},
)

fact = |hash, nightly, target, outcome, closure| { hash, nightly, target, outcome, modules: [], closure }

n1 = "nightly-2026-10-12-2664a27"

n2 = "nightly-2026-10-13-bbbbbbb"

n3 = "nightly-2026-10-14-38a3029"

n4 = "nightly-2026-10-15-0a0a0a0"

wire = |nightly, result| { nightly, target: "any", result, error_digest: Err(None) }

# R-PU5, R-PB5, R-AP71: the real facts of the hash. All 4 outcomes go (also a hang). A row with a `closure` (a build), a row with a target other than `any`, and a row of another hash do not go. Sorted by nightly (text order). `error_digest` is null (Q3).
expect {
	stored = [
		fact(h1, n3, "any", Fail, ""),
		fact(h1, n1, "any", Pass, ""),
		fact(h1, n4, "any", Crash, ""),
		fact(h1, n2, "any", Hang, ""),
		fact(h1, n1, "linux_x86_64", Pass, "abc"),
		fact(h1, n2, "x64musl", Pass, ""),
		fact(h2, n1, "any", Pass, ""),
	]
	Publish.facts({ hash: h1, stored })
		== { list: [wire(n1, "pass"), wire(n2, "hang"), wire(n3, "fail"), wire(n4, "crash")], warning: Err(None) }
		and Publish.facts({ hash: h1, stored: [] }) == { list: [], warning: Err(None) }
			and Publish.facts({ hash: h1, stored: [fact(h2, n1, "any", Pass, "")] }) == { list: [], warning: Err(None) }
				and Publish.facts({ hash: h1, stored: [fact(h1, n1, "linux_x86_64", Pass, "abc")] }) == { list: [], warning: Err(None) }
}

# R-AP8, R-AP26, R-AP45, R-AP71, R-PU2: `POST <origin>/v1/releases` with the headers `User-Agent`, `Content-Type`, `Authorization: Bearer <JWT>` (in this order) and the body `{compat, url}` (the members of `records.Compat.encode_publish`, in its order). 20 s.
expect {
	got = Publish.request({ origin, version: "0.0.1", token: "jwt1", url: asset_url, facts: [wire(n1, "pass"), wire(n3, "fail")] })
	body = js("{'compat':[{'error_digest':null,'nightly':'${n1}','result':'pass','target':'any'},{'error_digest':null,'nightly':'${n3}','result':'fail','target':'any'}],'url':'${asset_url}'}")
	got
		== {
			method: Post,
			url: "http://127.0.0.1:9/v1/releases",
			headers: [("User-Agent", "tln/0.0.1"), ("Content-Type", "application/json"), ("Authorization", "Bearer jwt1")],
			body,
			timeout_s: 20,
		}
}

# R-PUB3, R-AP71: no fact, no `compat` member (it is optional). The warning text is the design text.
expect {
	got = Publish.request({ origin, version: "0.0.1", token: "jwt1", url: asset_url, facts: [] })
	got.body == js("{'url':'${asset_url}'}")
		and got.url == "http://127.0.0.1:9/v1/releases"
			and Publish.no_facts(h1) == "no probe facts for ${h1}: run tln probe --range <bundle file> before tln publish"
}

reply_of = |status, headers| Ok({ status, headers, body: "" })

# R-AP34: after a 429, a 5xx or no answer, wait and send again, at most 3 times. The wait is `Retry-After` (whole seconds, at most 60 s) or 2 s, 8 s, 30 s. The 4th failure stops.
expect {
	next = |retries, reply| Publish.next({ retries, renewed: Bool.False, reply })
	next(0, reply_of(502, [])) == Wait(2000)
		and next(1, reply_of(502, [])) == Wait(8000)
			and next(2, reply_of(502, [])) == Wait(30000)
				and next(3, reply_of(502, [])) == Stop
					and next(0, reply_of(429, [])) == Wait(2000)
						and next(1, reply_of(503, [])) == Wait(8000)
							and next(0, Err(Timeout)) == Wait(2000)
								and next(2, Err(Failed("refused"))) == Wait(30000)
									and next(3, Err(Timeout)) == Stop
										and next(0, reply_of(429, [("Retry-After", "7")])) == Wait(7000)
											and next(1, reply_of(503, [("retry-after", " 60 ")])) == Wait(60000)
												and next(2, reply_of(429, [("RETRY-AFTER", "120")])) == Wait(60000)
													and next(0, reply_of(429, [("Retry-After", "soon")])) == Wait(2000)
														and next(1, reply_of(429, [("Retry-After", "Wed, 21 Oct 2026 07:28:00 GMT")])) == Wait(8000)
															and next(0, reply_of(429, [("Retry-After", "0")])) == Wait(0)
																and next(3, reply_of(429, [("Retry-After", "7")])) == Stop
}

# R-AP34, R-E6: 200 and 201 are done. A 401 after a first token gets a new token (`Renew`, no wait, once). A second 401 stops. Another 4xx, 3xx and 202 stop, with no wait.
expect {
	next = |retries, renewed, reply| Publish.next({ retries, renewed, reply })
	next(0, Bool.False, reply_of(201, [])) == Done
		and next(2, Bool.True, reply_of(200, [])) == Done
			and next(0, Bool.False, reply_of(401, [])) == Renew
				and next(2, Bool.False, reply_of(401, [])) == Renew
					and next(0, Bool.True, reply_of(401, [])) == Stop
						and next(0, Bool.True, reply_of(502, [])) == Wait(2000)
							and [400, 403, 404, 409, 413, 422, 302, 202, 204].all(|status| next(0, Bool.False, reply_of(status, [])) == Stop)
}

problem = |status, type, detail| js("{'type':'/errors/${type}','title':'T','status':${status.to_str()},'detail':'${detail}'}")

fail_of = |status, type, detail, tries| Publish.failure({ origin: "https://registry.example.org", version: "0.0.1", tries, renewed: Bool.False, reply: Ok({ status, headers: [], body: problem(status, type, detail) }) })

# R-E6, CLI 3 (the 3 texts of the example): a refused write is exit 20 (`rejected`); the text of `label-conflict` and of `forbidden` ends with the advice of the example. After 4 requests a 502 is exit 15 with `4 times`.
expect {
	conflict = fail_of(409, "label-conflict", "the registry has roc-lang/json 2.1.0 with another hash", 1)
	forbidden = fail_of(403, "forbidden", "token claim ref is refs/heads/main, the asset URL has the tag 2.1.0", 1)
	busy = fail_of(502, "upstream", "x", 4)
	conflict.message == "the registry has roc-lang/json 2.1.0 with another hash (/errors/label-conflict). The tag was released again. Release a new version."
		and conflict.kind.name() == "rejected"
			and conflict.kind.code() == 20
				and forbidden.message == "token claim ref is refs/heads/main, the asset URL has the tag 2.1.0 (/errors/forbidden). Run tln publish in a job for the tag."
					and forbidden.kind.code() == 20
						and busy.message == "the registry answered 502 (/errors/upstream) 4 times. Try again later."
							and busy.kind.code() == 15
								and fail_of(502, "upstream", "x", 1).message == "the registry answered 502 (/errors/upstream). Try again later."
}

# R-E6, R-J7: the other answers keep the mapping of `Registry.refuse`: 401 and 422 are 20, 400 is 1, a 429 is 15. `details` has `status` and `type` (R-J7). A body that is not problem details is 15.
expect {
	code = |status, type| fail_of(status, type, "d", 1).kind.code()
	code(401, "unauthenticated") == 20
		and code(422, "not-a-candidate") == 20
			and code(403, "repository-changed") == 20
				and code(400, "bad-request") == 1
					and code(429, "rate-limited") == 15
						and fail_of(422, "not-a-candidate", "d", 1).details == Ok(JsonDoc.Obj([("status", Num(422)), ("type", Text("/errors/not-a-candidate"))]))
							and Publish.failure({ origin, version: "0.0.1", tries: 1, renewed: Bool.False, reply: Ok({ status: 404, headers: [], body: "<html>" }) }).kind.code() == 15
}

# R-AP34, R-E6: no answer after 4 requests is exit 15, with the number of requests in the text (a proposal). With one request: the text of `Registry.no_answer`.
expect {
	four = Publish.failure({ origin, version: "0.0.1", tries: 4, renewed: Bool.False, reply: Err(Timeout) })
	one = Publish.failure({ origin, version: "0.0.1", tries: 1, renewed: Bool.False, reply: Err(Failed("connection refused")) })
	four.message == "the registry ${origin} gave no answer 4 times: no answer in 20 s. The publish may be done. Run the command again."
		and four.kind.code() == 15
			and one.message == "the registry ${origin} gave no answer: connection refused. Try again later."
}

release_body = |hash| js("{'log_index':41,'hash':'${hash}','group':'github.com/acme/json/releases/download/{v}','series':'2','version':'2.1.0','url':'${asset_url}','tag':'2.1.0','roc_version':null,'repo':'acme/json','published_at':1792065600000,'yanked':false,'yank_reason':null,'withdrawn':null,'provenance':['oidc']}")

# R-AP8, R-AP51, R-E6: 201 is a new release, 200 is the same label with the same hash. A 2xx body that is no release is exit 15.
expect {
	body = release_body(h1)
	Publish.answer({ origin, status: 201, body }) == Ok({ created: Bool.True, hash: h1, version: "2.1.0" })
		and Publish.answer({ origin, status: 200, body }) == Ok({ created: Bool.False, hash: h1, version: "2.1.0" })
			and kind_of(Publish.answer({ origin, status: 201, body: "{}" })) == "network"
				and kind_of(Publish.answer({ origin, status: 200, body: "nope" })) == "network"
}

# R-OUT2, R-OUT4 (proposal): the lines and the `data` of a publish. `fact` for 1, `no facts sent` for 0, another text for a release that is there already.
expect {
	run = { owner: "acme", repo: "json", tag: "2.1.0", hash: h1, created: Bool.True, facts: 2 }
	Publish.lines(run) == ["published acme/json 2.1.0: ${h1}, 2 facts sent\n"]
		and Publish.lines({ ..run, facts: 1 }) == ["published acme/json 2.1.0: ${h1}, 1 fact sent\n"]
			and Publish.lines({ ..run, facts: 0 }) == ["published acme/json 2.1.0: ${h1}, no facts sent\n"]
				and Publish.lines({ ..run, created: Bool.False }) == ["acme/json 2.1.0 is published already: ${h1}, 2 facts sent\n"]
					and Publish.data(run).render() == js("{'publish':{'repository':'acme/json','tag':'2.1.0','hash':'${h1}','created':true,'facts':2}}")
						and Publish.data({ ..run, created: Bool.False, facts: 0 }).render() == js("{'publish':{'repository':'acme/json','tag':'2.1.0','hash':'${h1}','created':false,'facts':0}}")
}

# Q32, R-EC2: the `direct` registry is exit 2 (`Usage`).
expect {
	got = Publish.direct({})
	got.kind.name() == "usage"
		and got.message == "tln publish needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
}

# Q510, R-PUB4 item 4: with more than 500 facts the 500 of the newest nightlies go (the oldest is dropped), sorted oldest first, with one warning that names the numbers and the hash. 500 facts: no warning.
expect {
	tags = nights(501)
	all = tags.map(|n| fact(h1, n, "any", Pass, ""))
	got = Publish.facts({ hash: h1, stored: tags.map_with_index(|_, i| fact(h1, tags.get(500 - i) ?? "", "any", Pass, "")) })
	exact = Publish.facts({ hash: h1, stored: all.take_first(500) })
	got.list.len() == 500
		and got.list.first() == Ok(wire(tags.get(1) ?? "", "pass"))
			and got.list.last() == Ok(wire(tags.get(500) ?? "", "pass"))
				and got.warning == Ok("sent 500 of 501 facts for ${h1}: the registry takes at most 500 for a publish")
					and exact.list.len() == 500
						and exact.warning == Err(None)
}

# Q517, R-PUB4 item 10: the warning for a `compat.db` that cannot be read.
expect {
	Publish.unread("busy") == "compat.db could not be read (busy): publishing with no probe facts"
		and Publish.unread("disk full") == "compat.db could not be read (disk full): publishing with no probe facts"
}

# Q508, R-PUB4 items 1, 2: `--offline` is exit 15 (network), an operand is exit 2 (usage).
expect {
	off = Publish.offline({})
	off.kind.code() == 15
		and off.message == "tln publish needs the network: --offline sends no request"
			and Publish.operand([]) == Ok({})
				and msg_of(Publish.operand(["x", "y"])) == "tln publish takes no argument: 'x'"
					and kind_of(Publish.operand(["x"])) == "usage"
}

# Q516, R-E6 (proposals): after the retries a 429 and a busy 503 are exit 15 with the text of `Registry.refuse` and `after 4 requests`; a 401 after the new token is exit 20 with the detail and `the registry refused the new token too`. With one request the texts are those of `Registry.refuse`.
expect {
	of = |status, type, headers, tries, renewed| Publish.failure({ origin: "https://registry.example.org", version: "0.0.1", tries, renewed, reply: Ok({ status, headers, body: problem(status, type, "D") }) })
	limited = of(429, "rate-limited", [("Retry-After", "7")], 4, Bool.False)
	busy = of(503, "busy", [("Retry-After", "7")], 4, Bool.False)
	busy_none = of(503, "busy", [], 4, Bool.False)
	refused = of(401, "unauthenticated", [], 2, Bool.True)
	limited.message == "the registry answered 429 (/errors/rate-limited) after 4 requests. Try again in 7 s."
		and limited.kind.code() == 15
			and busy.message == "the registry is busy (503) after 4 requests. Try again in 7 s."
				and busy_none.message == "the registry is busy (503) after 4 requests. Try again later."
					and busy.kind.code() == 15
						and refused.message == "D (/errors/unauthenticated): the registry refused the new token too."
							and refused.kind.code() == 20
								and of(401, "unauthenticated", [], 1, Bool.False).message == "D (/errors/unauthenticated). Fix the release or the workflow, then run the command again."
									and of(429, "rate-limited", [("Retry-After", "7")], 1, Bool.False).message == "the registry answered 429 (/errors/rate-limited). Try again in 7 s."
}
