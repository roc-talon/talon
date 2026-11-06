# 216 Queue send

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 216 of `PLAN-P2-CLI.md`. The send of the share queue (R-SH4) at the end of a command that sent a registry request: the plan of the rows, the request, what each answer does, the totals of `share.json` (R-SH6). Not in this slice: the call in real commands, `tln probe --share` (217).

## Rules

R-SH2 (again before the send), R-SH4, R-SH5 (the id as `Talon-Contributor`), R-SH6, R-AP10, R-AP34, R-CT1, R-CT2, R-CT4, R-CT14, R-TF7 (the version column). Named also: R-AP72, R-AP82, R-AP46, R-CC8.
Design: CLI 1 (R-SH2 to R-SH6); Registry 4 (R-AP10, R-AP34), 6.1 (R-CT1 to R-CT4, R-CT14). Closed slices read: 215, 213, 213b, 200.

## Records

`packages/records` `Compat` has `HintRow`, `HintPost`, `HintSkip`, `HintAnswer` with `encode_hint_post` and `decode_hint_answer` (slice 104f, R-AP72). Nothing is missing. The tests use no copy of a wire type. The L0 tests cannot import `records` (the driver has only `lib`), so they compare with the exact text that `packages/records/tests/CompatHintTest.roc` fixes.

## Public signatures (stubs, `crash "todo: slice 216"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `QueueSend.max_requests`, `batch_rows`, `budget_s` | `U64` constants 2, 500, 5 (not stubs) | R-SH4 |
| `QueueSend.plan` | `{ rows : List(Db.QueueItem), talon_version } -> { stale : List(U64), batches : List(List(Db.QueueItem)) }` | R-SH4, R-TF7 |
| `QueueSend.remaining` | `{ started, now : U64 } -> [Send(U64), Stop]` (proposal, Q4) | R-SH4 |
| `QueueSend.request` | `{ origin, talon_version, contributor, rows : List(Db.Queued), timeout_s } -> { method, url, headers, body, timeout_s }` | R-AP10, R-CT1, R-CT2 |
| `QueueSend.settle` | `{ count : U64, reply : QueueSend.Reply } -> [Leave(Add), Stay]` | R-SH4, R-SH6, R-CT4, R-CT14 |
| `QueueSend.totals` | `{ doc : ShareJson.Doc, add, now : Str } -> ShareJson.Doc` | R-SH6 |
| `QueueSend.send!` | `Fx, { roots, sharing : ShareQueue.Sharing, talon_version } => {}` | R-SH4 |
| `Db.QueueItem` | `{ seq, row : Queued }` | R-TF7 |
| `Db.Query` `QueueRows`, `Db.Answer` `QueueRows(List(QueueItem))` | all rows, smallest `seq` first, no file made | R-SH4 |
| `Db.Write` `Unqueue(List(U64))` | removes the rows with these `seq` | R-SH4 |

Edits to existing files (copies in `research/slice-216-revert/before/`): `cli/lib/Db.roc` (3 variants, 1 type), `cli/RealDb.roc` (`crash "todo: slice 216"` arms for `QueueRows` and `Unqueue`, empty-case arms), `cli/lib/main.roc` (1 expose), `tests/commands/FakeDb.roc` (the fake of the 2 variants, done, not stubs), `tests/commands/L2Db.roc` (the word `queue-send`), `tests/unit/l0-8.roc` (1 import). New: `cli/lib/QueueSend.roc`, `tests/unit/QueuesendTest.roc`, `tests/tools/mk-queue-send.sh` (makes the 6 L2 cases). No file of the 206b agent was edited.

## The flow (tested reading, for the review)

