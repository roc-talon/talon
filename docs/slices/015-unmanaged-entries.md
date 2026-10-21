# 015 Unmanaged entries

Phase: P0. Status: done

This slice tests the decision `docs/design-gaps/G-never-change.md` (applied to the design files: `docs/design-gaps/APPLIED.md`, rows NC1 to NC6). It also takes the 2 items that slice 014 moved here (C25 and C28). It follows `docs/agents/BRIEF-tests.md`. The earlier slices are not committed: the pre-slice copies of the changed files are in `research/slice-015-revert/before/` (with `NEW.txt`).

An unmanaged entry is a path entry or a foreign URL (Design 4.2, R-H4). Talon never writes its value. It changes it only as a whole, and only when the user names its alias in a command that removes or replaces it.

## Rules

R-H4, R-H7, R-H9, R-AD18, R-AD19, R-AD21, R-AD22, R-AD31, R-AD38, R-RV5 (changed or new in the design). Also R-I3 and R-I5 (a key of an unmanaged alias), R-SC6 and R-SC16 (an unmanaged entry has no version: C28), R-AD32, R-AD33 and R-C4 (the keyword `platform` of the entry stays), R-AD25 to R-AD27 (the `talon.toml` value of a replace), R-SL5 (`latest` is no selector), R-H1, R-H3, R-CC7 (the span edit), R-EC2.

R-H9 command by command (Design 4.2), with the test of each row:

| R-H9 row | Test |
| --- | --- |
| `install`, `update` with no names: byte for byte, keys of its alias ignored | L2 `rs-unmanaged` runs 1 and 2. L0 `vars.roc` expect 4 |
| `update X` (path entry or foreign URL): exit 2, names `tln add <name> --as X` | L2 `rs-unmanaged` runs 3 and 4. L3 `up1-update-entries` (the old text changed) |
| `add X@sel`: exit 2 | L2 `rs-unmanaged` run 7. L0 `add.roc` expect 10 |
| `add X` (no selector, `latest`): no change, exit 0, no command named | L2 `rs-unmanaged` runs 5 and 6, `in1-flow` run 6 (`--json`). L0 `add.roc` expect 10 |
| `add <name>` with the default alias that is its alias: stops, names `--as` | L2 `rs-unmanaged` run 8. L0 `alias.roc` expect 4, `add.roc` expect 9 |
| `add <name> --as X`, `add --platform <name>`: replaces the whole entry | L2 `rs-unmanaged` runs 9 and 10. L0 `locked.roc` expect 3, `alias.roc` expect 4, `add.roc` expect 9 |
| `remove X`: removes the whole entry, with its `talon.toml` keys | L3 `rm1-remove-entries` (the old run), L0 `removal.roc` expect 2 (3 new rows) |
| `remove X@sel`: an unmanaged entry never matches a selector (C28) | L3 `rm1-remove-entries` (new run) |
| `verify` with no names | Not a change: `verify` writes no file (R-CM11). No new test |
| `upgrade X`, `patch X` | P1. Out of scope |

## Public signatures (stubs)

| Item | Signature |
| --- | --- |
| `Locked.Op` | New tag `Replace({ alias : Str, url : Str })`. The whole-entry replace of an unmanaged entry (any row is allowed, the URL must pass R-H3, the keyword stays). `Locked.apply_op` and `ResolveBase.entries_after` have `Replace(_) => crash "todo"`. `Locked.alias_of` (the span) is done: it is a one-line match |
| `Alias` | `[New(Str), Existing(Str), Unmanaged(Str)]`. `Unmanaged(alias)`: `--as <alias>` names an unmanaged entry. `Alias.choose` is not changed (the stub never gives `Unmanaged`, and the text of `Taken` for an unmanaged entry is the old text) |
| `Add.never_changes` | `{ alias : Str, value : Str } -> Fail`. The usage failure of `update X` and `add X@sel` for an unmanaged entry. `crash "todo"` |
| `Add.decide`, `Add.decide_alias` | The types are not changed. In `Add.decide_package` and `Add.decide_platform` the arm `Ok(Alias.Unmanaged(_))` is `crash "todo"` |

The docs of `Locked`, `Alias` and `Add` hold the tables of the new cases.

## Files

