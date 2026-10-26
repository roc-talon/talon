# 072c No rank selects a compiler: installed compilers first, and the other fetch flows

Phase: P1. Status: done

Slice 072c follows slice 072b. The decisions are in `DESIGN-GAPS-2026-10-26.md` (Q-B1 and "Probe installed first"). The rule R-SO14 now has this order for a command with a project (R-SO23):

| Step | Compiler | Download | Default | Where the code is |
| --- | --- | --- | --- | --- |
| (a) | The newest installed compiler that resolves: a recorded `pass` (check row, target `any`) for each hash of the header entries that has a fact, and at least one hash with a fact | No | No | `NoRank.first`, `NoRank.ensure!` |
| (b) | Else: probe the installed compilers, newest first (ladder of R-PB2, `probe.max`, `probe.timeout`). A compiler with a recorded `fail` for a hash is skipped (R-P4). The first pass is used. A spent `probe.max` ends the step with no exit 12. `--no-probe`, `--no-check` and a command that runs no probe (R-LF1) skip it | No | No | `NoRank.first`, `NoRank.ensure!` (`NoRank.Probing`) |
| (c) | Else: the newest compiler in the channel that resolves | Yes | Yes (R-SO15) | `NoRank.pick`, `offer!` (slice 072b) |
| (d) | Else: the latest in the channel | Yes | Yes | same |

A command with no project (scope `Outside`) skips (a) and (b): it downloads the latest in the channel (R-SO14 (2)). Slice 072c also adds the warning of R-CV6 to `NoRank.offer!`, and it wires the fetch flows that slice 072b did not wire.

## 1. Scope split (for the review)

| Part | In 072c | Moved |
| --- | --- | --- |
| The pure decision `NoRank.first` (steps (a), (b)) | yes, 24 rows | |
| `NoRank.ensure!` with (a) and (b) before the gate, with an injected probe (`NoRank.Probing`) | yes (L2 entry `norank`) | |
| R-CV6 warning in `NoRank.offer!` | yes | |
| Fetch flows `list`, `why`, `outdated`, `patch`, `path`, `init` | yes (L2 `fetch/fe-flows`, `init/it4-nocompiler`) | |
| `verify`, `remove`: the wiring | in the reference, no test (they stop at `check_pin` first, exit 18, before any fetch) | the tests to 072d |
| The real closure of `Probing.one!` (the ladder with `Ladder`, the facts, `probe.max`) | no: every fetch flow gives `Skip` | 072d (`check_pin`, `ProbeFlow`, `ManageUse`, `Proxy` are its direct callers) |
| `roc use`, `probe`, the proxy, `check_pin`, `run` | no | 072d. `run` has no fetch of its own |

Why (a) and (b) are tested with an entry of their own (`norank`): `Fetch.unbundler` takes the newest installed compiler before it calls `NoRank` (R-FE4, row 2). So no fetch flow reaches (a) or (b). Only a direct caller of `NoRank.ensure!` does (the callers of 072d). The entry `norank` is that caller at L2.

## 2. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-SO14 (1) (a) | The newest installed compiler that resolves is used: no download, no default, no consent gate | L0 `first` (the (a) rows); L2 `norank/nr1-order` runs 1, 9 |
| R-SO14 (1) (b) | Probe the installed compilers, newest first; skip a recorded fail; `probe.max`; no exit 12; no download, no default | L0 `first` (the (b) rows); `nr1-order` runs 2, 3, 4, 6, 7 |
| R-SO14 (1) (c), (d) | The channel (slice 072b), after (a) and (b) | `nr1-order` runs 4 to 7, 10; `fe-flows` runs 1 to 4 (the newest with a pass is N2, not the latest N4) |
| R-SO14 (2) | No project: (a) and (b) are not looked at | `nr1-order` run 8; `it4-nocompiler` |
| R-SO15 | (a) and (b) set no default. A download of (c) or (d) sets it when none is set | `nr1-order` runs 1 to 3 (`default-roc: none`), run 4 (set); `fe-flows`; `it4-nocompiler` |
| R-SO23 | The project of each command: the hashes of its header entries (`path`: its project file; `list`, `why`, `patch`: the walk; `init`: none) | `fe-flows` runs 1 to 4; `it4-nocompiler` |
| R-FE4, R-LF1 | A fetch with no compiler uses R-SO14. A command that runs no probe skips (b) | `fe-flows` run 5 (`outdated` downloads nothing); `Skip` in all flows |
| R-CV6 | One warning for each tag whose sha256 changed; a changed tag is not offered | `nr1-order` runs 10, 11 |
| R-P7 (as used) | A recorded hang or crash skips a compiler like a fail | L0 `first` |
| R-CV1, R-EF1, R-EF3, R-P4, R-NS6 (as used) | Both tag forms are one compiler; a build row is no evidence and no fail; a recorded fail is final; no local build | L0 `first` |
| R-P5, R-PP4 (as used) | `probe.max` counts the probes that start; the facts go to `compat.db` (the closure of 072d) | `nr1-order` runs 2 to 4 (`left=`); the facts: 072d |
| R-DL5, R-DL10 | The gate (`--offline`, `TALON_AUTO_INSTALL=no`) runs after (a) and (b) | `nr1-order` runs 1, 2, 9 |

