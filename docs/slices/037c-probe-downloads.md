# 037c Optional compiler downloads of `tln probe --range`

Phase: P1. Status: done

Slice 037c is the plan row 037c of `PLAN-P1.md`. It needs 037 (done). It adds the download branch of R-NI4 to the range search of `tln probe --range`: the opt-in (`--probe-downloads`, or `--yes` inside the cap R-DL6), the compiler list D with the cap, the line `skipped N compiler downloads` (R-DL4), `probe.max-toolchains = 0`, and the share of the budget `probe.max`. The one-prompt question U5 is tested as reading (c) of the manager. The resolve commands (036c) have no producer of optional downloads in P1, so they are split to a later slice 037d (section 1, Q8).

The private reference has about 180 lines of code (without comments and empty lines): `Consent` 61, `ProbeSearch` 111, `ProbeCmd` 10. The row said about 250. No split is needed for the part in this file. The reference was deleted at the review (2026-10-24) with `swap.sh`. `mutate.py` needs it, so it cannot run again. Its log stays.

## 1. Scope and split

| Item | Where | Rule | In this slice |
| --- | --- | --- | --- |
| The decision: no download, skip with a line, or download (the opt-in) | `Consent.optional_want` | R-NI4, R-DL4, R-DL5, R-DL6, R-NM8 | yes |
| The downloads of one round: installed ids cost nothing, the cap that is left, the dropped ids | `Consent.optional_round` | R-DL1, R-DL6, R-P5 | yes |
| The texts: skipped line, answer line of a download, failed download, cap note | `Consent.optional_skipped`, `optional_line`, `optional_failed`, `optional_capped` | R-DL4, R-NM6, R-P3, R-DL6 | yes (TW24) |
| Phase 2 of the search: D with all allowed candidates, downloads before the probes | `ProbeSearch.run!` | R-PB3, R-PB4, R-P5, R-AL4, R-NS3, R-C7 | yes |
| `data.downloads` of a range | `ProbeCmd.Shown`, `ProbeCmd.data` | R-J3, R-OUT4, 025 Q7 | yes |
| The resolve commands (`update`, `install`, `upgrade`, `verify`): which probes on other compilers, which releases of D first | none | R-DL1, R-DL6, R-NI4, R-RP2 | no: slice 037d, question Q8 |
| One prompt with a required download and optional downloads | none | R-DL1, R-NI4, R-NI5 | the pure rule only (Out 1) |

## 2. Rules

| Rule | Tested by |
| --- | --- |
| R-NI4 (the opt-in: `--probe-downloads`, `--yes`; the default is no download) | L0 `consent.roc` `optional_want` (11 rows). L2 `probe/pd1-downloads` runs 1 to 5 |
| R-DL4 (the line `skipped N compiler downloads (<size>), pass --probe-downloads`) | L0 `consent.roc` text rows. L2 `pd1-downloads` runs 1, 2, 4. `pc2-range` runs C, D, E (changed, section 8) |
| R-DL5 (`--yes` accepts. `--allow-downloads` and `TALON_AUTO_INSTALL` do not answer an optional download) | L2 `pd1-downloads` runs 3 (variable `no` does not veto), 4 (variable `yes` and `--allow-downloads` do not opt in), 5 (`--yes`) |
| R-DL6 (the cap `probe.max-toolchains`: 1 allows one download, 0 offers nothing, a failed try counts) | L0 `optional_round` (10 rows). L2 `pd1-downloads` runs 6, 7, 10 |
| R-DL1 (one answer for the command, with the count and the size) | L0 `optional_skipped`, `optional_line`. L2 `pd1-downloads` (no `tty` and no `ask` call in any run). The prompt of a required download is `Consent.command_download` of 025, unchanged |
| R-NM6, R-NM8 (an answer with no prompt prints its line. `--yes` is yes to a prompt with the default No) | L0 `optional_line`, `optional_want`. L2 `pd1-downloads` runs 3, 5 |
| R-P5 (`probe.max` counts probes. A download is for a probe that can start. Installed compilers first) | L2 `pd1-downloads` run 9 (no room: no download), runs 1 and 3 (phase 1 first). L0 `optional_round` |
| R-P3 (a download error gives no fact) | L2 `pd1-downloads` runs 8, 10 |
| R-PB3, R-PB4 (the range: an unknown end becomes a real end after the download. Else exit 12) | L2 `pd1-downloads` runs 3, 5 (exit 0), 6, 7, 8, 9, 10 (exit 12) |
| R-HF1 (no terminal test when it is not needed) | L0 `optional_want` (`NeedsTty` rows). L2 `pd1-downloads` (no `tty` call) |
| R-EC12, R-J5, R-J3, R-OUT4 | L2 `pd1-downloads` runs 3, 8 (`--json`: `data.downloads`, `error.details.downloads`). L0 `probecmd.roc` expect 6 |
| R-NI5, R-DL2 (a required download) with an optional one in one prompt | out of scope (Out 1) |

