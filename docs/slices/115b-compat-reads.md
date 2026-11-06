# 115b Compat reads: sweeps, audit and artifact compat

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code: Opus medium. Part 2 of slice 115 (split, TW19). 115a (`115a-compat-post.md`) has the bot path and the bot set SQL `prefix.sql`. 115b needs `prefix.sql` from 115a (the code agent of 115b may write it too, if 115a is not done).

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-115-revert/reference/` (the private reference).

## 1. Scope

| Route | Rule |
| --- | --- |
| `GET /v1/sweeps/{tag}?target=any` | R-AP39: the sweep row of a compiler, the log size, the count of members and the missing hashes |
| `GET /v1/compat_hints?audit=n` | R-AP40: the pairs that have hints and no bot row, at most n |
| `GET /v1/artifacts/{hash}/compat` | R-AP4: the runs and hints of one artifact on all compilers |

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/CompatReads.roc`: constants, signatures. Bodies are `crash "todo"` | Test agent, code agent | Stubs |
| `worker/CompatReadRoutes.roc`: `sweep!`, `audit!`, `artifact_compat!` are `crash "todo"` | Test agent, code agent | Stubs, wired in `worker/main.roc` |
| `worker/sql/compat/members.sql`, `audit.sql`, `sweep_tag.sql`, `sweep_row.sql`, `log_size.sql`, `artifact_present.sql`, `artifact_runs.sql`, `artifact_hints.sql` | Code agent | Missing (W1 `m2`, `a1` fail) |
| `worker/lib/Route.roc` (`GetSweep(Str)`, `GetCompatHints`, `GetArtifactCompat(Str)`) | Test agent (tags), code agent (lines) | Half |
| Tests: section 5 | Test agent | Red |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP39 | `GET /v1/sweeps/{tag}`: `{"log_size","members","missing","sweep"}`. `sweep` is the row or `null`. `target` is `any` or absent | W0 `sweep_body`, `parse_sweep_target`. W1 `m2`. W2 `ap39-sweeps` |
| R-AP40 | `GET /v1/compat_hints?audit=n`: `{"pairs":[...]}` | W0 `parse_audit`, `pairs_body`. W1 `a1`. W2 `ap40-audit` |
| R-AP4 | `GET /v1/artifacts/{hash}/compat`: `{"hints","runs"}` as the closure answer | W0 `compat_body`. W2 `ap4-artifact-compat` |
| R-AP41 | Statements as one batch; the session of `Reads.session_of` | W2 d1-calls |
| R-AP43, R-AP54, R-AP55, R-AP56 | `audit` and `compat` use `ReadRoutes.serve!(req, "max-age=300", ...)`: ETag, 304, Cache API. `sweeps` is `no-store`, no ETag | W2 |
| R-AP24, R-AP17, R-AP58, R-RE3, R-RE12 | Order of items. Runs and hints are the bytes of the closure answer. `error_digest` null stays null | W0, W1, W2 |
| R-AP48 rows 1, 2 | `GET` only (405 with `Allow: GET`) | W0 `Route.decide` |
| R-AP21, R-AP46 | 404 for a tag with no `toolchains` row; 400 for a bad query | W0, W2 |
| R-MX11, R-MX16 | `members`, `missing`: the bot set at the log size now | W1 `m2` |
| R-MX13, R-RE8, R-EF3 | `audit`: unit checks and platform targets only (no tool app target); an `author` row does not remove a pair; the counts add up over `talon_version` | W1 `a1` |
| R-IK2, R-IK4, R-IK7 | The tag (both forms), the hash, the target names | W0, W2 |

## 3. What the code agent writes

### 3.1 Signatures

| Function | Signature |
| --- | --- |
| `CompatReads.parse_sweep_target` | `Try(Str, [NotFound]) -> Try({}, Problem)` |
| `CompatReads.parse_audit` | `Try(Str, [NotFound]) -> Try(U64, Problem)` |
| `CompatReads.no_tag` | `Str -> Problem` |
| `CompatReads.sweep_body` | `{ tag, sweep : Try(SweepRow, [None]), log_size, members, missing : List(Str) } -> Str` |
| `CompatReads.pairs_body` | `List(PairRow) -> Try(Str, [BadRow(Str)])` |
| `CompatReads.compat_body` | `{ runs : List(ClosureQuery.RunRow), hints : List(ClosureQuery.HintRow) } -> Try(Str, [BadRow(Str)])` |
| `CompatReads.audit_limit`, `cache_control`, `sweep_cache_control` | `1000`, `"max-age=300"`, `"no-store"` |

### 3.2 The flows

