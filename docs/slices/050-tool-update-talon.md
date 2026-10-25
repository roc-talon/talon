# 050 `tln tool update talon`: the prebuilt binary and `--from-source`

Phase: P1. Status: done

Slice 050 adds `tln tool update talon [--from-source]` (CLI 6.5: R-S1 to R-S4, R-T22, R-ST9, R-ST10, R-SE13). The command downloads the newest `tln` binary of `roc-talon/talon` that is old enough (R-T9), checks its sha256 against `sha256sums.txt` of the release, runs `tln --version` on it, and renames it over the installed file. Then it makes the bin dir entries `tln` and `roc` again and writes the entry `talon` of `tools.json`. `--from-source` builds the tag of the release as `tool install --git` does.

Slice 046b (GC of tool packages) was dropped and is not part of this slice.

Size (TW19): the plan row says about 250 lines. The private reference (`research/slice-050-revert/reference/`, deleted at the review, 2026-10-25) has 315 lines in `TalonUpdate`, 313 in `TalonUpdateFlow`, 133 more lines in `ToolsJson` (462 lines in all) and 35 lines of change in 6 other modules. That is about 580 lines of code without comments and blank lines (214, 238, 96 and about 30), about 800 lines with them. No module is over 490 lines. Split proposed, one test set, 2 code passes one after another (the same way as 048):

| Part | Code | Tests that turn green |
| --- | --- | --- |
| 050a | `TalonUpdate` (all pure functions), `ToolsJson` (`talon`, `put_talon`, the skip of the key `talon` in `read` and `manifest`), `ToolManage` (the 2 changes), `ToolManageFlow.machine!` (the field `talon`). About 340 code lines | L0: `TalonUpdateTest` 1 to 12, `ToolManageTest` 1 |
| 050b | `TalonUpdateFlow` (`update!` with the prebuilt path and `--from-source`), `ToolUpdateFlow.consent_for!`, the 1 line of `ToolBuild.attempt!`. About 245 code lines | L2: `tool/ts1-update` to `tool/ts6-source`. L3: `tools/ts1-update-talon` |

`Run` and `main.roc` are complete in the stub state (wiring), so 050a does not touch them.

Each part and the tests that it must make green (the manager accepted this split, 2026-10-25). The code agent does 050a, runs `scripts/test.sh l0`, then does 050b and runs the L2 and L3 filters. Each part ends with the old tests green.

| Part | Make green | Command |
| --- | --- | --- |
| 050a | L0 `TalonUpdateTest` 1 to 9, 11, 12 (10 is green in the stub). `ToolManageTest` 1. All old L0 `expect`s | `scripts/test.sh l0` |
| 050b | L2 `tool/ts1-update`, `ts2-stops`, `ts3-nostart`, `ts3b-foreign`, `ts4-rocforeign`, `ts5-windows`, `ts6-source`. L3 `tools/ts1-update-talon`. The old L2 and L3 cases | `tests/commands/run.sh tool/ts`, `tests/run.sh ts1-update-talon`, then `scripts/test.sh` |

After 050a and before 050b, `tool update talon` still ends in the stub of the flow (`todo: slice 050b`): the 8 tests of 050b stay red until then.

