# D1: integer keys (Registry 5.1, R-IK1 to R-IK8)

Question: can the registry tables use integer ids that are a function of the name (hash, group URL form, `owner/repo`), and how much smaller and faster is the matrix with them?

Answer: yes, with signed 64-bit ids, bound as text and read with `CAST(id AS TEXT)`. D1 rounds an integer of size 2^53 or more with no error, so a read with no cast must fail in the decoder (K11). Each table is `STRICT`, so a bad text id is an error, not a TEXT or REAL value (K12). One `names` table with `UNIQUE (kind, value)` finds a collision in the same batch. With integer keys and `WITHOUT ROWID`, a `compat` row takes 32 bytes in place of 192, and reads are about 2 to 2.6 times faster.

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs` | The cases below on local D1 (wrangler `getPlatformProxy`, workerd) and on plain SQLite (`node:sqlite`). Exit code 1 if a case fails. |
| `node test.mjs sqlite` | Plain SQLite only |
| `MUTATE=notarget node test.mjs` | `ON CONFLICT DO NOTHING` with no conflict target in the insert of a name. K5 must fail. |
| `MUTATE=nostrict node test.mjs` | The tables of K12 with no `STRICT`. K12 must fail. |
| `node size.mjs [hashes] [nightlies]` | Size and read time of `compat` in 4 forms. Default 20,000 x 50 = 1,000,000 rows. Plain SQLite in memory, about 10 s. |

`ids.mjs` has the id functions (R-IK2, R-IK4, R-IK5). Needs Node 22 or later (`node:sqlite`), `sha256sum`, and a global `wrangler` (4.151.0 was used). `$WRANGLER` can give another path to the wrangler package. Nothing is deployed. Wrangler writes `.wrangler/` in this dir: delete it after a run.

## Results (2026-10-16, K10 and K12 2026-10-17)

| Case | What | SQLite | Local D1 |
| --- | --- | --- | --- |
| K1 | 2^53 - 1 and 2^53 - 2 as a Number parameter and in a JSON parameter (`json_each`) | Exact | Exact |
| K2 | A `BigInt` parameter | Accepted | `D1_TYPE_ERROR: Type 'bigint' not supported` |
| K3 | 2^53 + 1 as a text parameter into an INTEGER column, then read | Stored as an integer. The plain read throws `RangeError` (too large for a Number). | Stored as an integer. The plain read gives 9007199254740992 with no error, and a lookup with that value finds the row 2^53. `CAST(id AS TEXT)` gives the exact value. |
| K4 | The same name inserted again, then a release that refers to it | No change, no error | Same |
| K5 | A new name with the id of another name, and a release in the same batch | `UNIQUE constraint failed: names.id`. The release is not written. | Same (`SQLITE_CONSTRAINT_PRIMARYKEY`) |
| K6 | Version parts: 4294967295 is stored. 4294967296 and -1 fail `CHECK`. `01.2.3` and `1.2.3` are one label (`UNIQUE`). | As said | Same |
| K7 | Nightly id: both tag forms give one id, the ids are in date order and under 2^47, 2026-02-30 has no id | As said | (No database) |
| K8 | `name_id` is the first 8 bytes of `sha256sum` of the kind byte and the value, as a signed integer. Two kinds give two ids. | As said | (No database) |
| K9 | A `WITHOUT ROWID` table, and the first write of a key wins | As said | Same |
| K10 | 64-bit ids (2^63 - 1, -(2^63 - 1)) bound as text: `WHERE id = ?`, `IN (SELECT value FROM json_each(?))`, a join to a `VALUES (?)` CTE, `? = (SELECT id ...)` | Exact. `? = ? + 0` is false (no column, so no conversion). `id = ? + 0` and `id = CAST(? AS INTEGER)` find the row. A plain read and `RETURNING id` throw `RangeError`. | Exact, the same compares. A plain read and `RETURNING id` give a rounded Number (9223372036854776000) with no error. |
| K11 | `CAST(id AS TEXT)` gives a string. A read with no cast does not. | The plain read throws | The plain read gives a Number. The D1 module of the platform gives `BadData` for it when its size is 2^53 or more (since 2026-10-16; the conformance test is in `cloudflare-workers` PLAN.md 8c). |
| K12 | `STRICT` tables (also `STRICT, WITHOUT ROWID`): a 64-bit id as text, `abc`, `9223372036854775808`. A `names` row whose value type does not fit its kind. | Integer, then a Datatype error for both bad values. The same table with no `STRICT` stores TEXT and REAL with no error. The bad `names` row fails `CHECK`. | Same |

Mutations: with `MUTATE=notarget`, K5 fails on both backends (`written, releases 1`): the collision is skipped with no error, and the release refers to the other name. With `MUTATE=nostrict`, K12 fails on both (`abc` is stored as TEXT, the out-of-range value as REAL).

`size.mjs` (20,000 hashes x 50 nightlies, target `any`, source `bot`, 5 % `fail` with a 44-character digest):

| Form | MB | Bytes a row | Rows of 500 hashes (25,000 rows) | 10,000 reads of one row |
| --- | --- | --- | --- | --- |
| Text keys (base58 hash, tag, `any`, `bot`, `pass`) | 191.7 | 191.7 | 33.6 ms | 34.5 ms |
| Text keys, `WITHOUT ROWID` | 98.1 | 98.1 | 14.4 ms | 27.5 ms |
| Integer keys (64-bit hash ids, bound as text) | 60.6 | 60.6 | 31.1 ms | 24.7 ms |
| Integer keys, `WITHOUT ROWID` | 31.5 | 31.5 | 12.8 ms | 19.3 ms |

The times change by about 20 % from run to run. With 53-bit ids bound as numbers, the last row was 31.4 MB and 15.2 ms for the point reads: the text parameter costs a parse for each bind.

## Findings

| Finding | Effect on the design |
| --- | --- |
| D1 rounds an INTEGER above 2^53 to a Number with no error (K3). The rounded value can name another row. | Each read of a 64-bit id has `CAST(id AS TEXT)` (R-IK2, K11) |
| Text binding of a 64-bit id (K10) works where the parameter meets a column, and fails where it meets only another parameter or an expression. Each read, also `RETURNING`, rounds on D1. | The compare rules of R-IK2. Changed 2026-10-16: the id column is typed `I64`. The D1 module reads the text of the cast into it, and gives `BadData` for a float of size 2^53 or more (roc-cbor 0.1.0, `cloudflare-workers/MODULES.md` 5.1, "Integers in rows"). Before this change, `bench/Cbor.roc` read an exact-integer float into an `I64` field, so the column was typed `Str`. |
| `ON CONFLICT DO NOTHING` with no target also skips a primary key conflict (K5 mutation) | The insert of a name has the target `(kind, value)` (R-IK3) |
| roc reads each version part as a `u32` (`roc:src/base/url.zig:183-203`) | First: a version is 3 columns (K6). Changed 2026-10-17: one 64-bit order key that saturates at 0xFFFF, and a text column for a key that is not exact (R-IK5, `research/semver-key/`). K6 tests the old form. |
| A table that is not `STRICT` stores a bad text id as TEXT or REAL with no error (K12) | Each table is `STRICT` (R-IK8) |
| A rowid table with a composite key stores the key two times | Small tables with a composite key are `WITHOUT ROWID` (R-IK8) |

## What this does not prove

| Item | Status |
| --- | --- |
| Remote D1 | Not tested. Local D1 uses the same binding code (workerd), so K2 and K3 are expected to be the same. |
| D1 time and the cost per row read | Not measured. `size.mjs` measures SQLite in memory. D1 bills rows read, and integer keys do not change the count of rows. |
| The other prototypes | `research/d1-sweep/` and `research/d1-contrib/` keep text keys. Their triggers compare keys for equality only, so integer keys do not change their results. Not run again with integer keys. |
