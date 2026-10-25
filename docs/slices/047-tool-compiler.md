# 047 Compiler choice of a tool

Phase: P1. Status: done

Slice 047 is the compiler step of `tln tool install` when the pin of the app header is not installed (CLI 6.4: R-T11 to R-T21, R-NI8; Resolution R-PP2 option 2). Slice 046 stopped there with exit 13 (D5). Now Talon uses an installed release that has a recorded build pass for the closure (R-T13), else it asks (R-NI8) or follows the flags (R-T16). Option 2 checks the installed releases at the same time, builds them in order until one passes, and records each try in `compat.db`.

Size (TW19): the private reference has 490 lines in 3 new modules (`ToolCompiler.roc` 257, `ToolCompilerFlow.roc` 143, `ToolTry.roc` 90) and 25 more lines in `ToolFlow.roc` (449 to 474). The plan row says 350 lines. This is about 330 lines without comments and blank lines, so no split is proposed. No module is above 490 lines (section 2).

Live reads: none. No real network and no real long build in L0 to L3. The L3 case uses 2 fake compilers (shell scripts) and the real `roc unbundle`.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-T11 | The pin is the compiler. A header with no pin stays exit 2 (D3 of 046, Q-A) | L0 `ToolCompilerTest` 5. L2 `ti2-refusals` runs 5 to 7 (changed `calls.log`), `ti3-compiler` run 8 |
| R-T12 | The pin is installed: use it, no evidence call, no prompt | L2 `ti1-install` run 1 (unchanged `calls.log`: no `db_query`) |
| R-T13 | The pin is missing: an installed release with a recorded pass for the closure builds the app, no prompt. The line `built with <id> (pin: <pin>)` | L0 `ToolCompilerTest` 1 to 4, 7. L2 `ti3-compiler` runs 1, 6 (evidence wins over `--roc pinned`). L3 step 2 (the real `compat.db`) |
| R-T14 | Other releases are installed: the prompt has options 1, 2, 3 | L0 `ToolCompilerTest` 6, 7. L2 `ti3-compiler` runs 2, 4, 5, 7, 8 |
| R-T15 | No other release is installed: the prompt has options 1 and 3 | L0 `ToolCompilerTest` 6, 7. L2 `ti4-nothing` run 1 (option 2 is not offered, asked again) |
| R-T16 | No person: `--roc pinned` is option 1, `--roc installed` is option 2, `--yes` or `TALON_AUTO_INSTALL=yes` is option 1, else exit 13 that names the flags | L0 `ToolCompilerTest` 5, 7. L2 `ti3-compiler` runs 3, 6, `ti4-nothing` runs 2, 3. L3 steps 3, 4 |
| R-T17 | The order of the releases: newer before older. Local builds are dropped | L0 `ToolCompilerTest` 1 (10 rows). L2 `ti3-compiler` runs 2, 3 (the order of the tries). L3 step 1 |
| R-T18 | `roc check` with `probe.timeout` for each release | L0 `ToolCompilerTest` 8. L2 `ti3-compiler` run 2 (`config.toml` has `timeout = 20`) |
| R-T19 | A check that passes gets `roc build`. A build that fails goes to the next release | L2 `ti3-compiler` run 2 (B fails the build, C passes). L3 step 1 |
| R-T20 | All fail: the prompt again with options 1 and 3 and the list of each release with its first error line | L0 `ToolCompilerTest` 6, 7. L2 `ti3-compiler` runs 3, 4. L3 step 3 |
| R-T21 | The pass or fail of each try is recorded in `compat.db` (a check row and a build row) | L0 `ToolCompilerTest` 4, 8. L2 `ti3-compiler` runs 2, 3, 4 (`db_write` calls and `compat.tsv`). L3 `facts.tsv` |
| R-NI8 | The prompt: text, options, default 1, answers | L0 `ToolCompilerTest` 6, 7. L2 `ti3-compiler` runs 2, 4, 5, 7, 8, `ti4-nothing` run 1 |
| R-PP2 (option 2) | The checks of the releases run at the same time (one `probes!` round, pool 12) | L2 `ti3-compiler` runs 2, 3, 4 (`probes 4`). L3 step 1 (each fake check waits for the other one to start) |
| R-PP3 (as used) | The results are read in the order of the list | L2 `ti3-compiler` run 3 (the order of the list in the error) |
| R-NM5, R-NM6, R-NM9, R-DL1 to R-DL5 (as used) | Flags answer the prompt, the line of the answer, option 1 is the default | L0 `ToolCompilerTest` 5, 6. L2 `ti3-compiler` runs 3, 6, 8 |
| R-HF1 (as used) | `tty!` is called at most once and only when the answer needs it | L2 `ti3-compiler` runs 1, 6 (no `tty`), `ti2-refusals` (changed `calls.log`) |
| R-BS2, R-P3, R-P4 (as used) | The key of a build fact is (platform hash, release id, host target) and the closure digest | L0 `ToolCompilerTest` 2, 3, 8 |

