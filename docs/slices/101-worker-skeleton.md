# 101 Worker skeleton and test harness

Phase: P2. Status: code done, verify (2026-11-01). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 101.

## 1. Scope

This slice makes the project frame of the registry Worker (`worker/`) and the harness of the layers W0, W1 and W2 (`TESTING.md` 9, `PLAN.md` B). It also makes the first Worker behavior: the router, the problem form, and the media types.

| Part | Who | State |
| --- | --- | --- |
| Frame: `worker/main.roc` header, `talon.toml`, `wrangler.toml`, `.gitignore`, `worker/lib/main.roc` | Test agent | Done. The code agent does not change the header, `talon.toml`, `wrangler.toml` or `.gitignore` (TW18). |
| Stubs: `worker/lib/Problem.roc`, `worker/lib/Route.roc`, `fetch!` in `worker/main.roc` | Test agent (signatures), code agent (bodies) | The bodies are `crash "todo"` |
| Harness: `scripts/test.sh` steps `w0 w1 w2`, `sql/tests/`, `worker/tests/` | Test agent | Done. The code agent does not change it. |
| Tests: W0 `worker/tests/unit/`, W2 `worker/tests/cases/`, the runner self-tests | Test agent | Red (section 4) |
| Code: the bodies of the stubs, the `fetch!` of `worker/main.roc` | Code agent | To do |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP21 | An error answer is problem details, with the members `type`, `title`, `status`, `detail`. The `type` and the status are in the table of R-AP21. | W0 `ProblemTest`, `RouteTest`. W2 `router/*` |
| R-AP23 | Request bodies and answers are `application/json`. Errors are `application/problem+json`. A body is accepted as `application/json` with no parameter, or with `charset=utf-8` as a token or a quoted string (RFC 9110 8.3.1), with no case. Other parameters are ignored (R-AP44). Any other charset gets 415. No body: no media check. | W2 `router/r-ap23-*`, `router/r-ap21-*`, W0 `RouteTest` |
| R-AP48 | The order of the checks: path (404), method (405 with `Allow`), media type (415), route. The skeleton shows rows 1, 2, 5 and 7. Rows 3, 4, 6 are out of scope (section 6). | W0 `RouteTest`, W2 `router/r-ap48-*` |
| R-AP44 (Worker side) | The Worker ignores a request field and a query parameter that it does not know. | W2 `router/r-ap44-unknown-ignored` (limited: section 6) |
| R-WH1 | One entry `event!` for all handler kinds. The app gives its handlers to `Worker.new`. | `worker/main.roc` (frame), the `sync --check` of the `w2` build, W2 `router/r-ap21-unknown-path` |
| R-WH4 | Pure logic in `roc test`. Handlers in Miniflare with local D1 and a fake GitHub. The clock comes from the test entry. | The harness (section 3), W2 `runner/*`, the self-tests |
| R-WH12 | `roc-cfw` is pinned in `talon.toml`. The build runs `roc build`, then `roc-cfw sync`. The header names the platform by its release URL. No npm package. | `worker/tests/frame.sh` (step `w0`), `sync --check` (step `w2`) |
| R-WH13 | The compiler of `worker/` is `ROC_TAG_WORKER`. The `roc:` pin of the header names it. | `frame.sh`, the build of `w2` and `w0` with `ROC_WORKER` |
| R-PL2 | The Worker platform is a generic Roc platform, taken by release URL. | `frame.sh`, W2 `router/r-ap21-unknown-path` |
| R-AP41 (only the count mechanism) | The D1 call count of a request. The routes of this slice make no D1 call. | W2 `runner/r-wh4-d1-count-and-rows`, `router/r-ap21-*` (count 0) |

Design refs: Registry 4.2 (R-AP21, R-AP23, R-AP44), Registry 8 (R-WH1, R-WH4, R-WH12 to R-WH14, "Release, shim and project setup"), Design 6.1 (R-PL2), `TESTING.md` 9 (TW31 to TW36), `cloudflare-workers/API.md` 10 and 11, `cloudflare-workers/MODULES.md` 3, 4.

