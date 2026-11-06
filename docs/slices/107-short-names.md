# 107 Short names and search

Phase: P2. Status: review (scope and red tests, 2026-11-02; questions answered, test changes open, section 10.1). Model for the code: Sonnet medium. Plan row: `docs/registry/PLAN.md` C.1, row 107.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-107-revert/reference/` (the private reference).

## 1. Scope

One route, two forms, one D1 call each, in a read session, with the ETag, the 304 and the Cache API of slice 106.

| Form | Rule | Answer | `Cache-Control` |
| --- | --- | --- | --- |
| `GET /v1/packages?short=<name>[&short=<name>...]` | R-AP7, R-SN1 | `{matches}`: one entry for each `short` value | `max-age=60` |
| `GET /v1/packages?q=<text>` | R-AP7, R-SN5 | `{packages}`: at most 20, ranked, for display only | `max-age=300` |

| Part | Who | State |
| --- | --- | --- |
| Frame: `worker/lib/Shorts.roc` (pure, signatures, stub bodies), `worker/ShortRoutes.roc` (signature, stub body) | Test agent | Done. The code agent does not change a signature or a type (TW18). |
| Route row `GetPackages` in `worker/lib/Route.roc` (1 tag, 1 arm) and the arm of `run!` in `worker/main.roc` (with `import ShortRoutes`) | Test agent | Done. They are code, not stubs: do not remove them. |
| Header entries: `Shorts` in `exposes` of `worker/lib/main.roc`, `import ShortsTest` in `worker/tests/unit/w0.roc` | Test agent | Done |
| Tests: `worker/tests/unit/ShortsTest.roc` (W0), `worker/tests/cases/shorts/` (W2, 5 cases) | Test agent | Red (section 5.1) |
| Bodies of `Shorts` and `ShortRoutes` | Code agent | To do |

Size: the private reference has about 190 lines of code in `Shorts` and about 90 in `ShortRoutes` (without blank and comment lines). Below the 400 of TW19.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP7 | The route, the two forms, 200, 304, 400, 413, the `Cache-Control` of each form | W0 route rows, `parse_url`. W2 all 5 cases |
| R-SN1 | The match set: the repo name, or the repo name minus a leading `roc-`; ASCII case-insensitive; sorted by `name`; not cut; an empty list is no match. The 4 rows of the table | W0 `short_keys`, `is_match`, `entries_of` (table). W2 `sn1-table`, `sn2-members` |
| R-SN2 | An indexed package has at least one release: also yanked, withdrawn, and a name in the state `missing`. The example (`roc-parser` deleted, `someone/parser` new: 2 matches). A repo with no release does not count | W0 `entries_of`. W2 `sn1-table` (the example as a sequence of requests), `sn2-members` (yanked, withdrawn, `c/ghost`) |
| R-SN3 | A package on another host never matches | W2 `sn1-table` (releases of `example.com` and `gitlab.com` groups, `repo` NULL). No name in the schema: no code needed except that the SQL reads `names` of kind 3 |
| R-SN4 | `first_log_index` is the smallest log index of the releases of the name | W2 `sn1-table`, `sn2-members` (`f/multi`: logs 9 and 3 give 3), `ap33-moved`. W0 `entries_of` |
| R-SN5 | At most 20 packages, ranked by a text match on the name, display only | W0 `rank`, `search_body`. W2 `sn5-search`. The ranking itself: question Q107-6 |
| R-AP33 | A `moved` name is replaced by the end of its chain, with `moved_from`. The end once. `state` of the end | W0 `chain_end`, `entries_of`, `matches_body`. W2 `ap33-moved`, `sn1-table` |
| R-TP11 | The states `active`, `missing`, `moved` | W0 `state_of_code`, `state_text`. W2 `sn1-table`, `ap33-moved` |
| R-TP14 | The chain of up to 4 links. A cycle stops it | W0 `chain_end` (0, 1, 4 links, cycle). W2 `ap33-moved` (`lone`, 4 links). More than 4 links and where a cycle stops: Q107-2 |
| R-AP46 | 50 `short` values are good. 51 give 413 `too-large` with `field` and `limit`, before every 400 and before any D1 call | W0 `parse_url`, `too_large_json`. W2 `ap46-limits` |
| R-AP48 | The order of the checks: 404, 405 (`Allow: GET`), 413 (row 4), 400 (row 6). All before D1 | W0 route rows. W2 `ap46-limits` (d1 count 0 on each) |
| R-AP41 | 1 D1 call for each answer that reads D1, in a session (`Reads.session_of`). The successor chain in one recursive CTE | W2 d1-calls in every case |
| R-AP43, R-AP54, R-AP55 | Cache API of the colo, ETag, `If-None-Match`, `no-cache` bypass. A refused request puts nothing | W2 `sn1-table` (hit with count 0, 304), `sn5-search` (304, `no-cache` with count 1), `ap46-limits` (413 twice, count 0) |
| R-AP44 | An unknown query parameter is ignored | W0 `parse_url`. W2 `sn1-table` (`&n=1`), `sn5-search` (`&unknown=1`) |
| R-AP21 | Problem form for 400, 404, 405, 413 | W0 problems. W2 `ap46-limits` |
| R-AP53 | One state gives one body: the order of the lists is fixed | W0 `matches_body`. W2 exact bodies and ETags |

Design refs: Registry 4.3, 4.2 (R-AP7, R-AP21, R-AP41 to R-AP48, R-AP53 to R-AP56), 7.3 (R-TP11, R-TP14); CLI 2 (R-SC8, R-AD3 to R-AD7, R-AD34). Slice 106 for the read flow.

## 3. What the code agent writes

### 3.1 Files

| File | Item |
| --- | --- |
| `worker/lib/Shorts.roc` | The bodies of the stubs. Pure. The doc comment of each stub is the rule. |
| `worker/ShortRoutes.roc` | The body of `list!`. It returns `Try(Response, ReadRoutes.Error)`. |
| `worker/main.roc`, `worker/lib/Route.roc` | Nothing. The rows are in place. |
| `sql/queries/*.sql` (optional) | The SQL texts. There is no W1 case: W2 runs them on the real schema. |

### 3.2 The flow of `list!`

| # | Step |
| --- | --- |
| 1 | `Shorts.parse_url(req.url())`. `Err(Bad(problem))` is `Err(Refuse(problem))`. `Err(TooMany(count))` is `Ok(Response)` with status 413, `content-type: application/problem+json` and the body `Shorts.too_large_json(count)`. No D1 call, no Cache API read, no put. |
| 2 | Cache key `req.url()`. `Reads.bypass_cache` of the headers `cache-control` and `pragma`. When false: `Cache.default.get!(key)`; a hit is the answer (no D1 call). |
| 3 | A miss or a bypass: `db.with_session!(Reads.session_of(req.header("talon-bookmark")))`, then one `batch!` of one statement. |
| 4 | `Short`: rows of `Shorts.Row`, `Shorts.entries_of(values, rows)`, `Shorts.matches_body`. `Search`: rows of `Shorts.SearchRow`, `Shorts.search_body(text, rows)`. A 200 answer with `content-type: application/json`, `cache-control` of the form (section 1), `etag: Reads.etag_of(bytes)`. Into the Cache API with `Cache.default.put!` (use the response that it gives). An empty list is 200. |
| 5 | `If-None-Match` against the `etag`, also for a hit: `Reads.etag_matches`. A match is 304 with no body and the headers `etag` and `cache-control` of the form (not 60 for `q`). |

`ReadRoutes.serve!` has a fixed `cache-control` of `max-age=60`, and I may not edit `ReadRoutes.roc`. So `ShortRoutes` has its own copy of the flow with the `cache-control` as a parameter (about 30 lines). If the manager makes `ReadRoutes.serve!` take the `cache-control`, `ShortRoutes` can use it (Q107-8).

### 3.3 SQL notes

| # | Fact | Effect |
| --- | --- | --- |
| 1 | The `short` values go as one JSON parameter and are read with `json_each(?1)` (R-AP41 row 2). Lower-case them with `with_ascii_lowercased` before. SQLite `lower()` is ASCII only: it matches the rule. | R-SN1 |
| 2 | The repo part of a name is the text after the first `/` of `names.value` (kind 3, lower case by R-IK2). A name matches when the repo part is the value, or when it starts with `roc-`, is longer than 4 bytes, and the rest is the value. | R-SN1 |
| 3 | A name with no release is not a match (`EXISTS` on `releases.repo`), but it can be on a chain. `first_log_index` is `min(releases.log_index)` and is NULL when none: it reads into `Try(U64, [Missing])`. | R-SN2, R-SN4 |
| 4 | The chain is a recursive CTE over `repos.successor` where `state = 2`. A cycle in data must end: bound the depth (the reference uses depth below 5) and use `SELECT DISTINCT`. The pure `chain_end` decides the end, so the CTE may give a superset. | R-AP41 row 1, R-TP14 |
| 5 | Nullable columns read into `Try(a, [Missing])`. A BLOB is not used here. Ids are 64 bits: never read them into a number type that loses digits; the rows here use names (text), not ids. | |
| 6 | `?q=` reads the indexed names and ranks in Roc (the reference reads all of them; a `LIKE` prefilter is allowed if it keeps the rule of `rank`). | R-SN5 |
| 7 | The platform `Request.query` gives only the first value of a name, so `parse_url` reads the whole URL (the percent-decoding and the `+` rule are those of `Request.query`). | R-SN1 |

### 3.4 Public signatures

They are in the two stubs. Summary:

| Module | Items |
| --- | --- |
| `Shorts` | `short_limit`, `search_limit`, `short_cache_control`, `search_cache_control`, `Query`, `Refusal`, `parse_url`, `too_large_json`, `short_keys`, `is_match`, `State`, `state_text`, `state_of_code`, `Row`, `Item`, `Entry`, `chain_end`, `entries_of`, `matches_body`, `SearchRow`, `rank`, `search_body` |
| `ShortRoutes` | `list!` |

## 4. Wire forms (the bytes that the ETag covers)

| Body | Text |
| --- | --- |
| `?short=` | `{"matches":[<entry>,...]}`. An entry: `{"matches":[<item>,...],"short":"<value as sent, decoded>"}`, one for each `short` parameter, in the order of the URL, also for equal values. An item: `{"first_log_index":N,"moved_from":"..","name":"..","state":".."}`, with `moved_from` only for a replaced name (R-AP33; R-AP51: an optional member is left out). |
| `?q=` | `{"packages":[<item>,...]}`. An item: `{"first_log_index":N,"name":"..","state":".."}`. No package: `{"packages":[]}` |
| 413 | A problem (R-AP21) with `field: "short"` and `limit: 50`; `detail`: `the query has <count> short values, the limit is 50` |

No white space. Members in alphabetical order. Text escaped as JSON text. Items sorted by `name` (bytes).

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `ShortsTest.roc`, 53 `expect`s (over the 20 of the budget: 4 route rows, 16 query rows, the 413 body, the keys and the match table, the chain, 12 match-set groups, bodies, 12 search rows). The route rows (4 `expect`s) are green now: the arm is in place. | R-AP7, R-AP21, R-AP33, R-AP44, R-AP46, R-AP48, R-SN1, R-SN2, R-SN4, R-SN5, R-SN6, R-SN7, R-SN8, R-SN9, R-SN10, R-TP11, R-TP14 |
| W2 | `shorts/sn1-table` (10 lines): `parser`, again (count 0), `roc-parser`, `pars`; `someone/parser` added (a `{"sql"}` line, RR1): `Parser` gives both; `roc-parser` set to `missing` and its release withdrawn: `parser&n=1` gives both (the example of R-SN2); 4 values in one request; the same with an equal `If-None-Match` (304, count 0). The world has releases of two other hosts. | R-AP7, R-SN1 to R-SN4, R-AP33, R-AP43, R-AP44, R-AP54 |
| W2 | `shorts/sn2-members`: a yanked name, a withdrawn name, a repo with no release, `roc-roc-x`, `rocx`, a name with releases in 2 groups (logs 9 and 3), `roc-` as a repo name, a full name as a value, upper case values, percent-encoded values | R-SN1, R-SN2, R-SN4 |
| W2 | `shorts/ap33-moved`: `json` (old and new in the set: once, with `moved_from`), a chain of 3 links through names that have no match, a chain of exactly 4 links, a chain of 5 links (cut, state `moved`), a cycle, a name that is its own successor, a moved name whose end is `missing`, the old name with the smaller index (R-SN9), an end with no release, 2 old names for 1 end, sorting by the name of the item, a moved name with no release (no match), then all 12 values in one request | R-AP33, R-SN1, R-SN2, R-SN4, R-SN8, R-SN9, R-TP11, R-TP14 |
| W2 | `shorts/ap46-limits`: 50 values (200); 51 (413 twice, count 0); 51 with an empty value (413); no parameter, an unknown parameter, `short` with `q`, `short=`, `q=`, `q` twice (400, R-SN7); POST, PUT, DELETE (405, `allow: GET`); `/v1/packages/x` (404). All count 0 except the first. | R-AP46, R-AP48, R-SN7, R-AP21, R-AP7 |
| W2 | `shorts/sn5-search`: `q=ranked` with exact body and ETag (an exact name first, a moved name not replaced and with state `moved`, then 18 prefix names by bytes, the substring and the no-match names out, cut to 20); again (count 0); upper case text; `roc-ranked`; an empty result with exact body and ETag; 304 (count 0); 304 with `no-cache` (count 1); `max-age=300` | R-SN5, R-SN6, R-SN10, R-AP7, R-AP43, R-AP54 |

All W2 expected texts are made by `research/slice-107-revert/gen/gen.py` with python (the ids, the version keys, the SHA-256 of the ETag, the match rule), not with Roc.

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| `roc check` | `worker/main.roc` and `worker/tests/unit/w0.roc`: no errors, no warnings |
| `roc fmt --check` | The new and changed Roc files pass |
| `scripts/test.sh w0` (the `ShortsTest.roc` part) | 53 `expect`s: 4 pass (the route rows), 49 fail with `todo`. The other failures of the step belong to slices 109 and 110. |
| `node worker/tests/run.mjs shorts` (a build of a copy with the stubs: `research/slice-107-revert/reference/red.sh shorts`) | 5 cases, 0 pass. All fail with `status: expected 200 (or 400, 413, 405, 404), got 500` and `fetch: trap: todo` |
| Old cases | The route row only adds a tag and an arm. `roc check worker/main.roc` has no error. The W2 cases of other slices were not changed. |

### 5.2 Private reference and revert check

`research/slice-107-revert/reference/` (`overlay/` has the two modules, `run-ref.sh` builds a copy of `worker/` with them and runs the cases, `mutate.sh` is the revert check, `red.sh` is the red run). With the reference: 53 of 53 W0 `expect`s, 5 of 5 W2 cases (re-made after the answers, 2026-11-02). 10 mutations of the reference were run (user rule: the tricky ones).

| Mutation | What | Caught by |
| --- | --- | --- |
| `strip-twice` | The key drops `roc-` twice | W0 `short_keys`, `is_match` |
| `missing-out` | A name in the state `missing` is left out | W0 `entries_of` (R-SN2) |
| `first-end` | `first_log_index` is that of the end only | W0 `entries_of` (R-SN9) |
| `moved-keep` | A moved name is not replaced | W0 `entries_of` |
| `chain-3` | The chain stops at 3 links | W0 `chain_end` |
| `no-dedup` | The end is twice in the set | W0 `entries_of` |
| `unsorted` | Items in the order of the old names | W0 `entries_of` |
| `first-max` | `first_log_index` is the largest log index (SQL) | W2 `sn1-table`, `sn2-members` (W0 passes: it does not see SQL) |
| `q-repeat` | `q` twice is good | W0 `parse_url` |
| `rank-rev` | Rank 3 before rank 1 | W0 `rank`, `search_body` |

## 6. Output (proposed, TW24)

The design gives the route, the item members of R-SN1 and R-AP33 and the limits. It does not give these. They are proposals for the human.

| Item | Proposal |
| --- | --- |
| `matches` shape | A list of entries `{short, matches}`, one for each `short` value in the order of the URL (R-AD34 says "the `matches` list" and one request holds all short names of a command). The `short` is the value as sent, decoded. Equal values give two entries. |
| Item members | `first_log_index`, `name`, `state` (`active`, `missing`, `moved`) and, for a replaced name, `moved_from`. `moved_from` is left out when there is none (R-AP51). `state` is the state of the end of the chain for a replaced name. |
| `packages` item of `?q=` | `first_log_index`, `name`, `state` (the same as an item of `matches`, no `moved_from`; a moved name is not replaced: display only) |
| Repeated parameter | Several values are the repeated parameter: `short=a&short=b` (Q107-1) |
| An empty `short` value | Counts for the limit of 50 (it is a `short` parameter) |
| 413 `detail` | `the query has <count> short values, the limit is 50`. `field`: `short`. `limit`: 50. |
| 400 `detail` | `GET /v1/packages needs the query parameter short or q` |
| Order | Items sorted by the `name` of the item (bytes), after the replace. Entries in the order of the URL. |
| Empty answers | `{"matches":[{"matches":[],"short":"pars"}]}` for no match. `{"packages":[]}` for no package. Both 200. |

## 7. Runner

No change. The cases use RR1 (a `{"sql": [...]}` line), RR3 (`force-cache`) and the `json_len`, `json_at` checks, all in `worker/tests/run.mjs` now. No W2 case checks the session argument (RR2): `Reads.session_of` is the same helper as in slice 106, tested there.

## 8. Platform notes

| # | Note |
| --- | --- |
| P1 | `Request.query` gives only the first value of a name (`cloudflare-workers/platform/Request.roc`). The route needs all `short` values, so `Shorts.parse_url` decodes the URL itself. A platform function `Request.query_all` would remove about 40 lines (a request to the platform owner, not needed now). |
| P2 | `Problem.to_json` has no `field` and `limit`. Slice 110 plans to extend it (the doc comment of `ClosureQuery.parse`). This slice does not depend on it: `Shorts.too_large_json` writes the whole body. The code agent may use the extended `Problem` if it is there, with the same members. W0 checks the parts of the text, not the order. |
| P3 | `roc build` exits with 2 when it has a warning. Leave no warning (an unused import in `ShortRoutes` is one). |

## 9. Out of scope

| Item | Reason |
| --- | --- |
| The ranking of `?q=` | Question Q107-6. Only the cap, the determinism and the empty result are tested. |
| `Talon-Bookmark` for this route (R-AP41 row 5) | The same `Reads.session_of` as slice 106 (`bookmark-session`). The session argument cannot be seen in W2 without a case like that one. |
| The purge of the Cache API at a publish | Slice 112 |
| The `tln` side: R-AD3 to R-AD7, R-AD34, `--snapshot log:N` hiding (R-SN4) | CLI slices (`cli/`). This slice gives `first_log_index`. |
| `max-age` expiry | The Cache API uses the real clock of workerd (as slice 106) |
| A yanked flag in the answer | Not in R-SN1. A yanked release counts as a release only. |

## 10. Questions (stop until answered)

Answered by the design agent on 2026-11-02 (column "Answer"; Design 9, Q107 to Q113; Registry 4.3, R-SN6 to R-SN10). The column "Tests" is the state before the answers: section 10.1 lists the changes. The test agent makes them before the code agent starts.

| Id | Question | Proposal | Tests | Answer |
| --- | --- | --- | --- | --- |
| Q107-1 | What is the query form of several `short` values? R-SN1 says "up to 50 `short` values" and does not show the form. | The repeated parameter `short=a&short=b` | All W2 and W0 `parse_url` rows with 2 or more values | Taken. Repeated parameter. Design Q107, Registry R-SN6. Shape of `matches` and item members: also R-SN6. |
| Q107-2 | The end of a chain that has a cycle or more than 4 links. R-TP14 gives 4 links to the client. Does the Worker follow the whole chain, or stop at 4? R-AP33 says "the end of its successor chain". | The Worker stops at 4 links and at a cycle, with the same walk as the client. The end is the last name reached (after 4 links; or the name before the one that closes the cycle). Its `state` can be `moved`. | W0: 0, 1, 4 links; a cycle gives a name of the cycle. W2: 4 links. Not tested: more than 4 links, which name of a cycle. | Changed. The Worker uses the walk of the client: at most 4 links, stop before a name already on the walk. The end has its own `state` (`moved` = cut chain or cycle). Design Q109, Registry R-SN8, R-TP14. |
| Q107-3 | A request with `short` and `q`; an empty `short` value (`short=`); an empty `q`? | 400 `bad-request` for each | none. (No `short` and no `q` is 400 by R-AP7 and is tested.) | Taken. 400 for each, after 404, 405, 413, before D1. Design Q108, Registry R-SN7. |
| Q107-4 | `first_log_index` of a replaced item. R-SN4: the smallest log index of the releases of "that name". The end can have no release yet. | The `first_log_index` of the end. When the end has no release: the smallest of the old names that it replaces. | The W2 and W0 rows are made so that "the end", and "the smallest of the end and the old name" give one value. A no-release end: none. | Changed. `first_log_index` is the smallest log index of the end and of each name it replaces in the entry (never NULL). Design Q110, Registry R-SN9, R-SN4. |
| Q107-5 | `moved_from` when the end is also in the set (R-AP33 says "the set has it once")? When 2 old names give one end? | `moved_from` stays. With 2 old names: the smaller by bytes. | `json` in W2 `ap33-moved` and W0 (the end in the set, 1 old name). Two old names: none. | Taken. `moved_from` stays; with 2 old names, the smaller by bytes. Design Q111, Registry R-SN9. |
| Q107-6 | What is "a text match on the name" (R-SN5)? Case, substring, prefix, fuzzy, the repo part or the whole name, and the tie order. | The reference ranks: a name that contains the text first (shorter name first), then by the count of characters in common, ties by name. This is only a proposal. | none for the order. W0 and W2: at most 20, one list for one input, a name with nothing in common is not in the list, an empty result. | Changed. Rank 1 exact, 2 prefix, 3 substring (on the name, repo part or part without `roc-`), ASCII case-insensitive; then name by bytes; cut to 20; no fuzzy. Design Q112, Registry R-SN10. |
| Q107-7 | The members of an item of `packages` (R-AP7 gives none). | `first_log_index`, `name`, `state`, as in section 4 | W0 `search_body` (exact text). W2 only counts. | Taken. `first_log_index`, `name`, `state`; no `moved_from`. Design Q113, Registry R-SN6. |
| Q107-8 | `ReadRoutes.serve!` has a fixed `max-age=60`. May `ReadRoutes` take the `cache-control` as a parameter, so that `ShortRoutes` does not copy the flow? | Yes, in a later cleanup (the manager). Now `ShortRoutes` has its own copy. | none | Manager decision. The code agent may change `ReadRoutes.serve!` to take the max age as an argument (a narrow edit), in place of a copy of the flow. Not a design question. |

### 10.1 Test changes after the answers (test agent; changes 1 to 6 and the row for a repeated `q` are done, 2026-11-02)

Proposed texts of the new 400 `detail` (TW24, `Shorts.parse_url` doc comment): `the query parameters short and q must not be used together`; `the query parameter short must not be empty`; `the query parameter q must not be given more than once`; `the query parameter q must not be empty`. The check order is that list. Stub signature for the Q107-8 edit (not made here): `ReadRoutes.serve! : Request, Str, List(Sql.Stmt), (List(D1.Result), U64 -> Try(Str, ReadRoutes.Error)) => Try(Response, ReadRoutes.Error)` with the new `Str` (the `cache-control`) after the request.

| # | Test | Change | Rule |
| --- | --- | --- | --- |
| 1 | W0 `ShortsTest.roc` `rank`, `search_body`; W2 `sn5-search` (gen.py) | The reference rank (contains, then characters in common) is gone. New rule: rank 1 exact (name, repo part or part without `roc-` equals the text), 2 prefix, 3 substring of the name, ASCII case-insensitive, then name by bytes, cut to 20. Add `expect`s for each rank and the tie order. A name with no substring is not in the list (also when it has characters in common). The 25 names and the 20 of the answer: re-make with the new order. | R-SN10 |
| 2 | W0 `entries_of`, W2 `ap33-moved` | `first_log_index` of a replaced item is the minimum of the end and of the replaced names in the entry. Add a row where the old name has the smaller index than the end (the item gets the old index), and a row where the end has no release (the old index; the item is there). The rows that made "end" and "min" equal stay. | R-SN9 |
| 3 | W0 `entries_of` | Add: 2 old names, 1 end: one item, `moved_from` is the smaller name by bytes, `first_log_index` is the minimum of the three. The end in the set and replaced: `moved_from` stays, the item is once. | R-SN9, R-AP33 |
| 4 | W0 `chain_end` | Add: 5 links gives the name after 4 links, with the `moved` state; A to B to A from A gives B; A to B to C to A from A gives C; a successor equal to the name is not a replace (the item is the name, `moved`, no `moved_from`); an end that is `missing` stops the walk. The W2 case of exactly 4 links stays. | R-SN8 |
| 5 | W0 `parse_url`, W2 `ap46-limits` | Add (400): `short` with `q`; `short=`; `q=`; and 51 values with an empty one is 413 (stays). The 400 checks come after 404, 405, 413 and before D1 (count 0). | R-SN7, R-AP48 |
| 6 | W0 `matches_body`, `search_body` | Check the entry shape `{"matches":[...],"short":"<as sent, decoded>"}`, equal values give 2 entries in the URL order, the `short` value is not made lower case, and an empty answer. No change if these are there already. | R-SN6 |

### 10.2 Notes for the code agent

| # | Note |
| --- | --- |
| 1 | Q107-8: the manager decides. The code agent may change `ReadRoutes.serve!` to take the max age as an argument (a narrow edit), in place of a copy of the flow in `ShortRoutes`. Slice 106 tests must stay green. |
| 2 | 413 body with `field` and `limit` (R-AP46): the code agent may add optional members to `worker/lib/Problem.roc` `to_json`, in place of the body written in `Shorts.too_large_json`. This is not designed here. |
| 3 | A repeated `q` is 400 (R-SN7, added by the manager). Tested. |

## 11. Disputes (from the code agent)

| Id | Test or frame | Problem | Proposal |
| --- | --- | --- | --- |
| | | | |

## 12. Verify results (code agent, 2026-11-02)

| Check | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| W0 (`ShortsTest.roc`, 53 `expect`s) | pass. The 34 failures of the step are in `ArchiveReadTest.roc` (slice 111, red) |
| W2 `shorts` | 5 of 5 pass (`ap33-moved`, `ap46-limits`, `sn1-table`, `sn2-members`, `sn5-search`) |
| W2 `reads` 12, `toolchains` 12, `oidc` 7 | all pass (run with `node worker/tests/run.mjs <group>`, `W2_DIR` set to the build) |
| W2 `router` | 9 of 10. `r-ap23-no-body` posts to `/v1/closure` (slice 110, red). `scripts/test.sh w2` stops at the `archive` cases: `archive-test.wasm` is missing (slice 111) |
| `scripts/rules.sh R-SN R-AP` | R-SN1 to R-SN10 all have tests. R-AP with no test (not in this slice): R-AP11, R-AP12, R-AP22, R-AP25, R-AP27, R-AP30, R-AP31, R-AP34 to R-AP40, R-AP65 |

Decisions: Q107-8 done. `ReadRoutes.serve!` takes the `Cache-Control` text after the request (4 callers changed, `ToolchainRoutes` does not call it). `Problem.to_json_with(problem, { field, limit })` added for the 413 body (slice 110 can use it); `Shorts.too_large_json` calls it. `Shorts` has its own copy of the query decode (P1). The SQL of `?q=` filters with `instr(name, text)` (names are lower case, R-IK2). No test changed, no dispute. No revert check run (not asked).
