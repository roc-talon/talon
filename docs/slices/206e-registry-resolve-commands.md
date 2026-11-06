# 206e Registry in the other resolve commands

Phase: P2 (CLI client). Status: done (sub-slice 1, closed 2026-11-03). The rest is in plan rows 206e2, 206e3, 206e4.

Plan row 206e of `PLAN-P2-CLI.md`. It holds the parts that slices 206b, 206d2, 209, 210, 215 and 216 moved out. The row is too large for one review (TW19). The test agent proposes 4 sub-slices. Each one builds on the one before it.

## Split (proposal for the manager)

| # | Sub-slice | Content | Rules | Depends on |
| --- | --- | --- | --- | --- |
| 1 | 206e (this file) | The other resolve commands reach the registry through the flow of `update` (`InstallFlow.with_setting`, `PickFlow.query!`, `settle!`, `--offline`, the R-DT5 line, `data.log_size`): `install` with no names (not `--frozen`), `verify`, `upgrade <names>` (the nightly is held, so the window is the held pin). The P0 refusal is lifted for these command lines only. | R-AL2, R-DI1, R-AP16, R-FL5, R-RG1, R-RG7, R-UP1, R-UP3, R-UP13, R-CM11, R-DT5 | 206d2 |
| 2 | 206e2 | The registry compiler list in a registry run (R-CV1): `upgrade` with a free nightly (no names, `roc`, `X roc`: the `Free` window from `Nightlies.list_registry!`, `NightlyFlow`), `HeldRoc.picked!`, the `offer!` of the ladder. `outdated` (`OutdatedFlow`, not `PickFlow`): the rows as groups, the `Report` window, the compiler domain of the `range` column. An L2 case with an R-AP28 ingest and a held move together (Q460). | R-CV1, R-AP16, R-AP74 row 4, R-UP6, R-CM6, R-AP28, R-SP24 | 206e |
| 3 | 206e3 | Probe runs with an answer: `PickLoop.read_all!` and `hinted!` (`PairOrder.order_shared`), `Matrix.rows`, `real`, `found`, `unknown_sets` in `PickLoop` and `ProbeRange`, the R-EF3 note in the resolve commands. `tln why` with the registry evidence (`Evidence.of_all`, `differ`; where `why` gets an answer). | R-EF1, R-EF3, R-EP15, R-SE5, R-CM7 | 206e2 |
| 4 | 206e4 | The index notes of slice 210 in `update` and `outdated` (both answers of a held move, stderr, `--quiet` R-FL4, exit code, `data.index_notes`). The end-of-command hooks: `ShareQueue.enqueue!` after the probe rounds (with the headers input of Q450) and `QueueSend.send!` after the output, in `update`, `install`, `upgrade`, `verify`. | R-AP29, R-AP30, R-FL4, R-SH2, R-SH3, R-SH4 | 206e3, 215, 216 |

Reasons for the order:

| # | Reason |
| --- | --- |
| 1 | Sub-slice 1 is wiring only: the query, `settle!`, `--offline` and the snapshot already work in `update`. No compiler list and no probe is needed (`--no-check` in each case). |
| 2 | The `Free` window of `upgrade` and the `Report` window of `outdated` both need the registry compiler list before the query (Registry R-AP16 `compilers`). The other compiler reads of a registry run (`HeldRoc.picked!`, `offer!`, `NightlyFlow`) use the same list. `outdated` has its own flow (`OutdatedFlow`), so it is not free wiring. |
| 3 | The evidence of the answer changes the probe calls. It needs commands that probe with a registry, so it comes after the compiler list (a probe needs a compiler). |
| 4 | The share queue admits probe facts (R-SH3), so it comes after sub-slice 3. The index notes are small and are output only. |

Until each sub-slice is done, a command line that is not wired keeps the P0 refusal of `--registry` and ignores `TALON_REGISTRY` and `config.toml`, as before.

The rest of this file is sub-slice 1.

## Scope (sub-slice 1)