Steps in the doc of `QueueSend.roc`. Order of calls in `calls.log`: `env_all` (the L2 word), `db_query queue_rows`, [`db_write unqueue=<stale>`], `read_files share.json`, per batch `clock`, `http_send`, [`db_write unqueue=<n>`], then `lock`, `read_files`, `random`, `write_atomic <temp>`, `spawn_all chmod 0600`, `rename`, `unlock` (the write of 213b). The time of the totals is the `clock` value of the last request (no extra call).

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/QueuesendTest.roc` (driver `l0-8`) expect 1: the constants | R-SH4 |
| L0 | expect 2 to 5: `plan` (no row, 3 rows; 500, 501, 1000, 1001, 1200 rows; unsorted input; other versions are `stale`, do not count for the 500, `0.9.0-rc1` is another version) | R-SH4, R-TF7 |
| L0 | expect 6: `remaining` | R-SH4 |
| L0 | expect 7: `request` (POST, url, header order, no `Authorization`, body with `rows` and `talon_version`, the result words) | R-AP10, R-CT1, R-CT2 |
| L0 | expect 8: `settle` 200 and 201 (rows leave, skipped rows leave, `written` 0 leaves, unknown reason) | R-SH4, R-SH6, R-CT4, R-CT14 |
| L0 | expect 9, 10: `settle` 4xx other than 429 (leave, nothing counted), 429, 5xx, 599, `Timeout`, `Failed` (stay) | R-SH4, R-AP34 |
| L0 | expect 11: `totals` (sums, first time stays, last time moves, other members stay, valid file) | R-SH6, R-TF2 |
| L2 | `share/sh11-send-one`: one request, `Talon-Contributor`, no `Authorization` (`require` lines in the fake route), 201, rows leave, totals | R-SH4, R-SH5, R-SH6, R-AP10, R-CT1, R-CT2 |
| L2 | `sh12-send-limits`: 1001 rows, 2 requests of 500, row 1001 stays, 2 answers added | R-SH4, R-SH6, R-CT14 |
| L2 | `sh13-send-version`: rows of 0.8.0 leave with no send; empty queue: query only; stale only: no `share.json` read, no request | R-SH4, R-TF7 |
| L2 | `sh14-send-answers`: 429, 503 `busy` with `Retry-After: 1`, timeout, failed: rows stay, one request each, no `sleep`, no retry, no write. 422: rows leave, no totals write. 200 that skips both rows: leave, `sent` 2, `counted` 0 | R-SH4, R-AP34, R-AP82, R-CT4, R-CT13, R-CT14 |
| L2 | `sh15-send-off`: `share` false, `Direct`, `--offline`, `DO_NOT_TRACK`, `CI`: no query, no request. Then all true: sent. | R-SH2, R-SH4 |
| L2 | `sh16-send-db-errors`: busy, failed and `TooNew` read of the queue: no request, no stderr, exit 0. Then it works. | R-SH4, R-CC8, R-TF3 |
| L2 | `sh17-send-no-share-json`: the file is made with a new id, then the send | R-SH4, R-SH5, R-SH13 |
| L2 | `sh18-send-talon-now`: `TALON_NOW` gives both times | R-SH6, R-EV22 |
| L2 | `sh19-send-stops`: 501 rows. 429, 503 busy, timeout stop the send after one request. A 422 lets the second request go. | R-SH4, R-AP34, R-AP82 |
| L2 | `sh20-send-unqueue-fails`: a failed `Unqueue` after a 201 gives no totals write, the next run counts the rows once | R-SH4, R-SH6, R-CT4 |
| L2 | `sh21-send-bad-share-json`: no request, no message | R-SH4, R-SH13 |
| L0 | expect 12 to 14: unlisted statuses (Q455), undecodable bodies (Q456), the timeouts (Q454) | R-SH4, R-CT4 |
| L3 | `tests/scenarios/fx/sq2-real-fx-queue-send` (`fxprobe`, 10 steps): `QueueRows` and `Unqueue` of the real `Fx`. Missing file (no file made, also for `Unqueue` with no seq); 5 rows of 2 versions in `seq` order; `Unqueue` of some rows, of a `seq` that is not there, of none; a new row gets the next `seq`; all rows removed (the table stays); a file with no `share_queue` (read: no row and no table; `Unqueue` makes the table, `user_version` 1, facts stay); `user_version` 0 (no table); a newer file (`TooNew`, same bytes); a text file (`Failed`, same bytes). New `fxprobe` calls `db-query ... queue-rows` and `db-write ... unqueue <seq>...` (doc in `cli/fxprobe.roc`). | R-SH4, R-TF7, R-TF3, R-CC8, TW4 |

R-AP82: a 503 is a 5xx, so the rows stay and the send does not wait (R-AP34: a user hint is not sent again by the command). It fits. `sh14` has the busy body.

## Output (proposed, R-OUT2)

None. `send!` prints nothing (R-SH4). L2 words print `  done`.

## Questions (answered 2026-11-03: Design Q452 to Q459, CLI R-SH4 details 1 to 8)

| # | Answer | Test change |
| --- | --- | --- |
| Q1 | The hook: `send!` is called at the end of each command that sent a registry request, after its output: `tln update` (206b), then 206e, 206f, 217. | None here. The caller gives `sharing`, `talon_version`, `roots`. |
| Q2 (Q452) | `share = true` and no `share.json`: make it with a new id (R-SH13), then send. | New L2 `sh17-send-no-share-json` |
| Q3 (Q453) | R-SH4 wins: no send, no message, no exit change, also for `TooNew` and a `share.json` that does not parse. | `sh16` has a third run (`TooNew`), new L2 `sh21-send-bad-share-json` |
| Q4 (Q454) | Whole seconds. The timeout of each request is the time left, at least 1 s. | New L0 expect (`remaining`: 5, 4, 3, 2, 1, Stop, Stop) |
| Q5 | The header order is accepted. | None |
| Q6 (Q455) | An unlisted status (1xx, 202, 204, 3xx) keeps the rows. | New L0 expect (8 statuses) |
| Q7 (Q456) | A 200 or 201 that does not decode: rows leave, `sent` counts them, `counted` and `first` add 0. | New L0 expect (5 bodies) |
| Q8 (Q457) | The times use the Talon clock (`TALON_NOW`). Only a 200 or 201 is a send. | New L2 `sh18-send-talon-now`. In all totals writes a `clock` call comes before the `lock` (`Clock.now!`: one `clock!`). `sh14` is as before. |
| Q9 (Q458) | The second request goes only after a 200, a 201 or another 4xx. After a 429, a 5xx (503 busy too), a timeout or no answer the send stops. | New L2 `sh19-send-stops` |
| Q10 (Q459) | `Unqueue` fails: no totals write. The rows go again. | New L2 `sh20-send-unqueue-fails` (not L0: the flow decides it) |
| Q11 | The `share.json` write of 213b is accepted. | None |
| G-C100 (Q464) | A failed `Unqueue` stops the send: no second request. The totals cover only the requests whose `Unqueue` worked (CLI R-SH4 detail 9). The code is confirmed. | `sh20` (or a new L2 case): 2 batches, the first `Unqueue` fails: one request, no totals write |

Pinned in the calls of `sh17` (reading, for the code step): the made file is the write of `tln share on` (`lock`, `read_files`, `random` three times, `write_atomic` temp, `chmod`, `rename`, `unlock`), the id is then used with no new read of the file.

## Left for later

| Item | Why |
| --- | --- |
| The hook in real commands | Q1 |

## Verify results

Red (stubs): `roc test tests/unit/l0-8.roc`: 10 `QueuesendTest` expects fail (`todo: slice 216`), the constants expect passes; the other failures in the driver are `RegistryTest` (records 104j, another agent). `tests/commands/run.sh share/`: 10 pass, 6 fail (`sh11` to `sh16`, `[ROC CRASHED] todo: slice 216`). `roc check` and `roc fmt --check` pass. `MISSING=1 scripts/rules.sh` for the rules above: no id with no test.

With a private reference (deleted): L0 all `QueuesendTest` pass, L2 `share/` 16 of 16. The expected files of `sh11` to `sh16` were written by hand (from `mk-queue-send.sh`, not from a run): the reference passed them with no `UPDATE=1`.

Expected exits (read): all 6 cases exit 0, stderr empty; the stdout is `== <word>` and `  done`.

Revert check: `research/slice-216-revert/results.txt`, 10 mutations (third batch, other versions sent, 429 leaves, 4xx counts, no contributor header, no R-SH2 recheck, rows leave on stay, first time overwritten, budget off by one, stale not removed): each caught by L0 or L2.

## Round 2 (L3 case, answers Q452 to Q459)

- `QueueRows` has no limit (a field). The manager note said "with a limit"; the plan takes the first 500 rows of the running version in `QueueSend.plan` (L0), and the queue has at most 10,000 rows, so no limit is in the signature. If a limit is wanted, the signature changes (the manager decides).
- Red: `roc test tests/unit/l0-8.roc`: 13 `QueuesendTest` expects fail (`todo: slice 216`), the constants expect passes. `tests/commands/run.sh share/`: 10 pass, 11 fail (`sh11` to `sh21`). `tests/run.sh fx/sq2`: fails with `[ROC CRASHED] todo: slice 216`. `roc check`, `roc fmt --check` pass.
- Green with private references (deleted): L0 189 of 189 (no `RegistryTest` failure counted: those are slice 104j), L2 `share/` 21 of 21, L3 `fx/sq2-real-fx-queue-send` 1 of 1 (the temporary `RealDb.roc` arms were removed again). Expected files were written by hand; no `UPDATE=1`. Exits read: `sq2` exit 0 (its `err TooNew(2)` and `err Failed(...)` lines are intended); `sh11` to `sh21` exit 0, stderr empty.
- Revert check: `results.txt` has 16 mutations in all (M1 to M16), each caught (M12 and M15 needed a second try because the first mutation did not compile). The script and the references are deleted.
- `cli/fxprobe.roc` has the 2 new calls (a test tool, as in slice 215). `RealDb.roc` arms stay stubs (`crash "todo: slice 216"`), except the empty-case arms. The code agent must also make `nothing_to_clear!` cover `Unqueue` (a missing file is not made).

## Code

| File | Change |
| --- | --- |
| `cli/lib/QueueSend.roc` | `plan`, `remaining`, `request`, `settle`, `totals`, `send!` (and the private steps `send_to!`, `contributor!`, `send_batches!`, `record!`). A failed `Unqueue` stops the send (Q459; the slice text does not say if a later batch goes: it does not). |
| `cli/lib/ShareFlow.roc` | `ensure_doc!` and `totals_write!` (public, for Q452 and R-SH6); `make_id!` gives the `Doc`. Same calls as before for `tln share on`. |
| `cli/RealDb.roc` | `QueueRows` (no table: no row), `Unqueue` (makes the table first, Q451), `nothing_to_clear!` covers `Unqueue`. |

Results: L0 `QueuesendTest` pass (the 2 `ClosureindexTest` failures are slice 206d); L2 `share/` 21 of 21; L3 `fx/sq2`, `fx/sq1`, `fx/db` pass; `scripts/test.sh check fmt l2 l3`: only the 206d cases `registry/ap28-update-unknown` and `registry/ix6-update-offline` fail.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-216-revert/code-final.sha256` | 3 of 3 OK (`QueueSend.roc`, `ShareFlow.roc`, `RealDb.roc`) |
| `todo: slice 216` in `cli/` | None |
| L0 | All `QueuesendTest` expects pass. `l0-8` red only on slice 206d stubs (`ClosureindexTest`, in progress). |
| L2 | `share/` 21 of 21. Full l2: only the 2 slice 206d red cases fail. |
| L3 | `fx/sq2-real-fx-queue-send`, `fx/sq1-real-fx-queue`, `fx/db` green (real SQLite) |
| Expected exits | All new cases exit 0 with empty stderr (R-SH4: a send never changes exit or output) |
| Revert check | 16 of 16 caught |
| Design answers | Q452 to Q459; Q5 header order and Q11 share.json write accepted |
| Code note | `ShareFlow` gained `ensure_doc!` and `totals_write!` (Q452 id creation, the totals write). |
| G-C100 | Answered as Q464: a failed `Unqueue` stops the send. L2 `share/sh22-send-unqueue-stops` (501 rows, one request, no totals write) passes with the code. |
| Moved out | The call of `QueueSend.send!` at the end of real commands: `tln update` (206b, done) needs the hook in 206d2 or 206e; the other commands in 206e, 206f, 217. |


## Q464 (G-C100)

A failed `Unqueue` stops the send: the second batch does not go, and the totals cover only the batches whose `Unqueue` worked. New L2 `share/sh22-send-unqueue-stops` (501 rows, the first `Unqueue` fails): one request, no totals write, the rows stay, exit 0, stderr empty. Passes with the code (`tests/commands/run.sh share/`: 22 of 22).
