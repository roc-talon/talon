# Ledger of the remote D1 run for Q27, 2026-10-18

Account: the account that wrangler is logged in to on this machine (Workers Free plan), wrangler 4.151.0, OAuth login.

Rule: each resource of this run has a name that starts with `rocplat-test-`. The run never changes a resource that is not in the table "Created". The bucket `rocplat-test-r2` is from an earlier run (`cloudflare-workers/edge/ledger.md`). This run does not touch it.

## Start state (07:36 UTC, before the first create)

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
| 07:37:33 | D1 | `rocplat-test-d1-remote` | 57b87b9b-f6c9-4d7d-b099-fe954b9d1eb3 | 07:42:38 |

## End state (07:42 UTC)

| Kind | Items | Same as the start? |
| --- | --- | --- |
| Workers | `bellup-sveltekit-edge` | Yes |
| D1 | `[]` | Yes |
| R2 | `bellup-weur-0`, `bellup-weur-0-preview`, `lottery0weur`, `rocplat-test-r2` (not of this run, not touched) | Yes |
| KV | the 2 `bellup-sveltekit-edge-*` namespaces | Yes |
| Queues | none | Yes |
| Durable Object namespaces | none | Yes |

Raw lists: `results/start-lists.txt` and `results/end-lists.txt`. `diff` of the 2 lists (without the time line): no difference.

Note: the run deployed no Worker. Wrangler remote bindings (`getPlatformProxy`, `remote = true`) open a remote proxy session for each run ("Establishing remote connection..."). That session made no entry in the Workers list (checked at 07:38 UTC during the run, and at the end).
