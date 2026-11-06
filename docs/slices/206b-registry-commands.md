# 206b Registry in the commands

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 206b of `PLAN-P2-CLI.md`. The row holds every part that slices 206, 207, 208, 209, 210 and 212 moved out: the query step of R-AL2 step 2 inside the commands, and the lift of the P0 refusal of a registry URL (`Opts.check_registry`). The row is too large for one review (TW19), so the test agent proposes 4 sub-slices. Each one is testable alone and builds on the one before it.

## Split (proposal for the manager)

| # | Sub-slice | Content | Rules | Tests | Depends on |
| --- | --- | --- | --- | --- | --- |
| 1 | 206b: setting and first query in `update` | The registry setting (R-RG1, R-RG7) for `tln update` only: the refusal is lifted for `update` and `up`, the other commands keep it. After the load, `update` reads the setting (`--registry`, `TALON_REGISTRY`, `registry` of `config.toml`), runs the privacy guard on what the query carries, sends ONE closure query (the groups of the free variables, the hashes of the header, the window of the held pin), applies `--snapshot log:N` (`LogSnapshot.hide_above`), sets `Request.index` to `Answer`. The R-DT5 line and JSON `snapshot` of a whole command. A run with no registry makes the same calls as before. | R-RG1, R-RG2, R-RG7, R-FL5, R-RG4, R-AL2, R-DI1, R-AP16, R-AP74, R-DI14, R-AL8, R-DT3, R-DT5, R-AP19, R-J3 | L0 `IndexqueryTest`, `UpdateTest`; L2 `registry/al2-update-query` | 206, 207 |
| 2 | 206d: more queries, offline | `UnknownValues.settle!` after the first query of `update` (its `urls`), the `Label` and `Archive` ends in `Gather` and the solver (R-DI7, R-C9), the `fixed: not in the registry index` line (R-DI11). The second query of a held move (R-SP16, R-SP23, R-SP24, `LogSnapshot.second!`) and its notes. `--offline` with a registry: index `Offline(origin)`, no guard, no request, the R-IX6 note `fixed: offline, no cached index`. | R-AP28, R-AP65, R-DI7, R-DI11, R-SP16, R-SP23, R-SP24, R-AP16 (second), R-IX6 | L2 `update` cases | 206b, 208 |
| 3 | 206e: other resolve commands, evidence, notes | `install` with no names, `verify`, `upgrade` (a `Free` window from the registry compiler list, slice 204), `outdated` (the `Report` window, its rows as groups). Probe runs at L2: `PickLoop.read_all!` and `hinted!` with an answer, `Matrix.rows`, `real`, `found`, `unknown_sets` in `PickLoop` and `ProbeRange`, `PairOrder.order_shared`, the R-EF3 note. `EvidenceFlow.blocks!` in `why` (where `why` gets an answer is open, slice 209). The index notes of slice 210 in `update`, `outdated`, `add` (stderr, `--quiet`, exit code, `data.index_notes`, both answers of a held move). May split again (commands, then evidence and notes). | R-AL2, R-DI1, R-AP16, R-AP74 row 4, R-EF1, R-EF3, R-EP15, R-AP29, R-AP30, R-FL4 | L2 per command | 206d, 209, 210 |
| 4 | 206f: names, the last lift | `add` and `install <names>`, `tool install`, `x`: `FullName.read!` and the short names of slice 211 in the commands, the use of the answer, the `NoMatch` texts (Q430), the source build after `SourceBuild`, R-AD36 of a whole command, a first R-AP1 read with 5xx, 429 or 3xx. The refusal is removed for every command; R-RG7 row 6 for the commands with no index call (`list`, `remove`, `install --frozen`: no stop for `--registry`), the check of `registry` in `ConfigToml.read` (R-TF4: every command that reads `config.toml`). An L3 case with the real `curl` children. | R-AD35 to R-AD37, R-AP1, R-SC3, R-SC4, R-RG7 row 6, R-TF4, R-DI1 | L2, L3 | 206e, 211, 212 |

