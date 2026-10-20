# 010 Closure walk and `list`

Phase: P0. Status: done

This slice adds the closure walk: the headers of the packages in the closure, fetched as needed. Four commands use it: `install` (also `--frozen`), `update`, `verify` (before the ladder) and the new `tln list` (`ls`). It also adds the warning R-C8 (2 series of one package in the closure) and the 4 short runs that slice 009 moved here (gaps L4, F10, W13, F17). The slice follows `docs/agents/BRIEF-tests.md`. Slice 011 (`why`) stays as it is.

The code agent starts with the move of `install!`, `remove!` and `verify!` out of `cli/lib/Resolve.roc` (section "First step: split Resolve"). Then it writes the bodies of the stubs.

## Rules of the slice

| Group | Ids | Where the test is |
| --- | --- | --- |
| Commands | R-CM9 (`list`, `--tree`), R-CM19 (`ls`), R-CM2 (the closure fetch of `install`) | L0 `listing`, L3 `list/ls1-list`, L2 `closure/cl1-flow` |
| Closure | R-H4 (`foreign`), R-H7 (a path entry joins the closure), R-ID2 (group of a URL), R-C2 and R-OV1 (highest version wins, `raised`), R-FE1 (hash check of the deeper packages), R-AL2 (the closure of the header after the planned edit, one fetch call for each level), R-SP21 (no `talon.toml`: fetch the closure, write nothing) | L0 `closure`, L2 `cl1-flow` (runs 1, 2, 6), L3 `ls1-list` |
| Warning | R-C8 (2 series), Q11 | L0 `closure` and `listing`, L2 `cl1-flow` (4 runs), L3 `ls1-list` |
| Flags and output | R-FL3 (`--offline`), R-FL6 (`--file`), R-PD9, R-J1 to R-J4, R-OUT2, R-OUT4, R-EC2, R-EC10, R-EC15, R-EC18, R-FE7 | L0 `listing`, L3 `ls1-list` |
| Gaps of slice 009 | R-PH7 (L4), R-RP2 and R-NS5 (F10), R-LD7 (F17), R-NM7 (W13) | L2 `gaps/g1-slice009` |

## First step: split Resolve (the code agent, no change of behavior)

`cli/lib/Resolve.roc` has 1759 lines. Move `install!`, `remove!` and `verify!` with their helpers before you add the walk. The move changes no test and no expected file. Check: `scripts/test.sh` gives the same result before and after the move (the red steps of this slice stay red for the same tests).

| Rule | Text |
| --- | --- |
| 1 | `Resolve` keeps these public names with the same signatures: `Resolve.Request`, `run!`, `install!`, `remove!`, `picks!`, `verify!`. `install!`, `remove!`, `verify!` call the new modules. `Install.roc`, `Remove.roc`, `Update.roc`, `Verify.roc` and `tests/commands/main.roc` do not change (the tests call only `Resolve.run!` and `Resolve.Request`) |
| 2 | A module cannot import a module that imports it. So the type `Request` and the helpers that all 3 flows use move to a base module (suggested name `ResolveBase.roc`: `Request`, `Loaded`, `Fact`, `load!`, `settings_of`, `check_pin`, `snapshot_of`, `loaded_text`, `main_of`, `read_releases!`). `Resolve.Request` is an alias of it |
| 3 | A function moves to the module of the one flow that calls it. Suggested modules: `InstallFlow.roc` (`install!`, `frozen!`, `prepared!`, `resolve!`, `pick!`, `pick_loop!`, `prepare!`, `finish!`, `ladder!`, `write!` and their helpers), `RemoveFlow.roc` (`remove!`, `removal_plans!`, `import_hits!`, `removal_ladder!`, `write_removal!`, `removed_of`, `removed_text`), `VerifyFlow.roc` (`verified!`, `checked_members`, `no_replace`). `verified!` and `finish!` share helpers: they go to the base module or to one of the two, as the imports need |
| 4 | No new module is longer than 800 lines. The new files are listed in `main.roc` |
| 5 | The step table of `Ls` (step 7) needs the load of the members. After the split it is a public function of the base module. The name is free: no test calls it |

