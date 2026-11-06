# 088c Windows sweep and cache parent

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Source: slice 088b section 7 (manager, 2026-11-02): 2 code bugs that the Windows test world of 088b showed. Both are in the design: R-LY5 to R-LY7 and R-ST10.

## 1. Scope

| Part | Bug | Right behavior |
| --- | --- | --- |
| A. The sweep | `Del.dirs` calls `Roots.from_env` (the form of Linux). On Windows the sweep lists `$HOME/.local/share/talon/bin`, and a `.del` file in the real data bin dir is never deleted | R-LY7, R-ST10: the data bin dir is `<LOCALAPPDATA>\talon/bin` (`Roots.item` `Bin` of `Roots.from_env_on(Windows, env)`). The `.del` files there are swept |
| B. The proxy parent | `Launch.child_env!` cuts the cache root at the last `/` (`Text.dir_of`). On Windows the root is `<dir>\roc`, so `XDG_CACHE_HOME` is `<dir>` minus its last `/` part (`$HOME/AppData`, or on a real host the empty text or the drive) | R-PX6, R-LY5: on Windows the cut is at the last `\` or `/` (the later one). `XDG_CACHE_HOME` is `<LOCALAPPDATA>`. `canonical!` gets the same path. Linux and macOS: no change (a `\` is a letter of a name) |

## 2. Rule ids

R-ST10, R-LY5, R-LY6, R-LY7, R-PX6, R-CR1 (the packages dir does not change).

## 3. Signatures (the smallest testable shape)

| Part | Choice |
| --- | --- |
| A | `Del.dirs : List((Str, Str)) -> List(Str)` does not change. The sweep runs on Windows only (`Run.run!` checks `Fx.windows!`, `DelFlow.sweep!` says so), so `Del.dirs` always uses `Roots.from_env_on(Windows, env)`. No new parameter, no stub. The DelTest rows give the Windows env. A caller that has no Windows host would be a new rule (not in the design) |
| B | New pure function, a stub with `crash "todo: slice 088c"`: `Launch.xdg_dir : { windows : Bool, cache : Str } -> Str` (in `cli/lib/Launch.roc`). `Launch.child_env!` must call it with `fx.windows!()` in place of `Text.dir_of(roots.cache)`. `Text.dir_of` does not change |

## 4. Red tests

| Test | What | State |
| --- | --- | --- |
| L0 `tests/unit/DelTest.roc` expect 1 (driver `l0-5.roc`) | rows of `Del.dirs` with the Windows env: both dirs, a `\` at the end, LOCALAPPDATA over HOME, `XDG_DATA_HOME` ignored, the HOME form, the empty and missing variables, `APPDATA` needed. Rows 1 to 5, 7 and 8 of the old file changed (the 6 old rows with no `LOCALAPPDATA` are now the Windows rows) | red: the rows with a data dir give the `/` form |
| L0 `tests/unit/LaunchTest.roc` last expect (driver `l0-1.roc`) | `Launch.xdg_dir`: 8 rows (Windows with `\`, with `/` before the last `\`, with `/` in `XDG_CACHE_HOME`, a `/` after the last `\`, no separator; Linux, a `\` in a name, no `/`) | red: `todo: slice 088c` |
| L2 `tool/ts5-windows` (run 2) | the sweep lists `$HOME/AppData/Local\talon/bin` and deletes the `.del` file there (3 files in one `delete`) | red |
| L2 `tool/dl2-tool-windows` (run 2) | the same: the `foo.<hex>.del` of the data bin dir is deleted by the sweep | red |
| L2 `tool/dl1-sweep`, `tool/dl1b-denied` | the data bin dir (and the files of it) moved to `given/home/AppData/Local\talon/bin` | red |
| L2 `tool/dl3-rename-edges`, `tool/dx2-source-windows`, `ptool/pt4-bin-file` | `canonical $HOME/AppData/Local ...` and `env XDG_CACHE_HOME=$HOME/AppData/Local` | red |
| L2 `tool/ts5b-winfresh`, `dx1-xtake-windows`, `rm3-windows`, `rm5-win-path`, `rm6-tools-windows`, `roc/ri1-flow` | the line 2 of each Windows run (`list_dirs <bin> <data bin>`) has the Windows data bin dir. No other change | red |

The expected L2 files come from the private reference of the 2 changes (the sweep and `xdg_dir`), run with `UPDATE=1`, and each diff was read: only the sweep line, the `canonical` line, the `XDG_CACHE_HOME` line and the `.del` file of the data bin dir changed. The rules files of `ts5-windows`, `dl2-tool-windows`, `dl1-sweep` and `dl1b-denied` say the right behavior again (the "known gap" text of 088b section 7 is gone).

## 5. Out of scope

| Item | Why |
| --- | --- |
| `Launch.clean` (`Text.resolve("/", path)`) for a path that `canonical!` cannot resolve | It makes a `\` path wrong on a real Windows host when the dir does not exist. The design does not say. Not a rule of this slice: a question for the design agent if it matters (the fake host and the L2 cases never show it, as `canonical!` of the fake gives the same text) |
| `RealLocks.registry_path!` (still `from_env`, no `fx`) | 088b |

## 6. Questions

None: the manager answered both items.

## 7. Revert check

The private reference (the 2 files `Del.roc` and `Launch.roc` with the right code) is deleted. 2 hand mutations with the reference in place, each killed: (1) `Launch.xdg_dir` with the Windows branch off (cut at `/` only): L0 `LaunchTest` fails (1 of 105). (2) `Del.dirs` back to `Roots.from_env`: L0 `DelTest` fails (1 of 85). The L2 cases need a build of `cli/lib/Run.roc`: L2 ran with the reference and `UPDATE=1` (all 239 passed), but the L2 mutations were not run (an import of another slice had no file for a while).
The old files are in `research/slice-088c-revert/before/` (`NEW.txt` lists the new file).

## 8. For the code agent

1. `Del.dirs`: `Roots.from_env_on(Windows, env)` in place of `Roots.from_env(env)`, and the text of its doc comment.
2. `Launch.xdg_dir`: the body. Cut at the later of the last `\` and the last `/` when `windows`; `Text.dir_of` otherwise.
3. `Launch.child_env!`: `xdg = Launch.xdg_dir({ windows: fx.windows!(), cache: roots.cache })`.
4. Do not edit the tests. Run L0 (`l0-1`, `l0-5`) and the whole L2.

## 9. Code result (code agent)

| Item | Result |
| --- | --- |
| Files | `cli/lib/Del.roc` (`dirs` uses `Roots.from_env_on(Windows, env)`), `cli/lib/Launch.roc` (`xdg_dir` body, `child_env!` calls it with `fx.windows!()`) |
| L0 | l0-1 and l0-5 pass. `check` and `l0` pass |
| L2 | 239 passed, 3 failed. The 13 cases of 088c pass. The 3 failures are `share/sh1-flow`, `share/sh2-direct`, `share/sh3-status` (slice 213, not mine) |
| L3 | pass |
| fmt | fails for `main.roc`, `ShareJson.roc`, `Share.roc`, `ShareTest.roc` (slice 213 files) |
| Copy | `research/slice-088c-revert/code-final/` and `code-final.sha256` (2 files) |
| Disputes | none |

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo: slice 088c"` | None |
| Tests (code agent) | check, l0, l3 pass. L2 239 pass. The 3 L2 failures (share/sh1 to sh3) and the fmt failures are files of slice 213, which is in work. |
| Out of scope | `Launch.clean` resolves a non-canonical path with `Text.resolve("/", path)`. This is wrong for a real Windows `\` path when the dir does not exist. No design text and no test show it. |
