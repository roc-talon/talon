# Registry request bench

Request scenarios of the registry use cases, and a driver that sends them to a base URL.
The driver writes one JSONL line for each request.
The platform session uses the lines to compare memory allocators (task T5).

## Files

| File | Use |
| --- | --- |
| `gen-scenarios.mjs` | Reads the read API of a registry and writes `scenarios/<name>.jsonl` and `scenarios/corpus.json` |
| `drive.mjs` | Sends the requests of the scenarios, writes the result lines, prints a table |
| `summary.mjs` | Reads result files, prints the same table, writes a CSV row for each scenario |
| `local.mjs` | Starts the Worker locally (`worker/tests/serve.mjs`) with a seed made from the corpus of another registry |
| `lib.mjs`, `discover.mjs` | Shared code (table, percentile, loopback check, corpus read) |
| `scenarios/` | The scenario files, made from `https://registry.roc-talon.org` on 2026-11-07 |

Node only (v26 here), no npm package.

## Usage

```
node research/bench/gen-scenarios.mjs --base <url> [--out-dir <dir>] [--seed N] [--mixed-size N]
node research/bench/drive.mjs --base <url> --scenario <name|a,b|all> [--repeat N] [--out <file.jsonl>]
        [--concurrency C] [--min-gap-ms N] [--timeout-ms N] [--dir <scenario dir>] [--quiet]
node research/bench/summary.mjs <file.jsonl> [<file.jsonl> ...] [--csv <out.csv>] [--by-colo]
node research/bench/local.mjs [--from <url>] [--dir <state dir>] [--port 8787] [--seed-only]
```

| Rule | Value |
| --- | --- |
| Order | Sequential. `--concurrency C` runs C requests at the same time |
| `--repeat N` | The scenario file is sent N times, in file order |
| `seq` | 0 based count of the request in the scenario, in order of start, across the repeats |
| Scenario order of `all` | Alphabetical, one after the other |
| Status mismatch | Recorded in the line, counted in the table. Never a crash, never a retry |
| No answer (network fault, timeout of 30 s) | A line with `status` 0 |
| Remote host (not loopback) | Read only. A scenario with a write request is refused (exit 2). `all` skips such scenarios and says so. Gap between 2 request starts: 100 ms or more |
| Write request | Any method but GET and HEAD, except `POST /v1/closure` (a query with a body, R-AP3, R-AP20) |
| `{{uniq}}` in a header or body | 32 lower-case hex digits, new for each sent request (the hint scenarios use it as `Talon-Contributor`, so each hint is new and the status is always 201) |
| Request headers | `user-agent: tln-bench/0` (not `tln/<v>`, so R-AP45 does not check it), `accept: application/json` |

## Line format

One JSON object in each line, 11 members, always all of them:

```
{"scenario":str,"seq":int,"method":str,"path":str,"status":int,"expected_status":int,
 "client_ms":number,"cf_ray":str|null,"colo":str|null,"ts":int,"stats":str|null}
```

| Member | Value |
| --- | --- |
| `client_ms` | Time from the start of the request to the last byte of the body (`performance.now`, 3 decimals) |
| `cf_ray` | The header `cf-ray`, or null (a local run has none) |
| `colo` | The part of `cf_ray` after the last `-`, or null |
| `ts` | Start of the request, ms since 1970 |
| `stats` | The raw header `x-roc-stats` (only a bench build sends it), else null. Not parsed |

Scenario file line (input): `{"method","path","json"?,"body"?,"headers"?,"expected_status"}`.

## Scenarios

Counts are for the corpus of 2026-11-07: 209 releases, 49 groups, 46 GitHub packages, 189 hashes, 7 nightly tags (34 toolchain rows).

| Scenario | Requests | Contents | Writes |
| --- | --- | --- | --- |
| `small` | 2 | `GET /v1/toolchains`, `GET /v1/does-not-exist` (404). The per-PR bench uses this one | no |
| `search` | 107 | `GET /v1/packages?short=<short name>` for 46 packages (cap 60), 10 with the full repo name, 1 unknown name, 10 with 5 `short` values, and 40 `?q=<prefix>` | no |
| `releases` | 68 | `GET /v1/packages/<owner>/<repo>/releases` for 46 packages (cap 300), 1 unknown repo (404), 20 `GET /v1/releases?group=<url form>`, `GET /v1/releases?after=0` (the largest answer of the reads) | no |
| `closure` | 62 | `POST /v1/closure`: 49 with 1 group (`tln add`, cap 60), 12 with 4 groups (some with 2 `hashes`, some with a `compilers` window), 1 with all groups and a window (`tln outdated`) | no |
| `compat` | 151 | `GET /v1/compat_hints?audit=100` and `=1000`, `GET /v1/sweeps/<tag>` for the 7 tags, 1 unknown tag (404), `GET /v1/artifacts/<hash>` for 100 hashes, 1 bad hash (404), `GET /v1/artifacts/<hash>/compat` for 40 hashes | no |
| `hints` | 31 | `POST /v1/compat` user hints: 10 each with 1, 5 and 9 rows, and one with no row (200). New `Talon-Contributor` for each request | yes, local only |
| `mixed` | 400 | A weighted mix (below) with the hint posts | yes, local only |
| `mixed-ro` | 400 | The same mix with no hint post. It runs on a remote host | no |

