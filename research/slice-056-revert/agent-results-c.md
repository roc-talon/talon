# Slice 056c, mutations of the code agent

Script: `research/slice-056-revert/agent-mutate-c.py`. Each mutation changes one place of `cli/lib`, runs the one test that must see it, and puts the file back (checked with `cmp` against `code-final-c/` and `sha256sum -c code-final-c.sha256`).
Baseline: L0 `l0-8` fails only the expects 11 and 15 (part d). L2 `pt1-add`, `pt2-install` and `pt3-move` pass.

| # | Mutation | Test | Result |
| --- | --- | --- | --- |
| C1, C1b | `ToolsPlan.split`: a name that is an alias and a key is a tool | L2 `pt3-move` run 9, L0 `ToolsplanTest` 7 | caught, caught |
| C2 | `split`: the text before the `@` is read as the key (a name with a selector goes to the tools) | L0 `ToolsplanTest` 7 | caught |
| C3, C3b | `selector_for`: `upgrade` takes the release inside the range of the `ref` | L2 `pt3-move` run 3, L0 `ToolsplanTest` 9 | caught, caught |
| C4 | `upgrade_ref`: the range of the `ref` does not change | L2 `pt3-move` run 3 | caught |
| C5 | a range with no form moves the tool all the same | L2 `pt3-move` run 4 | caught |
| C6 | the header flow runs when the names are keys of `[tools]` only | L2 `pt3-move` run 7 | caught |
| C7 | `update <header name>` runs the tools step for each entry (`tools_named` gives the phase for any names) | L2 `pt3-move` | NOT CAUGHT: no run names a header entry in a project that has `[tools]` |
| C8 | D16: `nothing to change` is printed also when the tools changed | L2 `pt3-move` run 7 | caught |
| C9 | D16: `nothing to change` is not printed for a tool that stays (`update fmt` at the newest) | L2 `pt3-move` run 13 | caught |

11 mutations, 10 caught, 1 not caught (C7: a gap of the tests, see the slice file).
