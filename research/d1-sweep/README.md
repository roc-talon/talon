# D1: an all-or-nothing sweep write (R-MX4) and the publish batch (Q27)

Question: a D1 batch is atomic, but it cannot branch (`cloudflare-workers/API.md` RF4). How does the Worker write the matrix rows and the `sweeps` row of one request only when the sweep is complete, and else write nothing?

Answer: a `BEFORE INSERT` and a `BEFORE UPDATE` trigger on `sweeps` run the completeness check of R-RE8. When the check fails, they call `RAISE(ABORT, 'sweep-incomplete')`. The Worker sends the rows and the sweep upsert in one batch. On local D1, the error rolls back the whole batch: no row of the request is written. The same mechanism does the 3 publish cases of Q27.

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs` | The 12 cases below on local D1 (wrangler `getPlatformProxy`, workerd) and on plain SQLite (`node:sqlite`). Exit code 1 if a case fails. |
| `node test.mjs sqlite` | Plain SQLite only |
| `MUTATE=noguard node test.mjs` | The same cases with no guard triggers. The guard cases must fail (exit code 1). |
| `node bench.mjs [N ...]` | The time of one sweep write on local D1 with N indexed hashes |

Needs Node 22 or later (`node:sqlite`) and a global `wrangler` (4.151.0 was used). `$WRANGLER` can give another path to the wrangler package. `wrangler.toml` holds only the local D1 binding. Nothing is deployed, and the database is in a temp dir that the test deletes. Wrangler writes `.wrangler/cache/cf.json` in this dir: delete it after a run.

## Mechanisms compared

| # | Mechanism | All or nothing | Race with a publish or a second bot run | Invariant for each writer | Result |
| --- | --- | --- | --- | --- | --- |
| M1 | Trigger on `sweeps` with `RAISE(ABORT)`. One batch: rows, then the sweep upsert. | Yes: the abort rolls back the batch (S2) | None: the check runs in the write transaction | Yes: no code path can write an incomplete sweep (S10) | Chosen |
| M2 | Guarded upsert `INSERT ... SELECT ... WHERE NOT EXISTS (missing)` as the last statement, and the Worker reads `meta.changes` | No: the rows are written, only the sweep is not | None | Only for this statement | Rejected: an answer of 422 then has side effects. To make it all or nothing, a statement must fail on purpose (for example `json('x')`), which is a trick. |
| M3 | Read before the batch, check in Roc, then one batch with an unconditional sweep | Yes, when the read is correct | Safe only because completeness cannot become false later (see below). A bug in the Roc check writes a false sweep. | No | Rejected: the check is outside the database |
| M4 | Two requests: rows first, then the sweep alone (M1 or M2) | Not needed: rows are true facts | None | With M1, yes | Possible for the bot, but it needs no rule: M1 already allows a sweep with no rows (S3, S6) |

Why completeness, once true, stays true for a fixed bound: a new leaf gets `index = max + 1`, so a new hash always has a log index above each bound that the Worker accepted (the bound is at most the log size, S5). A new label of an old hash does not lower its log index (S8). A `compat` row is never deleted (R-RE6). So the only race is inside the write, and M1 puts the check inside the write.

## Results

Local D1 (wrangler 4.151.0, workerd) and plain SQLite gave the same results. 12 of 12 cases pass. The rows P3m and S2m only print the error text. With `MUTATE=noguard`, 10 cases fail on both: P3, S2 to S10.

| Case | What | Result |
| --- | --- | --- |
| P1 | 3 new labels | 3 releases, leaves 1, 2, 3, written by the `AFTER INSERT` trigger |
| P2 | Same label, same hash (`INSERT OR IGNORE`) | No error, no new leaf |
| P3 | Same label, other hash, in a batch with a new label | `label-conflict`. Nothing of the batch is written, also not the new label. With no guard, `INSERT OR IGNORE` hides the conflict and writes the new label. |
| S2 | Rows for 2 of 3 hashes, and a sweep | `sweep-incomplete`. 0 rows written. |
| S3 | The last row, and a sweep. 2 rows came in an earlier request. | Written |
| S4 | An `author` row for the last hash | `sweep-incomplete` |
| S5 | Bound 9, log size 3 | `sweep-bound` |
| S6 | Bound 2 after bound 3 | No error, the row keeps 3 |
| S7 | A publish of a new hash between the read of the bot and its write | The new hash has log index 4, above bound 3, so the sweep is written |
| S8 | Bound 5, with no row for the hash of log index 4 | `sweep-incomplete`. The row keeps 3. |
| S9 | Two sweep requests at once, bounds 4 and 5 | Both succeed. The row has 5. |
| S10 | A direct `UPDATE` to a smaller bound | `sweep-smaller` |

The error that the Worker sees on local D1:

```text
D1_ERROR: sweep-incomplete: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
D1_ERROR: label-conflict: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
```

Cost of the guard (`node bench.mjs`, local D1, one sweep write, median of 5):

| Indexed hashes | Wall time (ms) | D1 `meta.duration` (ms) |
| --- | --- | --- |
| 1,000 | 4 to 6 | 0 |
| 5,000 | 7 to 11 | 2 |
| 20,000 | 11 to 16 | 7 to 10 |

The index has about 50 packages now (Registry 6). The check reads each release and probes the primary key of `compat` once for each release.

## What this does not prove

| Item | Status |
| --- | --- |
| Remote D1 rolls back the whole batch on a `RAISE` | Not tested. Local D1 runs the same SQLite in workerd. The D1 docs say that a batch is one transaction, and that a failed statement rolls back the whole sequence. |
| The remote error text | Not tested. The Worker matches the `RAISE` text as a substring, not the full message. |
| Triggers on remote D1 | Not tested. The D1 docs list `CREATE TRIGGER` as supported. |
| Read replicas | A batch that writes goes to the primary. The guard reads in that transaction, so a replica lag cannot affect it. |
| Two Worker isolates at once on remote D1 | Not tested. D1 has one primary, which runs one write transaction at a time. Locally, S9 sent 2 batches at the same time. |
