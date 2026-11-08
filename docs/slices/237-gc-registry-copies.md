# 237 GC of the registry copies

Phase: P2. Status: done (TW24 texts wait for the user review)

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-GC15 (Design Q200) | `tln cache gc` removes a page of `get/` (its 2 files, `<key>.json` and `<key>.meta`) whose meta is older than the GC age. It removes a dir `talon/index/registry/<origin>/` of another registry than the registry of the GC run when no file in it changed in the GC age. It keeps `toolchains.json` of the registry of the run. The pages of `talon/index/github/` have no GC rule (`tln cache clean` removes them, R-GC12). |
| R-IX1 | The dir name `<origin>`: `://` and each other `:` become `_` (`https_registry.example.org`, `http_127.0.0.1_8787`). |
| R-IX2 | A page is `<origin>/get/<key>.json` and `<key>.meta`. `<key>` is 32 lower-case hex digits. The age of a page is the modification time of its meta. |
| R-IX4 | `<origin>/toolchains.json` is a file that Talon can make again. Its rows never change. |
| R-IX5 | A command reads and writes only the dir of its registry. `direct` uses only `talon/index/github/`. GC removes old dirs (R-GC15). |
| R-GC9 | The GC age is `gc-age` (default 30 days). |
| R-GC11 | `--dry-run` prints what it would free and removes nothing. The sizes and the `freed` line follow the lists. |
| R-RG1, R-RG7 | The registry of a run: `--registry`, then `TALON_REGISTRY`, then `registry` of `config.toml`, then the built-in default. A text is `direct` or a URL in the base URL form. |
| R-GC12 | `talon/index/github/` is for `tln cache clean`, not for GC. |

Source: row 237 of docs/slices/PLAN-P2-CLI.md. `MISSING=1 scripts/rules.sh R-GC` listed R-GC15 with no test before this slice.

## Scope

Facts found in the code (before any change):

| Question | Answer | Where |
| --- | --- | --- |
| Does GC remove registry pages or dirs today? | No. Nothing in `CacheGc` or `Gc` reads `talon/index/registry/`. The only use of `talon/index` is the stale temp scan (R-GC6): one `list_dirs!` of the dir `talon/index`, top level only. | cli/lib/Gc.roc:131, cli/lib/CacheGc.roc:90 |
| Is there a helper for the dir of a registry? | Yes: `RegistryCache.origin_dir` (R-IX1) and `RegistryCache.files`. They are not used by GC. | cli/lib/RegistryCache.roc:23, :39 |
| Does GC know the registry of the run? | No. `CacheGc.work!` reads `config.toml` with `RocInstall.read_config!`, which gives `registry` (text and place) but GC never reads it. `IndexQuery.setting` gives `[Direct, Registry(origin)]` from the flag, the variable and the config. | cli/lib/CacheGc.roc:92, cli/lib/IndexQuery.roc:29 |
| What is the age edge of GC? | `Gc.expired` and `is_over`: `now > time and now - time > span`. Exactly the age stays, a time in the future stays. R-GC15 says "older than", so the same edge holds. | cli/lib/Gc.roc:253, :298 |
| What does the report print? | `Gc.Done` has the lists `toolchains`, `skipped`, `compat`, `stale`, `builds`, `pkgs`, `projects`. Slice 049 put the `x` dirs in `builds` (the report and `data.builds`). | cli/lib/Gc.roc, cli/lib/CacheGc.roc:164 |
| Which sizes? | One `Fx.tree_info!` call for all asks (D11): the sizes of removed items only. | cli/lib/CacheGc.roc:154 |

So the code is missing, not partial. Code is needed. The size is about 80 lines: 2 pure functions in `Gc`, 2 listings and the asks in `CacheGc.aged!`, the `registry` setting in `gc_flow!`.

Out of scope: the GC of `talon/index/github/` (no rule), the stale temps in `get/` (R-GC6 lists the top level of `talon/index` only: see Open Q5), `tln cache clean` (R-GC12), a `--json` key of its own (Open Q3).

## Tests

Test names use the rule ids in a comment (`scripts/rules.sh`). The L0 file is tests/unit/GcindexTest.roc. I added `import GcindexTest` to the small driver tests/unit/l0-9.roc (no new driver). The L2 case is tests/commands/cases/gc/gc15-registry-copies.

