# 016 One closure model

Phase: P0. Status: done

This slice tests the decision `docs/design-gaps/G-closure-fetch.md` (applied to the design files: `docs/design-gaps/APPLIED.md`, rows CF1 to CF3). It also takes the 4 items that the review of slice 015 moved here (C3, C21, C25, C27). It follows `docs/agents/BRIEF-tests.md`. The earlier slices are not committed: the pre-slice copies of the changed files are in `research/slice-016-revert/before/` (with `NEW.txt`).

The slice is one review (TW19): about 150 lines of code (one loop, one closure rule in `Pick.step`, the C3 line). The part of the gap file that is for P2 (the registry answer as source 2, `list` and `--frozen` with a registry) is out of scope.

## Rules

R-AL2, R-AL8, R-AL9, R-FE1, R-DI1, R-DI7 (changed or new in the design). Also R-H7 (a path entry is a node of the closure), R-C2, R-C3 (the pick checks them with the closure rule), R-PH10 and R-EC10 (a closure problem is a conflict of the tuple, exit 10 only when nothing is free), R-DT2 (the order of the facts does not matter), R-I3, R-OV1, R-SL5, R-AD31, R-AD38 and R-J3 (the 4 moved items).

## What changes

| # | Before | After | Rule |
| --- | --- | --- | --- |
| 1 | `Pick.closure_of` drops a path entry as an edge (`Ident.of_url` is `Err`). `Closure.step` follows it. So a path file that names `json 2.2.0` and a pick of `json 2.1.0` is accepted by the pick, and the walk fails with exit 10 | `Pick.step` checks R-C2 and R-C3 with the closure rule that the walk uses: the roots are the chosen slots and the entries that no slot owns. A path entry is a node, and its entries are edges | R-AL9, R-H7, R-C2 |
| 2 | A cycle, one label with 2 hashes, or 2 platforms in the closure of the picked tuple: the pick gives the tuple, the walk fails with exit 10 | The problem is a conflict of that tuple. The pick tries the next tuple. Exit 10 (`no_tuple`) only when no tuple is left | R-AL9, R-PH10, R-EC10 |
| 3 | `pick_loop!` (`PickFlow`) reads release headers (`ResolveBase.read_releases!`). `Walk.level!` reads release headers and path files. Two loops | One need loop. `Need` has release URLs and absolute path files. One call gets the facts of a list of ids: first the facts that the command has, then `packages/<hash>/main.roc` (a download only when it is not there), the path file itself. One `Fetch.packages!` for the URL ids, one `read_files!` for all ids, in the order of the ids | R-AL8, R-FE1, R-DI7 |
| 4 | The walk after the pick reads the path files that the pick did not see | The pick holds the path files, so the walk reads no file again (as it does not read the headers of the pick now) | R-AL8 |
| 5 | `--platform` over a path platform reads the `talon.toml` key of `pf` (C3) | It reads the key of the alias of that entry | R-AD31, R-AD38, R-I3 |

## Public signatures (stubs)

| Item | Signature |
| --- | --- |
| `Pick.step` input | 2 new fields. `unmanaged : List({ file : Str, entries : List(Closure.Entry) })`: for each member file, the header entries that no slot owns (a path value or a foreign URL, not the entry that the run replaces). `paths : List(Closure.Node)`: the path files that are read (`id` is the absolute file, `entries` are its entries, `Release.entries_of`). The result type is not changed |
| `Pick.step` `Need` | The list has ids: a release URL, or the absolute file of a path entry (`Text.resolve(<dir of the member file>, <value>)`, as `Closure.step` gives them). Order: first the chosen slot URLs that have no fact (slot order), then the other nodes in the order of the followed edges (level by level), no repeat |
| `PickFlow.pick_loop!` | The stub passes `unmanaged: []` and `paths: []`. The code agent computes them (note 2) |

The stub of `Pick.step` ignores the 2 fields (the body is the old body). So the new tests fail with a wrong value, not with "todo".

## Files

