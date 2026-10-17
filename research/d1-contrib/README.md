# D1: the user hint write, the login, the tracker, the daily limit, the trim and the delete (Registry 6.1)

Question: can one D1 batch write a user hint request so that a contributor counts once for each pair, a request that is sent again counts nothing twice, and a bad row writes nothing? Can a login move the rows of a machine to its GitHub account, and can the totals of the tracker come from the rows when they are read, with no fold? A D1 batch is atomic, but it cannot branch, and the Worker cannot pass a result from one statement to the next (`cloudflare-workers/API.md` RF4).

Answer: yes. A contributor is one 64-bit integer (R-CT3): a machine is negative, a GitHub account is positive. The write follows the link of a machine to its account in SQL (`COALESCE`), and an `AFTER INSERT` trigger on `contributions` counts only an inserted row (R-CT4). A login moves the rows with `UPDATE OR IGNORE` and a `DELETE` (R-CT8). The rows stay until their compiler is old (R-CT15) or a delete (R-CT7), so the tracker is one query (R-CT10). The trim moves the classes of the rows of an old compiler to `contributor_totals` in the same batch as the delete, so the tracker does not change. The same trigger enforces the daily limit (R-CT13).

Changed 2026-10-17: the first version of this test had a daily fold that compared and deleted rows after 30 days, and a `contributors` table of totals. Both are gone.

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs` | The 22 cases below on local D1 (wrangler `getPlatformProxy`, workerd) and on plain SQLite (`node:sqlite`). Exit code 1 if a case fails. |
| `node test.mjs sqlite` | Plain SQLite only |
| `MUTATE=notrigger node test.mjs sqlite` | Count every row with a plain statement in place of the trigger. W2 to W6, Q1 and Q2 fail. |
| `MUTATE=orignore node test.mjs sqlite` | `INSERT OR IGNORE` in place of `ON CONFLICT DO NOTHING`. W7 fails. |
| `MUTATE=changes node test.mjs` | `written` from `meta.changes` in place of `RETURNING`. W1, W3 to W6, W8, Q2 and X2 fail on D1. |
| `MUTATE=nolink node test.mjs sqlite` | The write does not follow the link of a machine. L2 to L4 and T1 fail. |
| `MUTATE=nomove node test.mjs sqlite` | A login does not move the rows of the machine. L1 to L4, T1, X3, D1 and D2 fail. |
| `MUTATE=nobotskip node test.mjs sqlite` | A pair with a `bot` row is counted. W6 and W7 fail. |
| `MUTATE=nototals node test.mjs sqlite` | The trim deletes the rows and keeps no totals. X1 and X3 fail. |
| `MUTATE=noage node test.mjs sqlite` | The write takes a row of an old compiler. X2 fails. |

Needs Node 22 or later (`node:sqlite`) and a global `wrangler` (4.151.0 was used). `$WRANGLER` can give another path to the wrangler package. Nothing is deployed, and the database is in a temp dir that the test deletes. Wrangler writes `.wrangler/` in this dir: delete it after a run. The test uses a daily limit of 50 rows in place of 200,000.

## The statements

| Request | Statements (one batch) |
| --- | --- |
| A user hint (R-CT4) | 1. `SELECT` the count of the distinct pairs that are not skipped, with no `compat` row and no `compat_hints` row: `first`. 2. `SELECT` the rows whose pair has a `bot` row or whose compiler is old: `skipped` (R-CT14). 3. `INSERT INTO contributions SELECT COALESCE((SELECT contributor FROM links WHERE machine = ?), ?), ... FROM json_each(?) WHERE NOT EXISTS (bot row) ON CONFLICT DO NOTHING RETURNING hash`. The trigger upserts `compat_hints` and `hint_days`, and calls `RAISE(ABORT, 'hint-quota')` over the limit. |
| A login (R-CT8) | Upsert `contributors` (the account). Upsert `links` (machine to account: a later login moves it). `UPDATE OR IGNORE contributions SET contributor = <account> WHERE contributor = <machine>`, then `DELETE` the rows of the machine that stayed: pairs that the account had already. Add the `contributor_totals` of the machine to the account, and delete them. |
| A trim (R-CT15) | For one old compiler: upsert `contributor_totals` with the classes of R-CT10 of its rows, grouped by contributor; then `DELETE` its `contributions` and `compat_hints` rows |
| The tracker (R-CT10) | One `SELECT` over the rows of the account, with `EXISTS` on `compat` and on the other rows of each pair, plus its `contributor_totals` row |
| A delete (R-CT7) | The header only: the rows, the totals and the link of the machine. The JWT: the rows, the totals, the links and the row of the account. |

The rows go in as one JSON parameter (`json_each`), so the batch has 3 statements for any count of rows.

## Results

Local D1 (wrangler 4.151.0, workerd) and plain SQLite gave the same results: 22 of 22 pass on both. Each mutation fails as the table above says (checked on 2026-10-17).

| Case | What | Result |
| --- | --- | --- |
| W1 | A sends 3 new pairs | written 3, first 3. Counts: HA pass 1, HB fail 1, HC crash 1. |
| W2 | A sends the same rows again | written 0, first 0. No count changes. |
| W3 | B sends 2 pairs that A sent | written 2, first 0 |
| W4 | One request names a pair 3 times | 1 row, first 1. The first row of the pair wins. |
| W5 | C sends with another Talon version | A second `compat_hints` row. The reader adds them up: HA pass 3. |
| W6 | A pair with a `bot` row | Skipped: not written, not counted, listed in `skipped` |
| W7 | One row has the result `hang` (fails `CHECK`) | The batch fails, and nothing is written |
| W8 | 2 machines send one new pair at the same time | Both counted. The tracker gives `first` to one of them (the smaller id on the same time). |
| L1 | A logs in as account 42 | The rows of A move to 42. No count changes. |
| L2 | A sends after the login, with the header only | The row counts for 42 |
| L3 | A second machine B of 42 had HA (which 42 has) and HD | HD moves, the copy of HA goes |
| L4 | A logs in as account 43 | New rows of A go to 43. The old rows stay with 42. |
| T1 | Bot rows come later | 42: agreed 1, disagreed 2, unconfirmed 1, first 4. No row is deleted. |
| Q1 | 51 new rows on one day (limit 50) | `hint-quota`, nothing written |
| Q2 | 50 rows, then 1 more on that day, then 1 on the next day | Written, `hint-quota`, written |
| X1 | Trim the old nightly N1. A and B have rows on N1 (some with `bot` rows) and A has one on N2. | The tracker of A and B is the same before and after. Only the N2 row and its hint stay. |
| X2 | A new hint for N1, older than the age | Skipped, listed in `skipped`, and not `first` |
| X3 | A logs in after the trim | Its old totals move to the account with its rows |
| X4 | Delete the account | Its old totals go too |
| D1 | Delete the machine C with the header only | Its rows go. The counts stay. |
| D2 | Delete the account 42 | Its rows, its links and its row go. The counts stay. |
| D3 | Delete again | No error |

Findings, now in R-CT4 and R-CT8:

| Finding | Effect |
| --- | --- |
| `INSERT OR IGNORE` also skips a row that fails `CHECK`, with no error | A bad row is lost, and the rest of the request is written (W7 with `MUTATE=orignore`). `ON CONFLICT DO NOTHING` skips only the key conflict. |
| On D1, `meta.changes` of the insert also counts the rows that the trigger writes | `RETURNING` gives the inserted rows on both |
| The count of `first` (step 1) also counted a row that the Worker skips | X2 found it. Step 1 now counts only the rows that are not skipped (R-CT4). |
| A login moves rows with an `UPDATE`, so the `AFTER INSERT` trigger does not run | A move does not count a hint again (L1). A pair that two machines of one account both sent stays counted twice in `compat_hints` (L3). A count is not a count of persons (R-RE13 row 3). |

## What this does not prove

| Item | Status |
| --- | --- |
| Remote D1 | Not tested, as for `research/d1-sweep/` |
| Cost with many rows | Not measured: the tracker query over the rows of one account with 10,000 rows, the move of a login, and the trim of a compiler with many rows |
| Old totals and a login | Accepted, not a gap. Two machines of one person have two anonymous ids (R-CT3), so before a login nothing ties them together. A pair that both sent, and that the trim removed before the login, counts twice in the totals of the account: the rows are gone, so the move cannot find the copy. Nothing can find it, and the totals are for display only. |
| The rate limit (R-CT11), the JWT (R-CT9) and the HMAC (R-CT3) | Not part of this test. The test uses small negative ids for machines. |
