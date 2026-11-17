# 251 `tln move`

Phase: P2 (the registry routes are built, Design Q626; `tln move` is P2 by Design Q631 (13)). Status: done (2026-11-17). The user approved Q251-1 to Q251-13 as recommended and the texts of section 5 (Design Q631, G-C261).
Registry side: slices 247 and 247b (done). This slice is the client of `PUT` and `DELETE /v1/packages/{owner}/{repo}/successor` (Registry R-AP31, R-TP15). The flow is the one of `tln yank` (slice 249, `docs/slices/249-yank.md`): the same token, the same retries, the same exit codes.
Not in this slice: the follow of a successor by `tln update` (slice 252, done).

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CM22 | `tln move <old-name> [--to <new-name>] [--undo]`. It sets, offers or removes the successor of a package name. It runs in a GitHub Actions `workflow_dispatch` job. It changes no header and writes no file (except the kept GitHub answer of the guard, R-RG5). |
| R-MV1 | The 3 rows of the request. J is `$GITHUB_REPOSITORY`, O is the old name, T is `--to`. J is not O, no `--to` or T equal to J: `PUT` with `{"name": J}`. J is O and `--to` T: `PUT` with `{"name": T}`, an offer (202). `--undo`: `DELETE`. |
| R-MV2 | The checks before a request, each exit 2 (section 4 gives the order, Q251-1). |
| R-MV3 | The privacy guard (R-RG6) checks the successor only, never the old name. |
| R-MV4 | The token of R-TP2 for the job repository. A refused request is exit 20 (R-E6) with the `detail`. After a 429, a 5xx or no answer: the retries of R-AP34. |
| R-MV5 | No project, no file, no header change. The output is in the catalog (a proposal, R-OUT2). |
| R-AP31, R-AP32, R-TP15, R-TP12 | The registry side: the answer is the `repos` item (201 new, 200 changed or same, 202 offer). 403 `forbidden`, 403 `repository-changed` with `issues_url`, 404, 422 `successor-mismatch`. |
| R-AP34, R-AP27, R-TP2, R-TP17 | The retries, the OIDC token request, the audience (the registry URL). |
| R-RG9, R-EC2, R-E6, R-J7, R-EC20 | `direct` is exit 2. No answer from a registry that a person set is exit 15, with the URL and the source, and no advice for `direct`. A refused write is exit 20 with `status` and `type` in `error.details`. |
| R-OUT2 to R-OUT4 | The human text and the `data` fields are a proposal (section 5). The catalog row `move` has the fields and 3 texts. |
| R-IK2 | A name is compared in lower case. |
| R-PD16 | `move` uses no project, and rejects `--file` (exists in `Args.allows`, no test needed here). |

## 2. Scope: what exists in the code today

| Fact | Where | Consequence |
| --- | --- | --- |
| `move` is a known command. `--to` (with a value) is allowed for `move` only. `--undo` is allowed for `yank` and `move`. `--file` is not allowed. | `Args.roc` (`top_level`, `takes_value`, `allows`) | No parser change. The L2 cases reach `Run.dispatch!`. |
| `Run.dispatch!` has no branch for `move`: exit 1, `command 'move' is not built yet`. | `Run.roc` | The red state of every L2 case. |
| The wire is done: `records.Move.encode_request`, `records.Closure.decode_repo` (the answer item), `records.Index.decode_releases` (the R-AP1 answer, with `repos`). | `packages/records` | No records change. |
| `YankCheck` and `YankFlow` have every client part: `job`, `oidc`, `request`, `failure`, `send!` with the waits and the new token. | `cli/lib` | `MoveCheck` has its own copies of the texts (the command name is in them). It reuses `Publish.token`, `Publish.next`, `Publish.wait`, `Publish.no_reply`, `Publish.retry_text`, `Registry.headers`, `Registry.refuse`. The code agent may move the shared flow (`token!`, `send!`) into one module. A move of code that changes no `yank` and no `publish` test is allowed. |
| `PrivacyGuard.check!` takes `sources : List(Source)`, with `Repo("owner/repo")`. A refused answer is not kept. A public answer is kept (`repo.json`). With `TALON_GITHUB_API` set it sends no token (R-EV19). | `PrivacyGuard.roc` | The L2 cases set `TALON_GITHUB_API=http://127.0.0.1:7`. |
| `Registry.refuse` maps a 401, 403, 404, 409 or 422 of a write to `Rejected` (20). Its text for a write ends `Fix the release or the workflow, then run the command again.` | `Registry.roc` | The tail does not fit a move (Q251-8): `MoveCheck.failure` replaces it. |
| `repository-changed` with `issues_url`: no CLI code reads `Problem.Extra.IssuesUrl` today. R-TP12 gives the text. | `Problem.roc` | `MoveCheck.failure` is the first user (Q251-8). |
| `Opts.reads_registry` must list `move` for `--registry` (R-FL5). L2 case `mv13`. | `Opts.roc` | Code agent. |
| The module name `Move` is taken by `records`. | | The new modules are `MoveCheck` (part A, pure) and `MoveFlow` (part C, command code). |

