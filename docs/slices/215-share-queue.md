# 215 Share queue

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 215 of `PLAN-P2-CLI.md`. Which facts go into the share queue (R-SH2, the 6 filters of R-SH3, the 3 tool-app conditions), the table `share_queue` of `compat.db` with its cap (R-SH4, R-TF7), and the contract of the real `Fx` for `QueueCount`, `ClearQueue` and the new `Queue` write. No send (216), no `tln probe --share` (217), no smoke build (218).

## Rules

R-SH2, R-SH3, R-SH4 (the cap, the order, the key), R-EV26, R-TF7. Named in the tests as used: R-SH1, R-CC8, R-TF2, R-TF3, R-CV1, R-CV6, R-EF3, R-AP17, R-AP28, R-RC1 to R-RC4, R-SM7, R-T21, R-NS1, R-NS6, R-TF1.

Design: CLI 1 (R-SH2, R-SH3, R-SH4), CLI 6.1 (R-TF7), CLI 7 (R-CC8); Resolution 3 (R-EF3); Registry 4 (R-AP17, R-AP28). Closed slices read: 213 (the settings, `Db` `QueueCount` and `ClearQueue`), 213b, 214, 206 (the answers), 209 (`Matrix.rows`, the `bot` rows).

## Scope of the test step

| Part | Where | State |
| --- | --- | --- |
| The decision for one fact: `ShareQueue.admit` | `cli/lib/ShareQueue.roc` (new, stub) | L0 |
| The line form of a row, the cap constant: `Db.queue_cap`, `Db.queue_line`, `Db.queue_of` | `cli/lib/Db.roc` (stubs) | L0 |
| The failure of the write: `ShareQueue.err` | stub | L0 |
| The write of the rows: `ShareQueue.enqueue!`, the new `Db.Write` variant `Queue` | stub | L2 (`FakeDb`) |
| The SQL of `Queue` | `cli/RealDb.roc` (a `crash "todo: slice 215"` arm in `insert!`) | L3 (`fxprobe`) |
| `fxprobe` lines for `QueueCount`, `ClearQueue`, `Queue`, and the dump of the table | `cli/fxprobe.roc`, `tests/tools/dumpdb.py` | done in this step (not stubs) |

## Public signatures (stubs, `crash "todo: slice 215"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `Db.queue_cap` | `U64` (10000). Not a stub: a constant | R-SH4 |
| `Db.Queued` | `{ hash, nightly, target : Str, result : Db.Outcome, talon_version, queued_at : Str }` | R-TF7 |
| `Db.Write` | a new variant `Queue({ rows : List(Queued), cap : U64 })`. The doc of `Db.Write` has the contract: the table is made, `INSERT ... ON CONFLICT DO NOTHING` for each row in order, then the rows with the smallest `seq` go until the table has `cap` rows. The cap is an argument because the real `Fx` has no Talon constant (TW4). | R-SH3, R-SH4, R-TF7 |
| `Db.queue_line` | `{ seq : U64, row : Queued } -> Str`: the 7 columns of R-TF7 in order, `seq` first, split by TAB, no table word, no line end. This is the form that the cases of slice 213 already use (their `share_queue.tsv`). | R-TF7 |
| `Db.queue_of` | `Str -> Try({ seq : U64, row : Queued }, [BadLine])` | R-TF7 |
| `ShareQueue.Sharing` | the input of `Share.state`: `{ share, registry, offline, env }` | R-SH2 |
| `ShareQueue.Fact` | `{ origin : [Probed, Stored, Registry, Inferred], probe : Kind, compiler : { id, recorded : Bool }, hash, target : Str, outcome : Db.Outcome, machine_error : Bool }` | R-SH3 |
| `ShareQueue.Kind` | `[Unit, Smoke, ToolApp({ indexed_app, changed, git_ref : Bool }), Baseline, WholeApp, AppBuild, ProjectFile, BundleFile]` | R-SH3 filter 2 |
| `ShareQueue.Why` | `[Off(Share.Reason), NotProbed, Kind, Compiler, NotInAnswer, BotRow, Result, Target]` | R-SH2, R-SH3 |
| `ShareQueue.admit` | `{ sharing, fact, answers : List(records.Closure.Answer), domain : List(Nightlies.Release), talon_version, queued_at } -> [Queue(Db.Queued), Skip(Why)]`. The first false test gives the reason, in this order: the 5 conditions (`Share.state`), then the filters 1 to 7. | R-SH2, R-SH3 |
| `ShareQueue.err` | `{ err : Db.Err, path } -> [Stop(Fail), Warn(Str)]` (proposal, as `Share.clear_err`) | R-SH4, R-CC8, R-TF3 |
| `ShareQueue.enqueue!` | `Fx, { roots, rows, cap } => Try([Queued, Lost], Fail)`. No row: no call. Else one `db_write!` with `Queue`. `Busy` or `Failed`: `warning: <text>` on stderr and `Lost`. `TooNew`: `Err` (exit 19). | R-SH4, R-CC8, R-TF3 |