| In | Out (where) |
| --- | --- |
| `Opts.check_registry`: no refusal for `install` (`i`, `add`) with no names and no `--frozen`, `verify`, `upgrade` with names and no `roc` (the nightly is held, R-UP13) | `install <names>`, `add <names>`, `install --frozen` (R-RG7 row 6 for a command with no index call): 206f. `upgrade` with a free nightly, `outdated`: 206e2 |
| `ResolveBase.Request.registry` is `Setting(args.registry)` for the command lines above, `Off` for the others (`Install.flow!`, `Verify.flow!`, `Update.request_of`) | `init` (it runs `upgrade` with no names or with `roc`): stays `Off` |
| `verify` reads the setting after the load (as `InstallFlow.with_setting`), the window is the held pin, the search uses the request with the `Answer` index, the outcome has the log size (`log`, `at`) | Probes with an answer, the R-EF3 note, `why`: 206e3. The index notes, the share hooks: 206e4 |
| `install` and `upgrade`: no new code beyond the setting (they run `InstallFlow.run!`) | |

## Rules

R-AL2 (step 2), R-DI1, R-AP16, R-FL5, R-RG1, R-RG7 (row 6), R-UP1, R-UP3, R-UP13, R-CM11, R-DT5 (CLI 1, 7.3; Resolution 5, 9, 10, 11; Registry 4.1). As used: R-RG4, R-RG5, R-AP74 (rows 3, 5), R-SP7, R-SP19, R-SP20, R-DI7, R-DI11, R-DI14, R-AL8, R-AP28, R-PU40, R-IX5, R-IX6, R-DT3, R-DT4, R-AP19, R-J3, R-EC2, Design Q438, Q462, Q465.

## Code shape

No new function, so no stub. The tests are red on the bodies that exist:

| Name | Kind | Change for the code agent |
| --- | --- | --- |
| `Opts.check_registry` | Pure (L0 through `Opts.read`, `Verify.read`, `Upgrade.read`) | The command lines of the scope table pass. The others keep the P0 text |
| `Install.flow!`, `Verify.flow!`, `Update.request_of` | Command code | `registry: Setting(args.registry)` for the lines of the scope table |
| `VerifyFlow.verify!` | Command code | The setting (as `InstallFlow.with_setting`), the snapshot of a `Read` (as `InstallFlow.resolve!`), the held pin as the window, `prepare!` then `search!` with `ready.request` (today `PickFlow.pick!` passes the request before the query), and `log` and `at` as `InstallFlow.finish!` (`log_of`) |

