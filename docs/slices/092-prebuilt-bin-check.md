# 092 Prebuilt tool binaries: the lock-time check

Phase: P1. Status: done (2026-11-03). Pure code (L0) is green (code step 1, 2026-11-02). The flow code is written (code step 2, 2026-11-03, section "Code (flow part)"); pt10 has a dispute.

Slice 092 is the check that the commands of R-PT19 run when they write a new `url` (or add values for a `url` that stays). It follows slice 091 (`ToolBin`, the `bin` key) and uses the pattern of slice 074 (`gh attestation verify` for `tool update talon`, `TalonUpdate.gh_state`, `gh_auth_argv`). Slice 093 is the use.

## 1. What the design says (R-PT19, R-PT20 as changed on 2026-11-02, Design Q231 to Q236)

| Step | Rule | Text (short) |
| --- | --- | --- |
| 1 | R-PT20, Q234 | The release list has the asset `<hash>-<target>` with a `digest` (`sha256:<hex>`). A target with no such asset: no value, no note. No target has an asset: the check ends, with no note. A `url` that is not on `github.com`: no check, no note, no `bin` key. `--dry-run` runs only this step (Q233): `would_check` has the targets with an asset and no value. |
| 2 | R-PT20, Q169, Q133, Q231 | `gh` found, new enough (the help run of `gh attestation verify ... --help` exits with 0, gh 2.68.0 or later), logged in (`gh auth status`). Else no value for any target, one note (R-PT23), and no download. |
| 3 | R-PT20, Q232, Q235 | `gh attestation verify <bundle file> ...` on the bundle archive. The verified attestations must name one commit and one workflow file (a re-run is the same signer). A failed run, or two commits or workflow files: no value for any target, no download, one note for the tool. |
| 4 | R-PT20, Q231, R-DA4 | Download each target of step 1 (up to 8 at the same time, R-DA5) and compute the sha256. Not the `digest`: exit code 16. This is the only exit 16 of the check (R-PT24). |
| 5 | R-PT20, Q235, Q236 | `gh attestation verify` on each binary. It passes when one of its verified attestations is the signer of the bundle. Else no value for that target and one note with the last stderr line or the two commits. No retry (Q236). A target that passes gets its sha256 in `bin`. The temp file of the host target goes to its `talon/x/` entry (R-PT22), the others are deleted. |
| Notes | R-PT23 | One line each, on stderr, once for the command, only when step 1 found a binary asset. The summary line has the one commit of the bundle. `--json`: `bin_skip`, `bin`, `binary`, and `would_check` (a proposal). |
| Limits | R-PT24, R-SE20 | One workflow file at one commit and the tag, a GitHub-hosted runner. Not that the binary comes from the bundle bytes. |

Checked (2026-11-03, gh 2.103.3, `research/gh-attestation/`): the output of `gh attestation verify --format json` is a JSON array. Each element has `verificationResult.signature.certificate.sourceRepositoryDigest` (the commit) and `buildSignerURI` (the full workflow URI with `@<ref>`). These are the names and the shape that `ToolBinCheck.signers` and row 6 of the tests use. A file with no attestation gives exit 1 and `Error: no attestations found`. A wrong repo gives exit 1 and `Error: HTTP 404: Not Found (...)`. The note of the target shows the last line (R-PT23).

## 2. Rules

| Rule | Tests |
| --- | --- |
| R-PT19 (which commands write, which targets) | L0 `ToolbinTest` 8, 9 (slice 091). Flow: section 3a, cases F1 to F3 |
| R-PT20 step 1, Q233, Q234, Q239 | L0 `ToolbincheckTest` 1, 2, 9 (`source`); L0 `ToolbinlistTest` 1 to 3 (`list_assets`, round 4: the list of R-DI2 is red until the code agent writes it, and the driver `l0-4.roc` does not compile until then) |
| R-PT20 step 2, R-PT24, R-SE20 (only the digest stops) | L0 `ToolbincheckTest` 3. Flow F4 |
| R-PT20 step 3, Q169, Q133 | L0 `ToolbincheckTest` 4, 5. Flow F2 |
| R-PT20 step 3, 4 and 5, R-SE20, Q232, Q235 | L0 `ToolbincheckTest` 6, 7 (`bundle_signer`), 8 (`judge`). Flow F1, F5 |
| R-PT23 | L0 `ToolbincheckTest` 10. Flow F1, F2 (the lines and `--json`) |
| R-PT24 | The same rows as R-SE20, and the text of the design (a limit, not a behavior) |

