# 250 The yank filter of the pick

Phase: P2 (the registry has the yank routes, slice 246. `tln yank` exists, slice 249). Status: done (2026-11-17). The user approved Q630-1 to Q630-4, the texts of section 7 and the R-B3 sentence (Design Q630, G-C260). The patch base lookup by hash skips the yank filter (it is not a pick; a regression found by mutation gap G4). The known limit "the second search of a held move gets no offline yanked count" is withdrawn: the failure of a held move is the failure of the first search, with no count from the second search, online and offline (slice 259, Design Q638 (a), guard registry/of3-offline-held-yanked).
Design ids (pending, the manager writes them): Q630, G-C260. Left open by Design Q629 (13) and `docs/slices/249-yank.md` section 13, row P10.
Test agent: 2026-11-16. No product code except 2 stubs (section 9).

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-C6 (Resolution 2) | A yanked release is not chosen for a new resolution. A withdrawn release is not a candidate. |
| R-C9 (Resolution 2) | R-C6, R-C7 and a snapshot never hide the value that a header entry or the `roc:` pin has now. The value stays in the domain of its variable. |
| R-YK5 (Registry 7.2) | The current yank state applies to each resolve, also with `--snapshot log:N`. A yank never hides the value that a header has now. |
| R-YK7 (Registry 7.2) | A yank changes the answers of R-AP1, R-AP2, R-AP13, R-AP14 and R-AP17. |
| R-AP1, R-AP2, R-AP13, R-AP14, R-AP17 (Registry 4) | Each answer has release rows. A row has `yanked` and `yank_reason` (R-AP49). One decoder reads all of them (`records`). |
| R-UP1, R-UP10, R-UP12 | The domain of `update` and `upgrade` is every release that R-C6 and R-C7 allow, and the header value (R-C9). |
| R-AL13 | The values of a slot are the candidates that R-C1, R-C6, R-C7 and R-C9 allow. |
| R-B3 (CLI 6.4) | `tln x` and `tln tool install` check the yank of a matching build. With yank data, a yanked build is not used. |
| R-AU4, R-AU7 | With a registry there is no note. A command that resolves prints a warning for a yanked closure hash. (Slices 244 and 249: done.) |
| R-IN9 (2) | A platform version that is yanked: `owner/repo has no release <version>` (exists). |

## 2. Scope: where the code is today

| Fact | Where | Consequence |
| --- | --- | --- |
| `ClosureIndex.candidates` keeps a yanked row (it drops a `withdrawn` row only). It has 5 test call sites. | `ClosureIndex.roc` | The gap of Q629-13, P10. |
| `Index.Candidate` is `{ url, ident, tag, published_at, size }`. It has no `yanked`. 15 test helpers and 2 code places build it by a record literal. | `Index.roc`, `Pick.roc` (current value), `tests/unit/*Test.roc` | See Q630-1: a new member breaks all of them. |
| The pick path of every resolve command is one place: `PickIndex.index!`. It gives the candidates of the answer (`Answer`), of the kept copies (`Offline`, `ClosureIndex.offline!`) or of GitHub (`Direct`). `Direct` has no yank. | `PickIndex.roc` | One filter in `PickIndex.index!` covers `update`, `upgrade`, `add`, `install <names>`, `outdated`, and the second search of a held move (`PickFlow.second_index!`). |
| `PickIndex.index!` already gets `known`: the header values of all members (`v.uses.map(url)`). | `PickFlow.roc` line 109, `OutdatedFlow.roc` line 127 | `known` is the set of R-C9 values. No new input. |
| `Pick.step` and the solver (`packages/resolve`, `Domain.values`) already have the rule "a yanked candidate is not a value, except the header value". `OracleRequest` sends `yanked: Bool.False` for each candidate. | `Pick.roc`, `OracleRequest.roc`, `packages/resolve/Domain.roc` | The solver needs no change if the lists have no yanked row (Q630-1 (b)). |
| `tln init` (`Init.registry_list!`), `tln tool install`, `tln x`, `tln tool update` (`ToolFlow.release_list_with!`), and `FullName.closure_item` drop a yanked R-AP1 row today. | `Init.roc`, `ToolFlow.roc`, `FullName.roc` | R-B3 for a registry works for the yank part. Only the note is wrong (next row). |
| `XFlow.note_reuse!` and `XTake.online!` print `note: no yank and advisory data without a registry` for each reused build, also with a registry. | `XFlow.roc`, `XTake.roc`, `XCmd.no_data` | The R-B3 gap, and the red part of `yf3`. |
| `AuditResolve.warn!` prints the R-AU7 warning for each yanked hash of the result of the resolve. | `AuditResolve.roc` | A header value that stays on a yanked release gives the warning (as the design says). |
| `PatchApply` calls `PickIndex.index!(fx, request, [x.name], [])`: `known` is empty. | `PatchApply.roc` line 198 | Risk: the patch base is a header value (R-PA13). The code agent must pass it as `known`, else the filter drops a yanked base. No test (section 8). |
| A kept copy of R-AP1 (`--offline`, R-IX6) has the yank state of the time of the copy. | `ClosureIndex.offline!` | No new rule: `--offline` shows the state of the copy (R-IX4). The same filter applies to the rows of the copy. |