## 3. Behaviors

| # | Behavior | Exit | Rules |
| --- | --- | --- | --- |
| B1 | `tln move <old>` in a job of the new name: guard of J, read of R-AP1 for the old name (fresh), token, `PUT` with `{"name": J}`. 201: `moved`. 200: `unchanged` when the read had this successor, else `moved`. | 0 | R-CM22, R-MV1, R-AP31 |
| B2 | `tln move <old> --to <new>` in a job of the old name: guard of T, token, `PUT` with `{"name": T}`. 202: `offered`. No R-AP1 read (an offer has no `unchanged`). A repeated offer shows the same text. | 0 | R-MV1, R-TP15 |
| B3 | `tln move <old> --undo`: no guard, read of R-AP1, token, `DELETE`. 200: `removed`, or `unchanged` when the read had no successor. | 0 | R-MV1, R-MV3 |
| B4 | The order of the checks, each stop before any request that follows it (Q251-1): registry `direct` (2); `--offline` (15); the operand (2); the old name is a full name (2); `--undo` with `--to` (2); the value of `--to` is a full name (2); `GITHUB_REPOSITORY` (2); the names against the job (2, B5); `GITHUB_EVENT_NAME` (2); `GITHUB_SERVER_URL` (2); the OIDC variables (2); the privacy guard (2, 15); the R-AP1 read (2, 15); the `--undo` check of Q251-6 (2); the token request (2, 15); the write. | 2, 15 | R-EC2, R-MV2, R-RG9, R-AP27 |
| B5 | The names against the job: `--to` equal to the old name: exit 2. J is the old name and no `--to` (and no `--undo`): exit 2. J is not the old name and `--to` is another name than J: exit 2 (J is neither). The first that applies, in this order. | 2 | R-MV1, R-MV2 |
| B6 | `--undo` in a job that is not the old name: the read shows the successor of the old name. J must be that successor, else exit 2 (no token). A read that is 404 or has no item of the old name: the check passes and the registry decides (Q251-6). | 2, 0, 20 | R-MV1, R-MV2, R-TP15 |
| B7 | The guard names the successor only (J for a move, T for an offer). The old name is never checked. `--undo` has no guard. A private or unknown successor: exit 2, nothing is sent to the registry. | 2 | R-MV3, R-RG6 |
| B8 | The R-AP1 read gets no answer or a 5xx, from a registry that a person set: the text of R-RG9 with no advice for `direct`. | 15 | R-RG9 |
| B9 | The token request: 401 or 403 is exit 2 (`id-token: write`); another failure is exit 15. | 2, 15 | R-TP2 |
| B10 | A refused write is exit 20 with `status` and `type` in `error.details`. One request, no wait, no new token. | 20 | R-MV4, R-E6, R-J7 |
| B11 | A 401 gets one new token and one more request, no wait. A second 401 is exit 20 with `the registry refused the new token too`. | 0, 20 | R-AP34 |
| B12 | 429, 5xx and no answer: 3 more requests with the waits of R-AP34. After the last: exit 15, the number of requests, and `The move may be done` (`The offer`, `The removal`). | 0, 15 | R-AP34, R-RG9 |
| B13 | `--json`: the envelope with `data` of the catalog row, or the error object. `--registry` is read. `GITHUB_REF` is not read. | 0 | R-J1, R-OUT4, R-FL5 |
| B14 | The names are in lower case in the URL, the body, the guard file and the output (R-IK2, Q251-11). | 0 | R-IK2 |

## 4. Tests

The L2 cases are in `tests/commands/cases/move/`, made by `tests/tools/mk-move.py` (it writes each fake answer and its `calls.log` line in one step, and the expected files by hand from this file, never from a run). Each case has `rules`, `fx/commands`, `fx/env` (the job `acme/roc-json`, `workflow_dispatch`, `https://github.com`, the OIDC variables, `TALON_REGISTRY=http://127.0.0.1:9`, `TALON_GITHUB_API=http://127.0.0.1:7`), `fx/http/` and `expect/`. No exit-0 run has a line on stderr.

