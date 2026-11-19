# Slice 256: W2 test speed (plan item G19)

Machine: 24 CPUs, load average 2 to 7 (other sessions), 2026-11-19. Build: the stamp of `wbuild` (cached, 0.3 s). Runner: `worker/tests/run.mjs`, JOBS=6 (default).

## 1. Result

| Item | Before | After |
| --- | --- | --- |
| Cases | 212 passed, 0 failed (178 case dirs + selftest; the 189 of the old notes grew) | 212 passed, 0 failed |
| `scripts/test.sh wbuild w2` | 31.4, 35.2, 33.2 s (3 runs) | 20.5, 18.5 s (2 runs of `w0 wbuild w2 wtrap`); direct runs 18.5 to 23 s |
| Budget `BUDGET[w2]` | 45 s | 45 s (not changed): met |
| App starts (pool keys) | 28 to 29 starts, 184 resets | 27 to 29 starts, 184 resets (same) |
| Main thread of the runner | 100 % busy, 34.2 s of CPU profile, 22.3 s blocked in `receiveReply` | 21.6 s, 8.3 s blocked |

The old numbers (69 s, 80 s, 135 s) came from a busy main thread plus machine load: the main thread of the runner is the single thread that all 6 jobs share, and Miniflare blocks it on each synchronous call.

## 2. Where the time went (CPU profile of the main thread, `prof-top.mjs`, `prof-callers.mjs`)

| Blocking call (Miniflare `SynchronousFetcher`, `Atomics.wait`) | Before (ms) | After (ms) |
| --- | --- | --- |
| `db.prepare()` in `runCase` (seed.sql and `sql` lines) | 9883 | 0 |
| `db.prepare()` in `migrate` (37 statements, each reset) | 4130 + 1091 + 346 | 0 |
| `h.d1('DB')`, one for each case | 2754 | 0 (made only for db.tsv and github/*.sql) |
| `clearD1` of the platform `reset()` (`.roc-cfw/test.mjs`, not ours) | 2615 + 687 + 128 | 4507 + 1117 + 261 (more, as the load moves here) |
| Other (queue, fakegithub, getProxy) | about 500 | about 600 |

Time of the jobs added (the line `w2 pool` of the runner): start 12 to 19 s, reset 16 to 30 s; the cases part went from 138 to 150 s to 67 to 86 s.

## 3. Options evaluated

| Option | Result |
| --- | --- |
| More or fewer JOBS (4, 6, 12 before the fix) | Wall time 36 s for all: the main thread was the limit, not the CPU count. After the fix: JOBS 4: 29.8 s, 6: 18 to 22 s, 8: 20.3 s, 10: 21.1 s. Kept 6 |
| Fewer pool keys | Not needed. 28 starts cost 12 s of job time (about 2 s of wall time). The key is the settings (bindings), which the platform sets at the start only |
| Worker processes (at most 4) | Not built. The blocking fix gives 18 to 21 s, below the budget. The runner can be split by pool key later if a case set grows (the cases are independent) |
| Repeated wasm compile | `new WebAssembly.Module` is only for the manifest, one per start (28 times); small in the profile (`Module` 150 ms) |
| Seed of the fake GitHub (`github/*.sql`) through the Worker | Tried and rejected: the nested request counts as D1 calls of the request in flight (case `reconcile/pu36-state-guard`: expected 2 calls, got 4). It keeps the direct D1 handle |
| `h.fetch` for `/__test/sql` | Rejected: the platform puts the calls in a response header, and a seed of 650 statements gives a header over 16 KB (4 cases failed with `fetch failed`, HeadersOverflowError). `h.mf.dispatchFetch` has no request id, so the calls are not recorded |

## 4. The floor

Three cases wait for a wall-clock window of the rate limit (`window_s` 60, `need_ms` 25000, 25000, 8000: `ingest-limits/pu34-ip`, `hints/ct11-rate-limit`, `account/ct11-login-limit`). They start first and wait at most 35 s, then run for 2 to 5 s. So a run is between 17 s and about 40 s by the phase of the clock, whatever the code does. The measured runs had phases from 0 to 17 s of wait. The worst phase (35 s of wait) gives about 38 to 40 s, below 45 s. The cases and their `need_ms` are not changed (TW18).

## 5. Changes

| File | Change |
| --- | --- |
| `worker/tests/hooks.js` | New path `POST /__test/sql?mode=batch|seq` (JSON array of statements): `batch` as `db.batch`, `seq` as one `prepare().run()` after the other |
| `worker/tests/run.mjs` | `runSql`; `migrate`, the seed and the `sql` lines use it; no `h.d1()` at the start of a case (a getter `dbRef.get`); `runner fault` text has the `cause`; header comment |
| `worker/tests/fakegithub.mjs` | `github/*.sql` gets the D1 handle by `dbRef.get()` (made when needed) |

Probes in this dir: `run-w2.sh` (run alone with a JOBS value), `prof-top.mjs`, `prof-callers.mjs` (read a `--cpu-prof` file), the logs `out-*.log`, `base-*.log`, `proof-*.log`.

## 6. Proof

`scripts/test.sh w0 wbuild w2 wtrap` twice: pass, pass. w0 8.5 and 7.0 s (budget 10), w2 20.5 and 18.5 s, wtrap 0.1 s; w2 212 passed, 0 failed both times (212 before). `scripts/test.sh selftest`: pass (33 s, over its own 20 s budget as before: it builds; not changed by this slice). The self-test cases of the runner (34, must fail) are in the 212.
