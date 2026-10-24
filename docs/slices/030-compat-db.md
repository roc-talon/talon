# 030 compat.db

Phase: P1. Status: done

Slice 030 is the store `talon/compat.db`: SQLite with the WAL journal and a busy timeout (R-CC8), the schema with the format in `PRAGMA user_version` (R-TF1 to R-TF3), the facts per (hash, nightly, target) (R-P4, R-NS12, R-EF1 rank 1), the row of a probe result (R-PP4, R-P3) and the first-seen sha256 of a compiler asset (R-CV6). It adds two `Fx` calls (`db_query!`, `db_write!`), the test fake of them, and `expect/facts.tsv` in the L3 runner.

The plan row (`PLAN-P1.md`, 030) asks for a spike first. The spike is in `research/compat-db/` (`RESULTS.md`): basic-cli `Sqlite` does every part that the slice needs, so there is no stop (TW17). Its findings change the order of the first calls (section 7, D4) and the shape of the tests (F1 to F6 in `RESULTS.md`).

## Split of the slice (proposal, TW19)

The plan row has two more jobs: the first-seen check inside the compiler list and `roc install`, and the facts that the probe jobs write. The design does not fix when the first-seen check stops a command (question Q1), and the probe jobs are slices 031 and 032. So this slice is the store and everything that tests need to use it:

| Part | In 030 | Later |
| --- | --- | --- |
| The `Fx` calls and the real SQL (`RealDb`) | Yes | |
| The pure rows, the text form, the failure decisions (`Db`) | Yes | |
| The row of a probe result, the index by key, the first-seen decision, the command-side helpers `load!`, `save!`, `pin!` (`Facts`) | Yes | |
| The fake `Fx` (`FakeDb`), the L2 entry `db`, `expect/facts.tsv` and its dump in the L3 runner | Yes | |
| `Facts.pin!` called from the compiler list and `tln roc install` (exit 16 in a real command) | No | Slice 030b, after Q1 and Q2 |
| `Facts.save!` called from unit probes and the ladder | No | Slices 031 and 032 |

The answers of the user (`docs/slices/ANSWERS.md`, `PLAN-P1.md`) that bind this slice: none. They are for commands that edit a header or choose a compiler. This slice has no command.

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-CC8 (WAL, busy timeout 5000 ms, a write round is one transaction, busy: facts stay in memory, warning, go on, a failed WAL switch keeps the default journal) | `Db.busy_ms`, `Db.on_err`, `Facts.save!`, `Facts.load!`, `RealDb` | L0 `db` 1, 5, 6. L2 `db/cc1-store` runs 3, 12 to 14. L3 `fx/db1` parts 3, 11, 12, `fx/db2` parts 1, 2 |
| R-P4 (per (hash, nightly, target), `check` target `any`, a fail stores the failing modules, a build pass stores the closure digest) | `Facts.of_probe`, `Db.modules_text`, `RealDb` | L0 `facts` 1, 2. L0 `db` 3, 4. L3 `fx/db1` parts 2, 4, 6 |
| R-PP4, R-P3 (each started probe gives a row, a hang and a crash too. No row for no fact) | `Facts.of_probe` | L0 `facts` 1. L2 run 3 (a crash row) |
| R-CV6 (the first sha256 of (tag, target) is recorded and stays, a changed one is exit 16 with both values and sources) | `Facts.first_seen`, `Facts.changed_fail`, `Facts.pin!`, `Db.Pinned` | L0 `facts` 4, 5. L2 runs 8 to 11. L3 `fx/db1` part 8 |
| R-EF1 rank 1 (the local facts are facts per key, one query for the keys of a closure) | `Facts.index`, `Facts.load!`, `Fx.db_query!` | L0 `facts` 3. L2 runs 1, 2, 7. L3 `fx/db1` parts 4, 5 |
| R-NS12 (a release is a compiler id in the same fact) | `Facts.of_probe`, the column `nightly` | L0 `facts` 1, 3. L0 `db` 4. L2 runs 18, 19. L3 `fx/db1` part 2 |
| R-PK7 (the rows of `compat.db`: types, encode and decode) | `Db.Fact`, `Db.Pinned`, `Db.fact_line`, `Db.parse_line`, `Db.file_text`, `Db.parse_file` | L0 `db` 2 to 5 |
| R-TF1 (`format` in `PRAGMA user_version`) | `Db.format`, `RealDb` | L0 `db` 1, 4 (`format` line). L2 `calls.log` (`format=1`). L3 `fx/db1` part 3, `fx/db2` part 1 |
| R-TF2 (an unknown column is ignored and kept) | `RealDb` (named columns, an upsert) | L3 `fx/db1` part 7 |
| R-TF3 (never write a newer format, exit 19 with the file and `tln tool update talon`) | `Db.on_err`, `Facts.*`, `RealDb` | L0 `db` 5. L2 runs 15 to 17. L3 `fx/db1` part 9 |

Rules of other slices that the cases touch: R-GC13 and R-RM10 (`compat.db` stays after `cache clean --all`: slice 029 tests it), R-J1 to R-J4 (none: no output of a command), R-CC3 (a db call is not a lock: the fake logs no lock line).

`MISSING=1 scripts/rules.sh CC P PP CV EF NS PK TF` lists none of the 10 ids of this slice. It lists ids of other slices.

## 2. Flow (the calls that the L2 case fixes)

Each `db_*` call has `Db.Open` with `path: Roots.item(roots, CompatDb)`, `busy_ms: 5000`, `format: 1`. The L2 case `db/cc1-store` runs the helpers in this order (19 runs, 18 db calls):

