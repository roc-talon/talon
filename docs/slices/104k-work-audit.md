# 104k `Work` and `Audit` in `records`

Phase: P2. Status: code done (2026-11-03). Model for the code: Sonnet medium. About 40 lines in 2 new files. Plan row: `docs/registry/PLAN.md` 104k. Design: Design Q575, Registry R-AP39, R-AP40, R-AP73, R-AP51, R-AP44, R-AP24.

## Rules

| Rule | Effect in this package |
| --- | --- |
| R-AP39, Q575 | New module `Work`: the answer of `GET /v1/sweeps/{tag}`: `{log_size, members, missing, sweep}`. |
| R-AP40, Q575 | New module `Audit`: the answer of `GET /v1/compat_hints?audit=<n>`: `{pairs}`, a pair is `{crash_count, fail_count, hash, nightly, pass_count, target}`. |
| R-AP73 | Each has a type, a decoder and an encoder. The encoder gives the bytes that the Worker gives today: members in alphabetical order, no white space, `sweep` always written (`null` for none), the lists in the order given. |
| R-AP51, R-AP44 | The decoder: all members are required (also all members of a sweep row and of a pair). A missing member, `null` or a wrong JSON type (also a negative or a fractional number for a `U64`) is `BadJson`. `sweep` is an object or `null` only. An unknown member is ignored. The order of the members is free. |
| R-PK7 | The tests run on both nightlies. |

## Types (real in the stub)

| Name | Type | Note |
| --- | --- | --- |
| `Work.Sweep` | `{ nightly : Str, target : Str, time : U64, upto_log_index : U64 }` | The `sweeps` row as the Worker writes it. It has `time`, so it is not `Compat.Sweep` (R-AP10: no `time`). Q575 says "uses `Compat.Sweep` when its members are the same": they are not. See the notes. |
| `Work.Answer` | `{ sweep : Try(Work.Sweep, [None]), log_size : U64, members : U64, missing : List(Str) }` | `Err(None)` is `null`. `missing` has the hashes in base58, as text. |
| `Audit.Pair` | `{ hash : Str, nightly : Str, target : Str, pass_count : U64, fail_count : U64, crash_count : U64 }` | `hash` is base58 text. The Worker turns its 32 bytes into text before it calls the encoder. |
| `Audit.Answer` | `{ pairs : List(Audit.Pair) }` | |

| Function | Type |
| --- | --- |
| `Work.encode`, `Audit.encode` | `Answer -> Str` |
| `Work.decode`, `Audit.decode` | `Str -> Try(Answer, [BadJson(Str)])` |

For the bot (CLI slice 223): `Bot.work` becomes `Work.decode` and `Bot.pairs` becomes `Audit.decode` (the bot reads `.pairs`). `BotTest` expects `w.log_size`, `w.members`, `w.missing`, `w.sweep.is_err()` and `w.sweep == Ok({ nightly, target, time, upto_log_index })`: the type above has exactly these. `Bot.sweep` reads `work.log_size`, `work.missing` and gives `Compat.Sweep` from the tag and `log_size`: it needs no `time`.

## Stub

`packages/records/Work.roc` and `Audit.roc`: the types are real, `encode` and `decode` are `crash "todo: slice 104k"`. Both names are in `packages/records/main.roc` (`Audit` after `Artifact`, `Work` last). The code agent writes the bodies. The reference in `research/slice-104k-revert/reference/` shows one way: a private wire record with `Nullable(Work.Sweep)` for `sweep` (module `Nullable`, as `Compat.roc` does), `Json.to_str` for the encoders, and `Json.parse` for the decoders. The derived JSON codec writes the members of a record in alphabetical order.

## Tests

`tests/WorkTest.roc` (8 `expect`s) and `tests/AuditTest.roc` (7 `expect`s), both in `tests/w0.roc`.

