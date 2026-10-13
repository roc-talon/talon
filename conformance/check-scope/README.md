# check-scope (Q15)

Question: does `roc check` on an app check only the package modules that the app imports?

| File | Content |
| --- | --- |
| `pkg/Good.roc` | Valid module |
| `pkg/Bad.roc` | Type error (`Str` = `42`) |
| `app_Good.roc`, `app_Bad.roc` | basic-cli app that imports one module. `PF` is set per nightly. |
| `run.sh` | For each nightly in `../compat-sweep/tags.txt`, uses a basic-cli that passes there (`../compat-sweep/results.tsv`). |
| `results.tsv` | Last run |

Run: `./run.sh <bin dir>`. The dir holds `<tag>/roc`. The default is `../compat-sweep/bin`.

Expected result per nightly: app_good pass, app_bad fail, pkg fail.

## Result (2026-10-13)

| Nightlies | Result |
| --- | --- |
| 20 with a working basic-cli (09-15 to 10-12) | yes on all 20 |
| 09-23, 09-24 | No basic-cli passes there (hang window, see compat-sweep) |

## Found on the way: `..` in `XDG_CACHE_HOME`

| `XDG_CACHE_HOME` | `roc check` on an app with a type error |
| --- | --- |
| `/tmp/q15/f` | `1 error and 0 warnings`, exit 1 |
| `/tmp/q15/f/x/..` | `No errors found in 0ms`, exit 0 |

`ROC_CACHE_DIR` with `..` does not cause it. `run.sh` uses its own cache dir with no `..` (`xdg/`, ignored by git).

Cause (roc `2664a27`, still in `9ec02d8c48`):

| Step | Code |
| --- | --- |
| The packages dir is `XDG_CACHE_HOME` + `roc/packages`, not normalized | `src/compile/compile_build.zig:1596` |
| That raw dir becomes a workspace root | `src/compile/compile_build.zig:1818`, `addWorkspaceRoot` at `:887` |
| The package file path is resolved (`..` removed), then a `startsWith` test against the raw root fails | `src/compile/compile_build.zig:1668-1678`, `:157-169` |
| `error.PathOutsideWorkspace` has no report, and the CLI prints "No errors found" with 0 reports | `src/cli/main.zig:18043`, `:18315-18350` |

Fix: resolve the dir in `addWorkspaceRoot`, and exit non-zero when a check fails with 0 reports.
All 22 nightlies (09-15 to 10-12) have the bug.
