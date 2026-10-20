# 008 `tln remove`

Phase: P0. Status: done done (verify results below)

This slice builds `tln remove` (also `rm`). It is the first scope of 007b in the file of slice 007, with the manager answers Q1 and Q5 below. The scope agent and the test agent are one agent. The code agent writes the bodies (TW18). A private reference implementation made the tests pass and was used for the revert check. It was deleted after the check: `cli/` has the stubs (`crash "todo"`) and the docs, and no reference code.

A remove changes one header entry, and the keys of that alias in `talon.toml`. It resolves nothing: no index call, no pick, no fetch. It has 3 parts that are new: the lexical import scan (R-RV2), the removal of the `talon.toml` keys (R-CM3, R-RV4), and the flow of `remove` (`Resolve.remove!`, `Remove.run!`).

## Answers of the manager that this slice uses (2026-10-20)

| # | Answer |
| --- | --- |
| Q1 of slice 007 (R-H4 and R-RV5) | R-RV5 wins for `remove` only: `Locked.edit` gets a `Remove` that works for a path row and a foreign row (`Set` still refuses them). |
| Q5 of slice 007 (the file of a local module for the import scan) | `import Foo` is `<project dir>/Foo.roc`. `import A/B` is `<project dir>/A/B.roc`. `./X` and `../X` are relative to the importing file. |

## Rules of the slice

| Group | Ids | Where the test is |
| --- | --- | --- |
| Command | R-CM3, R-CM19 (`rm` is `remove`) | L0 `removal`, L3 `remove/rm1`, L2 `remove/rm1-flow` |
| `remove` | R-RV1 (header entry, `talon.toml` key, `[overrides]` entry, whole-app check and build, `--no-check`, no write on a new error, exit 11 for an app file, exit 10 for a package with the text of `--no-check`) | L3 `rm1`, L2 `rm1-flow` runs 1 to 4 |
| | R-RV2 (an imported entry: exit 11 and the import lines; `--force`) | L0 `scan`, L3 `rm1`, L2 `rm1-flow` runs 5 and 6 |
| | R-RV3 (the platform: exit 2) | L0 `removal`, L3 `rm1` |
| | R-RV4 (the `[patch]` entry goes, the files stay, their dir is printed) | L0 `removal`, `intent`, L3 `rm1` |
| | R-RV5 (a path entry or a foreign URL is removed, no `talon.toml` key) | L0 `locked`, `removal`, L3 `rm1` |
| Workspace | R-WS12 (`remove` part: the current member, no current member is exit 2 with the members, `--file`), R-WS14 (the key is in the nearest `talon.toml`) | L3 `rm2` |
| Scan | R-LD7 (a package or a platform starts at each exposed module) | L0 `scan`, L2 `rm1-flow` run 5 |
| Flags | R-FL4 (`--quiet`), R-FL5, R-FL10, R-FL12, R-FL13 (`remove --frozen` is exit 2), R-LF3 (`--no-check`), R-LF4 (`--dry-run`) | L0 `removal`, L3 `rm1` |
| Output | R-J1 to R-J5, R-OUT4, R-OUT5, R-EC2, R-EC10, R-EC11, R-EC17 | L0 `report`, L3, L2 |
| Flow | R-PD9, R-CC1, R-CC7, R-SO7, R-OV1, R-SC1, R-SC6, R-SC7, R-H1 | L3, L2 |

`MISSING=1 scripts/rules.sh R-RV R-CM` lists no R-RV and no R-CM3 and R-CM19 id any more (the other R-CM ids are other slices).

