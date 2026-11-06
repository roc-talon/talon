# 217 Probe share

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 217 of `PLAN-P2-CLI.md`. `tln probe <alias> --share`: send the real facts of the target hash from `compat.db` to `POST /v1/compat` as user hints, once, also with sharing off, `CI` or `DO_NOT_TRACK`, with the filters of R-SH3 except filter 1. The privacy guard first for a `github.com` entry. Exit 2: `direct`, no operand, a bundle file. Not in this slice: how the command gets the registry answers for filters 4, 5 and 7, and the join with the probe itself (questions Q1 to Q3).

## Rules

R-PB6, R-CM8 (`--share`), R-EC2 (the R-PB6 cases). Named also: R-SH2 (the flag is the consent), R-SH3 (filters 2 to 7), R-SH5, R-SH6, R-SH13 (id, totals), R-RG4, R-RG6 (the guard), R-AP10, R-CT1, R-CT2 (the request), R-E6, R-J7 (the answers), R-DA9 (20 s), R-TF3 (a newer `compat.db`, a `share.json` that does not parse), R-FL5 and R-RG1 (the registry flag), R-OUT2, R-OUT4.
Design: Resolution 4 (R-PB6); CLI 1 (R-SH2 to R-SH6, R-SH13, R-RG4 to R-RG6), CLI 3 (R-E6, R-EC2); Registry 4 (R-AP10, limits table: "`tln probe --share` sends the facts of one hash in requests of at most 500 rows each"). Closed slices read: 203, 215, 216, 213, 220, 037.

## Reuse (no second copy)

| Need | Reused | New |
| --- | --- | --- |
| The 6 filters and the 5 conditions | `ShareQueue.admit` with `Share.state` forced on (`share` true, a registry URL, no `--offline`, empty `env`) and `origin: Probed` (filter 1 is the one that does not apply) | `ProbeShare.rows` maps a stored fact to a `ShareQueue.Fact`, sorts, collects the reasons |
| The request | `QueueSend.request` (`timeout_s` 20, R-DA9), `QueueSend.batch_rows` (500) | `ProbeShare.batches`: chunks of 500, no cap on the number of requests |
| The totals | `QueueSend.totals`, `ShareFlow.totals_write!`, `ShareFlow.ensure_doc!`, `Clock.now!` | None |
| The failures | `Registry.refuse` (method `Post`), `Registry.no_answer`, `Db.on_err`, `ShareJson.read`, `PrivacyGuard.check!` | `ProbeShare.answer` (which answer is which failure) |
| The facts of a hash | `Db.Query` `Facts(keys)` needs keys | `Db.Query` `FactsOf(hash)`: all rows of one hash (new, like `QueueRows` in 216) |

## Public signatures (stubs, `crash "todo: slice 217"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `Db.Query` `FactsOf(Str)` | all rows of `facts` with this hash, each nightly, target and closure, answer `Facts(rows)` in any order. No file made (missing file, `user_version` 0: `Facts([])`). The fake log word is `facts_of=<hash>`. | R-PB6, R-TF2, R-TF3 |
| `ProbeShare.rows` | `ProbeShare.Input -> { rows : List(Db.Queued), kept_back : List({ nightly, target, why : ShareQueue.Why }) }` | R-PB6, R-SH3 |
| `ProbeShare.batches` | `List(Db.Queued) -> List(List(Db.Queued))` | R-PB6, R-AP10 |
| `ProbeShare.answer` | `{ origin, version, count, reply : QueueSend.Reply } -> Try({ sent, counted, first, skipped }, Fail)` | R-E6, R-AP51 |
| `ProbeShare.direct`, `no_hash`, `bundle` | `{} -> Fail`, kind `Usage` (exit 2) | R-PB6, R-EC2, R-SH10 |
| `ProbeShare.lines`, `data` | the stdout lines and the `data` (proposal) | R-OUT2, R-OUT4 |
| `ProbeShareFlow.send!` | `Fx, ProbeShareFlow.Input => Try({ shared, kept_back }, Fail)` | R-PB6 |
| `ProbeCmd.Plan` | gets the member `share : Bool` (done, not a stub: the plumbing of the flag) | R-CM8 |