| Run | Helper | Calls | Rule |
| --- | --- | --- | --- |
| 1 | `load!` of 3 keys | `db_query` `facts=3` | R-EF1 |
| 2 | `load!` of no key | none | R-EF1 |
| 3 | `save!` of 2 new rows | one `db_write` `facts=2 existing=replace` | R-CC8, R-PP4 |
| 4, 5 | `save!` Replace, then Keep | `db_write` `existing=replace`, `existing=keep` | R-CC8 |
| 6 | `save!` of no row | none | R-CC8 |
| 7 | `load!` | `db_query` | R-EF1 |
| 8 | `pin!`, a new asset | `db_query` `pinned=1`, `db_write` `pinned=1` | R-CV6 |
| 9 | `pin!`, the same sha256 | `db_query` only | R-CV6 |
| 10 | `pin!`, a changed sha256 | `db_query` only, exit 16 | R-CV6 |
| 11 | `pin!`, the same sha256 with another source | `db_query` only | R-CV6 |
| 12 to 14 | `load!` busy, `save!` busy, `save!` failed | the call, a warning on stderr, `Kept` or no row | R-CC8 |
| 15 to 17 | `load!`, `save!`, `pin!` on a newer format | the call (one query for `pin!`), exit 19 | R-TF3 |
| 18, 19 | `save!` and `load!` of a release | `db_write`, `db_query` | R-NS12 |

The steps of the real calls are in the docs of `Fx.db_query!` and `Fx.db_write!` (`cli/lib/Fx.roc`):

| Step | `db_query!` | `db_write!` |
| --- | --- | --- |
| 1 | No key: the empty answer | No row: `Ok`, no change |
| 2 | The file is missing: the empty answer, no file, no dir | Make the parent dirs |
| 3 | `PRAGMA busy_timeout=<busy_ms>` (first: F1 of the spike) | the same |
| 4 | `PRAGMA user_version`: larger than `format`: `Err(TooNew(n))`, nothing else is done | the same |
| 5 | `PRAGMA journal_mode=WAL`, a failure is not an error (F2 of the spike) | the same |
| 6 | Version 0: the empty answer | Version 0: one transaction with the 2 tables and `PRAGMA user_version=<format>` |
| 7 | `SELECT <named columns> ... WHERE (key) OR (key) ...` | One `INSERT` with all rows. `Facts` `Replace`: `ON CONFLICT ... DO UPDATE SET <known columns>`. `Keep` and `Pinned`: `ON CONFLICT DO NOTHING` |
| Error | `SqliteErr(Busy or Locked)`: `Busy`. Other: `Failed(text)` | the same |

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Db.roc` | 126 | Stubs from the test agent | New pure module. Types, 2 constants (`format`, `busy_ms`), 13 functions with `crash "todo"`. The docs have the schema and the contract. |
| `cli/lib/Facts.roc` | 67 | Same | New module. 5 pure functions and 3 effect functions, bodies `crash "todo"`. The doc has the table of the calls. |
| `cli/RealDb.roc` | 13 | Same | New. `query!` and `write!` are `crash "todo"`. The code agent writes the SQL (the spike has what works). |
| `cli/lib/Fx.roc` | 263 to 286 | Test agent | The fields `db_query!`, `db_write!` and their methods, with the docs of the steps |
| `cli/RealFx.roc` | 210 to 213 | Test agent | `import RealDb` and the 2 fields |
| `cli/lib/main.roc` | 108 to 110 | Test agent | `Db` and `Facts` in the exposes list |
| `cli/fxprobe.roc` | 334 to 411 | Test agent | The calls `db-query` and `db-write` (complete: it is a test tool) |
| `tests/unit/db.roc`, `tests/unit/facts.roc` | 177, 126 | Test agent | 6 and 5 `expect`s |
| `tests/commands/FakeDb.roc` | 121 | Test agent | New. The fake store (a text file) and the rules of `fx/db`. Complete (a fake is test code). |
| `tests/commands/FakeFx.roc`, `tests/commands/main.roc` | 254 to 259, 492 to 558 | Test agent | The 2 fields, and the entry `db` of the L2 app (`db_entry!`) |
| `tests/commands/cases/db/cc1-store/` | 19 runs, 6 `fx/db` rules, 1 given file | Test agent | New L2 case |
| `tests/scenarios/fx/db1-real-fx-db/`, `db2-two-processes/` | cmd 114 (12 parts), cmd 47 (2 parts) | Test agent | New L3 cases |
| `tests/tools/dumpdb.py` | 36 | Test agent | New. The dump of `compat.db` for `expect/facts.tsv` |
| `tests/run.sh`, `tests/lib.sh` | 175 to 180, 105 to 108 | Test agent | `expect/facts.tsv` (compare, `UPDATE=1`), `dump_facts`, and `compat.db*` (the WAL files) left out of the tree diff |
| `tests/selftest.sh` | 480 to 517 | Test agent | Rows for the runner: 4 pass cases in the pass group (equal, an empty file, no compare, a db with the format 3), 4 fail rows, 1 `UPDATE=1` row, and the WAL files in the tree row (2 rows changed, 5 new) |
| `research/compat-db/` | `spike.roc` 167, `run.sh` 63, `RESULTS.md` 50 | Test agent | The spike |
| `research/slice-030-revert/` | | Test agent | `before/` (copies, `NEW.txt`), `stubs/`, `mutate.py`, `results.md`, `mutate-run-*.log`, `green.log`, `red.log` |

`Roots`, `Item` (it has `CompatDb` already), `Probe`, `Fail`, `Kind`, `Gc`, `Clean`, `scripts/test.sh`, `tests/commands/run.sh` are not changed.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Db.format`, `Db.busy_ms` | `U64`: 1 and 5000 | R-TF1, R-CC8 |
| `Db.Outcome` | `[Pass, Fail, Hang, Crash]` | R-P4, R-P3 |
| `Db.Key`, `Db.Fact` | `{ hash, nightly, target }`, `Key` and `outcome : Outcome, modules : List(Str), closure : Str` | R-P4, R-NS12, R-PK7 |
| `Db.Source`, `Db.Pinned`, `Db.PinKey` | `[GithubDigest, Registry]`, `{ tag, target, sha256, source }`, `{ tag, target }` | R-CV6, R-CV5 |
| `Db.Open`, `Db.Query`, `Db.Answer`, `Db.Write`, `Db.Err` | `{ path, busy_ms, format }`, `[Facts(List(Key)), Pinned(List(PinKey))]`, `[Facts(List(Fact)), Pinned(List(Pinned))]`, `[Facts({ rows, existing : [Replace, Keep] }), Pinned(List(Pinned))]`, `[Busy, TooNew(U64), Failed(Str)]` | R-CC8, R-TF3 |
| `Db.outcome_word`, `outcome_of`, `source_word`, `source_of` | `Outcome -> Str`, `Str -> Try(Outcome, [BadWord])`, the same for `Source` | R-P4, R-CV5 |
| `Db.modules_text`, `modules_of` | `List(Str) -> Str` (sorted, no repeat, `,`), `Str -> List(Str)` | R-P4 |
| `Db.fact_line`, `pinned_line`, `parse_line` | `Fact -> Str`, `Pinned -> Str`, `Str -> Try(Row, [BadLine])` | R-PK7 |
| `Db.file_text`, `parse_file` | `{ format, facts, pinned } -> Str`, `Str -> Try({ format, facts, pinned }, [BadLine])` | R-PK7, R-TF1 |
| `Db.on_err` | `{ err, what : [Read, Write], path } -> [Stop(Fail), Warn(Str)]` | R-TF3, R-CC8 |
| `Facts.of_probe` | `{ hash, nightly, host, command : Probe.Command, class : Probe.Class, errors : List(Probe.Err), closure } -> Try(Db.Fact, [NoFact])` | R-P4, R-PP4, R-P3 |
| `Facts.index` | `List(Db.Fact) -> Dict(Db.Key, Db.Fact)` | R-EF1 |
| `Facts.first_seen`, `changed_fail` | `{ recorded, listed } -> [New, Same, Changed({ first, now })]`, `{ first, now } -> Fail` | R-CV6 |
| `Facts.load!`, `save!`, `pin!` | `Fx, { roots, keys } => Try(List(Db.Fact), Fail)`, `Fx, { roots, rows, existing } => Try([Saved, Kept], Fail)`, `Fx, { roots, listed } => Try([New, Same], Fail)` | R-EF1, R-CC8, R-CV6 |
| `Fx.db_query!`, `Fx.db_write!` | `Fx, Db.Open, Db.Query => Try(Db.Answer, Db.Err)`, `Fx, Db.Open, Db.Write => Try({}, Db.Err)` | R-CC8, R-TF1 to R-TF3 |

