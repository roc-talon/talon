# Slice 123e probe: platform 0.0.4 `startApp` (test agent, 2026-11-03)

## 1. Setup

| Item | Value |
| --- | --- |
| Build copy | `research/slice-123e/build.sh` (copy of `worker/`, `--opt=speed`, the 0.0.4 URL in `main.roc` and `archive-test.roc` of the copy only) |
| W0 on the copy | All (449) tests passed |
| W2 on the copy, current runner | 189 passed, 0 failed (no change from 0.0.3). Wall time 104 s on this run (machine load average 9 to 16, so not the 69 s of G19; the build ran at the same time as other jobs) |
| Probe | `research/slice-123e/probe.mjs <build/worker>`, log `probe.log` |
| `startApp` | Works. No hooks module, no custom config (the `worker/wrangler.toml` of the copy, with its queue consumers and crons). `ratelimits: { RL_INGEST, RL_HINTS, RL_LOGIN }` is enough. The earlier "internal error" did not come back, so it was the missing config or the hooks of the first probe. No `ERROR.txt` |

## 2. Numbers (ms, 5 runs, one `startApp`, `d1` migrations 0001 and 0002, `count: ['DB']`)

| Step | Run 1 | 2 | 3 | 4 | 5 | Mean |
| --- | --- | --- | --- | --- | --- | --- |
| `startApp` | 1130 | 927 | 628 | 697 | 727 | 821 |
| One request (`GET /v1/packages?short=a`) | 75 | 59 | 67 | 67 | 67 | 67 |
| `app.reset()` (after one `app.sql` insert) | 515 | 271 | 301 | 264 | 282 | 327 |
| `app.close()` | 28 | 14 | 12 | 14 | 16 | 17 |

| Current runner | Value |
| --- | --- |
| Serial cases (`JOBS=1`, 4 simple cases: ct8-login, ct8-login-refusals, ap45-client-version, ct12-tags-fail) | 1269, 861, 1044, 959 ms each, mean about 1.0 s. This is `new Miniflare` + 2 migrations + seed + the requests + dispose |
| W2 time / 189 | 0.55 s (104 s run) or 0.37 s (69 s run) for each case, with JOBS = 6 |

A reset (0.33 s) costs about a third of a start (0.82 s) and about a third of a whole simple case (1.0 s). The cost of a reset is the floor: it waits for `idle`, drops and rebuilds D1, and clears the counters.

## 3. Estimate of W2 with startApp and reset

| Case group | Count | Pool |
| --- | --- | --- |
| No `settings.json` (default settings) | 62 | One app per job |
| `settings.json` (14 different files) | 93 | One app per distinct settings (14), each used by about 7 cases |
| `archive/` (own wasm `archive-test.wasm`) | in the 155 | Own pool (own `dir`) |
| `selftest/` | 34 | Check how they start (they test the runner, not the Worker); keep them on `new Miniflare` if they need a wrong entry |

Rule: one `startApp` serves only the cases with the same set of settings (`bindings`, `ratelimits.json`, `app`), so the pool is keyed by that set. With about 16 keys and JOBS = 6, each job starts about 3 apps (0.8 s each) and then resets. If the cases are 150 in 6 jobs, a job runs 25 cases:

| Item | Now (per job) | With pool (per job) |
| --- | --- | --- |
| Start | 25 x about 0.7 s = 17 s | 3 x 0.8 s = 2.4 s |
| Reset | 0 | 25 x 0.33 s = 8 s |
| Requests, seed, checks | same | same |
| Saved | | about 7 s of 25 s of start/migration cost, about 25 to 35 % of the case time |

My guess: W2 goes from 69 s to 45 to 55 s (nominal), not below 40 s. The gain is real but small, because the reset (0.33 s) takes most of the start (0.7 to 0.8 s). The window waits of 3 cases (hints/ct11-rate-limit, account/ct11-login-limit, ingest-limits/pu34-ip: up to 60 s of wall clock in the worst case, `need_ms` 8000 to 25000) stay. The budget of 45 s is reached only if the build and the Node side are not the limit. This is a guess: not measured on a runner.

