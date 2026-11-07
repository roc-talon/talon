# Slice 121: first deploy (2026-11-06)

| Item | State |
| --- | --- |
| Worker | `talon-registry`, version 7abfc3e0 (platform 0.0.7, no local patch), at `https://registry.roc-talon.org` (custom domain, 2026-11-06, after the user moved the zone to Cloudflare). The first version d895d7e4 was at `https://talon-registry.bellup.workers.dev`; that address is off since the custom domain (404). |
| D1 | `talon-registry-weur` (id in `worker/wrangler.toml`), region WEUR (2026-11-07, the user asked for the primary near Barcelona). Migrations 0001 and 0002 applied with `wrangler d1 migrations apply DB --remote`. Read replication `auto`. The first database `talon-registry` (EEUR) is deleted. |
| Queues | `talon-index` and `talon-index-dlq`, made with `wrangler queues create`. |
| Settings | `[vars]` of `worker/wrangler.toml`: AUDIENCE, ISSUES_URL, BOT_REPOSITORY_ID 1434744226, BOT_WORKFLOW_REF (branch `main`), GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID. |
| Secrets | CONTRIBUTOR_KEY and TOKEN_KEY made by `make-keys.mjs`, kept in `~/.config/talon-registry/` (mode 600). GITHUB_WEBHOOK_SECRET and GITHUB_APP_KEY (converted to PKCS#8 with `openssl pkcs8 -topk8 -nocrypt`) from `~/.config/talon-indexer/`. Never in the repo. |
| R-PU45 edge check | PASS (`dlq-check/RESULT.md`). |

## Platform fault and local patch

Platform 0.0.6 failed the real deploy with code 10021: the shim checked the bindings against `env` at global scope (`cf.env`), and at the upload validation that `env` has no D1 binding. The platform session gave a fix (the check runs only at the first event) for 0.0.7. The local copy `worker/.roc-cfw/index.js` (gitignored) has that fix: the import of `cf` and the load-time check are deleted. A sync from 0.0.7 replaces the file.

Platform 0.0.7 has the fix and replaces the local patch.

## Checks on the live Worker

| Request | Result |
| --- | --- |
| GET /v1/toolchains | 200 `{"toolchains":[],"more":false}` (only the compat bot fills it, with PUT /v1/toolchains/{tag}, R-AP6; the bot needs registry.roc-talon.org) |
| GET /v1/packages?short=a | 200 |
| POST /v1/releases (ingest of roc-semver 0.2.0) | 201, log_index 1, 2.2 s |
| GET /v1/packages/Karakatiza666/roc-semver/releases | 200 with the release |
| GET /v1/compat_hints?audit=5, /v1/sweeps/<tag> | 200, 404 (no toolchain yet) |
| POST /v1/webhooks/github, ping | 202 with a good signature, 401 with a bad one |

## Not done (needs the user)

| Item | Why |
| --- | --- |
| GitHub App webhook URL | Done: on 2026-11-07 `app-hook.mjs` reads `https://registry.roc-talon.org/v1/webhooks/github` (the user set it). Before, it was `https://example.com/v1/webhooks/github`. The user sets it to `https://registry.roc-talon.org/v1/webhooks/github`: in the App settings, or `node research/deploy-121/app-hook.mjs 5572595 ~/.config/talon-indexer/private-key.pem https://registry.roc-talon.org/v1/webhooks/github`. The automatic change was refused by the agent permission check. |
| P2 exit measures (closure p50, load test, step 12g) | Next part of slice 121. |

## D1 read replication and the closure time (2026-11-06)

Design Q49 asks for read replication on. The first deploy did not set it, so it was set by the API (`read_replication.mode = auto`) after the custom domain.

`closure-p50.sh` and a baseline, from a client in Greece (edge colo ATH, RTT about 8 ms), 30 to 40 requests each, time to first byte minus the TLS setup:

| Request | p50 | p90 |
| --- | --- | --- |
| GET /nope (no D1 call) | 11 ms | 28 ms |
| POST /v1/closure, before replication | 86 ms | 101 ms |
| POST /v1/closure, 1.5 min after replication on | 77 ms | 114 ms |

So from ATH the closure is about 65 to 75 ms over the baseline, over the 50 ms target of Design 7 P2. The D1 primary is in EEUR, and a session from ATH probably goes to the primary (the probe of Registry 8 saw sessions from LHR, TBS and FRA go to the primary). One colo is not the P2 measure: the load test and a measure from several colos are still open.

## Move of D1 to WEUR (2026-11-07)

The user asked for the primary in Barcelona and a replica in San Jose. D1 gives a region hint only (no city), and it puts the replicas itself (one for each region, no choice). So the new database has `--location weur`. A database cannot change its region, so the move is a new database.

| Step | Result |
| --- | --- |
| `wrangler d1 export --no-schema` of the old database | Not used: the export writes the 64-bit ids as floats (for example `-7163292474072844000`), so the ids are wrong. |
| New database, migrations 0001 and 0002 | `talon-registry-weur`, running in WEUR |
| The two releases again | `POST /v1/releases` (ingest) for roc-semver 0.2.0 and 0.1.0: log_index 1 and 2, provenance `ingest` (0.1.0 was `poll` before). |
| Deploy | version e9ff97ed |
| Read replication | `auto`, set by the API |
| Old database `talon-registry` (EEUR) | Deleted on 2026-11-07 with the user's approval. |

Closure from ATH after the move: p50 108 ms, p90 123 ms (40 requests). It was 77 ms with the EEUR primary. WEUR is farther from Greece than EEUR, so this is expected. One colo only.

Fault found: about 1 to 2 percent of requests on all routes get 503 with the Cloudflare body `error code: 500` (5 of 400, 1 of 300, 1 of 40). Worker analytics show 0 errors for the same time, so the requests do not get to the Worker code. Reported to the platform session (start of a cold isolate with the 6 MB wasm is one possible cause, not verified).

## Deploy of platform 0.0.8 with slices 227 and 228 (2026-11-07)

Version fb9bc036 at 14:27 UTC. wasm 6,361,855 to 3,393,205 bytes, largest function 1,246,912 to 176,616 bytes (research/bigfn, cloudflare-workers/research/bigfn2). Wrangler: "Worker Startup Time: 15 ms". Checks after the deploy: 5 routes as expected, 462 requests of mixed-ro and closure with 0 mismatches and 0 503s.
The old bench database `talon-registry-bench` is deleted (the bench uses `talon-registry-bench-2`).