## Files

| File | Lines | What |
| --- | --- | --- |
| `cli/lib/Closure.roc` | 106 | New. Part A and B (pure). The doc tables hold the rules of `Closure.step`. Stubs |
| `cli/lib/Walk.roc` | 26 | New. Part C: `Walk.run!`. The doc table holds the calls of one level. Stub |
| `cli/lib/Listing.roc` | 64 | New. Part A: `Listing.read`, `text`, `tree`, `data`. Stubs |
| `cli/lib/Ls.roc` | 25 | New. `Ls.run!`: the wiring of `tln list`. The doc table holds the steps. Stub |
| `cli/lib/Release.roc` | +6 | `Release.entries_of` (stub). `Release` has no new field |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +9, +7 | Dispatch of `list` and `ls`. Exposes `Closure`, `Listing`, `Ls`, `Walk` |
| `tests/unit/closure.roc` | 312 | New. 7 expects |
| `tests/unit/listing.roc` | 134 | New. 4 expects |
| `tests/commands/cases/closure/cl1-flow/` | 204 (calls.log) | New. L2, 6 runs |
| `tests/commands/cases/gaps/g1-slice009/` | 103 (calls.log) | New. L2, 4 runs |
| `tests/scenarios/list/ls1-list/` | 21 (cmd) | New. L3, 7 runs |
| `tests/commands/FakeFx.roc` | +9 | `create_item!` accepts `copy:<dest>=<source>` (a fake download that makes a package with a real header) |
| `tests/fixtures/add/make.py`, `hashes.txt` | +60 | Repos `acme/web`, `mid`, `core`, `text`, the table `DEPS`, the options `skip`, `fetched`, `pages` of a case, and the 3 new cases |

## Public signatures (the code agent keeps them)

| Function | Signature |
| --- | --- |
| `Closure.step` | `{ file : Str, entries : List(Entry), nodes : List(Node) } -> [Need(List(Str)), Done(Walked), Fail(Problem)]` |
| `Closure.failure` | `Problem -> Fail` (kind `NoTuple`) |
| `Closure.clashes` | `List(Row) -> List({ name : Str, series : List({ series : Str, via : Str }) })` |
| `Closure.notes` | `List(Row) -> List(Str)` (the lines of R-C8) |
| `Closure.Row` | `{ id, kind : [Release, Path, Foreign], alias, name, form, version, series, direct, via : Try(Str, [None]), raised : Try(Str, [None]), is_platform }` |
| `Closure.Walked`, `Link`, `Entry`, `Node`, `Problem` | In the file, with their doc tables |
| `Walk.run!` | `Fx, { roots, net, offline, file, entries, known } => Try({ walked, nodes }, Fail)` |
| `Listing.read` | `Args -> Try({ tree : Bool }, Fail)` |
| `Listing.text`, `Listing.tree` | `{ file : Str, walked : Closure.Walked } -> Str` |
| `Listing.data` | `List({ file, walked }) -> JsonDoc` |
| `Ls.run!` | `Fx, Args => I32` |
| `Release.entries_of` | `{ path : Str, text : Str } -> Try(List({ alias : Str, value : Str, is_platform : Bool }), Fail)` |

`Closure.step` uses `Mvs.select` of the generic package `roc-app-header` 0.1.0 (R-GP5: not tested again). A path node needs a URL for Mvs: the code gives it a made-up one. Roc follows only the selected version of each group, so the walk reads only these (Q16).

## Where the walk runs (the L2 case `cl1-flow` fixes the calls)