| File | Change |
| --- | --- |
| `cli/lib/Locked.roc`, `Alias.roc`, `Add.roc`, `ResolveBase.roc` | The stubs above, and the docs |
| `cli/lib/Removal.roc` | Doc only: R-RV5 agrees with R-H4 (no "gives way") |
| `tests/unit/locked.roc` (+43 lines, 3 labels of the old expect changed) | New expect 3: `Replace` |
| `tests/unit/alias.roc` (+52 lines, 1 old row changed) | New expect 4: an alias of an unmanaged entry |
| `tests/unit/add.roc` (+81 lines) | New expects 9 and 10: the replace plans and `add X` of an unmanaged entry, `Add.never_changes` |
| `tests/unit/vars.roc` (+16 lines) | New expect 4: a key of an unmanaged alias |
| `tests/unit/removal.roc` (+6 lines) | 3 rows in expect 2 (the keys of an unmanaged entry), the comment |
| `tests/unit/lookup.roc` (+25 lines) | New expect 7: `find` and `find_move` with an unmanaged entry |
| `tests/commands/cases/resolve/rs-unmanaged/` (new) | 11 runs on 3 projects, `rules`, expected files |
| `tests/commands/cases/resolve/rs-failures/` | +1 run (15, C25), the page of roc-lang/http in `fx/http`, `rules`, expected files |
| `tests/commands/cases/install/in1-flow/` | +1 run (6, `add local --json`), `rules`, expected files |
| `tests/scenarios/remove/rm1-remove-entries/` | +1 run (`remove util@1`, C28), expected files |
| `tests/scenarios/update/up1-update-entries/` | 1 expected line changed (the text of `update mylib`) |
| `research/slice-015-revert/` | `before/` (with `NEW.txt`), `stub/`, `mutate.py`, `results.md`, `cli-before.sha256`, `cli-stub.sha256` |

## Tests

