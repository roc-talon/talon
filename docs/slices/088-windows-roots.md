# 088 Windows roots

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Source: `PLAN-P1.md` 5b row "`Roots.from_env` has no Windows form" (slice 050c, Q-D3). On Windows with no `HOME` and no `XDG_*`, `Roots.from_env` fails with exit 18 (`HOME is not set`), or, with a `HOME` that git bash sets, gives Linux paths. The 050c sweep (`Del`) and each command then find the wrong dirs.

## 1. What the design says

| Rule | Text (CLI 6.1, short) |
| --- | --- |
| R-LY5 | Cache root. Windows: `%LOCALAPPDATA%\roc`. "roc reads `XDG_CACHE_HOME` first on Windows too, and so does Talon." |
| R-LY6 | Config. Windows: `%APPDATA%\talon` |
| R-LY7 | Data. Windows: `%LOCALAPPDATA%\talon` |
| R-CR1 | The packages root is `<cache>/packages` and ignores `ROC_CACHE_DIR`. The build root is `ROC_CACHE_DIR`, else the cache root. |

## 2. How the code knows the system

| Place | Fact |
| --- | --- |
| `Fx.platform!` | gives `{ os : [Linux, Macos, Windows, Other(Str)], arch }` (slice 021) |
| `Fx.windows!` | a `Bool` call (slice 050c). The fake `Fx` does not write it to `calls.log`, so a caller can use it with no change of an old `calls.log` |
| `Setup.bin_dir` | the model: `{ os, env }`. Windows reads `USERPROFILE` and joins with `\` (R-LY8) |
| `Roots.from_env(env)` | the 50 callers have an `env` list, and most have `fx` |

The pure function is the new `Roots.from_env_on(os, env)`. `Roots.from_env(env)` stays as it is (the form of Linux and macOS), so no old test changes. The wiring of the callers is question Q-W5.

## 3. Public signature (stub)

```roc
Roots.from_env_on : [Linux, Macos, Windows, Other(Str)], List((Str, Str)) -> Try(Roots, Fail)
```

The stub is `crash "todo slice 088: the Windows roots"` (`cli/lib/Roots.roc`). The type of the first argument is the same as `Setup.Os`.

| Input | Result |
| --- | --- |
| `Windows`, `LOCALAPPDATA` and `APPDATA` set | cache `<LOCALAPPDATA>\roc`, pkgs `<cache>\packages`, build `ROC_CACHE_DIR` else cache, config `<APPDATA>\talon`, data `<LOCALAPPDATA>\talon`. A `\` at the end of a variable is dropped (as `Setup.bin_dir`). `HOME` is not read |
| any other `os` | `Roots.from_env(env)` |

## 4. Tests

| Layer | Case | Rule ids |
| --- | --- | --- |
| L0 | `tests/unit/RootsTest.roc`, 1 new `expect` with 8 rows (the 8th is the XDG_CACHE_HOME row), and 1 new `expect` for the cache order on Windows (4 cases): Windows with no HOME and no XDG; a `\` at the end of the variables; `ROC_CACHE_DIR` (packages ignore it); Windows with `HOME` set (the Windows form wins); Linux with the Windows variables set; macOS; an unknown system with no `HOME` is the failure of `from_env` | R-LY5, R-LY6, R-LY7, R-CR1 |

The file has 3 `expect`s before and 5 now. Rule ids of the new rows: R-LY5, R-LY6, R-LY7, R-CR1. The driver is `tests/unit/l0-8.roc` (no change).

Red output (`roc test tests/unit/l0-8.roc`, `.work` log `088-red.log` in the scratchpad): 89 passed, 2 failed. The failures are `RootsTest.roc:53` and `RootsTest.roc:114` and the crash message is `todo slice 088: the Windows roots`. The 4 "compiler errors" of the same run come from the work of another agent in `cli/lib` (`Intent.roc`, `ToolBin.roc`), not from this slice.

## 5. Output

No output text and no `data` field.

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The wiring of the callers (`Roots.of_run!`) | Q-W5 (b): the code step does it, with no test change |
| `Del` | stays on `from_env` in this slice (no `DelTest` change) |
| `Del` and `DelTest` | `Del.roc` calls `Roots.from_env(env)` on Windows only. Its rows in `DelTest` have `HOME` and `XDG_DATA_HOME` in a Windows env. When `Del` moves to `from_env_on(Windows, env)`, rows 1 to 4 and 6 of `DelTest` change (the data dir is `%LOCALAPPDATA%\talon\bin`). A test change for the human review, so it is part of Q-W5 |
| L2 and L3 on Windows | CI on Windows runs `check fmt l0` only (TW28) |

## 7. Questions

Evidence for the answers: roc `src/compile/compile_build.zig` `getRocCacheDir` (about line 1570). Order: `XDG_CACHE_HOME` (any value, joined with `std.fs.path.join`, so `\` on Windows), then `LOCALAPPDATA` (Windows only), then `HOME` (also on Windows), else error `NoCacheDir`. R-LY5 says "as roc".

| # | Question | State |
| --- | --- | --- |
| Q-W1 | `XDG_CACHE_HOME` on Windows: form and separator | answered (manager, 2026-11-02): the value is taken as it is, with no absolute check on Windows, and the join uses `\`. L0 row: `D:\cache` gives `D:\cache\roc`. The Linux rule (a value must start with `/`) does not change here |
| Q-W3, Q-W4 (cache only) | `LOCALAPPDATA` missing, `HOME` on Windows | answered (manager, 2026-11-02): the cache order on Windows is `XDG_CACHE_HOME`, `LOCALAPPDATA`, `HOME` (`<HOME>\.cache\roc`), else kind `Environment` with `LOCALAPPDATA is not set`. L0 rows: XDG first, LOCALAPPDATA before HOME, HOME fallback, neither set. The row "Windows with HOME set: the Windows form wins" stays for cache, config and data (LOCALAPPDATA comes before HOME) |
| Q-W2 | `XDG_CONFIG_HOME` and `XDG_DATA_HOME` on Windows | open: sent to the design agent. Not tested |
| Q-W3, Q-W4 (config and data) | `APPDATA` or `LOCALAPPDATA` missing, `HOME` for the config and data roots | open: sent to the design agent. Not tested |
| Q-W5 | How the callers know the system | answered (manager, 2026-11-02): (b) a helper `Roots.of_run!(fx, env)` that uses `fx.windows!` (not logged). Callers that have `fx` move to it. `Del` stays on `from_env` in this slice (no `DelTest` change). The helper has no stub and no test here: it is thin wiring, covered by the old L2 and L3 cases that must stay green |

## 8. Revert check

2 hand mutations of the private reference were caught by the first `expect` before the manager review (the `\` at the end of a variable is not dropped; the Windows form only when `HOME` is not set). The reference is deleted (manager rule). The rows added by the review were not mutated.

## 9. Code agent result (2026-11-02)

| Item | Result |
| --- | --- |
| Code | `cli/lib/Roots.roc`: `from_env_on` (Windows gives `windows_roots`, any other system gives `from_env`) and `of_run!(fx, env)` (`fx.windows!` gives `Windows` or `Linux`). A copy is in `research/slice-088-revert/code-final/` with `code-final.sha256` |
| Test | `roc test tests/unit/l0-8.roc`: 91 passed (RootsTest) |
| Choice, not in the design (Q-W2 to Q-W4, config and data) | The test row "HOME fallback" needs a result with only `HOME`, so `config` and `data` use `<HOME>\.config\talon` and `<HOME>\.local\share\talon` when `APPDATA` or `LOCALAPPDATA` is missing. Without `HOME` the failure is kind `Environment`: `APPDATA is not set` or `LOCALAPPDATA is not set`. Rejected: failing when `APPDATA` is missing (the test row would fail). The design agent must confirm (Q-W3, Q-W4) |
| Choice | A trailing `\` is dropped from each variable that is read, `XDG_CACHE_HOME` and `ROC_CACHE_DIR` too (`ROC_CACHE_DIR` is not changed) |
| 088b (follow-up for the manager) | Move the callers that have `fx` from `Roots.from_env(env)` to `Roots.of_run!(fx, env)` (about 50). Not done now: another agent edits the tool flow files. `Del` stays on `from_env` (section 6) |

Revert check (4 mutations, the test `l0-8.roc` fails for each): no drop of the end `\` (caught), `HOME` before `LOCALAPPDATA` (caught), Windows uses `from_env` (caught), a wrong packages dir (caught). Caught 4 of 4. The file is equal to `code-final/` (`sha256sum -c`).

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo` of this slice | None |
| Tests (code agent run) | check, fmt pass. L0 driver of the slice passes. L2 239 of 239. L3 fast set pass. The only L0 failures are the red tests of slice 092. |
| Follow-up | 088b: move the callers with `fx` to `Roots.of_run!`. The config and data fallback on Windows waits for the design answer of G-C14. |