| Test | Case | Rules |
| --- | --- | --- |
| Work 1 | The 4 bodies of the W2 case `compat/ap39-sweeps`: decode to the value, encode to the same bytes, decode then encode | R-AP39, R-AP73 |
| Work 2 | Bytes of the encoder (the W0 test of `CompatReads.sweep_body`): order, `null`, `missing` order kept, 120 hashes, a quote in the tag escaped | R-AP39, R-AP73, R-AP24 |
| Work 3 | Free member order, unknown member (answer and sweep row), white space | R-AP51, R-AP44 |
| Work 4 | A missing member of the answer (4 cases and `{}`), also a missing `sweep` | R-AP51, R-AP73 |
| Work 5 | `null` or a wrong type for a member (16 cases): `null`, text, negative, fractional, `true`, `missing` not a list or with a non-text item, `sweep` as text, list, number, `false` | R-AP51, R-AP73 |
| Work 6 | The sweep row: 4 members required, none `null`, none of a wrong type (12 cases) | R-AP51, R-AP73 |
| Work 7 | Not JSON, not an object, cut text, text after the value: `BadJson`, no crash | R-AP51 |
| Work 8 | Round trip with the largest `U64`, an escaped text, an empty text, both forms of `sweep` | R-AP39, R-AP73 |
| Audit 1 | The body of the W2 case `compat/ap40-audit` (4 pairs): decode, encode to the same bytes, 2 pairs, empty `pairs` | R-AP40, R-AP73 |
| Audit 2 | Bytes of the encoder (the W0 test of `CompatReads.pairs_body`): member order, the pair order is kept (no sort) | R-AP40, R-AP73, R-AP24 |
| Audit 3 | Free member order, unknown member (answer and pair), white space | R-AP51, R-AP44 |
| Audit 4 | `pairs` missing, `null`, not a list, an item that is not an object, an array as body (12 cases) | R-AP51, R-AP73 |
| Audit 5 | Each of the 6 members of a pair: missing (6 cases), `null`, wrong type, negative, fractional (17 cases) | R-AP51, R-AP73 |
| Audit 6 | Not JSON and cut text: `BadJson`, no crash | R-AP51 |
| Audit 7 | Round trip with the largest `U64`, an escaped text, an empty text, an empty list | R-AP40, R-AP73 |

The decoders do not check the base58 form of a hash: R-AP73 gives only the rules of R-AP51, and the Worker wrote the text. Work 8 and Audit 7 pin this (a hash `a"b`, an empty text).

Red result: 99 tests on both nightlies (`nightly-2026-10-14-38a3029` and `nightly-2026-10-31-f7bef6b`): 84 pass (the old tests), 15 fail (all 8 of Work and all 7 of Audit, with `todo: slice 104k`). 0 compiler errors. `roc fmt --check packages/records/` is clean on both.

## The Worker (code agent, not in the tests of this slice)

The builders are not in `Reads.roc`. They are in `worker/lib/CompatReads.roc`:

| Function now | Change |
| --- | --- |
| `CompatReads.sweep_body` (R-AP39) | Build a `Work.Answer` and return `Work.encode(answer)`: `sweep` is `Ok({ nightly: x.tag, target: "any", time: row.time, upto_log_index: row.upto_log_index })` or `Err(None)`. Same type as now (`Str`). |
| `CompatReads.pairs_body` (R-AP40) | Turn each `hash` (32 bytes) to base58 with `Reads.base58_of_bytes`, keep `Err(BadRow)` for a bad length, then `Audit.encode({ pairs })`. Same type as now. |

The W2 cases `compat/ap39-sweeps` and `compat/ap40-audit` (bodies and the ETag `9b408635d67cbcedd83e37f5f39fcad6`) and the W0 expects of `CompatReadsTest` (`sweep_body`, `pairs_body`) are the byte check. They stay as they are (R-AP73). The types `CompatReads.SweepRow` and `CompatReads.PairRow` stay (they are rows of D1). `CompatReadRoutes.roc` calls the same two functions, so it does not change. The `worker/` tests are not edited by this slice.

## Other builds (checked 2026-11-03)

| Build | Result |
| --- | --- |
| `worker/` | No file imports `records.Work` or `records.Audit`. `roc check worker/lib/CompatReads.roc` is clean with the stub. The Worker imports `records` already (`records.Code`). |
| `cli/` | No import of the 2 modules. The two new names in `records/main.roc` change no existing module. |
| `bot/` (slice 223) | Not written yet. The bot imports `records.Work` and `records.Audit` after this slice (Q575, slice 223 Q10): `BotTest` expects 1 and 2 move to this slice (done above), `Bot.work` and `Bot.pairs` leave the stubs. This is a test change of slice 223 for its own agent: `BotTest` expects 1 and 2 call `Work.decode` and `Audit.decode`, and `Bot.Work` in expect 8 becomes `Work.Answer`. |
| `scripts/test.sh check w0` | `w0` result is in the red result above. |

