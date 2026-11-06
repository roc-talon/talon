# 200 HTTP writes, fake registry harness

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 200 of `PLAN-P2-CLI.md`. This slice is harness. It adds 3 calls to the `Fx` record, a real version of each, a fake version of each, and one route form for the L2 and L3 fake HTTP servers. No command uses them yet: slice 201 and the later registry slices do.

## Scope

| Part | Where | State after the test step |
| --- | --- | --- |
| `Fx.http_send!`, `Fx.http_all!`, `Fx.sleep!` (field and accessor) | `cli/lib/Fx.roc` | Done (the types are the public signatures, section "Public signatures") |
| Real `Fx`: the 3 calls | `cli/RealFx.roc` | Stubs, `crash "todo: slice 200"` |
| `fxprobe send`, `all`, `sleep` (the L3 driver of the real `Fx`, TW4) | `cli/fxprobe.roc` | Done (test tool, no Talon logic) |
| Fake `Fx` (L2): routes by method, the n-th answer, `require`, the body in `calls.log` | `tests/commands/FakeJobs.roc`, `FakeFx.roc` | Done (harness) |
| L2 entry `http` | `tests/commands/L2Http.roc`, `main.roc` | Done (harness) |
| Fake HTTP server (L3): `POST`, `PUT`, `DELETE`, the same route form, a body log | `tests/tools/fakehttp.py` | Done (harness) |
| `tests/run.sh`: optional `expect/http-bodies/` | `tests/run.sh` | Done (harness) |
| One example case of each new check | section "Tests" | Done |

## Rules

| Rule | What this slice tests about it |
| --- | --- |
| R-AP23 (client part) | A write has the header `Content-Type: application/json` and a body. The fake route can require it (`require`), and a request with no such header gets 599. The harness has no logic about media types: the headers are the ones that the caller passes, and the body is sent as bytes. The pure code that makes the headers is slice 201 (`Registry`). |
| R-AP45 (client part) | The same for `User-Agent: tln/<version>`: a route can require it, and `Fx` adds no header of its own that a test can see. |
| R-AP34 (the waits) | `sleep!` exists. The fake writes `sleep <ms>` to `calls.log` and does not wait. The real one waits at least the time. The retry rule itself (3 more tries, 2 s, 8 s, 30 s, `Retry-After`) is a later slice. |
| R-AD35 step 3 | `http_all!` runs up to `limit` requests at the same time (4 in R-AD35), and the results are in the order of the list. L3 sees at most 4 and at least 4 at the same time with 8 slow requests. |
| R-DA1 | A small API answer does not use the download adapter: `http_send!` and the GET and POST routes of the cases. See question Q1 for `http_all!`. |
| R-DA5 | The limit of parallel requests of `http_all!`, the same loop idea as the downloads. See Q1. |
| R-DA8 | `http_all!` runs `curl` children (Design Q224): the command line has `--proto =https,http` and `--max-time`, no `--fail`, no `--location`, `-H` for the headers and the body in a file of `tmp_dir`, and the temp files are removed. A request with `Authorization` or `Talon-Contributor` is not sent (Q6). A limit of 0 runs 1 at a time (Q226). No `curl`: each result is `Failed` (Q7). The URL check of R-RG7 is a rule of the caller (TW4). Tested in L3 `hw3` with a `curl` shim that logs its arguments, and in L2 (limit 0 in the log). |
| R-DA9 | The timeout is the time of the whole answer: a body that comes in parts over 2 s with a timeout of 1 s gives `Timeout`, for `http_send!` and `http_all!`. The case waits about 1 s. |
| R-CC2 | The body temp files are in `tmp_dir` (`talon/tmp/`) and are removed. |
| R-AP9, R-AP10, R-RG3 | Named in the examples (an ingest is a POST with a JSON body, a hint is a POST, a request to a registry has no token). The harness only carries them. |

## Public signatures

The types are in `cli/lib/Fx.roc`. `Method` is the closed union `[Get, Post, Put, Delete]`. These are the 4 methods of the registry client (Registry 4.2, R-AP41), so a later slice that needs `PATCH` changes the union and the 2 fakes.

