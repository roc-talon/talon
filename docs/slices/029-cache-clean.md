# 029 Cache clean

Phase: P1. Status: done

Slice 029 is `tln cache clean [--all] [--dry-run]` (CLI 6.3, R-GC12 to R-GC14, the prompt R-NI7, R-NR3). It removes cache content on request, with no age rule: `talon/index/` and `talon/x/`, and with `--all` also `packages/` and the build-cache dirs (`compat-<id>/`, `nightly-<tag>/`, `debug-<sha>/`). It never removes a toolchain, a tool, `talon/compat.db` or `talon/projects.json`. It shows the size to free and asks for confirmation (default yes). With no person it removes with no prompt. `--dry-run` prints what it would remove. After the manager review (Q2) a run that removes takes the GC lock `talon/gc` with `Wait` around the `delete!`. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-029-revert/before/` (with `NEW.txt`).

`tln cache list` and `tln cache dir` (R-CM17, the plan row title) are not in this slice: the design does not say what they print or do (question Q1, section 8). The command words are already known to `Args`, so they still give `command 'cache list' is not built yet`.

The answers of the user (`docs/slices/ANSWERS.md`, `PLAN-P1.md`) that bind this slice:

| Answer | Effect here |
| --- | --- |
| `--json --quiet`: the JSON envelope only (slice 007 D4) | `CacheClean` uses `Common.shown_fx`. L2 run 4 has `--dry-run --json --quiet`: stdout has the envelope, stderr is empty. |
| The other answers | They are for commands that edit a header or choose a compiler. `clean` does neither. |

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-GC12 (`clean` removes `talon/index/` and `talon/x/`, and keeps all else) | `Clean.asks`, `CacheClean.run!` | L0 `clean` row 2. L2 `cn1-clean` runs 1, 7 (index and x only), 8, 9. L3 `cl1-real` parts 1, 3, 8, `cl2-prompt-tty` part 2 |
| R-GC13 (`--all`: also `packages/`, `compat-<id>/`, `nightly-<tag>/`, `debug-<sha>/`; keeps toolchains, tools, `compat.db`, `projects.json`) | `Clean.asks`, `Gc.is_build_name`, `CacheClean` (the one `list_dirs!` of `roots.build`) | L0 `clean` row 2 (names, the dir test, the sort, the build root). L2 runs 2, 3, 9, 12 (the second home: the cache root is the build root). L3 `cl1-real` parts 2, 4, 6 (`ROC_CACHE_DIR`), `cl2-prompt-tty` part 3 |
| R-GC14, first sentence (never a toolchain or a tool) | `Clean.asks` has no such path | The tree diffs of all deep cases: `toolchains/`, `tools.json`, `bin/`, `config.toml`, `projects.json`, the app install stay. L3 `cl1-real` part 4 lists what is left. |
| R-GC14, second sentence (the size to free, a confirmation, the interactive default is yes) | `Clean.found`, `Clean.freed`, `Consent.cache_clean`, `Prompt.ask!` | L0 `clean` rows 3, 4, `consent` row 12. L2 runs 6, 7 (the question has the count and the size, the answer `n` and Enter). L3 `cl2-prompt-tty` parts 1, 2 |
| R-GC14, third sentence (non-interactive: removes with no prompt) | `Prompt.decide` (`Default` kind), `CacheClean.run!` | L0 `consent` row 12. L2 run 9 (`--json`, a terminal), 12 (CI). L3 `cl1-real` parts 3, 4, 8 (`TALON_INTERACTIVE=1` with no terminal: R-NR1) |
| R-GC14, fourth sentence (`--dry-run` prints what it would remove and removes nothing) | `Clean.report`, `CacheClean.run!` | L0 `clean` row 4. L2 runs 1 to 4 (no `tty`, no `ask`, no `delete` call). L3 `cl1-real` parts 1, 2 |
| R-NI7 (prompt "confirm the removal and its size": interactive default Yes, kind Default, no answer flag) | `Consent.cache_clean` | L0 `consent` row 12. L2 runs 6, 7, 11, 13. L3 `cl2-prompt-tty` |
| R-NR3 (a destructive prompt is `Default` only when the command names what it removes) | `Consent.cache_clean` (`kind: Default`) | L0 `consent` row 12 (the kind) |
| R-CM17 (`tln cache clean`, no operand) | `Clean.read`, `Run.tln!` | L0 `clean` row 1. L2 run 5 (exit 2). L3 `cl1-real` part 7 |
| R-NM6, R-NM8 (the answer line with no prompt, `--yes` is Yes) | `Prompt.ask!` | L2 runs 9, 12, 13 (`--yes` in a terminal: no `tty`, no `ask`). L3 `cl1-real` parts 3, 4, 8, `cl2-prompt-tty` part 3 |
| R-CC3, R-CC5, R-CC10 (the removal runs under the GC lock with `Wait`, after the prompt; the waiting line; the lock is released) | `CacheClean.run!` (`Fx.locked!`) | L2 `cn1-clean` runs 7, 9, 12 (busy), 13 (calls), runs 1 to 6, 8, 10, 11 (no lock). L3 `cl1-real` part 3 (no lock dir is left) |
| R-J3, R-OUT2, R-OUT4 (the text and `data`) | `Clean.report`, `Clean.data` | L0 `clean` rows 4, 5. L2 runs 3, 4, 9. L3 `cl1-real` part 4 |
| R-LY1 (`ROC_CACHE_DIR` is the build root, `roots.pkgs` ignores it) | `Roots.from_env`, `CacheClean` | L2 runs 2, 13. L3 `cl1-real` part 6 |

Rules of other slices that the cases touch: R-FL4 (the answer line is shown with `--quiet`), R-CC3 (a lock only through `with_lock!`, no `ask!` under it), R-CC5 (the waiting line), R-CC10 (the GC lock `talon/gc`), R-NR1 (no prompt without a terminal), R-NM4 (a `Default` prompt gets its default with no person), R-E1 (exit 2 for a usage failure), R-EC (exit 18 for a failure of the environment).

`MISSING=1 scripts/rules.sh R-GC R-CM R-NI R-NR` lists, for the ids of this slice, none. It lists R-GC7 (slice 049) and ids of other slices.

## 2. Flow of `tln cache clean` (the calls that the L2 case fixes)

The doc of `cli/lib/CacheClean.roc` has the same table.

| Step | Calls | Rule |
| --- | --- | --- |
| 1 | `Clean.read(args)` (no `Fx` call). A failure: `Common.failed!`. | R-CM17 |
| 2 | `env_all!`, `Roots.from_env`. No `clock!` call. | R-GC12 |
| 3 | `--all` only: one `list_dirs!` of `roots.build`, `Gc.entries`. | R-GC13 |
| 4 | `Clean.asks`, one `tree_info!` of all paths (also in a dry run), `Clean.found`. | R-GC12, R-GC13 |
| 5 | No path exists: the outcome `Nothing`, the end (no prompt, no delete). A dry run: `DryRun`, the end. | R-GC14 |
| 6 | `Mode.from_env`, `Prompt.ask!` with `Consent.cache_clean`. `tty!` only when the mode is not known and no `--yes`. `ask!` only for a person. | R-NI7, R-NR3, R-NM6 |
| 7 | No: the outcome `Declined`, exit 0, no lock. Yes: `Fx.locked!` (`Wait`) on `Roots.item(roots, Gc)` (`talon/gc`, after the prompt: R-CC3 point 5), in it one `delete!` of all items, then `Clean.check` (a refused path is exit 18). A busy lock prints `waiting for another tln: gc` and waits. A dry run, a declined run and a run with no item take no lock. | R-GC14, R-CC3, R-CC5, R-CC10 |
| 8 | `Clean.report` on stdout (`--quiet` hides it, `--json` moves it to stderr), with `--json` the envelope. | R-OUT2, R-J3 |

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Clean.roc` | 77 | Stubs from the test agent | New pure module. 6 public functions and 3 types, all bodies `crash "todo"`. The docs have the contract. |
| `cli/lib/CacheClean.roc` | 22 | Same | New command module. `run!` is `crash "todo"`. The doc has the table of the calls. |
| `cli/lib/Consent.roc` | +12 | Test agent, stub | `Consent.cache_clean` is `crash "todo"`. The doc has the texts. |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +3, +2 | Test agent | The dispatch for `["cache", "clean"]`, and `CacheClean` and `Clean` in the exposes list |
| `tests/unit/clean.roc` | 177 | Test agent | 6 `expect`s, red |
| `tests/unit/consent.roc` | +30 | Test agent | 1 new `expect` (row 12), red. The old `expect`s are not changed. |
| `tests/commands/FakeFx.roc` | +14 (`fx/delete`, `fx/treeinfo`) | Test agent | The file `fx/delete` (`denied <suffix>`): a `delete!` path with this suffix gives `Denied` and stays. The doc table has the row. Needed for the exit 18 case. |
| `tests/commands/cases/clean/cn1-clean/` | 13 runs, 30 given files | Test agent | New L2 case, red |
| `tests/scenarios/cache/cl1-real/` | cmd 43 (8 parts), 22 given files | Test agent | New L3 case, red |
| `tests/scenarios/cache/cl2-prompt-tty/` | cmd 16 (3 parts), 15 given files, tag `tty` | Test agent | New L3 case with a pseudo terminal, red |
| `research/slice-029-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `stubs/` (the 4 files that differ), `mutate.py`, `mk-fixtures.py`, `mk-fixtures-l3.py`, `results.md`, `mutate-run-*.log`, `green.log`, `red.log` |

`Fx`, `RealFx`, `RealFiles`, `fxprobe`, `Gc` (the stub copy is the old file), `Toolchain`, `tests/commands/main.roc`, `tests/commands/run.sh`, `tests/run.sh`, `scripts/test.sh`, `tests/selftest.sh` are not changed. There is no new `Fx` call: `tree_info!`, `list_dirs!`, `delete!` and `ask!` exist.

The private reference was deleted after the review (`research/slice-029-revert/reference/` and `swap.sh`). The stubs are in `cli/` and in `research/slice-029-revert/stubs/`.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Clean.Plan` | `{ all : Bool, dry_run : Bool }` | R-GC13, R-GC14 |
| `Clean.Outcome` | `[Nothing, DryRun, Declined, Removed]` | R-GC14 |
| `Clean.Done` | `{ all : Bool, outcome : Clean.Outcome, paths : List(Str), sizes : List(Gc.Sized) }` | R-OUT2 |
| `Clean.read` | `Args -> Try(Clean.Plan, Fail)` | R-CM17 |
| `Clean.asks` | `{ roots : Roots, all : Bool, builds : List({ path : Str, is_dir : Bool, mtime : U64 }) } -> List(Gc.Ask)` | R-GC12, R-GC13 |
| `Clean.found` | `Gc.Measured -> { paths : List(Str), sizes : List(Gc.Sized) }` | R-GC14 |
| `Clean.freed` | `Clean.Done -> U64` | R-GC14 |
| `Clean.report`, `Clean.data` | `Clean.Done -> List(Str)`, `Clean.Done -> JsonDoc` | R-OUT2, R-J3 |
| `Clean.check` | `{ paths : List(Str), results : List(Try({}, [NotFound, Denied, Other(Str)])) } -> Try({}, Fail)` | R-GC14 (Q4) |
| `Consent.cache_clean` | `{ count : U64, size : U64 } -> Prompt` | R-NI7, R-NR3 |
| `CacheClean.run!` | `Fx, Args => I32` | R-CM17 |

