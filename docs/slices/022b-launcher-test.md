# 022b Launcher test

Phase: P1. Status: done

Slice 022b makes rank 7 of Resolution 13 true to R-SO9: the first `roc` on `PATH` that is not the Talon launcher, the launcher test (same size and same sha256 as the running `tln`), the cache `talon/path-roc.json` (each file is hashed once, `roc version` runs once for each binary), and the id from `Roc compiler version <id>`. Today (P0) the `tln` commands run `programs!(["roc"])` and `roc version` by name at each run. It is split from slice 022 (TW19). Follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-022b-revert/before/` (with `NEW.txt`).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-SO9 (the launcher is a file with the size and the sha256 of the running `tln`. The first other `roc` on `PATH` is rank 7.) | `PathRoc.step`, `Fx.path_roc!`, `Install.on_path!` | L0 `step`, `walk`. L2 `roc/so9-launcher`. L3 `compilers/so9-launcher`, `fx/so9-real-fx-path-roc` |
| R-SO9 (each file is hashed once, `roc version` runs once for each binary, also when it gives no id (`NoId`), the key is the path, the size and the mtime) | `PathRoc.step`, `add_sha`, `finish` | L0 `step`, `walk`, `add_sha`, `finish`. L2 run 2. L3 runs 2, 3, 8 and 9 |
| R-SO9 (the id is the text after `Roc compiler version`) | `PathRoc.finish` (uses `Compiler.version_id`) | L0 `finish`. L3 |
| R-SO10 (a nightly or a release on `PATH` is an installed compiler) | `PathRoc.finish`, `PathRoc.step` (`Done`) | L0 `finish`. The ranks of slice 022 do the rest. |
| R-SO11 (another id, for example `debug-<sha>`, is a local build) | `PathRoc.finish`, `PathRoc.step` | L0 `step`, `finish` |
| R-TF1 (`path-roc.json` has an integer `format`) | `PathRoc.write`, `PathRoc.read` | L0 `write`, `read`. L3 |
| R-TF2 (a field that Talon does not know stays when Talon writes the file: the top fields and the fields of a kept row) | `PathRoc.read`, `write`, `add_sha`, `finish`, `save` | L0 `read`, `write`, `add_sha`, `finish`, `save`. L3 run 8 |
| R-TF3 (a newer `format`: the file is ignored and never written) | `PathRoc.read`, `PathRoc.save` | L0 `read`, `save`. L3 run 5 |
| R-TF6 (a file with content that does not parse: a warning, and Talon makes it again) | `PathRoc.read`, `PathRoc.save`, `PathRoc.warning` | L0 `read`, `save`, `warning`. L3 run 6 |

Rank 7 and its gate (R-SO7, R-SO19, R-PH6) are in slice 022, and they do not change.

## 2. Does selection read `TALON_IN_PROXY` now?

No. R-EV17 says: a proxy that sees `TALON_IN_PROXY` does not use rank 7. A `tln` command is not a proxy, and the proxy is slice 023. So `TALON_IN_PROXY` (the variable, the proxy that sets it for the compiler that it runs, and the proxy that reads it) is in slice 023. The R-SO9 text about an old copy of a launcher is tested here only in the part that selection needs: a file with the size of `tln` and other bytes is not the launcher, so it is the compiler (L0 `step`, L3 run 1).

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/PathRoc.roc` | 98 (new) | Stubs | Types, 7 functions, each `crash "todo"`. Exposed in `cli/lib/main.roc` (+1). |
| `cli/lib/Fx.roc` | 210 (+11) | Test agent | New field `path_roc!` and its method, with the doc |
| `cli/RealFx.roc` | 777 (+5) | Stub | The field is wired, the body is `crash "todo"` |
| `cli/fxprobe.roc` | 272 (+15) | Test agent (test tool) | New call `path-roc` |
| `tests/commands/FakeFx.roc` | 699 (+20) | Test agent | `path_roc!` (the file `fx/path-roc`) |
| `tests/lib.sh` | 74 (+0) | Test agent | `tree_diff` leaves out `path-roc.json` (D6) |
| `tests/unit/pathroc.roc` | 272 (new) | Test agent | 7 `expect`s |
| `tests/commands/cases/roc/so9-launcher/` | 1 case | Test agent | L2, 2 runs |
| `tests/scenarios/compilers/so9-launcher/` | 1 case | Test agent | L3, 9 runs |
| `tests/scenarios/fx/so9-real-fx-path-roc/` | 1 case | Test agent | L3, the real `Fx` job |
| 12 old L2 cases | `fx/path-roc` and `expect/calls.log` | Test agent | See section 6 |
| 8 old L3 cases | `expect/roc.log` (7), `expect/stdout` (1) | Test agent | See section 6 |
| `research/slice-022b-revert/` | | Test agent | `before/` (27 copies and `NEW.txt`), `update-old-cases.py` |

