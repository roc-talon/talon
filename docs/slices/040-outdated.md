# 040 `tln outdated`

Phase: P1. Status: done

Slice 040 is the plan row 040 of `PLAN-P1.md`. It needs 036 (done). It reuses the index step of 038 (`PickIndex`, `Pick` domain rules), the compiler list and the facts of 037 (`ProbeRange.found`, `Facts.load!`), and the project steps of `list` (010) and `why` (011).

The private reference has 216 added lines of code (without comments and empty lines): `Outdated.roc` 96, `OutdatedFlow.roc` 114, `Pick.newest_in` 2, `Run` 2, `main` 2. The row said about 250. This is under 450, so there is no split. The private reference was deleted after the review (2026-10-24).

## 1. Rules, and the tests that name them

R-CM6 names no other rule. The design gives one line for the command ("Table: current, wanted, latest, nightly range", Bun `outdated`) and these facts in other rules: R-DI1 ("the rows of `tln outdated`" are listed), R-DI11 (the `fixed:` line), R-PD14 (it uses a project), R-AP30, R-PU28, R-PU30 and R-MV5 (registry notes, P2). `DESIGN.md` R-PH3 note: "`outdated` shows nightly ranges, which need evidence".

| Rule | Content | Tested by |
| --- | --- | --- |
| R-CM6 | The table and its 4 columns | L0 `outdated.roc` expects 1, 4. L2 `od1-table` runs 1 to 7, `od2-edges` |
| R-DI1 | Only the rows of the table are listed: one index read for the groups with an index, no read for a group with no row to show. The compiler list is read only when a row is behind | L2 `od1-table` runs 1, 4 (`calls.log`) |
| R-DI11 | A host with no index has no row and one line `fixed: <host> has no index without a registry` | L0 `outdated.roc` expect 4. L2 `od1-table` runs 1, 4 |
| R-DI12 | `--offline`: cached pages, `index: cached at <time>`, a group with no page acts as an anchor (no row) | L2 `od1-table` runs 5, 6 |
| R-C1, R-UP10 | `wanted`: the newest release of the group that the ranges admit (the key of `talon.toml`, an anchor, the implied range `^<version>`, R-I4) | L0 `outdated.roc` expect 2. L2 `od1-table` run 1 (json, util, pf), `od2-edges` |
| R-C7 | A release that min-release-age or the snapshot hides is no candidate | L0 `outdated.roc` expect 2. L2 `od1-table` run 1 (parser) |
| R-C9 | The header value is always a candidate (also when young, also when the list lacks it) | L0 `outdated.roc` expect 2 |
| R-UP1, R-UP12, R-UP3 | `latest`: the newest release of the URL form in any series, no range. Another series: `(new series)` | L0 `outdated.roc` expect 2. L2 `od1-table` run 1 |
| R-DI5 | A release in another URL form is no candidate | L0 `outdated.roc` expect 2 |
| R-PB3, R-PB4, R-EP5, R-EP6, R-EP11, R-EF1 | The nightly range of the current release from known facts (no probe), the `?` mark of an end that is no real fact, `none known`, `-` for no compiler list | L0 `outdated.roc` expect 3. L2 `od1-table` runs 1, 6, `od2-edges` |
| R-PD5 | The members: the current member, else all members | L2 `od2-edges` runs 1 to 3 |
| R-PD9, R-PD14 | The project is recorded | L2 `od1-table` run 1, `od2-edges` run 1 (`tree.diff`, `calls.log`) |
| R-WS1, R-I2, R-I3, R-WS7 | A key of the root `talon.toml` limits the group in each member. A key in the `talon.toml` of one member limits the shared group for every member | L2 `od2-edges` runs 1 to 3 (root key), run 4 (key in member a only) |
| R-FL4 | `--quiet` keeps the table (it is the answer) | L2 `od1-table` run 3 |
| R-FL5, R-FL7, R-EC2 | The checks of `Opts.read`; no name; the resolve flags are usage failures | L0 `outdated.roc` expect 1. L2 `od1-table` runs 7, 8 |
| R-J3, R-OUT4 | `--json`: only the envelope, `data` has each fact of the table | L0 `outdated.roc` expect 4. L2 `od1-table` run 2, `od2-edges` run 3 |

