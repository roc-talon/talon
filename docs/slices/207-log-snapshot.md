# 207 Log snapshot and the second query

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 207 of `PLAN-P2-CLI.md`. With a registry, `--snapshot log:N` hides the releases of the closure answer above N (R-AP19). The command prints `resolved at log:<n>` (R-DT5) and puts the same text in `snapshot` of `--json`. The second query of a held move gets the first `log_size` as `log:N` (R-AP16, R-SP24).

## Scope

| In | Out (where) |
| --- | --- |
| New module `cli/lib/LogSnapshot.roc` (in `main.roc`): `hide_above`, `second_cut`, `printed`, `at_text`, `second_request`, `second!` | The query step inside the commands: the choice of the groups of a first query, when a command sends the second query (only when the search with the held variables fixed finds no tuple, R-SP16), the groups of the movable variables with the ranges of a moved variable (R-SP23), the `Request.index` of the run set to `Answer` after the query. Slice 206b (the same step as in slice 206: no command can pick a registry before slice 224) |
| R-AP19 on the releases of an answer (the closure answer has no compiler rows) | The compiler rows: done (slice 204 `RegistryToolchains.visible`, slice 205 `ClosureRequest.allowed`: `Log(n)` keeps `log_index <= n`) |
| R-DT5: the number that is printed, and its text `log:<n>` for `Report.resolved_line` and `Report.data` | The call of `Report.resolved_line` and `Report.data` with this text in `Install.run!`, `Update.run!` and the other commands (the `at` of the `Outcome` is set by `Resolve`): slice 206b |
| R-AP16 second query: the body, the one send, the one-state check, the hide by the first `log_size` | A command with no release left after the snapshot: R-AD36 (`tln add`, exit 2, no ingest), and the same case for the other commands (slice 206b, and the add slices) |
| | The usage failure of `log:N` with `direct` (R-DT3, R-EC2): done (`Intent.direct_snapshot`, `IntentTest`) |

## Rules

R-AP19, R-DT5, R-DT3 (the log form with a registry), R-SP24 (registry), R-AP16 (second query), Design Q403 to Q405 (R-C9, R-AP63). As used: R-AP18 (one state, also for the second answer), R-AP3, R-AP34 (one send, no second try), R-IX3 (no file), R-E6, R-J3 (`snapshot` of `--json`), R-FL9.

## Decisions (pure, L0) and flows (L2)

| Name | Signature | Rule |
| --- | --- | --- |
| `LogSnapshot.hide_above` | `Wire.Answer, { n : U64, keep : List(Str) } -> Wire.Answer` | R-AP19, Q403, Q405 |
| `LogSnapshot.second_cut` | `{ user : Try(U64, [None]), first : Wire.Answer } -> U64` | R-AP16, Q404 |
| `LogSnapshot.printed` | `{ snapshot : Try(U64, [None]), first : Wire.Answer } -> U64` | R-DT5 |
| `LogSnapshot.at_text` | `U64 -> Str` | R-DT5, R-J3 |
| `LogSnapshot.second_request` | `{ groups : List(ClosureRequest.Group), compilers : Try(Wire.Window, [None]) } -> Wire.Request` | R-AP16, R-SP24 |
| `LogSnapshot.second!` | `Fx, { origin, version, first : Wire.Answer, compilers, groups, keep : List(Str), user : Try(U64, [None]) } => Try(Wire.Answer, Fail)` | R-AP16, R-AP19, R-AP18, R-SP24, R-AP34, R-IX3, Q403, Q404 |