Pure functions that the tests name (a proposal for the code agent, TW1):

| Function | Type | Meaning |
| --- | --- | --- |
| `Gc.index_pages` | `{ dir : Str, entries : List({ name, is_dir, mtime }), now : U64, age : U64 } -> List(Str)` | `dir` is `<origin>/get`, `entries` is its `Gc.entries`-like listing. The paths of the 2 files of each page whose meta is older than `age`, sorted by path. A page is `<32 hex digits>.json` and `.meta`; a half page is aged by its own file (Q5), and only the existing file is listed. |
| `Gc.index_dirs` | `{ roots : Roots, current : [Direct, Registry(Str)], entries : List({ path, is_dir, mtime }) } -> List(Str)` | `entries` is the listing of `<index>/registry`. The dirs that are no dir of the registry of the run (`RegistryCache.origin_dir`), sorted, each once. The age test is `Gc.expired` (no new code). |

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/GcindexTest.roc expect 1: `index_pages` with 7 pages and 3 other names. Meta very old: goes, 2 files, also with a young body. Meta 1 s over the age: goes. Exactly the age: stays. Young: stays. Future: stays. Old body and young meta: stays. `notes.meta`, `README`, `<key>.txt`: stay. | R-GC15 R-IX2 R-GC9 | red: compile error, `Gc.index_pages` does not exist |
| L0 | expect 2 (Q5): orphan files. An old orphan `.json` or `.meta` goes alone, a young one stays, exactly the age stays. | R-GC15 R-IX2 R-GC9 | red: compile error |
| L0 | expect 3: the span is the argument (60 s: 61 s goes, 60 s stays, 59 s stays), and no entry gives no path. | R-GC15 R-GC9 | red: compile error |
| L0 | expect 4: `index_dirs` with `https://current.example.org`, with `http://127.0.0.1:8787` (R-IX1 name with `_`), with `Direct` (all dirs), with no entry. A file in `registry/` is no dir. | R-GC15 R-IX1 R-IX5 | red: compile error, `Gc.index_dirs` does not exist |
| L0 | expect 5: `index_dirs` with `Gc.expired`: a dir of another registry with all files old goes, with one new file stays, newest file exactly the age stays, 1 s over goes. The dir of the registry of the run is not asked, so it stays with all files old (it holds `toolchains.json`). | R-GC15 R-GC9 R-IX5 | red: compile error |
| L2 | gc/gc15-registry-copies run 1 and 2: `cache gc --dry-run`, then `cache gc --json` (config `registry = "https://current.example.org"`). 6 pages of the current registry (very old meta, 1 s over, exactly the age, young, future, old body with young meta) and `notes.meta`. Dirs: `https_old` (all old), `http_127.0.0.1_8787` (one young meta), `https_edge` (newest exactly the age), `https_over` (1 s over). `toolchains.json` of the current dir is very old. `talon/index/github/acme/lib/repo.json` is very old. Goes: the dirs `https_old`, `https_over`, the pages 1 and 2 (6 items, 382 B). Everything else stays, also `toolchains.json` and the github file. The lines, the `--json` lists, the sizes, the one `delete`, the tree. | R-GC15 R-IX1 R-IX2 R-IX5 R-GC9 R-GC11 R-GC12 R-J3 | red: stdout `nothing to remove`, no delete, no new listing |
| L2 | run 3: `cache gc` again: `nothing to remove`. The dirs that stay are asked again by `tree_info`, no delete. | R-GC15 | red: the calls.log lacks the 2 listings and the `tree_info` |
| L2 | run 4: `TALON_REGISTRY=http://127.0.0.1:8787` with `registry = "https://current.example.org"` in the config (R-RG1: the variable wins). `https_current.example.org` (all old) is another registry and goes. The dir of the run (all files old) stays with `toolchains.json`, its 2 old pages go. | R-GC15 R-RG1 R-IX5 | red |
| L2 | run 5: `--registry direct`. No dir is the dir of the run (R-IX5): 2 old dirs go, one dir with a young file stays. No listing of a `get/` dir. | R-GC15 R-IX5 R-RG1 | red |
| L2 | run 6 (Q1): `registry = "ftp://bad"` in the config of `h4`, which has an old dir of another registry. Exit 19, stderr has the R-RG7 row 6 line and the hint line `A newer tln may know this value. Update tln: tln tool update talon`, calls.log ends after the read of `config.toml` (no listing), tree unchanged. | R-GC15 R-RG7 R-TF4 R-TF8 | red: exit 0, `nothing to remove` |
| L2 | The 10 old cases of `gc/` (and the other cases that run `cache gc`) | R-GC1 to R-GC11 | green. They have no dir `registry` in `talon/index`, so they get no new call (requirement for the code, see Code proposal). |

