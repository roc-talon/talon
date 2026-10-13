# compat-sweep

Runs `roc check` on every cached package against each nightly in `tags.txt`. Results go to `results.tsv` (nightly, hash, result, first error).

```sh
./run.sh          # downloads nightlies to bin/, copies ~/.cache/roc/packages to xdg/
```

Classes: `pass`, `fail`, `timeout` (hang), `other` (crash). Run 2026-10-13 on Linux x86_64. All 6 timeouts and 4 crashes were confirmed by a serial re-run with a 30 s timeout (hang) and exit code 139 (segfault). `labels.tsv` maps hashes to release labels where known.

Note: the run used a 300 s timeout per check. Use 30 s. A normal check takes under 2 s.
