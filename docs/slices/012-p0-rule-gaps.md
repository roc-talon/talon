# 012 P0 rule gaps

Phase: P0. Status: done

This slice closes P0. It takes the P0 rules that no test names (the audit in `docs/slices/011-why.md`), and the 3 gaps that slice 011 moved here (P8, P9, W8). It follows `docs/agents/BRIEF-tests.md`. The earlier slices 009 to 011 are not committed: the pre-slice copies of the changed files are in `research/slice-012-revert/before/` (with `NEW.txt`).

## Decision for each rule of the audit

| Rule | Design says | Decision | Where |
| --- | --- | --- | --- |
| R-EV4 (`TALON_NIGHTLY`) | Resolution 1: R-NS8 (the environment, rank 1), R-NS5 (a nightly pin with the switch off is outside: exit 10 for `install` and `verify`, exit 14 for `--frozen`) | P0 behavior. Tested | L3 `verify/vf1-verify` (3 runs) |
| R-EV5, R-SO2 (`ROC_TOOLCHAIN`) | R-PH6 says "ranks 1 to 4 can select [the roc on PATH] when they name its id". R-PH7 refuses another compiler. But R-BL3 says the baseline of `install` is the held pin, so rank 2 changes nothing when a header pin is there | Question Q28. No test | none |
| R-SC12 (a prefix) | The full id only, in `ROC_TOOLCHAIN`, the `roc:` pin, `.roc-version` and `talon.toml` | `talon.toml` is P0 and tested (exit 19, R-EC19). The `roc:` pin of the header: Q29. The other 2 places: Q28 and Q30 | L0 `intent` (2 rows), L0 `pin` |
| R-SO5, R-SO18 (`.roc-version`) | Rank 5 and a warning in `install` and `ls`. R-PH6 lists ranks 1 to 4 for P0, and `TESTING.md` 7.4 puts R-SO1 to R-SO6 and R-SO8 to R-SO18 in P1 | Out of scope (P1). Q30 asks the user to confirm for R-SO18 (the warning needs no download) | none |
| R-SO16 (Talon never writes `.roc-version`) | Resolution 13 | P0 behavior, a negative rule. Named in the L3 case that writes the pin: its tree diff has no `.roc-version` | L3 `add/ad1-add-entries` |
| R-LF5 (no `--locked`) | One sentence | P0 behavior. `--locked` is a flag that no command takes: exit 2 | L3 `flags/fl12-bad-flags` |
| R-OV2 (an override raise, the whole-app probe) | The override is a free variable, and the whole-app probe covers the raise | P0 behavior (R-PH9: the whole-app check is in P0). Two runs: the override gives the version, and a raise that breaks a package stops at the check | L2 `ladder/ld-ladder-flow` runs 8 and 9 |

## Naming gaps (the behavior is tested; the id is added to the test that checks it)

I read each test before I added the id.

| Rule | Test that checks it | What I checked |
| --- | --- | --- |
| R-SO3 | L0 `pin` 2, row "a pin stays, also when it is not the compiler" | The header pin is the held value, not the `roc` on `PATH` |
| R-SO4 | L0 `pin` 2, rows "a pin below the lower bound", "a pin inside the range" | `[toolchain] roc` is read as a range and limits the pin (reported as `outside`). P0 has no download, so "newest installed in range" has only the `roc` on `PATH` (see Q32) |
| R-SO14 | L2 `resolve/rs-no-compiler` | No pin and no `roc` on `PATH`: exit 18, the text says that there is no `roc` on `PATH`. `install --frozen` does not stop. The text does not name `tln roc install` (P0 has no `tln roc`: slice 006 Q9) |
| R-SE1 | L2 `fetch/fe-flow` run 3 and L3 `fetch/fe1-loopback-fetch` (bad hash, exit 16, real `roc unbundle`) | A package with other bytes than its hash stops the fetch, and no item stays |
| R-SE3 | L0 `pick` 1 (`min-release-age` hides a new release), L3 `verify/vf1-verify` (2.2.0 is 1 day old, hidden by the default 2d) | The P0 part of R-SE3 is `min-release-age`. The compilers, `tln tool` and the provenance display are P1 and P2 |
| R-SE9 | L2 `fetch/fe-flow`, L3 `fetch/fe1-loopback-fetch` | Partial: Talon unpacks a package only with `roc unbundle`, in a temp dir, and a rejection leaves no item. The checks of paths and sizes are done by `roc`, so no test repeats them (R-GP5 style). The `tar` part of R-SE9 is P1 (compilers, Zig) |
| R-AD37 | L3 `add/ad1-add-entries`, first run (`add --offline`) | New run, red: see "Red output" and Note 1 |
| R-NM11 | L3 `add/ad1-add-entries` (CI mode: invalid alias, reserved word, taken alias: exit 2, text names `--as`) and the new L2 `prompt/nm11-alias-stops` (the same 3 runs in interactive mode: no `ask` call) | The invalid alias is no prompt in both modes. The ambiguous name and the binary clash are P1 (`tln x`, `tln tool`) |

