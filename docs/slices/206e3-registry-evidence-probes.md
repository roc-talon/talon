# 206e3 Registry evidence in probes and why

Phase: P2 (CLI client). Status: done (closed 2026-11-03). Open: G-C134, G-C135 (plan row 206e3b).

Plan row 206e3 of `PLAN-P2-CLI.md`. Sub-slice 3 of the 206e split. It puts the pure evidence of slice 209 (`Matrix`, `PairOrder.order_shared`, `Evidence.of_all`, `Evidence.differ`) into the command code of a registry run (the query step of 206b, 206d, 206e, 206e2, 206e2b). From 206e2 plan note P1: the facts of the `nightly range` column of `tln outdated`.

## Rules

R-EF1 (rank 2, rank 6), R-EF3, R-EP15, R-AL4 (Resolution 3, 4, 5). As used: R-EP2, R-EP3, R-EP4, R-EP6, R-EP8, R-EP9, R-EP12, R-EP13, R-UM1, R-EF2, R-SE5, R-P5, R-UP7, R-PB3, R-CM6, R-AP17, R-E7, Design Q393, Q395.

## Scope

| In | Out (where) |
| --- | --- |
| `PickLoop.wide!` with an `Answer` index: the rank 2 facts of the answer (`Matrix.rows` of `runs` and `nearest` on D, `Matrix.real` after the local rows), the rank 2 fails as unknown sets (`Matrix.unknown_sets`, Q393), the inferred facts with the epochs of the answer (`Matrix.found`) | `tln why` with the registry evidence: question Q1 (stopped) |
| `PickLoop.round!` (the lookup of a probe round) with an `Answer` index: the same rank 2 facts for the keys that it looks up, after the db (rank 1 wins) | The R-EF3 note in the output of the resolve commands: question Q2 (stopped) |
| `PickLoop.hinted!` with an `Answer` index: `PairOrder.order_shared` with the `hints` of the answer (rank 6, Q395) | `tln probe --range` with a registry: `probe` keeps the P0 refusal (`Opts.reads_registry`), and `ProbeFlow` is in slice 217. `ProbeSearch` passes `epochs: []` |
| `ProbeRange.Input.epochs` (new field): the epochs of D that the caller has; `Outdated.range_of` passes them | The unit facts of the ladder (`Ladder`, `verify`): plan note P1 |
| `tln outdated` with a registry: the `nightly range` column from the local rows, the `runs` and `nearest` of the answer (R-EP12) and its epochs (R-EP15) | The index notes, the share hooks: 206e4 |
| `PickLoop.read_all!` with an `Answer` index | Already done in slice 206 (`Gather.facts!`, a `Record` gives the fact with no read) and covered by `registry/al8-closure-facts` and every registry resolve case. No new test |

## Flow as read

### A resolve with a registry (`update`, `upgrade`, `install`, `verify` search)

| Step | Call | Rule |
| --- | --- | --- |
| 1 | The query (206b to 206e2b). `request.index` is `Answer(a)` | R-AL2 |
| 2 | `wide!` (D read: a free nightly, a movable compiler, `--no-probe`, a fail with a probe cause): `Facts.load!` of the keys of the slots on D (unchanged), then the facts: the local rows first, then one rank 2 fact for each key with no local row (`Matrix.real`, a `bot` row wins). A rank 2 `fail` is a check with an unknown set (`source: Inferred`, `modules: []`, Q393). The inferred facts: `Matrix.found` with D, the `epochs` of the answer and the facts (rank 1 and rank 2) | R-EF1, R-EF3, R-EP12, R-EP15, R-EP6, Q393 |
| 3 | `round!` lookup (a key that the command did not look up): `Facts.load!` (unchanged), then the rank 2 facts of these keys, as in step 2. A pair with a rank 2 `pass` needs no probe. A pair with a rank 2 `fail` is probed (it does not decide alone, R-EP8) | R-EF1, R-EF3, R-AL4, Q393 |
| 4 | A round that the budget cuts: `hinted!` orders the pairs with `PairOrder.order_shared` (rank 4, rank 6 `pass`, no hint, rank 6 `fail`) | R-AL4, R-P5, Q395 |
| 5 | The rest (the ladder, the output) unchanged. A hint is never a fact (R-SE5); the whole-app check and the build still run (R-EF2) | R-EF2 |