Reason for the order: sub-slice 1 is the smallest path that a user can run (one command, one query, no probe). Sub-slice 2 adds the other requests of the same flow. Sub-slice 3 adds commands and the evidence that changes the probe calls. Sub-slice 4 adds the name reads before the flow. Until sub-slice 4, a command that is not wired keeps the P0 refusal of `--registry` and ignores `TALON_REGISTRY` and `config.toml` (as today), so it never uses a registry by half.

The rest of this file is sub-slice 1.

## Scope (sub-slice 1)

| In | Out (where) |
| --- | --- |
| New module `cli/lib/IndexQuery.roc` (in `main.roc`): `setting`, `groups`, `sources`, `snapshot` (pure) | Unknown header values, the second query, `--offline` with a registry: 206d |
| `Opts.check_registry`: no refusal for `update` (and `up`) | The other commands: 206e, 206f |
| `ResolveBase.Request.registry : [Off, Setting(Try(Str, [Unset]))]` (test step: the type and every constructor; `Update.request_of` gives `Setting(args.registry)` for `update`, `Off` for `upgrade` and `init`; all others `Off`) | Probes with an answer (`read_all!`, `hinted!`, evidence): 206e. The L2 case uses `--no-check` |
| The flow of `update` with `Setting`: the setting after the load, the guard, one query, `hide_above`, `index` = `Answer`, the line and `snapshot` of R-DT5 | The check of `registry` in `ConfigToml.read` for every command (R-TF4): 206f |

## Rules

R-RG1, R-RG2, R-RG7 (rows 1 to 3, 6), R-FL5, R-RG4, R-AL2 (step 2, first query), R-DI1, R-AP16, R-AP74 (rows 3, 5), R-DT3, R-DT5, R-AP19 (Q403), R-J3 (CLI 1, 7.3; Resolution 5, 11; Registry 4.1). As used: R-RG5, R-DI14, R-AL8 (source 2), R-ID2, R-SP5, R-SP23, R-UP3, R-EC2, R-TF4, R-IX3, R-EV1, R-FL9.

## Decisions (pure, L0) and flow (L2)

| Name | Signature | Rule |
| --- | --- | --- |
| `IndexQuery.setting` | `{ flag : Try(Str, [Unset]), env : Try(Str, [Unset]), config : Try({ text : Str, at : Str }, [Unset]) } -> Try([Direct, Registry(Str)], Fail)` | R-RG1, R-RG2, R-RG7 |
| `IndexQuery.groups` | `List(Vars.Scoped) -> List(ClosureRequest.Group)` | R-AP16, R-DI1, R-AP74 row 3 |
| `IndexQuery.sources` | `{ groups : List(ClosureRequest.Group), entries : List(Str) } -> List(PrivacyGuard.Source)` | R-RG4 |
| `IndexQuery.snapshot` | `{ registry : Bool, flag : Try(Str, [Unset]), config : Try([Log(U64), Time(U64)], [Unset]) } -> Try([None, Time(U64), Log(U64)], Fail)` | R-DT3, R-DT4, R-FL9, R-EV1 |
| `ResolveBase.Request.registry` | `[Off, Setting(Try(Str, [Unset]))]`. The code agent can add a tag (for example the read origin) without a change of the tests: the tests construct only `Off` | R-RG1 |

