# 223 Compat bot

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-03). Depends on slice 104k (`records.Work`, `records.Audit`).

Plan row 223 of `PLAN-P2-CLI.md`. The compat bot (Registry R-MX1, R-MX15, R-MX17): the workflow `.github/workflows/compat-bot.yml` and the bot script, a Roc app `bot/main.roc`. The bot reads the work lists (R-AP39, R-AP40), registers a nightly (`PUT /v1/toolchains/{tag}`), runs `tln probe`, and sends `POST /v1/compat` with the rows and the sweep. It gets the OIDC token as R-TP2.

G-C12 is answered: Design Q209 and R-MX17. The form is a Roc app `bot/main.roc` on basic-cli with the code shape of the CLI. Its input is the `data` of `tln probe --json`, not `compat.db`. Its tests are L0 and L2 with a fake `Fx`. The Worker side stays W2. So this slice has no shell script and no script in another language.

Safety: the workflow file is written in the repository and is never run by a test. No test calls GitHub or the registry, and no real token is used. The only test of the workflow reads its text (`tests/tools/ciscan.py compatbot`).

## Rules

R-MX1, R-MX4, R-MX10 (the part that is not a smoke build), R-MX13, R-MX15, R-MX17, R-AP2 (client), R-AP6 (client), R-AP10 (client), R-AP34 (the retry), R-AP39, R-AP40, R-TP2, R-TP17, R-TP7 (the workflow side: triggers), R-EC2 (usage stop). Named also: R-MX5, R-MX9, R-AP27, R-AP66, R-PB1, R-PB7, R-P3, R-OUT2.
Design: Registry 4 (R-AP2, R-AP6, R-AP10, R-AP34, R-AP39, R-AP40, R-AP66, R-AP67), 6 (R-MX1 to R-MX17), 7.1 (R-TP2, R-TP7, R-TP17); Resolution 4 (R-PB1 to R-PB8); CLI 3 (R-J1 to R-J6); Design Q66, Q209.
Gaps of the plan: G-C12 is answered (Q209, R-MX17). The other gaps are the questions below.

## Reuse (no second copy)

| Need | Reused | New |
| --- | --- | --- |
| Headers (`User-Agent: tln/<version>`, `Content-Type`), the retry schedule, the failure of an answer | `Registry.headers`, `Registry.refuse`, `Registry.no_answer`, `Publish.next` (R-AP34), `Publish.failure` | none |
| The OIDC token | `Publish.oidc`, `Publish.token_request`, `Publish.token` (R-TP2, R-TP17, slice 221) | none |
| The bodies | `records.Compat.encode_post`, `records.Compat.Row`, `records.Compat.Sweep` (R-AP10), `records.Toolchain` (answer of R-AP6), `records.Release` (answer of R-AP2), `records.Work` (R-AP39) and `records.Audit` (R-AP40) from slice 104k (Q575) | none |
| The probe result | The `data` form of `ProbeCmd.data` (kind `unit`) | `Bot.row` reads it |
| The wire to the world | `Fx.http_get!`, `Fx.http_send!`, `Fx.spawn_all!`, `Fx.sleep!`, `Fx.env_all!`, `Fx.args!` | none |

## Public signatures (stubs, `crash "todo: slice 223"`)

Package `bot/lib/main.roc` (deps: `lib` = `cli/lib`, `records`). Modules `Bot` (pure) and `BotFlow` (command code). `bot/main.roc` is the app (basic-cli, stub).

| Name | Type | Rule |
| --- | --- | --- |
| `Bot.tags` | `Str -> Try(List(Str), [BadJson(Str)])` | R-MX18 item 2 (Q567) |
| `Bot.done` | `Work.Answer -> Bool` | R-MX18 item 7 (Q572) |
| `Bot.chunks` | `{ rows, sweep : Try(Compat.Sweep, [None]) } -> List(Compat.Post)` | R-MX18 item 7, R-AP46 (Q572) |
| `Bot.url` | `{ origin, route : [Put(Str), Sweeps(Str), Audit(U64), Artifact(Str), Compat] } -> Str` | R-AP6, R-AP39, R-AP40, R-AP2, R-AP10 |
| `Bot.release_url` | `Str -> Try(Str, [BadJson(Str), NoRelease])` | R-AP2 (Q566: the first release that is not withdrawn) |
| `Bot.fetch_job`, `Bot.probe_job` | `{ dir, hash, url } -> List(Str)`, `{ dir, tag, hash } -> List(Str)` | R-MX15, R-PB1, R-PB7 (Q1) |
| `Bot.row` | `{ tag, hash, stdout } -> Try(Compat.Row, Str)` | R-MX17, R-AP10 (Q4, Q5) |
| `Bot.sweep` | `{ tag, work, rowed } -> Try(Compat.Sweep, [None])` | R-MX4 |
| `Bot.failure` | `{ origin, step : [Put(Str), Post(Str), PostAudit(Str), List], reply : Try({ status, body }, [NoAnswer(Str)]) } -> Fail` | R-MX18 item 13 (Q585) |
| `Bot.audit_groups` | `List(Audit.Pair) -> List({ nightly, hashes })` | R-MX13, R-MX10 (Q3) |
| `BotFlow.run!` | `Fx => I32` | R-MX1, R-MX15, R-MX17 |

