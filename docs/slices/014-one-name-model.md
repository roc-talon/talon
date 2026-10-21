# 014 One name model

Phase: P0. Status: done

This slice tests the decision `docs/design-gaps/G-tie-names.md` (applied to the design files: `docs/design-gaps/APPLIED.md`, rows TN1 to TN4) and the item that slice 013 moved here (the R-SO20 note in `data.notes`). It follows `docs/agents/BRIEF-tests.md`. The earlier slices are not committed: the pre-slice copies of the changed files are in `research/slice-014-revert/before/` (with `NEW.txt`).

## Rules

R-SC1, R-SC6, R-SC14, R-SC15, R-SC16, R-WS8 (changed or new in the design). Also R-SO20 (the `--json` part, from slice 013), R-RV1 (`remove` of one of 2 entries of a repo), R-AD22 and R-SP5 (`update X@sel` is a move), R-SL4 (`@2` is `^2`).

The model in one table (G-tie-names section 3). A scope gives each package one unique printed name. `X@sel` filters by version, or by series, depending on the command.

| Item | Rule |
| --- | --- |
| Entity | `alias`, `name` (full name, no `@series`), `series`, `version`, `note`. An unmanaged entry (path entry, foreign URL) has no name, series or version (R-SC6). |
| Forms | 1 alias, 2 full name, 3 short name. First form with a match wins. An alias that names 2 groups is 2 matches (R-WS8). |
| Printed name | The full name. `@series` is added when the scope has 2 or more series of that name (R-SC15). It uses the whole scope, not only the matches. |
| `find` (`why`, `remove`) | `sel` is a version filter (`@2` is `^2`). 1 or more left: used, or a tie. 0 left: `'<x>' is not in the project`. An unmanaged entry never matches a selector. |
| `find_move` (`update`) | `sel` is the target. 1 match: used, also for a new series. 2 or more: keep the series of `sel`. 1 left: used. 0 left: tie with the alias line. A selector with no single series (`latest`, `*`, `0.x`, `>=1.0.0`) keeps all matches. |
| Tie text | `"<name>" matches <n> packages. Use a name from the list.` The list is before it. In `find_move`, with a series that no match has, and a distinct alias for each match: `Use the alias of the entry to move: tln update <alias>@<sel>`. |
| Scope per command | `why`: the closure. `remove`, `update`, `add`: header entries. `list` takes no name (R-CM9, tested by `listing.roc` and `ls1-list`). |

## Public signatures (stubs)

| Item | Signature |
| --- | --- |
| `Lookup.Entity` | `{ alias : Str, name : Str, series : Str, version : Try(Str, [None]), note : Str }` (new `series`, `version`) |
| `Lookup.Fact` | `{ alias : Str, what : [Release({ name : Str, series : Str, version : Str }), Unmanaged], role : [Platform, Direct, Via(Str)] }` |
| `Lookup.build` | `List(Lookup.Fact) -> List(Lookup.Entity)`. The one entity builder. `crash "todo"` |
| `Lookup.printed` | `List(Lookup.Entity), Lookup.Entity -> Str`. `crash "todo"` |
| `Lookup.find` | `Scope, Ref, List(Lookup.Entity) -> Try(Lookup, { fail : Fail, block : Str })`. The stub keeps today's behavior. A command that does not move. |
| `Lookup.find_move` | Same type. A command that moves. `crash "todo"` |
| `Lookup.Existing` | Payload `{ alias, name, series }` (new `series`: with the alias and name it names one entity) |
| `Why.row_facts` | `List(Closure.Row) -> List(Lookup.Fact)`. `crash "todo"`. Replaces `Why.entities` |

The doc comments of `cli/lib/Lookup.roc` and `Why.row_facts` hold the tables. `Why.entities`, `PickFlow.entities_of` and the builder of `RemoveFlow.removal_plans!` stay as stubs that add `series` and `version` (a compile fix): the code agent replaces them.

## Files