Reading that the tests fix:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | `hide_above` | Removes each release row with `log_index` greater than `n`, except a row whose `hash` is in `keep` (the `hashes` of the request, Q403). `log_index` = `n` stays. The order stays |
| 2 | Other members | `epochs`, `hints`, `artifacts`, `unknown`, `checked`, `repos` and `log_size` are not changed (R-AP19, Q405) |
| 2b | `second_cut` | The first `log_size`, or the smaller of it and the user's N (Q404) |
| 3 | `printed` | `Ok(N)` gives N, also when N is above `log_size` (R-DT5: "or N of `--snapshot log:N`"). `Err(None)` gives the `log_size` of the first answer |
| 4 | `at_text` | `log:<n>`. With it, `Report.resolved_line` gives `resolved at log:184467, 4 probes` and `Report.data` gives `"snapshot":"log:184467"` (the existing functions, no change) |
| 5 | `second_request` | `groups` as given (order, series, range). `hashes` is `[]`. `compilers` is the one of the first query |
| 6 | `second!` | The checks, the one send (`Post`, `Registry.closure_url`, 20 s) and the errors are those of `ClosureIndex.query!`. Then the one-state check against the second `log_size` (R-AP18), then `hide_above` with `second_cut` and `keep` (the `hashes` of the first request: the second request has none, Q403, Q404). No second try. No file. The printed log size stays the first one |
| 7 | Request | A snapshot adds nothing to the first request: the client applies it to the answer (R-AP19, R-AP16 has no snapshot member) |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/LogsnapshotTest.roc` (driver `l0-1.roc`): `hide_above` at N = a row, N below, N above | R-AP19 |
| L0 | `hide_above` with a keep list: a kept hash above N stays, the others go | R-AP19, Q403, R-C9 |
| L0 | the other members stay, also with a keep list | R-AP19, Q405 |
| L0 | `second_cut`: none, user smaller, equal, larger | R-AP16, Q404 |
| L0 | `printed` with N, with none, with N above `log_size` | R-DT5 |
| L0 | `at_text` and the line and the `data` of `Report` | R-DT5, R-J3 |
| L0 | `second_request`: groups, no hashes, the same `compilers` (a window, none) | R-AP16, R-SP24 |
| L2 | `registry/ap19-log-snapshot`: 3 runs on one answer (log 10, 30, 31, 50; log_size 50): `snapshot=30` gives 2 releases and `log:30`, none gives 4 and `log:50`, `snapshot=900` gives 4 and `log:900`. Run 4: the entry names the release 1.2.0 (log 31), `snapshot=30`: it stays, 3 releases (Q403). `log_size` and `artifacts` stay in every run (Q405). The first 3 request bodies are equal | R-AP19, R-DT5, R-DT3, R-AP16, R-IX3, Q403, Q405 |
| L2 | `registry/ap16-second-query`: run 1: the first query (held window, 1 hash), the second query with only the movable group, `hashes` empty, the same `compilers`, the second answer has log 12, 38, 43 with `log_size` 45: the release 43 is hidden by the first `log_size` 40, the line is `log:40`. Run 2: the second answer has a release above its own `log_size`: exit 15. Run 3 (Q404, Q403): `snapshot=20` below the first `log_size` 40, the entries give `hashes` [json 1.0.0, basic-cli 0.27.0]: the second answer is cut at 20, so 12 stays, 38 is hidden (a cut at 40 would keep it), 43 stays by the keep list: 2 releases, `log:20` | R-AP16, R-SP24, R-AP19, R-AP18, R-DT5, R-E6, R-IX3, Q403, Q404, Q405 |

New words of the entry `registry` (`tests/commands/L2Registry.roc`, doc table): `snapshot=<n>`, `resolved`, `then-group=<form>[@<series>]`, `name2=<owner/repo>` of the line `closure`. The lines `log_size`, `artifacts` and `unknown` are of the answer after the hide (Q405). `keep` is the `hashes` of the first request. `then-group=` passes `user` = the N of `snapshot=`. The fixtures and the hand-written expect files are made by `research/slice-207-revert/mkcases.py` (not from a run, TW21).

Not tested here (slice 206b, no choice made): the choice of the groups and the time of the second query in a command (R-SP16, R-SP23, R-SP24), the `--snapshot` flag to `LogSnapshot.hide_above` in a command, the printed line and the `snapshot` of `--json` of a whole command with a registry, the release-less name after a snapshot (R-AD36).

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-1.roc` | 108 pass, 9 fail: each `LogsnapshotTest` expect, `todo: slice 207` |
| `tests/commands/run.sh` | 270 pass, 2 fail: `registry/ap19-log-snapshot` and `registry/ap16-second-query`, `[ROC CRASHED] todo: slice 207` |
| `scripts/test.sh check fmt` | pass |

## Expected exits (read, TW21)

