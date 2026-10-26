# 072b A command that needs a compiler downloads one when no rank selects it (fetches)

Phase: P1. Status: verify

Slice 072b is the second half of the plan row 072 of `PLAN-P1.md` (section 2c). The first half is slice 072a (`tln setup` writes the first default). The user words: "... Then the selected nightly can be downloaded when needed."

R-SO14 (rewritten by the design agent, 2026-10-25): when no rank selects a compiler, a command that fetches, probes or builds does not stop with exit code 18. It picks a compiler and downloads it under the consent rules R-DL1 to R-DL6. Then it sets the compiler as `default-roc` when none is set (R-SO15).

| Case | The compiler that Talon picks |
| --- | --- |
| In a project | For each hash of the header entries that has a fact: the newest compiler of the channel with a recorded pass (R-EF1 rank 1). If no compiler suits, the latest |
| Outside a project | The latest in the channel (R-RU1: the switch and `min-release-age` apply) |

R-FE4 and R-LF1 apply the same rule to the fetch, also for `install --frozen`. R-PX4 and R-EC18 (the proxy, exit code 18 only in P0) are in the design text but not in this slice.

## 1. Scope split (decision of the test agent, for the review)

The plan row 072 is too large for one slice: the rule is in 14 flows. Slice 072b wires one flow family. Every other flow passes `Stop`, which keeps the old exit code 18, until a proposed slice 072c.

| Part | In 072b | In the proposed 072c (the manager adds the plan row) |
| --- | --- | --- |
| Fetch (`Fetch.program_of!`, R-FE4, R-LF1) through `InstallFlow.install_with!` | `install`, `add`, `update`, `upgrade`, `install --frozen` | |
| The other fetch flows | | verify, list, why, outdated, patch, remove, `roc use`, probe, path, init, tool, x, run |
| The stops that are not a fetch | | `ResolveBase.check_pin`, the free-nightly `NoCompiler` of `InstallFlow`, `ProbeFlow`, `Proxy` step 9 (R-PX4), `ManageUse` |
| The stop of a relative selector in `roc` commands | | cases `roc/bs2-no-pin`, `bs3-range` (R-SL7) |
| Cases that show exit 18 and change in 072c | | L3 cases with exit 18, `so9-*`, `tool/dl1-sweep` run 5, `proxy/px1-flow`, `evidence/ev2` (`why` needs no compiler) |

How the split works in the code: the field `none : NoRank.Fallback` of `ResolveBase.Request` goes to `Gather.get!`, `Walk`, `PickLoop` and `Fetch.Unbundler` (`Choose`). Every `Request` constructor gives `Stop`. `ResolveBase.no_rank` gives the value for `install_with!`. Slice 072c changes the callers, not the pipe.

A `--offline` fetch downloads no package, so it never reaches the choice of a compiler. The row `--offline` of `NoRank.gate` is tested at L0 only (D7).

