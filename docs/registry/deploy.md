# Deploy of the registry Worker

The command is `tln run deploy` in `worker/`. `tln run deploy-dry` does the same, but no remote change.

## Steps of `deploy`

| # | Step | Does | Who |
| --- | --- | --- | --- |
| 1 | `scripts/test.sh w0 wbuild w2 wtrap` (in the talon root) | The registry tests, on a build of their own in `.work/worker/<stamp>/` | `talon.toml` |
| 2 | `@check` | `roc build` of `app.wasm`, then `roc-cfw sync --check` | `talon.toml` |
| 3 | `roc-cfw deploy` | Preflight, record the live version, before reads of the `same-body` routes, `wrangler versions upload`, `d1 migrations apply DB --remote` (after the upload, before the deploy; the pending list must be empty after it), `versions deploy`, smoke checks, rollback when a check fails | `roc-cfw`, settings in `worker/roc-cfw.toml` |
| 4 | Triggers, only when `[triggers] crons` or `routes` in `wrangler.toml` changed | `wrangler triggers deploy` (in `worker/`, token loaded). Then read the schedules (dashboard: Worker, Settings, Trigger Events) | Manual. `wrangler versions deploy` does not send triggers: they are not part of a version (it prints `No non-versioned settings to sync. Skipping...`). Found at the first deploy of slice 257, 2026-11-23. |
| 5 | Log tail | `wrangler tail`: look for errors for some minutes | Manual |
| 6 | Dead letter consumer | In the log tail, look for the output of the dead-letter consumer (`IndexQueue.dead!`). The registry Worker is the consumer of `talon-index-dlq`, so a dead message is taken off at once and the queue never shows a count. | Manual |

`roc-cfw deploy --dry-run` (the last step of `deploy-dry`) does the preflight and `wrangler deploy --dry-run` only.

## Exit codes of `roc-cfw deploy`

| Code | Meaning | State |
| --- | --- | --- |
| 0 | All steps passed | New version live |
| 1 | Failure before the new version got traffic | Old version live (applied migrations stay) |
| 2 | Bad command line or `roc-cfw.toml`, a tool does not start | No change |
| 3 | Smoke check failed, rollback passed | Old version live |
| 4 | Smoke check failed, no rollback | New version live: run the rollback command that was printed |

A migration is never rolled back. It runs after the upload, so a failed upload changes no schema. Write migrations that the old code can use.

## Smoke checks

`worker/roc-cfw.toml` lists them. `same-body` only for routes whose body does not change by itself. Not `/v1/toolchains`, `/v1/sweeps/*`, `.../compat`, lists that grow: they are status only. The releases routes of a package (R-AP1, R-AP13) end with the `checked` item (R-AP29): `checked_at` and `stale` change with no write of the deploy. They use `same-body = true` with `ignore = ["/checked"]` (roc-cfw 0.0.3), so every other member is compared. The artifact route (R-AP2) has no `checked` item, so it is compared whole. Each request has a time limit of `timeout = 10` s (the slowest route took 0.36 s).

## Rules for the operator

| Rule | Reason |
| --- | --- |
| Run `deploy` from `worker/` | `roc-cfw.toml` and `.roc-cfw/` are read from the current directory |
| Load the token first: from the talon root, `set -a; . ./.env; set +a` (the file is gitignored, mode 600; never print it) | `tln run` reads no `.env` file (R-RUN9) |
| Run in a capped scope: `systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout <T> tln run deploy` (see Time limit) | A job that dies at the cap is a finding; never raise the cap |
| Do not use `wrangler deploy` by hand | `roc-cfw deploy` records the rollback target and checks the new version |

## Before the first run

| Need | Command |
| --- | --- |
| The compiler of the `roc:` pin of `worker/main.roc` for Talon | `tln roc install nightly-2026-11-06-34f137a` (else step 2 stops with `error[consent]`) |
| Node 26 or later, and Miniflare (the tests) | see `TESTING.md` 9 |
| `CLOUDFLARE_API_TOKEN` for `wrangler` | load `.env` into the shell (Rules for the operator) |

The build of step 2 gives the same `app.wasm` bytes as the build of the tests (checked 2026-11-11: sha256 `91c9d9dd...`), so `deploy` builds again and does not copy the tested build.

## Time limit

| Item | Value |
| --- | --- |
| Measured `tln run deploy-dry` (tests 255 s, build, dry run), 2026-11-11 | about 413 s |
| `<T>` for `timeout` | 900 s (about twice, rounded up). `deploy` adds migrations, upload and smoke checks. |
| Command | `systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 900 tln run deploy` |

## First deploy with the log (slice 257, Design Q636)

The registry Worker writes the log tiles to the R2 bucket `talon-log` and signs the checkpoint with the secret `LOG_KEY`. Do these steps once, before `tln run deploy`. Load the token first (Rules for the operator). Without the bucket, `wrangler versions upload` fails. Without the secret, each cron run of the log fails with one log line (`log step failed`) and the log routes answer 404.

