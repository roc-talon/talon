# 079 The compiler order of the tool flows (try installed first, then the pin)

Phase: P1. Status: done

Slice 079 follows slice 072b. The decisions are in `DESIGN-GAPS-2026-10-26.md` (Q-A1, Q-A2, Q-A3, Q-B1). The design is R-T30 (`DESIGN-CLI.md` 6.4), R-T14 to R-T16, R-T20, R-NI8, R-NI17, R-X1, R-FE4 and R-SO23.

The order of R-T30 for `tool install`, `x`, a project tool build (R-PT6), `tool --git` and `tool update` (the flows share `ToolCompilerFlow.choose!`, except `tool update`, see section 4):

| Step | What | Download | Default |
| --- | --- | --- | --- |
| 0 | The unpack of the app bundle comes first and follows R-FE4 (with nothing selected and nothing installed: the latest in the channel, R-SO23) | maybe | yes, as R-SO15 |
| T29 | The app header has no `roc:` pin: exit 2, before any try and any question (Q-A2) | no | no |
| 1 | The pin is installed: use it (R-T12) | no | no |
| 2 | An installed release has a recorded pass for the closure of the tool: use it (R-T13) | no | no |
| 3 | Try the installed releases, with no prompt: the selected compiler first when it is installed, then the others newer before older (R-T17 to R-T19). Each pass and fail is a fact (R-T21). The first pass builds the tool. `--roc pinned` skips this step | no | no |
| 4 | Only when no installed release works: download the pin under the consent rules R-DL1 to R-DL6. The prompt R-NI8 has the options 1 and 3 and the list of the releases that failed (R-T20). `--roc installed` ends after step 3 | yes | only when no compiler is selected and no default is set now (R-SO15) |

Before 079, the try was option 2 of the prompt, and a compiler that is selected did not change the order. The flow with no compiler at all stopped with exit 18 in `ToolFlow.package_text!` (`none: Stop`).

## 1. Scope

| Part | In 079 |
| --- | --- |
| Pure decisions: `try_order`, `sets_default`, `after_try`, `prompt`, `allowed` | yes (L0) |
| `ToolCompilerFlow.choose!`: the try before the prompt, the selected compiler first, the default after the download | yes (L2) |
| `ToolFlow.package_text!`: `none: Download({ scope: Outside, ... })` | yes (L2 `tool/tc2-nothing`, the cases that had exit 18 in this step) |
| `tool update`, `tool rebuild`: the first compiler that the command downloads becomes the default when none is selected (R-NI17) | yes (L2 `tu1-update`, `tr1-rebuild`, `tr2-selected`) |
| `x` and the project tool build | they call `ToolFlow.choose_for!`, the same code. No new case: the old cases of `x` and `ptool` pass again with the changes below |
| Evidence step 2 for `tool update` (R-T30, Q1 of the review: an installed release with a recorded pass; the plan reads facts and builds nothing) | yes (L2 `tu3-evidence`) |
| The selected compiler of a tool command: `ROC_TOOLCHAIN`, `default-roc`, a `PATH` `roc` with a nightly or release id (Q3 of the review) | the pure `selected_of` (L0). The wiring is for the code agent |

## 2. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-T30 | The order above | L0 `try_order`, `after_try`; L2 `tc1-order`, `tc2-nothing`, `ti3-compiler`, `ti2-refusals` |
| R-T29, Q-A2 | The missing pin is exit 2 before the try | L2 `ti2-refusals` run 5 (no probe, no prompt) |
| R-T14, R-T15 | The prompt shows only after a failed try (R-T14), or at once when nothing is installed (R-T15) | L0 `prompt`; L2 `ti3-compiler` runs 4, 5, 7, 8; `ti4-nothing` |
| R-T16 | No person: the flags decide. `--roc pinned` skips the try. `--roc installed` ends after it | L0 `decide`; L2 `ti3-compiler` run 3, `tc1-order` run 3, `ti4-nothing` runs 2, 3 |
| R-T20 | After a failed try the prompt (or the failure with no person) lists the first error line of each release | L0 `prompt`, `after_try`; L2 `ti3-compiler` runs 3, 4, 7; `ti2-refusals`; `pt2-install`; `rn3-tools` |
| R-T21 | Each pass and fail of the try is a fact (`compat.db`) | L2 `ti3-compiler`, `tc1-order` (the `db_write` lines and `compat.tsv`) |
| R-T6, R-DL1 | The download of the pin is a required download | L2 `ti3-compiler`, `tc2-nothing`, `ti2-refusals` run 7 |
| R-NI8 | Options 1 and 3. Option 2 is not allowed | L0 `prompt`, `allowed`; L2 `ti4-nothing` (the answer `2` is asked again) |
| R-NI17 | `tool update` and `tool rebuild`: the first compiler that is downloaded becomes the default when none is selected | L2 `tu1-update` run 3, `tr1-rebuild` run 3 (default set), `tr2-selected` (selected: no write) |
| R-SO14, R-SO15, R-SO23 | With no compiler selected the download of step 4 becomes the default, and the prompt says it. With a selected compiler it does not | L0 `sets_default`, `prompt`; L2 `ti2-refusals` run 7, `ti3-compiler` (selected), `ti4-nothing` (not selected), `tc2-nothing` |
| R-FE4 | The unpack of the bundle uses R-SO14 when nothing is installed: the latest in the channel (a tool has no fact yet), as default | L2 `tc2-nothing` |
| R-X1 | `x` and the project tool build share the choice | the shared code; L2 `pt2-install`, `rn3-tools` |
| R-DL7 (as used) | A project tool build keeps its own consent text (`--allow-downloads` for `install`, `--yes` for `run`) after a try | L2 `pt2-install` runs 12, 14, `rn3-tools` run 5 |

