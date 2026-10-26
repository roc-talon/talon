# 060 The compiler of `roc unbundle`

Phase: P1. Status: done

Slice 060 is the plan row 060 of `PLAN-P1.md` (from section 5b, answer Q5 of slice 055). R-FE4 says: Talon runs `roc unbundle` with the selected compiler when it is installed, else the newest installed compiler, else the `roc` on `PATH` (rank 7). With none, the selected compiler is a required download (R-DL2). Before this slice, `Gather` and `Fetch.packages!` ran the word `roc` (the first `roc` that the system finds on `PATH`) and did not look at the installed compilers. Only `tln probe` followed R-FE4 (slice 037).

The pure choice already exists: `ProbeCmd.unbundler` (slice 037, 8 L0 rows). This slice moves it to `Fetch` (the place that all fetches share), adds the rule R-NS6 to it (a named build is never the "newest"), and makes `Fetch.packages!` call it (a lazy choice). The selected compiler of each flow follows the answer to Q1 (section 9): a held compiler, else the `default-roc` of `config.toml` when the flow knows it, else none.

## 1. Where `roc unbundle` runs (the list of the manager)

| Site | Commands | Compiler before the slice | Compiler after the slice |
| --- | --- | --- | --- |
| `Gather.get!` (`cli/lib/Gather.roc`), called by `PickLoop.read_all!`, `Walk.level!`, `ResolveBase.read_releases!` | the commands that pick or walk a closure (the `ResolveBase.Request` flows, `install --frozen`) | `roc` (the word, `PATH`) | `Choose({ selected: request.selected })`: `request.selected` is the held compiler (`InstallFlow`, `VerifyFlow`) or the `default-roc` (`Ls` for `list` and `why`, `OutdatedFlow`, `PatchFlow`); `""` for the other `Request` flows (section 3a) |
| `PathFlow.fetch!` | `tln path` | `roc` | same |
| `PatchFlow.fetch!` | `tln patch` | `roc` | same |
| `Init.platform_header!` | `tln init --platform` | `roc` | same |
| `ToolFlow` (the fetch of a bundle and of a platform) | `tool install`, `tool update`, `tool rebuild`, `x`, project tools | `roc` | same |
| `ProbeFlow.materialise!` for an alias | `tln probe <alias>` | `what.program`: the program that the probe runs (the selected compiler, or from `--range` the R-FE4 choice) | the same value, as `Program(what.program)` |
| `ProbeBundle.ensure!` for a bundle file | `tln probe <hash>.tar.zst` | `ProbeCmd.unbundler` (R-FE4, slice 037) | `Fetch.unbundler` (moved) |
| `cli/flowprobe.roc`, `tests/commands/main.roc` (entry `fetch`) | test apps | `roc` | `Choose` (the entry has the words `have:`, `path:`, `select:`) |

No other code runs `roc unbundle`. The downloads of compilers, Zig and git sources use `tar`, not `roc unbundle`.

## 2. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-FE4 | The program of `roc unbundle`: the selected compiler when installed (row 1: the held compiler, else the `default-roc`, Q1), else the newest installed (row 2), else the `roc` on `PATH` (row 3), else a required download (row 4, exit 18 in this slice, Q2) | L0 `FetchTest.roc` expect 3 (17 rows). L2 `fetch/fe-flow` runs 1 to 15. L2 `init/it2-platform` run 7. 25 changed L2 `calls.log` files. L3 `fetch/fe1-loopback-fetch` |
| R-NS6 | `git-`, `link-` and `copy-` builds are not nightlies and not releases: they are selected by name only. So they are never the "newest installed" | L0 `FetchTest.roc` expect 3 (rows 13 to 16). L2 `fetch/fe-flow` runs 11 and 15 |
| R-FE2 (as used) | The program is the program of `roc unbundle`. A refusal of roc is still exit 16, a program that does not start is exit 18 | L2 `fetch/fe-flow` runs 3, 8 (old, unchanged texts) |
| R-SO9, R-SO14 (as used) | The `roc` on `PATH` (rank 7) is looked up only when no nightly or release is installed. Nothing at all: exit 18 `no compiler is selected` | L2 `fetch/fe-flow` runs 11, 12, 13. L3 `fetch/fe1-loopback-fetch` |
| R-LY1 (as used) | The installed compilers are the dirs of `<cache>/toolchains` (`Launch.toolchains!`) | L2 `fetch/fe-flow` runs 9 to 15 |
| R-SO6 (as used) | The global default (`default-roc`) is the selected compiler of a flow with no decision that knows it (answer Q1) | L0 `FetchTest.roc` expect 4. L2 `patch/pa1-flow` |
| R-LK4 (as used) | A selected `link-` build runs the path in its `.talon.json` (answer Q3) | L2 `fetch/fe-flow` run 16 |