The reading that the tests fix:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Precedence | The first set value of flag, `TALON_REGISTRY`, `config.toml` wins; none: `direct` (R-RG1, R-RG2). `direct` at any level is `Direct` |
| 2 | Bad text | Only the winner of flag and variable is read (exit 2, the source named): a valid flag means the variable is not read (Q439). A bad `config.toml` value stops also when the flag or the variable wins: "stops for `config.toml` as for each other key of R-TF4" (R-RG7 row 6), exit 19 in the R-TF4 form |
| 3 | When the setting is read | After the load of the project files (the text of `config.toml` is in that one read), before the guard. So a bad flag of `update` is not an `Opts` failure: `Update.read` passes it |
| 4 | Groups | The free variables that have a name: the groups whose releases `direct` lists in the first search (`PickFlow.prepare!`). A held and a movable variable give none (R-AP16: the first query does not hold the movable groups). Series: a group is the URL form and the series (Design R-ID2), so the series of the variable is sent; `any_series` (R-SP5, R-UP3) sends none. Range: `join_ranges` of the ranges of the variable (R-AP74 row 3) |
| 5 | Hashes | Each header entry with a hash, in header order (`ClosureRequest.request`, R-AP74 row 5) |
| 6 | Window | The held `roc:` pin: `from` = `to` = the pin (R-AP16). `update` holds the nightly. No compiler id (no pin, no compiler on `PATH`, `--no-check`): no `compilers` member (Q437, R-AP74 row 4) |
| 7 | Guard sources | The groups in order, then the URL of each entry that gives a hash, in entry order (R-RG4). Kept public answers need no request (R-RG5). The guard runs before the query |
| 8 | Snapshot | With a registry, `log:N` is valid (flag over `[resolution] snapshot`); the answer is hidden above N with the hashes of the request as the keep list (R-AP19, Q403). The time form works in both modes. `log:N` with `direct` keeps the failure of `Intent.direct_snapshot` |
| 9 | R-DT5 | With a time snapshot and a registry: `resolved at <time> (log:<n>), <probes> probes` (Q438). With the answer index and no time: `resolved at log:<n>, <probes> probes` and `"snapshot":"log:<n>"`, `n` = `LogSnapshot.printed` (N of `--snapshot log:N`, else `log_size`). Direct: the time, as before |
| 10 | No registry | `Setting` that reads `direct`, and `Off`: the same calls and output as before the slice |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/IndexqueryTest.roc` (driver `l0-6.roc`): precedence (7 rows) | R-RG1, R-RG2 |
| L0 | base URL form of the winner (4 rows) | R-RG7 rows 1 to 3 |
| L0 | bad flag and bad `TALON_REGISTRY`: exit 2, the source and the text | R-RG7 row 6, R-EC2 |
| L0 | bad `config.toml` value: exit 19, `<path>:<line>: registry: ...`, also when the flag or the variable wins | R-RG7 row 6, R-TF4 |
| L0 | `groups`: free only, order, series, 2 ranges joined, `*` dropped, no range, `any_series`, no free variable | R-AP16, R-DI1, R-SP23, R-ID2, R-AP74 row 3, R-SP5, R-UP3 |
| L0 | `sources`: groups then URLs with a hash; path and foreign text left out; no group | R-RG4 |
| L0 | `snapshot`: log with a registry (flag, key, flag over key), none; time in both modes; log with `direct`; bad text | R-DT3, R-DT4, R-FL9, R-EV1, R-AP19, R-EC2 |
| L0 | a valid flag wins over a bad `TALON_REGISTRY`: not read (Q439) | R-RG1, R-RG7 row 6 |
| L0 | `tests/unit/UpdateTest.roc` (driver `l0-7.roc`): `update` and `up` take a registry URL (also a bad text: the flow reads it); the order row now ends at `--strategy` | R-FL5, R-RG1, R-RG7 |
| L2 | `registry/al2-update-query` (entry `commands`, 5 runs, the case file `rules` has the detail): `--registry direct` wins (direct calls); config registry with `--snapshot log:30 --json --dry-run` (guard, then one POST with the body, hide above 30 with keep, `"snapshot":"log:30"`); bad `TALON_REGISTRY` exit 2; bad `--registry` exit 2; `TALON_REGISTRY` in another case with a `/` (base URL form) wins over the config and writes the header with `resolved at log:50, 0 probes` | R-AL2, R-RG1, R-RG2, R-RG7, R-FL5, R-RG4, R-DI1, R-AP16, R-AP74, R-DI14, R-AL8, R-DT3, R-DT5, R-AP19, R-J3, R-EC2, R-IX3 |
| L2 | `registry/al2-update-window` (entry `commands`, 2 runs): no pin and no compiler on `PATH`, `--no-check --dry-run`: the body has no `compilers` (Q437); `--snapshot 2026-10-01T00:00:00Z` hides parser 1.2.0 and prints `resolved at 2026-10-01T00:00:00Z (log:50), 0 probes` (Q438) | R-AP16, R-AP74 row 4, R-DT5, R-DT4, R-AL2, R-RG1, R-RG4 |
| L3 | `update/rg7-flag-wins-env` (real binary, project of `update/up1-update-entries`): `--registry direct` with `TALON_REGISTRY=ftp://127.0.0.1:1`: the direct run, exit 0; the same variable with no flag: exit 2 with the message, no index request | R-RG1, R-RG7 row 6, R-FL5, R-EC2 |

