# 039b `tln upgrade roc`: optional compiler downloads (U5)

Phase: P1. Status: done

Slice 039b is the plan row 039b of `PLAN-P1.md`. It needs 039, 039s and 037c (done). It adds the optional branch of R-NI4 to the free-nightly search of `tln upgrade` (R-UP6: "all other compiler downloads are optional probe downloads"): the opt-in (`--probe-downloads`, `--yes`), the cap R-DL6, the budget R-P5, the `skipped N compiler downloads` line (R-DL4), and the one prompt that asks for the required N and H only (U5, reading (c)).

The private reference has 115 added lines of code (without comments and empty lines): `PickOptional` 73, `NightlyPlan` 17, `PickLoop` 9, `InstallFlow` 7, `NightlyFlow` 4, `PickFlow` 4, `ResolveBase` 1. The row said about 120, and the limit is 450, so no split is needed. The reference is in `research/slice-039b-revert/reference/` (private: the code agent does not read it, TW18).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-NI4 (optional branch) | No download by default. The opt-in is `--probe-downloads` or `--yes`, inside the cap | L0 `nightlyplan.roc` expect 6. L2 `ur5-optional` runs 1 to 5, 9 |
| R-UP6 | N is the one download that the command names. Every other compiler download is optional | L0 expect 6 (N and H are never optional). L2 runs 1, 2, 11, 12 |
| R-DL1 | One answer for the command. The prompt shows the count and the size of the downloads that it asks | L2 runs 11, 12 (one `tty` call, one `ask` call, the prompt names N and H only) |
| R-DL2 | An optional download only widens a probe search: none is made when no pair needs a compiler | L2 runs 14, 15 (N passes: no download, no line) |
| R-DL4 | The line `skipped N compiler downloads (<size>), pass --probe-downloads`. In CI, N starts with no person (slice 039) | L2 runs 1, 4, 9, 11 (the line), runs 1, 2 (N starts in CI) |
| R-DL5 | `--yes` accepts an optional download. `--allow-downloads` and `TALON_AUTO_INSTALL` do not | L2 runs 3 (`--yes`), 4 (neither opts in) |
| R-DL6 | The cap `probe.max-toolchains`: 0 offers nothing, a failed try counts, the note when the cap dropped compilers | L2 runs 5, 6, 7, 8 |
| R-P5 | A download is for a probe that can start. A failed try gives no fact (R-P3) | L2 runs 13 (no room: no download), 7, 8 (R-P3) |
| R-LF4 (optional part) | `--dry-run` answers No to an optional download, also with `--probe-downloads` | L2 run 9 |
| R-J3, R-OUT4 | `data.downloads` counts the optional downloads (as slice 025 Q7) | L2 run 10 |
| R-HF1, R-NM8 | No terminal test for an optional download. `--yes` is yes to a prompt with the default No | L2 runs 3, 9 (no `tty` call), 11, 12 (one `tty` call) |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 039b"`)

| Name | Signature | File |
| --- | --- | --- |
| `NightlyPlan.optional` | `{ releases, req : Pin.Req, now, min_age, snapshot, nightly : Bool, held : Str, installed : List(Str) } -> { ids : List(Str), sizes : List({ id : Str, size : U64 }) }` (the same record as `pick`) | `cli/lib/NightlyPlan.roc:55` |
| `PickOptional.State` | `{ open : List(Str), got : List(Str), tried : U64, downloads : U64, dropped : U64 }` | `cli/lib/PickOptional.roc` |
| `PickOptional.Round` | `{ settings : Probe.Settings, sizes : List({ id : Str, size : U64 }), pairs : List(OracleBase.Pair) }` | same |
| `PickOptional.Stepped` | `{ state : PickOptional.State, pairs : List(OracleBase.Pair) }` | same |
| `PickOptional.step!` | `Fx, ResolveBase.Request, PickOptional.Round, PickOptional.State => Try(PickOptional.Stepped, Fail)` | same |

