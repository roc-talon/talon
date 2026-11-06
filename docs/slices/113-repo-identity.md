# 113 Repository identity

Phase: P2. Status: review (scope and red tests 2026-11-02; the questions of section 7 answered 2026-11-02, section 7.1; the tests changed for the answers, T1 to T7 done, section 7.2). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 113. Depends on slice 112 (the ingest: its GitHub reads, its D1 batch, the `repos`, `repo_checks` rows of R-TP5 and R-PU26).

## 1. Scope and split

The ingest of slice 112 reads `GET /repos/{owner}/{repo}` and writes the `repos` row of a new name. Slice 113 adds what R-TP9 to R-TP13, R-TP18 and R-TP19 say for that read: the ids of the read against the row, the 403, the states, the renames, and the `repo_events` rows.

| Item | In 113 | Where |
| --- | --- | --- |
| The 4 rows of R-TP9 for an ingest (a new release, and a label that has the hash and no `ingest` row) | Yes | `lib/Identity.roc` `decide` (W0), the flow in `IngestRoutes.roc` (W2) |
| The same rows for a publish (slice 114), a webhook (118), a reconcile (119) | The pure decision only. They call `Identity.decide` and `Identity.went_missing`. | `lib/Identity.roc` |
| R-TP10, R-TP18: a new name with a known `repository_id` (the old row is `moved`), the 301 of an old name (the name of the URL `U` and the `full_name` `F` of the answer), the rename back | Yes | W2 `tp10-rename`, `tp10-301-followed`, `tp18-301-no-row`, `tp18-rename-back` |
| R-TP11, R-TP19: `active` (the first release, `found`), `missing` and `moved` (the rows and the events); `found` sets `repo_checks.next_check_at` to the smaller of its value and now | The states in the rows, `found` in the ingest. `missing` as a pure decision (`went_missing`; a `moved` row is not changed). The cron and the webhook that set `missing` are 118 and 119. | W0, W2 `tp9-four-rows` request 6 |
| R-TP12: 403 `repository-changed` with `issues_url` | Yes | W0 `changed`, `changed_json`. W2 `tp9-four-rows` requests 4 and 7 |
| R-TP13, R-RE15: a `repo_events` row for each change, and `bind` for the first write (Design Q163) | Yes | W2 db.tsv |
| R-PU24 (state part): the state `missing` and its event | The pure decision. The `withdrawn` = `repo-missing` rows and the clear are 118 and 119 (they need the asset check, R-PU20). | W0 `went_missing` |
| R-PU22 | No change: 113 keeps the `repo_checks` interval of slice 112 | |

Split decision: no split. The private reference adds 65 lines to `lib/Identity.roc` (the stub has 113 lines) and 150 lines to `IngestRoutes.roc`: about 215 lines of code (TW19: about 400).

```mermaid
flowchart TB
    P["D1 call 1 (a batch): the label row and the repos row of the name"] --> A["after_read (slice 112)"]
    A -->|Answer, Conflict| X["200 / 409, as in 112 (no GitHub read, no identity check)"]
    A -->|AddProvenance, Index| V["GET /repos/{owner}/{repo}: public? (R-AP68 row 6, slice 112)"]
    V --> D{"Identity.decide(row of U, ids of the read); F = full_name of the answer"}
    D -->|Changed (R-TP9 row 4)| F["403 repository-changed + issues_url, no D1 call, nothing written"]
    D -->|Ok(change)| W["slice 112 flow; the batch also has the identity statements (3.2); the rename SQL depends on F is U (R-TP18)"]
```

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-TP9 rows 1 to 3 | The same ids: accept, no change. Another owner id: the row gets it, event `transfer`. Another repository id: the row gets it, state `active`, successor cleared, event `recreate`. | W0 `decide`. W2 `tp9-four-rows` requests 1 to 3 |
| R-TP9 row 4 | Both ids different (any state): 403, nothing written | W0 `decide`. W2 `tp9-four-rows` requests 4 and 7 |
| R-TP5, R-TP13, Design Q163 | The first write of a name: the row (slice 112) and the event `bind` (seq 1) | W0 `decide`. W2 `tp9-four-rows` request 5 |
| R-TP10 | A new name with no row, and a row of another name with the same `repository_id`: the new row (same ids, `active`), the old row `moved` with the new name as `successor`, events `rename` on both. The 301 of an old name is followed by the platform; the ids are those of the final answer. | W2 `tp10-rename`, `tp10-301-followed`. W0 `renamed`, `full_name_of`, `repo_by_id_url` |
| R-TP18 (Q260, Q261) | The release is under `U`. `F` is not `U` (a 301): no row of another name changes; `U` with no row gets `bind`. `F` is `U`: a rename marks every non-`moved` row of the `repository_id` as `moved`; the `moved` row of `U` with the same `repository_id` is `active` again (rename back). | W2 `tp10-301-followed` (row 5), `tp18-301-no-row` (row 6), `tp10-rename` (row 1), `tp18-rename-back` (row 3) |
| R-TP19 (Q264 to Q266) | `found` does not change `withdrawn`, and sets `next_check_at` to `MIN(next_check_at, now)`. `went_missing` of a `moved` row: the same row, no event. `seq`, the order and the guard of the events. | W0 `went_missing`. W2 `tp9-four-rows` request 6 (T5), `q262-row-race` |
| R-TP11 | `found`: a `missing` row with the same `repository_id` is `active` again. `missing`: an `active` row that is not found or not public. `moved`: by a rename. | W0 `decide`, `went_missing`. W2 `tp9-four-rows` request 6 |
| R-TP12 | 403 `repository-changed` has the member `issues_url`, the setting `ISSUES_URL`. The media type is `application/problem+json`. | W0 `changed`, `changed_json`. W2 `tp9-four-rows` |
| R-RE11, R-RE15 | The columns of `repos` and `repo_events`, the codes (`state` 0 to 2, `action` 0 to 9) | W0 codes. W2 db.tsv |
| R-AP32 | The read route shows `moved` and the successor after a rename (slice 106, read after the rename) | W2 `tp10-rename` request 3 |
| R-PU24 (state), R-PU31, R-PU32 | See section 1 | W0 `went_missing` |
| R-AP41 (row 3, Q262) | The 403 costs 1 D1 call (the pre-read, a batch). A write costs 2 calls, as in 112. The batch makes no new identity check: a row that another request changed between the 2 calls is not overwritten (the `UPDATE` has the old ids in `WHERE`) and adds no event. | W2 `expect/d1-calls`, `q262-row-race` |
| R-AP68 row 6 (Q263) | The visibility comes before the ids: a repository that is not public gets 422 with any ids | W2 `tp9-private-first` |
| R-AP21 | The 403 has the problem form of slice 101 and no `talon-bookmark` (Q165) | W2 `tp9-four-rows` |

