# 209 Evidence from the registry

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 209 of `PLAN-P2-CLI.md`. The `epochs`, `runs`, `nearest` and `hints` of the closure answer (Registry R-AP17) become evidence: `Matrix` (Resolution R-EP15) for the epochs, rank 2 facts (R-EF1) from the `bot` and `author` runs (a `bot` row wins, R-EF3), rank 6 hints (R-EF3) that only order the probes (R-SE5), and the lines of `tln why` for ranks 2 and 6 (R-CM7).

## Scope

| In | Out (where) |
| --- | --- |
| New module `cli/lib/Matrix.roc` (in `main.roc`): `rows`, `real`, `intervals`, `found`, `shared`, `unknown_sets` (pure) | The call of these functions in the command code: `PickLoop` (the `Epochs.epochs` call when the step gives `Wide`, the rows of the oracle), `PickLoop.hinted!` (`PairOrder.order_shared` with the `hints` of an `Answer` index), `ProbeRange`, `EvidenceFlow.blocks!` (`Evidence.of_all`, `Evidence.differ`). Each needs a command with a registry index: slice 206b (no command can select a registry before slices 206b and 224) |
| `Evidence`: new `Source` tags `Bot`, `Author`, `Shared`; `Line` gains `digest` and `counts`; new `of_all`, `differ`; the text and `--json` of the new lines | The `tln why` output of a whole run with a registry, and the R-EF3 note in the output of the resolve commands (`install`, `update`, ...): slice 206b |
| `PairOrder.order_shared` (rank 6 after rank 4) | R-SM6 in the ladder: a `bot` smoke `fail` as a fail of step 3 with no build, and the learned interval for that target (R-EP7). This slice only gives the smoke row as a rank 2 fact of its target (`Matrix.rows`, `Matrix.real`). Proposal: a new plan row after 206b (manager) |
| R-AP58 at the reader: `null` and `""` stay 2 digests, and `--json` of `why` shows them | |

## Rules

R-EF1 (ranks 2, 6), R-EF3, R-EP2, R-EP3 (a) and (b), R-EP4, R-EP5, R-EP6, R-EP15, R-AP19 (evidence is not hidden; a run or an epoch past a hidden compiler), R-AP58, R-SM6 (the fact only), R-SE5, R-CM7. As used: R-EP10, R-EP12, R-EP13, R-EP14, R-AL4, R-EF2, R-CV1, R-MX4 (epochs use unit checks only), R-OUT2, R-OUT4.

## Decisions (pure, L0)

| Name | Signature | Rule |
| --- | --- | --- |
| `Matrix.Row` | `{ hash, nightly, target, source : [Bot, Author], result : [Pass, Fail, Hang, Crash], error_digest : Try(Str, [None]) }` | R-AP17, R-AP58 |
| `Matrix.rows` | `{ runs : List(Wire.Run), nearest : List(Wire.Nearest), domain : List(Nightlies.Release) } -> List(Matrix.Row)` | R-AP17, R-AP19, R-AP58, R-SM6, R-CV1 |
| `Matrix.real` | `{ local : List(Db.Fact), rows : List(Matrix.Row) } -> List(Db.Fact)` | R-EF1, R-EF3, R-EP12 |
| `Matrix.intervals` | `{ domain, epochs : List(Wire.Epoch), facts : List(Db.Fact) } -> List(Epochs.Interval)` | R-EP2, R-EP3, R-EP4, R-EP5, R-EP13, R-EP15, R-AP19 |
| `Matrix.found` | `{ domain, epochs, facts } -> Epochs.Found` | R-EP6, R-EP10, R-EP15 |
| `Matrix.shared` | `{ hints : List(Wire.Hint), hash, nightly, target } -> Try(Matrix.Shared, [None])` | R-EF1 rank 6, R-EF3 |
| `Evidence.of_all` | `{ hash, compiler, facts, pin, hint, rows : List(Matrix.Row), shared : List(Wire.Hint) } -> List(Evidence.Line)` | R-EF1, R-EF3, R-CM7 |
| `Evidence.differ` | `{ compiler : Str, lines : List(Evidence.Line) } -> List(Str)` | R-EF3 (the note) |
| `Evidence.text`, `Evidence.fields` | unchanged signatures; the new sources and keys | R-CM7, R-OUT4, R-AP58 |
| `PairOrder.order_shared` | `{ pairs, hints, shared : List(Wire.Hint) } -> List(OracleBase.Pair)` | R-AL4, R-EF1, R-SE5, R-EF2, Q395 |
| `Matrix.unknown_sets` (Q393) | `{ checks : List(Solver.Check), local : List(Db.Fact), rows : List(Matrix.Row) } -> List(Solver.Check)` | R-EF3, R-EP8, R-UM1, R-EP7, Q393 |

