# 059 `tln x` of a project tool

Phase: P1. Status: done

Slice 059 changes `tln x` (CLI 6.4: R-PT11, R-CM12, R-X4). In a project, `tln x <key> [-- args]` and `tln x owner/app [-- args]` (no selector) run the project tool of `[tools]` as `tln run` does (R-PT9). `tln x owner/app@<sel>` and `tln x` outside a project are as before (slice 049). The `[tools]` table is the one of R-RUN3 (workspace root, or the file of a standalone project, OP4, NC2, NC5). The command records the project files under the `talon.toml` that it read (R-PD9, OP3, NC1). A project tool never runs a global binary (R-PT12, OP6 (b)).

User answers (`research/talon-scripts/design-draft/DIFF.md`): OP3 and NC1 (record the project files under the `talon.toml`, with no app file the `talon.toml` path itself), OP4 (the `[tools]` of the workspace root of the `talon.toml` that the walk finds, else of that file), NC2 and NC5 (a standalone `talon.toml` stops the walk, its own `[tools]` applies), OP6 (b) (the project tool never uses a global binary, its builds are only in `talon/x/`).

Size (TW19): the plan row says 100. The private reference (`research/slice-059-revert/reference/`, deleted at the review, 2026-10-25) has 126 lines in the new module `XProject` (about 50 are doc comments), 5 more lines in `XFlow`, and a move in `RunFlow` and `RunSteps` (`locate!` and `record_files!` go from `RunFlow` to `RunSteps`, 35 lines, no new logic). The walk is `RunFind` (slice 057), the binary of a key is `RunTools.load!` and `bin!`, the table is `RunTools.table`, the record is `Known.record!`. Nothing of them is written again.

Live reads: none. No real network and no real long build in L0 to L3. L2 uses the fake `Fx`. L3 uses a real child, the real `curl`, the real `roc unbundle` and the fake compiler.

## 1. Rules, and the tests that name them

L0 is the new `expect` 20 of `tests/unit/RunscriptTest.roc` (the 19 old ones stay). L2 is the new case `tests/commands/cases/x/x3-project` (14 runs, 12 + 2 of the gap step). L3 is the new case `tests/scenarios/ptools/pt2-x` (6 steps).

| Rule | Content | Tested by |
| --- | --- | --- |
| R-PT11 (key) | `tln x <key>`: the entry of the key runs, with the words after `--` | L0 20. L2 `x3` runs 1, 4, 5, 7 to 10. L3 steps 1, 4 |
| R-PT11 (app) | `tln x owner/app` with no selector, when an entry has the same app: the project version runs, with the note `project tool <key> <version> (talon.toml)` | L0 20. L2 `x3` run 2. L3 step 2 |
| R-PT11, review Q1 | 2 entries with the app: exit 2 that names both keys, nothing recorded, no child, no `x` cache read. The key of one of them runs it | L0 20. L2 `x3` runs 13, 14 |
| R-PT11 (selector) | `tln x owner/app@<sel>` and `<key>@<sel>`: the user asked for a version, the rules of R-X1 to R-X5 apply, no walk | L0 20. L2 `x3` run 3. L3 step 5 |
| R-PT11 (outside) | No `talon.toml` on the walk: `tln x` is as before | L2 `x3` run 12. `x1-run`, `x2-offline`. L3 step 6 and `tools/tx1-x-run` |
| R-PT11, R-RUN12 | The nearest `talon.toml` of the walk, also from a sub directory | L2 `x3` run 2 (cwd `p1/sub`) |
| R-PT11, R-PT2, OP4 | A member file of a workspace: the table of the root file | L2 `x3` runs 7, 9 |
| R-PT11, NC2, NC5, R-PD5 | A standalone file in a workspace directory: its own table, the root `[tools]` has no effect | L2 `x3` run 8 (the key `foo` is acme/own there, acme/foo in the root) |
| R-PT12 (OP6 (b)) | A project tool never runs the global binary, also for the same bundle hash. No `tools.json` read, no bin dir | L2 `x3` runs 1, 2. L3 steps 1, 4 |
| R-PT9, R-PT6 | The binary of the entry, or its build (fetch, build, entry in `talon/x/`). The same code as `tln run` | L2 `x3` run 4. L3 step 1 |
| R-PT8 | No release list, no yank check, no prompt at run time | L2 `x3` runs 1, 4. L3 steps 1, 2, 4 (`api: 0`) |
| R-PT7 | A key with no `url`: exit 14 (kind `Frozen`, as `tln run`), no child | L2 `x3` run 5 |
| R-PT1 | A `[tools]` that is not valid: exit 19, nothing recorded. The warnings go on stderr | L2 `x3` runs 6, 11 |
| R-X4, R-E1 | The app runs in place of `tln` (`exec!`): the exit code is the exit code of the app | L2 `x3` run 2 (7). L3 steps 1, 2, 4, 5 (3) |
| R-CM12 | The words after `--` are the arguments of the app | L2 `x3` runs 1, 2, 7, 8. L3 step 1 |
| R-PD9, R-PD16 | The project files under the `talon.toml` that was read: a root file records all member files, a member file its node, a standalone file its `main.roc` | L2 `x3` runs 1, 7, 8, 9 (`calls.log`, `projects.json` in `tree.diff`) |
| OP3, NC1, R-PD12 | With no app file, the `talon.toml` path itself | L2 `x3` run 10 |
| R-RUN15 | `tln x` never reads `[scripts]`: a bad `[scripts]` form in `p1` has no effect | L2 `x3` runs 1, 2 |

