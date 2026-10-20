# 009 `update`, `update -i` and `verify`

Phase: P0. Status: done

This slice builds 3 commands: `tln update` (also `up`), `tln update -i` (the picker) and `tln verify`. The split of the first scope is accepted (see "Review of the scope" at the end). `list`, `why` and the closure walk are in `010-closure-list.md` and `011-why.md` (status `scope`). The scope agent and the test agent are one agent. The code agent writes the bodies (TW18). A private reference implementation checked the tests (TW12) and was deleted.

`update` is the flow of `install` (`Resolve.resolve!`) with the command `Update`: the same scope, pick, ladder and write, with the changes in the table "Changes in `Resolve`". `verify` is the same flow in memory: it writes nothing, and the ladder runs with `roc check --replace-dep` in the project dir (no temp copy, see D1).

## Rules of the slice

| Group | Ids | Where the test is |
| --- | --- | --- |
| Commands | R-CM4, R-CM19 (`up`), R-CM11 | L0 `update`, L3 `update/up1`, `verify/vf1`, L2 `update/up1-flow`, `verify/vf1-flow` |
| Flags | R-FL5, R-FL8 to R-FL10, R-FL12, R-FL13 (`update` rejects `--frozen`), R-FL14 (`verify` rejects `--frozen` and `--dry-run`) | L0 `update`, L3 `up1`, `vf1` |
| Names and picks | R-SP2 to R-SP5, R-SP11, R-SP14 (list order), R-NR4 (`-i` has a command form), R-NI2, R-NM7 (no picker without a person) | L0 `picker`, `update`, L2 `up1-flow`, L3 `up1` |
| Notes and output | R-SE7 (platform notice), R-SL12 (close versions, Q5), R-DT5, R-PD9, R-J1 to R-J5, R-OUT4, R-EC2, R-EC10, R-EC11, R-E4 | L0 `add`, L3 `up1`, `vf1`, L2 old cases |
| Header and key rules | R-I5 (`update` adds no key, Q3), R-H4 (a path entry is not changed, Q8), R-C7 (a named version ignores min-release-age) | L2 `up1-flow` run 4, L3 `up1` |
| `verify` | R-LB1, R-LB2, R-LB4, R-LD4, R-LD6, R-LD7 (no build for a package), R-LF3 (`--no-check`), R-LF4, R-BL1, R-BL5, R-BL6, R-PP3, R-PH8, R-PH10, R-PH13, R-CC2, R-SO7, R-RP2 | L0 `verify`, L3 `vf1`, L2 `vf1-flow` |

## Files

| File | Lines | What |
| --- | --- | --- |
| `cli/lib/Picker.roc` | 30 | New. `Picker.Item`, `text`, `question`, `reply` (part A, stubs) |
| `cli/lib/Update.roc` | 45 | New. `Update.read`, `Update.run!` (stubs) |
| `cli/lib/Verify.roc` | 40 | New. `Verify.read`, `Verify.run!` (stubs) |
| `cli/lib/Resolve.roc` | +30 | Stubs `Resolve.picks!`, `Resolve.verify!`, and the doc table of the changes below |
| `cli/lib/Ladder.roc` | +27 | `Replace`, `plan_replace`, `Checked`, `verify!` (stubs) |
| `cli/lib/Probe.roc`, `Add.roc` | +5, +11 | `Probe.replace_args`, `Add.platform_note`, `Add.close_note` (stubs) |
| `cli/lib/Run.roc`, `main.roc` | +6, +3 | Dispatch of `update`, `up`, `verify`. Exposes `Picker`, `Update`, `Verify` |
| `tests/unit/update.roc`, `picker.roc`, `verify.roc` | 74, 44, 65 | New L0 tests |
| `tests/unit/add.roc` | +2 expects | Notes |
| `tests/scenarios/update/up1-update-entries`, `verify/vf1-verify` | 29, 21 (`cmd`) | New L3 cases |
| `tests/commands/cases/update/up1-flow`, `verify/vf1-flow` | 5 runs each | New L2 cases |
| `tests/fixtures/add/make.py`, `hashes.txt` | +repo `acme/pfx` | The platform of the new cases (2 releases) |

## Public signatures (the code agent keeps them)

