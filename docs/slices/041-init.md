# 041 `tln init`

Phase: P1. Status: done

Slice 041 is the plan row 041 of `PLAN-P1.md`. It needs 039, 039b and 039c (done). `tln init` writes a new `main.roc` and a CI file, then runs the flow of `tln upgrade` on that file (all packages and the nightly are free), so the pin, the newest platform release that passes, the one compiler prompt and the downloads are the code of slices 038 to 039c.

The private reference had about 170 added lines of code after the review (without comments and empty lines): `Init` about 150, `InitText` 20, and 2 lines in `Args`, 4 wiring lines (`Run`, `main`). The row said 300 and the limit is 450, so no split is needed. The reference was deleted after the review (section Review), so the code agent does not see it.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-CM1 | `init [app\|package] [--platform <name>] [--ci github\|none]`: a new app or package, the nightly in the header, a CI file | L0 `init.roc` expect 1 (also `--platform` with `package`, and a name that is not `owner/repo`: exit 2). L2 `it1-app` runs 1, 5, 6, 10. L0 `args.roc` |
| R-IN1 | `app` (default) or `package`. An app uses the newest `roc-lang/basic-cli`. `--platform` selects another platform | L0 expect 1, expect 3. L2 runs 1, 5, 6, 10 |
| R-IN2 | The resolve is the one of `tln upgrade`: the newest platform release and the newest nightly that pass. A package gets the newest nightly that passes the check | L2 run 5 (a platform release that fails on N: the pin is the next compiler), run 6 (package, 2 probes), run 1 |
| R-IN3 | The consent rules R-DL1 to R-DL6, the newest nightly is a download that the command names (R-NI12). `init` takes `--yes`, `--allow-downloads` and `--probe-downloads` | L2 runs 1, 2, 3, 11, 13 (R-DL3 to R-DL5). `args.roc`. R-DL1, R-DL2, R-DL6: Out 1 |
| R-IN4 | The nightly is the `roc:` entry of the header, no `.roc-version` | L2 runs 1 to 6, 8, 9 (the tree has no `.roc-version`) |
| R-IN5 | No `talon.toml` is created | L2 `tree.diff` of each run |
| R-IN6 | `.github/workflows/ci.yml` for GitHub Actions: the install line with the version of `tln`, `tln install --frozen`, `roc check`, `roc test`, `TALON_AUTO_INSTALL=yes`, `ubuntu-latest`. `--ci none` writes none | L0 expect 3 (the version is a parameter), L2 runs 1, 2 |
| R-IN7 | Talon never overwrites a file. `main.roc` exists: exit 2. The CI file exists: it is skipped with a note, exit 0. A failed run removes the files that it made | L2 run 7 (`main.roc`), run 12 (CI file), run 11 (removal) |
| R-PD15 | `init` creates `main.roc` in the current directory and does not search | L2 run 8 (a `main.roc` and a workspace `talon.toml` above) |
| R-PD9 | `init` records the file that it creates in `projects.json` | L2 run 1 (`tree.diff`), run 7 (no record) |
| R-SO16 | Talon never writes `.roc-version` | L2 `tree.diff` of each run. Mutation I4 |
| R-NI12 | The prompt for the newest nightly: default yes, a person says Enter or `--yes`, no person starts it | L2 runs 1, 2, 3 |
| R-UP6, R-C7 | The newest compiler that the `nightly` switch and min-release-age allow. The start release of the platform follows min-release-age | L2 runs 1, 4 (and the 1-day-old 0.26.0 in all runs). L0 expect 2 |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 041"`)

| Name | Signature | File |
| --- | --- | --- |
| `Init.Plan` | `{ template : [App, Package], named : Try(Str, [Unset]), ci : [Ci, NoCi] }` (`platform` is a reserved word, also as a field) | `cli/lib/Init.roc` |
| `Init.read` | `Args -> Try(Init.Plan, Fail)` | same |
| `Init.start` | `{ name : Str, list : List(Index.Candidate), now : U64, min_age : U64 } -> Try(Index.Candidate, [NoRelease])` | same |
| `Init.run!` | `Fx, Args => I32` | same |
| `InitText.default_platform` | `Str`, the constant `roc-lang/basic-cli` (R-IN1). It is not a stub | `cli/lib/InitText.roc` |
| `InitText.app_file` | `{ name : Str, url : Str } -> Str` (`app` and `package` are reserved words, so no function has these names) | same |
| `InitText.package_file` | `Str` (stub value `todo: slice 041`) | same |
| `InitText.ci_file` | `Str -> Str` (the version of `tln`) | same |

