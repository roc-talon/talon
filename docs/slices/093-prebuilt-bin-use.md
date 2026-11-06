# 093 Prebuilt tool binaries: the use (download, sha256, the `talon/x/` entry, the fallback)

Phase: P1. Status: done (2026-11-03). The pure parts have L0 tests (5 `expect`s, `ToolBinUse`), the flow has L2 cases (section 4b) and its code (section "Code (flow part)", 2026-11-03). No L3 case (reason in section 4b).

Slice 093 changes the path that finds or builds a project tool binary: `tln run`, `tln x <key>`, `tln install` and `tln install --frozen`. Today the path is step 1 (a `talon/x/` entry with the same bundle hash and target), step 3 (build). 093 adds step 2: the prebuilt binary (R-PT9, R-PT21).

## 1. What the design says

| Point | Rule | Text (short) |
| --- | --- | --- |
| Order | R-PT9 | (1) a `talon/x/` entry with the bundle hash and target (R-B9); a prebuilt entry only when R-PT25 allows binaries and its sha256 is the `bin` value of its target. (2) Else the prebuilt binary of `bin` for the host target. (3) Else build. |
| Install | R-PT6, R-PT7 | `install` and `install --frozen` get each tool that has no binary: the prebuilt binary of R-PT21, else a build. `--frozen` makes no index call. A host target with no hash in `bin` builds from source, also when the release has a binary. `--frozen` never writes `bin`. |
| Download | R-PT21 | The host target is the target of the running `tln` (R-IS2: Windows on ARM64 is `x64win`, Rosetta is `arm64mac`). Download `<url dir>/<hash>-<target>` (R-PT17) with the adapter (7.5), compute the sha256. Not the `bin` value: exit code 16, delete the file, no source build. The message names the target, both values and the way on (remove the target from `bin`). A download error (7.5, R-DA7) is a warning and a source build. Then set the executable bit (R-HF2) and write the entry. No attestation check, no index call, no compiler, no closure fetch, no prompt (R-DL7). No `--version` run. |
| Entry | R-PT22, R-B9, R-B10 | `talon/x/<digest>/`, digest = a hash of the bundle hash, the target and the sha256. The manifest has the source kind `prebuilt`, the full name, the version, the bundle hash, the target, the sha256, the asset URL, no build id. A source build entry with the same bundle hash and target is also used. `tln x owner/app@<sel>` and `tln tool install` never use or take over a prebuilt entry. GC keeps it through the bundle hash (R-PT14, R-GC7). |
| Opt-out | R-PT25, R-LY4 | `tool-binaries = false` or `bin = false`: no download, no prebuilt entry, source build (also `--frozen`). A `bin` table never overrides the machine key. |
| `--offline` | R-PT15 | A prebuilt binary is a download, so step 2 is skipped. |
| Output | R-PT23 | Use line: `roc-cfw 1.0.3: prebuilt x64musl binary, sha256 <12 hex> (talon.toml)`, in place of the platform line of R-SE8. Download error: `warning: the x64musl binary of roc-cfw 1.0.3 could not be downloaded (<last line>). Talon builds it from source.` `--json`: `bin` and `binary` (`prebuilt`, `built`, `null`) in each row of `data.tools`. |
| Global tools | R-T22 | Before P3, `tln tool install` builds from source. |
| Hash check | R-DA4 | sha256 of a prebuilt tool binary, before any other use. |

## 2. Rules for the tests

R-PT6, R-PT7 (the prebuilt part), R-PT9 (step 1 and 2), R-PT15, R-PT21, R-PT22, R-PT23 (use time), R-PT25 (use side), R-T22, R-DA4 (tool part), R-B9, R-B10, R-LY4.

## 3. Proposed split of the tests (for the next step)

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `ToolBin.host_target : { os, target } -> Str` (R-PT21: the Windows ARM64 and Rosetta rows; reuse `BuildSkip.target`, `TalonUpdate.asset_name`) | R-PT21 |
| L0 | `XCache`: the digest and the manifest text of a `prebuilt` entry (R-PT22), the match rule of R-PT9 step 1 (`prebuilt` entry is used only with a `bin` value that equals its sha256 and R-PT25 allows binaries; a source entry always), and that `x owner/app@<sel>` and `tool install` do not match a `prebuilt` entry (R-B10, R-PT22) | R-PT22, R-PT9, R-B10, R-T22 |
| L0 | `ToolBin.use_note`, `use_line`, `download_warning`, the exit 16 text | R-PT21, R-PT23 |
| L2 | `ptool/pt10-bin-use`: `tln run` with `bin` for the host: download, sha256, the entry, the use line, no compiler call, no index call, no `--version`. A second run uses the entry (no download). | R-PT9, R-PT21, R-PT22, R-PT23, R-DL7 |
| L2 | `ptool/pt11-bin-fallback`: a download error (warning, then the source build), a host target with no `bin` value (source build), `tool-binaries = false` and `bin = false` (no download, source build), `--offline` | R-PT21, R-PT25, R-PT15, R-PT6 |
| L2 | `ptool/pt12-bin-mismatch`: the sha256 is not the `bin` value: exit 16, the file deleted, no entry, no build. A stale `bin` after a hand edit of `url` | R-PT21, R-DA4, R-PT18 |
| L2 | `ptool/pt13-bin-frozen`: `install --frozen` fetches the binary, makes no index call, writes no `bin`, runs no compiler | R-PT7, R-PT6 |
| L3 | `tools/pt2-bin-use`: the real `tln` with the fake HTTP, `TALON_DOWNLOADER=curl` and `wget` (R-DA2), a bad hash, the executable bit | R-PT21, R-DA4 |

