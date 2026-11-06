# 109 Toolchain routes

Phase: P2. Status: review (tests red, 2026-11-01; updated for the answers Q109-1 to Q109-9, section 7.1). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 109. Depends on slices 101, 102, 103 (the leaf and the triggers), 104 (`Id.nightly_id`) and 108 (`Auth.bot!`).

## 1. Scope

Two routes for the compiler list (R-AP5, R-AP6) and the pure parts that they need.

| Route | What it does |
| --- | --- |
| `GET /v1/toolchains?after=&target=` | One D1 call. Pages of 1000 rows in `log_index` order, `more`, a `target` filter, 400 for a bad `after`. |
| `PUT /v1/toolchains/{tag}` | The bot token (slice 108). Then: read the rows of the tag (D1 call 1). A tag with rows gives 200 and no GitHub call. A new tag: the Worker reads the GitHub release, selects the assets (R-CV1, R-CV2, R-CV8), takes each sha256 from `digest` (R-CV3), and writes one batch (D1 call 2) with a leaf and a row for each asset. The answer is 201. |

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Toolchains.roc`: types, constants and problems (given), the other functions are `crash "todo"` | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/ToolchainRoutes.roc`: `put!` and `list!`, the flow is in the doc comment | Test agent (signatures), code agent (bodies) | Stubs `crash "todo"` |
| `worker/lib/Route.roc`: the tag `GetToolchains` in `Route.Id` | Test agent | Done. The line of `decide` for `["v1", "toolchains"]` is for the code agent (`decide_get`). |
| `worker/main.roc`: the arms `GetToolchains` and `PutToolchain(tag)` call the stubs | Test agent | Done. `Auth.bot!` stays first. |
| `worker/lib/main.roc` (`Toolchains` in the exposes), `worker/tests/unit/w0.roc` (`import ToolchainsTest`) | Test agent | Done |
| Tests: `worker/tests/unit/ToolchainsTest.roc`, `worker/tests/cases/toolchains/` (10 cases) | Test agent | Red (section 4.2) |
| The 6 `oidc/*` cases of slice 108 that had a 500 row | Test agent | Changed (section 4.3) |
| Runner: the checks `json_len`, `json_at`, `json_range` in `worker/tests/run.mjs`, the test path `/__test/rows` in `worker-test.js`, 4 self-tests, 1 runner case | Test agent | Done |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP5 | `{toolchains, more}`: rows with a larger `log_index`, in `log_index` order, at most 1000. `target` filters. No `after` is `after=0`. 400 for a bad query. `max-age=300`. | W0 `parse_query`, `page_of`, `page_body`. W2 `get-query`, `get-pages`, `get-bad-query`, `get-etag-304` |
| R-AP47 | Paging by `log_index` (not by nightly): each row once, `more` only when a row follows, the largest index gives an empty page | W0 `page_of`. W2 `get-pages` (2,500 rows; the 5 rows of a nightly are 500 rows apart) |
| R-AP6 | `PUT /v1/toolchains/{tag}`, no body, `{toolchains}`. 201 new rows, 200 a tag with rows. 404 (GitHub has no release), 422 `not-a-candidate`, 502. | W0 `put_body`, `no_release`, `no_candidate`, `github_*`, `Route.decide`. W2 `pu-*` |
| R-PU7, R-TP7 | The bot calls the route with its token | W2 `pu-*` (the token `bot`), `oidc/*` (slice 108) |
| R-PU8 | The Worker reads the release itself and does not trust the request for the sha256 | W0 `release_url`, `parse_release`. W2 `pu-asset-rules` (a body with a made-up `sha256`), `pu-github-answers` |
| R-PU9 | One batch writes a row and a leaf for each asset. A tag that has rows is not written again. | W0 `writes_of`, `after_rows`. W2 `pu-new-tag`, `pu-odd-sha-names`, `pu-digest-kept` |
| R-PU10 | A later other `digest` keeps the recorded row, and the answer has it | W2 `pu-digest-kept` |
| R-SG3, R-SG8 rows 1, 2, 6 | The leaf: group `roc-lang/nightlies:<target>`, version the tag, hash `sha256:<hex>`, `time` the time of the write | W0 `leaf_of`, `writes_of`. W2 `pu-new-tag` (the `log` rows, with a clock that is not `published_at`), `pu-odd-sha-names` |
| R-RE4, R-MX16 | The row; the rows of one tag have one `published_at` | W0 `parse_time`, `writes_of`. W2 `pu-new-tag`, `pu-odd-sha-names` |
| R-IK4 | The nightly id of both tag forms; a tag with the id of another recorded tag gets 422 `not-a-candidate` | W0 `after_rows`. W2 `pu-id-collision`, `pu-new-tag` (the `nightly` column) |
| CLI R-CV1, R-CV2 | Asset selection: `roc_nightly-<target>-` and `.tar.gz` (`.zip` for Windows); 2 or more for a host give none for it; the date and sha in the name are not compared; an unsafe name is no asset | W0 `select_assets`. W2 `pu-asset-rules`, `pu-odd-sha-names` (2 of the 3 real releases with another sha in the name) |
| CLI R-CV3, R-CV8 | sha256 from `digest`; the six targets | W0 `select_assets`, `host_targets`. W2 `pu-*` |
| R-AP54, R-AP55 | The ETag (first 16 bytes of SHA-256 of the body, 32 hex digits, quoted), `If-None-Match` (weak, list, `*`), 304 with no `Content-Type`, the Cache API with the whole URL as key, the bypass by `no-cache` only, `max-age=300` | W2 `get-etag-304` |
| R-AP56 | `after`: decimal digits, no leading zero, at most 2^63 - 1, else 400; `target`: any text, empty or unknown gives 200 with no rows | W0 `parse_query`. W2 `get-bad-query`, `get-query` |
| R-AP57 | The steps of `PUT`: no nightly id 422 with no D1 call; D1 before GitHub; a draft or prerelease 422; a `published_at` that is not in the `Z` form 502; a bad `digest` drops the asset for its host; 201 only when a `toolchains` statement has `changes` above 0 | W0 `start`, `after_rows`, `candidates`, `put_status`, `select_assets`, `parse_time`. W2 `pu-not-candidates`, `pu-digest-rules`, `pu-github-answers`, `pu-new-tag`, `pu-digest-kept` |
| R-AP41 | GET: 1 D1 call, 0 for a 400. PUT: 1 call for a recorded tag, an error or no candidate, 2 for a new tag. | W2 `expect/d1-calls` of each case |
| R-AP21, R-AP48 | The problem form; 405 with `Allow`; 400 before any D1 call | W0 `Route.decide` rows. W2 `get-bad-query`, `pu-github-answers` |
| R-AP44 | Unknown query parameters and unknown members of the GitHub answer are ignored | W0 `parse_release`. W2 `get-query`, `get-pages` |
| R-AP50 | `published_at` in ms | W0 `parse_time` |