## 3. Public signatures (fixed by the tests)

New module `cli/lib/ToolBinCheck.roc` (in `cli/lib/main.roc`). Stubs: `crash "todo: slice 092"` (the two argument lists are `[]`). Details and the case tables are in the doc comments of the file.

| Function | Signature |
| --- | --- |
| `release_assets` | `Str -> Try(List({ name : Str, digest : Str }), [BadJson])` (only `sha256:<64 hex>` digests, without the prefix) |
| `found` | `{ hash, want : List(Str), assets } -> List({ target : Str, digest : Str })` |
| `digest_check` | `{ key, version, target, digest, sha256 } -> Try({}, Fail)` (kind `Integrity`, exit 16) |
| `help_argv`, `verify_argv` | `{ repo, tag } -> List(Str)`, `{ file, repo, tag } -> List(Str)` |
| `gate` | `{ found : Bool, help : Try(Ended, [NotAsked]), auth : Try(Ended, [NotAsked]) } -> [Ready, NoGh, GhOld]` |
| `signers` | `{ ended, stdout, last_line } -> Try(List({ commit, workflow }), Str)` |
| `bundle_signer` | `List(Signer) -> Try(Signer, Str)` (one commit, one workflow file) |
| `judge` | `{ bundle : Signer, binary : List(Signer) } -> Try({}, Str)` |
| `source` | `Str -> Try({ repo, tag }, [NotGithub])` |
| `bundle_note` | `{ key, version, reason } -> Str` |
| `workflow_file`, `summary`, `target_note`, `skip_note`, `skip_name` | Text functions (R-PT23) |

The calls of the flow are not in the L0 tests. The code agent writes the flow in a new module (for example `ToolBinFlow`) that `ToolsStep` calls at the write of `url` (`ToolsStep.moved!`, `locked!`, `ToolsFlow` for `add --tool`). The flow reuses `TalonUpdate.gh_auth_argv` (the `gh auth status` of slice 074) and the `programs!`, `spawn_all!` and download calls of `Fx`. The code agent also needs `Fx.http_get!` (release body) and the download with `sha256_file!`.

### 3a. Deep cases (L2, round 3)

All cases have the entry `commands` and a world of `ptool/pt3-move` (the compiler installed, the platform in the cache, acme/foo with 1.0.0 and 1.1.0). `gh` is a rule of `fx/jobs` (no real `gh`; the host has `gh` 2.46.0). A rule `@<n>|` is for the n-th run. The release call is `GET https://api.github.com/repos/acme/foo/releases/tags/1.1.0` (`fx/http/.../releases/tags/1.1.0`, assets with `digest`).