## 3. The pick paths

| Command | Index source | Yank data | Today | After the slice | Test |
| --- | --- | --- | --- | --- | --- |
| `update`, `upgrade` (free variables, also the second search of a held move) | Closure answer, kept copy | `yanked` of each row | Chooses a yanked release | Not chosen. A yanked header value stays (R-C9). | L2 `yf1` runs 1 to 4, L0 `live` |
| `add <full name>`, `install <names>` | R-AP1 (group, `closure_item` drops yanked), then the closure answer | `yanked` of each row | The first read is right, then the pick chooses the yanked release | Not chosen | L2 `yf2` |
| `outdated` | Closure answer | `yanked` | `wanted` and `latest` can be a yanked release | Not | L2 `yf1` run 5 |
| `install` (no names), `install --frozen`, `verify`, `list`, `why` | None for a new value (all held) | n/a | No pick | No change. A header on a yanked release gives the R-AU7 warning only. | none |
| `tool install`, `tool update`, `x`, project tools (R-PT4) | R-AP1 | `yanked` | Drops yanked rows (done) | No change in the choice. The note is only for `direct`. | L2 `yf3`, L0 `reuse_note` |
| `init`, `init --platform owner/repo@v` | R-AP1 | `yanked` | Drops yanked rows (done) | No change | none (exists in `in*` cases) |
| `patch` (rebase of the base release) | `PickIndex.index!` | `yanked` | Finds the release of the base hash | Must still find a yanked base: pass the header values as `known` | none (risk, section 8) |
| `audit` | Closure answer | `yanked` | Reports yanked (slice 244) | No change | none |
| `direct` | GitHub | none | No yank | No change (the note stays) | none |

## 4. Behaviors

| # | Behavior | Rules |
| --- | --- | --- |
| B1 | `ClosureIndex.live { releases, held }`: a row with `yanked` true is dropped. The other rows stay, in the order of the rows. `withdrawn` is not read (`candidates` drops it). | R-C6, R-AP49 |
| B2 | A yanked row stays when it is the value of a header entry: a `held` URL with the same group form, version and hash as the row (the label of `drop_labels`). A `held` text with another hash, a path or a URL that is no release holds no row. | R-C9, Q461 |
| B3 | `PickIndex.index!` applies `live` with `known` as `held` to the rows of `Answer`, and to the rows of each kept copy in `Offline` (`ClosureIndex.offline!` gets `known`). `Direct` is as it is. | R-C6, R-DI14, R-IX6 |
| B4 | A yanked release is not chosen by `update`, `upgrade`, `add`, `install <names>`, nor shown as `wanted` or `latest` by `outdated`. | R-C6, R-UP1, R-UP10, R-UP12 |
| B5 | A header value on a yanked release stays in the domain. `update` moves it to a newer release that is not yanked, and keeps it when no such release exists (also when only older releases are live). The result of the resolve has the R-AU7 warning. | R-C9, R-UP1, R-AU7 |
| B6 | The yank state of now applies at a snapshot: a release at or below `log:N` that is yanked now is not chosen. A header value stays. | R-YK5, R-C9 |
| B7 | `tln x` and `tln tool install` with a registry print no `note: no yank and advisory data without a registry` for a reused build. With `direct` they print it. A reused build of a yanked release is not used (done today). `XCmd.reuse_note(index)` is the pure decision. | R-B3, R-C6, R-AU4 |
| B9 | A name that the user types and that is yanked is not chosen: `add acme/known@1.1.0` stops at R-AD35 step 5 with `NoMatch` (exit 2, `Add.no_release`, close versions without the yanked releases). `update json@2.1.0` gives the `no tuple works` failure of `Pick.step` (exit 10, R-SL12), as for a version that does not exist. `tool install acme/foo@1.2.3` gives `<name> has no release 1.2.3` (exit 2; the yanked R-AP1 rows are dropped today, so it passes already, no case). | R-C6, R-IN9 (2), R-SL12 |
| B10 | A name with releases and no selector, each release yanked: exit 2, `<name> has no release that Talon can use: each release is yanked.` (`FullName.each_yanked`), after the R-AP1 read and before the closure query. | R-C6, R-AD35 step 2 |
| B11 | (Offline too: the count of the rows that `ClosureIndex.live` dropped from a kept copy shows as for an answer.) The failure of an empty domain counts the dropped yanked rows (`Pick.with_yanked`, section 7): the total counts them, `<c> yanked` follows `too new`, only when c is above 0. The count of a name is the number of rows that `ClosureIndex.live` dropped for it. | R-C6, R-PH13 |
| B8 | A yank adds no request and changes no request body: the filter is in the client. The calls of a run with a yanked row are the calls of a run with no yanked row. | R-AP34 |

