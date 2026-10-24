# 028b Cache gc: build caches, packages and sizes

Phase: P1. Status: done

Slice 028b is part 2 of `tln cache gc` (CLI 6.3, R-GC1 age rule, R-GC2, R-GC3 second sentence, R-GC4, R-GC11 sizes). Part 1 is `docs/slices/028-cache-gc.md` (toolchains, temps, locks, `projects.json`). Part 2 adds three things:

| Part | What |
| --- | --- |
| Build-cache dirs | `compat-<id>/`, `nightly-<tag>/`, `debug-<sha>/` in `roots.build` go as whole dirs when no file in them changed in the GC age (R-GC2, R-GC3) |
| Packages | `packages/<hash>/` goes when no live known project uses it and no file in it changed in the last day (R-GC4). The use is read from the package headers in the cache. GC never fetches. |
| Sizes | A new call `Fx.tree_info!` gives the newest file time and the size of a tree. Each removed item has a size in the text and in `--json`, and the report has a total (R-GC11, Q5 of slice 028). |

It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-028b-revert/before/` (with `NEW.txt`). R-GC7 is slice 049. The user answers in `docs/slices/ANSWERS.md` and in `PLAN-P1.md` do not bind this slice (GC edits no header and chooses no compiler).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-GC2 (`nightly-<tag>/`, `debug-<sha>/`: removed when no file in the dir changed in the GC age) | `Gc.candidates`, `Gc.expired`, `CacheGc.work!` | L0 `gc` row 8. L2 `gc/gc3-caches` runs 1 to 3. L3 `cache/gc1-real` part 8 |
| R-GC3, second sentence (another `compat-<id>/` dir: the same age rule; the dir of a compiler that GC removes goes with it, whatever its age) | `Gc.candidates` (`owned`), `Gc.expired` | L0 `gc` row 8. L2 `gc3-caches` (compat-aaaaaaa goes with its compiler, compat-bbbbbbb of a kept compiler goes by age, compat-young stays). L3 part 8 |
| R-GC4 (`packages/<hash>/`: no live known project uses it, nothing in it changed in the last day; the use is the closure read from the headers in the cache, never fetched) | `Gc.protected`, `Gc.candidates`, `Gc.expired`, `CacheGc.protect!` | L0 `gc` rows 7, 8. L2 `gc3-caches` runs 1 to 4 (P1 and P3 old but used, P2 not in the cache, P4 and P8 and P9 go, P5 to P7 stay). L3 part 8 |
| R-GC1, age part (files inside a build cache are left to roc: GC removes a whole dir or nothing; the newest file decides) | `Gc.expired`, the `delete!` of whole dirs only | L2 `gc3-caches` (compat-mixed has one old file and one young file: it stays whole, and it is never in a `delete`). L3 part 8 (the file list before and after) |
| R-GC9 (the age of a file in a build-cache dir is its modification time against the real clock; `gc-age` is the span of a build dir. A package has the span of 1 day.) | `CacheGc.work!` (`clocks.real`, `age`, 86400) | L0 `gc` row 8 (edges). L2 `gc3-caches` (compat-exact stays, compat-over goes, home `h2` has `gc-age = "7d"`, P7 and P8 are the 1 day edge). L3 part 8 |
| R-GC11 (`--dry-run` prints what it would free: sizes, a total) | `Gc.report`, `Gc.data`, `Gc.freed`, `Gc.sizes`, `Gc.asks`, `Fx.tree_info!` | L0 `gc` rows 6, 8, 9. L2 `gc1-select` runs 1, 2, 3, 8. `gc2-busy` run 3. `gc3-caches`. L3 `cache/gc1-real` parts 1, 3, 4, 6, 8 |
| R-OUT2, R-OUT4 (text, `data`) | `Gc.report`, `Gc.data` | L0 `gc` rows 5, 6, 9 |
| R-GC3 and R-GC4 (the real `tree_info!`; TW4: one L3 case for each `Fx` call) | `RealFiles.tree_info!` | L3 `fx/tr1-real-fx-tree-info` |
| R-GC7 | Slice 049 | none here |

Rules of other slices that the cases also touch: R-GC5, R-GC6, R-CC2, R-CC10, R-PD12, R-PD13 (as in slice 028), R-LY1 (`roots.build` is `ROC_CACHE_DIR`, `roots.pkgs` ignores it), R-EV22 (a file time uses the real clock), R-DI7 (a package header is read from `packages/<hash>/main.roc`).

`MISSING=1 scripts/rules.sh R-GC` lists R-GC7, R-GC12 to R-GC14 (slices 049 and 029). Not R-GC1 to R-GC6, R-GC8 to R-GC11.

## 2. Flow of `tln cache gc` after this slice (the changes to the table of slice 028)

| Step | Change | Rule |
| --- | --- | --- |
| 5b (new) | One `list_dirs!` with the one dir `roots.build`. `Gc.entries` makes its entries. | R-GC2, R-GC3 |
| 6b (new) | The walk of `Gc.protected` over `known.live`. It runs only when the listing of `roots.pkgs` has a package dir (`Gc.candidates` with no protected hash has a package). Each `Need(ids)` is one `read_files!` of `Gather.file_of(roots, id)` for the ids, in the order of the ids. Never a fetch. | R-GC4 |
| 8 (more) | After the toolchain decisions: `Gc.candidates`, `Gc.asks`, one `tree_info!` (no call when `asks` is empty; a dry run calls it too), `Gc.expired` (builds: span `gc-age`; packages: span 86400; both with the real time), `Gc.sizes`. | R-GC2, R-GC3, R-GC4, R-GC11 |
| 10 (more) | One `delete!`: the stale paths, then the expired build dirs, then for each expired package its dir and `<dir>.deps.json` (no call when all are empty) | R-GC1, R-GC4 |
| 12 (more) | The report has sizes and a total, and `--json` has `builds`, `packages`, `sizes`, `freed` | R-GC11, R-OUT4 |

The order of the `Fx` calls is fixed by `calls.log` of the L2 cases. The GC lock is the same. No lock for a build dir or a package (R-CC10: GC removes `packages/<hash>/` with the age rule only).

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Fx.roc` | 263 (+12) | Test agent | New field and method `tree_info!`, with the contract in the doc. |
| `cli/RealFx.roc` | 210 (+1) | Test agent | `tree_info!: RealFiles.tree_info!` |
| `cli/RealFiles.roc` | 310 (+5) | Test agent, stub | `RealFiles.tree_info!` is `crash "todo"`. The code agent writes the body (the doc of `Fx.tree_info!` has the rules). |
| `cli/fxprobe.roc` | 334 (+11) | Test agent | The call `fxprobe tree <path>...` (complete: it is a test tool) |
| `cli/lib/Gc.roc` | 248 (+80) | Test agent, stubs | 6 new public functions (`protected`, `candidates`, `asks`, `expired`, `sizes`, `freed`), all `crash "todo"`. 6 new types. `Done` has 3 new fields. The bodies of `report` and `data` are the old bodies (they ignore the new fields); the docs have the new contract. |
| `cli/lib/CacheGc.roc` | 186 (+14) | Test agent | The doc table has the new steps. The 3 `Done` records have the new fields (`builds: []`, `pkgs: []`, `sizes: []`, the stub state). The code agent writes steps 5b, 6b, 8 and 10. |
| `tests/commands/FakeFx.roc` | 859 (+71) | Test agent | The fake `tree_info!` (complete). The file `fx/mtimes` also gives the time of a file in a tree. |
| `tests/unit/gc.roc` | 459 (+212) | Test agent | 3 new `expect`s (rows 7 to 9), rows 5 and 6 have the new `Done` fields, row 6 has the new keys. Row 9 has sizes in GB. |
| `tests/unit/toolchain.roc` | +6 values | Test agent | The `size_text` rows have 999.9 MB, 1.0 GB, 3.1 GB and the GB edges (Q5, review). Red: `Toolchain.size_text` has no GB step yet. |
| `cli/lib/Toolchain.roc` | 0 | Code agent | `size_text` gets the GB step (review). The test agent did not change it (it is code). |
| `tests/commands/cases/gc/gc3-caches/` | 5 runs, 47 given files | Test agent | New L2 case. The fixtures are made by `research/slice-028b-revert/mk-fixtures.py`. |
| `tests/commands/cases/gc/gc1-select/`, `gc2-busy/` | | Test agent | Only the expected files changed (the sizes and the new calls) and 4 lines in `gc1-select/fx/mtimes` (young times for the dirs that the age rule asks for). |
| `tests/scenarios/cache/gc1-real/` | cmd 105 (+43) | Test agent | The sizes in the expected files, and the new part 8. |
| `tests/scenarios/fx/tr1-real-fx-tree-info/` | cmd 29 | Test agent | New L3 case of the real `tree_info!` (TW4) |
| `research/slice-028b-revert/` | | Test agent | `before/` (and `NEW.txt`), `stubs/` (the stub files; the private reference was deleted after the review), `swap.sh`, `mutate.py`, `mk-fixtures.py`, `results.md`, `mutate-run-1.log`, `mutate-run-2.log`, `baseline.log`, `red.log`, `green.log` |

