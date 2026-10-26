# 072d No rank: the stops that are not a fetch (core)

Phase: P1. Status: done

Slice 072d is the plan row 072d of `PLAN-P1.md` (section 2c). It follows 072a, 072b and 072c. `NoRank` (072c: `ensure!`, `first`, `pick`, `offer!`, `Probing`) is done and has L0 and `norank` L2 tests. No command uses its step (b) (the probe of the installed compilers) yet: a fetch never reaches steps (a) and (b) because `Fetch.unbundler` takes the newest installed compiler first (R-FE4). This slice puts the pick in the commands that run a probe: `verify`, `probe`, `roc use`. It also makes the stop of `check_pin` (exit 18) apply only where a compiler is needed. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files and the private reference are in `research/slice-072d-revert/`.

## 1. Split of the row (proposal for the manager)

The plan row has 6 parts. The design text does not decide 3 of them (questions Q-D2 to Q-D4). So the slice has a core that the tests fix now, and a part 072e that waits for the answers.

| Part of the row | Here | Reason |
| --- | --- | --- |
| `check_pin`: a stop only for a run that needs a compiler | 072d (tests) | R-SO22, R-BL6 say `--no-check` needs no compiler, and R-SO21 says `verify` has its own run compiler |
| `ProbeFlow`, `verify`, `roc use` (baseline): the pick with steps (a) to (d) | 072d (tests) | R-SO14, R-SO23 (row `verify`, `probe`, `roc use`) |
| The real closure of `NoRank.Probing.one!` (step (b)) | 072d (tests) | The ladder of `tln probe` on the installed compiler (R-SO14 (b)) |
| `install`, `update`, `add`, `upgrade`, `remove` with checks and no pin | 072e (question Q-D2) | The design does not say when the compiler is picked |
| Relative selector `roc install @-1` (R-SL7) | 072e (question Q-D3) | The design does not say what the base is |
| `Proxy` step 9 (R-PX4), the free-nightly `NoCompiler` in `InstallFlow`, `init/it4-nocompiler`, the old cases that expect exit 18 | 072e (questions Q-D2, Q-D4, Q-D6) | Same |

## 2. Rules

| Rule | Text (short) | Where |
| --- | --- | --- |
| R-SO14 | No rank selects a compiler: Talon picks one. For a command with a project: (a) the newest installed compiler with a recorded pass for each header hash that has a fact, no download, no default. (b) Else probe the installed compilers, newest first, with the ladder of `tln probe`: a recorded fail, hang or crash skips a compiler, the first pass wins, no download, no default. The probes count against `probe.max` and write facts. A spent `probe.max` is no exit 12: go on. (c) Else the newest compiler in the channel with a pass: download, default. (d) Else the latest in the channel: download, default. | `HeldRoc.held!` (new) |
| R-SO23 | The row `install, add, remove, update, upgrade, verify, probe, roc use`: the project of the command, the order (a) to (d). | `ProbeFlow`, `VerifyFlow`, `RocUse` |
| R-SO21 | `verify` runs on the run compiler: rank 2, then the held nightly (the pick, when no rank gives one). | `VerifyFlow` |
| R-SO22, R-BL6 | `--no-check` runs no probe, so it needs no compiler. A required download comes at the first probe, not before. | `ResolveBase.check_pin` |
| R-SO15 | A download of step (c) or (d) is the default compiler (no default is set). The installed compilers of (a) and (b) set no default. | `HeldRoc.held!` |
| R-P5, R-PP4 | Each probe of step (b) counts against `probe.max`. Its facts go in `compat.db`. | `probe_one!` |
| R-DL2, R-DL5 | A download that no consent allows: exit 13. | `HeldRoc.held!` |
| R-SL7, R-PX4 | See 072e. | none |

## 3. What the code does today

