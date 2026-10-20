# 006 Probes ladder (P0)

Phase: P0. Status: done

Slice 006 adds the probe ladder to the flow of `install` and `update`. After the choice and before the write, Talon checks the candidate header with the compiler on `PATH`: the baseline check in the project dir, the whole-app check in a temp copy, and the build in the copy. A ladder that fails stops the command with a blame, and nothing is written. P0 has one tuple, so the ladder is a pass or fail test of that tuple (R-PH9, R-PH10). It also closes the 12 gap rows of slice 005 (K1).

## Rules

| Group | Ids | Design | Where tested |
| --- | --- | --- | --- |
| Ladder steps | R-LD1, R-LD4 to R-LD7 | Resolution 4 | `ladder.roc`, `ld-ladder-flow`, `pr1`, `pr2` |
| Baseline check | R-BL1 to R-BL6 | Resolution 4 | `ladder.roc`, `probe.roc`, `ld-ladder-flow`, `ld-no-check-refuse` |
| Build skip (never applies in P0) | R-BS1, R-BS2 | Resolution 4 | `ladder.roc` (the build is always in the plan) |
| Result classes | R-RC1 to R-RC4 | Resolution 4 | `probe.roc`, `ladder.roc`, `pr1` |
| Compiler on `PATH` | R-SO7 | Resolution 13 | `compiler.roc`, `ld-no-check-refuse` |
| Phase 0 | R-PH6 to R-PH11, R-PH13 | Design 7 | `compiler.roc`, `ladder.roc`, `ld-*` |
| Consent prompts | R-NI1, R-NI2, R-NI3 | CLI 4 | `consent.roc` (the values and texts only) |
| Security | R-SE4 | Design 8 | `probe.roc`, `pr1` (a probe is `check` or `build`, never a run) |
| Constraints | R-C5 for one tuple | Resolution 2 | `ld-ladder-flow` |
| Gap rows of slice 005 K1 | Q9, R-I2, R-OV1, R-C7, R-DT4, R-DT2, R-SP18, R-I8, R-AD26 (Q1), R-AD22, R-C9, R-WS5 | slice 005 | `pin.roc`, `intent.roc`, `vars.roc`, `pick.roc`, 5 `resolve/rs-*` cases |

Rules from `scripts/rules.sh` with no test after this slice, and in scope: none. The ids that the slice lists but does not test are in "Out of scope".

## Files

| Path | Writer | Lines | State |
| --- | --- | --- | --- |
| `cli/lib/Probe.roc` | Stub (test agent) | 91 | Types and `crash "todo"`. The doc comment has the table of the 10 class rules and the rules of the error identity. |
| `cli/lib/Compiler.roc` | Stub | 34 | `version_id`, `kind`, `on_path`, `require` |
| `cli/lib/Ladder.roc` | Stub | 121 | `plan`, `baseline`, `check`, `build`, `run!`. The doc comment has the flow and all message texts. |
| `cli/lib/Consent.roc` | Stub | 46 | `rename_keys`, `move_held`, `picker` |
| `cli/lib/Fx.roc` | Changed | | New fields `probes!`, `copy_tree!`, with wrappers and docs |
| `cli/lib/Resolve.roc` | Changed | | `finish!` calls the new stub `ladder!` before `write!`. `ladder!` is `crash "todo"`. |
| `cli/lib/main.roc` | Changed | | The exposes list has `Compiler`, `Consent`, `Ladder`, `Probe` |
| `cli/RealFx.roc` | Changed | | New stubs `probes!`, `copy_tree!` (`crash "todo"`) |
| `cli/fxprobe.roc` | Changed | | New calls `probes`, `copytree` (the L3 cases use them) |
| `tests/commands/FakeFx.roc` | Changed | | Fake `probes!` (answers from `fx/probes`) and `copy_tree!`. Format in its doc comment. |
| `tests/commands/run.sh` | Changed | | Each case gets a link `fixtures` to `tests/fixtures` |
| `tests/fakes/roc` | Changed | | The exit field also takes `sleep:<s>`, `pwd`, `signal:<n>` |
| `scripts/test.sh` | Changed | | `fmt` skips `tests/fixtures/` (a fixture has a syntax error on purpose, and its line numbers are in the outputs) |
| `tests/fixtures/check/` | Test agent | `make.sh` 71 | Real `roc check` and `roc build` outputs of the pinned nightly: `out/<case>.{args,exit,stdout,stderr}` for 14 cases, with the sources in `src/` |
| `tests/unit/probe.roc`, `compiler.roc`, `ladder.roc`, `consent.roc` | Test agent | 211, 78, 218, 123 | 12 `expect`s, red ("todo") |
| `tests/unit/pin.roc`, `intent.roc`, `vars.roc`, `pick.roc` | Test agent | | Rows for the gap rows 1 to 6 (and R-WS5, R-I2). They pass today. |
| `tests/commands/cases/ladder/ld-ladder-flow`, `ld-no-check-refuse` | Test agent | | 2 new L2 cases, red |
| `tests/commands/cases/resolve/rs-install-names`, `rs-stale-key`, `rs-member-root-table` | Test agent | | 3 gap cases, pass today (they write nothing) |
| `tests/commands/cases/resolve/rs-new-toml`, `rs-highest-use` | Test agent | | 2 gap cases, red (they write, so the ladder runs) |
| `tests/commands/cases/resolve/rs-install-add-key`, `rs-update-scope`, `rs-workspace-shared-group` | Test agent | | Old cases, expected files changed (see "Old cases that changed") |
| `tests/scenarios/fx/pr1-real-fx-probes` | Test agent | `cmd` 27 | L3, red |
| `tests/scenarios/fx/pr2-real-roc-probes` | Test agent | `cmd` 12 | L4 (tag `real-roc`, `REAL_ROC=1`) |
| `research/slice-006-gap/mutate.py` | Test agent | 70 | Revert check of the 12 gap rows (needs `ROC`) |

