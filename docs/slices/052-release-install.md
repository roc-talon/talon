# 052 Release and install scripts: the release workflow, the tests of `install.sh`, the entry `talon` that `tln setup` writes

Phase: P1. Status: done

Slice 052 closes the Talon-as-a-tool group (CLI 6.5: R-S1, R-S4, R-IS1 to R-IS8; Design 6.2: R-HF10; CLI 4: R-NI15; CLI 1: R-EV10). `install/install.sh`, `install/install.ps1` and `install/test.sh` exist. So this slice is a gap slice: it finds what the rules say and no test checks, adds the tests, and lists the code that is missing. Three parts are missing:

| Part | What is missing | Where the code goes |
| --- | --- | --- |
| A. Release workflow | No `.github/workflows/release.yml`: no release has the 5 binaries, `sha256sums.txt`, the 2 scripts and the attestation (plan answer Q2, `PLAN-P1.md` section 5) | `.github/workflows/release.yml` (about 110 lines of YAML) |
| B. `TALON_YES` | R-EV10 and R-NI15 say that `TALON_YES=1` skips the question of both scripts. `install.ps1` reads it. `install.sh` does not | `install/install.sh` (3 lines) |
| C. The entry `talon` | R-IS6: `tln setup` writes the `talon` entry of `tools.json` when it is missing. Slice 027 (D14) left it for this slice. Today `tln setup` writes no entry. | `TalonUpdate` (3 pure functions, about 25 lines), `SetupFlow` (about 50 lines) |

Size (TW19): the plan row says 150. The private reference (`research/slice-052-revert/reference/`, kept until the review is applied) has about 70 changed lines in `SetupFlow` and 14 lines in the 3 bodies of `TalonUpdate`. The workflow is about 110 lines of YAML (the fixture `tests/fixtures/ci/release-good.yml` is a conforming file of 93 lines). No module is over 490 lines. One pass for the code agent. Order of work: C, B, A.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-S1 | `install.sh` takes a prebuilt binary from the release, checks the sha256, and the attestation when there is one | `install/test.sh` row `attestation` (good, bad, `gh` not logged in). `ciscan release`: the workflow makes the attestation of the 5 binaries. The attestation of `tln tool update talon` is not in this slice (section 8, decision D8) |
| R-S4 | No rollback command, no copy of the old binary. The repair path is `install.sh --version <v>`, which needs no working `tln` | `install/test.sh` row `repair`: an old `tln` that does not start, and a step back from a newer release; the bin dir has no other file |
| R-IS1 | 2 scripts. `install.sh` is POSIX `sh` (dash, bash, busybox). Each release has both scripts as assets | `install/test.sh` runs all rows with the 3 shells. `ciscan release`: `gh release create` names `install/install.sh` and `install/install.ps1`. PowerShell 5.1 is out of scope (section 9) |
| R-IS2 | One binary for each Roc target: the 5 names and `sha256sums.txt`. A shell under Rosetta gets arm64. Windows on ARM64 gets `tln-x64win.exe`. Other systems stop with an error that lists the targets | `install/test.sh` rows `targets` (7 machines) and `unsupported platform` (the list of targets). `ciscan release`: the matrix, the asset names, the system of each target. L0 `TalonUpdateTest` 13: the URL of each asset. The ARM64 row of `install.ps1` exists |
| R-IS3 | `install.sh` checks sha256 (exit 16) and the attestation. It uses `latest/download/` URLs, no API call, no token | `install/test.sh` rows `URLs` (a fake `curl` logs the 3 URLs, no `api.github.com`, no token), `no sha256 line`, `sha256 mismatch`, `attestation` |
| R-IS4 | The script asks `Proceed? [Y/n]` (R-NI15, kind Default). The non-interactive rules of CLI 4. Under `curl \| sh` the answer comes from `/dev/tty`. Non-interactive: no question. `--yes`, `-Yes`, `TALON_YES=1` skip it | `install/test.sh` rows `the question` (a pseudo terminal, `cat install.sh \| sh`): n, Enter, `--yes`; row `TALON_YES=1`; 5 rows of the non-interactive settings |
| R-IS5 | The download is a temp file in the bin dir. `--version` runs on it. Then the rename. A failed check keeps the old file and leaves no temp file | `install/test.sh` row `temp file`: `version.log` has the path `<bin>/.tln.<x>`; a binary that exits 1 keeps the old `tln`, no temp file |
| R-IS6 | The script runs `tln setup` with `--yes` and `--no-modify-path` when given. `tln setup` writes the `talon` entry when it is missing, then R-ST1 to R-ST6. With a terminal, `/dev/tty` is the stdin of `tln setup` | `install/test.sh`: `stdin.log` is `tty` under a terminal, the flags arrive. L0 `TalonUpdateTest` 13 (the entry). L2 `setup/st5-talon-entry`, `setup/st6-talon-in-file`. L3 `setup/st1-setup-real` steps 1, 1b, 3 |
| R-IS7 | Exit codes 2 (bad argument), 15 (download), 16 (checksum, attestation), 1 (the rest). `install.ps1` under `irm \| iex` throws | `install/test.sh`: 2 (3 forms), 15, 16 (3 forms), 1 (platform, binary that does not start, `cancelled`). The `throw` of `irm \| iex` is out of scope (section 9) |
| R-IS8 | No uninstall script. `tln tool rm talon` removes Talon. `install.sh --version <v>` repairs | `install/test.sh` row `unknown argument`: no `uninstall` file in `install/`, no word in the help text, `--uninstall` is exit 2. `tln tool rm talon` is slice 051 |
| R-HF10 | Talon ships 5 targets. No `arm64win`. Windows on ARM64 installs `tln-x64win.exe` | `ciscan release`: the text has no `arm64win`, the matrix has the 5 targets. `install.ps1` ARM64 row. L0 `TalonUpdateTest` 13 |
| R-NI15 | The prompt of the install scripts: Yes by default, answers `--yes`, `-Yes`, `TALON_YES=1` | `install/test.sh` rows `the question`, `TALON_YES=1`, `latest release` (the text `Non-interactive mode: no prompt`) |
| R-EV10 | `TALON_YES=1`: the install script does not prompt | `install/test.sh` row `TALON_YES=1` (red: `install.sh` reads no such variable) |
| R-S2, R-T4, R-CC1, R-CC6, R-TF2 (write side of the entry) | The entry has the form of 050 Q-S1. One atomic write, under the lock of `tools.json`. Other tools and fields stay | L2 `setup/st5-talon-entry` (new file), `setup/st6-talon-in-file` (a tool and an unknown field stay) |