The mixed files have fixed lines (seed 1). A package in a class is picked with Zipf weights (rank r has weight 1/r), so a few packages get most of the requests, as in real use.

| Class of `mixed` | Weight | Reason |
| --- | --- | --- |
| closure, 1 group (`tln add`) | 12 | Each resolve calls the closure route (R-AP3: one round trip). Together the 3 closure classes are 35, the largest |
| closure, 3 to 4 groups (resolve) | 20 | The usual project has a few direct deps |
| closure, all groups (`tln outdated`) | 3 | Large body and answer, rare |
| toolchains | 15 | Read with the compiler list, `max-age=300` |
| short match | 15 | `tln add <name>` |
| q search | 3 | Display only (R-SN5), after "no match" |
| releases of a package | 10 | `tln info`, `tln outdated` |
| artifact | 8 | A hash lookup |
| artifact compat | 5 | `tln probe` and info |
| hint post (write) | 4 | After a build with a probe. Left out of `mixed-ro` |
| compat_hints audit | 1 | The bot reads it about once a day |
| sweeps | 1 | The bot reads it about once a day |
| 404 | 3 | A wrong path or hash |

The weights are a judgment: the registry has no traffic log yet. Change `CLASSES` in `gen-scenarios.mjs` when a log exists.

Not covered: conditional requests (`If-None-Match`, 304), the publish and ingest routes, tokens, the log tiles.

## Routes that the generator and the scenarios use

| What | Route | Docs |
| --- | --- | --- |
| Corpus: all releases and groups | `GET /v1/releases?after=<log_index>`, pages until an empty page | R-AP14 |
| Corpus: nightly tags | `GET /v1/toolchains?after=<log_index>` | R-AP5 |

The generator does not use `?q=` or `?short=` to find packages: `short` is an exact match, not a prefix (R-SN1), and `q` gives at most 20 packages (R-SN5, no page), so a search cannot list the corpus. The release pages give each package in a few requests.

## Local run

```
node research/bench/local.mjs --dir <state dir> &                  # seed, start serve.mjs on 127.0.0.1:8787
node research/bench/gen-scenarios.mjs --base http://127.0.0.1:8787 --out-dir <scenario dir>
node research/bench/drive.mjs --base http://127.0.0.1:8787 --scenario all --repeat 3 --dir <scenario dir> --out local.jsonl
kill %1                                                            # TERM stops serve.mjs
```

`local.mjs` reads the corpus of `--from` (default the live registry), and writes `<state dir>/worker/` (`seed.sql`, `settings.json`, `ratelimits.json`, `github/`). It then runs `worker/tests/serve.mjs` on `worker/app.wasm`.

| Item of the seed | Value |
| --- | --- |
| Releases | `worker/tests/tools/mk-l3w-seed.mjs`. A release with a tag that is not the version or `v`+version, and a hash with a second label, is left out. About 17 percent of the live releases are left out (154 of 186 on 2026-11-07) |
| Repository ids | Made up (1001 and up) |
| Toolchains | The 34 live rows, each with a `log` row |
| `compat` | One bot row (pass, target `any`) for each artifact on the 3 newest nightlies, so the closure answer has runs. The hint scenarios use the older nightlies, because a hint on a pair with a bot row is skipped (R-CT14) |
| Clock | `TALON_NOW` is the start time, as the seed times |
| `RL_HINTS` | 1,000,000 a minute (the live limit is 30), else the hint scenarios get 429 |
| Fake GitHub | The tag list of `roc-talon/talon` (R-CT12) with `v0.4.1` |

Generate the scenarios from the target that you drive. The files in `scenarios/` come from the live registry: against a local seed some hashes and groups are missing and the status of those requests differs from `expected_status`.

## Check results (2026-11-07)

Worker build: `worker/app.wasm` of 2026-11-06 16:58 (not built again). No request of the local run got a `serve fault` (599).