No change to `scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh`, `tests/commands/main.roc`, `tests/selftest.sh`.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Fx.tree_info!` | `Fx, List(Str) => List(Try({ newest : U64, size : U64 }, [NotFound, Denied, Other(Str)]))` | R-GC3, R-GC4, R-GC11 |
| `Gc.Tree`, `Gc.Info` | `{ newest : U64, size : U64 }`, `Try(Gc.Tree, [NotFound, Denied, Other(Str)])` | R-GC11 |
| `Gc.Ask`, `Gc.Measured`, `Gc.Sized`, `Gc.Node` | `{ item : Str, path : Str }`, `List({ item : Str, path : Str, info : Gc.Info })`, `{ item : Str, bytes : U64 }`, `{ id : Str, read : Manage.Read }` | R-GC4, R-GC11 |
| `Gc.Done` | The old fields, and `builds : List(Str)`, `pkgs : List(Str)`, `sizes : List(Gc.Sized)` (`packages` is a reserved word, so the field is `pkgs`, and the key of `--json` is `packages`) | R-OUT4 |
| `Gc.protected` | `{ projects : List(Gc.Project), nodes : List(Gc.Node) } -> [Need(List(Str)), Done(List(Str))]` | R-GC4 |
| `Gc.candidates` | `{ roots : Roots, entries : List(Entry), builds : List(Entry), protected : List(Str), owned : List(Str) } -> { pkgs : List(Str), builds : List(Str) }` (`Entry` is `{ path, is_dir, mtime }`) | R-GC2, R-GC3, R-GC4 |
| `Gc.asks` | `{ roots, toolchains : List(Str), compat, stale, builds, pkgs : List(Str) } -> List(Gc.Ask)` | R-GC11 |
| `Gc.expired` | `{ dirs : List(Str), measured : Gc.Measured, now : U64, span : U64 } -> List(Str)` | R-GC1, R-GC3, R-GC4, R-GC9 |
| `Gc.sizes`, `Gc.freed` | `Gc.Measured -> List(Gc.Sized)`, `Gc.Done -> U64` | R-GC11 |

The docs of these items in `cli/lib/Gc.roc` have the exact rules (a table for `protected` and `candidates`).

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/gc.roc` 7 (`protected`) | The walk in 4 steps (`Need`, `Need`, `Need`, `Done`): a project entry, a path entry of a project and of a path file, a `Foreign` URL, a path value in a release header, a hash that 2 projects name, a file that cannot be read (its URL still names the hash), a cycle. A `Denied` project and a project with a text that is no header use nothing. The hashes are sorted. | R-GC4 |
| L0 | 8 (`candidates`, `asks`, `expired`, `sizes`) | Which package dirs and build dirs can go (the name, the kind, the parent dir, `owned`, `protected`, `ROC_CACHE_DIR`). The one list for `tree_info!` and its order. The age edges (exactly the span stays, 1 s more goes, the future stays, `Err` stays, no row stays, the order of `dirs`). The sizes (an `Err` row has none). | R-GC1, R-GC2, R-GC3, R-GC4, R-GC9, R-GC11 |
| L0 | 9 (`report`, `data`, `freed`) | Sizes in the lines, the total line (before the dry run line, none when no removed item has a size), a skipped item and a project have no size, an item twice counts once, `sizes` and `freed` in `data`. | R-GC11, R-OUT2, R-OUT4 |
| L0 | 5, 6 (changed) | The new `Done` fields (empty), and the new keys in the data of a busy run and of a dry run | R-OUT2, R-J3, R-OUT4 |
| L2 | `gc/gc3-caches` (5 runs) | 1 `--dry-run`: the whole decision (see the comments in `fx/commands`), the one `tree_info` call, no write. 2 `--dry-run --json`: the envelope with `builds`, `packages`, `sizes`, `freed`. 3 the real run: the one `delete` (stale, builds, packages with their sidecars), a dir that stays is never touched. 4 again: only the `tree_info` call of the dirs that stay. 5 home `h2`: `gc-age` 7 days, no `ROC_CACHE_DIR` (the cache root is listed twice), a live project and no packages dir: no read of a package. | R-GC1 to R-GC4, R-GC9, R-GC11, R-EV22, R-J3 |
| L2 | `gc/gc1-select`, `gc/gc2-busy` (expected files changed) | The new `list_dirs` line and the `tree_info` line in each run that reads, the sizes in the text and in `data`, the total, `compat-bbbbbbb`, `compat-ccccccc`, `compat-other` and the package that nothing uses are asked and stay (young times in `fx/mtimes`) | R-GC11, R-GC3 |
| L3 | `cache/gc1-real` part 8 and the sizes of parts 1 to 6 | The real binary, the real `tree_info!`, the real clock. `ROC_CACHE_DIR` is another dir. Old dirs go, `compat-mixed` stays whole, a used and old package stays, a young package stays, the sidecar goes with its package. | R-GC1 to R-GC4, R-GC11 |
| L3 | `fx/tr1-real-fx-tree-info` | The real `tree_info!` (TW4): the newest file time (a dir time does not count), the sum of file sizes, a file path, a tree with no file (own time), a missing path, a link is not followed, the order of the list. | R-GC3, R-GC4, R-GC11 |

