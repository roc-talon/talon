# Slice 055 revert check (code agent)

Script: `agent-mutate.py` (10 mutations, each run with the steps that must see it). Final code: `code-final/`, `code-final.sha256` (checked after the run: all 5 files OK).

| Id | File | Mutation | Result | Test that failed |
| --- | --- | --- | --- | --- |
| A1 | InitStub | any word after a comma starts an entry (the `requires` split) | caught | l0 `InitTest` (l0-3), l2 `init/it2-platform` |
| A2 | InitStub | `()` counts as one argument (stub text) | caught | l0 `InitTest`, l2 `init/it1-app`, `it2-platform`, `it3-platform-moved` |
| A3 | Init | a type with no stub falls back to the hello world (no exit 2, a file written) | caught | l2 `init/it2-platform` (run 4) |
| A4 | Init | no remake after the resolve moved the platform | caught | l2 `init/it3-platform-moved` |
| A5 | Init | the remake drops the `roc:` pin | caught | l2 `init/it3-platform-moved` |
| A6 | PathCmd | a path entry is seen from the project file, not from its directory | caught | l0 `PathcmdTest` (2 expects), l2 `path/pt1-entry` |
| A7 | PathFlow | no fetch of a missing release dir | caught | l2 `path/pt1-entry` (run 3) |
| A8 | PathFlow | `--offline` does not reach the fetch (exit 15) | caught | l2 `path/pt1-entry` (run 2) |
| A9 | PathFlow | the project file is not recorded (`files: []`) | caught | l2 `path/pt1-entry` |
| A10 | Init | `--offline` does not reach the fetch of the platform in `init` | caught | l2 `init/it2-platform` (run 6) |

Caught 10 of 10. (A3 first ran as SKIPPED: its search text occurred twice; the text was made unique and A3 ran alone.)
