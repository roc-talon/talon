# 056 Project tools, `[tools]`

Phase: P1. Status: done

Slice 056 adds the project tools of `talon.toml` (CLI 6.4: R-PT1 to R-PT16, less R-PT11). A project tool is an app (a GitHub release bundle) that a project names in `[tools]` with a `ref` (the intent) and a `url` (the lock, G1, G2). The slice makes `tln add --tool` and `tln remove --tool`, the `url` lock of `tln install`, `tln install --frozen`, `tln update` and `tln upgrade` (with and without `--tool`), and the GC of the builds and bundles that a known project uses. The user answers OP1 to OP10 and NC1 to NC5 are in `research/talon-scripts/design-draft/DIFF.md`.

Size (TW19): the plan row has no size. The private reference (deleted after the review, section 11) had about 1250 lines in 6 new modules (`ToolsToml` 184, `ToolsPlan` 313, `ToolsCmd` 145, `ToolsStep` 375, `ToolsFlow` 204, `ToolsHeld` 35), and about 150 more lines in 13 existing modules. About 14 percent of the new lines are doc comments. Each module is under 490 lines. A split is proposed in section 12.

Live reads: none. No real network and no real long build in L0 to L3. L3 uses a fake compiler (a shell script), the real `curl`, the real `roc unbundle` and the real `exec`.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-PT1 | The form of `[tools]`: the key, `ref`, `url`, the selector of `ref` | L0 `ToolsplanTest` 1, 2, 14. L2 `pt1-add` runs 2, 13 |
| R-PT2 | `[tools]` only in the root file of a workspace. A member file gives exit 19 | L0 `ToolsplanTest` 3, 6. L2 `pt3-move` runs 11, 12 |
| R-PT3 | `add --tool` (the key, `--as`, the same app acts as update, another app is exit 2, the build comes before the write, `talon.toml` is made in the current directory when no project file exists) and `remove --tool` | L0 `ToolsplanTest` 4, 5, 13, 14, 16. L2 `pt1-add` runs 1 to 4, 7 to 10, 12, 14, 16. L3 steps 1, 2, 5 |
| R-PT4 | The selection of a release (min age, snapshot, no draft, no prerelease) | L0 `ToolsplanTest` 9. L2 `pt1-add` runs 6, 11. `pt2-install` run 1. `pt3-move` run 1 |
| R-PT5 | `update` and `upgrade` move a `url`: no names, with names, `--tool`, the alias error | L0 `ToolsplanTest` 7, 9. L2 `pt3-move` runs 1 to 10. `pt2-install` run 1 |
| R-PT6 | The build path of `tln x` from the bundle at `url`, the bundle hash is checked. `--dry-run` builds nothing and prints `would build` | L2 `pt1-add` runs 1, 10, 15. `pt2-install` runs 1, 2, 6, 9, 13. L3 steps 1, 3, 6 |
| R-PT7 | `install --frozen`: exit 14 for no `url`, a version out of range, another app. No index call | L0 `ToolsplanTest` 8. L2 `pt2-install` runs 3 to 6. L3 step 3 |
| R-PT9 | The build of a `url` is reused when an `x` entry has the same bundle hash and target (the `tln run` part is slice 057) | L0 `ToolsplanTest` 10. L2 `pt1-add` run 7. `pt2-install` runs 1, 2, 7. L3 step 6 |
| R-PT12 | Global and project tools are independent: no `tools.json`, no lock, no bin dir entry | L2 `pt1-add` runs 1, 7, 8. `pt3-move` run 1. L3 step 1 |
| R-PT13 | The take-over of an `x` entry that a project tool uses copies the binary and keeps the entry (NC3) | L0 `ToolsplanTest` 11. L2 `tk2-takeover-project` runs 1 to 5 |
| R-PT14 | GC keeps the `x` entries and the package dirs that the `[tools]` of known projects name | L0 `ToolsplanTest` 11, 15. L2 `gc5-project-tools` runs 1 to 3. L3 steps 4, 5 |
| R-PT15 | `--offline`: the binary, or the cache, else exit 15 | L2 `pt2-install` runs 8, 11 |
| R-PT16 | A wasm platform gives exit 2 before the build | L2 `pt1-add` run 5. `pt2-install` run 10 |
| G1, G2 | The app header is the lock, and the one lock outside it is the `url` of a project tool | L2 `pt2-install` run 1. L3 step 1 |
| R-WS5 | `[tools]` is a table of the root file of a workspace | L0 `ToolsplanTest` 3. L2 `pt3-move` runs 11, 12 |
| R-SO14 | No compiler is selected for a build when the binary is there | L2 `pt2-install` run 7 |
| R-SO22 | `--frozen` needs a compiler for a tool build only, as a required download | L2 `pt2-install` runs 6, 7, 12 |
| R-LF1 | Frozen mode: no change of a file, no index call | L2 `pt2-install` runs 3, 6. L3 step 3 |
| R-DL7 | A compiler download for a project tool is a required download (consent). The stop names `--allow-downloads` and `TALON_AUTO_INSTALL=yes`. `--allow-downloads` answers it | L0 `ToolsplanTest` 16. L2 `pt2-install` runs 12, 14 |
| R-PD9 | A command that uses a project records it, a `talon.toml` that `tln run` or `add --tool` recorded counts as a project file | L2 `pt1-add` runs 1, 16. `gc5-project-tools`. `tk2-takeover-project` runs 2, 3. L3 step 4 |

Other rule ids that the tests name (the slice does not own them): R-TF4, R-C7, R-DT4, R-UP5, R-FL3, R-FL7, R-FL12, R-FL13, R-CC7, R-LF4, R-J3, R-I5, R-X2, R-B4, R-B9, R-T2, R-GC4, R-GC7, R-PD12, R-PD13, R-AU6, R-DL2.

## 2. Files