| Part | Today |
| --- | --- |
| `ResolveBase.check_pin` | `Err(NoCompiler)` with no held nightly: exit 18 for the roles `Lock` and `Verify`. Even `--no-check` stops. |
| `ProbeFlow.single!`, `VerifyFlow.verified!` | `held: decision.held ?? ""`. With no compiler the ladder does not start, or `Start.run!` has no compiler. |
| `RocUse.fallback!` | The baseline of a member with no pin is `ResolveSelect.select!`. With no compiler: `NoCompiler`, exit 18. |

## 4. Where the code changes (for the code agent)

The reference is a proposal. The code agent may choose another shape. The `calls.log` files fix the order of the calls.

| # | Place | Change |
| --- | --- | --- |
| 1 | New module `HeldRoc` (exposed in `cli/lib/main.roc`) | `HeldRoc.held! : Fx, ResolveBase.Request, ResolveBase.Loaded, Try(Str, [NoCompiler]) => Try(Str, Fail)`. `Ok(id)` (a held nightly): the same id, no call. `Err(NoCompiler)` with `no_check` or `no_probe`: `""`, no call. Else `ResolveBase.no_rank(request, loaded)`: `Stop` is exit 18, `Download(run)` is `NoRank.ensure!` with `listed` from `Launch.toolchains!` and `probe: Run({ max: settings.max, one!: probe_one! })`. The result is the id. |
| 2 | `HeldRoc.probe_one!` (private) | The ladder of `tln probe` on the installed compiler `req.id`: `Start.run!` (`held: req.id`), `Fetch.packages!` for the release rows of all members, then `ProbeUnit.node!` for each hash in order. It stops at the first non-pass. It starts no probe when `req.left` probes are spent. A ladder that the budget stops before its end is `passed: False`. Then, when all units pass, `ProbeUnit.project!` (check, and build for an app). The answer is `{ passed, probes }`. |
| 3 | `ResolveBase.check_pin` | The role type is `[Lock, LockNoCheck, Verify]`. For `Err(NoCompiler)` only `Lock` stops (exit 18). `LockNoCheck` and `Verify` give `Ok`. The gate row `(Env, LockNoCheck)` is the row of `Lock`. |
| 4 | `InstallFlow`, `RemoveFlow` | Pass `LockNoCheck` when the run has `--no-check` (for `remove`, when it skips the check), else `Lock`. |
| 5 | `ProbeFlow.single!`, `VerifyFlow.verified!` (before `Ladder.verify!`) | `held = HeldRoc.held!(fx, request, loaded, decision.held)?`. `VerifyFlow` calls it only in the branch that runs the check (`--no-check` prints `check: skipped` before). |
| 6 | `RocUse.fallback!` | For a member with no pin and `NoCompiler` from `ResolveSelect.select!`: `HeldRoc.held!`. The id is the baseline. |

`Pin.decide`, `NoRank` and `ResolveSelect` do not change.

## 5. Tests

All are L2, entry `commands`. The fake `Fx` has the answers of the files in `fx/`. Each run has its own home (h1 to h6) and project, so the facts and the installed compilers of one run do not touch another. The fixtures: the packages of `verify/vf1-flow` in the cache of each home, the toolchains N1 `nightly-2026-10-14-38a3029`, N2 `nightly-2026-10-16-1df370f`, N3 `nightly-2026-10-18-5349569`, and for a download N4 `nightly-2026-10-19-0badf00` (the newest in the list). `fx/units` has one fail: the platform hash on N3.

