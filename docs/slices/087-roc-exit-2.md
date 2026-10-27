# 087 A `roc` exit code 2 with warnings only

Phase: P1. Status: tests (red) for section 9 written (test agent, 2026-10-27), see section 10. Review done (10.6: R1 fix in this slice, R2 a `+<id>` selector is skipped, 10.3 approved). Next: code. Output text of R-RUN18, R-RUN19, the names `ok-exit` and `ok_exit`: approved (human review, 2026-10-27).

## 1. Scope

roc exits with 2 when a command did its work with warnings and no errors. `roc build` still writes the program. Seen on nightly 2026-10-26: a platform module `R2.Range` shadows a builtin, a warning only, and `roc build` exits 2.

The report: the probe ladder counts this exit 2 as a pass, and `tln run` counts it as a failure. So `tln run build` fails when the ladder said that the tuple builds.

This slice checks (1) what the design says for each place that runs `roc check` or `roc build`, (2) what the code does, and (3) gives tests for the rules that the design states, or a question.

## 2. What the design says

| Place | Rule | Text (short) | Exit 2 with warnings only |
| --- | --- | --- | --- |
| Result classes of a probe | R-RC1 (`DESIGN-RESOLUTION.md:278`) | pass: "`No errors found`, or `0 errors and N warnings`" | Pass (by the text, the exit code is not named) |
| Probe rule | R-P2 (`DESIGN-RESOLUTION.md:288`) | "Warnings do not fail a probe." | Pass |
| Ladder steps 1 to 3 | R-LD1 to R-LD5 (`DESIGN-RESOLUTION.md:160-167`) | A probe "classifies the result" | Pass (R-RC1) |
| Baseline check | R-BL1 to R-BL6 (`DESIGN-RESOLUTION.md:197-220`), R-P6 | Only new errors count | Pass |
| Smoke build | R-SM1, R-SM4 (`DESIGN-RESOLUTION.md:260`) | Not implemented (P2). A probe class. | Pass |
| Tool try, tool build, `tln x`, project tool | R-T18 to R-T21 (`DESIGN-CLI.md:1103-1106`), R-X1, R-PT6 | "On a fail, go to the next release." The try records facts (R-T21), so the classes of R-RC1 to R-RC4 apply. | Pass |
| `tln run` steps | R-RUN5 (`DESIGN-CLI.md:356`), R-RUN7 (`:358`) | "The next step starts only when the step before it exits with 0." Exit code: "the exit code of the first step that fails". | Failure, exit 2 |
| A `roc` step, a `.roc` script | R-RUN3 (`DESIGN-CLI.md:354`), R-RUN6 (`:357`) | The step is a proxy call. | As the proxy |
| The `roc` proxy | R-PX2 (`DESIGN-CLI.md:956`), R-PX3 (`:957`), R-E1 (`:673`), Design R-HF6 (`DESIGN.md:489`) | "The exit code passes through." The proxy passes each roc command "with no change". | Exit 2, passed through |
| `tln build` | R-RUN17 (`DESIGN-CLI.md:368`) | There is no `tln build` command. | - |