Wired already (the code agent leaves them): `Run.roc` calls `Init.run!` for the command `init`, `main.roc` has `Init` and `InitText` in its module list. The doc of `Init` (step table and the notes of `Init.run!`) is the contract of the calls: `calls.log` of `init/it1-app` fixes the order. No other module changes.

## 3. The tested reading (the rules of the command)

| # | Rule | Source |
| --- | --- | --- |
| 1 | Operands: none or `app` is an app, `package` is a package. Other text or 2 operands: exit 2. `--ci` takes `github` (default) or `none`. `--platform` takes a full name `owner/repo` (as `tln add --platform`) | R-CM1, R-IN1 |
| 2 | The directory is `cwd!`. A `main.roc` there: exit 2, no other call. Nothing above or below is read before this check | R-IN7, R-PD15 |
| 3 | An app starts at the highest version of the releases of the platform that min-release-age does not hide (`Init.start`). The text has the platform entry and no `roc:` entry. The default platform has a hello world, another platform the smallest `main!` (D3) | R-IN1, R-C7, R-C9 |
| 4 | The flow of `tln upgrade` on the new file (`command: Upgrade`, `names: []`), with `--file` set to the new file. It can move the start release to an older one when the newest does not pass (code of slices 038 to 039c, not tested again for basic-cli), picks the compiler, asks for N, writes the pin | R-IN2, R-IN3, R-NI12, R-UP6, R-UP12 |
| 5 | Then the CI file (not `--ci none`). `data.written` has its absolute path at the end | R-IN6 |
| 6 | No `talon.toml`, no `.roc-version` | R-IN4, R-IN5, R-SO16 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/init.roc` expect 1 (18 rows) | `Init.read`: no operand, `app`, `package`, `--ci`, `--platform`, `--ci=none`, a bad template (also `App`), 2 operands, a bad `--ci` value, a flag with no value, `--platform` with `package`, a platform name with no `/`, with `@`, with 2 `/`, with an empty part | R-CM1 R-IN1 R-IN6 R-EC2 |
| L0 | same, expect 2 (10 rows) | `Init.start`: the highest version (not the newest time, and numbers: 0.10.0 is above 0.9.0), a 1-day-old release hidden by 2 days and visible with 0 or 1 day, a release at the limit is visible, nothing left, an empty list | R-IN1 R-IN2 R-C7 |
| L0 | same, expect 3 (12 checks) | `InitText`: the app text for the default platform and for another one, the package text, no `roc:` entry in any text, the CI file (the version twice, the runner, `TALON_AUTO_INSTALL`, the 3 later steps, no `tln audit`) | R-IN1 R-IN4 R-IN5 R-IN6 |
| L0 | `tests/unit/args.roc` (4 accepted rows, 8 message rows) | `init`, `init package --ci none ...`, `init app --platform ... --ci ...`, `init --allow-downloads --probe-downloads --yes` are accepted. `--dry-run`, `--no-check`, `--no-probe`, `--strategy`, `--snapshot`, `--file` are refused for `init`, `--ci` for `install`. The row with the two consent flags fails in the red state (`Args.allows` has no `init` for them yet) | R-CM1 R-IN3 R-FL7 R-FL12 |
| L2 | `init/it1-app` run 1 | a person says Enter, N missing: one prompt for N, the app with basic-cli 0.25.0 (0.26.0 is 1 day old), the pin N, the CI file, `projects.json`, the default compiler | R-CM1 R-IN1 R-IN2 R-IN3 R-IN4 R-IN5 R-IN6 R-NI12 R-DL3 R-PD9 R-SO16 R-C7 |
| L2 | same, run 2 | CI, `TALON_AUTO_INSTALL=no`, `--ci none`: N starts with no prompt, no `.github` | R-DL4 R-NI12 R-IN6 |
| L2 | same, run 3 | `init app --yes`: no prompt (no `ask`, no `tty`) | R-DL5 R-NI12 |
| L2 | same, run 4 | CI, `min-release-age = "0d"`: 0.26.0 and the download of n14 | R-C7 R-UP6 R-DL4 |
| L2 | same, run 5 | `--platform acme/pfx`: the smallest `main!`, pfx 0.2.0 fails on n12 so the pin is n11 and the note names n12 | R-IN1 R-IN2 |
| L2 | same, run 6 | `init package`: the package header, 2 probes (no build), the CI file | R-IN1 R-IN2 R-LD7 |
| L2 | same, run 7 | `main.roc` exists: exit 2, no change, no record, one `read_files` call after `cwd` | R-IN7 |
| L2 | same, run 8 | a directory below a `main.roc` and a workspace `talon.toml`: `i8/sub/main.roc` is written | R-PD15 |
| L2 | same, run 9 | `--json`: the envelope, `data.written` has `main.roc` and the CI file | R-OUT4 |
| L2 | same, run 10 | `init lib`: exit 2, the only call is `args` | R-IN1 R-EC2 |
| L2 | same, run 11 | a person says `n`, N missing: exit 13, nothing downloaded, `main.roc` is removed (`delete` call), the directory has no file | R-IN7 R-NI12 (answer Q1) |
| L2 | same, run 12 | `.github/workflows/ci.yml` exists: not overwritten, the note line, exit 0, `main.roc` written | R-IN7 (answer Q2) |
| L2 | same, run 13 | CI, `--allow-downloads`, `ROC_TOOLCHAIN` names n10 (not installed): `downloading 2 compilers`, exit 0 | R-IN3 R-DL5 (answer Q3) |

The world of `it1-app` is `research/slice-041-revert/gen-it.py` (the compilers n08, h0 (the `roc` on PATH), n10, n11, n12 (N), n14 (hidden by min-release-age); `roc-lang/basic-cli` 0.24.0, 0.25.0, 0.26.0 (1 day old); `acme/pfx` 0.1.0, 0.2.0). Each run has its own home and its own directory (the new word `cwd:<dir>` of the `commands` entry). `tree.diff` covers `home` and `project` only, so the files of all runs in the project are shown, the home files only for run 1.

Deep case: one (`it1-app`, 13 runs). L3: no new scenario (the real `roc` and the real downloads would be needed, and the flow is the one of slice 039 on the real `Fx`). L0: 3 expects in a new file (127 lines, 1.0 s cold with `--no-cache`, about 0.4 s in the run), and rows in `args.roc`. The step l0 was 8.8 s and once 10.0 s with the reference (baseline 8.3 s, budget 10 s): the budget has no room.

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| The files | `created main.roc`, then `created .github/workflows/ci.yml` (paths as seen from the current directory), after the lines of the flow and the line `resolved at ..., <n> probes` | runs 1 to 6, 8, 9, 13 |
| CI file exists | `note: .github/workflows/ci.yml exists, not written`, after the `created main.roc` line. The file is not in `data.written` | run 12 |
| The flow lines | the lines of `tln upgrade`: `check: passed`, `build: passed`, the path, `  + roc: <N>` (the member had no pin), the note `roc <N> is not used, ...` | all |
| `main.roc` exists | `tln: error[usage]: main.roc is in <dir> already. tln init never overwrites a file.`, exit 2 | run 7 |
| Bad template | `tln: error[usage]: unknown template 'lib': use app or package`, exit 2 | run 10, L0 |
| 2 operands | `tln init takes one template name (app or package), got <n> names` | L0 |
| Bad `--ci` | `--ci must be github or none, not '<value>'` | L0 |
| `--json` | the envelope of `upgrade` with `command` `init`. `data.written`: the files of the flow, then the CI file (absolute paths). No new field | run 9 |
| App text, default platform | `app [main!] {` + tab + `pf: platform "<release URL>",` + `}`, a blank line, `import pf.Stdout`, a blank line, a `main!` that prints `Hello, World!` and returns `Ok({})`. The `roc:` entry is added by the flow | run 1, L0 |
| App text, other platform | the same header and `main! = \|_args\| Ok({})` (the design gives no API of another platform) | run 5, L0 |
| Package text | `package [] {` and `}`: no module, no entry. The flow makes it `package [] { roc: "<N>" }` | run 6, L0 |
| CI file | the text of `tree.diff` of run 1: `name: CI`, `on: push, pull_request`, one job `check` on `ubuntu-latest` with `TALON_AUTO_INSTALL: "yes"` and the steps `actions/checkout@v4`, the install line `curl -fsSL https://github.com/roc-talon/talon/releases/download/v<version>/install.sh \| sh -s -- --yes --version <version>`, `tln install --frozen`, `roc check`, `roc test`. `<version>` is `Help.version` (`0.0.0` today). The step `tln audit` is P3 | run 1, L0 |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `init` writes the template (no `roc:` entry) and then runs the flow of `upgrade` on that file, with `--file` set to it. So the resolve, the ladder, the pin, the prompt and the downloads are one code path | a resolve on a header in memory (the flow reads files), the pin written by `init` itself |
| D2 | The start release is the highest version that min-release-age hides not, in the URL form of the newest one (`Index.new_entry`). The flow then moves it as `upgrade` does. R-C9 keeps a header value in the domain, so a young start release would win | the newest release with no age check (a young release would be written: R-SE3) |
| D3 | The default platform gets a hello world, another platform the smallest `main!` | one template for all (a hello world fails on another platform, the smallest one is dull for basic-cli) |
| D4 | `--platform` is a full name `owner/repo` (as `tln add --platform`, R-AD29) | a short name (no index of short names, R-AD6) |
| D5 | The package template exposes no module (`package [] {` `}`, checked with the pinned `roc check`) | a package with one module `Lib.roc` (a second file: R-IN7 for each file) |
| D6 | The output is the output of `upgrade` plus `created <path>` lines. `data.written` gets the CI file | a new `data.created` field |
| D7 | The CI file is written after the resolve passed | before (a failed run would leave a CI file with no project) |
| D8 | The first `main.roc` is written before the resolve (the flow needs the file). A failure removes it (answer Q1) | a temp copy only (a bigger change of the flow) |
| D9 | (changed by the review, answer Q3) `init` takes the consent flags `--allow-downloads` and `--probe-downloads` (and the global `--yes`), and no other resolve flag (`--dry-run`, `--no-check`, `--no-probe`, `--strategy`, `--snapshot`, `--slots`) | refuse the consent flags (the first version) |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-DL1, R-DL2, R-DL6, R-NI4 (optional downloads) for `init` | No row: the optional download is the code path of 039b (`init` shares it), and no run of `it1-app` needs an optional compiler |
| Out 2 | A failed run other than the exit 13 of run 11 (exit 10, 12, a failed download) | Same code (the removal wraps all of step 6 and 7). Run 11 shows it |
| Out 3 | A failure of the CI write (the main.roc is removed) | No fake fails `write_atomic!` for it |
| Out 4 | R-IN2 for a package whose newest nightly fails `roc check` | The ladder code is slice 038 to 039c. Run 6 has the pass |
| Out 5 | `tln audit` in the CI file (P3) | Phase |
| Out 6 | A real `install.sh` at the version of `tln` | `install/test.sh` (slice 052) |
| Out 7 | A package that is no platform (R-AD32), a host other than `github.com` | Q6 answer: only `owner/repo`; no check of the kind |
| Out 8 | An existing `talon.toml` in the directory | Q7 answer: read as `upgrade` reads it; no test now |