| File | Change |
| --- | --- |
| `cli/lib/Pick.roc` | The 2 fields in `step` and `Step`, the doc of `step` (rules 1 to 4 of the closure and the `Need` order). Body not changed |
| `cli/lib/PickFlow.roc` | `pick_loop!` passes `unmanaged: []`, `paths: []` (compiles, no behavior) |
| `tests/unit/pickclosure.roc` | The helper `step` has the 2 fields. Row of a cycle changed. 2 new expects (path entries, a problem of the closure) |
| `tests/unit/pick.roc` | The helper `step` has the 2 fields (no row changed) |
| `tests/unit/closure.roc` | Comment only: the 2 expects of the `Mvs` failures name R-AL9 (work item 6 of the gap file) |
| `tests/commands/cases/closure/cl2-chain/` | 3 new runs (5, 6 and 7) on 2 new projects (p4, p5), `rules`, expected files |
| `tests/commands/cases/resolve/rs-unmanaged/` | 3 new runs (12 to 14: C3, C21, C27) on 3 new projects (`plat2`, `ovr`, `lat`), `rules`, expected files (4 old lines of calls.log changed) |
| `tests/commands/cases/install/in1-flow/` | 1 new run (7: C25) on a new project (`app2`), `rules`, expected files (4 old lines of calls.log changed) |
| `tests/commands/cases/resolve/rs-install-add-key/` | `rules`, 2 old lines of calls.log changed |
| `tests/commands/cases/closure/cl1-flow/` | `rules` only (R-AL8, R-AL9, R-DI1, R-DI7 named; the calls do not change) |
| `research/slice-016-revert/` | `before/` (with `NEW.txt`), `cli-stub.sha256`, `mutate.py`, `results.md`, `red.md` |

## Tests

| Layer | File and case, and what it checks | Rules |
| --- | --- | --- |
| L0 | `tests/unit/pickclosure.roc` expect 3 (new, 10 rows): the app has a path entry and a foreign URL that no slot owns. The path file names `json 2.2.0`. With `Lowest`, the rounds are: no fact (`Need`: the slot URL first, then the file), the file is the only missing fact, the file read (json 2.1.0 is a conflict: `Need` has json 2.2.0), done with 2.2.0 (the probable bug: the old step gave 2.1.0). Same with the facts in the other order, and with `Highest`. A lower version in the file is a raise (no conflict, no `Need` for it). A file under a file and a package that the file names: both are needed, in the order of the edges. The nested file names json 2.2.0: a conflict. A held json: no tuple | R-AL9 R-AL8 R-H7 R-C2 R-DT2 R-FE1 |
| L0 | `pickclosure.roc` expect 4 (new, 4 rows): `mid` names `core 1.0.0` with one hash, `web 2.0.0` names `core 1.0.0` with another hash: a content conflict. With `Highest` the pick gives web 1.0.0 (the old step gave 2.0.0). The facts in the other order. `Lowest`: no change (a control row). A held web 2.0.0: no tuple (the failure of the pick, exit 10, only when nothing is free) | R-AL9 R-C2 R-PH10 R-EC10 R-DT2 |
| L0 | `pickclosure.roc` expect 2, 1 row changed: a cycle between packages gave `Done` (the walk then failed). Now it is a conflict: no tuple | R-AL9 R-C2 |
| L0 | `tests/unit/closure.roc` expects 4 and 5 (the failures of `Mvs`: the problem and its text): the tag lines name R-AL9 (comments only) | R-AL9 R-C2 R-EC10 |
| L2 | `closure/cl2-chain` run 5 (the probable bug, `update --strategy lowest`, p4): the path entry `util` names `core 1.1.0`, the header has `core 1.0.0`. The pick reads the path file with the headers of its first level (one `read_files`), sees the edge, and moves core to 1.1.0. Exit 0, no second read of the file in the walk. The old code: exit 10 | R-AL9 R-AL8 R-H7 R-C2 R-DI7 R-PH10 |
| L2 | `closure/cl2-chain` run 6 (`update`, p5): the same, and `talon.toml` has `core = "acme/core@=1.0.0"`. No variable is free: exit 10, the failure of the pick (`no tuple works: the releases of core, pf do not fit together (R-C2, R-C3)`). The old code: the failure of the walk | R-AL9 R-PH10 R-EC10 |
| L2 | `closure/cl2-chain` run 7 (`verify`, p4): the same pick and walk in `verify`. The pick holds the path file, the walk reads nothing more. Exit 0 | R-AL8 R-H7 R-CM11 |
| L2 | `closure/cl2-chain` runs 1 to 4 and `closure/cl1-flow` (6 runs): no change of the calls. A transitive group has no index call (R-AL2, R-DI1), `install --frozen` and `list` read `packages/` and download nothing (R-AL8 sources 1 and 3). The ids are named in `rules` | R-AL2 R-AL8 R-DI1 R-DI7 R-FE1 |
| L2 | `resolve/rs-unmanaged` runs 1 to 11, `install/in1-flow` runs 1 to 5, `resolve/rs-install-add-key` runs 1 and 2: the same results. 10 pairs of lines of calls.log became 1 line each (D5): the read of a path file is the end of the one `read_files` call of the first level of the pick. No call is new, no call is lost | R-AL8 R-FE1 R-H7 |
| L2 | `resolve/rs-unmanaged` run 12 (C3): the platform is the path entry `base` and `talon.toml` has `base = "=0.1.0"`. `install acme/pf platform` replaces `base` and honors its key: acme/pf 0.1.0 (the old code read the key of `pf`: 0.1.1). The entry that the run replaces is no root of the closure | R-AD31 R-AD38 R-I3 R-AL9 |
| L2 | `rs-unmanaged` run 13 (C21): the path entry `json` has a key only in `[overrides]`. `install acme/json as=json`: 2.1.0 (a pass today: the gap test of the slice 015 review, only the mutation fails it) | R-AD38 R-I3 R-OV1 |
| L2 | `rs-unmanaged` run 14 (C27): `install acme/json@latest as=json` with `json = "^2"`: 2.1.0. `latest` is no selector. `talon.toml` is not changed (a pass today, as run 13) | R-SL5 R-AD38 R-I3 |
| L2 | `install/in1-flow` run 7 (C25): `add acme/util --as local --no-check --json` where `local` is the path entry `../lib/main.roc`. `data.moved[0].from` is `{ "name": "../lib/main.roc", "version": "" }` (a pass today, as run 13) | R-AD38 R-J3 |

