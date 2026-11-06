# 116a User hints: POST /v1/compat with Talon-Contributor

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code: Sonnet high. Slice 116 is split (TW19): 116a is the hint path of `POST /v1/compat` (this file). 116b (`116b-hint-limits.md`) is the client version (`MIN_TLN`, `MIN_TLN_WRITE`, R-AP45) and the rate limit per address (R-CT11). The bot path is slice 115a (`115a-compat-post.md`): it is done and green, and this slice does not change it.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-116-revert/reference/` (the private reference).

## 1. Scope

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Hints.roc`: types, constants, signatures. Every body is `crash "todo"` (except the constants) | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/HintRoutes.roc`: `post!` is `crash "todo"`, the flow is in the doc comment | Test agent (signature), code agent (body) | Stub, called from `CompatRoutes.post!` |
| `worker/CompatRoutes.roc`: the arm `Hint` calls `HintRoutes.post!(req, bytes)` (was a 500 `Fault`, Design Q146), and `import HintRoutes` | Test agent | Done (two lines). The 115 tests are not changed and stay green |
| `worker/lib/main.roc` (exposes `Hints`, `Client`), `worker/tests/unit/w0.roc` (2 imports) | Test agent | Done |
| `worker/tests/run.mjs`: `ratelimits.json` and a default `RL_HINTS` binding for each case (needed by 116b, harmless here) | Test agent | Done |
| Tests: section 5 | Test agent | Red |

No SQL file and no W1 case: the three statements of R-CT4 are strings of `Hints` (as `rows_sql` of 115a). W0 pins their key words, W2 pins what they do on local D1 (the 22 cases of `research/d1-contrib/` are the source of R-CT4, the schema and triggers are slices 102 and 103).

Size (TW19): the private reference is about 285 code lines for 116a (`Hints` 173, `HintRoutes` about 110) and about 170 for 116b (`Client` 145, the binding and the check in `main.roc` about 25). Together about 455, so the split.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP10 (hint path) | Body `{talon_version, rows:[{hash, nightly, target, result}]}`, header `Talon-Contributor`. Answer `{written, first, skipped}`. 201 when `written` is above 0, else 200 | W0 `parse`, `answer_body`. W2 `ct4-*` |
| R-CT1 | No `Authorization` and a header `Talon-Contributor`: a hint. The id is 32 lower case hex characters, else 400. A token wins (Design Q146) | W0 `machine_id`. W2 `ct2-bad-requests`, `ct4-hint-batch` (request 8) |
| R-CT2 | A row that is not valid makes the whole request 400 and nothing is written. `error_digest` is not allowed. A hang is not a hint. A real target only for an app or a platform | W0 `parse`, `check`. W2 `ct2-bad-requests` |
| R-CT3 | The contributor of a machine is the first 8 bytes of HMAC-SHA256 (`CONTRIBUTOR_KEY`) with the top bit set. A machine that logged in (`links`) counts as its account | W0 `hmac_message`, `contributor_id`. W2 `ct4-hint-batch` |
| R-CT4 | One D1 batch: `first`, `skipped`, then the insert with `ON CONFLICT DO NOTHING RETURNING`. `written` is the count of returned rows | W0 `*_sql`. W2 `ct4-hint-batch` |
| R-CT12 | `talon_version` is kept only for a tag `v<version>` of `roc-talon/talon` (tag list, `Memo`, 1 h). Else key 0 | W0 `talon_key`, `tag_names`. W2 `ct12-*` |
| R-CT13 | `hint-quota` (trigger) is 429 `rate-limited` with `Retry-After` to the next UTC day. The whole request is undone | W0 `failure_of`, `retry_after`. W2 `ct13-hint-quota` |
| R-CT14 | Skipped rows: `unknown-hash`, `unknown-nightly`, `unknown-target`, `bot-row`, `old-nightly`. A valid row of another reason is written | W0 `skipped_sql`. W2 `ct4-hint-batch` |
| R-AP41 | At most 2 D1 calls: the read batch (for the 400), one write batch. Lists as one JSON parameter | W0 `read_params`, `rows_json`. W2 d1-calls |
| R-AP46, R-AP48 | 256 KB, 500 rows (413, `field`, `limit`). The order of the checks | W0 `parse`. W2 `ct2-bad-requests` |
| R-AP51, R-AP44, R-MX5 | A missing member is 400 and named. An unknown member is ignored, except `source` (and, for hints, `error_digest` in a row and `sweep`, Q116-7) | W0 `parse`. W2 `ct2-bad-requests` |
| R-MX6 | A hint is never a `compat` row | W2 `ct4-hint-batch` (the `compat` count) |
| R-RE12, R-RE13 row 3, R-RE16, R-RE24 | `compat_hints` counts by `talon_version`, once for each contributor and pair; `contributions`; `hint_days` | W2 `ct4-hint-batch`, `ct12-*`, `ct13-hint-quota` |
| R-IK2, R-IK4, R-IK5, R-IK7 | Ids as JSON integers (64 bit), the nightly id, the key of the Talon version, the target codes | W0, W2 |

## 3. What the code agent writes

### 3.1 Files

| File | What |
| --- | --- |
| `worker/lib/Hints.roc` | The bodies. The doc comment of each stub is the rule. Reuse `Compat.Reject`, `Compat.Facts`, `Compat.Constraint`, `Compat.too_large`, `Compat.written_status`, `Reads.artifact_id`, `Id.nightly_id`, `Code.result_from_str` |
| `worker/HintRoutes.roc` | The body of `post!` (section 3.3) |
| `worker/lib/Client.roc` | 116b |

Hints for `Hints.parse`: `records.Compat.decode_post` is for the bot body and the code agent does not change `packages/` here. Define the wire records of the hint body in `Hints.roc`. The derived `Json.parse` ignores an unknown member, so `source`, `error_digest` (in a row) and `sweep` need a field that says "present with any value" (a `Try(.., [Missing])` field of a type that reads `null` too; the private `Nullable` of `records` shows the way: copy its idea, not its file). The derived reader names a missing member (`MissingRequiredField("rows")`) and says only "Invalid JSON" for a wrong type: the tests ask for a named member only when the member is missing, or when the value is a text or `null`.

### 3.2 The signatures

See `worker/lib/Hints.roc`. In short:

| Function | Signature |
| --- | --- |
| `Hints.machine_id` | `Str -> Try(Str, Problem)` |
| `Hints.parse` | `List(U8) -> Try(Hints.Post, Compat.Reject)` |
| `Hints.read_params` | `Hints.Post -> { artifacts_json : Str, targets_json : Str }` |
| `Hints.check` | `Hints.Post, Compat.Facts -> Try(List(Hints.Sent), Problem)` |
| `Hints.rows_json` | `List(Hints.Sent) -> Str` |
| `Hints.first_sql`, `skipped_sql`, `insert_sql` | `() -> Str` |
| `Hints.hmac_message`, `Hints.contributor_id` | `Str -> List(U8)`, `List(U8) -> I64` |
| `Hints.talon_key`, `Hints.tag_names` | `{ version, tags } -> I64`, `Str -> Try(List(Str), [BadTags])` |
| `Hints.answer_body` | `{ written, first, skipped } -> Str` |
| `Hints.failure_of`, `retry_after`, `quota_problem` | `Compat.Constraint -> [Quota, Fault(Str)]`, `U64 -> U64`, `() -> Problem` |

### 3.3 The flow of `HintRoutes.post!`

| # | Step |
| --- | --- |
| 1 | `bytes` is the body read of `CompatRoutes.post!`. A body above 256 KB is the 413 (field `body`), before the id check |
| 2 | `Hints.machine_id` of the header. `Err(problem)`: the 400 |
| 3 | `Hints.parse(bytes)`: 400, or the 413 of the rows. No D1 call yet |
| 4 | (116b) the rate limit |
| 5 | A body with no row: the answer `{"written":0,"first":0,"skipped":[]}` (200). No D1 call, no GitHub read (Q116-3) |
| 6 | D1 call 1: the read batch (3 statements on the primary, as `CompatRoutes.plan!`; copy the text, `HintRoutes` cannot import `CompatRoutes`). `Hints.check`: `Err(problem)` is the 400 |
| 7 | The tag list: `Memo` of 1 h, `Hints.tags_url`, `Hints.tag_names`. A failed read keeps nothing and gives `[]` (Q116-9). `Hints.talon_key` |
| 8 | D1 call 2: one `batch!` on the primary of `first_sql`, `skipped_sql`, `insert_sql`, with `Time.now_ms!()` once. The secret `CONTRIBUTOR_KEY` through `WebCrypto.hmac_sha256`, then `contributor_id`. A `Constraint` goes to `Hints.failure_of`: `Quota` is the 429 with `Retry-After`, `Fault` is a 500 |
| 9 | 201 or 200 by `Compat.written_status`, `content-type: application/json`, `cache-control: no-store`, `Hints.answer_body` |

D1 calls that the W2 cases pin: a good request with rows 2; a body with no row 0; a refusal of the static checks 0; a refusal of `check` 1; the 429 of the quota 2.

### 3.4 The SQL (the contract between `Hints` and W2)

The three statements take `rows_json` as ?1 and the time in ms as ?2. `insert_sql` also takes ?3 (the machine id) and ?4 (the key of `talon_version`). The text of the classification (a `WITH` list) is the same in the three statements.

| Statement | Result | Rule |
| --- | --- | --- |
| `first_sql` | One row, column `first` | The count of the distinct pairs (artifact, nightly, target) of the rows that `skipped_sql` does not skip, with no `compat` row of any source and no `compat_hints` row of any version |
| `skipped_sql` | Columns `row` (the index `i`), `reason`; ordered by `row` | The first reason that holds, in this order: `unknown-hash`, `unknown-nightly`, `unknown-target` (the target is null), `bot-row` (a `compat` row of source 0), `old-nightly` (the smallest `published_at` of the nightly is older than ?2 minus 365 days) |
| `insert_sql` | The rows of `RETURNING CAST(artifact AS TEXT)` | `INSERT INTO contributions` of the rows that are not skipped, in the order of `i`, `contributor` = `COALESCE((SELECT contributor FROM links WHERE machine = ?3), ?3)`, `time` ?2, `ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING`. The first row of a pair wins |

A statement binds the ids as numbers (the platform sends a 64 bit id as decimal text, R-IK2). The trigger `contributions_count` (slice 103) counts, and raises `hint-quota`.

## 4. Edits of files that other slices own

| File | Edit |
| --- | --- |
| `worker/CompatRoutes.roc` | Done by the test agent: `import HintRoutes` and the arm `Hint => return HintRoutes.post!(req, bytes)`. A copy of the file before is in `research/slice-116-revert/before/` |
| `worker/lib/main.roc`, `worker/tests/unit/w0.roc` | Done by the test agent |
| `worker/lib/Route.roc` | None: `Route.decide` serves `POST /v1/compat` (slice 115a) |
| `worker/main.roc`, `worker/wrangler.toml` | 116b (the binding `RL_HINTS`, the client check) |

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/HintsTest.roc`, 15 `expect`s: `machine_id` (9 refusals); `parse` good body; decode errors (17 bodies, a named member); `error_digest`, `source`, `sweep` (14 forms); values (hash, nightly, result, the order); limits (500 / 501 rows, 262,144 / 262,145 bytes, limits before values); `read_params`; `check` (9 rows of facts and 4 refusals); `rows_json`; `hmac_message` and `contributor_id` (HMAC outputs from node); `talon_key`; `tag_names`; `answer_body`; `failure_of`, `retry_after`, `quota_problem`; the key words of the three SQL texts | R-AP10, R-AP41, R-AP44, R-AP46, R-AP51, R-CT1 to R-CT4, R-CT12 to R-CT14, R-MX5, R-IK2, R-IK4, R-IK5, R-IK7 |
| W2 | `hints/ct4-hint-batch`: 8 requests. A request of 13 rows (3 written with a package, a platform smoke row and an app row; `first`; the 5 skip reasons and 3 rows with two reasons; a duplicate pair; an author row that is not `first`). The same request again (written 0). A machine that logged in (the account `4242`). The same contributor and pair with another version (200). Another version of the pair (another `compat_hints` row). A text that is no version (key 0). No row (0 D1 calls). A garbage token with the contributor header (401). The db: `contributions`, `compat_hints`, `hint_days`, no new `compat` row. Independent JS oracle `research/slice-116-revert/gen/gen_116.mjs` | R-AP10, R-CT1 to R-CT4, R-CT12, R-CT14, R-MX5, R-MX6, R-RE12, R-RE13, R-RE16, R-RE24, R-IK2, R-IK5 |
| W2 | `hints/ct2-bad-requests`: 30 requests, 29 refusals (a body of 262,145 bytes as `text/plain` is 415 before the 413, R-AP70 row 3; a bad id with a body that is not JSON; id forms, garbage body, 413 of the body and the rows, `error_digest`, `source`, `sweep`, values, `talon_version`, `rows`, a package with a real target, a platform with a target it does not build, a good row before a bad one) and a last good request. No row is written by a refused request. 0 D1 calls, 1 for the facts | R-CT1, R-CT2, R-AP46, R-AP48, R-AP51, R-MX5 |
| W2 | `hints/ct12-talon-version`: 8 requests with versions that are in the tag list (3), not in it (3 on one pair: they sum in one row), empty, and `banana`. One tag list read | R-CT12, R-IK5, R-RE12 |
| W2 | `hints/ct12-tags-fail`: the first read answers 500: the request works with key 0. The next request reads again (nothing kept) and gets the key | R-CT12 (Q116-9) |
| W2 | `hints/ct14-old-nightly-edge` (Design Q174): 4 nightlies: one `published_at` exactly at the edge of 31,536,000,000 ms (kept), one 1 ms older (`old-nightly`), a nightly with two `toolchains` rows whose smaller `published_at` is older (skipped), one whose smaller is the edge (kept) | R-CT14, R-CT15, R-AP70 |
| W2 | `hints/ct13-hint-quota`: the day has 199,999. A request of 2 new rows: 429, `Retry-After` 43200, nothing written. 1 new row: 201. Another: 429, `Retry-After` 1. A conflict row and a skipped row count nothing: 200. The next day: 201 | R-CT13, R-AP25, R-MX9, R-RE24 |

