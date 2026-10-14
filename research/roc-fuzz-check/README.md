# roc-fuzz-check: can Talon use roc-fuzz?

Question: does [roc-fuzz](https://github.com/lukewilliamboswell/roc-fuzz) 0.4.3 build on Talon's pinned nightly, and does it find a bug in a Talon-style module?

| File | Content |
| --- | --- |
| `Semver.roc` | Small semver module with `parse` and `to_str`. One line, `PLANTED`, is a bug when it is not a comment. |
| `main.roc` | Fuzz target: for 3 random `U64`, `parse(to_str(v))` gives `v` back |
| `run.sh` | Builds the target twice (correct, planted), runs 200,000 inputs with seed 1 |

Run: `./run.sh [ROC]`. The default `ROC` is the 10-09 nightly in `cloudflare-workers/.cache/nightlies/`. It needs the network once, for the platform.

## Result (2026-10-15, `nightly-2026-10-09-258ab27`)

| Build | Exit | Time | Saved failures |
| --- | --- | --- | --- |
| correct | 0 | 854 ms for 200,000 inputs | 0 |
| planted | 77 | 39 ms | 1 (`patch` 5329407, over the planted limit) |

| Check | Result |
| --- | --- |
| Build on the pinned nightly | Passes. The examples pin `nightly-2026-09-29`, so the examples warn "roc version mismatch". `main.roc` here has no `roc:` pin. |
| Local module import | Works (`import Semver`) |
| `show`, `replay` of the saved failure | Work. `replay` exits 77. |
| `minimize` | Ran the full 600 s (the default limit), exit 0. The value did not get smaller. It minimizes the raw input bytes, not the typed value, so a small typed value is not certain. Give it a time limit. |
| Build time | 8 s the first time (platform download), about 0.7 s after a source change |
| `..` in `XDG_CACHE_HOME` | `roc build` stops with `PathOutsideWorkspace`. Same roc bug as `conformance/check-scope`. `run.sh` uses a path with no `..`. |

Conclusion: L1 of `TESTING.md` can use roc-fuzz on this nightly.
