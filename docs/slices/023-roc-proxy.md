# 023 The roc proxy

Phase: P1. Status: done

Slice 023 makes `tln` run as the `roc` proxy (CLI 6.2, R-PX1 to R-PX7). The program name `roc` starts the proxy. It selects a compiler (Resolution 13, ranks 1 to 7), writes the `.last-use` of the compiler (R-CC9), and runs it with the terminal of the process. The exit code of the compiler is the exit code of the run (R-E1). The proxy sets `TALON_IN_PROXY=1` for the compiler, so a proxy that runs inside a proxy does not use rank 7 (R-EV17, R-SO9). Follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-023-revert/before/` (with `NEW.txt`).

The slice as the plan has it (about 380 lines) is too large. The reference code that made the tests pass has about 380 lines for the first part alone (section 11). So this file covers the first part only. The tests of parts 023b and 023c are not written.

## 0. Split proposal (for the manager)

| Slice | Content | Rules | Lines (estimate) | State |
| --- | --- | --- | --- | --- |
| 023 (this file) | Dispatch by program name. `+<id>`. The target file. The selection with rank 3 (the pin). `.last-use`. The record of the project (R-PD10). The cache variables. `TALON_PROXY=0`. `TALON_IN_PROXY`. The refusal of a compiler that is not installed. `Fx.program_name!` and `Fx.exec!`. | R-PX1 to R-PX3, R-PX6, R-PX7, R-HF6, R-HF9, R-ST8, R-PD7, R-PD16, R-PD17, R-PD10, R-EV7, R-EV17, R-CC9, R-SO1, R-SO8, R-SO9 (the proxy half), R-E1, R-TF5 (proxy), R-DL8 and R-DL10 (the error), R-NI5 (the exit 13) | 380 | tests written |
| 023b | The install in the proxy: R-PX4, the prompt (R-DL3, R-NI5), `TALON_AUTO_INSTALL=yes` (R-DL9), `TALON_AUTO_INSTALL` values (R-EV6), the lock and the install of `RocInstall` as a function. L3: 3 proxies at once, 1 download, 3 runs (R-CC4, `tests/tools/mk-nightly.sh`). | R-PX4, R-DL8 (prompt), R-DL9, R-DL1 (proxy), R-EV6, R-NI5, R-CC4 (proxy) | 200 | not started |
| 023c | The probes run the selected compiler by its path: `Probe.Spec` gets `program` and `env`, `Compiler.require` accepts an installed compiler (the P0 refusal of slice 022 D8 and N3 goes), `.last-use` for each probe (R-CC9), the cache variables for probes (R-PX6). It changes the probe line of `calls.log` in all L2 cases that run a probe, so it is its own slice. | R-PX6 (probes), R-CC9 (probes), R-SO22, R-PH7 | 150 | not started |

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-PX1, R-ST8 (the program name decides) | `Proxy.is_proxy`, `Run.run!` | L0 `is_proxy`. L2 `proxy/px1-flow` (all runs). L3 `compilers/px1-proxy` runs 1, 3, 12 |
| R-HF9 (`Env.program_name!`) | `Fx.program_name!`, `RealFx` | L3 `fx/px1-real-fx-exec` (3 names). L3 `px1-proxy` |
| R-PX2 (select, `.last-use`, run, cost: no `PATH` walk when rank 1, 2, 3, 5 or 6 gives an installed compiler) | `Proxy.run!`, `select`, `program` | L0 `select`, `program`. L2 (the calls). L3 runs 1 to 3 |
| R-PX3, R-PD17 (the arguments go on, no Talon flag), R-PD16 (`--file` is not a flag of the proxy) | `Proxy.split` | L0 `split`. L3 run 6 (`--opt=speed --file x/main.roc --yes`) |
| R-SO1 (`roc +<id>`) | `Proxy.split`, `select` | L0 `split`, `select`. L2 runs 4 and 17. L3 runs 2, 4 to 7 |
| R-SO2 (`ROC_TOOLCHAIN`) | `select` | L0 `select`. L2 run 5 |
| R-SO3, R-CV1 (the pin, also in the other tag form) | `select` | L0 `select`. L2 runs 1, 11 (exit 3) and 20 |
| R-SO4, R-NS1, R-SO13 (rank 4: the newest in the range, none in the range) | `select` (`Compiler.select`) | L2 `p4` (run 6), the workspace run, `p13` (exit 13) |
| R-SO5, R-SO6, R-SO7 (ranks 5, 6, 7) | `select` | L0 `select`. L2 runs 7, 8, 9, 10. L3 run 11 |
| R-SO8, R-PD7 (the target file) | `Proxy.target` | L0 `target`. L2: `File`, `Main` and `NoFile` runs |
| R-SO9 (second half), R-EV17 (`TALON_IN_PROXY`) | `Proxy.in_proxy`, `child_env`, `run!` | L0 `in_proxy`, `child_env`. L2 run 12 (no `path_roc` call). L3 run 10 (the loop) |
| R-SO10, R-SO12 (the id of `PATH` is installed, an id that is not installed is `Missing`) | `select` | L0 `select` |
| R-PD3, R-PD5, R-PD6 (a member of a workspace) | `Project.find!`, `Proxy.run!` | L2 workspace run (the range of the root `talon.toml`) |
| R-PD10, R-PD9 (the record of the target file) | `Known.record_recent!` | L2 runs of `p3` (3 times: new, 6 hours, 2 days), `TALON_PROXY=0`. L3 `tree.diff` |
| R-CC9 (`.last-use`) | `Proxy.last_use`, `run!` | L0 `last_use`. L2 `tree.diff` and `calls.log`. L3 runs 1, 8 |
| R-PX6 (canonical cache paths) | `Proxy.child_env`, `run!` | L0 `child_env`. L2 (`canonical` call). L3 run 7 (a link and a `..`) |
| R-PX7, R-EV7 (`TALON_PROXY=0`) | `Proxy.opted_out`, `child_env` | L0 `opted_out`, `child_env`. L2 run 19. L3 run 8. The details are question Q1 |
| R-HF6, R-E1 (run with the terminal, exit code, signal) | `Fx.exec!`, `RealFx.exec!` | L3 `fx/px1-real-fx-exec`. L3 `px1-proxy` runs 4, 5. L2 `p10` (exit 3) and `p11` (not started) |
| R-TF5 (a bad header drops only the `roc:` pin) | `run!`, `Project.find_loose!` | L2 `p12` (the `talon.toml` range, rank 4, and the record stay) and `p14` (the `.roc-version`, rank 5, and the record stay) |
| R-SO2, R-NS6, R-SC12 (`ROC_TOOLCHAIN` is a full id of any kind, also `link-dev`, `git-<name>`, `copy-<name>`) | `Compiler.toolchain_of` | L0 `tests/unit/compiler.roc` (the last `expect`, 18 rows) |
| R-DL8 (non-interactive), R-DL10, R-NI5 (exit 13), R-PX4 (the error only) | `Proxy.missing`, `run!` | L0 `missing`. L2 runs `p9` (twice) and 17. L3 run 9 |

Not tested here: R-PX4 (the install), R-DL8 (the prompt), R-DL9, R-EV6, R-NI5 (the prompt), R-CC4 for the proxy (023b). R-PX5 (slice 043). R-PD16 (the `@+N` selector for `tln roc ...`: slices 024 and 026).

## 2. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Proxy.roc` | 102 (new) | Stubs | Types, 11 functions. `is_proxy` is `Bool.False` (so no run is a proxy), the others are `crash "todo"`. The doc of the module has the table of the calls (steps 1 to 12). Exposed in `cli/lib/main.roc` (+1). |
| `cli/lib/Fx.roc` | 226 (+16) | Test agent | New fields `program_name!` and `exec!`, with the methods and the docs |
| `cli/RealFx.roc` | 191 (+10) | Stubs | The fields are wired. `program_name!` gives the empty text. `exec!` is `crash "todo"`. |
| `cli/lib/Run.roc` | 112 (+5) | Test agent | `run!` calls `Proxy.run!` when `Proxy.is_proxy(fx.program_name!())`, else `Run.tln!` (the old body) |
| `cli/lib/Known.roc` | 72 (+5) | Stub | New `record_recent!` (`crash "todo"`) |
| `cli/lib/Install.roc` | 262 (+4) | Stub | New `on_path_file!` (`crash "todo"`) |
| `cli/fxprobe.roc` | 297 (+25) | Test agent (test tool) | New calls `program-name` and `exec` |
| `tests/commands/FakeFx.roc` | 725 (+26) | Test agent | `program_name!` (`fx/program`, not logged) and `exec!` (`fx/exec`, logged) |
| `tests/commands/main.roc` | 482 (+12) | Test agent | The `commands` entry: the line `@roc ...` runs as the proxy, the word `env:NAME=value` sets a variable for one run |
| `tests/unit/proxy.roc` | 217 (new) | Test agent | 6 `expect`s |
| `tests/unit/compiler.roc` | +35 (before copy in `before/`) | Test agent | 1 new `expect` (`toolchain_of`, 18 rows), review of G1 |
| `cli/lib/Compiler.roc` | doc only | Test agent | The doc of `toolchain_of` has the new rule. The body is as before (before copy in `before/`). |
| `tests/commands/cases/proxy/px1-flow/` | 1 case | Test agent | L2, 24 runs |
| `tests/scenarios/compilers/px1-proxy/` | 1 case | Test agent | L3, 12 runs |
| `tests/scenarios/fx/px1-real-fx-exec/` | 1 case | Test agent | L3, the real `Fx` job |
| `research/slice-023-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `proto/exec.roc` (what `Cmd` gives), `stubs/`, `mutate.py`, `results.md`. The private reference is deleted. |

`scripts/test.sh` and the runners are not changed. `docs/slices/PLAN-P1.md` is not changed.

## 3. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Fx.program_name!` | `() => Str`: the program name as the system gave it, `""` when it does not tell | R-HF9, R-ST8 |
| `Fx.exec!` | `{ argv : List(Str), env : List((Str, Str)) } => Try(I32, [NotStarted(Str)])`. The exit code, or `128 + signal`. `env` are added variables. | R-HF6, R-E1 |
| `Proxy.is_proxy` | `Str -> Bool` | R-ST8 |
| `Proxy.split` | `List(Str) -> { argument : Try(Str, [Unset]), rest : List(Str) }` | R-SO1, R-PX3 |
| `Proxy.target` | `List(Str) -> [File(Str), Main, NoFile]` | R-SO8, R-PD7 |
| `Proxy.opted_out`, `Proxy.in_proxy` | `List((Str, Str)) -> Bool` | R-EV7, R-EV17 |
| `Proxy.Rank` | `[Argument, Env, Pin, Range, VersionFile, Default, Path]` | R-SO1 to R-SO7 |
| `Proxy.select` | `{ pin : Try(Str, [NoPin]), facts : Compiler.Facts } -> Try({ id, rank : Proxy.Rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])` | R-SO1 to R-SO7, R-SO10, R-SO12, R-SO13, R-CV1 |
| `Proxy.program` | `{ roots : Roots, id, installed : List(Str), path : Try({ id, path }, [NoCompiler]) } -> Str` | R-PX2 |
| `Proxy.child_env` | `{ opted_out : Bool, xdg : { path, canonical : Try(Str, [Failed]) }, build : { path, canonical } } -> List((Str, Str))` | R-PX6, R-PX7, R-EV17 |
| `Proxy.last_use` | `U64 -> Str` | R-CC9 |
| `Proxy.missing` | `{ id : Str, rank : Proxy.Rank } -> Fail` | R-DL8, R-DL10 |
| `Proxy.start_failed` | `{ program : Str, text : Str } -> Fail` | R-E1 |
| `Proxy.run!` | `Fx => I32` | R-PX2 |
| `Known.record_recent!` | `Fx, { roots, files, now } => Try({}, Fail)`: as `record!` with `refresh: After(86400)` | R-PD10 |
| `Install.on_path_file!` | `Fx, Roots => Try({ id : Str, path : Str }, [NoCompiler])`: the walk of `on_path!` (slice 022b), with the path of the file that gave the id | R-SO9, R-PX2 |