The fixtures are made by `research/slice-206b-revert/mkcases.py` (given and fx), the expect files by `research/slice-206b-revert/mkexpect.py`, by hand from the rules (TW21), not from a run. Run 1 (the direct path) uses the calls and tree of the direct code, which the slice does not change (`base-run1-calls.log`, `base-run1-tree.diff`: a run of the same case before the slice).

The old direct cases do not change: every constructor except `update` gives `Off`, and the L2 cases set no `TALON_REGISTRY`.

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-6.roc` | 75 pass, 12 fail: each `IndexqueryTest` expect, `todo: slice 206b` |
| `roc test tests/unit/l0-7.roc` | 72 pass, 2 fail: the 2 `UpdateTest` expects with a registry URL (the old `Opts` refusal) |
| `tests/commands/run.sh` | 4 fail (after the answers, `registry/` and `update/`: 33 pass, 2 fail): `registry/al2-update-query` (run 2 stops on `log:30 needs a registry`, run 5 goes direct), `registry/al2-update-window` (runs go direct) and 3 `share/sh*-queue-*` cases of slice 215, which another session has in progress (`todo: slice 215`) |
| `tests/run.sh update/` | 6 pass, 1 fail: `update/rg7-flag-wins-env` (run 2 gives exit 0: the variable is not read today) |
| `roc check cli/main.roc`, `cli/flowprobe.roc`, `tests/commands/main.roc` | no errors (a warning in `cli/lib/ShareQueue.roc` of slice 215, not of this slice) |
| `roc fmt --check` of each changed file | pass |
| `MISSING=1 scripts/rules.sh R-RG1 R-RG2 R-RG7 R-AL2 R-DI1 R-AP16 R-DT5 R-DT3 R-FL5` | none missing |

## Expected exits (read, TW21)

`al2-update-window`: `expect/exit` 0, both runs exit 0, no stderr. L3 `rg7-flag-wins-env`: exit 0, then exit 2 (bad `TALON_REGISTRY` with no flag, R-RG7 row 6); its run 1 output, `http.log`, `roc.log` and `tree.diff` are those of the direct code, which the slice does not change. `al2-update-query`: `expect/exit` 0. The `exit` lines: run 1 0, run 2 0, run 3 2 (bad `TALON_REGISTRY`, R-RG7 row 6), run 4 2 (`http` to a host that is not loopback, R-RG7 row 1), run 5 0. Stderr has the human lines of the `--json` run 2 (`Common.shown_fx`) and the 2 failure lines.

## Revert check

`research/slice-206b-revert/`: `before/` (the stub `IndexQuery.roc` and `ResolveBase.roc` with the new field), `mkcases.py`, `mkexpect.py`, `results.txt`. A private green reference (all L0 drivers, all 292 L2 cases) was mutated 9 times, then deleted with its script (TW18).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `TALON_REGISTRY` wins over `--registry` | L0 |
| M2 | a bad `config.toml` value stops only when it wins | L0 |
| M3 | movable variables in the first query | L0 |
| M4 | series also with `any_series` | L0 |
| M5 | no privacy guard before the query | L2 |
| M6 | `hide_above` with no keep list | Not caught: equivalent in a command. The pick keeps the header value (R-C9), so no output changes (tried 3 more runs). `LogsnapshotTest` (slice 207) fixes it at L0 |
| M7 | the line prints `log_size`, not the N of `--snapshot` | L2 |
| M8 | the refusal lifted for every command | L0 (`OptsTest`) |
| M9 | no `compilers` window | L2 (request body) |
| N1 | (after Q438) a time snapshot prints the log only | L2 `al2-update-window` |
| N2 | (after Q439) the variable is read also when a valid flag wins | L0, L3 `rg7-flag-wins-env` |

## Output (proposed, R-OUT2)

| Case | Kind | Text |
| --- | --- | --- |
| Bad `--registry` | usage (2) | `--registry '<text>' is not a registry URL. Use direct, an https:// URL, or an http:// URL of 127.0.0.1, [::1] or localhost, with no path.` |
| Bad `TALON_REGISTRY` | usage (2) | `TALON_REGISTRY '<text>' is not a registry URL. <the same second sentence>` |
| Bad `registry` in `config.toml` | input (19) | `<path>:<line>: registry: '<text>' is not a registry URL. <the same second sentence>` |
| R-DT5 with a registry | line | `resolved at log:<n>, <probes> probes`; `--json`: `"snapshot":"log:<n>"` (slice 207) |
| Call order (not text, for the review) | | The setting is read after the load read; the guard reads the kept answers in one call (groups first, then URLs), then asks GitHub, then the one POST |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | The `compilers` window of `update` when the run has no compiler id: no `roc:` pin, no compiler on `PATH`, `--no-check` (`decision.held` is `Err(NoCompiler)`). R-AP16 gives `Held` for a held pin and `Free` for a free nightly. Is it no `compilers` member (as a command that only reports, R-AP74 row 4), or a `Free` window of the domain, or a stop? | Answered (Q437): no `compilers` member. L2 `registry/al2-update-window` run 1 |
| Q2 | R-DT5 with a registry and a time snapshot (`--snapshot 2026-10-12T00:00:00Z`): the text says the log size is the `log_size` of the answer "or N of `--snapshot log:N`", so `log:<log_size>`; but `--snapshot log:<log_size>` then shows releases that the time hid, so a person cannot repeat the resolve with it. Print `log:<log_size>`, the time, or both? | Answered (Q438): both. L2 `registry/al2-update-window` run 2 (human line only: the `--json` form is a proposal of slice 207, not tested here) |
| Q3 | R-RG7 row 6: "The check runs when Talon reads the setting". With `--registry <good URL>` and a bad `TALON_REGISTRY`, is the variable read (exit 2) or not (the flag wins)? The tests fix only the winner of flag and variable, and the `config.toml` value always (row 6 last sentence) | Answered (Q439): not read. L0 `IndexqueryTest` (new expect), L3 `update/rg7-flag-wins-env` |

