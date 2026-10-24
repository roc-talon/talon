# Slice 039b: revert check of the code agent

Method: `agent-mutate.py` (filtered runs only). Code copy: `code-final/` and `code-final.sha256`. Each mutation starts from the copy, and the copy is put back after it. Final compare: SAME (`agent-mutate.log`).

| Id | Mutation | Test that failed |
| --- | --- | --- |
| A1 | a skip removes only the wanted compilers (the line shows again) | L2 `upgrade/ur5-optional` |
| A2 | `--allow-downloads` is an opt-in | L2 `upgrade/ur5-optional` |
| A3 | `--dry-run` does not answer No | L2 `upgrade/ur5-optional` |
| A4 | a failed try does not count for the cap | L2 `upgrade/ur5-optional` |
| A5 | the download is made before the budget check | L2 `upgrade/ur5-optional` |
| A6 | the cap does not count the tries of earlier rounds | L2 `upgrade/ur5-optional` |
| A7 | `data.downloads` does not count the optional downloads | L2 `upgrade/ur5-optional` |
| A8 | an installed optional compiler is no value of the compiler slot | L2 `upgrade/ur5-optional` |
| A9 | the cap note shows also when the cap is 0 | L2 `upgrade/ur5-optional` |
| A10 | an installed compiler is optional | L0 `nightlyplan.roc` |

Caught 10 of 10. No mutation was missed, so there is no test gap and no equivalent change to report.
