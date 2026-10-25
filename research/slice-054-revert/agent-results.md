# Slice 054: revert check of the code agent (2026-10-24)

Script: `research/slice-054-revert/agent-mutate.py` (log: `agent-mutate.log`). Each mutation changes one place in `cli/lib`, runs `roc check`, then only the tests that must see it. The file is put back from `code-final/`.
The final code is in `code-final/cli/lib/`, with the hashes in `code-final.sha256` (check from the repo root: `sha256sum -c research/slice-054-revert/code-final.sha256`).

| Id | Mutation | Result |
| --- | --- | --- |
| M1 | `host`: glibc before musl (R-TG1 rule 2) | caught: `l0-3`, L2 `target/tg1-ladder` |
| M2 | `pick`: rule 2 takes the order of the platform list, not of the host (R-TG1) | caught: `l0-3` |
| M3 | `pick`: the one platform target wins over `[build] target` (R-TG1 rule 1) | caught: `l0-3` |
| M4 | R-C10: the solver gets the facts with no `gate` | caught: L2 `target/tg3-constraint` |
| M5 | R-C10: no release is exit 2, not exit 10 | caught: `l0-3`, L2 `target/tg3-constraint` |
| M6 | R-TG5: the member file has no target (`member_target` is always `Unset`) | caught: L2 `target/tg2-workspace`, `target/tg1-ladder` |
| M7 | R-TG4: the `[build]` of a package file is exit 19 | caught: `l0-3`, L2 `target/tg1-ladder` |
| M8 | R-TG2: the build gets no `--target`, but the key has the target | caught: L2 `target/tg1-ladder`, `target/tg2-workspace` |
| M9 | R-C10: the platform of the header is not read first (`unread_current` off) | caught: L2 `target/tg3-constraint`, `target/tg2-workspace` |
| M10 | R-TG2: `--target` at the end of the arguments | caught: `l0-3`, L2 `target/tg1-ladder` |

Caught 10 of 10. After the run, `cli/lib` equals `code-final/` (the script compares each file) and `sha256sum -c` passes.
Not mutated: R-TG6 (the proxy has no target). The proxy code has no target input, so a mutation needs new code in `Proxy.roc`. `proxy/tg4-proxy` is a guard by design (it passes on the stubs).