## 4. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/proxy.roc`: `is_proxy` (16 rows) | `roc`, `./roc`, a path, `roc.exe`, a Windows path. `tln`, `rocky`, `Roc`, `roc.exe.bak`, a directory named `roc`, empty | R-ST8, R-PX1 |
| L0 | same: `split` (10 rows) | Only the first argument can be `+<id>`. The rest keeps its order, also `--file` and `--yes`. | R-SO1, R-PX3, R-PD16, R-PD17 |
| L0 | same: `target` (23 rows) | `File` from the first `.roc` argument (also after options and before `--`). `Main` for no argument and for `check`, `build`, `test`, `docs`, `deps`, `run`. `NoFile` for `version`, `help`, `install`, `run <URL or name>`. A URL or an option with `.roc` inside is no file. | R-SO8, R-PD7 |
| L0 | same: `opted_out`, `in_proxy` (12 rows) | Only `TALON_PROXY=0` and `TALON_IN_PROXY=1` | R-EV7, R-EV17 |
| L0 | same: `select` (21 rows) | Rank 1 over 2 over the pin over 4 to 7. The pin has no range check and no switch. A pin that is not installed is `Missing` and never falls through. The other tag form (both ways). The id of `PATH`. `NoneInRange`, `NoCompiler`. | R-SO1 to R-SO7, R-SO10, R-SO12 to R-SO14, R-CV1 |
| L0 | same: `program`, `child_env`, `last_use`, `missing`, `start_failed` (4 + 4 + 2 + 6 rows) | An installed id wins over the same id on `PATH`. Canonical paths. A path that does not exist loses its `..`. Opted out: only `TALON_IN_PROXY`. The time text. The 6 texts. | R-PX2, R-PX6, R-PX7, R-EV17, R-CC9, R-DL8, R-DL10 |
| L2 | `proxy/px1-flow` (24 runs, `commands` entry) | See the list below. One case checks the stdout, the exit codes, the stderr, `.last-use` and `projects.json` (`tree.diff`) and the 365 lines of `calls.log`. | most rules of section 1 |
| L3 | `compilers/px1-proxy` (12 runs) | The real binary as `roc` and `roc.exe`. See the list below. | R-PX1 to R-PX3, R-PX6, R-PX7, R-ST8, R-HF6, R-E1, R-SO1, R-SO3, R-SO7, R-SO9, R-EV17, R-CC9, R-DL8, R-PD10 |
| L3 | `fx/px1-real-fx-exec` | `fxprobe exec` and `fxprobe program-name`: the exit code 0 and 7, a signal (137), the arguments as they are (one with a space), the stdout and the stderr of the child go to the terminal, the added variables replace one of the process, the current directory, a child that cannot start, the program name as typed (a link `./lnk/roc`, `roc` from `PATH`, `roc.exe`). | R-HF6, R-HF9, R-E1, TW4 |