| Layer | File and case, and what it checks | Rules |
| --- | --- | --- |
| L0 | `tests/unit/locked.roc` expect 3 (`Replace`): a path entry, a foreign URL, a path platform (the keyword and the comment stay), a release row, 3 ops in order, the same bytes as `Set`. Refused: a foreign URL or a path as the new value (R-H3), an alias that is not there, `Set` of a path row (still refused). `spans` of `Replace` is the old value | R-H4 R-H9 R-H1 R-H3 R-AD31 R-AD38 R-CC7 |
| L0 | `alias.roc` expect 4 (`Alias.choose`, 11 rows): `--as` over a path entry, a foreign URL, the platform entry: `Unmanaged`. The default alias over an unmanaged entry: `Taken` with the text that names `--as <a>` (path, foreign, and the platform alias `pf` of a package entry). A bad `--as` is checked first. A release of another group is still `Taken`. The group check comes first (`Existing`). The old row of `expect 3` has the new text | R-AD18 R-AD19 R-AD38 R-H9 R-AD16 |
| L0 | `add.roc` expect 9 (`Add.decide`, 11 rows): `--as` over a path entry and a foreign URL gives `Replace`, `talon.toml` by the table (none, `latest`, exact, exact with `--no-pin`, range), the note. A package over a path platform is `not a platform` (R-AD32). A platform release over a package entry is R-AD33. The default alias stops. `--platform` over a path platform is `Replace` under its alias | R-AD38 R-AD31 R-H9 R-AD18 R-AD32 R-AD33 R-C4 R-AD25 R-AD26 R-AD27 R-SL5 R-SE7 |
| L0 | `add.roc` expect 10 (`Add.decide_alias`, `Add.never_changes`): no selector and `latest` are `Keep` with the value as written and no command named. A range or an exact version is the failure `never_changes` (path and foreign texts). A release is as before | R-AD21 R-AD22 R-AD20 R-H9 R-H4 R-SL5 R-EC2 |
| L0 | `vars.roc` expect 4: keys of a path alias and of a foreign alias, in `[dependencies]` and `[overrides]`, also with a repo name: no want, no range. The key of a release in the same file gives its range | R-H9 R-H4 R-I3 R-I5 R-OV1 |
| L0 | `removal.roc` expect 2, 3 rows: a path entry and a foreign URL with keys in 2 tables give the keys. Another member has the alias: no key | R-RV5 R-H4 R-H9 |
| L0 | `lookup.roc` expect 7 (9 rows): `find_move` and `find` give `Existing` for the alias of an unmanaged entry, also with a selector. A full name is `New`. `find` with a selector is `not in the project` | R-SC6 R-SC16 R-H9 R-AD21 R-AD22 |
| L2 | `resolve/rs-unmanaged` run 1: `install` with no names, keys of the 2 unmanaged aliases in `talon.toml`: nothing to change | R-H9 R-I3 R-I5 |
| L2 | `rs-unmanaged` run 2: `update` with no names moves parser and the platform. The path entry (its comment) and the foreign URL stay byte for byte | R-H9 R-H4 R-H1 |
| L2 | `rs-unmanaged` runs 3 and 4: `update json` (path), `update other` (foreign): exit 2, the message names `tln add <name> --as <alias>`. No index call. Slice 009 G3 | R-H9 R-EC2 R-SC6 |
| L2 | `rs-unmanaged` runs 5 and 6: `install json`, `install other` (`tln add X`): exit 0, no change, the line has the value as written | R-AD21 R-H9 |
| L2 | `rs-unmanaged` run 7: `install json@^2` (`tln add X@sel`): exit 2 | R-AD22 R-H9 |
| L2 | `rs-unmanaged` run 8: `install acme/json`: the default alias is the path entry: exit 2, the text names `--as json`. The index is read first | R-AD18 R-H9 |
| L2 | `rs-unmanaged` run 9: `install acme/json@^2 as=json` replaces the path entry with 2.1.0. The comment of the line stays. Check and build run. The note and the line name the old value | R-AD38 R-H9 R-H1 R-H3 R-AD26 R-SE7 |
| L2 | `rs-unmanaged` run 11 (Q1, manager answer): `install acme/json as=json` with no selector, `json` is a path entry and `talon.toml` has `json = "^2"`: the pick honors the key, so the entry gets 2.1.0 (3.0.0 is the newest, outside the range) | R-AD38 R-I3 R-C1 R-AD24 |
| L2 | `rs-unmanaged` run 10 (the bug): `install acme/pf platform` over a path platform: replaced under its alias. It was exit 1 | R-AD31 R-H9 R-AD38 R-SE7 |
| L2 | `resolve/rs-failures` run 15 (C25): `install roc-lang/http@3 as=http3` with `http1` and `http2`: `--as` makes a new entry, so no tie (run 13): the index is read and `no release of roc-lang/http matches '3'` | R-AD19 R-SC16 R-SL12 |
| L2 | `install/in1-flow` run 6: `add local --json`, `local` is a path entry: exit 0, `data.kept` has the value as `name`, nothing is written | R-AD21 R-H9 R-J3 |
| L3 | `remove/rm1-remove-entries`: `remove util@1`, `util` is a path entry: exit 2, `not in the project` (C28). The old run `remove util odd util --force` removes both | R-RV5 R-H9 R-SC16 |
| L3 | `update/up1-update-entries`: the stderr line of `update mylib` has the new text (an old expected file changed) | R-H9 |

Count: 6 new L0 expects (`locked` 1, `alias` 1, `add` 2, `vars` 1, `lookup` 1) and 3 rows in an old expect (`removal`), 1 old row changed (`alias`). Deep: a new L2 case with 11 runs, 1 run in each of 2 old L2 cases, 1 run in an old L3 case. The L0 rows are many because one `expect` checks a table.

## Output (proposed, TW24, for the review)