Design refs: Registry 3 (R-SG3, R-SG8), 4 (R-AP5, R-AP6), 4.2 (R-AP21, R-AP24, R-AP41, R-AP47, R-AP48), 5 (R-RE4), 5.1 (R-IK4), 6 (R-MX16), 7 (R-PU7 to R-PU10); CLI 6.2 (R-CV1 to R-CV3, R-CV8); Design 8 (R-SE18).

## 3. What the code agent writes

### 3.1 Public signatures (in the stubs, fixed)

| Module | Item | Type or rule |
| --- | --- | --- |
| `Toolchains` | `page_limit` 1000, `cache_control` `max-age=300`, `host_targets` (6, byte order), `archive_suffix`, `release_url` | Given |
| `Toolchains` | `not_nightly`, `not_final`, `no_release`, `no_candidate`, `id_taken`, `github_status`, `github_no_answer`, `github_bad` | Given (the texts are proposals, section 5) |
| `Toolchains` | `parse_time : Str -> Try(U64, [BadTime])` | `YYYY-MM-DDTHH:MM:SSZ` to ms |
| `Toolchains` | `parse_release : Str -> Try(Toolchains.Release, [BadRelease])` | The GitHub answer. `digest` missing or `null` is `Err(Missing)`. |
| `Toolchains` | `select_assets : List(Toolchains.Asset) -> List(Toolchains.Picked)` | R-CV2, R-CV3, in the order of `host_targets` |
| `Toolchains` | `leaf_of`, `writes_of` | R-SG3, R-SG8 |
| `Toolchains` | `Release`, `Row`, `Picked`, `Write`, `Leaf`, `Query` | Types, given |
| `Toolchains` | `start`, `after_rows`, `candidates`, `put_status` | R-AP57 steps 1, 2, 4 and 6, 7. The handler follows these: `start` (no D1 before it), D1 read, `after_rows`, GitHub, `candidates`, batch, `put_status`. |
| `Toolchains` | `parse_query`, `page_of`, `put_body`, `page_body` | R-AP5, R-AP6 |
| `ToolchainRoutes` | `put! : Request, Str => Try(Response, ToolchainRoutes.Error)`, `list! : Request => Try(Response, ToolchainRoutes.Error)` | The flow is in the doc comment of the module |
| `Route.Id` | `GetToolchains` | The line in `decide` is for the code agent |

