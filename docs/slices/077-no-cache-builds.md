# 077 `--no-cache` in every `roc build`

Phase: P1. Status: done

Slice 077 is the plan row 077 of `PLAN-P1.md` (section 2c). Source: the design decision C1 of `DESIGN-GAPS-2026-10-26.md`: every `roc build` that Talon runs passes `--no-cache`. A `roc build --opt=dev` that reads the objects of an earlier build can give a bad program, and a probe fact never expires (R-P4). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stubs and the private reference are in `research/slice-077-revert/`.

## 1. Rules

| Id | Text (short) | Where |
| --- | --- | --- |
| R-LD8 (Resolution 4) | Each `roc build` that Talon runs passes `--no-cache`: ladder step 3, the unit probe build, the smoke build, the build of a tool, of `tln x` and of a project tool, the option 2 try of R-T19, the source build of Talon. `roc check` and `roc test` get no flag. The `roc` proxy passes the arguments of the user with no change. | `Probe.build_args` |
| R-T8 (CLI 6.4) | A tool build has no `--target` and has `--no-cache`. | `ToolInstall.build_spec` |
| R-LD5, R-TG2 | The form of the build arguments (target, output). The flag does not change it. | L0 `BuildtargetTest` |
| R-PX3 | The proxy passes the flags of the user with no change (guard rows, no change in this slice). | L0 `PatchedTest`, `ProxyTest` |

## 2. Build call sites (audit)

I read each place where Talon starts `roc build`. The argument list is made in 2 functions only, so one pure function covers all of them.

| # | Place | Makes the arguments with | Covered by |
| --- | --- | --- | --- |
| 1 | Ladder step 3: `LadderPlan.plan`, `with_patches`, `with_target` (`Ladder`, `Verify`, `Probe` flows) | `Probe.args` (`Build`) and `Probe.replace_args` | L0 `LadderTest`, `VerifyTest`, `PatchedTest`, `BuildtargetTest`. L2 `ladder/*`, `probe/pb*`, `upgrade/*`, `update/up1-flow`, `verify/vf1-flow`, `resolve/*` |
| 2 | The unit probe build (`ProbeUnit.one!`) | `Probe.args` (`Build`) | L2 `probe/un1-units`, `un2-remove-units`, `un3-verify-units` |
| 3 | `tln tool install`, `tool update`, `tool rebuild`, `tool install --git` (`ToolBuild.attempt!`) | `ToolInstall.build_spec` | L0 `ToolTest`. L2 `tool/ti1-install`, `tu1-update`, `tr1-rebuild`, `tg1-git` |
| 4 | The option 2 try of R-T19 (`ToolTry`, `ToolBuild.attempt!`) | `ToolInstall.build_spec` | L2 `tool/ti3-compiler`. L3 `tools/ti2-tool-compiler` |
| 5 | The source build of `tln` (`tool update talon --from-source`: `ToolBuild.finish_checked!`) | `ToolInstall.build_spec` | L2 `tool/ts6-source`, `ts7-source-nostart`, `dx2-source-windows` |
| 6 | `tln x` and a project tool (`XFlow`, `ToolsStep`) | `ToolInstall.build_spec` | L2 `x/x1-run`, `x/x3-project`, `ptool/pt1` to `pt4`, `run/rn3-tools` |
| 7 | The smoke build (R-SM1) | No code yet (P2) | Out of scope |
| 8 | `GitBuild.build_command` (`zig build roc`) | It is a Zig build, not `roc build` | Not a call site |
| 9 | `roc check`, `roc test`, the proxy | Check: `Probe.args` (`Check`). Proxy: `Patched.args`, with no change | Guard rows in L0 `ProbeTest` (check has no flag), `PatchedTest` (proxy build has no flag) |

## 3. Public signatures (the code agent keeps them)

| Function | Signature | Result | Stub |
| --- | --- | --- | --- |
| `Probe.build_args` | `{ file : Str, options : List(Str), output : Str } -> List(Str)` | `["build", file]`, then `options`, then `--output=<output>`, then `--no-cache` | `crash "todo: slice 077"` (`cli/lib/Probe.roc`) |

The code agent also (no new signature):

| Place | Change |
| --- | --- |
| `Probe.args` (`Build`) | Calls `Probe.build_args({ file, options: [], output })`. `Check` stays `["check", file]`. |
| `ToolInstall.build_spec` | `args` is `Probe.build_args({ file: "main.roc", options: ["--opt=speed"], output })`. The weight, the timeout and the other fields stay. |
| `LadderPlan.with_target`, `Probe.replace_args`, `Patched` | No change. `--target=<t>` goes after `build`, the `--replace-dep` pairs go after `--no-cache` (the tests fix this order). |
| Doc comments | `Probe.args`, `ToolInstall.build_spec` and `ToolTest` text name the flag. |

