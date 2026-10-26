# 073 Tool selectors, `--json` tools, `x` flags, binary file

Phase: P1. Status: done

Slice 073 is the plan row 073 of `PLAN-P1.md` (section 2c). The design agent changed R-PT5, R-PT11 and R-B10 on 2026-10-25 (`DESIGN-GAPS-2026-10-25.md`). The slice closes 4 gaps of slices 056, 059 and 049. The test agent wrote tests and stubs. A private reference (`research/slice-073-revert/reference/`, kept until the review is applied) passes all of them.

## 1. Rules, and the tests that name them

| Rule | Change | Tested by |
| --- | --- | --- |
| R-PT5 (selector) | A selector on a key of `[tools]` in `update` or `upgrade` (`update foo@^2`) is exit 2 and names `tln add --tool owner/app@<sel>`. A name that is no key goes to the header as before | L0 `ToolsplanTest` 7 (row changed), 18. L2 `ptool/pt3-move` run 15 |
| R-PT5, R-OUT4 (`data.tools`) | `--json` of `install`, `update` and `upgrade` has `data.tools` when the tools step handled an entry: the rows of the `--tool` commands | L0 `ToolsplanTest` 19. L2 `pt2-install` run 15, `pt3-move` runs 16, 17, `pt4-bin-file` run 1 |
| R-PT11 (flags) | `--roc` and `--allow-unchecked` with a project tool in `tln x` are exit 2. With a selector or no hit they stay as before | L0 `RunscriptTest` 21. L2 `x/x3-project` runs 15, 16 |
| R-B10 (binary) | An `x` entry has the binary when its dir holds the file that the manifest names: `<repo>`, with `.exe` on Windows only | L0 `ToolsplanTest` 20. L2 `ptool/pt4-bin-file` runs 1, 2 |

Other rule ids that the tests name: R-PT3, R-PT12, R-UP5, R-J3, R-X1, R-X2, R-B5, R-I5, R-PT6, R-PT8.

## 2. Public signatures (fixed by the L0 tests)

| Function | Signature | Stub state |
| --- | --- | --- |
| `ToolsPlan.split` | not changed (`{ command, names, keys, aliases } -> Try({ header, tools }, Fail)`) | old behavior: a name with `@` goes to the header |
| `ToolsPlan.with_tools` (new) | `{ base : JsonDoc, rows : List(<the row of ToolsPlan.data>) } -> JsonDoc` | `crash "todo: slice 073"` |
| `XProject.flags_stop` (new) | `{ key : Str, roc : [Auto, Pinned, Installed], unchecked : Bool } -> Try({}, Fail)` | `crash "todo: slice 073"` |
| `XCacheIo.has_file` | now public. `Try(List({ name, is_dir, mtime }), [NotFound, Denied, Other(Str)]), Str -> Bool`. The `Str` is the file that the manifest names (the repo, with `.exe` on Windows) | old body: it also takes `<repo>.exe` |

Proposed structure (not fixed by a test, the reference does it; the code agent may choose another): `XCacheIo.entries!` gets the system (`Fx, Roots, Setup.Os`) and gives `has_file` the file of `file_of({ os, name })`. `ToolsStep.after!` also gives `rows : List(ToolsStep.JsonRow)`. `InstallFlow.install_with!` and `Resolve.install_with!` give `{ outcome, tools }`. `Install.print!` and `Update.print!` call `ToolsPlan.with_tools`. `Report.Outcome` does not change (`tests/unit/ReportTest.roc` builds it as a record). `XProject.table!` calls `flags_stop` before `Known.record!`. About 150 lines of change in 14 modules, all under 490 lines.

## 3. Tests

| Layer | File and case | Content |
| --- | --- | --- |
| L0 | `tests/unit/ToolsplanTest.roc` 7 (changed), 18, 19, 20 | split with selectors (`fmt@^2`, `foo@latest` for `update` and `upgrade`, the first failure wins, header names with `@` stay). `with_tools` (2 rows, 1 row, no row, the key `tools` is last). `has_file` (10 rows) |
| L0 | `tests/unit/RunscriptTest.roc` 21 | `flags_stop`: no flag, `--roc` (2 values), `--allow-unchecked`, both |
| L2 | `ptool/pt2-install` run 15 | `install --json --file p11/main.roc`: locks and builds `d`. One envelope with `data.tools` (1 row `locked`, `built` true) |
| L2 | `ptool/pt3-move` runs 15 to 17 | `update fmt@^2` (exit 2). `update --json --file p4/main.roc` (header flow and 1 row `moved`). `upgrade --json foo --file w/m1/main.roc` (names are keys only: the idle header outcome and 1 row `moved`, `^1` becomes `^2`). `p4` is new |
| L2 | `x/x3-project` runs 15, 16 | `x fmt --roc installed --allow-unchecked` (exit 2, no record, no `platform`, no `x` read). The same flags with `acme/fmt@1.0.0`: as run 3 |
| L2 | `ptool/pt4-bin-file` (new case, 30 files) | run 1 Linux, `install --frozen --json`: the entry has `foo.exe` only, so it is built, the stale dir is deleted. Run 2 Windows (`fx/platform` has one row for each run): the entry has `bar` only, so it is built (`bar.exe`) |

