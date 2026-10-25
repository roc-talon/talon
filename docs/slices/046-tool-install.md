# 046 Tool install

Phase: P1. Status: code

Slice 046 is `tln tool install owner/app` for a release (CLI 6.4: R-CM16, R-T1 to R-T6, R-T8 to R-T12, R-T26 to R-T28; R-SE8, R-ST15, R-LY2, R-LY3, R-CC6): Talon reads the release list of a GitHub repo, takes the newest release that `min-release-age` allows and that has an app bundle, checks and extracts the bundle, reads the `roc:` pin of the app header, builds the app with that compiler (no `--target`), puts the binary in `<data>/bin/`, makes a hard link (else a copy) in the bin dir, and records the tool in `tools.json`. Only the last step runs under the lock of `tools.json` (R-CC6).

Size (TW19): the private reference had 1033 lines with comments and blank lines in 3 new modules (`ToolsJson.roc` 179, `ToolInstall.roc` 425, `ToolFlow.roc` 429), about 770 lines without comments, plus 2 lines in `main.roc` and 3 lines in `Run.roc`. The plan row says 400 lines. This is clearly over 500 lines of code (TW19), so a split is proposed in section 8 (Q10). No module is above 500 lines.

Live reads: none. No real network and no real long build in L0 to L3. The L3 case uses real `roc bundle` and real `roc unbundle` for 3 small apps. A compiler that the apps pin (`nightly-2026-10-14-38a3029`) is a shell script in the store of the case.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-CM16 | The command `tool install` and its flags | L0 `ToolTest` expect 1. L2 `ti1-install` runs 1 to 6 |
| R-T1 | Build from the app header as it is: hashes and `roc:` pin, no new resolve | L2 `ti1-install` run 1 (no probe of the project, one `roc build`). L3 step 1 |
| R-T2 | Only an app whose platform makes a native executable can be installed: a package bundle is dropped, a platform with only wasm targets is refused | L0 `ToolTest` expect 14. L2 `ti1-install` run 1 (1.2.0 is a package; the platform has native targets), `ti2-refusals` run 11 (a wasm platform) |
| R-T3 | Binary in `<data>/bin/`, hard link or copy in the bin dir, last step under the lock of `tools.json` | L0 `ToolTest` expect 6. L2 `ti1-install` runs 1, 5. L3 steps 1, 3 |
| R-T4 | `tools.json`: source, build id (hashes, nightly, target), sha256, libs, install time | L0 `ToolTest` expects 11, 12. L2 `ti1-install` runs 1 to 6. L3 steps 1, 3, 4 |
| R-T5 | The tool does not keep its nightly: the record has the compiler id | L0 `ToolTest` expect 12. L2 `ti1-install` run 1 |
| R-T6 | The pinned download follows R-DL1 to R-DL6. `--roc pinned` is consent | L0 `ToolTest` expects 1, 5. L2 `ti2-refusals` runs 6, 7 |
| R-T8 | No `--target`. A glibc build records `NEEDED` libs (not built: Q4) | L0 `ToolTest` expect 6. L2 `ti1-install` run 1. L3 step 1 (the log of the fake compiler) |
| R-T9 | `min-release-age` for no selector, `@latest`, a range. An exact version is installed and its age is printed | L0 `ToolTest` expects 3, 10. L2 `ti1-install` run 4, `ti2-refusals` run 4. L3 step 1 |
| R-T10 | The source is the app bundle (one asset, kind `app`). No candidate: exit 2 that names `--git owner/app@<tag or branch>` | L0 `ToolTest` expect 9. L2 `ti1-install` run 1, `ti2-refusals` runs 2, 3 |
| R-T11 | The compiler is the `roc:` pin | L0 `ToolTest` expects 5, 6, 8. L2 `ti1-install` run 1, `ti2-refusals` runs 5, 7, 8 |
| R-T12 | The pinned release is installed: build with it, no prompt | L0 `ToolTest` expect 5. L2 `ti1-install` run 1. L3 step 1 |
| R-T26 | `tln tool install foo` when foo is installed: no build or a replace | L0 `ToolTest` expect 4. L2 `ti1-install` runs 2, 3. L3 steps 2, 3 |
| R-T27 | One install for each name. A release install replaces a git install | L0 `ToolTest` expects 4, 12. L2 `ti1-install` run 5 |
| R-T28 | Binary name clash stops the install. `--as <name>` | L0 `ToolTest` expects 1, 2, 9, 13. L2 `ti1-install` run 6, `ti2-refusals` runs 1, 9. L3 step 5 |
| R-SE8 | The platform line and the build line on stderr before the build | L0 `ToolTest` expect 10. L2 `ti1-install` run 1. L3 step 1 |
| R-ST15 | The bin dir entry has the name of the tool (`.exe` on Windows) | L0 `ToolTest` expects 2, 6. L2 `ti1-install` runs 3, 5. L3 steps 1, 3 |
| R-LY2, R-LY3 | `tools.json` in the data dir, `bin/` in the data dir | L0 `ToolTest` expect 6. L2 `ti1-install` run 1. L3 step 1 |
| R-CC6 | `tools.json` lock for the last step only, the clash is checked again under it | L2 `ti2-refusals` run 9 (a hook adds a tool during the build). L3 step 4 (two builds at the same time) |
| R-ST6, R-ST7, R-ST11, R-ST12 (as used) | A bin dir entry that tln did not write stays. It is checked before the build and again under the lock. The entry is a hard link, else a copy, under a temp name, then renamed | L0 `ToolTest` expect 7. L2 `ti1-install` run 5, `ti2-refusals` runs 10 (before the build), 12 (under the lock). L3 steps 1, 3 |
| R-TF1 to R-TF3 (as used) | `format` 1, unknown fields stay, a newer format is exit 19 | L0 `ToolTest` expects 11, 12 |
| R-NM11, R-SC3 (as used) | The clash text names `--as`. A short name finds an installed tool | L0 `ToolTest` expects 9, 13. L2 `ti1-install` run 3 |
| R-DL1 to R-DL5, R-NM5 (as used) | The consent rows for the pinned compiler | L0 `ToolTest` expect 5. L2 `ti2-refusals` runs 6, 7 |
| R-J1 to R-J4, R-OUT2 (as used) | The envelope and the `data` | L0 `ToolTest` expect 10. L2 `ti1-install` run 6 |

