# 118 Webhook and index queue (118a)

Phase: P2. Status: green for 118a, code 2026-11-02 (was: review; scope and red tests 2026-11-02; questions answered 2026-11-02, section 12; the tests have the changes of section 12.2, applied 2026-11-02). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 118. Depends on slices 112 (the ingest and its GitHub reads), 113 (`Identity`, the states `active`, `missing`, `moved`, the events of R-TP13). Slice 119a (the GitHub read token) is not a dependency: the consumer reads GitHub with the helper that the other routes use (`Http.send!` with the two headers of `IngestRoutes` today, `GithubRead.send!` when 119a is coded).

## 1. Scope and split

The row 118 of the plan holds four parts: the webhook route, the queue and its consumer, the release jobs (the release read again, the ingest with the provenance `webhook`, withdraw and clear, the asset check), and the jobs of the events `repository` and `installation`. The private reference of all four is about 650 lines of code (TW19: about 400). So the slice splits.

| Slice | Content | Rule ids | State |
| --- | --- | --- | --- |
| 118a (this file) | `POST /v1/webhooks/github` (HMAC, the event and action mapping, the message, 202), the queue binding and its `wrangler.toml` config, the consumer (the dispatch, the retry schedule, the dead letter log line), and the small jobs: `repository` `privatized` and `publicized` (R-PU33), `installation` and `installation_repositories` (R-PU26) | R-AP12, R-AP46, R-AP48 (rows 4 to 7 for the webhook), R-PU3, R-PU11, R-PU13 (schedule), R-PU24 (state and withdraw part), R-PU26 (events), R-PU31 (webhook row), R-PU32, R-PU33, R-PU35 (index retries), R-PU36 (queue row), R-WH14 (`GITHUB_WEBHOOK_SECRET`, `INDEX`, `INDEX_DLQ`) | Red tests |
| 118b (scope in section 8, no tests yet) | The job `Release`: `GET /repositories/{id}`, the release read again, R-PU6 candidate, the ingest with the provenance `webhook`, R-PU14, R-PU17 (withdraw and clear), R-PU19, R-PU20 (the recorded asset check), the reads again after 1, 5, 15 and 60 min for a release with no asset | R-PU12, R-PU13, R-PU14, R-PU17, R-PU19, R-PU20, R-PU15 (`webhook`) | After 118a. Slice 119a is green, so 118b uses `GithubRead.send!` and does not wait for it |

Reason for the order (TW19): 118a has no change of `IngestRoutes.roc`, so it can run now, at the same time as slice 114 (that slice changes `IngestRoutes.roc`). 118b must share the index flow of `IngestRoutes.roc` (the visibility read, the archive read, the write batch), so it starts when slice 114 has finished its change of that file. 118a is about 330 lines of code in the private reference (`lib/Webhook.roc` about 150, `WebhookRoutes.roc` about 45, `IndexQueue.roc` about 130).

```mermaid
flowchart TB
    GH["GitHub: POST /v1/webhooks/github"] --> R["Route.decide: POST, media type"]
    R --> B["body (256 KB) -> 413"]
    B --> S["secret -> 500 if missing or empty"]
    S --> H{"HMAC-SHA256 of the raw bytes, constant time"}
    H -->|"bad or missing"| U401["401 unauthenticated"]
    H -->|"good"| P["Webhook.parse_event"]
    P -->|"bad body"| U400["400 bad-request"]
    P -->|"Ignore"| A202["202, no message"]
    P -->|"Send(message)"| Q["INDEX.send (no delay)"] --> A202b["202, no-store"]
    Q -.-> C["queue! consumer talon-index"]
    C --> J{"Webhook.job_of"}
    J -->|"Privatized"| PR["GET /repositories/id, Withdraw: repos missing + event, releases repo-missing"]
    J -->|"Publicized"| PU["repo_checks.next_check_at = now"]
    J -->|"AppInstalled"| AI["repo_checks.app_installed"]
    J -->|"Release"| X["118b"]
    C -->|"failure"| RT["retry_with(delay 1, 5, 15, 60 min), after attempt 5: retry (dead letter queue)"]
    RT -.-> D["queue! consumer talon-index-dlq: one error log line"]
```

## 2. Runner probe (done before the tests)

`research/slice-118/probe-queue.mjs` (Miniflare of the global wrangler, as `run.mjs`):

| Question | Result |
| --- | --- |
| A queue producer with no consumer | A `send` is accepted. The message stays in the queue. |
| A `send` with `delaySeconds` | The wrapper of the test entry sees `(body, {contentType: "json", delaySeconds})`. A delay of 60 s is not waited for. |
| The consumer with no broker | `(await mf.getWorker()).queue(name, messages)` calls the `queue` handler and returns `explicitAcks`, `retryMessages: [{msgId, delaySeconds}]` and `retryBatch`. No wait, so the delays 1, 5, 15, 60 min are checked as numbers. |
| A patch of `crypto.subtle.timingSafeEqual` | An assignment in the isolate works: a count of calls. The Roc `WebCrypto.timing_safe_equal!` calls this function, so the test can see that a compare is constant time. |
| What a local run cannot show | The move of a message to the dead letter queue (the broker does it, after real delays of 1 to 60 min). The config is checked as text (section 4.4). |

