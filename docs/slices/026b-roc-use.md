# 026b tln roc use

Phase: P1. Status: done

Part 026b of `docs/slices/026-roc-use-update.md`: the command `tln roc use <ref>` (CLI 6.6). It writes the `roc:` entry of each member after the baseline check, the candidate check and the build passed (R-H6). The base of a step (`@-N`) and the download prompts come from 026a and 025. Section 10 closes the open points of 026a (Q4, Q5) and the new Q6 to Q8. The review of 2026-10-23 (section 14) answered all of them.

## 1. Rules

| Id | Rule (short) | Where | Tested by |
| --- | --- | --- | --- |
| R-CS1 | `roc use <ref>` pins one compiler for the members of the project | `RocUse.use!`, `Manage.read_use`, `Manage.use_plan` | L0 `manage`. L2 `us1` runs 1, 2. `us2` run 1. L3 `us1` step 2 |
| R-U1 | A `git-`, `link-`, `copy-` id is no pin, also when a prefix names it. Exit 2 | `Manage.read_use`, `Manage.use_pinnable` | L0 `manage`. L2 `us1` runs 9, 10. L3 `us1` step 5 |
| R-U2 | The new compiler is installed when missing (a name, an id, a prefix of an installed id first) | `RocUse.named!` | L2 `us1` runs 5, 6. L3 `us1` step 2 |
| R-U3 | The baseline check runs on the old pin, the candidate check and the build on the new compiler. A new error stops (exit 11 or 10), nothing is written | `Ladder.use!`, `RocUse.flow!` | L2 `us1` runs 1, 14, 15. `us2` runs 1, 2. `us3` run 1. L3 `us1` step 2 |
| R-U4 | `--no-check` is a usage error | `Args.parse` (already stops it) | L0 `args`. L2 `us1` run 11. L3 `us1` step 5 |
| R-U5 | The `[toolchain] roc` range and the nightly switch refuse the id with exit 10. No `talon.toml` edit | `Pin.use_gate`, `RocUse.flow!` (times) | L0 `pin`. L2 `us1` runs 12, 13, 23, 24. L3 `us1` step 6 |
| R-U6 | A note when `ROC_TOOLCHAIN` has a higher priority than the new pin | `Manage.use_note` | L0 `manage`. L2 `us1` run 4. L3 `us1` step 4 |
| R-WS13 | In a workspace each member is checked on its own baseline. No member is written before all passed | `Ladder.use!`, `RocUse.write!` | L2 `us2` runs 1, 2 |
| R-RP1 (`roc use`) | The header is written with the span edit (comments stay), the entry is added as the last entry when there is none (R-RP3) | `RocUse.write!`, `Locked.edit` | L2 `us1` runs 1, 3. L3 `us1` step 2 |
| R-PH8 (`roc use`) | The command uses the compiler of Resolution 13 for a member with no pin | `RocUse.flow!`, `Manage.use_plan` | L2 `us1` run 3. `us2` run 1 |
| R-SL7, R-PD16 | A step `@-N` has the base that Resolution 13 selects for `main.roc` of the current dir | `RocInstall.offer!` (026a) | L2 `us3` run 1 |
| R-BL1, R-BL5 | Baseline of a member: its pin, else `ROC_TOOLCHAIN`, else the selected compiler. Errors of the baseline are notes | `Manage.use_plan`, `Ladder.use!` | L0 `manage`. L2 `us1` runs 3, 15. `us2` run 1 |
| R-DL1, R-DL3, R-DL4, R-DL5, R-NI5, R-NI6, R-EC13 | The prompts of the downloads (section 6, question Q4) | `RocUse.consent!`, `Consent.use_download` | L0 `consent`. L2 `us1` runs 5 to 8. L3 `us1` steps 1, 2 |
| R-NS1 | The range orders nightlies of one day by `published_at` (`.talon.json`, the list), not by the tag text | `Pin.admits`, `RocUse.flow!` | L0 `pin`. L2 `us1` runs 23, 24 |
| R-H1, R-H6, R-EC11, R-EC2, R-J3, R-OUT2, R-OUT4, R-CC4, R-CC7, R-CC9, R-PD9, R-PD14 | Same span edit, no new error, exit codes, `--json` envelope, install order, lock, `.last-use`, the record of the project | `RocUse`, `Ladder.use!` | L2 `us1`, `us2`. L3 `us1` |

`MISSING=1 scripts/rules.sh R-CS R-U R-WS13 R-RP1 R-PH8 R-BL R-DL R-NI` lists no id of this table.

## 2. Files