`MISSING=1 scripts/rules.sh R-IS R-S R-HF R-NI R-EV` lists no id of this slice (`scripts/rules.sh` now also reads `install/`: its `TEST_DIRS` has `install`, because `install/test.sh` is the test of R-IS).

## 2. What the tests change in the repository

| File | Change | Part |
| --- | --- | --- |
| `install/test.sh` | new rows (55 results for 3 shells, was 17), rule ids in the comments, the fake `uname`, `gh`, `curl`, the pseudo terminal. The shebang is `#!/usr/bin/env bash`. 3 rows of `pwsh` (not run here, section 7) | B, A, C |
| `tests/selftest.sh` | New rows `ci/release` (the real workflow), `ciscan release` (the good fixture), `ciscan release edits` (6 edits of the fixture fail), `install` (runs `install/test.sh` for each shell of the machine, at the same time, and `pwsh` when there is one) | A, B |
| `tests/tools/ciscan.py` | The check `release` (the shape of `release.yml`) | A |
| `tests/fixtures/ci/release-good.yml` | New: a file that `ciscan release` accepts. The code agent can use it as a shape. It is not the workflow. | A |
| `scripts/rules.sh` | `TEST_DIRS` has `install` | all |
| `tests/unit/TalonUpdateTest.roc` | 1 new `expect` (11 rows: the URL, the entry, the line) | C |
| `cli/lib/TalonUpdate.roc` | 3 stubs: `release_url`, `setup_entry`, `recorded_text` | C |
| `tests/commands/cases/setup/st5-talon-entry`, `st6-talon-in-file` | New L2 cases | C |
| `tests/commands/cases/setup/st1-flow`, `st2-copy-fallback`, `st3-gaps` | The given `tools.json` has an entry `talon` of the form `prebuilt` (st1: it had the old form `{"source":"install script"}`; st2 and st3 had no file). So their expected files stay as they are: setup keeps an entry that is there (R-IS6 "when it is missing") | C |
| `tests/scenarios/setup/st1-setup-real` | `tools.json` has no `talon` key now (it had `"talon":{}`), steps 1b and 3 print and compare the entry | C |
| `research/release-targets/` | `build-all.sh` and `linux-cross.txt`: the evidence for the matrix (section 6) | A |