The code agent writes the bodies of the stubs, `ladder!`, and the real `probes!` and `copy_tree!`. The code agent does not change a test (TW18).

## Public signatures

The contract is in the doc comment of each function. The table lists the names and the use.

| Module | Name | Use |
| --- | --- | --- |
| `Probe` | `args({ command, file })` | `["check", file]`, `["build", file, "--output=<path>"]` (R-LD4, R-LD5, R-SE4) |
| `Probe` | `classify(output)` | `Pass`, `Fail(n)`, `Hang`, `Crash(text)`, `NoFact(text)` (R-RC1 to R-RC4, 10 rules in the doc) |
| `Probe` | `errors({ text, dir, pkgs })` | The errors of a failed probe, with the identity of R-BL4 (file, title, message with no excerpt and no `:line:col`) |
| `Probe` | `compare({ baseline, candidate })` | `{ new, unchanged, removed }` (R-BL5). Sets with no repeat (Q2). |
| `Compiler` | `version_id`, `kind`, `on_path` | The id from `roc version`, its kind, the one compiler on `PATH` (R-SO7, R-PH6) |
| `Compiler` | `require({ id, path_roc })` | `Err` of kind `Consent` (exit 13) when the id is not the `roc` on `PATH` (R-PH7) |
| `Ladder` | `plan(facts)` | The probes of one member: baseline and candidate check in one round, then the build (R-LD1, R-LD4 to R-LD7, R-BS1, R-BS2) |
| `Ladder` | `baseline`, `check`, `build` | The pure steps: output to `Try(Report, Fail)` with the blame texts |
| `Ladder` | `run!(fx, request)` | The command code, direct style over `Fx` |
| `Consent` | `rename_keys`, `move_held`, `picker` | The values for `Prompt.ask!` (R-NI1 to R-NI3) |
| `Fx` | `probes!(specs)` | One child for each spec, all started together, results in the order of the list (R-PP3). A hang is killed at the timeout (R-RC3). |
| `Fx` | `copy_tree!({ from, to, skip })` | Copy a tree. A name in `skip` is not copied, at any depth. The parents of `to` are made. |
| `Resolve` | `ladder!` | The place of the ladder in `finish!` |

## The flow of the ladder

The diagram is in the doc comment of `Ladder` (`cli/lib/Ladder.roc:12`). The calls of `Ladder.run!` for one member, in order, are fixed by the L2 cases:

| Step | Call | Rule |
| --- | --- | --- |
| 0 | `Compiler.require` once, before any call. A failure is exit 13. | R-PH7 |
| 1 | `random!`, then the copy dir `talon/tmp/<16hex>/` | R-CC2 |
| 2 | `copy_tree!` of the dir of the member file, with `skip: [".git"]` | R-CC2 |
| 3 | `write_atomic!` of the candidate header into the copy | R-LD4 |
| 4 | `probes!` with 2 probes: baseline (project dir), candidate (copy). Then `Ladder.baseline`, `Ladder.check`. | R-BL1, R-BL2, R-LD4 |
| 5 | `probes!` with 1 build probe (copy). Then `Ladder.build`. Only for an app. | R-LD5, R-LD6, R-LD7 |
| 6 | `delete!` of the copy, also after a failure | R-CC2 |
| 7 | After all members: print the lines, then `Resolve.write!` | R-PH10 |

`resolve` with `--no-check` makes no call, prints `check: skipped` and goes on to the write (R-BL6, R-LF3). `resolve` with nothing to change does not run the ladder (Q6).

## Tests