## 4. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L0 | `ProbeTest` expect (line 44), 2 new rows and 1 changed row | `Probe.build_args` with no option and with `--opt=speed`, the order `build file options --output --no-cache`. `Probe.args` of a build has the flag, a check has none. | R-LD8 R-LD5 R-T8 |
| L0 | `LadderTest` expect (line 58), 2 changed rows | The build of the ladder (app, and the build with the facts of a slow compiler) has `--no-cache` after `--output`. | R-LD8 |
| L0 | `VerifyTest` expects (lines 18 and 35), 4 changed rows | `replace_args` and the plan of verify: the flag is before the `--replace-dep` pairs, also with no pair. | R-LD8 R-CM11 |
| L0 | `PatchedTest` expect (line 257), 2 changed rows | The build with the pairs of a patch has the flag before the pairs. Row 137 (a user `build` through the proxy) is not changed: it has no flag. | R-LD8 R-PX3 |
| L0 | `BuildtargetTest` expect (line 308), 4 changed rows | `--target=<t>` goes after `build`, the flag stays after `--output`, the pairs of the patches stay at the end. | R-LD8 R-TG2 R-LD5 |
| L0 | `ToolTest` expect (line 214), 1 changed row | `ToolInstall.build_spec` has `build main.roc --opt=speed --output=<out> --no-cache` and no `--target`. | R-LD8 R-T8 |
| L2 | 72 `calls.log` files (section 5) | Each `probe` line of a build has `--no-cache`. The cases are not changed in any other way. | R-LD8 R-T8 |
| L3 | 18 scenarios (`roc.log` or `stdout`, section 5) | The fake `roc` log shows the flag for the ladder build, the verify build, the tool build and the target build. | R-LD8 R-T8 |

L0 count: 0 new `expect`s, 2 new rows and 12 changed rows (14 rows in all) in 6 test files. Deep cases: no new case: the flag is a new part of the 72 L2 and 18 L3 cases that exist.

## 5. Changes of old tests (TW21)

The copies are in `research/slice-077-revert/before/`. The rule: a `calls.log` or `roc.log` changed only by the added word. I made each change with one `sed` over the lines of the probe builds and read the diff of `ti1-install`, `bs1-build-skip` and the L3 files.

| Group | Files | Change |
| --- | --- | --- |
| L2 `expect/calls.log` | 72 cases (list: `research/slice-077-revert/l2-files.txt`): consent 3, evidence 2, init 3, install 1, ladder 5, moves 2, patch 1, probe 9, ptool 4, remove 1, resolve 6, roc 4, run 1, target 3, tool 13, update 1, upgrade 9, verify 1, workspace 1, x 2 | ` --no-cache` after `--output=<path>` on each `probe` line that has `build`. A tool build: `... --opt=speed --output=<path> --no-cache timeout=3600`. |
| L3 `expect/roc.log` | 11 scenarios (`add/ad1`, `ad2`, `install/in1`, `remove/rm1`, `rm2`, `update/bs1`, `bs2`, `tg1`, `up1`, `up2`, `why/wy2`) | ` --no-cache` after `--output=<path>` on each `build` line (also before `--replace-dep`). |
| L3 `expect/stdout` | 7 scenarios (`compilers/pb1`, `probe/pc1`, `verify/vf1`, `tools/ti1`, `ti2`, `ti3`, `tx1`) | The same, in the lines that print the arguments of the fake `roc`. |
| L3 `expect/stdout` (count of arguments) | `compilers/dl1`, `dl3`, `pb1`, `us1` | The fake compiler of these cases prints `n=<number of arguments>`: `build main.roc n=12` is `n=13`, `n=3` is `n=4`. |
| `tests/commands/FakeJobs.roc` | `default_probe` | The pattern `["build", _, output]` is `["build", _, output, "--no-cache"]`: the fake answers a build with the flag as it did a build with no flag. The other rows are as before. |
| Not changed | `rn1-flow` (the script of the user runs `roc build` through `tln run`, R-RUN: no flag), the fake `roc` scripts of the L3 cases (they take `--output` from the arguments, and `"${3#--output=}"` stays the third argument because the flag is after `--output`), `tests/fixtures/check/` (real roc outputs) | |

## 6. Output (proposed, TW24)

None. No text and no `data` field changes. `tln probe` and the other commands do not print the arguments of `roc`.