Design refs: Registry 7.1 (R-TP5), 7.3 (R-TP9 to R-TP14, R-TP18, R-TP19), 5 (R-RE11, R-RE15), 7 (R-PU22, R-PU24, R-PU31 to R-PU33), 4 (R-AP32, R-AP41, R-AP68); Design Q163, Q165, Q260 to Q267.

## 3. What the code agent writes

### 3.1 Public signatures (fixed, in `worker/lib/Identity.roc`)

| Item | Type | Rule |
| --- | --- | --- |
| `Identity.Ids` | `{ repository_id : U64, owner_id : U64 }` | R-TP9 |
| `Identity.State` | `[Active, Missing, Moved]` (codes 0, 1, 2) | R-RE11 |
| `Identity.Row` | `{ repo : I64, repository_id : U64, owner_id : U64, state, successor : Try(I64, [None]), state_at : U64, time : U64 }` | R-RE11 |
| `Identity.Action`, `Identity.Event` | `[Bind, Transfer, Rename, Recreate, Missing, Found, SuccessorSet, SuccessorRemoved, Offer, Operator]` (codes 0 to 9); `Event` has the ids before and after as `Try(U64, [None])` | R-RE15 |
| `Identity.Change` | `{ row : Identity.Row, events : List(Identity.Event) }` | R-TP13 |
| `Identity.decide` | `{ repo : I64, row : Try(Identity.Row, [None]), seen : Identity.Ids, now : U64 } -> Try(Identity.Change, [Changed])` | R-TP9 (cases in the doc comment) |
| `Identity.went_missing` | `{ row : Identity.Row, now : U64 } -> Identity.Change` | R-TP11, R-PU24 |
| `Identity.full_name_of` | `Str -> Try(Str, [BadRepo])` | R-TP10 |
| `Identity.renamed` | `Str, Str -> Try(Str, [Same])` | R-TP10 |
| `Identity.repo_by_id_url`, `state_code`, `action_code`, `changed` | Given (bodies in the stub) | R-TP10, R-RE11, R-RE15, R-TP12 |
| `Identity.changed_json` | `Problem, Str -> Str`: the members of `Problem.to_json` and `issues_url` | R-TP12 |

`Identity` is in the exposes of `worker/lib/main.roc` and `IdentityTest` is in `worker/tests/unit/w0.roc` (done). `full_name_of` and `renamed` are used by the ingest (C1 of 3.2, R-TP18) and later by the reconcile and the webhook (119, 118). The rename back and the rename SQL are SQL of the ingest, not of `decide`.

### 3.2 The change of `IngestRoutes.roc` (the code agent; the 112 tests stay green)

`IngestRoutes.roc` is also changed by slice 112b (the limits). D1 call 1 is a batch since then (the label read, the owner count); the identity adds a statement to it.