Edits to existing files (copies in `research/slice-215-revert/before/`, the new files in `before/NEW.txt`): `cli/lib/Db.roc`, `cli/lib/main.roc` (1 expose), `cli/RealDb.roc` (2 arms), `cli/fxprobe.roc` (3 lines), `tests/commands/FakeDb.roc` (the fake of `Queue`), `tests/commands/L2Db.roc` (2 words), `tests/tools/dumpdb.py` (the `queue` lines), `tests/unit/l0-8.roc` (1 import). No file of the 206b agent (`Opts.roc`, `PickLoop`, `PickIndex`, `ResolveBase`, the resolve command modules) was edited.

## The tested readings

| # | Reading |
| --- | --- |
| 1 | R-SH2 is checked first, with the facts of `Share.state` (the 5 conditions, slice 213 D3 order). A condition that is false gives `Skip(Off(reason))`, also for a fact that fails a filter too. The 21-row table of `Share.state` is slice 213; here each condition is run once through `admit`, with the `DO_NOT_TRACK` and `CI` variants. |
| 2 | R-SH3: the filters give the first false one in the order of the table (a reading, as slice 213 D3 for R-SH2). One test peels a fact that fails all of them. |
| 3 | Filter 1: `origin` is `Probed` (a probe that this command ran). `Stored` (old `compat.db`), `Registry` and `Inferred` are stopped. "While R-SH2 was true" is the first test. |
| 4 | Filter 2: `Unit` and `Smoke` pass. `Baseline`, `WholeApp`, `AppBuild`, `ProjectFile`, `BundleFile` are stopped. `ToolApp` passes only with the 3 conditions: `indexed_app`, not `changed` (no `--resolve`, no override), not `git_ref`. Each false condition alone stops it. The command computes the 3 booleans (see "For slice 206b and later"). |
| 5 | Filter 3: `Compiler.kind(id)` is `Nightly` and `recorded` (the first-seen sha256 is in `compat.db`, R-CV6). `git-`, `link-`, `copy-` and `debug-` ids are stopped also with `recorded`. |
| 6 | Filter 4 (Q432): the set is the `hash` of each `artifacts` row and each `releases` row of all closure answers of the command. A hash only in `unknown`, only a dep hash, only a `platform_hash`, or only in `runs`, `nearest` or `hints` is not in the set. No answer gives an empty set. |
| 7 | Filter 5 (R-EF3: the pair is (hash, nightly, target)): `Matrix.rows` of each answer gives the `bot` rows (a run holds each release of `domain` in its interval, a `nearest` row has its own nightly). A `bot` row with the key, of any result, stops the fact. An `author` row, another hash, another target and another compiler stop nothing. The 2 tag forms of a compiler are one (R-CV1, `PinOrder.same_id`), in the row and in the fact. |
| 8b | Filter 7 (Q432): the kind comes from the `artifacts` row of the hash. A package: target `any`. A platform: `any` or a name of its `target_names`. An app: any target. A hash with only a release row has no kind: not tested. |
| 8 | Filter 6: `Pass`, `Crash` and `Fail` pass. `Hang` is stopped. A `Fail` with `machine_error` is stopped. |
| 9 | The row has the `hash`, the `nightly` (the compiler id), the `target` and the `result` of the fact, and `talon_version` and `queued_at` as given. A smoke fact has the key (platform hash, nightly, target), a tool app (app hash, nightly, real target). No error text (the type has none). |
| 10 | R-TF7 key: `UNIQUE (hash, nightly, target, talon_version)`, `ON CONFLICT DO NOTHING`: a repeat (also in the same call) keeps the first row, with its first `result` and `queued_at`. A row with another `talon_version`, `nightly`, `target` or `hash` is a new row. |
| 11 | R-SH4 cap: after the rows are added, the smallest `seq` rows are dropped until `cap` rows stay. A repeat adds no row, so it drops none. A row that was dropped is a new row when it comes again (next `seq`). A call with more new rows than `cap` keeps the last `cap` of all. `seq` of a new row is after the largest `seq` that is in the table. |
| 12 | A `Queue` write with no row makes no call (`enqueue!`) and no file (the real `Fx`, L3 step 1). A write to a new file makes the file with its 3 tables (`facts`, `pinned`, `share_queue`, R-TF1), WAL, `user_version` 1. A file of an older Talon with no `share_queue` gets the table with `CREATE TABLE IF NOT EXISTS` and keeps `user_version` 1 and its facts (R-TF7). `QueueCount` and `ClearQueue` of the 213 contract run against real SQLite for the first time (L3 steps 1, 9 to 13). |
| 13 | R-CC8, R-TF3: `Busy` and `Failed` are a warning, the rows are lost and the command goes on. A newer file is exit 19 and nothing is written. |

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/SharequeueTest.roc` (driver `l0-8.roc`), expect 1: the 5 conditions through `admit` (19 rows: each condition, `DO_NOT_TRACK` `1`, `true`, empty and `0`, `CI` `true`, `TRUE`, `1`, `false`, `0`, empty, `TALON_INTERACTIVE`, the order of the conditions, a condition before a filter) | R-SH2, R-EV26 |
| L0 | expect 2: filter 1 (4 rows) | R-SH3 |
| L0 | expect 3: filter 2 (7 rows) | R-SH3 |
| L0 | expect 4: the 3 tool-app conditions (6 rows) | R-SH3, R-T21 |
| L0 | expect 5: filter 3 (6 rows) | R-SH3, R-CV6, R-NS6 |
| L0 | expect 6: filter 4 (5 rows: in an answer, in the second answer, in no answer, no answer, only in `unknown`) | R-SH3, R-AP17, R-AP28 |
| L0 | expect 7: filter 5 (16 rows: the run interval, other hash, other target, `author`, any result, `nearest`, second answer, the 2 tag forms, a smoke row) | R-SH3, R-EF3, R-CV1 |
| L0 | expect 8: filter 6 (5 rows) | R-SH3, R-SM7, R-RC3 |
| L0 | new expect after 8: filter 7 (8 rows). Expect 5 has 2 more rows (a release id with and without a recorded sha, Q431). Expect 6 has 10 rows (releases, dep, platform_hash, runs, hints). | R-SH3, Design Q431, Q432 |
| L0 | expect 9: the order of the tests (8 steps) | R-SH2, R-SH3 |
| L0 | expect 10: the row of a smoke fact and of a tool app | R-SH3 |
| L0 | expect 11: `Db.queue_cap`, `Db.queue_line`, `Db.queue_of` (round trip, 5 bad lines) | R-SH4, R-TF7 |
| L0 | expect 12: `ShareQueue.err` (busy, failed, too new) | R-SH4, R-CC8, R-TF3 |
| L2 | `tests/commands/cases/share/sh8-queue-write` (entry `db`): a new file with 2 rows, the key and the dedupe (6 rows in all), no row (no call). `calls.log` and the tree (`compat.tsv` with the `format` line, `share_queue.tsv`). | R-SH3, R-SH4, R-TF7 |
| L2 | `share/sh9-queue-cap`: a given queue of 3 rows (seq 5, 6, 9), cap 4: the oldest drops, a repeat drops none, a dropped row comes back, a call with 6 rows, a larger cap. The final file. | R-SH4, R-TF7 |
| L2 | `share/sh10-queue-errors`: busy, failed, newer file (exit 19), then the same rows work. stderr and `calls.log`. | R-SH4, R-CC8, R-TF3 |
| L3 | `tests/scenarios/fx/sq1-real-fx-queue` (`fxprobe` and python `sqlite3`, 13 steps): `QueueCount`, `ClearQueue` and a `Queue` write with no row on a missing file (no file); the new file, its tables, columns and the unique key; the dedupe; the cap 4 and 3; a facts write beside the queue; a file of an older Talon (count 0 makes no table, the write makes it, `user_version` stays 1, the facts stay); `ClearQueue` on such a file; a file with `user_version` 0; a newer file (3 calls, same bytes); a text file (3 calls, same bytes). `expect/facts.tsv` has the 3 queue rows after the dump of the new `queue` lines. | R-SH3, R-SH4, R-TF7, R-TF2, R-TF3, R-CC8, TW4 |

The new `fxprobe` calls: `db-write <path> <busy_ms> queue <cap> <hash,nightly,target,result,talon_version,queued_at>...`, `db-write <path> <busy_ms> clear-queue`, `db-query <path> <busy_ms> queue-count` (doc table in `cli/fxprobe.roc`). The L2 entry `db` has the words `queue-add <cap> <row>...` and `queue-count`.

## Output (proposed, R-OUT2, TW24)

| Text | When |
| --- | --- |
| `warning: compat.db is busy: the shared results are not queued` | `Queue` write, busy file |
| `warning: cannot use <path> (<text>): the shared results are not queued` | `Queue` write, another failure |
| `tln: error[input]: <path> has format <n>. This tln writes format 1. Run: tln tool update talon` | `Queue` write, newer file (`Db.on_err`, exit 19) |

No other output: R-SH4 says the queue never changes the output or the `--json` of a command.

## Out of scope

| Item | Where |
| --- | --- |
| R-SH2 "again before it sends", the send, `Talon-Contributor`, the totals | Slice 216 |
| `tln probe --share` (the filters except filter 1, `DO_NOT_TRACK` still sends) | Slice 217 |
| The smoke build and the list of machine errors of R-SM7 | Slice 218 |
| Reading the queue rows (a `Db.Query` for the send, the rows of the running `talon_version`, a row of another version leaves) | Slice 216 |
| A busy timeout case for the `Queue` write in L3 | The write uses the common `open_db!` (db1 step 11 covers the timeout). A queue case would need a held lock for about 1 s. |

## For slice 206b and later (not chosen here)

| # | Part | Why it is not here |
| --- | --- | --- |
| 1 | The call of `admit` and `enqueue!` in the resolve commands (after the probe round, with the write of the facts, R-PP4), in `tln tool install`, `tln x` (tool-app builds, R-T21), the smoke build (218) and `tln probe`. | A command with a registry index exists only after 206b and 224. |
| 2 | The closure answers of the command as a list (`answers`) and the compiler list (`domain`): the command must keep each answer that it got, also the second query (R-SP24). | 206b (`PickLoop`, `PickIndex`, `ResolveBase`) |
| 3 | The facts of `Share.state`: the setting `share` of `config.toml` (`Share.setting`), `Net.registry`, `--offline`, the env. | The command reads them (slice 214 does for the prompt). |
| 4 | `Fact.origin`, `probe`, `recorded` (a `Db.Pinned` row of the compiler: query `Pinned`), `target` (the real target of a build) and the 3 booleans of a tool app (kind `app` of the artifact of the hash and a `github.com` URL; the build flags). | The probe flows. A pure function from the answer and the build request could do `indexed_app`: a later slice. |
| 5 | The hash set from the answers that are not closure answers (the release lists R-AP1, R-AP2, R-AP13, and `?short=`). `admit` reads closure answers only. | See Q2. |
| 6 | `queued_at` (the clock of Talon, R-EV22) and `talon_version` (`tln` version). | The command passes them. |
| 7 | Where a failed `Queue` write goes in the command (the warning is printed by `enqueue!`). | Part of 1. |

## Questions (answered 2026-11-03: Design Q431 to Q436, CLI R-SH3, R-SH4, R-TF7)

| # | Answer | Test change |
| --- | --- | --- |
| Q1 (Q431) | Only a nightly tag passes filter 3. | L0 rows: a release id is refused. |
| Q2 (Q432) | The hash set is the `hash` of each artifact record and release (R-AP1, R-AP2, R-AP13, R-AP14, closure answer). Dep hashes, `platform_hash`, `unknown`, `runs`, `nearest`, `hints` do not count. New filter 7: the target the Worker takes for the kind. | L0 filter 4 rows, new filter 7 expect, `ShareQueue.Why` gains `Target`. `admit` still takes closure answers; the answers of R-AP1, R-AP2, R-AP13, R-AP14 are a later input (206b). |
| Q3 | Stays with slice 218 (the list of machine errors). `admit` takes `machine_error : Bool`. | None. |
| Q4 (Q433) | A P2 table is made by the first write to it. A read of a missing table gives no rows. `fx/db1` stays. | None: `sq1` fits (a `Queue` write makes the table, a facts write on a new file makes no `share_queue`, `QueueCount` makes no table). `sq1` step 10 keeps the slice 213 contract that `ClearQueue` makes the table: the manager should confirm this reads as "first write". |
| Q5 (Q435) | The proposal is confirmed: warning and lost rows, a newer file is exit 19. | None (`sh10`, L0 expect 12). |
| Q6 (Q434) | `seq` can restart. Only the order counts. | None: no test reads a restart value. |
| Q7 (Q436) | The last `cap` rows stay. | None (`sh9`, `sq1` step 7). |
| G-C87 (Q450, test step done) | With no artifact record, the kind and the targets come from the header of `packages/<hash>/main.roc`. With no file, the row fails filter 7. | New L0 rows: a release-only hash with a header file passes, with no file it fails. |
| G-C88 (Q451) | `ClearQueue` makes the table on an old file: each insert or delete makes it first. | None: `sq1` step 10 stays. |

## Disputes (from the code agent)

None yet.

## Verify results

Red result (2026-11-03, stubs installed):

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-8.roc` | 146 pass, 12 fail: each `SharequeueTest` expect, `todo: slice 215` |
| `tests/commands/run.sh` | 289 pass, 3 fail: `share/sh8-queue-write`, `sh9-queue-cap`, `sh10-queue-errors`, `[ROC CRASHED] todo: slice 215` |
| `tests/run.sh fx/sq1` | 1 fail: `[ROC CRASHED] todo: slice 215` at the first `Queue` write (step 2); the L3 case `fx/db` passes (2 of 2, the dump change is safe) |
| `scripts/test.sh check fmt` | check passes. fmt fails only for `cli/lib/PickFlow.roc` (a file of the 206b agent). |
| `MISSING=1 scripts/rules.sh R-SH2 R-SH3 R-SH4 R-EV26 R-TF7` | no id with no test |

