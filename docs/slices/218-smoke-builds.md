# 218 Smoke builds

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 218 of `PLAN-P2-CLI.md`. After the work of a command and before the queue send, only with sharing on (R-SH2), Talon runs one smoke build for each built key (platform hash, nightly, target) that passes R-SM3 rows 1 to 5. It uses the app of R-SM2, `probe.timeout`, no budget, and changes no output. The result goes in the table `smoke` of `compat.db`, and in the share queue (R-SH3 filter 2 has `Smoke`, filter 6 stops a machine error and a hang). Row 209b (a `bot` smoke `fail` in the ladder) builds on this table of rows but not on this slice: it reads the registry, not the table.

G-C2 is answered (Design Q201, 2026-11-02): the table `smoke` has the columns `hash`, `nightly`, `target`, `outcome`, `PRIMARY KEY (hash, nightly, target)`; a machine error writes no row; `user_version` stays 1 (R-TF7). The existing code for the app of R-SM2 is `InitStub.app_text` (slice 055, `tln init --platform`): the smoke app is the same text with the body `crash "talon smoke test"`. Slice 215 has the queue side (`ShareQueue.admit` with `probe: Smoke`, `machine_error`), slice 216 the send, slice 206e4 the hooks (`ShareHook`, `ShareRound`).

## Rules

R-SM1, R-SM2, R-SM3, R-SM4, R-SM5, R-SM7 (client part). Named in the tests as used: R-SM6 (a `bot` row), R-SH2, R-SH3, R-SH4, R-RC1 to R-RC4, R-P3, R-P5, R-LD8, R-BS1, R-TF2, R-TF3, R-TF7, R-CC8, R-EV26.
Design: Resolution 4 "Smoke build" (R-SM1 to R-SM7), R-TG2 (the key has the build target); CLI 1 (R-SH2 to R-SH4); CLI 6.1 (R-TF7, the table `smoke`); Design Q42, Q43, Q201, Q496, Q534, Q536. Slices read: 055, 206e4, 215, 216, 217.

## Scope

| Part | Where | Layer |
| --- | --- | --- |
| R-SM3 rows 1 to 5: which built keys get a build | `Smoke.choose` (pure, new) | L0 |
| R-SM4, R-SM7, R-P3: the class of a smoke result (a row, a machine error, no fact) and the machine error list | `Smoke.result`, `Smoke.machine_errors` | L0 |
| R-SM2: the text of the smoke app | `Smoke.app_text` (calls the generator of `InitStub`) | L0 |
| R-TF7: the row form of the table | `Db.SmokeRow`, `Db.smoke_line`, `Db.smoke_of`, the variants `Smoke` of `Db.Query`, `Db.Answer` and `Db.Write` | L0, L2 (fake), L3 (real) |
| The flow after the work and before the send | `ShareHook` (a new step before `ShareHook.send!`) | L2 (7 cases) |
| The SQL of the table | `cli/RealDb.roc` (2 arms) | L3 `fx/sq3-real-fx-smoke` |

## Public signatures (stubs, `crash "todo: slice 218"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `Smoke.machine_errors` | `List(Str)` = `["WindowsSDKNotFound"]`. Not a stub: a constant | R-SM7 |
| `Smoke.Why` | `[NotInstalled, Done, BotRow, Hints, Compiler, NotInAnswer]` | R-SM3 |
| `Smoke.Choice` | `{ key : Db.Key, verdict : [Build, Skip(Why)] }` | R-SM3 |
| `Smoke.choose` | `{ built : List(Db.Key), installed : List(Str), done : List(Db.SmokeRow), recorded : List(Str), answers : List(Wire.Answer), domain : List(Nightlies.Release) } -> List(Choice)`. One choice for each key, in the order of the first appearance. The first false condition of R-SM3 rows 2 to 5 is the reason. | R-SM3 |
| `Smoke.result` | `Probe.Output -> [Row(Db.Outcome), Machine, NoFact]` | R-SM4, R-SM7, R-P3 |
| `Smoke.app_text` | `{ url : Str, text : Str } -> Try(Str, [NoSmoke])` (`app` is a keyword of Roc, so not `Smoke.app`) | R-SM2 |
| `Db.SmokeRow` | `{ hash, nightly, target : Str, outcome : Outcome }` | R-TF7 |
| `Db.smoke_line`, `Db.smoke_of` | `hash<TAB>nightly<TAB>target<TAB>outcome`; `Err(BadLine)` for a wrong word count or word | R-TF7 |
| `Db.Query` `Smoke(List(Key))`, `Db.Answer` `Smoke(List(SmokeRow))`, `Db.Write` `Smoke(List(SmokeRow))` | The contract is in the doc of `Db.SmokeRow`: a missing file, version 0 and a missing table give no row and make nothing; a write makes the table (first write), keeps `user_version` 1, `TooNew` writes nothing. The fake log words are `smoke=<count>`. | R-TF7, R-TF3, R-CC8 |

