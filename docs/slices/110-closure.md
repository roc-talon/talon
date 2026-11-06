# 110 Closure query

Phase: P2. Status: review (scope and test agent, 2026-11-02; tests changed for the answers of 9.1, T1 to T6 done). The code agent is done (2026-11-02): W0, W1 and W2 of the slice pass, section 11. Model for the code: Opus medium. Plan row: `docs/registry/PLAN.md` C.1, row 110. Depends on slices 101, 102, 104 (`records`), 105 (`Version`), 106 (`Reads`, `ReadRoutes`, done), 109 (done).

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-110-revert/reference/` (the private reference).

## 1. Scope

`POST /v1/closure` (R-AP3): the body and its limits, one D1 batch of 12 statements, the answer of R-AP17.

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/ClosureQuery.roc`: types, constants, signatures; `parse`, `too_large`, `keep_release`, `unknown_of`, `answer` are `crash "todo"` | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/ClosureRoute.roc`: `post!` is `crash "todo"`, the flow is in the doc comment | Test agent (signature), code agent (body) | Stub. No module imports it yet (section 3.4). |
| `worker/sql/closure/*.sql`: 13 files (section 4) | Code agent | Missing: the W1 cases fail with `the closure SQL is missing` |
| `worker/lib/main.roc` (`ClosureQuery` in the exposes), `worker/tests/unit/w0.roc` (`import ClosureQueryTest`) | Test agent | Done |
| `sql/tests/run.mjs`: a case can have `test.mjs` (a module that gets the backend), and the backends have `all` and `batchAll` | Test agent | Done (the old 41 cases pass) |
| `sql/tests/closure.mjs`: the loader of the SQL files for W1 | Test agent | Done |
| Tests: section 5 | Test agent | Red |

Size (TW19): the private reference has about 200 lines in `ClosureQuery.roc`, 85 in `ClosureRoute.roc` and 64 lines of SQL, without blank and comment lines: about 350. No split.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP58 to R-AP64 | The answers of 9.1: `error_digest` null (58), `unknown` (59), window ends (60), empty window (61), the order of the checks (62), the range filter keeps a hash of `hashes` (63), `checked` (64) | W0, W1 `c1` to `c3`, W2 `ap17-answer`, `ap46-limits`, `ap51-bad-requests` (the rule ids are in each test) |
| R-AP3, R-AP16 | The route, the body (`groups`, `hashes`, `compilers`), 200, `no-store` | W0 `parse`. W2 `ap17-answer` |
| R-AP17 | `artifacts`, `releases`, `epochs`, `runs`, `nearest`, `hints`, `log_size`, `unknown`, `checked` | W1 `c1`, `c2`, `c3`. W0 `answer`. W2 `ap17-answer` |
| R-AP18 | One state: the 12 statements are one batch (one transaction) | W1 (`batchAll`), W2 d1-calls 1 |
| R-AP19 | The Worker ignores a snapshot: the client applies it | W0 (`snapshot` member), W2 `ap17-answer` request 2 |
| R-AP20 | No state change | W2 (the same answer 2 times; no write statement) |
| R-AP28 | `unknown`: a hash of `hashes` that the registry does not index | W1 `c2`, W0 `unknown_of`, W2 `ap17-answer` |
| R-AP29, R-AP32 | `checked` and `repos` | W1 `c2`, W0 `answer`, W2 `ap17-answer` |
| R-AP41 rows 1, 2, 4, 6 | A recursive CTE; each list as one JSON parameter; the range filter in Roc; typed rows | W1 `c2` (a 64-bit id in the JSON), W2 `ap41-sixty-groups`, `ap46-limits`, W0 `keep_release` |
| R-AP42 | The answer is runs in a window: the same facts in W as all rows | W1 `c1` (the random reference, 60 cases on SQLite, 8 on local D1; 400 each with `SLOW=1`) |
| R-AP46 | 256 KB, 300 groups, 1000 hashes, 413 with `field` and `limit`, before any D1 call | W0, W2 `ap46-limits` (d1-calls 0) |
| R-AP48 rows 4, 6, 7 | 413 before 400; 400 before D1; a row that does not convert is 500 | W0, W2 `ap51-bad-requests`, `router/r-ap21-handler-err-internal` (section 7) |
| R-AP49, R-AP50, R-AP51 | The wire records; a missing required member is 400 | W0 `answer`, `parse`. W2 |
| R-RE13 row 4 | The sources as runs; only `nearest` merges them (bot over author) | W1 `c1`, `c3` |
| R-RE19 | The closure follows `deps.dep` to the end | W1 `c2` (a diamond, 2 cycles, a dep that is not indexed) |
| R-MX12 (read part) | An epoch transition counts only with the adjacent `previous` and `changed` = 0 | W1 `c3`, `c1` |
| R-MX16 | The order of nightlies: the date (`nightly >> 28`), then t (`MIN(published_at)`), then the id; a nightly with no `toolchains` row has no place | W1 `c1`, `c3`, W2 `ap17-answer` |
| R-IK2, R-IK4, R-IK5 | The ids of the request, the nightly id of both tag forms, the version bounds | W0 `parse` |

Resolution 4 (R-EP1 to R-EP6) is the client side: the W1 reference uses it to compare the facts.

## 3. What the code agent writes

### 3.1 Files

| File | What |
| --- | --- |
| `worker/lib/ClosureQuery.roc` | The bodies. The doc comment of each stub is the rule. Reuse `Reads.form_id`, `Reads.artifact_id`, `Reads.release_of_row`, `Reads.artifact_of_rows`, `Reads.checked_of_row`, `Reads.repo_item_of_row`, `Reads.base58_of_bytes`, `Version.series_bounds`, `Version.range_bounds`, `Id.nightly_id`, `Closure.decode_request`, `Closure.encode_answer`. |
| `worker/ClosureRoute.roc` | The body of `post!` (section 3.3) |
| `worker/sql/closure/*.sql` | The 13 SQL files of section 4. Port `research/closure-runs/schema.mjs` to the real schema. |
| `worker/main.roc` | Section 3.4 |

### 3.2 The 413 answer

R-AP21 and R-AP46: a 413 has the members `field` and `limit`. `Problem.to_json_with(problem, { field, limit })` (added by the `Shorts` slice) writes them. So `ClosureQuery.parse` gives `Err(ClosureQuery.Reject)`: `Bad(problem)` for a 400, `TooLarge(problem, { field, limit })` for a 413. `ClosureQuery.too_large(field, limit)` gives the `TooLarge` value. `Problem.roc` does not change.

### 3.3 The flow of `post!`

| # | Step |
| --- | --- |
| 1 | `req.bytes_with!({ max_bytes: ClosureQuery.body_limit })`. `Err(TooLarge)`: the 413 answer of `ClosureQuery.too_large("body", ClosureQuery.body_limit)` (step 2). Another `Err`: the bytes `[]` (then step 2 gives 400). |
| 2 | `ClosureQuery.parse(bytes)`. `Err(Bad(problem))`: `Err(Refuse(problem))`. `Err(TooLarge(problem, extra))`: `Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8()))`, because `ReadRoutes.Error` has no form for the extra members. No D1 call before this step. |
| 3 | `D1.binding("DB").with_session!(Reads.session_of(req.header("talon-bookmark")))`, then one `batch!` with the 12 statements in the order of section 4. Each statement is `"${prefix}\n${body}"` with the parameters `(query.groups_json, query.hashes_json, Sql.or_null(query.from), Sql.or_null(query.to))`. Embed the files with `import "sql/closure/<name>.sql" as <name>_sql : Str` (the reference does this; it builds). |
| 4 | Each `D1.Result` with `.all()` into the row types of `ClosureQuery.Rows` (`log_size` is the one row `{ log_size : U64 }`). A read error: `Fault`. |
| 5 | `ClosureQuery.answer(query, rows, Time.now_ms!())`. `Err(BadRow(text))`: `Err(Fault(text))` (500 `internal`, the case `r-ap21-handler-err-internal`). |
| 6 | `Response.from_bytes(200, "application/json", body.to_utf8()).with_header("cache-control", ClosureQuery.cache_control)`. No ETag, no Cache API. |

### 3.4 Edits of files that other slices own (the code agent makes them)

| File | Edit |
| --- | --- |
| `worker/main.roc` | `import ClosureRoute` after `import ReadRoutes`. In `run!`: `PostClosure => read_answer(ClosureRoute.post!(req))` in place of `PostClosure => Err(NotBuilt)`. The tag `NotBuilt` can then go from the type of `run!`. |
| `worker/lib/Route.roc` | None. `decide_closure` stays. |
| `worker/lib/Reads.roc`, `worker/ReadRoutes.roc`, `worker/lib/Toolchains.roc` | None. `Reads` is used as it is. |

## 4. The SQL (the contract between the code and W1)

Files: `worker/sql/closure/prefix.sql` and one file for each statement. Statement `<name>` = the text of `prefix.sql`, a newline, the text of `<name>.sql`. `prefix.sql` is a `WITH RECURSIVE` list of CTEs and has no final `SELECT`. All 12 statements take the same 4 parameters. `sql/tests/closure.mjs` loads the files the same way (`CLOSURE_SQL_DIR` changes the dir).

| Parameter | Value |
| --- | --- |
| ?1 | `groups_json`: `[{"form":<form id>,"lo":<stored>,"hi":<stored>}, ...]`. A candidate is a release with `form` = the id and `version BETWEEN lo AND hi` (`g.value ->> '$.form'`). |
| ?2 | `hashes_json`: `[<artifact id>, ...]`, the 64-bit ids as JSON integers (R-IK2: SQLite reads them exactly) |
| ?3, ?4 | The nightly id of `compilers.from` and `compilers.to`, or NULL |

The closure is the artifacts of the candidates, the artifacts of ?2, and each `deps.dep` of them, to the end (a recursive CTE with `UNION`, so a cycle ends). Only ids with an `artifacts` row are in the answer. The compilers are the distinct nightlies of `toolchains`, ordered by `nightly >> 28`, then `MIN(published_at)`, then `nightly` (R-MX16, PLAN G11). The tag of a nightly is `MIN(tag)` of its rows. W is the compilers from the place of ?3 to the place of ?4; an end that is NULL (also a tag with no nightly id: `parse` gives NULL) or that has no `toolchains` row is the end of the domain on its side (R-AP60). An end after the other end gives an empty W and E (R-AP61). `epochs`, `runs`, `nearest` and `hints` are the 4 statements of `research/closure-runs/schema.mjs` on the closure, on the codes of R-IK7 (source bot 0, author 1; result pass 0, fail 1, hang 2, crash 3), with `targets.name` for the target.

Each statement gives these columns, in this order (the names are the names of the row fields). A hash is the BLOB `names.value` (`List(U8)` in Roc; W1 compares it as hex). The order of the rows is part of the contract (R-AP24: one state gives one answer).

| # | Statement | Columns | Rows | Order |
| --- | --- | --- | --- | --- |
| 1 | `artifacts` | `hash`, `kind`, `exposed_json` (= `exposes`), `platform_hash` (BLOB or NULL), `roc_pin`, `size` | Each artifact of the closure | `hash` (bytes) |
| 2 | `deps` | `owner` (the hash of the artifact), `alias`, `hash` (of `dep`), `form` (`names.value` or NULL), `version` (`CAST(version AS TEXT)` or NULL), `version_text`, `url` | Each `deps` row of an artifact of the closure (also a dep with no `artifacts` row) | `owner`, `alias` |
| 3 | `targets` | `owner`, `name` (`targets.name`) | Each `artifact_targets` row of the closure | `owner`, `name` |
| 4 | `releases` | The columns of `Reads.ReleaseRow`: `log_index`, `hash`, `form`, `version`, `version_text`, `url`, `tag`, `roc_version`, `repo` (`names.value` or NULL), `published_at`, `yanked`, `withdrawn` | Each release of each artifact of the closure (also yanked and withdrawn) | `log_index` |
| 5 | `unknown` | `idx`: the smallest 0-based index in ?2 of an id with no `artifacts` row | One for each such id | `idx` |
| 6 | `epochs` | `target`, `from`, `to` (tags) | The epochs with 2 or more compilers in E | `target`, the place of `from` |
| 7 | `runs` | `hash`, `target`, `source`, `result`, `error_digest` (NULL stays NULL; 2 rows with NULL are one run, R-AP58), `from`, `to` | The runs in E (a compiler with no row ends a run) | `hash`, `target`, `source`, the place of `from` |
| 8 | `nearest` | `hash`, `target`, `source`, `result`, `error_digest`, `nightly` (tag), `side` (`before` or `after`) | For each (hash, target) and side: the nearest row outside E after the bot-over-author merge, with result pass or fail | `hash`, `target`, `before` first |
| 9 | `hints` | `hash`, `nightly`, `target`, `pass_count`, `fail_count`, `crash_count` (sums over `talon_version`) | The `compat_hints` rows of the closure on the compilers of W | `hash`, the place of `nightly`, `target` |
| 10 | `checked` | The columns of `Reads.CheckRow`: `name`, `checked_at` (NULL when no `repo_checks` row), `app_installed` (0 when no row) | Each distinct `releases.repo` (not NULL) of the releases whose `form` is in ?1 (no version bound) | `name` |
| 11 | `repos` | The columns of `Reads.RepoRow`: `name`, `state`, `successor` (name or NULL), `state_at` | Each distinct `repo` of the rows of statement 4 that has a `repos` row | `name` |
| 12 | `log_size` | `log_size`: `COALESCE(MAX(idx), 0)` of `log` | One row | |

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/ClosureQueryTest.roc`, 9 `expect`s: the body limit (262,144 bytes pass, 262,145 give 413 `body`); 300 groups and 1000 hashes pass, 301 and 1001 give 413 with `field` and `limit`, groups first, and 413 before a bad series; 17 bodies that give 400 (also `from` a number, `to` an object, `compilers` a list); the 4 parameters of a request with a series, a range, both, none, a repeated hash, a text that is no hash, both tag forms; `compilers` absent, null, empty, one end, tags with no nightly id (a missing end, R-AP60), unknown members, `snapshot`; `keep_release(query, release)` (6 kept, 7 dropped: range ends, series, a saturated series; the 7 kept when their hash is in `hashes`, R-AP63); `unknown_of` (4 rows); `answer` of all 12 row kinds (`error_digest` `null` for NULL, R-AP58; `runs` and `nearest` as text); the empty answer and 5 rows that give `BadRow`. The ids are made by `research/slice-110-revert/gen/ids.py` (python). | R-AP16, R-AP17, R-AP19, R-AP28, R-AP29, R-AP32, R-AP41, R-AP44, R-AP46, R-AP48, R-AP49, R-AP51, R-IK2, R-IK4, R-IK5 |
| W1 | `sql/tests/cases/closure/c1-random-reference`: the random reference of `research/closure-runs/test.mjs` on the real schema: integer ids above 2^53, (nightly, target) toolchain rows with t out of id order and out of date order, a nightly with compat rows and no toolchains row, window ends that are no nightly. The facts of the client in W from the answer must equal the facts from all rows, and the 4 lists must be in the order of section 4. 60 cases on SQLite, 8 on local D1; `SLOW=1` gives 400 each; `CLOSURE_CASES=n`. | R-AP17, R-AP42, R-AP18, R-MX16, R-RE13, R-AP41 |
| W1 | `c2-closure-cte`: a diamond, 2 cycles, a dep that is not indexed, a platform with 2 targets, an app with its platform, a series bound, the id 2^53 + 1 in ?2, `unknown` (the first index of a repeated id), `checked` (one with no `repo_checks` row), `repos` (a moved repo), `log_size`; no groups and no hashes; an id of another kind | R-AP17, R-RE19, R-AP28, R-AP29, R-AP32, R-AP41, R-IK2, R-IK5, R-AP18 |
| W1 | `c3-order-window`: the R-MX16 order of 5 nightlies, a held nightly made larger to its epoch, a transition row whose `previous` is not adjacent, bot over author and the fault filter in `nearest`, an unknown `from`, `from` after `to`, no window, hints of W only | R-AP17, R-MX16, R-MX12, R-RE13, R-AP16 |
| W2 | `closure/ap17-answer`: 8 requests, each 1 D1 call: the full answer of a held nightly (exact members of every list, `error_digest` null); the same with unknown members, `snapshot` and a query (same answer); no `compilers` (all compilers); no groups and no hashes; a range group with the hash of 1.2.0 in `hashes` (1.2.0 and 1.3.0 of 1.2.0, 1.3.0, 1.4.0, R-AP63); a repeated group and hash; 2 tags with no nightly id (the answer of all compilers, R-AP60); a range with no release in it: `checked` still has the repo (R-AP64) | R-AP3, R-AP16 to R-AP20, R-AP28, R-AP29, R-AP32, R-AP41, R-AP44, R-AP49 to R-AP51, R-MX12, R-MX16, R-RE13, R-RE19, R-IK1, R-IK5 |
| W2 | `closure/ap41-sixty-groups`: 60 groups (each with a series and a range) and 60 hashes: 200, 1 D1 call (more than 100 values if each were bound) | R-AP41 row 2, R-AP46, R-AP17, R-AP28 |
| W2 | `closure/ap46-limits`: 300 groups of the longest form and 1000 hashes (93 KB): 200, 1 call; 301 groups, 1001 hashes, both, a body over 256 KB: 413 with `field` and `limit`, 0 calls | R-AP46, R-AP41, R-AP48, R-AP21 |
| W2 | `closure/ap51-bad-requests`: 13 bodies (not JSON, not an object, a missing member, a wrong type, a bad series, a bad range, `from` a number, `to` an object, an empty body): 400, 0 calls | R-AP51, R-AP48, R-AP62, R-AP23, R-AP16 |

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `ClosureQueryTest` alone) | 9 expects, 0 passed, 9 failed with `todo`. 0 compiler errors. `roc fmt --check` passes. The whole `w0.roc` driver: 214 tests, 0 compiler errors (the other failures are other slices). |
| W1 `node sql/tests/run.mjs` | 41 passed, 6 failed: the 3 `closure/*` cases on both backends, `the closure SQL is missing: worker/sql/closure/prefix.sql` |
| W2 `node worker/tests/run.mjs closure` (stub build) | 4 of 4 fail: `status: expected 200 (413, 400), got 500` from `PostClosure => Err(NotBuilt)`, and d1-calls |

### 5.2 Private reference and revert check

`research/slice-110-revert/reference/` (`sql/closure/` and `overlay/worker/`), `ref.sh [w0|w1|w2|all]` builds a copy of `worker/` with it. With the reference: W0 12 of 12 (with `ProblemTest`), W1 6 of 6 (also 400 cases with `SLOW=1` on both backends: 3,233 inferred facts, 154 cases with one compiler), W2 4 of 4 closure cases and 9 of 9 router cases with the changes of section 7. `MUTATE=<m> ref.sh w1` (SQL) and `ROC_MUT=<m> MUTATE_PY=mutations/roc.py ref.sh` (Roc):

| Mutation | What | Caught by |
| --- | --- | --- |
| `noexpand` | E is W (no epoch expansion) | W1 `c1`, `c3` |
| `nogap` | A run goes over a compiler with no row | W1 `c1`, `c3` |
| `nomerge` | `nearest` without bot over author | W1 `c3` |
| `fault` | `nearest` can be a hang or a crash | W1 `c1`, `c3` |
| `order-id`, `order-t` | Compilers by id only, by t only | W1 `c1`, `c3` |
| `edge-lo` | The window misses its first compiler | W1 `c1`, `c3` |
| `no-previous` | A transition counts with a `previous` that is not adjacent | W1 `c3` |
| `any-changed` | A transition with `changed` > 0 is flat | W1 `c1`, `c3` |
| `union-all-dup` | Releases twice | W1 `c2` |
| `no-range-filter` | No `VersionReq.matches` in Roc | W0 |
| `unknown-no-dedupe` | A repeated unknown hash twice | W0 |
| `limits-after-parse` | The value checks before the limits | W0 (after a new row) |
| `two-calls` | The batch split in 2 calls | W2 `ap17-answer`, `ap41-sixty-groups`, `ap46-limits` |
| `no-held-hash` | The range filter drops a release whose hash is in `hashes` (R-AP63) | W0 |
| `digest-empty` | `""` in place of `null` (R-AP58) | W0 |
| `tag-400` | A tag with no nightly id is 400 (R-AP60) | W0 |

17 of 17 caught (the last 3 after the answers of 9.1). The W0, W1 and W2 runs of the reference were made again after T1 to T6. The reference used a copy of `records` with the nullable `error_digest` (`reference/records_nullable.py`) until slice 104c landed; the script is now a no-op. Keep the reference until the review is applied.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 200 | `content-type: application/json`, `cache-control: no-store`. The body is `Closure.encode_answer` (the member order of the derived encoder). |
| List order | Section 4. `unknown`: in the order of `hashes`, each text once. |
| 413 `detail` | `the <field> of the closure request is larger than its limit of <n>` (field `body`, `groups`, `hashes`) |
| 400 `detail` | `the closure request body is not valid: <the decode error>`; `the series <s> of the group <g> is not a series (M or 0.m)`; `the range <r> of the group <g> is not a version range`. No test pins a 400 `detail`. |

## 7. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | The test agent of slice 101 | With the closure built, 5 router cases change (they expect 500 from the stub). The new files are in `research/slice-110-revert/for-101/router/` and pass with the reference: `r-ap23-charset`, `r-ap23-parameters`, `r-ap48-order`: the 500 lines become 400 `bad-request` (the body `{}` misses `groups`; d1-calls stay 0); `r-ap44-unknown-ignored`: bodies with `"hashes":[]` and unknown members give the same 200 empty answer; `r-ap21-handler-err-internal`: a `seed.sql` with an `artifacts` row whose `exposes` is not JSON, and a body that names its hash: 500 `internal`, d1-calls 1. Apply them in the same change as the code of this slice. |
| RQ2 | The manager (`scripts/test.sh`) | `worker_stamp` reads only `*.roc`. The SQL files are embedded in `app.wasm`, so a change of `worker/sql/**/*.sql` must change the stamp: add `-o -name '*.sql'` to the `find`. |
| RQ3 | The test agent of slice 101 (note) | A W2 request with `POST` and no `body` reached the route with a body (415 `no Content-Type`), so `has_body` is true for it under Miniflare. `ap51-bad-requests` uses an empty text body with `application/json` instead. |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| R-AP41 row 5 and R-AP18 with a concurrent publish | No publish route yet (slice 112). The session is `Reads.session_of`, as slice 106 tests. |
| W3: the closure p50 on the edge | Slice 121 |
| R-AP45 `MIN_TLN` | The setting has no slice yet |
| The client side (R-AP19 applied, R-AP28 cases 1 to 3, R-EP) | The client track (PLAN C.4) |
| The second query of a held move (R-AP16) | The same route; the client sends it |

## 9. Questions (all settled: see 9.1)

| Id | Question | Proposal | Tests |
| --- | --- | --- | --- |
| Q110-1 | `error_digest` of a row with NULL. `records` `Closure.Run.error_digest` is `Str`, R-AP51 allows `null` only where a rule says so. | `""` on the wire. Other option: change `records` to a nullable member. | W0 `answer`, W2 `ap17-answer` |
| Q110-2 | A text of `hashes` that is not base58 of 32 bytes | In `unknown`, no 400 (as R-AP56 for R-AP2); not in ?2 | W0, W2 `ap17-answer` (`not a hash`) |
| Q110-3 | A tag of `compilers` with no nightly id (R-IK4) | 400 `bad-request` | W0, W2 `ap51-bad-requests` |
| Q110-4 | A `compilers` end with a nightly id but no `toolchains` row (a nightly that is not recorded yet) | The end of the domain on its side (the prototype). Other option: place it by its date. | W1 `c1` (1 case in 10), `c3` request 2 |
| Q110-5 | `from` after `to` | An empty W: no epochs, runs, nearest, hints | W1 `c3` request 3 |
| Q110-6 | A body that does not decode and has more than 300 groups: 413 (R-AP48 row 4) or 400? The count needs the decode. | 400 (decode first). The limits come before the value checks (series, range, tag). | No test of the conflict |
| Q110-7 | A candidate that the key bounds give and `VersionReq.matches` drops: is its artifact (and its closure) in `artifacts`? | Yes: `artifacts` is the SQL set; only `releases` is filtered. The difference is only for a key that saturates (R-IK5). | None (`ap17-answer` request 5 checks `releases` only) |
| Q110-8 | `checked` of a group: from all releases of the form, or only from the candidates in the bounds? A group with no release? | All releases of the form; no item for a group with no release (as R-AP53) | W1 `c2`, W2 `ap17-answer` |

### 9.1 Decisions (design agent, 2026-11-02)

| Id | Answer | Rule, Design Q |
| --- | --- | --- |
| Q110-1 | Not the proposal. `error_digest` is text or null: `null` for a NULL column, a required member. 2 rows with no digest are one run (`IS`). | R-AP58, Q114 |
| Q110-2 | The proposal: in `unknown` as sent, not in ?2, no 400. `unknown` in the order of `hashes`, each text once. | R-AP59, Q115 |
| Q110-3 | Not the proposal. No 400: a tag with no nightly id is a missing end (the end of the domain on its side), as Q110-4. A held `roc:` pin can be a compiler release. A non-text member is still 400. | R-AP60, Q116 |
| Q110-4 | The proposal: the end of the domain on its side. | R-AP60, Q117 |
| Q110-5 | The proposal: an empty W and E; `epochs`, `runs`, `nearest`, `hints` are `[]`. | R-AP61, Q118 |
| Q110-6 | The proposal: 400 (decode first). Order: body 413, decode 400, groups then hashes 413, series and range 400. | R-AP62, Q119 |
| Q110-7 | The proposal, with one addition: a release whose hash is a text of `hashes` stays, also when the filter drops it (a header value stays in its domain, Resolution R-C9). | R-AP63, Q120 |
| Q110-8 | The proposal: all releases of the form, no version bound; no item for a group with no release. | R-AP64, Q121 |

Test changes for the test agent:

| # | Test | Change |
| --- | --- | --- |
| T1 | W0 `answer`, W2 `ap17-answer` | A run or nearest row with a NULL digest gives `"error_digest":null`, not `""`. Add a W1 or W0 case: 2 adjacent rows with the same result and no digest are one run (R-AP58). |
| T2 | W0 `parse` | A tag of `compilers` with no nightly id gives `from` or `to` NULL (not a 400). Remove these bodies from the 17 bodies that give 400. A `from` or `to` that is a number or an object stays 400. |
| T3 | W2 `ap51-bad-requests` | Remove the 2 bad tags (or move them to `ap17-answer`: 200, the answer of a missing end). 11 bodies stay 400. |
| T4 | W0 `keep_release`, W2 `ap17-answer` | `keep_release` gets the hash set of `hashes` (or the query). A release outside the range whose hash is in `hashes` is kept. Add 1 W0 case and, in request 5 of `ap17-answer`, the hash of 1.2.0 in `hashes`: 1.2.0 then stays. |
| T5 | W0 `ClosureQuery` doc comments | Step 4 of `parse` loses the tag check (R-AP62). The doc of `answer` says `null` for NULL, not `""`. |
| T6 | Rule ids | Name R-AP58 to R-AP64 in the tests that check them. |

Change for `packages/records` (slice 104 area, not edited here): `Closure.Run.error_digest` and `Closure.Nearest.error_digest` become `Try(Str, [None])`; `RunWire` and `NearestWire` get `error_digest : Try(Nullable(Str), [Missing])` (required: `Err(Missing)` is a decode error, R-AP51), as `Repo.successor`. Update `WireTest.roc` (the `nearest` item with `'error_digest':''` becomes `null`). R-AP4 (not built yet) uses the same `Run` type.

Decided after the review note (R-AP65, Design Q122): R-AP28 case 1 when the answer has no release with the label of an unknown header value. The client treats a 409 `label-conflict` to the ingest of case 2 as case 1 for that URL, and sends the closure again only after a 200 or 201 ingest. No change to the Worker of this slice, and no test change in slice 110. Note for the client track (PLAN C.4): implement R-AP65 in the code of R-AP28; tests: a 409 `label-conflict` ingest gives the R-PU19 warning, no exit code 20, and no second closure when no ingest gave 200 or 201; a 422 ingest is case 3. CLI 2, R-AD35 step 3 (a 409 skips the release with a warning) stays as it is: it is the path of `tln add`, not of a header value.

## 10. Disputes (from the code agent)

None. No test, case, fixture or runner file was changed.

## 11. Verify results

Code agent, 2026-11-02. Compiler `nightly-2026-10-31-f7bef6b` (ROC_TAG_WORKER), W2 build `--opt=speed`.

### 11.1 Files

| File | Lines | What |
| --- | --- | --- |
| `worker/lib/ClosureQuery.roc` | 305 | The bodies of `too_large`, `parse`, `keep_release`, `unknown_of`, `answer`, and private helpers (`decode`, `group_item`, `fits`, `run_of`, `nearest_of`, `hint_of`, ...). No `crash`. The public signatures do not change. |
| `worker/ClosureRoute.roc` | 98 | `post!` (the flow of 3.3), `rows_of`, the 13 embedded SQL files |
| `worker/sql/closure/*.sql` | 69 (13 files) | `prefix.sql` (28) and the 12 statements of section 4 |
| `worker/main.roc` | 3 lines changed | `import ClosureRoute`; `PostClosure => read_answer(ClosureRoute.post!(req))`; the tag `NotBuilt` is removed from the type of `run!` and `read_answer` |
| `research/slice-110/batch-time.mjs` | 41 | Probe: the time of the closure batch on local D1 |
| `research/slice-110/revert.sh` | 31 | The revert check of 11.4 |

### 11.2 Test results

| Step | Result |
| --- | --- |
| `node sql/tests/run.mjs closure` | 6 of 6 pass (sqlite and d1: `c1` 60 and 8 cases, `c2`, `c3`) |
| `SLOW=1 node sql/tests/run.mjs closure` | 6 of 6 pass. `c1`: 400 of 400 cases equal on each backend (154 with one compiler, 3,233 inferred facts). d1 `c1`: 64 s. |
| `scripts/test.sh w0 w1 w2 check fmt` | w0: 255 tests, 230 pass, 25 fail, 0 compiler errors. All 25 failures are `ArchiveReadTest.roc` (slice 111, red). The 9 `ClosureQueryTest` expects pass. w1: pass (8.8 s). w2: 78 pass, 6 fail: the 6 `archive/*` cases of slice 111. The 4 `closure/*` cases and the 10 `router/*` cases (with the RQ1 updates) pass. check: pass. fmt: pass. |
| `roc fmt --check` of the 3 Worker files | pass |

### 11.3 Timing (R-AP41, W2 case `closure/ap41-sixty-groups`)

`research/slice-110/batch-time.mjs`: the batch of 12 statements with 60 groups (a series and a range each) and 60 hashes, on the empty schema, local D1 (Miniflare), 30 runs: median 35.6 ms, max 63.0 ms (first run: median 41.8 ms). The base (12 statements `SELECT 1` in one batch) is 14.4 ms. The whole W2 case (Worker start, one request) is about 2.5 s.

### 11.4 Revert check (TW12)

`research/slice-110/revert.sh`: each mutation runs only W1 `closure` or W0. The code is the same as before (diff and md5).

| Mutation | What | Caught by |
| --- | --- | --- |
| `order-t` | The compilers by t, then id (no date) | W1 (4 fails: `c1`, `c3`) |
| `order-id` | The compilers by id only | W1 (4 fails) |
| `nomerge` | `nearest` without bot over author | W1 (4 fails) |
| `no-previous` | A transition counts with a `previous` that is not adjacent | W1 (2 fails: `c3`) |
| `unknown-dup` | `unknown` without `GROUP BY id` (a repeated id gives each index) | Not caught. No effect on the answer: `unknown_of` gives each text once (R-AP59). |
| `checked-bounded` | `checked` from the releases of the closure (version bound) in place of all releases of the form | Not caught by W1, and not by W2 (a full `scripts/test.sh w2` with the mutation: no closure case fails). R-AP64 "no version bound" has no case that tells the two apart: a test gap for the test agent (a group whose only release with a repo is out of the bounds).  Closed by the test agent (2026-11-02): W1 `c2` has the group `o/z` with no release in its series, and W2 `ap17-answer` request 8 a range with no release; `checked` keeps the repo in both. The mutation now gives W1 2 failures (`c2` on sqlite and d1), and the code is back byte for byte (md5). |
| `no-held-hash` | `keep_release` without the hash of `hashes` (R-AP63) | W0 |
| `limits-after-values` | The series and range checks before the limits (R-AP62) | W0 |
| `digest-empty` | `""` for a NULL digest (R-AP58) | W0 |
| `range-ignored` | `lo` of a group with a series and a range ignores the range | W0 |

Caught 8 of 10. The 2 not caught: `unknown-dup` (no effect on the answer) and `checked-bounded` (a test gap, above).

### 11.5 Decisions that the slice does not fix

| Decision | Options not used |
| --- | --- |
| The 3 window parameters are `CAST(?3 AS INTEGER)` in SQL, so a text bind (R-IK2) and a number bind give the same place | A bare `?3` (a text bind would then compare as text with the CTE column) |
| `prefix.sql` adds a CTE `rel` (the releases of the closure), used by `releases` and `repos` | The same `WHERE` in each of the 2 statements |
| The groups are read with `json_extract(g.value, '$.form')` | `->>` (section 4 names it; both work on D1 and node:sqlite) |
| `keep_release` with 2 filters of one group: the release must fit each (the doc comment) | Fit any one |
| A release whose `version` text does not parse as a `Semver` fails a `range` filter | Keep it |
| A body that `bytes_with!` cannot read (not `TooLarge`) is parsed as `[]`, so it is 400 (3.3 step 1) | |
| The 400 `detail` texts are the proposals of section 6; a body that is not UTF-8 is `the closure request body is not valid: it is not UTF-8` | |

### 11.6 Rule coverage

`scripts/rules.sh R-AP R-EP`: 60 of 80 rules have a test. The rules of this slice: R-AP3 2, R-AP16 10, R-AP17 14, R-AP18 6, R-AP19 2, R-AP20 1, R-AP41 39, R-AP42 1, R-AP46 9, R-AP58 7, R-AP59 4, R-AP60 5, R-AP61 2, R-AP62 3, R-AP63 2, R-AP64 2. With no test: R-AP65 (client track, section 9.1), R-EP15, and R-AP4, R-AP8 to R-AP12, R-AP22, R-AP25, R-AP27, R-AP30, R-AP31, R-AP34 to R-AP40 (other slices).
