# 115a Compat bot rows: POST /v1/compat

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code: Opus medium. Slice 115 is split (TW19): 115a is the bot path of `POST /v1/compat` and the SQL of the bot set. 115b (`115b-compat-reads.md`) is the 3 read routes. The user hint path (`Talon-Contributor`) is slice 116.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-115-revert/reference/` (the private reference).

## 1. Scope

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Compat.roc`: types, constants, signatures. Every body is `crash "todo"` | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/CompatRoutes.roc`: `post!` is `crash "todo"`, the flow is in the doc comment | Test agent (signature), code agent (body) | Stub, wired in `worker/main.roc` |
| `worker/sql/compat/prefix.sql`, `missing.sql` (section 4) | Code agent | Missing: W1 `m1` fails with `the compat SQL is missing` |
| `worker/lib/Route.roc`: `Route.Id` has `PostCompat` (and the 115b ids). The `decide` lines are NOT written | Test agent (the tag), code agent (the lines, section 3.4) | Half |
| `worker/lib/main.roc` (exposes `Compat`, `CompatReads`), `worker/main.roc` (imports and 4 arms of `run!`), `worker/tests/unit/w0.roc` (2 imports) | Test agent | Done |
| `sql/tests/compat.mjs` (loader, random state, independent JS reference of the bot set) | Test agent | Done |
| Tests: section 5 | Test agent | Red |

Size (TW19): the private reference of both parts is about 700 lines with the SQL. Over 400, so the split.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP10 | `POST /v1/compat` bot path: rows `{hash, nightly, target, result, error_digest}` and an optional `sweep {nightly, target, upto_log_index}`. 201 when a row is new, else 200. Body `{"written":n}` | W0 `parse_post`, `plan`, `written_*`. W2 `ap10-*` |
| R-AP41 | D1: the read batch, then one write batch. Lists as one JSON parameter. The row statement reads `json_each` | W0 `read_params`, `rows_sql`. W2 d1-calls |
| R-AP44 | An unknown member is ignored, except `source` | W0, W2 `ap10-bad-requests` |
| R-AP46 | 256 KB, 500 rows. 413 with `field` and `limit` before any D1 call | W0, W2 `ap46-500-rows`, `ap10-bad-requests` |
| R-AP48 | The order of the checks: 405, 415, 413, 400 (decode), then the token (401, 403) | W0 `request_kind`, W2 `ap10-bad-requests`, `ap10-auth` |
| R-AP51, R-AP58 | The wire records. `error_digest` is text or `null` (null stays null) | W0 `parse_post`, W2 |
| R-MX4, R-MX5 | A bot row has `source` bot. A request body with `source` is 400. `target` of a sweep is `any` | W0, W2 `ap10-bad-requests` |
| R-MX8, R-MX9 | The sweep and the rows are one batch. A trigger error `sweep-incomplete` is 422 with the missing hashes (at most 100). `sweep-bound` is 400. Other trigger text is 500 | W0 `failure_of`, `sweep_incomplete`, W2 `mx9-*` |
| R-MX10, R-RE20, R-RE21, R-AP56 | A hash with no `artifacts` row is 404. A target the artifact does not build is 400 | W0 `plan`, W2 `ap10-404-and-targets` |
| R-MX11, R-MX16 | The bot set (SQL `prefix.sql`): the same text as the trigger `sweeps_guard_insert` | W1 `m1` |
| R-RE13, Q86, R-CT4 | The first row of a key wins: `ON CONFLICT DO NOTHING`, not `OR IGNORE`, not `OR REPLACE` | W0 `rows_sql`, W2 `ap10-bot-rows-and-sweep` |
| R-RE6, R-RE7, R-RE8, R-RE23, R-RE26 | The sweep upsert only to a larger bound; a `bot` row is the only row that completes a sweep (an `author` row does not) | W0 `sweep_sql`, W2 `ap10-bot-rows-and-sweep`, `mx9-sweep-errors` |
| R-TP3, R-TP7, R-MX15, R-AP26 | The bot token: `Auth.bot!` (slice 108). 401, 403 | W2 `ap10-auth` |
| R-CT1 | No `Authorization` and no `Talon-Contributor`: 400 | W0 `request_kind`, W2 `ap10-auth` |
| R-IK2, R-IK4, R-IK7 | The ids of the request: hash (base58 of 32 bytes), nightly (both tag forms), the result and target codes | W0 `parse_post`, `rows_json` |

## 3. What the code agent writes

### 3.1 Files

| File | What |
| --- | --- |
| `worker/lib/Compat.roc` | The bodies. The doc comment of each stub is the rule. Reuse `ClosureQuery.Reject`, `Reads`, `Id` (records), `Problem` |
| `worker/CompatRoutes.roc` | The body of `post!` (section 3.3) |
| `worker/sql/compat/prefix.sql`, `missing.sql` | Section 4 |
| `worker/lib/Route.roc` | Section 3.4 |
| `worker/lib/Nullable.roc` | None. No copy (RQ1 answered, 9.1): `parse_post` uses `records.Compat.decode_post` of slice 104d |

Hint for `parse_post`: it calls `records.Compat.decode_post` (slice 104d, 9.1). That function declares `source : Try(Nullable(Str), [Missing])` in the body record and in the row record, so any present `source` (a string, `null`, or the escaped name `source`) is `BadJson`, and `parse_post` maps it to a 400. A number or object value is a decode error (also 400). A text search for `"source"` is wrong (W0 pins it). `decode_post` keeps `result` and `nightly` as text: the checks of the values (R-AP66 check 6) come after the row limit (check 5), so they stay in `parse_post`.

### 3.2 The signatures

| Function | Signature |
| --- | --- |
| `Compat.too_large` | `Str, U64 -> Compat.Reject` |
| `Compat.parse_post` | `List(U8) -> Try(Compat.Post, Compat.Reject)` |
| `Compat.read_params` | `Compat.Post -> { artifacts_json : Str, targets_json : Str }` |
| `Compat.plan` | `Compat.Post, Compat.Facts -> Try(List(Compat.PlanRow), Problem)` |
| `Compat.rows_json`, `rows_sql`, `sweep_sql` | `List(PlanRow) -> Str`, `() -> Str`, `() -> Str` |
| `Compat.written_status`, `written_body` | `U64 -> U16`, `U64 -> Str` |
| `Compat.failure_of` | `Compat.Constraint -> [SweepIncomplete, Bad(Problem), Fault(Str)]` |
| `Compat.sweep_incomplete` | `{ tag : Str, upto_log_index : U64, missing : List(Str) } -> Problem` |
| `Compat.request_kind` | `{ authorization : Try(Str, [NotFound]), contributor : Try(Str, [NotFound]) } -> [Bot, Hint, Refuse(Problem)]` |

### 3.3 The flow of `post!`

| # | Step |
| --- | --- |
| 1 | `req.bytes_with!({ max_bytes: Compat.body_limit })`. `Err(TooLarge)`: the 413 of `Compat.too_large("body", Compat.body_limit)`. Another `Err`: the bytes `[]` (then 400) |
| 2 | `Compat.request_kind`. `Refuse(problem)` is the answer (400). `Hint` is slice 116: `Err(Fault(..))` here. `Bot` goes on |
| 3 | `Compat.parse_post(bytes)`. `Bad(problem)`: `Err(Refuse(problem))`. `TooLarge(problem, extra)`: `Ok` of `Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8())`. No D1 call yet |
| 4 | `Auth.bot!(req)`. `Err(problem)` is the answer (401, 403, 500, 502). No D1 call |
| 5 | D1 call 1 (skipped when the body has no row): one `batch!` of 3 statements on the primary: `artifacts`, `targets`, `artifact_targets` for `Compat.read_params`. `Compat.plan`. `Err(problem)` is the answer (404 or 400) |
| 6 | D1 call 2: one `batch!` of the row statement (if rows) and the sweep statement (if a sweep), `Time.now_ms!()` once. `written` is the `changes` of the row statement. On a `Constraint` error: `Compat.failure_of`. `Bad` is the answer, `Fault` is `Err(Fault)`, `SweepIncomplete` goes to step 7 |
| 7 | D1 call 3 only after `SweepIncomplete`: the statement `missing` (section 4) with the sweep. Then `Compat.sweep_incomplete` is the 422 answer (the rows of call 2 are rolled back) |
| 8 | 201 or 200 by `Compat.written_status`, `content-type: application/json`, `cache-control: no-store`, body `Compat.written_body(written)` |

D1 calls that the W2 cases pin: success with rows and sweep 2; only a sweep 1; a 404 or 400 from the facts 1; a static 400, 413 or token failure 0; `sweep-incomplete` 3 (2 when the body has no row); `sweep-bound` 2.

Row statement: `INSERT INTO compat ... SELECT ... FROM json_each(?1) WHERE true ON CONFLICT DO NOTHING`. Sweep statement: `INSERT INTO sweeps ... ON CONFLICT (nightly, target) DO UPDATE SET ... WHERE excluded.upto_log_index > sweeps.upto_log_index`. W0 pins the key words (no `OR IGNORE`, no `OR REPLACE`).

### 3.4 Edits of files that other slices own (the code agent makes them)

| File | Edit |
| --- | --- |
| `worker/lib/Route.roc` | In `decide`, add `POST /v1/compat` -> `Handle(PostCompat)`, and the 115b lines (see 115b section 3.3). 405 with `Allow: POST` for another method on `/v1/compat`; a request with no `Content-Type`, as `decide_closure` does for 415 and R-AP48 |
| `worker/main.roc`, `worker/lib/main.roc`, `w0.roc` | None. The test agent did them |

## 4. The SQL (the contract between the code and W1)

Statement `missing` = the text of `prefix.sql`, a newline, the text of `missing.sql`. `prefix.sql` is a `WITH` list and has no final `SELECT`. Slice 115b adds `members.sql` to the same prefix.

| Parameter | Value |
| --- | --- |
| ?1 | The nightly id |
| ?2 | The target code (`any` is 0) |
| ?3 | The bound (a log index), or NULL = the log size now |

| File | Columns | Rows | Order |
| --- | --- | --- | --- |
| `prefix.sql` | none (CTE `members`: `artifact`) | The bot set of R-MX11 at the bound ?3 for the nightly ?1: live = `log_index` at most the bound, not yanked, not withdrawn; a package or a platform; the newest of its form and series (the series is `M`, or `0.m` for M = 0); in the window of 548 days (47,347,200,000 ms) before `MIN(published_at)` of the nightly (the edge is in), or the newest live release of its form. A nightly with no `toolchains` row has no window | |
| `missing.sql` | `hash` (BLOB `names.value`) | Each member with no `compat` row of source `bot` (0) on (?1, ?2) | `hash` bytes |

The condition is the same as in `sql/0002_triggers.sql` `sweeps_guard_insert`. W1 `m1` checks: `missing` is empty if and only if the sweep insert passes, and `missing` equals an independent JS reference.

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/CompatTest.roc`, 14 `expect`s: `parse_post` good body, `source` (6 forms), decode errors, value errors (hash, nightly, result, target, sweep), limits (262,144 / 262,145 bytes, 500 / 501 rows, limits before value checks); the order of the value faults in a row and across rows; `read_params`; `plan` (404 before 400 in a row, the first row that fails, `any` codes per kind, platform targets); `failure_of`; `sweep_incomplete` (0, 1, 100, 101, 250 hashes); `written_*`; `request_kind`; `rows_sql`, `sweep_sql`; `Route.decide` for `/v1/compat` | R-AP10, R-AP66, R-AP44, R-AP46, R-AP48, R-AP51, R-AP58, R-MX4, R-MX5, R-MX8, R-MX9, R-MX10, R-RE13, R-CT1, R-IK2, R-IK4, R-IK7 |
| W1 | `compat/m1-bot-set-missing`: random states (120 on SQLite, 8 on local D1; `COMPAT_CASES` changes it), each nightly and bound, a window-edge release. `missing` against the trigger and the JS reference | R-MX8, R-MX11, R-MX16, R-RE8, R-RE13, R-IK2 |
| W2 | `compat/ap10-bot-rows-and-sweep`: rows, the 4 results, `null` and text digests, a repeated key (first wins), a sweep, a smaller bound | R-AP10, R-RE13, R-RE6, R-MX8 |
| W2 | `compat/mx9-sweep-errors`: 422 with rollback of the rows, `sweep-bound` 400, an `author` row does not complete | R-MX9, R-RE8 |
| W2 | `compat/mx9-missing-100`: 101 missing members, the list has 100 and `and 1 more` | R-MX9 |
| W2 | `compat/ap46-500-rows`: 500 rows, 2 D1 calls | R-AP46, R-IK2 |
| W2 | `compat/ap10-bad-requests`: 19 requests, 17 with a garbage token: all 4xx before the token check, 0 D1 calls; a 262,145 byte `text/plain` body is 415; no `Authorization` and no `Talon-Contributor` with 501 rows is 400 | R-AP48, R-AP46, R-AP51, R-MX5 |
| W2 | `compat/ap10-auth`: no header, a bad signature, a publish token, a good token | R-CT1, R-TP3, R-TP7, R-MX15 |
| W2 | `compat/ap10-404-and-targets`: 11 requests: unknown hash, a target the artifact does not build, 404 before 400 in a row, the first row that fails, and a malformed hash in row 2 after an unknown hash in row 1 (400, 0 D1 calls) | R-AP10, R-MX10, R-RE20, R-RE21 |

