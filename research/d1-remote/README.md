# Remote D1: the D1 prototypes on a real database (Q27)

Run on 2026-10-18, 07:36 to 07:42 UTC. Workers Free plan, wrangler 4.151.0. This machine is in colo `TBS`.

Question Q27 (DESIGN.md "Open" table) said: "Not tested on remote D1". This run sends the test cases of 3 prototypes to a real D1 database, and compares the results with local D1.

Result: all cases pass on remote D1. Remote D1 and local D1 gave the same values, the same error text and the same `meta` fields.

## Setup

| Item | Value |
| --- | --- |
| Database | `rocplat-test-d1-remote`, made with no location option |
| D1 location | Region `EEUR`. Each answer had `served_by_region` `EEUR`, `served_by_colo` `MXP`, `served_by_primary` true. Read replication: disabled. |
| Path of a call | `node test.mjs remote` on this machine, wrangler `getPlatformProxy` with a remote binding (`remote = true` on the D1 binding), a remote proxy session of wrangler, the D1 binding API, the database |
| Deployed Workers | None |
| Ledger | `ledger.md`: start state, the one database, its delete, end state |

## Files

| File | What |
| --- | --- |
| `run.sh` | `./run.sh create` makes the database and `.state/wrangler.toml` (with `remote = true`). `./run.sh delete` deletes them. |
| `remote.mjs` | The remote mode of the 3 `test.mjs` files: the config path, and `wipe(db)` that drops each table, view and trigger before the schema, so that each run starts empty |
| `probe.mjs` | The exact error texts, the `meta` fields and the round trip time of a batch. `node probe.mjs` (local D1) and `node probe.mjs remote`. |
| `ledger.py`, `ledger.md` | The ledger (same format as `research/edge-q47-q49/`) |
| `results/` | The raw output of each run, and the account lists at the start and at the end |

The change in each `test.mjs` is 4 lines: the import of `remote.mjs`, `configPath(...)`, `await wipe(db)`, and the backend list (remote mode runs only the D1 backend).

## Run

```sh
research/d1-remote/run.sh create
(cd research/d1-sweep && node test.mjs remote)
(cd research/bot-set && node test.mjs remote)          # 300 random states, about 90 s
(cd research/d1-contrib && node test.mjs remote)
research/d1-remote/run.sh delete
```

## Results

| Prototype | Cases | Remote D1 | Wall time | Raw |
| --- | --- | --- | --- | --- |
| `d1-sweep` (Q27: P1 to P3, sweep guard: S2 to S10) | 12, and 2 rows with the error text | 12 of 12 pass | 12 s | `results/d1-sweep.txt` |
| `bot-set` (member set, guard, transitions) | 13 (B1 with 300 random states) | 13 of 13 pass | 89 s | `results/bot-set.txt` |
| `d1-contrib` (triggers, `RETURNING`, `json_each`, `hint-quota`) | 22 | 22 of 22 pass | 18 s | `results/d1-contrib.txt` |

Mutation runs on remote D1. Each one must fail. Each one failed the same cases as on local D1.

| Prototype | Mutation | Exit code | Cases that fail on remote D1 | Same as local D1 |
| --- | --- | --- | --- | --- |
| `d1-sweep` | `noguard` | 1 | P3, S2 to S10 (10) | Yes |
| `bot-set` (20 states) | `faults` | 1 | T1, T2 | Yes |
| `bot-set` (20 states) | `allhash` | 1 | B0, B1, B3 to B6, T0, T1, T2, T4 | Yes (local D1 and SQLite run in this session gave the same list) |
| `d1-contrib` | `changes` | 1 | W1, W3 to W6, W8, Q2, X2 | Yes |
| `d1-contrib` | `notrigger` | 1 | W2 to W6, Q1, Q2 | Yes |
| `d1-contrib` | `orignore` | 1 | W7 | Yes |

## Q27 on remote D1

| Case | What | Remote D1 |
| --- | --- | --- |
| P1 | 3 new labels in one batch | 3 releases. The `AFTER INSERT` trigger wrote leaves 1, 2, 3 (`log_index = max + 1` in each statement). |
| P2 | Same label, same hash (`INSERT OR IGNORE`) | No error, no new leaf |
| P3 | Same label, other hash, in a batch with a new label | `label-conflict`. The batch wrote nothing: no new artifact, no new leaf, also not the new label. |
| P3 with `MUTATE=noguard` | No `BEFORE INSERT` trigger | Fails, as on local D1: `INSERT OR IGNORE` hides the conflict |

## Remote D1 compared with local D1

| Item | Local D1 | Remote D1 | Same |
| --- | --- | --- | --- |
| `RAISE(ABORT, 'label-conflict')` in a batch, `e.message` | `D1_ERROR: label-conflict: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)` | same text | Yes |
| `RAISE(ABORT, 'sweep-incomplete')`, `e.message` | `D1_ERROR: sweep-incomplete: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)` | same text | Yes |
| `RAISE(ABORT, 'hint-quota')`, `e.message` (batch and `run()`) | `D1_ERROR: hint-quota: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)` | same text | Yes |
| `RAISE`, `e.cause.message` | `hint-quota: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)` | same text | Yes |
| `CHECK` failure, `e.message` | `D1_ERROR: CHECK constraint failed: r IN ('pass', 'fail'): SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_CHECK)` | same text | Yes |
| Batch atomicity | A failed statement rolls back the whole batch (P3, S2, B2, W7, Q1; probe: 0 rows of the failed batch, also not the rows of the trigger) | same | Yes |
| `meta.changes` of an insert with an `AFTER INSERT` trigger that writes 2 rows | 3 (the trigger rows count) | 3 | Yes |
| `meta.rows_written` of the same insert | 3 | 3 | Yes |
| `meta.changes` of `ON CONFLICT DO NOTHING` that skips the row | 0 | 0 | Yes |
| `RETURNING` with a trigger | Only the inserted row (`[{k: 1}]`) | same | Yes |
| `json_each`, `json_extract` in a batch | Work (d1-contrib W1 to W8) | same | Yes |
| Two batches at the same time (S9, W8) | Both succeed, D1 runs them one after the other | same | Yes |
| `meta.served_by_region`, `served_by_colo` | not set | `EEUR`, `MXP` | Not applicable |

The first column of the error table is the text after the prefix `D1_ERROR: `. So the D1 module of `cloudflare-workers` can get the `RAISE` text (for example `label-conflict`) in the same way on local D1 and on remote D1.

## Timings

`node probe.mjs`: 10 batches of 2 statements (an insert with 2 trigger rows, and a `SELECT`), one after the other.

| Backend | Min (ms) | Median (ms) | Max (ms) |
| --- | --- | --- | --- |
| Local D1 | 5 | 5 | 6 |
| Remote D1, from colo `TBS` to primary `EEUR` (`MXP`), through the wrangler proxy | 110 | 117 | 170 |

The remote time includes the path from this machine to the edge and the proxy session. A Worker near the primary has a smaller time (see `research/edge-q47-q49/` Q49).

## What this does not prove

| Item | Status |
| --- | --- |
| Two Worker isolates at once | The concurrent cases (S9, W8) sent 2 batches at the same time through one proxy session, not from 2 isolates |
| Read replicas | Read replication was disabled. A write batch goes to the primary. |
| Other D1 regions | Only `EEUR` |
| Remote error text in a deployed Worker with no proxy | The proxy session uses the D1 binding API on the edge. A deployed Worker was not used. |
