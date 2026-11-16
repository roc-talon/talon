# 249 `tln yank`

Phase: P2 (the registry routes are built, Design Q625 (9); R-CM21 is P2 by Q629-9). Status: done (2026-11-16). The user approved Q629-1 to Q629-13, the texts of section 5, the Q629-2 text and the design text table of section 14 (Design Q629, G-C259).
Registry side: slice 246 (done). This slice is the client of `PUT` and `DELETE /v1/releases/{log_index}/yank`. Next to it: `tln move` (R-CM22, R-MV1 to R-MV5) is a later slice and has the same flow.

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CM21 | `tln yank <tag> [--reason <text>] [--undo]`. It runs in a GitHub Actions `workflow_dispatch` job. The repository is `$GITHUB_REPOSITORY`. A tag with no indexed release is exit 2. |
| R-YK1 | The routes. Both are idempotent. The answer is `{"release": <record>}` (200). |
| R-YK3 | The client flow: the release of the tag with R-AP1, then R-YK1 with the OIDC token of R-TP2. Outside GitHub Actions, Talon stops as `tln publish` does (R-AP27). |
| R-YK6 | The reason: at most 500 bytes of UTF-8, no control character (Unicode Cc). |
| R-YK2, R-TP8 | The server side: the token of the repository of the release, event `workflow_dispatch`. The client sends no operator key. A 403 is exit 20. |
| R-AP1 | `GET /v1/packages/{owner}/{repo}/releases`: the rows of the repository. A row has `tag`, `log_index`, `yanked`, `yank_reason`. 404: no indexed release. |
| R-AP34 | A write is sent again after 429, a 5xx or no answer (3 more times, 2 s, 8 s, 30 s, or `Retry-After`). A 401 gets one new OIDC token. |
| R-TP2, R-TP17, R-AP27 | The OIDC token request (audience = the registry URL, percent-encoded). No variable: exit 2, the text names `id-token: write`. |
| R-RG9, R-EC2 | `direct`: exit 2. No answer from a registry that a person set: exit 15, the text names the URL and the source, with no advice for `direct`. |
| R-E6, R-J7, R-EC20 | A refused write is exit 20, with `status` and `type` in `error.details`. No answer or a 5xx: exit 15. |
| R-OUT2 to R-OUT4 | The human text and the `data` fields are a proposal (section 5). The catalog row `yank` (CLI 3) has the fields. |
| R-PD16 | `yank` uses no project and rejects `--file` (exists in `Args.allows`, no test needed here). |

## 2. Scope: what exists in the code today

| Fact | Where | Consequence |
| --- | --- | --- |
| `yank` is a known command. `--reason` (with a value) and `--undo` are allowed for `yank` only. `--file` is not allowed. | `Args.roc` (`top_level`, `takes_value`, `allows`) | No parser change. The L2 cases reach `Run.dispatch!`. |
| `Run.dispatch!` has no branch for `yank`: exit 1, `command 'yank' is not built yet`. | `Run.roc` | The red state of every L2 case. |
| The wire bodies exist: `records.Yank` (`encode_request`, `decode_answer`, `check_reason`, `reason_limit`). `records.Index.decode_releases` reads the R-AP1 answer (as for the group read of `tln publish`). | `packages/records` | No records change. |
| `tln publish` has all the client parts: `Publish.job` (needs `GITHUB_REF`: not usable as it is), `Publish.oidc` (the text says `tln publish`), `Publish.token`, `Publish.next`, `Publish.wait`, `Publish.failure` (method `Post`, `label-conflict` and `forbidden` texts), the flow `PublishFlow.token!` and `post!`. | `Publish.roc`, `PublishFlow.roc` | `YankCheck` has its own `job`, `oidc`, `failure`, `request`. It reuses `Publish.token`, `Publish.next`, `Publish.wait`, `Registry.headers`, `Registry.refuse`. The code agent may move the shared flow into one module. A move of code that changes no `publish` test is allowed. |
| `RegistryCache.get_via!` with `newest: true` sends the read with `Cache-Control: no-cache`, no list of the cache dir, and no write when the answer has `no-store`. `Registry.releases_of_repo_url` makes the R-AP1 URL (lower-case owner and repo). | `RegistryCache.roc`, `Registry.roc` | The flow of the read. |
| `Registry.Method` has `Put` and `Delete`. `Registry.refuse` maps a 401, 403, 404, 409 or 422 of a write to `Rejected` (20). | `Registry.roc` | The error mapping needs no change. |
| `Opts.reads_registry` must list `yank` for the flag `--registry` (R-FL5). L2 case `yk12`. | `Opts.roc` | Code agent. |
| `AuditReport.from_p3` is `False`. The registry now has yank data (slice 246). | `AuditReport.roc` | Not changed here. See Q629-9. |
| The module name `Yank` is taken by `records`. | | The new modules are `YankCheck` (part A, pure) and `YankFlow` (part C, command code). |

## 3. Behaviors