`targets` is a reserved word of Roc, so the list is `host_targets`.

### 3.2 The SQL of the write batch (R-SG8 row 6)

For each `Write`, in this order: the leaf statement `INSERT INTO log (idx, grp, version, hash, time) SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)`, then `INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) SELECT ?, ?, ?, ?, ?, ?, (SELECT MAX(idx) FROM log) WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)`. No `OR IGNORE`. The last statement of the batch is the read of the rows of the nightly, so the batch is the only write call (R-AP41). The nightly id is bound as text (R-IK2). The private reference has the working texts, and the code agent must not read it (TW18); these two statements are given here.

### 3.3 Size

The private reference has 218 lines in `Toolchains.roc` (with no comments) and 91 in `ToolchainRoutes.roc`, plus 1 line in `Route.roc`. The code is about 150 lines without blank lines. It fits TW19.

## 4. Tests

### 4.1 Table

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| W0 | `ToolchainsTest.roc`, 76 `expect`s | `Route.decide` (8 rows: GET list, 405 with `Allow: GET` for 3 methods, PUT tag also with a body of another media type, GET tag 405, a longer path). The constants. `parse_time` (8 good, 18 bad: also `+00:00`, a fraction, a lower-case `z`). `parse_release` (the GitHub shape with unknown members, an asset with no `digest` and with `digest` null, no asset, draft and prerelease, 13 bad texts, also a `published_at` with an offset). `select_assets` (the real release of 2026-10-21; the real release with another sha in the names, in reverse order; 18 names that are no asset; 11 bad digests; a bad digest does not count for the rule of 2 assets; 2 or 3 assets for a host; a quote in a name). `leaf_of`, `writes_of`. The steps: `start` (no id, with an id), `after_rows` (5 rows), `candidates` (draft, prerelease, no asset, only bad digests), `put_status` (7 lists, the race that W2 cannot make: all `changes` 0 gives 200). `parse_query` (8 good: also `9223372036854775807`, an empty and an unknown `target`; 16 bad `after`: also `007`, `00`, `9223372036854775808`, `18446744073709551615`). `page_of` (0, 1, 999, 1000, 1001, 1500 rows). The 5 bodies (also the escape of a quote). The problems. | R-AP5, R-AP6, R-AP47, R-AP48, R-AP56, R-AP57, R-PU8 to R-PU10, R-SG3, R-SG8, R-RE4, R-IK4, R-CV1 to R-CV3, R-CV8, R-AP50 |
| W2 | `toolchains/pu-new-tag` | The real release `nightly-2026-10-21-5349569` (10 assets: 5 compilers, 2 source, 3 wasm): 201 with the 5 rows (exact body), 2 D1 calls, 5 leaves with the time of the write (not `published_at`), the `nightly` column. The same PUT again: 200, same body, 1 D1 call, no GitHub call. | R-AP6, R-PU7 to R-PU9, R-SG3, R-SG8, R-RE4, R-IK4, R-MX16, R-AP41, R-CV1 to R-CV3, R-CV8 |
| W2 | `toolchains/pu-odd-sha-names` | 2 real releases whose names have another date and sha than the tag (`nightly-2025-October-25-c3487d2`, `nightly-2026-February-10-c95f04d`, both with the month as a name), 6 hosts each, `.zip` for both Windows hosts. Leaf indexes continue (7 to 12). | R-AP6, R-PU8, R-PU9, R-CV1 to R-CV3, R-CV8, R-IK4, R-MX16 |
| W2 | `toolchains/pu-asset-rules` | One release with 2 `linux_x86_64` assets, a `macos_x86_64` name with `/`, `windows_x86_64` as `.tar.gz`, source and wasm assets: 3 rows (`linux_arm64`, `macos_apple_silicon`, `windows_arm64`). The request has a JSON body with a made-up `sha256`, which is not read. | R-AP6, R-PU8, R-PU9, R-CV2, R-CV3, R-CV8, R-SG3 |
| W2 | `toolchains/pu-digest-kept` | A real release is recorded. The second GitHub answer (file `.2`) has other digests. The second PUT gives 200 with the recorded rows, 1 D1 call, and GitHub is read once. | R-PU9, R-PU10, R-CV3, R-AP41 |
| W2 | `toolchains/pu-github-answers` | 8 tags: GitHub 404 (404 `not-found`), 500 and 403 (502 `upstream`), a body that is not JSON and a JSON that is not a release (502), a real release with 0 assets and a release with only source and wasm assets (422 `not-a-candidate`), a `published_at` with `+00:00` (502). Each: 1 D1 call, 1 GitHub call, nothing written. | R-AP6, R-AP21, R-PU8, R-CV2, R-AP41 |
| W2 | `toolchains/pu-not-candidates` | A tag with a date that does not exist, `v1.2.3`, and an upper-case sha: 422, 0 D1 calls, no GitHub call. A draft and a prerelease with good assets: 422. A release whose compiler assets all have a bad digest (missing, 63 hex digits, upper case, `sha512:`): 422. | R-AP57, R-AP6, R-AP21, R-IK4, R-CV1 to R-CV3, R-AP41 |
| W2 | `toolchains/pu-digest-rules` | `digest` null, 63 hex digits, upper case, `sha512:` drop the asset for its host only. A host with one bad and one good asset gets the good one. 3 rows, 201. | R-AP57, R-AP6, R-PU8, R-PU9, R-CV2, R-CV3, R-SG3 |
| W2 | `toolchains/pu-id-collision` | `nightly-2025-October-25-c3487d2` recorded; the other form `nightly-2025-10-25-c3487d2` gets 422 (1 D1 call, no GitHub call); the first tag again gives 200; a tag with another sha digit is another id (GitHub is read, 404). | R-AP6, R-IK4, R-AP21, R-AP41, R-CV1 |
| W2 | `toolchains/get-query` | 6 rows of 2 nightlies (one Windows asset logged late): no `after`, `after=0`, `after=3`, the largest index, a larger index, `target`, `target` with `after`, a target with no row, an empty `target`, `x64musl`, a `target` with another case (all 200 with no rows), unknown parameters. Exact bodies, headers `max-age=300`, 1 D1 call each. | R-AP5, R-AP47, R-AP41, R-AP44, R-RE4 |
| W2 | `toolchains/get-pages` | 2,500 rows. `json_range` of `log_index` gives each page: 1 to 1000 (more), 1001 to 2000 (more), 2001 to 2500, an empty page after the largest index, 1501 to 2500 (exactly 1000 left: no more), 1500 to 2499 (1001 left: more), a filter, a filter with `after`. The first row is checked in full. | R-AP5, R-AP47, R-AP41, R-AP44 |
| W2 | `toolchains/get-bad-query` | `after` = `abc`, `-1`, empty, `1.5`, `007`, `00`, 2^63, U64 max, a number above U64: 400 with the `detail`; a bad `after` with a good `target`; POST, PUT and DELETE on the list: 405 with `Allow: GET`. 0 D1 calls. | R-AP5, R-AP21, R-AP41, R-AP48 |
| W2 | `toolchains/get-etag-304` | An empty list, with the cache of slice 106: miss (1 D1 call), hit (0), 304 for the ETag, 200 for another ETag, a weak ETag in a list, `*`, `no-cache` (1 call), a 304 after a bypass (1 call), another URL (another key, 1 call), `max-age=0` does not bypass (0 calls). The 304 has no `Content-Type`. | R-AP5, R-AP24, R-AP54, R-AP55, R-AP41 |
| W2 | `runner/r-wh4-json-lists`, 4 self-tests `wrong-json-len`, `wrong-json-at`, `wrong-json-range`, `wrong-json-range-order` | The three new checks of the runner and a wrong value for each | R-WH4, R-AP47 |