L2 runs of `px1-flow` (`fx/commands` has the comments). The `calls.log` fixes the order of the calls of `Proxy.run!` (the table in the doc of `cli/lib/Proxy.roc`):

| # | Command | Shows |
| --- | --- | --- |
| 1 | `check p3/main.roc` (pin A1) | Rank 3. The project is found, recorded (`projects.json` is new), `.last-use`, the cache variables, `exec` by the path in `toolchains/` |
| 2 | `+A2 version` | Rank 1. No target file (R-SO8): no project, no `read_files`. No `path_roc` call (cost). |
| 3 | `check p3/main.roc` with `ROC_TOOLCHAIN=A2` | Rank 2 over the pin |
| 4 | `build p4/main.roc --opt=speed` (`[toolchain] roc = "*"`) | Rank 4. `.talon.json` times: A2 is newer than A3 although its sha sorts later. `PATH` is looked at (the id of `PATH` can be in the range). Arguments after the file go on. |
| 5 | `check p5/main.roc` (`.roc-version`, no `talon.toml`) | Rank 5 |
| 6 | `check p12/main.roc` (not a header, `talon.toml` with `roc = "*"`) | R-TF5, review of Q6: only the pin is dropped. Rank 4 gives the newest installed compiler (not the `default-roc`). The project is recorded. |
| 6b | `check p14/main.roc` (not a header, a `.roc-version`) | The same with rank 5 |
| 7 | `version` | No target: only `config.toml` is read. Rank 6. |
| 8 | `check p7/main.roc` with no `default-roc` | Rank 7: `path_roc`, the cache, `roc version`, then `exec` of the file on `PATH` (no `.last-use`) |
| 9 | the same with `TALON_IN_PROXY=1` | No `path_roc` call, exit 18 |
| 10 | `check p9/main.roc` (pin not installed) | Exit 13 (R-DL8), no `exec`. The project is recorded. |
| 11 | the same with `TALON_AUTO_INSTALL=no` | Exit 13 (R-DL10) |
| 12 | `+X check` (X not installed) | Exit 13, the text names `roc +X` |
| 13 | `check p13/main.roc` (range, none installed) | Exit 13, `Compiler.failure(NoneInRange)` |
| 14 | `check p10/main.roc` (the fake `exec` gives 3) | The exit code of the child is the exit code |
| 15 | `check p11/main.roc` (the fake `exec` gives `NotStarted`) | Exit 18 |
| 16 | `check p3/main.roc` with `TALON_PROXY=0` | No `clock`, no `projects.json` call, no `.last-use`, no `canonical`. `exec` with `TALON_IN_PROXY=1` only (Q1). |
| 17 | `check p16/main.roc` (pin in the other tag form) | R-CV1: the installed id runs |
| 18 | `check pw/apps/a/main.roc` (a member of a workspace) | R-PD3, R-PD5, R-PD6: the range of the root `talon.toml` wins over the member file and over the default |
| 19, 20 | `check p3/main.roc` 6 hours and 2 days later | R-PD10: no write, then a write of `projects.json`. `.last-use` each time. |