### `tln outdated` with a registry

After the query (206e2) and the facts of step 7 (`Facts.load!`, unchanged): the facts of a row are `Matrix.real` of the local rows and `Matrix.rows` of the answer on D; `epochs` are `Matrix.intervals` (D, the `epochs` of the answer, these facts). `Outdated.range_of` gives them to `ProbeRange.found`.

## Reading that the tests fix

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Where rank 2 joins rank 1 | At the db lookup of the same keys (in `wide!` and in `round!`), after the db, so a rank 1 row wins (R-EF3: the lowest rank number). The db is asked for the same keys as with `direct` (`facts=12`, `facts=3` in the cases) |
| 2 | A run on the held compiler with no list read (`ef1-rank2-held`) | The run holds H when H is between its ends in R-NS1 order (the dates of the tags, as `Matrix.rows` with D = `[H]`). The command reads no compiler list for it: no read happens in that run before, and the design asks for none (see Doubt D1) |
| 3 | A rank 2 `fail` of a candidate | A unit probe of the pair runs (Q393). A rank 2 `pass` gives no probe |
| 4 | `ProbeRange.Input.epochs` | `List(Epochs.Interval)`: a release of D in no interval is an epoch of its own (R-EP4), so `[]` is today's P1 result. The inferred cells are `Epochs.infer` with these epochs (case (a) of R-EP6 in an epoch) |
| 5 | Case (b) of R-EP3 in `outdated` | Inside an epoch of the answer, 2 hashes that change at one transition split the epoch (`Matrix.intervals`); `pb3-outdated-runs` has it (parser and pf change from 10-12 to 10-13) |
| 6 | The download of N in `ep15-epoch-no-probe` | Unchanged behaviour of `NightlyFlow` (the offer of N comes before the query); the test does not change it |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ProberangeTest.roc` (driver `l0-7.roc`), 1 new expect, 6 rows: no epoch, an epoch that makes both ends real, an epoch and a pass at its top, an epoch with a pass and a fail (no inference), `step` with no epoch (a probe round) and with the epoch (no probe) | R-EP15, R-EP4, R-EP6, R-EP13, R-PB3 |
| L0 | `ProberangeTest`, `OutdatedTest`: the existing calls get `epochs: []` (no expected value changed) | |
| L2 | `registry/ef1-rank2-free` (new, 1 run): run 1 of `cv1-upgrade-free` with a `bot` `pass` of the 3 header hashes on N: no unit probe round, `3 probes` (was 6) | R-EF1, R-EP12, R-EF2, R-AL4 |
| L2 | `registry/ef1-rank2-held` (new, 1 run): `update` on H with a `bot` `pass` run of json 2.2.0 from 10-12 to 10-16: the round probes only parser 1.2.0 and pf 0.1.1 (`probes 2`), after the db query of the 3 keys | R-EF1, R-EP12, R-EF3, R-AL4 |
| L2 | `registry/ef3-bot-author` (new, 1 run): parser `author` `fail` then `bot` `pass` (no probe), json `bot` `fail` and `author` `pass` (a probe, Q393), pf no row (a probe): `probes 2` (json, pf); N chosen, `5 probes` | R-EF3, R-EF1, R-EP8, R-UM1, Q393 |
| L2 | `registry/ep15-epoch-no-probe` (new, 1 run): `upgrade roc --no-probe`, the epoch 10-12 .. 10-16 and a `bot` `fail` of json 2.0.0 on 10-12 only: case (a) infers a fail on N, so roc stays H with the note of slice 039c (`json 2.0.0 fails the unit check on N (inferred)`) and `nothing to change` | R-EP15, R-EP6, R-EP9, R-EP2, R-EP3, R-EP4, R-EF3, Q393 |
| L2 | `registry/al4-shared-order` (new, 1 run): `probe.max = 2`, hints on N: json `fail` (0, 2, 1), parser `pass` (3, 1, 0), pf none. The cut round runs parser and pf, not json; exit 12 with `1 unit check did not run` | R-AL4, R-EF1, R-EF3, R-SE5, R-P5, R-UP7, Q395 |
| L2 | `registry/pb3-outdated-runs` (new, 2 runs): `outdated` and `outdated --json` with runs, an epoch and one local row: json `10-11 .. 10-12?` (case (a), then the case (b) split), parser `10-11 .. 10-12` (the `bot` row wins on 10-12), pf `10-11 .. 10-12` (the local `fail` on 10-13 wins over a `bot` `pass`) | R-PB3, R-CM6, R-EP12, R-EP15, R-EP3, R-EP6, R-EF3, R-AP17, R-E7 |

The fixtures are made by `research/slice-206e3-revert/mkcases.py` (from `cv1-upgrade-free` and `cv1-outdated-query`; each case has a `rules` file with the detail). The expect files came from a private reference (a copy of `cli/lib` and `tests/commands` under `research/slice-206e3-revert/ref/` with its own L2 binary, `L2BIN`), then each stdout, stderr, exit, the probe and db lines of `calls.log` and the `compat.tsv` part of `tree.diff` were read against the rules. The reference is deleted.

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `l0` | `ProberangeTest.roc:92` (the new expect: wrong value, `ProbeRange` ignores `epochs`). The other fails are slice 217 (`ProbeshareTest`, `ProbecmdTest:45`) |
| `l2` | 349 pass, 14 fail: the 6 new cases, and slice 217 (`probe/ps1` to `ps7`, `probe/pc1-targets`: the `--share` line) |
| `ef1-rank2-free`, `ef3-bot-author` | The unit round has 3 probes (no rank 2 fact) |
| `ef1-rank2-held` | The round has 3 probes (json 2.2.0 too) |
| `ep15-epoch-no-probe` | N is fit (no matrix): roc moves to N |
| `al4-shared-order` | `PairOrder.order`: the probes are json and parser |
| `pb3-outdated-runs` | Every range is `none known` (facts from `compat.db` only) or the local row only |
| `l3` | Only `fx/ps1-real-fx-facts-of` (slice 217) |

## Expected exits (read, TW21)

| Case | Exit | Reason |
| --- | --- | --- |
| `ef1-rank2-free` | 0 | Dry run; stderr the download line of N (as `cv1-upgrade-free`) |
| `ef1-rank2-held` | 0 | Dry run; no stderr |
| `ef3-bot-author` | 0 | Dry run; stderr the download line of N |
| `ep15-epoch-no-probe` | 0 | `nothing to change`; stderr the download line of N (the plan offers N before the query, unchanged) |
| `al4-shared-order` | 12 | R-P5, R-UP7: `tln: error[budget]: the probe budget is spent: probe.max is 2 and 1 unit check did not run. ...`, the facts of the 2 probes saved (`db_write facts=2`) |
| `pb3-outdated-runs` | 0, 0 | R-E7 |

## Revert check

`research/slice-206e3-revert/`: `before/` (the 4 code files and the 2 test files before the stubs), `mkcases.py`, `mutate.sh` (it needs the deleted reference), `results.txt`. 8 mutations on the reference, each caught (filtered L2 runs only):

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `hinted!`: `PairOrder.order` with an answer | `al4-shared-order` |
| M2 | A rank 2 `fail` decides as a real check (no unknown set, Q393) | `ef3-bot-author` |
| M3 | `wide!`: `Epochs.epochs` in place of `Matrix.found` | `ep15-epoch-no-probe` |
| M4 | `round!`: no rank 2 fact | `ef1-rank2-held` |
| M5 | `outdated`: rank 2 over rank 1 | `pb3-outdated-runs` |
| M6 | `outdated`: no epochs | `pb3-outdated-runs` |
| M7 | `outdated`: no runs | `pb3-outdated-runs` |
| M8 | `wide!`: no rank 2 fact | `ef1-rank2-free`, `ef3-bot-author`, `ep15-epoch-no-probe` |

## Code (stubs of the test step)

| File | Change |
| --- | --- |
| `cli/lib/ProbeRange.roc` | `Input` gains `epochs : List(Epochs.Interval)` (doc: todo slice 206e3). The body is unchanged: it does not read the field |
| `cli/lib/ProbeSearch.roc` | The 3 inputs get `epochs: []` |
| `cli/lib/Outdated.roc` | `range_of` takes `epochs` and passes them (import `Epochs`) |
| `cli/lib/OutdatedFlow.roc` | `range_of` gets `epochs: []` |

The command code (`PickLoop.wide!`, `round!`, `hinted!`, `OutdatedFlow`, `ProbeRange.world_of`) is for the code agent.

## Output (proposed, R-OUT2)

No new text and no new `--json` field. The cases use the texts of slices 039c (the inferred note), 040 (`nightly range`, `nightly_range`), 036b (the budget) and 206e.

## Out of scope

`tln why` (Q1), the R-EF3 note in resolve commands (Q2), `tln probe --range` with a registry, the ladder unit facts (P1), the index notes and share hooks (206e4).

## Questions (stop until answered)

Manager (2026-11-03): Q1 and Q2 went to TalonRegistry as G-C132 and G-C133. Plan notes P1 and P2 are plan row 206e3b. The code step starts for the tested parts.

| # | Question |
| --- | --- |
| Q1 | `tln why` with a registry (R-CM7, R-EF1 ranks 2 and 6, R-EF3 "`--json` gives both"): where does `why` get the rank 2 and rank 6 evidence? `why` resolves nothing (R-AL9: "no variable is free (`install --frozen`, `list`, `why`)"), R-DI1 names no query for `why`, R-DI8 says `why` shows rank 4 "from these files only", and R-AP4 (`GET /v1/artifacts/{hash}/compat`, which has `{runs, hints}`) is read "only by the compat bot" (Registry R-AP4 note, Q192). Options: (a) `why` sends the closure query of R-DI1 for the ladder commands (no `groups`, the header `hashes`, the held window), and `EvidenceFlow.blocks!` uses `Evidence.of_all` and `differ` with its answer; (b) `why` reads `GET /v1/artifacts/{hash}/compat` for each shown hash (a change of the R-AP4 note); (c) `why` makes no registry call and shows ranks 1, 3, 4 only (then the rank 2 and 6 lines of slice 209 appear in no command). Today `why --registry <url>` keeps the P0 refusal (`Opts.reads_registry`). No test written |
| Answer Q1 | Answered (Design Q499, CLI R-DI1): (a). Tests added in round 2 (below). Test change: `EvidenceFlow.blocks!` for `why` gets the closure answer (the query with no `groups`, the header `hashes`, the held window); `Opts.reads_registry` no longer refuses `--registry`; L2 `why` with a registry: one `closure` request, ranks 2 and 6 in the block, both rows in `--json`; `why --offline` and `direct`: no request, ranks 1, 3, 4 |
| Q2 | The R-EF3 note in the resolve commands ("Talon prints a note when a `bot` row and an `author` row of one pair have different results"): which pairs get a note? (a) each pair of the answer with a `bot` and an `author` row that differ (each compiler of E: one note per compiler of a run, can be many); (b) the pairs whose fact the command used (the checks of the solver); (c) the pairs of the chosen tuple on the chosen compiler (R-AL7 "the evidence for each choice"). Also: does the note go to stdout with the other notes and to `data.notes` (as the R-AL7 notes), and does it name the package (the text of slice 209 names only the compiler, because in `why` the block names the package)? The text is a TW24 proposal once the pairs are known: `note: <name> <version>: the bot and the author rows differ on <compiler>: bot <result>, author <result>`. No test written |
| Answer Q2 | Answered (Design Q500, Resolution R-EF3): (c). Tests added in round 2 (below). Test change: the note is made for the pairs of the chosen tuple on the compiler of the run only; an L2 run with a differing pair in the tuple (one note, stdout and `data.notes`) and one outside the tuple or on another compiler of E (no note); the text stays |
| Answer notes 3, 4 | Answered (Design Q501, Q502): `verify` prints the R-EF3 note (the shared finish step; one L2 run with a differing pair in the tuple and `verify`); `why` in a workspace with different `roc:` pins sends no `compilers` member and each member block shows the facts of its pin (L2 `why` with 2 members and 2 pins: one request, no `compilers`, two blocks). With equal pins the window is the nightly of the workspace |

## Round 2 (Design Q499, Q500)

| Layer | Case | Rules |
| --- | --- | --- |
| L2 | `registry/cm7-why-registry` (new, 4 runs, on the project of `cv1-held-offer`: pin H = 2026-10-13, packages in the cache, registry in `config.toml`). Answer: json 2.0.0 on H `bot` `fail` (`error: e1`) and `author` `pass`; rank 6 counts 5, 1, 0. Run 1: the guard (kept answers), one POST with `groups` [], the 3 header hashes and `compilers` H .. H, then the block: `* 2 bot: fail`, `2 author: pass`, `6 shared: pass (5 pass, 1 fail, 0 crash)` and the note `the bot and the author rows differ on H: bot fail, author pass`. Run 2: `--json`: both rank 2 items (`error_digest` `"error: e1"` and `null`), the rank 6 item with its counts, the note in `notes`. Run 3: `--registry direct`: no request, no evidence line. Run 4: `--offline`: no request, no evidence line | R-CM7, R-DI1, R-EF1, R-EF3, R-AP17, R-AP58, R-RG4, R-AL8, Q499, Q394 |
| L2 | `registry/ef3-note-tuple` (new, 2 runs, the world of `ef1-rank2-held`: `update` on H = 2026-10-14). Differing `bot` and `author` rows on 3 pairs: (json 2.2.0, H) in the tuple (`bot` `pass`, `author` `fail`), (parser 1.2.0, N) another compiler of E, (parser 1.0.0, H) not in the tuple. One note only: `note: acme/json 2.2.0: the bot and the author rows differ on nightly-2026-10-14-38a3029: bot pass, author fail`, after the platform note, before `check:`. Run 2: `--json`, the note is the 2nd item of `data.notes` | R-EF3, R-AL7, R-EF1, Q500 |

Readings that the round 2 tests fix:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | The order in `why` | The query comes after the load and before the walk (as `verify`), so the walk takes the header facts from the answer (R-AL8 source 2): no read of `packages/<hash>/main.roc` in a registry run |
| 2 | The rank 3 pin in `why` with an answer | The `roc_pin` of the artifact record (R-AL8 source 2: the answer before the file). No read of the package `main.roc` for the pin. Rank 4 stays the cache file (R-DI8) |
| 3 | The window of `why` | `Held(H)` with the pin of the member (`Pin.Decision.held`), as `verify` |
| 4 | `--offline` with a registry | No query, no request; the walk reads the cache (as `direct`) |
| 5 | The place of the resolve note | After the other notes before the ladder (`note: platform changes`), so `data.notes` has it after them. Only pairs of the chosen variables on the compiler of the run (the held H here) |
| 6 | Run 2 of `ef3-note-tuple` | `build: skipped (recorded pass)` and 2 probes: run 1 (a dry run) saved its probe facts (R-PP4). The note is the same |

Not tested: `why --registry <url>` (Q499 accepts it): it needs `Opts.reads_registry`, which the slice 217 test agent edits now. The cases use `registry` in `config.toml`. A run with `--registry http://127.0.0.1:9` can be added to `cm7-why-registry` after 217.