Answers (design agent, 2026-11-03):

| Slice Q | Design Q | Answer | Test change |
| --- | --- | --- | --- |
| Q1 (G-C84) | Q437 | No `compilers` member, as a command that only reports (Registry R-AP74 row 4) | New L2 case: no pin, `--no-check`, the body has no `compilers` |
| Q2 (G-C85) | Q438 | Both: `resolved at <time> (log:<n>), <probes> probes` (Resolution R-DT5) | New L2 case with a time snapshot and a registry |
| Q3 (G-C86) | Q439 | The variable is not read when a valid flag wins. A bad `config.toml` value is exit 19 always. | New L3 case: valid `--registry`, bad `TALON_REGISTRY`, exit 0 |
| Output | Q439 | The 3 texts and the call order agree with the design | None |

Plan notes for the manager (not design questions): the split above; until 206f a command that is not wired keeps the P0 text `no registry exists in this version of tln` for `--registry`, which is no longer true for `update`.

## Code (test step)

| File | Change |
| --- | --- |
| `cli/lib/IndexQuery.roc` | New: the 4 stubs (`crash "todo: slice 206b"`) with their rule tables |
| `cli/lib/main.roc` | `IndexQuery` in the package list |
| `cli/lib/ResolveBase.roc` | `Request.registry` and its doc |
| `cli/lib/Update.roc` | `request_of`: `Setting(args.registry)` for `update`, `Off` for `upgrade` |
| `cli/lib/Install.roc`, `Ls.roc`, `RocUse.roc`, `ProbeFlow.roc`, `Remove.roc`, `Verify.roc`, `cli/flowprobe.roc` | `registry: Off` |
| `tests/unit/ResolvebaseTest.roc`, `tests/commands/L2Resolve.roc`, `tests/commands/L2Registry.roc` | `registry: Off` |
| `tests/unit/IndexqueryTest.roc`, `tests/unit/l0-6.roc` | L0 tests and the driver import |
| `tests/unit/UpdateTest.roc` | 1 row changed, 1 new expect |
| `tests/commands/cases/registry/al2-update-query/` | The L2 case |