## 3. What the code agent writes

### 3.1 The layout

```text
worker/
  main.roc              header (fixed). fetch!, scheduled!, queue!, worker, event!. The code agent writes the body of fetch!.
  lib/main.roc          package [Problem, Route]. Pure modules (W0). No effect, no platform import.
  lib/Problem.roc       stub. Kind, new, type_uri, status, title, http_status, to_json.
  lib/Route.roc         stub. Id, Input, Decision, decide.
  talon.toml            [tools] roc-cfw, [scripts] build, check, dev (fixed)
  wrangler.toml         the D1 binding DB (fixed). Comments list the entries of later slices.
  worker.js             written by `sync`. Tracked. The code agent runs `node .roc-cfw/cli.mjs sync` if the manifest changes.
  tests/                the harness and the tests (the code agent does not change them)
sql/tests/              the W1 runner and its cases
```

### 3.2 Public signatures (in the stubs)

| Module | Item | Type or rule |
| --- | --- | --- |
| `Problem` | `Problem.Kind` | The 17 types of R-AP21, as tags: `BadRequest`, `Unauthenticated`, `Forbidden`, `RepositoryChanged`, `NotFound`, `MethodNotAllowed`, `LabelConflict`, `IdCollision`, `UnsupportedClient`, `TooLarge`, `UnsupportedMediaType`, `NotACandidate`, `SuccessorMismatch`, `SweepIncomplete`, `RateLimited`, `Internal`, `Upstream` |
| `Problem` | `new : Problem.Kind, Str -> Problem` | The kind and the `detail` text |
| `Problem` | `type_uri`, `status`, `title : Problem.Kind -> Str / U16 / Str` | The table of `ProblemTest.roc`: `/errors/<kebab name>`, the status of R-AP21, the title of section 5 |
| `Problem` | `http_status : Problem -> U16` | The status of the kind |
| `Problem` | `to_json : Problem -> Str` | The 4 members. `detail` is escaped as JSON text. `Json.to_str` of a record does it. |
| `Route` | `Route.Input` | `{ method : Str, segments : List(Str), content_type : Try(Str, [NotFound]), has_body : Bool }` |
| `Route` | `Route.Decision` | `[Handle(Route.Id), Refuse(Problem), NotAllowed(Problem, List(Str))]`. `NotAllowed` is the 405: the answer has the header `Allow` with the `List(Str)` joined with `, ` (R-AP21). |
| `Route` | `decide : Route.Input -> Route.Decision` | The rules in the doc comment of the stub, and the cases of `RouteTest.roc` |

### 3.3 `fetch!` (the order is the design of this slice)

1. Build a `Route.Input` from the request: `req.method().to_str()`, `req.segments()`, `req.header("content-type")`, and `has_body` = the body is not `Empty`.
2. `Route.decide`. A `Refuse(problem)` is the answer. A `NotAllowed(problem, allow)` is the answer with the header `allow` (the methods joined with `, `). No handler runs, and the Worker makes no D1 call.
3. A `Handle(PostClosure)` calls the handler of the closure route. In this slice that handler is a stub that gives `Err(NotBuilt)`. Slice 110 replaces it. `fetch!` turns each handler `Err` into the problem `Internal` with the fixed `detail` of section 5. The text of the `Err` goes to no answer (the answer shows no inner state).
4. The answer of a problem is `Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())`. `Response.from_text` and `Response.from_json` set another content type, and `with_header` adds a second `content-type`, so do not use them for a problem.
5. `scheduled!` and `queue!` stay stubs (`crash "todo"`): they have no cron or queue entry in `wrangler.toml` yet (slices 118 to 120). They are in `Worker.new`, so that R-WH1 holds, and `sync --check` accepts them.

### 3.4 How to run

