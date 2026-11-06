# 220 Share logout, forget, account

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 220 of `PLAN-P2-CLI.md`. `tln share logout`: `DELETE /v1/tokens`, remove the JWT. `tln share forget`: `DELETE /v1/contributors/me` with the JWT or the id, new id, totals 0, the message about `compat_hints`. `tln share` (status) with a JWT: `GET /v1/contributors/me`; a 401 removes the JWT and prints `run tln share login`. Not in this slice: `login` (219), the parts marked "Question" below.

## Rules

R-SH8 (the account part), R-SH9, R-AP35, R-AP36, R-AP38. Named also: R-SH10 (direct), R-SH13 (the JWT past its time is not sent; the members that `logout` and `forget` write), R-SH5 (the id goes with the machine form of the delete only; a new id), R-CT7 and R-CT16 row 7 (the proof of the delete), R-E6, R-OUT2, R-OUT4, R-TF2.
Design: CLI 1 (R-SH5, R-SH8, R-SH9, R-SH10, R-SH13), CLI 3 (R-E6); Registry 4 (R-AP35, R-AP36, R-AP38), 6.1 (R-CT7, R-CT10, R-CT16). Closed slices read: 213, 215, 216, 219.

## Public signatures (stubs, `crash "todo: slice 220"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `ShareAccount.timeout_s`, `Request`, `Reply` | the constant 20 and the 2 types of slice 219 (written again: `ShareLogin` imports `ShareFlow`, and `ShareFlow` must import `ShareAccount`, so `ShareAccount` cannot import `ShareLogin`). The code agent may make `ShareLogin` use them | R-DA9 |
| `ShareAccount.tracker_request`, `logout_request` | `{ origin, version, token } -> Request` | R-AP35, R-AP38 |
| `ShareAccount.forget_request` | `{ origin, version, proof : [Account(Str), Machine(Str)] } -> Request` | R-AP36, R-SH5 |
| `ShareAccount.tracker_answer` | `{ origin, version, reply } -> Try([Tracker(Account.Tracker), Stopped], Fail)` | R-AP35, R-SH8, R-E6 |
| `ShareAccount.delete_answer` | `{ origin, version, reply } -> Try([Done, Stopped], Fail)` | R-AP36, R-AP38, R-E6 |
| `ShareAccount.jwt` | `{ doc, now } -> [None, Live(Str), Expired]` | R-SH13, R-SH8 |
| `ShareAccount.logged_out`, `forgotten` | `Doc -> Doc`, `{ doc, id } -> Doc` | R-SH9, R-SH13 |
| `ShareAccount.direct_text` | `{ command } -> Str` | R-SH10 |
| `ShareAccount.account_lines`, `account_data`, `login_needed_lines` | the status texts | R-SH8, R-OUT2 |
| `ShareAccount.logout_lines`, `logout_data`, `forget_lines`, `forget_data` | the texts and the `data` | R-SH9, R-OUT2, R-OUT4 |
| `ShareAccountFlow.logout!`, `forget!` | `Fx, Args => I32` | R-SH9, R-SH10 |
| `ShareFlow.status_account!` | `Fx, { registry, offline, path, doc } => Try([Tracker(..), LoginNeeded], Fail)` | R-SH8 |

Reuse (no new helper): `ShareFlow.totals_write!` for each write of `share.json` (the lock, the temp file, `chmod 0600`, `rename`), `Registry.headers`, `Registry.refuse`, `Registry.no_answer`, `Registry.retry_after_of`, `Clock.parse_utc`, `Clock.format_utc`, `records.Account.decode_tracker`, `ShareJson.fresh`, `ShareJson.id_of`, `Common.failed!`, `Out.json_ok`. `ShareLogin.login_direct` can call `ShareAccount.direct_text` (same text).

Edits to existing files (originals in `research/slice-220-revert/before/`, the stubs in `research/slice-220-revert/stubs/`): `cli/lib/main.roc` (2 exposes), `cli/lib/Run.roc` (2 branches `["share", "logout"]` and `["share", "forget"]`, 1 import), `cli/lib/ShareFlow.roc` (the stub `status_account!` and its call in `status_flow!` when `doc.token` is set; the code agent fills the call and adds the lines and the `data`), `tests/unit/l0-7.roc` (1 import). New: `cli/lib/ShareAccount.roc`, `cli/lib/ShareAccountFlow.roc`, `tests/unit/ShareaccountTest.roc`, `tests/tools/mk-share-account.sh` (makes the 7 L2 cases `sh33` to `sh39`).

## The flow (reading, for the review)

