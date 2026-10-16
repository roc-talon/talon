# D1: the user hint write, the fold and the delete (Registry 6.1)

Question: can one D1 batch write a user hint request so that a contributor counts once for each pair, a request that is sent again counts nothing twice, and a bad row writes nothing? A D1 batch is atomic, but it cannot branch, and the Worker cannot pass a result from one statement to the next (`cloudflare-workers/API.md` RF4).

Answer: yes, with 3 statements and an `AFTER INSERT` trigger on `contributions` (R-CT4). The insert skips a pair that is pending for the contributor. The trigger counts only an inserted row. The fold (R-CT5) and the delete (R-CT7) are plain batches.

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs` | The 15 cases below on local D1 (wrangler `getPlatformProxy`, workerd) and on plain SQLite (`node:sqlite`). Exit code 1 if a case fails. |
| `node test.mjs sqlite` | Plain SQLite only |
| `MUTATE=notrigger node test.mjs` | Count every row with a plain statement in place of the trigger. W2 to W7 must fail. |
| `MUTATE=orignore node test.mjs` | `INSERT OR IGNORE` in place of `ON CONFLICT DO NOTHING`. W7 must fail. |
| `MUTATE=changes node test.mjs` | `written` from `meta.changes` in place of `RETURNING`. It must fail on D1. |

Needs Node 22 or later (`node:sqlite`) and a global `wrangler` (4.151.0 was used). `$WRANGLER` can give another path to the wrangler package. Nothing is deployed, and the database is in a temp dir that the test deletes. Wrangler writes `.wrangler/cache/cf.json` in this dir: delete it after a run.

## The statements of one request

| Step | Statement |
| --- | --- |
| 1 | `SELECT` the count of distinct pairs of the request with no `compat` row and no `compat_hints` row: `first` |
| 2 | Upsert `contributors`: `first` plus that count (the same subquery), `last_time` |
| 3 | `INSERT INTO contributions ... SELECT ... FROM json_each(?) WHERE true ON CONFLICT (contributor, hash, nightly, target) DO NOTHING RETURNING hash`. The trigger upserts `compat_hints` and adds 1 to `counted`. `written` is the count of returned rows. |

The rows go in as one JSON parameter (`json_each`), so the batch has 3 statements for any count of rows.

## Results

Local D1 (wrangler 4.151.0, workerd, SQLite 3.53.4 in `node:sqlite`) and plain SQLite gave the same results. 15 of 15 cases pass on both. Each mutation fails as the table above says (checked on 2026-10-16).

| Case | What | Result |
| --- | --- | --- |
| W1 | A sends 3 new pairs | written 3, first 3. Counts: HA pass 1, HB fail 1, HC crash 1. |
| W2 | A sends the same rows again | written 0, first 0. No count changes. |
| W3 | B sends 2 pairs that A sent | written 2, first 0 |
| W4 | One request names a pair 3 times | 1 row, first 1. The first row of the pair wins. |
| W5 | C sends with another Talon version | A second `compat_hints` row. The reader adds them up: HA pass 3. |
| W6 | A pair with a `bot` row | Counted, not first |
| W7 | One row has the result `hang` (fails `CHECK`) | The batch fails, and nothing is written, also not the `first` of step 2 |
| W8 | 2 contributors send one new pair at the same time | Both counted. `first` is 1 in total. |
| F1 | Fold with bot rows HA pass, HB pass, HC crash, cutoff 150 | A: agreed 2 (HA, HC), disagreed 1 (HB), unconfirmed 1 (HD, old). HE (young) stays pending. |
| F2 | The fold and the counts | No hint count changes |
| F3 | A second fold | No change |
| F4 | A resend of HA after the fold | Counted again. `tln` sends no pair that has a `bot` row (CLI 1, R-SH3 filter 5). |
| D1 | Delete the contributor C | Its rows go. The counts stay. |
| D2 | Delete the account X (A and B) | A, B, their rows and the account go. The counts stay. |
| D3 | Delete again | No error |

Two findings, now in R-CT4:

| Finding | Effect |
| --- | --- |
| `INSERT OR IGNORE` also skips a row that fails `CHECK`, with no error | A bad row is lost, and the rest of the request is written (W7 with `MUTATE=orignore`: written 1). `ON CONFLICT DO NOTHING` skips only the key conflict. |
| On D1, `meta.changes` of the insert also counts the rows that the trigger writes | 9 in place of 3 for 3 new rows. Plain SQLite gives 3. `RETURNING` gives the inserted rows on both. |

## What this does not prove

| Item | Status |
| --- | --- |
| Remote D1 | Not tested, as for `research/d1-sweep/` |
| Cost with many rows | Not measured. Step 1 and step 2 run the same subquery for each pair. 500 rows is the limit of one request (R-CT2). |
| The rate limit (R-CT11), the JWT (R-CT9) and the HMAC (R-CT3) | Not part of this test. The test uses plain contributor names. |