| Command | What it does | Time (this machine, 2026-11-01) |
| --- | --- | --- |
| `scripts/test.sh w0` | `frame.sh`, `roc fmt --check` of `worker/**/*.roc`, the driver check, `roc test worker/tests/unit/w0.roc` with `ROC_TAG_WORKER` | 0.3 s |
| `scripts/test.sh w1` | `node sql/tests/run.mjs` | 0.6 s |
| `scripts/test.sh w2` | Builds `worker/app.wasm` (`--opt=dev`), copies `js/` of the cached platform bundle to `worker/.roc-cfw/`, `sync --check`, then `node worker/tests/run.mjs` | build 7 s, run 2 s |
| `scripts/test.sh w0 w1 w2` | The three | see section 9 |
| `node worker/tests/run.mjs [filter]` | The W2 runner alone (the build must exist). `W2_DIR` changes the dir of `app.wasm`. `VERBOSE=1` prints the Worker log. | 2 s |
| `node sql/tests/run.mjs [filter]` | The W1 runner alone | 0.6 s |

The first build needs the network: roc downloads the platform and its two packages into `$WORK/cache/roc/packages`. The cache then holds them. Needs: Node 26 or later and a global `wrangler` 4 with Miniflare (`MINIFLARE=<dir>` names another one). A missing one fails the step with a message (TW34). No step runs `npm install`.

## 4. Tests

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| W0 | `worker/tests/unit/ProblemTest.roc`: the 17 kinds give the URI, status and title of the table. `to_json` keeps `detail` through JSON escaping for 8 texts (empty, quote, backslash, newline, tab, control character, non-ASCII). `http_status`. | R-AP21 | Red (`todo`) |
| W0 | `worker/tests/unit/RouteTest.roc`: 5 cases of an unknown path, 2 of a non-JSON body on an unknown path (404 before 415), 4 of a method not served on the path (405 with `["POST"]`, also with a non-JSON body: 405 before 415), 3 of a non-JSON body, 3 requests without a body that are not checked, 8 forms of `application/json` that pass (no parameter, `charset=utf-8` in any case, spaces around `;`), 4 charsets or empty charset that give 415 | R-AP21, R-AP23, R-AP48 | Red (`todo`) |
| W0 | `frame.sh`: platform release URL, no submodule path, `roc:` pin, `[tools] roc-cfw`, scripts, no `package.json`, `.gitignore` | R-WH12, R-WH13, R-PL2 | Green (the frame is given) |
| W2 | `router/r-ap21-unknown-path`: `GET /v1/nothing`, `GET /`, a path with a query. 404, `problem`, D1 count 0. | R-AP21, R-AP23, R-WH1, R-WH12, R-PL2, R-AP41 | Red |
| W2 | `router/r-ap48-method-not-allowed`: `GET`, `DELETE`, `PUT` (with a text body), `PATCH` on `/v1/closure`. 405, `allow: POST`, D1 count 0. | R-AP48, R-AP21, R-AP23 | Red |
| W2 | `router/r-ap48-order`: a text body on an unknown path (404), a text body with a method not served (405), a text body on `POST /v1/closure` (415), a valid body (500 from the stub). | R-AP48, R-AP21, R-AP23 | Red |
| W2 | `router/r-ap23-charset`: `charset=latin-1` and `charset=utf-16` (415); no parameter, `charset=UTF-8`, `Application/JSON;Charset=utf-8` (pass the media check, then 500 from the stub). | R-AP23, R-AP21, R-AP48 | Red |
| W2 | `router/r-ap23-parameters`: a quoted charset, `foo=bar`, `charset=utf-8; foo=bar` and the reverse pass the media check (500 from the stub); a quoted `latin-1` and `foo=bar; charset=latin-1` give 415. | R-AP23, R-AP44, R-AP21 | Red against the code of 2026-11-01 (it needs the quoted form) |
| W2 | `router/r-ap21-unknown-method`: `PUT`, `DELETE`, `PATCH` on unknown paths. 404. | R-AP21, R-AP23 | Red |
| W2 | `router/r-ap23-unsupported-media-type`: `POST /v1/closure` with `text/plain`, no content type, `application/xml`, `application/jsonx`. 415 with the `detail` of section 5, D1 count 0. | R-AP21, R-AP23 | Red |
| W2 | `router/r-ap21-handler-err-internal`: `POST /v1/closure` with `application/json`, with `application/json; charset=utf-8`, with `Application/JSON`. The stub handler gives `Err`, so 500 `internal` with the fixed `detail`. | R-AP21, R-AP23, R-WH1 | Red |
| W2 | `router/r-ap44-unknown-ignored`: the same request with unknown query parameters and unknown body members gives the same answer. A path with unknown query parameters gives the same 404 and the same `detail` (the query is not in the text). | R-AP44, R-AP21 | Red |
| W2 | `runner/r-wh4-status-json-headers`, `runner/r-wh4-d1-count-and-rows`, `runner/r-wh4-github-and-clock`: the runner on the answers of the test entry (`/__test/...`): status, headers, JSON subset, exact body, `problem`, D1 count, rows after, the fake GitHub and its log, the fixed clock | R-WH4, R-AP41 | Green (they do not use the Roc code) |
| W2 self-test | `selftest/wrong-status`, `wrong-json-field`, `wrong-json-array`, `wrong-header`, `wrong-body`, `wrong-problem-content-type`, `wrong-problem-member`, `wrong-clock`, `wrong-d1-count`, `wrong-d1-row`, `wrong-github-log`, `unexpected-github-call`, `missing-fake-route`, `wrong-response-count`: each case has a wrong expected value. The runner must report the failure with the text in the file `expect-fail`. | R-WH4, R-AP21, R-AP23 | Green (a self-test passes when the case fails as written) |
| W1 | `sql/tests/cases/example/e1-trigger-and-query`: a STRICT table, a trigger with `RAISE` and a `CASE ... END`, a parameter, `json_each`, an expected error. Runs on `node:sqlite` and on local D1. | R-WH4 | Green |
| W1 self-test | `sql/tests/selftest/wrong-row`, `no-error` | R-WH4 | Green |