`MISSING=1 scripts/rules.sh R-CM R-T R-SE R-ST R-LY R-CC` lists none of the rules of this slice (checked with the stubs in `cli/lib`). It lists R-T7, R-T13 to R-T15, R-T17 to R-T22, R-T24 and R-T25: they are out of scope (section 7).

## 2. Files

New files (also in `research/slice-046-revert/before/NEW.txt`). Lines of the stubs: the code agent writes the bodies.

| File | Lines | Content |
| --- | --- | --- |
| `cli/lib/ToolsJson.roc` (stub) | 71 | `tools.json`: types, `read`, `add`, `clash`, `entities` |
| `cli/lib/ToolInstall.roc` (stub) | 203 | The pure decisions: the operand, the key, the release choice, the reuse, the compiler, the consent, the paths, the build, the failures, the texts |
| `cli/lib/ToolFlow.roc` (stub) | 26 | The command code: `run!`. The calls in order are in the table of its doc comment |
| `tests/unit/ToolTest.roc` | 455 | 14 `expect`s |
| `tests/commands/cases/tool/ti1-install/` | 26 files | L2: 6 runs |
| `tests/commands/cases/tool/ti2-refusals/` | about 40 files | L2: 12 runs |
| `tests/scenarios/tools/ti1-tool-install/` | `cmd` 58, `given/` | L3: 5 steps |
| `tests/tools/mk-tool.sh` | 41 | Makes the release routes and the real app bundles of the L3 case |
| `research/slice-046-revert/` | | The private reference, the stubs, `restore.sh`, `mkstubs.py`, `gen-tools.py` (makes `given/` and `fx/` of the 2 L2 cases), `mutants.py`, `mutants.log`, the red logs, `expect-before/` (TW21) |

Changed files (a copy of each is in `research/slice-046-revert/before/`):

| File | Change |
| --- | --- |
| `cli/lib/main.roc` | exposes `ToolFlow`, `ToolInstall`, `ToolsJson` |
| `cli/lib/Run.roc` | `import ToolFlow`, and `args.command == ["tool", "install"]` calls `ToolFlow.run!` |
| `tests/commands/FakeJobs.roc` | a probe row can have a 4th field (the files that the fake build makes). A route that is a directory answers from `<dir>/@`. The index of the probe row counts only `check` probes of package files |
| `tests/commands/FakeFx.roc` | the doc rows of the two changes above |
| `tests/unit/l0-1.roc` | `import ToolTest` (the driver with the lowest time in `.work/l0-times`) |

Old L2 cases: no `expect/` changed (TW21: the old `expect/` files are the same after the changes of `FakeJobs.roc`, the whole L2 step passed, 119 passed and 2 failed, the 2 are the new cases).

## 3. Public signatures

`ToolInstall` and `ToolsJson` are pure (Part A). `ToolFlow.run!` is direct style over `Fx`. No new `Fx` call.