| Route | Steps |
| --- | --- |
| `sweep!(req, tag)` | 1. `parse_sweep_target(req.query("target"))`, `Err` is 400 (no D1 call). 2. `Id.nightly_id(tag)`; a tag that is no nightly tag is `no_tag` 404 (no D1 call). 3. One session `batch!` of 5 statements: `sweep_tag`, `sweep_row`, `log_size`, `members`, `missing` (the last two with `(nightly, 0, NULL)`). 4. No `sweep_tag` row: `no_tag` 404. 5. 200, `application/json`, `cache-control: no-store`, `sweep_body` (the tag is the stored one) |
| `audit!(req)` | `parse_audit` (400 before D1), then `ReadRoutes.serve!(req, cache_control, [audit statement with the limit], build)`, `build` = `pairs_body` |
| `artifact_compat!(req, hash)` | A malformed hash: 404 `no artifact <hash>`, no D1 call. The id from the hash, then `ReadRoutes.serve!` with `artifact_present`, `artifact_runs`, `artifact_hints`. No `artifact_present` row: 404 `no artifact <hash>` (not put in the cache). Body `compat_body` |

### 3.3 Edits of files that other slices own

| File | Edit |
| --- | --- |
| `worker/lib/Route.roc` `decide` | `GET /v1/sweeps/{tag}` -> `Handle(GetSweep(tag))`; `GET /v1/compat_hints` -> `Handle(GetCompatHints)`; `GET /v1/artifacts/{hash}/compat` -> `Handle(GetArtifactCompat(hash))`. `GET /v1/artifacts/{hash}` stays `GetArtifact`. Another method: 405 with `Allow: GET`. Other paths of the same words (`/v1/sweeps`, `/v1/sweeps/{tag}/x`, `/v1/artifacts/{hash}/other`): 404 `no route for <method> <path>` |

## 4. The SQL (the contract between the code and W1)

`members` = `prefix.sql` (115a section 4), newline, `members.sql`. The parameters are `(?1 nightly, ?2 target code, ?3 bound)`; for the route, ?2 is 0 and ?3 is NULL.

| File | Parameters | Columns | Rows | Order |
| --- | --- | --- | --- | --- |
| `members.sql` | the prefix | `members` | One row: `COUNT(*)` of the members (distinct hashes, Q115b-4) | |
| `audit.sql` | ?1 the most pairs | `hash` (BLOB), `nightly` (tag), `target` (name), `pass_count`, `fail_count`, `crash_count` | The pairs (hash, nightly, target) that have `compat_hints` rows and no `compat` row of source `bot`, with a `toolchains` row for the nightly, and target `any` or an artifact of kind platform. Counts are sums over `talon_version` | Total (pass + fail + crash) descending, then hash bytes, nightly id, target code (Q115b-6) |
| `sweep_tag.sql` | ?1 nightly id | `tag` | The smallest `tag` of the `toolchains` rows of the nightly (by target) | |
| `sweep_row.sql` | ?1 | `upto_log_index`, `time` | The `sweeps` row of (nightly, target 0), if any | |
| `log_size.sql` | none | `log_size` | `COALESCE(MAX(idx), 0)` | |
| `artifact_present.sql` | ?1 artifact id | `present` | One row if the `artifacts` row exists | |
| `artifact_runs.sql` | ?1 | `hash`, `target` (name), `source` (0 bot, 1 author), `result` (0 to 3), `error_digest` (NULL stays NULL), `from`, `to` (tags) | The runs of the artifact on all compilers, as the closure `runs` (an equal row on following compilers is one run; the order of nightlies is R-MX16) | `hash`, `target` name, `source`, place of `from` |
| `artifact_hints.sql` | ?1 | `hash`, `nightly` (tag), `target` (name), `pass_count`, `fail_count`, `crash_count` | The hints of the artifact, summed over `talon_version` | place of the nightly, target name |