| # | Change | Rule |
| --- | --- | --- |
| 1 | Add to the batch of D1 call 1 a read of the `repos` row of `Id.name_id(3, target.name)` (`CAST(id AS TEXT)` for the ids of 64 bits). The call count stays 1. | R-AP41 |
| 2 (C1) | After the visibility read of `AddProvenance` and `Index` (the repository is public), read `F` with `Identity.full_name_of` on the body of the answer. `Err(BadRepo)` is 502 `upstream`, detail `the GitHub repository answer is not valid`. `same` = `Identity.renamed(U, F) == Err(Same)`. Then `Identity.decide` with the row of call 1 and the ids of the read. `Err(Changed)`: return `Ok(Response)` 403 with the media type `application/problem+json` and the body of `Identity.changed_json` (the setting `ISSUES_URL` from `Env.var!`; a missing setting is `Fault`). No D1 call, no more GitHub read, no `talon-bookmark`. | R-TP9 row 4, R-TP12, R-TP18, Q263 |
| 3 | `Ok(change)` with events: statements in the write batch (and in the `AddProvenance` batch), before the last statement (the label read). A row that exists: one `UPDATE repos` guarded with the old ids, then one `INSERT INTO repo_events` for each event with `seq` = the next number of `repo` and `WHERE changes() > 0`. No other check in the batch (Q262). | R-TP9, R-TP13, R-TP19, Q262 |
| 4 (C2) | `U` has no row and `same`: in this order, `UPDATE repos SET state = 2, successor = <U>, state_at = <now> WHERE repository_id = <id> AND repo <> <U> AND state <> 2 AND NOT EXISTS (the row of U)`, the `rename` event of each marked row (`WHERE changes() > 0`), the `repos` insert of 112, the event of `U` (`rename` when a row was marked in this batch, else `bind`), the `repo_checks` insert of 112. `U` has no row and not `same`: the `repos` insert of 112, the event `bind`, the `repo_checks` insert. No other row changes. The lookup by `repository_id` is in SQL because R-AP41 allows no D1 call between the GitHub read and the batch (rule 1). | R-TP10, R-TP18 rows 1, 2, 6, R-TP13, Q163 |
| 5 (C3) | The row of `U` is `moved`, has the same `repository_id`, and `same`: after the `UPDATE` of row 3, (a) `UPDATE repos SET state = 2, successor = <U>, state_at = <now> WHERE repository_id = <id> AND repo <> <U> AND state <> 2 AND EXISTS (the row of U with state 2 and the id)`, the `rename` events of the marked rows (`changes() > 0`); (b) `UPDATE repos SET state = 0, successor = NULL, state_at = <now> WHERE repo = <U> AND state = 2 AND repository_id = <id>`, the `rename` event of `U` (ids before and after equal, successor NULL, `changes() > 0`). (a) comes before (b) because it reads whether `U` is `moved`. | R-TP18 row 3, Q261 |
| 6 (C4) | When the change has a `found` event: `UPDATE repo_checks SET next_check_at = MIN(next_check_at, <now>) WHERE repo = <U>` (after the event, `changes() > 0`). The code does not touch `releases.withdrawn`. | R-TP19, Q264 |
| 7 (C5) | `time` of a `repos` row never changes (R-PU34 row 2 reads it). `state_at` changes when `state` or `successor` change. The doc comments of `lib/Identity.roc` are done (test agent). | R-RE11, R-TP19 |

The reference of the private run uses `changes()` of SQLite in a batch, and it works on the local D1 of Miniflare.

## 4. Tests

### 4.1 Table

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| W0 | `worker/tests/unit/IdentityTest.roc`, 14 `expect`s | `decide`: no row (`bind`), the same ids, a transfer, a recreate, a recreate of a `moved` row and of a `missing` row (state `active`, successor cleared, `state_at`), `found` and `found` after a transfer, `Changed` in each state. `went_missing` (active, missing; a `moved` row gives the same row and no event, T1). `renamed` (4 cases). `full_name_of` (6 cases). `repo_by_id_url`. The codes. `changed`, `changed_json` (parsed back, escaping of the URL). | R-TP9, R-TP5, R-TP10, R-TP11, R-TP12, R-TP13, R-TP19, R-PU24, R-RE11, R-RE15 |
| W2 | `identity/tp9-four-rows` (7 requests) | 7 seeded or new names: same ids (no event), transfer, recreate, both ids different (403, `issues_url`, no bookmark, 1 D1 call, 1 GitHub read, nothing written), no row (`bind`, `repo_checks`), `missing` row (`found`, `state_at`; T5: its `next_check_at` was after the clock and is now the clock, and an older release stays `repo-missing` with its `withdrawn_at`), and a label with the hash and no `ingest` row with other ids (403, no provenance row). db.tsv: `repos`, `repo_events`, `repo_checks`, `releases` (with `withdrawn`), the groups (`names` kind 2) and `provenance`. | R-TP9, R-TP5, R-TP11, R-TP12, R-TP13, R-TP19, R-RE11, R-RE15, R-PU31, R-PU32, R-AP68, R-AP41, R-AP21 |
| W2 | `identity/tp10-rename` (4 requests) | A release of `acme/lib2` (no row; `acme/lib` has the same ids): `acme/lib` is `moved` with the successor, `acme/lib2` is `active`, 2 `rename` events (seq 2 of the old name), a `repo_checks` row. A second release: no new event, the same `state_at`. Then the R-AP32 reads of both names. | R-TP10, R-TP18 row 1, R-TP11, R-TP13, R-TP14, R-PU26, R-AP32, R-RE11, R-RE15 |
| W2 | `identity/tp10-301-followed` (1 request) | The old name `acme/lib` (it has a row): the fake GitHub answers 301 to `/repositories/100`, and that answer has the ids of the row and another `full_name` (`F` is not `U`). 201; the log has both reads; the release is under `acme/lib`. db.tsv (T2): `repos`, `repo_events`, `repo_checks` have only the seed rows (no row of `F`, no rename). A code that writes a row of `F`, or compares the `full_name` with the name of the URL and refuses, fails it. | R-TP10, R-TP9 row 1, R-TP18 row 5 |
| W2 | `identity/tp18-301-no-row` (1 request, T3) | `acme/new` is bound (100, 10). An ingest of the URL `acme/old` (no row): the 301 answer is `acme/new` with the same ids. 201, 2 D1 calls. `acme/old` gets its row (`active`, no successor, `state_at` = `time` = now), the event `bind` (seq 1) and a `repo_checks` row; `acme/new` does not change; the release is under `acme/old`. | R-TP18 row 6, R-TP5, R-TP13, R-PU26 |
| W2 | `identity/tp18-rename-back` (2 requests, T4) | A chain `acme/a` to `acme/b` to `acme/c` (`a`, `b` `moved`, `c` `active`, all with the same ids, with the events of a real history). An ingest of a release of `acme/a` with a direct 200 answer `full_name` `acme/a`: 201. `a` is `active`, no successor, `state_at` = now, a new `rename` event; `c` is `moved` with the successor `acme/a` and a `rename` event; `b` does not change. A second release: no new event, the same `state_at`. | R-TP18 rows 1, 3, 4, R-TP13, R-TP14 |
| W2 | `identity/tp9-private-first` (3 requests, T6) | `taken/repo` is bound (4001, 41). The answer of the repository has other ids (9999, 99) and `visibility` `private`: a new label gives 422 `repository not found or not public` (1 D1 call, no bookmark), the indexed label (the `AddProvenance` path) gives 422 and no provenance row. The control: the same ids, `public`: 403. | R-AP68 row 6, R-PU31, R-PU32, R-TP9 row 4, Q263 |
| W2 | `identity/q262-row-race` (1 request, T7) | A hook after D1 call 1 sets the owner id of the row to 11 and writes the event `transfer` (seq 2), as another request. Our answer has the ids (1, 12): 201, the release is written, the row keeps (1, 11), and no seq 3 (our guarded `UPDATE` changed 0 rows). | R-AP41 row 3, R-TP9 row 2, R-TP13, R-TP19, Q262 |