| Layer | Case | Checks | B |
| --- | --- | --- | --- |
| L0 | `tests/unit/MovecheckTest.roc` (23 `expect`s, in driver `l0-4.roc`; the last pins the status rule of `answer`): `direct`, `offline`, `operand`, `name`, `flags`, `job`, `plan` (3 expects), `event`, `server`, `oidc`, `guarded`, `before` (2), `holder`, `request`, `failure` (4), `answer`, `lines`, `data` | R-CM22, R-MV1 to R-MV4, R-EC2, R-RG9, R-AP31, R-AP32, R-AP34, R-TP12, R-IK2, R-E6, R-J7, R-OUT2, R-OUT4 | B1 to B14 |
| L2 | `move/mv1-set`: 201 `moved`, 200 `unchanged`, `--to` equal to J with `--json`, upper-case names. Calls in order: guard of J (the old name has no GitHub fixture), R-AP1 (`Cache-Control: no-cache`), token, `PUT`. | R-CM22, R-MV1, R-MV3, R-MV5, R-AP31, R-IK2, R-OUT2, R-OUT4, R-J1 | B1, B7, B13, B14 |
| L2 | `move/mv2-offer`: the offer (202) as text and as `--json`; the repeated offer; no R-AP1 read | R-MV1, R-MV3, R-TP15, R-OUT2, R-OUT4 | B2, B7 |
| L2 | `move/mv3-undo`: `removed`, `unchanged`, `--json` in the job of the successor. No guard. | R-MV1, R-MV2, R-MV3, R-OUT2 | B3, B6 |
| L2 | `move/mv4-usage-stops`: 27 stops with no request, in the order of B4, and the `--json` error | R-EC2, R-MV2, R-RG9, R-AP27, R-TP2 | B4, B5 |
| L2 | `move/mv5-guard`: a private successor, an unknown one, an offer to a private name. Nothing is sent to the registry. | R-MV3, R-RG4 to R-RG6 | B7 |
| L2 | `move/mv6-refused`: 403, 422 (exposes), 404 with `--json`, 403 `repository-changed` with `issues_url`, a refused offer | R-MV4, R-E6, R-J7, R-TP12, R-TP15 | B10 |
| L2 | `move/mv7-undo-holder`: `--undo` in the job of a third repository: the read has a successor, has none, is 404 (the registry then answers 403) | R-MV1, R-MV2, R-TP15 | B6 |
| L2 | `move/mv8-token-refused`: token 403 (exit 2), token 500 (exit 15) | R-TP2, R-AP27, R-E6 | B9 |
| L2 | `move/mv9-renew-401`: 401, a new token, 201; 401, a new token, 401 | R-AP34, R-TP2 | B11 |
| L2 | `move/mv10-retries`: 429 with `Retry-After: 7`, 503 busy, no answer, 201 (waits 7, 8, 30 s); a `DELETE` with 502 then 200 (2 s) | R-AP34, R-AP82, R-DA9 | B12 |
| L2 | `move/mv11-retries-exhausted`: 4 requests with no answer for a move and for an offer; 4 times 503 busy with `Retry-After: 3` for `--undo` | R-RG9, R-AP34, R-E6 | B12 |
| L2 | `move/mv12-registry-no-answer`: the R-AP1 read gets no answer, then 500 | R-RG9, R-E6, R-AP1 | B8 |
| L2 | `move/mv13-registry-flag`: `--registry` with no `TALON_REGISTRY` | R-FL5, R-RG1, R-RG7 | B13 |
| L2 | `move/mv14-case-fold`: job `Acme/OLD`, `move Acme/Old --to Acme/New` (an offer) and a move by `Acme/NEW`: lower case in the guard file, URL, body and output | R-IK2, Q251-11 | B14 |
| L2 | `move/mv15-read-not-retried`: the R-AP1 read answers 503: exit 15, no second read, no token (Q251-9); a move and `--undo` | R-RG9, R-AP34, R-AP1 | B8 |