## Reading that the tests fix

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Which lines reach the registry | `update` (206b), `install` with no names and no `--frozen`, `verify`, `upgrade` with one name or more and no `roc`. The check uses the operands of the line (`Opts.read`) |
| 2 | Groups | The free variables of the command (`IndexQuery.groups`): `install` with no names the variables outside their ranges (R-SP20), `verify` every `Indexed` variable (it runs as `update` with no names), `upgrade X` the named variables with no series and no range (R-UP1, R-UP3; `Vars.scope` gives `ranges` `[]` and `any_series`) |
| 3 | Window | The held pin (R-AP16): `from` = `to` = `roc:` of the header. `upgrade X` holds the nightly (R-UP13) |
| 4 | `settle!`, offline, snapshot | As in `update` (slices 206b, 206d, 206d2): no new rule. `verify` prints the same `fixed:` lines |
| 5 | `verify` output | No R-DT5 line (as before). `--json` `data` has `snapshot` and `log_size` as `install` (proposal below) |
| 6 | No registry | `--registry direct`, and every line that is not wired: the same calls and output as before the slice. Run 1 of each new case and run 4 of `al2-upgrade-query` were compared with a run of the unchanged code: equal |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/OptsTest.roc` (driver `l0-6.roc`), 1 new expect: `install`, `i` with no names take a URL (also a bad text: the flow reads it); `install <names>`, `add <names>`, `install --frozen` keep the P0 text; `--frozen --registry direct` passes. 1 row moved out of the failure expect (`install --registry <url>`) | R-FL5, R-RG1, R-RG7, R-AL2, R-DI1 |
| L0 | `tests/unit/UpdateTest.roc` (driver `l0-7.roc`): the `verify` expect: `--registry <url> --frozen` now fails on `--frozen`; 2 new rows (`--registry <url>`, a bad text) | R-FL5, R-RG1, R-AL2, R-CM11 |
| L0 | `tests/unit/UpgradeTest.roc` (driver `l0-1.roc`), 1 new expect: `upgrade json` and `upgrade json parser` take a URL; `upgrade`, `upgrade roc`, `upgrade json roc` keep the P0 text; `--registry direct` passes | R-FL5, R-RG1, R-RG7, R-AL2, R-DI1, R-UP13 |
| L2 | `registry/al2-install-query` (entry `commands`, 4 runs, `rules` has the detail): direct; registry (guard, one POST with only the free group json and its `talon.toml` range, `resolved at log:50`); `--json --snapshot log:30` (`"snapshot":"log:30","log_size":30`); a bad `--registry` gives the R-RG7 text, exit 2 | R-AL2, R-DI1, R-AP16, R-AP74, R-RG1, R-RG4, R-RG5, R-RG7, R-FL5, R-SP19, R-SP20, R-DI14, R-AL8, R-DT3, R-DT5, R-AP19, R-J3, R-EC2 |
| L2 | `registry/di1-install-no-free` (Design Q469, 3 runs, `rules` has the detail): u1 has no `talon.toml` (one member: nothing is outside, R-SP21). Run 1 `install --no-check --dry-run --json`: the guard (URLs only), one POST with `groups` `[]`, the 3 header hashes and the held window, no archive read, `"snapshot":"log:50","log_size":50`, `nothing to change`. Run 2 `--frozen`: no guard, no request. Run 3 a package header with no entry (u2): no guard, no request, `snapshot` is the time, no `log_size`. Expected files by hand from the direct run and the rules | R-DI1, R-AL2, R-AP16, R-AP74, R-RG4, R-RG5, R-AL8, R-DT5, R-J3, R-SP19, R-SP21, R-LF1 |
| L2 | `registry/al2-verify-query` (4 runs): direct (with the `example.org` line of `direct`); registry (3 groups, 4 hashes, `settle!` case 3: `other: fixed: not in the registry index`, only the archive of `other` read); `--json --snapshot log:30`; `--offline` (no request, 3 `offline, no cached index` lines, every archive read) | R-AL2, R-DI1, R-AP16, R-AP74, R-RG1, R-RG4, R-RG5, R-FL5, R-CM11, R-AP28, R-PU40, R-DI7, R-DI11, R-IX6, R-IX5, R-DI14, R-AL8, R-DT3, R-DT5, R-AP19, R-J3 |
| L2 | `registry/al2-upgrade-query` (4 runs): direct (json to 3.0.0, new series); registry (one group json with no `series` and no `range`, json to 3.0.0, `resolved at log:50`); a time snapshot hides 3.0.0 (`resolved at 2026-09-26T00:00:00Z (log:50)`); `upgrade` with no names and the `config.toml` registry stays direct (no POST) | R-AL2, R-DI1, R-AP16, R-AP74, R-RG1, R-RG4, R-RG5, R-FL5, R-UP1, R-UP3, R-UP13, R-SP7, R-DT4, R-DT5, R-DI14, R-AL8 |

The fixtures are made by `research/slice-206e-revert/mkcases.py` (given and fx; each case starts from a copy of `registry/al2-update-query`). The expect files came from a run of the private reference (see Revert check). Each line was then read against the rules above and the case `rules` files (the call order, the request bodies, the archive reads, the lines). Run 1 of each case (and run 4 of `al2-upgrade-query`) was compared with a run of the unchanged code: the same calls and output.

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-6.roc` | 91 pass, 1 fail: the new `OptsTest` expect (the P0 refusal) |
| `roc test tests/unit/l0-7.roc` | `UpdateTest` 1 fail (the `verify` expect). The 20 `ShareloginTest` fails are slice 219 (another agent) |
| `roc test tests/unit/l0-1.roc` | 198 pass, 1 fail: the new `UpgradeTest` expect |
| `tests/commands/run.sh registry/di1-install-no-free` (after Q469, the unchanged code of the tree before the code agent) | Red in run 1 only (no guard, no POST, the 3 archives read, `snapshot` is the time). Runs 2 and 3 already give the expected calls and output (they are the direct behavior) |
| `tests/commands/run.sh` (normal `TMPDIR`) | 318 pass, 4 fail: the 3 new cases (runs 2 and 3 go direct; `--snapshot log:30` stops with `needs a registry`; the bad `--registry` gives the P0 text) and `share/sh26-login-declined` of slice 219 (another agent) |
| `scripts/test.sh check fmt` | pass |
| `MISSING=1 scripts/rules.sh R-AL2 R-DI1 R-AP16 R-FL5 R-RG1 R-RG7 R-UP1 R-UP3 R-UP13 R-CM11 R-DT5` | none missing |