| Call | Type | Note |
| --- | --- | --- |
| `fx.http_send!(request)` | `{ method : [Get, Post, Put, Delete], url : Str, headers : List((Str, Str)), body : Str, timeout_s : U64 } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])` | As `http_get!`: a status of 400 or more is an answer. An empty `body` is no body. `Fx` adds no header. |
| `fx.http_all!({ requests, limit, tmp_dir })` | `{ requests : List(<the request above>), limit : U64, tmp_dir : Str } => List(Try(<the answer above>, [Timeout, Failed(Str)]))` | The result at place i is the result of `requests[i]`. A failed request does not stop the others. `tmp_dir` is the dir for the body files (R-DA8 rule 2, `talon/tmp/`): the caller knows the roots, so the `Fx` has no path logic (TW3). Added after the answer of Q224 (proposal, Q6). |
| `fx.sleep!(ms)` | `U64 => {}` | Milliseconds. The unit is a proposal (Q3). |

The real `Http.send!` of basic-cli 0.26.0 has everything that `http_send!` needs: `Request.from_method` takes `GET`, `POST`, `PUT` and `DELETE` (http 1.0.0 `Method`), `Request.with_body` takes `List(U8)`, and `Request.with_timeout` takes `TimeoutMilliseconds(U64)`. `Http.send!` blocks, so `http_all!` cannot use it for parallel requests. The private reference (see "Revert check") runs `curl` children through `spawn_all!` (`RealJobs.run_jobs!`), with `--include` for the status line and headers, `--data-binary @<temp file>` for a body and `-H "Expect:"`. That is the code agent's choice, with Q1.

## Tests

| Layer | File and case | Checks |
| --- | --- | --- |
| L0 | None. The slice has no pure decision: the real `Fx` has no Talon logic (TW4) and the fake is test code. The fields are type-checked by `roc check` of `cli/main.roc` and `tests/commands/main.roc`. | |
| L2 | `tests/commands/cases/registry/ap23-http-writes` (entry `http`, `tests/commands/L2Http.roc`): 18 runs. POST with the 4 answers of one route (201, 200, 409 `problem+json`, then the first again), a request with no header and a request with `Authorization` that break `require` and `require-none` (599), GET of the same URL (the plain route), PUT with a 2-line body (the log escapes it), DELETE with 204, a route with no file (404), the timeout in the log, an `error timeout` route, `http_all!` with limit 2 and 4 (list order, a 404 and a timeout in the list), `sleep!` 2000 and 8000 | R-AP23, R-AP45, R-AP34, R-AD35, R-DA1, R-DA5, R-AP9, R-AP10, R-RG3 |
| L3 | `tests/scenarios/fx/hw1-real-fx-http-send` (`fxprobe send`): the real `http_send!` for POST, the 2nd answer, a request that breaks `require`, PUT with a body of 2 lines and a backslash, DELETE 204, GET, 404 for a write. `expect/http.log` has the methods and `expect/http-bodies/` has the 5 bodies (named by the line of `http.log`) | R-AP23, R-AP45, R-DA1, R-AP9, R-AP10 |
| L3 | `tests/scenarios/fx/hw2-real-fx-http-all` (`fxprobe all`, `fxprobe sleep`): the real `http_all!` with 8 requests and limit 4 (the first is the slowest: list order, and `http.maxconn` is 4), limit 1, a failed request in the list, POST and GET in one list, headers and bodies in a list (the route needs both headers, the server got both bodies), an empty list, a body of 20000 bytes, `sleep!` waits at least the time | R-AD35, R-DA5, R-DA1, R-AP34, R-AP23, R-AP45, R-AP9 |

