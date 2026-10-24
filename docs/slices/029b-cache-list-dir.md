# 029b Cache list and cache dir

Phase: P1. Status: done

Slice 029b is `tln cache list` and `tln cache dir` (CLI 6.3, R-CM17). R-CM17 names the two words and no rule says what they print. This slice uses the proposal of the 029 test agent (`docs/slices/029-cache-clean.md`, Q1, accepted at the 029 review): `dir` prints the cache root. `list` prints what `clean --all` would remove, with sizes. Both only show: they remove nothing, take no lock and ask nothing.

Second task of this slice (test infrastructure): `tests/commands/FakeFx.roc` had 868 lines. It is now 4 modules (section 3). No behavior changed.

The slice follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-029b-revert/before/` (with `NEW.txt`).

The answers of the user (`docs/slices/ANSWERS.md`, `PLAN-P1.md`) that bind this slice:

| Answer | Effect here |
| --- | --- |
| `--json --quiet`: the JSON envelope only (slice 007 D4) | Both commands print only the envelope with `--json`, so `--quiet` changes nothing there. |
| The other answers | They are for commands that edit a header or choose a compiler. These two commands do neither. |

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-CM17 (`tln cache list`, `tln cache dir`: no operand, usage exit 2) | `CacheView.read`, `Args.allows` (`--all` is for `clean` only), `Run.tln!` | L0 `cacheview` 1. L2 `cache/cv1-view` runs 6, 10, 11. L3 `cache/cv1-real` parts 7, 8 |
| R-CM17 (what the two commands do: the proposal of 029 Q1, see D1 and D2) | `CacheShow.dir!`, `CacheShow.list!` | L2 runs 1 to 16. L3 parts 1 to 9 |
| R-LY1 (the cache root is `$XDG_CACHE_HOME/roc`, else `~/.cache/roc`. `ROC_CACHE_DIR` is the build root only) | `Roots.from_env`, `CacheShow` | L2 runs 1, 2, 4, 7, 15. L3 parts 1, 3, 6 |
| R-GC12, R-GC13 (the list is the set of `clean --all`: index, x, `packages/`, the build-cache dirs of the build root; never a toolchain, a tool, `compat.db`, `projects.json`) | `Clean.asks` with `all: true`, `Clean.found`, `Gc.entries` | L2 runs 7, 12, 15 (7 paths, h4 and h2). L3 parts 4, 6 |
| R-CC10 (a GC holds the lock `talon/gc`: `list` does not wait) | `CacheShow.list!` has no lock call | L2 run 12 (`fx/locks` is busy for the home h4: no lock call, no waiting line) |
| R-FL4 (`--quiet`: the result of the command is the answer, so it stays) | `CacheShow` (`print!`) | L2 runs 3, 9. L3 parts 3, 6 |
| R-J3, R-OUT2, R-OUT4 (the text and `data`) | `CacheView.dir_report`, `dir_data`, `list_report`, `list_data` | L0 `cacheview` 2, 3, 4. L2 runs 2, 8, 12, 13, 15. L3 parts 2, 5, 9 |

Rules of other slices that the cases touch: R-E1 (exit 2 for a usage failure), R-FL1 (a flag is allowed only for some commands: `list --all`), R-J1, R-J2 (with `--json` stdout has one document), R-GC14 (the item with no size, as in slice 029 Q5).

`MISSING=1 scripts/rules.sh R-CM R-LY R-FL R-J R-OUT` lists no id of this slice. It lists ids of other slices.

## 2. Flow

`CacheShow.dir!` (the doc of `cli/lib/CacheShow.roc` has the same tables):

| Step | Calls | Rule |
| --- | --- | --- |
| 1 | `CacheView.read(args)`. A failure: `Common.failed!` (no `Fx` call except `args!`). | R-CM17 |
| 2 | `env_all!`, `Roots.from_env`. No other call: the dir is not looked at and not made. | R-LY1 |
| 3 | `CacheView.dir_report(roots.cache)` on stdout. With `--json`: only the envelope with `dir_data` (`command` `cache dir`). `--quiet` hides nothing. | R-OUT2, R-J3, R-FL4 |

`CacheShow.list!`:

| Step | Calls | Rule |
| --- | --- | --- |
| 1 | `CacheView.read(args)` | R-CM17 |
| 2 | `env_all!`, `Roots.from_env` | R-LY1 |
| 3 | One `list_dirs!` with the one dir `roots.build`, `Gc.entries` | R-GC13 |
| 4 | `Clean.asks` with `all: true`, one `tree_info!` with all paths, `Clean.found` | R-GC12, R-GC13 |
| 5 | `CacheView.list_report` on stdout. With `--json`: only the envelope with `list_data` (`command` `cache list`). `--quiet` hides nothing. | R-OUT2, R-J3, R-FL4 |

No `clock!`, `tty!`, `ask!`, `lock!`, `delete!`, `make_dirs!`, `write_atomic!` call in any run. The `calls.log` of the L2 case fixes this.

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/CacheView.roc` | 44 | Stubs from the test agent | New pure module. 5 public functions and 1 type, all bodies `crash "todo"`. The docs have the contract. |
| `cli/lib/CacheShow.roc` | 34 | Same | New command module. `dir!` and `list!` are `crash "todo"`. The doc has the tables of the calls. |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +5, +2 | Test agent | The dispatch for `["cache", "dir"]` and `["cache", "list"]`, `CacheShow` and `CacheView` in the exposes list |
| `tests/unit/cacheview.roc` | 61 | Test agent | 4 `expect`s, red |
| `tests/commands/cases/cache/cv1-view/` | 16 runs, 22 given files | Test agent | New L2 case (copy of the `cn1-clean` home, less h3, plus a missing home h5), red |
| `tests/scenarios/cache/cv1-real/` | cmd 41 (9 parts), 28 given files | Test agent | New L3 case (copy of the `cl1-real` home), red |
| `tests/commands/FakeFx.roc` | 868 to 254 | Test agent | The split (below) |
| `tests/commands/FakeBase.roc`, `FakeFiles.roc`, `FakeJobs.roc` | 66, 348, 265 | Test agent | New, the split |
| `research/slice-029b-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `stubs/` (the 2 stub files), `reference/` (private, section 11), `swap.sh`, `mutate.py`, `split-fakefx.py`, `results.md`, `mutate-run-*.log`, `green.log`, `red.log` |

`Fx`, `RealFx`, `Clean`, `Gc`, `Toolchain`, `Roots`, `Args`, `Out`, `Common`, `tests/commands/main.roc`, `tests/commands/run.sh`, `tests/run.sh`, `scripts/test.sh` are not changed. There is no new `Fx` call: `list_dirs!`, `tree_info!` and `env_all!` exist.

### The split of `FakeFx.roc` (infrastructure task)

The old file was over the limit of about 600 lines. The groups are those of `cli/RealFx.roc` (`RealBase`, `RealFiles`, `RealJobs`). Each public function takes the case dir `w` first. `FakeFx.make` only forwards, so the record is the same. The doc table of the `fx/` files and the log lines stays in `FakeFx.roc`, with a table of the modules.

| Module | Lines | Holds |
| --- | --- | --- |
| `FakeFx` | 254 | The record, the doc table, the small calls (`args!`, `env_all!`, `cwd!`, `tty!`, `clock!`, `out!`, `err!`, `lock!`, `unlock!`, `programs!`, `random!`, `platform!`, `path_roc!`, `program_name!`, `ask!`) |
| `FakeFiles` | 348 | `read_files!`, `write_atomic!`, `list_dirs!`, `tree_info!`, `delete!`, `canonical!`, `rename!`, `make_dirs!`, `copy_tree!`, `copy_file!`, `hard_link!`, `sha256_file!` and their helpers |
| `FakeJobs` | 265 | `http_get!`, `spawn_all!`, `probes!`, `exec!` and their helpers (`probe-text`, `hooks`, `ended_of`) |
| `FakeBase` | 66 | The call log, `read_or_empty!`, `append!`, `lines`, `keep_empty`, `exists!`, `write_with_parents!`, `create_item!` |

The function bodies were moved by `research/slice-029b-revert/split-fakefx.py` (from `before/tests/commands/FakeFx.roc`), not typed again. The only text change in a body is the prefix `FakeBase.` on the shared helpers. Check: `roc check tests/commands/main.roc` 0 errors, `roc fmt --check` exit 0, and `scripts/test.sh` runs all 68 old L2 cases with no change (`red.log`: `commands: 68 passed, 1 failed`, the one failure is the new case).

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `CacheView.Listed` | `{ paths : List(Str), sizes : List(Gc.Sized) }` (the value of `Clean.found`) | R-GC13 |
| `CacheView.read` | `Args -> Try({}, Fail)` | R-CM17 |
| `CacheView.dir_report` | `Str -> List(Str)` (the argument is `roots.cache`) | R-OUT2 |
| `CacheView.dir_data` | `Str -> JsonDoc` | R-J3, R-OUT4 |
| `CacheView.list_report` | `CacheView.Listed -> List(Str)` | R-OUT2 |
| `CacheView.list_data` | `CacheView.Listed -> JsonDoc` | R-J3, R-OUT4 |
| `CacheShow.dir!`, `CacheShow.list!` | `Fx, Args => I32` | R-CM17 |

Reuse: `Clean.asks`, `Clean.found`, `Gc.entries`, `Gc.Sized`, `Roots.from_env`, `Toolchain.size_text`, `Common.failed!`, `Out.json_ok`, `JsonDoc`. The code agent makes `Clean.size_suffix` and `Clean.bytes_of` public (they are private today, as `Gc.is_build_name` was in slice 029) and uses them in `CacheView`: no copy.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/cacheview.roc` 1 (`read`) | No operand, the global flags change nothing, 1 and 2 operands are `Usage` (exit 2) with the words of the command in the message | R-CM17 |
| L0 | 2 (`dir_report`, `dir_data`) | One line with a line end. The key `path`. A quote in the path is escaped. | R-OUT2, R-J3, R-OUT4 |
| L0 | 3 (`list_report`) | No item. The order of `paths` (not of `sizes`). An item with size 0 has ` (0 B)` and the total line. An item with no size has no suffix. The total only when one item has a size. The size words. | R-OUT2 |
| L0 | 4 (`list_data`) | The keys and their order. `bytes` null for an item with no size. `total` is the sum. No item gives `[]` and 0. | R-J3, R-OUT4 |
| L2 | `cache/cv1-view` (16 runs) | 1 `dir` with `ROC_CACHE_DIR` set: the cache root, calls `args`, `env_all`. 2 `dir --json`: envelope only. 3 `dir --quiet`: shown. 4 `XDG_CACHE_HOME`. 5 a home with no cache dir: path printed, nothing made. 6 `dir packages`: exit 2, one call. 7 `list`: one `list_dirs`, one `tree_info` with 7 paths, sizes, total. 8 `list --json`. 9 `list --quiet`: shown. 10 `list --all`: exit 2 (Args). 11 `list packages`: exit 2. 12, 13 (home h4) an item that `tree_info!` cannot measure, with a busy `talon/gc` lock: no lock call, no wait line, `bytes` null. 14, 15 (home h5, no cache) `nothing to clean`, and `--json` with `items: []`. 16 (home h2) no `ROC_CACHE_DIR`: the build root is the cache root. | R-CM17, R-LY1, R-GC12, R-GC13, R-CC10, R-FL4, R-J3, R-OUT2, R-OUT4 |
| L3 | `cache/cv1-real` (9 parts) | The real binary and `Fx`. 1 `dir`. 2 `dir --json`, also with another `ROC_CACHE_DIR`. 3 `dir --quiet` with another `ROC_CACHE_DIR`. 4 `list` with the real sizes, no lock dir left. 5 `list --json`. 6 another `ROC_CACHE_DIR` and `--quiet`. 7 an operand for both commands: exit 2. 8 `list --all`: exit 2. 9 after `clean --all`: `nothing to clean` and the empty data. Parts 1 to 8 change no file (`snap` prints nothing). | R-CM17, R-LY1, R-GC13, R-FL4, R-J3, R-OUT2, R-OUT4 |

