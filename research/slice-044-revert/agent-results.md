# Revert check of slice 044 (code agent)

| Id | Mutation | Result |
| --- | --- | --- |
| Z1 | ZIG is checked for the series (R-D1, Q1) | caught (exit 1) by tests/commands/run.sh zig/zs1-search |
| Z2 | the oldest fitting installed dir wins | caught (exit 1) by tests/commands/run.sh zig/zs1-search |
| Z3 | the newest installed dir is chosen in text order (0.18.9 over 0.18.10) | caught (exit 1) by tests/commands/run.sh zig/zs1-search |
| Z4 | the sha256 check does not stop the install | caught (exit 1) by tests/commands/run.sh zig/zi1-install |
| Z5 | the keys of the 2 macOS hosts are swapped | caught (exit 1) by tests/commands/run.sh zig/zi2-xz |
| Z6 | the interactive default of the prompt is No | caught (exit 1) by tests/commands/run.sh zig/zi1-install |
| Z7 | non-interactive with no --yes stops (the prompt is Required) | caught (exit 1) by tests/commands/run.sh zig/zi1-install |
| Z8 | no xz check under the lock | caught (exit 1) by tests/commands/run.sh zig/zi2-xz |
| Z9 | no check for the dir under the lock | caught (exit 1) by tests/commands/run.sh zig/zi1-install |
| Z10 | a No answer does not stop the install | caught (exit 1) by tests/commands/run.sh zig/zi1-install |
| Z11 | any non-empty shasum text is accepted | caught (exit 1) by test tests/unit/l0-6.roc |
| Z12 | stale temps are not deleted | caught (exit 1) by tests/commands/run.sh zig/zi1-install |

Code after the runs: same as code-final (sha256sum -c: all OK)
