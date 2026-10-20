# 006b Probe follow-ups

Phase: P0. Status: done

Slice 006b closes 4 items that slices 006 and 007 left open. All 4 are small. The scope agent and the test agent are one agent here. The code agent writes the bodies (TW18).

| # | Item | Source | Change of code (code agent) |
| --- | --- | --- | --- |
| 1 | Exit 128 plus n is never a crash. Only exit 139 is (R-RC4 names it). Exit 134 is `NoFact("no result (exit 134)")`. | Slice 006, answer of the user to Q1 | `Probe.is_fault_exit` accepts only 139 (`cli/lib/Probe.roc:121`). The table of `Probe.classify` (`cli/lib/Probe.roc:61`) loses the words "128 + a fault signal". |
| 2 | A util that changes path prefixes in the files of the probe copy that match a glob (the header path entries and the `import "<file>"` strings of all `.roc` files, Q1 answered yes). The ladder uses it for the candidate header and for the other `.roc` files. | Slice 006, answer of the user to Q4. Review of this slice, Q1. | New module `Rebase` (stub in `cli/lib/Rebase.roc`). `Ladder.probe_in_copy!` (`cli/lib/Ladder.roc:210`) walks the copy and calls `Rebase.files` in place of the header-only rewrite with `Text.resolve` (`candidate_text`, `cli/lib/Ladder.roc:247`). |
| 3 | The kind of a new name comes from the newest candidate (by `published_at`), not from the first candidate in page order. | Slice 007, review of the code, C2 and D6 | `Resolve.prepare!` (`cli/lib/Resolve.roc:817`): `first` is the candidate with the highest `published_at`. A tie keeps the first (the rule of `Index.new_entry`, `cli/lib/Index.roc:73`). |
| 4 | `--no-check` with `--json` gives `data.check` = `skipped` (R-LF3, R-BL6). | Slice 007, review of the code, M1 | None. The code is right today. The test is new (it did not exist: the mutation M1 of slice 007 was not caught). |

## Rules

| Id | Where tested |
| --- | --- |
| R-RC4 (Q1) | L0 `probe.roc` expect 1 (changed row) |
| R-LD4 (Q4, Q1), R-H7, R-H1 | L0 `rebase.roc` 1 to 4, L2 `install/in1-flow` (M26 stays) |
| R-AD32, R-AD33 (D6 of slice 007) | L2 `install/in1-flow` runs 1, 2, 4 (the read of the kind) |
| R-LF3, R-BL6 | L2 `install/in1-flow` run 5 |