New files: `bot/lib/main.roc`, `bot/lib/Bot.roc`, `bot/lib/BotFlow.roc`, `bot/main.roc`, `tests/unit/BotTest.roc`, `tests/unit/l0-9.roc` (a new L0 driver: it has the dep `bot` in its header), `tests/tools/mk-bot.sh` (makes the 6 L2 cases), `tests/commands/cases/bot/b1` to `b6`, `.github/workflows/compat-bot.yml`, `tests/tools/ciscan.py` (the new check `compatbot`).
Edits to existing files (copies in `research/slice-223-revert/before/`): `tests/commands/main.roc` (dep `bot`, `import bot.BotFlow`, the entry `bot`), `tests/tools/ciscan.py` (the function `check_compatbot` and one `CHECKS` entry).
Code agent: write `bot/lib/Bot.roc`, `bot/lib/BotFlow.roc` and `bot/main.roc` (the real `Fx` for the app: `cli/RealFx.roc` is in `cli/`, so a shared module or a copy is a code decision). Not in my scope, listed for the manager: the wiring of question Q13.

Dependency on slice 104k (Q575): `packages/records` has `Work` (`Work.Answer`, `Work.Sweep` with `time`, `Work.decode`) and `Audit` (`Audit.Pair`, `Audit.Answer`, `Audit.decode`), stubs of the 104k agent. `Bot.roc` uses `Work.Answer` and `Audit.Pair`; L0 `sweep` and `done` are typed with `Work.Answer`. Slice 223 depends on 104k for these types. The decoder tests (old expects 1 and 2) are not in `BotTest`: slice 104k has them (`WorkTest`, `AuditTest`, 8 and 7 expects), so there is no duplicate. The flow decodes with `Work.decode` and `Audit.decode`.

## The flow (my reading, for the review)

`BotFlow.run!`. The order of calls is fixed by the L2 cases (`calls.log`). Operands are the nightly tags; with none, the 7 newest nightlies of GitHub, oldest first (Q567). The exits 2, 15 and 20 stop at once; the exit 1 is given at the end (Q573). Step 6 now has the 401 renewal (Q571), the 422 second round and the chunks of 500 (Q572): see b11 to b16.

| # | Step | Rule |
| --- | --- | --- |
| 1 | `args!`, `env_all!`. Checks with no request: `TALON_REGISTRY`, `ACTIONS_ID_TOKEN_REQUEST_URL`, `ACTIONS_ID_TOKEN_REQUEST_TOKEN`, `RUNNER_TEMP`. A fault is exit 2 (b4 tests the first OIDC variable) | R-TP2, R-AP27, R-EC2 |
| 2 | For each tag, in the order of the operands: a token (`http_send! GET` of `Publish.token_request`), then `PUT /v1/toolchains/<tag>` (201 new, 200 known) | R-AP6, R-TP2 |
| 3 | `GET /v1/sweeps/<tag>` (`http_get!`, headers as the reads of `tln publish`): the work list. The bound of the sweep is its `log_size` | R-AP39, R-MX4 |
| 4 | For each `missing` hash: `GET /v1/artifacts/<hash>` (the URL of the first release), then one `spawn_all!` of `curl` jobs (limit 4), then one `spawn_all!` of probe jobs (limit 4): `env ROC_TOOLCHAIN=<tag> tln probe --json --yes <RUNNER_TEMP>/<hash>.tar.zst` | R-MX1, R-MX15, R-PB1, R-PB7, R-AP2 |
| 5 | The rows from the stdout of each probe (`Bot.row`). A probe with no row is a warning on stderr, and its hash is not rowed | R-MX17, R-P3 |
| 6 | A new token, then `POST /v1/compat` with the rows and the sweep. The sweep is in the body only when each hash of `missing` has a row (`Bot.sweep`). Retries as `tln publish` (503: `sleep!` and the same request) | R-AP10, R-MX4, R-AP34 |
| 7 | After the tags: `GET /v1/compat_hints?audit=200`. The unit pairs are grouped by nightly (`Bot.audit_groups`). For each group the steps 4 and 5 run with the tag of the group, then one token and one `POST /v1/compat` with the rows and no sweep | R-MX13, R-AP40, R-MX10 |
| 8 | The exit code: 0, or 1 when a probe gave no fact | R-P3, R-MX4 (Q8) |

