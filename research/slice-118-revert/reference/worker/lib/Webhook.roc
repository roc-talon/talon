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
		bytes = header.drop_prefix("sha256=").to_utf8()
		if bytes.len() != 64 {
			return Err(Malformed)
		}
		bytes.chunks_of(2).map_try(
			|pair| match pair {
				[h, l] => match (nibble(h), nibble(l)) {
					(Ok(a), Ok(b)) => Ok(a * 16 + b)
					_ => Err(Malformed)
				}
				_ => Err(Malformed)
			},
		)
	}

	nibble : U8 -> Try(U8, [Bad])
	nibble = |b| if (b >= '0' and b <= '9') Ok(b - '0') else if (b >= 'a' and b <= 'f') Ok(b - 'a' + 10) else if (b >= 'A' and b <= 'F') Ok(b - 'A' + 10) else Err(Bad)

	bad : Str -> Problem
	bad = |text| Problem.new(BadRequest, text)

	used_event : Str -> Bool
	used_event = |e| e == "release" or e == "repository" or e == "installation" or e == "installation_repositories"

	used_action : Str, Str -> Bool
	used_action = |e, a| match e {
		"release" => ["published", "released", "edited", "prereleased", "unpublished", "deleted"].contains(a)
		"repository" => a == "privatized" or a == "publicized"
		"installation" => ["created", "deleted", "suspend", "unsuspend"].contains(a)
		"installation_repositories" => a == "added" or a == "removed"
		_ => Bool.False
	}

	parse_event : { event : Str, body : List(U8) } -> Try(Webhook.Decision, Problem)
	parse_event = |input| {
		if input.event == "" {
			return Err(bad("the webhook has no X-GitHub-Event header"))
		}
		if !used_event(input.event) {
			return Ok(Ignore)
		}
		text = Str.from_utf8(input.body).map_err(|_| bad("the webhook body is not UTF-8"))?
		head : Try({ action : Str }, _)
		head = Json.parse(text)
		action = match head {
			Ok(h) => h.action
			Err(_) => return Err(bad("the webhook body is not a JSON object with a text member action"))
		}
		if !used_action(input.event, action) {
			return Ok(Ignore)
		}
		inst : Try({ installation : { id : U64 } }, _)
		inst = Json.parse(text)
		installation_id = match inst {
			Ok(i) => if (i.installation.id >= 1) i.installation.id else 0
			Err(_) => 0
		}
		base = { event: input.event, action, installation_id, repository_id: 0, release_id: 0, repository_ids: [] }
		match input.event {
			"release" => {
				ids : Try({ repository : { id : U64 }, release : { id : U64 } }, _)
				ids = Json.parse(text)
				match ids {
					Ok(i) if i.repository.id >= 1 and i.release.id >= 1 => Ok(Send({ ..base, repository_id: i.repository.id, release_id: i.release.id }))
					_ => Err(bad("the webhook body has no valid repository id and release id"))
				}
			}
			"repository" => {
				ids : Try({ repository : { id : U64 } }, _)
				ids = Json.parse(text)
				match ids {
					Ok(i) if i.repository.id >= 1 => Ok(Send({ ..base, repository_id: i.repository.id }))
					_ => Err(bad("the webhook body has no valid repository id"))
				}
			}
			"installation" => {
				list : Try({ repositories : Try(List({ id : U64 }), [Missing]) }, _)
				list = Json.parse(text)
				match list {
					Ok({ repositories: Ok(items) }) => Ok(Send({ ..base, repository_ids: items.map(|i| i.id) }))
					Ok({ repositories: Err(Missing) }) => Ok(Send(base))
					Err(_) => Err(bad("the webhook body has a repository without an id"))
				}
			}
			_ => {
				list : Try({ repositories_added : Try(List({ id : U64 }), [Missing]), repositories_removed : Try(List({ id : U64 }), [Missing]) }, _)
				list = Json.parse(text)
				match list {
					Ok(l) => {
						chosen = if (action == "added") l.repositories_added else l.repositories_removed
						match chosen {
							Ok(items) => Ok(Send({ ..base, repository_ids: items.map(|i| i.id) }))
							Err(Missing) => Ok(Send(base))
						}
					}
					Err(_) => Err(bad("the webhook body has a repository without an id"))
				}
			}
		}
	}

	Job : [Release({ action : Str, repository_id : U64, release_id : U64 }), Privatized(U64), Publicized(U64), AppInstalled({ repository_ids : List(U64), installed : Bool })]

	job_of : Webhook.Message -> Try(Webhook.Job, [Unknown])
	job_of = |m| match (m.event, m.action) {
		("release", a) if used_action("release", a) => Ok(Release({ action: a, repository_id: m.repository_id, release_id: m.release_id }))
		("repository", "privatized") => Ok(Privatized(m.repository_id))
		("repository", "publicized") => Ok(Publicized(m.repository_id))
		("installation", "created") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.True }))
		("installation", "deleted") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.False }))
		("installation", "suspend") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.False }))
		("installation", "unsuspend") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.True }))
		("installation_repositories", "added") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.True }))
		("installation_repositories", "removed") => Ok(AppInstalled({ repository_ids: m.repository_ids, installed: Bool.False }))
		_ => Err(Unknown)
	}

	retry_delay_ms : U32 -> Try(U64, [GiveUp])
	retry_delay_ms = |attempts| match attempts {
		1 => Ok(60_000)
		2 => Ok(300_000)
		3 => Ok(900_000)
		4 => Ok(3_600_000)
		_ => Err(GiveUp)
	}

	repository_outcome : { status : U16, body : Str } -> Try([Withdraw, Stale], [Upstream(Str)])
	repository_outcome = |x| if x.status == 404 {
		Ok(Withdraw)
	} else if x.status == 200 {
		match Ingest.parse_repo(x.body) {
			Ok(r) => if (r.public) Ok(Stale) else Ok(Withdraw)
			Err(BadRepo) => Err(Upstream("the GitHub repository answer is not valid"))
		}
	} else {
		Err(Upstream("the GitHub repository read failed with status ${x.status.to_str()}"))
	}
}