The W2 ids come from `research/slice-115-revert/gen/` (node `crypto`, no Roc code). The clock must stay near 1767225600000 (the token `exp`).

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `CompatTest`) | 14 expects, 0 pass (re-run 2026-11-02 after 9.2) (`todo`, or a wrong `Route.decide` value). 0 compiler errors. `roc fmt --check` passes. |
| W1 `node sql/tests/run.mjs` | 47 old pass; the compat cases fail on both backends with `the compat SQL is missing: .../worker/sql/compat/prefix.sql` |
| W2 `compat` (stub build) | 0 of 7 pass (re-run after 9.2: all 10 compat cases fail): 404 `no route for POST /v1/compat` (the `decide` line is missing) and d1-calls |
| Old W2 (`router`, `closure`, `reads`) with the stubs | 26 of 26 pass |

### 5.2 Private reference and revert check

`research/slice-115-revert/reference/` and `ref.sh [w0|w1|w2|all]`. With the reference (after 9.1): W0 44 of 44 (with `CompatReadsTest`, `RouteTest`, `ProblemTest`), W1 6 of 6, W2 10 of 10.

| Mutation | What | Caught by |
| --- | --- | --- |
| `or-ignore` | `INSERT OR IGNORE` for the rows | W0 |
| `sweep-no-where` | The sweep upsert has no `WHERE` (a smaller bound is written; the trigger stops it) | W2 `ap10-bot-rows-and-sweep` |
| `source-naive` | `source` found by a text search | W0 |
| `failure-substring` | `sweep-incomplete` found by a substring of any error | W0 |
| `missing-cap-101` | 101 hashes in the 422 detail | W0 |
| `plan-order` | 400 of a target before 404 of a hash | W0 |
| `limits-after-values` | Row limit after the value checks | W0 |
| `kind-contributor-first` | `Talon-Contributor` wins over the token | W0 |
| `split-batch` | Rows and sweep in 2 batches (no rollback) | W2 `mx9-sweep-errors`, `mx9-missing-100` |
| `window-gt` | The window edge is out | W1 `m1`, `m2` |
| `author-counts` | An `author` row completes the sweep | W1 `m1` |
| `series-major-only` | The series ignores `m` when M = 0 | W1 `m1`, `m2` |
| `bound-null` | NULL bound is 0 | W1 `m1`, `m2` |
| `no-distinct` | A member twice | W1 `m1`, `m2` |