## Files

| File | Change |
| --- | --- |
| `tests/unit/pickclosure.roc` (108 lines) | +3 rows in expect 2: P8 and the 2 rows of P9. Header comment extended |
| `tests/unit/intent.roc` (292) | +2 rows in the failure table (R-SC12) |
| `tests/unit/pin.roc`, `tests/unit/pick.roc` | Comments only: R-SC12, R-SO3, R-SO4, R-SE3 |
| `tests/scenarios/flags/fl12-bad-flags/cmd` (9) | +1 run (`install --locked`) and its expected output |
| `tests/scenarios/verify/vf1-verify/cmd` (29) | +3 runs (R-EV4, R-NS8, R-NS9) and their expected output. The case copies `talon.toml` and puts it back |
| `tests/scenarios/add/ad1-add-entries/cmd` (44) | +1 run (`add --offline`, first), comment lines, ids R-AD37 R-DI12 R-SO16 R-NM11 |
| `tests/commands/cases/ladder/ld-ladder-flow/` | +2 runs, projects `p8` and `p9` (`[overrides]`), +5 probe rows. `rules`, expected files |
| `tests/commands/cases/prompt/nm11-alias-stops/` | New. L2, entry `commands`, 3 runs, interactive mode (`TALON_INTERACTIVE=1` and a terminal). `calls.log` 67 lines |
| `tests/commands/cases/resolve/rs-no-compiler/rules`, `fetch/fe-flow/rules`, `tests/scenarios/fetch/fe1-loopback-fetch/cmd` | Ids only |
| `research/slice-012-revert/` | `mutate.py` (11 rows), `results.md`, `before/`, `code-before.sha256` |

No Roc code of `cli/` was changed. No public signature is new.

## Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `pickclosure` 2, row P8: `mid` names `core 1.0.0`, the tuple has `core 1.1.0`: `Done`, the header of `core 1.0.0` is not asked for | R-OV1 R-C2 |
| L0 | `pickclosure` 2, rows P9: the deps of `mid` are `text` then `util`: `Need` has that order. The reverse list gives the reverse order (a sort would not) | R-DT2 |
| L0 | `intent` 1, rows: `>=nightly-2026-10-09` and `=nightly-2026-10` in `[toolchain] roc`: exit 19 | R-SC12 R-EC19 |
| L3 | `flags/fl12-bad-flags`: `tln install --locked`: exit 2, `flag '--locked' is not for 'install'` | R-LF5 R-FL12 |
| L3 | `verify/vf1-verify`: `TALON_NIGHTLY=0` with a nightly pin: exit 10, text names the switch. `[toolchain] nightly = false`: same. `TALON_NIGHTLY=1` with that key: runs | R-EV4 R-NS5 R-NS8 R-NS9 |
| L3 | `add/ad1-add-entries`: `add acme/util --offline` first: exit 15 (red). No `.roc-version` in any tree diff | R-AD37 R-DI12 R-SO16 R-NM11 |
| L2 | `ladder/ld-ladder-flow` run 8: `[overrides] json = "acme/json@=2.0.5"`, `update json` gives 2.0.5 (the implied range would give 2.1.0), then the whole ladder (3 probes) and the write | R-OV2 R-OV1 |
| L2 | `ladder/ld-ladder-flow` run 9: `[overrides] json = "acme/json@=2.1.0"`: the check shows a new error in acme/json 2.1.0: exit 10, no write, no build | R-OV2 |
| L2 | `prompt/nm11-alias-stops`: 3 runs in interactive mode, exit 2 each, no `ask` | R-NM11 R-AD16 R-AD17 R-AD18 |

Count: 5 new L0 rows (3 + 2), 1 new L2 case (3 runs), 2 runs added to an L2 case, 5 runs added to L3 cases (1 + 3 + 1).

## Output proposals (TW24, for the review)

| Item | Proposal |
| --- | --- |
| `add --offline`, new group, no cached page | `tln: error[network]: the index of acme/util has no cached page and --offline is set. Run the command without --offline.` Exit 15 (R-DI12 says exit code 15) |
| `install --locked` | The existing text for a flag that a command does not take. Note: `tln add --locked` says `not for 'install'`, because `add` is `install` in the flag table (not changed, not tested) |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | R-EV4 is tested on `verify`. `install`, `update`, `remove` and `verify` read the switch with the same function (`Install.nightly_of`), and the `--frozen` finding of R-NS5 has its own L2 case (`rs-frozen`, with the word `nightly=false`) | A run for each command |
| D2 | R-SO16 is named in `ad1`, which writes the pin: a bad write of `.roc-version` shows in the tree diff. The `.roc-version` file is not in the fixture (a file that names another id would test rank 5, which P0 does not have: Q30) | A `.roc-version` in the fixture |
| D3 | R-NM11 gets a new L2 case: the mode is part of the case environment, so the interactive half needs its own case | A mode switch inside a case |
| D4 | R-OV2 is 2 runs in `ld-ladder-flow` (same fixture as `update json`) | A new case |