The W2 ids come from `research/slice-116-revert/gen/` (node `crypto`, no Roc code). The clock is 1767225600000 + 1000 * request (2026-01-01, day 20454).

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `HintsTest`, `ClientTest`) | 19 `expect`s (15 + 4), 0 pass, all `todo`. 0 compiler errors. `roc fmt --check` passes |
| W2 `hints` (stub build) | 0 of 7 pass (`ct4`, `ct2`, `ct12-talon-version`, `ct12-tags-fail`, `ct13`, and the two of 116b): status 500 `trap unreachable` (the `todo`) |
| Old W2 with the stubs | All pass except `ingest/pu14-pu19-labels` (slice 112, in work) and the 6 `archive/*` cases (the copy of `worker/` of `ref.sh` has no `archive-test.wasm`; not this slice) |

### 5.2 Private reference and revert check

`research/slice-116-revert/reference/` and `ref.sh [w0|w2|all]`. With the reference (re-run after the answers of section 12): W0 `HintsTest` and `ClientTest` 19 of 19 (53 of 53 with `CompatTest` and `RouteTest`), W2 `hints` 8 of 8.

| Mutation | What | Caught by |
| --- | --- | --- |
| `written-changes` | `written` from `meta.changes` (local D1 counts the trigger rows: 3 for 1 row) | W2 `ct4`, `ct2`, `ct13`, `ct12-*` (5 of 7 cases) |
| `first-after-insert` | `first` runs after the insert | W2 `ct4`, `ct2`, `ct12-*`, `ct13` (5 of 7) |
| `first-ignores-compat` | An author row does not remove `first` | W2 `ct4` (row 8) |
| `reason-order` | `unknown-target` before `unknown-nightly` | W2 `ct4` (row 12) |
| `bot-row-any-source` | An author row skips the hint | W2 `ct4` (row 8) |
| `link-ignored` | The contributor ignores `links` | W0 `insert_sql`, W2 |
| `retry-floor` | `Retry-After` rounded down | W0 `retry_after` |
| `key-no-tags` | The key of every semver text | W0 `talon_key`, W2 `ct12-talon-version` |
| `package-target-unchecked` | A package with a real target is accepted | W0 `check` |
| `or-ignore` | `INSERT OR IGNORE` | W0 SQL words |
| `old-edge-in` (new, Q174) | A nightly at the edge is old | W2 `ct14-old-nightly-edge` |
| `old-max` (new, Q174) | The largest `published_at` of the nightly decides | W2 `ct14-old-nightly-edge` |