| L3 | `tests/scenarios/fx/hw3-real-fx-http-all-rules` (`fxprobe all`, a `curl` shim): limit 0 gives `http.maxconn` 1; the arguments of curl (`--proto =https,http`, `--max-time 7`, `-H`, the body file in `tmp_dir`, no `--fail`, no `--location`); no temp file left; a request with `Authorization` or `Talon-Contributor` gets `Failed`, has no secret in the arguments and no request at the server, also for the names in other case (`h:authorization`, `h:TALON-CONTRIBUTOR`, Q228); no `curl` on `PATH`: each result `Failed`; the whole-answer timeout (`slow 700` body, 1 s) for `http_send!` and `http_all!` | R-DA8, R-DA9, R-CC2, R-AD35, R-DA1 |
| L2 | The case `ap23-http-writes` has run 17: `all 0` (the log has `limit=0` and `tmp=`) | R-DA8 |

The L3 cases `hw2` and `hw3` have no `expect/http.log`: the order of arrival of parallel requests is not fixed.

## The route form (design of the harness)

One form for the L2 fake (`fx/http/`), the L3 server (`given/http/`) and, as far as it fits, the W2 fake GitHub (`worker/tests/run.mjs`, header lines 14 to 69). TalonRegistry suggested one form for both harnesses. The CLI form is older (slices 003 and 046) and is kept, with 4 additions that the Worker form already has or needs.

| Item | CLI form before slice 200 | Worker form (`github/`) | Form of slice 200 (CLI) |
| --- | --- | --- | --- |
| One file is one URL | `<host>/<path>`, with a query: `<path>?<query>` first (names encoded as TESTING 3.1) | `<host>/<path>` and `%3F<query>` at the end | Same as before |
| Body | The file | The file | Same |
| Status and headers | `<file>.meta`, one line each: `status <n>`, `header <Name>: <value>`, `error timeout`, `error failed <text>` (L2), `slow <ms>`, `body @<file>` (L3) | `<file>.meta.json`: `{"status", "headers"}` | Same `.meta` lines. A `.meta.json` would be a second form in the CLI tests, with no gain. |
| Method | None (GET only) | Not in the name (the Worker log has `METHOD url`, the file is the URL) | **`<file>` is `GET`. `<file>.POST`, `<file>.PUT`, `<file>.DELETE` are the other methods**, each with its `.meta` (`<file>.POST.meta`). Reason: the same URL has a GET and a POST in the registry (`/v1/releases`, `/v1/tokens`), and the Worker has no such pair in its fake because GitHub gets reads only. |
| The n-th answer | None | `<file>.<n>` (n from 2), own `.meta.json`. No file for n: the first one. | **`<file>.<n>`** with its own `.meta`: `x.POST.2`, `x.POST.2.meta`. No file for n: `<file>`. n counts the requests of the same method and URL (the Worker counts a URL; its fake has one method for each URL, so the 2 rules agree there). In L2 n counts the `calls.log` lines of the case, so it counts across the runs of one case. |
| Header rule | None | `"require": {"authorization": "Bearer x"}`, `null` for "must not have it", lower-case names, exact values | **`require <name>: <value>`** and **`require-none <name>`** in `.meta`. The name is matched in any case, the value exactly. A break gives status 599 and the body `wrong header`. The Worker adds the failure to the case errors, so its case fails. A CLI case fails because 599 is in its output. |
| A route with no file | 404 `{"message":"Not Found"}` | 599, and the case fails | **404, as before, for every method.** Reason: 404 is a real answer that commands must handle (R-AD35 starts with a 404 of `releases`), and about 100 cases use it. A write with no route is a missing file, and it shows in the log (`POST ... 404`). |
| Dir and file at one path | `<dir>/@` (L2) | `<dir>/%2F` | Same as before. The Worker form `%2F` is not taken: a rename of 2 forms in about 20 cases. Open for the human (Q5). |
| 204 and 304 | An `ETag` route gives 304 for the same `If-None-Match` | A 204 or 304 has no body | A status 204 or 304 in `.meta` gives no body. The `ETag` rule stays. |
| Request body | None | None (the Worker is the server) | L2: the line `  <body> <text>` in `calls.log` (below). L3: `<state dir>/http-bodies/<k>` and `expect/http-bodies/<k>`. |

The log of an L2 write:

```text
http_send POST http://127.0.0.1:9/v1/releases timeout=20
  Content-Type: application/json
  User-Agent: tln/0.4.1
  <body> {"url":"https://github.com/o/r/releases/download/v1/a.tar.zst"}
http_all limit=2
http_send GET http://127.0.0.1:9/v1/n/c timeout=20
...
sleep 2000
```

| Log line | Meaning |
| --- | --- |
| `http_send <METHOD> <url> timeout=<s>` | One `http_send!` (or one request of `http_all!`) |
| `  <Name>: <value>` | A header of the request, in order (as for `http_get!`) |
| `  <body> <text>` | The body, only when it is not empty. `\` is `\\`, a new line is `\n`, a carriage return is `\r`, so a body is one line. |
| `http_all limit=<n>` | One `http_all!`. Its requests follow, each as an `http_send` block, in the order of the list. |
| `sleep <ms>` | One `sleep!`. The fake does not wait (TW15). |

L3 body log: `fakehttp.py` writes the body of the k-th request to `<state dir>/http-bodies/<k>`, where k is the line number of that request in `http.log` (from 1). A request with no body has no file. The runner copies the files to `out/http-bodies/` (with `normalize`, so a port in a body is `$PORT`). `expect/http-bodies/` is optional: when the case has it, the runner compares the 2 dirs with `diff -r`, so a missing, an extra or a changed file fails the case. `UPDATE=1` with `HTTP_BODIES=1` writes it.

## TESTING proposal

Text for TESTING.md, to be added by the session that owns it. Item 1 replaces the row `given/http/` in the layout of 3.1 and adds the row `expect/http-bodies/`. Item 2 is a new block after the table of the file names (after the `%XX` table) in 3.1. Item 3 replaces the row "Fake HTTP" in 3.2. Item 4 is a new row of the table in 2.4. Words are the ones of the file.

Item 1 (3.1, the layout block):

```text
  given/http/        routes for the fake HTTP server (GitHub API JSON, release assets, the registry), see "Fake HTTP routes"
  expect/http.log    optional: the requests that the fake server got, one line each: METHOD, path and query, status
  expect/http-bodies/  optional: the body of each request that had one, a file for each, named by the line number of the request in http.log (from 1). The runner compares the dirs: a missing, an extra or a changed file fails the case.
```

Item 2 (3.1, new block "Fake HTTP routes"):

```markdown
### Fake HTTP routes

The L2 fake `Fx` (`fx/http/`) and the L3 server (`given/http/`) have one route form. One file is one URL: `<host>/<path>`, and `<path>?<query>` for a URL with a query (the query file first). The names are encoded as above (`%3F`, `%3A`).

