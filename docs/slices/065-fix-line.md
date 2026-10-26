# 065 The fix block of a failed `tln upgrade roc`

Phase: P1. Status: done

Slice 065 is finding F3 of slice 053: the `fix:` block of a `no_tuple` failure of `tln upgrade roc` has the option `or tln upgrade roc`, the command that just failed. The design says what to do in R-AL12 (`DESIGN-RESOLUTION.md` 5, "It is left out when the failed command is `tln upgrade roc` (R-SP8)"). The Resolution 5 example already has no such line. So there is no design gap. Q1 is answered (manager).

## Rules

R-AL12 (the fix block), R-SP8 (`tln upgrade roc` frees only the nightly), R-RP2 (the names of the options). Design: `DESIGN-RESOLUTION.md` 5 and 9.

## Which commands can have the fault

| Where the text `tln upgrade roc` is in a message | Commands | Can it be the failed command? |
| --- | --- | --- |
| Fix block of `Explain.lines` (option 2) | `install`, `add`, `update`, `remove`, `upgrade` (`PickFlow.search!`) | Yes, for `tln upgrade roc` only. The fix of this slice |
| `Pin.decide` text for members with different pins (R-WS4) | `install`, `add`, `update`, `remove` | No. A free nightly accepts different pins (`NightlyPlan`, slice 039), so `upgrade roc` does not stop for it (R-RP2) |
| `Pin.outside_failure` (R-RP2: pin outside `[toolchain] roc`, or `nightly` is false) | `install`, `add`, `update`, `remove`, `verify`, `upgrade <name>` (the nightly is not free) | No. R-RP2: "`tln roc use` and `tln upgrade roc` do not stop for it: they are the fix" |
| Option 1 `tln roc use <id>` | Same as the first row | No. `tln roc use` does not run the oracle loop (it gives other failures: R-U5) |
| Option 3 `stop using <alias>.<Module>` | Same as the first row | Not a Talon command |

So `upgrade roc` is the only case. No other command has a fix line that equals the failed command, and the design gives no second rule.

## Public signatures (stubs, body `crash "todo"` for `failed_command` only)

| Item | Type or change | Rule |
| --- | --- | --- |
| `Explain.failed_command` (`cli/lib/Explain.roc`) | `{ command : [Install, Update, Upgrade], names : List(Str) } -> [UpgradeRoc, Other]` | R-AL12, R-SP8 |
| `Explain.lines` input (`cli/lib/Explain.roc`) | `{ causes, hint, failed : [UpgradeRoc, Other] }`. The stub ignores `failed` (so the old tests pass). The code agent leaves option 2 out of the list of options before the lines are rendered | R-AL12 |
| `OracleBase.Compat` (`cli/lib/OracleBase.roc`) | new field `failed : [UpgradeRoc, Other]` | R-AL12 |
| `OracleCause.failure` | passes `compat.failed` to `Explain.lines` (done in the stub step) | R-AL12 |

`Explain.details` does not change: it has no fix line (the `hint` only).

## Wiring for the code agent (4 production files)

| File | Change |
| --- | --- |
| `Explain.roc` | Body of `failed_command`. In `fix_lines`, take `failed` and keep option 2 out of the list `options` when it is `UpgradeRoc`, before `map_with_index` renders the lines (option 1 is always the `fix:` line) |
| `PickLoop.roc` (line 73, the `compat` literal) | The stub step has `failed: Other`. Use `Explain.failed_command({ command: request.command, names: request.names })` (`request` is a parameter of `run!`) |
| `Oracle.roc` (line 63, the `Compat` of `step`) | `failed: Other` (no compiler, so no probe cause: no fix block). Stays |
| `OracleBase.roc`, `OracleCause.roc` | The field and the pass-through are done in the stub step. `OracleHint` uses `{ ..compat, ... }` and needs no change |

The message and the `--json` `error.message` come from the same text, so one change gives both. The tests (`Oracle*Test`) already have `failed: Other` in their `Compat` literals (the test agent did it).

## Decisions

| Id | Decision |
| --- | --- |
| D1 (manager review, 2026-10-25) | Data flow, not a text filter: the failed command is an input of `Explain.lines`, and the option is left out before the text is made. A filter on the rendered text of exact lines was rejected (it depends on the layout) |
| D2 | Option 1 (`tln roc use ...`) and the `stop using` options stay. Option 1 is always there, so `fix:` always has a first option |

## Tests