`Gc.Ask`, `Gc.Measured`, `Gc.Sized`, `Gc.sizes`, `Gc.entries` and `Toolchain.size_text` are reused. The code agent makes `Gc.is_build_name` public (it is private today) and uses it in `Clean.asks`: no copy of the name rule (the reference does this).

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/clean.roc` 1 (`read`) | No operand, `--all`, `--dry-run`, both, the global flags change nothing, 1 and 2 operands are `Usage` (exit 2) | R-CM17, R-GC13, R-GC14 |
| L0 | 2 (`asks`) | The paths: no `--all` gives the index and x. `--all` adds the packages dir and the build dirs of the listing: the 3 names, one more character, a dir, sorted, the compat dir of an installed compiler too. Without `ROC_CACHE_DIR` the cache root is the build root and `packages`, `toolchains`, `talon` are not asked. `builds` is ignored with no `--all`. | R-GC12, R-GC13, R-LY1 |
| L0 | 3 (`found`) | `NotFound` is no item. `Denied` and `Other` are items with no size. The sizes have the `Ok` rows. All missing gives no item. | R-GC14 |
| L0 | 4 (`report`, `freed`) | The 4 outcomes. The size suffix, no suffix for an item with no size. The total line only when one item has a size. `would` words and the last line of a dry run. `freed` is 0 for `Nothing` and `Declined`. | R-GC14, R-OUT2 |
| L0 | 5 (`data`) | The keys and their order, `bytes` null for an item with no size, the `Declined` run lists the items and has `removed` false and `freed` 0, `Nothing` has no item. | R-J3, R-OUT4 |
| L0 | 6 (`check`) | All `Ok`. `NotFound` is not a failure. The first other error is exit 18 with the path and the error. No path. | R-GC14 (Q4) |
| L0 | `tests/unit/consent.roc` 13 (`cache_clean`) | The id, the question for 1, 2 and 5 dirs (the count and the size), the subject, the default Yes, the kind `Default`, the answer lines, the text with `[Y/n]`. `decide`: no person gives `Use(Yes)` (no stop), `--yes` gives Yes, a person is asked, the unknown terminal gives `NeedTty`. | R-NI7, R-NR2, R-NR3, R-NM4, R-NM8, R-GC14 |
| L2 | `clean/cn1-clean` (13 runs) | 1 `--dry-run`. 2 `--all --dry-run`: one `list_dirs`, one `tree_info`, the whole list. 3 `--all --dry-run --json`. 4 `--dry-run --json --quiet`: envelope only. 5 an operand: exit 2, one call. 6 a terminal, `--all`, answer `n`: `tty`, `ask`, no delete. 7 a terminal, answer Enter: one `delete` of index and x. 8 again: `nothing to remove`, no `list_dirs`. 9 `--all --json` in a terminal: no `tty`, no `ask`, the answer line, one `delete` of packages and 4 build dirs. 10 `--all` again: `nothing to remove`. 11 (home `h4`) an item that `tree_info!` cannot measure: the question counts 2 dirs, answer `n`. 12 a delete that the fake refuses: exit 18, no report. 13 the second home, no `ROC_CACHE_DIR`, `--all --yes --quiet` in a terminal: no `tty`, no `ask`. Runs 7, 9, 11, 12 have `lock ... nowait: held`, the `delete`, `unlock`. Run 12 has a busy lock (`fx/locks`): `lock nowait: busy`, the line `waiting for another tln: gc` on stderr, `lock wait: held`, the delete, `unlock` also after the failure. Runs 1 to 6, 8, 10 have no lock call. | R-GC12, R-GC13, R-GC14, R-NI7, R-NR3, R-NM6, R-NM8, R-CM17, R-J3, R-OUT4, R-LY1 |
| L3 | `cache/cl1-real` (8 parts) | The real binary and `Fx`. 1, 2 dry runs (the file list is the same). 3 no flag in CI: the answer line, index and x go. 4 `--all --json`: packages and the build dirs go, all else is listed as left. 5 nothing to remove. 6 `ROC_CACHE_DIR` is another dir: only its build dirs go. 7 an operand: exit 2. 8 `TALON_INTERACTIVE=1` with no terminal: no prompt, removes. | R-GC12, R-GC13, R-GC14, R-NI7, R-NR1, R-CM17, R-J3, R-LY1 |
| L3 | `cache/cl2-prompt-tty` (3 parts) | A pseudo terminal. 1 `--all`, the answer `n`: the question shows the count, the size and `[Y/n]`, nothing is removed. 2 Enter: the default Yes, index and x go. 3 `--all --yes`: no question. | R-NI7, R-NR2, R-NR3, R-NM8, R-GC12, R-GC13, R-GC14 |

Count: 7 L0 `expect`s (6 in the new file, 1 new in `consent.roc`), 1 L2 case (13 runs), 2 L3 cases (8 and 3 parts). No selftest row. The budget of the manager is 5 to 20 L0 and 2 to 6 deep: this is 7 and 3.

## 6. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stdout, a run | One line for each item in the order of `asks`: `removed <path>` with the suffix ` (<size>)` when the item has a size. Then `freed <size>` when one item has a size. The sizes are `Toolchain.size_text`. |
| stdout, a dry run | The same with `would remove` and `would free <size>`, then the last line `dry run: nothing was removed`. |
| stdout, nothing | `nothing to remove` (also with `--dry-run`) |
| stdout, the answer No | `nothing was removed` |
| The prompt (stderr, a person) | `Remove <n> cache dirs, <size>? [Y/n] ` (`dir` for 1) |
| The answer line (stderr, no person, `--yes`, R-NM6) | `removing <n> cache dirs (<size>)` |
| `--json` `data` | `{"dry_run","all","removed","items":[{"path","bytes"}],"freed"}`. `dry_run` is true for a dry run. `removed` is true when the items were removed. `bytes` is null for an item with no size. `freed` is the sum of the sizes (0 when nothing is removed and it is no dry run). The text goes to stderr. |
| Errors | `tln: error[usage]: tln cache clean takes no operand, got <n>` (exit 2). `tln: error[environment]: cannot remove <path>: <error>` (exit 18, `<error>` as `Str.inspect` writes it: `Denied`, `Other("text")`). A bad `HOME` and a bad `TALON_NOW` do not apply (no `TALON_NOW`: no clock). |

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `cache clean` takes no operand: 1 or more is `Usage` (exit 2), as `cache gc`. | An operand that selects a part (`clean index`) |
| D2 | `clean` removes the dirs themselves (`talon/index`, `talon/x`, with `--all` `packages`, each build-cache dir), with one `delete!`. The design says "removes `talon/index/`" (question Q3). | Remove only the content and keep the dir |
| D3 | Only a path that exists is an item. A missing path (`NotFound`) is not listed and not removed. When no path exists the result is `nothing to remove`, exit 0, with no prompt, also in a dry run. | A prompt for 0 items. An error. |
| D4 | The order of the items: `talon/index`, `talon/x`, `packages`, the build-cache dirs in byte order of the path. | |
| D5 | The build-cache dirs are the dirs of `roots.build` (R-LY1, `ROC_CACHE_DIR`, else the cache root) with the name rule of `Gc.candidates`. They are found by one `list_dirs!`, only with `--all`. The compat dir of an installed compiler is in the list (R-GC13: "`compat-<id>/`" with no condition; the toolchain stays). | Skip the compat dir of an installed compiler. Also list `roots.cache` when `ROC_CACHE_DIR` is set. |
| D6 | The sizes come from one `tree_info!` call for all paths, also in a dry run. An item that `tree_info!` cannot read (`Denied`, `Other`) is still an item with no size, and `clean` still tries to remove it (question Q5). | Leave the item out. Stop with exit 18. |
| D7 | The prompt comes after the sizes and before the `delete!`. It shows the count and the total size, not the item list (the dry run shows the list first, R-NI7). The kind is `Default` (R-NR3), the interactive default is Yes (R-NI7), there is no answer flag, `--yes` is Yes (R-NM8). With no person (CI, `--json`, no terminal) the answer is Yes, the answer line goes to stderr (R-NM6, R-GC14). | An item list in the prompt. A flag `--no-confirm`. |
| D8 | The answer No: exit 0, stdout `nothing was removed`, no `delete!`. | Exit 13 (that is for a `Required` prompt) |
| D9 | `--dry-run` never prompts, so it never calls `tty!` and `ask!`. | A prompt that shows the list and then says "dry run" |
| D10 | No `clock!` call (no age rule). The GC lock `talon/gc` with `Wait` around the `delete!` only, taken after the prompt (answer of the manager to Q2). | No lock. The lock with `NoWait`. A lock around the prompt (R-CC3 point 5). |
| D11 | One `delete!` call for all items, in the order of the items. `NotFound` in its answer is not a failure. The first other error is exit 18 (`Clean.check`, question Q4). The other items were tried already. No report is printed for a failure. | Ignore the answer, as `cache gc` does (the next run asks again) |
| D12 | `--quiet` hides stdout. `--json` moves the text to stderr. `--json --quiet`: envelope only (answer of slice 007 D4). The answer line (R-NM6) is shown with `--quiet` (R-FL4, `Prompt.ask!`). | |
| D13 | `FakeFx` gets `fx/delete` (`denied <suffix>`) so that L2 can show exit 18. | A new real `Fx` call. No L2 case for exit 18. |
| D14 | `data.freed` is the sum of the sizes also in a dry run (as `cache gc`: "would free"). It is 0 for `Nothing` and `Declined`. | A separate key `would_free` |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| `tln cache list`, `tln cache dir` (R-CM17, the plan row title) | The design names the words only. It does not say what they print (question Q1). Not tested, still "not built yet". |
| R-GC7 (`talon/x` entries by age) | Slice 049. `clean` removes `talon/x` whole, with no age. |
| `Denied` from the real `delete!`, `Denied` from the real `tree_info!` | A `chmod 000` dir is not a stable test (a root user can read it). L0 checks `found` and `check`, L2 shows exit 18 with the fake. |
| An invalid reply to the prompt (it asks again), the end of input | `Prompt.ask!`, tested in slice 001 (`prompt` entry) |
| The size of an item with no size (`Denied`) in the prompt | The count and the size are `found.paths.len()` and `freed`. A mutation of the count to `sizes.len()` gives the same output in every deep case (all items have a size there). L0 `found` has the `Denied` item. |
| Windows (`rename`, paths) | The Windows CI job |
| A `tln` or `roc` process that uses `packages/` or a build cache while `clean --all` removes it | Design gap G1. `clean` has no age rule by design (R-GC14), and its lock is the GC lock only. |
| A real second process that holds `talon/gc.lock` while `clean` waits | The L2 fake shows the waiting line and the calls. A real wait has no stable L3 test (`CASE_TIMEOUT`). The lock contract is the L3 suite of slice 002. |

## 9. Questions (TW17)

The tests fix the default of each question. A different answer changes the rows that the table names.

| # | Question | Default (tested) | Other option, and the rows that change |
| --- | --- | --- | --- |
| Q1 | What do `tln cache list` and `tln cache dir` do? R-CM17 names them and gives no rule. | Not built (no test, no stub). | A proposal for the manager: `dir` prints the cache root `roots.cache` and a line end, `--json` has `{"path"}`. `list` prints what `clean --all` would remove (the same items and sizes, so one `Clean.asks` and one `tree_info!`), with no prompt and no removal. A new slice (about 60 lines) after the answer. |
| Q2 | Does `clean` take the GC lock (R-CC10, `talon/gc`) so that it does not run with `cache gc`? | Closed (manager, 2026-10-23): yes, with `Wait`, around the `delete!`, after the prompt (D10). Tested. | No lock (the first test default). |
| Q3 | Remove the dirs `talon/index`, `talon/x`, `packages` themselves, or the content of each? | The dir itself (D2). `roc` and `tln` make a missing dir when they need it (R-CR1, R-CC11): unknown for the real `roc`. | The content only. Rows: L2 `cn1-clean` (the `delete` paths, `tree.diff` is the same), L3 `cl1-real` (the file lists are the same, the dir lists differ). |
| Q4 | What does `clean` do when a path cannot be removed (`Denied`, `Other`)? | Exit 18 with the path (D11). | Ignore it, as `cache gc` does. Rows: L0 `clean` 6, L2 run 12. |
| Q5 | An item that cannot be measured (`Denied`, `Other`): remove it, or leave it? | Remove it, with no size (D6). | Leave it out of the list. Rows: L0 `clean` 3, 4, 5. |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-GC14 says `clean` has no age rule, and R-CC10 gives the GC rules only (lock, last day). `clean --all` can remove `packages/<hash>/` or a build cache that a running `roc` build uses. R-CC10 says that one build fails once and the next run fetches again, for GC. Nothing says the same for `clean`. |
| G2 | R-NI7 has no answer flag and R-NM6 says that a no-person answer prints a line. The text of the line is not given (`kept 3 tools, removed 5 compilers (1.2 GB)` is an example of another prompt). Proposal in section 6. |
| G3 | R-GC13 keeps "toolchains" but removes `compat-<id>/` of an installed compiler. A build then starts with an empty cache. This is the cost of `--all`, and the design does not say it. |
| G4 | R-CM17 names `list` and `dir` and no rule gives their behavior (Q1). |
| G5 | R-GC12 and R-GC13 name dirs. They do not say if the dir stays (Q3). |

## 11. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| A `sh -e` cmd stops at `grep` with no match | The L3 `snap` function ends with `|| true` |
| `Prompt` has a closure field (`answer_line`), so `==` on a `Prompt` does not compile | The `consent` row checks the fields one by one, never the record |
| The tty runner merges stdout and stderr | The prompt shows in `expect/stdout`, the typed answer does not (as slice 025) |

No new limit of the compiler.

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23), log `research/slice-029-revert/red.log`. The old tests all pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files | pass | |
| L0 `tests/unit/clean.roc` | red: 6 of 6 `expect`s fail | `Roc application crashed with this message: todo` |
| L0 `tests/unit/consent.roc` | red: 1 of 12 fails (row 12) | `todo` (`Consent.cache_clean`) |
| L2 old cases (67) | pass | |
| L2 `clean/cn1-clean` | red | `[ROC CRASHED] todo` (the test app writes no exit file) |
| L3 old cases (51, 1 skipped) | pass | |
| L3 `cache/cl1-real`, `cache/cl2-prompt-tty` | red | `[ROC CRASHED] todo` for each `tln cache clean`: the exit code is 1, the files are not removed, `tree.diff` has the removals that did not happen |
| selftest | pass | |

```text
tests/unit/clean.roc: FAILED   (6 failed: Roc application crashed with this message: todo)
tests/unit/consent.roc: FAILED (1 failed: row 12, todo)
FAIL clean/cn1-clean            the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL cache/cl1-real             stdout differs: +[ROC CRASHED] todo, tree.diff has the removals that did not happen
FAIL cache/cl2-prompt-tty       stdout differs: +[ROC CRASHED] todo
```

Times on the stub tree (warm cache, run again after the review, no reference left): check 0.9 s, fmt 0.1 s, l0 5.1 s, l2 1.3 s, l3 9.4 s, selftest 7.2 s. With the reference (`green.log`): check 0.9, fmt 0.1, l0 5.2, l2 1.3, l3 9.4, selftest 7.2, exit 0, no `WARN` line. No budget is at risk.

## 13. Check against the design (TW21)

The expected files of the L2 case and of the 2 L3 cases were made by the private reference (deleted) and read by eye against the design. With the reference all 7 `expect`s, the L2 case and the 2 L3 cases pass.

| File | What was checked |
| --- | --- |
| `clean/cn1-clean/expect/calls.log` | The order against the table of section 2. Runs 1 to 4 have `args`, `env_all`, `tree_info` (and `list_dirs` with `--all`), and no `tty`, `ask`, `delete`. Run 5 has `args` only. Runs 6 and 7 have `tty` and `ask`, run 6 no `delete`, run 7 one `delete` with index and x. Run 9 has no `tty` (the mode is not asked: `--json`) and no `ask`. Runs 8 and 10 end after `tree_info`. Run 12 has the `delete` and ends. Run 13 has no `tty` (`--yes`). No `clock`. Runs 7, 9, 11, 12 have `lock <item> nowait: held`, `delete`, `unlock`, the lock after the `ask` of run 7. Run 12 has `nowait: busy` then `wait: held`. No other run has a lock. |
| `clean/cn1-clean/expect/stdout`, `stderr` | The texts of section 6. The `--json` runs have the text in `stderr`. The `--quiet` run has an empty stdout. The answer lines are in `stderr` in the order of the runs. The error line of run 12 names `$HOME/h3/.cache/roc/talon/x`. |
| `clean/cn1-clean/expect/tree.diff` | Only the removed files: index and x of the first home, packages, the 4 build dirs, the h2 index and compat-ten, the h3 index. `toolchains/`, `tools.json`, `bin/`, `config.toml`, `projects.json`, `other-old`, `compat-file` and the h3 `x` dir are not in the diff, so they stay. |
| `cache/cl1-real/expect/stdout` | The sizes are the real sizes of the fixture files. Part 4 lists what is left: the toolchain, tools, settings, the app, `compat.db`, `projects.json`, `compat-file`, the other build root. Part 6 removes only the build dirs of `roc-builds`, `compat-zzzzzzz` of the cache root stays. Part 8 removes with no prompt. |
| `cache/cl1-real/expect/stderr` | The answer lines (parts 3, 4, 6, 8), the text of the `--json` run, the usage line (part 7). |
| `cache/cl2-prompt-tty/expect/stdout` | The question with `[Y/n]`, the count and the size. Part 1 stays whole. Part 2 removes index and x. Part 3 has the answer line and no question. |

## 14. Revert check (TW12)

Method: the private reference makes all new tests pass. `research/slice-029-revert/mutate.py` puts the reference in place, applies one change, runs `roc check cli/main.roc`, then the layers of the mutation in order (`clean.roc` and `consent.roc`; L2 `clean/`; L3 `cache/cl`). Each run is one after the other. No full sweep. Result: 54 mutations. 53 caught. 1 is an equal change (W15). After the answer to Q2 the mutations K01 to K04 (no lock, the lock of another item, the prompt under the lock, a dry run takes the lock) and W02, W07, W11, W13 again were run and caught (`mutate-run-5.log`). `results.md` and `mutate-run-1.log` to `-5.log` have the list. The reference, `swap.sh` and the path of `mutate.py` to the reference are deleted (the review). W12 was not caught at first (no run with `--json --quiet`): the L2 run 4 was added, and W12 is caught. 6 mutations (L01 to L06) run only the L3 layer: L3 catches them without L2.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Clean.read` (the flags, the count in the text) | C01 to C03 | L0 `clean` 1 |
| `Clean.asks` (order, packages, the dir test, the sort, `--all` gate, the 3 names, the x path, `Gc.is_build_name`) | C04 to C10, G01 | L0 `clean` 2 |
| `Clean.found`, `freed` (`NotFound`, `Denied`, `Declined`, the sum) | C11 to C14 | L0 `clean` 3, 4 |
| `Clean.report`, `data` (the verb, the last line, the total gate, the `Declined` line, the `would free` word, `removed`, `null`) | C15 to C21 | L0 `clean` 4, 5 |
| `Clean.check` (`NotFound`, the kind, the first error) | C22 to C24 | L0 `clean` 6 |
| `Consent.cache_clean` (the default, the kind, the size in the question, the plural) | C25 to C28 | L0 `consent` 13 |
| `CacheClean` (the build root, the dry run, nothing, the mode for `--json`, `--yes`, `shown_fx`, the delete order, the answer, the size in the prompt, the listing gate, the result of `check`, `--json --quiet`, `Declined`, the `x` path, `ROC_CACHE_DIR`) | W01 to W16 | L2 (W01, W02, W05, W08, W13, W16 also L3) |
| `CacheClean` lock (Q2): none, another item, around the prompt, in a dry run | K01 to K04 | L2 |
| `CacheClean` through L3 only | L01 to L06 | L3 (build root, answer, `ROC_CACHE_DIR`, `--yes`, `Declined`, dry run) |

