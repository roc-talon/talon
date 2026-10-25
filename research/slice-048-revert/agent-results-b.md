# Revert check, slice 048 part 048b (code agent)

| Mutation | Caught by |
| --- | --- |
| M1 rm writes tools.json before it deletes the files (D12) | l2 tm1-manage: FAIL |
| M2 rm deletes a bin dir entry that is not Talon's (R-ST11) | l0 tests/unit/l0-3.roc: new failing lines [157] |
| M3 rm takes no lock of tools.json (R-CC6) | l2 tm1-manage: FAIL |
| M4 rebuild builds with the pin of the header, not the recorded compiler (R-T5) | l2 tr1-rebuild: FAIL |
| M5 rebuild with no name does not take all tools (D1) | l2 tr1-rebuild: FAIL |
| M6 the plan does not stop at the first failure (Q-U2) | l2 tr2-rebuildstops: FAIL |
| M7 the foreign text of rebuild names --as (Q-U3) | l0 tests/unit/l0-4.roc: new failing lines [309] |
| M8 the source of the manifest is read after the check of the bin dir entry (pure checks first) | l2 tr2-rebuildstops: FAIL |
| M9 the downloads count a compiler twice | l0 tests/unit/l0-4.roc: new failing lines [261] |
| M10 the scratch dirs of the git sources are not deleted (R-CC2) | l2 tr1-rebuild: FAIL |
| M11 drop removes the other tools (R-B6) | l0 tests/unit/l0-3.roc: new failing lines [236] |

Caught 11 of 11. Code the same as before: True.