## 3. Decisions (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | The gate runs after (a) and (b). This revises D1 of slice 072b: a refusal of a download must not stop a command that needs none | The gate first: `--offline` would stop a command that has a good installed compiler |
| D2 | `ensure!` makes two `db_query` calls when it downloads: one for the installed ids (before the gate), one in `offer!` (the channel ids). A run with no installed compiler id makes no first call (no key) | One shared query: `offer!` has the channel list after the gate, and the installed ids are known before it |
| D3 | The probe is injected: `NoRank.Run.probe : [Skip, Run({ max, one! })]`. `one!({ id, left })` returns `{ passed, probes }`. `ensure!` stops when the probes that started reach `max`, and gives `left = max - started` | The ladder inside `NoRank`: a cycle of modules, and 072c has no fixture for the ladder (072d) |
| D4 | Every fetch flow of 072c gives `Skip` (`ResolveBase.no_rank`, `PathFlow`, `Init`). The real closure is in 072d | A closure in 072c that no test can reach |
| D5 | `Outside` skips (a) and (b) | Looking at the installed compilers with no facts: step (b) would probe for a project that does not exist |
| D6 | `Ls.request_of` has `downloads.auto: Consent.auto_install(start.env)` in place of `Ask` (`list`, `why`, `outdated`, `patch` ignored `TALON_AUTO_INSTALL`) | A new consent field |
| D7 | The cases show the intermediate behavior of the reference where a flow goes on after the fetch (`it4-nocompiler`: `nothing to change`, see its `rules`). It changes in 072d | A case that waits for 072d |
| D8 | `fe-flows` has one home for each run (`h1` to `h5`): a download changes the machine, and a run must start with no compiler | One home: only the first run shows a download |

## 4. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `NoRank.first` | Body. The doc table is the rule: a `Fail`, `Hang` or `Crash` row of a hash of the project skips a compiler. The two tag forms of one nightly are one compiler (`Pin.same_id`); the result has the name of the installed dir |
| 2 | `NoRank.ensure!` | The 9 steps in its doc. (a) and (b) are before `gate`. `Outside`: no query |
| 3 | `NoRank.offer!` | R-CV6: one `warning: ` line on stderr for each changed tag (`Toolchain.changed_warning`), also before the failure `pick_failed`. The line comes from `Nightlies.list!`'s `changed` |
| 4 | `Ls.walk_full!` (`list`, `why`), `OutdatedFlow`, `PatchFlow`, `VerifyFlow` | `none: ResolveBase.no_rank(asked, loaded)` in the request |
| 5 | `Ls.request_of` | `auto: Consent.auto_install(start.env)` |
| 6 | `PathFlow.fetch!` | `none: Download({ scope: Project(<hashes of the release rows of the project file>), downloads, probe: Skip })`. `downloads` from the args and the env (`yes`, `mode`, `quiet`, `offline`) |
| 7 | `Init` (`platform_header!`, both call sites: step 4b and `remake!`) | `none: Download({ scope: Outside, downloads, probe: Skip })` |
| 8 | `RemoveFlow`, `RocUse`, `ProbeFlow`, `Proxy` | not in 072c (072d) |

The private reference of the test agent is deleted (manager rule, 2026-10-26). `research/slice-072c-revert/before/` has the files that the test agent changed.

## 5. Public signatures