| Id | Mutation | Verdict |
| --- | --- | --- |
| W15 | `quiet: Bool.True` in the `Prompt.ask!` call | Equal change. `Out.show(quiet, Answer)` shows an answer line for any `quiet` (R-FL4), so no output changes. Not a test gap. |

Not mutated: the count in the prompt (`found.paths.len()` against `sizes.len()`: no case has an item with no size, section 8), the text of `TALON_NOW` (not used).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `cli/lib/Clean.roc` have the contract of each function. The doc of `cli/lib/CacheClean.roc` has the table of the calls. The `calls.log` of the L2 case fixes the order and the number of calls. |
| N2 | Reuse: `Gc.entries` (the listing of `roots.build`), `Gc.sizes`, `Gc.Ask`, `Gc.Measured`, `Gc.Sized`, `Toolchain.size_text`, `Prompt.ask!`, `Mode.from_env`, `Common.shown_fx`, `Common.failed!`, `Out.json_ok`, `Text.sorted_unique`, `Text.last_segment`, `Text.join`. Make `Gc.is_build_name` public (move it into the type module block, as the reference does). |
| N3 | `Consent.cache_clean`: the texts are in its doc. `plural` is private in `Consent` and can be used there. |
| N4 | A local variable must not have the name of a method of its type module (slice 020 limit). A local named `packages` or `app` does not compile. |
| N5 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

