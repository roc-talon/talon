# Slice 226: `tln probe <bundle>` with no project file

## Fault

The first live compat bot run (roc-talon/talon run 42360886796, 2026-11-07) found it. Every unit probe exits 2, so the bot stores no facts.

| Item | Value |
| --- | --- |
| Command | `ROC_TOOLCHAIN=nightly-2026-11-06-34f137a TALON_AUTO_INSTALL=yes tln probe --json --yes ./<hash>.tar.zst` |
| cwd | A dir with no project file in it or above it (the bot checkout root) |
| Now | `{"ok":false,"error":{"kind":"usage","code":2,"message":"no project file found. Checked: ... Pass --file <path>."}}` (cli/lib/Project.roc:124, from `Install.begin!` in `ProbeFlow.begin!`) |
| Expected | The probe of the hash of the file on the compiler of `ROC_TOOLCHAIN`, one fact in `compat.db`, exit 0 |

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-PB1 | A path to a `<hash>.tar.zst` file: Talon checks its hash, extracts it as a package and probes that hash. |
| Design Q566 (b), Registry R-MX18 item 1 | The bot runs `env ROC_TOOLCHAIN=<tag> tln probe --json --yes <path>` in a dir with no project. The compiler is R-SO2 rank 2. |
| Design Q591 (precedent for the URL operand of `--smoke`) | No project: no search, no `projects.json` record, the compiler of section 13 with no project (ranks 2, 6, 7). |

## Scope

| Case | Behaviour |
| --- | --- |
| Bundle operand, no project file found | New: the no-project path of Q591 (`ProbeSmokeFlow` URL operand is the model). No `Known.record!`. Compiler: `Compiler.select` with no project. The unit probe and the fact as with a project. |
| Bundle operand, a project file found | No change in this slice (question G-C232). |
| Alias operand, no operand | No change: these need the project (exit 2 as now). |
| `--range` with a bundle and no project | In scope if the same change covers it, else a question. |

## Question

G-C232 (to TalonRegistry, does not block): when a project file is found, does a bundle operand use it (its pin, its config) or not (as the URL operand of Q591)? This slice keeps the current behaviour for that case.

## Tests

Case `tests/commands/cases/probe/pb3-bundle-no-project` (rules R-PB1, R-PB2, R-SO2, R-SO15, R-PD16, R-DL2, R-DL5).

| Run | cwd | Command | Expected exit | Shows |
| --- | --- | --- | --- | --- |
| 1 | no project file | `ROC_TOOLCHAIN=<installed id> probe --json --yes <hash>.tar.zst` | 0 | The search, then the no-project path. One fact. No `projects.json`. |
| 2 | no project file | `probe --json` (no operand) | 2 | No change: "no project file found". |
| 3 | no project file | as 1, the compiler is not installed | 0 | The bot path: download with no prompt. `default-roc` is set because none was set (R-SO15). |
| 4 | a bad `talon.toml` | as 3 | 19 | A search that fails on a found project still stops the run. |

## Review (manager)

| Point | Decision |
| --- | --- |
| The red test first skipped the project search | Wrong: that decides G-C232. The test now searches first (option B). |
| The fall back on any search failure | Wrong: a bad `talon.toml` was skipped. Fixed: `Fail.no_project` (cli/lib/Fail.roc:28), set only at cli/lib/Project.roc:124. Run 4 guards it. |
| The answer line on stderr with `--json`, the install offer calls, the `default-roc` write, one `.last-use` | The code is right (pc1, R-SO15). The test follows the code. |

## Code

| File | Change |
| --- | --- |
| cli/lib/ProbeFlow.roc | `begin!` split into `begun!`. New `bare!` (the no-project prelude of Q591, shared). `flow!` sends a `Bundle` to `bundle_flow!`, which falls back to `bare_bundle!` only on `fail.no_project`, with no `--range`. |
| cli/lib/ProbeSmokeFlow.roc | The `Url` branch calls `ProbeFlow.bare!`. |
| cli/lib/Fail.roc, cli/lib/Project.roc | The `no_project` field (default false, not in `--json`). |

## Mutations (research/slice-226-revert/mutate.sh)

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | Fall back on any search failure | pb3 (run 4) |
| m2 | "no project file found" is not marked | pb3 (runs 1, 3) |
| m3 | The no-project path ignores `ROC_TOOLCHAIN` | pb3 |

## Open

| Item | Owner |
| --- | --- |
| G-C232: a bundle operand with a found project: use it or not | Decided by the user (2026-11-07): yes, it uses the project. That is the current behaviour (pc1 run 10, pc2 run F). No code change. |
| `--range` with a bundle and no project: still exit 2 | Question if the bot needs it |
| The `label` of a bundle in `data` is the bare hash | Accepted by the user (2026-11-07, TW24) |