| Module | Name | Signature |
| --- | --- | --- |
| `ToolsJson` | `Source`, `Entry`, `Built`, `Clash` | types |
| `ToolsJson` | `read` | `{ path : Str, text : Try(Str, [NotFound]) } -> Try(List(Entry), Fail)` |
| `ToolsJson` | `add` | `{ path : Str, text : Try(Str, [NotFound]), built : Built } -> Try(Str, Fail)` |
| `ToolsJson` | `clash` | `{ entries : List(Entry), key : Str, name : Str } -> Clash` |
| `ToolsJson` | `entities` | `List(Entry) -> List(Lookup.Entity)` |
| `ToolInstall` | `Plan`, `Picked`, `Compiler`, `Layout`, `How` | types |
| `ToolInstall` | `read` | `Args -> Try(Plan, Fail)` |
| `ToolInstall` | `key` | `{ plan : Plan, name : Str } -> Str` |
| `ToolInstall` | `file_name` | `{ os : Setup.Os, key : Str } -> Str` |
| `ToolInstall` | `pick` | `{ name : Str, list : List(Index.Candidate), selector : Try(Selector, [None]), now : U64, min_age : U64 } -> Try(Picked, Fail)` |
| `ToolInstall` | `reuse` | `{ installed : Try(ToolsJson.Entry, [None]), selector : Try(Selector, [None]), first : Str } -> [Keep(Str), Build]` |
| `ToolInstall` | `compiler` | `{ pin : Try(Str, [NoPin]), installed : List(Str) } -> Compiler` |
| `ToolInstall` | `want` | `{ id : Str, roc : [Auto, Pinned], auto : [Ask, Yes, No], yes : Bool } -> [Install, Stop(Fail)]` |
| `ToolInstall` | `consent_stop`, `no_pin`, `clash_failure`, `elsewhere_failure`, `foreign_failure`, `no_candidate`, `build_failed` | the failures |
| `ToolInstall` | `native`, `not_native` | R-T2: `Try(List(Str), [NoSection]) -> [Native, WasmOnly(List(Str))]`, and the failure |
| `ToolInstall` | `layout`, `build_spec` | the paths and the probe of the build |
| `ToolInstall` | `verdict` | `{ old : Try(Str, [NotFound]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Make, Foreign]` |
| `ToolInstall` | `newest_tag`, `branch_of` | R-T10 |
| `ToolInstall` | `age_note`, `header_lines`, `report`, `data` | the texts and the `data` |
| `ToolFlow` | `run!` | `Fx, Args => I32` |

The stubs have the full signatures and the doc comments. The doc comments are the contract: the tables in them give the rows of each function.

## 4. Tests

Layers: L0 pure decisions (`ToolTest`), L2 the `Fx` calls and the files with a fake `Fx` (calls.log is the order of the calls), L3 the real `Fx` with fake HTTP and a fake compiler (TESTING.md 3).

| Layer | Where | Case | Rules |
| --- | --- | --- | --- |
| L0 | `ToolTest` expect 1 | `read`: the operand and the flags, 20 rows (the not-built flags, the operand count, a git sha selector, `--roc`, `--as` names) | R-CM16, R-T28, R-T6, R-SL1 to R-SL3 |
| L0 | expect 2 | `key` (default is the repo name, `--as`), `file_name` (`.exe`) | R-T28, R-ST15, R-LY7 |
| L0 | expect 3 | `pick`: the age, the boundary, a named young version, the 2 failures | R-T9, R-T10, R-C7, R-DI3, R-DI6, R-B2 |
| L0 | expect 4 | `reuse`: 10 rows (none, git, release, selectors) | R-T26, R-T27, R-B1, R-B2 |
| L0 | expect 5 | `compiler` (4 rows), `want` (7 rows: `--roc pinned`, `--yes`, `TALON_AUTO_INSTALL`, no answer, a release id) | R-T6, R-T11, R-T12, R-T16, R-DL1 to R-DL5, R-NM5 |
| L0 | expect 6 | `layout` (Linux, Windows) and `build_spec` (no `--target`, the timeout) | R-T3, R-T5, R-T8, R-T11, R-LY2, R-CC1, R-CC2, R-ST15, R-ST7 |
| L0 | expect 7 | `verdict`: 9 rows | R-ST6, R-ST7, R-ST11, R-ST12 |
| L0 | expect 8 | `build_failed`: 7 rows | R-T11, R-EC1, R-EC11 |
| L0 | expect 9 | the failure texts, `newest_tag`, `branch_of` | R-T28, R-NM11, R-CC6, R-T27, R-ST6, R-T10 |
| L0 | expect 10 | `header_lines`, `age_note`, `report`, `data` | R-SE8, R-T9, R-OUT2, R-J3, R-J4, R-OUT4 |
| L0 | expect 11 | `ToolsJson.read`: 12 rows | R-T4, R-T27, R-LY2, R-LY3, R-TF1, R-TF3 |
| L0 | expect 12 | `ToolsJson.add`: 9 rows and the line end | R-T4, R-T26, R-T27, R-TF1 to R-TF3, R-CC6 |
| L0 | expect 13 | `ToolsJson.clash` (6 rows), `entities` | R-T28, R-T26, R-T27, R-CC6, R-SC3 |
| L0 | expect 14 | `native` (6 rows) and the text of `not_native` | R-T2 |
| L2 | `tool/ti1-install` | 6 runs: install, again (no build), a named older version, a young named version, a git tool replaced (copy after a failed hard link), `--as q --json` | R-CM16, R-T1 to R-T5, R-T8 to R-T12, R-T26 to R-T28, R-SE8, R-ST7, R-ST15, R-LY2, R-LY3, R-CC6, R-J1 to R-J4 |
| L2 | `tool/ti2-refusals` | 12 runs: early clash, no app (names `--git <name>@<tag>`), no release (names the default branch), all young, no pin, pin missing with no consent (exit 13), `--roc pinned` (download then build), build with 5 errors (exit 11), clash under the lock (a hook), foreign bin dir entry before the build (run 10: no fetch, no probe, no lock), a wasm platform (run 11, exit 2, no build), a bin dir entry that becomes foreign during the build (run 12, a hook, found under the lock) | R-T2, R-T6, R-T9 to R-T12, R-T28, R-CC2, R-CC6, R-ST6, R-ST11 |
| L3 | `tools/ti1-tool-install` | 5 steps with the real `Fx`, the real curl and `roc unbundle`, a fake compiler. 1 install (one file for both names, `tools.json`, build log). 2 again (no download, no build). 3 older version replaces (one file again). 4 two installs at the same time (R-CC6: the fake compilers wait for each other). 5 clash exit 2, `--as` | R-T1, R-T3, R-T4, R-T8 to R-T11, R-T26 to R-T28, R-ST7, R-ST15, R-CC1, R-CC6, R-SE9 |