| Path | Lines (stub) | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/RocUse.roc` | 34 | test agent (stub) | New. `use!` is `crash "todo"`. The doc table has steps 1 to 11 |
| `cli/lib/Manage.roc` | 473 | test agent (stub) | 6 new functions (section 3), `crash "todo"` |
| `cli/lib/Pin.roc` | 457 | test agent (stub) | `use_gate`, `crash "todo"` |
| `cli/lib/Consent.roc` | 299 | test agent (stub) | `use_download`, `crash "todo"` |
| `cli/lib/Ladder.roc` | 534 | test agent (stub) | `UseMember`, `use!` (`crash "todo"`). `probe_member!` takes a `Pair` (old behavior) |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | 127, 98 | test agent | The dispatch of `["roc", "use"]`, the export of `RocUse` |
| `tests/unit/manage.roc` | 408 | test agent | +4 expects |
| `tests/unit/pin.roc`, `consent.roc`, `args.roc` | 345, 385, 189 | test agent | +1 expect, +1 expect, rows for `roc use` |
| `tests/commands/cases/roc/us1-use`, `us2-workspace`, `us3-step` | 28, 2, 1 runs | test agent | L2 |
| `tests/scenarios/compilers/us1-use` | 49 | test agent | L3 (fake nightly release, fake roc) |

The copies of the files before the slice are in `research/slice-026b-revert/before/` (`NEW.txt` lists the new files). The private reference is deleted (review, section 14). `research/slice-026b-revert/stubs/` has the stub files and `code-mutate.py` needs the code of the code agent in `cli/` as its base.

## 3. Public signatures

| Module | Signature | Rule |
| --- | --- | --- |
| `RocUse` | `use! : Fx, Args => I32` | R-CS1 |
| `Manage` | `read_use : Args -> Try(Str, Fail)` | R-CS1, R-U1 |
| `Manage` | `use_pinnable : Str -> Try({}, Fail)` | R-U1 |
| `Manage` | `use_plan : { id, members : List({ file, pin : Try(Str, [NoPin]) }), fallback : Try(Str, [NoCompiler]) } -> Try(List(UseRow), Fail)` | R-BL1, R-WS13, R-H1 |
| `Manage` | `UseRow : { file, baseline, previous, op : Try(Locked.Op, [Same]) }` | R-RP3 |
| `Manage` | `use_note : { toolchain, id } -> Str` | R-U6 |
| `Manage` | `use_report : { id, files } -> List(Str)` | R-OUT2 |
| `Manage` | `use_data : { id, files, probes, downloads, built, notes } -> JsonDoc` | R-J3, R-OUT4 |
| `Pin` | `use_gate : { id, req, req_text, nightly, source, times } -> Try({}, Fail)` | R-U5 |
| `Consent` | `use_download : { ids : List(Str), size : U64 } -> Prompt` | R-DL1, R-NI5 |
| `Ladder` | `UseMember : { file, kind, text, ops, baseline }` | R-U3 |
| `Ladder` | `use! : Fx, { roots, now, path_roc, held, members : List(UseMember), owners, downloads } => Try({ notes, downloads }, Fail)` | R-U3, R-WS13 |

## 4. Flow of `roc use` (the calls that the L2 and L3 cases fix)

The table in the doc comment of `cli/lib/RocUse.roc` has the 11 steps. This table is the order of the effects.

| Step | Effect | Rule |
| --- | --- | --- |
| 1 | No effect. A bad operand is printed with `Common.failed!` (exit 2) | R-CS1, R-U1, R-U4 |
| 2 | `env_all!`, `clock!`, the project, `Known.record!`, `Install.compiler!` | R-PD9, R-PD14 |
| 3 | One `read_files!` of the members and the `talon.toml` files. `ResolveBase.select!` only for the members that have no pin | R-BL1, R-SO14 |
| 4 | `list_dirs!` of the store. An operand that is not a step goes to `Nightlies.pick` over the installed ids, then the list (`RocInstall.offer!`) | R-U2, R-SL7 |
| 5 | `Manage.use_pinnable`, `Pin.use_gate`. No effect | R-U1, R-U5 |
| 6 | `Manage.use_plan`. A member with the pin already has no edit | R-H1, R-BL1 |
| 7, 8 | One prompt for the downloads (section 6), then the installs: the new compiler first | R-DL1, R-CC4 |
| 9 | `Ladder.use!`: for each member, the baseline check on its own compiler (project dir), the candidate check and the build on the new compiler (temp copy), delete of the copy | R-U3, R-BL1, R-CC9 |
| 10 | Under no lock: `read_files!`, `Guard.check_all`, `Locked.edit`, one `write_atomic!` for all changed members | R-CC7, R-H1, R-WS13 |
| 11 | The lines, the note, or the envelope | R-OUT2, R-J3, R-U6 |

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `manage.roc`: `read_use` (13 rows) | No operand, 2 or 3 operands, `git-`, `link-`, `copy-`, a full id, a prefix, `@latest`, `@-1`, a release | R-CS1, R-U1 |
| L0 | `manage.roc`: `use_pinnable` (7 rows) | A nightly (both tag forms) and a release pass. `link-`, `copy-`, `git-`, `debug-<sha>` stop | R-U1 |
| L0 | `manage.roc`: `use_plan` | Own pin, no pin with a fallback, no pin with no fallback (exit 18), the pin is the id (also in the other tag form: `Err(Same)`), different baselines in one workspace | R-BL1, R-WS13, R-H1, R-SO14, R-RP3 |
| L0 | `manage.roc`: `use_note`, `use_report`, `use_data` | The note text, the lines for a changed pin and a new entry, the line for no member (Q7), the key order of `data`, `previous` null, `build` null | R-U6, R-OUT2, R-J3, R-OUT4 |
| L0 | `pin.roc`: `use_gate` (16 rows) | Kind `NoTuple`. Two nightlies of one day: the time orders them, the tag text only with no times. Switch off from env, toml, config. Range below, at the bound, above. A release is not stopped by the switch. A semver range. The switch is checked before the range | R-U5, R-NS2, R-NS5, R-NS7 |
| L0 | `consent.roc`: `use_download` (15 rows) | One id, 2 ids, the size text, default Yes, the ways of the stop, the answer lines | R-DL1, R-NI5, R-DL3, R-DL5 |
| L0 | `args.roc` | `roc use` with `--file` and `--allow-downloads`. `--no-check` and `--probe-downloads` are errors | R-U4, R-EC2 |
| L2 | `roc/us1-use` (28 runs) | See the list below | R-CS1, R-U1 to R-U6, R-RP1, R-RP3, R-H1, R-H6, R-BL1, R-BL5, R-SO6, R-NI5, R-NI6, R-DL1, R-DL3 to R-DL5, R-EC2, R-EC11, R-EC13, R-NS2, R-NS5, R-NS7, R-J3, R-OUT4, R-CC4, R-CC7, R-CC9, R-PD9, R-PD14, R-LK3, R-R4, R-SO2, R-RC4 |
| L2 | `roc/us2-workspace` (2 runs) | 4 members: the pin O, the pin M, no pin, the new pin in the other tag form (no probe, no write). A second workspace where the second member has a new error: no write | R-CS1, R-WS13, R-WS4, R-U3, R-BL1, R-RP3, R-H1, R-H6, R-EC11 |
| L2 | `roc/us3-step` (1 run) | `@-1`: the base is the pin N, the new pin is the nightly before it, installed already | R-SL7, R-PD16, R-CS1, R-U3 |
| L3 | `compilers/us1-use` (7 steps, 9 `tln` calls) | Real binary, real `curl` and `tar`, the fake release server, the fake `roc`. Step 1: stop for 2 downloads (exit 13). 2: `--allow-downloads`, 2 installs, probes, span edit. 3: `--json`. 4: `ROC_TOOLCHAIN` note. 5: link and `--no-check` (exit 2). 6: range and switch (exit 2). 7: no temp or lock file | R-CS1, R-U1, R-U3 to R-U6, R-RP1, R-PH8, R-NI5, R-DL1, R-DL4, R-DL5, R-H1, R-J3, R-OUT4, R-CC4, R-CC9, R-H6 |

L2 runs of `us1-use`:

| # | Run | Shows |
| --- | --- | --- |
| 1 | `p1`, pin O, new N, all installed | No download. Baseline on O in the project dir, candidate and build on N in the copy. Span edit, comments stay. The project is recorded |
| 2 | `p3 --json` | stdout is only the envelope, the text is on stderr |
| 3 | `p4`, no pin | The baseline is the global default. The entry is the last entry |
| 4 | `ROC_TOOLCHAIN` set | The pin is written and the note says that `ROC_TOOLCHAIN` wins |
| 5 | `home2`, N missing, a person, Enter | The prompt of `roc install` (default yes), then the list, install, probes |
| 6 | `home4`, both missing, CI, `--allow-downloads` | No prompt. One answer line with the count and the size. 2 installs |
| 7 | `home5`, baseline O missing, a person, Enter | The prompt of `use_download` (default Yes) |
| 8 | `home3`, both missing, CI | Exit 13, one stop with the count and the size. Nothing is installed or written |
| 9 | `link-dev` | Exit 2, no Fx call |
| 10 | `link`, a prefix of an installed link build | Exit 2, nothing is written |
| 11 | `--no-check` | Exit 2, no Fx call |
| 12 | `p12`, range | Exit 10 with the range, no probe, `talon.toml` stays |
| 13 | `TALON_NIGHTLY=0` | Exit 10 with the switch and its source |
| 14 | `p14`, new error in the candidate | Exit 11, no write, no build, the copy is deleted |
| 15 | `p15`, the app has errors already | The same errors are notes, the pin is written |
| 16 | `home9`, baseline O missing, `TALON_AUTO_INSTALL=no` | Exit 13 with the refusal text, no question |
| 17 | `home7`, a package member, `--json`, `--allow-downloads`, CI | `downloads` 1, `build` null, 2 probes |
| 18 | `home10`, `ROC_TOOLCHAIN` is the new N, N missing, a member with no pin | One download (not 2), the prompt of `roc install`. The baseline is N |
| 19 | `home8`, baseline O missing, a person, `n` | Exit 13, nothing downloaded or written |
| 20 | The baseline check crashes (SIGSEGV) | The text names O, the baseline compiler, not N |
| 21 | `home11`, both missing, a person, Enter | One prompt for 2 compilers, default Yes |
| 22 | The only member has the new pin (other tag form) | Q7: one line, no download, no probe, no write, exit 0 |
| 23 | `home12`, range `>=nightly-2026-10-14-ffffff0`, N installed | Two nightlies of one day: the time (10:00 and 15:00) orders them, so N is in the range and the pin is written |
| 24 | `home13`, the same range, N missing | The time of N comes from the list. One download (Enter), the pin is written |

## 6. The downloads (question Q4, proposal)

| New compiler missing | Baseline compilers missing | Prompt | Rules |
| --- | --- | --- | --- |
| yes | none | The prompt of `roc install` (the command names it): a person, default yes. No person: no prompt, the download starts | R-NI6, R-DL4 |
| any | 1 or more | One prompt for all: `Consent.use_download` (1 id or more). Default Yes (`roc use` names its download, R-DL3). Flags, `--yes`, `TALON_AUTO_INSTALL=yes` answer it. No person and no answer: exit 13 with count and size. `TALON_AUTO_INSTALL=no`: exit 13 | R-NI5, R-DL1, R-DL5 |
| no | none | No prompt, no list request | |

## 7. Output (proposal for the review, TW24)

| Case | Text | Stream |
| --- | --- | --- |
| Operand missing | `tln roc use needs one compiler: a full id, a prefix, @latest or a step like @-1` | stderr, exit 2 |
| 2 operands or more | `tln roc use takes one compiler, got <n>` | stderr, exit 2 |
| `git-`, `link-`, `copy-` | `tln roc use does not take <ref>: a git, link or copy build cannot be a pin. Use ROC_TOOLCHAIN or tln roc default for it.` | stderr, exit 2 |
| Switch off | `tln roc use <id>: it is a nightly, and nightly is false (set by <source>). Use a release, or change the nightly switch. tln roc use does not change talon.toml.` | stderr, exit 10 (`no_tuple`) |
| Range | `tln roc use <id>: it is outside [toolchain] roc (<range>). Use a compiler in the range, or change [toolchain] roc. tln roc use does not change talon.toml.` | stderr, exit 10 (`no_tuple`) |
| Download prompt for 2 or more | `Download <n> compilers, <size>: <ids>?` | prompt |
| Result | `<file>`, then `  ~ roc: <old> -> <id>` or `  + roc: <id>` for each member, then `the roc pin is now <id>` | stdout |
| `ROC_TOOLCHAIN` set | `note: ROC_TOOLCHAIN is <t>. It has a higher priority than the new pin <id>, so it still selects the compiler. The pin is used when ROC_TOOLCHAIN is not set.` | stdout |
| No member changes (Q7) | `the roc pin is already <id> in every member. Nothing was written.` Exit 0. No download, no probe | stdout |
| `--json` | `data` keys in order: `id`, `files` (`path`, `previous`), `probes`, `downloads`, `check`, `build`, `notes`. The human text goes to stderr | stdout |

## 8. Decisions that the design does not fix

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Baseline of a member | Its own pin, else `ROC_TOOLCHAIN`, else the compiler of Resolution 13 (R-BL1) | One baseline for the workspace. The new compiler as baseline |
| `select!` with a pinned member | Only for the members with no pin | For all members (exit 18 when a member has a pin and another has none) |
| A member that has the pin already | No probe, no write (`Err(Same)`, R-H1) | Probe it anyway |
| Workspace write | One `write_atomic!` after all members passed | A write after each member |
| Who writes the lines | `Manage.use_report` from the files that were written | Print before the write |
| Order of the installs | The new compiler first, then the baselines in member order | Baselines first |
| `Ladder.use!` starts | One `Start.run!` for each distinct baseline compiler | One for each member |
| `.last-use` of the baseline | Touched after the candidate, only when it is another installed compiler | Not touched. Touched first |
| Operand that is a prefix | `Nightlies.pick` over the installed ids first, then the list | The list first |
| Gate failure kind | `NoTuple`, exit 10 (answer Q6), as R-NS2, R-SO19, 025b D4 and `roc update` | `Usage`, exit 2 |
| `times` of the gate | The `published_at` of the installed ids (`.talon.json`, read only with a range) and of the new compiler (the list). Same order as `Pin.order` (answer Q8) | `[]`: the tag text orders nightlies of one day |
| Prompt default | Yes (answer Q4: `roc use` names its download, R-DL3) | No |
| One id missing | `use_download` for 1 id or more | `command_download` for one id (default No, shared with the resolve commands) |
| No member changes | One line, exit 0, no download (Q7) | Probe anyway. Install the new compiler anyway |

## 9. Out of scope

| Ids | Reason |
| --- | --- |
| R-U6 for "an argument" | A tln command has no compiler argument (rank 1 is for the proxy). Only `ROC_TOOLCHAIN` has a higher priority (question Q8) |
| The real compiler (`REAL_ROC`) | L4 is the nightly run. The fake roc fixes the calls |

## 10. Questions (TW17)

| # | Question | State |
| --- | --- | --- |
| Q4 | The prompt of `roc use` for the baseline and the new nightly | Answered in the review (section 14): one prompt, default Yes. No person: the named new compiler alone starts, a missing baseline is exit 13 |
| Q5 | A workspace: one check for all or one for each member | Answered: each member on its own baseline, one write after all passed |
| Q6 | The exit code of the range and switch refusal (R-U5) | Answered: exit 10 (`no_tuple`) |
| Q7 | A run where every member has the pin already | Answered: one cheap L2 run (us1 run 22). The text is a proposal for the review (TW24) |
| Q8 | An argument for R-U6, and the order for the range | Answered: only `ROC_TOOLCHAIN`. `published_at` orders nightlies (as `Pin.order`) |

Design gaps: none open.

## 11. Notes for the code agent

| Topic | Note |
| --- | --- |
| Stubs | `RocUse.use!`, the 6 `Manage` functions, `Pin.use_gate`, `Consent.use_download`, `Ladder.use!` are `crash "todo"`. The old bodies stay for all other functions |
| Calls | `expect/calls.log` of `roc/us1-use`, `us2-workspace`, `us3-step` fix the order of the effects |
| Probes | The baseline check of a member must run on its own compiler. `Ladder.baseline` gets the baseline compiler id too |
| Compiler limits | `roc build` exits 2 on a warning. A record with a `Bool` field in an `Err` crashes `roc test`. `package` is a reserved word |

## 12. Red output (stub tree, `scripts/test.sh`)

| Step | Result | Failing |
| --- | --- | --- |
| check, fmt, selftest | pass | none |
| l0 | FAIL | `manage.roc` 4 expects, `pin.roc` 1 (`use_gate`), `consent.roc` 1 (`use_download`): all crash with `todo`. `args.roc` passes (it has the flag errors already) |
| l2 | FAIL, 57 passed, 3 failed | `roc/us1-use`, `roc/us2-workspace`, `roc/us3-step`: `[ROC CRASHED] todo` (`RocUse.use!`) |
| l3 | FAIL, 46 passed, 1 failed, 1 skipped | `compilers/us1-use` |

With the private reference tree all steps passed with no WARN (check 6.6, fmt 0.2, l0 6.2, l2 15.4, l3 9.5, selftest 3.7 seconds). After the review changes the stub tree is red as above (l2: 57 passed, 3 failed; l3: 46 passed, 1 failed, 1 skipped). `MISSING=1 scripts/rules.sh` for the ids of section 1 lists none.

## 13. Revert check (TW12)

`research/slice-026b-revert/code-mutate.py` makes one change at a time in the private reference and runs only the tests that should catch it (`ONLY=l3` limits the run to one layer). Result in `research/slice-026b-revert/code-results.txt`: 51 changes, 48 caught, 3 equivalent (after the review changes of section 14: M39 to M44 are new, M15 now flips the default Yes to No). `cli/` is restored after each change and ends equal to `reference/`.

| Group | Changes | Caught by |
| --- | --- | --- |
| `Manage` (M01 to M11) | baseline of a member, the other tag form, `copy-`, text of 2 operands, `use_pinnable`, note text, last line, `~` line, `previous`, `build` | L0 `manage` |
| `Pin`, `Consent` (M12 to M17, M40, M41) | switch ignored, range ignored, switch text, default No, ways of the stop, no size, exit 2 in place of 10 | L0 `pin`, `consent` |
| `RocUse` (M18 to M38) | `select!` for pinned members, a duplicate download, a member with the pin already, counts, note, installed prefix, no prompt, `n` downloads, refusal text, install order, `ROC_TOOLCHAIN` baseline, gate inputs, record, edit | L2 (`us1`, `us2`). L3 also catches M23, M35, M38 |
| `Ladder` (L01 to L06) | baseline parse compiler, baseline spec, `.last-use` of the baseline, one start for each baseline | L2. L3 also catches L02, L03 |
| Review changes (M39, M42 to M44) | the gate with no times, a run with no change that probes, the line for no member, no time of a new compiler | L2 `us1` (M39, M42, M44), L0 `manage` (M43) |
| `Run` (X01) | the command is not wired | L2 |

Equivalent changes (no test can see them):

| Id | Reason |
| --- | --- |
| M30, M31 | `RocUse.consent!` reads the flag and `TALON_AUTO_INSTALL` itself. The same fields in the request go to the ladder downloads, which find every compiler installed (downloads come before the ladder) |
| L05 | `Start.run!` downloads 0 inside `Ladder.use!` for the same reason |

Rounds that changed the tests:

| Gap found | Fix |
| --- | --- |
| No run with a member that has the new pin (M20) | `us2` run 1 has a fourth member in the other tag form |
| No `TALON_AUTO_INSTALL=no` (M26), no answer `n` to the baseline prompt (M27) | `us1` runs 16 and 19 |
| `data.downloads` and `data.build` were only 0 and an app (M22, M36) | `us1` run 17 (a package, one download) |
| `ROC_TOOLCHAIN` is the new compiler and missing (M19, M29) | `us1` run 18 |
| Baseline failure text named the wrong compiler (L01) | `us1` run 20 |
| M39, M44 (after the review) | The gate read the tag text only: no row had two nightlies of one day, and no run had the new compiler from the list | L0 `pin` 3 rows, `us1` runs 23 and 24 |

## 14. Review (manager, 2026-10-23)

Accepted as proposed: the baseline of each member (its own pin, else `ROC_TOOLCHAIN`, else the Resolution 13 compiler), `select!` only for members with no pin, no probe for a member that has the pin already, one write after all members passed (Q5), one `Start.run!` for each distinct baseline, the pick of an installed prefix first, Q8 first part (only `ROC_TOOLCHAIN` has a higher priority, there is no compiler argument), and the proposals of section 7.

Changes:

| # | Change | Where it is done |
| --- | --- | --- |
| Q4 | R-DL3 lists `roc use` as a command that names its download. So the one prompt (new compiler plus a missing baseline, R-U3, R-DL1) has default Yes, not No. With no person: the named new compiler alone starts (R-DL4). When a baseline is also missing, it is a required download that the command does not name: exit 13 with the R-NI5 text, flags named | `Consent.use_download` (default Yes, used for 1 id or more), L0 `consent`, L2 `us1` runs 7, 21 |
| Q6 | R-U5 refusals (out of range, switch off) are exit 10 (`no_tuple`), as R-NS2, R-SO19, 025b D4 and `roc update`. Not exit 2 | `Pin.use_gate`, L0 `pin`, L2 `us1` runs 12, 13, L3 `us1` step 6 |
| Q8 | The gate orders nightlies by `published_at` (the `.talon.json` of installed ids and the list), as `Pin.order` of slice 022. `times: []` is removed | `RocUse.flow!`, L0 `pin` (3 rows), L2 `us1` runs 23, 24 |
| Q7 | One cheap L2 run where every member has the pin. Text proposed for the review (TW24): `the roc pin is already <id> in every member. Nothing was written.` Exit 0, no download, no probe, no write | `Manage.use_report`, `RocUse.flow!`, L0 `manage`, L2 `us1` run 22 |

## 15. Code result (code agent)

Result of `scripts/test.sh`: exit 0, no WARN in the last run. check 7.3 s, fmt 0.1 s, l0 6.3 s (`manage` 18, `pin` 9, `consent` 11 expects, all files pass), l2 60 cases passed in 16.1 s, l3 47 cases passed and 1 skipped in 9.4 s, selftest 5.6 s. `OPT=speed scripts/test.sh`: exit 0 (l2 78.8 s). `roc check`: 0 errors, 0 warnings. `MISSING=1 scripts/rules.sh` lists no id of the table in section 1.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/RocUse.roc` | 323 | `use!`, `flow!` (steps 2 to 10), `named!`, `gate!`, `fallback!`, `install_all!`, `missing_baselines`, `consent!`, `write!`, `print!` |
| `cli/lib/Manage.roc` | 515 | `read_use`, `use_pinnable`, `use_plan`, `use_note`, `use_report`, `use_data`, and private `is_local_build`, `use_refused`. New import: `Compiler` |
| `cli/lib/Pin.roc` | 467 | `use_gate` |
| `cli/lib/Consent.roc` | 312 | `use_download` |
| `cli/lib/Ladder.roc` | 553 | `use!` (it calls `probe_member!` of `run!`, no copy). New import: `Pin` |
| `cli/lib/ResolveBase.roc` | 572 | New public `write_checked!`: `Guard.check_all`, the files that change, one `write_atomic!` (no call for no file). New import: `Guard` |
| `cli/lib/InstallFlow.roc`, `cli/lib/RemoveFlow.roc` | 512, 319 | Their private write tail calls `ResolveBase.write_checked!` (manager review: no copy). Behavior is the same. The unused import `Guard` is gone |

