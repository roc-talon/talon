# 030b R-CV6 wiring

Phase: P1. Status: done

Slice 030b connects the first-seen sha256 store of slice 030 (`Facts`, `Db`, `compat.db`) to the compiler list. Each list that `Nightlies.list!` reads records the sha256 of the asset of the host for each release (R-CV6, R-CV3). A tag with a later, different sha256 is no candidate for any command. A command that names the tag stops with exit 16 and the text of R-CV6. An installed compiler with that tag stays in use. A busy or failing `compat.db` gives the R-CC8 warning, records nothing, and the command goes on. It follows `docs/agents/BRIEF-tests.md`. The copies of the changed files before the slice are in `research/slice-030b-revert/before/` (with `NEW.txt`).

The answers of the review of slice 030 (Q1, Q2 in `docs/slices/030-compat-db.md`, "Review (manager, 2026-10-23)") bind this slice. They are in the table:

| Answer | Where it is tested |
| --- | --- |
| Every (tag, target) sha256 that a list gives is recorded, from either source (R-CV3) | L0 `pins` 1, 3. L2 `cv1-pins` runs 5, 13, 14, 17. L3 `cv1-first-seen` part 1 |
| A later different value makes the tag no candidate for every command | L0 `pins` 2. L2 `cv1-pins` runs 5, 13. L3 part 2 |
| A command that names the tag stops with exit 16 and the R-CV6 text: `roc install`, `roc default`, `roc use`, a pin | L0 `pins` 4. L2 runs 8 to 12. L3 part 3 |
| An installed compiler with that tag stays in use, also as the base of `@-N`, `@+N` (review Q1) | L0 `pins` 6. L2 runs 6, 7, 18. L3 part 4 |
| `compat.db` busy or failing on the read: the R-CC8 warning, nothing recorded, go on. The check of the download sha256 against the list still runs | L2 runs 1 to 4. L3 part 6 |

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-CV6 (first sha256 of (tag, target) recorded and kept. A changed one: exit 16 with the tag, both values and both sources. Not a candidate. An installed compiler stays) | `Nightlies.pins`, `Nightlies.without_changed`, `Nightlies.auto_with_base`, `Nightlies.list!`, `Facts.first_seen_all`, `Facts.pin_all!`, `Toolchain.changed_failed`, `Toolchain.changed_warning`, `RocInstall.offer!` | L0 `pins` 1 to 6. L2 `roc/cv1-pins` (18 runs). L3 `compilers/cv1-first-seen` |
| R-CV3 (the sha256 is the `digest` of a list from either source. A cached list is a list) | `Nightlies.pins` (source `GithubDigest`), `Nightlies.list!` | L0 `pins` 1. L2 run 17 (a cached list), the old cases |
| R-CC8 (busy or failing db: warning, go on, nothing recorded. A write that fails: the facts stay in memory) | `Facts.pin_all!` | L2 runs 1 to 4, 14. L3 part 6 |
| R-TF3 (a newer format: exit 19 for every command that reads the list) | `Facts.pin_all!` | L2 run 15. L3 part 7 |
| R-EC16 (exit 16, `integrity`), R-SC10 (a prefix names one compiler), R-C7, R-SO13, R-SO22, R-DL1, R-CV1, R-CV4 | The cases above | Named in the cases |

`MISSING=1 scripts/rules.sh CV CC TF` lists none of the ids that this slice names.

## 2. Flow (what the L2 and L3 cases fix)

Each list that is read (live or from the cache, not `Missing`) makes these calls after the calls of `Github.releases!`, in `Nightlies.list!`:

| Step | Call | Rule |
| --- | --- | --- |
| 1 | `Nightlies.pins`: one row for each release with one asset for the host that has a sha256 (`{ tag, target: Nightlies.target(host), sha256, source: GithubDigest }`). No row: no call | R-CV3, R-CV6 |
| 2 | One `db_query!` with `Pinned(keys)` (one key for each row) | R-CV6 |
| 3 | `Err(Busy)` or `Err(Failed)`: `warning: <Db.on_err text>` on stderr, no write, no change, go to step 6. `Err(TooNew)`: exit 19 | R-CC8, R-TF3 |
| 4 | `Facts.first_seen_all`: `new` (no recorded row) and `changed` (another sha256) | R-CV6 |
| 5 | `new` is not empty: one `db_write!` with `Pinned(new)` (a row that exists stays). A busy or failed write: the warning of `Write`, go on | R-CC8 |
| 6 | `releases` is `Nightlies.without_changed`, and the result has `changed` and `dropped` (the releases that were taken out) | R-CV6 |

