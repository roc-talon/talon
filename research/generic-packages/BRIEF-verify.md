# Brief: verify one generic package

You are the verify agent for one generic Roc package (TESTING.md 7.1, step 4). You are not the test agent and not the code agent. You change no test and no code permanently.

## Steps

| # | Step | Pass when |
| --- | --- | --- |
| 1 | Run `scripts/test.sh $ROC` from a clean work dir (`rm -rf .work`) | Exit 0. Record the counts per test file and the runs per fuzz target. |
| 2 | Run `roc check package/main.roc` and read its output | 0 errors and 0 warnings |
| 3 | Run `mkdir -p dist && roc bundle package/main.roc --output-dir dist` | One `<hash>.tar.zst`. Record the hash and the file list (`tar --zstd -tf`). The list has only package files. |
| 4 | Revert check: for each rule id or settled answer in the slice file, plant one small bug in `package/` that breaks only that rule (change a constant, a compare, an order, remove a branch). Run the L0 test file for that rule, and for an L1 rule the fuzz target. Then restore the file exactly (`git diff --quiet` or keep a copy and `cmp`). | For each mutation, at least one test fails. A mutation that no test catches is a gap. |
| 5 | Check that the public API names no Talon concept (R-GP1): grep `package/` for `talon`, `registry`, `probe`, `evidence`, `compat` | No match |
| 6 | Write the results in the slice file section "Verify results": a table with the mutation, the file and line, the test that failed (or "not caught") | Table written |

Keep any mutation script in `research/generic-packages/tools/mutate-<pkg>.py`, never only in a temp dir or the scratchpad. A fuzz run adds files to `.roc-fuzz/corpus`: put the corpus back after the mutations.

Do at least 8 mutations, and at least one for each public function. Do the mutations one at a time, never two at once. Never leave a mutation in place: before you finish, check that `package/` is the same as at the start (compare with a copy that you made at step 0).

Use the pinned binary: `ROC=cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc`. Set `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to a path with no `..`. Do not use the 10-15 nightly.

## Roc knowledge

Before you read or write Roc, call `get_roc_syntax` once with no arguments. Use `get_roc_syntax(topic: ...)` for one construct, `get_roc_module` for one module, and `search_symbols` / `search_project_symbols` to find a function before you use Grep. Do not request `Builtin.roc` whole. The MCP tools are deferred: load them with ToolSearch `select:mcp__roc-syntax__get_roc_syntax,mcp__roc-syntax__get_roc_module,mcp__roc-syntax__search_symbols,mcp__roc-syntax__search_project_symbols`.

## Final reply to the orchestrator (under 30 lines)

1. Steps 1 to 3 results (counts, bundle hash, file list).
2. The mutation table, in short form: caught N of M. List each mutation that was not caught, with the rule it breaks.
3. Step 5 result.
4. Confirm that `package/` is restored (the compare result).

Style: ASD-STE100 Simplified Technical English, tables, no em-dashes, no bold.