Other ids that the tests name and the slice does not own: R-FE1, R-FE3, R-FE7, R-FE8, R-FE10, R-DA2, R-DA3, R-DA5, R-DA7, R-EV12, R-EV24, R-HF4, R-HF12, R-SE1, R-SE9 (the old rules of `fe-flow`).

Rule check: `MISSING=1 scripts/rules.sh R-FE R-NS` lists only R-FE9 (P2). R-FE4 had 5 tests that named it and none that checked it.

## 3. Public signatures (stub in `cli/lib/Fetch.roc`, `crash "todo: slice 060"`)

| Name | Signature | State |
| --- | --- | --- |
| `Fetch.Unbundler` | `[Program(Str), Choose({ selected : Str })]`. `Program(p)`: the program is `p` (a command that chose it already). `Choose`: `packages!` chooses it | done (a type) |
| `ResolveBase.Request.selected` | `Str`: the compiler that the fetches of the run call selected, `""` for none | wired: every constructor gives `""` (8 files and `tests/commands/main.roc`) |
| `Fetch.packages!` | the facts have `unbundler : Fetch.Unbundler` in place of `roc : Str` | wired. `Gather.get!`, `Walk.Facts`, `PickLoop`, `ResolveBase` pass `request.selected` down. `PatchFlow` passes `Choose({ selected: request.selected })`. `PathFlow`, `Init`, `ToolFlow`, the test apps pass `Choose({ selected: "" })`. `ProbeFlow` passes `Program(what.program)` |
| `Fetch.selected` | `{ held : Str, default : Str } -> Str`: `held` when it is not empty, else `default` (Q1) | stub: gives `""` (no selected compiler: the old behavior). The L0 expect 4 fails with a wrong value |
| `Fetch.unbundler` | `{ selected : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Try(Str, [NoCompiler])`: the id of the compiler, not its file (answer Q3: the file of a `link-` build is read by `Launch.program!`) | stub (pure decision) |
| `program_of!` (private in `Fetch.roc`) | `Fx, { roots : Roots, unbundler : Fetch.Unbundler } => Try(Str, Fail)` | stub: `Choose(_)` gives `Ok("roc")` (the old behavior). `Program(p)` is done |
| `unbundle!` (private, step 6) | calls `program_of!` only when a URL was downloaded, and fails each such URL with the failure of `program_of!` | done |

### 3a. Where `selected` is set (answer Q1 (a))