| Item | Proposal |
| --- | --- |
| `update X`, `add X@sel`: the refusal (usage, exit 2) | `<alias> is a path entry: Talon never changes it. To replace it, run tln add <name> --as <alias>.` A value with `://` is `a foreign URL` in place of `a path entry`. One function: `Add.never_changes` |
| `add X` of an unmanaged entry (R-AD21) | One line: `<alias>: <value as written> is in the header`. It names no command (the design) |
| `data.kept` of that run | `{ "alias": "<alias>", "name": "<value as written>", "version": "" }` (the type of `kept` is not changed) |
| The default alias is an unmanaged entry (R-AD18) | `the default alias '<a>' for '<name>' is used by a path entry in the header. Use --as <alias>, or --as <a> to replace that entry.` (`a foreign URL` for a foreign entry) |
| The replace of a package (R-AD38) | `note: entry changes: <old value> -> <name> <version>`, and the line `~ <alias>: <old value> -> <name> <version>` |
| The replace of the platform (R-AD31) | The note of R-SE7 with the old value: `platform changes: ./pf/main.roc -> acme/pf 0.1.1`, and the line `~ pf: ./pf/main.roc -> acme/pf 0.1.1` |
| `--json` of a replace | The entry is in `data.moved`: `{ "alias", "from": { "name": "<old value>", "version": "" }, "to": { "name", "version" } }`. No new field |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `Locked.Op` gets a 5th tag `Replace({ alias, url })`. `Set` still refuses an unmanaged row, so a bug of `update` stays an `Internal` fault (G-never-change section 5) | A flag on `Set`. `Set` that accepts all rows |
| D2 | `Alias.choose` gives `Unmanaged(alias)` only for `--as`. The default alias is `Taken` with the text of E7 | A prompt (G-never-change Q1: no prompt) |
| D3 | One function, `Add.never_changes`, for the text of `update X` and `add X@sel` | Two texts |
| D4 | `latest` is no selector for an unmanaged entry: `add X@latest` is the same as `add X` (R-SL5 wins over the word "selector" in R-H9 row 2, as slice 004 Q9) | Exit 2 for `latest` |
| D5 | `--as <alias>` over the platform entry with a package release is `'<name>' is not a platform` (R-AD32, R-C4 apply, R-AD38). The text is the one of R-AD32 | A new text. Replace and drop the keyword |
| D6 | The group check of `Alias.choose` comes first (R-AD19): `add acme/json --as util`, where the header has acme/json as `js` and `util` is a path entry, is `Existing("js")`: no entry is added | Replace anyway |
| D7 | New L2 case `rs-unmanaged` for the flows that need their own fixtures (a path entry and a foreign URL with keys, a path platform). The other items are runs in old cases | All runs in old cases (they would share state with runs that fail with exit 17) |
| D8 | `verify` has no test: it writes no file (R-CM11), so R-H9 row 1 holds for it | A `verify` run |
| D9 | The old text of `update <path alias>` (`'mylib' is a path entry: Talon never changes it`) is replaced by the text of `Add.never_changes` (E10 and R-H9 row 2: the message names `tln add <name> --as X`) | Keep both |

## Out of scope

| Rule or case | Reason |
| --- | --- |
| R-PA14 (`tln patch` of an unmanaged entry: exit 2) | P1: `patch` has no command yet (TW16) |
| R-H9 rows `upgrade`, `upgrade X` | P1: `upgrade` has no command yet |
| R-H7 (the last sentence: no command removes or replaces an entry of the header of a path file) | No command reads such a header as a project header. No test can name a behavior |
| `verify` with no names (R-H9 row 1) | D8 |
| R-AD3 to R-AD5, R-AD34 to R-AD36 | Registry (P2) |

## Questions (TW17)

| # | Question | Default (the tests follow it) |
| --- | --- | --- |
| Q1 (answered: yes, see "Review"; run 11 tests it) | R-AD38 says that a key which the alias already has "stays and is the range of the new entry (R-I3)". When the user gives no selector, does the pick of the new entry take the range of that key (R-C1)? The key of an unmanaged alias is ignored before the replace (R-H9 row 1), so it is a new constraint at that moment | Answer: yes. `rs-unmanaged` run 11 tests it. Run 9 has the same range (`^2`) in the key and in the selector |
| Q2 | `tln add --platform <name> --as X` when the header has no platform and `X` is a path entry of a package: R-AD38 replaces the entry, but the entry has no keyword `platform` | The reference stops with a usage failure. No test |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Old tests that changed

