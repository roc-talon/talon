# 206e4 Index notes and share hooks

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 206e4 of `PLAN-P2-CLI.md`. Slices 210, 215 and 216 built three parts that no command calls: `IndexNotes` (the notes and `data.index_notes`), `ShareQueue.enqueue!` (with the header input of Q450) and `QueueSend.send!`. This slice wires them into `update` and the resolve commands. No new function and no new type: the tests are red on the missing calls (no stub).

## Rules

R-AP29, R-AP30 (CLI 3 R-OUT2), R-SH2, R-SH3, R-SH4 (Q518: not `publish`). As used: R-FL4, R-J6, R-PP4, R-LF4, R-AP10, R-AP16, R-SH5, R-SH6, R-EV26, R-DI1, R-LF1, R-AP34. Design Q406 to Q408 (notes), Q435, Q450, Q452 to Q459, Q464, Q469 (hooks).
Slices read: 206e, 206e2, 206e3, 206e3b, 210, 215, 216, 217 (the filters), the design: CLI 1 R-SH2 to R-SH4, Registry 4 R-AP29, R-AP30, Resolution R-SM3, R-LF4.

## Scope

| # | Part | Commands |
| --- | --- | --- |
| 1 | The index notes (R-AP30: "`tln update`, `tln outdated` and `tln add`") | `update` (also a held move with 2 answers), `outdated`. `add` with names has no registry yet (206f) |
| 2 | `ShareQueue.enqueue!` after a probe round that gave facts | The commands that probe with an answer: `update`, `install`, `upgrade`, `verify` (the ladder and the oracle loop) |
| 3 | `QueueSend.send!` at the end, after the output | Each command that sent a registry request: `update`, `install` (no names), `upgrade <names>`, `verify`, `outdated`, `why` (all send the closure request, 206e to 206e3b) |

Not: `tln publish` (Q518), `tln probe --share` (217), the smoke build (218), the tool builds (R-T21), the commands with only a compiler list request (`roc ...`, `x`, `tool ...`): question Q2.

## The flow as I read it

