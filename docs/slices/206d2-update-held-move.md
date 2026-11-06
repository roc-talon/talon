# 206d2 Registry in update: held move, JSON snapshot, log:N in the range step

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 206d2 of `PLAN-P2-CLI.md`: parts 2 and 4 of the 206d row. It continues slice 206d (`PickFlow.query!`, `UnknownValues.settle!`, the anchors) and uses `LogSnapshot.second!` of slice 207.

## Scope

| In | Out (where) |
| --- | --- |
| `tln update` with a registry: the second closure query of a held move (R-SP16, R-SP23, R-SP24, Registry R-AP16), sent only when the first search has no tuple, through `LogSnapshot.second!` | The other commands (`install`, `add`, `verify`, `upgrade`, `outdated`): 206e, 206f |
| The anchor hold: an anchor of 206d (R-DI11, R-AP28) is never movable (R-SP23; 206d revert M8) | A held move after the ingest of R-AP28 case 2 (Q460: "the first answer" is the answer of `settle!`): no L2 case (see Notes 3) |
| `--json` `snapshot` with a time snapshot: the time and the log size apart (Design Q438, `Report.Outcome`) | The probes of a held move with an answer (`--no-check` in every case): 206e |
| `log:N` in the compiler range step of `update` with a registry (`ResolveSelect.ranged!`, `snapshot_of`) | |

## Rules

R-SP16, R-SP23, R-SP24, R-DT5, R-DT3 (Resolution 9, 11), R-AP16 (second query), R-AP19, R-CV1 (Registry 4.1; CLI 7.3), Design Q404, Q438, Q460. As used: R-SP26, R-AP18, R-AP74 row 3, R-DI1, R-DI11, R-AP28, R-DI7, R-AL8, R-RG4, R-SO13, R-AP47, R-J3, R-J6, R-OUT2.

## Code shape

| Name | Kind | Rule | State |
| --- | --- | --- | --- |
| `IndexQuery.held_anchors : { scoped : List(Vars.Scoped), anchors : List(Str) } -> List(Vars.Scoped)` | Pure, new | R-SP23, R-DI11: a variable with a use whose URL is an anchor gets `movable` false; nothing else changes | Stub `crash "todo: slice 206d2"` |
| `IndexQuery.second_groups : List(Vars.Scoped) -> List(ClosureRequest.Group)` | Pure, new | R-AP16 (second query), R-SP23, R-AP74 row 3: one group for each movable variable with a name, in scope order, made as in `groups` | Stub |
| `Report.Outcome.log : Try(U64, [None])` | Type, new field | R-DT5, Q438 | Done in the test step: every constructor has `log: Err(None)` (`InstallPlan.idle`, `InstallPlan.outcome_of`, `VerifyFlow`) |
| `Report.resolved_line : { at, log, probes } -> Str` | Pure, changed signature | R-DT5, Q438: with `log` `Ok(n)` and `at` not `log:<n>`: `resolved at <at> (log:<n>), ...` | Signature done (callers `Install.print!`, `Update` pass `log: outcome.log`); the body is not changed, so the new expect is red |
| `Report.data` | Pure, changed | Q438: the key `log_size` after `snapshot` when `log` is `Ok` | Not changed: the new expect is red (a wrong value) |
| `PickFlow.prepare!`, `PickFlow.search!`, `InstallFlow.finish!`, `ResolveSelect.ranged!` | Command code | The rest | Code agent |

## Reading that the tests fix