Edits to existing files (copies in `research/slice-217-revert/before/`): `cli/lib/Db.roc` (1 variant), `cli/RealDb.roc` (`crash "todo: slice 217"` for `FactsOf`, the empty-case arms), `cli/lib/main.roc` (2 exposes), `cli/lib/ProbeCmd.roc` (the `share` member of `Plan`), `cli/fxprobe.roc` (the call `db-query ... facts-of <hash>`, a test tool, as in 215 and 216), `tests/commands/FakeDb.roc` (the fake of `FactsOf`, done, not a stub), `tests/commands/main.roc` (the entry `probe-share`), `tests/unit/l0-7.roc` (1 import), `tests/unit/ProbecmdTest.roc` (the `--share` rows change), `tests/commands/cases/probe/pc1-targets` (run 12 changes). New: `cli/lib/ProbeShare.roc`, `cli/lib/ProbeShareFlow.roc`, `tests/unit/ProbeshareTest.roc`, `tests/commands/L2ProbeShare.roc`, `tests/tools/mk-probe-share.sh` (makes the 7 L2 cases), `tests/scenarios/fx/ps1-real-fx-facts-of`.
The code agent must also do (no test can reach it before the code): `Opts.reads_registry` gets `["probe"]` when `--share` is set (R-FL5: a registry flag is not refused); the wiring in `ProbeFlow.run!`; `ProbeCmd.read` drops the early exit of `--share` (the stub still has it, so the L0 rows fail by a wrong value).
No file of the 206e2b agent was edited.

## The flow (my reading, for the review)

`ProbeCmd.read` (pure), in this order: `Opts.read`; 2 operands or more; `--share` with no operand (`ProbeShare.no_hash`, exit 2); `--share` with a bundle file (`ProbeShare.bundle`, exit 2); `--range` with no operand. `--share` and `--range` with an alias are both allowed (the syntax of R-CM8 has both flags).

`ProbeFlow.run!`, with `--share`, right after `read` and before any project read (R-PB6: "with `direct`, Talon stops"): `env_all`, `read_files config.toml`, then `Net.registry` with the flag, the environment and the config. `Direct`: `ProbeShare.direct` (exit 2, `--json`: the error envelope). The calls of this stop are those of `tln share logout` (slice 220): `args`, `env_all`, `tty` (the first-run prompt, none with `--json`), `env_all`, `read_files config.toml`.

`ProbeShareFlow.send!` (the L2 cases `probe/ps2` to `probe/ps7`), calls in order:

| Step | Call | Rule |
| --- | --- | --- |
| 1 | `PrivacyGuard.check!` with the source `Url(<release URL of the header entry>)`; no source: no call. A failure ends the command before any read of `compat.db` and before any registry request. | R-PB6, R-RG4, R-RG6 |
| 2 | `db_query!` `FactsOf(hash)`. `Err(TooNew)`: exit 19 (`Db.on_err`), no request. | R-TF3 |
| 3 | `ProbeShare.rows`, `ProbeShare.batches`. | R-PB6, R-SH3 |
| 4 | `read_files!` of `share.json`. A file that does not parse: exit 19, no request. A missing file: made with a new id (the write of `tln share on`). Only with at least one batch. | R-SH5, R-SH13 |
| 5 | Each batch, in order: `http_send!` `POST <origin>/v1/compat` (`User-Agent`, `Content-Type`, `Talon-Contributor`, no `Authorization`, `timeout_s` 20, no `clock` call before it: no budget of 5 s), `ProbeShare.answer`. The first failure ends the loop. No `sleep`, no retry (R-AP34). | R-AP10, R-E6 |
| 6 | At least one request got a 200 or 201: one `clock!`, then the totals write, also when a later request failed. | R-SH6, R-SH13 |
| 7 | `Ok(shared)`, or the failure of step 5. | R-E6 |

`ProbeShare.rows`: the stored facts of the hash, sorted by nightly (text order), then target, then closure. Each is a `ShareQueue.Fact` with `origin: Probed`, `probe: Unit` for an empty `closure` and `AppBuild` for a build row, `compiler.recorded` from the list that the caller gives, `machine_error: false`. `admit` decides (the first false filter is the reason). A hang is `Result`; a pass, a fail and a crash go.