| Case | Runs | Content | Rule ids |
| --- | --- | --- | --- |
| `verify/vn1-nocompiler` (new) | 6 | Run 1 (h1, step (a)): N1, N2, N3 installed, facts pass for the 3 header hashes on N1 and N2: N2 is used, no download, no `config.toml`. Run 2 (h2, step (b)): N2 and N3, no fact: N3 fails the platform unit and stops, N2 passes the 3 units, the check and the build: N2 is used. Run 3 (h3, step (d)): nothing installed, `TALON_AUTO_INSTALL=yes`: N4 is downloaded (`downloading <id> (<size>), the default compiler`), `config.toml` gets `default-roc`. Run 4 (h4): nothing installed, `TALON_AUTO_INSTALL=no`: exit 13. Run 5 (h5): `--no-check`, nothing installed: `check: skipped`, exit 0, no pick. Run 6 (h6): as run 2 with `probe = { max = 3 }`: 1 probe on N3, 2 on N2, the third unit is not started, step (b) ends with no exit 12, the download is refused: exit 13. | R-SO14 R-SO23 R-SO22 R-SO21 R-SO15 R-SO7 R-DL2 R-DL5 R-BL6 R-P4 R-P5 R-PP4 R-PB2 R-LD7 R-CM11 R-EC18 |
| `probe/pn1-nocompiler` (new) | 4 | `tln probe --file`: run 1 step (a) (N2), run 2 step (b) (N2), run 3 step (d) (N4, default), run 4 refusal (exit 13). The first line of stdout names the compiler (`on <id>`). | R-SO14 R-SO23 R-SO15 R-DL2 R-DL5 R-PB2 R-PB1 R-P4 R-P5 R-PP4 |
| `roc/us4-nocompiler` (new) | 2 | `tln roc use <N1> --file` on a project with no pin and no compiler selected. Run 1 (step (a)): the baseline is N2, the pin is written (`+ roc:`). Run 2 (step (b)): the baseline is N2 after N3 fails. N1 is installed in both homes. | R-SO14 R-SO23 R-SO15 R-DL2 R-SL7 R-BL1 R-RP3 R-H6 R-U3 R-P4 R-P5 R-PP4 |
| `remove/rm3-nocompiler` (new) | 2 | `remove json --no-check` and `install --no-check` with nothing installed and no compiler selected: no exit 18, no download. The entry is removed (`check: skipped`), and `install` says `nothing to change`. | R-SO22 R-BL6 R-SO14 R-SO23 R-EC18 R-RM1 R-H6 |

L0: no change (`NoRank` has its rows from slice 072c, and `check_pin` has no L0 test). L3: no change. Test counts: 4 new L2 cases (14 runs). No old expected file changes: the old cases that expect exit 18 (`roc/so9-no-roc`, `roc/so9-hash-fails`, `resolve/rs-no-compiler` run 1, `tool/dl1-sweep` run 5, `proxy/px1-flow`) still stop at a `Lock` role, and `roc/bs2-no-pin` and `roc/bs3-range` stop at the relative selector. They wait for 072e.

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| Steps (a) and (b) | No line. The pick of an installed compiler is silent (no download, no default). The probes of step (b) print nothing. `verify` and `probe` print their own lines as before. |
| Steps (c) and (d) | The text of slice 072b: `downloading <id> (<size>), the default compiler`. No new text. |
| `--json` | No new `data` field. The probes of step (b) are not in `data.probes` (they are the probes of the choice, not of the command). |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| `--no-check` and `--no-probe` in `HeldRoc.held!` (the guard of the reference) | `verify --no-check` never calls it (`VerifyFlow` prints `check: skipped` first), `probe` and `roc use` refuse the flags. No test can reach the guard. The code agent may drop it. |
| The pick when a pin, `ROC_TOOLCHAIN`, `default-roc` or a `PATH` `roc` gives a compiler | Not a case of R-SO14. Covered by the old cases. |
| Step (c) (the newest in the channel with a recorded pass) for a project | `NoRank` L0 and `norank` L2 (slice 072c). No flow case: a fact needs an installed compiler to exist, so step (a) or (b) takes it first. |
| The order of the downloads of `roc use` (the pick and the new compiler both missing) | Question Q-D5. No case. |

## 8. Questions (TW17)