| # | Topic | Reading |
| --- | --- | --- |
| 1 | When | The second query is sent only when the first search has no tuple and a movable variable exists (R-SP16, `PickMoves.second_wanted`). Not in a run that finds a tuple. |
| 2 | Body | `LogSnapshot.second_request`: `groups` = `second_groups` of the scope after `held_anchors` (all movable variables, also when their group is in the first answer: the first query never holds them), `hashes` `[]`, `compilers` = the window of the first query. |
| 3 | Hide | `second!` with `first` = the answer that the first search used (the answer of `settle!`, Q460), `user` = N of `--snapshot log:N`, `keep` = the `hashes` of the first request (Q403, Q404). |
| 4 | Index and facts | The candidates of the movable variables come from the second answer (after the hide). The facts (records) of a moved release come from the second answer: no archive read (R-AL8 source 2). |
| 5 | Printed size | `resolved at log:<n>`: N of the user, else the `log_size` of the first answer, not of the second (R-DT5, Registry R-AP16 "the command prints the first `log_size`"). |
| 6 | Anchor | `held_anchors` with the anchors of `query!` runs before the first search. A fixed anchor is not movable, so with no other movable variable there is no second query and the run stops with exit 10 (R-SP16). |
| 7 | Range step | With a registry (the setting of `--registry`, `TALON_REGISTRY`, `config.toml`, read as in `InstallFlow.with_setting`), the range step lists the compilers of the registry (R-CV1: `Nightlies.list_registry!`), and `log:N` hides the toolchain rows above N (R-AP19, R-DT3). `log:N` is no failure there. A time snapshot keeps the time filter of `range_pick`. With `direct` the step is as before. |
| 8 | JSON | `data.snapshot` is the snapshot text as given (the time, or `log:<n>`; with no snapshot and an answer `log:<log_size>` as in slice 207), and `data.log_size` is the R-DT5 number, right after `snapshot`, only on a run with an answer (R-J6: a run with no answer has no such key). |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/IndexqueryTest.roc` (driver `l0-6.roc`), 4 new expects: `held_anchors` (an anchor URL: `movable` false, a free anchor stays free, other URLs stay; no anchors: no change); `second_groups` (movable only, scope order, series, joined ranges, `*` dropped, `any_series`; no movable or no name: `[]`) | R-SP23, R-DI11, R-AP28, R-AP16, R-SP24, R-DI1, R-AP74 |
| L0 | `tests/unit/ReportTest.roc` (driver `l0-5.roc`), 2 new expects: `resolved_line` with a time and `log` (`(log:50)`), with `at` = `log:30` (not twice), with no log; `data` with `log_size` after `snapshot` | R-DT5, R-J3, R-J6, R-OUT4, Q438 |
| L0 | `tests/unit/LogsnapshotTest.roc` (driver `l0-1.roc`), 1 changed expect: the `data` of a log run has `"log_size":184467` after `snapshot` | R-DT5, R-J3, Q438 |
| L2 | `registry/sp24-update-held-move` (new, 4 runs, `rules` has the detail): run 1 the second query and the move of pf, `resolved at log:40`; run 2 `--snapshot log:30`: the second answer is cut at 30, exit 10; run 3 `yaml@1.2.0`: pfx 0.1.2 (log 43) is above the first `log_size` 40, exit 10; run 4 the anchor: no second query, exit 10 | R-SP16, R-SP23, R-SP24, R-SP26, R-AP16, R-AP19, R-AP18, R-DT5, R-DI1, R-DI11, R-AP28, R-AP74, R-RG4, R-DI7, R-AL8, Q403, Q404, Q460 |
| L2 | `registry/dt3-update-range-log` (new, 2 runs): `[toolchain] roc` range, no compiler: the registry list, the newest in the range (2026-10-13) is the window; `--snapshot log:30` hides the row of log 40, so 2026-10-12 is the window, `resolved at log:30` | R-DT3, R-AP19, R-CV1, R-SO13, R-DT5, R-AP16 |
| L2 | `registry/sp24-held-move-drop` (new, Design Q466, G-C102; 1 run, `--no-probe --dry-run`): the ladder drops the first tuple of the second search (a new error in acme/json 2.0.0), the search runs again and moves json to 2.1.0. `calls.log` has exactly 2 POST `/v1/closure` (the first query and one second query): the second answer is kept and reused | R-AP3, R-SP24, R-SP16, R-SP26, R-AP16, R-AL6, R-PH13, R-LF2, R-DT5, Q466 |
| L2 | `registry/ix6-offline-range` (new, Design Q467, G-C103; 1 run): `update --no-check --dry-run --offline` with a registry, a `[toolchain] roc` range and no `toolchains.json`: the list is empty, exit 10 `no compiler is left: the compiler list of the registry is empty` (the text of `ClosureRequest.no_compiler`), not the exit 15 of `direct`. No request | R-IX6, R-IX4, R-AP74, R-SO13, R-DI12, Q467 |
| L2 | `registry/al2-update-window` (changed: run 3 added): run 2 with `--json`: `"snapshot":"2026-10-01T00:00:00Z","log_size":50` | R-DT5, R-J3, Q438 |
| L2 | `registry/al2-update-query` (changed: expect/stdout of run 2): `"snapshot":"log:30","log_size":30` | R-DT5, R-J3, Q438 |

The fixtures of the 4 new cases are made by `research/slice-206d2-revert/mkcases.py [<cases dir> [<case> ...]]` (given and fx only; it deletes the case dirs that it makes). The expect files were checked line by line against the rules above and the case `rules` files, and against a private reference run (see Revert check). Empty expect files were restored after the update run.

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-6.roc` | 87 pass, 4 fail: the 4 new expects, `todo: slice 206d2` |
| `roc test tests/unit/l0-5.roc` | 94 pass, 2 fail: the 2 new `ReportTest` expects (wrong value) |
| `roc test tests/unit/l0-1.roc` | 197 pass, 1 fail: the changed `LogsnapshotTest` expect (no `log_size`) |
| `tests/commands/run.sh` (normal `TMPDIR`) | 305 pass, 4 fail: `sp24-update-held-move` (no second query: exit 10 in run 1), `dt3-update-range-log` (run 1 reads the GitHub list, run 2 `needs a registry`, exit 2), `al2-update-window` (run 3: `snapshot` has `(log:50)`, no `log_size`), `al2-update-query` (no `log_size`) |
| `scripts/test.sh check fmt` | pass |
| `MISSING=1 scripts/rules.sh R-SP16 R-SP23 R-SP24 R-DT5 R-DT3 R-AP16 R-AP19 R-CV1` | none missing |

