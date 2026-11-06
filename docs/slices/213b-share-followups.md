# 213b Share follow-ups

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 213b of `PLAN-P2-CLI.md`. Three design answers for the slices 213 and 214 (all in `DESIGN-CLI.md` R-SH5, R-SH11, R-SH13, R-EV29, and `DESIGN.md` Q213, Q215). No network, no queue (215).

## Rules

R-SH5, R-SH8, R-SH11, R-SH13, R-EV29, R-SE15, R-CC1, R-HF2 (as a model), R-LY3 (also named in the cases). Design Q213 (G-C32), Q215 (G-C35).

## What changes

| # | Design answer | Change in the code | Tests |
| --- | --- | --- | --- |
| 1 | Q213: `tln share` with no `share.json` prints `id: none` and 0 totals. It makes no file. | `ShareFlow.status_flow!`: a missing file is `ShareJson.absent({})`, not an Internal failure. No lock, no write, no `random`. | L0 expect 12, L2 `sh3-status` |
| 2 | Q213: `chmod 0600` runs on the temp file of R-CC1, before the `rename`. Nothing on Windows. | The write of a new `share.json` (`ShareFlow` step 3, also used by the first-run Yes): see "The write of a new share.json". | L2 `sh1-flow`, `sh2-direct`, `sh4-first-run` (the `calls.log`), `sh7-chmod-fail` |
| 3 | Q215: the prompt shows once for each process tree. A `tln` that asked sets `TALON_SHARE_ASKED=1` in the env of each child. A `tln` that sees `1` does not ask. | `FirstRun.gate` gives `Skip(Asked)`. `FirstRunFlow.before!` gives back an `Fx` with the variable (see "The variable"). | L0 expect 13, L2 `sh6-run-once`, `sh5-first-skips` |

## Public signatures (stubs, `crash "todo: slice 213b"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `FirstRun.Why` | a new tag `Asked` | R-SH11, R-EV29 |
| `FirstRun.gate` | no new signature. A new check: the env has `TALON_SHARE_ASKED` with the value `1` gives `Skip(Asked)`. This is not a stub: the code is not there, so the test fails with a wrong value. | R-SH11, R-EV29 |
| `FirstRun.child_env` | `List((Str, Str)) -> List((Str, Str))`: removes each entry named `TALON_SHARE_ASKED`, then adds `("TALON_SHARE_ASKED", "1")` at the end. The other entries keep their order. | R-EV29 |
| `ShareJson.absent` | `{} -> Doc`: the `Doc` for a missing file: id `none`, totals 0, other members `Unset`, `extra` empty (`fresh("none")`). Never written. (A function, because a constant that crashes does not compile.) | Q213, R-SH8 |

Edits to existing files (copies in `research/slice-213b-revert/before/`, the new files in `before/NEW.txt`): `cli/lib/FirstRun.roc`, `cli/lib/ShareJson.roc` (the stubs), `tests/unit/ShareTest.roc` (2 new `expect`s), `docs/slices/PLAN-P2-CLI.md` (the row), and the cases `share/sh1-flow`, `sh2-direct`, `sh3-status`, `sh4-first-run`, `sh5-first-skips`. New cases: `share/sh6-run-once`, `share/sh7-chmod-fail`.

## The write of a new share.json (change 2)

`write_atomic!` of the real `Fx` makes its own temp file inside the call, so a flow cannot reach it. So the flow makes the temp name itself, with the existing calls (as `SetupFlow.make_entry!` and `ZigInstall` do). No new `Fx` call.

| Step (Unix, `Fx.windows!` false) | Call in `calls.log` |
| --- | --- |
| 1. The id: 2 numbers (high first), as now | `random`, `random` |
| 2. The temp hex: one more number, `Temp.name({ target: <share.json>, hex: Temp.hex(<number>) })` | `random` |
| 3. `write_atomic!` of the content to the temp name | `write_atomic <share.json>.<16hex>.tmp` |
| 4. `spawn_all!` (limit 1) of `Share.chmod_command` for the temp name | `spawn_all limit=1` and `  job - chmod 0600 <temp>` |
| 5. `rename!({ from: temp, to: <share.json> })` | `rename <temp> <share.json>` |
| A failure of step 4 or 5 | `delete <temp>` (one `delete!`), then kind `Environment` (exit 18). The text of step 4 is `cannot set the mode of <share.json>: <result>` (the target, not the temp). The text of step 5 is `cannot write <share.json>: <error>`. |

The lock of `share.json` is held for all steps (R-CC6). On Windows: no `random` for the hex, no temp, no chmod: one `write_atomic!` of `share.json` (R-CC1 does the temp and the rename inside the call). The Windows branch is not in an L2 case (a Windows start runs the `.del` sweep first, so the case would need many fake answers). It is decision D1.

## The variable (change 3)