Tests that follow a recommendation (approved 2026-11-17): Q251-1 (mv4, mv5 order), Q251-3 (L0 `event`, `server`, mv4 runs 20, 23), Q251-4 (the R-AP1 read and `unchanged`: mv1, mv3, L0 `before`, `answer`, and the read in each `calls.log`), Q251-5 (mv3 has no guard), Q251-6 (mv7, L0 `holder`), Q251-8 (the tail and the `repository-changed` text: mv6, L0 `failure`), Q251-11 (lower case: mv1 run 4, L0 `name`, `job`). If the user answers another way, these change.

Not tested: a name with a `.` in the owner (Q251-7); an old name with no release when the registry answers 200 to the `PUT` (the read is `unknown`: mv6 run 3 has it with a 404 answer); a 200 for an offer (Q251-12); `--to ""` (the L2 harness drops an empty word); a 400, 405, 413 or 415 (the code of `Registry.refuse` has its own tests).

## 5. Output (proposed, TW24)

The 3 first texts are the catalog row `move` (CLI 3). The others are proposals.

| Item | Proposal |
| --- | --- |
| Moved | `moved: <old> to <successor>. Users see it in tln outdated, and follow it with tln update <alias>.` (the catalog) |
| Offered | `offered: <old> to <new>. To accept, run tln move <old> in a workflow_dispatch job of <new>.` (the catalog) |
| Removed | `removed: the successor of <old>` (the catalog) |
| Unchanged, `PUT` | `unchanged: <old> has the successor <successor> already` |
| Unchanged, `DELETE` | `unchanged: <old> has no successor` |
| `--json` `data` | `name` (the old name, lower case, from the answer item), `result` (`moved`, `offered`, `removed`, `unchanged`), `successor` (the item `successor`, or `null`), `offer` (the offered name for `offered`, else `null`), `state` (the item `state`), in this order, flat in `data` (the catalog row) |
| No operand | exit 2: `tln move needs an old name: tln move <old-name> [--to <new-name>] [--undo]` |
| 2 or more operands | exit 2: `tln move takes one old name: unexpected '<second>'` |
| `direct` | exit 2: `tln move needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` |
| `--offline` | exit 15: `tln move needs the network: --offline sends no request` |
| Not a full name | exit 2: `the old name '<text>' is not a full github.com name (owner/repo)`, and `the value of --to '<text>' is not a full github.com name (owner/repo)` |
| `--undo` with `--to` | exit 2: `tln move --undo takes no --to` |
| No repository | exit 2: `GITHUB_REPOSITORY is not set or is empty. tln move runs in a GitHub Actions job.` and `GITHUB_REPOSITORY is <value>, not of the form owner/repo.` |
| J is the old name, no `--to` | exit 2: `the job repository <J> is the old name, so --to <new-name> is needed: tln move <old> --to <new-name> offers the new name` |
| `--to` equal to the old name | exit 2: `the old name and the new name are the same: <old>` |
| J is neither | exit 2: `the job repository <J> is neither the old name <old> nor the new name <T>. Run tln move in a job of <old> to offer the new name, or in a job of <T> to accept it.` |
| Event | exit 2: `tln move runs in a workflow_dispatch job: GITHUB_EVENT_NAME is <value>` (or `is not set`) |
| Server | exit 2: `tln move runs on github.com only: GITHUB_SERVER_URL is <value>, not https://github.com` (or `is not set`) |
| No OIDC variable | exit 2: `tln move needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.` |
| `--undo` in another job | exit 2: `the job repository <J> is neither the old name <old> nor its successor <S>. Run tln move --undo in a job of one of them.` and `the job repository <J> is not the old name <old>, and <old> has no successor. Run tln move --undo in a job of <old>.` |
| Guard | The texts of `PrivacyGuard.refusal` (exit 2) and `Github.*_failure` (exit 15). |
| R-AP1 no answer, 5xx | exit 15: `the registry <url> (<source>) gave no answer: <why>.` and `the registry <url> (<source>) answered <status>: <detail>.` (R-RG9) |
| Token request | The texts of `Publish.token`. |
| Write refused (exit 20) | `<detail> (<type>). Fix the names or the workflow, then run the command again.` for 403, 404 and 422. For 422 the detail names the check and the modules (Registry slice 247, section 5). `error.details`: `status`, `type`. |
| 403 `repository-changed` | `<detail>. Only the registry operator can change this. Open an issue: <issues_url>` (R-TP12). `error.details`: `status`, `type`. |
| New token refused | exit 20: `<detail> (<type>): the registry refused the new token too.` |
| Retries, no answer | exit 15: `the registry <url> (<source>) gave no answer 4 times: <why>. The move may be done. Run the command again.` (`The offer may be done.`, `The removal may be done.`) |
| Retries, 429, busy, 5xx | The texts of `Publish.failure` (`... after 4 requests. Try again in <n> s.`, `... 4 times. Try again later.`) with the source after the URL. |