Live reads: none. No real network and no real long build in L0 to L3. L2 uses the fake `Fx`. L3 uses the real `Fx` with a fake GitHub server on the loopback address (`given/http`), a wrapper of `curl` (`given/bin/curl`), and real shell scripts as the downloaded `tln`.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-S2 | `tool update talon` installs the newest release that is old enough. The same version, or a lower one, is up to date (no downgrade). `--from-source` builds the tag as `tool install --git` | L0 `TalonUpdateTest` 3, 4, 9, 10. L2 ts1 runs 1 to 3, ts2 runs 6, 7, ts4, ts6. L3 steps 1, 2 |
| R-S3 | The new file is a temp file in the data bin dir. `tln --version` runs on it (an end other than exit 0 is exit 1, the old tln stays). Then the rename over the old file, and the entries `tln` and `roc` again | L0 `TalonUpdateTest` 6. L2 ts1 run 1, ts3 run 1, ts4. L3 steps 1, 4 |
| R-S1 | The sha256 of the file is the one in `sha256sums.txt` of the release. A difference, a missing `sha256sums.txt` and a file that the sums do not list are exit 16 | L0 `TalonUpdateTest` 5. L2 ts1 run 1, ts2 runs 1, 2, 4. L3 step 3 |
| R-SE13 | The same checks, from the point of view of safety: no file is renamed before the check | L0 `TalonUpdateTest` 5. L2 ts2 runs 1, 2, 4. L3 step 3 |
| R-T22 | The prebuilt file is run with `--version` before it replaces the old one | L0 `TalonUpdateTest` 6. L2 ts3. L3 step 4 |
| R-T9 | `min-release-age` applies to Talon: a release that is too young is not a candidate | L0 `TalonUpdateTest` 3. L2 ts1 run 1, ts2 (the `TALON_NOW` of each run). L3 steps 1, 3, 4 |
| R-ST9 | The entries `tln` and `roc` of the bin dir are made again, as 2 names for one file (R-ST13, R-ST14: hard link to a temp name, then rename) | L0 `TalonUpdateTest` 7. L2 ts1 run 1, ts4, ts5. L3 step 1 |
| R-ST6, R-ST11 | An entry that tln did not write is not replaced. A foreign `tln`: exit 2 before the download. A foreign `roc`: kept, with a warning | L0 `TalonUpdateTest` 7. L2 ts3b, ts4 |
| R-ST10 | Windows: each file that is replaced is renamed to `<name>.<16hex>.del` first. The test for a `.del` name and the list of `.del` files are pure (the sweep at each start is out of scope, Q-W1) | L0 `TalonUpdateTest` 8. L2 ts5 |
| R-HF2 | `chmod 0755` on the temp file (none on Windows) | L0 `TalonUpdateTest` 6. L2 ts1 run 1, ts5. L3 step 1 |
| R-IS2 | The asset names `tln-x64musl`, `tln-arm64musl`, `tln-x64mac`, `tln-arm64mac`, `tln-x64win.exe`, `sha256sums.txt`. The tags are `v<version>` | L0 `TalonUpdateTest` 1, 2. L2 ts5 |
| R-IS6 (read side) | The entry `talon` of `tools.json` is read and written. The form of its source is Q-S1 | L0 `TalonUpdateTest` 11, 12. L2 ts1 runs 1, 4, ts4 |
| R-DA2 to R-DA4 | One `spawn_all!` with 2 jobs (the file and `sha256sums.txt`), the downloader of the config, the temp names | L2 ts1 run 1, ts2. L3 step 1 |
| R-DI12 | `--offline` with a needed download is exit 15 | L0 `TalonUpdateTest` 9. L2 ts2 run 5, ts6 run 4 |
| R-CC1, R-CC2, R-CC6 | The lock of `tools.json` is for the last step only. The temp file and the scratch dir are deleted after a success and after a failure | L2 ts1 run 1, ts2 runs 2, 3, 4, ts3. L3 steps 1, 3, 4 |
| R-J1 to R-J4 | The text goes to stdout (stderr with `--json`). `--json` gives the `data` of `tool update` with one outcome | L0 `TalonUpdateTest` 9. L2 ts1 run 3 |
| R-FL12, R-CM16, R-CM19 | `update talon` takes `--from-source`. `--from-source` on any other `update` is exit 2. `update talon foo` and `update talon@1` are usage failures | L0 `ToolManageTest` 1, `TalonUpdateTest` 10. L2 `tu1-update` run 8 |
| R-T4, R-T25, Q-S2 | The entry `talon` is not a tool of the list: `tool list` and `tool update` (no name) do not see it | L0 `TalonUpdateTest` 11. L2 ts1 runs 4, 5. L3 step 5 |

Other rule ids that the tests name (the slice does not own them): R-T5, R-T23, R-T24, R-DA7, R-ST2, R-S4, R-C7, R-DI2, R-DI3, R-DI10, R-TF2, R-TF3, R-LY8, R-OUT2, R-ST7, R-ST13, R-ST14.

Rule check: `MISSING=1 scripts/rules.sh R-S R-ST R-T R-SE` lists only R-S5 (slice 051) and R-SE2, R-SE5, R-SE6, R-SE10, R-SE14, R-SE15, R-SE16 (not part of this slice). R-S1 to R-S4, R-T9, R-T22, R-ST9, R-ST10, R-SE13 each have a test.

## 2. Files

