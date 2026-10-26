# 071 `tln roc list` shows the git ref

Phase: P1. Status: done

Slice 071 is the plan row 071 of `PLAN-P1.md` (section 2c). It closes gap G8 of slice 045. R-R15 (design agent, 2026-10-25): `tln roc list` shows the repo and the ref that the user typed for each `git-*` id. The text is a proposal (R-OUT2, TW24). The row says that `--json` `data` gets `repo` and `ref` for those rows.

Where the data is stored (slice 045, R-R1): `toolchains/<id>/.talon.json` of a git build has `"repo":"https://github.com/<owner>/<repo>"`, `"sha"` (full) and `"ref"` (the text the user typed, a branch, a tag or a sha). `roc list` already reads this file for each id (one `read_files!` with 2 paths for each id: `.talon.json`, `.last-use`). So the slice adds no `Fx` call.

## 1. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-R15 | `roc list` shows repo and typed ref of each `git-*` id | L0 `ManageTest` (3 new `expect`s); L2 `roc/ls1-list` |
| R-R1 (as used) | The data is the `repo` and `ref` fields of `.talon.json` | L0 `origins`, L2 `ls1-list` |
| R-J3, R-OUT4 (as used) | The `--json` `data` holds what the text prints | L0 `ls_data`, L2 `ls1-list` run 2 |
| R-OUT2 (as used) | The table text is a proposal | L0 `ls_report`, L2 `ls1-list` run 1 |

## 2. Public signatures (done, in `cli/lib/Manage.roc` and `RocManage.roc`)

| Name | Signature | State |
| --- | --- | --- |
| `Manage.Origin` | `{ id : Str, repo : Str, ref : Str }` (`repo` and `ref` as stored in `.talon.json`) | done |
| `Manage.origins` | `List({ id : Str, meta : Manage.Read, last_use : Manage.Read }) -> List(Manage.Origin)` (manager review: keyed by id, not by position) | stub: `crash "todo: slice 071"` |
| `Manage.ls_report` | input gets a field `origins : List(Manage.Origin)`. A row finds its origin by `id` | type changed, body old |
| `Manage.ls_data` | the same new input field | type changed, body old |
| `RocManage.list_flow!` | builds `facts` with `origins: []` | stub (the old output) |

`Manage.Row` does not change: `Gc` uses it (a new field would change the rows of `GcTest`). `Manage.rows` does not change.

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Manage.origins` | One `Origin` for each item of the kind `Git` (`Manage.kind_of(id) == Git`) whose `meta` is a JSON object with a text `repo` and a text `ref` (`field_of`). The texts are as stored. The other items give nothing (the list is shorter). Order of `found` |
| 2 | `Manage.ls_report` | A row takes the first origin with its `id`; an origin whose id is no row is ignored. With at least one row that has an origin, the table has the column `SOURCE`, after `LAST USE` (which is padded to its widest cell). Else the table is as before. The cell is `<short repo>@<ref>`: a `repo` of the form `https://github.com/<owner>/<repo>` (2 non-empty parts, no more `/`) shows as `owner/repo`; any other text shows in full |
| 3 | `Manage.ls_data` | A `git` row has the keys `repo` and `ref` after `default`: the stored texts, raw (no shortening), or `null` and `null` when no origin has its id. Other kinds: no key |
| 4 | `RocManage.list_flow!` | `origins: Manage.origins(found)` (the stub line is a comment) |

The module `Manage.roc` has 412 lines now. The private reference had about 450 (limit 490).

## 4. Output (proposed, R-OUT2, TW24; accepted by the manager, 2026-10-25, with 2 changes that are in the table)

| Item | Text | Rejected |
| --- | --- | --- |
| Table | A fifth column `SOURCE`, `owner/repo@ref` (the form that `--git` takes, R-R14), `-` for a row with no origin. The column is there only when a row has an origin, so a store with no `git-*` build prints the table of slice 024 | The column always (it changes each table of the existing cases). The ref in the `ID` column |
| `repo` in the table | `owner/repo` for `https://github.com/<owner>/<repo>`; any other URL shows in full | A guess for other hosts |
| Row of a git build with no readable `repo` or `ref` | `-` | A guess from the id (`git-<sha8>` has no repo) |
| `--json` | `repo` (the stored URL, raw) and `ref` after `default` in a `git` row: text, or `null` and `null` for a git row with no origin. No key in the other kinds | The short form `owner/repo` in `data` (data is raw, manager review). The keys in all rows. A nested object `source` |
| Example, a table with 2 git builds | `  git-5a5a5a5a  git  2026-10-19  -  Karakatiza666/roc@my-branch` and `  git-dd03c09e  git  2026-10-18  -  roc-lang/roc@main` | |
| Example, `--json` row | `{"id":"git-dd03c09e","kind":"git","installed_at":"2026-10-18T08:00:00Z","last_use":null,"default":false,"repo":"https://github.com/roc-lang/roc","ref":"main"}` | |

