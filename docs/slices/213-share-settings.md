# 213 Sharing settings

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 213 of `PLAN-P2-CLI.md`. The local part of sharing: `share.json`, `tln share on`, `tln share off`, and `tln share` with no word. No network, no first-run prompt (214), no login (219), no queue rows (215), no send (216).

## Rules

R-CM23, R-SH1, R-SH2 (the 5 conditions as a pure function, used here for the status), R-SH4 (`off` empties the queue), R-SH5, R-SH6 (the form and the rule "totals stay"), R-SH8 (local part), R-SH10 (`on` with `direct`), R-SH13, R-SE15, R-LY3 (`share.json.lock`), R-LY7, R-TF1, R-TF2, R-TF6, R-TF7 (the table `share_queue`), R-EV26, R-CC6.

Design: CLI 1 (R-SH1 to R-SH13), CLI 6.1 (R-LY3, R-LY7, R-TF1 to R-TF7), CLI 7.4 (R-CC6), Design Q201 (G-C2, answered).

## Public signatures (stubs, `crash "todo: slice 213"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `ShareJson.format` | `U64` (1) | R-TF1 |
| `ShareJson.Doc` | the members of R-SH13, and `extra` for the members that Talon does not know | R-SH13, R-TF2 |
| `ShareJson.id_of` | `{ high : U64, low : U64 } -> Str`: 2 numbers of `Fx.random!` give 32 lower-case hex digits | R-SH5 |
| `ShareJson.fresh` | `Str -> Doc`: totals 0, other members `Unset` | R-SH13 |
| `ShareJson.text` | `Doc -> Str`: one line and a line end (`TalonFile.render`), the members in the order of the R-SH13 example, then `extra` | R-SH13, R-TF1 |
| `ShareJson.read` | `{ path, text } -> Try(Doc, Fail)`: `TalonFile.open` (newer format: exit 19, the text of R-TF3), a member with the wrong form gives `<path>: the content does not parse` (R-TF6) | R-TF1 to R-TF3, R-TF6 |
| `Share.Reason`, `Share.state` | `{ share, registry : Net.Registry, offline, env } -> [On, Off(Reason)]`: the first false condition of R-SH2 in the order of the table | R-SH2, R-EV26 |
| `Share.setting` | `{ path, text } -> Try({ share, registry }, Fail)`: the keys `share` and `registry` of `config.toml` | R-SH1, R-TF4 |
| `Share.edit` | `{ path, text, value } -> Try({ previous, edit : [Same, Set(Str)] }, Fail)`: the span edit of the key `share` | R-SH1, R-CC6 |
| `Share.chmod_command` | `{ windows : Bool, file : Str } -> Try(List(Str), [NotNeeded])`: `chmod 0600 <file>`, or `NotNeeded` on Windows (as `Toolchain.chmod_command`, R-HF2) | R-SH5, R-SE15 |
| `Share.clear_err` | `{ err : Db.Err, path : Str } -> [Stop(Fail), Warn(Str)]` (D7) | R-SH4, R-CC8 |
| `Share.reason_text`, `Share.reason_word` | the text and the `--json` word of a condition | R-SH8 |
| `Share.status_lines`, `Share.status_data` | the output of `tln share` | R-SH8, R-OUT2 |
| `Share.on_lines`, `Share.on_data`, `Share.off_lines`, `Share.off_data` | the output of `on` and `off` | R-SH10, R-OUT2 |
| `ShareFlow.status!`, `on!`, `off!` | `Fx, Args => I32`. `Run.tln!` calls them for `share`, `share on`, `share off`. The steps and the calls are in the doc of `ShareFlow`. | R-CM23 |
| `Db.Query` `QueueCount`, `Db.Answer` `QueueCount(U64)`, `Db.Write` `ClearQueue` | New variants (see "Decisions"). The contract is in the doc of `Db`. | R-SH4, R-SH8, R-TF7 |

Edits to existing files (copies in `research/slice-213-revert/before/`): `cli/lib/main.roc` (3 exposes), `cli/lib/Run.roc` (the 3 dispatch lines and the import), `cli/lib/Db.roc` (3 variants and their doc), `cli/lib/Facts.roc` and `cli/fxprobe.roc` (the wrong-answer arms became `Ok(_)`, so the new answer compiles), `cli/RealDb.roc` (the arms of the new variants: `crash "todo: slice 213"` in `select!` and `insert!`), `tests/commands/FakeDb.roc` (the fake of the 2 new variants), `tests/unit/l0-8.roc` (imports `ShareTest`).

## Decisions that the design does not fix (options and the choice)

