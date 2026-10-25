# Slice 058, revert check of the code agent

Script: `agent-mutate.py` (run from the repo root). Each mutation changes one place of `cli/lib`, checks `roc check cli/lib/main.roc`, runs L0 (`l0-7.roc`), then L2 (`run/rn4`), then L3 (`run/rn2-each`) until one fails, and puts the file back from `code-final/`. After the run `sha256sum -c research/slice-058-revert/code-final.sha256` passes.

| Mutation | File | Result |
| --- | --- | --- |
| m1 ties: the largest ready node first (the list `left` is reversed) | RunEach | killed by L0 |
| m2 a path entry to a file in the directory of a node (no member) gives no edge | RunEach | NOT CAUGHT |
| m3 `after` gives no edge | RunEach | killed by L0 |
| m4 a cycle text starts at the largest node of the group | RunEach | killed by L0 |
| m5 `--keep-going` skips only a direct edge | RunEach | killed by L0 |
| m6 the exit code is the code of the last failure | RunEachFlow | killed by L2 |
| m7 a node that cannot start stops the command (also with `--keep-going`) | RunEachFlow | killed by L2 |
| m8 the args of `--` go to no step | RunEachFlow | killed by L2 |
| m9 a start in a standalone project is no stop | RunEach | killed by L0 |
| m10 the farthest `talon.toml` (not the nearest) is the node of a member file (NC4) | RunEach | killed by L0 |
| m11 the root file may have the table `[run]` | Intent | killed by L0 |

Caught 10 of 11. m2: L0 13 gives the same edge twice (the entry `core` names a member file of `libs/core`, the entry `util` names a non member file in the same directory), so the second rule of Q1 has no test of its own. L2 and L3 have no such entry. Q1 stays untested as the slice file says.
