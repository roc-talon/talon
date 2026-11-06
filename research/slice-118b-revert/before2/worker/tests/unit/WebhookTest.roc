import lib.Problem
import lib.Route
import lib.Webhook

WebhookTest :: [].{}

# W0 tests of worker/lib/Webhook.roc and of the webhook row of Route.decide (slice 118, docs/slices/118-webhook.md section 4).
# The HMAC itself is not here: it is the platform `WebCrypto.hmac_sha256`, and the W2 cases (worker/tests/cases/webhook/) check it with signatures that node made (crypto.createHmac).
# The payloads are the shape that GitHub sends: many members that the Worker does not read, nested objects and `null` values (`"body":null`).

# ---- payloads ----

junk = "\"sender\":{\"login\":\"someone\",\"id\":5,\"site_admin\":false},\"organization\":{\"id\":3,\"login\":\"acme\"}"

release_json = |action, installation| {
	inst = if (installation) ",\"installation\":{\"id\":55,\"node_id\":\"MDIzOkludGVncmF0aW9u\"}" else ""
	"{\"action\":\"${action}\",\"release\":{\"id\":9001,\"tag_name\":\"1.2.0\",\"name\":null,\"body\":null,\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-20T12:00:00Z\",\"author\":{\"login\":\"a\",\"id\":5},\"assets\":[{\"id\":1,\"name\":\"x.tar.zst\",\"label\":null,\"size\":10}]},\"repository\":{\"id\":100,\"full_name\":\"acme/lib\",\"private\":false,\"description\":null,\"owner\":{\"id\":10,\"login\":\"acme\"}}${inst},${junk}}"
}

repository_json = |action| "{\"action\":\"${action}\",\"repository\":{\"id\":100,\"full_name\":\"acme/lib\",\"private\":true,\"description\":null},\"installation\":{\"id\":55},${junk}}"

event = |name, body| Webhook.parse_event({ event: name, body: body.to_utf8() })

message = |event_name, action, installation_id, repository_id, release_id, repository_ids| { event: event_name, action, installation_id, repository_id, release_id, repository_ids }

# Is the answer a 400 problem?
is_400 = |result| match result {
	Err(p) => p.http_status() == 400
	Ok(_) => Bool.False
}

# ---- R-AP12: the header X-Hub-Signature-256 ----

hex64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

bytes32 = [
	0x01,
	0x23,
	0x45,
	0x67,
	0x89,
	0xab,
	0xcd,
	0xef,
	0x01,
	0x23,
	0x45,
	0x67,
	0x89,
	0xab,
	0xcd,
	0xef,
	0x01,
	0x23,
	0x45,
	0x67,
	0x89,
	0xab,
	0xcd,
	0xef,
	0x01,
	0x23,
	0x45,
	0x67,
	0x89,
	0xab,
	0xcd,
	0xef,
]

# R-AP12: `sha256=` and 64 hex digits is the 32 bytes of the signature. Any other form is `Malformed`: another prefix (sha1 is the old header form), no prefix, a short or a long text,
# a character that is not a hex digit, white space around, an empty text. The 401 of the route (`Webhook.bad_signature`) is for all of them.
expect {
	short = hex64.drop_suffix("f")
	Webhook.parse_signature("sha256=${hex64}") == Ok(bytes32)
		and Webhook.parse_signature("sha256=${hex64}0") == Err(Malformed)
		and Webhook.parse_signature("sha256=${short}") == Err(Malformed)
		and Webhook.parse_signature("sha256=${short}g") == Err(Malformed)
		and Webhook.parse_signature("sha256=${short}-") == Err(Malformed)
		and Webhook.parse_signature(" sha256=${hex64}") == Err(Malformed)
		and Webhook.parse_signature("sha256=${hex64} ") == Err(Malformed)
		and Webhook.parse_signature("sha1=0123456789abcdef0123456789abcdef01234567") == Err(Malformed)
		and Webhook.parse_signature("sha1=${hex64}") == Err(Malformed)
		and Webhook.parse_signature(hex64) == Err(Malformed)
		and Webhook.parse_signature("sha256=") == Err(Malformed)
		and Webhook.parse_signature("") == Err(Malformed)
}