The mutations are in `research/slice-116-revert/mutations/roc.py`.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 200 / 201 body | `{"written":<n>,"first":<k>,"skipped":[{"row":<i>,"reason":"<reason>"},...]}`. The members in this order; `skipped` is always there; `row` counts from 0; the reasons are the 5 texts of R-CT14, with `-` |
| 200 / 201 headers | `content-type: application/json`, `cache-control: no-store` |
| 400 id | `the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f` |
| 400 body | `the hint request body is not valid: <why>`; for a value: `the hash <h> of a row is not a base58 hash of 32 bytes`, `the nightly <t> of a row is not a nightly tag`, `the result <r> of a row is not pass, fail or crash`, `the result hang of a row is not a hint`; for the refused members: `member error_digest is not allowed in a row`, `member source is not allowed`, `member sweep is for the compat bot` |
| 400 target | `the target <t> is not valid for a hint: the artifact <hash> is a package`; `the platform <hash> does not build the target <t>` |
| 413 | as 115a: `the <field> of the compat request is larger than its limit of <n>` (field `body`, `rows`) |
| 429 | type `rate-limited`, `detail`: `the daily limit of user hints is used up: send the rows again after the next UTC day starts`, header `Retry-After: <seconds>` |

## 7. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | The manager (`scripts/test.sh`) | `worker_stamp` reads `*.roc` only (as 115a RQ2): the W2 cases of the hint path depend on `.roc` files, so no change |
| RQ2 | Slice 119a | The token of the tag list read (Design Q170): 119a changes the plain request of `HintRoutes` to the token function |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| R-AP45, R-CT11 | Slice 116b |
| R-CT5 (cleanup cron), R-CT15 (trim) | Slice 120 |
| R-CT6 to R-CT10 (login, delete, tracker) | Slice 117 |
| A tag list with more than 100 tags (Q116-9) | A question |
| The age of the tag list `Memo` (1 h) | The `Memo` expiry uses the shim clock, not the case clock (as the JWKS, slice 108): one read in a case is pinned, the hour is not |
| The edge: the real D1 error text of `hint-quota` and `meta.changes` | W3 (slice 103 `t5-d1-error-text` has the text) |