| Reading | Why |
| --- | --- |
| The token is fetched just before each write (PUT, POST) | R-TP2 gives one request. A run takes up to 35 minutes (R-MX10 cost table), and an OIDC token lives some minutes, so a token from the start is stale at the first post. Q6 |
| An empty `missing` and no sweep row: the bot still sends the sweep (b2) | R-MX4: an empty set is complete, and the sweep is the claim that makes the nightly covered |
| A failed probe stops the sweep of its nightly, and the other rows go | R-MX4: the Worker writes no sweep when a member has no `bot` row (422). The rows are facts and they are right |
| The reads (R-AP39, R-AP40, R-AP2) carry no `Authorization` | They are public routes |
| The audit rows go with no sweep | R-MX4 is for the nightly of the run. R-MX13 has no sweep |

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/BotTest.roc` (driver `l0-9`) expect 1: `url` (5 routes) | R-AP6, R-AP39, R-AP40, R-AP2, R-AP10 |
| L0 | expect 2: `release_url` (a withdrawn first row is skipped, a yanked one counts, only withdrawn is `NoRelease`) | R-AP2, R-MX18 item 1 (Q566) |
| L0 | expect 3: `fetch_job`, `probe_job` | R-MX15, R-PB1, R-PB7 (Q566) |
| L0 | expect 4: `row` (4 results, target `any`, digest null) | R-MX17, R-AP10 (Q569) |
| L0 | expect 5: `row` compares the compiler by nightly id (`July` form equal, another date no row) | R-MX17, R-IK4 (Q570) |
| L0 | expect 6: `row` gives none for ok false, kind range, other hash, other compiler, empty text, not JSON | R-MX17, R-P3 (Q570) |
| L0 | expect 7: `sweep` (full, one open, empty `missing`) | R-MX4 |
| L0 | expect 8: `audit_groups` (grouping, order, smoke pair out, empty) | R-MX13, R-MX10 (Q568) |
| L0 | expect 9: `tags` (nightly tags only, oldest first, empty, not an array) | R-MX18 item 2 (Q567) |
| L0 | expect 10: `done` (typed with `Work.Answer`) | R-MX18 item 7 (Q572) |
| L0 | expect 12: `failure` (401, 403, 400, 404, 409, 422, 429, 502, 503 busy, no answer, the GitHub list; kinds, exits, texts, no token in a text) | R-MX18 item 13 (Q585) |
| L0 | expect 11: `chunks` (501, 500, 1000 with no sweep, 0 rows) | R-MX18 item 7, R-AP46 (Q572) |
| L2 | `bot/b1-sweep`: 201 PUT, 2 missing, the order of the calls, rows and sweep up to 8 | R-MX1, R-MX4, R-MX15, R-MX17, R-AP2, R-AP6, R-AP10, R-AP39, R-AP40, R-TP2, R-TP17, R-PB7 |
| L2 | `b2-sweep-only`: nothing missing, a sweep with no rows (200) | R-MX4, R-AP10, R-AP39 |
| L2 | `b3-audit`: 2 unit pairs of an older nightly, probed on that tag, rows with no sweep | R-MX13, R-MX10, R-AP40, R-AP10 |
| L2 | `b4-no-oidc`: exit 2, no request | R-TP2, R-AP27, R-EC2 |
| L2 | `b5-no-fact`: a probe exits 1, so no sweep; the other row goes; exit 1 | R-MX4, R-MX17, R-P3 |
| L2 | `b6-retry`: 503 then 200 on the post, one sleep of 2000 ms, one token | R-AP34, R-AP10 |
| L2 | `b7-no-release`: only a withdrawn release: no job, a warning, no post, exit 1 | R-MX18 item 1 (Q566) |
| L2 | `b8-find-tags`: no operand, the GitHub list, oldest first, 2 done tags, the third sweep alone | R-MX18 items 2 and 7 (Q567, Q572) |
| L2 | `b9-list-fails`: GitHub 503: exit 15, no other request | R-MX18 item 2, 8 (Q567, Q573) |
| L2 | `b10-bad-tag`: operand `latest`: exit 2, no request | R-MX18 item 2, 8 (Q567, Q573) |
| L2 | `b11-renew`: 401, a new token, 200 | R-AP34, R-MX18 item 6 (Q571) |
| L2 | `b12-renew-twice`: 401, 401: exit 20, no audit read | R-AP34, R-MX18 items 6, 8 (Q571, Q573) |
| L2 | `b13-sweep-incomplete`: 422, a second read, the new hash probed, all rows, bound 9 | R-MX9, R-MX18 item 7 (Q572) |
| L2 | `b14-sweep-incomplete-twice`: 422 twice, no third post, the next operand goes, exit 1 | R-MX9, R-MX18 items 7, 8 (Q572, Q573) |
| L2 | `b15-done`: bound at least the log size, nothing missing: no post | R-MX18 item 7 (Q572) |
| L2 | `b16-chunks`: 501 rows, 2 posts, the sweep only in the second | R-AP46, R-MX18 item 7 (Q572) |
| L2 | `b17-refused`: 403 on the post: exit 20, stop | R-MX18 item 8 (Q573) |
| L2 | `b18-no-answer`: the PUT times out 4 times: sleeps 2000, 8000, 30000, exit 15 | R-AP34, R-MX18 item 8 (Q573) |
| L2 | `b19-registry-direct`, `b20-registry-empty`: exit 2, no request | R-MX18 item 10 (Q576) |
| L2 | `b21-registry-path`: `HTTPS://Reg.Example:443/` is read as the base URL form: calls to `https://reg.example/v1/...`, the audience is that form (a path is a bad form: b19, b20 cover exit 2) | R-TP17, R-MX18 item 10 (Q576) |
| L2 | `b22-read-retry`: the work list read 503 busy, then 200, one sleep of 2000 ms | R-AP34, R-AP39, R-MX18 item 14 (Q594) |
| L2 | `b23-read-no-answer`: the work list read has no answer 4 times, sleeps 2000, 8000, 30000, exit 15 | R-AP34, R-AP39, R-MX18 item 14 (Q594) |
| L2 | `b24-read-refused`: the work list read 404: exit 20, no retry, the fault text with `get sweeps <tag>` | R-AP39, R-MX18 items 13, 14 (Q594, Q585) |
| L2 | `b25-artifact-404`: one artifact read 404: a warning for that hash, the other is rowed, no sweep, exit 1 | R-AP2, R-MX4, R-MX18 item 14 (Q595) |
| L2 | `b26-artifact-503`: the artifact read 503 four times: exit 15 at once, no probe, no post, no audit read | R-AP2, R-AP34, R-MX18 item 14 (Q594, Q595) |
| L2 | `b27-list-no-nightly`: the GitHub list has 7 releases and no nightly tag: exit 15 with `(7 releases read)` | R-MX18 item 14 (Q596) |
| L0 | `BotTest` expect 13: `Bot.failure` for the steps `get sweeps <tag>`, `get audit`, `get artifact <hash>` (15 for no answer, 429, 5xx, busy; 20 for a 4xx; no token in a text) | R-MX18 items 13, 14 (Q594) |
| Text | `tests/tools/ciscan.py compatbot` reads `compat-bot.yml`: triggers, the cron `43 4 * * *`, the input `tags`, the job `if`, 120 minutes, `concurrency` with no cancel, rights, `TALON_AUTO_INSTALL: yes`, `TALON_REGISTRY`, no secret and no token variable in the file or in the sweep step, the order of the steps | R-MX15, R-MX18 item 11, R-TP7, R-TP2, R-TP17, TW28 (Q577) |

