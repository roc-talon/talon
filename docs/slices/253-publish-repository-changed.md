# 253 `tln publish`: the `repository-changed` refusal

Phase: P2. Status: done (2026-11-17). Q253-1 to Q253-3 approved by the user (Design Q633, G-C263).
Registry side: nothing to build (R-AP8, R-AP75 row 10, R-TP3 row 5 and R-TP12 are built; the worker cases `publish/tp9-claim-ids` and `identity/tp9-four-rows` have the body). `tln move` has the text since slice 251 (Q251-8, Design Q631). This slice gives it to `tln publish`.

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TP12 | A 403 `repository-changed` has the member `issues_url`. `tln publish` and `tln move` print it. Exit 20 `rejected` (R-E6). The text is a proposal (R-OUT2). |
| R-AP8, R-AP27 | `POST /v1/releases` can answer 403 `repository-changed` (R-TP3 row 5, R-AP75 row 10) before any D1 write. |
| R-E6, R-J7 | Exit 20. `error.details` has `status` and `type`. |
| R-AP34 | A 403 is not retried: one request, no wait, no new token. |
| R-MV4 | The text for `tln move` (the form that is reused). |

## 2. Scope facts

| Fact | Source |
| --- | --- |
| `Publish.failure` builds the text of a publish refusal. It has the cases `label-conflict` and `forbidden`, then `Registry.refuse`. A 403 `repository-changed` gets the last text today: `<detail> (<type>). Fix the release or the workflow, then run the command again.` | `cli/lib/Publish.roc` |
| `MoveCheck.failure` reads `body.extra` (`IssuesUrl(url)`) with `type_text == Problem.type_uri(RepositoryChanged)`. The decode of `issues_url` is built (`records.Problem`). | `cli/lib/MoveCheck.roc` line 263 |
| The body of the worker: `{"type":"/errors/repository-changed","title":"Repository changed","status":403,"detail":"the name taken/repo is bound to another GitHub account (repository id 4001)","issues_url":"https://github.com/roc-talon/talon/issues"}`. | `worker/tests/cases/publish/tp9-claim-ids/expect/responses.jsonl` |
| An existing L0 `expect` (R-E6, R-J7) checks that a 403 `repository-changed` is exit 20, with a body that has no `issues_url`. It stays true. | `tests/unit/PublishTest.roc` |

## 3. Behaviors

| # | Behavior | Rules |
| --- | --- | --- |
| B1 | 403 `repository-changed` with `issues_url`: the message is `<detail>. Only the registry operator can change this. Open an issue: <issues_url>`. Exit 20. | R-TP12, R-E6 |
| B2 | `--json`: `ok` false, `error.kind` `rejected`, `error.code` 20, the same message, `details` `{"status": 403, "type": "/errors/repository-changed"}`. stderr has the `tln: error[rejected]: ...` line. | R-J7, R-OUT2 |
| B3 | One request, no wait, no new token. | R-AP34 |
| B4 | The `issues_url` text is for the type `repository-changed` only. A 403 `forbidden` keeps its text (`Run tln publish in a job for the tag.`), also when the body has `issues_url`. | R-TP12 |
| B5 | A 403 `repository-changed` with no `issues_url`: the text of `Registry.refuse` (Q253-3). | R-TP12 |

## 4. Tests

| Layer | Case | Checks | B |
| --- | --- | --- | --- |
| L0 | `tests/unit/PublishTest.roc` (driver `l0-6.roc`, 3 new `expect`s): `failure` of 403 `repository-changed` with `issues_url` (text, exit 20, `details`); the same after 4 requests, and a 403 `forbidden` with `issues_url` keeps its text; no `issues_url` | R-TP12, R-E6, R-J7, R-AP34 | B1, B3, B4, B5 |
| L2 | `publish/pu30-repository-changed`: run 1 text; run 2 `--json`; run 3 with no `issues_url`. One `POST` each, no second one. | R-TP12, R-E6, R-AP22, R-J7, R-AP34, R-OUT2 | B1, B2, B3, B5 |

Tests that follow a recommendation: Q253-1 (the text of B1), Q253-2 (`details` has no `issues_url`), Q253-3 (B5). If the user answers another way, these change.

## 5. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 403 `repository-changed` | `<detail>. Only the registry operator can change this. Open an issue: <issues_url>` (the text of R-TP12 and of `tln move`, no change). Example: `acme/json is bound to another GitHub account (repository id 812345). Only the registry operator can change this. Open an issue: https://github.com/roc-talon/talon/issues` |
| `--json` | `error.details`: `status`, `type` (Q253-2). |

## 6. Questions