Expected exits (read): `cm7-why-registry` 0, 0, 0, 0 (no stderr); `ef3-note-tuple` 0, 0 (stderr: the text summary of the `--json` run, as every `--json` resolve).

Red (round 2): `cm7-why-registry` fails (no query: the walk reads the packages and the block has no rank 2 or 6 line); `ef3-note-tuple` fails (no note in stdout and in `data.notes`). `scripts/test.sh check fmt` pass. No stub: no new function (the code is in `Why`, `Ls`, `EvidenceFlow`, `InstallFlow`).

Mutations (round 2, `research/slice-206e3-revert/mutate2.sh` on a new private reference, now deleted; `results.txt`): M9 `why` sends no query, M12 `why` reads no rank 2 row, M13 no R-EF3 note in `why`: caught by `cm7-why-registry`. M10 the note also for another compiler of E: caught by `ef3-note-tuple`. M11 (no note in the resolve) did not build in the reference; it is the red state above.

## Plan notes (for the manager, not design questions)

| # | Point |
| --- | --- |
| P1 | R-DI1 says that `verify` and the other ladder commands send the query so that "the evidence ... come[s] from one answer". The ladder reads its unit facts with its own `Facts.load!` (`Ladder.run!`, `verify!`), not through `PickLoop`, so a rank 2 fact does not reach `verify` or ladder step 1. Not in the plan row. A follow-up row (or part of 206e4) |
| P2 | The second answer of a held move (R-SP24, `Probed.second`): its `runs`, `epochs` and `hints` are evidence too. The tests use the first answer only (`request.index`). No case covers the second search |