Rule ids are in the file `rules` of each W2 case, in the comments of the W0 files, and in the dir name (TW13, TW36). `MISSING=1 scripts/rules.sh R-AP R-WH R-PL` lists what no test names. `scripts/rules.sh` counts `sql/tests/` and `worker/tests/` now (TW36). The comments of the runner files hold no rule id, so they do not count as tests.

### 4.1 Red results (2026-11-01)

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | 23 expects, 0 passed, 23 failed with `todo`. `frame.sh`, `fmt` and the driver check pass. |
| `scripts/test.sh w1` | 6 passed, 0 failed |
| `scripts/test.sh w2` | 17 passed, 8 failed. The 8 red cases are the `router/*` cases. Each fails with `status: expected 404, got 500` or the same for 415/500, `body is not JSON: trap RuntimeError: unreachable`, and the Worker log `fetch: trap: todo`. |

A private reference (the stubs filled, `research/slice-101-revert/reference/`) makes all 23 W0 expects and all 25 W2 cases pass (updated for R-AP48, 2026-11-01). Five mutations of the reference were caught: the problem content type `application/json` (5 router cases fail), no media check (`r-ap23`), a handler `Err` that crashes (`r-ap21-handler-err-internal`, `r-ap44`), a D1 call on each request (3 cases fail on the D1 count), and a query string in the 404 `detail` (3 cases fail). Keep the reference until the review is applied.

## 5. Output (proposed, TW24)

The design gives the `type`, the status and the member names. It does not give the `title` and `detail` texts. These are proposals for the human.

| `type` | `title` | When the Worker gives it in this slice | `detail` |
| --- | --- | --- | --- |
| `/errors/not-found` | `Not found` | (method, path) is no route | `no route for <METHOD> <path>`. The path is the segments joined with `/`, with a leading `/`, and has no query. |
| `/errors/method-not-allowed` | `Method not allowed` | The path is a route, and the method is not served on it | `<METHOD> is not allowed on <path>`, for example `GET is not allowed on /v1/closure`. The header `Allow` is `POST` for `/v1/closure`. |
| `/errors/unsupported-media-type` | `Unsupported media type` | A route that takes a JSON body, a body, and a media type that is not `application/json` | `the request body must be application/json, got <content type as sent>`. With no `Content-Type`: `the request body must be application/json, but the request has no Content-Type`. |
| `/errors/internal` | `Internal error` | A handler gave `Err` | `the Worker failed to handle the request`. The same text for each fault, so the answer shows no inner state. |