## 3. Public interface (the stubs)

All in `cli/lib/TalonUpdate.roc`. The bodies are `crash "todo"`.

| Function | Signature | Contract |
| --- | --- | --- |
| `TalonUpdate.release_url` | `{ version : Str, asset : Str } -> Str` | `https://github.com/roc-talon/talon/releases/download/v<version>/<asset>` (the form of the install script for an exact version, R-IS3) |
| `TalonUpdate.setup_entry` | `{ have : Try(ToolsJson.Talon, [None]), version : Str, os : Setup.Os, target : Str, sha256 : Str, now : U64 } -> [Keep, Put(ToolsJson.Talon)]` | `Ok(_)`: `Keep` (an entry of any readable form stays). `Err(None)`: `Put` the entry: source `Prebuilt({ version, url: release_url(version, asset_name(os, target)) })`, `hashes` `[]`, `nightly` `""`, `target`, `sha256`, `libs` `[]`, `installed_at` `Clock.format_utc(now)` |
| `TalonUpdate.recorded_text` | `{ version : Str, path : Str } -> Str` | `recorded talon <version> in <path>` |

Nothing else changes in a signature. `Setup.Os`, `ToolsJson.talon`, `ToolsJson.put_talon`, `BuildSkip.target`, `Clock.now!`, `Fx.locked!` and `SetupIo.write_file!` exist.

## 4. Part C: the flow of `tln setup` with the entry

The L2 cases fix these calls. A new step is marked `new`.

| Step | Does | Rule |
| --- | --- | --- |
| 3 (changed) | The `read_files!` of `tools.json` gives the text. `Setup.tool_names` as before. `ToolsJson.talon` on the same text: `Ok(Err(None))` is a missing entry. No new call. | R-IS6 |
| 5 (as before) | `sha256_file!` of `<data bin>/tln`: its sha256 is the `sha256` of the entry. No new call. | R-IS6 |
| 10a (new, first write of step 10, after the prompts of step 9) | Only when the entry is missing, and `BuildSkip.target` knows the machine: `Clock.now!` (one `clock` call), then `Fx.locked!` on `Roots.item(ToolsJson)` (`Wait`): `read_files!` of `tools.json` again (R-CC6), `ToolsJson.talon` again, `TalonUpdate.setup_entry`, `ToolsJson.put_talon`, one `write_atomic!`. | R-IS6, R-CC6, R-CC1, R-CC3 |
| 12 (changed) | When the entry was written, the first output line is `TalonUpdate.recorded_text({ version: Help.version, path })` on stdout (`Common.shown_fx`: stderr with `--json`). | R-OUT2 |

An entry that is there: no `clock`, no lock, no write, no line (so the calls of an up-to-date run stay as before). The L2 cases show the order: `read_files`, `list_dirs`, `sha256_file`, `path_roc`, `read_files` of the completion, then `clock`, `lock`, `read_files`, `write_atomic`, `unlock`, then `make_dirs` and the entries.

## 5. Output (proposed, R-OUT2, TW24)

| Output | Text | Where |
| --- | --- | --- |
| The first line of `tln setup`, when the entry was written | `recorded talon <version> in <path of tools.json>` | stdout (stderr with `--json`). Example: `recorded talon 0.0.0 in $HOME/.local/share/talon/tools.json` |
| `--json` `data` of `setup` | No new field. The entry is a side effect of the install, not a result of `setup`. The line goes to stderr in `--json` mode | the existing `data` |
| The entry | `{"name":"roc-talon/talon","source":{"kind":"prebuilt","version":"<v>","url":"https://github.com/roc-talon/talon/releases/download/v<v>/tln-<target>"},"build":{"hashes":[],"nightly":"","target":"<target>"},"sha256":"<sha256 of the file tln>","libs":[],"installed_at":"<time>"}` (the form of 050 Q-S1). The URL always names the release page of Talon: `tln setup` does not know the mirror (`TALON_DOWNLOAD_BASE`) or the repository (`TALON_REPO`) that the script used | `tools.json` |
| `install.sh` texts | No change (the tests read `Proceed? [Y/n]`, `cancelled`, `Non-interactive mode: no prompt`, `attestation ok`, `attestation check failed`, `attestation not checked`, `sha256sums.txt has no line for <asset>`, `does not start`, `no prebuilt tln for <os>/<arch>` and the list `x64musl, arm64musl, x64mac, arm64mac`) | stderr |

