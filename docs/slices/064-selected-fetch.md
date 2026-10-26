# 064 The selected compiler in all fetches

Phase: P1. Status: done

Slice 064 is the plan row 064 of `PLAN-P1.md` (section 2c). It closes G4 of slice 060: after slice 060, `Fetch.packages!` chooses the program of `roc unbundle` by R-FE4 (the selected compiler when installed, else the newest installed, else `roc` on `PATH`). But the flows below pass no selected compiler (`""`), so they use the newest installed compiler also when a different compiler is the selected one. This slice makes each flow pass the selected compiler, with the rule of slice 060 (question Q1, answer (a), `Fetch.selected`): the held compiler, else the `default-roc` of `config.toml` when the flow knows it, else none.

No new pure decision. `Fetch.selected` and `Fetch.unbundler` (slice 060) are not changed, and the L0 tests are not changed. No output text and no `--json` field changes.

## 1. Which flows change

| Flow | Where it fetches | `selected` after the slice | State |
| --- | --- | --- | --- |
| `remove` | `RemoveFlow.removal_ladder!`, `ResolveBase.closure!` (the closure after the removal) | `Fetch.selected({ held: decision.held ?? "", default: loaded.config.default_roc ?? "" })`: as `install` (the decision `Pin.decide` is made before the ladder) | change |
| `probe --range` | `ProbeFlow.ranged!`, `unbundle_program!` | `Fetch.selected({ held: "", default: loaded.config.default_roc ?? "" })`: as `list`, `why` (no decision, the config is loaded) | change |
| `probe` with no `--range` | `ProbeFlow.single!` | the compiler of the run (`started.id`, `started.program`) | no change (done by slice 060) |
| `path` | `PathFlow.fetch!` | the default, with one new `Fx` call: `RocInstall.read_config!` (one `read_files!` of `config.toml`), made in `fetch!`, so only for a release entry, after the read of the project file and before `Fetch.packages!` (D1) | change |
| `init --platform <name>` | `Init.platform_header!` | the default of the read that `Init.start_url!` already makes (no new read: `start_url!` gives `{ url, default_roc }` to `make!`, and `make!` gives it to `platform_header!`) | change |
| `tool install`, `x` | `ToolFlow.package_text!` (the bundle and the platform) | the default of `ToolFlow.machine!` (step 3 already reads `config.toml`): `Machine.default_roc`, then `ToolBuild.Facts.selected` | change |
| `tool update`, `tool rebuild`, `tool rm`, `tool install --git`, `tln tool update talon` | `ToolFlow.package_text!` through `ToolManageFlow.machine!` | the default of its read of `config.toml` (the same read) | change |
| `add --tool`, `remove --tool`, `update --tool`, `upgrade --tool` | `ToolFlow.package_text!` through `ToolsFlow.context!` | the default of its read of `config.toml` | change |
| `install`, `update`, `upgrade` (the tools step) | `ToolFlow.package_text!` through `ToolsStep.ctx_of` | `request.selected` of `InstallFlow` (the held compiler, else the default: slice 060) | change |
| `run` (project tools) | `RunTools.build!` | the default of its read of `config.toml` | change |
| `roc use` | none: `RocUse` does not call `Fetch.packages!`, `Gather`, `Walk` or `ResolveBase.closure!` (its probes run `roc`) | not needed | no change (out of scope, section 6) |

## 2. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-FE4 | The program of `roc unbundle` is the selected compiler when installed, in each fetch of each command | the L2 cases of section 4 |
| R-SO6 (as used) | The global default (`default-roc`) is the selected compiler of a flow with no decision that knows it | L2 `x/x1-run`, `tool/ti1-install`, `tool/tr2-rebuildstops`, `ptool/pt1-add`, `run/rn3-tools`, `path/pt1-entry`, `init/it2-platform`, `probe/pc2-range` |
| R-SO19 (as used) | A command with a project holds the compiler of the pin (`decision.held`) | L2 `remove/rm2-select`, `ptool/pt2-install` |
| R-PTH2 (as used) | `tln path` fetches as `install --frozen` fetches (R-FE4 included) | L2 `path/pt1-entry` |

## 3. Public signatures (no stub: the code agent adds these; `Fetch.selected` is done)