| Function | Signature |
| --- | --- |
| `Picker.text` | `List(Picker.Item) -> Str` |
| `Picker.reply` | `{ items, line } -> Try(List(Str), [Invalid])` |
| `Update.read` | `Args -> Try({ opts : Opts, pick : Bool }, Fail)` |
| `Update.run!`, `Verify.run!` | `Fx, Args => I32` |
| `Verify.read` | `Args -> Try(Opts, Fail)` |
| `Probe.replace_args` | `{ command, file, replace : List({ old, new }) } -> List(Str)` |
| `Ladder.plan_replace` | `{ compiler, kind, dir, file, tmp, replace, timeout } -> Plan` |
| `Ladder.verify!` | `Fx, { roots, path_roc, held, members, replace, owners, moved } => Try(List(Str), Fail)` |
| `Add.platform_note` | `{ from : { name, version }, to : { name, version } } -> Str` |
| `Add.close_note` | `{ selector, versions } -> Str` |
| `Resolve.picks!` | `Fx, Request => Try(List(Picker.Item), Fail)` |
| `Resolve.verify!` | `Fx, Request => Try(Report.Outcome, Fail)` |

`Resolve.Request` is unchanged. Its `command` is `Update` for `update`. `verify` uses `Resolve.verify!`, not `resolve!`.

## Changes in `Resolve` for `command: Update` (doc table in `cli/lib/Resolve.roc`)

| # | Change | Rule |
| --- | --- | --- |
| U1 | No want from `talon.toml` for `update` (a key that the header lacks has no effect and no entry) | R-I5, Q3 |
| U2 | The notice `platform changes: ...` when the platform changes (same text as `add`) | R-SE7 |
| U3 | The failure `has no release that satisfies` gets ` Close versions: ...` (exit 10) | R-SL12, Q5 |
| U4 | A name that is a path entry fails: `'<alias>' is a path entry: Talon never changes it` | R-H4, Q8 |

## Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `update`: `Update.read` rows (12) | R-CM4 R-CM19 R-FL5 R-FL8 to R-FL10 R-FL12 R-FL13 R-SP4 R-NR4 |
| L0 | `update`: `Verify.read` rows (11) | R-CM11 R-FL14 R-FL5 R-FL7 R-LB2 |
| L0 | `picker`: `Picker.text`, `question` | R-SP14 R-NI2 R-NR2 R-OUT2 |
| L0 | `picker`: `Picker.reply` (14 rows) | R-SP4 R-SP14 R-SP11 R-NM7 |
| L0 | `verify`: `Probe.replace_args` (5 rows) | R-CM11 R-LB2 R-P1 R-SE4 |
| L0 | `verify`: `Ladder.plan_replace` | R-LB2 R-LD1 R-LD6 R-LD7 R-BL1 R-PP3 |
| L0 | `add`: `platform_note`, `close_note` | R-SE7 R-AD31 R-SL12 R-SL3 R-SL4 R-EC10 |
| L3 | `update/up1-update-entries` (12 runs) | R-CM4 R-CM19 R-SP2 R-SP4 R-NM7 R-FL13 R-SL12 R-DT5 R-SE7 R-I5 R-H4 R-J1 to R-J5 R-C7 |
| L3 | `verify/vf1-verify` (6 runs and the files check) | R-CM11 R-LB1 R-LB2 R-LB4 R-FL14 R-LF3 R-LD7 R-J1 to R-J5 |
| L2 | `update/up1-flow` (5 runs: no tty, picker invalid then valid, empty, plain, end of input) | R-SP4 R-NI2 R-NM7 R-NR4 R-SE7 R-DT5 R-I5 |
| L2 | `verify/vf1-flow` (5 runs: app, package, new error in a package, new error in an app, tuple equals header) | R-CM11 R-LD4 R-LD7 R-PH10 R-PH13 R-EC10 R-EC11 R-CC2 R-SE7 |

L0 count: 8 new expects (2 in `update`, 2 in `picker`, 2 in `verify`, 2 in `add`). Deep cases: 4 (2 L3, 2 L2).

## Old cases that changed (Q3 and the new texts)