| # | Point | Choice | Rejected |
| --- | --- | --- | --- |
| D1 | `share off` must empty `share_queue`, and the table is made by slice 215 | The table is in this slice as far as R-TF7 gives it: a `Db.Write` `ClearQueue` runs `CREATE TABLE IF NOT EXISTS share_queue (...)` and `DELETE FROM share_queue` in one transaction (R-TF7: Talon makes the table when it opens the file to write). A `compat.db` that does not exist is not made (nothing is queued). `QueueCount` gives 0 for a file with no table, and makes nothing. `user_version` stays 1. | A new `Fx` call (the lead said no). A `Facts` write with no rows (it cannot delete). Wait for 215 (then `off` cannot meet R-SH4). |
| D2 | The fake `Fx` keeps the rows in `share_queue.tsv` next to `compat.tsv`, one row for each line. | The text form of a row is slice 215. The L2 cases give 3 to 4 lines in the R-TF7 column order. Only the count and the empty file are checked. | A change of `Db.file_text` and `Db.parse_file` (they have a record type used in many places). |
| D3 | The state in `tln share` | `sharing: on` when the 5 conditions of R-SH2 are true. Else `sharing: off (<first false condition in the order of the table>)`. So `share = true` with `DO_NOT_TRACK=1` is off. | The setting alone (R-SH8 says "the condition of R-SH2 that turns it off", so the condition must show). All false conditions in one line (R-SH8 says "the condition"). |
| D4 | The order of `on` | `config.toml` first (under its lock), then `share.json` (under its lock). The 2 locks are never held together. | One nested lock. |
| D5 | `off` when `share` is not set | It writes `share = false` (R-SH1: `off` writes the setting, so the first-run prompt R-SH11 does not ask again). | No write when not set. |
| D6 | `off` and `share.json` | `off` does not read and does not write `share.json`: the id and the totals stay (R-SH5, R-SH6). | |
| D7 | A db error in `on`, `off`, `status` | `off`: `Share.clear_err` (TW24 proposal): busy is the warning `compat.db is busy: the share queue is not emptied`, another failure is `cannot use <path> (<text>): the share queue is not emptied`, a too new file is `Db.on_err` for a write (exit 19). `Db.on_err` says "the facts of this command", which is wrong for the queue. `status` uses `Db.on_err` for a read (not tested). | |
| D8 | The registry for `on` (R-SH10) | `Net.registry` with `--registry`, `TALON_REGISTRY` and the key `registry` of `config.toml`. The check of its form (R-RG7, exit 2 or 19) is slice 224. | |

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ShareTest.roc` (driver `l0-8.roc`), expect 1: `id_of` (2 numbers, leading zeros), `format`, the text of a new file (the exact example of R-SH13) | R-SH5, R-SH13, R-TF1, R-SH6 |
| L0 | expect 2: `ShareJson.read` of a full file (totals, times, JWT, account, an unknown member) and the same bytes back with `text`; a new file; format 2; 13 bad texts (empty, not JSON, an array, no `format`, wrong `id`, upper-case `id`, negative total, text total, null total, wrong time, wrong `token`, wrong `account`) | R-SH13, R-SH6, R-TF1, R-TF2, R-TF3, R-TF6 |
| L0 | expect 3: `state`, 21 rows: each of the 5 conditions, `DO_NOT_TRACK` (`1`, `true`, empty, `0`), `CI` (`true`, `TRUE`, `1`, `false`, `0`, empty), the variables that change nothing, the order of the rows | R-SH2, R-EV26, R-NM1 |
| L0 | expect 4: `setting` (7 rows: unset, true, false with a registry, a registry only, a wrong type with the line, bad TOML) and the texts and words of the 5 reasons | R-SH1, R-TF4, R-SH8 |
| L0 | expect 5: `edit` (empty text, a comment kept, a value replaced with its comment kept, the same value, a wrong type, bad TOML, a new key before the first table) | R-SH1, R-CC6 |
| L0 | expect 6: `status_lines` and `status_data` (on with the 2 times, off with no time, 8 characters of the id) | R-SH8, R-SH5, R-SH6, R-SE15, R-OUT2 |
| L0 | expect 8: `chmod_command` (Unix and Windows) and `clear_err` (busy, failed, too new) | R-SH5, R-SE15, R-SH4 |
| L0 | expect 7: `on_lines` with and without a send, `off_lines`, the 3 `data` objects | R-SH10, R-SH1, R-SH4, R-OUT2 |
| L2 | `tests/commands/cases/share/sh1-flow`: `on`, `on`, `off`, `on`, `off` with a registry URL. The first `on` makes `share.json` (2 `random` calls, the id) and edits `config.toml` (a comment stays, the key is added); the second `on` writes nothing; `off` writes false and empties the queue (3 rows); the next `on` does not make a new id. The locks of `config.toml` and `share.json`, and the call `chmod 0600 <share.json>` after the write (`spawn_all!`, limit 1). The final tree. | R-CM23, R-SH1, R-SH4, R-SH5, R-SH6, R-SH13, R-LY3, R-LY7, R-CC6, R-TF1, R-SE15 |
| L2 | `tests/commands/cases/share/sh2-direct`: `on` with the registry `direct` (no `config.toml` before, so the file is made), the note that nothing is sent, `--json` for `on` and `off`, and `off` with no `compat.db` (no file is made) | R-SH10, R-SH1, R-CM23, R-LY3, R-SH4, R-TF7, R-OUT2 |
| L2 | `tests/commands/cases/share/sh3-status`: `tln share` with no word: on, `--json`, `--offline`, `DO_NOT_TRACK` `1` and `0`, `CI=true` with `--json`, the registry `direct` with `DO_NOT_TRACK=1` (the first condition shows), no `config.toml` (a second home) and an empty queue. No lock, no write, no random. | R-CM23, R-SH8, R-SH2, R-SH5, R-SH6, R-SE15, R-EV26, R-OUT2 |

## Output (proposed, R-OUT2, TW24)

| Command | Text (stdout, each line ends with a line end) | `--json` `data` |
| --- | --- | --- |
| `tln share` | `sharing: on`, or `sharing: off (<reason>)`. Then `id: <8 characters>`, `sent: <n>`, `counted: <n>`, `first: <n>`, `first sent: <time>` and `last sent: <time>` only when set, `queued: <n>`. The reasons: `share is not true in config.toml`, `the registry is direct`, `--offline is set`, `DO_NOT_TRACK is set`, `CI is set`. | `{"on":<bool>,"reason":<word or null>,"id":<8 characters>,"sent":<n>,"counted":<n>,"first":<n>,"first_sent_at":<text or null>,"last_sent_at":<text or null>,"queued":<n>}`. The words: `share`, `registry`, `offline`, `do-not-track`, `ci`. |
| `tln share on` | `sharing: on`. With the registry `direct` a second line: `Talon shares nothing while the registry is direct.` | `{"share":true,"sends":<bool>}` |
| `tln share off` | `sharing: off` | `{"share":false}` |

`--quiet` for these commands is not tested (R-FL4 is a general rule). The envelope `command` is the words as typed (`share`, `share on`, `share off`).

## Out of scope

| Item | Reason |
| --- | --- |
| `tln share` when `share.json` is missing | Question Q2, now design gap G-C32. The L2 cases always give the file. The code agent leaves that branch as a clear internal failure. |
| R-SH8 account part (GitHub login, account totals, the 401 answer, a JWT past `token_expires_at`) | Slices 217 to 219 (network). The local part ignores `token` and `account`. |
| R-SH7, R-SH9, R-SH10 for `login`, `logout`, `forget` (exit 2 with `direct`) | Slices 219 and 220. Until then the 3 words print `command 'share login' is not built yet`. |
| The totals and the times change after a send (R-SH6 writes) | Slice 216. `ShareJson.Doc` has `extra`, so that write keeps unknown members. |
| The queue rows, R-SH2 for the queue, R-SH3, the cap of 10,000, R-EV26 for `probe --share` | Slice 215. This slice uses `Share.state` for the status only. |
| R-CC7: the second read of `config.toml` and the check of the bytes | The fake `Fx` has no way to change a file between 2 reads. The reference without the check passes all cases (equal mutant). |
| R-RG6, R-RG7 checks of the `registry` value | Slice 224. |
| R-CC8 db warnings of `QueueCount` and `ClearQueue`, the operands of `share` (`tln share on x`), R-FL4 `--quiet` | Not named in the plan row. No test. |
| The real `Fx` SQL of `QueueCount` and `ClearQueue`, and an L3 case with `fxprobe` | `cli/RealDb.roc` has `crash "todo: slice 213"` arms. `fxprobe` has no line for the 2 variants, and `tests/tools/dumpdb.py` does not dump the table. The code agent writes the SQL by the doc of `Db`. The contract case of the real `Fx` for the 2 variants moves to slice 215 (plan row 215), which adds rows. |
| R-SH11 first-run prompt, R-NI16, R-NM12 | Slice 214. |

## Questions (stop until answered)

| # | Question | Options | State |
| --- | --- | --- | --- |
| Q1 | The mode `0600` of `share.json` (R-SH5, R-SE15). `Fx.write_atomic!` has no mode, and no other call sets one. Slice 200 changes `Fx` later. | (a) a `mode` member in the entries of `write_atomic!` (Unix only, ignored on Windows). (b) A new call `write_private!`. (c) `chmod` through `exec!` (a process for one file, and a window with the wrong mode). | Answered (manager, 2026-11-02): option (c), as R-HF2. After the `share.json` write, `spawn_all!` (limit 1) of `chmod 0600 <file>` (`Share.chmod_command`), no call on a Windows host (`Fx.windows!`). A failed chmod is kind `Environment` (as R-HF2). The `calls.log` of `sh1-flow` and `sh2-direct` show it. |
| Q2 | `tln share` when `share.json` does not exist. R-SH13 says that a missing file "is made when the first rule needs the id", and R-SH8 prints the id. But R-SH5 says Talon makes the id "the first time that sharing turns on", and `tln share` is a read-only status. | (a) `tln share` makes the file (a lock and a write in a status command). (b) It prints `id: none` and makes nothing. (c) It makes the file only when `share` is true. | Open: design gap G-C32 (design agent). No test. The code agent leaves the branch as a clear internal failure. The flow stub has no branch for it: `status_flow!` of the reference stops with an internal failure here. |

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | R-SH2 row 5 is the row `CI` of R-NM1 only: `CI` is `true` or `1` in any case. `--json`, `DEBIAN_FRONTEND`, `NONINTERACTIVE` and `TALON_INTERACTIVE` change nothing. |
| 2 | R-EV26: `DO_NOT_TRACK` set, not empty and not `0` (so `true` also turns sharing off). |
| 3 | R-SH1: `share on` with the value already `true` writes no file. R-TF4 for `share` with a wrong type is exit 19 with `<path>:<line>: share: must be true or false`. |
| 4 | R-SH5: `share.json` is made at the first `on`, and it is read, never written, by a later `on`, and not touched by `off`. |

## Disputes (from the code agent)

None yet.

## Verify results

Red result (2026-11-02, after the manager review): `roc test tests/unit/l0-8.roc`: 8 `expect`s of `ShareTest.roc` fail with `todo: slice 213` (106 others pass; 8 expects, one added for `chmod_command` and `clear_err`, log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red-l0.log`). `tests/commands/run.sh share/`: 3 cases fail with `[ROC CRASHED] todo: slice 213` (log `.../scratchpad/red-l2.log`). `roc check` of `cli/lib/main.roc`, `cli/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc`, `tests/commands/main.roc`: no errors. `roc fmt --check` of each changed file: exit 0. The full L2 run has 15 other fails in `ptool/*` that are the work of another agent (tool flows), and no other case changed.