The L2 cases print their run table in `rules`. The expected files of L2 and L3 were written with `UPDATE=1` from the reference and read by eye against the design (TW21). The hashes of the L2 fixtures are `base58(sha256(label))`, so they are valid package hashes. The L3 bundles are made by `tests/tools/mk-tool.sh` (the real `roc bundle`: the same source gives the same hash). The platform of each L3 app is a file of the bundle (`pf/main.roc`, a path entry), so the L3 case has no platform fetch: the check of R-T2 is in L2 (the fake `Fx` has the platform bundles of `ti1-install` and `ti2-refusals`).

## 5. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stdout, installed | `installed <key> <version> (<name>)` |
| stdout, replaced | `replaced <key> <old> with <version> (<name>)`. A git tool is `git <ref>` |
| stdout, present (R-T26, text from the design) | `<key> <version> is installed` |
| stderr, before a build (`--quiet` hides them) | `platform <url> (hash <hash>)` (only `platform <value>` for a value that is no release URL, no line for an app with no platform), then `building <name> <version> with <compiler id>` |
| stderr, a young named version (R-T9) | `<name> <version> was released at <time>, less than min-release-age ago. It is installed because the version is named.` |
| stderr, other URL forms | the note of `Index.new_entry` (`<name> also has releases in other URL forms: ...`) |
| `--json` | `data` has `tool`, `name`, `version`, `how` (`installed`, `replaced`, `present`), `previous` (null or the old version), `bin`, and for a build `url`, `nightly`, `target`, `sha256`, `entry` (`hard_link` or `copy`) |
| `tools.json` | One line: `{"format":1,"tools":{"<key>":{"name","source":{"kind":"release","version","url"},"build":{"hashes":[...],"nightly","target"},"sha256","libs":[],"installed_at"}}}` |
| Errors (all exit 2 unless the table says) | `<key> is the binary name of <taken> already. Use --as <name> to install <name> under another binary name.` `<name> is installed as <key> already. Remove it first: tln tool remove <key>`. `<path> is not a file that tln wrote, so tln does not replace it. Use --as <name> to install under another binary name.` `<name> has no release with an app bundle. tln does not build from source by itself. Run: tln tool install --git <name>@<tag>` (no release: `<name> has no release. ... --git <name>@<default branch>`). `no release of <name> is old enough for min-release-age`. `<name> has no release <v>` and `<name> has no release in <range>`. `<name> <v> has no roc: pin in its app header, so tln cannot tell which compiler to build with`. `tln tool install <flag> is not built yet`. The pinned compiler with no consent: exit 13, `the compiler <id> is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes. (--roc installed tries the installed compilers.)`. A build with errors: exit 11, `the build of <name> <v> with <id> failed: <n> errors: <title of the first>`. A wasm platform (R-T2): `<name> <v> needs the platform <hash>, which has no native target (targets: wasm32). tln tool install makes a command line tool, so it needs a native platform.` |