For the code agent: `Opts.check_registry` (lift for `update`), `ConfigToml.Config` may get the `registry` text and line (no test builds a `Config`), the snapshot of a registry run (`ResolveSelect.snapshot_of` refuses `log:N` today), the query in `PickFlow.prepare!` (the groups need the scope) with the new index for the rest of the run, and `InstallPlan`'s `at` as text.

## Code

| File | Change |
| --- | --- |
| `cli/lib/IndexQuery.roc` | The 4 pure functions: `setting` (R-RG1, R-RG7: only the winner of flag and variable is read, Q439; a bad `config.toml` value is exit 19 always), `groups`, `sources`, `snapshot` |
| `cli/lib/Opts.roc` | `check_registry`: no refusal for the command `update` (`up` is parsed as `update`). The other commands keep it |
| `cli/lib/ConfigToml.roc`, `ResolveLoad.roc`, `Base.roc` | `Config.registry`: the text of the key `registry` and `<path>:<line>` (a value that is not a string is `Unset`: the R-TF4 check is 206f) |
| `cli/lib/ResolveBase.roc` | `Request.registry` gets the tag `Read(Query)`: `{ origin, snapshot, pin }` |
| `cli/lib/InstallFlow.roc` | `with_setting` after `ResolveLoad.prepared!`: `Setting` becomes `Off` (`direct`, and `--offline`) or `Read` (with `IndexQuery.snapshot`). `resolve!`: the time snapshot of a `Read`, the held compiler as `pin`, the rest of the run uses `ready.request`. `finish!`: `at` is `log:<n>` or `<time> (log:<n>)` (`at_text`) |
| `cli/lib/PickFlow.roc` | `Ready.request`. `query!` after the scope, before the index: `PrivacyGuard.check!`, `ClosureIndex.query!` (window `Held(pin)` or `None`, Q437), `LogSnapshot.hide_above` with the request hashes as the keep list, `index` = `Answer` |

Notes for the review:

| # | Point |
| --- | --- |
| 1 | `--offline` with a registry: the setting is read (a bad text stops), then the run is direct as before (index `Offline` is 206d) |
| 2 | `--json` with a time snapshot and a registry: `snapshot` is the same text as the line (`<time> (log:<n>)`). Q438 proposes the time alone and a log member of its own: slice 207 (not tested here) |
| 3 | `ResolveSelect.snapshot_of` in the compiler range step (`ranged!`, in the load) still refuses `log:N`: a run with a registry, `log:N` and no installed compiler in the `[toolchain] roc` range stops there (not in a case of this slice) |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206b-revert/code-final.sha256` | 8 of 8 OK |
| `todo: slice 206b` in `cli/` | None |
| L0 | `l0-6` 87 of 87 (`IndexqueryTest`), `l0-7` 74 of 74 (`UpdateTest`). `l0-8` and `fmt` failed in the code agent's run only on the slice 216 test step in progress (`QueuesendTest`, `main.roc`). |
| L2 | 293 of 293 in the code agent's run; `registry/al2-update-query`, `al2-update-window` green |
| L3 | 96 pass, 3 skipped; `update/rg7-flag-wins-env`, `up1-update-entries` green |
| Expected exits | `al2-update-query` runs 3 and 4: 2 (a bad `TALON_REGISTRY` and a bad `--registry`, R-RG7 row 6). The others exit 0. |
| Revert check | 10 of 11 caught; M6 (empty keep list) changes no command output (R-C9) and is caught at L0 by slice 207. |
| Design answers | Q437, Q438, Q439; the output proposals and call order accepted |
| Where the flow is | Not in `Update.roc`: the setting is read in `InstallFlow` after `ResolveLoad.prepared!`; the query runs in `PickFlow` after the scope (the groups need it). |
| Moved to 206d | `--offline` with a registry (the `Offline` index); `--json` `snapshot` with a time snapshot (now the same text as the human line; Q438 proposes time and log size apart); `log:N` in the compiler range step (`ResolveSelect.snapshot_of` still refuses it). |

