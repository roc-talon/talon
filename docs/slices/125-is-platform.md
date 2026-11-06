# 125 The platform mark of a dep, Worker side

Phase: P2. Status: review (tests red, 2026-11-03). Model for the code: Sonnet high. About 25 lines of code. Plan row: `docs/registry/PLAN.md` 125. Slice 104i (`records`, green) already has `is_platform : Bool` in `Artifact.Dep`, so the Worker did not build until this slice (stubs below). The slice 119c work waits for a Worker that builds: with the stubs it builds again.

Design: Design Q251, Q400. Registry R-AP81, R-RE19, R-PU38 row 13, R-AP49 (Dep table), R-AP51. The CLI side (Design Q401, Q402) does not change the Worker.

## Rules

| Rule | Effect in the Worker |
| --- | --- |
| R-AP81, R-RE19 | `sql/0001_init.sql`: `deps.platform INTEGER NOT NULL DEFAULT 0 CHECK (platform IN (0, 1))`. No new migration (Design Q163). The `INSERT` of seeds that do not name the column stay valid (default 0). |
| R-PU38 row 13, R-AP81 | `ArchiveRead.header_fields`: the platform entry of a package or platform header is a dep with `is_platform` `true`. Each other dep is `false`. An app has no marked dep: its platform entry is `platform_hash` only (Q128, Q400). |
| R-PU38 row 13, Q400 | 2 or more platform entries (any kind of header): roc refuses them (`multiple_platforms`). `header_fields` gives the new refusal `MultiplePlatforms(aliases)`. The ingest and publish give 422 `not-a-candidate` (`ArchiveRead.problem`, the existing path of the refusals). |
| R-AP81 | Ingest and publish write the mark: `Ingest.Plan.deps[].is_platform`, and the `INSERT INTO deps` writes `platform` (1 or 0). Publish uses `IngestRoutes.writes_of`, so one change serves both. |
| R-AP49, R-AP2 | `Reads.DepRow` and `Reads.dep_of_row` read the mark. `ReadRoutes.deps_sql` selects `d.platform AS is_platform`. The artifact body has `is_platform` in each dep, after `hash` (the `records` encoder writes the order). The bytes and the ETag of the bodies with deps change once (Q251: no Worker is deployed). |
| R-AP17, R-AP49 | `ClosureQuery.DepRow` has the mark. `worker/sql/closure/deps.sql` selects `dp.platform AS is_platform` as the last column. |
| R-AP51 | The member is required on the wire: `Artifact.decode` (104i) already refuses a body without it. |

## Name of the field and its type

| Place | Name and type | Reason |
| --- | --- | --- |
| `Reads.DepRow`, `ClosureQuery.DepRow` | `is_platform : Bool` | `platform` is a reserved word of Roc, and the SQL column of `deps` is `platform`. So the SQL statements select `platform AS is_platform`. The D1 decoder reads the integer 0 or 1 as `Bool` (the same as `app_installed : Bool` of `RepoCheckRow`). |
| `Ingest.Plan.deps[]` | `is_platform : Bool` | The statement binds `1` or `0`. |
| `ArchiveRead.Refusal` | `MultiplePlatforms(List(Str))` | The aliases of the platform entries, in header order, for the `detail`. |

## Stubs (test agent). The code agent replaces each one.

| File | Stub | Code |
| --- | --- | --- |
| `worker/lib/ArchiveRead.roc` | `dep_of` gives `is_platform: Bool.False` (2 places). `MultiplePlatforms` is in `Refusal`, and `detail` has `MultiplePlatforms(_aliases) => crash "todo"`. `header_fields` never gives the refusal. | `dep_of` gets the mark (a parameter). `header_fields` collects the aliases of the entries with `is_platform` (not `roc`), and gives `Err(MultiplePlatforms(aliases))` when there are 2 or more. `detail` text: see Output. |
| `worker/lib/Reads.roc` | `DepRow` has `is_platform : Bool`. `dep_of_row` gives `is_platform: Bool.False`. | `is_platform: dep.is_platform` |
| `worker/lib/ClosureQuery.roc` | `DepRow` has `is_platform : Bool` and the answer copies it (plain copy, no stub). | none |
| `worker/lib/Ingest.roc` | `Plan.deps[]` has `is_platform : Bool`. `plan` gives `Bool.False` (2 places). | `is_platform: d.is_platform` |
| `worker/ReadRoutes.roc` | `deps_sql` selects `0 AS is_platform`. | `d.platform AS is_platform` |
| `worker/sql/closure/deps.sql` | `0 AS is_platform` (last column, a `--` comment marks it). | `dp.platform AS is_platform`, no comment |
| `worker/IngestRoutes.roc` | None. The `INSERT INTO deps` does not name `platform`, so the column keeps its default 0. | Add `platform` as column and `?8` (`if d.is_platform 1 else 0`) |

## Tests (red)