## 3. Public signatures (stubs in `cli/lib/`)

| Name | Signature | File |
| --- | --- | --- |
| `Consent.optional_want` | `{ count : U64, mode : Mode, yes : Bool, flag : Try(Answer, [NoFlag]) } -> [Nothing, Skip, Download]` | `cli/lib/Consent.roc:350` |
| `Consent.optional_round` | `{ ids : List(Str), installed : List(Str), left : U64, sizes : List({ id : Str, size : U64 }) } -> { asked : List(Str), fetch : List({ id : Str, size : U64 }), dropped : List(Str), size : U64 }` | `cli/lib/Consent.roc:362` |
| `Consent.optional_skipped` | `{ count : U64, size : U64 } -> Str` | `cli/lib/Consent.roc:367` |
| `Consent.optional_line` | `{ id : Str, size : U64 } -> Str` | `cli/lib/Consent.roc:371` |
| `Consent.optional_failed` | `{ id : Str, text : Str } -> Str` | `cli/lib/Consent.roc:375` |
| `Consent.optional_capped` | `{ cap : U64, dropped : U64 } -> Str` | `cli/lib/Consent.roc:380` |
| `ProbeSearch.Run` | 4 new fields: `env : List((Str, Str))`, `flag : Try(Answer, [NoFlag])`, `yes : Bool`, `mode : Mode` | `cli/lib/ProbeSearch.roc` |
| `ProbeSearch.Found` | new field `downloads : U64` | `cli/lib/ProbeSearch.roc` |
| `ProbeCmd.Shown` | `Range({ node, found, probes, downloads : U64 })` | `cli/lib/ProbeCmd.roc` |
| `ProbeCmd.ranged!` | passes `env`, `flag`, `yes`, `mode` (done in the stub) | `cli/lib/ProbeCmd.roc` |

The stubs have the contract tables in their doc comments. The stub of `ProbeSearch.run!` is the body of slice 037 (phase 1 only, `downloads: 0`). The stub of `ProbeCmd.data` does not write the key `downloads`. The tables in the doc of `ProbeSearch` are the spec of phase 2.

## 4. The tested reading of the search

Phase 1 is the search of slice 037 (installed compilers only). It is the first, because R-P5 says that installed nightlies are tried first and R-AL4 says "installed nightly first". So the Fx calls of a run with no opt-in are the calls of slice 037, and only the stderr line is new. Phase 2 starts when phase 1 ended with no budget cut.

| Step of one round of phase 2 | Detail |
| --- | --- |
| 1 | `ProbeRange.step` with `askable` = all candidates that the switch and `min-release-age` allow (not removed). `Done`: the search ends |
| 2 | `Need(ids)`: `Units.budget` over the ids. `wanted` is the first `room.run`. No room: the search ends with the budget failure, and no download is made |
| 3 | `Consent.optional_round` with `wanted`, the installed ids, `left` = cap minus the tries so far, and the sizes of the list |
| 4 | `Consent.optional_want` with `count = fetch.len()`. `Nothing`: the search ends (cap note when the cap is above 0 and ids were dropped). `Skip`: the skipped line, the search ends. `Download`: step 5 |
| 5 | For each `fetch` id: `RocInstall.offer!`, the answer line, `RocInstall.install_offer!`. A failure is a warning line. The release gets no fact and is removed from `askable` |
| 6 | The probes of `asked` without the failed ids (the steps of phase 1), then the next round |

Example of the flow (run 3 of the case): D is n1 to n10. Installed: all but n2 and n4. The truth: json passes n5, n6, n7. Phase 1 gives the range n5 .. n7 with the lower end unknown (n4 is not installed). Phase 2: `Need([n4])`, one download, one probe (a fail), the lower end n5 is real, exit 0.