The expected files were written by hand (`tests/tools/mk-bot.sh`). No reference code was built, so the L2 expected files have not run against code. The workflow check passes now: the workflow file is not code that a stub can hide.

## Output (proposed, R-OUT2, TW24)

The bot has no `--json`. Its output is lines on stdout, and its failures use the line of `Fail` (`tln: error[<kind>]: <text>`).

| Text | Form |
| --- | --- |
| PUT | `put <tag>: new` (201), `put <tag>: known` (200) |
| Work | `sweep <tag>: <n> of <members> members to probe` |
| Probe | `probe <hash> on <tag>: <pass, fail, hang or crash>` |
| Post | `posted <tag>: <n> rows, sweep up to <bound>` or `<n> rows, no sweep` (`1 row`); the audit: `posted audit <tag>: <n> rows` |
| Audit | `audit: <n> pairs` |
| Done, 422 | `sweep <tag>: done`; `sweep <tag>: not complete (422), reading the work list again`; the count in `sweep <tag>: <n> of <members> members to probe` is the hashes without a row now |
| Warnings, stops | `warning: no fact for <hash> on <tag>: the artifact has no release that is not withdrawn`; `warning: no sweep for <tag>: the registry answered 422 sweep-incomplete after 2 sweep requests` and `tln: error[internal]: no sweep for <tag>`; `'<operand>' is not a nightly tag. Use nightly-<date>-<sha>.` (2); `the list of roc-lang/nightlies answered <status>. Try again later.` (15); the texts of `Bot.failure` (item 13 of R-MX18: 20 for a 4xx, 15 for no answer, 429, 5xx and the GitHub list); `the compat bot needs a registry, and TALON_REGISTRY is direct` or `is not set or is empty` (2) |
| No fact | stderr `warning: no fact for <hash> on <tag>: tln probe exited with <code>`, and at the end `tln: error[internal]: <n> probe gave no fact, so there is no sweep for <tag>` (exit 1) |
| No OIDC | `tln: error[usage]: the compat bot needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.` (exit 2) |

## Out of scope

| Item | Why |
| --- | --- |
| Smoke builds (R-MX10) | Q568: `tln` has no command for one |
| The range search of each new release (R-MX1 sentence 3, R-PB3) | Q574: a later slice |
| A real run on GitHub, a real token, the real Worker | Safety. L4 and slice 225 |
| The Worker side of the bot routes | W2 (slices 106 to 115), done |

## Questions (stop until answered)

The cases pin a reading where the table says so. A reading is not a decision: it is the smallest form that lets a test run. The part of the code that a question touches waits for the answer.

