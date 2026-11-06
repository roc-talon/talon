# 105 Version columns

Phase: P2. Status: review (scope and test agent, 2026-11-01). The W0 tests are red. The code agent has not started. Model for the code: Sonnet medium. Plan row: `docs/registry/PLAN.md` C.1, row 105.

This file is the only link between the test agent and the code agent (TW18).

## 1. Scope

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Version.roc`: the pure functions (section 3) | Test agent (signatures, doc comments), code agent (bodies) | Bodies are `crash "todo"`, parameters `_x` |
| `worker/lib/main.roc` and `worker/main.roc` headers: `semver` is the roc-semver 0.2.0 release URL (R-GP3, no path) | Test agent | Done. `worker/tests/unit/w0.roc` has the same entry. |
| W0 tests `worker/tests/unit/VersionTest.roc` (in the driver `w0.roc`) | Test agent | Red (section 5) |
| W1 case `sql/tests/cases/versions/v1-order-bounds-filter/` | Test agent | Green at once: it tests SQL text and the schema of slice 102 with fixed numbers. Section 4. |
| Bodies of `Version` | Code agent | To do. The code agent changes no test and no header. |

### 1.1 Where the code lives

| Option | Choice | Reason |
| --- | --- | --- |
| `worker/lib/Version.roc` | Yes | Only the Worker reads and writes the columns (routes 106, 110, 112). Plan section B puts "the version key bounds" in W0 of `worker/`. `packages/records` has "No dependency" (its header), and a roc-semver dependency would force the 0.2.0 URL on the CLI side, which stays on 0.1.0 (PLAN A.1). |
| `packages/records` | No | The CLI has no use for the stored form yet (PLAN G16, Design Q68). A CLI slice can move the module later. Then the W0 test must also build on `ROC_TAG`. Not now: this slice builds on `ROC_TAG_WORKER` only. |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-IK5 column `version` | `key XOR 2^63` as a signed INTEGER. Bound as text, read with `CAST(version AS TEXT)`. | W0 `to_stored`, `column`; W1 v1 |
| R-IK5 column `version_text` | Empty for an exact key, else `Semver.to_str`. | W0 `column`, `read`; W1 v1 |
| R-IK5 properties 1 and 3 | The stored order is the key order. Ties are put right with `order_relative_to`. | W0 chain and `sort_precedence`; W1 v1 (case S4) |
| R-IK5 `?series=` | Series bounds as column values. A part of 65535 or more: the Worker checks `series_of` of each row. | W0 `series_bounds`, `series_of`; W1 v1 |
| R-IK5 `range` | `BETWEEN` the bounds of `VersionReq.key_bounds`, then `VersionReq.matches` on each row. | W0 `range_bounds`, `filter_range`; W1 v1 (case S5) |
| R-IK2 (platform rule) | A value of 2^53 or more is bound as text and read with `CAST(x AS TEXT)`. So each column value of `Version` is a `Str`. | W0 `column`, `read`; W1 v1 |
| R-AP41 row 4 | The list of rows is one JSON parameter. | W1 v1 (`json_each`) |

## 3. Public surface (`worker/lib/Version.roc`)

| Function | Type | Rule of the body |
| --- | --- | --- |
| `to_stored` | `U64 -> I64` | `key XOR 2^63`, read as `I64` (`bitwise_xor`, `to_i64_wrap`) |
| `from_stored` | `I64 -> U64` | The inverse |
| `column` | `Semver -> Version.Column` | `{ version: I64.to_str(to_stored(key)), version_text: "" if exact else v.to_str() }` |
| `read` | `Version.Column -> Try(Semver, [BadColumn])` | `version_text` not empty: `Semver.parse`. Empty: `from_key(from_stored(I64.from_str(version)))`. Every failure is `Err(BadColumn)`. |
| `series_of` | `Semver -> Str` | `"M"` for a major of 1 or more, else `"0.m"` |
| `series_bounds` | `Str -> Try(Version.Bounds, [BadSeries])` | Doc comment of the stub. Strict number form: decimal digits only, no leading zero, fits `U64`. |
| `range_bounds` | `VersionReq -> Version.Bounds` | `key_bounds`, each end through `to_stored` and `I64.to_str` |
| `filter_range` | `VersionReq, List(Semver) -> List(Semver)` | `keep_if` with `VersionReq.matches`, order kept |
| `sort_precedence` | `List(Semver) -> List(Semver)` | `sort_with` of `order_relative_to` |

Types: `Version.Column : { version : Str, version_text : Str }`, `Version.Bounds : { lo : Str, hi : Str }` (both ends inclusive).

## 4. SQL form (for the route slices 106, 110, 112)

| Query | SQL (bind the bounds as text, read with CAST) |
| --- | --- |
| Insert | `INSERT INTO releases (..., version, version_text, ...) VALUES (..., ?, ?, ...)` with `Version.column(v)`. The column affinity makes the text an INTEGER (R-IK2). |
| Read | `SELECT CAST(version AS TEXT), version_text, ... FROM releases ... ORDER BY version, version_text`, then `Version.read` and `Version.sort_precedence` |
| `?series=` | `WHERE version BETWEEN ?1 AND ?2` with `Version.series_bounds(series)`, then keep the rows with `series_of(read) == series` |
| `range` | `WHERE version BETWEEN ?1 AND ?2` with `Version.range_bounds(req)`, then `Version.filter_range` |

The W1 case v1 tests these forms with 23 releases that go in out of order (one JSON parameter): the order of `ORDER BY version`, one tie group of 4 and one of 2 (SQL gives the order of `version_text`, so it is wrong for `alpha.10` and `alpha.4`: the code sorts), the series `1`, `0.2` and `65535` (the last holds `70000.1.2`), and the superset of `^1.2.3` (it holds `2.0.0-alpha`, `2.0.0-rc` and `2.0.0`). W1 uses literal `CAST('..' AS INTEGER)` bounds: the runner passes no parameter to the final queries.

## 5. Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| W0 | `VersionTest.roc`: `to_stored` and `from_stored` on 7 keys (0, 0xFFFF, the sign edge, U64 max) | R-IK5 column |
| W0 | `column` on 10 texts (exact, pre-release, ties, build, 3 saturated) | R-IK5 column, `version_text`, R-IK2 |
| W0 | `read` round trip on the same 10 rows, and 5 bad columns | R-IK5 properties 2, 3 |
| W0 | A chain of 19 versions: stored values never fall; `alpha10` and `alpha4` share a value | R-IK5 property 1 (S4) |
| W0 | `sort_precedence` (`alpha10` before `alpha4`, `alpha.4` before `alpha.10`) | R-IK5 property 3 |
| W0 | `series_of` (7 rows), `series_bounds` (5 rows, 13 bad texts) | R-IK5 `?series=` |
| W0 | `range_bounds` (`^1.2.3`, `>=1.2.3`, `*`) | R-IK5 `range`, S5 |
| W0 | `filter_range` (3 requirements on supersets) | R-IK5 `range`, S5 |
| W1 | `versions/v1-order-bounds-filter` on node:sqlite and local D1 | R-IK5, R-IK2, R-AP41 row 4 |

Count: 24 `expect`s in `VersionTest.roc`, 1 W1 case.

The W1 case has a file `migrations` with `0001` (added by the test agent of slice 103, 2026-11-01). It tests the order of the version keys, not the log. It inserts `releases` rows with no leaf, and the leaf check trigger of `sql/0002_triggers.sql` (slice 103, R-SG8 row 5) would stop them. With `migrations`, the case runs on the tables only.

Red output (`roc test worker/tests/unit/w0.roc` with `nightly-2026-10-31-f7bef6b`): 47 tests, 23 passed (slice 101), 24 failed, 0 compiler errors. Each failure is `Roc application crashed with this message: todo`. `roc fmt --check` and `roc check worker/main.roc` pass. `node sql/tests/run.mjs versions`: 2 passed (sqlite, d1).

The numbers come from `research/semver-key/key.mjs` (`stored`). Copies of the changed files: `research/slice-105-revert/before/` (list of new files in `NEW.txt`). No mutation sweep was run (user rule).

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The key of `tln` and `unknown` (key 0 = stored `-9223372036854775808`) in R-CT12 | Slice 116 |
| The SQL file `sql/queries/*.sql` and the D1 call | Slices 106 and 110 |
| `Semver.to_key` itself (R-PK2) | Slice 100, tested in `roc-semver` (R-GP5) |
| A BigInt parameter (R-IK2 K2) | A fact of the platform binding, not of this module |

## 7. Questions

| # | Question |
| --- | --- |
| Q1 | The series text for the major 0 is "0.m" only; "0" alone is `BadSeries` (R-ID1: below 1.0 the series is `0.minor`). The design does not say what `?series=0` gives. The tests expect `BadSeries`, and the route (400 `bad-request`, R-AP13) decides. Is this right? |
| Q2 | For "0.m" with m of 65535 or more, R-IK5 says "the interval goes to the largest key". The stub and the tests read it as the keys of major 0: up to `0x0000FFFFFFFFFFFF`, not `U64.highest`. Is this right? |
| Q3 | The `read` of a row with a non-empty `version_text` does not compare it with the key. A bad row is the database's fault (the trigger slice owns the check). Is this right? |


Answers (manager, 2026-11-01):

| # | Answer |
| --- | --- |
| Q1 | Yes. A series of major 0 is `0.m` (Design 4.1, R-ID1), so `0` alone is `BadSeries`. |
| Q2 | Yes, `0x0000FFFFFFFFFFFF`: the largest key of major 0, because the series stays in major 0. The Worker then checks the series of each row (R-IK5). |
| Q3 | No check in `read`. The write path computes `version` and `version_text` from one `Semver`, so they cannot differ. No trigger checks them. |

Review: tests accepted by the manager (2026-11-01). The human review is pending.

## 8. Disputes (from the code agent)

| Test | Problem | Design source | State |
| --- | --- | --- | --- |
| `VersionTest.roc` line 116: `range_bounds(req("*")) == { lo: "-9223372036854775808", ... }` | The `lo` is the stored form of key 0. But `roc-semver` 0.2.0 `VersionReq.key_bounds` for `*` gives `lo` = the key of `0.0.0` (`0xFFFF`), because the lower bound of `*` is `At(0, 0, 0)` (`Comparator.any`). So `to_stored` of it is `-9223372036854710273`. Section 3 says the body of `range_bounds` is `key_bounds` through `to_stored`: no other value is possible without a special case that the slice does not give. The `hi` is right. The roc-semver test T-K23 also says the bounds of `*` hold the key of `0.0.0`. | R-IK5 `range` (bounds hold each match), slice section 3 | Test not changed. The expected `lo` should be `-9223372036854710273`, or the design must say that `*` starts at key 0. Manager to decide. |

## 9. Verify results

| Check | Result |
| --- | --- |
| `roc check` and `roc fmt` of `worker/lib/Version.roc` (ROC_TAG_WORKER) | 0 errors, formatted |
| `scripts/test.sh w0` | 46 passed, 1 failed (the dispute above). The 23 slice 101 tests and the other 23 slice 105 tests pass. |
| `scripts/test.sh w1` | `versions/v1-order-bounds-filter` passes on sqlite and d1. 8 failures, all in `triggers/*` (slice 103, `sql/0002_triggers.sql` landed during the run), not in `versions`. |
| `scripts/test.sh w2` | pass |
| Revert check | Not run: w0 is not green. |

## 8. Dispute (resolved)

The code agent disputed the `*` row of `range_bounds`. `key_bounds` of `*` gives lo = the key of 0.0.0 (0xFFFF), because a release has no pre-release key below it (roc-semver T-K23). The test now expects lo `-9223372036854710273`; hi is `9223372036854775807`. Resolved.