## 5. Tests

| Layer | Case | Checks | Red state |
| --- | --- | --- | --- |
| L0 | `tests/unit/YankfilterTest.roc`, in driver `l0-1.roc`: `live` drops a yanked row, keeps the order | R-C6, B1 | fails: `crash "todo"` (stub) |
| L0 | same file: a held yanked URL stays | R-C9, B2 | fails: todo |
| L0 | same file: a held URL with another hash keeps nothing | R-C9, Q461, B2 | fails: todo |
| L0 | same file: a path and a non-release URL in `held` keep nothing | R-C9, B2 | fails: todo |
| L0 | same file: all rows yanked, no held value: no row | R-C6, B1 | fails: todo |
| L0 | same file: `candidates` of the `live` rows, with and without the held yanked row | R-C6, R-AP49, B1, B2 | 2 fail: todo |
| L0 | same file: `XCmd.reuse_note(Direct)` is the note, `Registry` is none | R-B3, R-C6, R-AU4, B7 | 2 fail: todo |
| L2 | `registry/yf1-update-yanked`, run 1: `update` (u1) moves json to 2.1.1 (not the yanked 2.1.0) and parser to 1.1.0 (not the yanked 1.2.0) | R-C6, R-AP17, R-DI14, B4 | fails: chooses 1.2.0, warning on stderr |
| L2 | same case, run 2: the header has the yanked json 2.1.0 (u2): it moves to 2.1.1 | R-C9, R-C6, R-UP1, B5 | fails: parser 1.2.0 (the json line passes) |
| L2 | same case, run 3: `--snapshot log:25` (u1): json 2.1.0 (log 25) is yanked now, so json moves to 2.0.5 | R-YK5, R-YK7, B6 | fails: chooses 2.1.0 |
| L2 | same case, run 4: `--snapshot log:25` (u2): the header value stays, "nothing to change", the R-AU7 warning | R-C9, R-YK5, R-AU7, B5 | passes now (a guard) |
| L2 | same case, run 5: `outdated` (u1): `wanted` and `latest` of parser are 1.1.0 | R-C6, R-UP10, B4 | fails: 1.2.0 |
| L2 | `registry/yf2-add-yanked`: `add acme/known` with 1.1.0 yanked in R-AP1 and in the closure answer: `+ known: acme/known 1.0.0`, no warning, the calls of `ad35-add-latest` | R-C6, R-AD35, R-YK7, B4, B8 | fails: adds 1.1.0, warning |
| L2 | `registry/yf3-x-yanked`, run 1: `x acme/bar` reuses the entry 1.0.0 with a registry: no `note: no yank ...` line | R-B3, R-C6, R-AU4, B7 | fails: the note is printed |
| L2 | same case, run 2: the entry 1.0.0 is yanked (second answer): 1.1.0 is built, no note | R-B3, R-YK7, B7 | passes now (a guard, but the note part fails) |