Result of the runs (before any code change):

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | 44 tests: 39 pass (BotTest, NewerhintTest, TlngateTest, TlngatepureTest), 5 compiler errors (the 5 expects of GcindexTest: unknown names `Gc.index_pages`, `Gc.index_dirs`). The compile error is on purpose (as slice 236). The other modules of the driver fail to run while the file does not compile: the code agent adds the 2 names first. |
| `roc fmt --check tests/unit/GcindexTest.roc` | valid |
| `tests/commands/run.sh gc` | 10 old cases pass, `gc15-registry-copies` fails on the missing behavior only: the file tree (nothing deleted), the report, the 3 missing call lines of each run |
| `MISSING=1 scripts/rules.sh R-GC` and `R-IX` | no id listed (R-GC15 is named by the tests) |
| Check of the tests (scratch copy of cli/lib outside the repo, crash stubs, then a throwaway implementation of the 2 functions) | with the stubs: 4 tests crash. With the throwaway body: 4 pass. 3 mutations fail 2 of the 4: the edge `>=`, no skip of the dir of the run, the age taken from the body file in place of the meta. The scratch copy is not in the repo and is not a proposal for the code. |

How the L2 expected `calls.log`, `stdout`, `stderr` and `tree.diff` were made: the baseline of the current code (`UPDATE=1` on a scratch copy of the case) is the old calls plus nothing new. I added by hand the lines of the new calls (below), and the sizes from `wc -c` of the fixture files. The `tree.diff` is the diff of the given tree against the given tree minus the deleted files (`tree_diff` of tests/lib.sh). Q4 says what the code agent does when its calls differ.

## Changed expectations

None. No existing expected file changes. `gc/gc15-registry-copies` is a new dir, `GcindexTest` is a new file.

## Code proposal

| Item | Proposal |
| --- | --- |
| The registry of the run | `gc_flow!` gets `IndexQuery.setting({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry })`. The result is `[Direct, Registry(origin)]`. See Open Q1 for a bad value. |
| New calls, in order | (a) Only when the listing of `talon/index` (the first `list_dirs!` result, `scan_dirs`) has a dir named `registry`: one `list_dirs!([<index>/registry])`. (b) Only when the run has a registry (not `Direct`) and (a) lists the dir `RegistryCache.origin_dir` of it: one `list_dirs!([<origin dir>/get])`. Both come right after the listing of `roots.build` (step 5b) and before the read of `projects.json`. No new call for a cache with no `registry` dir, so the 10 old cases keep their `calls.log`. |
| Decisions | `Gc.index_dirs` gives the candidate dirs. Their asks go in the one `tree_info!` call, and `Gc.expired` (span: the GC age, the real clock as for build dirs) gives the dirs that go. `Gc.index_pages` gives the page files. Their asks (only the files that go) go in the same `tree_info!` call. |
| Order of the asks and of the report | In `builds`: the build-cache dirs, the `x` dirs, then the registry dirs (sorted), then the page files (sorted). So the `tree_info!` asks are: the toolchains, compat, stale, then these (the candidate dirs are all asked, only the dirs that go are in the report), then the packages. |
| Delete | The existing one `delete!` of step 10: the paths join `builds`, so they come after the build dirs. No lock or extra step: GC holds the GC lock already, and a page is written whole (R-CC1, R-CC11). |
| Report | No new line form: `removed <path> (<size>)` for each item of `builds`, as the `x` dirs of slice 049. A page is 2 lines. |

## Output (proposed, TW24)