Count: 9 L0 `expect`s in `gc.roc` (3 new, 2 changed). 2 new deep cases (L2 `gc3-caches` with 5 runs, L3 `tr1-real-fx-tree-info`), 1 new part in a deep case (L3 part 8), 3 deep cases with changed expected files. No selftest row.

## 6. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stdout, a run | As in slice 028, with these changes. A removed item that has a size has the suffix ` (<size>)` (`Toolchain.size_text`: `999 B`, `2.0 KB`, `1.5 MB`, `3.1 GB`). The order of the item lines: toolchains, skipped toolchains, compat dirs, stale paths, build dirs, package dirs, projects. |
| stdout, a run with a size | The line `freed <size>` before the last line. In a dry run: `would free <size>`, then `dry run: nothing was removed`. No total line when no removed item has a size (for example only projects leave). |
| `--json` `data` | The keys in this order: `dry_run`, `ran`, `toolchains`, `skipped`, `compat`, `stale`, `builds`, `packages`, `projects`, `sizes`, `freed`. `sizes` is `[{"item":<id or path>,"bytes":<n>}]` for the removed items that have a size, in the order of the lines, each item once. `freed` is the number of bytes. A busy run has `sizes: []`, `freed: 0`. |
| Errors | No new error. |

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | Sizes: a suffix on each line and a total line (Q5 of slice 028 answered by the plan row 028b). | Only a total. A flag `--sizes`. |
| D2 | `Fx.tree_info!`: `newest` is the newest time of a file; the time of a dir does not count (it changes when an entry is added or removed, not when a file changes); an empty tree has its own time; `size` is the sum of file sizes; a link is not followed and not counted. | The time of a dir counts (a dir looks young after any change). Disk blocks. Follow links. |
| D3 | A `tree_info!` error (`NotFound`, `Denied`, `Other`) for a candidate: the dir stays, it has no size, and there is no error. | GC stops with exit 18. The dir goes. |
| D4 | The build-cache dirs are in `roots.build` (R-LY1, `ROC_CACHE_DIR`), found by one more `list_dirs!` (step 5b). A candidate is a dir whose name starts with `compat-`, `nightly-` or `debug-` and has one more character. | A 7th dir in `Gc.scan_dirs` (`Temp.old` would then look in the build root for temps). Every dir of the build root. |
| D5 | The age rule is for the compat dir of a compiler that GC keeps too (R-GC3: "another dir"). The dir of a compiler that GC removes goes with it, young or not, and it is not asked (`owned`). | Skip the dir of each kept compiler (question Q1). |
| D6 | The span of a build dir is `gc-age`, the span of a package is 1 day. Both use the real clock, because they compare file times. "More than the span" goes, exactly the span stays, a time in the future stays (D3 of slice 028). | `TALON_NOW` for a file time. One span for both. |
| D7 | The use of a package: the walk follows every entry of every header that it can read, not only the winning version (a superset of `Closure.step`). It reads `packages/<hash>/main.roc` of a release URL (`Gather.file_of`) and the file of a path entry of a project or of a path file. A path value in a release header is ignored. A `Foreign` URL (no version) names nothing. A file that cannot be read still names its hash, and has no entries. | `Closure.step`: it fails on a conflict and needs all nodes. A fetch of a missing package. A hash for a `Foreign` URL (question Q4). |
| D8 | Only live projects (`known.live`: not gone, used in the GC age) protect a package. A live project with an unreadable file protects nothing (as D4 of slice 028). | Keep all packages when a project cannot be read (question Q3). |
| D9 | The walk runs only when `roots.pkgs` has a package dir that can go. Else there is no read. | A walk every run. |
| D10 | The sidecar `packages/<hash>.deps.json` is deleted with its package, in the same `delete!`, and is not listed or sized. | Leave it. List it as an item. |
| D11 | One `tree_info!` call for all asks (toolchains that go, their compat dirs, stale paths, candidate builds, candidate packages), in this order. A dry run calls it too. | Two calls (age, then sizes). |
| D12 | The order of the `delete!` paths: stale, builds, packages (each with its sidecar). | Packages first. |
| D13 | A busy (skipped) toolchain is measured but has no line and no part in the total. An item that has no size (an `Err` answer) has no suffix and counts 0. A path that is in the lists twice (2 compilers with one compat id, D13 of slice 028) counts once in the total. | Count twice. |
| D14 | `Gc.Done` has the field `pkgs` (the word `packages` is reserved in Roc). The key of `--json` is `packages`. | The key `pkgs`. |
| D15 | No lock for a build dir or a package (R-CC10: GC removes `packages/<hash>/` with the age rule only). | A lock for each dir. |
| D16 | `Gc.entries` is used for the listing of the build root (same type as the listing of the 6 dirs). `Temp.old` is not called for it. | |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-GC7 | Slice 049 (no `x` entry and no record of its last use exist, R-X2) |
| R-GC12 to R-GC14, R-NI7 | Slice 029 (`cache clean`) |
| Packages used by a global tool or by `talon/x` (Q2) | The tool roots come with slice 046, when the `tools.json` form is fixed |
| `tree_info!` that gives `Denied` for a dir that the user cannot read | The L3 runner runs as the user of the test run. A `chmod 000` dir is not a stable test (a root user can read it). The code of the `Err` path is checked in L0 (`expired` with `Err(Denied)`). |
| The race of a `roc` build that uses a package that GC removes | R-CC10 says that one build fails once and the next run fetches the package again. |
| `Fx.tree_info!` of a very large tree and its time | The budget R-CC12 for a step that is not a wait is 25 s. No test: a fake tree of that size is not a stable test. |
| A `delete!` that fails for a build dir or a package | The result of `delete!` is ignored, as for the stale paths in slice 028 (the next run asks again). No test row. |

