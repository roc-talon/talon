# 018b CI jobs

Phase: P1. Status: done

This slice adds the CI workflows and the small changes in the scripts that the workflows need. No Talon code changes. Source: `docs/slices/PLAN-P1.md` row 018b and "Answers of the user" (2): CI in P1 with Linux, macOS and Windows jobs that run the fast set, and a nightly job with `OPT=speed`, `SLOW=1` and the tag `net`. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copy of the changed file is in `research/slice-018b-revert/before/` (with `NEW.txt`).

The repository has no git remote and `actionlint` is not installed, so no workflow can run here. So the tests are static: 6 rows of `tests/selftest.sh` read the workflow files and the scripts. The first real run of the jobs is the real test. The slice file says which parts can fail there (section "Risks of the first run").

## Rules

No design rule (R-xx) is in this slice. TW20, TW25, TW27 apply. One new rule, TW28, and one new tag, `net`, go into `TESTING.md` (section "TESTING.md text").

## What changes

| # | Before | After | Rule |
| --- | --- | --- | --- |
| 1 | No `.github/` | `.github/workflows/ci.yml` (fast set, 3 systems) and `.github/workflows/nightly.yml` (merge run and nightly run, Linux). Shape: next section | TW28 |
| 2 | `scripts/env.sh` has the nightly tag inside the path of `ROC` | `ROC_TAG=${ROC_TAG:-nightly-2026-10-14-38a3029}` before the `ROC` line. `ROC` uses `$ROC_TAG`. This is the one place of the tag (the workflows and `get-roc.sh` read it) | TW28 |
| 3 | The compiler is in `cloudflare-workers/.cache/` (local) | New `scripts/get-roc.sh`: installs the compiler of `ROC_TAG` and prints its path. CI uses it. A developer can too | TW28 |
| 4 | `scripts/test.sh` uses `bc`. Git Bash on Windows has no `bc` | The 3 `bc` calls are `awk` (same numbers) | TW28 |
| 5 | `scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh` start with `#!/bin/bash`. They use `mapfile` and `declare -A`. `/bin/bash` of macOS is 3.2 | The first line is `#!/usr/bin/env bash` | TW28 |
| 6 | `tests/run.sh` has no tag `net` | The tag `net` is skipped unless `NET=1`. `SLOW=1` and `REAL_ROC=1` do not run it | TW27, TW28 |

## Shape of the workflow files

The files use a small YAML subset, so the test reader (`tests/tools/ciscan.py`) stays simple: block mappings and lists, plain or quoted scalars, one-line `[a, b]` lists, `{}`, and `|` or `>` blocks. No anchor, alias, tag, document marker, tab, multi-line plain scalar or flow mapping with keys. If PyYAML is installed, the test also parses each file with it.

Both files, at the top level: `name`, `on`, `permissions` with `contents: read` only, `jobs`. Each job has `runs-on`, `timeout-minutes` and `steps`. Each `uses:` ends in `@v<N>` or in a 40 digit sha.

### ci.yml (the fast set)

| Item | Required |
| --- | --- |
| `on` | `push` and `pull_request` (`workflow_dispatch` is allowed) |
| Job | One job `fast` with `runs-on: ${{ matrix.os }}`, `timeout-minutes: 30`, `strategy.fail-fast: false` |
| Matrix | `strategy.matrix.include` with 3 entries of `os` and `steps`. See the table below |
| Test step | `run: scripts/test.sh ${{ matrix.steps }}` and `shell: bash` (the default shell on Windows is PowerShell) |
| Variables | None of `OPT`, `SLOW`, `NET`, `REAL_ROC` at any level. This is the fast set (TW20) |
| Order | Tool step, `ROC_TAG` step, binary cache, `scripts/get-roc.sh` step, package cache, test step |