| # | Reading | Source |
| --- | --- | --- |
| R1 | An index note is one `note:` line like the other notes, in the notes block (after the other `note:` lines, before `check:`), for `update`. `data.notes` ends with the texts, and `data.index_notes` is the last member of `data` (after `written`). | Q407: "the text of each index note is in `notes` as for every note". The place is a proposal |
| R2 | `outdated`: the `note:` lines after the table, one for each stale repository. `data` gets `index_notes` after `members`. `outdated` has no `notes` list, so none is added. | Proposal (R-OUT2) |
| R3 | `--quiet` hides the notes (R-FL4). `--json` still has `data.index_notes`. The exit code does not change (R-AP30). | R-FL4, R-AP30 |
| R4 | Only `stale` decides. A fresh item gives no note, also with an old time. Held move: the notes come from the stale items of both answers, one for each name, the older `checked_at` (null oldest), sorted by name. | R-AP29, Q408, `IndexNotes.notes` |
| R5 | Enqueue point: right after the `db_write` of the facts of a round (R-PP4), for the facts that this round probed (R-SH3 filter 1). Calls, in this order, only when R-SH2 is true and at least one fact of the round can pass filters 1 and 2: `db_query` `Pinned` for the compiler (the `recorded` of filter 3), `clock` (`queued_at`, R-TF7), one `db_write` `Queue` with `cap` 10000. A round with no row: no queue call. | Plan row 206e ("after the probe rounds"), slice 215 "For 206b and later" row 1. The calls are my reading |
| R6 | The rows are in the order of the facts of the round (the order of the probe results, R-PP3). A unit probe of a package or a platform passes filter 2. The build row of the ladder (an app build) does not. | R-SH3, R-PP3 |
| R7 | The send: after the output, `QueueSend.send!` with `share` of `config.toml`, the registry, `--offline` and the environment of the command. R-SH2 is checked again inside it. The calls are those of slice 216: `queue_rows`, `share.json`, `clock`, the POST, `unqueue`, `clock`, the totals write. With R-SH2 false or no request the command makes no queue call at all. | R-SH2, R-SH4, slice 216 |
| R8 | `--dry-run` queues and sends: R-LF4 forbids only project files, and probe facts still go in `compat.db`. | R-LF4 |
| R9 | The send never changes the output, the `--json`, the stderr or the exit code (also a 503). | R-SH4 |
| R10 | A command that sent no request to the registry (`install --frozen`, a header with no group and no hash, Q469) does not send the queue. | R-SH4 ("a command that sent a request") |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L2 | `registry/ap30-update-notes` (3 runs): `update --no-check --dry-run`: json stale 3d2h, parser fresh with an old time, pfx stale and null. Human (2 notes, sorted), `--json` (`notes` and `index_notes`), `--quiet` (nothing) | R-AP29, R-AP30, R-FL4, R-J6, Q407 |
| L2 | `registry/ap30-held-move-notes` (2 runs): the held move of `sp24-update-held-move` with `checked` in both answers: json stale in both (the older, 2d), pfx fresh then stale null, yaml stale in the first only (12m). Human and `--json` | R-AP30, R-AP16, Q408 |
| L2 | `registry/ap30-outdated-notes` (3 runs): `outdated`: the table and the notes, `--json` (`index_notes` after `members`), `--quiet` (table only) | R-AP29, R-AP30, R-FL4, Q407 |
| L2 | `share/sh49-update-share` (2 runs): `update` with probes, `share = true`, no `CI`, `pinned` recorded, one queue row. Run 1: the 2 unit facts (parser, platform) are queued after the facts write, the build fact is not, the send has 3 rows, 201, `unqueue=3`, totals. Run 2: no probe, no queue write, the queue is empty (read only) | R-SH2, R-SH3, R-SH4, R-SH5, R-SH6, R-PP4, R-LF4 |
| L2 | `share/sh50-update-share-off` (3 runs): `DO_NOT_TRACK=1` (probes, no queue call), `CI=true` (no queue call), then plain: the stored facts of run 1 are not queued (filter 1), only the old row is sent | R-SH2, R-SH3, R-SH4, R-EV26 |
| L2 | `share/sh51-send-install`, `-verify`, `-upgrade`, `-outdated`, `-why` (1 run each, a 503): the command sends the queue at its end (one POST with the row), the row stays, no other effect, exit 0 | R-SH4, R-SH2, R-AP34 |
| L2 | `share/sh56-no-request-no-send` (2 runs): `install --frozen` and a header with no group and no hash: no request, so no queue call. Passes before the code (a guard) | R-SH4, R-DI1, R-LF1 |

No L0 test: no new pure decision is named by the design (the notes and the filters have their L0 tests in 210 and 215). The fixtures are made by `research/slice-206e4-revert/mkcases.py` (each from an existing case). The expect files came from `UPDATE=1` on the current code (a baseline with no hook), then `research/slice-206e4-revert/patch-expect.py` edited them by hand to the readings above (TW21). Each expected `stdout`, `stderr`, `exit`, `calls.log` and `tree.diff` was read.

## Proposals (R-OUT2, TW24)

| Item | Proposal |
| --- | --- |
| Human line | `note: index: acme/json checked 3d ago` and `note: index: acme/pfx not checked since its first ingest` (the text of R-AP30, the `note:` prefix of the other notes) |
| Place, `update` | After the other `note:` lines, before `check:`. Also on stderr in a `--json` run (as every note) |
| Place, `outdated` | After the table |
| `--json` | `data.index_notes` as `IndexNotes.index_notes` (`kind`, `name`, `checked_at`, `text`), last member of `data` for `update`, after `members` for `outdated`. No `notes` list for `outdated` |
| Send | No output (R-SH4) |

## Expected exits (read, TW21)

All 11 cases exit 0 in each run (`expect/exit` 0, the multi-run stdout has `exit 0`). `ap30-held-move-notes` stderr: the held report (`~ pf ... (held)`) and the human text of the `--json` run, as `sp24-update-held-move`; the notes lines only in the run-2 text. No other stderr.

## Red result