### 4.2 Red results (2026-11-01, after the answers of 7.1)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `ToolchainsTest` alone) | 76 expects: 15 passed (the constants, the problem texts, the PUT and 404 rows of `Route.decide`), 61 failed (57 with `todo`, 4 with a wrong value: `GET /v1/toolchains` is `NotFound`, the line of `decide` is not there). 0 compiler errors. |
| W2 `toolchains/*` | 12 of 12 fail. `get-*`: `status: expected 200, got 404` (the route is not in `decide`). `pu-*`: `status: expected 201, got 500` (or 422, 502), `fetch: trap: todo`. |
| W2 `oidc/*` | 6 of 7 fail with `status: expected 200, got 500`, `d1-calls: expected 1, got 0`, `fetch: trap: todo`. `tp3-token-form` passes. |
| W2 `router/*`, `runner/*`, `selftest/*` | All pass with the stubs. The `reads/*` cases (slice 106) are red for their own stubs. |
| `roc fmt --check`, `roc check worker/main.roc` | 0 errors |
| `scripts/test.sh w0` as a whole | Compile state of `ReadsTest.roc` (slice 106) is not checked here. |

### 4.3 Changed cases of slice 108

The slice 108 file says that the 500 rows of the `oidc/*` cases become the answers of slice 109. In 6 cases (`tp7-bot-token-pass`, `tp3-signature-and-kid`, `tp3-key-rotation`, `tp3-jwks-max-age`, `tp3-jwks-upstream`, `tp3-tp7-claims`) each request with a good token now gets 200 with one recorded row. A new `seed.sql` records the tag `nightly-2026-10-31-f7bef6b` (one log leaf and one row). So the route gives 200 with 1 D1 call and no GitHub call, and `expect/github.log` (the JWKS reads) does not change. Only the files `expect/responses.jsonl`, `expect/d1-calls` and `rules` changed. The copies before are in `research/slice-109-revert/before/worker/tests/cases/oidc/`. The cases fail now, and pass with the code.