| `plan-order` (re-run) | Also the new rows: a 404 of row 1 before a target 400 of row 2, one row with a 404 and a bad target | W0 `plan` |
| `hash-check-late` | The hash of a row is not checked as base58 in `parse_post` (the row would be a 404 from the facts; R-AP66 check 6 before 8) | W0, W2 `ap10-404-and-targets` request 9, `ap10-bad-requests` |
| `empty-list-normal` | The 422 with an empty list has the normal text | W0 `sweep_incomplete` |
| `list-excludes-request` | The 422 list without the members whose rows were in the failed request (Q115-7) | W2 `mx9-sweep-errors` (see 9.2) |

All caught (the last 4 are new). The mutations are in `research/slice-115-revert/mutations/`.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 200 / 201 | `content-type: application/json`, `cache-control: no-store`, body `{"written":n}` |
| 422 `sweep-incomplete` `detail` | `the sweep of <tag> up to the log index <n> is incomplete: <k> members of the bot set have no bot row: h1, h2`. Over 100: the first 100, then `, and <k-100> more` |
| 400 `sweep-bound` `detail` | `the sweep upto_log_index is larger than the log size` |
| 413 `detail` | `the <field> of the compat request is larger than its limit of <n>` (field `body`, `rows`) |
| 400 no auth | `POST /v1/compat needs an Authorization header (the compat bot) or a Talon-Contributor header (a user hint)` |
| 404 | `no artifact <hash>` |