A nightly with no `toolchains` row has no tag, so its runs, hints and pairs are not visible.

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/CompatReadsTest.roc`, 7 `expect`s: `parse_sweep_target` (also `Any` and `0`), `parse_audit` (digits, no leading zero, cap 1000 also for numbers beyond 64 bits, missing, 12 bad forms), `no_tag` and constants, `sweep_body` (120 hashes, quote escape), `pairs_body`, `compat_body` (codes, null and empty digest, `BadRow`), `Route.decide` for the 3 routes | R-AP39, R-AP40, R-AP4, R-AP48, R-AP24, R-AP58 |
| W1 | `compat/m2-members-count`: random states, the count and the missing hashes at the log size now against the JS reference | R-AP39, R-MX11, R-MX16 |
| W1 | `compat/a1-audit`: `setup.sql`, `test.mjs`: sums over versions, an `author` row does not remove a pair, targets, apps, no tag, order of equal totals, the limit (0 gives none) | R-AP40, R-MX13, R-RE8, R-MX16 |
| W2 | `compat/ap39-sweeps`: 12 requests (a sweep row, no row, a missing list, both tag forms, bad `target`, unknown tag, 405) | R-AP39 |
| W2 | `compat/ap40-audit`: 12 requests (the pairs, ETag, 304, limit, bad `audit`, cap, `Cache-Control`) | R-AP40, R-AP54, R-AP55, R-AP56 |
| W2 | `compat/ap4-artifact-compat`: 11 requests (runs and hints, ETag, 304, 404 for an unknown or malformed hash, not cached) | R-AP4, R-AP43, R-AP54, R-AP55 |

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`CompatReadsTest`) | 7 expects, 0 pass (re-run 2026-11-02 after 9.2). 0 compiler errors. `roc fmt --check` passes |
| W1 | `m2-members-count` and `a1-audit` fail on both backends: `the compat SQL is missing: .../audit.sql` or `prefix.sql` |
| W2 | 0 of 3 pass: 404 `no route for GET ...` (the `decide` lines are missing) |

### 5.2 Private reference and revert check

With the reference (after 9.1): W0 44 of 44, W1 6 of 6, W2 10 of 10.

| Mutation | What | Caught by |
| --- | --- | --- |
| `audit-limit` | `audit` above 1000 is not cut | W0 |
| `sweep-target-any` | A `target` other than `any` is accepted | W0 |
| `cache-404` | An unknown artifact gives 200 with empty lists | W2 `ap4-artifact-compat` |
| `no-distinct` | A member counted twice | W1 `m2` |
| `window-gt`, `series-major-only`, `bound-null` | The bot set (as 115a) | W1 `m2` |
| `audit-bot-filter` | Pairs removed by an `author` row | W1 `a1` |
| `audit-app-target` | An app tool target in the list | W1 `a1` |
| `audit-order` | The tie order | W1 `a1` |
| `audit-per-version` | The counts not summed over versions | W1 `a1` |

All caught.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| `sweeps` body | `{"log_size":n,"members":n,"missing":["<base58>",...],"sweep":{"nightly":"<tag>","target":"any","time":ms,"upto_log_index":n}}` or `"sweep":null`. Members in alphabetical order (the derived encoder). `missing` in hash byte order, no cap |
| `audit` body | `{"pairs":[{"crash_count","fail_count","hash","nightly","pass_count","target"}]}` |
| `compat` body | `{"hints":[...],"runs":[...]}`, items as the closure answer |
| 404 | `no toolchain for the tag <tag>`; `no artifact <hash>` |
| 400 | `the query parameter target must be any, got <t>`; `GET /v1/compat_hints needs the query parameter audit`; `the query parameter audit must be a count (decimal digits), got <t>` |

## 7. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | The manager | As 115a RQ2: the SQL files in `worker_stamp` |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| User hint rows (slice 116) | They write `compat_hints` |
| Tag spelling variants (both nightly forms) in `sweeps` | Not tested beyond `Id.nightly_id` |
| Q115b-5: the audit includes an app hash with target `any` | The literal rule; not tested |

## 9. Questions (all settled: see 9.1)

| Id | Question | Proposal |
| --- | --- | --- |
| Q115b-1 | A `target` of sweeps other than `any` | 400 |
| Q115b-2 | `audit` | Required; decimal digits, no leading zero |
| Q115b-3 | `audit` above 1000 | Cap to 1000 (also huge numbers); 0 gives an empty list |
| Q115b-4 | `members` | Count of distinct hashes |
| Q115b-6 | The order of equal totals in `audit` | Hash bytes, nightly id, target code |
| Q115b-7 | `{hash}` of R-AP4 that is malformed | 404 `no artifact <hash>`, no D1 call |

### 9.1 Decisions (design agent, 2026-11-02)

All 6 answers are the proposals. The rules are R-AP67 (new) and R-MX11 row 5 (new). Q115b-5 stays out of scope (not asked).

| Id | Answer | Rule, Design Q |
| --- | --- | --- |
| Q115b-1 | The proposal: `target` is absent or `any`; any other text, also an empty one, is 400. A sweep exists only for `any` (R-MX4), so another target has no fact. R-AP56 gives 200 for `target` of R-AP5 because that parameter filters rows that exist for each target. No change to slice 109 | R-AP67, Q147 |
| Q115b-2 | The proposal: `audit` is required; decimal digits, no leading zero (the form of `after` in R-AP56) | R-AP67, Q148 |
| Q115b-3 | The proposal: above 1000 is 1000, also past 2^63 - 1 (the text is compared); `audit=0` gives `{"pairs":[]}`. `after` is 400 above 2^63 - 1 (slice 106, Q95) because it binds to a column; `audit` is a count, and R-AP40 says "at most 1000". No change to slice 106 | R-AP67, Q149 |
| Q115b-4 | The proposal: distinct hashes. R-MX11 gets row 5: a member is a hash | R-MX11, R-AP67, Q150 |
| Q115b-6 | The proposal: total from large to small, then hash bytes, nightly id, target code, each rising | R-AP67, Q151 |
| Q115b-7 | The proposal: 404 `no artifact <hash>`, no D1 call. R-AP56 names R-AP4 too. No change to slice 106 | R-AP56, R-AP67, Q152 |

Test changes for the test agent:

| # | Test | Change |
| --- | --- | --- |
| T1 | All W0, W1, W2 | Remove the "pending" mark of Q115b-1 to Q115b-7. Name R-AP67 in the tests that check it. |
| T2 | W0 `parse_sweep_target` | Make sure that these rows exist: absent is `Ok`; `any` is `Ok`; `target=` (empty), `Any`, `x64glibc`, `0` are `Err` 400. Add the missing ones. |
| T3 | W2 `ap39-sweeps` | Make sure that a tag with no nightly id (for example `v1`) gives 404 `no toolchain for the tag v1` with D1 calls 0. Add it if the 12 requests have no such tag. |
| T4 | W2 `ap40-audit` | Add 2 requests: `audit=5000` and `audit=1000` on one state give the same body and the same ETag; `audit=0` gives `{"pairs":[]}` with 200 (if not there). |
| T5 | Doc comments of `worker/lib/CompatReads.roc` | Cite R-AP67 and R-MX11 row 5. No signature change. |

W1 `m2`, `a1` and the mutations of 5.2 stay as they are: `no-distinct`, `audit-order` and `audit-limit` already pin Q115b-4, Q115b-6 and Q115b-3.

### 9.2 Test changes done (test agent, 2026-11-02)

| # | Done |
| --- | --- |
| T1 | The "pending" marks are gone from `CompatReadsTest`; R-AP67 (and R-MX11 row 5) is named in the W0 comments, in the W2 `rules` of `ap39-sweeps`, `ap40-audit`, `ap4-artifact-compat` and in the W1 `rules` of `m2`, `a1` |
| T2 | W0 `parse_sweep_target`: `Any` and `0` added (the rows absent, `any`, empty, `x64glibc` were there) |
| T3 | W2 `ap39-sweeps` request 6 (`/v1/sweeps/latest`, a tag with no nightly id): 404 `no toolchain for the tag latest`, 0 D1 calls. It was there |
| T4 | W2 `ap40-audit`: `audit=1000` and `audit=99999999999999999999999999` added, same body and ETag as `audit=5000` (the D1 count of these two is not pinned: `-`). `audit=0` and `audit=5000` were there |
| T5 | The doc comments of `CompatReads.roc` cite R-AP67 and R-MX11 row 5 |

## 10. Disputes

None.

## 11. Verify

`roc fmt --check`, W0, W1 (`node sql/tests/run.mjs compat`), W2 (`node worker/tests/run.mjs compat`). `MISSING=1 scripts/rules.sh R-AP R-MX`.

## 12. Code (code agent, 2026-11-02)

| File | Code lines (no comments) | What |
| --- | --- | --- |
| `worker/lib/CompatReads.roc` | 71 (110 with comments) | All bodies. `compat_body` converts the rows with `ClosureQuery.run_of` and `hint_of`; the run text is built by hand (`error_digest` `null`, `Nullable` is private to `records`) |
| `worker/CompatReadRoutes.roc` | 122 (145) | `sweep!` (one session batch of 5), `audit!` and `artifact_compat!` (`ReadRoutes.serve!`) |
| `worker/sql/compat/members.sql`, `audit.sql`, `sweep_tag.sql`, `sweep_row.sql`, `log_size.sql`, `artifact_present.sql`, `artifact_runs.sql`, `artifact_hints.sql` | 30 lines | Section 4. `artifact_runs.sql` and `artifact_hints.sql` hold their own `d` CTE (the order of R-MX16) |
| `worker/lib/Route.roc` | 3 lines in `decide` | `GetSweep`, `GetCompatHints`, `GetArtifactCompat`, all with `decide_get` |
| `worker/sql/compat/prefix.sql`, `missing.sql` | written in 115a | |

Decision: `sweep_tag.sql` is `SELECT tag ... ORDER BY tag LIMIT 1` (no row for an unknown nightly), not `MIN(tag)` (one NULL row).

### 12.1 Green results (2026-11-02)

| Layer | Result |
| --- | --- |
| W0 `CompatReadsTest` | all 7 `expect`s pass |
| W1 | `m2-members-count` and `a1-audit` pass on sqlite and local D1 |
| W2 | `ap39-sweeps`, `ap40-audit`, `ap4-artifact-compat` pass |