| Id | Question | Options | Recommended |
| --- | --- | --- | --- |
| Q-D2 | `install`, `update`, `add`, `upgrade` and `remove`, with checks and no pin, no compiler selected: when is the compiler picked? | (a) Before the resolution, always: the pick is the held nightly H, and R-RP3 writes the `roc:` pin. `tln install` with nothing to change would download a compiler for nothing. (b) Before the resolution, only when a probe will run (there is a change to check). (c) At the first probe, with H empty, and the pin written from the pick. | (b). It blocks: `roc/so9-no-roc`, `roc/so9-hash-fails`, `resolve/rs-no-compiler` run 1, the free-nightly `NoCompiler` in `InstallFlow`, and the pin write of `remove` with checks. The run 2 of `rm3-nocompiler` shows the case: `install --no-check` has nothing to change. |
| Q-D3 | R-SL7: what is the base of a relative selector (`roc install @-1`) when no compiler is selected? | (a) The R-SO14 pick used only as an id: no download, no default. (b) The pick, downloaded and made the default. (c) Keep exit 18. | (a). It blocks: `roc/bs2-no-pin`, `roc/bs3-range`, L3 `compilers/bs1-base-ranks`, `cl1-nightly-list`. |
| Q-D4 | R-PX4, the proxy: does the proxy run step (b) (the hidden probes)? How does it get the project hashes (`Base.Loaded` has none)? | (a) Step (b) runs. The proxy gets a new `hashes` field. (b) The proxy has only (c) and (d) and the facts of (a). | The design says "the project of the target file" and the same order as the row of `verify`, so (a). The proxy prints no default-compiler line (stdout of the proxy is the one of `roc`). It blocks `proxy/px1-flow`, L3 `px1-proxy`, `so9-launcher`. |
| Q-D5 | `roc use <id>` with the pick and the new compiler both missing: which download comes first, and is it one prompt or two? | (a) One prompt for both (the `roc use` rule for the baseline and the new compiler, Q4 of slice 026b), the pick is the default. (b) Two prompts: the pick first. | (a). No case until the answer. A try with nothing installed and `TALON_AUTO_INSTALL=no` printed the download line of the new compiler before the refusal of the pick: the order is not fixed by the design. |
| Q-D6 | `init/it4-nocompiler`: after the init download, the upgrade shows `nothing to change` (no ladder, no `+ roc:`). Why? The expected result is the one of `init/it2-platform` (`check: passed`, `build: passed`, `+ roc: <id>`, `resolved at ..., 4 probes`). | The cause is not known (it is code, not design). | The code agent finds the cause in 072e. |

Open points for 072e, not questions: the free-nightly `NoCompiler` in `InstallFlow` (after Q-D2), `ManageUse`, the `Proxy` step 9 (after Q-D4).

## 9. Red output

With the old code (the reference away). The 078b and 079b slices have their expected files in the tree with the old code, so the L2 total has their 19 fails too.

| Step | Result |
| --- | --- |
| check, fmt | pass (no change of a `.roc` file) |
| l0 | pass |
| l2 | FAIL, 23 cases: the 4 of this slice and the 19 of slices 078b and 079b. Each of the 4: exit 18 (`no compiler is selected`) in place of the result. `vn1`: all 6 runs (run 5, `--no-check`, also stops with exit 18; runs 4 and 6 give 18 in place of 13). `pn1`: runs 1 to 3. `us4`: runs 1 and 2. `rm3`: runs 1 and 2. |

With the private reference: the 4 cases pass, `scripts/test.sh l2` has only the 19 fails of slices 078b and 079b (their code is away), no other change.

## 10. Revert check (TW12)

9 changes of the reference, one at a time (`research/slice-072d-revert/mutate.py`). All are caught. The change m3 (`--no-check` still picks) is dropped: no test can reach the guard (section 7).

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | `LockNoCheck` stops (exit 18) | `rm3` |
| m2 | `Verify` stops | `vn1`, `pn1` |
| m4 | Step (b) goes on after the first non-pass | `vn1`, `pn1`, `us4` (extra probes in `calls.log`) |
| m5 | Step (b) has no check and build of the project | `vn1`, `pn1`, `us4` |
| m6 | Step (b) ignores the budget `left` | `vn1` (run 6) |
| m7 | `probe` has no pick | `pn1` |
| m8 | `roc use` has no pick | `us4` |
| m9 | Step (b) never runs (`max` 0) | `vn1`, `pn1`, `us4` |
| m10 | `verify` has no pick | `vn1` |

## Review (manager, 2026-10-26)