## 2. Public signatures (stubs, `crash "todo"`)

| Name | Signature | File |
| --- | --- | --- |
| `Outdated.Range` | `[Known(ProbeRange.Found), Unread]` | `cli/lib/Outdated.roc:29` |
| `Outdated.Row` | `{ alias, name, current, wanted, latest : Str, new_series : Bool, range : Outdated.Range }` | `cli/lib/Outdated.roc:32` |
| `Outdated.Member` | `{ file : Str, rows : List(Row), fixed : List(Str) }` (`fixed` are hosts) | `cli/lib/Outdated.roc:35` |
| `Outdated.read` | `Args -> Try({}, Fail)` | `cli/lib/Outdated.roc:42` |
| `Outdated.versions` | `{ current : Str, ranges : List(Str), list : List(Index.Candidate), now : U64, min_age : U64, snapshot : Try(U64, [None]) } -> { wanted : Str, latest : Str, new_series : Bool }` | `cli/lib/Outdated.roc:54` |
| `Outdated.range_of` | `{ hash : Str, domain : List(Str), facts : List(Db.Fact) } -> Outdated.Range` | `cli/lib/Outdated.roc:58` |
| `Outdated.range_text` | `Outdated.Range -> Str` | `cli/lib/Outdated.roc:62` |
| `Outdated.behind` | `Outdated.Row -> Bool` | `cli/lib/Outdated.roc:66` |
| `Outdated.text` | `Outdated.Member -> Str` | `cli/lib/Outdated.roc:78` |
| `Outdated.data` | `List(Outdated.Member) -> JsonDoc` | `cli/lib/Outdated.roc:89` |
| `OutdatedFlow.run!` | `Fx, Args => I32` | `cli/lib/OutdatedFlow.roc:24` |
| `Run.run!` | dispatches `args.command == ["outdated"]` to `OutdatedFlow.run!` (wired, not stubbed) | `cli/lib/Run.roc:79` |

The wiring is not stubbed: `Run`, `main.roc` (the two new exposes). The pure part is its own module on purpose: a unit file that imports a module with `run!` (which imports `Install`, `Resolve` and more) takes 1.1 s in `roc test`, one that imports the pure part 0.4 s, and the step l0 is near its budget.

## 3. The tested reading (rules of the command)