Other rule ids that the tests name (the slice does not own them): R-PD2, R-PD3, R-PD5, R-PD6, R-WS5, R-TF4, R-X1, R-X2, R-X3, R-B5, R-B8, R-SE8, R-T26, R-HF6, R-PT14.

Rule check: `MISSING=1 scripts/rules.sh R-PT R-X R-PD R-RUN R-B` lists no rule without a test.

## 2. Files

New files (also in `research/slice-059-revert/before/NEW.txt`). The code agent writes the bodies of the stub.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/XProject.roc` (stub) | 44, 126 | Part A: `Hit`, `choose`, `note`. Part C: `run!` (direct style) |
| `tests/unit/RunscriptTest.roc` | 557 to 613 | 1 new `expect` (20) and 2 helpers (`tools_x`, `choose_view`) |
| `tests/commands/cases/x/x3-project/` | 49 files | L2: 14 runs. Its `rules` file has the table |
| `tests/scenarios/ptools/pt2-x/` | `cmd` 39, 18 files | L3: 6 steps |
| `research/slice-059-revert/` | | `stubs/`, `before/`, `ref-off.sh`, `gen-x.py` (writes only the given, fx, entry and rules of the L2 case, no `expect/`), `mut.py`, `mutations.txt`, `red-run.log`, `green-run.log` |

Changed files (a copy of each is in `research/slice-059-revert/before/`):

| File | Change |
| --- | --- |
| `cli/lib/main.roc` | exposes `XProject` (complete, not a stub) |
| `cli/lib/XFlow.roc`, `RunFlow.roc`, `RunSteps.roc` | not changed in the stub state. The code agent changes them (section 10) |
| `tests/commands/cases/x/x1-run/fx/gitdirs`, `x2-offline/fx/gitdirs` | new, one line `.`: the project has a `.git`, so the walk of the new first step stops at `project/` (with no `.git` the walk lists `/tmp/talon-l2`, `/tmp` and `/`, which depends on `TMPDIR`) |
| `tests/unit/RunscriptTest.roc` | the new `expect` 20, 4 imports added (`Ref`, `Scope`, `ToolsToml`, `XProject`) |

Old expected files that changed (TW21): `tests/commands/cases/x/x1-run/expect/calls.log` and `tests/commands/cases/x/x2-offline/expect/calls.log`. In each run that has no selector (a short name or `owner/app`), the 4 lines `cwd`, `list_dirs $PROJECT`, `env_all`, `clock` come after the line `args`: the new walk of `XProject.run!` (a `Miss` has no `talon.toml`, then the global flow starts with its own `env_all` and `clock`). A run with a selector or with a flag that `Args.parse` refuses has no new line. Nothing else changed in those cases (`diff -r` against `research/slice-059-revert/before/tests/commands/cases/x/` shows only these 2 files and the 2 new `gitdirs`). `tools/tx1-x-run` (L3) is not changed. In the stub state these 2 cases fail on those lines until `XFlow` calls `XProject.run!`.

Module plan (TW19, the manager may change it): `XFlow` 198 to 203, `RunFlow` 157 to 123, `RunSteps` 126 to 161, `XProject` 126. All stay under 490.

## 3. Public signatures

The L0 test calls `XProject.choose`, `XProject.many` and `XProject.note`, so these are fixed. `run!` is a proposed structure: the file `calls.log` of `x3-project` fixes the order of the `Fx` calls, not the names.

| Function | Signature |
| --- | --- |
| `XProject.Hit` | `{ entry : ToolsToml.Entry, via : [Key, App] }` |
| `XProject.choose` | `{ ref : Ref, tools : List(ToolsToml.Entry) } -> Try(XProject.Hit, [None, Many(List(Str))])` (`Many`: the keys of 2 entries or more with the app, in line order, review Q1) |
| `XProject.many` | `{ name : Str, keys : List(Str) } -> Fail` (kind `Usage`, exit 2: `<name> is the app of <n> entries of [tools]: <key>, <key>. Use tln x <key>.`, a proposal, TW24) |
| `XProject.note` | `{ key : Str, version : Str } -> Str` |
| `XProject.run!` (proposed) | `Fx, Args, XCmd.Plan => Try(Try(I32, [Miss]), Fail)` (`Miss`: no project tool, the global flow goes on) |
| `RunSteps.locate!` (moved, proposed) | `Fx, { name : Try(Str, [None]), dirs : List(RunFind.Dir) }, RunSteps.Scan, List({ path : Str, exists : Bool }) => Try(RunFind.Found, Fail)` |
| `RunSteps.record_files!` (moved, proposed) | `Fx, RunSteps.Scan, RunFind.Found => List(Str)` |

Order of the `Fx` calls of a run with a project tool (fixed by `calls.log`): `args` (the start of `Run.tln!`), `env_all`, `clock`, `cwd`, then `Project.scan!` (`list_dirs` of the walk, one `read_files` of the `talon.toml` files, `list_dirs` of the members of a root), then (a hit only) `canonical` and the `projects.json` write (R-PD9), then `platform` and the `x` cache read (`RunTools.load!`), then for a build the calls of slice 056, then `exec` of the binary and the words after `--` with no variable. A run with no hit goes on with the calls of slice 049 (its own `env_all` and `clock` first). A run with a selector makes no new call.

## 4. Tests

### L0 (`RunscriptTest`, the new `expect`)

| # | Rows | Rules |
| --- | --- | --- |
| 20 | `XProject.choose` (with 3 rows for 2 entries of one app, review Q1) and `XProject.many` for the operand as typed (`Ref.parse` with the scope `X`) and a table of 4 entries (a range, no selector and no `url`, an exact version, a repo name that is not the key): a key (also an entry with no `url`), the app (no selector, a range, an exact version in the entry), a selector (`@1.0.0`, `@latest`, `@^1`, also on a key), the short name of an app (`fmtr`) that is not a key, a prefix, upper case, a name that no entry has, another owner, `host/path`, no table. `XProject.note` | R-PT11, R-PT12 |

### L2 and L3

| Case | Content |
| --- | --- |
| `x/x3-project` | 14 runs (12 + the gap runs 13 and 14) (the file `rules` has the table). One home as `run/rn3-tools` (the compiler, the `x` entries of fmt, foo and own, the global tool `fmt` with the same bundle hash). Runs: the key with args (1), the app with a note from a sub directory and the exit code 7 (2), a selector (3), a build (4), no `url` (5), a bad table (6), a member file (7), a standalone file in a workspace directory (8), the workspace root (9), a `talon.toml` with no app file (10), an unknown key (11), no `talon.toml` (12) |
| `ptools/pt2-x` | 6 steps with a real child, `curl` and `roc unbundle`: the key builds and runs (exit 3, args), the app with the note and no new build, a global tool of an older release, the project version wins, a selector runs the global tool, outside the project |

L3 does not depend on file age (given files keep the checkout mtime).

## 5. Output (proposed, R-OUT2, TW24)

| Output | Text |
| --- | --- |
| The note for the form `owner/app` (stderr, before the run) | `project tool <key> <version> (talon.toml)`. This is the text of the design (R-PT11). `<version>` is the version of the `url`, `talon.toml` is the file name as written, not the path |
| The note for the form `<key>` | None (the design gives the note for `owner/app` only, see D3) |
| The warnings of `[tools]` (stderr) | `warning: <path>:<line>: <message>`, as `tln run` prints them (slice 057, C8), before the run |
| A key with no `url` | `the [tools] of <path> are not locked: tools.<key> has no url. Run tln install to lock them.` (exit 14, the text of `RunTools.no_url`) |
| A `[tools]` that is not valid | `<path>:<line>: <message>` (exit 19, `RunTools.table`) |
| The lines of a build | `platform <url> (hash <hash>)` and `building <name> <version> with <compiler>` (R-SE8, as `tln x` and `tln run`) |

No new text of Talon. Each other text is the text of an earlier slice.

## 6. Decisions that the design does not fix (the test agent chose)

| # | Decision | Chosen | Rejected |
| --- | --- | --- | --- |
| D1 | Which `talon.toml` the walk finds for `tln x` (R-PT11 says "the walk of R-RUN12", which looks for a script name) | The nearest `talon.toml` of the walk (`RunFind.find` with a file that always holds the name). Its table is the root's for a workspace file, its own for a standalone file. A file further up cannot change the table: the walk stops at the root and at a standalone file | The first file that has the key (the same result: all files of one workspace have the table of the root) |
| D2 | When the walk finds a `talon.toml` and no entry has the key or the app | `Miss`: `tln x` goes on as before, with no record (Q3) | An error. A record |
| D3 | The note for the form `<key>` | None. The design gives the note for `owner/app` only, so the user who typed the key knows the source | The same note for both forms |
| D4 | The app runs with `exec!` (in place of `tln`, R-X4) and no variable. Not `exec_in!` with `TALON_SCRIPT` (R-RUN9 is for the steps of a script) | `exec!` with `env: []`, as slice 049 | `exec_in!` |
| D5 | The order of the checks of a hit: the record (R-PD9) first, then the warnings, the `url`, the note, the binary | As `tln run` (slice 057: the record is made also when a later step fails) | Record after the run |
| D6 | The new first step of a run with no selector makes its own `env_all` and `clock`, and the global flow makes them again | Two calls each (the fake `Fx` shows them in `calls.log`, 4 lines in each old run) | A change of `ToolFlow.machine_for!` to take them (a change in a module of slice 047) |
| D7 | `.git` in the old L2 cases `x1-run` and `x2-offline` (`fx/gitdirs`) | Added: the walk stops at `project/` | No `.git`: the calls name `/tmp/talon-l2` and depend on `TMPDIR` |
| D8 | A bad `[tools]` in the nearest `talon.toml` blocks a run with no selector that is not a project tool (a global short name) | Yes, exit 19 (the table is read before the choice), not tested for a global name | Read the table only for a key that looks like a project key |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| R-PT15 (offline, missing bundle: exit 15), R-DL7 and R-DL2 (the consent stop of a build: exit 13), R-PT16 (a wasm platform), a failed build (exit 11) | The code is `RunTools.bin!` and `ToolsStep.ensure!`, shared with `tln run`. Slice 057 tests them through `rn3-tools` runs 5, 6, 10 |
| R-PT13, R-PT14, R-B4 (GC and the take-over of an entry of a project tool) | slices 028 and 049 and 056 |
| `--git`, `--path`, `--resolve` with a key | `tln x` says `not built yet` before the walk (slice 049, `XCmd.read`) |
| A `[tools]` entry in `tln x` with `--roc` and `--allow-unchecked` | Q2 |
| The note when a global tool and a project tool have the same name | R-RUN11 (`tln run` with no name), slice 057 |

## 8. Questions (TW17) and design gaps

| # | Question | Where | In the reference (not tested) |
| --- | --- | --- | --- |
| Q1 | Two entries of `[tools]` have the same app (two keys, two refs). `tln x owner/app` with no selector: which one runs? | R-PT11, R-PT3 | Answered at the review: exit 2 (`XProject.many`), see Review |
| Q2 | Do `--roc` and `--allow-unchecked` of `tln x` apply to a project tool? R-PT11 says "as R-PT9" (the compiler is the pin of the app, the consent is R-DL1 to R-DL6 with `--yes`) | R-PT11, R-X1, R-PT9 | Both are ignored. `--yes` and `--offline` reach the build |
| Q3 | The nearest `talon.toml` has no entry for the key or the app (D2). Does `tln x` record the project files (R-PD9: "each project file that it reads")? | R-PD9, R-PT11 | No: nothing is recorded, the run is as before. No case runs this (run 12 has no `talon.toml`) |
| Q4 | Two `owner/app` names of one app that differ only in case (`Acme/Fmt`, `acme/fmt`) | R-PT11, Design 4.1 | An exact text compare (the same as `ToolsToml.app_of`) |

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| `==` on a `Try` does not compile | `choose` and `run!` use `match` for the selector (`Err(None)` is a tag, so no `==`) |
| A mutation that leaves a variable unused is a warning (exit 2) | `mut.py` writes `or !has_main` for the NC1 mutation |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Order | One pass: `XProject.choose` and `note` (L0 20), then the move in `RunSteps`, then `run!` and `XFlow` (L2, L3). Filter the runs: `tests/commands/run.sh x/`, `tests/run.sh ptools/pt2-x tools/tx1` |
| `RunSteps` | Move `locate!` and `record_files!` out of `RunFlow` (the code is as it is, `locate!` takes the walk as an argument: `{ name, dirs }`, and `RunFlow` gives `find_dirs(scan)`). The reference: `RunFlow` 157 to 123 lines, `RunSteps` 126 to 161. The L2 and L3 cases of slices 057 and 058 stay green |
| `XFlow` | `run!` calls `XProject.run!(fx, args, plan)` right after `XCmd.read`. `Ok(Ok(code))` is the exit code, `Err(fail)` goes to `Common.failed!`, `Ok(Err(Miss))` goes on with `flow!` (the code of slice 049, not changed) |
| The walk | `RunSteps.locate!` with `name: Ok(holder)` and a walk in which each existing `talon.toml` has the one name `holder` and a good form (so `[scripts]` is not read, R-RUN15). Any failure of `locate!` is `Miss` (it is "no talon.toml"; a bad form cannot happen with this walk) |
| The table | `found.tools_dir` and the text of that directory in `scan.walk`, `RunTools.table`. `RunTools.Run` has `net: Net.from_env(env)` and `path`, `text`, `tools` of the table, as `RunSteps.tool_run` |
| The binary | `RunTools.load!(fx, roots)` once, `RunTools.bin!(fx, args, run, know, entry)`, then `fx.exec!({ argv: [bin] ++ plan.args, env: [] })`. `Err(NotStarted(text))` is `XCmd.start_failed` (exit 18) |
| The note | Only for `via: App`, on stderr, with `Ident.of_url(url).version` |
| Tests | do not edit the tests (TW18). A wrong test goes back to the test agent |

## 11. Red run, revert check

Red run with the stubs (`research/slice-059-revert/red-run.log`): `scripts/test.sh` (all steps).

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest, l1 | pass | the stub compiles with no warning |
| l0 | 1 failed, 63 passed | the new `expect` 20 of `RunscriptTest`: `ROC CRASHED todo: slice 059` (`research/slice-059-revert/red-l0.log`) |
| l2 | 3 failed, 142 passed | `x/x3-project` (a wrong value: `XFlow` is not wired, so each run goes the global way: a release list request that gives `no GitHub repository acme/fmt`, no record, other calls). `x/x1-run` and `x/x2-offline` (the new lines of the walk are missing) |
| l3 | 1 failed, 76 passed, 1 skipped | `ptools/pt2-x` (step 1 gives exit 2 with the same message). `tools/tx1-x-run` passes |

Green run with the reference (`green-run.log`): all steps pass (l0 7.4 s of 10 s, l2 7.9 s, l3 10.0 s).

Revert check (`mutations.txt`, 8 mutations of the most tricky behaviors, filtered runs, the reference is put back after each one): every mutation is killed by at least one layer.

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| a key also matches the repo name of an app | killed | survived | survived |
| a selector does not stop the project path | killed | killed | killed |
| no record of the project files (R-PD9) | survived | killed | killed |
| the words after `--` are not passed | survived | killed | killed |
| an entry with no `url` is a `Miss` (no exit 14) | survived | killed | survived |
| a standalone file in a workspace directory uses the root table (NC2) | survived | killed | survived |
| a `talon.toml` with no app file records `main.roc` (NC1) | survived | killed | survived |
| a key (a short name) never takes the project path | survived | killed | killed |

## Review (manager, 2026-10-25)

D1 to D8, the TW21 change of `x1-run` and `x2-offline` (with `fx/gitdirs`) and the TW24 texts are accepted. No split.

| # | Answer | Change |
| --- | --- | --- |
| Q1 | Two `[tools]` entries with the same app and `tln x owner/app`: exit 2 that names both keys and says to use `tln x <key>` | `choose` gives `Err(Many(keys))`, new `XProject.many` (the text is a proposal). L0 20 has 4 more rows and the text. No L2 run (the manager asked for one L0 row). Hand mutation (first entry wins): killed by L0. Green run after the change: all steps pass |
| Q2, Q3, Q4 | Accepted as the reference does. The manager records them as design gaps | none |

Red state after the review (`scripts/test.sh`, stubs): l0 1 failed (todo), l2 3 failed, l3 1 failed, as section 11.

## Verify results (code agent, 2026-10-25)

`scripts/test.sh` exits 0: check pass, fmt pass, l0 pass (7.2 s of 10 s, 568 expects in 8 drivers), l2 pass (145 cases, 8.7 s), l3 pass (77 scenarios, 1 skipped, 10.0 s), selftest pass, l1 pass (35.7 s).

| File | Lines |
| --- | --- |
| `cli/lib/XProject.roc` | 151 |
| `cli/lib/XFlow.roc` | 204 |
| `cli/lib/RunFlow.roc` | 123 |
| `cli/lib/RunSteps.roc` | 163 |

`locate!` and `record_files!` moved from `RunFlow` to `RunSteps` with no change of behavior (`locate!` takes `{ name, dirs }`, `RunFlow` gives `find_dirs(scan)`). `XFlow.run!` calls `XProject.run!` after `XCmd.read`.

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Order inside a hit | table, choice, then (hit only) record, warnings, `url` check (exit 14 before any `RunTools.load!` call, as `calls.log` of run 5 shows), note, `load!`, `bin!`, `exec!` | `bin!` alone for the `url` check (it would run `load!` first) |
| A failure of `Project.scan!` or `Roots.from_env` in the new first step | The failure ends the command (as `tln run`, D8) | `Miss` |
| A `host/path` operand with no selector | The walk runs, `choose` gives no hit, `Miss` | No walk |
| Warnings of the table with no hit | Not printed (nothing is read for a `Miss`) | Print them |

Disputes (from the code agent): none. No test changed.

Revert check: caught 8 of 8 (`research/slice-059-revert/agent-results.md`). Copy of the code: `code-final/`, `code-final.sha256`.

## Gap step (test agent, 2026-10-25)

Code agent decisions, checked against the design:

| Decision of the code | Design | Result |
| --- | --- | --- |
| Order in a hit: table, choose, record, warnings, url check, note, `load!`, `bin!`, `exec!` | Not fixed (R-PD9 says "records each project file that it reads", R-PT7 gives the exit code, not the order of calls) | The same as the reference. `calls.log` of `x3` runs 1, 5, 13 fixes it (run 5: the record, then no `platform` and no `x` read). No new row |
| Explicit `url` check before `RunTools.load!` | Not fixed (the exit code 14 is) | As above. Run 5 pins it |
| `Project.scan!` or `Roots.from_env` fails in the new first step: the failure ends the command | Not fixed. R-PT11 says "outside a project, `tln x` is as before"; R-TF4 stops a command for a `talon.toml` that is not valid | Question Q5. No row |
| `host/path` operand with no selector: the walk runs, no hit, `Miss` | R-PT11 names `<key>` and `owner/app` only. A `ref` of `[tools]` is `owner/app` (R-PT1), so no entry can match a `host/path` | The result (a `Miss`) follows from the design. That the walk runs is not observable but in `calls.log`. L0 20 has the `host/path` row. No new row |
| The warnings of `[tools]` are not printed on a `Miss` | R-TF4: "an unknown key or table gives a warning that names it, and the command goes on". It does not say which commands read which tables | Question Q6. No row |

New rows (one hand mutation each, the code was put back and `sha256sum -c code-final.sha256` passes):

| Layer, file | Rows | Rules | Hand mutation | Result |
| --- | --- | --- | --- | --- |
| L2 `x/x3-project` | run 13 `x acme/fmt` in `p10` (2 entries for acme/fmt): exit 2, the text of `XProject.many`, no record, no `platform` call. Run 14 `x fmt2` in `p10`: the key runs its entry. `p10` is new in the given files | R-PT11, review Q1 | `Err(Many(_)) => Ok(Err(Miss))` in `XProject.table!` (the command goes the global way) | killed (stderr and `calls.log` differ) |

The gap step changed `expect/` of `x3-project` only: `calls.log` (25 lines added), `stderr` (1 line), `stdout` (4 lines), `tree.diff` (the `projects.json` line has `p10`, from run 14). The old expected files are in `research/slice-059-revert/gap-before/x3-project/`.

| # | Question | Where | In the code (not tested) |
| --- | --- | --- | --- |
| Q5 | A failure of the walk (`Project.scan!`: a `talon.toml` of the walk that has a bad `[workspace]`, or a bad `HOME`) in a `tln x` of a short name or `owner/app` with no selector. Is it the failure of the walk (exit 19 or 18), or is `tln x` as before (outside a project)? | R-PT11, R-TF4, R-PD2 | The failure ends the command, also for an app that no project tool names |
| Q6 | The table `[tools]` has an unknown key and the operand is no entry (a `Miss`). Does `tln x` print the R-TF4 warning? | R-TF4, R-PT1 | No warning on a `Miss` |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-059-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.5, fmt 0.3, l0 7.6, l2 9.0, l3 9.8, selftest 2.9, l1 36.8 s |
| Code pass | 8 of 8 mutations caught |
| Gap tests | L2 `x3-project` runs 13 (two entries for one app: exit 2, `Use tln x <key>.`) and 14 (the second key runs); 1 hand mutation caught; no code bug |
| Q5, Q6 | Not fixed by the design. The code stops on a walk failure and prints no R-TF4 warning on a `Miss`. Recorded as design gaps in PLAN-P1 5b. |
