# win-link: why `tln` did not link for x64win

## Cause

| Item | Value |
| --- | --- |
| Failed run | release 40395628076, job `build (windows-latest, x64win, tln-x64win.exe)` |
| Error | `lld-link`: undefined `mainCRTStartup`, `memcpy`, `memset`, `__chkstk`, `_tls_index`, `_fltused`, `malloc`, `qsort`, `strlen` ... |
| Compiler | `nightly-2026-10-14-38a3029` (`ROC_TAG`) |
| Platform | basic-cli 0.25.0 |

From the roc nightly of 2026-10-11, roc does not add the MSVC startup code and the C runtime to an x64win link.
The platform must give them (basic-cli PR 512, "Supply redistributable MSVC startup and runtime inputs").
basic-cli 0.25.0 is older. Its `x64win` inputs are `host.lib` and the Win32 import libs only, with no CRT.
Thus the pair (nightly 2026-10-14, basic-cli 0.25.0) cannot link any x64win app, also not on a Windows runner.

basic-cli 0.26.0 adds `targets/x64win/windows_support.lib` (Roc/Zig startup, TLS, compiler-rt, mingw-w64 UCRT imports).
It needs nightly `2026-10-12-2664a27` or later. The pinned nightly is newer, so no compiler change is necessary.

## Minimal repro (Linux, cross link)

| Dir | Platform | `roc build main.roc --target=x64win` |
| --- | --- | --- |
| `hello25/` | basic-cli 0.25.0 | fails: `undefined symbol: mainCRTStartup`, `memcpy`, ... |
| `hello/` | basic-cli 0.26.0 | links, `hello.exe` |

```sh
. scripts/env.sh
cd research/win-link/hello25 && "$ROC" build main.roc --target=x64win --output=hello.exe   # fails
cd ../hello && "$ROC" build main.roc --target=x64win --output=hello.exe                     # links
```

## Fix

Move Talon to basic-cli 0.26.0 (branch `win-link`). The `cli/Real*.roc` modules change to the 0.26 API:

| 0.25 | 0.26 (in Talon) |
| --- | --- |
| `Env.platform!().os` / `.arch` | `System.target!().os()` / `.arch()` |
| `Cmd.new_str(p).args_str(a).envs_str(e)` | `RealBase.command(p, a, e)` (`Cmd.new`, `args`, `envs` with `OsStr.from_str`) |
| `child.try_wait!()`, `Ok([out])` | `child.poll!()`, `Ok(Finished(out))` |
| `Cmd.RunOutput` | `Cmd.Output` |
| `Utc.now!()` is `U128` | `Utc`; `RealBase.seconds` gives seconds |
| `Sleep.millis!(n)` | `_ = Sleep.millis!(n)` (it returns `Try`) |
| `Http.send!(req)` | `Http.send!(req, {})`, plus `Interrupted` and the new `TransportErr` tags |
| `Sqlite.query!`/`execute!` with a path, `:name` bindings | `Sqlite.open!` once per call, `db.query_one!`/`query_all!`/`execute!`, `Query.new` with `?` marks |
| `PRAGMA busy_timeout` | open option `busy_timeout` |

No upstream issue is necessary: basic-cli 0.26.0 has the fix.
