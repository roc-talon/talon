# Brief: scope and red tests for one generic package

You are the scope agent and the test agent for one generic Roc package (TESTING.md 7.1, steps 1 and 2). A different agent writes the code later (TW18). You write no code bodies.

## Limits

| Do | Do not |
| --- | --- |
| Work in the local package dir `../<pkg>/` (`git init -b main` if it is new) | Create a GitHub repository. Commit or push anything. Commit in the Talon repo. |
| Write the slice file `research/generic-packages/slices/<pkg>.md` (form: TESTING.md 7.2) | Edit any Talon design file |
| Put each open point in the slice file "Questions" section (TW17), and stop that part | Choose behavior that the design or the spec does not state |
| Name in the public API no Talon concept (R-GP1) | Name `talon.toml`, registry, probe, evidence in the API or the README |
| Write each `expect` with a comment that names its source: the spec section, the Design 2 fact, or the rule id | Copy or translate roc compiler code (roc-app-header is a clean-room rewrite, R-GA7) |

## Read first

- `CLAUDE.md`
- `TESTING.md` sections 1, 4, 7 (all TW rules)
- `DESIGN.md` section 2 (facts), 6.1 (R-GP1 to R-GP7, R-PK rows), 6.2 (R-GA4 to R-GA7)
- `research/generic-packages/LAYOUT.md` (the layout, the commands, open points LP1 to LP7) and `layout-probe/` (a working example of each file kind)
- The package-specific rows that your prompt names

## Roc knowledge

Before you read or write Roc, call `get_roc_syntax` once with no arguments. Use `get_roc_syntax(topic: ...)` for one construct (for example modules, package headers, `exposes`, tests, `expect`), `get_roc_module` for one module, and `search_symbols` / `search_project_symbols` to find a function before you use Grep. Check every file with `roc_check` and format it with `roc_fmt`. Do not request `Builtin.roc` whole.

The MCP tools are deferred. Load them with ToolSearch `select:mcp__roc-syntax__get_roc_syntax,mcp__roc-syntax__get_roc_module,mcp__roc-syntax__roc_check,mcp__roc-syntax__roc_fmt,mcp__roc-syntax__search_symbols,mcp__roc-syntax__search_project_symbols`. The MCP `roc_check` has no `roc` on its PATH. Run every check with the pinned binary:

`ROC=cloudflare-workers/.cache/nightlies/nightly-2026-10-09-258ab27/roc`

Set `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to a path with no `..` (see `layout-probe/run.sh`).

## Layout (from LAYOUT.md)

| Path | Who writes it | Content |
| --- | --- | --- |
| `package/main.roc` | You | Header with `exposes` |
| `package/<Module>.roc` | You: the public signatures and doc comments, each body `crash "todo"` (parameters named `_x`, LAYOUT.md point 4). The code agent fills the bodies. | Public modules |
| `package/Internal/*.roc` | Code agent | Hidden modules. Do not create them. |
| `tests/<module>.roc` | You only | L0 test apps: `app [main!] { pkg: "../package/main.roc" }`, `main! = \|_args\| Ok({})`, then `expect`s. Test through the public API only (a test app cannot import a hidden module). |
| `fuzz/<property>.roc` | You only | L1 roc-fuzz 0.4.3 targets, one property each (TESTING.md 4) |
| `tests/fixtures/` | You only | Data files, if any |
| `scripts/test.sh` | You | Runs check, fmt check, all `tests/*.roc`, then builds and runs each fuzz target with `--runs=N --seed=1 --time=0` (TW6). Exit 0 only when all pass. |

## Done when

| Check | Result |
| --- | --- |
| `roc check package/main.roc` | Exit 0 (the stubs compile) |
| `roc check` and `roc fmt --check` on each test and fuzz file | Exit 0 |
| `roc test tests/<x>.roc` | Each test fails for the right reason: "todo" |
| Each fuzz target | Builds, and fails on the stub (exit 77) |
| Slice file | Rules, the function list with signatures, the test table (layer, file, case, source), out of scope, questions, proposed first version |

## Final reply to the orchestrator (under 70 lines)

1. The public API: each function with its signature.
2. The test counts: L0 `expect`s per file, L1 targets with the property of each.
3. Dependencies on other packages (release URL with hash), and why.
4. Each decision you made, with the options you rejected.
5. Questions (TW17), and design gaps (a design row that is wrong or incomplete, with the change you propose).
6. The proposed first version, with the reason.

Style for all text: ASD-STE100 Simplified Technical English, tables over text, no em-dashes, no bold or stars.
