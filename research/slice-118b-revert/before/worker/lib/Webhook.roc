## The pure part of the GitHub webhook and the index queue (Registry 4: R-AP12, R-AP79; 7: R-PU3, R-PU11, R-PU12, R-PU13, R-PU24, R-PU26, R-PU31, R-PU32, R-PU33, R-PU35, R-PU45; slice 118).
## No effect, no platform import. The effects (the body read, the secret, the compare, the queue send and consume, GitHub, D1, the clock) are in `worker/WebhookRoutes.roc` and `worker/IndexQueue.roc`.
## The tests are in `worker/tests/unit/WebhookTest.roc` (W0) and `worker/tests/cases/webhook/` (W2). The slice file is `docs/slices/118-webhook.md`.
## The names of the queues, the texts of the `detail` and the form of the message are proposals for the human review (TW24): slice file section 5.
## The doc comment of each function is the rule. Every function that is not given is `crash "todo"` until the code agent writes it (TW18).
import Ingest
import Problem

Webhook :: [].{

	## The queue of the index jobs (R-WH14 `INDEX`) and its dead letter queue (`INDEX_DLQ`): the names in `wrangler.toml` (R-PU45, Design Q331). The binding `INDEX` is in `main.roc`; the code has no producer for `INDEX_DLQ` (Design Q329).
	queue_name : Str
	queue_name = "talon-index"

	dlq_name : Str
	dlq_name = "talon-index-dlq"

	## The most attempts of a job: the first delivery and 4 retries. `wrangler.toml` has `max_retries = 4` for the consumer of `queue_name` (R-PU45, R-PU35, R-PU13).
	max_attempts : U32
	max_attempts = 5

	## R-PU11: the message of one event that the Worker uses. It holds the event, the action and the GitHub ids, never a name (R-PU32). A number that does not apply to the event is 0, a list that does not apply is `[]`.
	## It crosses as a CBOR map (`Queue.json`): a JS peer and the test see the JSON object with the 6 members. `repository_ids` is for the events `installation` and `installation_repositories`.
	Message : { event : Str, action : Str, installation_id : U64, repository_id : U64, release_id : U64, repository_ids : List(U64) }

	## What the Worker does with an event: send the message, or ignore it (answer 202 and send nothing).
	Decision : [Send(Webhook.Message), Ignore]

	## R-AP12: the problem 401 of a signature that is missing or not good. One text for all the causes (the answer shows no more than the registry publishes). Given.
	bad_signature : Problem
	bad_signature = Problem.new(Unauthenticated, "the signature of the webhook is missing or not valid")

	## R-AP12: the header `X-Hub-Signature-256`. The text must be `sha256=` and exactly 64 hex digits (`0-9`, `a-f`; `A-F` is accepted, no test). The result is the 32 bytes.
	## Any other text is `Err(Malformed)`: no prefix, another prefix (`sha1=`), 63 or 65 digits, a character that is not a hex digit, white space around, an empty text.
	parse_signature : Str -> Try(List(U8), [Malformed])
	parse_signature = |header| {
		if !header.starts_with("sha256=") {
			return Err(Malformed)
		}
		digits = header.drop_prefix("sha256=").to_utf8()
		if digits.len() != 64 {
			return Err(Malformed)
		}
		digits.chunks_of(2).map_try(
			|pair| match pair {
				[hi, lo] => Ok(hex_value(hi)? * 16 + hex_value(lo)?)
				_ => Err(Malformed)
			},
		)
	}

	hex_value : U8 -> Try(U8, [Malformed])
	hex_value = |c|
		if c >= '0' and c <= '9' {
			Ok(c - '0')
		} else if c >= 'a' and c <= 'f' {
			Ok(c - 'a' + 10)
		} else if c >= 'A' and c <= 'F' {
			Ok(c - 'A' + 10)
		} else {
			Err(Malformed)
		}

	## R-PU11, R-PU3, R-AP79 rows 6 to 9: the event and the body of a webhook, after the signature (R-AP79 row 5, Design Q320). `event` is the header `X-GitHub-Event`.
	## 0. An empty `event` (the route passes "" for a missing header): `Err` 400 `BadRequest`, whatever the body (R-AP79 row 6, Design Q321). The proposal of the `detail`: `the webhook has no X-GitHub-Event header`.
	## 1. An event other than `release`, `repository`, `installation`, `installation_repositories` (`ping`, `star`, ...): `Ok(Ignore)`. The body is not read.
	## 2. The body is not a JSON object, or its member `action` is missing or not text: `Err` 400 `BadRequest`. Other members are ignored (R-AP44), also nested ones.
	## 3. The actions that the Worker uses (R-PU11): `release`: `published`, `released`, `edited`, `prereleased`, `unpublished`, `deleted`. `repository`: `privatized`, `publicized`.
	##    `installation`: `created`, `deleted`, `suspend`, `unsuspend` (Design Q322). `installation_repositories`: `added`, `removed`. Any other action (`release` `created`, a draft, R-PU11; `repository` `archived`; `installation` `new_permissions_accepted`) is `Ok(Ignore)` (R-AP79 row 9).
	## 4. The ids. `release`: `repository.id` and `release.id` are JSON integers of 1 or more, else 400 `BadRequest`. `repository`: `repository.id`. `installation_id` is `installation.id` when it is an integer of 1 or more, else 0
	##    (a missing `installation` is not an error). `installation` (all 4 actions): `repository_ids` are the `id` of each item of `repositories` (a missing or empty list is `[]`). `installation_repositories`: the `id` of each item of
	##    `repositories_added` for `added`, of `repositories_removed` for `removed`. An item with no integer `id` is 400 `BadRequest`.
	## 5. `Ok(Send(message))`: `event` and `action` as sent, the ids as in rule 4, the numbers that do not apply 0, the lists that do not apply `[]`.
	## The texts of the `detail` of a 400 are proposals (slice file section 5).
	parse_event : { event : Str, body : List(U8) } -> Try(Webhook.Decision, Problem)
	parse_event = |input| {
		if input.event.is_empty() {
			return Err(bad_request("the webhook has no X-GitHub-Event header"))
		}
		if !used_event(input.event) {
			return Ok(Ignore)
		}
		text = Str.from_utf8(input.body).map_err(|_| bad_request("the webhook body is not UTF-8"))?
		head : Try({ action : Str }, _)
		head = Json.parse(text)
		action = match head {
			Ok(h) => h.action
			Err(_) => return Err(bad_request("the webhook body is not a JSON object with a text member action"))
		}
		if !used_action(input.event, action) {
			return Ok(Ignore)
		}
		match input.event {
			"release" => release_message(text, action)
			"repository" => repository_message(text, action)
			"installation" => installation_message(text, action)
			_ => installation_repositories_message(text, action)
		}
	}

	bad_request : Str -> Problem
	bad_request = |detail| Problem.new(BadRequest, detail)

	message_of : Str, Str, U64, U64, U64, List(U64) -> Webhook.Message
	message_of = |event, action, installation_id, repository_id, release_id, repository_ids| { event, action, installation_id, repository_id, release_id, repository_ids }

	used_event : Str -> Bool
	used_event = |event| ["release", "repository", "installation", "installation_repositories"].contains(event)

	## The pairs of event and action that the Worker uses (R-PU11, Design Q322).
	used_action : Str, Str -> Bool
	used_action = |event, action| match event {
		"release" => ["published", "released", "edited", "prereleased", "unpublished", "deleted"].contains(action)
		"repository" => ["privatized", "publicized"].contains(action)
		"installation" => ["created", "deleted", "suspend", "unsuspend"].contains(action)
		"installation_repositories" => ["added", "removed"].contains(action)
		_ => Bool.False
	}

	## `installation.id` when it is an integer of 1 or more, else 0. A missing installation is not an error.
	installation_id_of : Str -> U64
	installation_id_of = |text| {
		parsed : Try({ installation : Try({ id : U64 }, [Missing]) }, _)
		parsed = Json.parse(text)
		match parsed {
			Ok({ installation: Ok(i) }) => i.id
			_ => 0
		}
	}

	release_message : Str, Str -> Try(Webhook.Decision, Problem)
	release_message = |text, action| {
		parsed : Try({ release : { id : U64 }, repository : { id : U64 } }, _)
		parsed = Json.parse(text)
		match parsed {
			Ok(r) if r.repository.id >= 1 and r.release.id >= 1 => Ok(Send(message_of("release", action, installation_id_of(text), r.repository.id, r.release.id, [])))
			_ => Err(bad_request("the webhook body has no valid repository id and release id"))
		}
	}

	repository_message : Str, Str -> Try(Webhook.Decision, Problem)
	repository_message = |text, action| {
		parsed : Try({ repository : { id : U64 } }, _)
		parsed = Json.parse(text)
		match parsed {
			Ok(r) if r.repository.id >= 1 => Ok(Send(message_of("repository", action, installation_id_of(text), r.repository.id, 0, [])))
			_ => Err(bad_request("the webhook body has no valid repository id"))
		}
	}

	installation_message : Str, Str -> Try(Webhook.Decision, Problem)
	installation_message = |text, action| {
		parsed : Try({ repositories : Try(List({ id : U64 }), [Missing]) }, _)
		parsed = Json.parse(text)
		match parsed {
			Ok(r) => Ok(Send(message_of("installation", action, installation_id_of(text), 0, 0, ids_of(r.repositories))))
			Err(_) => Err(bad_request("the webhook body has a repository without an id"))
		}
	}

	installation_repositories_message : Str, Str -> Try(Webhook.Decision, Problem)
	installation_repositories_message = |text, action| {
		ids = if action == "added" {
			parsed : Try({ repositories_added : Try(List({ id : U64 }), [Missing]) }, _)
			parsed = Json.parse(text)
			parsed.map_ok(|r| ids_of(r.repositories_added))
		} else {
			parsed : Try({ repositories_removed : Try(List({ id : U64 }), [Missing]) }, _)
			parsed = Json.parse(text)
			parsed.map_ok(|r| ids_of(r.repositories_removed))
		}
		match ids {
			Ok(list) => Ok(Send(message_of("installation_repositories", action, installation_id_of(text), 0, 0, list)))
			Err(_) => Err(bad_request("the webhook body has a repository without an id"))
		}
	}

	ids_of : Try(List({ id : U64 }), [Missing]) -> List(U64)
	ids_of = |items| match items {
		Ok(list) => list.map(|i| i.id)
		Err(Missing) => []
	}

	## What the consumer does for a message (R-PU11 "The queue consumer does the work"). `Release` is the job of slice 118b. `Privatized` and `Publicized` are the actions of the event `repository` (R-PU33).
	## `AppInstalled` is the event `installation` or `installation_repositories` (R-PU26, Design Q322): `installed` is True for `created`, `unsuspend` and `added`, False for `deleted`, `suspend` and `removed`.
	Job : [Release({ action : Str, repository_id : U64, release_id : U64 }), Privatized(U64), Publicized(U64), AppInstalled({ repository_ids : List(U64), installed : Bool })]

	## The job of a message. The pairs of `parse_event` rule 3 give a job. Any other event or action (a message that this Worker did not write) is `Err(Unknown)`.
	job_of : Webhook.Message -> Try(Webhook.Job, [Unknown])
	job_of = |m| match (m.event, m.action) {
		("release", action) if used_action("release", action) => Ok(Release({ action, repository_id: m.repository_id, release_id: m.release_id }))
		("repository", "privatized") => Ok(Privatized(m.repository_id))
		("repository", "publicized") => Ok(Publicized(m.repository_id))
		("installation", action) if used_action("installation", action) => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: action == "created" or action == "unsuspend" }))
		("installation_repositories", action) if used_action("installation_repositories", action) => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: action == "added" }))
		_ => Err(Unknown)
	}

	## R-PU13, R-PU35: the delay of the retry after the attempt `attempts` (the first delivery is attempt 1) in ms: 60 000 after attempt 1, 300 000 after 2, 900 000 after 3, 3 600 000 after 4
	## (1, 5, 15 and 60 min, first guess). The delays are one after the other, each from the failed attempt. Attempt 5 and later: `Err(GiveUp)`: the consumer retries with no delay, and the platform
	## moves the message to `dlq_name` because `max_retries` is used up (R-PU35).
	retry_delay_ms : U32 -> Try(U64, [GiveUp])
	retry_delay_ms = |attempts| match attempts {
		0 | 1 => Ok(60_000)
		2 => Ok(300_000)
		3 => Ok(900_000)
		4 => Ok(3_600_000)
		_ => Err(GiveUp)
	}

	## R-PU31, R-PU12, R-PU33: the answer of `GET /repositories/{repository_id}` for a job `Privatized`. The event body is old when GitHub sends an event again (R-PU12), so the Worker reads the repository.
	## 404: `Ok(Withdraw)` (the repository is deleted, or private and not readable, R-PU24, R-TP11). 200 with `visibility` `public`: `Ok(Stale)` (the event is old: nothing changes). 200 with `private` or `internal`
	## (`Ingest.parse_repo`): `Ok(Withdraw)`. 200 with a body that `Ingest.parse_repo` refuses: `Err(Upstream(text))`. Any other status: `Err(Upstream(text))`. The text is for the log line, with no name.
	repository_outcome : { status : U16, body : Str } -> Try([Withdraw, Stale], [Upstream(Str)])
	repository_outcome = |answer| match answer.status {
		404 => Ok(Withdraw)
		200 => match Ingest.parse_repo(answer.body) {
			Ok(repo) => if (repo.public) Ok(Stale) else Ok(Withdraw)
			Err(BadRepo) => Err(Upstream("the repository answer is not a repository"))
		}
		status => Err(Upstream("GitHub answered the repository read with status ${status.to_str()}"))
	}
}