Edits to existing files (copies in `research/slice-218-revert/before/`): `cli/lib/Db.roc` (3 variants, 1 type, 2 stubs), `cli/lib/main.roc` (1 expose), `cli/RealDb.roc` (3 empty-case arms, done; 2 SQL arms with `crash "todo: slice 218"`), `cli/fxprobe.roc` (2 calls, done, doc table), `tests/commands/FakeDb.roc` (the fake of `Smoke`, done), `tests/commands/L2Db.roc` (2 words), `tests/tools/dumpdb.py` (the `smoke` lines), `tests/unit/l0-5.roc` (1 import). New: `cli/lib/Smoke.roc`, `tests/unit/SmokeTest.roc`, 8 L2 cases, 1 L3 case. No file of the 206f agent was edited (`Opts`, `Install`, `Add`, `FullName`, `Lookup`, tool install, `x`).

## The flow as I read it

The step runs in each command that sent a closure query and that built (the commands of `ShareHook`), only when R-SH2 is true, after the output and before `ShareHook.send!`. It has no output and never changes the exit code (R-SM4). A command with no built key (an `update` with no build, `--no-check`) makes no call of this step.

| # | Reading | Source |
| --- | --- | --- |
| R1 | The keys are the (platform hash, nightly, target) of each ladder step 3 build of the command, also a skipped build (R-BS1: the key of the recorded pass). The target is the target of the build (`BuildTarget.key`: `Named(t)` or the host target). | R-SM3 |
| R2 | The calls, in this order, when at least one key was built: `db_query` `Smoke` (the built keys), `platform`, `db_query` `Pinned` (the recorded sha256 of the nightly of each key: the `recorded` of filter 3). Then one `Smoke.choose`. No other call decides: `installed` comes from the toolchain list that the command read, `answers` and `domain` from the run (`Fail.Ran`). | R-SM3 rows 2 to 5 |
| R3 | The builds of the keys with `Build` run in one `Fx.probes!` round (the order of the list). Each in its own temp dir: `random`, `make_dirs` (`talon/tmp/<16hex>`, R-CC2), `write_atomic` of `<tmp>/main.roc` with `Smoke.app_text` of the header text of the platform, then `roc build --target=<key target> main.roc --output=<tmp>/tln-probe.out --no-cache` (R-LD8; the same program and `env` as the other probes of the command), `timeout` = `probe.timeout`, the cwd is the temp dir. No budget: nothing is counted, nothing is checked against `probe.max`. | R-SM1, R-SM2, R-SM4, R-LD8 |
| R4 | The header text of the platform is the text that the command read already for its build target (`packages/<hash>/main.roc`, the line `read_files` in the baseline): no new read (Design Q535: a command reads a header file once). | Q535 |
| R5 | `Smoke.result` of each output. `Row(o)`: `db_write` `Smoke` with all rows of the round (one call), also `hang`. `Machine` and `NoFact`: no row. Then `delete` of each temp dir. | R-SM4, R-SM7, R-P3 |
| R6 | The queue: the smoke facts (`origin: Probed`, `probe: Smoke`, the real target, `machine_error: false` for a stored row) go through `ShareRound.enqueue!`: `platform`, `db_query` `Pinned`, `clock`, `db_write` `Queue`. A `hang` makes the calls but no row (filter 6), so no `Queue` write. A round with no stored row makes no queue call. Filters 4 and 5 use the answers of the command, as for a unit fact. | R-SH3, Q539 |
| R6b | The result is never evidence: it goes in no fact of `compat.db` and the solver and the build skip do not read it. | R-SM4 |
| R7 | Then `ShareHook.send!` as before (the new row is in the POST). | R-SH4 |
| R8 | A row of `smoke` for a key (any outcome, `hang` too) stops a later build of that key (R-SM3 row 3). A machine error and a result with no fact write no row, so a later command builds again. | R-SM3, R-SM4 |
| R9 | `--dry-run` runs the smoke step like the queue step (Design Q538: probe facts go in `compat.db` in a dry run). Not tested. | R-LF4, Q538 |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/SmokeTest.roc` (driver `l0-5`) expect 1: `machine_errors` | R-SM7 |
| L0 | expect 2: `choose` row 1 (one key, 2 targets, a key twice, 2 nightlies, 2 hashes, a done key and another target) | R-SM3 |
| L0 | expect 3: row 2 (installed, none, another nightly) | R-SM3 |
| L0 | expect 4: row 3 (a pass, fail, hang, crash row of the key, a row of another target, nightly, hash) | R-SM3, R-SM4 |
| L0 | expect 5: row 4 (a bot row in the interval, a bot pass, an author row, a bot unit row, another hash, an interval before the nightly, a `nearest` row of the other tag form, the second answer; hints 3 and 2 and the other tag form, other target, nightly, hash) | R-SM3, R-SM6, R-CV1 |
| L0 | expect 6: row 5 (recorded, not recorded, a release id, a named build, a `releases` row only, the second answer, no answer, `unknown` only, no answer at all) | R-SM3, R-SH3 |
| L0 | expect 7: the order of the reasons (6 steps) | R-SM3 |
| L0 | expect 8: `result` (pass, errors, a target error, a link error, timeout, SIGSEGV, exit 139, SIGKILL, SIGTERM, not started, no text, a machine error on stderr, in a report, with exit 139) | R-SM4, R-SM7, R-P3, R-RC1 to R-RC4 |
| L0 | expect 9: `app_text` (one argument, `()` with the old form, an alias with a record, a `Str` value, a record with a `U16` field, 2 entries, a package header) | R-SM2 |
| L0 | expect 10: `Db.smoke_line`, `Db.smoke_of` (4 words, round trip, 4 bad lines) | R-TF7 |
| L2 | `share/sh70-smoke-build` (2 runs, `verify`): the smoke block of calls in the right place (after the work, before the send), the app build for the key, `--target`, `probe.timeout` 7 with `probe.max` 5 (no budget), the row, the queue row `x64musl`, the POST of 4 rows, the same stdout as with no smoke build. Run 2: the key is in the table: the 3 queries and nothing else | R-SM1, R-SM2, R-SM3, R-SM4, R-SM5, R-SH3, R-SH4, R-P5, R-TF7 |
| L2 | `share/sh71-smoke-build-skipped`: ladder step 3 uses the build skip, `--no-probe`, the smoke build still runs | R-SM3, R-BS1, R-SM8 |
| L2 | `share/sh78-smoke-moved-platform`: the key has the hash of the built tuple (`smoke.tsv`, `--target`); the app URL is the L0 `app_text` expect | R-SM2, Q549 |
| L2 | `share/sh79-smoke-update`: `update --dry-run` with a ladder build runs the smoke build too, not only `verify` | R-SM1, R-SM3, R-SM4 |
| L2 | `share/sh61-ladder-share-header` (slice 206e4, changed): its `update` with a ladder build now has the smoke block, the queue row and a 4-row POST (`unqueue=4`). The Q535 header read stays one read for each hash | R-SM1, R-SH3, Q535 |
| L2 | `share/sh72-smoke-bot-row`: a `bot` row for the key in the answer: the queries, no build, no row, no queue write | R-SM3 row 4, R-SM6 |
| L2 | `share/sh73-smoke-fail`: the smoke build fails: row `fail`, queued `fail`, output and exit code of the baseline | R-SM4, R-SH3, R-RC2 |
| L2 | `share/sh74-smoke-machine-error` (2 runs): `WindowsSDKNotFound`: no row, no queue; run 2 builds the key again | R-SM7, R-SM4, R-SM3 |
| L2 | `share/sh75-smoke-off` (2 runs, `DO_NOT_TRACK=1`, `CI=true`): no call of the step. Passes before the code (a guard) | R-SM5, R-SH2 |
| L2 | `share/sh76-smoke-hang`: a timeout: row `hang`, no queue row | R-SM4, R-SH3, R-RC3 |
| L2 | `share/sh77-smoke-table-fake` (entry `db`): the fake `Fx` of the table (also the first row stays), and `Db.smoke_line` | R-TF7 |
| L3 | `tests/scenarios/fx/sq3-real-fx-smoke` (`fxprobe`, 8 steps): the real SQL. A missing file (no file made, no key, no row); a write makes the file, 2 base tables and `smoke`, no `share_queue`, `user_version` 1; a query gives the rows of the keys (4 outcome words, another target, nightly and hash give none); a second write keeps the first rows; an old file (query makes no table, write makes it, facts stay); `user_version` 0; a newer file (`TooNew`, same bytes); a text file (`Failed`, same bytes). `expect/facts.tsv` has the 5 `smoke` lines | R-SM3, R-SM4, R-TF7, R-TF2, R-TF3, R-CC8, TW4 |

The L2 cases are the world of `share/sh60-ladder-share` (`verify` with the registry answer, sharing on, held nightly-2026-10-14-38a3029, `pinned` recorded), with `acme/pfx` 0.1.1 as the platform of the project header (so the platform of the build is the platform of the header; `sh78` moves it: Q549). The baseline of each case came from `UPDATE=1` on the current code (no smoke build); `research/slice-218-revert/patch-expect.py` edited the expected files by hand to the readings above (TW21; the baseline copies are in `research/slice-218-revert/baseline/`). `L0` and `sh77` were checked with a private reference (deleted). The L3 expected files came from a private reference of the 2 SQL arms (deleted); every step was read.

## Output (proposed, R-OUT2, TW24)

None. A smoke build prints nothing, changes no `--json` and no exit code (R-SM4). A failed `Smoke` write is the warning of R-CC8 as for a facts write (text as the existing warning); it is not tested here (no case), see the doubts.

## Expected exits (read, TW21)

All L2 runs exit 0 (the exit code is the one of the command: R-SM4). `sh74` run 1 and `sh76` have a smoke result that is not a pass, and still exit 0. `sq3` exits 0; its `err TooNew(2)` and `err Failed(...)` lines (steps 7 and 8) are the intended results. No stderr in any case.

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `roc test tests/unit/l0-5.roc` | `SmokeTest`: 9 of 10 expects fail with `todo: slice 218` (the constant `machine_errors` passes). Other failures of the driver (`ProbecmdTest`) are the 206f agent's |
| `tests/commands/run.sh share/sh7` | `sh70`, `sh71`, `sh72`, `sh73`, `sh74`, `sh76`: no smoke call (`calls.log`, `tree.diff`; stdout, stderr and exit are equal); `sh77`: `[ROC CRASHED] todo: slice 218`; `sh75` passes (a guard) |
| `tests/run.sh fx/sq3` | `[ROC CRASHED] todo: slice 218` at the first write |
| `scripts/test.sh l0 l2 l3` | the new tests fail as above. The other failures are the 206f agent's: `ProbecmdTest`, `RemovalTest`, `add/ad3`, `registry/ad35-*`, `ad36`, `ad37`, `e6`, `rg7-*`, `sc3-*`, `sc4-*`, `sn6` |
| `MISSING=1 scripts/rules.sh R-SM1 R-SM2 R-SM3 R-SM4 R-SM5 R-SM7` | no id with no test |

## Out of scope

| Item | Why |
| --- | --- |
| The smoke build of a tool build (R-SM3 "and the build of a tool", CLI 6.4: `tool install`, `tool update`, `x`, `run`) | Those commands are the 206f files and are not wired to the queue yet (Design Q534: "each wired in the slice that makes its facts"). Question Q3 |
| `update`, `install` and `upgrade` cases | The step is in `ShareHook` and is shared with `verify`; the cases use `verify` (the world of `sh60`). See doubt D9 |
| R-SM6, slice 209b (a `bot` smoke `fail` as a step 3 fail) | A registry read, not the table |
| `tln probe --share` and the smoke rows (Design Q496) | R-PB6 sends the facts of `compat.db` only |
| A failed `Smoke` write (busy, failed, `TooNew`) in the command | The calls are those of `Facts.save!` (R-CC8); no case. Doubt D10 |
| The generator itself (`InitStub`) | Tested by slice 055 (`InitTest`) and the 7 rows of expect 9 |
| The bot (Registry R-MX10) | W-side |

## Questions (answered 2026-11-03: Design Q548 to Q554, Resolution R-SM2, R-SM4, R-SM7, R-SM8)

| # | Answer | Test change (round 2) |
| --- | --- | --- |
| Q1 (Q548) | A machine error is a stderr line, with no white space at its end, that is exactly `Error: <name>`, any exit code. Stdout is not read, a substring does not count | L0 expect 8: 5 rows of a machine error (a line after a linker report, exit 139, exit 0, trailing white space), 4 rows of no machine error (the name in a title, a longer line, a longer name, stdout only), an `ld64.lld` error is a `fail` |
| Q2 (Q549) | The smoke app has the URL of the built tuple (the hash of the key), not the header URL | New L2 `share/sh78-smoke-moved-platform`: the world of `sh60` (the tuple moves the platform 0.1.0 to 0.1.1). `fx/delete` denies the delete of the temp dir, so `tree.diff` shows the smoke `main.roc` with the 0.1.1 URL |
| Q3 (Q550) | Tool builds are not in this slice (a plan choice) | None |
| Q4 (Q551) | The first row stays (`ON CONFLICT DO NOTHING`), also a repeat in the same call | L3 `sq3` step 4b, L2 `sh77` (last 2 runs); doc of `Db.SmokeRow`, fake |
| Q5 (Q552) | A command that ends with an error runs the smoke builds when the send runs (not after exit 15 or 19) | Not tested: no cheap world (it needs a failed command after a built key). A case like `sh57-send-after-error` with a build is the next step |
| Q6 (Q553) | `--no-probe` does not stop them | `sh71` now runs `verify --no-probe` (the build skip, no unit probe, a 2 row POST) |
| Q7 (Q554) | One `probes!` round for all keys. Per key, in key order: `db_query` Smoke, `platform`, `db_query` Pinned, `random`, `make_dirs`, `write_atomic`; then one `probes!`; then `db_write` Smoke and `delete` for each key; then the queue calls. Each build has `--target=<key target>` | The `calls.log` of the cases is this order already (one key). No case has 2 keys, and none can: each command takes one project file (`--file`), and one app has one platform and one target, and tool builds are out. The order of 2 keys is not tested |

## Out of scope (added in round 2)

Two keys in one command (see Q7), a failed command with a built key (Q5), the tool builds (Q3).

## Doubts (a reading that the code agent may dispute)

| # | Doubt |
| --- | --- |
| D1 | The call order of R2 (`Smoke` query, `platform`, `Pinned`) and R3 (`random`, `make_dirs`, `write_atomic`, `probes`, `Smoke` write, `delete`) is a reading. The cases fix it. The temp dir is a new `random` and `make_dirs` after the command's own `delete` (the name is the same in the fake). |
| D2 | The queue step after the smoke write repeats `platform` and `Pinned` (the call of `ShareRound.enqueue!` as it is). The smoke step needs `Pinned` before the build (R-SM3 row 5). A code that passes the first answer to `ShareRound` would drop the second pair of lines: a dispute, not a design change. |
| D3 | For a `hang` the queue step makes `platform`, `Pinned` and `clock`, and no `Queue` write (R6). A code that stops before these calls for a result that cannot pass filter 6 is also valid: then `sh76` changes (3 lines). |
| D4 | The smoke build always has `--target=<key target>`, also when ladder step 3 had no `--target` (`Unlisted`: the key has the host target). The target is a valid roc target name, so this builds the same. `sh70` fixes `--target=x64musl` while the baseline build has none. |
| D5 | R4 (no new read of the platform header) is the reading of Design Q535. In a run where the command did not read the header (no build target check), a `read_files` is needed; no case has it (all cases read the header for the build target, also the skipped build: `sh71`). |
| D6 | `installed` is `Compiler.find` of the key's compiler (an installed toolchain, or the `roc` on `PATH` of that id, as the probes of the command use). No new `list_dirs` or `path_roc` call. |
| D7 | A result with no fact (`NoFact`: SIGKILL, not started, no result) writes no row (R-P3 "no fact" and the text of the table: "a machine error writes no row"). Not in an L2 case (L0 only). |
| D8 | `Smoke.result` takes the machine error from the whole text before the class (R-SM7: "a result with such an error"). |
| D9 | The cases run `verify` only. `update`, `upgrade` and `install` call the same hook, so the step is the same; each command that builds needs the key list (`built`) in `Fail.Ran`. No case for them: a reviewer may ask for one. |
| D10 | A busy or failed `Smoke` write: R-CC8 warning and the command goes on (as for facts). Not in a case. |
| D11 | The probe weight is 4 (a build, `Probe.weight`), `probe.slots` is the pool. Not visible in `calls.log`. |
| D12 | `max = 5` in `sh70` shows "no budget" only if `verify` counts its probes against `probe.max` (R-PP4); the baseline does not fail with 5. If `verify` does not count, the line only checks `timeout`. |

## Code

| File | Change |
| --- | --- |
| `cli/lib/Smoke.roc` | `choose`, `result`, `app_text` (the generator of `InitStub` with the stub body replaced) |
| `cli/lib/Db.roc` | `smoke_line`, `smoke_of` |
| `cli/RealDb.roc` | the query arm (no table: no row) and `smoke_insert!` (`CREATE TABLE IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, one transaction) |
| `cli/lib/Fail.roc` | `Fail.Built`, and `Ran.built` |
| `cli/lib/BuildFlow.roc` | `Plan.header` (the header text that step 3 read: no second read) and `Plan.url` (the URL of the platform of the built tuple, Q549) |
| `cli/lib/Ladder.roc` | `Ran.built`, `build_round!` gives it, `verify!` collects it (`built_of`) |
| `cli/lib/VerifyFlow.roc` | `verified!` gives `{ outcome, built }`; `verify!` puts `built` in the `ran` for the send |
| `cli/lib/InstallWrite.roc`, `cli/lib/InstallFlow.roc` | `ladder!` and `settle!` give `built` (from `Ladder.run!`); `finish!` puts it in the `ran` for the send (install, update, upgrade). `Ladder.run!` gives `built` too |
| `cli/lib/ShareHook.roc` | `smoke!` (the flow), called in `send!` before `QueueSend.send!` (so not after exit 15 or 19); `ran_of` gives `built: []` |
| `cli/lib/ShareRound.roc`, `cli/lib/UnitFlow.roc` | `ShareRound.enqueue!` has a field `probe` (`Unit` for the unit callers, `Smoke` for the smoke step) |

