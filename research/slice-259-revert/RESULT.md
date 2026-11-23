# Slice 259 mutation check (test agent, TW12, 2026-11-23)

Script: `mutate.sh` (mirror under `.tmp/slice-259-mut`, each step capped at 16G and 600 s, the shared heavy lock, one mutant at a time). Tests: L2 `registry/of registry/yf registry/su9 registry/oc7`. No L0: no L0 test calls `ClosureIndex.dropped` or `dropped_groups`, and the change is in command code and one fold. Logs: `run.log` (all), `run2.log` (base, m3, m4, m5 again, after the gap tests).

Note on `run.log`: the gap case `of5` was written while run 1 ran (its calls.log was empty), so its failures in the rows m2 to m5 of run 1 do not count. `run2.log` has the true result with the finished `of5`.

| Mutant | What it changes | Killed by |
| --- | --- | --- |
| m1 | The group match compares the form only: the series is ignored (the old total of the name) | `of4-offline-count-series` (run 1) |
| m2 | An `any_series` slot uses the group filter too | `of4-offline-count-series` (run 2), `of5-offline-count-repo-copy` |
| m3 | The group match compares the series only: another URL form of the same series counts | SURVIVED in run 1 (no case had two URL forms of one name). Gap test added: `of5-offline-count-repo-copy` (json `{v}` and json1 `v{v}`, a yanked v2.0.5). Run 2: killed by it |
| m4 | The R-AP1 copy of the repository (step 2 of `ClosureIndex.offline!`) gives no groups | SURVIVED in run 1 (each count case had a `?group=` copy). Gap test added: `of5` (the rows come from the R-AP1 copy only). Run 2: killed by it |
| m5 | The online path (`Answer`) uses the group sum of the slot too | SURVIVED (run 2). NOT equivalent: the first closure query of a plain `update` has one group for each free variable, so two aliases of one name in two series put the rows of both series in the answer. Gap test added: `of6-online-count-series`. It is RED on the slice 259 code (`(7 releases, 4 outside the ranges, 0 too new, 3 yanked)`, expected `(6 releases, ..., 2 yanked)`): the online count has the same over-count that of4 found offline. m5 is the fix, so m5 makes of6 pass. For the code agent. |

Result: 5 mutants. m1 and m2 killed in run 1. m3 and m4 killed after the gap test of5. m5 found a code bug online: the red case of6 is for the code agent (Design Q638, the same rule as of4).
