# 123e The W2 runner on the platform test helper

Phase: P2. Status: tests done, for human review (test agent, 2026-11-03). Plan row: `docs/registry/PLAN.md` G19, `docs/slices/123-platform-003.md` section 7, Design Q444. Harness work only: `worker/` code and the expected results of the W2 cases do not change in meaning.

## 1. Scope

| Item | Value |
| --- | --- |
| Goal | The W2 runner uses `startApp` and `app.reset()` of platform 0.0.5 (`.roc-cfw/test.mjs`) in place of one `new Miniflare` for each case. W2 budget: 45 s (TW20) |
| Owner | Test agent: `worker/tests/` (`run.mjs`, `hooks.js`, `wrangler-test.toml`, case files). No change in `worker/` code, `sql/`, `packages/`, `cli/`, design files, `cloudflare-workers/` |
| Case format | Kept, with one change: the header `x-d1-session` of an expected response is now the key `d1_session` (section 4) |
| Old runner | Copies of the old files are in `research/slice-123e/before/` (`run.mjs`, `worker-test.js`, `clock.js`, the changed cases and tools). The files `worker/tests/worker-test.js` and `worker/tests/clock.js` are deleted |
| Build mode | `--opt=speed` only |

## 2. Design

| Part | Decision |
| --- | --- |
| Pool | One `startApp` for each job and each key. The key is the JSON of: app (the Worker or `archive-test.wasm`), the settings (`bindings`: `settings.json` with the App settings), the rate limits (`ratelimits.json` with the defaults). About 14 keys |
| Between two cases | `app.reset()` (D1 tables dropped, clock, `Memo` pins, Cache API keys, calls, outbound log, logs, rate limit counters). The runner then runs the migrations as one `db.batch` (see section 6) |
| Not reused | An app after a failed case, a timeout, a runner fault or a failed `reset()`. The next case gets a new app |
| Scheduling | A job takes the next case of its own key. Else a case with a `window_s` line (they wait up to 60 s, so they start first). Else a case of the key that the fewest jobs hold. The report is in the order of the cases |
| Config | `worker/tests/wrangler-test.toml`: compatibility date and flags, the producer INDEX, and `consumers = []`. Without this, `startApp` makes a queue consumer for each producer, and the Worker would consume its own sends |
| Hooks | `worker/tests/hooks.js` (a `hooks` module of `startApp`), see section 3 |
| Fake GitHub | The `outbound` function of `startApp` calls the function of the current case (the same code as the old runner, in a ref) |

## 3. What calls give, and what hooks give

| Work | Source |
| --- | --- |
| D1 call count and ops of a request | `res.calls.DB.n`, `.ops` (the case `expect/d1-calls`) |
| `withSession` argument | `res.sessions.DB` (the last one), expected as `d1_session` |
| Clock | `app.setNow`. The runner keeps the clock value itself (section 8, issue 2) |
| Queue send body | `res.calls.INDEX.list[i].body.value` (`send`), `.bodies[i].value` (`sendBatch`) |
| Queue send delay | `hooks.js` (section 8, issue 1) |
| Cron lines | `app.idle()`, `app.calls({ reset })` before and after the run, and `dispatchFetch` of `/cdn-cgi/local/scheduled` (the old status and body); `copies` use `mf.getWorker().scheduled()` as before |
| Queue lines | `app.queue(name, messages, { now })` |
| `timingSafeEqual` count | `hooks.js`: the patch of `crypto.subtle.timingSafeEqual` and the response header `x-timing-safe-calls` |
| `/__test/...` paths | `hooks.js` (`fetch` hook). `/__test/now` is answered by the runner (the clock is in the test entry), by a read of the control path `/__cfw_test/<token>/now`: it gives the real clock of the isolate |
| `TEST_INDEX_FAIL_SENDS` | `hooks.js` (`wrapEnv`, before the count, so a refused send is no call). `/__test/arm` makes it read the setting again for the next case (`reset()` does not clear a module global) |
| Queue lines | `app.queue` drives the real consumer for every queue (slice 123f, section 10) |
| Rate limits | The option `ratelimits`. Counters are new after each `reset()`. They follow the real wall clock, so the `window_s` lines stay |

## 4. Changed case files

The brief said 11 case files read the `x-d1-*` header names. The real count is 18 case files, 2 self-test cases and 4 generators. Only `x-d1-session` was used (no case read `x-d1-calls`, `x-d1-ops`, `x-queue-sent` or `x-timing-safe-calls`).