## 3. Decisions (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `ToolCompiler.prompt` has no `installed` count and no option 2. `allowed` allows 1 and 3. `decide` is unchanged: its `TryInstalled` means `--roc installed`, and the flow calls it after the try | A new `decide`: every row of `decide` stays true |
| D2 | `ToolCompiler.Run` has `selected : Str` (`facts.selected` of `ToolBuild.Facts`: `default-roc`, `""` for none) | A new field of `ToolBuild.Facts` for the fallback: the fallback is built in `ToolFlow.package_text!` from `args` and `facts.env` (`Download({ scope: Outside, downloads, probe: Skip })`) |
| D3 | The default of step 4 is decided by `sets_default`: `selected` is `""` and `config.toml` has no default now. The flow reads `config.toml` again (one `read_files`) before the prompt and before the download, because the unpack of the bundle can set the default | Only `selected`: the unpack would be the first download, and step 4 would write the default again |
| D4 | After a failed try, a `Stop(fail)` of `decide` (no person, no flag, `TALON_AUTO_INSTALL=no`) is `after_try`: the message is `no installed compiler release built <name> <version> (<list>), and <the text of the stop>`, with the kind of the stop. The text of the stop keeps the flags of the command | `all_failed` for every stop: it names `--roc pinned`, a flag that `install` and `run` do not take |
| D5 | `ToolsPlan.compiler_stop` and `RunTools.stop` rewrite the end of the message (they must not check the start): the flags of `install` (`--allow-downloads`) and of `run` (`--yes`) stay | Two texts for each stop |
| D6 | The cases whose app must reach the prompt or the stop get a `fx/units` row that fails the check with each installed compiler (`pt2-install`, `rn3-tools`, `ti2-refusals`, `ti3-compiler`: `cancel`, `dl`). `ti3-compiler` has `default-roc` = the newest compiler (A): the order of the try does not change, and its downloads set no default. `tc1-order` has a selected compiler that is not the newest | New cases for each: too many fixtures |
| D7 | `fx/hooks` of `ti2-refusals`: the check of the try is one more `probes` call, so the numbers 3 and 4 are 4 and 5 | |