## 7. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | The manager (`packages/records`, slice 104 area) | `records` has no compat request types and does not expose `Nullable`. Add `records/Compat.roc`, or expose `Nullable`. Until then copy `Nullable.roc` into `worker/lib/`. ANSWERED (9.1): slice 104d adds `records/Compat.roc`; no copy; `Nullable` stays private |
| RQ2 | The manager (`scripts/test.sh`) | `worker_stamp` reads only `*.roc`. The SQL files are embedded in `app.wasm`: add `-o -name '*.sql'` to the `find` (as slice 110 RQ2) |
| RQ3 | The design agent | R-MX8 says `INSERT OR IGNORE` for the matrix rows. R-CT4 and Q86 say `ON CONFLICT DO NOTHING`. The tests follow the second. Make the text one. DONE (9.1): R-MX8 and PLAN row 115 say `ON CONFLICT DO NOTHING` |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| The user hint path (`Talon-Contributor`) | Slice 116. `request_kind` only selects it |
| R-AP45 `MIN_TLN_WRITE` | No setting slice yet |
| A nightly with no `toolchains` row in a row or sweep | Accepted with no check; not tested |
| The 3 GET routes | Slice 115b |

## 9. Questions (all settled: see 9.1)

| Id | Question | Proposal |
| --- | --- | --- |
| Q115-1 | A member `source` inside a row | 400, as at the top level |
| Q115-2 | `error_digest` in a bot row | Required; `null` allowed |
| Q115-3 | A malformed hash in a row | 400. A valid hash that is not indexed is 404 |
| Q115-4 | Which row fails first | The first failing row wins; 404 before 400 inside a row |
| Q115-5 | The limits and the value checks | The limits (413) come first |
| Q115-6 | Body checks and the token | 413, 415, 400 come before 401, 403 (R-AP48 literal) |
| Q115-7 | The 422 `missing` list | By database state after the rollback: it includes members whose rows were in the failed request. Other option: exclude them |
| Q115-8 | A request with `Talon-Contributor` | Slice 116 |