| File | Change |
| --- | --- |
| `cli/lib/Lookup.roc` | Types, doc, stubs (above) |
| `cli/lib/Why.roc`, `PickFlow.roc`, `RemoveFlow.roc` | The 2 new fields in the old builders. `Why.row_facts` (stub) |
| `tests/unit/lookup.roc` (256 lines), `why.roc` (245), `vars.roc` (237, 1 row) | L0 |
| `tests/commands/cases/remove/rm1-flow/` | +3 runs (7 to 9), +project `r6`, expected files, `rules` |
| `tests/commands/cases/resolve/rs-failures/` | +2 runs (11, 12), +projects `walias` and `names`, expected files, `rules` |
| `tests/scenarios/why/wy1-why/cmd` | +5 runs, expected files |
| `tests/scenarios/update/up1-update-entries/cmd` | +1 run (`--json` with the R-SO20 note), expected files |
| `tests/scenarios/remove/rm2-workspace/cmd` | +1 run (`--dry-run --json` with the R-SO20 note), expected files |
| `research/slice-014-revert/` | `before/`, `mutate.py`, `results.md`, `cli-stub.sha256` |

## Tests

| Layer | File and case, and what it checks | Rules |
| --- | --- | --- |
| L0 | `tests/unit/lookup.roc` expect 1 (`Install`): the old rows with the new entity fields. A header alias, `New` for a full name, a short name is an error | R-SC6 R-SC7 R-AD1 R-AD2 R-AD6 R-SC2 |
| L0 | `lookup.roc` expect 2 (`build`, `printed`): 9 facts. The roles and notes, an unmanaged entry, the dedup of a workspace (same alias, name, series), the same alias with 2 groups stays, facts with no alias stay, the printed name uses the whole scope | R-SC1 R-SC6 R-SC14 R-SC15 R-WS8 |
| L0 | `lookup.roc` expect 3 (`find`, 27 rows). The forms, the tie text and list. P0 bug 1: `roc-lang/http@2` with 2 entries. P0 bug 2: `http@2` and `text@1` (a short name with a series). P0 bug 3: `json@3` is not in the project. `acme/text@2.5.0`, `latest`, an exact version, an unmanaged entry with a selector, 3 matches with `acme/text@1` and `other/text` | R-SC1 R-SC6 R-SC7 R-SC8 R-SC14 R-SC15 R-SC16 R-SL4 |
| L0 | `lookup.roc` expect 4 (R-WS8, 4 rows): an alias of 2 groups is a tie in the same list, with `Use a name from the list.`. `pf@0.12` picks one | R-WS8 R-SC14 |
| L0 | `lookup.roc` expect 5 (`find_move`, 17 rows, and 6 rows for the scope `Install`). `json@3` is used (1 match), `http1@3` (the design example), `roc-lang/http@2`, `text@1`, the alias line for `roc-lang/http@3` and `http@3`, the plain tie for no selector, `latest`, `*`, `0.x`, `>=1.0.0`, an alias of 2 groups with no series match (no alias line) | R-SC16 R-SC14 R-SC6 R-AU8 |
| L0 | `lookup.roc` expect 5, 6 more rows (`find_move` with the scope `Install`, Q1): `roc-lang/http@2` is `http2`, `roc-lang/http@3` is the alias tie, no selector is the plain tie, `json@3` is the alias, a full name with no entry is `New`, a short name is the R-AD6 error | R-SC16 R-AD22 R-AD2 R-AD6 |
| L0 | `lookup.roc` expect 6 (`tool`, `x`): the old rows with the new fields | R-SC3 R-SC4 R-AD7 |
| L0 | `tests/unit/why.roc` expect 2 (`Why.row_facts`): alias only for a direct row, `Platform`, `Direct`, `Via`, `Unmanaged` for a path entry and a foreign URL | R-SC1 R-SC6 R-SC15 |
| L0 | `why.roc` expect 3 (`Why.find`, 20 rows): the design example, 2 series, `text@1`, `acme/text@2.0.0`, `acme/text@2.5.0`, `json@3`, `util@1`, the row key has the series | R-SC1 R-SC6 R-SC7 R-SC8 R-SC14 R-SC15 R-SC16 |
| L0 | `tests/unit/vars.roc` expect 3, 1 row changed: `update pf` with 2 groups gives the line of the tie | R-WS8 |
| L2 | `remove/rm1-flow` run 7: `remove roc-lang/http` with `http1` and `http2` in the header: exit 2, the list with `@1`, `@2` and `direct (<alias>)`, no scan and no probe | R-SC14 R-SC15 R-RV1 |
| L2 | `rm1-flow` run 8 (P0 bug 3): `remove json@3`, `json` is series 2: exit 2, `'json@3' is not in the project`, no write | R-SC16 R-RV1 |
| L2 | `rm1-flow` run 9 (P0 bug 1): `remove roc-lang/http@2`: the check and build run, only `http2` goes, `http1` stays | R-SC16 R-RV1 R-CM3 |
| L2 | `resolve/rs-failures` run 11 (R-WS8): `update pf` in a workspace where 2 members have `pf` for 2 platforms: exit 2 before the index, the list `platform (pf)` twice, `Use a name from the list.` | R-WS8 R-SC14 |
| L2 | `rs-failures` runs 13 and 14 (Q1, manager answer): `install roc-lang/http@3` (that is `tln add`) with `http1` and `http2`: the header entries are matched, no entry has series 3, so the same tie as run 12 with `tln update http1@3`, exit 2, no index call. Run 14 has no selector: the plain tie | R-SC16 R-SC14 R-AD22 |
| L2 | `rs-failures` run 12: `update roc-lang/http@3` with `http1` and `http2`: exit 2, the list with `@1`, `@2`, the last line `tln update http1@3`. No index call | R-SC16 R-SC14 R-SC15 R-AU8 |
| L3 | `why/wy1-why` runs `text@2`, `acme/text@2.0.0` (both exit 0, the series-2 paths), `acme/text@2.5.0`, `core@2`, `util@1` (exit 2, `not in the project`). The 2 tie runs have the new last line | R-SC1 R-SC14 R-SC16 |
| L3 | `update/up1-update-entries`: `ROC_TOOLCHAIN=<other id> tln up --dry-run --json`. `data.notes` has the R-SO20 note first, then the notice of R-SE7. The envelope is the only stdout | R-SO20 R-J1 R-J3 R-SE7 |
| L3 | `remove/rm2-workspace`: `ROC_TOOLCHAIN=<other id> tln remove json --file apps/b/main.roc --dry-run --json`: `data.notes` has the note, `written` is empty | R-SO20 R-J3 |

