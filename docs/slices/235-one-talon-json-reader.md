# 235 One `.talon.json` reader

Phase: P2. Status: done

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TF3 (Design Q607), the `.talon.json` exception | A `.talon.json` with a newer `format` (`TalonFile.record_format` + 1) reads as no fields: its time is unknown, and GC keeps the compiler. Only the `link-*` target (`Link.target`) gives exit 19. All readers of `.talon.json` use one function. |
| R-GC5 (last sentence) | A `toolchains/` dir name of a form that this Talon does not know is not listed, not selected and never removed. |
| R-NS1, R-LY1 | The time of an installed compiler (`published_at`, `installed_at`) comes from `.talon.json`. No time: the order falls back to the tag, and the table shows `-`. |
| R-CV5, R-LK4 | The record of a compiler and the `link-*` target. `Link.target` stays strict. |
| R-GC3, R-R5, R-R15 | Other fields of the record that readers use: `compat`, `repo`, `ref`. |

Source: research/cli-format-audit/PLAN.md, findings F7 and F14. Row 235 of docs/slices/PLAN-P2-CLI.md.

## Scope

Readers of `toolchains/<id>/.talon.json` that ignore `format` today (found with a search of `JsonDoc.parse` and `ToolchainMeta` in cli/lib):

| Reader | Where | Field | Users |
| --- | --- | --- | --- |
| `Compiler.published_at_of` | cli/lib/Compiler.roc:252 | `published_at` | `Compiler.times`: `ResolveSelect` (cli/lib/ResolveSelect.roc:102), `Base.times!` (cli/lib/Base.roc:291), `RocManage` (cli/lib/RocManage.roc:335) |
| `Manage.field_of` | cli/lib/Manage.roc:341 | `installed_at` (`time_of`, used by `Manage.rows`), `compat` (`compat_of`), `repo` and `ref` (`origin_of`) | `roc list`, `roc rm`, GC times (`Gc.used_time`, cli/lib/Gc.roc:334), `CacheGc.roc:118`, `TalonRemoveFlow.roc:149` |
| `GitBuild.built_at` | cli/lib/GitBuild.roc:127 | `repo`, `ref`, `sha`, `installed_at` | `GitBuild.newest`, `GitDefault.newest!` (cli/lib/GitDefault.roc:37) |
| `Link.target` | cli/lib/Link.roc:117 | `path` | Already uses `TalonFile.open`. Stays as it is (exit 19). |

The other `JsonDoc.parse` sites (`PathRoc`, `RegistryToolchains`, `Index`, `Nightlies`, `TalonUpdate`, `Zig` index) read other files, not `.talon.json`. The `Zig` GC reads `.last-use` only.

Part F14: the code is believed to do this already (`Compiler.is_compiler_dir`, cli/lib/Compiler.roc:246, `Gc.zig_dirs`). The tests guard it.

Out of scope: the writers of `.talon.json`, `format` numbers (slice 230), `Link.target`.

## Tests

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/FormatTest.roc, first expect of slice 235 (control): with the current `format`, `Compiler.times`, `Manage.rows`, `Manage.compat_of`, `Manage.origins` and `GitBuild.newest` give their field. The texts come from `Toolchain.meta` and `GitBuild.meta`. | R-TF3 R-NS1 R-LY1 | green (guards the others) |
| L0 | `Compiler.times` with the text at `format` + 1 gives `[]` (the time is unknown). | R-TF3 R-NS1 | red: gives the time |
| L0 | `Manage.rows` with `format` + 1: `installed_at` is `Err(Unknown)`. | R-TF3 R-LY1 | red: gives the time |
| L0 | `Gc.toolchains` of that row: the same compiler at the current `format` is old and `Remove`, at `format` + 1 it is `Keep(NoTime)`. | R-TF3 R-GC5 | red: `Remove` |
| L0 | `Manage.compat_of` with `format` + 1 is `Err(None)` (no `compat-<id>/` dir is tied to it). | R-TF3 R-GC3 | red: gives the compat id |
| L0 | `Manage.origins` with `format` + 1 is empty. | R-TF3 R-R15 | red: gives the origin |
| L0 | `GitBuild.newest`: the only build has `format` + 1: `Err(None)`. With an older build of the same repo and ref, the older build wins. | R-TF3 R-R5 R-R6 | red: picks the newer-format build |
| L0 | `Link.target` with `format` + 1 is a failure of kind `Input` and the text names `tln tool update talon`. | R-TF3 R-LK4 | green (guards the exception) |
| L2 | tests/commands/cases/gc/gc9-foreign-newer: age 0 days. Runs: `cache gc --dry-run`, `cache gc`, `cache gc` again, `cache clean --all --dry-run`. `nightly-2026-08-01-aaaaaaa` (format 1, old) goes: it shows that GC runs. `nightly-2026-08-02-bbbbbbb` (format 2, old `installed_at`, no `.last-use`) stays. `toolchains/wasm-x` (a name form that this tln does not know, old time, old `.last-use`) is never read, listed or removed. The default stays. | R-GC5 R-TF3 R-CC10 | red: `bbbbbbb` is removed (stdout, calls.log, tree diff). The `wasm-x` part is green. |
| L2 | tests/commands/cases/roc/ls2-foreign-newer: `roc ls`, `roc list --json`, `roc rm wasm-x`, `roc rm wasm`. The format 2 compiler is listed with `-` (`null` in JSON) for `INSTALLED`. `wasm-x` is not listed, and `roc rm` does not match it (exit 2, nothing is removed). | R-GC5 R-LY1 R-TF3 | red: the format 2 row shows its date. The `wasm-x` part is green. |