Count: 2 new L0 expects (10 and 4 rows), 1 row changed, 1 comment. Deep: 6 new L2 runs in 2 old cases (`cl2-chain` 3, `rs-unmanaged` 3, with 5 new small projects), 1 new run in `in1-flow` (1 new project). 3 old L2 cases have lines of calls.log that changed (D5). The L3 set is not changed: no L3 expected file differs with the reference.

## Output (proposed, TW24, for the review)

| Item | Proposal |
| --- | --- |
| The failure of the pick when no tuple is left, for a problem of the closure rule (a cycle, one label with 2 hashes, a pin lower than a dep needs, 2 platforms) | The same text as for R-C2 and R-C3: `no tuple works: the releases of <id>, <id> do not fit together (R-C2, R-C3)` (D3). The text that names the problem is the text of `Closure.failure` of the walk (`install --frozen`, `list`, `why`): R-AL9 |
| `data.moved[].from` of a replace (C25) | `{ "name": "<old value as written>", "version": "" }`. No new field (the proposal of slice 015) |
| The read of a path file in the pick | No output. A file that cannot be read is the failure of the walk (kind `environment`, exit 18, `cannot read <path>`), now at the pick |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `Pick.step` gets `unmanaged` (the entries that no slot owns, for each member) and `paths` (the path files that are read) | One list `nodes` in place of `facts` (every L0 row of `pick` and `pickclosure` changes). A made-up URL for a path file as a `Release` fact. All entries of a member, slots too (the slot URL is the chosen value, not the header value) |
| D2 | The order of `Need`: the chosen slot URLs first, then the other nodes in the order of the followed edges, no repeat. A path file is an absolute path | Sorted ids. The order of the rows of `Closure.step` for all (it is the same here, but the slot URLs are the first rows by the rule of `Closure.step`) |
| D3 | A problem of the closure rule inside the pick is a conflict of the tuple (next tuple). The failure text, when no tuple is left, is the old one (R-C2, R-C3) | A new text that names the problem (the pick cannot say which tuple to blame: R-AL9 asks for the name only for the commands with no free variable, and `Closure.failure` does it) |
| D4 | The row "a cycle between packages ends the step" of `pickclosure.roc` expect 2 now expects no tuple. The old row expected `Done`. R-AL9 says that a cycle is a problem of the rule | Keep the row (R-AL9 would not hold) |
| D5 | The read of a path file by the pick is part of the one `read_files!` call of the level that names it, in the order of the ids. So in 3 old cases (`in1-flow` 4, `rs-unmanaged` 4, `rs-install-add-key` 2) 10 pairs of lines of calls.log became 1 line each. No call is new or lost | A second `read_files!` for the files (the calls.log would have a new call on each run with a path entry) |
| D6 | The entry that the run replaces (`--as`, `--platform`) is no root of the pick (`unmanaged` has no row for it): the new entry is a slot | Keep it as a root (the old file is read, and 2 platforms are a conflict) |
| D7 | C3: with `--platform` and no `--as`, the alias of the new entry is the alias of the platform entry of the current member, else `pf` | The alias `pf` (the bug) |
| D8 | C25 is a run of `in1-flow` (the entry `commands` has `--json`; the entry `resolve` of `rs-unmanaged` has not). The package `acme/util` is in the cache after run 1 | A new `--json` flag in the `resolve` entry |
| D9 | The tests do not name the module of the shared loop: the facts of a list of ids are tested through `Pick.step` (the `Need` list) and through calls.log. R-AL8 sources 1 and 3 are checked by the calls of `cl1-flow` and `cl2-chain` that do not change. Source 4 is checked by the fake download of `cl2-chain` run 1 | A test of the module |