The existing flows are in `RunTools.bin!` (step 3 today), `XProject`, `XCache` (`entities`, `digest`, `manifest_text`), `ToolsStep.locked!` (the fetch and build of `install`), `RunFind`. The `[tools]` table that these read (`RunTools.Table`, `ToolsToml.Entry`) has no `bin` yet: 091 adds `ToolsToml.read_table`.`bins` and `Intent.tool_bins`, and 093 carries it to `RunTools` and `ToolsStep`.

## 4. Design answers (2026-11-02, Design Q237, Q238)

| # | Answer |
| --- | --- |
| Q1 | The digest is the R-X2 hash function over `prebuilt\n<bundle hash>\n<target>\n<sha256>\n` (R-PT22). |
| Q2 (G-C22) | The prebuilt entry wins when its sha256 is the `bin` value, else the source build entry (R-PT22). |
| Q3 (G-C23) | Exit 16 stops `install` (also `--frozen`) as a failed build does: running work stops and its temp files go (R-CC2), done `talon/x/` entries stay (R-PT21). A flow case. |
| Q4 | A TW24 output proposal: the use line and the download warning go to stderr (as the build line of R-SE8). |
| Q5 | The file in the entry has the name of a source build file: the repo name, `.exe` on Windows (R-PT22). A flow case. |

## 4a. Tests written (L0, round 2)

New module `cli/lib/ToolBinUse.roc` (in `cli/lib/main.roc`), stubs `crash "todo: slice 093"`. Tests in `tests/unit/ToolbinuseTest.roc` (driver `tests/unit/l0-4.roc`). The host target is not a function of this slice: R-PT21 uses the target that the running `tln` has (`Know.target` of `RunTools`, the same value as `TalonUpdate.asset_name`); the Windows ARM64 and Rosetta rows belong to that earlier code.

| # | Case | Rule ids |
| --- | --- | --- |
| 1 | `digest`: a value made with python3 `hashlib`, and each input changes it | R-PT22, Q237 |
| 2 | `pick`: 15 rows. A prebuilt entry only when `bin` names its sha256 and both levels allow; it wins over a source entry; else a source entry; else none. A global run never takes a prebuilt entry. Another bundle or target never counts | R-PT9, R-PT22, R-PT25, R-B10, R-T22, Q237 |
| 3 | `use`: 8 rows. `Download(sha256)` only online with a value for the host target and both levels on, else `Build` | R-PT21, R-PT15, R-PT25, R-PT6, R-PT7, R-PT9 |
| 4 | `verify` (exit 16 with both values and the way on), `use_line`, `download_warning` | R-PT21, R-PT23, R-DA4, R-DL7 |
| 5 | `manifest_text` (the layout is a proposal: one line, `format` 1, `source` kind `prebuilt`, `target`, `sha256`, `bundle`, `last_run`, no `build`), `read_manifest` (round trip, a `release` manifest, text that is not JSON) | R-PT22, R-B9, R-TF1, R-B10 |

Red: 5 tests, 5 fail, all `crash "todo: slice 093"`. A private reference (`research/slice-093-revert/ToolBinUse.reference.roc`) passes all 5. Revert check: `research/slice-093-revert/mutate.py` with `results.txt`, 6 mutations, all caught (a source entry wins, a `bin` table overrides the machine opt-out, a global run takes a prebuilt entry, `--offline` downloads, the entry is not matched by its sha256, the digest ignores the sha256).

Code note, not tested here: `XCache.entries_of` and `XCacheIo` read the manifests of `talon/x/` today with `XCache.read` (kinds `release` and `git`). A `prebuilt` manifest must not make them warn or delete the entry, and GC must keep it by the bundle hash (R-PT22, R-GC7). The listing code reads it with `ToolBinUse.read_manifest` first. This needs a flow-level case (the GC L2 cases) when the flow files are free.

## 4b. Deep cases (L2, round 3)

All cases have the entry `commands`, the world of `ptool/pt3-move` and `install --frozen` (no index call, no compiler call, no closure fetch for the tool). The files of the assets are in `fx/src/bin-<target>`, the downloads are rules of `fx/jobs`.