| Layer | File | Case | Rules |
| --- | --- | --- | --- |
| L0 | `probe.roc` 1 | `args`, `classify`: 24 rows with the real outputs (pass, warning exit 2, errors, syntax error, not found, build with errors, target error, SIGSEGV, SIGKILL, 139, hang, not started, no result) | R-SE4, R-P1, R-RC1 to R-RC4, R-P2, R-P3, R-LD4, R-LD5 |
| L0 | `probe.roc` 2 | `errors`: counts, pins, titles, files (app, package hash, no file), equal across 2 dirs, line numbers removed | R-BL4, R-P2, R-LD4 |
| L0 | `probe.roc` 3 | `compare`: 9 rows (new, unchanged, removed, shifted line, repeat, order) | R-BL5, R-BL4, R-BL3, R-P6 |
| L0 | `compiler.roc` 1 | `version_id`, `kind`, `on_path` | R-SO7, R-SO9 to R-SO11, R-PH6 |
| L0 | `compiler.roc` 2 | `require`: same id, other id, no compiler | R-PH7, R-PH6, R-BL3, R-DL5, R-EC13 |
| L0 | `ladder.roc` 1 | `plan`: an app, a package, a platform, the dirs, the output path | R-LD1, R-LD4 to R-LD7, R-BL1, R-BL2, R-PP3, R-BS1, R-BS2, R-PH9, R-SE4, R-P1, R-CC2 |
| L0 | `ladder.roc` 2 | `baseline`: pass, fail, hang, crash, no result | R-BL1, R-BL3, R-P7, R-EC1 |
| L0 | `ladder.roc` 3 | `check`: no error, same error as baseline, new app error, new hash error, 2 hashes, hang, crash, no result | R-LD4, R-BL5, R-P6, R-PH10, R-PH13, R-RC2 to R-RC4, R-P3, R-EC1, R-EC10, R-EC11 |
| L0 | `ladder.roc` 4 | `build`: pass, errors the same as baseline, new app error, target error (platform blame), new hash error, hang, crash | R-LD5, R-LD6, R-BL5, R-RC1 to R-RC4, R-PH10, R-EC10, R-EC11 |
| L0 | `consent.roc` 1 | `rename_keys`: prompt fields, texts, report | R-NI1, R-I8, R-NM5, R-NM8, R-NM10, R-NR2 |
| L0 | `consent.roc` 2 | `move_held`: default No, texts, report | R-NI3, R-SP16, R-SP17, R-NM8, R-NR2 |
| L0 | `consent.roc` 3 | `picker`: Interactive, NeedsTty, non-interactive usage failure | R-NI2, R-NM7, R-SP14 |
| L2 | `ladder/ld-ladder-flow` | 7 runs of `update json`: pass with a baseline error, blame of acme/json 2.1.0 (exit 10), app error (exit 11), baseline hang (exit 1), candidate crash (exit 10), platform blame from a build target error (exit 10), pass with notes (unchanged errors). The `calls.log` fixes the call order and the copy dir. | R-LD1, R-LD4 to R-LD7, R-BL1 to R-BL5, R-P6, R-P7, R-RC2 to R-RC4, R-PH9, R-PH10, R-PH13, R-C5, R-AL1, R-AL6, R-CC2, R-EC1, R-EC10, R-EC11 |
| L2 | `ladder/ld-no-check-refuse` | 4 runs: a pin that is not the `roc` on `PATH` gives exit 13 and no call; the same with `--no-check` writes and prints `check: skipped`; no pin plus `--no-check` writes no pin; nothing to change gives no refusal | R-PH6, R-PH7, R-PH9, R-BL3, R-BL6, R-LF3, R-H6, R-DL5, R-EC13, R-SO7, R-RP2, R-AL6 |
| L3 | `fx/pr1-real-fx-probes` | `probes!`: dir and arguments of the child, results in list order when the first probe ends last, SIGSEGV, exit 1 with errors, exit 2 with warnings, a hang killed at 1 s, a dir that is missing. `copy_tree!`: files, a dir, an empty dir, `skip` at any depth, parents made, `Exists`, `NotFound`, nothing made on `NotFound`. | R-LD1, R-RC3, R-RC4, R-P3, R-PP3, R-SE4, R-CC2 |
| L4 | `fx/pr2-real-roc-probes` (`real-roc`) | The real pinned `roc` on headerless apps: check with no error, check with an error, build (the output is made and not run), a round of 2 | R-LD1, R-LD5, R-RC1, R-RC2, R-P1 |

Also changed: the L2 cases in "Old cases that changed" and the 12 gap rows below.

Every new L0 `expect` and L2/L3/L4 case was checked against a private reference implementation, then the reference was deleted (TW18). The revert check is in "Verify and red output".

## The 12 gap rows of slice 005 K1

`research/slice-006-gap/mutate.py` makes one small change of the code for each row, runs the named test, and puts the file back. A compile error counts as invalid, not as a catch. Result: all 12 rows are caught. No row is red on the unchanged code.

