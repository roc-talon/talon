# 259 `tln outdated --offline` cases, and the offline count of a held move

Phase: P2. Status: tests, 2026-11-23. Item 1 green at once (a test gap). Item 2: Q638-1 decided by the user, 2026-11-23, answer (a); the slice 250 known limit is withdrawn; guard `of3` green. Item 3 (the gap row of the over-count): red case `of4`, green after the code. Mutation check (research/slice-259-revert/RESULT.md): gap tests `of5` (green) and `of6` (RED: the same over-count online), for the code agent.
Design ids (given by the manager): slice 259, Design Q638, G-C268.
Test agent: 2026-11-23. No product code.

Two small items that earlier slices left open:

| # | Item | Source |
| --- | --- | --- |
| 1 | `tln outdated --offline` with a registry has no case with a row since slice 252: no plain row from the kept copies, no moved row offline. | docs/slices/252-successor-follow.md (Q252-8, Q252-9); `Outdated.roc`, `OutdatedFlow.roc` |
| 2 | "Known limit: the second search of a held move gets no offline yanked count." | docs/slices/250-yank-filter.md, status line |

## 1. Rules

| Rule | Text (short) | Item |
| --- | --- | --- |
| Registry R-PU28 (7) | With `--offline`, the follow uses the kept R-AP1 copies (CLI R-IX6). | 1 (no follow in `outdated`, the copy of the successor is not read) |
| Registry R-PU28 (9), CLI R-CM6 | `tln outdated` shows a row for a header entry whose name has a successor; `latest` ends with ` (moved to <successor>)`, the first link only; `--json` member `successor` only when there is one. | 1 |
| Registry R-PU30, Design Q634 (6) | No owner note with `--offline`. | 1 (`oc7-offline` covers it with no successor; `of2` covers it on a moved row) |
| CLI R-IX6, R-DI12, R-IX4 | Offline: the kept copies at any age, no request, one `index: cached at <oldest>` line, the kept compiler list. | 1 |
| Resolution R-C6, R-C7, R-UP10, R-UP12 | A yanked release and a release younger than `min-release-age` are not `wanted` or `latest`. | 1 |
| Resolution R-C6 (note), Design Q630 (4) | The failure of an EMPTY DOMAIN (`<id> has no release that satisfies <range> (<n> releases, ...)`) gets `, <c> yanked` when the pick dropped yanked releases of the name. | 2 |
| Resolution R-SP16 | No tuple in the second search of a held move: "Talon stops with exit code 10 as before, and asks nothing." | 2 |
| CLI R-B3 | With a registry the yank data is on. | 2 (no text of its own for this path) |

## 2. Scope: where the code is today

| Fact | Where | Effect |
| --- | --- | --- |
| `outdated --offline` reads the kept copies of each group (`PickIndex.index!`, `Offline`), then, when a row is behind, the kept compiler list `toolchains.json` (one `platform` call and one `read_files`). It reads no copy of the successor. | `OutdatedFlow.report!` | Item 1: the cases pass at once (section 4). |
| The first search of `update`/`upgrade` counts the yanked rows of each FREE name (`PickIndex.counted!` on the first index; `Offline`: `ClosureIndex.offline!` gives `yanked`). `PickFlow.with_yanked_count` adds the count to the failure (`Answer`: `ClosureIndex.dropped` over the FIRST answer; `Offline`: the list of the first index). | `PickFlow.roc` lines 124, 151, 343 | Online and offline use the rows of the first search only. |
| The second search of a held move reads the MOVABLE names (`PickFlow.second_index!`): online the second closure answer, offline `PickIndex.index!`, which drops the yanked rows but throws the count away. | `PickFlow.roc` line 548 | This is the "known limit" of slice 250. |
| When the second search also has no tuple, the command reports the failure of the FIRST search (`Err(failed(stuck.fail))`), with the count of the first search. Another kind of failure of the second search is reported as it is (no count). | `PickFlow.search!` | The count of the second search is never used, online or offline. |
| The first search of a held move fails because a held variable blocks a free one: the text is `the releases of json, yaml, pf do not fit together (R-C2, R-C3)` (registry/sp24-update-held-move runs 2 and 3). That is not an empty-domain text, so `Pick.with_yanked` does not change it. | `Pick.with_yanked` | No count in this text, online or offline. |
| An empty domain of a FREE variable in a run that has a held move (`update json@2.1.0 --offline`, pf movable) gets the count offline: registry/yf7-offline-yanked-count (its 2 `index: cached at` lines are the two index steps: the first search and the second search). | yf7, yf11 | The offline count of the first-search text works with a held move. |

