# Edge: D1 query count (Q47) and Worker placement (Q49)

Run on 2026-10-17, 19:31 to 20:38 UTC. Workers Free plan, wrangler 4.151.0. This machine is in colo `TBS`. The D1 primaries were made with no location option and got `EEUR` (the Q49 primary answers from colo `PRG`).

Questions (DESIGN.md "Open" table):

| Id | Question |
| --- | --- |
| Q47 | Does one D1 batch of N statements count as 1 query or N toward the limit of D1 queries for each invocation? |
| Q49 | Smart Placement or the default placement for the registry Worker? |

## Files

| File | What |
| --- | --- |
| `deploy.sh` | Makes and deletes the test resources. Each name starts with `rocplat-test-` and gets a row in `ledger.md`. |
| `ledger.py`, `ledger.md` | The ledger: start state, each resource made, each delete, end state |
| `cfapi.sh` | One Cloudflare API call with the wrangler OAuth token (the token is not printed) |
| `lists.sh` | The lists of the account (Workers, D1, R2, KV, Queues, Durable Object namespaces) |
| `q47/worker.js` | Q47: one case for each invocation (`/?case=<name>`), and a cron that runs one case and reports by a fetch to `/log` |
| `q49/target.js` | Q49: the Worker under test (routes `/closure`, `/chain3`, `/publish`, `/closure_s`, `/chain3_s`, `/where`) |
| `q49/client.js` | Q49: a Durable Object for each `locationHint` that calls the targets and times each call |
| `q49/run.mjs`, `q49/warm.sh`, `q49/summary.mjs` | Q49: one measure round, the traffic for Smart Placement, the summary table |
| `results/` | Raw results (JSON lines) and the account lists |

## Q47: the count of D1 queries for each invocation

Worker `rocplat-test-q47` (`q47/worker.js`), D1 `rocplat-test-q47-d1` (`EEUR`). Each case is one invocation. A loop case stops at the first error. Raw: `results/q47-run1.jsonl` (fetch handler), `results/q47-cron.json` (cron handler). `wrangler tail` failed (`Unexpected server response: 500`, `results/q47-cron-tail.err`), so the cron reports its result by a fetch to `/log` of the same Worker.

| Case | Invocation | D1 calls | Statements | Result | Time |
| --- | --- | --- | --- | --- | --- |
| `singles`: `prepare().run()` one after the other | fetch | 1,000 pass, call 1,001 fails | 1,000 | Error A | 73 s |
| `singlesPar`: 1,100 `run()` at the same time | fetch | 1,000 pass, 100 fail | 1,000 | Error A | 2.1 s |
| `batch60`: 1 batch of 60 `SELECT` | fetch | 1 | 60 | Pass | 74 ms |
| `batch200`: 1 batch of 200 | fetch | 1 | 200 | Pass | 106 ms |
| `batch1000`: 1 batch of 1,000 | fetch | 1 | 1,000 | Pass | 281 ms |
| `batch5000`: 1 batch of 5,000 | fetch | 1 | 5,000 | Pass | 666 ms |
| `write200`: 1 batch of 200 `INSERT` and 1 `DELETE` | fetch | 1 | 201 | Pass | 128 ms |
| `batches20`: batches of 20, one after the other | fetch | 1,000 pass, batch 1,001 fails | 20,000 | Error A | 76 s |
| `batchesPar`: 1,100 batches of 20 at the same time | fetch | 1,000 pass, 100 fail | 20,000 | Error A | 3.2 s |
| `mixed`: 40 `run()`, then 1 batch of 20 | fetch | 41 | 60 | Pass | 2.9 s |
| `exec60`: `exec()` of 60 statements in 1 string | fetch | 1 | 60 | Pass | 80 ms |
| `fetches`: `fetch()` one after the other | fetch | 0 (51st fetch fails) | 0 | Error B after 50 fetches | 35 ms |
| `d1ThenFetch`: 30 `run()`, then fetches | fetch | 30 pass | 30 | 30 D1 calls pass, then 50 fetches pass, fetch 51 fails with Error B | 2.1 s |
| `singles` | cron | 1,000 pass, call 1,001 fails | 1,000 | Error A | 233 s (not stopped) |
| `batches20` | cron | 1,000 pass, batch 1,001 fails | 20,000 | Error A | 178 s (not stopped) |
| `singlesPar` | cron | 1,000 pass, 100 fail | 1,000 | Error A | 30 s |
| `mixed` | cron | 41 | 60 | Pass | 9.7 s |
| Deploy with `[limits] subrequests = 20` | deploy | - | - | Refused: "CPU limits are not supported for the Free plan" (code 100328). The old version stayed. | - |

