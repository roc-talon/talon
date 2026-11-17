# Slice 253 mutation check (TW12, `tln publish` 403 `repository-changed` text)

Script: `research/slice-253-revert/mutate.sh [mutant names]` (pattern of slice 251; `pyrep.py` does the multi-line edit; w3b edits two files). Log: `run.log`. Each mutant is an edit of a mirror (`.tmp/slice-253-mut/`, deleted at the end; the working tree is not changed). Compiler: `$ROC` of `scripts/env.sh`. Each test run holds `.tmp/heavy.lock` and runs capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one at a time. Tests per mutant: the `l0-6` and `l0-4` drivers and `tests/commands/run.sh publish/ move/`. In `run.log` a failed expect prints `exit=1 ... 0 compiler errors`; a pass prints `All (N) tests passed`. Baseline: l0-6 168 passed, l0-4 158 passed, L2 49 passed. No cap hit, no loop.

Result: 5 mutants (the 4 asked, and w3 split in two). 3 caught, 1 NOT caught (w1), 1 equivalent (w3).

| # | Mutant (place) | Result |
| --- | --- | --- |
| w1 | `Registry.operator_text` ignores the type: any problem with `issues_url` gets the text | NOT caught (G1) |
| w2 | `operator_text` with no `issues_url` still gives a text | caught: l0-6, L2 publish/pu30-repository-changed |
| w3 | `Publish.failure` calls `operator_text` before `forbidden` | EQUIVALENT: `operator_text` checks the type itself, so a `forbidden` problem gets `Err(None)` from it and falls on to the `forbidden` branch. The order of the two branches does not change any answer |
| w3b | the same, and `operator_text` has no type check (so a `forbidden` with `issues_url` gets the operator text) | caught: l0-6 (the `forbidden` row). L2 passes |
| w4 | the message drops the `issues_url` | caught: l0-6, l0-4, L2 pu30-repository-changed, move/mv6-refused |

## Gap

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | w1 | No test has a problem of another type that carries `issues_url` (a `forbidden`, a `label-conflict`, or a 5xx busy problem with an `issues_url` member). The type check of `operator_text` is never the deciding one. | L0 `Registry.operator_text` (and one `Publish.failure` expect): a body of type `/errors/forbidden` with `extra: IssuesUrl("https://...")` expects `Err(None)` (so the `forbidden` text stays), and the same for `/errors/label-conflict`. Note that w3b is caught only because the `forbidden` row of l0-6 has an `issues_url`; w1 passes because `Publish.failure` tests the label-conflict and forbidden types before `operator_text`, and `MoveCheck.failure` has no row of that kind. A `MoveCheck.failure` expect with a `/errors/forbidden` body that has `issues_url` closes it. |

## Gap G1 closed (test agent, 2026-11-17)

New tests: L0 `RegistryTest.roc` (driver `l0-8`): `operator_text` of a `forbidden` and of a `label-conflict` problem with `issues_url` is `Err(None)`, and `repository-changed` gives the text. L0 `MovecheckTest.roc` (driver `l0-4`): `MoveCheck.failure` of a 403 `forbidden` with `issues_url` gives the generic text. Both pass against the code (l0-8 192 passed, l0-4 159 passed; no code bug).

`mutate.sh w1` (L0F=l0-8 and l0-4, L2=0): CAUGHT. `l0-8: exit=1`, `l0-4: exit=1`. No cap hit.