Status to exit code (R-E6, `Registry.refuse`; no change of that code): 200, 201, 202: 0. 400, 405, 413, 415: 1 (a fault of tln or a version skew). 401 after the new token, 403, 404, 409, 422: 20. 401 the first time: one new token. 429, 503 busy, 5xx, no answer: the retries, then 15. A body that does not decode: 15.

## 6. Out of scope

| Item | Reason |
| --- | --- |
| `tln update` and `tln outdated` following or showing the successor | Slice 252 (done). |
| The `owner_changed` note (R-PU30) | A known gap (Design Q632). |
| The operator key (R-YK2) | The CLI never sends it. |
| A move across 2 accounts in one job | R-TP15: the token of the successor accepts an offer. The offer and the acceptance are 2 jobs (finding F2). |
| L3 cases (the real `Fx`) | The Fx calls are the ones of `publish` and `yank`. |

## 7. Questions (stop until answered)

ANSWERED: the user approved all recommendations Q251-1 to Q251-13 (including Q251-4 (a), the fresh R-AP1 read) and all texts of section 5 on 2026-11-17, pending Design Q631 (G-C261). The tests follow them. Each answer is for Design Q631.

| Id | Question | Options | Recommendation and reason | Effect now |
| --- | --- | --- | --- | --- |
| Q251-1 | The design gives no order of the checks of R-MV2 (the list is not an order). | (a) The order of B4: the command line first (direct, offline, operand, names, `--undo` and `--to`), then the environment (job, event, server, OIDC), the names against the job after `GITHUB_REPOSITORY`, then the requests: guard, R-AP1 read, token, write. (b) The order of the list of R-MV2. | (a). Reason: it is the order of `tln yank` and `tln publish`, a check that costs no request comes before a request, and a mistake in the command line shows before a detail of the environment. | mv4, mv5, L0 `plan` follow (a). |
| Q251-2 | R-MV1 says the job repository selects the request. Which job repository can use which flags? | (a) As B5 of this file: J is not O: `--to` is absent or equal to J; J is O: `--to` is needed; `--undo`: any J (Q251-6). (b) J is not O and `--to` is another name: send `{"name": T}` and let the registry answer 403. | (a). Reason: R-MV2 already names these stops (`no --to in a job of <old-name>`, `the job repository is neither`). | L0 `plan`, mv4 runs 15 to 18. |
| Q251-3 | R-MV2 says `GITHUB_EVENT_NAME is not workflow_dispatch` and `GITHUB_SERVER_URL is not https://github.com`. Does an unset or empty variable stop? (`tln yank` has no client check of the event, Design Q629-4; here R-MV2 gives it.) | (a) Yes: unset and empty are not the value. Own text `... is not set`. (b) No: only a set value that differs stops. | (a). Reason: both are always set in a GitHub Actions job, so a missing one means no job, and the OIDC check would stop the run later anyway with a less clear text. | L0 `event`, `server`, mv4 runs 20 and 23. |
| Q251-4 | The catalog row has the result `unchanged`, but the registry answers 200 for a changed and for an unchanged successor (R-AP31). How does the client know? | (a) One R-AP1 read of the old name before the write (fresh, as `tln yank`), only for `PUT` by a job of the new name and for `DELETE`. The `repos` item of the old name gives the successor before. 404 or no item: `unknown`, no `unchanged`. An offer has no read (202 always, the item has no `offer`). (b) No read. 201 is `moved`, 200 of a `PUT` is `moved`, 200 of a `DELETE` is `removed`. `unchanged` leaves the catalog. | (a). Reason: the catalog names `unchanged`, and a lost answer that R-AP34 repeats then reads true. Cost: one request, and a read can fail (exit 15) before the write. The read is needed for Q251-6 too. | mv1, mv3, mv6, mv7, L0 `before` and `answer` follow (a). With (b) they lose the read and the 2 `unchanged` texts. |
| Q251-5 | R-MV3: the guard checks the successor. `--undo` names none. Is J checked when it is the successor? | (a) The guard names the successor of the request: J for a move, T for an offer, nothing for `--undo`. (b) Also check J for `--undo`. | (a). Reason: R-MV3 says "the successor only", and a remove sends no name. The old name is never checked. | mv3 has no guard call. L0 `guarded`. |
| Q251-6 | R-MV1 says `--undo` is for the old name or its successor, and R-MV2 says the job must be one of them. The client knows the successor only after a read. | (a) With the read of Q251-4: for `--undo` in a job that is not O, J must be the successor of the read, else exit 2 with no token. 404 or no item: go on, the registry decides. (b) No client check: the registry answers 403 (exit 20). | (a). Reason: R-MV2 lists the check, the read is there already (Q251-4), and no token is used for a refusal. | mv7, L0 `holder`. |
| Q251-7 | What is a full `github.com` name (R-MV2, R-SC7)? | (a) 2 non-empty parts split by one `/`, each of ASCII letters, digits, `.`, `_`, `-` (as `GITHUB_REPOSITORY` in `tln publish`). A third part, a host, a space or an empty part is not. (b) Also stop an owner with a `.` (a GitHub account has none, and `example.com/x` is a host and a path). | (a). Reason: one rule as `tln publish`, and the registry answers for the rest (422 Index). | L0 `name`. A dot in the owner is not tested. |
| Q251-8 | The texts of a refused write. `Registry.refuse` ends `Fix the release or the workflow, then run the command again.`, which does not fit a move. R-TP12 gives the text of `repository-changed` with `issues_url`, but no CLI code has it. R-MV4 says the message gives the `detail`. | (a) 403, 404 and 422: `<detail> (<type>). Fix the names or the workflow, then run the command again.` and `repository-changed`: `<detail>. Only the registry operator can change this. Open an issue: <issues_url>`. (b) The default text of `Registry.refuse` for all. (c) (a), and `publish` takes the `repository-changed` text too (a later slice). | (a), and (c) as a note. Reason: R-TP12 gives the text. The tail says what the user can change. | mv6 and L0 `failure`. |
| Q251-9 | R-AP34 for the reads: is the R-AP1 read sent again? | (a) No: one request, 429, 5xx or no answer is exit 15 (as `tln yank`). (b) Yes, with the waits. | (a). Reason: R-AP34 names the writes. A read failure costs nothing to repeat by hand, and the write is not sent yet. | mv12. |
| Q251-10 | The text after the last try. R-AP34 says the write may have happened. | (a) `The move may be done.`, `The offer may be done.`, `The removal may be done.` by the plan. (b) One text for all. | (a). Reason: the user needs to know what to look for. | mv11, L0 `failure`. |
| Q251-11 | The case of the names. GitHub names are not case sensitive, and the registry folds them (R-IK2, R-AP56). | (a) Lower case in the URL, the body, the guard file and the output. (b) As typed in the body and the output. | (a). Reason: one key, one text, and the output shows what the registry has. `name` of `--json` is `name` of the answer item. | mv1 run 4, L0 `name`, `job`, `plan`. |
| Q251-12 | The status that `Offer` does not expect: a 200 for an offer (the `PUT` of an old repository answers 202 by R-TP15), or a 201 or 202 for a `DELETE`. | (a) The result follows the plan: an offer is `offered`, a `DELETE` is `removed` or `unchanged`. The status is not checked beyond the 2xx. (b) A status that the plan does not expect is exit 1. | (a). Reason: the state is the truth, the status only says what the registry did. | No test. |
| Q251-13 | Phase marks. R-CM22, the first line of the `tln move` section, the catalog row `move` and R-PH5 say P3. The registry routes are built (Q626), and `tln yank` went to P2 by Q629 (9). | (a) Change them to P2. (b) Keep P3. | (a). Reason: the user ordered the build now, as for `yank`. No text of `tln move` depends on the phase. | No test. The design text table of section 13. |

