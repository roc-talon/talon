# 057 `tln run` and `[scripts]`

Phase: P1. Status: done

Slice 057 adds the command `tln run [<name>] [-- <args>]` (CLI 1: R-RUN1 to R-RUN17, R-CM24). A script is a list of steps in the table `[scripts]` of `talon.toml`. A step is one command (no shell), `@<name>` (a call of another script of the same file), or `{ in = "<dir>", run = "<step>" }`. The first word of a step is `roc`, `tln`, a key of `[tools]` (the project tools of slice 056, R-PT8 to R-PT10), a `.roc` script, or a program on `PATH`. `tln run` with no name lists the scripts.

Size (TW19): the plan row says 350. The private reference (`research/slice-057-revert/reference/`, kept until the review is applied) has 853 lines in 6 new modules (`ScriptsToml` 190, `RunCmd` 30, `RunPlan` 155, `RunFind` 137, `RunTools` 105, `RunFlow` 236), and about 45 lines of change in `Fx`, `RealFx`, `Project`, `Intent`, `Args`, `Run`, `main`. This is over 500 lines: section 12 proposes a split in 3 parts (057a, 057b, 057c).

Live reads: none. No real network and no real long build in L0 to L3. L2 uses the fake `Fx` (no child runs). L3 uses real `sh` children, a fake compiler (a shell script), the real `curl`, the real `roc unbundle`.

Not in this slice: `--each` and `[run]` (slice 058, R-EA1 to R-EA8, R-RUN13), `tln x <key>` (slice 059, R-PT11).

## 1. Rules, and the tests that name them

L0 is `tests/unit/RunscriptTest.roc` (11 `expect`s, numbered 1 to 11 in file order). L2 is the 3 cases `tests/commands/cases/run/rn1-scripts` (35 runs), `rn2-words` (5 runs), `rn3-tools` (11 runs). L3 is `tests/scenarios/run/rn1-flow` (13 steps) and `tests/scenarios/fx/px2-real-fx-exec-in` (7 rows).

| Rule | Content | Tested by |
| --- | --- | --- |
| R-CM24 | `run` is a top-level command | L0 7. L2 `rn1` runs 20, 21. L3 `rn1-flow` step 1 |
| R-RUN1 | The form of `[scripts]` (name, string, table step, array). Exit 19 with the first issue by line | L0 1, 2. L2 `rn1` run 23 |
| R-RUN2 | A step is one command. Words, quotes, no expansion, shell words and a quote that is not closed refused before the first step (Q3) | L0 3, 4. L2 `rn1` runs 1, 9, 35. L3 steps 2, 3, 8 |
| R-RUN3 | The first word: `roc`, `tln`, a `[tools]` key, `.roc`, `PATH`. The environment is not changed (no `PATH` entry) | L0 5. L2 `rn2` runs 1 to 3. `rn3` runs 1, 2, 7, 8. L3 steps 2, 10, 12 |
| R-RUN4 | `@<name>`: expands to the steps of that script. A cycle and a missing name are exit 19 | L0 4. L2 `rn1` runs 2, 3, 4, 8, 10. L3 step 4 |
| R-RUN5 | Steps run in order, one child at a time, with the terminal of `tln` and the directory of the step | L2 `rn1` runs 1, 5. `rn2` run 1. L3 steps 2, 5. L3 `px2` |
| R-RUN6 | A word that ends with `.roc` runs as `roc <file> -- <other words>` (the `--` always) | L0 5. L2 `rn2` runs 3, 5 |
| R-RUN7 | The first step that fails gives the exit code of the run. A signal gives 128 + n. A program that cannot start is exit 18 | L0 6. L2 `rn1` runs 5, 6, 7. `rn2` run 4. `rn3` run 10. L3 steps 5, 6, 7. L3 `px2` |
| R-RUN8 | `in` steps: own directory, inside the repository (else exit 19), `@name` there reads the `talon.toml` of that directory | L0 4. L2 `rn1` runs 4, 11, 12, 13. `rn3` run 2. L3 step 4 |
| R-RUN9 | The 2 variables `TALON_SCRIPT` and `TALON_SCRIPT_DIR` | L0 6. L2 `rn1` runs 1, 4 (in `calls.log`). `rn2` run 1. L3 steps 2, 4 |
| R-RUN10 | Args after `--` go to the last step (and through `@name` to its last step). A word after the name with no `--` is exit 2. Words after `--` and no name are exit 2 (Q1) | L0 4, 7. L2 `rn1` runs 2, 3, 15, 34. `rn2` run 3. L3 steps 3, 11 |
| R-RUN11 | No name: the list (text, and `--json` in `data`). A name with `--json` is exit 2 | L0 6, 7, 8. L2 `rn1` runs 16, 20, 21. `rn3` run 9. L3 step 1 |
| R-RUN12 | Which `talon.toml`: the walk, the stop at a root and at a standalone file, member files (NC2, NC4, NC5) | L0 8. L2 `rn1` runs 14, 22 to 33 |
| R-RUN14 | `[scripts]` is allowed in every role (root, member, standalone) | L0 9. L2 `rn1` runs 24, 25 |
| R-RUN15 | No other command reads `[scripts]` | L0 9. L3 step 13 |
| R-RUN16 | `tln run` resolves nothing and writes no project file | L2 `rn1` (no `read` of `index`, no write but `projects.json`). `rn3` runs 1, 3. L3 steps 10, 13 |
| R-RUN17 | `tln build` is an unknown command (a script name is no command) | L0 7. L2 `rn1` run 19. L3 step 9 |
| R-PT8 | A project tool in `tln run`: no release list, no yank check, no prompt | L2 `rn3` runs 1, 3. L3 steps 10, 11 (`api: 0`) |
| R-PT7 | A `[tools]` key with no `url` in a step is exit 14 and names `tln install` (Q2) | L0 11. L2 `rn3` run 11 |
| R-DL7 | The consent stop of a build in `tln run` names `--yes` and `TALON_AUTO_INSTALL=yes` (Q6) | L0 11. L2 `rn3` run 5 |
| R-PT9 | `tln run` uses the build of the `url`, or builds it (the `run` part) | L2 `rn3` runs 1, 3, 4, 5, 10. L3 steps 10, 11 |
| R-PT10 | `tln run` adds no directory to `PATH` | L2 `rn3` run 1 (`exec_in` env lines). L3 step 10 (`penv`) |
| R-PT12 | No `tools.json`, no bin dir, no lock in `tln run` | L2 `rn3` runs 1, 3. L3 step 10 |
| R-HK1, R-SE17 | `install`, `list` and the other commands run no script | L3 step 13 |
| R-PD9 | `tln run` records the project files: root: all members, member: its node, standalone: `main.roc` or the `talon.toml` (NC1) | L2 `rn1` runs 1, 22, 24, 25, 26, 27, 28 (`projects.json` write in `calls.log`) |