# R-AP12, R-AP21: one problem for all the causes: 401 `unauthenticated`.
expect Webhook.bad_signature.http_status() == 401

# ---- R-AP12, R-AP48: the route ----

route = |method, content_type, has_body| Route.decide({ method, segments: ["v1", "webhooks", "github"], content_type, has_body })

# R-AP12, R-AP79 rows 1 and 3: POST is the route. A body needs the media type `application/json` (R-AP23, R-AP48 row 5): GitHub can send `application/x-www-form-urlencoded` (a setting of a webhook), and that gives 415.
# Another method is 405 with `Allow: POST` (row 2). A path below the route is no route (row 1).
expect {
	Route.decide({ method: "POST", segments: ["v1", "webhooks", "github"], content_type: Ok("application/json"), has_body: Bool.True }) == Handle(PostWebhook)
		and Route.decide({ method: "POST", segments: ["v1", "webhooks", "github"], content_type: Ok("application/json; charset=utf-8"), has_body: Bool.True }) == Handle(PostWebhook)
		and route("POST", Ok("application/x-www-form-urlencoded"), Bool.True)
			== Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got application/x-www-form-urlencoded"))
		and route("GET", Err(NotFound), Bool.False)
			== NotAllowed(Problem.new(MethodNotAllowed, "GET is not allowed on /v1/webhooks/github"), ["POST"])
		and route("PUT", Ok("text/plain"), Bool.True)
			== NotAllowed(Problem.new(MethodNotAllowed, "PUT is not allowed on /v1/webhooks/github"), ["POST"])
		and Route.decide({ method: "POST", segments: ["v1", "webhooks"], content_type: Ok("application/json"), has_body: Bool.True })
			== Refuse(Problem.new(NotFound, "no route for POST /v1/webhooks"))
}

# ---- R-PU11: the events and the actions that the Worker uses ----

# R-PU11, R-PU13, R-PU17: the 6 actions of `release` give a message with the ids of the repository and the release and the installation, and no name. The members that the Worker does not read
# (`null` values, nested objects, the assets) are ignored (R-AP44). The ids are the GitHub ids (100 the repository, 9001 the release, 55 the installation).
expect {
	actions = ["published", "released", "edited", "prereleased", "unpublished", "deleted"]
	got = actions.map(|a| event("release", release_json(a, Bool.True)))
	want = actions.map(|a| Ok(Send(message("release", a, 55, 100, 9001, []))))
	got == want
}

# R-PU11: `release` `created` (a draft) is ignored, also an action that the Worker does not know. A missing `installation` is the installation id 0, not an error.
expect {
	event("release", release_json("created", Bool.True)) == Ok(Ignore)
		and event("release", release_json("something-new", Bool.True)) == Ok(Ignore)
		and event("release", release_json("published", Bool.False)) == Ok(Send(message("release", "published", 0, 100, 9001, [])))
}

# R-PU33, R-PU11: `repository` `privatized` and `publicized` give a message with the repository id only (no release id). Every other action of `repository` (`archived`, `deleted`, `renamed`)
# is ignored: the reconcile finds them (R-PU24).
expect {
	event("repository", repository_json("privatized")) == Ok(Send(message("repository", "privatized", 55, 100, 0, [])))
		and event("repository", repository_json("publicized")) == Ok(Send(message("repository", "publicized", 55, 100, 0, [])))
		and event("repository", repository_json("archived")) == Ok(Ignore)
		and event("repository", repository_json("deleted")) == Ok(Ignore)
		and event("repository", repository_json("renamed")) == Ok(Ignore)
}