## 6. Part A: the release workflow (`ciscan.py release`)

No workflow can run here, and a test never makes a release. So the rows read the file. `.github/workflows/release.yml` must have this shape (the reader is the YAML subset of 018b). `tests/fixtures/ci/release-good.yml` is a file that passes.

| Item | Required | Why |
| --- | --- | --- |
| `on` | `push` with `tags` only, a list of patterns that start with `v`. No branch, no `pull_request`, no `schedule`, no `workflow_dispatch` | A release is a tag `v<X.Y.Z>` (`TalonUpdate.releases` takes only that form). A run by hand has no tag. |
| Top-level `permissions` | `contents: read` only | Least privilege (the `yaml` row of 018b) |
| Jobs | `build` and `publish` | |
| `build` | `runs-on: ${{ matrix.os }}`, no write permission, `defaults.run.shell: bash`, `actions/checkout`, the guard step (Q-V: reads `version` from `cli/lib/Help.roc`, compares it with `v` + `$GITHUB_REF_NAME`, `exit 1` when they differ, before the build), the `ROC_TAG` step and `scripts/get-roc.sh` as in `ci.yml` (TW28), then `roc build cli/main.roc --opt=speed --target=${{ matrix.target }} --output=${{ matrix.asset }}`, then `actions/upload-artifact` (name `${{ matrix.target }}`, path `${{ matrix.asset }}`) | |
| Matrix | 5 entries `os`, `target`, `asset`: `x64musl` and `arm64musl` on `ubuntu-*`, `x64mac` and `arm64mac` on `macos-*`, `x64win` on `windows-*`. The assets are `tln-x64musl`, `tln-arm64musl`, `tln-x64mac`, `tln-arm64mac`, `tln-x64win.exe`. The text has no `arm64win` | R-IS2, R-HF10. The systems are the result of the build test below |
| `publish` | `needs: build`, `ubuntu-*`, permissions exactly `contents: write`, `id-token: write`, `attestations: write`. Steps in this order: checkout, `actions/download-artifact`, a run of `install/test.sh` (the scripts are tested before they are released), `sha256sum tln-* > sha256sums.txt`, `actions/attest-build-provenance` with `subject-path` that names `tln-*`, `gh release create` | R-S1, R-IS1, R-IS2 |
| `gh release create` | Names `--verify-tag`, `tln-*`, `sha256sums.txt`, `install/install.sh`, `install/install.ps1`. `GH_TOKEN` is in its env | The 8 assets of a release (R-IS1, R-IS2) |
| No | Literal nightly tag, `cloudflare-workers`, `.cache/nightlies`, an unpinned action | TW28 |

Evidence for the matrix (`research/release-targets/build-all.sh`, 2026-10-25, Linux x86-64, `--opt=speed`, the 5 builds at the same time, 346 to 373 s):

| Target | Result on Linux | So |
| --- | --- | --- |
| `x64musl`, `arm64musl` | Built (ELF, static) | One Ubuntu runner builds both |
| `x64mac`, `arm64mac` | `ld64.lld: library not found for -lSystem`: LinkFailed | A macOS runner builds both |
| `x64win` | `lld-link: undefined symbol mainCRTStartup, memcpy, __chkstk`: LinkFailed | A Windows runner builds it |

## 7. Tests

