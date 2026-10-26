# 080 A compiler is always selected

Phase: P1. Status: done

Slice 080 is the plan row 080 of `PLAN-P1.md` (section 2c). Source: R-SO24 (Resolution 13), the decisions of `DESIGN-GAPS-2026-10-26.md` section "Invariant: a compiler is always selected", and the close item of 072e.
Test agent output. The code agent makes the tests green (TW18: it does not edit them).

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-SO24 | After an install of a nightly or release, `default-roc` is set when it was not set. The write is under the item lock, before the final rename of the toolchain. A crash between the two leaves a default that names a missing compiler (R-SO12 downloads it). `tln roc link` sets no default. | L2 about 60 cases (the install block in `calls.log`), `dl1`, `px2`, `rm1`, `lk1`, L3 `dl1`, `dl3`, `px2`, `us1` |
| R-SO14 | No rank selects a compiler only when nothing is installed, no `roc` is on `PATH`, no default is set and the project has no pin: the pick (download, consent) is unchanged. The probe steps (a) and (b) of 072c to 072e are gone (dead code). | `norank/nr1-order`, `verify/vn1`, `probe/pn1`, `roc/us4`, `NoRankTest` |
| R-SO15 | An install for the work of a command sets the default when none is set (the same write as R-SO24). A user act (`setup`, `roc default`, `roc install --default`, `tool install` of a git build) keeps `first_default!`. | `consent/dl1`, `fetch/fe-*`, `roc/df1`, `roc/ri1` |
| R-SO6 | Rank 6: `default-roc`. When it is not set and a nightly or release is installed, the newest installed one (new rank `Newest`, a git build is never chosen). Rank 6 is before rank 7 (`PATH`). | `CompilerTest`, `ProxyTest`, `proxy/px5`, `tool/tc3-newest` |
| R-RR1 | `tln roc remove` of the default moves it to the newest installed compiler that the nightly switch admits, else to the newest nightly or release of any kind, with a note when the switch rejects it. | `ManageTest`, `roc/rm1-remove`, L3 `mg1` |
| R-ST16 | `tln setup` with no default and a compiler installed writes the newest installed one (no download). | `setup/st8-first-default` run 7 |
| R-T30 | A tool flow with no pin takes rank 6 before `PATH`. | `tool/tc3-newest` |
| R-NI17, R-PX4, R-SO22 | The proxy and the first probe: the download makes the default (R-SO24); the proxy with rank 6 writes nothing. | `proxy/px5` runs 6 and 7, L3 `px1`, `px2` |

## 2. Public signatures (stubs exist, they crash with `todo: slice 080`)

| Module | Signature | Rule |
| --- | --- | --- |
| `Compiler` | `Rank` has the new tag `Newest` (between `Default` and `Path`) | R-SO6 |
| `Compiler` | `newest_installed : { installed : List(Str), times : List({ id : Str, published_at : U64 }) } -> Try(Str, [None])`. Nightly and release ids only, ordered by `Pin.order`. | R-SO6 |
| `Compiler` | `newest_note : Str -> Str`. Text: `default-roc is not set, so <id>, the newest installed compiler, is used. Run: tln setup, or tln roc default <id>` | R-SO6 |
| `Manage` | `move_note : { next : Str, nightly : Bool } -> Try(Str, [None])`. `Ok(text)` when `next` is a nightly and the switch is off (`nightly` is the switch). | R-RR1 |
| `Manage` | `next_default` falls back to the newest nightly or release of any kind. | R-RR1 |
| `Base.Rank` | new tag `Newest`, `rank_of`, `Proxy.source_text` = "the newest installed compiler", `ResolveSelect.rank_from` (`Newest => Default`). Stubs have them. | R-SO6 |
| `SetupText.Default` | new tag `Repaired(Str)`. stdout `default compiler: <id> (the newest installed compiler)`. `--json` action `repaired`. Stub has it. | R-ST16 |
| `NoRank.Run` | no `probe` field. Removed: `NoRank.Probing`, `NoRank.First`, `NoRank.first`, `NoRankPure.first`, `NoRankPure.First`, `first_of!`, `installed!`, `probed!`, `HeldRoc.ensured!`, `probe_one!`, `fetch!`, `nodes_of`, the step (a)/(b) branch of `HeldRoc.picked!`. `, probe: Skip` is removed from `Init`, `PathFlow`, `ResolveBase`, `ToolFlow`, `tests/commands/main.roc`. Stubs have it. | R-SO14 |

## 3. What the code agent implements (the shape is in `calls.log`)