| Command | Place | Known headers (not read again) |
| --- | --- | --- |
| `install`, `update` | In `finish!`, after the notes and before `ladder!`. The rows of each member are the header after the planned edits without the pin writes (R-AL2) | The headers that the pick read (`facts.known`) |
| `verify` | In `verified!`, before the ladder or the `check: skipped` line | The same |
| `install --frozen` | In `frozen!`, after `Frozen.check`, before the line `the header satisfies talon.toml` | None: all levels are read |
| `list` | `Ls.run!` step 8, for the current member (else all members) | The nodes of the member before |
| Level | One `Fetch.packages!` for the release URLs of the level (only when there are some), then one `read_files!` for their `main.roc` and the path files, then `Release.entries_of` for each, then `Closure.step` again | |

The R-C8 lines go to stderr, once each for a run (`Closure.notes`, no repeat). They do not change the exit code. `list` makes no compiler call (no `programs`, no `roc version`).

## Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `closure`: `step` of one header, level by level | R-H4 R-H7 R-AL2 R-CM2 R-CM9 R-ID2 R-FE1 |
| L0 | `closure`: the winner changes when a node is read | R-C2 R-OV1 R-CM9 |
| L0 | `closure`: a path entry, a raise from a path entry | R-H7 R-H4 R-C2 |
| L0 | `closure`: the 5 failures of `Mvs.select` as a problem | R-C2 R-EC10 |
| L0 | `closure`: `Closure.failure` kind and texts | R-EC10 |
| L0 | `closure`: `clashes` and `notes` | R-C8 R-CM9 |
| L0 | `closure`: `Release.entries_of` (4 header kinds, no header) | R-H7 R-C3 R-CM9 |
| L0 | `listing`: `Listing.read` (7 rows) | R-CM9 R-CM19 R-FL5 R-FL7 R-EC2 |
| L0 | `listing`: `Listing.text` | R-CM9 R-H4 R-C8 R-OUT2 |
| L0 | `listing`: `Listing.tree` | R-CM9 R-H4 |
| L0 | `listing`: `Listing.data` | R-CM9 R-OUT4 R-OUT5 R-J3 R-J4 |
| L2 | `closure/cl1-flow` (6 runs: `install`, `install --frozen`, `list`, `update`, `verify`, `update` that moves a package) | R-CM2 R-CM9 R-H7 R-C8 R-AL2 R-SP21 R-FE1 R-PD9 R-OUT2 |
| L3 | `list/ls1-list` (7 runs: `list`, `ls --tree`, `list --json`, `list web`, `--offline` with a missing package, a closure with no tuple, a missing path file) | R-CM9 R-CM19 R-H4 R-H7 R-C8 R-OV1 R-FE7 R-FL3 R-FL6 R-J1 to R-J4 R-OUT4 R-EC2 R-EC10 R-EC15 R-EC18 R-PD9 |
| L2 | `gaps/g1-slice009` (4 runs: `verify` with a held compiler that is not installed, `verify` with a pin outside `[toolchain] roc`, `verify --json` of a package, `update -i` with no free package) | R-PH7 R-RP2 R-NS5 R-LD7 R-NM7 R-OUT4 R-EC10 R-EC13 |

L0 count: 11 expects (7 in `closure`, 4 in `listing`). Deep cases: 3 (1 L3, 2 L2). The `rules` file of each L2 case and the head of `cmd` say what each run checks.

## Old cases that changed (the walk reads more)

The old files are in `research/slice-010-revert/before/tests/commands/cases/`.

| File | Change | Why |
| --- | --- | --- |
| `install/in1-flow/expect/calls.log` | 3 new lines `read_files $PROJECT/lib/main.roc $PROJECT/app/inner/main.roc` (3 runs, before the ladder) | R-H7: the header of a path entry is read |
| `resolve/rs-frozen/expect/calls.log` | 1 new line: the `main.roc` of acme/json 2.1.0 in the run `good` | `--frozen` walks the closure (R-CM2) |
| `resolve/rs-no-compiler/expect/calls.log` | 1 new line: the `main.roc` of acme/json 2.0.0 in the run `--frozen` | The same |
| `resolve/rs-install-add-key/expect/calls.log` and `given/project/lib/main.roc` (new file) | The header of the project has the path entry `../lib/main.roc`, and the file did not exist. The walk reads it (Q21). The file is now `package [Lib] {}`, and the calls.log has 2 new `read_files $PROJECT/lib/main.roc` lines | R-H7 |