`node worker/tests/tools/mk-identity.mjs` writes the 7 cases. The ids, the version columns and the hashes come from node. `notes.txt` in each case names each request. No W1 case: the slice adds no SQL file, and the SQL of the route is checked by the db.tsv of W2.

### 4.2 Red results (2026-11-02)

| Step | Result |
| --- | --- |
| W0 `IdentityTest` with the stubs | 14 expects: 2 pass (the codes, `repo_by_id_url`), 12 fail with `todo`. 0 compiler errors. |
| W2 `identity/*` with the code of slice 112 and the stubs (after T1 to T7) | `tp9-four-rows` (`request 4: status: expected 403, got 201`), `tp10-rename`, `tp18-301-no-row`, `tp18-rename-back` (db rows differ) and `tp9-private-first` (`request 3: status: expected 403, got 502`) fail. `tp10-301-followed` and `q262-row-race` pass: they are guards (a code that writes a row of `F`, or an `UPDATE` with no old ids in `WHERE`, fails them; see the mutations m10 and m16). Requests 1 and 2 of `tp9-private-first` pass (the code of 112 gives 422 for a private repository). |
| `roc check worker/main.roc`, `roc fmt --check` of the new files | 0 errors |
| Full W0 (`scripts/test.sh w0`, worker part), first run | Failures: `ClientTest` (4) and `HintsTest` (15) of slice 116, `IdentityTest` (11 of 13 at that time). Nothing else. |
| Full W2 (`scripts/test.sh w2`), first run | 115 cases: 102 pass. The 13 failures: `identity/tp9-four-rows`, `identity/tp10-rename` (this slice), `hints/*` (8, slice 116), `ingest-limits/*` (3, slice 112b). `check`, `fmt`, `selftest` pass. |

### 4.3 Shared files changed

The copies before are in `research/slice-113-revert/before/`. `NEW.txt` lists the new files.

| File | Change |
| --- | --- |
| `worker/lib/main.roc` | `Identity` in the exposes |
| `worker/tests/unit/w0.roc` | `import IdentityTest` |

### 4.4 Revert check (private reference)

`research/slice-113-revert/reference/` fills `lib/Identity.roc`, and `patch.py` changes a copy of `IngestRoutes.roc` (anchored replacements). `research/slice-113-revert/ref.sh all` copies `worker/`, `packages/records` and `sql/` to `refbuild/`, applies both, runs W0 (`IdentityTest`) and W2 (`identity/`): 14 of 14 expects, 7 of 7 cases (2026-11-02, after the answers of 7.1; the patch is on the `IngestRoutes.roc` of slice 112b). With the reference, `ingest/`, `ingest-limits/`, `reads/` and `toolchains/` pass too (39 of 39 cases with `identity/`). The build is `--opt=speed`. `MUTATE=mutations/<m>.py ref.sh all` runs one mutation.