## 4. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `ToolCompiler.try_order`, `sets_default`, `after_try`, `prompt`, `allowed` | Bodies. The docs are the rules. `decide`, `trying_line`, `built_line`, `all_failed`, `declined` stay |
| 2 | `ToolCompilerFlow.choose!` | Rewrite as the table in its doc (steps 1 to 5). The helpers `asked!`, `downloaded!`, `tried!`, `again!` of 047 are replaced. `first` of `Chosen` is false after an attempt of the try that built the app (R-SE8: the `platform` line is printed once) |
| 3 | `ToolFlow.package_text!` | `none` is `Download({ scope: Outside, downloads, probe: Skip })`. `downloads`: `auto` from `Consent.auto_install(facts.env)`, `allow: Err(NoFlag)`, `yes`, `mode`, `quiet`, `offline`, `env` from `args` and `facts.env` (as `PathFlow` of 072c) |
| 4 | `ToolUpdateFlow.consent!` (`Download` branch and `asked!`) | After the downloads: when `ToolCompiler.sets_default({ selected: base.selected, default_now })` (one `RocInstall.read_config!`), `RocInstall.first_default!` with the first id that was downloaded. The prompt text `ToolUpdate.prompt` is unchanged |
| 5 | `ToolsPlan.compiler_stop`, `RunTools.stop` | Match the end of the message (`ends_with`), not the start, and keep the start (D5) |
| 6 | `ToolInstall.consent_stop` | No change (proposal P4) |
| 7 | `ToolFlow` and the callers of `ToolBuild.Facts` (`selected`) | `selected` is `ToolCompiler.selected_of({ env: <ROC_TOOLCHAIN>, default: <default-roc>, path: <the id of the roc on PATH, as `OnPath.file!` gives it> })` in place of the `default-roc` alone. A selected compiler that is not an installed release is never tried (`try_order`) and sets no default (`sets_default`) |
| 8 | `ToolUpdateFlow.run!` (kind `Update` only) | After `plan!` and before `consent!`: one `Launch.toolchains!`, and when a job has a pin that is not installed, one `Facts.load!` (one `db_query`) with `ToolCompiler.evidence_keys` of the installed `candidates`. A job with `ToolCompiler.evidence` `Ok(id)` is built with `id` (the line `built_line` on stderr, no download for its pin). `consent!` then counts the pins that stay (`ToolUpdate.downloads`). `rebuild` has no evidence step (R-T7). The calls: `list_dirs`, `db_query`, and `consent!`'s own `list_dirs` (the calls of `tu1-update`, `tu2-updatestops`, `tu3-evidence` fix them) |

The consent text of `install --frozen` and of `run` after a try: `ToolsPlan.compiler_stop` and `RunTools.stop` must match the end of the message (`ends_with`), keep the start, and rewrite only the flags (D5). Without this change `pt2-install` and `rn3-tools` fail.

## 5. Public signatures

| Name | Signature | State |
| --- | --- | --- |
| `ToolCompiler.Run` | new field `selected : Str` | done |
| `ToolCompiler.try_order` | `{ ids : List(Str), selected : Str, roc : [Auto, Pinned, Installed] } -> List(Str)` | stub |
| `ToolCompiler.sets_default` | `{ selected : Str, default_now : Str } -> Bool` | stub |
| `ToolCompiler.after_try` | `{ fail : Fail, name : Str, version : Str, pin : Str, tried : List(Tried) } -> Fail` | stub |
| `ToolCompiler.prompt` | `{ name, version, pin, size, tried, becomes_default : Bool } -> Prompt` | stub (the old `installed` field is gone) |
| `ToolCompiler.allowed` | `{ answer : Answer } -> Bool` | stub |
| `ToolCompiler.selected_of` | `{ env : Str, default : Str, path : Try(Str, [NoCompiler]) } -> Str` | stub |
| `ToolFlow.choose!` | passes `selected: facts.selected` | done |