| Run | Result |
| --- | --- |
| `tests/commands/run.sh` | 385 pass, 24 fail: 10 of the new cases (`ap30-*` 3, `sh49`, `sh50`, `sh51-send-*` 5) and the 14 `publish/` cases of slice 222. `sh56` passes (a guard) |
| `ap30-*` | no `note:` line, no `index_notes` |
| `sh49`, `sh50`, `sh51-*` | no queue call (`db_query pinned`, `clock`, `queue=2`, `queue_rows`, the POST) |
| `scripts/test.sh check fmt l3` | pass |
| `scripts/test.sh l0` | fails only in `tests/unit/PublishCheckTest.roc` (slice 222) |
| `MISSING=1 scripts/rules.sh R-AP29 R-AP30 R-SH2 R-SH3 R-SH4` | no id with no test |

No private reference was built: I could not make one without code in `cli/` (the hooks are in many flows). The expected files are from the readings, so the code agent may dispute a call order (R5 to R7).

## Out of scope

`add` with names (206f), `install --frozen` registry reads, `probe --share` (217), the smoke build and the machine-error list (218), the tool builds and `x` (R-T21: `indexed_app`, `changed`, `git_ref`), the commands that read only the compiler list, the failing queue write in a command (warning, exit 19: slice 215 `sh10` covers `enqueue!`), `publish` (Q518).

## Questions (stop until answered)

Manager (2026-11-03): Q1 to Q5 went to TalonRegistry as G-C165 to G-C169; G-C170 asks about `--dry-run`. The code step waits for the answers.

| # | Question | Not tested | Answer and test change |
| --- | --- | --- | --- |
| Q1 | Does a command that ends with an error (exit 10, 15, ...) run the send and print the index notes? R-SH4 says "at its end, after its output", R-AP30 says "the note does not change the exit code". Neither says what a failed command does. | A failed run | Answered (Q533, R-SH4 detail 10): yes for both after an error, except exit 15, 19 and a signal for the send; the notes go after the error text on stderr, none in the `--json` error object. Test change: new L2 `registry/ap30-update-error-notes` (`update` with a stale item and no tuple, exit 10: the note line after the error) and `share/sh57-send-after-error` (`install` exit 10 after an answer: the send runs; exit 15: no queue call) |
| Q2 | R-SH4 says "a command that sent a request to the registry". Which commands are that besides `update`, `install`, `upgrade`, `verify`, `outdated`, `why`? Does `tln roc install`, `tln upgrade roc` with only the compiler list, `tln init`, `tln x`, `tln tool install` send the queue (a list request is a request)? I took the closure commands only. | These commands | Answered (Q534, R-SH4 detail 11): a closed list; `roc install`, `upgrade roc` with only the list, `init`, `x` and `tool install` are not in this slice. Test change: new L2 `share/sh58-no-send-compiler-list` (`roc install` and `upgrade roc` with a non-empty queue: no queue call); `audit` is added to the list of `sh51` (one case `sh51-send-audit`, 503) |
| Q3 | Q450 says the flow reads `packages/<hash>/main.roc` with `read_files!` for a fact whose hash has no `artifacts` row. In `update` with a registry the R-DI7 read of the same headers can be done before the probe (see the held-back fixture `sh52-update-share-header` in `mkcases.py`: one `read_files` of both files before the probes). Does the queue step read them again, or use the text of that read? | Q450 in a command | Answered (Q535): reuse the kept text. Test change: the held-back fixture `sh52-update-share-header` is valid: one `read_files` of the headers, the queue step adds none (`calls.log` has no second `read_files`) |
| Q4 | `machine_error` of a fact (filter 6, R-SM7): the list is slice 218. Until then, is it `false` for each `fail`? A command that passes `false` queues a `fail` that a machine fault caused. | A `fail` or `crash` fact in a command | Answered (Q536): `machine_error` is false for a unit check. No test change: the wiring passes `false` for each fact in this slice; the cases have `pass` unit facts |
| Q5 | R-AP30 names `update`, `outdated` and `add`. Do `install`, `upgrade` and `verify` print the index notes too (they send the same closure query and have the same answer)? I read the list as complete. | Index notes in these commands | Answered (Q537): `install` and `verify` print none; `upgrade` with names prints them. Test change: new L2 `registry/ap30-upgrade-notes` (1 run, `upgrade json`: the note after the other notes); `ap30-*` cases for `install` and `verify` have no note (add a run of `install` and `verify` with a stale answer: no `note: index:` line, no `index_notes`) |