## Files

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Scan.roc` | 47 | New. `Source`, `Hit`, `roots`, `local_file`, `level`. Stubs. The doc has the table of the file of an import. |
| `cli/lib/Removal.roc` | 53 | New. `Opts`, `opts`, `Table`, `What`, `Plan`, `plan`. Stubs. |
| `cli/lib/Remove.roc` | 29 | New. `Remove.run! : Fx, Args => I32`. Stub. The doc has the table of steps and the output rules. |
| `cli/lib/Resolve.roc` | 1262 | New stub `remove! : Fx, Request, { names, force } => Try(Report.RemoveOutcome, Fail)`. The doc has the table of 10 steps. Nothing else changed. |
| `cli/lib/Intent.roc` | 411 | New `Table`, and stubs `remove`, `table_spans`. |
| `cli/lib/Report.roc` | 158 | New `Removed`, `RemoveOutcome`, and the stub `remove_data`. |
| `cli/lib/Locked.roc` | 162 | The doc only: `Remove` works for a path row and a foreign row (R-RV5). The body is not changed (the code agent changes `apply_op`, the `Remove` branch). |
| `cli/lib/Run.roc` | 92 | `remove` calls `Remove.run!` (as `install` calls `Install.run!`). |
| `cli/lib/main.roc` | 68 | Exposes `Removal`, `Remove`, `Scan`. |
| `tests/unit/scan.roc`, `removal.roc` | 85, 101 | New. 2 + 2 `expect`s. |
| `tests/unit/intent.roc`, `report.roc` | 289, 124 | 1 new `expect` each (`Intent.remove` with `table_spans`, `Report.remove_data`). |
| `tests/unit/locked.roc` | 167 | Old test changed (see "Old tests that changed"). |
| `tests/scenarios/remove/rm1-remove-entries`, `rm2-workspace` | 30, 9 (lines of `cmd`) | New L3 cases. |
| `tests/commands/cases/remove/rm1-flow` | 6 runs | New L2 case (entry `commands`). |
| `research/slice-008-revert/` | 150, 84 | `mutate.py` and `results.md`: the record of the revert check. |

No change in the harness (`tests/commands/FakeFx.roc`, `main.roc`, `tests/run.sh`, `tests/lib.sh`, the fixtures of `tests/fixtures/`): the cases use the fake `probes`, the `hooks` and the real check outputs of slice 006.

## Public signatures (stubs)

| Module | Signature | Body |
| --- | --- | --- |
| `Scan` | `Source : { path : Str, text : Str }`, `Hit : { file : Str, line : U64, text : Str }` | |
| `Scan` | `roots : { kind : [App, Package, Platform], file : Str, exposed : List(Str) } -> List(Str)` | `crash "todo"` |
| `Scan` | `local_file : { project_dir : Str, file : Str, name : Str } -> Str` | `crash "todo"` |
| `Scan` | `level : { alias : Str, project_dir : Str, sources : List(Source), seen : List(Str) } -> { hits : List(Hit), next : List(Str) }` | `crash "todo"` |
| `Removal` | `Opts : { names : List(Str), force : Bool, dry_run : Bool, no_check : Bool }`, `opts : Args -> Try(Opts, Fail)` | `crash "todo"` |
| `Removal` | `Plan : { what : What, keys : List({ table : Table, key : Str }), patch_dir : Try(Str, [None]) }` (`What : [Release({ name, version }), Path(Str), Foreign(Str)]`, `Table : Intent.Table`) | |
| `Removal` | `plan : { alias : Str, rows : List(Locked.Row), toml : Try({ path : Str, text : Str }, [NoToml]), shared : Bool } -> Try(Plan, Fail)` | `crash "todo"` |
| `Intent` | `Table : [Dependencies, Overrides, Patch]` | |
| `Intent` | `remove : { path : Str, text : Str, keys : List({ table : Table, key : Str }) } -> Try(Str, Fail)` | `crash "todo"` |
| `Intent` | `table_spans : { text : Str, keys : List({ table : Table, key : Str }) } -> List(Str)` | `crash "todo"` |
| `Report` | `Removed : { alias, kind : [Release, Path, Foreign], name, version : Try(Str, [None]) }`, `RemoveOutcome : { probes, dry_run, check, build, removed, toml, patches, pinned, notes, written }` | |
| `Report` | `remove_data : RemoveOutcome -> JsonDoc` | `crash "todo"` |
| `Resolve` | `remove! : Fx, Request, { names : List(Str), force : Bool } => Try(Report.RemoveOutcome, Fail)` | `crash "todo"` |
| `Remove` | `run! : Fx, Args => I32` | `crash "todo"` |

The contract of each function is in its doc comment. In short:

| Function | Contract |
| --- | --- |
| `Scan.local_file` | The file of a local import by the table of Q5 (the answer of the manager). The path has no `..` (`Text.resolve`). |
| `Scan.roots` | An app: its file. A package or a platform: `<project dir>/<Name>.roc` for each exposed module. |
| `Scan.level` | Uses `Imports.scan` of `roc-app-header` (R-GP5: it is not tested again). A hit is an import line of the alias (an exact alias). `next` are the new local files, with no repeat, in the order of the first import. |
| `Removal.opts` | The order of the checks: registry, strategy, `--frozen`, no name. |
| `Removal.plan` | The platform row is a usage failure. A release, a path row and a foreign row are removed in the same way. The keys are the keys of the alias in the 3 tables of the nearest `talon.toml`, unless another member under that file has the alias (`shared`). A `[patch]` key gives `patch_dir`. |
| `Intent.remove` | `Toml.remove` for each key: only the lines of the key go. |
| `Resolve.remove!` | The 10 steps of its doc. The call order is fixed by the L2 case. |

## Tests

| Layer | File | Case | Rules |
| --- | --- | --- | --- |
| L0 | `scan.roc` expect 1 | `local_file` (8 rows: a bare name, a subdirectory, `./`, `../`, `../../`, out of the project dir) and `roots` (4 rows: an app, a package, a platform, no module) | R-RV2, R-LD7, Q5 |
| L0 | `scan.roc` expect 2 | `level` (7 rows): hits and next files; an exact alias (`jsonx`, `pf`), a comment, a file import, a repeat, a seen file, a file of this level that `seen` lacks, a CRLF line, a file out of the project dir | R-RV2 |
| L0 | `removal.roc` expect 1 | `opts` (12 rows): the flags, the global and the resolve flags that change nothing, the 4 failures and the order of their checks | R-CM3, R-CM19, R-FL5, R-FL7, R-FL10, R-FL12, R-FL13, R-EC2, Q2 |
| L0 | `removal.roc` expect 2 | `plan` (14 rows): release, path, foreign, the 3 keys with a patch dir, a key in `[dependencies]` only, a key in `[overrides]` only, a package header, another dir of `talon.toml`, `shared`, no `talon.toml`, no key, the platform (also under another alias, and a package named `pf`), an alias that is not there, a `talon.toml` that is not TOML | R-CM3, R-RV1, R-RV3, R-RV4, R-RV5, R-WS14, R-OV1, R-PA11, R-PA12, Q3 |
| L0 | `intent.roc` expect (new) | `Intent.remove` (8 rows): one key with its comment, 3 keys, the order of the keys, an inline `[patch]` table, no key, a key that is not there (2 forms), not TOML. `table_spans` | R-CM3, R-RV1, R-RV4, R-OV1, R-PA12, R-H1, R-CC7 |
| L0 | `report.roc` expect (new) | `Report.remove_data`: the keys in order, the kinds of an entry, `null` for a path entry version, for a step that did not run and for no pin | R-J3, R-J4, R-OUT4, R-OUT5, R-LF3, R-RV4, R-RV5 |
| L0 | `locked.roc` expect 2 (changed) | `Remove` of a path row and of a foreign row works (2 new rows in the table of edits). The row "remove a path entry" is no refusal any more: a new refusal row is `Remove` of an alias that is not there. | R-RV5, R-H4 |
| L3 | `remove/rm1-remove-entries` | 12 runs: `--dry-run` with the plan and the pin; the failure of R-RV2 with `--json` (main.roc, then a module: 2 levels deep, and with `--no-check`); the platform; an unknown name; no name; `--frozen`; the real run with `--json` (3 keys, the pin, the patch dir); `rm acme/xml --no-check --json --quiet`; a path entry, a foreign URL and a repeated name with `--force --json` (the check runs); `--force` of an imported entry | R-CM3, R-CM19, R-RV1 to R-RV5, R-LF3, R-LF4, R-RP3, R-FL4, R-FL12, R-FL13, R-EC2, R-EC11, R-J1, R-J3 to R-J5, R-OUT4, R-PD9, R-OV1, R-SC1, R-SC6, R-SC7, R-H1, R-CC1, Q2, Q4, Q8 |
| L3 | `remove/rm2-workspace` | 3 runs: at the root (exit 2, the members), a member while the other member has the alias (the key stays), the other member (the key goes) | R-WS12, R-WS14, R-CM3, R-RV1, R-PD4, R-PD5, R-PD9, R-FL6, R-EC2, Q3 |
| L2 | `remove/rm1-flow` | 6 runs on 5 projects: a 3 level scan with a missing module, the check passes with an unchanged error and the files are written (the call order); exit 10 for a new error in a package; exit 11 for a new error in an app file; exit 17 for an edit during the probes; a package member that imports the alias (exit 11, no probe); the same package without the import (2 probes, `--json`) | R-CM3, R-CM19, R-RV1, R-RV2, R-LD4, R-LD7, R-BL5, R-P6, R-PH10, R-PH13, R-EC10, R-EC11, R-EC17, R-CC7, R-PD9, R-SO7, R-PH8, R-OV1, R-SC1, R-H1, Q7 |

The probes of the L3 cases are the fake `roc` (every check passes), so the exits 10 and 11 of the check are in the L2 case (the fake `probes!` takes the real outputs of `tests/fixtures/check/out/`).

## Old tests that changed

| Test | Change | Why |
| --- | --- | --- |
| `tests/unit/locked.roc`, expect 2 | The refusal row "remove a path entry" is replaced by "remove an alias that is not there". 2 new rows in the table of edits: remove a path entry, remove a foreign URL. The comment names R-RV5. | Q1 of slice 007: R-RV5 wins for `remove` |

All other old tests pass with the stubs (`scripts/test.sh`: check, fmt and selftest pass).

## Output (proposed, R-OUT2, TW24)

The design gives none of these texts. They are proposals for the review. The text is in the expected files.

| Output | Text |
| --- | --- |
| Entry removed | Under the path of the header file: `  - <alias>: <name> <version>` for a release, `  - <alias>: <path>` for a path entry, `  - <alias>: <url>` for a foreign URL |
| Pin written (R-RP3) | `  + roc: <id>` (as `install`) |
| `talon.toml` key removed | `<path>: - [<table>] <key>`, with `<table>` `dependencies`, `overrides` or `patch` |
| Patch files stay (R-RV4) | `kept: <dir> (the patch files of <alias>)`, with `<dir>` the dir `.talon/patches/<alias>/` next to the `talon.toml`, with `/` at the end |
| Check lines | `check: passed`, `note: unchanged error: ...`, `build: passed`, `check: skipped` (as `install`, they come first) |
| Forced run (R-RV2) | `note: <alias> is still imported in <n> line(s). The app cannot check until you change the imports.` (`1 line`, `2 lines`). No check line. |
| Dry run | `dry run: nothing was written`, the last line. The plan lines are the same as for a write. There is no `resolved at` line. |
| R-RV2 failure | Exit 11: `the app imports <alias>[, <alias>]: <file>:<line>: <import line>; <file>:<line>: <import line>. Change these imports first, or pass --force to remove it anyway.` The lines are in the message, so the `--json` error has them too (the `Fail` type has no details field that a flow can set). |
| R-RV3 failure | Exit 2: `<alias> is the platform of the app. An app needs a platform. Use tln add --platform <name> to change it.` |
| Not an entry | Exit 2: `'<name>' is not in the project` (the text of `Lookup`, slice 004 Q7) |
| R-RV1 failure for a package | Exit 10: the text of the ladder, then ` tln remove moves no other entry. Pass --no-check to remove <alias>[, <alias>] anyway.` |
| Option failures | `tln remove needs one name or more`, `flag '--frozen' works only for tln install with no names` (the text of `install`), and the texts of `--registry` and `--strategy` of `Opts.read` |
| R-WS12 | The text of `install`: `no current member in the workspace at <root>. Members: <file>, <file>. Pass --file <member file>.` |
| `--json` `data` | `probes`, `dry_run`, `check`, `build`, `removed` (`alias`, `kind`, `name`, `version`), `toml` (`path`, `table`, `key`), `patches` (`alias`, `dir`), `pinned`, `notes`, `written`, in this order. `command` of the envelope is the word as typed (`remove`, `rm`). |

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Options rejected |
| --- | --- | --- |
| D1 | `Resolve.remove!` takes the `Request` of `install!` and `{ names, force }`. `Remove.run!` is the same wiring as `Install.run!` (steps 2 to 7 are the same calls in the same order, `roc version` is called also with `--no-check` and `--force`). | A new request type (the flow needs `project`, `roots`, `compiler`, `nightly`, `no_check`, `dry_run`) |
| D2 | A remove prints no `resolved at` line and `data` has no `snapshot`: it resolves nothing (R-DT5 names `tln update`; slice 007 gave the line to `install` and `add`). | A line with `0 probes` |
| D3 | The scan always runs. `--no-check` does not skip it, and `--force` only lets the run go on. | `--no-check` skips the scan |
| D4 | `--force` skips the check only when the scan found an import (the reason that R-RV2 gives). `--force` on an entry that no module imports runs the check (R-RV1). See Q4. | `--force` always skips the check |
| D5 | The pin is written as for `install` (R-RP3: a command that writes the header for another change writes the held nightly, after a check that passed). `--no-check` and a forced run write no pin (R-H6). | `remove` never writes `roc:` |
| D6 | A local module file that cannot be read is skipped (no failure). See Q7. | An `Environment` failure |
| D7 | All names are looked up and planned before the scan: one bad name stops the run with no other effect. Names that find one entry count once (`util odd util`). One check for all names. | One run for each name |
| D8 | The names are looked up in the entries of the header of the current member only (alias, full name, short name: slice 004). A transitive package is `'<name>' is not in the project`. The closure walk is slice 009. | A search in the closure |
| D9 | The keys of an alias are removed from the nearest `talon.toml` of the member only (R-WS14, R-WS5: a member with a nearer file does not read the root). A key of a path entry or a foreign URL is removed too when it is there. | A search in all files |
| D10 | The patch dir is the layout of R-PA11, `<dir of the talon.toml>/.talon/patches/<alias>/`. It is printed also when the dir does not exist. | The `path` value of the `[patch]` entry |
| D11 | The files are written in one `write_atomic!` call, the `talon.toml` first (the order of `Guard.check_all`, R-CC1). The check of R-CC7 uses `Locked.spans` for the header and `Intent.table_spans` for the keys. | Two calls |
| D12 | `--dry-run` runs the ladder and prints the plan (as `install`, R-LF4). | No probe in a dry run |
| D13 | `Removal.opts` rejects `--frozen` (R-FL13). `Args.allows` accepts it for `remove` (slice 001: `--frozen` is a resolve flag for `install`, `remove`, `update`, `upgrade`, `verify`). | A change of `Args.allows` (it would change the L0 `args` tests; the code agent can choose it) |
| D14 | The R-RV2 lines are in the message of the failure, not in a block before it. | A block on stderr (as the tie list of R-SC14): the `--json` error would not have the lines |
| D15 | The scan of a package or a platform starts at the exposed modules (`Header.exposed`), as R-LD7 says. | Start at the project file only |
| D16 | `check_pin` (R-RP2 outside range, no compiler: exit 18) runs when the check runs. It is not tested for `remove` (the cases of `install` cover it). | Always, also with `--no-check` |

## Questions (TW17) and design gaps

| # | Question or gap | Default used in the tests |
| --- | --- | --- |
| Q2 | `tln remove` with no name, and with 2 names or more: R-CM3 shows one name. Is a line with no name a usage failure, and are many names allowed in one run (as `bun remove a b`)? | No name: usage, exit 2 (`tln remove needs one name or more`). Many names: all are removed in one run, with one check. |
| Q3 | In a workspace, another member under the same `talon.toml` has the same alias. The key of that alias in `talon.toml` constrains that member too (R-WS7). Does `remove` take the key out, or keep it? R-RV1 says "its `talon.toml` key" and does not say. | Keep the key (and the `[overrides]` and `[patch]` keys) when another member under the dir of that file has the alias. Else R-I5 would add the entry again. |
| Q4 | `--force` on an entry that no module imports: skip the check or run it? R-RV2 says that `--force` skips the check "because the app cannot check until the user changes the imports". | Run the check (the reason does not hold). |
| Q6 | The import `import /X` (a leading `/` starts at the package root): which dir is the root of an app? Q5 of the manager does not name it. | `<project dir>/X.roc`. Not tested. |
| Q7 | A local import whose file does not exist or cannot be read: skip it, or fail? (`roc` reports the error itself, and the baseline check has it too.) | Skip it, no failure (the L2 case `import Gone`). |
| Q8 | R-DT5 is the line of `tln update`. Does `remove` print a `resolved at` line and have `snapshot` in `data`? | No (D2). |
| G1 | `Ladder.check` text for a hang or a crash ends with `with <moved>`. `remove` gives `moved` empty, so the text ends with `with `. | No test. The code agent can give the removed entry as `moved`, or change the text. |
| G2 | R-RV1 says that the error for a package "names the package and `--no-check`". The ladder text names the package and its modules. The suffix of D-text above is the proposal. | The suffix of "Output" |

## Out of scope

| Id or item | Reason |
| --- | --- |
| R-H7 (the `import` lines of a path entry join the scan) | The closure walk is slice 009. The scan starts at the member only. |
| R-UM1, R-BS2 (the used modules and the build skip) | Unit probes and `compat.db` are P1. |
| R-RP2 outside range and no compiler for `remove` | Same code as `install` (D16). No new case. |
| `import` forms that `Imports.scan` does not read (a line that is not at the start of a line, a multi-line string with the word `import`) | The generic package decides (R-GP5). |
| The delete of `.talon/patches/<alias>/` | R-RV4 keeps the files. |
| R-CM1, R-CM4 to R-CM18, R-CM21 to R-CM23 | Other slices or phases |
| `remove` in the closure of a workspace member that is not the current member | R-WS12: one member only. |

## Red output (stubs, 2026-10-20)

`scripts/test.sh`: check, fmt and selftest pass. No compiler error and no warning in any test.

| Layer | Result |
| --- | --- |
| L0 | 5 files fail, all other files pass. `scan` 2 of 2, `removal` 2 of 2, `report` 1 of 3 (the new `expect`), `intent` 1 of 5 (the new `expect`): `Roc application crashed with this message: todo`. `locked` 1 of 2: the wrong value (`Locked.edit` still refuses to remove a path entry and a foreign URL). |
| L2 | 1 failed of 25: `remove/rm1-flow` (`the test app wrote no exit file`, `[ROC CRASHED] todo`). The 24 old cases pass. |
| L3 | 2 failed: `remove/rm1-remove-entries` and `remove/rm2-workspace` (`[ROC CRASHED] todo`, the exit is 1 in place of the expected code). The old cases pass. |

## Revert check (TW12)

76 changes of the private reference, in `research/slice-008-revert/results.md`: 76 caught. 8 rows were INVALID at the first run (a warning stops `roc build`), were rewritten and run again, and were caught. 4 rows were not caught at first (S8, M8, M16, M18): a test row was added for each. 2 rows (F13, F19) were not caught by the first deep cases: the `--json` envelope was added to the run of a path entry and a foreign URL, and the scan of the L2 case got 3 levels.

| Group | Rows | Caught by |
| --- | --- | --- |
| `Scan` | S1 to S12 | L0 `scan` |
| `Removal` | M1 to M19 | L0 `removal` |
| `Intent` | I1 to I5 | L0 `intent` |
| `Report`, `Locked` | P1 to P6, K1, K2 | L0 `report`, `locked` |
| `Resolve.remove!` | F1 to F20 | L3 `rm1`, `rm2`, L2 `rm1-flow` |
| `Remove`, `Run` | C1 to C11, W1 | L3 `rm1`, `rm2`, L2 `rm1-flow` |

## Next step

Human review of the tests and of the output proposals (TW24), and the answers to Q2, Q3, Q4, Q6, Q7 and Q8. Then the code agent writes: `Scan` (3 bodies), `Removal` (`opts`, `plan`), `Intent.remove` and `Intent.table_spans`, `Report.remove_data`, the `Remove` branch of `Locked.apply_op`, `Resolve.remove!` and `Remove.run!`. It does not edit a test (TW18).

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Verify results (code agent, 2026-10-20)

`scripts/test.sh` exit 0: check 6.9 s, fmt 0.1 s, L0 41 files pass (11.4 s), L2 25 cases pass (35.9 s), L3 22 pass and 1 skipped (9.2 s), selftest 24 pass (5.8 s). Total 69 s. The 5 red items of the stubs are green: L0 `scan`, `removal`, `report`, `intent`, `locked`; L2 `remove/rm1-flow`; L3 `remove/rm1-remove-entries`, `remove/rm2-workspace`.

Files written (lines now): `Scan.roc` 89, `Removal.roc` 100, `Remove.roc` 91, `Resolve.roc` 1544 (`remove!` and its helpers, about 280 new lines), `Install.roc` 202, `Intent.roc` 441, `Report.roc` 189, `Locked.roc` 163, `Ladder.roc` 400.

Revert check (TW12): `research/slice-008-revert/code-mutate.py`, rows in `research/slice-008-revert/code-results.md`. Caught 38 of 39. The dir `cli/` after the run equals the copy before it (`diff -r`).

| Id | Rule | Mutation | Result |
| --- | --- | --- | --- |
| G1 | G1 | `Ladder.moved_text` gives ` with ` also for an empty list | NOT CAUGHT. The manager said: no new test for G1. A scratch `expect` (run once, deleted) showed the fixed texts. |

Decisions of the code agent that the slice does not fix:

| # | Decision | Options rejected |
| --- | --- | --- |
| C1 | `Removal.opts` calls `Opts.read` (imported as `FlagOpts`, because `Removal.Opts` is the name of the type), so the checks of the registry and the strategy are the ones of `install`. Then it checks `--frozen` and no name. `--force` is read in `Removal`. | A copy of the 2 checks |
| C2 | The helpers of `Install.run!` that `Remove.run!` needs are now members of the block of `Install` (public): `shown_fx`, `check_member`, `canonical_files!`, `on_path!`, `nightly_of`, `failed!`, and the new `begin!` (steps 2 to 4: env, clock, project). `Install.flow!` calls `begin!` too. `check_member` now takes a `Bool` (the run needs a member) in place of `Opts`. No test calls it. The L2 and L3 cases of `install` pass. | A copy of about 60 lines in `Remove.roc` |
| C3 | `Resolve.remove!` sets `shared` (Q3) by the contract of `Removal.plan`: another member whose file is under the dir of the `talon.toml` has the alias. | The members whose nearest `talon.toml` is that file (a member with a nearer file does not read the root, D9) |
| C4 | A run with `--no-check` and `--force` and a hit prints `check: skipped` (the flag was given, as for `install`). A forced run with no `--no-check` prints no check line. | No line for any forced run |
| C5 | `Removal.plan` reads the `talon.toml` with `Toml.parse` and gives the text of `Intent.read` for a failure (`<path>:<line>: not valid TOML`, kind `Input`). `load!` has already called `Intent.read` for the same file. | A second `Intent.read` (it checks the tables again) |
| C6 | G2: the failure of the ladder is `<ladder text>. tln remove moves no other entry. Pass --no-check to remove <alias>[, <alias>] anyway.` The `.` is written by the code: the ladder text has no full stop at its end (the expected files have `). tln remove`). Only the kind `NoTuple` gets the suffix. | A suffix for the other kinds |
| C7 | G1: `Ladder.moved_text` gives ` with <name> <version>, ...` and gives the empty text for no moved entry, so the hang and crash texts of `Ladder.check` end after the `)`. The doc of `Ladder.check` has this. | Give the removed entry as `moved` (the removed entry is no tuple member) |
| C8 | `Intent.table_name : Table -> Str` is a new public function (the output and the key path use it). | A copy in `Resolve` |
| C9 | `Locked.apply_op`, `Remove`: the check is "the alias is in the header" (`<alias> is not in the header`, kind `Internal`). It no longer calls `check_row`, so a path row and a foreign row go (R-RV5). `Set` is unchanged. | A new `Op` |
| C10 | `Resolve.remove!` with no current member (a workspace root) fails with `no current member: pass --file <member file>` (kind `Usage`). `Remove.run!` stops that case first with the text of `install`, so the line is not reached. | `crash` |
| C11 | A package or a platform file starts the scan at its exposed modules only (D15). The project file itself is not scanned for them (its header has no `import`). The files that were seen are the project file and each file that a level read, also a file that could not be read (so it is not asked again). | Scan the project file |

## Review (manager, 2026-10-20)

D1 to D16 and the output proposals (TW24) are accepted. The change of the old row in `locked.roc` is accepted: it follows the Q1 answer of slice 007. The answers below are proposals of the manager. The user did not confirm them yet.

| # | Answer |
| --- | --- |
| Q2, Q3, Q4, Q6, Q8 | The defaults |
| Q7 | The default (skip), because the check after the remove still sees the module. |
| G1 | A bug: the code agent fixes the text, so it has no `with ` at the end when `moved` is empty. No new test. |
| G2 | The proposed suffix is accepted. |

## Review of the code (manager, 2026-10-20)

`scripts/test.sh` passes (manager run). The revert check of the code caught 38 of 39 (G1 not caught, as the review said). C1 to C11 are accepted. Note for a later slice: `cli/lib/Resolve.roc` has about 1544 lines. Slice 009 can move `install!` and `remove!` to their own modules if it touches them.