The new module `PickOptional` is in the package list of `cli/lib/main.roc`. The stub of `PickOptional.step!` has the full contract in its doc table (section 3). The wiring is not stubbed (section 11). `NightlyFlow` has a doc paragraph for the field `Plan.optional`.

## 3. The tested reading (the rules of the command)

| # | Rule | Source |
| --- | --- | --- |
| 1 | The optional compilers of a free nightly are the allowed ones (`Toolchain.range_allowed`) that are not older than H, not installed, not N and not H. Newest first, with one size row for each id. `NightlyPlan.optional` | R-UP6, R-C7, R-C9, R-CV2 |
| 2 | The search asks the compilers of slice 039 (installed, N, H) and the open optional ones. A `Pairs` round that has a pair on an open compiler calls `PickOptional.step!` after the budget check and before the compiler starts | R-DL2, R-P5 |
| 3 | No opt-in: all open compilers leave the search (the compilers that the round wanted, and the others). One line on stderr: `skipped K compiler downloads (<size>), pass --probe-downloads`, with K and the size of ALL open compilers inside the cap (`Consent.optional_round` over the open ids). No prompt, no `tty` call. The result is the best of the installed compilers, N and H | R-DL4, R-NI4 |
| 4 | Opt-in: for each id of the round that the cap allows (newest first): `RocInstall.offer!`, the line `downloading <id> (<size>)`, `RocInstall.install_offer!`. The compiler is a value of the next step, and its probes run. `.last-use` is written | R-NI4, R-DL5 |
| 5 | A failed download: a warning on stderr, no fact, the compiler leaves the search, the try counts for the cap | R-P3, R-DL6 |
| 6 | The cap: `left` is `probe.max-toolchains` less the tries. With no `left` the open compilers leave the search with no line. The ids that the cap dropped are counted. At the end of a successful run, when the cap is above 0 and some were dropped, the note `probe.max-toolchains is C and K compiler downloads were not made. Set probe.max-toolchains higher.` | R-DL6 |
| 7 | The budget: a download is made only for a probe that can start (`Units.budget` first). No room: the failure of the budget (exit 12), no download | R-P5 |
| 8 | `--dry-run` answers No (the opt-in is ignored): rule 3 | R-LF4 |
| 9 | `data.downloads` is the required downloads of the plan, the downloads of the ladder, and the optional downloads | R-J3 |
| 10 | The prompt of the run (slice 039) names N and H only. It does not change with the optional compilers (U5, reading (c)) | R-DL1, R-NI5, R-NI12 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/nightlyplan.roc` expect 6 (14 rows) | `NightlyPlan.optional`: nothing installed, min-release-age 0 (newest first, sizes), installed (also the other tag form), all installed, H is N, H newer than N, H old, H not in the list, range, switch off, snapshot, no asset, empty list | R-UP6 R-NI4 R-DL2 R-DL6 R-CV1 R-CV2 R-C7 R-C9 R-NS3 |
| L2 | `upgrade/ur5-optional` (new, 16 runs, entry `commands`) | The list below | R-NI4 R-DL1 R-DL2 R-DL4 R-DL5 R-DL6 R-UP6 R-P3 R-P5 R-LF4 R-J3 R-HF1 R-NM8 |

Deep case: one (`ur5-optional`, 16 runs, 16 projects, 16 homes). `Consent.optional_*` has its own unit rows (slice 037c), so no new `consent.roc` row. L0: one new expect (the file is 180 lines, about 0.4 s in `roc test`). L3: no new scenario (the L2 case covers the flow, and the real `roc` needs real downloads). The step l0 was 8.0 s in the green run.

The world of `ur5-optional` (`research/slice-039b-revert/gen-uo.py`): the compilers n08 (on PATH), h0 (H, the pin), n10, n11, n12 (N), n14 (hidden by min-release-age). The optional compilers are n11 and n10. ja fails on n12 only. jb fails on n12 and n11. jc passes on all. `upgrade roc` holds the packages, so only the compiler moves. The sizes are 74.0 MB (n10), 74.1 MB (n11), 74.2 MB (n12).

| # | Run | Shows | U5 |
| --- | --- | --- | --- |
| 1 | CI, `upgrade roc`, only H installed (ja) | N starts (one answer line). ja fails on n12: the search needs n11, no opt-in: `skipped 2 compiler downloads (148.1 MB), pass --probe-downloads`. Result H: `nothing to change`. No prompt, no `tty` | |
| 2 | CI, `--probe-downloads` (ja) | n11 is downloaded (answer line), probed (a pass), chosen. The pin moves to n11, not to N. The ladder runs on n11 | |
| 3 | `--yes`, a person, n10 installed (ja) | `--yes` is the opt-in: no prompt, N and n11 are downloaded. The pin moves to n11 | |
| 4 | CI, `--allow-downloads` and `TALON_AUTO_INSTALL=yes` (ja) | Neither opts in: the line of run 1, `nothing to change` | |
| 5 | CI, `probe.max-toolchains = 0`, `--probe-downloads` (ja) | No offer: no line, no download, no note | |
| 6 | cap 1, `--probe-downloads`, downloads work (jb) | n11 is downloaded, probed (a fail). n10 is wanted: the cap is spent. The note of the cap. Result H | |
| 7 | cap 1, every download fails (ja) | The warning for n11 (the try counts). n10 is wanted: no `curl` call, the note. Result H | |
| 8 | default cap, every download fails (ja) | The warning for n11 and for n10, once each: a failed compiler is not asked again. No note. Result H | |
| 9 | `--dry-run --probe-downloads`, a person (ja) | R-LF4: the line of run 1, no download, nothing written, no `tty` | |
| 10 | CI, `--probe-downloads --json` (ja) | n11 is chosen. `data.downloads` is 1, `data.pinned` is n11 | |
| 11 | a person, no opt-in, H and N missing (ja) | ONE prompt `Download 2 compilers, 148.1 MB: <N>, <H>? [Y/n]` (N and H only). Enter. N and H are downloaded. The search needs n11: the line `skipped 2 compiler downloads`, no second prompt. The pin stays | U5 |
| 12 | a person, `--probe-downloads`, H and N missing (ja) | The same prompt for N and H (one `tty`, one `ask`). Then n11 is downloaded with the answer line, no second prompt. The pin moves to n11 | U5 |
| 13 | CI, `probe.max = 2`, `--probe-downloads` (ja) | The 2 probes of the round on n12 spend the budget. n11 is wanted, no probe can start: no `curl` call, exit 12 with the budget text | |
| 14 | CI, `--probe-downloads` (jc passes on N) | No pair needs an optional compiler: no download, no line (R-DL2). The pin moves to N | |
| 15 | CI, no opt-in (jc) | The same with no line: the line shows only when the search needs a compiler that it cannot use | |
| 16 | CI, `--probe-downloads` (jb) | n11 is downloaded and fails, n10 is downloaded and passes: 2 downloads, the pin moves to n10 | |

U5 rows: runs 11 and 12 (and the doc of `NightlyFlow` and of `PickOptional`). Under reading (a) (one prompt lists the optional downloads too) or (b) (a second prompt) the prompt text of these two runs changes, and the person is asked about n11 and n10 in run 11. To change them, the code agent edits `DownloadAsk.required!` (the prompt) and `PickOptional.step!` (rows 3 and 4). The other runs have no person, or no prompt in any reading.

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| Skipped | `skipped 2 compiler downloads (148.1 MB), pass --probe-downloads` (`Consent.optional_skipped`, exists). Once for the run, on stderr, also with `--json`. K and the size are those of all open compilers inside the cap (Q2) | runs 1, 4, 9, 11 |
| Answer line | `downloading <id> (<size>)` (`Consent.optional_line`, exists) | runs 2, 3, 6, 7, 8, 10, 12, 16 |
| Failed download | `no download of <id>: <text of the failure>. The release has no fact and is not asked again.` (`Consent.optional_failed`, exists) | runs 7, 8 |
| Cap note | `probe.max-toolchains is 1 and 1 compiler download was not made. Set probe.max-toolchains higher.` (`Consent.optional_capped`, exists). At the end of a successful run, on stderr | runs 6, 7 |
| Budget | the failure of slice 036b (`tln: error[budget]: the probe budget is spent: probe.max is 2. Set probe.max higher.`), exit 12 | run 13 |
| `--json` | `data.downloads` counts the optional downloads. No new field | run 10 |
| The prompt | no new text. `Consent.use_download` names N and H only | runs 11, 12 |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | Lazy: a compiler is asked, and so downloaded or skipped, only when a pair needs it (`Pairs` round). The line shows only then. So the old U5 runs of slice 039 (`ur1-roc` runs 1, 2, 8, `ur2-consent`) do not change: N passes there | Eager: the line shows whenever optional compilers exist. Those runs would show `skipped 2 ...` (Q1) |
| D2 | The compilers are a part of the loop (`Pairs` rounds of `PickLoop`), not a phase 2 as in `ProbeSearch`. The solver picks the newest value, so the order is the order of the search (newest first) | A phase 2 after the search (the solver has no "second round") |
| D3 | A skip removes all open compilers at once, so the line shows once. K and the size count all of them inside the cap | One line for each round, with the compilers of the round only (Q2, Q3) |
| D4 | The cap keeps the newest optional compilers (the order of the ids). A compiler that was dropped is not asked again | The oldest first (nearest to H) |
| D5 | `--dry-run` ignores `--probe-downloads` and `--yes` for optional downloads (R-LF4 says "answers No") | The opt-in wins |
| D6 | A release with no asset for the host is never optional (R-CV2: not a candidate). `sizes` has a row for each id | A download that fails (the warning, a try of the cap) |
| D7 | The cap note shows at the end of a successful run (in `InstallFlow.finish!`, once), as `ProbeSearch` does for a successful search. A failed run (exit 12) has no note | A note at each drop |
| D8 | `data.downloads` is the sum of the required, ladder and optional downloads | Optional ones in a new field |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-NI4 for `add`, `update`, `install`, `verify` | No source of an optional download (slice 037d) |
| Out 2 | `--offline` with the opt-in | As slice 037c Out 5 (the offer fails for each compiler: a failed download) |
| Out 3 | R-RP4, the lag note for the nightly (Q4 of 039), `--no-probe` with a free nightly (Q5 of 039) | Slice 039c |
| Out 4 | A held move (second search) and a dropped tuple (the ladder, re-search) with optional compilers | The state is in `ResolveBase.Probed`, so it goes on. Slice 039c tests the held move with the nightly. The optional part is the same code |
| Out 5 | Bare `upgrade` (all packages free) with optional compilers | The same path as `upgrade roc` (`free` is `Ok`). Not tested again |
| Out 6 | The default compiler after an optional download, a `Present` after `offer!` | As slice 037c (Out 4, Out 6). The homes of the case set `default-roc` |

| Id | Question | Options (tested reading first) |
| --- | --- | --- |
| Q1 | When does the `skipped` line show? Slice 039 says that 039b adds it for the U5 rows | (a) Lazy (D1): only when a pair needs an optional compiler that cannot be used. Runs 1, 4, 9, 11. Old runs do not change. (b) Eager: whenever optional compilers exist (n10, n11 in `ur1-roc` runs 1, 2, 8 and all `ur2-consent` runs), also when N passes at once. The line would show in most runs of `upgrade roc` |
| Q2 | What do K and the size of the line count? | (a) All open compilers inside the cap (D3). (b) The compilers of the round that wanted one (slice 037c Q2 (a): run 1 would say `1 compiler download (74.1 MB)`) |
| Q3 | After a skip, does the search ask the other open compilers? | (a) No: the line shows once (D3). (b) Yes: one line for each round that needs a compiler |
| Q4 | Which compilers does the cap keep? | (a) The newest (D4). (b) The nearest to H. Runs 6, 7 show it: with cap 1 the first download is n11 |
| Q5 | U5 for the free nightly | Reading (c) is tested (runs 11, 12). The design text R-DL1 says: "A download that is not in the prompt does not start". With (c) the flag is the consent for an optional download, and the prompt does not list it |

Design gaps (for the human, no design file is changed here):

| Gap | Where |
| --- | --- |
| R-DL1 says that a download that is not in the prompt does not start. Under reading (c) an optional download starts with a flag and no prompt | CLI R-DL1, R-NI4, U5 |
| R-DL4 gives the line for the non-interactive mode. Slice 037c and this slice print it in both modes (U5 (c)) | CLI R-DL4 |
| R-DL1 and R-DL6 say nothing about the count of the line for a search that goes on after a skip (Q2, Q3) | CLI R-DL1, R-DL4 |
| R-LF4 says that `--dry-run` answers No to optional downloads, but not what the line shows. Run 9 shows the line | Resolution 12, R-LF4 |

## 8. Changed old tests (TW21)

None. The reference passes all old L2 (97) and L3 cases with no change of an expected file, because the line shows only when a pair needs an optional compiler (D1), and no old run has such a pair. `ug1-flow`, `ug2-lag`, `ur1-roc`, `ur2-consent`, `ur3-list`, `ur4-candidate` are the same. `tests/unit/nightlyplan.roc` has one new expect (6), and the old 5 are the same.

## 9. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Red (the stubs, `research/slice-039b-revert/red-run.log`) | l0 FAIL: `nightlyplan.roc` expect 6 of 6: `todo: slice 039b` (the 5 old expects pass). l2 FAIL: `upgrade/ur5-optional` (wrong output: no `skipped` line, no optional download, the pin does not move to n11 or n10, `data.downloads`). 97 other L2 cases pass. check, fmt, l3, selftest, l1 pass |
| Green (the reference, `reference-run.log`) | all pass: check 1.4, fmt 0.2, l0 8.0, l2 3.1, l3 10.8, selftest 11.2, l1 28.8 (budgets 10, 5, 10, 30, 60, 20, 60) |
| Baseline before this slice | all pass: check 1.1, fmt 0.2, l0 8.5, l2 5.5, l3 10.0, selftest 11.3, l1 18.3 |

Revert check (`research/slice-039b-revert/mutate.py`, the reference in the tree, filtered runs only, `mutate.log`): 10 mutations, 10 caught. The run that shows each rule is named in the table; the log shows the case, not the run. O5 and O10 were first written wrong (O10 did not compile: an unused variable, so it uses `or Bool.True`).

| Id | Mutation | Caught by |
| --- | --- | --- |
| O1 | a skip removes only the compilers that the round wanted: the line shows again | `ur5-optional` run 1 |
| O2 | `--allow-downloads` is an opt-in | `ur5-optional` run 4 |
| O3 | `--dry-run` does not answer No | `ur5-optional` run 9 |
| O4 | a failed try does not count for the cap | `ur5-optional` run 7 |
| O5 | the download is made before the budget check | `ur5-optional` run 13 |
| O6 | the cap does not count the tries of earlier rounds | `ur5-optional` run 6 |
| O7 | `data.downloads` does not count the optional downloads | `ur5-optional` run 10 |
| O8 | with the opt-in every open compiler is downloaded, also when no pair needs it | `ur5-optional` (run 14 shows it) |
| O9 | a compiler that the search downloaded is no value of the compiler slot (a bug that the reference had at first) | `ur5-optional` run 2 |
| O10 | an installed compiler is optional | `nightlyplan.roc` expect 6 |

## 10. Compiler and tool limits met

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | `roc check` exits 2 on a warning, so a mutation with an unused variable did not compile (O10) | the mutation | `or Bool.True` |
| C2 | The tree diff of an L2 case covers `home` and `project` only. The homes of this case are `home1` to `home16` | the installed compilers are not in `tree.diff` | the `rename` calls of `calls.log` show them |

## 11. Notes for the code agent

| Topic | Note |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/upgrade/ur5-optional/rules` has the text of each run. `research/slice-039b-revert/run-log.py <case> <n>` prints the calls of one run |
| `NightlyFlow` | `Plan` gets `optional : { ids, sizes }`. `known!` calls `NightlyPlan.optional` with the same facts as `pick` (the installed list before the downloads of step 4). The records with `free: Err(Held)` get `optional: { ids: [], sizes: [] }` |
| `PickFlow` | `prepare!` gets a parameter `optional` (after `free`) and puts it in `PickLoop.Setup` (`optional : { ids, sizes }`). `pick!` gives empty lists |
| `ResolveBase.Probed` | a new field `optional : { open, got, tried, downloads, dropped }` (the type of `PickOptional.State`: write the record, `ResolveBase` cannot import `PickOptional`, which imports `ResolveBase`). `PickLoop.start` sets `open` to `setup.optional.ids`. The state goes on with `probed` into a second search and a re-search of the ladder |
| `PickLoop.run!` | the values of the compiler slot are `setup.free` plus `probed.optional.open` plus `probed.optional.got`. The compilers that were downloaded must stay values (a mutation, O9, removes them) |
| `PickLoop.probe_round!` | after the budget checks and BEFORE `begin!`: `PickOptional.step!` with `pairs.take_first(budget.run)`. When `Stepped.pairs` is empty: return `Ok({ ..probed, optional: state })` with no probe and no count change (the next step asks again). Else `begin!`, and the started record has `installed` plus `state.got`, so `Launch.program!` and `Launch.touch!` work for a compiler that the search installed. The probes run on `Stepped.pairs` |
| `PickOptional.step!` | the doc table of the stub is the contract. Reuse `Consent.optional_round`, `Consent.optional_want` and the texts of `Consent`. The fetch of one compiler is the one of `ProbeSearch.fetch!` and `fetch_one!` (private there): move it into one shared function (a new module or `RocInstall`) and use it from both |
| `InstallFlow.finish!` | `ran.downloads` adds `probed.optional.downloads`. Before the end, when `probe.max-toolchains` (`ResolveBase.probe_settings`) is above 0 and `probed.optional.dropped` is above 0: `fx.err!` of `Consent.optional_capped` (once: `finish!` runs again only after a failure) |
| Calls | The order of the calls is fixed by `calls.log` (a download: `platform`, `db_query pinned`, `random`, `programs curl wget`, `make_dirs` ... `rename`; then `.last-use` for the new compiler and H, then the probes) |
| Size | The reference has 115 lines of code (section above). `PickLoop.roc` stays near 316 lines |