A private reference exists in `research/slice-080-revert/reference/cli/lib/` (22 files). The tests are green with it. It is a guide, not the answer: the code agent may write another form with the same effects.

| No | Behavior | Place |
| --- | --- | --- |
| 1 | `RocInstall.install_offer!` calls `set_default!` under the item lock, before `fx.rename!` of the toolchain: lock `config.toml`, read it, (read and `write_atomic` only when no default is set), unlock. The result has `default: Set or Kept`. | `RocInstall` |
| 2 | The calls of `first_default!` after an install go away in `NoRank.ensure!` (Present and Download), `Start`, `Proxy`, `RocUse`, `NightlyFlow`, `ToolCompilerFlow`, `ToolUpdateFlow`, `RocInstall.flow!` (uses `done.default`). `RocManage.fetched!` and `download!` return `defaulted : Bool`; `default_flow!` and `update_flow!` skip the second edit when it is true (the output keeps `Set`). `GitInstall`, `SetupFlow` and `flow!` Present keep `first_default!`. | many |
| 3 | Rank 6 fallback: `Compiler.select` with `default` unset takes `Compiler.newest_installed` before rank 7. The note is printed on stderr (`note: <text>`) once, in `ResolveSelect.choose!` and in `Proxy.go!`. No file write. The listing of `<cache>/toolchains` always happens (`ResolveSelect.picked!` `lists = True`, the proxy lists always). | `Compiler`, `ResolveSelect`, `Proxy` |
| 4 | Tools: `ToolFlow.selected_for!` calls `Compiler.newest_installed` (one `list_dirs`) before the `PATH` lookup, and prints the rank 6 note on stderr (`fx.err!`) when rank 6 gives the compiler. | `ToolFlow` |
| 5 | R-RR1: `Manage.next_default` fallback and `Manage.move_note`. `RocManage.remove_flow!` prints `note: <text>` on stderr after the move. | `Manage`, `RocManage` |
| 6 | Setup: `SetupFlow.default_step!` with no default calls `Launch.toolchains!` and `newest_installed`. `Ok(id)`: `first_default!`, `Repaired(id)`. `Err(None)`: the old path. | `SetupFlow` |
| 7 | Dead code (section 2 last row). | many |

## 4. Tests

Layers: L0 pure (`roc test`), L2 command cases (`tests/commands/cases`), L3 scenarios (`tests/scenarios`).

| Layer | File or case | What | Rule |
| --- | --- | --- | --- |
| L0 | `CompilerTest` | 9 `select` rows with `Newest`, `newest_installed`, `newest_note` | R-SO6, R-SO24 |
| L0 | `ManageTest` | `next_default` rows (fallback to any kind), `move_note` | R-RR1 |
| L0 | `ProxyTest` | rank 7 off row, Newest row, rank 6 before 7, default names a missing id gives Missing | R-SO6, R-PX4 |
| L0 | `NoRankTest` | `NoRank.first` expect deleted | R-SO14 |
| L2 | `norank/nr1-order` | rewritten: 6 runs with nothing installed (steps c, d, outside, gate, home2, home3) | R-SO14 |
| L2 | `verify/vn1-nocompiler` | 4 runs, run 1 = rank 6 case 3. h2, h6, n6 removed. `vn2-step-b-project` deleted | R-SO14, R-SO6 |
| L2 | `probe/pn1-nocompiler`, `roc/us4-nocompiler` | h2, n2 removed, rank 6 note | R-SO14, R-SO6 |
| L2 | `proxy/px5-no-rank` | run 6 rank 6 with note, run 7 default names a missing id: download, config unchanged | R-SO6, R-SO12 |
| L2 | `proxy/px1-flow` | rank 7 runs use an empty cache (`XDG_CACHE_HOME={w}/nocache`) | R-SO6 |
| L2 | `setup/st8-first-default` | run 7: `setup --json` repair | R-ST16 |
| L2 | `roc/rm1-remove` | switch off: default moves to the newest nightly of any kind with note | R-RR1 |
| L2 | `link/lk1-link` | comment: link sets no default | R-SO24 |
| L2 | `tool/tc3-newest` (was `tc3-path-roc`) | rank 6 for tools, no `path_roc` | R-T30, R-SO6 |
| L2 | `consent/dl1-resolve`, `proxy/px2-install` | text and ids | R-SO24 |
| L2 | about 60 cases: `expect/calls.log` | the install block (lock, read, [read, write], unlock) before the rename; one `list_dirs` of toolchains. Some `tree.diff` (config.toml has `default-roc`), a few stdout and stderr (note lines) | R-SO24 |
| L2 | givens of `init/it1`, `it2`, `it3`, `upgrade/ur1`, `ur4` | `default-roc = "nightly-2026-10-09-9d9d9d9"` added to every home that had no default (the state "installed, no default" is not a state any more) | R-SO24 |
| L2 and L3 | `tool/tc2`, `tc3-newest`, `tg1`, `ti2-refusals`, `tk1`, `ptool/pt3-move`, `x/x3-project`, L3 `ptools/pt1`, `pt2`, `run/rn1`, `tools/ti1`, `ti2`, `ti3`, `tx1` | the rank 6 note on stderr of tool commands (Q2) | R-SO24, R-SO6 |
| L3 | `compilers/dl1`, `dl2`, `dl3`, `mg1`, `px1` (new `http.log`), `px2`, `us1`, `exit/ex3`, `ptools/pt1`, `pt2`, `run/rn1`, `tools/ti1`, `ti2`, `ti3`, `tx1` | regenerated: install block, no `version` probe of the `PATH` roc when rank 6 selects an installed compiler, `ti2` prompt has no line "It becomes the default compiler." | R-SO24, R-SO6 |