## Doubts (no test)

| # | Doubt |
| --- | --- |
| D1 | Reading 2: if the code agent reads the registry list in `round!` to get D for `Matrix.rows` (with `ResolveBase.list_first`, the 206e2b note), `ef1-rank2-held` gets a `GET /v1/toolchains` and its `calls.log` changes. The design (R-EP12, R-AP17 run) does not need D for a run whose ends are tags; the case pins "no read" |
| D2 | `ep15-epoch-no-probe` downloads N before the query and then does not use N. That is the flow of `NightlyFlow` today (the offer before the query), not of this slice |
| D3 | No PickLoop case has a rank 1 row against a rank 2 row (only `pb3-outdated-runs` has it). `Matrix.real` (L0, slice 209) has the precedence; the wiring is reading 1 |

## Code

| File | Change |
| --- | --- |
| `cli/lib/ProbeRange.roc` | `world_of`: the inferred cells are `Epochs.infer` with `Input.epochs` (was `Epochs.epochs`); the todo note removed |
| `cli/lib/OutdatedFlow.roc` | Step 7: new private `evidence_of`: with an `Answer` index, `Matrix.real` of the local rows and `Matrix.rows` of the answer on D, and `Matrix.intervals` with the answer `epochs`; `range_of` gets both. Else the local rows and `[]` |
| `cli/lib/PickLoop.roc` | `wide!`: the rank 2 facts after `Facts.load!` (`rank2_of`), `Matrix.found` with the answer epochs (`epochs_of`) and the facts of rank 1 and 2. `round!`: `rank2_of` of the looked-up keys on the compilers of the pairs (`round_domain`: the time of the kept list when read, else the tag date; no list read, D1). `hinted!`: `PairOrder.order_shared` with the answer `hints`. New public `differ_notes` (Q500). New private `rank2_of`, `epochs_of`, `round_domain` |
| `cli/lib/InstallFlow.roc` | `finish!`: `PickLoop.differ_notes` of the chosen tuple on the compiler of the run (`after.nightly`, else the held compiler), printed after the platform notes, and in `notes` after them (Q500) |
| `cli/lib/Ls.roc` | `walk_full!` is split in `load_full!` (steps 2 to 7) and `walk_loaded!` (step 8). Same calls |
| `cli/lib/Why.roc` | `run!` calls the new private `walk_indexed!`: with a registry setting (`InstallFlow.setting_of`), `PickFlow.report_query!` with no group and the window `Held(<first member pin>)`, before the walk. `direct` and `--offline`: no query (Q499) |
| `cli/lib/EvidenceFlow.roc` | With an `Answer` index: the pin of a hash in the answer is its `roc_pin` (new private `pins_with!`, no file read; other hashes read the file), the lines are `Evidence.of_all` (rows of the answer on the compiler, `hints`), the notes get `Evidence.differ` after the unit-fail notes (Q499) |