New files (also in `research/slice-056-revert/before/NEW.txt`). The code agent writes the bodies of the 6 stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/ToolsToml.roc` (stub) | 70, 184 | Part A: the entry type, `is_key`, `read_table`, and the edits `put`, `drop`, `spans` |
| `cli/lib/ToolsPlan.roc` (stub) | 109, 313 | Part A: the decisions: `home`, `split`, `frozen_check`, `visible`, `selector_for`, `add_ref`, `upgrade_ref`, `stuck_note`, `cached`, `held_paths`, `held_hashes`, and the output texts |
| `cli/lib/ToolsCmd.roc` (stub) | 50, 145 | Part A: the line of a command with `--tool` (`read`) and its failures |
| `cli/lib/ToolsStep.roc` (stub) | 103, 375 | Part C: the steps over `Fx` (pick, chosen, ensure, run, write, print) and `after!`, the hook of `install`, `update` and `upgrade` |
| `cli/lib/ToolsFlow.roc` (stub) | 24, 204 | Part C: `run!` for the commands with `--tool` |
| `cli/lib/ToolsHeld.roc` (stub) | 20, 35 | Part C: the bundle hashes of the known projects (`of!`, `all!`) |
| `tests/unit/ToolsplanTest.roc` | 294 | 16 `expect`s (L0) |
| `tests/commands/cases/ptool/pt1-add/` | 36 files | L2: 16 runs |
| `tests/commands/cases/ptool/pt2-install/` | 63 files | L2: 14 runs |
| `tests/commands/cases/ptool/pt3-move/` | 46 files | L2: 13 runs |
| `tests/commands/cases/gc/gc5-project-tools/` | 39 files | L2: 3 runs |
| `tests/commands/cases/tool/tk2-takeover-project/` | 44 files | L2: 5 runs |
| `tests/scenarios/ptools/pt1-flow/` | `cmd` 46, 17 files | L3: 6 steps |
| `research/slice-056-revert/` | | `stubs/lib/` (all stubs), `restore.sh`, `chk.sh`, `l0.sh`, `mkstubs.py`, `gen-ptools.py` (writes the given, fx, entry and rules of the 5 L2 cases, no `expect/`), `mutants.py`, `mutants.log`, `red-all.log`, `green-all.log`, `baseline-run.log`, `before/`, `expect-before/`. The private reference and `reference-on.sh` were deleted after the review (section 11). `mkstubs.py` and `mutants.py` need the reference and cannot run again |

Changed files (a copy of each is in `research/slice-056-revert/before/`):

| File | Change in the stub state |
| --- | --- |
| `cli/lib/main.roc` | exposes `ToolsCmd`, `ToolsFlow`, `ToolsHeld`, `ToolsPlan`, `ToolsStep`, `ToolsToml` |
| `cli/lib/Run.roc` | a line with `--tool` calls `ToolsFlow.run!` (first branch). `check_refs` accepts such a line |
| `cli/lib/Args.roc` | `--tool` is a flag of `install`, `remove`, `update`, `upgrade` (`one_of`) |
| `cli/lib/Intent.roc` | the field `tools : List(ToolsToml.Entry)`, always `[]` in the stub. The code agent writes the read (section 10) |
| `tests/unit/l0-8.roc` | `import ToolsplanTest` (the driver with the lowest time) |
| `InstallFlow`, `Resolve`, `Install`, `Update`, `XTake`, `Gc`, `CacheGc`, `XCacheIo` | not changed in the stub state. The code agent changes them (section 10). `Install` gets `begin_loose!` (section 3) |

Old expected files that changed (TW21): 3 L2 cases. In each one only `expect/calls.log` has more lines (checked with `diff -r` against `research/slice-056-revert/expect-before/`):

| Case | Change |
| --- | --- |
| `gc/gc1-select` | 4 runs get one `read_files /talon.toml ... $PROJECT/pa/talon.toml ... /tmp/talon-l2/talon.toml /tmp/talon.toml` (the `talon.toml` files of the known projects, R-PT14) |
| `gc/gc3-caches` | 4 runs get one `read_files` of the `talon.toml` candidates |
| `tool/tk1-takeover` | 5 take-overs get one `read_files $HOME/.cache/roc/talon/projects.json` (the take-over asks which bundles a project holds, NC3) |

The ancestor paths in these lines (`/tmp/talon-l2/talon.toml`) depend on `TMPDIR`. The old expected files already hold `talon-l2` paths, so this has a precedent.

Module plan (TW19, the manager may change it): `Intent.roc` is 389 lines before and 395 in the reference, `InstallFlow.roc` 261 and 318, `Gc.roc` 333 and 338, `CacheGc.roc` 233 and 239, `XTake.roc` 171 and 166. All stay under 490.

## 3. Public signatures

Only the tests fix the behavior. The signatures of `ToolsToml`, `ToolsPlan`, `ToolsCmd` are called by the L0 tests, so they are fixed. The signatures of `ToolsStep`, `ToolsFlow` and `ToolsHeld` are a proposed structure: the L2 `calls.log` files fix the order of the `Fx` calls, not the names.

### ToolsToml (fixed, L0)

| Function | Signature |
| --- | --- |
| `Entry` | `{ key : Str, ref : Str, url : Try(Str, [Unset]), line : U64 }` |
| `is_key` | `Str -> Bool` |
| `read_table` | `Toml -> { value : List(Entry), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }` |
| `put` | `{ path : Str, text : Str, key : Str, ref : Str, url : Str } -> Try(Str, Fail)` |
| `drop` | `{ path : Str, text : Str, keys : List(Str) } -> Try(Str, Fail)` |
| `spans` | `{ text : Str, keys : List(Str) } -> List(Str)` |

### ToolsPlan (fixed, L0)

| Function | Signature |
| --- | --- |
| `Phase` | `[Install, Frozen, Update, Upgrade]` |
| `home` | `{ workspace : Try({ root : Str, members : List(Str) }, [Standalone]), file : Try(Str, [NoCurrent]) } -> Try(Str, Fail)` |
| `split` | `{ command : Str, names : List(Str), keys : List(Str), aliases : List(Str) } -> Try({ header : List(Str), tools : List(Str) }, Fail)` |
| `frozen_check` | `{ path : Str, tools : List(ToolsToml.Entry) } -> Try({}, Fail)` |
| `visible` | `{ list : List(Index.Candidate), snapshot : Try(U64, [None]) } -> List(Index.Candidate)` |
| `selector_for` | `{ phase : Phase, ref : Str } -> Try(Selector, [None])` |
| `add_ref` | `{ name : Str, selector : Try(Selector, [None]), version : Str } -> Str` |
| `upgrade_ref` | `{ ref : Str, version : Str } -> Try(Str, [NoForm])` |
| `stuck_note` | `{ key : Str, ref : Str, version : Str } -> Str` |
| `cached` | `{ entries : List(XCache.Found), bundle : Str, target : Str } -> Try(XCache.Found, [None])` |
| `held_paths` | `{ files : List(Str) } -> List(Str)` |
| `held_hashes` | `{ files : List(Str), reads : List({ path : Str, text : Str }) } -> List(Str)` |
| `line` | `[Added(..), Locked(..), Moved(..), Built(..), WouldBuild({ key, name, version }), Removed(..)] -> Str` |
| `file_line` | `{ path : Str, key : Str, entry : Try({ ref : Str, url : Str }, [Removed]) } -> Str` |
| `data` | `List(Row) -> JsonDoc` (the rows of section 5, with `would_build : Bool`) |
| `build_env` | `{ env : List((Str, Str)), allow : Bool } -> List((Str, Str))`: with `allow` the pair `TALON_AUTO_INSTALL=yes` comes first |
| `compiler_stop` | `Fail -> Fail`: the consent stop of `ToolInstall.consent_stop` gets the text of section 5. Any other failure stays |
| `no_project` | `Fail -> Bool`: the failure of the search for a project file that found none (kind `Usage`, text starts with `no project file found. Checked:`) |

### ToolsCmd (fixed, L0)

| Function | Signature |
| --- | --- |
| `Op` | `[Add, Remove, Update, Upgrade]` |
| `Cmd` | `{ op : Op, ref : Try(Ref, [None]), keys : List(Str), as_key : Try(Str, [Unset]), snapshot : Try(Str, [Unset]), dry_run : Bool, allow_downloads : Try(Answer, [NoFlag]) }` |
| `op_of` | `Args -> Try(Op, [NoTool])` |
| `read` | `Args -> Try(Cmd, Fail)` |
| `key_of` | `{ as_key : Try(Str, [Unset]), name : Str } -> Try(Str, Fail)` |
| `key_taken` | `{ path : Str, key : Str, other : Str } -> Fail` |
| `no_key` | `{ path : Str, key : Str, keys : List(Str) } -> Fail` |

### Proposed structure (not fixed by an L0 test)

| Module | Function | Signature |
| --- | --- | --- |
| `Intent` | `read` | gives `intent.tools` (the entries of `[tools]`). A member file with `[tools]` is exit 19 (role `Member`) |
| `Gc` | `projects` | a project path that ends in `/talon.toml` is live while the file exists (L0 `ToolsplanTest` 15) |
| `ToolsStep` | `after!` | `Fx, Args, { request, loaded, phase, keys } => Try({ changed : Bool }, Fail)`: the tools step after the header flow. `changed` is true when a line was printed |
| `ToolsStep` | `frozen_check` | `ResolveBase.Request, ResolveBase.Loaded -> Try({}, Fail)`: step 1 of `--frozen`, before the closure fetch |
| `ToolsStep` | `Ctx`, `Row` | `Ctx` has `allow : Bool` (`--allow-downloads`). `Row` has `would_build : Bool` |
| `ToolsStep` | `run!`, `write!`, `print!`, `machine!`, `pick!`, `chosen!`, `ensure!` | the steps of `ToolsFlow` (the doc comments of the stubs have the table of the calls). `ensure!` gives `{ built, would, added }` |
| `Install` | `begin_loose!` | `Fx, Args => Try({ env, roots, net, now, cwd, project : Try(Project, Fail) }, Fail)`: the calls of `begin!`, but a failure of the search for the project file is the field `project`. `begin!` calls it and takes `project?` |
| `ToolsFlow` | `run!` | `Fx, Args => I32`: the commands with `--tool` |
| `ToolsHeld` | `of!`, `all!` | `Fx, List(Str) => List(Str)` and `Fx, Roots => Try(List(Str), Fail)` |
| `InstallFlow` | `install_with!` | `Fx, Request, Try(Args, [None]) => ...`. `install!` calls it with `Err(None)`. `Resolve.install_with!`, `Install.flow!` and `Update.resolve!` pass `Ok(args)` |
| `XCacheIo` | `has_file` | `listed, repo`: a binary is a file (not a directory) named `<repo>` or `<repo>.exe` |

## 4. Tests

### L0

`tests/unit/ToolsplanTest.roc` has 16 `expect`s. Each one has the rule ids in a comment.

| # | Case | Rule ids |
| --- | --- | --- |
| 1 | `Intent.read` of `[tools]`: the order, an entry with no `url`, the quoted key `"v2.x_y"`, the warning of an unknown key | R-PT1, R-PT5, R-TF4 |
| 2 | 8 forms that fail with exit 19 (not a table, a bad key, a value that is no table, no `ref`, a `ref` that is no string, a `url` that is no string, ...) | R-PT1, R-TF4 |
| 3 | The role `Member` gives exit 19 `talon.toml:2: the table [tools] is not allowed in a workspace member file (...)`. The role `Root` is ok | R-PT2, R-WS5 |
| 4 | `ToolsToml.put`: a new key, a replaced entry in place with its comment, a new table after a blank line, an empty text | R-PT3, R-CC7 |
| 5 | `drop` and `spans` (a missing key is kind `Internal`, code 1) | R-PT3, R-CC7 |
| 6 | `ToolsPlan.home`: a standalone file, a workspace root, a member, no current file | R-PT2, R-PT3 |
| 7 | `split`: the names of `update` and `upgrade` into header names and keys (an alias with a key, a name with `@`) | R-PT5 |
| 8 | `frozen_check`: exit 14, the findings in order | R-PT7, R-LF1 |
| 9 | `visible`, `selector_for`, `add_ref`, `upgrade_ref` (`^1` with 2.0.0 gives `^2`), `stuck_note` | R-PT3, R-PT4, R-PT5, R-UP5 |
| 10 | `cached`: the bundle and the target match, the latest `last_run` wins | R-PT9, R-PT6 |
| 11 | `held_paths` and `held_hashes`: the byte order, the walk stops at `[workspace]` (a `/talon.toml` read proves it) | R-PT13, R-PT14, R-PD9 |
| 12 | `line` (with `WouldBuild`), `file_line`, `data` (the JSON, with `would_build`) | R-PT3, R-PT6, R-J3 |
| 13 | `ToolsCmd.read`: 18 rows (the flags, the operands, the failures) | R-PT3, R-FL7, R-FL12 |
| 14 | `key_of`, `key_taken`, `no_key`, `op_of` | R-PT1, R-PT3, R-FL12 |
| 15 | `Gc.projects` with `talon.toml` entries | R-PT14, R-PD9, R-GC9 |
| 16 | `compiler_stop` (the consent stop names `--allow-downloads` and `TALON_AUTO_INSTALL=yes`, another failure stays), `build_env` (`--allow-downloads` wins over `TALON_AUTO_INSTALL=no`), `no_project` | R-DL4, R-DL5, R-DL7, R-PT3, R-PT6 |

### L2 and L3

| Layer | Case | Content | Rule ids |
| --- | --- | --- | --- |
| L2 | `ptool/pt1-add` | 16 runs. The table is in the file `rules` of the case: a first add that makes `talon.toml`, `--as`, the same app acts as update, a key of another app (exit 2), a wasm platform (exit 2), `--snapshot`, `--dry-run --json` with an `x` entry already there, `remove`, a missing key, a failed build (exit 11, nothing is written), a release younger than the min age (exit 2), an existing `talon.toml` (the table is added at its end), a git sha as selector (exit 2), `--no-pin` (exit 2), a `--dry-run` of a release with no `x` entry (`would build`, no build, no write), `add --tool` with no project file (it makes `talon.toml` in the current directory and records it) | R-PT1, R-PT3, R-PT4, R-PT6, R-PT9, R-PT12, R-PT16, R-FL7, R-CC7, R-PD9, R-C7, R-DT4, R-LF4, R-J3 |
| L2 | `ptool/pt2-install` | 14 runs: `install` locks a tool with no `url`, builds one with no binary, keeps one with a binary, one write. A second run changes nothing. `--frozen`: exit 14 for no `url`, a version out of range, another app. A locked tool with no binary is built (no index call, no write). A present binary needs no compiler. `--offline` with no bundle (exit 15). A directory with the name of the binary (follow-up of slice 049). A wasm platform. `--offline` with all binaries. A missing compiler (exit 13, the text names `--allow-downloads` and `TALON_AUTO_INSTALL=yes`). `install --dry-run` (`locked`, `would build`, no build, no write, no `nothing to change`). `--allow-downloads` answers the compiler download (the run goes on to the list of nightlies) | R-PT4 to R-PT7, R-PT9, R-PT12, R-PT15, R-PT16, R-LF1, R-SO14, R-SO22, R-DL4, R-DL5, R-DL7, R-LF4, G1, G2 |
| L2 | `ptool/pt3-move` | 13 runs: `update --tool` (range, exact stays, a second range), nothing newer, `upgrade --tool foo bar` (the `ref` changes, R-UP5), a range with no form (the note), a key that is not there (exit 2), a ref as operand (exit 2), `update fmt` (only a key: the header flow does not run), `update` with no names, `update pf` (an alias that is also a key: exit 2), `upgrade --tool pf`, a member of a workspace (root file), a member file with `[tools]` (exit 19), `update fmt` when `fmt` is current (the line `nothing to change`, once) | R-PT2, R-PT4, R-PT5, R-PT12, R-UP5, R-WS5, R-CC7, R-FL12 |
| L2 | `gc/gc5-project-tools` | 3 runs: `--dry-run`, `--json`, the second run. 3 live projects keep entries and package dirs. The entries `kold`, `kgone`, `kfree` and 2 package dirs go. 2 projects leave `projects.json` | R-PT14, R-GC4, R-GC7, R-PD12, R-PD13, R-J3 |
| L2 | `tool/tk2-takeover-project` | 5 runs: a project uses the bundle (copy, the entry stays), a workspace member (walk up), a `talon.toml` in `projects.json`, a project with another bundle (move), no project (move) | R-B4, R-PT13, R-PT14, R-PD9, R-PD12 |
| L3 | `ptools/pt1-flow` | 6 steps with the real Fx, curl, unbundle and exec: add (the build, `talon.toml`, no `tools.json`, no bin dir), a second entry with `--as`, `install --frozen` on a machine with no `x` cache, 36 days later `install --frozen` and `cache gc` (2 builds stay), `remove` and `cache gc` (the build of the removed entry goes), `install --frozen` builds nothing | R-PT3, R-PT6, R-PT7, R-PT9, R-PT12, R-PT14, R-LF1, R-SO22, R-GC7, R-PD9, G1, G2 |

Run `MISSING=1 scripts/rules.sh R-PT R-WS R-SO R-LF R-DL R-PD`: no rule of section 1 is missing. R-PT8, R-PT10 and R-PT11 are out of scope (section 7).

## 5. Output (proposed, R-OUT2, TW24)

The design gives no text for these commands. All texts below are proposals for the human review. The doc comment of each function in the stubs has the text.

| Output | Text |
| --- | --- |
| Lines on stdout of a change | `added tool <key> <version> (<name>)`, `locked tool <key> <version> (<name>)`, `moved tool <key> <old> to <new> (<name>)`, `built tool <key> <version> (<name>)`, `removed tool <key> (<name>)` |
| File lines | `<path>: tools.<key> = { ref = "...", url = "..." }` and `<path>: tools.<key> removed` |
| No change | `nothing to change`. It is printed once, at the end, and only when neither the header nor the tools change (D16 of the review). `install`, `update` and `upgrade` with `[tools]`: the header flow does not print it, the tools step decides |
| `--dry-run` | the lines of the plan, `would build tool <key> <version> (<name>)` for a release that has no `x` entry, the file line, then `dry run: nothing was written`. No build, no fetch of a bundle, no write (D8 of the review) |
| `--json` of the `--tool` commands | `data.tools`: rows with `key, name, action, ref, url, version, previous, file, built, would_build` |
| `--json` of `install`, `update`, `upgrade` | no tools field (gap, section 8) |
| A range with no form on `upgrade` | the note `stuck_note` on stderr |
| Failures of `ToolsCmd` and `ToolsToml` | the texts in the doc comments of the stubs (kind `Usage`, exit 2, or kind `Input`, exit 19) |
| Missing compiler (exit 13) of a project tool build | `the compiler <id> is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` (Q-A of the review, as R-DL4) |
| Exit 14 of `--frozen` | `ToolsPlan.frozen_check` names the file, the key and the cause |

## 6. Decisions that the design does not fix (the test agent chose, the manager reviewed them: section Review)

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `--tool` takes `--as` (add only), `--snapshot`, `--dry-run`, `--allow-downloads` and the global flags. Any other flag is exit 2 (`--no-pin`, `--no-check`) | Accept and ignore the flags of the header flow |
| D2 | The header flow runs first, then the tools step. A failure of the tools step after a header write leaves the header written | Tools first. One transaction for both |
| D3 | `install` with names runs no tools step | Run the tools step for every `install` |
| D4 | One write at the end for all tools of a command (all or nothing). The build comes before the write | One write for each tool |
| D5 | A name with `@` in `update` and `upgrade` goes to the header (question Q2) | Refuse the selector for a tool name |
| D6 | `update` moves to the first release of the pick when the `url` differs. No downgrade guard | Refuse a move to an older version |
| D7 | The selectors of a `ref`: none, `latest`, a version, a range. The `ref` is `owner/app` | Allow a git sha or a host path |
| D8 | Changed at the review: `--dry-run` builds nothing and writes nothing. It prints the plan: the release that would be locked, and `would build` for a release that has no `x` entry. It fetches no bundle (the release is the newest candidate of the pick), so it makes no platform check. A real run makes the check (R-PT16) | The first choice: a dry run that builds (the `x` cache is no project file) |
| D9 | The reuse key of an `x` entry is the bundle hash and the target, with a release source and a binary. With several entries the latest `last_run` wins, then the first dir | Also compare the nightly and the dependency hashes |
| D10 | The held walk of GC climbs to the first file with `[workspace]` or to the file system root (over-approximation). The take-over counts every `projects.json` entry, GC counts only live projects (within the GC age) | Find the workspace root of a member with a read of each ancestor (question Q4) |
| D11 | `XCacheIo.has_file` is a file (not a directory) named `<repo>` or `<repo>.exe` (follow-up of slice 049) | Any file that is not `manifest.json` |
| D12 | The `--tool` commands record the project (`Known.record!`) and never read `tools.json`. A workspace root with no current member is allowed (the file is the root file) | No record for `--tool` commands |
| D13 | `add --tool` with no selector writes `name@^<version>` | `name@<version>` or `name` |
| D14 | The `not_native` text of `ToolInstall` is reused for a wasm platform | A new text |
| D15 | The output texts of section 5 | |
| D16 | Changed at the review: `nothing to change` is printed once, at the end, and only when neither the header nor the tools change. For `--frozen` the line `the header satisfies talon.toml` stays before the tool build | The first choice: the header flow prints it before the tool lines |
| D17 | A build failure of a tool gives `ToolInstall.build_failed` (exit 11) | A new kind |
| D18 | `ToolsHeld.all!` passes a bad `projects.json` on (exit 19) | Ignore the file in a take-over |
| D19 | R-GC4 (the package dir of a `url`) is kept by the same held hashes as R-GC7 | A second walk for the packages |
| D20 | `--allow-downloads` answers the required compiler download of a project tool build (R-DL5): `ToolsPlan.build_env` puts `TALON_AUTO_INSTALL=yes` first in the environment of the build facts. The flag wins over `TALON_AUTO_INSTALL=no` (flag over environment, as `Consent.required_want`) | A new argument of `ToolFlow.choose_for!` |
| D21 | `add --tool` with no project file (no `--file`, no app file, no workspace): the file is `<current directory>/talon.toml` (Q3 of the review). The same holds for the other 3 commands with `--tool`: `remove`, `update` and `upgrade` then find no key. The file is the project file that `Known.record!` gets (R-PD9, NC1) | A new failure |

## 7. Out of scope

| Rule or item | Reason |
| --- | --- |
| R-PT8, R-PT10, R-PT11, the `tln run` part of R-PT9 | `tln run` is slice 057, `tln x <key>` is slice 059 |
| R-PD16 | Later slice |
| `--each` | Slice 058 |
| `tln outdated` rows for tools (R-CM6), `tln audit` list (R-AU1) | Later |
| Yank state of a tool | Later |
| R-PT15 beyond the offline bundle and the present binary | A missing compiler offline has no test (section 8) |
| R-DL7 (full coverage) | The consent stop of a project tool and the flag are tested (`pt2-install` runs 12, 14). The download paths are shared with `ToolCompilerFlow` and tested by slices 046 and 047 |

## 8. Questions (TW17) and design gaps

| # | Question or gap | What the slice does now |
| --- | --- | --- |
| Q2 | A selector on a tool name in `update` and `upgrade` (`foo@^2`): is it a new `ref` for the tool, or a failure? | Accepted at the review as it is: the name goes to the header (D5). A design gap that the manager records |
| Q3 | `add --tool` where no project file exists. R-PT3 says "creates `talon.toml` when it is missing" | Decided at the review: it makes `talon.toml` in the current directory (D21, NC1 allows a `talon.toml` with no app file). `pt1-add` run 16, L0 16 |
| Q4 | How GC finds the workspace root of a member | Accepted at the review: over-approximation (D10). A design gap that the manager records |
| Q-A | The exit 13 text for a missing compiler named `--roc pinned`, a flag that `install` rejects | Decided at the review: the project-tool path names `--allow-downloads` and `TALON_AUTO_INSTALL=yes` (R-DL4). `pt2-install` run 12, L0 16 |
| Gap | `--allow-downloads`: the test shows that the flag passes the consent stop (`pt2-install` run 14: the run goes on to the list of nightlies, then fails because the fake has no such list). The download and the build after it are tested by slices 046 and 047 | Partly tested |
| Gap | R-PT15: a missing compiler offline has no test | Not tested |
| Gap | The `--json` `data` of `install`, `update` and `upgrade` has no tools field | No field |

## 9. Compiler and tool limits met

| Limit | Effect |
| --- | --- |
| `{ x }` alone is a block | write `{ x: x }` |
| `ToolsCmd.op_of` in `Run` | a stub that crashes made every command crash, so `Run` uses the inline check `args.options.any(...)` |
| An unused variable is an error, and `roc build` exits 2 on a warning | two mutations did not compile at first and were changed |
| `roc fmt` must pass on the stubs | `mkstubs.py` runs `roc fmt` on the 6 new stubs |
| A dotted key in TOML must be quoted | the L0 row uses `"v2.x_y"` |
| `Str.inspect(Bool)` gives `True` or `False` | the L0 text rows use that form |
| The age of a package dir in L3 is its real mtime | R-GC4 is tested in L2 only |
| L2 `calls.log` has raw ancestor paths that depend on `TMPDIR` | section 2, as before |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Where | the 6 stubs of section 2, `Intent`, `InstallFlow`, `Resolve`, `Install`, `Update`, `XTake`, `Gc`, `CacheGc`, `XCacheIo`. `Run`, `main` and `Args` are done |
| Tests | Do not edit tests (TW18). A wrong row: write it in the report. The private reference was deleted at the review |
| `Intent` | read `[tools]` with `ToolsToml.read_table`. An issue is exit 19 (the first by line). A warning is printed. Add `"tools"` to `known_tables` and not to `member_tables`. A member file with `[tools]` gives the message of L0 `ToolsplanTest` 3 |
| `InstallFlow`, `Resolve`, `Install`, `Update` | `InstallFlow.install_with!(fx, request, tools : Try(Args, [None]))`. `install!` calls it with `Err(None)`. `Resolve.install_with!`, `Install.flow!` and `Update.resolve!` pass `Ok(args)`. `upgrade` uses `Update.resolve!` |
| Names split | `update` and `upgrade` split the names with `ToolsPlan.split`. With only tool names the header flow is skipped (an idle outcome). `install` with no names runs phase `Install` after the header flow. `install` with names runs no tools step (D3) |
| `--frozen` | `frozen!` calls `ToolsStep.frozen_check` before the closure fetch. After the line `the header satisfies talon.toml` it runs phase `Frozen`. No index call, no write of `talon.toml` |
| No extra calls | With an empty `[tools]` the code adds no `Fx` call. The old `calls.log` files stay the same, except the 3 cases of section 2 |
| `ToolsStep.ensure!` | reuse `ToolsPlan.cached`, `ToolFlow.bundle_for!`, `platform_for!`, `choose_for!`, `ToolBuild.built!` and `XCacheIo.write!`. It never touches `tools.json` |
| `ToolsStep.write!` | one `read_files!`, then `ResolveBase.write_checked!` (the Guard check), then one write. No write for `--dry-run` |
| `--dry-run` (D8) | `ToolsStep.chosen!` with `ctx.dry_run` returns the newest candidate of the pick with no fetch of a bundle. `ToolsStep.ensure!` with `ctx.dry_run` and no `ToolsPlan.cached` entry returns `would: true` with no bundle, no platform check, no compiler and no build. `ToolsStep.print!` prints `ToolsPlan.line(WouldBuild(..))` after the line of a row with `would_build`. A row with no line and `would_build` still prints the `would build` line |
| `nothing to change` (D16) | `InstallFlow.install_with!`: when a tools step runs (`tools` is `Ok` and the phase is `Ok`) the header flow gets an `Fx` whose `out!` drops the text `nothing to change\n`. After `ToolsStep.after!` the line is printed once when `step.changed` is false and the header outcome has no `written` file and no `kept` entry. `--frozen` is unchanged. `ToolsFlow.print!` prints the line when no change was made |
| `ToolsFlow` and no project file (Q3, D21) | call `Install.begin_loose!`. A failure of the search for which `ToolsPlan.no_project` is true gives the home `<cwd>/talon.toml` and the file list `[<cwd>/talon.toml]` for `Known.record!` (no `canonical!`). Any other failure of the search is the failure of the run |
| Compiler stop (Q-A) | `ToolsStep.ensure!` maps the failure of `ToolFlow.choose_for!` with `ToolsPlan.compiler_stop`. `ToolsStep.facts_of` uses `ToolsPlan.build_env({ env: ctx.env, allow: ctx.allow })` for `env`. `allow` is `request.downloads.allow == Ok(Yes)` for `install`, `update` and `upgrade`, and `cmd.allow_downloads == Ok(Yes)` for the commands with `--tool` |
| `ToolsFlow` | the table of the steps is in the stub. `add!` with the same app and the same key acts as `update <key>`. A key with another app gives `ToolsCmd.key_taken` |
| `XTake` | `ToolsHeld.all!(fx, roots)?` inside the lock, then `take_how({ project_uses: held.contains(entry.bundle) })`. Remove the old constant `held_hashes`. This is one more `read_files` of `projects.json` for each take-over |
| `Gc`, `CacheGc` | `Gc.judge`: a project path that ends in `/talon.toml` is live while the file exists. `CacheGc.aged!`: one `x_reads!`, then `XCache.expired` with `kept` as the held hashes. `ToolsHeld.of!` runs only if a live project exists and an `x` dir or a package dir would go. Filter the package dirs by the held hash |
| `XCacheIo.has_file` | a file (not a directory) named `<repo>` or `<repo>.exe` |
| Order of the calls | The `calls.log` files of the 5 L2 cases are the exact order |
| Reuse | `Install.begin!`, `Known.record!`, `Intent.read`, `RocInstall.read_config!`, `ResolveBase.write_checked!`, `ToolFlow`, `ToolBuild`, `ToolInstall.build_failed`, `XCacheIo`, `Common.failed!`, `Common.shown_fx`, `Out.json_ok` |
| Pure first | `ToolsCmd.read` makes no `Fx` call. A failure is printed with `Common.failed!` |
| Size | Keep each module at or under 490 lines |

## 11. Red run, revert check

Red run with the stubs in `cli/lib`, after the review (log: `research/slice-056-revert/red-all.log`):

| Step | Result |
| --- | --- |
| `scripts/test.sh check fmt l0 l2 l3 selftest` | check pass, fmt pass, selftest pass, l0 FAIL, l2 FAIL, l3 FAIL |
| L0 | `l0-8`: 76 tests, 60 passed, 16 failed (the 16 `expect`s of `ToolsplanTest`: a crash `todo: slice 056` or a wrong value of the stub). 0 compiler errors. The other drivers pass |
| L2 | 131 passed, 8 failed: `pt1-add`, `pt2-install`, `pt3-move` (the crash of the stub), `gc5-project-tools` and `tk2-takeover-project` (a wrong value: the entry is moved, not copied), and `gc1-select`, `gc3-caches`, `tk1-takeover` (the lines of section 2) |
| L3 | 72 passed, 1 failed (`ptools/pt1-flow`), 1 skipped |

Old tests: all pass in the stub state, except the 3 cases of section 2 (checked with `diff -rq` against `expect-before`: only these 3 differ).

Green run with the private reference after the review (log: `research/slice-056-revert/green-all.log`): `scripts/test.sh check fmt l0 l2 l3 selftest` all pass (L2 139 cases). `l1` was not run (the slice does not touch it).

Revert check (`research/slice-056-revert/mutants.py`, the result in `mutants.log`). Only filtered runs. The reference was put back after each run. First 10 mutations on the most tricky behaviors, then (review) one mutation for each change of the review. Two mutations (M3, M8) and one of the review (N2) did not compile at first (an unused variable) and were changed.

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `cached` ignores the target | L0 `ToolsplanTest` 10 |
| M2 | the range check of `--frozen` is removed | L0 `ToolsplanTest` 8, L2 `pt2-install` |
| M3 | `split` ignores the alias that is also a key | L0 `ToolsplanTest` 7, L2 `pt3-move` |
| M6 | the held walk does not stop at `[workspace]` | L0 `ToolsplanTest` 11 |
| M7 | the take-over always moves | L2 `tk2-takeover-project` |
| M8 | `has_file` takes any file that is not the manifest | L2 `pt2-install` |
| M9 | GC does not keep the package dirs of the held hashes | L2 `gc5-project-tools` |
| M10 | `header_idle` is always false | L2 `pt3-move` |
| M11 | the snapshot test uses `<` in place of `<=` | L0 `ToolsplanTest` 9 |
| M14 | a key of another app acts as an update | L2 `pt1-add` |
| N1 | D8: `--dry-run` builds (`ensure!` ignores `dry_run`) | L2 `pt1-add`, `pt2-install` |
| N2 | D16: `nothing to change` ignores the tools (`step.changed`) | L2 `pt2-install`, `pt3-move` |
| N3 | Q3: `no_project` is always false (no `talon.toml` is made) | L0 `ToolsplanTest` 16, L2 `pt1-add` |
| N4 | Q-A: `compiler_stop` keeps the text with `--roc pinned` | L0 `ToolsplanTest` 16, L2 `pt2-install` |
| N5 | `--allow-downloads` does not change the environment of the build | L0 `ToolsplanTest` 16, L2 `pt2-install` |

15 mutations, 15 caught, 0 not caught. L3 caught none of them (it is the end-to-end flow). No full sweep was run. At the review the private reference (`reference/`) and `reference-on.sh` were deleted. `stubs/` and `restore.sh` stay. `mkstubs.py` and `mutants.py` need the reference and cannot run again.

## 12. Split (TW19, accepted at the review)

The reference had about 1250 lines against a limit of 500 for one slice. The tests are one set. The code is four passes, in this order, each with its own green run. The table of the parts is in the section Review.

If the manager keeps one slice, the code agent should write the modules in this order and run the cases of each part when it is done.

## Review (manager, 2026-10-25)

The manager accepted the slice with the split of section 12: one test set, four code passes in the order 056a, 056b, 056c, 056d.

| Item | Answer | Where |
| --- | --- | --- |
| D1 to D7, D9 to D15 | Accepted. The texts of section 5 (TW24) are accepted | |
| D8 | Changed: `--dry-run` builds nothing and writes nothing. It prints the planned tool lines (the release that would be locked, `would build`). A dry run must not start a long build | `pt1-add` run 15, `pt2-install` run 13, L0 12 |
| D16 | Changed: `nothing to change` is printed only when neither the header nor the tools change | `pt2-install` runs 1, 2, `pt3-move` runs 8, 13 |
| Q3 | Changed: `add --tool` with no project file makes `talon.toml` in the current directory (NC1 allows a `talon.toml` with no app file) | `pt1-add` run 16, L0 16 |
| Q-A | Changed: the exit 13 text for a missing compiler in the project-tool path names `--allow-downloads` and `TALON_AUTO_INSTALL=yes` (R-DL4), not `--roc pinned` | `pt2-install` runs 12, 14, L0 16 |
| Q2, Q4 | Accepted as the reference did. Design gaps: the manager records them | section 8 |

The parts. A module that two parts share is written by the first part that needs it. `ToolsStep.one!` has the phase `Update` in 056a (a second `add --tool` with the same key acts as `update <key>`, `pt1-add` run 3), the phases `Install` and `Frozen` in 056b, and the phase `Upgrade` in 056c.

| Part | Stub modules | L0 expects | L2 cases and runs | L3 steps |
| --- | --- | --- | --- | --- |
| 056a: `add --tool`, `remove --tool`, the `[tools]` read | `ToolsToml`, `ToolsCmd`, `ToolsPlan` (`home`, `visible`, `selector_for`, `add_ref`, `cached`, `line`, `file_line`, `data`, `build_env`, `compiler_stop`, `no_project`), `ToolsStep` (`Ctx`, `machine!`, `facts_of`, `pick!`, `chosen!`, `ensure!`, `run!`, `one!` for `Update`, `write!`, `print!`, `data`), `ToolsFlow`, `Intent` (read, member role), `Install.begin_loose!` | 1 to 6, 10, 12, 13, 14, 16 (expect 9 stays red until 056c) | `pt1-add` runs 1 to 16. `pt3-move` runs 6, 12 | 1, 2 |
| 056b: `install`, `install --frozen` | `ToolsPlan` (`frozen_check`), `ToolsStep` (`frozen_check`, `ctx_of`, `after!`, `one!` for `Install` and `Frozen`), `InstallFlow` (`install_with!`, `frozen!`, D16), `Resolve`, `Install` (`flow!`), `XCacheIo.has_file` | 8 | `pt2-install` runs 1 to 14 | 3, 6 (and the `install --frozen` of 4) |
| 056c: `update`, `upgrade`, the names split | `ToolsPlan` (`split`, `upgrade_ref`, `stuck_note`), `ToolsStep.one!` for `Upgrade`, `ToolsFlow` (`moved!`, `check_keys`), `InstallFlow` (`tools_split`), `Update` | 7, 9 | `pt3-move` runs 1 to 5, 7 to 11, 13 | none (the L3 flow has no `update`) |
| 056d: GC and the take-over | `ToolsPlan` (`held_paths`, `held_hashes`), `ToolsHeld`, `Gc` (`judge`, `projects`), `CacheGc`, `XTake` (NC3) | 11, 15 | `gc5-project-tools` runs 1 to 3. `tk2-takeover-project` runs 1 to 5. `gc1-select`, `gc3-caches`, `tk1-takeover` (the lines of section 2) | 4 (`cache gc`), 5 (`cache gc`). The scenario is green after 056d |

Notes for the parts: the red state of a part is the state of the tests after the passes before it. A test of a later part stays red until its part is done. L3 `ptools/pt1-flow` is one script that stops at the first wrong step: steps 1 and 2 are green after 056a, step 3 after 056b, and the whole scenario after 056d.

## Verify results (056a)

Code agent, 2026-10-25. Part 056a: `add --tool`, `remove --tool`, the `[tools]` read.

| Check | Result |
| --- | --- |
| `scripts/test.sh check fmt l0 l2 l3 selftest` | check pass, fmt pass, selftest pass. l0: `l0-8` 76 tests, 71 passed, 5 failed (expects 7, 8, 9, 11, 15: parts b, c, d). l2: 132 passed, 7 failed (`pt2-install` b, `pt3-move` c, `gc1-select`, `gc3-caches`, `gc5-project-tools`, `tk1-takeover`, `tk2-takeover-project` d). l3: `ptools/pt1-flow` steps 1 and 2 are green, the first difference is in step 3 (`install --frozen`, part b) |
| New green | L0 expects 1 to 6, 10, 12, 13, 14, 16. L2 `pt1-add` (16 runs). `pt3-move` runs 5, 6, 12 (the other runs of the case wait for part c; its `Update` runs with `--tool` already match) |
| Old tests | all pass, except the 3 cases with new `calls.log` lines (part d) |
| Files | `ToolsToml` 205, `ToolsCmd` 168, `ToolsPlan` 176 (a part), `ToolsStep` 320 (a part), `ToolsFlow` 214, `Intent` 395, `Install` 184 |
| Revert check | 9 mutations in 6 places, 9 caught (`research/slice-056-revert/agent-mutate-a.py`, `agent-results-a.md`). Files after the mutations are the same as `code-final-a/` |

Decisions of the code agent that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | The `--tool` commands take the snapshot from `--snapshot`, else from `[resolution] snapshot` of the `talon.toml` that holds `[tools]` (as `install`, R-EV1). The text of a bad `--snapshot` is the text of `ResolveSelect` | `--snapshot` only |
| C2 | `ToolsToml.app_of : Str -> Str` is a new public function (the name of a `ref`). It is used by `ToolsStep` and `ToolsFlow` | A private copy in each module |
| C3 | `ToolsStep.facts_of` gives `bin: ""` and `entries: []`: a project tool has no bin dir and reads no `tools.json` (R-PT12) | `Setup.bin_dir` (it can fail for a missing `HOME`) |
| C4 | `ToolsStep.one!` has the arm `Update` only in 056a. The other phases give a failure of kind `Internal` (`the phase is not built yet`) until parts b and c | A `crash` |

## Verify results (056b)

Code agent, 2026-10-25. Part 056b: `install`, `install --frozen`.

| Check | Result |
| --- | --- |
| `scripts/test.sh check fmt l0 l2 l3 selftest` | check pass, fmt pass, selftest pass. l0: `l0-8` 76 tests, 72 passed, 4 failed (expects 7, 9, 11, 15: parts c, d). l2: 133 passed, 6 failed (`pt3-move` c, `gc1-select`, `gc3-caches`, `gc5-project-tools`, `tk1-takeover`, `tk2-takeover-project` d). l3: `ptools/pt1-flow` steps 1 to 3 and the `install --frozen` of steps 4 and 6 are green, the first difference is the `cache gc` of step 4 (part d) |
| New green | L0 expect 8. L2 `pt2-install` (14 runs). The old L3 case `update/up1-update-entries` stays green (see C6) |
| Old tests | all pass, except the cases of later parts |
| Files | `ToolsPlan` 209, `ToolsStep` 382 (a part), `ToolsFlow` 215, `InstallFlow` 305, `Resolve` 125, `Install` 185, `XCacheIo` 101 |
| Revert check | 11 mutations, 11 caught (`research/slice-056-revert/agent-mutate-b.py`, `agent-results-b.md`). Files after the mutations are the same as `code-final-b/` |

Decisions of the code agent that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C5 | The minimum release age of `install`, and of the `--tool` commands too (`ToolsFlow`), is `Setting.pick` of `[resolution] min-release-age` of the `talon.toml` that holds `[tools]`, then `config.toml`, then 2 days (R-C7, as `ResolveBase.settings_of`) | `config.toml` only (the first form of `ToolsFlow`) |
| C6 | D16 uses `header_changed(outcome)` in place of "`written` is empty": a `--dry-run` has an empty `written` but planned changes (`added`, `moved`, `pinned`, `toml`, `renamed`), as the test of `Install.print!` for the line of R-DT5. With the text of the notes, `tln install --dry-run` of the old L3 case `update/up1-update-entries` printed `nothing to change` after a planned `+ lex` line | `written` and `kept` only |
| C7 | `frozen_check` finding 3 for a URL with no name (`Ident.name` is `NoName`): `the url is of <url>, the ref is of <owner/app>` | A new text |
| C8 | `install_with!` runs the tools step with the phase `Frozen` after `frozen!` and gives no `nothing to change` for it (`--frozen` is unchanged, D16) | A line after the tools |

## Verify results (056c)

Code agent, 2026-10-25. Part 056c: `update`, `upgrade`, the names split.

| Check | Result |
| --- | --- |
| `scripts/test.sh check fmt l0 l2 l3 selftest` | check pass, fmt pass, selftest pass. l0: `l0-8` 76 tests, 74 passed, 2 failed (expects 11 and 15: part d). l2: 134 passed, 5 failed (`gc1-select`, `gc3-caches`, `gc5-project-tools`, `tk1-takeover`, `tk2-takeover-project`: part d). l3: `ptools/pt1-flow` first difference is the `cache gc` of step 4 (part d) |
| New green | L0 expects 7, 9. L2 `pt3-move` (13 runs) |
| Old tests | all pass, except the cases of part d |
| Files | `ToolsPlan` 246, `ToolsStep` 393 (a part), `InstallFlow` 321, `Update` 195 |
| Revert check | 11 mutations, 10 caught, 1 not caught (`research/slice-056-revert/agent-mutate-c.py`, `agent-results-c.md`). Files after the mutations are the same as `code-final-c/` |

Not caught: C7. `update <name>` where `<name>` is no key of `[tools]` (a header entry) in a project that has `[tools]` must run the header flow only. With the mutation the tools step ran for each entry. No run of `pt3-move` names a header entry in a project with `[tools]` (run 8 has no names, run 9 is a failure of the split). A test row `update json --file p2/main.roc` (p2 has `[tools]` and a header entry) would catch it. This is a gap of the tests, not changed by the code agent (TW18).

Decisions of the code agent that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C9 | `upgrade_ref` takes the kind of the selector from `Selector.parse` and rewrites the text as typed (`Ranges.rewrite` of the text after the `@`, not of the parsed `Range` text, which has a `^` added by R-SL15) | Rewrite the parsed range |
| C10 | An `upgrade` that finds the `url` at the newest release keeps the entry whole (no change of the `ref`). The stuck note is decided at the newest candidate before any bundle fetch or build | Decide after the build |
| C11 | `ToolsStep.after!` has no call and no check when the file has no `[tools]` entry (so `tln init` and the old commands add no failure path) | Always `ctx_of` |
| C12 | `InstallFlow.tools_split` gives the header flow the names that are for the header (`request.names`), and `prepared!` still gets the full request | A second `prepared!` |

## Verify results (056d)

Code agent, 2026-10-25. Part 056d: GC and the take-over. This is the last part: the slice status is `verify`.

| Check | Result |
| --- | --- |
| `scripts/test.sh` (check fmt l0 l2 l3 selftest l1) | all pass, exit 0. l0: `l0-8` 76 tests, all passed. l2: 139 passed, 0 failed. l3: 73 passed, 0 failed, 1 skipped (`ptools/pt1-flow` is green: 6 steps). l1 pass |
| New green | L0 expects 11 and 15. L2 `gc5-project-tools`, `tk2-takeover-project`, and the 3 old cases with the new `calls.log` lines (`gc1-select`, `gc3-caches`, `tk1-takeover`). L3 `ptools/pt1-flow` |
| `crash "todo` | none left in `cli/` and `packages/` (`grep -rn 'crash "todo' cli packages`) |
| Files | `ToolsHeld` 35, `ToolsPlan` 296, `Gc` 338, `CacheGc` 239, `XTake` 165 |
| Revert check | 11 mutations, 10 caught, 1 not caught (`research/slice-056-revert/agent-mutate-d.py`, `agent-results-d.md`). Files after the mutations are the same as `code-final-d/` |
| Whole slice | `research/slice-056-revert/code-final/` (15 files) and `code-final.sha256` (`sha256sum -c` from the repo root). Each new module is under 490 lines: `ToolsCmd` 168, `ToolsFlow` 215, `ToolsHeld` 35, `ToolsPlan` 296, `ToolsStep` 393, `ToolsToml` 205. Changed modules: `Intent` 395, `Install` 185, `InstallFlow` 321, `Resolve` 125, `XCacheIo` 101, `Update` 195, `Gc` 338, `CacheGc` 239, `XTake` 165 |
| Totals of the revert check | 42 mutations (056a 9, 056b 11, 056c 11, 056d 11), 40 caught, 2 not caught (C7, D9). None of the two is a bug of the code: both are gaps of the tests |