## Files

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Rebase.roc` | 64 | New. Stub (`crash "todo"`) and the doc comment with the rules. |
| `cli/lib/main.roc` | 65 | Exposes `Rebase` |
| `tests/unit/rebase.roc` | 158 | New. 4 `expect`s. |
| `tests/unit/probe.roc` | | 1 row changed (exit 134, in expect 1) |
| `tests/commands/FakeFx.roc` | 615 | The fake `probes!` also logs the import lines of the other `.roc` files of the copy (`probe-text`, see its doc) |
| `tests/commands/cases/install/in1-flow/` | | `given/project/app/main.roc` and `given/project/app/inner/main.roc` (new path entry in the app dir), `given/project/app/Helpers.roc` and `given/project/app/inner/Deep.roc` (modules with embeds), `fx/commands` (run 5), all files of `expect/`, `rules` |
| `tests/commands/cases/ladder/ld-ladder-flow`, `resolve/rs-highest-use`, `rs-install-add-key`, `rs-new-toml`, `rs-update-scope`, `rs-workspace-shared-group` | | `expect/calls.log`: one new line `list_dirs <copy>` after each `copy_tree` |
| `research/slice-006b-revert/` | 102, 38 | `mutate.py` and `results.md`: the record of the revert check |

## Public signatures (stub)

| Module | Signature | Body |
| --- | --- | --- |
| `Rebase` | `File : { path : Str, text : Str }` (`path` is relative to the root of the copy) | |
| `Rebase` | `glob_match : { glob : Str, path : Str } -> Bool` | `crash "todo"` |
| `Rebase` | `path : { path : Str, file_dir : Str, from : Str, to : Str } -> Str` | `crash "todo"` |
| `Rebase` | `embeds : { text : Str, file_dir : Str, from : Str, to : Str } -> Str` (the name `imports` is reserved) | `crash "todo"` |
| `Rebase` | `files : { files : List(File), glob : Str, from : Str, to : Str } -> List(File)` | `crash "todo"` |

The contract of each function is in its doc comment. In short:

| Function | Contract |
| --- | --- |
| `glob_match` | The glob matches the whole path. `*` is a run with no `/`. `?` is one character that is not `/`. `**` is any run. `**/` is zero or more whole segments. No other special character. |
| `path` | One path string of a file in `file_dir`. An absolute path stays. A path that never goes above `from` stays (the copy has the target at the same place). A path that goes above `from` becomes the absolute target, or, when the target is in `from` again, the target with the prefix `from` changed to `to`. A prefix is a whole segment. |
| `embeds` | The text with the file of each line that starts with `import "` (column 0) changed by `path`. An indented line, a comment, `import pf.Stdout` and a string that holds the word `import` stay. All other bytes stay. |
| `files` | The files that the glob matches, with each path entry of the header (`path`) and each import file (`embeds`) changed. Only the files whose text changed are in the result, in the order of the input. Only the bytes of the changed values change. |

The use in `Ladder` (the code agent writes it in `probe_in_copy!`; the L2 cases fix the result). The glob is one constant, `**/*.roc`:

| Step | Call | Note |
| --- | --- | --- |
| 1 | `fx.copy_tree!` (as today) | |
| 2 | `fx.list_dirs!([copy])`, then `fx.list_dirs!` of the subdirs of that level in one call, and so on until no dir is left | The first call has the copy dir as it is (no `/` at the end). Each level is one call. The `.roc` files (names that end with `.roc`) are collected as paths relative to the copy, and sorted with `Text.sorted`. A listing that fails is an `Environment` failure. |
| 3 | `fx.read_files!` of the collected files except the project file (the member file), in the sorted order, in one call. No call when the list is empty. | The project file is not read: its text is the candidate text from `Locked.edit` (in memory). A read that fails is an `Environment` failure. |
| 4 | `Rebase.files({ files: <the others, then the candidate header as { path: <file name>, text }>, glob: "**/*.roc", from: <dir of the member file>, to: <copy> })` | Pure |
| 5 | One `fx.write_atomic!`: the candidate header first (the changed text from `Rebase.files`, or the text of `Locked.edit`), then each other changed file in the sorted order | The write of the header is always there (as today), so the call is still one call |
| Then | `fx.probes!`, as today | |

So each ladder case has one new line `list_dirs <copy>` (the other calls do not change when the copy has only the project file), and `in1-flow` has the walk of 2 levels, one `read_files` and the 3 files in the `write_atomic` line.

## Tests

