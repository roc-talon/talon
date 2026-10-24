# Slice 039c: revert check of the code agent

Method: `agent-mutate.py` (filtered runs only). Code copy: `code-final/` and `code-final.sha256`. Each mutation starts from the copy, and the copy is put back after it. Final compare: SAME (`agent-mutate.log`).

| Id | Mutation | Test that failed |
| --- | --- | --- |
| B1 | the lower compilers of a movable compiler are in the order of D, not nearest first | L0 `moves.roc` |
| B2 | a compiler slot with no `current` is movable | not caught |
| B3 | a compiler older than H is a value of the movable nightly | L0 `nightlyplan.roc` |
| B4 | an inferred fail wins over a real row of a later release | L0 `upgrade.roc` |
| B5 | the lag reason is blamed on the chosen compiler, not on N | L0 `upgrade.roc` |
| B6 | the pin of a held nightly move is not written | L2 `upgrade/ur6-moves` |
| B7 | `wide!` reads the compiler list again | L2 `upgrade/ur6-moves` |
| B8 | the installed compilers are read when the list is empty | L2 `upgrade/ug3-move` |
| B9 | a free nightly is a held move | L2 `upgrade/ur6-moves` |
| B10 | the compiler list is not read before the second search | L2 `upgrade/ur6-moves` |

Caught 9 of 10. B2 is a test gap (not an equivalent change): the only row with no `current` in `moves.roc` expect 4 uses `Highest`, where the newest-first order of the mutation equals the order of D. With `Lowest` the order differs (oldest first expected). B3 first did not compile (an unused variable warning), and was rewritten.
