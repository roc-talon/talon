# 023c Probes by path

Phase: P1. Status: done

Slice 023c makes the probes of the resolve commands run the selected compiler by its path (CLI 6.2, R-PX2, R-PX6). Before it, a probe ran the name `roc` on `PATH`, and `Compiler.require` refused each compiler that was not that `roc` (P0, slice 006, D8 and N3 of slice 022). Now an installed compiler runs from `toolchains/<id>/roc`, the `roc` on `PATH` runs by the file that `PATH` gave (never by the name: the first `roc` can be the Talon launcher), each probe gets the cache variables of the proxy (R-PX6: "Probes use the same rule"), and `.last-use` of the compiler is written before a round of probes starts (R-CC9). A compiler that is not installed is still refused (exit 13): the consent rules are slice 025. Follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-023c-revert/before/` (with `NEW.txt`). The private reference was deleted after the review.

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-PX6 (probes: `XDG_CACHE_HOME` and `ROC_CACHE_DIR` are canonical paths with no `..`) | `Launch.child_env`, `Launch.child_env!` | L0 `launch` (`child_env`, 4 rows). L2 `probe/pb1-ladder`, `probe/pb2-verify` (the `canonical` call and the `env` line of each probe). L3 `compilers/pb1-probes-by-path` run 2 (a link and a `..`). L3 `fx/pr1-real-fx-probes` (the real `Fx` sets `env`) |
| R-CC9 (probes: the time of Talon in `toolchains/<id>/.last-use` before the compiler starts) | `Launch.touch!`, `Launch.last_use`, `Ladder` | L0 `launch` (`last_use`). L2 `pb1-ladder` runs 1, 4, 5, 7 (`write_atomic` before each round, `tree.diff`), run 9 and run 2 of `pb2-verify` (no write for the `roc` on `PATH`). L3 `pb1-probes-by-path` runs 1, 5 |
| R-PX2 (the compiler runs by its path: `toolchains/<id>/roc`, or the file of `PATH`) | `Launch.program`, `Probe.Spec.program`, `Ladder.plan`, `Ladder.plan_replace`, `RealJobs.start_probe!` | L0 `launch` (`program`, 6 rows), `ladder` and `verify` (`plan`, `plan_replace`). L2 `pb1-ladder`, `pb2-verify`, and the 17 old cases (the probe line). L3 `pb1-probes-by-path` runs 1, 5, 6. L3 `pr1-real-fx-probes` (a program that is a file) |
| R-SO22 (the compiler is a required download at the first probe, not before. `--no-check` and `--frozen` need no compiler.) | `Ladder.run!`, `Ladder.verify!` (steps 0a to 0c), `Compiler.require` | L2 `pb1-ladder` run 6 (`no-check`: no `list_dirs` of `toolchains`), `pb2-verify` run 5. L3 `pb1-probes-by-path` run 4 |
| R-PH7 (a held pin, or a rank that selects another compiler, is a required download when a probe needs it. Here: refused as `TALON_AUTO_INSTALL=no` would, exit 13, until slice 025.) | `Compiler.require` | L0 `compiler` (`require`, 16 rows). L2 `pb1-ladder` runs 3, 8. `pb2-verify` run 4. The old cases `ladder/ld-no-check-refuse`, `gaps/g1-slice009`. L3 `pb1-probes-by-path` run 3, `verify/vf1-verify` |
| R-SO10, R-CV1 (an installed id is a compiler, the other tag form of one nightly names the same compiler, the installed copy wins over the `roc` on `PATH` with the same id) | `Compiler.require`, `Launch.program` | L0 `compiler`, `launch`. L2 `pb1-ladder` runs 4, 5. L3 `pb1-probes-by-path` run 6 |
| R-SO2, R-SO21 (`verify` probes on the run compiler: rank 2, over the pin), R-SO20 (a command that holds the pin probes on the pin) | `Ladder.verify!`, `Ladder.run!` | L2 `pb2-verify` runs 1, 2. `pb1-ladder` runs 7, 9. L3 `pb1-probes-by-path` run 1 |
| R-SO9 (the first `roc` on `PATH` can be the launcher) | `Launch.program`, `Install.compiler!` | L3 `pb1-probes-by-path` run 5 (a launcher first on `PATH`) |

`MISSING=1 scripts/rules.sh R-PX6 R-CC9 R-SO22 R-PH7` lists none of these ids.

## 2. Flow of a probing command (the calls that the L2 cases fix)

| Step | Call | Rule |
| --- | --- | --- |
| 0a | `Launch.toolchains!`: one `list_dirs!` of `<cache>/toolchains`. Once for each `Ladder.run!` or `Ladder.verify!`, before the first member. | R-SO22 |
| 0b | `Compiler.require({ id: held, installed, path: path_roc })`. A failure is exit 13 and ends the run: no more call. | R-PH7, R-SO22 |
| 0c | `Launch.child_env!`: one `canonical!` of the dir of `roots.cache` and `roots.build` (once for the run). `Launch.program`. | R-PX2, R-PX6 |
| 1 to 3 | The copy (`install`, `update`, `remove`) or the temp dir (`verify`), as before | R-CC2 |
| 4 | Before each `probes!` call (the round of checks, then the round of the build): `Launch.touch!` (one `write_atomic!` of `.last-use`) when the compiler is in `installed`. The `roc` on `PATH` has no toolchain dir, so no write. | R-CC9 |
| 5 | `probes!`: each `Probe.Spec` has `program` and `env` | R-PX2, R-PX6 |

Calls with no probe (`--no-check`, `--frozen`, nothing to change) are as before: none of 0a to 0c.

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Probe.roc` | +5 -4 | Test agent | `Probe.Spec` has `program` and `env` (type and doc) |
| `cli/lib/Compiler.roc` | 232 | Stub | New type of `require` and its doc (the table of 3 rows). The body keeps the P0 rule and the P0 text, so the new `expect`s fail by a wrong value. |
| `cli/lib/Launch.roc` | 46 (new) | Stub | `program`, `child_env`, `last_use`, `toolchains!`, `touch!`, `child_env!`: `crash "todo"`. The doc has the table of users. |
| `cli/lib/Ladder.roc` | 497 | Stub | New request fields (`now`, `path_roc` with the file), new facts of `plan` and `plan_replace` (`program`, `env`), the doc of the steps 0a to 0c and 4. The bodies keep the P0 behavior: the specs have `program: "roc"` and `env: []`. |
| `cli/lib/Proxy.roc` | 535 | None (unchanged) | The code agent moves `program`, `child_env`, `last_use`, `installed!`, `clean` and `canonical_at` to `Launch` (N1) |
| `cli/lib/Install.roc`, `ResolveBase.roc`, `Update.roc`, `InstallFlow.roc`, `RemoveFlow.roc`, `VerifyFlow.roc` | 2 to 3 each | Test agent (types) | `Install.compiler!` gives `Try({ id, path }, [NoCompiler])` (it is `Install.on_path_file!`), `ResolveBase.Request.compiler` has the same type, the 3 flows pass `now: request.now` |
| `cli/lib/Fx.roc`, `cli/lib/main.roc` | doc, +1 | Test agent | The doc of `probes!`, the module `Launch` is exposed |
| `cli/RealJobs.roc` | none | None (unchanged) | `start_probe!` still runs the name `roc` (the code agent: `Cmd.new_str(spec.program)` and `.envs_str(spec.env)`, as `exec!` in `cli/RealFx.roc`) |
| `cli/fxprobe.roc` | +10 -2 | Test agent (test tool) | `probes` groups take `program=<file>` and `env:<NAME>=<value>` words (default `roc` on `PATH`) |
| `tests/commands/FakeFx.roc` | +6 -2 | Test agent | `probes!` logs `  probe <dir> <compiler> <program> <args> timeout=<s>` and, for a non-empty `env`, `    env <NAME>=<value> ...` |
| `tests/commands/main.roc` | +2 | Test agent | The harness word `compiler=<id>` is `{ id, path: "<w>/home/bin/roc" }` |
| `tests/unit/launch.roc` | 65 (new) | Test agent | 1 `expect` (3 groups of rows, moved from `proxy.roc` and extended) |
| `tests/unit/compiler.roc`, `ladder.roc`, `verify.roc`, `proxy.roc` | changed | Test agent | Section 5 |
| `tests/commands/cases/probe/pb1-ladder/` | 1 case | Test agent | L2, 9 runs |
| `tests/commands/cases/probe/pb2-verify/` | 1 case | Test agent | L2, 5 runs |
| `tests/scenarios/compilers/pb1-probes-by-path/` | 1 case | Test agent | L3, 6 parts |
| `tests/scenarios/fx/pr1-real-fx-probes/` | cmd +14, `expect/stdout` +11 | Test agent | The real `Fx` runs a program with `env` |
| 17 old L2 cases, `verify/vf1-verify` (L3) | expected files | Script | Section 5 |
| `research/slice-023c-revert/` | | Test agent | `before/` (copies, `NEW.txt`), `stubs/`, `update-calls.py`, `restore-calls.py`, `mutate.py`, `mutate-run.log`, `bk.sh` |

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Probe.Spec` | `{ compiler : Str, program : Str, args : List(Str), dir : Str, env : List((Str, Str)), timeout : U64 }` | R-PX2, R-PX6 |
| `Compiler.require` | `{ id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Try(Str, Fail)`: the id of the compiler that runs (the table is in the doc: installed, then `PATH`, else exit 13) | R-PH7, R-SO22, R-SO10, R-CV1 |
| `Launch.program` | `{ roots : Roots, id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Str` (moved from `Proxy.program`) | R-PX2 |
| `Launch.child_env` | `{ opted_out : Bool, xdg : { path, canonical }, build : { path, canonical } } -> List((Str, Str))` (moved from `Proxy.child_env`) | R-PX6, R-EV17 |
| `Launch.last_use` | `U64 -> Str` (moved from `Proxy.last_use`) | R-CC9 |
| `Launch.toolchains!` | `Fx, Roots => List(Str)`: one `list_dirs!`, `Compiler.installed` (moved from the private `installed!` of `Proxy`) | R-LY1 |
| `Launch.touch!` | `Fx, Roots, { id : Str, now : U64 } => {}`: one `write_atomic!` of `.last-use`, a write error is ignored | R-CC9 |
| `Launch.child_env!` | `Fx, Roots, { opted_out : Bool } => List((Str, Str))`: one `canonical!` call (none when opted out), then `Launch.child_env` | R-PX6 |
| `Ladder.plan`, `Ladder.plan_replace` | the facts have `program : Str` and `env : List((Str, Str))`, each spec of the plan has them | R-PX2, R-PX6 |
| `Ladder.run!`, `Ladder.verify!` | the request has `now : U64` and `path_roc : Try({ id : Str, path : Str }, [NoCompiler])` | R-CC9, R-PX2 |
| `Install.compiler!` | `Fx, Roots, Bool => Try({ id : Str, path : Str }, [NoCompiler])` | R-SO9 |
| `ResolveBase.Request.compiler` | `Try({ id : Str, path : Str }, [NoCompiler])` | R-SO9 |

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/compiler.roc`: `require` (16 rows, rewritten) | Installed (also the other tag form, both ways, also with the same id on `PATH`), only on `PATH` (also the other tag form), not installed with and with no `roc` on `PATH`, a named build, a prefix. The refusal text, kind and code (13), no `TALON_AUTO_INSTALL`, no `P0`, no "only the roc on PATH". | R-PH7, R-SO22, R-SO10, R-CV1, R-BL3, R-DL5, R-EC13 |
| L0 | `tests/unit/launch.roc` (new, 1 `expect`: 6 `program`, 4 `child_env`, 2 `last_use` rows) | An installed id runs from `toolchains/` also when `PATH` has the same id. Only on `PATH`: the file, never `roc`. Canonical paths, a `..` that does not resolve, `TALON_IN_PROXY`, opted out. The time text. | R-PX2, R-SO10, R-PX6, R-PX7, R-EV17, R-CC9 |
| L0 | `tests/unit/ladder.roc` `plan`, `tests/unit/verify.roc` `plan_replace` (rows changed) | Each spec (the 2 checks and the build) has the `program` and the `env` of the facts | R-PX2, R-PX6, R-CC9 |
| L2 | `probe/pb1-ladder` (new, 9 runs, `resolve` entry) | See the list below | R-PX2, R-PX6, R-CC9, R-SO22, R-PH7, R-SO10, R-SO2, R-SO20, R-CV1, R-BL3, R-BL6 |
| L2 | `probe/pb2-verify` (new, 5 runs, `commands` entry) | See the list below | R-PX2, R-PX6, R-CC9, R-SO21, R-SO22, R-PH7, R-SO2, R-PD5 |
| L2 | 17 old cases | The probe line has the program and one `env` line, a ladder run has `list_dirs` and `canonical`, a refused run has `list_dirs` | R-PX2, R-PX6, R-SO22, R-PH7 |
| L3 | `compilers/pb1-probes-by-path` (new, 6 parts) | The real binary and a fake compiler in `toolchains/`: see the list below | R-PX2, R-PX6, R-CC9, R-SO2, R-SO9, R-SO10, R-SO21, R-SO22, R-PH7, R-CV1, R-EC13 |
| L3 | `fx/pr1-real-fx-probes` (3 new parts) | `program` is the file that runs and `env` adds variables (a name of the process is replaced, another stays). Two programs in one round. A program that is not a file does not start. The fake `roc` on `PATH` does not run. | R-PX2, R-PX6, TW4 |

L2 runs of `pb1-ladder` (`fx/runs`, `rules` has the text). The `roc` on `PATH` is the harness word `compiler=<id>` (its file is `$HOME/bin/roc`). Installed: A1 (nightly-2026-10-09-258ab27) and `nightly-2026-October-13-91fa0c2`.

| # | Run | Shows |
| --- | --- | --- |
| 1 | p1: pin A1 (installed), PATH has another id | The program is `toolchains/A1/roc`. `.last-use` is written before the 2 checks and before the build. |
| 2 | p2: pin is the id of PATH, not installed | The program is `$HOME/bin/roc`. No `.last-use`. |
| 3 | p3: pin not installed, not on PATH | Exit 13 after `list_dirs`: no copy, no probe, no write |
| 4 | p4: pin `nightly-2026-10-13-91fa0c2`, installed as `nightly-2026-October-13-91fa0c2` | The program and `.last-use` are in the installed dir. The probe line shows the pin. |
| 5 | p5: pin A1, A1 installed, PATH has A1 too | The installed copy runs (not `$HOME/bin/roc`) |
| 6 | p6: pin not installed, `no-check` | No `list_dirs` of `toolchains`, exit 0 (R-SO22) |
| 7 | p7: no pin, `ROC_TOOLCHAIN=A1` | Rank 2: A1 runs |
| 8 | p8: no pin, `ROC_TOOLCHAIN` not installed | Exit 13 after `list_dirs` |
| 9 | p9: pin is the id of PATH, `ROC_TOOLCHAIN=A1` | The command holds the pin (R-SO20): the file of `PATH` runs, A1 gets no `.last-use` |

L2 runs of `pb2-verify` (`fx/commands`). Workspace of 2 members, pin = PATH id, A1 installed.

| # | Command | Shows |
| --- | --- | --- |
| 1 | `ROC_TOOLCHAIN=A1 verify --file apps/a/main.roc` | R-SO21: the run compiler over the pin. 1 `list_dirs`, 1 `canonical`, 2 writes of `.last-use`, 3 probes by the path of A1 |
| 2 | `ROC_TOOLCHAIN=A1 verify` | 2 members: 1 `list_dirs` and 1 `canonical` for the run, 2 writes of `.last-use` for each member |
| 3 | `verify` | The pin is the id of PATH: `/fake/bin/roc`, no `.last-use` |
| 4 | `ROC_TOOLCHAIN=<not installed> verify` | Exit 13 after `list_dirs` |
| 5 | the same with `--no-check` | No `list_dirs`, exit 0 (R-SO22) |

L3 parts of `pb1-probes-by-path` (`cmd` has the comments). A1 is a fake compiler script in `toolchains/` that logs its id, dir, command, and the 3 variables to `prog.log`. The runs are `tln verify` on the project of `verify/vf1-verify`.

| # | Part | Shows |
| --- | --- | --- |
| 1 | `ROC_TOOLCHAIN=A1` | R-SO21, R-SO2, R-PX2, R-PX6, R-CC9: 3 runs of A1 with the 3 variables, only `version` on the `roc` of `PATH`, `.last-use` has `TALON_NOW` |
| 2 | `XDG_CACHE_HOME` is a link, `ROC_CACHE_DIR` has a `..` | R-PX6: A1 gets canonical paths |
| 3 | `ROC_TOOLCHAIN` not installed | R-SO22, R-PH7, R-EC13: exit 13, the new text, no compiler runs, no dir made |
| 4 | the same with `--no-check` | R-SO22: exit 0 |
| 5 | A launcher (a copy of `tln`) is first on `PATH`, the pin is the id of the `roc` behind it | R-SO9, R-PX2: the fake `roc` runs 3 times by its file, the launcher does not run |
| 6 | The pin is installed and `PATH` has the same id | R-SO10, R-CV1: the installed copy runs, the `roc` on `PATH` does not. `.last-use` of the pin |

Budget: 1 new L0 file with 1 `expect`, 4 `expect`s changed in 3 files (`require`, 2 `plan`, 1 split), 3 new deep cases (L2 2, L3 1), 1 extended L3 case, the changed expected files of 17 L2 cases and 1 L3 case. Times on the stub tree: see section 11.

## 6. Old tests that changed

The changes of the 17 L2 cases are made by `research/slice-023c-revert/update-calls.py` (the inverse is `restore-calls.py`). The independent private reference gave the same files: all 43 L2 cases passed with it, with no `UPDATE=1` for the 17 cases. Each diff was read.

| File | Change | Why |
| --- | --- | --- |
| `tests/commands/cases/<case>/expect/calls.log` for 17 cases: `roc/so1-ranks`, `resolve/rs-new-toml`, `rs-install-add-key`, `rs-workspace-shared-group`, `rs-update-scope`, `rs-highest-use`, `rs-unmanaged`, `gaps/g1-slice009`, `ladder/ld-no-check-refuse`, `ld-ladder-flow`, `remove/rm1-flow`, `workspace/ws2-verify-members`, `verify/vf1-flow`, `install/in1-flow`, `update/up1-flow`, `moves/hm1-noninteractive`, `hm2-interactive` | (1) Each `  probe <dir> <compiler> <args>` has the program after the compiler (`/fake/bin/roc` or, with the harness word `compiler=<id>`, `$HOME/bin/roc`) and one line `    env XDG_CACHE_HOME=$HOME/.cache ROC_CACHE_DIR=$HOME/.cache/roc TALON_IN_PROXY=1` after it. (2) A run that starts the ladder has `list_dirs $HOME/.cache/roc/toolchains` and `canonical $HOME/.cache $HOME/.cache/roc` before its first `random`. (3) A run that the ladder refuses has `list_dirs $HOME/.cache/roc/toolchains` at its end. | Steps 0a to 0c, R-PX2, R-PX6 |
| `roc/so1-ranks`: `expect/calls.log` and `expect/tree.diff` | 2 held compilers are installed in the case (`0.1.3`, `nightly-2026-10-14-0abcdef`): their probes run `toolchains/<id>/roc`, a `write_atomic` of `.last-use` comes before each round (4 lines), and `tree.diff` has the 2 new files `.last-use` (`2026-10-15T12:00:00Z`) | R-CC9. D8 of slice 022 (the probe on an installed compiler was refused) goes. |
| `tests/commands/cases/gaps/g1-slice009/expect/stderr`, `ladder/ld-no-check-refuse/expect/stderr` (2 lines), `tests/scenarios/verify/vf1-verify/expect/stderr` (2 lines) | `the compiler <id> is not installed. This version of tln runs only the roc on PATH (<path id>).` becomes `the compiler <id> is not installed. Run: tln roc install <id>.` | The P0 text is not true any more (section 8) |
| `tests/commands/cases/gaps/g1-slice009/rules` | Run 1 text: one `list_dirs` before the refusal | The new call |
| `tests/unit/compiler.roc` | The `require` `expect` is rewritten (new type, 16 rows, new text) | R-PH7, slice 023c |
| `tests/unit/ladder.roc`, `tests/unit/verify.roc` | The `plan` and `plan_replace` rows have `program` and `env` (3 rows added: the build of a slow plan, in both files) | `Probe.Spec` |
| `tests/unit/proxy.roc` | The `expect` of `program`, `child_env` and `last_use` moves to `tests/unit/launch.roc` (the functions move). The 6 rows of `missing` and `start_failed` stay. 2 imports go. | N1 |
| `tests/scenarios/fx/pr1-real-fx-probes/cmd`, `expect/stdout` | 3 new parts at the end of the probes part (the `tree.diff` is as before: the cmd deletes its file) | The real `Fx` |

Old tests that do not change: the L3 cases that run a probe with the fake `roc` of `PATH` (`roc.log` is the same: the `roc` of `PATH` is run by its file, with the same arguments), `fx/pr2-real-roc-probes` (L4).

## 7. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| The refusal of a compiler that a probe needs (exit 13, kind `consent`) | `the compiler <id> is not installed. Run: tln roc install <id>.` The same text with or without a `roc` on `PATH`. It has no flag name and no `TALON_AUTO_INSTALL` (a resolve command does not read it before slice 025). |
| `.last-use` | The text of the proxy (`2026-10-15T12:00:00Z` and a line end). The same function. |
| The log of the fake `Fx` | `  probe <dir> <compiler> <program> <args> timeout=<s>` and `    env <NAME>=<value> ...` (test tool, not a product output) |
| stdout, `--json` | No change |

## 8. Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | A new module `Launch` holds the code that the proxy and the probes share: `program`, `child_env`, `last_use` and 3 command functions. The code of slice 023 moves there. | The functions stay in `Proxy`: `Proxy` imports `Install`, `Install` imports `Resolve`, and the flows of `Resolve` import `Ladder`, so `Ladder` cannot import `Proxy` (a cycle). A copy in `Ladder` (a second rule for the cache paths). |
| D2 | `Compiler.require` gets `installed` and gives the id that runs. The id of `installed` wins (also the other tag form, R-CV1), then the id of `PATH`. The caller lists `toolchains/` first (one call). | `require` stays an id compare, and `Ladder` checks the listing (the rule is in 2 places). |
| D3 | `Ladder` and `ResolveBase.Request.compiler` carry the file of the `roc` on `PATH` (`{ id, path }`): `Install.compiler!` is `on_path_file!`, which makes the same calls as `on_path!`. | `Ladder` walks `PATH` again (the same calls twice in each run). The name `roc` for the compiler on `PATH` (the launcher can be first on `PATH`, L3 part 5). |
| D4 | One `list_dirs!` and one `canonical!` for each run of `Ladder.run!` or `Ladder.verify!`, not for each member or round. `.last-use` is written before each `probes!` call (each round), for an installed compiler only. | A write for each probe (the 2 probes of a round start together: the same time, 2 writes). One write for each command (a long ladder can pass the GC age of 1 day of R-CC10 only by hours, but "each probe" is the text of R-CC9). Question Q2. |
| D4a | `Spec.compiler` stays the id that the command holds (the pin text, also when the installed id is the other tag form). It is used in the messages. | The installed id. |
| D5 | The variables of a probe are the 3 variables of the proxy (`Launch.child_env` with `opted_out: Bool.False`). `TALON_PROXY=0` has no effect on a probe. Question Q1. | Only the 2 cache variables (R-PX6 names only them). `TALON_IN_PROXY` only for a compiler on `PATH`. |
| D6 | The harness word `compiler=<id>` gives the file `<w>/home/bin/roc`. `fx/path-roc` rows give the file of a `commands` case. | A new word for the file. |
| D7 | `fxprobe probes` groups take `program=<file>` and `env:<NAME>=<value>` words after the dir. The default program is `roc` on `PATH` (the old lines stay valid). | A new call. |
| D8 | A probe through the real `Fx` of a program that cannot start gives `NotStarted(text)` as before (no new case). | |

## 9. Out of scope

| Item | Reason |
| --- | --- |
| The consent for a missing compiler (a prompt, `--allow-downloads`, `TALON_AUTO_INSTALL`, the download) | Slice 025. 023c refuses as P0 did. |
| The gate texts of `Pin.gate` for rank 7 (`This version of tln runs only the roc on PATH, so it cannot select another compiler.`) | The rank 7 gate is unchanged in its rules. The text is slice 025 (R-SO13 and the consent). |
| The unit probes, `tln probe`, `compat.db`, the slots | Slices 030, 031, 037. They use `Spec.program` and `Spec.env` as this slice does. |
| R-PX5 (`--replace-dep` for `[patch]`) | Slice 043 |
| `TALON_PROXY=0` for the probes | Question Q1 |
| `tln tool install` and `tln x` probes of the compiler (R-T*) | Slices 046 to 049 |
| `.last-use` write error | Ignored as in slice 023 (Q7). Not tested. |
| Windows (`.exe` of the compiler file) | Windows CI job |

## 10. Questions (TW17) and design gaps

| # | Text | Default of the tests and of the reference |
| --- | --- | --- |
| Q1 | R-PX6 says that probes use the cache rule of the proxy. R-EV17 says that the proxy sets `TALON_IN_PROXY=1` "for the compiler that it runs". Does a probe set it? It matters for a `roc` on `PATH` that is an old copy of the launcher (R-SO9): without the variable that copy runs as a proxy and can start itself again. And does `TALON_PROXY=0` change a probe? | The probe sets the 3 variables of the proxy (`Launch.child_env`, one function for both). `TALON_PROXY=0` does not change a probe. Pinned by L0 `launch`, L2 (the `env` lines), L3 part 1. A different answer changes `Launch.child_env` callers and the `env` lines of the expected files. |
| Q2 | R-CC9: "each probe writes the time of Talon before the compiler starts". One write for each round (the probes of a round start together), for each command, or for each probe? | One write before each `probes!` call (D4). Pinned by L2 `pb1-ladder`, `pb2-verify` (the order in `calls.log`). |
| Q3 | The text of the refusal for a compiler that is not installed (section 7). The design of R-PH7 gives the P0 text. | The proposal of section 7. |
| G1 | R-PH7 and R-SO22 say that the P0 compiler is a required download "when a probe needs it", and R-PH6 says "ranks 1 to 6 with downloads" for P1. They give no text for the time between 023c (installed compilers run) and 025 (consent). | 023c refuses as `TALON_AUTO_INSTALL=no` would (R-DL5, exit 13). |

## 11. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | Move `Proxy.program`, `Proxy.child_env`, `Proxy.last_use`, the private `installed!`, `canonical_at` and `clean` into `Launch` and make `Proxy.run!` call `Launch` (the doc of `Launch` has the table). `tests/unit/proxy.roc` no longer calls them. Do not keep a copy in `Proxy`. The calls of `Proxy.run!` do not change (the L2 case `proxy/px1-flow` and `px2-install` stay green). |
| N2 | `Ladder.run!` and `Ladder.verify!`: steps 0a to 0c once, then for each member the steps as before with `Launch.touch!` before each `probes!` call (only when `installed` has the id). The reference has a private `start!`, `touch!` and `probes_touched!` (about 25 lines). A function that takes a closed record cannot take a wider one: build the small record at the call (`{ roots: request.roots, path_roc: request.path_roc, held: request.held }`). |
| N3 | `Compiler.require`: the doc has the 3 rows. The text is in section 7. |
| N4 | `RealJobs.start_probe!`: `Cmd.new_str(spec.program).args_str(spec.args).envs_str(spec.env)` (as `exec!`). |
| N5 | Format all files with `roc fmt`. `scripts/test.sh check` is at 7 s alone: the new `tests/unit/launch.roc` is one more file. |

## 12. Revert check (TW12)

Method: a private reference implementation (deleted after the review) made all tests green. `research/slice-023c-revert/mutate.py` applies one hand-made mutation at a time to the reference, runs the steps that can catch it, and logs the result to `research/slice-023c-revert/mutate-run.log`. Result: 35 mutations, 35 caught. 4 first tries (L6, D7, D8, F1) did not compile (an unused variable or a wrong name). `mutate-run.log` holds them as INVALID and, at its end, the run of the 4 new versions: all caught.

| Group | Mutations | What they break | Caught by |
| --- | --- | --- | --- |
| `Compiler.require` | C1 to C6 | The installed id is not found. Tag forms compared with `==` and not `Pin.same_id` (R-CV1). The `PATH` id is taken without a compare. Refusal text with the old hint. Refusal code `Usage` | `tests/unit/compiler.roc`, `probe/pb1-ladder` |
| `Launch` | L1 to L10 | `PATH` file used when the id is also installed. The name `roc` in place of the file. No `TALON_IN_PROXY`. Variables in wrong order. Canonical calls in wrong order or one missing. Wrong `.last-use` time. Text without the newline. Wrong directory for the listing. Wrong item for the `.last-use` file | `tests/unit/launch.roc`, `probe/pb1-ladder`, L3 `compilers/pb1-probes-by-path` |
| `Ladder` | D1 to D14 | No `.last-use` write before the first round, a replace round, a verify round. Write for a compiler on `PATH`. Write with time 0. Wrong env (opted out). `compiler` of the plan is the held id. `env` or `program` lost in a fact. No listing of `toolchains/`. Wrong id for `Launch.program`. A second start for each member | `probe/pb1-ladder`, `probe/pb2-verify`, `tests/unit/ladder.roc`, `tests/unit/verify.roc`, `resolve/rs-workspace-shared-group`, L3 `compilers/pb1-probes-by-path` |
| `RealJobs` | J1, J2 | `env` is not set. The name `roc` runs and not `spec.program` | L3 `fx/pr1-real-fx-probes`, L3 `compilers/pb1-probes-by-path` |
| `Install` | I1 | `Install.compiler!` gives the name `roc` as the file | L2 `rs-unmanaged`, `verify/vf1-flow`, L3 `compilers/pb1-probes-by-path` |
| `InstallFlow` | F1 | An extra `list_dirs` before the check (a call that is not in the flow) | L2 `probe/pb1-ladder` |
| `Proxy` | P1 | `.last-use` written also for a compiler that is not installed | L2 `proxy/px1-flow` |

The mutations of `Ladder` and `Compiler` that change only a `PATH` rule are fixed by the rows with `compiler=<id>` and `installed` in `probe/pb1-ladder`. The script does not run the full sweep (only the entries for what changed).

## 13. State on the stub tree (red)

The tree is the stub tree: the stubs and the type changes are in place, the reference is deleted. `scripts/test.sh check` and `fmt` pass.

| Step | Result on the stub tree | Why it fails |
| --- | --- | --- |
| check | pass | |
| fmt | pass | |
| l0 | 4 files fail: `compiler` (1 of 6 `expect`s: wrong value), `launch` (1 of 1: `todo`), `ladder` (1 of 4: wrong value), `verify` (1 of 2: wrong value) | The stubs keep the P0 behavior |
| l2 | 26 pass, 19 fail | 17 old cases: the new probe line and the new calls. New: `probe/pb1-ladder`, `probe/pb2-verify` |
| l3 | 35 pass, 3 fail, 1 skipped | `compilers/pb1-probes-by-path` (exit 13, not 0; no probe lines; `last use of A1:` empty), `fx/pr1-real-fx-probes` (the fake `roc` runs, not `envprog`), `verify/vf1-verify` (the old P0 text in 2 lines of stderr) |
| selftest | pass | |

Times on the stub tree (the load average was about 12, so they are noisy): check 7.1 s alone (11.8 to 13 s under load), l0 6.7 s, l2 12.5 s, l3 9.4 s, selftest 4.0 s. The budgets are check 10, l0 10, l2 30, l3 60, selftest 20 seconds. The unloaded baseline before the slice was check 7.0, l0 6.1, l2 9.6, l3 9.2, selftest 3.5.

## 14. Review (manager, 2026-10-23)

| Item | Result |
| --- | --- |
| D1 to D8, section 7 proposals | Accepted |
| Q1 | Accepted as chosen: `TALON_IN_PROXY=1` is set for probes. `TALON_PROXY=0` has no effect on probes. |
| Q2 | Accepted: one `.last-use` write for each round. The time is the Talon time of the run, so the content is the same as with a write for each probe. The write is before the compiler starts (R-CC9). |
| Q3 | Accepted: the refusal text. |
| G1 | The P0 refusal stays until slice 025. |
| Reference | `research/slice-023c-revert/reference/` is deleted. `mutate.py` needs it, so it cannot run again. |
| Status | code |

## 15. Code result (code agent, 2026-10-23)

| Item | Result |
| --- | --- |
| `scripts/test.sh` | exit 0: check, fmt, l0, l2, l3, selftest all pass (l0 6.4 s, l2 12.8 s, l3 9.4 s). `OPT=speed`: all pass (l2 79.9 s, over its budget of 30 s, as the build is LLVM). |
| Code | `Compiler.require` (installed id, then `PATH` id, else the refusal of section 7). `Launch`: 6 functions, `clean` and `canonical_at` private. `Proxy` has no copy: it calls `Launch` (N1). `Ladder`: `start!`, `probes_touched!`, `Started`. `RealJobs.start_probe!`: `spec.program`, `spec.env` (N4). |
| Lines | `Launch` 87, `Ladder` 519, `Proxy` 485 (was 535), `Compiler` 234, `RealJobs` 210 |
| Decisions not fixed by the slice | `Ladder.start!` and `Ladder.probes_touched!` are private helpers (N2 names a private `start!`, `touch!`, `probes_touched!`). The record `Started` holds `id`, `installed`, `program`, `env`. Nothing else. |
| Disputes | none: no test, fixture or expected file changed |
| Questions | none |

## 16. Verify results (revert check, TW12)

42 mutations in `research/slice-023c-revert/code-mutate.py`, results in `code-results.md`, the log in `code-run.log`. Caught 41 of 42. Not caught: P3 (`Launch.program` with `installed` in place of `have` after an install in `Proxy.go!`): an equivalent change, because the branch has no `PATH` file with the id. The code after the mutations is the same as `code-final/` (`diff -r`).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Compiler.require` | C1 to C6 | l0 `compiler` |
| `Launch` | L1 to L13 | l0 `launch`, l2 `pb1-ladder` |
| `Ladder` | D1 to D16 | l2 `pb1-ladder`, `pb2-verify`, l0 `ladder`, `verify` |
| `RealJobs` | J1, J2 | l3 `pr1-real-fx-probes` |
| `Install`, `Proxy` | I1, P1, P2 | l2 `vf1-flow`, `px1-flow` |
| `Proxy` | P3 | not caught (equivalent) |

## Close (manager, 2026-10-23)

The code agent decisions are accepted. P3 (not caught) is an equivalent mutation: no test can see it. `scripts/test.sh` exits 0 with no WARN. Status: done.