| Layer | File and case | Checks | Today |
| --- | --- | --- | --- |
| L0 | `tests/unit/TalonUpdateTest.roc` expect 13: `release_url` for the 5 assets, `setup_entry` (no entry on Linux, macOS and Windows; an entry of kind `prebuilt` and of kind `git` stays), `recorded_text` | R-IS6, R-IS2, R-HF10, R-S2 | red: `todo` |
| L2 | `tests/commands/cases/setup/st5-talon-entry`: 3 runs. 1: no `tools.json`, the entry is written (clock, lock, read, write, unlock), the line is first. 2: again, nothing for the entry. 3: `--json`, no field for the entry | R-IS6, R-S2, R-T4, R-CC1, R-CC6, R-ST12 | red: wrong value (no entry, no line, no calls) |
| L2 | `setup/st6-talon-in-file`: `tools.json` has a tool `foo` and a field `note`. The entry is the last tool, `foo` and `note` stay, the entries `tln`, `roc`, `foo` are made | R-IS6, R-TF2, R-CC6, R-ST15 | red: wrong value |
| L2 | `setup/st7-talon-bad`: the entry is `{"source":"install script"}` (not readable, not missing): exit 19, `tool talon: has no source that tln knows`, only the reads of step 3, no write (Q-B1, R-TF3) | R-IS6, R-TF3 | red: setup goes on and exits 0 |
| L2 | `setup/st1-flow`, `st2-copy-fallback`, `st3-gaps` (given changed) | setup keeps an entry that is there: no new call | green before and after |
| L3 | `tests/scenarios/setup/st1-setup-real` steps 1, 1b, 3: the real `tln` writes the entry with the real sha256 of the file `tln` (the case prints `<sha256>` and compares it), the time `TALON_NOW`, the tool `foo` stays, no temp file; a second run leaves the file as it is (`cmp`) | R-IS6, R-S2, R-T4, R-CC1 | red: wrong value |
| Script | `install/test.sh`, the rows for each shell (dash, bash, busybox sh, as R-IS1 says; busybox skips the fake `uname` rows). Rows: latest release, `--version`, sha256 mismatch, missing release, unknown argument and missing value and `--uninstall`, attestation (3 cases), no sha256 line, temp file and `--version`, repair (2 cases), URLs (3 cases), the question under a terminal (3 cases), `TALON_YES=1`, 5 non-interactive settings, unsupported platform, targets (7 machines) | R-S1, R-S4, R-IS1 to R-IS8, R-HF10, R-NI15, R-EV10 | 52 pass, 3 fail (`TALON_YES=1`, once for each shell) |
| Script | `install/test.sh` with `PWSH`: 3 new rows (attestation good and bad, no sha256 line). They mirror the rows of `install.sh`. They are not run here: no `pwsh` on this machine, so they never failed or passed. They run where `pwsh` exists (the Ubuntu and macOS jobs of `ci.yml`, through the row `install` of the self-test) | R-IS3, R-S1, R-IS7 | not run |
| Selftest | `ci/release`: the real `release.yml` | R-IS1, R-IS2, R-S1, R-HF10, R-SE13 | red: file is missing |
| Selftest | `ciscan release`: the good fixture passes. `ciscan release edits`: 7 edits of it fail (`arm64win`, top-level `contents: write`, no attestation step, `branches` in place of `tags`, `x64mac` on Ubuntu, no `install.ps1`, a guard step that does not `exit 1`) | the scanner is true | green |
| Selftest | `install`: runs `install/test.sh` for each shell of the machine, at the same time (about 2 s), and `pwsh` when it exists | R-IS1 to R-IS8 in the fast set | red: the 3 rows of `TALON_YES=1` |

Fail output (2026-10-25, the red state; the full output is in `.work/logs`):

| Test | Fail text |
| --- | --- |
| L0 `TalonUpdateTest.roc:360` | `Roc application crashed with this message: todo` |
| L2 `setup/st5-talon-entry` | stdout: the line `recorded talon 0.0.0 in $HOME/.local/share/talon/tools.json` is missing. Calls: `clock`, `lock`, `read_files`, `write_atomic`, `unlock` are missing. Tree: `tools.json` is not made |
| L2 `setup/st6-talon-in-file` | the same, and the tree: `tools.json` has no `talon` tool |
| L3 `setup/st1-setup-real` | stdout: the line is missing, `tools.json` is `{"format":1,"tools":{"foo":{}}}`, `the sha256 is not the one of the file tln` |
| `install/test.sh` | `FAIL <shell>: TALON_YES=1 (rc 0)`, with the prompt `Proceed? [Y/n]` in the output |
| Selftest `ci/release` | `FAIL: .github/workflows/release.yml is missing` |

Old tests: all pass (`scripts/test.sh`, 2026-10-25: check, fmt and l1 pass; l0 fails only in `TalonUpdateTest`, l2 only in st5 and st6, l3 only in `st1-setup-real`, selftest only in the 2 rows above).

