# 062 The default compiler is set by a user act

Phase: P1. Status: done

Slice 062 is the plan row 062 of `PLAN-P1.md` (section 2c). It closes gap rows 046 G3 and 053 F4. User words: "The default compiler should only be set by user intent, not just downloading a later nightly to build something."

R-SO15 (rewritten 2026-10-25): only a user act writes `default-roc`. A download that a command makes for its own work installs the compiler and never sets the default.

## 1. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-SO15 | The table of acts (below) | L2 and L3 cases of section 4 |
| R-SO14 (part) | Only the sentence that a download for a command never sets the default, when a rank gives the compiler | the same cases |

| Act | Effect on `default-roc` | State in the code today | After the slice |
| --- | --- | --- | --- |
| `tln roc default <ref>` | Sets it always (R-CS2) | done | no change (the download of a missing compiler no longer sets it first: one lock, not two) |
| `tln roc install <ref>`, `--git`, `@<sha>` | Sets it when none is set, also for an installed compiler. Never changes a default that is set | only after a download (`Installed`) | also when the compiler is present |
| `tln roc update` | Moves or sets it (R-RU2) | the first default came from `install_offer!` | `moved_default!` sets it (`before` is unset) |
| `tln roc rm` of the default | Moves it (R-RR1) | done | no change |
| a probe, `tln upgrade`, `tln init`, `tln roc use`, a tool pin, a project tool, `x`, the proxy when a rank gives the compiler | Never | `install_offer!` sets it when none is set | never |

## 2. Where the code changes (for the code agent)

The tests fix the `calls.log` of each case, so the calls below are part of the contract. The private reference (2 files, `RocInstall.roc` and `GitInstall.roc`, 48 diff lines; deleted at the review, 2026-10-25) makes all tests pass.

| # | Place | Change |
| --- | --- | --- |
| 1 | `RocInstall.install_offer!` | Never calls `set_default!`. The result field `default` stays and is always `Kept` (`Toolchain.report` and `Toolchain.data` use the field: no L0 change) |
| 2 | `RocInstall.flow!` (the `tln roc install` flow) | After `Present(found)`: `set_default!(fx, roots, found.id)`, the result has that `default`. After `Download` and `install_offer!`: `set_default!(fx, offer.ctx.roots, done.id)`, also for `how == Present` (another process won). `set_default!` is the one that exists: under the lock of `config.toml`, `Keep` when a default is set (so: lock, read, unlock), else two reads and `write_atomic` |
| 3 | `GitInstall` (step after the `locked!` of `install!`) | `RocInstall.first_default!` for `Installed` and for `Present` |
| 4 | `RocManage.default_flow!`, `download!`, `update_flow!` | No change is needed: `first_default` is now always false, so `default_flow!` sets with its own `edit_config!` (one lock) and `update_flow!` goes to `moved_default!` (which sets when `before` is unset). The field `first_default` may be removed |
| 5 | Callers of `install_offer!`: `Proxy`, `Start`, `RocUse`, `NightlyFlow`, `ToolCompilerFlow`, `ToolUpdateFlow`, `RocInstall.fetch_optional!` (probes) | No change in the callers: they get the new behavior from item 1. A new `first_default!` in any of them is a bug (revert mutations M3, M4, M6) |

Where slice 072 touches the same code: `Start.run!` (step 0e) and `Proxy` (step 9e) are the places that download when no rank selects a compiler (R-SO14). 072 sets the default there, when none is set, with `RocInstall.first_default!` or `set_default!`. This slice leaves them with no default write. 072 also adds `tln setup` writing the first default.

## 3. Public signatures

No new function, type or `Fx` field. The code agent adds no stub: all the changes are in existing bodies.

## 4. Tests

No L0 row: there is no new pure decision (`Toolchain.default_edit` is tested already). No L1 change. The change is the removal of the write of `default-roc` from `calls.log` and `tree.diff` of the cases that show a download for a command, and one new write in the cases that install an installed compiler. No case was added: `roc/bs1-base` and `roc/bs3-range` show `roc install` of an installed compiler when no default is set.