`RocInstall.offer!` (the one function that `roc install`, `roc default`, `roc use`, `roc update`, the proxy and the compiler of a pin call, through `Start`) then does:

| Case | Result |
| --- | --- |
| Before the pick | `Nightlies.auto_with_base` gives the `auto` for the step: an installed base with a changed tag is put back at its place (review Q1) |
| `Nightlies.pick` gives an id | One line `warning: <Toolchain.changed_warning>` on stderr for each change, then the usual steps |
| `Nightlies.pick` fails, `Toolchain.changed_failed` of the text of the caller is `Ok(fail)` | `Err(fail)`: exit 16. No warning |
| `Nightlies.pick` fails, `Err(NotNamed)` | The warnings, then `Toolchain.pick_failed` as before |
| The text is an installed id | Exit before the list (step 3 of `roc install`): no list, no db call, no warning |

`RocInstall.range_id!` (rank 4) calls `Nightlies.list!` only. It prints no warning (a ladder run calls it and then `offer!` for the same list: one set of warnings).

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Facts.roc` | 174 to 189 | Stubs from the test agent | `Facts.Change`, `first_seen_all`, `pin_all!`: bodies `crash "todo"`. The doc table has the calls |
| `cli/lib/Nightlies.roc` | 359 to 373 | Same | `pins`, `without_changed`, `auto_with_base`: `crash "todo"`. `list!` has the new result fields `changed` and `dropped` (the stub returns `[]`) and the doc of the calls. Imports `Db` and `Facts` |
| `cli/lib/Toolchain.roc` | 419 to 437 | Same | `changed_failed`, `changed_warning`: `crash "todo"`. Imports `Facts` |
| `cli/lib/RocInstall.roc` | 378 | Test agent | Docs only (step 4 of the table, `range_id!`). The code is the code agent work (section 4) |
| `tests/unit/pins.roc` | 187 | Test agent | 6 `expect`s, red |
| `tests/commands/cases/roc/cv1-pins/` | 18 runs, 54 files | Test agent | New L2 case, red. Made by `research/slice-030b-revert/mkcase-cv1.py` (the expected files by the reference) |
| `tests/scenarios/compilers/cv1-first-seen/` | 7 parts, 14 files | Test agent | New L3 case, red. `given/http` is the one of `compilers/ri1-install-flow` |
| 12 old L2 cases (23 expected files) | | Test agent | `calls.log` and `tree.diff` have the new db calls and the new `compat.tsv` (section 6) |
| `research/slice-030b-revert/` | | Test agent | `before/`, `stubs/`, `mutate.py`, `mkcase-cv1.py`, `old-l2-update.py`, logs, `results.md` |

No `Fx` field, no `main.roc`, no L3 runner and no selftest change. `RealFx`, `RealDb`, `Db`, `Roots`, `Github` are not changed.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Facts.Change` | `{ first : Db.Pinned, now : Db.Pinned }` | R-CV6 |
| `Facts.first_seen_all` | `{ recorded : List(Db.Pinned), listed : List(Db.Pinned) } -> { new : List(Db.Pinned), changed : List(Facts.Change) }` | R-CV6 |
| `Facts.pin_all!` | `Fx, { roots : Roots, listed : List(Db.Pinned) } => Try(List(Facts.Change), Fail)` | R-CV6, R-CC8, R-TF3 |
| `Nightlies.pins` | `{ host : Host, releases : List(Release) } -> List(Db.Pinned)` | R-CV3, R-CV6 |
| `Nightlies.without_changed` | `{ releases : List(Release), changed : List(Facts.Change) } -> List(Release)` | R-CV6 |
| `Nightlies.auto_with_base` | `{ releases : List(Release), dropped : List(Release), auto : List(Str), base : Try(Str, [None]) } -> List(Str)` | R-CV6, R-C9 |
| `Nightlies.list!` | The result is `{ releases, source, changed : List(Facts.Change), dropped : List(Release) }` (new fields `changed` and `dropped`) | R-CV6 |
| `Toolchain.changed_failed` | `{ text : Str, changed : List(Facts.Change) } -> Try(Fail, [NotNamed])` | R-CV6, R-SC10, R-CV1 |
| `Toolchain.changed_warning` | `Facts.Change -> Str` | R-CV6 (TW24) |