| Row | Rule | Mutation | Test that fails |
| --- | --- | --- | --- |
| 1 | Q9 | `Pin.at_least`: no `is_release` check on the bound and the id | `pin.roc` (row `>=0.1.0-rc1`) |
| 2 | R-I2 | `Intent.read_deps`: split at the last `@` | `intent.roc` (a value with 2 `@`) |
| 3 | R-OV1 | `Vars.range_of`: the key of `[overrides]` is read wrong | `vars.roc` (a use only in `[overrides]`) |
| 4 | R-C7 | `Pick.too_young`: `>` to `>=` | `pick.roc` (age equal to the limit) |
| 5 | R-DT4 | `Pick.after_snapshot`: `>` to `>=` | `pick.roc` (time equal to the snapshot) |
| 6 | R-DT2 | `Pick.domain_of`: no sort by URL | `pick.roc` (2 URL forms of one version, reversed) |
| 7 | R-SP18 | `Resolve.asked!`: `install` reads the operands | `resolve/rs-install-names` |
| 8 | R-I8 | `Resolve.live_wants!`: the text of the warning for a stale key | `resolve/rs-stale-key` |
| 9 | R-AD26, Q1 | `Resolve.pairs_of`: name of the new `talon.toml` | `resolve/rs-new-toml` |
| 10 | R-AD22 | `Resolve.range_of_selector`: `Exact` writes `2.2.0`, not `=2.2.0` | `resolve/rs-new-toml` |
| 11 | R-C9 | `Resolve.highest_use`: the lowest use is the current value | `resolve/rs-highest-use` |
| 12 | R-WS5 | `Resolve.load!`: every `talon.toml` has the role `Root` | `resolve/rs-member-root-table` |

Findings from the gap rows:

| Row | Finding |
| --- | --- |
| 10 | A bare `2.2.0` in a selector is an exact version (D7 of slice 005). The test needs 2 runs (`@2.2.0` and `@^2.2`) to show the difference between `=2.2.0` and a range. |
| 8 | The case shows the warning of decision D15 (slice 005). It conflicts with R-I8 and R-NI1: see Q8. |

## Old cases that changed

The ladder is now in the flow, so each old L2 case that writes a header has new output (the `check: passed` and `build: passed` lines and the Fx calls). The changes are the intended effect of this slice (TW21). The expected files were read after the change.

| Case | Change |
| --- | --- |
| `resolve/rs-install-add-key` | `stdout` and `calls.log`: ladder lines and calls for each run that writes |
| `resolve/rs-update-scope` | same |
| `resolve/rs-workspace-shared-group` | same, 2 members (each line has the file path in front). `fx/runs`: `compiler=nightly-2026-10-14-38a3029`, so it is the pin of the header (else R-PH7 refuses) |
| `resolve/rs-highest-use`, `resolve/rs-new-toml` | new gap cases, written with the ladder lines |

## Output (proposed, R-OUT2: text and `data` fields)