| # | Rule | Source |
| --- | --- | --- |
| 1 | The members are the current member, else all members. Each member is one block of output. One `Vars.build` over all members (as the resolve commands do): a key of any member limits the shared group for every member. A member shows the groups that it uses. The alias and `current` are of the first use in that member | R-PD5, R-PD14, R-WS7 |
| 2 | One row for each group with an index (`host` is `Indexed`) that is behind. The alias is the alias of the first use, `current` is its version. The platform is a group like the others. A path entry and a foreign URL are no group | R-WS1, R-H4 |
| 3 | `wanted`: the candidates of the group of `current`, the ranges of the group (R-C1), R-C7, R-C9: the newest by version number | R-UP10, R-C1, R-C7, R-C9 |
| 4 | `latest`: the candidates of the URL form of `current`, any series, no range, R-C7, R-C9: the newest. `new_series` when its group is not the group of `current` | R-UP12, R-UP1, R-UP3 |
| 5 | A row is shown when `current` differs from `wanted` or from `latest` (`Outdated.behind`) | question Q1 |
| 6 | A group with no cached page offline (`missing`) has no candidate, so no row | R-DI12 |
| 7 | A `Fixed` host has no row. Each such host (no repeat) gives one line | R-DI11 |
| 8 | The nightly range is of the `current` release (its hash). D is the compiler list (`PickLoop.releases!`, the candidates with one asset), read at most once and only when a row is behind. The facts are one `Facts.load!` for the keys (hash of each row, each release of D, `any`). `ProbeRange.found` with no askable release gives the range. An empty D is `Unread` and makes no query | R-PB3, R-EP11, R-EF1, questions Q2, Q4 |
| 9 | No probe, no archive download, no compiler download, no write of a header or `talon.toml`. The run records the project (R-PD9) and, as every command that reads the index or the compiler list, writes the index cache pages (R-DI2) and the first-seen sha256 rows (R-CV6) | R-PD9, R-DI2, R-CV6, question Q4 |
| 10 | The exit code is 0 when the report was made, also when rows are behind | question Q3 |
| 11 | A name is a usage failure. `--quiet` does not hide the table. `--json` prints only the envelope | R-CM6, R-FL4, R-J1 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/outdated.roc` expect 1 (11 rows) | `Outdated.read`: ok forms, a name or a selector, the registry check first, the resolve flags rejected by `Args.parse` | R-CM6 R-FL5 R-FL7 R-EC2 R-E4 |
| L0 | `tests/unit/outdated.roc` expect 2 (18 rows) | `Outdated.versions`: range, no range, anchor, tilde, 2 ranges, same series is newest, young hidden, all newer young, header value young, exactly at min age, snapshot, other URL form, current is newest, header value not in the list, empty list, number order (2.10.0 above 2.9.0), pre-1.0 series, no release URL | R-C1 R-C7 R-C9 R-UP1 R-UP3 R-UP10 R-UP12 R-DI5 R-DI10 |
| L0 | `tests/unit/outdated.roc` expect 3 (10 rows) | `Outdated.range_of`, `range_text`: no fact, real ends, unknown ends, the ends of D, one real end, only fails, other hash, release not in D, build fact, empty D | R-PB3 R-PB4 R-EP5 R-EP6 R-EP11 R-EF1 |
| L0 | `tests/unit/outdated.roc` expect 4 | `Outdated.behind` (4 rows), `Outdated.text` (padding, header row, `(new series)`, `-`, 2 fixed lines, `all packages are up to date` with and without a host), `Outdated.data` (2 members, all 3 range states, a member with no row) | R-CM6 R-DI11 R-OUT4 R-J3 |
| L2 | `outdated/od1-table` run 1 | p1: 7 entries. Rows pf, json, parser, util; no row for lib, ext (fixed line) and loc (path). The calls: the load, 5 index reads, the compiler list, the pins, one db query with 24 keys | R-CM6 R-DI1 R-DI11 R-C1 R-C7 R-C9 R-UP1 R-UP3 R-UP10 R-UP12 R-PB3 R-PB4 R-EP6 R-PD9 R-PD14 |
| L2 | same, run 2 | `--json` of run 1 | R-J3 R-OUT4 |
| L2 | same, run 3 | `--quiet`: the table stays | R-FL4 |
| L2 | same, run 4 | p2: lib and ext only. `all packages are up to date`, the fixed line, no compiler list, no db query | R-DI1 R-DI11 |
| L2 | same, run 5 | p3 offline: json cached, solo has no page (no row), compiler list cached, `index: cached at` | R-DI12 R-PB3 |
| L2 | same, run 6 | p4 offline, no compiler list: the range is `-`, no db query | R-DI12 R-EP11 |
| L2 | same, runs 7, 8 | a name: exit 2. `--snapshot`: exit 2 | R-CM6 R-FL5 R-FL7 |
| L2 | `outdated/od2-edges` run 1 | workspace root: both members, the key of the root file, 3 releases of json, the index read once | R-PD5 R-WS1 R-I3 R-WS7 R-DI1 R-PD9 |
| L2 | same, run 2 | `--file apps/a/main.roc`: member a only | R-PD5 |
| L2 | same, run 3 | `--file apps/b/main.roc --json`: member b only | R-PD5 R-J3 |
| L2 | same, run 4 | second workspace `ws2`: the key `json = "~2.1"` is in the `talon.toml` of member a only. `--file ws2/apps/b/main.roc` shows member b with `wanted` 2.1.5, not 2.2.0 | R-WS7 R-I2 R-WS1 R-PD5 |

L0 `expect`s: 4 in one new file (143 lines, 0.4 s in `roc test`). Deep cases: 2 (`od1-table` 8 runs, `od2-edges` 4 runs). The generator is `research/slice-040-revert/gen-od.py` (it deletes and writes the case dirs, so it must not run again: the reference that wrote the expected files is deleted). L3: no new scenario (L2 runs the whole `Run.run!`; the real `roc` is not needed).

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| A member | the project file, then the table, then the `fixed:` lines | od1, od2, `outdated.roc` expect 4 |
| The table | a header row `package  current  wanted  latest  nightly range`, then one row per group, each column padded to the longest cell plus 2 spaces (the last is not padded), 2 spaces at the start of a line | same |
| `latest` in a new series | `3.0.2 (new series)` | od1 run 1 |
| Nightly range | `<from> .. <to>` (full compiler ids). A `?` after an end that is no real fact (R-PB4). `none known`: no real pass. `-`: no compiler list | od1 runs 1, 6, od2 |
| Nothing behind | `  all packages are up to date` (and the `fixed:` lines) | od1 run 4, expect 4 |
| Fixed host | `  fixed: <host> has no index without a registry` (the text of R-DI11) | od1 runs 1, 4 |
| A name | `tln: error[usage]: tln outdated takes no name`, exit 2 | od1 run 7, expect 1 |
| `--json` `data` | `{ "members": [ { "file", "packages": [ { "alias", "name", "current", "wanted", "latest", "new_series", "nightly_range" } ], "fixed": [ <host> ] } ] }`. `nightly_range` is `{ "state": "range", "from": { "id", "real" }, "to": { ... } }`, `{ "state": "no-pass" }` or `{ "state": "unread" }` | od1 run 2, od2 run 3, expect 4 |
| Index notes | the existing lines on stderr (`index: cached at <time>`, warnings of `Index.candidates`) | od1 runs 5, 6 |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `wanted` is the newest release in the range among the candidates. It looks at no closure rule (R-C2, R-C3) and no fact of the unit checks. So it can name a release that `tln update` would not take | the result of the `update` resolve (needs the closure walk and probes: it breaks "from known facts"). Question Q6 |
| D2 | The row is per group, not per alias. The alias is the first use | one row for each use |
| D3 | A group with no cached page offline has no row | a note for the group |
| D4 | The platform is a row (alias `pf`) | no platform row |
| D5 | The nightly range column is for the `current` release | `latest`, or one column for each of the three (question Q2) |
| D6 | The ends of the range print full compiler ids | the date only (two nightlies can have one date) |
| D7 | The members are limited as in `tln list`: the current member, else all members. The variables are built over all members (R-WS7, as the resolve commands do) | one `Vars.build` for each shown member (changed in the review, Q8) |
| D8 | The compiler list is read for the facts only when a row is behind | always |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-AP30, R-PU28, R-PU30, R-MV5 (index stale notes, `moved to <successor>`, a recreated repository) | They need the registry (P2) |
| Out 2 | R-SM6: a smoke row of another target "can" be shown | No smoke rows before P2 |
| Out 3 | The `roc:` pin as a row (the nightly) | R-CM6 names the nightly range only. `tln upgrade roc` is the nightly (039) |
| Out 4 | R-C6 (yanked releases) | `direct` has no yank data (P3). `Index.candidates` skips drafts and prereleases (tested in slice 003) |

| Id | Question | Options | Tested reading |
| --- | --- | --- | --- |
| Q1 | Which rows does the table show? | (a) only a group that is behind (`current` differs from `wanted` or `latest`), as Bun. (b) every group with an index | (a). `Outdated.behind`. With (b) the nightly range of an up to date package is shown too |
| Q2 | The nightly range is of which release? | (a) `current`: the facts exist from the earlier checks. (b) `latest`: "can I move?", but a new release has no fact. (c) a column for each | (a) |
| Q3 | The exit code when something is behind | (a) 0: a report, as `tln probe` (U6 (a)). (b) a code for CI, as `npm outdated` (1) | (a). R-EC has no code for it, and 1 is `internal` |
| Q4 | What may `outdated` write? R-CM6 says nothing. The index read writes cache pages (R-DI2), the compiler list writes first-seen sha256 rows to `compat.db` (R-CV6), and R-PD9 records the project | (a) these 3 writes, no project file (the shared code of the other commands). (b) no write of `compat.db`: D comes from the facts only (no compiler list, the ends of the range then have no neighbour, so all are `?`). (c) no cache write | (a). The tests show the writes in `tree.diff` and `calls.log` |
| Q5 | A newer release that min-release-age hides | (a) it is no candidate (R-C7, as `update` and `upgrade`). (b) it is shown with a mark | (a) |
| Q6 | What `wanted` means | (a) the newest release in the range (D1). (b) the version that `tln update` would choose | (a) |
| Q7 | The platform entry in `latest` of a new series: R-C3 ties a package to its platform URL, so `latest` of a package can need another platform | (a) `outdated` does not look at it. (b) a note | (a). `tln upgrade` reports the reason (R-UP2) |
| Q8 | In a workspace, a key of `talon.toml` in member a limits the group in member b too (R-WS7) | (a) each member alone. (b) the variables of all members, the rows of the shown members | Answered (b), see the review. Test: `od2-edges` run 4 |

U1 to U6 of `PLAN-P1.md` section 6 do not change this slice. Q3 follows U6 (a).

## 8. Compiler and tool limits met (for the code agent)

| Id | Limit | Workaround |
| --- | --- | --- |
| C1 | `roc check` exits non-zero on a warning: a constant `if` (`if Bool.False ...`) is a warning, so a mutation with one does not compile | write a mutation with a real condition |
| C2 | The generator deletes a case dir with its `expect/` | Do not run `gen-od.py` again: the reference that wrote the expected files is deleted. `expect-copy/` has a copy of the cases |

No compiler bug found. The roc object cache was not used (`--no-cache` in all runs).

## 9. Notes for the code agent

| Topic | Note |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/outdated/*/rules` has the text of each run |
| Modules | `Outdated` is pure and must not import `Install`, `Resolve`, `ResolveLoad`, `PickIndex`, `Facts` or `Nightlies` (the L0 file compile time). `OutdatedFlow` has the effects |
| `Outdated.versions` | The reference gets both values from `Pick` (the domain rules 1 to 3): a slot `{ id: "", is_platform: False, ranges, current: Ok(url), hold: Free, named: Err(None), candidates, files: [] }` and a new public `Pick.newest_in` (a new public function for the code agent: the body of `Pick.newest` with the ranges of the slot kept; `Pick.newest` calls it with `ranges: []`). `wanted` candidates: `Index.in_group`. `latest` candidates: the `group.form` of `current`. An empty domain gives the header value |
| `OutdatedFlow.flow!` | `Install.begin!`, `Known.record!` with `Install.canonical_files!`, a `ResolveBase.Request` as `Ls.walk_full!` makes it (`command: Update`), `ResolveLoad.load!`, `ResolveBase.settings_of` (for `min_age`), one `Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })` (as `ResolveLoad.prepared!`), and for each shown member the variables that have a use in its file (the alias and `current` are of that use; `ranges` are the ones of the variable), `PickIndex.index!` once for the names of the `Indexed` groups (and the URLs of all uses as `known`), `Outdated.versions` for each group, then only for the rows that are behind: `Nightlies.candidates(PickLoop.releases!(fx, request))` and one `Facts.load!` with the keys (hash, release, `any`) of those rows |
| Calls | No `probes!`, no `spawn_all!`, no `copy_tree!`, no `write_atomic!` of a project file, no compiler call (`path_roc!`, `roc version`): the expected `calls.log` has none |
| Output | `Outdated.text` for each member, or `Out.json_ok({ command: args.typed, data: Outdated.data(members) })`. Print with `fx.out!` (the table is the answer: `--quiet` does not hide it). Failures with `Common.failed!` |