`scripts/test.sh` is not changed. `docs/slices/PLAN-P1.md` is not changed.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Fx.path_roc!` | `() => { exe : Try({ path : Str, size : U64, mtime : U64 }, [Unknown]), found : List({ path : Str, size : U64, mtime : U64 }) }` | R-SO9 |
| `PathRoc.File` | `{ path : Str, size : U64, mtime : U64 }` (`mtime` in seconds) | R-SO9 |
| `PathRoc.Entry` | `{ path, size, mtime, sha256 : Try(Str, [None]), id : [NotRun, NoId, Id(Str)], extra : List((Str, JsonDoc)) }` (`NoId`: `roc version` ran and gave no id) | R-SO9, R-TF1, R-TF2 |
| `PathRoc.State` | `[Absent, Good, Newer, Corrupt]` | R-TF3, R-TF6 |
| `PathRoc.read` | `Try(Str, [NotFound, Denied, Other(Str)]) -> { entries : List(Entry), extra : List((Str, JsonDoc)), state : State }` | R-TF1 to R-TF3, R-TF6 |
| `PathRoc.write` | `{ entries : List(Entry), extra : List((Str, JsonDoc)) } -> Str` | R-TF1, R-TF2 |
| `PathRoc.step` | `{ exe : Try(File, [Unknown]), found : List(File), entries : List(Entry) } -> [Hash(File), Version(File), Done(Try(Str, [NoCompiler]))]` | R-SO9 to R-SO11 |
| `PathRoc.add_sha` | `List(Entry), File, Str -> List(Entry)` | R-SO9 |
| `PathRoc.finish` | `{ entries, file : File, text : Str } -> { entries, id : Try(Str, [NoCompiler]) }` | R-SO9 to R-SO11 |
| `PathRoc.save` | `{ state, before : List(Entry), after : List(Entry), extra : List((Str, JsonDoc)) } -> [Skip, Write(Str)]` | R-TF3, R-TF6 |
| `PathRoc.warning` | `{ path : Str, state : State } -> Try(Str, [None])` | R-TF6 |

Command code (not in the stubs, see N1 and N2): `Install.on_path!` gets `Roots` (the path of the cache is `Roots.item(roots, PathRocJson)`), so `Install.compiler!` and its 4 callers (`Install`, `Update`, `Remove`, `Verify`) get `roots` too.

The command code of step 7 loops on `PathRoc.step` (the doc of `cli/lib/PathRoc.roc` has the table). The calls of one run, in order, for a run with a `roc` on `PATH`:

| Case | Calls |
| --- | --- |
| No `roc` file on `PATH` (`found` is `[]`) | `path_roc` |
| The cache has the rows | `path_roc`, `read_files <cache>` |
| The first run (no cache) with a launcher and then a compiler | `path_roc`, `read_files <cache>`, `sha256_file <file>`, `sha256_file <exe>`, one `sha256_file` for each next file of the size of `tln`, `spawn_all limit=1` with `job - <path> version`, `write_atomic <cache>` |

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/pathroc.roc`: `step` (22 rows) | No file. A file of another size than `tln` is never hashed. A row of the cache gives `Done`. A local build id. The key of a row (path, size, mtime) changes. The hash order (file, then `tln`). Equal sha256 is the launcher. Another sha256 with the same size is the compiler. The walk goes on past a launcher, and stops at the first compiler. A row with `NoId` gives `Done(Err(NoCompiler))` with no second run (and a changed mtime runs again). | R-SO9, R-SO10, R-SO11 |
| L0 | same: `walk` | A driver that does what command code does (hash, run `roc version`) over 2 commands: the first hashes the launcher and `tln` and runs one `roc version`, the second has no effect. The same for a binary that is not a compiler: one run, then none. | R-SO9 |
| L0 | same: `add_sha`, `finish` | One row for each path. A row of an older file is replaced with its sha256 and id. The id of a release, a nightly, a local build. A text that is not a version, no output, an empty id: the row gets `NoId`. The unknown fields of a kept row stay. | R-SO9 to R-SO11 |
| L0 | same: `write`, `read`, `save`, `warning` | The text of the file (a round trip, `"id":null`, the unknown top fields and row fields written after the known keys). A newer `format`, bad JSON, a bad row, `id` that is a number or false, unknown fields kept in order. When the cache is written, and the top fields stay. The warning. | R-TF1 to R-TF3, R-TF6 |
| L2 | `roc/so9-launcher` (new, 2 runs) | The calls of 2 `install` runs with `TALON_NIGHTLY=0`. Run 1: `path_roc`, the cache read, the hash of the launcher then of `tln` then of the old copy, one `<path> version`, the write. `later/roc` and `small/roc` are never touched. Run 2: `path_roc` and the cache read only. The gate text names the id of the old copy. | R-SO9, R-SO10, R-TF1 |
| L3 | `compilers/so9-launcher` (new, 9 runs) | The real binary: `a/roc` is a copy of `tln`, `b/roc` has the size of `tln` and other bytes. Run 1: the id of `b/roc` (exit 10, text). Run 2: no new run of `b/roc`. Run 3: a new mtime, `roc version` runs again, one row for the path. Run 4: `b/roc` is gone, the fake `roc` is the compiler (one `version` in `roc.log`). Run 5: a newer `format`, the file is not changed. Run 6: bad JSON, a warning, the file is made again. Run 7: no warning. Run 8: the file gets the top field `note` and the row field `x`, and `c/roc` (a script that prints `not a version`, exit 3) runs once: exit 18, and a write keeps both fields, and the row of `c/roc` has `"id":null`. Run 9: `c/roc` does not run again (the log of `c/roc` has 1 line). | R-SO9, R-SO10, R-TF1, R-TF2, R-TF3, R-TF6 |
| L3 | `fx/so9-real-fx-path-roc` (new) | `fxprobe path-roc`: the running program (path, size, mtime as `stat` gives them). The files named `roc` in the directories of `PATH`, in order: a missing directory, a file that cannot run, a directory named `roc` are left out. A link counts, with the size and the mtime of its target. A `PATH` with no `roc`. | R-SO9, TW4 |