| Module | Change |
| --- | --- |
| `ToolBuild.Facts` | new field `selected : Str` (the program of `roc unbundle` is chosen with it). Each place that makes a `Facts` gives it: `ToolFlow.gather!`, `XFlow.flow!`, `ToolManageFlow.machine!`, `ToolsStep.facts_of` |
| `ToolFlow.Machine` | new field `default_roc : Str` (`config.default_roc ?? ""` in `machine!`). `ToolFlow.gather!` and `XFlow.flow!` give `Fetch.selected({ held: "", default: default_roc })` |
| `ToolsStep.Ctx` | new field `selected : Str`. `ToolsStep.ctx_of` (install, update, upgrade): `request.selected`. `ToolsFlow.context!` and `RunTools.build!`: `Fetch.selected({ held: "", default: config.default_roc ?? "" })` (both read `config.toml` already) |
| `ToolFlow.package_text!` | `unbundler: Choose({ selected: facts.selected })` in place of `""` |
| `Init.start_url!` | gives `{ url : Str, default_roc : Str }` in place of `Str` |
| `Init.platform_header!` | the facts get `selected : Str`. `make!` gives `Fetch.selected({ held: "", default: started.default_roc })`. `remake!` (step 6b) gives `""`: its release was fetched by the resolve, so its fetch never downloads (no test) |
| `PathFlow.fetch!` | reads the config (step in section 1), gives `Choose({ selected: Fetch.selected({ held: "", default: ... }) })` |
| `ProbeFlow.ranged!` | `unbundle_program!` gets `selected: Fetch.selected({ held: "", default: loaded.config.default_roc ?? "" })` |
| `RemoveFlow.remove!` | `removal_ladder!` gets the request with `selected` set (section 1) |

Compiler limits: a new record field in a closed record type is a compile error in each place that makes the record (the check finds them all). `{ selected }` alone is a block: write `selected: selected`. A warning fails a build (an unused `config`). `RemoveFlow.roc` is 318 lines, `ToolsStep.roc` 395: all modules stay under 490 lines.

## 4. Tests

No L0 test, no L1, no L3 change. All tests are L2: the `calls.log` of the runs. Each case has a world where the selected compiler is installed and is NOT the newest installed one, so the old behavior (newest) shows a different program.

| Layer | Case | Change | The check | Rule ids |
| --- | --- | --- | --- | --- |
| L2 | `remove/rm2-select` (new) | the project `r2` of `rm1-flow`, 3 compilers (pin `38a3029`, default `2664a27`, newest `9e9e9e9`), the package of `json` not in the cache, `remove parser` | the `roc unbundle` job runs `38a3029`: the held pin, not the default, not the newest. Exit 10 (the candidate error, as `rm1-flow` run 2) | R-FE4, R-SO19, R-SO6 |
| L2 | `tool/ti1-install` | world: `config.toml` `default-roc = 38a3029`, compiler `9e9e9e9` added | 7 unbundles (runs 1 to 7) run `38a3029`. `expect/` is the same as before the slice: the old code shows `9e9e9e9` | R-FE4, R-SO6 |
| L2 | `x/x1-run` | same world edit | 7 unbundles run `38a3029` (`XFlow` builds its own `Facts`) | R-FE4, R-SO6 |
| L2 | `tool/tr2-rebuildstops` | same world edit | 2 unbundles of `tool rebuild` (`ToolManageFlow.machine!`) | R-FE4, R-SO6 |
| L2 | `ptool/pt1-add` | same world edit | 6 unbundles of `add --tool` (`ToolsFlow`) | R-FE4, R-SO6 |
| L2 | `ptool/pt2-install` | same world edit | 8 unbundles of the tools step of `install` (`request.selected`). 2 lines `db_query ... facts=` show 2 in place of 1 (the added compiler) | R-FE4, R-SO6, R-SO19 |
| L2 | `run/rn3-tools` | same world edit | 3 unbundles of the build in `run` (`RunTools.build!`). 1 line `db_query` shows 2 facts | R-FE4, R-SO6 |
| L2 | `path/pt1-entry` | same world edit | run 3 unbundles with `38a3029`. The 4 runs that reach the fetch (runs 1 to 4) have one new line `read_files $HOME/.config/talon/config.toml` before the fetch | R-FE4, R-SO6, R-PTH2 |
| L2 | `init/it2-platform` | `home8` `default-roc = 0e0e0e0` (installed, not the newest `2a2a2a2`) | run 7 unbundles with `0e0e0e0`. The default also selects the compiler of the ladder of run 7 (new `list_dirs` of `toolchains/`, 4 `.last-use` writes, the probe program): this is R-SO6 and is not the scope of the slice | R-FE4, R-SO6 |
| L2 | `probe/pc2-range` | `config.toml` `default-roc = 7b7b7b7` (not the newest `0e0e0e0`) | run F (`probe --range <bundle file>`) unbundles with `7b7b7b7` | R-FE4, R-SO6 |
| L2 | `tool/ti2-refusals`, `tool/ti3-compiler` | no world change: only `calls.log` | 6 and 1 unbundles after run 7 of `ti2` (the first compiler becomes the default: R-SO15 today) run `1a2b3c4` (the default, not the newest `38a3029`). Slice 062 stops this write, so these lines go back to `38a3029` then (the test agent of 062 changes them) | R-FE4 |

The expected files changed: `remove/rm2-select` (new, all files), `path/pt1-entry` and `ptool/pt2-install`, `run/rn3-tools`, `init/it2-platform`, `probe/pc2-range`, `tool/ti2-refusals`, `tool/ti3-compiler` (`calls.log`), and the rules files of 9 cases (a paragraph). `ti1-install`, `x1-run`, `tr2-rebuildstops`, `pt1-add` have the same `expect/` as before: the world is new, not the answer. The old copies are in `research/slice-064-revert/before/` (`NEW.txt` lists the new files).