## 6. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected | Why |
| --- | --- | --- | --- |
| D1 | The default binary name is the repo name (`acme/foo` is `foo`) (Q1) | The full name, the first part, the app name from the header | The design names no default. The fixtures use `foo`, `baz`, `qux` so that a different default shows in the tests (the tests name the default in L0 expect 2) |
| D2 | The same app under another key is exit 2, `elsewhere_failure` (Q2) | A second entry, a rename | R-T27 says one install for each name. Untested in L2 (L0 expect 9, 13 only) |
| D3 | A header with no `roc:` entry is exit 2 (Q3) | Use the compiler of the run, use the default compiler | R-T11 says the compiler is the pin. No pin: no rule |
| D4 | `libs` is `[]`. No `NEEDED` list (Q4) | Read the ELF file | No `Fx` call reads the bytes of a file. R-T8 is partly built |
| D5 | With a person and no flag the stop is the same as with no person: exit 13 (Q5) | A prompt | R-NI8 is slice 047. Untested |
| D6 | The build timeout is 3600 s, `--opt=speed` is explicit (Q6) | The 30 s of a probe (R-RC3), no `--opt` | A tool build is long. Untested but in `build_spec` (L0 expect 6) |
| D7 | A build with errors is exit 11 (`app_error`). A hang, a crash, no fact and no output file are exit 1 (Q7) | Exit 1 for all | R-EC11 gives 11 for an app that fails. The design gives no code for a tool build |
| D8 (changed in the review) | A foreign file in the bin dir is exit 2. The check is made before the download and the build (fail fast, no build call), and again under the lock after the build (the file can appear during the build) | A warning and a skip | R-ST6 says never overwrite. The early check saves the build time. `entry_verdict!` is one function for both |
| D9 | R-T26 is online first: the first candidate of the selector is compared with the installed version. An installed git tool is always built again | Offline first, an app check of the candidate | R-B1 and R-B2 need the newest release in the range. With the cached list `--offline` works |
| D10 | "The newest release tag" of R-T10 is the candidate with the latest `published_at`. With no release, `GET <api>/repos/<owner>/<repo>` gives `default_branch`, else the text names `<branch>` | A tag from the list of all releases | The list of candidates is what the tool has. The extra request is needed only on the failure path |
| D11 | `--git`, `--path`, `--resolve`, `--roc installed` and a git sha selector are exit 2 `... is not built yet` | Accept and ignore | They are slices 047, 048 and later |
| D12 | The binary is copied (not moved) from `<cache>/talon/tmp/<hex>/<file>` to the data bin dir, then the temp dir is deleted, also after a failure (R-CC2) | A rename of the temp dir | The cache and the data dir can be on two file systems |
| D13 | The URL in `tools.json` is the bundle URL that `Index.candidates` makes (`https://github.com/<o>/<r>/releases/download/<tag>/<hash>.tar.zst`). `hashes` are the hashes of the release URL entries of the header, in header order | The tag only | R-T4 says "source". The hash in the URL is the bundle |
| D14 | The L3 case has a `curl` in its bin dir that changes the prefix `https://github.com/` to the fake server | A change of `Index` | Talon makes the URL from the repo, the tag and the hash (R-DI5), so a list cannot point to the fake server |
| D15 | `ToolsJson.add` replaces a known tool in its place and keeps the fields of the tool that tln does not know (R-TF2) | Replace the whole object | R-TF2 says a field that tln does not know stays when tln writes the file |
| D16 | A platform with `targets: {}` (no names) is admitted, like a header with no readable `targets`. Only a non-empty list whose names all start with `wasm` is refused | Refuse an empty list | The review text refuses "only wasm names". An empty list has none |
| D17 | The platform is fetched with `Fetch.packages!` before the compiler step (it stays in the cache: `roc build` needs it too), only when the `pf` entry is a release URL. A path entry is admitted with no call | Read the platform after the build | R-T2 must stop before a long build |

## 7. Out of scope

| Rules | Reason |
| --- | --- |
| R-T13 to R-T21, R-NI8, R-NI9 | Slice 047: the prompts and `--roc installed` |
| R-T7, R-T22 to R-T25 | Slice 048: `tool ls`, `update`, `rebuild`, `rm`, `--git` |
| R-B1 to R-B10 (except R-B1, R-B2 as used), R-X | Slice 049: `tln x`, the take-over of known project entries |
| R-PT | Slice 056: `[tools]` in `talon.toml` |
| R-T1 `--resolve` | Slice 048 and later: refused here |
| R-T8, the ELF `NEEDED` list | Q4: no `Fx` call reads the bytes of a file |
| GC protection of the packages that an installed tool uses (028b review) | Proposed slice 046b (section 8) |

## 8. Questions (TW17) and design gaps

| # | Question or gap | What the reference does |
| --- | --- | --- |
| Q9 (answered in the review) | R-T2: how does Talon know a native platform? | Answer: `BuildTarget.targets_of` (slice 054). Built, see D16, D17 |
| Q10 | Size: the reference is about 770 lines of code in 3 modules (plan: 400). A split? | Proposal: slice 046 as written (3 modules under 500 lines, one flow), and slice 046b for the GC part (below). A second cut is possible after 046: `no_candidate!`, `branch!` and the `want` path (about 110 lines) as 046c. It would split `ToolFlow`, so it is not proposed |
| Q11 | 028b review: `Gc.protected` must protect the packages that an installed tool uses | Not in this slice. Slice 046b: `Gc.protected` gets the tool roots (the bundle hash of each `source.url` in `tools.json`). It changes the signature of `Gc.protected`, `CacheGc` reads `tools.json`, and the `calls.log` of the old gc cases change (TW21). No test and no stub now |
| G1 | R-FE4: `Fetch.packages!` uses `roc` from `PATH` for the unbundle. A tool install on a machine with no `roc` on `PATH` fails | The L3 case has the fake `roc` on `PATH` with a `real` rule for `unbundle` |
| G2 | R-B3: a yank note does not apply in `direct` mode | None |
| G3 | The first compiler installed (here the pin of an app) becomes the default compiler when `config.toml` has none (R-SO15, `RocInstall.install_offer!`), also if another compiler is installed. A tool pin can change the default compiler of the user | The existing behavior. L2 `ti2-refusals` run 7 shows it (`config.toml` with `default-roc`). The human can decide at the review |
| G4 | The design has no text for a `format` newer than 1 of `tools.json` except R-TF3 | `<path>: format <n> is newer than this tln (format 1). Run: tln tool update talon` (exit 19), from `TalonFile.open` |

## 9. Compiler and tool limits met