L3 runs of `px1-proxy` (`cmd` has the comments): 1 rank 3 and `.last-use` text; 2 `+A2 version`; 3 the name `roc.exe`; 4 exit 7; 5 `kill -9` gives 137; 6 `check --opt=speed --file x/main.roc --yes` goes on unchanged; 7 `XDG_CACHE_HOME` is a link and `ROC_CACHE_DIR` has a `..`, and the compiler gets canonical paths; 8 `TALON_PROXY=0` (no `.last-use`, the variables as they are); 9 a pin that is not installed (exit 13); 10 and 11 rank 7 with a stand-in for an old launcher (`b/roc` runs once, exit 18; `path-roc.json` has the id the second time); 12 `tln --version` is not the proxy.

Budget: 6 L0 `expect`s (the many rows are in lists), 3 deep cases (L2 1, L3 2), no selftest row. Times on the stub tree: l0 4.2 s, l2 0.9 s, l3 9.3 s, selftest 3.5 s. check is 3.8 s alone and 10.1 s once in a full run under load (TW20 warning, budget 10 s). The other steps are within budget.

## 5. Old tests that changed

None. The run of `Run.run!` for a name that is not `roc` is the old body, so the old expected files are the same. `tests/commands/FakeFx.roc` does not log `program_name!` (decision D2): no `calls.log` changed.

## 6. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| R-DL8, R-DL10, R-NI5 (not installed) | stderr `tln: error[consent]: the compiler <id> (<source>) is not installed. Run: tln roc install <id>, or set TALON_AUTO_INSTALL=yes.` Exit 13. `<source>` is `roc +<id>`, `ROC_TOOLCHAIN`, `the roc: entry of the header`, `.roc-version` or `the global default`. |
| R-SO13 | The text of slice 022 (`Compiler.failure`): `no installed compiler is in [toolchain] roc (<range>). This version of tln does not download a compiler for a run.` Exit 13. |
| R-SO14 | The text of slice 022: `no compiler is selected. Run: tln roc install @latest, then tln roc default <id>`. Exit 18. |
| R-E1 (child did not start) | `tln: error[environment]: cannot run <program>: <text>`. Exit 18. |
| R-CC9 (`.last-use`) | One line: the time of Talon as `2026-10-22T12:00:00Z` and a line end |
| R-PD10 | No output |