Review notes:

| # | Note |
| --- | --- |
| 1 | Q393 wiring: `OracleBase.Compat` has no place for the registry rows (its shape is fixed by the L0 tests of `Oracle*`), so `Matrix.unknown_sets` is not called. `rank2_of` puts a rank 2 `fail` into `probed.inferred` as `{ outcome: Fail, modules: [], from: [] }`; `OracleDomain.checks` makes it a check with `source: Inferred`, `modules: []`, the same check that `unknown_sets` gives. A rank 2 `pass`, `hang` or `crash` goes to `probed.checks` |
| 2 | Rank 2 facts are added only for the keys that the same call looked up in the db, so a later db row of the same key cannot come after a rank 2 row (R-EF3, reading 1) |
| 3 | The window of `why` is the `roc:` pin of the first member that has one (not `Pin.decide`: `why` makes no pin decision). A workspace with 2 pins sends the first one. No test has 2 pins |
| 4 | `differ_notes` is also correct for `install` and `upgrade` (same `finish!`). `verify` (`VerifyFlow.verified!`) does not print the note: not tested, not added |
| 5 | `why --registry <url>` stays refused by `Opts.reads_registry` (manager note: slice 217 edits it) |
| 6 | D1: no compiler list read in `round!` (agrees with the test) |