## Out of scope

| Rule or case | Reason |
| --- | --- |
| R-AL2 and R-AL8 source 2 (the registry answer), R-AP17, R-AP28 | P2: no registry in P0 (`direct`) |
| R-DI1 with a registry (`install --frozen` and `list` send no query) | P2: the registry `Fx` calls do not exist. In P0 the design example is `direct`: no index call (checked by `cl1-flow` runs 2 and 3) |
| R-AL9 the "two platforms" problem as a separate row | `Pick` has the pairwise check of R-C3 (one platform slot), tested by `pick.roc`. The closure problem of 2 platforms comes from `Closure.step`, tested in `closure.roc` (PlatformMismatch) |
| The `Mvs` failures of the walk, `list` and `why` | Tested in slices 010 and 011. Only the tag R-AL9 is new |
| The per-member closure (Q1) | Question |

## Questions (TW17)

| # | Question | Default (the tests follow it) |
| --- | --- | --- |
| Q1 | The closure of a tuple in a workspace. roc builds each member alone. The pick has one list of slots (one variable for all members). The path files of a member that does not use a group could name a higher version than the slot, and the tuple is then a conflict that roc would not see | The reference takes, for each member, all slots as its entries and the entries of that member that no slot owns (an over-approximation, as the old `Pick.closure_of`). No test has 2 members with this case |
| Q2 | A path file that cannot be read in the pick (not there, no header): the old failure came from the walk, after the pick and the index | The same failure (kind `environment` or `input`, the same texts), now before the ladder. No test |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | The test agent ran the whole fast set with a private reference (deleted). Its shape, as a hint: `Pick.closure_of` calls `Closure.step` for each member of `unmanaged` (one dummy member when there is none). The entries are the chosen slot URLs (in slot order, with `is_platform`), then the entries of that member. The nodes are the facts (a `Release` as a `Closure.Node`: `ResolveBase.known_nodes` does it) and `paths`. A `Fail` is a conflict, a `Need(ids)` gives the `Need` of the step (no repeat). The R-C3 check (the platform that a package names) and the cut of one level stay |
| 2 | `PickFlow.pick!`: `unmanaged` for each member is its `locked.rows` with no release URL (`Ident.of_url` is `Err`) and no alias of `asked.fresh` (D6). `pick_loop!` keeps `paths` next to `facts`, and gives both to `Finish` (a new field `paths`). `InstallFlow` and `VerifyFlow` add `facts.paths` to the `known` nodes of the walk. Else the walk reads the files again (the L2 calls.log shows it) |
| 3 | One need loop: `ResolveBase.need!(fx, request, ids)` in the reference does one `Fetch.packages!` for the URL ids and one `read_files!` for all ids (`main.roc` of a URL, the file of a path id), then `Release.read` for a URL and `Release.entries_of` for a path. `Walk.level!` has the same steps, so it should call the same function. `Walk` cannot import `ResolveBase` (a cycle): put the function in a new module that both import. The calls.log of `cl1-flow` and `cl2-chain` must not change |
| 4 | C3: `PickFlow.fresh_of`: the `key` of `--platform` with no `--as` is the alias of the platform row of the current member (`ResolveBase.current_rows`), else `pf`. One line |
| 5 | Update the docs of `Pick.step` (the rules 1 to 4 of the closure are in the stub), `Walk` and `ResolveBase.read_releases!` |