## 9. Questions (all settled: see section 12; the marks `pending` are removed from the tests)

| Id | Question | Proposal | Pinned by |
| --- | --- | --- | --- |
| Q116-1 | R-CT12 reads the tag list with the installation token (G15), which slice 119 builds. Which token does slice 116 use? | No `Authorization` header until slice 119, then the installation token | Nothing (the fake GitHub does not see headers) |
| Q116-2 | R-AP66 gives the order of the checks of the bot path only. What is the order of the hint path? | R-AP48 (client version, 413 body, 415), then the id (400), the decode (400), 413 rows, the values (400), the rate limit (116b), D1 call 1 (the 400 of a target), the tag list, D1 call 2 | W2 `ct2-bad-requests` (413 of the body and a bad id; 400 of a bad id and 501 rows) |
| Q116-3 | A body with `rows: []`? | 200 `{"written":0,"first":0,"skipped":[]}` with no D1 call and no GitHub read | W2 `ct4-hint-batch` request 7, `ap45`, `ct11` |
| Q116-4 | R-CT2 "Another kind or another target gets 400": a platform row with a target that the platform does not build (R-MX10 for the bot says 400)? An app has no `artifact_targets`. | 400 for a platform whose `artifact_targets` has no pair; an app takes any name with a code; a package takes only `any` | W0 `check`, W2 `ct2-bad-requests` |
| Q116-5 | R-CT14 `old-nightly`: "older than the age of R-CT15" (12 months, first guess). How many ms, which edge, and which `published_at` when a nightly has several `toolchains` rows? | 365 days (31,536,000,000 ms), the smallest `published_at` of the nightly, a nightly exactly at the edge is not old, the time is the request time | W2 `ct4-hint-batch` (a nightly of 2024 against 2026-01-01; the edge is not pinned) |
| Q116-6 | R-CT3: the HMAC of "the id of the header": the 32 characters as text, or the 16 bytes? | The 32 characters as UTF-8 bytes | W0 `hmac_message`, `contributor_id`; W2 `ct4-hint-batch` (the ids in `contributions`) |
| Q116-7 | R-CT2 forbids `error_digest`; R-MX5 forbids `source`; R-AP10 says `sweep` is bot only. For a hint request, is each one, with any value (also `null`), a 400? | Yes, 400 for each | W0 `parse`, W2 `ct2-bad-requests` |
| Q116-8 | R-IK5 "The version of `tln` is the key of its version", `unknown` is the key 0. Is `talon_version` stored as the key (no flip) or as the key with the top bit flipped (as `releases.version`)? | The key, as an `I64` with `to_i64_wrap`, no flip: `0.4.1` is 17180000255, `unknown` is 0 | W0 `talon_key`, W2 `ct4-hint-batch`, `ct12-*` |
| Q116-9 | R-CT12: which URL, how many tags, and what does a failed read do? | `GET https://api.github.com/repos/roc-talon/talon/tags?per_page=100`, one page. A failed read (status other than 200, network fault, a body that is no tag array) keeps nothing in the `Memo` and the request is written with the key 0; the next request reads again | W0 `tags_url`, `tag_names`; W2 `ct12-tags-fail` |
| Q116-10 | R-CT13 `Retry-After` "to the next UTC day": rounding? | Whole seconds, rounded up (at 00:00:00.000 it is 86400) | W0 `retry_after`, W2 `ct13-hint-quota` |
| Q116-11 | R-CT4 does not say which row of one pair wins when a request holds a pair twice with two results. | The first row of the body (the insert is ordered by the index) | W2 `ct4-hint-batch` (rows 0 and 9) |
| Q116-12 | R-CT4 writes `skipped` and `first` in the same batch as the insert. A request whose rows are all skipped has `written` 0 and answer 200. A row that is a duplicate of a pair of the same contributor is neither written nor skipped. Is that the intent? | Yes (R-AP10: 200 "each row was there already for this contributor") | W2 `ct4-hint-batch` requests 2 and 4 |