Revert check (the private reference was deleted after the review; `before/` holds the old files and `before/NEW.txt` the new ones). With the reference installed: 7 `expect`s and 3 L2 cases pass. Mutations of the reference:

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `state`: row 4 (`DO_NOT_TRACK`) before row 3 (`--offline`) | L0 expect 3 |
| M3 | `id_of`: `low` before `high` | L0 expect 1 |
| M7 | `edit`: never `Same` (the same value writes again) | L0 expect 5 |
| M9 | the status prints the whole id | L0 expect 6, L2 `sh3-status` |
| M4 | `ensure_id!`: writes a new id also when the file is there | L2 `sh1-flow`, `sh2-direct` |
| M5 | `off` does not call `ClearQueue` | L2 `sh1-flow`, `sh2-direct` |
| M8 | no second read of `config.toml` (R-CC7) | not caught: equal mutant under the fake (see "Out of scope") |

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo: slice 213"` | None |
| Tests (code agent) | check, fmt, l0 (7.0 s), l3 pass. L2 237 pass. The 15 L2 failures are the `ptool/*` cases of slices 092 and 093, which are in work. |
| Revert check | Test step: M1, M3, M4, M5, M7 and M9 were caught. M8 is an equal mutant. The code step ran none (TW12). |
| Open | G-C32 (`tln share` with no `share.json`): Internal failure until the design answer. Real SQL of QueueCount and ClearQueue: contract case in slice 215. |

## Correction (manager, 2026-11-02, after the close)

The close above missed one defect. The L2 cases `share/sh1-flow` and `share/sh2-direct` had no `fx/jobs` rule for `chmod`, so the fake host gave `Exited(99)`. Their expected files then recorded exit 18 for the first `tln share on`, and the cases passed while they recorded a failure. Slice 213b adds the `chmod` rule and changes the expected files to exit 0 with `share.json` made. Manager check from now on: read the expected `exit` and `stdout` of each new or changed L2 case for a failure that the slice does not intend.