Count: 4 new L0 expects in `lookup.roc` (the expects 2 to 5) and 2 old ones with new fields (1 and 6); 2 new expects in `why.roc` (the old expect 2 is replaced); 1 L0 row changed in `vars.roc`. Deep: 3 L2 runs in `rm1-flow`, 4 in `rs-failures` (11 to 14), 7 L3 runs in 3 existing cases (no new case). The L0 rows are many because one `expect` checks a table of cases (the budget rule).

## Output proposals (TW24, for the review)

| Item | Proposal |
| --- | --- |
| Tie, last line | The texts of the design (R-SC14). A tie of a short name: `"<name>" matches <n> packages. Use a name from the list.` The note column: `platform (<alias>)`, `direct (<alias>)`, `via <alias>` |
| Tie in a moving command | `... Use the alias of the entry to move: tln update <alias>@<sel>` (the example of the design). `<sel>` is the typed selector: `Range` text without a leading `^` (`3`, not `^3`), the `Exact` version, `latest` |
| Selector in the "not in the project" text | `'<name>@<sel>' is not in the project`, with the same `<sel>` text (`'json@3'`, `'acme/text@2.5.0'`). With no selector the text is as before (`'zzz'`). A selector that excludes the match must not read as "json is not in the project" |
| R-WS8 | The same list and last line as a tie (the list prints the full names, one for each group) |
| `--json` | `data.notes` of `install`, `update` and `remove` has the R-SO20 note as the first entry, in the text that the `note:` line has. The `name` field of `why` and `list` is not changed |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | Names: `Lookup.build` (one builder, input `Lookup.Fact`), `Lookup.printed`, `Lookup.find_move`. `Existing` gets `series`. `Lookup.find` keeps its type | A `Bool` parameter on `find` (4 callers and the tests change). A new module (`main.roc` lists the modules) |
| D2 | An unmanaged entity has `name: ""`, `series: ""`, `version: Err(None)`. Only its alias names it (R-SC6) | The path as the name (it is no full name) |
| D3 | The facts of one scope can repeat an alias (members of a workspace): `build` keeps the first fact of equal `alias`, `name` and `series` and drops the rest. Its version is lost. Facts with no alias stay | Dedup by alias only (it hides R-WS8). No dedup (a workspace gives 2 matches for one entry) |
| D4 | The alias line needs a selector with a single series, and a distinct alias for each match. Else the plain line. For an alias of 2 groups (`pf@0.13`) the aliases are equal, so no alias line | The alias line always (it names a useless alias) |
| D5 | The selector filter is for the scope `Project`. `Tool` and `X` ignore it (P1 commands) | A filter for all scopes |
| D6 | `Vars.scope` keeps its error type `Fail`. Its R-WS8 text is the line of the tie. `Lookup.find` prints the list before it, so a command never reaches the `Vars` line with an alias tie. The `Vars` check is a backstop | `{ fail, block }` in `Vars.scope` (3 callers and `frozen.roc` change) |
| D7 | `add` with an alias is `Lookup.find` with the scope `Install` (form 1 only, as before). A full name that matches 2 or more header entries of the member (no `--as`, no `--platform`) is `Lookup.find_move` with the scope `Install` (Q1, manager answer). One entry stays `entry_of_repo` (Q11 of slice 004, the platform check) | `find_move` for every `add` name (it moves the one-entry rule and the R-AD33 check) |
| D8 | R-WS8 has a deep test at L2 (`rs-failures` run 11). No L3 case has an alias for 2 groups, and a new case is more than the budget | A new L3 case |
| D9 | The `--json` note test for `remove` is a `--dry-run` run in `rm2-workspace` (the existing run has the same state after it) | Change the last run to `--json` (it loses the text check) |
| D10 | `Why.find` finds the row by `alias`, `name` and `series` | The index of the entity (it breaks when `build` drops a fact) |