| Layer | File and case | Checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/ExplainTest.roc`, `expect` "failed_command": 5 rows (upgrade roc; upgrade of a package; install; update; `update roc` is not the upgrade) | The decision which command failed | R-AL12, R-SP8 |
| L0 | `tests/unit/ExplainTest.roc`, `expect` "lines for `UpgradeRoc`": 6 rows (option 1 alone, with the hint; a cause line and a `stop using` option stay, with and without the hint; 2 causes keep all stop options; `Other` with the same input keeps option 2) | The option goes, no other line goes | R-AL12, R-RP2, R-UM1 |
| L0 | The `Compat` literals of `OraclefreeTest`, `OracledomainTest`, `OracleprobeTest` (9 literals) have the new field `failed: Other` | no new rows |
| L3 | `tests/scenarios/exit/ex3-no-tuple-yaml` (an existing case; `expect/stderr`, 2 lines less, and `expect/stdout`, the `error.message` of the `--json` run) | The real `tln upgrade roc` prints a fix block with no `or tln upgrade roc`, in the text and in `--json` | R-AL12, R-SP8, R-J5 |

The old cases that keep the line for other commands: L3 `remove/rm2-workspace`, `verify/vf1-verify` (they are not changed). No new L2 or L3 case: `ex3` shows the fault already (slice 053, F3), so its expected files change (TW21: the text is changed by hand, 3 lines, and the run shows the 3 lines as the only diff).

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| `tln upgrade roc`, no tuple, no hint | `  fix: tln roc use <id>` then (if the app imports a failing module) `       or stop using parser.Yaml`. No `or tln upgrade roc` |
| `tln upgrade roc`, with a hint | `  fix: tln roc use <id> (the oldest nightly that works)` and the `stop using` options |
| Other commands | No change |

The text is the text that the Resolution 5 example has.

## Out of scope

| Item | Reason |
| --- | --- |
| A test of the wiring in `PickFlow` at L2 | `ex3` (L3) runs the real wiring, and the L0 rows are the decisions |
| `tln upgrade` (all names) and `tln upgrade roc <name>` | Q1: not `UpgradeRoc` |
| `details` for `--json` | It has no fix line |

## Questions

| Id | Question | Answer |
| --- | --- | --- |
| Q1 | Do `tln upgrade` (no name) and `tln upgrade roc <name>` count as the failed command `tln upgrade roc`? | Manager answer (2026-10-25): literal reading. Only `tln upgrade roc` (`names == ["roc"]`) counts. No test row for the other 2 cases |

## Failing output of the new tests (red)

| Test | Result |
| --- | --- |
| `roc test tests/unit/l0-2.roc` | 53 tests: 51 passed, 2 failed. `failed_command`: `todo`. The `lines` rows: wrong value (option 2 is still there). The old 51 pass |
| `roc test` of l0-4, l0-6, l0-8 (the 3 `Oracle*Test` files with the new field) | all pass (65, 73, 77) |
| `scripts/test.sh check fmt` | pass |
| `tests/run.sh exit/ex3` | `FAIL`: the actual output has `or tln upgrade roc` (2 lines in stderr, 1 in the `--json` message), the expected output has none |

## Revert check

A private reference (the 2 functions written) passed the new tests. Each mutation was caught. The reference dir is deleted (manager, 2026-10-25).

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | `UpgradeRoc` for each `Upgrade` (names ignored) | `failed_command` row "upgrade of a package" |
| M2 | Option 2 left out for each command (`failed` ignored) | the rows of the first `lines` `expect`, and the `Other` row |
| M3 | For `UpgradeRoc`, all options after option 1 go (also the stop options) | the `lines` rows with a stop option |
| M4 | `UpgradeRoc` for each command with `names == ["roc"]` (command ignored) | `failed_command` row "update with the name roc" |

A wiring mutation (`PickLoop` keeps `failed: Other`) is caught by `ex3`.

## Disputes (from the code agent)

None yet.

## Verify results

`scripts/test.sh`: check, fmt, l0 (l0-2: 53 tests), l2 (commands 170), l3 (scenarios 84, 3 skipped), selftest, l1 all pass. `tests/run.sh exit/ex3` passes.

Revert check by the code agent (3 mutations, the code was put back and compared with `cmp`):

| Mutation | Caught by |
| --- | --- |
| `Upgrade => UpgradeRoc` (names ignored) | l0 (`ExplainTest`, "failed_command") |
| `UpgradeRoc => ["or tln upgrade roc"]` (option 2 stays) | l0 (`ExplainTest`, "lines for UpgradeRoc") |
| `PickLoop` keeps `failed: Other` (wiring) | L3 `exit/ex3-no-tuple-yaml` |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-065-revert/code-final.sha256` | 3 files OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` | Passed (code agent run, all layers) |
| Gap step | Skipped: 3 of 3 mutations caught (7 with the test agent's), no new decision |