| Item | Rule |
| --- | --- |
| Who sets it | A `tln` that showed the prompt (the call `ask`, whatever the answer, also the end of input), and a `tln` whose env has `TALON_SHARE_ASKED=1` (the gate gave `Skip(Asked)`). |
| How | `FirstRunFlow.before!` gives back the `Fx` of the command with 3 fields replaced: `env_all!` gives `FirstRun.child_env(<env>)`, and `exec!` and `exec_in!` pass `FirstRun.child_env(<their env>)`. So the variable is the last entry in the `env` of each child (the `exec_in` lines of `calls.log` show it after the other variables). |
| In-process `tln` steps | `RunFlow` reads the env with `env_all!` of this `Fx`, and the derived `Fx` of a `tln` step gets this env. So the inner `Run.tln!` gate sees the variable and stops at its first call (no `tty`, no config read, no `ask`). No change in `RunFlow` or `RunSteps` is needed. |
| Not set | When no prompt was shown and no variable was seen (share set, `--json`, `CI`, a command with `Skip(Command)`, and so on), the `Fx` is not changed. |
| Real children | `exec!` and `exec_in!` (the compiler of the proxy in `tln run`, a path step, a tool run, the `tln x` binary). `spawn_all!` and `probes!` (`tar`, `curl`, `roc check`) have no env field: they are not `tln` and are not changed. The real `Fx` adds the `env` entries to the env of the process, so a child gets the variable once. |

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ShareTest.roc` (driver `l0-8.roc`), expect 12: `status_lines` and `status_data` of `ShareJson.absent({})` (`id: none`, `"id":null`, 0 totals), and the text of `absent` is not a valid file (`ShareJson.read` gives Input) | Q213, R-SH8, R-SH13, R-OUT2 |
| L0 | expect 13: `gate` with `TALON_SHARE_ASKED=1` gives `Skip(Asked)` (alone, and with other entries); a similar name and unset give `NeedTty`. `child_env`: empty, order kept, an old value replaced, the name once, twice gives the same | R-SH11, R-EV29 |
| L2 | `share/sh1-flow`, `sh2-direct`: the `calls.log` has the temp name, the third `random`, the chmod on the temp and the `rename` (the file tree is as before). Also each now has `fx/jobs` with the rule `chmod`, see "Notes" | R-SH5, R-SE15, R-CC1, R-LY3, R-CC6 |
| L2 | `share/sh4-first-run`: the same for the answer `y` | R-SH11, R-SH5, R-SE15 |
| L2 | `share/sh3-status`: 2 more runs in a home with no `share.json` (and no `config.toml`, no `compat.db`): the text and `--json`. The `calls.log` has no lock, no write, no `random`. | Q213, R-SH8, R-SH13, R-OUT2 |
| L2 | `share/sh5-first-skips`: one more run with `TALON_SHARE_ASKED=1` in the env: no `ask`, and the calls stop at `env_all` | R-SH11, R-EV29 |
| L2 | `share/sh6-run-once`: `tln run go` with `go = ["tln cache dir", "echo hi", "tln cache dir"]`, a person there, share not set, no answer (end of input). Run 1: one `ask` in all, the 2 `tln` steps ask nothing, nothing is written, the env of `echo hi` has `TALON_SHARE_ASKED=1` last. Run 2: the variable is in the env of the first command: no `tty` call, no `ask`, the child has the variable. Run 3: `share = true`: no `ask`, and the child has no variable. | R-SH11, R-EV29, R-NI16, R-HF1 |
| L2 | `share/sh7-chmod-fail`: the chmod fails (exit 1): `share on` and `share on --json` give exit 18 with the text of the table above. The `calls.log` has `delete <temp>` and no `rename`. `share.json` is not made (the tree diff has `config.toml` only). | Q213, R-SH5, R-SE15, R-CC1, R-CC2, R-OUT4 |

The L3 case `scenarios/share/fr1-first-run-tty` (the mode `-rw-------` of the real file) is unchanged: the real `Fx` runs the same calls and the final mode is the same.

## Output (proposed, R-OUT2, TW24)

| Command | Text | `--json` `data` |
| --- | --- | --- |
| `tln share`, no `share.json` | the lines of `tln share` with `id: none`, then `sent: 0`, `counted: 0`, `first: 0`, `queued: <n>` | the same object as now, with `"id":null` (Design Q217, G-C37; the text stays `id: none`) |
| A failed chmod | stderr `tln: error[environment]: cannot set the mode of <path>: Exited(1)` (the form `Str.inspect` of the `ended` value, as the other `Environment` texts) | the error envelope, code 18 |

## Decisions that the design does not fix

| # | Point | Choice | Rejected |
| --- | --- | --- | --- |
| D1 | The Windows write of a new `share.json` | One `write_atomic!` of the target, no temp, no chmod, no extra `random` (R-CC1 is inside the call) | The same temp and `rename` without chmod (a second path for nothing) |
| D2 | The number of the temp hex | A third `random`, after the id (the id keeps its 2 calls and its order) | The temp hex first (a change of the id numbers in the cases) |
| D3 | A failed step 4 or 5 | Delete the temp (R-CC2 says a failed write leaves no temp), exit 18, the text names the target | Keep the temp for `tln cache gc` |
| D4 | Where the check `Asked` is in `gate` | Not fixed. No test has an env where 2 checks are true. The reference put it after the check of the mode. | |
| D5 | Who sets the variable | The `Fx` that `before!` gives back (3 fields), so the commands do not change | A change in each `exec` call of the commands |

## Out of scope

| Item | Reason |
| --- | --- |
| The Windows branch of change 2 | See the section above. Rows of `Share.chmod_command` (Windows gives `NotNeeded`) are in slice 213 L0. |
| The variable in the `roc` proxy path (`Run.run!` never calls `before!`) | A proxy `tln` that sees the variable has it in its own process env, so the compiler child gets it from the real `Fx` (it adds `env` to the process env). The fake `Fx` shows `env` only, so an L2 case would test the fake, not the design. If the manager wants the call to set it in the proxy path too, it is a question for a later slice. |
| `tln x` and tool runs with the variable | They use the same `exec!` of the `Fx` that `before!` gives back. `sh6-run-once` shows it for a path step. |
| R-SH2 for the queue, R-SH3, send | Slices 215, 216. |

## Questions (stop until answered)

| # | Question | Options | State |
| --- | --- | --- | --- |
| Q1 | `TALON_SHARE_ASKED` with a value other than `1` (`0`, empty, `true`). R-EV29 gives the value `1` only. | (a) only the exact text `1` counts (the reference). (b) any not empty value other than `0`, as `DO_NOT_TRACK`. | Answered (Design Q217): only the exact text `1` counts. |

## Notes

| # | Note |
| --- | --- |
| 1 | `share/sh1-flow` and `share/sh2-direct` had no `fx/jobs` when this slice started: their expected files showed exit 18 and `cannot set the mode of ...: Exited(99)` (the fake has no rule for `chmod`). I added the rule (`chmod`, exit 0, as `sh4-first-run`) and the expected files are as the slice 213 describes them: exit 0, the file made. |
| 2 | The L2 world of `sh6-run-once` has no answers file: the end of input is the case. |

## Disputes (from the code agent)

None yet.

## Verify results

Red result (2026-11-02, the stubs installed, no code change):

| Check | Result |
| --- | --- |
| `roc test tests/unit/l0-8.roc` | 2 `expect`s fail with `todo: slice 213b` (12 and 13), 123 pass (log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red-l0.log`) |
| `tests/commands/run.sh share/` | 7 fail, 0 pass: `sh1`, `sh2`, `sh4` (the temp and the chmod order), `sh3` (the Internal failure for the 2 new runs), `sh5` and `sh6` (the prompt asks again), `sh7` (the chmod is on the final file) (log `.../red-l2.log`) |
| `roc check cli/lib/main.roc`, `roc fmt --check` of the changed Roc files | 0 errors, exit 0 |