Reuse: `Roots.item`, `Item.CompatDb`, `Text.sorted`, `Text.sorted_unique`, `Probe.Class`, `Probe.Err`, `Probe.Command`, `Fail.new`.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/db.roc` 1 | `format` is 1, `busy_ms` is 5000 | R-TF1, R-CC8 |
| L0 | 2 | The words of `outcome` and `source`, both ways. A wrong case or word is `BadWord`. | R-P4, R-CV5 |
| L0 | 3 | `modules_text` (sorted by bytes, no repeat, `,`) and `modules_of` | R-P4 |
| L0 | 4 | The line of a row (5 facts, 2 pinned rows, a release as the compiler id), the round trip, and 9 lines that are not rows | R-PK7, R-NS12, R-CV6 |
| L0 | 5 (`file_text`, `parse_file`) | The `format` line first, the sort of facts and of pinned rows, the same text for any input order, a new file is format 0, 4 bad texts | R-PK7, R-TF1 |
| L0 | 6 (`on_err`) | `TooNew` is `Input` (exit 19) and names the file, both numbers and `tln tool update talon`. `Busy` and `Failed` are warnings, with a text for `Read` and one for `Write`. | R-TF3, R-CC8 |
| L0 | `tests/unit/facts.roc` 1 (`of_probe`) | 11 rows: target of a check and of a build, the closure only for a build pass, hang, crash, no row for `NoFact`, a release id | R-P4, R-P3, R-PP4, R-NS12 |
| L0 | 2 (`of_probe` modules) | Package errors of this hash only, sorted, no repeat, byte order, no module for app and no-file errors | R-P4 |
| L0 | 3 (`index`) | By key. The target is part of the key. A release id. A missing key. | R-EF1, R-NS12 |
| L0 | 4 (`first_seen`) | `New`, `Same`, a changed source is `Same`, `Changed`, rows of other assets | R-CV6 |
| L0 | 5 (`changed_fail`) | Kind `Integrity` (exit 16), the text with the tag, the target, both values and sources | R-CV6 |
| L2 | `db/cc1-store` (19 runs) | The table of section 2: the facts, the first-seen decision, the busy, failed and newer-format answers, the calls and their order in `calls.log`, the store file in `tree.diff`, the warnings and the exit lines | R-EF1, R-P4, R-PP4, R-NS12, R-CC8, R-CV6, R-TF1, R-TF3, R-PK7 |
| L3 | `fx/db1-real-fx-db` (12 parts) | The real `Fx`, one process: a read makes no file, a write makes the dirs and the file, WAL and `user_version` 1 (read by python3), the rows of keys, `Keep` and `Replace`, an added column that stays (R-TF2), the first sha256 stays, a newer format (the bytes of the file stay), a text file and a dir that cannot be made, Busy after 200 ms while python3 holds the write lock, a reader that does not wait. `expect/facts.tsv`: the rows at the end. | R-CC8, R-TF1 to R-TF3, R-P4, R-NS12, R-CV6, R-PK7 |
| L3 | `fx/db2-two-processes` (2 parts) | 2 shell loops write 30 rows each at the same time into a new db: 60 `ok`, 60 rows, WAL, no failed write. A held write lock for 0.8 s: a query does not wait, a write with 5000 ms waits and works. `expect/facts.tsv`: the format line and 62 facts. | R-CC8, R-TF1, R-P4 |
| selftest | `tests/selftest.sh` | `expect/facts.tsv`: 4 pass cases (equal, empty file and no db, no file and no compare, the format of the file is 3), 4 fail cases (a different row, a db where none is expected, no db where rows are expected, a different format), `UPDATE=1`, and the WAL files left out of the tree diff | the runner of R-PK7 |

Count: 11 L0 `expect`s in 2 new files, 1 L2 case (19 runs), 2 L3 cases, 5 new selftest rows and 2 changed. The budget of the manager is 5 to 20 L0 and 2 to 6 deep: this is 11 and 3. Step times with the reference (`green.log`): check 0.9 s, fmt 0.2 s, l0 5.5 s, l2 1.3 s, l3 9.6 s, selftest 7.6 s.

Flake check (TW15): `fx/db1` and `fx/db2` ran 25 times in a row with no failure, and 32 times as 8 runs at the same time (4 rounds), with no failure. The two cases that wait use a ready file (`held`) that python3 makes after `BEGIN IMMEDIATE`, so no case depends on a start order. The shell waits at most 5 s for the file.

## 6. Output (proposed, R-OUT2, TW24)

No command prints in this slice. The texts of the helpers are proposals for the review. They are in `Db.on_err` and `Facts.changed_fail` (the strings of L0 `db` 6 and `facts` 5):

| Case | Text |
| --- | --- |
| Newer format (stderr, exit 19, `error[input]`) | `<path> has format <n>. This tln writes format <format>. Run: tln tool update talon` |
| Busy write (stderr, `warning: ` first, no exit code) | `compat.db is busy: the facts of this command are not saved` |
| Busy read | `compat.db is busy: Talon goes on with no saved facts` |
| Failed write, failed read (Q6: names the file and the fix) | `cannot use <path> (<text>): the facts of this command are not saved. Removing the file resets the stored facts and the first-seen sha256 of compilers.` (a read: `... Talon goes on with no saved facts. Removing ...`) |
| Changed sha256 (stderr, exit 16, `error[integrity]`) | `the sha256 of <tag> for <target> changed: first seen <sha256> (<source>), now <sha256> (<source>). Talon does not use this compiler. Select another compiler.` |

The text form of the rows (`Db.fact_line`, the dump and `expect/facts.tsv`) is a proposal too: one line for each row, fields split by a TAB, `format`, `fact`, `pinned` as the first word, the modules joined with `,`. `expect/facts.tsv` has the lines of `Db.file_text` (the dump of `tests/tools/dumpdb.py`). A missing file is not compared, an empty file means that no db file exists.

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The slice is the store only. The wiring of R-CV6 into the compiler list and `roc install` is slice 030b (the split table, Q1). | All of the plan row in one slice (the design does not say when exit 16 applies). |
| D2 | The rows are in `cli/lib/Db.roc` (R-PK7 says the package `records`, which does not exist before P2 and has no other content yet). | Make `packages/records` now. |
| D3 | Two `Fx` calls with a typed query and a typed write (`db_query!`, `db_write!`, as `TESTING.md` 2.3 names them). `Db.Open` carries the path, `busy_ms` and `format`, so the real `Fx` has no Talon constant (TW4). | One call with SQL text (Talon logic in the SQL strings of the commands). A call for each table. |
| D4 | The order in the real call: `busy_timeout`, then the `user_version` check, then the WAL switch. (F1: a second process fails at once when the timeout is not set before the first statement. R-TF3: the WAL switch changes the header of a file with a newer format.) | `journal_mode=WAL` first, as R-CC8 lists it. |
| D5 | The schema: `facts` (6 text columns, key (`hash`, `nightly`, `target`)) and `pinned` (4 columns, key (`tag`, `target`)), `WITHOUT ROWID`. No `error_digest` column (question Q5), no `smoke` and no `share_queue` table (P2). | A `result` column with the registry codes. A table for each outcome. |
| D6 | `modules` is one text: the set sorted by bytes and joined with `,`. `closure` is a text, empty for any row that is not a build pass. | A table of modules. A `NULL` column. |
| D7 | A query of a file that does not exist gives the empty answer and makes no file and no dir. A write makes the dirs and the file. | A read that makes an empty db. |
| D8 | `existing : [Replace, Keep]` is in the write, so the command chooses (question Q3). `Replace` is an upsert of the known columns (R-TF2). `Pinned` always keeps the first row (R-CV6). | `INSERT OR REPLACE` (it deletes the unknown columns). A fixed rule in the `Fx`. |
| D9 | A failed WAL switch is not an error: the connection goes on with the default journal. (F2: the loser of a race on a new db gets `Busy` from the switch and can write.) | `Failed`. A retry. |
| D10 | `Busy` and `Failed` are the same for the command: a warning, an empty answer for a read, `Kept` for a write (a fact is evidence: R-CC8). `TooNew` stops with exit 19 (R-TF3). | `Failed` stops. |
| D11 | `load!` with no key and `save!` with no row make no call. | A call with an empty list. |
| D12 | The row of a probe: the target of a check is `any`, of a build the host target that the command gives. A build pass keeps the closure that the command gives. A fail keeps the paths of the errors that have a `Package` file of this hash. A hang and a crash are rows. `NoFact` is no row. | The modules of all packages in one fail row. A `NoFact` row. |
| D13 | The fake store is the text file `compat.tsv` next to the db path. Rows that a case gives are in the given tree. `fx/db` holds the errors, one rule for each call number (`<n>: busy`, `failed <text>`, `version <k>`). This changes the plan row text (`Rows from fx/db.tsv`): one file for the rows (shown by `tree.diff`) and one for the errors is simpler to read. | Rows in `fx/db.tsv` and writes in another file (two places for one store). |
| D14 | The L3 runner compares `expect/facts.tsv` only when the file is there. It dumps `home/.cache/roc/talon/compat.db` with `python3 -I tests/tools/dumpdb.py` (python3 is used by `tests/run.sh` already, `sqlite3` is not on every machine: F5). `tree.diff` leaves out `compat.db*`, because a process that ends leaves `compat.db-wal` and `compat.db-shm` (F3). | A `sqlite3` program. A dump by `tln`. |
| D15 | The first-seen check compares the sha256 only. A changed source with the same sha256 is `Same`. | `Changed` for any difference. |
| D16 | `Facts.pin!` when the read fails with `Busy` or `Failed`: the reference warns and goes on as `New`. This is not tested (question Q2). | |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-CV6 in a real command (the compiler list, `roc install`: exit 16 from `tln`) | Slice 030b, after Q1 and Q2. The decision and the db part are tested here. |
| R-CV6 "stays after `cache clean --all` and `roc rm`" | Slice 029 tests that `clean` never removes `compat.db`. `roc rm` is slice 024. |
| R-P4 "never expire" | No code path removes a row, so there is nothing to test. `cache gc` and `cache clean` keep the file (slices 028 and 029). |
| R-PP4 "counts against `probe.max`" | Slice 031. This slice has the row of a result. |
| R-P4 the used-closure digest (how it is computed) | Slice 032 (R-BS2). The slice stores a text that the command gives. |
| R-TF3 "migrates a file with an older `format` when it writes it next" | There is no older format. The first format is 1. A file with a format between 1 and `format` does not exist. |
| R-TF1 and R-TF2 for the JSON files | Slices of those files. Here only `compat.db`. |
| R-EF1 ranks 2 to 6, R-EF3 | P2 and slice 033 (the registry rows and the hints). |
| R-CC8 "a write round is one transaction", as an effect | One `INSERT` with many rows is one transaction in SQLite. A test would need a failure in the middle of a statement. The tests check that one round is one `db_write!` call (L2 `calls.log`). |
| A read of a file that two processes create at the same time | The race gives `Busy` or an empty answer for a moment. L3 `db2` part 1 tests the write side (60 rows). |
| Windows, a file system with no WAL | The Windows CI job. A file system with no WAL is the failed switch of D9 (not testable on tmpfs). |

## 9. Questions (TW17)

The tests fix the default of each question, except Q2 and Q4, which no test fixes. The manager answered all of them (section Review). A different answer changes the rows that the table names.

| # | Question | Default (tested) | Other option, and the rows that change |
| --- | --- | --- | --- |
| Q1 | R-CV6: which sha256 does Talon record, and which commands stop with exit 16 when it changed? The design says "the first time Talon sees a sha256 for a compiler asset ... from either source in R-CV3" and "when a later list gives another sha256 ... Talon stops". A list has about 100 nightlies. | Not wired in this slice. `Facts.pin!` records one asset and stops for that asset. | (a) Record the host asset of every release in each list that Talon reads, in one transaction. Exit 16 only for the command that picks that tag, and the other commands drop the tag from the candidates with a warning. (b) Record only the asset that a command installs or runs. (c) Any command that reads a list with a changed row stops with exit 16, also when it picks another tag. Rows: slice 030b only. |
| Q2 | R-CV6: the db is busy or fails when Talon reads the first sha256 (`Busy`, `Failed`). Go on with no check, or stop? | Not tested. The reference warns and goes on. | Stop with exit 16 (integrity) or 18 (environment). A db that is busy for 5 s is rare, but "go on" lets a swapped asset pass once. The download check of R-CV4 still compares with the listed digest. Rows: slice 030b. |
| Q3 | R-P4: a second result for a key that has a row: `Replace` or `Keep`? "Results are stored per (hash, nightly, target) and never expire" does not say. | The `Fx` supports both (`existing`). The L2 case runs both. Which one the commands use is not tested. | Slices 031 and 032 choose. Recommended: `Replace` (the newest result, because `tln probe` is a run that the user asked for, and a compiler fault such as a hang can pass on a second run). |
| Q4 | R-P4, R-UM1: a fail with no failing module of the hash (a link error with no file, errors in the app files only) has an empty `modules`. R-UM1 ignores a unit fail when the app uses no failing module. Does an empty set mean "a hard fail" or "ignore"? | The row has `modules` empty (L0 `facts` 2 rows 5 to 7). No test says what the reader does. | Recommended: an empty set is a hard fail (the code can not say which module). Slice 031 (R-UM1) tests it. |
| Q5 | R-EF1 and R-AP10 name an `error digest`, and no rule says how it is made. Is it a column of `compat.db`? | No column. The set of modules is the local evidence. | Recommended: not stored. `tln publish` and the share queue (P2) compute it from `modules` when they send. Before P2 the design must say how (for example the sha256 of `modules_text`). |
| Q6 | A file that is not a database (`Failed`) gives a warning in every command, and the user does not know what to do. Should Talon move the file to `compat.db.bad` and start again? That loses the first-seen sha256 of R-CV6. | A warning only (D10). | Move the file and print the new name. Rows: `Db.on_err`, `RealDb`, L3 `db1` part 10. |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-CC8 lists `journal_mode=WAL` before `busy_timeout=5000` and gives no order. The spike shows that the timeout must be set first (F1), and R-TF3 needs the version check before the WAL switch (D4). The text should say the order: timeout, version, WAL. |
| G2 | R-CC8 says SQLite keeps its default journal "when the file system does not support WAL". The switch also fails when two processes make a new db at the same time (F2). The text should say "when the switch fails". |
| G3 | R-PK7 says the package `records` has the `compat.db` rows. There is no such package before P2 (D2). |
| G4 | R-EF1 and R-AP10 use an error digest with no definition (Q5). |
| G5 | R-P4 says a fail stores the failing modules and R-UM1 reads them. A fail with no module has no rule (Q4). |
| G6 | `TESTING.md` 3.1 lists `expect/facts.tsv` with no form. The form of this slice (section 6) should go in `TESTING.md` 3.1 when it is accepted, with the rule that `tree.diff` leaves out `compat.db-wal` and `compat.db-shm`. |
| G7 | R-CV6 does not say which assets Talon records and which commands stop (Q1), or what it does when the db cannot be read (Q2). |
| G8 | R-TF3 says "a file with a newer `format`" and R-CC8 lets Talon go on when the db is busy. Nothing says what a newer or unreadable `compat.db` costs (the facts and the first-seen sha256 stay unread). The slice stops with exit 19 for a newer format (R-TF3) and goes on with a warning for the rest (D10). |

## 11. Compiler and syntax limits found

| # | Limit |
| --- | --- |
| N1 | A local variable with the name of a function of its type module is a duplicate definition: `format` in `Db.parse_file` (the module has `Db.format`). A record field `format` is fine. |
| N2 | `Sqlite.query!` is needed for a PRAGMA that returns a row (`journal_mode`, `busy_timeout`, `user_version`). `Sqlite.execute!` gives `RowsReturnedUseQueryInstead` for it. `PRAGMA user_version=7` has no row, so `execute!`. |
| N3 | The row decoder of `Sqlite.query_many!` is a nested lambda `|cols| |stmt| { a = Sqlite.str("a")(cols)(stmt)? ... Ok({ ... }) }`. Many `?` in one such lambda compile when the lambda only reads strings. Convert the strings to types outside the decoder (the docs of `sqlite-everything` say a second `?` on a mapped value panics the type checker). |
| N4 | `args` of `main!` has no program name: `fxprobe db-query ...` gives `["db-query", ...]`. |
| N5 | A closure in a record field is called as `(rec.field)(x)`. `rec.field(x)` is a method call. The first draft of `FakeDb` had this error. |
| N6 | `==` on a `Try` and on a record of `Try` fields compiled in the tests of this slice (`Err(BadWord) == Db.outcome_of(...)`, `Ok(Fact(row))`). The known limit is not met. |

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23), log `research/slice-030-revert/red.log`. All old tests pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files | pass | |
| L0 `tests/unit/db.roc` | red: 5 of 6 `expect`s fail (the constants row passes) | `Roc application crashed with this message: todo` |
| L0 `tests/unit/facts.roc` | red: 5 of 5 fail | `todo` |
| L2 old cases (69) | pass | |
| L2 `db/cc1-store` | red | `[ROC CRASHED] todo` (the test app writes no exit file) |
| L3 old cases | pass | |
| L3 `fx/db1-real-fx-db`, `fx/db2-two-processes` | red | exit code 1 (`RealDb.write!` is `todo`), stdout stops after part 1, `facts.tsv` has no row |
| selftest | pass | the new rows test the runner, which is complete |

```text
tests/unit/db.roc: FAILED      (5 failed: Roc application crashed with this message: todo)
tests/unit/facts.roc: FAILED   (5 failed: todo)
FAIL db/cc1-store              the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL fx/db1-real-fx-db         exit code differs (0 expected, 1), stdout stops after part 1
FAIL fx/db2-two-processes      exit code differs, no `ok` line, facts.tsv has no row
```

Times on the stub tree: check 1.6 s, fmt 0.2 s, l0 5.5 s, l2 3.3 s (the L2 app builds), l3 9.5 s, selftest 7.6 s. With the reference (`green.log`): check 0.9, fmt 0.2, l0 5.5, l2 1.3, l3 9.6, selftest 7.6, exit 0, no `WARN` line. No budget is at risk.

## 13. Check against the design (TW21)

The expected files of the L2 case and the 2 L3 cases were made by the private reference and read by eye against the design. With the reference all 11 `expect`s, the L2 case, the 2 L3 cases and the 49 selftest rows pass.

| File | What was checked |
| --- | --- |
| `db/cc1-store/expect/calls.log` | 18 db calls in the order of section 2. Runs 2 and 6 have no call. Run 8 has a query and a write, runs 9 to 11 a query only. Runs 15 to 17 end at the first call. Every call has `busy_ms=5000 format=1` (R-CC8, R-TF1). No `lock`, `ask`, `clock` line. |
| `db/cc1-store/expect/stdout`, `stderr` | The facts of run 1 are the given rows, run 7 shows the replaced row (`Keep` of run 5 did not change it), run 10 has `exit 16`, runs 12 to 14 show `none`, `Kept`, `Kept`, runs 15 to 17 `exit 19`, run 19 the release fact. `stderr` has the 4 texts of section 6 and the 3 lines of exit 19 (formats 2, 2, 3). |
| `db/cc1-store/expect/tree.diff` | The store file after the case: the fail row of the second hash is a pass (run 4), 3 new facts (run 3, run 18) and 1 new pinned row (run 8). The rows of runs 12 to 17 are not there (busy, failed, newer format). |
| `fx/db1-real-fx-db/expect/stdout` | Part 1: `none`, `none`, `nothing was made`. Part 3: `wal`, `user_version 1`, the 2 tables. Part 4: 5 rows, the modules `Json.roc,Yaml.roc` sorted. Part 6: `Keep` left `fail` and added the `crash` row, `Replace` made `pass`, 5 rows. Part 7: the column `note` is not in the query rows, and `kept` is still there after a `Replace`. Part 8: the first sha256 (`github-digest`) stays, the second target is added. Part 9: 3 `TooNew(2)`, the same sha256 of the file, no `-wal` file. Part 10: `Failed` for the 3 calls, the text file is the same. Part 11: `Busy`, a query with no row of the open transaction. Part 12: both rows. |
| `fx/db1-real-fx-db/expect/facts.tsv` | The 9 facts and 2 pinned rows that the case leaves, with `format 1`. The row `other` has the modules `Json.roc,Yaml.roc`: the case wrote `Yaml.roc,Json.roc,Yaml.roc`, so the file holds a set. |
| `fx/db2-two-processes/expect/stdout`, `facts.tsv` | 60 `ok`, 60 rows, WAL. A query during the hold has no `held` row. The final text has the `format` line and 62 facts: the 60 rows, `held` and `late` (`a1` of the query is one of the 60). |

## 14. Revert check (TW12)

Method: the private reference makes all new tests pass. `research/slice-030-revert/mutate.py` puts the reference into `cli/`, changes one small thing, runs `roc check cli/main.roc`, then the layers of the mutation in order (L0 `db.roc` and `facts.roc`; L2 `db/`; L3 `fx/db`; the self-test for the runner files). One mutation at a time, no full sweep. Result: 66 mutations, all caught (after the review answer Q6: 64 and the 3 rows D16, D19, D20 for the new `Failed` text) (`results.md`, `mutate-run-1.log` to `-3.log`; runs 2 and 3 repeated the 7 mutations that first did not compile (X03, X10), had a double match (D14, F15, R02) or were not caught (X14, R04)). The reference, `swap.sh` and `mutate.py` stay in `research/slice-030-revert/` until the manager deletes them.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Db` words, `modules_text` (no sort, no unique), `modules_of`, the line and the file text (order, sort, trailing line end, empty text), `parse_line` (a bad source word) | D01 to D13 | L0 `db` 2 to 5 |
| `Db.on_err` (kind, the `tln tool update talon` text, `Read` and `Write` swapped, the `Failed` text), `format`, `busy_ms` | D14 to D18 | L0 `db` 1, 6 |
| `Facts.of_probe` (target, closure, `NoFact`, the hash filter, the sort, hang, the closure of a fail) | F01 to F07 | L0 `facts` 1, 2 |
| `Facts.index` (the target in the key) | F08 | L0 `facts` 3 |
| `Facts.first_seen`, `changed_fail` (the target, the source, the kind, the order of both values) | F09 to F12 | L0 `facts` 4, 5 |
| `load!`, `save!` (no call for no key or no row, a busy read stops, `Kept`, `existing`, the open record, the path, stderr, `TooNew` ignored) | F13 to F17, F20 to F23 | L2 `db/cc1-store` |
| `pin!` (no write for `New`, a write for `Same`, `Changed` ignored) | F18, F19, F24 | L2 `db/cc1-store` |
| `RealDb` (the busy timeout, WAL, the version check before WAL, `>=`, `user_version`, delete and insert in place of an upsert, a replaced first sha256, `Keep` as `Replace`, a read that makes the file, no parent dirs, no table, `Busy` as `Failed`, `OR` as `AND`, unsorted modules, a missing column) | X01 to X15 | L3 `fx/db1`, `fx/db2` |
| The runner (no compare of `facts.tsv`, the WAL files in the tree diff, no pinned rows, a fixed format, a cut row, no `UPDATE=1` write, a dump of a missing file) | R01 to R07 | selftest |

