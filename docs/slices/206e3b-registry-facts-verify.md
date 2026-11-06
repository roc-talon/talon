# 206e3b Registry facts in verify and the ladder, the second answer, `why` window

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 206e3b of `PLAN-P2-CLI.md`. It finishes slice 206e3 (`docs/slices/206e3-registry-evidence-probes.md`): the plan notes P1 and P2, the closing note of `why --registry <url>` (Q499), and the Design answers Q501 and Q502.

## Rules

R-EF1 (rank 2), R-EF3, R-DI1, R-CM7, R-CM11, R-LD2, R-FL7, R-WS4 (Resolution 3, 4, 5; CLI R-DI1). As used: R-EP12, R-AL4, R-AL7, R-AL8, R-SP24, R-RG4. Design Q499, Q500, Q501, Q502.

## Scope

| # | In | Where the code is (for the code agent) |
| --- | --- | --- |
| 1 | P1: `verify` and ladder step 1 read the rank 2 facts of the answer (the `bot` and `author` rows of `runs` and `nearest` on the compiler of the ladder), after the db rows (rank 1 wins, R-EF3) | `Ladder.known_facts!`, `Ladder.verify!`, `VerifyFlow.verified!` |
| 2 | P2: the `runs` of the second answer of a held move are evidence of the second search | `PickFlow.second_index!` (`both` keeps `releases` and `artifacts` only) |
| 3 | Q499: `why --registry <url>` is accepted | `Opts.reads_registry` (a `why` line) |
| 4 | Q501: `verify` prints the R-EF3 note (stdout and `data.notes`) | `VerifyFlow.verified!`, `PickLoop.differ_notes` |
| 5 | Q502: the `why` window is the nightly of the workspace when the pins agree. With different pins, the query has no `compilers` member, and each member block shows the facts of its own pin | `Why.walk_indexed!` |

## Flow as I read it

| Item | Reading |
| --- | --- |
| P1, `verify` | `verify` has no oracle loop that probes: its search does not call `PickLoop.round!`, so the only place where the facts of the tuple are read is `Ladder.known_facts!` (one `db_query` for the keys of the tuple on the held compiler). The test fixes: the `db_query` stays (rank 1 first), then the rank 2 facts of these keys are added. A pair with a rank 2 `pass` has no unit probe in round 1. Rank 2 facts are not written to `compat.db` (R-EF3: they are not local facts) |
| P1, `update json` (ladder of a resolve) | `Ladder.run!` has `loop.looked` and `loop.checks`: the keys that the search looked up are not asked again. The keys that the search did not look up (the held values of the names that the command does not name: parser and pf here) are asked of the db (`db_query facts=2`), then get their rank 2 facts. A pair with a rank 2 `pass` is not probed in round 1 |
| Rank 2 `fail` | As in 206e3 (Q393): it has an unknown set and never decides alone. The tests of this slice use rank 2 `pass` rows only for the ladder, so no test fixes how the ladder treats a rank 2 `fail` (see the doubts) |
| P2 | The second search reads its facts from the `runs` of both answers. A `bot` `pass` of pfx 0.1.1 on H in the second answer gives a real fact for the pair in the second search: it starts no unit probe for it. The `epochs`, `nearest` and `hints` of the second answer: see the doubts |
| Q499 | `why json --registry http://127.0.0.1:9` with no `config.toml` does what run 1 of `registry/cm7-why-registry` does (the same calls, the same text) |
| Q501 | `verify` prints the note of Q500 with the same text and in the same place as `install` (after the platform note, before `check:`), and `data.notes` has it after the platform note |
| Q502 | Members with different pins: one POST, no `compilers` (Q437), no read of a pin for the window. The blocks come from the pin of each member, from one answer |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L2 | `registry/ef1-rank2-verify` (new, 1 run): `verify` with the world of `ef1-rank2-held` (the answer has a `bot` `pass` of json 2.2.0 on H). Ladder round 1: the baseline, and the unit probes of pf and parser only (`probes 3`, `db_write facts=2`) | R-EF1, R-EP12, R-DI1, R-CM11, R-LD2 |
| L2 | `registry/ef1-rank2-ladder` (new, 1 run): `update json --dry-run`, rank 2 `pass` rows of json 2.2.0, parser 1.0.0 and pf 0.1.0 on H. The search asks the db for json (`facts=1`), the ladder for the other 2 keys (`facts=2`), and no unit probe runs. `3 probes` (baseline, check, build) | R-EF1, R-EP12, R-DI1, R-LD2, R-AL4 |
| L2 | `registry/sp24-second-evidence` (new, 1 run): run 1 of `sp24-update-held-move` with the check; the second answer has a `bot` `pass` of pfx 0.1.1 on H. The search probes yaml 1.1.0 only (`probes 1`, `db_write facts=1`); the ladder still probes json 2.0.0 (no row for it). `5 probes` | R-SP24, R-SP16, R-EF1, R-EP12, R-AP16 |
| L2 | `registry/cm7-why-flag` (new, 1 run): `why json --registry http://127.0.0.1:9 --file u1/main.roc`, no `config.toml`. Exit 0, the output and calls of run 1 of `cm7-why-registry` | R-CM7, R-DI1, R-FL7, R-RG2, Q499 |
| L2 | `registry/ef3-note-verify` (new, 2 runs): `verify` and `verify --json` with the answer of `ef3-note-tuple`. One note, for (json 2.2.0, H); none for (parser 1.2.0, N) or (parser 1.0.0, H). Stdout, the stderr summary of run 2, and `data.notes`. This case has the P1 effect too: json 2.2.0 has a `bot` `pass`, so run 1 has `probes 3` | R-EF3, R-AL7, R-CM11, Q500, Q501 |
| L2 | `registry/cm7-why-pins` (new, 1 run): `why json` in a workspace of 2 members, pins 2026-10-13 (apps/a) and 2026-10-14 (apps/b). One POST with no `compilers` member. Block a: `* 2 bot: fail` on 2026-10-13; block b: `* 2 bot: pass` on 2026-10-14. `db_query facts=2` | R-CM7, R-DI1, R-EF1, R-WS4, R-AL8, Q502 |