## 10. Disputes

None.

## 11. Verify results

`MISSING=1 scripts/rules.sh R-CT R-AP R-MX R-RE` (2026-11-02): no rule of this slice is missing. R-CT5 to R-CT10 and R-CT15 stay for the slices 117 and 120. `roc fmt --check` of `worker/` passes. `unit_modules_check worker/tests/unit` passes. All 10 mutations of 5.2 and the 4 of 116b are caught (W0 `retry-floor`, `key-no-tags`, `package-target-unchecked`, `or-ignore`, `link-ignored`, `client-equal-refused`, `ipv6-full`; W2 the others).

## 12. Answers (design agent, 2026-11-02)

All questions of section 9 are settled. The new rule is R-AP70 (the order of the hint path). The answers are in `DESIGN.md` 9 (Q170 to Q181) and `DESIGN-REGISTRY.md` (R-AP70, R-CT2, R-CT3, R-CT4, R-CT12 to R-CT15, R-IK5).

| Question | Answer | Design | Rule |
| --- | --- | --- | --- |
| Q116-1 | Changed. No `Authorization` header in 116a, as in slices 109 and 112. The token helper is the new slice 119a (PLAN). It moves no work into 116a. | Q170 | R-CT12 |
| Q116-2 | Changed: 415 comes before 413 of the body (R-AP66, Q144). The rest as proposed. | Q171 | R-AP70 |
| Q116-3 | Taken. The request uses the IP budget (116b). | Q172 | R-AP70 row 10 |
| Q116-4 | Taken | Q173 | R-CT2 |
| Q116-5 | Taken | Q174 | R-CT14, R-CT15 |
| Q116-6 | Taken | Q175 | R-CT3 |
| Q116-7 | Taken. The `detail` names the member. | Q176 | R-CT2 |
| Q116-8 | Taken | Q177 | R-IK5 |
| Q116-9 | Taken. Also: a page of 100 tags is a known limit. | Q178 | R-CT12 |
| Q116-10 | Taken | Q179 | R-CT13 |
| Q116-11 | Taken | Q180 | R-CT4 |
| Q116-12 | Taken | Q181 | R-CT4 |