## Out of scope

| Rule or case | Reason |
| --- | --- |
| R-AU8 text `tln why <name>` with the name of R-SC15 | The audit fix text is P3 (`audit`). The name function `printed` is tested, and the alias line of `update` uses R-SC15 names |
| R-SC1 for `patch`, `probe`, `upgrade` | P1 commands. The `find` and `find_move` functions are tested |
| R-SC16 "When the one match is an unmanaged entry, R-H9 applies (exit 2)" | Slice 015 (unmanaged entries). `find_move` returns the entry. There is no row for it here |
| A registry as a source of matches (R-AD34) | P2 |
| R-SC1 "A transitive package is not a name" for `remove` and `update` | Both read the header only. L2 has no closure. `why` finds a transitive package (`wy1-why` runs `acme/text@2` and `text@2`) |

## Questions (TW17)

| # | Question | Default (the tests follow it) |
| --- | --- | --- |
| Q1 (answered, see "Review") | R-SC16 says that `tln add X@sel` of a header entry moves and keeps the series of `sel` for 2 or more matches. R-AD2 says that `add` with a full name does not search the scope. Which rule wins with 2 entries? | Answer: R-SC16 wins. The runs 13 and 14 of `rs-failures` and 6 L0 rows test it. |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Old tests that changed

| Test | Change | Rule |
| --- | --- | --- |
| `tests/unit/lookup.roc` | The entity record has `series` and `version`, and `Existing` has `series`. The tie text is `Use a name from the list.` The old row `roc-lang/http@3` (a tie) is `'roc-lang/http@3' is not in the project` for `find`, and a tie with the alias line for `find_move`. the note `via web-utils` is `via web_utils` (R-AD16: `-` is no alias character) | R-SC14 R-SC16 |
| `tests/unit/why.roc` expect 2 | Replaced: `Why.row_facts` and `Why.find` (no `Why.entities`). The 3 tie rows have the new text | R-SC14 |
| `tests/unit/vars.roc` | 1 row: the R-WS8 text | R-WS8 |
| `tests/scenarios/why/wy1-why` | `expect/stderr`: 2 tie lines end with `Use a name from the list.` | R-SC14 |