Not caught: D9. The read of `[tools]` in `cache gc` starts when a live project exists and an `x` entry or a package dir would go (the note of section 10). Each L2 case with a live project also has a package dir that can go, so a code that starts the read for a package dir only passes. A case with a live project, an expired `x` entry and no package dir would catch it. A gap of the tests, not changed by the code agent (TW18).

Decisions of the code agent that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C13 | `ToolsPlan.held_hashes` reads the `url` of each entry of `[tools]` itself (`Toml.get`, `Ident.of_url`). It does not use `ToolsToml.read_table`, so an entry with a bad `ref` and a good `url` still keeps its build (GC keeps more, never less) | `read_table` (it drops the entry for a bad `ref`) |
| C14 | `CacheGc.aged!` computes the expired `x` dirs twice with the same manifests (`kept: []` to know whether a read is needed, then with the held hashes), and `Gc.candidates` twice (with no held hash for the same test). The read of `[tools]` is one `ToolsHeld.of!` | Always read when a live project exists (it breaks the `calls.log` of cases with nothing to remove) |
| C15 | `Gc.judge`: a path that is `talon.toml` or ends with `/talon.toml` is live when its file is read and the entry is in the age (any text). Other paths keep the `Locked.read` test | A `talon.toml` that is not valid TOML goes |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