| File | Change | Why |
| --- | --- | --- |
| `tests/commands/cases/resolve/rs-failures/expect/stderr` | 2 lines get ` Close versions: 3.0.0, 2.2.0, 2.1.0.` | Q5 (U3) |
| `tests/commands/cases/resolve/rs-new-toml/expect/stderr` | 1 line gets ` Close versions: 2.2.1, 2.2.0, 2.0.0.` | Q5 (U3) |
| `tests/commands/cases/resolve/rs-update-scope/expect/stdout` | New line `note: platform changes: acme/pf 0.1.0 -> acme/pf 0.1.1` in run 2 | R-SE7 (U2) |

Q3 needed no change of an old file: no old case had a stale key with `update`. The old content of these files is in `research/slice-009-revert/before-tests/`.

## Output proposals (TW24, for the human review)

| Item | Text |
| --- | --- |
| Picker list (stderr) | `update can move these packages:` then `  <n>) <alias padded to longest+2><name> <version>` |
| Picker question | `Pick packages to update (numbers or names, empty for none): ` |
| Empty pick | `nothing picked`, exit 0 |
| End of input in the picker | usage failure, exit 2: `update -i needs a person to pick. Name the packages: tln update X Y.` |
| `-i` with names | `update -i picks the packages: do not name packages` |
| `verify` last line | `verified: the tuple passes. Nothing was written.` |
| `verify` rejects | `tln verify writes nothing, so it rejects --frozen` (also `--dry-run`), `tln verify takes no name` |
| Platform notice | `note: platform changes: <old name> <old version> -> <new name> <new version>` (also in `data.notes`) |
| Close versions | ` Close versions: a, b, c.` after the message of exit 10 |
| Path entry named by `update` | `'<alias>' is a path entry: Talon never changes it` |
| `verify --json` | `data` is the `data` of `install` with `written` empty. `command` is the word as typed |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `verify` has no temp copy: baseline and candidate check run in the project dir, the candidate with `--replace-dep`. A temp dir holds the build output only. The pinned roc has the flag. | The copy of the ladder (design R-CM11, R-LB2 say the flag) |
| D2 | `verify` with no replacement still runs baseline, candidate and build (Q4) | Skip the ladder when the tuple equals the header |
| D3 | `verify` prints no `resolved at` line and writes no `+ roc:` line | Print them like `install` |
| D4 | `verify --no-check` prints `check: skipped` (R-LF3) | Reject the flag |
| D5 | `Opts.read` runs on the line without `--frozen`, so the order of checks is Opts, `--frozen`, `-i` with names | The order of `Opts.read` (its `--frozen` check first) |
| D6 | The picker asks after `Known.record!` and before the compiler call. End of input is a usage failure. | Ask after the compiler call |
| D7 | `update` needs no member for R-WS12 (it names packages that exist) | Same check as `add` |
| D8 | `Request` is unchanged. New functions `Resolve.picks!` and `Resolve.verify!`. | New fields in `Request` |

## Questions (TW17) and design gaps

| # | Item |
| --- | --- |
| G1 | Stays from slice 007: `Pick.step` cannot search with freed held variables (R-SP16, R-SP17, R-NI3). `--allow-moves` is read and changes nothing. |
| G2 | `Vars.build` fails for `update` on a workspace with 2 members when a name is in no header (R-WS6 text). No case. The code agent follows the text of `install`. |
| G3 | No case for `verify` on a workspace, and none for a foreign URL named by `update`. |
| Q-none | No new question. Q1 to Q8 use the answers of the manager. |

## Out of scope

| Ids | Reason |
| --- | --- |
| R-SP16, R-SP17, R-NI3, effect of `--allow-moves` | G1 |
| `list`, `ls`, `why`, closure walk, R-C8, R-H7, R-PH12 | Slices 010 and 011 |
| R-NI4, R-NI5, R-EF*, `compat.db` | P1 (no unit probe) |
| R-LB3 (`tln probe --range`) | P1 |
| R-WS12 for `verify` | No workspace case (G3) |

## Red output (stubs, `scripts/test.sh`, 2026-10-20)