Counts: 1 new case, 9 changed worlds (6 with an added compiler), 12 failing L2 cases in the red state.

## 5. Output (proposed, R-OUT2)

No new text. The only new output is one `Fx` call of `tln path` (the read of `config.toml`), in the `calls.log` of 4 runs.

## 6. Decisions that the design does not fix (D, for the review) and out of scope

D1 to D5: accepted by the manager, 2026-10-25.

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `tln path` reads `config.toml` (one new call) in `fetch!`, so a run that does not fetch (a path entry, a foreign URL) has no new call, and a release entry has it also when its directory is present (the fetch decides that later). Reason: R-PTH2 says `path` fetches as `install --frozen` does, and that fetch selects the default | pass `""` for `path` (R-FE4 is not followed with a default that is not the newest); read the config in `Install.begin!` for all commands (changes the `calls.log` of all cases) |
| D2 | `probe --range` selects the default (no decision, the config is loaded): the same rule as `list` and `why` (question Q1 of slice 060) | pass `""`; a held compiler (the command makes no pin decision, R-PB3) |
| D3 | `x`, `tool *`, project tools and `run` select the default only. The pin of the app is in the bundle that the fetch gets, so it is not known at the fetch of the bundle | the pin of the app (not known yet) |
| D4 | The tools step of `install`, `update` and `upgrade` uses `request.selected` (the held compiler, else the default), as the closure fetches of the same command | the default only |
| D5 | `Init.remake!` passes `""`: the platform was fetched by the resolve before, so no download happens | thread the default also there (no test can tell) |
| Out 1 | `roc use`: no fetch in the flow (it never calls `Fetch.packages!`), so nothing to pass. The plan row 064 and G4 of slice 060 list it: remove the word | |
| Out 2 | `probe` with no `--range`, `probe <hash>.tar.zst`: already selected (`started.id`, slice 060) | |
| Out 3 | A required download when no compiler is installed (R-FE4, R-DL2) | slice 060 G5 |
| Out 4 | `tool/ti2-refusals` and `tool/ti3-compiler` select a default that is not the newest only because a downloaded compiler becomes the default today (R-SO15). Slice 062 stops that write, so their later unbundle lines go back to `38a3029` then: the test agent of 062 changes them | slice 062 |

## 7. Verify results (test agent, 2026-10-25)

| Step | Red state (stubs: no code change, the world and the expected files are new) |
| --- | --- |
| check, fmt | pass |
| l2 | FAIL, 12 cases, all with a wrong program or a missing `read_files` line in `calls.log`: `remove/rm2-select`, `tool/ti1-install`, `tool/ti2-refusals`, `tool/ti3-compiler`, `tool/tr2-rebuildstops`, `x/x1-run`, `ptool/pt1-add`, `ptool/pt2-install`, `run/rn3-tools`, `path/pt1-entry`, `init/it2-platform`, `probe/pc2-range`. The other 159 pass |
| l0, l3, selftest, l1 | not changed |

The log is `research/slice-064-revert/red-run.log`. With the private reference (11 files, about 30 changed lines): `scripts/test.sh` passes all 7 steps (`green-run.log`). Revert check: 5 hand mutations, each caught by one case (M1 remove: default over held; M2 `XFlow` gives ""; M3 `ToolsStep.ctx_of` gives ""; M4 init loses the default; M5 path drops the default). The private reference was deleted at the review (manager, 2026-10-25).

## 7b. Verify results (code agent, 2026-10-25)

`scripts/test.sh` exits 0: check, fmt, l0, l2 (171 cases), l3, selftest, l1 all pass. The 12 red cases are green. The code is 11 files of `cli/lib/` (about 30 changed lines, no new module, none over 490 lines).

| Mutation | Test that failed |
| --- | --- |
| M1 `RemoveFlow`: `held: ""` (the default only) | L2 `remove/rm2-select` |
| M2 `XFlow`: `selected: ""` | L2 `x/x1-run` |
| M3 `ToolsStep.ctx_of`: `selected: ""` | L2 `ptool/pt2-install` |
| M4 `Init.start_url!`: `default_roc: ""` | L2 `init/it2-platform` |
| M5 `PathFlow`: the default gives `""` | L2 `path/pt1-entry` |
| M6 `ProbeFlow.ranged!`: `selected: ""` | L2 `probe/pc2-range` |

Caught 6 of 6. The code after the mutations is the same as before (compared with `cmp`). No test was changed (no dispute row).

## 8. Questions (TW17)

None that stop the slice. D1 to D5 are for the review.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-064-revert/code-final.sha256` | 11 files OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` | Passed (code agent run, all layers; 171 L2 cases) |
| Gap step | Skipped: 6 of 6 mutations caught, no new decision |
| `roc use` | Has no fetch; removed from the PLAN row 064 and the 060 G4 row |