## 10. Changed old tests (TW21)

None. The 99 old L2 cases, the L3 cases and the old L0 files pass with the reference (`Pick.newest_in` is new, `Pick.newest` has the same result). `Run.roc` and `main.roc` have 2 new lines each (copies in `research/slice-040-revert/before/cli/lib/`).

## 11. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Red (stubs, `red-run.log`) | l0: `outdated.roc` 4 of 4 fail (`Roc application crashed with this message: todo`), the other files pass. l2: `od1-table` and `od2-edges` fail (`[ROC CRASHED] todo`), the other 99 cases pass. check, fmt, l3, selftest, l1 pass. Steps: check 1.3, fmt 0.1, l0 7.9, l2 5.4, l3 9.8, selftest 11.2, l1 28.2 |
| Green (reference, `green-run.log`) | all steps pass in dev: check 1.3, fmt 0.2, l0 8.0, l2 4.9 (101 cases), l3 9.7, selftest 11.2, l1 29.6 (budgets 10, 5, 10, 30, 60, 20, 60). The expected files come from the dev build. Not run with `OPT=speed` |

Revert check: 11 mutations of the reference, and one hand mutation after the review (M15) (`research/slice-040-revert/mutate.py`, log `mutate.log`), filtered runs only (L0 file, and the 2 cases). A mutation that did not compile (a constant `if`, C1) was written again.