## 3. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP12, R-AP79 rows 5, 10 | `POST /v1/webhooks/github`: 202 with no body and `cache-control: no-store`; 401 `unauthenticated` for a signature that is missing or bad (one `detail`). The HMAC-SHA256 key is the secret `GITHUB_WEBHOOK_SECRET`. The message is the RAW bytes of the body. | W0 `parse_signature`, `bad_signature`. W2 `ap12-signature` requests 1 to 10 |
| R-AP12, R-AP79 row 5 (constant time) | The compare is `WebCrypto.timing_safe_equal!`: one call for each header of the good form | W2 `ap12-signature` (`timing_safe`) |
| R-WH14, R-AP79 row 4, Q327 | A missing secret, or an empty one, is 500 `internal`, never the empty key. It comes after the size and media checks and before the signature header. | W2 `ap12-no-secret`, `ap12-empty-secret` (5 requests each) |
| R-AP79 rows 1 to 3, R-AP48 rows 1, 2, 4, 5 | 404 for a path below the route, 405 `Allow: POST`, 413 over 1 MiB (before the media type and the signature), 415 for another media type (before the secret and the signature) | W0 `Route.decide`. W2 `ap12-signature` requests 15 to 18, `ap12-no-secret` requests 3, 4 |
| R-AP46, R-AP79 row 2, Q326 | The body of this route is at most 1 MiB (1048576 bytes pass, 1048577 do not; 262145 bytes pass) | W2 `ap12-signature` requests 13 to 15 (`body_pad`) |
| R-AP79 rows 6 to 9, Q320, Q321 | The signature comes before the event and the body parse: a body that is not JSON with a bad signature is 401. A good signature and a missing or empty `X-GitHub-Event` is 400. An event that is not used is 202 with its body unread. | W0 `parse_event` (empty event). W2 `ap12-signature` requests 19 to 23 |
| R-PU11, R-PU3, R-AP79 rows 7 to 9 | The events and actions that the Worker uses become one message each; `release` `created`, `installation` `new_permissions_accepted` and every other event or action are ignored (202, no message); the message has ids, no name | W0 `parse_event`. W2 `pu11-events` |
| R-PU11 (message) | The message holds the event, the action and the GitHub ids of the repository, the installation and the release | W0 `parse_event`. W2 `pu11-events` (`queue_sent`) |
| R-PU13, R-PU35, R-PU45, Q323 | The retries come after 1, 5, 15 and 60 min, each from the failed attempt (reads at 0, 1, 6, 21 and 81 min); after the last attempt (5) the consumer retries with no delay and the platform moves the message to the dead letter queue | W0 `retry_delay_ms`. W2 `pu35-retry-schedule`. Frame row (`max_retries = 4`, `dead_letter_queue`) |
| R-PU35, R-PU45 (dead letter) | The consumer of the dead letter queue writes one log line for each message and acks it | W2 `pu35-dead-letter` (`logs.jsonl`) |
| R-PU36 | A job that comes twice does the same as once: a second `privatized` changes nothing | W2 `pu33-privatized` request 2 |
| R-PU33, R-PU24, R-TP11, R-TP19 | `privatized`: the row of the current name becomes `missing` (event `Missing`), every release of every name of the repository gets `withdrawn` = `repo-missing` (not one that is withdrawn already), a `moved` row keeps its state | W2 `pu33-privatized` |
| R-PU31 (webhook row), R-PU12 | The event body is not used for the visibility: the consumer reads `GET /repositories/{id}`. 404 and `private` and `internal` withdraw. `public` is a stale event: nothing changes. A GitHub fault is a failed job (retry). | W0 `repository_outcome`. W2 `pu33-privatized`, `pu35-retry-schedule` |
| R-PU32 | A repository with no `repos` row: nothing is written (no row, no queue job holds a name) | W2 `pu33-privatized` (id 999), `pu26-app-installed` (id 999), `pu33-publicized` (id 999) |
| R-PU33 (`publicized`), Q324 | `next_check_at` of the rows that are not `moved` becomes now; the state and `withdrawn` do not change; a `moved` row of the same repository id keeps its value | W2 `pu33-publicized` |
| R-PU26, Q322, Q324 | `installation` `created` and `unsuspend` and `installation_repositories` `added` set `repo_checks.app_installed` to 1; `deleted`, `suspend` and `removed` to 0; for EVERY row (also `moved`) of the repositories of the event; no row is added. `new_permissions_accepted` is ignored. | W0 `job_of`, `parse_event`. W2 `pu26-app-installed` |
| R-WH14, R-PU45, Q329 | `INDEX` is a queue producer; `INDEX_DLQ` has a consumer and no producer in the code (no binding in `main.roc`); `GITHUB_WEBHOOK_SECRET` is a secret | Frame rows (`worker/tests/frame.sh`). W2 (the runner gives `INDEX` and `INDEX_DLQ`) |
| R-AP41 | The webhook costs no D1 call (the work is in the queue, not counted) | W2 `expect/d1-calls` (0 for every webhook request) |

Design refs: Registry 4 (R-AP12, R-AP46, R-AP48, R-AP79), 7 (R-PU3, R-PU11 to R-PU13, R-PU24, R-PU26, R-PU31 to R-PU33, R-PU35, R-PU36, R-PU45), 7.3 (R-TP11, R-TP13, R-TP19), 8 (R-WH14); `cloudflare-workers/API.md` RN16, `MODULES.md` 6 (Queue); Design Q48, Q56, Q320 to Q331.

## 4. What the code agent writes

### 4.1 Public signatures (fixed, in the stubs)