| Layer | File | Case | Rules |
| --- | --- | --- | --- |
| L0 | `probe.roc` expect 1 | The row `exit 134` is `NoFact("no result (exit 134)")` (it was `Crash`). The rows 139, 137 stay. | R-RC4, R-P3 |
| L0 | `rebase.roc` 1 | `glob_match`: 26 rows (a name, `*`, `?`, `**`, `**/`, the empty glob) | R-LD4 |
| L0 | `rebase.roc` 2 | `path`: 15 rows (absolute, inside, out of the app dir, out and in again, a whole segment, a file in `sub/`) | R-LD4, R-H7 |
| L0 | `rebase.roc` 3 | `embeds`: 4 import lines of one text (out, in, out and in, absolute), `import pf.Stdout`, an indented line, a comment, a string that holds `import`; a file in `sub/`; no import; no end of line | R-LD4, R-H1 |
| L0 | `rebase.roc` 4 | `files`: a header with a platform path entry, 3 path entries (out, in, out and in), a URL entry, the pin, a comment, an import file; 3 globs; a file in `sub/`; a module with an import file; a module with an import file that stays; a file that is no `.roc`; a header with no change | R-LD4, R-H1, R-H7 |
| L2 | `install/in1-flow` | 5 runs (4 old, 1 new). Run 1 to 3 (app): the header in the copy has `local: "$PROJECT/lib/main.roc"` (out of the app dir) and `inner: "./inner/main.roc"` (in the app dir, not changed). The module `Helpers.roc` has the embeds `import "../data/notes.txt"` (becomes `$PROJECT/data/notes.txt`) and `import "inner/data.json"` (stays). The module `inner/Deep.roc` (a subdir, 2 levels in the walk) has `import "../../data/deep.txt"` (becomes `$PROJECT/data/deep.txt`) and `import "data.json"` (stays). The log has the walk, the read and the write of the 3 files. The first read of a package for a new name is the newest release. Run 4 (package). Run 5: `add acme/lex --no-check --json`: `check` and `build` are `skipped`, `probes` 0, `pinned` null, no ladder call. | R-LD4, R-H7, R-AD32, R-AD33, R-LF3, R-BL6, R-J3 |
| L2 | `ladder/ld-ladder-flow` and 5 `resolve/rs-*` cases | `calls.log`: the new line `list_dirs <copy>` after each `copy_tree` (17 lines in 6 cases, no other change) | R-LD4 |

## Old cases that changed

| Case | Change | Why |
| --- | --- | --- |
| `install/in1-flow` | `calls.log`: the read of the kind of a new name is the newest release (`FaSAC...` for util, `7r2t7...` for lex) in run 1, 2 and 4. The pick does not read it again (the header of the newest candidate is a start fact of the pick), so run 4 has 3 calls less (`random`, `list_dirs`, `read_files` of `GuxBH...`) and runs 1 and 2 lose one path in the second `read_files`. | C2 of slice 007 (D6) |
| `install/in1-flow` | New entry `inner: "./inner/main.roc"` in `given/project/app/main.roc` and the file `inner/main.roc`. The lines `copy-entries inner/ main.roc` and the header text in `calls.log`, and `tree.diff`, have it. | Q4: a path in the app dir is not changed. The slice 006 code made it `$PROJECT/app/inner/main.roc`. That is a wrong identity: an error in that module is `App(inner/x.roc)` in the baseline and `App(<absolute path>)` in the candidate, so `Probe.compare` calls it new. |
| 6 cases (`ladder/ld-ladder-flow`, `resolve/rs-highest-use`, `rs-install-add-key`, `rs-new-toml`, `rs-update-scope`, `rs-workspace-shared-group`) | `calls.log`: one new line `list_dirs <copy>` after each `copy_tree` (17 lines). Nothing else. | Q1: the ladder walks the copy |
| `install/in1-flow` | New modules `Helpers.roc` and `inner/Deep.roc` in `given/project/app/`: `calls.log` has `list_dirs` of the copy and of `inner`, one `read_files`, the `write_atomic` of 3 files, `copy-entries Helpers.roc inner/ main.roc`, and the lines `~ <path>: <import line>` | Q1 |
| `install/in1-flow` | Run 5, `stdout` and `stderr` (the human lines go to stderr with `--json`, D4 of slice 007), `exit`, `calls.log`, `tree.diff` (the new entry in `lib/main.roc`) | M1 |