Remote, `https://registry.roc-talon.org`, `--scenario all --repeat 3`, gap 100 ms, 2370 requests, `hints`, `mixed` skipped (they write). All lines have colo `ATH` (the bench host is in Athens). `x-roc-stats` was not sent (`stats` null in all lines).

| Scenario | Count | Mismatch | p50 ms | p90 ms | max ms | Status |
| --- | --- | --- | --- | --- | --- | --- |
| closure | 186 | 0 | 94.4 | 104.4 | 230.4 | 200x186 |
| compat | 453 | 0 | 17.1 | 81.2 | 120.6 | 200x447 404x6 |
| mixed-ro | 1200 | 0 | 20.1 | 95.4 | 435.5 | 200x1158 404x42 |
| releases | 204 | 0 | 16.3 | 79.9 | 109.5 | 200x201 404x3 |
| search | 321 | 0 | 16.2 | 78.1 | 125.6 | 200x321 |
| small | 6 | 0 | 13.1 | 16.9 | 16.9 | 200x3 404x3 |

The known fault (503, body `error code: 500`): 0 of 2370 in this run. Other 5xx: 0. Requests with no answer: 0.
The high p90 of the cached read routes is probably the first of the 3 repeats of a path (cache miss, D1 read), and the p50 the cache hit. This was not checked.

Local, `serve.mjs` on 127.0.0.1:8787, scenarios made from the local registry (154 releases, 42 packages), `--scenario all --repeat 3`, no gap, 3612 requests:

| Scenario | Count | Mismatch | p50 ms | p90 ms | max ms | Status |
| --- | --- | --- | --- | --- | --- | --- |
| closure | 162 | 0 | 7.8 | 9.6 | 47.0 | 200x162 |
| compat | 453 | 0 | 4.7 | 7.5 | 17.4 | 200x447 404x6 |
| hints | 93 | 0 | 7.7 | 9.2 | 19.2 | 200x3 201x90 |
| mixed | 1200 | 0 | 4.2 | 8.6 | 63.6 | 200x1107 201x45 404x48 |
| mixed-ro | 1200 | 0 | 4.0 | 8.3 | 70.6 | 200x1158 404x42 |
| releases | 192 | 0 | 2.5 | 4.5 | 12.6 | 200x189 404x3 |
| search | 306 | 0 | 2.2 | 3.6 | 16.8 | 200x306 |
| small | 6 | 0 | 1.6 | 2.6 | 2.6 | 200x3 404x3 |

The local run also worked with `--concurrency 4` (0 mismatches). The 11 members of each line were checked in all 3612 lines.

Fixed while checking: a hint on a pair with a bot row is skipped (R-CT14) and gives 200 `written: 0`, not 201. So the hint rows use the older nightlies.

## Routes that did not answer as the docs say

None in the scenarios. These were noted:

| Request | Answer | Docs |
| --- | --- | --- |
| `GET /v1/sweeps/<tag>?target=linux_x86_64` (a probe, not in a scenario) | 400 `target must be any` | As R-AP67 (Q147): the target of a sweep is `any`. The task text had `target` as optional, so the 400 is a note, not a fault |
| `GET /v1/packages?short=<prefix>` | 200 with no match for a prefix such as `roc` | As R-SN1: `short` is an exact match. A prefix search is `?q=` |

## Bench deployment (T4, 2026-11-07)

| Item | Value |
| --- | --- |
| URL | `https://talon-registry-bench.bellup.workers.dev` (workers.dev only) |
| Config | `worker/wrangler.bench.toml` (`wrangler -c wrangler.bench.toml ...`), same app.wasm as prod, version 5f7be587 |
| D1 | `talon-registry-bench`, WEUR, migrations 0001 and 0002 |
| Data | A dump of prod (`research/d1-dump/dump.mjs`) on 2026-11-07: 214 releases, 306 names, 34 toolchains, no compat rows yet |
| Queues | `talon-bench-index`, `talon-bench-index-dlq` |
| Secrets | CONTRIBUTOR_KEY and TOKEN_KEY of its own (`~/.config/talon-registry-bench/`). No GitHub App secrets: ingest, publish and webhooks do not work. |
| Crons | None (no GitHub reads) |
| Limits | RL_HINTS 100000 a minute (the hints scenario) |
| Writes | `lib.mjs` `BENCH_HOST`: the driver sends write scenarios to this host and to loopback only |

First run, `--repeat 1`, from ATH: 821 requests, 0 mismatches. p50 ms: small 10, search 81, releases 82, compat 85, closure 108, hints 157, mixed-ro 81.
To seed again after the prod corpus grows: make a new D1 (the import needs an empty database), apply the migrations, import a new dump, change `database_id`.