New files (also in `research/slice-050-revert/before/NEW.txt`). The code agent writes the bodies of the 2 stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/TalonUpdate.roc` (stub) | 138, 315 | Part A: `name`, `is_target` (complete in the stub: `Run` calls it for each `tool update`), `Release`, `asset_name`, `releases`, `pick`, `current`, `expected_sha`, `check_download`, `unlisted`, `missing`, `version_check`, `chmod_command`, `entries`, `kept_warning`, `del_name`, `del_moves`, `is_del`, `stale`, `up_to_date_text`, `updated_text`, `offline_failure`, `outcome`, `prebuilt_entry`, `source_of`, `source_text` |
| `cli/lib/TalonUpdateFlow.roc` (stub) | 33, 313 | Part C: `update!` (direct style). The reference has the private `run!`, `release_list!`, `prebuilt!`, `states!`, `staged!`, `installed!`, `source!`, `built!` (the step table is in the doc comment of the stub) |
| `tests/unit/TalonUpdateTest.roc` | 358 | 12 `expect`s |
| `tests/commands/cases/tool/ts1-update/` to `ts6-source/` (7 cases, with `ts3b-foreign`) | 19 to 24 files each | L2: 21 runs |
| `tests/scenarios/tools/ts1-update-talon/` | `cmd` 50, 17 files | L3: 5 steps (real `Fx`) |
| `research/slice-050-revert/` | | `stubs/`, `before/`, `mkstubs.py`, `restore.sh` (`stubs`, `before`), `mut.py`, `mutations.txt`, `mut-*.log`, `gen-talon.py` and `gen-l3.py` (write the given, fx, entry and rules files, no `expect/`), `red-run.log`, `green-run.log` |

Changed files (a copy of each is in `research/slice-050-revert/before/`). In the stub state these are complete (wiring) or as before:

| File | Stub state | Change of the reference (code agent) |
| --- | --- | --- |
| `cli/lib/ToolsJson.roc` | The types `TalonSource` and `Talon`, and the stubs `talon` and `put_talon` (374 lines, reference 462) | 050a: `others` (the skip of the key `talon` in `read` and `manifest`), `talon_of`, `talon_doc`, the generic `with_doc` and `merge` |
| `cli/lib/main.roc` | exposes `TalonUpdate` and `TalonUpdateFlow` | none |
| `cli/lib/Run.roc` | `tool update` calls `TalonUpdateFlow.update!` when `TalonUpdate.is_target(args)`, else `ToolUpdateFlow.update!` | none |
| `cli/lib/ToolManage.roc` | as before | 050a: row 7 only for `rebuild` and `remove`, `flag_check` has the new argument `talon` (it allows `--from-source` for `update talon`) |
| `cli/lib/ToolManageFlow.roc` | as before | 050a: `machine!` also gives `talon : Try(ToolsJson.Talon, [None])` (the entry is read from the same text as the tools) |
| `cli/lib/ToolUpdateFlow.roc` | as before | 050b: the public `consent_for!` (a wrapper of `consent!`) |
| `cli/lib/ToolBuild.roc` | as before | 050b: `attempt!` makes the layout with the key `facts.file.drop_suffix(".exe")` (the key is `talon`, the file is `tln`) |

Old tests that this slice changed (TW21, the expected files are read):

| File | Change |
| --- | --- |
| `tests/unit/ToolManageTest.roc` | the row `update talon` was `is not built yet`. Now `update talon`. New rows: `update roc-talon/talon`, `update talon --from-source`, `update talon foo`, `update talon@1`, `update --from-source`, the 2 parse failures of `--from-source` for `rebuild` and `rm`. `rebuild talon` and `rm talon` stay `is not built yet` |
| `tests/unit/l0-1.roc` | `import TalonUpdateTest` (the driver with the smallest time) |
| `tests/commands/cases/tool/tu1-update/` | run 8 was `tool update talon` (exit 2, `is not built yet`). Now `tool update --from-source` (exit 2, `works only for tln tool update talon`). Changed: `fx/commands`, `rules`, `expect/stdout`, `expect/stderr`. `expect/calls.log` is the same (no call) |

Module plan: every module stays under 490 lines (`ToolsJson` 462 is the largest).

## 3. Public signatures

The L0 tests call `TalonUpdate` and `ToolsJson`, so these are fixed (the stub files have the full types and doc comments):

| Function | Type |
| --- | --- |
| `TalonUpdate.asset_name` | `{ os : Setup.Os, target : Str } -> Str` |
| `TalonUpdate.releases` | `{ pages : List(Str), asset : Str } -> Try(List(Release), [BadPage(U64)])` |
| `TalonUpdate.pick` | `{ list : List(Release), now : U64, min_age : U64, current : Str, asset : Str } -> Try([Newer(Release), Current(Release)], Fail)` |
| `TalonUpdate.current` | `{ entry : Try(ToolsJson.Talon, [None]), running : Str } -> Str` |
| `TalonUpdate.expected_sha`, `check_download`, `unlisted`, `missing` | the checks of the sha256 (R-S1) |
| `TalonUpdate.version_check`, `chmod_command` | R-S3, R-HF2 |
| `TalonUpdate.entries` | `{ os, bin, tln : [Make, Foreign], roc : [Make, Foreign] } -> Try({ make : List(Str), warnings : List(Str) }, Fail)` |
| `TalonUpdate.del_name`, `del_moves`, `is_del`, `stale` | R-ST10 |
| `TalonUpdate.outcome`, `prebuilt_entry`, `source_of`, `source_text` | the report and the entry |
| `ToolsJson.talon` | `{ path : Str, text : Try(Str, [NotFound]) } -> Try(Try(Talon, [None]), Fail)` |
| `ToolsJson.put_talon` | `{ path : Str, text : Try(Str, [NotFound]), talon : Talon } -> Try(Str, Fail)` |

`TalonUpdateFlow.update! : Fx, Args => I32` is the one public function of the flow. Its private helpers are a proposal: the `calls.log` files fix the order of the `Fx` calls, not the names.

## 4. Tests

### L0 (`TalonUpdateTest`, 12 `expect`s, and one row set of `ToolManageTest`)

| # | Rows | Rules |
| --- | --- | --- |
| 1 | `asset_name`: the 5 targets, `.exe` on Windows only | R-IS2, R-S2 |
| 2 | `releases`: drafts, prereleases and tags that are no `v` and 3 numbers are left out. Only an asset with exactly the name counts. The order stays. A bad page, a release with no `tag_name`, a kept release with no readable `published_at`: `BadPage(n)` | R-IS2, R-DI3, R-DI10 |
| 3 | `pick`: no asset, too young (the edge: `published_at + min_age <= now`), numbers and not text (`0.10.0` above `0.9.0`, `0.4.0` above `0.3.4`, `1.0.0` above `0.9.9`), not the newest by time, same version or lower is `Current`, a tie gives the first, the 2 usage failures | R-T9, R-C7, R-S2, R-S4 |
| 4 | `current`: a prebuilt entry, a git entry with a tag ref, a branch ref, no entry | R-S2, R-T4 |
| 5 | `expected_sha` (the forms of a line: `*` of binary mode, `\r\n`, tab, upper case, short digest, a name that only starts like it, the first line wins), `check_download` (exit 16, the text), `unlisted`, `missing` | R-S1, R-SE13, R-DA4 |
| 6 | `version_check`: exit 0 is `Ok`, another exit, a signal, not started (all kind `Internal`). `chmod_command`: Linux and Windows | R-S3, R-T22, R-HF2 |
| 7 | `entries`: foreign `tln` (exit 2, the text of `ToolUpdate.foreign_failure`), both made, foreign `roc` kept with the warning, `.exe` on Windows | R-ST9, R-ST6, R-ST11 |
| 8 | `del_name`, `del_moves` (Windows only, in order), `is_del` (the 6 forms), `stale` (files only, byte order) | R-ST10, R-IS5 |
| 9 | `up_to_date_text`, `updated_text`, `offline_failure`, `outcome` and `ToolUpdate.data`, `prebuilt_entry`, `source_of`, `source_text` | R-J3, R-J4, R-DI12, R-T4 |
| 10 | `is_target`: `talon`, `roc-talon/talon`, no operand, another tool, 2 operands | R-FL12, R-CM16, R-CM19 |
| 11 | `ToolsJson.read` and `manifest` skip the key `talon`. `ToolsJson.talon`: prebuilt and git entries, no entry, no file, no `tools`, the failures of kind `Input` (exit 19) | R-T4, R-IS6, Q-S2 |
| 12 | `ToolsJson.put_talon`: in place (a field that Talon does not know stays), as the last entry, a file with no `tools`, a missing file, the other tools and fields stay, a newer `format` fails | R-TF2, R-TF3, R-T4 |

`ToolManageTest` 1 (the one `expect` with the table of rows) has the new rows of section 2.

### L2 and L3

| Case | Content |
| --- | --- |
| `tool/ts1-update` | 5 runs (the file `rules` has the table). The entry says 0.3.1. Update to 0.3.4 and skip the young 0.3.5 (the full call order), up to date (no request), `roc-talon/talon --json`, `tool list` hides the entry, `tool update` with no name leaves it alone |
| `tool/ts2-stops` | 7 runs, each with its own `TALON_NOW`: no `sha256sums.txt` (16), the sums do not list the file (16), curl 404 (15), a wrong sha256 (16), `--offline` (15), the success, up to date. `fx/mtimes` pins the cache page |
| `tool/ts3-nostart` | `--version` exits with 1: exit 1, nothing renamed, temp file deleted |
| `tool/ts3b-foreign` | a foreign `tln` in the bin dir: exit 2, no download |
| `tool/ts4-rocforeign` | no entry `talon`, a foreign `roc`: kept with the warning, `tln` made, the entry written |
| `tool/ts5-windows` | `os=windows`: no `chmod`, the `.del` renames before the rename over the file, 2 runs |
| `tool/ts6-source` | `--from-source`: 4 runs (the build with the tag commit, same commit up to date, no flag up to date, `--offline` exit 15) |
| `tools/ts1-update-talon` (L3) | 5 steps with the real `Fx`: the real update (hard links with `-ef`, the new file runs), up to date, a bad sha256 (v0.3.5, exit 16), a `--version` that exits with 3 (v0.3.6, exit 1), `tool ls` and `tool update` ignore the entry |

L3 does not depend on file age: the clock is `TALON_NOW`, and the given files are not read by mtime. `expect/http.log` is not kept (it has the real date).

## 5. Output (proposed, R-OUT2, TW24)

The design gives no text for these. They are proposals for the review (the expected files fix them):

| Case | Text |
| --- | --- |
| Updated | `updated talon 0.3.1 to 0.3.4 (roc-talon/talon)` (stdout) |
| Source build | `updated talon 0.3.1 to git v0.3.4@d0d0d0d0 (roc-talon/talon)` |
| Up to date | `talon 0.3.4 is up to date`, and for a source build `talon git v0.3.4@d0d0d0d0 is up to date` |
| `--json` | `data` is the `data` of `tool update` with one outcome: `{"tool":"talon","name":"roc-talon/talon","how":"updated","from":"0.3.1","to":"0.3.4"}`. `how` is `up_to_date` with `from` null |
| No release with the asset | exit 2 `roc-talon/talon has no release with tln-x64musl` |
| None old enough | exit 2 `no release of roc-talon/talon is old enough for min-release-age` |
| No sums file | exit 16 `the release v0.2.5 of roc-talon/talon has no sha256sums.txt, so tln cannot check tln-x64musl. tln is not changed.` |
| Sums lack the name | exit 16 `sha256sums.txt of v0.2.6 does not list tln-x64musl, so tln cannot check it. tln is not changed.` |
| Wrong sha256 | exit 16 `tln-x64musl of roc-talon/talon v0.3.2: the sha256 is <got>, but sha256sums.txt says <want>. tln is not changed.` |
| Download failed | exit 15, the text of `Toolchain.download_failed` with the id `talon 0.3.1` |
| `--offline` | exit 15 `tln 0.3.4 is not downloaded and --offline is set. Run the command without --offline.` With `--from-source`: the text of `GitRef.offline_failure` |
| New file does not start | exit 1 `the new tln 0.3.4 does not start (exit 1). The old tln stays.` (also `signal <n>`, `not started: <text>`) |
| Foreign `tln` | exit 2, the text of `ToolUpdate.foreign_failure` |
| Foreign `roc` | warning on stderr `warning: <path> is not a file that tln wrote, so tln keeps it. Run: tln setup --replace-roc` |
| Bad release page | exit 15 `the release list of roc-talon/talon (page <n>) is not a list of releases` |

## 6. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | Releases with no asset of the target are not candidates. Drafts, prereleases and tags that are not `v` and 3 numbers are left out | A failure for the newest release with no asset |
| D2 | A missing `sha256sums.txt` is Integrity (exit 16). A sums file that lacks the name is Integrity | A warning and an install with no check |
| D3 | `--offline` after the pick is Network (exit 15), with no entry check and no download | A silent keep of the old file |
| D4 | One `random!` gives the hex of the temp names and of the `.del` names. The temp file is `<data bin>/tln.<hex>.tmp`. The sums go to `<cache>/talon/tmp/<hex>/sha256sums.txt` | One random number for each name |
| D5 | The entry check runs before the download and again under the lock of `tools.json` (the entries can change during the download) | Only once |
| D6 | No prompt for the Talon download | A prompt as for a tool bundle |
| D7 | Windows on ARM64 is not special: `platform!` says `X64` there, so the asset is `tln-x64win.exe` | An `arm64win` asset (the design lists none) |
| D8 | A bad release page is Network (exit 15) | Input (exit 19) |
| D9 | The `.del` renames cover the data file and each entry that exists and is made again, in that order | Rename only the data file |

## 7. Out of scope

| Rule | What | Reason |
| --- | --- | --- |
| R-S1, R-SE13 (attestation) | The check of the GitHub attestation when the release has one | The design does not say how tln finds out that there is one: Q-A1. This part stops |
| R-ST10 (2nd sentence) | The sweep of `.del` files at each start of tln | The call at the start changes the `calls.log` of every case. The pure `is_del` and `stale` are here (Q-W1) |
| R-ST10 (ordinary tools) | `.del` renames for an ordinary `tool update` or `rebuild`, and for `--from-source` on Windows | Only the prebuilt Talon path uses `del_moves` (Q-W2) |
| R-ST10 (real Windows) | A real rename of a running `.exe` | There is no Windows machine in L3. L2 fixes the order of the calls |
| R-ST9 (2nd sentence), R-U1 | The entries `tln` and `roc` for a case where `tln update` must act on a conflict with R-ST11 | R-ST9 and R-ST11 say different things for a foreign `roc`: the tests follow R-ST11 (Q-E1) |
| R-IS5, R-IS6 (write side) | The install script, and `tln setup` that writes the entry `talon` | Slice 052 (they must write the same `prebuilt` form: Q-S1) |
| R-S5, R-RM5 | `tool rm talon`, `tool rebuild talon` | Slice 051 (`rm`), Q-R1 (`rebuild`). Both stay `is not built yet` |
| R-T9 for ordinary tools, R-T24 | Not changed | Slices 047, 048 |

## 8. Questions (TW17) and design gaps

The tests pin the default of each question until the human answers.

| # | Question | Default (pinned) | Rejected |
| --- | --- | --- | --- |
| Q-S1 | R-IS6 says the entry `talon` has "source: install script". What is the form of the source in `tools.json`? | A new kind `prebuilt`: `{"kind":"prebuilt","version":"0.3.4","url":"<asset url>"}`. A source build has the git kind `{"kind":"git","commit","ref","path":"cli"}`. Setup (052) writes the same form | A kind `script`. The kind `release` (its url means an app bundle) |
| Q-S2 | The entry `talon` is no tool. What do `read`, `manifest`, `tool list` and `tool update` (no name) do with it? | `read` and `manifest` skip the key `talon`. `tool list` does not show it. `tool update` with no name leaves Talon alone. This also closes the 048 question Q-T1 (exit 19 for a file with the entry) | `tool list` shows a row `talon` |
| Q-A1 | How does tln find the attestation of a release (R-S1, R-SE13)? | Not in this slice. The sha256 of `sha256sums.txt` only | A call to the GitHub attestation API |
| Q-F1 | What does `--from-source` build? | The tag `v<version>` of the pick, as a git source with the path `cli`, as `tool install --git`. It builds also when the pick equals the installed version. Up to date only when the entry is a git entry with the same commit | The default branch |
| Q-F2 | Does a source build run `--version` (R-T22)? | No. R-T22 names the prebuilt file | A check of the built file |
| Q-E1 | Which entries does the update make? | `tln` and `roc` from the same file. An absent `roc`, or one that tln wrote, is made. A foreign `roc` is kept with a warning. A foreign `tln` is exit 2 before the download | A foreign `roc` is exit 2 as well |
| Q-M1 | No entry `talon` in `tools.json` (Talon came from the install script of an older tln) | The update works and writes the entry. The installed version is the running `Help.version` | Exit 2 with a hint |
| Q-V1 | What does the `--version` check read? | Only the exit code 0. The output is not read | The output must equal the release version |
| Q-D1 | What is the installed version? | The version of a prebuilt entry, or the version of the tag ref (`v<X.Y.Z>`) of a git entry, else `Help.version`. A lower release is `Current` (no downgrade) | Always the running `Help.version` |
| Q-W1 | Where does the sweep of `.del` files run? | Not in this slice (section 7) | A call in `Run.run!` for each command |
| Q-W2 | `.del` for the ordinary tools on Windows | Not in this slice | The same helper for each replace |
| Q-R1 | `tool rebuild talon` | `is not built yet` | A rebuild from the git entry |
| Q-K1 | A tool that is named `talon` (a binary name that clashes with the key of the entry) | Not tested: the design does not say. The key `talon` of `tools.json` is Talon itself | A failure at `tool install` |

Why a foreign `tln` stops the update and a foreign `roc` does not (Q-E1): R-ST6 forbids to overwrite any file that tln did not write. For `roc`, R-ST2 gives the "No" way (keep the file, print `tln setup --replace-roc`), so the update keeps it with that line. For `tln` the design has no text: the exit 2 is by the same rule as `ToolUpdate.foreign_failure` of slice 048 (Q-U3), because an update that keeps the old `tln` does not do its job. That choice has no design source (a design gap).

## 8b. Design gaps

Manager review, 2026-10-25: all of these are design gaps. The tests pin the default.

| Id | Gap | Pinned default |
| --- | --- | --- |
| Q-S1 | R-IS6 says "source: install script" and gives no form for the source of the entry `talon` (a TW24 data proposal) | kind `prebuilt` `{"kind":"prebuilt","version","url"}`. A source build: the git kind with path `cli` |
| Q-S2 | R-T4 says `tool ls` reads `tools.json`, but not if it shows Talon | `read` and `manifest` skip the key `talon`. Closes 048 Q-T1 |
| Q-A1 | R-SE13 and R-IS3 (attestation when `gh` is installed and logged in) are not in 050. A follow-up row in `PLAN-P1.md` 5b | sha256 only |
| Q-F1, Q-F2 | What `--from-source` builds, and if it runs `--version` | tag `v<version>`, path `cli`; no `--version` run |
| Q-E1 | R-ST9 (2nd sentence) and R-ST11 differ for a foreign `roc`. No text says that a foreign `tln` is exit 2 | R-ST11 wins. A foreign `roc` is kept with a warning. A foreign `tln` is exit 2 before the download |
| Q-M1 | No entry `talon` in `tools.json` | the update works and writes the entry |
| Q-V1 | What the `--version` check reads | exit 0 only |
| Q-D1 | What the installed version is | the entry, or the tag of a git ref, else `Help.version`. No downgrade |
| Q-R1 | `tool rebuild talon` | `is not built yet` |
| Q-W1, Q-W2 | The `.del` sweep at each start and `.del` renames for ordinary tools are fixed by R-ST10, but not in 050. Follow-up slice 050c in `PLAN-P1.md` | out of scope (the pure `is_del`, `stale` and the Talon `del_moves` are here, `ts5` stays) |
| Q-K1 | A tool that is named `talon` | untested |
| (no id) | The design gives no asset for Windows on ARM64 (D7) | the x64 asset |
| Q-B1 | R-TF6 is for content that does not parse. An entry `talon` that parses but has a bad shape (`"talon":5`): the design does not say if `tool list` fails. The code skips the key `talon` there, so `tool list` lists the other tools with exit 0. `tool update talon` and `tool update` read the entry and fail with exit 19 (L2 `ts7-badentry`). The code agent's note said `tool list` also gives 19: that is wrong, the gap step ran it. A bad entry of an ordinary tool is exit 19 for `tool list` (slice 048) | `tool list` is not pinned (no run in `ts7`). Question for the human: should `tool list` fail on a bad entry `talon`, as on a bad entry of another tool? |
| Q-H1 | R-HF2 gives the `chmod` and no failure kind. A failed `chmod` job | the code gives kind Environment (exit 18) `cannot make <temp> executable: <end>`. The text is a proposal (TW24), the kind is a gap. Not tested (a failure of `chmod` after a good download is unlikely to hide a bug) |
| Q-Q1 | R-FL4: `--quiet` prints only errors and answer lines. R-J2: warnings go to stderr. Is the warning of a kept foreign `roc` hidden by `--quiet`? | the code prints it (it changes only `out!`, as for the other commands). Not tested |
| D5 | The second check of the entries under the lock of `tools.json` is a decision of this slice (R-CC6 gives the lock, R-ST11 the test of an entry) | pinned only by the order of the calls in the `calls.log` of `ts1`, `ts5`, `ts5b`. The fake `Fx` has no way to change the bin dir during the download, so no case tests the second check itself |

## Notes for later slices

| Slice | Note |
| --- | --- |
| 052 (setup) | `tln setup` and the install script must write the entry `talon` in the form of Q-S1: `{"kind":"prebuilt","version","url"}` |
| 050c | The `.del` sweep at each start (R-ST10) and the `.del` renames for ordinary `tool update` and `rebuild`. The pure `TalonUpdate.is_del`, `stale` and `del_moves` exist |
| 5b follow-up | The attestation check (R-SE13, R-IS3) for the Talon download |

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| A decimal literal is `Dec` by default | `10.U64`, or a typed value, in the rows |
| `keep_oks(...).first()` crashed the app in an earlier slice | The reference uses it in `expected_sha` and `read_release` (pure code, small lists) and the L0 rows pass. If the code agent sees a crash, use a recursive match |
| Warnings fail a build | The mutations use a condition that is not known at compile time (`facts.hex != "zz"`), the first form was `INVALID(warning)` |
| `Str.inspect` writes the fields in alphabetical order | The rows compare the text of the fields, not the text of a record |
| `roc check` (the MCP tool) cannot check a headerless unit module | A scratch driver `app` runs `TalonUpdateTest` alone |
| A module cannot import a module that imports it | `ToolManage` does not import `TalonUpdate` (the check of the operand is in `ToolManage`, `Run` uses `TalonUpdate.is_target`) |
| `UPDATE=1` writes the expected files | Run only with the filters `tool/ts`, `tool/tu1`, `ts1-update-talon` (TW21) |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Order | 050a: `TalonUpdate`, `ToolsJson`, `ToolManage`, `ToolManageFlow` (L0 green: `scripts/test.sh l0`). Then 050b: `TalonUpdateFlow`, `ToolUpdateFlow.consent_for!`, `ToolBuild` (L2: `tests/commands/run.sh tool/ts`, L3: `tests/run.sh ts1-update-talon`) |
| `is_target` | complete in the stub. Do not change it |
| `ToolManage` | no import of `TalonUpdate` (a cycle). `flag_check` gets the Bool `talon` for `update` with one operand `talon` or `roc-talon/talon` |
| `ToolsJson` | `others` is used by `read` and `manifest`. The key `talon` is Talon, not a tool. `with_doc` and `merge` are the generic forms of the old `with_tools` and `merge` |
| Calls | The step table in the doc comment of `TalonUpdateFlow` and the `calls.log` files fix the order. One `random!` for the update. The lock is for the last step only |
| Tests | do not edit the tests (TW18). A wrong test goes back to the test agent |

## 11. Red run, revert check

Red run with the stubs (`research/slice-050-revert/red-run.log`): `scripts/test.sh` (all steps).

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest, l1 | pass | the stubs compile with no warning |
| l0 | 12 failed | `TalonUpdateTest` 1 to 9, 11, 12: `ROC CRASHED todo: slice 050a`. `ToolManageTest` 1: 4 rows are `tln tool update talon is not built yet` in place of `update talon` (a wrong value). `TalonUpdateTest` 10 (`is_target`) passes: that function is complete in the stub |
| l2 | 7 failed, 145 passed | `tool/ts1-update` to `tool/ts6-source`: `ROC CRASHED todo: slice 050b` (`Run` calls the stub flow) |
| l3 | 1 failed, 77 passed, 1 skipped | `tools/ts1-update-talon`: the same crash in step 1 |

The old L0, L2 and L3 tests pass in the stub state (the `tu1-update` run 8 and the `ToolManageTest` rows that this slice changed pass in L2 and fail only in the 4 rows above).

Green run with the reference (`green-run.log`): all steps pass (l0 7.5 s of 10 s, l2 8.4 s of 30, l3 10.0 s of 60).

Revert check (`mutations.txt`, 10 hand mutations of the most tricky behaviors, filtered runs, the reference is put back after each one): every mutation is killed by at least one layer.

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| m1 `pick` ignores the age (R-T9) | killed | killed | killed |
| m2 `pick` allows a downgrade (R-S4) | killed | survived | survived |
| m3 the version order compares the patch first (rows added to L0 3 after the first run: L0 survived) | killed | killed | survived |
| m4 `del_moves` renames on every system (R-ST10) | killed | killed | killed |
| m5 `version_check` accepts any exit code (R-S3) | killed | killed | killed |
| m6 the key `talon` is not skipped in `read` (Q-S2) | killed | killed | killed |
| m7 `current` ignores the tag of a git entry (Q-D1) | killed | killed | survived |
| m8 the sha256 check result is ignored (R-S1) | survived | killed | killed |
| m9 a foreign `roc` is replaced (R-ST6) | killed | killed | survived |
| m10 the temp file stays after a failure (R-CC2) | survived | killed | killed |

## Review (manager, 2026-10-25)

Accepted: D1 to D9, the output and `--json` proposals (section 5), the split 050a and 050b (section header, one test set). Q-S1, Q-S2, Q-A1, Q-F1, Q-F2, Q-V1, Q-D1, Q-M1, Q-E1, Q-W1, Q-W2, Q-R1, Q-K1 accepted with the defaults of section 8, all as design gaps (section 8b). The reference was deleted. No test changed in this review.

## Verify results (code agent)

Part 050a (L0 only, a scratch driver of `TalonUpdateTest` and `ToolManageTest`, the code put back and compared after the run). Part 050b is not done yet.

| Mutation | Test that failed |
| --- | --- |
| m1 `pick`: the edge `published_at + min_age <= now` becomes `<` | `TalonUpdateTest` 3 |
| m2 `pick`: the same version is `Newer` | `TalonUpdateTest` 3 |
| m3 `sum_line`: no white space after the digest | `TalonUpdateTest` 5 |
| m4 `is_del`: an empty name is allowed | `TalonUpdateTest` 8 |
| m5 `read`: the key `talon` is not skipped | `TalonUpdateTest` 11 |
| m6 `entries`: a foreign `tln` is not checked | `TalonUpdateTest` 7 |
| m7 `merge`: the fields that Talon does not know are dropped | `TalonUpdateTest` 12 and 1 more |
| m8 `ToolManage`: `update talon` is blocked as in row 7 | `ToolManageTest` 1 |

Caught 8 of 8.

Part 050b (L2 `tool/ts` filter only; the code put back and compared after the run):

| Mutation | Test that failed |
| --- | --- |
| b1 the result of `check_download` is ignored (R-S1) | L2 `tool/ts2-stops` |
| b2 `--offline` is not checked for the prebuilt file (R-DI12) | L2 `tool/ts2-stops` |
| b3 the temp file is not deleted after a stop (R-CC2) | L2 `tool/ts1-update`, `tool/ts2-stops` |
| b4 the `--version` result is ignored (R-S3, R-T22) | L2 `tool/ts3-nostart` |
| b5 only the entry `tln` is made again (R-ST9) | L2 `tool/ts1-update`, `ts2-stops`, `ts5-windows` |
| b6 the `.del` renames in another order (R-ST10) | L2 `tool/ts5-windows` |
| b7 the same-commit test of a source build is inverted (R-T24) | L2 `tool/ts6-source` |
| b8 the scratch dir of the source is not deleted (R-CC2) | L2 `tool/ts6-source` |
| b9 the layout key of `ToolBuild.attempt!` is the key, not the file | L2 `tool/ts6-source` |
| b10 the warning of a kept `roc` is not printed (R-ST6) | L2 `tool/ts4-rocforeign` |

Caught 10 of 10. A first b10 (the entry check under the lock is left out) did not compile, so it was replaced by the b10 above: no test changes the bin dir during the download, so only the call order (the `calls.log` of ts1) fixes the second check.

Code files (100 percent of the slice code): `research/slice-050-revert/code-final/` with `code-final.sha256` (`sha256sum -c research/slice-050-revert/code-final.sha256` from the repo root). `scripts/test.sh` exits 0 (check, fmt, l0, l2, l3, selftest, l1).

## Gap tests (test agent, 2026-10-25)

The code is in (status verify, `code-final.sha256`). The gap step checked the 6 decisions of the code agent against the design. No code changed: after each hand mutation the file was put back, and `sha256sum -c research/slice-050-revert/code-final.sha256` gave OK for all files. The case files are written by `research/slice-050-revert/gen-gap.py` (it does not touch the old cases).

| Decision of the code | Design | Result |
| --- | --- | --- |
| chmod job fails: Environment, exit 18 | R-HF2 has no failure kind | Gap row Q-H1, no test |
| Warning of a kept foreign `roc` after success, also with `--quiet` | R-FL4 and R-J2 do not agree on warnings | Gap row Q-Q1, no test |
| Entry check again under the lock | Not fixed by the design (D5) | Gap row D5, no test of the check itself |
| `.del` list: the data file (when its sha256 was readable), then each made entry that exists, in that order | R-ST10: a file is renamed before it is replaced. A file that is not there is not replaced | New row `ts5b-winfresh` (below). The old `ts5-windows` has all 3 files |
| `--from-source`: entry written by `ToolBuild.install!`, key `talon`, git kind, path `cli` | Q-F1 | Already fixed by `ts6-source` run 1 (`tree.diff` has `"path":"cli"`). No new row |
| Malformed entry `talon`: exit 19 | R-TF6 (content that does not parse) | New row `ts7-badentry`. `tool list` is exit 0, not 19: gap row Q-B1 |

| Row | Layer, file | Behavior | Rules | Hand mutation, result |
| --- | --- | --- | --- | --- |
| G1 | L2 `tests/commands/cases/tool/ts5b-winfresh` (1 run) | Windows, nothing installed: no `.del` rename (no `rename` of a file that is not there), the temp file is renamed to `<data>/bin/tln.exe`, the entries `tln.exe` and `roc.exe` are made, `tools.json` is made. Exit 0 | R-ST10, R-ST9, R-S3, R-HF2, Q-M1 | `installed!`: the data file is in the `.del` list also when `now.old` is `NotFound`. Killed: exit 18 and a `rename ... tln.<hex>.del` line in `calls.log`. `ts5-windows` still passes |
| G2 | L2 `tests/commands/cases/tool/ts7-badentry` (2 runs) | `"talon":5` and the tool `gp`: `tool update talon` and `tool update` give exit 19 `<path>: tool talon: is not an object`, after the read of `tools.json` only (no request, no write) | R-TF6, R-S2, R-T25 | `ToolManageFlow.machine!`: `ToolsJson.talon(...) ?? Err(None)` (the failure is dropped). Killed: no exit 19, the command goes on to the release list (`no GitHub repository roc-talon/talon`) |

Totals now: L2 has 9 cases of slice 050 (23 runs). L0 and L3 are as before. No old expected file changed.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-050-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.6, fmt 0.3, l0 7.5, l2 9.2, l3 10.0, selftest 2.9, l1 36.2 s |
| Code pass | part a 8 of 8, part b 10 of 10 mutations caught |
| Gap tests | L2 `tool/ts5b-winfresh` (Windows, nothing installed) and `tool/ts7-badentry` (bad `talon` entry, exit 19); 2 hand mutations caught; no code bug |
| Q-B1, Q-H1, Q-Q1, D5 | Not fixed by the design. Code stays as it is: `tool list` skips a bad `talon` entry (exit 0); a failed chmod is exit 18; the kept-roc warning shows with `--quiet`. Recorded as design gaps in PLAN-P1 5b. |