Two mutations were left out: D19 (a text `format 0` is an error: the design says nothing about such a text) and X16 (`Locked` is not `Busy`: the host keeps one connection for each path, so the code is not reached).

Gaps found by the check and closed before the hand-off:

| Mutation | Gap | Row added |
| --- | --- | --- |
| X14 (the modules are written in the given order) | Every row with 2 modules was replaced later in `db1`, so the dump never showed the stored text | `db1` part 2 writes a row with `Yaml.roc,Json.roc,Yaml.roc`, part 4 reads it, and the row stays for `facts.tsv` |
| R04 (the dump has a fixed `format 1`) | Every db of the self-test has the version 1 | A pass case with `user_version` 3 |

The changes of the check did not touch the tests of other slices. After the run and the review, `cli/` has the stubs again.

## Review (manager, 2026-10-23)

The spike result, the split (030 is the store, 030b is the R-CV6 wiring, added to `PLAN-P1.md`), D1 to D16, the proposals of section 6 and the runner changes are accepted. Answers:

| # | Answer | Effect |
| --- | --- | --- |
| Q1 | For 030b. R-CV6 records every (tag, target) sha256 that a list gives, from either source. A later different value makes that tag no candidate for every command (it is filtered out). A command that names that tag (`roc install`, `roc default`, `roc use`, a pin) stops with exit 16 and the text of R-CV6. An installed compiler with that tag stays in use. | Slice 030b |
| Q2 | For 030b. When `compat.db` is busy or fails on the read, Talon prints the R-CC8 warning, records nothing, and goes on. The check of the download sha256 against the list still runs. | Slice 030b. D16 (`pin!` warns and goes on) stays as it is. |
| Q3 | `Replace`: the newest observation is the fact. | Slices 031 and 032 pass `existing: Replace` |
| Q4 | Yes: an empty failing set is a hard fail. | Slice 031 (R-UM1) |
| Q5 | No digest column. | None |
| Q6 | Keep the warning. Its text names the fix: the path of the file, and that removing it resets the facts and the first-seen sha256 values. Talon does not move the file aside: the `pinned` table is the R-CV6 record. | The `Failed` text changed (section 6). L0 `db` 6 (2 rows), L2 `cc1-store` `expect/stderr` (run 14) and the doc of `Db.on_err` changed. Mutations D16, D19, D20 (the path, the fix text) are caught by L0 `db` 6. Run 4 and 5 of `mutate.py`. 66 mutations, all caught. |