| Item | Rule |
| --- | --- |
| The body | The file. When the path is also a dir, the file `<dir>/@`. |
| `<file>.meta` | One line each: `status <n>`, `header <Name>: <value>`, `error timeout`, `error failed <text>` (L2), `slow <ms>`, `body @<file>` (L3). A status 204 or 304 has no body. A header `ETag` gives 304 for the same `If-None-Match`. |
| The method | `<file>` answers `GET`. `<file>.POST`, `<file>.PUT` and `<file>.DELETE` answer the other methods, each with its own `.meta` (`<file>.POST.meta`). |
| The n-th answer | `<file>.<n>` (n = 2, 3, ...) answers the n-th request of the same method and URL in the case, with its own `.meta` (`<file>.POST.2`, `<file>.POST.2.meta`). With no file for n, `<file>` answers. In L2 the n counts the lines of `calls.log`, so it counts across the runs of one case. |
| `require` | A `.meta` line `require <name>: <value>`: the request has this header with this exact value (the name in any case). `require-none <name>`: it has not. A request that breaks a line gets status 599 and the body `wrong header`. |
| No file | 404 `{"message":"Not Found"}`, for each method. (The W2 fake GitHub gives 599 and fails the case, TESTING 9.) |
| The request body | L2: the line `  <body> <text>` in `calls.log` after the header lines (`\`, new line and carriage return escaped, so it is one line), only for a body that is not empty. L3: a file of `expect/http-bodies/`. |
| `Fx` calls | L2 logs `http_get <url>` (`http_get!`) and `http_send <METHOD> <url> timeout=<s>` (`http_send!` and each request of `http_all!`, after the line `http_all limit=<n>`), and `sleep <ms>` (`sleep!`, no wait). The results of `http_all!` are in the order of the list. |
```

Item 3 (3.2, row "Fake HTTP", the last sentence is the addition):

```text
... A package with a `github.com` URL is pre-filled in `given/home/` (`packages/<hash>/`). A fetch test uses a loopback package URL. The server answers `GET`, `POST`, `PUT` and `DELETE` with the route form of 3.1, and writes the body of each request to the body log. It counts the requests in flight at one time in `http.maxconn`: a case that checks the limit of parallel requests reads it (`http_all!`, R-AD35 step 3, R-DA5).
```

Item 4 (2.3, table "Job of the real `Fx`", new row):

```text
| `http_send!`, `http_all!`, `sleep!` (R-AP23, R-AP34, R-AD35) | Fake HTTP: a POST with a body (the body log), the n-th answer, a request that breaks a `require` line; 8 slow requests with limit 4: the server sees 4 at the same time (`http.maxconn`) and the results are in the order of the list; `sleep!` waits at least the time |
```

## Output (proposed, R-OUT2)

None. The slice has no command output. The L2 and L3 probes print their own lines (`status`, `header`, `body`, `err`, `result`, `slept`), which are test text, not Talon output. `fxprobe` prints only `err Timeout` or `err Failed` for the new calls: the text of `Failed` depends on the code of the real `Fx` and is not tested.

## Out of scope

| Item | Reason |
| --- | --- |
| The retry rule of R-AP34 (3 more tries, the waits 2 s, 8 s, 30 s, `Retry-After`, a new token after 401) | A client slice. This slice gives `sleep!` and the fake that does not wait. |
| The headers `Content-Type` and `User-Agent` of a request, the media-type rule (charset) | Slice 201 (`Registry`, pure) |
| The Worker side of R-AP23 and R-AP45 | W2 cases in `worker/tests/cases/` |
| The `limit` of 4 in R-AD35 and the ingest flow | Slice 212 |
| The exit code 18 for no `curl`, the URL check of R-RG7, the choice of the limit | The command slices (Q7) |
| `PATCH` and other methods | The 4 methods of R-AP41. A later slice adds a tag to the union. |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | R-DA1 says that the adapter (`curl` children) downloads archives and "nothing else", and that small API answers use `Http.send!`. R-AD35 step 3 says "up to 4 requests run at the same time", and `Http.send!` blocks, so 4 at one time needs child processes. May `http_all!` run `curl` children (with headers and a body, so R-DA3 "no token, no header" does not hold for it), or does R-AD35 run its ingests one after the other with `http_send!`? The test `hw2-real-fx-http-all` assumes parallel requests (it reads `http.maxconn` = 4). If the answer is "one after the other", `http_all!` is a plain loop and `hw2` changes (`maxconn` 1). | Answered (Q224, R-DA1, R-DA8). |
| Q2 | What is `timeout_s`: the time to the first byte of the answer, or the time of the whole answer? Design R-CC12 says a step that is not a wait ends in under 25 s, and `http_get!` has 20 s. `Http.send!` has one `TimeoutMilliseconds`. | Answered (Q225, R-DA9): the whole answer. Tested in `hw3`. |
| Q3 | The unit of `sleep!` (milliseconds, as basic-cli `Sleep.millis!`) and of `timeout_s` (seconds, as R-CC12 and the fake log `timeout=<s>`). The design gives no unit. | Answered (Q225): the units stay. |
| Q4 | A `limit` of 0 for `http_all!`: the real `spawn_all!` runs 1. The design says nothing. | Answered (Q226, R-DA8): 1 at a time. Tested in `hw3` and L2. |
| Q5 | The route form (Worker `%2F` against CLI `@` for a path that is also a dir; `.meta.json` against `.meta`; 404 against 599 for no file). The slice keeps the CLI form (table above). One form for both harnesses would change about 100 existing cases or the Worker runner. | Answered (Q227): the route form stays. |

| # | New question (test step after the answers) | State |
| --- | --- | --- |
| Q6 | R-DA8 rule 1 says a request with `Authorization` or `Talon-Contributor` "uses `Http.send!`, one at a time". What does `http_all!` do with such a request in its list? The tests use: it is not sent, and its result is `Failed("credential")` (the caller splits the list). Also, rule 2 gives the body temp file the dir `talon/tmp/`, but `Fx` has no roots: the tests pass the dir as `tmp_dir` in the batch. | Answered (Q228): confirmed. The names `Authorization` and `Talon-Contributor` match in any case (`hw3` has `h:authorization` and `h:TALON-CONTRIBUTOR`). |
| Q7 | R-DA8: "no `curl`: the command stops with exit code 18". `http_all!` gives a list of Try, with no exit code. The tests use: with no `curl` each result is `Failed(text)`, and the command (a later slice) asks `programs!(["curl"])` first and stops with exit 18, as for R-DA2. | Answered (Q229): confirmed. The exit 18 itself is a test of that later slice. |

Answers (design agent, 2026-11-03):

| G-C | Design Q | Answer | Test change |
| --- | --- | --- | --- |
| G-C45 (Q1) | Q224 | `http_all!` runs `curl` children, up to the limit, at the same time (CLI R-DA1, new R-DA8). Only `curl`. A request of the list carries no `Authorization` and no `Talon-Contributor` (such a request uses `http_send!`). The body is a temp file (`--data-binary @<file>`), no `--fail`, no `--location`, the timeout is `--max-time`. | None: `hw2` keeps `maxconn` 4. Optional: a case with no `curl` on `PATH` gives exit 18. |
| G-C46 (Q2) | Q225 | The time of the whole answer, to the last byte (CLI R-DA9). Q3: the units stay (the timeout in seconds, `sleep!` in milliseconds). | None |
| G-C47 (Q4) | Q226 | A limit of 0 runs 1 request at a time, as `spawn_all!` (CLI R-DA8) | Optional: an L2 run with limit 0 |
| G-C48 (Q5) | Q227 | The 2 harnesses may differ in the 3 items. The CLI form of this slice stays. TESTING.md 3.1 "Fake HTTP routes" names the differences. | None |
| G-C49 (Q6) | Q228 | Confirmed: a request with `Authorization` or `Talon-Contributor` (any case) is not sent, and its result is `Failed("credential")` (CLI R-DA8) | None: the tests use the proposal |
| G-C50 (Q7) | Q229 | Confirmed: `http_all!` gives `Failed` for each result with no `curl`. The command asks `programs!(["curl"])` first and stops with exit 18. The `tmp_dir` in the batch is not against a rule (TW4). | None: the tests use the proposal |

## Disputes (from the code agent)

None yet.

## Red result

L3 with the stub `RealFx`: `tests/run.sh fx/hw` fails the 3 cases `hw1`, `hw2`, `hw3` with `[ROC CRASHED] todo: slice 200` (the first call of each). L2 `tests/commands/run.sh registry/ap23` passes: the fake `Fx` is the harness of this slice, so its example case is green at the test step (it tests the fake). `scripts/test.sh check fmt l2 l3` (2026-11-03): check, fmt and l2 pass (the old L2 cases and `registry/ap23-http-writes`). After the answers (second run): l3 fails only `hw1`, `hw2` and `hw3` (`todo: slice 200`).

## Revert check

`research/slice-200-revert/before/RealFx.roc` is the stub file. The private green reference (`http_send!` on `Http.send!`, `http_all!` on `curl` children, `sleep!` on `Sleep.millis!`) and `mutate.py` were deleted at the end of the test step (the code agent must not see them). With the reference, `hw1`, `hw2` and `hw3` passed, and `hw3` passed 4 times in a row. `mutate.py` applied each mutation, ran the cases and restored the file. Results are in `research/slice-200-revert/results.txt`. Each mutation is on the reference (M1 to M8) or on the harness (M9 to M17), one at a time:

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `http_all!` gives the results in the order of the end (the first result last) | `hw2` |
| M2 | `http_all!` ignores the limit | `hw2` (`http.maxconn` 8, not 4) |
| M3 | `http_all!` runs at most 2 at a time | `hw2` (`http.maxconn` 2) |
| M4 | `http_send!` sends no body | `hw1`, `hw2` |
| M5 | `sleep!` does not wait | `hw2` |
| M6 | `http_all!` sends no headers | `hw2` (the route `require` lines: 599) |
| M7 | `http_all!` sends no body | `hw2` (the body files) |
| M8 | `http_send!` sends GET for each method | `hw1` |
| M9 | `fakehttp.py`: the n-th answer gives the first answer again | `hw1` |
| M10 | `fakehttp.py`: the body is not logged | `hw1` (`expect/http-bodies/`), `hw2` |
| M11 | `fakehttp.py`: the method is not in the file name | `hw1` |
| M12 | `fakehttp.py`: `require-none` is not checked | `hw1` |
| M13 | `FakeJobs`: the body is not in `calls.log` | L2 `ap23-http-writes` |
| M14 | `FakeJobs`: the n-th answer is not read | L2 |
| M15 | `FakeJobs`: `http_all!` gives the first result last | L2 |
| M16 | `FakeJobs`: `require-none` is not checked | L2 |
| M17 | `run.sh`: `expect/http-bodies/` is not compared | Caught by the row `fl3-http-bodies` of `tests/selftest.sh` (added by TalonRegistry; `scripts/test.sh selftest` fails with `l3 http-bodies must fail with 'http request bodies differ'`). `tests/run.sh` was restored and compared equal. |
| M18 | `http_all!` adds `--fail` | `hw3` |
| M19 | `http_all!` sends a request with `Authorization` | `hw3` |
| M20 | `http_all!` has no `--proto =https,http` | `hw3` |
| M21 | `http_all!` leaves the body temp files | `hw3` |
| M22 | `http_all!` limit 0 is unlimited | `hw3` |
| M23 | `http_all!` adds `--location` | `hw3` |

## Code

| File | Change |
| --- | --- |
| `cli/RealFx.roc` `http_send!` | basic-cli `Http.send!` with the method, the headers, the body (none when empty) and `timeout_s` in ms |
| `cli/RealFx.roc` `http_all!` | `curl` children through `RealJobs.run_jobs!` (limit 0 runs 1). Args: `--include --proto =https,http --max-time <s> --request <M> -H Expect:`, `-H` for each header, `--data-binary @<file>` (file in `tmp_dir`, removed after), no `--fail`, no `--location`. `Authorization` or `Talon-Contributor` (any letter case): `Failed("credential")`. Exit 28: `Timeout`. No `curl`: `Failed` for each. |
| `cli/RealFx.roc` `sleep!` | basic-cli `Sleep.millis!` |

## Verify results

(Code agent and verify step.)

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-200-revert/code-final.sha256` (from the repo root) | 1 of 1 OK (`cli/RealFx.roc`) |
| `todo: slice 200` in `cli/` | None |
| L3 `fx/hw1`, `hw2`, `hw3` | 3 of 3 green. The Q228 rows of `hw3` (header names in other letter cases) were written by hand and pass on the first run. |
| `scripts/test.sh check l2 l3` | Pass |
| `fmt`, `l0` | Fail only on `tests/unit/ClosureindexTest.roc`: the red tests of slice 206, in progress. Not this slice. |
| Expected exits | L2 `registry/ap23-http-writes` exits 0 in each run. The L3 cases check `err Failed` and `err Timeout` lines, each a rule of the slice (R-DA8, R-DA9, Q228, Q229). |
| Self-test row M17 | `fl3-http-bodies` (TalonRegistry) catches it. |
| Design answers | Q224 to Q229 (G-C45 to G-C50) |
| Not covered | A response body that is not UTF-8 through `http_all!` (stdout is read as text). |