| Module | Item | Rule |
| --- | --- | --- |
| `lib/Webhook.roc` (pure) | `queue_name`, `dlq_name`, `max_attempts`, `Message`, `Decision`, `bad_signature` (given) | R-PU35, R-PU11, R-AP12 |
| `lib/Webhook.roc` | `parse_signature : Str -> Try(List(U8), [Malformed])` | R-AP12 |
| `lib/Webhook.roc` | `parse_event : { event : Str, body : List(U8) } -> Try(Webhook.Decision, Problem)` (rules 1 to 5 in the doc comment) | R-PU11, R-AP48 row 6 |
| `lib/Webhook.roc` | `Job`, `job_of : Webhook.Message -> Try(Webhook.Job, [Unknown])` | R-PU11 |
| `lib/Webhook.roc` | `retry_delay_ms : U32 -> Try(U64, [GiveUp])` | R-PU13, R-PU35 |
| `lib/Webhook.roc` | `repository_outcome : { status : U16, body : Str } -> Try([Withdraw, Stale], [Upstream(Str)])` | R-PU31, R-PU33 |
| `WebhookRoutes.roc` | `post! : Request => Try(Response, ReadRoutes.Error)` (the flow in the doc comment) | R-AP12 |
| `IndexQueue.roc` | `index : Queue(Webhook.Message)` (given: `Queue.json("INDEX")`), `consume! : Queue.Batch => Try({}, [Fault(Str)])` (the flow in the doc comment) | R-PU11, R-PU35 |
| `lib/Route.roc` | The tag `PostWebhook` (done). The line of `decide` is for the code agent. | R-AP12 |

### 4.2 What the code agent changes

| File | Change | State |
| --- | --- | --- |
| `worker/lib/Route.roc` | In `decide`: `["v1", "webhooks", "github"] => decide_post(input, path, PostWebhook)`. `decide_post` gives 405 `Allow: POST` and the media check. | For the code agent |
| `worker/lib/Webhook.roc`, `IndexQueue.roc`, `WebhookRoutes.roc` | The bodies. `Client.is_write` stays as it is (the webhook is not a write route of R-AP45). | For the code agent |
| `worker/main.roc` | `import WebhookRoutes`, `import IndexQueue`, the arm `PostWebhook`, `queue! = |b| IndexQueue.consume!(b)`, `IndexQueue.index.declare()` in the bindings | Done (test agent) |
| `worker/lib/main.roc`, `worker/tests/unit/w0.roc` | `Webhook` in the exposes, `import WebhookTest` | Done |
| `worker/wrangler.toml` | `[[queues.producers]]` `INDEX`, the consumers of `talon-index` (`max_retries = 4`, `dead_letter_queue`) and of `talon-index-dlq` | Done (the build needs it) |
| `GITHUB_WEBHOOK_SECRET` | A secret: `wrangler secret put` at the deploy. The tests set it as a test value. | Deploy step |

The doc comments of the three stubs are the flow. Two points that the code agent must keep:

| Point | Reason |
| --- | --- |
| The consumer does not use `Queue.each!` | It acks after an `Ok` and retries with no delay after an `Err`. The consumer reads `Cbor.parse(m.body())`, calls `m.ack!()`, `m.retry_with!({ delay_ms })` or `m.retry!()`. |
| The HMAC is over the raw bytes `req.bytes_with!` gave, not over a text that was parsed | The W2 case `ap12-signature` request 2 signs the compact form of the same JSON and expects 401. |

## 5. Tests

### 5.1 Table

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| W0 | `worker/tests/unit/WebhookTest.roc`, 13 `expect`s | `parse_signature` (12 forms), `bad_signature` is 401, `Route.decide` for the webhook path (POST json, form 415, GET and PUT 405, a longer path 404), `parse_event`: 6 `release` actions with a realistic payload (null values, nested objects), `created` and an unknown action ignored, no `installation` is id 0; `repository` (2 sent, 3 ignored); `installation` (`created`, `deleted`, `suspend`, `unsuspend` sent with the ids, `new_permissions_accepted` ignored, an empty list) and `installation_repositories`; events that are not used (`ping` with a body that is not JSON is ignored); an empty event is 400 (3 bodies); the 400 forms (16); `job_of` (16 rows, `suspend` False, `unsuspend` True); `retry_delay_ms` (the 4 delays, 5 and after, the constants); `repository_outcome` (13 rows) | R-AP12, R-AP79, R-PU11, R-PU13, R-PU26, R-PU33, R-PU35, R-PU31 |
| W2 | `webhook/ap12-signature` (23 requests) | A good signature of the raw bytes with white space and a non-ASCII escape (202, no body, `no-store`, one message, 1 compare, 0 D1 calls). 401 for: the signature of the compact form, another key, the last hex digit changed, a body one byte longer, no header, `sha1=`, 63 digits, no prefix, a non-hex digit. 400 for a body that is not JSON and for no body (with a good signature). Bodies made by the runner (`body_pad`): 1048576 bytes pass (a `ping`), 262145 bytes pass, 1048577 bytes: 413 with `limit` 1048576 and no compare. A form body with a bad signature: 415 with no compare. GET: 405 `Allow: POST`. A longer path: 404. Requests 19 to 23 (Q320, Q321): a good signature and no event header, and an empty one: 400 (one compare); no event header and no signature: 401; a body that is not JSON with a bad signature and the event `release`: 401 (one compare); a body that is not JSON with a good signature and the event `ping`: 202, no message. | R-AP12, R-AP79, R-AP48, R-AP46, R-AP23, R-AP21 |
| W2 | `webhook/ap12-no-secret`, `webhook/ap12-empty-secret` (5 requests each) | The secret is not set, or is empty: a signature with a made-up key and one with the empty key both give 500 `internal`; nothing is sent. No signature header: 500 (the secret comes before the header, Q327). A body of 1048577 bytes: 413, and a form body: 415 (the static checks come before the secret). | R-AP12, R-AP79 rows 2 to 4, R-WH14 |
| W2 | `webhook/pu11-events` (22 requests) | The exact message of each of the 6 `release` actions, `created` (no message), a release with no installation (id 0), `repository` `privatized` and `publicized`, `archived` and `deleted` ignored, `installation` `created`, `deleted`, `suspend` and `unsuspend` (a message each), `new_permissions_accepted` ignored, `installation_repositories` `added` and `removed`, `ping` and `star` ignored, a release with no repository id (400). The `queue_sent` list is exact. | R-PU11, R-PU3, R-PU32, R-AP79 |
| W2 | `webhook/pu33-privatized` (6 queue lines) | 7 repositories (one with a `moved` second name, one already `missing`, one with a withdrawn release). `privatized` 100: `missing` with the event `Missing` (seq 2), the releases of both names `repo-missing`, the earlier `deleted` kept, the `moved` row unchanged. The same job later, and 600: no change at all (the old `state_at` and `withdrawn_at`). 300: GitHub says public: nothing. 400: 404: withdrawn. 999: no row: nothing is added. 500: GitHub 500: retried after 60 s, not acked. db.tsv of 5 tables and the counts. github.log lists 7 reads. | R-PU33, R-PU24, R-PU31, R-PU32, R-PU36, R-TP11, R-TP13, R-TP19 |
| W2 | `webhook/pu33-publicized` (3 lines) | `next_check_at` becomes the clock for 100 (state `missing` and `repo-missing` stay, no event, no GitHub read); 999 writes nothing; 700 has `acme/new` active and `acme/old` moved: only `acme/new` changes (Q324) | R-PU33, R-PU32, R-TP19 |
| W2 | `webhook/pu26-app-installed` (9 lines) | `created` [100, 101, 999], `removed` [101], `added` [200], `deleted` [100, 300], an empty list, `suspend` [200] (1 to 0), `unsuspend` [300] (0 to 1), `created` [700] (two rows, one `moved`: both 1), `removed` [701] (two rows, both 1 to 0); `app_installed` and unchanged `next_check_at`; no row for 999 | R-PU26, R-PU32, R-TP19 |
| W2 | `webhook/pu35-retry-schedule` (9 lines) | A job that fails (GitHub 500) at attempts 1 to 5: retried after 60, 300, 900, 3600 s, then with no delay; attempt 6 the same; a body that is not a message and a message of an unknown action are failures with the delay of their attempt; a batch of 3 messages has 3 delays | R-PU35, R-PU13 |
| W2 | `webhook/pu35-dead-letter` (1 line) | The queue `talon-index-dlq`: a message and a body that is not a message are acked; 2 error log lines (`index job dead`), no D1 row | R-PU35, R-PU32 |
| Frame | `worker/tests/frame.sh` (5 rows) | `wrangler.toml` has the producer `INDEX` for `talon-index`, the consumer of `talon-index` with `max_retries = 4` and `dead_letter_queue = "talon-index-dlq"`, and a consumer of `talon-index-dlq` | R-PU35, R-WH14 |
| Runner | `cases/runner/r-wh4-queue-and-logs`, `selftest/wrong-queue-sent`, `wrong-queue-sent-none`, `wrong-timing-safe`, `wrong-queue-retry`, `wrong-queue-acked`, `wrong-log`, `wrong-body-pad` (the `body_pad` line and `/__test/len`) | The new checks of the runner (section 5.3): each fails for a wrong value | R-WH4 |