No other old file changes. The 3 changes of slice 009 (`rs-failures`, `rs-new-toml`, `rs-update-scope`) are not from this slice.

## Output proposals (TW24, for the human review)

| Item | Proposal |
| --- | --- |
| Flat list (`list`) | One block for each member: the project file, then one line for each row: 2 spaces, the alias, the label (`<name> <version>`, else the value as written), the marks. The columns are padded to the longest alias and the longest label, and 2 more. Marks: `direct` or `via <alias>`, `raised from <version>`, `foreign`, joined by `; ` |
| Tree (`list --tree`) | The project file, then one line for each link, depth first, 2 spaces for each level: `<alias>: <label> (<marks>)`, with no `via`. A row that was shown before says `(shown above)` and has no children |
| `list --json` | stdout is the envelope only. `data.members` (a list): `file`, `packages` (`alias`, `name`, `version`, `kind`, `id`, `direct`, `via`, `raised`, `foreign`, `platform`), `links` (`from`, `alias`, `to`), `series` (the clashes of R-C8) |
| R-C8 warning (Q11) | `warning: <name> has 2 series in the closure: <series> via <alias>, <series> via <alias>. The types of the 2 series are different types.` |
| `list` with a name | `tln list takes no name` (kind `usage`) |
| Closure problem | Kind `no_tuple` (exit 10). Texts: `the closure has a cycle: a -> b`, `the header names one package at 2 versions or more: ...`, `one release has 2 hashes in the closure: ...`, `<package> needs <package>, but the header names <package>`, `the platforms in the closure are not one release: ...` |
| Missing path file | Kind `environment` (exit 18): `cannot read <path>` (Q21) |

The L3 expected files hold the exact texts.

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `Closure.step` is a pure solver step (`Need`, `Done`, `Fail`). `Walk` loops. | One effect function that calls `Mvs` itself (no L0 test, no call order in L0) |
| D2 | The walk fetches only the selected version of each group (Q16) | Fetch each named version |
| D3 | The walk uses the headers that the pick read, so `install`, `update` and `verify` do not read the level 1 headers again | Read all levels again (more old calls.log files change, and one more read for each header) |
| D4 | `Release.entries_of` is a new function. `Release` has no new field | A new field `entries` in `Release` (the record literals of `tests/unit/pick.roc` stop to compile) |
| D5 | The closure walk of one member that has an edit runs on the edited header | Run on the header as it is (R-AL2 says the closure of the tuple) |
| D6 | `list` shows the current member when there is one, else all members (R-PD5) | All members always |
| D7 | `--json` of `list` has `links` and `series` too (R-OUT4: the data has what the text prints, and `--tree` prints the links) | Only `packages` |
| D8 | The `raised` mark is of the package, with the lowest named version (Q9) | A mark of the edge |

## Questions (TW17) and design gaps

| # | Question | Default (the tests use it) |
| --- | --- | --- |
| Q16 | Which versions does the walk fetch, and which failure does a bad closure give? Design 2 says Roc builds the winners. | Winners only. A problem of `Mvs.select` is kind `no_tuple`, exit 10 |
| Q17 | R-H7 says the `import` lines of a path entry join the scan of `remove`. A path file uses the aliases of its own header, not those of the app. Does `remove json` count an `import json.X` in a path file? | Not in P0: `remove` is as slice 008 left it |
| Q18 | The mark `patched` (R-CM9) has no source in P0 (patches are Resolution 7) | No `patched` mark |
| Q19 | `list` in a workspace (R-PD5, R-PD14) | The current member, else all members. No test (G3) |
| Q20 | `list --json` prints the human list too? | No. stdout is the envelope (R-J1) |
| Q21 | A path entry whose file is missing | A failure, kind `environment`, exit 18, `cannot read <path>`. Not a skip |
| Q22 | R-FL4 (`--quiet`) prints only errors and answer lines. Does the R-C8 warning stay with `--quiet`? | The warning is hidden. No test |

