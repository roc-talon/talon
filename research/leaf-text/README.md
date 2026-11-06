# The leaf text: the Worker binds it, a trigger checks it (Design Q79, Registry R-SG8)

Question (slice 103, Q103-1): R-IK1 wants text forms in a log leaf (the base58 hash, the `X.Y.Z` version, the URL form of the group). `releases` has only ids, so the `AFTER INSERT` trigger of Q27 cannot make the leaf. Who writes it, so that a leaf is still written only with a new release, in the same batch?

Answer: the Worker computes the leaf text and sends the leaf statement before the release statement, in the same batch. An `AFTER INSERT` trigger on `releases` (and on `toolchains`) stops the batch with `leaf-missing` when the leaf of `NEW.log_index` is not there.

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs` | Cases L1 to L8 on `node:sqlite`, on `sql/0001_init.sql` and the triggers of the test. Exit code 1 if a case fails. |
| `MUTATE=agg node test.mjs` | The leaf statement as `SELECT COALESCE(MAX(idx), 0) + 1, ... FROM log WHERE NOT EXISTS (...)`. An aggregate with no `GROUP BY` gives one row also when `WHERE` is false, so the leaf is written for an old label. L2, L3, L6 fail. |
| `MUTATE=release-first node test.mjs` | The release before the leaf (the order of Q27). The check trigger stops each publish. |
| `MUTATE=no-check node test.mjs` | No check trigger. A release with no leaf (L7) and a leaf of another group (L8) are written. |

## Results (2026-11-01, Node 26, plain SQLite)

8 of 8 pass. Each mutation fails as the table says.

| Case | What | Result |
| --- | --- | --- |
| L1 | A new label | One leaf, one release |
| L2 | The same label and artifact | No error, no leaf, no release |
| L3 | The same label, another artifact | `label-conflict`, nothing written |
| L4 | A second label | Its `log_index` is the new leaf |
| L5 | A compiler leaf and its `toolchains` row | Written, checked on group, version and hash |
| L6 | The same label after a compiler leaf | No error, no leaf |
| L7 | A release with no leaf statement | `leaf-missing` |
| L8 | A leaf with another group text | `leaf-missing` |

Not tested here: local D1. The W1 cases of slice 103 run the same statements on local D1.
