# Slice 121: first deploy (2026-11-06)

| Item | State |
| --- | --- |
| Worker | `talon-registry`, version d895d7e4, at `https://talon-registry.bellup.workers.dev` (the account's workers.dev name). Platform 0.0.6 with a local patch of `.roc-cfw/index.js` (below). |
| D1 | `talon-registry` (id in `worker/wrangler.toml`), region EEUR. Migrations 0001 and 0002 applied with `wrangler d1 migrations apply DB --remote`. |
| Queues | `talon-index` and `talon-index-dlq`, made with `wrangler queues create`. |
| Settings | `[vars]` of `worker/wrangler.toml`: AUDIENCE, ISSUES_URL, BOT_REPOSITORY_ID 1434744226, BOT_WORKFLOW_REF (branch `main`), GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID. |
| Secrets | CONTRIBUTOR_KEY and TOKEN_KEY made by `make-keys.mjs`, kept in `~/.config/talon-registry/` (mode 600). GITHUB_WEBHOOK_SECRET and GITHUB_APP_KEY (converted to PKCS#8 with `openssl pkcs8 -topk8 -nocrypt`) from `~/.config/talon-indexer/`. Never in the repo. |
| R-PU45 edge check | PASS (`dlq-check/RESULT.md`). |

## Platform fault and local patch

Platform 0.0.6 failed the real deploy with code 10021: the shim checked the bindings against `env` at global scope (`cf.env`), and at the upload validation that `env` has no D1 binding. The platform session gave a fix (the check runs only at the first event) for 0.0.7. The local copy `worker/.roc-cfw/index.js` (gitignored) has that fix: the import of `cf` and the load-time check are deleted. A sync from 0.0.7 replaces the file.

## Checks on the live Worker

| Request | Result |
| --- | --- |
| GET /v1/toolchains | 200 `{"toolchains":[],"more":false}` (the daily job at 03:00 UTC fills it) |
| GET /v1/packages?short=a | 200 |
| POST /v1/releases (ingest of roc-semver 0.2.0) | 201, log_index 1, 2.2 s |
| GET /v1/packages/Karakatiza666/roc-semver/releases | 200 with the release |
| GET /v1/compat_hints?audit=5, /v1/sweeps/<tag> | 200, 404 (no toolchain yet) |
| POST /v1/webhooks/github, ping | 202 with a good signature, 401 with a bad one |

## Not done (needs the user)

| Item | Why |
| --- | --- |
| `registry.roc-talon.org` | The zone is on Porkbun DNS, not Cloudflare. A Worker custom domain needs the zone on Cloudflare, and the API token has no zone rights. |
| GitHub App webhook URL | Set in the App settings of `Talon Indexer` to `<registry>/v1/webhooks/github` with the same secret. |
| P2 exit measures (closure p50, load test, step 12g) | Next part of slice 121. |
