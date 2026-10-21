# Red output of slice 016 (test agent, 2026-10-21)

`scripts/test.sh` with `cli/` equal to the stubs (`cli-stub.sha256`), pinned roc.

| Step | Result |
| --- | --- |
| `check`, `fmt`, `l3` (26 pass, 1 skipped), `selftest` | pass |
| `l0` | 1 file fails: `tests/unit/pickclosure.roc`, 3 of 4 expects (the changed cycle row, the new expect 3, the new expect 4). The other 48 files pass (also `pick.roc`, `closure.roc`) |
| `l2` | 28 pass, 4 fail: `closure/cl2-chain`, `install/in1-flow`, `resolve/rs-install-add-key`, `resolve/rs-unmanaged` |

L0 reasons (all a wrong value, no "todo"):

| Row | Stub gives | Test wants |
| --- | --- | --- |
| cycle between packages | `Done(mid 1.0.0)` | no tuple (`no tuple works: the releases of mid do not fit together (R-C2, R-C3)`) |
| path expect, round 1 | `Need([json 2.1.0])` | `Need([json 2.1.0, "/p/util/main.roc"])` |
| path expect, other rows | the path file is never needed, so json 2.1.0 is kept | json 2.2.0 after the file is read (the probable bug) |
| content conflict, `Highest` | `Done(web 2.0.0, Move 1.0.0)` | `Done(web 1.0.0, Keep)` |
| held web 2.0.0 | `Done(web 2.0.0, Keep)` | no tuple |

L2 reasons:

| Case | Stub gives | Test wants |
| --- | --- | --- |
| `cl2-chain` run 5 (p4, the probable bug) | exit 10, `$PROJECT/p4/util/main.roc needs acme/core 1.1.0, but the header names acme/core 1.0.0` (the failure of the walk after the pick). The bug is real | exit 0, `~ core: acme/core 1.0.0 -> 1.1.0` |
| `cl2-chain` run 6 (p5) | the same failure of the walk | `no tuple works: the releases of core, pf do not fit together (R-C2, R-C3)` |
| `cl2-chain` run 7 (verify, p4) | prints the move (run 5 did not write) | no move line |
| `rs-unmanaged` run 12 (C3) | `acme/pf 0.1.1` (the key of `base` is not read) | `acme/pf 0.1.0` |
| `rs-unmanaged`, `in1-flow`, `rs-install-add-key` | the read of the path file is a second `read_files` call | the file is in the one read of the first level (D5) |
| `rs-unmanaged` runs 13, 14 (C21, C27), `in1-flow` run 7 (C25) | pass (gap tests: only a mutation fails them) | |