| Change | Files |
| --- | --- |
| In `expect/responses.jsonl`: `"x-d1-session":"v"` leaves `headers` and becomes the key `"d1_session":"v"` after `headers` (null: no `withSession`). An empty `headers` is removed. 174 lines | identity (6 cases), runner/r-wh4-sql-session-cache, reads/bookmark-session, ingest-limits (3), publish (4), ingest (3), selftest/session-absent, selftest/wrong-session |
| In `expect-fail`: `header x-d1-session:` becomes `d1_session:` | selftest/session-absent, selftest/wrong-session |
| The generators emit the files that are in the tree | `tools/mk-identity.mjs`, `mk-ingest.mjs`, `mk-platform-mark.mjs`, `mk-publish.mjs`: `d1_session`, and the later hand edits that they had missed (the `provenance` member of a release, `is_platform` of a dep and the `platform` column of the `deps` block, the `R-AP49 R-PU15 R-RE9` rule ids). A run of each generator into a copy of `worker/tests/` and `diff -r` with the tree is empty for all 7 generators (`mk-identity`, `mk-ingest`, `mk-platform-mark`, `mk-publish`, `mk-reconcile`, `mk-webhook`, `mk-zero-run`), with one exception: the case `publish/pu15-ingest-then-publish` is in the tree and no generator makes it (slice 122). No case file was changed to fit a generator |

Copies of every changed file: `research/slice-123e/before/` (same relative paths as in `worker/tests/`).

## 5. Results

| Check | Result |
| --- | --- |
| All W2 cases on the real build (`scripts/test.sh wbuild w2 wtrap`) | 189 passed, 0 failed (155 cases and 34 self-test cases that must fail); `wtrap` passes |
| The selftest step (`scripts/test.sh selftest`) | It does not cover W2 (no W2 line in `tests/selftest.sh`): the W2 cases that must fail are the 34 `worker/tests/selftest/` cases, and they ran in the 189. The step has 1 failure that is not from this slice: `l1: the default steps of scripts/test.sh are ... (TW32)`, because slice 123d added `wtrap` to the default steps and the row of `tests/selftest.sh` has no `wtrap` (80 passed, 1 failed). Not changed here (`scripts/` and `tests/` are not in the scope of this slice) |
| Pool in a run | 25 to 26 apps started, 163 resets, 189 cases (before: 189 starts) |

W2 time, wall clock, the same build and the same machine, one run after the other (the machine had other builds: load average is the value at the start). `research/slice-123e/timing-pairs.txt`, `old-run-1.log`, `old-run-2.log`, `new-run-*.log`:

| Pair | Old runner | New runner |
| --- | --- | --- |
| Quiet (load 4 to 6) | 86.8 s, 77.6 s (`scripts/test.sh w2`) | 34.9 s (a run just after the second old run, first version of the pool: 55.9 s and 60.4 s, before the batch of the migrations and before the scheduling by key) |
| Loaded, pair 1 | 109.5 s (load 29) | 42.8 s (load 17) |
| Loaded, pair 2 | 103.7 s (load 16) | 46.8 s (load 16) |
| `scripts/test.sh w2` after the change (load about 12) | | 48.2 s |

Reading: about 2.2 times faster on the same load (104 s to 47 s; 78 s to 35 s). The budget of 45 s (TW20) is met on a quiet machine (35 s) and missed by 2 to 3 s on a loaded one. The floor is the 3 cases with a rate limit window wait (`compat/mx9-missing-100` 17 s, `ingest-limits/pu34-ip` 17 s, `hints/ct11-rate-limit` 15 s): they run on 3 of the 6 jobs from the start. The time of the jobs added (one run, loaded): start 25 s, reset 45 s, cases 190 s, in 6 jobs. A start is 1 s, a reset 0.3 s (0.1 s with no load). More jobs (`JOBS`, default `min(CPUs, 6)`) were not measured.

Mutants (research/slice-123e/mutants.sh: a copy of `worker/` with one change, built with `--opt=speed`, run with the new runner on all 189 cases; then the old runner, from the old files, on the failing cases). Each mutant fails the cases on both runners:

| Mutant | Change | Failing cases, new runner | Old runner |
| --- | --- | --- | --- |
| m1-send-delay | The webhook sends to INDEX with a delay of 5 s | webhook/ap12-signature, webhook/pu11-events (`queue_sent` `delay_s`) | the same 2 |
| m2-retry-delay | First retry delay 120 s in place of 60 s | 6 webhook cases (`queue retried` `delay_s` 120) | the same |
| m3-d1-count | One more D1 `batch` in `ReadRoutes.serve!` | 24 cases (`d1-calls` expected 1, got 2) | the same |
| m4-rate-limit | `RateLimited` of RL_HINTS is not answered with 429 | hints/ct11-rate-limit (429 expected, got 200). A second failure, `compat/mx9-missing-100`, was a timeout of the 4 mutant runs at the same time (load 45), not a result | the same |
| m5-hint-status | The hint answer is always 200 (not 201) | 9 cases (githubtoken/pu25-*, hints/ct12-*, ct13, ct14, ct2) | the same |
| m6-session | A bookmark makes the session `After("zzz")` | reads/bookmark-session (`d1_session` expected `bookmark-abc-123`, got `zzz`) | the same (as the header) |
| m7-timing-safe | The signature compare is `==`, no `timingSafeEqual` | webhook/ap12-signature, webhook/pu11-events (`timing_safe`) | the same |
| m8-ignore-send-fail | The reconcile ignores a failed send to INDEX | reconcile/pu37-etag-effects (`TEST_INDEX_FAIL_SENDS`, `queue_sent` got []) | the same (and 2 more checks) |

`ingest-limits/pu34-ip` failed in one loaded mutant run only (the 60 s window of the real wall clock passed during the case): it is a load effect, not a mutant effect. The 189 cases pass on the real build in every run of the table above.


## 6. Decisions of the test agent

| Decision | Reason |
| --- | --- |
| The migrations are one `db.batch` of the runner after the start and after each `reset()`, not the `d1` seeds of `startApp` | The seeds of `reset()` run one statement at a time: 120 ms against 50 ms for a reset on a quiet machine (`research/slice-123e/reset-probe.mjs`). The batch gives the same schema. The seed of a case (`seed.sql`) and the `sql` lines use the same one-statement code as before |
| Window cases start first | They wait up to 60 s for a rate limit window. They are the longest items, so they must not start last |
| `idle()` before a cron or queue line | The calls that are counted for the line must be the calls of the line, not of the work after an earlier response |
| A failed case closes its app | A case that fails can leave work in flight. A new app costs about 1 s and a failure is rare |

## 7. Questions for the human

| Id | Question | Proposal |
| --- | --- | --- |
| Q1 | The count of the case files is 18, not 11. Is the new key `d1_session` the form that you want? | Yes. The key has the same meaning as the header. The alternative is a runner that makes the pseudo header `x-d1-session` from `res.sessions`, with no case change |
| Q2 | The queue `__test...` lines tested the runner only | Closed by slice 123f (section 10): every queue line drives the real consumer |

## 8. Platform issues (for the platform session)

Update 2026-11-04 (platform 0.0.6): issue 1 is fixed. `res.calls` and `app.calls()` keep `delaySeconds` (a `send` item has it; a `sendBatch` item has it on each of `bodies` and on the batch options). The workaround is gone: `hooks.js` no longer records the delays (no `x-queue-delays` header, no `/__test/delays` path), and `sentOf` in `run.mjs` reads them from `calls`. Issue 2 is fixed (`app.now` is a getter; the runner still keeps its own clock to skip a `setNow` call). Issue 5 is fixed (one batch for each seed text). Issue 6 is documented (`consumers = []`). The case files did not change. Mutants of the new path: `research/platform-006/mutants.sh`.

| No | Issue | Effect | Wish |
| --- | --- | --- | --- |
| 1 | `res.calls` and `app.calls()` have no `delaySeconds` for a `send` and for the batch options of a `sendBatch`. `test-entry.js` (0.0.5) keeps it in the call record, but `group` of `test.mjs` copies only `op`, `session`, `kind`, `name`, `body`, `bodies`, `contentType` into `list`. Only `bodies[i].delaySeconds` is there. The README "Count" says it is kept on a `send` item | The runner needs a hook (`hooks.js` `delays`, header `x-queue-delays`, path `/__test/delays`) for the delay of the 14 case files that have `delay_s` | Add `delaySeconds` to the `list` item in `group` (and the batch delay to the `sendBatch` item) |
| 2 | `app.now` is a value, not a getter: `Object.assign(app, { get now() { ... } })` copies the value at the start | `app.now` stays the start clock after `setNow`. The runner keeps its own clock | `Object.defineProperties`, or a method `app.clock()` |
| 3 | There is no public read of the clock of the isolate | The check `/__test/now` reads the control path with `app.token` and `app.mf` (no promise of stability) | A method `app.isolateNow()` |
| 4 | `hooks` has `wrapEnv` and `fetch` only, no `queue` hook | Not needed any more: `app.queue` drives the real consumer (slice 123f) | None |
| 5 | A `reset()` runs each seed statement as a round trip | 120 ms for 35 statements (50 ms with one `batch`); 160 resets in a W2 run | Run the seeds with `db.batch` |
| 6 | `startApp` makes a queue consumer for each producer when the config has no `queues.consumers` and the app has a `queue` handler | A test config must say `consumers = []` or the Worker consumes its own sends | Document it in "Testing an app" (an option `queues: false`) |
| 7 | `ratelimits` names that the app does not declare are a throw | A pool for two apps (the Worker, a test app with other bindings) must filter the table by the manifest | Skip the names that the app does not declare |

