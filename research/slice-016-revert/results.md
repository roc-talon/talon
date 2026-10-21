# Revert check of the tests (slice 016, TW12)

A private reference of the slice (`Pick.closure_of` over `Closure.step`, `ResolveBase.need!`, the path files in `pick_loop!` and in the `known` nodes of the walk, the one line of C3) ran the whole fast set green (check, fmt, l0, l2, l3, selftest). `mutate.py` then put 14 small changes in it, one by one, and ran the tests that must fail. The reference is deleted: `cli/` equals the stubs again (`cli-stub.sha256`, checked with `sha256sum`).

| Id | Rules | Mutation | Result |
| --- | --- | --- | --- |
| S1 | R-AL9 R-H7 | the path files are no nodes of the closure | caught by l0:pickclosure, l2:closure/cl2-chain (the pick loop did not end: the case was stopped by hand, counted as a failure) |
| S2 | R-AL9 | the entries that no slot owns are no roots | caught by l0:pickclosure, l2:closure/cl2-chain |
| S3 | R-AL9 | a problem of the closure is no conflict of the tuple | caught by l0:pickclosure |
| S4 | R-AL8 R-DT2 | the step asks only for release URLs, not for path files | caught by l0:pickclosure |
| S5 | R-AL9 | the `Need` list has repeats (`Closure.step` of 2 members names one node twice) | NOT CAUGHT. Equal behavior for one member: `Closure.step` has no repeat. Needs 2 members (question Q1) |
| F1 | R-AL8 | the pick gets no path entries | caught by l2:closure/cl2-chain, l2:resolve/rs-unmanaged, l2:install/in1-flow (first try INVALID: an unused value, made smaller) |
| F2 | R-AD38 R-AL9 | an entry that the run replaces is still a root | caught by l2:resolve/rs-unmanaged, l2:install/in1-flow (first try INVALID, made smaller) |
| F3 | R-AL8 | the walk does not get the path files that the pick read (`install`, `update`) | caught by l2:closure/cl2-chain, l2:install/in1-flow, l2:resolve/rs-unmanaged |
| F4 | R-AL8 | the same for `verify` | first try NOT CAUGHT (cl1-flow has no path entry). Run 7 of `cl2-chain` was added. Then caught by l2:closure/cl2-chain |
| C3 | R-AD31 R-AD38 R-I3 | `--platform` reads the key of `pf`, not of the alias of the entry | caught by l2:resolve/rs-unmanaged (run 12) |
| C21 | R-AD38 R-OV1 | the key of `[overrides]` is ignored | caught by l2:resolve/rs-unmanaged (run 13) |
| C25 | R-AD38 R-J3 | the `from` of a replace has no old value | caught by l2:install/in1-flow (run 7) |
| C27 | R-SL5 R-AD38 | `latest` is a selector for the key range | caught by l2:resolve/rs-unmanaged (run 14) |
| N1 | R-FE1 R-AL8 | the level reads the files in 2 calls | caught by l2:closure/cl2-chain, l2:resolve/rs-unmanaged |

Caught 13 of 14 (S5 is equal behavior for the test input).