`node worker/tests/tools/mk-webhook.mjs` writes the 9 cases (a body of 1 MiB is a `body_pad` of the runner, not a file). The signatures (`crypto.createHmac`), the ids (SHA-256) and the version columns come from node, not from the Roc code. `notes.txt` in each case names each request. The tests use the secret `test-webhook-secret`; the real secret of the App is never read.

### 5.2 Red results (2026-11-02, after the answers of section 12)

| Step | Result |
| --- | --- |
| W0 `WebhookTest` with the stubs (`NOREF=1 research/slice-118-revert/ref.sh w0`) | 13 expects: 1 passes (`bad_signature`), 12 fail (11 with `todo`, the route row with the wrong value: the `decide` line is missing). 0 compiler errors. |
| W2 `webhook/*` with the stubs (`scripts/test.sh wbuild w2`) | 9 of 9 fail. The `queue` handler gives `trap: todo`; the HTTP cases give the wrong status (404 with no route line, the trap of `todo` with it). |
| `roc check worker/main.roc`, `roc fmt --check` of the new files | 0 errors |
| `worker/tests/frame.sh` | Green (the `wrangler.toml` lines are done) |
| Runner and selftest cases | `runner/*` 7 of 7 and `selftest/*` 34 of 34 pass (with `wrong-body-pad`) |
| Full W2 (`scripts/test.sh wbuild w2`) | 158 cases: 84 pass, 74 fail. `webhook/*` 9 (this slice, red by design), `account/*` 8 (slice 117), `publish/*` 4 (slice 114). The other 53 failures are `runner fault: D1_ERROR: table toolchains has no column named size`: the slice 109 agent changes `sql/` at the same time (`compat`, `hints`, `reads`, `ingest*`, `oidc`, `githubtoken`, `toolchains`, `closure`). They are not from this slice: the runner changes of 118 do not touch the schema, and the same cases passed in the first run of this slice. |

### 5.3 Shared files changed (copies before in `research/slice-118-revert/before/`)

| File | Change |
| --- | --- |
| `worker/tests/run.mjs` | `body_pad` (a body of N bytes made by the runner). Each case gets the queue producers `INDEX` and `INDEX_DLQ` (no consumer). A request line `{"queue", "now", "messages"}` calls the `queue` handler (`worker.queue()`). New expected keys: `queue_sent`, `timing_safe` (responses), `acked` and `retried` (queue lines), `expect/logs.jsonl` (log lines). The header of the file documents them. |
| `worker/tests/worker-test.js` | `/__test/len` (the length of the body). The wrapper of `env.INDEX` (header `x-queue-sent`), the count of `crypto.subtle.timingSafeEqual` (header `x-timing-safe-calls`), the queue `__test...` answered in JS, the paths `/__test/send`, `/__test/timing`, `/__test/log` |
| `worker/tests/frame.sh` | The 5 queue rows |
| `worker/lib/Route.roc` | `PostWebhook` in `Route.Id` |
| `worker/main.roc` | See 4.2 |
| `worker/lib/main.roc`, `worker/tests/unit/w0.roc` | `Webhook`, `import WebhookTest` |
| `worker/wrangler.toml` | See 4.2 |