Counts: new L0 `expect`s 4 (3 in `ToolsplanTest`, 1 in `RunscriptTest`), 1 changed. New L2 runs 7 in 3 old cases, 1 new case with 2 runs.

Why a new case for R-B10: an `x` entry in the `given` home of an old case changes the lines `read_files` and `list_dirs` of the `x` dir in each run of that case (TW21 noise in about 14 `calls.log` lines of `pt2-install`). The new case holds the 2 stale entries alone.

### TW21: old expected files that changed

| File | Change |
| --- | --- |
| `tests/unit/ToolsplanTest.roc` 7 | the row `foo@^2` (a header name before) is now `json@^2` (an alias with a selector), because `foo@^2` on a key is exit 2. The comment says so |
| `pt2-install`, `pt3-move`, `x3-project` | only appended: the new runs in `fx/commands`, `rules`, and the end of `expect/*`. `tree.diff` shows the end state, so the lines of `projects.json` and of the changed `talon.toml` files (`w/talon.toml`) changed. The `calls.log` of runs 1 to 14 did not change (`diff` of the files against `research/slice-073-revert/before/`) |
| `pt2-install/fx/probes` | one more build row (the build of run 15) |

## 4. Output (proposed, R-OUT2, TW24)

| Output | Text |
| --- | --- |
| Selector on a key (stderr, exit 2) | `'fmt@^2' is a selector on the [tools] key 'fmt'. A selector changes its ref: run tln add --tool owner/app@^2` (`<sel>` is the text after the first `@`; `owner/app` stays as the design writes it) |
| `data.tools` of `install`, `update`, `upgrade` | the last key of `data`, after `written`: an array of rows with the keys of the `--tool` commands (`key`, `name`, `action`, `ref`, `url`, `version`, `previous`, `file`, `built`, `would_build`). One row for each entry that the step handled. An entry that did not change has the action `kept`. No `[tools]` entry, or no step: no key `tools` |
| Flags with a project tool (stderr, exit 2) | `--roc has no effect on the project tool fmt: its pin and its url are the lock. Remove the flag.` Also `--allow-unchecked has ...`. With both: `--roc and --allow-unchecked have no effect on the project tool fmt: ... Remove the flags.` |

## 5. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `data.tools` is present when the step handled at least one entry, with a `kept` row for an unchanged entry. Absent otherwise | Only the rows that changed. `tools: []` when there is no row |
| D2 | A run with `--roc` or `--allow-unchecked` and a hit stops before `Known.record!` (nothing is recorded, as for `Many` of slice 059) | Record first, as for the failures after a hit |
| D3 | "The file that the manifest names" is the file of `XCache.layout` (R-X2): the repo of the manifest `name`, `.exe` on Windows only. The manifest has no field for a file name (R-B9) | A new manifest field |
| D4 | `XCacheIo.has_file` is public so that L0 can test it. The slice 056 code already refuses a directory and `other` files: what is left is the system-dependent suffix | A private function that only L2 reaches |
| D5 | The stop for a selector on a key is in `ToolsPlan.split`, before the header flow (no index call). `--tool` with a selector is already exit 2 (slice 056, `ToolsCmd`) | A stop in the header flow |
| D6 | New case for R-B10 (see section 3) | Entries in the home of `pt2-install` |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| `tln outdated` rows for tools (R-CM6) | Later (slice 056 section 7) |
| L3 | The 4 changes are command flow with the fake `Fx`. The L3 case `ptools/pt1-flow` has no `--json`, no `x` flag |

## 7. Questions (TW17) and design gaps

| # | Question or gap | What the tests pin |
| --- | --- | --- |
| Q1 | A name that is a header alias and a key, with a selector (`pf@^2`): the alias rule (`--tool pf`) or the selector rule? Both are exit 2 | Not pinned. The reference gives the alias text |
| Q2 | `data.tools` for `install --frozen --json` and for a run with `[tools]` where nothing changed: R-PT5 says "that move, lock or build" | D1: rows are there for each handled entry (`kept` for no change). The frozen run is pinned by `pt4-bin-file` run 1 |
| Q3 | Does a run that stops for the flags record the project (R-PD9)? R-PT11 gives no order | D2: no |
| Gap | The `--json` of `update` and `upgrade` when only tool keys are named (the header flow does not run): the header keys of `data` are the idle values | Pinned by `pt3-move` run 17 |

## 8. Red run, revert check

Red run with the stubs (`research/slice-073-revert/red-all.log`, `red-both.log` has the state with the stubs of slice 074):