| # | Behavior | Exit | Rules |
| --- | --- | --- | --- |
| B1 | `tln yank <tag>`: read R-AP1 (a fresh read), find the row whose `tag` is the operand, get the OIDC token, `PUT .../v1/releases/<log_index>/yank` with `{"reason":"<text>"}` or `{}`. Print the result. | 0 | R-CM21, R-YK1, R-YK3 |
| B2 | `--undo`: the same, with `DELETE` (no body, no `Content-Type`). | 0 | R-CM21, R-YK1 |
| B3 | The release is already in that state: the request is sent (Q629-6). `changed` is false. The record of the answer is shown (the old reason stays). | 0 | R-YK1 |
| B4 | The order of the checks, each stop before any request that follows it: registry `direct` (2); `--offline` (15); the operand (2); `--undo` with `--reason` (2, Q629-2, proposal, pending user review); the reason content (2, Q629-3); `GITHUB_REPOSITORY` (2); the OIDC variables (2); the read of R-AP1 (2, 15); the token request (2, 15); the write. | 2, 15 | R-EC2, R-YK3, R-AP27 (Q629-1) |
| B5 | The reason is checked before any request (R-YK6 rule of the registry). | 2 | R-YK6 (Q629-3) |
| B6 | The tag is not in the list, or R-AP1 is 404: no token request. | 2 | R-CM21, R-EC2 |
| B7 | The read of R-AP1 gets no answer or a 5xx, from a registry that a person set: the text of R-RG9 with no advice for `direct`. | 15 | R-RG9 |
| B8 | The token request: 401 or 403 is exit 2 (`id-token: write`); another failure is exit 15. | 2, 15 | R-TP2, Q515 of `publish` |
| B9 | A refused write is exit 20 with `status` and `type` in `error.details`. One request, no wait, no new token. | 20 | R-E6, R-J7 |
| B10 | A 401 gets one new token and one more request, no wait. A second 401 is exit 20 with `the registry refused the new token too`. | 0, 20 | R-AP34 |
| B11 | 429, 5xx and no answer: 3 more requests with the waits of R-AP34. After the last: exit 15, the number of requests, and `The yank may be done` (or `The undo`). | 0, 15 | R-AP34, R-RG9 |
| B12 | `--json`: the envelope with `data` of the catalog row, or the error object. `--registry` is read. `GITHUB_REF` is not read. | 0 | R-J1, R-OUT4, R-FL5 |

## 4. Tests

The L2 cases are in `tests/commands/cases/yank/`. Each has `rules`, `fx/commands`, `fx/env` (the job of `acme/json`, a branch ref, the OIDC variables, `TALON_REGISTRY=http://127.0.0.1:9`), `fx/http/` and `expect/`. The cases run several commands each (as the `publish` cases). A case has no `expect/exit` and no `expect/tree.diff` file when they are `0` and empty (the runner treats a missing file as empty). No exit-0 run has a line on stderr.

