# Revert check of the code, slice 023 (35 mutations, see code-mutate.py)

Rule: a mutation is CAUGHT when a listed test fails. Only the tests that should catch it were run (no full sweep). The script put all files back from `code-final/` before each mutation and compared them at the end: SAME as code-final (`run.log` for all, `run2.log` for the 4 mutations that first did not compile: P4, G2, G9, I1).

Result: caught 32 of 35. Not caught: P6, P7, G16 (test gaps, the test agent decides, TW18).

| Not caught | Why |
| --- | --- |
| P6 (`is_source_file`: a URL that ends in `.roc` is a file) | The row of `target` for a URL has `.roc` inside but not at the end. A row `run https://example.com/x/app.roc` (NoFile) would catch it. |
| P7 (`is_source_file`: an option that ends in `.roc` is a file) | The row of `target` for an option has `.roc.d` at the end. A row `check --main=app.roc` (Main) would catch it. |
| G16 (`find!`: `TALON_PROXY=0` with `roc +<id>` or `ROC_TOOLCHAIN` still searches the project) | No L2 run has `TALON_PROXY=0` together with rank 1 or 2. A run `@roc +<id> check p3/main.roc env:TALON_PROXY=0` (no `canonical` call) would catch it. |

The other 32 are in `run.log` and `run2.log`.