## Expected exits (read, TW21)

`sp24-update-held-move`: `expect/exit` 0; run 1 `exit 0` (dry run, R-SP26), runs 2, 3, 4 `exit 10` with `tln: error[no_tuple]: no tuple works: the releases of ... do not fit together (R-C2, R-C3)` (the failure of the first search, as `direct`). stderr of run 1: the report `~ pf: acme/pfx 0.1.0 -> 0.1.1 (held): yaml 1.1.0 needs pf >= 0.1.1` and the `writes` line. `dt3-update-range-log`: `expect/exit` 0, both runs `exit 0`, stderr empty. `al2-update-window` run 3: `exit 0`, the human lines on stderr. `tree.diff`: `projects.json` (and for `dt3` the kept toolchain rows and the 3 pins of `compat.tsv`, source `registry`).

## Revert check

`research/slice-206d2-revert/`: `before/` (the files before the test step, and the 2 changed cases), `mkcases.py`, `results.txt`. A private green reference (L0 drivers l0-1, l0-5, l0-6; all 309 L2 cases) was mutated 8 times, then deleted with the script (TW18).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | no anchor hold (206d M8) | L2 sp24 run 4, L0 |
| M2 | the second query also holds the free groups | L2 sp24 (body) |
| M3 | the second query ignores the user N (Q404) | L2 sp24 run 2 |
| M4 | no second query | L2 sp24 run 1 |
| M5 | the printed size is the second `log_size` | Not caught: equivalent in the reference (its `finish!` reads the first index). The expect files fix `log:40` |
| M6 | the second answer is not cut at the first `log_size` | L2 sp24 run 3 |
| M7 | the range step ignores `log:N` | L2 dt3 run 2 |
| M8 | the facts of a moved release are not read from the second answer | L2 sp24 run 1 |

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| `--json` with a registry answer | `data.log_size` (number), right after `data.snapshot`: the R-DT5 log size. Absent on a run with no answer. For the catalog of CLI 3 (R-OUT3): `install` and `update` rows |
| `--json` with a registry and a time snapshot | `"snapshot":"<time>","log_size":<n>` (Q438) |
| Human line | Unchanged: `resolved at <time> (log:<n>), <p> probes`, `resolved at log:<n>, <p> probes` |
| Held move with a registry | The texts of `direct` (the report, `fixed: not in the registry index` of 206d, the exit 10 failure) |