| # | Step | Command (in `worker/`) | Note |
| --- | --- | --- | --- |
| 1 | Make the bucket | `wrangler r2 bucket create talon-log` | One time. The binding is `LOG` in `wrangler.toml`. |
| 2 | Make the key | `node ../research/log-key/log-key.mjs make --signer-out ~/.config/talon-log/signer.key --verifier-out ~/.config/talon-log/verifier.key` | Make the directory first (`mkdir -m 700 ~/.config/talon-log`). The tool refuses to overwrite and never prints the signer key text. Keep both files. Back up the signer file: a lost key cannot be made again. |
| 3 | Set the secret | `wrangler secret put LOG_KEY < ~/.config/talon-log/signer.key` | The signer file has no newline (the tool writes none). Do not use `echo` or a here-string: they add a newline. Do this before the deploy of step 4: the old code ignores the secret. |
| 4 | Deploy | `tln run deploy` | See Steps of `deploy`. |
| 5 | Send the cron | `wrangler triggers deploy` | `tln run deploy` does not send the new cron (Steps of `deploy`, step 4). It also sends the custom domain again, with no change. |
| 6 | Check the log | see below | |

### The cron `2-59/5 * * * *` (confirmed 2026-11-23)

| Item | State |
| --- | --- |
| Why this text | The reconcile has `*/5 * * * *`. `Worker.cron` takes one handler for each text. The log job gets its own text, and it starts 2 min after the reconcile (Design Q636 (9)). |
| Docs | The Cloudflare cron docs list `*`, `,`, `-` and `/`. They give no example of a range with a step. Wrangler on this machine has no check of the text (no cron parser found in `wrangler-dist`). Miniflare passes any text to the handler. So this is NOT confirmed. |
| Result | `wrangler triggers deploy` accepted the text on 2026-11-23 (03:40 UTC). The first run of the log wrote its objects at 03:52:08 UTC, 8 s after the 03:52 slot. Note: `wrangler tail` did not show that scheduled event. To check a run, read the `last_modified` time of the `checkpoint` object, not the tail only. |
| Fallback (Design Q636 (9)) | If the edge refuses `2-59/5`, or never runs it: remove the text from `LogStep.cron`, `main.roc` and `wrangler.toml`, and run the step in the 5-minute handler before the reconcile. This is a code change (a new slice step with tests), not an operator step. |

### The first catch-up run (backfill)

| Item | Value |
| --- | --- |
| What it does | The first run finds no checkpoint and builds the log from size 0: all leaves of P2 (releases and compiler assets, R-SG2, R-SG3). The first checkpoint is the size of D1 at that time (Design Q636 (11)). |
| Steps | At most 65,536 leaves for each step. The cron loops step by step in one run until the checkpoint size is the largest `idx`. So `ceil(leaves / 65536)` steps in 1 run; no second run is needed for less than about 1M leaves (about 15 min of the cron limit). |
| Estimate of the leaves | Not measured. `research/deploy-121/awesome/RESULT.md`: 17 new releases in the last ingest run (231 answers 200 or 201 for 347 attempts, most of them repeats). Compiler leaves: about 1 for each target for each nightly tag. A guess is below 5,000 leaves in total, so 1 step in 1 cron run. Measure it first (read only): `wrangler d1 execute DB --remote --command "SELECT MAX(idx) FROM log"`. |
| Time | The first checkpoint is there at the first run after the deploy: minute 2, 7, 12 ... |

### How to check the log

| # | Check | Command | Expect |
| --- | --- | --- | --- |
| 1 | The checkpoint | `curl -s https://registry.roc-talon.org/log/checkpoint -o checkpoint.txt` (outside the repository) | 200, `text/plain; charset=utf-8`, `cache-control: max-age=5`. Before the first run: 404 `not-found`. |
| 2 | Its signature | `node research/log-key/log-key.mjs verify --verifier-file ~/.config/talon-log/verifier.key --checkpoint-file checkpoint.txt` | `ok: registry.roc-talon.org/log size <N> root <hash>` |
| 3 | The size | Compare `<N>` with `SELECT MAX(idx) FROM log` | Equal, or smaller by the leaves of the last minutes |
| 4 | A tile | `curl -sI https://registry.roc-talon.org/log/tile/0/000` (full tile for N of 256 or more) or `.../log/tile/0/000.p/<N>` for a smaller N | 200, `application/octet-stream`, `cache-control: max-age=31536000, immutable` |
| 5 | The entries | `curl -s https://registry.roc-talon.org/log/tile/entries/000.p/<N>` for N below 256 | Lines `<group> <version> <hash> <time>` with 2-byte length prefixes |
| 6 | The log tail | `wrangler tail` | `log wrote` after a write. No `log step failed`. |
| 7 | The edge cache of a tile | Ask the same tile twice; look at `cf-cache-status` | The second answer is `HIT` (open check: Miniflare is not the edge, slice 257d) |

### Smoke checks for `/log` (proposal, not in `roc-cfw.toml` yet)

See the slice file, section 257e. They are status only: the checkpoint changes at each write.

### Rollback

| Item | State after a rollback |
| --- | --- |
| The old version | Live. It has no `LOG` binding and no log routes: `/log/...` is 404 and the log cron does not run (the cron text can stay in the account until the next deploy). |
| The bucket `talon-log` and its objects | Stay. They are write-once tiles and a checkpoint. They are not read. Harmless. |
| The secret `LOG_KEY` | Stays. Harmless. |
| The next deploy of the log code | The first step reads the checkpoint, finds the tiles of the old size and goes on. The tiles are a function of the leaves, so a step also repairs a stop in the middle. Do not delete the bucket: the key and the checkpoint would not match a new bucket that has other tiles. If you must start again, make a new bucket and a new key (a new log). |

### The bench

See the slice file, section 257e. The bench has its own bucket `talon-log-bench`, its own key and origin, and no cron. The platform session deploys it.