Count: 4 L0 `expect`s (1 new file), 1 L2 case (16 runs), 1 L3 case (9 parts). The budget of the manager is 5 to 20 L0 and 2 to 6 deep: this is 4 and 2. The slice has 4 pure decisions only (the operand check, 2 texts, 2 `data` values), and 4 `expect`s check all of them. The deep cases check the rest.

## 6. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| `dir`, stdout | `<cache root>` and a line end. Nothing on stderr. |
| `dir --json` `data` | `{"path"}`. Stdout has only the envelope (`command` `cache dir`). No text, also not on stderr. |
| `list`, stdout | One line for each item in the order of `Clean.asks`: `<path> (<size>)` (no suffix for an item with no size). Then `total <size>` when one item has a size. The sizes are `Toolchain.size_text`. |
| `list`, no item | `nothing to clean` |
| `list --json` `data` | `{"items":[{"path","bytes"}],"total"}`. `bytes` is null for an item with no size. `total` is the sum of the sizes (0 with no item). Stdout has only the envelope (`command` `cache list`). No text. |
| Errors | `tln: error[usage]: tln cache dir takes no operand, got <n>` and the same for `cache list` (exit 2). `tln: error[usage]: flag '--all' is not for 'cache list'` (exit 2, the text of `Args`, not new). A bad `HOME` is exit 18 as in all commands that read the roots (not tested here, slice 029 section 7). |

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `dir` prints `roots.cache`, also when `ROC_CACHE_DIR` is set. The cache root holds the Talon items (`talon/`, `toolchains/`, `packages/`) and the build root holds only `compat-<id>/` dirs (R-LY1). Question Q1. | The build root. Both paths. |
| D2 | `list` shows the items that exist of the set of `clean --all` (index, x, `packages/`, build-cache dirs of the build root), in the order of `Clean.asks`, each with its size, the total at the end. One `Clean.asks` and one `tree_info!` (the same call as `clean --all --dry-run`, so the two lists are equal). Question Q2. | The whole cache root with toolchains. A mark for each item that says if `clean` (no `--all`) removes it. |
| D3 | `dir` does not look at the dir and does not make it: it prints the path of a dir that does not exist. | Make the dir. An error when it is missing. |
| D4 | No lock. `list` never waits for `cache gc` or `cache clean`. A size can change while a GC runs: the list shows the sizes at the time of the call. | The GC lock with `NoWait`. |
| D5 | `--quiet` hides nothing: the result is the answer of the command (as `Ls` and `RocManage.list!`). | `--quiet` hides the list (an empty output is of no use). |
| D6 | With `--json` stdout has only the envelope and the human text is not printed at all, also not on stderr (as `RocManage.list!`). `cache clean` and `cache gc` move the text to stderr because they act. | The text on stderr. |
| D7 | No flag of its own. `--all` and `--dry-run` are not allowed (Args already stops them with exit 2). | `list --all`, `list --dry-run` |
| D8 | An item that `tree_info!` cannot measure (`Denied`, `Other`) is listed with no size and is not in the total (as `clean`, 029 Q5). A missing path is no item. | Leave it out. Stop with exit 18. |
| D9 | A missing build root or cache root is not a failure: `list_dirs!` gives `NotFound`, no item, `nothing to clean`, exit 0. | An error |
| D10 | The operand check comes before `env_all!`: a run with an operand has the one call `args`. | The roots first |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| A list of toolchains, tools, `compat.db`, `projects.json` | They are not removed by `clean`, so they are not in the list (Q2). `tln roc list` shows toolchains (slice 024), `tln tool list` shows tools (P1 slice 048). |
| `--dry-run` or `--all` for `list` | Not flags of these commands (D7). `Args` has them in its own tests. |
| A bad `HOME` | `Roots.from_env` is not tested by the design (slice 029 section 7). Same code path as `clean`. |
| `Denied` from the real `tree_info!` or `list_dirs!` | A `chmod 000` dir is not a stable test (a root user can read it). L0 has the item with no size, L2 has it with the fake. |
| Windows paths | The Windows CI job |