Budget: 7 new L0 `expect`s, 3 deep cases (L2 1, L3 2), no selftest row. The new L3 cases use the real `tln`, the fake `roc` of the runner, and no real `roc` (TW10). Times on the red tree: l0 4.0 s, l2 0.5 s, l3 9.3 s, selftest 19.5 s of 20 s (unchanged).

## 6. Old tests that changed

The compiler step of each run is now the walk of section 4. The result of the old runs is the same, but the calls are not.

| File | Change | Why |
| --- | --- | --- |
| 12 L2 cases: `closure/cl1-flow`, `closure/cl2-chain`, `gaps/g1-slice009`, `install/in1-flow`, `moves/hm1-noninteractive`, `moves/hm2-interactive`, `prompt/nm11-alias-stops`, `remove/rm1-flow`, `update/up1-flow`, `verify/vf1-flow`, `workspace/ws1-closure-keys`, `workspace/ws2-verify-members`: `expect/calls.log` | Each 3 lines `programs roc`, `spawn_all limit=1`, `  job - roc version` become `path_roc`, `read_files $HOME/.cache/roc/talon/path-roc.json`. The first run of a case also has `spawn_all limit=1`, `  job - /fake/bin/roc version` and `write_atomic $HOME/.cache/roc/talon/path-roc.json` (the cache is in the HOME of the case, so only the first run runs `roc version`). 61 runs. | R-SO9 |
| the same 12 cases: `fx/path-roc` (new) | A `tln` of 5000 bytes and a `roc` of 1000 bytes: the sizes differ, so no file is hashed | The fake has no `roc` on `PATH` otherwise |
| 7 L3 cases: `add/ad1-add-entries`, `add/ad2-platform-json`, `compilers/so2-ranks`, `install/in1-workspace-frozen-rename`, `remove/rm1-remove-entries`, `remove/rm2-workspace`, `update/up1-update-entries`: `expect/roc.log` | One `version` line stays in each (the first run). The others are gone: the id is in the cache. | R-SO9 |
| L3 `verify/vf1-verify`: `expect/stdout` | The case prints the sorted `roc.log`: 6 `version` lines became 1 | R-SO9 |
| `tests/lib.sh` | `tree_diff` leaves out `path-roc.json` (D6) | The file has the size and the mtime of files of the machine |

