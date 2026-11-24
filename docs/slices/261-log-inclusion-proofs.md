# 261 The client checks inclusion proofs against the registry log

Phase: P3 exit "Client checks inclusion proofs" (`DESIGN.md:539`), built in P2 on the user's order (2026-11-23: the first public release has this check). Status: 261a done (2026-11-24): `roc-ed25519` 0.1.0 is released, `https://github.com/Karakatiza666/roc-ed25519/releases/download/0.1.0/HrAdxCQXofHbDHhgxv6qywS5hozKum4dpEu3dn34h8op.tar.zst`; Talon names it by this URL only (R-GP3). Next: 261b, the `Tlog` reader functions in `packages/records` (Q636 (14)) (section 12.6). The user approved the slice on 2026-11-23 (Design Q640): all recommended answers Q261-1 to Q261-14 (Q261-1 (a), Q261-4 (b)) and all texts T1 to T8b with the `--json` details. TalonRegistry recorded Q640 and the rule ids: R-LV1 to R-LV12 in DESIGN-CLI.md section 7.6 (R-LV1 releases, R-LV2 leaf and URL, R-LV3 proof, R-LV4 signature, R-LV5 keys, R-LV6 kept checkpoint, R-LV7 copies, R-LV8 when, R-LV9 reads again, R-LV10 consistency, R-LV11 exits, R-LV12 output), R-EV30 (`TALON_LOG_KEY`), R-IX8 (the log copies), R-PK10 (`roc-ed25519`). The Talon-side tests (261b to 261d) name these ids.

Change of the user (2026-11-23, after the approval): SHA-512 and Ed25519 verify are NOT in `packages/records`. They are the new generic package `roc-ed25519` (Design 6.1, R-GP1 to R-GP7, R-PK10), in its own repository `https://github.com/Karakatiza666/roc-ed25519` (local: `/home/george/dev/Karakatiza666/roc-ed25519`). Talon uses it by release URL only, after its first release (R-GP3); during development the developer uses `--replace-dep` (R-GP4). The package has its own L0 and L1 tests and CI on the nightly that Talon pins. The live checkpoint vector (size 386) stays on the Talon side (261b `TlogTest`).
Design ids (given by the manager): slice 261, Design Q640, G-C270. This slice answers Design Q636 (15) ("the verifier key in `tln` is a `tln` setting with a built-in default (a CLI slice)") and uses Q636 (14) / Q257-14 ("the tlog math is in `packages/records`, so `tln` checks proofs with the same code").
Registry side: slice 257 (`docs/slices/257-log-tiles.md`), live since 2026-11-23.

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-SE2 (Design 8, `DESIGN.md:572`) | "Registry maps a label to a bad hash for some users: append-only log with signed checkpoints and inclusion proofs (P3). The header keeps the hash, and later builds do not ask the registry." The client part is this slice. |
| Design 7, P3 exit (`DESIGN.md:539`) | "Client checks inclusion proofs." |
| R-SE11 (Design 8) | "From P2, each compiler asset is a log leaf (Registry 3) [...] P3 adds inclusion proofs for these leaves." Q261-3 asks if this slice does it. |
| Design Q636 (14), (15) | The tlog math is in `packages/records` (14). The verifier key in `tln` is a `tln` setting with a built-in default (15). The name, the form and the scope of the setting are not given: Q261-4. |
| R-SG2 (Registry 3) | The leaf at D1 `idx` i is the tlog leaf at index i - 1; the tree size is `MAX(idx)`. Entry bytes `<grp> <version> <hash> <time>\n`; leaf hash `SHA-256(0x00 ‖ entry)`. |
| R-SG3 (Registry 3) | A compiler leaf: group `roc-lang/nightlies:<target>`, version the tag, hash `sha256:<hex>`. |
| R-SG4 (Registry 3) | Tiles in the C2SP tlog-tiles layout, tile height 8, partial tiles kept, entry bundles written. Checkpoint: C2SP tlog-checkpoint, origin `registry.roc-talon.org/log`, no extension line, C2SP signed note, Ed25519 (type 0x01). |
| R-SG8 row 1 (Registry 3) | `grp` is the URL form of the group (R-AP15). `version` is `Semver.to_str` (R-IK5). `hash` is the base58 hash. |
| R-AP11 (Registry 4) | `GET /log/checkpoint` (`max-age=5`), `GET /log/tile/...` (`immutable`). 404 also for the checkpoint before the first leaf. No client version check. A query string, `no-cache` and `Range` are ignored. |
| R-AP23 (Registry 4) | The checkpoint is `text/plain; charset=utf-8`; the tiles are `application/octet-stream`. |
| R-AP18, R-IK6 (Registry 4, 5.1) | Each release row has its `log_index`; it never changes; `log_index <= log_size` in one answer. |
| R-RG7 (CLI 1) | The base URL form of the registry: the one text of the registry, also the dir of its index copies (R-IX1). The Worker serves `/log/...` at the root of its origin (row 2). |
| R-RG9 row 2 (CLI 1) | After a registry answer is used, a later request with no answer whose answer the command needs stops with exit 15. So a log that does not answer is exit 15 also for the built-in default registry (no fall back to `direct` at that time). |
| R-E6, R-EC15, R-EC16 (CLI 3) | 15 `network`: an error that a later run can fix. 16 `integrity`: a hash or checksum does not match. Q261-10. |
| R-TF4, R-RG7 row 6 (CLI) | A bad value of a known `config.toml` key: exit 19. A bad flag or environment value: exit 2. |
| R-IX1 to R-IX7, R-GC12 (CLI) | The index copies of a registry, `--offline`, `tln cache clean`. The log copies are a new kind of copy: Q261-7, Q261-9. |
| R-PL1, R-HF12 (Design 6.2) | Talon uses basic-cli as it is, with no fork. An effect that basic-cli does not have is a child process. basic-cli 0.26.0 and the Roc builtins have no Ed25519 and no SHA-512 (checked with `search_symbols`: only `Crypto.SHA256` and `Crypto.BLAKE3`). Q261-1. |

DESIGN-CLI.md has no rule about proofs, the log, the verifier key or a checkpoint (grep for `inclusion`, `checkpoint`, `verifier`, `tlog`, `proof` finds only the unrelated "proof" of Resolution R-AL10). So most of the client behavior is new: section 6 has the questions.

## 2. Scope: where the code is today