| Id | Question | Options (tested reading first) |
| --- | --- | --- |
| Q1 | Answered (review): a failure removes the files that this run made. Run 11. Question: A failed `init` (exit 13 when the person says `n` or no consent exists, exit 10 no tuple, exit 12 budget, a failed download): which files stay? The reference has written `main.roc` before the flow (D8) and leaves it. The CI file is not written. No test shows a failed run after the first write |
| Q2 | Answered (review): the CI file is skipped with a note, exit 0. Run 12. Question: `.github/workflows/ci.yml` exists (R-IN7: "never overwrites a file", but the exit 2 is named for `main.roc` only) |
| Q3 | Answered (review): `init` takes `--yes`, `--allow-downloads`, `--probe-downloads`, no other resolve flag. Run 13, `args.roc`. Question: Flags of `init`. R-FL7 names 5 commands that resolve, R-FL12 gives `--allow-downloads` and `--probe-downloads` to "commands that resolve", R-DL7 lists the commands under the consent rules and omits `init`, and R-IN3 applies R-DL1 to R-DL6 to `init`. Today `Args` refuses all of them for `init` (tested: `args.roc`). Then (1) a missing baseline compiler in CI is exit 13 whose text names `--allow-downloads`, a flag that `init` refuses (`TALON_AUTO_INSTALL=yes` works, and the CI file sets it); (2) the line `skipped N compiler downloads, pass --probe-downloads` would name a flag that `init` refuses; (3) `--yes` is the only opt-in for optional downloads |
| Q4 | Answered (review): exit 2. `init.roc` expect 1. Question: `--platform` with `package` |
| Q5 | Answered (review): `init` downloads the newest nightly (R-NI12), no exit 18. No row (the baseline of a fresh template stays open for the code agent: the compiler that the ranks select). Question: No compiler at all (no `roc` on `PATH`, nothing installed): R-SO14 gives exit 18, R-NI12 says that `init` downloads the newest nightly. `upgrade roc` stops here (slice 039). A new user runs `init` first |
| Q6 | Answered (review): only `owner/repo`, any other form exit 2. `init.roc` expect 1. Question: `--platform` forms: only `owner/repo` is tested. `owner/repo@sel`, a package that is no platform (R-AD32), a name that is not on `github.com` |
| Q7 | Answered (review): read as `upgrade` reads it. No row. Question: A `talon.toml` in the directory (R-IN5 only says that `init` creates none): does the flow read it? Its `[toolchain] roc` range and `[resolution]` settings change the pick |
| Q8 | Answered (review): accepted. With `--probe-downloads` accepted (Q3), the skipped line names a flag that `init` takes. Question: U5 for `init`: one prompt names the required downloads (N, and H when it is not installed). Reading (c) of slice 039 |
| Q9 | Answered (review): accepted (D2). Question: The start release hides young releases (D2). R-C7 names a "named version" and the releases that Talon selects by itself, R-IN1 says "the newest release" |