| Mutation (2026-11-02) | Caught by |
| --- | --- |
| m1 R-TP9 row 4 uses `or`: a transfer or a recreate gives 403 | W0 `decide` (4 expects), W2 `tp9-four-rows` |
| m2 a `missing` row with the same ids gets no `found` | W0 `decide`, W2 `tp9-four-rows` (request 6) |
| m3 a recreate keeps the state and the successor of the row | W0 `decide` (the `moved` and `missing` rows). Not W2 (no `moved` row is recreated in W2). |
| m4 the 403 of the `Index` path is ignored (the batch goes on) | W2 `tp9-four-rows` (request 4) |
| m5 the 403 of the `AddProvenance` path is ignored | W2 `tp9-four-rows` (request 7) |
| m6 the event of the new name of a rename is `bind` | W2 `tp10-rename` |
| m7 the old row of a rename is not set to `moved` (no state, no successor) | W2 `tp10-rename` (db and the R-AP32 read) |
| m8 the event `seq` is always 1 | W2 `tp9-four-rows` (the second event of a name) |
| m9 `time` of a changed row is the clock | W0 `decide` (5 expects). Not W2 (the reference `UPDATE` does not write `time`). |

Caught 9 of 9. The first run of m4 did not apply (an anchor), and m9 was first a version that did not compile; both were made again. The tests changed for the answers of 7.1, and 7 mutations were added (2026-11-02):

| Mutation | Caught by |
| --- | --- |
| m10 the rename SQL (C3 a) runs also when `F` is not `U` (it marks `acme/new` `moved` with the successor `acme/old`) | W2 `tp18-301-no-row` (T3) |
| m11 a `moved` row of the current name is not revived | W2 `tp18-rename-back` (T4) |
| m12 (a) runs after (b) | W2 `tp18-rename-back` (T4) |
| m13 `found` clears `withdrawn` of the releases | W2 `tp9-four-rows` (T5) |
| m14 `found` does not lower `next_check_at` (`MAX` for `MIN`) | W2 `tp9-four-rows` (T5) |
| m15 the identity check comes before the visibility check (a private repository with other ids gives 403) | W2 `tp9-private-first` (T6) |
| m16 the `UPDATE` of R-TP9 has no old ids in `WHERE` | W2 `q262-row-race` (T7) |

Caught 7 of 7, by W2 only (W0 passes with them: they are SQL of the route). The logs are `research/slice-113-revert/mut-<m>.log`.

## 5. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 403 body | The 4 members of every problem (`type` `/errors/repository-changed`, `title` `Repository changed`, `status` 403, `detail`) and `issues_url` (the setting). `content-type: application/problem+json`. No `talon-bookmark`. |
| 403 `detail` | `the name <owner/repo> is bound to another GitHub account (repository id <the recorded id>)`. The id is the recorded `repository_id`, as in the `tln` text of R-TP12. |
| `repo_events` rows | `seq` of a repo starts at 1 and grows by 1 (the next is `MAX(seq) + 1`). `claims` is NULL (no token in 113). The ids before and after are filled in each event (`bind`: before NULL). `rename` on the new name: ids before NULL, after the ids, successor NULL. `rename` on the old name: ids before and after equal, successor the new name. `transfer`, `recreate`, `found`, `missing`: `successor` is the successor of the row after the change. |
| `transfer` of a `missing` row | Two events: `transfer`, then `found` (both rules apply, R-TP9 row 2 and R-TP11) |
| `repos.time`, `repos.state_at` | `time` is the time of the first write and never changes. `state_at` is the time of the last change of `state` or `successor` (the R-AP32 member `state_at`). A transfer or a recreate of an `active` row does not change it. |
| Events for no change | None. An ingest of the same ids writes no event. |
| A missing `ISSUES_URL` | 500 `internal` (the setting is a deploy fault). No test. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The publish path (ids from the claims): a failed id check is 403 `repository-changed` (R-TP3 row 5, Q267) | Slice 114 maps it to `Identity.changed` |
| The webhook and reconcile paths: `missing` from a 404 or a private read, `found` from a read by id, `withdrawn` = `repo-missing` and its clear (R-PU24, R-PU33, R-PU17) | Slices 118 and 119. 113 gives `went_missing`, `full_name_of`, `renamed`, `repo_by_id_url`. |
| `successor-set`, `successor-removed`, `offer`, `operator` events (R-AP31, P3; R-TP12 by hand) | P3 and operator |
| The Workers log line of a refusal | The runner does not check log lines |
| The webhook and reconcile steps by id of R-TP10 (a rename found by `GET /repositories/{id}`), and the second `active` row that R-TP18 row 6 can leave | Slices 118 and 119 |
| R-PU22 | No change in 113 |

## 7. Questions (all answered)

All 8 are answered (2026-11-02, section 7.1). The columns below are the record of the questions. Where 7.1 differs from a proposal, 7.1 holds.