| L0 | same file: `closure_item` with the selector `1.1.0` and 1.1.0 yanked is `NoMatch` (not a fall back to the yanked row). A control with no yank finds the group. | R-C6, R-AD35, Q630-2, B9 | fails: gives the group (a wrong value) |
| L0 | same file: `FullName.each_yanked`: kind `Usage` (exit 2), the text | R-C6, R-AD35, Q630-3, B10 | 2 fail: todo |
| L0 | same file: `Pick.with_yanked`: 0 gives the old text, 3 gives `(5 releases, ..., 0 too new, 3 yanked)`, all rows yanked, a range failure, and the 2 other failures stay | R-C6, R-PH13, Q630-4, B11 | 6 fail: todo |
| L2 | `registry/yf4-update-named-yanked`: `update json@2.1.0` (2.1.0 yanked): exit 10 and the text with `1 yanked` and the close versions without the yanked release | R-C6, R-SL12, R-PH13, Q630-2, Q630-4, B9, B11 | fails: exit 0, chooses 2.1.0 |
| L2 | `registry/yf5-add-each-yanked`: `add acme/known`, each release yanked: exit 2, no closure query | R-C6, R-AD35, Q630-3, B10 | fails: exit 0, adds 1.1.0 |
| L2 | `registry/yf6-add-named-yanked`: `add acme/known@1.1.0`, 1.1.0 yanked: exit 2, `no release of acme/known matches '1.1.0'. Close versions: 1.0.0.` | R-C6, R-AD35, R-SL12, Q630-2, B9 | fails: exit 0, adds 1.1.0 |
| L2 | `registry/yf7-offline-yanked-count`: `update json@2.1.0 --offline`, a kept copy where 2.1.0 is yanked: the count `1 yanked` shows on the Offline path too | R-C6, R-IX6, R-PH13, Q630-4, B3, B11 | fails: the row is dropped, the text has no count |

The L0 `expect`s name the rule ids in their comments. The `rules` file of each L2 case lists the ids.

## 6. Questions (answered by the user 2026-11-16, pending Design Q630)

Answers: Q630-1 (b), the `live` filter. Q630-2 accepted. Q630-3 accepted. Q630-4: the yanked count is IN this slice (proposal below). The R-B3 sentence of section 11 is approved.

| Id | Question | Options | Recommendation and reason | Effect now |
| --- | --- | --- | --- | --- |
| Q630-1 | How does the pick know that a row is yanked? Design Q629 (13) says: add `yanked` to `Index.Candidate`. | (a) A new member `yanked : Bool` in `Index.Candidate`. Each `Pick`, `Oracle` and `Outdated` test helper (15 places, `tests/unit`) and 2 code places must add `yanked: Bool.False` at the same time as the type, so a test agent edits the tests and a code agent edits the code in one step (TW18 gives each of them one half). `Pick.domain_of` drops a yanked candidate, except `current`. `OracleRequest` sends the member. (b) A pure function `ClosureIndex.live { releases, held }` drops the yanked rows (B1, B2) before they become candidates. `held` is `known`, which `PickIndex.index!` has already. No shared type changes. | (b). Reasons: (1) every consumer gets the filter at one place (`add`, `Index.new_entry`, `Outdated`, `ToolInstall`) instead of one by one, (2) no change of a type that about 40 test sites use, (3) R-C9 is met with `known`, (4) the solver rule of `Domain.values` stays as a second guard. The cost of (b): `Pick` cannot say "n yanked" in a failure message (Q630-4). The tests of this slice follow (b). With (a), the L0 tests of section 5 change to `Pick.step` tests, and the L2 cases stay. | The L0 tests and the stub `ClosureIndex.live` follow (b). The L2 cases hold for both. |
| Q630-2 | A version that the user names and that is yanked: `tln add acme/foo@1.2.3`, `tln update foo@1.2.3`, `tln tool install acme/foo@1.2.3`. R-C7 lets a named version skip the age. Does the name skip the yank? R-C6 says "not chosen"; R-IN9 (2) says a yanked platform version is "no release". | (a) No: a yanked release is never chosen, also when named. The command stops with exit 2 and its text of "no such release". (b) Yes: a named release is chosen, with the R-AU7 warning (as a header value). | (a). Reason: R-C6 has no exception for a name, R-IN9 (2) already treats the named platform version this way, and `Domain.values` (solver) has no exception. The user keeps the way to pin a yanked release: write the URL by hand (R-ID7, a hand edit stays, R-C9). | No test. Under (b) `live` would need a `named` input. |
| Q630-3 | A name with only yanked releases and no selector: `tln add acme/foo` (each row yanked). `FullName.closure_item` falls back to the yanked rows for the first read. After the filter, no candidate is left. What does the command print? | (a) Exit 2 with the text `no_candidate` plus the yank: `acme/foo has no release that Talon can use. A release needs one <hash>.tar.zst asset and must not be a draft, a prerelease or yanked.` (a proposal, TW24: it changes the text of `FullName.no_candidate` for all cases). (b) Exit 2 with a new text only for this case: `acme/foo has no release that Talon can use: each release is yanked.` (c) Exit 10, `no tuple works` of the pick. | (b). Reason: the user gets the real cause, and no existing test text changes. | No test (the code that prints it is not clear before Q630-1). |
| Q630-4 | The failure text of an empty domain (R-PH13) counts `n releases, a outside the ranges, b too new`. Under (b) of Q630-1, a yanked row is not counted. A name whose rows are all yanked and one range prints `0 releases`. | (a) Leave it: not in this slice. (b) Count the dropped rows and add `, <c> yanked` when c is above 0 (a proposal, TW24). | (a) in this slice, (b) later. Reason: (b) needs the count through `ResolveBase.Candidates` and a new test group. The message `0 releases` is true for the pick. | No test. |