No module is over 600 lines, so there is no split. Reused: `Install.begin!`, `Install.canonical_files!`, `Install.compiler!`, `Known.record!`, `ResolveBase.load!`, `select!`, `settings_of`, `ladder_downloads`, `loaded_text`, `Launch.toolchains!`, `Nightlies.pick`, `RocInstall.offer!`, `ask_download!`, `install_offer!`, `Base.times!`, `Start.run!`, `Locked.edit`, `Locked.spans`, `ResolveBase.write_checked!`, `Consent.required_want`, `Prompt.ask!`.

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Members of a run | All members of the workspace, also with `--file` (as the L2 case `us2` run 2 shows) | Only the current member |
| `select!` for members with no pin | `RocUse.fallback!` calls `ResolveBase.select!` on a `Loaded` that has only the members with no pin (no call when `ROC_TOOLCHAIN` is set or all members have a pin) | A new select function |
| Order of the download steps | The offers of the missing baselines come before the consent decision, as `calls.log` shows (`TALON_AUTO_INSTALL=no` and the stop for no person come after the list request) | Decide before the list |
| The id in a refusal, a stop or a decline | `download_refused` names the first missing baseline. `command_declined` names the first id of the prompt. `download_stop` has the count and the sum of all ids | The new compiler |
| A baseline that is not a nightly and is not installed | `Compiler.require` fails before any offer (R-NS2: no list has it) | An offer with a release id |
| Number `downloads` of `--json` | The compilers that this run installed (`install_offer!` gave `Installed`) | The count of offers |
| Start of the baseline compilers | In `Ladder.use!`, a lazy `Start.run!` for each member in member order, reused for a later member with the same baseline (`Pin.same_id`). This is the order of `calls.log` of `us2` | All starts first |
| `--allow-downloads` | Read from `args.options` in `RocUse.flow!` | `Opts.read` (its checks are for `install`) |
| `--json` and no member changes | The envelope with `Manage.use_data` (`files` empty, `probes` 0, `check` is `"passed"` as the fixed `use_data` writes it) | No envelope |
| The `ROC_TOOLCHAIN` note | Printed only when a file was written, and also the last text of `data.notes` | Print it for a run that wrote nothing. Keep it out of `data.notes` |
| The write of the headers | `RocUse.write!` reads again and cuts the spans, then calls `ResolveBase.write_checked!`, the one tail that `InstallFlow`, `RemoveFlow` and `RocUse` share (manager review) | A private copy in each flow |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