## 6. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/ToolCompilerTest.roc` (driver `l0-5.roc`), `try_order` | 12 rows: no selected; the selected first (middle, newest, oldest); not installed; `Pinned` gives `[]`; `Installed` as `Auto`; no release; the other tag form of the selected nightly (R-CV1) | R-T30, R-T17, R-T16, R-CV1 |
| L0 | same, `sets_default` | 4 rows: nothing selected and no default; the unpack set the default; a compiler is selected | R-SO14, R-SO15, R-NI17 |
| L0 | same, `after_try` | 5 rows: nothing tried keeps the stop; a try gives the list and the text of the stop; one release; the kind stays | R-T16, R-T20, R-NM5 |
| L0 | same, `prompt`, `allowed`, texts | the prompt with and without `tried` and `becomes_default`, `Prompt.decide` rows, the answer lines; option 2 is not allowed | R-NI8, R-T14, R-T15, R-T20, R-NM9 |
| L0 | same, `decide`, `candidates`, evidence, probe and row functions | the old rows, unchanged | R-T13 to R-T21 |
| L2 | `tool/tc1-order` (new, 3 runs) | `default-roc` is C (not the newest): the checks go C, A, B, D (selected first); the selected passes and builds. `three`: C, A fail, B passes, D fails: one build with B. `--roc pinned`: no try, the pin is downloaded, no default write | R-T30, R-T17, R-T19, R-T21, R-T16, R-SO15 |
| L2 | `tool/tc2-nothing` (new, 1 run) | No compiler, no default, no `roc` on PATH: the unpack downloads the latest (not the pin) and sets the default; the try of that compiler fails; the pin is downloaded (`TALON_AUTO_INSTALL=yes`) and builds; `config.toml` is read, not written again | R-T30, R-FE4, R-SO14, R-SO15, R-SO23, R-T6 |
| L2 | `tool/tu3-evidence` (new, 1 run) | `tool update foo` with a new pin that is not installed, no person: an installed compiler has a recorded pass for the closure, so no download and no stop; `built with ...` | R-T30, R-T13, R-NI17, R-T25 |
| L2 | `tool/tu1-update`, `tool/tu2-updatestops` (calls only) | the `db_query` and the second `list_dirs` of the evidence step | R-T30, R-NI17 |
| L2 | `tool/tr2-selected` (new, 1 run) | `tool rebuild g --yes` with a selected compiler: the recorded compiler is downloaded, no write of `config.toml` | R-NI17, R-SO15 |
| L2 | `tool/ti3-compiler` (changed, 8 runs) | the try runs before the prompt (the line `trying 4 installed compiler releases`), no option 2, no answer `2`; the apps `cancel` and `dl` fail the check, so the prompt shows; `default-roc` = A | R-T30, R-T14, R-T16, R-T20, R-NI8 |
| L2 | `tool/ti4-nothing` (changed) | nothing installed: nothing is tried (R-T15); the question has `It becomes the default compiler.` and one `config.toml` read | R-T15, R-NI8, R-T30, R-SO15 |
| L2 | `tool/ti2-refusals` (changed) | run 5: R-T29 before the try. Run 6: the try, then the stop with the list. Run 7: the downloaded pin becomes the default, so later unbundles use it | R-T29, R-T30, R-T20, R-SO15 |
| L2 | `ptool/pt2-install` runs 12, 14; `run/rn3-tools` run 5 (changed) | the try, then the stop with the flags of the command | R-T30, R-DL7, R-T20 |
| L2 | `tool/tr1-rebuild` run 3, `tool/tu1-update` run 3 (changed) | the first downloaded compiler is the default (one write of `config.toml`) | R-NI17, R-SO15 |
| L3 | `tools/ti2-tool-compiler` (changed, 6 runs, real Fx, a pseudo terminal) | run 1: with a person, the try runs with no prompt and the older compiler builds. Run 4: no person, no flag: the try first, then the stop with the list and the flags. Run 5 (new): a person, the try fails, the prompt with the list, `It becomes the default compiler.` and the options 1 and 3, the typed answer `3`: exit 13. Run 6 (new): the same with `--roc installed` (Q4). `given/answers` is `3` twice | R-T30, R-T14, R-T16, R-T20, R-NI8, R-SO15 |

Changes of expected files that follow the design (TW21): L2 `ti3-compiler`, `ti4-nothing`, `ti2-refusals`, `pt2-install`, `rn3-tools`, `tr1-rebuild`, `tu1-update`, and L3 `tools/ti2-tool-compiler`. Each diff was read. The old stdout and exit codes are the same in the 7 L2 cases (the fixtures keep the intent). The L3 scenario has a new run 5 and a new text for runs 1 and 4. Stderr and the `Fx` calls differ by the try, the default and the stop text. Each old case is saved in `research/slice-079-revert/before/`.

## 7. Output (proposed, R-OUT2, TW24)

| Item | Text |
| --- | --- |
| P1 Prompt, no compiler selected | After the first line: `It becomes the default compiler.` (the design says the prompt adds this line). The answer line of option 1 ends with `, the default compiler` |
| P2 The try starts | `trying <n> installed compiler release(s)` on stderr, in every mode (before 079 only `--roc installed` printed it) |
| P3 Stop after a try | `no installed compiler release built <name> <version> (<id>: <stage> failed: <title>; ...), and the compiler <pin> is not installed. <flags of the command>`. The kind and the exit code (13) are those of the stop |
| P4 The text `(--roc installed tries the installed compilers.)` of `ToolInstall.consent_stop` | Unchanged. It is redundant after a try. The human decides if it goes |
| P5 `tool update` and `tool rebuild` prompt | The text of `ToolUpdate.prompt` is unchanged: no `It becomes the default compiler.` line (R-NI17 does not ask for it) |
| P6 The calls | One `read_files` of `config.toml` before the prompt (when nothing is selected) and before the download of step 4 |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| New `x` cases | `x` shares `ToolFlow.choose_for!` with the tool flows |
| The selected-first order in `tool update` | the plan builds nothing and runs no try |
| An L2 case for the `PATH` `roc` | the wiring needs the `PATH` id (section 4, row 7) |
| `tool update talon`, `tln` source build | no compiler choice of this rule |
| R-NI11, R-NI16, R-FE9 | other rows of the table, no change in this slice |