| `os` | `steps` | What runs | Why |
| --- | --- | --- | --- |
| `ubuntu-latest` | empty | The whole fast set: check, fmt, l0, l2, l3, selftest | The reference system |
| `macos-latest` (Apple Silicon) | empty | The whole fast set | Case-insensitive names (`TESTING.md` section 5) |
| `windows-latest` | `check fmt l0` | `roc check`, `roc fmt --check` and the L0 `roc test` files | See decision D3 |

### Tool steps

| Step | `if` | Content |
| --- | --- | --- |
| Linux tools | `runner.os == 'Linux'` | `sudo apt-get install -y bubblewrap` and `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`. Ubuntu 24.04 blocks user namespaces. Then `tests/lib.sh` `netoff` falls back to a run with the network on, and a case that uses the network would pass in CI (TW15) |
| macOS tools | `runner.os == 'macOS'` | `brew install bash coreutils findutils diffutils`. Add `$(brew --prefix)/bin` and the `libexec/gnubin` dirs of coreutils and findutils to `$GITHUB_PATH`, so `date +%s.%N`, `find -printf`, `timeout`, `nproc` and GNU `diff` work. The scripts use these |
| Pinned tag | all | `. scripts/env.sh` and `echo "ROC_TAG=$ROC_TAG" >> "$GITHUB_ENV"` |
| Install roc | all | `echo "ROC=$(scripts/get-roc.sh)" >> "$GITHUB_ENV"`, with `GH_TOKEN: ${{ github.token }}` |

### nightly.yml (the merge run and the nightly run)

| Item | Required |
| --- | --- |
| `on` | `schedule` with a list of `cron: '<5 fields>'`, and `workflow_dispatch`. No `push`, no `pull_request`. `workflow_dispatch` is the merge run by hand (question Q2) |
| Job | One job `nightly`, `runs-on: ubuntu-latest`, `timeout-minutes: 90` |
| Test step | `run: scripts/test.sh` with no argument (all steps). `env`: `OPT: speed`, `SLOW: 1`, `NET: 1`, `REAL_ROC: 1` (`TESTING.md` E1, "Nightly" row), and `GITHUB_TOKEN: ${{ github.token }}` (the `net` cases call `api.github.com`, R-RG3). Both forms are valid: `env:` or the assignments in front of the command |
| Package cache | None. The nightly run downloads the packages again, so a deleted release asset shows (R-FE6) |
| Same as ci.yml | The Linux tools step, the `ROC_TAG` step, the binary cache and the install step |

## Decisions that the design does not fix

The test agent chose these. The human can change them at the review.