## Out of scope

| Rule | Reason |
| --- | --- |
| R-SO5, R-SO18 | P1: R-PH6 lists ranks 1 to 4 for P0 and `TESTING.md` 7.4 puts them in P1. Confirm in Q30 |
| R-EV5, R-SO2, and the `ROC_TOOLCHAIN` part of R-SC12 | Q28 |
| The `roc:` pin part of R-SC12 | Q29 |
| R-SE9, the `tar` part | P1 (compilers and Zig: R-CV4, R-HF5) |
| W8 | Code task, not a test (see "Notes for the code agent") |

## Questions (TW17)

| # | Question | Default (no test uses it) |
| --- | --- | --- |
| Q28 | Does P0 read `ROC_TOOLCHAIN`? R-PH6 says ranks 1 to 4 can select the `roc` on `PATH` by its id, so rank 2 could be P0. But R-BL3 says that `install`, `add`, `update` and `remove` use the held pin for the baseline, so rank 2 has an effect only when there is no header pin. What does `tln install` do with no pin and `ROC_TOOLCHAIN=<other id>`: exit 13 (R-PH7, another compiler)? And with the id of the `roc` on `PATH`: is the pin written that id? Also the full-id rule of R-SC12 for the variable | P1. P0 ignores the variable (as built). No test |
| Q29 | A `roc:` pin that is not a full id (`nightly-2026-10`): R-SC12 says "error". Which exit code: 19 (`input`, a header value of the wrong form, like `[toolchain] roc`), 2 (`usage`) or 10? Today `install --frozen` finds nothing, and a probe stops with exit 13 (the id is "not installed"). I checked it by hand with the built binary | None. The user answers first |
| Q30 | R-SO18 (the `.roc-version` warning in `install` and `ls`) needs no download. Is it P0 or P1? R-PH6 and `TESTING.md` 7.4 say P1 for rank 5 | P1 (out of scope) |
| Q31 | `TALON_NIGHTLY` with a value other than `0` and `1`: the code accepts `false` and `true` and ignores other text without a warning. R-EV4 lists `0` and `1` | `0` and `1` only are tested |
| Q32 | No `roc:` pin, and the `roc` on `PATH` is outside `[toolchain] roc` (R-SO4, R-SO13), or is a nightly with the switch off (R-NS2, R-NS3). `Pin.decide` checks a pin only: with no pin it gives `held = compiler` and no `outside`. R-SO13 says "a required download", which P0 refuses with exit 13 (R-PH7). Is that P0? R-RP3 would also write a nightly pin that R-NS5 calls outside | No test. As built: no check |
| Q33 | `config.toml` settings `nightly` (R-NS10), `min-release-age` and `strategy` (R-C7): P0 reads only `registry` from `config.toml` (`Net.roc`). R-LY4 and R-C7 name `config.toml` as a source. Is the rest P0 or P1 (CLI 6.1)? R-NS10 is not in the audit of slice 011 and has no test | P1. No test |

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | R-DI12 and R-AD37 (the red test): `tln add acme/util --offline` with no cached page must stop with exit 15. Today `PickFlow` takes the source `Missing` of `Github.releases!` as "no candidates", so the command stops with exit 2 `no release of acme/util matches 'latest'`. R-DI12: "A new group with no cached page (`tln add`) fails with exit code 15" (`Github.releases!` says "the command decides: R-DI11 or R-DI12"). R-DI11 (a host with no index) keeps its behavior. The expected text is in the proposals above. `PickFlow.roc:361` is the call |
| 2 | W8 (slice 011 review): `Why.not_in` is a dead branch. `Lookup.find` with the scope `Project` never gives `New`, so the text cannot be reached. Remove the branch, or keep the `match` exhaustive in another way. No test changes |
| 3 | P8 and P9 pass today: they were gaps of the tests, not bugs of the code |

## Red output (2026-10-21, `scripts/test.sh`, pinned roc)

| Step | Result |
| --- | --- |
| `check`, `fmt`, `l0`, `l2`, `selftest` | pass |
| `l3` | 1 failed: `add/ad1-add-entries`. Stdout: `exit 15` expected, `exit 2` actual. Stderr: expected `error[network]: the index of acme/util has no cached page and --offline is set...`, actual `error[usage]: no release of acme/util matches 'latest'.` (the right reason: Note 1). 25 pass, 1 skipped |

