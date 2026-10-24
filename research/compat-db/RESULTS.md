# Spike: basic-cli `Sqlite` for `compat.db` (slice 030, R-CC8)

Date: 2026-10-23. Compiler `nightly-2026-10-14-38a3029`, basic-cli 0.25.0. Files: `spike.roc` (the app), `run.sh` (builds it, runs the cases). Raw run: `research/compat-db/run.sh`.

## Result

Basic-cli `Sqlite` does every part that slice 030 needs. No part is missing, so there is no TW17 stop.

| Need | Result | How |
| --- | --- | --- |
| Open a db file | Works. The first call on a path opens it and creates it. A missing dir gives `SqliteErr(CanNotOpen, "unable to open database file")`. A text file gives `SqliteErr(NotADatabase, "file is not a database")`. | `Sqlite.query!` or `Sqlite.execute!` with `path: Path.utf8(file)` |
| `PRAGMA journal_mode=WAL` | Works. It returns one row, so use `query!` with `Sqlite.str("journal_mode")`. `execute!` gives `RowsReturnedUseQueryInstead`. The answer is `wal`. | `query!` |
| `PRAGMA busy_timeout=5000` | Works, one row (`timeout`, use `Sqlite.i64`). It holds for the next calls: the host keeps one connection for each path in the process. Read back in a later call: 5000. | `query!` |
| `PRAGMA user_version` | Read: `query!` with `Sqlite.i64("user_version")`. Set (`PRAGMA user_version=7`): `execute!` (no row). Works. | both |
| Create a table, insert, select | Works. `execute!` with named bindings (`:h`). `STRICT, WITHOUT ROWID` and a primary key on (hash, nightly, target) work. `Sqlite.decode_record` makes a record of 2 columns. | |
| One write round in one transaction | A statement with many `VALUES` rows is one atomic write. `BEGIN IMMEDIATE`, an insert and `COMMIT` as 3 calls also work, because the connection stays the same. | |
| Error codes | `SqliteErr(Busy, text)` with `Sqlite.errcode_to_str`. A busy write waits for the timeout, then gives `Busy`. | |
| Many statements in one call | Not tested and not needed. `prepare!` takes one statement. | |

## Two processes in WAL

| Case | Result |
| --- | --- |
| Holder keeps the write lock 2 s, second writer with `busy_timeout=5000` | The second write waits 1.5 s (the rest of the hold), then succeeds. |
| Same, second writer with `busy_timeout=500` | It fails after 0.51 s with `Busy`. The holder then commits. |
| 2 writers at once on a new db, 300 writes each, gap 5 ms, timeout 5000 | 600 of 600 rows, 0 write errors. One process got `Busy` from `PRAGMA journal_mode=WAL` (see below) and went on in the default journal. |
| Same, `busy_timeout=0` | A `CREATE TABLE` also failed with `Busy`: 300 of 600 rows. This shows that the timeout is needed. |
| 2 writers at once, tight loop of 3000 writes each, timeout 5000 | 6002 of 6002 rows, but 1 write failed with `Busy` after 5 s and the run took 12 s: one writer starves the other. Not a Talon pattern (one write for each probe round). |

## Findings that change the design text or the code

| # | Finding | Effect |
| --- | --- | --- |
| F1 | The order of the first calls matters. `PRAGMA busy_timeout` must come before `PRAGMA journal_mode=WAL`: with the timeout still 0, the WAL switch of a second process fails at once with `Busy`. | The open step is: busy_timeout, then journal_mode, then user_version. R-CC8 names the two pragmas and no order. |
| F2 | The WAL switch on a new db can still give `Busy` after the full timeout, when two processes make the db at the same time. The failed process can go on: its connection keeps the default journal, writes work, and the file is in WAL after the other process switched it. | This is the case "the file system does not support WAL, SQLite keeps its default journal" of R-CC8. A failed WAL switch is not an error. |
| F3 | A process that exits keeps `t.db-wal` and `t.db-shm` next to the db. The host does not close the connection at exit. | The L3 tree diff must leave out `compat.db-wal` and `compat.db-shm` as well as `compat.db`. |
| F4 | One connection for each path, kept for the process. `busy_timeout` and an open transaction hold across calls. | A transaction can be 3 calls. A fake `Fx` has no such state, so a write round is one `INSERT` with many rows. |
| F5 | There is no `sqlite3` program on this machine. | The L3 runner reads `compat.db` with `python3 -I` (the module `sqlite3`, version 3.46.1 here). `tests/run.sh` uses `python3` already. |
| F6 | Each commit costs 2 ms (3000 writes in 6 s alone, default `synchronous=FULL`). | One transaction for each round (R-CC8) is cheap enough. |

## SQLite version and variable limit (question C5 of the slice)

Run: `spike version <db>` and `spike vars <db> <n>` (`spike.roc`), built with the pinned roc, through the real `Sqlite` host.

| Item | Result |
| --- | --- |
| `SELECT sqlite_version()` | 3.49.1 |
| A query with 999, 1000, 20000, 32766 named variables | works |
| A query with 32767 variables | `SqliteErr(Error, "too many SQL variables")` |

The limit is 32766 variables, so one query for the keys of a closure is enough (3 variables for each fact key: about 10000 keys).

## Cost

| Item | Without `Sqlite` | With `Sqlite` |
| --- | --- | --- |
| Binary, `--opt=size` or `--opt=speed` (hello app, spike app) | 1.07 MB | 2.83 MB (+1.77 MB) |
| Binary, `--opt=dev` | 1.66 MB | 3.52 MB |
| `tln` today (`--opt=dev`) | 17.4 MB | about 19 MB (not measured) |
| Build of the spike, warm cache | | 0.05 s dev, 1.1 s size or speed, 255 MB peak memory |
| Run of `single` (open, 3 pragmas, create, 3 inserts, select, a 3-call transaction) | | 25 ms |
| Download | | none: basic-cli 0.25.0 is in the package cache already |