| Output | Text (proposal, TW24) | Where |
| --- | --- | --- |
| Check passed | `check: passed` | stdout |
| Build passed | `build: passed` | stdout |
| Check skipped (`--no-check`) | `check: skipped` | stdout |
| An error that is in the baseline and in the candidate | `note: unchanged error: <where>: <title>` | stdout |
| An error that only the baseline has | `note: removed error: <where>: <title>` | stdout |
| Prefix with 2 or more members | `<file>: ` in front of each line | stdout |
| New error in an app file (exit 11) | `a new error in an app file: <path> (<title>); .... The app is not a free variable: fix it, or pass --no-check.` | stderr |
| No tuple works (exit 10) | `no tuple works: the whole-app check found new errors in <name> <version> (<module>: <title>, ...); ...` | stderr |
| Build, target or link error with no file (exit 10) | `no tuple works: the build for the host target failed on the platform <name> <version>: <title>` | stderr |
| Hang or crash of a step | texts in the doc comments of `Ladder.baseline`, `check`, `build` | stderr |
| Compiler not installed (exit 13) | `the compiler <id> is not installed. This version of tln runs only the roc on PATH (<id>).` | stderr |
| Prompts | `Consent` doc comment (question, subject, answer line, report) | stderr |
| `--json` `data` | Not given. Slice 007 builds `--json`. | |

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Options rejected |
| --- | --- | --- |
| D1 | Pure steps are `Ladder.plan`, `baseline`, `check`, `build`, and `Probe` and `Compiler`. `Ladder.run!` and `Resolve.ladder!` are command code. | One module with the decisions inside `run!` |
| D2 | The ladder runs in `Resolve.finish!` after the choice and before `write!`, only when a header changes. Reason: the write is the one step that cannot be undone (R-PH10). | A separate command step after the write, with a rollback |
| D3 | Two probes of the first step run in one round: the baseline (project dir) and the candidate check (copy). The build is a second round. | Three rounds. The baseline first, then the candidate. |
| D4 | The candidate is checked in a temp copy `talon/tmp/<16hex>/`, which `Ladder.run!` deletes at the end and after a failure (R-CC2). `Roots.item(roots, TalonTmp(hex))` names it. | An in-place edit with a restore. `--replace-dep` (see note below). |
| D5 | The build output is `<copy>/tln-probe.out`. The build never runs it (R-P1, R-SE4: `Probe.Command` has no run case). | Build in the project dir |
| D6 | The error identity is the file, the title, and the message without excerpts and `:line:col` (R-BL4). A package file is the hash and the module path, not the cache path. | The full text. The first line only. |
| D7 | `Probe.compare` has set semantics: an error that is twice in a list counts once (Q2). | A multiset |
| D8 | Rule order of a failed whole-app check: a new error in an app file (exit 11) wins over a blame of a hash (exit 10). For a build: app error, then an error with no file (platform blame), then a hash. | A hash first |
| D9 | A new error with no file in a check goes to the app, not to a hash. In a build, an error with no file blames the platform (R-LD5). | Blame the app for both |
| D10 | A baseline that is a hang, a crash or no result stops the command with kind `Internal` (exit 1). Reason: with no baseline set, each error looks new and the blame is wrong (R-BL3). | Treat it as an empty baseline |
| D11 | `Hang` and `Crash` of the candidate are exit 10 (no tuple works). `NoFact` is exit 1. | Exit 1 for all |
| D12 | Exit code 2 with `0 errors` is a pass (R-RC1, R-P2): the class comes from the summary line, not from the exit code. A signal in 4, 6, 7, 8, 11, and exit 139, are a crash (R-RC4). Other signals are `NoFact`. | The exit code only |
| D13 | The timeout of a probe is 30 s (R-RC3, R-P5). | A setting |
| D14 | The roc on `PATH` is the only compiler in P0. A held compiler id that differs is a `Consent` failure (exit 13), not a download (R-PH7). It is refused only when a probe is needed: with `--no-check` or with nothing to change there is no refusal (Q5). | Exit 18. Refuse at the start of every command. |
| D15 | `--no-check` prints `check: skipped`, makes no `Fx` call for it, and writes no pin (R-BL6, R-H6). | Print nothing |
| D16 | With 2 or more members each member has its own copy and is probed one after the other. Each line of the report has the file path of its member in front. | One copy for the workspace. Lines with no file. |
| D17 | The fake `probes!` answers from `fx/probes` in call order, and a missing row means a pass. The real outputs are in `tests/fixtures/check/out/`. | Fake output that is written by hand |
| D18 | The L3 and L4 cases call `fxprobe probes` and `fxprobe copytree`. They have no Talon logic (TW4). | A case that runs `tln` end to end (slice 007) |

Note on D4: `roc check --replace-dep` could check a candidate with no copy of the app. P0 uses the copy because the design says so (R-CC2, R-LD4). The code agent does not change this.

## Out of scope

| Ids | Reason |
| --- | --- |
| R-LD2, R-LD3 | The unit probe of a hash and of the platform is step 1 of the ladder. It needs more than one tuple (P1). In P0 the whole-app check blames a hash. |
| R-BS1, R-BS2 (beyond "the build is always in the plan") | The build skip needs `compat.db` (P1) |
| R-LF2, R-EF2, `compat.db`, evidence | P1 |
| R-PH1 to R-PH5, R-PH12 | Phase tables, not behavior of this slice. R-PH12 is the output of `why`. |
| R-NI1, R-NI3 wiring in `Resolve` | `Consent` gives the values. The commands that ask (`add`, `install`, `update`) are slice 007. |
| R-NI4 to R-NI16 | Prompts for downloads and other commands: need a compiler download or other commands. |
| R-SE1 to R-SE3, R-SE5 to R-SE16 | Other security rules: not part of the probes |
| R-SO1 to R-SO6, R-SO8, R-SO12 to R-SO16, R-SO18 | Other compiler rules (downloads, selection, `config.toml`): P1 (R-PH7) |
| R-C8 | The warning for 2 series in the closure needs the closure walk (slice 007) |
| Parallel slots, compiler downloads | P1 |

## Questions (stop until answered)

Each question has a default that the stubs and the tests use. The code agent does not decide these.

