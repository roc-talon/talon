# P0 slice plan

The order of the P0 slices of the `tln` CLI (Design 7, `TESTING.md` 7.4). The manager (the orchestrator agent) keeps this file. Each slice has its own file `docs/slices/NNN-<name>.md` (`TESTING.md` 7.2).

| Item | Value |
| --- | --- |
| Compiler | `nightly-2026-10-14-38a3029` (the nightly of the generic packages, `.roc-version`). Path: `cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc` |
| Platform | basic-cli 0.25.0: `https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst` |
| `roc-app-header` 0.1.0 | `https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst` |
| `roc-semver` 0.1.0 | `https://github.com/Karakatiza666/roc-semver/releases/download/0.1.0/KFKmXaroJeaPkQmAaqm83fTP9yhnEkTQwE97a5BtFSX.tar.zst` |
| `roc-base58` 0.1.0 | `https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst` |
| `roc-toml` 0.1.0 | `https://github.com/Karakatiza666/roc-toml/releases/download/0.1.0/3icmtKz6XQUyHqu5JftcoJJT6a9YTND1B8z1UAmtqJpN.tar.zst` |
| Briefs | `docs/agents/BRIEF-tests.md`, `docs/agents/BRIEF-code.md` |

## Test budget

Few tests, each with a large reach. Every rule id of a slice is named by at least one test, but one test can name many ids.

| Kind | Count per slice | Use |
| --- | --- | --- |
| L0 `expect` | About 5 to 20 | Pure decisions with many cases or edge cases (a parse, a compare, a selection). One `expect` can check a table of cases. |
| Deep test (L2 or L3) | About 2 to 6 | A whole command flow, with the earlier slices in the path. One case checks the exit code, the output, the file tree and the call log, so it covers many rules at once. |

## Slices

| # | Slice | Rule groups (P0 parts) | Depends on |
| --- | --- | --- | --- |
| 001 | Skeleton and harness | The `cli/` app, the `Fx` record, the real `Fx` (files, env, print, exit), the L0, L2 and L3 runners (`TESTING.md` 2.4, 3), `tests/fakes/roc`, `scripts/test.sh`. Rules: R-CM19, R-CM20, R-FL1 to R-FL4, R-FL6, R-FL7, R-FL12, R-E1 to R-E5, R-EC (P0 codes), R-J1 to R-J6, R-OUT1 to R-OUT5, R-NM1 to R-NM10, R-NR1, R-NR5, R-NR6, R-HF1, R-EV1, R-EV8 to R-EV10, R-EV18, R-EV22 | none |
| 002 | Project, files and locks | R-PD (P0 commands), R-LY, R-TF, R-CR1, R-CC1 to R-CC3, R-CC5 to R-CC7, R-CC11, R-CC12, R-HF3, R-EV13 | 001 |
| 003 | Index and fetch | R-DI, R-FE, R-DA, R-HF4, R-HF5, R-RG (P0: `direct`), R-EV2, R-EV3, R-EV12, R-EV14, R-EV15, R-EV19, R-EV20, R-EV23 to R-EV25, the fake HTTP server | 002 |
| 004 | References and lookup | R-SL, R-SC (P0 scopes), R-AD (registry off), R-ID, R-SE (P0 rows) | 001 |
| 005 | Intent and header | R-H, R-I, R-WS, R-VA, R-C (P0), R-SP, R-RP, R-DT, R-LF, R-OV, R-AL | 002, 004 |
| 006 (done) | Probes ladder (P0) | R-LD, R-BL, R-BS, R-RC, R-SO7, R-PH6 to R-PH13, R-NI1 to R-NI3 | 005 |
| 006b (done) | Probe follow-ups | The answers of the user to slice 006 Q1 (exit 134 is no result) and Q4 (the path rewrite util). Slice 007 review: C2 (newest candidate) and M1 (`--no-check` with `--json`). | 006, 007 |
| 007 (done) | `install` and `add` | `install` (and `add`, `i`, `--frozen`) wiring in `Run.run!`, add of a name, `--dry-run`, `--json`, R-DT5, the rename prompt R-NI1, and the items that slices 004 to 006 moved here. The design examples of these commands (TW16). | 003, 005, 006 |
| 008 (done) | `remove` | R-CM3, R-RV1 to R-RV5, the `remove` part of R-WS12, the import scan, the removal of `talon.toml` keys | 007 |
| 009 (done) | `update`, `update -i`, `verify` (file `009-update-verify.md`) | R-CM4, R-CM11, R-SP4, R-SP14, R-NI2, R-SE7 and R-DT5 for `update`, R-FL14, R-LB1, R-LB2, R-LB4, R-SL12 for `update` | 007, 008 |
| 010 (done) | Closure walk and `list` | The closure walk, R-C8, `list`, the fetch of the closure in `install` (R-CM2). R-CM9, R-H4, R-H7 (also the R-H7 scan of `remove`), R-SP21, R-AL2 | 007, 008 |
| 011 | `why` | `why`, R-C2 over the full closure. R-CM7, R-PH12, R-C2, the R-SC14 tie list, P6 of slice 004 | 010 |

The manager can split a slice that is too large for one review (TW19), or join two small ones. A change to this table is recorded here.

## Changes

| Date | Change | Reason |
| --- | --- | --- |
| 2026-10-20 | Slice 007 is split into 007 (commands that write) and 008 (`update`, `list`, `why`, `verify`) | TW19: one slice was too large for one review, and many items of slices 004 to 006 were moved to 007 |
| 2026-10-20 | Slice 007 is split again: 007 (`install`, `add`), 008 (`remove`), 009 (`update`, `list`, `why`, `verify`, the closure walk) | The 007 test agent found about 1200 lines of new code, and `Run.run!` has no wiring yet |
| 2026-10-20 | New slice 006b | The answers of the user to slice 006 Q1 and Q4 |
| 2026-10-20 | Slice 009 is split: 009 (`update`, `verify`), 010 (closure walk, `list`), 011 (`why`) | The 009 test agent found about 920 lines of new code |