| Flow | `selected` | Wired by this slice |
| --- | --- | --- |
| `install`, `add`, `update`, `upgrade` (`InstallFlow.install_with!`), `install --frozen` | `Fetch.selected({ held: decision.held ?? "", default: loaded.config.default_roc ?? "" })` | yes. L2 `closure/cl2-chain` run 1 (the pin is installed and is not the newest) |
| `verify` (`VerifyFlow.verify!`) | the same | yes, no case that tells it from the newest |
| `list`, `why` (`Ls.walk_full!`), `outdated`, `patch` | `Fetch.selected({ held: "", default: loaded.config.default_roc ?? "" })`: they load the files (so they know the default) and make no pin decision | yes. L2 `patch/pa1-flow` (the default is installed and is not the newest) |
| `remove`, `roc use`, `probe` (it runs its own program, D8) | none (`""`): their fetches run before a decision, and the `Request` is made before the files are read. Passing the default would need a change of the order of their calls | no |
| `tln path`, `init --platform`, `tool *`, `x`, `run` (project tools) | none (`""`): no decision, and the default is not in scope at the fetch. `init` and `tool` read `config.toml`, but in another function than the fetch (`Init.start_url!`, `ToolFlow.machine!`), so the default would have to be passed on (no new read) | no. A follow-up: row for the next slice |

The code agent does these steps:

| # | Step |
| --- | --- |
| 1 | `Fetch.selected`: the body (one line) |
| 2 | `Fetch.unbundler`: the body of `ProbeCmd.unbundler` (rows 1 to 4 of its doc), with these changes: it gives the id (`found.id` for row 3), and the "newest installed" is taken from the ids for which `Pin.is_id` is true (R-NS6). Row 1 (`selected` in `installed`) has no such filter: a named build can be selected by name |
| 3 | `program_of!`, branch `Choose({ selected })`: `Launch.toolchains!(fx, roots)`; when no id of the list is a nightly or a release (`Pin.is_id`), `OnPath.file!(fx, roots)`, else `Err(NoCompiler)`; then `Fetch.unbundler`. `Err(NoCompiler)` becomes `Compiler.failure(NoCompiler)`. Then `Launch.program!(fx, { roots, id, installed, path })` (a `link-` id: one `read_files!` of its `.talon.json`). Imports to add: `Compiler`, `Launch`, `OnPath`, `Pin` |
| 4 | Delete `ProbeCmd.unbundler` (its L0 rows moved to `FetchTest`). `ProbeFlow.unbundle_program` becomes effectful: `Fetch.unbundler` for the id, then `Launch.program!`. Remove an import of `ProbeCmd` that is not used any more |

## 4. The tested reading

| # | Topic | Reading |
| --- | --- | --- |
| 1 | When the choice is made | Inside `Fetch.packages!`, step 6, only when at least one download ended with `Done`. A run with all items present, offline, or with only failed downloads makes no call of the choice (L2 `fe-flow` runs 2, 4, 14, and all old runs of other cases). Reason in D1 |
| 2 | The calls | `Choose`: one `list_dirs` of `<cache>/toolchains` (`Launch.toolchains!`) before the `spawn_all` of the unbundles. Only when no nightly or release is installed: the calls of `OnPath.file!` (`path_roc`, `read_files` of `path-roc.json`, and the first time `roc version` and `write_atomic` of the cache, slice 022b). Each `Fetch.packages!` call makes its own choice (a closure walk of 3 levels makes 3, `cl1-flow`) |
| 3 | The program | Row 1: `<cache>/toolchains/<id>/roc` (`Launch.program`). Row 3: the file of PATH as PATH wrote it. The job is `[<program>, "unbundle", "<hash>.tar.zst"]` with the temp dir as the working directory. The calls.log line shows the program |
| 4 | Row 2 and R-NS6 | The newest by `Pin.order` with no times (the day of the tag, then the tag text; a release has no day, so every nightly is newer, two releases go by version). A named build is not an id of this list |
| 5 | No compiler | `Compiler.failure(NoCompiler)`: kind `Environment`, exit 18, `no compiler is selected. Run: tln roc install @latest, then tln roc default <id>`. Each URL that was downloaded gets this failure, nothing is spawned, the temp dirs are deleted (step 8) |
| 6 | The selected compiler | Section 3a. `Fetch.selected`: the held compiler, else the default, else none. Row 1 is tested by the pure decision, by `fe-flow` runs 9, 15 and 16 (the entry passes `select:`), by `closure/cl2-chain` (held) and by `patch/pa1-flow` (default) |
| 7 | A link | A selected `link-` build: `Launch.program!` reads `<cache>/toolchains/<id>/.talon.json` (one `read_files`, after the `list_dirs`) and the job runs the path in it (`fe-flow` run 16) |

