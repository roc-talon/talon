# Slice 059 revert check (code agent)

Script: `agent-mutate.py` (8 mutations, L0 then L2 then L3, filtered). Log: `agent-run.log`. The code is the same as `code-final/` (`sha256sum -c code-final.sha256` passes).

| Mutation | Result |
| --- | --- |
| m1 a key also matches the repo name of an app | killed by l0 |
| m2 the first entry of an app wins (no `Many`) | killed by l0 (the first try did not compile: redundant branch, changed to remove both branches) |
| m3 a selector does not stop the walk | killed by l2 |
| m4 no record of the project files | killed by l2 |
| m5 the table of the file, not of `tools_dir` (OP4) | killed by l2 |
| m6 the words after `--` lose the first one (first try did not compile: unused variable) | killed by l2 |
| m7 the note for the form `<key>` too (D3) | killed by l2 |
| m8 a standalone file records `talon.toml` in place of `main.roc` (NC1) | killed by l2 |

Caught 8 of 8.