What the caller gives (`recorded`, `answers`, `headers`, `domain`) is not decided here: Q1, Q2.

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ProbeshareTest.roc` (driver `l0-7`) expect 1: old facts go (filter 1 does not apply), sorted | R-PB6, R-SH3 |
| L0 | expect 2 to 8: `rows` for a hang (6), a build row (2), an unrecorded nightly and a release (3), no answer and a release-only hash with and without a header kind (4, 7), a bot run (5), the target of a package and of a platform (7), a fact of another hash, no fact | R-PB6, R-SH3 |
| L0 | expect 9: `batches` (0, 1, 500, 501, 1001: 3 requests) | R-PB6, R-AP10 |
| L0 | expect 10, 11: `answer` (200, 201, a body that does not decode; 400, 413, 403, 404, 422, 429, 503, 500, 204, 302, no problem details, timeout, failed) | R-E6, R-AP51 |
| L0 | expect 12: the 3 usage texts | R-PB6, R-SH10, R-EC2 |
| L0 | expect 13 to 15: `lines`, `data` | R-OUT2, R-OUT4 |
| L0 | `tests/unit/ProbecmdTest.roc`: `--share` with no operand, a bundle file, 2 operands, with `--range`, with a registry flag (changed rows) | R-PB6, R-CM8, R-FL5 |
| L2 | `probe/ps1-share-usage` (whole command): direct (default, `--registry direct`, `--json`), no operand, a bundle file | R-PB6, R-EC2, R-SH10, R-FL5, R-J5 |
| L2 | `ps2-share-send`: 2 old facts go in one request, with sharing unset, `CI=true`, `DO_NOT_TRACK=1`; kept back: an unrecorded nightly, a hang, a build row; a fact of another hash; totals | R-PB6, R-SH2, R-SH3, R-SH5, R-SH6, R-AP10, R-CT1, R-CT2, R-EV26, R-DA9 |
| L2 | `ps3-share-guard`: the guard calls come first; a private repository is exit 2 with no read of `compat.db`; a URL of another host has no guard call | R-PB6, R-RG4 to R-RG6, R-EC2 |
| L2 | `ps4-share-answers`: 429, 503 busy, timeout, failed, 400, 422: exits 15, 15, 15, 15, 1, 20; one request each | R-E6, R-AP34 |
| L2 | `ps5-share-batches`: 501 facts, 2 requests; the second fails (503): exit 15, the totals of the first are written | R-AP10, R-SH6, R-SH13, R-E6 |
| L2 | `ps6-share-no-share-json`: the file is made, the request has the new id | R-SH5, R-SH13 |
| L2 | `ps7-share-file-faults`: a newer `compat.db`, a `share.json` that does not parse: exit 19, no request | R-TF3, R-SH13 |
| L3 | `tests/scenarios/fx/ps1-real-fx-facts-of` (`fxprobe`): `FactsOf` of the real `Fx`: no file made, 4 rows of one hash and none of another, `user_version` 0, a newer file (`TooNew`, same bytes) | R-PB6, R-TF2, R-TF3, TW4 |

The L2 cases use the entry `probe-share` (`ProbeShareFlow.send!` with the answers built from words, because of Q1), except `ps1` (the whole command). The expected files were written by hand (`tests/tools/mk-probe-share.sh`).

## Output (proposed, R-OUT2, TW24)

| Text | Form |
| --- | --- |
| The send | `shared <n> fact(s) of <label>: <counted> counted, <skipped> skipped by the registry` (`fact` for 1) |
| A fact kept back | `  not shared: <nightly> <target>: <reason>`. Reasons: `not a unit check`, `the compiler has no recorded sha256 or is not a nightly`, `the hash is not in an answer of the registry`, `the registry has a bot result for it`, `a hang, or a machine error`, `the registry does not take this target for the kind of the hash` |
| `data` | `{"share":{"requests","sent","counted","first","skipped","not_shared":[{"nightly","target","reason"}]}}`, the reason words `kind`, `compiler`, `not-in-answer`, `bot-row`, `result`, `target` |
| `--share` with no operand | `tln probe --share needs a header alias: the project file has no hash` |
| `--share` with a bundle file | `tln probe --share needs a header alias: a bundle file can be a hash before its release` |
| `direct` | `tln probe --share needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` (as `ShareAccount.direct_text`) |
| Failures of the answer | the texts of `Registry.refuse`, `Registry.no_answer` (`no answer in 20 s`) |
| Order of rows and lines | nightly, target, closure, in text order |

## Out of scope

| Item | Why |
| --- | --- |
| The registry answers of the command and the wiring in `ProbeFlow` | Q1 to Q3 |
| `--offline` with `--share` | Q4 |
| No row to send | Q5 |
| Smoke facts (table `smoke`) | Slice 218 |
| The queue send at the end of the command, and the queue entries of the probe itself | Slice 206e4 (R-SH4: the command sent a registry request) |

## Questions (stop until answered)

Manager (2026-11-03): Q1 to Q7 went to TalonRegistry as G-C125 to G-C131 (in this order). The code step waits for the answers.

| # | Question | Why it is open | What is not tested | Answer and test change |
| --- | --- | --- | --- | --- |
| Q1 | Where do the registry answers come from in `probe --share`? Filter 4 needs the hash in an answer "of this command", filter 5 needs the `bot` rows (`runs`, `nearest`), filter 7 needs the kind and `target_names` of the artifact. `GET /v1/artifacts/{hash}` (R-AP2) has the artifact and the releases but no runs. `POST /v1/closure` has the runs but needs the body of R-AP16. The probe itself has `registry: Off` today (slice 206e3 is open). | R-PB6 says "except filter 1" and names no request. | `ProbeFlow` wiring, no L2 case of the whole command with a registry | Answered (Design Q491, Resolution R-PB6): one `POST /v1/closure`, `groups` empty, `hashes` the hash, `compilers` oldest to newest nightly of the facts. Test change: L2 `probe-share` runs get one `closure` line before `compat`; a hash not in `artifacts` shares nothing; the window and the body are L0 `expect`s of the body builder |
| Q2 | What is `compiler.recorded` for a stored fact (filter 3, R-CV6)? The `pinned` key is (tag, host asset target), the fact row has no target of the compiler. Reading: the row (nightly, asset target of this machine) is in `pinned`. | The design says "recorded sha256" only. | The source of `recorded` (the L0 and L2 tests give the list) | Answered (Design Q492, CLI R-SH3 filter 3): (tag, host target) in `pinned`. Test change: none if the tests already give the list that way; an `expect` for a tag pinned for another target only (not recorded) |
| Q3 | Does `tln probe <alias> --share` probe first (R-PB2, R-PB3 with `--range`) and then send, or only send? In which order are the two outputs, and which exit code wins when the probe is exit 12 and the send fails with 15? R-PB5 (`probe --range` then `publish`) suggests: probe, then send. | R-PB6 says "sends the facts of `compat.db`" and "except filter 1 (a probe of this command)". | The join of probe and share in one run | Answered (Design Q493): probe, then send; probe lines first; the probe code wins when not 0; a failed send with probe 0 is 15. Test change: L2 runs: probe 12 and a failed send (exit 12); probe 0 and a 5xx (exit 15) |
| Q4 | `--share` with `--offline`: R-SH2 3 does not name the flag as an exception (it names `CI` and `DO_NOT_TRACK`). No request can go. Exit code and text? | Not in R-PB6. | Nothing | Answered (Design Q494): exit 15 before any work, no request. Test change: one L2 run with `--offline` (no probe line, no request); `direct` stays exit 2 |
| Q5 | No fact passes (no fact at all, or each is kept back): exit 0 with the line `shared 0 facts` and the lines of the facts kept back, or another code? R-E7 says a report with bad facts is exit 0. | Not in R-PB6. | No L2 run with 0 rows | Answered (Design Q495): no request, exit 0, `nothing to share` and the kept-back lines. Test change: one L2 run with 0 rows passing |
| Q6 | A stored fact with a `closure` digest is a build of an app or a platform: it is `AppBuild` (filter 2 stops it). A smoke build of a platform is in the table `smoke` (slice 218). Is the smoke row of a platform hash also sent by `--share`? | R-SH3 filter 2 lets a smoke build go. | Smoke rows | Answered (Design Q496): no smoke rows. Test change: an L0 or L2 `expect` that a row of the table `smoke` is not in the request |
| Q7 | A `share.json` that does not parse, or a newer `compat.db`: exit 19 here (R-TF3, R-SH13), because the silent rule of R-SH4 detail 2 is for the queue send. The totals write that fails after a 200: is it silent, as for the queue? | R-SH4 detail 2 names the queue send only. | A failed totals write | Answered (Design Q497): exit 19 before the request; one warning on stderr after a failed totals write, exit unchanged. Test change: one L2 run with a `share.json` that is read-only after the 200 (the warning, the exit) |
| Cap | The user chose the cap (Design Q498, 2026-11-03) | Added to the rules: at most 20 requests of 500 rows, one after another, a stop at the first 429, 5xx or no answer, the rest listed as not shared. Test change: an L2 case with 10,500 facts: exactly 20 requests (10,000 rows), the 500 facts past them in `not shared`, exit 15 (a send that did not finish); an L0 `expect` for the batch builder (20 batches at most, the order nightly, target) | | |
| Follow-ups | Design Q503 to Q506 | Test change: (Q503) the query is sent when a stored fact passes filters 2, 3 and 6, and not when none does (a hash with only a hang or an unrecorded compiler: no `closure` line, the filter reasons listed); (Q504) `groups` is `[]`, a hash in no `artifacts` shares nothing; (Q505) a 400 and a 422 to `compat` stop the send too (exit 1, exit 20) and list the rest as not shared; (Q506) a probe of 12 sends (exit 12 stays, also with a failed send), a probe of 1 or 15 sends nothing | | |

## Disputes (from the code agent)

| Test | Expected | Actual | Reason |
| --- | --- | --- | --- |
| L3 `tests/scenarios/probe/pc1-probe-command` (`expect/stderr` line 4) | `tln probe --share needs a registry, and this version of tln has only --registry direct` | `tln probe --share needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` | R-PB6 and `ProbeShare.direct` (ps1 pins the new text, exit 2 unchanged). The old text is the P1 stub text. The test agent must update it. |
| L2 `probe/ps11-share-nothing` | resolved (manager ruling): `ProbeShare.rows` applies the local filters 2, 3, 6 before `ShareQueue.admit` (filters 4, 5, 7), so the hang reason stays | | |

## Verify results

Red (stubs): see the report of the test agent below.

With a private reference (deleted): `roc test tests/unit/l0-7.roc` 132 of 132, L2 `probe/ps1` to `ps7` 7 of 7, L2 `probe/pc1` and `share/` 49 of 49, L3 `fx/ps1-real-fx-facts-of` passes. Revert check: `research/slice-217-revert/results.txt`, 14 mutations, each caught by L0 or L2. The expected files were written by hand, no `UPDATE=1`.

Expected exits (read): `ps1`: 2, 2, 2 (`--json`), 2, 2. `ps2`, `ps6`: 0. `ps3`: 0, 2, 0 (run 2: the private repository). `ps4`: 15, 15, 15, 15, 1, 20. `ps5`: 15 (the second request: 503 busy). `ps7`: 19, 19. The word entry prints `exit <code>`; the other runs exit 0. Each non-zero exit is the rule of its run: R-PB6 and R-EC2 (2), R-RG6 (2), R-E6 (15, 1, 20), R-TF3 (19).

## Round 2 (answers Q491 to Q498)

Signature changes (stubs, `crash "todo: slice 217"`): `ProbeShareFlow.Input` is `{ roots, net, origin, source, hash, env }` (the answers, `recorded`, `headers` and `domain` are no longer given: the flow reads them); `ProbeShareFlow.send!` gives `Try({ shared, kept_back, unsent, stop : Try(Fail, [None]) }, Fail)`; `ProbeShare.batches` gives `{ send, unsent }` with `max_requests` 20; new `ProbeShare.closure_request`, `offline`, `unfinished`; `lines` and `data` take `unsent` and print `nothing to share`. The L2 word `probe-share` no longer has `kind=`, `bot=`, `noanswer`, `recorded=` (the closure answer is the route `v1/closure.POST`, `recorded` is the `pinned` rows of the fact tags for `linux_x86_64`).

The flow of `send!` (doc of `ProbeShareFlow`): guard, `FactsOf`, `platform`, `Pinned(tag, host target)`, one closure query, `rows`, `share.json`, the batches (stop at the first failure), the totals (a failed write: one `warning:` line), `stop`. `ProbeFlow`: `share_check!` after `read` (direct 2, `--offline` 15), the probe and its lines, then `send!` and the share lines when the probe code is 0; the failure of `stop` gives the code (15), `Common.failed!`.

| Layer | Case | Checks |
| --- | --- | --- |
| L0 | `ProbeshareTest`: `batches` (cap 20, 10,500 rows: 20 batches and 500 unsent), `closure_request`, `lines` and `data` with `unsent` and `nothing to share`, `offline` and `unfinished` texts | R-PB6 (3), (4), (5), Q491, Q494, Q495, Q498 |
| L2 | `probe/ps1` run 6: `--offline` with a registry, exit 15 | R-PB6 (1), Q494 |
| L2 | `ps2` to `ps7`: now with the closure query and the `platform` and `pinned` calls; `ps2` has a nightly pinned for another target only (not recorded, Q492); `ps4` and `ps5`: the lines come first and list the fact as not sent | Q491, Q492, Q498 |
| L2 | `ps8-share-command`: the whole command with a registry (run 1 of `pc1` for the probe), then the share step, exit 0 | Q493, R-PB6 |
| L2 | `ps9-share-command-fails`: the same, the compat request gets 503: the probe line, the share lines, exit 15 (the probe was 0) | Q493 |
| L2 | `ps10-share-cap`: 10,500 facts: exactly 20 requests, 500 facts not sent, exit 15, totals of 20 requests | Q498 |
| L2 | `ps11-share-nothing`: no fact passes: no `compilers`, no compat request, `nothing to share`, exit 0 | Q495 |
| L2 | `ps12-share-totals-warning`: the totals write fails after the 201: one warning, exit 0 | Q497 |

New proposals (TW24): the cap text `tln probe --share sent 20 requests and stopped: <n> facts are not shared. Run it again to send the rest.` (exit 15); the offline text `tln probe --share needs the network: --offline sends no request`; the warning `warning: the totals of share.json are not saved: <message>`; the line `    not shared: <nightly> <target>: not sent`, data reason `not-sent`. Readings (no design text): the closure query is sent when the hash has at least one stored fact (with no `compilers` when no fact can go without the answer), so the reasons of the facts that are kept back are the filters, not "not in an answer"; no stored fact at all: no request, `nothing to share`; `headers` is empty (a hash that has only a release row in the answer shares nothing, filter 7); a failed request of any status stops the send (not only 429, 5xx, no answer); the share step runs when the probe code is 0 only (a probe with a non-zero code keeps its code and the share step does not run: Q493 says the probe code stays; whether the send still runs after an exit 12 is not tested).

Not tested: the share step after a probe of exit 12 (needs the `--range` fixtures of `probe/pc2-range`; Q493 says the code stays).

Verify results (round 2): with a private reference (deleted): L0 `l0-7` 136 of 136, L2 `probe/ps` 12 of 12, mutations in `research/slice-217-revert/results.txt`. Expected files by hand, no `UPDATE=1`. Expected exits (read): `ps1`: 2, 2, 2, 2, 2, 15. `ps2`, `ps6`, `ps11`, `ps12`: 0. `ps3`: 0, 2, 0. `ps4`: 15, 15, 15, 15, 1, 20. `ps5`: 15. `ps7`: 19, 19. `ps8`: 0. `ps9`: 15. `ps10`: 15. Each non-zero exit is its rule: R-PB6 and R-EC2 (2), R-RG6 (2), R-E6 (15, 1, 20), R-TF3 and R-SH13 (19), Q494 (15), Q498 (15 for the cap).


## Code

| File | Change |
| --- | --- |
| cli/lib/ProbeShare.roc | `rows`, `batches`, `closure_request`, `answer`, `lines`, `data`, `direct`, `no_hash`, `bundle`, `offline`, `unfinished`; private text order (bytes), reason texts and words |
| cli/lib/ProbeShareFlow.roc | `check!` (direct 2, offline 15), `send!` (guard, FactsOf, platform, Pinned, closure query, rows, share.json, batches, totals warning, stop) |
| cli/RealDb.roc | `FactsOf(hash)` arm (SELECT by hash) |
| cli/lib/ProbeCmd.roc | `read`: no early exit; `--share` with no operand or a bundle file uses `ProbeShare.no_hash` and `bundle` |
| cli/lib/Opts.roc | `reads_registry`: `["probe"]` with `--share` |
| cli/lib/ProbeFlow.roc | `share_origin!` after `read`; `Finished.share`; `finish!` runs the share step after probe exit 0 or 12 (Q506); share lines and `data` merged |

Review notes: Q503 no closure request when `closure_request.compilers` is none (answers empty). Q505 any failed POST stops. `domain` for filter 5 is the nightlies of the facts with `published_at` 0 (no source in the design). A busy or failed `compat.db` read gives a warning and no facts (the design gives no rule). With `--json` the share lines go to stderr and the share `data` is added to the probe `data`.

## Round 3 (answers Q503 to Q506, the 2 disputes)

Changed tests only. L0 `ProbeshareTest`: the `closure_request` expect no longer pins "no such fact" (the flow does not call it then); new expect: `rows` with `answers: []` gives the local reasons (hang `Result`, build `Kind`, unrecorded `Compiler`, a fact that passes `NotInAnswer`) (Q503, dispute 2). L2: `ps11` has no `closure` line (calls end after `pinned`); new `ps13-share-4xx-stops` (a 422 then a 400 to the first request: exit 20 and 1, the second request is not sent, 501 facts listed as not sent, no write; Q505); new `ps14-share-after-12` (run G of `pc2-range`: probe exit 12, then the guard, `facts_of` with no stored fact, `nothing to share`, exit stays 12; Q506). L3 `probe/pc1-probe-command` stderr line 4 is the text of `ps1` (dispute 1; exit 2 unchanged). Not tested: no send after the codes 1, 2, 15 (no L0 test, because the decision needs a new function that I may not add to `cli/`; a code agent can add `ps15` from `ps14` if wanted). `ps14` depends on the registry in `config.toml` not changing the `--range` compiler reads (slice 206e3 works on them).
Expected exits (read): `ps11` 0; `ps13` 20, 1; `ps14` 12.

Round 3: `ProbeShare.rows` has a local step (`local_why`: filters 2, 3, 6) before `ShareQueue.admit`; `ShareQueue.admit` is not changed. `probe/ps14-share-after-12`: `fx/commands` has no `--share` (the line is `probe parser2 --range --file p4/main.roc`), so the case fails by test data; the code runs the share step after exit 12 (`fail.kind == Budget`).

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-217-revert/code-final.sha256` | OK |
| `grep "todo: slice 217" cli/` | nothing |
| Expected exits (read) | ps1 2 x5, 15 (offline); ps3 2 (guard); ps4 15 x4, 1, 20; ps5 15; ps7 19, 19; ps9 15; ps10 15 (cap, Q498); ps13 20, 1 (Q505); ps14 12 (the probe code stays, Q506); ps2, ps6, ps8, ps11, ps12 0. Each non-zero exit is the rule of its run |
| `scripts/test.sh check fmt l0 l2 l3` | all pass |
| Disputes | 1 (L3 `pc1-probe-command` text): accepted, test updated. 2 (`ps11`): no request (Q503); the manager ruled that the local filters 2, 3, 6 decide first and keep their reasons; code `ProbeShare.local_why` before `ShareQueue.admit`, which is unchanged |
| Design answers | Q491 to Q498, Q503 to Q506 |
| Not tested | no L0 test of the Q506 decision; no test that the send is skipped after probe exit 1, 2 or 15 |
| For the human review | Proposals: the cap, offline and totals-warning texts, `not shared: ... not sent`; `--json` share lines on stderr with the share `data` in the probe `data`; a busy or failed `compat.db` read gives a warning and no facts; the filter 5 domain is the nightlies of the facts |