Design gaps (for the human, no design file is changed here):

| Gap | Where |
| --- | --- |
| R-DL7 omits `init` from the commands under the consent rules, R-IN3 and R-DL3, R-DL4 name it | CLI R-DL7, R-IN3 |
| "Commands that resolve" (R-FL12) is not a list for `--allow-downloads` and `--probe-downloads`. R-FL7 has a list of 5 | CLI R-FL7, R-FL12 |
| R-IN7 names `main.roc` for the exit code and "a file" for the rule | CLI R-IN7 |
| R-IN2 does not say what the baseline of a fresh template is (R-BL1: the current header, but there is no pin and no compiler may exist) | CLI R-IN2, Resolution R-BL1, R-SO14 |

## 8. Compiler and tool limits met (for the manager and the code agent)

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | `app`, `package` and `platform` are reserved words, also as the name of a function or a record field | `InitText.app_file`, `InitText.package_file`, `Init.Plan.named` | use another name |
| C2 | A warning fails `roc check` (exit 2), also an unused parameter | mutation I8 first did not compile (`plan` unused) | the mutation keeps the use of `plan` |
| C3 | `roc fmt` moves a `roc:` pin to its own version, so `roc fmt --check` of a new `main.roc` fails on the pin only (R-H2) | none: the texts were checked with `roc fmt` and differ in the pin only | |

