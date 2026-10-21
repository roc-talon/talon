# Revert check of the code (slice 016, TW12)

`code-mutate.py` puts one small change in the green code, runs the tests that must fail, and puts the code back. A run that does not end (a pick loop with no end) was stopped by a watchdog after 150 s: a failure of that test. The code after the mutations equals the copy before them (`diff -r`, 0 differences).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| P1 | R-AL9 R-H7 | `Pick.step`: the path files are no nodes of the closure | caught by l0:pickclosure, l2:closure/cl2-chain (the loop did not end: stopped, counted as a failure) |
| P2 | R-AL9 | the entries that no slot owns are no roots | caught by l0:pickclosure, l2:closure/cl2-chain |
| P3 | R-AL9 R-PH10 | a `Fail` of `Closure.step` is no conflict of the tuple | caught by l0:pickclosure |
| P4 | R-AL8 R-DT2 | the `Need` list has no path file | caught by l0:pickclosure, l2:closure/cl2-chain |
| P5 | R-AL9 | the `Need` list of 2 members has repeats | NOT CAUGHT. Equal behavior for one member. Needs 2 members (Q1, slice 017) |
| P6 | R-AL9 | no dummy member: no closure check when `unmanaged` is empty | caught by l0:pickclosure, l0:pick |
| P7 | R-C3 R-AL9 | the platform entry of a release is no edge of the closure | NOT CAUGHT. The pairwise check of R-C3 (`conflict_from`) finds the same conflict first. `Mvs` `PlatformMismatch` is tested in `closure.roc` |
| P8 | R-FE1 | the entries of the member come before the slot URLs (the `Need` order) | caught by l0:pickclosure |
| P9 | R-C3 | the slot entries lose `is_platform` | NOT CAUGHT. Same reason as P7 (one platform slot: the pairwise check finds it) |
| P10 | R-PH10 | `Done` with a node that has no fact | caught by l0:pickclosure, l0:pick |
| P11 | R-AL9 | only the first member is checked | NOT CAUGHT. Needs 2 members (Q1, slice 017) |
| F1 | R-AL8 | the pick gets no path entries | caught by l2:closure/cl2-chain, l2:resolve/rs-unmanaged, l2:install/in1-flow |
| F2 | R-AD38 R-AL9 D6 | an entry that the run replaces is still a root | caught by l2:resolve/rs-unmanaged, l2:install/in1-flow |
| F2b | R-AL9 D6 | the replaced alias is dropped in every member, not only in the current one | NOT CAUGHT. Needs 2 members with the same alias (Q1, slice 017) |
| L1 | R-AL8 | `PickLoop.run!` does not keep the path files | caught by l2:install/in1-flow (not by cl2-chain, rs-unmanaged) |
| L2 | R-AL8 | `PickLoop.run!` gives no path files to the caller | caught by l2:closure/cl2-chain, l2:install/in1-flow, l2:resolve/rs-unmanaged |
| F3 | R-AL8 | the walk of `install` and `update` gets no path files of the pick | caught by l2:closure/cl2-chain, l2:install/in1-flow, l2:resolve/rs-unmanaged |
| F4 | R-AL8 | the same for `verify` | caught by l2:closure/cl2-chain |
| G1 | R-FE1 R-AL8 | `Gather.get!` reads the files in 2 calls | caught by l2:closure/cl2-chain, l2:resolve/rs-unmanaged |
| G2 | R-DI7 R-AL8 | `Gather.get!` downloads nothing | caught by l2:closure/cl2-chain, l2:closure/cl1-flow |
| G3 | R-FE7 | a file that cannot be read has kind `Input`, not `Environment` | NOT CAUGHT. No test reads a missing path file (Q2 of the slice: no test) |
| C3 | R-AD31 R-AD38 R-I3 | `--platform` reads the key of `pf`, not of the alias of the entry | caught by l2:resolve/rs-unmanaged (run 12) |
| C21 | R-AD38 R-OV1 | the key of `[overrides]` is ignored | caught by l2:resolve/rs-unmanaged (run 13) |
| C25 | R-AD38 R-J3 | the `from` of a replace has no old value | caught by l2:install/in1-flow (run 7) |
| C27 | R-SL5 R-AD38 | `latest` is a selector for the key range | caught by l2:resolve/rs-unmanaged (run 14) |

Caught 20 of 26. Not caught: P5, P11, F2b (need 2 members: Q1, slice 017), P7, P9 (the pairwise check of R-C3 covers them), G3 (no test of an unreadable path file).
