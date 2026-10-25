# 046b GC protects tool packages

Phase: P1. Status: dropped

Slice 046b makes `tln cache gc` keep the packages that the installed tools use (CLI 6.3 R-GC4, CLI 6.4 R-T4). The roots are the `source.url` of each entry of `tools.json`. They join the live projects in the walk of `Gc.protected` (slice 028b). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-046b-revert/before/` (with `NEW.txt`). Slice 046 (Q10, Q11) and the 028b review gave this slice its row in `PLAN-P1.md`.

## 0. What the design says (the answers to the manager notes)

| Question | Answer from the design | Effect here |
| --- | --- | --- |
| Does R-GC4 name the tools of `tools.json`? | No. R-GC4 names known projects and the `[tools]` bundle of a known project (R-PT14). The tool roots are the plan row of 046b (028b review, Q2). | G1 below: the text of R-GC4 needs the tools. The tests fix the plan row |
| Packages of project tools (`[tools]`, slice 056) | Covered already, but only for the bundle dir: R-PT14 says "R-GC4 keeps the extracted bundle `packages/<hash>/` of such a URL". Slice 056 does it with `ToolsHeld` (hashes, no walk). The packages that the bundle names (its platform) are not kept by 056. | Not changed here. G2 below |
| Packages of `x` cache entries (slice 049) | Not covered. R-GC7 removes an `x` entry by age. R-B9 puts the bundle hash in its manifest. No rule keeps `packages/<hash>/` for an `x` entry. | Question Q1 (TW17). The tests fix the default: not a root |
| A `talon` entry in `tools.json` | R-IS6: `tln setup` writes it, "source: install script" (6.5). It has no bundle URL. `ToolsJson.read` gives exit 19 for it today (slice 050 fixes `read`). | GC reads only `source.url` (`ToolsJson.bundles`). A tool with no url names nothing and is no failure. The form of the `talon` source is not in the design: the fixtures use `{"kind":"script","version":"0.3.1"}` as a placeholder (G3) |

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-GC4 (tools): a package is used when a bundle URL of `tools.json` names it, or when the header of such a bundle (or of a package that it names) names it | `Gc.protected` (new field `tools`), `ToolsJson.bundles`, `CacheGc` step 6b | L0 `ToolrootsTest` 1, 2. L2 `gc/gc7-tool-roots` runs 1 to 3, 6. L3 `cache/gc1-real` part 9 |
| R-T4: `tools.json` records the `source` of each tool (the url of a release bundle) | `ToolsJson.bundles` | L0 `ToolrootsTest` 1. L2 `gc7-tool-roots`. L3 part 9 |
| R-TF3 (as used): a text that does not parse, a newer `format`, or `tools` that is no object: exit 19, nothing is removed | `ToolsJson.bundles`, `CacheGc` | L0 `ToolrootsTest` 1. L2 `gc7-tool-roots` run 4. L3 part 9c |
| R-IS6 (as used): the `talon` entry (no url) names nothing and does not stop GC | `ToolsJson.bundles` | L0 `ToolrootsTest` 1. L2 `gc7-tool-roots` runs 1 to 3 |
| R-GC4 (age, gate of D9 of slice 028b): no package dir can go: no read of `tools.json` | `CacheGc.protect!` | L2 `gc7-tool-roots` run 5. The old cases `gc/gc3-caches` run 5, `gc/gc4-x`, `gc/gc6-held-no-package` (no new line) |

Other rules that the cases touch: R-GC9, R-GC11, R-J3, R-PD9, R-PD12, R-GC7 (the `x` entry `kx` stays by its age), R-LY7 (`tools.json` is in the data dir).

`MISSING=1 scripts/rules.sh R-GC R-T` lists only R-T22 (slice 050, not this slice).

## 2. Flow of `tln cache gc` after this slice (the change to the table of slice 028b)

| Step | Change | Rule |
| --- | --- | --- |
| 6b | Only when the listing of `roots.pkgs` has a package dir that can go (as 028b): first one `read_files!` of `Roots.item(roots, ToolsJson)` (`<data>/talon/tools.json`), then `ToolsJson.bundles` of the answer, then the walk of `Gc.protected` over the live projects and the tool roots. A failure of `bundles` ends the run with nothing removed (exit 19). No lock for the read. The read is made also when no project is live. | R-GC4, R-T4, R-TF3 |

The rest of the table is the same. The step 8 (`aged!`) is not changed: the `held` hashes of slice 056 and the walk result are two lists that join in `protected`.

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/ToolsJson.roc` | 367 (+14) | Test agent, stub | New public `bundles` (`crash "todo: slice 046b"`), with the contract table in its doc |
| `cli/lib/Gc.roc` | 339 (+1) | Test agent | `Gc.protected` takes `tools : List(Str)`. The body is the old body (it ignores `tools`). The doc table has the new rules 1b, 3, 4, 5 |
| `cli/lib/CacheGc.roc` | 239 (0) | Test agent | The call `Gc.protected` passes `tools: []`. The doc row 6b has the new flow. The code agent writes `protect!` |
| `tests/unit/ToolrootsTest.roc` | 98 | Test agent | New unit module, 2 `expect`s. In the driver `l0-6.roc` (the smallest time in `.work/l0-times`) |
| `tests/unit/l0-6.roc` | +1 | Test agent | `import ToolrootsTest` |
| `tests/unit/GcTest.roc` | 457 (0) | Test agent | Row 7: the 6 calls of `Gc.protected` have `tools: []` (the old rows are the same) |
| `tests/commands/cases/gc/gc7-tool-roots/` | 20 given files, 6 runs | Test agent | New L2 case. The fixtures are made by `research/slice-046b-revert/mk-fixtures.py` |
| `tests/commands/cases/gc/gc1-select/`, `gc3-caches/`, `gc5-project-tools/` | `expect/calls.log` only | Test agent | One new line `read_files $HOME/.local/share/talon/tools.json` in each run that walks (TW21, section 8) |
| `tests/scenarios/cache/gc1-real/` | `cmd` 130 (+23) | Test agent | New part 9 (`expect/stdout`, `stderr`, `tree.diff` have only added lines) |
| `research/slice-046b-revert/` | | Test agent | `before/` (and `NEW.txt`), `expect-before/` (the old expected files, TW21), `stubs/`, `reference/` (private, kept until the manager's review is applied), `swap.sh`, `mk-fixtures.py`, `mutate.py`, `results.md`, `mutate-run-1.log`, `red.log` |

No change to `scripts/`, `tests/commands/*.roc`, `tests/run.sh`, `Fx`, `RealFx`.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `ToolsJson.bundles` | `{ path : Str, text : Try(Str, [NotFound, Denied, Other(Str)]) } -> Try(List(Str), Fail)` | R-GC4, R-T4, R-TF3 |
| `Gc.protected` | `{ projects : List(Gc.Project), tools : List(Str), nodes : List(Gc.Node) } -> [Need(List(Str)), Done(List(Str))]` (the new field is `tools`) | R-GC4 |

`ToolsJson.bundles` rules (the table is in its doc comment):

| Text | Result |
| --- | --- |
| `NotFound`, `Denied`, `Other`, no `tools`, `"tools":{}` | `Ok([])` |
| A tool whose `source` is an object with a text `url` (any `kind`) | its `url`, in the order of the text |
| A tool with no url (git, the `talon` entry), a url that is no text, a `source` that is no object, no `source`, a tool that is no object | nothing, no failure |
| Not JSON, no integer `format` | Input (exit 19): `<path>: the content does not parse` |
| `format` above 1 | Input: `<path>: format <n> is newer than this tln (format 1). Run: tln tool update talon` |
| `tools` is no object | Input: `<path>: tools is not an object` |

`Gc.protected` rules (the table in its doc comment, new rows 1b, 3, 4, 5):

| Rule | Text |
| --- | --- |
| 1b | Each bundle URL of `tools` is a root as if a project header named it. A value that is a release URL names its hash. A value that is no release URL names nothing |
| 3 | The header of a bundle is a release header: a path value in it is ignored (it names a file inside the bundle) |
| 4 | `Need` order: the entries of the projects, then the bundle URLs of the tools in their order, then the entries of the nodes. Each id is asked once |
| 5 | `Done`: also the hash of each tool bundle URL. Sorted, each once. A bundle that cannot be read still names its hash |

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/ToolrootsTest.roc` 1 (`bundles`) | 11 rows: `NotFound`, `Denied`, `Other`, no `tools`, empty `tools`, one release, a mixed file (a git tool, the `talon` entry, 4 odd entries, a release with an unknown `kind`: urls in the order of the text), only git and `talon`, not JSON, `tools` that is a list, `format` 2 | R-GC4, R-T4, R-TF3, R-IS6 |
| L0 | `ToolrootsTest` 2 (`protected` with `tools`) | 3 steps of the walk with a project and 5 tool values (a url twice, a url that is no release URL, a url that a project names too): the order of `Need` (projects first), the closure of a bundle (its platform, a package that the platform names), a bundle that cannot be read, a path value in a bundle header; only tools with no project (2 steps); a tool that is no release URL; no tool and no project | R-GC4 |
| L0 | `tests/unit/GcTest.roc` 7 (changed) | the same rows as in 028b, with `tools: []` | R-GC4 |
| L2 | `gc/gc7-tool-roots`, 6 runs | 1 `--dry-run`: one read of `tools.json`, the walk (P1, TA, TB, then PFT, then DEP), the 4 packages that go (PB, PG, PX, PU), the `x` entry `kx` stays. 2 `--json` the real run. 3 again: nothing, the read is made again. 4 home `h2`: `format` 2, exit 19, no `tree_info`, no `delete`. 5 home `h3`: `tools.json`, no packages dir: no read. 6 home `h4`: no `projects.json`, TA and PFT stay, PU goes | R-GC4, R-T4, R-TF3, R-IS6, R-J3 |
| L2 | `gc/gc1-select`, `gc3-caches`, `gc5-project-tools` (expected `calls.log` changed) | one new read line in each run that walks | R-GC4 |
| L3 | `cache/gc1-real` part 9 | the real binary and the real Fx: `tools.json` with a release tool, a git tool and the `talon` entry. A dry run and a real run remove only the old package that no root names. TA and PFT stay. 9c: a newer `format` is exit 19, nothing is removed | R-GC4, R-T4, R-TF3 |

Count: 2 new L0 `expect`s (`ToolrootsTest`), 1 old `expect` changed (`GcTest` 7). 1 new deep L2 case (6 runs), 3 old L2 cases with a changed `calls.log`, 1 new part in a deep L3 case. No selftest row. The case `gc7-tool-roots` fixes the order of the `Fx` calls: it is the one place that checks the gate, the position of the read and the walk.

## 6. Output (proposed, R-OUT2, TW24)

No new output text and no new `--json` field. `data.packages` and the report list the packages that go, as before. The only new text is the exit 19 line, which is the text of `ToolsJson.read` (R-TF3): `tln: error[input]: <data>/talon/tools.json: format 2 is newer than this tln (format 1). Run: tln tool update talon`. The human accepts or changes it at the review.

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The root of a tool is the text `source.url` of each entry (any `kind`), and the walk follows its header like any package (the platform, and the packages that it names). | The hash of the bundle only (no closure, as the `[tools]` of slice 056). Only `kind` release. The `build.hashes` list (Q3) |
| D2 | `ToolsJson.bundles` is a new lenient reader. A tool with no url names nothing. | `ToolsJson.read`: exit 19 for the `talon` entry until slice 050 |
| D3 | A `tools.json` that cannot be read (`Denied`, `Other`) names nothing (as D8 of 028b for a project file). A bad text or a newer `format` is exit 19 and nothing is removed (R-TF3, as `projects.json` in slice 028). | Ignore a bad file (GC never fails for it). Keep all packages when the file is bad |
| D4 | `tools.json` is read only when a package dir can go (the gate of D9 of 028b). A bad file stops GC only then. | Read at each run (a new line in every `calls.log`, also where no package exists) |
| D5 | The read comes first (before the first `Need` of the walk) and also when no project is live: the first `Need` has the project roots and the tool roots in one `read_files!`. | A walk for the tools after the walk of the projects (2 passes) |
| D6 | `Gc.protected` takes the urls (`tools : List(Str)`), and filters by `Ident.of_url` itself (a pure decision, tested in L0). | `tools : List(ToolsJson.Entry)`. A filter in `ToolsJson.bundles` |
| D7 | No lock for the read of `tools.json`. R-CC6 locks a change. Every write is a rename (R-CC1), so a read sees the old file or the new file. | The `tools.json` lock around the read (it would wait for an install) |
| D8 | An `x` entry does not keep its bundle (Q1). A project tool is as 056 made it (Q2). | See Q1, Q2 |
| D9 | The tool packages are protected only by the age rule of R-GC4: the 1 day rule for a package that changed is the same for all packages. | |

## 8. Old cases that change (TW21)

| Case | Change | Reason |
| --- | --- | --- |
| `gc/gc1-select` `expect/calls.log` | 4 new lines `read_files $HOME/.local/share/talon/tools.json`, one before each walk read (the 4 runs that read a package header) | The new step 6b read |
| `gc/gc3-caches` `expect/calls.log` | 4 new lines, the same | The same |
| `gc/gc5-project-tools` `expect/calls.log` | 3 new lines, the same | The same |
| `gc/gc2-busy`, `gc4-x`, `gc6-held-no-package`, `gc3-caches` run 5, L3 `cache/gc1-real` parts 1 to 8 | No change (no package dir that can go, or a busy run, or the same output) | The gate (D4) |

The old `expect/` files are in `research/slice-046b-revert/expect-before/` (`l2/<case>/expect`, `gc1-real/`). `diff -r` against the new files shows only the added lines (the L3 case: the new part 9 and its tree diff). They were made with `UPDATE=1` by the private reference, only for these 4 cases, and read by eye.

## 9. Out of scope

| Id | Reason |
| --- | --- |
| R-GC7 | Slice 049, not changed |
| R-PT14, the closure of the bundle of a project tool | Slice 056 (G2) |
| The parse of the `talon` entry by `ToolsJson.read`, its source form | Slice 050 |
| R-T22 | Slice 050 (no test names it today, not a rule of this slice) |
| The race of a `roc` build that uses a package that GC removes | R-CC10 (028b) |
| Tool packages in a real GC with a real network | Not needed: GC never fetches |

## 10. Questions (TW17, the tests fix the default; a different answer changes the rows)

| # | Question | Default (tested) | Other option, and the rows that change |
| --- | --- | --- | --- |
| Q1 | Is the bundle package of an `x` cache entry (R-B9, `manifest.bundle`) a root? The design gives no rule. A kept entry has its binary, so `tln x` needs no bundle. A rebuild of the entry needs it again (a fetch, R-DI7). | Not a root. `kx` stays by its age, its bundle PX goes | Protect the `bundle` of each entry that GC keeps. L2 `gc7-tool-roots` runs 1 to 3 (PX stays), the order of the reads changes (the manifests are read after the walk today), L3 none |
| Q2 | Does R-PT14 mean the closure of the bundle of a project tool (its platform) too? Today 056 keeps only the bundle dir (hashes), while a global tool keeps its closure (D1). | As 056 made it (the bundle dir only) | Give the `[tools]` urls of the live projects to `Gc.protected` as `tools` (the `url` of each entry, not the hashes). L2 `gc5-project-tools`, `gc6-held-no-package` and the unit rows of slice 056 (`ToolsplanTest` 11, 15, 17) change |
| Q3 | Should the `build.hashes` of `tools.json` be roots too? A git tool has no bundle dir (its source is not in `packages/`), so its platform and packages are named only by `build.hashes`. The same for a release tool whose bundle dir was removed (the header cannot be read). | No (the plan row names `source.url`). In `gc7-tool-roots`: PB (platform of `tb`, the bundle TB is missing) and PG (platform of the git tool) go | Add the hashes. `ToolsJson.bundles` gets a second list or a new function, `Gc.protected` takes hashes, L0 `ToolrootsTest` 1 and 2, L2 `gc7-tool-roots` (PB, PG stay) |
| Q4 | A bad `tools.json` (not JSON, newer `format`): exit 19 and nothing is removed (D3), as `projects.json`. | Exit 19 | Ignore the file (no roots): L0 `ToolrootsTest` 1 (3 rows), L2 `gc7-tool-roots` run 4, L3 part 9c |
| Q5 | Read `tools.json` only when a package dir can go (D4)? | Yes | Always: a new line in each `calls.log` that does not walk (`gc2-busy`, `gc4-x`, `gc6`, `gc3-caches` run 5), L2 run 5 of `gc7` |

## 11. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-GC4 names known projects and `[tools]` bundles only. It does not name the tools of `tools.json`. Proposed text: "The bundle of a tool of `tools.json` (6.4, R-T4) and the packages that its header names count as used." (the plan row of 046b is the source today) |
| G2 | R-PT14 keeps the bundle dir of a project tool only. A global tool (046b) keeps its closure. The two rules are not the same (Q2) |
| G3 | The source form of the `talon` entry (R-IS6, "source: install script") is not in the design. 046b needs only that it has no `url`. Slice 050 fixes the form. |
| G4 | R-GC4 and R-GC7 do not say what an `x` entry keeps (Q1) |
| G5 | R-TF3 says "stops with exit code 19" for each file that Talon cannot make again. It does not say if GC, which only reads `tools.json` to protect packages, must stop (Q4) |

## 12. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| `app` is reserved, also as a local function name | The test helper for a header is `proj` |
| An `Err` record with a `Bool` field in `roc test`, and a literal `Bool.False` in an `if` | Not used. The tests compare texts and lists. The mutation C3 used `tools.drop_first(100)` (an unused variable is a warning) |
| The ancestor paths in `calls.log` (`/tmp/talon-l2/talon.toml`) depend on `TMPDIR` (slice 056 has the same note) | The L2 runs for the expected files used `TMPDIR=/tmp` |

## 13. Red output

`scripts/test.sh` with the stubs (log `research/slice-046b-revert/red.log`): check pass (1.8 s), fmt pass, l0 FAIL (7.3 s), l2 FAIL (8.9 s), l3 FAIL (9.9 s), selftest pass, l1 pass. The old tests all pass.

| Layer | Result | Reason |
| --- | --- | --- |
| l0 `l0-6.roc` | 2 of 55 fail (`ToolrootsTest` 1 and 2) | 1: `Roc application crashed with this message: todo: slice 046b` (the stub `bundles`). 2: a wrong value (the old body of `protected` ignores `tools`: `step0` is `Need([pf, core])`) |
| l0 other drivers | pass (`l0-7`: 64 passed with `GcTest` 7 changed, `l0-8`: 77) | |
| l2 | 142 passed, 4 failed: `gc/gc1-select`, `gc/gc3-caches`, `gc/gc5-project-tools`, `gc/gc7-tool-roots` | A wrong value: no read of `tools.json` in `calls.log` (and in `gc7` the 4 packages stay, run 4 is exit 0) |
| l3 | 76 passed, 1 failed, 1 skipped: `cache/gc1-real` | A wrong value: part 9 removes TA and PFT too (no tool root), so the `ls | grep` of part 9b finds nothing and the script stops (`sh -e`) before 9c |

With the private reference (`research/slice-046b-revert/reference/`): `l0-6` (55) and `l0-7` (64) all pass, L2 `gc/` 7 passed, L3 `cache/gc1-real` passed.

## 14. Revert check (TW12)

Method: `research/slice-046b-revert/mutate.py` puts the private reference into `cli/lib`, makes one change, runs `roc check cli/lib/main.roc`, then the layers (l0, then l2, then l3). The first failing layer ends the run. 10 mutations of the most tricky behaviors (user rule 2026-10-23), one after another, no full sweep. Result: 10 caught of 10 (`results.md`, `mutate-run-1.log`). After the runs, `cmp` of the 3 files against `reference/` shows no difference, and `swap.sh stub` put the stubs back.

| Id | Mutation | Caught by |
| --- | --- | --- |
| G1 | A tool value that is no release URL is a root | L0 `ToolrootsTest` 2 |
| G2 | The tool roots come before the project roots in `Need` | L0 `ToolrootsTest` 2 |
| G3 | The header of a tool bundle is not followed (no closure) | L0 `ToolrootsTest` 2 |
| J1 | `Denied` is an error | L0 `ToolrootsTest` 1 |
| J2 | A file with no `tools` field is an error | L0 `ToolrootsTest` 1 |
| J3 | The `talon` entry makes `bundles` fail (as `ToolsJson.read` does today) | L0 `ToolrootsTest` 1 |
| C1 | The read is made also when no package can go and a project is live (the gate) | L2 `gc/` (`gc3-caches` run 5) |
| C2 | A failure of `bundles` is ignored | L2 `gc/` (`gc7-tool-roots` run 4) |
| C3 | The tool roots are not given to the walk | L2 `gc/` (`gc7-tool-roots`) |
| C5 | The walk runs only when a project is live | L2 `gc/` (`gc7-tool-roots` run 6) |

L3 `gc1-real` part 9 was green with the reference and red with the stubs. No mutation needed it as the first catch (L2 fails first). A hand mutation for L3 alone is not made (no gap test).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `ToolsJson.bundles`, `Gc.protected` and the row 6b of `CacheGc` are the contract. `calls.log` of `gc7-tool-roots` fixes the order and the number of the calls. |
| N2 | `ToolsJson.bundles`: `open_file`, then `tools_of` (both private in `ToolsJson`), then the text field `url` of the object `source` of each tool. `Err(_)` of the text (`NotFound`, `Denied`, `Other`) is `Ok([])`. |
| N3 | `Gc.protected`: add `facts.tools.keep_if(|url| Ident.of_url(url).is_ok())` between the edges of the projects and the edges of the nodes. |
| N4 | `CacheGc.protect!` returns `Try(List(Str), Fail)`: the gate (`Gc.candidates` with no protected hash has a package), one `read_files!` of `Roots.item(roots, ToolsJson)`, `ToolsJson.bundles`, then the walk with `tools`. The call in `work!` gets a `?`. `walk!` has the new argument. |
| N5 | Do not edit a test (TW18). A question goes to the manager. |

## Dropped (manager, 2026-10-25)

The user dropped the slice. R-GC4 does not name `tools.json`, so tool packages are not GC roots, as R-T5 for the nightly: GC can remove them, and `tln tool rebuild` downloads them again. All code and test changes of this slice were undone. `research/slice-046b-revert/before/` is the record (the old files and `expect-before/`). The sections above are the record of the design work only.