| Fact | Where | Consequence |
| --- | --- | --- |
| `records` has the log math of the writer: `entry`, `tlog_index` (idx - 1), `leaf_hash`, `node_hash`, `root_of`, `path`, `growth`, `edge`, `grow` (the old root and the new root from the edge tiles), `bundle`, `checkpoint_body`, `key_id`, `signed_note`, `parse_checkpoint` (it does NOT check the signature lines), `parse_signer_key`. Private helpers: `parse_bundle`, `edge_tails`, `peaks_root`, `tile_peaks`. | `packages/records/Tlog.roc` (473 lines), tests in `packages/records/tests/TlogTest.roc` | The reader side is missing: a verifier key parse, the signature check, the entry of one index from a bundle, the tiles of one proof, the inclusion check and the consistency check. |
| No Ed25519 verify and no SHA-512 anywhere in Roc. The Worker signs with WebCrypto (a host call). The CLI platform is basic-cli 0.26.0 (`cli/main.roc`). | `Tlog.roc` line 4: "The Ed25519 signature itself is a host call (WebCrypto, slice 257b)" | Q261-1. This is the largest part of the slice. |
| A release row on the wire has `log_index`, `group` (URL form), `version`, `hash`, `url`. It has NO leaf `time`. | `packages/records/Release.roc` `Row` | The client cannot make the entry bytes by itself. It reads the entry from the entry bundle (`tile/entries/...`) and compares `grp`, `version` and `hash` with the row. Then it hashes the entry bytes. |
| A toolchain row has `tag`, `target`, `sha256`, `log_index`. | `packages/records/Toolchain.roc` | A compiler leaf is `roc-lang/nightlies:<target> <tag> sha256:<sha256> <time>`: the same compare (Q261-3). |
| The live log (read 2026-11-23): the checkpoint has size 386 and verifies with `secrets/log-key-verifier` (`node research/log-key/log-key.mjs verify`: ok). Entry 1 is `github.com/Karakatiza666/roc-semver/releases/download/{v}/ 0.2.0 BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i 1794044326262\n`; compiler entries have the R-SG3 form; a `v{v}` group keeps the `v`. `/log/tile/entries/001.p/130` is 17,758 bytes; `/log/tile/1/000.p/1` is 32 bytes. | `.tmp/s261/` (not kept) | The formats of R-SG2, R-SG3 and R-SG4 are what the registry serves. The live checkpoint text is a good L0 vector (public data). |
| `Fx.http_get!` and `Fx.http_send!` give the body as `Str`. The real Fx returns `Failed("bad body")` for a body that is not UTF-8. | `cli/lib/Fx.roc:69`, `cli/RealFx.roc:198` | A hash tile is binary. A new `Fx` call that gives the body as bytes is needed (section 5, F7). `write_atomic!` and `read_files!` are text too (Q261-7 proposes a text form of the copies). |
| The registry reads: `RegistryCache.get!` (copies of `GET` answers, R-IX2), `ClosureIndex.query!` (the closure, no copy), `FullName.read!` (R-AP1), `RegistryToolchains` (R-AP5, `toolchains.json`). | `cli/lib/RegistryCache.roc`, `ClosureIndex.roc`, `FullName.roc`, `RegistryToolchains.roc` | The log reads are new routes. They do not use the R-IX2 copies (Q261-7). |
| Where a release hash enters the header: the pick of `install`, `add`, `update`, `upgrade`, `init` ends in one funnel: `InstallFlow` step "finish": `InstallWrite.ladder!`, then `InstallWrite.confirm_moves!`, then `InstallWrite.write!` (`cli/lib/InstallFlow.roc:533-539`). `tln tool install`, `tln x` and `tln tool update` pick from R-AP1 (CLI R-SC3); `[tools]` locks pick in `ToolsStep`. Compilers: the sha256 of R-CV3 from `GET /v1/toolchains`. | `InstallFlow.roc`, `InstallWrite.roc`, `ToolsStep.roc`, `RegistryToolchains.roc` | One check point for the header path, before `ladder!` (Q261-6). Tools and compilers have their own points (Q261-2, Q261-3). |
| L2 cases: about 308 cases use the registry `http://127.0.0.1:9`, 95 use `:8`, 17 use the built-in default `registry.roc-talon.org`. | `tests/commands/cases/*/*/fx/http/` | If the built-in key applied to every registry, every L2 case that writes a new value would need a fake log. Q261-4 (b) keeps the `127.0.0.1` cases as they are. |
| L3W (`tests/tools/with-worker.sh`, `worker/tests/serve.mjs`) runs the real Worker at `http://127.0.0.1:8787`. `serve.mjs` has no `LOG_KEY` and no `LOG` bucket today. L4 net cases `rn1`, `rn2` run `tln add` against the live registry. | `tests/scenarios/registry/` | L4 `rn1`/`rn2` will run the real check against the live log with the built-in key (NET=1). An L3W proof case needs a `worker/` change (out of this slice, section 8). |
| A public test key exists: the 257a test key (`research/slice-257a-vectors/vectors.json`: `origin`, `seed`, `public`, `key_id`, `note` of size 257), and `research/log-key/log-key.mjs` signs and verifies with `node:crypto`. | `research/` | The L0 and L2 vectors are made with a test key in the test tools. The real signer is never read. |

## 3. The design of the check (proposal; each open point is a question in section 6)

```mermaid
flowchart TB
    P["pick done: the new values (rows with log_index)"] --> K{"a key for this registry? (Q261-4)"}
    K -->|no| W["ladder, prompts, write (as today)"]
    K -->|yes| C["checkpoint: the kept one if it covers every index (Q261-8), else GET /log/checkpoint"]
    C --> S["signature with the key, origin = key name"]
    S --> CO["consistency with the kept checkpoint (Q261-7)"]
    CO --> T["tiles: the kept copy, else GET /log/tile/..."]
    T --> E["entry at index log_index - 1 equals the row (grp, version, hash; url, Q261-11)"]
    E --> I["leaf hash up the tiles to the signed root"]
    I --> KEEP["keep the checkpoint and the tiles (Q261-9)"]
    KEEP --> W
    S -->|fails| X16["exit 16"]
    CO -->|fails| X16
    E -->|fails| X16
    I -->|fails| X16
    C -->|no answer, behind after the reads (Q261-5)| X15["exit 15"]
```

| # | Item | Proposal | Source |
| --- | --- | --- | --- |
| D1 | Which releases | Each release whose URL the command writes (a new header value, a new `[tools]` lock, a new `tools.json` entry) and whose row came from a registry answer (closure, R-AP1, R-AP13). A value that the header has now is not checked. A candidate that is not chosen is not checked. | R-SE2 sentence 2, Q261-2 |
| D2 | Which leaf | The leaf at tlog index `log_index - 1` (`Tlog.tlog_index`). Its entry in the bundle must have `grp == row.group`, `version == row.version`, `hash == row.hash`, and 4 fields with a decimal `time`. | R-SG2, R-SG8 row 1 |
| D3 | The proof from tiles | The checkpoint of size N with N >= `log_index`. The root of N comes from the tiles of `Tlog.edge(N)` (the method of `grow` for the old root). The entry bundle that holds the index gives the entry; its leaf hash must be the hash at that index in the level-0 tile; each full tile on the path hashes (RFC 6962 MTH of its 256 hashes) to the hash at its place in the tile one level up; the path ends in a tile of `edge(N)`. No hash comes from the registry without a check against the signed root. | C2SP tlog-tiles, RFC 6962 |
| D4 | The signature | The checkpoint text must have a signature line `— <key name> <base64(key id ‖ sig)>` with the name and the key id of the key, and the Ed25519 signature of the note text must verify. Other signature lines (an unknown key, a later witness) are ignored. The origin line must equal the key name (`Tlog.parse_checkpoint(name, text)`). | C2SP signed-note, R-SG4, Q636 (5) |
| D5 | One checkpoint for a command | All leaves of one command are checked against one checkpoint, so one command reads the checkpoint at most once (plus the reads of Q261-5). | (proposal) |
| D6 | Requests | `GET <base>/log/checkpoint` with `User-Agent: tln/<version>` and no other header; `GET <base>/log/tile/<path>` with the same header. Tiles are read one at a time (a proof needs about 3 to 6 tiles for a log under 65,536 leaves). | R-AP11, R-AP45 (no check on log routes, but the agent header is sent on each request) |
| D7 | Where in the flow | After the final pick, before the ladder (downloads, probes), before the prompts (R-NI3) and before any write. Also with `--dry-run` and `--no-check`. | Q261-6 |
| D8 | `direct` | No registry, so no log and no check. `--registry direct` is the way to work while the log is broken. | R-DI14, Q261-12 |

## 4. Tests (plan; the test agent writes them in phase 2 after the answers)

Test vectors never use the real signer (`secrets/log-key-signer` is not read). They are made by a node tool with a fixed test seed: `research/slice-261-vectors/vectors.mjs` (L0, `node:crypto` only, as `research/slice-257a-vectors/vectors.mjs`) and `tests/tools/mk-log.mjs` (L2 fixtures: from a list of leaves it writes `fx/http/<host>/log/checkpoint` and the tiles, signed with the test key, and prints the `TALON_LOG_KEY` line for `fx/env`). The real verifier key (public) is used in one L0 vector: the live checkpoint of 2026-11-23 (size 386).