The other 12 titles are in `ProblemTest.roc` (`Bad request`, `Unauthenticated`, `Forbidden`, `Repository changed`, `Label conflict`, `Id collision`, `Unsupported client`, `Too large`, `Not a candidate`, `Successor mismatch`, `Sweep incomplete`, `Rate limited`, `Upstream error`). The form is the type name in words, with the first letter in upper case.

| Item | Proposal |
| --- | --- |
| `Content-Type` of a problem | Exactly `application/problem+json`, with no `charset` (RFC 9457 defines no parameter). The test compares the whole value. |
| Members of a problem in this slice | `type`, `title`, `status`, `detail`. The members `minimum`, `field`, `limit`, `issues_url` of other types are added by the slices that give those types. |
| Test-only headers | `x-d1-calls` and `x-d1-ops` (the D1 count) on each response of the test entry `worker/tests/worker-test.js`. The production entry `worker.js` does not set them. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| Field-level R-AP44 (an unknown member of a typed request body is ignored) | This slice has no typed request: the closure handler is a stub. The case `r-ap44-unknown-ignored` shows only that an unknown query parameter and an unknown member change nothing (the answer is 500 `internal` with or without them, not 400). The probe `research/registry-plan/json-extra/` shows that the derived `Json.parse` ignores unknown keys. Slice 110 (closure) and slice 112 (ingest) test the typed request. |
| The 400 `bad-request` for a body that is not valid JSON or a request with no body on a body route | It needs the typed request of the route. Slices 110, 112, 114, 115, 116. |
| R-AP48 rows 3, 4 and 6 (400 `unsupported-client`, 413 `too-large`, 400 `bad-request`), and 429 | Settings, limits and the typed body: slices 110, 112, 116. The skeleton has no setting and no typed body. |
| `ETag`, `Cache-Control`, `Talon-Bookmark`, the Cache API | Slice 106 |
| OIDC tokens, the signed JWT, the fake JWKS in the runner | Slice 108 |
| `worker/tests/tools/mk-bundle.mjs` (a `.tar.zst` of a package for the fake GitHub) | Slice 111 (it needs the tar form of the archive reader). `PLAN.md` C.1 puts it in 101: moved. |
| A cron run with its own time | `worker-test.js` sets the time of a request through its `fetch`. A `scheduled` event does not pass through `fetch`, so a cron run gets the default time of `clock.js` (2026-01-01T00:00:00Z). A case that needs another time for a cron needs a change of the entry. Slice 119. |
| `ci.yml` (TW35): the steps `w0 w1 w2` on Linux, `w0` on macOS and Windows. `scripts/get-roc.sh` for `ROC_TAG_WORKER`. | The manager (workflow files). The `w` steps need `ROC_TAG_WORKER`, Node 26, a global wrangler, and the network for the first platform download. |
| The decision whether `packages/records` takes `Problem` (slice 104) | `Problem` is in `worker/lib/` now. Slice 104 can move it to `packages/records`. |
| The `--opt=speed` form of the Worker build | `OPT=speed` is passed to `roc build --target=wasm32`. Not run in this slice. |
| `UPDATE=1` for the W2 expected files | Not built. The expected files are small and written by hand. |

## 7. Questions (stop until answered)