## 10. Slice 123f: the queue lines drive the real consumer

Check 1: which W2 cases drive the real `talon-index` consumer. In 123e only the queue name `__test...` was answered by the runner; every line for `talon-index` and `talon-index-dlq` already went to the Worker through `app.queue` (the old runner used the same call of Miniflare). So no real consumer path lost coverage in 123e. The m2 mutant of section 5 (the retry delay) is proof: 6 cases failed on the new runner.

| Queue lines | Count |
| --- | --- |
| `talon-index`: webhook (14 cases), reconcile (2 cases) | 63 lines in 16 cases (the runner case had none before) |
| `talon-index-dlq` (webhook/pu35-dead-letter) | 1 line |
| `__test-q` (runner/r-wh4-queue-and-logs, selftest/wrong-queue-acked, selftest/wrong-queue-retry) | 3 lines, runner only (the gap) |

Change (test files and runner only; `worker/` is not changed):

| Item | Change |
| --- | --- |
| `run.mjs` | The branch for `__test` queues and `testQueue` are removed. `queueCall` takes `explicitAcks`, `retryMessages` (`delaySeconds` only when the consumer gives one; null for none), and now also `ackAll` and `retryBatch` of the result of `app.queue` |
| New check | A whole-batch ack or retry fails the line, unless the expected line says it: `"ack_all": true`, `"retry_batch": {"delay_s": N or null}`. No existing case needs them. This catches a consumer that retries the batch in place of one message |
| The 3 `__test-q` cases | They use the real consumer. A message that acks: `installation_repositories` `added` (no GitHub read). A message that fails: the body `{"unexpected":true}` (retry after 60, 300, 900, 3600 s by attempt, then no delay at attempt 5). `r-wh4-queue-and-logs`: ids a (ack), b attempt 2 (retry 300 s), c attempt 5 (retry, no delay). The 2 self-test cases still must fail, with the same texts (`queue acked: expected`, `queue retried: expected`). Copies of the old files: `research/slice-123e/before/` |
| Format | Unchanged, except the 2 optional members above |

Result: `scripts/test.sh wbuild w2 wtrap`: 189 of 189 W2 cases pass, `wtrap` passes. W2 time 54.0 s at load average 17 to 26 (other builds ran; the 123e runs at load 16 gave 47 s, so this change adds no cost: the same cases, the same number of `app.queue` calls).

Mutants of the real consumer (`worker/IndexQueue.roc` in a build copy, `--opt=speed`, `research/slice-123e/mutants.sh`, run on the webhook, reconcile and runner cases, the build copies deleted). Each fails cases now:

| Mutant | Change | Failing cases |
| --- | --- | --- |
| q1-consumer-delay | The retry delay of a failed job is twice the value | 8: `webhook/pu35-retry-schedule`, `pu13-*`, `pu17-withdraw-clear`, `pu26-release-installed`, `pu33-privatized`, `runner/r-wh4-queue-and-logs` |
| q2-ack-must-retry | The last attempt acks the message in place of a retry | 3: `webhook/pu35-retry-schedule`, `pu13-no-asset-end`, `runner/r-wh4-queue-and-logs` |
| q3-retry-whole-batch | The consumer also calls `retry_all!` on the batch | 17 (all the queue cases): `queue retry_batch: expected null, got {"delay_s":null}` (the new check) |
| q4-dlq-unrouted | The dead letter queue is not routed to `dead!` | `webhook/pu35-dead-letter` (outcome `exception`, nothing acked) |
| q5-success-no-ack | A job that ends with `Ok` is not acked | 16 cases (`acked` expected, got none), also `runner/r-wh4-queue-and-logs` |

The runner case `r-wh4-queue-and-logs` now fails for 4 of the 5 mutants, so it checks the real consumer too.