With the private reference installed: 13 `expect`s of the file pass, the 7 `share/*` cases pass, and the full L2 run has 240 pass and 17 fail (`gc/gc6` and `ptool/*`, the work of other agents). The reference was deleted after the run (the manager's order for this slice).

Mutations of the reference (7, the likely bugs). Each was run with L0 and the 7 cases of `share/`.

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `gate`: the variable is not read (the value is compared with another text) | L0 expect 13, L2 `sh5-first-skips`, `sh6-run-once` |
| M2 | `before!`: a `tln` that saw the variable does not set it for its children | L2 `sh6-run-once` (run 2) |
| M3 | the `Fx` has no marked `env_all!`, so the in-process `tln` step asks again | L2 `sh6-run-once` (run 1) |
| M4 | the `Fx` is marked also when no prompt was shown | L2 `sh6-run-once` (run 3) |
| M5 | the chmod runs on the final file after the `rename` | L2 `sh1`, `sh2`, `sh4`, `sh7` |
| M6 | `tln share` with no file stops with an Internal failure (the old code) | L2 `sh3-status` (the L0 expect 12 has no flow) |
| M7 | `child_env` does not remove an old entry | L0 expect 13 |

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK. The manager cut `code-final` down to the 5 files of this slice (FirstRun, FirstRunFlow, ShareFlow, ShareJson, Share). The code agent had copied all of `cli/lib`. |
| `crash "todo: slice 213b"` | None |
| Tests (code agent) | l0-8 125 of 125. `share/*` 7 of 7, with `"id":null` (Q217). Windows and flow cases by name: 11 of 11. L2 240 pass. The 17 failures are `gc/gc6` and 16 `ptool/*` of slices 092 and 093. L3 passes. |
| Expected exits (manager check) | `sh7-chmod-fail` exit 18 is the rule. In `sh5-first-skips`, `setup` (exit 18) and `@roc --version` (exit 2) only check that no prompt shows. Their errors come from the test world (no `tln` binary, no nightlies). |
| Revert check | Test step: M1 to M7 caught. |
| Design | Q213, Q215 (R-EV29), Q217 (G-C37). |
