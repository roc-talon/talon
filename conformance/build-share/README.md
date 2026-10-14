# build-share (Q18)

Question: can 3 `roc build` runs share one compiler cache (`compat-<id>/`) at the same time with no error?

| File | Content |
| --- | --- |
| `apps/` | 3 basic-cli 0.25.0 examples: `command-line-args`, `print`, `url` |
| `run.sh` | Builds the 3 apps at the same time, `N` times (default 100), on one cache |
| `results.tsv` | Last run: one row per iteration |

Run: `./run.sh <roc binary> [N]`. The cache is `xdg/` (ignored by git). The platform comes from `~/.cache/roc/packages`.

Method:

| Step | What |
| --- | --- |
| 1 | References: build each app alone, one at a time. Cold: on an empty cache. Warm: on a cache that holds all 3 apps. |
| 2 | Odd iterations empty the compiler cache first (cold). Even iterations keep it (warm). |
| 3 | Each iteration starts the 3 builds at the same time and waits for all. |
| 4 | Each binary must exist, give the same output as the reference (run from one fixed path, so `argv[0]` is the same), and have the same bytes as the reference of its kind. |

Test of the test: a wrapper around roc that removes one binary and adds a byte to another gives `built` 2 and `same_binary` 1 in each iteration.

## Result (2026-10-14, nightly-2026-10-12-2664a27, 24 threads, Linux x86_64)

| Cache | Iterations | Builds | Built | Same output | Same bytes | Mean wall | Max wall |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Cold | 50 | 150 | 150 | 150 | 150 | 0.97 s | 1.53 s |
| Warm | 50 | 150 | 150 | 150 | 150 | 0.80 s | 1.34 s |

The test ran 2 times with the same result (600 builds). Answer: yes.

Wall time for builds that start at the same time (mean of 3, cold cache):

| Builds | 1 | 3 | 6 | 12 |
| --- | --- | --- | --- | --- |
| Wall | 0.74 s | 1.03 s | 1.22 s | 1.59 s |

Each build uses about 250 MB of memory.

## Found on the way: a warm build gives other bytes

A build on a warm cache gives a binary with other bytes (and another size) than a build on an empty cache. Both give the same output. Two warm builds give the same bytes. So the sha256 of a binary is not a function of the build id.