| # | Question | Why it is open | What is not tested or is a reading | Answer and test change |
| --- | --- | --- | --- | --- |
| Q1 | How does the bot run one unit probe of a hash on a nightly? Three facts are missing: (a) the archive: `tln probe` takes a header alias, a `<hash>.tar.zst` path or the project file (R-PB1), and the bot has only a hash (from `missing`); (b) the compiler: `tln probe` has no flag for it, and `Fx.spawn_all!` has no `env` member; (c) the consent for the compiler downloads (R-NI4, R-DL1) in a job | R-MX15 says "tln probe ... tln downloads each compiler that a probe needs" and R-MX17 says "one run for each work item", nothing more | Reading: the URL of the first release of `GET /v1/artifacts/<hash>` (R-AP2), a `curl -fsSL --output <RUNNER_TEMP>/<hash>.tar.zst <url>` job, then `env ROC_TOOLCHAIN=<tag> tln probe --json --yes <path>` (R-SO2 rank 2), both in `spawn_all!` batches of 4. Pinned in L0 `fetch_job`, `probe_job` and each `spawn_all` line of b1, b3, b5 | Answered (Q566, R-MX18 item 1): keep. Adds: the URL is the first release of R-AP2 with `withdrawn` null; no release or a failed `curl`: no row, a warning, no sweep, exit 1. Test change: new L2 `b7-no-release` (the answer has only a withdrawn release: no `curl`, no probe, warning, exit 1); L0 `release_url` gets a case with a withdrawn first row; the job env of the workflow has `TALON_AUTO_INSTALL: yes` |
| Q2 | Which nightlies does a run sweep? R-MX1 says "for each new nightly". How does the bot find the new tags (the list of `roc-lang/nightlies` against `GET /v1/toolchains`?), how many, and what is "new" when a runner keeps no state (R-MX7 says "the largest log index of its last run")? Is a run with no tag a usage fault? | Not given | Reading: the operands of `bot` are the tags (the workflow input `tags` fills them). No operand is untested | Answered (Q567, item 2): operands win; with none the bot reads the newest 7 nightly tags of GitHub, no state. Test change: new L0 `Bot.tags : Str -> Try(List(Str), [BadJson(Str)])` (7 releases, a non-nightly tag dropped, oldest first) and `Bot.done : Work -> Bool`; new L2 `b8-find-tags` (no operand: the GitHub list, 3 tags, one done: `PUT` and one read, no probe), `b9-list-fails` (a 503 of GitHub: exit 15, no other request), `b10-bad-tag` (an operand that is not a nightly: exit 2). The workflow passes `${{ inputs.tags }}` (`ciscan.py`) |
| Q3 | Smoke builds (R-MX10) and the audit pairs of a platform target: how does the bot run a smoke build with `tln`? The `data` of `tln probe --json` for a unit check has no build field, and `Project` data is for the project file | Not given | Not tested. `Bot.audit_groups` leaves a pair of another target out (L0): a reading, no message is printed | Answered (Q568, item 3): not run; a CLI question (`tln probe` has no smoke result): route to the CLI design agent. Keep the L0 `audit_groups` case (a smoke pair out). Test change: none |
| Q4 | The `error_digest` of a row: `data` has `modules`, no digest (R-AP58, Design Q394) | R-AP10 wants the member (text or null) | Reading: `null` for each result, as `tln publish` (Design Q509). Pinned in L0 `row` and each body of the L2 cases | Answered (Q569): keep `null`. No test change |
| Q5 | A probe whose `data.compiler` is not the tag, or whose `data.hash` is not the hash | A row of another compiler would be a wrong fact | Reading: no row (`Bot.row` is `Err`), as for a probe with no fact | Answered (Q570): no row; the compiler is compared by nightly id. Test change: L0 `row` expect: `data.compiler` `nightly-2026-July-31-123c5d7` for the tag `nightly-2026-07-31-123c5d7` gives a row; a different date gives none |
| Q6 | The token: one for each write (reading), or one for the run? How long does the GitHub OIDC token live? | R-TP2 describes one request for `tln publish` | Reading: a new `http_send! GET` before each PUT and each POST; a 401 renewal (R-AP34 `Renew`) is not tested | Answered (Q571): one token for each write; a 401 gets one new token. Test change: new L2 `b11-renew` (401 on the post, a new token, 200) and `b12-renew-twice` (401, 401: exit 20) |
| Q7 | After 422 `sweep-incomplete` (R-MX9: "the bot reads R-AP39 for the work list"): one more round, how many rounds, and what is sent after a yank? Also: a work list with a sweep row whose bound is at least `log_size` and no `missing`: send, or skip? | R-MX9, R-MX4 | Not tested. b2 sends the sweep with no row for `sweep: null` | Answered (Q572): one more round after a 422, at most 2 sweep requests; done = no request; chunks of 500. Test change: new L0 `Bot.chunks` (500 rows, 501 rows: the sweep in the last), new L2 `b13-sweep-incomplete` (422, a second read, the new `missing` probed, a second post with all rows), `b14-sweep-incomplete-twice` (422 twice: exit 1, no third post, the other tag goes on), `b15-done` (sweep bound at least `log_size`, no `missing`: no token, no post, `sweep <tag>: done`), `b16-chunks` (501 rows: 2 posts, the sweep only in the second) |
| Q8 | The exit codes and the texts of a bot failure: 1 for a probe with no fact, 2 for usage (reading: the line of `Fail`, prefix `tln:`), 15 for no answer, 20 for a refusal (as `tln publish`)? The workflow turns each non-zero code into a red run | CLI 3 has the codes of `tln` only | b4 (2) and b5 (1) pin the reading. 15 and 20 are not tested | Answered (Q573, item 8): keep; 2, 15, 20 stop at once and 1 is reported at the end. Test change: new L2 `b17-refused` (403 on the post: exit 20, no more request), `b18-no-answer` (the `PUT` gets no answer 4 times: exit 15, the sleeps 2000, 8000, 30000); b4 and b5 stay |
| Q9 | The range search of each new release (R-MX1, R-MX7, R-PB3): `tln probe --range --json` gives the 2 ends (`data.range`), not a row for each nightly that it probed. The rows are in `compat.db`, which R-MX17 refuses | R-MX17 | Not tested | Answered (Q574, item 9): a later slice (new plan row: the range search); `data.range.facts` and the `after` rule are decided. Test change: none in 223 |
| Q10 | The types of R-AP39 and R-AP40: `records` says that they "come with the slice of the bot script" (Registry R-AP73), and R-MX17 says the bot uses `records`. The test agent may not edit `packages/` | R-AP73 | Reading: `Bot.Work`, `Bot.Pair`, `Bot.work` and `Bot.pairs` in `bot/lib/Bot.roc`. If the answer is `records`, the L0 expects 1 and 2 move to `packages/records/tests` | Answered (Q575, Q575 plan row 104k): the types are in `packages/records` (`Work`, `Audit`). Test change: L0 expects 1 and 2 of `BotTest` move to the records slice 104k (the test agent of that slice); `Bot.work` and `Bot.pairs` leave the stubs; `BotTest` imports `records.Work`, `records.Audit` for the other expects |
| Q11 | The registry of the bot: only `TALON_REGISTRY` (no `config.toml`, no flag, no default)? Its text is the base URL form (R-RG7) and the audience (R-TP17) | Not given | Reading: the variable, used as it is (the form is the job of the variable, not of the bot). `direct` or an empty value is exit 2: not tested | Answered (Q576, item 10): `TALON_REGISTRY` only, read with R-RG7; the audience is the origin form. Test change: new L2 `b19-registry-direct` (`direct`: exit 2, no request), `b20-registry-empty` (empty: exit 2), `b21-registry-path` (`https://reg.example/api/`: the token request has `audience=https%3A%2F%2Freg.example`, the calls go to `https://reg.example/api/v1/...`) |
| Q12 | The workflow details: the time of the `schedule` (`43 4 * * *`), `vars.TALON_REGISTRY`, a job of 120 minutes, `concurrency` with no cancel, the build of `tln` and `bot` from the repository (not a release), `TALON_AUTO_INSTALL: yes`, `probe.max-toolchains` | R-MX15 gives the triggers, the runner and the 2 Worker settings only | `ciscan.py compatbot` checks the triggers, the rights, the steps and the variable, not the cron time | Answered (Q577, item 11): the details are as listed. Test change: `ciscan.py compatbot` also checks the cron (`43 4 * * *`), the input `tags`, the job `if`, `timeout-minutes: 120`, `concurrency` with `cancel-in-progress: false`, `TALON_AUTO_INSTALL: yes`, and that `GITHUB_TOKEN` and `secrets.` are absent |
| Q13 | Wiring that I may not do: `scripts/test.sh` lists the apps for `check` (`bot/main.roc` is not there) and `step_fmt` formats `cli tests packages` only (`bot/` is not there; I ran `roc fmt` on it by hand); `tests/selftest.sh` has no row for `ciscan.py compatbot`; `tests/selftest.sh` and the L0 driver comment say "8 drivers" and there are 9 now | Not my files | The manager adds the wiring | Answered (Q578, item 12): the wiring is consistent with TESTING.md; the main session makes the edits. `bot/lib` needs `cli/lib` first in the check order. Test change: none |