| Id | Mutation | Result |
| --- | --- | --- |
| M1 | `wanted` ignores the ranges | caught (`outdated.roc`, `od1-table`) |
| M2 | min-release-age hides nothing | caught (`outdated.roc`, `od1-table`) |
| M3 | `latest` stays in the series of `current` | caught (`outdated.roc`, `od1-table`) |
| M4 | `Outdated.behind` ignores `latest` | caught (`outdated.roc`) |
| M4b | the same in the flow (`is_behind`) | caught (`od1-table`) |
| M5 | the compiler list and the db are read also when no row is behind | caught (`od1-table` run 4) |
| M7 | an end that is no real fact has no `?` | caught (`outdated.roc`, `od1-table`, `od2-edges`) |
| M8 | a current member does not limit the members | caught (`od2-edges`) |
| M9 | `--quiet` hides the table | caught (`od1-table` run 3) |
| M10 | the project is not recorded | caught (`od1-table`, `od2-edges`) |
| M14 | an empty compiler list gives `none known` in place of `-` | caught (`outdated.roc`, `od1-table` run 6) |

| M15 | review (Q8): `Vars.build` over the shown members only | caught (`od2-edges` run 4: `wanted` 2.2.0 in place of 2.1.5, `mutate-3.log`) |

No mutant survives. `od2-edges` was changed after the run of M1 to M14 (a third release of json, so that the key of the root file matters). M1, M3 and M8 were run again with it (`mutate-2.log`): caught.

