# 007 Commands that write: `install` and `add`

Phase: P0. Status: done

This slice builds `tln install` (also `add`, `i`, `--frozen`). Other slices (see `PLAN.md`): 008 is `remove` (R-CM3, R-RV1 to R-RV5, the import scan, the removal of `talon.toml` keys), 009 is `update`, `list`, `why`, `verify`, the closure walk and R-C8. The scope agent split the first plan of 007 into these three slices (the manager accepted it, see "Answers of the manager").

The test agent wrote the stubs, the tests, the fixtures and the harness changes. The code agent writes the bodies (TW18). A private reference implementation made the tests pass and was used for the revert check. It was deleted after the check: no reference code is in the tree.

## Rules of the slice

| Group | Ids | Where the test is |
| --- | --- | --- |
| Commands | R-CM2, R-CM19, R-CM20 (`add`, `i`, `install` are one command) | L0 `opts`, L3 `add/*` |
| Flags | R-FL5 (`--registry`), R-FL8 (`--frozen`, `--dry-run`), R-FL9 (`--snapshot`), R-FL10 (`--strategy`), R-FL12, R-FL13, R-FL4 (`--quiet`), R-FL1 to R-FL3 (`--json`, `--yes`) | L0 `opts`, L3 |
| Lookup and entry | R-AD1, R-AD2, R-AD6, R-AD8 to R-AD33 (not R-AD3 to R-AD5, R-AD34 to R-AD37) | L0 `add`, L3 `add/*` |
| Selectors | R-SL3 to R-SL5, R-SL10, R-SL12, R-SL14 | L0 `add`, L3 `add/ad1` |
| Header and intent | R-H1, R-H3, R-I5, R-I8, R-I9, R-WS12, R-WS14, R-RP3 | L3, L0 `intent` |
| Output | R-DT5, R-LF4, R-J1 to R-J6, R-OUT4, R-OUT5, R-PD9, R-SE7 | L0 `report`, L3 |
| Prompt | R-NI1, R-NM4, R-NM6, R-NM8, R-NM9, R-NM10 | L2 `resolve/rs-stale-key*`, L3 `install/in1` |
| Flow | R-CC1, R-CC2, R-CC6, R-CC7, R-LD4, R-SO7 | L2 `install/in1-flow` |

Carry-over items from the slices 004 to 006:

| Item | Where |
| --- | --- |
| P1 (add of a name, Keep) | L3 `add/ad1` |
| P2 (selectors, `--no-pin`, an exact version with no release) | L3 `add/ad1` |
| P3 (`add json`, `add json@^2.1` for a header alias) | L3 `add/ad1` |
| P4 (`--platform`: replace, a package as platform, a platform with no flag, the note) | L3 `add/ad2` |
| P5 (short name, `9lives`, `--as` taken, reserved, 2 names with `--as`) | L3 `add/ad1` |
| P7 (git ref `@dd03c09e`) | L3 `add/ad1` |
| Q9 of slice 004 (`add json@latest` is Keep) | L3 `add/ad1` |
| R-AD31 with another platform alias | L0 `add` (row), L3 `add/ad2` (the alias `shell`, with a package named `pf`) |
| W2 (`probe` with a path operand is no ref failure) | L3 `install/in1` |
| R-SL12 close versions | L0 `add`, L3 `add/ad1` |
| Q8 of slice 006 (the stale key is the prompt R-NI1) | L2 `resolve/rs-stale-key`, `rs-stale-key-ask`, L3 `install/in1` |
| C6 (`Fail(n)` with no readable error is no pass) | L0 `ladder` |
| M22 (the temp copy has no `.git`), M26 (the candidate header has absolute path entries) | L2 `install/in1-flow` |
| R-CC7 at command level | L2 `install/in1-flow` (runs 2 and 3) |

