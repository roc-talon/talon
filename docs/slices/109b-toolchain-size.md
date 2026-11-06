# 109b Toolchain row size

Phase: P2. Status: review (tests red, 2026-11-02). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` 109b. Depends on slice 109. Goes with 104h (`records` `Toolchain.Row.size`, not in this slice).

## 1. Scope

The toolchain row gets `size`: the byte size of the asset from the GitHub release, written once with the row (Design Q340, R-AP80).

| Part | Who | State |
| --- | --- | --- |
| `sql/0001_init.sql`: `toolchains.size INTEGER NOT NULL CHECK (size > 0)`, placed after `sha256`. No new migration. | Code agent | Not done. The test agent does not edit `sql/`. |
| `worker/lib/Toolchains.roc`: `Asset` has `size`, `Picked`, `Write`, `Row` carry it, `row_text` writes it after `sha256` | Test agent (types, placeholders `size: 0`), code agent (bodies) | Types done |
| `worker/ToolchainRoutes.roc`: `columns` and the insert SQL carry `size` | Code agent | Only the doc comment changed |
| Tests: W0 `ToolchainsTest.roc`, W1 (section 4.3), W2 (section 4.2) | Test agent | Red |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP80 | The wire row has `tag, target, asset_name, sha256, size, published_at, log_index`. `size` is a whole number above 0, from the asset `size` of the release. | W0 `parse_release`, `select_assets`, `writes_of`, `put_body`. W2 all `toolchains/*` bodies and `db.tsv`. W1 `s1-tables`, `s5` |
| R-AP57 step 6, R-PU8 | An asset with a missing, `null`, fraction, negative or 0 `size` is not an asset for its host. The other hosts stay. None left: 422. A bad asset does not count for the rule of 2 assets. | W0 `select_assets`, `candidates`. W2 `pu-size-rules` |
| R-PU9, R-PU10 | A later PUT keeps the recorded row, also its `size` | W2 `pu-digest-kept` (the second GitHub answer has other sizes) |
| R-SG3, R-SG8 | `size` is not in the compiler leaf and not in `toolchains_leaf_check` | W2 `pu-size-rules` (`log` rows), all `pu-*` (`log` rows) |
| R-RE4 | The column is `INTEGER NOT NULL CHECK (size > 0)` | W1 `s1-tables`, `s5-keys-and-checks` (0, -5, NULL, 12.5 are errors) |

## 3. What the code agent writes

| File | Change |
| --- | --- |
| `sql/0001_init.sql` | Column `size INTEGER NOT NULL CHECK (size > 0)` after `sha256` in `toolchains` (STRICT table) |
| `worker/lib/Toolchains.roc` | `Asset.size : Try(U64, [Missing])` read from the release JSON (a whole number; `"size":null` needs the same hack as `digest`, see `null_digests_out`); `picked_for` requires `Ok(size)` with `size > 0`; `writes_of` uses `p.size` (now the placeholder `size: 0`); `row_text` writes `"size"` after `sha256` |
| `worker/ToolchainRoutes.roc` | `columns` and the insert SQL carry `size` (one more bind) |

The private reference has the change in about 25 lines.

## 4. Tests

### 4.1 W0 (`worker/tests/unit/ToolchainsTest.roc`, 81 expects)

| Check | Rule |
| --- | --- |
| `parse_release`: `size` 123 is `Ok(123)`; missing and `null` are `Err(Missing)`; 0 is `Ok(0)`; 12.5 and -5 are `Err(Missing)` | R-AP80 |
| `select_assets`: a bad size drops the asset for its host only; a bad asset does not count for the rule of 2 assets (size 1 is good); real releases give the real sizes | R-AP57 step 6 |
| `candidates`: only bad sizes: `no_candidate` | R-AP57 step 6 |
| `writes_of`, `put_body`: `size` after `sha256` | R-AP80 |

### 4.2 W2

| Case | Change |
| --- | --- |
| `toolchains/*` (12 cases) | Made again by `research/slice-109b-revert/mk_cases.py`: the GitHub assets have `size` (real sizes for the real releases), the bodies and `db.tsv` have the column, the seeds have a `size` (1000 + `log_index`). R-AP80 added to the rules of `pu-new-tag`, `pu-odd-sha-names`, `pu-asset-rules`, `pu-digest-kept`, `get-query`, `get-pages`. |
| `toolchains/pu-size-rules` (new) | Tag A: `size` missing, 0, 1, `null`, 12.5, -5, and 2 assets for one host (one with size 0): 201 with 2 rows (`linux_x86_64` with the good asset of size 1, `windows_x86_64`); the `log` rows are the same as before (no `size` in the leaf). Tag B: a bad size for each host: 422 `not-a-candidate`. D1 calls 2 and 1. |
| `pu-digest-kept` | The second GitHub answer has other sizes; the recorded rows keep their sizes. |
| Seeds of other areas | The `INSERT INTO toolchains` lines get the column list with `size` (1000 + `log_index`): 34 `seed.sql` files in `account` (5), `closure/ap17-answer`, `compat` (10), `githubtoken` (3), `hints` (8), `oidc` (7). The expected bodies of the 7 `oidc/*/expect/responses.jsonl` have `"size":1001` after `sha256`. Made by `research/slice-109b-revert/fix_seeds.py`. |

Seeds of other areas fail with `no column named size` until the code agent adds the column. This is the expected red state, and it is the wrong reason for those cases.

### 4.3 W1 (`sql/tests`)

| File | Change |
| --- | --- |
| `schema/s1-tables/expect.tsv` | `toolchains` has 8 columns, new line for `size` (the file is red for `contributor_totals` of another slice too) |
| `schema/s5-keys-and-checks` (`steps.sql`, `expect.tsv`, `rules`) | 4 failing inserts: `size` 0 and -5 (`CHECK constraint failed`), NULL (`NOT NULL constraint failed: toolchains.size`), 12.5 (`cannot store REAL value`); the stored `size` is read back |
| `triggers/t1-publish`, `t2`, `t3`, `t5` (2 files), `t6`, `compat/a1-audit`, `closure/c3-order-window`, `closure/c1-random-reference/test.mjs`, `sql/tests/compat.mjs` | The inserts name the columns and give `size`. `t1` uses a literal `1000` in `INSERT ... SELECT`, so the `params` stay. Made by `fix_w1.py`. |

### 4.4 Results

| Step | Result |
| --- | --- |
| Reference, W0 | 81 of 81 pass |
| Reference, W1 | all cases of this slice pass; `closure/c2-closure-cte` and `schema/s1-tables` also fail for the `vias` and `contributor_totals` of other slices |
| Reference, W2 | `toolchains` 13 of 13, `oidc`, `hints`, `githubtoken`, `compat` all pass; `account/*` and `closure/ap17-answer` fail for other slices (`contributor_totals.last_time`, `provenance`, `/v1/tokens`), not for `size` |
| Red W0 (before the bodies) | 81 expects: 64 pass, 17 fail (size related). 0 compiler errors. |
| Red W2 | Not counted as a number: every case with a `toolchains` seed fails with `no column named size` (53 cases), and the `toolchains/*` bodies fail until the code is changed. |

### 4.5 Revert check (private reference `research/slice-109b-revert/`, `ref.sh`, `run_mutations.sh`, `mutations.log`)

| Mutation | Caught by |
| --- | --- |
| m1 `size` in the leaf hash | W2 `pu-new-tag`, `pu-odd-sha-names`, `pu-asset-rules`, `pu-digest-kept`, `pu-digest-rules`, `pu-id-collision`, `pu-size-rules` |
| m2 a size of 0 is accepted | W0 (3 expects), W2 `pu-size-rules` |
| m3 `size` after `published_at` in the wire row | W0 (4 expects), W2 8 cases (`get-query`, `pu-*`) |
| m4 a size with a fraction is cut and accepted | W0 (1 expect), W2 `pu-size-rules` |
| m5 a later PUT replaces the row (size rewritten) | W2 `pu-digest-kept`, `pu-id-collision`, `pu-new-tag` |

All 5 mutations are caught. The full results are in `research/slice-109b-revert/mutations.log`.

### 4.6 Code agent result

| Item | Result |
| --- | --- |
| `sql/0001_init.sql` | Column added after `sha256`. |
| `Toolchains.roc` | `picked_for` needs `Ok(size)` above 0; `writes_of` uses `p.size`; `row_text` writes `size`. `null_digests_out` calls `size_whole`: a `size` that is `null`, negative or with a fraction becomes another member, so the size is missing. |
| `ToolchainRoutes.roc` | `columns` and the insert SQL carry `size`. |
| W0 | `ToolchainsTest` all pass. Other failures are other slices. |
| W1 | 49 pass. 4 fail: `c2-closure-cte`, `s1-tables` (other slices). |

## 5. Output

The row form is given by R-AP80. No new output text.

## 6. Out of scope

| Item | Reason |
| --- | --- |
| A `size` that is a JSON text (`"123"`) | Roc has no generic JSON value type here. The derived reader refuses the text, so the release is a bad release (502) or the asset is dropped; the code decides. Not tested. |
| `records` `Toolchain.Row.size` | Slice 104h |
| The CLI use of `size` (total download size, R-DL1) | CLI slice 204 |
| The column in `sql/0001_init.sql` | Code agent (test agent does not edit `sql/`) |

## 7. Questions

None. Design Q340 and R-AP80 give the rules.

## 8. Files

| File | Kind |
| --- | --- |
| `worker/lib/Toolchains.roc` | Changed: types and placeholders (copy in `research/slice-109b-revert/before/`) |
| `worker/ToolchainRoutes.roc` | Changed: 2 comment lines |
| `worker/tests/unit/ToolchainsTest.roc` | Changed |
| `worker/tests/cases/toolchains/*` | Made again; `pu-size-rules` is new |
| 34 `worker/tests/cases/*/*/seed.sql` and 7 `oidc/*/expect/responses.jsonl` | Changed (section 4.2) |
| `sql/tests/**` | Changed (section 4.3) |
| `research/slice-109b-revert/` | `before/` (copies, `NEW.txt`), `reference/`, `mutations/`, `ref.sh`, `run_mutations.sh`, `mk_cases.py`, `fix_seeds.py`, `fix_w1.py` |