### 12.1 Test changes (for the test agent)

| # | File | Change |
| --- | --- | --- |
| T1 | `HintsTest.roc`, `Hints.roc` (doc comments), W2 cases | Remove each mark `pending Q116-n`. Name R-AP70 and the Q ids of the table above in the tests that check them. |
| T2 | W2 `hints/ct2-bad-requests` | Add a request: a body of 262,145 bytes with `Content-Type: text/plain` and a good id: 415, 0 D1 calls (Q171, R-AP70 row 3). Keep the 413 case with `application/json`. Add a request with a bad id and a body that is not JSON: the 400 of the id (row 5 before row 6). Check that a bad id with 501 rows is still the 400 of the id. |
| T3 | W0 `Hints.retry_after` | Add `00:00:00.001` (86400, rounded up) and `23:59:59.999` (1), if not there. |
| T4 | W0 `skipped_sql` key words | Add the number `31536000000` (Q174). |
| T5 | W2 new case `hints/ct14-old-nightly-edge` | Two seeded nightlies: `published_at` = clock minus 31,536,000,000 ms (written, 201) and minus 31,536,000,001 ms (skipped, `old-nightly`). One of them has two `toolchains` rows (two targets) with two `published_at`: the smaller one decides. |
| T6 | W0 `check` | Add if missing: a platform row with a real target that has a code and is not in its `artifact_targets`: 400. The same row with an artifact that is not indexed: no 400 (skip). A package with a real target that has no code: 400 (Q173). |
| T7 | W2 `hints/ct4-hint-batch` | Check that the db row of `compat_hints` has `talon_version` 17180000255 for `0.4.1` and 0 for `unknown` (Q177). |