## 12. Files

| File | Lines | State |
| --- | --- | --- |
| `docs/slices/040-outdated.md` | this file | new |
| `cli/lib/Outdated.roc` | 91 | new, stub |
| `cli/lib/OutdatedFlow.roc` | 26 | new, stub |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +3, +2 | changed (copies in `research/slice-040-revert/before/cli/lib/`; `Pick.roc` is only in the reference) |
| `tests/unit/outdated.roc` | 143 | new |
| `tests/commands/cases/outdated/{od1-table,od2-edges}/` | 8, 6 runs | new (`od2-edges` has 2 gap runs) |
| `research/slice-040-revert/` | | `before/` (with `NEW.txt`), `stubs/`, `reference.sha256` (the hashes of the deleted reference), `expect-copy/`, `gen-od.py`, `mode.sh`, `mutate.py`, `od1-rules.txt`, `od2-rules.txt`, logs |

## Review (manager, 2026-10-24)

Accepted, with one change (Q8). The answers:

| Id | Answer |
| --- | --- |
| Q1 | Accepted: only rows that are behind |
| Q2 | Accepted: the range of the current release |
| Q3 | Accepted: exit 0. The manager adds `outdated` to the user's question U6 (exit codes of report commands) |
| Q4 | Accepted. The cache pages, the `compat.db` first-seen rows and the `projects.json` record come from shared code and are not project files. No header and no `talon.toml` is written |
| Q5, Q6, Q7 | Accepted |
| Q8 | Changed. R-WS7: a key in one member's `talon.toml` limits the shared group for every member, as the resolve commands do (one `Vars.build` over all members). `od2-edges` run 4 is new (a key in member a only, member b has `wanted` 2.1.5). The test agent made the change in the reference, ran one hand mutation (M15, caught), and deleted the reference |
| D1 to D8 and the TW24 texts | Accepted (D7 is changed as Q8) |
| `Pick.newest_in` | Accepted as a new public function for the code agent (listed in the notes of section 9) |