All other new rows and runs pass today: they name rules whose code exists (gap tests, as `closuregaps` of slice 011). The revert check shows that each one fails when the code is wrong.

## Revert check (TW12)

`research/slice-012-revert/mutate.py` (11 rows, results in `research/slice-012-revert/results.md`). Each row is one small change in `cli/lib`, put back after the run. `cli/` after the run equals the copy before it (`code-before.sha256`, checked with `sha256sum` and `diff`).

| Id | Rule | Mutation | Result |
| --- | --- | --- | --- |
| P8 | R-OV1 | `add_below` tests the URL, not the group | caught by L0 `pickclosure` |
| P9 | R-DT2 | the deps are read in reverse order | caught by L0 `pickclosure` |
| P9s | R-DT2 | the deps are sorted | caught by L0 `pickclosure` (the reverse row) |
| LF5 | R-LF5 | `--locked` is a known flag of the resolving commands | caught by L3 `fl12-bad-flags` |
| E1 | R-EV4 | `TALON_NIGHTLY=0` is not read | caught by L3 `vf1-verify` |
| E2 | R-NS8 | the environment has no priority over `talon.toml` | caught by L3 `vf1-verify` |
| O2 | R-OV2 | the keys of `[overrides]` give no range | caught by L2 `ld-ladder-flow` (run 8) |
| S16 | R-SO16 | the write of the header also writes `.roc-version` | caught by L3 `ad1` (the tree diff). `ad1` is red for Note 1, so the row counts only when the output names the tree |
| N11 | R-NM11 | an invalid alias asks a question before it fails | caught by L2 `nm11-alias-stops` |
| SC12 | R-SC12 | `>=` accepts a prefix | caught by L0 `intent` |
| A37 | R-AD37 | `add` ignores `--offline` | caught by L3 `ad1` (stdout and stderr). The first run of the script used a wrong needle (the request log has the same first line) |

Not mutated: R-SO3, R-SO4, R-SO14, R-SE1, R-SE3, R-SE9 (names only: the tests exist and were checked in earlier slices), and run 9 of `ld-ladder-flow` (the code path of run 2 of the case).

## Final list of the P0 ids that have no test

Command: `MISSING=1 scripts/rules.sh R-H R-I R-C R-RP R-E R-EC R-J R-OUT R-NR R-NM R-PD R-DI R-WS R-TF R-VA R-SP R-LF R-DT R-AL R-OV R-LD R-BL R-BS R-RC R-SL R-SC R-AD R-RV R-RG R-LY R-FE R-CM R-FL R-EV R-NI R-SO R-HF R-DA R-CR R-ID R-PK R-PL R-GA R-CF R-PH R-SE R-CC R-NS R-LB R-UP R-P R-PP` lists 150 ids (the P0 groups of `TESTING.md` 7.4, and the groups of slices 005 and 009). The 13 ids of this slice are covered: R-EV4 R-SC12 R-SO3 R-SO4 R-SO14 R-SO16 R-SE1 R-SE3 R-SE9 R-AD37 R-NM11 R-LF5 R-OV2. R-EV5, R-SO2, R-SO5, R-SO18 stay open (reasons above). All of the 150:

| Reason | Ids |
| --- | --- |
| P1 (compiler manager, proxy, `upgrade`, probes, tools, cache) | R-SO5 R-SO18 (rank 5, manager answer Q30), R-AL4 R-AL5 R-LD2 R-LD3, R-CC8 R-CC9 R-CC10, R-CM1 R-CM5 R-CM6 R-CM8 R-CM10 R-CM15 R-CM16 R-CM17 R-CM18, R-EV6 R-EV7 R-EV11 R-EV16 R-EV17 R-EV21, R-HF2 R-HF6 R-HF9 R-HF10 R-HF11, R-ID6, R-NI4 R-NI6 R-NI7 R-NI8 R-NI9 R-NI10 R-NI12 R-NI13 R-NI14, R-NR3, R-PD7 R-PD15 R-PD16 R-PD17, R-PH3, R-PK6, R-RP4, R-SC10 R-SC11 R-SC13, R-SE8 R-SE11 R-SE12 R-SE13, R-SO1 R-SO6 R-SO8 R-SO12 R-SO13 R-SO15 (no global default and no download in P0: R-PH6, R-PH7), R-SP6 R-SP7 R-SP8 R-SP9 R-SP12 R-SP13, R-WS13, R-NS2 R-NS3 R-NS6 R-NS12 (the switch applies where Talon selects a compiler), R-LB3, R-P4 R-P5 R-P8, R-PP1 R-PP2 R-PP4 R-PP6 R-PP7, R-UP1 to R-UP10 R-UP12 R-UP13 (`upgrade`, probes) |
| P2 or P3 (registry, share, publish, audit) | R-AD3 R-AD4 R-AD5 R-AD34 R-AD35 R-AD36, R-CM13 R-CM14 R-CM21 R-CM22 R-CM23, R-E6 R-J7, R-EV26, R-GA2, R-ID7, R-NI16, R-PH4 R-PH5, R-PL2, R-RG4 R-RG5 R-RG6, R-SE2 R-SE5 R-SE6 R-SE10 R-SE14 R-SE15 R-SE16 |
| Not a testable rule here (explanation, table, other repository, other runner) | R-CF1 R-FE9 (L5), R-GA1 R-GA3 R-GA4 R-GA5 R-GA6 R-GA7, R-HF7 R-HF8, R-PK1 R-PK2 R-PK3 R-PK4 R-PK5 R-PK7, R-PL1, R-PH1 R-PH2, R-OUT3, R-LY8 R-LY9 (Windows CI), R-EV10 R-NI15 (`install/test.sh`), R-NI11 (removed) |
| Open question, no test (TW17) | none (second pass: Q28, Q29, Q32, Q33 are answered and tested; `strategy` in `config.toml` is not named by the design, so it has no test) |