Answers of the user (2026-11-16): Q630-1 (b). Q630-2: accept the recommendation (a yanked named version is not chosen, exit 2). Q630-3: accept (b), exit 2, `<name> has no release that Talon can use: each release is yanked.` Q630-4: the count is built in this slice, with the text of section 7. The tests of sections 5 and 10 follow these answers.

Q630-4 choices that I made as a TW24 proposal (not a TW17 question: they are output text), with the reason. Change them at the review if you want another form:

| # | Choice | Recommendation | Reason |
| --- | --- | --- | --- |
| a | The total `<n> releases` counts the dropped yanked rows | Yes | The 3 counts add up: n = outside + too new + yanked (when the domain is empty). Without it `0 releases` hides the cause. |
| b | The part `, <c> yanked` shows only when c is above 0 | Yes | `direct` has no yank, so each old text, test and case stays. With a registry the text changes only when a row was dropped. |
| c | A yanked row counts as `yanked` also when it is outside the range | Yes | The filter runs first (B3), so the pick never sees the row. A count by range needs the row. |
| d | A held yanked value is not dropped, so it is not counted | Yes | R-C9: it is in the domain. |
| e | Where the count comes from | `PickIndex.index!`: `ClosureIndex.live` drops rows, the count of a name is `rows - kept` | No shared type: the flow amends the failure with `Pick.with_yanked` as `with_close_versions` does (a pure function of the message and the count). The code agent chooses how the count reaches the flow. |

Design points that need no question (they follow the rules): a header on a yanked release is never an error (R-C9), `install --frozen`, `verify` and a run use no yank check (R-PT8, R-C9), and the R-AU7 warning and `tln audit` report it (slices 244, 249). `update` keeps a yanked header value when no newer live release exists (B5, R-UP1).

## 7. Output (proposed, TW24)

Q630-4, `Pick.with_yanked` (R-PH13; the only other text that lists why releases were left out is the same message in `Pick.first_failure`; `OracleCause.failure` and `Explain` hold probe causes only, R-AL10, R-AL11 do not change):

| Case | Before | After |
| --- | --- | --- |
| c = 0 (`direct`, or no row dropped) | `no tuple works: json has no release that satisfies =2.1.0 (4 releases, 4 outside the ranges, 0 too new)` | the same |
| c above 0 | none | `no tuple works: json has no release that satisfies =2.1.0 (5 releases, 4 outside the ranges, 0 too new, 1 yanked)` (+ ` Close versions: 2.1.1, 2.0.5, 2.0.0.` for a selector, R-SL12) |
| all rows yanked, any range | `(0 releases, 0 outside the ranges, 0 too new)` | `(2 releases, 0 outside the ranges, 0 too new, 2 yanked)` |
| The kind of R-C4, "do not fit together" | | not changed |