Red state after the review: `scripts/test.sh` fails only `outdated.roc` (L0, 4 of 4, `todo`) and the 2 `outdated` L2 cases.

## Code result (code agent, 2026-10-24)

`scripts/test.sh` exits 0: check 1.2, fmt 0.1, l0 7.6 (a cold build: 10.0), l2 4.8, l3 9.7, selftest 11.3, l1 30.9 (budgets 10, 5, 10, 30, 60, 20, 60). `OPT=speed`: all pass, l2 209 s (over budget, known).

| File | Lines | State |
| --- | --- | --- |
| `cli/lib/Outdated.roc` | 170 | stubs replaced |
| `cli/lib/OutdatedFlow.roc` | 121 | stub replaced |
| `cli/lib/Pick.roc` | 447 | `Pick.newest_in` new (7 lines), `Pick.newest` calls it with `ranges: []` |
| `cli/lib/Ls.roc` | 104 | `Ls.request_of` new (the `ResolveBase.Request` literal that `walk_full!` had, so `OutdatedFlow` does not copy it) |

| Topic | Decision (not fixed by the slice) | Rejected |
| --- | --- | --- |
| Request | `OutdatedFlow` calls `Ls.request_of(args, start)` and sets `command: Update` | one more copy of the 20-line record |
| Index names | The groups of the shown members only (`od2-edges` runs 2, 3 read 2 repositories, run 1 reads 3). `known` for `Index.candidates` is the URLs of all uses of all variables | the names of all variables |
| `latest` | `Pick.newest` (ranges `[]`) over the candidates of the URL form of `current` | a second function |
| Missing page offline | No special case: the list is empty, `versions` gives `current` for both, so `behind` is false | an extra check of `missing` |
| Facts keys | One key for each (hash of a behind row, release of D), the hashes with no repeat. `Facts.load!` makes no call with no key | the keys of all rows |
| `Err` tags | Private `Try` tags `NoIndex`, `NoHost`, `NoRow` (no `Err` record with a `Bool` field) | |

No test, fixture or expected file was changed. No dispute rows. No question (TW17). No compiler bug found. Limits met: `package` is a reserved word (also as a field name), a record field `package` failed to parse; the fields are `alias`, `current`, `wanted`, `latest`, `range`.

## Verify results (code agent)