All other expected files are not changed. With the reference, no old expected file changed and no `calls.log` changed.

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | `Lookup`: the doc comments have the tables. `series_of` is wrong for a range that is no `^N` or `^0.M` (`0.x`, `*`, `>=1.0.0` have no series: `expect 5` rows check it). Delete `base_name`, `by_series`. |
| 2 | One builder: `PickFlow.entities_of` (role `Platform` or `Direct`, one fact for each use), the builder of `RemoveFlow.removal_plans!` (a `Release` row is a release fact, other rows `Unmanaged`), `Why.row_facts` (L0). Then `Lookup.build`. Delete `Why.entities`, and `Why.note_of` when nothing uses it. |
| 3 | `PickFlow.asked!`: `find_move` for `update`. For `install` and `add`: `find`, and when the result is `New(name)` and the member has 2 or more entities of that full name (no `--as`, no `--platform`), `find_move` with the scope `Install` (Q1). One entity stays `entry_of_repo`. `RemoveFlow` and `Why.find`: `find`. |
| 4 | `Why.find`: the row is the one with the same `alias`, `name`, `series` as `Existing` (D10). |
| 5 | `Vars.named_indexes`: only the text changes (D6). Delete `full_name` if nothing uses it. |
| 6 | R-SO20 in `--json`: `ResolveBase.pin_notes(decision)` goes first in `Outcome.notes` of `InstallFlow.resolve!` (also for `update`) and in the notes of `RemoveFlow.remove!`. The `note:` line stays on stderr in `--json` mode. The L3 expected files fix the order. |
| 7 | The test agent ran the whole fast set with a private reference (see the revert check): no old expected file changed. If one changes, it is a dispute row. |

## Red output (2026-10-21, `scripts/test.sh`, pinned roc, `cli/` with the stubs)

| Step | Result |
| --- | --- |
| `check`, `fmt`, `selftest` | pass |
| `l0` | 3 files fail, all others pass. `lookup.roc`: 4 of 6 expects (`build` and `printed`: `todo`; `find` (the new texts and the version filter), the R-WS8 rows, `find_move`: `todo`). `why.roc`: 2 of 6 (`row_facts`: `todo`; `find`: the old text and `text@1` is a tie). `vars.roc`: 1 of 3 (old R-WS8 text) |
| `l2` | 29 pass, 2 fail. `remove/rm1-flow`: run 7 prints `roc-lang/http@1` with no note and the old last line (the old builder), run 8 removes the series-2 entry (the P0 bug), run 9 is a tie (the P0 bug: the series in the name is not read). `resolve/rs-failures`: run 11 has the old R-WS8 text, run 12 the old tie text with no notes |
| `l3` | 23 pass, 1 skipped, 3 fail. `why/wy1-why`: the old tie text, `text@2` is a tie. `update/up1-update-entries` and `remove/rm2-workspace`: `data.notes` has no R-SO20 note |

## Revert check (TW12)

A private reference of the slice ran the whole fast set green. Then `research/slice-014-revert/mutate.py` put 30 small changes in it, one by one (results: `research/slice-014-revert/results.md`). The reference is deleted: `cli/` equals the stubs again (`research/slice-014-revert/cli-stub.sha256`, checked with `sha256sum`).

| Result | Rows |
| --- | --- |
| Caught (30 of 30) | M1 (no selector filter in `find`: the 3 P0 bugs), M2 M14 (an unmanaged entry and a selector), M3 (series in place of version), M4 M5 M6 M7 M8 (`find_move`: the series filter, one match, the alias line, a range of series), M9 M24 (last line), M10 M17 (printed names), M11 M12 M15 M28 (`build` and the alias tie of R-WS8), M13 M29 (notes), M16 (text with the selector), M18 M30 (`Why.row_facts`), M19 (row key), M20 M21 (`update` uses `find_move`, the platform note), M22 M23 (`remove`), M25 M26 M27 (the R-SO20 note in `data.notes`, its order) |
| First try not caught | M14 (version `0.0.0` never matches `^1`: the row used `1.0.0`), M19 (a compile warning: the row used `(x.series == series or Bool.True)`) |