## Questions

Answered by the design (2026-11-03):

| # | Answer | Test change |
| --- | --- | --- |
| G-C102 | Design Q466, Registry R-AP3: the second query is sent once in a command, and its answer is reused by each later search. | The L2 case with a ladder drop that runs a second search (`ap16-second-query` or the held-move case of this slice) expects one second `closure` request in `calls.log`, not two. An L0 `expect`: the held second answer is the input of the next search. The code keeps the answer in the run state |
| G-C103 | Design Q467, CLI R-IX6: offline reads the rows of `toolchains.json` at any age; with no copy the list is empty (R-AP74 row 4, exit 10 if a compiler must be chosen). `data.log_size` is left out with no registry answer (agrees). | Add an L2 case `--offline` with a registry and a range: the range filters the kept rows (no request); and one with no `toolchains.json` and `upgrade`: exit 10 and the cause text. No change to existing cases |
| G-C104 | Design Q468, Registry R-AP74 row 4: with a registry and a non-empty list, a range that fits no compiler gives the text of `Toolchain.range_failed`, exit 10, as `direct`. | None for the code of `range_failed`. `ClosureRequest.no_compiler`: the causes switch and range call `range_failed` (its L0 rows for these 2 causes now expect the `range_failed` texts, not `no compiler is left: ...`); an L2 case with a registry, a range and a non-empty list expects the same stderr line as the `direct` case of the same range |

For the manager (plan scope, not TW17):