Revert check (research/slice-052-revert/reference/, private, 17 hand mutations of the code, and 7 edits of the workflow fixture):

| Mutation | Caught by |
| --- | --- |
| `install.sh`: a failed attestation is not fatal | `attestation` (3 shells) |
| `install.sh`: no Rosetta rule | `targets` |
| `install.sh`: `--version` runs after the `mv` | `temp file and --version` |
| `install.sh`: the temp file is outside the bin dir | `temp file and --version`, `attestation` |
| `install.sh`: `tln setup` has no `/dev/tty` | `the question` |
| `install.sh`: the answer is read from stdin | `the question` |
| `install.sh`: the latest URL is an API URL | 7 rows |
| `setup_entry`: an entry that is there is replaced; the URL has no `v`; the Windows asset has no `.exe` | L0 13 (3 of the mutations) |
| `SetupFlow`: the write is not under the lock; the sha256 is empty; the time is 0; the line comes last; the clock is read for an entry that is there | L2 st5, st6 (and st1 for the clock) |
| the release scanner: 7 edits of the good fixture (the 7th: the guard step ends with `exit 0`) | the row `ciscan release edits` |
| `SetupFlow`: an unreadable `talon` entry is taken as missing (setup overwrites it) | L2 `setup/st7-talon-bad` (1 of 7 setup cases fails) |

## 8. Decisions that the design does not fix

The test agent chose these. The human can change them at the review.

| # | Point | Choice | Rejected |
| --- | --- | --- | --- |
| D1 | `TALON_YES=1` for `install.sh` | R-EV10 and R-NI15 name the install scripts (both) and do not limit the variable to `install.ps1`. R-IS4 says "`TALON_YES=1` for `irm \| iex`" because `irm \| iex` has no argument. So `install.sh` reads it too, and it has the effect of `--yes` (no question, `--yes` to `tln setup`). The same as `install.ps1` today. | Only `install.ps1` (then R-EV10 and R-NI15 would name a variable that `install.sh` ignores) |
| D2 | Trigger of the release workflow | The push of a tag `v...`. The tag `v<X.Y.Z>` is the form that `TalonUpdate.releases` accepts | `release: published` (the release would exist before its assets, and `latest/download` would 404); `workflow_dispatch` (no tag) |
| D3 | Systems of the build | Ubuntu for the 2 musl targets, macOS for the 2 mac targets (`macos-latest`, Apple silicon, also for `x64mac`: not tested here, risk R1), Windows for `x64win` | One Ubuntu job for all 5 (the Linux linker cannot link mac and Windows: section 6) |
| D4 | Two jobs: `build` has no write rights, `publish` has all of them | The jobs of the build never see a write token | One job (a build step could write the release) |
| D5 | The scripts are tested before they are released | `publish` runs `install/test.sh dash bash` | No test in the release |
| D6 | The attestation | `actions/attest-build-provenance` over the 5 binaries, in `publish` (the file that `gh attestation verify` of `install.sh` checks) | An attestation of `sha256sums.txt` only; of the scripts |
| D7 | The install scripts are in the release as they are in the tag | `gh release create ... install/install.sh install/install.ps1` | A copy with a version inside |
| D8 | The attestation of `tln tool update talon` (050 Q-A1) | Not in this slice. `install.sh` already checks it (R-IS3), and the release workflow now makes it. A later slice can read it (`PLAN-P1.md` 5b row) | Added here |
| D9 | The entry that `tln setup` writes | The `prebuilt` form of 050 Q-S1, with the URL `release_url(Help.version, asset)`. An entry of any readable form stays | A `script` kind; reading `TALON_REPO` |
| D10 | The order in `tln setup` | The entry is written first in step 10, after the prompts (R-CC3 point 5: no `ask!` under a lock), and before the bin dir entries. The clock is read only when the entry is missing | After the entries; the clock for each run |
| D11 | A machine that `BuildSkip.target` does not know (`Other`) | No entry, no error. (`install.sh` stops for such a machine, so only a hand-built `tln` gets here.) Not tested | An error of kind `Environment` |
| D12 | The tests of `install.sh` run on the machine of the user as Linux x86-64 | `uname` is a fake on the path of each run, so macOS gives the same result (the `selftest` row runs on the macOS job) | The real `uname` |
| D13 | `scripts/rules.sh` reads `install/` | `install/test.sh` is the test of R-IS (TESTING.md 7.4) | A copy of the file in `tests/` |