## 9. Questions (TW17)

The tests fix the default of each question. A different answer changes the rows that the table names.

| # | Question | Default (tested) | Other option, and the rows that change |
| --- | --- | --- | --- |
| Q1 | Which dir does `dir` print when `ROC_CACHE_DIR` is set: the cache root or the build root? R-CM17 and R-LY1 do not say. | The cache root (D1). | The build root. Rows: L2 runs 1, 2 (`ROC_CACHE_DIR` is set there), L3 parts 2, 3 (`dir` prints `$HOME/.cache/roc-builds`). Or both, in the `--json` data. |
| Q2 | What does `list` list: only what `clean --all` removes, or all of the cache root (also toolchains, `compat.db`, `projects.json`)? | Only the set of `clean --all` (D2), as the proposal of 029 Q1. | All of the cache root with the size of each top item. Rows: L0 `cacheview` 3, 4, L2 runs 7 to 16, L3 parts 4 to 9. A new decision function is needed (which dirs, and which are removable). |
| Q3 | Does `--quiet` hide the output of `list` and `dir`? R-FL4 says `--quiet` keeps "errors and the answer lines of section 4". | No (D5). `Ls` and `RocManage.list!` give the same answer (R-FL4 in their docs). | Hide it. Rows: L2 runs 3, 9, L3 parts 3, 6. |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-CM17 names `list` and `dir` and no rule gives their behavior (Q1, Q2). The design has no catalog row for them (R-OUT3). The accepted fields go in the catalog with this slice. |
| G2 | R-FL4 names "the answer lines of section 4" only. A command whose result is a list (`list`, `roc list`, `cache list`) is not named. `Ls` and `RocManage.list!` already keep it with `--quiet`. |