| # | Question | Default | Depends |
| --- | --- | --- | --- |
| Q1 | Exit code 128 plus a fault signal other than 139 (a shell that reports a crash) | `NoFact("no result (exit <n>)")`. Only 139 is a crash. | `probe.roc` expect 1 |
| Q2 | 2 real errors of one probe can have the same identity (same file, title, message after the removal of the line numbers). One set or a count? | A set (D7) | `probe.roc` expect 3 |
| Q3 | What does the copy hold? The whole dir of the member file, or only the files that the app imports? | The whole dir, with `skip: [".git"]` | `ld-ladder-flow` `calls.log` |
| Q4 | The header of the candidate can have path entries (`./lib`). In the copy a relative path points to another place. Make the paths absolute in the copy, or copy the targets? The design says nothing. | Absolute paths (Design gap: R-LD4 needs the answer) | `ld-ladder-flow` (stub doc, step 3) |
| Q5 | When is R-PH7 refused? At the start of the command, or only when a probe is needed? | Only when a probe is needed (D14) | `ld-no-check-refuse` |
| Q6 | R-PH9 says each tuple is probed. When no header changes, run the ladder anyway? | No. Nothing changes, so nothing to check. | `ld-no-check-refuse` run 4, `rs-*` |
| Q7 | A workspace has 2 members that are 2 apps. Is a failure of member 2 a reason to stop before the write of member 1? | Yes: nothing is written (R-PH10). A member is probed after the member before it passed. | `rs-workspace-shared-group` |
| Q8 | Design conflict: R-I8 and R-NI1 say a stale key is a prompt (rename). Slice 005 D15 made it a warning. Which one does P0 follow? | The warning (D15 of slice 005). `Consent.rename_keys` has the prompt for slice 007. | `rs-stale-key` |
| Q9 | Design conflict: R-SO14 says exit 2 for a missing compiler, slice 005 Q3 (accepted) says exit 18. | Exit 18 (the accepted answer) | `rs-no-compiler` (slice 005) |

## Disputes (from the code agent)

| Test | Change | Design source |
| --- | --- | --- |
| `resolve/rs-highest-use`, `resolve/rs-install-add-key`, `resolve/rs-new-toml`, `resolve/rs-update-scope` (`expect/stdout`, `expect/calls.log`) | The 4 expected files had no ladder lines and no ladder calls (the table "Old cases that changed" says they have them, and `rs-workspace-shared-group` has them). Written with `UPDATE=1`. The diff against the old files has only the lines `check: passed`, `build: passed` and the calls `random`, `copy_tree`, `write_atomic`, `probes 2`, `probes 1`, `delete`, in the order of `ld-ladder-flow`. | R-PH9, R-PH10, R-AL6 (each of these runs writes a header, so the ladder runs); slice "Old cases that changed" |

## Verify and red output

Revert check (TW12) of the new tests, against the private reference. Each row is one change of the code. The test named in the last column fails (a compile error is not a catch: it was checked for each L0 row, "0 compiler errors").

| # | Rule | Change of the code | Layer that fails |
| --- | --- | --- | --- |
| M01 | R-RC4 | SIGSEGV (11) is not in the crash set | L0 `probe` |
| M02 | R-RC1, R-P2 | A pass needs exit 0 (warnings exit 2) | L0 `probe` |
| M03 | R-RC4 | Exit 139 is not a crash | L0 `probe` |
| M04 | R-RC2, R-LD5 | A build target error needs more than 99 headers | L0 `probe` |
| M05 | R-BL4 | The line numbers stay in the message | L0 `probe` |
| M06 | R-BL5, Q2 | A list, not a set | L0 `probe` |
| M07 | R-BL4 | The source excerpt stays in the message | L0 `probe` |
| M08 | R-LD5 | A build error with no file is not blamed on the platform | L0 `ladder` |
| M09 | R-P7, R-EC1 | A baseline hang gives exit 10 | L0 `ladder` |
| M10 | R-LD7 | A package has a build | L0 `ladder` |
| M11 | R-BL1 | The baseline runs in the copy | L0 `ladder` |
| M12 | R-EC11 | A package error is an app error | L0 `ladder` |
| M13 | R-PH7 | Any compiler id is accepted | L0 `compiler` |
| M14 | R-NI3 | The default of the move prompt is Yes | L0 `consent` |
| M15 | R-CC2 | The copy is not deleted | L2 (several cases) |
| M16 | R-LD6 | No build | L2 (several cases) |
| M17 | R-CC2 | `skip` is empty | L2 (several cases) |
| M18 | R-PH7 | `Compiler.require` is not checked | L2 (several cases) |
| M19 | R-BL6 | `--no-check` runs the ladder | L2 (several cases) |
| M20 | R-AL6 | The ladder runs also with no change | L2 (several cases) |
| M21 | R-P6 | A new hash error is not blamed | L2 (several cases) |
| M22 | R-PP3 | The prefix `<file>: ` for 1 member | L2 (several cases) |
| M24 | R-PP3 | The prefix `<file>: ` only for more than 5 members | L2 (several cases) |
| M23 | R-LD4 | A fixed name of the copy dir | L2 (several cases) |
| L3-1 | R-CC2 | `skip` is ignored by `copy_tree!` | L3 `pr1` |
| L3-2 | R-LD1 | The child has no working dir | L3 `pr1` |
| L3-3 | R-RC3 | No timeout | L3 `pr1` |
| L3-4 | R-PP3 | The results are in the order of the ends | L3 `pr1` |
| L3-5 | R-CC2 | A target that exists is not refused | L3 `pr1` |
| L3-6 | R-P3 | A child that did not start counts as a pass | L3 `pr1` |

