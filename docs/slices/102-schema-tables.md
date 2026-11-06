# 102 Schema: tables and ids

Phase: P2. Status: green (code step done, 2026-11-01; tests were red at review). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` C.1, row 102. Depends on slice 101 (the W1 runner `sql/tests/run.mjs`, in progress).

## 1. Scope

This slice makes the D1 migration `sql/0001_init.sql`: each table of Registry 5 that P2 uses, with the types, keys, `STRICT`, `WITHOUT ROWID`, the `CHECK` constraints, the `targets` rows and the indexes of the prototypes. It adds no trigger (slice 103) and no `yanks` table (P3, Design Q55).

| Part | Who | State |
| --- | --- | --- |
| `sql/0001_init.sql` | Test agent (a stub with a TODO comment), code agent (the tables) | The stub is in place. The code agent writes the file from section 3. |
| W1 cases `sql/tests/cases/schema/s1` to `s5` | Test agent | Done. Red (section 4). The code agent does not edit them (TW18). |
| Private reference `research/slice-102-revert/reference/0001_init.sql` | Test agent | Passes all cases. The code agent does not read it (TW18). Keep until the review is applied. |
| Runner `sql/tests/run.mjs`, `split.mjs`, `scripts/test.sh` | Slice 101 | Not changed here. No runner request is needed (section 8). |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-RE1 to R-RE5, R-RE7, R-RE9, R-RE11, R-RE12, R-RE14 to R-RE25 | One table each (section 3). R-RE8 and R-RE13 are triggers (slice 103). R-RE10 (`yanks`) is P3. | s1 (shape), s4, s5 |
| R-RE6 (the tables part) | The key that makes a row unique, the columns that change (`yanked`, `withdrawn`, `withdrawn_at`), and `targets` UNIQUE. The "never changed" part needs no trigger. | s2, s5 |
| R-RE26 | A time is an INTEGER (ms since 1970 UTC). A text time and a real time are errors. | s1 (types), s4 (text), s5 (real) |
| R-IK1, R-IK2 | Ids are INTEGER columns. A 64-bit id is bound as text, stored as an integer, read with `CAST(id AS TEXT)`, and compared in the 4 forms of the rule. | s4 (K1, K3, K10, K11), s1 |
| R-IK3 | `names (id, kind, value)`, `UNIQUE (kind, value)`, the conflict target, the collision error. | s3 (K4, K5) |
| R-IK4 | The `nightly` columns are INTEGER. The id function is slice 104. | s1 |
| R-IK5, R-IK6 | `version` is a signed 64-bit key, `version_text` is TEXT, the label is `UNIQUE (form, version, version_text)`, the key of a release is `log_index`. The key function is slice 105. | s1, s5 (K6), s4 |
| R-IK7 | The `targets` rows 0 to 35, a new target takes code 36. The `source` and `result` codes are CHECKed. | s2, s5 |
| R-IK8 | `STRICT` for all tables. `WITHOUT ROWID` for 8 tables. The `CHECK` of `names.value`. | s1, s3 (K12), s4 (K12) |
| R-SG1, R-SG2, R-SG5 | The log is a D1 table `(idx, grp, version, hash, time)`. The index is `max + 1` in one statement, and a used index is an error. | s1, s5 |

Design refs: Registry 3, 5, 5.1, `DESIGN.md` Q55 (no tiles in P2), Q60 (provenance key), Q61 (`transitions` is `WITHOUT ROWID`), Q65 (time is INTEGER ms), Q70 to Q74 (the wire records, `kind` codes, one `size`), Registry R-AP49, prototypes `research/d1-int-keys/`, `research/d1-sweep/`, `research/bot-set/`, `research/d1-contrib/`, `research/closure-runs/`.

## 3. What the code agent writes

One file: `sql/0001_init.sql`. It runs on SQLite (`node:sqlite`) and on local D1. Write one statement for each `;`. D1 cannot take the file as one text (the runner and `wrangler d1 migrations apply` split it). Do not use a `PRAGMA` or a `BEGIN`.

### 3.1 The tables

The tests check name, type, null flag (non-key columns), key position, row kind (rowid or `WITHOUT ROWID`) and `STRICT` for every row below. They do not check the order of the columns. A key column has no `NULL`. A `STRICT` table takes only these types: `INTEGER`, `TEXT`, `ANY`. Every table is `STRICT`.

| Table | Rows | Column | Type | Null | Key |
| --- | --- | --- | --- | --- | --- |
| `names` | rowid | `id` | INTEGER | no | key |
|  |  | `kind` | INTEGER | no |  |
|  |  | `value` | ANY | no |  |
| `targets` | rowid | `target` | INTEGER | no | key |
|  |  | `name` | TEXT | no |  |
| `artifacts` | rowid | `artifact` | INTEGER | no | key |
|  |  | `kind` | INTEGER | no |  |
|  |  | `exposes` | TEXT | no |  |
|  |  | `platform` | INTEGER | yes |  |
|  |  | `roc_pin` | TEXT | yes |  |
|  |  | `size` | INTEGER | no |  |
| `releases` | rowid | `log_index` | INTEGER | no | key |
|  |  | `form` | INTEGER | no |  |
|  |  | `version` | INTEGER | no |  |
|  |  | `version_text` | TEXT | no |  |
|  |  | `artifact` | INTEGER | no |  |
|  |  | `repo` | INTEGER | yes |  |
|  |  | `url` | TEXT | no |  |
|  |  | `tag` | TEXT | yes |  |
|  |  | `roc_version` | TEXT | yes |  |
|  |  | `published_at` | INTEGER | no |  |
|  |  | `yanked` | INTEGER | no |  |
|  |  | `withdrawn` | TEXT | yes |  |
|  |  | `withdrawn_at` | INTEGER | yes |  |
| `compat` | WITHOUT ROWID | `artifact` | INTEGER | no | key 1 |
|  |  | `nightly` | INTEGER | no | key 2 |
|  |  | `target` | INTEGER | no | key 3 |
|  |  | `source` | INTEGER | no | key 4 |
|  |  | `result` | INTEGER | no |  |
|  |  | `error_digest` | TEXT | yes |  |
|  |  | `time` | INTEGER | no |  |
|  |  | `log_index` | INTEGER | yes |  |
| `toolchains` | WITHOUT ROWID | `nightly` | INTEGER | no | key 1 |
|  |  | `target` | TEXT | no | key 2 |
|  |  | `tag` | TEXT | no |  |
|  |  | `asset_name` | TEXT | no |  |
|  |  | `sha256` | TEXT | no |  |
|  |  | `published_at` | INTEGER | no |  |
|  |  | `log_index` | INTEGER | no |  |
| `log` | rowid | `idx` | INTEGER | no | key |
|  |  | `grp` | TEXT | no |  |
|  |  | `version` | TEXT | no |  |
|  |  | `hash` | TEXT | no |  |
|  |  | `time` | INTEGER | no |  |
| `sweeps` | WITHOUT ROWID | `nightly` | INTEGER | no | key 1 |
|  |  | `target` | INTEGER | no | key 2 |
|  |  | `upto_log_index` | INTEGER | no |  |
|  |  | `time` | INTEGER | no |  |
| `transitions` | WITHOUT ROWID | `nightly` | INTEGER | no | key 1 |
|  |  | `target` | INTEGER | no | key 2 |
|  |  | `previous` | INTEGER | no |  |
|  |  | `compared` | INTEGER | no |  |
|  |  | `changed` | INTEGER | no |  |
| `provenance` | rowid | `release` | INTEGER | no | key 1 |
|  |  | `via` | INTEGER | no | key 2 |
|  |  | `claims` | TEXT | yes |  |
|  |  | `time` | INTEGER | no |  |
| `repos` | rowid | `repo` | INTEGER | no | key |
|  |  | `repository_id` | INTEGER | no |  |
|  |  | `repository_owner_id` | INTEGER | no |  |
|  |  | `state` | INTEGER | no |  |
|  |  | `successor` | INTEGER | yes |  |
|  |  | `state_at` | INTEGER | no |  |
|  |  | `time` | INTEGER | no |  |
| `repo_events` | rowid | `repo` | INTEGER | no | key 1 |
|  |  | `seq` | INTEGER | no | key 2 |
|  |  | `action` | INTEGER | no |  |
|  |  | `repository_id_before` | INTEGER | yes |  |
|  |  | `repository_id_after` | INTEGER | yes |  |
|  |  | `owner_id_before` | INTEGER | yes |  |
|  |  | `owner_id_after` | INTEGER | yes |  |
|  |  | `successor` | INTEGER | yes |  |
|  |  | `claims` | TEXT | yes |  |
|  |  | `time` | INTEGER | no |  |
| `repo_checks` | rowid | `repo` | INTEGER | no | key |
|  |  | `etag` | TEXT | yes |  |
|  |  | `checked_at` | INTEGER | yes |  |
|  |  | `next_check_at` | INTEGER | no |  |
|  |  | `fail_count` | INTEGER | no |  |
|  |  | `app_installed` | INTEGER | no |  |
| `compat_hints` | WITHOUT ROWID | `artifact` | INTEGER | no | key 1 |
|  |  | `nightly` | INTEGER | no | key 2 |
|  |  | `target` | INTEGER | no | key 3 |
|  |  | `talon_version` | INTEGER | no | key 4 |
|  |  | `pass_count` | INTEGER | no |  |
|  |  | `fail_count` | INTEGER | no |  |
|  |  | `crash_count` | INTEGER | no |  |
|  |  | `first_time` | INTEGER | no |  |
|  |  | `last_time` | INTEGER | no |  |
| `contributions` | WITHOUT ROWID | `contributor` | INTEGER | no | key 1 |
|  |  | `artifact` | INTEGER | no | key 2 |
|  |  | `nightly` | INTEGER | no | key 3 |
|  |  | `target` | INTEGER | no | key 4 |
|  |  | `result` | INTEGER | no |  |
|  |  | `talon_version` | INTEGER | no |  |
|  |  | `time` | INTEGER | no |  |
| `contributors` | rowid | `contributor` | INTEGER | no | key |
|  |  | `login` | TEXT | no |  |
|  |  | `tokens_after` | INTEGER | no |  |
|  |  | `first_time` | INTEGER | no |  |
|  |  | `last_time` | INTEGER | no |  |
| `links` | rowid | `machine` | INTEGER | no | key |
|  |  | `contributor` | INTEGER | no |  |
|  |  | `time` | INTEGER | no |  |
| `deps` | WITHOUT ROWID | `artifact` | INTEGER | no | key 1 |
|  |  | `alias` | TEXT | no | key 2 |
|  |  | `dep` | INTEGER | no |  |
|  |  | `form` | INTEGER | yes |  |
|  |  | `version` | INTEGER | yes |  |
|  |  | `version_text` | TEXT | yes |  |
|  |  | `url` | TEXT | no |  |
| `artifact_targets` | WITHOUT ROWID | `artifact` | INTEGER | no | key 1 |
|  |  | `target` | INTEGER | no | key 2 |
| `hint_days` | rowid | `day` | INTEGER | no | key |
|  |  | `counted` | INTEGER | no |  |
| `contributor_totals` | rowid | `contributor` | INTEGER | no | key |
|  |  | `counted` | INTEGER | no |  |
|  |  | `first` | INTEGER | no |  |
|  |  | `agreed` | INTEGER | no |  |
|  |  | `disagreed` | INTEGER | no |  |
|  |  | `unconfirmed` | INTEGER | no |  |
|  |  | `first_time` | INTEGER | no |  |

Id and code columns (sizes, R-IK2, R-IK7):

| Column | Holds | Table or rule |
| --- | --- | --- |
| `artifact`, `platform`, `dep`, `form`, `repo`, `successor`, `repos.repo` | A `name_id` (64 bit) | R-IK2, `names` |
| `contributor`, `machine` | A GitHub user id (above 0) or an HMAC id (below 0) | R-CT3 |
| `nightly` | The id of R-IK4 (under 47 bits) | R-IK4 |
| `version`, `talon_version` | A key (R-IK5). `version` is the key XOR 2^63 as a signed integer. | R-IK5 |
| `target` (not in `toolchains`) | A code of `targets` | R-IK7 |
| `toolchains.target` | The asset target of CLI 6.2 as text, for example `linux_x86_64` (R-RE4) | R-RE4, CLI 6.2 |
| `source` | `bot` 0, `author` 1 | R-IK7 |
| `result` | `pass` 0, `fail` 1, `hang` 2, `crash` 3. `contributions.result` is 0, 1 or 3. | R-IK7 |

### 3.2 CHECK constraints

Only these (section 5, proposals 3 and 4). A closed set that the design lists gets a CHECK (R-AP44). The tests use the message text `CHECK constraint failed`.

| Table.column | Check | Source |
| --- | --- | --- |
| `names` | `kind IN (1, 2, 3)`, and `typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END` | R-IK8, R-IK2, `research/d1-int-keys/schema.sql` |
| `artifacts.kind` | `IN (0, 1, 2)` (app 0, package 1, platform 2) | R-IK7, R-AP49, Design Q73 |
| `releases.withdrawn` | `IN ('deleted', 'unpublished', 'prereleased', 'edited', 'asset-replaced', 'repo-missing')`, or NULL | R-AP49, R-PU17, R-PU20, R-PU24 |
| `repos.state` | `IN (0, 1, 2)` (active 0, missing 1, moved 2) | R-RE11, R-AP32, R-IK7 |
| `provenance.via` | `IN (0, 1, 2, 3)` (oidc, webhook, poll, ingest) | R-RE9, R-IK7 |
| `repo_events.action` | `IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)` (the order of R-RE15) | R-RE15, R-IK7 |
| `compat.source` | `IN (0, 1)` | R-IK7 |
| `compat.result` | `IN (0, 1, 2, 3)` | R-IK7 |
| `contributions.result` | `IN (0, 1, 3)` (a hang is not a hint, R-CT2) | R-IK7, `research/d1-contrib/` |
| `contributors.contributor` | `> 0` | R-CT3 |
| `links.machine` | `< 0` | R-CT3 |

### 3.3 Indexes

The five of the prototypes, with these names, and the indexes that the keys make. The tests check the names, uniqueness and columns of both (`pragma_index_list`, `pragma_index_info`).

| Table | Index | Columns | From |
| --- | --- | --- | --- |
| `releases` | `releases_artifact` | `(artifact, log_index)` | `research/d1-sweep/` `releases_hash` |
| `compat` | `compat_artifact_target` | `(artifact, target, nightly)` | `research/closure-runs/` `compat_hash_target` |
| `compat` | `compat_nightly` | `(nightly, target, source, artifact)` | `research/bot-set/` |
| `contributions` | `contributions_pair` | `(artifact, nightly, target, time)` | `research/d1-contrib/` |
| `contributions` | `contributions_nightly` | `(nightly)` | `research/d1-contrib/` |
| `names` | (from `UNIQUE`) | `(kind, value)` | R-IK3 |
| `targets` | (from `UNIQUE`) | `(name)` | R-RE21 |
| `releases` | (from `UNIQUE`) | `(form, version, version_text)` | R-IK5, R-IK6 |
| the 8 `WITHOUT ROWID` tables, `provenance`, `repo_events` | the key | the key columns | R-IK8 |

No other index. No foreign key. No trigger. No view. No default value.

### 3.4 The `targets` rows

`targets (target, name)`: `(0, 'any')`, then the 35 values of R-IK7 as codes 1 to 35, in the order of the rule. The names are in `cli/lib/BuildTarget.roc` (`BuildTarget.names`, the same list). The test `s2-targets` reads all 36 rows and no more (it adds code 36 itself).

### 3.5 How to run

| Command | What it does |
| --- | --- |
| `scripts/test.sh w1` | `node sql/tests/run.mjs`: all W1 cases on both backends (about 3 s) |
| `node sql/tests/run.mjs schema` | Only the cases of this slice |
| `node research/slice-102-revert/gen-shape.mjs` | Writes `s1-tables/expect.tsv` and `s2-targets/expect.tsv` again (test agent only) |

## 4. Tests

Five W1 cases in `sql/tests/cases/schema/`. Each runs on `node:sqlite` and on local D1 (10 runs). Few cases with a large reach: `s1` checks the whole shape (21 tables, 122 columns, 18 indexes, the foreign keys) in 4 queries. The rule ids are in the file `rules` of each case (TW36).

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| W1 | `schema/s1-tables` | `pragma_table_list` (name, column count, `WITHOUT ROWID`, `STRICT`), `pragma_table_xinfo` (name, type, null flag of non-key columns, key position, hidden), `pragma_index_list` + `pragma_index_info` (name, unique, origin, columns), `pragma_foreign_key_list` (none) | R-RE1 to R-RE5, R-RE7, R-RE9, R-RE11, R-RE12, R-RE14 to R-RE26, R-IK1, R-IK2, R-IK4 to R-IK6, R-IK8, R-SG1, R-SG2 |
| W1 | `schema/s2-targets` | The rows 0 to 35 (names from the CLI list), UNIQUE name and code, NOT NULL, a text code is an error, code 36 is added | R-IK7, R-RE21, R-RE6 |
| W1 | `schema/s3-names` | K4 (same name, `ON CONFLICT (kind, value) DO NOTHING`), K5 (the id of another name stops the statement with `UNIQUE constraint failed: names.id`), the `CHECK` of the value type for 6 wrong pairs, kind 0 and 4, NULLs, a bad text id | R-IK3, R-IK8, R-IK2, R-RE22 |
| W1 | `schema/s4-int64-ids` | K1 (53-bit Number and `json_each` parameter), K3 (2^53+1 and 2^53 are two rows), K10 (the compare forms `=`, `IN json_each`, CTE join, `? = (SELECT id)`, `? = ? + 0` false, `id = ? + 0`, `CAST(? AS INTEGER)`), K11 (`CAST(id AS TEXT)` is exact, `typeof` integer) on `names` and on 9 other tables with the ends of the i64 range, K12 (a bad text id and an out of range id are errors in a WITHOUT ROWID key, a rowid column, a rowid key, and a time column) | R-IK1, R-IK2, R-IK3, R-IK5, R-IK6, R-IK8, R-RE26, R-RE1 to R-RE3, R-RE11, R-RE12, R-RE16, R-RE18 to R-RE20, R-RE22 |
| W1 | `schema/s5-keys-and-checks` | K6 ported (the label, five version keys in semver order, a saturated key with `version_text`), the changing columns, K9 (`WITHOUT ROWID`, the first write wins, a `bot` row and an `author` row), `source` and `result` codes, `toolchains` with 2 targets for 1 nightly (G11), the log sequence `max + 1`, NOT NULL of composite keys, the `CHECK` of `artifacts.kind`, `contributions.result`, `contributors`, `links`, a real time | R-IK5 to R-IK7, R-RE1, R-RE3 to R-RE6, R-RE9, R-RE15 to R-RE18, R-RE26, R-SG2, R-SG5 |

Cases K2, K7 and K8 of the prototype are not ported (section 6).

### 4.1 Red results (2026-11-01, `scripts/test.sh w1` with the stub migration)

| Run | Result |
| --- | --- |
| `scripts/test.sh w1` | `w1: 6 passed, 10 failed`. The 10 failures are the 5 `schema/*` cases on both backends. The 6 passes are the example and the self-tests of slice 101. 1.3 s. |
| Reason | Each failure is `no such table: <name>` (a step) or `setup failed: no such table`. For `s1` and `s2` the failure is `rows differ` (the query gives no row, or `no such table`) |
| Private reference | `research/slice-102-revert/run-ref.sh` runs the runner with the reference: `w1: 16 passed, 0 failed` (2.7 s) |

### 4.2 Revert check (14 mutations of the reference)

`research/slice-102-revert/mutate.sh`. Each result is a case that fails.

| Mutation | Cases that fail |
| --- | --- |
| No `STRICT` on `compat_hints` | s1 |
| No `WITHOUT ROWID` on `transitions` | s1 |
| `names` without the `typeof` CHECK | s3 |
| `names` without `UNIQUE (kind, value)` | s1, s3 |
| `targets` 21 and 22 swapped | s2 |
| `toolchains` keyed by `nightly` only (the prototype form, G11) | s1, s5 |
| `contributions.result IN (0, 1, 2)` (the `bot-set` code of `crash`) | s4, s5 |
| `releases` label `UNIQUE (form, version)` | s1, s5 |
| `log.time` as TEXT | s1, s4, s5 |
| A foreign key on `compat.artifact` | s1, s5 |
| No index `compat_nightly` | s1 |
| `withdrawn` without its CHECK | s5 |
| `artifacts.kind` CHECK on the old codes (1, 2, 3) | s4, s5 |
| `repos.state` without CHECK | s5 |

## 5. Output (proposed, TW24)

This slice has no command output and no `data` field. The design does not fix these schema details. They are proposals for the human review. The tests check each of them, so the human changes the test and this table together.

| # | Proposal | Reason |
| --- | --- | --- |
| 1 | The columns and types that no design table gives: `artifacts.exposes` (JSON array of module names as TEXT, `'[]'` for an app), `size` (INTEGER, the bytes of the `.tar.zst` asset, Design Q74; no unpacked size), `roc_pin` (TEXT, the header `roc:` value); `releases.tag`, `roc_version` (TEXT, NULL on another host or with no `.roc-version`), `withdrawn` (TEXT or NULL: the wire value of R-AP49, CHECKed against the 6 texts, NULL when not withdrawn; the design lists no codes, so no code column) and `withdrawn_at` (INTEGER ms, NULL when not withdrawn); `compat.error_digest` (TEXT) and `compat.log_index` (INTEGER, NULL for `bot`); `toolchains.asset_name` and `sha256` (TEXT, 64 hex digits); `provenance.claims` and `repo_events.claims` (TEXT, a JSON object of the R-TP6 claims); `repo_events` ids before and after as four INTEGER columns `repository_id_before`, `repository_id_after`, `owner_id_before`, `owner_id_after`; `sweeps.time`, `repos.time`, `repos.state_at`. | R-RE1 to R-RE26 name fields and no types (plan gap G12). R-PU17 says `withdrawn` is "the action and the time"; R-RE26 lists "the time of `withdrawn`": two columns. Slice 103 ports `withdrawn = 0` of `research/bot-set/` to `withdrawn IS NULL`. |
| 2 | The codes of closed sets, as R-IK7 says (position in the list of the rule, from 0): `artifacts.kind` app 0, package 1, platform 2 (R-IK7, differs from `research/bot-set/`, which slice 103 ports); `provenance.via` oidc 0, webhook 1, poll 2, ingest 3; `repos.state` active 0, missing 1, moved 2; `repo_events.action` bind 0, transfer 1, rename 2, recreate 3, missing 4, found 5, successor-set 6, successor-removed 7, offer 8, operator 9; `releases.yanked` 0 or 1 (the wire value is a boolean, R-AP49). | The design lists the values and never the codes except for `source`, `result`, `targets`. `artifacts.kind`, `repos.state`, `provenance.via` and `repo_events.action` are CHECKed. |
| 3 | The CHECKs are those of section 3.2: the prototype ones, and one for each closed set that the design lists (`withdrawn`, `repos.state`, `provenance.via`, `repo_events.action`). `releases.yanked` has none. A closed set is closed on the wire (R-AP44). The set of `side` is a wire value that no column stores. | R-AP44, R-IK7. |
| 4 | `names.kind IN (1, 2, 3)` next to the `typeof` CHECK of R-IK8. | The prototype `names` has it. R-IK2 has no other kind. R-IK2 lists three kinds of name. |
| 5 | No foreign key (`pragma_foreign_key_list` is empty, block 4 of `s1`). | The Worker writes names and rows in one batch (R-IK3); A foreign key costs a parent lookup in each insert, and the row sizes of Registry 5.1 are measured without it. The design lists none. The prototype `releases` of `d1-int-keys` had two; the later prototypes have none. |
| 6 | No default value and no `AUTOINCREMENT`. The Worker writes each column. | The prototypes insert every column. A log index is `max + 1` (R-SG5). |
| 7 | P3 columns are not in `0001`: `provenance.attestation` (R-RE9), `repos.offer` (R-RE11). A P3 migration adds them with `ALTER TABLE ... ADD COLUMN`. `releases.yanked` stays (the live rule of R-MX11 reads it). | Design Q55 and the plan: P2 without P3. |
| 8 | `deps.form`, `version` and `version_text` can be NULL. `version_text` is NULL when the URL has no version (R-RE19), and empty when the key is exact, as in `releases` (R-RE2). `deps.version` is NULL with it. | R-RE19 says null "when the URL has no version". R-RE2 says empty for an exact key. The two agree. |
| 9 | `toolchains.target` is the text of CLI 6.2 (`linux_x86_64`). Every other `target` column (`compat`, `compat_hints`, `contributions`, `sweeps`, `transitions`, `artifact_targets`) is a code of `targets`. | R-RE4 says text. R-IK7 says a code in each matrix row. |
| 10 | Indexes: only the five of the prototypes, with the names of section 3.3. | The plan row says "the indexes of the prototypes". The queries that read `repos` by `repository_id` (R-TP10, R-PU31) and `repo_checks` by `next_check_at` (R-PU37 row 1) may need an index. The slice of that route adds it in a later migration. |
| 11 | `log` columns are `idx` and `grp` (not `index` and `group`: SQL keywords), as in `research/d1-sweep/`. `contributor_totals.first` is the column `first` of R-RE25. | Slice 103 ports the triggers of `d1-sweep` with these names. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| K2 (a `BigInt` parameter gives `D1_TYPE_ERROR`) | A fact of the D1 binding. The runner passes JSON parameters and cannot send a `BigInt`. The platform D1 module tests it (`cloudflare-workers/conformance/`). |
| K7, K8 (`nightly_id`, `name_id`: pure functions) | No database. Slice 104 (`packages/records`, W0). `s4` uses the K8 id as a value. |
| Reads without `CAST` (K3 rounding on D1, `RangeError` on SQLite, `BadData` of the platform) | The behavior of the backend and of the platform decoder, not of the schema. The runner reads rows after the last step and cannot show a rounded read. |
| R-SG6 (KV is not used) | No SQL can show it. See the request in section 8 (R6). |
| R-SG3 (compiler leaves in the log), R-RE8, R-RE13, R-MX8, R-MX12, R-CT13 (triggers) | Slices 103, 109. |
| R-RE10 (`yanks`), R-SG4, R-SG7 | P3 (Design Q55). |
| The "never changed" rows of R-RE6, `INSERT OR IGNORE` of R-RE13 | Slice 103 and the routes. This slice has the keys that make them possible. |
| `wrangler d1 migrations apply` | The runner applies the file by its own splitter. The D1 migration table (`d1_migrations`) is not tested. Slice 101's `wrangler.toml` has `migrations_dir`. |
| The size and speed numbers of Registry 5.1 (`size.mjs`) | A measurement of a prototype, not a test. |

## 7. Questions (stop until answered)

None. Every open point is a schema detail that the design does not fix: they are the proposals of section 5 (TW24).

## 8. Runner requests and notes

| # | Note |
| --- | --- |
| R1 | No change is needed in `sql/tests/run.mjs`. |
| R2 | The runner reads the expected rows after the last step, with no parameters, and a step gives no rows. The case `s4` uses a scratch table `probe` (created in its `setup.sql`) to see the result of a statement with a bound parameter. An optional request for later: `-- rows:` under a step, with the expected rows of that statement. Not needed for this slice. |
| R3 | D1 allows at most 5 terms in a compound `SELECT` (`too many terms in compound SELECT`). `node:sqlite` allows more. The cases use 5 or fewer. |
| R4 | The text of an error depends on the column: a key that is a rowid gives `datatype mismatch`, another INTEGER column gives `cannot store TEXT value in INTEGER column <table>.<column>`. Both backends give the same text (D1 adds `D1_ERROR:` and `: SQLITE_...`). The cases match a part of the text. |
| R5 | `wrangler`/Miniflare leaves no `.wrangler/` dir for the runner (it uses `$TMPDIR`). Checked after the runs. |
| R6 | Request for the code agent (R-SG6): add one check to `worker/tests/frame.sh` (step `w0`): `worker/wrangler.toml` has no `kv_namespaces` entry. Then R-SG6 has a test. This slice's test agent does not edit slice 101 files. |

## 9. Disputes (from the code agent)

None. No test or case was changed.

Harness change (request R6): `worker/tests/frame.sh` has two new lines, a comment line `# R-SG6: ...` and one `grep` check that `worker/wrangler.toml` has no `kv_namespaces` entry (table `[kv_namespaces]`, array `[[kv_namespaces]]` or key `kv_namespaces =`). Nothing else in the file changed. Checked by hand: with a `[[kv_namespaces]]` entry added to `wrangler.toml`, `frame.sh` prints the fault and the step fails; with the file as it was, it passes.

## 10. Verify results

Code step (2026-11-01). The code agent wrote `sql/0001_init.sql` (21 tables, 5 named indexes, 36 `targets` rows) from section 3. It did not read the private reference.

| Run | Result |
| --- | --- |
| `scripts/test.sh w1` | pass (all 5 `schema/*` cases on both backends, 16 runs) |
| `scripts/test.sh w0 w1 w2 check` | w0 pass 0.2 s, w1 pass 2.8 s, w2 pass 6.8 s, check pass 2.0 s |
| `scripts/rules.sh R-RE R-IK R-SG` | Every rule of the three groups has a test, except the rules with no test in this slice: R-RE8, R-RE13 (triggers, slice 103), R-RE10 (P3), R-SG3 (slice 103), R-SG4, R-SG7 (P3). R-SG6 has 1 test (the `frame.sh` check of R6). |
| `.wrangler/` dirs | None left by the code agent. The dirs that exist are old, or gitignored (`research/registry-plan/hello-worker/`). |

Decisions of the code agent that section 3 does not fix: none. The order of the columns and the comments are free (the tests do not check them). `names.value` is `ANY NOT NULL` with the `typeof` CHECK and `UNIQUE (kind, value)` as table constraints. The CHECKs and indexes are as in sections 3.2 and 3.3.

The revert check of the code step is not done here: the test agent did the 14 mutations of section 4.2 on its reference.

Files of the test agent (none of them is an existing file that this slice changes, so there is no `before/` copy; `research/slice-102-revert/before/NEW.txt` lists them):

| Path | What |
| --- | --- |
| `docs/slices/102-schema-tables.md` | This file |
| `sql/0001_init.sql` | The stub |
| `sql/tests/cases/schema/s1-tables` to `s5-keys-and-checks` | The cases (`steps.sql`, `setup.sql`, `expect.tsv`, `rules`) |
| `research/slice-102-revert/` | `reference/0001_init.sql` (private), `run-ref.sh`, `mutate.sh`, `gen-shape.mjs` |