Design gaps: R-AL2 names one registry request for the whole closure (Registry 4). P0 has no registry, so the slice fetches level by level from the cache and the release URLs.

## Out of scope

| Rule or item | Reason |
| --- | --- |
| R-H7: `import` lines of a path entry in the scan of `remove` | Q17 |
| R-H7: GC counts the closure (R-PD12) | The GC slice |
| `patched` mark of R-CM9 | Q18 |
| R-SO18 (`.roc-version` warning in `tln ls`) | The `.roc-version` file has no slice yet |
| R-AL2: one registry request | No registry in P0 |
| `list` and the walk in a workspace (R-PD5, 2 members: dedupe of the R-C8 lines, member choice) | G3: no workspace case in P0 (mutants L5, R7, R8) |
| `install --dry-run` runs the walk (Q12) | No test. The code agent follows Q12 |
| `--quiet` and the R-C8 warning | Q22, no test |
| R-AL4 to R-AL7, R-SP6 to R-SP13 | Other slices |

## Red output (stubs, `scripts/test.sh`, 2026-10-20)

| Step | Result |
| --- | --- |
| `check`, `fmt`, `selftest` | pass |
| `l0` | `closure`: 7 failed (`todo`). `listing`: 4 failed (`todo`). All other files pass |
| `l2` | 5 failed: `closure/cl1-flow` (the `list` run stops the app with `todo`), and the 4 old cases of the table above (they need the walk). `gaps/g1-slice009` passes now: the 4 runs test the code of slice 009 (the revert check below shows that they catch the 4 gaps). All other cases pass |
| `l3` | 1 failed: `list/ls1-list` (`list` crashes with `todo`). All other scenarios pass |

## Revert check (TW12)

The script is `research/slice-010-revert/mutate.py`, the table is `research/slice-010-revert/results.md`. The rows change one place of a private reference implementation (written by the test agent, deleted after the run). 62 rows: 56 caught, 6 not caught.

| Row | Why it is not caught |
| --- | --- |
| C1, S3, R5 | Equivalent change: no input can show it |
| L5, R7, R8 | G3: they need 2 members in one project |

The 4 gaps of slice 009 (rows GL4, GF10, GF17, GW13) are caught by `gaps/g1-slice009`. Two rows needed a better case: R6 (the walk on the edited header) led to run 6 of `cl1-flow`. W6 (a loop that never ends) is not a row.

## Review of the tests (manager, 2026-10-20)

D1 to D8, the output proposals (TW24) and the 4 changed old cases are accepted. The answers are proposals of the manager. The user did not confirm them yet.

| # | Answer |
| --- | --- |
| Q16, Q18 to Q22 | The defaults |
| Q17 | No change in `remove`, for a reason: a path file reads its `import` lines through the aliases of its own header, and its own entries stay in the closure. So the remove of an app entry never breaks a path file import. The R-H7 scan of a path file matters for an entry of that path file, which Talon never changes (R-H4). |
| R-AL2 gap | Level by level in P0 (no registry). To report to the user. |

Status: code. The code agent does the "First step: split Resolve" before the closure walk.

## Split of Resolve (code agent, 2026-10-20)

No change of behavior, no test change. `scripts/test.sh` before and after the move gave the same result (the red steps were the same tests):

| Step | Before the move | After the move |
| --- | --- | --- |
| `check`, `fmt`, `selftest` | pass | pass |
| `l0` | `closure` 7 failed, `listing` 4 failed, the other 44 files pass | the same |
| `l2` | 24 passed, 5 failed (`closure/cl1-flow`, `install/in1-flow`, `resolve/rs-frozen`, `resolve/rs-install-add-key`, `resolve/rs-no-compiler`) | the same |
| `l3` | 24 passed, 1 failed (`list/ls1-list`), 1 skipped | the same |