## Old tests that changed

| Test | Change | Rule |
| --- | --- | --- |
| `tests/unit/pickclosure.roc` expect 2 | 1 row: the cycle gives no tuple (was `Done`) | R-AL9 |
| `tests/unit/pickclosure.roc`, `pick.roc` | The helper `step` has the 2 new fields (`[]`) | |
| `closure/cl2-chain`, `rs-unmanaged`, `in1-flow`, `rs-install-add-key` | calls.log: the line `read_files <path file>` is joined to the read of the first level of the pick (D5). Runs 1 to 4 of `cl2-chain`: no change | R-AL8 |
| `tests/unit/closure.roc` | The tag line of expect 4 names R-AL9 | R-AL9 |

## Red output (2026-10-21, `scripts/test.sh`, pinned roc, `cli/` with the stubs)

The full text is in `research/slice-016-revert/red.md`.

| Step | Result |
| --- | --- |
| `check`, `fmt`, `l3`, `selftest` | pass |
| `l0` | `pickclosure.roc`: 3 of 4 expects fail with a wrong value (the cycle row gives `Done`, the path rows never need the file, the content conflict gives web 2.0.0). The other 48 files pass |
| `l2` | 28 pass, 4 fail. `cl2-chain` run 5 is exit 10 with the failure of the walk (`$PROJECT/p4/util/main.roc needs acme/core 1.1.0, but the header names acme/core 1.0.0`): the probable bug of the gap file is real. Run 6 has the same failure in place of the failure of the pick. `rs-unmanaged` run 12 gives 0.1.1 (C3). 3 old cases have the second `read_files` call. Runs 13, 14 (C21, C27) and `in1-flow` run 7 (C25) pass: they are gap tests, only a mutation fails them (as in slice 015) |

## Revert check (TW12)

A private reference ran the whole fast set green. `research/slice-016-revert/mutate.py` put 14 small changes in it, one by one (`results.md`). The reference is deleted: `cli/` equals the stubs again (`cli-stub.sha256`, checked with `sha256sum`).

| Result | Rows |
| --- | --- |
| Caught (13 of 14) | S1 to S4 (`Pick`: the path nodes, the roots, the conflict, the `Need` list), F1 to F4 (`PickFlow`, `InstallFlow`, `VerifyFlow`: the path entries of the pick, the replaced entry, the path files in the walk), C3, C21, C25, C27, N1 (one `read_files` call) |
| Not caught | S5: the `Need` list has repeats. Equal behavior for one member (`Closure.step` has none). It needs 2 members (Q1) |
| First try not caught | F4 (`verify` had no run with a path entry): run 7 of `cl2-chain` was added. F1 and F2 did not compile (an unused value): made smaller |

## Next step

The human reviews the 2 new L0 expects, the changed cycle row, the 7 new L2 runs and 6 new small projects, the 10 changed pairs of calls.log lines (D5), the output proposals, D1 to D9 and Q1, Q2. Then the code agent (notes 1 to 5).

## Review (manager, 2026-10-21)

D1 to D9 are accepted. The red run is confirmed by the manager: l0 `pickclosure`, l2 `cl2-chain`, `in1-flow`, `rs-install-add-key`, `rs-unmanaged`.