`research/slice-022b-revert/update-old-cases.py` made the first two edits (one time). No expected `stdout`, `stderr` or `tree.diff` of an old L2 case changed.

## 7. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| `path-roc.json` (R-TF1) | One line and a line end: `{"format":1,"files":[{"path":"/usr/bin/roc","size":123,"mtime":1792065600,"sha256":"<hex>","id":"<id>"}]}`. The keys of a row are in this order. `sha256` is left out when the file was not hashed. `id` is left out when `roc version` did not run on it (`NotRun`), is `"id":null` when it ran and gave no id (`NoId`, Q1 of the review), and is the text otherwise. After the known keys come the unknown keys (R-TF2): in a row after `id`, in the top object after `files`, in the order of the file. The rows keep the order in which Talon added them. |
| R-TF6 | stderr: `warning: <cache path>: path-roc.json is not valid. Talon made it again.` |
| Gate text of rank 7 | Not changed (slice 012 and 022). The tests use it to show the id: `the roc on PATH, <id>, is a nightly, and nightly is false (set by <source>). No roc release is known, so no compiler can be selected.` |

## 8. Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | One `Fx` call, `path_roc!`, gives the `roc` files and the running `tln`. It reads no content and runs nothing (TW3, TW4). The size and the mtime come with the path, so the cache key needs no more call. | Two calls (files, and exe). A call that also hashes: it would hash files that the size test can skip. |
| D2 | The size test comes first: a file with another size than `tln` is not hashed. The design says "same size and sha256", so a file with another size is never the launcher. | Hash each file. |
| D3 | `tln` itself has a row in the cache (path, size, mtime, sha256), so it is hashed once, as the other files. The running `tln` changes with an update, and the key (path, size, mtime) then changes. | A flag `launcher` in the row of a file (it would be wrong after an update of `tln`). Hash `tln` at each run. |
| D4 | The walk stops at the first file that is not the launcher. The files after it are not hashed and not run. The order of the 2 hashes: the file, then `tln`. | Look at all files. |
| D5 | `roc version` runs on the path of the file with `spawn_all!` (one job, limit 1), not on the name `roc` (the name finds the launcher first). | The name `roc`. |
| D6 | The runners leave out `path-roc.json` of the tree diff, as `compat.db`. The text of the file is tested in L0 and in the L3 case. | Keep it in the L2 diff (12 old cases with the same file). Fixed `mtime` in L3: the size of the fake `roc` and the mtime of its checkout change. |
| D7 | `path-roc.json` has no lock. R-CC6 lists the files with a lock, and this one is not in the list. R-CC1 (the atomic write) is enough: a lost write only costs one more `roc version`. | A lock `path-roc.json.lock`. |
| D8 | A `Newer` file is not written and not deleted. A `Corrupt` file is written again with the new rows (the atomic write replaces it, so there is no separate `delete`). | A `delete!` call before the write. |
| D9 | The old L2 cases get `fx/path-roc` (a `roc` with another size than `tln`). | Make the fake answer from `fx/programs`. |
| D10 | The row tells 3 cases apart: `NotRun` (no key `id`), `NoId` (`"id":null`), `Id(text)`. A `NoId` row is valid for the same (path, size, mtime) and ends rank 7 with no compiler. (Manager answer Q1.) | Keep no row for a failed run (it runs again at each command). A text `"id":""`. |
| D11 | An unknown field is kept as a `JsonDoc` value in `Entry.extra` and in the top `extra`. It is written after the known keys, in the order of the file. A row that Talon replaces (the file changed) loses its unknown fields. (Manager answer Q4.) | Write the unknown fields before the known keys. Keep them for a replaced row. |

## 9. Out of scope