## 7. Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `Fx.exec!` is one call: `argv` and the added variables in, the exit code (or `128 + signal`) out. The real `Fx` uses `Cmd.run!` with `Inherit` for the 3 streams. | `Cmd.exec_exit_code!`: it gives an error for a child that a signal ended (`research/slice-023-revert/proto/exec.roc`). `execve`: basic-cli has no call for it (R-HF6 allows the child form). |
| D2 | `Run.run!` reads `Fx.program_name!` first. The fake does not log it, so no old `calls.log` changes. | Log it (every old calls.log changes). Read it in `cli/main.roc` (L2 would not reach it). |
| D3 | The proxy has its own selection `Proxy.select` (the pin is rank 3 inside it, no gate, no switch for a pin). | `ResolveBase.load!` and `Pin.decide`: they need a `Request`, they fail on a bad header (R-TF5), and they gate (R-SO19: the proxy has no gate). |
| D4 | `spawn_all!` has no `env`. The proxy sets `TALON_IN_PROXY=1` only for the compiler that it runs (R-SO9: "the proxy also sets"). The `roc version` of a rank 7 file runs from a `tln` command, with no variable (question Q9). | A field `env` in each job (it changes all callers and the `job` line of 15 old `calls.log` files). |
| D5 | The `PATH` walk (`Install.on_path_file!`) runs only when needed. A compiler of rank 1, 2, 3, 5 or 6 that is installed ends the selection with no `PATH` call. Rank 4 always looks (the id on `PATH` can be in the range). With `TALON_IN_PROXY=1` it never looks. | Always look (costs a call and the cache read in each run, R-PX2 cost target 5 ms). |
| D6 | A header that does not parse drops only the `roc:` pin (R-TF5, review of Q6). The project is found: its `talon.toml` (rank 4), its `.roc-version` (rank 5) and the R-PD10 record stay. Another failure of the search (no such file, a bad `talon.toml`, a file that cannot be read) is no project. | No project at all for a bad header (first version of this slice). |
| D7 | An id that is in `toolchains/` runs from there, also when `PATH` has the same id. `.last-use` is written for it. The compiler on `PATH` has no `.last-use` (no toolchain dir). | The file on `PATH` for the same id. |
| D8 | The proxy records the project (R-PD10) right after it found it, before the selection, so a run that fails later records it too (slice 007 D2). | Record after the selection. |
| D9 | A compiler that is not installed is always a refusal in this slice, also for `TALON_AUTO_INSTALL=yes` and in an interactive run. Slice 023b changes these two cases. | Install here (it is slice 023b). |
| D10 | The proxy prints no warning of `talon.toml` or `config.toml` (an unknown key). It stays silent: its stdout and stderr belong to roc. (Question Q5.) | Print as `tln` commands do. |
| D11 | The record of the proxy is `Known.record_recent!`, a second function. `record!` and its callers stay as they are. | A `refresh` field in `record!` (7 callers change). |
| D12 | The L2 `commands` entry: `@roc` as the first word runs as the proxy. `env:NAME=value` words set one variable for one run (a line of `fx/env` with the same name is replaced). | A new entry (the `commands` entry has the loop and the `{w}` rules already). |
| D13 | `+<id>` is not checked as a full id (question Q4). An id that is not installed is `Missing`. | The same check as `ROC_TOOLCHAIN` for the argument (G1 makes `+link-dev` valid in any case). |

## 8. Out of scope

| Rule or item | Reason |
| --- | --- |
| R-PX4 (the install), R-DL3 (the prompt), R-DL9, R-EV6, R-NI5 (the prompt), R-CC4 for the proxy, `TALON_AUTO_INSTALL=yes` | Slice 023b |
| The probes on the selected compiler by its path, R-PX6 and R-CC9 for probes, the P0 refusal of slice 022 D8 and N3 | Slice 023c |
| R-PX5 (`--replace-dep` for `[patch]`, exit 14) | Slice 043 |
| R-PX2 cost target (under 5 ms) | No timing test. The L2 `calls.log` shows the calls. |
| R-PD16 `@+N` and `@-N` | Slices 024 and 026 (`tln roc ...`) |
| Windows: `roc.exe` on Linux is tested by name only. The `.exe` rename and the `PATH` with `;` | The Windows CI job |
| `Fx.exec!` kills no child and has a timeout of none | R-HF6: Ctrl-C reaches the child. A `kill <pid>` of `tln` does not (R-HF6 text, until the upstream `execve` call). Not tested: no stable test of a signal to the parent. |
| `roc version` of a rank 7 file with `TALON_IN_PROXY=1` in its environment | Question Q9 |

## 9. Questions (TW17) and design gaps

The tests do not cover Q2 to Q9, except where the table says. Q1 and Q6 are pinned by tests: a different answer changes the named expected files only.