The tested reading:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | A compiler tag of the answer | The release of D that is `PinOrder.same_id` with it (R-CV1). D is the compiler list of the command, in R-NS1 order |
| 2 | An interval `[from, to]` (a run, an epoch) | Each release of D between the ends in R-NS1 order (`PinOrder.order_of` with the times of D). An end that D does not have (a hidden compiler, R-AP19) is placed by that order: the interval holds only the compilers that the client knows. An interval with no release of D gives nothing |
| 3 | `rows` | A run gives one row on each release of D in it (the id of D). A `nearest` row gives one row with its own `nightly`. The runs first, then the `nearest` rows, each in the order of the answer. Every target |
| 4 | `real` (R-EF3) | Rank 1 rows first, as they are. Then one fact for each key (hash, nightly, target) that rank 1 does not have, at the place of the first row of the key. A `bot` row wins over an `author` row. `closure` is `""` |
| 5 | `intervals` | Only the epochs with the target `any` (R-MX4). An epoch of the answer holds the releases of D in it. Case (b) of R-EP3 splits it at a transition where 2 or more hashes have a code result on both releases (target `any`) and the 2 results of the hash differ (the count of R-MX12 `changed`). A fault is not compared (R-EP5). 2 epochs of the answer are never joined. A release in no epoch is its own epoch. No epoch: `Epochs.partition` |
| 6 | `found` | `intervals`, then `Epochs.infer` with them. No epoch: `Epochs.epochs` |
| 7 | `shared` | The first row of the hash, the target and the compiler (`same_id`). `pass_count` > `fail_count` + `crash_count`: `Pass`; less: `Fail`; equal (also all 0) or no row: none |
| 8 | `of_all` | The lines of `of_pair`, with the rank 2 lines after rank 1 (a `bot` line, then an `author` line: both, R-EF3 "`--json` gives both") and a rank 6 line at the end. Only the target `any`. A rank 2 line has `modules` `[]` and the digest of its row |
| 9 | `differ` | One note when the `bot` line and the `author` line have different `result` words. A different digest only: no note (Q394) |
| 10 | `order_shared` | The rank 4 group (as `order`), then the pairs with a rank 6 `Pass` hint (the hash of the release URL, `Ident.of_url`, the target `any`), then the pairs with no hint, then the pairs with a rank 6 `Fail` hint (Q395). Each group keeps the order of the solver |
| 11 | `unknown_sets` (Q393) | A check with no rank 1 row whose rank 2 fact (after R-EF3) is a unit `fail` becomes `source: Inferred`, `modules: []`: a hard fail that touches each used module (also when the app uses no module of the package) and never decides alone, so the step asks for the local unit probe. A rank 2 `pass`, a fault, a rank 1 row, another target and a fail that loses to a `bot` row stay. The order stays |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/MatrixTest.roc` (driver `l0-5.roc`): `rows` (interval, one compiler, hidden ends, all hidden, tag form, digests `"d9"`, `""`, null, smoke target, `nearest`, order) | R-AP17, R-AP19, R-AP58, R-SM6, R-CV1, R-EP15 |
| L0 | `real`: rank 1 as it is, bot, author only, rank 1 wins, bot wins at the place of the first row, bot first then author, another target is another key | R-EF1, R-EF3, R-EP12, R-SM6 |
| L0 | `intervals`: no epoch (= `Epochs.partition`), one epoch, another target, 2 adjacent epochs, a hidden end, case (b) with 2 hashes (one or 2 directions), 1 hash, a hang, one side only, build rows, changes outside an epoch | R-EP2, R-EP3, R-EP4, R-EP5, R-EP13, R-EP15, R-AP19, R-MX4 |
| L0 | `intervals` with 2 overlapping epochs: the first in the order of the answer holds the shared releases, no stop | Q409, R-AP17 |
| L0 | `found`: no epoch = `Epochs.epochs`; case (a) in an epoch of the answer; a case (b) boundary stops case (a) | R-EP6, R-EP10, R-EP14, R-EP15 |
| L0 | `shared`: more passes, more fails and crashes, only crashes, equal, all 0, no row, other hash, compiler, target, tag form | R-EF1, R-EF3, R-CV1 |
| L0 | `PairOrder.order_shared`: none, rank 6 first, rank 4 before rank 6, 2 rank 6 hints, equal counts, other compiler, other target, tag form | R-AL4, R-EF1, R-EF3, R-SE5, R-EF2 |
| L0 | `tests/unit/EvidenceTest.roc` (driver `l0-4.roc`): `of_all` (no registry = `of_pair`, bot, author only, both with the bot first, empty digest, other hash, compiler, target, tag form, rank 6 pass, fail, equal, rank order 1, 2, 3, 4, 6) | R-EF1, R-EF3, R-CM7, R-SE5, R-AP58, R-CV1 |
| L0 | `differ`: differ, hang against fail, same, 2 fails with 2 digests (Q394), bot only, rank 1 against rank 6 | R-EF3, R-OUT2, Q394 |
| L0 | `MatrixTest` `unknown_sets`: bot fail, author fail, rank 2 pass, hang, rank 1 wins, bot pass wins over author fail, smoke fail of another target, inferred check, order | Q393, R-EF3, R-EP8, R-UM1, R-EP7 |
| L0 | `MatrixTest` order with a rank 6 `fail` hint: rank 4, rank 6 pass, no hint, rank 6 fail | Q395, R-AL4, R-EF3 |
| L0 | `text` with rank 2 and rank 6 lines and the note | R-CM7, R-OUT2 |
| L0 | `fields`: rank 2 with a digest and with null, an empty digest, rank 6 counts | R-OUT4, R-AP58, R-EF3, R-OUT2 |

No L2 case: every flow of this slice needs a command with a registry index (slice 206b). The existing `EvidenceTest` helper `line` gains the 2 new fields (`Err(None)`); no old expectation changed.

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-5.roc` | 85 pass, 8 fail: each `MatrixTest` expect, `todo: slice 209` |
| `roc test tests/unit/l0-4.roc` | 107 pass, 4 fail: the 4 new `EvidenceTest` expects, `todo: slice 209` |
| `scripts/test.sh check fmt l0 l2` | check, fmt and l2 pass; l0 fails only in `l0-4` and `l0-5` (the 12 expects above; re-run after the answers: check, fmt pass, l0-1 to l0-3 and l0-6 to l0-8 pass). l0 took 10.7 to 13.8 s on a loaded machine (TW20 warning) |