# R-PU26, R-PU11, Design Q322: `installation` `created`, `deleted`, `suspend` and `unsuspend` give a message with the ids of the repositories of the list `repositories` (the ids, not the names, R-PU32). A missing list is `[]`.
# `installation_repositories` `added` reads `repositories_added`, `removed` reads `repositories_removed`. The other list of the same payload is not read.
expect {
	repos = "[{\"id\":100,\"name\":\"lib\",\"full_name\":\"acme/lib\",\"private\":false},{\"id\":101,\"name\":\"secret\",\"full_name\":\"acme/secret\",\"private\":true}]"
	created = "{\"action\":\"created\",\"installation\":{\"id\":55,\"account\":{\"id\":3}},\"repositories\":${repos},${junk}}"
	deleted = "{\"action\":\"deleted\",\"installation\":{\"id\":55},\"repositories\":${repos}}"
	empty = "{\"action\":\"created\",\"installation\":{\"id\":55}}"
	suspended = "{\"action\":\"suspend\",\"installation\":{\"id\":55},\"repositories\":${repos}}"
	unsuspended = "{\"action\":\"unsuspend\",\"installation\":{\"id\":55},\"repositories\":${repos}}"
	perms = "{\"action\":\"new_permissions_accepted\",\"installation\":{\"id\":55},\"repositories\":${repos}}"
	added = "{\"action\":\"added\",\"installation\":{\"id\":55},\"repository_selection\":\"selected\",\"repositories_added\":[{\"id\":200,\"name\":\"a\"}],\"repositories_removed\":[{\"id\":300,\"name\":\"c\"}]}"
	removed = "{\"action\":\"removed\",\"installation\":{\"id\":55},\"repositories_added\":[{\"id\":200,\"name\":\"a\"}],\"repositories_removed\":[{\"id\":300,\"name\":\"c\"},{\"id\":301,\"name\":\"d\"}]}"
	event("installation", created) == Ok(Send(message("installation", "created", 55, 0, 0, [100, 101])))
		and event("installation", deleted) == Ok(Send(message("installation", "deleted", 55, 0, 0, [100, 101])))
		and event("installation", empty) == Ok(Send(message("installation", "created", 55, 0, 0, [])))
		and event("installation", suspended) == Ok(Send(message("installation", "suspend", 55, 0, 0, [100, 101])))
		and event("installation", unsuspended) == Ok(Send(message("installation", "unsuspend", 55, 0, 0, [100, 101])))
		and event("installation", perms) == Ok(Ignore)
		and event("installation_repositories", added) == Ok(Send(message("installation_repositories", "added", 55, 0, 0, [200])))
		and event("installation_repositories", removed) == Ok(Send(message("installation_repositories", "removed", 55, 0, 0, [300, 301])))
}

# R-PU11: an event that the App does not use is ignored (`ping` is the first event of a new webhook, GitHub shows a failed delivery for a non 2xx answer). The body is not read.
expect {
	event("ping", "{\"zen\":\"Keep it logically awesome.\",\"hook_id\":1}") == Ok(Ignore)
		and event("star", release_json("published", Bool.True)) == Ok(Ignore)
		and event("release_extra", release_json("published", Bool.True)) == Ok(Ignore)
		and event("ping", "not json") == Ok(Ignore)
}

# R-AP79 row 6, Design Q321: an empty event (the route passes "" for a missing header or an empty one) is 400 whatever the body, a valid release body or a body that is not JSON: the event check comes first.
# R-AP79 row 7: an event that is not used is ignored with its body unread, so `ping` with a body that is not JSON stays `Ignore` (the row above).
expect {
	is_400(event("", release_json("published", Bool.True)))
		and is_400(event("", "not json"))
		and is_400(event("", ""))
}