## 9. Questions (TW17)

The tests fix the default of each question. A different answer changes the rows that the table names.

| # | Question | Default (tested) | Other option, and the rows that change |
| --- | --- | --- | --- |
| Q1 | R-GC3 says that GC removes "another dir" only when no file in it changed in the GC age. A compat dir of a compiler that GC keeps is "another dir". But a build that finds its cache may not write a file. So a compiler that a project uses each day can lose its build cache (cost: one rebuild). | The age rule applies to it (D5). | Never remove the compat dir of a kept compiler. Rows: L0 `gc` 8 (`owned`), L2 `gc3-caches` (`compat-bbbbbbb`), the `compat-` lists |
| Q2 | R-GC4 names only known projects. A package that a global tool (`tools.json`) or `talon/x` uses, with no known project, is not protected. | Not protected (the package is fetched again, R-DI7). | Protect it. Rows: L0 `gc` 7, L2 `gc3-caches`. It needs the closure of the tool entries (slice 046 to 049). |
| Q3 | A live project whose file cannot be read (`Denied`, `Other`) has no closure. | It protects nothing (D8). | GC removes no package in this run. Rows: L0 `gc` 7 (`p3`), L2 (no row today) |
| Q4 | A header URL with no version (`Foreign`) still downloads to `packages/<hash>/`. | It names nothing (D7). | Take the hash from the file name. Rows: L0 `gc` 7 (`odd`) |
| Q5 | `Toolchain.size_text` has no GB step: a 3.1 GB dir was `3100.0 MB`. The design says "3.1 GB here" (R-GC2). | Answered by the manager (2026-10-23): add a GB step (`size_text` change, section Review). Tested: L0 `toolchain` size rows, L0 `gc` 9 (`3.1 GB`). | Closed |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-GC3 and Q1: the age rule for the compat dir of a kept compiler. |
| G2 | R-GC4 names the closure but not how GC reads it. R-DI7 says Talon reads a header from `packages/<hash>/main.roc` and GC must not fetch. D7 chooses the superset walk. |
| G3 | R-GC4 does not say what a project that cannot be read protects (Q3), and does not name tools (Q2). |
| G4 | R-GC1 says "Leaves to roc" for files inside a build cache. R-GC2 and R-GC3 remove a whole dir by age. The tests keep both: GC never removes a part of a dir. |
| G5 | R-GC9 names the real clock for the age of a file in a build-cache dir only. D6 uses it for a package too (a file time). |
| G6 | R-GC4 says "nothing in it changed in the last day": the edge (exactly 1 day) is not given. The tests use the rule of `Temp.old` (exactly 1 day stays). |
| G7 | No GC rule names the sidecar `packages/<hash>.deps.json` (D10). |
| G8 | R-GC11 says "prints what it would free" and gives no format (D1, section 6). `size_text` had no GB step (Q5, closed in the review). |