R-NS10 was not in the audit of slice 011. After the second pass the same command lists 144 ids (150 before). New names: R-EV5 R-SO2 R-NS10 R-SO13 R-NS3 R-SC12 R-PH7 R-EC13 R-SO4 R-C7 R-LY4 (checked with `MISSING=1 scripts/rules.sh`). R-SO5 and R-SO18 are P1 (manager answer Q30) and stay in the list.

## Next step

The human reviews the 5 new rows, the 7 new runs, the new case, the output proposal and the second pass below. Then the code agent: Notes 1 and 2 (R-DI12 exit 15, W8) and Notes 4 to 8 of the second pass.

## Review (manager, 2026-10-21)

The decisions are accepted. The bug that the red test found (`add --offline` with no cached page gives exit 2, R-DI12 needs exit 15) is for the code agent. W8 is for the code agent. The answers below come from the design where it decides. The others are proposals of the manager, not confirmed by the user.

| # | Answer | Source |
| --- | --- | --- |
| Q28 | P0 reads `ROC_TOOLCHAIN`. R-PH6: ranks 1 to 4 can select the `roc` on `PATH` when they name its id, and rank 2 is `ROC_TOOLCHAIN` (R-SO2). Its id is the `roc` on `PATH`: no change. Another full id: refused as R-PH7 (exit 13). A prefix: error (R-SC12), exit 2, as a bad `TALON_NOW` (slice 001 Q5). | Design |
| Q29 | A prefix in the `roc:` pin is exit 19: R-EC19 names "a known key with a value of the wrong form" and "a project header" | Design (R-EC19) |
| Q30 | P1. R-SO5 and R-SO18 are rank 5 (`.roc-version`), and R-PH6 names ranks 1 to 4 only. | Design (R-PH6) |
| Q31 | The same rule as `TALON_INTERACTIVE` (slice 001 Q11): another value counts as not set | Manager |
| Q32 | A bug. With no pin, a `roc` on `PATH` that is not in the `[toolchain] roc` range, or a nightly with the switch off, needs another compiler: R-SO13 makes it a required download, and P0 refuses it as R-PH7 (exit 13). | Design (R-SO13, R-PH7) |
| Q33 | P0 reads `nightly` from `config.toml` (R-NS10, rank 3 of the switch), because P0 has the switch (R-EV4 is tested). For `min-release-age` and `strategy` in `config.toml`: read them only if the design names them as `config.toml` keys. Else nothing. | Design (R-NS10) |

## Second pass: tests for the answers of the review (2026-10-21)

Budget: 8 new runs (6 in L3, 2 in L2) and no new case. Pre-slice copies of the changed files: `research/slice-012-revert/before2/` (with `NEW.txt`). No file of `cli/` or of the design was changed. The reference that I used for the revert check is deleted.

### Tests