Readings (the design is clear enough; the human can change them):

| # | Reading | Why |
| --- | --- | --- |
| R1 | `--to` equal to J, in a job that is not the old name, is the same request as no `--to` (R-MV1 row 1). | The table says "No `--to`, or `--to` equal to `$GITHUB_REPOSITORY`". |
| R2 | The check "the old name equals the successor" comes before the job checks (mv4 run 16, and the L0 `plan` row for a third job). | The mistake is in the command line. |
| R3 | An offer (J is the old name) always gives `offered`, also for a repeated offer (the registry gives 202 with no write). | The wire has no member that tells the client. |
| R4 | A `--undo` run needs the OIDC variables, the event and the server checks like each other run. | R-MV2 lists them for the command. |
| R5 | The R-AP1 read is fresh (`Cache-Control: no-cache`), as `tln yank` (Q629-5). | The user may have moved a second ago. |

Findings (not questions):

| # | Finding |
| --- | --- |
| F1 | The R-AP1 route answers 404 for a repository with no indexed release, but R9 of slice 247 says a `repos` row with no release is possible. Then the read is `unknown` and the registry decides: the `PUT` can be 201 (mv6 run 3 has a 404 `PUT`). No test for a 201 after a 404 read: the code treats both the same. |
| F2 | R-TP15 gives the old repository an offer only. A move by one account from the old repository to another repository of the same account needs 2 jobs too: `--to` in the old repository (an offer), and `tln move <old>` in the new one. One job cannot do both. The text of the `J is neither` stop names the 2 jobs. |
| F3 | The R-PU30 note (`owner_changed`) is not shown by `tln move`. The answer item has it, and the client ignores it (Design Q632). |