**Finding for item 2 (before the answer).** The limit is in the code only: the offline second search drops the count of the movable names, but online drops it too (`with_yanked_count` reads the first answer), and no output uses it, because the failure text is the one of the first search (R-SP16 "as before"). A test cannot make an online/offline difference visible. Whether the user must see the yanked rows that only the second search dropped is not in the design: R-C6 gives the count for "the failure of an empty domain", and R-SP16 gives the failure of the first search, whose domain had no row of the movable name. So item 2 is question Q638-1 (TW17). I wrote no red test for it.

## 3. Behaviors

| # | Behavior | Rule |
| --- | --- | --- |
| B1 | `outdated --offline` shows the rows from the kept R-AP1 copies: `wanted` and `latest` skip a yanked row and a release younger than `min-release-age`. No request. One `index: cached at` line for each run. With no kept compiler list the nightly range is `-` (`--json`: `{"state":"unread"}`). | R-IX6, R-DI12, R-C6, R-C7, R-CM6 |
| B2 | `outdated --offline` shows the moved row from the `repos` item of the kept copy: `latest` ends with ` (moved to acme/roc-json)`, `--json` has `successor`. The copy of the successor is not read. No owner line with `--offline`, also when `owner_changed` is later than the header release; `--json` has no `owner_changes`. | R-PU28 (9), R-PU30, Q634 (6) |
| B3 | (Q638-1 (a)) A held move with no tuple in both searches, offline: exit 10 with the failure of the first search (`do not fit together`), no yanked count, also when the second search dropped a yanked row. | R-SP16, R-C6, Q638 (a) |
| B4 | (gap row) The yanked count of an empty domain offline counts only the dropped rows of the group of the slot: for a slot in one series, a yanked row of another series of the same form is not counted (as online). For an `any_series` slot (a selector, `upgrade`) every series of the form is its group, so those rows count. | R-C6, R-IX6, R-ID2 |

## 4. Tests

| Layer | Case | Rules | State |
| --- | --- | --- | --- |
| L2 | `registry/of1-outdated-offline`: run 1 `outdated --offline`: `json 2.0.0 2.0.1 3.0.0 (new series) -` (2.1.0 yanked, 2.0.2 one hour old); run 2 `--json`: no `successor` member | R-CM6, R-IX6, R-DI12, R-C6, R-C7, R-UP10, R-UP12, R-E7 | passes at once (test gap) |
| L2 | `registry/of2-outdated-offline-moved`: home of su9-follow-offline (someone/roc-json moved to acme/roc-json), plus `owner_changed` transfer after the header release; run 1: `json 2.0.0 2.0.0 2.0.0 (moved to acme/roc-json) -`; run 2 `--json`: `"successor":"acme/roc-json"`, no `owner_changes`; stderr only the `index: cached at` lines | R-PU28 (7) (9), R-PU30, Q634 (6), R-CM6, R-IX6, R-DI12 | passes at once (test gap) |
| L2 | `registry/of3-offline-held-yanked`: the offline form of sp24-update-held-move run 1. Run 1: pfx 0.1.1 yanked in the kept copy: exit 10, `the releases of json, yaml, pf do not fit together (R-C2, R-C3)`, no count. Run 2 (`HOME=home2`, a control): pfx 0.1.1 not yanked: pf moves to 0.1.1 offline | R-SP16, R-SP24, R-C6, R-C9, R-IX6, R-DI7, R-DI12, Q638 (a) | passes (a guard) |
| L2 | `registry/of4-offline-count-series`: run 1 (talon.toml `json = "^2.5"`, plain `update`): expected `(3 releases, 2 outside the ranges, 0 too new, 1 yanked)`; run 2 (`update json@2.5.0`, any series): `(4 releases, ..., 2 yanked)` | R-C6, R-C9, R-PH13, R-IX6, R-ID2, R-UP10 | RED run 1: `(4 releases, 2 outside the ranges, 0 too new, 2 yanked)`; run 2 passes |

`registry/oc7-offline` already covers the R-PU30 note absent offline in `outdated` and `update` (no successor). `of2` adds it on a moved row.

How I wrote the expected files: stdout and stderr by hand from the design (the table widths as in outdated/od1-table, the `--json` item as in su11-outdated-successor, the `-` range as od1-table run 6). The calls.log from the outdated run of oc7-offline. The first run showed 2 call differences, both right by the design, and I added them by hand: after the index reads, a run with a row reads the kept compiler list (`platform`, `read_files .../toolchains.json`; R-IX4, as od1-table "only then, because rows are behind"), and a `--json` run has no `tty` call. stdout, stderr, exit and tree.diff matched the hand-written files at the first run. No UPDATE=1.