| Layer | Case | Checks |
| --- | --- | --- |
| L0 | `roc-ed25519/tests/sha512.roc` (generic package) | FIPS 180-4 vectors: empty, `abc`, the 448-bit and 896-bit messages; lengths 111, 112, 127, 128, 239, 240 bytes (padding edges, values from `node:crypto`) |
| L0 | `roc-ed25519/tests/rfc8032.roc`, `roc-ed25519/tests/ed25519.roc` (generic package) | RFC 8032 7.1 TEST 1, 2, 3, 1024, SHA(abc). Fails: a bit changed in the message, in R, in S; S + L (not canonical, rejected as Go `crypto/ed25519`); another key; a public key that does not decode; a signature of 63 or 65 bytes |
| L0 | `packages/records/tests/TlogTest.roc` (new expects) | `parse_verifier_key`: the Go example `PeterNeumann+c74f20a3+ARpc2QcUPDhMQegwxbzhKqiBfsVkmqq/LDE4izWy10TW`, the 257a key, the built-in key; fails: wrong key id, type byte not 0x01, 31/33 key bytes, bad base64, empty name, a name with a space or `+`. `open_checkpoint`: the 257a note (size 257); the live prod note (size 386); fails: wrong origin, size changed, root changed, no signature line of the key, a line of the key with another key id, a bad signature; an extra signature line of another key is ignored. `entry_at` / `parse_entry`: a release entry, a compiler entry, index 0, 255, the last of a partial bundle; fails: 3 or 5 fields, no `\n`, a `time` that is not decimal, an index outside the bundle. `proof_tiles` and `check_inclusion` over trees that the test builds with `grow` from size 0: sizes 1, 2, 3, 7, 256, 257, 511, 65,536, 65,537; indexes first, middle, last; fails: one byte changed in each tile of the proof, a missing tile, the wrong index, a root of another size. `consistency_tiles` and `check_consistency`: 1 to 2, 7 to 256, 256 to 257, 255 to 70,000, equal sizes; fails: a forged old root, same size with another root. |
| L0 | `tests/unit/LogKeyTest.roc` | The key of a registry (Q261-4): the built-in key for `https://registry.roc-talon.org`; none for `http://127.0.0.1:9`; a set key named `127.0.0.1:9/log`; a set key with the built-in name replaces the built-in key; the built-in text equals the line of `secrets/log-key-verifier`; bad setting texts (exit 19 from `config.toml`, exit 2 from `TALON_LOG_KEY`) |
| L0 | `tests/unit/LogProofTest.roc` | D1: the new values of a pick (kept values out, candidates out); D2 and Q261-11: the compare of a row and an entry (release and compiler); Q261-5: the decision after each checkpoint read (`Proved`, `Again(wait)`, `Behind`); the texts of section 7 |
| L2 | `logproof/lp1-add-proof` | `add` with `TALON_LOG_KEY` for `127.0.0.1:9`: `calls.log` has one checkpoint read and the tile reads; `tree.diff` has the kept checkpoint and the tile copies; the header is written | 
| L2 | `logproof/lp2-kept-copies` | Run 2 of the same project (`update` to a release below the kept size): no checkpoint read and no tile read (Q261-8) |
| L2 | `logproof/lp3-bad-signature` | A checkpoint signed by another test key: exit 16, the text T3, the header is not written |
| L2 | `logproof/lp4-entry-differs` | The bundle has another hash at the index: exit 16, T1 |
| L2 | `logproof/lp5-tile-tampered` | A changed hash in a level-0 tile: exit 16, T2 |
| L2 | `logproof/lp6-behind` | Run 1: the checkpoint is behind on read 1 and 2, covers on read 3 (`checkpoint.2`, `.3`): exit 0, 2 `sleep` lines. Run 2: behind on every read: exit 15, T5 |
| L2 | `logproof/lp7-no-answer` | Checkpoint 404, then a timeout: exit 15, T6; a tile 404: exit 15, T6b |
| L2 | `logproof/lp8-fork` | A kept checkpoint (size 5) and a new checkpoint (size 9) that does not contain it: exit 16, T4. Same size, other root: exit 16, T4 |
| L2 | `logproof/lp9-offline` | `--offline` with the kept checkpoint and tiles: exit 0, no request. With no kept proof: exit 15, T7 |
| L2 | `logproof/lp10-no-key` | A registry with no key: no log request (a guard; all old `127.0.0.1` cases are this case) |
| L2 | `logproof/lp11-bad-setting` | `TALON_LOG_KEY=xyz`: exit 2, T8b. `log-key = "xyz"` in `config.toml`: exit 19, T8 |
| L2 | `logproof/lp12-dry-run-json` | `--dry-run` checks too (Q261-6); `--json` of a failure has `error.details` of section 7 |
| L2 | `logproof/lp13-kept-values` | `install` with no change and `update` that changes nothing: no log request (R-SE2 sentence 2) |
| L2 | `logproof/lp14-default-registry` | The built-in registry with `TALON_LOG_KEY=registry.roc-talon.org/log+<test id>+<test key>` (replaces the built-in key): the proof passes |
| L2 | `logproof/lp15-url-differs` | The row `url` is not made from `grp`, `version`, `hash` (Q261-11): exit 16 |
| L2 | `logproof/lp16-tool`, `lp17-compiler` | 261d: `tool install` and a compiler install check their leaves (Q261-2, Q261-3) |
| L3 | `fx/http-bytes` | The real `Fx` call of F7 gives the bytes of a binary body (fake HTTP serves a 32-byte tile with bytes above 0x7F) (TW4) |
| L3 | `registry/lp-add-proof` | `tln add` with the fake HTTP log: exit 0, the copies in the tree |
| L4 | `registry/rn1-add-short`, `rn2-add-closure` (net) | No file change: they now run the real check against the live log with the built-in key |

Old cases that change: the 17 cases on `registry.roc-talon.org` that write a new value get the log requests. The test agent lists them in phase 2 and gives each the fixtures of `mk-log.mjs` and a `TALON_LOG_KEY` override (TW21: only outputs that this slice changes).

Revert check (TW12, only the tricky ones): no signature check; the leaf at `log_index` (no `- 1`); a compare that skips `hash`; the root from the registry tiles with no check of the path; no consistency check; the copies written before the proof passes; the built-in key used for every registry; S >= L accepted; kept header values checked (extra requests).

## 5. Facts that the design gives (no question)

| # | Fact | Source |
| --- | --- | --- |
| F1 | The header keeps the hash, and later builds do not ask the registry: a value that is already in the header is not checked again (D1). | R-SE2 |
| F2 | The leaf form, the tlog index, the tile layout, the tile height, the checkpoint form, the origin and the signature algorithm are fixed. | R-SG2, R-SG3, R-SG4, Q636 (1), (3), (4), (5), (6) |
| F3 | The verifier key is a setting with a built-in default. The default is the public verifier text of `secrets/log-key-verifier`: `registry.roc-talon.org/log+e5942107+AcChrF9eGpi29YDCTnBoS8Jd3xEVR1To+6RRg3korCQy`. | Q636 (15), Q257-15 (c) |
| F4 | The new log math goes in `packages/records`. It builds and passes on both nightlies (TW28). | Q636 (14), Q257-14 |
| F5 | A log that does not answer after the registry answered: exit 15, also for the built-in default registry. | R-RG9 row 2 |
| F6 | With `direct` nothing is checked: there is no log. | R-RG9 row 3, R-DI14 |
| F7 | A new `Fx` call: `http_get_bytes! : { url : Str, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : List(U8) }, [Timeout, Failed(Str)])` (proposal of the form; TESTING 2.3 gets a row). The fake `Fx` answers it from the same `fx/http/` routes and writes `http_get_bytes <url>` to `calls.log`. The real `Fx` gets an L3 case (TW4). | TESTING 2.3, TW3, TW4 |
| F8 | The registry needs no change: the routes, the tiles and the checkpoint are live (slice 257). | Q636 |

## 6. Questions (decided by the user 2026-11-23, Design Q640: every recommendation accepted)

Answers: Q261-1 (a), Q261-2 (a), Q261-3 (a), Q261-4 (b), Q261-5 (a), Q261-6 (a), Q261-7 (a), Q261-8 (a), Q261-9 (a), Q261-10 (a), Q261-11 (a), Q261-12 (a), Q261-13 (a), Q261-14 (a). The tests follow these answers.