# R-AP79 row 8, R-AP21: a body that is not a JSON object with a text `action`, or an event of the Worker with no valid id, is 400. Rows: an empty body, not JSON, an array, `{}`, `action` a number,
# `action` null, no `repository`, `repository.id` a text, `repository.id` 0, `release.id` missing, `release.id` negative, `release.id` a text; `repository` with no repository id; an item with no id in a list.
expect {
	ok_release = release_json("published", Bool.True)
	no_repo = "{\"action\":\"published\",\"release\":{\"id\":9001},\"installation\":{\"id\":55}}"
	text_repo = "{\"action\":\"published\",\"release\":{\"id\":9001},\"repository\":{\"id\":\"100\"}}"
	zero_repo = "{\"action\":\"published\",\"release\":{\"id\":9001},\"repository\":{\"id\":0}}"
	no_release_id = "{\"action\":\"published\",\"release\":{\"tag_name\":\"1\"},\"repository\":{\"id\":100}}"
	neg_release_id = "{\"action\":\"published\",\"release\":{\"id\":-5},\"repository\":{\"id\":100}}"
	text_release_id = "{\"action\":\"published\",\"release\":{\"id\":\"9001\"},\"repository\":{\"id\":100}}"
	no_release = "{\"action\":\"published\",\"repository\":{\"id\":100}}"
	no_item_id = "{\"action\":\"created\",\"installation\":{\"id\":55},\"repositories\":[{\"id\":100},{\"name\":\"x\"}]}"
	is_400(event("release", ""))
		and is_400(event("release", "not json"))
		and is_400(event("release", "[]"))
		and is_400(event("release", "{}"))
		and is_400(event("release", "{\"action\":5}"))
		and is_400(event("release", "{\"action\":null}"))
		and is_400(event("release", no_repo))
		and is_400(event("release", text_repo))
		and is_400(event("release", zero_repo))
		and is_400(event("release", no_release_id))
		and is_400(event("release", neg_release_id))
		and is_400(event("release", text_release_id))
		and is_400(event("release", no_release))
		and is_400(event("repository", "{\"action\":\"privatized\",\"installation\":{\"id\":55}}"))
		and is_400(event("installation", no_item_id))
		and !is_400(event("release", ok_release))
}

# ---- R-PU11, R-PU33, R-PU26: the job of a message ----

# The pairs of `parse_event` give a job. `installed` is True for `created`, `unsuspend` and `added`, False for `deleted`, `suspend` and `removed` (Design Q322). A message of another event or action (a message that this Worker did not write)
# is `Unknown`.
expect {
	job = |event_name, action, repository_id, release_id, ids| Webhook.job_of(message(event_name, action, 55, repository_id, release_id, ids))
	job("release", "published", 100, 9001, []) == Ok(Release({ action: "published", repository_id: 100, release_id: 9001, installation_id: 55 }))
		and job("release", "deleted", 100, 9001, []) == Ok(Release({ action: "deleted", repository_id: 100, release_id: 9001, installation_id: 55 }))
		and job("repository", "privatized", 100, 0, []) == Ok(Privatized(100))
		and job("repository", "publicized", 100, 0, []) == Ok(Publicized(100))
		and job("installation", "created", 0, 0, [100, 101]) == Ok(AppInstalled({ repository_ids: [100, 101], installed: Bool.True }))
		and job("installation", "deleted", 0, 0, [100]) == Ok(AppInstalled({ repository_ids: [100], installed: Bool.False }))
		and job("installation_repositories", "added", 0, 0, [200]) == Ok(AppInstalled({ repository_ids: [200], installed: Bool.True }))
		and job("installation_repositories", "removed", 0, 0, [300]) == Ok(AppInstalled({ repository_ids: [300], installed: Bool.False }))
		and job("installation", "suspend", 0, 0, [100]) == Ok(AppInstalled({ repository_ids: [100], installed: Bool.False }))
		and job("installation", "unsuspend", 0, 0, [100]) == Ok(AppInstalled({ repository_ids: [100], installed: Bool.True }))
		and job("installation", "new_permissions_accepted", 0, 0, [100]) == Err(Unknown)
		and job("release", "created", 100, 9001, []) == Err(Unknown)
		and job("repository", "archived", 100, 0, []) == Err(Unknown)
		and job("ping", "", 0, 0, []) == Err(Unknown)
		and job("installation", "added", 0, 0, [1]) == Err(Unknown)
		and job("installation_repositories", "created", 0, 0, [1]) == Err(Unknown)
}

# ---- R-PU13, R-PU35: the retry schedule ----

