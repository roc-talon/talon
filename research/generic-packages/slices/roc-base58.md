# roc-base58: encode and decode

Phase: P0, generic packages (Design 7, TESTING.md 7.4). Status: review (round 2: B58-Q1 settled, limit tests added)

Repository: `../roc-base58/` (future `github.com/Karakatiza666/roc-base58`). Not committed.

## Rules

| Id or source | Text | Where |
| --- | --- | --- |
| R-PK3 | Encode and decode, Bitcoin alphabet. Spec: the hash form of roc. | Design 6.1 |
| R-GA4 | base58 is missing, so it is the generic package `roc-base58` | Design 6.2 |
| Design 2 | A package URL ends in `<hash>.tar.zst`. The hash is base58 (Bitcoin alphabet) of the BLAKE3 of the `.tar.zst` bytes. | Design 2, LAYOUT.md 5 |
| BTC | The Bitcoin base58 rules: the alphabet `123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz` (digit values 0 to 57), the bytes are one big-endian number, the most significant digit is first, each leading zero byte is one leading `1`, decode rejects a character outside the alphabet | Task spec |
| TESTING.md 4 | L1: `decode(encode(b)) == b`, a leading zero byte is kept. Also "decode never crashes". | TESTING.md 4 |
| R-GP1, R-GP7 | No Talon concept in the API or the README. `LICENSE` is UPL-1.0 with the copyright line of table LIC. | Design 6.1 |

## Public API

`package/main.roc` exposes `Base58`. `package/Base58.roc` (stubs, each body `crash "todo"`):

| Function | Signature | Text |
| --- | --- | --- |
| `Base58.encode` | `List(U8) -> Str` | Each leading zero byte gives one leading `1`. `[]` gives `""`. |
| `Base58.decode` | `Str -> Try(List(U8), [InvalidChar(U64), TooLong(U64)])` | Each leading `1` gives one leading zero byte. `""` gives `Ok([])`. A text of more than 1024 UTF-8 bytes gives `Err(TooLong(length))` (checked first). A byte outside the alphabet gives `Err(InvalidChar(index))`: the index of the first such byte in the UTF-8 bytes of the text. |

No dependency. No hidden module yet (the code agent can add `package/Internal/`).

## Tests

All tests use the public API only. Each `expect` has a comment with its source.

| Layer | File | Count | Cases | Source |
| --- | --- | --- | --- | --- |
| L0 | `tests/base58.roc` | 42 | Each of the 58 digits both ways; 58 is `21`; a `1` that is not leading is digit 0 (`z1`); `[]` and `""`; leading zero bytes and leading `1` both ways; `0 O I l`; `+ / = -`; whitespace at the start, the end and inside; the first of two bad bytes; non-ASCII text (byte index). Limit (8): 1024 bytes accepted (2 cases), 1025 gives `TooLong(1025)`, length check before the alphabet check, a bad byte at index 1023, the limit counts UTF-8 bytes (2 cases), 749 bytes of 0xFF encode to 1023 bytes and decode back. | R-PK3, BTC, TW24, B58-Q1 |
| L0 | `tests/bitcoin_vectors.roc` | 42 | The 21 pairs of Bitcoin Core `base58_encode_decode.json`, one encode and one decode test each | R-PK3, BTC |
| L0 | `tests/roc_hashes.roc` | 5 | The BLAKE3 digest of 2 real release assets both ways (roc-parser 2.0.0 `7CLzCK6q...`, unicode 4.2.0 `4W8SHzvw...`); a 32-byte digest with 2 leading zero bytes | R-PK3, Design 2 |
| L1 | `fuzz/roundtrip.roc` | 1 | `decode(encode(b)) == Ok(b)`, b = 0 to 8 zero bytes, then random bytes, cut to 749 bytes (so `encode(b)` is inside the limit) | TESTING.md 4, R-PK3 |
| L1 | `fuzz/leading-ones.roc` | 1 | The count of leading `1` in `encode(b)` equals the count of leading zero bytes of b | BTC, R-PK3 |
| L1 | `fuzz/canonical.roc` | 1 | For text of alphabet characters only, cut to 1024 bytes: `encode(decode(t)) == t` | BTC (one form for each byte list), decision D6 |
| L1 | `fuzz/decode-total.roc` | 1 | Decode never crashes. A text of n > 1024 bytes gives `Err(TooLong(n))`. Else it gives `Err(InvalidChar(i))` exactly when byte i is the first byte outside the alphabet, else `Ok`. Input: alphabet characters, then random text. | TESTING.md 4, BTC, TW24 |

Other files:

| File | Content |
| --- | --- |
| `tests/tools/blake3_hex.roc` | Prints `Crypto.BLAKE3` of `asset.tar.zst` as hex (builtin, no `b3sum` on this machine) |
| `scripts/blake3-vectors.sh [ROC]` | Downloads the 2 assets to `.work/b3/`, runs the tool on each, prints `<hex> <name>`. `roc check` of the tool works only in that copy (the embed file is next to it). |
| `scripts/test.sh ROC [FUZZ_ROC]` | `FUZZ_ROC` (default `ROC`) builds the fuzz targets. check, fmt check, `roc check` of each test and fuzz file, `roc test` of each `tests/*.roc`, then build and run each fuzz target with `--runs=$RUNS --seed=1 --time=0` (default 100000). Exit 0 only when all pass. |
| `LICENSE`, `.roc-version`, `.gitignore`, `README.md` | Table LIC line plus the UPL-1.0 text of the Talon `LICENSE`; `nightly-2026-10-15-38e6c42` (the latest, at the human's request); `.work/`, `dist/` |

Red state (2026-10-16). `scripts/test.sh <10-15 roc> <10-14 roc>`. roc-fuzz 0.4.3 does not run on 10-15 (`../nightly-1015-check/README.md`), so L1 is on 10-14 only.

| Check | `nightly-2026-10-15-38e6c42` | `nightly-2026-10-14-38a3029` |
| --- | --- | --- |
| `roc check package/main.roc` | exit 0, no warning | exit 0, no warning |
| `roc check`, `roc fmt --check` on each test and fuzz file | exit 0, no warning | exit 0, no warning |
| `roc test` | 42, 42, 5 failed, 0 compiler errors. All 89 failures are "todo". | Same |
| Each fuzz target | Not run | Builds. Run: exit 77, `[roc crashed] todo`. |

The first red run (34 L0 tests in `tests/base58.roc`) was also on `nightly-2026-10-09-258ab27`.
| Check of the expected values | In a temp copy (`.work/`, removed), `encode` was replaced by the base58 of `layout-probe/tools/bundle_hash.roc`: the 32 encode-only `expect`s passed, and each other `expect` failed only on the `decode` stub. The `hex` test helper was checked once against `[0x27, 0x1F, 0x35, 0xA0]` and the 256-byte vector. |

## Output (TW24)

The design does not name the errors of decode. Type: `[InvalidChar(U64), TooLong(U64)]`.

| Item | Status | Value | Reason |
| --- | --- | --- | --- |
| `InvalidChar` tag | Accepted 2026-10-16 | A byte outside the alphabet (also whitespace) | BTC |
| `InvalidChar` payload | Accepted 2026-10-16 | The index of the first bad byte in the UTF-8 bytes of the text | The caller can show where the text is wrong. `Str` counts and cuts in bytes. |
| Which byte | Accepted 2026-10-16 | The first one, when there are more | Deterministic |
| Limit value | Proposed (B58-Q1) | 1024 UTF-8 bytes of text. A text of exactly 1024 bytes is accepted. | Each list of at most 749 bytes encodes to at most 1024 bytes (750 bytes can give 1025). That is 23 times a 32-byte hash (44 bytes), and more than the longest Bitcoin Core vector (348 bytes). The cost is about 1024^2 steps. |
| Limit API shape | Proposed (B58-Q1) | A fixed limit inside `decode`, stated in the doc comment. No new function, no parameter. | Smallest API. One signature for all callers. |
| `TooLong` tag | Proposed (B58-Q1) | `TooLong(length)`, the count of UTF-8 bytes of the text | The caller can report the length |
| Order | Proposed (B58-Q1) | The length check is first, before the alphabet check | No scan of a long text |

## Decisions

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | One type module `Base58` with `encode` and `decode` | `to_str` / `from_str`; one module for each direction |
| D2 | Error `[InvalidChar(U64)]`, byte index (TW24, accepted) | A bare tag (`InvalidChar`, `BadBase58`): no position. `InvalidChar({ index, byte })`: a byte of a UTF-8 character is not a character. A character index: `Str` has no character API. |
| D3 | Whitespace is rejected, also at the start and the end (spec: "rejects a character outside the alphabet"). Accepted. | Bitcoin Core `DecodeBase58` skips leading and trailing whitespace. The copied vectors have no whitespace case, so they do not conflict. |
| D4 | (Accepted.) Copy all 21 Bitcoin Core vectors (commit `5dd3a0d8a899e4c7263d5b999135f4d7584e1244`, file sha256 `20d51011...82ca`) as `expect`s, with the URL and the full MIT notice in the file comment. `tests/` is not in the bundle, so the package license does not change. | A JSON fixture parsed in the test: more test code. Only a few vectors: the 2025 edge cases (`zzzzz` to `211111`, 40 zero bytes) are useful. |
| D5 | Real roc hashes from 2 assets: roc-parser 2.0.0 and roc-lang/unicode 4.2.0 (the dependency of roc-parser). BLAKE3 with the roc builtin. Cross-check: `layout-probe/tools/bundle_hash.roc` gives the same 2 names, and roc checks the name when it downloads. | `b3sum`: not installed. roc-fuzz 0.4.3 platform asset: 10 MB. A committed `.tar.zst` fixture: binary in the repo, the script downloads it. |
| D6 | 2 more L1 targets than TESTING.md 4 names: `leading-ones` and `canonical` | Only `roundtrip` and "never crashes". `canonical` follows from BTC (no leading digit 0 after the leading `1`s), so each valid text is the one encode result. The human can drop it. |
| D7 | `decode-total` checks the error index against a simple oracle (first byte not in the alphabet), with a prefix of alphabet characters so that some inputs are valid | Random `Fuzz.str` only: almost no input is valid |
| D8 | The `hex` helper is in 2 test files (6 lines each) | A shared module in `tests/`: `scripts/test.sh` runs each `tests/*.roc` as a test app |
| D9 | The test runner is `scripts/test.sh` (the brief) | `scripts/all_tests.sh` (LAYOUT.md 1) |
| D10 | The decode limit: 1024 bytes, fixed, `TooLong(length)`, checked first (Output table) | 512 bytes (too near the 348-byte Bitcoin Core vector); a limit in data bytes (decode does not know it before it works); an exposed constant `max_text_len` (a constant cannot be a red stub); a parameter `decode_max(text, n)` (more API); `TooLong` with no payload |
| D11 | The fuzz inputs are cut to the limit: `roundtrip` to 749 bytes, `canonical` to 1024 bytes. `decode-total` checks `TooLong` too. | Reject (`Fuzz.reject`) a long input: then `roundtrip` must call `encode` to know |
| D12 | `.roc-version` is `nightly-2026-10-15-38e6c42`, the latest | 10-14: L1 runs there, but the human asked for the latest |

## Out of scope

| Item | Where |
| --- | --- |
| Hashing (BLAKE3 of a file) | Builtin `Crypto.BLAKE3` (R-GA3), the caller |
| A check that a name is 32 bytes | The caller (Talon R-DI4 decodes and checks the length) |
| Other alphabets (Flickr, Ripple), Base58Check (checksum) | Not in R-PK3 |
| Bundle and release | `workflows/release.yml`, after the review |

## Questions (stop until answered)

None.

## Settled

| # | Question | Answer (human review, 2026-10-16) |
| --- | --- | --- |
| B58-Q1 | Does `decode` need a length limit? Bitcoin Core `DecodeBase58` has `max_ret_len`. Decode of n characters costs about n^2 steps, and the Worker can decode untrusted text. | Yes. The value, the API shape and the error tag are TW24 proposals (Output table, D10). |

## Design gaps

| Row | Gap | Proposed change |
| --- | --- | --- |
| R-PK3 (Design 6.1) | "Bitcoin alphabet" only. The leading-zero rule, the errors, whitespace and the length limit (B58-Q1) are not stated. | Spec cell: "Bitcoin base58: the alphabet, each leading zero byte is one leading `1`. Decode rejects a text of more than 1024 UTF-8 bytes with `TooLong(length)` (checked first), and each byte outside the alphabet (also whitespace) with `InvalidChar(index)` of the first bad byte." D2 and D3 are accepted. The limit part waits for the acceptance of D10. |
| `workflows/ci.yml`, `release.yml` | `TEST_PATHS: package/main.roc`, so CI runs no `tests/*.roc` app. The fuzz run has no `--time=0` (LAYOUT.md 3: `--time` has a default of 60 s). | `TEST_PATHS` as a glob of `tests/*.roc`, or CI calls `scripts/test.sh`. Add `--time=0`. |

## Proposed first version

`0.1.0`. Reason: the limit is a proposal (D10), and no user has the API yet. Below 1.0, the series is `0.minor` (Design 2), so a later API change is `0.2.0`. Move to `1.0.0` when the human accepts the API and Talon uses it.

## Disputes (from the code agent)

## Verify results

Verify agent, 2026-10-16. Binary `nightly-2026-10-14-38a3029`. `package/` was copied before step 1 and compared after the last step: `diff -r` gives no difference. The fuzz corpus `.roc-fuzz/` was put back to its state after step 1.

| Step | Result |
| --- | --- |
| 1 `scripts/test.sh` (clean `.work`) | Exit 0, `ALL PASSED`. `tests/base58.roc` 42 passed, `tests/bitcoin_vectors.roc` 42 passed, `tests/roc_hashes.roc` 5 passed. Each of the 4 fuzz targets: 100000 runs, seed 1, no crash. |
| 2 `roc check package/main.roc` | `No errors found`, no warning |
| 3 `roc bundle` | `dist/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst` (1588 bytes). Files: `main.roc`, `Base58.roc`. Only package files. |
| 5 grep `package/` for `talon registry probe evidence compat` | No match (R-GP1) |

Step 4: one mutation at a time in `package/Base58.roc`, then all 3 `tests/*.roc` and the 4 fuzz targets (20000 runs, seed 1). Lines are the failed `expect` lines. Caught: 19 of 19 by L0.

| # | Mutation (rule) | Line | L0 failed (`tests/base58.roc` lines, other files) | L1 failed |
| --- | --- | --- | --- | --- |
| M1 | Alphabet order: `A` and `B` swapped (BTC alphabet) | 48 | 27, 30; bitcoin_vectors 8; roc_hashes 4 | none |
| M2 | Encode: no `1` for a leading zero byte (BTC) | 12 | 27, 33, 49 to 51; bitcoin_vectors 7; roc_hashes 48 | canonical, leading-ones, roundtrip |
| M3 | Encode: one `1` too many for leading zero bytes (BTC) | 16 | 27, 33, 49 to 51; bitcoin_vectors 7; roc_hashes 48 | canonical, leading-ones, roundtrip |
| M4 | Decode: no zero byte for a leading `1` (BTC) | 67 | 30, 54 to 57, 87, 88; bitcoin_vectors 7; roc_hashes 48 | canonical, roundtrip |
| M5 | Decode: each digit 0, not only the leading ones, is a zero byte (`z1`) | 65 | 38, 42, 57, 105; bitcoin_vectors 5; roc_hashes 3 | canonical, roundtrip |
| M6 | `InvalidChar(index + 1)` (TW24 index) | 40 | 60 to 84 (17 lines), 97, 100 | decode-total |
| M7 | `find_last_index`: the last bad byte (TW24 first byte) | 39 | 78, 79, 82 to 84, 100 | decode-total |
| M8 | Decode trims whitespace at the start and the end (D3) | 38 | 72 to 74 | decode-total |
| M9 | Decode skips a space inside (D3) | 38 | 72, 73, 75 | decode-total |
| M10 | Limit `>` to `>=`: 1024 bytes rejected (B58-Q1) | 35 | 87, 88, 97, 100 | not caught |
| M11 | Limit 1025: 1025 bytes accepted (B58-Q1) | 52 | 91, 94, 101 | not caught |
| M12 | `TooLong(1024)`, not the length (B58-Q1) | 36 | 91, 94, 101 | not caught |
| M13 | Limit counts characters, not UTF-8 bytes (B58-Q1) | 34 | 101 | not caught |
| M14 | Alphabet check before the length check (B58-Q1 order) | 34 to 43 | 94, 101 | not caught |
| M15 | Encode `[]` gives `1` (empty input) | 16 | 45; bitcoin_vectors 49 | canonical, leading-ones, roundtrip |
| M16 | Decode `""` gives `Err(InvalidChar(0))` (empty input) | 38 | 46; bitcoin_vectors 50 | canonical, decode-total, roundtrip |
| M17 | Encode: least significant digit first (no `rev`) | 14 | 37, 41, 51, 105; bitcoin_vectors 15; roc_hashes 3 | canonical, leading-ones, roundtrip |
| M18 | Decode: bytes little-endian (no `rev`) | 67 | 42; bitcoin_vectors 14; roc_hashes 3 | canonical, roundtrip |
| M19 | `mul_add`: `while $carry > radix`, so a last digit is lost | 81 | 13 lines; bitcoin_vectors 36; roc_hashes 5 | canonical, leading-ones, roundtrip |

Gap (L1 only). `fuzz/decode-total.roc` has a `TooLong` branch (D11), but M10 to M14 do not make it fail, also at 100000 runs (seed 1, the `scripts/test.sh` default). M12 fails for each text of more than 1024 bytes, so the fuzz input never has more than 1024 bytes: the `TooLong` branch is not reached. The L0 limit tests (lines 87 to 101) catch all 5. Proposed change for the test agent: make long inputs, for example repeat the digit prefix to a length from the input, or set `-max_len` and a long seed in the corpus.

Note. M13 is caught by only one test (line 101). M1 has no L1 check, because the fuzz targets do not know the digit values (expected: L0 checks the alphabet).