### 4.4 Revert check (private reference)

`research/slice-109-revert/reference/` fills the stubs and the line of `Route.decide`. `research/slice-109-revert/ref.sh all` copies `worker/` and `packages/` to `refbuild/`, puts the reference over it, and runs W0 and the W2 cases: all 76 W0 expects and all 56 W2 cases (`router`, `runner`, `oidc`, `toolchains`, `selftest`) pass. The reference has the Cache API, the ETag and the weak compare of `list!` as the read routes of slice 106 have them. `MUTATE=mutations/<m>.py ref.sh all toolchains` runs one mutation. Keep the reference until the review is applied. `NOREF=1` builds the stubs.

| Mutation | Caught by |
| --- | --- |
| m1 the read of the tag is ignored (every tag is new) | W2 `pu-digest-kept`, `pu-id-collision`, `pu-new-tag` |
| m2 the leaf time is `published_at` | W2 `pu-new-tag`, `pu-odd-sha-names`, `pu-asset-rules`, `pu-digest-kept`, `pu-id-collision` |
| m3 the first asset of a host wins when there are 2 | W0, W2 `pu-asset-rules` |
| m4 `more` at exactly 1000 rows | W0, W2 `get-pages` |
| m5 `log_index >= after` | W2 `get-pages`, `get-query` |
| m6 the collision check compares a row with itself | W0 |
| m7 the `target` filter is ignored | W2 `get-pages`, `get-query` |
| m8 `.zip` only for `windows_x86_64` | W0, W2 `pu-asset-rules`, `pu-odd-sha-names` |
| m9 no `ORDER BY log_index` (the table is read in key order) | W2 `get-pages`, `get-query` |
| m10 `published_at` in seconds | W0, W2 `pu-*` |

| m11 a leading zero is allowed in `after` | W0, W2 `get-bad-query` |
| m12 a bad `digest` counts for the rule of 2 assets | W0, W2 `pu-digest-rules` |
| m13 `put_status` is always 201 | W0 (the race cannot be made in W2) |
| m14 a draft is a candidate | W0, W2 `pu-not-candidates` |
| m15 `after` above 2^63 - 1 is allowed | W0, W2 `get-bad-query` |
| m16 no weak compare of `If-None-Match` | W2 `get-etag-304` |

Caught 16 of 16 (m1 to m10 were caught before the answers of 7.1, and run again after them). Not covered in W2: the aggregate form of the leaf statement, and a batch that races with another request (W0 `put_status` has the race). The aggregate form differs only when the row exists, and the read of the tag stops that in W2. Slice 103 (`t1`, `t6`) tests the statement forms in W1.

## 5. Output (proposed, TW24)

The design gives the statuses (R-AP5, R-AP6, R-AP21) and the members `toolchains` and `more`. The rest is a proposal.

| Item | Proposal |
| --- | --- |
| A row (`toolchains` items) | `{"tag","target","asset_name","sha256","published_at","log_index"}`, this order, no white space. `sha256` is bare hex (R-RE4; the `sha256:` prefix is only in the leaf). `published_at` is ms (R-AP50). The ids (`nightly`) are not on the wire (R-IK1). `Json.to_str` of a record may order the members otherwise: then the code agent writes the text by hand. |
| `GET` body | `{"toolchains":[...],"more":false}`. `Content-Type: application/json`, `Cache-Control: max-age=300`, `ETag` (the form of slice 106). |
| `PUT` body | `{"toolchains":[...]}`, the rows of the tag in `log_index` order. `Content-Type: application/json`, `Cache-Control: no-store` (R-AP6). |
| Order of the rows of a new tag | The byte order of the target: `linux_arm64`, `linux_x86_64`, `macos_apple_silicon`, `macos_x86_64`, `windows_arm64`, `windows_x86_64`. So the leaves of one tag follow in this order. |
| GitHub call | `GET https://api.github.com/repos/roc-lang/nightlies/releases/tags/{tag}` with the headers `User-Agent` and `Accept: application/vnd.github+json`. R-PU8 names no URL. |

