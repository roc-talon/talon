# Slice 039a: revert check of the code agent

Method: `agent-mutate.py` (log: `agent-mutate.log`). Before each mutation the final file is copied from `code-final/` over `cli/lib/`. One small change in one line, `roc check`, then only the tests that must see it (L0 file, or the L2 cases of one dir), dev build, `--no-cache`.
The final file is copied back after each mutation. After the run `sha256sum -c research/slice-039-revert/code-final.sha256` is OK for all files of `cli/lib/`.

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | a compiler that is not installed is askable (`NightlyPlan.pick`, U5 reading (c)) | `nightlyplan.roc` |
| A2 | H is the oldest pin, not the newest (`NightlyPlan.unify`, Q3) | `nightlyplan.roc` |
| A3 | the scan and the lookups use H, not the compiler of the tuple (`Oracle.walked`) | `oraclefree.roc` |
| A4 | no `.last-use` for the other compiler of a probe round (`PickLoop.on_compiler!`, R-CC9) | `upgrade/ur1-roc` |
| A5 | 2 spellings of the started compiler are 2 compilers (`PickLoop.probe_round!`, R-CV1) | `probe/pb1-ladder` (an old case) |
| A6 | the ladder does not start the candidate compiler (`Ladder.run!`) | `upgrade/ur1-roc` |
| A7 | the pin of `Pin.decide` stays an op of the candidate header when the pin moved (`InstallFlow.finish!`, `ladder_decision`) | not caught |
| A8 | `data.downloads` has no download of the plan (`InstallFlow.finish!`) | not caught |
| A9 | N alone is asked as a required download (`NightlyFlow.asked!`, R-NI12, R-DL4) | `upgrade/ur2-consent` |
| A10 | D is not read before the first step of a free compiler (`PickLoop.wants_domain`) | `upgrade/ur1-roc` |
| A11 | the word `roc` is a package name (`PickAsk.asked!`) | `upgrade/ur1-roc` |

Caught 9 of 11.

A7 is a test gap, not an equal change. When the pin moves and a member has no `roc:` entry and has package changes, `decision.writes` has the pin of H, and the candidate header would get 2 pin ops (N' and H). All 24 projects of `ur1-roc` and `ur2-consent` have a pin in each member. A case with an unpinned member and `upgrade roc` or bare `upgrade` that moves the nightly closes it.

A8 is a test gap, not an equal change. `data.downloads` of `--json` is the sum of the downloads of the plan and of the ladder. The only `--json` run (`ur1-roc` run 10) has N installed, so the plan has 0 downloads. A `--json` run that downloads N (or H) closes it.