## Files

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Opts.roc` | 47 | New. `Opts.read : Args -> Try(Opts, Fail)`. Stub. |
| `cli/lib/Report.roc` | 65 | New. `Report.Outcome`, `resolved_line`, `data`. Stubs. |
| `cli/lib/Install.roc` | 39 | New. `Install.run! : Fx, Args => I32`. Stub. The doc has the step table and the output rules. |
| `cli/lib/Run.roc` | 89 | `install` calls `Install.run!`. Other commands keep the skeleton failure. |
| `cli/lib/main.roc` | 64 | Exposes `Install`, `Opts`, `Report`. |
| `cli/lib/Resolve.roc` | 766 | `Request` has 4 new fields. New stub `install!`. `run!` is unchanged (it must call `install!`). The doc of `install!` is a table of 10 steps. |
| `cli/lib/Add.roc` | 223 | New stubs `no_release`, `check_held`. |
| `cli/lib/Intent.roc` | 375 | New stub `rename`. |
| `cli/lib/Ladder.roc` | 343 | The doc has the C6 rows. The body is not changed (the code agent changes it). |
| `tests/unit/opts.roc`, `report.roc` | 60, 72 | New. 2 + 2 `expect`s. |
| `tests/unit/add.roc`, `intent.roc`, `ladder.roc` | 271, 242, 238 | 2 new `expect`s and 1 row in `add`, 1 `expect` in `intent`, 4 rows (3 `expect`s) in `ladder`. |
| `tests/scenarios/add/ad1-add-entries`, `ad2-platform-json` | 39, 21 (lines of `cmd`) | New L3 cases. |
| `tests/scenarios/install/in1-workspace-frozen-rename` | 23 | New L3 case. |
| `tests/commands/cases/install/in1-flow` | 4 runs | New L2 case (entry `commands`). |
| `tests/commands/cases/resolve/rs-stale-key-ask` | 2 runs | New L2 case (the prompt with a tty). |
| `tests/commands/cases/resolve/rs-stale-key`, `rs-install-names` | 3, 3 runs | Changed (see "Old cases that changed"). |
| `tests/commands/FakeFx.roc` | 584 | `{w}` in `fx/args` and `fx/env`; `fx/probe-text`; `fx/hooks` (a concurrent edit). |
| `tests/commands/main.roc` | 466 | The entry `resolve` reads the new run words and fills the new `Request` fields. New entry `commands`. |
| `tests/lib.sh`, `tests/run.sh` | 65, 167 | `hexnorm`: the L3 runner maps `/talon/tmp/<16 hex>` to `/talon/tmp/$HEX`. |
| `tests/fixtures/add/make.py` | 97 | Writes the packages and the release pages of the 4 new cases. The hashes of slice 005 stay. |
| `research/slice-007-revert/` | 155, 90 | `mutate.py` and `results.md`: the record of the revert check. |

## Public signatures (stubs)

| Module | Signature | Body |
| --- | --- | --- |
| `Opts` | `Opts := { names, frozen, dry_run, no_check, no_probe, no_pin, as_platform, as_alias, strategy, snapshot, rename_keys, allow_moves }`, `read : Args -> Try(Opts, Fail)` | `crash "todo"` |
| `Report` | `Outcome : { at, probes, dry_run, check, build, added, moved, kept, pinned, toml, renamed, notes, written }`, `resolved_line : { at, probes } -> Str`, `data : Outcome -> JsonDoc` | `crash "todo"` |
| `Install` | `run! : Fx, Args => I32` | `crash "todo"` |
| `Resolve` | `install! : Fx, Request => Try(Report.Outcome, Fail)` | `crash "todo"` |
| `Add` | `no_release : { name, selector, text, versions } -> Fail`, `check_held : { name, range, held } -> Try({}, Fail)` | `crash "todo"` |
| `Intent` | `rename : { path, text, renames } -> Try(Str, Fail)` | `crash "todo"` |

`Resolve.Request` has the new fields `snapshot`, `dry_run`, `add : { as_platform, as_alias, no_pin }` and `prompt : { mode, yes, quiet, rename_keys }`. The L2 entry `resolve` fills them.

## Tests

| Layer | Test | Rules | What it fixes |
| --- | --- | --- | --- |
| L0 | `opts.roc` expect 1 | R-FL8 to R-FL13, R-CM2, R-CM19, R-CM20, R-AD25, R-AD27 | The options of `install`, `add`, `i`: values, global flags, `--frozen --dry-run` is allowed |
| L0 | `opts.roc` expect 2 | R-FL13, R-FL5, R-FL10, R-AD29, R-EC2 | The 4 usage failures and the order of the checks |
| L0 | `report.roc` expect 1 | R-DT5 | `resolved at <time>, <n> probes` (`1 probe`) |
| L0 | `report.roc` expect 2 | R-J3, R-J4, R-OUT4, R-OUT5, R-LF3 | The `data` keys in order, null for a step that did not run |
| L0 | `add.roc` row (platform) | R-AD31 | The platform is the entry with `is_platform`, not the alias `pf` |
| L0 | `add.roc` expect `no_release` | R-SL12, R-SL3, R-SL4 | The 3 close versions, newest first, nearest for an exact version |
| L0 | `add.roc` expect `check_held` | R-WS12, Q9, R-EC10 | Exit 10 and the text when the selector excludes the held version |
| L0 | `intent.roc` expect `rename` | R-NI1, R-I8, R-H1 | Only the bytes of the key change; the 3 failures |
| L0 | `ladder.roc` rows | C6, R-BL3 | `Fail(n)` with no readable error is `Internal` (exit 1) for the baseline, the check and the build |
| L3 | `add/ad1-add-entries` | P1 to P3, P5, P7, Q9 of 004, R-AD*, R-SL*, R-LF4, R-DT5 | 16 runs of `tln add` on the real binary |
| L3 | `add/ad2-platform-json` | P4, R-AD29 to R-AD33, R-SE7, R-J1 to R-J5, R-FL4 | `--platform`, `--json`, `--quiet`, the failure envelope |
| L3 | `install/in1-workspace-frozen-rename` | R-NI1, R-NM8, R-LF1, R-FL13, R-WS12, Q9, W2 | A workspace: stale key, `--frozen`, no current member, a held group, `probe` |
| L2 | `install/in1-flow` | M22, M26, R-CC7, R-PD9, R-SO7, R-DT5 | 4 runs: the call order, the copy, the candidate header, a concurrent edit, a package member |
| L2 | `resolve/rs-stale-key-ask` | R-NI1, R-NM4, R-NM6 | The prompt with a tty: answer `n`, then Enter |

## Output proposals (TW24, R-OUT1 to R-OUT5)

The design gives none of these texts. They are proposals for the review.

| Output | Text |
| --- | --- |
| R-DT5 line | `resolved at 2026-10-15T12:00:00Z, 3 probes`. Printed for `install` and `add` when an entry, a pin, a `talon.toml` key or a rename is planned. Not for `--frozen`, not for "nothing to change", not for a kept entry. It is the last line of stdout, before `dry run: nothing was written`. |
| Dry run | `dry run: nothing was written`. The plan lines are the same as for a write. |
| New entry | `+ <alias>: <name> <version>` under the file path. `~ <alias>: <name> <old> -> <new>` for a move. `+ roc: <id>` for the pin. |
| `talon.toml` | `<path>: <key> = "<value>"`. A rename: `<path>: key <from> -> <to>`. |
| Keep (R-AD21) | `<alias>: <name> <version> is in the header` and `Run tln update <alias> to move it.` |
| Platform change (R-SE7) | `note: platform changes: <old name> <old version> -> <new name> <new version>`. The text is in `data.notes` too. |
| Stale key report (R-I8) | `talon.toml: key "<key>" is "<name>", which the header names "<alias>"` (the text of `Consent.rename_keys`, also used by `Frozen.check`) |
| No close version (R-SL12) | `no release of <name> matches '<text>'. Close versions: <v>, <v>, <v>.` |
| Held version (Q9) | `no tuple works: '<range>' for <name> excludes the version <v> held by <file>, <file>. Moving a held version needs consent (R-NI3), which this version of tln cannot ask. Nothing was written.` Exit 10. |
| R-WS12 | `no current member in the workspace at <root>. Members: <file>, <file>. Pass --file <member file>.` Exit 2. |
| Option failures | `flag '--frozen' works only for tln install with no names`, `flag '--platform' names one entry: got <n> names`, `--strategy must be highest or lowest, not '<v>'`, `--registry '<v>': no registry exists in this version of tln. Use --registry direct.` |
| C6 | `the baseline check on <id> gave no result: <n> errors that tln cannot read. Run the command again.` (and the same for `the whole-app check`, `the build`) |
| `--json` `data` | `snapshot`, `probes`, `downloads` (0), `dry_run`, `check`, `build`, `added`, `moved`, `kept`, `pinned`, `toml`, `renamed`, `notes`, `written`, in this order. The `command` of the envelope is the word as typed (`add`, `i`). |

## Decisions that the design does not fix (TW17)

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `roc version` runs once for each run that is not `--frozen`, after the project is found and before the flow, also for a run that fails later. | Run it only when a probe needs it (the flow would need a lazy value in `Request`) |
| D2 | `Known.record!` runs before the flow, so a run that fails later, `--dry-run` and `--frozen` record the project (R-PD9). | Record only after a write |
| D3 | `Install` prints the R-DT5 line and the dry-run line after the lines of the flow. `Resolve.install!` prints the other lines. | The R-DT5 line first (the probe count is known only after the ladder); the line in `Resolve` (it changes the old L2 cases) |
| D4 | `--quiet` hides each stdout line, also with `--json`. With `--json` the human lines go to stderr through a `Fx` whose `out!` is `err!`. | `--json` keeps the human lines in a quiet run; a new field in `Request` |
| D5 | A full name that has one entry in the header (one repo, one variable) is that entry: Keep or Update with no index call. With `--platform` it is always a new entry (the platform is replaced). | Always ask the index (a Keep would cost a request) |
| D6 | The kind of the newest candidate (its header is read) decides before the pick: a wrong `--platform` is exit 2. | Let `Pick` fail with R-C4 (exit 10: P4 asks for exit 2) |
| D7 | A group that other members hold: the new entry gets the held version (range `=<held>`), after `Add.check_held`. | Pick the highest release (R-WS12 says held) |
| D8 | `install` and `add` ask to rename a stale key (R-NI1). The answer No keeps the key. `update` keeps the warning (slice 009). | Prompt in `update` too |
| D9 | `Intent.rename` renames keys of `[dependencies]` only. | `[overrides]` too (`Intent.spans` reads `[dependencies]` only) |
| D10 | `Report.Outcome` has `renamed`, and the platform note is in `notes`. | No field for renames (R-OUT4 says the data holds each fact of the text) |
| D11 | "nothing to change" is not printed when an entry was kept. | Always print it |
| D12 | `probes` is 3 for an app, 2 for a package or a platform, 0 with `--no-check`. `build` is `NotRun` when no member is an app. | Count the roc runs of the fake only |
| D13 | `--snapshot` is a UTC time, or `log:<n>` (usage failure with `direct`). The flag wins over `[resolution] snapshot` (R-EV1). | |

## Questions (TW17) and design gaps

| # | Question or gap | Default used in the tests |
| --- | --- | --- |
| G1 | R-SP16, R-SP17 and R-NI3 need a search with the held variables freed. `Pick.step` has none, so P0 cannot move a held variable. | Exit 10 and no write (the answer of the manager to Q9). The design gap goes to the user. |
| G2 | R-H4 (Talon never changes a path entry or a foreign URL) conflicts with R-RV5 (`remove` removes them). | Slice 008 |
| Q1 | Does `install` with a stale key and no flag stop with exit 13 in a CI run, or warn and go on? R-NI1 says "Required" (the table of CLI 4). | Exit 13 |
| Q2 | `data.command` for `i`: the word as typed (`i`) or `install`? | As typed (the `Out` doc of slice 001) |
| Q3 | `--no-probe` and `--slots` are read and change nothing (R-LF2: P0 has no unit probe). | No test |
| Q4 | The one design example of `add` (`tln add parser@2.0.0`, CLI 3 R-RG4) needs P2 (short name, `log:`, unit probes). | TW16: it becomes an L3 case in P2 |

## Answers of the manager (2026-10-20)

| # | Answer |
| --- | --- |
| Split | 007 `install` and `add`, 008 `remove`, 009 `update`, `list`, `why`, `verify`, closure walk, R-C8 |
| Q1 of the scope (R-H4 and R-RV5) | R-RV5 wins for `remove` only (slice 008) |
| Q2 | `add` of a selector with no release: exit 2 with the 3 nearest versions. `update` stays exit 10. |
| Q3, Q4, Q6, Q7, Q8 | The defaults of the scope file: `--platform` takes one name; R-DT5 for `install` and `add`; `--registry` is `direct` only; C6 is `NoFact`; `--frozen --dry-run` is allowed |
| Q9 | When the selector excludes the held version: exit 10 and nothing is written. The message names the members. |
| User answers | Q8 of slice 006: the stale key is the prompt R-NI1. Q4: the candidate header keeps absolute path entries (slice 006b rewrites path prefixes: this slice tests only the text of the candidate header). Q1: slice 006b changes `Probe.classify`. The design says exit 18 for "no compiler": no change in the code. |

## Old cases that changed

| Case | Change | Why |
| --- | --- | --- |
| `resolve/rs-install-names` | Run 1 (`install json`) prints the Keep note. Run 2 (`install nosuch`) is exit 2 (short name). The rules text is new. | `install` with names is `tln add` (R-SP18) |
| `resolve/rs-stale-key` | 3 runs: no flag (exit 13), `rename-keys` (the key is renamed), again (nothing to change). The warning of D15 is gone. | Q8 of slice 006: the prompt R-NI1 |
| `tests/commands/FakeFx.roc`, `main.roc` | New opt-in features only. No old case changed its output. | |

All other old tests pass with the stubs: 20 L2 cases of 24, 17 L3 cases of 21 (1 skipped), all L0 files but the 5 below.

## Red output (stubs)

`scripts/test.sh`: check and fmt pass, selftest passes. No compiler error in any test.

| Layer | Result |
| --- | --- |
| L0 | `add` 2 failed of 6, `intent` 1 of 4, `ladder` 3 of 4, `opts` 2 of 2, `report` 2 of 2. The failures are `crash "todo"` or the old value (`ladder`: the C6 rows get the pass of the old code). |
| L2 | 4 failed: `install/in1-flow` (`todo`), `resolve/rs-install-names`, `resolve/rs-stale-key`, `resolve/rs-stale-key-ask` (the old output of `Resolve.run!`). 20 passed. |
| L3 | 3 failed: `add/ad1-add-entries`, `add/ad2-platform-json`, `install/in1-workspace-frozen-rename` (`[ROC CRASHED] todo`). 17 passed. |

## Revert check

76 changes of the private reference, in `research/slice-007-revert/results.md`: 75 caught, 1 not caught (D12, an equivalent change). Rows that did not compile were rewritten (a warning stops `roc build`) and run again.

| Group | Rows | Caught by |
| --- | --- | --- |
| `Opts` | O1 to O11 | L0 `opts` |
| `Report` | R1 to R8 | L0 `report` |
| `Add`, `Intent`, `Ladder` | A1 to A7, I1 to I3, C1 to C4 | L0 `add`, `intent`, `ladder` (A6 is the R-AD31 row that slice 004 did not catch) |
| `Resolve` and `Install` (add) | D1 to D14, P1 to P9 | L3 `add/ad1`, `add/ad2` |
| `Resolve` and `Install` (workspace, prompt) | W1 to W14 | L3 `install/in1`, L2 `rs-stale-key`, `rs-stale-key-ask`, `rs-install-names` |
| `Resolve`, `Ladder`, `Guard` (flow) | F1 to F7 | L2 `install/in1-flow` (F1 is M22, F2 is M26 of slice 006: both not caught before) |

## Not covered (reported, not hidden)

| Item | Reason |
| --- | --- |
| The answer No of the prompt with other changes in the same run | One case shows No alone (`rs-stale-key-ask`) |
| `update` with a stale key (the warning) | Slice 009 builds `update` |
| 2 or more members that change in one `install` | The ladder of slice 006 tests the members; no case here |
| `--no-probe`, `--slots` | P0 has no unit probe (R-LF2) |

## Out of scope

| Id | Reason |
| --- | --- |
| R-AD3 to R-AD5, R-AD34 to R-AD37 | Registry (P2) |
| R-NI3, R-SP16, R-SP17 | Design gap G1 |
| R-CM3, R-RV1 to R-RV5, R-SC1 for `remove` | Slice 008 |
| R-CM4, R-CM7, R-CM9, R-CM11, R-SP4, R-C8, the closure walk | Slice 009 |
| R-LF2 | No unit probe in P0 |
| R-WS13 | `tln roc use` is P1 |
| R-NI4 to R-NI16 | Downloads and other commands (P1) |

## Next step

Human review of the tests and of the output proposals (TW24). Then the code agent writes the bodies: `Opts.read`, `Report`, `Install.run!`, `Resolve.install!` (and `run!` as a call of it), `Add.no_release`, `Add.check_held`, `Intent.rename` and the C6 change of `Ladder` (the three `Fail(n)` branches). The code agent does not edit tests (TW18).

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Verify results (code agent, 2026-10-20)

`scripts/test.sh` exit 0: check 2.8 s, fmt 0.1 s, L0 38 files pass (6.5 s), L2 24 cases pass (31.5 s), L3 20 pass and 1 skipped (9.1 s), selftest pass (5.8 s). Total 56 s.

Files written (lines now): `Opts.roc` 95, `Report.roc` 111, `Install.roc` 190, `Resolve.roc` 1234, `Add.roc` 290, `Intent.roc` 390, `Ladder.roc` 364. Not touched: `Probe.classify`, `tests/unit/probe.roc`, the path rewrite util (slice 006b).

Signature change: `Ladder.run!` gives `Try(List(Str), Fail)` (the text of each `note:` line, for `Report.Outcome.notes`) in place of `Try({}, Fail)`. It prints the lines as before. `Resolve.ladder!` gives a record with the probe count and the state of the steps. No test calls either.

Revert check (TW12): `research/slice-007-revert/code-mutate.py`, rows in `research/slice-007-revert/code-results.md`. Caught 54 of 57. The dir `cli/` after the run equals the copy before it (`diff -r`).

| Id | Rule | Mutation | Result |
| --- | --- | --- | --- |
| D12 | R-H3 | The id of the slot of a new name has no `pf` for `--platform` | NOT CAUGHT. The id shows only in the message of a failed pick of a new name. No case makes that pick fail. |
| M1 | R-LF3 | `--no-check` gives `check: Passed` in the outcome in place of `Skipped` | NOT CAUGHT. No case has `--no-check` with `--json`, and no `Report.data` test starts from a real run. |
| F6 | R-PD9 | The canonical path of a member is not used for the record (the given path is used) | NOT CAUGHT. The fake `canonical!` and the real one give the same path in these cases (no link). The call is still checked by `calls.log`. |

Decisions of the code agent that the slice does not fix:

| # | Decision | Options rejected |
| --- | --- | --- |
| C1 | `Add.decide_alias` of a name that is a header alias or a one-entry repo gives `Keep` (kept, no change) or the entry is named for the pick as `update X@sel` (`Vars.scope` with the command `Update`, so only the named variables are free). With names, the scope is `Update` for the moved entries; with no name or only new names it is `Install`. | Scope `Install` with names (`Vars.scope` ignores the names then) |
| C2 | The kind of a new name is read from the first candidate of its URL form in the order of the index page (the GitHub API lists the newest first). The header of that candidate is a start fact of the pick (no second fetch). `in1-flow` shows this order (`GuxBH...` is util 1.0.0). | The candidate with the highest `published_at` (the call log of `in1-flow` names the first one) |
| C3 | The alias of a new name is checked with `Add.decide` before the pick (with the URL of that first candidate), so a bad alias stops the command before any pick. The same `Add.decide` runs again with the chosen URL for the edit. | Check only after the pick |
| C4 | A new name whose selector admits no candidate is `Add.no_release` with the versions of all candidates of the repo. A repo with no candidate gives the same message with no versions. | A new failure text |
| C5 | A run that kept an entry or changed nothing prints no R-DT5 line. The `Outcome` lists (`added`, `moved`, `toml`, `renamed`, `pinned`, `written`) hold only the files that changed (dry run: the files of the plan). `kept` is the same for both. | Always the plan |
| C6 | Stale keys of `[overrides]` keep the warning of slice 005 (D9). Only `[dependencies]` keys go to the prompt R-NI1. | Prompt for both |
| C7 | `--snapshot` that is neither `log:<n>` nor a UTC time: usage failure `--snapshot '<text>' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z.` (a proposal, TW24, no test). | |
| C8 | `--platform` takes the platform variable of the header out of the pick (R-AD31): the new platform is the one platform slot. | Keep the old platform as a held slot (2 platform slots break R-C3) |

## Review (manager, 2026-10-20)

The decisions D1 to D13 are accepted. The output texts and the `--json` fields are accepted as proposals (TW24). The extra L2 case `rs-stale-key-ask` is accepted. The answers below are proposals of the manager. The user did not confirm them yet.

| # | Answer |
| --- | --- |
| Q1 | The default: a stale key with no answer flag in a non-interactive run stops with exit 13. R-NI1 is "Required". |
| Q2 | The default: `data.command` is the word as typed (the same as slice 001 Q3) |
| Q3 | The default: `--no-probe` and `--slots` are read and change nothing in P0 |
| Q4 | The default: the design example `tln add parser@2.0.0` is an L3 case of P2 |
| G1, G2 | Reported to the user. G1 uses the answer Q9 of the scope review (exit 10, nothing written). |

User answers that touch this slice: slice 006 Q8 (the prompt) is confirmed. Slice 006b (after this slice) changes `Probe.classify` for exit 134 and adds the path rewrite util. The code agent of slice 007 does not do these.

## Review of the code (manager, 2026-10-20)

`scripts/test.sh` passes (manager run: l0 7.0 s, l2 34.9 s, l3 9.1 s). The revert check of the code caught 54 of 57.

| Item | Decision |
| --- | --- |
| C1, C3 to C8, the `Ladder.run!` signature | Accepted |
| C2: the kind of a new name comes from the first candidate in page order, not the newest (D6) | Not accepted. D6 (accepted) says the newest candidate. The call log of `install/in1-flow` fixes the other choice: a test bug. Slice 006b: the test agent changes the expected file, the code agent changes the code. |
| M1 not caught (`--no-check` with `--json` gives `check: passed`) | Slice 006b adds a row: `data.check` is `skipped` (R-LF3, R-BL6). |
| D12, F6 not caught | Accepted: D12 shows only in a message of a pick that fails, and F6 needs a symlink in the project path. |
| New limit: `has` and `platform` are reserved | Added to the briefs of the next agents |