## 11. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| `packages` and `app` are reserved words, also as a field name or a variable name | The `Done` field is `pkgs`. The test helper for a project header is `proj`. |
| A local name with the name of a top level value of the same file (`now`) is a duplicate definition | The new rows of `gc.roc` use the top level `now` and `age` |
| `Path.type!` gives `IsSymLink` and does not follow a link | The fake and the reference of the real `tree_info!` use it to skip links |
| The L2 runner changes `{w}` only in `.json` files of `home/` and `project/` | The second home of `gc3-caches` is `home/h2`, so its `projects.json` has a real path |
| The tree diff of the L2 runner covers `home/` and `project/` only | The build dir of `gc3-caches` is `home/.cache/roc-builds` |

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23), log `research/slice-028b-revert/red.log`. The old tests all pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files (all but `gc.roc` and `toolchain.roc`) | pass | |
| L0 `tests/unit/toolchain.roc` | red: 1 `expect` fails (the `size_text` rows) | A wrong value: no GB step (re-run 2026-10-23 after the review, `red.log`) |
| L0 `tests/unit/gc.roc` | red: 4 of 9 `expect`s fail (rows 6 to 9) | Row 6: a wrong value (the old keys). Rows 7 to 9: `Roc application crashed with this message: todo` (the stubs). Rows 1 to 5 pass: the old `report` and `data` bodies ignore the new fields. |
| L2 old cases (64) | pass | |
| L2 `gc/gc1-select`, `gc/gc2-busy`, `gc/gc3-caches` | red | A wrong value: no `tree_info` call and no sizes (`gc3-caches`: the build dirs and packages stay) |
| L3 old cases (49, 1 skipped) | pass | |
| L3 `cache/gc1-real` | red | A wrong value: no sizes and no total, part 8 removes nothing |
| L3 `fx/tr1-real-fx-tree-info` | red | `[ROC CRASHED] todo` (the stub of `RealFiles.tree_info!`) |
| selftest | pass | |