### Round 2: new questions (TW17)

| # | Question | Why it is open | Reading in the tests |
| --- | --- | --- | --- |
| Q14 | Four forms that Q566 to Q573 do not give: (a) the GitHub list of Q567: "one request" (no retry) or the retries of R-AP34; (b) a nightly with no row and no sweep (every hash failed): no post at all, or a post with `rows: []`; (c) a batch with no job (no release for any hash): a `spawn_all!` with an empty list, or no call; (d) the exact lines of the new outputs | Q567 says one request and Q573 says "after the retries of R-AP34" for 15; Q572 gives chunks only for 1 or more rows | (a) one request, no retry (b9). (b) no post, no token (b7: `Bot.chunks` of no rows and no sweep is `[]`). (c) no call (b7). (d) proposals in the Output table. The 3 readings are pinned; each changes one case if the answer differs Answered (Q582 to Q585, R-MX18 items 2, 7, 1, 13): (a), (b), (c) confirmed as read (b9, b7, b7 stay). (d) The bot has its own texts (`Bot.failure`), not `Registry.refuse`. Test change: the failure lines of the Output table become the texts of item 13 in the cases that fail a write or the list (b9, b17, b18, and any case with a `rejected` or `network` line); new L0 `Bot.failure` expects (401/403 with the OIDC text, 404/422 with the step text, 503 after 4 requests, the GitHub list), each with the real `<type>` and `<detail>` of a problem body and a token text that is not in the line |

Round 3: Q14 is answered as Q582 to Q585 (R-MX18 items 1, 2, 7, 13). (a), (b), (c) keep the readings (b9, b7). (d): the failure lines of b9, b12, b17 and b18 are the texts of `Bot.failure`, and L0 expect 12 tests each case of item 13. Reading: the second 401 of b12 (Q571) is the 401 text of item 13 (the OIDC token words), because item 13 has no separate "new token" text.

## Code decisions (code agent)