| # | Point | Choice | Rejected |
| --- | --- | --- | --- |
| D1 | How CI gets the pinned roc | `scripts/get-roc.sh` downloads the asset of `roc-lang/nightlies` for tag `ROC_TAG` with `gh` (on all runner images; `GH_TOKEN` is the job token). Asset: name starts with `roc_nightly-<target>-` and ends in `.tar.gz` (`.zip` on Windows), with `<target>` `linux_x86_64`, `macos_apple_silicon` or `windows_x86_64` (R-CV2). It checks the sha256 against the `digest` of the asset from the release API (R-CV3). It installs to `$WORK/nightlies/$ROC_TAG/roc` (or `roc.exe`) and prints the path. A found file is not downloaded again | A tag text in each workflow (two copies of the pin). A check-in of the compiler (70 MB). A third-party setup action (no pin, no digest check) |
| D2 | The platform and the packages | No install step. `roc` downloads basic-cli and the packages from the URLs in the app headers into `ROC_CACHE_DIR` (`$WORK/cache/roc`, `scripts/env.sh`). `ci.yml` caches `.work/cache/roc` | A copy of basic-cli in the repository (a second source of the URL) |
| D3 | The Windows job | `scripts/test.sh check fmt l0`. L2, L3 and the selftest are bash with GNU tools (`mapfile`, `find -printf`, `bwrap`, a pty tool, `sh` fakes of `roc`), and the case runner is built for Linux. The Windows rules (R-HF11, R-ST10, R-RM5, R-S3, R-LY5 to R-LY9, `install.ps1`) belong to slices 027, 050 and 052, which extend the Windows steps when their cases exist. Today the tag `windows` is skipped everywhere | A Windows job with all steps (fails for reasons that are not Talon). No Windows job until slice 027 (the user asked for it in P1) |
| D4 | Cache keys | Binary: path `.work/nightlies`, key `roc-${{ runner.os }}-${{ runner.arch }}-${{ env.ROC_TAG }}`, no `restore-keys` (another tag must not restore). Packages (`ci.yml` only): path `.work/cache/roc`, key `roc-pkgs-${{ runner.os }}-<hash of the https URLs of the roc headers>`, where a step makes the hash (for example `grep -rhoE 'https://[^"]+[.]tar[.]zst' --include='*.roc' cli tests packages \| sort -u \| sha256sum`) and gives it as a step output | A key of `hashFiles('**/*.roc')`: a new cache entry for each commit, and the 10 GB limit evicts the useful entries. `restore-keys` for the binary |
| D5 | Systems | Linux x86-64 (`ubuntu-latest`), macOS Apple Silicon (`macos-latest`), Windows x86-64 (`windows-latest`). Not tested: Linux arm64, macOS x86-64 | A bigger matrix (cost, and the nightlies list no asset for Windows arm64, R-CV2) |
| D6 | Budgets in CI | No change. A slow runner gives `WARN` lines and the exit code stays 0 (TW26). The selftest takes 14 to 16 s here with a budget of 15 s (question Q3) | `BUDGET_*` variables in the jobs (hides growth) |
| D7 | Names of the new variable and tag | `NET=1` and the tag `net`, like `SLOW` and `REAL_ROC` | A flag (the scripts have only variables) |
| D8 | `REAL_ROC=1` in the nightly job | Yes, as `TESTING.md` E1 gives for the nightly run (the L4 cases run with the pinned roc) | Not set (L4 never runs in CI) |
| D9 | Action versions | A major tag (`@v4`) or a sha. The test accepts both | Only sha (cannot look up the sha offline) |
| D10 | Upload of the logs | The fast job uploads `.work/logs` with `actions/upload-artifact@v4` and `if: failure()`. Not tested | None |

## Tests

6 rows in `tests/selftest.sh`, section "Slice 018b", and one negative check of the reader. The scanner `tests/tools/ciscan.py` (stdlib only, run with `python3 -I`) is the test code. A row calls it with a check name and the repo root. A row passes when the check prints no `FAIL:` line.

| # | Layer | Row (`tests/selftest.sh`) | What it checks | Rules |
| --- | --- | --- | --- | --- |
| 0 | selftest | `ciscan: a tab and an anchor ...` | The reader rejects a tab, an anchor and a duplicate key (a bad file in a temp dir). This guards the other rows against a reader that accepts all | TW28 |
| 1 | selftest | `ci/yaml` | `ci.yml` and `nightly.yml` exist and parse. Top-level keys, `permissions: contents: read`, each job has `runs-on`, `timeout-minutes`, `steps`. Each `uses:` is pinned | TW28 |
| 2 | selftest | `ci/fast` | Section "ci.yml": triggers, matrix of ubuntu, macos and windows, the arguments (`check fmt l0` for windows only), `shell: bash`, no `OPT`, `SLOW`, `NET`, `REAL_ROC`, the Linux bubblewrap step | TW20, TW25, TW28 |
| 3 | selftest | `ci/nightly` | Section "nightly.yml": schedule and dispatch only, ubuntu, `OPT=speed`, `SLOW=1`, `NET=1`, `REAL_ROC=1`, a token, all steps, no package cache | TW25, TW27, TW28 |
| 4 | selftest | `ci/pin` | `scripts/env.sh` has the one `ROC_TAG` line with `nightly-2026-10-14-38a3029`, and `ROC` uses it. `scripts/get-roc.sh` exists, is executable, uses `env.sh`, names the 3 targets, the repository and the sha256 digest, and has no tag text. The workflows run it before the tests, write `ROC` and `ROC_TAG` to `$GITHUB_ENV`, have no tag text, no `cloudflare-workers` path, cache keys with `runner.os`, a binary key with `env.ROC_TAG`, a package key with a hash | TW28 |
| 5 | selftest | `ci/portable` | Each script with `mapfile`, `readarray` or `declare -A` starts with `#!/usr/bin/env bash`. No `bc` in the scripts. The macOS step installs bash, coreutils, findutils, diffutils and writes `gnubin` and the brew bin to `$GITHUB_PATH` | TW28 |
| 6 | selftest (L3 runner) | `net tag` | 2 L3 cases with the tag `net`: `net/ok` (passes), `net/bad` (fails). Fast set: `0 passed, 0 failed, 2 skipped`. `SLOW=1 REAL_ROC=1`: the same. `NET=1`: `FAIL net/bad`, `1 passed, 1 failed, 0 skipped`, exit 1 | TW27, TW28 |