## Private reference and revert checks

`research/slice-104k-revert/reference/Work.roc` and `Audit.roc`: 99 tests pass on both nightlies. `research/slice-104k-revert/mutate.py` (10 mutants, run on both nightlies; the stubs are `stub-Work.roc` and `stub-Audit.roc`):

| Mutant | Result |
| --- | --- |
| M1 `Work.encode` leaves out `sweep` for none | caught (3 tests) |
| M2 `Work.decode` reads a missing `sweep` as `null` | caught (1) |
| M3 `Work.encode` reverses `missing` | caught (3) |
| M4 `Work.decode` swaps `log_size` and `members` | caught (3) |
| M5 `Work.decode` keeps only the first `missing` | caught (2) |
| M6 `Audit.encode` sorts the pairs by `pass_count` | caught (2) |
| M7 `Audit.decode` drops the last pair | caught (5) |
| M8 `Audit.encode` writes a space after each comma | caught (2) |
| M9 `Audit.decode` reads a `null` `pairs` as empty | caught (1) |
| M10 `Audit.decode` swaps `pass_count` and `fail_count` | caught (4) |

All 10 caught on both nightlies. The package files are the stubs again.

## Questions

None. Notes for the review (not blocking):

| Note | Text |
| --- | --- |
| Sweep type | Q575 says "`Compat.Sweep` when its members are the same". The Worker writes `time` in the row (R-AP39 text: "the `sweeps` row"; `BotTest` expects `time`), and `Compat.Sweep` has no `time`, so `Work.Sweep` is a new type with 4 members. If the human wants `Compat.Sweep` to get `time`, the request form of R-AP10 would change: not proposed. |
| Hash as text | `Audit.Pair.hash` and `Work.Answer.missing` are `Str`, not `Id`. The decoders do not check the form. |

## Code and results (code agent)

| Item | Result |
| --- | --- |
| Code | `packages/records/Work.roc` and `Audit.roc`: a private wire record (`Work.Wire` with `sweep : Nullable(Work.Sweep)`), `Json.to_str` for the encoders, `Json.parse` for the decoders. `Audit.Answer` is its own wire form. |
| Worker | `worker/lib/CompatReads.roc`: `sweep_body` builds a `Work.Answer` and calls `Work.encode`. `pairs_body` converts each hash with `Reads.base58_of_bytes` (`Err(BadRow)` stays for a bad length) and calls `Audit.encode`. Two imports are new. A record `{ pairs }` as an argument is read as a block: it is bound with a type first. |
| `roc test packages/records/tests/w0.roc` | All 99 pass on nightly-2026-10-14-38a3029 and on nightly-2026-10-31-f7bef6b. |
| `roc fmt --check` | Clean on `packages/records` (both nightlies) and on the Worker file. |
| `scripts/test.sh check fmt` | check pass (4.3 s), fmt pass (0.3 s). |
| `scripts/test.sh w0 wbuild w2` | w0 pass (9.5 s, 448 Worker tests), wbuild pass (218.6 s, `--opt=speed`), w2 pass (73.6 s): `compat/ap39-sweeps` and `compat/ap40-audit` give the same bytes. |
| `scripts/test.sh l0` | Fails only in `BotTest` (bot stubs of slice 223) and in `ProbecmdTest.roc:250` (`ProbeShow.facts_doc`). Neither file is in this slice. |

## Revert check of the code (TW12, main session, 2026-11-03)

`research/slice-104k-revert/code-check/run.sh` mutates the package code (not the reference), runs `roc test packages/records/tests/w0.roc` on ROC_TAG, and restores the file. 6 of 6 caught: W1 `log_size` and `members` swapped, W2 `missing` reversed, W3 `sweep` always none, A1 last pair dropped, A2 white space after a comma, A3 `pass_count` and `fail_count` swapped. Status: done.