| Layer | Case | Checks | B |
| --- | --- | --- | --- |
| L0 | `tests/unit/YankcheckTest.roc` (15 `expect`s, in driver `l0-6.roc`): `direct`, `offline`, `operand`, `reason`, `job`, `oidc`, `release` (3 expects), `request`, `failure` (3 expects), `answer`, `lines`, `data` | R-CM21, R-EC2, R-RG9, R-YK1, R-YK3, R-YK6, R-AP1, R-AP27, R-AP34, R-E6, R-J7, R-TP2, R-OUT2, R-OUT4 | B1 to B12 |
| L2 | `yank/yk1-yank-undo`: yank with a reason, `--undo`, yank with no reason and `--json`. Calls in order: R-AP1 (`Cache-Control: no-cache`), token, write. | R-CM21, R-YK1, R-YK3, R-TP2, R-TP17, R-OUT2, R-OUT4, R-J1 | B1, B2, B12 |
| L2 | `yank/yk2-same-state`: yank of a yanked release (old reason shown), `--undo` of a release that is not yanked, `--json` with `changed` false | R-YK1, R-OUT2, R-OUT4 | B3 |
| L2 | `yank/yk3-usage-stops`: 12 stops with no request, in the order of B4 | R-EC2, R-RG9, R-YK3, R-AP27, R-TP2 | B4 |
| L2 | `yank/yk4-reason-checks`: 501 bytes, a tab; the reason comes after the operand and before the repository | R-YK6, R-EC2 | B4, B5 |
| L2 | `yank/yk5-no-release`: the tag is not in the list, 404, and `--json` | R-CM21, R-EC2, R-YK3, R-AP1 | B6 |
| L2 | `yank/yk6-token-refused`: token 403 (exit 2), token 500 (exit 15) | R-TP2, R-AP27, R-E6 | B8 |
| L2 | `yank/yk7-refused`: 403 (claim), 403 with `--undo --json` (the operator's yank), 404 | R-E6, R-AP22, R-J7, R-YK2, R-TP8 | B9 |
| L2 | `yank/yk8-renew-401`: 401 then a new token then 200; a second 401 | R-AP34, R-TP2 | B10 |
| L2 | `yank/yk9-retries`: 429 (`Retry-After: 7`), 503 busy, no answer, 200 (waits 7, 8, 30 s); a `DELETE` with 502 then 200 (wait 2 s) | R-AP34, R-AP82, R-DA9 | B11 |
| L2 | `yank/yk10-retries-exhausted`: 4 requests with no answer (exit 15, source, `The yank may be done`); 4 times 503 busy with `Retry-After: 3` for `--undo` | R-RG9, R-AP34, R-AP22, R-E6 | B11 |
| L2 | `yank/yk11-registry-no-answer`: the read of R-AP1 gets no answer, then 500 | R-RG9, R-E6, R-AP1 | B7 |
| L0 | `YankcheckTest.roc`, the expect of `undo_reason` (proposal, pending user review) | Q629-2 | B4 |
| L2 | `yank/yk13-undo-reason`: `--undo --reason`, with no repository (this text first), with no tag (the tag text first), and with `--json` (proposal, pending user review) | Q629-2, R-EC2 | B4 |
| L2 | `yank/yk12-registry-flag`: `--registry` with no `TALON_REGISTRY` | R-FL5, R-RG1, R-RG7 | B12 |

Tests that follow a recommendation (the answer is pending): Q629-1 (yk3, yk4), Q629-3 (L0 `reason`, yk4), Q629-5 (the `no-cache` header in each `calls.log`), Q629-6 (yk2). If the user answers another way, these change. The other questions have no test.

Not tested in L2 (the harness splits a command line on spaces): a reason with a space (`--reason "parse bug"`). The L0 test `request` and `reason` have it. A later L3 case can run it with the real `Fx`.

## 5. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| Yank, changed | `yanked <owner/repo> <version> (tag <tag>): <reason>`, or with no reason `yanked <owner/repo> <version> (tag <tag>)` (the catalog row). |
| Undo, changed | `unyanked <owner/repo> <version> (tag <tag>)` (the catalog row). |
| Already yanked | `<owner/repo> <version> (tag <tag>) is yanked already: <reason>` (the reason of the answer), or `... is yanked already` for no reason. |
| Not yanked | `<owner/repo> <version> (tag <tag>) is not yanked` |
| `--json` `data` | `name`, `tag`, `version`, `log_index`, `yanked`, `reason` (`null` for none), `changed`, in this order, flat in `data` (the catalog row; as `audit`). `name` is `GITHUB_REPOSITORY` as it is. |
| `--undo` with `--reason` (Q629-2, proposal, pending user review; also `--reason ""`) | exit 2: `tln yank --undo takes no --reason`. Place: after the operand, before the content of the reason and before `GITHUB_REPOSITORY`: it is a usage error of the flags, and it costs no request. Function: `YankCheck.undo_reason({ undo, reason })`. |
| No operand | exit 2: `tln yank needs a tag: tln yank <tag> [--reason <text>] [--undo]` |
| 2 or more operands | exit 2: `tln yank takes one tag: unexpected '<second>'` |
| `direct` | exit 2: `tln yank needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` |
| `--offline` | exit 15: `tln yank needs the network: --offline sends no request` |
| Reason too long | exit 2: `the reason is <n> bytes: the registry takes at most 500` |
| Reason with Cc | exit 2: `the reason has a control character: a reason is one line of plain text` |
| No repository | exit 2: `GITHUB_REPOSITORY is not set or is empty. tln yank runs in a GitHub Actions job.` and `GITHUB_REPOSITORY is <value>, not of the form owner/repo.` |
| No OIDC variable | exit 2: `tln yank needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.` |
| No indexed release | exit 2: `<owner>/<repo> has no indexed release for the tag <tag>. Run tln publish for the tag first, or wait until the registry indexes it.` |
| R-AP1 no answer, 5xx | exit 15: `the registry <url> (<source>) gave no answer: <why>.` and `the registry <url> (<source>) answered <status>: <detail>.` (R-RG9, `Registry.stop_text` with `needs`) |
| Token request | The texts of `Publish.token` (exit 2: `... was refused (403). The job needs permissions: id-token: write.`; exit 15: `... request failed: answered 500`). |
| Write refused | exit 20: `<detail> (<type>). Fix the release or the workflow, then run the command again.` (`Registry.refuse`, `Put` and `Delete`). `error.details`: `status`, `type`. |
| New token refused | exit 20: `<detail> (<type>): the registry refused the new token too.` |
| Retries, no answer | exit 15: `the registry <url> (<source>) gave no answer 4 times: <why>. The yank may be done. Run the command again.` (`The undo may be done.` for `--undo`) |
| Retries, 429, busy, 5xx | The texts of `Publish.failure` (`... after 4 requests. Try again in <n> s.`, `... 4 times. Try again later.`) with the source after the URL. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| `tln move` (R-CM22) | A later slice. The flow is the same. |
| The operator key (R-YK2) | The CLI never sends it. |
| `tln audit` and `tln outdated` showing a yank | Slice 244 (done). The note `no-yank-data` (R-AU4) is Q629-9. |
| The resolve rules for a yanked release (R-YK5, R-C6) | Done in the registry reads and in `ClosureIndex`. |
| L3 cases (the real `Fx`) | The Fx calls are the ones of `publish` (L3 exists for them). |

## 7. Questions (stop until answered)

Each answer is for Design Q629 (G-C259, pending). I wrote no test for a question, except the four in section 4.

| Id | Question | Options | Recommendation and reason | Effect now |
| --- | --- | --- | --- | --- |
| Q629-1 | The design gives no order of the checks for `tln yank` (R-PUB4 item 1 gives it for `publish`). | (a) The order of B4, as `publish`. (b) Another order. | (a). Reason: a check that costs no request comes before a request, and the people who know `publish` find the same order. | yk3, yk4 follow (a). |
| Q629-2 | `--reason` with `--undo`. The `DELETE` has no body, so the reason would be lost. | (a) Exit 2: `--reason has no use with --undo`. (b) Ignore the reason. | (a). Reason: a text that the user wrote must not vanish with no word. | No test. |
| Q629-3 | R-YK6 limits the reason on the server, with a 400. Does the client check it first? | (a) Yes, before any request, exit 2, with `records.Yank.check_reason`. (b) No: the 400 is exit 1 (`a fault of tln`), because the client sent a bad request. | (a). Reason: a bad reason is the fault of the user, not of tln. The text says what to change. | L0 `reason`, yk4 follow (a). |
| Q629-4 | R-CM21 says "runs only in a `workflow_dispatch` job". R-EC2 names the missing OIDC token, not the event. Does the client read `GITHUB_EVENT_NAME`? | (a) Yes: when it is set and is not `workflow_dispatch`, exit 2 with the text `tln yank runs in a workflow_dispatch job: GITHUB_EVENT_NAME is <value>`; when it is not set, no check. (b) No: the registry checks the claim and answers 403 (exit 20, the detail names the claim). | (b). Reason: one rule in one place (R-TP8), and a variable of another CI is not wrong for the registry, which reads the signed claim. The 403 text already names the claim. | No test. The `fx/env` of each case sets `GITHUB_EVENT_NAME=workflow_dispatch`, so each case holds for (a) and (b). |
| Q629-5 | R-YK3 says "R-AP1". The read has `max-age=60` and a local copy lives up to that time (R-AP24). Is the read fresh? | (a) Fresh: `Cache-Control: no-cache`, as the group read of `publish` (`newest`). (b) With the cache. | (a). Reason: the maintainer may have published the tag a few seconds before, and `changed` and the shown state depend on the row. A job on a fresh runner has an empty cache anyway. | Each `calls.log` has `Cache-Control: no-cache` and no `list_dirs`. |
| Q629-6 | The release is already in the state that the user asks for. | (a) Send the request anyway. The routes are idempotent (R-YK1) and the answer is the truth. (b) Do not send. Print `... is yanked already` from the R-AP1 row. | (a). Reason: one flow, no second path, and a stale R-AP1 row cannot give a false "already". Cost: one request. | yk2 follows (a). With (b) yk2 loses the write calls. |
| Q629-7 | The match of the tag. | (a) Byte for byte, case-sensitive, over all rows of the repository (R-AP1 has all groups and series). (b) Case-insensitive. | (a). Reason: GitHub tags are case-sensitive (`v1.0` and `V1.0` can both exist). | L0 `release` (the tag `v2.1.0` is not `2.1.0`). The case is not tested. |
| Q629-8 | Two rows with the same tag (R-AP1 should not give them: one tag has one asset). | (a) Exit 1 (internal): `the registry gave 2 releases for the tag <tag> (log indexes <a>, <b>)`. (b) Take the first. | (a). Reason: a yank of the wrong release is worse than a stop. | No test. |
| Q629-9 | Phase marks. R-CM21 says "Phase P3", as `tln audit`. The routes are P2 (Q625 (9)), and `tln yank` is built now on the order of the user. `AuditReport.from_p3` is `False`, so `tln audit` still prints the note `no-yank-data` and takes no `yank_reason` from the registry, although the registry has them. | (a) Change the P3 mark of R-CM21 and of the catalog row `yank` to P2 (as Q625 did for the registry rows). Leave `from_p3` for a later slice. (b) Also set `from_p3` to `True` in this slice. | (a), and a separate slice for `from_p3`. Reason: `from_p3` changes the text and the exit of `tln audit` and `tln update` (R-AU4, R-AU8, R-PU28), and has its own tests (slice 244c). | No text of `tln yank` depends on the phase. |
| Q629-10 | `--reason ""` (an empty text). | (a) The same as no reason: the body is `{}`. (b) The body is `{"reason":""}`. | (a). Reason: an empty reason says nothing, and `yank_reason` would be `""` instead of `null` for a reader. | No test (the L2 harness drops an empty word). |

Answers: Q629-1 to Q629-8 and Q629-10: approved as recommended by the user 2026-11-16 (pending Design Q629). Q629-9: the user chose "mark P2 and turn on the yank data of `tln audit` now": sections 13 to 15. Section 4 is therefore final for these: no test changes.

## 8. Names for the code agent

| Name | Type | Rule |
| --- | --- | --- |
| `YankCheck` (stub, `cli/lib/YankCheck.roc`) | The 12 functions of part A with their types and the text of each case in the doc comment: `direct`, `offline`, `operand`, `reason`, `job`, `oidc`, `release`, `request`, `failure`, `answer`, `lines`, `data` | B1 to B12 |
| `YankFlow` | Part C, `run! : Fx, Args => I32`, the branch `args.command == ["yank"]` in `Run.dispatch!`, and `yank` in `Opts.reads_registry` | B1 to B12 |

The calls of `YankFlow.run!`, in order (the `calls.log` of the cases): `env_all!`, `Roots.of_run!`, `read_files!` of `config.toml`, `Net.registry` (as `PublishFlow`); `YankCheck.direct`, `offline`, `operand`, `reason`, `job`, `oidc` (no call); `RegistryCache.get_via!` with `newest: true` and the source; `YankCheck.release`; the token request (`Fx.http_send!`, `Publish.token_request`, `Publish.token`); the write (`Fx.http_send!` of `YankCheck.request`, `Publish.next`, `sleep!`, `YankCheck.failure`); `YankCheck.answer`; the output (`lines`, or `Out.json_ok` with `data`). The `calls.log` lines are my best guess, and the code agent may dispute them (section 9).

## 9. Disputes (from the code agent)

None yet.

## 10. Red results (test agent, 2026-11-16)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-6.roc` | 162 tests: 147 pass, 15 fail, 0 compiler errors | The 15 `expect`s of `YankcheckTest.roc` fail on `crash "todo"` of the stub `cli/lib/YankCheck.roc`. The other 147 (old tests of the driver) pass. |
| `tests/commands/run.sh yank/` | 12 of 12 cases fail | Exit 1 and `tln: error[internal]: command 'yank' is not built yet` (a `--json` run has the same text in the envelope). The `Args` parse passes for each command line of each case. |

Files changed outside the test tree, needed for the red state of L0: `cli/lib/YankCheck.roc` (new, a stub of types and `crash "todo"`) and one line `YankCheck,` in `cli/lib/main.roc` (the list of exposed modules). Without them driver `l0-6.roc` does not compile and the old tests of it fail too. The code agent replaces the stub.

## 11. Verify results

Not done (step 4).

## 12. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 249 | `tln yank` | Tests for R-CM21, R-YK3 (client), R-YK6 (client check), R-EC2 (yank cases), R-RG9 (yank). The pure module `YankCheck`, the flow `YankFlow`, the branch in `Run.dispatch!`, `yank` in `Opts.reads_registry`. | R-CM21, R-YK1, R-YK3, R-YK6, R-EC2, R-RG9, R-AP34 | G-C259 (Design Q629) | none / none | 60 | Sonnet |

## 13. The yank data of `tln audit` (Q629-9, added 2026-11-16)

### 13.1 What `from_p3` and the yank switches control today (found in `cli/lib`)

| # | Place | Today (P2) | Switch | Part |
| --- | --- | --- | --- | --- |
| P1 | `AuditFlow.roc` line 63: `no_yank_data: Bool.True` for each index | The report always has the flag. | A constant in the flow, not `from_p3` | Yank data |
| P2 | `AuditReport.text`: the last line. `direct`: `note: no yank and advisory data without a registry`. Registry: `note: the registry has no yank and advisory data yet`. | Both are printed. | The flag of P1 | Yank data |
| P3 | `AuditReport.data`: `notes[]` has `{"kind":"no-yank-data"}` first | Both indexes. | The flag of P1 | Yank data |
| P4 | `AuditReport.fix` with a successor: `tln update <alias>` | Off: the fix of the reason alone. | `from_p3` | Successor |
| P5 | `AuditReport.fix` of `moved`: today `""` (no item, no `fix:` line, `"fix":null`) | Off. | `from_p3` | Successor |
| P6 | The `fix:` line of `text`: an item for a finding with a successor (not failing) | Off. | `from_p3` | Successor |
| P7 | `AuditReport.resolve_line` of `moved` with a successor: `<alias>: moved to <successor>` + `. Run: tln update <alias>` | The `Run:` part is off. | `from_p3` | Successor |
| P8 | `XCmd` (R-C6, R-B3): the note `no yank and advisory data without a registry` on a reused build | `direct` only. | No switch | Not changed |
| P9 | The findings with reason `yanked`, `yank.reason`, the R-AU7 warning of a yanked hash | Built (slice 244): they appear when the answer has `yanked: true`. The P2 registry never sent it, the yank routes now do (slice 246). | None | No change: it works already |
| P10 | `ClosureIndex.candidates` and the other resolve readers: they do not drop a yanked row (only `withdrawn`), and `Index.Candidate` has no `yanked` member. R-C6 says a yanked release is not chosen. | Missing. | None | Q629-13 |

P1 to P3 are the "yank data". P4 to P7 are the "successor" part: they need `tln update` to follow a successor (the client part of Registry R-PU28), which no code does today (`docs/slices/244-audit.md`, 244c). They share the one constant `from_p3` with the yank data only because Q620 item 1 put both on one phase.

### 13.2 New behaviors

| # | Behavior | Before | After | Rules |
| --- | --- | --- | --- | --- |
| B13 | `tln audit` with a registry prints no note about yank data. The flow sets the flag `no_yank_data` from the index: true for `direct`, false for a registry. `AuditReport.text` and `data` use the flag for `direct` only: a registry never prints the note and never has `no-yank-data` in `notes[]`, also when the flag is true. | Last line `note: the registry has no yank and advisory data yet`; `notes[0]` is `{"kind":"no-yank-data"}` | No line, no member | R-AU4, R-C6, Q629-9, Q629-11 |
| B14 | `direct` is unchanged: `note: no yank and advisory data without a registry` and `{"kind":"no-yank-data"}`. | same | same | R-AU4, R-C6 |
| B15 | `from_p3` is true in full (Q629-12, approved): P4 to P7 give the P3 texts below. All P3 texts were decided already (slice 244, Q-244c-4, "The fix before P3", read in the other direction), so there is no new question. | the pre-P3 texts | the P3 texts | R-AU8, R-AU14, R-PU28 |

Texts, before and after (B13):

| Place | Before | After |
| --- | --- | --- |
| Human, registry, last line | `note: the registry has no yank and advisory data yet` | (no line) |
| `--json`, registry, `data.notes` | `[{"kind":"no-yank-data"}, ...]` | `[...]` (the other notes only; `[]` for none) |
| Human, `direct`, last line | `note: no yank and advisory data without a registry` | the same |
| `--json`, `direct`, `data.notes` | `[{"kind":"no-yank-data"}, ...]` | the same |

Texts, before and after (B15, `from_p3` true):

| Place | Before (P2 constant false) | After (true) |
| --- | --- | --- |
| `fix` of a header finding with a successor, reason `repo-missing` | `tln remove csv, then tln add another package, or add the item to [audit] ignore` | `tln update csv` |
| `fix` of a finding with a successor, any other reason | the fix of the reason | the fix of the reason (it is `tln update <alias>` already; only `repo-missing` changes) |
| `fix` of `moved`, header (with or without a successor) | `""` (`"fix":null`) | `tln update <alias>` |
| `fix` of `moved`, transitive | `""` | `tln update <a> or tln update <b> (tln why <name>), or use [overrides]` (one alias: `tln update <a> (tln why <name>), or use [overrides]`) |
| `fix` of `moved`, tool | `""` | `tln update --tool <key>` |
| The `fix:` line of `tln audit` | items for the findings that fail | the same, and an item for each open finding with a successor, in the order of the findings (for example `... csv: ... ignore. xml: tln update xml.`) |
| `--json` `findings[].fix` of `moved` | `null` | the text |
| `resolve_line` of `moved`, header, with a successor | `json: moved to acme/roc-json` | `json: moved to acme/roc-json. Run: tln update json` |
| `resolve_line` of `moved`, no successor | `xml: <name> <version> is in a repository that moved.` | the same text and ` Fix: tln update xml.` |
| `resolve_line` of `moved`, transitive | `...moved to acme/roc-util.` | `...moved to acme/roc-util. Fix: tln update json (tln why someone/roc-util), or use [overrides].` |
| `data.audit_warnings[].text` | the line above | the line above |

Risk, for the review: the texts say `tln update <alias>` follows the successor (R-PU28, client part). No code does it today (`grep successor cli/lib`: only the audit modules). The user ordered the texts on. Until a slice builds the follow, the advice is wrong in a run: `tln update json` will not move the entry. Recommendation (Q629-14, no test): a slice right after the yank filter slice, or before it, for the follow in `tln update` (R-PU28 client part, Design Q406).

### 13.3 Questions (TW17)

| Id | Question | Options | Recommendation and reason | Effect now |
| --- | --- | --- | --- | --- |
| Q629-11 | ANSWERED by the user 2026-11-16: (a), no note (pending Design Q629). The advisories and the scanner hook of R-CM14 stay P3. With a registry, does `tln audit` still print a note, now only about advisories? R-AU4 gives a note for "no yank data" only. | (a) No note. (b) A note `note: the registry has no advisory data yet` (id `no-advisory-data`) with each registry run, until P3. | (a). Reason: it is what "turn on the yank data" means and what R-AU4 says. A feature that does not exist yet needs no note on each run: R-CM14 names the advisories in the future ("then the advisories"), and `tln audit` has no advisory column. With (b) each CI run prints a line that nobody can act on. | The tests of B13 follow (a). With (b): the same files change to the new line and the id `no-advisory-data`, and the L0 report needs a second flag. |
| Q629-12 | ANSWERED by the user 2026-11-16: (b), turn it on in full (pending Design Q629). The successor part of `from_p3` (P4 to P7): keep it off, or turn it on with the yank data? `tln update <alias>` follows a successor only when the client part of R-PU28 exists (no code does it today), so the fix text `tln update <alias>` and the line `. Run: tln update <alias>` would not do what they say. | (a) Split the constant: the yank data is on; the successor part stays off (a second constant, `follows_successor`, false) until the slice of R-PU28 (client). (b) Both on now. | (a). Reason: a text that tells the user a step that does not move the entry is a bug (the reason of Q-244c-4). The user's order was the yank data. Design: R-AU8 and R-AU14 say "before P3" for the successor part: the new words say "until `tln update` follows a successor". | No test change: P4 to P7 keep their tests. With (b): the L0 `fix` rows, the L0 `resolve_line` rows and the L2 cases `audit/au1-findings`, `au3-warnings`, `au9-ignore`, `ad1-direct` change as the table "The fix before P3" of slice 244 says, in reverse. |
| Q629-13 | ANSWERED by the user 2026-11-16: (a), out of scope, its own slice right after 249 (the number comes from TalonRegistry; pending Design Q629). P10: a registry answer has yanked rows, and R-C6 says a yanked release is not chosen. Today the resolve reads them as candidates. Is this in slice 249? | (a) No: a later slice (`yank filter`): it adds `yanked` to `Index.Candidate`, drops a yanked row for a new pick, and keeps the value of a header (R-C9, R-YK5), also in `tln x`, `tln tool install`, `tln add` (`FullName` already drops yanked) and the R-B3 note. (b) Yes, now, only in `ClosureIndex.candidates` and `drop_labels`' callers. | (a). Reason: `Index.Candidate` is a shared type (about 40 test sites), R-C9 needs the header values at each pick, and the user asked for the audit yank data. A resolve warning for a yanked hash (R-AU7) already shows the problem. Until then a new pick can choose a yanked release. | No test. This is an open gap, not a regression: before the yank routes no row was yanked. |

Q629-11 (a) and Q629-12 (b) are answered and the tests follow them. Q629-13: out of scope, no test; the slice of the yanked-row filter follows 249 (it adds `yanked` to `Index.Candidate`, drops a yanked row from a new pick, keeps a header value (R-C9, R-YK5), and covers `tln x`, `tln tool install`, `tln add` and the R-B3 note).

### 13.4 Tests changed (they were green, now red)

| Layer | File | Change |
| --- | --- | --- |
| L0 | `tests/unit/AuditcheckTest.roc`, the `text` note expect: the row `g` (registry, flag true) | The text has no `note: the registry has no yank and advisory data yet` line |
| L0 | the same file, the `data` expect (registry, flag true) | `notes` starts with `unused-ignore`, no `no-yank-data` |
| L0 | the same file, the not-indexed expect (registry, flag true) | no note line; `notes` has no `no-yank-data` |
| L2 | `audit/au1-findings`, `au1-tool`, `au3-clean`, `au3-warnings`, `au4-not-indexed`, `au9-ignore` (3 runs), `ad9-guard`, `ad13-guard-gone` | The note line is removed from each registry run; `no-yank-data` is removed from each registry `--json` run (`notes`, and `error.details` of exit 21). Comments of `au3-clean` and `au4-not-indexed` (`fx/commands`) |
| Tool | `tests/tools/mk-audit.py` | `NOTE_REG` is empty and the registry `notes` lists have no `no-yank-data`, so a new run of the tool gives the same files |

| L0 | `AuditcheckTest.roc`, the `fix` rows (`csv` with a successor, `xml` twice, `moved` transitive, `moved` tool), the `text` expect (the `fix:` line ends with `xml: tln update xml.`), the `data` expect (`"fix":"tln update xml"` for `moved`), the not-indexed expect (a `fix: xml: tln update xml.` line), the `resolve_line` rows (3 `moved` rows) | the texts of the table B15 |
| L2 | `audit/ad1-direct`, `au1-findings`, `au3-warnings`, `au9-ignore` (runs 1, 3, 4 and the `--json` run), `registry/au7-install-warnings` (stderr and the `audit_warnings` text of the `--json` run), `registry/au7-ignore` (stderr) | the same texts: `xml: tln update xml.` in the `fix:` line, `"fix":"tln update xml"`, `parser: moved to acme/roc-parser. Run: tln update parser` |
| Tool | `mk-audit.py` | the same (the 4 places of the `xml` finding, the `fix:` lines, `line_parser`, the comments) |

Not changed: every `direct` case (`ad1`, `ad2`, `ad10` to `ad12`, and their notes), the L0 `direct` rows, the `x` and `tool` notes (P8). The L0 tests of the flag with `Direct` stay. The flow `AuditFlow` has no L0 test (command code): the L2 cases above are its test. The code agent sets `no_yank_data: index == Direct` in the flow, and makes `text` and `data` ignore the flag for `Registry`. Dead text of the registry note is removed.

## 14. Design text changes (FINAL: Q629-11 (a), Q629-12 (b), Q629-13 (a); for TalonRegistry)

The spots of `DESIGN-CLI.md` that still describe the pre-P3 state. The new text follows the answers of the user. `from_p3` is on in full, so every "Before P3" and "from P3" word about the successor goes. The advisories and the scanner hook stay P3, with no note.

| Spot | Old | New |
| --- | --- | --- |
| R-CM14 (line 24), the text | `With `direct`, or before P3, there is no yank and advisory data, and Talon prints a note (Resolution 2, R-C6). Rules: R-AU1 to R-AU12. Phase P3.` | `With `direct` there is no yank and advisory data, and Talon prints a note (Resolution 2, R-C6). With a registry the yank data is on (Design Q629) and there is no note. The advisories and the scanner hook are P3. Rules: R-AU1 to R-AU12. Phase P2.` |
| R-CM14, the last column | `` `tln audit` is built in P2: the P2 registry gives 5 of the 6 reasons (`withdrawn` and `repos`); yank data is P3 (Design Q620). `` | `` `tln audit` is built in P2 (Design Q620). With the yank routes (Design Q625) the registry gives all 6 reasons, and the yank data is on from slice 249 (Design Q629). `` |
| Line 369 | `` `tln audit` is P3 (Design 7, R-PH5). R-AU7 gives the warnings of the phases before it. `` | `` `tln audit` is built in P2 (Design 7, R-PH5, Design Q620, Q629). Its advisories and its scanner hook are P3. R-AU7 gives the warnings of a resolve. `` |
| R-AU4 | `With `direct`, or with a registry before P3, Talon also prints the note of Resolution 2, R-C6. The note is not a finding. The phase is a constant of each `tln` release: a P2 `tln` prints the note with every registry. With a registry the note has the same id (`no-yank-data`) and the text `note: the registry has no yank and advisory data yet` (Design Q620). From slice 249, ...` (the text that TalonRegistry wrote) | `With `direct`, Talon also prints the note of Resolution 2, R-C6 (`note: no yank and advisory data without a registry`, id `no-yank-data`). The note is not a finding. With a registry there is no note: the registry has the yank data (Design Q629). The advisories and the scanner hook are P3 and have no note until then.` |
| R-AU7 | `Before P3, a command that resolves prints one warning for each closure hash ...` | `A command that resolves prints one warning for each closure hash ...` (the rest is the same: the reason `yanked` is one of the reasons of R-AU2, so a yanked hash that the closure answer shows gets its warning) |
| R-AU8, last sentence | `Before P3, a successor does not make the fix `tln update <alias>` (R-AU14, Design Q622).` | (delete the sentence; the rest of R-AU8 is the rule: `moved`, and each other reason with a successor, have the fix `tln update <alias>`) |
| R-AU14, the sentence with the phase constant | `Before P3 (the phase constant, Design Q620), `tln update` does not follow a successor (Registry R-PU28, Design Q406), so the moved line is `json: moved to acme/roc-json` with no `Run:` part; from P3 it gets `. Run: tln update json` (Design Q622).` | `The moved line is `json: moved to acme/roc-json. Run: tln update json` (Design Q622, Q629).` Also: `` `moved` starts in P2 for a rename (R-TP10), and in P3 for a move (R-AP31) `` becomes `` `moved` starts in P2, for a rename (R-TP10) and for a move (R-AP31, Design Q626) ``. |
| Line 24 (R-CM14) and R-PH5 | (see the rows above) | R-PH5 already says `audit` is built in P2 (the TalonRegistry text). R-CM14 above. |
| Line 864 | `Human text of `tln audit` (a proposal, R-OUT2, P3):` | `Human text of `tln audit` (a proposal, R-OUT2):` |
| Line 880 | `Warning of a resolve before P3 (R-AU7), and of the R-DI15 case (a proposal, R-OUT2):` | `Warning of a resolve (R-AU7), and of the R-DI15 case (a proposal, R-OUT2):` |
| Catalog row `audit`, last column | `Below the table | Proposal (R-OUT2), P3` | `Below the table | Proposal (R-OUT2)` |
| Phase words in `DESIGN-RESOLUTION.md` R-C6 | `With a registry before P3 (a P2 `tln`), the note has the same id (`no-yank-data`) and the text `note: the registry has no yank and advisory data yet` (CLI R-AU4, Design Q620).` | `With a registry there is no note (CLI R-AU4, Design Q629).` The sentence "Yank and advisory data come from the registry (... advisories in Design 7, P3)" stays: the advisories are P3. |

Also (Q629-13 (a), approved): add to `DESIGN-RESOLUTION.md` R-C6 or to the plan: "The filter of a yanked row in the pick is a later slice (Design Q629-13)": a design note, so that the gap is not lost.

## 15. Red state after the audit part (test agent, 2026-11-16)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-6.roc` | 15 fail (YankCheck), 147 pass | as section 10 |
| `roc test tests/unit/l0-9.roc` | 189 tests: 183 pass, 6 fail, 0 compiler errors | the changed `AuditcheckTest` expects: the registry note and `no-yank-data` (text, data, not-indexed), and the successor texts (`fix` rows, `resolve_line` rows, and the `text`, `data` and not-indexed expects, which hold both changes) |
| `tests/commands/run.sh` (all L2) | 685 cases: 662 pass, 23 fail | 11 old cases and 12 `yank/`. The 11: `audit/` `ad1-direct`, `ad9-guard`, `ad13-guard-gone`, `au1-findings`, `au1-tool`, `au3-clean`, `au3-warnings`, `au4-not-indexed`, `au9-ignore`, and `registry/au7-ignore`, `au7-install-warnings`. The diffs show only the notes and the successor texts. The other 8 `audit/` cases (`direct` ones and the usage cases) pass unchanged. |
| `tests/commands/run.sh yank/` | 12 of 12 fail | as section 10 |

I changed `AuditcheckTest.roc` only (no shared type, so only drivers `l0-9` and `l0-6` were run; `l0-6` has the stub). The whole L2 run (all groups) was run once: no other case prints these texts. Nobody ran `UPDATE=1`.

## 16. Plan row (replaces section 12)

| 249 | `tln yank`, and the yank data of `tln audit` | Tests for R-CM21, R-YK3 (client), R-YK6 (client check), R-EC2 (yank cases), R-RG9 (yank). The pure module `YankCheck`, the flow `YankFlow`, the branch in `Run.dispatch!`, `yank` in `Opts.reads_registry`. Audit: no `no-yank-data` note and no registry note with a registry (B13; the flow sets the flag from the index), and `from_p3` true in full (B15: the successor fix, the `fix:` items, `Run: tln update <alias>`). The yanked-row filter is the next slice (Q629-13). | R-CM21, R-YK1, R-YK3, R-YK6, R-EC2, R-RG9, R-AP34, R-AU4, R-C6 | G-C259 (Design Q629) | none / none | 80 | Sonnet |

## 17. After the code (test agent, 2026-11-16)

| Item | Result |
| --- | --- |
| Dispute D249-1 (code agent, accepted): the L0 expect "another answer to the read" built its problem body with a literal that defaulted to Dec (`"status":500.0`). Fixed in the test: `problem(500.U16, ...)` and `403.U16`. I checked the texts against the code and the approved texts: `the registry answered 500 (/errors/internal). Try again later.` (no source, `Registry.refuse`, `Get`) and `the registry <origin> (TALON_REGISTRY) answered 500: D.` (R-RG9, `needs`) are right. | `l0-6`: the expect passes |
| Q629-2 (proposal, pending user review): text `tln yank --undo takes no --reason`, place after the operand and before the reason content. A stub `YankCheck.undo_reason` (`crash "todo"`) is in `cli/lib/YankCheck.roc`; the flow does not call it yet. | L0 expect and L2 `yk13` are red |
| `roc test tests/unit/l0-6.roc` | 163 tests: 162 pass, 1 fail (the `undo_reason` expect), 0 compiler errors |
| `tests/commands/run.sh yank/` | 13 cases: 12 pass, 1 fail (`yk13-undo-reason`: the flow gives the tag, repository and no-release texts and not the new text) |

## 18. Mutation gaps closed (test agent, 2026-11-16)

| Gap | New test |
| --- | --- |
| G1 | L2 `yank/yk13-undo-reason`, runs 5 and 6: `--undo --reason` of 501 bytes, and with a tab: the `--undo` text comes first |
| G2 | L0 `YankcheckTest`: the tag `V1.0.0` is not `v1.0.0` (both directions), Q629-7 |
| G3 | L0 `YankcheckTest`: 2 rows with one tag (log indexes 4 and 9) give kind `internal` and `the registry gave 2 releases for the tag 1.0.0 (log indexes 4, 9)`. This text was approved in Q629-8 (a); the code gives it as written. |
| W1 | L2 `yank/yk14-undo-no-answer`: 4 times no answer for `--undo`: `The undo may be done.` |
| W2 | L2 `audit/au13-successor-fix`: `repo-missing` with the successor `acme/roc-csv`: `fix: csv: tln update csv.` (exit 21). The `moved` case of `au1-findings` did not catch the mutant: `moved` has the fix `tln update` with or without the successor. The expected output of this case was reviewed from the real run (the code is green) and kept in `mk-audit.py`. |

All pass against the code. Mutants: 17 of 17 caught (`research/slice-249-revert/RESULT.md`).