Other change in `tests/selftest.sh` (not a row): `NET` is unset at the start, with `OPT`, `SLOW` and the other flags, so the nightly flags do not change the old rows.

## Public interface

No Roc code, so no stubs. The old scripts are the stubs: they lack the behavior of the table, so the rows fail.

| Item | Interface |
| --- | --- |
| `ROC_TAG` | Variable in `scripts/env.sh`. A caller can set it. The default is the pinned tag |
| `scripts/get-roc.sh` | No argument. Reads `ROC_TAG`, `WORK` from `scripts/env.sh`. Needs `gh` and `GH_TOKEN`. Prints the absolute path of `roc` (or `roc.exe`) on stdout, and messages on stderr. Exit 1 on an unknown system, a missing asset, or a sha256 mismatch. The first line is `#!/usr/bin/env bash`. The file mode is executable |
| `NET` | Variable. `NET=1` makes `tests/run.sh` run the tag `net`. It passes through the environment of `scripts/test.sh` |
| `tests/tools/ciscan.py` | `python3 -I ciscan.py <yaml\|fast\|nightly\|pin\|portable> <repo root>`. Prints `FAIL: <reason>`. Exit 0 or 1 (2: usage) |

## Files

| File | Change |
| --- | --- |
| `tests/selftest.sh` | Done by the test agent: the rows and the `unset` change |
| `tests/tools/ciscan.py` | New, test agent (the scanner) |
| `.github/workflows/ci.yml`, `.github/workflows/nightly.yml` | New (code agent) |
| `scripts/get-roc.sh` | New (code agent) |
| `scripts/env.sh` | `ROC_TAG` (code agent) |
| `scripts/test.sh` | `bc` to `awk`, the shebang. Header comment is unchanged (code agent) |
| `tests/run.sh` | The shebang, `NET=1`, the header comment (code agent) |
| `tests/commands/run.sh` | The shebang (code agent) |
| `TESTING.md` | The text of the next section (code agent, after the review) |

## TESTING.md text (proposal)

| # | Place | New text |
| --- | --- | --- |
| E1 | Section 7.3, after TW27 | `TW28`: see below |
| E2 | Section 3.1, table "Tag", new row | `net` / `The case needs the real network (GitHub API, real downloads). The cases of this tag cut no network.` / `Skipped. NET=1 runs it (the nightly run only).` |
| E3 | Section 5, row "Case-insensitive names" and row "`rename` of a running `.exe`" | Column "Setup": `CI job on macOS (.github/workflows/ci.yml)`, `CI job on Windows (.github/workflows/ci.yml)`. The Windows job runs `check fmt l0` until a slice adds more |
| E4 | Section 1, table E1 of slice 018, row "Nightly" | The command `OPT=speed SLOW=1 NET=1 REAL_ROC=1 scripts/test.sh` |

