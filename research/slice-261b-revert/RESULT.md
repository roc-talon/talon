# 261b mutation check (TW12), 2026-11-24

`mutate.sh` changes one place of the 261b code in a mirror under `.tmp/261b-mut/<name>/` (the repo is not changed). A records mutant runs `packages/records/tests/w0.roc` with nightly 03dce41 AND 11-06; a cli mutant runs `tests/unit/l0-9.roc` with 03dce41. A mutant is killed only by a failed test. Each run is capped (16G, no swap), flocked, 300 s limit.

First run: 11 of 13 mutants killed, 2 survived (`incl-root-first-byte`, `note-any-line`). Each survivor got a gap test (below). Second run: 13 of 13 killed; the reference passes.

| Mutant | Place | What it breaks | First run | Gap test | Final |
| --- | --- | --- | --- | --- | --- |
| reference | none | | all pass | | all pass (good) |
| incl-root-first-byte | `Tlog.check_inclusion` | compares only the first byte of the root | SURVIVED: each wrong root of the tests had another first byte | `TlogTest`: a signed root with only its LAST byte changed (inclusion; consistency old root, new root, same size) | killed (both compilers) |
| incl-leaf-no-0x00 | `Tlog.check_inclusion` | leaf hash without the 0x00 prefix | killed | | killed |
| chain-stops-early | `Tlog.check_chain` | skips the MTH check of the last full tile (the one under a partial tile) | killed | | killed |
| chain-mth-no-0x01 | `Tlog.check_chain` | the full-tile hash is SHA-256 of the 256 hashes (no RFC 6962 node hash) | killed | | killed |
| incl-missing-skipped | `Tlog.check_inclusion` | no missing-tile check (a missing tile gives NotIncluded) | killed | | killed |
| cons-new-root-for-old | `Tlog.check_consistency` | the root of the larger size is used for the old size | killed | | killed |
| cons-chains-skipped | `Tlog.check_consistency` | the tiles of the old size are not chained to the new edge | killed (a changed `tile/1/000` of 255 to 70,000: only the chain sees it) | | killed |
| entry-at-width-skipped | `Tlog.entry_at` | a bundle with fewer entries than its width is accepted | killed | | killed |
| note-name-only | `LogProof.open_checkpoint` | matches a line on the name only, not the key id | killed | | killed |
| note-any-line | `LogProof.open_checkpoint` | accepts when ONE of several lines of the key verifies | SURVIVED: no note had 2 lines of the same key | `LogproofTest`: a good and a bad line of key A, in both orders: `BadSignature` (Go `note.Open` rejects a bad signature of a known key) | killed |
| key-id-skipped | `LogKey.parse_verifier_key` | no key-id compare | killed | | killed |
| key-point-skipped | `LogKey.parse_verifier_key` | no `is_valid_public_key` check | killed | | killed |
| release-url-skipped | `LogProof.check_release` | no URL check | killed | | killed |

Not done as a mutant: a change of `leaf_hash` or `node_hash` themselves (257 code; the 257 vectors kill it at once). The reader-side mutants above change only the calls of the 261b code.