`Nightlies.Release` does not change (the type of the old tests stays). The code agent changes `Nightlies.list!` (the 6 steps), `RocInstall.offer!` (the table above, with `auto_with_base` before the pick) and nothing else. The doc of each function has the contract.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/pins.roc` 1 (`pins`) | Rows for releases with one asset and a sha256 only (no asset, 2 assets, no sha256: no row). The target of the host (`windows_arm64`). The order. The source `github-digest` | R-CV3, R-CV6, R-CV4 |
| L0 | 2 (`without_changed`) | Drops the tags of the changes, any number. The order stays. A tag that is not in the list, no change, no release | R-CV6 |
| L0 | 3 (`first_seen_all`) | Nothing recorded, all the same, a changed sha256 with `first` and `now`, the same sha256 with another source, a row of another target, a repeated row (one `new` row), 2 changes in the order of the list | R-CV6 |
| L0 | 4 (`changed_failed`) | The tag, after `@`, the other tag form (R-CV1), a unique prefix, the first source in the text. NotNamed for a prefix of 2 changes, an empty text (also with one change), `@`, `@latest`, a step, an unchanged tag, the date with another sha | R-CV6, R-SC10, R-CV1 |
| L0 | 5 (text) | The failure of a named tag (kind Integrity, the text of `Facts.changed_fail`) and the warning text | R-CV6 |
| L0 | 6 (`auto_with_base`) | The base is put back at its place in the order (also in the other tag form). No other changed tag comes back. No base, a candidate base, an unknown base, nothing dropped: `auto` as it is. `pick` of `@-1` from the base skips a changed tag, `@+1` | R-CV6, R-C9, R-CV1, R-NS1, R-SL7 |
| L2 | `roc/cv1-pins` (18 runs) | Runs 1 to 4: a busy read, a failed read, a busy read for a changed tag (it installs), a busy read and a wrong listed digest (exit 16 from R-CV4). Run 5: 3 changes dropped, `@latest` is the next release, 6 new rows in one write, a cached list is recorded. Runs 6, 7: an installed changed tag is in use, no list, no db call. Runs 8 to 12: the id, a prefix, `roc default`, `roc use`, a project pin: exit 16. Run 13: rank 4 (home2). Run 14: a busy write (home3). Run 15: a newer format (home4). Run 16: no changed tag named: warnings, then exit 2. Run 17: `--offline` with a cached list records it. Run 18 (review Q1): the default is an installed changed tag, `@-2` starts from it and lands on 2026-10-15, not on the changed 2026-10-16 | R-CV6, R-CV3, R-CC8, R-TF3, R-EC16, R-SC10, R-C7, R-SO13, R-SO22, R-CV4 |
| L2 | 12 old cases (section 6) | The db calls of each list read in `calls.log`, the `compat.tsv` in `tree.diff`. Stdout, stderr and exit code did not change | R-CV6, R-CV3 |
| L3 | `compilers/cv1-first-seen` (7 parts) | The real SQLite store and the real curl and tar. 1: the first read records 5 rows. 2: a swap of 2 assets: `@latest` skips both (warnings). 3: the id, a prefix, `--json` (R-J5) and `roc default` stop with exit 16. 4: an installed compiler stays in use, no request (`http.log`). 5: a name is not hidden by age, the cached list. 6: a file that is no database: warning, go on. 7: a newer format: exit 19, the file stays. `expect/facts.tsv`: the first value of each asset | R-CV6, R-CV3, R-CV1, R-CV4, R-CC8, R-TF3, R-EC16, R-J5, R-SC10, R-C7, R-NS4, R-SO15 |

Count: 6 L0 `expect`s in 1 new file, 1 new L2 case (18 runs), 1 new L3 case (7 parts), 12 old L2 cases with changed expected files. The budget of the manager is 5 to 20 L0 and 2 to 6 deep: this is 6 and 2. Step times with the reference (`green.log`): check 1.5 s, fmt 0.1 s, l0 5.7 s, l2 1.5 s, l3 9.6 s, selftest 7.7 s. Flake check (TW15): the L3 case ran 8 times in a row and the L2 case 5 times, with no failure.

## 6. Old L2 cases that changed

The db calls are new lines in `calls.log`, and the store file is new in `tree.diff`. `research/slice-030b-revert/old-l2-update.py check <snapshot>` compares each changed file with a copy of the tests before the slice, after it removes the allowed lines (`db_query` and `db_write` of `compat.db` in `calls.log`, the section of `compat.tsv` in `tree.diff`). Result: 0 unexpected lines. `stdout`, `stderr` and `exit` of the 12 cases are the same as before. No L3 case changed (the runner leaves `compat.db*` out of the tree diff, and no old case reads `facts.tsv`).

| Case | db lines added | `compat.tsv` lines in `tree.diff` |
| --- | --- | --- |
| `consent/dl1-resolve` | 15 | 16 |
| `consent/dl2-verify-workspace` | 2 | 15 |
| `consent/dl3-rank4` | 22 | 16 |
| `proxy/px2-install` | 20 | 14 |
| `roc/bs1-base` | 8 | 16 |
| `roc/bs2-no-pin` | 6 | 16 |
| `roc/bs3-range` | 4 | 16 |
| `roc/df1-default` | 8 | 7 |
| `roc/ri1-flow` | 11 | 24 |
| `roc/up1-update` | 22 | 16 |
| `roc/us1-use` | 23 | 0 (the effects are in homes that the tree diff does not cover) |
| `roc/us3-step` | 2 | 16 |

The reading of the diffs: each list read is a `db_query` with `pinned=<n>` (n is the count of candidates of the host), the first read of a db is followed by one `db_write` with all the rows, a later read of the same list is a query only (all the same), and a read of another host (`roc/ri1-flow` run 4, Windows) writes the rows of the other target.

## 7. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stderr, a tag dropped from the list (not named). `warning: ` first, one line for each change, in the order of the list | `the sha256 of <tag> for <target> changed: first seen <sha256> (<source>), now <sha256> (<source>). Talon does not offer this compiler.` |
| stderr, exit 16, `error[integrity]` (a command that names the tag): the text of slice 030 | `the sha256 of <tag> for <target> changed: first seen <sha256> (<source>), now <sha256> (<source>). Talon does not use this compiler. Select another compiler.` |
| `--json`, exit 16 | The envelope of R-J5: `error.kind` is `integrity`, `error.code` is 16, `error.message` is the text above (L3 part 3) |
| Busy, failing, newer format | The texts of slice 030 (`Db.on_err`). A newer format stops with exit 19 in each command that reads the list |

The warnings are printed after the db calls and before the prompt or the download (L2 run 5 and run 17, `stderr`). The source words are `github-digest` and `registry`.

## 8. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | A list records the asset of the host of the machine for each release (one target), not each target of the release. `Nightlies.releases` gives the asset of one host, so no type of the old tests changes. A swap of an asset for another host is not seen by a machine that cannot use it. | The assets of all targets of each release (a change of `Release`, and of the old tests that build one) |
| D2 | The wiring is in `Nightlies.list!` and `RocInstall.offer!`: the one list read and the one offer that each command uses (`roc install`, `roc default`, `roc use`, `roc update`, the proxy, the compiler of a pin, rank 4). No command has its own code. | A check in each command |
| D3 | `Nightlies.Release` does not change. The tags with a change are not in `releases` (so no candidate for any command), and `changed` is in the result of `list!`. | A variant `Changed` in `Release.asset` (it breaks the type that the old tests write) |
| D4 | A command "names" the tag when `Nightlies.pick` fails and its text is the tag (also after `@`), the other tag form (R-CV1), or a prefix of the tag of exactly one change (R-SC10). A prefix of 2 or more changed tags names none. | The exact tag only (a unique prefix would give "no compiler matches", which hides the reason) |
| D5 | One warning for each dropped tag, from `offer!`, after a good pick or a failure that names no changed tag. None for a named tag (the error has the same facts). None in `range_id!`. | No warning (a skipped compiler with no reason). A warning in `list!` (the same text twice with exit 16, and twice in a ladder run) |
| D6 | The first read of each list records the rows with `Keep`: a row that exists stays, so the first value stays. A cached list (the source `Cached`, `--offline`) is recorded as a live one. | Only a live list |
| D7 | A release with no asset, 2 assets or no sha256 is not recorded and is never a change. | A row with an empty sha256 |
| D8 | `TooNew` stops each command that reads the list with exit 19 (the rule of `Facts.pin!` and R-TF3). | A warning and no check |
| D9 | `compat.db` busy or failing on the read: no change is known for this command (nothing is dropped). A failing write keeps the changes that the read gave. | Drop nothing also after a good read |
| D10 | An installed id ends `roc install` before the list (slice 021, D2), so an installed compiler with a changed tag makes no db call. | A read for each command |
| D11 | (review Q1) `Nightlies.list!` gives `dropped`, and `Nightlies.auto_with_base` puts an installed base with a changed tag back into `auto` for the relative step only. `Nightlies.pick`, `Toolchain.domain` and `Release` do not change. | A `keep` field in `Toolchain.domain` (it changes the old tests that call it) |

## 9. Out of scope

| Id | Reason |
| --- | --- |
| R-CV3 registry branch (`source: registry`) | P2. The source word is in `Db` (slice 030) |
| R-CV6 "stays after `tln cache clean --all` and `tln roc rm`" | Slices 029 and 024 test that `compat.db` is not removed |
| The assets of the other targets of a release (D1) | A later slice if the manager wants it |
| The text of R-CV6 in the design | The manager changes the design (gap G1) |

## 10. Questions (TW17)

| # | Question | Default (not tested) | Other option |
| --- | --- | --- | --- |
| Q1 | A relative step with a base that is an installed compiler whose tag changed. | Answered by the review: the base stays usable (D11, L0 `pins` 6, L2 run 18) | `BaseNotListed`, exit 2 |
| Q2 | Is the warning of D5 wanted, or is the drop silent? | The warning (tested). Answered by the review: keep it | No warning: the `stderr` lines of L2 runs 5, 13, 16, 17 and L3 part 2 and 5 change |

## 11. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-CV6 says that a later different sha256 makes Talon stop with exit 16 and that the tag is not a candidate. The review answers (Q1 of slice 030) say: not a candidate for every command, exit 16 only for a command that names it. The text should say so, and that a busy `compat.db` lets a changed asset pass the first-seen check once (the download check of R-CV4 still runs). |
| G2 | R-CV3 does not say that a cached list counts. D6 records it. |
| G3 | R-TF3 and the wiring: every command that reads a list stops with exit 19 for a `compat.db` of a newer format, also `roc install <id>` for one tag. R-TF3 says "stops" for a file that Talon cannot make again, so this follows the rule. The text could name this effect. |
| G4 | The warning text for a dropped tag (D5) has no rule. |
| G5 | The error text of an unreadable file (`Failed`) holds the text of the SQLite library: `NotADatabase: File opened that is not a database file: file is not a database` (L3 part 6, `expect/stderr`). A later basic-cli can change it. |

## 12. Compiler and syntax limits found

None new. A `==` on a `Try` of a record and on records with lists of records compile in `tests/unit/pins.roc`.

## 13. Red output

`scripts/test.sh` with the stubs (2026-10-23), logs `research/slice-030b-revert/red.log` and `green.log` (with the reference). `cli/lib` has the stubs again (`diff` with `stubs/`: equal).

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest | pass | The stubs compile. |
| L0 old files | pass | |
| L0 `tests/unit/pins.roc` | red: 6 of 6 `expect`s crash | `Roc application crashed with this message: todo` |
| L2 old cases (58, the other 12 are below) | pass | |
| L2 `roc/cv1-pins` | red | A wrong value: no db call, `@latest` is 2026-10-18 (no change is known), no exit 16, no warning |
| L2 12 old cases (section 6) | red | A wrong value: `calls.log` lacks the db lines, `tree.diff` lacks `compat.tsv`. `stdout`, `stderr` and `exit` are the same |
| L3 old cases | pass | |
| L3 `compilers/cv1-first-seen` | red | A wrong value: part 2 installs nothing and exits 16 (the swapped 2026-10-14 is still the newest), no warnings, exit 16 is missing in part 3, `facts.tsv` has no row |

```text
tests/unit/pins.roc: FAILED  (6 expects crash with todo)
FAIL roc/cv1-pins              stdout, stderr, Fx calls and file tree differ
FAIL consent/dl1-resolve, consent/dl2-verify-workspace, consent/dl3-rank4, proxy/px2-install, roc/bs1-base, roc/bs2-no-pin,
     roc/bs3-range, roc/df1-default, roc/ri1-flow, roc/up1-update, roc/us1-use, roc/us3-step   Fx calls and file tree differ