The text of Q630-3 and Q630-2:

| Command | Text |
| --- | --- |
| `add acme/known` (each release yanked) | `tln: error[usage]: acme/known has no release that Talon can use: each release is yanked.` |
| `add acme/known@1.1.0` (yanked) | `tln: error[usage]: no release of acme/known matches '1.1.0'. Close versions: 1.0.0.` (the close versions leave out the yanked releases) |
| `update json@2.1.0` (yanked) | the failure of the first row above, exit 10 |

Other output: no new text. The warning of a yanked closure hash is the R-AU7 text of slice 244 (`warning: json: acme/json 2.1.0 is yanked ("parse bug"). Fix: tln update json.`). The texts of Q630-3 and Q630-4 wait for the answers.

Two cases hold a warning on stderr with exit 0 (`yf1` run 4: the R-AU7 warning of a header value that stays on a yanked release; before the slice `yf1` runs 1 to 3 and `yf2` print the same warning for a chosen yanked release). It is a warning, not an error.

## 8. Out of scope

| Item | Why |
| --- | --- |
| `tln outdated` with a mark for a yanked package (R-CM6 names the yank state of a project tool) | Not in the design for a package. A separate question for the manager. |
| A patch (`patch`, `PatchApply`) with a yanked base | Risk: `PatchApply` passes `known: []`. The code agent passes the header values (R-PA13, R-C9). I wrote no L2 case: it needs a patch fixture with a registry. The verify step checks it. |
| The advisories and the scanner hook | P3 |
| A yank of a compiler (nightly) | Compilers have no yank. |
| A change of `packages/records` | None needed: `records.Release.Row` has `yanked` and `yank_reason`. |

## 9. Files of the test agent

| File | Change |
| --- | --- |
| `tests/unit/YankfilterTest.roc` | New: 19 `expect`s (9 first, 10 after the answers) |
| `tests/unit/l0-1.roc` | One line: `import YankfilterTest` |
| `tests/commands/cases/registry/yf1-update-yanked/` | New L2 case: 5 runs |
| `tests/commands/cases/registry/yf2-add-yanked/` | New L2 case: 1 run |
| `tests/commands/cases/registry/yf3-x-yanked/` | New L2 case: 2 runs |
| `cli/lib/ClosureIndex.roc` | Stub: `ClosureIndex.live` (`crash "todo"`). The code agent replaces it. |
| `cli/lib/XCmd.roc` | Stub: `XCmd.reuse_note` (`crash "todo"`). The code agent replaces it. |
| `cli/lib/Pick.roc` | Stub: `Pick.with_yanked` (`crash "todo"`) |
| `cli/lib/FullName.roc` | Stub: `FullName.each_yanked` (`crash "todo"`) |
| `tests/commands/cases/registry/yf4-update-named-yanked/`, `yf5-add-each-yanked/`, `yf6-add-named-yanked/` | New L2 cases |

No shared type changed. The 9 L0 drivers compile, and the 206 old tests of `l0-1` and all tests of `l0-2` to `l0-9` pass.

## 10. Red results (test agent, 2026-11-16)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-1.roc` | 225 tests: 207 pass, 18 fail, 0 compiler errors | 17 `expect`s of `YankfilterTest.roc` fail on `crash "todo"`. 1 fails on a wrong value (`closure_item` of a yanked named version gives a group, not `NoMatch`). 1 is a control that passes. |
| `roc test tests/unit/l0-2.roc` to `l0-9.roc` | all pass | The stubs change no old test |
| `tests/commands/run.sh` (all cases) | 688 pass, 6 fail (`yf1` to `yf6`) | `yf4`, `yf5`, `yf6`: exit 0 and a chosen yanked release, the R-AU7 warning. `yf1`: stdout has parser 1.2.0 and json 2.1.0 (run 3), stderr has the yank warnings. `yf2`: `acme/known 1.1.0` and the warning. `yf3`: the extra line `note: no yank and advisory data without a registry`. |

## 11. Design text changes (for TalonRegistry, after the answers)