| Item | Text |
| --- | --- |
| D1 to D14, section 6 (output), Q3, Q4, Q5 | Accepted, with the defaults. G3 is what R-GC13 says (`compat-<id>/` is in the list). |
| Q1 | `cache list` and `cache dir` go to a new small slice 029b (the manager adds it to `PLAN-P1.md` with the proposal of Q1). |
| Q2 | Change. `clean` (not `--dry-run`) takes the `talon/gc` lock with `Wait`, as the explicit `roc rm` waits for its lock, so it never deletes while a GC runs (a GC that starts later finds the lock busy and exits 0, R-CC10). Show the `waiting for another tln` line in one L2 run with a busy lock, and the lock calls in the other runs. |
| Work asked | Update the private reference, run the mutations of the changed rows one after another and record them. Set the status to `code`. Delete the reference. Confirm the red state with `scripts/test.sh`. |

Answers of the test agent:

| Item | Answer |
| --- | --- |
| Lock | `CacheClean` has `Fx.locked!` (`Wait`) on `Roots.item(roots, Gc)` around the one `delete!` and `Clean.check`, after the prompt (R-CC3 point 5: no `ask!` under a lock). A declined run, a dry run and a run with no item take no lock. The doc of `CacheClean` and `Clean` and the section 2 table have it. |
| L2 | `cn1-clean`: runs 7, 9, 12, 13 have `lock ... nowait: held`, `delete`, `unlock`. Run 12 (home `h3`) has a busy `talon/gc` (`fx/locks`): `nowait: busy`, `waiting for another tln: gc` on stderr, `wait: held`, the refused delete (exit 18), `unlock`. |
| L3 | `cl1-real` part 3 prints the number of `*.lock` dirs left (0). A real wait has no stable L3 test. |
| Mutations | K01 to K04 and W02, W07, W11, W13 again: all caught (`mutate-run-5.log`, `results.md`). |
| Reference | Deleted, with `swap.sh`. `scripts/test.sh` on the stubs: l0 `clean.roc` 6 of 6 and `consent.roc` 1 of 12 fail (todo), l2 `clean/cn1-clean` and l3 `cache/cl1-real` and `cache/cl2-prompt-tty` fail (`[ROC CRASHED] todo`), all old tests pass (`red.log`). |