| Id | Question | Options | Effect now |
| --- | --- | --- | --- |
| Q101-1 | What does a request get for a method that is not served on a known path (for example `GET /v1/closure`)? R-AP21 has no 405 type. | (a) 404 `not-found` (the pair method and path is no route); (b) 400 `bad-request`; (c) a new type `method-not-allowed`, 405, with an `Allow` header (R-AP44: a new problem type stays in `/v1`) | No test covers it. `Route.decide` for this input is not fixed: `RouteTest.roc` has no row. The stub doc comment says rule 1 (404) only for a (method, path) that is no route. Proposal: (a). |
| Q101-2 | A request with a body on an unknown path and a non-JSON media type: 404 or 415? | (a) 404: the route comes first (the stub rule); (b) 415 for each request with a non-JSON body | No test covers it. `RouteTest.roc` has no row. Proposal: (a). |
| Q101-3 | Is `application/json; charset=latin-1` accepted? R-AP23 says UTF-8. | (a) accept: the parameters are not read; (b) 415 for a charset other than UTF-8 | `RouteTest.roc` expects (a) only for `charset=utf-8`. No row for another charset. |
| Q101-4 | A request with an empty body, or no body, on a body route: does the route give 400 `bad-request`, or a 415 with the media check? | The stub checks the media type only when the body is not empty (section 3.3, R-AP21 "request body"). The 400 belongs to the route (slices 110 and later). | `RouteTest.roc` has two rows that expect `Handle` (no check without a body). Confirm. |
| Q101-5 | Is the stub `POST /v1/closure` with `Err(NotBuilt)` (500 `internal`) acceptable until slice 110? | Another way to test "an `Err` of a handler gives 500 `internal`": a route only for tests (a production route with a test switch), or W0 only | The cases `r-ap21-handler-err-internal` and `r-ap44-unknown-ignored` expect 500 for a valid JSON body. Slice 110 changes both. |

Answers (manager, 2026-11-01, Design Q69, Registry R-AP48):

| Id | Answer |
| --- | --- |
| Q101-1 | (c) 405 `method-not-allowed` with an `Allow` header (RFC 9110, 15.5.6). New row in R-AP21. |
| Q101-2 | (a) 404. The path check comes first (R-AP48 row 1). |
| Q101-3 | (b) 415. Accepted: `application/json` with no parameter or `charset=utf-8`, case-insensitive (R-AP23). |
| Q101-4 | Confirmed. No body gives no media check. A route that needs a body answers 400 (R-AP23, R-AP48 row 5). |
| Q101-5 | Yes, until slice 110. |

The test agent added the W0 rows and the W2 cases for Q101-1 to Q101-3 (`RouteTest.roc`, `router/r-ap48-*`, `router/r-ap23-charset`), and the 405 title and `detail` (section 5). Review: tests accepted by the manager (2026-11-01). The human review is pending.

## 8. Platform issues

| # | Issue | Evidence |
| --- | --- | --- |
| P1 | The option `now` of `makeHandler` is the clock of the task deadlines, the memory budget and the pins only. `Time.now_ms!` calls `Date.now()` directly. A reader of `options.js` (`now: fn`, no text) and of `tasks.js` / `budget.js` ("`now` (a clock for tests)") expects that `now` fixes the time of the app. `PLAN.md` G10 expected this. The way that works is to set `Date.now` before the shim loads (`worker/tests/clock.js`). | `Time.roc` (`Date.now()` through `Js.call!`), `js/options.js:40`, `js/budget.js:20`. Probe `research/slice-101-revert/clock-probe/main.roc`: a request with `now` 1790000000000 gives `Time.now_ms!` = 1790000000000 with `clock.js`. |
| P2 | No supported test helper. Plain Miniflare options fail with `Unrecognized keys: "modules", "script", "compatibilityDate", "d1Databases", "d1Persist"`. `convertV4MiniflareOptions` from the global wrangler is needed, and nothing in the platform docs says so (only `conformance/run.mjs` shows it). The D1 count needs a subclass of the class that `makeHandler` gives, which swaps `env.DB` in its constructor. This works in 0.0.2 but depends on how the shim reads `this.env` (same as E1 and E2 of `PLAN.md`). | `sql/tests/run.mjs` (the first try failed with the text above), `worker/tests/worker-test.js` |
| P3 | A `crash` in a handler gives a 500 with a plain text body `trap RuntimeError: unreachable` (`text/plain`), and the log line `fetch: trap: todo`. Not a fault: noted because a Worker that must always answer in problem form cannot do it for a `crash`. The registry code must give `Err`, never `crash`, for each runtime fault. | `scripts/test.sh w2` red output |
| P4 | An HTTP method that workerd does not know (for example `BREW`) gets `501 Unrecognized request method` from the runtime before the Worker runs (text, not problem form). So a case with such a method cannot test the Worker. The case `r-ap21-unknown-method` uses `PUT`, `DELETE` and `PATCH`. This is a workerd fact, not a platform fault. | First run of the case with `BREW`: status 501, body `ERROR: Unrecognized request method.` |
| P5 | `dispatchFetch` with a string body adds `Content-Type: text/plain;charset=UTF-8`. A case that needs a request with no `Content-Type` must send bytes. The runner does. | `worker/tests/run.mjs` (the comment at `Buffer.from`) |