| Limit | What we did |
| --- | --- |
| `roc fmt` writes the pin of the pinned compiler in the `roc:` entry of any app `.roc` file outside `given/` (and `scripts/test.sh` runs `fmt --check` on them) | The sources of the apps in the L2 cases are `.src` files |
| `Probe.Err` is an alias, not a nominal type | The tests use a record |
| A closed record parameter does not take a wider record, `{ x }` alone is a block, a local name equal to a method of its type module is a duplicate, `with` and `platform` are reserved words | The code and tests avoid them |
| `roc test` crashes with an `Err` record that has a `Bool` field | The tests compare texts |
| The generated header of an app, formatted by `roc fmt`, has the entries in alphabetical order (`dep0` before `pf`) | `hashes` are in header order, whatever the order |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Where | `cli/lib/ToolsJson.roc`, `ToolInstall.roc`, `ToolFlow.roc` (stubs). `Run.roc` and `main.roc` are done |
| Order of the calls | The table in the doc comment of `ToolFlow`. The L2 `calls.log` files are the exact order, and `ti2-refusals` run 9 has a hook line (an `Fx` call of another process) |
| Reuse | `Github.releases!`, `Index.candidates`, `Fetch.packages!`, `Release.read`, `Locked.read`, `Lookup.find`, `Launch.toolchains!`, `Launch.program!`, `Launch.touch!`, `Launch.child_env!`, `RocInstall.offer!`, `RocInstall.install_offer!`, `Consent.required_want`, `Probe.classify`, `Probe.errors`, `TalonFile.open`, `TalonFile.render`, `Setup.bin_dir`, `Setup.judge`, `SetupIo.*`, `Common.failed!`, `Out.json_ok` |
| Lock | `Fx.locked!` on `Roots.item(ToolsJson)` with `Wait`, only for the last step. The L3 case 4 fails (the fake compiler waits 10 s) when the lock is held during the build |
| Tests | Do not edit tests (TW18). A wrong row: write it in the report |
| Early check and platform | `entry_verdict!` is called twice (step 7b before the download, step 12 under the lock). `check_platform!` (step 8b) is after the first app and before the compiler step. The doc comment of `ToolFlow` has both rows |
| `--json` | `ToolInstall.data` gives the `data`. The text goes to stderr with `--json` (`Common.shown_fx`) |

## 11. Red run, revert check

Red run with the stubs in `cli/lib` (logs in `research/slice-046-revert/red-*.log`):

| Step | Result |
| --- | --- |
| `roc check cli/main.roc`, `roc build cli/main.roc --opt=dev --no-cache`, `roc build cli/flowprobe.roc`, `roc fmt --check` of the 3 stubs | pass, 0 warnings |
| `scripts/test.sh` | check pass, fmt pass, l0 FAIL, l2 FAIL, l3 FAIL, selftest pass, l1 pass |
| L0 `l0-1` | 74 tests: 60 passed, 14 failed. The 14 are the `expect`s of `ToolTest`, all `todo: slice 046`. The other 7 drivers pass |
| L2 | 119 passed, 2 failed (`tool/ti1-install`, `tool/ti2-refusals`: the app wrote no exit file, `todo: slice 046`) |
| L3 | 68 passed, 1 failed (`tools/ti1-tool-install`), 1 skipped |

Green run with the reference (deleted after the review): L0 `l0-1` all 74 passed, L2 `tool/` 2 passed, L3 `tools/` 1 passed (3 runs in a row). The expected files of L2 and L3 were written with `UPDATE=1` from the reference and read by eye against the design. After the change of the L2 sources from `.roc` to `.src` the 2 `expect/` dirs were the same as before (`diff -r` against `research/slice-046-revert/expect-before/`).

Revert check (`research/slice-046-revert/mutants.py`, 14 mutations of the reference, the result in `mutants.log`; the mutations 11 to 14 and the new text of 5 are from the review):

| # | Mutation | Caught by |
| --- | --- | --- |
| 1 | a release that is exactly `min-release-age` old is hidden (`<` for `<=`) | L0 `ToolTest` 3 |
| 2 | `@latest` or a range keeps the installed version whatever the newest release is | L0 `ToolTest` 4 |
| 3 | a git tool is kept (no replace by a release install) | L0 `ToolTest` 4 |
| 4 | no check of the binary name under the lock | L2 `tool/ti2-refusals` run 9 |
| 5 | a foreign bin dir entry is overwritten (`entry_verdict!`) | L2 `tool/ti2-refusals` runs 10, 12 |
| 6 | an entry with no old binary is Talon's | L0 `ToolTest` 7 |
| 7 | `--roc pinned` is not the consent | L0 `ToolTest` 5 |
| 8 | a replaced tool loses the fields that tln does not know | L0 `ToolTest` 12 |
| 9 | a bundle that is no app is taken | L2 `tool/ti1-install` run 1 |
| 10 | the lock of `tools.json` is held during the build | L3 `tools/ti1-tool-install` step 4 |

| 11 | no early check of the bin dir entry (the build runs before the stop) | L2 `tool/ti2-refusals` run 10 |
| 12 | no check of the bin dir entry under the lock | L2 `tool/ti2-refusals` run 12 |
| 13 | `native`: one wasm name refuses the platform (`any` for `all`) | L0 `ToolTest` 14 |
| 14 | no check of the platform | L2 `tool/ti2-refusals` run 11 |

14 mutations, 14 caught (the mutations 1 to 4 and 6 to 10 were run before the review change and are not changed by it). The reference was put back after each run (`cmp` against `cli/lib` after the run: equal), then `restore.sh` put the stubs back. The reference was deleted after the review was applied (`research/slice-046-revert/reference/`). `restore.sh` and `stubs/` stay.