## 12. Files

| File | State |
| --- | --- |
| `docs/slices/039b-upgrade-roc-downloads.md` | new (this file) |
| `cli/lib/PickOptional.roc` | new, stub (37 lines) |
| `cli/lib/NightlyPlan.roc` | stub of `optional` (doc and `crash`) |
| `cli/lib/NightlyFlow.roc`, `cli/lib/main.roc` | doc paragraph, the module list |
| `tests/unit/nightlyplan.roc` | expect 6 (+40 lines) |
| `tests/commands/cases/upgrade/ur5-optional/` | new (16 runs) |
| `research/slice-039b-revert/` | `before/` (with `NEW.txt`), `stubs/`, `gen-uo.py`, `ur5-rules.txt`, `mutate.py`, `mutate.log`, `run-log.py`, `bk.sh`, `red-run.log`, `reference-run.log` |

## Review (manager, 2026-10-24)

Accepted. Status: code.

| Item | Answer |
| --- | --- |
| Q1 | Lazy (D1) accepted: the line shows only when a pair needs an optional compiler |
| Q2 | Accepted: K and the size count all open compilers inside the cap. It differs from 037c Q2 (next round only) because here a skip removes all open compilers at once (D3), so the count is the whole skip |
| Q3 | Accepted: a skip ends all optional asking for the command |
| Q4 | Accepted: the cap keeps the newest compilers (`upgrade` wants the newest) |
| Q5 | U5 stays open. Reading (c) is tested, with the marks (runs 11 and 12) |
| D1 to D8 | Accepted (D5: `--dry-run` makes no optional download) |
| Gaps 1 to 4 | Recorded by the manager in `PLAN-P1.md` 5b for the next design edit |
| Section 11 | Accepted, including one shared fetch function for `ProbeSearch` and `PickOptional` |