| Case | Status, `type` | `detail` |
| --- | --- | --- |
| No release at GitHub | 404 `not-found` | `roc-lang/nightlies has no release with the tag <tag>` |
| No asset passes | 422 `not-a-candidate` | `the release <tag> has no compiler asset (roc_nightly-<target>-*.tar.gz, or .zip for Windows)` |
| Tag with the id of another recorded tag | 422 `not-a-candidate` | `the tag <tag> has the same nightly id as the recorded tag <other>` |
| GitHub status other than 200 and 404 | 502 `upstream` | `the GitHub release read failed with status <n>` |
| No answer from GitHub | 502 `upstream` | `the GitHub release read failed: no answer` |
| An answer that is not a release | 502 `upstream` | `the GitHub release answer is not a valid release` |
| Bad `after` | 400 `bad-request` | `the query parameter after must be a log index (decimal digits), got <text>` (the same text as slice 106) |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The statement forms and the `RAISE` texts of the write (`leaf-missing`, a used `log_index`) | Slice 103 (W1 `t1`, `t5`, `t6`). A `Constraint` failure of the batch is a `Fault` (500 `internal`, R-SG8 row 7): no W2 case, because the read of the tag stops each way to it. |
| A PUT that races with another PUT of the same tag, in W2 | W2 runs one request at a time. W0 `put_status` has the rule (200 when `changes` is 0, Q109-6). |
| The `Talon-Bookmark` session of the GET (R-AP41 row 5) | Tested by slice 106 (`reads/bookmark-session`). The code of `list!` uses the same function. |
| `--snapshot log:N` (R-AP19), the client cache of the rows (R-AP47), R-CV4 to R-CV6 (exit code 16) | The client track (`tln`, PLAN C.4) |
| R-AP45 (`MIN_TLN`) for the GET | Slice with the setting (110, 112) |
| The sweep use of the rows (R-MX11, R-MX12, `t` of a nightly) | Slices 103 (SQL) and 115 |
| Real GitHub, real D1 | W3, only when the user asks |
| The third release with another sha in the name | The trimmed fixture `tests/fixtures/nightlies/` has two. R-CV2 says 3. |

## 7. Questions (all settled, 2026-11-01: see 7.1)

| Id | Question | Options | Effect now |
| --- | --- | --- | --- |
| Q109-1 | Does `PUT` for a tag that has rows read GitHub? R-AP41 allows "an optional read batch that can stop the request before a GitHub read", R-PU9 says "not written again", R-PU10 says "if GitHub later shows another digest" (this can mean a second GitHub read). | (a) Read D1 first. A tag with rows gives 200 with no GitHub call (1 D1 call). A new tag gives 2 D1 calls. (b) Read GitHub first, then one D1 batch (1 D1 call always). A tag with rows costs a GitHub read, and the 60 calls an hour of a shared address are used. | The cases follow (a): `d1-calls` 2 then 1, and `github.log` has one release read in `pu-new-tag`, `pu-digest-kept`, `pu-id-collision`. (b) changes these 3 cases and the 6 `oidc` cases. Proposal (a). |
| Q109-2 | A tag that is not a nightly tag (no id, `Id.nightly_id` gives `NotANightly`): which answer? | (a) 422 `not-a-candidate`, no D1 and no GitHub call; (b) 400 `bad-request`; (c) 404 `not-found` | No test row. The reference gives 422. |
| Q109-3 | A release with `draft` or `prerelease` true: is it a candidate? CLI R-CV1 says "R-DI3 applies: Talon skips a draft and a prerelease". | (a) 422 `not-a-candidate` for the whole tag; (b) the Worker takes its assets as for any release | No test row. `Release` has the two flags. |
| Q109-4 | An asset whose name counts but whose `digest` is missing, `null`, not `sha256:`, or not 64 hex digits. CLI R-CV4 says an asset with no sha256 stops the install. | (a) The asset is not a candidate on that host (no row, other hosts stay, 422 if none); (b) 422 for the whole tag; (c) 502 | No test row. The reference does (a). |
| Q109-5 | The members of a toolchain row on the wire. R-AP5 says "the rows of R-RE4". | The proposal of section 5 | `put_body`, `page_body` and all W2 bodies use it. Confirm at the review. |
| Q109-6 | The batch wrote nothing because another request wrote the tag between the read and the batch. The last statement then gives the other rows. 201 or 200? | (a) 200 (nothing new from this request: needs `changes` or a compare of `log_index`); (b) 201 (simple) | No test row. |
| Q109-7 | `target` that is empty or not one of the six: 400 or an empty list? An `after` in the range above I64 max and up to U64 max: 400, or an empty page? A future `target` of roc would give a 400 with (a). | (a) 400 for a `target` that is empty or unknown; (b) 200 with the rows of that text (an unknown target has none); `after` above I64 max: (a) 400, (b) 200 empty | No test row for these. `parse_query` accepts any text for `target`. |
| Q109-8 | `published_at` of GitHub with an offset other than `Z`: read, or `BadRelease`? | GitHub sends `Z`. | No test row. |
| Q109-9 | Does `GET /v1/toolchains` use the read mechanism of slice 106 (Cache API, bookmark, ETag, 304)? R-AP5 says `max-age=300`, ETag; R-AP43 says every `GET` route. | Yes, with `max-age=300`. The ETag form is `etag_of` of slice 106. | `get-etag-304` checks the ETag as the first 16 bytes of the SHA-256 of the body in hex, in quotes (python, not Roc). It is red until slice 106 has the form. If 106 changes the form, this case changes. |