## 9. Disputes (from the code agent)

| # | Test | Problem | Design source | State |
| --- | --- | --- | --- | --- |
| D1 | `tests/tools/ciscan.py` `check_fast` | The matrix pinned `""` for macOS and `check fmt l0` for Windows, against TW35. | TESTING.md TW35 | Resolved (coordinator, 2026-11-01): `ciscan.py` now pins macOS `check fmt l0 l2 l3 w0 selftest l1` and Windows `check fmt l0 w0`. `ci.yml` matches. The Worker compiler is installed on each OS (w0 needs it). Node and wrangler: Linux only. |

## 10. Verify results

Code agent run (2026-11-01, this machine). The code is in `worker/main.roc` (`fetch!`, `has_body`, `problem_response`, `handle!`, `run!`), `worker/lib/Problem.roc` and `worker/lib/Route.roc`. `scheduled!` and `queue!` stay `crash "todo"` as section 3.3 item 5 says (no cron or queue entry yet, so no event reaches them).

| Command | Result | Seconds |
| --- | --- | --- |
| `scripts/test.sh w0 w1 w2` | w0 pass (23 expects), w1 pass (6), w2 pass (25 cases, 0 failed) | w0 0.2, w1 0.5, w2 1.9 |
| `scripts/test.sh` (default list) | check pass, l2 pass, l3 pass (incl. `cache/gc1-real`), w0 w1 w2 pass, l1 pass. `fmt` FAIL, `l0` FAIL, `selftest` FAIL (1 of 75 rows). | total 78 |
| `scripts/rules.sh R-AP R-WH R-PL` | tests per rule: R-AP21 17, R-AP23 11, R-AP41 2, R-AP44 5, R-AP48 6, R-WH1 2, R-WH4 21, R-WH12 2, R-WH13 2, R-PL2 2 | |

The three failures have one cause, not this slice: `packages/records/` (slice 104, another agent) has `tests/CodeTest.roc` whose functions do not exist yet, and `tests/CodeTest.roc` and `tests/WireTest.roc` that the CLI compiler `fmt` cannot parse (a `targets` line). `fmt` fails on both files, `l0` fails on `CodeTest.roc`, and the selftest row "unit guard" runs the `l0` step on the whole tree. No failure is in `worker/`, `sql/`, `cli/` or the files of this slice.

Rules with no test in `R-AP R-WH` (`MISSING=1`): R-AP4 to R-AP12, R-AP18 to R-AP20, R-AP22, R-AP24 to R-AP28, R-AP30, R-AP31, R-AP33 to R-AP40, R-AP42, R-AP43, R-AP47, R-WH2, R-WH3, R-WH5 to R-WH11, R-WH14. These belong to later slices (section 6).

Decisions that the slice does not fix:

| Item | Choice | Rejected |
| --- | --- | --- |
| `Content-Type` parameters | Replaced by the new R-AP23: see 10.1. | |
| Handler `Err` | `handle!` maps each `Err` to `Internal` with the fixed `detail`. | A `crash` (R-AP48 forbids it). |

