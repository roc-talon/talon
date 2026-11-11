# Deploy of the registry Worker

The command is `tln run deploy` in `worker/`. `tln run deploy-dry` does the same, but no remote change.

## Steps of `deploy`

| # | Step | Does | Who |
| --- | --- | --- | --- |
| 1 | `scripts/test.sh w0 wbuild w2 wtrap` (in the talon root) | The registry tests, on a build of their own in `.work/worker/<stamp>/` | `talon.toml` |
| 2 | `@check` | `roc build` of `app.wasm`, then `roc-cfw sync --check` | `talon.toml` |
| 3 | `roc-cfw deploy` | Preflight, record the live version, before reads of the `same-body` routes, `d1 migrations apply DB --remote`, `wrangler versions upload` and `versions deploy`, smoke checks, rollback when a check fails | `roc-cfw`, settings in `worker/roc-cfw.toml` |
| 4 | Log tail | `wrangler tail`: look for errors for some minutes | Manual |
| 5 | Dead letter queue | `wrangler queues` / the dashboard: `talon-index-dlq` must have no new message | Manual |

`roc-cfw deploy --dry-run` (the last step of `deploy-dry`) does the preflight and `wrangler deploy --dry-run` only.

## Exit codes of `roc-cfw deploy`

| Code | Meaning | State |
| --- | --- | --- |
| 0 | All steps passed | New version live |
| 1 | Failure before the new version got traffic | Old version live (applied migrations stay) |
| 2 | Bad command line or `roc-cfw.toml`, a tool does not start | No change |
| 3 | Smoke check failed, rollback passed | Old version live |
| 4 | Smoke check failed, no rollback | New version live: run the rollback command that was printed |

A migration is never rolled back. Write migrations that the old code can use.

## Smoke checks

`worker/roc-cfw.toml` lists them. `same-body` only for routes whose body does not change by itself (no `/v1/toolchains`, `/v1/sweeps/*`, `.../compat`, lists that grow). A new route that matters gets a `[[deploy.smoke]]` entry.

## Rules for the operator

| Rule | Reason |
| --- | --- |
| Run `deploy` from `worker/` | `roc-cfw.toml` and `.roc-cfw/` are read from the current directory |
| Keep `CLOUDFLARE_API_TOKEN` in the environment of `tln run` | `tln run` reads no `.env` file (R-RUN9) |
| Do not use `wrangler deploy` by hand | `roc-cfw deploy` records the rollback target and checks the new version |

## Before the first run

| Need | Command |
| --- | --- |
| The compiler of the `roc:` pin of `worker/main.roc` for Talon | `tln roc install nightly-2026-11-06-34f137a` (else step 2 stops with `error[consent]`) |
| Node 26 or later, and Miniflare (the tests) | see `TESTING.md` 9 |
| `CLOUDFLARE_API_TOKEN` for `wrangler` | environment (not the repo `.env`: `tln run` reads no `.env`) |

The build of step 2 gives the same `app.wasm` bytes as the build of the tests (checked 2026-11-11: sha256 `91c9d9dd...`), so `deploy` builds again and does not copy the tested build.
