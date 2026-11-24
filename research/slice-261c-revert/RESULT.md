# 261c mutation check (nightly-2026-11-13-03dce41, 2026-11-24)

`mutate.sh` (TW12, the coordinator's order): 13 mutants and a reference, each in its own mirror under `.tmp/261c-mut-<stamp>/<name>/` (the repo is not changed).
Each mutant runs `roc test tests/unit/l0-9.roc` and the L2 cases `logproof/` and `registry/rg2-{config-direct,default-registry,example-add-short}` with an L2 app built in the mirror (`--opt=dev`).
All runs are capped (16G, no swap), flocked, and have a 300 s limit. A mutant must build with no warning (roc build fails on a warning), so a skipped step keeps a run-time condition.

| Mutant | File | Change | Result | Killed by |
| --- | --- | --- | --- | --- |
| reference | - | none | all pass (good) | |
| skip-no-check | InstallFlow.roc | no check with `--no-check` | killed | all 19 logproof cases that check, the 3 rg2 cases |
| skip-dry-run | InstallFlow.roc | no check with `--dry-run` | killed | lp12, lp9, lp9b, the 3 rg2 cases |
| check-after-settle | InstallFlow.roc | the check after `settle!` (after the ladder and the writes) | killed | 18 logproof cases |
| kept-no-cover | LogCheck.roc | the kept checkpoint is used also when it does not cover each log index | killed | lp8 |
| no-consistency | LogCheck.roc | the kept checkpoint is checked against itself (no consistency check) | killed | lp8 |
| one-read | LogProof.roc | `Behind` after read 1 (no read again) | killed | l0-9 (1), lp6, lp6b |
| no-sleep | LogCheck.roc | no `sleep!` between the reads | killed | lp6, lp6b |
| config-wins | LogKey.roc | `log-key` of config.toml wins over `TALON_LOG_KEY` (Q261c-1) | killed | l0-9 (1) |
| no-trim | LogKey.roc | no trim of the key text (N1), env and config | killed | l0-9 (3), lp11c, lp11d |
| copies-on-fail | LogCheck.roc | the tile copies are written also when a proof fails | killed | lp4, lp5, lp12, lp15 |
| no-copies | LogCheck.roc | no copy and no kept checkpoint is written (also with `--dry-run`, Q261c-2) | killed | lp1, lp6, lp11c, lp11d, the 3 rg2 cases |
| offline-no-proof-passes | LogCheck.roc | `--offline` with no kept checkpoint passes (no T7) | killed | lp9b |
| offline-rows-unchecked | InstallFlow.roc | the rows of the `--offline` copies are not checked | killed | lp9, lp9b |

No survivor, so no gap test. Note: no mutant writes the copies only without `--dry-run`, because `LogCheck` does not see the flag; `no-copies` covers it, and the dry-run cases `rg2-default-registry` and `rg2-example-add-short` fail on it (their next run expects the kept proof).