## 5. Tests

| Layer | File and case | Content | Rules | U5 |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/consent.roc` expect 13 (11 rows) | `optional_want`: count 0, the opt-in (flag, `--yes`) in each mode, no opt-in in each mode, no `tty` need | R-NI4 R-DL4 R-DL5 R-DL6 R-NM8 R-HF1 | rows 5, 6 (a person, the terminal not known: with reading (a) or (b) they give a prompt) |
| L0 | same, expect 14 (10 rows) | `optional_round`: installed ids, the cap exact, 1, 0, order, the sizes, an id with no size | R-DL1 R-DL6 R-P5 R-PP3 R-AL4 | |
| L0 | same, expect 15 (6 rows) | the 4 texts (skipped 1 and 2, answer line, failed, cap 1 and 3) | R-DL4 R-NM6 R-P3 R-DL6 | |
| L0 | `tests/unit/probecmd.roc` expect 5 and 6 | `Range` has `downloads` (changed rows, 1 new row: `data` with 2 downloads) | R-J3 R-OUT4 | |
| L2 | `probe/pd1-downloads` (new, 10 runs, entry `commands`) | The list below | R-NI4 R-DL1 R-DL4 R-DL5 R-DL6 R-NM6 R-NM8 R-PB3 R-PB4 R-P5 R-P3 R-HF1 R-EC12 R-J5 | runs 1, 5 |
| L2 | `probe/pc2-range` (changed) | runs C, D, E: the skipped line. Run E: `downloads: 0` in `error.details` | R-DL4 R-NI4 | default branch |

L0: `consent.roc` has 3 new expects (15 in all). `probecmd.roc` has 7 expects as before. No new unit file, so the l0 step has no new `roc test` process. Time of the unit files: `consent.roc` is 62 lines longer. The l0 step was 7.2 s in the green run (budget 10 s, 7.0 to 8.9 s before).

The case `probe/pd1-downloads` has the packages, the config and the 10 nightlies (n1 to n10) of `pc2-range`. The list has correct digests (the sha256 of the text `fake`, the file that the fake `curl` writes) and sizes of 73.1 MB (n1) to 74.0 MB (n10). Every home starts with n1, n3, n5 to n10 installed (n2 and n4 are downloads), except home6 (n10 only). Each home has its own db and its own list cache. The tree diff covers `home` and `project` only, so the runs in `home2` to `home6` show their effect in `calls.log` (lock, curl, `rename`, `delete` of the temp dir after a failure).

| # | Run | Shows |
| --- | --- | --- |
| 1 | `probe json --range`, a person, no flag | Phase 1 (8 probes). Phase 2 wants n4. The line `skipped 1 compiler download (73.4 MB), pass --probe-downloads`. No `tty` call and no `ask` call (U5 reading (c)). Exit 12 (R-PB4: lower end unknown) |
| 2 | the same with `CI=true` | The same line, the same exit. No probe (the facts are known) |
| 3 | `TALON_AUTO_INSTALL=no probe json --range --probe-downloads --json` | The variable `no` does not veto an optional download. The answer line, list, lock, `curl`, `tar`, `chmod`, `rename`, one probe on n4 (a fail). Lower end real, exit 0, `data.downloads` is 1 |
| 4 | `CI=true TALON_AUTO_INSTALL=yes probe parser --range --allow-downloads` | Neither answers an optional download: phase 1 (10 probes), the line for n2 (73.2 MB), exit 12 |
| 5 | `probe parser --range --yes`, a person | `--yes` is the opt-in: no prompt, n2 is downloaded and probed (a fail), lower end n3 real, exit 0 (U5) |
| 6 | `max-toolchains = 1`, parser2, home2 | Phase 2 wants n2 and n4. The cap allows 1: n2 (the first of the round). n4 is dropped. The note of the cap. Exit 12 |
| 7 | `max-toolchains = 0`, `--probe-downloads`, home3 | Nothing is offered: no line, no download, no note. Exit 12 |
| 8 | the download of n4 fails, `--json`, home4 | The answer line, then the warning. The temp dir is deleted and the lock is released. No fact for n4, no retry. Exit 12. `error.details.downloads` is 0 |
| 9 | `probe.max = 8`, `--probe-downloads`, home5 | Phase 1 uses all 8 probes. Phase 2 would need n4: no room for a probe, so no download and no `curl` call. Exit 12 with the budget text |
| 10 | `max-toolchains = 4`, every download fails, home6 (only n10 installed) | Phase 1: n10 fails (no pass). Round 1: n9, n8, n7, 3 tries. Round 2: n6 is tried (the cap that is left is 1), n5 and n4 are dropped. Round 3: no try (the cap is spent). 4 tries in all: a failed try counts. Result no pass, 9 releases with no fact, note: 5 downloads were not made. Exit 12 |

## 6. Output proposals (TW24, for the human review)

| Where | Text |
| --- | --- |
| Skipped (stderr, once, before the final output, no opt-in) | `skipped 2 compiler downloads (146.6 MB), pass --probe-downloads`. `skipped 1 compiler download (73.4 MB), pass --probe-downloads` for 1. The design text of R-DL4 with the singular for 1. The count and the size are those of the next round of phase 2 (Q2) |
| A download (stderr, before it starts, R-NM6) | `downloading <id> (<size>)` (the text of the answer line of 025) |
| A failed download (stderr) | `no download of <id>: <text of the failure>. The release has no fact and is not asked again.` |
| The cap (stderr, at the end of phase 2, only when the cap is above 0 and ids were dropped) | `probe.max-toolchains is 4 and 5 compiler downloads were not made. Set probe.max-toolchains higher.` (`1 compiler download was not made`) |
| The failure of exit 12 | no change: `the range has 1 end that is not a real fact (unknown): no installed compiler can show it. Run tln roc install for more compilers.` stays with the opt-in (Q10) |
| `--json` `data` of a range | new key `downloads` after `probes`: the number of compilers that the search downloaded (as `data.downloads` of slice 025, Q7). It is in `error.details` for exit 12 |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | One prompt for a required download and optional downloads | No P1 command has both. `--range` has no required download (it skips `Start.run!`, slice 037). The resolve commands have a required download but no producer of optional ones (Q8). The pure part is tested: `Consent.command_download` of 025 counts the required downloads only, and `optional_want` has no prompt. Slice 037d |
| Out 2 | The resolve commands (`update`, `install`, `upgrade`, `verify`) | Q8 |
| Out 3 | A `--range` with no installed compiler (R-FE4 rule 4: a required download to unbundle or to fetch) | The command fails with `Compiler.failure(NoCompiler)` as in slice 037. The design does not say which compiler is selected for `--range` |
| Out 4 | `Present` after `offer!` (another process installed the compiler in between) | A race. The code treats the id as installed and does not count it for the cap. Not tested |
| Out 5 | `--offline` with the opt-in | Not tested (Q9) |
| Out 6 | The default compiler after an optional download (Q7) | The same code as a required download (R-SO15). Not tested: the fixture sets `default-roc` |

| Id | Question | Options (tested reading first) |
| --- | --- | --- |
| Q1 | Which releases are downloaded first? The design says only "consent never goes past the cap" | (a) The order of the `Need` of `ProbeRange.step` (the newest 3 above the pass, newest first; else the quartile places, oldest first), after all installed compilers (phase 1). Run 6: cap 1 downloads n2, which does not help the end n5. (b) The releases nearest to an unknown end first (run 6 would download n4). (c) Newest first in D |
| Q2 | What do N and the size of the skipped line count? | (a) The downloads of the next round of phase 2 (run 1: n4 only). (b) All allowed releases that are not installed and have no real fact, up to the cap (run 1: n2 and n4, and n2 is below a real fail, so no search asks it) |
| Q3 | How does a failed download count? R-P3 says only "a download error gives no fact" | (a) A warning, no fact, the release is not asked again, the try counts for the cap, the search goes on, and the exit code is that of the range (run 8, run 10). (b) The command fails with the exit code of the failure kind (15 network, 16 integrity). (c) As (a), but the try does not count for the cap (run 10 would try 9 times) |
| Q4 | Budget: how do the downloads share `probe.max`? | (a) A download is not a check. `probe.max` counts probes only. A download is made only for a probe that can start in the budget (run 9). `probe.max-toolchains` counts the tries (run 10). (b) A download counts as a check |
| Q5 | Do `TALON_AUTO_INSTALL` and `--allow-downloads` have an effect on optional downloads? | (a) No. R-DL5 says `yes` accepts only required downloads and that `--allow-downloads` answers R-NI5. `no` refuses each required download, so it does not veto an optional one either (run 3, run 4). (b) `no` refuses all downloads, also with `--probe-downloads` |
| Q6 | U5: a person with no opt-in. R-NI4 gives the interactive default No, which reads as a prompt | (a) One prompt lists the required and the optional downloads, one answer for both. (b) Two prompts. (c) No prompt for an optional download in any mode: the opt-in is the flag, `--yes` or nothing, and the line shows in both modes (tested: L0 rows 5, 6, L2 runs 1, 5). The manager recommends (c). With (c) R-NM3 holds: a prompt that does not exist does not differ between the modes |
| Q7 | Does an optional download become the default compiler when none is set? | (a) Yes, as R-SO15 says for the first compiler that Talon installs (the same code as a required download). (b) No. Not tested: the fixture sets `default-roc`, so `config.toml` does not change |
| Q8 | The resolve commands: with the opt-in, which probes on other compilers produce an optional download? R-RP2 says the error names "the oldest nightly that works, when a probe or the matrix knows it". Slice 036c only reads known facts | (a) A slice 037d: after a failure on the held compiler, the same loop runs on compilers of D (phase 2 of this slice), to find the oldest compiler that works. It needs a nested oracle loop for each compiler: about 300 lines, with its own design question (which compiler first, which unit facts are enough). (b) Only the probe on the failing releases, no hint. (c) None: the resolve commands stay with known facts |
| Q9 | `--offline` with the opt-in | (a) The offer fails with the offline failure for each release, so each is a failed download (Q3). (b) Phase 2 does not start offline |
| Q10 | The text of exit 12 with the opt-in says `Run tln roc install for more compilers.` | (a) Keep it (tested). (b) Name the cap or the failed downloads in the text, in place of the extra line |

The design gaps: R-DL1 does not say what the count of the prompt means for a search (Q2). R-NI4 gives an interactive default with no rule for the prompt (Q6). R-DL6 and R-P5 do not say that a failed try counts (Q3). R-P5 does not say how a download shares the budget (Q4). No design file is changed by this slice.

## 8. Changed old tests (TW21)

The change is by `research/slice-037c-revert/update-l2.sh` (`UPDATE=1` of one case) and `check-diff.py` (only the allowed lines). The old copies are in `research/slice-037c-revert/before/`. No L3 case and no other L2 case changed.

| Case | File | Change | Reason |
| --- | --- | --- | --- |
| `tests/commands/cases/probe/pc2-range` (L2) | `expect/stderr` | 3 lines added: `skipped 1 compiler download (73.0 MB), pass --probe-downloads`, before the failure of runs C and D, and before the human text of run E | The default branch of R-NI4 prints the line when phase 2 has a `Need` (n4 is not installed). Runs A (budget cut), B, F, G, H have no `Need`, so no line |
| same | `expect/stdout` | run E (`--json`): `"downloads":0` at the end of `error.details` | `data.downloads` |
| same | `expect/calls.log`, `exit`, `tree.diff` | none (checked) | The line needs no Fx call |
| same | `rules` | the id R-DL4, and the text that said "037b has the opt-in" | the opt-in is `pd1-downloads` |
| `tests/unit/probecmd.roc` | expect 5 (the helper `range`), expect 6 (2 rows) | `Range({ ..., downloads: 0 })`, and the key `"downloads":0` in 2 expected texts | the new field. 1 new row in expect 6 (2 downloads) |

## 9. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Red (the stubs, `research/slice-037c-revert/red-run.log`) | l0: `consent.roc` 3 of 15 fail (todo), `probecmd.roc` expect 6 fails (wrong value: no key `downloads`). l2: `probe/pd1-downloads` and `probe/pc2-range` fail (wrong output: no line, no download). 88 other cases pass. check, fmt, l3, selftest, l1 pass |
| Green (the reference, `green-run.log`) | all steps pass: check 1.2, fmt 0.2, l0 7.2, l2 3.0, l3 9.8, selftest 10.8, l1 31.7 (budgets 10, 5, 10, 30, 60, 20, 60) |

Revert check: 10 mutations of the reference, filtered runs only (`research/slice-037c-revert/mutate.py`, `mutate.log`). Each one gives a code that compiles. 10 of 10 are caught.

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | `--allow-downloads` is the opt-in | L2 `pd1-downloads` |
| M2 | the download is planned before the budget | L2 `pd1-downloads` run 9 (first try: the mutation was too small and survived, then it changed 2 places) |
| M3 | the cap does not count the tries of earlier rounds | L2 run 10 |
| M4 | a release whose download failed is asked again | L2 runs 8, 10 |
| M5 | phase 1 asks a release that is not installed (with `--yes`) | L2 |
| M6 | `--yes` is not an opt-in | L0 `consent.roc` |
| M7 | a count of 0 is offered | L0 `consent.roc` |
| M8 | the ids that the cap drops are not listed | L0 `consent.roc` |
| M9 | the cap note shows with a cap of 0 | L2 run 7 |
| M10 | `data.downloads` does not count | L2 run 3 |

The code that this slice does not test: the `Present` branch (Out 4), `--offline` (Out 5), the default compiler (Q7).

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Size | The reference has `Consent` +61, `ProbeSearch` +111, `ProbeCmd` +10 lines of code (without comments). `ProbeSearch.roc` is 224 lines in the reference. |
| Reference parts | `ProbeSearch.more!` (phase 2), `fetch!` (step 5), `finished!` (the cap note), `State` with `have`, `tried`, `downloads`, `removed`, `capped`. `World` has `allowed` and `sizes`. The size of an id is the asset size of the candidate. |
| The calls of a download | `RocInstall.offer!` then `RocInstall.install_offer!`, as `Start.run!` does: the L2 `calls.log` fixes them (list read from the cache, lock, `curl`, `sha256_file`, `tar`, `chmod`, the compat check, `.talon.json`, `rename`, unlock, the `config.toml` check for the default). A failure deletes the temp dirs and unlocks. |
| `Run.installed` | A round of probes after a download needs the new ids in the installed list (`Launch.program!`). The reference passes `{ ..run, installed: have }`. |
| Order | The answer line is printed before `install_offer!`, the warning after a failure. All lines go to stderr with `fx.err!` (also with `--json`). |
| Compiler limits met | none new. A mutation that leaves a variable unused gives exit 2 of `roc build`. |
| Not to change | the tests, the fixtures, `ProbeRange.step` (its order of the `Need` is Q1) |

## Review (manager, 2026-10-24)

Accepted. Status: code.

| Item | Answer |
| --- | --- |
| Q1 to Q6 | Accepted as tested: installed compilers first, then the next `Need`. The skipped line counts the next round. A failed download warns, gives no fact, is not asked again, counts for the cap, and the exit is that of the range. A download is not a check and needs budget room. `TALON_AUTO_INSTALL` and `--allow-downloads` do not opt in. U5 reading (c), with the U5 marks |
| Q7 | Accepted: the same code as a required download (R-SO15). Not tested now (Out 6) |
| Q8 | Accepted. The optional downloads of the resolve commands are a new slice 037d (the manager adds the row). The one-prompt rule stays a pure decision test here |
| Q9, Q10 | Accepted: `--offline` with the opt-in is out of scope (Out 5). The exit 12 text does not change |
| Texts and `data.downloads` | Accepted as TW24 proposals |
| Changed old files | Accepted: `pc2-range` stderr, stdout, rules. `probecmd.roc` rows |

## Code result (code agent)

Result of `scripts/test.sh`: exit 0. check 1.8 s, fmt 0.1, l0 7.5, l2 3.2, l3 9.7, selftest 10.7, l1 30.1. `OPT=speed`: exit 0 (l2 198 s: the known reason).

| File | Change | Lines |
| --- | --- | --- |
| `cli/lib/Consent.roc` | the 6 bodies of `optional_*` | 439 |
| `cli/lib/ProbeSearch.roc` | phase 2: `more!`, `probed!`, `fetch!`, `fetch_one!`, `sizes_of`, the cap note in `run!` | 232 |
| `cli/lib/ProbeCmd.roc` | `data` writes `downloads` after `probes` | 471 |

Decisions that the slice does not fix:

| Topic | Decision | Rejected |
| --- | --- | --- |
| `Skip` and `Nothing` with a budget cut | The search ends and keeps `cut` as it was (no budget failure from this round). The consent is the reason of the end | Set `cut` also on these ends |
| A `Need` of phase 2 with an installed id and no download (`fetch` empty, `Nothing`) | The search ends as the doc says. In practice no `Need` has an installed id without a fact: phase 1 asked each installed id | Probe the installed ids when `fetch` is empty |
| `tried` | It counts each id of `fetch` except a `Present` after `offer!` (Out 4) | Count `Present` too |
| `dropped` for the cap note | Added in the rounds that end with `Nothing` or a `Download`, not with `Skip` | Add it on `Skip` too |
| Order of the round | `fetch!` runs all downloads of the round, then one `round!` for `asked` without the failed ids | One probe after each download |

No test, fixture or expected file was changed (no dispute rows). No new question (TW17). No compiler limit met beyond the list in the brief.

## Verify results

Filtered revert check, 11 mutations (`research/slice-037c-revert/agent-mutate.py`, log `agent-mutate.log`). Each mutation compiles. The final code is in `code-final/` with `code-final.sha256`. The check at the end: the 3 files are the same (`sha256sum -c`).

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | `--allow-downloads` is the opt-in | L2 `pd1-downloads` |
| A2 | phase 1 asks a release that is not installed (with `--yes`) | L2 `pd1-downloads` |
| A3 | the cap does not count the tries of earlier rounds | L2 `pd1-downloads` run 10 |
| A4 | a release whose download failed is asked again | L2 `pd1-downloads` |
| A5 | the download is planned before the budget | L2 `pd1-downloads` run 9 |
| A6 | a failed try does not count for the cap | L2 `pd1-downloads` run 10 |
| A7 | the cap note shows with a cap of 0 | L2 `pd1-downloads` run 7 |
| A8 | `data.downloads` does not count | L2 `pd1-downloads` run 3 |
| A9 | the ids dropped in the last round (`Nothing`) are not counted | L2 `pd1-downloads` run 10 |
| A10 | a round cut by the budget is followed by another round | not caught: test gap. Closed by run 11 of `pd1-downloads` (section Gap tests) |
| A11 | the cap allows one more download | L0 `consent.roc` |

Caught 10 of 11, and A10 is closed by the gap test below (11 of 11). A10 was: the next round gives `room.run` of 0 and the same `cut` text, with only the count of the ids that did not run possibly different. No test has a partial budget cut in phase 2 with a download (run 9 has room 0). It is a test gap, not an equivalent change.

## Gap tests (test agent, 2026-10-24)

The code check (A10) found one test gap. No code file was changed by the test agent: only the case `probe/pd1-downloads` (now 11 runs) and `research/slice-037c-revert/gen-pd.py` changed. The old runs 1 to 10 have the same expected files (`diff` shows added lines only). The expected files of run 11 were made with the code of the code agent and read.

| Run | Input | Expected | Shown mutation |
| --- | --- | --- | --- |
| 11 | `env:HOME={w}/home7 probe json --range --probe-downloads --file p6/main.roc`. `p6` has `probe = { max = 2 }`. `home7` has only n10 installed and its downloads work | Phase 1 probes n10 (a fail, no pass): 1 probe. Phase 2 wants n9, n8, n7 and the budget allows 1: n9 is downloaded and probed (a fail). The round is cut, so the search ends after it. The failure counts the 2 checks of that round that did not run: `the probe budget is spent: probe.max is 2 and 2 unit checks did not run. ...`. Exit 12 | A10 |

Revert check by hand (one change in `cli/lib/ProbeSearch.roc`, `tests/commands/run.sh probe/pd1-downloads`, then `cp -a research/slice-037c-revert/code-final/cli/. cli/`):

| Id | Change | Result |
| --- | --- | --- |
| A10 | `if room.cut Ok(next) else more!(fx, run, world, wide, next)` becomes `more!(fx, run, world, wide, next)` | FAIL: run 11 gives `3 unit checks did not run` (the next round wants n8, n7, n6 and has no room) in place of 2 |

After the restore `sha256sum -c research/slice-037c-revert/code-final.sha256` is OK for the 3 files.

## Close (manager, 2026-10-24)

The code decisions are accepted. The code agent ran 11 targeted mutations: 10 caught, A10 closed by `pd1-downloads` run 11 (a partial budget cut in phase 2). `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 7.4 s). U5 stays open for the user. Status: done.