| Step | Result |
| --- | --- |
| check, fmt, selftest | pass (the stubs compile, the new files are formatted) |
| l0 | 4 `expect`s fail: `ToolsplanTest` 18 (wrong value: `Ok` in place of the exit 2), 19 (`todo: slice 073`), 20 (wrong value: `fmt.exe` counts), `RunscriptTest` 21 (`todo: slice 073`). `ToolsplanTest` 7 (the changed row) passes in both states |
| l2 | 4 cases fail: `pt2-install` (run 15, no `tools` key), `pt3-move` (runs 15 to 17), `pt4-bin-file` (no build: the entry counts), `x3-project` (runs 15, 16: the `x` run goes on) |
| l3 | pass (not changed) |

Green run with the reference (`research/slice-073-revert/green-all.log`): check, fmt, l0, l2, l3, selftest, l1 all pass. Old tests: all pass in the stub state, except the cases of the table in section 3.

Revert check (`research/slice-073-revert/mutate.py`, result in `mutants.log`, 7 hand mutations of the private reference, filtered runs, the reference is put back after each):

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `flags_stop` runs after the record (D2) | L2 `x3-project` |
| M2 | `entries!` looks for the repo name, not the file of the system | L2 `pt4-bin-file` (the Windows run) |
| M3 | the frozen install drops the rows of `data.tools` | L2 `pt4-bin-file` |
| M4 | `update` and `upgrade` print no `data.tools` | L2 `pt3-move` |
| M5 | the selector stop is for `update` only | L0 `ToolsplanTest` 18 |
| M6 | `with_tools` adds an empty `tools` key | L0 `ToolsplanTest` 19 |
| M7 | `flags_stop` checks `--roc` only | L0 `RunscriptTest` 21 |

7 mutations, 7 caught.

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| `has` is a reserved word | the helper of the L0 row is `holds` |
| `Report.Outcome` is a closed record that `ReportTest` builds | the reference carries the rows beside the outcome (`{ outcome, tools }`) |
| `roc fmt` indents a chain of `and` | the test files are formatted (staircase of `and`) |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Order | 1. `ToolsPlan.split`, `with_tools`, `XProject.flags_stop`, `XCacheIo.has_file` (L0). 2. The wiring of the flags (`XProject.table!`) and of the file (`XCacheIo.entries!`). 3. The `data.tools` wiring (section 2) |
| Run | `scripts/test.sh l0`, `tests/commands/run.sh ptool/ x/x3`, then `scripts/test.sh` |
| Tests | Do not edit tests (TW18). A wrong row goes back to the test agent |

## Review (manager, 2026-10-25)

Accepted with all decisions D1 to D6 as written. Manager answers:

| Question | Answer |
| --- | --- |
| Q1 alias plus key with a selector | Exit 2, the text is not pinned. This is fine |
| Q2 `data.tools` for `--frozen` | Yes (pinned by `pt4-bin-file` run 1) |
| Q3 the stop for the `x` flags | Records nothing (D2) |

The private reference, `mutate.py`, `mutants.log`, the logs and the switch scripts were deleted. `before/` and `stubs/` stay in `research/slice-073-revert/`.

## Code (code agent, 2026-10-25)

Disputes (from the code agent): none. No test, fixture or expected file was changed.

| Decision | Rejected |
| --- | --- |
| `XCacheIo.entries!` gets `Setup.Os` as its third argument. Each caller already had the system (`machine.os`, `facts.os`). `has_file` gets `file_of({ os, name })` of each entry (the file differs for each entry name) | One file for all entries |
| `InstallFlow.Done : { outcome, tools }` is the result of `install_with!`. `InstallFlow.install!` gives `.outcome`. `Update.print!` and `Install.print!` take `Done`. `Update.resolve!` gives `Done` (so `Init` takes `.outcome`) | A field in `Report.Outcome` |
| `ToolsStep.JsonRow` and `ToolsStep.json_rows` (the rows with the file path and the action as text). `ToolsStep.data` uses them | A second map in `InstallFlow` |
| `ToolsPlan.split`: a name that is an alias and a key, with a selector, gives the alias failure (Q1, text not pinned) | The selector text |

## Verify results

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `flags_stop` after `Known.record!` | L2 `x/x3-project` |
| M2 | `has_file` also takes `<file>.exe` | L0 `ToolsplanTest` 20 |
| M3 | the selector stop is for `update` only | L0 `ToolsplanTest` 18 |
| M4 | `with_tools` adds an empty `tools` key | L0 `ToolsplanTest` 19 |
| M5 | `flags_stop` ignores `--roc` | L0 `RunscriptTest` 21 |
| M6 | the frozen install drops the rows | L2 `ptool/pt4-bin-file` |
| M7 | `Update.print!` drops the rows | L2 `ptool/pt3-move` |

7 mutations, 7 caught. The code was compared with the code before the mutations (the crash of the session removed the copies, so each changed file was read again against the `before/` diff).

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-073-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, both slices in) | Exit 0, all 7 steps, 180 L2 cases |
| Session crash during the code step | The code agent re-read each changed file against `before/` and found no leftover mutation; the full run after the crash is clean |
| Gap step | Skipped: 12 of 12 code-agent mutations caught, no new decision that needs a test |
