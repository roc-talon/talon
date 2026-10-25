# Slice 046 revert check (code agent)

Script: `research/slice-046-revert/agent-mutate.py`. Each mutation breaks `cli/lib` in one small way, runs only the test that must see it, and puts the file back. After the run `sha256sum -c research/slice-046-revert/code-final.sha256` is OK (the code is the same as before the mutations).

| # | Mutation | Test that must see it | Result |
| --- | --- | --- | --- |
| 1 | no early check of the bin dir entry (before the download and the build) | L2 tool/ti2-refusals run 10 | caught: FAIL tool/ti2-refusals; commands: 0 passed, 1 failed |
| 2 | no check of the bin dir entry under the lock | L2 tool/ti2-refusals run 12 | caught: FAIL tool/ti2-refusals; commands: 0 passed, 1 failed |
| 3 | no binary name check under the lock (a taken name is free) | L2 tool/ti2-refusals run 9 | caught: FAIL tool/ti2-refusals; tln: error[app_error]: the build of acme/broken 1.0.0 with nightly-2026-10-14-38a3029 failed: 5 errors: type mismatch; commands: 0 passed, 1 failed |
| 4 | the lock of tools.json is held during the build (the lock moves from the install to the whole build step) | L2 tool/ti1-install (the lock line is before the probe), L3 step 4 | caught: FAIL tool/ti1-install; commands: 0 passed, 1 failed |
| 5 | native: one wasm name refuses the platform (any for all) | L0 ToolTest 14 | caught: 1 failed; at ToolTest.roc:442 |
| 6 | no check of the platform | L2 tool/ti2-refusals run 11 | caught: FAIL tool/ti2-refusals; commands: 0 passed, 1 failed |
| 7 | min-release-age does not hide a release (no name, no range) | L0 ToolTest 3 | caught: 1 failed; at ToolTest.roc:131 |
| 8 | a replaced tool loses the fields that tln does not know | L0 ToolTest 12 | caught: 1 failed; at ToolTest.roc:385 |
| 9 | a range or @latest keeps the installed version whatever the newest release is | L0 ToolTest 4 | caught: 1 failed; at ToolTest.roc:158 |
| 10 | an entry with no old binary is Talon's | L0 ToolTest 7 | caught: 1 failed; at ToolTest.roc:245 |
| 11 | no lock of tools.json at all for the last step | L2 tool/ti1-install (the lock lines | caught: FAIL tool/ti1-install; commands: 0 passed, 1 failed |

Mutation 4 was also run against L3 (`tests/run.sh tools/ti1-tool-install`): caught (`scenarios: 0 passed, 1 failed`).

Review 2 (installed key, token of the default branch request):

| # | Mutation | Test that must see it | Result |
| --- | --- | --- | --- |
| 12 | the key ignores the installed key | L2 tool/ti1-install run 7 | caught: FAIL tool/ti1-install |
| 13 | the default branch request sends no token | L2 tool/ti2-refusals run 3 | caught: FAIL tool/ti2-refusals |
| 14 | `installed_key` finds no entry (by hand: `Ok(e) => Ok(e.key)` replaced by `Err(None)`) | L0 ToolTest 15 | caught: 1 failed |

Caught 14 of 14. No mutation that no test caught.