| Item | Result |
| --- | --- |
| Split | Accepted. 072d is the tested core. 072e waits for Q-D2 to Q-D5 (sent to the design agent). Q-D6 is a code question: the code agent finds the cause. |
| Output proposals | Accepted: steps (a) and (b) print nothing, (c) and (d) reuse the 072b text, the probes of step (b) are not in `--json` `data.probes`. |
| Next | Code agent: green for the 4 cases. |

The private reference and `mutate.py` are deleted. `research/slice-072d-revert/before/` stays.

## 072e scope (proposed, not tested)

| Part | Blocked by | Cases that wait |
| --- | --- | --- |
| The pick of `install`, `update`, `add`, `upgrade`, `remove` with checks and no pin, and the free-nightly `NoCompiler` in `InstallFlow` | Q-D2 | `roc/so9-no-roc`, `roc/so9-hash-fails`, `resolve/rs-no-compiler` run 1, `tool/dl1-sweep` run 5 |
| The relative selector (R-SL7) | Q-D3 | `roc/bs2-no-pin`, `roc/bs3-range`, L3 `compilers/bs1-base-ranks`, `cl1-nightly-list` |
| `Proxy` step 9 (R-PX4) | Q-D4 | `proxy/px1-flow`, L3 `px1-proxy`, `so9-launcher` |
| `roc use` with the pick and the new compiler both missing | Q-D5 | none yet |
| `init/it4-nocompiler` (the upgrade after the init download shows `nothing to change`) | Q-D6, a code question | `init/it4-nocompiler` (list for the code agent) |

## Disputes (from the code agent)

None.

## Verify results (code agent)

Code: new module `HeldRoc` (`held!`, private `probe_one!`, `fetch!`, `nodes_of`; exposed in `cli/lib/main.roc`), `ResolveBase.check_pin` (role `[Lock, LockNoCheck, Verify]`: only `Lock` stops at no compiler), `InstallFlow` and `RemoveFlow` (`LockNoCheck` with `--no-check`), `ProbeFlow.single!`, `VerifyFlow.verified!`, `RocUse.fallback!` call `HeldRoc.held!`. Decisions beyond the slice: the guard for `no_check` and `no_probe` in `held!` is dropped (the slice says no test can reach it); a project with no member file (`request.project.file` is `Err`) skips the project check and build of step (b); step (b) starts no project check when `left` is spent. No dispute. No question. 072e is not done.

`scripts/test.sh` exit 0 (check, fmt, l0, l2, l3, selftest, l1), run once with the code of the 3 slices 078b, 079b and 072d. Revert check: `research/slice-072d-revert/agent-mutate.py` (filtered L2 runs, one change at a time; the file goes back from a copy after each run). Result: caught 7 of 8.

| Id | Change | Result |
| --- | --- | --- |
| c1 | `--no-check` stops at no compiler (`LockNoCheck` gives exit 18) | `rm3` |
| c2 | `verify` stops at no compiler | `vn1`, `pn1` |
| c3 | Step (b) goes on after a non-pass | `vn1`, `pn1`, `us4` |
| c4 | The units of step (b) ignore the budget `left` | `vn1` (run 6) |
| c5 | A failed project build or check counts as a pass (2 forms) | not caught: no case has a unit pass and a project check or build that fails in step (b) |
| c6 | `probe` has no pick | `pn1` |
| c7 | `roc use` has no pick | `us4` |
| c8 | `verify` has no pick | `vn1` |

The code is the same as before the mutations (`sha256sum -c` of `research/slice-072d-revert/code-final.sha256` against `cli/lib`; the copy is in `research/slice-072d-revert/code-final/`).

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Disputes, questions | none |
| Mutation c5 not caught | A failed project check or build in step (b) counted as a pass. The gap test (all units pass, then the project check or build fails) goes to the 072e test step. |
| Q-D2 (design, after this slice) | `--no-check` picks nothing (R-SO19). The 072e test step checks that `HeldRoc.held!` with `LockNoCheck` agrees. The code agent dropped the `--no-check` guard in `held!`. |
