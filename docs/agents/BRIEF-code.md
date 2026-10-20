# Brief: code (green) for one Talon slice

You are the code agent for one slice of the `tln` CLI (`TESTING.md` 7.1, step 3). A different agent wrote the tests. The manager accepted them.

## Limits

| You may change | Rule |
| --- | --- |
| Code: `cli/`, `packages/`, and the stubs of the slice | Replace each `crash "todo"`. Keep the public signatures, or record each change in the slice file. |
| A test, a fixture or an expected file | Only when it contradicts the design, or has a plain bug (a typo, a wrong path, a test that cannot compile). Each change gets a row in the slice file "Disputes (from the code agent)": the test, the change, the design source. Never change a test only to make your code pass. |
| Nothing else | No design file. No commit or push. Not `cloudflare-workers/`. No path entry to a generic package (R-GP3). |

If the design does not say what the code must do, do not choose: write a question in the slice file (TW17), skip that part, and report it.

## Read first

1. `CLAUDE.md`, `docs/slices/PLAN.md`, the slice file `docs/slices/NNN-<name>.md`.
2. `TESTING.md` sections 2 and 3 (the code shape and the runners).
3. The design sections that the slice names.
4. The tests of the slice (all of them), then the existing code.

## Roc knowledge (roc-syntax MCP)

Before you read or write Roc, call `get_roc_syntax` once with no arguments. The syntax of this compiler is new: do not trust Roc that you remember. Use `get_roc_syntax(topic: ...)` for one construct, `get_roc_module` for one module (for example a basic-cli module), and `search_symbols` / `search_project_symbols` (up to 8 queries in one call) to find a function before you use Grep. Check each file with `roc_check` and format it with `roc_fmt`. Never request `Builtin.roc` whole.

The MCP tools are deferred. Load them first with ToolSearch: `select:mcp__roc-syntax__get_roc_syntax,mcp__roc-syntax__get_roc_module,mcp__roc-syntax__roc_check,mcp__roc-syntax__roc_fmt,mcp__roc-syntax__search_symbols,mcp__roc-syntax__search_project_symbols`. The MCP `roc_check` runs the pinned nightly.

For shell runs, use the pinned binary: `ROC=/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc`. Set `XDG_CACHE_HOME` and `ROC_CACHE_DIR` only to absolute paths with no `..`.

## Code style

- Each decision is a pure function (TW1). Command code is direct-style Roc over the `Fx` record. The real `Fx` has no Talon logic (TW4).
- Short functions. Names that read like the design. A comment only where the reason is not clear from the code.
- Comments in ASD-STE100 Simplified Technical English. No em-dashes. No bold or stars.
- `roc check`: 0 errors and 0 warnings.
- Prototype code goes in `research/`, never only in a temp dir.

## Done when

`scripts/test.sh` exits 0: all old and new tests pass. Then do the revert check (TW12) for the slice: for each rule id of the slice, break the code of that rule in one small way, run the tests, see a test fail, and put the code back exactly. Record the results in the slice file "Verify results" (the mutation, the test that failed, or "not caught"). Check at the end that the code is the same as before the mutations (keep a copy and compare).

## Final reply to the manager (under 50 lines)

1. The result of `scripts/test.sh` (counts per layer, time).
2. The files you wrote, with the line count of each.
3. Each decision you made that the slice does not fix, with the options you rejected.
4. Each test that you changed, and why (the dispute rows).
5. The revert check: caught N of M. Each mutation that no test caught.
6. Questions (TW17), compiler bugs or limits (with a small repro under `research/`).

Style: ASD-STE100 Simplified Technical English, tables, no em-dashes, no bold.
