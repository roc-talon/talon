# d1-dump: exact data dump of a Talon registry D1 database

`wrangler d1 export --no-schema` writes a 64-bit INTEGER as a JSON float. The id is wrong. Example from `names` of the remote database:

| Source | id of the same row |
| --- | --- |
| `wrangler d1 export --no-schema --table names` | `-9222162771289818000` |
| `dump.mjs` (SQLite `quote()`) | `-9222162771289817993` |

`dump.mjs` lets SQLite make the text of each row with `quote()`. An integer, a text (quotes escaped, a newline kept) and a blob (`X'..'`) are then exact.

## Files

| File | Use |
| --- | --- |
| `dump.mjs` | The dump tool. Node, no npm package. It runs only SELECT. |
| `check.sh` | Round-trip check (below). |
| `seed.sql` | Test rows for `check.sh seed`: ids above 2^53, a blob name, a quote and a newline in a text, NULLs, rows that triggers also write. |
| `corrupt.mjs` | Test helper: writes the big ids as floats, like `wrangler d1 export`. |
| `.work/` | Local databases and dumps of `check.sh` (gitignored). |

## Use

From `worker/`:

```
set -a; . ../.env; set +a        # only for --remote; never print the values
node ../research/d1-dump/dump.mjs --remote DB /path/out.sql
node ../research/d1-dump/dump.mjs --local --persist-to DIR DB /path/out.sql
```

| Option | Meaning |
| --- | --- |
| `--local` (default) or `--remote` | Which database of the binding. |
| `--persist-to DIR` | Local state directory. |
| `--snapshot-rows N` | Largest total row count for snapshot mode. Default 5000. |
| `--page N` | Rows for each call in paged mode. Default 500. A failed call halves it. |

Import into a database that has the migrations: `npx wrangler d1 execute DB --remote --file out.sql` (or `--local --persist-to DIR`).

## Read modes

| Mode | When | How | Consistency |
| --- | --- | --- | --- |
| snapshot | total rows <= `--snapshot-rows` | One wrangler call with one SELECT for each table. D1 runs the statements of one call in one batch. | One state of the database, also while the registry gets writes. |
| paged | more rows | `LIMIT/OFFSET` on the primary key, counts before and after. | A changed count gives a new try (6 tries). An UPDATE of a row cannot be seen. Use a quiet database. |

A failed wrangler call is tried again 4 times (D1 gives a transient internal error now and then).

## Table order

The dump has one INSERT for each row. Skipped: `targets` (the migrations insert it), `d1_migrations`, `sqlite_sequence`, `_cf_*`. The dump tool stops when the database has a table that is not in its list.

| # | Table | Why in this place |
| --- | --- | --- |
| 1 | names | `releases_leaf_check` reads `names` (the form text). |
| 2 | artifacts | `sweeps_guard_*` reads `artifacts.kind`. |
| 3 | log | Before `releases` and `toolchains`: their AFTER triggers need the log row (`leaf-missing`). |
| 4-10 | repos, repo_events, repo_checks, contributors, links, deps, artifact_targets | No trigger. |
| 11 | releases | Needs `log` and `names`. `releases_label_conflict` passes: the label is unique. |
| 12 | provenance | No trigger. After `releases`, as the data model reads. |
| 13 | toolchains | Needs `log` (`toolchains_leaf_check`). |
| 14 | compat | Before `sweeps`: `sweeps_guard_*` reads `compat`, `releases`, `toolchains`. |
| 15 | contributions | Its trigger `contributions_count` adds to `compat_hints` and `hint_days`. |
| 16-17 | compat_hints, hint_days | INSERT OR REPLACE after `contributions`. The trimmed totals (R-RE24, R-RE25) differ from the sums that the trigger made, so the dump value must win. A plain INSERT here gives a UNIQUE error. |
| 18 | contributor_totals | No trigger. |
| 19 | sweeps | Last of the inputs of its triggers. `sweeps_transitions_insert` writes `transitions`. |
| 20 | transitions | INSERT OR REPLACE after `sweeps`, for the same reason as 16-17. |

All triggers are satisfied by the order alone. One risk stays: `sweeps_guard_insert` tests the live state of today. If a release was yanked after the sweep, the newest live release can change and the guard can raise `sweep-incomplete` on the import. The remote database has no sweeps now, so this is not tested on real data. `check.sh seed` covers one sweep pair.

## Check

`research/d1-dump/check.sh [remote|seed] [--corrupt]`, from any directory. Steps:

| Step | Action |
| --- | --- |
| 1 | Dump the source (the remote database, or a local database made from `seed.sql`). |
| 2 | Make an empty local database with `wrangler d1 migrations apply` (own `--persist-to` under `.work/`). |
| 3 | Import the dump. |
| 4 | Dump the local database again. |
| 5 | `cmp` of the two dumps, byte for byte. |
| 6 | Compare 64-bit ids as `CAST(x AS TEXT)` (min, max and first rows of names, artifacts, releases, toolchains, repos) between the source and the local database. |

Note on step 2: wrangler 4.151 refuses a local SQL file that has the text `BEGIN TRANSACTION` (`src/d1/trimmer.ts`). `sql/0002_triggers.sql` has it in a comment (line 3), so `migrations apply --local` fails on the original file. `check.sh` applies a copy with `BEGIN-TRANSACTION` in that comment (`.work/.../cfg/sql`). The statements are the same. The remote apply is not affected.

## Result against the remote database `talon-registry-weur` (2026-11-07)

Mode: snapshot (1686 rows). Dump: 1708 lines, 358988 bytes.

| Table | Rows | Table | Rows |
| --- | --- | --- | --- |
| names | 306 | toolchains | 34 |
| artifacts | 194 | compat | 0 |
| log | 248 | contributions | 0 |
| repos | 47 | compat_hints | 0 |
| repo_events | 47 | hint_days | 0 |
| repo_checks | 47 | contributor_totals | 0 |
| contributors | 0 | sweeps | 0 |
| links | 0 | transitions | 0 |
| deps | 130 | releases | 214 |
| artifact_targets | 205 | provenance | 214 |

| Check | Result |
| --- | --- |
| Byte compare of the two dumps | same |
| 64-bit id spot check (6 queries) | same |
| `check.sh remote` | PASS |
| `check.sh seed` (also with `DUMP_OPTS="--snapshot-rows 0 --page 1"`, paged mode) | PASS |
| Tables that could not be dumped | none |

The tables that are empty in the remote database (compat, contributions, hints, sweeps, transitions, contributors, links) are tested only by `check.sh seed`.

## Negative tests (the check must catch the bug)

| Change | Result |
| --- | --- |
| `check.sh remote --corrupt` (import file has 2218 big ids as floats) | FAIL: dumps differ, 5 of 6 id queries differ. |
| `check.sh seed --corrupt` | FAIL: dumps differ, 4 of 6 id queries differ. |
| `dump.mjs` writes `compat_hints`, `hint_days`, `transitions` with plain INSERT | FAIL: import error `UNIQUE constraint failed: compat_hints...`. |
