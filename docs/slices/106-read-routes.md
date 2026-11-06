# 106 Read routes: releases and artifacts

Phase: P2. Status: code done, verify results in section 12 (code agent, 2026-11-01). The W0 and W2 tests of this slice pass. Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 106.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-106-revert/reference/` (the private reference).

## 1. Scope

Four `GET` routes with one D1 call each, in a read session, with the ETag, the 304, `max-age=60` and the Cache API.

| Route | Rule | Answer |
| --- | --- | --- |
| `GET /v1/packages/{owner}/{repo}/releases` | R-AP1 | `{releases, checked, repos}` |
| `GET /v1/artifacts/{hash}` | R-AP2 | `{artifact, releases, repos}` (question Q106-6) |
| `GET /v1/releases?group=<URL form>[&series=][&after=]` | R-AP13 | `{releases, checked, repos}` |
| `GET /v1/releases?after=<log_index>` | R-AP14 | `{releases, repos}`, at most 1000 |

| Part | Who | State |
| --- | --- | --- |
| Frame: `worker/lib/Reads.roc` (signatures, stub bodies), `worker/ReadRoutes.roc` (signatures, stub bodies) | Test agent | Done. The code agent does not change a signature or a type (TW18). |
| Route rows in `worker/lib/Route.roc` (3 `Route.Id` tags and 3 arms) and dispatch arms in `worker/main.roc` (`run!`, `read_answer`) | Test agent (the manager allowed it, 2026-11-01) | Done. They are code, not stubs: do not remove them. Slice 109 uses `ReadRoutes.Error` and `read_answer`: do not rename them. |
| Header entries `base58` and `records` in `worker/main.roc`, `worker/lib/main.roc`, `worker/tests/unit/w0.roc`; `Reads` in the `exposes` of `worker/lib/main.roc` | Test agent | Done. |
| Tests: `worker/tests/unit/ReadsTest.roc` (W0), `worker/tests/cases/reads/` (W2) | Test agent | Red (section 5) |
| Runner changes RR1, RR2, RR3 (section 7) | The manager | Needed before the code step. 4 of the 11 cases need them. |
| Bodies of `Reads` and `ReadRoutes` | Code agent | To do |

Size: the private reference has 254 lines of code in `Reads` and 195 in `ReadRoutes` (without blank and comment lines), about 450. That is over the 400 of TW19. I did not split: the three routes share one flow (`serve!`), and a split of R-AP14 or of the cache part (about 30 lines) would make two reviews of the same flow. If the code is much larger than 450 lines, the code agent writes a dispute (section 10) and the manager splits.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP1, R-AP2, R-AP13, R-AP14 | The four routes, their answers and errors (404, 400) | W0 routes, ids, query, bodies. W2 `ap1-*`, `ap2-artifact`, `ap13-*`, `ap14-pages` |
| R-AP48 rows 1, 2, 6 | 404 for an unknown path, 405 with `Allow: GET` for another method, 400 for a bad query before any D1 call | W0 routes and query. W2 `ap48-method-not-allowed`, `ap13-bad-requests` (D1 count 0) |
| R-AP41 (rows 1 and 5, read budget) | Exactly 1 D1 call for each answer that reads D1, in a session: `Any`, or `After(bookmark)` from the header `Talon-Bookmark` | W0 `session_of`. W2 d1-calls in every case, `bookmark-session` |
| R-AP18 | All rows of an answer come from one state: one `batch!` (one transaction) | W2 d1-calls (the count 1 shows one call; the transaction is the platform) |
| R-AP24 | `ETag` on each 200. `If-None-Match` equal to the ETag gives 304 with no body | W0 `etag_of`, `etag_matches`. W2 `ap1-body-etag-cache`, `ap24-conditional-first`, `ap2-artifact` |
| `max-age` | `Cache-Control: max-age=60` on each 200 and each 304 | W2 headers |
| R-AP43 | Cache API of the colo for 60 s. A hit makes no D1 call. `Cache-Control: no-cache` or `Pragma: no-cache` skips the read and puts the new answer. A 404 is not put. | W0 `bypass_cache`. W2 `ap1-body-etag-cache`, `ap43-not-found-uncached`, `ap43-cache-refresh` |
| R-AP29 | `checked`: `{name, checked_at, stale}`. Stale: never read, or older than 2 intervals of R-PU22 (1 h, 24 h with the App) | W0 `stale`, `checked_of_row`. W2 `ap29-checked-stale`, `ap1-body-etag-cache` |
| R-AP32 | `repos`: `{name, state, successor, state_at}` for each GitHub name in the answer | W0 `repo_item_of_row`, bodies. W2 bodies |
| R-AP49, R-AP50, R-AP51, R-RE1, R-RE2, R-RE19, R-RE20, R-IK1 | The wire records from D1 rows. Hash in base58, version as `X.Y.Z`, series, times in ms, `null` for none | W0 `release_of_row`, `artifact_of_rows`, bodies. W2 exact bodies |
| R-IK2, R-IK5 | Ids from the request (`name_id`), `?series=` as version bounds | W0 ids. W2 `ap13-group-series-after` |
| R-AP44 | An unknown query parameter is ignored | W2 `ap13-group-series-after` (`&unknown=1`) |
| R-AP21 | Problem form for 400, 404, 405 | W0 problems. W2 `problem` |
| R-AP23 | The answer is `application/json` | W2 headers |

Design refs: Registry 4 (the table of routes, R-AP15, R-AP29, R-AP32, R-AP41, R-AP43, R-AP48 to R-AP51), 5, 5.1, 7 (R-PU22), Design Q25, Q46. Platform 0.0.2: `cloudflare-workers/MODULES.md` 4, 5.1 (`D1`, `with_session!`, `batch!`), 5.4 (`Cache`).

## 3. What the code agent writes

### 3.1 Files

| File | Item |
| --- | --- |
| `worker/lib/Reads.roc` | The bodies of the stubs. Pure. The doc comment of each stub is the rule. |
| `worker/ReadRoutes.roc` | The bodies of `repo_releases!`, `artifact!`, `releases!`. They return `Try(Response, ReadRoutes.Error)`. |
| `worker/main.roc`, `worker/lib/Route.roc` | Nothing. The rows are in place. |
| `sql/queries/*.sql` (optional) | The SQL texts, embedded with `import "..." as x : Str`. There is no W1 case for them: W2 runs them on the real schema. |

### 3.2 Route rows (done)

| Path | Method | `Route.Id` | Other method |
| --- | --- | --- | --- |
| `/v1/packages/{owner}/{repo}/releases` | GET | `GetRepoReleases(owner, repo)` | 405, `Allow: GET` |
| `/v1/artifacts/{hash}` | GET | `GetArtifact(hash)` | 405, `Allow: GET` |
| `/v1/releases` | GET | `GetReleases` | 405, `Allow: GET` |

HEAD gets 405 (`Allow: GET`): the design serves `GET` only (R-AP48 row 2).

### 3.3 The flow of each handler (`serve!`)

| # | Step |
| --- | --- |
| 1 | Checks that need no D1 come first, with no D1 call: `Reads.parse_query` (400), `Reads.artifact_id` (question Q106-5). |
| 2 | The cache key is `req.url()` (the whole URL with the query). `Reads.bypass_cache` of the request headers `cache-control` and `pragma`. When false: `Cache.default.get!(key)`. A hit is the answer, and no D1 call is made. |
| 3 | A miss or a bypass: `db.with_session!(Reads.session_of(req.header("talon-bookmark")))`, then one `batch!` on the session (one call for all statements). |
| 4 | Rows to body with the `Reads` builders. A body is text. The answer is 200 with `content-type: application/json`, `cache-control: Reads.cache_control`, `etag: Reads.etag_of(bytes of the body)`. It goes into the Cache API with `Cache.default.put!(key, res)` (use the response that `put!` gives). A problem answer (404) is not put. |
| 5 | `If-None-Match` of the request against the `etag` of the answer, also for a hit: `Reads.etag_matches`. A match is 304, no body, with the headers `etag` and `cache-control`. |

On the 304 path after a miss, the Worker has read D1 and has the 200 answer: it puts the 200 answer in the cache (test `ap24-conditional-first`, proposal in section 6).

### 3.4 SQL notes (facts found while making the tests)

| # | Fact | Effect |
| --- | --- | --- |
| 1 | On the W2 build with `--opt=dev` a BLOB column does not read into a `List(U8)` field or a `Cbor.Bytes` field (`BadData("column bl: the value does not fit the type")`). The cause is the wasm32 `--opt=dev` backend of roc (I128 to U8, U16, I8, I16), not the platform (section 8 P1). | The frame of the test agent has `hash : Str` in `ReleaseRow`, `ArtifactRow` and `DepRow`, so the code first read each hash as `hex(names.value)` (64 digits, upper case from SQLite) and `Reads` decodes the hex. Dispute D106-1 (section 11) asks to change this to `List(U8)` after the W2 build is `--opt=speed`. |
| 2 | `hex(NULL)` is the empty text, not NULL. | Use `NULLIF(hex(pl.value), '')` for `platform_hash` (a LEFT JOIN). The test row of an app has a platform, a package has none. |
| 3 | Ids are 64 bits. Bind them as `I64` (the platform sends text from 2^53). Compare with a column: `WHERE r.repo = ?`. | R-IK2 |
| 4 | Read `version` as `CAST(r.version AS TEXT)`. | R-IK2, R-IK5 |
| 5 | A series bound is text: `r.version BETWEEN CAST(?2 AS INTEGER) AND CAST(?3 AS INTEGER)`, with `Version.series_bounds`. Filter the rows with `Version.series_of` after the read, as R-IK5 says. | W2 `series=4`, `series=0.25`, `series=7` |
| 6 | The first release row of a group on another host has `repo` NULL. Use `LEFT JOIN names rp ON rp.id = r.repo`. | `repo: null`, `repos: []`, `checked: null` |
| 7 | A nullable column reads into `Try(a, [Missing])`. `yanked` (0 or 1) reads into `Bool`. | The row types of `Reads` |
| 8 | `roc build` exits with 2 when it has a warning (an unused variable), and `scripts/test.sh` stops at a non-zero exit. Leave no warning. | The `w2` step |
| 9 | `Cache.default.put!` gives the response to send. A response with no `cache-control` is not cached on local workerd. `Cache.default.get!` gives `Err(NotFound)` for a miss. | MODULES.md 5.4 |

### 3.5 Public signatures

They are in the two stubs. Summary:

| Module | Items |
| --- | --- |
| `Reads` | `page_limit`, `cache_control`, `artifact_id`, `form_id`, `repo_id`, `QueryInput`, `Query`, `parse_query`, `etag_of`, `etag_matches`, `bypass_cache`, `session_of`, `interval_ms`, `stale`, `CheckRow`, `CheckedItem`, `checked_of_row`, `RepoRow`, `RepoItem`, `repo_item_of_row`, `ReleaseRow`, `release_of_row`, `ArtifactRow`, `DepRow`, `artifact_of_rows`, `releases_body`, `page_body`, `artifact_body`, `no_repo_releases`, `no_artifact` |
| `ReadRoutes` | `Error : [Refuse(Problem), Fault(Str)]`, `repo_releases!`, `artifact!`, `releases!` |

## 4. Wire forms (the bytes that the ETag covers)

| Body | Text |
| --- | --- |
| R-AP1, R-AP13 | `{"releases":[<Release.encode each>],"checked":<item or null>,"repos":[<items>]}` |
| R-AP14 | `{"releases":[..],"repos":[..]}` |
| R-AP2 | `{"artifact":<Artifact.encode>,"releases":[..],"repos":[..]}` |
| `checked` item | `Closure.encode_checked`: `{"checked_at":<integer or null>,"name":"..","stale":<bool>}` |
| `repos` item | `Closure.encode_repo`: `{"name":"..","state":"active","state_at":<integer>,"successor":<text or null>}`, sorted by `name` (bytes) |

No white space. The members of a release and of an artifact are in the order of `Release.encode` and `Artifact.encode` (alphabetical). `records` has no encoder for `checked` and `repos` and `Nullable` is private to it, so `Reads` writes these two items as text (platform note: section 8 N1).

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `ReadsTest.roc`, 22 `expect`s. Routes (12 rows: 3 served, 4 methods, 5 near misses), ids (`artifact_id` 3 good and 7 bad texts, `form_id`, `repo_id`), `parse_query` (5 good, 16 bad rows), `etag_of` (3 vectors), `etag_matches` (9 yes, 11 no), `bypass_cache` (10 yes, 7 no), `session_of` (5), `stale` (9 rows, both intervals), `checked_of_row`, `repo_item_of_row`, `release_of_row` (3 good, 7 bad, lower case hex), `artifact_of_rows` (3 good, 5 bad), the 3 bodies with exact text, the 2 problems. The constants are made by `research/slice-106-revert/gen/gen_w0.py` with python (hashlib, json), not with Roc. | R-AP1, R-AP2, R-AP13, R-AP14, R-AP21, R-AP24, R-AP29, R-AP32, R-AP41, R-AP43, R-AP48, R-AP49, R-IK1, R-IK2, R-RE1, R-RE2, R-RE19, R-RE20 |
| W2 | `reads/ap1-body-etag-cache`: the body (exact text and ETag), a second request from the Cache API (D1 count 0), `If-None-Match` equal (304, count 0), not equal (200, count 0), `no-cache` (count 1), `Pragma: no-cache` (count 1), `no-cache` with an equal `If-None-Match` (304, count 1), then a plain request (count 0) | R-AP1, R-AP18, R-AP24, R-AP29, R-AP32, R-AP41, R-AP43, R-AP49 to R-AP51, R-RE2 |
| W2 | `reads/ap24-conditional-first`: the first request has `If-None-Match` (a weak form `W/"..."`): 304 and one D1 call. The next plain request is served from the cache (count 0). | R-AP24, R-AP43 |
| W2 | `reads/ap43-not-found-uncached`: an unknown repo twice (404, count 1 each time), an unknown owner, then a known repo | R-AP1, R-AP21, R-AP43 |
| W2 | `reads/ap13-group-series-after`: a group; `series=4`, `series=0.25`, `series=7` (empty); a second URL form; a group on another host (`checked: null`, `repos: []`); a moved repo with `successor`; a group with no release (200, empty); `after`; `series` with `after`; an unknown query parameter | R-AP13, R-AP14, R-AP29, R-AP32, R-AP44, R-IK5 |
| W2 | `reads/ap13-bad-requests`: no parameter, `series` only, an unknown parameter only, an empty `group`, bad `after`, bad `series` (`0`, `1.2`). All 400 with D1 count 0. | R-AP13, R-AP14, R-AP21, R-AP48 |
| W2 | `reads/ap14-pages`: 1002 releases made by a recursive CTE in `seed.sql`. `after=0` gives 1000, `after=1000` gives 2, `after=1002` gives none, `after=999`, and `group` with `after` | R-AP14, R-AP13, R-AP41 |
| W2 | `reads/ap2-artifact`: a package with 2 deps, a package, a platform with 2 targets, an app with its platform, an equal `If-None-Match` (304), an unknown hash twice (404, count 1 each time) | R-AP2, R-AP24, R-AP32, R-AP49, R-RE1, R-RE19, R-RE20 |
| W2 | `reads/ap29-checked-stale`: 6 repos: 1 h old, never, exactly 2 h, 2 h and 1 ms, 3 h with the App, 48 h and 1 ms with the App | R-AP29, R-PU22 |
| W2 | `reads/ap43-cache-refresh` (needs RR1): a 404, a new repo is added, the next request is 200; a cached answer stays old after an update (count 0); `no-cache` reads the new rows (count 1) and puts them; the next plain request has the new rows (count 0) | R-AP43, R-AP1 |
| W2 | `reads/bookmark-session` (needs RR2): no header gives the session `first-unconstrained`; `Talon-Bookmark: <b>` gives `<b>`; a value with spaces is cut; an empty value gives `first-unconstrained`; the same for R-AP2 and R-AP13 | R-AP41 row 5, R-AP43 |
| W2 | `reads/ap48-method-not-allowed`: POST, PUT, DELETE, PATCH on the three paths (405, `allow: GET`, count 0), two near misses (404) | R-AP48, R-AP21 |

Count: 22 W0 `expect`s (over the 20 of the budget: the wire has 5 record kinds), 11 W2 cases (all with 2 to 10 requests). All W2 expected texts are made by `research/slice-106-revert/gen/gen_w2.py` with python, not with Roc.

### 5.1 Red results (2026-11-01, the stubs)

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | `ReadsTest.roc`: 21 failed with `todo`, 1 passed (the route rows: the arms of `Route.decide` are in place). 0 compiler errors. The other failures of the step are slice 109. `roc fmt --check` passes. |
| `node worker/tests/run.mjs reads` | 11 cases: 1 passes (`ap48-method-not-allowed`: the arms exist), 10 fail. 8 fail with `status: expected 200 (or 400, 404), got 500` and the Worker log `fetch: trap: todo`. `ap43-cache-refresh` fails at once: `expect/responses.jsonl has 6 lines for 8 requests` (RR1 missing). `bookmark-session` fails on the status first (and needs RR2 for the header). |
| Old cases | The 33 cases of slices 101 and 108 pass with the stubs. (Slice 109 cases are red: not this slice.) |

### 5.2 Private reference and revert check

`research/slice-106-revert/reference/` (`overlay/` has the two modules, `run-ref.sh` builds a copy of `worker/` with them, the changed runner of section 7 and runs the cases, `mutate.sh` is the revert check). With the reference: 22 of 22 W0 `expect`s of `ReadsTest.roc` pass, and 11 of 11 W2 cases pass (with RR1 to RR3). 10 mutations of the reference were run (user rule: the tricky ones). The table lists each with the test that fails.

| Mutation | What | Caught by |
| --- | --- | --- |
| `no-pragma` | `Pragma: no-cache` is ignored | W0 `bypass_cache`, W2 `ap1-body-etag-cache` |
| `no-put-bypass` | A `no-cache` request does not put the new answer | W2 `ap43-cache-refresh` |
| `etag-exact` | `If-None-Match` is one tag only (no list) | W0 `etag_matches` |
| `session-any` | The bookmark is not used | W0 `session_of`, W2 `bookmark-session` |
| `page-1001` | A page has 1001 releases | W2 `ap14-pages` |
| `key-no-query` | The cache key has no query | W2 `ap13-group-series-after`, `ap14-pages`, `ap29-checked-stale` |
| `stale-ge` | Exactly 2 intervals is stale | W0 `stale`, W2 `ap29-checked-stale` |
| `after-ge` | `after` includes the log index | W2 `ap14-pages` |
| `two-calls` | The batch is split in 2 calls | 9 of 11 W2 cases (count 2) |
| `order-desc` | Releases in the order of a descending log index | 5 of 11 W2 cases |

## 6. Output (proposed, TW24)

The design gives the route, the members and the status. It does not give these. They are proposals for the human.

| Item | Proposal |
| --- | --- |
| ETag | A strong tag: the first 16 bytes of SHA-256 of the body as 32 lower-case hex digits, in double quotes: `"ba7816bf8f01cfea414140de5dae2223"`. A function of the bytes, so two answers of one state have one ETag (R-AP49). |
| `If-None-Match` | RFC 9110 13.1.2 weak comparison: `*`, or a comma separated list of tags, `W/` ignored, white space ignored. |
| 304 | Headers `etag` and `cache-control: max-age=60`. No body, no `content-type`. |
| 200 | `content-type: application/json` (no `charset`), `cache-control: max-age=60`, `etag`. |
| Cache on a 304 after a miss | The Worker puts the 200 answer that it has read (a client with no `If-None-Match` then gets it from the cache). |
| Order | `releases` in the order of `log_index`, rising (R-AP14 says it; the same for the other routes, so the ETag is stable). `repos` sorted by `name`. |
| `checked` | An object `{name, checked_at, stale}` for R-AP1 and R-AP13, `null` when the answer has no GitHub release (question Q106-1). R-AP14 has no `checked`. |
| Empty answers | R-AP13 for a group with no release: 200, `{"releases":[],"checked":null,"repos":[]}`. R-AP14 for `after` at the end: 200, `{"releases":[],"repos":[]}`. |
| Query 400 `detail` | `GET /v1/releases needs the query parameter group or after`; `the query parameter group must not be empty`; `the query parameter after must be a log index (decimal digits), got <text>`; `the query parameter series must be a series (M or 0.m), got <text>`. The first rule that fails, in this order (the order of the doc comment of `parse_query`). |
| 404 `detail` | `no indexed release for <owner>/<repo>` (R-AP1); `no artifact <hash>` (R-AP2) |
| `Talon-Bookmark` | Cut of white space. An empty value is like no header: `Any`. |
| `stale` | `now - checked_at` more than 2 intervals. Intervals 1 h and 24 h (the first guesses of R-PU22). |

## 7. Runner requests (the manager applies them to `worker/tests/run.mjs` and `worker/tests/worker-test.js`)

The test agent does not edit the runner (slice 101). The changed files are in `research/slice-106-revert/runner/` (`run.mjs`, `worker-test.js`) with the diffs `run.mjs.diff` (41 lines) and `worker-test.js.diff` (35 lines). `research/slice-106-revert/reference/run-ref.sh` runs the cases with them.

| # | Request | Form | Why |
| --- | --- | --- | --- |
| RR1 | A request line `{"sql": ["statement", ...]}` is not a request: the statements run on the D1 between the requests. It has no line in `expect/responses.jsonl` and `expect/d1-calls`. | `run.mjs` | A cache test must change the data between two requests. No Worker route writes yet. `ap43-cache-refresh` needs it. |
| RR2 | The test entry records the argument of `withSession` and sets the response header `x-d1-session` (absent when the request opens no session). It does not count as a D1 call. | `worker-test.js` | The only way to see `Any` or `After(bookmark)` in W2. `bookmark-session` needs it. Local D1 takes any bookmark text. |
| RR3 | `dispatchFetch` is called with `cache: 'force-cache'`. | `run.mjs` | Node `fetch` (undici) adds `Cache-Control: no-cache` and `Pragma: no-cache` to a request that has `If-None-Match`. The Worker then bypasses the cache and the D1 count is 1, not 0 (found with the reference: `ap1-body-etag-cache` requests 3 and 4). With `force-cache` it adds nothing. A case that wants `no-cache` sets the header itself. |

The Cache API can be seen in the harness without a change: a hit has the D1 count 0. Only the data change (RR1) and the INM headers (RR3) need the runner. The old cases pass with RR1 to RR3 (checked with the reference tree: 38 of 44 pass, the 6 others are the slice 109 changes).

## 8. Platform issues and notes

The code agent found no new platform problem in this step: all 12 W2 cases of this slice passed at the first run (first run: `hex(...)`; after D106-1: plain BLOB). Notes: `roc fmt` of the pinned worker nightly changes nothing in the two modules; the MCP `roc_check` uses the nightly of the CLI (`ROC_TAG`) and shows a version mismatch for `worker/main.roc`: check the worker with `ROC_TAG_WORKER` (`scripts/test.sh check`).

| # | Issue | Evidence |
| --- | --- | --- |
| P1 | A BLOB column does not read into a typed row on the W2 build. Cause (manager, 2026-11-01): the roc wasm32 `--opt=dev` backend gives a wrong narrowing of I128 to U8, U16, I8 and I16, and roc-cbor reads each integer through an I128 (`cloudflare-workers/MODULES.md` 2, "Mode"). It is not a platform fault. The release 0.0.2 text of `MODULES.md` 5.1 (a BLOB reads into `List(U8)` and `Cbor.Bytes`) is right for `--opt=speed`. | A route with `db.all!("SELECT x'0102ff' AS bl", Sql.none)` into `List({ bl : List(U8) })` gives `Err(Infra(BadData("column bl: the value does not fit the type")))` on the dev build. The harness owner changes the W2 build to `--opt=speed`. The old text of this row (a fault of the 0.0.2 bundle) was wrong. |
| P2 | `roc build` exits with 2 when it has a warning, and still writes the file. `scripts/test.sh` treats it as a failed build. | An unused variable in the reference. |
| P3 | Node `fetch` adds `Cache-Control: no-cache` and `Pragma: no-cache` to a request with `If-None-Match` (fetch spec, cache mode `default` becomes `no-store`). A test of a conditional request through `dispatchFetch` bypasses a Worker that follows R-AP43. | RR3 |
| P4 | Local D1 takes a bookmark that it never made (`withSession("bookmark-abc-123")` gives no error, also not at the query). `bookmark-session` checks the argument only. | The reference run |
| N1 | `records` has no encoder for the `Checked` and `Repo` items, and its `Nullable` is private, so a Worker cannot write `null` with the derived codec. `Reads` writes the two items as text. A later slice of `records` can add `Closure.encode_checked` and `Closure.encode_repo`. | Section 4 |
| N2 | The comments of `Closure.Checked` and `Closure.Repo` in `packages/records/Closure.roc` say that `checked_at` and `state_at` are "a time in seconds". R-AP50 says milliseconds, and the type is `U64`. The tests here use milliseconds. | `Closure.roc` lines 29 and 32 |

## 9. Out of scope

| Item | Reason |
| --- | --- |
| The purge of the Cache API at a publish (`cache.delete`, R-AP43) | Slice 112 (the publish writes) |
| `max-age` expiry of an entry | The Cache API uses the real clock of workerd; the case clock does not move it. The `cache-control` header is checked. |
| `yank_reason` and `yanked` true | P3 (`yanks`). Before P3 `yanked` is `false` and `yank_reason` is `null` (R-AP49). |
| W1 cases for the SQL texts | W2 runs them on the real schema (section 3.1). |
| R-AP18 test with a publish at the same time | No write route yet (slice 112). The count 1 of one `batch!` is the check now. |
| R-AP41 write routes, R-AP46 limits, R-AP45 `User-Agent` | Other slices |
| Rate limit 429 (R-AP25) | Slice 112 |
| HEAD | 405 by R-AP48 row 2. No case beyond the three methods of `ap48-method-not-allowed`. |

## 10. Questions (stop until answered)

The tests follow the proposal in the column "Tests". A row with "none" has no test: the code agent follows the proposal, and the human decides at the review.

| Id | Question | Proposal | Tests |
| --- | --- | --- | --- |
| Q106-1 | What is `checked` in the answers of R-AP1 and R-AP13? R-AP17 has a list. R-AP13 says "`null` for another host", which reads as one value. | One object `{name, checked_at, stale}`, or `null`. | `ap29-checked-stale`, `ap1-body-etag-cache` (the member `checked`), the bodies of W0 |
| Q106-2 | Is the path `Roc-Lang/Unicode` the same repo as `roc-lang/unicode`? R-IK2 says the name is lower case. | Fold ASCII case in `Reads.repo_id`. | none |
| Q106-3 | `?series=4` with no `group`: 400, or ignored? | 400 `bad-request` (the first rule of `parse_query` when `after` is also missing). With `after` and no `group` the series is ignored. | `ap13-bad-requests` has `?series=4` alone (rule 1) |
| Q106-4 | Do `Cache-Control: max-age=0`, `no-store` and `Pragma` values other than `no-cache` bypass the cache? The design names `no-cache`. | Only the directive `no-cache`. | W0 `bypass_cache` has `max-age=60` and `private` as no |
| Q106-5 | `GET /v1/artifacts/<text that is no base58 of 32 bytes>`: 404 or 400? R-AP2 lists only 404. | 404 `not-found` with the same `detail` as an unknown hash. | W0 `artifact_id` (the `Err(BadHash)` only), no W2 row |
| Q106-6 | The shape of the R-AP2 answer: "the artifact record and all its releases". | `{artifact, releases, repos}` | `ap2-artifact`, W0 `artifact_body` |
| Q106-7 | How is `artifacts.exposes` (TEXT) stored? | A JSON array of text: `["Unicode","Utf"]` (slice 112 writes it) | The seed of the W2 cases, W0 `exposed_json` |
| Q106-8 | The `group` of a dep whose URL has no version (`deps.form` NULL, R-RE19)? R-AP49 makes `group` required. | The URL without its scheme, or a design change that makes `group` nullable | none (every dep row of the tests has a version) |
| Q106-9 | `after` with a value above 2^63 - 1, and `after=007`: 400 or accepted? | 400 for both (digits only, no leading zero, fits `I64`) | none |

### 10.1 Answers (design agent, 2026-11-01)

| Id | Answer | Design |
| --- | --- | --- |
| Q106-1 | As proposed: one item or `null` (`null` for another host and for an answer with no release) | Registry R-AP53, Design Q87 |
| Q106-2 | Yes: fold the ASCII letters of `{owner}/{repo}` to lower case before `name_id(3, ..)`. The 404 `detail` keeps the segments as sent. A `group` is exact bytes. | R-AP56, Q88 |
| Q106-3 | As proposed: 400 with no `group` and no `after`; with `after` and no `group`, `series` is ignored | R-AP56, Q89 |
| Q106-4 | As proposed: only the directive `no-cache` in `Cache-Control` or `Pragma` | R-AP55, Q90 |
| Q106-5 | As proposed: 404 `not-found` with the `detail` of an unknown hash, no D1 call | R-AP56, Q91 |
| Q106-6 | As proposed: `{artifact, releases, repos}` | R-AP2, R-AP53, Q92 |
| Q106-7 | As proposed: a JSON array of text, in the order of the header | R-RE1, Q93 |
| Q106-8 | `group` stays a required text: the URL with no scheme and no last segment (`<hash>.tar.zst`), with no `{v}`, made from `url` | R-AP49, Q94 |
| Q106-9 | As proposed: 400 for both. Digits, no leading zero (only `0`), at most 2^63 - 1. The same rule for `after` of `GET /v1/toolchains` (slice 109). | R-AP56, Q95 |

Section 6 (TW24): the ETag form, the `If-None-Match` comparison, the 304 and 200 headers and the put of the 200 answer on a 304 after a miss are now design facts (R-AP54, R-AP55, Q96). The order of `releases` and `repos`, the empty answers and the `Talon-Bookmark` trim are design facts (R-AP53, R-AP55, Q97). The `stale` rule is R-AP29 as written (exactly 2 intervals is not stale). The `detail` texts stay proposals for the human review (accepted as written).

Test changes (done by the test agent, 2026-11-01):

| # | Change | Why |
| --- | --- | --- |
| T1 | `parse_query` (W0): add bad `after` rows `007`, `00`, `9223372036854775808`, and a good row `9223372036854775807`. Change the doc comment of rule 3 to the R-AP56 form. | Q106-9 |
| T2 | Doc comments of the stubs in `worker/lib/Reads.roc`: line 4 (the ETag form is R-AP54, not a proposal), `artifact_id` (Q106-5: 404), `repo_id` (Q106-2: ASCII fold), `parse_query` (Q106-3), `bypass_cache` (Q106-4), `ArtifactRow` (Q106-7), `DepRow` (Q106-8: `group` from `url` when `form` is missing). No signature change. | The questions are answered |
| T3 | Optional: a W0 `repo_id` row with upper case (`Roc-Lang`, `Unicode`) equal to the lower-case id, and a W0 `artifact_of_rows` row with a dep with no `form` and no `version` (`group` from `url`) | Q106-2, Q106-8 have no test now |

Done: T1 (`parse_query` rows `007`, `00`, `9223372036854775808` bad, `9223372036854775807` good; `series` alone 400; `series` with `after` and no `group` ignored), T2 (the doc comments cite R-AP53 to R-AP56; `CheckedItem` and `RepoItem` are the `records` types `Closure.Checked` and `Closure.Repo`, and `releases_body` uses `Closure.encode_checked` and `Closure.encode_repo`, so the members of these two items are in alphabetical order), T3 (W0 `repo_id` upper case, W0 dep with no version: `group` is `example.com/pkg/lib/`). The optional rows are required now: W2 `ap56-case-fold` (path case fold, the 404 `detail` as sent, `group` exact bytes), W2 `ap2-artifact` (4 texts that are no hash: 404, count 0), `max-age=0` and `no-store` do not bypass (W0, W2 `ap1-body-etag-cache`), W2 `ap13-bad-requests` (`after=007`, `after=9223372036854775808`), `ap14-pages` (`after=9223372036854775807`, `series` with `after` and no `group`). Counts: W0 23 `expect`s (22 red `todo`, 1 green), W2 12 cases (11 red `todo`, `ap48-method-not-allowed` green). The reference passes all of them (W0 23 of 23, W2 12 of 12), and 4 more mutations are caught (`no-fold`, `maxage-bypass`, `after-zero`, `nofold-group`). The runner changes RR1 to RR3 are applied.

## 11. Disputes (from the code agent)

| Id | Test or frame | Problem | Proposal |
| --- | --- | --- | --- |
| D106-1 | The four hash fields were `Str` (hex). | Resolved (2026-11-02): the test agent changed them to `List(U8)`; the code agent dropped `base58_of_hex`, `hex(...)` and `NULLIF` and reads the BLOB columns directly (`base58_of_bytes` checks 32 bytes and encodes). The build is `--opt=speed`. | Done |


Test agent, 2026-11-01: D106-1 accepted and applied. `ReleaseRow.hash`, `ArtifactRow.hash`, `ArtifactRow.platform_hash` (`Try(List(U8), [Missing])`) and `DepRow.hash` are `List(U8)`; the `ReadsTest.roc` rows give bytes; the bad-hash rows are 31 and 33 bytes and `[]`. The row about lower-case hex is gone. The reference reads the plain column (no `hex`, no `NULLIF`) and passes 22 of 22 W0 and 12 of 12 W2 (build with `--opt=speed`). Until the code agent drops `base58_of_hex`, `Reads.roc` has 4 type errors and W0 does not compile.

## 12. Verify results

Code agent, 2026-11-01.

| Step | Result |
| --- | --- |
| `scripts/test.sh check fmt w0 w2` (2026-11-02, after D106-1) | all pass: check, fmt, w0 (all `ReadsTest` expects), w2 (the 12 `reads/` cases and the others; w2 took 98 s, over the 45 s budget: not this slice). The hashes are read as `List(U8)` BLOBs. |
| `MISSING=1 scripts/rules.sh R-AP` | The slice ids R-AP1, R-AP2, R-AP13, R-AP14, R-AP18, R-AP21, R-AP23, R-AP24, R-AP29, R-AP32, R-AP41, R-AP43, R-AP44, R-AP48 to R-AP56 are not in the list of rules with no test. The list has R-AP4, 7 to 12, 19, 20, 22, 25, 27, 28, 30, 31, 33 to 40, 42: other slices. |

Size (lines of code, without blank and comment lines): `worker/lib/Reads.roc` 236, `worker/ReadRoutes.roc` 193, total 429 (about 450, as expected). With comments: 361 and 250 lines.

Decisions that the slice does not fix: (1) `checked` is the item of the first repo of the `repos` rows (sorted by name); all four routes have at most one repo per answer for R-AP1 and R-AP13. (2) `LIMIT` of R-AP13: a group without `after` has no limit (`LIMIT -1`); with `after` it is `page_limit`. One SQL text serves both (sentinel parameters). (3) The `?series=` filter is done twice: `BETWEEN` in SQL, then `series` of each row (R-IK5). The `repos` rows are read from the same CTE `page`, so a saturated series (65535 or more) can show a repo whose releases the filter removed. (4) A failure of `Cache.default.put!` or `get!` is not a fault of the request: a `get!` error is a miss, a `put!` error sends the answer without the cache.

Revert check (TW12): not run by the code agent in this step (the manager did not ask for it). The test agent ran 14 mutations of the private reference (section 5.2).

Disputes: D106-1 (section 11). Platform: P1 corrected (section 8).
