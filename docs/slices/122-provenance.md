# 122 Provenance member

Phase: P2. Status: review (scope and red tests 2026-11-02). Model for the code: Sonnet medium. Plan row: `docs/registry/PLAN.md` C.1, row 122. Design: Registry R-AP49 (`provenance`), R-PU15, R-PU16, R-RE9, R-IK7; Design Q158.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-122-revert/` (the private reference).

## 1. Scope and split

Every answer with a release record gets the member `provenance`: the list of the `via` texts of the `provenance` rows of the release, strongest first (`oidc`, `webhook`, `poll`, `ingest`). One state has one ETag (Q158), so all answers change in this slice.

| Part | Who | State |
| --- | --- | --- |
| `packages/records/Release.roc`: `provenance : List(Str)` in `Row` and `Wire`. `to_wire` and `from_wire` give `[]` (stub: wrong value) | Test agent (types), code agent (2 lines) | Stub |
| `packages/records/Code.roc`: `via_name`, `via_sort` (`crash "todo"`) | Test agent (signatures), code agent (bodies) | Stub |
| `worker/lib/Reads.roc`: `ReleaseRow.vias`, `provenance_of` (`crash "todo"`), `release_of_row` (gives `provenance: []`) | Test agent (types), code agent (bodies) | Stub |
| `worker/IngestRoutes.roc`: `label_rows` sets `vias: Err(Missing)` (compile only) | Test agent (1 line) | Done |
| The SQL: `ReadRoutes.releases_sql`, `worker/sql/closure/releases.sql`, `IngestRoutes.label_sql_of` and `LabelSqlRow` | Code agent | To do (section 3) |
| Tests and fixtures (section 5) | Test agent | Red (section 9) |

Split decision: no split. The private reference is about 45 changed lines of code (records 14, Reads 20, SQL and routes 12). TW19 allows about 400.

The routes that carry a release: R-AP1, R-AP13, R-AP14 with and without `group` (`ReadRoutes`, `Reads.releases_body`, `page_body`), R-AP2 (`artifact_body`), R-AP17 (`ClosureRoute`, `ClosureQuery.answer`), R-AP8 ingest (`IngestRoutes`) and publish (`PublishRoutes`). All of them build the record with `Reads.release_of_row`, so one `ReleaseRow` field and three SQL texts give all of them the member. No route code changes except the SQL.

## 2. The wire change (for the CLI client track)

| Item | Change |
| --- | --- |
| `records.Release.Row` | New field `provenance : List(Str)`. Strongest first. Required on the wire |
| `records.Release.Wire` | The same field. A JSON answer with no `provenance` in a release is `BadJson` (R-AP51). `null`, a text and a list of numbers too |
| JSON | The member sits between `log_index` and `published_at` (the derived encoder writes the names in alphabetical order): `..."log_index":1,"provenance":["oidc","ingest"],"published_at":...` |
| Where | Each release in `Index.Releases`, `Index.Page`, `Index.Detail` (R-AP1, R-AP2, R-AP13, R-AP14), `Closure.Answer.releases` (R-AP17), `{"release":...}` of R-AP8 (ingest and publish) |
| Values | `oidc`, `webhook`, `poll`, `ingest`. A reader keeps a text it does not know (not a closed set, R-AP44) |
| Reader order | `records.Code.via_sort : List(Str) -> List(Str)` gives the strength order, a text that is not known goes last in its input order. `tln add` shows the first item (R-PU15) |
| ETag | Every ETag of an answer with a release changes (the body changes). A cached answer of an older Worker is replaced after its `max-age=60` |
| Fixtures | Any CLI fixture of a release record needs the member (`packages/records/tests/WireTest.roc` and `AnswerTest.roc` are updated in this slice). The CLI does not use `Release.Row` yet (`cli/lib/ClosureRequest.roc` imports `records.Closure` for the request only) |

## 3. What the code agent writes

| # | File | Change |
| --- | --- | --- |
| 1 | `packages/records/Release.roc` | `to_wire`: `provenance: r.provenance`. `from_wire`: `provenance: w.provenance` |
| 2 | `packages/records/Code.roc` | `via_name` (0 `oidc`, 1 `webhook`, 2 `poll`, 3 `ingest`, else `Err(NoSuchCode)`). `via_sort` (the 4 known texts in that order, with a repeated text kept; the other texts after them in input order) |
| 3 | `worker/lib/Reads.roc` | `provenance_of`: split the text at `,`, each item `U8.from_str`, `Code.via_name`, then `Code.via_sort`. A bad item is `Err(BadRow(text))`. `release_of_row`: `provenance = provenance_of(row.vias)?` |
| 4 | `worker/ReadRoutes.roc` `releases_sql` | Add the column `vias` (SQL below) |
| 5 | `worker/sql/closure/releases.sql` | The same column (W1 runs this file) |
| 6 | `worker/IngestRoutes.roc` | `LabelSqlRow.vias : Try(Str, [Missing])`, the column in `label_sql_of`, `vias: r.vias` in `label_rows` (the ingest and the publish read the label with this text) |

The column, the same text in the three SQL places (`r` is the alias of the release row; the codes are in ascending order, so the text is the strength order):

```sql
(SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias
```

It is `NULL` when the release has no row, and `0,1,2,3` style text with a comma and no white space otherwise. W1 (`closure/c2-closure-cte`) compares the column as text. Do not join `provenance` in the main statement: a release with 2 rows would appear 2 times.

`ReleaseRow.vias` is `Try(Str, [Missing])`, so a statement that has no `vias` column decodes as `Err(Missing)` and the cases that do not show a release stay green.

The answer of the paths that write a row (R-PU14 `AddProvenance`, R-PU16 `Write`) is the label read of the last statement of the write batch (as today), so it has the new row. The answer of the path with a row already (`Answer`) is the first read.

## 4. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP49 | `provenance`: list of text, the `via` of each row, strongest first `oidc`, `webhook`, `poll`, `ingest`, always present. An unknown text is kept after the known ones | W0 `CodeTest`, `WireTest`, `AnswerTest`, `ReadsTest`. W1 `c2-closure-cte`. W2 all cases of section 5 |
| R-PU15 | The strongest is `oidc`, then `webhook`, `poll`, `ingest`. A path adds its row only if its `via` has none | W0 `CodeTest`, `ReadsTest`. W2 `pu15-ingest-then-publish`, `pu14-pu19-labels` |
| R-PU16 | A publish after an ingest adds the `oidc` row: the list is `oidc`, `ingest` and not the order of the writes | W2 `pu15-ingest-then-publish`, `pu16-after-ingest` |
| R-RE9 | The codes of `via`: 0 `oidc`, 1 `webhook`, 2 `poll`, 3 `ingest` | W0 `CodeTest`. W1 |
| R-IK7 | A code is the position in the list of its rule | W0 `CodeTest` |
| R-AP51 | `provenance` is required: missing, `null`, text, numbers are `BadJson` | W0 `WireTest` |
| R-AP53, R-AP73 | The members of an answer are in a fixed order; the records encoder writes the bytes of the Worker | W0 `AnswerTest`, `ReadsTest` (bodies), W2 (ETags) |
| R-AP17 | The closure answer has the member in each release | W0 `ClosureQueryTest`, `WireTest`. W1, W2 `closure/ap17-answer` |
| R-AP8, R-AP9 | The ingest and the publish answer have the member | W0 `IngestTest`. W2 ingest and publish cases |
| R-AP1, R-AP2, R-AP13, R-AP14 | The read answers have the member | W2 `reads/*` |
| R-AP18 | One batch, one state: no new D1 call (the `d1-calls` files do not change) | W2 `d1-calls` of all changed cases |

## 5. Tests

W0 and W1 numbers are `expect`s or cases. The test agent changed these files (the copies before the change are in `research/slice-122-revert/before/`).

| Layer | File and case | Checks | State |
| --- | --- | --- | --- |
| W0 | `packages/records/tests/CodeTest.roc`: `via_name` (4 codes, 2 outside), `via_sort` (the 24 orders, shorter lists, `ingest`+`oidc`, unknown texts after the known ones, case counts) | R-AP49, R-PU15, R-RE9, R-IK7 | New, red (todo) |
| W0 | `WireTest.roc`: `release_row` and fixtures with the member; the member and its place in the text; 0, 1, 2, 4 texts round trip; missing, `null`, text, numbers are `BadJson`; an unknown text is kept; an unknown member is ignored; the closure answer | R-AP49, R-AP51, R-AP44, R-AP17 | Changed + 3 new, red |
| W0 | `AnswerTest.roc`: the fixtures of the three release answers have the member (script `research/slice-122-revert/gen/answertest.py`); decoded releases have a non-empty list | R-AP49, R-AP73, R-AP53 | Changed + 1 new, red |
| W0 | `worker/tests/unit/ReadsTest.roc`: `provenance_of` for the 24 orders and 9 shorter lists, 10 bad texts; `release_of_row` with `vias`; 2 more bad rows; the three bodies show the member | R-AP49, R-PU15, R-RE9 | Changed + 3 new, red |
| W0 | `IngestTest.roc`, `PublishTest.roc`: the rows have `vias`, `Answer(record7)` has `["oidc","ingest"]`; `Ingest.answer_body` has the member | R-AP8, R-PU14, R-PU16 | Changed, red |
| W0 | `ClosureQueryTest.roc`: `rows.releases` have `vias`; the answer has `["webhook","ingest"]` for the codes `3,1` | R-AP17 | Changed, red |
| W1 | `sql/tests/cases/closure/c2-closure-cte`: `setup.sql` has `provenance` rows (inserted out of order, 1 to 4 rows, 2 releases of the answer have none of the others); `requests.json` has `vias` in the 6 rows of `releases` | R-AP17, R-AP49, R-RE9 | Changed, red |
| W2 | `publish/pu15-ingest-then-publish` (new, 8 requests: ingest 201, read, publish 200, read after the cache drop, ingest 200, page read, artifact read, publish 200) | R-AP49, R-PU14, R-PU15, R-PU16, R-AP69, R-AP43 | New, red |
| W2 | Changed cases: `reads/ap1-body-etag-cache`, `ap13-group-series-after`, `ap14-pages`, `ap2-artifact`, `ap24-conditional-first`, `ap43-cache-refresh`, `ap43-not-found-uncached`, `ap56-case-fold`, `bookmark-session`; `closure/ap17-answer`; `ingest/pu14-pu19-labels`, `pu4-index-kinds`; `ingest-limits/ap69-cache-drop`, `pu34-ip`, `pu34-owner`; `publish/pu1-publish-package`, `pu16-after-ingest`, `tp9-claim-ids` | R-AP49 and the rules of each case | Changed, red |
| W2 | `reads/ap29-checked-stale`: only the seed has `provenance` rows (the answer shows no release, but the Worker reads the rows) | R-AP49 | Changed seed, stays green |

How the W2 cases changed (script `research/slice-122-revert/gen/w2_edit.py`, read after each run, TW21):

| Area | Seed rows | Expected files |
| --- | --- | --- |
| `reads/*` (6 releases) | 1: ingest. 2: ingest, oidc (inserted in that order). 3: webhook. 4: ingest, webhook, poll. 5: ingest, poll, webhook, oidc. 6: poll. `ap43-cache-refresh` also release 7: oidc | `provenance` in each release (the lists are `["ingest"]`, `["oidc","ingest"]`, `["webhook"]`, `["webhook","poll","ingest"]`, all four, `["poll"]`, `["oidc"]`). The exact `body` and the `etag` of the answers, the same ETag in `if-none-match` of `requests.jsonl` |
| `reads/ap14-pages` (1002 releases) | Every release: ingest. Even log index: also oidc | The 1000 releases of each page |
| `closure/ap17-answer` | The rows of the W1 case (releases 1 to 8) | The releases of the 6 answers |
| `ingest/*`, `ingest-limits/*`, `publish/*` | None (the seeds have rows, or the path writes them) | `pu14`: `["webhook","ingest"]` for the label with a webhook row (lines 1 and 2: the ingest adds its row, then the answer with the row), `["ingest"]` for the new ones. `pu16`: `["oidc","ingest"]`. `pu1`, `tp9`: `["oidc"]`. `ap69`: release 1 `["webhook"]`, release 2 `["ingest"]`. `pu34-*`: `["ingest"]` |

The `d1-calls`, `db.tsv` and `github.log` files do not change in the old cases: the same writes, the same calls.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| Member name and type | `provenance`, a JSON list of text (given by R-AP49) |
| Place in the text | After `log_index`, before `published_at` (alphabetical order of the derived encoder) |
| SQL column name | `vias` (text of codes, section 3). Not on the wire |
| `detail` of a 500 | None: a `BadRow` is a 500 `internal` with the text `provenance: <item> is not a via code` or `provenance: the via code <item> is not known` (a proposal, the text is not tested) |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| `claims` and the attestation result of a row | R-RE9 fields; the member lists the `via` texts only (Q158) |
| The webhook and the reconcile `via` values in W2 | Slice 118 (webhook) writes `webhook` and `poll` rows. The seeds of this slice insert them by SQL |
| The CLI side (`tln add` shows the strongest) | The CLI client track, from the wire change of section 2 |
| `yank_reason`, `yanked` | P3 |

## 8. Questions (decided 2026-11-02)

| # | Answer | Effect on code and tests |
| --- | --- | --- |
| Q122-1 (Design Q341) | A release with no `provenance` row gives `provenance: []`. It is not `BadRow` and not 500. Each write path adds the row in the release batch, so only a data fault makes the state. No trigger can guard it, because the row follows the release in the batch. A 500 would hide the other releases of a page. R-AP49 says this. | Code: `provenance_of` has no `BadRow` case; no row gives `[]`. Test (new, W0 `ReadsTest`, R-AP49): a release with no row gives `[]` and the other releases of the page are unchanged. W2: no change. |
| Q122-2 (Design Q342) | Two unknown `via` texts go in ascending byte order of the UTF-8 text, after the known values. R-AP49 says this. | Code: `Code.via_sort` sorts known values by rank, then unknown values by text. Test (new, W0 `CodeTest`, R-AP49): input `["zz", "ingest", "aa", "oidc"]` gives `["oidc", "ingest", "aa", "zz"]`, and the result is the same for any input order. |

## 9. Verify results

Red state of the test agent (2026-11-02, `OPT` speed build of `wbuild`):

| Step | Result |
| --- | --- |
| `roc test packages/records/tests/w0.roc`, both nightlies | 62 passed, 17 failed (all the new and changed expects: `todo` in `via_name` and `via_sort`, `[]` in the wire) |
| `roc test worker/tests/unit/w0.roc` | The failures of this slice: `ReadsTest` 8, `IngestTest` 2, `PublishTest` 1, `ClosureQueryTest` 1. `LoginTest`, `ToolchainsTest`, `WebhookTest` fail for the other slices that are in progress |
| W1 `closure` | `c2-closure-cte` red on sqlite and local D1 (`vias` missing in the rows) |
| `scripts/test.sh wbuild w2` | 19 cases of this slice red with `json.release.provenance: expected an array of N items, got []` or a wrong exact body and ETag. `ap29-checked-stale`, `ap13-bad-requests`, `ap48-method-not-allowed`, the other `ingest`, `publish` and `closure` cases stay green. The red cases of `account`, `compat`, `githubtoken`, `hints`, `oidc`, `toolchains`, `webhook` are from other slices (the `toolchains` column `size`) |
| `closure/ap17-answer` | Red also by the missing column `toolchains.size` (slice 109b). After that, it is red for `provenance` |
| `roc check worker/main.roc`, `scripts/test.sh check`, `fmt` | 0 errors, valid |

Private reference (`research/slice-122-revert/`, not for the code agent): all W0 of this slice, W1 `closure` and the 19 W2 cases pass. Mutations: see `research/slice-122-revert/mutations/` and the table in the final report.

## 10. Disputes (from the code agent)

None yet.

## 11. Code and green results (code agent, 2026-11-02)

Questions settled by the coordinator: Q341 (a release with no `provenance` row gives `[]`, not `BadRow`) and Q342 (unknown `via` texts after the known ones, in ascending UTF-8 byte order). The code uses these two answers, not the proposals of section 8.

| File | Change | Lines |
| --- | --- | --- |
| `packages/records/Release.roc` | `to_wire` and `from_wire` copy `provenance` | 2 |
| `packages/records/Code.roc` | `via_name`, `via_sort`, local `compare_bytes` (`Artifact` imports `Code`, so `Code` cannot import `Artifact.compare`) | 23 |
| `worker/lib/Reads.roc` | `import records.Code`, `provenance_of`, `via_of_item`, `release_of_row` uses `provenance_of(row.vias)?` | 15 |
| `worker/ReadRoutes.roc`, `worker/sql/closure/releases.sql` | column `vias` | 2 |
| `worker/IngestRoutes.roc` | `LabelSqlRow.vias`, column in `label_sql_of`, `vias: r.vias` | 3 |

`ClosureQuery.roc`, `PublishRoutes.roc`: no change (they use `Reads.release_of_row` and the label SQL of `IngestRoutes`). About 45 lines in all.

| Step | Result |
| --- | --- |
| `roc test packages/records/tests/w0.roc`, 10-14 and 10-31 | 80 passed each |
| `scripts/test.sh w0` | all slice 122 tests pass; the only fails are `WebhookTest` (slice 118) |
| `node sql/tests/run.mjs` | 51 passed, 2 failed: `schema/s1-tables` (slice 117). `closure/c2-closure-cte` passes on sqlite and D1 |
| `scripts/test.sh wbuild w2` (`--opt=speed`) | 150 passed, 8 failed: all 8 are `account/*` (slice 117). The 19 changed cases, `publish/pu15-ingest-then-publish` and `closure/ap17-answer` pass |
| `scripts/test.sh check fmt` | pass |