## Expected exits (read, TW21)

No L2 or L3 case is new in this slice, so no expected exit or stdout file.

## Revert check

`research/slice-209-revert/`: `before/` (the stubs), `results.txt`. A private reference was green (L0, and `scripts/test.sh l0` all pass), then 9 mutations were run, then the reference was deleted (TW18). After the answers Q393 to Q395 a new reference was green again (l0-4 111 of 111, l0-5 93 of 93), 4 more mutations were run, and it was deleted. Each mutation was caught:

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `real`: the author row wins (R-EF3) | `real` |
| M2 | `real`: rank 2 over rank 1 | `real` |
| M3 | `intervals`: case (b) with 1 changed hash | `intervals` |
| M4 | `intervals`: a hang is compared (R-EP5) | `intervals` |
| M5 | `intervals`: 2 adjacent epochs of the answer joined | `intervals` |
| M6 | `rows`: an end that D does not have gives nothing (R-AP19) | `rows`, `intervals` |
| M7 | `shared`: equal counts give a pass | `shared`, `order_shared` |
| M8 | `order_shared`: rank 6 before rank 4 | `order_shared` |
| M9 | `of_all`: the author line first | `EvidenceTest` `of_all` |
| M10 | `unknown_sets`: the rank 2 fail stays `Real` (Q393) | `unknown_sets` |
| M11 | `unknown_sets`: no R-EF3 precedence | `unknown_sets` |
| M12 | `order_shared`: a rank 6 fail with the pairs with no hint (Q395) | Q395 expect |
| M13 | `differ`: a different digest is a different result (Q394) | `differ` |