## Doubts (a reading that the code agent may dispute)

| # | Doubt |
| --- | --- |
| D1 | The calls of the enqueue (R5) and the place of the note (R1, R2) are readings, not design text. `sh49`, `sh50` and the `ap30-*` cases fix them. |
| D2 | `queued_at` comes from a new `clock` call (R-TF7: "the time that the row went into the queue"). A command that passes its start time would have no `clock` line in `sh49`. |
| D3 | `recorded` (filter 3) is one `db_query` `Pinned` with the key of (compiler, the machine target) before the queue write. The case gives that row. |
| D4 | `outdated` and `why` are read-only, but R-SH4 names no exception, so they send (`sh51-send-outdated`, `-why`). |
| D5 | A `--dry-run` run sends (R8). `verify` writes nothing of the project, and the send writes `compat.db` and `share.json`: this is the same as for the facts of a probe. |
| D6 | Only `pass` unit facts of a package and a platform are in the cases. The filters have their L0 tests (215); `sh49` shows only that the wiring gives the right input (answers, the compiler, the order). |
| D7 | The 503 cases fix `timeout=5` (the first request: the whole budget) and one `clock` before it, as `sh14`. |

## Design answers (2026-11-03)

| Item | Answer | Test change |
| --- | --- | --- |
| G-C170, Q538 | `--dry-run` queues and sends (R8 confirmed) | none: `sh49` and `ap30-*` use `--dry-run` already |
| R5 to R9, Q539 | Confirmed: the order `db_query` Pinned (one query for the distinct (tag, target) pairs of the round: `pinned=<n>`), `clock`, `db_write` Queue; no candidate means no call; the rows in probe-result order; the send after the output; `outdated` and `why` send | If a round has 2 compilers, `pinned=2`: add to `sh49` only if a case has 2; none now |
| R1, R2, R3, TW24, Q540 | The text, the places, `--quiet`, `data.index_notes` last in `update` and after `members` in `outdated` are accepted. No conflict with Q407: `data.notes` has the texts and `data.index_notes` the objects. The line has `<owner>/<repo>`, not a group | none: `ap30-update-notes` and `ap30-outdated-notes` already fix them |
| Q4 | A unit check has no machine error (Q536) | none |

Part 2 of the wiring waits for the test agent to add the new cases above (`ap30-update-error-notes`, `ap30-upgrade-notes`, `sh57`, `sh58`, `sh51-send-audit`).


## Round 2 (test agent, Design Q533 to Q540)

| Case | Checks |
| --- | --- |
| `registry/ap30-update-error-notes` (2 runs, exit 10, human and `--json`) | R-AP30, Q533: the note on stderr after the error text, none in the error object |
| `registry/ap30-upgrade-notes` (`upgrade json`) | R-AP30, Q537: the notes after the other notes |
| `sh51-send-install`, `sh51-send-verify` now have stale `checked` items | Q537: no `note: index:` line (their answers were fresh before) |
| `share/sh52-update-share-header` (added, Q535) | Q450: the same 2 rows as `sh49`; the R-DI7 read of the headers is the only read, the queue step adds none |
| `share/sh57-send-after-error` (exit 10, 503) | Q533: the send runs after an error exit |
| `share/sh57-no-send-exit15` (closure 429, exit 15) | Q533: no queue call (guard, passes before the code) |
| `share/sh58-no-send-compiler-list` (`upgrade roc`) | CHANGED by Q541: `upgrade roc` sends the closure query and probes, so it sends the queue. Test change: the case becomes `share/sh58-send-upgrade-roc` (the same world, a queued row, one POST, the row leaves, exit 0; it is red before the code), and a new guard `share/sh58-no-send-compiler-list` uses a command that reads only the compiler list (`roc update` with a non-empty queue: no queue call, no request but the list). Also an `ap30-upgrade-notes` run of a bare `upgrade` with a stale answer: the note |

