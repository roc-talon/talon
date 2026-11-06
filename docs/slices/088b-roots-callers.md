# 088b Roots callers

Phase: P1. Status: done (closed by the manager, 2026-11-02).

## 1. Scope

Follow-up of slice 088 (Q-W5 (b)). Each caller of `Roots.from_env(env)` that has an `fx` calls `Roots.of_run!(fx, env)`. `Roots` and the tests did not change. On Linux and macOS the result is the same (`of_run!` gives `Linux` for a machine that is not Windows, and `fx.windows!` is not logged).

## 2. Changed callers (20 files, 33 calls)

| File | Calls |
| --- | --- |
| `cli/flowprobe.roc` | 5 (`record!`, `releases!`, `hint!`, `fetch!`, `listing!`) |
| `cli/lib/Install.roc`, `Init.roc`, `ZigInstall.roc`, `NoRank.roc`, `GitInstall.roc`, `GitDefault.roc`, `RocLink.roc`, `RunFlow.roc`, `XProject.roc`, `CacheClean.roc`, `CacheGc.roc`, `SetupFlow.roc`, `ToolFlow.roc`, `TalonRemoveFlow.roc`, `Proxy.roc` | 1 each |
| `cli/lib/RocManage.roc` | 4 |
| `cli/lib/RocInstall.roc` | 3 |
| `cli/lib/ToolManageFlow.roc` | 3 |
| `cli/lib/CacheShow.roc` | 2 |

Comment lines that name `Roots.from_env` are not changed.

## 3. Callers that stay

| Caller | Reason |
| --- | --- |
| `cli/lib/Del.roc` (`dirs`) | Pure code, no `fx`. Section 6 of slice 088 |
| `cli/RealLocks.roc` (`registry_path!`) | No `fx` (it calls `RealBase.env_all!()`). The path of the heartbeat file only |
| `cli/lib/Roots.roc` | Defines `of_run!` and `from_env_on` |

No caller was in the files of the other agents (`ToolBin`, `ToolBinCheck`, `ToolsToml`, `ConfigToml`, `Intent`, `Registry`).

## 4. Results

| Step | Result |
| --- | --- |
| `roc check cli/main.roc` | 0 errors |
| `roc fmt --check cli` | valid |
| L0 | `l0-4` fails: 10 `todo: slice 092` (red). `l0-8` fails: `todo: slice 205` and `todo: slice 201` (red). The other files pass |
| L3 | pass (first run) |
| L2 | 224 passed, 15 failed (before 088b: 0 failed) |

## 5. The 15 L2 failures: what the test worlds need

Cause: the fake `Fx` reads `os=windows` from the `platform` row, so `fx.windows!` is true. The env of these cases has only `HOME`. `Roots.from_env_on(Windows, env)` then uses the `HOME` fallback of slice 088: `$HOME\.cache\roc`, `$HOME\.local\share\talon`, `$HOME\.config\talon`. The expected files have `/` paths. The code is right by 088. Not changed: `Roots`, the code, the tests.

First differing line of each case (the first section that differs is `Fx calls` or `stdout`, shown as the first `-` or `+` line):

| Case | Section | First differing line |
| --- | --- | --- |
| ptool/pt4-bin-file | Fx calls | `-lock $HOME/.cache/roc/talon/projects.json nowait: held` |
| roc/ri1-flow | Fx calls | `-read_files $HOME/.config/talon/config.toml` |
| tool/dl1b-denied | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| tool/dl1-sweep | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| tool/dl2-tool-windows | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| tool/dl3-rename-edges | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| tool/dx1-xtake-windows | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| tool/dx2-source-windows | Fx calls | `-read_files $HOME/u1/.local/share/talon/tools.json` |
| tool/rm3-windows | Fx calls | `-read_files $HOME/u1/.local/share/talon/tools.json` |
| tool/rm5-win-path | Fx calls | `-read_files $HOME/u3/.local/share/talon/tools.json` |
| tool/rm6-tools-windows | Fx calls | `-read_files $HOME/u1/.local/share/talon/tools.json` |
| tool/ts5b-winfresh | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| tool/ts5-windows | Fx calls | `-read_files $HOME/.local/share/talon/tools.json` |
| zig/zi1-install | Fx calls | `-list_dirs $HOME/.cache/roc/toolchains` |
| zig/zs1-search | Fx calls | `-list_dirs $HOME/.cache/roc/toolchains` |

Each case then fails later (stdout, stderr, file tree) because the tools.json, config.toml or toolchains dir is read from the new path and is not found.

What a test agent must decide and do (a test change, for the human review):

| Option | Change |
| --- | --- |
| A (likely) | Add `LOCALAPPDATA` and `APPDATA` to the env of each Windows case (the `given` env), in the form that the expected files use, so the roots are `<LOCALAPPDATA>\roc`, `<LOCALAPPDATA>\talon`, `<APPDATA>\talon`. Then change each path in `calls.log` and in the file tree to that form |
| B | Decide that the roots on a fake Windows keep `/` (a path form decision: design question for G-C14) |

Cases that have `os=windows` and `HOME` only also need the choice in Q-W2 to Q-W4 (config and data fallback, slice 088) to be confirmed by the design agent.