`ap19-log-snapshot`: `expect/exit` 0, no failure line, stdout holds 4 runs (2, 4, 4, 3 candidates and `log:30`, `log:50`, `log:900`, `log:30`). `ap16-second-query`: `expect/exit` 0; run 1 and run 3 have no failure line; run 2 has `exit 15` (R-AP18 on the second answer, R-E6) and the same text on stderr as slice 206 `ap18` (a proposal, R-OUT2). Both cases pass with a private reference, and the files are written by hand from the rules.

## Revert check

`research/slice-207-revert/`: `before/` (the stubs), `mkcases.py`, `results.txt`. A private reference and 7 mutations were run, then deleted (TW18): reference green (L0 and both L2 cases), each mutation caught.

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `hide_above` ignores the keep list (Q403) | L0, `ap19`, `ap16` |
| M2 | `hide_above` drops the row equal to N | L0, `ap19` |
| M3 | `second_cut` ignores the user N (Q404) | L0, `ap16` run 3 |
| M4 | `second_cut` takes the user N when it is larger | L0 |
| M5 | `second!` has no keep list (Q403) | `ap16` run 3 |
| M6 | `hide_above` clears `unknown` (Q405) | L0 |
| M7 | `second!` hides before the one-state check (R-AP18) | `ap16` run 2 |

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| The line of R-DT5 with a registry | `resolved at log:<n>, <probes> probes` (the form of `Report.resolved_line`, the `at` is `log:<n>`) |
| `--json` | `"snapshot": "log:<n>"` (the example of CLI 3) |
| A second answer above its own `log_size` | The text of slice 206 (Q390) |

## Questions

| # | Question | State |
| --- | --- | --- |
| Q1 | A release of a header hash above N: hidden or kept? | Answered (Design Q403, Registry R-AP19): kept, with the toolchain row of the held `roc:` pin. `hide_above` has `keep`. The toolchain row is kept by the compiler list: slice 206b |
| Q2 | A user N with a second query | Answered (Design Q404): hidden by the smaller of N and the first `log_size`, with the same keep list. `second_cut`, and `second!` has `user` and `keep` |
| Q3 | The other members of the answer | Answered (Design Q405): not changed, `log_size` too. The printed number is as R-DT5 |

## Code

| File | Change |
| --- | --- |
| `cli/lib/LogSnapshot.roc` | The 6 stubs of the table (`crash "todo: slice 207"`) |
| `cli/lib/main.roc` | `LogSnapshot` in the package list |
| `tests/unit/LogsnapshotTest.roc`, `tests/unit/l0-1.roc` | The L0 tests and the driver import |
| `tests/commands/L2Registry.roc` | The words of the table above (test code) |
| `tests/commands/cases/registry/ap19-log-snapshot/`, `ap16-second-query/` | The L2 cases |

### Code result

| File | Change |
| --- | --- |
| `cli/lib/LogSnapshot.roc` | The 6 bodies; `second!` reuses the steps of `ClosureIndex.query!`, then `one_state`, then `hide_above` |
| Levels | `scripts/test.sh check fmt l0 l2 l3`: all pass |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-207-revert/code-final.sha256` | 2 of 2 OK (`LogSnapshot.roc`, `ClosureIndex.roc`) |
| `todo: slice 207` in `cli/` | None |
| `scripts/test.sh check fmt l0 l2 l3` | All pass. Over the time budgets (TW20 warnings) because other sessions loaded the machine. One `l0` run gave FAIL with an empty log (a shared `.work/` log written over); `l0` alone passed. |
| Slice cases | L0 `LogsnapshotTest` 9 of 9. L2 `ap19-log-snapshot`, `ap16-second-query` green. |
| Expected exits | All 0, except `ap16-second-query` run 2: 15 (R-AP18, Q390, the second answer). |
| Revert check | 7 of 7 caught (test step) |
| Design answers | Q403, Q404, Q405 |
| Review change | The closure query timeout is one public constant, `ClosureIndex.query_timeout_s`, for both queries. |
| Moved out | Slice 206b: the whole-command parts (when the second query is sent, `--snapshot` in a command, the R-DT5 line and JSON `snapshot`, R-AD36). |