| Case | Runs | Rules |
| --- | --- | --- |
| `ptool/pt11-bin-use` | 1: the lock has x64musl: the asset is downloaded, its sha256 is the lock, the file goes into a new `x` dir (`chmod 0755`, the manifest of kind `prebuilt`), the use line on stderr, no `unbundle`, no build. 2: the entry is used, no download. 3: another lock sha256: the old prebuilt entry is not used, the download is not the lock: exit 16, file deleted, no entry. 4: `bin` has no value for the host: no download, source build | R-PT6, R-PT7, R-PT9, R-PT21, R-PT22, R-PT23, R-DA4, R-DL7, Q237 |
| `ptool/pt12-bin-fallback` | 1: the download fails (curl 22): the warning, source build. 2: `tool-binaries = false` with a `bin` table: no download, source build. 3: `bin = false`: no download, source build | R-PT21, R-PT23, R-PT25, R-LY4, R-PT6 |
| `ptool/pt13-bin-frozen-stop` | 3 tools. foo is made, bar is not its lock: exit 16, the temp dir deleted, baz is not started, foo's entry stays | R-PT21, R-PT7, R-T25, R-CC2, Q238 |
| `gc/gc6-prebuilt-entries` | The world of `gc5-project-tools` with all `x` manifests of kind `prebuilt`: no warning, no delete by the parse, the entries are kept or removed by the same rules (bundle hash of a known project, the age) | R-PT22, R-PT14, R-GC7, R-B9, R-B10 |

Not covered by an L2 case: `--offline` (R-PT15, the L0 row of `use`), `tln run` and `tln x <key>` with a prebuilt entry (the same `RunTools.bin!` step 1 and step 2 as `install --frozen`; the reference changed `RunTools`, no case runs it), and the Windows `.exe` file name (R-PT22). No L3 case: the real `Fx` jobs that the use needs (download, sha256, rename, chmod) have their L3 cases in earlier slices.

The private flow reference (`research/slice-093-revert/reference/`) is the one of slice 092 plus the use (`ToolBinFlow.use!`, `ToolBinFlow.enter!`, `ToolBinFlow.hit`), the edits of `ToolsStep.ensure!`, `RunTools.bin!`, `RunTools.build!` and `XCache` (`read_any`: `entries_of` and `expired` read a prebuilt manifest). The reference marks a prebuilt entry in the list of `x` entries with `nightly = "prebuilt"`, so `XCache.Found` has no new field (about 20 old L0 values compare it). Round 4: the reference is deleted; run 1 of `pt11-bin-use` has `--json` (row with `binary` = `prebuilt`); the 092 cases no longer have a `releases/tags` call (Q9).

New question Q6 (open): GC (`XCache.expired`) and the listing (`XCache.entries_of`) read manifests with `XCache.read`, which gives `Delete` for a manifest of kind `prebuilt` (its source kind is unknown to `ToolsJson`). Today that deletes the dir with the warning `the content does not parse`. `gc6-prebuilt-entries` shows the wanted result. The code agent must make both read functions know the kind (R-PT22). Not a design question.

## 5. Out of scope

| Item | Why |
| --- | --- |
| The check at lock time | Slice 092 |
| Global tools (`tln tool install` of a prebuilt binary) | P3, R-T22 |
| A check that the downloaded binary runs | R-PT21: no `--version` run |

## Code step 1 (pure), 2026-11-02

| Item | Result |
| --- | --- |
| Files | `cli/lib/ToolBinUse.roc` (143 lines), all stubs replaced. Signatures not changed. No flow code, no `Fx` call. It imports `JsonDoc`, `TalonFile`, `ToolsJson`. `research/slice-093-revert/code-final/` and `code-final.sha256` |
| `roc test tests/unit/l0-4.roc --no-cache` | 104 of 104 pass (the 5 of this slice included) |
| `roc check cli/main.roc`, `roc fmt --check` | 0 errors, formatted |
| Choices that the slice does not fix | `read_manifest` uses `TalonFile.open` (`newest` 1, `can_recreate` true); any result other than a `Use` with source kind `prebuilt` and all text fields is `NotPrebuilt`. `last_run` that is missing reads as the empty text. |
| Revert check (3 of 4 caught) | a `Global` scope that takes a prebuilt entry (test 2), a source entry that wins over a prebuilt entry (test 2), `--offline` that downloads (test 3). Not caught: the kind test in `prebuilt_of` removed. A `release` manifest has no `target`, so it is still `NotPrebuilt` by the field test: the guard is redundant for the test data, kept for a manifest with all fields. Code restored and compared: same. |
| Disputes | None |
| Open | The flow part (L2, L3 cases and the wiring in `RunTools`, `ToolsStep`, `XCache` listing). The `XCache.entries_of` and `XCacheIo` code note of section 4a is still open. Status is "tests (flow part)". |

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

Closed with slice 092: see its "## Close (manager, 2026-11-03)" table. The flow code is in `research/slice-092-revert/code-final/`.