| # | Text | Default of the tests and of the reference |
| --- | --- | --- |
| Q1 | R-PX7 says `TALON_PROXY=0` "runs the selected compiler with no extra work". What is the extra work? | The selection stays. Extra work is the `.last-use` (R-CC9), the record of the project (R-PD10), the cache variables (R-PX6), and the `clock!` call. `TALON_IN_PROXY=1` is still set (it prevents a loop). Pinned by L2 run 16 and L3 run 8 (`calls.log`, `tree.diff`, the child output). |
| Q2 | R-SO8 names `version`, `help`, `install` and `run` with a URL or a name as commands with no file. What are the other subcommands (`fmt`, `bundle`, `unbundle`, `repl`, `glue`, `bump`, `licenses`) and the flags `--help`, `--version`? | `Main`, except `-h`, `--help`, `-V` and `--version`: `NoFile`. No test row. |
| Q3 | An option with a separate value: `--replace-dep OLD NEW` (NEW is a path to a `.roc` file) and `-j 4`. And the arguments after `--`. | The literal rule: the first argument that ends in `.roc`. A `--replace-dep a b.roc` gives `b.roc`. No test row. |
| Q4 | What is a valid `+<id>`? A prefix (`+nightly-2026-10`), `+git-1234abcd`, `+link-dev`. | No check: the id is as typed, `Missing` when not installed (exit 13, the text names `roc +<id>`). Not tested. |
| Q5 | The proxy and a `talon.toml`, `config.toml` or `.roc-version` that does not parse: exit 19 (R-TF4), or no effect? And a warning (unknown key)? | Exit 19 for the 3 files (a failure of `Intent.read`, `Intent.read_config`, `Compiler.version_file`), no warning. Not tested. |
| Q6 | Answered by the manager (review): a header that does not parse drops only the `roc:` pin. | D6. Pinned by L2 runs 6 and 6b. |
| Q7 | A write error of `.last-use`. A bad `TALON_NOW` in the proxy. | The write error is ignored. A bad `TALON_NOW` is exit 2 as in the other commands. Not tested. |
| Q8 | The exit code and the text when the compiler cannot start (R-E1 gives only the failures that Talon finds "before or after") | Kind `environment`, exit 18, `cannot run <program>: <text>` (L2 run 15). |
| Q9 | R-SO9: does `tln` set `TALON_IN_PROXY=1` when it runs `<file> version` for rank 7 (slice 022b)? | No (D4). With the variable an old launcher copy gives no id (it is a proxy that sees the variable), and the walk then stops with no compiler. Without it, the old launcher runs the next `roc` on `PATH` and its id is the id of that compiler. |
| Q10 | R-PD10 (the proxy records its target file) is not in the plan row of slice 023. | Included (`Known.record_recent!`, about 15 lines). Remove it from this slice if it belongs to another one. |
| G1 | A bug of slice 022, now in the scope of 023 (review): `Compiler.toolchain_of` refused `link-dev` and `git-0123abcd`. | Pinned by L0 (`tests/unit/compiler.roc`, last `expect`). |