## 8. Names for the code agent

| Name | Type | Rule |
| --- | --- | --- |
| `MoveCheck` (stub, `cli/lib/MoveCheck.roc`) | The 18 functions of part A with their types and the text of each case in the doc comment: `direct`, `offline`, `operand`, `name`, `flags`, `job`, `plan`, `event`, `server`, `oidc`, `guarded`, `before`, `holder`, `request`, `failure`, `answer`, `lines`, `data`. Types: `Name`, `Plan` (`Set`, `Offer`, `Remove`), `Before` (`Unknown`, `Successor`, `NoSuccessor`), `Done`. | B1 to B14 |
| `MoveFlow` | Part C, `run! : Fx, Args => I32`, the branch `args.command == ["move"]` in `Run.dispatch!`, and `move` in `Opts.reads_registry` | B1 to B14 |

The calls of `MoveFlow.run!`, in order (the `calls.log` of the cases): `env_all!`, `Roots.of_run!`, `read_files!` of `config.toml`, `Net.registry` (as `YankFlow`); `MoveCheck.direct`, `offline`, `operand`, `name` (old), `flags`, `name` (`--to`), `job`, `plan`, `event`, `server`, `oidc` (no call); `PrivacyGuard.check!` with `Repo(<successor>)` for `Set` and `Offer` (`MoveCheck.guarded`); for `Set` and `Remove` the read of R-AP1 for the old name (`RegistryCache.get_needs!`, `newest: true`, with the source) and `MoveCheck.before`; `MoveCheck.holder`; the token request (`Fx.http_send!`, `Publish.token_request`, `Publish.token`); the write (`Fx.http_send!` of `MoveCheck.request`, `Publish.next`, `sleep!`, `MoveCheck.failure`); `MoveCheck.answer`; the output (`lines`, or `Out.json_ok` with `data`). The `calls.log` lines are my best guess, and the code agent may dispute them (section 9).

The names are in lower case from `MoveCheck.name` and `MoveCheck.job` on. `before` for an `Offer` is `Unknown` (the flow makes no read).

## 9. Disputes (from the code agent)

None yet.

## 10. Red results (test agent, 2026-11-17)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-4.roc` | 157 tests: 135 pass, 22 fail, 0 compiler errors | The 22 `expect`s of `MovecheckTest.roc` fail on `crash "todo"` of the stub `cli/lib/MoveCheck.roc`. The other 135 (old tests of the driver) pass. |
| `tests/commands/run.sh move/` | 13 of 13 `move/` cases fail | Exit 1 and `tln: error[internal]: command 'move' is not built yet`. The `Args` parse passes for each command line of each case. (The filter `move/` also runs 3 cases of the group `moves/`: they pass.) |
| `roc fmt --check` | valid | `MovecheckTest.roc`, `MoveCheck.roc`, `l0-4.roc` |
| `MISSING=1 scripts/rules.sh R-MV R-CM22` | no id missing | |

Files changed outside the test tree, needed for the red state of L0: `cli/lib/MoveCheck.roc` (new, a stub of types and `crash "todo"`) and one line `MoveCheck,` in `cli/lib/main.roc` (the list of exposed modules). Without them driver `l0-4.roc` does not compile and its old tests fail too. The code agent replaces the stub. Nobody ran `UPDATE=1`: the expected files are written by `tests/tools/mk-move.py` from this file.

## 11. Verify results

Not done (step 4).