## 5. Questions (Q638-1 decided by the user 2026-11-23: (a), Design Q638)

| # | Question | Options | Recommendation |
| --- | --- | --- | --- |
| Q638-1 (decided: (a)) | A held move with no tuple in the first search and none in the second search (R-SP16, exit 10). The second search dropped yanked releases of a movable name (example: `update yaml@1.1.0`, yaml 1.1.0 needs pf 0.1.1, and pf 0.1.1 is yanked). Today the text is the failure of the first search, `the releases of yaml, pf do not fit together (R-C2, R-C3)`, online and offline, with no count. Must the user see the yanked count of the second search? | (a) No. The text stays the failure of the first search (R-SP16 "as before"); the count of R-C6 is only for an empty-domain text, from the rows of that search. Online and offline are the same now. The "known limit" of slice 250 is withdrawn (no visible effect); a guard case `registry/of3-offline-held-yanked` (the offline form of sp24-update-held-move run 1, pf 0.1.1 yanked in the kept copy: exit 10, the `do not fit together` text, no count) pins it. (b) Yes: the failure gets a second line, for example `note: the second search dropped <c> yanked releases of pf`, online from the second answer and offline from the second kept-copy read (a new text, TW24, and a code change in `second_index!` and `search!`). | (a). Reason: the design gives the count only for an empty-domain text (R-C6, Q630 (4)), and R-SP16 keeps the first failure. (b) adds text for a rare case; `tln audit` and the R-AU7 line already show yanked releases. |

## 6. Output (proposed, TW24)

No new text. B1 and B2 use the texts of R-CM6, R-PU28 (9) (Design Q632) and R-IX6.

## 7. Out of scope

| Item | Reason |
| --- | --- |
| The R-AU14 moved line in `update --offline` | Design Q622 (1): no R-AU7 or R-AU14 line with `--offline`. |
| The why text of a held move: online `yaml 1.1.0 needs pf >= 0.1.1` (the closure record), offline and direct `yaml 1.1.0 needs pf 0.1.1` (the archive header; moves/hm1-noninteractive has the same text). | Existing behavior, seen in `of3` run 2. Not a yank matter; the manager can make it a gap row if the two texts must be one. |

## 7a. The slice 250 known limit (withdrawn, Q638 (a))

The status line of docs/slices/250-yank-filter.md said: "Known limit: the second search of a held move gets no offline yanked count." With Q638 (a) this is no limit: the failure of a held move is the failure of the first search (R-SP16), and the count of R-C6 is of the rows of that search only, online and offline. The offline second search keeps no count, and no output needs one. `of3` pins it. The status line of the 250 file now says this (a status note only).

## 7b. Gap row: the offline over-count (checked, 2026-11-23)

| Step | Result |
| --- | --- |
| The claim | `ClosureIndex.offline!` counts the dropped yanked rows of a NAME over every series of the URL form (`counted!` keeps one count for each name). The slot of a variable in one series keeps only its group (`PickIndex.slots_of`, `Index.in_group`). |
| Two aliases of one name (json 2.x free, json1 1.0.0 held), `update json@2.5.0 --offline` (experiment, `.tmp/s259-exp/x1`) | `(5 releases, 3 outside the ranges, 0 too new, 2 yanked) Close versions: 2.1.0, 2.0.0, 1.0.0.` The selector frees every series (`any_series`), so the series-1 rows ARE in the domain of the slot (1.0.0 is outside and a close version). The count agrees with n: no over-count. Two aliases are not needed for the effect. |
| One alias, a slot in one series (talon.toml `json = "^2.5"`, plain `update --offline`), the kept copy also has 1.1.0 yanked (series 1) | `(4 releases, 2 outside the ranges, 0 too new, 2 yanked)`: the slot has 2 candidates (2.0.0, 2.1.0), but the count adds the series-1 row, which was never a candidate of the group. Online the answer for the group with series 2 has no series-1 row, so online gives `(3 releases, 2 outside the ranges, 0 too new, 1 yanked)`. VISIBLE, offline only. |
| Design | R-IX6: offline, the candidates of a group come from the copy "with the releases of that group"; a group is the URL form and the series (R-ID2). R-C6: the count is of the yanked releases that "the pick dropped" and `<n>` counts them. A row of another group was not dropped by the pick of this group. So the design gives the answer: the count is of the group of the slot. No question. |
| Test | Red case `registry/of4-offline-count-series` (run 1 red, run 2 a guard for `any_series`). For the code agent: count by the group of the slot (or keep the count for each group form and series), not by the name. |
| Online | Not run (no online fixture made). The online text comes from the reading of `IndexQuery.groups` (series `Ok(series)` when not `any_series`) and `ClosureIndex.dropped` over the first answer. |