| Layer | File and run | Rule ids | Q |
| --- | --- | --- | --- |
| L3 | `verify/vf1-verify` run 1: `ROC_TOOLCHAIN=<id of the roc on PATH> tln verify --no-check`: exit 0, same output as without the variable (green today: the variable is ignored) | R-SO2 R-EV5 R-PH6 | Q28 |
| L3 | `vf1-verify` run 2: `ROC_TOOLCHAIN=nightly-2026-10-09-258ab27`: exit 13, kind consent, text of `Compiler.require` (the unit test `compiler.roc` fixes it) | R-PH7 R-EC13 | Q28 |
| L3 | `vf1-verify` run 3: `ROC_TOOLCHAIN=nightly-2026-10`: exit 2, `ROC_TOOLCHAIN is not a full compiler id: nightly-2026-10` | R-SC12 | Q28 |
| L3 | `vf1-verify` run 4: the `roc:` pin of `main.roc` is `nightly-2026-10-14`: exit 19, `$PROJECT/main.roc:5: the roc pin nightly-2026-10-14 is not a full compiler id` | R-SC12 R-EC19 | Q29 |
| L3 | `vf1-verify` run 5: `nightly = false` in `config.toml`, a nightly pin: exit 10, the text of `Pin.outside_failure` | R-NS10 R-NS5 | Q33 |
| L3 | `vf1-verify` run 6: `min-release-age = "0d"` in `config.toml`: json 2.2.0 (1 day old) is the newest, not 2.1.0 | R-C7 R-LY4 | Q33 |
| L2 | `resolve/rs-no-compiler` run 3 (`range/`): no pin, `[toolchain] roc = ">=nightly-2026-10-20-aaaaaaa"`, the roc on PATH is older: exit 13 before the index | R-SO13 R-SO4 R-PH7 R-EC13 | Q32 |
| L2 | `rs-no-compiler` run 4 (`off/`): no pin, the roc on PATH is a nightly, `nightly=false`: exit 13 | R-NS3 R-PH7 R-EC13 | Q32 |

The new L3 runs go after the dump of the roc calls: they use `--no-check`, so they call only `roc version`, and the `rm` of `roc.log` is now the last step. The L3 runs write `config.toml` in `$XDG_CONFIG_HOME/talon` and remove it.

### Output proposals (TW24)

| Item | Text |
| --- | --- |
| Prefix in `ROC_TOOLCHAIN` | `tln: error[usage]: ROC_TOOLCHAIN is not a full compiler id: <text>` (as the text for a bad `TALON_NOW`) |
| Prefix in the `roc:` pin | `tln: error[input]: <file>:<line>: the roc pin <text> is not a full compiler id` |
| Another full id in `ROC_TOOLCHAIN` | The text of `Compiler.require` (exit 13) |
| No pin, the roc on PATH outside `[toolchain] roc` | `tln: error[consent]: the roc on PATH, <id>, is outside [toolchain] roc (<range>). This version of tln runs only the roc on PATH, so it cannot select another compiler.` |
| No pin, a nightly on PATH, the switch off | `tln: error[consent]: the roc on PATH, <id>, is a nightly, and nightly is false (TALON_NIGHTLY or [toolchain] nightly). This version of tln runs only the roc on PATH, so it cannot select another compiler.` |

### Red output (2026-10-21)

| Run | Result with the current `cli/` |
| --- | --- |
| L3 `vf1-verify` | Run 1 passes. Runs 2 to 5 give exit 0 (expected 13, 2, 19, 10): the variable, the pin form and `config.toml` are not read. Run 6 gives json 2.1.0 (expected 2.2.0). The 4 error lines are missing. The rest of the case is unchanged |
| L2 `rs-no-compiler` | Runs 3 and 4 print `nothing to change`, exit 0 (expected exit 13). The 2 error lines are missing. The calls continue to `random` and the package check |

### Revert check against a private reference (TW12)

I made a copy of `cli/` and `tests/` in `research/slice-012-ref/` and put the minimum code in it: `ROC_TOOLCHAIN` in `Verify.flow!`, the pin form and the `config.toml` merge in `ResolveBase.load!`, the no-pin refusal in `ResolveBase.prepared!`. Both cases passed against the reference (L2 only after I recorded its extra `config.toml` read, see Q35). Then each mutation below was put in the reference, and the case ran. The reference is deleted.

| Id | Rule | Mutation of the reference | Result |
| --- | --- | --- | --- |
| M1 | R-SO2 R-EV5 | the id of the roc on PATH is refused too | caught by `vf1-verify` (stdout, stderr) |
| M2 | R-PH7 | another full id is not refused | caught by `vf1-verify` |
| M3 | R-SC12 | a prefix in `ROC_TOOLCHAIN` is not an error | caught by `vf1-verify` |
| M4 | R-SC12 R-EC19 | a prefix in the `roc:` pin is not an error | caught by `vf1-verify` |
| M5 | R-NS10 | `nightly` of `config.toml` is ignored | caught by `vf1-verify` |
| M6 | R-C7 | `min-release-age` of `config.toml` is ignored | caught by `vf1-verify` (stdout) |
| M7 | R-SO13 | a PATH roc outside the range is accepted | caught by `rs-no-compiler` (stdout, stderr, calls) |
| M8 | R-NS3 R-PH7 | a PATH nightly with the switch off is accepted | caught by `rs-no-compiler` (stdout, stderr, calls) |

The first try of M3 to M6 did not build (the compiler refuses a condition that is known at compile time): the conditions were rewritten with a value that is known only at run time. `cli/` equals `code-before.sha256` after the run.

### Not tested, with the reason

