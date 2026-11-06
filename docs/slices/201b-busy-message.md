# 201b Busy registry message

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 201b of `PLAN-P2-CLI.md`. Registry R-AP82 (the answers of a trap) and Design Q440, Q445: a 503 of the type `/errors/busy` is exit 15 at once. A read is not sent again (R-AP34).

## Scope

| In | Out (where) |
| --- | --- |
| `Registry.problem_fail` (and so `Registry.refuse`): the text for a 503 `/errors/busy` | Retry of a write (R-AP34, slice 200) |
| `Retry-After` as in the 429 rule (`wait_text`, whole seconds) | Other commands' output code |

## Rules

R-AP82, R-AP34, R-AP21, R-E6 (a 5xx is exit 15), R-J7, Design Q440, Q445.

## Reading that the tests fix

| # | Case | Result |
| --- | --- | --- |
| 1 | 503, type `/errors/busy`, `retry_after` a whole number (white space cut) | `the registry is busy (503). Try again in <n> s.` |
| 2 | Same, no `retry_after`, empty, `soon`, `1.5` | `the registry is busy (503). Try again later.` |
| 3 | Any method | Exit 15 (`Network`) |
| 4 | `details` | `{"status": 503, "type": "/errors/busy"}` |
| 5 | 503 with another type; 502 or 500 (also with type `/errors/busy`); 503 that is not problem details | The general text, unchanged |

`problem_fail` needs no new signature. The new `expect`s are red until the code step.

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/RegistryTest.roc` (driver `l0-8.roc`): the 15 `expect`s after the comment `Slice 201b` | R-AP82, Q445, R-AP34, R-E6, R-J7 |

## Revert check

`research/slice-201b-revert/results.txt` (mutations by hand, with `before/` the files before them).

## Code

| File | Change |
| --- | --- |
| `cli/lib/Registry.roc` | `problem_fail`: new arm `(503, _)` when `type_text` is `Problem.type_uri(Busy)`: `Network`, `the registry is busy (503). ${wait_text(retry_after)}`. Doc table row added. `details` come from `refuse`, unchanged. |
| Result | `scripts/test.sh check fmt l0`: check and fmt pass. All RegistryTest expects pass. l0-8 has 10 red `QueuesendTest` expects (slice 216, not this slice). |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-201b-revert/code-final.sha256` | 1 of 1 OK (`Registry.roc`) |
| L0 | All `RegistryTest` expects pass (15 new). `l0-8` is red only on `QueuesendTest`, the slice 216 test step in progress. |
| Revert check | 3 of 3 caught |
| Design answers | Q440, Q445 (records 104j) |