The private reference and `swap.sh` are deleted (`research/slice-030-revert/` keeps `before/`, `stubs/`, `mutate.py`, `results.md`, the logs). `mutate.py` needs the reference, so it cannot run again. The red state with the stubs is confirmed with `scripts/test.sh` (`red.log`).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `cli/lib/Db.roc`, `Facts.roc` and the 2 docs in `Fx.roc` have the contract. The `calls.log` of the L2 case fixes the order and the number of calls. |
| N2 | The spike (`research/compat-db/spike.roc`, `RESULTS.md`) shows the `Sqlite` calls that work: `query!` for a PRAGMA with a row, `execute!` for the rest, `Sqlite.str` and `Sqlite.i64` decoders, `Path.utf8` for the path, one connection for each path in the process (so `BEGIN IMMEDIATE`, 3 calls and `COMMIT` is one transaction), one `INSERT` with many `VALUES` rows. |
| N3 | The 3 first calls of a file: `PRAGMA busy_timeout`, `PRAGMA user_version`, `PRAGMA journal_mode=WAL` (D4). Treat `SqliteErr(Busy)` and `SqliteErr(Locked)` as `Busy`, any other error as `Failed(text)`. |
| N4 | `ON CONFLICT(hash, nightly, target) DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules, closure = excluded.closure` is `Replace` (not `INSERT OR REPLACE`: it would delete a column that a later Talon added, L3 `db1` part 7). `ON CONFLICT DO NOTHING` is `Keep` and `Pinned`. |
| N5 | A new file: one transaction with the 2 tables and `PRAGMA user_version=<format>`. A second process that makes it at the same time uses `IF NOT EXISTS`, so both can run it. |
| N6 | A local variable must not have the name of a function of its type module (N1 of section 11). |
| N7 | Do not edit a test (TW18). A question goes to the manager. |