```markdown
| TW28 | CI is in `.github/workflows/`. `ci.yml` runs the fast set (`scripts/test.sh`) on Linux, macOS and Windows for each push and pull request. The Windows job runs `check fmt l0` until a slice adds more. `nightly.yml` runs `OPT=speed SLOW=1 NET=1 REAL_ROC=1 scripts/test.sh` each night and on request (the merge run). The nightly tag of the compiler is `ROC_TAG` of `scripts/env.sh` and nowhere else. A workflow gets the compiler with `scripts/get-roc.sh` and never uses a path of `cloudflare-workers/`. A selftest row reads the workflow files (no runner can run them in the test run). |
```

## Risks of the first run

The rows cannot find these. The first run of the jobs shows them. The code agent writes the steps with these in mind, and the human looks at the first run.

| # | Risk | Where |
| --- | --- | --- |
| 1 | The pinned nightly may not run, or `roc test` may differ, on Windows. `.zip` unpack needs `7z` or `unzip` in Git Bash (`7z` is on the runner image) | Windows job |
| 2 | A script may use another tool that macOS lacks after the brew step (for example `readlink -f`, `sed -i`, `stat -c`). The brew list is the known list (`find -printf`, `date %N`, `timeout`, `nproc`, `mapfile`, `declare -A`, GNU `diff`) | macOS job |
| 3 | `ROC_CACHE_DIR` and `XDG_CACHE_HOME` are Git Bash paths (`/d/a/...`) on Windows. MSYS converts them for native programs. `roc` may read them in another way | Windows job |
| 4 | The sysctl for bubblewrap may fail on a new runner image. Then L3 runs with the network on (the script prints no warning) | Linux jobs |
| 5 | The `digest` field of the asset may be missing for an old nightly. Then `get-roc.sh` fails with exit 1 (R-CV4: no asset without sha256) | All jobs |
| 6 | The macOS and Windows jobs are slower. Step budgets only warn (D6) | macOS, Windows |

## Out of scope

| Item | Where |
| --- | --- |
| The release workflow (5 targets, `sha256sums.txt`) | Slice 052 |
| The `net` cases, `--snapshot`, and a `net` case without the `bwrap` network cut (`netoff` in `tests/run.sh` cuts the network of each case) | Slice 053 |
| Windows L2 and L3, the `windows` tag cases | Slices 027, 050, 052 |
| L1 (roc-fuzz) in CI (Linux only, `TESTING.md` 4) | The first L1 target |
| A run of the workflows (no remote, no runner, no `actionlint`) | The first push to GitHub |
| Linux arm64 and macOS x86-64 jobs | None |

## Questions (TW17)

| # | Question | Effect |
| --- | --- | --- |
| Q1 | The macOS and Windows jobs may fail at the first run for reasons of the machine (section "Risks of the first run"). Should they have `continue-on-error: true` until the first green run? | Default: no. A red job is a real fact, and a flag that stays is a hidden failure. The shape check allows the flag only if the human says so. Then the rows must change |
| Q2 | Does CI need a merge run on each pull request (`OPT=speed SLOW=1`, Linux)? `TESTING.md` E1 says "before a merge". The nightly run only (and `workflow_dispatch`) is cheaper | Default: no. The merge run is the nightly workflow started by hand |
| Q3 | The selftest budget (15 s) is over on this machine now (14 to 16 s) and CI runners are slower. Raise it in TW26, or leave the warning? | Default: leave it. A warning does not fail the run. The change is in `TESTING.md` and in `scripts/test.sh` (`BUDGET`) |

## Red output

`research/slice-018b-revert/red-full.txt`: `scripts/test.sh` on the final tree. check, fmt, l0, l2 and l3 pass. The selftest step fails with 6 rows (the 31 older rows and the negative check of the reader pass: 32 passed, 6 failed). The selftest takes 14.1 s (budget 15).