New files are in `research/slice-118-revert/before/NEW.txt`.

### 5.4 Revert check (private reference)

`research/slice-118-revert/reference/worker/` fills `lib/Webhook.roc`, `IndexQueue.roc` and `WebhookRoutes.roc`. `ref.sh all` copies `worker/`, `packages/records` and `sql/` to `refbuild/`, puts the reference over it, adds the `Route.decide` line, runs W0 (`WebhookTest`) and W2 (`webhook/ runner/ selftest/`): 13 of 13 expects, 50 of 50 cases (9 `webhook/`). The build is `--opt=speed`. `MUTATE=mutations/<m>.py ref.sh all webhook/` runs one mutation; `run-mutations.sh m1 m2 ...` runs several. Keep the reference until the review is applied.

| Mutation (2026-11-02) | Caught by |
| --- | --- |
| m1 the HMAC is over the body with the white space cut (not the raw bytes) | W2 `ap12-signature` (the good request gives 401, the compact-form request gives 202), `pu11-events` |
| m2 the compare is `==` (not constant time) | W2 `ap12-signature`, `pu11-events` (`timing_safe` 0 in place of 1) |
| m3 a missing secret is the empty key, and an empty secret is accepted | W2 `ap12-no-secret`, `ap12-empty-secret` |
| m4 the third delay is 10 min in place of 15 | W0 `retry_delay_ms`, W2 `pu35-retry-schedule` |
| m5 attempt 4 gives up (off by one) | W0 `retry_delay_ms`, W2 `pu35-retry-schedule` |
| m6 `release` `created` (a draft) is a used action | W0 `parse_event` (2 expects), W2 `pu11-events` |
| m7 `privatized` withdraws only the releases of the row that is not `moved` | W2 `pu33-privatized` (the release of `acme/old`) |
| m8 `privatized` does not look at the visibility (a public answer withdraws) | W0 `repository_outcome`, W2 `pu33-privatized` (id 300) |
| m9 the last attempt acks the message (no dead letter queue) | W2 `pu35-retry-schedule` |
| m10 `installation` `deleted` sets `app_installed` to 1 | W0 `job_of`, W2 `pu26-app-installed` |

| m11 the body is parsed before the signature (Q320) | W2 `ap12-signature` (request 19 no compare, request 21 gives 400 in place of 401) |
| m12 the body limit is 262144 (Q326) | W2 `ap12-signature` (the 1 MiB and 262145 byte requests give 413) |
| m13 `installation` `suspend` is ignored (Q322) | W0 `parse_event`, `job_of`; W2 `pu11-events` (request 17) |
| m14 `installation` changes the first row of a repository id only (Q324) | W2 `pu26-app-installed` (repositories 700 and 701) |
| m15 `publicized` also changes a `moved` row (Q324) | W2 `pu33-publicized` (repository 700, `acme/old`) |

Caught 15 of 15 (round 1: m1 to m10; this round: m11 to m15, and m6 and m10 run again with the new cases: both still caught, `pu11-events` and `pu26-app-installed`). The logs are `research/slice-118-revert/mut-<m>.log`.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| Queue names | `talon-index` (binding `INDEX`), `talon-index-dlq` (binding `INDEX_DLQ`). R-WH14 gives the binding names only. The names stay a proposal (Q331). `main.roc` has no `INDEX_DLQ` binding (Q329). |
| Message (`Queue.json`, a JSON object with these 6 members) | `{"event":"release","action":"published","installation_id":55,"repository_id":100,"release_id":9001,"repository_ids":[]}`. A number that does not apply is 0, a list that does not apply is `[]`. No name (R-PU32). |
| 202 | No body, `cache-control: no-store`, no `content-type` |
| 401 | `unauthenticated`, `detail` `the signature of the webhook is missing or not valid` (one text for all causes) |
| 400 | `bad-request`. `detail` (proposal, the tests check the type only): `the webhook body is not a JSON object with a text member action`; `the webhook body has no valid repository id and release id`; `the webhook body has no valid repository id`; `the webhook body has a repository without an id`; `the webhook body is not UTF-8`; for a good signature and no event header: `the webhook has no X-GitHub-Event header` |
| 413 | As the other routes: `too-large`, `field` `body`, `limit` 1048576 (R-AP79, Q326) |
| 500 | `internal` with the fixed `detail` of R-AP48, for a missing or empty secret (after the size and media checks, before the signature header, Q327) and a failed send |
| Dead letter log line | `Log.error!("index job dead", { event, action, repository_id, release_id })`; for a body that is not a message `{ readable: false }` |
| Failed job log line | `Log.warn!("index job failed", { attempts, error })`. No test checks it. |
| GitHub call of `privatized` | `GET https://api.github.com/repositories/<id>` with the headers `user-agent: talon-registry`, `accept: application/vnd.github+json` |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| The job `Release` and its rules: R-PU12 (the release read), R-PU13 (the ingest and the reads again), R-PU14, R-PU15 (`webhook`), R-PU17, R-PU19, R-PU20 | Slice 118b (section 8). In 118a the arm `Release` is a failure with the error `not done`; no test checks it. |
| The move of a message to the dead letter queue after 5 failed attempts | The broker does it after real delays (1 to 60 min). A local run cannot show it. The config is a frame row, and the consumer retries with no delay at attempt 5. First deploy: R-PU45 (W3 check, below). If the check fails, the fallback of Q330 applies: at attempt 5 the consumer sends the message to `INDEX_DLQ` itself and acks it. |
| Constant time of the compare as a time measure | The test counts the calls of `timingSafeEqual`. The platform function is constant time. |
| The signature of a real GitHub delivery | The real secret is never read. The tests use `test-webhook-secret`. The user sets the real secret with `wrangler secret put GITHUB_WEBHOOK_SECRET` and turns the webhook of the App on with the real URL (`research/github-app-check/README.md`). |
| Redelivery by GitHub, `X-GitHub-Delivery` | The design has no rule. Every path is idempotent for a label (R-PU14, R-PU36). |
| The W3 first-deploy check of R-PU45 | A test Worker with a throwaway queue pair (`max_retries = 1`, a dead letter queue) and a consumer that always retries with no delay. Expected: the message comes to the dead letter queue after the second delivery. Run it once at the first deploy and write the result in section 11. A test agent of W3 does it, not this slice. |
| R-PU22 (the interval of the reconcile for `app_installed`), R-PU23 | Slice 119 |
| R-AP45 for the webhook | `MIN_TLN_WRITE` does not apply (Design Q182). No row, because `Client.is_write` does not list `PostWebhook`. |
| The upload of an asset to a published release (no event, R-PU13) | The reads again of 118b |

