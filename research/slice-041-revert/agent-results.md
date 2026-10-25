# Slice 041 revert check (code agent)

Script: `research/slice-041-revert/agent-mutate.py`. Each run: `scripts/test.sh check l0 l2` with one change, the file put back after. Logs: `agent-mutate.log` (first run), `agent-mutate2.log` (re-run of M4, M6, M7, M9, M10 after the first mutation did not compile or the filter was wrong).

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | a failed run does not remove its `main.roc` | L2 `init/it1-app` (run 11) |
| M2 | an existing CI file is overwritten | L2 `init/it1-app` (run 12) |
| M3 | `--ci none` still writes the CI file | L2 `init/it1-app` (run 2) |
| M4 | `init` refuses `--probe-downloads` | L0 `args.roc` |
| M5 | `init` refuses `--allow-downloads` | L0 `args.roc` and L2 `init/it1-app` (run 13) |
| M6 | a platform name with `@` is accepted | L0 `init.roc` expect 1 |
| M7 | the consent flags do not reach the flow | L2 `init/it1-app` (run 13) |
| M8 | an existing `main.roc` is overwritten | L2 `init/it1-app` (run 7) |
| M9 | the start release ignores min-release-age | L0 `init.roc` expect 2 and L2 `init/it1-app` |
| M10 | `--platform` is accepted with `package` | L0 `init.roc` expect 1 |

The run number in the table is the one that must see the change (the log names the case `init/it1-app` only). Caught 10 of 10. The first M7, M9 and M10 did not compile (unused value or a warning): they were changed to forms that compile, then run again.
After the runs the code was compared with `code-final/` (`sha256sum -c research/slice-041-revert/code-final.sha256`): the same.