| Rule or item | Reason |
| --- | --- |
| R-EV17 (`TALON_IN_PROXY`), R-PX2, R-PX7, R-SO8 | Slice 023 (section 2) |
| `roc version` on a file that is an old launcher of another Talon version, with `TALON_IN_PROXY=1` in its environment | `spawn_all!` has no environment. The proxy is slice 023. |
| `roc.exe` and the `;` of a Windows `PATH` | The Windows CI job (R-LY9). L3 runs on Linux and macOS. |
| R-SO12, R-SO13 as downloads | Slice 025 |
| The probes on the compiler that selection chose (`probes!` still runs the name `roc`) | Slice 023 (manager answer Q2 of slice 022) |

## 10. Questions (TW17)

All answered in the review (section 14). Q1 and Q4 changed the tests (D10, D11). The answers of the others are the defaults.

| # | Text | Answer |
| --- | --- | --- |
| Q1 | What Talon keeps when `roc version` fails or prints another text | A row with `"id":null` (`NoId`). It does not run again for the same (path, size, mtime). Rank 7 has no compiler. |
| Q2 | `exe: Err(Unknown)` | `NoCompiler` (not tested) |
| Q3 | A read error or a write error of `path-roc.json` | Read error as `Absent`. Write error: no failure, no output (not tested). |
| Q4 | R-TF2 and the unknown fields on write | Kept (D11) |
| Q5 | Rows of files that are no longer on `PATH` | No prune in this slice (not tested) |

## 11. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `Install.on_path!` becomes `Fx, Roots => Try(Str, [NoCompiler])`, and `Install.compiler!` gets `roots`. Callers: `Install.flow!`, `Update`, `Remove`, `Verify` (each has `start.roots` or `roots` at step 7). Step 7 of the docs of these 4 modules names `programs!` and `roc version`: change the text. |
| N6 | `Install.on_path!` passes `read.extra` to `PathRoc.save`, and a run of `roc version` always goes to `PathRoc.finish` (also a non-zero exit: the stdout is the text, maybe empty), so a failed run has its `NoId` row. A job that cannot start (`NotStarted`) is not a run: no row. |
| N2 | The calls of step 7 are fixed by the calls table of section 4 and by the L2 case `so9-launcher`. A warning of `PathRoc.warning` goes to stderr as `warning: <text>` before the first `Fx` call that follows. The cache is not read when `found` is `[]`. |
| N3 | `RealFx.path_roc!`: split `PATH` on `:`. For each directory `<dir>/roc`: a link counts (resolve it to test the file and to get the size and the mtime). The file must be a file that the user can run. The `path` is the text of `PATH`, not the resolved path. `exe` is `Env.exe_path!` with the same 3 values. On the pinned platform `Path.is_file!` is false for a link, so resolve first (`Path.canonicalize!`). `Path.time_modified!` gives nanoseconds: divide by 1000000000. |
| N4 | `Compiler.on_path` and `Compiler.version_id` stay. `PathRoc.finish` uses them (the doc comment of `Compiler.version_id` that says "P0 keeps no path-roc.json" is old: change it). |
| N5 | `tests/commands/FakeFx.roc` `path_roc!` logs `path_roc`. `sha256_file!` of the fake reads the real bytes of the path, so the L2 case has real files in its dir. |

## 12. Revert check (TW12)

A private reference made all new tests pass. It was deleted after the check (it is not in `research/`). 41 small mutations of it were run one by one, each with only the tests that should catch it. 41 of 41 were caught. One mutation was first not caught (`PathRoc.finish` keeps a row of an older file): a row was added, and it is now caught. Two of the 11 new `PathRoc` mutations (the unknown fields dropped by `add_sha` and by `finish`) are caught by L0 only, as the L2 and L3 cases have no such row.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `PathRoc`, first round: hash order, hash for each size, size only (no sha256 compare), key without mtime, size or path, `add_sha` keeps a stale row, `finish` keeps a stale row, a local id is `Ok`, `save` for `Newer`, `Corrupt` and the same rows, `read` of a newer `format`, `read` of bad JSON, write key order, warning for each state, no id in a read row | 17 | L0 `pathroc` |
| `PathRoc`, after the review: `NoId` row runs again, a bad text leaves no row, `NoId` not written, `"id":null` read as corrupt, the unknown top or row fields dropped by `read`, `write`, `add_sha`, `finish` or `save` | 11 | L0 `pathroc` (all 11). L3 `so9-launcher` caught 9, L2 caught 1. |
| `Install.on_path!`: spawn by name, no write, no read, no warning, always write, `Newer` written, no unknown fields to `save`, a failed run not recorded | 8 | L2 `so9-launcher` (spawn, write, read, always write, failed run), L3 `so9-launcher` (all 8) |
| `RealFx.path_roc!`: no link, a file that cannot run, a directory | 3 | L3 `so9-real-fx-path-roc` |
| `tests/lib.sh`: `path-roc.json` not left out | 1 | L2 `in1-flow`, `so9-launcher`, L3 `so9-launcher` |
| `PathRoc.step`: hash each size (in the code of the walk) | 1 | L0 `pathroc`, L2 `so9-launcher` |