| Module | Lines | Holds |
| --- | --- | --- |
| `Resolve.roc` | 119 (was 1759) | `Request` (an alias of `ResolveBase.Request`), `install!`, `remove!`, `verify!`, `picks!`, `run!`. The doc tables of the flows stay here. The 3 flows are one line each |
| `ResolveBase.roc` | 415 | `Request`, `Loaded`, `Fact` and the other shared types. `load!`, `prepared!`, `settings_of`, `check_pin`, `snapshot_of`, `loaded_text`, `main_of`, `read_releases!`, `current_rows`, `owner_rows`, `set_edits`, `moved_platform_notes`. Slice 010: `entries_after`, `known_nodes`, `closure!`, `closure_notes!` |
| `PickFlow.roc` | 545 | `pick!` and its helpers (the names, the scope, the index, `Pick.step`). A new module: the 3 suggested modules would be longer than 800 lines |
| `InstallFlow.roc` | 469 | `install!`, `frozen!`, `resolve!`, `finish!`, `ladder!`, `write!` and their helpers |
| `VerifyFlow.roc` | 130 | `verify!`, `verified!`, `checked_members` |
| `RemoveFlow.roc` | 315 | `remove!` and its helpers |

The imports go one way: `ResolveBase` <- `PickFlow` <- `InstallFlow` <- `VerifyFlow`, and `RemoveFlow` <- `ResolveBase`. `Resolve` imports the 3 flows. `main.roc` lists the 5 new modules. The one-off script of the move is `research/slice-010-revert/split-resolve.py` (it reads `research/slice-010-revert/code-before/cli/lib/Resolve.roc`, the file before the move). Rule 5: `ResolveBase.load!` is public, `Ls` uses it.

## Code (green, code agent, 2026-10-20)

Files written (lines now): `Closure.roc` 365, `Walk.roc` 79, `Listing.roc` 186, `Ls.roc` 80. Changed: `Release.roc` 56 (`entries_of`; `read` and `entries_of` share the private `parsed`), `main.roc` 80, `Run.roc` 101 (the dispatch was in the stubs already), `InstallFlow.roc`, `VerifyFlow.roc`, `PickFlow.roc`, `ResolveBase.roc` (the wiring below).

| Place | What the code does |
| --- | --- |
| `Closure.step` | Mvs gets the root edges (release URLs and path files, not foreign values) and `deps` of the nodes read. A path file has a made-up URL (`talon.path/x<bytes as digits>/1.0.0/`), so Mvs treats it as one group for each file. With `Ok(chosen)` the winners are the chosen URLs. With `Err` the winners are the fixed point of "the header version, else the highest" (`settle`), only to see whether a node is not read yet. The rows are a queue walk over the followed edges (header edges first, the edges of a row are queued when the row is new). `Need` is the list of the rows with no node, in row order. A problem is a `Fail` only when `Need` is empty |
| `Walk.run!` | `Closure.step`, then for each `Need`: one `Fetch.packages!` for the release URLs (none: no call), one `read_files!`, `Release.entries_of` of each text |
| `ResolveBase.closure!` | `Walk.run!` for each member in the order of the list, with the nodes of the earlier members as `known` |
| `ResolveBase.closure_notes!` | The R-C8 lines on stderr, each text once, not with `--quiet` (Q22) |
| `finish!` | After the plan and before the ladder: all members, the entries after the planned edits (`entries_after`, no pin write), `known` is the headers of the pick (`Finish.known`, `known_nodes`) |
| `verified!` | The same for the checked members, before the ladder or `check: skipped` |
| `frozen!` | After `Frozen.check`: all members, no `known`. The walk makes the fetch that `read_releases!(..., False)` made before |
| `Ls.run!` | `Listing.read`, `Install.begin!`, `Known.record!`, `ResolveBase.load!`, the walk of the current member (else all members), the notes, then the text, the tree or the envelope. No compiler call |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | A new module `PickFlow.roc` (`pick!` and its helpers) | 3 modules only: `InstallFlow` would have about 1100 lines (rule 4: at most 800) |
| C2 | `known_nodes` has empty aliases for the nodes of the pick (`Release` keeps no alias, D4). Only `via` of the rows is used by `install`, `update` and `verify` (R-C8), and it comes from the header entries | A new field `alias` in `Release` (D4) |
| C3 | `pick_loop!` gives the facts that it read, `Finish` has the new field `known`. Both are private | A second read of the headers (D3) |
| C4 | The walk runs with `--dry-run` too (the slice table, Q12: Q12 has no text in the design files) | No walk with `--dry-run` |
| C5 | The failure of `Mvs` with an unread winner: `Need` first, `Fail` after the read (the L0 case of the rounds) | `Fail` at once (the problem can come from a version that does not win) |
| C6 | `ResolveBase.closure_notes!` hides the lines with `--quiet` (Q22) | Show them |