Files: `research/slice-040-revert/agent-mutate.py`, `agent-mutate.log`, `agent-results.md`, `code-final/`, `code-final.sha256`. The code after the mutations equals `code-final/` (`sha256sum -c code-final.sha256` from the repo root: 4 files OK).

| Id | Mutation | Result |
| --- | --- | --- |
| M1 | `wanted` ignores the ranges | caught (`outdated.roc`, `od2-edges` run 4) |
| M2 | min-release-age is 0 | caught (`outdated.roc`, `od1-table`) |
| M3 | `latest` stays in the series of `current` | caught (`outdated.roc`, `od1-table`) |
| M4 | `behind` ignores `latest` | caught (`outdated.roc`, `od1-table`) |
| M5 | the compiler list and the db are read when no row is behind | caught (`od1-table` run 4) |
| M6 | `Vars.build` over the shown members only (Q8) | caught (`od2-edges` run 4) |
| M7 | no `?` after an end that is no real fact | caught (`outdated.roc`, `od1-table`, `od2-edges`) |
| M8 | the current member does not limit the members | caught (`od2-edges`) |
| M9 | the project is not recorded | caught (`od1-table`, `od2-edges`) |
| M10 | the index is read for the groups of members that are not shown | caught (`od2-edges`) |
| M11 | a fixed host of 2 groups is listed twice | closed by the gap test: `od2-edges` run 5 (hand mutation: the run fails with a second `fixed: example.org` line) |
| M12 | `-` in place of `none known` | caught (`outdated.roc`, `od1-table`) |
| M13 | `none known` in place of `-` for an empty list | caught (`outdated.roc`, `od1-table` run 6) |
| M14 | padding of 1 space | caught (`outdated.roc`, `od1-table`) |
| M15 | alias and `current` of the first use of any member | closed by the gap test: `od2-edges` run 6 (hand mutation: the run fails with `jx 1.1.0` in place of `k 1.0.0`) |

Caught 13 of 15. Both gaps are in `agent-results.md` with the test that would catch them. No equivalent change.

## Gap tests (test agent, 2026-10-24)

Two runs are new in `od2-edges` (the case has 6 runs). Only tests and this file were edited. The old copy of the case is in `research/slice-040-revert/gap-before/`: the expected files of runs 1 to 4 did not change. The diff has only added lines, and one changed line of `tree.diff` (the `projects.json` record has the 2 new member files). `od1-table` did not change.

| Gap | Test | Check |
| --- | --- | --- |
| M11: a `Fixed` host that 2 groups have is listed twice | `od2-edges` run 5: `--file ws3/apps/a/main.roc`. Member a has jx 1.1.0 (releases 1.0.0 to 1.2.0) and 2 entries on example.org (e1, e2: 2 groups, 1 host). Expected: one `fixed: example.org ...` line (R-DI11, rule 7 of section 3) | M11 applied by hand (`fixed: hosts` with no dedupe): the case fails with a second `fixed:` line |
| M15: `alias` and `current` are of the first use in any member | `od2-edges` run 6: `--file ws3/apps/b/main.roc`. Member b has the alias `k` for jx 1.0.0, member a has `jx` 1.1.0 (one group). Expected: `k  1.0.0` (rule 1 of section 3) | M15 applied by hand (the first use of any member): the case fails with `jx 1.1.0` in place of `k 1.0.0` |

After each mutation, `cli/` was copied back from `research/slice-040-revert/code-final/`: `sha256sum -c research/slice-040-revert/code-final.sha256` is OK for each file. The log is `research/slice-040-revert/gap-mutate.log`. The rules text of the case and `od2-rules.txt` have runs 5 and 6.

## Close (manager, 2026-10-24)

The code decisions are accepted (`Ls.request_of` shared by `ls` and `outdated`; the index read for the shown members only). The code agent ran 15 targeted mutations: 13 caught; M11 and M15 are closed by `od2-edges` runs 5 and 6. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 8.3 to 8.5 s). Q3 (exit 0) is part of the user's U6. Status: done.