| Item | Choice |
| --- | --- |
| Real `Fx` for `bot/main.roc` | A package header `cli/real.roc` (`package [RealFx] { http, lib, pf: platform ... }`). Its source root is `cli/`, so it exposes `RealFx` and the files it imports (`RealBase`, `RealDb`, `RealFiles`, `RealJobs`, `RealLocks`) stay once in `cli/`. `bot/main.roc` has the dep `real: "../cli/real.roc"` and `import real.RealFx`. A symlink does not work (roc refuses an import that resolves outside the app root), and a copy is a second copy. `cli/main.roc` is not changed. |
| Reuse | `Publish.token_request`, `Publish.token`, `Publish.next` (R-AP34), `Publish.env_var`, `Registry.headers`, `Registry.base` (R-RG7), `Registry.problem`, `Registry.refuse` and `Registry.no_answer` (reads only), `Nightlies.parts` and `Nightlies.same_nightly` (R-IK4), `Net.headers` (GitHub list), `Fail`, `Compat.encode_post`, `Work.decode`, `Audit.decode`. `Publish.oidc` is not reused: its text says `tln publish` (b4 pins the text `the compat bot needs an OIDC token`). `bot/lib` imports `cli/lib` as the dep `lib`: no layout problem. |
| Readings not pinned by a test | A 422 of the `PUT` skips the tag with a warning on stderr and no exit change (R-MX18 item 2). A read of the registry (work list, audit) that fails uses `Registry.refuse` or `Registry.no_answer` (no retry, as b6 says). A `curl` job that fails is a no fact: `warning: no fact for <hash> on <tag>: curl exited with <n>`. The list of GitHub with no nightly tag is exit 15. A bad `TALON_REGISTRY` text is exit 2. An audit group with a no-fact probe ends the run with exit 1 (`<n> probes gave no fact on <nightly>`). |

## Disputes (from the code agent)

| # | Case | Dispute | Rule |
| --- | --- | --- | --- |
| D1 | `bot/b21-registry-path` | The case sets `TALON_REGISTRY=https://reg.example/api/` and expects exit 0 with the calls under `https://reg.example/api/v1/...` and the audience `https://reg.example`. R-RG7 row 2 says a registry URL has no path except one `/` at the end, and R-MX18 item 10 says `TALON_REGISTRY` is read with R-RG7 and a bad value is exit 2. `Registry.base` gives `Err(BadRegistry)` for this text, so the bot gives exit 2 (`the compat bot needs a registry, and TALON_REGISTRY is https://reg.example/api/, and that is not a base URL ...`) and no request. Diff: expected exit 0 and 8 calls after `env_all`; actual exit 2 and none. Either the case should expect exit 2 (a path is not valid), or the design must allow a path in a registry URL (then R-RG7 row 2, R-TP17 and `Registry.base` change: a design question, TW17). The code follows the rule. | R-RG7 rows 2 and 6, R-MX18 item 10, R-TP17 |

D2 (accepted, 2026-11-03): `Bot.failure` takes a step type with 7 tags, and Roc does not accept a closed union with fewer tags as its argument. The test agent widened the `got` annotation of `BotTest` to the 7 tags and moved the read-step expect into `BotTest` (expect 13). `BotReadTest.roc` and the driver `l0-10.roc` are deleted: the bot has one L0 driver, `l0-9`.

D1 result (accepted, 2026-11-03): the code is right. R-RG7 row 2 allows no path except one `/`, so `https://reg.example/api/` is a bad form: exit 2, no request (Q576, R-RG7 row 6). The test agent changed `b21-registry-path` to `TALON_REGISTRY=HTTPS://Reg.Example:443/` (row 3 base URL form): calls to `https://reg.example/v1/...`, audience `https%3A%2F%2Freg.example`, exit 0. The path run is not added: b19 and b20 cover exit 2 for a bad value.

## Verify results

Code agent, 2026-11-03.

| Step | Result |
| --- | --- |
| `scripts/test.sh check fmt selftest` | pass (`bot/main.roc`, `bot/lib/main.roc`, `cli/main.roc` build) |
| L0 `tests/unit/l0-9.roc` (`BotTest`) | 12 of 12 pass. The l0 step fails only on `ProbesmokeTest` (`todo: slice 218b`, not mine) |
| L2 `bot/b1` to `b20` | pass |
| L2 `bot/b21-registry-path` | D1 settled: the case is changed to the origin form (see Disputes) |
| L2 other | 499 passed, 8 failed: `probe/sm1` to `sm6` (`todo: slice 218b`) and `probe/ps7` (the shared test binary `.work/bin/l2` was gone while another session built it; it passes alone) |
| `python3 tests/tools/ciscan.py compatbot` | pass, `.github/` not edited |
| L3 (`JOBS=1`) | pass |

Changed code files and their sha256: `research/slice-223-revert/code-final.sha256`. Copies before: `research/slice-223-revert/code-before/` (`Bot.roc`, `BotFlow.roc`, `main.roc` of `bot/`).

## Design answers G-C223 to G-C225 (2026-11-03)