Edits of old tests (TW21): every changed expected file is a consequence of R-SO24, R-SO6, R-RR1 or R-SO14. The brief of each pattern: (1) the install block in `calls.log`; (2) a `version` call of the `PATH` roc is gone when an installed compiler is selected by rank 6; (3) cases with the states "installed, no default" got a default in the given.

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| Rank 6 note | stderr `note: default-roc is not set, so <id>, the newest installed compiler, is used. Run: tln setup, or tln roc default <id>`. Printed by every command that uses rank 6 (also the tool commands and the proxy), one for each run. |
| `move_note` | `<id> is a nightly and the nightly switch is off, so commands that use the default stop with exit code 10 until you change the switch or install an admitted compiler`. Printed as `note: ...` on stderr by `tln roc remove`. |
| Setup | stdout `default compiler: <id> (the newest installed compiler)`. `--json` `data.default_roc`: `{ "action": "repaired", "id": ... }`. |
| `Proxy.source_text` | "the newest installed compiler" |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| R-SO24 case 4 crash between the default write and the rename | The fake `Fx` cannot stop a flow between two calls. The L0 row "default names a missing id" and `px5` run 7 test the state after it. |
| Two processes at one time (R-SO24 lock rule) | Only L3 `px2-proxy-install` can run two processes. |
| `tln tool rm talon` | No change. |
| Size | About 90 changed L2 files. No split (manager): one code agent does parts A (install default, rank 6, R-RR1, setup, dead code) and B (tool rank 6 and its note). |

## 7. Questions (TW17)

All closed by the manager (see the review).

## 8. Disputes (from the code agent)

| No | Test | Problem | Design source | State |
| --- | --- | --- | --- | --- |
| D1 | `setup/st8-first-default` run 7 | `given/home5` has no `.local/share/talon/bin/tln`, so the run stops at exit 18 (`tln is missing`) before `default_step!`. No test reaches the repair (`Repaired`, `repaired` in `--json`). A mutation that makes setup never repair is not caught (the code agent ran it: all 204 L2 cases pass). | R-ST16, R-SO24 case 3 | Not edited (code agent rule). The code agent added the file `home5/.local/share/talon/bin/tln` (a copy of the one of `home2`) in a temp run: the actual output is the design output (stdout `default compiler: nightly-2026-10-16-1df370f (the newest installed compiler)`, `--json` action `repaired`, calls: one `list_dirs` of toolchains, lock, 2 reads, `write_atomic`, unlock, no `http_get`). Then the file was removed. The test agent must add the file and regenerate `expect/` of run 7. Result (test agent, 2026-10-26): accepted and fixed. `given/home5/.local/share/talon/bin/tln` added (copy of the file of `home4`). `expect/` of run 7 regenerated with the code of the slice and every diff read: stdout line `default compiler: nightly-2026-10-16-1df370f (the newest installed compiler)`, `--json` `data.default_roc` = `{"action":"repaired","id":"nightly-2026-10-16-1df370f"}`, exit 0 (was 18), `calls.log` gets the bin dir entries, one `list_dirs` of toolchains, the `config.toml` lock, 2 reads, `write_atomic`, unlock, and no `http_get` in run 7. Hand mutation (`SetupFlow.default_step!` never repairs, goes to `latest_default!`): run 7 fails on the missing line and `repaired`; the file was restored. |