| Error | Text |
| --- | --- |
| A | `Too many API requests by single Worker invocation. To configure this limit, refer to https://developers.cloudflare.com/workers/wrangler/configuration/#limits` |
| B | `Too many subrequests by single Worker invocation. To configure this limit, refer to https://developers.cloudflare.com/workers/wrangler/configuration/#limits` |

Findings:

| # | Finding |
| --- | --- |
| 1 | The limit counts D1 calls, not statements. One `batch()` is 1 call for any N (1 to 5,000 tested). One `exec()` is 1 call. |
| 2 | On this Free plan account, the limit is 1,000 D1 calls for each invocation, not the 50 of the D1 limits page ("Queries per Worker invocation (read subrequest limits): 1000 (Workers Paid) / 50 (Free)", read 2026-10-17). The same 1,000 in a fetch handler and in a cron handler. |
| 3 | D1 calls and `fetch()` subrequests have separate counts. `fetch()` stops at 50 on Free (the wrangler `limits.subrequests` default: 50 Free, 10,000 Paid, at most 10,000,000 Paid). 30 D1 calls did not lower the 50 fetches. |
| 4 | The D1 limits page also says: "Limits for individual queries ... apply to each individual statement contained within a batch statement." That is the size and time limits of one statement, not the count. |
| 5 | A cron run of 233 s with 1,000 D1 calls was not stopped. |
| 6 | The Free plan refuses each `[limits]` block (also `subrequests` alone) with the CPU error. So this run could not check if `limits.subrequests` also sets the D1 count. |

Not measured: the Paid plan. The docs give 1,000 for Paid, the same value that the Free account showed.

## Q49: placement

Workers `rocplat-test-q49-default` (no placement), `rocplat-test-q49-smart` (`[placement] mode = "smart"`), `rocplat-test-q49-hint` (`[placement] region = "aws:eu-central-1"`, added during the run because Smart Placement did not move). One D1 `rocplat-test-q49-d1`: primary `EEUR`, served from colo `PRG`. Seed: 1,000 releases, 50 groups.

| Route | D1 calls | What |
| --- | --- | --- |
| `/closure` | 1 batch | Recursive closure CTE of 2 groups (200 release rows), then `log_size`. Like R-AP3 with R-AP41. |
| `/chain3` | 3, one after the other | `log_size`, then the releases of a group, then their deps. Shows the cost of each round trip. |
| `/publish` | 2 | A read that can stop the request, then 1 write batch of 4 statements (insert, insert, update, select). Like R-AP8 with R-AP41. |
| `/closure_s`, `/chain3_s` | 1, 3 | The same in `withSession('first-unconstrained')` |

Clients: a Durable Object for each `locationHint`, and this machine.

| Hint | Colo of the Durable Object (`/cdn-cgi/trace`) | Hint kept? |
| --- | --- | --- |
| `wnam` | `DFW` | Yes (`DFW` is in North America, central) |
| `weur` | `LHR` | Yes |
| `apac` | `KIX` | Yes |
| (this machine) | `TBS` | - |

The ingress colo that each target saw (`request.cf.colo`) was the colo of the client in each sample.

### Placement facts

| Item | Result |
| --- | --- |
| Smart Placement | Never moved. Status `INSUFFICIENT_INVOCATIONS` from the deploy (19:38:31) to the end (20:38). `last_analyzed_at` stayed 19:38:31, so the analysis did not run again in 1 h. The traffic: 1,560 warm-up requests (`/chain3`, 3 D1 calls each) in 56 min, 390 from each of the 4 colos, plus about 250 measure requests. Each answer had `cf-placement: local-<client colo>`. The docs give no request count ("enough requests from multiple locations") and say "up to 15 minutes" to analyze. |
| Placement hint `placement.region = "aws:eu-central-1"` | Accepted on the Free plan. Applied from the first request: `cf-placement: remote-FRA` for each request from each colo. API: `{"mode":"targeted","target":[{"region":"aws:eu-central-1","type":"region"}]}`. |
| D1 read replication | Turned on with the API on the Free plan: `PUT /accounts/<id>/d1/database/<id>` with `{"read_replication":{"mode":"auto"}}`. A `WNAM` replica answered after about 1 min. |
| Replicas seen | `WNAM` replica in `DFW`, `APAC` replica in `ICN`. A session from `LHR`, `TBS` or `FRA` went to the primary in `PRG` each time (no `WEUR` replica showed). 1 of 8 session reads from `KIX` went to the primary (276 ms). |