| Id | Question | Options | Recommendation and reason |
| --- | --- | --- | --- |
| Q261-1 | (Answer (a), then changed by the user on 2026-11-23: the pure Roc code is the generic package `roc-ed25519`, not `packages/records`.) How does `tln` verify the Ed25519 signature? Roc and basic-cli have no Ed25519 and no SHA-512 (Ed25519 needs SHA-512). Design 6.2 allows no fork. | (a) Pure Roc in `packages/records`: a `Sha512` module and an `Ed25519.verify` (the rules of Go `crypto/ed25519`: cofactorless, S must be below L, the key and R must decode), with the RFC 8032 vectors. About 350 lines. (b) A child process: `openssl pkeyutl -verify -rawin` (OpenSSL 3.0 or later); exit 18 when it is missing. macOS has LibreSSL and Windows has no `openssl`. (c) No signature check: only the tiles against the root of an unsigned checkpoint. (d) An upstream basic-cli PR, and wait for its release. | (a). Reason: it works on each target with no program on `PATH`, it fits R-PL1 and R-HF12, and one verify is a few thousand field multiplications (milliseconds). (b) fails on 2 of the 3 systems. (c) gives no proof: the registry can sign any tree. (d) blocks the first public release. Risk of (a): the speed in `--opt=dev`; 261a measures it. |
| Q261-2 | Which releases are checked? | (a) Each release whose URL the command writes (header, `[tools]` lock, `tools.json`) and whose row came from a registry answer, in all commands that write one (`add`, `install`, `update`, `upgrade`, `init`, `tool install`, `tool update`, `x`, the `[tools]` step). (b) Only header values (no tools). (c) Every release row of each answer. (d) Also the values that the header has now, on each run with a registry. | (a). Reason: R-SE2 is about a label that the client takes from the registry; a tool URL comes from the same rows. (c) costs a tile read per row. (d) contradicts R-SE2 sentence 2. Tools go in sub-slice 261d. |
| Q261-3 | Compiler leaves (R-SE11: "P3 adds inclusion proofs for these leaves")? | (a) In this slice (261d): each compiler that Talon installs with the sha256 of `GET /v1/toolchains` (R-CV3) is checked before the download. (b) A later slice. | (a). Reason: R-SE11 says it, the leaf is in the same log, the compare is 3 fields, and the first public release has the check. |
| Q261-4 | Which key applies to which registry, and the name and form of the setting? The key text names the log (`registry.roc-talon.org/log`), not the URL. | (a) One setting `log-key`; its value (or the built-in key) applies to every registry. (b) Keys: the setting `log-key` in `config.toml` (one verifier text), the variable `TALON_LOG_KEY` (priority over `config.toml`, R-LY4), and the built-in key. A key applies to the registry whose base URL (R-RG7) has the authority `<host>[:<port>]` when the key name is `<authority>/log`. A set key with the name of the built-in key replaces it. A registry with no key: no check and no note. (c) A table `[log-keys]` in `config.toml`, keyed by the base URL. | (b). Reason: the built-in key then applies only to `https://registry.roc-talon.org` (its origin is `registry.roc-talon.org/log`), so a private registry, the bench (`<host>/log`, Q257-5) and the L2 fake registries at `127.0.0.1` are not refused with a wrong key, and old L2 cases do not change. A user who sets a key for a private registry cannot break the default registry. No note, else ~400 L2 outputs change. (a) breaks every other registry. (c) is more text for the same effect. |
| Q261-5 | The checkpoint is behind the release (`log_index` > size). This is normal after an ingest: `tln add` of a new name ingests it (R-AD35), and the tile step runs after the answer, or within 5 minutes by cron. | (a) Read the checkpoint again, up to 3 more times, with `sleep!` 2, 4 and 8 s before them (14 s at most); then exit 15 with T5. (b) Exit 15 at once. (c) Go on with a warning and no proof. | (a). Reason: the step after the answer usually ends in about a second, so (b) would fail the first `add` of most new names. (c) is no check. |
| Q261-6 | When in the flow? Also with `--dry-run` and `--no-check`? | (a) After the final pick, before the ladder, the prompts and the writes; also with `--dry-run` and `--no-check`. (b) After the ladder, before the write; not with `--dry-run`. | (a). Reason: no download or probe of a release that fails the proof; a dry run shows what a real run does; `--no-check` skips probes, not integrity checks (as the hash check). |
| Q261-7 | Does the client check that the log is append-only (a consistency check with a checkpoint that it kept)? The design says "inclusion proofs" only. | (a) Yes: Talon keeps the largest checkpoint that passed. A new checkpoint must contain it (consistency from the tiles); at the same size the root must be equal. A smaller new checkpoint is checked the other way. A fail is exit 16, T4. (b) No: only inclusion. | (a). Reason: with the key on the Worker, inclusion alone lets the registry show each user another tree; a kept checkpoint makes that visible to the user, as the Go checksum database client does. The cost is the same tile reads. |
| Q261-8 | Which checkpoint does a command use? | (a) The kept checkpoint when its size covers every needed `log_index` (no request); else a new read. (b) Always a new read. | (a). Reason: an inclusion proof against an older signed tree is as good; fewer requests; `--offline` works the same way. A new read happens when a release is newer than the kept tree. |
| Q261-9 | Where are the checkpoint and the tile copies kept, and in which form? `write_atomic!` and `read_files!` are text. | (a) The checkpoint (the signed note as served) in the data dir: `$XDG_DATA_HOME/talon/log/<origin dir>/checkpoint` (R-LY7; `tln cache clean` keeps it, so the consistency memory stays). The tiles in the cache: `talon/index/registry/<origin dir>/log/tile/<path>`, as text: a hash tile as one line of 64 lower-case hex digits for each hash; an entry bundle as its entries one after the other (each entry ends in `\n`, and the bytes are UTF-8). Both written only after a proof passes. `<origin dir>` is the name of R-IX1. (b) Both in the cache index dir. (c) Raw bytes, with 2 more new `Fx` calls (read and write bytes). | (a). Reason: no new file `Fx` calls; a tile is immutable, so a copy is never stale; a copy that did not pass is never kept. (b) loses the consistency memory on each `tln cache clean`. |
| Q261-10 | Exit codes. | (a) A bad signature, a failed inclusion, a failed consistency check, an entry that is not the row: 16 `integrity`. No answer, a 404 or 5xx of the checkpoint or of a tile of a signed size, a checkpoint still behind, `--offline` with no kept proof: 15 `network`. A bad setting: 19 (`config.toml`) or 2 (`TALON_LOG_KEY`). (b) A new code 22 `log` for the integrity fails (R-E5: "a new failure kind gets a new code"). | (a). Reason: R-EC16 is "a hash does not match", which is what a failed proof is; a script already treats 16 as "do not trust". A missing tile is a fault that a later run can fix (R-EC15). |
| Q261-11 | Does the client also check the row `url`? A row with a correct leaf and another `url` would write another URL. | (a) Yes: `url` must be `https://` + `grp` with `{v}` changed to `version`, + `hash` + `.tar.zst` (R-ID2, the URL form of R-AP15); else exit 16. (b) No: the header URL comes from `url` as today. | (a). Reason: the leaf proves the group, version and hash; the URL that Talon writes must be made of them, else the proof proves nothing about the header. |
| Q261-12 | An opt-out (a setting value `off`, a flag)? | (a) None. A user whose registry log is broken uses `--registry direct` (no log, no check). A private registry with no key is not checked (Q261-4). (b) `log-key = "off"`. | (a). Reason: an opt-out is a switch that an attacker can ask the user to set; `direct` is already there. |
| Q261-13 | `tln publish` and the leaf of its own release (R-AP8 answers the log index)? | (a) Out of scope. (b) Check it after the publish. | (a). Reason: the publisher is not the user that R-SE2 protects; a user who adds the release checks it. |
| Q261-14 | Output on success. | (a) Nothing: no line and no `--json` member (as the hash check of a download). (b) One line `log: checked <n> releases at size <N>` and `data.log_proof: {size, checked}`. | (a). Reason: no old output changes (R-OUT: a new `data` member is a proposal; a check that passes adds nothing). |

## 7. Output (approved by the user 2026-11-23, Design Q640: T1 to T8b and the `--json` details)

All errors are `tln: error[<kind>]: <text>` (R-E4). `<url>` is the base URL form (R-RG7). `<release>` is `<alias>: <name> <version>` for a header entry (`json: acme/roc-json 2.0.1`), `tool <name> <version>` for a tool, `nightly-<date>-<sha> (<target>)` for a compiler. `<key>` is `<name>+<key id>`. `<source>` is `the built-in key`, `TALON_LOG_KEY`, or `log-key in <path of config.toml>`.

| Id | Case | Exit | Text |
| --- | --- | --- | --- |
| T1 | The entry at the index is not the row (Q261-10) | 16 | `<release>: the log of <url> has another entry at log index <log_index>: <grp> <version> <hash>. Talon wrote nothing.` |
| T2 | The tiles do not give the signed root | 16 | `<release>: the inclusion proof of log index <log_index> does not match the signed checkpoint of <url> (size <N>). Talon wrote nothing.` |
| T2b | The row `url` is not made from the leaf (Q261-11) | 16 | `<release>: the registry <url> gave the URL <url of row>, which is not the URL of its log entry. Talon wrote nothing.` |
| T3 | No valid signature of the key | 16 | `the checkpoint of the log of <url> has no valid signature of <key> (<source>). Talon wrote nothing.` |
| T4 | Not append-only (Q261-7) | 16 | `the log of <url> changed its history: the checkpoint of size <N> does not contain the checkpoint of size <M> that Talon kept on <date> (<path>). Talon wrote nothing. Report this to the registry operator.` |
| T5 | Still behind after the reads (Q261-5) | 15 | `<release> (log index <log_index>) is not in the log of <url> yet: the checkpoint has size <N> after 4 reads. Try again in a few minutes.` |
| T6 | The checkpoint does not answer (no answer, 404, 5xx) | 15 | `the log of <url> does not answer (<cause>): Talon cannot check <release>. Try again later, or use --registry direct.` |
| T6b | A tile of a signed size is missing | 15 | `the log of <url> has no tile <tile path> for size <N> (<cause>). Try again later.` |
| T7 | `--offline`, no kept proof | 15 | `<release> has no kept log proof and --offline is set. Run the command without --offline.` |
| T8 | Bad `log-key` in `config.toml` | 19 | `<path>: line <n>: log-key: '<text>' is not a log verifier key (the form is <name>+<8 hex digits>+<base64 key>)` |
| T8b | Bad `TALON_LOG_KEY` | 2 | `TALON_LOG_KEY: '<text>' is not a log verifier key (the form is <name>+<8 hex digits>+<base64 key>)` |
| - | Success | 0 | No text (Q261-14) |
| - | `<cause>` | | The words of R-RG9 row 5: `timeout`, `status 404`, `status 503`, the text of `Failed` |