The new `expect/` was made with a private reference (`UPDATE=1`), and then each changed line was read. No other L2 or L3 case fixes the old choice of C2: all other cases pass with the reference.

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Options rejected |
| --- | --- | --- |
| D1 (changed by the review) | `Rebase` is pure (part A). The walk of the copy is a short function in `Ladder` (`roc_files_of!`, command code) that uses the `Fx` fields that exist: `list_dirs!`, `read_files!`, `write_atomic!`. No new `Fx` field, so no new L3 row. The project file is not read from the copy: its text is in memory, and it is written in the same `write_atomic!` call as the changed files. | A new `Fx` field (`walk!`): not needed. A write of the header first and a second write after the walk: one more call for each member. |
| D9 | The walk is one `list_dirs!` call for each level (all the dirs of a level in one call, TW3). The paths are sorted with `Text.sorted` (TW2: the order of a dir list comes from `Fx`). | One call for each dir |
| D10 | An import line is a line that starts with `import "` at column 0. The file is the text up to the next `"`. | A parse of the Roc source: not needed for a line that `roc fmt` writes at column 0 |
| D2 | A path that stays in the app dir is not changed. A path that leaves it is absolute. | All paths absolute (slice 006 C1): wrong identity of the errors, see "Old cases that changed" |
| D3 | A path that leaves the app dir and comes back (`../app/x.roc`) is the place in the copy (`to` plus the rest). The prefix `from` changes to `to`. This is the "prefix to prefix" rewrite of the answer of the user. | The original place (the errors of the copy would have the other identity than the errors of the baseline) |
| D4 | The glob has `*`, `?`, `**`, `**/` and no other special character (no `[a-z]`, no `{a,b}`, no `!`). `*` also matches a name that starts with a dot. | A full glob library. Not needed: the design names no glob. |
| D5 | `files` gives only the changed files, in the order of the input. | All matching files |
| D6 | The kind comes from the candidate with the highest `published_at` of the URL form (the same rule as `Index.new_entry`). | The highest version (the design says "newest", and R-NS1 orders by date) |
| D7 | The test of M1 is run 5 of `install/in1-flow` (L2), with a package member (`lib/main.roc`). The run has no probe call, so the hooks of the runs 2 and 3 are not affected. | A run in L3 `add/ad2` (the L2 case already has the `--json` path and the log of the calls) |
| D8 | `build` is `skipped` with `--no-check` (the code of slice 007 does so: `Ran.build` is `Skipped`). R-BL6 says the step 3 is skipped too. | `build` null (`NotRun`) |

## Output (proposed, R-OUT2)

| Output | Text | Where |
| --- | --- | --- |
| `--no-check --json` | `data.check` is `"skipped"`, `data.build` is `"skipped"`, `data.probes` is 0, `data.pinned` is null. The key order is the one of slice 007. | stdout (`expect/stdout`, run 5) |
| `--no-check` (human) | `check: skipped`, then the plan lines, then `resolved at <time>, 0 probes` | stderr with `--json` |

## Out of scope

| Item | Reason |
| --- | --- |
| A string in a `.roc` file that is a path but not a header entry and not an `import "<file>"` line | The design names none. Roc has no other file reference in source. |
| An `import "<file>"` line that is not at column 0 | `roc fmt` writes imports at column 0 (D10) |
| R-LD2, R-LD3, the other items of slice 006 "Out of scope" | Unchanged |

## Questions (TW17)

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Does the ladder rewrite the `import "<file>"` strings too (a design gap in R-LD4)? | Yes. The manager answered on 2026-10-20 (see "Review (manager, 2026-10-20)"). The test agent changed the tests. No open question. |

## Next step

Human review of the tests. Then the code agent writes: `Probe.is_fault_exit`, the 4 bodies of `Rebase`, `Ladder.probe_in_copy!` (the walk, the read, one `write_atomic!`, and `Rebase.files`; `candidate_text` goes away), and the choice of the newest candidate in `Resolve.prepare!`. It does not edit a test (TW18). The code agent also changes the words in the docs: `Probe.roc:61` (128 plus a signal), `Resolve.roc:800` ("first candidate"), and `Ladder.roc:154` (step 3: the table of `run!`: the walk, the read, the write, and `Rebase` in place of "made absolute first").

## Verify and red output