## 9. Revert check (TW12)

Done with the private reference, 10 mutations (the reference and `mutate.py` are deleted). Each one made at least one test fail.

| No | Mutation | Failing tests (examples) |
| --- | --- | --- |
| m1 | default written after the rename | 35 L2 cases (`calls.log` order) |
| m2 | an install overwrites a set default | `dl1`, `dl3-rank4`, `fe-none`, `it1`, `pd1`, `px2` |
| m3 | R-RR1 has no any-kind fallback | `ManageTest`, `rm1-remove` |
| m4 | rank 7 before rank 6 | `CompilerTest`, `ProxyTest` |
| m5 | a git build can be the newest | `CompilerTest` |
| m6 | the proxy writes the default on `Newest` | `px5` |
| m7 | setup never repairs | `st8` |
| m8 | no rank 6 note | `pn1`, `us4`, `vn1` |
| m9 | the proxy lists toolchains only when needed | `px1-flow`, `px5` |
| m10 | tool commands print no rank 6 note (Q2) | `tc2`, `tc3-newest`, `x3-project`, L3 `tx1` |

## 10. Red output (stubs in place)

Stub state: old behavior, the dead code removed, new tags, `crash "todo: slice 080"` in the three new functions. `roc check` of `cli/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc`, `cli/lib/main.roc`, `tests/commands/main.roc` pass. `roc fmt --check` of changed files passes.

| Layer | Result |
| --- | --- |
| L0 | `l0-1`, `l0-5`, `l0-6` fail (todo crash, wrong values). The others pass. 0 compiler errors. |
| L2 | 141 passed, 63 failed (wrong output: install block, missing note, old default). |
| L3 | 14 failed (70 passed, 3 skipped): `compilers/dl1`, `dl2`, `dl3`, `mg1`, `px2`, `us1`, `exit/ex3`, `ptools/pt1`, `pt2`, `run/rn1`, `tools/ti1`, `ti2`, `ti3`, `tx1`. No compile error. |

## 11. Files kept

| Path | Content |
| --- | --- |
| `research/slice-080-revert/before/` | the files before this slice (old tests, old cli files). `NEW.txt` lists the added files. |

The stubs are in `cli/lib` (13 files). The private reference, the stub copies and `mutate.py` are deleted (manager, 2026-10-26).

## Review (manager, 2026-10-26)

| No | Answer |
| --- | --- |
| Q1 | Yes: the proxy prints the rank 6 note on each run, on stderr (stdout stays the output of `roc`). |
| Q2 | Yes: tool commands print the rank 6 note when they use rank 6 (R-SO24: one note for each run that uses it, for every command). Tests: the tool L2 cases and L3 cases of section 4, and the rule text of `tool/tc3-newest`. |
| Q3 | Closed, moot. `upgrade --no-check` with a free nightly is exit 2 (R-UP9, `Upgrade.read`) before `InstallFlow.resolve!`. The `Err(NoCompiler)` branch there cannot be reached from the CLI. No test, no change. |
| Q4 | Accepted. With no default set, the download of a tool pin does become the default (R-SO24: an install writes the default when none is set), so the prompt line is correct. |
| TW24 | All proposals accepted: the note text, `move_note` text, setup stdout and `repaired` json action, the proxy source text. |
| Size | No split. One code agent does parts A and B. |

## Verify results (code agent)

Code: `research/slice-080-revert/code-final/` (15 files), `code-final.sha256`. `scripts/test.sh`: check, fmt, l0, l2 (204 passed), l3 pass. Mutations (one small break each, the test run, the code put back and compared):

| No | Mutation | Result |
| --- | --- | --- |
| 1 | `install_offer!` does not set the default | 35 L2 cases fail |
| 2 | `newest_installed` without the `Pin.is_id` filter | `CompilerTest` fails (L0) |
| 3 | the proxy prints the rank 6 note for `Path`, not `Newest` | `px1-flow`, `px5-no-rank` |
| 4 | `next_default` without the any-kind fallback | `ManageTest` (L0) |
| 5 | setup never repairs | not caught (dispute D1) |
| 6 | `roc default` and `roc update` ignore `defaulted` (second edit always) | `up1-update` and one more |
| 7 | tool commands skip rank 6 (`newest_of!`) | `x3-project` and 7 more |


## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none; no `Probing` left in `cli/lib` |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Dispute D1 | accepted; the test agent fixed `setup/st8-first-default` run 7, and the "setup never repairs" mutation now fails it |
| Revert check | 7 of 7 caught after the D1 fix |