# R-PU13, R-PU35: the retries come after 1, 5, 15 and 60 min (first guess), each from the failed attempt, as the delay of the platform retry. The first delivery is attempt 1. Attempt 5 is the last:
# `GiveUp` (the consumer retries with no delay, and the platform moves the message to the dead letter queue because `max_retries` is 4). The constants agree: `max_attempts` is 5.
expect {
	Webhook.retry_delay_ms(1) == Ok(60_000)
		and Webhook.retry_delay_ms(2) == Ok(300_000)
		and Webhook.retry_delay_ms(3) == Ok(900_000)
		and Webhook.retry_delay_ms(4) == Ok(3_600_000)
		and Webhook.retry_delay_ms(5) == Err(GiveUp)
		and Webhook.retry_delay_ms(6) == Err(GiveUp)
		and Webhook.retry_delay_ms(100) == Err(GiveUp)
		and Webhook.max_attempts == 5
		and Webhook.queue_name == "talon-index"
		and Webhook.dlq_name == "talon-index-dlq"
}

# ---- R-PU31, R-PU33, R-PU24: the read of the repository for a `privatized` job ----

# R-PU31, R-PU12: the event can be old (a redelivery), so the Worker reads the repository. 404 is gone (R-PU24, R-TP11): `Withdraw`. `public` is a stale event: `Stale`. `private` and `internal` (GitHub
# Enterprise, R-PU32) are `Withdraw`. A body that is not a repository (no `id`, no `owner.id`, no `visibility`, not JSON) and any other status (5xx, 403, 304, 301) is `Upstream`: the job fails and is tried again.
expect {
	repo = |visibility| "{\"id\":100,\"name\":\"lib\",\"full_name\":\"acme/lib\",\"private\":false,\"owner\":{\"login\":\"acme\",\"id\":10},\"description\":null,\"visibility\":\"${visibility}\"}"
	out = |status, body| match Webhook.repository_outcome({ status, body }) {
		Ok(Withdraw) => "withdraw"
		Ok(Stale) => "stale"
		Err(Upstream(_)) => "upstream"
	}
	out(404, "{\"message\":\"Not Found\"}") == "withdraw"
		and out(404, "") == "withdraw"
		and out(200, repo("public")) == "stale"
		and out(200, repo("private")) == "withdraw"
		and out(200, repo("internal")) == "withdraw"
		and out(200, "{\"id\":100}") == "upstream"
		and out(200, "not json") == "upstream"
		and out(200, "") == "upstream"
		and out(500, "") == "upstream"
		and out(502, repo("private")) == "upstream"
		and out(403, repo("private")) == "upstream"
		and out(304, "") == "upstream"
		and out(301, "") == "upstream"
}

# ---- Slice 118b: the job Release (R-PU12, R-PU13, R-PU17, R-PU20; Design Q328, Q332, Q334) ----

# Three hashes (base58 of 32 bytes) for the names of the assets.
h1 = "7o7Rdz2Y1iJ86hB9Jg3p68pPccx7wVmMJ6f2p69bvYvF"

h2 = "CLoqacYwy459wZNHBVaKGZ7ivzZfnTr8e6BYmCfBvJu8"

h3 = "58kWEwvZAekXEePbtrjLPob7CPmx2JQJzhLqdjn6pQ5g"

# The answer of GitHub for `GET /repos/{full_name}/releases/{release_id}`: many members that the Worker does not read, nested objects and `null` values.
release_answer = |tag, draft, prerelease, published, assets| {
	names = Str.join_with(assets.map(|a| "{\"url\":\"https://api.github.com/repos/acme/lib/releases/assets/1\",\"id\":1,\"name\":\"${a}\",\"label\":null,\"uploader\":{\"login\":\"someone\",\"id\":5},\"content_type\":\"application/octet-stream\",\"state\":\"uploaded\",\"size\":10,\"digest\":null}"), ",")
	"{\"url\":\"https://api.github.com/repos/acme/lib/releases/9001\",\"id\":9001,\"tag_name\":\"${tag}\",\"target_commitish\":\"main\",\"name\":null,\"draft\":${draft},\"prerelease\":${prerelease},\"created_at\":\"2026-10-20T11:00:00Z\",\"published_at\":${published},\"author\":{\"login\":\"someone\",\"id\":5},\"assets\":[${names}],\"body\":null}"
}