Order of the calls in `calls.log`. `ShareFlow.totals_write!` is the write of `share.json` (`lock`, `read_files`, `random`, `write_atomic <temp>`, `chmod 0600`, `rename`, `unlock`).

| Command | Calls | Rule |
| --- | --- | --- |
| `logout` | `args`, `env_all`, `read_files config.toml`, `Net.registry` (`direct`: exit 2, calls stop here), `read_files share.json` (`ShareJson.read`; a file that does not parse is exit 19), `clock`, `jwt`; `Live`: `http_send DELETE <origin>/v1/tokens` (`User-Agent`, `Authorization: Bearer <JWT>`), `delete_answer`; `Done`: the write with `logged_out`; then stdout `logout_lines` or the envelope | R-SH9, R-AP38, R-SH10, R-SH13 |
| `forget` with a live JWT | the same up to `clock`; `http_send DELETE <origin>/v1/contributors/me` with `Authorization: Bearer <JWT>` and no `Talon-Contributor` (a token wins, R-CT16 row 7); `Done`: `random`, `random` (the new id, `ShareJson.id_of`), the write with `forgotten`; stdout | R-SH9, R-AP36, R-SH5 |
| `forget` with no JWT | no `clock` call; `http_send DELETE` with `Talon-Contributor: <id>` and no `Authorization`; then as above | R-SH9, R-AP36, R-CT7 |
| `share` with a JWT | the calls of slice 213b up to `db_query ... queue`; then `clock`, `jwt`; `Live`: `http_send GET <origin>/v1/contributors/me` (`User-Agent`, `Authorization`, no id); `Tracker`: no write, the account lines after the local lines; `Stopped` (401) or `Expired`: the write with `logged_out`, then the line `run tln share login` | R-SH8, R-AP35, R-SH13 |
| `share` with no JWT | unchanged (sh3): no `clock` call, no request | R-SH8 |

