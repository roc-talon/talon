# Slice 036 (a): revert check of the code (code agent)

Script: `agent-mutate.py` (filtered runs, no full sweep). Log: `agent-mutate.log`. The final code is in `code-final/` (`code-final.sha256`, checked from the repo root: all 4 files OK after the run).

| Id | File | Change | Result |
| --- | --- | --- | --- |
| A1 | Oracle | a closure problem gives `Fail` | CAUGHT `pickclosure` |
| A2 | Oracle | `conflicts: []` (no pair conflict) | CAUGHT `oracle` (timeout) |
| A3 | Oracle | no movable names | CAUGHT `pickmoves` |
| A4 | Oracle | a movable slot is open without `second` | CAUGHT `pickmoves` |
| A5 | Oracle | the empty fact of a platform slot is a package | CAUGHT `oracle` |
| A6 | Oracle | slot name is `slot.id` | CAUGHT `oracle` |
| A7 | Oracle | `published_at: 0` | CAUGHT `pick` |
| S1 | Solver | `Need` in search order | CAUGHT `moves` |
| S2 | Solver | `Done` in search order | CAUGHT `moves` |
| S3 | Solver | compiler slot is movable | CAUGHT `moves` |

Caught 10 of 10. No mutation was missed, so there is no test gap and no equivalent change to report.
