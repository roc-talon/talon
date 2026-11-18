# Slice 255 mutation check (test agent, TW12, 2026-11-18)

Script: `mutate.sh` (mirror under `.tmp/slice-255-mut`, each step capped at 16G and 600 s, the shared heavy lock, one mutant at a time). Tests: L2 `registry/au7 update/au7 moves/ registry/sa registry/yf5 verify/ patch/`. Logs: `run.log` (all), `run2.log` (n3 again, after the gap test).

Note on `run.log`: the case `registry/au7-write-conflict-no-warning` was being written while run 1 ran (no expected files yet), so it fails in each row of run 1, including the base. It is not counted there. With its expected files, it passes with the code of slice 255.

| Mutant | What it changes | Killed by |
| --- | --- | --- |
| n1 | The audit lines before the ladder again (the place of slice 249) | `au7-failed-no-warning`, `au7-consent-refused-no-warning`, `au7-held-move`, `sa1-add-moved`, `update/au7-direct-held-move` |
| n2 | The audit lines after the ladder, before `confirm_moves!` (the first fix of slice 255) | `au7-consent-refused-no-warning`, `au7-held-move`, `update/au7-direct-held-move` |
| n3 | The audit lines after the consent, before `InstallWrite.write!` | SURVIVED in run 1 (no case had a write that fails). Gap test added: `registry/au7-write-conflict-no-warning` (a concurrent edit of the header makes the write stop with exit 17, R-CC7; no R-AU14 line). Run 2: killed by it |
| n4 | `verify`: the audit lines before `Ladder.verify!` | `au7-verify-failed-no-warning` |
| n5 | `InstallWrite.report!` dropped (the lines of the files) | `moves/hm1-noninteractive`, `moves/hm2-interactive`, `patch/pa2-resolve`, `au7-held-move`, `sa1-add-moved`, `update/au7-direct-held-move`, `update/au7-direct-offline`, `update/au7-direct-series` |
| n6 | `PatchApply.report!` dropped (the rebased lines) | `patch/pa2-resolve` |

Result: 6 mutants, 5 killed in run 1, n3 killed after the gap test. No equivalent mutant.