## 12. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 251 | `tln move` | Tests for R-CM22, R-MV1 to R-MV5, R-EC2 (move cases), R-RG9 (move), R-AP34 (move). The pure module `MoveCheck`, the flow `MoveFlow`, the branch in `Run.dispatch!`, `move` in `Opts.reads_registry`. | R-CM22, R-MV1 to R-MV5, R-EC2, R-RG9, R-AP34, R-TP12 | G-C261 (Design Q631) | none / none | 80 | Sonnet |

## 13. Design text changes (pending the answers; for TalonRegistry)

Each row follows the recommendation. A change of an answer changes the row.

| Spot | Old | New |
| --- | --- | --- |
| R-CM22 (`DESIGN-CLI.md` line 30), the last words | `Rules: R-MV1 to R-MV5. Phase P3.` | `Rules: R-MV1 to R-MV5. Phase P2 (Design Q631).` |
| `### tln move`, first line (line 406) | `` `tln move` is P3 (Design 7, R-PH5). `` | `` `tln move` is built in P2 (Design 7, R-PH5, Design Q631): the registry routes are built (Design Q626). `` |
| R-MV1, the `--undo` row | `` `<old-name>` or the successor `` (job repository) | the same, and a sentence after the table: `For --undo in a job that is not <old-name>, the client reads R-AP1 and stops with exit code 2 when the job is not the successor (R-MV2, Design Q631).` |
| R-MV2 | `... the job repository is neither <old-name> nor the successor.` | add: `The checks run in this order: ... (the list of section 4 of docs/slices/251-move.md B4). A GITHUB_EVENT_NAME or GITHUB_SERVER_URL that is not set or is empty is not the value, and stops.` Add `--undo` to the last check: `the job repository is neither <old-name> nor the successor (for --undo, the successor of the old name in the R-AP1 read)`. |
| R-MV3 | `The privacy guard (R-RG6) checks the successor only.` | add: `--undo names no successor, so it has no guard.` |
| R-MV4 | `A refused request gives exit code 20 (rejected, R-E6). The message gives the problem detail: ...` | add: `The text is <detail> (<type>). Fix the names or the workflow, then run the command again.; for 403 repository-changed it is <detail>. Only the registry operator can change this. Open an issue: <issues_url> (Registry R-TP12).` |
| R-MV5 | `The output is in the catalog (section 3, a proposal, R-OUT2).` | add: `Before a PUT by the new name, and before a DELETE, the client reads R-AP1 once (fresh) for the result unchanged (Design Q631).` |
| Catalog row `move` (line 861), the texts | `moved: ...`, `offered: ...`, `removed: ...` | add: `unchanged: <old-name> has the successor <successor> already` and `unchanged: <old-name> has no successor`. |
| Catalog row `move`, last column | `Proposal (R-OUT2), P3` | `Proposal (R-OUT2), P2` |
| R-EC2 (line 766) | `... a check of tln move before it sends (R-MV2), ...` | the same, and `--undo` in a job that is neither (R-MV2) |
| `DESIGN.md` R-PH5 (line 549) | `\| R-PH5 \| P3 \| audit (built in P2, Design Q620; its yank data P2, Design Q629), move \|` | `\| R-PH5 \| P3 \| audit (built in P2, ...) \|` and a row of P2 `move` (Design Q631) |
| `DESIGN-REGISTRY.md` R-AP31 (line 1673) | `The move route (P3).` | `The move route (P2, Design Q626, Q631).` |
| `DESIGN-CLI.md` R-TP12 text (Registry R-TP12) | `` `tln` prints it: ... The text is a proposal. `` | add: `tln publish and tln move print it (Design Q631).` (a later slice makes `publish` do it, Q251-8 (c)) |
| `docs/slices/PLAN-P2-CLI.md` line 47 | `R-MV and R-CM22 (tln move)` in P3 | move to P2, with the row 251 |

## 14. Mutation gaps closed (test agent, 2026-11-17)

| Gap | New test |
| --- | --- |
| G1 | L0 `MoveCheck.answer`: `Set`, `before` `Successor("a/b")`, status 201, item successor `a/b`: `Moved` |
| G2 | L0 `MoveCheck.answer`: `Remove`, `NoSuccessor`, status 204 and 202: `Removed` |
| W1 | L2 `move/mv14-case-fold` |
| W2 | L2 `move/mv15-read-not-retried` |

All pass against the code. Mutants: 14 of 14 caught (`research/slice-251-revert/RESULT.md`). `tests/commands/run.sh move/`: 18 pass.