FAIL compilers/cv1-first-seen  stdout, stderr and facts.tsv differ
```

Times on the stub tree: check 1.9 s, l0 5.7 s, l2 2.1 s, l3 9.6 s. With the reference: check 1.4, fmt 0.1, l0 5.7, l2 1.4, l3 9.6, selftest 7.7, exit 0. No budget is at risk.

## 14. Check against the design (TW21)

The expected files of the new cases and of the 12 old L2 cases were made by the private reference and read by eye against the design.

| File | What was checked |
| --- | --- |
| `roc/cv1-pins/expect/calls.log` | 21 db calls in the order of the runs. Runs 1 to 4: a query and no write. Run 5: a query and one write of 6 rows (3 changed, 1 the same, 6 new of 10). Runs 6, 7: no call. Runs 8 to 12: a query only. Run 13: a query, a write of 7 rows, a second query (the offer). Run 14: a query and a busy write. Run 15: one query (exit 19). Run 17: a query and a write of 10 rows. Run 18: one query, no write. Every call has `busy_ms=5000 format=1` |
| `roc/cv1-pins/expect/stdout`, `stderr`, `exit` | The exit codes 0, 0, 0, 16, 0, 0, 0, 16, 16, 16, 16, 16, 13, 0, 19, 2, 15, 0 (run 18: `nightly-2026-10-15-38e6c42 is already installed`). The 4 warnings of R-CC8 (busy, failed, busy, busy), 3 dropped-tag warnings after run 5, none for the named runs, 3 in run 13 (once), 1 in run 14, 3 in run 16 |
| `roc/cv1-pins/expect/tree.diff` | `compat.tsv` of home: the 4 given rows stay (the first values), 6 rows are new (2026-10-09 to 12, 15, 17). 2026-10-14 is the same |
| `compilers/cv1-first-seen/expect/stdout`, `stderr`, `http.log` | Exit codes 0, 0, 16 x4, 0 x5, 19. `@latest` is 2026-10-12. The id, a prefix and `--json` give the text of R-CV6 (the json has `kind: integrity`). The installed compiler makes no request. A name of a hidden nightly installs |
| `compilers/cv1-first-seen/expect/facts.tsv` | The 5 rows with the first sha256 of each asset (from `given/http`, not the swapped values), source `github-digest` |

## 15. Revert check (TW12)

Method: the private reference made all new tests pass (it is deleted, so `mutate.py` cannot run again). `research/slice-030b-revert/mutate.py` puts the reference into `cli/`, changes one small thing, runs `roc check cli/main.roc` (0 errors and 0 warnings), then the layers of the mutation in order (L0 `pins.roc`, L2 `roc/cv1-pins` and the old cases that the change can touch, L3 `cv1-first-seen`). One mutation at a time, no full sweep. Result: 37 mutations, all caught (`results.md`, `mutate-run-1.log` to `-5.log`: N07 was not caught at first and T06 had a double match; A01 to A06 are the rows of the review Q1, A02 did not compile in its first form). `mutate-run-3-l3.log` (`ONLY=l3`): 9 of the code mutations that the L2 case catches are caught by L3 alone.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `first_seen_all` (no dedupe of a repeated row, a change ignored, `Same` as new) | F01 to F03 | L0 `pins` 3 |
| `pin_all!` (no early return for no row, a write for no new row, the write of all rows, a busy read goes on to a write, a failed read stops, `TooNew` ignored, a failed write drops the changes, a wrong target in the key) | F04 to F12 | L2 `cv1-pins` and the old cases (F07 to F09 also L3) |
| `Nightlies.pins` (source, no sha256 row, the target) | N01 to N03 | L0 `pins` 1 |
| `without_changed`, `list!` (no filter, the filter left out, `changed` empty, only a live list is recorded) | N04 to N07 | L0 `pins` 2, L2, L3 |
| `changed_failed` (no `@`, a prefix never names, the other tag form, a prefix of 2 names the first, an empty text) | T01 to T05 | L0 `pins` 4 |
| `changed_warning` (the text, the sources swapped) | T06, T07 | L0 `pins` 5, L2 |
| `auto_with_base`, `list!` `dropped`, `offer!` (the base is not put back, all dropped tags come back, the other tag form, no order, the function is not used, `dropped` is empty) | A01 to A06 | L0 `pins` 1 to 6 (A01 to A04), L2 `cv1-pins` (A01, A02, A05, A06) |
| `offer!` (no `changed_failed`, no warning after a pick, a warning for a named tag, no warning after another failure, `changed` empty for `changed_failed`) | R01 to R05 | L2 `cv1-pins`, L3 |

Gaps found by the check and closed before the hand-off:

| Mutation | Gap | Row added |
| --- | --- | --- |
| T05 (an empty text is a prefix of every tag) | The first rows had 3 changes, so an empty text was `NotNamed` for another reason | L0 `pins` 4: an empty text and `@` with one change |
| N07 (only a live list is recorded) | Every list of the L2 case was a fresh cache (source `Live`) | L2 run 17: `--offline` with a cached list (home5) |

## 16. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `Facts.pin_all!`, `Nightlies.list!`, `Toolchain.changed_failed` and the step 4 of the table of `RocInstall` are the contract. The `calls.log` of `roc/cv1-pins` fixes the calls and their order, including the warning lines on stderr (after the db calls, after a good pick). |
| N2 | `Nightlies.list!` calls `Facts.pin_all!` when `Nightlies.pins` is not empty. With `source: Missing` the list is empty, so no call. |
| N3 | `RocInstall.offer!`: after `Nightlies.pick` gives an id, one `fx.err!("warning: ...\n")` for each change. After a `PickError`, `Toolchain.changed_failed({ text: run.id, changed: found.changed })` first. `range_id!` prints nothing. |
| N4 | A local variable must not have the name of a function of its type module (`new`, `pins` are fine in other modules, `releases` is not in `Nightlies`). `==` on a record that has a `Try` field compiled in the tests. |
| N5 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

D1 (only the asset of the host: it is the only one that this machine downloads, so it is enough for R-CV6 here; it replaces the wider text of the review of slice 030), D2 to D10, the changes of the old L2 cases and the text proposals of section 7 are accepted. Answers:

| # | Answer | Effect |
| --- | --- | --- |
| Q1 | R-CV6 says that an installed compiler with a changed tag stays in use, so it must also stay usable as the base of `@-1` and `@+1` (R-C9). An installed base stays in the candidates for the relative step only, and the step itself never lands on a changed tag. | D11. `Nightlies.auto_with_base`, the field `dropped` of `Nightlies.list!`, L0 `pins` 6, L2 `cv1-pins` run 18 (mutations A01 to A06, all caught) |
| Q2 | Yes: keep the warning for a dropped tag. | None |
| G1 to G5 | Stay recorded as design notes. G5: the SQLite text stays (basic-cli is pinned). | None |

The private reference and `swap.sh` are deleted (`research/slice-030b-revert/` keeps `before/`, `stubs/`, `mutate.py`, `mkcase-cv1.py`, `old-l2-update.py`, `results.md` and the logs). `mutate.py` needs the reference, so it cannot run again. The red state with the stubs is confirmed with `scripts/test.sh` (`red.log`). Status: code.

## Code result (code agent, 2026-10-23)

`scripts/test.sh` exits 0: check 1.5 s, fmt 0.1 s, l0 5.8 s, l2 1.7 s, l3 9.7 s, selftest 7.6 s. `OPT=speed scripts/test.sh` exits 0 too (l2 86 s: the LLVM build, over the budget of the dev run, as for other slices). The L3 case `compilers/cv1-first-seen` passed 3 times in a row. No test, fixture or expected file changed. No stub signature changed.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Facts.roc` | 234 | `first_seen_all` (one fold with `first_seen`), `pin_all!` (steps 1 to 5 of section 2), private `record_new!` (one write, a busy or failed write is the warning of `settle!`) |
| `cli/lib/Nightlies.roc` | 401 | `pins`, `without_changed`, `auto_with_base`, the 6 steps in `list!` (`changed`, `dropped`). New public `same_nightly` (see below) |
| `cli/lib/Toolchain.roc` | 456 | `changed_failed`, `changed_warning`. Imports `Db` |
| `cli/lib/RocInstall.roc` | 395 | `offer!` (`auto_with_base` before the pick, `warn_changed!` after a pick or a `NotNamed`, `changed_failed` after a `PickError`), private `warn_changed!`. Imports `Facts`. `range_id!` is not changed |

