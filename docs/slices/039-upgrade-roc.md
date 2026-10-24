# 039 `tln upgrade roc` (the free nightly), part 039a

Phase: P1. Status: done

Slice 039 is the plan row 039 of `PLAN-P1.md`. It needs 036c, 037c, 037d and 038 (done). The row is too big for one slice (section 1), so this file is part 039a. The parts 039b and 039c are proposed and not tested here.

The private reference had 346 added lines of code (without comments and empty lines): `NightlyFlow.roc` 107, `NightlyPlan.roc` 61, `PickLoop` 46, `InstallFlow` 45, `Oracle` 34, `Ladder` 14, `InstallWrite` 12, `PickFlow` 11, `Vars` 6, `Upgrade` 3, `ResolveLoad` 3, `main` 2, `PickAsk` 1, `ResolveBase` 1. It was deleted after the review (section Review), so the code agent does not see it. The whole row is about 620 lines (039a 346, 039b about 120, 039c about 150), over the 450 of the split rule.

## 1. Scope and split (proposal)

| Part | Content | Rules | Lines | In this file |
| --- | --- | --- | --- | --- |
| 039a | The free nightly for `upgrade` and `upgrade roc`. The newest compiler N as a named download. The baseline download of H. One prompt for the required downloads. The search over the installed compilers, N and H. The pin move, also for members with different pins. A list of compilers that cannot be read. `--no-check` is an error. | R-SP8, R-SP9, R-SP12, R-SP13, R-RP1, R-UP6, R-UP9, R-UP13, R-NI12, R-BL3, R-PH8, R-DL1 (required downloads only), R-NI5, R-WS4 | 346 | yes |
| 039b | Optional downloads (U5): `Consent.optional_*`, `--probe-downloads`, `--yes` inside the cap (R-DL6), the line `skipped N compiler downloads`, lazy downloads in the search (as `ProbeSearch.more!`). The stderr of the U5 rows changes | R-NI4 (optional branch), R-DL2, R-DL4 (skipped line), R-DL6 | about 120 | no |
| 039c | Held moves with the nightly: the compiler slot is movable in the second search, the consent prompt names `roc`. Also Q4 (the lag note for the nightly) and Q5 (`--no-probe` with a free nightly) | R-RP4, R-SP16 with the nightly, R-UP2 for the nightly | about 150 | no |

U5 is read as (c): the prompt names the required downloads only (N, H). A compiler that is not installed and is not N is not askable and is skipped with no line. Every row that depends on this reading is marked `U5` in section 4.

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 039"`)

| Name | Signature | File |
| --- | --- | --- |
| `NightlyPlan.scope` | `List(Str) -> { who : [All, Named(List(Str)), None], nightly : [Free, Held] }` | `cli/lib/NightlyPlan.roc:19` |
| `NightlyPlan.pick` | `{ releases, req : Pin.Req, now, min_age, snapshot, nightly : Bool, held : Str, installed : List(Str) } -> { newest : Try(Str, [NoneKnown]), askable : List(Str), domain : List(Str) }` | `cli/lib/NightlyPlan.roc:32` |
| `NightlyPlan.unify` | `{ members : List({ file, pin : Try(Str, [NoPin]), changes : Bool }), free : Bool } -> { members : <same>, differ : Bool }` (Q3) | `cli/lib/NightlyPlan.roc:39` |
| `NightlyPlan.moved_to` | `{ free : Bool, unify : Bool, held : Try(Str, [NoCompiler]), nightly : Try(Str, [None]) } -> Try(Str, [Same])` | `cli/lib/NightlyPlan.roc:45` |
| `NightlyPlan.pin_line` | `{ old : Try(Str, [NoPin]), id : Str } -> Try(Str, [Same])` | `cli/lib/NightlyPlan.roc:50` |
| `Oracle.Free` | `[Need, Pairs, Scan, Wide, Done({ chosen, nightly : Try(Str, [None]) }), Fail]` | `cli/lib/Oracle.roc:69` |
| `Oracle.step_free` | `Oracle.Input, Oracle.Compat, Try(List(Str), [Held]) -> Oracle.Free` | `cli/lib/Oracle.roc:77` |
| `Vars.scope` | the tag `NightlyOnly` in `command` (stub: `crash` in the arm) | `cli/lib/Vars.roc:109`, `:266` |
| `NightlyFlow.Plan` | `{ free : Try(List(Str), [Held]), downloads : U64, note : Try(Str, [None]) }` | `cli/lib/NightlyFlow.roc:27` |
| `NightlyFlow.plan!` | `Fx, ResolveBase.Request, ResolveBase.Loaded, ResolveBase.Settings, { held : Str, snapshot : Try(U64, [None]) } => Try(NightlyFlow.Plan, Fail)` | `cli/lib/NightlyFlow.roc` |
| `NightlyFlow.unify`, `NightlyFlow.moved_to`, `NightlyFlow.pin_edit` | wrappers of `NightlyPlan` for a request and for a member. `moved_to` is `ResolveBase.Request, Bool (differ), held, nightly -> Try(Str, [Same])` | `cli/lib/NightlyFlow.roc:29`, `:34` |

The wiring is not stubbed. It is in section 9. The stubs of `Oracle.step_free` and `NightlyPlan` carry the full doc of the contract. `ResolveLoad.roc` and `InstallFlow.roc` are the old files (the wiring of Q3 is in section 9).

## 3. Rules of the command