`--json` of a failure (R-J7): `error.kind` as the table; `error.details` has `{"log":"<url>/log","reason":<reason>,"size":<N or null>,"index":<log_index or null>,"release":<the release URL or the compiler tag, or null>}`. `reason` is one of `entry-differs`, `not-included`, `url-differs`, `bad-signature`, `not-consistent`, `behind`, `no-answer`, `tile-missing`, `offline`, `bad-key`. The member order is as written.

Example (T5):

```text
tln: error[network]: json: acme/roc-json 2.0.1 (log index 391) is not in the log of https://registry.roc-talon.org yet: the checkpoint has size 386 after 4 reads. Try again in a few minutes.
```

## 8. Out of scope

| Item | Why |
| --- | --- |
| Witnesses, cosignatures, a monitor, gossip of checkpoints | Not in the design (slice 257 section 8) |
| Key rotation of the log | Not in the design (257e: one prod key for the life of the log). Q261-4 (b) lets a user replace the built-in key by a set key with the same name. |
| `tln publish` (Q261-13), `outdated`, `audit`, `verify`, `list`, `why` | They write no new release URL |
| `--snapshot log:N` against a checkpoint | The snapshot hides releases above N as today (R-AP19); the proof of a chosen release is the same |
| An L3W case with the real Worker | `worker/tests/serve.mjs` has no `LOG_KEY` or `LOG` bucket; a later registry-side change (a test key with the origin `127.0.0.1:8787/log`) enables it |
| Changes in `worker/` | None needed (F8) |

## 9. Sub-slices and size

| Sub-slice | Content | Code lines (estimate) | Tests |
| --- | --- | --- | --- |
| 261a `roc-ed25519` generic package | Its own repository (R-GP1 to R-GP7, R-PK10): `package/Sha512.roc`, `package/Ed25519.roc` (verify only), L0 `tests/*.roc`, L1 `fuzz/*.roc`, `scripts/vectors.mjs`, CI, the first release (by the user). Talon then adds the release URL to `packages/records/main.roc` or `cli/` (261b decides where `Tlog.open_checkpoint` calls it) | 350 | 41 expects, 3 fuzz targets; a speed measure |
| 261b Tlog reader | `Tlog`: `parse_verifier_key`, `open_checkpoint`, `entry_at`, `parse_entry`, `proof_tiles`, `check_inclusion`, `consistency_tiles`, `check_consistency` | 200 | ~60 expects |
| 261c Header check | `cli/lib/LogKey.roc` (the key of a registry, the setting), `cli/lib/LogProof.roc` (pure: D1, D2, Q261-5, Q261-11, texts), `cli/lib/LogCheck.roc` (`check!`: reads, copies), the `Fx` call F7 (real and fake), the hook in `InstallFlow` before `ladder!`, `ConfigToml` key `log-key`, `TALON_LOG_KEY`; `tests/tools/mk-log.mjs` | 380 | ~25 expects, L2 `lp1` to `lp15`, L3 2 cases, the 17 default-registry cases |
| 261d Tools and compilers | The check in the tool flows and before a registry compiler download (Q261-2, Q261-3) | 120 | L2 `lp16`, `lp17` |

Total about 1,050 lines of code, in 4 sub-slices of at most 400 (TW19). Order: 261a and 261b (both pure, in parallel), then 261c, then 261d. Model: Opus for 261a (field arithmetic) and 261b, Sonnet for 261c and 261d.

## 10. Design text changes (for TalonRegistry, after the answers)