Note: `roc/ri1-flow`, `ptool/pt4-bin-file` and `zig/*` show other lines in stdout and stderr. They all start from a changed path read, not from another rule.

## 6. Verify results

No mutation: the change is a rename of a call, with no new rule. A copy of the changed files is in `research/slice-088b-revert/code-final/` with `code-final.sha256`.

## 7. Test world fix (2026-11-02)

Option A (manager): the fake Windows has a real Windows env. Each Windows case got `LOCALAPPDATA` and `APPDATA` (in `fx/env`, or in the `env:` words of `fx/commands` for the cases with one home for each run). The `given/` files moved to the new dirs, which are names with `\` (as `home\.local\bin`): `AppData/Local\roc` (cache), `AppData/Local\talon` (data), `AppData/Roaming\talon` (config). The code joins the packages dir with `\` too, so it is `AppData/Local\roc\packages`. `expect/` was rewritten with `UPDATE=1` and then compared with the old files after a path mapping: only paths differ, except where this table says so.

| Case | World | Choice |
| --- | --- | --- |
| `tool/ts5-windows`, `ts5b-winfresh`, `dl2-tool-windows`, `dl3-rename-edges`, `dx1-xtake-windows` | all runs Windows | `LOCALAPPDATA={w}/home/AppData/Local`, `APPDATA={w}/home/AppData/Roaming`. The HOME fallback is not tested here |
| `tool/dx2-source-windows`, `rm3-windows`, `rm5-win-path`, `rm6-tools-windows` | one home for each run (`u1`, `u2`, `u3`, `u4`) | the 2 variables are in the `env:` words of each command line, under the `u<n>` home |
| `tool/dl1-sweep`, `dl1b-denied` | all runs Windows | the 2 variables are in `fx/env`. The data bin dir (with `.del` files) stays at `home/.local/share/talon/bin`: see the gap below. `dl1-sweep` run 2 (`env:HOME=` empty) still shows the sweep with only the bin dir |
| `ptool/pt4-bin-file` | run 1 Linux, run 2 Windows | the Linux files stay. A Windows copy of the start state was added (cache, config, packages). Run 2 now works in its own tree |
| `zig/zs1-search` | run 7 Windows, the others Linux | the Linux files stay. A Windows copy of the 3 `zig-0.18.*` dirs and the compiler was added. Output the same as before except for the path |
| `zig/zi1-install` | run 3 Windows, the others Linux | the Linux files stay. A Windows copy of the compiler dir was added. Run 3 installs `zig 0.16.2` in the Windows cache, so the Linux runs 4 to 12 no longer see it: 3 lines of the dependency list on stderr of run 12 changed (`found zig 0.16.2` became `found zig 0.17.0` / `zig not found`) |
| `roc/ri1-flow` | run 4 Windows, run 11 freebsd, the others Linux | the Linux files stay. The Windows run has a `config.toml` with the default of run 1. It has no index cache, so run 4 now calls `http_get` for the nightlies index and `programs gh`, writes the index in its cache and prints the warning "compat id not known". The later runs are not changed |

HOME fallback: no case was moved to it. No case tests it at L2 (the unit test `RootsTest` does).

Gaps for the code agent (not fixed here, no test hides them except the one in the next row):

| Gap | Where it shows |
| --- | --- |
| `Del.dirs` still calls `Roots.from_env`, so the sweep of the `.del` files lists the data bin dir in the Linux form. R-LY6 and R-ST10 need `<LOCALAPPDATA>\talon\bin`. The expected files keep the current output: `tool/ts5-windows` run 2 and `dl2-tool-windows` run 2 do not delete the `.del` file of the data bin dir (it stays in the tree), `dl1-sweep` and `dl1b-denied` keep their data bin dir in `home/.local/share/talon/bin`. After the fix: `UPDATE=1` for these 4 cases, and move the data bin files of `dl1-sweep` and `dl1b-denied` | `calls.log` line 2 of each Windows run: `list_dirs ... $HOME/.local/share/talon/bin` |
| The parent of the cache dir is cut at `/` only: `canonical $HOME/AppData $HOME/AppData/Local\roc` and `XDG_CACHE_HOME=$HOME/AppData` for the proxy (`dl3-rename-edges`, `dx2-source-windows`, `pt4-bin-file`). On a real Windows host the parent of `...\Local\roc` would be `...\Local`. A design check is needed (what must `XDG_CACHE_HOME` be?) | `calls.log` lines `canonical` and `env XDG_CACHE_HOME=` |

Results: L2 239 of 239 passed. L3 fast (`scripts/test.sh l3`): pass (19.3 s). A backup of the 15 old cases is in `research/slice-088b-testworld-revert/before.tgz`.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK (20 files) |
| L2 after the test world fix | 239 of 239. L3 fast set passes. |
| Follow-up | 088c: `Del.dirs` on Windows (the `.del` sweep of the data bin dir) and the proxy cache parent cut at `\`. Four L2 cases recorded the old sweep output, and 088c makes them state the right output. |

Update (088c, 2026-11-02): both gaps of section 7 are now the slice `088c-windows-sweep-parent.md` (red tests). The sweep rows of `ts5-windows`, `dl2-tool-windows`, `dl1-sweep` and `dl1b-denied`, and the `XDG_CACHE_HOME` lines, now state the right behavior; the "Known gap" notes of their rules are gone.