### D1 time for each call (time in the Worker, the clock moves at I/O)

| From (Worker colo) | To | ms for each call, median | Source |
| --- | --- | --- | --- |
| `FRA` (hint) | primary `PRG` | 24 | `/closure` 25, `/chain3` 73 / 3, `/publish` 68 / 2 |
| `LHR` | primary `PRG` | 30 | `/closure` 29 to 33, `/chain3` 90 / 3 |
| `TBS` | primary `PRG` | 70 | `/closure` 66 to 72, `/chain3` 207 / 3 |
| `DFW` | primary `PRG` | 152 | `/closure` 153, `/chain3` 450 / 3 |
| `KIX` | primary `PRG` | 245 | `/closure` 245, `/chain3` 736 / 3 |
| `DFW` | replica `DFW` | 12 to 14 | `/closure_s` 13 to 15, `/chain3_s` 33 to 36 / 3 |
| `KIX` | replica `ICN` | 49 | `/closure_s` 48 to 49, `/chain3_s` 147 to 151 / 3 |

The 200 rows of `/closure` add little: `/closure` (1 batch, 200 rows) and one call of `/chain3` (20 rows) cost about the same.

### Client time, median (min to max) in ms

Round 0 of each run is left out (a cold isolate). n is the count of samples. Raw: `results/q49.jsonl`, all phases: `results/q49-summary.md`.

`/closure` (1 call) and `/closure_s`:

| Placement | wnam (DFW) | weur (LHR) | apac (KIX) | local (TBS) |
| --- | --- | --- | --- | --- |
| default | 161 (159-165) n=18 | 38 (36-56) n=18 | 250 (244-261) n=18 | 89 (83-98) n=18 |
| smart | 164 (159-168) n=18 | 41 (37-48) n=18 | 252 (248-263) n=18 | 89 (83-104) n=18 |
| hint | 184 (176-234) n=8 | 59 (51-92) n=8 | 271 (260-307) n=8 | 117 (108-139) n=8 |
| default + session | 22 (21-25) n=8 | 38 (36-43) n=8 | 54 (52-276) n=8 | 87 (85-94) n=8 |
| hint + session | 186 (178-193) n=4 | 68 (57-86) n=4 | 275 (266-283) n=4 | 125 (111-133) n=4 |

`/chain3` (3 calls) and `/chain3_s`:

| Placement | wnam (DFW) | weur (LHR) | apac (KIX) | local (TBS) |
| --- | --- | --- | --- | --- |
| default | 465 (460-470) n=18 | 104 (97-128) n=18 | 741 (730-755) n=18 | 229 (222-351) n=18 |
| smart | 465 (460-471) n=18 | 108 (97-122) n=18 | 739 (729-770) n=18 | 233 (225-307) n=18 |
| hint | 241 (226-315) n=8 | 109 (91-120) n=8 | 334 (307-356) n=8 | 176 (161-215) n=8 |
| default + session | 48 (44-54) n=8 | 104 (99-110) n=8 | 157 (147-166) n=8 | 228 (220-233) n=8 |
| hint + session | 243 (238-267) n=4 | 127 (115-138) n=4 | 334 (329-338) n=4 | 182 (161-190) n=4 |

`/publish` (2 calls):

| Placement | wnam (DFW) | weur (LHR) | apac (KIX) | local (TBS) |
| --- | --- | --- | --- | --- |
| default | 334 (330-367) n=14 | 96 (88-186) n=14 | 514 (507-541) n=14 | 184 (174-236) n=14 |
| smart | 334 (330-337) n=14 | 97 (91-106) n=14 | 523 (511-594) n=14 | 186 (178-298) n=14 |
| hint | 235 (219-260) n=8 | 104 (93-281) n=8 | 322 (308-339) n=8 | 161 (153-179) n=8 |