## Gap tests (test agent, 2026-10-25)

Gap step (TESTING.md 7.1 step 5). The code agent's mutations C7 (056c) and D9 (056d) were not caught. The 3 tests below close them and the decision C13. No code was changed: after each hand mutation the live files were put back and compared with `research/slice-056-revert/code-final/` (`cmp` of each of the 15 files, and `sha256sum -c code-final.sha256`: all equal). The script is `research/slice-056-revert/gap-mutate.py`, the result `gap-results.md`. `gen-ptools.py` makes the new case and the new run.

| Gap | New test | Mutation | Result |
| --- | --- | --- | --- |
| C7: `update <name>` where `<name>` is a header entry, in a project that has `[tools]`, runs no tools step | L2 `ptool/pt3-move` run 14: `update pf --file p2/main.roc` (`pf` is the platform alias, `p2` has the tool `fmt`). The header flow runs (the index of basic-cli is read), no call for the tool `fmt`, the line `nothing to change` once. R-PT5 | `InstallFlow.tools_named`: `phase: Ok(phase)` (the tools step runs for each entry) | caught by `pt3-move` |
| D9: GC reads `[tools]` when only an `x` entry can go | L2 `gc/gc6-held-no-package` (new case, 3 runs, 20 files): a live project `p1` names the bundle of `khold`. `khold` and `kfree` are expired by age, `kfresh` is not, `packages/` has no dir. `cache gc --dry-run` and `cache gc` make one `read_files` of the `talon.toml` files, keep `khold` and `kfresh` and remove `kfree`. The third run removes nothing, but `khold` is still expired by age, so the read is made again and keeps it. R-PT14, R-GC7 | `CacheGc.aged!`: the read starts for `!open.pkgs.is_empty()` only | caught by `gc6-held-no-package` |
| C13: a bad `ref` with a good `url` keeps its build | L0 `ToolsplanTest` 17: `held_hashes` of a file with `ref = 5` and a `url`, a `ref` that is no ref and a `url`, an entry with no `url`, an entry with a `url` that is no release gives the 2 hashes of the first two. `Intent.read` of the same file is exit 19. R-PT14, R-PD13 | `ToolsPlan.hashes_of` uses `ToolsToml.read_table` (it drops the entry for a bad `ref`) | caught by L0 |

Run results: L0 `l0-8` 77 tests, all passed. L2 139 cases before and 140 now, all passed. One full `scripts/test.sh` (check fmt l0 l2 l3 selftest l1): all pass, exit 0 (`gap-full.log`). `calls.log` of `gc6-held-no-package` has raw ancestor paths that depend on `TMPDIR` (as `gc1-select`). No old expected file changed. No bug of the code was found.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| Live `cli/lib` files equal `research/slice-056-revert/code-final/` | `cmp`: all 15 equal |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.6, fmt 0.2, l0 7.2, l2 9.3, l3 10.0, selftest 3.0, l1 37.1 s |
| Code passes | 056a to 056d: 42 mutations, 40 caught; the 2 misses (C7, D9) are now caught by gap tests |
| Gap tests | pt3-move run 14 (C7), gc/gc6-held-no-package (D9), L0 expect 17 (C13); 3 hand mutations caught; no code bug |
| Decisions C1 to C15 | accepted |