## Disputes (from the code agent)

| # | Case | Dispute |
| --- | --- | --- |
| C1 | `registry/ef3-bot-author` (round 1) | After Q500 the run gives 2 R-EF3 notes: `note: acme/json 2.0.0: the bot and the author rows differ on nightly-2026-10-16-5e6f7a8: bot fail, author pass` and `note: acme/parser 1.0.0: ... bot pass, author fail`. Both pairs are in the chosen tuple on N, the compiler of the run, and their `bot` and `author` rows differ, so Q500 (c) asks for both notes. The expect files were made before Q500 and have no note. Proposal: re-bake stdout (and `data.notes` if a `--json` run is added) with the 2 notes. Not edited (TW18). It is the only non-217 L2 fail Resolved (test agent, 2026-11-03): `expect/stdout` has the 2 notes after the `==` line and before `check: passed` (no other note in this run; json, then parser: the order of the header). Only these 2 lines changed. `tests/commands/run.sh registry/ef3-bot-author` passes |

## Verify results

Code agent run (2026-11-03), `scripts/test.sh check fmt l0 l2 l3`:

| Step | Result |
| --- | --- |
| check, fmt | pass |
| l0 | `ProberangeTest` passes (the new expect too). Fails only slice 217 (`ProbeshareTest`, `ProbecmdTest:45`). TW20 warning (26 s, loaded machine) |
| l2 | 356 pass. The 8 cases of this slice pass (`ef1-rank2-free`, `ef1-rank2-held`, `ep15-epoch-no-probe`, `al4-shared-order`, `pb3-outdated-runs`, `cm7-why-registry`, `ef3-note-tuple`) except `ef3-bot-author` (dispute C1). The other fails are slice 217 (`probe/pc1-targets`, `probe/ps1` to `ps12`) |
| l3 | Only `fx/ps1-real-fx-facts-of` (slice 217) |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206e3-revert/code-final.sha256` | OK, 7 files |
| `grep "todo: slice 206e3" cli/` | nothing |
| Expected exits (read) | all runs 0, except `al4-shared-order` 12 (the probe budget, R-P5, R-UP7) |
| The 8 slice cases | pass (`ef1-rank2-free`, `ef1-rank2-held`, `ef3-bot-author`, `ep15-epoch-no-probe`, `al4-shared-order`, `pb3-outdated-runs`, `cm7-why-registry`, `ef3-note-tuple`) |
| Dispute C1 | Accepted: `ef3-bot-author` was made before Q500. The test agent added the 2 notes by hand (diff of 2 lines) |
| `scripts/test.sh check fmt l0 l2 l3` | check, fmt pass. L0, L2, L3: only the slice 217 red tests fail (test round 2 in progress). 5 `roc/*` L2 failures in the full run were transient (a concurrent run); they pass alone |
| Mutation scripts | deleted by the manager (`mutate.sh`, `mutate2.sh`) |
| Code notes 1, 2 | Accepted (rank 2 `fail` as an inferred check with no modules, as `Matrix.unknown_sets` gives; rank 1 before rank 2 for one key) |
| Code notes 3, 4 | Sent as G-C135 (the `why` window with 2 pins) and G-C134 (the Q500 note in `verify`). Plan row 206e3b |
| Not tested | `why --registry <url>` (Q499 accepts it): after slice 217, in plan row 206e3b |