## 8. Scope of 118b (for the next test agent)

| Item | Content |
| --- | --- |
| Job | `Release({ action, repository_id, release_id })` of `Webhook.job_of`. Start with `GET /repositories/{repository_id}` (R-PU31 webhook row): `Webhook.repository_outcome`; not public: write nothing for a new name, apply R-PU33 for a known name (the repository is `missing` already or becomes so), and ignore the release event ("While a repository is not public, the Worker ignores its release events", R-PU33). |
| Release read | R-PU12: not the event body. The endpoint is `GET /repos/{full_name}/releases/{release_id}` with the `full_name` of the repository answer (Q328). The read uses `GithubRead.send!`. |
| `published`, `released`, `edited` | R-PU13: when the release passes `Ingest.candidate`, the ingest of the asset URL with the provenance `webhook` (via 1, R-PU15) through the flow of `IngestRoutes.index!` (the archive read, the write batch, R-TP9 to R-TP19, the label rules R-PU14, R-PU19). No asset: the retry with `Webhook.retry_delay_ms` (the failure path of `IndexQueue.consume!`). 2 or more package assets: not a candidate, no retry. A release that is deleted meanwhile (404): stop. |
| `unpublished`, `deleted`, `prereleased`, `edited` (now a prerelease) | R-PU17: `releases.withdrawn` = the action and the time, for the indexed label of that release (for `edited` the value is `edited`, Q332). `published`, `released`, `edited` with the same asset hash clear it. |
| R-PU20 | The recorded asset of each indexed label of the release is still there, else `withdrawn` = `asset-replaced`; there again: clear |
| Tests | W0 for the decisions (the action to the effect, the asset check), W2 with the fake GitHub: a release with no asset, then the asset on the 3rd read (the message comes back with `attempts` 2 and 3 through queue lines), a conflict that is logged and written nowhere (R-PU14 "The webhook path writes nothing and logs the conflict"; the call is `Log.warn!("index label conflict", { repository_id, release_id, group, version })`, Q333), the fifth read with no asset is acked with the info line `index job no asset` and not sent to the dead letter queue (Q334), a `Release` job with `installation_id >= 1` sets `app_installed` 1 on the rows of the repository and on a row it adds (Q335), a private repository |
| Start | After slice 114 finishes its change to `IngestRoutes.roc`. Slice 119a is green, so 118b does not wait for it. No 118b test is written yet. |
| Settled for 118b | None open. Q118-9 is Q328, the log line of a conflict is Q333, the `withdrawn` value of `edited` is Q332, the end of a release with no asset is Q334, `app_installed` from a release job is Q335 (section 12.3). |

## 9. Questions

All 11 questions of the first round, and the 118b points, are settled. The answers are Design 9 Q320 to Q335 and the rules R-AP79 and R-PU45 (section 12). No question is open.

| Old id | Settled as | Effect on the tests |
| --- | --- | --- |
| Q118-1 | Q320 | `ap12-signature` request (d) |
| Q118-2 | Q321 | `ap12-signature` requests 19 to 21, W0 `parse_event` |
| Q118-3 | Q322 | `pu11-events`, `pu26-app-installed`, W0 `job_of` |
| Q118-4 | Q323 | `retry_delay_ms`, `pu35-retry-schedule` |
| Q118-5 | Q324 | `pu33-publicized` (repository 700), `pu26-app-installed` (700, 701) |
| Q118-6 | Q325 | `pu33-privatized` |
| Q118-7 | Q326 | `ap12-signature` (262145, 1 MiB, 1048577 bytes) |
| Q118-8 | Q327 | `ap12-no-secret`, `ap12-empty-secret` |
| Q118-9 | Q328 | 118b |
| Q118-10 | Q329 | No test |
| Q118-11 | Q330 (R-PU45) | W3 check at the first deploy |
| (new) | Q331 | The queue names stay a proposal |
| (new) | Q332 to Q335 | 118b |

## 10. Disputes (from the code agent)

None.

## 11. Verify results

Status of the test agent (2026-11-02, round 2): the tests follow the answers of section 12. The red results are in 5.2, the reference and the mutations in 5.4. The code agent turns the red cases green (`scripts/test.sh wbuild w0 w2`); the W3 check of R-PU45 is open for the first deploy.

### 11.1 Code agent result (2026-11-02)