## 13. State on the stub tree (red)

`scripts/test.sh`: check pass (all files compile), fmt pass. l0: `pathroc` fails (7 failed: `crash "todo"`), the other 51 files pass. l2: 26 passed, 13 failed (the 12 old cases of section 6 with the old calls, and `so9-launcher`). l3: 24 passed, 10 failed (the 7 old `roc.log` cases and `vf1-verify` with the old `version` lines, `so9-launcher` with exit 18 in place of 10 and no cache file, `so9-real-fx-path-roc` with the crash `todo` of `path_roc!`), 1 skipped. selftest: pass (19.5 s of 20 s). With the reference (deleted) all steps passed (L0 7 of 7, L2 39 of 39, L3 34 of 34 with 1 skipped).

Fail output (excerpts, the first lines of each):

```text
tests/unit/pathroc.roc: FAILED   Roc application crashed with this message:  todo     (7 failed)
FAIL roc/so9-launcher            stdout differs: -exit 10 / +exit 18 (the old code finds no roc: no fx/programs file)
FAIL install/in1-flow            Fx calls differs: -path_roc / -read_files $HOME/.cache/roc/talon/path-roc.json / +programs roc / +spawn_all limit=1 / +  job - roc version
FAIL verify/vf1-verify           stdout differs: -version (5 lines) that the old code still prints
FAIL compilers/so9-launcher      stdout differs: -exit 10 / +exit 18, and the cmd stops at the first `rows` (no cache file): exit code 1
FAIL fx/so9-real-fx-path-roc     stdout differs: the lines "exe matches" and "file $PROJECT/d2/roc 10 1700000000" are missing (the call crashes with todo)
```

## 14. Review (manager, 2026-10-22)

D1 to D9 and the proposals of section 7 are accepted. Q2, Q3, Q5 and the design gap: the defaults are accepted. Two changes:

| # | Text | Done |
| --- | --- | --- |
| Q4 | Not a question: R-TF2 (`DESIGN-CLI.md:804`) says Talon keeps a field it does not know when it writes the file. `PathRoc` must keep the unknown top-level fields, and the unknown fields of a row that it keeps. Add L0 rows (R-TF2). | `Entry.extra`, `read` and `write` with `extra`, `save` with `extra`, D11. L0 rows in `read`, `write`, `add_sha`, `finish`, `save`. L3 run 8. |
| Q1 | R-SO9 says `roc version` runs once for each binary. When it fails or prints another text, Talon keeps the row and marks that the run happened with no id. It does not run again for the same (path, size, mtime). The row tells "not run" from "ran, no id" apart. Rank 7 then gives no compiler. Add L0 rows and, if cheap, one L2 or L3 run. | `Entry.id` is `[NotRun, NoId, Id(Str)]`, `"id":null` for `NoId` (section 7, D10). L0 rows in `step`, `walk`, `finish`, `read`, `write`. L3 runs 8 and 9. |

Status: code.

## Code result (code agent, 2026-10-23)

