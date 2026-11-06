# 100 roc-semver 0.2.0: the 64-bit version key

Phase: P2. Status: review (scope and test agent, 2026-11-01). Tests are red. The code agent has not started.

The work is in the `roc-semver` repository (`/home/george/dev/Karakatiza666/roc-semver`, R-GP5), not in Talon. This file is the only link between the test agent and the code agent (TW18).

## 1. What the design says

| Point | Rule | Text (short) |
| --- | --- | --- |
| API | R-PK2 (`DESIGN.md` 6.1) | From 0.2.0: `Semver.to_key : Semver -> { key : U64, exact : Bool }`, `Semver.from_key : U64 -> Try(Semver, [NotExact])`, `VersionReq.key_bounds : VersionReq -> { lo : U64, hi : U64 }`. |
| Layout | R-IK5 table (`DESIGN-REGISTRY.md` 5.1) | Bits 63 to 48 major, 47 to 32 minor, 31 to 16 patch, 15 to 0 pre-release code. A part of 0xFFFF or more gives 0xFFFF for itself and for each field after it, and the pre-release code is then 0xFFFF. |
| Pre-release code | R-IK5 table | No pre-release: 0xFFFF. Numeric first identifier n: 0x0001 + min(n, 0x0FFE). Alphanumeric first identifier: 0x1000 + 65 x r(c1) + r(c2), from its first 2 characters. r is 0 for no character, 1 for `-`, 2 to 11 for `0` to `9`, 12 to 37 for `A` to `Z`, 38 to 63 for `a` to `z`. The codes 0x0000 and 0x203F to 0xFFFE are not used. |
| Property 1 | R-IK5 | Monotone: when a is before b by semver precedence, key(a) <= key(b). |
| Property 2 | R-IK5 | Exact: when each part is below 0xFFFF and the version has no pre-release and no build metadata, the key gives the version back (`Semver.from_key`). |
| Property 3 | R-IK5 | Two versions with one key are compared with `Semver.order_relative_to`. |
| Examples | R-IK5 | `1.2.3` is `100020003ffff`, `1.2.3-beta1` is `1000200031a11`, `1.2.3-alpha4` is `10002000319d7` (hex). `alpha4` and `alpha10` get one code (the code of `al`). `alpha.4` < `alpha.10` compares numbers. |
| Bounds | R-IK5 query row `range` | "Each version that matches has its key in the bounds, but not each key in the bounds matches", so the Worker checks each row with `VersionReq.matches` (case S5). |
| `unknown` | R-IK5 | The key 0: no version has the pre-release code 0x0000. |
| Reference | `research/semver-key/` (`key.mjs`, `test.mjs`) | S1 monotone, S2 exact round trip, S3 chain and examples, S4 SQLite order (not in this slice), S5 caret bounds are a superset. Mutations `nosat` (S1, S4, S5 must fail) and `prenum` (S1, S4 must fail). |

The numbers in the tests come from `key.mjs`, run in Node 26.7 on the version texts of the tests.

## 2. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-PK2 | The 3 signatures exist in the exposed modules `Semver` and `VersionReq`. | All |
| R-IK5 layout | Fields, saturation, the pre-release codes. | L0 T-K1 to T-K6, T-K14 |
| R-IK5 property 1 | Monotone. | L0 T-K9, T-K13 to T-K15. L1 `semver-key` |
| R-IK5 property 2 | `exact`, and `from_key` of an exact key. | L0 T-K7, T-K16 to T-K20. L1 `semver-key` |
| R-IK5 property 3 | Ties are ordered by `order_relative_to`. | L0 T-K11, T-K12 |
| R-IK5 query row | `key_bounds` holds the key of each matching version. | L0 T-K21 to T-K23. L1 `req-key-bounds` |

## 3. Tests

The new tests are `tests/key.roc` (L0), `fuzz/semver-key.roc` and `fuzz/req-key-bounds.roc` (L1) in `roc-semver`. The ids T-K are local to that repository. A row of a table test is one version text with its expected key and `exact`.