Not added: `sh51-send-audit` (`tln audit` is P3 and has no flow in `cli/`; no world exists), and `roc install` (no registry world for it; Q534 note). Q536, Q538, Q539: no change. Red: `tests/commands/run.sh` 387 pass, 35 fail: 14 `publish/` (slice 222) and 14 of mine (`ap30-*` 5, `sh49`, `sh50`, `sh51-*` 5, `sh52`, `sh57-send-after-error`); the 3 guards pass (`sh56`, `sh57-no-send-exit15`, `sh58`). All exits read: runs exit 0 except `ap30-update-error-notes` (10, 10), `sh57-send-after-error` (10) and `sh57-no-send-exit15` (15), each the rule of its run.


## Code

| File | Change |
| --- | --- |
| `cli/lib/ShareHook.roc` (new, exposed in `main.roc`) | `ran_of` (the run that sent a closure query: `registry` `Read` and an `Answer` index), `attach`, `notes`, `with_index_notes`, `failed!`, `send!` (not after exit 15 or 19), `enqueue!` (R-SH2, `Pinned` query, `clock`, `ShareQueue.admit` for each fact, `ShareQueue.enqueue!`). No logic is copied: it calls `IndexNotes`, `ShareQueue`, `QueueSend` |
| `cli/lib/Fail.roc` | New field `ran : Try(Fail.Ran, [None]) ?? Err(None)` (a default, so `Fail.{...}` of `OutTest` stays valid) and the type `Fail.Ran`: the run that a failure carries to the end of the command (Q533) |
| `cli/lib/ConfigToml.roc`, `Base.roc`, `ResolveLoad.roc` | `Config.share` (key `share` of `config.toml`; a wrong value is `Unset` here) |
| `cli/lib/ResolveBase.roc`, `InstallFlow.roc` | `Query.share`, set in `with_setting`. `Done.ran`. `resolve!`, `attempts!`, `finish!` give `{ outcome, ran }`. `finish!` prints the index notes after `plan.notes` (update and upgrade, not install) and adds the texts to `outcome.notes`. A failure after the first query gets `ran` (`noted` when the notes were printed). Q541: the flag is "this run has an answer", not a list of command names |
| `cli/lib/ShareRound.roc` (new, exposed) | The queue step core (R-SH2, `platform`, `Pinned` query, `clock`, `ShareQueue.admit`, `ShareQueue.enqueue!`), with no `ResolveBase`, so the search and the ladder share it (Q543). `ShareHook.enqueue!` calls it |
| `cli/lib/UnitFlow.roc`, `Ladder.roc`, `InstallWrite.roc`, `VerifyFlow.roc` | Q543: `UnitFlow.Ctx.share`, `Ladder.Loop.share`, the `share` of `verify!`: `UnitFlow.first!` queues the unit facts of each ladder round right after `Facts.save!` (the baseline and the whole-app checks are not unit facts: filter 2) |
| `Fail.Ran.headers`, `ShareHook.headers_of`, `InstallFlow.settle!` (`headers`) | Q450, Q535: the ladder gets the same header facts as the search through `Ladder.Loop.share` (`UnitFlow.first!` passes `ran.headers`), so it does not skip a fact with no `artifacts` row |
| `cli/lib/PickLoop.roc` | `round!` and `probe_round!` get the facts that the command read; `ShareHook.enqueue!` follows `Facts.save!` of each round |
| `cli/lib/Install.roc`, `Update.roc`, `Upgrade.roc` | `ShareHook.failed!` for a failure, `ShareHook.send!` after the output; `Update.print!` adds `data.index_notes` last |
| `cli/lib/Verify.roc`, `VerifyFlow.roc`, `Resolve.roc` | `verify!` gives `{ outcome, ran }`; no note; the send after the output and after a failure |
| `cli/lib/OutdatedFlow.roc` | `flow!` gives `{ members, ran }`; the notes after the table (human run only, not in `--quiet`), `data.index_notes` after `members`; the send |
| `cli/lib/Why.roc` | the send after the output and after a failure; no note |

Copies: `research/slice-206e4-revert/code-final/` and `code-final.sha256`.