## Next step

The human reviews the 4 new L0 expects of `lookup.roc`, the 2 of `why.roc`, the 14 new deep runs, the output proposals, D1 to D10 and Q1. Then the code agent (notes 1 to 7).

## Q1 follow-up (test agent, 2026-10-21)

Pre-slice copies: no new file changed (`rs-failures`, `lookup.roc` and `Lookup.roc` were copied before). A private reference (deleted again, `cli/` equals the stubs, `cli-stub.sha256` is new) ran the whole fast set green. Mutations N1 (`add` never calls `find_move`), N2 (no narrowing in the scope `Install`), N3 (the rule needs 3 entities): all caught by `l2:resolve/rs-failures` (N2 also by `l0:lookup`; N1 and N3 only by the deep runs, as the rule is in `PickFlow`). Red with the stubs: `lookup.roc` 4 of 6 fail as before, `rs-failures` fails. Not tested: the `--as` and `--platform` guard of D7 (no case).

## Verify results (code agent, 2026-10-21)

`scripts/test.sh` exit 0: check, fmt, l0 (all unit files), l2 (31 passed), l3 (26 passed, 1 skipped), selftest (24 passed). The revert check is `research/slice-014-revert/code-mutate.py` (results: `code-results.md`). Caught 30 of 32 changes. `cli/` equals its copy before the run (`cli-code.sha256`).

| Result | Rows |
| --- | --- |
| Caught | C1 to C24, C26, C27, C29 to C32 (find filter, `find_move`, alias line, tie text, printed names, `build`, `Why.row_facts` and key, `PickFlow`, `RemoveFlow` series and `find`, `Vars` text, R-SO20 notes and their order) |
| Not caught | C25 (the `--as` guard of D7: no case, accepted in the Q1 follow-up). C28 (a path entry as a release in `RemoveFlow.row_fact`: no L2 case) |

Decisions of the code agent that the slice does not fix:

| Decision | Rejected |
| --- | --- |
| A release with no GitHub name has `name` = the URL form (`Ident.group.form`, `host/path`) in `RemoveFlow` too, as in `PickFlow`. The old builder used the full URL | The URL (no form of R-SC7 matches it) |
| The R-SO20 note is put before `Outcome.notes` in `InstallFlow.resolve!` (after `finish!`), not as a parameter of `finish!` | A new parameter of `finish!` |
| `Lookup.find_move` for `Tool` and `X` is `find` (they have no move) | An error |
| `selector_text` of `Step` is `""` (no scope that calls `Lookup` can have it: `Ref.parse` stops it) | A crash |

## Review (manager, 2026-10-21)

D1 to D10 and the output proposals (TW24) are accepted, also the `^` strip in `tln update <alias>@<sel>`.

| # | Answer |
| --- | --- |
| Q1 | R-SC16 wins. R-AD2 "a full name needs no search" means no registry search (R-I8, R-AD34). The match against the header entries still applies, as slice 004 Q11 and Q12 (accepted) and slice 007 C1 say: `tln add roc-lang/http@3` with 2 entries of that repo picks the entry by the series of the selector, and with no entry in that series it is the R-SC16 tie. The test agent adds one run for it. |
Q1 follow-up accepted (runs 13 and 14 of `rs-failures`, 6 `find_move` rows). The `--as` and `--platform` guard gap is accepted: slice 015 changes `--as` (R-AD38). Status: code.

## Review of the code (manager, 2026-10-21)

`scripts/test.sh` passes (manager run). The revert check caught 30 of 32. The decisions are accepted. Moved to slice 015: C25 (the `--as` guard of D7) and C28 (`RemoveFlow.row_fact` must keep a path entry unmanaged: a `remove` run on a path entry).