| Item | Reason |
| --- | --- |
| `strategy` as a key of `config.toml` | The design does not name it there. The example of R-LY4 and the rule R-C7 list `nightly` and `min-release-age`. R-TF4 says "an unknown `strategy`" for `talon.toml` or `config.toml` in general. Q36 |
| The order `talon.toml` over `config.toml` (R-NS9 over R-NS10, R-C7) | The budget. One more run in `vf1-verify` would do it (`[toolchain] nightly = true` with `nightly = false` in `config.toml`) |
| `TALON_NIGHTLY` over `config.toml` (R-NS8) | The same |
| Q31, other values of `TALON_NIGHTLY` | The manager rule is the same as for `TALON_INTERACTIVE`. The code accepts `true` and `false` today: a code task, no test |

### New questions (TW17)

| # | Question | Default |
| --- | --- | --- |
| Q34 | R-NS2 says: the switch off, the domain of `roc` is the releases, and that domain is empty today, so a command that must select a compiler stops with exit 10 (`no_tuple`). The manager answer for Q32 gives exit 13 (R-PH7) for a PATH nightly with the switch off and no pin. These two rules give different codes. The run 4 of `rs-no-compiler` uses exit 13 as the manager said | Exit 13 (as tested). If R-NS2 wins, run 4 expects exit 10 and the text of `Pin.outside_failure` |
| Q35 | Reading `config.toml` is a new `Fx` call (or a new path in an existing call) in each command. The `calls.log` of every L2 case then changes by that one line. The code agent does not edit tests (TW18). Who records them? My proposal: the test agent runs `UPDATE=1 tests/commands/run.sh` after the code is green, and the human reviews the diff, which must hold only the `config.toml` line. The same for the text of the nightly failure: it names `TALON_NIGHTLY or [toolchain] nightly` and not `config.toml` (the new run 5 expects the text as it is) | As described |
| Q36 | Is `strategy` a key of `config.toml`? R-TF4 can be read so. The design example (CLI 6.1) and R-C7 do not list it | No: not read, not tested |

### Notes for the code agent (continued)

| # | Note |
| --- | --- |
| 4 | `ROC_TOOLCHAIN` (R-SO2, R-EV5): a value that is not a full compiler id is exit 2 (Compiler.kind `Local`, in the reference). A full id other than the roc on PATH is `Compiler.require`, exit 13. The id of the roc on PATH changes nothing. The new L3 run 2 and 3 fix the texts. The commands that use a compiler read it: `verify` is tested, the others should use the same function |
| 5 | The `roc:` pin form (R-SC12, R-EC19): a pin that is not a nightly tag and not a release version is exit 19 with `<file>:<line>:` and the text above. The check is in the load of the header, so each command that reads the header has it |
| 6 | `config.toml` (R-NS10, R-C7, R-LY4): read `nightly` and `min-release-age`. Priority from high to low: flag or environment, `talon.toml`, `config.toml`, the default. Only the first two are tested (run 5 and 6 of `vf1-verify`). The test does not fix where the read happens (Q35) |
| 7 | No pin and a PATH roc that the range or the switch does not admit (R-SO13, R-PH7): exit 13 before the index call, and before any write. `Pin.decide` checks a pin only, so the reference put the check in `ResolveBase.prepared!`. The signature of `Pin.decide` is your choice: no test names it |
| 8 | The first green run changes the `calls.log` of all L2 cases by the `config.toml` read (Q35). Do not edit them: report the diff |

## Review of the second pass (manager, 2026-10-21)

| # | Answer | Source |
| --- | --- | --- |
| Q34 | R-NS2 wins for the switch: with the switch off and no pin, the domain is empty, so exit 10 (`no_tuple`), and the error names the switch and its source (for example `config.toml`). The Q32 answer (exit 13) stays for a `roc` on `PATH` outside the `[toolchain] roc` range. The code agent changes run 4 of `rs-no-compiler` to exit 10, and the nightly-off texts to name the source, as dispute rows that cite R-NS2. | Design (R-NS2) |
| Q35 | The code agent reads `config.toml` in a call that exists, if it can. If each L2 `calls.log` must get one new line, the code agent may add only that line to the expected files, as one dispute row that lists the cases. The manager reviews the diff. | Manager |
| Q36 | No `strategy` key in `config.toml` in P0. R-TF4 names `strategy` only as an example of a bad value. | Manager |

## Code (code agent, 2026-10-21)

