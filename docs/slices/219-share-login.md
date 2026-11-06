# 219 Share login

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 219 of `PLAN-P2-CLI.md`. `tln share login`: the text before the code, the GitHub device flow (R-SH12), `POST /v1/tokens` with the GitHub token and the id, the JWT in `share.json`. Not in this slice: `logout`, `forget`, the account view of `tln share` (220).

## Rules

R-SH7, R-SH10, R-SH12 (rows 1 to 10), R-SH13 (the form of the file), R-SH5 (the id, mode 0600), R-EV28, R-EC13 (login case), R-EC2 (direct), R-CT8 (client part: row 1, the id), R-AP37 (the request and the answer), R-E6 (the registry errors of the token request), R-J2, R-J7. Named also: R-EC15, R-EC19, R-EC20, R-TF6, R-SE15, R-OUT2, R-OUT4.
Design: CLI 1 (R-SH7, R-SH10, R-SH12, R-SH13), 7.1 (R-EV28), CLI 3 (R-EC, R-E6, R-J); Registry 4 (R-AP37), 6.1 (R-CT8). Gap G-C10 is answered as Q206 (`TALON_GITHUB_WEB`, RFC 8628 poll rules). Closed slices read: 213, 213b, 216, 200, 201, 201b.

## Public signatures (stubs, `crash "todo: slice 219"`)

New file `cli/lib/ShareLogin.roc` (copy of the stub in `research/slice-219-revert/before/ShareLogin.roc`). The constants are not stubs.

| Name | Signature | Rule |
| --- | --- | --- |
| `ShareLogin.client_id`, `default_web`, `timeout_s` | `Str` `"Ov23li2sxWgMaAvjaUbQ"`, `Str` `"https://github.com"`, `U64` 20 (the 20 is a proposal, Q8) | R-CT8 row 1, R-EV28 |
| `ShareLogin.web_of` | `List((Str, Str)) -> Str`: `TALON_GITHUB_WEB`, not empty, else the default | R-EV28 |
| `ShareLogin.intro_lines` | `{} -> List(Str)` | R-SH7 |
| `ShareLogin.code_lines` | `{ web, user_code } -> List(Str)` | R-SH7, R-SH12 row 1 |
| `ShareLogin.code_request` | `{ web } -> Request` | R-SH12 row 1 |
| `ShareLogin.code_answer` | `{ reply, now } -> Try(Code, Fail)` (`Code` has `device_code`, `user_code`, `interval`, `ends`) | R-SH12 rows 1, 2, 7, 9, 10 |
| `ShareLogin.poll_request` | `{ web, device_code } -> Request` | R-SH12 row 3 |
| `ShareLogin.poll_answer` | `{ reply, wait } -> Try([Token(Str), Wait(U64)], Fail)` | R-SH12 rows 4 to 10 |
| `ShareLogin.expired` | `{ now, ends } -> Bool` | R-SH12 row 7 |
| `ShareLogin.token_request` | `{ origin, version, contributor, github_token } -> Request` | R-SH7, R-AP37, R-SH5 |
| `ShareLogin.token_answer` | `{ origin, version, reply } -> Try(Granted, Fail)` | R-AP37, R-E6 |
| `ShareLogin.stored` | `{ doc, granted } -> ShareJson.Doc` | R-SH7, R-SH13 |
| `ShareLogin.login_direct`, `done_lines`, `done_data` | the texts and the `data` | R-SH10, R-OUT2, R-OUT4 |
| `ShareLogin.login!` | `Fx, Args => I32` | R-SH7 |

`Request` is the argument of `Fx.http_send!`. `Reply` is its result. No new `Fx` call: `http_send!`, `sleep!` and `clock!` exist (slice 200). No new type in `records`: `records.Account` has `Token`, `Login`, `decode_token` (slice 104e).

Edits to existing files (originals in `research/slice-219-revert/before/`): `cli/lib/main.roc` (1 expose), `cli/lib/Run.roc` (one branch `["share", "login"]` and its import), `tests/unit/l0-7.roc` (1 import). New: `cli/lib/ShareLogin.roc`, `tests/unit/ShareloginTest.roc`, `tests/tools/mk-share-login.sh` (makes the 7 L2 cases). No file of the 206e agent was edited.