## Review notes (code agent)

| # | Note |
| --- | --- |
| C1 | `verify`, `install`, `update` and `upgrade` give `built` (manager ruling). `RemoveFlow` also calls `Ladder.run!` and ignores `built` (no smoke build for `remove`; not edited). |
| C2 | A failed command (also a failed ladder after a build) gives no `built`: the `built` is in the `Ok` result only, and keeping it would need a change of the `Err` path of `Ladder`. Not small, so not done (the key list is in the `Ok` result only), so Q552 (smoke after an error) is not done for a failure of the ladder after a build. Not tested. |
| C3 | `installed` of `Smoke.choose` is the compiler id of each built key: the ladder ran a program for it (an installed toolchain or the `roc` on `PATH`), so no new `list_dirs` call (D6). |
| C4 | The `probes!` pool is the largest `probe.slots` of the keys; no budget. One `delete!` call for each temp dir, after the one `Smoke` write. A failed `make_dirs`/`write_atomic` deletes the dir and skips the key. A failed `Smoke` write is the R-CC8 warning and nothing is queued; a failed query ends the step with no warning. |
| C5 | The smoke step is one function in `ShareHook`; no other module calls `Fx.probes!` for it. |

## Disputes (from the code agent)

| Case | Rule | Dispute |
| --- | --- | --- |
| `share/sh78-smoke-moved-platform` `expect/tree.diff` | R-SM2, Q549 | The file `tmp/0123456789abcdef/main.roc` is in the work dir after the run (checked in `/tmp/talon-l2/share_sh78-smoke-moved-platform/home/.cache/roc/talon/tmp/`, the text is right), but `tree_diff` in `tests/lib.sh` has `-x tmp`, so no diff shows it. The expected lines `--- .../tmp/0123456789abcdef/main.roc` can never match. Only this case fails. Fix: the runner must not skip this path, or the case must check the file in another way (for example `calls.log` with the text). |
| `add/ad3-registry-ingest-skip` | none | A 206f test, not a slice 218 failure. |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-218-revert/code-final.sha256` | OK, 12 files |
| `grep "todo: slice 218" cli/` | nothing |
| Expected exits | all smoke runs 0: a smoke build never changes output or exit code (R-SM4) |
| Dispute `sh78` | accepted: `tree_diff` leaves out `tmp`; the moved platform URL is checked through `smoke.tsv` and the probe line |
| Older cases updated (R-SM1 now runs in update, install, upgrade) | `sh49`, `sh50` (only the sharing-on run 3), `sh52` (smoke row, no queue row: filter 7, the platform has no `targets`), `sh58`, `sh60`, `sh61`. Each diff was only the smoke block and its queue, POST and totals lines |
| `scripts/test.sh check fmt l0 l2 l3` (`JOBS=3 TEST_TIMEOUT=400`) | all pass, with slice 206f in the tree |
| Design answers | Q201, Q548 to Q554 |
| Not tested or not done | Q552 after a failed ladder (`built` is only in the Ok result); 2 keys in one command (needs tool builds, Q550); `remove` runs no smoke build |
