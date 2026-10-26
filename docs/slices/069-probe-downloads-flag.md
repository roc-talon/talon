# 069 `--probe-downloads` only where it works

Phase: P1. Status: done

Slice 069 is the plan row 069 of `PLAN-P1.md` (section 2c). It closes the question Q4 of slice 037d. Design change (design agent, 2026-10-25, `DESIGN-GAPS-2026-10-25.md` rows "037d, Q4" and "(gap added) 037d, Q4 code"): R-NI4 and the flag table name `upgrade`, `probe` and `init` for `--probe-downloads`. The other commands that resolve hold the nightly (R-RP2), so they have no optional download. By R-FL12 the flag on another command is exit 2.

## 1. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-FL12 | A flag that the table does not name for the command: exit 2 | L0 `ArgsTest`, `OptsTest`, `RemovalTest`; L3 `flags/fl12-bad-flags` |
| R-NI4 | `--probe-downloads` is for `upgrade`, `probe`, `init` (the table in CLI 1) | same |
| R-FL7 (as used) | `init` takes `--probe-downloads` of the resolve flags | L0 `ArgsTest` (`init` row stays), `OptsTest` |

## 2. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Args.allows`, flag `--probe-downloads` | `one_of(["upgrade", "probe", "init"])` (now: `resolving or one_of(["probe", "init"])`). `add` and `i` have the long form `install`. |
| 2 | `Opts.read`, field `probe_downloads` | `Ok(Yes)` only when the flag is given and `args.command` is `["upgrade"]`, `["probe"]` or `["init"]`. Else `Err(NoFlag)`. A second guard: `Args.parse` stops the other lines first. |
| 3 | Comments | The docs of `Removal.opts`, `Opts` (field table), `Init.roc` that say "`--probe-downloads` is read and changes nothing" are old: change them. `Install`, `Update`, `Verify` keep `probe: opts.probe_downloads` (it is `Err(NoFlag)` there now). |

No new type, no new `Fx` call, no new function. No stub is needed: the tests call `Args.parse` and `Opts.read`, which exist, so the new rows fail with a wrong value.

## 3. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/ArgsTest.roc`, `accepted` (changed) | The 3 old rows lose `--probe-downloads` (`install`, `update`, `verify`). New rows: `upgrade` and `probe` take it. (`init` row is old.) | R-FL12, R-NI4 |
| L0 | same file, the failure messages (changed) | 9 new rows: `install`, `add`, `i`, `remove`, `update`, `verify`, `tool install`, `x`, `path` with `--probe-downloads` give `flag '--probe-downloads' is not for '<long form>'`. `add` and `i` show `install` (R-CM19) | R-FL12, R-NI4 |
| L0 | `tests/unit/OptsTest.roc`, answer flags (changed) | Old rows `install`, `add`, `verify` with the flag are now the failure text. New rows: `upgrade`, `upgrade roc`, `probe`, `init` read `Ok(Yes)` | R-NI4, R-FL12 |
| L0 | same file, new `expect` | `Opts.read` of a parsed `upgrade` line with the command words of `install`, `update`, `verify` or `remove` gives `Err(NoFlag)`. `upgrade`, `probe`, `init` give `Ok(Yes)` | R-NI4, R-FL12 |
| L0 | `tests/unit/RemovalTest.roc`, `remove` flags (changed) | `rm json --probe-downloads` (with and without `--allow-downloads`) is the failure text. `rm json --allow-downloads --yes` is `Ok(Yes)` | R-FL12, R-NI4 |
| L3 | `tests/scenarios/flags/fl12-bad-flags` (2 lines added) | `tln install --probe-downloads` and `tln verify --allow-downloads --probe-downloads`: exit 2, the message on stderr, nothing else written | R-FL12, R-NI4, R-EC2 |

Counts: 1 new `expect` (OptsTest) and 3 changed `expect`s with new rows, 1 changed L3 case (2 lines). The old copies are in `research/slice-069-revert/before/` (`NEW.txt` is empty: no new file).

Red run (2026-10-25, the old code): `l0-5` (`ArgsTest.roc:162`: the new messages are empty), `l0-6` (`OptsTest.roc:62` and the new `expect`: the flag is read for `install`, `add`, `verify`), `l0-2` (`RemovalTest.roc:110`), `tests/run.sh flags/`: the stderr of the new lines differs. All fail with a wrong value, none with a compile error. The L2 harness (`tests/commands/main.roc`, `L2Resolve.roc`) builds its `Request` from the words and never goes through `Args`: the word `probe-downloads` for `install` and `update` lines there is not a user path. No case uses it with those commands (`grep` of the `fx/` files), so no L2 file changes.

## 4. Output

No new text. The failure message is the one of R-FL12 that exists: `flag '--probe-downloads' is not for '<command>'`.

## 5. Out of scope

| Item | Reason |
| --- | --- |
| `--allow-downloads` for other commands | Not part of the row. The flag table is unchanged for it |
| `Help` text per command | `Help` does not list the flag by command |

## 6. Questions

None.

## 7. Revert check (private reference, deleted after the review)

| # | Mutation of the reference | Result |
| --- | --- | --- |
| 1 | `Args`: add `update` to the commands of the flag | `ArgsTest` fails |
| 2 | `Args`: drop `init` | `ArgsTest` and `OptsTest` fail |
| 3 | `Opts`: no command guard | `OptsTest` (new `expect`) fails |
| 4 | `Args`: the old rule (`resolving or one_of(["probe", "init"])`) | `flags/fl12-bad-flags` fails |

The reference passes all of l0-2, l0-5, l0-6 and `tests/run.sh flags/`. After the check `cli/lib/Args.roc` and `Opts.roc` are the old files again (cmp with `before/`).

## 8. Review

Accepted by the manager, 2026-10-25, with the `Opts.read` second guard.

## 10. Verify results (code agent)

Files: `cli/lib/Args.roc` (1 line), `cli/lib/Opts.roc` (field, helper `probe_command`, doc row), `cli/lib/Removal.roc` (2 comments). Decision: the command guard is a helper `probe_command` that compares `args.command` with the 3 word lists; no option rejected. No dispute, no question.

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | `Args`: add `update` to the commands of the flag | `ArgsTest` (l0-5) |
| 2 | `Args`: drop `init` | `ArgsTest` (l0-5) and `OptsTest` (l0-6) |
| 3 | `Opts`: no command guard | `OptsTest` (l0-6, the new `expect`) |

Caught 3 of 3. `Args.roc` and `Opts.roc` are the same as before the mutations (cmp).

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-069-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, all 3 slices in) | Exit 0, all 7 steps |
| Gap step | Skipped: all code-agent mutations caught (12 of 12 over the 3 slices), no new decision |
