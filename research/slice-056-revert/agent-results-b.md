# Slice 056b, mutations of the code agent

Script: `research/slice-056-revert/agent-mutate-b.py`. Each mutation changes one place of `cli/lib`, runs the one test that must see it, and puts the file back (checked with `cmp` against `code-final-b/` and `sha256sum -c code-final-b.sha256`).
Baseline: L0 `l0-8` fails only the expects 7, 9, 11, 15 (parts c, d). L2 `pt1-add` and `pt2-install` pass.

| # | Mutation | Test | Result |
| --- | --- | --- | --- |
| B1, B1b | `ToolsPlan.frozen_check`: an entry with no `url` is no finding | L2 `pt2-install` run 3, L0 `ToolsplanTest` 8 | caught, caught |
| B2 | `frozen_check`: the range of the `ref` is not checked | L2 `pt2-install` run 4 | caught |
| B3 | `--frozen` runs no tools step (no build of a tool with no binary) | L2 `pt2-install` run 6 | caught |
| B4 | `XCacheIo.has_file`: a directory with the name of the binary counts | L2 `pt2-install` run 9 | caught |
| B5 | `has_file`: any file that is not the manifest counts (the state of slice 049) | L2 `pt2-install` run 9 | caught |
| B6 | `--dry-run` builds (`ensure!` ignores `dry_run`) | L2 `pt2-install` run 13 | caught |
| B7 | `--allow-downloads` does not answer the compiler download (`ctx_of`: `allow` false) | L2 `pt2-install` run 14 | caught |
| B8 | D16: `nothing to change` ignores `step.changed` | L2 `pt2-install` run 1 | caught |
| B9 | D16: the header flow prints `nothing to change` before the tools | L2 `pt2-install` run 1 | caught |
| B10 | a build that does not pass is taken as a pass (the failed build of `acme/bad` is no stop) | L2 `pt1-add` run 10 | caught |

11 mutations, 11 caught, 0 not caught.