| Item | Proposal | Why |
| --- | --- | --- |
| Text of a removed dir or page file | `removed <path> (<size>)`, `would remove <path> (<size>)` in a dry run. One line for each path, so a page is 2 lines (its `.json` then its `.meta`). | The form of all other paths (R-OUT2). The alternative is one line for a page: it needs a new list. |
| `--json` | The paths are in `data.builds`, and each has a row in `data.sizes` (the same as the `x` dirs). No new key. | Slice 049 did the same. The alternative is a new key `index` (an array of paths). That changes `Gc.Done` and its L0 tests. |
| `freed` | The sum of the sizes of these paths joins the total. | R-GC11 |

## Mutation plan (TW12, for the code agent after green)

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | The page edge is `>=` | GcindexTest expect 1, 2 and 3 (the exact-age page), gc15 run 1 (page 3) |
| m2 | The dir of the run is not skipped | GcindexTest expect 4 and 5, gc15 run 4 (`toolchains.json` stays) |
| m3 | The age of a page is read from the body file | GcindexTest expect 1 (pages 1 and 6), gc15 runs 1 and 2 |
| m4 | A page removes only its meta (or only its body) | gc15 `delete` line and `tree.diff` |
| m5 | A dir of another registry goes at any age | gc15 `http_127.0.0.1_8787` and `https_edge` stay, run 5 `https_new` stays |
| m6 | `talon/index/github/` is judged too | gc15 `repo.json` stays |
| m7 | `toolchains.json` of the registry of the run is removed with its old pages | gc15 run 4 and run 1 (`toolchains.json` of the current dir stays) |
| m8 | `Direct` keeps a dir | gc15 run 5 |
| m9 | The registry of the run ignores `TALON_REGISTRY` or the flag | gc15 runs 4 and 5 |
| m11 | The registry key is not checked, or GC removes first | gc15 run 6 |
| m12 | A half page is not aged by its own file | GcindexTest expect 2 |
| m10 | A listing is made when `talon/index` has no `registry` dir | the 10 old gc cases (`calls.log`) |

Revert only these entries, filtered (the memory rule: no full sweep).

## Verify

Not run yet (the code agent runs: check, fmt, selftest, l0, l2, l3, `MISSING=1 scripts/rules.sh R-GC R-IX`).

## Mutation results (research/slice-237-revert/mutate.sh)

The unchanged mirror passes l0-9 (44).

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | The dir of the registry of the run is a candidate | l0-9 (2 failed); gc15 (m1b) |
| m2 | A page is aged by its body, not its meta | l0-9 |
| m3 | A bad registry value does not stop GC | gc15 |
| m4 | Other registry dirs go with no age check | gc15 |
| m5 | Old pages are not removed | gc15 |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only). `MISSING=1 scripts/rules.sh R-GC R-IX R-RG`: no rule without a test. The test agent first wrote `expect/exit` 19 for gc15; the `commands` entry always exits 0, so it is 0 (manager review).

## Open

| Item | Owner |
| --- | --- |
| Q1 (DECIDED by the user, 2026-11-08, Design Q611 = G-C241). GC takes the registry in the full R-RG1 order. A bad value stops GC with the R-RG7 row 6 exit 19 error and the hint line, before it lists or removes anything. Test: gc15 run 6 (`h4`, `registry = "ftp://bad"`, exit 19, nothing listed, nothing removed). | closed |
| Q2 (DECIDED, Q611). Pages are aged only in the dir of the registry of the run. A dir of another registry goes or stays whole. | closed |
| Q3 (DECIDED, Q611). The report and `--json` form of the Output table is accepted: `removed <path> (<size>)`, `data.builds`, `data.sizes`. It goes to the user with the slice. | closed |
| Q4. The expected `calls.log` is derived by hand (the 2 new listings after the build listing, the page and dir asks in the one `tree_info`, the one `delete`). If the code agent needs another order, it tells the human before it edits the expected files (TW18). | Code agent, human |
| Q5 (DECIDED, Q611). Only `<32 hex>.json` and `.meta` names are pages. A half page is aged by the file that exists, by its own mtime: an orphan `.json` and an orphan `.meta`, old goes (that file only), young stays. Other names stay. Tests: GcindexTest expect 2. | closed |
| Q6 (DECIDED, Q611). The real clock and the file mtime. | closed |
| Q7. A dir of another registry that has no file (empty): `tree_info!` gives the time of the dir. Not tested (no new rule). | none |