## 11. Compiler and syntax limits found

No new limit. The split met none: a function of a type module is called with its module name (`FakeBase.log!(w, line)`), as in `RealFx`.

The private reference was deleted after the review (`research/slice-029b-revert/reference/` and `swap.sh`). The tree has the stubs (`cmp` against `stubs/`: no difference). `mutate.py` needs the reference, so it cannot run again.

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23), log `research/slice-029b-revert/red.log`. The old tests all pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files | pass | |
| L0 `tests/unit/cacheview.roc` | red: 4 of 4 `expect`s fail | `Roc application crashed with this message: todo` |
| L2 old cases (68) | pass | The split of `FakeFx` changed none. |
| L2 `cache/cv1-view` | red | `[ROC CRASHED] todo` (the test app writes no exit file) |
| L3 old cases (53, 1 skipped) | pass | |
| L3 `cache/cv1-real` | red | `+[ROC CRASHED] todo` for each `tln cache dir` and `tln cache list` (the exit code is 1) |
| selftest | pass | |

```text
tests/unit/cacheview.roc: FAILED   (4 failed: Roc application crashed with this message: todo)
FAIL cache/cv1-view             the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL cache/cv1-real             stdout differs: +[ROC CRASHED] todo
```

Times on the stub tree: check 1.1 s, fmt 0.1 s, l0 6.1 s, l2 2.2 s, l3 9.5 s, selftest 7.4 s. With the reference (`green.log`): check 0.8, fmt 0.1, l0 5.3, l2 1.4, l3 9.4, selftest 7.2, exit 0. No budget is at risk.