| Layer | File and case | Rules | Red because |
| --- | --- | --- | --- |
| W1 | `sql/tests/cases/schema/s1-tables`: `deps` has 8 columns, `platform INTEGER NOT NULL`. | R-AP81, R-RE19 | green (the schema is a test-agent change, Q163) |
| W1 | `sql/tests/cases/schema/s5-keys-and-checks`: default 0, value 1, value 2 is a CHECK error, NULL is a NOT NULL error, the type is `integer`. | R-AP81 | green |
| W1 | `sql/tests/cases/closure/c2-closure-cte` (`setup.sql` has 8 values for each `deps` row, the dep `c` of the package `A` is marked; `requests.json` deps rows have `is_platform`, 0 or 1, as the last member) | R-AP81, R-AP17, R-RE19 | `deps.sql` gives 0 for the marked dep |
| W0 | `ArchiveReadTest`: `header_fields` of a package with a platform entry has the mark (a header with `json`, `pf`, `alpha`, `roc`: only `pf` is marked, header order, `roc` is the pin); a platform entry with a URL with no version is marked; the 3 headers with 2 platform entries (2 adjacent, 2 with a plain dep between, an app) give `MultiplePlatforms`; `problem(MultiplePlatforms)` is a 422 problem with the text of Output. The other old tests carry `is_platform: Bool.False`. | R-AP81, R-PU38 row 13, Q400 | `Bool.False` / no refusal / `todo` |
| W0 | `ReadsTest`: `artifact_of_rows` (dep `b` of the package is marked in the rows and in the record); the body fixture `body_art` has `"is_platform":false` and `true` after `hash`. | R-AP2, R-AP49, R-AP81 | `dep_of_row` gives `False` |
| W0 | `ClosureQueryTest`: the answer from the rows keeps the mark of dep `pf` (a `true` row gives `"is_platform":true` in the text of `Closure.encode_answer`). | R-AP17, R-AP49, R-AP81 | `dep_of_row` gives `False` |
| W0 | `IngestTest`: `Ingest.plan` of a package with a platform dep: the deps (sorted by alias) carry the mark. The other plans carry `Bool.False`. | R-AP81, R-RE19, R-PU38 row 13 | `plan` gives `False` |
| W2 | `ingest/pu38-platform-mark` (new, made by `worker/tests/tools/mk-platform-mark.mjs`): request 1, a package with `pf: platform` and `semver`: 201, `db.tsv` has `platform` 1 for `pf` and 0 for `semver`. Request 2, the artifact read: `pf` has `is_platform` true, `semver` false (no extra D1 call). Request 3, a package with 2 platform entries: 422 `not-a-candidate`, 1 D1 call, nothing written. | R-AP81, R-PU38, R-RE19, R-AP49, R-AP2, R-AP68, R-AP21, R-PU32 | rows have `platform` 0, no refusal (the asset is written: 201) |
| W2 | `ingest/*/expect/db.tsv` (4 files with the deps query): the query has `platform`, the rows `0`. | R-AP81, R-RE19 | green |
| W2 | `reads/ap2-artifact` (seed marks dep `b` of the package, `responses.jsonl` has the member and the new bytes and ETags, the `if-none-match` of request 5 has the new ETag), `reads/bookmark-session`, `closure/ap17-answer` (seed marks dep `c`, answers), `archive/*` and `ingest/pu4-index-kinds` answers with deps (`is_platform` false). | R-AP81, R-AP2, R-AP17, R-AP49, R-PU38 | the mark is `false` where the fixture says `true` |

Why the new refusal has no W2 case in `archive/`: the ingest case covers the path from the asset to the 422 (the harness has no `roc`: the Worker reads the header itself, and the refusal is the Worker check of Q400, not a roc answer). So there is no fake roc to give `multiple_platforms`.

## Output (proposed, TW24)

| Item | Text |
| --- | --- |
| 422 `detail` for 2 or more platform entries | `main.roc has more than one platform entry (roc refuses it: multiple_platforms): pf, pf2` (the aliases in header order, joined by `, `) |
| `data` fields | none new. The member `is_platform` is Design Q251. |

## Out of scope

| Item | Reason |
| --- | --- |
| The header of a platform kind with a platform entry in the W0 tests | The syntax of such a header for `Header.parse` is not known to the test agent. A platform header goes through the same `header_fields` path as a package. The code agent does not need a separate branch. |
| `Release.pf` and the platform check of the client | CLI slices 206 and later (Q401, Q402). |
| An app record with a marked dep | The Worker never writes it (Q400). No Worker test makes one. |
| The older generator `worker/tests/tools/mk-ingest.mjs` | It is older than some hand edits of the ingest cases (slice 122 `provenance`). It must not run again: it would overwrite the cases. The query line and the rows of the `deps` blocks are edited in the files. |
| `research/slice-110-revert/gen/mk_w1.py` | The W1 closure fixtures are edited in the files. |

## Questions (stop until answered)

None. Q400 answers the two open points of the design (the Worker check, the decoder). The check order (a bad URL of a plain dep before or after the count of platform entries) is not tested: the reference checks the URL of each entry first (as the code before this slice), then the count.

## Red run (test agent, 2026-11-03, `--opt=speed` for W2)