| # | Answer |
| --- | --- |
| Q1 | Moved to slice 017 (held moves, the workspace slice): roc builds each member alone, so the closure check is per member, with the shared slot values. Slice 017 tests it. Slice 016 keeps the over-approximation. |
| Q2 | Accepted: a path file that cannot be read fails in the pick, with the text and kind of the walk (exit 18, slice 010 Q21). |

Status: code.

## Code agent result (2026-10-21)

`scripts/test.sh` exit 0 (79 s): check, fmt, l0 (49 files), l2 (32 runs of cases), l3 (26 passed, 1 skipped), selftest (24).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Gather.roc` | 58 (new) | `Gather.get!`: the one fetch of header facts for a list of ids (one `Fetch.packages!` for the URLs, one `read_files!` for all ids) |
| `cli/lib/PickLoop.roc` | 63 (new) | `PickLoop.run!`: the pick loop with `Gather.get!`. Keeps the release facts and the path nodes (`paths`). Holds `platform_wants` and the `Input` type (moved from `PickFlow`, module size) |
| `cli/lib/Pick.roc` | 304 | `closure_of` calls `Closure.step` for each member of `unmanaged` (one dummy member when none). `Pick.node_of` |
| `cli/lib/PickFlow.roc` | 577 | `unmanaged_of`, `platform_alias` (C3, D7), `Finish.paths`. `pick_loop!` and `platform_wants` moved out |
| `cli/lib/Walk.roc` | 54 | `level!` calls `Gather.get!` |
| `cli/lib/ResolveBase.roc` | 433 | `read_releases!` over `Gather.get!` (no `read` flag), `known_nodes` over `Pick.node_of`, `Finish.paths`, `main_of` removed |
| `cli/lib/InstallFlow.roc`, `VerifyFlow.roc` | 490, 130 | `facts.paths` joins the `known` nodes of the walk |
| `cli/lib/main.roc` | 83 | `Gather`, `PickLoop` in the list |

Decisions that the slice does not fix:

| # | Decision | Rejected options |
| --- | --- | --- |
| K1 | The shared function is a module `Gather` that returns the raw texts (`id`, `path`, `text`). Each caller parses: `Release.read` for a URL (pick), `Release.entries_of` (walk and path files) | A function that returns one fact type for both (the pick needs `Release`, the walk needs entries: 2 parses of one text) |
| K2 | The loop of the pick moved to `PickLoop` (PickFlow had 587 lines). `Walk.walk!` stays: the 2 loops have different state, they share the fetch and the read | One generic loop (an effectful lambda does not work) |
| K3 | `unmanaged_of` drops the replaced alias only in the current member file (the run replaces an entry only there) | Drop it in every member (note 2, literal text). No test has 2 members (F2b) |
| K4 | `Pick.node_of` is public in `Pick`: `ResolveBase.known_nodes` uses it | A copy in `ResolveBase` |

## Verify results (code agent, TW12)

`research/slice-016-revert/code-mutate.py`, results in `research/slice-016-revert/code-results.md`: caught 20 of 26. Not caught:

| Id | Gap in the tests | Rule |
| --- | --- | --- |
| P5, P11, F2b | 2 members (the `Need` list has no repeat, each member is checked, the replaced alias is for the current member only): Q1, slice 017 | R-AL9 |
| P7, P9 | The platform as an edge of the closure inside the pick: the pairwise check of R-C3 finds the same conflict first | R-C3 |
| G3 | A path file that cannot be read (kind `Environment`, exit 18, Q2) | R-FE7 |

The code after the mutations equals the copy before them (`diff -r`, 0 differences).

## Review of the code (manager, 2026-10-21)

`scripts/test.sh` passes (manager run, after the last comment edits). The revert check caught 20 of 26. K1, K2 and K4 are accepted. Moved to slice 017 (the workspace slice): K3 and P5, P11, F2b (2 members), and G3: a path file that cannot be read must give kind `Environment` (exit 18, slice 010 Q21), and the code may give `Input`. Slice 017 adds a run for G3 and the code agent fixes it if it is red. P7 and P9 are accepted: the pairwise R-C3 check finds the same conflict first.