Smart rows: the smart Worker ran at the client colo (`local-*`) in each sample, so it is the same as default.

### What the numbers show

| # | Finding |
| --- | --- |
| 1 | A remote placement adds one hop from the client colo to the Worker: `DFW` 159 ms, `KIX` 246 ms, `LHR` 35 ms, `TBS` 93 ms (client time minus D1 time of the hint Worker). The hop is about the same as one D1 round trip from that colo. |
| 2 | So a route with 1 D1 call is slower with a remote placement: `/closure` +23 ms (`DFW`), +21 (`LHR`), +21 (`KIX`), +28 (`TBS`). A route with 2 or more calls one after the other is faster from far colos: `/publish` 334 to 235 ms (`DFW`), 514 to 322 (`KIX`), 184 to 161 (`TBS`), but 96 to 104 (`LHR`). |
| 3 | Read replication with a session helps a 1-call read much more than any placement: `/closure` 161 to 22 ms (`DFW`), 250 to 54 ms (`KIX`). It does not help `LHR` or `TBS`, which go to the primary. |
| 4 | A remote placement removes the replica gain: `/closure_s` on the hint Worker from `DFW` is 186 ms (the Worker in `FRA` reads the primary), against 22 ms with the default placement. |
| 5 | Smart Placement changes all fetch routes of the Worker at once. The registry reads (R-AP41: 1 call) are many more than the writes (at most 2 calls). So the placement that is best for the reads is best for the Worker. |

## Proposed answers

| Q | Answer | Numbers for the rule text |
| --- | --- | --- |
| Q47 | A batch counts as 1. The limit counts D1 calls (`run`, `all`, `first`, `batch`, `exec`), not statements. | 1,000 D1 calls for each invocation, in a fetch and in a cron handler (measured on Free; the docs give 1,000 for Paid and 50 for Free, and the Free value of the docs is not what the edge does). `fetch()` subrequests have their own count: 50 on Free, 10,000 on Paid by default (`limits.subrequests`, at most 10,000,000). |
| Q47 for R-PU23, R-PU37 | With R-PU37 (1 claim statement, then 1 GitHub read and 1 D1 batch for each row), a run of R rows uses 1 + R D1 calls and R + (token reads) fetches. 500 rows: 501 D1 calls (under 1,000) and about 501 fetches (under 10,000 on Paid). The count that limits R is the fetch count on Free (50), not D1. | Keep 500 on Paid. The bound: R at most 1,000 minus the other D1 calls of the run, and at most the subrequest limit minus the other fetches. On Free: at most 48 rows. |
| Q49 | Default placement. Turn on read replication, and run each read route in a session (`first-unconstrained`), as R-AP41 row 5 says. Do not use Smart Placement. | Reads with 1 call: default with a replica 22 ms (`DFW`), 54 ms (`KIX`); a remote placement adds 21 to 28 ms to each 1-call route and removes the replica gain. Smart Placement did not move in 1 h with 1,560 requests from 4 colos. |

Option, not proposed: if writes from far colos (for example GitHub Actions runners in North America) must be faster, a separate write Worker with `placement.region` near the D1 primary saves about 100 ms (`DFW`) to 190 ms (`KIX`) on a 2-call publish. The placement hint works on the Free plan.

## What this does not prove

| Item | Status |
| --- | --- |
| Paid plan | Not tested. The D1 count 1,000 for Paid is from the docs. `limits.subrequests` could not be set (Free refuses each `[limits]` block), so this run did not check if it also changes the D1 count. |
| Smart Placement after more time or traffic | Not seen. It can move after more than 1 h, or with more requests. If it moves, finding 2 gives the cost: each 1-call route gets slower by about the hop. |
| A primary in another region | The primary was `EEUR` (`PRG`), the default for a database made from `TBS`. A primary made with `--location` (for example `enam`) changes the times of each colo, not the shape of the result. |
| Read after write (Q46) | Not tested. All session reads used `first-unconstrained` with no bookmark. |
| Queue sends and the subrequest count | Not tested (R-PU37 row 5 sends queue messages in the reconcile). |
| Load | Not tested on purpose. About 2,330 requests to the Q49 targets and about 3,300 D1 calls in the Q47 loops. |