ANSWERED: the user approved Q253-1 to Q253-3 as recommended on 2026-11-17 (Design Q633).

| Id | Question | Options | Recommendation and reason | Effect now |
| --- | --- | --- | --- | --- |
| Q253-1 | The text for `publish`. R-TP12 gives the form `<detail>. Only the registry operator can change this. Open an issue: <issues_url>`, as a proposal, for both commands. | (a) The same text as `tln move`. (b) A text with an advice for a publisher (for example `Release again after the operator has changed the binding.`). | (a). Reason: R-TP12 gives one form for both commands, and the human approved it for `move`. | L0 and L2 pu30 runs 1, 2. |
| Q253-2 | Does `issues_url` go into `error.details` (R-J7 says `status` and `type`; the design is silent on more)? | (a) No: the URL is in `message`; `details` has `status`, `type` (as `tln move`, mv6 run 4). (b) Yes, a member `issues_url`. | (a). Reason: one `details` form for all refusals, and the URL is in the message already. | L2 pu30 run 2. |
| Q253-3 | 403 `repository-changed` with no `issues_url` (the Worker setting `ISSUES_URL` is not set, or an old registry). R-TP12 says the answer "has" the member, so this is not a case of the design. | (a) The text of `Registry.refuse`: `<detail> (<type>). Fix the release or the workflow, then run the command again.` (as `MoveCheck.failure`). (b) The text of B1 without the last sentence. | (a). Reason: it is the code of `tln move` and the text of today, so nothing new to decide. | L0 third `expect`, L2 pu30 run 3. |

Findings (not questions):

| # | Finding |
| --- | --- |
| F1 | 403 `repository-changed` is also the answer of R-TP3 row 5 at the start of the order of R-AP75, so no earlier request of the publish can hide it. |

## 7. Names for the code agent

| Name | Change | Rule |
| --- | --- | --- |
| `Publish.failure` (`cli/lib/Publish.roc`) | One more case: type `repository-changed` with `body.extra` `IssuesUrl(url)`: message B1, other fields of `refused`. Update the doc table of `failure`. No new function: `MoveCheck.failure` may call the same helper. | B1 to B5 |

No stub was needed: the 3 L0 `expect`s use `Publish.failure`, which exists.

## 8. Disputes (from the code agent)

None yet.

## 9. Red results (test agent, 2026-11-17)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-6.roc` | 168 tests: 166 pass, 2 fail, 0 compiler errors | The first 2 new `expect`s fail: the message is the generic text. The third (no `issues_url`) passes: it pins the text of today. |
| `tests/commands/run.sh publish/pu30` | 1 case fails | Only the text of runs 1 and 2 differs (stdout and stderr). `calls.log`, exit codes and the tree match: the flow is right. |
| `roc fmt --check` | valid | `PublishTest.roc` |

Nobody ran `UPDATE=1`. The expected files of `pu30` were written by hand from section 5 (the `calls.log` is the one of `pu9-refused` run 1, 3 times; it matched). Case files are a copy of `pu9-refused` with the answers 403 `repository-changed`.

## 10. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 253 | `tln publish`: `repository-changed` text | Tests for R-TP12, R-E6, R-J7 (publish). One case in `Publish.failure`. | R-TP12, R-E6, R-J7, R-AP34 | G-C263 (Design Q633) | none / none | 10 | Sonnet |

## 11. Design text changes (pending the answers; for TalonRegistry)

| Spot | Old | New |
| --- | --- | --- |
| `DESIGN-REGISTRY.md` R-TP12 | `` `tln publish` and `tln move` print it (Design Q631; `publish` in a later slice): `` | `` `tln publish` and `tln move` print it (Design Q631, Q633; `publish` is built in slice 253): `` |
| `DESIGN-CLI.md` R-PUB (the refusal text of `publish`, near R-E6) | no text for 403 `repository-changed` | add: `For 403 repository-changed the message is the one of R-MV4 (Registry R-TP12).` |
| `DESIGN.md` Q633 | new row | `G-C263: the text of the 403 repository-changed refusal of tln publish (Registry R-TP12; CLI slice 253)? Q253-1 to Q253-3, as recommended.` (after the answers) |

## 12. Mutation gap closed (test agent, 2026-11-17)

| Gap | New test |
| --- | --- |
| G1 (`Registry.operator_text` ignores the type) | L0 `RegistryTest.roc` (`l0-8`): `forbidden` and `label-conflict` with `issues_url` give `Err(None)`. L0 `MovecheckTest.roc` (`l0-4`): a 403 `forbidden` with `issues_url` gives the generic text. Mutant w1 is caught (`research/slice-253-revert/RESULT.md`). |
