# roc unbundle as the package extractor

Question: can Talon extract a package `.tar.zst` with no `zstd` tool and no hosted function in the platform?

`roc unbundle <hash>.tar.zst` exists in the compiler (`roc:src/cli/cli_args.zig:845`, `roc:src/cli/main.zig:8164`). It extracts into `./<hash>/` in the current directory, and checks the hash of the file name, the paths and the size limits (`roc:src/unbundle/`).

Run: `./run.sh <roc binary> <hash in ~/.cache/roc/packages>`

Result on 2026-10-15, `nightly-2026-10-09-258ab27`, Linux x86_64, basic-cli `CZsY7tYZ...` (21 MB packed, 70 MB unpacked):

| Case | Result |
| --- | --- |
| Good archive | Exit 0. The files are the same as in the roc cache. 1235 ms (`zstd -dc \| tar x`: 100 ms) |
| Corrupted archive (1 byte added) | Exit 1, `InvalidTarHeader`. The output dir stays, partly written. |
| Archive under another hash name | Exit 1, `Hash mismatch` |
| Output dir exists | Exit 1, `Directory ... already exists` |

So Talon can run `roc unbundle` in a temp dir and then `rename` the dir into `packages/`. A failure leaves only the temp dir.
