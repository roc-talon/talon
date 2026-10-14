# test-fs: is tmpfs faster for Talon tests?

Question: does an in-memory file system (tmpfs) make Talon tests faster than ext4?

| File | Content |
| --- | --- |
| `Semver.roc` | Small type module with 4 `expect`s |
| `app.roc` | basic-cli 0.29.0 app (passes on the 10-09 nightly, `conformance/compat-sweep`) |
| `run.sh` | Runs each case N times (default 5) in `.work/` (ext4) and in `/dev/shm` (tmpfs), prints the median ms |

Run: `./run.sh [ROC] [N]`. The default `ROC` is the 10-09 nightly in `cloudflare-workers/.cache/nightlies/`.

## Result (2026-10-15)

Machine: 24 cores, 91 GB RAM, home on ext4. Nightly `nightly-2026-10-09-258ab27`. Median of 5 runs, 2 passes.

| Case | What it does | ext4 ms | tmpfs ms |
| --- | --- | --- | --- |
| `cold_test` | `roc test` on `Semver.roc`, empty cache | 24 to 25 | 23 to 25 |
| `warm_test` | Same, warm cache | 15 to 16 | 16 to 17 |
| `cold_check` | `roc check` on `app.roc`, empty build cache, package in the cache | 145 to 160 | 130 to 168 |
| `check_app` | Same, warm build cache | 27 to 28 | 24 to 32 |
| `store` | Copy a 13 MB package (51 files), tar, delete, untar, delete | 32 to 38 | 28 to 31 |
| `fsync200` | 200 atomic writes (write 4 KB, `fsync`, `rename`) in one process | 425 to 431 | 23 to 25 |

Process start costs (same machine):

| Isolation | Start ms |
| --- | --- |
| Fresh directory and environment variables | about 0 |
| `bwrap` with tmpfs `HOME` and `/tmp`, no network | 35 |
| `docker run --rm --network none --tmpfs /work` (alpine) | 260 to 440 |

## Conclusion

- tmpfs is faster only for `fsync`: 18x. The page cache makes all other reads and writes equal.
- The design does not say `fsync` today. The store, the self update and the tool install write a temp file, then `rename` (CLI 7.1, S3, IS5, B4). If Talon adds `fsync` to these for crash safety, their tests gain from tmpfs. Else the gain is small.
- `roc` time is CPU time. tmpfs does not change it. Fewer `roc` runs (a fake `roc`, a warm cache) is what makes tests fast.
- On this machine `/tmp` is already tmpfs. A container is for isolation and the same tools on each machine, not for speed. Start one container per test run, not per test.