## 2. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-SO14 | The rule above | L0 `NoRank.pick`, `keys`, `gate`, `prompt`; L2 `fetch/fe-none`, `fetch/fe-flow` run 13, `closure/cl3-frozen-none` |
| R-FE4 | The fetch picks the unbundler compiler, and R-SO14 applies when none is installed | `fe-flow` run 13, `fe-none` runs 1 to 7 |
| R-LF1 | `install --frozen` fetches with the same rule | `cl3-frozen-none` runs 1 to 3 |
| R-SO22 (frozen part) | The frozen run does not change the lock, and it may set the default | `cl3-frozen-none` run 2 |
| R-SO15 | The download of R-SO14 sets `default-roc` when none is set. A default that is set stays | `fe-none` runs 2 and 3, `cl3-frozen-none` runs 2 and 3, `fe-flow` run 13 |
| R-DL1 to R-DL6, R-DL10 | Consent: `TALON_AUTO_INSTALL`, `--yes`, `--allow-downloads`, no person, the default answer | L0 `NoRank.gate`, `NoRank.prompt`; `fe-none` runs 3 to 6 |
| R-NI5 | The prompt names the compiler and says that it becomes the default | L0 `NoRank.prompt`, `fe-none` run 3 |
| R-EF1, R-EF3 (as used) | A recorded pass is a check row (target `any`) with the outcome `Pass`. A build row is no evidence | L0 `NoRank.pick`, `fe-none` run 2, `cl3-frozen-none` run 2 |
| R-CV1 (as used) | The other tag form of the same nightly is the same compiler | L0 `NoRank.pick` |
| R-RU1, R-NS2, R-NS3 (as used) | The switch and the age limit the channel; with the switch off and no release, exit 10 | `fe-none` run 7 |
| R-EC10, R-EC13, R-EC15 | Exit codes 10, 13 and 15 | `fe-none` runs 1, 4 to 7; `cl3-frozen-none` run 1 |
| R-CC3 point 5, R-CC4, R-CC8 | The question is asked before a lock. The download holds the item lock. One `db_query` for the pick | `fe-none` run 3, `calls.log` of `fe-none` and `cl3-frozen-none` |
| R-PX4, R-EC18 | Text only. Exit code 18 stays in the proxy and the other flows until 072c | none |

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `NoRank.pick`, `keys`, `gate`, `prompt` | The pure decisions. Stubs: `crash` |
| 2 | `NoRank.offer!` | New. Steps 2 to 6 of `RocInstall.offer!` with `NoRank.pick` in place of `Nightlies.pick`. The calls are in its doc. Stub: `crash` (L0 and L2 do not reach it through a stub, because `ensure!` is a stub) |
| 3 | `NoRank.ensure!` | The 7 steps in its doc. Stub: `Err(Compiler.failure(NoCompiler))` (the old exit 18), so the L2 cases of the old flows stay green |
| 4 | `ResolveBase.no_rank` | Body: `Download({ scope: Project(<hashes of the Release rows of loaded.members' m.locked.rows>), downloads: ResolveBase.ladder_downloads(request) })`. Stub: `Stop` |
| 5 | `RocInstall` | The helpers that `offer!` has as private functions (`toolchain_entries!`, `has_dir`, `asset_of`, `published_of`, `env_var`) become public, or move to a module that both use. `RocInstall.roc` has 421 lines: each module is at most 490 lines |
| 6 | `Fetch.program_of!` | Done in the stubs: the arms `Stop` and `Download` (`Download` calls `NoRank.ensure!`, then `Launch.program!`) |
| 7 | The pipe `none` | Done in the stubs: `Gather.get!`, `Walk`, `PickLoop`, `ResolveBase.Request` and its constructors (`Install`, `Remove`, `RocUse`, `Update`, `Ls`, `ProbeFlow`, `Verify`, `L2Resolve`, `Init`, `PathFlow`, `ToolFlow`, `flowprobe.roc`; `PatchFlow` passes `request.none`) |

Note for the code agent: the private reference calls `list_dirs` of `<cache>/toolchains` twice (the caller reads the list, `offer!` reads it again). The `calls.log` files of `fe-flow`, `fe-none` and `cl3-frozen-none` fix the calls. Follow the files, not the reference.

The calls of `NoRank.ensure!` (the L2 cases fix them):

| Step | Does | Rule |
| --- | --- | --- |
| 1 | `gate`: a `Stop` is returned, no call | R-DL5, R-DL10 |
| 2 | `offer!`: `clock`, `platform`, `read_files config.toml`, `list_dirs toolchains`, the list calls of `Nightlies.list!`, then for `Project` with a key `db_query facts=<n>` | R-SO14 |
| 3 | `Present`: `RocInstall.first_default!`, then the result. No download | R-SO15 |
| 4 | `Download`: `Consent.required_want`; `NeedTty`: one `tty`; `NeedsConsent`: `Consent.download_stop` (exit 13) | R-DL4, R-DL5 |
| 5 | `Prompt.ask!` with `NoRank.prompt`; `No`: `Consent.command_declined` (exit 13) | R-DL1, R-NI5 |
| 6 | `RocInstall.install_offer!` (the item lock, download, extract, no default) | R-CC4 |
| 7 | `RocInstall.first_default!` | R-SO15 |

## 4. Public signatures

| Name | Signature | State |
| --- | --- | --- |
| `NoRank.Scope` | `[Outside, Project(List(Str))]` | done |
| `NoRank.Run` | `{ scope : NoRank.Scope, downloads : Start.Downloads }` | done |
| `NoRank.Fallback` | `[Stop, Download(NoRank.Run)]` | done |
| `NoRank.Got` | `{ id : Str, installed : List(Str) }` | done |
| `NoRank.pick` | `{ auto : List(Str), scope : NoRank.Scope, facts : List(Db.Fact) } -> Try(Str, [Empty])` | stub |
| `NoRank.keys` | `{ hashes : List(Str), auto : List(Str) } -> List(Db.Key)` | stub |
| `NoRank.gate` | `{ auto : [Ask, Yes, No], yes : Bool, flag : Try(Answer, [NoFlag]), offline : Bool } -> [Go, Stop(Fail)]` | stub |
| `NoRank.prompt` | `{ id : Str, size : U64 } -> Prompt` | stub |
| `NoRank.offer!` | `Fx, { env, offline, scope } => Try(RocInstall.Offer, Fail)` | stub (`crash`) |
| `NoRank.ensure!` | `Fx, { roots : Roots, run : NoRank.Run, listed : List(Str) } => Try(NoRank.Got, Fail)` | stub: exit 18 |
| `ResolveBase.no_rank` | `Request, Loaded -> NoRank.Fallback` | stub: `Stop` |
| `Fetch.Unbundler` | `[Program(Str), Choose({ selected : Str, none : NoRank.Fallback })]` | done |