| Item | Result |
| --- | --- |
| Files written | `worker/lib/Webhook.roc` (the bodies of 5 stubs and the helpers), `worker/WebhookRoutes.roc`, `worker/IndexQueue.roc`, and the `decide` line for `PostWebhook` in `worker/lib/Route.roc` (1 line) |
| Lines (all of the file, doc comments too) | See the table below |
| W0 `WebhookTest` | 13 of 13 `expect`s pass (`scripts/test.sh w0`; the 23 other failures of W0 are in the tests of other slices: Closure, Ingest, Login, Publish, Reads) |
| W2 `webhook/*` | 9 of 9 pass (`OPT=speed scripts/test.sh wbuild w2`). Full W2: 131 pass, 27 fail. The 27 are `account/*` (slice 117), `publish/*` (114) and the cases that read `provenance` (`reads/*`, `closure/ap17-answer`, `ingest*`; slice 122 and 109b). None is a `webhook/*` case. |
| Runner and selftest | `runner/*` and `selftest/*` pass |
| `roc check worker/main.roc`, `roc fmt` of the 4 files | 0 errors |
| W1 | 49 pass, 4 fail (`closure/c2-closure-cte`, `schema/s1-tables`: schema of slice 109b, not this slice) |

| File | Lines |
| --- | --- |
| `worker/lib/Webhook.roc` | 223 |
| `worker/WebhookRoutes.roc` | 68 |
| `worker/IndexQueue.roc` | 153 |

Decisions that the slice does not fix:

| Decision | Rejected option |
| --- | --- |
| `privatized` writes the `Missing` event with `INSERT .. SELECT` before the `UPDATE repos` (guarded by `state = 0`), so the event does not depend on `changes()` | The order of the doc comment (update, then the event with `WHERE changes() > 0`) |
| The HMAC is `WebCrypto.hmac_sha256` (pure, in the platform 0.0.2), the compare is `WebCrypto.timing_safe_equal!` | `WebCrypto.sign!` with `Hmac(Sha256)` (one wait, no gain) |
| A queue name that is neither `talon-index` nor `talon-index-dlq` is `Err(Fault)` | Ack of the batch |
| `Release` job is `Err("not done")` (118b) | none |
| The failed-job log line has `{ attempts, error }` (section 6) | The ids of the message in the line |
| The GitHub read of `privatized` uses `GithubRead.send!` (119a is green) | `Http.send!` |