## 13. Check against the design (TW21)

The expected files of the L2 case and of the L3 case were made by the private reference and read by eye against the design and this file. With the reference all 4 `expect`s, the L2 case and the L3 case pass.

| File | What was checked |
| --- | --- |
| `cache/cv1-view/expect/calls.log` | Runs 1 to 5 have `args`, `env_all` and nothing else. Run 6 has `args`. Runs 7 to 9 have `args`, `env_all`, one `list_dirs` of the build root, one `tree_info` with the 7 paths in the order of the list of `clean --all --dry-run` (`cn1-clean` run 2). Runs 10 and 11 have `args` only. Runs 12 to 15 (h4, h5, h2) have the home paths. No run has `tty`, `ask`, `lock`, `unlock`, `delete`, `clock`, `make_dirs`. Run 12 has a busy `talon/gc` and no lock call. |
| `cache/cv1-view/expect/stdout` | The texts of section 6. The 7 sizes and the total (236 B) are those of `cn1-clean` run 2 (35, 47, 47, 24, 49, 16, 18). `--json` runs have the envelope and no text. The h4 run: the x item has no size and the total is 11 B. The h5 run: `nothing to clean`. The h2 run: `compat-ten` is in the list, `compat-file` is not. |
| `cache/cv1-view/expect/stderr` | The 3 usage lines (runs 6, 10, 11) and nothing else. The `--json` runs have an empty stderr. |
| `cache/cv1-view/expect/tree.diff` | Empty: no file changed. |
| `cache/cv1-real/expect/stdout` | The sizes are the real sizes of the fixture files (as `cl1-real` part 2: 24, 47, 30, 24, 16, 18, total 159 B). Part 6 shows the 3 dirs of `roc-builds` and not `compat-aaaaaaa`. Part 9 has the empty list. |
| `cache/cv1-real/expect/tree.diff` | Only the removals of part 9 (the setup `clean --all`). Parts 1 to 8 print no `<` or `>` line. |