`NoRank` is in the exposes list of `cli/lib/main.roc`.

## 5. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/NoRankTest.roc` (driver `l0-5.roc`), `pick` | 16 rows: outside a project; an empty channel; the newest that passes for each known hash; the order of the hashes; no hash; a hash with no fact is ignored; each hash and not some; no compiler suits; a hash that fails everywhere; a hang is no pass; a build row is no evidence; the other tag form; a repeated hash | R-SO14, R-EF1, R-CV1 |
| L0 | same file, `keys` | sorted, no repeat, order of `auto`; no hash or no id gives no key | R-EF1, R-CC8 |
| L0 | same file, `gate` | 8 rows with the proposed texts: ask, auto yes, auto no, `--yes` and `--allow-downloads` win, `--offline` (also with an answer, and with auto no) | R-SO14, R-DL5, R-DL10, R-EC13 |
| L0 | same file, `prompt` | `Prompt.decide` rows (no person, `--yes`, `--allow-downloads`, ask, `NeedsTty`), and the texts of the question, the answer lines, the subject | R-NI5, R-DL1, R-DL3 |
| L2 | `fetch/fe-none` (new, 7 runs) | 1: a transport error from the list, exit 15. 2: `none:project:HA,HB` with `TALON_AUTO_INSTALL=yes` picks the 16th (not the latest, the 18th) from the facts of `compat.tsv`, installs it, writes `default-roc`. 3: `none:project:HC` (no fact), answer `y`: the latest; the prompt text is in `calls.log`; a default that is set stays. 4: `TALON_AUTO_INSTALL=no`: exit 13 before the list. 5: outside a project, answer `n`: exit 13. 6: `CI=true`: exit 13 `download_stop`. 7: `TALON_NIGHTLY=false`: exit 10 | R-SO14, R-FE4, R-SO15, R-DL1 to R-DL5, R-NI5, R-EC10, R-EC13, R-EC15, R-CC3, R-CC8 |
| L2 | `fetch/fe-flow` run 13 (changed) | was exit 18. Now `TALON_AUTO_INSTALL=yes`: the 18th is downloaded outside a project and set as default. New files `fx/env` and a list route in `fx/http`, 3 job rules. Runs 1 to 12 and 14 to 16 do not change | R-SO14 (2), R-FE4, R-SO15 |
| L2 | `closure/cl3-frozen-none` (new, 3 runs) | 1: `install --frozen` with `TALON_AUTO_INSTALL=no`: exit 13. 2: with `--allow-downloads`: the platform passes on all three compilers and `core` fails on the 18th, so the 16th is picked, downloaded and set as default. 3: the compiler is installed: no list, no prompt, unbundle runs with the 16th | R-LF1, R-SO14 (1), R-SO22, R-SO15, R-EF1 |
| L2 | `tests/commands/main.roc`, entry `fetch` | new words `none:stop`, `none:outside` (default), `none:project:<hash>,<hash>`, `yes`, `allow-downloads`. The consent facts come from the env and the words | |

Counts: 1 new L0 file (4 expects, 28 rows), 2 new L2 cases (10 runs), 1 changed L2 case (run 13), 1 changed test entry. The old copies are in `research/slice-072-revert/before/` (`NEW.txt` lists the new files).

## 6. Output (proposed, R-OUT2, TW24)