```text
tests/unit/gc.roc: FAILED (4 failed: row 6 wrong keys, rows 7 to 9 "todo")
FAIL gc/gc1-select    Fx calls differ (no tree_info, no list_dirs of the build dir), stdout has no sizes
FAIL gc/gc2-busy      the same
FAIL gc/gc3-caches    Fx calls differ, the file tree has no removal of a build dir or a package
FAIL cache/gc1-real   stdout differs (no sizes, no part 8 removal)
FAIL fx/tr1-real-fx-tree-info   stdout differs: +[ROC CRASHED] todo
```

Times, stub tree (warm cache): check 1.0 s, fmt 0.1 s, l0 5.0 s, l2 1.3 s, l3 9.4 s, selftest 7.0 s. With the reference (`green.log`): check 1.0, l0 5.0, l2 1.4, l3 9.5, selftest 7.0, exit 0. Before the slice (`baseline.log`): check 0.9, l0 5.0, l2 1.3, l3 9.4, selftest 7.0. No budget is at risk.

## 13. Check against the design (TW21)

The expected files of `gc3-caches` and the changes to the other cases were made by the private reference (`research/slice-028b-revert/reference/`) and read by eye against the design. The sizes are the real sizes of the fixture files. The L3 case and the L2 cases were run again with a longer `TMPDIR`: the same output (no size depends on the path of the work dir).

| File | What was checked |
| --- | --- |
| `gc/gc3-caches/expect/calls.log` | The order: `list_dirs` (6 dirs), `list_dirs` (build root), `projects.json`, the project files, the walk (2 levels: P1 and P2 in one `read_files`, then P3), the compiler files, one `tree_info`, then the locks, the `rename`, one `delete` with the compat dir, one `delete` (stale, builds, packages with sidecars), the `projects.json` write. The dirs that are protected (P1, P3), that are not dirs (`compat-file`), and that have no build-cache name (`other-old`) are not in `tree_info`. Run 4 has no `delete`. Run 5 has no read of a package although the project is live. |
| `gc/gc3-caches/expect/stdout` | The lines in the order of section 6. The 3 old build dirs and the 3 packages that nothing uses go. `compat-exact` (exactly the age), `compat-mixed`, `compat-young`, `compat-future`, P5, P6 (one file of 100 s), P7 (exactly 1 day) stay. The total is the sum of the lines. |
| `gc/gc3-caches/expect/tree.diff` | Only the removed files. Nothing under `compat-mixed`. P1, P3 and the sidecar of P1 stay. |
| `gc/gc1-select`, `gc2-busy`, `cache/gc1-real` expected files | The same lines as before, each with its size, a total line, the new calls. The `tree.diff` files are the same as before (part 8 of the L3 case adds the new removals). |
| `fx/tr1-real-fx-tree-info/expect/stdout` | The numbers match the `touch -d` times of the `cmd` (1031536000 is 2002-09-09 01:46:40) and the byte counts (4 + 10 + 1). |

## 14. Revert check (TW12)