| Spot | Old | New |
| --- | --- | --- |
| `DESIGN-CLI.md` R-B3 (about line 1326), the sentence with the note | `With no yank or advisory data (`direct`, or a registry before P3), Talon checks only that the release is still a candidate (R-DI3) and prints the note of R-C6. The note shows only when a cached build is reused.` | `With a registry the yank data is on (Design Q629, Q630): a matching build of a yanked release is not used, and Talon builds the newest release that is not yanked. The advisories are P3 and have no note until then (R-AU4). With `direct` there is no yank and advisory data: Talon checks only that the release is still a candidate (R-DI3) and prints the note of R-C6. The note shows only with `direct`, and only when a cached build is reused.` |
| `DESIGN-RESOLUTION.md` R-C6, last column | `The pick does not drop a yanked row yet: the filter is slice 250 (Design Q629 (13)).` | `The pick drops a yanked row, except the value of a header entry (R-C9): CLI slice 250, `ClosureIndex.live` (Design Q630).` |
| `DESIGN.md` Q629 row, item (13) | `(13) The filter of a yanked row in the pick is a later slice (Q629-13).` (the text of TalonRegistry) | `(13) The filter is slice 250 (Design Q630).` |
| `DESIGN.md`, a new row | none | `Q630 | G-C260: the yank filter of the pick (CLI slice 250; Resolution R-C6, R-C9; Registry R-YK5, R-YK7)? | Decided by the user, 2026-11-16, all recommended answers (relayed by talon-6f; reasons in docs/slices/250-yank-filter.md, Q630-1 to Q630-4). (1) The rows of a registry answer or of a kept copy that are yanked are dropped before they become candidates (`ClosureIndex.live`), except the value of a header entry (`known`, R-C9). No shared type changes. (2) A yanked version that the user names is not chosen: `add` exit 2 (`no release of <name> matches '<v>'`), `update` exit 10 (R-SL12). (3) A name with only yanked releases and no selector: exit 2, `<name> has no release that Talon can use: each release is yanked.` (4) The failure of an empty domain counts the dropped rows: `(<n> releases, <a> outside the ranges, <b> too new, <c> yanked)`, with `<c> yanked` only when c is above 0 and n counting the yanked rows (R-PH13). (5) With a registry a reused build of `tln x` prints no note (R-B3).` |
| `DESIGN-RESOLUTION.md` section 5, R-PH13 (the text of the empty domain) | `... (<n> releases, <a> outside the ranges, <b> too new)` (in the CLI text; the design rows R-AL10 and R-AL11 do not hold it) | The same text with the sentence: `When the pick dropped yanked releases of the name (R-C6), the part `, <c> yanked` follows `too new`, and `<n>` counts them (Design Q630).` The place is the row that gives the text of the empty domain: the manager finds it (R-PH13 or the table of `no tuple works`). |

## 12. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 250 | The yank filter of the pick | Tests for R-C6, R-C9, R-YK5, R-YK7, R-B3, R-PH13. The pure `ClosureIndex.live` (rows with `yanked` are dropped, a held value stays), its call in `PickIndex.index!` (`Answer` and `Offline`, `known` as `held`), `XCmd.reuse_note` (no note with a registry) in `XFlow.note_reuse!` and `XTake.online!`, the `known` of `PatchApply`, the named yanked version (`FullName.closure_item`), `FullName.each_yanked`, and the count `Pick.with_yanked` in the failure. | R-C6, R-C9, R-YK5, R-YK7, R-B3, R-AU4 | G-C260 (Design Q630) | none / none | 60 | Sonnet |

## 13. After the code (test agent, 2026-11-17)

| Item | Result |
| --- | --- |
| Dispute on `yf4` `calls.log` | The code is right. `update X@<version>` sends a second `POST /v1/closure` (the other free groups, `hashes: []`) when the first search fails, for the second search of the movable variables (R-SP24, R-AP3). Evidence: `registry/ap30-update-error-notes` (`update yaml@1.1.0`, exit 10) has 2 POSTs for each run (4 for 2 runs). The slice changes no request (B8). My `calls.log` guess had one POST and was wrong. I made this file from the real run of the code, and I read each line: the only change is the second POST (4 lines at the end). stdout, stderr and exit were right. |
| Gap: the count on the Offline path | New case `registry/yf7-offline-yanked-count` (built from `ix6-update-offline`: its home with the kept copies, the json copy has 2.1.0 yanked). Red: the rows are dropped (so the filter is there), but the text is `(1 releases, 1 outside the ranges, 0 too new)`. Expected: `(2 releases, 1 outside the ranges, 0 too new, 1 yanked)`. The `calls.log` and `tree.diff` come from the run of the code before the count (an offline run sends no request). The 2 `index: cached at` lines are the 2 index steps of the run (the first has the json copy only, 17:46:40, the second has the oldest copy, 15:00:00). |