`scripts/test.sh` exits 0: check 6.8 s, fmt 0.1 s, l0 4.1 s (all files pass, `pathroc` 7 of 7), l2 39 passed 0.5 s, l3 34 passed and 1 skipped 9.3 s, selftest pass 19.5 s. `OPT=speed scripts/test.sh` also exits 0.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/PathRoc.roc` | 271 | The 7 functions, with the private helpers `read_object`, `read_row`, `row_doc`, `upsert`, `walk`, `compiler_step`, `usable`, `same_rows` |
| `cli/lib/Install.roc` | 258 | `on_path!` is `Fx, Roots => Try(Str, [NoCompiler])` (the loop of `PathRoc.step`), `compiler!` gets `roots`. Doc of step 7 changed. |
| `cli/lib/Remove.roc`, `Verify.roc`, `Update.roc` | | `Install.compiler!(fx, start.roots, Bool.False)`. The doc of step 7 or 8 names `Install.on_path!` and R-SO9. |
| `cli/lib/Compiler.roc` | 233 | The doc of `version_id` no longer says "P0 keeps no `path-roc.json`" (N4) |
| `cli/RealFx.roc` | 181 (was 777) | The `Fx` record, `make!`, and the small calls (`cwd!`, `tty!`, `ask!`, `http_get!`, `programs!`, `rename!`, `make_dirs!`, `platform!`) |
| `cli/RealBase.roc` | 28 (new) | `env_all!`, `clock!`, `draw!`, `file_err` (used by the other modules) |
| `cli/RealFiles.roc` | 256 (new) | `read_files!`, `write_atomic!`, `list_dirs!`, `delete!`, `canonical!`, `copy_tree!`, `sha256_file!`, and the new `path_roc!` |
| `cli/RealLocks.roc` | 180 (new) | `take_lock!`, `release_lock!`, `heartbeat!` and the registry |
| `cli/RealJobs.roc` | 209 (new) | `run_jobs!`, `probes!` |

The split of `RealFx` is by group of `Fx` calls. The code moved as it was (the copy before the split is `research/slice-022b-revert/before-realfx/RealFx.roc.pre-split`). A module that was a top-level function is now a method of a type module, and a call to another group is `RealBase.x!`, `RealLocks.heartbeat!`. The signatures of `Fx` did not change. `RealFx` has no Talon logic (TW4).

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| D12 | A `sha256_file!` that fails (`NotFound`, `Denied`) ends the walk with `Err(NoCompiler)`. No row is made, so the next run tries again. The design has no rule for it. | Count the file as not the launcher (the compiler): `roc version` would run on a file that cannot be read. |
| D13 | `RealFiles.path_roc!` skips an empty part of `PATH`, splits on `:` only (Windows is out of scope), and gives `exe` the resolved path of `Env.exe_path!` (`Path.canonicalize!`, else the path as it is). The size and the mtime come from the resolved file (`Path.size_in_bytes!`, `Path.time_modified!`). | Read the file with `Path.is_file!` on the link (false on the pinned platform). |
| D14 | `PathRoc.read` takes `format` below 1 (0, negative) as `Corrupt`, and `"id":""` as `Corrupt`. | `Id("")` (it would give the id `""` as a compiler). |
| D15 | `PathRoc.same_rows` (the `save` test) compares as sets by length and by `contains` in both ways. | Compare as lists (a new order would write). |
| D16 | `Compiler.on_path` stays and is tested, but command code does not call it any more (`PathRoc.usable` maps an id the same way: a local build is `Err(NoCompiler)`). | Call `Compiler.on_path` from `PathRoc.finish` (it takes the stdout of a `Try`, the other `Err(NoRoc)` case has no meaning here). |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

## Verify results (code agent, TW12)

37 small mutations (`research/slice-022b-revert/code-mutate.py`, results in `code-results.md`, a copy of the final code in `code-final/`). Caught 35 of 37. The files are the same as `code-final/` after the run (SAME).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `PathRoc` (hash order, size test, sha256 compare, the 3 parts of the key, `NoId`, local build, stale row, 2 rows for a path, unknown fields in `add_sha`, `finish`, `read`, `write`, key order, `NoId` write, `Newer`, `Corrupt`, same rows, warning) | 24 | L0 `pathroc` (24 of 24) |
| `Install.on_path!` (spawn by name, no write, no read, no warning, top fields lost, failed run, `found` empty, failed hash) | 8 | L2 `so9-launcher` (3), L3 `so9-launcher` (3). Not caught: I7, I8 |
| `RealFiles.path_roc!` (no link resolve, a file that cannot run, a directory, mtime unit, `PATH` order) | 5 | L3 `fx/so9-real-fx-path-roc` (5 of 5) |

| Not caught | Test gap |
| --- | --- |
| I7: `Install.on_path!` reads the cache when `found` is `[]` | No L2 case has a run with no `roc` on `PATH`. The first row of the calls table (section 4) and N2 say that only `path_roc` is called. |
| I8: a failed `sha256_file!` does not end the walk | No test has a failing `sha256_file`. The design gives no rule (D12). |

## Gap rows and selftest speed (test agent)

Tests and test tooling only. No file of `cli/` changed. The pre-change copies are in `research/slice-022b-revert/before/` (`tests/selftest.sh`, `tests/unit/compiler.roc`), and the 2 new cases are in `NEW.txt`.

### 1. Gap rows I7 and I8

| Gap | New L2 case | What it fixes | Rules |
| --- | --- | --- | --- |
| I7 | `tests/commands/cases/roc/so9-no-roc` (1 run of `install`, no `fx/path-roc`) | No `roc` file on `PATH`: the only call of the compiler step is `path_roc` (line 15 of `calls.log`), the cache is not read, and the run ends with exit 18 (R-SO14, the text of `rs-no-compiler`) | R-SO9, R-SO14, N2 |
| I8 | `tests/commands/cases/roc/so9-hash-fails` (2 runs, `fx/path-roc` has a file of the size of `tln` that does not exist, then a compiler) | `sha256_file!` gives `NotFound`: the walk ends with no compiler (exit 18). The second file is never hashed and never run. There is no `write_atomic` of `path-roc.json`, so the second run makes the same 3 calls again (D12) | R-SO9, D12 |

Each mutation of `research/slice-022b-revert/code-mutate.py` was applied by hand to `cli/lib/Install.roc`, the new cases were run, and the file was put back (`cmp` against `code-final/cli/lib/Install.roc`: same).

| Mutation | Result |
| --- | --- |
| I7: the cache is read when `found` is `[]` | `roc/so9-no-roc` fails (the extra `read_files` line) |
| I8: a failed `sha256_file!` does not end the walk | `roc/so9-hash-fails` fails |

### 2. D16: `Compiler.on_path` is dead code

The 5 rows `paths` of the first `expect` of `tests/unit/compiler.roc` (and `bad_paths`) are removed, and its comment says that the mapping to `NoCompiler` is tested in `tests/unit/pathroc.roc` (`step`, `finish`: a local build id, a text that is not a version). The rows of `Compiler.version_id` and `Compiler.kind` stay. The manager removes the function `Compiler.on_path`. No other test names it.

### 3. Selftest speed (TW26)

The step took 19.5 s on my last runs and 20.5 s on the run of the code agent, over its budget of 20 s. The rows wait for sleeps of the fake `roc` and for process starts, so they use little CPU. Where the time went (one run, in seconds):

| Group of rows | s |
| --- | --- |
| `l0 in parallel` (52 files, `FAKE_ROC_SLEEP=0.2`) | 3.4 |
| `check in parallel`, 2 runs of `test.sh check` | 3.8 |
| budget rows (`bud-slow`, `bud-ok`, `bud-total`) and the `OPT=speed` budget rows | 2.1 + 1.4 |
| `OPT` runs dev, speed, bad (3 runs of 3 scripts) and the budget column row | 1.9 |
| L3 pass cases (9 cases) | 1.8 |
| 14 L3 cases that must fail (each starts `tests/run.sh`) | 3.0 |
| the other rows (L2, update, slow, net, CI, `get-roc`) | 2.1 |

The change (in `tests/selftest.sh`): each group of rows is a function that runs in a background subshell (`sec <name> <function>`). `ok` and `bad` write to a file for the group, the text of a group goes to its own file, and the report at the end prints the files and the count. Each group has its own `TMPDIR`, so the case dirs of the runners do not meet. The 14 rows `fl3` and the 2 `check` runs are each a group. No row was removed or changed: the count is still 42, and a failing row still prints `SELFTEST FAIL: ...` with its output and gives exit 1 (checked with a changed needle).

| Run | selftest step (s) | Whole `scripts/test.sh` |
| --- | --- | --- |
| Before (budget 20) | 19.5 to 20.5 | WARN on the code agent run |
| After | 3.5 (2 runs: 3.5, 3.5) | exit 0, no `WARN` |

State: `scripts/test.sh` exits 0 with no `WARN` (check 6.7 s, fmt 0.1 s, l0 4.1 s, l2 0.5 s, l3 9.2 s, selftest 3.5 s).

## Close (manager, 2026-10-23)

D12 to D16 are accepted. The manager removed the dead `Compiler.on_path` (D16). `scripts/test.sh` exits 0 with no WARN. Status: done.
