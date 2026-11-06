# roc bump (slice 222, G-C156 to G-C159)

What `roc bump` does in the real compilers. Run `research/roc-bump/run.sh [ROC]`: it builds the fixtures in a temp dir, starts a local HTTP server for the bundle, and writes `results.txt` (the exact exit code, time, stdout and stderr of 18 runs). `results-worker-nightly.txt` is the same run with `nightly-2026-10-31-f7bef6b` (`ROC_TAG_WORKER`). The default is `ROC_TAG` `nightly-2026-10-14-38a3029`.

## Facts (all read from the two result files, and from runs on `nightly-2026-10-09`, `-10-12`, `-10-15`)

| Fact | Evidence |
| --- | --- |
| `roc bump` exists in every nightly from 2026-10-09 on. Form: `roc bump --old <OLD> [--old-version X.Y.Z] [--expect X.Y.Z] [ROC_FILE]`. `ROC_FILE` is the main file of the NEW package (default `main.roc` of the working directory). `OLD` is a URL, a `.tar.zst`, a directory or a main file | `roc bump --help` |
| Exit codes: only 0 and 1. 0 is a pass (also with no `--expect`). Every failure is 1, so the exit code cannot tell the causes apart | `results.txt` |
| A pass with `--expect`: stdout ends with `<expect> satisfies the required <LEVEL> bump.`. A bump larger than needed also passes (`--expect 3.0.0` for a major change) | runs 2, 5 |
| Less than needed: exit 1, stderr headline `── ✗ insufficient version bump ──`, then `This is a <LEVEL> change, so the next version must be at least <V>, but --expect was <E>.`. `<LEVEL>` is `PATCH`, `MINOR` or `MAJOR`. The stdout of that run still has the comparison: a line `This is a <LEVEL> change.` and a line `<old> -> <next>` (the wanted version) | runs 3, 4 |
| The nightly of 2026-10-31 wraps that sentence in the middle (`... at least 1.1.0, but` newline `--expect was 1.0.1.`). The stdout is the same byte for byte in all 5 nightlies. So a reader must join the white space, or read the stdout lines | `results-worker-nightly.txt` run 3 |
| `--expect` not above the old version: exit 1, headline `insufficient version bump`, text `The expected version <E> does not move forward from <old>.` (no "must be at least"). stdout has the comparison | run 6 |
| A package that does not compile (new or old, also a missing file): exit 1, the compiler errors, then headline `── ✗ package does not compile ──` and `The new package (<path>) does not compile with this compiler.` or `The old package ...`. stdout is empty | runs 7, 8, 12 |
| No old version: exit 1, headline `missing old version`. `--old-version` is needed unless `--old` is a URL with a version path segment: then it is read from the URL (run 13 shows `(old, 1.0.0)`) | runs 9, 13 |
| A version with a pre-release (`1.0.0-rc.1`) is refused for `--old-version` and `--expect`: headline `invalid old version` and `invalid expected version`. Only `MAJOR.MINOR.PATCH` is read | runs 10, 11 |
| Old URL that does not answer or is not a hash URL (a 404, a closed port): exit 1, headline `download failed`, `Error: InvalidHash.` (the hash in the URL is checked first) | runs 15, 16 |
| No `--old`: exit 1, stderr `Error: no value was supplied for --old` (no headline) | run 17 |
| Time: 10 to 35 ms for local packages and for a bundle from a local server. A package with one dependency and an empty cache (`ROC_CACHE_DIR` new): 982 ms, then 27 ms from the cache. The time of a real run is the download of the old bundle and of each dependency | `results.txt`, one run with `packages/resolve` |
| `roc bump` does not run the new package. An app as the new file fails with `package download failed` for its platform and then `package does not compile`: the check is for a package | one run (not in `run.sh`) |

## What this means for R-PU39

| R-PU39 text | Real |
| --- | --- |
| `roc bump --old <URL> --expect <version>` | Works. The 5 words are not enough: the new package is the file `ROC_FILE` of the working directory (`main.roc`), so a call must name it or run in its directory (Q2) |
| "When roc says that the label bumps less than the API change needs" | Exit 1 and the headline `insufficient version bump` with `must be at least` (exit 1 alone is not enough: every failure is 1) |
| "the bump that roc wants" | `<LEVEL>` and `<old> -> <next>` in the stdout (stable in 5 nightlies); the stderr sentence wraps in the newest one |
| "a `roc bump` that fails for another reason (the old version does not compile with this compiler)" | Matches `package does not compile`; also `download failed`, `missing old version`, a bad `--expect` |
| "the compiler of the `roc:` pin of the release header" | Needed: both packages must compile with the one compiler that runs. A different compiler gives `package does not compile` |