## Expected exits (read, TW21)

| Case | `expect/exit` | Runs |
| --- | --- | --- |
| `al2-install-query` | 0 | 0, 0, 0, 2 (a bad `--registry`, R-RG7 row 6: `--registry 'http://example.org' is not a registry URL. ...`) |
| `al2-verify-query` | 0 | 0, 0, 0, 0. stderr: the human lines of the `--json` run 3 |
| `di1-install-no-free` | 0 | 0, 0, 0. stderr: `nothing to change` and `dry run: nothing was written` of runs 1 and 3 (`--json`) |
| `al2-upgrade-query` | 0 | 0, 0, 0, 0. No stderr. Run 4 runs the 6 fake probes of the direct code (`check: passed`, `build: passed`) |

`tree.diff`: `projects.json`, the kept guard answer of `acme/parser`, and the GitHub pages and `compat.tsv` that the direct runs write. No header write (dry runs and `verify`).

## Revert check

`research/slice-206e-revert/`: `before/` (the 7 code files before the slice: no code file is changed in the test step), `mkcases.py`, `results.txt`. A private green reference passed l0-1, l0-6, l0-7 and 310 of 315 L2 cases (`tool/rm1`, `rm2`, `rm3`, `rm5`, `rm7` fail only because of the private `TMPDIR`, also on the unchanged code). It was mutated 7 times, then deleted with its script (TW18).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `verify` does not read the setting (no query) | L2 `al2-verify-query` |
| M2 | `verify` searches with the request before the query (facts not from the answer) | L2 `al2-verify-query` (archive reads) |
| M3 | `verify` sends no window | L2 `al2-verify-query` (request body) |
| M4 | `verify` has no log size in the outcome | L2 `al2-verify-query` run 3 |
| M5 | the refusal lifted for `install <names>` | L0 `OptsTest` |
| M6 | the refusal lifted for `upgrade` with a free nightly | L0 `UpgradeTest` |
| M7 | `upgrade` with no names reads the `config.toml` registry | L2 `al2-upgrade-query` run 4 |

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| `verify --json` with a registry answer | `data.snapshot` `log:<n>` (or the time of a time snapshot) and `data.log_size` `<n>` after it, as the `data` of `install` (slice 206d2). The human output has no R-DT5 line, as before |
| `install`, `upgrade <names>` with a registry | The texts of `update` (206b, 206d, 206d2): `resolved at log:<n>, <p> probes`, `resolved at <time> (log:<n>), <p> probes`, the `fixed:` lines |
| A command line that is not wired yet | The P0 text, unchanged: `--registry '<url>': no registry exists in this version of tln. Use --registry direct.` |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | `tln install` with no names when no variable is free (each header entry is inside its ranges, R-SP20, R-LF1): with `direct` the run lists no group and makes no index call. With a registry, does the run send the closure query (no `groups`, the `hashes` of the header: the records of R-AL8 source 2 in place of the archive reads), or no query, as R-DI1 says for a command that resolves nothing? The tests have a free variable in each registry run, so they do not fix it | Answered (Design Q469, CLI R-DI1). Test change done: L2 `registry/di1-install-no-free` (the `--frozen` and the no-entry runs are in it; the human R-DT5 line is not printed when nothing changes, so the log size is checked in `--json`). The query is sent, with no `groups` and the header `hashes`. Test change: add an L2 case: `tln install` with a registry and every entry in its range: one `closure` request with `groups` `[]` and the header hashes, the R-DT5 line with `log:<n>`; a case with `--frozen`: no request; a header with no dependency: no request and the time. `verify --json` has `snapshot` and `log_size` as proposed |