Method: the private reference makes all new tests pass. `research/slice-028b-revert/mutate.py` puts the reference in place, applies one change, runs `roc check cli/main.roc`, then the layers of the mutation in order (`gc.roc`, L2 `gc/`, L3 `cache/gc1-real` and `fx/tr1`). Each run is one after the other. No full sweep. Result: 42 mutations, 42 caught (`results.md`, `mutate-run-1.log`, `mutate-run-2.log`, `mutate-run-3.log`). S1 to S4 (the GB step: the edge, the rounding, the unit, a wrong edge) are caught by `toolchain.roc`. 3 did not compile at first (an unused variable) and were written again (N24, N35, N39). The number N34 is not used.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Gc.protected` (path of a release header, the sort, a missing node, a `Foreign` URL, a project path, an unreadable node) | N01 to N05 | L0 row 7 |
| `Gc.candidates` (the name, the parent dir, `protected`, `owned`, the prefixes, the length) | N06 to N11 | L0 row 8 |
| `Gc.asks`, `Gc.expired`, `Gc.sizes` (order, the edge, `Err`, no row, the size) | N12 to N16 | L0 row 8 |
| `Gc.freed`, `Gc.report`, `Gc.data` (a duplicate, the verb, the total, the order, `freed`, `sizes`) | N17 to N22 | L0 rows 8, 9 (N19: L2) |
| `CacheGc` (the build dir, the walk gate, the delete order, the sidecar, the spans, the real clock, `owned`, `known.live`, the dry run, the call gate) | N23 to N33 | L2 |
| `RealFiles.tree_info!` (the size, the newest, an empty tree, a link, a missing path) | N35 to N39 | L3 `fx/tr1` |
| `Toolchain.size_text` GB step | S1 to S4 | L0 `toolchain` |

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `cli/lib/Gc.roc` docs have the contract of each new function. `cli/lib/CacheGc.roc` doc has the table of the calls. The `calls.log` of the L2 cases fixes the order and the number of calls. |
| N2 | `Gc.report` and `Gc.data` need `Toolchain.size_text` (`import Toolchain`). The stub `Gc.roc` does not import it (it would be unused). `size_text` needs the GB step: below `999_950_000` bytes the MB text, else `tenths_text((bytes + 50_000_000) // 100_000_000)` and ` GB` (the rows of `toolchain.roc`: 999_949_999 is `999.9 MB`, 999_950_000 is `1.0 GB`, 3_149_999_999 is `3.1 GB`, 3_150_000_000 is `3.2 GB`). |
| N3 | `Gc.protected` follows the walk of `Closure.step` in shape (`Need`, `Done`). `Release.entries_of` reads a header, `Ident.of_url` gives the hash, `Text.resolve` resolves a path entry, `Gather.file_of` gives the file of an id. |
| N4 | `RealFiles.tree_info!`: `Path.type!` does not follow a link (`IsSymLink`), `Path.list!` gives the entries, `Path.time_modified!` gives nanoseconds, `Path.size_in_bytes!` gives bytes. A local name must not be the name of a method of its type module. |
| N5 | A local variable named `packages` or `app` does not compile. |
| N6 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

| Item | Text |
| --- | --- |
| D1 to D16, section 6 (output), Q1, Q3, Q4 | Accepted, with the defaults. G1 to G8 stay recorded as design notes. |
| Q2 | Accepted. The tool roots come with slice 046, when the `tools.json` form is fixed. Noted in section 8 (Out of scope). |
| Q5 | Change. The design text says "3.1 GB", so `Toolchain.size_text` gets a GB step: from 1000 MB up it prints GB with one decimal, in the same rounding style as the MB step. Add L0 rows in the existing `size_text` expect (999.9 MB, 1.0 GB, 3.1 GB). Update any expected file that shows a size of 1000 MB or more (old cases too). |

Answers of the test agent:

| Item | Answer |
| --- | --- |
| L0 | `tests/unit/toolchain.roc`: 6 new values (999_949_999 is `999.9 MB`, 999_950_000 and 1_000_000_000 are `1.0 GB`, 3_100_000_000 and 3_149_999_999 are `3.1 GB`, 3_150_000_000 is `3.2 GB`). The edge is 999_950_000, as the KB to MB edge is 999_950 (999.95 MB would round to `1000.0 MB`). `tests/unit/gc.roc` row 9 has `3.1 GB` in place of `3100.0 MB`. |
| Expected files | No other expected file (old or new) has a size of 1000 MB or more. None changed. |
| Code | `Toolchain.size_text` is not changed by the test agent (it is code, N2). The new `toolchain.roc` values are red until the code agent adds the step. |
| Mutations | S1 to S4, all caught (section 14). |
| Reference | Deleted (`research/slice-028b-revert/reference/`). The stubs are in `cli/` and in `research/slice-028b-revert/stubs/`. |

## Code result (code agent)

Result of `scripts/test.sh`: exit 0, no WARN (`research/slice-028b-revert/agent-run2.log`): check 0.9 s, fmt 0.1 s, l0 5.0 s, l2 1.5 s, l3 9.4 s, selftest 7.0 s. `OPT=speed scripts/test.sh`: exit 0 (l2 78.5 s, `agent-speed.log`). `roc check`: 0 errors, 0 warnings.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Gc.roc` | 333 | The 6 new bodies (`protected`, `candidates`, `asks`, `expired`, `sizes`, `freed`). New bodies of `report` (size suffix, total line) and `data` (`builds`, `packages`, `sizes`, `freed`). Private helpers: `paths_of`, `counted` (the removed items that have a size, each once: the one source of `sizes` in `data`, of `freed`, and of the total line), `size_suffix`, `once`, `is_build_name`, `named`, `id_of`. `is_over` (slice 028) is the one age test, also for `expired`. |
| `cli/lib/CacheGc.roc` | 222 | Steps 5b, 6b, 8 and 10 in `work!`. New private `protect!` (the gate of D9), `walk!` (`Need` is one `read_files!` of `Gather.file_of`), `aged!` (`candidates`, `asks`, one `tree_info!`, `expired`, `sizes`). |
| `cli/RealFiles.roc` | 365 | `tree_info!` with private `tree_one!`, `tree_files!`, `seconds_of!`, `bytes_of!`. |
| `cli/lib/Toolchain.roc` | 419 | `size_text` GB step (N2): `999_950_000` is the edge, the rounding is `(bytes + 50_000_000) // 100_000_000`. |

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| `candidates`: parent dir of a build dir | Not tested (the list of the one `list_dirs!` of `roots.build` has only its entries). Only the name, the kind and `owned` decide. | A test of `Text.dir_of(path) == roots.build` (a trailing `/` in `ROC_CACHE_DIR` would make it fail) |
| `expired`: match of a row | By `path` (`item` of a toolchain is its id, not its path) | By `item` |
| Total line and `data.sizes` | One function `counted` for both, so that the text, `sizes` and `freed` cannot differ | The sum over `done.sizes` (it has the size of a skipped toolchain) |
| `tree_info!` of a link as the path itself | Not a file: no time, no size (`0`, `0`). The doc gives no rule for the path that is a link. | An error |
| The walk (`walk!`) | Recursive effectful function, one `read_files!` for each level | A `while` loop with `var` |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

Questions (TW17): none. Compiler limits met: none new.

## Verify results (revert check, TW12)

`research/slice-028b-revert/agent-mutate.py` puts `code-final/` back, makes one change, runs `roc check cli/main.roc`, then the layers of the mutation in order (l0 `gc.roc`; l2 `gc/`; l3 `cache/gc1-real` and `fx/tr1`; `toolchain.roc` for the GB step). The first failing layer ends the run. It was run in 4 chunks, one mutation after another. Result: caught 39 of 40 (`agent-results.md`, `agent-mutate-run-2.log` to `-4.log`; chunk 1 was not logged, its lines are in `agent-results.md`). `cmp` of the 4 changed files against `code-final/` shows no difference after each chunk and after the `OPT=speed` run.

| Rule | Mutations | Caught by |
| --- | --- | --- |
| R-GC4 (walk) | G01 path value of a release header followed, G02 no sort or unique, G03 `Need` with a repeat, G04 a `Foreign` URL as a path | l0 `gc` row 7 |
| R-GC4, R-GC3, R-GC2 (candidates) | C01 and C02 the `.` test or `protected`, C03 parent dir of a package, C05 `owned`, C06 name length | l0 `gc` row 8 |
| R-GC11, R-GC9, R-GC1 (asks, expired, sizes, report, data) | A01 order of asks, E01 age edge, E02 an `Err` info goes, S01 size, F01 a duplicate counts twice, R01 dry run word, R02 order of the total line, R04 order of items, D01 `freed` | l0 `gc` rows 8, 9 |
| R-GC11 | R03 total gate uses `done.sizes` | l2 `gc/` (L0 has no run with a size of a skipped item only) |
| R-GC3, R-GC4, R-GC9, R-GC1, R-EV22 (`CacheGc`) | W01 build root, W02 walk gate, W03 delete order, W04 sidecar, W05 span of builds, W06 real clock, W07 `owned`, W08 live projects, W09 builds in a dry run, W10 `file_of`, W11 the `delete!` gate, W12 expired packages, W14 sizes | l2 `gc/` |
| R-GC3, R-GC4, R-GC11 (`tree_info!`) | T01 size, T02 newest, T03 own time of an empty tree, T04 a link, T05 error kind | l3 `fx/tr1` |
| R-GC11 (GB step) | Z01 edge, Z02 rounding | l0 `toolchain` |

Not caught:

| Id | Mutation | Verdict |
| --- | --- | --- |
| T06 | `tree_files!` ignores an error of a child (`Err(_) => {}`): a `Denied` dir below a tree gives a partial answer in place of `Denied` | Test gap, known and accepted: section 8 (Out of scope) says that a `chmod 000` dir is not a stable test. The `Err` path of the answer is checked in L0 (`expired` with `Err(Denied)`). |

## Close (manager, 2026-10-23)

The code agent decisions are accepted. T06 (an error in a child dir of `tree_info!`) stays a known gap: a `chmod 000` test is not stable, and L0 checks the `Err(Denied)` path. The revert check caught 39 of 40. `scripts/test.sh` exits 0 with no WARN. Status: done.