## 9. Out of scope

| Rule or part | Reason |
| --- | --- |
| R-IS1: PowerShell 5.1 | The self-test has `pwsh` 7 at most (and no machine here has it). The Windows job of `ci.yml` runs `check fmt l0`. A Windows run of `install.ps1` is the first real run of the release |
| R-IS7: `install.ps1` under `irm \| iex` throws and does not exit | Needs `pwsh` and an `iex` run of the file. No row |
| R-NI15 for `install.ps1`: the question and `-Yes` | `Read-Host` and `[Console]::IsInputRedirected` need a terminal in `pwsh`. No pseudo terminal tool for it |
| R-S1 and R-SE13: the attestation of `tln tool update talon` | D8 (050 Q-A1) |
| R-S3, R-ST9, R-ST10, R-RM5 on Windows | Slices 050c and 050d. The Windows CI job |
| The real release (a tag, `gh release create`, the attestation service, the macOS and Windows links) | The user's rule: no workflow run, no release, no tag. The first real run is the test of D3 and of the whole file |
| That a run of the guard step stops a wrong tag | The step is read, not run (no workflow runs here). The first tag shows it |

## 10. Questions: answers of the manager (review, 2026-10-25)

| # | Question | Answer |
| --- | --- | --- |
| Q-V | The source of the version of `tln --version` | `Help.version` stays a constant in the source. A release is a commit that sets it, then a tag. `release.yml` has a guard step that fails when the tag is not `v` + `Help.version`. Tested: `ciscan release` (the guard step) and the edit row. The expected files keep `0.0.0` until a release sets the constant |
| Q-R1 | A stale entry after an R-S4 repair | The design text as written: setup writes the entry only when it is missing, so it keeps an existing one. Design gap G1 |
| Q-B1 | An unreadable `talon` entry | Exit 19 (kind `input`, R-TF3). Tested: L2 `setup/st7-talon-bad` |
| Q-X1 | The exit code when `tln setup` fails | The code of `tln setup` goes through (both scripts). Design gap G2 |

## 10b. Design gaps (for the next edit of the design files)

| # | Gap | Source |
| --- | --- | --- |
| G1 | R-IS6 "when it is missing": after `install.sh --version <older>` (R-S4 repair) or an install of another version, the entry keeps the old version and sha256, so `tln tool update talon` reads a wrong installed version (050 Q-D1). The design says nothing of a refresh | Q-R1 |
| G2 | R-IS7 "1 for the rest" does not say what the script exits with when its child `tln setup` fails: both scripts pass the code of `tln setup` through | Q-X1 |
| G3 | R-IS6 gives no form for the source of the entry (`source: install script`). 050 Q-S1 chose `prebuilt` with `version` and `url`. The URL always names the release page of Talon, not the mirror (`TALON_DOWNLOAD_BASE`) or `TALON_REPO` of the script | R-IS6, 050 Q-S1 |
| G4 | R-EV10 and R-NI15 name `TALON_YES` for both scripts, R-IS4 only "for `irm \| iex`". Read as: both scripts (D1) | R-EV10, R-IS4 |
| G5 | The design has no release workflow: trigger, systems, jobs, assets, attestation. Section 6 is the proposal | R-S1, R-IS1, R-IS2 |
| G6 | `Help.version` has no design source before Q-V (slice 001 Q12). Now: a constant that a release commit sets | Q-V |
| G7 | R-IS1 says PowerShell 5.1 and later. No test runs it (only `pwsh` 7, and not on a machine with no `pwsh`) | R-IS1 |
| G8 | A machine that `BuildSkip.target` does not know (`Other`) gets no entry from `tln setup` and no error (D11) | R-IS6 |
| G9 | The attestation of `tln tool update talon` (050 Q-A1) | R-S1, R-SE13 |

Risks of the first real run (no test can show them): R1 `macos-latest` links `x64mac` from Apple silicon (the SDK is the same, but it is not tested); R2 `roc build --target=x64win` needs the MSVC libraries on `windows-latest`; R3 the Linux arm64 binary has no run test (the Ubuntu runner is x86-64, so no `--version` check of `tln-arm64musl`); R4 `install/test.sh dash bash` on the runner needs `python3` (it has it) and a `pty`; R5 the pattern `v[0-9]+.[0-9]+.[0-9]+` is a GitHub filter pattern: check it on the first tag; R6 `gh release create` makes the release in one step, so `latest/download` never sees a release with no assets (a draft is not made, so a failed upload leaves a release with fewer assets: delete it and push the tag again).