### 9.1 Decisions (design agent, 2026-11-02)

| Id | Answer | Rule, Design Q |
| --- | --- | --- |
| Q115-1 | The proposal: a member `source` in a row is 400, with any value | R-MX5, R-AP66, Q139 |
| Q115-2 | The proposal: `error_digest` is required, text or `null`; a missing member is 400 | R-AP66, R-AP58, Q140 |
| Q115-3 | The proposal: a hash that is not base58 of 32 bytes is 400 before any D1 call; a valid hash that is not indexed is 404. A body value is not a path (R-AP56 gives 404 for a path) | R-AP66, Q141 |
| Q115-4 | The proposal, with one addition: the static checks of all rows (check 6) come before the facts of D1 (check 8). A malformed hash in row 2 is a 400 even if row 1 is a 404. Inside a row: 404, then the target 400 | R-AP66, Q142 |
| Q115-5 | The proposal: decode 400, then 413 rows, then the values 400. As the closure body | R-AP66, R-AP62, Q143 |
| Q115-6 | The proposal: 413, 415, 400 before 401, 403. One detail: the media type is a header, so a body that is too large and not JSON gets 415 (as `POST /v1/closure`, and as the code of `Route.decide`) | R-AP48, R-AP66, Q144 |
| Q115-7 | The proposal: the state after the rollback, third call on the primary, the SQL text of R-AP39 `missing`. Added: the list can be empty (another request wrote in between); the answer stays 422 | R-MX9, R-AP66, Q145 |
| Q115-8 | The proposal: slice 116. `Authorization` wins over `Talon-Contributor`. Until slice 116 a hint request is 500 `internal`, so the route is not deployed before it | R-AP66, R-CT1, Q146 |
| RQ1 | Records: slice 104d adds `packages/records/Compat.roc` (the request types and codecs). `Nullable` stays private. No copy in `worker/lib/`. See the section "104d" of `docs/slices/104-records.md` | R-PK7, Q154 |
| RQ3 | `INSERT ... ON CONFLICT DO NOTHING` with `WHERE true`. R-MX8 and PLAN row 115 are changed | R-MX8, Q86, Q153 |