## 7c. Mutation check (test agent, 2026-11-23)

`research/slice-259-revert/RESULT.md`: 5 mutants. m1, m2 killed by of4. m3 (the group match on the series only) and m4 (no groups from the R-AP1 copy) survived; gap test `registry/of5-offline-count-repo-copy` kills both (passes on the code). m5 (the online path uses the group sum) survived and is not equivalent: gap test `registry/of6-online-count-series` is RED on the code. Online, a plain `update` with two aliases of one name in two series sends both groups in the first closure query, and `with_yanked_count` counts the `Answer` by name: `(7 releases, 4 outside the ranges, 0 too new, 3 yanked)` where the group of the slot gives `(6 releases, 4 outside the ranges, 0 too new, 2 yanked)`. The rule is the one of of4 (R-C6, R-ID2), so no question. The online note of section 7b ("not run") is replaced by this result.

## 8. Files of the test agent

| File | What |
| --- | --- |
| `tests/commands/cases/registry/of1-outdated-offline/` | New L2 case (2 runs). Copies: someone/roc-json (5 rows), acme/pfx. |
| `tests/commands/cases/registry/of2-outdated-offline-moved/` | New L2 case (2 runs). Home of su9-follow-offline, `owner_changed` transfer added. |
| `tests/commands/cases/registry/of3-offline-held-yanked/` | New L2 guard case (2 runs, `home` and `home2`). Kept copies of acme/yaml, acme/json, acme/pfx; the archive of yaml 1.1.0 names pfx 0.1.1. |
| `tests/commands/cases/registry/of4-offline-count-series/` | New L2 red case (2 runs). Base yf11-offline-held-count, plus a series-1 yanked row and `u1/talon.toml`. |
| `tests/commands/cases/registry/of5-offline-count-repo-copy/`, `of6-online-count-series/` | Gap tests of the mutation check (of5 green, of6 red). `research/slice-259-revert/` (mutate.sh, RESULT.md, run.log, run2.log). |
| docs/slices/250-yank-filter.md | Status line only: the known limit withdrawn (Q638 (a)). |

## 9. Red results

| Run | Result |
| --- | --- |
| `tests/commands/run.sh registry/of1 registry/of2` | 2 passed, 0 failed (a test gap, not a bug: the code was right). |
| `tests/commands/run.sh registry/oc7-offline registry/su9-follow-offline` (guards, before the new cases) | 2 passed. |
| After Q638 (a): `run.sh registry/of1 of2 of3 of4 oc7-offline su9-follow-offline yf7-offline-yanked-count yf11-offline-held-count` | 7 passed, 1 failed: `of4` run 1 only, `(4 releases, 2 outside the ranges, 0 too new, 2 yanked)` where `(3 releases, ..., 1 yanked)` is expected. Red for the right reason. |

How I wrote the expected files of of3 and of4: stdout and stderr by hand. Each first run showed one difference that the design gives and I accepted by hand after I read it: `of3` run 2 the why text `needs pf 0.1.1` (the archive form, as hm1); `of4` run 1 the two `fixed:` lines of R-IX6. The calls.log of both: read line by line from the first run (no request; `of3` run 1 reads no archive of the yanked pfx 0.1.1, run 2 reads it). No UPDATE=1.

## 10. Design text changes (for TalonRegistry, after the answer)

| Place | Text |
| --- | --- |
| `DESIGN.md` new row Q638 | `Q638 | G-C268: the yanked count of a held move whose second search also fails (CLI slice 259)? | Decided by the user, 2026-11-23: (a). The failure stays the failure of the first search (R-SP16), with no count from the second search, online and offline; the slice 250 known limit is withdrawn (guard registry/of3). Also: tln outdated --offline cases (registry/of1, of2, a test gap since slice 252), and offline the count of R-C6 is of the group of the slot, not of the name (R-IX6, R-ID2; registry/of4).` |
| docs/slices/250-yank-filter.md status line | Done (a status note): the known limit is withdrawn (slice 259, Q638 (a)). |

## 11. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 259 | `outdated --offline` cases, the offline yanked count | Tests for R-PU28 (7) (9), R-PU30, R-CM6, R-IX6 (`registry/of1`, `of2`, a test gap since 252, green at once), R-SP16 and Q638 (a) (guard `of3`), R-C6 with R-IX6 and R-ID2 (red `of4`: offline the yanked count is of the group of the slot, `ClosureIndex.offline!` / `PickIndex.counted!`). | R-PU28, R-PU30, R-CM6, R-IX6, R-C6, R-SP16, R-ID2 | G-C268 (Design Q638) | 252, 250 / none | 30 | Sonnet |