Result of the runs (before any code change):

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-6.roc` (the driver that has FormatTest) | 147 tests, 141 pass, 6 fail (the 6 red rows above). 0 compiler errors. |
| `tests/commands/run.sh ls2-foreign gc9-foreign` | both fail, only on the rows named above |
| `tests/commands/run.sh ls1-list gc1-select rm1-remove` | 3 pass (no existing expected output changed) |

Not tested, and why:

| Item | Reason |
| --- | --- |
| "Not selected" for a foreign dir through `ResolveSelect` (rank 6, `roc use`, `roc default`) | `Compiler.installed` filters the list before every selection, and `ls2` covers that function through `roc ls` and `roc rm`. A separate select case adds no rule. |
| `tln cache clean` and a foreign dir | `cache clean` has no code that reads `toolchains/` (the `--all` dry run in gc9 shows that: the calls have no `toolchains` item). The case guards that this stays so. |
| `ResolveSelect`, `Base.times!` and `RocManage` each | They all call `Compiler.times`, so one L0 test covers them. |

### Mutation check (TW12)

I did not edit cli/. The code agent checks these after the code is green. The rows that are green now (the `wasm-x` guard, `Link.target`) cannot be proved with a revert here.

| Id | Mutation (after the code is green) | Caught by |
| --- | --- | --- |
| m1 | `Compiler.published_at_of` ignores `format` again | FormatTest `Compiler.times` expect |
| m2 | `Manage.field_of` ignores `format` again | FormatTest `Manage.rows`, `compat_of`, `origins`, `Gc.toolchains` expects, gc9, ls2 |
| m3 | `GitBuild.built_at` ignores `format` again | FormatTest `GitBuild.newest` expect |
| m4 | `Link.target` reads a newer `format` as no fields | FormatTest `Link.target` expect |
| m5 | `Compiler.is_compiler_dir` accepts any directory name | gc9 and ls2 (`wasm-x` is read, listed or removed) |
| m6 | The new reader gives no fields for a bad `format` only, but reads a `format` that is a text | not tested (R-TF6 for `.talon.json` is a design gap, see Open 2) |

## Changed expectations

None. No existing case or test changes. The new L2 cases are new directories.

## Code proposal

| Item | Proposal |
| --- | --- |
| New function | `TalonFile.fields_of : Try(Str, [NotFound, Denied, Other(Str)]) -> Try(List((Str, JsonDoc)), [None])`, next to `record_format` in cli/lib/TalonFile.roc. It parses the text and checks that it is an object. `format` is a number and is not more than `TalonFile.record_format`. It returns the fields (with no `format`). A missing file, a bad read, text that is not JSON, no `format` or a newer `format` give `Err(None)`. |
| Readers | `Compiler.published_at_of`, `Manage.field_of` and `GitBuild.built_at` call it and then look for their key. Each of them loses its own `JsonDoc.parse`. |
| `Link.target` | No change: it calls `TalonFile.open` (exit 19). |
| Size | About 15 lines new, about 15 lines removed. |

## Text proposals (TW24)

None. The slice adds no output text. The only visible change is the `-` in the INSTALLED column (and `null` in `--json`), which the existing form of `roc list` already has for an unknown time (R-LY1).

## Mutation results (research/slice-235-revert/mutate.sh)

The unchanged mirror passes l0-6 (147).

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | `TalonFile.fields_of` accepts format + 1 | l0-6 (6 failed); gc9, ls2 (m1b) |
| m2 | `Manage.field_of` reads a format 2 file as format 1 | gc9, ls2 |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only). Manager decision: a `.talon.json` with no `format` also reads as no fields (one rule for each read failure).

## Open

| Item | Owner |
| --- | --- |
| 1. No TW17 question. R-TF3 and R-GC5 say what to do. | none |
| 2. A `.talon.json` that has no `format`, or whose `format` is not a number, reads as no fields in the code proposal. Today a reader that ignores `format` still reads its fields from such a file. R-TF3 names only a newer `format`. R-TF6 (garbage stops with exit 19) does not say that a `.talon.json` is exempt. The tests do not cover this case, so the code agent may keep the old read for it. If the human wants one rule, it is a design text. | Human (information) |
| 3. A `.talon.json` written by an old Talon before `format` existed is not a case: the file has had `format` from the first release (R-TF1). | none |
| 4. The expected `calls.log` of `gc9` for the green state is derived by hand from the red output (the calls for `bbbbbbb` removed, and run 3 reads `bbbbbbb` and the default). If the code agent finds a small difference, such as a changed read order, it tells the human before it changes the file (TW18). | Code agent, human |
