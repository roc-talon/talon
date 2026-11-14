# Slice 245 mutation check (TW12, R-R14 the `--git` operand)

Script: `research/slice-245-revert/mutate.sh [mutant names]`. Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-245-mut/`, deleted at the end; the working tree is not changed). Compiler: `$ROC` of `scripts/env.sh` (ROC_TAG nightly-2026-10-14-38a3029), not the worker pin. Each test run is capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one mutant at a time. L2 binary built with `--opt=dev`. Tests per mutant: the l0-3 driver (GitTest) and `tests/commands/run.sh roc/gi channels/ch08`. Baseline: l0-3 131 passed, L2 12 passed. No cap hit, no mutant looped.

Result: 10 mutants, 10 caught, 0 gaps in the sense of "not caught". Two are caught at one layer only (m6, m8).

| # | Mutant (place) | Behavior | Caught by |
| --- | --- | --- | --- |
| m1 | `git_source`: drop `parsed.form != Full` | M1 | L0 (2 failed), L2 gi4-operand |
| m2 | `ref_of`: no selector gives the ref `main` | M2 | L0 (2), L2 gi4-operand |
| m3 | `sha_source`: a bare hex word is read as `@<word>` | M3 | L0 (1), L2 gi4-operand |
| m4a | `Selector.is_sha`: `>= 6` | M4 | L0 (1), L2 gi5-short-hex |
| m4b | `Selector.is_sha`: `> 7` | M4 | L0 (14), L2 gi4-operand |
| m5 | `read`: the `many` arm takes the first operand | M5 | L0 (2), L2 gi4-operand |
| m6 | `sha_source`: a bad selector is `NotGit`, not a usage failure (gi5 fix reverted) | M6 | L2 gi5-short-hex only. L0 passes |
| m7a | `git_source`: a nightly tag with no `@` gets the has-no-ref text | M7 | L0 (1), L2 gi4-operand |
| m7b | `git_source`: every no-ref name gets the nightly text | M7 | L0 (2), L2 gi4-operand |
| m8 | `sha_source`: the short-hex stop applies to a channel name with no `/` | extra | L2 channels/ch08-bad-selector only. L0 passes |

Note: for m8 the l0-3 run says "All (131) tests passed" with exit 2 (the compiler warns about the constant condition). It is not a test result.

## Weak spots (caught at L2 only; not a gap in the sense of no catch)

| # | Mutant | Suggested L0 row |
| --- | --- | --- |
| W1 | m6 | `GitRef.read({ args: roc install @deadbe, bare_sha: True })` expects `Err(Usage)` (the `Ref.parse` text, R-SL12); also `Karakatiza666/roc@deadbe`. |
| W2 | m8 | `GitRef.read` with `bare_sha: True` and a channel name with an unknown selector, for example `mychan@deadbe` or `mychan@x`: expects `Ok(Err(NotGit))` (R-CH8, `RocInstall` words that failure). |