## Review (manager, 2026-10-25)

Accepted with the split 046 and 046b (GC protection, later; no test or stub now).

| Item | Answer | Done |
| --- | --- | --- |
| D1 to D7, D9 to D15, TW24 texts | Accepted | none |
| D8 | Change: check the bin dir for a foreign file also before the build (fail fast, exit 2, no build), and again under the lock after the build | `entry_verdict!` in `ToolFlow` at step 7b and step 12. L2 `ti2-refusals` run 10 now has no fetch, no probe, no lock. New run 12 (a hook makes `<bin>/z` foreign during the build): found under the lock. Mutations 5, 11, 12 |
| Q9 | Change: R-T2 "native platform" uses the target list that slice 054 reads (`BuildTarget.targets_of`). Only wasm names: exit 2. No readable `targets`: admitted (054 Q1) | `ToolInstall.native`, `ToolInstall.not_native`, `ToolFlow.check_platform!` (step 8b). L0 `ToolTest` expect 14. L2 run 11 (acme/wasm). Mutations 13, 14. The L2 `calls.log` files have the platform fetch (D17) |
| Q10, Q11 | Accepted. 046b later | none |
| G1 (R-FE4) | Known, a follow-up slice | none |
| G2, G4 | Recorded | none |
| G3 | Accepted as the existing R-SO15 behavior. The manager tells the user | none |

TW21: the old `expect/` files of the 2 new L2 cases were copied to `research/slice-046-revert/expect-before2/` before `UPDATE=1`. The diff is the platform fetch, the new early `sha256_file` calls, and runs 11 and 12; the stdout of runs 1 to 9 is the same. The stderr of run 10 lost the build lines. No other case changed.

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | The default branch request (R-T10) has the headers of `Net.headers` with no token and no ETag. A timeout, a failed call or a bad answer is `Err(None)` (the text says `its default branch is not known`) | A token for the request, a failure of the command |
| C2 | A name that is not `owner/repo` (a `host/path` name) is exit 2: `'<name>' is not an owner/repo name. tln tool install reads the releases of GitHub repos only.` (a proposal, TW24) | Fetch from another host (no rule) |
| C3 | The note of `Index.new_entry` (other URL forms) is printed as `note: <text>` on stderr. The age note of a young named version is printed only when a build follows (not for `Keep`) | No prefix, the age note also for `Keep` |
| C4 | `--quiet` hides the two header lines (R-SE8) only. The `downloading <id> (<size>)` line, the notes and the warnings stay (they are `RocInstall.fetch_optional!` and the warnings of the index) | Hide all of stderr |
| C5 | The build probe has the pool 12 (the default of `probe.slots`). `--slots` and `[probe]` of `config.toml` are not read: the slice names no such rule | Read `--slots` |
| C6 | A build that passed and made no file is found by the `copy_file!` of the output (`NotFound`) under the lock, and gives `build_failed` with `Pass` (the `calls.log` has no other call between the build and the lock) | A `list_dirs!` of the temp dir before the lock |
| C7 | The old source in `Replaced(<old>)` is the version of a release tool and `git <ref>` of a git tool. It is the same text in `data.previous` | The commit |
| C8 | The line `index: cached at <time>` (R-DI12) is printed on stderr with `--offline` and a cached list. It is not hidden by `--quiet`, as in `PickIndex` | Hide it |

Question (TW17), no code change: `ToolInstall.key` (step 5) is the repo name of the full name, or `--as`. A tool that was installed with `--as q` and is named again by its short name `q` (`tln tool install q`) has the full name `acme/qux` (step 4), so the key is `qux`, `ToolsJson.clash` is `Elsewhere` and the command fails with `acme/qux is installed as q already. Remove it first`. R-T26 (`tln tool install foo` when foo is installed: no build) may mean `Present` here. The design does not say which key an installed tool keeps. No test covers it. The code follows the doc comments (the key from the name and `--as`).

## Verify results

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | exit 0: check 1.4 s, fmt 0.2, l0 6.6 (`l0-1`: 74 passed, the 14 `expect`s of `ToolTest` green; `l0-2` 51, `l0-3` 75, `l0-4` 60, `l0-5` 55, `l0-6` 53, all green), l2 7.8 (121 passed, 0 failed: `tool/ti1-install` 6 runs, `tool/ti2-refusals` 12 runs), l3 9.9 (69 passed, 0 failed, 1 skipped: `tools/ti1-tool-install` green), selftest 2.9, l1 35.9 |
| `roc check`, `roc build` of the test apps (0 warnings), `roc fmt --check` of the 3 modules | 0 errors, 0 warnings |
| `crash "todo` in `cli/`, `packages/` | none |
| Size | `ToolsJson.roc` 203 lines, `ToolInstall.roc` 434, `ToolFlow.roc` 438 (each under 500) |
| Revert check | `research/slice-046-revert/agent-mutate.py`, results in `research/slice-046-revert/agent-results.md`: 11 mutations, 11 caught, 0 not caught (mutation 4 also in L3 step 4) |
| Code after the runs | same as `research/slice-046-revert/code-final/` (`sha256sum -c research/slice-046-revert/code-final.sha256` from the repo root: all OK) |

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | no early check of the bin dir entry | L2 `ti2-refusals` (run 10) |
| A2 | no check of the bin dir entry under the lock | L2 `ti2-refusals` (run 12) |
| A3 | no binary name check under the lock | L2 `ti2-refusals` (run 9) |
| A4 | the lock is held during the build | L2 `ti1-install`, L3 `ti1-tool-install` (step 4) |
| A5 | `native`: `any` for `all` | L0 `ToolTest` 14 |
| A6 | no check of the platform | L2 `ti2-refusals` (run 11) |
| A7 | `min-release-age` hides no release | L0 `ToolTest` 3 |
| A8 | a replaced tool loses the unknown fields | L0 `ToolTest` 12 |
| A9 | `@latest` or a range keeps the installed version | L0 `ToolTest` 4 |
| A10 | an entry with no old binary is Talon's | L0 `ToolTest` 7 |
| A11 | no lock at all for the last step | L2 `ti1-install` |