| Item | Text |
| --- | --- |
| Prompt question | `No compiler is selected. Download <id>, <size>? It becomes the default compiler. [y/N] ` (default No) |
| Prompt answer line, yes | `downloading <id> (<size>), the default compiler` |
| Prompt answer line, no | `no download of <id>` |
| Refusal, `--offline` (exit 13, no request) | `no compiler is selected, and --offline stops the download. Run: tln roc install @latest when you are online, then tln roc default <id>.` |
| Refusal, `TALON_AUTO_INSTALL=no` (exit 13, no request) | `no compiler is selected. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install @latest, then tln roc default <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` |
| No person, no flag | the text of `Prompt.decide`: `the download of <id> needs consent. Pass --allow-downloads or TALON_AUTO_INSTALL=yes or --yes.` |
| CI, the list is read | `Consent.download_stop` (existing text, with the size) |
| Answer no | `Consent.command_declined` (existing text) |

## 7. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `gate` runs before the list. `--offline` and `TALON_AUTO_INSTALL=no` give exit 13 with no request | The list first: a refusal that costs a request, and a different exit code for a run with no network |
| D2 | `Stop` is a transitional fallback (exit 18) for the flows that 072b does not wire | One slice for all 14 flows: about 40 old cases change, too large to review |
| D3 | The pick uses the order of `Toolchain.domain(...).auto`. The facts come from one `Facts.load!` with the keys of hashes times `auto` | One query for each hash: R-CC8 asks for one |
| D4 | The prompt default is No. It follows R-NI5 (table: default No, yes for the proxy) and R-DL3 ("No for all other commands"), and the existing prompt `Consent.command_download` of slices 025 and 036 (`default: No`) for `install`, `add`, `update`, `remove` and `verify`. The manager asked to use that default: it is No, so nothing changed | Yes: only the proxy (`proxy-download`) and the commands that name the download have Yes |
| D5 | The `Present` branch (the pick is installed already) only sets the default and downloads nothing. This is a race with another process, and no test reaches it | A second download |
| D6 | `fe-flow` run 13 changes: it was the exit 18 case, and now it shows R-SO14 (2). It gets `fx/env` (a fixed `HOME` and `TALON_NOW`) | A new case: the old run would then show a rule that is not true any more |
| D7 | The row `--offline` of `gate` has an L0 row only. A fetch with `--offline` does not reach the choice | An L2 case that cannot reach the code |
| D8 | The compiler is never a `git-`, `link-` or `copy-` build (the channel is nightlies, R-NS6) | |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| The flows of the table in section 1, column 072c | A proposed slice 072c. The tests of those flows keep the exit 18 in their expected files |
| R-PX4, R-EC18 (proxy step 9) | The proxy passes `Stop` until 072c |
| A second compiler download for a pin | R-SO14 is for the case with no rank. A pin has its own rule (R-DL2) |
| R-FE9 | A P2 rule (it is the only rule that `MISSING=1 scripts/rules.sh R-SO R-FE R-LF R-PX R-EC R-IS R-ST` lists) |

## 9. Questions (TW17) and manager answers (2026-10-25)

| Id | Manager answer |
| --- | --- |
| Prompt default | The same as the existing required-download prompt. That default is No (`command_download`), so D4 is unchanged |
| Q1 | Reading A accepted |
| Q2 | Accepted: `--offline` gives exit 13 even with a cached list, because no download can happen |
| Q3 | Stays open for 072c (the manager adds the 072c plan row) |
| Q4 | Accepted: the `Nightlies.failure` text and exit 10 |

| Id | Question | Options | Default in the tests |
| --- | --- | --- | --- |
| Q1 | ANSWERED (A). R-SO14 says "a recorded pass for each hash that has a fact". Which reading? | (A) A compiler suits when it has a pass for each hash that has any check row. A hash with a fail row on every compiler is "known", so no compiler suits and the latest is used. (B) Avoid recorded failures: a compiler suits when no known hash has a fail on it | (A). L0 `pick` rows fix it |
| Q2 | ANSWERED (a). `--offline` with a cached list: the gate gives exit 13 even then | (a) Exit 13 before the list (D1). (b) Use the cached list and download nothing: the pick is `Present` only | (a), L0 only |
| Q3 | Which "project" applies to the fetch of `tool`, `x`, `init` and `run`? They have no header of a project in the same sense | (a) The hashes of the entries that the command fetches. (b) `Outside` | not in 072b; for 072c |
| Q4 | ANSWERED (a). An empty channel with the switch on (no release in the list for this host, or all too young): which text? | (a) `Nightlies.failure` text and exit 10 (the reference). (b) A text of this rule | the reference. `fe-none` run 7 has the switch off, which fixes the exit code only |
| Q5 | Known open (user questions of 2026-10-25, not decided here): the "project with no pin" choice, and `min-release-age` for "latest". The text as written is used | | |

## 10. Gaps