No L0 test: no new pure decision is named by the design for these items (the code agent may add one for the window of `why`).

The fixtures are made by `research/slice-206e3b-revert/mkcases.py` (from `cv1-upgrade-free`, `sp24-update-held-move`, `cm7-why-registry` and `cv1-held-offer`; each case has a `rules` file with the detail). It deletes the dirs of these cases: do not run it again after the expect files exist (the expect files are made by hand, below).

### How the expect files were made

No private reference with the fixed code was built. For each case, `UPDATE=1 tests/commands/run.sh <case>` ran once on the current code. Then the expected files were edited by hand to the behaviour of the rules:

| Case | Hand edit |
| --- | --- |
| `ef1-rank2-verify` | Round 1 of the ladder: `probes 4` to `probes 3` (the json unit probe removed), `db_write facts=3` to `facts=2`, the json fact removed from `compat.tsv` |
| `ef1-rank2-ladder` | Round 1: `probes 3` to `probes 1` (baseline only), no `db_write` after it, the 2 unit facts removed from `compat.tsv` (the build fact of pf stays), `5 probes` to `3 probes` |
| `sp24-second-evidence` | Search round: `probes 2` to `probes 1`, `db_write facts=2` to `facts=1`, the pfx 0.1.1 `any` fact removed from `compat.tsv`, `6 probes` to `5 probes` |
| `cm7-why-flag` | Written from run 1 of `cm7-why-registry` (stdout with the new command line, `calls.log`, `tree.diff`, exit 0) |
| `ef3-note-verify` | The note line in stdout (run 1) and stderr (run 2) after the platform note; the note in `data.notes`; the P1 edit of `ef1-rank2-verify` for run 1 |
| `cm7-why-pins` | The body of the POST has no `compilers` member |

Every `stdout`, `stderr`, `exit`, the `probes`, `db_*` and `http_send` lines of `calls.log` and `tree.diff` were read against the rules.

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `l0`, `l3` | pass (no change) |
| `l2` | 372 pass, 6 fail: the 6 new cases. No other test fails |
| `ef1-rank2-verify` | The ladder probes json 2.2.0 (`probes 4`): the rank 2 fact does not reach it |
| `ef1-rank2-ladder` | The ladder probes parser 1.0.0 and pf 0.1.0 (`probes 3`, `5 probes`) |
| `sp24-second-evidence` | The search probes pfx 0.1.1 too (the second answer `runs` are not read) |
| `cm7-why-flag` | exit 2, `--registry 'http://127.0.0.1:9': no registry exists in this version of tln` |
| `ef3-note-verify` | No note in stdout, stderr and `data.notes`; the P1 probe of json |
| `cm7-why-pins` | The POST has `compilers` 2026-10-13 .. 2026-10-13 (the first pin). The text is already as expected: the blocks use the pin of each member today |

## Expected exits (read, TW21)