Plan notes for the manager (not design questions):

| # | Point |
| --- | --- |
| P1 | `install --frozen` keeps the P0 refusal of `--registry` in this sub-slice: R-RG7 row 6 (no stop for a command with no index call) is in plan row 206f |
| P2 | For 206e2: `outdated` with a registry needs the compiler list before the query (the `Report` window), also when no row is behind (today the list is read only when a row is behind, `OutdatedFlow` step 7). Its groups are probably the rows with no `series` and no `range` (Registry R-AP16: "with no range ... where R-UP1 says that the range does not apply"; the `latest` column shows a new series). The 206e2 test agent must check both against the design |

## Code

| File | Change |
| --- | --- |
| `cli/lib/Opts.roc` | `check_registry` uses `reads_registry`: no refusal for `update`, `verify`, `install` (`i`, `add`) with no names and no `--frozen`, `upgrade` with one name or more and no `roc`. The other lines keep the P0 text |
| `cli/lib/Install.roc` | `flow!`: `registry` is `Setting(args.registry)` with no names and no `--frozen`, else `Off` |
| `cli/lib/Verify.roc` | `flow!`: `registry: Setting(args.registry)` |
| `cli/lib/Update.roc` | `request_of`: `Setting` also for `upgrade` with names and no `roc`. `init` (no names or `roc`) stays `Off` |
| `cli/lib/InstallFlow.roc` | New public `setting_of` (= `with_setting`) and `log_size` (= `log_of`) for `VerifyFlow` |
| `cli/lib/VerifyFlow.roc` | `verify!`: the setting after the load, the snapshot of a `Read` (time as cutoff, `log:N` in `prepare!`), the held pin as the window, `prepare!` then `search!` with `ready.request`, `verified!` with `ready.request`, then `log` and `at` as `InstallFlow.finish!` |
| `cli/lib/PickFlow.roc` | `query!` (Design Q469): no source (no group and no hash) gives no guard and no query (the run is as `direct`). `pick!` and its helper `no_optional` deleted (no caller) |

Notes for the review:

| # | Point |
| --- | --- |
| 1 | Q469 no-source rule is in `query!`, so it also applies to `update` and `upgrade <names>` (a header with no group and no hash). No case of `update` reaches it |
| 2 | A run with no query keeps `registry: Read` with the index `Direct`: `log_of` gives `Err(None)`, so `snapshot` is the time and there is no `log_size` (run 3 of `di1-install-no-free`) |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206e-revert/code-final.sha256` | OK, 7 files |
| `grep "todo: slice 206e" cli/` | nothing |
| L2 `registry/al2-install-query`, `al2-verify-query`, `al2-upgrade-query`, `di1-install-no-free` | pass. Expected exit 0 in all (read) |
| `scripts/test.sh check fmt l0 l2 l3` | check, fmt, l3 pass. l0: only the 24 slice 219 `ShareloginTest` expects fail. l2: 316 pass, only slice 219 `share/sh23` to `sh32` fail (red tests, code not yet written) |
| Review note 3 | `PickFlow.pick!` and `no_optional` had no caller: deleted by the code agent. check, fmt, l0-6 and the 4 L2 cases pass after it |
| Review notes 1, 2 | Accepted. Q469 "no source, no query" in `PickFlow.query!` also covers `update` and `upgrade <names>`: this agrees with Q469 (a query has a source or is not sent) |