| Name | Signature | State |
| --- | --- | --- |
| `NoRank.Probed` | `{ passed : Bool, probes : U64 }` | done |
| `NoRank.Probing` | `[Skip, Run({ max : U64, one! : { id : Str, left : U64 } => Try(NoRank.Probed, Fail) })]` | done |
| `NoRank.Run` | `{ scope, downloads, probe : NoRank.Probing }` (new field `probe`) | done |
| `NoRank.First` | `[Use(Str), Probe(List(Str))]` | done |
| `NoRank.first` | `{ installed : List(Str), hashes : List(Str), facts : List(Db.Fact) } -> NoRank.First` | stub (`crash "todo: slice 072c"`) |
| `NoRank.ensure!`, `NoRank.offer!` | as in 072b | the body of 072b (the doc has the new steps) |
| `ResolveBase.no_rank` | gives `probe: Skip` | done |

## 6. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/NoRankTest.roc` (driver `l0-5.roc`), `first` | 29 rows: (a) the newest that passes for each known hash; the order of `installed` does not matter; a repeated hash; a hash with no fact is ignored; no known hash gives `Probe`; a build row is no evidence; the other tag form (R-CV1) gives the installed name; (b) a recorded fail, hang or crash skips a compiler; a fail of another hash skips it too; a local build is ignored, also with a recorded pass (R-NS6); a release is older than every nightly; two nightlies of one day are in the order of the tag | R-SO14, R-EF1, R-EF3, R-CV1, R-NS6, R-P4, R-P7 |
| L2 | `norank/nr1-order` (new, 11 runs, entry `norank`) | 1: (a) with `--offline` and `TALON_AUTO_INSTALL=no`. 2: (b) probe order N3 then N2 (`left=100`, `left=98`). 3: a recorded fail is skipped. 4: `probe.max` 3 and cost 2: N3, N2, no N1, no exit 12, then (d). 5: `Skip`, then (d). 6: (b) no pass, then (d). 7: nothing to probe, then (c) picks N2. 8: `Outside`. 9: the gate after (a) and (b): exit 13. 10, 11: R-CV6 warning, and all tags changed (exit 10) | R-SO14, R-SO15, R-SO23, R-CV6, R-P4, R-P5, R-DL5, R-DL10 |
| L2 | `fetch/fe-flows` (new, 5 runs, one home each) | `list`, `why`, `path`, `patch` with no compiler: download N2 (the newest with a pass for the hash of the project, not the latest N4), set it as default, then unbundle. `outdated` downloads nothing | R-SO14, R-SO15, R-SO23, R-FE4, R-LF1, R-DL1, R-NI5 |
| L2 | `init/it4-nocompiler` (new, 1 run) | `init --platform` with no compiler: the latest is downloaded as default (`Outside`) | R-SO14 (2), R-SO15, R-FE4 |
| L2 | `tests/commands/main.roc`, `L2NoRank.roc` | the entry `norank` (words in the doc of `L2NoRank`) | |

## 7. Output (proposed, TW24)

| Item | Text |
| --- | --- |
| R-CV6 warning (stderr) | `warning: the sha256 of <tag> for <target> changed: ...Talon does not offer this compiler.` (the existing line of `Toolchain.changed_warning`) |
| (a) and (b) | no line: a compiler that is installed needs no message |
| The refusals and the prompt of (c), (d) | the texts of slice 072b, unchanged |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| The closure of `Probing.one!`, `check_pin`, `ProbeFlow`, `ManageUse`, `Proxy`, R-SL7, the exit-18 cases | slice 072d |
| Tests of `verify`, `remove`, `roc use`, `probe` with no compiler | They stop at `check_pin` (no pin: exit 18 before the fetch). With a pin that is not installed: question Q2 |
| `run` | no fetch of its own |
| `outdated` (the wiring) | it fetches no package (R-LF1), so no fixture reaches it |
| R-FE9 | P2 |

## 9. Questions (TW17), all answered

| Id | Answer (design agent, 2026-10-26, `DESIGN-GAPS-2026-10-26.md`) | In the tests |
| --- | --- | --- |
| Q1 | `Hang` and `Crash` skip a compiler in step (b), like `Fail` (R-P4, R-P7) | L0 `first`: 4 rows (a hang, a crash, a hang of another hash, a hang and a crash on every compiler) |
| Q2 | A pin that is not installed is downloaded by R-DL2. R-SO14 applies only with no pin | no test (072d) |
| Q3 | Local builds are never candidates in (a) or (b) | L0 `first`: 3 rows (R-NS6) |