| Spot | Old | New (with the recommended answers; the exact text follows the user's answers) |
| --- | --- | --- |
| `DESIGN.md` R-SE2 | `... inclusion proofs (P3). The header keeps the hash ...` | `... inclusion proofs (built in P2 on the user's order, CLI 7.6, Design Q640). The header keeps the hash ...` |
| `DESIGN.md` R-SE11 last sentence | `P3 adds inclusion proofs for these leaves.` | `Talon checks the inclusion proof of the leaf of each compiler that it installs from a registry, before the download (CLI 7.6, Design Q640).` |
| `DESIGN.md` Design 7 P3 row | `Client checks inclusion proofs.` (exit) | The same, with `(built on the user's order, Design Q640)` |
| `DESIGN.md` R-PL1 / R-HF12 | none | One row: `Ed25519 verify and SHA-512: none in basic-cli or the builtins. Pure Roc in the generic package roc-ed25519 (R-PK10, Design Q640).` |
| `DESIGN.md` 6.1, R-GP1 (the fixed list of generic packages) | `roc-semver`, `roc-base58`, `roc-toml`, `roc-app-header`, `roc-tar` | add `roc-ed25519` |
| `DESIGN.md` R-PK table, new row R-PK10 | none | `R-PK10 | roc-ed25519 | SHA-512 (FIPS 180-4) and Ed25519 verify (RFC 8032, the checks of Go crypto/ed25519), pure Roc. API: Sha512.hash : List(U8) -> List(U8); Ed25519.verify : { public_key, message, signature } -> Bool. Used by the log proofs (CLI 7.6) by release URL (R-GP3).` |
| `DESIGN.md` Q640 item (1) | `(1) pure Roc Sha512 and Ed25519 verify in packages/records` | `(1) pure Roc SHA-512 and Ed25519 verify in the new generic package roc-ed25519 (own repository, R-GP1 to R-GP7, R-PK10; changed by the user 2026-11-23); Talon uses it by release URL after the first release` |
| `CLAUDE.md` (Talon) generic package list | `roc-semver`, `roc-base58`, `roc-toml`, `roc-app-header`, `roc-tar` | add `roc-ed25519` (a file of the user: the manager asks first) |
| `DESIGN.md` Q636 row, item (15) | `(15) The verifier key in tln is a tln setting with a built-in default (a CLI slice).` | The same, and `Done by CLI slice 261 (Design Q640).` |
| `DESIGN.md` new row | none | `Q640 | G-C270: the client check of inclusion proofs (CLI slice 261)? | Decided by the user, <date> (docs/slices/261-log-inclusion-proofs.md, Q261-1 to Q261-14): ...` |
| `DESIGN-CLI.md` new section 7.6 "Log proofs" | none | Rules R-LV1 to R-LV12 (ids proposed by this file; TalonRegistry records them with Q640): D1 to D8 of section 3, the key rule of Q261-4, the reads again of Q261-5, the consistency of Q261-7, the kept checkpoint of Q261-8, the copies of Q261-9, the exit codes of Q261-10, the URL check of Q261-11, no opt-out (Q261-12), the texts of section 7 |
| `DESIGN-CLI.md` R-LY3 `config.toml` example | none | `log-key = "<name>+<key id>+<base64>"   # a log verifier key (7.6, R-LV). Not set: the built-in key of https://registry.roc-talon.org.` |
| `DESIGN-CLI.md` environment variables (R-EV) | none | `R-EV30`: `TALON_LOG_KEY`: a log verifier key, priority over `log-key` of `config.toml` (7.6). A bad value: exit 2. |
| `DESIGN-CLI.md` R-LY1, R-LY2 trees | none | `talon/index/registry/<origin>/log/tile/` (cache, tile copies) and `$XDG_DATA_HOME/talon/log/<origin>/checkpoint` (data, the kept checkpoint) |
| `DESIGN-CLI.md` R-IX table | none | `R-IX8`: the log copies (Q261-9); `--offline` proves from them (R-IX6). |
| `DESIGN-CLI.md` R-GC12 | `talon/index/` and `talon/x/` | The same (the tile copies are in `talon/index/`); `the kept checkpoint (data dir) stays`. |
| `DESIGN-CLI.md` CLI 3 exit table, sources of R-EC15 and R-EC16 | `7.1, 7.3, R-E6` / `7.1, 6.2 R-CV4 and R-CV6, Design 8` | add `7.6` to both |
| `DESIGN-CLI.md` output catalog | none | The texts T1 to T8b and the `error.details` members of section 7 |
| `DESIGN-REGISTRY.md` R-AP11 | `From R2` | add: `tln reads the checkpoint and the tiles to check inclusion proofs (CLI 7.6).` |
| `TESTING.md` 2.3 `Fx` table | none | One row: `http_get_bytes!`: a `GET` whose body is bytes (the log tiles, CLI 7.6). L3 case `fx/http-bytes`. |

## 11. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 261 | The client checks inclusion proofs | Tests for R-SE2, R-SE11 (client), Q636 (14) (15). `Sha512.hash`, `Ed25519.verify` in the generic package `roc-ed25519` (R-PK10); the `Tlog` reader functions in `packages/records`; `LogKey`, `LogProof`, `LogCheck` in `cli/lib`; the setting `log-key` / `TALON_LOG_KEY` with the built-in key; the `Fx` call `http_get_bytes!`; the check before the ladder, in the tool flows and before a registry compiler download. Sub-slices 261a to 261d. | R-SE2, R-SE11, R-SG2, R-SG3, R-SG4, R-AP11, R-RG9, R-EC15, R-EC16, R-IX6, R-LV1 to R-LV12, R-EV30, R-IX8, R-PK10 | G-C270 (Design Q640, Q636 (14) (15)) | none / 257 | 1050 | Opus (261a, 261b), Sonnet (261c, 261d) |

## 12. 261a: the generic package `roc-ed25519` (test agent, 2026-11-23)

Local repository `/home/george/dev/Karakatiza666/roc-ed25519` (`git init -b main`, `origin` = `git@github.com:Karakatiza666/roc-ed25519.git`; no commit, no push, no tag, no release). The layout is the layout of `roc-base58`.

| File | What |
| --- | --- |
| `package/main.roc` | `package [Ed25519, Sha512] {}` |
| `package/Sha512.roc` | Stub: `hash : List(U8) -> List(U8)`, body `crash "todo"` |
| `package/Ed25519.roc` | Stub: `verify : { public_key : List(U8), message : List(U8), signature : List(U8) } -> Bool`, body `crash "todo"`. The doc comment has the rules of Go `crypto/ed25519`. |
| `tests/sha512.roc` | 17 expects: FIPS 180-4 empty, `abc` (one block), the 896-bit message (two blocks); a length guard; 13 lengths at the padding edges and long inputs (1000, 8192 bytes) |
| `tests/rfc8032.roc` | 6 expects: the 5 vectors of RFC 8032 7.1 (TEST 1, 2, 3, 1024, SHA(abc)), and a guard of the table |
| `tests/ed25519.roc` | 18 expects: S + L (high bits 0), S = L, a high bit of S, a changed S, a changed R, an R that is not a point, an A that is not a point, a changed A, another key, a changed message, one more message byte, the signature of another message, each of 16 message bits, signatures of 63 and 65 bytes, keys of 31 and 33 bytes, all empty; a guard (the vectors are valid) |
| `fuzz/verify-total.roc`, `fuzz/verify-tamper.roc`, `fuzz/sha512-total.roc` | L1 (roc-fuzz 0.4.3): verify never crashes and a random signature is false; one changed bit of TEST 3 is false; SHA-512 gives 64 bytes, the same twice, another digest with one more byte |
| `scripts/vectors.mjs`, `scripts/rfc8032-7.1.txt` | The vector maker (`node:crypto`, BigInt): it checks each vector against node and prints the Roc constants |
| `scripts/test.sh`, `.github/workflows/ci.yml`, `release.yml`, `.roc-version`, `.gitignore`, `LICENSE` | Copies of `roc-base58` (the license names `roc-ed25519`) |
| `README.md` | The API, the rules, the tests, the release |

Not in the generic package: a small-order public key or R is not rejected, because Go does not reject it (cofactorless). The live checkpoint vector is Talon data: `research/slice-261-vectors/checkpoint-386.txt` and `live.mjs` (it checks the signature with `node:crypto` and prints the note, the public key and the signature in hex, for 261b).

Red state (`$ROC` = `nightly-2026-10-14-38a3029`, capped scope): `roc check` passes for `package/main.roc` and each test app, also with the worker nightly `nightly-2026-11-06-34f137a`; `roc fmt --check package tests` passes. `roc test`: `tests/sha512.roc` 0 pass, 17 fail; `tests/rfc8032.roc` 1 pass (the table guard), 5 fail; `tests/ed25519.roc` 0 pass, 18 fail. Each failure is the crash `todo`.

### 12.1 Disputes (code agent, 2026-11-23)

Status: D1, D2 and D3 are fixed (section 12.2, the user's decisions of 2026-11-23). D3: roc-fuzz 0.7.0 on nightly 03dce41 (the Talon pin, R-GP5); each fuzz run has the time limit `FUZZ_TIME` (120 s), as roc-semver.

The code agent did not change a test. These need the test agent or the human.

| # | File | Problem | Proposal |
| --- | --- | --- | --- |
| D1 | `fuzz/verify-total.roc` | The property "a random signature is always false" is wrong for Go rules. With `key_full = 1` and `sig_full = 1`, a short or empty `key` and `sig` become 32 and 64 zero bytes. The zero key decodes (y = 0, x = sqrt(-1), even): it is a point of order 4, and its encoding is 32 zero bytes. R = 32 zero bytes, S = 0, so the check is: encoding of -[k]A = R. When k = 3 mod 4, -[k]A = A, and the encodings are equal: Go accepts this signature (cofactorless, no small-order check). About 1 message in 4 does this. The fuzzer finds it in fewer than 2,000 runs on each compiler (for example `{ key: [], key_full: 1, message: [221, 7, 56, 20, 0, 10], sig: [], sig_full: 1 }`; Python: SHA-512(64 zero bytes ‖ message) mod L mod 4 = 3). A probe (`.work/probe/probe.roc`, not in git) confirms `verify(zeros 32, [9], zeros 64)` is true and `verify(zeros 32, [0], zeros 64)` is false, as Go gives. | Pad with a nonzero byte, or skip (`Fuzz.keep`) a key that is a small-order point, or change the property to "never crashes" only for the all-zero case. Optionally add an L0 expect for this Go-compatible accept, so the behaviour is fixed on purpose. |
| D2 | `tests/ed25519.roc`, `fuzz/verify-total.roc`, `fuzz/verify-tamper.roc` | `roc fmt --check` fails with `nightly-2026-11-06-34f137a` and `nightly-2026-11-13-03dce41`: the newer formatter puts parentheses around the condition of a one-line `if` (for example `if j == i b.bitwise_xor(...)` becomes `if (j == i) ...`). It passes with 10-14. | Write each one-line `if` condition in parentheses. The parenthesized form passes `roc fmt --check` on 10-14 and the newer nightlies (the package code uses it). |
| D3 | (not a test) roc-fuzz 0.4.3 | With `nightly-2026-11-13-03dce41`, `roc build --fuzz` fails for all 3 targets: `ld.lld: relocation R_X86_64_32 cannot be used against symbol 'main'; recompile with -fPIC` (the `targets/x64musl/libfuzzer.a`, `crt1.o` and `libc.a` of the platform are not PIC). 10-14 and 11-06 link. So the CI fuzz job fails on 03dce41 until roc-fuzz has a release for it. | Human decision: a newer roc-fuzz release, or fuzz in CI with an older nightly, or no L1 in CI for now. |

### 12.2 Test-side answers to D1 to D3 (test agent, 2026-11-23, the user's decisions)

| # | Change |
| --- | --- |
| D1 | `fuzz/verify-total.roc`: the pad byte is 0x55 (not 0), and the property skips a small-order key (the 7 encodings of a y of a point of order 1, 2, 4 or 8, canonical and non-canonical, with the sign bit ignored; each checked with BigInt: 8 P = identity). `tests/ed25519.roc` has 3 new `GO` expects that record the Go-style accepts on purpose: the zero key with the zero signature verifies `[9]` and not `[0]` (as the probe of the code agent); a non-canonical key (`ee ff ... ff 7f`, y = p + 1 = 1) is accepted. The expected values come from a BigInt reference of the Go rules (a test tool, not kept). The README says that this matches Go. |
| D2 | Each one-line `if` condition has parentheses. `roc fmt --check package tests fuzz` passes on 10-14, 11-06 and 03dce41. |
| D3 | roc-fuzz 0.7.0 (`HBigHQhVZWEF2EkLxpYK35u8P6UNsAmPYxpNFTxXK1Br`): the 3 targets have the new URL, `parser_for : _` and `encoder_for : _` on each `Input` (0.7.0 needs them for the corpus encoding), and declared `examples`. `scripts/test.sh` and `ci.yml` use `run --runs --seed --time=0 --report-dir` (0.7.0 has no `--artifact-dir`). With 03dce41: each target builds and passes 2,000 runs (seed 1). With 10-14 and 11-06: the targets build, and the executable crashes at once (segmentation fault). The release notes name `nightly-2026-11-18-a520eed` for the roc-fuzz tooling and say that no compiler is pinned. So L1 with 0.7.0 needs 03dce41 or later; `.roc-version` and `ROC_NIGHTLY` in the CI files are still 10-14 (not changed: a decision of the user). |

L0 after these changes: 44 expects (`sha512` 17, `rfc8032` 6, `ed25519` 21), all pass on 10-14, 11-06 and 03dce41.

### 12.3 Mutation check of `roc-ed25519` (test agent, 2026-11-23, the user's order)

`research/slice-261a-revert/` (`mutate.sh`, `RESULT.md`, the helper tools). 10 mutants on nightly 03dce41, mirror copies under `.tmp/ed-mut/`. A mutant is killed only by a failed test (a compiler warning does not count). 9 killed, 1 survived:

| Mutant | Result |
| --- | --- |
| no S < L check, no length check, k not reduced mod L, +A instead of -A, the sign bit of x ignored, a SHA-512 round constant, the length field in bytes, a rotation 41 to 40 | killed by the first tests |
| R compared on 31 bytes | survived at first; killed by a new test (the zero key, S = 0, R = 31 zero bytes then 0x80, message [0]) |
| a non-point key decoded with the wrong root (not rejected) | survived: not equivalent in theory (an invalid-curve key), but no killing input was found (a replica search, and the order-8 construction does not exist for the Ed25519 d). For Talon the key is fixed and valid. RESULT.md has the details. |

`tests/ed25519.roc` now has 23 expects (44 + 2 = 46 L0 expects in all); they pass on 10-14, 11-06 and 03dce41, and `roc fmt --check` passes on the three.

### 12.4 `Ed25519.is_valid_public_key` (the user's choice for the survivor, test agent, 2026-11-23)

API change before 0.1.0: `Ed25519.is_valid_public_key : List(U8) -> Bool` (README): 32 bytes that decode to a point by the decode of `verify` (Go rules). Stub `crash "todo"` in `package/Ed25519.roc`; the code agent writes the body. New L0 file `tests/key.roc`, 9 expects: the 5 RFC keys; the y values 2, 7, 8, 11, 12, 13 with no x (with and without the sign bit), p - 2, p + 2; the 7 small-order encodings, x = 0 with the sign bit, an RFC key with the sign bit changed (True); lengths 31, 33, 0 (False). Red: 0 pass, 9 fail (`todo`) on 10-14, 11-06 and 03dce41; the other 46 expects pass; `roc fmt --check` passes. `mutate.sh` fills the stub in the mirror with a reference body (32 bytes and `decode_point` gives `Ok`): the reference passes all files, and the mutant `non-point-a-valid` is now killed by `tests/key.roc` (4 failed). All 10 mutants are killed. The Talon-side check (261b) can call `is_valid_public_key` on the setting key (exit 19 or 2 for a key that is not a point) after the release.

### 12.5 CI finding of `verify-tamper` (commit a7ff849, run 45250196569; test agent, 2026-11-23)

The finding is a wrong test property, not a code bug. The input is `{ bit: 247, part: 39, pos: 0 }`. The generator makes `part` in 0 to 2 and `bit` in 0 to 7, but the fuzzer also decodes mutated corpus inputs with any `U8`. `part` 39 went to the signature branch, and bit 247 has no entry in the bit table, so `flip_bit` changed nothing: the unchanged RFC 8032 TEST 3 vector verified, as it must (Go and node:crypto accept it too). Fix: `part % 3` and `bit % 8` in `fuzz/verify-tamper.roc`, and the input is kept as the example `out-of-range-fields`. Check: all 784 single-bit changes of TEST 3 are rejected by node:crypto (`research/slice-261a-revert/flips.mjs`); 2 new L0 expects in `tests/ed25519.roc` (each of the 256 key bits and each of the 512 signature bits, 25 expects in the file). The artifact replays as `finding` before the fix and `passed` after; the CI form (100,000 runs, seed 1, `--time=120`) passes locally on 03dce41.

### 12.6 261a done, next step (2026-11-24)

`roc-ed25519` 0.1.0 is released (CI on d5e1b9c passed, the release workflow passed). Asset: `https://github.com/Karakatiza666/roc-ed25519/releases/download/0.1.0/HrAdxCQXofHbDHhgxv6qywS5hozKum4dpEu3dn34h8op.tar.zst`. API: `Sha512.hash`, `Ed25519.verify`, `Ed25519.is_valid_public_key`. Talon uses it by this release URL only, never a path entry (R-GP3; `--replace-dep` only while a developer works on a new version, R-GP4). The README usage line has the URL (local commit 4401efb in roc-ed25519).

Next: 261b, the `Tlog` reader functions in `packages/records/Tlog.roc` (the tlog math is there, Q636 (14), TalonRegistry's module): `parse_verifier_key`, `open_checkpoint` (it calls `Ed25519.verify` of the release above, and can use `Ed25519.is_valid_public_key` for the key), `entry_at`, `parse_entry`, `proof_tiles`, `check_inclusion`, `consistency_tiles`, `check_consistency` (section 9 row 261b, section 4 L0 rows). The live checkpoint vector is `research/slice-261-vectors/` (`checkpoint-386.txt`, `live.mjs`). Open point for 261b: `packages/records` must build on both nightlies (TW28), so its header needs the `roc-ed25519` release URL as a dependency; the scope of 261b checks that the release builds on the worker pin too, or puts `open_checkpoint` in `cli/lib` (a question for the human if it does not).

## 13. 261b: the Tlog reader functions (test agent, 2026-11-24)

### 13.1 Placement (decided by the manager with TalonRegistry, 2026-11-24)

`packages/records` does NOT depend on `roc-ed25519`. Reasons: the Worker imports `records` and signs and verifies with WebCrypto; Q640 (1) and R-PK10 name the CLI as the only user of `roc-ed25519`; Q636 (14) puts only the tlog math in `records`. So `records` stays with no dependency and builds on both nightlies as before (TW28).

| Part | Where | Why |
| --- | --- | --- |
| Open a signed note (the text and its signature lines), the entry bundle of an index, the entry of an index, parse an entry, the proof tile lists, the inclusion check, the consistency check | `packages/records/Tlog.roc` (new functions only; the 257 code is not changed) | Tlog math (Q636 (14)); no signature |
| Parse the verifier key text, the key id check, `Ed25519.is_valid_public_key` | `cli/lib/LogKey.roc` (new) | Needs `roc-ed25519` |
| `open_checkpoint` (find the line of the key, `Ed25519.verify`, then `Tlog.parse_checkpoint`), the R-LV2 compare of a leaf and a row (release, compiler) | `cli/lib/LogProof.roc` (new; 261c adds D1, R-LV9 and the texts to it) | Needs `roc-ed25519`; client logic |
| The dependency `ed25519: "https://github.com/Karakatiza666/roc-ed25519/releases/download/0.1.0/HrAdxCQXofHbDHhgxv6qywS5hozKum4dpEu3dn34h8op.tar.zst"` | `cli/lib/main.roc` header only (R-GP3, no path entry) | The package downloads and `roc check cli/main.roc` passes on 03dce41 |

### 13.2 API (stubs `crash "todo"`; the doc comments have the full rules)

| Function | Type | Errors |
| --- | --- | --- |
| `Tlog.open_note` | `Str -> Try(Tlog.Note, [BadNote])`, `Note : { text : Str, signatures : List(NoteSignature) }`, `NoteSignature : { name : Str, key_id : List(U8), signature : List(U8) }` | Go `note.Open` rules: no control character but `\n`; the text up to the last `\n\n`; each line `— <name> <base64>\n`, name not empty with no space or `+`, at least 5 bytes |
| `Tlog.entry_tile` | `U64, U64 -> Try(Tlog.Tile, [NotInTree])` (index, size) | `index >= size` |
| `Tlog.entry_at` | `U64, Tlog.TileBytes -> Try(List(U8), [NotInBundle, BadBundle])` | not the bundle of the index or past its width; bytes that are not `width` entries |
| `Tlog.parse_entry` | `List(U8) -> Try(Tlog.Leaf, [BadEntry])` | not 4 fields, one space, one final `\n`, decimal I64 `time` |
| `Tlog.proof_tiles` | `U64, U64 -> List(Tlog.Tile)` (index, size) | the path up to the first partial tile, then the rest of the hash tiles of `edge(size)`; `[]` when `index >= size` |
| `Tlog.check_inclusion` | `U64, Tlog.Checkpoint, List(U8), List(Tlog.TileBytes) -> Try({}, [NotIncluded, MissingTile])` (index, checkpoint, entry bytes, tiles) | |
| `Tlog.consistency_tiles` | `U64, U64 -> List(Tlog.Tile)` (sizes in either order) | `[]` for equal sizes and for size 0 |
| `Tlog.check_consistency` | `Tlog.Checkpoint, Tlog.Checkpoint, List(Tlog.TileBytes) -> Try({}, [NotConsistent, MissingTile])` (either order: R-LV10 "the other way") | |
| `LogKey.parse_verifier_key` | `Str -> Try(LogKey.VerifierKey, [BadKey])`, `VerifierKey : { name : Str, key_id : List(U8), public_key : List(U8) }` | Go `NewVerifier` rules, the key id must match, the key must be a point |
| `LogProof.open_checkpoint` | `LogKey.VerifierKey, Str -> Try(Tlog.Checkpoint, [BadNote, NoSignature, BadSignature, BadCheckpoint])` | in this order: note, a line with the name AND key id, verify, origin and body |
| `LogProof.check_release` | `{ group, version, hash, url : Str }, Tlog.Leaf -> Try({}, [EntryDiffers, UrlDiffers])` | T1, then T2b |
| `LogProof.check_compiler` | `{ target, tag, sha256 : Str }, Tlog.Leaf -> Try({}, [EntryDiffers])` | R-SG3 form |

The renamed parts of section 9 row 261b: `parse_verifier_key` and `open_checkpoint` are in `cli/lib`; `entry_tile` is new (the bundle to fetch); `parse_checkpoint` (257) is used as it is.

### 13.3 Tests

Vectors: `research/slice-261-vectors/vectors.mjs` (`node ... records` and `node ... cli` print the generated blocks). `node:crypto` only; the test keys A, A2, B, C are made from fixed texts (never the real signer). The tile lists come from their definition; a JS reference reader in the tool proves each listed case with only the listed tiles, and the "uniform" tree roots are checked against the plain MTH (self-checks, each run). Large trees (65,536 to 16,777,217) use a "uniform" tree (every leaf the same entry but one special leaf), so the test builds any tile cheaply; small trees use the 257a distinct leaves (`Tlog.grow`).

| File | Expects (new) | Rules | What |
| --- | --- | --- | --- |
| `packages/records/tests/TlogTest.roc` (step `w0` / `step_records`, both compilers) | 24 (1 guard of the test helpers, passes now; 23 red) | R-LV2, R-LV3, R-LV4, R-LV10, R-SG2, R-SG3, R-SG4 | `open_note`: the live note (size 386), the 257a and Go notes, extra lines kept in order, no line, 11 bad notes. `entry_tile` vectors and out of tree. `entry_at`: indexes 0, 1, 2, 255, 256; NotInBundle 3 cases, BadBundle 3 cases. `parse_entry`: live entry 1, a release and a compiler entry; 11 bad entries. `proof_tiles`: 25 (index, size) vectors. Inclusion: sizes 1, 2, 3, 7, 256, 257, 511 at first, middle, last; only the proof tiles; 5 fails; each proof tile changed or missing; large trees 65,536 (power of two), 65,537, 70,000 (partial tiles at 2 levels), 16,777,217 (3 levels); large fails. `consistency_tiles`: 13 vectors. Consistency: 1-2, 3-7, 7-256, 256-257, 7-257, 257-7, 255-511, 5-5, 0-5; large 255-70,000 and back, 65,536-70,000, 300-65,537, 16,777,216-16,777,217; forged old root, old root of another size, forged new root, same size other root, size 0 other root; each tile changed or missing. |
| `tests/unit/LogkeyTest.roc` (driver `l0-9`) | 6 | R-LV5, R-LV4 | The built-in key, the Go key, the 257a key, keys A and B; upper-case key id; wrong key id, type 2, 31/33 bytes, no type byte, a name with a space; a key that is not a point; 10 bad texts |
| `tests/unit/LogproofTest.roc` (driver `l0-9`) | 12 | R-LV4, R-LV2 | `open_checkpoint`: the live checkpoint with the built-in key (size 386); the 257a note; A with extra lines before and after; NoSignature 5 cases (another key only, the name of A with the id of A2, no line, the live note with A, the note of A with A2); BadSignature 3 (a bit, the size, the root); BadCheckpoint 2 (origin is not the key name, an extension line); BadNote 2. `check_release`: live entry 1, a `v{v}` group; EntryDiffers 3; UrlDiffers 6. `check_compiler`: Ok; EntryDiffers 4. |

### 13.4 Red state (capped scope, 2026-11-24)

| Run | Result |
| --- | --- |
| `roc fmt --check packages/records/*.roc packages/records/tests/*.roc`, 03dce41 and 11-06 | passes on both |
| `roc test packages/records/tests/w0.roc`, 03dce41 | 205 tests: 182 pass, 23 fail; each fail is the crash `todo`; 0 compiler errors |
| the same, 11-06 (worker pin) | 205 tests: 182 pass, 23 fail (`todo`); 0 compiler errors |
| `roc test tests/unit/l0-9.roc`, 03dce41 | 208 tests: 190 pass (all old), 18 fail (`todo`) |
| `roc fmt --check` of the new cli and unit files; `unit_modules_check tests/unit`; `roc check cli/main.roc` | pass |

### 13.5 Review points (TW24 proposals; no TW17 question)

| # | Point | Proposal in the tests |
| --- | --- | --- |
| P1 | A public key that is not a point (section 12.4 "can call") | `BadKey` (so exit 19 or 2 in 261c), test `LogkeyTest` |
| P2 | The error tags of `open_checkpoint` | 4 tags (`BadNote`, `NoSignature`, `BadSignature`, `BadCheckpoint`); 261c maps all 4 to T3 / `bad-signature` (R-LV4 "a fail is T3") |
| P3 | `check_consistency` and `consistency_tiles` take the two sizes in either order | One function for R-LV10 "a smaller new checkpoint is checked the other way" |
| P4 | `proof_tiles` does not hold the entry bundle | `entry_tile` gives it; 261c fetches both |

### 13.6 Mutation check of the 261b code (test agent, 2026-11-24)

`research/slice-261b-revert/` (`mutate.sh`, `RESULT.md`). 13 mutants (records ones on 03dce41 and 11-06, cli ones on 03dce41). First run: 2 survived. `incl-root-first-byte` (only the first byte of the root compared) survived because each wrong root of the tests had another first byte. `note-any-line` (accept when one of several lines of the key verifies) survived because no note had 2 lines of the same key. 2 gap tests:

| File | New expect | Rules |
| --- | --- | --- |
| `packages/records/tests/TlogTest.roc` | A signed root with only its last byte changed: inclusion `NotIncluded`; consistency (old root, new root, same size) `NotConsistent` | R-LV3, R-LV10 |
| `tests/unit/LogproofTest.roc` | A good and a bad line of the same key, in both orders: `BadSignature` (as Go `note.Open`) | R-LV4 |

Second run: all 13 killed. On the green code: records 206 tests pass on both compilers; `l0-9` 209 tests pass.

### 13.7 Review points of the code agent, and a note for 261c (2026-11-24)

| # | Point | Note |
| --- | --- | --- |
| C1 | `Tlog.open_note` accepts an empty signature block (`text\n\n` with no line); Go `note.Open` rejects it | The test of 261b (13.3) asks for `Ok` with no signature, and `open_checkpoint` then gives `NoSignature` (T3). The exit is the same; the human decides if `open_note` follows Go here. |
| C2 | The strict (canonical) base64 rejects a key text with a newline at the end | `LogkeyTest` has this case as `BadKey` on purpose; see 261c below |
| C3 | Only the ASCII space is rejected in a key name (Go rejects each Unicode space) | No test has a non-ASCII space; the human decides |
| N1 | For 261c: the key text from `config.toml`, `TALON_LOG_KEY` or the built-in constant is trimmed of the white space around it before `LogKey.parse_verifier_key` | 261c test plan: a gap test in `LogKeyTest` / L2 `lp11`: `TALON_LOG_KEY=" <key>\n"` and a `log-key` with spaces around the key pass; a key with a space inside is still exit 2 or 19 |
