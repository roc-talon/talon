# Slice 056a, mutations of the code agent

Script: `research/slice-056-revert/agent-mutate-a.py`. Each mutation changes one place of `cli/lib`, runs the one test that must see it, and puts the file back (checked with `cmp` against `code-final-a/` and `sha256sum -c code-final-a.sha256`).

| # | Mutation | Test | Result |
| --- | --- | --- | --- |
| A1, A1b | `ToolsToml.put`: any text gives a new table (the other bytes are lost) | L2 `pt1-add`, L0 `ToolsplanTest` 4 | caught, caught |
| A2 | `ToolsPlan.add_ref`: no selector writes `name@<version>` (no caret, D13) | L2 `pt1-add` | caught |
| A3, A3b | `ToolsPlan.no_project` is never true (no `talon.toml` in the current directory, Q3) | L2 `pt1-add` run 16, L0 `ToolsplanTest` 16 | caught, caught |
| A4, A4b | `ToolsCmd.check_flags`: `add --tool` takes `--no-pin` (D1) | L2 `pt1-add` run 14, L0 `ToolsplanTest` 13 | caught, caught |
| A5 | `ToolsFlow.add!`: a key of another app acts as an update | L2 `pt1-add` run 4 | caught |
| A6 | `ToolsStep.write!`: `--dry-run` writes the file | L2 `pt1-add` runs 7, 15 | caught |

9 mutations (6 places, 3 of them also seen by L0), 9 caught, 0 not caught.