## 10. Gaps

| Gap | Effect |
| --- | --- |
| The facts that `Probing.one!` writes (R-PP4) | not tested in 072c: the fake probe writes none |
| `verify`, `remove` wiring | in the reference, no case reaches it |
| `outdated` wiring | no case reaches it |
| `init` after the fetch | the expected file is the intermediate behavior (D7) |

## 11. Verify results (test agent, 2026-10-26)

Red state (stubs, new tests):

| Step | Result |
| --- | --- |
| check, fmt | pass |
| l0 | FAIL: `NoRankTest.roc:128` (the `first` expect) crashes with `todo: slice 072c`. The `ToolCompilerTest.roc` failures belong to slice 079 |
| l2 | FAIL, 3 cases from this slice: `fetch/fe-flows` (exit 18 in place of 0), `init/it4-nocompiler` (exit 18), `norank/nr1-order` (the gate runs before (a), exit 13) |

Private reference (deleted after the review): check, fmt, l0, l2 (186 of 186) and l3 pass. No expected file of an old case changed.

Revert check (hand mutations of the reference, `research/slice-072c-revert/mutate.py`; every one is caught):

| # | Mutation | Test that failed |
| --- | --- | --- |
| M1 | `first`: a recorded `Fail` does not skip a compiler | L0 `first`, `nr1-order` |
| M2 | `first`: `resolves` with no known hash | L0 `first` |
| M3 | `ensure!`: the gate before (a) and (b) | `nr1-order` |
| M4 | `probed!`: `>=` to `>` (the budget) | `nr1-order` |
| M5 | `Outside` runs (a) and (b) | `nr1-order` |
| M6 | `warn_changed!` prints nothing | `nr1-order` |
| M7 | (a) sets the default | `nr1-order` |
| M8 | `Ls.request_of`: `auto: Ask` | `fe-flows` |
| M9 | `PathFlow`: the scope has no hashes | `fe-flows` |
| M10 | `left` is `max` and not `max - started` | `nr1-order` |
| M11 | `Init`: `offline: Bool.True` | `it4-nocompiler` |
| M12 (review) | `first`: only `Fail` skips (the rows of Q1) | L0 `first` |

Rule coverage: `MISSING=1 scripts/rules.sh R-SO R-CV R-FE` lists only R-FE9 (P2).

## 12. Review (manager, 2026-10-26)

| Item | Decision |
| --- | --- |
| Q1 | `Hang` and `Crash` skip a compiler in (b). L0 rows added |
| Q2 | R-DL2 downloads a pin. No test in 072c |
| Q3 | Local builds are never candidates. L0 row added (a local build with a recorded pass) |
| D1 to D8 | Accepted. The gate after (a) and (b) revises D1 of 072b |
| Proposals (section 7) | Accepted |
| `it4-nocompiler` | Kept as intermediate, with the 072d note in its `rules` |
| Status | `code`. The reference and `mutate.py` are deleted. Red state: l0 `NoRankTest.roc` (`first`), l2 `norank/nr1-order`, `fetch/fe-flows`, `init/it4-nocompiler` |

## 13. Disputes and decisions (code agent, 2026-10-26)

| Id | Item | Text |
| --- | --- | --- |
| C1 | No dispute | No test of this slice was changed |
| C2 | `PathFlow.fetch!`, `Init.platform_header!` | They take `downloads : Start.Downloads` (and `hashes` for `path`) in place of `offline`. `PathFlow` has `allow: Err(NoFlag)` (`path` has no `--allow-downloads`). `Init` has `allow: Ok(Yes)` when `--allow-downloads` is in the options (`init` takes it, `Args.allows`), and its `remake!` gets `env` for it |
| C3 | R-CV6 warning in `NoRank.offer!` | A 3-line loop on `found.changed`, after `Nightlies.list!` and before the `Missing` check. `RocInstall.warn_changed!` stays private (the line is the same) |


## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Revert check | done in the test step (all caught); not run again |
| Code agent decisions | accepted: the `config.toml` read follows the accepted `calls.log` order |