| Layer | Case | What changes | Rule ids |
| --- | --- | --- | --- |
| L2 | `roc/bs1-base` | run 1 (`roc install @-1`, the compiler is installed, no default): the lock, 2 reads and the write of `config.toml`, the stdout line `<id> is now the default compiler`. Runs 2 and 3: the default is set, no change (lock, read, unlock). Run 4 (`roc default @-1`) says `is already the default compiler` | R-SO15, R-CS2 |
| L2 | `roc/bs3-range` | run 1: the same as `bs1-base` run 1 (also the `tree.diff` has `config.toml`) | R-SO15 |
| L2 | `roc/bs2-no-pin`, `roc/cv1-pins`, `roc/ri1-flow`, `roc/gi2-zig` | `roc install` of an installed compiler with a default set (or a lost race): the new calls lock, read, unlock of `config.toml` (Keep) | R-SO15 |
| L2 | `roc/df1-default`, `roc/up1-update` | the download sets the default once, not twice: one lock cycle in place of 2 (the file result and stdout are the same) | R-SO15, R-CS2, R-RU2 |
| L2 | `consent/dl1-resolve`, `consent/dl2-verify-workspace`, `consent/dl3-rank4` | a download for a probe: no lock, no write of `config.toml`, no `default-roc` in `tree.diff` | R-SO15 |
| L2 | `init/it1-app`, `upgrade/ur1-roc`, `upgrade/ur2-consent` | `init` and `upgrade` download: `config.toml` keeps only `[probe]` | R-SO15 |
| L2 | `proxy/px2-install` | the proxy with a rank 3 pin: no default | R-SO15, R-PX4 |
| L2 | `roc/us1-use` | `roc use` downloads: no default write (7 places) | R-SO15 |
| L2 | `probe/pd1-downloads`, `upgrade/ur5-optional` | optional downloads of a probe search: the `calls.log` has no lock of `config.toml` | R-SO15 |
| L2 | `tool/ti2-refusals`, `tool/ti3-compiler` | run 7 of `ti2` and run 8 of `ti3` download a pin: no default. The later unbundle lines (6 in `ti2`, 1 in `ti3`) run the newest installed compiler `38a3029` again (slice 064, Out 4) | R-SO15, R-FE4 |
| L2 | `tool/tr1-rebuild`, `tool/tu1-update` | a tool pin download: no default in `tree.diff` | R-SO15 |
| L3 | `compilers/dl1-resolve-consent`, `dl2-consent-tty`, `dl3-rank4-download`, `px2-proxy-install` | no `config.toml`: the script shows `no default-roc (no config.toml)` (the new function `default_roc` in `cmd`) and the comments no longer say that the first install is the default | R-SO15 |
| L3 | `compilers/us1-use`, `exit/ex3-no-tuple-yaml` | `roc use` and `tln upgrade roc` download: `tree.diff` has no `config.toml` | R-SO15 |
| L4 (net, not run in the fast set) | `exit/ex1-parser-basic-cli` | `tree.diff` has no `config.toml` (edited by hand: the case needs the network) | R-SO15 |

Counts: 22 L2 cases and 6 L3 cases change, 45 expected files, 12 comment or `cmd` edits. No new case. The old copies are in `research/slice-062-revert/before/` (`NEW.txt` lists this slice file).

## 5. Output (proposed, R-OUT2)

No new text. One combination is new: `tln roc install <id>` of an installed compiler when no default is set prints the 2 existing lines of `ToolchainReport.report`:

```text
nightly-2026-10-13-91fa0c2 is already installed
nightly-2026-10-13-91fa0c2 is now the default compiler
```

With `--json` the `data.default` is `true` and `data.installed` is `false` for that run.

## 6. Decisions that the design does not fix (D, for the review) and out of scope

D1 to D4 and the L3 helper `default_roc`: accepted by the manager, 2026-10-25.