Result: the design states each place, and the two groups differ on purpose: a probe answers "does this tuple work" (Talon's question), and `tln run` and the proxy give the answer of the child (R-E1). The design does not say whether the combination (the case of section 1) is wanted, and it has no way for a `tln run` step to accept exit 2. That is the TW17 question of section 5.

## 3. What the code does

| Place | Code | Exit 2 with warnings only | Matches the design |
| --- | --- | --- | --- |
| Class of a probe | `cli/lib/Probe.roc:23` (doc: "Exit code 2 with `0 errors` is a pass: the exit code is not the class"), `:117-121` (`classify`), `:178-187` (`classify_text`, row 7 at `:182`) | Pass | Yes |
| Ladder, baseline | `cli/lib/LadderJudge.roc:33`, `:64`, `:140` (`Probe.classify`) | Pass | Yes |
| Ladder step 3 | `cli/lib/BuildFlow.roc:69` | Pass | Yes |
| Unit probes | `cli/lib/Units.roc:90`, `cli/lib/ProbeUnit.roc:75` | Pass | Yes |
| Tool try, tool build, `tln x`, source build of `tln` | `cli/lib/ToolTry.roc:84`, `cli/lib/ToolBuild.roc:228` (also used by `cli/lib/TalonUpdateFlow.roc:445`) | Pass | Yes |
| `tln run` steps | `cli/lib/RunSteps.roc:103` (a `roc` step is `Proxy.run!`), `:118-119` (`if done != 0 return Ok(done)`) | Exit 2, the script stops | Yes |
| The proxy | `cli/lib/Proxy.roc:164`, `:250-251` (the code of `exec!` is the exit code) | Exit 2 | Yes |

The claim of the report is correct: `tln run` does not read the output. It passes the exit code of the step through, as R-RUN7 and R-E1 say. The code follows the design in each place. So no test can be red for a design rule: there is no code fault.

## 4. Tests

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| L0 | `tests/unit/ProbeTest.roc:67`, row `build warnings only, exit 2`: the real output of `roc build` with warnings only (exit 2, the summary `0 errors and 1 warning found in ... while successfully building` on stdout, the warning report on stderr) is `Pass` | R-RC1, R-P2 | Green (a guard). No test had a build with warnings only: the old row `warnings only, exit 2` is a `roc check`. |

New fixture: `tests/fixtures/check/out/build-warn.{args,exit,stdout,stderr}`, made with the pinned roc (`nightly-2026-10-14-38a3029`) from `src/warn/`, in the copy dir, as the other builds. `tests/fixtures/check/make.sh` has the new line `run build-warn warn copy build main.roc --output="$OUT"`. Only this case was made: the other outputs did not change.

Mutation check (the test catches the bad behavior): in `cli/lib/Probe.roc:182`, `if n == 0 Pass` became `if n == 0 and (code == 0 or !output.stdout.contains(" found in ")) Pass` (a build summary with exit 2 is a fail). `roc test tests/unit/l0-4.roc`: 79 passed, 1 failed, `bad_rows` = `[("build warnings only, exit 2", Pass)]`. The old check row did not catch it. Reverted: 80 passed.

No L2 case: the behavior of `tln run` for exit 2 is the question of section 5. The existing cases of R-RUN7 (`tests/commands/cases/run/rn1-scripts`, `tests/scenarios/run/rn1-flow`) already check the pass-through of a code that is not 0.

## 5. Questions (answered)

| Id | Question | Options | Recommendation |
| --- | --- | --- | --- |
| Q-087 | A `roc check`, `build` or `test` step of `tln run` exits with 2 and has warnings only. The ladder said that the tuple builds. Is the step a pass? | (a) a pass everywhere, also in the proxy; (b) a failure everywhere, also in the ladder; (c) no change: pass in the ladder, `tln run` and the proxy pass the code through; (d) (c) plus an opt-in in a step (`ok-exit = [0, 2]`, a proposal); (e) (c) for the proxy, and in `tln run` only, a `roc check|build|test` step with exit 2 is 0, with one note | (d), then (e). Full table, trade-offs and reference tools (cargo, npm, uv, make, just, tsc): `DESIGN-GAPS-2026-10-27.md`, part E. Answer: (d) plus the hint R-RUN19 (part E5). |

TW17 also names Design 9 (Open). `DESIGN.md` 9 says "Open: none." The test agent did not change a design file: the question is in the gaps file for the design agent and the human.

## 6. Output (proposed, R-OUT2)

Option (e) is rejected, so its note is not used. The notes of the decision (proposals for the human review) are in R-RUN18 and R-RUN19 (`DESIGN-CLI.md:370-371`):

| Rule | Line on stderr |
| --- | --- |
| R-RUN18 | `tln: note: step "<step>" exited with <code>; this is accepted as success by the ok-exit of the step` |
| R-RUN19 | `tln: note: roc exits with 2 when it finds warnings and no errors; to accept them in this step, use { run = "...", ok-exit = [2] } (R-RUN18)` |

## 7. Out of scope

| Point | Why |
| --- | --- |
| The smoke build (R-SM1 to R-SM7) | P2. When it comes, it uses `Probe.classify`, so the guard test covers it. |
| `roc test` in Talon's own `scripts/test.sh` | Not a Talon command. |

## 8. Verify results

| Step | Result |
| --- | --- |
| `roc fmt --check tests/unit/ProbeTest.roc` | All formatting valid |
| `roc test tests/unit/l0-4.roc` | All (80) tests passed |

## 9. New scope (after Q-087)

The design changed (`DESIGN-GAPS-2026-10-27.md`, E5). The test agent covers these rules. The guard of section 4 stays.

| Rule | File:line | What to check | Layer (proposal) |
| --- | --- | --- | --- |
| R-RUN1 | `DESIGN-CLI.md:353` | A step table with `run` only, with `run` and `ok-exit`, with `in` and `ok-exit`, is valid. A table with no `run`, or an unknown key, gives exit 19. | L0 (parse of `[scripts]`) |
| R-RUN18 | `DESIGN-CLI.md:370` | Form: `[]`, a string, a float, a value below 0 or above 255, and `ok-exit` with `run = "@<name>"` give exit 19. 0 is a pass with or without it. | L0 |
| R-RUN18, R-RUN5 | `DESIGN-CLI.md:357`, `:370` | Pass decision: (code, signal, ok-exit) gives pass or fail. A signal is a fail, also when 128 + n is in the list. A code above 255 is a fail. | L0 (pure function) |
| R-RUN18, R-RUN7 | `DESIGN-CLI.md:358`, `:370` | A script `[{ run = "roc build main.roc", ok-exit = [2] }, "next"]` with a roc that exits 2: the next step runs, `tln run` exits 0, one R-RUN18 note on stderr. With exit 1: the script stops, exit 1. | L2 (fake roc), and L3 with the `build-warn` fixture if cheap |
| R-RUN19 | `DESIGN-CLI.md:371` | `roc check`, `roc build`, `roc test` step with exit 2 and no `ok-exit`: exit 2 and the hint. `roc run`, `roc main.roc`, a `.roc` script, and a non-roc step with exit 2: no hint. A `roc build` step with exit 1: no hint. | L0 (the decision), L2 (the line) |
| R-RUN11 | `DESIGN-CLI.md:363` | `tln run --json` with no name: a step table is `{ run, in, ok_exit }`, a plain step is a string. | L2 |
| R-EA7, R-RUN18 | `DESIGN-CLI.md:370` | With `--each`, a step that passes by `ok-exit` does not stop the node, and `--keep-going` skips no node after it. | L2 (one case) |
| R-RC1 | `DESIGN-RESOLUTION.md:278` | Already covered by `tests/unit/ProbeTest.roc` (rows `warnings only, exit 2` and `build warnings only, exit 2`). Add the id to the comment of the build row if it is not there. | L0 (done) |

Out of scope: the proxy (R-PX2, R-PX3) and the probes do not change.

## 10. Tests for section 9 (test agent, 2026-10-27)

### 10.1 Public signatures (stub `crash "todo: slice 087"`)

| Module | Change | Rule |
| --- | --- | --- |
| `RunPlan.step_end` (new, `cli/lib/RunPlan.roc`) | `{ words : List(Str), text : Str, ok_exit : List(U8), ended : [Exited(I32), Signaled(I32)] } -> { pass : Bool, code : I32, note : Try(Str, [None]) }`. The doc comment has the table of the 3 fields. `code` is the code of the step (`128 + n` for `Signaled(n)`), also for a pass. `note` is the whole line with no line end. | R-RUN5, R-RUN7, R-RUN18, R-RUN19 |
| `ScriptsToml.read` (existing) | Reads the new step table forms and the new exit 19 cases (10.3). | R-RUN1, R-RUN18 |
| `RunPlan.list_text`, `RunPlan.list_data` (existing) | Show `ok-exit` (10.3). | R-RUN11 |

### 10.2 Tests

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/OkexitTest.roc` (new, driver `l0-7`), expect at `:31` | Valid forms: `{ run }` alone (a string in `data`), `{ run, ok-exit }`, `{ in, run, ok-exit }` in an array, `{ in, run }`, `ok-exit = [0]` and `[0, 2, 255]`. Checks `list_text` and `list_data`. | R-RUN1, R-RUN18, R-RUN11 |
| L0 | `OkexitTest` `:48` | Exit 19 for `ok-exit`: `[]`, `2`, `["2"]`, `[2.0]`, `[-1]`, `[256]`, `[2, 300]`, `[true]`, `[[2]]`, an item `[2]` of an array. `[0]` and `[255]` are valid. | R-RUN18 |
| L0 | `OkexitTest` `:66` | Exit 19 for `ok-exit` with `run = "@b"`, also with `in`. `{ run = "@b" }` and `{ in, run = "@b" }` stay valid. | R-RUN18, R-RUN1 |
| L0 | `OkexitTest` `:74` | Exit 19 for a table with no string `run`, an `in` that is not a string, an unknown key (`okexit`, `ok_exit`, `more`, `other`). | R-RUN1 |
| L0 | `OkexitTest` `:102` | `step_end`: 0 is a pass with no note (also with `ok-exit`), a code in the list is a pass with the note, another code fails with no note. | R-RUN5, R-RUN7, R-RUN18 |
| L0 | `OkexitTest` `:114` | `step_end`: `Signaled(n)` fails with `128 + n` also when that code is in the list (`Exited(130)` with `[130]` passes). Codes 256, 258, -1, -1073741819 (0xC0000005) fail also when their low byte is in the list. | R-RUN18, R-RUN7 |
| L0 | `OkexitTest` `:127` | `step_end`: the hint for `roc check`, `roc build`, `roc test` with 2 and no `ok-exit`, also after a `+<id>` selector (`roc +nightly-... build`; `roc +nightly-... run` gets none). No hint for `roc run`, `roc main.roc`, a `.roc` script, `tool-x build`, `tln build`, exit 1, an `ok-exit` with no 2, a signal. | R-RUN19 |
| L0 | `tests/unit/RunscriptTest.roc:60` (changed) | The messages of the form failures: "a table with run" in place of "a table with in and run", and the new table message. | R-RUN1 |
| L0 | `RunscriptTest.roc:207` (new expect, the `list_data` row moved out of the expect at `:195`) | An `in` step in `data` is `{"run":"@y","in":"d","ok_exit":null}`. | R-RUN11 |
| L0 | `tests/unit/ProbeTest.roc:66` (no change) | The guard of section 4 already names R-RC1. | R-RC1, R-P2 |
| L2 | `tests/commands/cases/run/rn5-ok-exit` (new, 15 runs, table in `rules`; runs 10 to 12 after the review: `sigt`, `sigr` a signal 2 with `ok-exit = [130]` gives exit 130 for a program step and for a `roc` step through the proxy; `pinb` `roc +<id> build` with 2 gives the hint) | `roc build` with `ok-exit = [2]` exits 2: note, the next step runs, exit 0. `roc build` and `roc check` with no `ok-exit`: exit 2 and the hint. `ok-exit = [2]` and exit 1: exit 1. `roc run`, `roc main.roc`, a `.roc` script, `tool-two`: exit 2 and no hint. An `in` step with `ok-exit = [0, 2]`. The list and `--json`. `p2`: `ok-exit = [2, 256]` gives exit 19. | R-RUN1, R-SC11, R-RUN5, R-RUN7, R-RUN11, R-RUN18, R-RUN19, R-RUN6 |
| L2 | `run/rn4-each` (run 16 added; the script `warn` added in 5 nodes; `tool-two` 2 in `fx/exec`) | `run --each warn --keep-going`: ledger passes by `ok-exit` (note), web is not skipped, exit 0. | R-RUN18, R-EA7 |
| L2 | `run/rn1-scripts` (one stderr line changed) | Run 23: the new table message. | R-RUN1 |
| L2 harness | `tests/commands/FakeJobs.roc` (`exec!`, `exec_in!`, new `child_end`), `FakeFx.roc` doc of `exec` | The fake gives `Try([Exited(I32), Signaled(I32)], [NotStarted(Str)])`. A rule code `signal:<n>` is `Signaled(n)`, `<n>` is `Exited(n)`, no rule is `Exited(0)`. Mechanical for old cases: their codes (also `143`) stay `Exited`, so no old expected file changes. | R-RUN18, R-RUN7 |

`MISSING=1 scripts/rules.sh R-RUN`: no rule is missing.

### 10.3 Output proposals (R-OUT2, for the human review)

| Place | Text |
| --- | --- |
| `list_text`, a step with `ok-exit` | `  <step text> (ok-exit = [<code>, <code>])`, for example `  in sub: tool-two sub (ok-exit = [0, 2])` |
| `list_data`, a step with `in` or `ok-exit` | `{"run":<text>,"in":<dir or null>,"ok_exit":[<codes>] or null}` (key order of R-RUN11) |
| `<step>` of the R-RUN18 note | The step text of the other messages (`Flat.text`): `roc build main.roc`, or `in sub: tool-two sub` |
| Form messages (exit 19, `scripts.<key>` or `scripts.<key>[<n>]`) | `must be a step (a string, or a table with run) or an array of steps`; `must be a string or a table with run`; `a table step needs the string run, and can have the string in and ok-exit, no other key`; `ok-exit must be an array of 1 or more integers from 0 to 255`; `ok-exit is not allowed with run = "@<name>": put it on a step of the script <name>` |

### 10.4 Red output (against the code of today)

| Run | Result |
| --- | --- |
| `roc check tests/commands/main.roc` (the L2 app) | 1 error: `FakeFx.roc:116` invalid nominal record. The fake has the new type of `exec!` and `exec_in!`, `cli/lib/Fx.roc` has the old one. So all L2 cases are red until the code agent changes the `Fx` type (10.5 note 6). Checked in a separate worktree: with only the 4 types of `Fx.roc` changed, the fake compiles and the 8 errors left are in `cli/lib` (`Proxy.roc:251`, `RunSteps.roc:143`, `XFlow.roc:205`, `XProject.roc:165`, `SetupFlow.roc:468`, `TalonRemoveFlow.roc:371`). |
| `tests/commands/run.sh run/rn5` with the L2 binary built before the fake change, case copied with the old forms | Exit codes 130, 130, 2 for `sigt`, `sigr`, `pinb`: the base of the expected `calls.log` (the same calls are expected). |
| `roc test tests/unit/l0-7.roc` | 73 tests: 64 passed, 9 failed: `OkexitTest.roc` `:31`, `:48`, `:66`, `:74` (wrong value: the read refuses `ok-exit` and `{ run }` with the old table message), `:102`, `:114`, `:127` (crash `todo: slice 087`), `RunscriptTest.roc:60` (old messages), `:207` (`in` step is still a string). Without the slice changes: 65 passed. |
| `tests/commands/run.sh run/` | `rn5-ok-exit`: each `p1` run is exit 19 with `scripts.okb[1]: a table step needs the strings in and run, and no other key`. `rn4-each`: each `w1` run that reads `workers/ledger/talon.toml` is exit 19 (`scripts.warn`). `rn1-scripts`: the old table message of run 23. `rn2-words`, `rn3-tools`: pass. |
| `roc check cli/main.roc`, `roc fmt --check` of the changed Roc files | No errors |

### 10.5 Notes for the code agent

| # | Note |
| --- | --- |
| 1 | Harness risk: `RunscriptTest.roc` builds `ScriptsToml.Step` values with `Line(Str)` and `In({ dir : Str, run : Str })` (`p_scripts`, `:108` and later). Keep these 2 tags and their payloads. Add a new tag for a table with `ok-exit` (for example `Run({ dir : Try(Str, [Here]), run : Str, ok_exit : List(U8) })`), or the old tests do not compile. `{ run = "x" }` alone can be `Line("x")`: it is a string in `data`. |
| 2 | `RunPlan.Flat` is not built by a test; a new field `ok_exit` is free. `plan_view` reads only `dir` and `words`. |
| 3 | `ok-exit` with `@<name>` is a form failure of `ScriptsToml.read` (R-RUN18: exit 19), not of `plan`. |
| 4 | `RunSteps.steps!` and `RunEachFlow` use the one judgment `step_end`. With `--keep-going`, a step that passes is no failure of the node (R-EA7). The note goes to stderr after the output of the step. |
| 5 | The hint uses the words of the step (`Flat.words`): `roc` first, then an optional `+<id>` word (R-SC11), then `check`, `build` or `test`. A `.roc` script step has the file as its first word, so it gets no hint. |
| 6 | Signals (review R1, end to end). Change `Fx.exec!` and `Fx.exec_in!` (the record at `cli/lib/Fx.roc:78`, `:84`, and the functions at `:216`, `:261`) to `=> Try([Exited(I32), Signaled(I32)], [NotStarted(Str)])`. `cli/RealFx.roc:100` and `:116` give `Signaled(signal)` in place of `128 + signal`. The callers that need a code (`Proxy.roc:251`, `XFlow.roc:205`, `XProject.roc:165`, `SetupFlow.roc:468`, `TalonRemoveFlow.roc:371`) map `Signaled(n)` to `128 + n`, so their exit codes do not change (R-RUN7, R-HF6). The `roc` step of `tln run` must give the end to `RunPlan.step_end`: `Proxy.run!` gives an `I32` today, so the step needs the end of the proxy child (L2 `rn5-ok-exit` run 11: `roc build main.roc --sig` with `ok-exit = [130]` is exit 130). The fake already has the new type (`tests/commands/FakeJobs.roc`). |

### 10.6 Point for the review

| Id | Point | Proposal |
| --- | --- | --- |
| R1 (answered: fix in this slice, end to end; 10.5 note 6) | `Fx.exec!` and `Fx.exec_in!` give `I32` and fold a signal into `128 + n` (`cli/RealFx.roc:100`, `:116`; `Proxy.run!` returns that `I32`). So the step code cannot tell `Signaled(2)` from `Exited(130)`, and R-RUN18 ("a signal is a failure, also when 128 + n is in the array") holds only in L0. To make it true end to end, the `Fx` must give the end (`[Exited(I32), Signaled(I32)]`) and the proxy must pass it on. That changes the fake (`tests/commands/FakeJobs.roc`, a code `signal:<n>` in `fx/exec`), a test file (TW18). | Accept L0 only for this slice and add the `Fx` change as a later slice (the test agent changes the fake then), or allow the code agent to change the type of `exec_in!` in the fake mechanically. No L2 case has a signal with `ok-exit` now. |
| R2 (answered: R-RUN19 now skips a `+<id>` selector, `DESIGN-CLI.md:371`; tests added) | R-RUN19 reads the words literally: `roc +<id> build main.roc` has `+<id>` as its second word, so it gets no hint. No test pins this. | Keep the literal reading, or let the design say "the first roc subcommand". |

### 10.7 Code (code agent, 2026-10-27)

Result: green, except 1 L2 case that is a test fault (10.8).

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-7.roc` | All (73) tests passed |
| `tests/commands/run.sh run/` | 4 passed, 1 failed: `run/rn1-scripts` (10.8) |
| `scripts/test.sh` (default locale) | check, fmt, l0, l1, l3, selftest: pass. l2: 237 passed, 1 failed (`run/rn1-scripts`) |
| `LC_ALL=C scripts/test.sh` | The same result |

| File | Change | Rule |
| --- | --- | --- |
| `cli/lib/ScriptsToml.roc:19` | `Step` has the new tag `Run({ dir : Try(Str, [Here]), run, ok_exit })` for a table with `ok-exit`. `{ run }` alone is `Line`, `{ in, run }` is `In` (the old tests build these). | R-RUN1, R-RUN18 |
| `cli/lib/ScriptsToml.roc:87`, `:105`, `:137`, `:165` | `ok_exit` of a step, the 3 table messages of 10.3, the table read (keys, `run`, `in`, `ok-exit`, `@<name>`), the read of the codes | R-RUN1, R-RUN18 |
| `cli/lib/RunPlan.roc:21` | `Flat` has `ok_exit` | R-RUN18 |
| `cli/lib/RunPlan.roc:84` | `step_end` | R-RUN5, R-RUN7, R-RUN18, R-RUN19 |
| `cli/lib/RunPlan.roc:131`, `:142`, `:149` | `roc_warns` (skips a `+<id>` word), the list suffix ` (ok-exit = [...])`, the `{ run, in, ok_exit }` object of `data` | R-RUN19, R-RUN11 |
| `cli/lib/RunSteps.roc:104`, `:118` | A `roc` step gives the end of the proxy child (`Proxy.ended!`). Each step goes through `step_end`; the note goes to stderr after the step; a step that does not pass stops the script with its code. `RunEachFlow` uses `steps!`, so a pass by `ok-exit` does not fail a node. | R-RUN5, R-RUN7, R-RUN18, R-EA7 |
| `cli/lib/Fx.roc:78`, `:84`, `:216`, `:261`; `cli/RealFx.roc:92`, `:108` | `exec!` and `exec_in!` give `Try([Exited(I32), Signaled(I32)], [NotStarted(Str)])` | R-RUN18, R-RUN7 |
| `cli/lib/Exit.roc:19` | `Exit.of_child`: `Signaled(n)` is `128 + n` | R-RUN7, R-HF6 |
| `cli/lib/Proxy.roc:163`, `:167`, `:205` | `ended!` (new) gives the end of the child, a failure is `Exited(<code>)`. `run!` is `Exit.of_child(ended!)`: its exit code does not change. | R-PX2, R-E1 |
| `cli/lib/XFlow.roc:206`, `cli/lib/XProject.roc:166`, `cli/lib/SetupFlow.roc:470`, `cli/lib/TalonRemoveFlow.roc:373`, `cli/fxprobe.roc:307`, `:343` | `Exit.of_child` for the code (no change of output) | R-HF6, R-E1 |

Mutations (`research/slice-087-revert/`: `mutate.py`, `results.txt`). Each was applied alone, then `roc test tests/unit/l0-7.roc` and `tests/commands/run.sh run/rn4 run/rn5`, then restored.

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | A signal passes when `128 + n` is in `ok-exit` | `OkexitTest.roc:114`, L2 `run/rn5-ok-exit` |
| m2 | No 0 to 255 check: code 258 passes by its low byte | `OkexitTest.roc:114` |
| m3 | A `roc` step gets `Exited(Proxy.run!)` (the signal is lost) | L2 `run/rn5-ok-exit` |
| m4 | The hint does not skip a `+<id>` word | `OkexitTest.roc:127`, L2 `run/rn5-ok-exit` |
| m5 | `ok-exit` with `run = "@<name>"` is allowed | `OkexitTest.roc:66` |
| m6 | `steps!` does not print the note | L2 `run/rn4-each`, `run/rn5-ok-exit` |
| m7 | The hint also for a step with an `ok-exit` that has no 2 | `OkexitTest.roc:127` |

### 10.8 Open (for the test agent)

| Id | Point |
| --- | --- |
| T1 | `tests/commands/cases/run/rn1-scripts/expect/stdout:84` (`run --json cwd:p1`) still has the `in` steps as strings (`"in sub: tool-d x"`). R-RUN11 (`DESIGN-CLI.md:363`) and `RunscriptTest.roc:207` say that a step with `in` is `{"run":...,"in":...,"ok_exit":null}`. The code follows the design and the L0 test. The expected line must change to the object form (5 steps: `all` (2), `out`, `nofile`, `noname`). The code agent does not edit tests (TW18). |
