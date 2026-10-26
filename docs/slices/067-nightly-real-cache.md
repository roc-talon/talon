# 067 Nightly real cache

Phase: P1. Status: done

Slice 067 is the follow-up of slice 053 Q2 (row 067 of `PLAN-P1.md`, and the row "The nightly runner has no real roc cache"). The GitHub runner of `nightly.yml` has no `~/.cache/roc`, so the L4 case `exit/ex2-gc-real-cache` is skipped there. This slice adds a script that builds a real roc cache, and one step in `nightly.yml` that calls it and sets `REAL_CACHE`. No Talon code and no test file changes. The pre-slice copy of the changed file is in `research/slice-067-revert/before/` (with `NEW.txt`).

## Rules

None (TW16 only: the case exists since slice 053).

## Scope

| Item | Decision |
| --- | --- |
| What `ex2` needs | 4 or more legacy dirs (`nightly-*`, `debug-*`), 4 or more `compat-*` dirs, 4 or more `packages/<hash>` dirs. A cache with fewer fails the case (exit 3). A missing cache dir skips it (`needs-real-cache`) |
| How `ex2` finds the cache | `tests/run.sh` gives `TALON_TEST_REAL_CACHE=${REAL_CACHE:-$HOME/.cache/roc}` to a case with the tag `real-roc`. The case copies the dir. `REAL_CACHE` is the roc cache dir itself |
| Legacy dirs | The 4 newest nightlies before 2026-10-05 write `nightly-<tag>`. Each one runs `roc check` of one app |
| Compat dirs | Each nightly from 2026-10-11 on writes its own `compat-<id>`. The 4 oldest of them run the same `roc check` |
| Packages | The app uses basic-cli 0.24.0 and roc-parser 2.0.0 (as case `ex1`). The cache gets 4 packages: the platform, the parser, and 2 dependencies |
| Tags | From the release list of `roc-lang/nightlies` (no tag in the script, no tag in the YAML). `scripts/get-roc.sh` installs each compiler (sha256 check, R-CV3) into a temp dir that the script deletes |
| Safety | The script runs each compiler with `XDG_CACHE_HOME=ROOT` and `ROC_CACHE_DIR=ROOT/roc`. ROOT must be absolute, with no `.` or `..`, empty or new, and not `~/.cache` or `~/.cache/roc` |
| Output | The cache dir on stdout (`ROOT/roc`), messages on stderr. Exit 1 if a download fails or a kind has fewer than 4 dirs |

## Files

| File | Change |
| --- | --- |
| `scripts/real-cache.sh` | New. Usage: `REAL_CACHE=$(scripts/real-cache.sh [ROOT])`, default ROOT is `$WORK/real-cache`. A human can run it too |
| `.github/workflows/nightly.yml` | New step `Real roc cache` before `Test`: `cache=$(scripts/real-cache.sh)`, then `REAL_CACHE=$cache` into `$GITHUB_ENV`. It has `GH_TOKEN`. No new action. The permissions stay `contents: read` |

## Tests

No new test (the script needs the network, and the workflow cannot run here). The static check of the workflow is `tests/tools/ciscan.py` (rows `ci/yaml`, `ci/nightly`, `ci/pin`, `ci/fast`, `ci/portable` of the self-test). The real test is the first nightly run.

## Verify results

| Check | Result |
| --- | --- |
| `ciscan.py yaml`, `nightly`, `pin`, `fast`, `portable` | All pass (no literal tag in the workflow or the script, `contents: read`) |
| `bash -n scripts/real-cache.sh`; bad ROOT (relative, `..`, `~/.cache/roc`, not empty) | Each one exits 1 with a clear text. `shellcheck` is not installed |
| `scripts/real-cache.sh research/slice-067-revert/rc/root` (2026-10-25, network, 39 s) | Exit 0. Nightlies 10-01, 10-02, 10-03, 10-04: `roc check` exit 0. Nightlies 10-11, 10-12, 10-13, 10-14: exit 1 (basic-cli 0.24.0 does not type check there, the cache is made anyway). Cache: 4 legacy dirs, 4 compat dirs, 4 packages, 253 MB. The temp dir is deleted |
| `OPT=speed NET=1 REAL_ROC=1 REAL_CACHE=<that cache> tests/run.sh exit/ex2` (4.6 min with the build of `tln`) | `scenarios: 1 passed, 0 failed, 0 skipped`. The case ran on the new cache (no skip). The cache of the run is deleted. `~/.cache/roc` was not used or changed |

## Out of scope

| Item | Reason |
| --- | --- |
| A self-test row for `real-cache.sh` | A test file. The script needs the network. A later test slice can add a fake `gh` row (as `get-roc.sh`, slice 019) |
| A cache of `.work/real-cache` between runs | The packages are downloaded again each time (R-FE6). The build takes under 1 minute |

## Open points

| Id | Point | Suggested step |
| --- | --- | --- |
| P1 | The plan says "legacy dirs exist before 2026-10-05". The real cut is later: nightlies 10-06 and 10-09 still write `nightly-*` (seen locally), and 10-11 is the first that writes `compat-*`. The script uses the plan date for legacy and 2026-10-11 for compat, so the 2 kinds do not overlap | Manager: change the date in the docs, or leave it |
| P2 | A compat dir needs a new nightly each. If the release list drops old nightlies, the script fails with `fewer than 4 nightlies` (it does not skip). The fail is visible in the nightly run | Accept, or store 4 compiler tags in `env.sh` |
| P3 | The 4 packages are the minimum that `ex2` accepts. A second app with more libraries gives a margin | Add if a package download is flaky |
| P4 | Nothing ran on GitHub. The step uses the same `GH_TOKEN` and `gh` as `get-roc.sh`. The runner has `gh` and Linux `bash` 5 | The first nightly run is the test |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-067-revert/code-final.sha256` | 3 files OK |
| Local run | `scripts/real-cache.sh` into a research dir (39 s), then `exit/ex2-gc-real-cache` passed with no skip |
| GitHub | Not run (no workflow run without the user's OK). The first nightly run is the real check. |
| P1 (cutoff date) | The real change is between 2026-10-09 (last `nightly-*` dir) and 2026-10-11 (first `compat-*` dir), not 2026-10-05. The script uses both dates, so it works. A 5b row records it. |
| P2, P3 | Accepted as they are: a fail when old releases go away is a clear signal. |