## Code result (code agent)

Result of `scripts/test.sh`: exit 0, no WARN (`research/slice-029-revert/agent-final.log`): check 0.9 s, fmt 0.1 s, l0 5.1 s, l2 1.3 s, l3 9.4 s, selftest 7.2 s. `OPT=speed scripts/test.sh`: exit 0 (l2 79.8 s, `agent-speed.log`). `roc check`: 0 errors, 0 warnings.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Clean.roc` | 144 | The 6 bodies. Private helpers: `flag_set`, `lines` (item lines and total line, one source for `Removed` and `DryRun`), `size_suffix`, `bytes_of`. `freed` is the one source of the total in `report`, `data` and the prompt. |
| `cli/lib/CacheClean.roc` | 89 | `run!`, private `clean_flow!` (steps 2 to 7), `remove!` (`Fx.locked!` on `Roots.item(roots, Gc)`, one `delete!`, `Clean.check`), `print!` (step 8, as `CacheGc.print!`). |
| `cli/lib/Consent.roc` | 376 | `cache_clean` body (uses private `plural` and `Toolchain.size_text`). |
| `cli/lib/Gc.roc` | 333 | `is_build_name` moved into the type module block and public (note N2). `candidates` calls `Gc.is_build_name`. No other change. |

No new `Fx` call. No change to a public signature.

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| The `Done` record that the prompt step uses | `done` is made once with the outcome `Removed`. `Clean.freed(done)` gives the size for the prompt. The outcome is then set with `{ ..done, outcome: ... }`. | A second size function for the prompt |
| `Clean.check` | A `map2` of paths and results to `Ok(text)` or `Err(Skip)`, then `keep_oks`, then the first | A `find_first` on a tuple with a nested `Err` pattern (partial pattern limit) |
| `Clean.asks` sort | `Text.sorted_unique` of the build dirs only (the fixed first 3 paths keep their order) | A sort of the whole list |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

Questions (TW17): none. Compiler limits met: none new.

## Verify results (revert check, TW12)

`research/slice-029-revert/agent-mutate.py` copies `code-final/` into `cli/` before each mutation, makes one change, runs `roc check cli/main.roc`, then the layers of the mutation in order (l0 `clean.roc` and `consent.roc`; l2 `clean/`; l3 `cache/cl`). The first failing layer ends the run. One run, one mutation after another, in the foreground (`agent-run.log`, `agent-results.md`). Result: caught 49 of 50 (M01 to M29, W01 to W17, K01 to K04). After the run, `cmp` of the 4 changed files against `code-final/` shows no difference, also after the `OPT=speed` run.

| Rule | Mutations | Caught by |
| --- | --- | --- |
| R-CM17, R-GC12, R-GC13, R-GC14 (`Clean.read`, `asks`) | M01 to M10, M28, M29 (flags, count, order, packages, dir test, sort, `--all` gate, name rule, x path, `debug-`, the one more character) | l0 `clean` rows 1, 2 |
| R-GC14 (`found`, `freed`, `report`, `data`, `check`) | M11 to M23 | l0 `clean` rows 3 to 6 |
| R-NI7, R-NR2, R-NR3 (`Consent.cache_clean`) | M24 to M27 | l0 `consent` row 13 |
| R-GC12, R-GC13, R-GC14, R-LY1, R-NM6, R-NM8, R-NR1, R-J3 (`CacheClean`) | W01 to W16 | l2 `clean/cn1-clean` |
| R-CC3, R-CC10 (the GC lock: none, another item, around the prompt, in a dry run) | K01 to K04 | l2 `clean/cn1-clean` |

Not caught:

| Id | Mutation | Verdict |
| --- | --- | --- |
| W17 | `count: found.paths.len()` becomes `found.sizes.len()` in the prompt | Test gap, known and accepted: section 8 ("Out of scope", the size of an item with no size). Every item has a size in L2 and L3, so the count is the same. L0 `found` has the item with no size, but the count is made in `CacheClean`, not in a pure function. A fix needs an L2 run with an item that `tree_info!` cannot measure (`Denied`): a new test, for the test agent. |

W01, W02, W05, W08, W13, W15, W16 and W17 ran L3 after l2. Only W17 passed l2, so only it ran L3, and L3 did not catch it either.

## Gap rows (test agent)

| Id | Gap | Row |
| --- | --- | --- |
| W17 | The prompt count used `found.sizes.len()` in place of `found.paths.len()`: no deep case had an item with no size. | New fake table `fx/treeinfo` (`denied <suffix>`: `tree_info!` gives `Err(Denied)`, in `tests/commands/FakeFx.roc`, with its doc row). New L2 run 11 in `clean/cn1-clean` (home `h4`, a terminal, the third answer `n`): the index has a size and `talon/x` is an item with no size, so the question says `Remove 2 cache dirs, 11 B?`. With W17 applied by hand the run fails (`Remove 1 cache dir, 11 B?` in `calls.log`). The code was put back and `cmp` against `code-final/` shows no difference. |

## Close (manager, 2026-10-23)

The code agent decisions are accepted. W17 is caught by the gap run; W15 is equivalent. `scripts/test.sh` exits 0 with no WARN. `cache list` and `cache dir` are slice 029b. Status: done.