## 5. Tests

| Layer | File | Case | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/FetchTest.roc` (driver `l0-6.roc`) | expect 3: `Fetch.unbundler`, 18 rows (ids). Rows 1 to 8 are the 8 rows that moved from `ProbecmdTest.roc` (the expect is removed there). New rows: one installed, two nightlies of one day, a release against a nightly, two releases, a named build and a link selected by name, a named build that is not the newest (the list order is reversed), only named builds with PATH, only named builds with no PATH, a selected named build that is not installed. Expect 4: `Fetch.selected`, 6 rows (a held compiler wins over the default, the default, no default, a held named build, a link default, none) | R-FE4, R-NS6, R-FE2, R-SO6 |
| L2 | `tests/commands/cases/fetch/fe-flow` | runs 1 to 8 changed (the given home has the compiler nightly-2026-10-14-38a3029: program and one `list_dirs`). New runs 9 to 16: the selected compiler (9), the newest because the selected one is not installed (10), only named builds installed with PATH (11, with the first PATH lookup), a nightly installed with PATH (12, no `path_roc`), nothing anywhere (13, exit 18, no unbundle call, temp deleted), a 404 only (14, no choice call), a named build selected by name (15), a `link-` build selected by name: one `read_files` of its `.talon.json`, and the job runs the path in it (16) | R-FE4, R-NS6, R-SO9, R-SO14, R-FE2, R-LK4 |
| L2 | `tests/commands/cases/init/it2-platform` run 7 (new) | `init --platform acme/wpf` with the platform release not in the cache: the download, `roc unbundle` with the newest installed compiler, the stub. This is the only case where `Init.platform_header!` downloads | R-FE4 |
| L2 | 25 cases, `expect/calls.log` only (TW21, section 6). Two of them test the selected compiler: `closure/cl2-chain` (the world has the pin nightly-2026-10-14-38a3029 and the newer nightly-2026-10-16-9e9e9e9: the fetch of run 1 uses the pin, `InstallFlow` passes the held compiler) and `patch/pa1-flow` (`config.toml` has `default-roc = nightly-2026-10-14-38a3029`, and the newer nightly is installed: the fetch uses the default, `PatchFlow` passes it). The others: `closure/cl1-flow`, `patch/pa1-flow`, `path/pt1-entry`, `probe/lp2-fetch`, `ptool/pt1-add`, `pt2-install`, `pt3-move`, `run/rn3-tools`, `tool/dl2-tool-windows`, `dl3-rename-edges`, `dx2-source-windows`, `tg1-git`, `ti1-install`, `ti2-refusals`, `ti3-compiler`, `ti4-nothing`, `tk1-takeover`, `tr1-rebuild`, `tr2-rebuildstops`, `ts6-source`, `tu1-update`, `tu2-updatestops`, `x/x1-run`, `x/x3-project` | R-FE4, R-SO6 |
| L3 | `tests/scenarios/fetch/fe1-loopback-fetch` | no compiler installed: the program is the fake `roc` on PATH. `roc.log` has one more line, `version` (the first lookup of PATH with the real Fx). The unbundles are as before | R-FE4, R-SO9 |
| L3 | 7 cases that fetch (`ptools/pt1-flow`, `ptools/pt2-x`, `run/rn1-flow`, `tools/ti1-tool-install`, `ti2-tool-compiler`, `ti3-tool-git`, `tx1-x-run`) | the fake compiler in the store gets 2 lines: `unbundle` goes to the fake `roc` on PATH (and so to the real roc). No expected file changes, except 4 numbers in `tools/tx1-x-run` (the size of the fake compiler that `cache gc` prints) | R-FE4 |

Counts: 2 new L0 expects (18 and 6 rows, 8 rows moved), 1 L0 expect removed from `ProbecmdTest.roc` (moved), 8 new runs in `fe-flow`, 1 new run in `it2-platform`, 25 changed `calls.log` files (2 with a changed world: `cl2-chain`, `pa1-flow`), 1 changed L3 `roc.log`. Deep cases: 2 new (`fe-flow` runs 9 to 16 are one case, `it2-platform` run 7).

L3 stays small. No L3 case needs a real second compiler: the fake compilers of the store pass `unbundle` to the roc on PATH. A real second compiler would be needed only for an L4 case that proves that the selected compiler (not the one on PATH) did the unbundle. The slice has no such case (L3 `roc.log` cannot tell the compilers apart).

## 6. The changed expected files (TW21)

The old copies are in `research/slice-060-revert/before/`. `UPDATE=1` was used for the 27 L2 cases and for 2 L3 cases (`fetch/fe1-loopback-fetch`, `tools/tx1-x-run`). Each diff was read.

| Class | Cases | The change in `calls.log` |
| --- | --- | --- |
| An installed compiler (19) | `ptool/pt1-add`, `pt2-install`, `pt3-move`, `run/rn3-tools`, `tool/dl2`, `dl3`, `dx2` (2 homes), `tg1`, `ti1`, `ti2`, `ti3`, `tk1`, `tr1`, `tr2`, `ts6`, `tu1`, `tu2`, `x/x1-run`, `x/x3-project` | `+list_dirs <cache>/toolchains` before each unbundle `spawn_all`, and the job shows `<cache>/toolchains/nightly-2026-10-14-38a3029/roc` in place of `roc`. The newest installed compiler was checked by a script for each case |
| PATH `roc` known (`fx/path-roc`) and no compiler installed (1) | `closure/cl1-flow` | `+list_dirs`, `+path_roc`, `+read_files path-roc.json` (the cache is hit: the start of the command did the lookup), the job shows `/fake/bin/roc` |
| The selected compiler is not the newest (2) | `closure/cl2-chain`, `patch/pa1-flow` | `cl2-chain`: the world has no PATH lookup any more, it has the installed pin and a newer nightly (`given/home/.cache/roc/toolchains/`); run 1 shows `+list_dirs` and the job with the pin. `pa1-flow`: `config.toml` has `default-roc`, and a newer nightly is installed (so the stub, which gives no selected compiler, runs the newer one); the job shows the default |
| No compiler in the world, and the case is not about that (2) | `path/pt1-entry`, `probe/lp2-fetch` | The world gets an installed compiler (`given/home/.cache/roc/toolchains/nightly-2026-10-14-38a3029/.talon.json`). Then as the first class. Without it the run is exit 18 |
| No compiler, and the case is about that (1) | `tool/ti4-nothing` | The case tests the prompt for a compiler that is not installed, so the world must stay empty. The world gets a `roc` on PATH (`fx/path-roc`, a `version` rule in `fx/jobs`): `+list_dirs`, `+path_roc`, `+read_files`, `+spawn_all limit=1` with `/fake/bin/roc version`, `+write_atomic path-roc.json`, then the job with `/fake/bin/roc`. Stdout and stderr are the same |
| `fetch/fe-flow` | all | the given home has a compiler (first class for runs 1 to 8), 8 new runs. `tree.diff`: the packages of the new runs, and the last `have:` (the old compiler dir is gone) |
| `init/it2-platform` | run 7 is new | `home8` is a copy of `home6`. 90 lines in `calls.log`, 9 in `stdout`, 33 in `tree.diff`: all new, none changed |

No `stdout`, `stderr` or `tree.diff` of another case changed. The `probe/pc1-targets` and `probe/pc2-range` cases did not change (they already used the R-FE4 program).

## 7. Output (proposed, R-OUT2)

No new text. A fetch with no compiler gives the existing failure of `Compiler.failure(NoCompiler)`: `tln: error[environment]: no compiler is selected. Run: tln roc install @latest, then tln roc default <id>`, exit 18. There is no `--json` `data` field. The `calls.log` of the L2 cases is the only output that changes.

## 8. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | The choice is lazy and inside `Fetch.packages!`: it runs only when a download ended with `Done`, and again for each `Fetch.packages!` call. Reason: it costs nothing when all items are present, so only 25 old L2 cases change, and no command has to know about it. | An eager choice at the start of each command (one list and one PATH lookup for each run, also for runs that fetch nothing: many more `calls.log` files change, and the call sites need the program as a new input). A choice that is made once for the command and passed down (the fake `Fx` and `Gather` have no state for it) |
| D2 | The `roc` on PATH is looked up (`OnPath.file!`) only when no nightly or release is installed, also for `install --frozen` (it has `request.compiler = Err(NoCompiler)` by design). A lookup that the command made at its start is made again: the cache `path-roc.json` makes it 2 calls (`path_roc`, `read_files`) | Pass `request.compiler` to `Gather` (a new input for 3 callers, and it is wrong for `--frozen`) |
| D3 | A named build (`git-`, `link-`, `copy-`) is never the "newest installed" (R-NS6: selected by name only). The old `ProbeCmd.unbundler` could pick one, because `Pin.order` gives `Same` for these ids | Keep the old function as it was |
| D4 | The "newest" is by `Pin.order` with no times, as in slice 037: a release has no day, so any nightly is newer than any release | Read the `.talon.json` of each installed compiler for `published_at` (N reads for a choice that does not change the result of `roc unbundle`) |
| D5 | No compiler anywhere is exit 18 with the text of `Compiler.failure(NoCompiler)`, as `tln probe` does (slice 037). The download of the selected compiler (R-FE4, R-DL2) is not started by a fetch (Q2) | A required download with the prompt of R-DL1 inside `Fetch.packages!` |
| D6 | The worlds of 2 old L2 cases (`pt1-entry`, `lp2-fetch`) get an installed compiler, so that they keep their meaning. `ti4-nothing` gets a `roc` on PATH, because its meaning is "no compiler installed". `cl2-chain` and `pa1-flow` get an installed pin or default and a newer nightly, to test the selected compiler | Let the cases change to exit 18 |
| D7 | The fake compilers of 7 L3 cases pass `unbundle` to the roc on PATH (2 lines in each). `roc.log` and all outputs stay the same | A real second compiler in the store (L4) |
| D8 | `Fetch.Unbundler` has two variants. `ProbeFlow` keeps its own choice (`Program`): it chose the program of the whole command already, and a second `list_dirs` would change its cases for no gain | One variant: `ProbeFlow` would list the compilers again |
| D9 | Q1 (a), the manager answer. `selected` is the held compiler (`decision.held`, the value before the pick: a move of the nightly in `InstallFlow` can change it after) else the `default-roc` else none. It is set in `InstallFlow`, `VerifyFlow`, `Ls`, `OutdatedFlow`, `PatchFlow` (section 3a). The pure `Fetch.selected` has the rule | A flow-by-flow rule in each flow (no L0 row) |
| D10 | Q3, the manager answer. `Fetch.unbundler` gives the id and `program_of!` calls `Launch.program!`, so a selected `link-` build runs its recorded path. `copy-` and `git-` builds run `toolchains/<id>/roc` (no read) | The pure `Launch.program` for all ids |

## 9. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | A fetch that downloads the selected compiler when none is installed (R-FE4, R-DL2) | Q2: follow-up row in `PLAN-P1.md` 5b (the manager adds it). This slice keeps exit 18 |
| Out 2 | `selected` for `remove`, `roc use`, `probe`, `path`, `init --platform`, `tool *`, `x`, `run` | Section 3a: no decision or no default in scope. Follow-up |
| Out 3 | An L4 case with a real second compiler | Section 5 |
| Out 4 | A test that tells the compilers of the L3 cases apart | The fake store compilers pass `unbundle` to the roc on PATH, so `roc.log` is the same for all |

Answers of the review (2026-10-25):

| Id | Question | Answer, and where it is tested |
| --- | --- | --- |
| Q1 | Which compiler is "the selected compiler" for a fetch? | (a): a flow with a decision passes the held compiler. A flow with no decision passes the `default-roc` of `config.toml` when it already knows it, else none. Tested: L0 `FetchTest` expect 4, L2 `closure/cl2-chain` (held), L2 `patch/pa1-flow` (default) |
| Q2 | No compiler anywhere: a required download? | Keep exit 18 in this slice. R-FE4 says "a required download (R-DL2)", so exit 18 is not the design: a follow-up row |
| Q3 | A selected `link-` build | `Launch.program!` (section 3, D10). Tested: L0 `FetchTest` (a link selected by name), L2 `fetch/fe-flow` run 16 |

Design gaps and follow-ups (one table):

| Id | Kind | Gap | Where |
| --- | --- | --- | --- |
| G1 | Design | R-FE4 says "the newest installed compiler" and does not say if a named build counts (this slice reads R-NS6: it does not), nor how a release with no `published_at` is ordered (D4: a release is older than every nightly) | CLI R-FE4, Resolution R-NS6, R-NS1 |
| G2 | Design | R-FE4 says "a required download (R-DL2)"; this slice gives exit 18. R-SO14 says `install --frozen` needs no compiler, and R-FE2 says every fetch runs `roc unbundle`, so `install --frozen` with no compiler cannot fetch | CLI R-FE4, R-FE2, R-LF1, Resolution R-SO14 |
| G3 | Design | Resolution 13 gives "the selected compiler" for a command with a project. R-SO19 says that the held nightly can move during `install` (a move of the nightly), so "selected" before and after the pick can differ. This slice uses the value before the pick (D9) | Resolution R-SO19, R-FE4 |
| G4 | Follow-up | The flows of section 3a that pass none (`remove`, `roc use`, `probe`, `path`, `init`, `tool`, `x`, `run`). `init` and `tool` read `config.toml` in another function than the fetch: pass the default on | next slice |
| G5 | Follow-up | The required download of R-FE4 in a fetch (Q2) | `PLAN-P1.md` 5b (the manager) |
| G6 | Follow-up | `tests/commands/main.roc` is over 490 lines (644, 622 before the slice) | `PLAN-P1.md` 5b (the manager) |

## 10. Compiler and tool limits met

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | `{ selected }` alone is a block, not a record | `Choose({ selected: selected })` | write the field name |
| C2 | A warning fails the build: an unused import or an unused parameter | the stub has no import of `Compiler`, `Launch`, `OnPath`, `Pin` and names its parameters `_x`, `_fx` | the code agent adds the imports |
| C3 | The first version of the "selected ignored" mutation (an unused field) gave a warning that failed all L0 files | the revert check | the mutation keeps the use of the field |

## 11. Verify results

| Step | Red state (stubs, 2026-10-25, after the review) |
| --- | --- |
| check, fmt, selftest, l1 | pass |
| l0 | FAIL: `tests/unit/FetchTest.roc:136` (expect 3) crashes with `todo: slice 060`. `FetchTest.roc:170` (expect 4, `Fetch.selected`) gives `""` where the rows want the held compiler or the default. All other l0 files pass |
| l2 | FAIL, 27 cases, all with the wrong value (the old `roc` program and no `list_dirs`): the 25 of section 5, `fetch/fe-flow`, `init/it2-platform`. All other cases pass. `closure/cl2-chain` and `patch/pa1-flow` show the newest nightly in place of the pin and the default. `fe-flow`: run 13 gives `fetched` in place of exit 18, runs 9 to 12, 15 and 16 show the program `roc` |
| l3 | FAIL: `fetch/fe1-loopback-fetch` (`roc.log` has no `version` line). The other 82 pass (the 7 cases with a store compiler pass in both states) |

The log is `research/slice-060-revert/red-run.log`. With the reference (deleted at the review): check, fmt, l0, l2, l3, selftest and l1 all passed (`green-run.log`). The revert check had 10 hand mutations of the tricky behaviors; each one was caught by at least one test (the list is in the report of the review).

## 12. Files

| File | Change |
| --- | --- |
| `cli/lib/Fetch.roc` | the type `Unbundler`, the stubs `unbundler`, `selected` and `program_of!`, the wired `unbundle!` (about 310 lines) |
| `cli/lib/Gather.roc`, `PatchFlow.roc`, `PathFlow.roc`, `Init.roc`, `ToolFlow.roc`, `ProbeFlow.roc`, `cli/flowprobe.roc` | the field `unbundler` in the call of `Fetch.packages!` (1 line each) |
| `ResolveBase.roc`, `Install.roc`, `Ls.roc`, `ProbeFlow.roc`, `Remove.roc`, `RocUse.roc`, `Update.roc`, `Verify.roc`, `PickLoop.roc`, `Walk.roc` | the field `selected` of `Request` and `Walk.Facts`, passed down to `Gather.get!` |
| `InstallFlow.roc`, `VerifyFlow.roc`, `Ls.roc`, `OutdatedFlow.roc`, `PatchFlow.roc` | `request` with `selected: Fetch.selected(...)` after the files are loaded (section 3a) |
| `tests/unit/FetchTest.roc`, `ProbecmdTest.roc` | the new expect (166 lines), the removed expect and its unused import |
| `tests/commands/main.roc` | the words `have:`, `path:`, `select:` of the entry `fetch` |
| `tests/commands/cases/`, `tests/scenarios/` | section 5 and 6. New files are in `research/slice-060-revert/before/NEW.txt` |

## 13. Verify results (code agent, 2026-10-25)

| Step | Green state |
| --- | --- |
| `scripts/test.sh` | exit 0: check, fmt, l0, l2, l3, selftest, l1 all pass (about 72 s) |
| Code | `Fetch.selected`, `Fetch.unbundler`, `program_of!` written; `ProbeCmd.unbundler` deleted; `ProbeFlow.unbundle_program!` is effectful. Unused imports `Launch`, `Pin`, `Roots` removed from `ProbeCmd.roc`. No test changed |
| Final copy | `research/slice-060-revert/code-final/`, `code-final.sha256` (21 files) |

Revert check (7 mutations, filtered runs, code restored and compared with `cmp`):

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | `Fetch.unbundler`: no `Pin.is_id` filter for the newest (R-NS6) | L0 `FetchTest` expect 3 |
| 2 | `Fetch.unbundler`: row 1 only for an empty `selected` | L0 `FetchTest` expect 3 |
| 3 | `Fetch.selected`: the default wins over the held compiler | L0 `FetchTest` expect 4 |
| 4 | `program_of!`: `PATH` looked up when the list is empty only in place of when no nightly or release is installed | L2 `fetch/fe-flow` (run 11) |
| 5 | `program_of!`: `Launch.program` in place of `Launch.program!` (a `link-` build) | L2 `fetch/fe-flow` (run 16) |
| 6 | `program_of!`: `selected` ignored | L2 `closure/cl2-chain` |
| 7 | `Fetch.unbundler`: no compiler gives `Ok("")` | L2 `fetch/fe-flow` (run 13) |

Caught 7 of 7.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-060-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.7, fmt 0.2, l0 7.8, l2 9.7, l3 10.0, selftest 3.4, l1 35.8 s |
| Code pass | 7 of 7 mutations caught; no decision outside the slice |
| Gap tests | None: no mutation was missed, and the code agent made no new decision. |
| Design gaps | Section 9 (G1 to G6), recorded in PLAN-P1 5b: the flows of G4 pass no selected compiler yet; no compiler gives exit 18 (follow-up row). |