| Case | Runs | Rules |
| --- | --- | --- |
| `ptool/pt6-bin-lock` (F1) | 1: `update --tool`, a new `url`: the full check (release call, `programs gh`, help run, `gh auth status`, `programs curl wget`, bundle download and verify, 3 downloads, 3 `sha256_file`, 3 verify runs). x64musl passes, arm64mac has another commit, x64mac has no attestation. The summary and 2 notes. The host file is the `x` entry (kind `prebuilt`), no build. `bin` is written with the `url`. 2: the `url` stays, the targets with no value are checked, both fail again, no write. 3: arm64mac is attested now: its value is added, x64musl stays | R-PT19, R-PT20, R-PT22, R-PT23, R-SE20, Q231, Q232, Q235 |
| `ptool/pt7-bin-skip` (F2) | 1: help run fails: the `gh is too old` note, no auth, no download, source build. 2: `gh auth status` fails: the `needs gh, logged in` note. 3: the bundle verify fails: one note for the tool, no binary is downloaded | R-PT20, R-PT23, Q169, Q231, Q232 |
| `ptool/pt7b-bin-no-gh` (F2) | 1: no `gh` on `PATH`: the note, no `gh` call, no download, source build | R-PT20, R-PT23, Q231 |
| `ptool/pt8-bin-update` (F3) | 1: a `url` that stays with `bin = { x64musl = "aaaa..." }`: arm64mac and x64mac are added, x64musl is not checked and not changed. 2: `bin = false`: no call. 3: `tool-binaries = false` (home2), the `url` stays: no check, the table stays. 4: `tool-binaries = false`, a new `url`: no check, the old table goes, source build. 5: `add --tool acme/foo` for the key with `bin = false`: acts as `update`, nothing is checked (Q230) | R-PT19, R-PT25, R-LY4, R-PT3, Q230 |
| `ptool/pt9-bin-digest` (F4) | 1: the sha256 of x64musl is not the `digest`: exit 16, temp dir deleted, no write, no entry | R-PT20 step 4, R-PT24, R-SE20, R-DA4 |
| `ptool/pt10-bin-dry-run` (F6) | 1 and 2: `update --tool --dry-run`: only the release list, no release call for binaries, no `gh`, no download | R-PT19, Q233 |
| F5 L3 `tools/pt1-bin-lock` | Not written. Reason: the L2 cases cover each call (the fake `Fx` answers `gh` through `fx/jobs`). A real `tln` case needs `given/bin/gh` (a script), a fake HTTP release with `digest` fields, a real `curl`/`wget` download and `sha256` of real files: a second copy of the same checks with no new rule. The real `Fx` jobs (spawn, download, sha256) have their L3 cases in earlier slices | |

The L2 flow reference that made the `calls.log` files was private and is deleted (the manager deletes `research/slice-09{2,3}-revert/reference/` after the review). It had no release call: the asset digests are read from the cached list of R-DI2 (Q9).

TW21 (round 4): the 6 old `calls.log` files are as before (no `releases/tags` call in direct mode, Q9). What changed in old cases: `tree.diff` of `pt1-add`, `pt2-install`, `pt3-move`, `pt5-exclude`, `pt5b-exclude-config` (a new `url` of a release with no binary asset gets `, bin = {}`, Q239) and `stdout` of `pt1-add`, `pt2-install`, `pt3-move` and `pt4-bin-file` (each `data.tools` row gets the keys `bin`, `binary`, `bin_skip`, `would_check`). Checked: additions only, the rest of each file is equal. Added: `ptool/pt14-bin-none` (a release with no binary asset: `bin = {}`, run 2 looks again, no `gh`). `--json` was added to the first run of `pt6`, `pt7`, `pt11` and to run 2 of `pt10`.

## 4. Tests written (L0)

All in `tests/unit/ToolbincheckTest.roc` (driver `tests/unit/l0-4.roc`). 10 `expect`s. The JSON of row 6 has the shape of `gh` 2.6x as the design names it (unverified, section 1).

| # | Case | Rule ids |
| --- | --- | --- |
| 1 | `release_assets`: 7 assets in a body (a valid digest, `null`, a bare hex, `sha512:`, no digest, upper case hex, a second valid one): 2 count. No `assets`: `Ok([])`. `[1]` and `nope`: `BadJson` | R-PT20 |
| 2 | `found`: text order, `want` filter, no asset, another hash, and `want` from `to_check` for a `bin` with a value (the `would_check` of `--dry-run`) | R-PT20, R-PT17, R-PT19, Q233 |
| 3 | `digest_check`: equal is `Ok`, not equal is exit 16 with the text | R-PT20, R-PT24, R-SE20, R-DA4 |
| 4 | The two argument lists | R-PT20, Q169 |
| 5 | `gate`: 8 rows (no `gh`; help exit 1, 127, signal, no start is `GhOld`; auth fails is `NoGh`; `Ready`) | R-PT20, Q169, Q133, Q231 |
| 6 | `signers`: 2 attestations (an element with no signer does not count), empty array, no signer, not an array, not JSON, exit 1 with and without a last line, signal, no start | R-PT20 |
| 7 | `bundle_signer`: one, a re-run (the same twice), two commits, two workflow files, two commits after a repeat, none | R-PT20, R-SE20, Q232, Q235 |
| 8 | `judge`: the signer of the bundle in first and in second place, a binary at another commit, at another workflow file, none | R-PT20, R-SE20, Q235 |
| 9 | `source`: a release URL on github.com (and a tag with `v` and a suffix), a loopback URL, another forge, a non-release URL | R-PT20, Q234 |
| 10 | `workflow_file`, `summary`, `target_note`, `bundle_note`, 2 `skip_note`, `skip_name` | R-PT23 |