## 5. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/ManageTest.roc` (driver `l0-1.roc`), `origins` (new) | 11 items in one list: 3 forms of the typed ref (a branch, a fork and a branch, a short sha), the field order of the JSON, a URL that is not `github.com` (stays raw), `repo` only, `ref` only, a `ref` that is not text, `not json`, a missing file, a nightly id and a link id with the same fields. The result is the 4 `Origin`s with their ids, in the order of the items | R-R15, R-R1 |
| L0 | same file, `ls_report` (new) | 6 rows with origins given in another order than the rows, and one origin of an id that is no row (ignored): the column, the padding of `LAST USE`, the `-` cells, a non-github URL in full; a deep github URL (`.../tree/x`) in full; a table with no origin has no column; a list with only an unmatched origin gives the table with no column | R-R15, R-OUT2 |
| L0 | same file, `ls_data` (new) | a nightly row (no key, also when an origin has its id), a git row with an origin (the raw URL), a git row with no origin (`null`) | R-R15, R-J3, R-OUT4 |
| L0 | same file, 6 old calls | `origins: []` added (the new input field) | |
| L2 | `tests/commands/cases/roc/ls1-list` (changed) | The store has 3 git builds: `git-dd03c09e` (full `.talon.json`, ref `main`), `git-5a5a5a5a` (a fork, `my-branch`), `git-7e7e7e7e` (no repo, no ref). Run 1 (table, `SOURCE` with the short form), run 2 (`--json`, raw URLs), run 3 (`home2`, no git build: no column), run 4 (no store). `calls.log`: the 3 new ids in the list read (no new call kind) | R-R15, R-R1, R-J3, R-OUT2, R-OUT4, R-LY1 |
| L3 | `tests/scenarios/compilers/mg1-manage` (changed, 1 line) | `expect/stdout`: the git row of `roc list --json` has `"repo":null,"ref":null` (its `.talon.json` is `{"format":1,"id":"git-dd03c09e"}`) | R-R15, R-J3 |

Counts: 3 new `expect`s (ManageTest), 6 changed calls, 1 changed L2 case (4 runs), 1 changed L3 line. New files (6 lines in `before/NEW.txt`): 4 files of the 2 new git dirs in `ls1-list/given/`. The old copies are in `research/slice-071-revert/before/`; the red stubs of `Manage.roc` and `RocManage.roc` are in `stubs/`.

The L3 case `mg1-manage` fails in the red state too (the stub does not print `repo` and `ref`). It is a case that the slice changes, not an old case that must pass.

Red run (2026-10-25, redone after the manager review, with the stubs): `l0-1`: 88 passed, 3 failed (`origins`: `todo: slice 071`; `ls_report` and `ls_data`: a wrong value). `tests/commands/run.sh roc/`: 18 passed, 1 failed (`roc/ls1-list`: no `SOURCE` column, no `repo` and `ref`; the `calls.log` is right). `tests/run.sh compilers/`: `mg1-manage` fails (the `--json` line). `roc check cli/main.roc`: 0 errors. `roc fmt --check`: pass.

## 6. Out of scope

| Item | Reason |
| --- | --- |
| `link-*` and `copy-*` rows | R-R15 names `git-*` only |
| The full sha in the table or in `data` | R-R15 names the repo and the typed ref. The id has the 8 digits |
| `roc list` of a build that `tln tool` made | The tool store has no `git-*` id of a compiler |

## 7. Questions

None. The design says what `roc list` shows (the repo and the typed ref). The form of the text is a proposal (TW24).

## 8. Revert check (private reference, deleted after the review)

| # | Mutation of the reference | Result |
| --- | --- | --- |
| 1 | `--json` shows the short `owner/repo` | `ManageTest` and `ls1-list` fail |
| 2 | The table keeps the URL | `ManageTest` and `ls1-list` fail |
| 3 | The column `SOURCE` for any origin, also one of an id that is no row | `ManageTest` fails |

The reference passed `l0-1` (91), `tests/commands/run.sh roc/` (19 cases) and `tests/run.sh compilers/` (21 cases). The earlier mutations of the first version (origin for other kinds, no `github.com` strip, always a column, keys for all kinds) were caught too; the rows that hold them stay.

## 9. Review

Accepted by the manager, 2026-10-25, with 2 changes (done): `origins` keyed by the toolchain id; `--json` `repo` is the stored URL.

## 10. Verify results (code agent)

Files: `cli/lib/Manage.roc` (456 lines: `origins`, `ls_report`, `ls_data`, helpers `origin_of`, `origin_for`, `short_repo`, `table` and `row_doc` with an origins input), `cli/lib/RocManage.roc` (the stub line replaced). No decision beyond the slice, no dispute, no question.

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | `--json` `repo` is the short `owner/repo` | `ManageTest` (l0-1) and L2 `roc/ls1-list` |
| 2 | The table shows the raw URL | `ManageTest` and `roc/ls1-list` |
| 3 | `origins` gives an item for every kind except `Copy` | `ManageTest` |
| 4 | An origin is found by `id !=` (wrong match) | `ManageTest` (2 expects) and `roc/ls1-list` |
| 5 | The column `SOURCE` for any origin (also an unmatched one) | `ManageTest` |

Caught 5 of 5. `Manage.roc` is the same as before the mutations (cmp).

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-071-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, all 3 slices in) | Exit 0, all 7 steps |
| Gap step | Skipped: all code-agent mutations caught (12 of 12 over the 3 slices), no new decision |
