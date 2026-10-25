# 055 `tln path` and the `init --platform` stub

Phase: P1. Status: done

Slice 055 is the plan row 055 of `PLAN-P1.md` (TRANSITION step 6, the user is the helper `roc-cfw`, `cloudflare-workers/research/talon-fit/TRANSITION.md` section 5). The design is the user-accepted draft D-TS (`research/talon-scripts/design-draft/DIFF.md`, answer OP8). Two parts:

| Part | What | Rules |
| --- | --- | --- |
| `tln path <alias>` | Prints the directory of one header entry. A release entry is `packages/<hash>/`, fetched when it is missing. A path entry is the directory of its file. | R-CM25, R-PTH1 to R-PTH5, R-PD14, R-PD9 |
| `tln init --platform <name>` | `main.roc` is the stub app of the platform (the smoke app of R-SM2 with `crash "write the app"`). The ladder builds it for the target of R-TG1 rules 2 and 3. A `requires` type with no stub: exit 2, nothing written. `roc-lang/basic-cli` by name: the hello world template. | R-IN8, R-TG6 (the `init` part), R-IN1 |

The private reference has about 420 lines of code without comments and empty lines: `InitStub` 301 (new, pure), `PathFlow` 50 (new), `PathCmd` 44 (new), `Init` 27 more. The row says 200: the stub generator (the scan of the `requires` clause) is the larger part. No module has more than 450 lines (`InitStub` has 367 with its doc, `Init` 238), so no split is needed.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-CM25 | `tln path <alias>`: the directory of a header entry, read-only | L0 `PathcmdTest.roc` expects `read`, `pick`, output. L2 `path/pt1-entry`. L3 `path/pt1-entry`. L0 `ArgsTest.roc` (the command and its flags) |
| R-PTH1 | The absolute directory of the entry of the project file (R-PD4, `--file`): `packages/<hash>/` for a release URL (also the platform entry), the directory of the file for a path entry. One line on stdout. `--json` `data` is `{ alias, kind, dir }` | L0 `pick`, `read`, output. L2 runs 1, 3, 4, 5, 8. L3 |
| R-PTH2 | A missing `packages/<hash>/` is fetched (as `install --frozen`): nothing is resolved, no project file is written. `--offline` and a missing directory: exit 15 | L2 runs 2 (offline), 3 (the fetch). L3 (offline) |
| R-PTH3 | An alias that is not in the header: exit 2. A foreign URL: exit 2 | L0 `pick`. L2 runs 6, 7. L3 |
| R-PD5, R-WS12 (as used, answer Q1) | A workspace root with no current member: exit 2 that lists the members, as `add` | L2 `path/pt1-entry` run 9 |
| R-PTH4 | The command uses a project (R-PD14): it records the project file (R-PD9), also when it fails later | L2 `tree.diff` (`projects.json` has p1 and p5, p5 from a failed run 7). L3 `tree.diff` |
| R-PTH5 | Talon reads and runs no file in the directory | L2 `calls.log` of runs 1, 3, 5 (no read of a file under the directory; the path entry's directory does not exist). Mutation M10 |
| R-IN8 | The stub app of the platform: each stub body is `crash "write the app"`. A type that R-SM2 cannot fill: exit 2, the message names the type, nothing is written. `roc-lang/basic-cli` by name: the R-IN1 template | L0 `InitTest.roc` expect `InitStub.app_text` (20 rows). L2 `init/it2-platform` runs 1 to 5. L2 `init/it3-platform-moved` (the stub is made again, answer Q4). L2 `init/it1-app` run 5 (changed) |
| R-TG6 (`init` part) | `tln init --platform` builds for the target of R-TG1 rules 2 and 3 (no `talon.toml` yet) | L2 `init/it2-platform` run 1 (`--target=wasm32`, rule 3), run 2 (`--target=x64musl`, rule 2), run 3 (no `targets`: no `--target`). `compat.tsv` of `tree.diff` has the key with the target |
| R-IN1 (as used) | `--platform roc-lang/basic-cli` gives the basic-cli template, not the stub | L2 `init/it2-platform` run 5 (hello world, no fetch call) |
| R-FL6, R-FL7, R-FL12 (as used) | `--file` works for `path` (it uses a project). The resolve flags are refused | L0 `ArgsTest.roc` (2 accepted rows, 3 message rows) |
| R-FE2, R-FE3, R-FE7 (as used) | The fetch of the release: download, `roc unbundle`, rename. `--offline` and a missing dir: exit 15 | L2 `path/pt1-entry` run 3, runs 2. L2 `init/it2-platform` run 6 |
| R-EC2, R-PD1 to R-PD8 (as used) | Usage failures are exit 2. The project is found as in the other commands | L2 runs 6 to 8 of `path/pt1-entry`. L0 `read` |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 055"`)

| Name | Signature | File |
| --- | --- | --- |
| `PathCmd.Entry` | `{ alias : Str, source : [Release(Str), Dir], dir : Str }` (a type, no stub) | `PathCmd.roc` (new) |
| `PathCmd.read` | `Args -> Try({ alias : Str }, Fail)` | same |
| `PathCmd.pick` | `{ alias : Str, rows : List(Locked.Row), file : Str, roots : Roots } -> Try(PathCmd.Entry, Fail)` | same |
| `PathCmd.text` | `PathCmd.Entry -> Str` | same |
| `PathCmd.data` | `PathCmd.Entry -> JsonDoc` | same |
| `PathFlow.run!` | `Fx, Args => I32` | `PathFlow.roc` (new) |
| `InitStub.app_text` | `{ name : Str, url : Str, text : Str } -> Try(Str, Fail)`. `text` is the text of the `main.roc` of the platform release | `InitStub.roc` (new) |

Wired already (the code agent leaves them): `Args.roc` (`path` is a command, `--file` is allowed for it: 2 lines), `Run.roc` (the branch `PathFlow.run!` and its import), `main.roc` (the modules `InitStub`, `PathCmd`, `PathFlow`). `Init.roc` has the new step 4b (`platform_header!`: `Fetch.packages!` and `read_files!`, so the calls are as the L2 logs show) and ignores the result in the stub (`_ = header`). The code agent replaces the two lines of the stub in `Init.make!` (the branch for another platform) with `InitStub.app_text({ name, url, text: header })?`, and adds `import InitStub`. The docs of the stubs are the contract of the calls and of the texts.

## 3. The tested reading (the rules of the code)

| # | Topic | Reading |
| --- | --- | --- |
| 1 | `tln path` operands | One alias. None, or 2 or more: exit 2, before any `Fx` call (L2 run 8) |
| 2 | The project | `Install.begin!` (as `list`), then `Known.record!` of the member files (also for a run that fails later), then one `read_files!` of the project file (`Locked.read`). So the log has 2 reads of the file (D1) |
| 3 | The entry | The first row with the alias. `Release` row: `dir` is `Roots.item(roots, Package(hash))`. `Path` row: `Text.resolve(<dir of the project file>, value)`, then `Text.dir_of`: lexical, no `canonical` call, no read, the directory can be missing. `Foreign` row: exit 2. No row: exit 2, the message lists the aliases (the `roc:` pin is no row, Q2) |
| 4 | The fetch | Only for a `Release` row: `Fetch.packages!` for its URL, `roc: "roc"` (as `Gather`, D3), `offline: args.offline`. A failure is the failure of the run. The result is not read: after the fetch, no call reads a file in the directory |
| 5 | The output | stdout: the directory and a line end, nothing else, also with `--quiet` (the answer, R-FL4). `--json`: the envelope `{"schema":1,"command":"path",...,"data":{"alias","kind","dir"}}`, `command` is the word as typed. No line on stderr for a fetch |
| 6 | `init --platform <name>`, another platform than `roc-lang/basic-cli` | After the start release (`start_url!`) and before the first write: `platform_header!` (the fetch of the start release: `random`, `list_dirs` of the packages dir, a download when missing; then one `read_files!` of `<pkgs>/<hash>/main.roc`). A fetch failure is the failure of the run (`--offline` and a missing dir: exit 15, nothing written). Then `InitStub.app_text`. A failure of it: exit 2, nothing written (the run stops before the write). The default platform makes no such call (L2 run 5). After the resolve (step 6b, answer Q4): when `outcome.moved` has the alias `pf`, the release that the resolve chose is not the start release, so `init` reads `main.roc`, takes the `pf` URL, runs `platform_header!` for it, makes the stub again (`InitStub.app_text`), puts the `roc:` pin back (`Locked.edit` with `Pin`) and writes `main.roc` again. No move: no call. `init` made the file, so this is no overwrite of a user file (R-IN7) (L2 `it3-platform-moved`) |
| 7 | The `requires` clause | The group after the word `requires` at depth 0 of the platform header span. The old form `requires {} { ... }` has two groups: the values are in the second. Comments and strings are no tokens. An entry is `name : <type>` or `[Alias : var, ...] for name : <type>`. A comma at depth 0 followed by `name :` (or, between entries, by `[`) starts the next entry. A last comma is allowed. A clause with 2 or more entries is a form that R-SM2 does not give: exit 2 like a type with no stub (answer Q6). `{ name : T, ... }` fields split the same way, so `respond! : Request, context => R` is one field |
| 8 | The stubs | A function type (a `=>` or `->` at depth 0 of the type): `\|_, _\| crash "write the app"`, one `_` for each argument (the depth-0 commas of the argument part, plus one; `()` has none: `\|\| crash ...`). A record type: a record of stubs, one tab more for each level, `{}` for no field. Any other type: no stub, the first one in source order, also in a field (the innermost type is named) |
| 9 | The app text | `app [<each alias of each entry, then each name>] {`, a tab, `pf: platform "<url>",`, `}`, then one block for each alias (`Alias : {}`), then one block for each entry (`name = <stub>`), blocks split by one empty line, a line end at the end. `roc fmt --check` and the pinned `roc check` accept the text (checked by hand for the basic-cli form: `main! = \|_\| crash "write the app"`) |
| 10 | R-TG6 | The ladder of `init` has no `talon.toml` in the case, so `BuildFlow` takes rule 2 or 3 of R-TG1. No code change is needed: the L2 rows pin it |

## 4. Tests

| Layer | File | Case | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/PathcmdTest.roc` (driver `l0-7.roc`) | `read`: 5 rows (one alias, `--file`/`--json`, none, 2 and 3 names) | R-PTH1, R-EC2, R-CM25 |
| L0 | same | `pick`: 9 rows (platform and package release, path entries: `..`, deeper, `.` and `..` inside, absolute, a foreign URL, 2 unknown aliases) | R-PTH1, R-PTH3, R-CR1, R-H4, R-H7 |
| L0 | same | `text` and `data` (the 2 kinds, the JSON text) | R-PTH1 |
| L0 | `tests/unit/InitTest.roc` (driver `l0-3.roc`) | `InitStub.app_text`: 20 rows (rows that give a stub: basic-cli with a comment that has `{`, `:` and `,`, the old form, 2 and 3 arguments with `->`, a tuple and a record as arguments, an alias with a record of functions, 2 aliases and a nested record, one entry with a last comma, `{}`, comments and strings and a nested `requires` key; rows of exit 2: `Str`, `U16` and `List(U8)` in a field, the first one in a nested record, an alias type, a multi-line tag union, a `Try` type; and 3 rows for a clause with 2 or 3 entries, answer Q6) | R-IN8, R-SM2, R-EC2 |
| L0 | `tests/unit/ArgsTest.roc` (driver `l0-5.roc`) | 2 accepted rows and 3 message rows for `path` | R-FL6, R-FL7, R-FL12, R-CM25 |
| L2 | `tests/commands/cases/path/pt1-entry` (9 runs) | present package, offline and missing (exit 15), the fetch, `--file` and `--json`, a path entry, a foreign URL, an unknown alias in a second project, no alias, a workspace root with no current member (run 9, answer Q1) | R-CM25, R-PTH1 to R-PTH5, R-PD14, R-PD9, R-FL6, R-FE2, R-FE3, R-FE7, R-EC2 |
| L2 | `tests/commands/cases/init/it2-platform` (6 runs) | wasm-only platform (stub, `--target=wasm32`), host target (old form, `--target=x64musl`), alias and record (no `targets`), a type with no stub in a field of a record (exit 2, nothing written), `roc-lang/basic-cli` by name (hello world, no fetch), `--offline` and a missing platform (exit 15) | R-IN8, R-SM2, R-TG6, R-TG1, R-IN1, R-IN2, R-IN7, R-PD9, R-FE7, R-EC2 |
| L2 | `tests/commands/cases/init/it3-platform-moved` (1 run, answer Q4) | `acme/mov` has 0.2.0 (an alias and a record in `requires`) and 0.1.0 (`main! : () => {}`). The directory has a `talon.toml` with `[build] target = "wasm32"` and 0.2.0 has x64musl only (R-C10), so the resolve moves the platform to 0.1.0: `init` makes the stub again from 0.1.0 (`main! = \|\| crash "write the app"`, the pin kept) | R-IN8, R-IN2, R-IN7, R-SM2, R-C10, R-TG1 |
| L2 | `tests/commands/cases/init/it1-app` run 5 (changed, TW21) | the body is the stub (`main! = \|\| crash "write the app"`), 3 more calls (`random`, `list_dirs`, `read_files` of the platform) | R-IN8 |
| L3 | `tests/scenarios/path/pt1-entry` (7 commands) | the real `tln` and the real `Fx`: a release entry in the cache, a path entry, `--json`, a foreign URL, an unknown alias, no alias, `--offline` with a missing package (exit 15), `projects.json` | R-CM25, R-PTH1 to R-PTH4, R-EC2, R-J1 |

Counts: 3 L0 expects in the new `PathcmdTest.roc`, 1 new L0 expect in `InitTest.roc` (20 rows), 5 new rows in 2 expects of `ArgsTest.roc`, 3 new L2 cases (16 runs), 1 changed L2 case (run 5 of `it1-app`), 1 L3 scenario. Deep cases: 4. One row of `InitTest` expect 3 was removed (section 10).

The world of `it2-platform` is the world of `it1-app` (the compilers n10 to n12 are installed, so no prompt and no download, the basic-cli list, the compiler list). The world of `it3-platform-moved` is a copy of the `it2-platform` world (home7). The generators are `research/slice-055-revert/gen-pth.py` and `gen-pth-l3.py` (do not run them: they write the case dirs without `expect/`, TW21).

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| `tln path` stdout | `<dir>` and a line end, nothing else (R-PTH1: one line) | L0 output, L2, L3 |
| `--json` `data` (the design gives it as a proposal, R-OUT2) | `{"alias":"pf","kind":"url","dir":"<dir>"}`, `kind` is `url` or `path`. The envelope is the one of all commands, `command` as typed | L0 output, L2 run 4, L3 |
| No alias | `tln: error[usage]: tln path needs an alias: a name in the header of the project file` | L0 `read`, L2 run 8, L3 |
| 2 or more aliases | `tln: error[usage]: tln path takes one alias, got <n> names` | L0 `read` |
| Alias not in the header | `tln: error[usage]: no entry '<alias>' in the header of <file>. Entries: <alias>, <alias>.` (`none` for no row; the case of the alias matters) | L0 `pick`, L2 run 7, L3 |
| Foreign URL | `tln: error[usage]: '<alias>' is a foreign URL (<url>): roc keeps it under another cache rule, so it has no directory in packages/ (R-PTH3)` | L0 `pick`, L2 run 6, L3 |
| Missing package, `--offline` | `tln: error[network]: <owner>/<repo> <version> is not in the package cache and --offline is set (<url>)` (the text of `Fetch.offline_missing`, no new text) | L2 runs 2, `it2-platform` run 6, L3 |
| The stub app | the layout of section 3, row 9. For basic-cli: `app [main!] {`, `pf: platform "<url>",`, `}`, an empty line, `main! = \|_\| crash "write the app"`. The `roc:` pin is added by the resolve | L0 `InitStub.app_text`, L2 `it2-platform` runs 1 to 3 |
| No stub for a type | `tln: error[usage]: cannot make the stub app for <name>: the value <value> of its requires clause has the type <type>, and R-SM2 has no stub for that type (R-IN8). Nothing was written.` `<type>` is the text of the type with white space as one space | L0 (6 rows), L2 `it2-platform` run 4 |
| `init` for a platform with no `requires` clause | `tln: error[usage]: <name> has no requires clause: it is not a platform (R-IN8)` (question Q3, not tested) | none |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `PathFlow` reads the project file with one `read_files!` after `Known.record!`. `Install.begin!` (`Project.find!`) has read it before, so the log has 2 reads | `Project.find!` gives the text (it changes the `calls.log` of about 110 old L2 cases) |
| D2 | A path entry gives its directory by `Text.resolve` and `Text.dir_of`: no `canonical` call and no check that the directory exists (R-PTH5: Talon reads no file there) | `canonical!` of the directory (a read of the file system, and it fails for a missing directory) |
| D3 | The program of `roc unbundle` is `roc` on `PATH` (as `Gather` and `install --frozen`), not the selected compiler of R-FE4 | The selection of R-FE4 (a compiler resolve in a command that resolves nothing). See Q5 |
| D4 | `tln path` prints no line for a fetch: stdout is one line, stderr is empty | A progress line on stderr |
| D5 | `--file` is allowed for `path`, the resolve flags (and `--allow-downloads`) are not: it resolves nothing, R-FL6, R-FL7 | Refuse `--file`. Allow the download flags |
| D6 | `init` fetches and reads the start release of the platform before it writes `main.roc`. The stub is made from the start release only (Q4) | Read the platform after the first write (a failure would remove `main.roc`) |
| D7 | The stub generator is a new pure module `InitStub` (not `InitText`). `InitText.app_file`'s branch for another platform is dead code after the slice. (Changed by the review: the old `InitTest` row that pinned it is removed, so the code agent can remove the branch.) | Keep the row and the branch |
| D8 | The layout of the stub app (section 3, row 9): the exposes list has the aliases first, one blank line between blocks, `\|_\|` and not a named argument | A named argument. The app text of the smoke build (`talon smoke test`, `research/smoke-app/`) |
| D9 | The reading of the `requires` clause (section 3, row 7) for forms that R-SM2 does not spell out: a record field that is a function with many arguments, the old two-group form. (Changed by the review, Q6: a clause with 2 or more entries is exit 2, not a stub of each entry.) | A stub for each entry |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | A real download for `tln path` in L3 | The fake `roc` has no `roc unbundle` (the L3 runner note). L2 `path/pt1-entry` run 3 has the fetch; `fetch/fe-flow` has the contract with the real `Fx` |
| Out 2 | R-TG6 first part (the proxy has no build target) and the build of a tool | Slice 054 (`proxy/tg4-proxy`, a guard) and the tool slices |
| Out 3 | A `talon.toml` with `[build]` in the directory of `init` | R-TG6 says there is none yet. Question Q7 of slice 041: the flow reads it as `upgrade` does. No row |
| Out 4 | The real `roc check` of every stub form | The text of basic-cli was checked by hand with the pinned `roc` (`roc fmt --check`, `roc check`: no errors). The other forms are the forms of `research/smoke-app/` (L4 would need a platform release) |
| Out 5 | `--quiet` and `--json` together for `tln path` | Not a rule of the slice: the answer line stays (R-FL4). No row |
| Out 6 | `Help.usage` has no line for `path` | The design gives no text. The help is not tested for it |

| Id | Question | In the stub and the tests |
| --- | --- | --- |
| Q1 | `tln path <alias>` at a workspace root with no current member (R-PD5 gives no project file). R-WS12 names `add` and `remove` only | Answered (manager): exit 2 that lists the members, as `add`. Tested by L2 `path/pt1-entry` run 9 |
| Q2 | `tln path roc`: the `roc:` pin is an entry of the header record but it is no package | Answered (manager): exit 2 (R-PTH3: `roc` is not a header alias). Tested by L0 `PathcmdTest` |
| Q3 | `tln init --platform <name>` for a package that is no platform (R-AD32), or for a header that does not parse: no `requires` clause | Answered (manager): exit 2. Tested by L0 `InitTest` and L2 `it2-platform` |
| Q4 | The ladder of `init` can move the platform to an older release (R-IN2). A release with another `requires` clause can make the stub fail to build | Answered (manager): change. After the resolve, if the chosen release is not the start release, `init` makes the stub again from the chosen release and writes `main.roc` again (R-IN7: no overwrite of a user file). Tested by L2 `init/it3-platform-moved` |
| Q5 | R-FE4 says that `roc unbundle` uses the selected compiler, else the newest installed, else the `roc` on `PATH`. `Gather`, `PatchFlow` and the code of this slice use `roc` on `PATH` (P0) | Answered (manager): accepted for this slice, `Fetch.packages!` keeps the behavior of `Gather`. R-FE4 compliance of all fetches is a separate follow-up (the manager records it). Not tested |
| Q6 | R-SM2 says "each value of its `requires` clause" and does not give the form of an entry list | Answered (manager): an entry list that R-SM2 does not give is a type that R-SM2 cannot fill (OP8): exit 2 with a message, nothing written. Tested by L0 `InitTest` (2 and 3 entries) |

Design gaps (for the human, no design file is changed here):

| Gap | Where |
| --- | --- |
| R-PTH1 to R-PTH5 do not say what `tln path` does at a workspace root with no current member (Q1) or for the `roc:` pin (Q2). Both answered by the manager | CLI R-PTH1, R-PD5, R-WS12 |
| R-IN8 does not say what a platform with no `requires` clause does (Q3), and which release the stub is made from when the resolve moves the release (Q4). Both answered by the manager | CLI R-IN8 |
| R-SM2 is the smoke-app table. It has no rule for more than one value, and no rule for the order of the exposes list. The smoke build never runs it for a real platform with a record that has a function with many arguments, so `research/smoke-app/` is the only evidence | Resolution R-SM2 |

## 8. Compiler and tool limits met (for the manager and the code agent)

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | `requires` and `app` are reserved words, also as a parameter name or a function name | the test helpers `view`, `hdr` and `stub_app` name the clause `clause` | use another name |
| C2 | `{ alias }` alone is a block, not a record | `PathCmd.read` | `{ alias: alias }` |
| C3 | A `var` that holds a bare `Err(...)` has no `is_err` | the scan of the clause and of the arrow | a typed top-level value (`no_clause_at : Try(U64, [NoClause])`) |
| C4 | A top-level constant of a test file with a `crash` branch is a warning of `roc test`, and a warning fails the l0 step (the reference run showed it: `unused branch`) | `PathcmdTest.roc` | a function in place of the constant, and `Roots.{ ... }` for the roots |
| C5 | The old tests pass in the red state, except the 4 L2 cases and the 4 L0 expects that name this slice | see section 11 | |

## 9. Notes for the code agent

| Topic | Note (the reference was not seen by you: these notes describe it) |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/path/pt1-entry/rules` and `init/it2-platform/rules` have the text of each run. `research/slice-055-revert/gen-pth.py` and `gen-pth-l3.py` made the cases (do not run them) |
| `PathFlow.run!` | See the step table in its doc. `Install.begin!` and `Install.canonical_files!` are in `Install.roc`. `Fetch.packages!` gives a list with one result for the one URL (`[Ok(Present or Fetched)]` or `[Err(fail)]`). The output goes to `fx.out!`. The L2 `calls.log` fixes the order (2 reads of the project file: D1) |
| `PathCmd.pick` | `Locked.Row` has `alias`, `value`, `is_platform`, `what` (`Release(ident)`, `Path`, `Foreign`). `Ident` has `hash`. `Roots.item(roots, Package(hash))` is the directory. `Item` is imported in the reference |
| `InitStub.app_text` | Scan the platform header with `Header.parse` and `header.span()` (the pattern of `BuildTarget.targets_of`: a token list, comments and strings give no token). The reading is the table of section 3, rows 7 to 9, and the rows of the L0 expect are the cases. The L2 `it2-platform` run 4 and the L0 rows pin the failure texts |
| `Init.after_first!` | Step 6b (Q4) goes here as `remake!`: if the plan template is App, the name is not the default, and the outcome moved the alias `pf`, then read `main.roc`, `Locked.read`, take the `pf` URL, `platform_header!`, `InitStub.app_text`, `Locked.edit` with `Pin(id)`, `write_atomic!`. The stub `Init.roc` already passes `roots` and `net` in the `here` record. L2 `init/it3-platform-moved` is the test |
| `Init.make!` | Replace the stub lines (`_ = header` and `InitText.app_file`) in the branch for another platform. Add `import InitStub`. A failure of `InitStub.app_text` is returned with `?`: nothing was written yet, so no `delete!` is needed |
| `InitText.app_file` | The else-branch for another platform is dead code. Remove it (D7: the old `InitTest` row that pinned it is removed, review of 2026-10-24) |
| Q6 | `InitStub.app_text` returns exit 2 for a clause with 2 or more entries (the message is in the L0 expect). One entry, also with a trailing comma, gives a stub |
| Size | About 450 lines of code. `InitStub` is the largest (about 300): the tokenizer, the entry split, the stub of a type |
| Reserved words | `requires`, `app`, `package`, `platform` can not be a name of a function, a parameter or a field |

## 10. Changed old tests (TW21)

| Test | Change | Reason |
| --- | --- | --- |
| `tests/commands/cases/init/it1-app/expect/calls.log`, `tree.diff` (run 5) | 3 lines in the log (`random`, `list_dirs` of the packages dir, `read_files` of the platform `main.roc`, after `read_files config.toml`, before `write_atomic main.roc`). One line in `tree.diff`: `main! = \|\| crash "write the app"` in place of `main! = \|_args\| Ok({})`. Checked against the saved copy (`research/slice-055-revert/before/`): no other line changes | R-IN8: `--platform acme/pfx` gets the stub of its `requires {} { main! : () => {} }` |
| `tests/commands/cases/init/it1-app/rules` | the sentence of run 5 (the body) | the same |
| `tests/unit/ArgsTest.roc`, `InitTest.roc`, `l0-7.roc` | new rows and a new expect, one import in the driver | the new tests |
| `tests/unit/InitTest.roc` (expect 3) | removed the row `other = InitText.app_file(...)`, its check `other.contains("roc:")` and its `Stdout` row | D7 (review 2026-10-24): the row pinned the dead branch of `InitText.app_file` for another platform |
| `tests/commands/cases/init/it2-platform/` | the platform `acme/cnst` has `requires {} { main! : { go! : () => {}, port : U16 } }`; run 4 stderr names `main!` | Q6: the old form is a list of 2 values, now exit 2 |

No other expected file changed (`UPDATE=1` ran only for the 4 new cases and for `init/it1-app`; the old file trees were compared).

## 11. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Baseline before the slice (`research/slice-055-revert/baseline-run.log`) | all pass: check 3.5, fmt 0.3, l0 11.9, l2 9.9, l3 10.3, selftest 4.2, l1 68.1 (the 2 WARN lines come from a loaded machine) |
| Reference (`reference-run.log`, after the review) | all pass: check 1.4, fmt 0.2, l0 7.3, l2 7.7, l3 9.9, selftest 3.0, l1 53.2. The reference is deleted (`research/slice-055-revert/reference/`) |
| Red, with the stubs (`red-run.log`) | check, fmt, selftest, l1 pass |

| Step | Red result | The new tests |
| --- | --- | --- |
| l0 | FAIL | `l0-3`: 64 passed, 1 failed (`InitTest` expect `InitStub.app_text`: `todo: slice 055`). `l0-7`: 37 passed, 3 failed (the 3 expects of `PathcmdTest`: `todo: slice 055`). `ArgsTest` passes: `path` is wired (the rows pin the flags). Other drivers pass |
| l2 | FAIL (109 passed, 4 failed) | `path/pt1-entry` (9 runs): the test app crashes at the first run (`todo: slice 055`, no exit file). `init/it2-platform`: the stub text is the old smallest `main!` for runs 1 to 3, and run 4 writes a `main.roc` (wrong value). `init/it3-platform-moved`: `main.roc` has the stub of the start release (0.2.0), not of 0.1.0. `init/it1-app`: run 5 has the old body (the 3 calls of 4b are there already, so only the tree line differs) |
| l3 | FAIL (65 passed, 1 failed, 1 skipped) | `path/pt1-entry`: the 7 commands crash with `todo: slice 055` |

Revert check (`research/slice-055-revert/mutate.py`, the reference in the tree, filtered runs only, `mutate.log`): 10 mutations (M1 to M10) and, after the review, 3 more (R1 to R3). All caught. M1, M3 and M8 ran again after the review. The reference is deleted now, so the revert check can not run again without a new reference.

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | any bracket after a comma starts an entry | L0 `InitTest` |
| M2 | any word after a comma starts an entry (not `name :` only) | L0 `InitTest`, L2 `it2-platform` |
| M3 | `()` counts as one argument | L0 `InitTest`, L2 `it2-platform`, `it1-app` |
| M4 | a comment is read as tokens | L0 `InitTest`, L2 `it2-platform` |
| M5 | the message names the whole record type, not the field | L0 `InitTest` |
| M6 | a path entry is seen from the project file, not from its directory | L0 `PathcmdTest`, L2 `pt1-entry`, L3 |
| M7 | the project is not recorded | L2 `pt1-entry`, L3 |
| M8 | the default platform also gets the stub | L2 `it2-platform` |
| M9 | `--offline` does not reach the fetch of the platform in `init` | L2 `it2-platform` |
| M10 | a file in the directory of the entry is read | L2 `pt1-entry` |
| R1 | Q1: `check_member` off in `PathFlow` | L2 `pt1-entry` (run 9) |
| R2 | Q4: no remake after the move | L2 `it3-platform-moved` |
| R3 | Q6: an entry list is accepted | L0 `InitTest` (l0-3) |

## 12. Files

| File | State |
| --- | --- |
| `docs/slices/055-path-and-init-platform.md` | new (this file) |
| `cli/lib/PathCmd.roc`, `PathFlow.roc`, `InitStub.roc` | new, stubs (41, 23, 37 lines) |
| `cli/lib/Init.roc` | changed (the step 4b `platform_header!`, the stub branch, 238 lines). Copy before in `research/slice-055-revert/before/` |
| `cli/lib/Args.roc`, `Run.roc`, `main.roc` | wired (2 lines, 2 lines, 3 lines). Copies before in `research/slice-055-revert/before/` |
| `tests/unit/PathcmdTest.roc` | new, 104 lines |
| `tests/unit/InitTest.roc`, `ArgsTest.roc`, `l0-7.roc` | new expect (20 rows of `view`), 5 rows, one import. The `InitText.app_file` row is removed (D7) |
| `tests/commands/cases/path/pt1-entry/` | new (9 runs) |
| `tests/commands/cases/init/it2-platform/` | new (6 runs) |
| `tests/commands/cases/init/it3-platform-moved/` | new (1 run, Q4) |
| `tests/commands/cases/init/it1-app/` | run 5 expected files changed (section 10) |
| `tests/scenarios/path/pt1-entry/` | new (7 commands) |
| `research/slice-055-revert/` | `backup.sh`, `swap.sh` (modes `stub`, `check`), `gen-pth.py`, `gen-pth-l3.py`, `mutate.py`, `mutate.log`, `before/` (with `NEW.txt`), `stubs/`, `baseline-run.log`, `red-run.log`, `reference-run.log` |

## Review (manager, 2026-10-24)

The manager accepted the slice with no split. D1 to D6, D8, D9 and the TW24 texts are accepted. The status is set to `code`.

| Item | Answer | Applied |
| --- | --- | --- |
| Q1 | As `add`: exit 2 that lists the members | L2 `path/pt1-entry` run 9 (`cwd:ws path pf`) |
| Q2 | Accepted: exit 2 (R-PTH3, `roc` is not a header alias) | no change |
| Q3 | Accepted: exit 2 | no change |
| Q4 | Change. After the resolve, if the chosen platform release is not the start release, `init` makes the stub again from the chosen release header and writes `main.roc` again (no overwrite of a user file, R-IN7) | step 6b in section 3. L2 `init/it3-platform-moved` (the resolve moves `acme/mov` from 0.2.0 to 0.1.0, whose `requires` differs) |
| Q5 | Accepted for this slice: `Fetch.packages!` keeps the behavior of `Gather` (`roc` on `PATH`). R-FE4 compliance of all fetches is a separate follow-up (the manager records it) | no change |
| Q6 | An entry list that R-SM2 does not give is a type that R-SM2 cannot fill (OP8): exit 2 with a message, nothing written | L0 `InitTest` rows (2 and 3 entries), `it2-platform` platform `acme/cnst` |
| D7 | Change. Remove the old `InitTest` row that pins the dead `InitText.app_file` branch for another platform | row removed (section 10). The code agent can remove the branch |

Reference: deleted. `research/slice-055-revert/swap.sh` keeps the modes `stub` and `check`. Red state confirmed (section 11).

## Verify results (code agent)

`scripts/test.sh`: all 7 steps pass (check 1.5 s, fmt 0.2, l0 6.7, l2 7.6 with 113 cases, l3 9.9 with 66 passed and 1 skipped, selftest 3.0, l1 38.7). New and changed code: `PathCmd.roc` 63 lines, `PathFlow.roc` 77, `InitStub.roc` 441, `Init.roc` 270 (step 6b `remake!`, `InitStub` in step 4b), `InitText.roc` 47 (the dead else-branch of `app_file` is removed, D7).

Revert check (`research/slice-055-revert/agent-mutate.py`, `agent-results.md`): 10 mutations, 10 caught.

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | any word after a comma starts an entry | L0 `InitTest`, L2 `it2-platform` |
| A2 | `()` counts as one argument | L0 `InitTest`, L2 `it1-app`, `it2-platform`, `it3-platform-moved` |
| A3 | no exit 2 for a type with no stub (hello world written) | L2 `it2-platform` |
| A4 | no remake after the resolve moved the platform | L2 `it3-platform-moved` |
| A5 | the remake drops the `roc:` pin | L2 `it3-platform-moved` |
| A6 | a path entry seen from the project file | L0 `PathcmdTest`, L2 `pt1-entry` |
| A7 | no fetch of a missing release dir | L2 `pt1-entry` run 3 |
| A8 | `--offline` does not reach the fetch of `path` | L2 `pt1-entry` run 2 |
| A9 | the project file is not recorded | L2 `pt1-entry` |
| A10 | `--offline` does not reach the fetch of `init` | L2 `it2-platform` run 6 |

Decisions of the code agent that the slice does not fix (the untested edges): a `requires` clause with no entry (`requires {}`), and an entry that does not have the form `name : type` or `[A : a] for name : type`, give the `has no requires clause` failure (exit 2, nothing written), like Q3. No question is open.

Disputes (from the code agent): none. No test, fixture or expected file was changed.

## Gap tests (test agent, TESTING.md 7.1 step 5)

The gap rows are 4 rows in the `InitStub.app_text` expect of `tests/unit/InitTest.roc` (L0 `l0-3`, 65 tests, all pass). No code changed (`sha256sum -c research/slice-055-revert/code-final.sha256`: OK after each mutation). The old file is in `research/slice-055-revert/InitTest.roc.before-gap`.

| Row | Input (`requires` clause) | Expected | Mutation (by hand, restored) | Result |
| --- | --- | --- | --- | --- |
| G1 | `{}` | `has no requires clause` (exit 2) | delete the arm `[] => Err(no_clause(...))` of `entries_app` | caught (message `has 0 values`) |
| G2 | `{ main! }` | `has no requires clause` | `Err(Bad)` gives another message | caught |
| G3 | `{ [A : a] main! : () => {} }` | `has no requires clause` | same mutation as G2 | caught |
| G4 | `{ main! : () => {}, "x, helper! : Str" }` | one entry, stub of `main!` (a string token starts and ends no entry) | the tokenizer does not read a string (`b == '"'` branch off) | caught (message `has 2 values`) |

Not added: a pin of the remake (step 6b) beyond `it3-platform-moved`, which already pins it (mutations A4 and A5). The first try of the G4 mutation was a compile error, not a test result: it was replaced by the one in the table.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-055-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.4, fmt 0.2, l0 7.3, l2 6.6, l3 10.0, selftest 3.1, l1 41.8 s |
| Gap tests | 4 rows, 4 hand mutations, all caught; no code bug |
| Note | The code agent read `swap.sh` and 5 lines of `mutate.log` (mutation names only, no reference code). Accepted. `InitStub.roc` is 441 lines: split it before it grows. |