| Item | Answer | Test change |
| --- | --- | --- |
| G-C223, Q594 | The bot reads get the retries of R-AP34 (2, 8, 30 s, `Retry-After` at most 60 s, also after 503 `busy`). The texts are `Bot.failure` with the steps `get sweeps <tag>`, `get audit`, `get artifact <hash>`, not `Registry.refuse` | New L2 `b22-read-retry` (the work list: 503, then 200: one `sleep!` of 2000 ms, the run goes on), `b23-read-no-answer` (R-AP39 no answer 4 times: sleeps 2000, 8000, 30000, exit 15, the line `did not take the get sweeps <tag> after 4 requests`), `b24-read-refused` (R-AP39 404: exit 20, the `rejected` text of Q585 with the step). New L0 `Bot.failure` expects for the 3 read steps |
| G-C224, Q595 | A 4xx other than 429 on the R-AP2 read is a warning for that hash, no row, exit 1 at the end. No answer, 429, 5xx, busy after the retries: exit 15 at once | New L2 `b25-artifact-404` (one of 2 hashes: the warning, the other hash probed and rowed, no sweep, exit 1); `b26-artifact-503` (R-AP2 503 four times: exit 15, no probe, no post) |
| G-C225, Q596 | The GitHub list of 200 with no nightly tag is exit 15 with the line of R-MX18 item 14. Not exit 0 | `b9-list-fails` stays; new L2 `b27-list-no-nightly` (a list of 7 releases with tags `v1.0` and so on: exit 15, no other request) |


## Code round 2 (Q594 to Q596)

| Item | Result |
| --- | --- |
| Reads | `BotFlow.get!` is one loop over `Publish.next` (`renewed` true, so a 401 stops): the retries of R-AP34 for the work list, the audit and the artifact. The ends are `Bot.failure` with the steps `GetSweeps`, `GetAudit`, `GetArtifact` (`Registry.refuse` and `Registry.no_answer` are not used). |
| Artifact read (Q595) | A 4xx other than 429 is `warning: no fact for <hash> on <tag>: the registry did not give the artifact (<status>)`, exit 1 at the end. Other ends stop the run (15, or 20 for a 4xx the list does not take). |
| GitHub list (Q596) | No nightly tag: exit 15, the line of R-MX18 item 14 with `(<n> releases read)`. |
| L2 | `bot/` b1 to b27: 27 passed. |
| L0 | `l0-9` and `l0-10` do not compile: see dispute D2. With the `got` annotation of both files widened to the 7-tag step type (a copy in `research/`, removed), all 13 expects pass. |
| `check fmt` | pass |

### Dispute D2: the `got` annotation of `BotTest` and `BotReadTest`

`Bot.failure` has the step type `[Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)]`, as the slice says. Roc does not accept a closed union with fewer tags as the argument (I tried an open `..others` type, an open union that lists only some tags, and `where [step.to_inspect ...]`; none lets one function take both a 4-tag and a 3-tag closed union and print the text of each tag). The two tests annotate `got` with a part of the tags, so neither compiles:

- `tests/unit/BotTest.roc` line 126: `got : [Put(Str), Post(Str), PostAudit(Str), List], Try(...)` must be `got : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)], Try(...)`.
- `tests/unit/BotReadTest.roc` line 21: `got : [GetSweeps(Str), GetAudit, GetArtifact(Str)], Try(...)` must be the same 7-tag type.

Rule: R-MX18 items 13 and 14 (one `Bot.failure`). With those two edits (or no annotation) both drivers pass.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-223-revert/code-final.sha256` | 4 files OK (`bot/lib/Bot.roc`, `bot/lib/BotFlow.roc`, `bot/main.roc`, `cli/real.roc`) |
| `todo: slice 223` | none |
| Expected exits read (27 cases) | 0: b1, b2, b3, b6, b8, b11, b13, b15, b16, b21, b22. 1: b5, b7, b14, b25. 2: b4, b10, b19, b20. 15: b9, b18, b23, b26, b27. 20: b12, b17, b24. Each is the rule of its run (Q566 to Q596) |
| Disputes | D1 (b21 had a path, R-RG7 row 2): accepted, b21 tests the origin form. D2 (the step type of `Bot.failure`): accepted, the annotations are wider, `BotReadTest` and `l0-10` are merged into `BotTest` (expect 13). The D2 text of the code agent above still names `BotReadTest` and `l0-10`: they are gone |
| Questions | G-C196 to G-C209 (Q566 to Q585), G-C223 to G-C225 (Q594 to Q596): all answered |
| Mutations (private builds in a mirror, deleted) | 5 of 5 caught: chunks of 501 (b16); a third sweep try (b14); a 5xx on the artifact read as a warning (b26); no retry on reads (b22, b23); a 429 as a refusal (BotTest, 2 expects) |
| `check`, `fmt`, `selftest` | pass (selftest 22.2 s, over the 20 s budget: warning) |
| L0 | pass |
| L2 | 515 passed, 0 failed |
| L3 (`JOBS=1`) | pass (81.9 s, over the 60 s budget: warning) |
| `ciscan.py compatbot .` | exit 0 |
| The workflow | Local file only. Not pushed, not run |
| Later slices | The bot uses `tln probe --smoke` (218b) for R-MX10 and the platform pairs of R-MX13, and the range facts (217b) for the range search (Q574): a later slice |

## Human review (the user, 2026-11-06)

The user accepted all the proposed output texts and `--json` fields of this slice (TW24, R-OUT2). They are final.
