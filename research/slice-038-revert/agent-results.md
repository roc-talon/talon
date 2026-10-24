# Slice 038: revert check of the code agent

Method: `agent-mutate.py` (log: `agent-mutate.log`). One small change in one line of `cli/lib/`, the 3 L0 files (`ranges`, `vars`, `upgrade`), and only when no L0 file fails, the L2 cases `upgrade/` and `resolve/rs-new-toml` (dev build, `--no-cache`). After each run the file is copied back from `code-final/`. At the end `sha256sum -c research/slice-038-revert/code-final.sha256` (from the repo root) gave 12 of 12 OK.

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | an anchor is free when no name is given (`Vars`, R-UP1) | `vars.roc` |
| A2 | a movable variable keeps its ranges (`Vars`, R-SP23) | `vars.roc` |
| A3 | the wildcard end is lost (`Ranges.rewrite`, R-UP5) | `ranges.roc`, `upgrade.roc` |
| A4 | a fail row of a module that the app does not use is a reason (`Lags`, R-UM1) | `upgrade.roc` |
| A5 | 2 members under one file give 2 pairs for one key (`Lags.changes_of`, R-SP25) | `upgrade.roc` |
| A6 | `update X@latest` does not rewrite the range (`InstallPlan.moves_of`, R-UP11) | `ug1-flow` (run 8) |
| A7 | the suffix ` new series` is on the wrong lines (`InstallPlan.marked`, R-UP3) | `ug1-flow`, `ug2-lag`, `ug3-move` |
| A8 | `update` reports lags too (`PickFlow`, R-UP10) | `resolve/rs-new-toml`, `ug1-flow`, `ug2-lag` |
| A9 | `upgrade` uses the strategy of `talon.toml` (`ResolveBase.settings_of`, Q2) | `ug1-flow` (run 12) |
| A10 | the toml line has `(was "<old>")` also when the new value equals the old value (`InstallWrite.was_text`, Q6) | not caught |

Caught 9 of 10.

A6 first form (`Update => Bool.False`) made a warning (unused `latest`), so `roc test` failed for a wrong reason. It was done again with `latest(u.alias) and Bool.False`.

A10 is a test gap, not an equal change. When the pair has the value that the key has now (for example `tln update json@^2.1` with the key `^2.1`), the line must have no `(was ...)`. No L0 or L2 case has such a pair: `Lags.rewrites` never gives a pair with the old value, and the cases with a selector range change the key. Proposal for the test agent: one L2 run with `update json@^2.1` over the key `"^2.1"`.