## The flow (tested reading, for the review)

The steps are in the doc of `ShareLogin.roc`. Order of the calls in `calls.log` for a good login: `args`, `env_all`, `read_files config.toml`, `read_files share.json`, `http_send` (code), `clock` (the start, also when the answer is bad), then for each poll `sleep <wait in ms>` (also `sleep 0`), `clock`, `http_send` (poll), then `http_send` (token), then the write of 213b under the lock (`lock`, `read_files`, `random`, `write_atomic <temp>`, `spawn_all chmod 0600`, `rename`, `unlock`). `ShareFlow.totals_write!` is that write.

| Fact | Tested by |
| --- | --- |
| The registry `direct`: exit 2, and the calls stop after the read of `config.toml` | `sh25` |
| `share.json` is read before the intro and before any request: a file that does not parse gives exit 19 and no request | `sh29` |
| The intro and the code lines go to stderr, also without `--json` (R-J2: progress is human text on stderr). stdout has `Logged in as <login>.` or only the envelope. | `sh23`, `sh24` (proposal, see Output) |
| The wait goes before each poll. The first wait is `interval`. | `sh23` (7, 7, 12, 17, 17 s) |
| `expires_in`: the end time is `clock` of the code answer plus `expires_in`. After each wait the clock is read and `now >= ends` stops with exit 13 and no poll. | L0 `expired`, `sh26` run 3 (`expires_in` 0) |
| A GitHub request has `Accept` and `Content-Type` only: no `Authorization`, no `Talon-Contributor` (the id goes only to the registry, R-SH5). The registry request has no `Authorization`: the GitHub token is in the body. | the `require` lines of the fake routes, L0 |
| The GitHub token is only in the body of the one token request. `share.json` has the JWT, the expiry and the account, and every other member as it was. | `sh23` tree diff, L0 `stored` |
| A login does not turn sharing on | `sh23` (`config.toml` has `share = false` and no diff) |
| `TALON_GITHUB_WEB` moves only the 2 GitHub requests | `sh23` (registry at another host) |
| A second login replaces the token and the account | `sh24` |

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ShareloginTest.roc` (driver `l0-7`) expect 1: the client id and the default web | R-CT8 row 1, R-EV28 |
| L0 | expect 2: `web_of` (unset, hook, empty, `TALON_GITHUB_API` is not the hook) | R-EV28 |
| L0 | expect 3, 4: `code_request`, `poll_request` (exact: URL, headers, form body, no `scope`, the encoded device code) | R-SH12 rows 1, 3 |
| L0 | expect 5, 6: `intro_lines` (the facts of R-SH7, no URL, no code), `code_lines` | R-SH7, R-SH12 row 1 |
| L0 | expect 7 to 9: `code_answer` (good, `interval` 5 by default, 0 as it is, `ends`; no answer, 5xx, not JSON: kind `network`; `device_flow_disabled`, `incorrect_client_credentials`: kind `internal`, the text in the message) | R-SH12 rows 1, 2, 9, 10 |
| L0 | expect 10 to 14: `poll_answer` (pending, token; `slow_down` with and without `interval`, also a smaller one and from 0; `access_denied`, `expired_token`: `consent`; 5 other errors: `internal`; no answer, 500, 503, not JSON: `network`) | R-SH12 rows 4 to 10, R-EC13 |
| L0 | expect 15: `expired` (one second before, at the end, after) | R-SH12 row 7 |
| L0 | expect 16 to 18: `token_request` (exact, no `Authorization`), `token_answer` (201; 401: `rejected`; 400: `internal`; 429, 502, 503, no answer, bad body: `network`) | R-AP37, R-E6, R-SH7, R-SH5 |
| L0 | expect 19: `stored` (the exact file text, other members stay, a login again replaces) | R-SH7, R-SH13, R-TF2 |
| L0 | expect 20, 21: `login_direct`, `done_lines`, `done_data` | R-SH10, R-OUT2, R-OUT4 |
| L2 | `share/sh23-login-flow`: the whole flow with the hook, 5 polls (pending, `slow_down` with and without `interval`), the token request, the file write (mode step), `config.toml` unchanged | R-SH7, R-SH12 rows 1 to 5, 8, R-CT8 row 1, R-AP37, R-SH5, R-SH13, R-SE15, R-EV28 |
| L2 | `sh24-login-default-json`: no hook (`github.com`), `interval` 0 (`sleep 0`), token at the first poll, a login again replaces the token, `--json` | R-SH7, R-SH12, R-EV28, R-OUT2, R-OUT4, R-J2, R-CT8 |
| L2 | `sh25-login-direct`: exit 2, plain and `--json` (`TALON_REGISTRY=direct`) | R-SH10, R-EC2 |
| L2 | `sh26-login-declined`: `access_denied`, `expired_token`, `expires_in` 0 (no poll): exit 13, file unchanged, no token request | R-SH7, R-SH12 rows 6, 7, R-EC13 |
| L2 | `sh27-login-no-answer`: 8 runs, exit 15: poll no answer, 500, not JSON; token 502, token timeout; code timeout, 503, not JSON | R-SH7, R-SH12 row 10, R-E6, R-EC15 |
| L2 | `sh28-login-errors`: `device_flow_disabled` and `incorrect_device_code` exit 1; token 401 exit 20 (also `--json`, `details`), 400 exit 1, 429 exit 15 | R-SH12 row 9, R-E6, R-J7, R-EC1, R-EC20 |
| L2 | `sh30-login-no-share-json`, `sh31-login-offline`, `sh32-login-quiet` (round 2) | Q470, Q476, R-SH13, R-EC15, R-SH7 |
| L2 | `sh29-login-bad-share-json`: exit 19 and no request, plain and `--json` | R-TF6, R-EC19, R-SH5 |
| L3 | None | See below |

No L3 case: the write of `share.json` (temp, `chmod 0600`, `rename`) is the code of 213b and its L3 case `scenarios/share/fr1-first-run-tty` shows the real mode; the L2 `calls.log` of `sh23` shows that login uses the same steps. The real `http_send!` and `sleep!` have L3 cases (slice 200, `fx/hw1`, `fx/hw2`). A real L3 flow with a fake GitHub server would test the fake `Fx` rules again.

## Output (proposed, R-OUT2, TW24)

| Item | Text |
| --- | --- |
| Intro (stderr) | 3 lines: `A login ties this machine to your GitHub account.` / `The results that this machine sent before move to the account, and the next ones count for it.` / ``The registry keeps them until you run `tln share forget`, or until their compiler is 12 months old. Then it keeps only the totals.`` |
| Code (stderr) | `Open <web>/login/device` / `Enter the code: <user_code>` / `Talon waits until you approve the code in GitHub.` |
| Where | The intro and the code go to stderr with and without `--json` (R-J2). The person sees them in the terminal, and a program reads stdout only. |
| Done (stdout) | `Logged in as <login>.` |
| `--json` `data` | `{"account":{"id":<id>,"login":"<login>"},"token_expires_at":"<RFC 3339>"}`. No token. |
| `direct` (exit 2) | `tln share login needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` |
| Declined (exit 13) | `the login was declined in GitHub` |
| Expired (exit 13, `expired_token` and the end time) | `the code expired before you approved it. Run tln share login again.` |
| GitHub, no answer (exit 15) | `GitHub gave no answer in 20 s. Try again later.` or `GitHub gave no answer: <why>. Try again later.` |
| GitHub, 5xx (exit 15) | `GitHub answered <status>. Try again later.` |
| GitHub, not JSON (exit 15) | `GitHub answered with text that is not JSON. Try again later.` |
| GitHub, another `error` (exit 1) | `GitHub refused the login (<error>). The client id or the code of tln is wrong.` |
| Registry, no answer (exit 15) | `the registry <origin> gave no answer: no answer in 20 s. Try again later.` (as `Registry.no_answer`, the text of the closure query) |
| Registry 401 (exit 20) | `the registry <origin> refused the login (/errors/unauthenticated): <detail>. Run tln share login again.` The text of `Registry.refuse` for a write names a release and a workflow, so login needs its own text. `error.details` is as `Registry.refuse` gives it (R-J7). |
| Registry 400, 429, 5xx | the texts of `Registry.refuse` (method `Post`), unchanged |

## Out of scope

| Item | Reason |
| --- | --- |
| `logout`, `forget`, the account part of `tln share` | Slice 220 |
| `--offline` with `login` | The design does not say (Q6). No test. |
| The retry rules of Registry R-AP34 for a 429 or 5xx of `POST /v1/tokens` | R-SH7 gives exit 15 and R-AP34 is for the hint send. A login is one try. |

## Questions (answered 2026-11-03: Design Q470 to Q476)

| # | Answer | Test change |
| --- | --- | --- |
| Q1 (Q470) | No `share.json`: make it with a new id under its lock, before the intro, and send that id | New L2 `sh30-login-no-share-json` |
| Q2 (Q471) | The device flow requests send `User-Agent: tln/<version>`, after `Accept` | `code_request` and `poll_request` have a `version` field. L0 expects 3, 4 and the `calls.log` of all cases changed |
| Q3 (Q472) | The encoded form body stays | None |
| Q4 (Q474) | `expires_at` ms rounded down to whole seconds | New L0 expect (`...600500` and `...600999` ms give `...600` s) |
| Q5 (Q475, R-SH12 row 11) | A 2xx JSON answer with missing members is exit 15, the message names the step | New L0 expects (code answer: each member missing, wrong type, `{}`; poll with neither `error` nor `access_token`; token answer with no `token`, `expires_at` or `account`) and L2 `sh27` run 9 |
| Q6 (Q476) | `--offline`: exit 15, no request. The proposals are accepted; `--quiet` does not hide the intro and the code | New L2 `sh31-login-offline` and `sh32-login-quiet`, new `ShareLogin.login_offline` (stub) and 1 L0 expect |
| Q7, Q8 (Q473, Q476) | stderr for the intro and the code, 20 s: accepted | None |

## Round 2

- Stub changes: `code_request : { web, version } -> Request`, `poll_request : { web, device_code, version } -> Request`, new `login_offline : {} -> Str` (all `crash "todo: slice 219"`). The doc of `ShareLogin.roc` has the new steps (2b for `--offline`, step 3 makes the file).
- Calls that the code must make (reading, for the review): `--offline` is checked right after the registry check (after `direct`, before `share.json` is read or made): the calls end after `read_files config.toml` (`sh31`). A missing `share.json`: `read_files share.json` finds nothing, then `ShareFlow.ensure_doc!` (`lock`, `read_files`, `random` x3, `write_atomic <temp>`, `chmod 0600`, `rename`, `unlock`), then the intro (`sh30`).
- New proposed texts: `--offline`: `tln share login needs the network, and --offline is set.` (kind `network`). Missing code member (the first missing one): `GitHub answered the code request with no <member>. Try again later.` (`sh27` run 9 pins it for `device_code`). Poll with neither member: the message has `poll`. Token answer that does not decode: the message has `registry login` (L0 checks the words only).
- With `--quiet` the result line `Logged in as <login>.` stays on stdout (a proposal: the manager note only says that the intro and the code stay).
- Red: `roc test tests/unit/l0-7.roc`: 24 of 25 `ShareloginTest` expects fail with `todo: slice 219`, the constants expect passes. `tests/commands/run.sh share/sh23 ... sh32`: all 10 fail with `[ROC CRASHED] todo: slice 219`. `scripts/test.sh check fmt` passes.
- The expected files of the round were written by hand (the script, no run, no `UPDATE=1`). No reference was rebuilt: the round 1 reference passed round 1 with the same flow, and the new calls follow the tables above. The code agent must tell by a failing case if a hand-written line of `sh30` to `sh32` is wrong (a dispute, TW18).
- Expected exits (read): `sh30` 0, `sh31` 15 and 15, `sh32` 0, `sh27` 15 nine times. Others as in round 1.

## Disputes (from the code agent)

None. All 10 L2 cases (sh23 to sh32) and all 25 L0 expects passed with the hand-written expected files.

## Code

| File | Change |
| --- | --- |
| `cli/lib/ShareLogin.roc` | All stubs filled. New imports (`records.Account`, `Clock`, `Common`, `Help`, `Item`, `Net`, `Out`, `Registry`, `RocInstall`, `Roots`, `Share`, `ShareFlow`). Private helpers `github_headers`, `member`, `refused`, `code_expired`, `github_json`, `login_refused`, `login_flow!`, `poll_loop!`. |
| `cli/lib/main.roc`, `cli/lib/Run.roc` | No change in this step (the expose and the branch were already there). |

Review notes: reuse of `ShareFlow.ensure_doc!` and `ShareFlow.totals_write!` (no new write code), `Registry.headers`, `Registry.encode`, `Registry.refuse`, `Registry.no_answer`, `Account.decode_token`, `Clock.format_utc`. The version is `Help.version` (as the other flows; the design gives no other source). The 401 text of the token request is made from `Registry.refuse` (kind and `details` stay; only the message is replaced). Any 2xx status of the token request is a success. `--quiet` does not change `out!`: the result line stays on stdout. Result: `scripts/test.sh check fmt l0 l2 l3` pass (l0 time warning only).

## Verify results

Red (stubs): `roc test tests/unit/l0-7.roc`: 20 of 21 `ShareloginTest` expects fail with `todo: slice 219`, the constants expect passes (as in slice 216). `tests/commands/run.sh share/sh2`: `sh23` to `sh29` fail with `[ROC CRASHED] todo: slice 219`, `sh20` to `sh22` pass. `scripts/test.sh check fmt`: pass. `MISSING=1 scripts/rules.sh R-SH7 R-SH10 R-SH12 R-EC13 R-CT8 R-AP37 R-EV28`: no id with no test. `UpdateTest` in `l0-7` fails on its own (slice 206e, another agent): not this slice.

With a private reference (deleted): L0 all 21 `ShareloginTest` pass, L2 `share/sh23` to `sh29` pass (11 of 11 with `sh20` to `sh22`). The expected files were written by hand with `tests/tools/mk-share-login.sh` (the design readings above, not a run): the reference passed them with no `UPDATE=1`. One fix came from the reference: the `clock` call after the code request is also in the log when the answer is bad (the table above says so).

Expected exits (read): `sh23` 0, `sh24` 0, `sh25` 2 and 2, `sh26` 13 three times, `sh27` 15 eight times, `sh28` 1, 1, 20, 20, 1, 15, `sh29` 19 and 19. The case `sh23` to `sh29` run files have `exit 0` for the harness (the code is in the stdout). The error lines of stderr hold the proposed texts above.

Revert check: `research/slice-219-revert/results.txt`, 11 hand mutations (client id, `slow_down` +4, `>` for `>=`, `access_denied` as `internal`, interval 0 as 5, direct checked after the `share.json` read, expiry in ms, the id sent to GitHub, no `sleep 0`, an `Authorization` header with the GitHub token, a login that resets the totals): each caught by L0 or L2 (M6 and M9 by L2 only). The reference and the mutate script are deleted; `before/` keeps the originals.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-219-revert/code-final.sha256` | OK |
| `grep "todo: slice 219" cli/` | nothing |
| Expected exits (read, from the `exit` lines in stdout) | sh23 0; sh24 0; sh25 2, 2; sh26 13 x3; sh27 15 x9; sh28 1, 1, 20, 20, 1, 15; sh29 19, 19; sh30 0; sh31 15, 15; sh32 0. Each non-zero exit is the rule of its run |
| `scripts/test.sh check fmt l0 l2 l3` | all pass (l0 TW20 time warning only) |
| Code doubts | Accepted: `User-Agent` from `Help.version`; non-parse `share.json` read failure goes to `ensure_doc!` (as `QueueSend.contributor!`). Note: any 2xx of `POST /v1/tokens` counts as success, the design names 201 (R-AP37); no test pins a 200 |
| For the human review | `--offline` order (reading), `--quiet` keeps the result line, the new texts (section Output and Round 2) |