| Step | Result |
| --- | --- |
| check, fmt, selftest | pass |
| l0 | FAIL: `update`, `picker`, `verify`, `add` (`todo` and the new rows). All other files pass |
| l2 | 22 passed, 5 failed: `update/up1-flow`, `verify/vf1-flow`, `resolve/rs-failures`, `resolve/rs-new-toml`, `resolve/rs-update-scope` |
| l3 | 22 passed, 2 failed, 1 skipped: `update/up1-update-entries`, `verify/vf1-verify` |

## Revert check (TW12)

The record is `research/slice-009-revert/results.md` and the script `mutate.py`. 82 rows. 75 caught, 7 not caught.

| Not caught | Reason |
| --- | --- |
| U5 | Equivalent change (same text for `--frozen` with names) |
| L6 | Gap: no case where the held compiler is missing in `verify` |
| F5 | Gap: the platform note dedupe needs a workspace |
| F7 | Gap: no other `no_tuple` failure after a named update |
| F9 | Gap: no picker case with a Fixed host entry |
| F16 | Gap: the replace dedupe needs 2 members |
| F17 | Gap: the probe count of `verify` is not in an output |

Rows that were first not caught and now are: U6, K3, K9 (a row `js` was added to the picker reply), L5 (the old pattern hit the install ladder), and the rows R3, L4, F6, F8, F10, F14 that did not compile.

## Review of the scope (manager, 2026-10-20)

The split is accepted (see `PLAN.md`): this file is slice 009 (`update`, `update -i`, `verify`). Slices 010 and 011 get their own files, and take Q9 to Q15 from here. The answers are proposals of the manager. The user did not confirm them yet.

| # | Answer |
| --- | --- |
| Q1, Q2 | The defaults |
| Q3 | A bug of slice 005: `update` adds no `talon.toml` key that the header does not have (R-I5). The test agent changes the old expected files that fix the bug, and records each one. |
| Q4 | Yes: `verify` always runs the ladder. That is its job (R-CM11). |
| Q5 to Q8 | The defaults |
| Q9 to Q15 | The defaults, for slices 010 and 011. They can change when those slices are scoped. |
| `--replace-dep` | R-CM11 and R-LB2 say `verify` uses `roc check --replace-dep`, and slice 006 uses a temp copy. Check whether the pinned `roc` has `--replace-dep` (`roc check --help`). If it has it, `verify` follows the design. If not, `verify` uses the copy of the ladder, and this is a design gap for the user. |

## Review of the tests (manager, 2026-10-20)

D1 to D8 and the output proposals (TW24) are accepted. D1 follows the design (R-CM11, R-LB2): the pinned `roc` has `--replace-dep`. The 3 changed old expected files are accepted (Q5, R-SE7). The 6 gaps of the revert check (L6, F5, F7, F9, F16, F17) and G2, G3 are accepted for P0: each needs a workspace or a case that P0 does not test. Status: code.

## Disputes (from the code agent)

None. No test, fixture or expected file was changed by the code agent.

## Verify results (code agent, 2026-10-20)

`scripts/test.sh` exit 0: check 6.2 s, fmt 0.1 s, L0 44 files pass (9.0 s), L2 27 cases pass (43.7 s), L3 24 pass and 1 skipped (9.3 s), selftest pass (5.9 s). Total 74 s. The red items of the stubs are green: L0 `update`, `picker`, `verify`, `add`; L2 `update/up1-flow`, `verify/vf1-flow`, `resolve/rs-failures`, `resolve/rs-new-toml`, `resolve/rs-update-scope`; L3 `update/up1-update-entries`, `verify/vf1-verify`.

Files written (lines now): `Picker.roc` 56, `Update.roc` 172, `Verify.roc` 104. Changed: `Resolve.roc` 1759 (+185: `prepared!`, `pick!`, `with_close_versions`, `picks!`, `verify!`, `verified!`, `moved_platform_notes`, `owner_rows`, `checked_members`, the changes U1 to U4), `Ladder.roc` 491 (`plan_replace`, `verify!`, `verify_member!`, `print_lines!`), `Probe.roc` 270, `Add.roc` 304, `Consent.roc` 86 (`no_person`). `Run.roc` and `main.roc` needed no change (the test agent made the dispatch). `install!` and `remove!` were not moved to other modules: `install!` now calls `prepared!` and `pick!` (the same code, in the same order), and `resolve!` calls `pick!` and `finish!`.