With the private reference installed: L0 158 of 158, L2 `share/` 10 of 10, L3 `fx/sq1-real-fx-queue` passes. The expected files of the 3 L2 cases and of the L3 case were written by hand (the form of `diff -u` for the tree diffs only, made from my own expected rows) and not from a run: the reference passed them without `UPDATE=1`.

Expected exits (read, TW21): `sh8` and `sh9` exit 0, no stderr. `sh10` has exit 0 and `exit 19` in stdout for the third run (R-TF3, the proposal Q5), the 2 warnings on stderr. `sq1` exit 0; the only failures in its stdout are the intended `err TooNew(2)` and `err Failed(...)` lines of steps 12 and 13.

Revert check: see `research/slice-215-revert/results.txt` (13 mutations, then 5 more after the answers, each caught; the references are deleted).

After the answers (red): `roc test tests/unit/l0-8.roc` 146 pass, 13 fail (all `todo: slice 215`). L2 and L3 results are as before (L2 3 fail, L3 `sq1` 1 fail).

## Code

| File | Change |
| --- | --- |
| `cli/lib/ShareQueue.roc` | `admit` (conditions, then filters 1 to 7 in order), `err`, `enqueue!`; imports `Compiler`, `Matrix`, `PinOrder`. A hash with a release row only passes filter 7 (filter 7 reads `headers` when no `artifacts` row, Q450). |
| `cli/lib/Db.roc` | `queue_line`, `queue_of` |
| `cli/RealDb.roc` | `Queue` arm: `queue_insert!` (one transaction: `CREATE TABLE IF NOT EXISTS`, `INSERT ... ON CONFLICT DO NOTHING` per row, delete the smallest `seq` beyond `cap`) |
| `cli/lib/ShareQueue.roc` (Q450) | Filter 7: kind and names from the first `artifacts` row, else the `headers` entry, else `Skip(Target)`. |