## 10. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `cli/lib/Run.roc` is done (`Run.tln!` is the old body). Do not change it. `Proxy.is_proxy` must be a function that no old run meets as true: the real `Fx.program_name!` of `tln` is `tln`. |
| N2 | `RealFx.exec!`: `Cmd.new_str(program).args_str(rest).envs_str(env).stdin(Inherit).stdout(Inherit).stderr(Inherit).run!()`. `Exited(code)` is the code, `Signaled(n)` is `128 + n`, `Err(IO(_))` is `NotStarted`. `Cmd.exec_exit_code!` is wrong for a signal. `RealFx.program_name!`: `Env.program_name!`, `display`, `""` on an error. It gives the name as typed (`./lnk/roc`), so `is_proxy` takes the base name. |
| N3 | `Proxy.run!`: the calls of the table in the doc of the module, in this order. The L2 `calls.log` is exact. `Project.find!` and `Known.record_recent!` make their own calls (as in the other commands). The pin is `Locked.read(...).roc`. The `talon.toml` is read with role `Root`. The workspace range is the root `talon.toml`. |
| N4 | `Install.on_path_file!`: the walk of `on_path!` (slice 022b) with the path. For a cache hit the path is the first file of `found` whose row has `Id(<id>)`. For a run of `roc version` it is the file. `on_path!` can call it and drop the path. |
| N5 | `Known.record_recent!`: the same calls as `record!`, with `Projects.record` `refresh: After(86400)`. |
| N6 | The `.last-use` text is `Clock.format_utc(now)` and `\n`. The write is `write_atomic!`. Do not write it for a compiler that is not in the listing. |
| N7 | Format all files with `roc fmt` (the `fmt` step). `scripts/test.sh check` is at 3.6 s alone and 7.5 s in the full run. |
| N8 | Review: `Project.find!` must keep its type and its calls. Add `Project.find_loose!` (same arguments, gives `{ project, header : Try({}, Fail) }`; the header check is the only step that does not stop the search) and let `find!` call it and return the header failure. The proxy calls `find_loose!`. The calls do not change (steps 1 to 5 of `find!`). |
| N9 | Review: `Compiler.toolchain_of` accepts `Pin.is_id` or a name `git-`, `link-`, `copy-` plus a non-empty name with no `/`, no `\`, no white space (a helper `is_named_build` next to `is_compiler_dir`). The rows of the new `expect` are the rule. `debug-<sha>` is not pinned (not named in R-NS6). |

## 11. Revert check (TW12)

The private reference made all new tests pass. The manager reviewed the slice, so the reference is deleted (`research/slice-023-revert/` keeps `before/`, `stubs/`, `proto/`, `mutate.py`, `results.md`). 51 small mutations of it were run one by one, each with the layers that should catch it (`research/slice-023-revert/mutate.py`, the table is `results.md`). 51 of 51 are caught. Four mutations were not caught the first time (`contains` in place of `ends_with` in `target`, a member `talon.toml` in place of the root, the path of a cache hit in `on_path_file!`, the `NoneInRange` text): a row, a file or a run was added for each. The review added 7 mutations (R26 to R32).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `is_proxy`: `.exe`, `\`, `starts_with` | 3 | L0 `is_proxy` (also L3 for `.exe`) |
| `split`, `target`, `opted_out`, `in_proxy` | 6 | L0 |
| `select`: pin below rank 4, exact match only, always installed, no `same_id` | 4 | L0 (L2 for 2) |
| `program`, `child_env`, `last_use`, `missing`, `start_failed` | 7 | L0 (L2 for 4) |
| `run!`: arguments dropped, no `.last-use` (3 forms), `PATH` always, `TALON_IN_PROXY` ignored, no record, always record, project failure stops, no canonical (2 forms), a missing compiler runs, the exit code dropped, rank 1 ignored, member `talon.toml`, `NoneInRange` text, no `clock` change, early reads | 20 | L2 (L3 for 8) |
| `RealFx`: signal code, no `env`, captured stdout, program name | 4 | L3 `px1-proxy`, `fx/px1-real-fx-exec` |
| `Run` dispatch, `Known.record_recent!`, `Install.on_path_file!` | 3 | L2, L3 |
| Review: bad header stops the project (R26), the `talon.toml` is lost (R27) | 2 | L2 `px1-flow` (runs 6, 6b) |
| Review: `toolchain_of` as before (R28), no `/` check (R29), no white space check (R30), no name check (R31), no `copy-` (R32) | 5 | L0 `tests/unit/compiler.roc` |

## 12. State on the stub tree (red)

`scripts/test.sh`: check pass (all files compile), fmt pass. l0: `proxy` fails (6 of 6: the first by a wrong value, `is_proxy` is `Bool.False`, the others by the crash `todo`). `compiler` fails 1 of 6 (the new `toolchain_of` `expect`: `link-dev`, `git-0123abcd` and `copy-dev` give exit 2). The other 52 files pass. l2: 41 passed, 1 failed (`proxy/px1-flow`: each of the 23 runs gives `exit 2` and the usage text, because `is_proxy` is false). l3: 34 passed, 2 failed, 1 skipped (`compilers/px1-proxy`: `exit 2` for each proxy run, and the `cmd` stops at the missing `b.log`; `fx/px1-real-fx-exec`: `[ROC CRASHED] todo` at the first `exec`). selftest: pass. With the reference all steps passed (before it was deleted).

```text
tests/unit/proxy.roc: FAILED   (6 failed: is_proxy rows, then Roc application crashed with this message: todo)
FAIL proxy/px1-flow            stdout differs: -exit 0 / +exit 2 (the line `@roc check p3/main.roc` runs as tln)
FAIL compilers/px1-proxy       exit code differs (-0 / +1), stdout differs: -ran nightly-2026-10-09-258ab27: check p3/main.roc / +exit 2
FAIL fx/px1-real-fx-exec       stderr differs: -child err / +[ROC CRASHED] todo
```

## Review (manager, 2026-10-23)

The split (023, 023b, 023c) is accepted. D1 to D5 and D7 to D13, the proposals of section 6, and the defaults of Q1, Q2, Q3, Q4, Q5, Q7, Q8, Q9 and Q10 are accepted. Two changes:

| Item | Decision | Change in the tests |
| --- | --- | --- |
| Q6 and D6 | R-TF5 names only the pin. A header that does not parse drops only the `roc:` pin (rank 3). The `talon.toml` (rank 4) and the `.roc-version` (rank 5) of the project directory stay, and so does the R-PD10 record. A `Project.find!` failure that gives no directory is still no project. | L2 `px1-flow`: run 6 (`p12` has a `talon.toml` with `roc = "*"`) and the new run 6b (`p14` has a `.roc-version`). Both runs record the project. Expected files made again with the reference. |
| G1 | A bug of slice 022. R-NS6 says that `git-*`, `link-*` and `copy-*` builds are chosen by name, so `ROC_TOOLCHAIN=link-dev` and `+link-dev` must be accepted. `Compiler.toolchain_of` accepts a full id of any kind and refuses only a text that is not a full id (a prefix such as `nightly-2026-10`). It is in the scope of 023 for the code agent. | L0 rows (R-SO2, R-NS6) in `tests/unit/compiler.roc`: 10 accepted rows and 8 refused rows (`link-`, `git-`, `copy-`, a space, `/`, `\`). No change to `+link-dev` tests (Q4: no check). |

Test agent notes: the refused rows with a name that has a space, `/` or `\` are a decision (a name must be one safe path part, see N9). The mutations R26 to R32 are caught (51 of 51). The reference is deleted. Red state: see section 12 (`compiler` fails 1 of 6 in l0).

## Gap rows (test agent)

The revert check of the code (`research/slice-023-revert/code-results.md`) found 3 test gaps. Tests only, no change in `cli/`. Each mutation of `code-mutate.py` was applied by hand, the new test failed, the file was put back and compared with `code-final/` (same).

| Gap | New test | Mutation | Result |
| --- | --- | --- | --- |
| P6 | L0 `tests/unit/proxy.roc` `target`: `run https://example.com/x/app.roc` gives `NoFile` | `is_source_file` without `!arg.contains("://")` | L0 fails (1 of 6) |
| P7 | L0 same: `check --main=app.roc` gives `Main` | `is_source_file` without `!arg.starts_with("-")` | L0 fails (1 of 6) |
| G16 | L2 `proxy/px1-flow` run 24: `@roc +nightly-2026-10-14-38a3029 check p3/main.roc env:TALON_PROXY=0`. The calls are `args`, `env_all`, `cwd`, `list_dirs` of `toolchains`, `exec`: no `canonical`, no `clock`, no record. | `find!` with `Ok(typed) =>` in place of `Ok(typed) if !run.skip =>` | L2 fails |