### 7.1 Answers (design agent, 2026-11-01)

| Id | Answer | Design |
| --- | --- | --- |
| Q109-1 | (a): D1 first. A tag with rows gives 200 with no GitHub call (1 D1 call). A new tag gives 2 D1 calls. | Registry R-AP57 step 2, Design Q98 |
| Q109-2 | (a): 422 `not-a-candidate`, no D1 call and no GitHub call | R-AP57 step 1, Q99 |
| Q109-3 | (a): 422 `not-a-candidate` for the whole tag | R-AP57 step 4, Q100 |
| Q109-4 | (a): the asset is not an asset for its host. A valid `digest` is `sha256:` and 64 lower-case hex digits. | R-AP57 step 6, Q101 |
| Q109-5 | As proposed: `{tag, target, asset_name, sha256, published_at, log_index}`, bare lower-case hex, ms | R-AP49 (Toolchain rows), Q102 |
| Q109-6 | (a): 200. 201 only when a `toolchains` statement of the batch has `changes` above 0 (`D1.Result` info, `cloudflare-workers/MODULES.md` 5.1) | R-AP57 step 7, Q103 |
| Q109-7 | `target`: (b), 200 with no rows for an empty or unknown text. `after`: (a), 400 above 2^63 - 1, and also for a leading zero (`007`), as slice 106 | R-AP56, Q95, Q104 |
| Q109-8 | Only `YYYY-MM-DDTHH:MM:SSZ`. Another form: the answer is not a release, 502 `upstream`. | R-AP57 step 5, Q105 |
| Q109-9 | Yes: the Cache API, the bookmark, the ETag and the 304 of slice 106, with `max-age=300`. The ETag form is R-AP54 (one decision for both slices). | R-AP54, R-AP55, Q96 |

Section 5 (TW24): the row members are design (R-AP49). The order of the rows of a new tag (byte order of the target) and the GitHub URL are in R-AP57. The `detail` texts stay proposals for the human review (accepted as written).

Test changes (done by the test agent, 2026-11-01):

| # | Change | Why |
| --- | --- | --- |
| T1 (done) | `ToolchainsTest.roc` `parse_query`: the good row `18446744073709551615` becomes a bad row (400). Add bad rows `9223372036854775808`, `007`, `00`, and a good row `9223372036854775807`. | Q109-7, Q95 |
| T2 (done, and the optional rows are required now) | Optional W0 rows: a tag with no nightly id, a draft and a prerelease release (Q109-2, Q109-3), an asset with a `digest` of 63 hex digits or upper case (Q109-4), `parse_time` with `+00:00` (Q109-8). Optional W2: `target=` and `target=x64musl` give 200 with no rows (Q109-7). | No test now |
| T3 (done) | Doc comments of the stubs that name these questions: change them to the answers. No signature change. | |

## 8. Platform issues

| # | Issue | Evidence |
| --- | --- | --- |
| P1 | `targets` is a keyword of Roc: a function or a field with this name does not parse (`expr_unexpected_token, at token KwTargets`). The name is natural for this domain. | First `roc fmt` of `Toolchains.roc` |
| P2 | The derived JSON reader cannot read `null` (see `packages/records/Nullable.roc`). GitHub gives `"digest": null` for old assets, so `parse_release` needs more than `Json.parse`. The reference replaces the text `"digest":null` before the parse. A reader with an optional-or-null member would help. | `ToolchainsTest.roc` `release_text` |
| P3 | `roc build` exits non-zero for a warning (an unused variable) although it writes `app.wasm`. A mutation that leaves a variable unused looks like a build failure. | `research/slice-109-revert/ref.sh`, mutation m2 first try |
| P4 | Miniflare gives each case a Cache API. The cases avoid it with `no-cache` (section 6). Whether a repeated GET without `no-cache` gives a cache hit with 0 D1 calls is slice 106. | |