Questions (TW17): none. Compiler limits met: `{ id }` alone is a block (`Present({ id: id })`), and a mutation that leaves a variable unused is a warning (exit 2), so a mutation of that kind must use `_ =`.

## 16. Verify results (revert check, TW12)

`research/slice-026b-revert/agent-mutate.py` puts `code-final/` back, makes one change, runs `roc check`, then only the tests that should catch it (`agent-results.md`). Result: caught 39 of 46 for A01 to X01, and 3 of 3 for B01 to B03 (the moved write tail). `diff -r cli research/slice-026b-revert/code-final/cli` shows no difference after the run. The test agent file `code-mutate.py` and `code-results.txt` were not changed.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Manage` (A01 to A10) | `copy-` taken, text of no operand, `use_pinnable`, baseline of a member with no pin, the other tag form, line for no member, `~` line, `data.build`, `data.downloads`, note text | l0 `manage` (A03, A04, A05, A06, A07, A08, A09, A10 also by l2) |
| `Pin`, `Consent` (A11 to A17) | switch ignored, range ignored, tag text order, exit 2 for 10, default No, no size, prompt with no flags | l0 `pin`, `consent` |
| `Ladder` (A19, A20) | one start for each baseline, baseline on the new compiler | l2 |
| `ResolveBase.write_checked!` (B01 to B03) | writes an unchanged file, writes with no file, does not see a change during the run | l2 (all cases for B01, B02; install, remove, us1, us2 for B03) |
| `RocUse` (A22 to A29, A31 to A35, A37, A40, A42 to A45) | `select!` for pinned members, `ROC_TOOLCHAIN` baseline, prefix not expanded, times read with no range, time of the new compiler, member with the pin, `use_pinnable`, duplicate download, stop text, flag, answer No, tty, install order, no edit, note prefix, probes, record, `--json` stream, ladder id | l2 `us1`, `us2` |
| `Run` (X01) | not wired | l2 |

Mutations that no test caught:

| Id | Change | Class | What a test needs |
| --- | --- | --- | --- |
| A21 | `moved` of the ladder is `request.owners` | Equal: `owners` is `[]` in `RocUse` | none |
| A36 | `downloads` counts an install that another process made | Equal: the fake `Fx` cannot make a second process | none |
| A18 | A baseline in the other tag form of the new compiler is a second start (`b.id == member.baseline`) | Test gap (R-CV1) | A member whose pin is the other form of N, and that changes (a pin that is `Same` has no row) |
| A30 | A missing baseline that is not a nightly is offered, not refused (R-NS2) | Test gap | A member with a release or `link-` baseline that is not installed (exit 13, no list request) |
| A38 | `RocUse.write!` compares the spans of the first text twice, so a change of the header during the run is not seen (the shared `write_checked!` is covered by B03 through the install and remove cases) | Test gap | An L2 run where the second `read_files!` of a member gives other text in the span (exit 17), as the `install` cases do |
| A39 | The `ROC_TOOLCHAIN` note is printed also for a run that wrote nothing | Test gap, and the slice does not say (my decision above) | `us1` run 22 with `ROC_TOOLCHAIN` set, if the design wants a note there |
| A41 | The `ROC_TOOLCHAIN` note is not in `data.notes` | Test gap, and the slice does not say (my decision above) | A `--json` run with `ROC_TOOLCHAIN` set |

Edits of the first run that matched twice or gave a warning (A10, A12, A36) were fixed and run again. The test agent owns the tests (TW18), so the code agent added none of the tests above.

## 17. Gap rows (test agent)

Five gaps of the code agent (`agent-results.md`) are closed with 4 new runs in `roc/us1-use` (tests only, no `cli/` edit). Each mutation of `research/slice-026b-revert/agent-mutate.py` was applied by the script (`code-final/` put back after each, `cmp` of all files is clean), and the new rows fail for it.

| Gap | Rule | Run | What the run shows | Result of the mutation |
| --- | --- | --- | --- | --- |
| A18 | R-CV1 | 25 | `ROC_TOOLCHAIN` is the other tag form of N, the member has no pin (so its baseline is that form). The baseline is the new compiler, so no second start | CAUGHT (l2 `calls.log`) |
| A41 | R-J3, R-U6 | 25 | The same run with `--json`: the note is the last text of `data.notes` | CAUGHT |
| A39 | R-U6 | 26 | `ROC_TOOLCHAIN` set, the pin is there already: nothing is written, so no note | CAUGHT |
| A30 | R-NS2 | 27 | The pin is the release `0.1.0`, not installed: exit 13, `Compiler.require` stops before any offer (no list request) | CAUGHT |
| A38 | R-CC7 | 28 | A hook after the first probe round changes the text of the `roc:` entry: exit 17, nothing is written. A change outside the span is no stop (R-H1) | CAUGHT |

Fast set after the new runs: `scripts/test.sh` exit 0, no WARN (check 7.3, fmt 0.1, l0 6.3, l2 16.3, l3 9.5, selftest 5.1 seconds).

## Close (manager, 2026-10-23)

The code agent decisions are accepted. The shared write tail is `ResolveBase.write_checked!` (no copy). A18, A30, A38, A39 and A41 are caught by the gap runs; A21 and A36 are equivalent. `scripts/test.sh` exits 0 with no WARN (warm cache). Status: done.