Revert check (TW12): `research/slice-009-revert/code-mutate.py`, rows in `research/slice-009-revert/code-results.md`. Caught 57 of 64. `cli/` after the run equals the copy before it (`diff -r`, and `code-before.sha256`).

| Id | Rule | Mutation | Result |
| --- | --- | --- | --- |
| L4 | R-PH7 | `Ladder.verify!` does not call `Compiler.require` | NOT CAUGHT. No `verify` case has a missing held compiler (the test agent's gap L6). |
| F5 | R-SE7 | `moved_platform_notes` does not remove a repeated note | NOT CAUGHT. It needs 2 members that use the platform (no workspace case). |
| F10 | R-RP2 | `Resolve.verify!` does not call `check_pin` | NOT CAUGHT. No `verify` case has a pin outside `[toolchain] roc`. |
| F12 | R-CM11 | `replace` is not made unique | NOT CAUGHT. It needs 2 members (the test agent's gap F16). |
| F17 | R-LD7 | `build` of the outcome is `Passed` for a package | NOT CAUGHT. Only an app has `--json` output in the cases. |
| W13 | R-NM7 | An empty picker list still asks | NOT CAUGHT. No case has a project with no free package (decision C4). |
| X3 | R-CM11 | `verify` request has `dry_run: true` | NOT CAUGHT. Equivalent: `verified!` reads no `dry_run`. |

Decisions of the code agent that the slice does not fix:

| # | Decision | Options rejected |
| --- | --- | --- |
| C1 | `Update.read` and `Verify.read` call `Opts.read` on `{ ..args, options: <without --frozen> }` (the record update works on `Args`), then check `--frozen` themselves (D5). | Change `Opts.read` |
| C2 | `Resolve.install!` and `Resolve.verify!` share `prepared!` (files, variables, pin decision) and `pick!` (steps 2 to 7: names, scope, index, pick). `verified!` is the part of `verify!` after the pick. | A copy of the flow |
| C3 | New public value `Consent.no_person` (the usage failure of a picker with no person). `Consent.picker(NonInteractive)` and the end of input in `Update` both use it (a `match` on the constant mode is a compile warning). | The text twice |
| C4 | `update -i` with no free package prints `nothing picked` and asks nothing. | Print an empty list and ask |
| C5 | U1: `update` and `verify` ignore each want of `talon.toml`, also a short name (no failure). | Keep the short-name failure |
| C6 | U2: the note is made from the `Moved` edits of the platform variables, with no repeated text. It is printed after the pick notes and before the notes of `add`. In `Outcome.notes` it has the same place. | Print it in `Add.decide` only |
| C7 | U3: the close versions are for a free variable that has a selector (`update X@sel`, also `install X@sel`) and a failure of kind `NoTuple` with `has no release that satisfies`. The versions are all candidates of the repository (not only its series). | Only the group versions |
| C8 | U4: the check is in the failure branch of `Lookup.find`, over the rows of all members. An alias that is a variable in another member is found by `Lookup` first. | A check before the lookup |
| C9 | `verify` with `--file` that names a member checks that member only (the doc of `Verify`). Replacements and `~` lines are for its uses only. Without a current member all members are checked. No test (G3). | All members always |
| C10 | `verify` prints the `verified:` line also for `--no-check`, after `check: skipped`. | No line |
| C11 | `Update.flow!` calls `Resolve.picks!` with a request whose `compiler` is `Err(NoCompiler)`: `picks!` does not read it. | Move the compiler step before the picker (the L2 log fixes the order) |

## Review of the code (manager, 2026-10-20)

`scripts/test.sh` passes (manager run). The revert check of the code caught 57 of 64. C1 to C11 are accepted. Not caught, moved to slice 010 (the test agent adds a short run for each): L4 (`verify` with no compiler), F10 (`verify` with a pin outside `[toolchain] roc`), W13 (`update -i` with no free package asks nothing), F17 (`--json` of `verify` for a package). F5, F12 and the `verify --file` rule need a workspace case: accepted as gaps for P0. X3 is an equivalent change. `cli/lib/Resolve.roc` has 1759 lines: slice 010 moves `install!`, `remove!` and `verify!` to their own modules before it adds the closure walk.
