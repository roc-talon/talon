# 124 Worker on the records codecs

Phase: P2. Status: code done (2026-11-02). Plan row: `docs/registry/PLAN.md` row 124. Rules: R-PK7, R-AP73. This is a refactor. No test was changed (TW18).

## 1. Scope

The Worker builds its bodies with the codecs of `packages/records` (104e, 104f). The wire bytes do not change. The function names stay, because the tests and the routes call them.

## 2. Replaced functions

| Function | Now calls |
| --- | --- |
| `Reads.releases_body` | `Index.encode_releases` |
| `Reads.page_body` | `Index.encode_page` |
| `Reads.artifact_body` | `Index.encode_detail` |
| `Toolchains.put_body` | `Toolchain.encode_put` |
| `Toolchains.page_body` | `Toolchain.encode_page` |
| `Toolchains.row_text`, `rows_text` | removed (`Toolchain.encode_row`); `Toolchains.Row` is `Toolchain.Row` |
| `Shorts.matches_body` | `Short.encode_matches` (`entry_json`, `item_json` removed) |
| `Shorts.search_body` | `Short.encode_packages` |
| `Hints.parse` | `Compat.decode_hint_post` (as `Wire`) |
| `Hints.answer_body` | `Compat.encode_hint_answer`; `Hints.Skipped` is `Compat.HintSkip` |
| `Hints.Present`, `RowWire`, `PostWire`, `refuse_members` | removed |

`Reads.repos_json` becomes `Reads.sorted_repos`: the encoders write the lists in the order given (R-AP53), so the Worker sorts `repos` by name before the call. `Reads.releases_json` is removed.

## 3. Lines

| File | Before | After | Change |
| --- | --- | --- | --- |
| `worker/lib/Reads.roc` | 378 | 370 | -8 |
| `worker/lib/Toolchains.roc` | 349 | 343 | -6 |
| `worker/lib/Shorts.roc` | 336 | 325 | -11 |
| `worker/lib/Hints.roc` | 290 | 255 | -35 |
| Total | 1353 | 1293 | -60 |

## 4. Bytes and texts

| Item | Result |
| --- | --- |
| Wire bytes and ETags | No difference. The W0 tests and the W2 cases of reads, toolchains, shorts, hints, compat, closure, ingest and publish give the same results as before. |
| `detail` of a 400 for a hint body | The text after `the hint request body is not valid: ` is now the `BadJson` text of `Compat.decode_hint_post` (for example `member sweep or source is not allowed in a hint request`), not the old text of `Hints.refuse_members`. The tests check the member name only. No W2 case compares the text. |

## 5. Results

| Run | Before | After |
| --- | --- | --- |
| `scripts/test.sh w0` | 405 pass, 15 fail (LoginTest, WebhookTest) | 405 pass, 15 fail (the same files) |
| `node sql/tests/run.mjs` | 2 fail (`schema/s1-tables`, sqlite and d1) | the same |
| `scripts/test.sh wbuild w2` | 150 pass, 8 fail (`account/*`) | the 8 `account/*` fail, and 8 `webhook/*` cases fail: the slice 118b test agent changed those cases and the release job during the run (queue exception), not this slice |
| `scripts/test.sh check fmt` | pass | pass |
| `scripts/test.sh w1` | 51 pass, 2 fail (`s1-tables`) | the same |