## 9. Questions (TW17), all answered (design agent, 2026-10-26)

| Id | Answer | In the tests |
| --- | --- | --- |
| Q1 | `tool update` applies R-T30 step 2: an installed release with a recorded pass for the closure is used, and the plan counts a download only when steps 1 and 2 find none. It reads facts and builds nothing | L2 `tu3-evidence`; `tu1-update`, `tu2-updatestops` have the new calls |
| Q2 | A selected local build is never tried | L0 `try_order`: 2 rows |
| Q3 | A `roc` on `PATH` with a nightly or release id counts as the selected compiler (ranks 2, 6, 7 of Resolution 13: `ROC_TOOLCHAIN`, `default-roc`, `PATH`). A `PATH` `roc` with another id is a local build and is not tried | L0 `selected_of` (8 rows), `try_order` (1 row). No L2 case (the wiring needs the `PATH` id: see section 4, row 7) |
| Q4 | `--roc installed`, a person, every release failed: the prompt of R-T20 (options 1 and 3). With no person: exit 13 | L3 `ti2-tool-compiler` run 6 (a person) and run 3 (no person) |

## 10. Gaps

| Gap | Effect |
| --- | --- |
| `x` with the new order | no new case (shared code) |
| `selected_of` in the flows | L0 only: the flows still pass `default-roc`, until the code agent does row 7 |
| `tool --git` | no case reaches the try (the existing cases of `tg*` use installed pins) |

## 11. Verify results (test agent, 2026-10-26)

Red state (stubs, new tests):

| Step | Result |
| --- | --- |
| check, fmt | pass |
| l0 | FAIL: 6 expects of `ToolCompilerTest.roc` (`prompt`, texts and `allowed`, `try_order`, `selected_of`, `sets_default`, `after_try`) crash with `todo: slice 079`. `NoRankTest.roc` `first` is slice 072c |
| l3 | FAIL: `tools/ti2-tool-compiler` (the real `tln` crashes with `todo: slice 079` in run 1). The other L3 cases pass |
| l2 | FAIL, 12 cases from this slice: `tool/tc1-order`, `ti3-compiler`, `ti4-nothing` (crash `todo: slice 079`); `tc2-nothing`, `tr1-rebuild`, `tr2-selected`, `tu1-update`, `tu2-updatestops`, `tu3-evidence` (no download of the latest, no default write, no evidence); `ti2-refusals`, `ptool/pt2-install`, `run/rn3-tools` (old flow: no try) |

Private reference (deleted after the review): check, fmt and l0 pass except the 072c row, l2 passes except the 3 cases of 072c (186 of 189), where the reference of 072c is not in this sandbox, and l3 passes (84 of 84 with the new scenario).

Revert check (hand mutations of the reference, `research/slice-079-revert/mutate.py`; every one is caught):

| # | Mutation | Test that failed |
| --- | --- | --- |
| N1 | `try_order`: the selected compiler last | L0 `try_order`; L2 `tc1-order`, `ti3-compiler`, `pt2-install`, `rn3-tools` |
| N2 | `try_order`: `--roc pinned` still tries | L0 `try_order`; L2 `tc1-order`, `ti2-refusals` |
| N3 | `sets_default`: the default now is ignored | L0 `sets_default`; L2 `tc2-nothing` |
| N4 | `ToolUpdateFlow`: no default after the downloads | L2 `tr1-rebuild`, `tr2-selected` |
| N5 | `ToolFlow.package_text!`: `none` is `Stop` | L2 `tc2-nothing` |
| N6 | `after_try` gets `tried: []` | L2 `pt2-install`, `rn3-tools`, `ti2-refusals` |
| N7 | `first` of `Chosen` is always true | L2 `ti3-compiler` |
| N8 | `allowed`: option 2 allowed | L0 `allowed`; L2 `ti4-nothing` |
| N9 | `ToolsPlan.compiler_stop` checks the start of the message | L2 `pt2-install`, `rn3-tools` |
| N12 (review) | `tool update`: the evidence step does not use the release | L2 `tu3-evidence` |
| N13 (review) | `selected_of`: `default-roc` before `ROC_TOOLCHAIN` | L0 `selected_of` |
| N14 (review) | `selected_of`: the `PATH` id is ignored | L0 `selected_of` |
| N15 (review) | `--roc installed` with a person gives `all_failed`, no prompt | L3 `ti2-tool-compiler` run 6 |

