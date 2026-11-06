# 119 Reconcile cron (split: 119b first, then 119c)

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code of 119b: Opus medium (PLAN row 119). The token comes from slice 119a (green). The P2 check of R-PU25 passed (`research/github-app-check/RESULT.md`).

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-119-revert/` (the private reference and the mutants).

## 0. Split

| Part | What | Size (private reference) | State |
| --- | --- | --- | --- |
| 119b (first) | The cron, the claim with `RETURNING`, the visibility read by id, the list read with `If-None-Match`, 304, the list work (withdraw `deleted` and `prereleased`, the asset check, the clear), the new candidates to the index queue, one batch for each row with the etag, the backoff, the log line, the rate limit reserve, the index job `Poll` with the provenance `poll` | About 90 lines of `lib/Reconcile.roc`, 150 lines of `ReconcileCron.roc`, 15 lines changed in `IndexQueue.roc`, 1 line in `lib/Webhook.roc` | Green (section 12), revert check section 14 |
| 119c (after the answers of Q376, Q378 to Q380) | The identity part of the reconcile: the clear of `repo-missing` (R-PU24, after the binding check), the state `found` (R-TP11), a rename found by the `full_name` of the read by id (R-TP10, R-TP18 note), a transfer (R-TP9 row 2), the etag of the visibility read (Q371) | About 60 lines of `lib/Reconcile.roc`, 120 lines of `ReconcileCron.roc`, 2 lines of `IndexQueue.roc` | Tests red, stubs (section 13) |

Reason: 119b has the whole frame of the cron and the list, and is about 260 lines (TW19). The identity part reuses `Identity` (slice 113) and has 4 open questions. 119b never clears `repo-missing` and never changes a `repos` row except the `missing` withdraw (the same statements as the job `Privatized`), so it is safe to deploy before 119c.

## 1. Rules (119b)

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-PU21 | A reconcile reads each indexed repository again; the work is that of an ingest; the provenance is `poll` (via 2) | W2 `pu21-poll-job`, `pu23-list`, `pu37-etag-effects`. W0 `message_of` |
| R-PU22 | The interval: 1 h, 24 h with the App | W0 `next_check`. W2 `pu23-list` (`acme/lib` 24 h, the others 1 h) |
| R-PU23 | Every 5 min, the due rows (at or before now), the oldest first, at most 500; 1 + R D1 calls; the list with `If-None-Match`; 304 changes only `checked_at`, `next_check_at`; 200 stores the etag; new candidates to the index job; not in the list (or a draft again): `deleted`; a prerelease: `prereleased`; then `checked_at` = now and the interval | W0 `claim_sql`, `list_url`, `parse_list`, `list_outcome`, `list_work`. W2 all `reconcile/` cases (the D1 calls of each run are pinned) |
| R-PU24 | 404 or not public: `repo-missing` on each release with no value, the state `missing`. (The clear of `repo-missing`: 119c) | W2 `pu23-list` (`acme/gone`, `acme/priv`) |
| R-PU25 | The installation token (119a) for each read; the reserve: under 10 % of the limit, the rest of the batch moves to the reset time | W0 `reserve`. W2 `pu25-reserve`, `auth.log` of `pu23-list` |
| R-PU27 | Only `github.com`: every `repo_checks` row is a GitHub name (R-PU40), the list call is on `api.github.com` | W0 `list_url`. W2 `pu23-list` |
| R-PU31, R-PU33 | The visibility read `GET /repositories/{id}` before the list | W2 `pu23-list` |
| R-PU35 | The work comes from the state of D1: a row that is not due is not read | W2 `pu23-list` (`acme/later`), `pu37-backoff` |
| R-PU36 | 2 runs at once, and 1 planned time 2 times: each repository is read once | W2 `pu36-overlap`, `pu23-list` run 2 |
| R-PU37 row 1 | The claim: ONE statement, `next_check_at` = now + 15 min, `RETURNING` | W0 `claim_sql`. W2 `pu36-overlap` |
| R-PU37 row 2 | One failed row does not stop the run; the outcome is ok | W2 `pu37-backoff` |
| R-PU37 row 3 | `fail_count` + 1, now + min(interval, 5 min x 2^(n-1)); 0 after a pass | W0 `next_check`. W2 `pu37-backoff` (5 min, 10 min, the cap at 1 h, 0 after a pass) |
| R-PU37 row 4 | One log line for each failed row, with the job, the repository id, `fail_count`, the error kind, no name | W2 `pu37-backoff`, `pu37-etag-effects` (`expect/logs.jsonl`) |
| R-PU37 row 5 | The etag and the effects in one batch; the send first; a failed send or batch stores no etag | W2 `pu37-etag-effects` |
| R-PU17, R-PU19, R-PU20, Design Q339 | The values of the list; a row with a value keeps it; `asset-replaced`; the clear of a candidate | W0 `list_work`. W2 `pu23-list` |
| R-PU13, R-PU14, R-PU15 | The job `Poll`: the job `Release` with via 2; a message 2 times writes nothing new | W2 `pu21-poll-job`. W0 `message_of` (with `Webhook.job_of`) |
| R-RE14 | The columns `etag`, `checked_at`, `next_check_at`, `fail_count`, `app_installed` | W2 `db.tsv` of each case |

## 2. Files

| File | Who | What |
| --- | --- | --- |
| `worker/lib/Reconcile.roc` | Test agent (signatures, constants), code agent (bodies) | New. 8 stubs. The doc comment of each stub is the rule |
| `worker/ReconcileCron.roc` | Test agent (signature, the flow in the head comment), code agent (body) | New. `run! : Worker.Scheduled => Try({}, [Fault(Str)])` |
| `worker/lib/Webhook.roc` | Test agent (the type), code agent (`job_of`) | `Job` has a new tag `Poll({ repository_id, release_id })`. `job_of` must give it for (`poll`, `published`) |
| `worker/IndexQueue.roc` | Test agent (the arm and the stub), code agent (body) | `job!` has the arm `Poll(p) => poll!(p, attempts)`; `poll!` is `crash "todo"`. The code agent threads `via` (1 or 2) through `release!`, `release_work!` and `index_label!` (3 places use 1 today: `label_sql_of(1)`, the `AddProvenance` statement, `via: 1` of the flow) |
| `worker/main.roc` | Test agent | Done: `import lib.Reconcile`, `import ReconcileCron`, `Worker.cron(Reconcile.cron, ReconcileCron.run!)` |
| `worker/lib/main.roc`, `worker/wrangler.toml`, `worker/tests/unit/w0.roc` | Test agent | Done: exposes `Reconcile`; `crons = ["0 3 * * *", "*/5 * * * *"]`; `import ReconcileTest` |
| `worker/tests/run.mjs`, `worker/tests/worker-test.js` | Test agent | Done (section 4) |
| `worker/tests/tools/mk-reconcile.mjs`, `worker/tests/cases/reconcile/*`, `worker/tests/unit/ReconcileTest.roc` | Test agent | Done (section 5) |

No SQL file changes, so no W1 case: the claim is a string of `Reconcile` (as `Daily`). W0 pins its key words, W2 pins what it does on local D1. The code agent writes no route and no `Route.Id`.

## 3. Hints for the code agent

| Point | Hint |
| --- | --- |
| The claim | `UPDATE repo_checks SET next_check_at = ?1 + 900000 WHERE repo IN (SELECT repo FROM repo_checks WHERE next_check_at <= ?1 ORDER BY next_check_at, repo LIMIT ?2) RETURNING ...`. SQLite allows correlated subqueries with `json_group_array` in `RETURNING` (checked on `node:sqlite`, `research/slice-119/claim-probe.mjs` is a public probe of the form, no reference code). So the releases of the repository come back in the same call, and the run makes 1 + R D1 calls. Use `COALESCE` for a NULL `tag` or `withdrawn` (the derived JSON reader does not read `null`) |
| The order of the rows | `RETURNING` gives the rows in rowid order, not in the order of the subquery. Q370. Sort the rows by `repo` as a signed 64-bit integer (the W2 cases hold for this order and for the oldest first) |
| `etag` | Store and send the `ETag` header text as it came (`W/"..."`). A row with no etag sends no `If-None-Match` (the fake checks that the header is absent) |
| A NULL value | `Sql.or_null(try)` binds NULL (an answer with no `ETag`) |
| The reserve | `Response.header(res, "x-ratelimit-remaining")` and so on. The move is ONE statement for all rows that were not started (for example `WHERE repo IN (SELECT CAST(value AS INTEGER) FROM json_each(?2))` with the ids as a JSON text list). Use `Str.join_with(list, sep)` (the function form; the method form crashes on this compiler) |
| The withdraw | The 3 statements of `IndexQueue.withdraw!` and the pass update in ONE batch. A helper that both use is allowed (do not change what the job `Privatized` writes) |
| A clear | Guard it by state, for example `WHERE log_index = ?1 AND withdrawn IS NOT NULL AND withdrawn <> 'repo-missing'` (R-PU36: a webhook can write the row during the run) |
| The poll job | `poll!` is `release!` with `{ action: "published", installation_id: 0, .. }` and via 2. A webhook job keeps via 1: the cases of `webhook/` must stay green |
| The clock | `Time.now_ms!()` once at the start of the run (Design Q345) |
| D1 calls | The W2 cases count the D1 calls of each run: 1 claim, then 1 batch for each row (a row whose batch fails makes 1 more for its failure update), then 1 for the reserve move |

## 4. Runner changes (done by the test agent)

| File | Change |
| --- | --- |
| `run.mjs` | A `github/<file>.meta.json` with status 304 (or 204) gives an answer with no body (a JS `Response` refuses a body for these). In `require`, the value `null` means that the header must be absent. A cron line can have `"copies": N` (N runs at the same time, R-PU36). After the run(s) of a cron line, the runner reads `/__test/stats` from the test entry: `expect/d1-calls` and `queue_sent` of a cron line now check the D1 calls and the queue sends of the run(s) (for `copies`, the sum of the calls, and the sends in any order). The old cron cases have `-` in `d1-calls` and no `queue_sent`, so they do not change |
| `worker-test.js` | `/__test/stats` gives the D1 calls and the sends since the last request. The setting `TEST_INDEX_FAIL_SENDS` ("N") makes the first N sends of the isolate to `INDEX` fail (rejected, not recorded) |

Copies of the files before the change: `research/slice-119-revert/before/`.

## 5. Tests

| Layer | Test | What it pins | Rules |
| --- | --- | --- | --- |
| W0 | `ReconcileTest` 1 | The constants (`*/5 * * * *`, 500, 900000, 300000) and the claim key words: one statement, `UPDATE repo_checks`, `next_check_at = ?1 + 900000`, `next_check_at <= ?1`, `ORDER BY next_check_at`, `LIMIT ?2`, `RETURNING`, `CAST(repo AS TEXT)`, `json_group_array`, the columns | R-PU23, R-PU35, R-PU36, R-PU37, R-RE14 |
| W0 | 2 `next_check` | 14 vectors: 0 is the interval; 5, 10, 20, 40 min; the cap at 1 h and 24 h; 1280 min (n = 9) under 24 h; n = 4,000,000,000 does not overflow | R-PU37 row 3, R-PU22 |
| W0 | 3 `list_url` | The full name as GitHub gave it (`Acme/Lib`), `per_page=100` | R-PU23, R-PU27, R-TP10 |
| W0 | 4 `parse_list` | A realistic array (nulls, nested objects, a draft with `published_at` null, the order kept), `[]`, 9 bad texts (one bad item fails the whole list) | R-PU23, R-PU37 row 2 |
| W0 | 5 `list_outcome` | 304, 200 with and with no etag, a bad body, 500, 404, 403 (the texts of section 6) | R-PU23, R-PU37 |
| W0 | 6, 7 `list_work` | 11 rows and 15 list items: `prereleased`, `deleted` (absent, a draft again, a row of another name), `asset-replaced` (another hash), the clear of `unpublished`, `repo-missing` kept, a row with a value kept (Q339), `TooMany` does not clear; candidates only for a final release with exactly one package asset, a version tag, a tag of no row, in the list order (`.intoto.jsonl` and `docs.tar.gz` are not packages). Also: no rows; an empty list; a label released again with another hash | R-PU23, R-PU17, R-PU19, R-PU20, R-PU6, R-PU14 |
| W0 | 8 `reserve` | 499 of 5000 (under), 500 (exactly 10 %: go on), 4999, missing and bad headers | R-PU25 |
| W0 | 9 `message_of`, `Webhook.job_of` | The message form (TW24) and its job `Poll`; another action or event is `Unknown` | R-PU23, R-PU21, R-PU13 |
| W2 | `reconcile/pu23-list` | 4 due rows and 1 row due 1 ms later. 304 with the stored etag; 200 with no etag sent: the new etag, `prereleased`, `deleted` (absent, a draft again, the release of the moved old name), `asset-replaced`, the clear of `unpublished`, `repo-missing` and `deleted` kept; ONE message (8.0.0); 404 and private: `missing`, the event, `repo-missing`. 24 h with the App. The token on each read (`auth.log`). Run 2 at the same planned time: no row, no read, 1 D1 call | R-PU21 to R-PU25, R-PU27, R-PU31, R-PU33, R-PU35, R-PU36, R-PU37, R-PU17, R-PU19, R-PU20, R-RE14, R-TP11 |
| W2 | `reconcile/pu37-backoff` | 3 runs. The oldest row fails (list 500), the run goes on; a 304 for a row with `fail_count` 2 gives 0 and the interval (Q374); a failed visibility read (502); the cap at 1 h for `fail_count` 5; 5 min, then 10 min; 0 and the interval after a pass; `checked_at` stays on a failure; the log lines | R-PU37 rows 2 to 4, R-PU23, R-PU22, R-PU35 |
| W2 | `reconcile/pu37-etag-effects` | A failed send: nothing of the list is written, the old etag stays (it is sent again in run 2); a failed batch (a trigger): rolled back, no etag; run 2 writes the message, `deleted` and the etag | R-PU37 row 5, R-PU23, R-PU13, R-PU36 |
| W2 | `reconcile/pu36-overlap` | 2 runs at once: each repository read once, 2 claims + 3 batches; then the same time again | R-PU36, R-PU37 row 1, R-PU35 |
| W2 | `reconcile/pu25-reserve` | The VISIBILITY answer of the first row has 499 of 5000 (Q377): the row still reads its list and stores its etag, then the 2 other rows move to the reset time, keep `fail_count`, and are not read; one log line | R-PU25, R-PU23 |
| W2 | `reconcile/pu21-poll-job` | 3 queue lines: the poll message of a release that an ingest indexed (only the provenance row via 2), the same message again (nothing), a new candidate (the shared flow with via 2) | R-PU21, R-PU15, R-PU13, R-PU14, R-RE9 |

The case files are made by `worker/tests/tools/mk-reconcile.mjs`.

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`ReconcileTest`) | 9 `expect`s, 0 pass, all `todo`. 0 compiler errors. `roc check worker/main.roc`: no errors. `roc fmt --check`: pass |
| W2 `reconcile/` (`scripts/test.sh wbuild w2`, `--opt=speed`) | 0 of 6 pass. The 5 cron cases: status 500, outcome `exception`, Worker log `scheduled: trap: todo`, the DB unchanged. `pu21-poll-job`: each message is retried after 60 s (`job_of` gives `Unknown`), no provenance row |
| `wbuild` | pass (`roc-cfw sync --check` accepts the second cron) |
| Old W2 | 171 pass. 1 other failure: `webhook/pu13-identity-changed`, a new case of the slice 118b agent (`the setting ISSUES_URL is missing`), not this slice |

### 5.2 Private reference and mutants

Section 10.

## 6. Output (proposals, TW24)

| Item | Proposal |
| --- | --- |
| The cron expression | `*/5 * * * *` (`Reconcile.cron`, `wrangler.toml`) |
| The message of a candidate | `{ event: "poll", action: "published", installation_id: 0, repository_id, release_id, repository_ids: [] }` |
| The log line of a failed row | `Log.warn!("reconcile row failed", { job: "reconcile", repository_id, fail_count, error })`. `repository_id` is the GitHub id (no name, no names id). `error` is a short text, not pinned |
| The texts of `list_outcome` | `the release list read answered status <n>`, `the release list is not valid`, `the release list has more than one page` (Q372) |
| The log line of the reserve | `Log.warn!("reconcile rate reserve", { reset_ms, moved })` |
| The log line of a failed claim | `Log.warn!("reconcile claim failed", { error })`, the run is `Ok` (as Q344) |
| The answer of a run | `Ok({})`: Miniflare gives `{"outcome":"ok"}`, status 200 |

## 7. Questions (TW17)

The tests of 119b do not depend on an answer: each case is made so that the proposal and the other reading give the same result, or the case does not touch the point. The code agent follows the proposal or the "until answered" line.

| Id | Question | Proposal | Until answered |
| --- | --- | --- | --- |
| Q370 | R-PU23 says "oldest first" and R-PU37 row 1 says one statement with `RETURNING`. SQLite gives the rows of `RETURNING` in rowid order and only with the new values, so the run cannot know the old order. In which order does the run handle its rows (it matters for the reserve: "the rest of the batch")? | The claim selects the oldest 500 (the subquery). The run handles them in the order of `repo` (the names id as a signed integer). Other option: a batch of a `SELECT ... ORDER BY` and the `UPDATE` (still 1 D1 call, but 2 statements) | Order of `repo`. The W2 cases give `next_check_at` in the order of the ids |
| Q371 | R-PU31 says the reconcile sends `If-None-Match` on `GET /repositories/{id}` and "a 304 keeps the last result". `repo_checks` has one `etag` column (R-RE14), and it is the etag of the list (R-PU23). What holds the etag and the last result of the visibility read? | A new column `repo_checks.repo_etag` (no Worker is deployed, so `sql/0001_init.sql` can change). A 304 means "public, with the `full_name` of the last read": the name of the `repos` row. Without the column, the visibility read costs 1 counted request for each row and check (1,000 an hour for 1,000 repositories without the App; under 5,000) | No `If-None-Match` on the visibility read. Slice 119c |
| Q372 | CLI R-DI2 follows `Link: rel="next"`. A repository with more than 100 releases has more pages. R-PU23 stores one etag, and a 304 for page 1 does not show a change on page 2 (a deleted old release). A release on page 2 that is not read looks deleted | Read every page; the etag of page 1 is the etag of the row; a 304 for page 1 ends the read. A deleted release on a later page is found when page 1 changes (or: no etag for a row with more than one page) | `list_outcome` gives `Failed("the release list has more than one page")`: the row fails, nothing is written, the backoff applies. No test |
| Q373 | R-PU21: "the work is the same as an ingest ... The provenance is `poll`". An ingest adds its provenance row to a label that another path indexed with the same hash (`AddProvenance`). Does the reconcile add a `poll` row to each listed release that is indexed already (in the batch of the row), or only to new candidates (through the job)? | Only new candidates. A `poll` row on every listed release adds no fact (the label is in the log already), and it is a write for each release at each 200 | Only new candidates. No test reads the provenance of an old release after a run |
| Q374 | R-PU23: a 304 "changes only `checked_at` and `next_check_at`". R-PU37 row 3: "a row that passes gets `fail_count` = 0". A row with `fail_count` 2 gets a 304: does `fail_count` go to 0? | Yes: a 304 is a pass, and `next_check_at` uses the interval (`next_check(now, interval, 0)`) | 0. No test has a 304 for a row with `fail_count` above 0 |
| Q375 | A `moved` row (R-TP11) has its own `repo_checks` row and comes due. The check of the current name does the work of every name of the repository (Design Q324). What does the claim of a `moved` row do? | The same work as any row (it reads by id and lists the current name; the writes are guarded, so a second check of the same repository changes nothing). Other option: no read, only `next_check_at` + interval | As any row (harmless). No test claims a `moved` row |
| Q376 | After R-PU24 (`repo-missing`), the etag of the list stays. When the repository is public again with the same releases, the list gives 304, and `repo-missing` is never cleared | The withdraw batch sets `etag` to NULL, so the next public read gets 200 and 119c can clear | 119b does not change `etag` in the withdraw batch. Slice 119c |
| Q377 | R-PU25: "moves `next_check_at` of the rest of the batch". Does the reserve of the visibility read stop the list read of the same row? | The row that saw the reserve ends (its list read too), then the rest moves | As the proposal. The test has the reserve only on the last read of a row |

## 8. Out of scope (119b)

| Item | Reason |
| --- | --- |
| The clear of `repo-missing`, `found`, a rename, a transfer (R-PU24 second half, R-TP9 to R-TP11, R-TP18 note) | Slice 119c |
| The 30 s CPU limit of a cron and 500 rows (RN17) | W3 |
| The token itself | Slice 119a |
| A real GitHub call | W3, with the user |
| Pages of the list | Q372 |

## 9. Slice 119c (scope only)

| Part | Rule | Open |
| --- | --- | --- |
| A `missing` row whose read by id is public again: state `active`, event `found` (R-TP11) | R-TP11, R-TP19 | Q378: does the reconcile write `found` itself (the ingest does it in R-TP19 row "Found"), in the batch of the row? |
| The clear of `repo-missing` after "the binding of section 7.1 allows it" (R-PU24) | R-PU24, R-PU17 | Q379: what is the binding check here: R-TP9 with the ids of the read by id against the `repos` row (the same `repository_id` is given by the read, so only the owner id can differ)? Is a transfer (row 2) a pass? |
| A rename found by the read by id: the `full_name` is not the name of the row (R-TP10, the note of R-TP18: "the path that reads by id ... sets the old row `moved`") | R-TP10, R-TP13, R-TP18 | Q380: the new name gets a `repos` row and a `repo_checks` row (R-PU26) in the batch of the row, with the events `rename`, as R-TP18 row 1? |
| The etag of the visibility read | R-PU31 | Q371 |
| The etag after `repo-missing` | R-PU24 | Q376 |

## 10. Private reference and revert check

`research/slice-119-revert/reference/` (the 4 files of section 2) and `ref.sh [w0|w2|all] [filter]` (`NOREF=1`: the stubs; `MUTATE=mutations/<m>.py`; `KEEP=1` reuses the build; `--opt=speed`). With the reference: W0 `ReconcileTest` 9 of 9 and `WebhookTest` 17 of 17; W2 `reconcile/` 6 of 6; `webhook/` and `cron/` unchanged (22 pass; the 1 failure is `webhook/pu13-identity-changed` of the 118b agent, as with the stubs).

| Mutant | What | Caught by |
| --- | --- | --- |
| m1 | The batch with the etag is written before the send (R-PU37 row 5 "Store the etag first") | W2 `pu37-etag-effects` (and `pu23-list`, `pu25-reserve`, `pu37-backoff` by the D1 call count) |
| m2 | The claim does not move `next_check_at` (a select with no claim) | W0 `claim_sql`; W2 `pu36-overlap` (8 D1 calls, every repository read 2 times, 2 tokens) |
| m3 | No cap of the backoff at the interval | W0 `next_check`; W2 `pu37-backoff` (`fail_count` 5 gives 80 min, not 1 h) |
| m4 | The run stops at the first failed row | W2 `pu37-backoff`, `pu37-etag-effects` |
| m5 | A draft in the list is kept as a final release that is not a candidate (no `deleted`) | W0 `list_work`; W2 `pu23-list` (4.0.0) |
| m6 | The reserve at exactly 10 % (`<=`) | W0 `reserve` only (the W2 case has 499) |
| m7 | The poll job writes via 1 (webhook) in place of 2 (poll) | W2 `pu21-poll-job` |
| m8 | A tag that is indexed with another hash is a candidate (a message for a conflict) | W0 `list_work` (2 expects); W2 `pu23-list` (`queue_sent` has 5.0.0 too) |
| m10 | A reserve on the visibility read ends the row before its list read (the reading that Q377 rejects) | W2 `pu25-reserve` |
| m9 | The claim gives only the releases of the claimed name, not of every name of the repository id | W2 `pu23-list` (0.9.0 of the moved name `acme/lib-old` is not `deleted`) |

All 10 are caught. After the answers of section 11 (2026-11-02): `pu25-reserve` puts the reserve on the visibility read (Q377), `pu37-backoff` seeds `fail_count` 2 on the 304 row (Q374); the reference passes again, m10 is new, m4 and m6 were run again. Logs: `research/slice-119-revert/mut-*.log`.

Runner note: under load, 2 `dispatchFetch` calls of `/cdn-cgi/local/scheduled` at once gave a runner fault ("Body has already been read"). A cron line with `copies` now goes through `worker.scheduled()` of Miniflare (the outcome, no body). 10 runs of `reconcile/` at the same time: all pass.

## 11. Design answers (2026-11-02)

The design agent answered Q370 to Q380. The entries are in `DESIGN.md` (Q370 to Q380), and the rule text is in `DESIGN-REGISTRY.md` (R-PU21, R-PU23, R-PU24, R-PU25, R-PU31, R-PU33, R-PU37 row 1, R-RE14, the cost table, the note of R-TP18). The code agent of 119b follows the "119b" rows. The "119c" rows are the scope of 119c, together with section 9.

| Id | Answer | Part | Test change |
| --- | --- | --- | --- |
| Q370 | The proposal: the claim selects the oldest 500, and the run handles them in the order of `repo` as a signed 64-bit integer (R-PU37 row 1) | 119b | No test change |
| Q371 | A new column `repo_checks.repo_etag`. The pass batch stores it only for a public read whose `full_name` in lower case is the name of the row, else NULL. A failed row keeps it. A 304 means public, the same name, the same ids. No header when it is NULL. A `moved` row never stores it (R-PU31, R-RE14) | 119c | 119c: the column in `sql/0001_init.sql` (and the W1 schema check, if one lists the columns). A W2 case: a stored `repo_etag` is sent as `if-none-match` on `/repositories/{id}`, a 304 gives the list read of the row name, a 200 public stores the new value, a `moved` row and a non-public read store NULL. 119b: no test change (its fake GitHub does not require the header) |
| Q372 | Read each page (`&page=<n>`, the Worker makes the URL, not from `Link`), at most 10 pages, else the row fails (`the release list has more than 10 pages`). A row with more than one page stores `etag` NULL. Ids that come 2 times are kept once (R-PU23) | 119c | 119c: W0 `list_outcome` (or a new function) for a `Link` with `rel="next"`; W2 cases: a list of 2 pages (no `if-none-match`, `etag` NULL, a release on page 2 not `deleted`), and a list of 11 pages (the row fails). 119b: no test change (the "until answered" stays) |
| Q373 | The proposal: only new candidates get the `poll` row, through the job. An indexed release gets no provenance row from the reconcile (R-PU21) | 119b | No test change |
| Q374 | Yes: a 304 is a pass, `fail_count` = 0 and the interval (R-PU23) | 119b | No test change. Optional: a 304 vector for a row with `fail_count` 2 in `pu37-backoff` |
| Q375 | The proposal: a `moved` row is checked as any row (R-PU23) | 119b | No test change |
| Q376 | Each write of `repo-missing` (the reconcile withdraw and the job `privatized`) also sets `etag` and `repo_etag` to NULL on each `repo_checks` row of the repository id, in the same batch (R-PU24, R-PU33) | 119c | 119c: a W2 case: `repo-missing`, then public again with the same list: the list read has no `if-none-match`, a 200, the clear. A seed with a stored `etag` in a `privatized` case (all webhook seeds have `etag` NULL today, so no old case changes). 119b: the withdraw batch does not change `etag` |
| Q377 | No: the row that gets an answer under the reserve does all its work (its list read and pages too), then the run moves the rows that it did not start and stops (R-PU25). This changes the proposal: the step c of the head comment of `ReconcileCron.roc` means "the row ends" after its last read | 119b | No test change (`pu25-reserve` has the reserve on the last read of a row, so both readings give the same result) |
| Q378 | Yes, R-TP11 gives it: a public read by id sets a `missing` row of the current name `active`, event `found`, in the batch of the row, guarded by state, after R-TP9 and before the clear (R-PU24) | 119c | 119c: a W2 case (`missing` row, public read: `active`, one `found` event, the clear of `repo-missing`; a second run adds no event) |
| Q379 | R-TP9 with the ids of the read by id against the claimed row. Only rows 1 and 2 can apply, and both accept. A transfer writes the new owner id and the event `transfer`, then the clear goes on (R-PU24) | 119c | 119c: a W2 case with another `owner.id` in the read by id (`transfer` event, new owner id, the clear) |
| Q380 | Yes: the identity rows of an ingest of `F` (R-TP18 rows 1, 3, 4 with `U` = `F`), with the `repo_checks` row of `F` (`app_installed` of the claimed row), in the batch of the row, with the SQL guards of slice 113. A row of `F` with another id gets no write (R-TP18 note) | 119c | 119c: W2 cases for a rename (row 1: new `repos` and `repo_checks` rows, `moved`, 2 `rename` events) and for the old name again (row 3) |
| Q381 | Not the proposal: the claimed row gets R-TP9 row 2 (new owner id, `transfer`) and then `moved` (`rename`); a new row of F gets the ids of the read and `rename` only; a row of F that exists gets R-TP9 with its own ids (R-TP18 note, R-TP19 "Order") | 119c | 119c: a W2 case (or a row in `tp18-rename`) with a rename and another owner id: the claimed row has the new owner id and the events `transfer` then `rename` (the `seq`), F has the ids of the read and one `rename`; a second run adds no event |
| Q381 (2026-11-03) | The test agent's reading of 16.1 is right: when the row of F has another `repository_id`, the claimed row still gets R-TP9 row 2 (new owner id, `transfer`), but it does not become `moved` and F gets no write. The code choice of 15.3 (no transfer then) must change: remove the `NOT EXISTS (... repo = F AND repository_id <> id)` guard from the transfer of the claimed row | 119c | 119c: a row in `tp18-rename` with another owner id in the read and a row of F of another id: the claimed row has the new owner id and one `transfer`, it stays `active`, F does not change. Also add a row for a `moved` claimed row whose read gives its own name (R-TP18 row 3: `active` again, the other row `moved`, 2 `rename` events, `repo_etag` stored); it is a real case (a rename back) and no test pins it |

Open after these answers: none for 119b. 119c has no open question.

## 12. Code (119b, code agent, 2026-11-02)

No test, fixture or runner file was changed. No dispute.

### 12.1 Files

| File | Change | Lines |
| --- | --- | --- |
| `worker/lib/Reconcile.roc` | The 8 bodies, and 2 helpers: `state_of` (the state of a row from its list item, for `Webhook.row_changes`) and `indexed_of` (the JSON of the column `releases` of the claim) | 98 to 199 (about 100 new) |
| `worker/ReconcileCron.roc` | `run!` and its steps: `rows!` (the loop and the stop), `move!` (the reserve), `row!` (the failure update and log line), `check!` (the visibility read), `list!` (the list read, the send, the batch), the pure helpers `by_repo`, `pass`, `change_stmt`, `reserve_of`, `either` | 31 to 200 (about 170 new) |
| `worker/IndexQueue.roc` | `poll!` (1 line). `via` threaded through `release!`, `release_work!`, `index_label!` (the label SQL, the `AddProvenance` statement with `?3`, the flow). `withdraw_stmts` (the 3 statements of `withdraw!`, used by `withdraw!` and the reconcile; what the job `Privatized` writes does not change) | about 20 changed |
| `worker/lib/Webhook.roc` | `job_of`: the arm (`poll`, `published`) gives `Poll` | 1 |

### 12.2 Green results

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | pass (433 `expect`s of `w0.roc`, with the 9 of `ReconcileTest`; frame, fmt, records) |
| `node sql/tests/run.mjs` | 53 passed, 0 failed |
| `scripts/test.sh wbuild w2` (`--opt=speed`) | pass. Direct run of `run.mjs` with the same build: 178 passed, 0 failed. `reconcile/` 6 of 6; `webhook/`, `cron/`, `account/` 37 of 37 (also `webhook/pu13-identity-changed`) |
| `scripts/test.sh check fmt w1` | pass |
| Time | `wbuild` 121 s (budget 90), `w2` 57 s (budget 45): over the TW20 budget, as before this slice |

### 12.3 Revert check (W0 only, 5 mutations of `lib/Reconcile.roc`)

| Mutation | Result |
| --- | --- |
| The reserve at exactly 10 % (`<=`) | Caught by `ReconcileTest` 8 |
| No cap of the backoff at the interval | Caught by `ReconcileTest` 2 |
| A draft in the list is a final release (no `deleted`) | Caught by `ReconcileTest` 6 |
| A tag that is indexed is a candidate | Caught by `ReconcileTest` 6 and 7 |
| `Link` with `rel="next"` is ignored | Not caught. Expected: Q372 says "No test" for 119b (119c adds the pages) |

The file is the same as before the mutations (`cmp`). The W2 mutants of the test agent are in section 10.

### 12.4 Choices that the design does not give

| Choice | Other options |
| --- | --- |
| The claim gives `etag` as `COALESCE(etag, '')`; an empty text is "no etag" (no `If-None-Match`). A GitHub `ETag` is never empty | `Try(Str, [Missing])` for NULL |
| The releases of the claim are in the order of `log_index` (a subquery with `ORDER BY` inside `json_group_array`), so the order of the change statements is fixed | No order |
| A claimed row with no `repos` row (no `repository_id`) fails with the error `the row has no repository id` (the backoff applies, the log line has `repository_id` 0) | Skip the row with no write |
| The 2 reserves of a row (visibility read and list read): the later reset time is used | The first one, or the last one |
| A reserve on the last claimed row: no move statement (no D1 call), but the log line `reconcile rate reserve` with `moved: 0` | No log line |
| A failed move statement: the log line `reconcile rate reserve move failed` with `error`; the run still stops | No line |
| A failed failure update (the second batch of a row): no other log line (the row line is written) | A second line |
| `fail_count` + 1 is capped at the highest U32 | Wrap |
| A clear of the reconcile is guarded: `WHERE log_index = ?1 AND withdrawn IS NOT NULL AND withdrawn <> 'repo-missing'` (section 3). The clear of the webhook job does not change | One shared statement |
| The batches of the cron use `db.batch!` with no session (as `DailyCrons`): D1 sends a write with no session to the primary | `with_session!(Primary)` |
| The error texts of a failed row other than section 6 (`the repository read failed: ..`, `the release list read failed: ..`, `the send of the candidates failed: ..`, `the indexed releases of the claim are not valid`, a D1 error as `Str.inspect`) | Not pinned (TW24 proposals) |

## 13. Slice 119c (tests, test agent, 2026-11-02)

Scope: section 9 with the answers of section 11 (Q371, Q372, Q376, Q378 to Q380). Status: tests red, stubs. Copies of the touched files before 119c: `research/slice-119-revert/before-119c/`.

### 13.1 Files

| File | Who | What |
| --- | --- | --- |
| `sql/0001_init.sql` | Test agent (done) | `repo_checks.repo_etag TEXT`, the last column (Q371, R-RE14) |
| `sql/tests/cases/schema/s1-tables/expect.tsv`, `sql/tests/cases/closure/c2-closure-cte/setup.sql` | Test agent (done) | 7 columns of `repo_checks`. W1: 53 of 53 pass |
| `worker/lib/Reconcile.roc` | Test agent (docs, stubs), code agent (bodies) | `claim_sql` also gives `repo_etag`, the name of the row, `repository_owner_id` and `state`. `list_outcome` ignores `Link` (Q372). `list_work` also clears `repo-missing` (R-PU24, Q379). New stubs: `max_pages`, `has_next`, `page_url`, `merge_pages`, `repo_etag_of` |
| `worker/ReconcileCron.roc` | Test agent (head comment, section "119c"), code agent (body) | `If-None-Match` with `repo_etag`; a 304 lists the row name; the identity steps (R-TP9 row 2, found, R-TP18 rows 1, 3, 4 with U = F); the pages; the clear guarded by the value that the claim saw |
| `worker/IndexQueue.roc` | Test agent (doc), code agent (body) | `withdraw_stmts` also sets `etag` and `repo_etag` to NULL on every `repo_checks` row of the repository id (Q376). The job `Privatized` uses it, so it gets this too |
| `worker/tests/unit/ReconcileTest.roc`, `worker/tests/tools/mk-reconcile.mjs`, `worker/tests/cases/reconcile/*` | Test agent (done) | Section 13.2 |

No runner change. The code agent writes no route.

### 13.2 Tests

| Layer | Test | What it pins | Rules |
| --- | --- | --- | --- |
| W1 | `schema/s1-tables` | `repo_checks` has 7 columns, with `repo_etag` | R-RE14 |
| W0 | `ReconcileTest` 6 (changed) | `list_work` now clears `repo-missing` of a listed release (`clear(7)`) | R-PU24, Q379 |
| W0 | `ReconcileTest` 10 | The claim also gives `repo_etag`, the row name, `repository_owner_id`, `state` | R-PU31, R-RE14, Q371, Q378 to Q380 |
| W0 | `ReconcileTest` 11 | `has_next` (`rel="next"` of `Link`; the last page has no next), `max_pages` = 10 | R-PU23, Q372 |
| W0 | `ReconcileTest` 12 | `page_url` (page 1 is `list_url`, page n adds `&page=n`), `merge_pages` (the first of each id), `list_outcome` with a next link is `Changed` | R-PU23, Q372 |
| W0 | `ReconcileTest` 13 | `repo_etag_of`: only a public read of the row name (case ignored); a rename, not public, no `ETag`: NULL | R-PU31, R-RE14, Q371 |
| W2 | `reconcile/pu23-list` (changed) | 7.0.0 of the list had `repo-missing`: it is cleared now | R-PU24 |
| W2 | `reconcile/pu31-repo-etag` | A stored `repo_etag` is sent; 304 gives the list of the row name and keeps both etags; a 200 public stores it (the case of the name is ignored); a `moved` row stores NULL; a private 200 nulls both etags | R-PU31, R-RE14, R-PU24, R-PU33, Q371, Q376 |
| W2 | `reconcile/pu24-missing-again` | 3 runs and 1 queue job. 404: both etags NULL on both rows of the id; the job `privatized` nulls too; public again: no `If-None-Match`, `found`, the clear of 1.0.0 and of 0.9.0 of the moved name, 2.0.0 (not listed) keeps `repo-missing`; then 304 and 304, no second `found` | R-PU24, R-PU33, R-TP11, R-TP19, Q376, Q378 |
| W2 | `reconcile/tp9-transfer` | Another owner id in the read by id: event `transfer` (seq 2), the new owner id, then `found` (seq 3), then the clear | R-TP9, R-TP11, R-TP19, R-PU24, Q379 |
| W2 | `reconcile/tp18-rename` | Row 1 (F has no row): the row and the `repo_checks` row of F (`app_installed` of the claimed row, now + 24 h), the old row `moved`, 2 `rename` events, the list of F, one message. Row 3 (F is `moved` with the same id): F active again, the claimed row `moved`. F of another id (999): no identity write, the list of F is read. No `repo_etag` | R-TP10, R-TP13, R-TP18, R-PU26, R-PU22, Q380 |
| W2 | `reconcile/tp18-rename-transfer` | Q381: a rename and another owner id in one read. The claimed row gets owner 81 and `transfer` (seq 2), then `moved` and `rename` (seq 3); the new row of F has the ids of the read and one `rename`; run 2 (both rows due) adds no event | R-TP9, R-TP10, R-TP18, R-TP19, Q381 |
| W2 | `reconcile/pu23-pages` | 2 pages: page 2 has no `If-None-Match`, a duplicate id counts once, a release on page 2 is not `deleted`, `etag` NULL. 10 pages that all have a next link: the row fails, `fail_count` 1, the old etag stays, the log line | R-PU23, R-PU37, Q372 |

The tokens of `pu24-missing-again`: run 2 and run 3 are 1 h later, so each gets a new default token (`token=2`, `token=3`, the token of slice 119a is valid 1 h).

### 13.3 Red results (2026-11-02, the stubs, a build copy, `--opt=speed`)

| Step | Result |
| --- | --- |
| W0 (`ReconcileTest` and `WebhookTest`) | 30 tests: 25 pass, 5 red. Red: test 6 (`list_work` keeps `repo-missing`), test 10 (the claim words), tests 11, 12, 13 (`crash "todo"`) |
| W2 `reconcile/` | 6 of 12 red: `pu23-list` (7.0.0 keeps `repo-missing`), `pu23-pages` (the row fails at "more than one page"), `pu24-missing-again` and `pu31-repo-etag` (no `If-None-Match` on the visibility read: the fake answers 599), `tp9-transfer` (no owner change, no events, no clear), `tp18-rename` (no new rows, no `moved`) |
| Old W2 | All pass (172), with the old `reconcile/` cases and `webhook/`. The 6 `archive/` cases fail only in the build copy (it does not build `archive-test.wasm`) |

### 13.3a Private reference and mutants (TW12)

`research/slice-119-revert/reference-119c/` and `REFDIR=reference-119c ref.sh` (the code agent does not read it). With the reference: W0 30 of 30; W2 `reconcile/` 12 of 12; the full W2 178 pass (only the 6 `archive/` cases of the build copy fail, as above). Mutants: `m119c/`, `run-119c.sh`, logs `m119c-*.log`.

| Mutant | What | Caught by |
| --- | --- | --- |
| c1 | No `If-None-Match` on the visibility read | W2 `pu24-missing-again`, `pu31-repo-etag` |
| c2 | `repo_etag` stored for a renamed row | W2 `pu31-repo-etag` |
| c3 | The withdraw keeps `etag` and `repo_etag` | W2 `pu24-missing-again`, `pu31-repo-etag` |
| c4 | No `found` | W2 `pu24-missing-again`, `tp9-transfer` |
| c6 | Every page sends `If-None-Match` | W2 `pu23-pages` |
| c7 | A duplicate id of 2 pages is not merged | W0 12, W2 `pu23-pages` (2 messages for 5.0.0; the case was made stronger for this) |
| c8 | No cap of 10 pages | W2 `pu23-pages` |
| c9 | No `repo_checks` row for a new F | W2 `tp18-rename` |
| c10 | The clear is not guarded by the claim value | W2 `pu36-state-guard` |
| c11 | The list etag is stored for more than one page | W2 `pu23-pages` |
| c12 | Row 1 of R-TP18 without the check that F has no row (a name of another id) | W2 `tp18-rename` |

All 11 are caught. After Q381: the reference also passes `tp18-rename-transfer` (W0 30 of 30, W2 `reconcile/` and `webhook/` 32 of 32). Mutant c13 (the old proposal of Q381: R-TP9 row 2 on the row of F only) is caught by W2 `tp18-rename-transfer` (the claimed row keeps owner 80, no `transfer` event); W0 and the other cases pass. On the stubs, `tp18-rename-transfer` is red (the identity writes are missing). Both runs are after slice 125 (2026-11-03).

### 13.4 Hints for the code agent

| Point | Hint |
| --- | --- |
| The visibility read | No `If-None-Match` when `repo_etag` is NULL (the fake checks that the header is absent). A 304 keeps `repo_etag` and lists the name of the row |
| The owner id | `Ingest.parse_repo` of the answer gives the owner id; `Identity.full_name_of` gives F |
| The id of F | `Reads.repo_id(owner, repo)` of F in lower case. A `names` row for F can be missing: insert it with `NOT EXISTS` in the same batch |
| The identity SQL | Put the identity statements in the batch of the row, before the change statements. Guard each one in SQL (state, `repository_id`, `NOT EXISTS`, `changes() > 0` for an event), so a second run or a statement that does not apply writes nothing. The `seq` of an event is `COALESCE(MAX(seq), 0) + 1` of its name |
| The order | R-TP19: transfer, then found, then the clear (`tp9-transfer` pins the `seq`) |
| The pages | Only page 1 sends `If-None-Match`. More than one page: `etag` NULL |
| The clear | Guard it by the value that the claim saw (`withdrawn = ?2`), so a webhook write during the run is kept (`pu36-state-guard`) |
| Roc | `app` is a reserved word: do not use it as a name |

### 13.5 Questions (TW17)

| Id | Question | Proposal | Until answered |
| --- | --- | --- | --- |
| Q381 | A read by id can give a rename and a transfer at the same time. Which row gets R-TP9 row 2? | (Answered in section 11: the claimed row first, then `moved`; a new F gets the ids of the read) | Pinned by `tp18-rename-transfer` (mutant c13 caught) |

### 13.6 Output (proposals, TW24)

| Item | Proposal |
| --- | --- |
| The error of a row with more than 10 pages | `the release list has more than 10 pages` (the text of Q372). The log line does not pin `error` |
| A page after page 1 that answers 304 | The row fails, the error is a short text (not pinned) |

## 14. Revert check of the real code of 119b (TW12, test agent, 2026-11-02)

The mutants change a build copy of the real code (`research/slice-119-revert/real/`, `run-real.sh`). Each runs W0 and W2 `reconcile/`, `webhook/pu17`, `webhook/pu13-index-new`. Baseline (no change): W0 26 of 26, W2 9 of 9. New case for this check: `reconcile/pu36-state-guard` (a `.sql` hook sets release 1 to `repo-missing` and release 2 to `edited` just before the list answer; both must stay). It passes on the real code.

| Mutant | What | Caught by |
| --- | --- | --- |
| r1 | A failed send is ignored | W2 `pu37-etag-effects` |
| r2 | No claim | W0 `claim_sql`, W2 `pu36-overlap` |
| r3 | The run stops at the first failed row | W2 `pu37-backoff`, `pu37-etag-effects` |
| r4 | The draft line of `state_of` is removed | W0 `list_work`, W2 `pu23-list` |
| r5 | Only the releases of the claimed name | W2 `pu23-list` |
| r6 | The reserve ends the row before its list read | W2 `pu25-reserve` |
| r7 | The clear has no state guard | W2 `pu36-state-guard` |
| r8 | The flow of the poll job uses via 1 | W2 `pu21-poll-job` |
| r9 | `AddProvenance` of the poll job uses via 1 | W2 `pu21-poll-job` |

All 9 are caught. Of the choices of 12.4, the tests pin: an empty etag sends no `If-None-Match` (`require: null` in `pu23-list`, `pu37-etag-effects`), and the guard of the clear (`pu36-state-guard`). No test pins: the `log_index` order of the claim, the failure of a row with no `repos` row, the later reset of 2 reserves, the log line with `moved: 0`, the "move failed" log line, the U32 cap, the batches with no session, the error texts. Logs: `research/slice-119-revert/real-r*.log`.

## 15. Code (119c, code agent, 2026-11-03)

No test, fixture or runner file was changed. No dispute. The code agent did not read `research/slice-119-revert/`.

### 15.1 Files

| File | Change | Lines |
| --- | --- | --- |
| `worker/lib/Reconcile.roc` | `claim_sql` gives `repo_etag`, `name`, `repository_owner_id`, `state`. `list_outcome` ignores `Link`. `list_work` clears `repo-missing` of a final candidate with the recorded asset. The bodies of `has_next`, `page_url`, `merge_pages`, `repo_etag_of` | about 20 changed or new |
| `worker/ReconcileCron.roc` | `Claimed` has the 4 new columns. `check!`: `if-none-match` with `repo_etag`, a 304 lists the row name with no identity write. New: `seen_of`, `identity_stmts` (pure, the SQL of the identity), `page!` (one page), `Ident`, `Etags`. `list!`: the pages, `merge_pages`, `etag` NULL for more than one page, the identity statements first in the batch. `pass` sets each etag only when it is `Set`. `change_stmt`: a clear is guarded by `withdrawn = <the claim value>` | 215 to 363 (about 150 new or changed) |
| `worker/IndexQueue.roc` | `withdraw_stmts`: the 4th statement `UPDATE repo_checks SET etag = NULL, repo_etag = NULL` on each row of the repository id (Q376) | 2 |

### 15.2 Green results

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | pass (`ReconcileTest` 13 of 13 with the rest of `w0.roc`) |
| `node sql/tests/run.mjs` | 53 passed, 0 failed |
| `scripts/test.sh wbuild w2` (`--opt=speed`) | pass: 186 passed, 0 failed. `reconcile/` 13 of 13 |
| `scripts/test.sh check fmt w1` | pass. The Worker `roc fmt` on the 3 files: no change |
| Time | `wbuild` 237 s (budget 90), `w2` 98 s (budget 45): over the TW20 budget, as before |

First run: 3 cases failed with `Wrong number of parameter bindings` (the pass bound 5 values for a statement with fewer). Fixed: the pass is one statement with `CASE WHEN ?4 = 1 THEN ?5 ELSE etag END` (and the same for `repo_etag`).

### 15.3 Choices that the design does not give

| Choice | Other options |
| --- | --- |
| The identity statements are generic SQL with guards, built from the read only (`identity_stmts`). They do not use the `repository_owner_id` and `state` of the claim (the claim gives them for W0 test 10). The SQL compares the ids, so the result is the same, and a webhook write during the run is not overwritten | Decide in Roc with `Identity.decide` from the claim values |
| The transfer event is written BEFORE its `UPDATE` (the event reads the old owner id from the row; the guard `repository_owner_id <> ?3` is the same in both). Both are in one batch | Update first, then an event with the old id as a parameter |
| When `F` is the name of the row and the row is `moved`, the same statements give R-TP18 row 3 (the row is `active` again, the other rows `moved`) | Only transfer and found |
| (Changed after the design answer, Q381 addition, 2026-11-03.) When `F` has a row of another `repository_id`, the claimed row still gets R-TP9 row 2 (new owner id, `transfer`), is not `moved`, and the row of `F` gets no write. The `NOT EXISTS` guard on `F` is removed from the transfer. W2 `tp18-other-id` pins it | The first code: no transfer |
| The row of `F` (existing, same id) that is `missing` gets `found`, but its `next_check_at` does not change | `MIN(next_check_at, now)` as the ingest |
| The new `repo_checks` row of `F` is added only when `F` has a `repos` row of the same id after the insert, and it has no row in `repo_checks` | `NOT EXISTS` only |
| The `names` row of `F` is added with `WHERE NOT EXISTS (... id = ?1)` | `ON CONFLICT DO NOTHING` |
| A moved claimed row whose read gives its own name stores `repo_etag` (it is `active` again in the same batch) | NULL for each claimed row in the state `moved` |
| A page after page 1 that answers 304: the row fails with `the release list page <n> answered status 304` | Another text |
| A `full_name` with no `/`, or a claimed `repo` that is not a number: the row fails (texts not pinned) | Skip the identity |
| A clear of a row that the claim did not give binds NULL (`withdrawn = NULL` is never true, so no write) | No statement |

## 16. Revert check of the real code of 119c (TW12, test agent, 2026-11-03)

The mutants change a build copy of the real code (`research/slice-119-revert/real119c/`, `run-real119c.sh`, `--opt=speed`). Each runs W0 and W2 `reconcile/` and `webhook/`. Baseline (d0, no change): W0 30 of 30, W2 32 of 32. Logs: `research/slice-119-revert/real119c-d*.log`.

| Mutant | What | Caught by |
| --- | --- | --- |
| d1 | No `If-None-Match` on the visibility read | W2 `pu24-missing-again`, `pu31-repo-etag` |
| d2 | `repo_etag` stored for a renamed row | W2 `pu31-repo-etag` |
| d3 | The withdraw keeps `etag` and `repo_etag` (Q376) | W2 `pu24-missing-again`, `pu31-repo-etag` |
| d4 | No `found` | W2 `pu24-missing-again`, `tp9-transfer` |
| d6 | Every page sends `If-None-Match` | W2 `pu23-pages` |
| d7 | The pages are not merged (a duplicate id) | W2 `pu23-pages` |
| d8 | No cap of 10 pages | W2 `pu23-pages` |
| d9 | No `repo_checks` row for a new F | W2 `tp18-rename`, `tp18-rename-transfer` |
| d10 | The clear has no guard on the claim value | W2 `pu36-state-guard` |
| d11 | The list etag is stored for more than one page | W2 `pu23-pages` |
| d12 | The mark `moved` without the check of the row of F (a name of another id) | W2 `tp18-rename` |
| d13 | No R-TP9 row 2 on the claimed row (the old proposal of Q381) | W2 `tp18-rename-transfer` |
| d14 | `found` before `transfer` on the row of F (R-TP19 "Order") | W2 `tp9-transfer` |
| d15 | `rename` before `transfer` on the claimed row (Q381) | W2 `tp18-rename-transfer` |

All 14 are caught.

### 16.1 The main choices of 15.3 against the design

| Choice (15.3) | Agrees with the design | Pinned by a test |
| --- | --- | --- |
| The identity SQL uses only the read and SQL guards, not the claim values | Yes (Q379, Q380: the guards of slice 113, a webhook write is not overwritten) | Yes, indirectly: every identity case (`tp9-transfer`, `tp18-rename`, `tp18-rename-transfer`, `pu24-missing-again`) |
| The transfer event comes before its `UPDATE` (the same guard) | Yes (R-TP19 "Order", Q381: `transfer` first) | Yes: `tp9-transfer`, `tp18-rename-transfer` (the `seq` and the old owner id of the event); d14, d15 |
| F is the name of the row and the row is `moved`: R-TP18 row 3 (active again, the other rows `moved`) | Yes (Q380: rows 1, 3, 4 with U = F) | Only the other form of row 3 (F is another `moved` name, `tp18-rename` acme/x to acme/y). A `moved` claimed row whose read gives its own name: no test |
| F has a row of another `repository_id`: the claimed row gets no transfer either | No, in my reading. Q380 says only that the row of F with another id gets no write. Q379 and Q381 apply R-TP9 to the claimed row with the ids of the read (same `repository_id`, so row 2), and the reason of Q381 is that the old row must have the `transfer` event (R-PU30). The `NOT EXISTS (... repo = F AND repository_id <> id)` guard on the claimed row is not in the design | No: in `tp18-rename` acme/p (owner 70) to acme/q (id 999) the read has the same owner id, so both readings give the same result. For the coordinator or design agent to decide: remove the guard from the claimed-row transfer, and add a row to `tp18-rename` with another owner id |

### 16.2 New case after the Q381 addition (2026-11-03)

| Layer | Test | What it pins | Rules |
| --- | --- | --- | --- |
| W2 | `reconcile/tp18-other-id` | Row (1): `acme/r` (810, owner 80) reads as `Acme/S` with owner 81, and `acme/s` is a row of another id (998). `acme/r` gets the owner id 81 and ONE `transfer` event and stays `active`. `acme/s` gets no write. Row (2), R-TP18 row 3 with U = F: `acme/b` is `moved` (successor `acme/c`) and its read gives `acme/b`. `acme/b` becomes `active` with no successor and a `rename` event; `acme/c` becomes `moved` with successor `acme/b` and a `rename` event. Run 2 (1 h later, the same reads) adds no event. No ETag on the reads, so `repo_etag` is not pinned for the moved row | R-TP9, R-TP10, R-TP18, R-TP19, R-TP13, R-PU23, R-PU31, Q380, Q381 |

Results (build copies, `--opt=speed`): `reference-119c` passed with no change (W2 `reconcile/` and `webhook/`: 33 of 33). On the real code of 119c, `tp18-other-id` is red only for row (1): `acme/r` keeps owner 80 and has no `transfer` event, because of the `NOT EXISTS (... repository_id <> ?2)` guard (16.1). Row (2) already passes. The other `reconcile/` cases pass (13 of 14).