| Row | Why it fails today |
| --- | --- |
| `ci/yaml` | `.github/workflows/ci.yml` and `nightly.yml` are missing |
| `ci/fast` | `ci.yml` is missing |
| `ci/nightly` | `nightly.yml` is missing |
| `ci/pin` | `scripts/env.sh` has no `ROC_TAG`, `scripts/get-roc.sh` and the workflows are missing |
| `ci/portable` | 3 scripts start with `#!/bin/bash`, `scripts/test.sh` uses `bc`, `ci.yml` is missing |
| `net tag` | The tag `net` is unknown: `net/bad` runs in the fast set (`1 passed, 1 failed, 0 skipped` for 3 runs) |

## Revert check

The test agent wrote a private reference of the change: the 2 workflows, `get-roc.sh` (a stub that has the words, not the download), the changed `env.sh` and `test.sh`, the shebangs and the `NET` line of `tests/run.sh`. It is in `research/slice-018b-revert/reference/`. It is a record of the revert check only. The code agent writes the real files from this slice file. The reference was laid over a copy of the repository. In that copy the selftest passes (38 passed, 0 failed), `ciscan.py` agrees with PyYAML on both workflow files, and 47 mutations of the reference (`research/slice-018b-revert/mutate.py`) were each caught by one check (44 by `ciscan.py`, 3 by the `net tag` row). The real tree is the same as `research/slice-018b-revert/before/` except `tests/selftest.sh` and the new `tests/tools/ciscan.py`.

## Disputes (from the code agent)

(none)

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | Do not edit `tests/selftest.sh` or `tests/tools/ciscan.py` (TW18). If a row looks wrong, write a dispute here and stop |
| 2 | Keep the YAML in the subset of section "Shape of the workflow files". Run `python3 -I tests/tools/ciscan.py <check> .` for each of the 5 checks |
| 3 | `scripts/get-roc.sh` must do the download and the digest check. The rows only read it. Test it by hand with `gh` on this machine: `ROC_TAG=<a tag that exists> WORK=<temp dir> scripts/get-roc.sh` |
| 4 | After the `bc` change, run `scripts/test.sh` and compare the budget and `WARN` output with the old output (same numbers). The selftest rows of slice 018 must pass |
| 5 | Check the macOS risk list by reading the scripts for other GNU-only calls. Write each one you find into the macOS tool step |

## Review (manager, 2026-10-22)

D1 to D10, the script changes (`bc` to `awk`, `#!/usr/bin/env bash`), the macOS and Linux setup steps, the `net` tag and the new rule TW28 are accepted. The code agent adds TW28 and the `net` tag text to TESTING.md as the slice file gives it. The private reference of the test agent was deleted by the manager before the code step (TW18).

| # | Answer |
| --- | --- |
| Q1 | No `continue-on-error` (the default): a red first run must show. |
| Q2 | The default: no merge run on each pull request; the nightly workflow started by hand is the merge run. |
| Q3 | Raise the selftest budget to 20 s: the selftest grows with each harness slice (14 to 16 s now). |

The workflows cannot run here: the repo has no git remote. The first real run is after the user pushes.

## Verify results (code agent)

`scripts/test.sh` exits 0 (check, fmt, l0, l2, l3 and selftest pass; selftest 38 passed, 0 failed). Revert check: caught 23 of 24, see `research/slice-018b-revert/code-results.md`. The one mutation that no row catches is the removal of the sha256 comparison in `scripts/get-roc.sh` (G3). The rows read the file only. A hand check with a fake `gh` shows exit 1 on a wrong digest. The real workflows have not run (no remote).

## Review of the code (manager, 2026-10-22)

`scripts/test.sh` passes (manager run). The revert check caught 23 of 24. The decisions are accepted, also the TW26 text "selftest 20" (it follows Q3). `scripts/get-roc.sh` ran once against the real release (digest match, `roc version` is the pinned tag). G3 (the sha256 compare in `get-roc.sh`) has no row: moved to slice 019, a selftest row with a fake `gh` that gives a wrong digest. The workflows have not run: the repo has no remote.