| Test | Change | Rule |
| --- | --- | --- |
| `tests/unit/alias.roc` expect 3 | 1 row: the default alias `util` over a path entry has the text of R-AD18 for an unmanaged entry (`used by a path entry in the header. Use --as <alias>, or --as util to replace that entry.`) | R-AD18 |
| `tests/scenarios/update/up1-update-entries` | `expect/stderr` 1 line: `update mylib` has the text of `Add.never_changes` (was `'mylib' is a path entry: Talon never changes it`). The cmd comment names R-H9 | R-H9 |
| `tests/unit/locked.roc`, `removal.roc`, `rm1-remove-entries/cmd` | Comments and 2 labels: "R-RV5 gives way over R-H4" is "R-H4, R-H9, R-RV5" (G-never-change section 5) | R-H4 R-H9 R-RV5 |
| `rs-failures`, `in1-flow`, `rm1-remove-entries` | Expected files only grow (new runs, appended lines). No old line changed | |

With the reference, no other old expected file changed and no old `calls.log` line changed.
## Red output (2026-10-21, `scripts/test.sh`, pinned roc, `cli/` with the stubs)

| Step | Result |
| --- | --- |
| `check`, `fmt`, `selftest` | pass |
| `l0` | 3 files fail. `locked.roc`: expect 3 (`todo`: `Replace`). `alias.roc`: expect 3 (the old row has the new text) and expect 4 (`Unmanaged` is not given, the old `Taken` text). `add.roc`: expect 9 (`todo`) and expect 10 (`Keep` of a path entry has the old text and a command, a selector gives `Update`). `vars.roc`, `removal.roc`, `lookup.roc` pass: they guard behavior that exists |
| `l2` | 30 pass, 2 fail. `resolve/rs-unmanaged`: runs 3 and 4 have the old texts (`'json' is a path entry...`, `'other' is not in the project`), runs 5 to 7 are the short-name error, run 8 and 9 have the old `Taken` text, run 10 is `exit 1`, run 11 is the old `Taken` text (`tln: error[internal]: pf is a path entry or a foreign URL: tln never changes it (R-H4)`: the bug). `install/in1-flow`: run 6 is the short-name error. `rs-failures` run 15 passes (C25 is a gap test: only the mutation fails it) |
| `l3` | 25 pass, 1 skipped, 1 fail: `update/up1-update-entries` (the old text of `update mylib`). `remove/rm1-remove-entries` passes (C28 is a gap test) |

## Revert check (TW12)

A private reference of the slice ran the whole fast set green. Then `research/slice-015-revert/mutate.py` put 26 small changes in it, one by one (results: `research/slice-015-revert/results.md`). The reference is deleted: `cli/` equals the stubs again (`research/slice-015-revert/cli-stub.sha256`, checked with `sha256sum`).

| Result | Rows |
| --- | --- |
| Caught (26 of 26) | N1 to N4 (`Replace` in `Locked`), N5 to N8 (`Alias`), N9 to N14 (`Add`), N15 to N17 and N25 (`PickFlow`: the refusal, the foreign case of slice 009 G3, the unmanaged entities, the `kept` name), N18 (C25, `rs-failures` run 15), N19 and N20 (`InstallFlow`: the replace op and its line), N21 (`Vars`), N22 (`Removal`), N23 (C28), N24 (`Lookup`), N26 (run 11: the pick ignores the key of the unmanaged alias, so it takes 3.0.0) |
| First try not caught | N25 did not compile (an unused parameter): its change was made smaller |

## Next step

The human reviews the 6 new L0 expects, the new L2 case `rs-unmanaged` (11 runs), the 3 added runs, the output proposals, D1 to D9 and Q1 and Q2. Then the code agent (notes 1 to 6).

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | `Locked.apply_op`: `Replace({ alias, url })` is `Set` without the R-H4 check: the alias must be a row, `check_url`, then `Header.set_value`. `ResolveBase.entries_after`: `Replace` is the same as `Set`. Update the docs of `Locked` (the `Remove` doc must not say "gives way": it is in the stub) |
| 2 | `Alias.new_alias`: a row with the alias and `Ident.of_url` that fails (`Err(Foreign)`) is unmanaged: `--as` gives `Unmanaged`, the default alias gives `Taken` with the new text (path or foreign: a value with `://`). The checks 1 and 2 stay first. The group check (`in_header`) stays before `new_alias` |
| 3 | `Add`: `replace_unmanaged` for `Unmanaged` in `decide_package` (the platform row is the failure of D5). `decide_alias`: an unmanaged row is `Keep` (no selector, `Latest`) or `never_changes`. `never_changes` has the text of the output table |
| 4 | `PickFlow.asked!`: the entities of `entities_of` get a `Lookup.Fact` with `what: Unmanaged` for each `Path` or `Foreign` row (of all members for `update`, of the current member for `add`). A `Lookup.Existing` with `name == ""` for `update` is `Add.never_changes` (delete the old `r.what == Path` block). `add` goes on to `Add.decide_alias`. The `Kept` of an unmanaged entry has the value as `name` |
| 5 | `InstallFlow.fresh_step`: the `Replace` branch finds the old row by `plan.alias` (not the first platform row). An unmanaged old row gives `Locked.Replace`, a release row gives `Set`. The line of an unmanaged old row is `~ <alias>: <old value> -> <name> <version>` |
| 6 | The test agent ran the whole fast set with a private reference. The old expected files that changed: `up1-update-entries` (1 line) and the old row of `alias.roc`. No `calls.log` of an old case changed |
| 7 | `Removal.roc` doc is done in the stub. `Locked.roc` docs of `Set`, `Replace`, `Remove` are done in the stub |