`forget` does not touch `config.toml` (`share` stays) or the queue. The `compat_hints` counts stay at the registry and the message says so.

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ShareaccountTest.roc` (driver `l0-7`) expect 1 to 3: `tracker_request`, `logout_request`, `forget_request` (exact; the 2 proofs, never both headers) | R-AP35, R-AP38, R-AP36, R-SH5, R-CT16 row 7 |
| L0 | expect 4, 5: `tracker_answer` (200, 401 `Stopped`, bad body and no answer: `network`), `delete_answer` (204, 401, 400 `internal`, 429 and 503 `network`, no answer) | R-AP35, R-AP36, R-AP38, R-SH8, R-E6 |
| L0 | expect 6: `jwt` (none, one second before the time, one second after it) | R-SH13, R-SH8 |
| L0 | expect 7, 8: `logged_out`, `forgotten` (the exact doc, `extra` stays) | R-SH9, R-SH13, R-SH5, R-TF2 |
| L0 | expect 9: `direct_text` | R-SH10 |
| L0 | expect 10 to 13: `account_lines`, `account_data`, `login_needed_lines`, `logout_lines`, `logout_data`, `forget_lines`, `forget_data` (the words of R-SH9: `compat_hints`, new id, totals 0) | R-SH8, R-SH9, R-OUT2, R-OUT4 |
| L2 | `share/sh33-logout`: live JWT, `DELETE /v1/tokens`, 204, 3 members null, the rest stays, `config.toml` unchanged | R-SH9, R-AP38, R-SH13, R-SE15 |
| L2 | `sh34-forget-account`: `--json`, the JWT form (no id sent), new id, totals 0, times and JWT null, `share` unchanged | R-SH9, R-AP36, R-SH5, R-SH13, R-OUT4 |
| L2 | `sh35-forget-machine`: no JWT, the id form (no `Authorization`, no `clock`), text with `compat_hints` | R-SH9, R-AP36, R-SH5 |
| L2 | `sh36-account-direct`: `logout` and `forget --json` with the registry `direct`: exit 2, the calls stop after `config.toml` | R-SH10, R-EC2 |
| L2 | `sh37-status-account`: live JWT, `GET`, 200, the account lines; run 2 `--json` | R-SH8, R-AP35, R-OUT2 |
| L2 | `sh38-status-stopped`: 401, the JWT is removed, `run tln share login`; run 2 `--json` finds no JWT (no `clock`, no request, no `account` member) | R-SH8, R-AP35, R-SH13 |
| L2 | `sh39-status-expired`: `token_expires_at` before the clock: no request, JWT removed, the same line | R-SH13, R-SH8 |
| L3 | None | The write of `share.json` is the code of 213b (L3 `scenarios/share/fr1-first-run-tty`); the L2 `calls.log` shows that the 3 commands use the same steps. The real `http_send!` has L3 cases (slice 200). |

## Output (proposed, R-OUT2, TW24)

| Item | Text |
| --- | --- |
| `logout` (stdout) | `Logged out. Each token of the account stopped.` `--json` `data`: `{"logged_out":true}` |
| `forget`, JWT (stdout) | `The registry removed the account, its results and the links of each machine to it.` / `This machine has a new id, and its totals are 0.` / `The counts that went into compat_hints stay, because they hold no id.` `data`: `{"removed":"account"}` |
| `forget`, no JWT | the first line is `The registry removed the results that this machine sent before a login.` The other 2 lines are the same. `data`: `{"removed":"machine"}` |
| Status, account part (stdout, after the local lines) | `account: <login>`, `account machines: <n>`, `account counted: <n>`, `account first: <n>`, `account agreed: <n>`, `account disagreed: <n>`, `account unconfirmed: <n>`, `account first sent: <time>` and `account last sent: <time>` only when set (ms rounded down to whole seconds, RFC 3339) |
| Status, after a 401 or an expired JWT | `run tln share login` (the text of R-SH8) |
| Status `--json` | with a JWT the member `account` is added after `queued`: `{"id","login","machines","counted","first","agreed","disagreed","unconfirmed","first_sent_at","last_sent_at"}`, or `null` after a 401 or an expired JWT. With no JWT the member is not there (so `sh3` stays as it is; Q12) |
| `direct` (exit 2) | `tln share logout needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` (and `forget`) |
| The new id | not printed (R-SE15: only 8 characters of an id are shown, and a new id has no use in the text) |

## Out of scope

| Item | Reason |
| --- | --- |
| `login` | Slice 219 |
| The parts of the Questions section | The design does not say. No test pins them. |
| Retry rules of R-AP34 for the 3 requests | A request of these commands is one try, as `login` |

## Questions (to the design owner, TW17)

Manager (2026-11-03): questions 1 to 11 went to TalonRegistry as G-C112 to G-C122 (in this order). Questions 12 and 13 are proposals (R-OUT2), not questions: no `account` member with no JWT; `token_expires_at` equal to now is expired. The code step waits for the answers.

Marked "test" are the places where a test pins a default. All others have no test.

| # | Question | Default used |
| --- | --- | --- |
| Q1 | `tln share` after a 401 or an expired JWT: exit code? The design says only "removes it and prints `run tln share login`". Exit 0 (the local part is shown), or a failure (20, R-E6 says 401 to a write is 20, but this is a `GET`; 15 is the `Get` rule of `Registry.refuse`)? And does the line go to stdout or stderr? | Answered (Design Q477, CLI R-SH8): exit 0, stdout, after the local lines; `login_needed` in `--json`. Test change: none for `sh38`, `sh39`; add `data.login_needed` to the `--json` run |
| Q2 | `tln share` with a JWT, when the registry is `direct` or `--offline` is set: does it send the `GET`? The status already shows sharing off for both. | Answered (Design Q478): no `GET`, local lines, exit 0, the JWT stays. Test change: add an L2 case with a JWT and `--offline`, and one with `direct`: no request in `calls.log`, the file unchanged |
| Q3 | `tln share` with a JWT, when the `GET` fails (no answer, 429, 5xx, 2xx body that does not decode): exit 15 (R-E6), or the local part with a warning on stderr and exit 0 (the status is a read of local state)? The JWT stays in both. | Answered (Design Q479): local lines, a warning on stderr, exit 0, the JWT stays. Test change: L2 runs for no answer, 429 (with `Retry-After`), 5xx and a body that does not decode |
| Q4 | `logout` with no JWT (or no `share.json`): a message and exit 0 with no request, or an error? | Answered (Design Q480): no request, no file, a message, exit 0. Test change: L2 `logout` with no JWT and with no file |
| Q5 | `logout` or `forget` when the registry answers 401 (the token already stopped or expired; or no `contributors` row, R-CT16 row 4): remove the JWT and finish with exit 0 (the goal is reached), or exit 20 (R-E6) and keep it? For `forget` with a stopped token the account data is NOT deleted, so exit 0 would be wrong. | Answered (Design Q481): `logout` removes the JWT and exits 0; `forget` changes nothing and exits 20 with the login hint. Test change: L2 `logout` with a 401 (JWT removed, exit 0) and `forget` with a 401 (exit 20, `share.json` equal to before, the JWT still there) |
| Q6 | `logout` or `forget` when the `DELETE` fails (no answer, 429, 5xx): is the local state kept (the JWT, the old id, the totals)? I read: kept, exit 15, so a later run can try again. | Answered (Design Q482): the local state stays, exit 15. Test change: L2 runs for no answer, 429 and 5xx of both commands, `share.json` equal to before |
| Q7 | `logout` or `forget` with a JWT past `token_expires_at` (R-SH13: it is not sent). `logout`: remove it, no request? `forget`: the machine form with the id (then the account data stays at the registry), or stop and ask for `login` first? | Answered (Design Q483): `logout` removes it, no request, exit 0; `forget` stops with exit 2, no request, no change. Test change: L2 for both with a JWT past `token_expires_at` |
| Q8 | `forget` with no `share.json`: no id and no JWT, so the registry would answer 400 (R-CT16 row 7). No request and a message, or make the file first? | Answered (Design Q484): no request, no file, a message, exit 0. Test change: L2 `forget` with no file |
| Q9 | `logout` and `forget` with `--offline`: exit 15 with no request, as `login` (Design Q476)? | Answered (Design Q485): exit 15, no request, no change. Test change: L2 for both with `--offline` |
| Q10 | `forget` with a JWT: send only `Authorization` (my reading of "with the JWT or the id", R-CT16 row 7: the id is ignored when the token is there), or both headers? | Answered (Design Q486): only `Authorization`. No test change (`sh34`, L0 expect 3) |
| Q11 | `forget` and the members that Talon does not know (R-TF2: Talon keeps them on write) against R-SH13 ("`null` for the other members"): are they kept? | Answered (Design Q487): unknown members stay. No test change (L0 expect 8) |
| Q12 | `--json` of the status with no JWT: `account` as `null` (the catalog writes `null` for a value that does not exist, section 3) or not there? I keep it not there so that `sh3` stays; `null` always needs a change of the 3 `--json` lines of `sh3`. | Answered (Design Q488): `"account": null`. Test change: the 3 `--json` lines of `sh3` and the `sh38` run 2 get `"account":null` |
| Q13 | The JWT time compare at the same second: is a JWT with `token_expires_at` equal to now expired? | Answered (Design Q488): equal to now is expired. Test change: add the equal case to L0 expect 6 |

## Red state

`roc test tests/unit/l0-7.roc`: all 13 `ShareaccountTest` expects fail with `todo: slice 220`. `tests/commands/run.sh share/sh33 ... sh39`: 7 of 7 fail with `[ROC CRASHED] todo: slice 220`, `sh3` passes. `scripts/test.sh check` passes; `fmt` fails only on files of the slice 206e2 agent (`InstallFlow`, `NoRank`, `PickLoop`, `ResolveBase`). `MISSING=1 scripts/rules.sh R-SH8 R-SH9 R-AP35 R-AP36 R-AP38`: no id with no test.

A private reference (deleted; stubs restored from `research/slice-220-revert/stubs/`) passed all 13 L0 expects and the 7 L2 cases with the hand-written expected files, with no `UPDATE=1`. Expected exits (read from the `exit` lines of `expect/stdout`): `sh33` 0, `sh34` 0, `sh35` 0, `sh36` 2 and 2, `sh37` 0 and 0, `sh38` 0 and 0 (Q1), `sh39` 0 (Q1). The only non-zero exits are the two `direct` runs (R-SH10).

## Round 2 (tests for Design Q477 to Q488)

Stub changes (all `crash "todo: slice 220"`): `ShareFlow.status_account!` gives `Try([None, Tracker(..), LoginNeeded], Fail)` and prints the warning of a failed `GET` itself (`warning: <Fail.message>` on stderr, JWT kept); the flow calls it only when `doc.token` is set. New in `ShareAccount`: `forget_stopped`, `forget_expired`, `offline_text`, `no_login_lines`/`no_login_data`, `nothing_to_forget_lines`/`nothing_to_forget_data`, `status_members`. `jwt` at or before `now` is `Expired`; `tracker_answer` uses `Retry-After`.

| Change | Where |
| --- | --- |
| L0 expect 6: the equal second is `Expired` | `ShareaccountTest` |
| L0 new expects: 429 with `Retry-After`; `forget_stopped` and `forget_expired` (exact texts); `offline_text`; the two "nothing" texts and data; `status_members` | `ShareaccountTest` (18 expects in all) |
| L2 `sh3` (3 `--json` lines), `sh38` run 2: `"account":null` | Q488 |
| L2 `sh39` is now `share --json`: `account` null and `login_needed` true | Q477 |
| L2 new `sh40` (JWT, `--offline` and direct: no clock, no GET), `sh41` (GET: no answer, 429 + `Retry-After`, 502: warning, exit 0, JWT stays) | Q478, Q479 |
| L2 new `sh42` (logout, no JWT, plain and `--json`), `sh48` (no `share.json`: forget and logout, no file) | Q480, Q484 |
| L2 new `sh43` (logout 401: JWT removed, exit 0), `sh44` (logout expired: no request, JWT removed) | Q481, Q483 |
| L2 new `sh45` (forget 401: exit 20, no change; `--offline` for forget and logout: exit 15), `sh46` (forget expired: exit 2, no request, no change) | Q481, Q483, Q485 |
| L2 new `sh47` (DELETE fails: logout no answer, forget 429 and 502: exit 15, no change) | Q482 |

Proposed texts (R-OUT2): `There is no login on this machine.` (`{"logged_out":false}`), `There is nothing to forget on this machine.` (`{"removed":null}`), forget 401: `the registry <origin> refused the account delete (<type>): <detail>. Run tln share login, and then tln share forget.` (exit 20), forget expired: `the login has expired, so the registry cannot delete the account. Run tln share login, and then tln share forget.` (exit 2), `tln share <command> needs the network, and --offline is set.`, status `--json`: `login_needed` after `account`. Warning of a failed status GET: `warning: ` and the `Registry` message.
Readings (not in the design, pinned by `calls.log`): no `clock` call for direct, `--offline`, no JWT or no file; `--offline` is checked right after `direct`, before `share.json`; a bad 2xx body of the status GET has no L2 run (the decode text is not fixed), only L0.

Red: L0 18 `ShareaccountTest` expects fail with `todo: slice 220`. L2: `sh33` to `sh48` crash with `todo: slice 220`; `sh3-status` fails on the 3 `--json` lines (`account` null: Q488). A private reference (in `research/slice-220-revert/ref/`, deleted) passed all 18 expects and `sh3`, `sh33` to `sh48`. Expected exits (read): `sh33` 0; `sh34` 0; `sh35` 0; `sh36` 2, 2; `sh37` 0, 0; `sh38` 0, 0; `sh39` 0; `sh40` 0, 0; `sh41` 0 x3; `sh42` 0, 0; `sh43` 0; `sh44` 0; `sh45` 20, 15, 15; `sh46` 2; `sh47` 15 x3; `sh48` 0, 0.

## Code

| File | Change |
| --- | --- |
| `cli/lib/ShareAccount.roc` | All pure functions made (requests, answers, `jwt`, `logged_out`, `forgotten`, texts, `status_members`). `delete_answer` and `tracker_answer` use `Registry.refuse` with the `Retry-After` of the reply |
| `cli/lib/ShareAccountFlow.roc` | `logout!`, `forget!`: shared `start!` (direct, `--offline`, `share.json`), then the flows of the table in "The flow" |
| `cli/lib/ShareFlow.roc` | `status_account!` made (no `clock` for direct or `--offline`; a failed `GET` gives a warning on stderr and `None`; 401 or expired: `totals_write!` with `logged_out`). `status_flow!` adds the account lines and `status_members` to the data |
| `cli/lib/ShareLogin.roc` | `timeout_s`, `Reply`, `Request` and `login_direct` use `ShareAccount` (no duplicate) |

Review notes: no test changed, no dispute. `logout` with a 401 and `logout` with an expired JWT both write `logged_out` and print the normal logout text (sh43, sh44). `forget` with a 401 reads the status and body from the same reply for `forget_stopped`. `scripts/test.sh check l0 l2 l3`: l2 347 passed, l3 pass; l0 fails only in `l0-8` (206e2: `ToolchainTest`, `source` field).

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-220-revert/code-final.sha256` | OK, 4 files |
| `grep "todo: slice 220" cli/` | nothing |
| Expected exits (read) | sh33 0; sh34 0; sh35 0; sh36 2, 2; sh37 0, 0; sh38 0, 0; sh39 0; sh40 0, 0; sh41 0 x3; sh42 0, 0; sh43 0; sh44 0; sh45 20, 15, 15; sh46 2; sh47 15 x3; sh48 0, 0. Each non-zero exit is the rule of its run (R-SH10, Q481, Q483, Q482, Q485) |
| All `share/` L2 cases (48), with the `ShareLogin` change | pass |
| `scripts/test.sh check fmt l0 l2 l3` | all pass, with slice 206e2 code in the tree |
| Incident | The 206e2 test agent restored `main.roc`, `Run.roc`, `ShareFlow.roc` from a snapshot, then put back the 220 stub copies. The 220 test agent checked the 3 files; the green run confirms them |
| For the human review | The proposed texts and `--json` fields (sections Output and round 2) |