Disputes (from the code agent): none. No test, fixture or expected file was changed by the code agent.

## Verify results (code agent, 2026-10-20)

`scripts/test.sh` exit 0: check 3.9 s, fmt 0.1 s, L0 46 files pass, 145 expects (9.3 s), L2 29 cases pass (55.3 s), L3 25 pass and 1 skipped (9.2 s), selftest 24 pass (7.3 s). Total about 85 s. The red items of the stubs are green: L0 `closure` (7), `listing` (4); L2 `closure/cl1-flow`, `install/in1-flow`, `resolve/rs-frozen`, `resolve/rs-install-add-key`, `resolve/rs-no-compiler`; L3 `list/ls1-list`. `roc check` has 0 errors and 0 warnings for all apps.

Revert check (TW12): `research/slice-010-revert/code-mutate.py`, rows in `research/slice-010-revert/code-results.md`. Caught 44 of 52. `cli/` after the run equals the copy before it (`diff -r` with `research/slice-010-revert/code-green/cli`, and `code-before.sha256`).

| Id | Rule | Mutation | Result |
| --- | --- | --- | --- |
| X4 | R-C2 | `settle` (the winners after a failure of Mvs) gives no winner | NOT CAUGHT. No L0 case has a problem while a winner is not read. Gap of the tests |
| X16 | R-EC10 | `RootConflict` list is not sorted | NOT CAUGHT. Mvs gives that order for the test input |
| X19 | R-C3 | A later platform edge does not set `is_platform` of the row | NOT CAUGHT. No case has it |
| S3 | R-CM9 | The marks `raised` and `foreign` swap | NOT CAUGHT. Equivalent: a `foreign` row is never `raised` |
| L5 | R-C8 | A note is not made unique over members | NOT CAUGHT. Needs 2 members (G3) |
| L6 | R-FL6 | `list` takes all members, not the current member | NOT CAUGHT. Needs 2 members (G3) |
| R6 | R-AL2 | `entries_after` ignores an `Add` | NOT CAUGHT. The header of an added package is a fact of the pick, so the reads do not change |
| R8 | R-CM2 | The nodes of a member are not given to the next member | NOT CAUGHT. Needs 2 members (G3) |

Questions (TW17): none. Design gap for the report: Q12 (`install --dry-run`) has no text in the design files (C4).

## Review of the code (manager, 2026-10-20)

`scripts/test.sh` passes (manager run). The split of `Resolve` changed no test result. The revert check of the new code caught 44 of 52. The decisions of the code agent are accepted. X4 (`settle` after a Mvs failure with an unread node) and X19 (`is_platform` from a later edge) move to slice 011: the test agent adds a row for each. X16, S3 and R6 are equivalent for the test input. L5, L6 and R8 need 2 members (G3).