| Id | Question | Proposal | Effect now |
| --- | --- | --- | --- |
| Q113-1 | An ingest of the URL of the old name after a rename: GitHub follows the 301, and the final answer has the recorded ids and another `full_name`. R-TP10 calls this a rename, but gives its effects only for a name with no `repos` row. What does the ingest write for the old name: nothing for the identity (row 1, accept) or also the rename (the row of `full_name` if missing, the old row `moved` with the successor, events `rename`)? And does the release get the name of the URL or `full_name`? | Row 1: accept, no identity write, the release under the name of the URL (the reference) | `tp10-301-followed` checks the status, the 2 reads and one release row only |
| Q113-2 | More than one row has the `repository_id` (A to B, then B to C), and the name of a `moved` row is read again (B to A): which rows become `moved` or `active`? R-TP10 says "a row of another name". | The rows with the same `repository_id` and a state other than `moved` become `moved`. A `moved` row that is read again with the same ids stays as it is (the reference). | No test |
| Q113-3 | R-AP41 rule 3: "The write batch makes that check again". The 403 uses the row of call 1. A row that changed between the 2 calls (another request bound the name to other ids) needs a guard in the batch (a `WHERE` on the release statements, or a trigger in `sql/0002_triggers.sql`) and an answer. | No re-check except the guarded `UPDATE` (the reference): the window is small and a binding to other ids by a second request needs the owner of the name | No test |
| Q113-4 | A name that is bound to other ids and whose repository is not public now: 422 (the visibility, R-AP68 row 6) or 403? | 422 first (the order of R-AP68: row 6, then the identity; the answer for a private repository is one answer, R-PU32) | No test |
| Q113-5 | A `missing` row that an ingest sets `active` (`found`): does the ingest clear `withdrawn` = `repo-missing` on the releases of the name (R-PU24, R-TP11 "clears for each release whose asset is there again")? | No. The ingest sets the state and the event. The clear is the reconcile (119), which checks the asset (R-PU20). | `back/repo` has no withdrawn release (T5 adds one) |
| Q113-6 | `went_missing` of a `moved` row (the reconcile of an old name that GitHub now answers 404, R-TP11)? | Open. The function is not tested for it. | No test |
| Q113-7 | The order of the events of one change and the `seq` of the first event of a name | Section 5 (a proposal, the human accepts at the review) | db.tsv |
| Q113-8 (for 114) | R-TP3 row 5 says a publish token whose ids do not match the row gets 403 `forbidden` with the claim in `detail`. R-TP9 row 4 says 403 `repository-changed`. Which one does a publish get? | `repository-changed` (R-TP12 is the answer for the whole identity; R-TP3 row 5 and R-TP9 are the same check) | None in 113 |

## 7.1 Answers (design agent, 2026-11-02)

The answers are in Registry R-TP18 (Q113-1, Q113-2), R-TP19 (Q113-5, Q113-6, Q113-7), R-AP41 row 3 (Q113-3), R-AP68 row 6 and the item "The identity" (Q113-4) and R-TP3 row 5 (Q113-8). Design Q260 to Q267.

| Id | Answer | Against the proposal | Design Q |
| --- | --- | --- | --- |
| Q113-1 | `U` is the name of the URL, `F` the `full_name` of the answer. The release is under `U`. R-TP9 checks the ids against the row of `U`. If `F` is not `U`, no row of another name changes (also not a `moved` row). If `U` has no row, it gets a row with `bind`. If `F` is `U`, R-TP18 rows 1 to 4 apply. | Taken, with one addition: the proposal said nothing for a `U` with no row. The reference marks the row of `F` as `moved` with successor `U` (it reverses the rename), so the SQL of rows 1 and 3 must run only when `F` is `U`. | Q260 |
| Q113-2 | At a new name, every row with the `repository_id` that is not `moved` becomes `moved` with the successor. A `moved` row stays. A `moved` row of the current name with the same ids (`F` is `U`) becomes `active`, no successor, event `rename`. | Changed: the proposal kept a `moved` row as it is, also when its name is the current name again. Then the current name stays `moved` with a successor that points back to it, until the reconcile of slice 119. | Q261 |
| Q113-3 | No new check in the batch. The guarded `UPDATE` and `changes() > 0` stay. R-AP41 row 3 names this as the second exception. | Taken, with the reason: a row changes between the calls only by an accepted change, and a request keeps one equal id. | Q262 |
| Q113-4 | 422 first. | Taken. | Q263 |
| Q113-5 | The ingest does not clear `repo-missing`. It sets `repo_checks.next_check_at` to `MIN(next_check_at, now)` when it writes `found`. | Taken, with one addition (as the `publicized` of R-PU33): a repository with the App is read every 24 h, too long for a repository that is back. | Q264 |
| Q113-6 | `went_missing` of a `moved` row: the same row, `events` is `[]`. | Answered (the proposal was open). | Q265 |
| Q113-7 | Section 5 holds: `seq` from 1, then +1; `transfer` before `found`; an event only when a statement changed a row. | Taken. | Q266 |
| Q113-8 | A publish gets 403 `repository-changed` with `issues_url`. | Taken. R-TP3 row 5 is changed. Slice 108 Q108-3 had the same answer. | Q267 |

### Changes for the code agent (section 3.2, rows 3 and 4)