`scripts/test.sh`: exit 0, no WARN (check 3.0 s, l0 6.2 s, l2 6.2 s, l3 9.3 s, selftest 3.6 s).

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `Proxy.target` looks only at the arguments before `--`. An argument is a file when it ends in `.roc`, does not start with `-` and has no `://`. `-h`, `--help`, `-V`, `--version` anywhere before `--` give `NoFile` (Q2 default). | The first `.roc` after `--` too (the doc of `target` says the app arguments follow `--`). |
| C2 | The `nightly` switch of rank 4 in the proxy is `TALON_NIGHTLY`, then `[toolchain] nightly`, then `config.toml`, then on (the same order as `ResolveBase.settings_of`). | A fixed `Bool.True` (R-NS3 says rank 4 obeys the switch). |
| C3 | The read of step 6 gives a failure for a file that exists in the walk but cannot be read (exit 18), except `NotFound` (no file). The `roc:` pin is read only when the header check of `find_loose!` passed. | Treat any read error as no file. |
| C4 | `Known.record!` and `record_recent!` share `record_with!` (refresh as an argument). `Install.on_path!` calls `on_path_file!` (same calls). | A second copy of the walk. |
| C5 | `scripts/test.sh` starts the builds after the `check` step when `check` is the first step (`check` was 13.5 s with the builds at the same time, now 2.8 s alone; budget 10 s is not changed). `l0` is 6.3 s (the builds overlap it, budget 10 s). | A lower job count for `check`; a higher budget. |

## Code result

| Item | Value |
| --- | --- |
| `scripts/test.sh` | exit 0. check 2.9 s, fmt 0.1 s, l0 54 files passed 6.3 s, l2 42 passed 6.5 s, l3 36 passed 1 skipped 9.3 s, selftest 42 passed 3.5 s. `OPT=speed`: exit 0 (l2 83.3 s: LLVM build, no warning for speed). |
| Files | `cli/lib/Proxy.roc` 447, `cli/lib/Known.roc` 76, `cli/lib/Install.roc` 275, `cli/lib/Project.roc` 364 (`find_loose!`, N8), `cli/lib/Compiler.roc` 229 (`toolchain_of`, `is_named_build`, N9), `cli/RealFx.roc` 207, `scripts/test.sh` 138. |
| Signatures | No public signature changed. New: `Project.find_loose!` (N8). |

## Verify results

Code agent: 35 small mutations (`research/slice-023-revert/code-mutate.py`, `code-results.md`, `run.log`, `run2.log`). Caught 32 of 35. The code is the same as `code-final/` after the run.

| Group | Mutations | Result |
| --- | --- | --- |
| `is_proxy`, `split`, `target`, `opted_out`, `select`, `program`, `child_env`, `last_use` | P1, P3, P4, P9, P10, P12 to P15, P17, P18 | caught by L0 `proxy` |
| `target` | P6 (URL that ends in `.roc`), P7 (option that ends in `.roc`) | not caught |
| `run!` | G1, G2, G4 to G7, G9, G10, G12 to G14 | caught by L2 `px1-flow` |
| `run!`: no project search with `TALON_PROXY=0` and rank 1 or 2 | G16 | not caught |
| `find_loose!` | R26, R27 | caught by L2 `px1-flow` |
| `Known.record_recent!`, `Install.on_path_file!` | K1, I1, I2 | caught by L2 or L3 |
| `toolchain_of` | C1 to C3 | caught by L0 `compiler` |
| `RealFx` | X1 to X3 | caught by L3 `fx/px1-real-fx-exec` |

Manager, after the review changes: the refusal of a named build whose name has a space, `/` or `\` is accepted (the name is one path part under `toolchains/`).

## Close (manager, 2026-10-23)

C1 to C5 of the code agent are accepted. The gap rows close P6, P7 and G16. `scripts/test.sh` exits 0 with no WARN. Status: done.