## Review (manager, 2026-10-21)

D1 to D9 and the output proposals (TW24) are accepted.

| # | Answer |
| --- | --- |
| Q1 | Yes. R-AD38 says the key is the range of the new entry (R-I3), so with no selector the pick of the new entry honors the range of the key. The test agent adds one run where the key range and the newest release differ. |
| Q2 | The default: a usage failure (exit 2). A replace never changes the kind of an entry (R-AD32). No test. |
| O2 | Fixed in the design by the manager (R-H9 now cites R-I3 and R-I5). |
Q1 run accepted (`rs-unmanaged` run 11). The manager restored the pre-slice copies of `PickFlow.roc` and `InstallFlow.roc` (they match `cli-before.sha256`). Status: code.

## Code agent result (2026-10-21)

`scripts/test.sh` exit 0: check, fmt, l0 (49 files, 166 expects), l2 (32 runs of cases), l3 (26 passed, 1 skipped), selftest (24).

Decisions that the slice does not fix:

| # | Decision | Rejected options |
| --- | --- | --- |
| C1 | `--platform <name>` (header has no platform) with `--as X`, where `X` is an unmanaged package entry (Q2): usage failure `X is not a platform entry: --platform cannot replace it.` No test (Q2). The text is a proposal | Replace and drop the kind. A new entry |
| C2 | Q1: the key range applies to a replace when the selector is none or `latest` (R-SL5), from `[dependencies]`, else `[overrides]` (as `Vars.range_of`). A selector replaces the range | Only "no selector". The key as a second range with the selector |
| C3 | Q1 for `--platform` over a path platform: the key range is read for the alias `pf` only (`fresh_of` key), not for the alias of the old platform entry. No test. A path platform under another alias has no key range at the pick | Read the key of the old platform alias |
| C4 | `Alias` has no new public function: the kind text of an unmanaged value (`a path entry`, `a foreign URL`) is a private function in `Alias.roc` and in `Add.roc` (one line each) | A public function in `Ident` |

## Verify results (code agent, TW12)

`research/slice-015-revert/code-mutate.py`, results in `research/slice-015-revert/code-results.md`: caught 24 of 27 mutations. Not caught:

| Id | Gap in the tests | Rule |
| --- | --- | --- |
| C21 | A key in `[overrides]` of the replaced alias | R-AD38, R-I3, R-OV1 |
| C25 | `--json` of a replace: `data.moved[].from` | R-AD38, R-J3 |
| C27 | `add <name>@latest --as <alias>` with a key in `talon.toml` | R-SL5, R-AD38 |

The code after the mutations has the same `sha256sum` as before them (75 files of `cli/`).

## Review of the code (manager, 2026-10-21)

`scripts/test.sh` passes (manager run). The revert check caught 24 of 27. C1, C2 and C4 are accepted. C3 is not accepted: a replace keeps the alias of the entry (R-H9, R-AD38), so `--platform` over a path platform reads the key of that alias, not of `pf`. Moved to slice 016, with the 3 gaps: C21 (a key in `[overrides]` for the replaced alias), C25 (a `--json` run of a replace: `data.moved[].from`), C27 (`add <name>@latest --as <alias>` with a key). The test agent of 016 adds a run for each and for C3; the code agent fixes C3.