## 5. Red output (test agent, round 2, 2026-11-02)

10 tests, 0 pass, 10 fail, 0 compile errors (stubs only). Reason: 1, 3, 5, 6, 7, 8, 9, 10: `crash "todo: slice 092"`. 2: `crash "todo: slice 091"` (`ToolBin.asset_name`, until 091 has its code). 4: wrong value (the stubs give `[]`). A private reference (`research/slice-092-revert/reference/ToolBinCheck.roc`) passes all 10.

## 6. Output (proposed, TW24, R-OUT2)

The texts of R-PT23 are in the design and the tests use them as they are. These are the texts that the design does not give:

| Output | Text |
| --- | --- |
| Digest mismatch (exit 16) | `the <target> binary of <key> <version> has the sha256 <got>, but the release digest is <digest>. Talon deleted the file.` |
| The reason of a verify run | `gh exit <n>: <last line>`, `gh signal <n>`, `gh not started: <text>`, `no attestation`, `gh gave no readable JSON` |
| Two commits (the design: "a note that names both commits") | `the bundle was attested at commit <8 hex> and the binary at commit <8 hex>` |
| Same commit, two workflow files (the design is silent) | `the bundle was attested by <file> and the binary by <file>` |
| `<name>` in the notes and the summary | The key of `[tools]` (`roc-cfw`), as `tln update roc-cfw` in the text of R-PT23 |
| `data.tools` fields `bin`, `binary`, `bin_skip` | As R-PT23 says. Not tested here (flow case F2). |

## 7. Out of scope

| Item | Why |
| --- | --- |
| The flow and its L2 and L3 cases | Section 3a. They need the code reference first. |
| R-PT20 step 1 for a registry (the `releases/tags/<tag>` call) | Same flow cases. `release_assets` reads the body of both calls. |
| R-DA5 (8 downloads at the same time), R-PT20 temp files in `talon/x/` | Flow. The `talon/x/` entry of the host target is slice 093. |
| `gh` 2.68.0 itself | `help_argv` is the whole test (Q169). |

## 8. Questions (TW17)

| # | Question | Why it is open |
| --- | --- | --- |
| Q1 (answered, Q232, G-C16) | The bundle verify fails. | No binary is downloaded or verified. One note for the tool (`bundle_note`). |
| Q2 (answered, Q231, G-C17) | The order of the downloads and the `gh` check. | `gh` probe and auth, then the bundle verify, then the downloads. No `gh`: no download. Exit 16 at lock time only from a digest mismatch. |
| Q3 (answered, Q233, G-C18) | `--dry-run`. | Step 1 only. `would_check` in the `--json` rows (a TW24 proposal). |
| Q4 (answered, Q234, G-C19) | A `url` that is not on github.com. | No check, no note, no `bin` key (`ToolBinCheck.source`). |
| Q5 (answered, Q235, G-C20) | A mix of commits. | Cannot pass: the bundle names one commit and one workflow file (`bundle_signer`). The summary has one commit. |
| Q6 (answered, Q236, G-C21) | A retry. | None. |