## Gap tests (test agent, after the code agent)

| Row | Test | Result |
| --- | --- | --- |
| C2 | L2 `ti2-refusals` run 13: `tool install example.com/pkgs/json`: exit 2, `is not an owner/repo name`, no request. It is an L2 run, not an L0 row: the text is made in `ToolFlow.release_list!`, not in a pure function | Mutation: the name `[o, r, ..]` is read as owner/repo: caught by run 13 (the text and the request change). Code restored: `sha256sum -c research/slice-046-revert/code-final.sha256` all OK |
| C6 | L2 `ti2-refusals` run 14: `tool install acme/nofile`, the 5th row of `fx/probes` passes and makes no file: exit 1, `made no file`, no binary, the temp dir is deleted, the lock is taken and released | Mutation: `Err(NotFound)` of the copy is ignored: caught by run 14 (exit 18). Code restored, sha OK |
| C3, C4, C5, C7, C8 | Accepted, no test (C5, C3 and C4 are visible in the existing `calls.log` and stderr files; C7 is `data.previous` in L0 expect 10) | none |

The expected files of runs 13 and 14 were written with `UPDATE=1` from the code and read by eye (`research/slice-046-revert/expect-before3/` has the old files, TW21: only lines were added).

## Review 2 (manager, 2026-10-25)

| Item | Decision | Test (red now, with the code of the code agent) |
| --- | --- | --- |
| Question of the code agent (R-T26 and the key) | When the command names a source (full name, `acme/qux`) with no `--as`, and the source is installed under another key (`q`, from `--as q`), it is the same tool: `Present` under the key `q` (R-T26 keep or replace there). With an `--as` that differs from the installed key: exit 2 as D2 | L0 `ToolTest` expect 15: `ToolInstall.installed_key : { entries : List(ToolsJson.Entry), name : Str } -> Try(Str, [None])` (6 rows). The key is `--as`, else `installed_key`, else the repo name. L2 `ti1-install` run 7 (`tool install acme/qux`: `q 2.0.0 is installed`, no build, exit 0; the code gives exit 2 now) and run 8 (`--as other`: exit 2, `is installed as q already`, green now) |
| C1 | The default branch request sends the token by the same rule as the other GitHub requests (045 Q1) | L2 `ti2-refusals` run 3 now has `env:TALON_GITHUB_API= env:GITHUB_TOKEN=ghp_fake` (the test hook `TALON_GITHUB_API` sends no token, so the run clears it). The expected `calls.log` has `Authorization: Bearer ghp_fake` on the default branch request (red now: the code sends none). The list request has the token already |
| C5 | Accepted: pool 12 | none |
| C2, C3, C4, C6, C7, C8 | Accepted | gap rows above |

Red now: `roc test tests/unit/l0-1.roc` has 74 passed and 1 compiler error (`installed_key` does not exist, expect 15). L2: 119 passed, 2 failed (`tool/ti1-install` run 7 only, `tool/ti2-refusals` run 3 only). L3 `tools/` passes. The code of the code agent is not changed (`sha256sum -c research/slice-046-revert/code-final.sha256`: OK). The code agent writes `installed_key`, the key rule and the token in `default_branch!`, and does not edit tests (TW18).

Review 2 fix: Review 2 (installed key, token of the default branch request): `ToolInstall.installed_key` written, the key is `--as`, else `installed_key`, else the repo name (`ToolFlow.gather!`), and `default_branch!` sends the token as `Github.releases!` does. Full `scripts/test.sh` exit 0, the code copy and `code-final.sha256` are new (OK). Mutations A12 (the key ignores the installed key: L2 `ti1-install` run 7), A13 (no token on the default branch request: L2 `ti2-refusals` run 3), A14 (`installed_key` finds nothing: L0 `ToolTest` 15): 3 caught, 0 not caught

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-046-revert/code-final.sha256` | OK, 6 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.5, fmt 0.2, l0 6.7, l2 7.2, l3 9.9, selftest 3.0, l1 38.9 s |
| Gap tests | runs 13, 14 (C2, C6), 2 hand mutations, caught |
| Review 2 | installed key (R-T26) and the token on the default-branch request: red tests first, then the fix, 3 hand mutations caught |
| Note | `ToolFlow.roc` 449 and `ToolInstall.roc` 442 lines: split before slice 047 or 048 grows them. GC protection is 046b. |