## 11. Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## 12. Verify results

`scripts/test.sh` exits 0 (2026-10-25): check, fmt, l0 (all files pass), l2 169 passed, l3 83 passed 1 skipped, selftest 72 passed, l1 pass.

Code written: `TalonUpdate.release_url`, `setup_entry`, `recorded_text`; `SetupFlow` (`record_talon!`, `put_talon!`, field `source_sha` of `Row`, fields `talon` and `target` of `Facts`, `flow!` gives `{ done, lead }`); `install/install.sh` (`TALON_YES=1`); `.github/workflows/release.yml` (the fixture with the guard step). Files are in `research/slice-052-revert/code-final/`.

Revert check (11 mutations, filtered runs, each code file put back and compared with `cmp`):

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | `setup_entry`: an entry that is there is replaced | L0 `l0-1` (TalonUpdateTest 13) |
| 2 | `release_url`: no `v` before the version | L0 `l0-1` |
| 3 | `SetupFlow`: the write of the entry is not under the lock | L2 `setup/st5-talon-entry` (calls) |
| 4 | `SetupFlow`: the `sha256` of the entry is empty | L2 `setup/st5-talon-entry` (tree) |
| 5 | `SetupFlow`: the line `recorded talon` comes after the other lines | L2 `setup/st5-talon-entry` (stdout) |
| 6 | `SetupFlow`: an unreadable `talon` entry is taken as missing | L2 `setup/st7-talon-bad` |
| 7 | `SetupFlow`: the clock is read when the entry is there | L2 `setup/st1-flow`, `st5-talon-entry` |
| 8 | `install.sh`: `TALON_YES=1` does not add `--yes` for `tln setup` | `install/test.sh dash` (row `TALON_YES=1`) |
| 9 | `release.yml`: the guard step ends with `exit 0` | selftest `ci/release` |
| 10 | `release.yml`: `x64mac` on `ubuntu-latest` | selftest `ci/release` |
| 11 | `release.yml`: the attestation `subject-path` is `sha256sums.txt` | selftest `ci/release` |

Caught 11 of 11. Not testable here (fake `Fx`): that the second read of `tools.json` in the lock changes the decision (a race: the file changes between the two reads).

## Notes for the code agent

| Part | What to do | Do not |
| --- | --- | --- |
| C | `TalonUpdate.release_url`, `setup_entry`, `recorded_text`. In `SetupFlow`: read `ToolsJson.talon` from the text of step 3 (a failure is exit 19, `setup/st7-talon-bad`), keep the `sha256` of the source of the `tln` row, write the entry first in step 10 (section 4), print the line first. Update the table of the doc comment | Add a call for an entry that is there. Add a field to `data` |
| B | `install.sh`: `TALON_YES=1` is the same as `--yes` (set `YES=1` and add `--yes` to `SETUP_ARGS`, as the flag does) | Change `install.ps1` |
| A | `.github/workflows/release.yml` (section 6), with the guard step of Q-V. Start from `tests/fixtures/ci/release-good.yml`. `scripts/test.sh selftest` must pass | Run or trigger it. Push a tag. Edit a test. |
| all | `scripts/test.sh` passes. `install/test.sh` passes with `PWSH` when you have it | |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-052-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.7, fmt 0.2, l0 7.7, l2 9.0, l3 10.0, selftest 3.3, l1 36.8 s |
| Code pass | 11 of 11 mutations caught |
| Gap tests | None: no mutation was missed. The second read of `tools.json` in the lock is a race that no fake `Fx` test can show. |
| `release.yml` | Read by the manager: trigger is a tag push `v<X.Y.Z>` only; `contents: read` at the top, write rights only in `publish`. Never run. No tag, release or push was made. |
| Output proposal (TW24) | A setup run that only records the entry prints `recorded talon ...`, then `nothing to do: ...`. Kept; for the human review of output text. |
| Design gaps | Section 10b (G1 to G9), recorded in PLAN-P1 5b. First-run risks R1 to R6 (macOS link of x64mac, MSVC on Windows, arm64musl never run, the tag filter). |