## Code result (code agent, 2026-10-23)

`scripts/test.sh` exit 0 (dev build): check 0.9 s, fmt 0.2 s, l0 5.4 s, l2 1.4 s, l3 9.5 s, selftest 7.5 s. `OPT=speed scripts/test.sh` also exit 0 (the l2 build with LLVM takes 85 s: the budget warning is for dev only). `fx/db1` and `fx/db2` passed 5 times in a row (also after the speed build). `roc check`: 0 errors, 0 warnings. No test, fixture or expected file was changed (no dispute rows). No design file and no `cloudflare-workers/` file was changed.

| File | Lines | Content |
| --- | --- | --- |
| `cli/lib/Db.roc` | 238 | The words, `modules_text`, the line and file text, `parse_line`, `parse_file`, `on_err`, 3 private helpers for the sort (`fact_order`, `pinned_order`, `then_by`) and `parse_rows` |
| `cli/lib/Facts.roc` | 174 | `of_probe`, `index`, `first_seen`, `changed_fail`, `load!`, `save!`, `pin!`, private `open_of`, `settle!`, `failing_modules`, `wrong_answer` |
| `cli/RealDb.roc` | 247 | `query!` and `write!` on `Sqlite` (steps of section 2) |

Public signatures: none changed.

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `query!` and `write!` check the file with `Path.exists!` (it follows a link) and not `Path.is_file!` (it does not follow a link: a symlinked `compat.db` would look missing). | `is_file!` |
| C2 | A row of `facts` or `pinned` with an `outcome` or `source` word that this Talon does not know is dropped from the answer (R-TF2 spirit: a later Talon with the same format may add words). | `Failed` for the whole query |
| C3 | The new file is made by `BEGIN IMMEDIATE`, 2 `CREATE TABLE IF NOT EXISTS`, `PRAGMA user_version=<format>`, `COMMIT`. A failed step gives `ROLLBACK`, so the shared connection holds no open transaction. | One call for each step with no rollback |
| C4 | The tables are `WITHOUT ROWID` with all columns `TEXT NOT NULL`, as D5 says. No `STRICT` (the schema text of `Db` does not ask for it). | `STRICT` |
| C5 | Measured (manager request): the bundled SQLite is 3.49.1 (`research/compat-db/RESULTS.md`, `spike version`). A query with 32766 variables works, 32767 gives `too many SQL variables` (`spike vars`). One query for all keys stays (3 variables for each fact key: about 10000 keys). The limit is in a comment of `RealDb.select!`. No chunking and no new L3 part. | Chunks of 300 keys |
| C6 | `Facts.save!` with no row returns `Saved` (the L2 `stdout` of run 6 fixes it; the slice text says only "none" for the calls). | `Kept` |
| C7 | `Facts.load!` and `pin!` read an answer of the other table as `Internal` fail ("compat.db gave the answer of another table"). The real and the fake `Fx` never do it. | `crash` |
| C8 | `Locked` is `Busy` like `Busy` (N3 of the notes). | `Failed` |