Order of work: slice 104d (tests, then code) before the code of 115a. The tests of 115a need no wait: the red tests of 115a stay red until both are done. 115b has no dependency on 104d (it uses `Closure.Run` and `Closure.Hint`).

Test changes for the test agent (the proposal is the test behavior, so only these rows change):

| # | Test | Change |
| --- | --- | --- |
| T1 | All W0, W1, W2 | Remove the "pending" mark of Q115-1 to Q115-8. Name the new rule ids R-AP66 (and Q139 to Q146) in the tests that check them. |
| T2 | W0 `CompatTest` `plan` and `parse_post` | Add the order rows of Q115-4: (a) `plan`: row 1 has a target 400, row 2 an unknown hash: the answer is the 400 of row 1; (b) row 1 has an unknown hash, row 2 a target 400: the 404; (c) one row with an unknown hash and a bad target: the 404. (d) `parse_post`: 2 faults in one row: a bad `hash` and a bad `nightly` names the hash; a bad `nightly` and a bad `result` names the nightly. Check that the mutation `plan-order` still fails on (a) to (c). |
| T3 | W2 `ap10-404-and-targets` | Add one request: row 1 has an unknown (valid) hash, row 2 has a malformed hash: 400, D1 calls 0 (static checks come before the facts). |
| T4 | W2 `ap10-bad-requests` | Add one request: a body of 262,145 bytes with `Content-Type: text/plain` and a garbage token: 415, D1 calls 0. Add one: no `Authorization` and no `Talon-Contributor` with a 501-row body: 400 (check 3 before check 5). |
| T5 | W0 `sweep_incomplete` | Add the row with `missing = []`. Proposed `detail` (TW24): `the sweep of <tag> up to the log index <n> was incomplete, but no member has no bot row now: send the request again`. The status stays 422. The code agent calls `sweep_incomplete` with the list from call 3, also when it is empty. |
| T6 | Doc comments of `worker/lib/Compat.roc` | `parse_post` says that it uses `records.Compat.decode_post`; the cap text of `sweep_incomplete` adds the empty list; `failure_of` and the flow 3.3 step 7 say "D1 call 3 on the primary". No signature change. |
| T7 | W2 `mx9-sweep-errors` | Check that the 422 `detail` lists the members whose rows were in the failed request (the state after the rollback, Q115-7). If a case lists only other members, change it. |

Everything else in section 5 stays. The mutations of 5.2 stay valid; add `list-excludes-request` (the 422 list without the request rows): caught by T7.

### 9.2 Test changes done (test agent, 2026-11-02)