The L4 case `pr2` ran once with `REAL_ROC=1` against the reference (the real pinned roc). It passes. The times of roc are made stable with `sed`.

Red output of `scripts/test.sh` on the stubs (2026-10-20). The state is red as designed (TW18). `check`, `fmt` and `selftest` pass.

| Step | Result | Detail |
| --- | --- | --- |
| check | pass (2.1 s) | All files compile (the stubs). No warning. |
| fmt | pass (0.1 s) | |
| l0 | FAIL (6.8 s) | `probe.roc` (3 expects), `ladder.roc` (4), `compiler.roc` (2), `consent.roc` (3): all `Roc application crashed with this message: todo`. All other unit files pass. |
| l2 | FAIL (31.5 s): 15 passed, 7 failed | `ladder/ld-ladder-flow`, `ladder/ld-no-check-refuse`, `resolve/rs-highest-use`, `resolve/rs-install-add-key`, `resolve/rs-new-toml`, `resolve/rs-update-scope`, `resolve/rs-workspace-shared-group`: all `[ROC CRASHED] todo` in `Resolve.ladder!`. The 3 gap cases that write nothing pass. |
| l3 | FAIL (9.1 s): 16 passed, 1 failed, 1 skipped | `fx/pr1-real-fx-probes`: `[ROC CRASHED] todo` in the real `probes!`. The L4 case `pr2` is skipped (no `REAL_ROC=1`). |
| selftest | pass (5.6 s) | |

The fast set takes about 55 s (TW20: 3 minutes). The 5 old L2 cases that write changed by design: their expected files have the ladder lines, and they stay red until the code agent writes `ladder!`.

Gap rows 1 to 12 pass on the current code (see "The 12 gap rows"). To run the L4 case: `REAL_ROC=1 tests/run.sh pr2-real`. To make the fixtures again: `tests/fixtures/check/make.sh`.

## Verify results (code agent, 2026-10-20)

`scripts/test.sh` exit 0: check 2.3 s, fmt 0.1 s, L0 37 files pass (7.8 s), L2 22 cases pass (29.1 s), L3 17 pass and 1 skipped (9.1 s), selftest pass (6.6 s). Total 55 s. L4 `fx/pr2-real-roc-probes` (`REAL_ROC=1 tests/run.sh pr2-real`): 1 passed.

Revert check (TW12): `research/slice-006-revert/mutate.py`, result table in `research/slice-006-revert/results.md`. Caught 33 of 35. The code after the run equals the copy in `research/slice-006-revert/before/`.

| Id | Rule | Mutation | Result |
| --- | --- | --- | --- |
| M01 to M10 | R-RC1 to R-RC4, R-P2, R-P3, R-BL4, R-BL5 | `Probe`: fault set, 128 plus signal (Q1), pass from the summary, hang, error count, not started, positions, excerpt, package path, set | caught by L0 `probe` |
| M11 to M13 | R-PH7, R-SO9, R-SO11 | `Compiler`: any id accepted, nightly test, id with a space | caught by L0 `compiler` |
| M14 to M19 | R-LD7, R-BL1, R-LD5, R-EC11, R-P7, R-BL5 | `Ladder`: build for a platform, baseline in the copy, no platform blame, no app error, baseline hang exit code, no removed note | caught by L0 `ladder` |
| M20 | R-NI3 | `Consent`: default Yes | caught by L0 `consent` |
| M21, M23 to M25, M27 to M29 | R-CC2, R-PH7, R-BL6, R-AL6, R-PP3, R-PH13, R-LD6 | no delete of the copy, `Compiler.require` always passes, `--no-check` runs the ladder, the ladder runs with no change, prefix for 1 member, wrong moved list, build probe twice | caught by L2 `ladder/*` |
| L3-1 to L3-6 | R-CC2, R-RC3, R-PP3, R-LD1, R-P3 | `RealFx`: no skip, no timeout, order of the ends, no dir, a missing `to` is accepted, not started is a pass | caught by L3 `pr1` |
| M22 | R-CC2 (Q3) | `Ladder.run!`: `skip: []` in place of `skip: [".git"]` | NOT CAUGHT. The fake `copy_tree!` skips by name, but no case has a `.git` dir in the app dir, and the copy is not read. |
| M26 | R-LD4 | `Ladder.run!`: the candidate file has the header text twice | NOT CAUGHT. The fake `probes!` answers from a table and never reads the copy, and `calls.log` has the path of the write, not its content. No test checks the text of the candidate header (also not the absolute path entries of Q4). |

Decisions of the code agent that the slice does not fix:

| # | Decision | Options rejected |
| --- | --- | --- |
| C1 | `Text.resolve(dir, path)` (new, in `cli/lib/Text.roc`) removes `.`, `..` and `//` from a path. `Probe.errors` and the absolute path entries of Q4 use it. | A second private function in each module |
| C2 | The candidate header has the `Pin` op of `decision.writes` (R-RP3), so the probe checks the header that the command writes. | A candidate with no pin |
| C3 | `Ladder.run!` collects the lines of all members and prints them after the last member. A failure of a member prints nothing to stdout. | Print each member at once |
| C4 | `copy_tree!` of `RealFx`: `NotFound` for a missing `from` and `Exists` for a `to` that is there are found before anything is made. A link is copied as its target with `Path.copy!`, or recursively for a dir. | Delete the partial copy inside `RealFx` (the command deletes it, R-CC2) |
| C5 | `probes!` of `RealFx` keeps its own deadline (`Utc.now!`) and calls `kill!`, then `close!`. A hung child gives empty `stdout` and `stderr`. `manage_tree` is on, so the children of roc end too. | `Cmd.timeout_ms` (its result for a child that is started with `spawn!` is not documented) |
| C6 | A `Fail(n)` with no error header that `Probe.errors` can parse is a pass in `Ladder.check` (no new error). | Treat it as no result |

## Review (manager, 2026-10-20)

The decisions D1 to D18 are accepted. The answers below are proposals of the manager. The user did not confirm them yet.

| # | Answer | Test change |
| --- | --- | --- |
| Q1 | Exit code 128 plus a fault signal (4, 6, 7, 8, 11) is a crash, the same as 139. R-RC4 names the signals, and "exit 139 seen" is an example. Exit 128 plus another signal is `NoFact("no result (exit <n>)")`. | The manager added 2 rows to `probe.roc` expect 1: exit 134 is `Crash("exit 134")`, exit 137 is `NoFact`. |
| Q2 | A set (the default) | None |
| Q3 | The whole dir with `skip: [".git"]` (the default) | None |
| Q4 | Absolute paths in the copy (the default). Design gap, to report to the user. | None |
| Q5 | Only when a probe is needed (the default) | None |
| Q6 | No ladder when no header changes (the default) | None |
| Q7 | Yes, nothing is written (the default) | None |
| Q8 | The design wins: R-I8 and R-NI1 make a stale key a prompt. Slice 006 keeps the warning of slice 005 D15. Slice 007 wires `Consent.rename_keys` into `install` and `add`, and changes `rs-stale-key`. | None in slice 006 |
| Q9 | Exit 18 in P0. R-SO14 is about compiler ranks (P1), and its message names `tln roc install`, which P0 does not have. To report to the user. | None |

## Review of the code (manager, 2026-10-20)

`scripts/test.sh` passes (manager run: l0 6.5 s, l2 26.1 s, l3 9.1 s). The L4 case `pr2-real-roc-probes` passes (code agent run). The revert check caught 33 of 35 mutations.

| Item | Decision |
| --- | --- |
| Dispute: 4 L2 expected files rewritten with the ladder lines | Accepted. The table "Old cases that changed" says these cases have the ladder lines. |
| C1 to C5 | Accepted |
| C6: `Fail(n)` with no error that Talon can parse counts as a pass | Not accepted. A failed check must never let a write go through (R-PH10). The answer is `NoFact`, exit 1. Moved to slice 007: the test agent adds a row, the code agent changes `Ladder`. |
| M22 not caught (`.git` skip) | Moved to slice 007: a `.git` dir in the app dir of a deep case, and a check of the copy. |
| M26 not caught (candidate header text, Q4 absolute paths) | Moved to slice 007: the fake `probes!` records or checks the candidate header. |

## Answers of the user (2026-10-20)

| # | Answer | Work |
| --- | --- | --- |
| Q1 | "No result" is cleaner for the long term: Talon starts `roc` with no shell, so a real fault comes as a signal. An exit code of 128 plus n comes from a program or a wrapper. In P1 a crash is a compiler-fault fact in `compat.db` and the registry, and a wrong fact is shared. So exit 134 and the other exit codes are `NoFact("no result (exit <n>)")`. Exit 139 stays a crash, because R-RC4 names it. | Slice 006b: the row of exit 134 in `probe.roc` changes to `NoFact`, and `Probe.is_fault_exit` accepts only 139. |
| Q4 | A copy that keeps the relative paths is not simple: a path entry can point out of the app dir (`../lib`), and the copy would need the targets or links to them. So a util rewrites the paths: in the files of the copy that match a glob, it changes a path prefix to another prefix. The ladder uses it for the header of the candidate. | Slice 006b: the util (pure part with L0 rows, a `Fx` part if needed), and `Ladder` uses it in place of the header-only rewrite. |
| Q8 | Prompt (R-NI1), as the manager answer says | Slice 007 |
| Q9 | Exit 18. The design is changed: R-SO14 (Resolution 13) says exit 18, R-EC2 no longer lists "no selected compiler", R-EC18 lists it. | None: the code already gives exit 18. |