Copies: `research/slice-215-revert/code-final/`, hashes in `code-final.sha256`.

## Q450 for the code agent (2026-11-03)

| Item | Text |
| --- | --- |
| Input | `admit` has a new field `headers : List({ hash : Str, kind : [Package, Platform, App], names : List(Str) })`: the kind and the target names that the caller read from `packages/<hash>/main.roc` (R-DI7, Registry R-RE20) for a hash with no `artifacts` row. (`names`, not `targets`: `targets` is a reserved word.) |
| What the code must change | In `admit`, filter 7: the kind and names come from the first `artifacts` row of the hash, else from the `headers` entry of the hash, else `Skip(Target)`. Today the body has `[] => Bool.True` for no row: that is the defect that the new expect shows. |
| Tests | L0 `SharequeueTest` expect 8c: 10 rows (package, platform pass and fail, app, no file, another hash, an `artifacts` row wins). The filter 4 row "only in a release row" now gives a header entry. The only red test is the new expect. |
| Who reads the files | Not `admit` (it is pure) and not this slice: the flow that calls `admit` after a probe (the probe and resolve command code, slice 206b and later) reads `packages/<hash>/main.roc` with `read_files!` and parses the header (`roc-app-header`, the kind and the platform targets), only for a fact whose hash has no `artifacts` row. A missing file is no entry. |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-215-revert/code-final.sha256` | 3 of 3 OK (`ShareQueue.roc`, `Db.roc`, `RealDb.roc`) |
| `todo: slice 215` in `cli/` | None |
| L0 | `l0-8` 160 of 160 (`SharequeueTest`). Other red drivers (`l0-6`, `l0-7`) are slice 206b tests in progress. |
| L2 | `share/sh8-queue-write`, `sh9-queue-cap`, `sh10-queue-errors` green |
| L3 | `fx/sq1-real-fx-queue` and `fx/db` green (real SQLite) |
| Expected exits | `sh10-queue-errors`: 19 (a newer `compat.db` format, Q435). The others exit 0. |
| Revert check | 18 of 18 caught (13 in round 1, 5 for Q431 and Q432) |
| Design answers | Q431 to Q436, Q450, Q451 |
| Moved out | The calls of `admit` and `enqueue!` in real commands, the read of `packages/<hash>/main.roc` headers for Q450, the hash set from non-closure answers, `queued_at` and `talon_version`: slices 206e, 206f and later. R-SH2 recheck before the send: 216. R-SM7 list: 218. |