| Layer | Case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | T-K1 | The 3 hex keys of R-IK5. | R-IK5 examples, S3 |
| L0 | T-K2 | Releases with each part below 0xFFFF: `0.0.0` is `0xffff`, `65534.65534.65534` is `0xfffefffefffeffff`, each part in its 16 bits. `exact` True. | R-IK5 layout, S2 |
| L0 | T-K3 | Saturation: a part of 0xFFFF, 0x10000, 2^32 - 1 or U64 max gives 0xFFFF for itself and for each field after it. `exact` False. | R-IK5 layout, S1 |
| L0 | T-K4 | After a saturated part, a pre-release also gives code 0xFFFF (`65536.8.0-b.-`). | R-IK5 layout, S1 |
| L0 | T-K5 | Numeric first identifier: 0, 1, 4093, 4094, 4095, 99999, a 30-digit number (above U64 max), `0.5`, `1.alpha`. | R-IK5 code |
| L0 | T-K6 | Alphanumeric first identifier: 21 rows with the hand-computed codes (`a`, `-`, `--`, `0a`, `1-`, `9z`, `A`, `Z`, `Zz`, `z`, `zz`, `x-y`, `alpha4`, `alpha.4`, `rc`). | R-IK5 code |
| L0 | T-K7 | `exact` flag: True for plain releases. False for build metadata, a pre-release, a part of 0xFFFF or U64 max. | R-IK5 property 2 |
| L0 | T-K8 | Build metadata does not change the key. | R-IK5, semver 10 |
| L0 | T-K9 | The chain of semver 11.4 is in strict precedence order and has keys in order. | R-IK5 property 1, S3 |
| L0 | T-K10 | `1.2.3-alpha4` < `1.2.3-beta1` < `1.2.3` with 3 different keys, exact False, False, True. | R-IK5 example, S3 |
| L0 | T-K11 | `alpha10` before `alpha4`, one key. | R-IK5 property 3 |
| L0 | T-K12 | `alpha.4` before `alpha.10`, one key. | R-IK5 |
| L0 | T-K13 | A numeric first identifier has a smaller key than an alphanumeric one (`0.6.65534-0.0` is `0x6fffe0001`, below `-A`). | R-IK5 code, S1 mutation `prenum` |
| L0 | T-K14 | `65536.8.0-b.-` has a key not above the key of `4294967295.0.0-99999.beta`. | R-IK5 layout, S1 mutation `nosat` |
| L0 | T-K15 | 37 versions in strict precedence order with all the edges. Every pair (a, b) with a before b has key(a) <= key(b). | R-IK5 property 1, S1 |
| L0 | T-K16 | `from_key(to_key(v).key) == Ok(v)` for 7 exact versions. | R-IK5 property 2, S2 |
| L0 | T-K17 | `from_key(0x100020003ffff) == Ok(1.2.3)` and `from_key(0xffff) == Ok(0.0.0)` (2 `expect`s). | R-IK5 example |
| L0 | T-K18 | The key of a pre-release, or of a saturated part, gives `Err(NotExact)`. | R-PK2, S2 |
| L0 | T-K18b | The key of `1.2.3+build.5` gives `Ok(1.2.3)` (reading of the reference, question Q2). | R-IK5 property 2 |
| L0 | T-K19 | Keys no version has give `Err(NotExact)`: 0, code 0x0000, 0xFFFE, 0x203F, a field of 0xFFFF, U64 max. | R-PK2 (reference) |
| L0 | T-K20 | When `from_key` gives a version, `to_key` of it gives the same key and `exact` True. | R-IK5 property 2 |
| L0 | T-K21 | Caret bounds of the reference: `^1.2.3` is `{lo: 0x100020003ffff, hi: 0x200000000ffff}`, `^0.2.3` is `{0x20003ffff, 0x30000ffff}`, `^0.0.3` is `{0x3ffff, 0x4ffff}`. | R-IK5 query row, S5 |
| L0 | T-K22 | 50 requirements (all forms of the README, edge parts, U64 max, ranges that match nothing) against 175 release versions (7 majors x 5 minors x 5 patches with the edges). No pair matches with its key outside the bounds, and more than 500 pairs match. `key_bounds` does not crash. | R-IK5 query row, S5 |
| L0 | T-K23 | The bounds of `*` hold the key of `0.0.0` and the keys of saturated versions. | R-IK5 query row |
| L1 | `fuzz/semver-key.roc` | Two versions (the second often near the first, as in `near` of `test.mjs`) with the edge values, pre-releases, a number above U64 max and build metadata. Before gives key <=, After gives key >=, Same gives equal keys. `exact` is True exactly for a release with parts below 0xFFFF and no build. An exact key gives the version back. For keys made from 16-bit fields and for any U64: `from_key` gives a version exactly when the code is 0xFFFF and the 3 parts are below 0xFFFF, and `to_key` of it gives the same key with `exact` True. | R-IK5 properties 1 and 2, R-PK2, S1, S2 |
| L1 | `fuzz/req-key-bounds.roc` | A requirement (operator, 1 to 3 parts, a wildcard, a second comparator, or `*`) and a release version, parts from `{0, 1, 2, 3, 65534, 65535, 65536, U64 max}`. When the requirement matches, the key is in `lo` to `hi`. | R-IK5 query row, S5 |

L1 uses the repo's fixed count: `scripts/test.sh` runs each target with `--runs=100000 --seed=1 --time=0` (TW6).