| Case | Exit | Reason |
| --- | --- | --- |
| `ef1-rank2-verify` | 0 | `verified: the tuple passes` |
| `ef1-rank2-ladder` | 0 | Dry run; no stderr |
| `sp24-second-evidence` | 0 | Dry run; stderr has the report of the held move (`~ pf ... (held)`, `writes ...`) as `sp24-update-held-move` run 1 |
| `cm7-why-flag` | 0 | R-E7. No stderr |
| `ef3-note-verify` | 0, 0 | Run 2 stderr: the text summary of the `--json` run (as every `--json` resolve) |
| `cm7-why-pins` | 0 | No stderr |

## Code (stubs of the test step)

None. No new function and no new type: the code is in `Ladder`, `VerifyFlow`, `PickFlow`, `Opts` and `Why`. `grep "todo: slice 206e3b" cli/` finds nothing.

## Proposals (R-OUT2)

No new text and no new `--json` field. The cases use the note text of Q500 and the `why` block texts of slice 209.

## Out of scope

`why` and `verify` with a registry on `--offline` (no query, as before), `install --frozen`, the share hooks and the index notes (206e4), `tln probe --range` with a registry (217).

## Questions (stop until answered)

None. The design (Q499 to Q502) gives each item.

## Doubts (no test, or a reading that the code agent may dispute)

| # | Doubt |
| --- | --- |
| D1 | `ef1-rank2-verify` fixes that the `db_query` of the ladder stays (rank 1 first, then rank 2). A code that passes the search facts as a `loop` would also be correct for `update`, but `verify` has no search facts, so the `db_query facts=3` is the one call. If the code agent wants another call order, it writes a dispute |
| D2 | `ef1-rank2-ladder` pins `db_query facts=2` for the keys that the search did not look up, and no `db_write` after round 1 when no unit probe ran (the same as `ef1-rank2-held`). A rank 2 `fail` of the ladder is not tested (Q393: it is a local probe) |
| D3 | A transitive hash (a dependency of a dependency) is a ladder key that the search never looks up. No fixture has one with a full resolve, so no test checks its rank 2 fact. `ef1-rank2-ladder` (held names) and `ef1-rank2-verify` cover the same code path of `known_facts!` |
| D4 | P2 is tested for `runs` only. The `epochs`, `nearest` and `hints` of the second answer are the same merge in `second_index!` (`both`); a code that merges only `runs` passes the test. No test for `hints` (a cut round with a second search) or `epochs` |
| D5 | Q502 with members that agree: the window is the workspace nightly (`Pin.decide`). It is not tested: with equal pins, the first member pin is the same value, so today's code already passes. A case with a member with no pin and a member with a pin would need a reading of `Pin.decide` for `why` (not stated) |
| D6 | `cm7-why-pins` is red only by the `compilers` member of the POST. The blocks are right today, because each member block uses its own pin already |
| D7 | `ef3-note-verify` depends on the P1 change (json 2.2.0 is not probed in the ladder). A code that does P1 but not Q501 fails on the note; a code that does Q501 but not P1 fails on the probes. Both are in one case on purpose: the rank 2 `pass` is the same `bot` row that makes the note |

## Disputes (from the code agent)

## Code

| File | Change |
| --- | --- |
| `cli/lib/Matrix.roc` | New `rank2` (the body of `PickLoop.rank2_of`, moved: `Ladder` cannot import `PickLoop`, `ResolveBase` imports `Ladder`) |
| `cli/lib/PickLoop.roc` | `rank2_of` calls `Matrix.rank2` (same result) |
| `cli/lib/Ladder.roc` | `Loop` and `verify!` get `answer`; `known_facts!` adds `Matrix.rank2` facts of the asked keys after the db rows (not written to the db) |
| `cli/lib/ResolveBase.roc` | New `answer_of` (the `Answer` of `request.index`) |
| `cli/lib/InstallWrite.roc`, `cli/lib/VerifyFlow.roc` | pass `answer: ResolveBase.answer_of(request)` to the ladder; `VerifyFlow.verified!` prints and returns `PickLoop.differ_notes` after the platform notes (Q501) |
| `cli/lib/PickFlow.roc` | `second_index!`: `both` also merges `runs` and `nearest` of the second answer |
| `cli/lib/Opts.roc` | `reads_registry`: `["why"]` |
| `cli/lib/Why.roc` | `pin_window`: `Held(pin)` when the pins agree, else `None` (Q502) |

Review notes: (1) A rank 2 `fail` is not given to the ladder (only non-fail rank 2 facts): the pair is probed locally, as Q393. (2) `epochs` and `hints` of the second answer are not merged (D4). (3) `verify` uses `decision.held` as the compiler of the note. (4) Members with no pin and members with a pin: the pins of the members that have one decide (D5, not stated by Q502).