| # | Point |
| --- | --- |
| P1 | Part 4 "log:N in the range step" is R-CV1 in the range step of `update`: with a registry, the design lists the compilers with `GET /v1/toolchains` (R-CV1), and only that list has a log index for `log:N` (R-AP19, R-DT3). So `dt3-update-range-log` run 1 (no snapshot) also expects the registry list. The other compiler reads of a registry run (`HeldRoc.picked!`, the ladder's `offer!`, `NightlyFlow` of `upgrade`) still read GitHub; no case of this slice reaches them (`--no-check`). If the manager wants that smaller, move part 4 to 206e. |

## Notes for the code agent

| # | Point |
| --- | --- |
| 1 | The setting is read after the load today (`InstallFlow.with_setting`), but `ranged!` runs in the load. `ranged!` has `request.registry` (`Setting(flag)`) and `loaded.config.registry`: `IndexQuery.setting` and `IndexQuery.snapshot` can be called there. `Nightlies.list_registry!` (slice 204) is the registry list with the `log` cut. |
| 2 | `search!` gets `ready.request` (the `Answer` index of the first query); the second search needs the second answer for the candidates (`PickIndex.index!`) and for the facts (`PickLoop.run!` reads the records from the request index). |
| 3 | Q460: after the ingest of R-AP28 case 2, "the first answer" (for `second_cut` and the printed size) is the answer of `settle!`. No L2 case has an ingest and a held move; keep it by the rule. |
| 4 | M5: the printed size must stay the first `log_size` also when the run carries the second answer to `finish!`. |

## Code

| File | Change |
| --- | --- |
| `cli/lib/IndexQuery.roc` | `held_anchors` (an anchor URL: `movable` false, nothing else changes); `second_groups` (`groups` of the movable variables, as if free) |
| `cli/lib/PickFlow.roc` | `Ready.second` (new type `Second`: `origin`, the answer of `settle!` as `first`, the window and the `hashes` of the first request, the user N, the anchors). `prepare!`: `held_anchors` after `query!`, before the index and the slots. `search!`: `second_index!` for the second search: with a registry answer one `LogSnapshot.second!` (`second_groups`), the candidates of all movable names from the second answer (`anchored`, joined with the first index), and the second search reads its facts from the records of both answers (second first). With no answer: as before |
| `cli/lib/InstallFlow.roc` | `finish!`: `log_of` (`LogSnapshot.printed` of the first answer, as before) sets `Outcome.log`; `at` is the time of a time snapshot, else `log:<n>`. `at_text` removed (the line and `data` add the log size) |
| `cli/lib/Report.roc` | `resolved_line`: `<at> (log:<n>)` when `at` is not `log:<n>`; `data`: `log_size` after `snapshot` when `log` is `Ok` |
| `cli/lib/ResolveSelect.roc` | `ranged!`: `registry_of` (the setting of `update`, `IndexQuery.setting` and `IndexQuery.snapshot`, as `with_setting`). With a registry: the registry list with `log:N` as the row cut, a time as the `range_pick` time. Else as before |
| `cli/lib/RocInstall.roc` | `range_id!`: new member `registry`; `Ok` uses `Nightlies.list_registry!` in place of `Nightlies.list!` |
| `cli/lib/Proxy.roc` | `range_id!` call: `registry: Err(None)` |
| `cli/lib/ResolveBase.roc`, `PickLoop.roc`, `PickFlow.roc`, `RocInstall.roc` (Q466, Q467) | Q466: `Probed.second` keeps the second answer (`start`: `Err(NotRead)`); `second_index!` uses it again in a later search of the command (after a ladder drop), so one second query per command. Q467: `range_id!` with a registry list that is empty (offline with no kept `toolchains.json`) fails with `ClosureRequest.no_compiler` (exit 10, first cause "the compiler list of the registry is empty") |
| `cli/lib/ClosureRequest.roc`, `RocInstall.roc` (Q468) | `no_compiler`: the switch and the range causes give `Toolchain.range_failed` (exit 10, the text of `direct`; an unset range is the req text `""`, as `ResolveSelect.ranged!`). `Domain` gets the optional member `nightly_from ?: Pin.Source` (left out: `Default`), so the L0 domains need no change; `range_id!` passes `run.switch.source`. The empty list, `min-release-age` and the snapshot keep their texts |

Notes for the review:

| # | Point |
| --- | --- |
| 1 | `--offline` with a registry in the range step: the registry list with `offline` true (the kept rows, R-CV1, R-IX6). No case reaches it |
| 2 | A ladder drop (R-AL6) runs `search!` again; the second answer is used again with no request (Q466) |
| 3 | The second search reads the hints and the records of both answers; its candidates of a name in both indexes are the first list plus the new URLs of the second answer |

## Answers Q466, Q467 (2026-11-03): test changes

| Case | How the expect files were made | State after the code of 206d2 |
| --- | --- | --- |
| `sp24-held-move-drop` | A run of the code of 206d2, then by hand: the second, repeated POST `/v1/closure` (4 lines) is deleted from `calls.log` (Q466). The other lines were read against the rules (the drop note, the 2 moves, 5 probes, `resolved at log:40`, exit 0). A kept-copy case of Q467 is not added: offline and `--no-check` show no chosen compiler (no query body, no pin), and a probe needs a download | Red: one extra POST (the code sends the second query again after the drop) |
| `ix6-offline-range` | By hand: stdout `exit 10`, stderr the R-AP74 row 4 line; `calls.log` and `tree.diff` from the run (they stop after the read of `toolchains.json`) | Red: exit 15, `no cached list of compilers and --offline is set` |

## Answer Q468 (G-C104, 2026-11-03): test changes

| Test | Change | State |
| --- | --- | --- |
| L0 `tests/unit/ClosurerequestTest.roc` (driver `l0-8.roc`), the `no_compiler` expect | The range row expects `no compiler release is in [toolchain] roc (0.1.*)`. The switch row and the "first of 2 reasons" row expect the `range_failed` form `no compiler release is in [toolchain] roc ...`, `, and nightly is false (set by ...`: the req text of an unset range and the source of the switch are not fixed, because `ClosureRequest.Domain` has no source of the switch (the code agent adds what `range_failed` needs). The rows of the empty list, `min-release-age` and the snapshot do not change | Red (190 pass, 1 fail): the code of `no_compiler` must change |
| L2 `registry/so13-range-none` (new, 1 run; fixtures by `mkcases.py ... so13-range-none`, expect files by hand) | A registry, a range after the newest row of a non-empty registry list: exit 10, `tln: error[no_tuple]: no compiler release is in [toolchain] roc (>=nightly-2026-10-20-0000000)`, the same text as `direct` (consent/dl3-rank4 p6). Calls and tree: run 1 of `dt3-update-range-log` up to the pins of the list | Green with the current code (the range step already calls `range_failed`) |

## Disputes (from the code agent)

| # | Dispute | Answer (test agent) |
| --- | --- | --- |
| D1 | `tests/unit/IndexqueryTest.roc` defines `pf_url` twice (the slice 206d2 helpers repeat it): `roc test` reports a duplicate definition | Accepted: the second definition (same value) is deleted. `scripts/test.sh fmt l0`: pass |

| # | Test | Point |
| --- | --- | --- |
| D1 | `tests/unit/IndexqueryTest.roc` | `pf_url` is defined twice (line 137, and line 197 in the slice 206d2 helpers). `roc test tests/unit/l0-6.roc` runs all 91 expects with a pass, but it reports the error `duplicate definition`, so the `l0` step of `scripts/test.sh` fails. The second definition has the same value: the test agent can delete it (TW18: the code agent does not edit tests) |

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206d2-revert/code-final.sha256` | 9 of 9 OK |
| `todo: slice 206d2` in `cli/` | None |
| `scripts/test.sh check fmt l0 l2 l3` | All pass (l2 311 of 311) |
| Slice cases | L0 `IndexqueryTest`, `ReportTest`, `LogsnapshotTest`. L2 `sp24-update-held-move`, `sp24-held-move-drop`, `dt3-update-range-log`, `ix6-offline-range`, `al2-update-window`, `al2-update-query` green; all registry cases green. |
| Expected exits | `sp24-update-held-move` runs 2 to 4: 10 (the snapshot cut, the log-size cut and the anchor hold leave no fit). `ix6-offline-range`: 10 (empty registry compiler list, R-AP74 row 4, Q467). The others exit 0. |
| Revert check | 7 of 8 caught. M5 (printed size from the second answer) changes no output in the reference; the expect files fix `log:40`. |
| Dispute D1 | Accepted: a duplicate `pf_url` in `IndexqueryTest.roc` deleted by the test agent. |
| Design answers | Q404, Q438, Q460, Q466, Q467; `data.log_size` proposal accepted |
| G-C104 | Answered as Q468: the range and switch causes keep the `Toolchain.range_failed` text and exit 10, as direct does. `ClosureRequest.no_compiler` changed (`Domain.nightly_from`); L0 `ClosurerequestTest` and L2 `registry/so13-range-none` green; l2 312 of 312. With no range and the switch off, the text has `roc ()`, as the direct path prints. |
| Moved out | Slice 206e: `HeldRoc.picked!`, `offer!`, `NightlyFlow` with the registry list; an R-AP28 ingest during a held move. |

Changed by Q489 in slice 206e2: `registry/ix6-offline-range` now expects exit 15 and `tln: error[network]: no cached list of compilers and --offline is set` (an offline run with no `toolchains.json` has a list that cannot be read, not an empty list: Registry R-AP74 row 4, CLI R-IX6). The calls and the tree do not change.