Count: 25 new `expect`s in `tests/key.roc` (T-K17 has 2), 2 new fuzz targets. The old tests are 103 (`tests/semver.roc`) and 146 (`tests/version_req.roc`) `expect`s and 3 fuzz targets.

## 4. Public surface (done by the test agent)

| File | Change |
| --- | --- |
| `package/Semver.roc` | `to_key` and `from_key` with the R-PK2 signatures and a doc comment. Bodies `crash "todo"`, parameter `_x`. |
| `package/VersionReq.roc` | `key_bounds` with the R-PK2 signature and a doc comment. Body `crash "todo"`. |
| `package/main.roc` | No change: the package exposes the modules `Semver` and `VersionReq`, and the methods are part of them. |

## 5. Red output (test agent, 2026-11-01)

The pinned compiler: `nightly-2026-10-14-38a3029` (`.roc-version`), from `talon/cloudflare-workers/.cache/nightlies/`. Command: `scripts/test.sh $ROC` in `roc-semver`.

| Check | Result |
| --- | --- |
| `roc check package/main.roc`, `roc check` of all tests and fuzz files | Pass |
| `roc fmt --check package tests fuzz` | Pass |
| `roc test tests/semver.roc` | 103 passed |
| `roc test tests/version_req.roc` | 146 passed |
| `roc test tests/key.roc` | 0 passed, 25 failed. Each failure is `todo`. |
| `fuzz/semver-order`, `semver-roundtrip`, `req-caret` (100,000 runs) | Pass |
| `fuzz/semver-key`, `fuzz/req-key-bounds` | Fail with `[roc crashed] todo` at the first input |

The test agent checked that the tests are right, with a throw-away implementation in the scratchpad of the session (not in any repository, not given to the code agent). With it, all 25 `expect`s pass and the 5 fuzz targets pass at 100,000 runs. These mutations of it made the tests fail:

| Mutation | Failing tests |
| --- | --- |
| No saturation of the fields after a large part (`nosat`) | T-K3, T-K4, T-K7, T-K14, T-K15, T-K22. L1 `semver-key` |
| Numeric first identifier above the alphanumeric codes (`prenum`) | T-K5, T-K13, T-K15. L1 `semver-key` |
| Numeric cap 0x0FFD in place of 0x0FFE | T-K5 |
| Number above U64 max read as 0 | T-K5 |
| `exact` True for build metadata | T-K7 |
| `from_key` ignores the patch field of 0xFFFF | T-K18, T-K19. L1 `semver-key` |
| `hi` one below the right value | T-K21, T-K22. L1 `req-key-bounds` |
| `lo` one above the right value | T-K21, T-K22, T-K23. L1 `req-key-bounds` |

## 6. Notes for the code agent

| Note | Detail |
| --- | --- |
| Where | `package/Semver.roc` (`to_key`, `from_key`) and `package/VersionReq.roc` (`key_bounds`). `Comparator` (`package/Internal/Comparator.roc`) is opaque and keeps `lower` and `upper` as `[At(U64, U64, U64), End]`, so `key_bounds` needs a read of them. |
| Reference | `research/semver-key/key.mjs` in Talon (`toKey`, `fromKey`, `preCode`, `rank`, `caretBounds`). It uses `BigInt`. Roc `+` and `*` on `U64` crash on overflow. |
| Pitfalls found while the tests were made | A numeric pre-release identifier can have more than 20 digits and does not fit in `U64`: it gives the maximum code, with no crash. A part of U64 max must not overflow. `Lex.number` and `Comparator` already treat U64 max (Q10). A top-level value that calls a `todo` function stops `roc check` at compile time: this is why the tests call the functions inside `expect`. |
| One valid way for `key_bounds` | `lo` is the largest key of the `lower` bounds (key of `At(a, b, c)`, the release `a.b.c`), `hi` is the smallest key of the `upper` bounds, with `End` as U64 max. This holds R-IK5 for each comparator list. It gives `lo > hi` for a range that matches nothing (question Q3). |
| Docs | Update the table of modules and the "Tests" and "Release" sections of `README.md`. The release (tag `0.2.0`, workflow) is not part of this slice. |
| Tests | Do not edit `tests/key.roc` or the fuzz files (TW18). A wrong test is a dispute in section 9. |
| Run | `ROC=<pinned roc> scripts/test.sh $ROC` in `roc-semver`. About 10 s. |

## 7. Out of scope