| # | Decision that the slice does not fix | Rejected |
| --- | --- | --- |
| C1 | `Nightlies.same_nightly` (R-CV1) was private in `Nightlies`. It is now public, and `Toolchain.changed_failed` uses it. A new public function, no signature of the slice changed. | A second copy in `Toolchain` |
| C2 | `dropped` of `list!` is the releases of the list that are not in `kept` (the same order as the list). It has the same ids as the releases that `without_changed` took out. | A second filter with `changed` |
| C3 | `changed_failed` takes the first change with the tag (or the same nightly) before it tests a prefix, so the full tag wins over a prefix of 2 (L0 `pins` 4). | |

No question (TW17). No dispute. Compiler limits: the known ones only. A partial record pattern (`Ok({ sha256: Ok(x) })`) against a `Try` did not type-check (the brief names it), so `pins` uses 2 nested `match`.

## Verify results (revert check, TW12)

Script: `research/slice-030b-revert/agent-mutate.py` (the test agent `mutate.py` needs the deleted reference). Results: `agent-results.md`. Copy of the final code: `code-final/`, put back before each mutation and compared at the end: equal (`cmp` of the 4 files). 40 mutations, one after another: `roc check` (0 errors, 0 warnings), then L0 `pins`, then `scripts/test.sh l2 l3`. F01 and A01 did not compile in their first form (a warning, an unused variable) and were changed and run again.

