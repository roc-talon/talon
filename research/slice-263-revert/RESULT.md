# Slice 263 mutation check (test agent, 2026-11-24)

Script: `mutate.sh` (mirror under `.tmp/slice-263-mut`, each build and run capped: 16G, no swap, 600 s, heavy lock). Tests: L2 `registry/op registry/ix6 registry/of registry/ad37 registry/sa6 registry/yf moves/hm1 resolve/rs-unmanaged fetch/ update/au7`, and L0 `l0-5` (IndexTest) for the Index mutants. Logs: `run.log` (round 1), `run2.log` (round 2, the survivors against the gap tests).

Base: all cases of the set pass (`run.log` line 1 also shows 2 gap cases that were half made at that time; they were moved out of the tree for the mutant runs).

| Mutant | Change | Round 1 | Round 2 (gap tests) |
| --- | --- | --- | --- |
| m1 | `newest_admitted` ignores the range (the old code) | killed: op1, op6, op7, op8, hm1, rs-unmanaged; L0 | |
| m2 | a tie on `published_at` takes the last | killed: L0 only (no L2 world has a tie) | |
| m3 | `read_admitted!` skips online too | survived: EQUIVALENT. `Fail.missing` is set only by `Fetch.offline_missing`, which `Fetch.start_state` makes only with `offline` (Fetch.roc:198-206). Online, a missing archive is downloaded. | |
| m4 | `read_admitted!` does not skip offline | killed: op2 | |
| m5 | add: all skipped gives the failure of the LAST skipped (Q643-1) | survived | killed: gap test op12 |
| m6 | pick loop: all skipped gives the failure of the LAST skipped | survived | killed: gap test op13 |
| m7 | pick loop skips the current header value | survived | killed: gap test op14 |
| m8 | `read_admitted!` skips ANY offline failure (a broken archive dir) | survived | killed: gap test op10 |
| m9 | outdated skips too (the offline index drops a candidate with no archive, Q643-2) | killed: op9 and 19 more (calls and rows) | |
| m10 | the skipped candidate stays in the rows of the new name | killed: op2 | |
| m11 | pick loop never stops early when no candidate is left in a range (the solver failure, exit 10) | survived | killed: gap tests op11, op13 |

Result: 11 mutants, 10 killed, 1 equivalent (m3). 5 gap tests added (op10 to op14), all pass on the code.