## Code (stubs of the test step)

| File | Change |
| --- | --- |
| `cli/lib/Matrix.roc` | New: the type `Row`, `Shared` and the 6 stubs (`crash "todo: slice 209"`), `unknown_sets` added after Q393 |
| `cli/lib/main.roc` | `Matrix` in the package list |
| `cli/lib/Evidence.roc` | `Source` gains `Bot`, `Author`, `Shared`; `Line` gains `digest`, `counts` (`of_pair` sets both to `Err(None)`); stubs `of_all`, `differ`; the source words of the new tags are stubs; `line_text` and `line_doc` are unchanged (the code agent adds the counts and the keys) |
| `cli/lib/PairOrder.roc` | Stub `order_shared` |
| `tests/unit/MatrixTest.roc`, `tests/unit/l0-5.roc` | The new L0 tests and the driver import |
| `tests/unit/EvidenceTest.roc` | 4 new expects; the helper `line` gains the 2 fields |

## Code

| File | Change |
| --- | --- |
| `cli/lib/Matrix.roc` | Bodies of `rows`, `real`, `intervals`, `found`, `shared`, `unknown_sets`; private `winner` (R-EF3: the first `bot` row, else the first row of the key) and `close`. Imports `PinOrder`, `Ident` |
| `cli/lib/Evidence.roc` | Bodies of `of_all`, `differ`; source words `bot`, `author`, `shared`; `line_text` adds the rank 6 counts; `line_doc` adds `error_digest` (rank 2) or the 3 counts (rank 6) after `winner` (`line_extra`) |
| `cli/lib/PairOrder.roc` | Body of `order_shared`: rank 4, rank 6 `Pass`, no hint, rank 6 `Fail` |

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-5.roc` | 93 of 93 pass |
| `roc test tests/unit/l0-4.roc` | 111 of 111 pass |
| `scripts/test.sh check fmt l0 l2 l3` | check, fmt, l2, l3 pass. l0: l0-2 to l0-8 pass; l0-1 has 27 fails, all `UnknownvaluesTest` with `todo: slice 208` (the red tests of slice 208). TW20 warning on l0 (10.0 to 12.2 s, loaded machine) |

Notes for the review (no test reads them):

| # | Note |
| --- | --- |
| 1 | Manager review (R-CV1): `real` and `unknown_sets` match the `nightly` of a row with `PinOrder.same_id`, as `rows`, `intervals`, `shared` and `of_all` do. The 2 tag forms of one release are one key. The doc of `real` says this. After the fix: check, fmt pass; l0-2 to l0-8 pass (l0-4 111 of 111, l0-5 93 of 93); l0-1 only the 27 slice 208 red tests |
| 2 | (To the design side.) `intervals`: a release of D that 2 epochs of the answer hold (overlap) goes to the first such epoch in the order of the answer. Answered (Design Q409, Registry R-AP17): right, no stop. The Worker cannot send it. The code stays. New L0 `expect` in `MatrixTest` (Q409, R-AP17): epochs c1 to c3 and c2 to c5 give c1 to c3 and c4 to c5; in the other answer order they give c1 and c2 to c5. It passes with the code |
| 3 | `unknown_sets` changes only `source` and `modules` of a `Real` check; `outcome` stays as the check has it |

## Moved to slice 206b (no command can select a registry yet)

| Part | Why |
| --- | --- |
| `PickLoop`: `Matrix.rows` and `Matrix.real` into the checks of the oracle, `Matrix.unknown_sets` on the checks (Q393), `Matrix.found` in place of `Epochs.epochs` with an `Answer` index; `ProbeRange` the same | A flow of a whole resolve with a registry |
| `PickLoop.hinted!`: `PairOrder.order_shared` with the `hints` of an `Answer` index | The same |
| `EvidenceFlow.blocks!`: `Evidence.of_all` and `Evidence.differ` for `tln why` with a registry (and where `why` gets the answer: `why` makes no index call today, E3, R-DI1) | A whole `tln why` run with a registry |
| The R-EF3 note in the output and `--json` of the resolve commands | A whole command |

## Output (accepted at the review, Design Q395)

| Case | Text |
| --- | --- |
| Source words | `bot`, `author` (rank 2), `shared` (rank 6) |
| Rank 2 line of `why` | `      * 2 bot: fail` (no digest in the text) |
| Rank 6 line of `why` | `        6 shared: pass (5 pass, 1 fail, 0 crash)` |
| R-EF3 note (in `why`) | `note: the bot and the author rows differ on <compiler>: bot <result>, author <result>` |
| `why --json`, rank 2 line | the 5 keys, then `"error_digest"`: the text or `null` |
| `why --json`, rank 6 line | the 5 keys, then `"pass_count"`, `"fail_count"`, `"crash_count"` |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | A rank 2 `fail` has an `error_digest` (R-EF1 `fail(error digest)`), not the set of failing modules that R-P4, R-EP6, R-EP7 and R-UM1 read. Which `modules` does its fact get? (a) none: then the fail is a hard fail for R-UM1 (the app's use of the module is not checked), (b) the fact is only an order hint for R-EP7 until a local probe gives the modules, (c) the digest names the modules (a new rule for the bot and for `tln publish`). The tests do not read `modules` of a registry fact. | Answered (Design Q393, Resolution R-EF3): an unknown set; it touches each used module and does not decide alone (R-EP8). `Matrix.unknown_sets` marks the check `Inferred` with no module |
| Q2 | R-EF3 note "when a `bot` row and an `author` row of one pair have different results": does a different `error_digest` with the same `result` (`fail` and `fail`) count as different? The tests fix only a different `result`. | Answered (Design Q394, R-EF3): only a different `result`; 2 digests give no note |
| Q3 | The probe order with a rank 6 `fail` hint (R-AL4 "then the strongest hint"): is such a pair after the pairs with no hint, or with them? | Answered (Design Q395, R-AL4): after the pairs with no hint |

Answers (design agent, 2026-11-03):

| G-C | Design Q | Answer | Test change |
| --- | --- | --- | --- |
| G-C63 (Q1) | Q393 | An unknown set: it touches each used module, and the fail does not decide alone (as R-EP8): the solver runs the local unit probe (Resolution R-EF3) | New L0 test: a rank 2 `fail` gives a probe of the pair, not a hard incompatibility, also when the app uses no module of the package |
| G-C64 (Q2) | Q394 | Only a different `result` value. 2 `fail` rows with 2 digests give no note. | New L0 test: 2 `fail` rows with 2 digests, no note |
| G-C65 (Q3) | Q395 | After the pairs with no hint (Resolution R-AL4) | New L0 test: the order with a rank 6 `fail` hint |
| TW24 output | Q395 | The proposals agree with the design | None |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-209-revert/code-final.sha256` | 3 of 3 OK (`Matrix.roc`, `Evidence.roc`, `PairOrder.roc`) |
| `todo: slice 209` in `cli/` | None |
| L0 | `l0-4` 111 of 111, `l0-5` 94 of 94 (with the Q409 overlap expect). `scripts/test.sh l0` fails only in `l0-1`, on 27 slice 208 red tests. |
| `scripts/test.sh check l3` | Pass. `l2` fails only on the 3 slice 208 red cases (`ap28-*`). |
| L2 cases | None (every flow needs a command with a registry: slice 206b) |
| Revert check | 13 of 13 caught (test step) |
| Review change | `Matrix.real` and `unknown_sets` compare the nightly with `PinOrder.same_id` (R-CV1), as the other functions do. |
| Design answers | Q393, Q394, Q395, Q409; the output proposals accepted |
| Moved out | Slice 206b: the wiring in `PickLoop`, `ProbeRange`, `EvidenceFlow` and the R-EF3 note in commands. Slice 209b: R-SM6 in the ladder. |