## Verify results

Code agent run: `scripts/test.sh check fmt l0 l2 l3`. check, fmt pass. L2: 378 pass, 9 fail (`publish/pu1` to `pu9`, slice 221). L0: only `PublishTest` (slice 221) fails. L3 pass (one run had a transient `waiting for another tln` line in `tools/ti1`; it passes alone). The 6 cases of this slice pass. D1 and D2 orders agree with the design: no dispute.

## Design answers after the code review (2026-11-03)

| # | Answer | Test change |
| --- | --- | --- |
| G-C154, Q521 | The unpinned members do not count as a difference. The code (`Why.pin_window` over the members that have a pin) is right. With different pins an unpinned member shows the facts of the selected compiler | New L2 `registry/cm7-why-pin-unset` (1 run): a workspace of 3 members, pins 2026-10-13 (apps/a), none (apps/b), 2026-10-13 (apps/c). One POST with `compilers` 2026-10-13 .. 2026-10-13. The block of b shows the facts of 2026-10-13. A second run in a workspace with pins 2026-10-13 and 2026-10-14 and a member with no pin: no `compilers` member, the block of the unpinned member shows the facts of the selected compiler. D5 is closed by the first run |
| G-C155, Q522 | The `epochs` and `hints` of the second answer are used after the move: epochs by target (second replaces first), hints of both (second wins on the same key) | New L2 `registry/sp24-second-epochs-hints` (1 run, from `sp24-second-evidence`): the second answer has `epochs` that join 2 compilers for target T, and a `fail` hint on the moved pair. The search probes the moved pair last (R-AL4) and takes the epoch cover (fewer probes). An L0 `expect` for the merge: a target in both (second wins), a target in the first only (kept), the same hint key (second wins). D4 is closed |

## Round 2 (Design Q521, Q522) test step

| Layer | Case | Rules |
| --- | --- | --- |
| L2 | `registry/cm7-why-pin-unset` (new, 2 runs, `cwd:ws1` and `cwd:ws2`). Run 1: pins 2026-10-13, none, 2026-10-13: one POST with `compilers` 2026-10-13 .. 2026-10-13, the block of the unpinned member (apps/b) is on 2026-10-13, `db_query facts=1`, no `path_roc` call. Run 2: pins 2026-10-13, 2026-10-14, none: no `compilers`, the unpinned member (apps/c) shows the roc on PATH (2026-10-12, a compiler that no pin names), `facts=3` | R-CM7, R-DI1, R-WS4, Q521 |
| L2 | `registry/sp24-second-epochs-hints` (new, 1 run, from `sp24-second-evidence`): `probe.max = 1`, and a `pass` hint of pfx 0.1.1 on H in the second answer. The cut round (yaml 1.1.0, pfx 0.1.1) probes pfx first (the rank 6 `pass` group, R-AL4), exit 12 (`1 unit check did not run`) | R-SP24, R-AL4, R-P5, R-UP7, Q522, Q395 |
| L0 | `tests/unit/LogsnapshotTest.roc` (driver `l0-1.roc`), 1 new expect for `LogSnapshot.merged`: `epochs` of a target in both (second wins), a target in the first only (kept), a target in the second only; `hints` with the same key (second wins), a hint of each answer only; `releases` and `runs` second first; `log_size` of the first | R-SP24, R-EP15, R-AL4, Q522 |

Stub: `LogSnapshot.merged` (new pure function, `crash "todo: slice 206e3b"`). The code agent fills it and makes `PickFlow.second_index!` use it for `both` (today `both` merges `releases`, `artifacts`, `runs`, `nearest`). The copies of the 2 changed files before the stub are in `research/slice-206e3b-revert/before/`.

Red: `cm7-why-pin-unset` fails (run 1: the block of apps/b is on the roc on PATH, 2026-10-12, not on the workspace pin, and `path_roc` is called); `sp24-second-epochs-hints` fails (the hints of the second answer are not read: yaml 1.1.0 is probed, not pfx 0.1.1); the L0 expect fails with `todo: slice 206e3b`.

Expected exits (read): `cm7-why-pin-unset` 0, 0 (no stderr); `sp24-second-epochs-hints` 12 (stderr `tln: error[budget]: the probe budget is spent: probe.max is 1 and 1 unit check did not run. ...`, the fact of the 1 probe saved).

