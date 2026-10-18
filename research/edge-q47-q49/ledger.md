# Ledger of the edge run for Q47 and Q49, 2026-10-17

Account: the account that wrangler is logged in to on this machine (Workers Free plan), wrangler 4.151.0, OAuth login. workers.dev subdomain: `bellup`. Client machine colo: `TBS`.

Rule: each resource of this run has a name that starts with `rocplat-test-`. The run never changes a resource that is not in the table "Created". The bucket `rocplat-test-r2` is from the earlier run (`cloudflare-workers/edge/ledger.md`). Another job deletes it. This run does not touch it.

## Start state (19:31 UTC, before the first create)

| Kind | Command | Items |
| --- | --- | --- |
| Workers | Workers API `GET /workers/scripts` | `bellup-sveltekit-edge` (modified 2023-05-15) |
| D1 | `wrangler d1 list --json` | none (`[]`) |
| R2 | `wrangler r2 bucket list` | `bellup-weur-0`, `bellup-weur-0-preview`, `lottery0weur`, `rocplat-test-r2` (not of this run) |
| KV | `wrangler kv namespace list` | `bellup-sveltekit-edge-bellup_kv_0`, `bellup-sveltekit-edge-bellup_kv_0_preview` |
| Queues | `wrangler queues list` | none |
| Durable Object namespaces | Workers API `GET /workers/durable_objects/namespaces` | none |

Raw lists: `results/start-lists.txt`.

## Created

| Time (UTC) | Kind | Name | Id | Deleted (UTC) |
| --- | --- | --- | --- | --- |
| 19:33:22 | D1 | `rocplat-test-q47-d1` | a79e99ab-689e-4b0c-81ef-2803088e68ad | 19:48:00 |
| 19:33:34 | Worker | `rocplat-test-q47` | https://rocplat-test-q47.bellup.workers.dev | 19:47:58 |
| 19:37:51 | D1 | `rocplat-test-q49-d1` | ff3f556c-5f09-4ca2-b59c-8bb7110fe16a | 20:38:20 |
| 19:38:04 | Worker | `rocplat-test-q49-default` | https://rocplat-test-q49-default.bellup.workers.dev | 20:38:00 |
| 19:38:16 | Worker | `rocplat-test-q49-smart` | https://rocplat-test-q49-smart.bellup.workers.dev | 20:38:05 |
| 19:38:28 | Worker | `rocplat-test-q49-client` | https://rocplat-test-q49-client.bellup.workers.dev | 20:38:15 |
| 19:40:57 | D1 setting | `rocplat-test-q49-d1` | read_replication mode auto (API PUT /d1/database/ff3f556c-...), goes with the database | 20:38:20 |
| 19:47:50 | Cron trigger | `rocplat-test-q47` | '* * * * *' on the Worker, 19:37 to 19:48 (removed by API PUT schedules []) | 19:47:50 |
| 19:49:24 | Worker | `rocplat-test-q49-hint` | https://rocplat-test-q49-hint.bellup.workers.dev (placement.region aws:eu-central-1) | 20:38:10 |

Note: the run made no KV, R2, Queue or custom domain and no zone route. The Durable Object namespace of `rocplat-test-q49-client` (class `Client`, SQLite) was made by its deploy and went with the Worker (Durable Object list empty at the end).

## End state (20:38 UTC)

| Kind | Items | Same as the start? |
| --- | --- | --- |
| Workers | `bellup-sveltekit-edge` | Yes |
| D1 | `[]` | Yes |
| R2 | `bellup-weur-0`, `bellup-weur-0-preview`, `lottery0weur`, `rocplat-test-r2` (not of this run, not touched) | Yes |
| KV | the 2 `bellup-sveltekit-edge-*` namespaces | Yes |
| Queues | none | Yes |
| Durable Object namespaces | none | Yes |

Raw lists: `results/start-lists.txt` and `results/end-lists.txt`. `diff` of the 2 lists (without the time line): no difference.