Other rule ids that the tests name (the slice does not own them): R-FL1, R-FL3, R-FL6, R-FL7, R-FL12, R-PD2, R-PD3, R-PD5, R-PD6, R-PD16, R-WS5, R-EC18, R-E1, R-J3, R-PX1, R-PT1, R-PT2, R-PT6, R-PT14, R-PT15, R-DL2, R-DL7, R-B9, R-X2, TW4. User answers NC1, NC2, NC4, NC5, OP4, Q-S15 (b) are named in the comments.

Rule check: `MISSING=1 scripts/rules.sh R-RUN R-CM R-PT R-HK R-SE R-PD` lists only R-RUN13 (`--each`, slice 058) of the rules of this slice.

## 2. Files

New files (also in `research/slice-057-revert/before/NEW.txt`). The code agent writes the bodies of the 6 stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/ScriptsToml.roc` (stub) | 55, 190 | Part A: `Step`, `Script`, `is_name`, `read_table`, `read`, `words`, `step_text` |
| `cli/lib/RunCmd.roc` (stub) | 22, 30 | Part A: `Cmd`, `read` (the line of `tln run`) |
| `cli/lib/RunPlan.roc` (stub) | 74, 155 | Part A: `plan`, `program`, `env`, `start_failed`, `list_text`, `list_data`, `path_note` |
| `cli/lib/RunFind.roc` (stub) | 37, 137 | Part A: `find` (which `talon.toml` holds the script) |
| `cli/lib/RunTools.roc` (stub) | 54, 105 | Part A `table`. Part C `load!`, `bin!` (the binary of a `[tools]` key) |
| `cli/lib/RunFlow.roc` (stub) | 42, 236 | Part C: `run!` (direct style) |
| `tests/unit/RunscriptTest.roc` | about 340 | 11 `expect`s (L0) |
| `tests/commands/cases/run/rn1-scripts/` | 29 files | L2: 35 runs |
| `tests/commands/cases/run/rn2-words/` | 19 files | L2: 5 runs |
| `tests/commands/cases/run/rn3-tools/` | 49 files | L2: 11 runs |
| `tests/scenarios/run/rn1-flow/` | `cmd` 64, 19 files | L3: 13 steps |
| `tests/scenarios/fx/px2-real-fx-exec-in/` | `cmd` 21 | L3: the real `exec_in!` with `fxprobe` (TW4) |
| `research/slice-057-revert/` | | `reference/`, `stubs/`, `before/`, `ref-on.sh`, `ref-off.sh`, `mkstubs.py`, `gen-run.py` (writes the given, fx, entry and rules of the 3 L2 cases, no `expect/`), `mut.py`, `mutations.txt`, `red-run.log`, `green-run.log`, `expect-before.tgz` |

Changed files (a copy of each is in `research/slice-057-revert/before/`). These changes are complete (not stubs), because they are test infrastructure or wiring:

| File | Change |
| --- | --- |
| `cli/lib/Fx.roc` | the new call `exec_in!`: `{ argv, env, cwd } => Try(I32, [NotStarted(Str)])` (field and wrapper) |
| `cli/RealFx.roc` | `exec_in!` in the record. Its body is a stub (`crash`): the code agent writes it with `Cmd.cwd` (the reference is 10 lines, as `exec!`) |
| `cli/fxprobe.roc` | the call `exec-in <dir> [NAME=value]... -- <argv>` (a probe, no Talon logic) |
| `tests/commands/FakeFx.roc`, `FakeJobs.roc` | the fake `exec_in!`: the log line `exec_in <cwd> <argv>` and one `  env` line for each variable, the code from `fx/exec` rules |
| `cli/lib/Args.roc` | `run` is a top-level command (only the global flags; `--file`, the resolve flags and `--allow-downloads` are refused) |
| `cli/lib/Run.roc` | `import RunFlow`. A branch `args.command == ["run"]` calls `RunFlow.run!(fx, args, \|inner\| Run.tln!(inner))`. The function is passed in to avoid an import cycle |
| `cli/lib/main.roc` | exposes `ScriptsToml`, `RunCmd`, `RunFind`, `RunFlow`, `RunPlan`, `RunTools` |
| `cli/lib/Project.roc` | the public `scan!` (a stub): the walk, the root and the members, with no project file chosen |
| `cli/lib/Intent.roc` | not changed in the stub state. The code agent adds `"scripts"` to `known_tables` and `member_tables` (2 words). L0 9 is red until then |
| `tests/unit/l0-7.roc` | `import RunscriptTest` |

Old expected files that changed (TW21): none. All 1039 files of `expect/` of old cases are the same as in `research/slice-057-revert/expect-before.tgz` (`cmp` of each file).

Module plan (TW19, the manager may change it): `Project.roc` is 364 lines before, 370 with the stub and 377 in the reference. `Run.roc` 185, `Fx.roc` 298, `Intent.roc` 395. All stay under 490.

## 3. Public signatures

The L0 tests call `ScriptsToml`, `RunCmd`, `RunPlan`, `RunFind` and `RunTools.table`, so these are fixed. `RunTools.load!`, `bin!`, `RunFlow.run!` and `Project.scan!` are a proposed structure: the `calls.log` files fix the order of the `Fx` calls, not the names. The stubs in `cli/lib` have the full doc comments with the tables of the cases.

### ScriptsToml (fixed, L0 1 to 4)

| Function | Signature |
| --- | --- |
| `Step` | `[Line(Str), In({ dir : Str, run : Str })]` |
| `Script` | `{ name : Str, steps : List(Step), line : U64 }` |
| `is_name` | `Str -> Bool` |
| `read_table` | `Toml -> { value : List(Script), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }` |
| `read` | `{ path : Str, text : Str } -> Try(List(Script), Fail)` |
| `words` | `Str -> Try(List(Str), [Shell(Str), Unclosed])` |
| `step_text` | `Step -> Str` |

### RunCmd, RunPlan, RunFind, RunTools.table (fixed, L0 5 to 10)

| Function | Signature |
| --- | --- |
| `RunCmd.Cmd` | `{ name : Try(Str, [None]), args : List(Str) }` |
| `RunCmd.read` | `Args -> Try(Cmd, Fail)` |
| `RunPlan.File` | `{ dir : Str, scripts : Try(List(ScriptsToml.Script), [NoFile]) }` |
| `RunPlan.Flat` | `{ dir : Str, words : List(Str), text : Str, owner : Str }` |
| `RunPlan.Want` | `{ start : { dir : Str, name : Str }, args : List(Str), stop : Str, files : List(File) }` |
| `RunPlan.plan` | `Want -> Try(List(Flat), [Need(Str), Stop(Fail)])` |
| `RunPlan.program` | `{ words : List(Str), keys : List(Str) } -> Try([Roc(List(Str)), Tln(List(Str)), Tool({ key : Str, args : List(Str) }), Path({ program : Str, args : List(Str) })], [NoWords])` |
| `RunPlan.env` | `{ script : Str, dir : Str } -> List((Str, Str))` |
| `RunPlan.start_failed` | `{ owner : Str, text : Str, program : Str, why : Str } -> Fail` |
| `RunPlan.list_text`, `list_data` | `{ file : Str, scripts : List(Script) } -> Str`, `-> JsonDoc` |
| `RunPlan.path_note` | `Str -> Str` |
| `RunFind.Dir` | `{ dir : Str, toml : Try({ names : List(Str), bad : Try(Str, [None]) }, [None]) }` |
| `RunFind.Facts` | `{ name : Try(Str, [None]), walk : List(Dir), root : Try(Str, [NoWorkspace]), members : List(Str), probes : List({ path : Str, exists : Bool }) }` |
| `RunFind.Found` | `{ dir : Str, kind : [Root, Member, Standalone], tools_dir : Str, members : List(Str), stop : Str }` |
| `RunFind.find` | `Facts -> Try(Found, [Need(List(Str)), Stop(Fail)])` |
| `RunTools.table` | `{ path : Str, text : Str } -> Try(Table, Fail)` with `Table : { tools : List(ToolsToml.Entry), warnings : List(Str) }` |
| `RunTools.no_url` | `{ path : Str, key : Str } -> Fail` (kind `Frozen`, exit 14) |
| `RunTools.stop` | `Fail -> Fail` (the consent stop of `ToolsPlan.compiler_stop` with `--yes` in place of `--allow-downloads`) |

### Proposed structure (not fixed by an L0 test)

| Module | Function | Signature |
| --- | --- | --- |
| `RunFlow` | `run!` | `Fx, Args, (Fx => I32) => I32` (the last argument runs a `tln` step) |
| `RunTools` | `load!` | `Fx, Roots => Try(Know, Fail)`: once for a run, at the first tool step |
| `RunTools` | `bin!` | `Fx, Args, Run, Know, ToolsToml.Entry => Try({ bin : Str, know : Know }, Fail)` |
| `Project` | `scan!` | `Fx, { start : Str, home : Str } => Try({ walk : List({ dir, names, toml }), root, members }, Fail)` |
| `Fx` | `exec_in!` | see section 2 |

Order of the `Fx` calls of `RunFlow.run!` (fixed by the L2 `calls.log` files): `env_all`, `clock`, `cwd`, then `Project.scan!` (`list_dirs`, one `read_files` of the `talon.toml` files, `list_dirs` of the members of the root), a `read_files` of the paths that `RunFind` asks (NC4), `canonical` and the `projects.json` write (R-PD9), then for a name: `read_files` of the `talon.toml` of each `in` directory, and one `exec_in` for each step; for a tool step `machine`, the `x` entries, and the build calls of slice 056.

## 4. Tests

### L0 (`RunscriptTest`)

| # | Rows | Rules |
| --- | --- | --- |
| 1 | forms of `[scripts]`: string, array, table step, `"check:wasm"` key, comment, no table. `is_name` good and bad names (64 and 65 bytes) | R-RUN1, R-RUN14 |
| 2 | the failures by line (exit 19), the first one by line wins | R-RUN1 |
| 3 | `words`: quotes, escapes only in `"..."`, backslash, no expansion, empty quoted word, quoted shell characters, each refused word, `$(`, backquote, an unclosed quote (3 rows), `a"b c"d` is `ab cd` | R-RUN2 |
| 4 | `plan`: args to the last step (and through `@`), `in` with `Need`, missing file, cycle, self cycle, missing name, shell word, unclosed quote, no command, outside repository, `..` equal to the stop | R-RUN4, R-RUN8, R-RUN10, R-RUN2 |
| 5 | `program`: `roc`, `tln`, key, `.roc` (the `--`), `.roc` key, path, no word, a key `roc` is shadowed | R-RUN3, R-RUN6 |
| 6 | `env`, `start_failed` (exit 18), list text, list `data`, path note | R-RUN9, R-RUN7, R-RUN11 |
| 7 | `RunCmd.read` with `Args.parse`: list, name, args, 2 words, name with `--json`, refused flags, `tln build` | R-RUN10, R-RUN11, R-RUN16, R-RUN17, R-CM24 |
| 8 | `RunFind.find`: no workspace, root, member, standalone in a workspace dir (NC2, NC5), NC4 with and without the probe, bad form, list mode, no file | R-RUN12, R-PD9 |
| 9 | `Intent.read` of `[scripts]` in 3 roles gives no warning and no failure. `[tools]` in a member is still exit 19 | R-RUN14, R-RUN15 |
| 10 | `RunTools.table`: keys, warnings, first failure | R-RUN3, R-PT1 |
| 11 | `RunTools.no_url`, `RunTools.stop` (a consent stop of another text stays) | R-PT7, R-DL7 |

### L2 and L3

| Case | Content |
| --- | --- |
| `run/rn1-scripts` | 35 runs (run 34: `run -- x`, run 35: an unclosed quote): the rules table of the case (file `rules`) has the rows. Words, args, `@`, `in`, env, exit codes, signal, cycle, shell word, outside repository, not found, usage, `--json`, `--file`, `--frozen`, `tln build`, the list, `--json` list, standalone with no app file, bad form, workspace root, member, standalone in a workspace (NC2, NC5), NC4, no `talon.toml` |
| `run/rn2-words` | 5 runs: `roc +<id> version` through the proxy, `tln --version` in process, a `.roc` script with args, `tln frobnicate` stops the run (exit 2), a `.roc` script with no more words |
| `run/rn3-tools` | 11 runs (run 11: a key with no `url`): a project tool binary while a global tool with the same key exists, an `in` step, a build in `run` then reuse, no compiler (exit 13), `--offline` (exit 15), the table of the workspace root used from a member, standalone in a workspace, the list with the `PATH` note, a failed build (exit 11), a key with no `url` (exit 14). No `http_get`, no `tools.json` line |
| `scenarios/run/rn1-flow` | 13 steps with real `sh` children: list, 2 variables, args with a space, `@` and `in`, exit 3, signal 143, exit 18, shell word exit 19 (no file made), not found, `tln build`, a tool built by the fake compiler (`api: 0`), reuse (`builds: 1`), `PATH` clean, `roc` step through the proxy, `install --frozen` and `list` run no script |
| `scenarios/fx/px2-real-fx-exec-in` | `exec_in!` of the real Fx: directory, args, variable, exit code, signal 143, the directory of the process stays, no directory, no program |

L3 does not depend on file age (given files keep the checkout mtime).

## 5. Output (proposed, R-OUT2, TW24)

The design gives no text for these. They are proposals for the review (the expected files fix them):

| Output | Proposal |
| --- | --- |
| The list (stdout) | `scripts of <file>`, then `<name>:` and each step 2 spaces in. An `in` step is `in <dir>: <run>` |
| The list (`--json`) | `data`: `{"file": <file>, "scripts": [{"name", "steps": [<text>]}]}` (the shape is in the design, the step text is a proposal) |
| Note for a key that is also on `PATH` (stderr, `tln run` with no name) | `note: the tool key '<key>' is also a program on PATH: inside tln run the key wins (R-RUN3)` |
| A step that cannot start | `script <owner>: the step '<text>' cannot start '<program>': <why>` (kind `environment`, exit 18) |
| Bad form of `[scripts]` | `<file>:<line>: scripts.<key>...` (5 texts, in `ScriptsToml.read_table`) |
| Shell word, no command, cycle, missing name, directory outside | 6 texts in `RunPlan.plan` (`... a step is one command; use 2 steps, or a .roc script`) |
| No script found | `no script '<name>' in the talon.toml files that the walk checked: <files>.` or `no talon.toml found. Checked: <dirs>.` (exit 2) |
| 2 words, name with `--json` | `tln run takes one script name, got <n> words. Pass arguments for the script after --.` and `tln run <name> does not take --json: the steps write to stdout. Only tln run with no name does.` |
| A failing step | no extra line: the exit code is the code of the child |
| Words after `--` and no name | `tln run -- <words> needs a script name: the words after -- are the arguments of a script. Use tln run <name> -- <words>.` (exit 2) |
| A key with no `url` | `the [tools] of <path> are not locked: tools.<key> has no url. Run tln install to lock them.` (exit 14) |
| Consent stop | `the compiler <id> is not installed. Pass --yes or set TALON_AUTO_INSTALL=yes.` (exit 13) |
| A quote that is not closed | `<file>: script <owner>: the step '<text>' has a quote that is not closed` (exit 19) |

## 6. Decisions that the design does not fix (the test agent chose)

| Decision | Chosen | Rejected |
| --- | --- | --- |
| How `roc` and `tln` words run | In process with a derived `Fx` (`args!`, `cwd!`, `env_all!`, `program_name!`, `exec!` replaced). This needs the new `Fx` call `exec_in!` | Start the `tln` binary again: the argv0 `roc` is impossible with the basic-cli `Cmd`. The `sh exec -a` trick: it needs a shell |
| When the words are checked | All words, `@` names, cycles and `in` directories are checked before the first step (also for R-RUN2) | Check each step when it starts: an early step could run before a later step is found bad |
| `.roc` word | `roc <file> -- <rest>`, the `--` also with no more words | No `--` when there is no more word |
| Order of the first word | `roc` and `tln`, then a `[tools]` key, then `.roc`, then `PATH` | `.roc` before a key |
| Which `[tools]` table | One for the run: the root's table for root and member files, the file's own table for a standalone file (OP4). `in` directories use the same table | The table of the `in` directory |
| What is recorded (R-PD9) | The holder `talon.toml` files only (root: all members, member: its node, standalone: `main.roc` or the `talon.toml`). Not the `in` directories. It is made before the steps run, also when a step fails | Record after the last step. Record the `in` files |
| The list picks the file | The nearest file on the walk with at least one script | The workspace root always |
| Empty quoted word | `""` is an empty word | A refusal |
| Compiler stop text | See the review (Q6): `--yes`, not `--allow-downloads` | |
| `Intent` and `[scripts]` | Known in all roles. The message for member tables is not changed. `[run]` is left to slice 058 | |

## 7. Out of scope

| Rule | Reason |
| --- | --- |
| R-RUN13, the `--each` part of R-RUN10, R-EA1 to R-EA8, `--keep-going` | slice 058 |
| R-PT11 (`tln x <key>`) | slice 059 |
| `[run] after` (`after` does not apply to `in` steps: Q-S13 (a), decided) | slice 058 |
| R-PT15 other than the offline missing bundle (exit 15) | slice 056 |

## 8. Questions (TW17) and design gaps

All questions were answered at the review (section Review). The open points are design gaps that the manager records:

| # | Gap |
| --- | --- |
| Q4 | Does `tln run` of a tool write `last_run` of the `x` entry (R-X2)? The code does not |
| Q5 | What R-PD9 records when no script is found. The code records nothing (no file is known) |
| Q7 | A `[tools]` key that has the form of a `.roc` file name (`x.roc`): the code makes it a tool |

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| `where`, `has`, `in`, `app` are reserved words | `in` is a key of a `Dict` (string `"in"`), field names changed |
| `{ x }` alone is a block | `{ x: x }` |
| `==` on `Try` is not allowed in some places | the L0 rows render to `Str` or `List(Str)` |
| `roc build` exits 2 on a warning | all new code has no unused name. The mutation script treats a warning as an invalid mutation |
| `roc test` segfaults on an `Err` record with a `Bool` field | the L0 helper turns failures into `Str` |
| A module cannot import a module that imports it | `RunFlow.run!` takes `Run.tln!` as an argument |
| Test modules cannot import the `toml` package alias | the tests use `ScriptsToml.read` and `Intent.read` |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Order | Do it in 3 parts (section 12): 057a, then 057b, then 057c. Filter the runs: `tests/commands/run.sh run/rn1`, `tests/run.sh run/rn1 fx/px2` |
| `Intent` | add `"scripts"` to `known_tables` and `member_tables` (2 words). Do not change the message text for member tables |
| `exec_in!` | as `exec!` with `Cmd.cwd(Path.utf8(cwd))`. The exit code of a signal is 128 + n |
| Derived `Fx` | the steps `roc` and `tln` use a record `{ ..fx, args!, cwd!, env_all!, program_name!, exec! }`. The proxy and `Run.tln!` make no other call for these fields |
| Walk | `Project.scan!` is steps 2 to 4 of `Project.find!` with no project file. A bad `talon.toml` before the root is exit 19 as in `find!` |
| `L3` | `tests/scenarios/run/rn1-flow` needs the real `sh`. The fake compiler prints `ran: ... args: ...` and exits 3 |
| Tests | do not edit the tests (TW18). A wrong test goes back to the test agent |

## 11. Red run, revert check

Red run with the stubs (`research/slice-057-revert/red-run.log`): `scripts/test.sh check fmt l0 l2 l3 selftest`.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest | pass | the stubs compile with no warning |
| l0 | 11 failed, 44 passed | the 11 `expect`s of `RunscriptTest` (the stub crash. Row 9 also needs `Intent`) |
| l2 | 3 failed, 140 passed | `run/rn1-scripts`, `rn2-words`, `rn3-tools`: `ROC CRASHED todo: slice 057` |
| l3 | 2 failed, 73 passed, 1 skipped | `run/rn1-flow` and `fx/px2-real-fx-exec-in` (the stub crash) |

The old cases pass. The old `expect/` files are the same (section 2).

Green run with the reference (`green-run.log`): all steps pass.

Revert check (`mutations.txt`, 10 mutations at the first pass, 5 more for the review changes of the most tricky behaviors, filtered runs, the reference is put back after each one): every mutation is killed by at least one layer.

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| args go to every step | killed | killed | survived |
| the walk does not stop at a root or standalone file | killed | killed | survived |
| no NC4 probe | killed | killed | survived |
| an `in` directory outside the repository is allowed | killed | killed | survived |
| a `[tools]` key does not win over `PATH` | killed | killed | killed |
| a failing step gives exit 1 | survived | killed | killed |
| R-PD9 record is not made | survived | killed | survived |
| no cycle check | killed | killed | survived |
| `.roc` word with no `--` | killed | killed | survived |
| `>` is no shell word | killed | survived | killed |
| Q1: words after `--` with no name are accepted | killed | killed | survived |
| Q2: a key with no `url` is kind `Internal` | killed | killed | survived |
| Q3: a quote splits a word (`a"b c"d`) | killed | survived | survived |
| Q3: an unclosed quote is accepted | killed | killed | survived |
| Q6: the consent stop keeps `--allow-downloads` | survived | killed | survived |

## 12. Split (TW19, proposal)

The reference has 853 lines. The code agent can do the slice in 3 parts. The tests are one set. Each part makes a group of rows green, the other rows stay red until their part. `RunFlow` needs the walk, so the first part has no command code.

| Part | Modules | Reference lines | Rows that turn green |
| --- | --- | --- | --- |
| 057a decisions | `ScriptsToml`, `RunCmd`, `RunPlan`, `RealFx.exec_in!` | about 385 | L0 1 to 7. L3 `px2` |
| 057b command and walk | `RunFind`, `Project.scan!`, `RunFlow` (the Path, `roc` and `tln` steps, the list, the record of R-PD9), `RunTools.table`, `Intent` | about 335 | L0 8, 9, 10. L2 `rn1`, `rn2`. L3 `rn1-flow` steps 1 to 9, 12, 13 |
| 057c project tools | `RunTools` (`no_url`, `stop`, `load!`, `bin!`), the tool steps of `RunFlow`, the note of the list | about 190 | L0 11. L2 `rn3`. L3 `rn1-flow` steps 10, 11 |

If the manager wants one slice, the total is 853 lines over 6 modules, with no module over 240 lines.

## Review (manager, 2026-10-25)

The slice is accepted with the split of section 12: one test set, three code passes. The decisions of section 6 (the new `Fx` call `exec_in!` included) and the TW24 texts of section 5 are accepted. The answers:

| Q | Answer | Change in the reference and the tests |
| --- | --- | --- |
| Q1 | `tln run -- <words>` with no name is exit 2 (the words need a script name). The list reads the nearest file with a script (as written) | `RunCmd.read` gives the failure. L0 7 row, L2 `rn1` run 34 |
| Q2 | A `[tools]` key with no `url` in a step is exit 14 (kind `Frozen`) and the text names `tln install` (as R-PT7) | new `RunTools.no_url`. L0 11, L2 `rn3` run 11 |
| Q3 | An unclosed quote is exit 19 with the script named, found before the first step. `a"b c"d` is the one word `ab cd` | the reference did this already. New L0 rows in 3 and 4, L2 `rn1` run 35 |
| Q6 | The consent stop in `tln run` names `--yes` and `TALON_AUTO_INSTALL=yes`, not `--allow-downloads` | new `RunTools.stop`. L0 11, L2 `rn3` run 5 (expected text changed) |
| Q4, Q5, Q7 | accepted as the reference does. The manager records them as design gaps (section 8) | none |

The parts, with the stub modules and the rows that each part turns green. A row that is not in a part's list stays red until its own part.

| Part | Stub modules and functions | L0 `expect`s | L2 cases and runs | L3 steps |
| --- | --- | --- | --- | --- |
| 057a decisions | `ScriptsToml`, `RunCmd`, `RunPlan`, `RealFx.exec_in!` | 1 to 7 | none | `fx/px2-real-fx-exec-in` (all 7 rows) |
| 057b command and walk | `RunFind`, `Project.scan!`, `RunFlow`, `RunTools.table`, `Intent` (add `"scripts"`) | 8, 9, 10 | `rn1-scripts` runs 1 to 35. `rn2-words` runs 1 to 5 | `rn1-flow` steps 1 to 9, 12, 13 |
| 057c project tools | `RunTools` (`no_url`, `stop`, `load!`, `bin!`), the tool steps of `RunFlow` | 11 | `rn3-tools` runs 1 to 11 | `rn1-flow` steps 10, 11 |

Notes: the L2 cases cannot run without `RunFlow` (057b), so no L2 case is green after 057a. `RunFlow.run!` calls `RunTools.table` for every run, so `table` is in 057b. In 057b the tool step may call the stubs `RunTools.load!` and `bin!`: the cases of `rn1` and `rn2` name no tool. `rn3` and `rn1-flow` steps 10, 11 are green after 057c. The reference was deleted at this review (the hand mutations of the review are in `mutations.txt`). `research/slice-057-revert/ref-off.sh` puts the stubs back.

## Verify results (057a)

Code agent, 2026-10-25. Files: `ScriptsToml` 181 lines, `RunCmd` 33, `RunPlan` 203, `RealFx.exec_in!` (12 lines). A copy of the files is in `research/slice-057-revert/code-final-a/` (`code-final-a.sha256`).

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | check, fmt, selftest, l1 pass. l0: `RunscriptTest` 1 to 7 pass, 8 to 11 fail (057b and 057c). l2: `rn1`, `rn2`, `rn3` fail (`RunFlow` stub, 057b and 057c). l3: `fx/px2-real-fx-exec-in` passes, `run/rn1-flow` fails (057b and 057c). All old tests pass. |
| Revert check | 7 mutations, 7 caught (`research/slice-057-revert/agent-results-a.md`): quote splits a word, unclosed quote accepted, args to every step, cycle check off, `.roc` with no `--`, key over `roc` order, signal exit code of `exec_in!` |

Decisions of the code agent that the slice does not fix:

| Id | Decision | Rejected |
| --- | --- | --- |
| C1 | A `Line` step is an `@<name>` call when its trimmed text starts with `@`. The name is the rest of the trimmed text (`@a b` names the script `a b`, which is then "no such script") | A call with extra words as args |
| C2 | The name of a script of another directory in a cycle is `<name> (<dir>)` when the dir is not the dir of the start script | Always with the dir |
| C3 | `Flat.text` is `ScriptsToml.step_text` of the step (an `in` step shows as `in <dir>: <run>`) | The `run` text only |
| C4 | `plan` with a start script that its file does not have: kind `Input`, `<dir>/talon.toml: has no script '<name>'` (`RunFind` makes this case impossible) | A panic |

## Verify results (057b)

Code agent, 2026-10-25. Files: `RunFind` 145 lines, `RunFlow` 254, `Project.scan!` (9 lines, `Project` 377), `RunTools.table` (11 lines), `Intent` (2 words). A copy is in `research/slice-057-revert/code-final-b/` (`code-final-b.sha256`).

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | check, fmt, selftest, l1 pass. l0: `RunscriptTest` 1 to 10 pass, 11 fails (057c). l2: `rn1-scripts` (35 runs) and `rn2-words` (5 runs) pass, `rn3-tools` fails (057c). l3: `px2` passes, `run/rn1-flow` fails in steps 10, 11 and the result of step 13 (the tool is not built yet): 057c. All old tests pass. |
| Revert check | 9 mutations, 9 caught (`research/slice-057-revert/agent-results-b.md`): walk stop, NC4 probe, R-PD9 record, standalone record file, list file, `roc` step args, stop at first failure, member tools table, `-- words` with no name |

Decisions of the code agent that the slice does not fix:

| Id | Decision | Rejected |
| --- | --- | --- |
| C5 | `RunFind` asks a probe only for the nearest `talon.toml` path between a member file below the file and that file, and only when no nearer path is known to exist (`Need` again after each answer). A path is never taken from the walk, only from `probes` (L0 8 gives a walk with a file that the probe says is not there) | Ask all paths between in one `Need` |
| C6 | A walk file with a `[scripts]` form that is not valid fails (exit 19) when `find` examines it, before its kind is known (no probe) | Decide the kind first |
| C7 | `RunFlow` leaves a walk file with a bad form out of the known files of `plan`, so a `Need` for it reads the file again and gives the exit 19 message | Treat it as `NoFile` |
| C8 | The warnings of `RunTools.table` go on stderr as `warning: <path>:<line>: <message>`, as `ToolsFlow` does, before the plan and before the list | No print |
| C9 | The list calls `programs!` once with the tool keys (no call with no key) and prints one `note: ` line for each key that is on `PATH`, in the order of the keys (this is part of 057c in the table of the review; it is in `RunFlow` now) | |

## Verify results (057c)

Code agent, 2026-10-25. Files: `RunTools` 130 lines (`no_url`, `stop`, `load!`, `bin!` and the helper `build!`). `RunFlow` is complete since 057b (its tool branch calls `load!` and `bin!`). A copy is in `research/slice-057-revert/code-final-c/` (`code-final-c.sha256`). The live files of the whole slice: `research/slice-057-revert/code-final/` and `code-final.sha256` (`sha256sum -c` from the repo root checks the live files).

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | exit 0: check, fmt, l0, l1, l2, l3, selftest all pass (l0 `RunscriptTest` 1 to 11, l2 `rn1-scripts`, `rn2-words`, `rn3-tools`, l3 `run/rn1-flow` all 13 steps and `fx/px2`). No `crash "todo` in `cli/` or `packages/`. |
| Revert check | 8 mutations, 7 caught, 1 not caught by L3 (`research/slice-057-revert/agent-results-c.md`): `.roc` word before a key, no `url` kind, consent stop text, no reuse of the `x` entry (L2 catches it, L3 does not: the output is the same), new entry not added, `PATH` note when absent, tool args lost |

Decisions of the code agent that the slice does not fix:

| Id | Decision | Rejected |
| --- | --- | --- |
| C10 | `RunTools.bin!` has no `last_run` write for a reused `x` entry (Q4 of the review) and builds with `ToolsStep.ensure!` with `allow: false`, `dry_run: false`, `snapshot: Err(None)`, `min_age` of `config.toml` (2 days default, as `ToolFlow`) | A `last_run` write |
| C11 | `RunTools.stop` changes only a failure of kind `Consent` that has the exact text of `ToolsPlan.compiler_stop` (the sentence with `--allow-downloads`) | A text search in any failure |
| C12 | `RunTools.bin!` checks `Ident.of_url` before the cache look-up and gives kind `Input` (`tools.<key>.url: '<url>' is not a release URL with a version and a hash`); `ToolsToml.read_table` already refuses such a `url`, so this is a guard only | No check |

## Review 2 (manager, 2026-10-25)

| Id | Decision | Test row |
| --- | --- | --- |
| C10 | In a run step that builds a project tool, min-release-age comes from `Setting.pick` of the `talon.toml` that holds `[tools]`, then `config.toml`, then 2 days, as slice 056 does (056 C5), not from `config.toml` only | none can be red, see below |

Test agent finding on C10: no row can fail now, and none could fail after the fix. The `url` of the entry is the lock, so a run step makes no release pick. `ensure!` has no read of `min_age`: the only readers of `facts.min_age` and `ctx.min_age` are `ToolInstall.pick` (`ToolFlow.flow!`, `ToolsStep.pick`, `ToolUpdateFlow`, `XFlow`) and `Toolchain` for a rank 4 range, and the compiler of a tool build is the exact pin of the bundle (`ToolCompilerFlow.choose!`: `Use` or `Missing`, never a range, R-NS4: a name is not limited by min-release-age). The value that `RunTools.build!` gives to `ctx.min_age` therefore changes no output. The code agent may still fix the source of the value (for consistency with 056), but there is no test for it. If the manager wants a row, a design change is needed first (a rule that makes a run step read the age). No row was added for C10.

## Gap tests (test agent, 2026-10-25)

Rows for accepted behavior of the code (no change of code). Each row got one hand mutation, then the file was restored and `sha256sum -c research/slice-057-revert/code-final.sha256` gave OK for all files.

| Id | Behavior | Row | Mutation, result |
| --- | --- | --- | --- |
| C8 | The warnings of the `[tools]` table go on stderr as `warning: <path>:<line>: <message>`, before the step, also when the step uses no tool | L2 `rn3-tools` run 12 (`p7`: an unknown key `note`) | `warn:` in place of `warning:`: killed by L2 |
| C4 | A start script that its file does not have: exit 19, `<dir>/talon.toml: has no script '<name>'` | L0 4 (`plan` row `nothere`) | `no scripts` in the text: killed by L0 |
| C2 | A cycle over 2 directories: `scripts call themselves: cx -> cy (/r/p/sub) -> cx` | L0 4 (`plan` rows with `cx` and `cy`, `in` steps) | the label has no directory: killed by L0 |

Totals now: L0 11 `expect`s (L0 4 has 2 more rows), `rn3-tools` 12 runs. The old expected files of `rn3` only got the lines of run 12 (checked with `diff -r`). Affected tests run: `scripts/test.sh l0`, `tests/commands/run.sh run/`: both pass with the code of `code-final`.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-057-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.5, fmt 0.2, l0 8.7, l2 8.8, l3 10.1, selftest 3.3, l1 43.2 s |
| Code passes | 057a, 057b, 057c: 23 mutations caught; one L3-only miss is caught by L2 |
| Gap tests | C8 (rn3 run 12), C4, C2 (L0 rows); 3 hand mutations caught; no code bug |
| Review 2, C10 | Withdrawn by the manager: a run step makes no release pick (the `url` is the lock), so min-release-age has no effect there and no test can see it. `RunTools.build!` passes a value that nothing reads; harmless. |
| Note | The code agent read `mut.py` once (mutation texts only). Accepted. l0 is 8.7 s: watch it. |