| # | Doubt (round 2) |
| --- | --- |
| D8 | The `epochs` of the second answer have no L2 case. `PickLoop.wide!` computes the inferred facts (`Matrix.found` with the epochs) once, before the second answer is read, and the second search keeps `probed.inferred`. So no `update` run shows a difference of the epochs of the second answer, unless the code agent also computes the inference for the moved releases after the move. Q522 says this is the effect ("R-EP4 gives each moved release an epoch of its own"), but I cannot write the expected calls for it by hand (it needs a compiler list, `--no-probe` or a movable compiler, and a new inference step). The merge is tested in L0 only. The code agent may add the inference; a case for it is then a new test round |
| D9 | `cm7-why-pin-unset` run 1 fixes that no `path_roc` call happens (every member has a compiler: its pin or the workspace pin) and that `path-roc.json` is then written by run 2 (the `spawn_all` moves to run 2). If the code agent calls `path_roc` anyway, it disputes this. The hint of the sp24 case is a `pass` hint, not the `fail` hint of the Design text, because the natural order (yaml, pfx) already puts a `fail` hint on pfx last, so a `fail` hint could not fail today |
| D5 | Closed by `cm7-why-pin-unset` run 1 (Q521). D4: closed for `hints` and `epochs` by the L0 expect and the L2 hints case; the effect of the epochs is D8 |

## Code (round 2, Q521, Q522)

| File | Change |
| --- | --- |
| `cli/lib/LogSnapshot.roc` | `merged` filled: epochs by target (second replaces), hints (second wins on the same key), the rows of the second first |
| `cli/lib/PickFlow.roc` | `second_index!` uses `LogSnapshot.merged`. New `wider`: with an `Answer` index the second search reads D again (`probed.domain` to `NotRead`) when D has more than the held compiler |
| `cli/lib/PickLoop.roc` | `wide!`: the new inferred facts replace the old ones of the same (hash, nightly); the others stay (D8). First search: no change |
| `cli/lib/EvidenceFlow.roc`, `cli/lib/ResolveSelect.roc` | Q521: an unpinned member holds the pin that the other members share (`ResolveSelect.peek_pin!`: one list of the toolchains, no `path_roc`) |

Notes: the D8 inference runs only with an `Answer` index (a direct run keeps its calls: `upgrade/ur6-moves` showed the change otherwise). No L2 case shows the effect of the epochs yet (the test agent writes it). Run: `scripts/test.sh check fmt l0 l2 l3` all pass (slice 221 tests are green now).

## Round 3 (D8, Q522 epochs)

L2 `registry/sp24-second-epochs` (new, 1 run, from `sp24-update-held-move`): `update yaml@1.1.0 --no-probe --dry-run`, the compiler list of `cv1-upgrade-free`, and in the second answer an epoch 2026-10-12 .. H (target any) and a `bot` `fail` of pfx 0.1.1 on 2026-10-12 only. Case (a) of R-EP6 infers a fail of pfx 0.1.1 on H (Q393), which decides under `--no-probe` (R-EP9): exit 10, `no tuple works` (the text of the first search). Expect files made with `UPDATE=1` on the current code and read. Mutation (second answer `epochs: []`): the run exits 0 and moves pf, so the case fails. Fixture restored. Note: in this world the first search stops before it reads D, so the list is read once, in the second search; the case does not exercise the reset of `PickFlow.wider`.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206e3b-revert/code-final.sha256` | OK, 12 files (also `slice-221` OK: the `Opts.roc` copy has the 221 edit) |
| `grep "todo: slice 206e3b" cli/` | nothing |
| Expected exits (read) | all 0, except `sp24-second-epochs-hints` 12 (probe budget, `probe.max = 1`) and `sp24-second-epochs` 10 (`no tuple works`: the inferred fail of the second answer's epoch decides under `--no-probe`, R-EP6, R-EP9, Q522) |
| Mutation check of `sp24-second-epochs` | the second answer's `epochs` set to `[]`: exit 0 and pf moves, so the case fails. Restored |
| `scripts/test.sh check fmt l0 l2 l3` | check, l2, l3 pass. fmt and l0 fail only on `tests/unit/PublishCheckTest.roc` (slice 222 test step in progress) |
| `WhyTest.roc:58` | old P0 row changed to Q499 (`why --registry` accepted) by the test agent |
| Design answers | Q499 to Q502, Q521, Q522 |
| Not tested | the `PickFlow.wider` reset path itself (the case reads the list only in the second search); members whose pins agree with a member with no pin and the `path_roc` fallback; a rank 2 `fail` in the ladder (code: not given to the ladder, so a local probe, Q393); a transitive hash as a ladder key |