Caught 39 of 40.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `first_seen_all` | F01 to F03 | L0 `pins` 3 |
| `pin_all!`, `record_new!` | F04 to F13 | L2 (`cv1-pins`, old cases `roc/up1-update`, `roc/us1-use`, `consent/dl1-resolve`, `consent/dl3-rank4`) and L3 `cv1-first-seen` (F07 to F09) |
| `pins` | N01 to N03 | L0 `pins` 1 |
| `without_changed`, `list!` | N04 to N08 | L0 `pins` 2 (N04), L2 `cv1-pins`, L3 |
| `auto_with_base`, `offer!` | A01, A03, A04, A06 (L0 `pins` 6), A05 (L2 `cv1-pins`), A02 not caught | |
| `changed_failed`, `changed_warning` | T01 to T07 | L0 `pins` 4 and 5 |
| `offer!`, `warn_changed!` | R01 to R06 | L2 `cv1-pins`, L3 |

| Not caught | Reason |
| --- | --- |
| A02 (`auto_with_base` adds all dropped releases, not only the base) | Equivalent change. The last filter keeps only ids that are in `auto` or the base, and `auto` (from `Toolchain.domain` of the kept releases) never has a changed tag. So the dropped releases that are not the base do not remain. Not a test gap. |


## Close (manager, 2026-10-23)

C1 to C3 of the code agent are accepted. The revert check caught 39 of 40; A02 is equivalent. `scripts/test.sh` exits 0 with no WARN. Status: done.