| Item | Code |
| --- | --- |
| R-DI12 (Note 1) | `PickFlow.prepare!`: a candidate list with `missing` stops with `Github.no_page_failure` (kind `Network`, exit 15) |
| W8 (Note 2) | `Why.find`: the branch `New(name) => Err(not_in(name))` is gone. `New` gives a key that no entity has, so the one `not_in` of the row lookup answers |
| `ROC_TOOLCHAIN` (Q28, Note 4) | `Compiler.toolchain_of` (a prefix: exit 2), `Compiler.select` (another full id: `Compiler.require`, exit 13), `Install.compiler!` for `install`, `update`, `remove`, `verify` |
| `roc:` pin form (Q29, Note 5) | `Locked.read`: a pin that `Pin.is_id` refuses is exit 19 with the line (`Pin.is_id` is new) |
| `config.toml` (Q33, Note 6) | `Intent.read_config` (keys `nightly` and `min-release-age`, unknown key: warning, wrong form: exit 19). `ResolveBase.load!` reads it in the same `read_files!` call as the headers (the path is the last one). `settings_of` takes `Loaded` and gives `nightly_from`. Priority: environment, `talon.toml`, `config.toml`, default |
| PATH roc, no pin (Q32, Q34, Note 7) | `Pin.gate`, called by `ResolveBase.check_pin` when `Pin.Decision.pinned` is false (new field): the switch off and a nightly is exit 10 (R-NS2), a range that does not admit it is exit 13 |

## Disputes (from the code agent)

| # | Test | Change | Design source |
| --- | --- | --- | --- |
| 1 | `tests/commands/cases/resolve/rs-no-compiler`, run 4 (`expect/stdout`, `expect/stderr`, `rules`) | exit 13 becomes exit 10 (kind `no_tuple`). The text names the switch and its source: `the roc on PATH, <id>, is a nightly, and nightly is false (set by TALON_NIGHTLY). No roc release is known, so no compiler can be selected.` | R-NS2, manager answer Q34 |
| 2 | `tests/unit/pin.roc` (the `outside_failure` row) | `Pin.outside_failure` has a `source` field. The row passes one, and the expected text is `(set by nightly in config.toml)` instead of `(TALON_NIGHTLY or [toolchain] nightly)` | R-NS2, Q34 |
| 3 | `tests/scenarios/verify/vf1-verify/expect/stderr` (3 lines, runs 1, 2, 5 of the nightly switch) | The text names the source: `set by TALON_NIGHTLY`, `set by [toolchain] nightly in talon.toml`, `set by nightly in config.toml` | R-NS2, Q34 |
| 4 | `expect/calls.log` of 23 L2 cases: closure/cl1-flow cl2-chain, gaps/g1-slice009, install/in1-flow, ladder/ld-ladder-flow ld-no-check-refuse, prompt/nm11-alias-stops, remove/rm1-flow, resolve/rs-failures rs-frozen rs-highest-use rs-install-add-key rs-install-names rs-member-root-table rs-new-toml rs-no-compiler rs-stale-key rs-stale-key-ask rs-update-scope rs-want-platform rs-workspace-shared-group, update/up1-flow, verify/vf1-flow | The `read_files` line of the load (headers and `talon.toml`) has the path ` $HOME/.config/talon/config.toml` at its end: 89 lines, no other change (checked with `sed` against the copy before) | Q35 (the read is in a call that exists, so a line changes and no line is new) |

`Frozen.check` text (`the roc pin <pin> is a nightly, and nightly is false`) has no source. No test asks for one, so it is not changed.

## Verify results

`research/slice-012-revert/code-mutate.py` (25 rows), results in `research/slice-012-revert/code-results.md`. `cli/` after the run equals `research/slice-012-revert/code-green-cli/` (`diff -r`). The copy of `cli/` before this slice is `code-before-cli/`.

| Result | Rows |
| --- | --- |
| Caught (20) | D1 D2 D3 (R-DI12, `ad1`), T1 T2 T3 T4 (`ROC_TOOLCHAIN`, `vf1`), P1 P2 (pin form and line, `vf1`), N1 N2 N4 N5 (switch priority and source text, `vf1`), C1 C2 C3 (`config.toml`, `vf1`), G1 G2 G3 G4 (PATH roc gate, L2 `rs-no-compiler`) |
| Not caught (5) | N3: `talon.toml` over `config.toml` (the order of R-NS9 and R-NS10 has no test). G5: the gate also for a header that has a pin. F1: `ROC_TOOLCHAIN` with another id in `--frozen`. I1: `ROC_TOOLCHAIN` in `install` (only `verify` has a run). W1: the row lookup of `Why.find` (the branch of W8 cannot be reached, so no input shows it) |

Status: verify.

## Review of the code (manager, 2026-10-21)

`scripts/test.sh` passes (manager run: l0 11.5 s, l2 39.2 s, l3 9.2 s). The 4 dispute rows are accepted. Row 4 is checked: the code agent's change in the `calls.log` files is only the path `$HOME/.config/talon/config.toml` at the end of `read_files` lines. The revert check caught 20 of 25. Open for a follow-up (no test yet): N3 (`talon.toml` over `config.toml` for `nightly`), G5 (the PATH gate with a pin in the header), F1 (`ROC_TOOLCHAIN` with `--frozen`), I1 (`ROC_TOOLCHAIN` in `install`, `update`, `remove`). W1 cannot be reached.