## 14. Mutation gaps closed (test agent, 2026-11-17)

Source: `research/slice-250-revert/RESULT.md` (G1 to G6). The tests check built behavior. A failing test is a code bug: I did not bend a test.

| Gap | New test | Result on the code |
| --- | --- | --- |
| G1 (`live` label) | L0 `YankfilterTest.roc`: 3 `expect`s: the same hash with another version, and the same hash and version in the form `v1.1.0`, drop the yanked row. All three equal keep it. | passes |
| G2 (`each_yanked_check` with a selector) | L2 `registry/yf5b-add-each-yanked-version`: `add acme/known@1.0.0` (every release yanked) gives the no-match text with no close versions. `@latest` gives `each release is yanked`. | passes |
| G3 (close versions with a yanked row) | L2 `registry/yf8-add-nomatch-close`: `add acme/known@9.9.9` with 1.1.0 yanked: `Close versions: 1.0.0.` | passes |
| G4 (patch) | L2 `registry/yf9-patch-yanked`: see below | FAILS: code bug or design gap |
| G5 (withdrawn counts) | L2 `registry/yf5c-add-each-withdrawn`: 1.0.0 withdrawn, 1.1.0 yanked: the each-yanked text | passes |
| G6 (`held` in `counted!`) | L2 `registry/yf10-update-held-count` (answer) and `registry/yf11-offline-held-count` (kept copy): a header on a yanked release stays and is NOT counted: `(6 releases, 5 outside the ranges, 0 too new, 1 yanked)` and `(3 releases, 2 outside ...)` | passes |

**G6, the date of a held value.** I checked the design and the outputs. A header value gets `published_at: 0` from `Domain.with_header` when the list lacks it. No output uses the real date of a header value: `Pick.chosen_for` gives a note only for a `Move` (a `Keep` has none), `outdated` and `--json` show versions, the age and the snapshot never hide the header value (R-C9), and the order is by version. So the real date needs no test, and `held` in `counted!` has no effect on the pick. It has an effect on the COUNT: without `held` a held yanked value would be counted as dropped. yf10 and yf11 pin this (the count of R-PH13, my proposal d of section 6). So `held` is not dead, if the count must not include a header value. The decision to keep it, or to count the header value, is the coordinator's.

**G4, finding.** `patch` with a registry does not use the registry index at all (it reads the GitHub list: `Direct`). The base lookup (`PatchApply.fetch_base!`) uses the registry only for `install` and `update` with `--offline` (kept copies) or after a closure answer. `fetch_base!` calls `PickIndex.index!` with `known = [x.entry.url]`, the HEADER URL. The base release is a different release than the header (when the base is in the cache, no lookup is made), so `held` never holds the base. In `yf9` the base of the patch is json 2.1.0, which is yanked in the kept copy: the filter drops the row, and the command stops with exit 14 `no release of acme/json has that hash`. R-PA13 finds the release that HAS the hash: this is no pick (R-C6 says "not chosen for a new resolution"). The expected result of yf9 is exit 15 (the base is found, its fetch stops with `--offline`). It is exit 14 now. Question for the manager: is a yanked patch base found (my recommendation: yes, a lookup by hash is no choice), and so `fetch_base!` must read the rows with no yank filter? Mutant q11 (`known` is `[]`) cannot be caught by any case: the header URL never equals a base that needs a lookup.

**Mutants again** (`research/slice-250-revert/mutate.sh q1b q1c q8 q9 q11 q12 q13 q14`): q1b, q1c (L0), q8, q9, q12, q13, q14 are caught now. q11 stays not caught: it cannot be caught (see G4), `yf9` fails with and without it.

Red state now: L0 `l0-1` 228 pass, 0 fail. L2 (all cases): 700 pass, 1 fail (`yf9-patch-yanked`).