D1 calls that the cases pin do not change.

## 13. Code (code agent, 2026-11-02)

| File | Code lines (no comments) | What |
| --- | --- | --- |
| `worker/lib/Hints.roc` | 187 (290 with comments) | All bodies. `parse`: the 413 of the body, UTF-8, `Json.parse` of the wire record `PostWire`, `refuse_members`, the 413 of the rows, `row_of` (hash, nightly, result). `check`: `target_of` per row. The three SQL texts share the text `classified` (a `WITH` list: `r` the rows of `json_each(?1)`, `c` each row with the first reason or NULL) |
| `worker/HintRoutes.roc` | 129 (168 with comments) | `post!`: the flow of 3.3. `read!` is D1 call 1, `tag_list!` the `Memo` of the tags, `write!` is D1 call 2, `quota!` the 429. The rate limit (step 4) and `limiter` are the lines of the 116b agent |

Decisions that the slice does not fix:

| Item | Choice | Rejected |
| --- | --- | --- |
| Members that a hint must not have (`source`, `sweep`, `error_digest` in a row) | A nominal type `Hints.Present` with a hand-written `parser_for` that calls `Json.skip_json_value`. It reads any value, also `null`, an object and a list. The fields are `Try(Hints.Present, [Missing])` | A copy of `Nullable` (reads text and `null` only, so `"source":1` would be a type error, not the named 400) |
| Wire records | In `Hints.roc` (`PostWire`, `RowWire`): `records.Compat.decode_hint_post` is still `todo` and `packages/` is not changed here | Use `decode_hint_post` |
| `?3` and `?4` of the insert (machine id, key of `talon_version`) | Bound as decimal text, with `CAST(.. AS INTEGER)` in the SQL (64-bit values, R-IK2). `?2` (time) is a number | Bind the `I64` |
| `RETURNING` column | `CAST(artifact AS TEXT) AS artifact`, so that the route reads a row `{ artifact : Str }` and counts the rows | A column with no alias (its name is the text of the expression) |
| Tag list read | `Http.send!` of `Request.get(Hints.tags_url)` with the header `user-agent: talon-registry` (GitHub refuses a request with no user agent). No `Authorization` header (Q170) | `Http.get!` (no user agent) |
| Secret | `Env.secret!("CONTRIBUTOR_KEY")` after D1 call 1, before the tag list | Read it at the start |

### 13.1 Green results (2026-11-02)

| Layer | Result |
| --- | --- |
| W0 `HintsTest` | 15 of 15 `expect`s pass. `scripts/test.sh w0`: 330 of 341 pass. The 11 red ones are all `IdentityTest` (slice 113). `ClientTest` and `IngestLimitsTest` pass at that time (the 116b and 112b agents had finished their code) |
| W2 `scripts/test.sh wbuild w2` | 113 passed, 6 failed. All 8 `hints/*` pass: `ct4-hint-batch`, `ct2-bad-requests`, `ct12-talon-version`, `ct12-tags-fail`, `ct13-hint-quota`, `ct14-old-nightly-edge`, and (116b) `ap45-client-version`, `ct11-rate-limit`. Red, not this slice: `identity/*` (5, slice 113) and `compat/mx9-missing-100` (timeout at 30 s under load: three builds ran at the same time; it takes 19 s alone) |
| `scripts/test.sh check fmt w1` | pass |

No test file was changed (Disputes: none). The revert check (TW12) is not part of this task.