Revert check (TW12): `research/slice-006b-revert/mutate.py`, rows in `research/slice-006b-revert/results.md`. 31 changes of a private reference, 31 caught (T4 first not: a row was added, then caught). The reference was deleted: `cli/lib/` has the stubs, and the files that the reference changed were put back (checked with `diff` against copies that were made before).

Red output of `scripts/test.sh` on the stubs (2026-10-20). The old tests pass. `check`, `fmt`, `l3` and `selftest` pass.

| Step | Result | Detail |
| --- | --- | --- |
| check | pass (3.7 s) | All files compile. No warning. |
| fmt | pass (0.1 s) | |
| l0 | FAIL (8.2 s) | `probe.roc`: 1 of 3 `expect`s fails (the value of the row exit 134: `Crash` and not `NoFact`). `rebase.roc`: 4 of 4 fail with `todo`. All other files pass. |
| l2 | FAIL (39.7 s): 17 passed, 7 failed | `install/in1-flow` and 6 ladder cases (`ladder/ld-ladder-flow`, `resolve/rs-highest-use`, `rs-install-add-key`, `rs-new-toml`, `rs-update-scope`, `rs-workspace-shared-group`): only `Fx calls` differs (the new `list_dirs` lines, the walk, the embeds, the header path entry, the oldest release read first). |
| l3 | pass (9.3 s) | |
| selftest | pass (5.9 s) | |

## Review (manager, 2026-10-20)

D1 to D8 are accepted, with one change that comes from Q1.

| # | Answer |
| --- | --- |
| Q1 | Yes. The user asked for a util that rewrites paths "in the subdirectory by glob from one prefix to another", so the rewrite covers all `.roc` files of the copy, not only the header. A false exit 11 from an embed `import "../data.json" as d : Str` is a real failure. The glob is `**/*.roc` (one constant in the ladder). `Rebase` gets a pure function for the `import "<file>"` strings (`Rebase.embeds`, the rule of D2 and D3). The ladder walks the copy with the `Fx` fields that exist. D1 changes to match: a pure `Rebase`, plus a short walk in `Ladder.run!`. |
| Test change | L0 rows for the import strings (`rebase.roc` 3 and 4). In `install/in1-flow` one module in the app has an embed that leaves the app dir and one that stays, and a module in a subdir has the same. The expected files and the call log are changed. 6 other ladder cases get one new log line. |

## Review of the tests (manager, 2026-10-20)

Accepted: D1 to D10, the walk with no new `Fx` field, and the 17 new `list_dirs` lines in 6 old L2 cases. Status: code.

## Verify results (code agent, 2026-10-20)

`scripts/test.sh` exit 0: check 4.3 s, fmt 0.1 s, l0 7.3 s, l2 41.0 s (24 cases), l3 9.1 s, selftest 5.8 s. No test was changed (no dispute rows).

Revert check of the code (`research/slice-006b-revert/code-mutate.py`, `code-results.md`): 26 of 27 caught. `cli/` was compared with a copy from before the run: no difference.

| Id | Mutation | Result |
| --- | --- | --- |
| C3 | `Resolve.newest`: a tie takes the last candidate (`>=` in place of `>`) | Not caught. No L2 case has a tie of `published_at`. The rule is tested only in L0 `index` (`Index.new_entry`). Gap for the test agent. |

Code files: `cli/lib/Probe.roc` (`is_fault_exit`, doc row), `cli/lib/Rebase.roc` (198 lines, 4 bodies and helpers), `cli/lib/Ladder.roc` (`rebased_files!`, `roc_files_of!`, `roc_glob`; `candidate_text` removed; doc of `run!` step 3), `cli/lib/Resolve.roc` (`newest`, doc of `prepare!`).

## Review of the code (manager, 2026-10-20)

`scripts/test.sh` passes (manager run). The revert check of the code caught 26 of 27. The decisions of the code agent are accepted. C3 (the tie rule of `Resolve.newest`) is accepted as not caught: `Resolve.newest` uses the same rule as `Index.new_entry`, which L0 `index` tests. A later slice can make `Resolve` call one shared function.