A less costly try to cut the same time: more JOBS (the machine has 24 CPUs; JOBS is min(CPUs, 6)). Not measured here.

## 4. Where the runner needs a hooks module or its own code

| Work of the runner | startApp 0.0.4 | Needs |
| --- | --- | --- |
| Queue send body | `calls` has `body` (base64, 4096 bytes kept) | No hook for the body. A body over 4096 bytes is `truncated` with no `value`: check the largest queue body of the cases (INDEX messages are small, check) |
| Queue send delay (`delay_s` in 14 `responses.jsonl`) | `test-entry.js` has no `delay` (grep found none). Not in `calls` | A hooks module (`wrapEnv`) that wraps INDEX `send` and keeps `delaySeconds`, or a platform change (ask the platform to add `delaySeconds` to the `send` item) |
| `timingSafeEqual` count (3 files) | Not counted | A hooks module (patch `crypto.subtle.timingSafeEqual`, give the count by a header or a `/__test` path) |
| `/__test/...` paths (json, problem, now, rows, d1, headers, count, session, send, github, stats) | None | A hooks module with `fetch(request, env, next)` for these paths (it can use `next` for all other paths) |
| `__test` queues (ack or retry with `retry_s`) | `app.queue(name, messages)` gives `ackAll`, `retryMessages` with delay | The `__test` queue answers of the Talon entry stay in hooks, or the Worker queue handler is tested through `app.queue` |
| `TEST_INDEX_FAIL_SENDS` (the first N sends fail) | None | Hooks (`wrapEnv`) |
| Cron lines (`/cdn-cgi/local/scheduled`, then `/__test/stats`) | `app.scheduled({ cron, time, now })` | `app.calls()` for the D1 ops and queue sends of a run |
| D1 count and ops, sessions, clock, fake GitHub | `count`, `res.calls`, `res.sessions`, `now`, `outbound` function | The header names `x-d1-calls`, `x-d1-ops`, `x-d1-session` change to `res.calls` (11 case files depend on the names) |
| Ratelimits per case | `ratelimits` option | No hook. The pool key has the ratelimits.json |

So the hooks module cannot be dropped. The runner still keeps its own wrapper for the queue delay, the `timingSafeEqual` count, the `/__test` paths and `TEST_INDEX_FAIL_SENDS`; only the Miniflare start, the D1 count, the clock and the bodies come from the platform.

## 5. Rate limit counters and the case clock

Miniflare counts by the real wall clock, not by `app.setNow`; `app.reset()` uses a key prefix with the number of resets, so a counter is new after each reset.

| Case | Uses the case clock for the limit window? |
| --- | --- |
| account/ct11-login-limit (RL_LOGIN limit 3, period 60) | No. Its `now` (1767225600000) is the shim clock for the Worker logic only. The window is the real wall clock: the line `{"window_s":60,"need_ms":8000}` makes the runner wait for a real window with 8 s left (`run.mjs` line 401) |
| hints/ct11-rate-limit (RL_HINTS limit 3, period 60) | No. Same, `need_ms` 25000. The `now` values (…602000, …603000) step the shim clock only |
| ingest-limits/pu34-ip (RL_INGEST) | No. Same window line |
| Other cases | Use the default limits (RL_INGEST 60, RL_HINTS and RL_LOGIN 1000 in 60 s) and make fewer calls |

No case needs the limit window to follow `app.setNow`. The window line (wall clock) stays in the new runner. With reset, a case in a pool that follows another one starts with a new counter, so the window wait is still needed only for the start-of-window condition inside one case.

## 6. Open points for the human

| Point | Note |
| --- | --- |
| Is a gain of about 15 to 25 s (a guess) worth a rewrite of the 493-line runner and 11 case files? | The probe says startApp works and the gain is real, but it is a third of the case cost, not a large cut. Q444 said "only if the measured gain is large": I would say the gain is medium |
| Queue delay | Ask the platform for `delaySeconds` in the `calls` send item (then 14 files need no hook for it) |
| Re-measure | Run W2 alone (no other job) before the decision: this run had load average 9 to 16 |
