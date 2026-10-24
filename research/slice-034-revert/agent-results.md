# Revert check of slice 034 (code agent)

Script: `research/slice-034-revert/agent-mutate.py`. Log: `agent-run.log`. 48 small changes of the final code, one at a time, each over a fresh copy of `code-final/`.
Order of checks: `roc check` (0 errors, 0 warnings), the 2 L0 files, then `scripts/test.sh l1` only when L0 did not catch it. A run that does not end is stopped after 30 s (counts as caught).
At the end `sha256sum -c research/slice-034-revert/code-final.sha256` (from the repo root) gives OK for both files.

Result: 43 of 48 caught by L0. 5 not caught by L0 or L1.

| Id | Change | Result |
| --- | --- | --- |
| m01 | Highest and Lowest swapped | L0 |
| m02 | a tie in the reverse byte order | L0 |
| m04 | ranges: any in place of all | L0 |
| m05 | a yanked release is a value | L0 |
| m07 | young: `>=` | L0 |
| m08 | young: not applied | L0 |
| m09 | late: `>=` | L0 |
| m10 | snapshot ignored | L0 |
| m11 | the header value is hidden when young or late | L0 |
| m12 | the header value is not added | L0 |
| m13 | a range does not exclude the header value | L0 |
| m14 | a named version is never exempt | L0 |
| m15 | a named version that is yanked is a value | L0 |
| m16 | a named version is exempt from the age only | L0 |
| m17 | the version order reads minor and patch only | L0 |
| m18 | a Package slot takes an App release | L0 |
| m20 | a release with no fact is not fit | L0 |
| m21 | dep: the limit itself is no value | L0 |
| m22 | a dep on the own group is read | L0 |
| m24 | a limit above all values is not read | L0 |
| m25 | the deps are not read | L0 |
| m26 | the platform is not read | L0 |
| m27 | the platform check holds with 2 platform slots (the first) | not caught. Test gap: Q2 (accepted, "no new test"): no row has 2 platform slots |
| m28 | the platform slot's own release is checked against its own `pf` | not caught. Test gap, low value: no design rule gives a platform release a `pf` (D8), so no row and no L1 world has one |
| m29 | the platform check has the wrong sense | L0 |
| m30 | the decision takes the worst value | L0 |
| m31 | learn only the last decision (unsound) | L0 |
| m32 | go back to the same decisions | L0 (timeout: the search does not end) |
| m34 | the depth of a clash is one too low | L0 |
| m35 | the conflicts of the caller are not read | L0 |
| m36 | the sign of a term is swapped | L0 |
| m37 | a conflict with an unknown name applies without that term | L0 |
| m38 | the terms of one variable are not joined | L0 |
| m39 | a term with no value still gives an incompatibility | not caught. Equivalent change: such a term is false in each state, so the incompatibility never fires |
| m40 | unit propagation off | L0 (timeout: the search does not end) |
| m41 | a false term does not stop a propagation | L0 |
| m42 | all terms true is no clash | L0 |
| m43 | a term is true when one place is in the set | L0 |
| m45 | Need names all chosen ids | L0 |
| m46 | Need names the first missing id only | L0 |
| m47 | Done with one fact missing | L0 |
| m48 | Need in the reverse order | L0 |
| m49 | Need names a release twice (no repeat removed) | not caught. Test gap: no row has 2 slots with one release (D11: the caller adds a conflict). The repeat guard is for a caller that does not |
| m51 | the strategy is ignored | L0 |
| m52 | the header value is not passed to the domain | L0 |
| m53 | the ranges are not passed to the domain | L0 |
| m54 | the named version is not passed | L0 |
| m56 | the names of a `Fail` are the other slots | not caught. Test gap by design: `Why` is a placeholder that no test reads (D5) |

Notes: the first m37 text did not compile (a warning, an unreachable pattern). It was replaced and then caught. A mutation that removes unit propagation (m40) does not end, as the slice notes say (N4).