| # | Rule | Source |
| --- | --- | --- |
| 1 | The nightly is free for `upgrade` with no names and for `upgrade ... roc`. It is held for `upgrade X` (no `roc`). `NightlyPlan.scope` | R-SP6 to R-SP9, R-UP12, R-UP13 |
| 2 | `upgrade roc` holds all packages. `upgrade X roc` frees X and the nightly. The compiler is the last slot of the solver, so X gets its best release first | R-SP8, R-SP9, R-SP13 |
| 3 | N is the newest allowed compiler (`Toolchain.range_pick`: range, switch, min-release-age, snapshot). The compilers that the search may use (askable): the allowed ones that are not older than H and are installed, N, and H. H stays in the search also when it is outside the range or the age window | R-UP6, R-SP12, R-C7, R-C9 |
| 4 | The result is the newest askable compiler on which all chosen hashes pass. H has the assumed pass (R-BL3). A pair with no fact is probed on the newest compiler first | R-SP12, R-AL4 |
| 5 | N and H are downloaded before the search when they are not installed. N is named by the command (default Yes). One prompt for all missing ones. Details in the table below | R-NI12, R-BL3, R-NI5, R-DL1 |
| 6 | When the result is not H, each member gets `roc: <N'>` (N' is the result). The ladder runs the baseline check on H and the candidate check and the build on N' | R-RP1, R-BL1 |
| 7 | The range and the switch do not stop a free nightly (it is the fix, R-RP2). A run with no compiler still stops | R-UP6, R-PH8 |
| 8 | `--no-check` with a free nightly is exit 2 (usage) | R-UP9 |
| 9 | When only H is askable (N is H, or N is older than H), the compiler slot is not free. The search is the one of a held compiler, so the old probes stay | R-SP12 |
| 10 | Q1 answer: the list of compilers cannot be read. With the name `roc` the command fails (the failure of the list). With no names the nightly stays H, the line `note: the compiler list could not be read; roc stays <H>` is printed (also in `data.notes`), and the packages upgrade as usual | R-UP6, R-UP12, R-UP13 |
| 11 | Q3 answer: members with different `roc:` pins are no failure for a free nightly. H is the newest pin (`Pin.order`). The result is written to each member that does not have it, also when it is H. `Pin.decide` gets rows in which each pin is the newest pin (`NightlyPlan.unify`), at both call sites (`ResolveLoad.prepared!`, `InstallFlow.finish!`) | R-WS4, R-RP1 |

The prompt (`NightlyFlow.plan!`, `cli/lib/NightlyFlow.roc` doc table):

| N | H | Prompt | Rule |
| --- | --- | --- | --- |
| installed | installed | none | |
| missing | installed | `Consent.roc_install`, default Yes. No person: no prompt, the download starts. `TALON_AUTO_INSTALL=no` does not stop it (the command names it) | R-NI12, R-DL3, R-DL4 |
| any | missing | one `Consent.use_download` for the missing compilers (N first). `Consent.required_want` for H: a flag answers, a person is asked, no person is exit 13, `TALON_AUTO_INSTALL=no` is a refusal | R-NI5, R-DL1, R-DL5, R-BL3 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/nightlyplan.roc` expect 1 (16 rows) | `NightlyPlan.pick`: nothing installed, installed compilers, older than H, too new, min-age 0, snapshot, ranges (`>=`, `=`), H newest, H newer than all, switch off, H not in the list, empty list | R-UP6 R-SP12 R-C7 R-C9 R-NS3 R-NS7 |
| L0 | same, expect 2 (7 rows) | `NightlyPlan.scope`: no names, `roc`, `roc` twice, one package, two packages, package and `roc`, `roc` first | R-SP6 R-SP7 R-SP8 R-SP9 R-UP12 R-UP13 |
| L0 | same, expect 3 (10 rows) | `NightlyPlan.moved_to`: a move, H, the other tag form of H, held nightly, no compiler, `unify` (the result H is written, Q3) | R-RP1 R-SP12 R-CV1 R-WS4 |
| L0 | same, expect 4 (4 rows) | `NightlyPlan.pin_line`: with a pin, no pin, same id, other tag form | R-RP1 R-RP3 R-OUT2 |
| L0 | same, expect 5 (7 rows) | `NightlyPlan.unify` (Q3): 2 pins, 3 pins in any order, a member with no pin, one pin text, one member, no pin, held nightly | R-WS4 R-RP1 |
| L0 | `tests/unit/oraclefree.roc` expect 1 (12 rows) | `Oracle.step_free` with held packages: the pair on the newest compiler, pass on n5, fail on n5 then n4, two packages, only H askable, not askable, not in D, `Err(Held)`, no compiler | R-SP12 R-SP8 R-UP6 R-BL3 R-AL4 |
| L0 | same, expect 2 (5 rows) | `Oracle.step_free` with a free package: X first (3.0.0 on H wins over 2.0.0 on n5), 3.0.0 on n4, on n5, all fail on every compiler, no fact | R-SP13 R-SP9 R-SP12 |
| L0 | `tests/unit/upgrade.roc` expect 1 (+8 rows, 2 rows changed) | `Upgrade.read`: `roc` is a name now, `--no-check` with no names or with `roc` is a usage failure, with a named package it works, the order of the checks | R-UP9 R-UP13 R-SP8 R-SP9 R-UP8 R-SL5 |
| L0 | `tests/unit/vars.roc` expect 9 (new, 2 rows) | `Vars.scope` with `NightlyOnly`: no package free, indexed ones movable with no range, anchor and fixed host not movable, no note | R-SP8 R-SP23 R-UP13 |
| L2 | `upgrade/ur1-roc` run 1 (U5) | `upgrade roc`, only H installed, a person says Enter: the prompt names N alone (the answer is only in `calls.log`), the pin moves to N, no package changes. n10 and n11 are not installed and nobody asks for them | R-SP8 R-SP12 R-UP6 R-NI12 R-RP1 R-PH8 |
| L2 | same, run 2 (U5) | CI, no person: the download starts and the answer line is printed. No `skipped` line (039b adds it) | R-NI12 R-DL4 |
| L2 | same, run 3 | `--yes`, n10 and n11 installed, json 1.2.0 fails on n12: N is a candidate, so n11 wins | R-SP12 R-C7 |
| L2 | same, run 4 | json 1.3.0 fails on n10, n11 and n12: `nothing to change`, the pin stays. N was downloaded | R-SP12 |
| L2 | same, run 5 | `upgrade lib roc`: lib 1.1.0 fails on n12, so the move is lib 1.1.0 and n11 (X first) | R-SP9 R-SP13 |
| L2 | same, run 6 | `upgrade roc` on the same world: lib stays 1.0.0, the pin moves to n12 | R-SP8 |
| L2 | same, run 7 | range `>=n10`, H outside the range: the command does not stop, N is n12 | R-UP6 R-C9 |
| L2 | same, run 8 (U5) | `min-release-age = "0d"`: N is n14 (the download) | R-C7 R-NI12 |
| L2 | same, run 9 | `TALON_NIGHTLY=0`: exit 10, the text names the switch | R-NS2 |
| L2 | same, run 10 | `--dry-run --json`: `data.pinned` has the new id, `data.downloads` is 0, nothing is written | R-RP1 R-J3 |
| L2 | same, run 11 | `upgrade json --no-check`: the nightly is held, the flag works, 0 probes | R-UP9 R-SP7 |
| L2 | same, runs 12 and 13 | `upgrade --no-check` and `upgrade roc --no-check`: exit 2 | R-UP9 |
| L2 | same, run 14 | Q3: workspace `ws2`, pins H and n10, `upgrade roc`: no failure, both members get n12 (a pin line for each) | R-WS4 R-RP1 R-SP8 |
| L2 | same, run 15 | Q3: workspace `ws3`, pins H and n11, N fails: the result is n11 (= H, the newest pin). Member a gets n11, member b has no line | R-WS4 R-RP1 R-SP12 |
| L2 | `upgrade/ur3-list` run 1 | Q1: bare `upgrade`, the list cannot be read (no route, 404): the note `roc stays <H>`, json still moves to 1.2.0, no pin line | R-UP6 R-UP12 R-SP6 |
| L2 | same, runs 2 and 3 | `upgrade roc`, `upgrade json roc`: the command fails with the failure of the list (exit 2) | R-UP6 R-UP13 |
| L2 | same, run 4 | `upgrade json`: the nightly is held, the list is not read, no note | R-SP7 |
| L2 | same, run 5 | `--dry-run --json`: the note is in `data.notes` | R-J3 |
| L2 | same, run 6 | `upgrade --no-check`: exit 2, before the list | R-UP9 |
| L2 | `upgrade/ur2-consent` run 1 (U5) | H and N missing, a person says Enter: one prompt `Download 2 compilers ...: N, H?` | R-NI5 R-DL1 R-BL3 R-NI12 |
| L2 | same, run 2 (U5) | the same, CI: exit 13, nothing downloaded | R-DL5 |
| L2 | same, run 3 (U5) | the same, CI with `--allow-downloads`: both installed, the pin moves | R-DL3 R-DL4 |
| L2 | same, run 4 (U5) | the same, a person says `n`: exit 13 | R-DL5 R-DL1 |
| L2 | same, run 5 (U5) | the same, CI and `TALON_AUTO_INSTALL=no`: exit 13, the refusal names H | R-DL5 R-NI5 |
| L2 | same, run 6 (U5) | N installed, H missing, a person: one prompt for H alone | R-BL3 |
| L2 | same, run 7 (U5) | H installed, N missing, a person says `n`: the prompt names N alone, exit 13 | R-NI12 |
| L2 | same, run 8 (U5) | H installed, N missing, CI and `TALON_AUTO_INSTALL=no`: the command names N, so it downloads | R-NI12 R-DL4 |
| L2 | same, run 9 (U5) | H installed, N missing, a person says Enter: the download starts, the pin moves | R-NI12 |

U5 rows: `ur1-roc` runs 1, 2, 8 (compilers other than N and H are missing in the home) and all 9 runs of `ur2-consent` (n10 and n11 are missing in each home). In 039b their stderr and prompt text can change (the `skipped` line, the count of the prompt).

L0 expects: `nightlyplan.roc` 5 (a new file, about 160 lines, about 0.4 s in `roc test`), `oraclefree.roc` 2 (a new file, 127 lines, about 0.6 s), `upgrade.roc` +8 rows, `vars.roc` +1 expect. With the reference the step l0 is 7.6 s (baseline 7.8 s, budget 10 s). Deep cases: 3 new (`ur1-roc` 15 runs, `ur2-consent` 9 runs, `ur3-list` 6 runs). L3 has no new scenario (the L2 cases cover the flow, and the real `roc` needs real downloads).

The 3 cases are 3 and not 1 because the worlds differ: `ur1-roc` has the packages and the facts (the unit fails per compiler) and homes with installed compilers, `ur2-consent` has no package fact and the `roc` on PATH is older than H, so H is missing in some homes, `ur3-list` has no route for the list of compilers.

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| Pin line, member with a pin | `  ~ roc: <old> -> <new>`, in the list of the file, after the package lines | ur1 runs 1, 2, 3, 5 to 8, ur2 |
| Pin line, member with no pin | `  + roc: <new>` (the line of slice 013) | nightlyplan.roc expect 4 |
| `--no-check` with a free nightly | `tln: error[usage]: --no-check does not work when tln upgrade moves the nightly: the roc pin moves only after the check. Name the packages to hold the nightly: tln upgrade <name> --no-check`, exit 2 | upgrade.roc, ur1 runs 12, 13 |
| Download of N alone | the prompt `Download 1 compiler, <size>: <N>? [Y/n]`, the answer line `downloading <N> (<size>)` (the texts of `Consent.roc_install`, they exist) | ur1 runs 2, 8, ur2 runs 7, 8, 9 |
| Downloads of N and H | the prompt `Download 2 compilers, <size>: <N>, <H>? [Y/n]`, the answer line `downloading 2 compilers (<size>)` (`Consent.use_download`, they exist) | ur2 runs 1, 3 |
| No consent, no person | `tln: error[consent]: 2 compiler downloads (<size>) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.`, exit 13 (`Consent.download_stop`, exists) | ur2 run 2 |
| Person says `n` | for N and H: `<N> is not installed. Nothing was downloaded. Run: tln roc install <N>, ...` (`Consent.command_declined`). For N alone: `<N> is not installed. Nothing was downloaded.` (`Consent.roc_install_declined`). Exit 13 | ur2 runs 4, 7 |
| `TALON_AUTO_INSTALL=no` with H missing | `the compiler <H> is not installed. TALON_AUTO_INSTALL=no refuses the download. ...` (`Consent.download_refused`), exit 13 | ur2 run 5 |
| No compiler is allowed | `tln: error[no_tuple]: no compiler release is in [toolchain] roc (*), and nightly is false (set by TALON_NIGHTLY)` (`Toolchain.range_failed`, exists), exit 10 | ur1 run 9 |
| Nothing moves | `nothing to change` (exists) | ur1 run 4 |
| `--json` | `data.pinned` is the new id (field of slice 013), `data.downloads` is the number of compilers that the run installed | ur1 run 10 |
| List cannot be read | `note: the compiler list could not be read; roc stays <H>` (bare `upgrade`, Q1 answer). It is in `data.notes`. With the name `roc`: the failure of the list, exit 2 in the fake (exists) | ur3 runs 1, 2, 3, 5 |
| Default compiler | the first download sets `default-roc` in `config.toml` (R-SO15, the existing rule of `RocInstall.install_offer!`). It is in the `tree.diff` of `ur1-roc` and `ur2-consent` (homes with no default) | ur1, ur2 `tree.diff` |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | N is the newest allowed compiler (`Toolchain.range_pick`), also when it is not installed. It is the one download that the command names | the newest installed compiler (no R-NI12 download) |
| D2 | Askable compilers: installed and allowed and not older than H, plus N, plus H. A compiler older than H is never a value (`upgrade` moves up) | all allowed compilers (needs the optional downloads of 039b), only H and N |
| D3 | The downloads of N and H are done before the search. The search then runs on installed compilers only | a lazy download in the search (039b) |
| D4 | One prompt: `use_download` when H is missing (as `roc use`, slice 026b), else `roc_install` for N alone | one prompt for each download |
| D5 | No person: N starts at once, `TALON_AUTO_INSTALL=no` does not stop it (R-DL4: the command names the download). H is a required download, so `TALON_AUTO_INSTALL=no` refuses it | stop N without a person |
| D6 | The range and switch gate (`check_pin`) is skipped for a free nightly. Only a run with no compiler stops (R-RP2: `upgrade roc` is the fix that the failure names) | keep the gate |
| D7 | When only H is askable the compiler slot is held (rule 9). The old probes of bare `upgrade` do not change | always free: bare `upgrade` makes one probe more (`ug2-lag` showed 2 probes become 3) |
| D8 | A moved pin is written to each member that does not have it. The ladder runs the baseline on H and the candidate and the build on the result | write the pin before the ladder |
| D9 | In `upgrade roc` the held packages are movable as in `upgrade X` (Q2, accepted) | not movable |
| D10 | The list of compilers that cannot be read: with the name `roc` a failure, with no names a note and H alone (Q1, review) | a failure for both |
| D11 | Different pins in a workspace: H is the newest pin, every member gets the result (Q3, review) | the oldest pin as H, the pin of the first member |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-RP4 (the nightly held and a move needs it) | 039c |
| Out 2 | R-NI4 optional branch, R-DL2, R-DL4 skipped line, R-DL6 cap, `--probe-downloads`, `--yes` for optional downloads | 039b (U5) |
| Out 3 | R-UP2 for the nightly (a note that N was not chosen) | 039c (Q4) |
| Out 4 | `--no-probe` with a free nightly | 039c (Q5) |
| Out 5 | `tln init` with R-NI12 | not this row |

| Id | Question | Options |
| --- | --- | --- |
| Q1 | The list of compilers cannot be read for a free nightly | Answered (review): with the name `roc` the command fails, with no names the nightly stays H, with a note (rule 10). The note text is a TW24 proposal |
| Q2 | R-SP23 omits R-SP8: are held packages movable in `upgrade roc`? | Answered (a): movable, as `upgrade X` |
| Q3 | Members of a workspace with different pins: `Pin.decide` fails and names `tln upgrade roc` | Answered (review): `upgrade roc` accepts them and sets one pin for every member (rule 11) |
| Q4 | R-UP2 note for a nightly that is not the newest allowed one | Moved to 039c. Not tested here |
| Q5 | `--no-probe` with a free nightly | Moved to 039c. Not tested here |
| Q6 | U5 reading (c) is used for 039a | Answered: stays, with the U5 marks |

## 8. Compiler and tool limits met (for the manager and the code agent)

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | `packages` is a reserved word, also as a record field | `NightlyPlan.scope` has the field `who` | use another name |
| C2 | A local name that is the name of a parameter is a duplicate definition (`nightly` in `Oracle.scanned`) | the reference renames the parameter | rename |
| C3 | `roc check` exits 2 on a warning, so a mutation with an unused variable did not compile | the revert check uses `and Bool.False` and `or Bool.True` | same |

## 9. Notes for the code agent

| Topic | Note (the reference was deleted: these notes describe it, with no line numbers) |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/upgrade/{ur1-roc,ur2-consent}/rules` has the text of each run |
| `Oracle` | `step_free(input, compat, askable)` is `step_with(..., askable)`. `step_probed` calls it with `Err(Held)` and drops the `nightly`. `request_of` builds the compiler slot values: `askable` filtered by D and without H, then H last. The `Done` path of `search` threads the compiler of the tuple. The return types of `search`, `fetch_first`, `walked`, `scanned` are `Oracle.Free` |
| `PickLoop` | `Setup` has `free`, `Looped` has `nightly`. `run!` gives `Wide` first when the slot is free and D is not read, then `Oracle.step_free`. `probe_round!` groups the pairs by `pair.nightly`: the started compiler keeps the old params, the other compilers use `Launch.program!` and `Launch.touch!`, one `UnitFlow.probes!` call, one `Facts.save!`, the first failure wins |
| `PickFlow` | `prepare!` has the 8th parameter `free`. The pick command is `NightlyOnly` when `NightlyPlan.scope(names).who` is `None`. `Lags.of` gets `compiler: looped.nightly`. `Picked` has `nightly` (`ResolveBase.Picked`) |
| `Vars` | the arm `NightlyOnly`: `free` false, `movable` as `movable_of(variable, false)`, `ranges: []` when movable, `any_series` false, no note |
| `PickAsk` | `asked!` skips the word `roc` for `Upgrade` |
| `InstallFlow` | `resolve!`: `free_nightly`, the gate is skipped, `NightlyFlow.plan!` runs when `free_nightly and !request.no_check`. `finish!`: `NightlyFlow.moved_to`, the pin edits for the members, `ladder_decision`, `checked`, `candidate: to`. The last parameter of `finish!` is a record `{ seen, nightly, downloads }` |
| `InstallWrite` | `ladder!` has `candidate`. `held` of the ladder is the candidate. `loop.base` is `Ok(H)` when there is a candidate |
| `Ladder` | `Loop.base`. With `base: Ok(id)` the baseline check runs on H, the candidate check and the build on `request.held` |
| `Upgrade` | `read` returns the usage failure of rule 8 instead of the `Internal` failure of the name `roc` |
| `NightlyFlow` | the whole module was in the reference. The call order is in its doc table. `RocInstall.offer!` and `install_offer!` are used as `RocUse` does |
| Q1 | `NightlyFlow.plan!` matches `Nightlies.list!`: `Ok(listed)` with a source other than `Missing` goes on. `Missing` and `Err(fail)` give `Err(fail)` (`Toolchain.offline_no_list` for `Missing`) when `request.names` has `roc`, else `Ok({ free: Err(Held), downloads: 0, note: Ok("the compiler list could not be read; roc stays <H>") })`. `InstallFlow.resolve!` prints the note as `note:...` after the pin notes and puts it in `Outcome.notes` between the pin notes and the others |
| Q3 | Both `Pin.decide` call sites get `NightlyFlow.unify(request, rows).members` (`ResolveLoad.prepared!` uses `NightlyPlan.unify` with `free: request.command == Upgrade and NightlyPlan.scope(request.names).nightly == Free`). `InstallFlow.finish!` passes `unified.differ` to `NightlyFlow.moved_to`. `NightlyPlan.moved_to` with `unify` true gives `Ok(n)` also when n is H, and `pin_line` gives `Err(Same)` for the members that have the pin. H is the newest pin, by `Pin.order` with no times |
| Order of the checks | `Upgrade.read` checks the selector before `--no-check` (the test `upgrade json@^3 --no-check` is the selector failure) |

## 10. Changed old tests (TW21)

| Case | File | Change | Reason |
| --- | --- | --- | --- |
| `upgrade/ug1-flow` | `fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100` (new), `expect/calls.log`, `expect/tree.diff` | the runs with bare `upgrade` (1, 2, 6, 10) read the list of compilers: new calls (`platform`, `list_dirs`, `http_get`, `db_query pinned`, `list_dirs toolchains`) and the `pinned` row and the list in the tree. The list has H (`nightly-2026-10-14-38a3029`) as the only release, so N is H, no download, no move. `stdout`, `stderr` and `exit` do not change | R-UP6: bare `upgrade` frees the nightly, so it reads the list (Q1). By `research/slice-039-revert/old-routes.py` and `UPDATE=1`. Copies in `research/slice-039-revert/before/` |
| `upgrade/ug2-lag` | the same 3 files | the same (runs 1 and 2 are bare `upgrade`). `stdout` and `stderr` do not change, also the probe counts (decision D7) | the same |
| `tests/unit/upgrade.roc` | expect 1 | the rows `upgrade roc` and `upgrade json roc` are `Ok` (were the `Internal` failure), 8 new rows | the name `roc` is built |
| `tests/unit/vars.roc` | new expect 9 | the scope `NightlyOnly` | new tag |
| `tests/selftest.sh` | row `s_oracle` (line 702) and its comment (line 699) | the loop may call `Oracle.step_free(` as well as `Oracle.step_probed(` | `PickLoop.run!` calls `step_free` now. Copy in `before/tests/selftest.sh` |

All other L2 cases (93) and the L3 cases pass with the reference with no change.

## 11. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Baseline (`research/slice-039-revert/baseline-run.log`) | all pass: check 1.2, fmt 0.2, l0 7.8, l2 4.3, l3 9.7, selftest 10.8, l1 28.5 |
| Reference, first (`reference-run.log`) | all pass: check 1.4, fmt 0.1, l0 7.9, l2 3.2, l3 9.8, selftest 11.2, l1 31.0 |
| Reference, after the review (`reference-run2.log`) | all pass: check 1.3, fmt 0.1, l0 7.6, l2 3.3, l3 10.6, selftest 11.2, l1 30.3 |
| Red, with the stubs, after the review (`red-run2.log`) | check, fmt, l3, selftest, l1 pass. l0 FAIL (4 files), l2 FAIL (5 cases) |

The red run, the failing tests and the reason:

| Test | Result | Reason |
| --- | --- | --- |
| `nightlyplan.roc` 5 of 5 expects | crash `todo: slice 039` | the stubs of `NightlyPlan` |
| `oraclefree.roc` 2 of 2 expects | crash `todo: slice 039` | `Oracle.step_free` is a stub |
| `vars.roc` expect 9 | crash `todo: slice 039` | the arm `NightlyOnly` is a stub |
| `upgrade.roc` expect 1 | 6 rows (`upgrade roc`, `upgrade json roc`, 4 rows with `--no-check`): got `tln: error[internal]: tln upgrade roc is not built yet` or `Ok` | `Upgrade.read` is the old code |
| L2 `ur3-list` | the same | the same |
| L2 `ur1-roc` | run 1: exit 1 instead of the pin move (the name `roc` is the `Internal` failure), all runs differ | the wiring is not done |
| L2 `ur2-consent` | the same | the same |
| L2 `ug1-flow`, `ug2-lag` | the calls of the list are missing in `calls.log` | bare `upgrade` does not read the list yet |

Revert check (`research/slice-039-revert/mutate.py`, the reference in the tree, filtered runs only, `mutate.log`, `mutate-run2.log`, `mutate-run3.log`): 13 mutations, 13 caught. N11 to N13 are for the review changes.

| Id | Mutation | Caught by |
| --- | --- | --- |
| N1 | an uninstalled compiler is askable | `l0:nightlyplan` |
| N2 | min-release-age does not hide an installed compiler | `l0:nightlyplan` |
| N3 | the compiler is the first slot | `l0:oraclefree` |
| N4 | `upgrade roc` frees the packages | `l2:upgrade/ur1` |
| N5 | `--no-check` with `roc` is allowed | `l0:upgrade` |
| N6 | the pin is written when it does not change | `l0:nightlyplan` |
| N7 | the range gate stops a free nightly | `l2:upgrade/ur1` |
| N8 | the baseline has no prompt of its own (N alone is named) | `l2:upgrade/ur2` |
| N9 | the slot is free when only H is askable | `l2:upgrade/ug2` |
| N10 | the baseline of the ladder is not H | `l2:upgrade/ur1` |
| N11 | `upgrade roc` degrades when the list cannot be read (Q1) | `l2:upgrade/ur3` |
| N12 | different pins stop a free nightly (Q3) | `l0:nightlyplan`, also `l2:upgrade/ur1` (checked by hand) |
| N13 | the result H is not written to the members with another pin (Q3) | `l0:nightlyplan`, also `l2:upgrade/ur1` (checked by hand) |

## 12. Files

| File | Lines | State |
| --- | --- | --- |
| `docs/slices/039-upgrade-roc.md` | this file | new |
| `cli/lib/NightlyPlan.roc` | 51 (stub) | new, stub |
| `cli/lib/NightlyFlow.roc` | 44 (stub) | new, stub |
| `cli/lib/Oracle.roc`, `Vars.roc`, `Upgrade.roc`, `main.roc` | types and docs | changed, stubs (copies in `research/slice-039-revert/before/`) |
| `tests/unit/nightlyplan.roc` | about 160 | new |
| `tests/unit/oraclefree.roc` | 127 | new |
| `tests/unit/upgrade.roc`, `tests/unit/vars.roc` | +16 changed lines, +45 | changed |
| `tests/selftest.sh` | 2 lines | changed |
| `tests/commands/cases/upgrade/ur1-roc/`, `ur2-consent/`, `ur3-list/` | 15, 9 and 6 runs | new |
| `tests/commands/cases/upgrade/ug1-flow/`, `ug2-lag/` | route and 2 expected files each | changed |
| `research/slice-039-revert/` | | `before/` (with `NEW.txt`), `stubs/`, `gen-ur.py`, `old-routes.py`, `mutate.py`, `bk.sh`, logs |

## Review (manager, 2026-10-24)

Accepted, with 2 changes. The test agent made both (section 4, rules 10 and 11, ur1 runs 14 and 15, `ur3-list`).

| Item | Answer |
| --- | --- |
| Split | Accepted. 039a is this file. The manager adds 039b (optional downloads, U5: R-NI4 optional branch, R-DL6 cap, `--probe-downloads`, the skipped line) and 039c (held moves with the nightly, R-RP4, plus Q4 and Q5) |
| Q1 | Change. An unreadable compiler list must not break bare `upgrade` offline: the nightly stays H, with a note (for example `note: the compiler list could not be read; roc stays <H>`), and the packages still upgrade. `upgrade roc` alone, where moving the nightly is the whole point, fails as now. Test both |
| Q2 | Accepted: held packages are movable in `upgrade roc` (as `upgrade X`, D8 of 038) |
| Q3 | Change. `Pin.decide` names `upgrade roc` as the fix for differing pins in a workspace, so `upgrade roc` must accept differing pins and set one pin for every member (D7). Add one run |
| Q4, Q5 | Move to 039c (not tested here) |
| Q6 | U5 reading (c) stays, with the U5 marks |
| D1 to D10 | Accepted (D4 follows R-DL4 and R-NI12: the newest nightly of `upgrade` starts with no person) |
| Changed old tests | Accepted: the ug1-flow and ug2-lag routes, the upgrade.roc rows, vars.roc, the `s_oracle` selftest row |

After the review the test agent deleted `research/slice-039-revert/reference/`. The red state is in `red-run2.log`.

## Code result (code agent, 2026-10-24)

`scripts/test.sh` exits 0 (dev): check 1.4 s, fmt 0.1, l0 7.9 (budget 10), l2 4.8 (96 cases), l3 9.8, selftest 11.1, l1 28.9. `OPT=speed scripts/test.sh` exits 0 too (l0 10.0, l2 150.6 over budget for the known reason). `roc check`: 0 errors, 0 warnings.

| File | Lines | What |
| --- | --- | --- |
| `cli/lib/NightlyPlan.roc` | 82 | `scope`, `pick`, `unify`, `moved_to`, `pin_line` |
| `cli/lib/NightlyFlow.roc` | 145 | `unify`, `moved_to`, `pin_edit`, `plan!` (steps 1 to 4 of its doc) |
| `cli/lib/DownloadAsk.roc` | 41 | new: `totals` and `required!` (the one prompt of the required downloads, moved from `RocUse`) |
| `cli/lib/Oracle.roc` | 499 | `step_free`. `step_probed` calls it with `Err(Held)`. `values_of` (the values of the compiler slot), `step_hint` (the old `step_with` for `hint`). `search`, `fetch_first`, `walked`, `scanned` give `Oracle.Free`; `walked` runs the lookups and the scan on the compiler of the tuple |
| `cli/lib/PickLoop.roc` | 312 | `Setup.free`, `Looped.nightly`, `wants_domain` (D first), `probe_round!` groups the pairs by compiler (`on_compiler!`) |
| `cli/lib/PickFlow.roc` | 227 | `prepare!` has `free`. The command `NightlyOnly`. `Picked.nightly`. `Lags.of` gets `looped.nightly` |
| `cli/lib/PickAsk.roc` | 230 | the word `roc` is not a name for `Upgrade` |
| `cli/lib/Vars.roc` | 307 | the arm `NightlyOnly` |
| `cli/lib/Upgrade.roc` | 70 | `read`: `--no-check` with a free nightly is the usage failure (after the selector check) |
| `cli/lib/ResolveLoad.roc`, `ResolveBase.roc` | 171, 351 | `NightlyPlan.unify` before `Pin.decide`. `Picked.nightly` |
| `cli/lib/InstallFlow.roc` | 211 | the gate for a free nightly, `NightlyFlow.plan!`, the `note:` line, `finish!` (unify, `moved_to`, the pin edits, the ladder for a moved pin, the downloads) |
| `cli/lib/InstallWrite.roc`, `Ladder.roc` | 181, 398 | `ladder!` has `candidate`. `Loop.base`. `Ladder.run!` starts the candidate and the baseline compiler |
| `cli/lib/Toolchain.roc` | 462 | new `range_allowed` (steps 1 to 3 of `range_pick`, which now uses it) |
| `cli/lib/RocUse.roc` | 298 | uses `DownloadAsk` (its private `consent!` and `totals` are gone) |
| `cli/lib/main.roc` | 147 | exposes `DownloadAsk` |

Decisions that the slice does not fix:

| Topic | Choice | Rejected |
| --- | --- | --- |
| The one prompt for N and H | new module `DownloadAsk` (the `consent!` and `totals` of `RocUse`, moved), used by `RocUse` and `NightlyFlow` | a copy in `NightlyFlow`. `NightlyFlow` cannot import `RocUse`: `RocUse` imports `Install`, which imports `Resolve`, which imports `InstallFlow`, which imports `NightlyFlow` (a cycle) |
| The allowed compilers (`NightlyPlan.pick`) | new `Toolchain.range_allowed`, and `range_pick` takes the newest of it | a copy of the filter in `NightlyPlan` |
| The candidate in the ladder | `Ladder.run!` always starts `held` (the candidate) when `Loop.base` is `Ok` (the log of `ur1-roc` run 15 has a second start of H when the result is H), and reuses the started compiler of the loop for the baseline when its id is H | reuse of the loop compiler when it is the candidate |
| Spelling of the started compiler in a probe round | a pair whose compiler is the started compiler in the other tag form (R-CV1) counts as the started compiler (`probe/pb1-ladder` showed it) | compare the texts |
| `Pin.decide` writes and the pin move | with a move, the pin edits of `NightlyFlow.pin_edit` replace `decision.writes` (also in the ladder: `ladder_decision` has no writes), and the ladder runs when only the pin moves | both kinds of pin |
| Text of the `range_failed` for no `[toolchain] roc` | `*` | an empty range text (as `ResolveSelect.ranged!`) |
| H missing and not a nightly (a release) | `Compiler.require` fails (as `RocUse.missing_baselines`), no offer | an offer of H |
| `Oracle.step_with` | removed. `step_free` and `step_hint` (for `hint`: no explanation, `assume` off) | one function with a flag for the askable list |

No test, fixture or expected file was changed (no dispute rows). No compiler bug found. The limits of section 8 were met only as noted there (the chain `a ?? b ?? ""` was written as a `match`; a closed record parameter got a built record, `Ladder.start_on!`, `ctx` of `DownloadAsk.required!`).

## Verify results (code agent)

Revert check (TW12), filtered runs only: `research/slice-039-revert/agent-mutate.py`, results in `agent-results.md`, log `agent-mutate.log`. Caught 9 of 11. After the run `sha256sum -c research/slice-039-revert/code-final.sha256` is OK for all 137 files of `cli/lib/`.

| Id | Mutation | Result |
| --- | --- | --- |
| A1 | a compiler that is not installed is askable | caught (`nightlyplan.roc`) |
| A2 | H is the oldest pin, not the newest | caught (`nightlyplan.roc`) |
| A3 | the scan and the lookups use H, not the compiler of the tuple | caught (`oraclefree.roc`) |
| A4 | no `.last-use` for the other compiler of a probe round | caught (`ur1-roc`) |
| A5 | 2 spellings of the started compiler are 2 compilers | caught (`probe/pb1-ladder`) |
| A6 | the ladder does not start the candidate compiler | caught (`ur1-roc`) |
| A7 | the pin of `Pin.decide` stays an op of the candidate header when the pin moved | not caught: test gap. No project of `ur1-roc` or `ur2-consent` has a member with no `roc:` entry. Closed: `ur4-candidate` (see Gap tests) |
| A8 | `data.downloads` has no download of the plan | not caught: test gap. The only `--json` run (`ur1-roc` run 10) has N installed. Closed: `ur1-roc` run 17 (see Gap tests) |
| A9 | N alone is asked as a required download | caught (`ur2-consent`) |
| A10 | D is not read before the first step of a free compiler | caught (`ur1-roc`) |
| A11 | the word `roc` is a package name | caught (`ur1-roc`) |

## Gap tests (test agent, 2026-10-24)

The code agent found 2 test gaps (A7, A8). Both are closed. Tests only; no code or stub changed. The files are in `research/slice-039-revert/` (`gen-ur.py`, `ur1-rules.txt`, `ur4-rules.txt`, `gap-run.log`).

| Gap | New test | Hand mutation | Result |
| --- | --- | --- | --- |
| A7 | `upgrade/ur4-candidate` (new case, 2 runs, with `fx/probe-text`: the header of the candidate copy is in `calls.log`). Run 1: project `pu` has no `roc:` entry and has package changes (lib 1.1.0 fails on n12), bare `upgrade`: the candidate header has one `roc: <n11>` line, the project file gets `+ roc: <n11>`. Run 2: project `pp` has the pin H: one `roc: <n11>` line, `~ roc: <H> -> <n11>`. Also `ur1-roc` run 16 (the same project kind, the project file and the stdout) | `ladder_decision = if moved.is_ok() and Bool.False { ..decision, writes: [] } else decision` in `InstallFlow.finish!` (A7 of the code agent) | `ur4-candidate` fails: the header of the copy has `roc: "<H>"` instead of `roc: "<n11>"`. `ur1-roc` does not see it: the copy is not in its log |
| A8 | `ur1-roc` run 17: `upgrade roc --json`, CI, only H installed: N is downloaded by the plan, `data.downloads` is 1 | `downloads: ladder_ran.downloads }` without `+ after.downloads` (A8 of the code agent) | `ur1-roc` fails: `"downloads":0` instead of `"downloads":1` |

After each mutation the file was copied back from `research/slice-039-revert/code-final/`. `sha256sum -c research/slice-039-revert/code-final.sha256` is OK (0 other lines). `scripts/test.sh` exits 0 (check 1.1, fmt 0.1, l0 7.9, l2 4.6, l3 9.8, selftest 11.2, l1 29.4).

The expected files of `ur1-roc` (17 runs, 13 projects), `ur2-consent` and `ur3-list` were written again with `UPDATE=1` after the generator ran again. The runs 1 to 15 of `ur1-roc` have the same output as before (checked with a copy of the old case).

Closed in "Verify results": A7 and A8.

## Close (manager, 2026-10-24)

The code decisions are accepted (`DownloadAsk` and `Toolchain.range_allowed` extracted, no copies). The code agent ran 11 targeted mutations: 9 caught; A7 is closed by `upgrade/ur4-candidate`, A8 by `ur1-roc` run 17. The `ur2` and `ur3` expected files were written again by `gen-ur.py`; the code is the one that passed the old files (`code-final.sha256` clean) and the rules are unchanged, so their content is the same. `scripts/test.sh` exits 0 with no WARN (l0 7.9 s). Oracle.roc is 499 lines: slice 039s splits it before 039b. Status: done.