| Gap | Effect |
| --- | --- |
| The `Present` branch of `ensure!` (a race) | no test; the reference has it |
| The offline row of `gate` at L2 | unreachable (D7) |
| The other flows, the proxy | slice 072c |
| `NoRank.offer!` reads `toolchains/` a second time in the reference | the code agent follows `calls.log` |

## 11. Compiler and tool limits met

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | A warning fails a build (an unused parameter) | the stubs name their parameters `_x` | none needed |
| C2 | A stub that crashes stops the whole L2 test app | `NoRank.ensure!` and `ResolveBase.no_rank` give the old behavior | `pick`, `keys`, `gate`, `prompt` and `offer!` crash (not L2-reachable until `ensure!` is a body) |
| C3 | `{ x }` is a block in Roc | a record with one field is `{ id: id }` | |

## 12. Verify results (test agent, 2026-10-25)

Red state (stubs, new tests, with the 072a stubs):

| Step | Result |
| --- | --- |
| check, fmt, selftest, l3 | pass |
| l0 | FAIL: `NoRankTest.roc` lines 28, 58, 70 and 95 crash with `todo: slice 072b`; `ToolchainTest.roc:102` crashes with `todo: slice 072a` |
| l2 | FAIL, 9 cases of 174: from 072b `closure/cl3-frozen-none`, `fetch/fe-flow` (run 13), `fetch/fe-none`; from 072a `setup/st1-flow`, `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry`, `st6-talon-in-file`, `st8-first-default` |

Private reference (a copy of the tree with 072a and 072b, `research/slice-072-revert/reference/sandbox`): check, fmt, l0, l2 (174 of 174) and l3 pass.

Revert check (hand mutations of the reference, 10 for 072b; every one is caught):

| # | Mutation | Test that failed |
| --- | --- | --- |
| M1 | `all` to `any` in `pick` | L0 `pick`, `fe-none`, `cl3-frozen-none` |
| M2 | build rows count as evidence | L0 `pick` |
| M3 | the scope is ignored in `ensure!` | `cl3-frozen-none`, `fe-none` |
| M4 | the offline row of `gate` removed | L0 `gate` |
| M5 | no `first_default!` after the download | `cl3-frozen-none`, `fe-flow`, `fe-none` |
| M6 | `gate` after the list | `cl3-frozen-none`, `fe-none` |
| M8 | no `NeedsConsent` stop | `fe-none` |
| M10 | `no_rank` drops the hashes | `cl3-frozen-none` |
| M12 | `keys` has repeats | L0 `keys` |
| M13 | the switch is ignored in `offer!` | `fe-none` |

Rule coverage: `MISSING=1 scripts/rules.sh R-SO R-FE R-LF R-PX R-EC R-IS R-ST` lists only R-FE9 (P2).

## 13. Verify results (code agent, 2026-10-25)

`scripts/test.sh`: check, fmt, l0, l2 (174 of 174), l3, selftest and l1 pass. The L2 calls of `NoRank.offer!` follow the `calls.log` files: `list_dirs toolchains` is read twice (the caller, then `offer!`), as the doc of `NoRank.offer!` says.

| # | Mutation | Test that failed |
| --- | --- | --- |
| M4 | `pick`: `all` to `any` | L0 `NoRankTest`, L2 |
| M5 | no `first_default!` after the download | L2 `fetch/fe-none` |
| M6 | `gate`: the offline row needs no `--yes` | L0 `NoRankTest` (`gate`) |
| M7 | `no_rank` drops the hashes (`drop_first(5)`) | L2 `closure/cl3-frozen-none` |
| M8 | `keys` with no `sorted_unique` | L0 `NoRankTest` (`keys`) |
| M9 | `NeedsConsent` is no stop | L2 `fetch/fe-none` |

All 9 mutations of both parts are caught. The code is the same as before the mutations (`cmp` with `research/slice-072-revert/code-final/`).

Decisions of the code agent (not fixed by the slice):

| Decision | Rejected |
| --- | --- |
| The helpers `env_var`, `toolchain_entries!`, `has_dir`, `asset_of`, `published_of` moved into the `RocInstall` block (public); `RocInstall.roc` has 446 lines | A new module (more files); a copy in `NoRank` (as `GitInstall` does) |
| `NoRank.offer!` gives no `warning:` line for a changed tag (R-CV6): the slice says nothing, no test reads it | The same warning as `RocInstall.offer!` |
| `NoRank.offer!` uses `Toolchain.domain(...).auto` as it is (no `Nightlies.auto_with_base`: there is no base) | |