## 9. Files

| File | Kind | Lines |
| --- | --- | --- |
| `worker/lib/Toolchains.roc` | New, code (stubs filled) | 328 |
| `worker/ToolchainRoutes.roc` | New, code (stubs filled) | 167 |
| `worker/tests/unit/ToolchainsTest.roc` | New, W0 | 305 |
| `worker/tests/cases/toolchains/` | New: 12 W2 cases | |
| `worker/tests/cases/runner/r-wh4-json-lists/`, `worker/tests/selftest/wrong-json-*` (4) | New | |
| `worker/lib/Route.roc` | Changed: `GetToolchains` in `Route.Id` (one word), and the comment | |
| `worker/main.roc` | Changed: `import ToolchainRoutes`, 2 arms in `run!` | |
| `worker/lib/main.roc`, `worker/tests/unit/w0.roc` | Changed: one word each | |
| `worker/tests/run.mjs` | Changed: the three checks (about 16 lines) | |
| `worker/tests/worker-test.js` | Changed: the test path `/__test/rows` (one line) | |
| `worker/tests/cases/oidc/*` | Changed: section 4.3 | |
| `research/slice-109-revert/` | `before/` (the copies, `NEW.txt`), `reference/`, `mutations/`, `ref.sh`, `mk_cases.py` | |

## 10. Disputes (from the code agent)

None. No test, case or fixture was changed.

## 11. Verify results (code agent, 2026-11-01)

| Item | Result |
| --- | --- |
| `scripts/test.sh w0 w1 w2 check fmt` | All pass: w0 2.0 s, w1 5.9 s, w2 24.0 s (all cases, also `reads/*` after slice 106 landed), check 3.1 s, fmt 0.3 s |
| W0 `ToolchainsTest` | 76 of 76 `expect`s pass |
| `MISSING=1 scripts/rules.sh R-AP R-PU` | R-AP5, R-AP6, R-AP21, R-AP24, R-AP41, R-AP44, R-AP47, R-AP48, R-AP49, R-AP50, R-AP54 to R-AP57, R-PU7 to R-PU10 are not in the list of rules with no test. The rules that still have no test belong to other slices. |
| Files | `worker/lib/Toolchains.roc` 328 lines, `worker/ToolchainRoutes.roc` 167 lines, `worker/lib/Route.roc` +1 line (`["v1", "toolchains"] => decide_get(input, path, GetToolchains)`) and the comment of `Id`. `worker/main.roc` is not changed: the slice 108 arm already calls `ToolchainRoutes.put!` after `Auth.bot!`. |
| Revert check | Not run. The task did not ask for it. The test agent ran 16 mutations on the private reference (section 4.4). |

Decisions of the code agent that the slice does not fix:

| Decision | Rejected option |
| --- | --- |
| `list!` uses the pure functions of `lib/Reads.roc` (`bypass_cache`, `session_of`, `etag_of`, `etag_matches`) and has its own `conditional` and cache steps in `ToolchainRoutes.roc`. `ReadRoutes.Error` is not used: `ToolchainRoutes.Error` has the same form. | Wait for a shared `read_answer` helper in `ReadRoutes`. Move the cache steps into one shared function when slice 106 has one. |
| `put_body` and `page_body` write each row by hand, with `Json.to_str` for the texts. | `Json.to_str` of a record: it writes the members in the order of their names, not the order of R-AP49. |
| `parse_release` replaces the text `"digest":null` (and `"digest": null`) with an unknown member before `Json.parse` (platform note P2). | A reader with an optional-or-null member: not in the platform. |
| `parse_time`, the date helpers, are local to `Toolchains` (a small copy of the date code of `records.Id`). | Call the private helpers of `records.Id`. |
| The nightly id binds as `I64` (a number below 2^53, text above). | An explicit `Id64`: same result for these ids. |

Platform notes for this slice:

| # | Note |
| --- | --- |
| P5 | `Json.to_str` of a record orders the members by name (`asset_name`, `log_index`, `published_at`, ...). A wire form with another member order needs text built by hand. |
| P6 | A tuple of 8 SQL parameters (`Sql.stmt`) encodes and binds without a problem. |
| P7 | A run of `scripts/test.sh w2` at the same time as another agent can use an `app.wasm` that the other agent built (the file is shared in `worker/`). One run failed with `fetch: trap: todo` for this reason, and the next run passed. |