| # | Done |
| --- | --- |
| T1 | The "pending" marks are gone from W0 (`CompatTest`) and the rule ids R-AP66 (check number and Design Q) are in the comments, in the W2 `rules` files and in the doc comments of the stubs |
| T2 | W0 `plan`: row 1 with a 404 and row 2 with a target 400 gives the 404; a row with a 404 and a bad target gives the 404; (a) was there. New `expect` for `parse_post`: the `detail` names `hash` before `nightly` before `result` in a row, and the first bad row in the body. `plan-order` fails on these |
| T3 | W2 `ap10-404-and-targets`: request 9 (row 1 unknown valid hash, row 2 malformed hash: 400, 0 D1 calls), 10 (row 1 a 404, row 2 a target 400: 404, 1 call), 11 (row 1 a target 400, row 2 a 404: 400, 1 call) |
| T4 | W2 `ap10-bad-requests`: request 18 (262,145 bytes, `text/plain`, garbage token: 415, 0 calls), 19 (no token, no contributor header, 501 rows: 400, 0 calls). The 415 comes from `Route.decide` before the handler; the code agent must not move the body size check before it |
| T5 | W0 `sweep_incomplete(0 hashes)`: 422 with the `detail` of the empty list |
| T6 | The doc comments of `Compat.roc` and `CompatRoutes.roc` say `records.Compat.decode_post` (slice 104d), the primary D1 call 3, the empty list |
| T7 | W2 `mx9-sweep-errors` requests 1 and 4: the 422 list holds PC, whose row was in the failed request. No case changed. New mutation `list-excludes-request` fails on it |
| 104d | The stubs and the tests import no `Nullable` and no local request type: `Compat.Post` and `Compat.Row` are the parsed types of the Worker (ids and codes as numbers), a different layer from `records.Compat.Post` (text). So no test changes. The private reference still has a copy of `Nullable.roc` (it needs the wire type before 104d is done); it is not given to the code agent. The code agent of 115a calls `records.Compat.decode_post` once 104d is done |

## 10. Disputes

None.

## 11. Verify

`MISSING=1 scripts/rules.sh R-AP R-MX R-RE R-CT` for the rules with no test. `roc fmt --check` of the new files. W0, W1 (`node sql/tests/run.mjs compat`), W2 (`node worker/tests/run.mjs compat`).

## 12. Code (code agent, 2026-11-02)

| File | Code lines (no comments) | What |
| --- | --- | --- |
| `worker/lib/Compat.roc` | 151 (252 with comments) | All bodies. `parse_post` calls `records.Compat.decode_post` (imported as `Wire`), then the row limit, then the values of the rows and the sweep. `plan` is a `map_try` of `plan_row` (404, then the target). `failure_of` matches the pair (kind, message) |
| `worker/CompatRoutes.roc` | 102 (129) | `post!`: the flow of 3.3. `plan!` is D1 call 1, `write!` is D1 call 2, `failed!` is D1 call 3 (plain `db.all!`, so on the primary) |
| `worker/sql/compat/prefix.sql`, `missing.sql` | 13 + 3 lines | Section 4. The text of the trigger `sweeps_guard_insert`, with `live` and `bound` CTEs |
| `worker/lib/Route.roc` | 4 lines in `decide`, a function `decide_post` | `POST /v1/compat` (405 `Allow: POST`, 415 as `decide_closure`) and the 3 lines of 115b. `decide_closure` is not changed |

Decisions that the slice does not fix:

| Item | Choice | Rejected |
| --- | --- | --- |
| `Auth.bot!` result | `_ = Auth.bot!(req).map_err(Refuse)?`: a `Problem` of 401, 403, 500, 502 is a `Refuse`, and `main.roc` makes the answer from it | A separate `problem_response` in the route |
| Order of the body read error and the kind check | The body is read first; the `TooLarge` of the read is reported after `request_kind` (400 for no token comes first) | 413 before the kind check |
| Detail of the value faults | `the hash <h> of a row is not ...`, `the nightly <t> of a row ...`, `the result <r> of a row ...` (no row number) | A row index (the test pins only the member name) |
| Facts statements | Inline text in `CompatRoutes.roc`, with `json_each(?1)` | Files in `sql/compat/` (the slice lists only `prefix.sql` and `missing.sql`) |

### 12.1 Green results (2026-11-02)

| Layer | Result |
| --- | --- |
| W0 `CompatTest` | all 14 `expect`s pass (the full W0 run has 21 failures: `IngestTest` and `ReadsTest:137`, slice 112, not this slice) |
| W1 `node sql/tests/run.mjs` | 6 of 6 pass (`m1`, `m2`, `a1` on sqlite and local D1) |
| W2 `scripts/test.sh w2` | 10 of 10 `compat/*` pass (`mx9-missing-100` takes 19 s). The 6 other failures are `ingest/*` (5) and `reads/ap48-method-not-allowed` (slice 112) |
| `scripts/test.sh check fmt w1` | pass |