Results: `scripts/test.sh check fmt l0 l3` pass (TW20 time warning for l0). `tests/commands/run.sh`: 411 pass, 11 fail. The 11 are the disputes below (each checked: the case with the fixture fix, in a copy outside `tests/`, passes except for D1).
`upgrade roc` and a bare `upgrade` send and print the notes (Q541, G-C171): the flag is `ran`. `roc update` has no flow with `ran`: no send.

## Disputes (from the code agent)

The code is the same in all of them. I did not edit the expected files or the fixtures (TW18).

| # | Case | Line or file | Rule | Problem and fix that I checked |
| --- | --- | --- | --- | --- |
| D1 | `share/sh49-update-share`, `sh52-update-share-header` | `expect/calls.log` before `db_query ... pinned=1` | R-SH3 filter 3, R-CV6 | The key of `Pinned` has the machine target (`linux_x86_64`), and no `Fx` call gives it but `platform!`, which is logged. The code calls `platform!` once before the query: the log has one `platform` line more (in run 1, after `db_write ... facts=2`). The later `platform` line of the build stays. Fix: add the line `platform` before `db_query ... pinned=1` in both files. With D2 fixed and this line added, both cases are green (checked) |
| D2 | `sh49`, `sh50-update-share-off`, `sh52` | `fx/jobs` | R-SH5 | No rule answers `chmod 0600` of `share.json` (only `chmod 0755`): the fake gives a failure, so the log has `delete <tmp>` and not `rename`, and `share.json` is not changed. Fix: a line `chmod 0600<TAB>0<TAB>-<TAB>-<TAB>-` (as `sh11-send-one`). With it `sh50` is green (checked) |
| D3 | `registry/ap30-update-error-notes` | `fx/http/.../closure.POST.3` | R-AP30, Q533 | Run 2 gets the answers 3 and 4. In 3 the item `acme/yaml` has `stale: false`, so the note of the expected stderr line 4 cannot exist. Fix: `checked` of 3 as in `closure.POST` (`checked_at` 1792064880000, `stale` true). Checked: green |
| D4 | `registry/ap30-held-move-notes` | `fx/http/.../closure.POST.3` and `.4` | R-AP30, Q408 | The same: run 2 gets the answers 3 and 4, and all their `checked` items are fresh, but the expected `--json` of run 2 and the human stderr have 3 notes. Fix: `checked` of 3 as of `closure.POST`, of 4 as of `closure.POST.2`. Checked: green |
| D5 | `sh51-send-install`, `-upgrade`, `-verify`, `-why`, `sh57-send-after-error` | `given/home/.cache/roc/talon/` | R-SH4, R-TF1 | The fake `QueueRows` gives no row when `compat.tsv` does not exist (`FakeDb.exists!`), and these cases have only `share_queue.tsv`: the send reads the queue and stops. Fix: a `compat.tsv` with the line `format<TAB>1` (as `sh11-send-one`). Checked: all 5 green (`sh51-send-outdated` is green: its run creates `compat.tsv`) |
| D6 | `share/sh58-send-upgrade-roc` | `fx/env`, `expect/stdout` | R-SH2 condition 5, R-AP30 | `fx/env` has `CI=true` (taken from `cv1-upgrade-free`), so R-SH2 is false and `upgrade roc` must not send: the expected POST cannot happen. Also `TALON_NOW=2026-10-20`, so the age of `acme/json` is `8d`, not `3d`. Fix: no `CI`, `8d` in the stdout. Then the run also queues its 3 probed facts (`platform`, `db_query pinned=1`, `clock`, `db_write queue=3`, `tty`), so the calls and the POST body of this case need the new lines (rows after `HA`: the probed unit facts), as D1 |

## Review notes and doubts