| Q7 (answered by the manager) | The bundle archive is downloaded again for the verify (the fetch deletes it after `roc unbundle`). | A known cost. A later slice can keep the archive. |
| Q8 (answered, Q239, G-C33) | A release with no `<hash>-<target>` asset gets `bin = {}` (step 1 ran). No `bin` key only for: a `url` not on github.com, no usable `gh` with an asset in the release, `tool-binaries = false`. | Case `ptool/pt14-bin-none`. |
| Q9 (answered by the manager) | Direct mode: the digests come from the R-DI2 list that the command read (the cached pages), with no `releases/tags` call. `Index.candidates` stays as it is. | New pure function `ToolBinCheck.list_assets({ pages, tag })` (name is a proposal), L0 `ToolbinlistTest` 3 expects. Only the registry mode makes the one `releases/tags` call (slice 200 and up). |
| Q10 (accepted by the manager, TW24 proposals) | A bundle that cannot be downloaded again, or a binary download that fails, at lock time: the reference gives the bundle note (with `download failed` as the reason) and a note for the target. The design says only "every other failure leaves the target to the source build". | The texts of these two notes are proposals. |
| Q11 (answered by the manager) | `--json` fields appear once. | Rows of `data.tools` always have `bin` (targets, or `false` for `bin = false`), `binary` (`prebuilt`, `built`, `null`), `bin_skip` (`no-gh`, `gh-old`, `null`) and `would_check` (a list, empty outside `--dry-run`), in this order after `would_build` (a TW24 proposal). Cases `pt6`, `pt7`, `pt10`, `pt11`, and the old rows. |
No new question in round 2.

## 9. Disputes (from the code agent)

## 10. Verify results

Revert check (test agent, round 2): `research/slice-092-revert/mutate.py` with `results.txt`, 6 mutations of the private reference, all caught: an old `gh` reported as no `gh`, the workflow file not compared by `judge`, a bare hex digest counted, an empty attestation array passes, two commits in the bundle pass, a digest mismatch passes. A mutation "any host is github" had no effect on the reference (the reference needs the prefix to split the URL): not kept. The first four are the round 1 mutations m7 to m10 of 092.

## Code step 1 (pure), 2026-11-02

| Item | Result |
| --- | --- |
| Files | `cli/lib/ToolBinCheck.roc` (225 lines), all stubs replaced. Signatures not changed. No flow code, no `Fx` call. `research/slice-092-revert/code-final/` and `code-final.sha256` |
| `roc test tests/unit/l0-4.roc --no-cache` | 104 of 104 pass (the 10 of this slice included) |
| `roc check cli/main.roc`, `roc fmt --check` | 0 errors, formatted |
| Field names of `gh attestation verify --format json` | Checked against gh 2.103.3 on 2026-11-03 (`research/gh-attestation/README.md`): same names, top level is an array, as the tests give them. |
| Choices that the slice does not fix | `gate` with `found` true and a `help` of `Err(NotAsked)` gives `GhOld`. `found` keeps the order of `want`. `source` needs exactly 6 path parts (`owner/repo/releases/download/<tag>/<file>`). `bundle_signer` tests the commits first, then the workflow files. |
| Revert check (5 of 5 caught) | help gate that ignores a failed help run (test 5), workflow file not compared in `bundle_signer` (test 7), `release_assets` that skips the sha256 shape test (test 1), an empty attestation list that passes (test 6), `judge` that compares only the commit (test 8). Code restored and compared: same. |
| Disputes | None |
| Open | The flow part (section 3a, F1 to F6) and its wiring. Status is "tests (flow part)". |

Round 3 (flow): see `research/slice-092-revert/results-flow.txt` for the revert check of the L2 cases (6 mutations of the private flow reference, shared with slice 093).

## Code (flow part), 2026-11-03

