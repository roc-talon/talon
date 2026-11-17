# Slice 251 mutation check (TW12, `tln move`, R-CM22, R-MV1 to R-MV5, Q631)

Script: `research/slice-251-revert/mutate.sh [mutant names]` (pattern of slice 250; `pyrep.py` does the multi-line edits of v1, v2 and v9). Log: `run.log`. Each mutant is an edit of a mirror (`.tmp/slice-251-mut/`, deleted at the end; the working tree is not changed); a check reports "SED DID NOT APPLY" when an edit changes nothing (none did). Compiler: `$ROC` of `scripts/env.sh`. Each test run holds `.tmp/heavy.lock` and runs capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one at a time. Tests per mutant: the `l0-4` driver (MovecheckTest) and `tests/commands/run.sh move/ yank/ publish/`. In `run.log` a failed expect prints `exit=1 ... 0 compiler errors`; a pass prints `All (157) tests passed`. Baseline: l0-4 157 passed, L2 60 passed. No cap hit, no loop.

Result: 14 mutants. 12 caught, 2 NOT caught (v8, v8b), both of them very probably equivalent in practice (see the table). v1, v2, v6, v10 are caught at L2 only (flow code); v11 at L0 only.

| # | Mutant (place) | Behavior | Result |
| --- | --- | --- | --- |
| v1 | `MoveFlow`: the job is checked before the value of `--to` | Q251-1 order | caught: L2 move/mv4-usage-stops |
| v2 | `MoveFlow`: the OIDC variables are checked before the job | Q251-1 order | caught: L2 mv4-usage-stops |
| v3 | `MoveCheck.plan`: the old name's job with `--to` sets (no offer) | Q251-2 | caught: l0-4, L2 mv2-offer, mv6-refused, mv11-retries-exhausted |
| v4 | `plan`: another job with `--to` that is not itself is accepted | Q251-2 | caught: l0-4, L2 mv4-usage-stops |
| v5 | `holder`: `--undo` from any job is accepted | Q251-6 | caught: l0-4, L2 mv7-undo-holder |
| v6 | `MoveFlow`: an offer reads R-AP1 too | Q251-4 | caught: L2 mv2-offer, mv6-refused, mv11-retries-exhausted (the calls differ) |
| v7 | `guarded`: the privacy guard also asks for `--undo` | R-MV3, Q251-5 | caught: l0-4, L2 mv3, mv6, mv7, mv8, mv9, mv10, mv11 |
| v8 | `answer`: `unchanged` for a set without the 200 status | `unchanged` detection | NOT caught (equivalent in practice, see below) |
| v8b | `answer`: a removal with no successor is always `unchanged` | `unchanged` detection | NOT caught (equivalent in practice, see below) |
| v9 | `before`: a 404 read gives `NoSuccessor` (not `Unknown`) | Q251-4 | caught: L2 mv7-undo-holder |
| v10 | `send!`: a 202 is not Done | R-TP15 | caught: L2 mv2-offer |
| v11 | `name`: the old name keeps its case | Q251-11 | caught: l0-4 only (L2 passes: no case types a mixed-case old name, W1) |
| v12 | `failure`: `repository-changed` gets the generic refusal text | Q251-8 | caught: l0-4, L2 mv6-refused |
| v13 | `failure`: the offer says "The move may be done." | Q251-10 | caught: l0-4, L2 mv11-retries-exhausted |

## The two that were not caught

| # | Mutant | Why | Suggested test |
| --- | --- | --- | --- |
| G1 | v8 (`Set`, `before` is `Successor(s)`, the answer has the same successor, status is not 200) | The code says `Unchanged` needs status 200 (a 201 means "created"). A 201 with a successor that equals the old one cannot come from the registry: the item already had it. Only a race gives it. No test builds that answer. | L0 `MoveCheck.answer`: `Set`, `before` `Successor("a/b")`, status 201, item successor `a/b`: expect `Moved`. (Pins the rule; the mutant is equivalent for a real registry.) |
| G2 | v8b (`Remove`, `before` is `NoSuccessor`, status is not 200) | The registry answers a `DELETE` with 200 only. | L0 `MoveCheck.answer`: `Remove`, `NoSuccessor`, status 204 or 202: expect `Removed`. Same remark. |

Both are an L0 pin of a status rule; no L2 case can reach them with a fake registry that behaves as the real one.

## Weak spots

| # | Note | Suggested test |
| --- | --- | --- |
| W1 | v11: lower-case names are tested at L0 only. | L2 `move/`: `GITHUB_REPOSITORY=Acme/OLD` and `tln move Acme/Old --to Acme/New`. Expect the request URL in lower case in `calls.log`. |
| W2 | The behavior "the read is not retried" (Q251-9) has no mutant: the read goes through `RegistryCache.get_needs!`, which is shared with `yank`, and a sed of it changes `yank` too. | An L2 case: R-AP1 read answers 503 once, then 200. Expect exit 15 (no second read) in `move/` (a copy of `yank/yk11`). |

## Second run: the gaps closed (test agent, 2026-11-17)

New tests: L0 expect "G1, G2" in `MovecheckTest.roc` (23 expects now); L2 `move/mv14-case-fold` (W1), `move/mv15-read-not-retried` (W2). Before the run: `l0-4` 158 of 158 pass, `tests/commands/run.sh move/` 18 of 18 pass (13 + 2 new + 3 of `moves/`), both on the real code. The other 13 cases are byte-identical to the first generation.

Run: `mutate.sh v8 v8b v11`.

| # | Result |
| --- | --- |
| v8 | CAUGHT: `l0-4` exit 1 (the G1 expect fails). L2 all pass (as predicted: L0 pin) |
| v8b | CAUGHT: `l0-4` exit 1 (the G2 expect fails). L2 all pass |
| v11 | CAUGHT at L0 and now also at L2: `move/mv14-case-fold` fails |

Result: 14 of 14 mutants caught. W2 (the read is not retried) has no mutant (shared `RegistryCache.get_needs!` code); `mv15` pins the behavior with a second answer that a retry would get.
