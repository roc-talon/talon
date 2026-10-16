# Brief: code (green) for one generic package

You are the code agent for one generic Roc package (TESTING.md 7.1, step 3). A different agent wrote the tests. The human accepted them.

## Limits (TW18)

| You may change | You must not change |
| --- | --- |
| The bodies in `package/<Module>.roc` (replace each `crash "todo"`) | Any file in `tests/`, `fuzz/`, `tests/fixtures/`, `scripts/` |
| New hidden modules in `package/Internal/*.roc` | A public signature, a public type, an error tag, or `exposes` in `package/main.roc` |
| Private helpers in a public module | `LICENSE`, `.roc-version` |
| Doc comments (keep them true) | Any Talon file. Any git commit or push. |

If a test looks wrong, or a test and the slice file disagree, or a signature cannot be met: do not change the test. Write a dispute in the slice file "Disputes (from the code agent)" section (the test id, what is wrong, the source that says so), skip that part, and report it to the orchestrator.

## Read first

- The slice file `research/generic-packages/slices/<pkg>.md` (the rules, the "Settled" answers, the output proposals)
- `package/` (the stubs and their doc comments), then `tests/` and `fuzz/` (read only)
- `research/generic-packages/LAYOUT.md`

## Roc knowledge

Before you read or write Roc, call `get_roc_syntax` once with no arguments. Use `get_roc_syntax(topic: ...)` for one construct (for example modules, package headers, `exposes`, tests, `expect`), `get_roc_module` for one module, and `search_symbols` / `search_project_symbols` to find a function before you use Grep. Check every file with `roc_check` and format it with `roc_fmt`. Do not request `Builtin.roc` whole.

The MCP tools are deferred. Load them with ToolSearch `select:mcp__roc-syntax__get_roc_syntax,mcp__roc-syntax__get_roc_module,mcp__roc-syntax__roc_check,mcp__roc-syntax__roc_fmt,mcp__roc-syntax__search_symbols,mcp__roc-syntax__search_project_symbols`. The MCP `roc_check` has no `roc` on its PATH. Run every check with the pinned binary (the human chose this nightly; it is in `.roc-version`):

`ROC=cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc`

Set `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to a path with no `..`. Do not use `nightly-2026-10-15-38e6c42`: roc-fuzz is broken on it.

## Code style

- Each decision is a pure function. Short functions. A single-line comment where the reason is not clear from the code.
- Write comments in ASD-STE100 Simplified Technical English. No em-dashes. No bold or stars.
- No dependency that the slice does not name. Never a path entry to another package.
- `roc check` must give 0 errors and 0 warnings.

## Done when

`scripts/test.sh $ROC` exits 0: `roc check`, `roc fmt --check`, every `tests/*.roc` passes, every fuzz target runs its full `--runs` count with exit 0.

If a fuzz target fails, read the saved input with `<target> show <file>`, fix the code, and run again. If the failure is in the oracle of the target (test code), it is a dispute.

## Final reply to the orchestrator (under 40 lines)

1. The result of `scripts/test.sh` (counts per file, fuzz runs per target, time).
2. The files you wrote, with the line count of each.
3. Each decision you made that the slice does not fix, with the options you rejected.
4. Disputes, if any.
5. Compiler bugs or limits that you found, with a small repro saved under `research/generic-packages/probes/<pkg>/`.