| # | Change | Rule |
| --- | --- | --- |
| C1 | After the visibility read, read `F` with `Identity.full_name_of` on the body of the answer. `Err(BadRepo)` is 502 `upstream`, detail `the GitHub repository answer is not valid`. All 112 fixtures have `full_name`. `same` = `Identity.renamed(U, F) == Err(Same)`. | R-TP18 |
| C2 | The statements for the rename of a name with no row (3.2 row 4) run only when `same`. When not `same` and `U` has no row: the `repos` insert of 112, the event `bind`, the `repo_checks` insert. | R-TP18 rows 5, 6 |
| C3 | Rename back, when `same`, in this order: (a) `UPDATE repos SET state = 2, successor = U, state_at = now WHERE repository_id = rid AND repo <> U AND state <> 2 AND (NOT EXISTS (row of U) OR EXISTS (row of U with state = 2 AND repository_id = rid))`, then the `rename` events of the rows marked (`changes() > 0`); (b) `UPDATE repos SET state = 0, successor = NULL, state_at = now WHERE repo = U AND state = 2 AND repository_id = rid`, then the `rename` event of `U` (ids before and after equal, successor NULL, `changes() > 0`); (c) the insert of 112 and its event (`rename` when (a) marked a row, else `bind`). (a) comes before (b) because it reads whether `U` is `moved`. (a) and (b) come after the `UPDATE` of R-TP9 rows 2 and 3. | R-TP18 rows 1, 3 |
| C4 | When the change has a `found` event: `UPDATE repo_checks SET next_check_at = MIN(next_check_at, now) WHERE repo = U`. The code does not touch `releases.withdrawn`. | R-TP19 |
| C5 | Doc comments of `lib/Identity.roc` (test agent): `decide` item 3 says "A row in the state Moved stays, no event (Registry R-TP18 rows 3 and 5: the rename back is SQL of the ingest, not `decide`)". `went_missing`: "A Moved row: the same row, no event (Q265)". The 2 "open" notes go. | R-TP19 |

### Changes for the test agent (all in `worker/tests/tools/mk-identity.mjs`, then the tool is run again; the rules file of each case names the ids)

| # | Case | Change | Rules |
| --- | --- | --- | --- |
| T1 | W0 `IdentityTest` | One new `expect`: `went_missing` of `row(Moved, Ok(99), 2000)` with `now` gives `{ row: moved, events: [] }` (state, successor and `state_at` the same). Total 14 `expect`s. The 2 doc notes of C5. | R-TP19, Q265 |
| T2 | W2 `identity/tp10-301-followed` | Add the 3 db.tsv queries of `tp10-rename` (`repos`, `repo_events`, `repo_checks`) and the release query `r.log_index, n.value, r.tag` with `releases` joined to `names`. Expect: `repos` the seed row only (`acme/lib 100 10 0 \N 1767000000000 1767000000000`), `repo_events` the seed `bind` only, `repo_checks` the seed row, the release under `acme/lib` (not under the `full_name`). The case then fails a code that writes a row of `F`. | R-TP18 rows 5, Q260 |
| T3 | W2 new `identity/tp18-301-no-row` (1 request) | Seed: `acme/new` (100, 10, `active`, `bind`, `repo_checks`). Request: an ingest of the URL `acme/old`, which has no row. The fake answer of `repos/acme/old` is the 301 text, and `repositories/100` has the ids 100 and 10, `full_name` `acme/new`, `visibility` `public`. Expect 201, 2 D1 calls. `repos`: `acme/new` unchanged (`active`, no successor, seed `state_at`), `acme/old` (100, 10, state 0, no successor, `state_at` and `time` = now). `repo_events`: `acme/old` seq 1 `bind`; `acme/new` still only seq 1. `repo_checks`: 2 rows. The release is under `acme/old`. | R-TP18 row 6, Q260 |
| T4 | W2 new `identity/tp18-rename-back` (2 requests) | Seed: `acme/a` (100, 10, `moved`, successor `acme/b`, `state_at` S0), `acme/b` (100, 10, `moved`, successor `acme/c`, S0), `acme/c` (100, 10, `active`), each with a `bind` event (and the `rename` events a real history has), and `repo_checks`. Request 1: an ingest of a release of `acme/a`; the fake answer is a direct 200 with `full_name` `acme/a` and the ids 100, 10. Expect 201. `acme/a`: state 0, no successor, `state_at` = now, `time` unchanged, a new event `rename` (before and after 100/10, successor NULL). `acme/c`: state 2, successor `acme/a`, `state_at` = now, a new event `rename` (successor `acme/a`). `acme/b`: unchanged, no new event. Request 2: a second release of `acme/a`: 201, no new event, the same `state_at`. | R-TP18 rows 1, 3, Q261 |
| T5 | W2 `identity/tp9-four-rows` request 6 | Seed `back/repo` with `next_check_at` 1767312000000 (after now). Seed one release of `back/repo` with `withdrawn` `repo-missing` and a `withdrawn_at` (log index 2; the later log indexes move by 1 and the node tool computes them). Expect after request 6: `back/repo` `repo_checks.next_check_at` 1767225630000 (= now); the old release still `repo-missing` with the same `withdrawn_at`; the other 6 `repo_checks` rows as before. | R-TP19, Q264 |
| T6 | W2 new `identity/tp9-private-first` (2 requests) | Seed: `taken/repo` (4001, 41, `active`) as in `tp9-four-rows`, and an indexed label with webhook provenance and no `ingest` row. Request 1: a new label of `taken/repo`; the answer of `repos/taken/repo` has the ids 9999 and 99 (both different) and `visibility` `private`. Expect 422 `not-a-candidate`, `repository not found or not public`, 1 D1 call, no `talon-bookmark`, nothing written. Request 2: the indexed label (the AddProvenance path) with the same private answer: 422, no provenance row. Request 3 (the control): the same ids and `visibility` `public`: 403 `repository-changed`. | R-AP68 row 6, Q263 |
| T7 | W2 new `identity/q262-row-race` (1 request) | Seed: `race/repo` (1, 10, `active`, `bind` seq 1). The hook `repos/race/repo/%2F.sql` (it runs after D1 call 1, as `%2F.N.sql` of slice 112) sets the ids to (1, 11) and adds `transfer` as seq 2. The fake answer has the ids (1, 12). Expect 201. `repos`: (1, 11), as the other request wrote it. `repo_events`: seq 1 `bind`, seq 2 `transfer` (1/1, 10/11), and no seq 3: our guarded `UPDATE` changed 0 rows. The release is written. | R-AP41 row 3, Q262 |