Rule coverage: `MISSING=1 scripts/rules.sh R-T R-NI R-X R-SO R-CV R-FE R-NS` lists R-NI11, R-NI16 and R-FE9 only (not in this slice).

## 12. Review (manager, 2026-10-26)

| Item | Decision |
| --- | --- |
| Q1 | `tool update` applies step 2. `tu3-evidence` added; `tu1-update`, `tu2-updatestops` have new calls |
| Q2 | A selected local build is never tried. L0 rows added |
| Q3 | A `PATH` `roc` with a nightly or release id is the selected compiler. L0 `selected_of`; the wiring is row 7 of section 4 |
| Q4 | Prompt with a person, exit 13 with no person. L3 run 6 added |
| D1 to D7, proposals P1 to P6 | Accepted (the prompt lines, the `trying` line in every mode, the after-try stop text, the left parenthetical, one config read) |
| For the code agent | Update `ToolsPlan.compiler_stop` and `RunTools.stop` (section 4, after row 8) |
| Status | `code`. The reference and `mutate.py` are deleted. Red state: l0 `ToolCompilerTest.roc` (6 expects), l2 12 cases (`tc1-order`, `tc2-nothing`, `tr2-selected`, `tu3-evidence`, `ti2`, `ti3`, `ti4`, `pt2`, `rn3`, `tr1`, `tu1`, `tu2`), l3 `tools/ti2-tool-compiler` |

## 13. Disputes and decisions (code agent, 2026-10-26)

| Id | Item | Text |
| --- | --- | --- |
| D1 (dispute, row 7) | The `PATH` `roc` as the selected compiler (section 4 row 7, Q3). Not wired | `OnPath.file!` makes the calls `path_roc` (and `read_files` of `path-roc.json`, `sha256_file`, `spawn_all`). The accepted L2 expected files have none of them in the try and the prompt: `tc1-order`, `ti3-compiler` and `ti2-refusals` try a compiler, and their `calls.log` has no `path_roc` call after the unpack. In `ti4-nothing` run 1 a `roc` with the id `nightly-2026-10-14-38a3029` is on `PATH` (`fx/path-roc`, `fx/jobs` `version`) and nothing is installed: with row 7 it would be the selected compiler, so the question would not have the line `It becomes the default compiler.`, but the expected `stderr` and `calls.log` have it (and one `read_files` of `config.toml`). So row 7 and these tests say two things. I did not edit a test. `ToolFlow.selected_for` gives `ROC_TOOLCHAIN` (rank 2) and `default-roc` (rank 6) through `ToolCompiler.selected_of`; `path` is `Err(NoCompiler)`. The pure `selected_of` is done and tested (L0). The wiring of the `PATH` id needs a design or test decision (question for the manager) |
| C1 | The read of `config.toml` in `ToolCompilerFlow` | The expected `calls.log` (`tc2-nothing`, `ti2-refusals` run 7, `ti4-nothing` run 1) show the read of `config.toml` AFTER `install_offer!` for a download (the flow then writes the default only when `sets_default`), and BEFORE the prompt for `Ask`. With a selected compiler (`ti3-compiler`) there is no read. So the flow reads only when `run.selected` is empty. This differs from the text "before the download" of P6 and D3: the log is the rule |
| C2 | `tool update` and `tool rebuild`: the read after the downloads | `consent!` reads `config.toml` once after the downloads, also with a selected compiler (`tr2-selected`: read, no write), and only when a compiler was downloaded (`defaulted!`). The id that becomes the default is the first one that was downloaded (`Installed` of `fetch_optional!`, or the first `Download` offer) |
| C3 | The evidence step of `tool update` | `ToolUpdateFlow.evidenced!`: one `Launch.toolchains!` and, when a job has a pin that is not installed (`ToolUpdate.downloads`), one `Facts.load!` with the keys of all those jobs. `rebuild` and a run with no job make no call |


## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Revert check | done in the test step (all caught); not run again |
| Code agent decisions | accepted: the `config.toml` read follows the accepted `calls.log` order |
| Dispute D1 (PATH `roc`) | accepted: the test is wrong under the Q3 decision. `ToolFlow.selected_for` passes `path: Err(NoCompiler)`. The wiring of the `PATH` id and the fix of `ti4-nothing` run 1 (no "It becomes the default compiler." line when a `PATH` `roc` with a nightly id is selected) go to slice 079b. |