## 14. Revert check (TW12)

Method: the private reference makes all new tests pass. `research/slice-029b-revert/mutate.py` puts the reference in place, applies one change, runs `roc check cli/main.roc`, then the layers of the mutation in order (l0 `cacheview.roc`; l2 `cache/`; l3 `cache/cv`). Each run is one after the other, no full sweep of the old tests. Result: 27 mutations, 27 caught (`results.md`, `mutate-run-1.log`). A second run (`mutate-run-2-l3.log`, the env variable `ONLY=l3`) ran 7 mutations with the L3 layer alone: 6 caught. S02 (`dir --json` gives the build root) was not caught by L3 at first, because the runner sets `ROC_CACHE_DIR` to the cache root. L3 part 2 got a second command with another `ROC_CACHE_DIR`, and S02 is caught.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `CacheView.read` (the count, the words) | V01, V02 | L0 `cacheview` 1 |
| `dir_report`, `dir_data` (the line end, the key) | V03, V04 | L0 `cacheview` 2 |
| `list_report` (the empty text, the suffix, the total gate, the total word, the sum, the order, the empty test) | V05 to V10, V15 | L0 `cacheview` 3 |
| `list_data` (null, the keys, the sum) | V11 to V14 | L0 `cacheview` 4 |
| `CacheShow.dir!` (the build root in the text and in the data, `--quiet`, no text with `--json`, `make_dirs!`, the command name) | S01 to S04, S08, S09 | L2 `cv1-view` (S01, S02, S03 also L3) |
| `CacheShow.list!` (`all: false`, the build root, a lock, a `clock!` call, `--quiet`, a short `tree_info!`) | S05 to S07, S10 to S12 | L2 `cv1-view` (S05, S06, S11, S12 also L3) |

Not mutated: the order of the check against `env_all!` (D10) for `list` (the one `args` call of runs 6, 10, 11 fixes it for both commands, `dir` has the same flow), the dispatch in `Run.tln!` (a swap of `dir` and `list` gives other output in every run).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `cli/lib/CacheView.roc` have the contract of each function. The doc of `cli/lib/CacheShow.roc` has the tables of the calls. The `calls.log` of the L2 case fixes the order and the number of calls. |
| N2 | Reuse: `Clean.asks` (with `all: Bool.True`), `Clean.found`, `Gc.entries`, `Roots.from_env`, `Toolchain.size_text`, `Common.failed!`, `Out.json_ok`. Make `Clean.size_suffix` and `Clean.bytes_of` public and use them in `CacheView`. |
| N3 | The command word in the failure text is `Str.join_with(args.command, " ")`. `args.typed` is for the envelope `command`. |
| N4 | `--json` prints only the envelope on stdout and nothing on stderr (D6). Do not use `Common.shown_fx`: it moves text to stderr. |
| N5 | A local variable must not have the name of a method of its type module (slice 020 limit). |
| N6 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

| Item | Text |
| --- | --- |
| D1 to D10, section 6 (output), the FakeFx split, the notes for the code agent | Accepted. |
| Q1, Q2, Q3 | Accepted with the defaults: Q1 the cache root, Q2 only the `clean --all` set, Q3 `--quiet` hides nothing (as `ls` and `roc ls`). |
| G1, G2 | Stay recorded as design notes. |
| Work asked | Status `code`. Delete the private reference. Confirm the red state with `scripts/test.sh`. Stop all background processes. |