`MISSING=1 scripts/rules.sh R-T R-NI R-PP` lists R-T7, R-T22, R-T24, R-T25 (slice 048), R-NI9 (section 7), and R-NI10, R-NI11, R-NI15, R-NI16, R-PP1 (other slices: `tool rm talon`, setup, probes). It lists none of R-T11 to R-T21, R-NI8, R-PP2.

## 2. Files

New files (also in `research/slice-047-revert/before/NEW.txt`). The code agent writes the bodies of the stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/ToolCompiler.roc` (stub) | 151, 257 | Part A, pure: types `Run`, `Attempt`, `Tried`, `Want`. The functions of section 3 |
| `cli/lib/ToolCompilerFlow.roc` (stub) | 29, 143 | Part C: `choose!`. The steps 1 to 7 are in the table of its doc comment |
| `cli/lib/ToolTry.roc` (stub) | 26, 90 | Part C: `installed!` (option 2). The steps 1 to 5 are in the table of its doc comment |
| `tests/unit/ToolCompilerTest.roc` | 302 | 8 `expect`s (L0) |
| `tests/commands/cases/tool/ti3-compiler/` | 39 files | L2: 8 runs |
| `tests/commands/cases/tool/ti4-nothing/` | 18 files | L2: 3 runs |
| `tests/scenarios/tools/ti2-tool-compiler/` | `cmd` 32, 22 files | L3: 4 steps |
| `tests/tools/mk-tool-pf.sh` | 52 | Makes the release routes, the platform release and the app bundles of the L3 case |
| `research/slice-047-revert/` | | The private reference (`reference/lib/`), the stubs (`stubs/lib/`), `restore.sh`, `reference.sh`, `mkstubs.py`, `gen-compiler.py` (writes only `ti3-compiler` and `ti4-nothing`), `mutants.py`, `mutants.log`, `red-all.log`, `expect-before/` (TW21) |

Changed files (a copy of each is in `research/slice-047-revert/before/`):

| File | Change |
| --- | --- |
| `cli/lib/main.roc` | exposes `ToolCompiler`, `ToolCompilerFlow`, `ToolTry` |
| `cli/lib/ToolInstall.roc` | types only, in the stub state: `Plan.roc` is `[Auto, Pinned, Installed]`, `want` takes the same type and its last arm is `_ => Err(NoFlag)`. `read` still refuses `--roc installed` in the stub state: the code agent makes `Ok("installed") => Installed` |
| `cli/lib/ToolFlow.roc` | not changed in the stub state. The code agent replaces `compiler_id!` and `built!` (section 10) |
| `tests/unit/ToolTest.roc` | expect 1: the row `--roc installed` now gives `Installed` (it was a refusal), and a new row with `--as q` |
| `tests/unit/l0-5.roc` | `import ToolCompilerTest` (the driver with the lowest time in `.work/l0-times`) |
| `tests/commands/cases/tool/ti2-refusals/expect/calls.log` | 3 lines added: run 6 has `db_query ... facts=1` and `tty`, run 7 has `db_query ... facts=1` (the evidence pass, D-E1). The old file is in `research/slice-047-revert/expect-before/ti2-refusals/`, the diff was checked (TW21) |

Module plan (TW19, the manager may change it): `ToolFlow.roc` is 449 lines now and 474 lines in the reference, `ToolInstall.roc` is 442. Both stay under 490. If the code agent goes over 490 in `ToolFlow.roc`, the cut is a new `ToolBuild.roc` with steps 10 to 13 (`build!`, the lock, the install). Do not grow `ToolInstall.roc`.

## 3. Public signatures

`ToolCompiler` is pure (Part A). `ToolCompilerFlow.choose!` and `ToolTry.installed!` are direct style over `Fx`. No new `Fx` call.

| Module | Name | Signature |
| --- | --- | --- |
| `ToolCompiler` | `Run`, `Attempt`, `Tried`, `Want` | types |
| `ToolCompiler` | `candidates` | `List(Str) -> List(Str)` |
| `ToolCompiler` | `digest` | `{ bundle : Str, hashes : List(Str) } -> Str` |
| `ToolCompiler` | `evidence_keys` | `{ pf : Try(Str, [None]), target : Str, ids : List(Str) } -> List(Db.Key)` |
| `ToolCompiler` | `evidence` | `{ ids : List(Str), pf : Try(Str, [None]), target : Str, digest : Str, facts : List(Db.Fact) } -> Try(Str, [None])` |
| `ToolCompiler` | `decide` | `{ id : Str, roc : [Auto, Pinned, Installed], auto : [Ask, Yes, No], yes : Bool, mode : Mode } -> Want` |
| `ToolCompiler` | `prompt` | `{ name : Str, version : Str, pin : Str, size : U64, installed : U64, tried : List(Tried) } -> Prompt` |
| `ToolCompiler` | `allowed` | `{ answer : Answer, installed : U64 } -> Bool` |
| `ToolCompiler` | `trying_line`, `built_line`, `declined`, `all_failed` | texts and failures |
| `ToolCompiler` | `check_spec`, `check_row`, `build_row` | the probe of the check, the two facts |
| `ToolCompiler` | `tried_of`, `tried_text` | the record and the line of a failed release |
| `ToolCompilerFlow` | `Chosen`, `choose!` | `Fx, Args, ToolCompiler.Run, { build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) } => Try(Chosen, Fail)` |
| `ToolTry` | `Result`, `installed!` | `Fx, ToolCompiler.Run, { ids, build } => Try(ToolTry.Result, Fail)` |

The stubs have the full signatures and the doc comments. The doc comments are the contract: the tables in them give the rows of each function and the order of the calls.

## 4. Tests

Layers: L0 pure decisions (`ToolCompilerTest`), L2 the `Fx` calls and the files with a fake `Fx` (`calls.log` is the order of the calls), L3 the real `Fx` with fake HTTP and fake compilers (TESTING.md 3).

| Layer | Where | Case | Rules |
| --- | --- | --- | --- |
| L0 | `ToolCompilerTest` expect 1 | `candidates`: 10 rows (order, locals dropped, versions, same-day text order, no repeat) | R-T17 |
| L0 | expect 2 | `digest` (order and repeats do not matter), `evidence_keys` (one key for each id, none with no platform hash) | R-T13, R-BS2, R-P4 |
| L0 | expect 3 | `evidence`: 15 rows (a pass, a fail blocks, another digest, another id, another target, a check row, no key, the first in order) | R-T13, R-T17, R-BS2 |
| L0 | expect 4 | round trip: `build_row` and `check_row` into `evidence` | R-T21, R-T13 |
| L0 | expect 5 | `decide`: 23 rows (`--roc installed` wins, `pinned`, `--yes`, `TALON_AUTO_INSTALL` yes, no and ask, the mode, a pin that is not a nightly tag) | R-T14 to R-T16, R-NM5, R-NM9, R-DL1 to R-DL5 |
| L0 | expect 6 | `prompt`: id, kind, shape, default, texts with and without `tried`, 1 release, 0 releases, the answer lines, `Prompt.decide` (15 rows) | R-NI8, R-T14, R-T15, R-T20, R-NR2 |
| L0 | expect 7 | `allowed`, `trying_line`, `built_line`, `tried_text`, `declined`, `all_failed`: 18 rows | R-NI8, R-T20, R-T16, R-NM6 |
| L0 | expect 8 | `check_spec`, `check_row`, `build_row`: 14 rows | R-T18, R-T21 |
| L0 | `ToolTest` expect 1 (changed) | `read`: `--roc installed` is `Installed` | R-CM16, R-T16 |
| L2 | `tool/ti3-compiler` | 8 runs, below | R-T6, R-T13 to R-T21, R-NI8, R-PP2, R-PP3, R-NM6, R-HF1 |
| L2 | `tool/ti4-nothing` | 3 runs, below | R-T15, R-T16, R-T20, R-NI8 |
| L2 | `tool/ti2-refusals` (changed `calls.log`) | runs 6, 7 | R-T13, R-T16 |
| L3 | `tools/ti2-tool-compiler` | 4 steps, below | R-T13, R-T14, R-T16 to R-T21, R-NI8, R-PP2, R-PP3, R-NM6, R-HF1 |

L2 `ti3-compiler`. Home with 4 installed compilers (A = nightly-2026-10-14-38a3029, B = nightly-2026-10-12-2664a27, C = nightly-2026-10-05-aaaaaaa, D = nightly-2026-10-01-bbbbbbb), no pin installed (the pin is nightly-2026-10-11-1a2b3c4), `config.toml` has `[probe] timeout = 20`, a fake tty, `fx/answers` is `2, 2, 3, 3, 2, 1, Enter`.

| Run | Words | Result |
| --- | --- | --- |
| 1 | `tool install acme/ev` | Evidence: one `db_query` with 4 keys. A has a fail (blocked), B and C a pass. B is first in the order. `built with B`, no `tty`, no check, one build |
| 2 | `tool install acme/two` (answer 2) | No evidence (the facts are for another bundle). The prompt. One round of 4 checks (`probes 4`, `timeout=20`). One `db_write` with 4 rows. Builds in order: B fails (a row), C passes (a row). D is never built. `built with C` |
| 3 | `tool install acme/three --roc installed` (no person) | `trying 4 installed compiler releases`. A, C, D fail the check, B fails the build. Exit 13 with the list and the flags. The facts are written |
| 4 | `tool install acme/again` (answers 2, 3) | The 4 checks fail. The prompt again with the list and options 1 and 3. Answer 3: exit 13 |
| 5 | `tool install acme/cancel` (answer 3) | Exit 13, no download, no probe |
| 6 | `tool install acme/evp --roc pinned` | Evidence (a pass of D) comes before the flag: `built with D`, no download, no check |
| 7 | `tool install acme/redo` (answers 2, 1) | Review 2 (C3). Option 2: A, C, D fail the check, B passes the check and fails the build. The prompt again with the list. Answer 1: download the pin and build with it. The `platform` line is printed once for the command (R-SE8): the build with the pin prints only `building ...` |
| 8 | `tool install acme/dl` (Enter) | The default is option 1: download the pin (73.7 MB), build with it |

L2 `ti4-nothing`: no installed compiler. Run 1 (answers 2, 3): option 2 is not offered, the prompt is asked again, exit 13. Run 2 (`--roc installed`): exit 13 `no compiler release is installed to try`, no `trying` line. Run 3 (no flag, no person): exit 13 with the consent text of slice 046.

L3 `tools/ti2-tool-compiler` (tag `tty`, a pseudo terminal, `given/answers` is `2`): step 1 `acme/foo`: the prompt, answer 2, both checks run at the same time (each fake check waits for the other one to start), A fails the check, B passes, the build uses B. Step 2: remove the tool, install again with no person: the evidence comes from the real `compat.db` (`facts.tsv`), no prompt, no check, one build with B. Step 3: `acme/bar --roc installed`: both checks fail, exit 13 with the list. Step 4: `acme/bar` with no flag and no person: exit 13, no probe.

The expected files of L2 and L3 were written with `UPDATE=1` from the reference and read by eye against the design (TW21). L3 passed 3 runs in a row. No test depends on the age of a given file.

## 5. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stderr, evidence or a passing option 2 | `built with <id> (pin: <pin>)` (the design text). For evidence it is before the build |
| stderr, a flag chose option 2 | `trying <n> installed compiler releases` (`release` for 1). No line for a person's answer, and none with no release |
| prompt (question) | `<name> <version> was tested with compiler release <pin>. It is not installed.` then with a failed try `No installed compiler release built it:` and one line `  <tried_text>` for each. Then `1) Download <pin> (<size>)    [default]`, `2) Try the <n> installed compiler releases` (only with `n` above 0), `3) Cancel`, `Select an option` |
| prompt (answer lines, R-NM6) | `downloading <pin> (<size>)`, `trying <n> installed compiler releases`, `cancelled` |
| `tried_text` | `<id>: check failed: <first error title>`, `<id>: build failed: <title>`, no title: `<id>: <stage> failed`, hang: `<id>: <stage> did not end in time`, crash or no fact: `<id>: <stage> gave no result: <text>` |
| exit 13, option 3 or a cancel | `the compiler <pin> is not installed. Nothing was downloaded and nothing was built. Run: tln roc install <pin>, pass --roc pinned, or set TALON_AUTO_INSTALL=yes.` |
| exit 13, all fail, no person | `no installed compiler release built <name> <version> (<tried_text>; <tried_text>). The compiler <pin> is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes.` |
| exit 13, `--roc installed`, no release | `no compiler release is installed to try for <name> <version>. The compiler <pin> is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes.` |
| prompt id and kind | `tool-compiler`, `Required(["--roc pinned", "--roc installed", "TALON_AUTO_INSTALL=yes"])`, `Options(3)`, default `Option(1)`, subject `the compiler <pin>` |
| `compat.db` | A check row (hash = the app bundle, target `any`) and a build row (key = platform hash, release id, host target, closure = digest of the bundle hash and the header hashes) for each try |

## 6. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected | Why |
| --- | --- | --- | --- |
| D-E1 | "A recorded pass for this closure" is a build fact. Key: (platform hash, release id, host target). Closure: `BuildSkip.digest` of the app bundle hash and the header `hashes` (platform first, D13 of 046). Evidence is `BuildSkip.decide == Skip` (a pass and no fail, hang or crash of that digest). With no platform hash there is no key: no evidence and no build row. The tries write a check row (`Facts.of_probe`, Check, target `any`) and a build row (`BuildSkip.row`) | A unit pass of each closure hash. Check-only evidence | R-T13 says the closure. The build key is the one that R-BS1 and R-BS2 already use, so one row serves `tln tool install` and a project build |
| D-E2 | With several evidence releases, the first in the R-T17 order. In P1 that is newer before older over all releases (`Pin.order`, no times): with no registry matrix each release is an epoch of its own (R-EP4), so "the epoch of the pin" is empty (the pin is not installed). Local builds (`git-`, `link-`, `copy-`) are dropped | Newer-than-pin group first. Skip a release with a recorded fail in option 2 | The design says the order is epoch based. Without epochs the only fixed order is newest first |
| D-E3 | R-T12 (pin installed) wins over all. Evidence wins over flags (a flag only answers the prompt). `--roc installed` wins over `--yes`, `TALON_AUTO_INSTALL` and the mode, and `TALON_AUTO_INSTALL=no` does not stop it (no download). `Consent.required_want` handles the other rows, including the refusal of a pin that is not a nightly tag. `ToolInstall.want` stays the source of the stop texts | The flag wins over evidence | R-T13 comes before the prompt in the order of R-T11 |
| D-E4 | The prompt text of section 5. Options 1 and 3 keep their numbers when option 2 is not offered, and the flow asks again for an answer that is not offered (`allowed`) | Renumber to 1 and 2 | The design says "options 1 and 3" (R-T15, R-T20) |
| D-E5 | Option 2 runs the checks of all releases in one `probes!` round (pool 12, list order), then builds one by one in order until the first pass. After all fail: a person gets the prompt again (options 1 and 3, with the list). No person (also `--roc installed`) gets exit 13 `all_failed`. Option 3 or a cancel gives `declined` (exit 13). `--roc installed` with no installed release is exit 13 | Builds in parallel (too much load, R-PP2 says the checks). Checks one by one | R-PP2: option 2 runs at the same time. R-T19: the first pass gets the build |
| D-E6 | `tty!` is called at most once and only when `Consent.required_want` says `NeedTty` (R-HF1) | Ask at the start | The evidence pass and a flag need no person |
| D-E7 | The evidence `db_query!` is made only when there are keys (a platform hash and installed releases). The header with no pin is exit 2 as in 046 (D3), with the same calls | A query for each command | A command with nothing to look up makes no call |
| D-E8 | Option 2 uses `probe.timeout` of `config.toml` (`Probe.settings`) for the checks. `--slots` stays out (046 C5: pool 12) | `--slots` | The tool commands have no `--slots` yet |
| D-E9 | The platform line (R-SE8) is printed only for the first build attempt. Each attempt has its own temp dir, and a failed attempt deletes it. The passed attempt is installed with no second build | One temp dir for all | A failed attempt must not leave a half output |

## 7. Out of scope

| Rules | Reason |
| --- | --- |
| R-T7, R-T22 to R-T25 | Slice 048: `tool ls`, `update`, `rebuild`, `rm`, `--git` |
| R-B* (except as used), R-X | Slice 049: `tln x` |
| R-PT | Slice 056: `[tools]` in `talon.toml` |
| R-NI9 (`--allow-unchecked`), `--resolve`, `--git` | Later slices: refused as in 046 |
| `--slots` for the tries | D-E8 |
| GC protection of the packages of an installed tool | Slice 046b |
| A real `tty!` prompt with the real terminal in L2 | L3 has a pseudo terminal (step 1) |
| The size of the unpacked pin in the prompt ("228 MB unpacked" of the design text) | Gap G2 |

## 8. Questions (TW17) and design gaps

| # | Question or gap | What the reference does |
| --- | --- | --- |
| Q-A | A header with no `roc:` pin: the evidence pass works with no pin, but the prompt needs the pin text. What should happen? | D3 of 046 stays: exit 2 `no_pin`, with the same calls as before. Untested here |
| Q-B | A normal build with the pin installed or downloaded records no fact. So the evidence of R-T13 comes only from option 2 tries (and from the project builds of slice 032, if the key is the same). Should the tool build record a build fact? | No record (not in the design). L3 step 2 gets its evidence from the tries of step 1 |
| G2 | The design prompt shows "228 MB unpacked". The release list gives the size of the archive only | The prompt shows `(<size>)` of the archive |
| G3 | R-T20 says "the prompt again with options 1 and 3". It does not say if a person who answered 2 can be asked a third time | One more prompt, then exit 13 on option 3. No loop: option 2 is not offered again (`allowed`) |

## 9. Compiler and tool limits met

| Limit | What we did |
| --- | --- |
| `app` and `with` are reserved words | The test module uses `tool_app` |
| `roc test` crashes with an `Err` record that has a `Bool` field | The tests compare texts |
| A list of rows with `(Bool, Bool)` and `(Str, ...)` does not type-check | A `yn` helper turns a Bool into a text |
| `==` on a Try does not compile | The tests use `match` |
| An effectful function does not work in `map_try` | `ToolTry` uses `for` with `var` |
| `roc fmt` rewrites the `roc:` pin of `.roc` apps outside `given/` | The L2 app sources are `.src` files |
| `roc fmt` needs a block form for a long tuple element in a row | The test file was formatted with `roc fmt` |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Where | `cli/lib/ToolCompiler.roc`, `ToolCompilerFlow.roc`, `ToolTry.roc` (stubs). `main.roc` is done. `ToolInstall.roc` has the 3 type edits. `ToolInstall.read` must accept `--roc installed` (`Ok("installed") => Installed`) |
| `ToolFlow.roc` | Replace `compiler_id!` and `built!` by `compile!`: it builds `ToolCompiler.Run` (the `Facts` record gets a `probe_timeout : U64` from `Probe.settings`), calls `ToolCompilerFlow.choose!` with the callback `attempt!` (random dir, layout, header lines with the platform line only when `req.first`, toolchains, program, touch, child_env, make_dirs, `probes!`, classify, errors, delete of the temp dir when the attempt does not pass) and `build!` (use `chosen.passed`, else one `attempt!`, then the lock and the install, then delete of the temp dir). The calls: the doc table of `ToolCompilerFlow` |
| Order of the calls | The tables in the doc comments of `ToolCompilerFlow` and `ToolTry`. The L2 `calls.log` files are the exact order |
| Reuse | `Launch.toolchains!`, `Launch.program!`, `Launch.touch!`, `Launch.child_env!`, `Facts.load!`, `Facts.save!`, `Facts.of_probe`, `BuildSkip.digest`, `BuildSkip.decide`, `BuildSkip.row`, `Consent.required_want`, `Consent.auto_install`, `Mode.from_env`, `Mode.with_tty`, `Prompt.ask!`, `RocInstall.offer!`, `RocInstall.install_offer!`, `RocInstall.fetch_optional!`, `Probe.classify`, `Probe.errors`, `Probe.args`, `Probe.weight`, `Pin.order`, `Compiler.kind`, `Toolchain.size_text` |
| Size | Keep `ToolFlow.roc` and `ToolInstall.roc` at or under 490 lines (section 2) |
| Tests | Do not edit tests (TW18). A wrong row: write it in the report |

## 11. Red run, revert check

Red run with the stubs in `cli/lib` (log: `research/slice-047-revert/red-all.log`):

| Step | Result |
| --- | --- |
| `roc check cli/main.roc`, `roc build` of the test apps, `roc fmt --check` of the new and changed Roc files | pass, 0 warnings |
| `scripts/test.sh` | check pass, fmt pass, l0 FAIL, l2 FAIL, l3 FAIL, selftest pass, l1 pass |
| L0 | `l0-1`: 75 tests, 74 passed, 1 failed (`ToolTest` expect 1, the `--roc installed` row). `l0-5`: 63 tests, 55 passed, 8 failed (the 8 `expect`s of `ToolCompilerTest`, all `todo: slice 047`). The other 6 drivers pass |
| L2 | 120 passed, 3 failed (`tool/ti2-refusals`: 3 lines of `calls.log`, `tool/ti3-compiler`, `tool/ti4-nothing`) |
| L3 | 69 passed, 1 failed (`tools/ti2-tool-compiler`), 1 skipped |

Green run with the reference: `l0-1` 75 passed, `l0-5` 63 passed, L2 `tool/` 4 passed, L3 `tools/` 2 passed (3 runs in a row for the new case).

Revert check (`research/slice-047-revert/mutants.py`, 12 mutations of the reference, the result in `mutants.log`). The reference was put back after each run (`cmp` against `research/slice-047-revert/reference/lib/`: equal), then `restore.sh` put the stubs back.

| # | Mutation | Caught by |
| --- | --- | --- |
| 1 | the digest ignores the hashes of the header | L0 `ToolCompilerTest` 2 |
| 2 | the evidence takes the last release in the order | L0 `ToolCompilerTest` 3 |
| 3 | a fail row does not block a pass of the same digest | L0 `ToolCompilerTest` 3 |
| 4 | `--roc installed` does not win over `--yes` | L0 `ToolCompilerTest` 5 |
| 5 | the checks run one by one (a `probes!` call each) | L2 `ti3-compiler`, L3 `ti2-tool-compiler` |
| 6 | no `db_write` after the checks | L2 `ti3-compiler` |
| 7 | a failed build stops option 2 | L2 `ti3-compiler` run 2 |
| 8 | option 2 is allowed with no installed release | L0 `ToolCompilerTest` 7 |
| 9 | the prompt after option 2 offers option 2 again | L2 `ti3-compiler` run 4 |
| 10 | `tty!` is called at once | L2 `ti3-compiler`, `ti4-nothing` |
| 11 | a flag removes the evidence pass | L2 `ti3-compiler` run 6 |
| 12 | the build row of a try is not written | L2 `ti3-compiler` run 2 |

12 mutations, 12 caught, 0 not caught. No full sweep was run.

## Review (manager, 2026-10-25)

| Item | Decision |
| --- | --- |
| Slice | Accepted with no change, no split |
| D-E1 to D-E5, the other decisions, the TW24 texts | Accepted |
| Module plan | Accepted: cut `ToolBuild.roc` (steps 10 to 13) if `ToolFlow.roc` goes over 490 lines |
| Q-A (no pin) | Keep D3 of 046 (exit 2). Design gap, the manager records it |
| Q-B (no fact for a normal build) | No fact. Design gap, the manager records it |
| G2 (archive size in the prompt) | Accepted. Design gap |
| G3 (ask once more, then exit 13) | Accepted. Design gap |
| Private reference | Deleted (`research/slice-047-revert/reference/` and `reference.sh`). `restore.sh` and `stubs/` stay |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `ToolTry.installed!` calls `Launch.toolchains!` once (one `list_dirs`) before the programs, as the L2 `calls.log` shows. With no id it makes no call and gives `Failed([])` | Use `ids` for `Launch.program!` (no `list_dirs`: the `calls.log` has it) |
| C2 | The `build` hook gets `first` and `ToolFlow.attempt!` prints the platform line only then. The line `building ...` is printed for each attempt (`header_lines` with `pf: Err(None)` for a later attempt) | A second function for the line |
| C3 (changed in review 2) | `Chosen` has a `first` field. It is false after a failed option 2 that built the app (a `Build` try) and a download, so the platform line prints once for each command. `ToolBuild.finish!` passes it to `attempt!` | A flag in `ToolFlow` |
| C4 | The id of the result for a download or a present pin is the pin text (as before in 046), not the id of the offer | The id of `RocInstall.Offer` |
| C5 | The second prompt gets its `Offer` from the first one (no new `offer!`), or from a new `offer!` when no prompt came before (`--roc installed` with a person and `NeedsTty`) | Ask `offer!` again every time |
| C6 (changed in review 2) | `ToolBuild.roc` is cut (steps 7b and 10 to 13: the types `Facts`, `Bundle`, `Done`, `attempt!`, `finish!`, `entry_verdict!`, `pf_hash`, the install under the lock). `main.roc` exposes it. No behavior change | Keep 488 lines in `ToolFlow.roc` |

## Verify results

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | exit 0: check 1.6 s, fmt 0.2, l0 6.6 (`l0-1` 75, `l0-2` 51, `l0-3` 75, `l0-4` 60, `l0-5` 63, `l0-6` 53, `l0-7` 40, `l0-8` 60 passed), l2 7.9 (123 passed, 0 failed), l3 9.9 (70 passed, 0 failed, 1 skipped), selftest 3.0, l1 36.0 |
| `roc check`, `roc build` of the test apps, `roc fmt --check` | 0 errors, 0 warnings |
| `crash "todo` in `cli/`, `packages/` | none |
| Size | `ToolCompiler.roc` 255, `ToolCompilerFlow.roc` 161, `ToolTry.roc` 110, `ToolFlow.roc` 488, `ToolInstall.roc` 441 lines (each under 490) |
| Revert check | `research/slice-047-revert/agent-mutate.py`, results in `research/slice-047-revert/agent-results.md`: 10 mutations, 10 caught, 0 not caught |
| Code after the runs | same as `research/slice-047-revert/code-final/` (`sha256sum -c research/slice-047-revert/code-final.sha256` from the repo root: all OK) |

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | the digest ignores the hashes of the header | L0 ToolCompilerTest 2 (l0-5) |
| A2 | the evidence key has the target `any` | L0 ToolCompilerTest 2 and 3 (l0-5) |
| A3 | D-E3: `--yes` wins over `--roc installed` | L0 ToolCompilerTest 5 (l0-5) |
| A4 | D-E3: a flag removes the evidence pass | L2 ti3-compiler (runs 3 and 6) |
| A5 | the checks run one by one (a `probes!` call each) | L2 ti3-compiler (`probes 4` lines) |
| A6 | the builds go on after the first pass (no `break`) | L2 ti3-compiler run 2 (D is built) |
| A7 | the prompt after option 2 offers option 2 again | L2 ti3-compiler run 4 |
| A8 | no person after option 2: the cancel text, not the list | L2 ti3-compiler run 3, ti4-nothing run 2 |
| A9 | the build row of a failed try is not written | L2 ti3-compiler runs 2, 3 (`db_write` calls) |
| A10 | `tty!` is called at the start (not lazy) | L2 ti3-compiler, ti4-nothing (a `tty` line in `calls.log`) |