# R-PU12: the answer of the release read. `tag_name` and the members that `Ingest.parse_release` reads. `published_at` null (a draft) is `Err(None)` there. A text that is not JSON, a missing or empty `tag_name`, a missing `assets`
# and a `published_at` that is not a time are `BadRelease` (the job fails and GitHub is read again).
expect {
	asset = "${h1}.tar.zst"
	good = Webhook.parse_release(release_answer("1.2.0", "false", "false", "\"2026-10-20T12:00:00Z\"", [asset, "notes.txt"]))
	draft = Webhook.parse_release(release_answer("1.2.0", "true", "false", "null", [asset]))
	pre = Webhook.parse_release(release_answer("v2.0.0-rc1", "false", "true", "\"2026-10-20T12:00:00Z\"", []))
	no_tag = "{\"id\":9001,\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-20T12:00:00Z\",\"assets\":[]}"
	empty_tag = "{\"id\":9001,\"tag_name\":\"\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-20T12:00:00Z\",\"assets\":[]}"
	no_assets = "{\"id\":9001,\"tag_name\":\"1.2.0\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-20T12:00:00Z\"}"
	bad_time = release_answer("1.2.0", "false", "false", "\"yesterday\"", [asset])
	good == Ok({ tag: "1.2.0", release: { draft: Bool.False, prerelease: Bool.False, published_at: Ok(1792497600000), assets: [asset, "notes.txt"] } })
		and draft == Ok({ tag: "1.2.0", release: { draft: Bool.True, prerelease: Bool.False, published_at: Err(None), assets: [asset] } })
		and pre == Ok({ tag: "v2.0.0-rc1", release: { draft: Bool.False, prerelease: Bool.True, published_at: Ok(1792497600000), assets: [] } })
		and Webhook.parse_release("not json") == Err(BadRelease)
		and Webhook.parse_release("") == Err(BadRelease)
		and Webhook.parse_release("[]") == Err(BadRelease)
		and Webhook.parse_release(no_tag) == Err(BadRelease)
		and Webhook.parse_release(empty_tag) == Err(BadRelease)
		and Webhook.parse_release(no_assets) == Err(BadRelease)
		and Webhook.parse_release(bad_time) == Err(BadRelease)
}

# R-PU13, R-PU17, Design Q332: what the job does with a release that is read. A final release with one package asset is `Index(url)` for `published`, `released` and `edited`, with the URL of the asset made from the `full_name` of the
# repository answer as GitHub gives it (not the lower case name, not the event). Assets that are not packages (`docs.tar.gz`, `x.tar.zst.intoto.jsonl`, a name that is not a base58 hash) are not counted. No package asset: `NoAsset`.
# 2 or more: `TooMany` (not a candidate, not read again). A release that is not final: `Withdraw(action)` for `unpublished`, `prereleased` and `edited` (the value of `edited` is `edited`).
expect {
	read = |tag, draft, prerelease, assets| { tag, release: { draft, prerelease, published_at: Ok(1792497600000), assets } }
	step = |action, full_name, r| Webhook.release_step({ action, full_name, read: r })
	url = |name, tag, hash| "https://github.com/${name}/releases/download/${tag}/${hash}.tar.zst"
	final = |assets| read("1.2.0", Bool.False, Bool.False, assets)
	step("published", "Acme/Lib", final(["${h1}.tar.zst"])) == Index(url("Acme/Lib", "1.2.0", h1))
		and step("released", "Acme/Lib", final(["${h1}.tar.zst"])) == Index(url("Acme/Lib", "1.2.0", h1))
		and step("edited", "acme/lib", final(["${h1}.tar.zst"])) == Index(url("acme/lib", "1.2.0", h1))
		and step("published", "acme/lib", read("v2.0.0", Bool.False, Bool.False, ["${h2}.tar.zst"])) == Index(url("acme/lib", "v2.0.0", h2))
		and step("published", "acme/lib", final(["docs.tar.gz", "${h3}.tar.zst", "${h3}.tar.zst.intoto.jsonl", "notes.txt"])) == Index(url("acme/lib", "1.2.0", h3))
		and step("published", "acme/lib", final([])) == NoAsset
		and step("published", "acme/lib", final(["docs.tar.gz", "${h1}.tar.zst.intoto.jsonl", "x.tar.zst"])) == NoAsset
		and step("released", "acme/lib", final(["${h1}.tar.zst", "${h2}.tar.zst"])) == TooMany
		and step("edited", "acme/lib", final(["${h1}.tar.zst", "${h2}.tar.zst", "${h3}.tar.zst"])) == TooMany
		and step("unpublished", "acme/lib", read("1.2.0", Bool.True, Bool.False, ["${h1}.tar.zst"])) == Withdraw("unpublished")
		and step("prereleased", "acme/lib", read("1.2.0", Bool.False, Bool.True, ["${h1}.tar.zst"])) == Withdraw("prereleased")
		and step("edited", "acme/lib", read("1.2.0", Bool.False, Bool.True, ["${h1}.tar.zst"])) == Withdraw("edited")
		and step("edited", "acme/lib", read("1.2.0", Bool.True, Bool.False, [])) == Withdraw("edited")
}