## Code result (code agent, 2026-10-23)

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/CacheView.roc` | 63 | The 5 stubs are code. A private `total` (the sum of the sizes). `list_report` and `list_data` use `Clean.size_suffix` and `Clean.bytes_of`. |
| `cli/lib/CacheShow.roc` | 68 | `dir!` and `list!` are code. Private `print!` (the lines, or with `--json` only the envelope). `list!` calls `CacheClean.measure!(fx, roots, Bool.True)`. No `Common.shown_fx`. |
| `cli/lib/CacheClean.roc` | 95 | New public `measure! : Fx, Roots, Bool => { paths, sizes }` (steps 3 and 4: `list_dirs!` with `all`, `Gc.entries`, `Clean.asks`, one `tree_info!`, `Clean.found`). `clean_flow!` and `CacheShow.list!` both call it. Same calls and output as before (manager review). |
| `cli/lib/Clean.roc` | 146 | `size_suffix` and `bytes_of` are public (moved into the type block, with docs). `lines` and `data` call them as `Clean.size_suffix`, `Clean.bytes_of`. No change of behavior. |

Public signatures of the slice are as in section 4. No decision was made that the slice does not fix. No test, fixture or expected file was changed (no dispute rows). No question (TW17). No new compiler limit.

## Verify results

`scripts/test.sh` exit 0 (2026-10-23):

| Step | dev | `OPT=speed` |
| --- | --- | --- |
| check | pass 1.0 s | pass 0.8 s |
| fmt | pass 0.1 s | pass 0.2 s |
| l0 | pass 5.2 s (62 files) | pass 5.5 s |
| l2 | pass 1.4 s (69 cases) | pass 80.4 s (LLVM build, no budget with speed) |
| l3 | pass 9.5 s (54 passed, 1 skipped) | pass 9.4 s |
| selftest | pass 7.3 s (44) | pass 7.2 s |

Revert check (TW12): `research/slice-029b-revert/agent-mutate.py`, results in `agent-results.md`, log `agent-mutate-run.log`. 28 mutations (A21 to A23, A25, A26 now target `CacheClean.measure!`, A29 is new: `!all` in `measure!`, caught by L2 `cache/`; 29 mutations in all, 29 caught), one build after another, filtered layers only. Caught 29 of 29. A copy of the final code is in `research/slice-029b-revert/code-final/`. After the run the 4 files are equal to the copy (`cmp`).
First run: A01, A24 and A27 did not compile (unused variable, unreachable pattern, constant `match`). They were rewritten (A01 `[]` gives an `Err`, A24 adds a `make_dirs!` call, A27 gives `read` an args record with no operand) and run again: all 3 caught.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `CacheView.read` (the `[]` case, the count, the words, the kind) | A01 to A04 | L0 `cacheview` 1 |
| `dir_report`, `dir_data` (line end, key) | A05, A06 | L0 `cacheview` 2 |
| `list_report` (empty text, suffix, total gate, total word, sum, order, size words) | A07 to A12, A28 | L0 `cacheview` 3 |
| `list_data` (null in `Clean.bytes_of`, `total`, `path`) | A13 to A15 | L0 `cacheview` 4 |
| `CacheShow.dir!` (build root in text and data, `make_dirs!`) | A16, A17, A24 | L2 `cv1-view` (A16, A17 also L3) |
| `CacheShow.print!` (`--quiet`, text with `--json`, `command`) | A18 to A20 | L2 `cv1-view` (A18 also L3) |
| `CacheShow.list!` (`all: false`, listing dir, lock, `clock!`, short `tree_info!`, operand check) | A21 to A23, A25 to A27 | L2 `cv1-view` (A21, A22, A26 also L3) |

No mutation was left uncaught, so there is no test gap and no equivalent change to explain. Not mutated: the order of `read` against `env_all!` (D10, fixed by the one `args` call of L2 runs 6, 10, 11) and the dispatch in `Run.tln!`.

## Close (manager, 2026-10-23)

The code agent decisions are accepted. The listing sequence is one function, `CacheClean.measure!`, that `clean` and `list` share. The revert check caught 29 of 29. `scripts/test.sh` exits 0 with no WARN. Status: done.