## Review 2 (manager, 2026-10-25)

| Item | Decision | Test |
| --- | --- | --- |
| C3 | The platform line prints once for each command (R-SE8). After a failed option 2 and a download (option 1 of the second prompt) the code printed it a second time | L2 `ti3-compiler` run 7 (`tool install acme/redo`, answers `2`, `1`). Red now: only `expect/stderr` differs, by one `platform ...` line (before `building acme/redo 1.0.0 with nightly-2026-10-11-1a2b3c4`). `stdout`, `exit`, `calls.log`, `tree.diff` are the same. The code agent fixes it (for example a `first` field in `Chosen`, or a flag that the flow keeps) and does not edit tests |
| C5 | The second prompt reuses the offer of the first one | No new row. `ti3-compiler` run 4 (answers `2`, `3`) already has one `offer!` (`list_dirs`, `db_query pinned=10`) for two prompts. Hand mutation: the second prompt makes a new `offer!`: caught by run 4 (the extra calls). Code restored: `sha256sum -c research/slice-047-revert/code-final.sha256` is OK |
| C1, C2, C4, C6 | Accepted | none |

Run order: run 7 is before the download run (now run 8), because the download installs the pin and a run after it would not reach the prompt. The old run 7 (`acme/dl`) is run 8. Its output is the same (TW21: `research/slice-047-revert/expect-before2/` has the old expected files of the 4 `tool/` cases; the diff of `ti3-compiler` is the lines of the new run and the new `fx/probes` row, and `ti1-install`, `ti2-refusals`, `ti4-nothing` pass unchanged).

Review 2 fix (C3, ToolBuild cut): `Chosen.first`, `ToolBuild.roc` (217 lines), `ToolFlow.roc` 296, `ToolCompilerFlow.roc` 171 lines. Full `scripts/test.sh` exit 0 (l2 123 passed, run 7 of `ti3-compiler` green; l3 70 passed). Hand mutation A11 (`first` always true: second `platform` line): caught by L2 `ti3-compiler` run 7, code restored. `code-final/` and `code-final.sha256` are new (`sha256sum -c` from the repo root: all OK).

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-047-revert/code-final.sha256` | OK, 7 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.5, fmt 0.2, l0 7.0, l2 7.2, l3 10.0, selftest 3.1, l1 38.1 s |
| Review 2 | C3 (platform line once per command): red run 7 first, then the fix; mutation caught. `ToolBuild.roc` cut out of `ToolFlow.roc` (now 296 lines), no behavior change |
| Gap tests | C5 is covered by run 4 (hand mutation caught) |