Mutations to add (the 5 to 10 tricky ones only, as the memory rule says; run filtered entries of `reverts.mjs`, not the full sweep):

| Mutation | Caught by |
| --- | --- |
| m10 the rename SQL of C3 (a) runs also when `F` is not `U` | T2, T3 |
| m11 a `moved` row of the current name is not revived | T4 |
| m12 (a) runs after (b) | T4 |
| m13 `found` clears `withdrawn` of the releases | T5 |
| m14 `found` does not set `next_check_at` | T5 |
| m15 the identity check comes before the visibility check | T6 |
| m16 the `UPDATE` of R-TP9 has no old ids in `WHERE`, or its event has no `changes() > 0` | T7 |

Out of scope, for later slices: the reconcile and the webhook rename steps by id (R-TP10, slice 118 and 119), and the second `active` row of R-TP18 row 6 (they set it `moved`). Slice 114 maps the failed ids of R-TP3 row 5 to `Identity.changed` (Q113-8).

### 7.2 Changes for the answers (test agent, 2026-11-02)

| # | Done |
| --- | --- |
| T1 | `IdentityTest`: the expect for `went_missing` of a `moved` row (14 `expect`s). C5: the doc comments of `lib/Identity.roc` (`decide` item 3, `went_missing`) cite R-TP18 and R-TP19; the two "open" notes are gone. |
| T2 | `tp10-301-followed`: db.tsv for `repos`, `repo_events`, `repo_checks`, `releases`; the response checks `repo` = `acme/lib`. |
| T3 | New `tp18-301-no-row`. |
| T4 | New `tp18-rename-back`. The seeds have the events of a real history (`bound` of `mk-identity.mjs` takes an `events` list). |
| T5 | `tp9-four-rows`: the old release of `back/repo` (log index 2, `repo-missing`), `next_check_at` after the clock; the later log indexes moved by 1. |
| T6 | New `tp9-private-first` (the `.2` and `.3` answers of the fake GitHub). |
| T7 | New `q262-row-race` (the hook `repos/race/repo/%2F.sql`). |
| Ids | The `rules` files name R-TP18, R-TP19, R-AP41, R-AP68; the comments cite Q260 to Q264. No `Q113-` mark is left in the tests, the tool or the stubs. |

## 8. Disputes (from the code agent)

None yet.

## 8.1 Code (code agent, 2026-11-02)

| File | Change | Lines |
| --- | --- | --- |
| `worker/lib/Identity.roc` | `decide`, `went_missing`, `full_name_of`, `renamed`, `changed_json` (the stubs are filled; 2 small helpers `event_of`, `found_after`, `with_first`, `ids_of`) | 113 to 197 lines (+84) |
| `worker/IngestRoutes.roc` | Section 3.2 and C1 to C4: `repo_sql` (the third statement of D1 call 1), `old_row`, `identity!` (C1, the 403), `identity_stmts`, `new_name_stmts` (C2), `rename_back_stmts` (C3), `event_stmt`, `marked_events_stmt`, `update_stmt`, `found_stmt` (C4); `read_repo!` returns `F`; `writes_of` no longer has the `repos` and `repo_checks` inserts (they are in `new_name_stmts`) | 367 to 541 lines (+174) |

Decisions the slice does not fix:

| Decision | Reason |
| --- | --- |
| `changed_json` reads the 4 members back from `Problem.to_json` and writes them again with `issues_url` | The fields of `Problem` are hidden outside `lib/Problem.roc`, and that file is not part of the slice |
| A row that exists gets no `repos` and no `repo_checks` insert in the batch | The insert would never write (the row exists); R-AP41 row 3 |
| One clock value for each request after the GitHub read: `identity!` and `Ingest.plan` (and the provenance row) use it | One `now` for the decision and the rows |
| The marked rows of C2 and C3 (a) are found for their events by `successor = U AND state_at = now AND state = 2` | The batch has no other way to know which rows the `UPDATE` changed |

## 9. Verify results

Code agent, 2026-11-02 (the revert check of the code agent is not done; the mutations m1 to m16 of the test agent stand).

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | `IdentityTest` 14 of 14 expects pass. The failures that remain are `GithubAppTest` and `LoginTest` (slices 119a and 117, red by design). |
| `scripts/test.sh wbuild w2` (`--opt=speed`) | 123 pass, 4 fail. All 7 `identity/*`, and `ingest/*`, `ingest-limits/*`, `reads/*` pass. The 4 failures are `githubtoken/pu25-*` (slice 119a, red). |
| `scripts/test.sh check fmt w1` | pass |