## 9. Notes for the code agent

| Topic | Note (the reference was not seen by you: these notes describe it) |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/init/it1-app/rules` has the text of each run. `research/slice-041-revert/gen-it.py` made the case (do not run it) |
| New harness word | `tests/commands/main.roc` and `FakeFx.roc`: the word `cwd:<dir>` of a run sets `cwd!` to `project/<dir>` (file `fx/cwd`). It changes no old case |
| `Init.read` | `Args.parse` has checked the flags. `--platform` and `--ci` have a value (`Args.takes_value`). The checks are the table in the doc of `Init.read` |
| `Init.start` | `published_at + min_age <= now` keeps a release. Then `Index.new_entry` (the URL form) and `Index.order(list, Highest).first()` |
| `Init.run!` | See the step table and the notes in its doc. In short: `Common.shown_fx`, `fx.env_all!()`, `Roots.from_env`, `Net.from_env`, `Clock.now!`, `fx.cwd!()`, the exists check, an app: `Github.releases!`, `Index.candidates`, one `read_files!` of `config.toml` (`ConfigToml.read`), `Init.start`, `InitText.app_file`; one `write_atomic!` of `main.roc`; `given = { ..args, operands: [], options: [], file: Ok(<cwd>/main.roc) }`, `Opts.read(given)`, `Update.begin!(shown, given)`, `Update.resolve!(shown, given, opts, begun, { command: Upgrade, names: [] })`; the CI file; `Update.print!` with `written` that has the CI path; then `created <path>` lines on `shown.out!`. A local variable named `start` or `read` in the module of these methods is a duplicate definition |
| `Update.print!` | It prints the line R-DT5 and the JSON envelope with `command: args.typed` (`init`). `Update.begin!` records the file (R-PD9) |
| Review changes | (1) `Args.allows`: `--allow-downloads` and `--probe-downloads` are allowed for `init` too (`cli/lib/Args.roc`, the two lines of the flag table). (2) `Init.read` checks `--platform`: with `package` and with a name that is not `owner/repo` are usage failures (the texts are in the doc of `Init.read`). (3) The flow after the first write is one function; on a failure `delete!` of `<cwd>/main.roc` and the failure again (step 7b of the doc). (4) The CI file: `read_files!` of it, `write_atomic!` only when `NotFound`; when it exists the output has `note: .github/workflows/ci.yml exists, not written` after the `created` lines, and `data.written` has no CI path. (5) The consent flags are the only entries of `options` of the record that the flow gets |
| Size | About 170 lines of code with `InitText` and `Args` |

## 10. Changed old tests (TW21)

None of the old expected files change. The reference passes all old L0, L2 and L3 cases and the selftest.

| File | Change | Reason |
| --- | --- | --- |
| `tests/commands/main.roc`, `tests/commands/FakeFx.roc` | the word `cwd:<dir>` of a run and the file `fx/cwd` | `init` works in the current directory (R-PD15), so each run of a case needs its own directory. No run of an old case has the word, so `cwd!` gives `project/` as before |
| `tests/unit/args.roc` | 4 rows in the list of accepted lines, 8 rows in the list of messages | `init` flags (answer Q3). The accepted row with the consent flags fails in the red state |

## 11. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Baseline before this slice (`research/slice-041-revert/baseline-run.log`) | all pass: check 1.2, fmt 0.1, l0 8.3, l2 4.4, l3 9.8, selftest 11.3, l1 31.0 |
| Reference (`reference-run.log`) | all pass: check 1.3, fmt 0.1, l0 8.8, l2 5.2, l3 9.9, selftest 11.7, l1 30.9 |
| Red, with the stubs (`red-run.log`) | check, fmt, l3, selftest, l1 pass. l0 FAIL: `init.roc` 3 of 3 expects crash `todo: slice 041`. l2 FAIL: `init/it1-app`: the test app crashes at the first `init` run (`todo: slice 041`, no exit file). 101 other L2 cases pass |

| Reference after the review (`reference-run2.log`) | all pass: check 1.2, fmt 0.2, l0 10.0, l2 2.0, l3 9.7, selftest 11.6, l1 31.2 |
| Red after the review, with the stubs (`red-run2.log`) | check, fmt, l3, selftest, l1 pass. l0 FAIL: `init.roc` and `args.roc` (the accepted row with the consent flags and the old message rows). l2 FAIL: `init/it1-app` (`todo: slice 041`). 101 other L2 cases pass |

Revert check (`research/slice-041-revert/mutate.py`, the reference in the tree, filtered runs only, `mutate.log`): 10 mutations, 10 caught, and 5 more for the review changes (I12 to I16), all caught. I8 and I14 first did not compile (an unused variable) and were fixed.

| Id | Mutation | Caught by |
| --- | --- | --- |
| I1 | an existing `main.roc` is overwritten | `it1-app` (run 7) |
| I2 | `init` also looks for a `main.roc` in the parent directory | `it1-app` (run 8) |
| I3 | the start release ignores min-release-age | `init.roc` expect 2 |
| I4 | `init` writes `.roc-version` | `it1-app` (`tree.diff`) |
| I6 | `--ci none` still writes the CI file | `init.roc` expect 1 |
| I7 | `init package` writes an app | `it1-app` (run 6) |
| I8 | `--platform` is ignored | `it1-app` (run 5) |
| I9 | the install line of the CI file has no version and no `--yes` | `init.roc` expect 3 |
| I10 | the flow has no `--file` (it searches for the project) | `it1-app` |
| I11 | the ladder is skipped (`no_check`) | `it1-app` |
| I12 | a failed run does not remove its `main.roc` (Q1) | `it1-app` (run 11) |
| I13 | an existing CI file is overwritten (Q2) | `it1-app` (run 12) |
| I14 | the consent flags do not reach the flow (Q3) | `it1-app` (run 13) |
| I15 | `--platform` is accepted with `package` (Q4) | `init.roc` expect 1 |
| I16 | a platform name with `@` is accepted (Q6) | `init.roc` expect 1 |

After the runs the reference was compared with the tree, and the tree was put back to the stubs. The reference was deleted after the review.

## 12. Files

| File | State |
| --- | --- |
| `docs/slices/041-init.md` | new (this file) |
| `cli/lib/Init.roc`, `cli/lib/InitText.roc` | new, stubs (`InitText.default_platform` is real) |
| `cli/lib/Args.roc` | not changed (the code agent adds `init` to the 2 flags, see section 9) |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | wired (the dispatch of `init`, the module list). Copies before in `research/slice-041-revert/before/` |
| `tests/unit/init.roc` | new, 127 lines |
| `tests/unit/args.roc` | +12 rows |
| `tests/commands/main.roc`, `tests/commands/FakeFx.roc` | the word `cwd:<dir>` |
| `tests/commands/cases/init/it1-app/` | new (13 runs) |
| `research/slice-041-revert/` | `before/` (with `NEW.txt`), `stubs/`, `gen-it.py`, `it1-rules.txt`, `mutate.py`, `mutate.log`, `baseline-run.log`, `reference-run.log`, `red-run.log`, `reference-run2.log`, `red-run2.log` |

## Review (manager, 2026-10-24)

Accepted, no split, with 3 changes. The test agent made them with the reference (section 11), then deleted `research/slice-041-revert/reference/`.

| Item | Answer |
| --- | --- |
| Q1 | Change. On any failure after `init` wrote its first file (exit 10, 12, 13, a failed download), `init` removes the files that this run created, so the person can run `init` again. It never removes a file that it did not create. Run 11 |
| Q2 | Change. An existing `.github/workflows/ci.yml` is not overwritten: `init` skips it with a note, exit 0. Run 12 |
| Q3 | Change. R-IN3 applies R-DL1 to R-DL6, so `init` takes `--yes`, `--allow-downloads` and `--probe-downloads`. The other resolve flags (`--dry-run`, `--no-check`, `--no-probe`, `--strategy`, `--snapshot`) stay refused. Run 13, `args.roc` |
| Q4, Q6 | `--platform` with `package`: exit 2. Only `owner/repo`, any other form: exit 2. `init.roc` expect 1 |
| Q5 | Accepted: `init` downloads the newest nightly (R-NI12), no exit 18 |
| Q7 | An existing `talon.toml` is read as `upgrade` reads it. No test now |
| Q8, Q9 (D2) | Accepted |
| D1 to D9, TW24 texts | Accepted (D9 changed as Q3) |
| Design gaps | Recorded by the manager |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| Decision | Rejected |
| --- | --- |
| No release left after min-release-age (`Init.start` gives `NoRelease`): failure of kind `Usage` (exit 2), `no release of <name> is old enough for min-release-age` (as the `add` failure for no release) | kind `Network`, kind `NoTuple` |
| `Github.releases!` with `Cached(t)` prints `Github.offline_line(t)` on stderr, and a candidate warning is printed as `warning: <text>` (as `PickIndex.index!`) | no print |
| A read of `main.roc` or the CI file that is neither a file nor `NotFound`: kind `Environment`, `cannot read <path>` | treat as not there |

## Gap tests (test agent)

The code agent's decisions that were visible behavior with no test. Tests only, no code changed. `it1-app` has 15 runs now (runs 1 to 13 have the same output as before: the new lines in the expected files are all after run 13; run 15 is red with the code of the code agent, see below). The mutations are in `research/slice-041-revert/gap-mutate.py`, result in `gap-mutate.log`. After them `sha256sum -c research/slice-041-revert/code-final.sha256` is OK for all 6 files.

| Gap | New test | Hand mutation | Result |
| --- | --- | --- | --- |
| No release old enough for min-release-age (`start_url!` text and kind, not in `Init.start`) | `it1-app` run 14: `--platform acme/young` (one release, 1 day old): exit 2, `no release of acme/young is old enough for min-release-age`, no `main.roc` | the failure has kind `Network` (G1) | caught (exit code and stderr) |
| The `Cached(t)` line on stderr (R-DI12: once) | `it1-app` run 15: `--offline` with the cached lists of basic-cli and of the compilers: the expected stderr has one line `index: cached at 2026-10-15T11:59:50Z` | G2: the line is not printed by `init` (the flow still prints one) | caught only as a count of 0 against 1. With the current code the run is RED: stderr has 2 lines (`init` and `PickIndex.index!` print the same line) |

R-DI12 says a command prints the line once, so the expected file has one line. The current code prints it twice (once in `start_url!`, once in the resolve flow, which reads the list again), so run 15 fails with the code of the code agent. That is a code bug for the code agent: print the line once (for example `init` does not print it when the flow does, or the flow reads the list that `init` fetched). The mutation G2 shows that a missing print is also seen (0 lines). The read-error decision (not a file and not `NotFound`) is not tested: the fake Fx has no failing read.

## Verify results

| Item | Result |
| --- | --- |
| `scripts/test.sh` | all pass: check 1.6, fmt 0.2, l0 9.6, l2 5.8, l3 9.9, selftest 11.7, l1 65.8 (l1 over its budget on a loaded machine, 29.8 s in the run before) |
| Code | `cli/lib/Init.roc` 212 lines, `cli/lib/InitText.roc` 58 lines, `Args.roc` 2 lines changed. Copy: `research/slice-041-revert/code-final/`, check: `sha256sum -c research/slice-041-revert/code-final.sha256` |
| Revert check | 10 mutations, 10 caught (`research/slice-041-revert/agent-mutate.py`, `agent-results.md`) |

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | a failed run does not remove its `main.roc` | `it1-app` |
| M2 | an existing CI file is overwritten | `it1-app` |
| M3 | `--ci none` still writes the CI file | `it1-app` |
| M4 | `init` refuses `--probe-downloads` | `args.roc` |
| M5 | `init` refuses `--allow-downloads` | `args.roc`, `it1-app` |
| M6 | a platform name with `@` is accepted | `init.roc` expect 1 |
| M7 | the consent flags do not reach the flow | `it1-app` |
| M8 | an existing `main.roc` is overwritten | `it1-app` |
| M9 | the start release ignores min-release-age | `init.roc` expect 2, `it1-app` |
| M10 | `--platform` is accepted with `package` | `init.roc` expect 1 |


| Item | Result |
| --- | --- |
| Fix R-DI12 (run 15, `init --offline`) | `Init.start_url!` no longer prints `index: cached at <time>`: the flow of step 6 reads the same list (`PickIndex.index!`) and prints it once. `Init.roc` 209 lines, `code-final/` and `code-final.sha256` updated. `tests/commands/run.sh init`: 1 passed. Hand mutation (the second print put back): run 15 fails with the line twice, then the fix was restored. Full `scripts/test.sh`: check, fmt, l0 8.1, l2 5.4, selftest, l1 pass. l3 FAIL `cache/gc1-real` (step 8: the package CZsY7... is removed, the case expects it to stay). It also fails with the `Init.roc` from before this fix, and no `cache` file changed, so it is not from this fix (the case uses the real clock and the real files) |

## Close (manager, 2026-10-24)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-041-revert/code-final.sha256` | OK, 6 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.2, fmt 0.2, l0 8.5, l2 3.3, l3 10.2, selftest 11.5, l1 29.5 s |
| R-DI12 fix (run 15) | one `index: cached at` line; red before the fix, green after |
| `cache/gc1-real` (l3) | failed after 24 h: the given package `CZsY7...` kept the mtime of the git checkout, so R-GC4 (1 day, real clock) saw it as old. The manager added a `touch` of its files to the case setup (copy in `before/`). Not a code fault. |