Until slice 072, a download in `Start` step 0e and `Proxy` step 9e when no rank selects a compiler writes no default. Slice 072 restores it under R-SO14.

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `roc install` of an installed compiler when a default is set still takes the lock of `config.toml` and reads it (lock, read, unlock: the calls of the `Keep` path of a download) | pass the config of `offer!` to the flow (a change of the `Offer` type, no gain in a rare path) |
| D2 | `roc default <missing>` and `roc update` set the default in their own step, so a download does one lock cycle of `config.toml`, not two | keep the write in `install_offer!` for these 2 commands |
| D3 | The L3 scripts print `no default-roc (no config.toml)` in place of `cat $C` (a failed `cat` ends a `sh -e` script) | delete the `cat` lines (the case would not show that no default is written) |
| D4 | `GitInstall` sets the default also for `Present` (the user named the build). No L2 case shows the `Set` of that path: the `Present` runs of `gi2-zig` have a default | add a case for a git install of a present build with no default (the path is the same function as `roc install`, row 3 of section 2) |
| Out 1 | `tln setup` writes the first default (slice 072) | |
| Out 2 | The case that no rank selects a compiler and nothing is installed: the download that sets the default (R-SO14, slice 072) | |
| Out 3 | The design rows of R-SO14 (2) "when that compiler is already installed Talon only sets the default" (slice 072) | |

## 7. Questions (TW17)

None. The design agent settled R-SO15 and R-SO14 on 2026-10-25.

## 8. Verify results (test agent, 2026-10-25)

| Step | Result |
| --- | --- |
| Red state (old code, new tests; run in a copy of the tree with `/tmp` as a private tmpfs) | L2: FAIL, 22 cases fail, 149 pass. L3: 6 fail (`dl1-resolve-consent`, `dl2-consent-tty`, `dl3-rank4-download`, `px2-proxy-install`, `us1-use`, `ex3-no-tuple-yaml`), 78 pass. Each failure is a missing or extra `config.toml` line in `calls.log`, `tree.diff` or stdout, or a wrong compiler in an unbundle line. The logs were deleted with the reference. l0, l1, check and fmt: not changed (no Roc file changed) |
| Private reference in a copy of the tree (`research/slice-062-revert/reference/sandbox`, deleted at the end) | L2: 171 of 171 pass. L3 fast: 84 pass, 3 skipped. Before the reference: 149 and 78 pass |
| Revert check (6 hand mutations of the reference, L2 only) | 6 of 6 caught |

| Mutation | Case that failed |
| --- | --- |
| M1 `roc install` of an installed compiler does not set the default | `roc/bs1-base`, `bs2-no-pin`, `bs3-range`, `cv1-pins`, `ri1-flow` |
| M2 `roc update` with no default does not set it | `roc/up1-update` (`changed` false, `--json`) |
| M3 `ToolCompilerFlow` option 1 download sets the default | `tool/ti3-compiler` |
| M4 `fetch_optional!` (probe search) sets the default | `probe/pd1-downloads`, `upgrade/ur5-optional`, `tool/ti2-refusals`, `tool/tr1-rebuild` |
| M5 `GitInstall` `Present` does not set the default | `roc/gi2-zig` |
| M6 `RocUse` download sets the default | `roc/us1-use` |

## 9. Verify results (code agent, 2026-10-25)

Code: `RocInstall.install_offer!` never sets the default; `RocInstall.flow!` sets it for `Present` and after the download; `GitInstall.build!` sets it for `Installed` and `Present`; `RocManage` lost the field `first_default` (always false). Comments only in `Proxy.roc` and `ManageUpdate.roc`. `scripts/test.sh` exit 0 (check, fmt, l0, l2, l3, selftest, l1 pass).

| Mutation (L2 only) | Case that failed |
| --- | --- |
| M1 `flow!` `Present` does not set the default | `roc/bs1-base`, `bs2-no-pin`, `bs3-range`, `cv1-pins`, `ri1-flow` (5 failed) |
| M2 `install_offer!` sets the default for `Installed` again | 18 cases failed (probe, init, upgrade, proxy, use, tool) |
| M3 `GitInstall` does not set the default for `Present` | `roc/gi2-zig` |
| M4 `update_flow!` does not write when `before` is unset | `roc/up1-update` |

Caught 4 of 4. The code is the same as before the mutations (compared with a copy).

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-062-revert/code-final.sha256` | 6 files OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, with 062 and 063 both in) | Exit 0, all 7 steps |
| Gap step | Skipped: 4 of 4 (6 with the test agent's) mutations caught, no new decision |