`scripts/get-roc.sh` takes the optional argument `worker` and installs `ROC_TAG_WORKER` into `$WORK/nightlies/<tag>` (tested: first run downloads, second run finds it, an unknown argument exits 1). `ci.yml` and `nightly.yml` write `ROC_TAG_WORKER` to `GITHUB_ENV`, add it to the compiler cache key, install the Worker compiler into `ROC_WORKER`, and set up Node 26 and `wrangler@4.151.0` (not on Windows in `ci.yml`). The package-URL hash of `ci.yml` also reads `worker/`. The matrix is unchanged because of dispute D1: Linux runs the default list (so `w0 w1 w2`), and macOS runs it too until D1 is decided. The self-test rows `ci/*` pass.

The revert check (TW12) is not run by this agent: the manager did not ask for it.

Timing and the old fast set (2026-11-01, this machine, test agent run):

| Run | Result | Seconds |
| --- | --- | --- |
| `scripts/test.sh w0 w1 w2` | w0 FAIL (red, expected), w1 pass, w2 FAIL (red, expected) | w0 0.2, w1 0.7, w2 1.7 (the build of `app.wasm` overlaps w0 and w1; it takes 5 to 7 s alone) |
| `scripts/test.sh check fmt l0 l2 l3 selftest l1` | check, fmt, l0, l2, l1 pass. selftest passes after the two changes below. `l3` has one failure, `cache/gc1-real`: the tree diff and the sizes of `would remove ... compat-*` differ. The case reads file times of a `given/` copy. It is not in a file of this slice (no change in `cli/` or `tests/scenarios/`). Not caused by this slice. | l0 10.4 (WARN, budget 10), l3 11 |

Changes to existing files, because the registry steps change them (the copies before are in `research/slice-101-revert/before/`):

| File | Change |
| --- | --- |
| `scripts/test.sh` | The steps `w0 w1 w2`, their budgets, `ROC_WORKER`, `worker_build`, the default list `check fmt l0 l2 l3 w0 w1 w2 selftest l1` (TW32) |
| `scripts/rules.sh` | `TEST_DIRS` has `sql/tests` and `worker/tests` (TW36) |
| `tests/selftest.sh` | The row "the default steps of scripts/test.sh" reads the new list |
| `tests/tools/ciscan.py` | `check_pin`: `scripts/env.sh` has 2 nightly tags (`ROC_TAG` and `ROC_TAG_WORKER`, the line that the design agent added to `scripts/env.sh`) |

### 10.1 Follow-up: R-AP23 parameters, TW35 matrix (2026-11-01)

| Change | Detail |
| --- | --- |
| `Route.is_json_media` | `charset` must be `utf-8` as a token or a quoted string, no case. Other parameters are ignored, also one with `;` inside quotes (`split_params` joins the pieces of an odd number of quotes; a backslash escape in a quoted string is not read). Any other charset, also in a later parameter, gives 415. A repeated `charset` must be `utf-8` each time. This replaces the "exactly one parameter" decision of the table above. |
| `ci.yml` | The matrix is as D1 says. Node and wrangler steps run on Linux only. |
| `scripts/test.sh w0 w1 w2 selftest` | w0 pass (0.3 s), w2 pass (26 cases, 2.4 s). w1 FAIL: the new cases `schema/*` of slice 102 (`sql/tests/`, another agent), not this slice. selftest 74 of 75: only the "unit guard" row fails, because `l0` runs on `packages/records/` (slice 104, another agent). The `ci/*` rows pass. |

## 10.2 Follow-up: a request with no body (manager, 2026-11-02)

Cause: under Miniflare, a POST with no body reaches the Worker with a body that is not `Empty`, so the media check of R-AP23 ran and gave 415. Fix (code agent): `body_present!` in `worker/main.roc`. `content-length: 0` is no body, and a positive length is a body. With no header, or a header that is not a number, the Worker reads at most 262144 bytes (R-AP46): 0 bytes is no body. A read that fails or that is too large counts as a body. Test: `router/r-ap23-no-body` (added by the harness owner). The 415 is gone. The case expects 400 and gets 500 until the closure route of slice 110 exists.
