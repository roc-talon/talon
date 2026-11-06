# 206c Platform entry from the closure answer

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 206c of `PLAN-P2-CLI.md`. Split from Q1 of `206-closure-index.md`. Records slice 104i is green: `Artifact.Dep` has `is_platform : Bool`.

## Scope

| In | Out |
| --- | --- |
| `ClosureIndex.header`: `Release.pf` and `entries[].is_platform` from the `is_platform` mark of each dep | An archive read (none: the answer has the facts) |
| The rule of an app record (no `pf`) and of 2 marks (the first wins) | The platform check of CLI R-C3 in a command (the walk already reads `is_platform` of an entry) |
| | Worker write of the mark (Worker 125) |

## Rules

| Rule | Text | Test (L0, `tests/unit/ClosureindexTest.roc`) |
| --- | --- | --- |
| R-AP81 (client) | `pf` of a package or platform record is the `url` of its dep with the mark. No mark: none | package with one mark; platform record; package with no mark |
| R-AP81, R-RE19, Q402 | The entry has `is_platform` true only for the platform dep (the first marked dep of a package or platform record); every other entry is false | package with one mark; 2 marks |
| R-AP81, Q400, Q401 | An app record gives no `pf`, and every entry flag is false: its mark is not read | app with a mark |
| R-AP81, Design Q400 | 2 or more marks: the first in the order of the answer gives `pf` | 2 marks |
| R-AP49 (Dep), R-C3 | `Release.pf` is the platform edge that R-C3 needs | all of the above |

## Tests

| # | Test | Rules |
| --- | --- | --- |
| 1 | Package record, deps `dep` (no mark) and `pf` (mark): `pf` is its url, entries `[False, True]`, deps in record order | R-AP81, R-RE19, R-C3 |
| 2 | Platform record with a marked dep: `pf` is its url | R-AP81 |
| 3 | App record with a marked dep: `pf` none, deps stay, entries `[False, False]` (Q401) | R-AP81, Q400, Q401 |
| 4 | Package record, marks on `pf` and `pf2`: `pf` is the first, entries `[True, False, False]` (Q402) | R-AP81, Q400, Q402 |
| 5 | Package record, no mark: `pf` none, no entry marked | R-AP81, R-AP49 |

No L2 change. The L2 harness (`al8-closure-facts`) prints no `pf` and no `is_platform` (`fact` and `row` lines have kind, deps, targets, version), so L0 is the only place that shows these facts. No fixture of `mkcases.py` changes and no expected line changes.

## Red state

`ClosureIndex.header` is not stubbed with `crash`: it still gives `pf: Err(None)` and `is_platform: Bool.False` (slice 206). A `crash` would also turn the green tests of slice 206 and the L2 cases red. Tests 1, 2 and 4 fail (3 failures in `l0-8`). Tests 3 and 5 pass today (the stub gives none and false); the mutations below show that they bind.

## Revert check (hand mutations)

Private files: `research/slice-206c-revert/{before,reference,m1..m7.roc,run.sh,results.txt}`. `reference/` is a correct `header` that the test agent wrote for the check only.

| # | Mutation | Failing expects |
| --- | --- | --- |
| M1 | last mark wins for `pf` | 1 |
| M2 | app mark used for `pf` | 1 |
| M3 | mark ignored for `pf` | 3 |
| M4 | entry flag ignored | 3 |
| M5 | `pf` of the first dep, not the marked one | 3 |
| M6 | entry flag is the mark as sent (Q402) | 1 |
| M7 | app entry flag set (Q401) | 1 |

Reference: all pass.

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | An app record with a marked dep: the entry flag? | Answered (Design Q401): every entry flag is false. Test 3 checks it |
| Q2 | 2 marked deps: the entries? | Answered (Design Q402): only the first marked dep has the flag; the second is false. Test 4 expects `[True, False, False]` |

Rule: the platform dep is the first marked dep of a package or platform record, and none for an app record. `pf` and the entry flag both come from it.

## Code (for the code agent)

| File | Change |
| --- | --- |
| `cli/lib/ClosureIndex.roc` | `header`: `pf` from the first dep with `is_platform` for kind `Package` or `Platform` (`Err(None)` for `App` and for no mark); the entry flag true only for the platform dep (Q401, Q402); update the doc table of `header` |

## Code

| File | Change |
| --- | --- |
| `cli/lib/ClosureIndex.roc` | New `platform_dep` (first marked dep of a `Package` or `Platform` record, none for `App` or no mark). `header` takes `pf` and each entry `is_platform` from it (entry flag: alias equals the platform dep alias). Doc table of `header` updated |

Result: `check`, `fmt`, `l2`, `l3` pass. `l0`: `l0-8` all 139 pass; `l0-1` has 7 failures, all `todo: slice 207` (not 206c). Final copy: `research/slice-206c-revert/code-final/`, hash in `code-final.sha256`.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206c-revert/code-final.sha256` | 1 of 1 OK |
| `todo: slice 206c` in `cli/` | None |
| L0 | `l0-8` passes, with the 5 new expects. `scripts/test.sh l0` fails only in `l0-1`, on 7 `todo: slice 207` red tests of the next slice. |
| `scripts/test.sh check fmt l2 l3` | All pass |
| L2 cases | None new: the L2 harness prints no `pf`. |
| Revert check | 7 of 7 caught (test step) |
| Design answers | Q251, Q400, Q401, Q402 |
| Code note | The entry flag compares by alias (aliases are unique in a record). |