## 7. Out of scope

| Part | Reason |
| --- | --- |
| The smoke build (R-SM1, R-SM2) | No code in P1 (`InitStub` writes the text of the app only). R-LD8 names it, so the P2 slice of the smoke build must pass the flag. |
| `GitBuild` (`zig build roc`) | It is not `roc build`. |
| L4 (the pinned real `roc` accepts `--no-cache`) | The runners (`scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh`) already pass it to the pinned `roc build`. L4 cases run the same argument lists. |
| `TESTING.md` | The line on `--no-cache` of R-LD8 is the work of the design agent. |

## 8. Decisions of the test agent that the design does not fix (for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The place of the flag: after `--output=<output>` (so `build <file> [options] --output=<out> --no-cache [--replace-dep a b ...]`). Reasons: `--target=<t>` stays after `build` (R-LD5 form) and the `--replace-dep` pairs stay at the end (R-CM11, `Patched`); the L3 fake `roc` scripts read the output as the third argument (`"${3#--output=}"`); the roc option parser takes a flag anywhere (the runners put it before `--opt`). | Before `--output`, or right after the file (both move the output to the fourth argument and break the fake `roc` scripts of 6 L3 cases that read argument 3). |
| D2 | One function, `Probe.build_args`, makes the argument list of every build. `Probe.args` and `ToolInstall.build_spec` call it. | The flag added in each of the 6 places (a new build in P2 could miss it). |

## 9. Questions (stop until answered)

None.

## 9a. Review (manager, 2026-10-26)

| Item | Answer |
| --- | --- |
| Slice 077 | Accepted. D1 (the flag after `--output=<out>`) and D2 (one function `Probe.build_args`) stay. No question was open. |

## 10. Disputes (from the code agent)

None.

## 11. Red output

With the stubs in the tree (private reference away).

| Step | Result |
| --- | --- |
| check, fmt | pass. `roc fmt --check` of the changed `.roc` files: exit 0 |
| l0 | FAIL: 7 `expect`s: `ProbeTest` (line 44, `todo: slice 077`), `LadderTest`, `VerifyTest` (2), `PatchedTest`, `BuildtargetTest`, `ToolTest` (wrong value: the flag is missing). All other `expect`s pass. |
| l2 | FAIL, 72 cases (the list of `l2-files.txt`): `Fx calls differs`, only the added word. 109 cases pass. |
| l3 | FAIL, 21 scenarios (the 18 of section 5 and the 4 count cases, `pb1` is in both). |
| selftest, l1 | pass |

With the private reference in the tree, check, fmt, l0, l2, l3 and selftest pass.

## 12. Revert check (TW12)

7 changes of the private reference, one at a time (`research/slice-077-revert/mutate.py`), steps check, l0, l2, l3. All 7 are caught. The reference and the script are deleted after the review (section 13). The stubs and `before/` stay.

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | `Probe.args` of a build has no flag | L0, L2, L3 |
| m2 | The flag is before `--output` | L0, L2, L3 |
| m3 | `ToolInstall.build_spec` has no flag | L0 `ToolTest`, L2 tool cases, L3 tool scenarios |
| m4 | `build_args` drops `options` (a tool build loses `--opt=speed`) | L0, L2, L3 |
| m5 | A check has the flag too | L0 `ProbeTest`, L2, L3 |
| m6 | The unit probe build strips the flag (`ProbeUnit`) | L2 `probe/un*`, L3 (L0 passes: wiring) |
| m7 | `replace_args` makes the build with no flag (the verify and patch builds) | L0 `VerifyTest`, L2, L3 |

## 13. Next step

The manager reviews the tests (D1 is the one choice). Then the code agent writes the body of `Probe.build_args` and the 2 call changes of section 3 (status `code`). The private reference and `mutate.py` are deleted (the manager's order of 2026-10-26); `before/`, `stubs/` and the file lists stay.

## 14. Verify results

Code agent, 2026-10-26: `scripts/test.sh` passes (check, fmt, l0, l2, l3, selftest, l1). Code: `Probe.build_args` (body), `Probe.args` (`Build` calls it), `ToolInstall.build_spec` (calls it). Revert check: 3 mutations, all caught, the code is the same after them (compared with `cmp`).

| Mutation | Test that failed |
| --- | --- |
| `build_args` drops `options` | L0 (`scripts/test.sh l0`) |
| The flag is before `--output` | L0 |

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK (tree and `code-final/`) |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Disputes, questions | none |
| Gap step | skipped: every mutation was caught, no new decision |