| # | Note |
| --- | --- |
| N1 | (Q543, done) the ladder rounds are queued; no case (`sh60`) existed when I wrote this. Old text: the facts of `UnitFlow.first!` (the ladder with a registry answer, `--no-probe` aside) are not queued: the `Ladder` input has no sharing facts, and no test shows the call. The oracle loop (`PickLoop.probe_round!`) is wired. If the design wants the ladder rounds too, `Ladder.Ctx` needs the `Fail.Ran` of the run: a question for the next slice |
| N2 | A failure before the first closure answer exists (a bad file, a guard, the query itself) carries no `ran`: no note, no send. A failure after `finish!` printed the notes has `noted` true: no second print on stderr |
| N3 | `Fail` has a new defaulted field. `tests/unit/OutTest.roc` (`Fail.{...}` with 4 fields) still compiles (L0 is green). |
| N4 | Signals (Q533): no command of the closed list runs a child, so no exit code is a signal. Only 15 and 19 stop the send |
| N5 | A `--json` run of `outdated` has the notes in `data.index_notes` only (no stderr line): `ap30-outdated-notes` fixes it. `update` prints them on stderr in a `--json` run (as every note) |

## Design answer for G-C173 (2026-11-03)

| Item | Answer | Test change |
| --- | --- | --- |
| N1: the unit facts of the ladder (Q543) | Queued, after the facts write of each ladder round that probed (the same calls as Q539: `db_query` Pinned, `clock`, `db_write` Queue). The baseline and the whole-app check are not queued (filter 2). Filters 5 and 6 decide the rest | New L2 `share/sh59-ladder-share` (2 runs): run 1 `verify` with `share = true`, no `CI`, a ladder that probes the unit checks of parser and platform: the 2 unit facts are queued after the ladder facts write, the baseline is not (`queue=2`), the send has 2 rows. Run 2 `update` with the ladder after the search (the keys that the search did not look up, as `ef1-rank2-ladder`): a unit fact of a pair with a rank 2 `author` row is queued, one with a `bot` row is not (filter 5). `sh49` stays |

## Round 4 (test agent)

D1 to D6 fixed in the 11 cases (`platform` line before `pinned=1`, `chmod 0600` job, `closure.POST.3`/`.4` `checked`, `compat.tsv` with `format 1`, `sh58` without `CI`: age `8d`, 3 probed facts queued). New: `share/sh60-ladder-share` (named `sh60`, not `sh59`, which is free but was dropped; Q543): `verify` with the world of `ef1-rank2-verify`, sharing on. The ladder round 1 probes 3 (baseline, parser, platform), `db_write facts=2`, then `platform`, `pinned=1`, `clock`, `queue=2`; the build row is not queued; the send has HA and the 2 unit rows, 201, `unqueue=3`. Exit 0. The case was made with `UPDATE=1` because the code already queues the ladder facts; every call line, the POST body, stdout, stderr (none), tree.diff and the exit were read against Q543 and R-SH3 filters 2, 5, 6.

Round 4b: `share/sh61-ladder-share-header` (Q450, Q535, Q543): `sh60` with no artifacts row for parser: one R-DI7 header read, no second read, the parser fact is queued (queue=2, 3-row POST). Expect files by hand (calls.log = sh60 + the 3 baseline read lines; tree.diff = sh60).

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206e4-revert/code-final.sha256` | OK, 21 files. Older code-final lists (206e3b, 221, 222) differ only in files that later slices changed (expected) |
| `grep "todo: slice 206e4" cli/` | nothing |
| Expected exits (read) | all 0, except `ap30-update-error-notes` 10, 10 and `sh57-send-after-error` 10 (no tuple; the notes and the send still run, Q533) and `sh57-no-send-exit15` 15 (no send, Q533) |
| `sh60-ladder-share` (made with UPDATE=1) | read by the manager: the ladder unit round writes 2 facts and queues 2; the whole-tuple check and the app build are not queued (filter 2, Q543) |
| `sh61-ladder-share-header` | by hand; the kind of a hash with no `artifacts` row comes from the kept header text, no second read (Q450, Q535) |
| Disputes D1 to D6 | all accepted: faults in hand-patched fixtures (platform line, chmod rule, stale answers, `compat.tsv`, `CI` in `sh58`) |
| `scripts/test.sh check fmt l0 l2 l3` | all pass (with slice 222 in the tree) |
| Design answers | Q533 to Q541, Q543 |
| Not tested | `tln audit` (P3, no flow); the `roc update` no-send guard (plan row 206f); a failure before the first answer (no `ran`, so no note and no send) |