# R-PU17, R-PU20: the writes for the indexed rows of the release. `Withdrawn(value)` sets the value on the rows that have none. `Final(assets)`: the recorded asset of a row is `<hash>.tar.zst` (the whole name). A row whose asset is gone
# and that has no value gets `asset-replaced`. A row with a value whose asset is there is cleared (the release is a candidate again with the same hash, or the replaced asset is back). A row that needs no write is not in the list.
expect {
	row = |log_index, hash, withdrawn| { log_index, hash, withdrawn }
	none = Err(None)
	with_h1 = ["${h1}.tar.zst", "notes.txt"]
	Webhook.row_changes({ state: Withdrawn("unpublished"), rows: [row(1, h1, none), row(2, h2, none)] }) == [{ log_index: 1, to: Ok("unpublished") }, { log_index: 2, to: Ok("unpublished") }]
		and Webhook.row_changes({ state: Withdrawn("edited"), rows: [row(7, h3, none)] }) == [{ log_index: 7, to: Ok("edited") }]
		and Webhook.row_changes({ state: Withdrawn("prereleased"), rows: [] }) == []
		and Webhook.row_changes({ state: Final(with_h1), rows: [row(1, h1, Ok("unpublished"))] }) == [{ log_index: 1, to: Err(Clear) }]
		and Webhook.row_changes({ state: Final(with_h1), rows: [row(1, h1, Ok("edited"))] }) == [{ log_index: 1, to: Err(Clear) }]
		and Webhook.row_changes({ state: Final(with_h1), rows: [row(1, h1, Ok("asset-replaced"))] }) == [{ log_index: 1, to: Err(Clear) }]
		and Webhook.row_changes({ state: Final(with_h1), rows: [row(1, h1, none)] }) == []
		and Webhook.row_changes({ state: Final(with_h1), rows: [row(2, h2, none)] }) == [{ log_index: 2, to: Ok("asset-replaced") }]
		and Webhook.row_changes({ state: Final([]), rows: [row(2, h2, none)] }) == [{ log_index: 2, to: Ok("asset-replaced") }]
		and Webhook.row_changes({ state: Final(["${h1}.tar.zst.intoto.jsonl", "x${h1}.tar.zst"]), rows: [row(1, h1, none)] }) == [{ log_index: 1, to: Ok("asset-replaced") }]
		and Webhook.row_changes({ state: Final(["${h1}.tar.zst", "${h3}.tar.zst"]), rows: [row(1, h1, none), row(2, h2, none), row(3, h3, Ok("deleted")), row(4, h2, Ok("asset-replaced"))] }) == [{ log_index: 2, to: Ok("asset-replaced") }, { log_index: 3, to: Err(Clear) }]
}

# R-PU13, Design Q323, Q334: a release with no package asset is read again at the attempts 1 to 4 (the delays of `retry_delay_ms`); at attempt 5 the job ends without a fault: an ack and an info line, no dead letter.
expect {
	Webhook.after_no_asset(1) == Retry(60_000)
		and Webhook.after_no_asset(2) == Retry(300_000)
		and Webhook.after_no_asset(3) == Retry(900_000)
		and Webhook.after_no_asset(4) == Retry(3_600_000)
		and Webhook.after_no_asset(5) == Done
		and Webhook.after_no_asset(6) == Done
}
