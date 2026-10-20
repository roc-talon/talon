# Brief: scope and red tests for one Talon slice

You are the scope agent and the test agent for one slice of the `tln` CLI (`TESTING.md` 7.1, steps 1 and 2). A different agent writes the code later, with no access to your session (TW18). So the slice file and the tests must hold all that the code agent needs.

## Limits

| Do | Do not |
| --- | --- |
| Write the slice file `docs/slices/NNN-<name>.md` (form: `TESTING.md` 7.2) | Write the bodies of decisions or commands. A stub is `crash "todo"` with parameters named `_x`. |
| Write tests, fixtures, fakes and the public signatures (types, the `Fx` fields, module exposes) | Edit a design file (`DESIGN*.md`, `TESTING.md`) |
| Put each open point in the slice file "Questions" section (TW17), and stop that part | Choose a behavior (a fact that the command decides) that the design does not state |
| Propose output text and `--json` `data` fields that the design does not give (TW24), in the slice file "Output" section and in the expected files | Commit or push. Touch `cloudflare-workers/`. |
| Name the rule ids in each test (`# R-H3: ...`, TW13) | Write a path entry to a generic package (R-GP3) |

## Test budget (the manager's rule)

Few tests, each with a large reach (`docs/slices/PLAN.md`, "Test budget"):

- About 5 to 20 L0 `expect`s, for pure decisions with many cases or edge cases. One `expect` can check a list of cases.
- About 2 to 6 deep tests (L2 or L3): a whole command flow, with the parts of earlier slices in the path. One case checks the exit code, stdout, stderr, the file tree and the call log, so it covers many rules.
- Each rule id of the slice is named by at least one test. A rule that no test can check in P0 goes to "Out of scope" with the reason.
- Do not test a generic package again (R-GP5). Test the Talon use of it.

## Read first

1. `CLAUDE.md`, `docs/slices/PLAN.md` (the pinned compiler, platform and package URLs), the files of the earlier slices in `docs/slices/`.
2. `TESTING.md` (all of it: the layers, the code shape, the `Fx` record, the runners, the TW rules).
3. The design sections that your slice names, and the rules that they refer to. `scripts/rules.sh R-XX R-YY` lists the ids of a group with their sections.
4. The code and tests that exist (`cli/`, `packages/`, `tests/`, `scripts/`).

## Roc knowledge (roc-syntax MCP)

Before you read or write Roc, call `get_roc_syntax` once with no arguments. The syntax of this compiler is new: do not trust Roc that you remember. Use `get_roc_syntax(topic: ...)` for one construct, `get_roc_module` for one module (for example a basic-cli module), and `search_symbols` / `search_project_symbols` (up to 8 queries in one call) to find a function before you use Grep. Check each file with `roc_check` and format it with `roc_fmt`. Never request `Builtin.roc` whole.

The MCP tools are deferred. Load them first with ToolSearch: `select:mcp__roc-syntax__get_roc_syntax,mcp__roc-syntax__get_roc_module,mcp__roc-syntax__roc_check,mcp__roc-syntax__roc_fmt,mcp__roc-syntax__search_symbols,mcp__roc-syntax__search_project_symbols`. The MCP `roc_check` runs the pinned nightly.

For shell runs, use the pinned binary: `ROC=/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc`. Set `XDG_CACHE_HOME` and `ROC_CACHE_DIR` only to absolute paths with no `..` (`TESTING.md` 3.2).

## Done when

| Check | Result |
| --- | --- |
| `roc check` of each new or changed Roc file | 0 errors. The stubs compile. |
| `roc fmt --check` | Exit 0 |
| The new tests | Each fails for the right reason ("todo", or a wrong value). Record the fail output in the slice file. |
| The old tests | All pass (`scripts/test.sh`, when it exists) |
| Slice file | Rules, the public signatures, the test table (layer, file, case, rule ids), the output proposals, out of scope, questions. The status is `review`. |

## Final reply to the manager (under 60 lines)

1. The files you wrote, with the line count of each.
2. The test counts: L0 `expect`s per file, deep cases with the rule ids of each.
3. Each decision you made that the design does not fix, with the options you rejected.
4. Questions (TW17) and design gaps.
5. The rule ids that are out of scope, with the reason.

Style for all text and comments: ASD-STE100 Simplified Technical English, tables over text, no em-dashes, no bold or stars.