| Item | Where |
| --- | --- |
| The release `0.2.0` (tag, `roc bundle`, workflow, the new URL) | The user, after the review. The plan row 100 says "release". |
| The Talon headers move to 0.2.0 (R-GP3) | With `tln`, after the release. No path entry (CLAUDE.md). |
| The stored form (`key XOR 2^63`), the SQLite order (S4), `version_text`, the series bounds (R-IK5 `?series=`) | Slice 105 |
| Tight bounds for all range forms | Question Q1 |
| `Semver.order_relative_to` and the parser | Done in 0.1.0, not changed |
| `scripts/revert-check.sh` and `scripts/rules.sh` | Talon scripts, they do not read this repository. The mutation table in section 5 is the revert list. |

## 8. Questions (stop until answered)

| # | Question | Effect now |
| --- | --- | --- |
| Q1 | Must `key_bounds` be tight for the forms other than a caret of 3 parts? R-IK5 gives only the superset property. The reference tests `^M.m.p` only, and its README says that the other forms "need the same superset property". The tests check exact `lo` and `hi` for `^1.2.3`, `^0.2.3` and `^0.0.3`, and only the superset for all other forms. `{lo: 0, hi: U64 max}` would pass T-K22 (but not T-K21). Do the human want exact values for `^1.2`, `~1.2.3`, `>=1.2`, `1.2.3`, and `*`? | The code agent may use any superset for the other forms. No test checks tightness. |
| Q2 | `from_key` on a key that no version has, and on the key of a version with build metadata: R-IK5 does not say. The tests follow `fromKey` of the reference: `Ok` exactly when the code is 0xFFFF and the 3 parts are below 0xFFFF, so the key of `1.2.3+b` gives `Ok(1.2.3)` and the unused codes (0x0000, 0x203F to 0xFFFE) give `Err(NotExact)`. Is that right? | T-K18b, T-K19 and the L1 check of `from_key` follow the reference. |
| Q3 | A range that matches nothing (`>2, <1`) can give `lo > hi`. SQL `BETWEEN` gives no row then, which is right. Is `lo > hi` allowed, or must `lo <= hi` hold? | No test. |

If Q1 is settled with "tight", the test agent adds the cases and the design names the bounds per form (R-IK5 query row). If Q2 or Q3 is settled in another way, the design states it in R-IK5 and the test agent changes T-K18b, T-K19 or adds a case.

Answers (manager review, 2026-11-01):

| # | Answer |
| --- | --- |
| Q1 | The superset property is the rule (R-IK5). The exact values for the 3-part caret forms stay as tests. The other forms need only the superset. |
| Q2 | Follow the reference `fromKey`: `1.2.3+b` gives `Ok(1.2.3)`, and the unused codes give `Err(NotExact)`. |
| Q3 | Allowed. A range that matches nothing can give `lo > hi`. SQL `BETWEEN lo AND hi` then gives no rows. No test is needed. |

Review: the tests are accepted by the manager (2026-11-01). The human review is pending.

## 9. Disputes (from the code agent)

None.

## 10. Verify results (code agent, 2026-11-01)

Command, in `roc-semver`: `scripts/test.sh $ROC` with `ROC` the pinned `nightly-2026-10-14-38a3029`. Exit 0, "ALL PASS", 15.6 s in total.

| Check | Result |
| --- | --- |
| `roc check package/main.roc`, `roc check` of each test and fuzz file | 0 errors |
| `roc fmt --check package tests fuzz` | All formatting valid |
| L0 `tests/key.roc` | 25 passed |
| L0 `tests/semver.roc` | 103 passed |
| L0 `tests/version_req.roc` | 146 passed |
| L1 `semver-order`, `semver-roundtrip`, `req-caret`, `semver-key`, `req-key-bounds` | 5 of 5 pass at 100,000 runs, seed 1 (0 to 3 s each) |

Files changed in `roc-semver`: `package/Semver.roc` (`to_key`, `from_key`, helpers `field_max`, `saturated_after`, `pre_release_code`, `char_rank`), `package/VersionReq.roc` (`key_bounds`, helper `bound_key`), `package/Internal/Comparator.roc` (methods `lower_bound` and `upper_bound`, to read the opaque fields), `README.md` (module table, "Order key" section, test row). The repo has no changelog, so there is no 0.2.0 entry. The "Usage" URL in the README still names 0.1.0: it changes at the release.

Decisions: `key_bounds` follows the way in section 6 (`lo` is the largest key of the lower bounds, `hi` the smallest key of the upper bounds, `End` is U64 max). A numeric pre-release identifier is capped at each digit step, so a long number does not overflow. No test, fuzz target or fixture was changed. The revert check was not part of this task.

Release (manager, 2026-11-01): roc-semver commit `31a8594`, release workflow run 41330900359 passed (bundle tests on ubuntu-24.04 and macos-26). Release 0.2.0: `https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst`. The local bundle with the 10-14 nightly gave the same hash. README URL: `8cdb94d`. Status: done.