| Layer | Result |
| --- | --- |
| Build | `roc check worker/main.roc` 0 errors (the Worker builds again). `roc fmt --check` of `worker/` is clean. |
| W0 | 437 tests: 8 new or changed tests fail (`ArchiveReadTest` lines 253, 259, 274, 280, 565; `ReadsTest` 417; `ClosureQueryTest` 301; `IngestTest` 360), by a wrong value or by `todo`. The 5 `ReconcileTest` failures are slice 119 (paused) and were there before. |
| W1 | `node sql/tests/run.mjs`: 51 pass. `closure/c2-closure-cte` fails on both backends (`deps` rows have no `is_platform`). The schema cases pass. |
| W2 | 176 pass. Fail: `closure/ap17-answer` (`deps[1].is_platform` expected true), `ingest/pu38-platform-mark` (the mark; the 3rd request gives 502 because the stub reads on to `.roc-version`, with the refusal it ends at 422 before), `reads/ap2-artifact` (body and ETag). The 7 `reconcile/*` failures are slice 119. |

## Private reference and revert checks

Reference: `research/slice-125-revert/reference/` (the 6 stub files with the real code). `research/slice-125-revert/mutate.py` copies it over the stubs, runs the layers, and restores the stubs. Before copies of all changed files: `research/slice-125-revert/before/` (the file `NEW.txt` lists the added files).

Results (2026-11-03): the reference passes W0 (all but the 5 slice 119 tests), W1 (53 of 53) and W2 (all but the 7 slice 119 cases). The stubs are restored. 6 mutants of the reference, all caught:

| # | Layer | Mutation | Caught by |
| --- | --- | --- | --- |
| M1 | W0 | Every dep of a package is marked (`kind != App`), not only the platform entry | `ArchiveReadTest` lines 206, 259 |
| M2 | W0 | The count check is `> 2`: 2 platform entries pass | `ArchiveReadTest` 280 |
| M3 | W0 | The count ignores the platform entries of an app | `ArchiveReadTest` 280 (the app row) |
| M4 | W1 | `closure/deps.sql` reads `a.platform IS NOT NULL` (the owner artifact) in place of `dp.platform` | `closure/c2-closure-cte` |
| M5 | W2 | The ingest `INSERT INTO deps` writes platform 0 for each dep | `ingest/pu38-platform-mark` (`db.tsv`) |
| M6 | W0 | `dep_of_row` inverts the mark | `ReadsTest` 417, 422; `ClosureQueryTest` 301 |

## Revert check on the real code (test agent, TW12, 2026-11-03)

Run on a build copy of `worker/`, `sql/`, `packages/` and `scripts/` (the repo was not changed), with `--opt=speed` for W2. Script: `research/slice-125-revert/mutate-real.py`. The copy with no mutation: W0 only the 5 `ReconcileTest` reds, W1 53 of 53, W2 only the `reconcile/*` reds (slice 119c). Each mutant changes one place of the real code:

| # | Layer | Mutation | Caught by |
| --- | --- | --- | --- |
| M1 | W0 | `header_fields` marks every dep of a package (`kind != App`) | `ArchiveReadTest` 206, 259, 369, 405 |
| M2 | W0 | the count check is `>= 3`: 2 platform entries pass | `ArchiveReadTest` 280 |
| M3 | W0 | the count ignores the platform entries of an app | `ArchiveReadTest` 280 |
| M4 | W1 | `closure/deps.sql` reads `a.platform IS NOT NULL` | `closure/c2-closure-cte` (both backends) |
| M5 | W2 | `IngestRoutes` writes platform 0 | `ingest/pu38-platform-mark` |
| M6 | W0 | `dep_of_row` inverts the mark | `ReadsTest` 417, 422; `ClosureQueryTest` 301 |
| M7 | W2 | `ReadRoutes.deps_sql` selects `0 AS is_platform` | `reads/ap2-artifact`, `ingest/pu38-platform-mark` |

All 7 are caught.

## Disputes (from the code agent)

## Verify results

### Code (code agent, 2026-11-03)

| File | Change |
| --- | --- |
| `worker/lib/ArchiveRead.roc` | `dep_of` has the parameter `is_platform`. `header_fields` passes `entry.is_platform`, collects the aliases of the platform entries, and gives `Err(MultiplePlatforms(aliases))` for 2 or more (after the URL check of each entry). `detail` text as in Output. |
| `worker/lib/Reads.roc`, `worker/lib/Ingest.roc` | `is_platform: dep.is_platform`, `is_platform: d.is_platform`. |
| `worker/ReadRoutes.roc`, `worker/sql/closure/deps.sql` | `platform AS is_platform` (stub removed). |
| `worker/IngestRoutes.roc` | `INSERT INTO deps` has `platform` and `?8` (`if d.is_platform 1 else 0`). |

Choices: none beyond the slice file. About 20 lines changed. Worker fmt run on the 5 .roc files.

### Results

| Step | Result |
| --- | --- |
| w0 | 437 of 442 pass. 5 fail: `ReconcileTest` (slice 119c, as before). |
| w1 | 53 of 53 pass. |
| wbuild, w2 (`--opt=speed`) | 179 pass, 7 fail: `reconcile/*` (slice 119c, as before). |
| check, fmt | pass. |