Compiler limits met: no new one. N1 of section 11 was avoided (no local variable named `format`). A value of type `[Ok({})]` from `var` has no `is_ok` method: `RealDb.create!` keeps the first error in a list (`$failures`).

Test gap found (not changed, TW18): see X23 in "Verify results".

## Verify results

Method (the C5 change is a comment only, so the mutations were not run again): `research/slice-030-revert/agent-mutate.py` (rows in `agent-results.md`). The final code is in `research/slice-030-revert/code-final/`. Each mutation puts `code-final` into `cli/`, changes one small thing, runs `roc check cli/main.roc` (0 errors and 0 warnings needed), then the layers in order (l0, l2 or l3 of the table). One mutation at a time, a timeout for each layer, no full sweep. At the end `cli/` was compared with `code-final/`: equal. The test agent files (`mutate.py`, `results.md`) are not changed.

Result: caught 37 of 38 (1 mutation that did not compile was replaced by another: `X06`).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Db` words, `modules_text` (no sort, no unique), the line (field order), the file text (no sort of facts, no trailing line end), `on_err` (kind, the `tln tool update talon` text, the path, `Read` and `Write` swapped), `busy_ms` | D02, D04, D05, D07, D09, D13, D14, D16, D18 | L0 `db` |
| `Facts.of_probe` (target, closure, `NoFact`, the hash filter), `index` (the target in the key), `first_seen` (the sha256 only) | F01 to F04, F08, F10 | L0 `facts` |
| `load!`, `save!`, `pin!` (no call for no key or no row, `Kept`, no write for a new asset, the warning on stdout, `TooNew` ignored, `Changed` ignored) | F13, F14, F16, F18, F22, F23, F24 | L2 `db/cc1-store` |
| `RealDb` (the busy timeout, the version check `>=`, `user_version`, upsert replaced by `INSERT OR REPLACE`, `Keep` as upsert, pinned `OR REPLACE`, a read that makes the file, no parent dirs, `Busy` as `Failed`, unsorted modules, the version check after the WAL switch, the WAL switch before the busy timeout, no `COMMIT`, a query with no key) | X01, X04 to X10, X12 to X14 (X13: `AND` in the facts clause), X16, X17, X19, X24 | L3 `fx/db1`, `fx/db2` |

| Mutation | Result | Class |
| --- | --- | --- |
| X23 (`RealDb.write_is_empty` for `Facts` is false: a write of no row sends `INSERT ... VALUES ` and gives `Failed`) | not caught | Test gap, R-CC8 ("No row to write: `Ok`, no change", the doc of `Fx.db_write!` step 1). The L2 case runs it only on the fake (run 6), and no L3 part calls `db-write` with no row. Suggested row: `db1` part 5: `$FX db-write $DB 5000 facts replace` (expect `ok`, and the file the same). Not an equivalent change. |
| X06 (first form: `${conflict}` left out of the SQL) | did not compile (an unused variable) | Replaced by the form with `Replace => ""` and `INSERT OR REPLACE`: caught. |

Not run, from the spare rows of `agent-mutate.py` (the test agent covered the same ideas in `results.md`): D01, D03, D06, D08, D10 to D12, D15, D17, D19, F05 to F07, F09, F11, F12, F15, F17, F19 to F21, F25, X02, X03, X11, X15, X18, X20 to X22, X25.

## Gap rows (test agent)

The code revert check (`research/slice-030-revert/agent-results.md`) found one gap: X23 (`RealDb.write!` with no row runs a SQL statement). Only a test changed (TW18). The mutation was applied by hand to `cli/RealDb.roc`, the part failed, and the file was put back (`cmp` with `code-final/`: same).

| Mutation | New part | Rules | File |
| --- | --- | --- | --- |
| X23: `Facts({ rows, existing: _ }) => rows.len() > 1000` (no early `Ok`) | Part 5b: `db-write` with no row for `facts replace`, `facts keep` and `pinned` gives `ok` each, and the row counts stay 5 and 0. A write with no row to a db that does not exist makes no file. With the mutation the stdout has `err Failed(... near "ON": syntax error)`. | R-CC8 (the doc of `Fx.db_write!`: no row, `Ok`, no change) | `tests/scenarios/fx/db1-real-fx-db` (`cmd`, `expect/stdout`) |

## Close (manager, 2026-10-23)

Part 030a is done. C1 to C8 of the code agent are accepted; C5 is measured (SQLite 3.49.1, limit 32766 variables, one query). X23 is caught by L3 db1 part 5b. `scripts/test.sh` exits 0 with no WARN. Part 030b is its own row in PLAN-P1.md. Status: done.