After the review the test agent deleted `research/slice-039b-revert/reference/` (and `reference.sha256`, `reference-run.log` stays). The red state is in `red-run.log`.

## Code result (code agent)

| Item | Result |
| --- | --- |
| `scripts/test.sh` | exit 0: check 1.8, fmt 0.1, l0 8.0, l2 2.9, l3 10.9, selftest 11.1, l1 30.0 s. `OPT=speed`: all pass, l2 152.0 s (over budget, the known reason) |
| Changed tests | none (no dispute rows) |
| Questions (TW17) | none |

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/PickOptional.roc` | 95 | `step!`, `left_out`, `fetch!` (the rows 1 to 4 of the doc table) |
| `cli/lib/NightlyPlan.roc` | 96 | `optional` |
| `cli/lib/RocInstall.roc` | 407 | new `fetch_optional!`: the one shared fetch (offer, answer line, install) |
| `cli/lib/ProbeSearch.roc` | 221 | `fetch!` calls `RocInstall.fetch_optional!`; the private `fetch_one!` is removed |
| `cli/lib/PickLoop.roc` | 318 | `Setup.optional`, `start`, the values of the compiler slot, `PickOptional.step!` in `probe_round!` |
| `cli/lib/PickFlow.roc` | 230 | `prepare!` parameter `optional`; `pick!` gives `no_optional` |
| `cli/lib/ResolveBase.roc` | 352 | `Probed.optional` |
| `cli/lib/NightlyFlow.roc` | 150 | `Plan.optional` (`NightlyPlan.optional` in `known!`) |
| `cli/lib/InstallFlow.roc` | 216 | `plan.optional` to `prepare!`; `data.downloads` adds `probed.optional.downloads`; the cap note |

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Place of the shared fetch | `RocInstall.fetch_optional!` (it has `offer!` and `install_offer!`, and imports `Consent`) | A new module (one more file for 10 lines) |
| `Nothing` case (cap 0 or spent) | all open compilers leave, `dropped` grows by `plan.dropped.len()` (the doc table row 2) | none |
| `Skip` case | `dropped` does not grow (the cap did not drop them) | count them as dropped |
| Compilers not wanted in a `Download` round | stay open (asked in a later round) | leave with the round |
| Cap note place | in `InstallFlow.finish!` before the outcome, after the write (no failure can follow) | at the start of `finish!` (it would print again after a failed ladder) |

## Verify results (code agent)

Revert check: 10 mutations, 10 caught (`research/slice-039b-revert/agent-mutate.py`, `agent-mutate.log`, `agent-results.md`). Code copy: `code-final/`, `code-final.sha256`. Final compare: SAME.

| Id | Mutation | Test that failed |
| --- | --- | --- |
| A1 | a skip removes only the wanted compilers | L2 `ur5-optional` |
| A2 | `--allow-downloads` is an opt-in | L2 `ur5-optional` |
| A3 | `--dry-run` does not answer No | L2 `ur5-optional` |
| A4 | a failed try does not count for the cap | L2 `ur5-optional` |
| A5 | the download is made before the budget check | L2 `ur5-optional` |
| A6 | the cap does not count the tries of earlier rounds | L2 `ur5-optional` |
| A7 | `data.downloads` does not count the optional downloads | L2 `ur5-optional` |
| A8 | an installed optional compiler is no value of the slot | L2 `ur5-optional` |
| A9 | the cap note shows with cap 0 | L2 `ur5-optional` |
| A10 | an installed compiler is optional | L0 `nightlyplan.roc` expect 6 |

Compiler limits met: none new.

## Close (manager, 2026-10-24)

The code decisions are accepted (the shared fetch is `RocInstall.fetch_optional!`, used by ProbeSearch and PickOptional; open compilers stay open across rounds; the cap note prints after the write). The revert check caught 10 of 10 targeted mutations, so no gap rows are needed. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 7.8 s). U5 stays open for the user. Status: done.