Revert check: not done by this agent (the manager rule asks 5 to 10 mutations; the test agent's 15 mutations of 5.4 ran on the private reference).

## 12. Answers (design agent, 2026-11-02)

### 12.1 Decisions

9 of 11 proposals hold. 2 change (Q118-3 and Q118-7). Q118-8 and Q118-11 get an addition (the order of the 500; a fallback). The rules are in `DESIGN-REGISTRY.md` and the settled questions in `DESIGN.md` 9.

| Slice id | Q id | Answer | Proposal | Rule |
| --- | --- | --- | --- | --- |
| Q118-1 | Q320 | The signature first (401), then the parse (400). The reason of R-AP48 for the parse before the token does not hold: an HMAC is local, cheaper than the JSON parse, and GitHub says to verify before use. | Taken | R-AP79 rows 4, 5, 8; R-AP48 note |
| Q118-2 | Q321 | A good signature and no `X-GitHub-Event` (or an empty one): 400. After the signature, before the body. | Taken | R-AP79 row 6 |
| Q118-3 | Q322 | `suspend` sets `app_installed` 0, `unsuspend` sets 1, `new_permissions_accepted` is ignored. The GitHub docs are silent on events of a suspended installation; a wrong 0 costs a read an hour, a wrong 1 leaves the index old for a day. The payload of all five actions has `repositories`. | Changed (`suspend`, `unsuspend` were ignored) | R-PU11, R-PU26 |
| Q118-4 | Q323 | One after another from the failed attempt: reads at 0, 1, 6, 21, 81 min. | Taken | R-PU45, R-PU13 |
| Q118-5 | Q324 | `publicized`: rows that are not `moved`. `installation`: every row of the repository id. | Taken | R-TP19, R-PU26, R-PU33 |
| Q118-6 | Q325 | Yes, the job reads; `privatized` is a hint. | Taken | R-PU33 |
| Q118-7 | Q326 | The limit of this route is 1 MiB (1,048,576), not 256 KB. Measured: a normal payload is 30 to 70 KB (release objects of 4 projects: 20 to 56 KB, repository 6 to 7 KB, an asset 1.4 to 1.7 KB). `edited` holds the old body too: 2 bodies of 125,000 characters are about 260 KB (ASCII) or 760 KB (3-byte characters). 256 KB is just under the real worst case. The D1 reason of R-AP46 does not apply to this route. GitHub drops payloads over 25 MB itself. | Changed (was 256 KB) | R-AP46, R-AP79 row 2 |
| Q118-8 | Q327 | 500, never the empty key. After rows 1 to 3 (path, method, size, media type), before the signature header. | Taken, order added | R-AP79 row 4 |
| Q118-9 | Q328 | `GET /repos/{full_name}/releases/{release_id}`, `full_name` from `GET /repositories/{id}` of the same job. | Taken | R-PU12 |
| Q118-10 | Q329 | Yes. No producer for `INDEX_DLQ`, no binding in `main.roc`. The operator makes both queues with `wrangler queues create`. | Taken | R-PU45 |
| Q118-11 | Q330 | Yes. The Cloudflare docs say a message goes to the dead letter queue when it reaches the retry limit. Edge check once (R-PU45 "Edge check"). Fallback fixed now: the consumer at attempt 5 sends to `INDEX_DLQ` itself. | Taken, with a fallback | R-PU45 |
| TW24 | Q331 | `talon-index`, `talon-index-dlq` stay a proposal. R-WH14 lists them. | Taken | R-WH14 |

### 12.2 Test changes (for the test agent; the code agent does not edit tests)

| Layer | File or case | Change | Q |
| --- | --- | --- | --- |
| W0 | `WebhookTest.roc`, `parse_event` | `installation` `suspend` and `unsuspend` give `Send` with the `repository_ids` (as `created`). `installation` `new_permissions_accepted` is `Ok(Ignore)`. An empty `event` with a valid release body is `Err` 400. An empty `event` with a body that is not JSON is `Err` 400 (the event check is first). `ping` with a body that is not JSON stays `Ok(Ignore)`. | Q321, Q322 |
| W0 | `WebhookTest.roc`, `job_of` | `installation` `suspend` is `AppInstalled({ repository_ids, installed: False })`, `unsuspend` is `installed: True`. `installation` `new_permissions_accepted` is `Err(Unknown)`. | Q322 |
| W0 | stub `lib/Webhook.roc` doc comments | `parse_event` rule 0: an empty `event` is 400. Rule 3: `installation` uses `created`, `deleted`, `suspend`, `unsuspend` (the example of an ignored action is `new_permissions_accepted`). `Job.installed` is False for `deleted`, `removed`, `suspend`. | Q321, Q322 |
| W2 | `webhook/ap12-signature` requests 13, 14 | The edge is 1048576 (a `ping`, 202) and 1048577 (413, `limit` 1048576, no compare). Add a request of 262145 bytes with a good signature: 202 (the old limit is gone). The test agent may add a generated body form to `run.mjs` (for example `body_pad`) so the case does not hold two files of 1 MiB. | Q326 |
| W2 | `webhook/ap12-signature`, new requests | (a) A good signature, event header missing: 400, `queue_sent` `[]`, `timing_safe` 1. (b) The same with an empty header value: 400. (c) No event header and no signature: 401. (d) A body that is not JSON with a bad signature and event `release`: 401 (Q320), `timing_safe` 1. (e) A body that is not JSON with a good signature, event `ping`: 202, no message (requests 15 and 16 use `release` and stay 400). | Q320, Q321 |
| W2 | `webhook/ap12-no-secret` | Add: no signature header and no secret: 500 (the secret comes before the header). Add: a body of 1048577 bytes and no secret: 413 (the static checks come first). | Q327 |
| W2 | `webhook/pu11-events` | Add `installation` `suspend` [100] and `unsuspend` [100]: one message each. Add `installation` `new_permissions_accepted`: 202, no message. | Q322 |
| W2 | `webhook/pu26-app-installed` | Add a repository 700 with 2 rows (`acme/new` active, `acme/old` moved, both `repo_checks` `app_installed` 0). `created` [700]: both rows 1. `removed` [700]: both 0. Add `suspend` [101] (row 1 becomes 0) and `unsuspend` [101] (becomes 1). `next_check_at` stays. | Q322, Q324 |
| W2 | `webhook/pu33-publicized` | Add repository 700 as above. `publicized` 700: `next_check_at` of `acme/new` is the clock, `acme/old` keeps its value; no event, no GitHub read. | Q324 |
| W2 | `pu33-privatized`, `pu35-retry-schedule`, `pu35-dead-letter` | No change (they pin Q325, Q323, Q330). | |
| Frame | `worker/tests/frame.sh` | No change. | Q329 |
| W3 (first deploy, by hand) | Dead letter hand-off | The check of R-PU45 "Edge check": a test Worker, a throwaway queue pair, `max_retries = 1`. Record the result in this file. | Q330 |
| Output (section 6) | 400 detail | Add the proposal `the webhook has no X-GitHub-Event header`. The 413 `limit` is 1048576. | Q321, Q326 |

The revert check (section 5.4): the mutations m6, m10 stay. New mutations to add for these changes: m11 the parse before the signature (request (d) gives 400), m12 the limit 262144 (request of 262145 gives 413), m13 `suspend` ignored, m14 `installation` changes only the first row of a repository id, m15 `publicized` changes a `moved` row.

### 12.3 Changes for 118b (no tests yet)

| Item | Answer | Q |
| --- | --- | --- |
| The release read | `GET /repos/{full_name}/releases/{release_id}` after `GET /repositories/{repository_id}`; a 404 stops the job. | Q328 |
| The `withdrawn` value of `edited` | `edited` | Q332 |
| The conflict | No write. `Log.warn!("index label conflict", { repository_id, release_id, group, version })` (proposal, TW24). | Q333 |
| The fifth read with no asset | Ack and an info log line (`index job no asset`). Not a fault, so not the dead letter queue. The consumer must tell this end from a fault, because the fault at attempt 5 is `retry` with no delay. | Q334 |
| `app_installed` | A `Release` job of a message with `installation_id` of 1 or more sets `app_installed` 1 on the rows of the repository and on a row that it adds. A test: a release event with installation 55 for a name with no row gives a `repo_checks` row with 1 and the interval of 24 h. | Q335 |
| Dependency | Slice 119a is green, so 118b uses `GithubRead.send!` and does not wait. | |

### 12.4 Sources

GitHub docs "Webhook events and payloads": headers `X-GitHub-Event`, `X-GitHub-Delivery`, `X-Hub-Signature-256`; "Payloads are capped at 25 MB"; the actions of `installation` (created, deleted, new_permissions_accepted, suspend, unsuspend), `installation_repositories` (added, removed), `repository` (GitHub Apps do not receive `deleted`; `transferred` only goes to the new owner); `release` `edited` has `changes`. Cloudflare Queues docs: `retry({ delaySeconds })`, `max_retries` (default 3), delay up to 24 h, a message at the retry limit goes to the dead letter queue (deleted when there is none), a dead letter queue with no consumer keeps messages 4 days. Sizes: `GET /repos/{owner}/{repo}/releases` of `roc-lang/basic-cli`, `roc-lang/roc`, `BurntSushi/ripgrep`, `cli/cli`, 2026-11-02.