| File | What it does |
| --- | --- |
| `cli/lib/ToolBinFlow.roc` (new) | `check!` (R-PT20 steps 1 to 5: the assets of the R-DI2 pages, the `gh` gate once for the command, the bundle download and verify, the binary downloads, `digest_check`, the verify runs, the notes, the `x` entry of the host target), `use!` (R-PT21: download, sha256, `ToolBinUse.verify`, the entry, the use line, the download warning), `enter!` (R-PT22: the prebuilt `talon/x/` entry), `hit` (R-PT9 step 1, Q237), `prebuilt_there`, `source_only` |
| `cli/lib/ToolBinCheck.roc` | `list_assets` (Q9: the assets of the release with the tag in the pages of the R-DI2 list; L0 `ToolbinlistTest`) |
| `cli/lib/ToolsStep.roc` | `Ctx` has `machine_bins` and `bins`. `locks!` (the check and `ToolBin.write`) after `chosen!` and before `ensure!`; `stays!` for a `url` that stays (`Bin` change); `Put` carries the new `bin` table (one write). `ensure!` takes `key` and `bin`: `ToolBinFlow.hit`, then `ToolBinUse.use` and `ToolBinFlow.use!`, then the build. Rows and `--json` rows have `bin`, `binary`, `bin_skip`, `would_check` (`data`, `with_tools`). The `gh` gate is kept across the entries of a run |
| `cli/lib/ToolsFlow.roc` | `add --tool` of a new key runs `locks!`; `context!` fills `machine_bins` and `bins` |
| `cli/lib/ToolFlow.roc` | `release_pages_for!`: the release list with the texts of its pages |
| `cli/lib/RunTools.roc`, `cli/lib/RunSteps.roc`, `cli/lib/XProject.roc` | `Table` and `Run` have `bins`. `bin!` step 1 is `ToolBinFlow.hit` (reads `config.toml` only when a prebuilt entry has the `bin` value); `build!` passes `bin` and `tool-binaries` to `ensure!` |
| `cli/lib/XCache.roc` | `read_any` (a `prebuilt` manifest is an entry: no warning, no delete; `entries_of` and `expired` use it, Q6 of 093), `prebuilt_entry`, `is_prebuilt`, `manifest_text_any`. `choose` and `entities` skip a prebuilt entry (R-B10) |
| `cli/lib/XCacheIo.roc` | `touch!` writes a prebuilt manifest as a prebuilt manifest |
| `cli/lib/Install.roc`, `cli/lib/Update.roc` | `--json` uses `ToolsStep.with_tools` |
| `cli/lib/main.roc` | exposes `ToolBinFlow` |

Copies: `research/slice-092-revert/code-final/`, `code-final.sha256`. Result: the 18 cases of `ptool/` and `gc/gc6-prebuilt-entries` pass except `ptool/pt10-bin-dry-run` (dispute below). `scripts/test.sh check fmt l0 l2`: check, fmt and l0 pass; l2 262 of 263 (only pt10).

Choices that the slices do not fix: the end of `chmod 0755` is not read (the `fx/jobs` of the cases have no rule for it, so the reference did not read it). The reason of a failed binary download at lock time is `download failed` (Q10). A missing `curl`/`wget` at lock time is a bundle note with the failure text; at use time it is the download warning.

Dispute (TW17, for the human): `ptool/pt10-bin-dry-run` run 2 expects `"would_check":[]`. The `url` stays, `bin` has only x64musl, and the release list has the asset arm64mac. R-PT19 and Q233 say: `--dry-run` runs step 1, and `would_check` has the targets with an asset and no value in `bin`. The code gives `["arm64mac"]`. The expected file is not changed.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-092-revert/code-final.sha256` | 13 of 13 OK. The flow code of 092 and 093 is in one copy, under `research/slice-092-revert/code-final/`. |
| `crash "todo: slice 092"` or `093` in `cli/` | None |
| `ptool/*` (17 cases) and `gc/gc6-prebuilt-entries` | 18 of 18 green. `pt4-bin-file` (Windows) run by name. |
| `scripts/test.sh l0 l2` | Pass. l0 7.5 s (budget 10), l2 11.9 s (budget 30). |
| Expected exits | Not 0 and intended: `pt9`, `pt11` run 4, `pt13` exit 16 (integrity, digest mismatch). The other non-zero exits of `pt1` to `pt5` were there before this slice. |
| `pt10` run 2 | The code agent reported a wrong expected value. Manager decision: `would_check` is `["arm64mac"]` (R-PT19 checks the targets with no value also when the `url` stays, Q233). The test agent changed the expected file and the rules. Green. |
| `gh` field names | Checked against gh 2.103.3 (`research/gh-attestation/`): same names, top level is an array. |
| L3 `ptools/pt1-flow` | Missed at the close: it failed on `bin = {}` (Q239). Found by the slice 200 test agent. The test agent changed only the `bin = {}` lines of its expected files. Green (2026-11-03). |
| Not covered by L2 | The prebuilt path of `tln run` and `tln x <key>` (section 4b of slice 093). |
