# 082 The exclude list in the project resolve

Phase: P1. Status: done (code agent, 2026-10-27)

Slice 082 is the plan row 082 of `PLAN-P1.md` (section 2d). It needs slice 081 (`Age`, the key). Source: Decision 1 of the user (2026-10-27), `DESIGN-GAPS-2026-10-27.md` (A4, A5, A7, A8). The design is R-C14, R-C15 (first row, and the table of what the list does not change), R-C16, R-C7, R-C9, R-UP1, R-DT3, R-DT4.
Scope: the resolve and the commands that work on a project: `install`, `add`, `update`, `upgrade`, `outdated`. Tools are in 083, compilers in 084, `init` in 085.

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-C15 (row 1) | A candidate of a variable (a direct package, the platform) whose `owner/repo` matches a pattern is not hidden by `min-release-age`. | L0 `PickTest`, `OutdatedTest`; L2 `resolve/rs-exclude-age`, `outdated/od3-exclude` |
| R-C14 | The list of a run is `Age.join` of `[resolution]` of the project and `config.toml`. A project `min-release-age` does not change it. | L0 `ResolveBase` row (`settings_of`); L2 `resolve/rs-exclude-age` run 3 |
| R-C15 (list of "does not change") | A `snapshot` time still hides a matching release published after it. A yanked release is not a candidate. The header value stays (R-C9). A named version keeps the R-C7 note. A transitive package has no age. | L0 `PickTest`; L2 `rs-exclude-age` runs 4, 5 |
| R-C16 | One `note:` line for a newly chosen release that is young and kept by a pattern, in the place of the R-C7 note (stdout, and `data.notes` with `--json`). No note for a kept header value, an old release, or a named version (the R-C7 note). `outdated` prints none. | L0 `PickTest` (`chosen_for`); L2 `rs-exclude-age`, `od3-exclude` |
| R-C7, R-UP1 | `upgrade` and `update` take the newest release that the age rule allows, the pattern included. | L0 `UpgradeTest`/`PickTest` (`Pick.newest`); L2 `upgrade/ug5-exclude` |
| R-C15, R-DT4 (solver) | The solver (`packages/resolve`, `Domain.hidden`, rule 4) is a seventh age test. It stays unchanged. `OracleRequest.solver_slot` gives it `Age.seen` as the time of each candidate, so an excluded candidate looks old to it and a candidate after the snapshot looks as before (section 3a). | L0 `OracleTest`/`OraclerequestTest` (`solver_slot` rows, a search that picks the young release); L2 `rs-exclude-age` runs 1, 3, `ug5-exclude` |
| R-WS5 | In a workspace the list is read from the root file. A member file does not have it. | L2 `rs-exclude-age` run 6 |
| R-C13 | A bad pattern: exit 19 (081). Here: the check runs before the release list is read in `install`. | L2 `rs-exclude-bad` (081) |

## 2. Public signatures

No stub crashes here: the changes are new fields and calls of `Age` (081). The test agent changes the record literals of the old tests (section 4).

| Module | Change | Rule |
| --- | --- | --- |
| `Pick.Step` | New field `exclude : List(Str)` (the patterns, already joined) | R-C14, R-C15 |
| `OracleBase.Input` | New field `exclude : List(Str)` next to `min_age` | R-C15 |
| `OracleRequest.solver_slot` | The time of a candidate is `Age.seen({ published_at: c.published_at, snapshot, exclude, name: c.ident.name })`. `solver_slot` gets `snapshot` and `exclude` from the `Input`. `packages/resolve` is not changed. | R-C15, R-DT4 |
| `Pick.is_hidden` (private) | `Age.hides({ now, min_age, published_at, exclude, name: c.ident.name })` in place of `too_young`. The `exempt` test stays (current value, named version). The snapshot test stays. | R-C7, R-C9, R-C15 |
| `Pick.chosen_for` | Input gets `exclude : List(Str)`. The name comes from `Ident.of_url(url)`. `note`: the R-C7 note when the slot names this version and it is young. Else, when `change` is not `Keep`, `Age.note`. Else `Err(None)`. | R-C7, R-C16 |
| `Pick.newest`, `Pick.newest_in` | The `ctx` record gets `exclude : List(Str)` | R-C15, R-UP2 |
| `Outdated.versions` | Input gets `exclude : List(Str)`. It passes it to `Pick.newest` and `Pick.newest_in`. | R-C15 |
| `ResolveBase.Settings` | New field `exclude : List(Str)` | R-C14 |
| `ResolveBase.settings_of` | `exclude: Age.join({ project: intent.resolution.min_release_age_exclude, user: loaded.config.min_release_age_exclude })` | R-C14 |

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Pick.roc`: `Step`, `is_hidden`, `too_young` (kept for the named note only), `chosen_for`, `newest`, `newest_in` | As section 2. The doc comment of rule 3 in the table of `Pick.step` names R-C15. |
| 2 | `PickIndex.roc` (the Step it builds, `min_age: settings.min_age`) | `exclude: settings.exclude` |
| 3 | `PickLoop.roc`, `OracleBase.roc`, `OracleSearch.roc` (`chosen_of` calls `Pick.chosen_for`), `Lags.roc`, `PickFlow.roc` | Pass `exclude` where they pass `min_age` |
| 4 | `ResolveBase.roc`: `Settings`, `settings_of` | As section 2 |
| 5 | `Outdated.roc`, `OutdatedFlow.roc` (`pending_of`, `row_of`: the ctx gets `exclude: settings.exclude`) | As section 2 |
| 6 | `OracleRequest.roc` (`solver_slot`, line 44; `request_of`, `moving`) | Pass `snapshot` and `exclude` to `solver_slot` and map the time with `Age.seen`. `OracleSearch.chosen_of` keeps the original `published_at` of `slot.candidates` (the note needs the real age). |
| 7 | The notes | `Chosen.note` joins the notes that the R-C7 note joins (`InstallFlow` and `InstallPlan.pick_notes_of`: a `note: <text>` line on stdout; `Report` `notes` with `--json`, the text without the prefix). `Pick.chosen_for` gives the text without the prefix, as for the R-C7 note. |

### 3a. How `exclude` reaches the solver (decision of the review, 2026-10-27)

The age test of the real flow is in `packages/resolve/Domain.roc` (`hidden`, rule 4: `published_at + min_age > now`, or `published_at > snapshot`). `Pick.step`'s `is_hidden` is a second copy. So there are 7 age tests, not 6. The design keeps `packages/resolve` unchanged:

| Point | Decision |
| --- | --- |
| Where | The CLI side, in `OracleRequest.solver_slot`, before the request goes to the solver. A pure function `Age.seen` (081) gives the time. |
| What | For a candidate that a pattern matches and that is not after the snapshot, the solver sees `published_at` 0. The solver's rule 4 then finds it old (`0 + min_age > now` is false for a real clock). A candidate after the snapshot keeps its time, so the snapshot still hides it. |
| Why not `exclude` in `Solver.Rules` | `Rules` is one record for the whole request (`Solver.roc`: `rules: req.rules` for every slot), and a candidate has no owner or repo. Names and patterns would enter the solver package, and its tests and `tests/fuzz/pubgrub.roc` would change. |
| Why not a per-variable `min_age` | The rules are not per variable. |
| Why 0 is safe | `Domain.with_header` already gives `published_at: 0` to a value with no known time. The solver uses `published_at` for rule 4 only. The real time stays in `slot.candidates` for the note. |
| Why not a lower time that keeps the order | The solver does not order by time (rule 5 is by version). A lower time but not 0 would give no gain and would need `now - min_age` math with an underflow case. |

## 4. Tests

The rows below are the test agent's list. The review of 2026-10-27 changed three points; the test agent did them (table "After the review", with the state of each).

Layers: L0 pure (`roc test`), L2 command cases (`tests/commands/cases`), L3 scenario (`tests/scenarios`). Written by the test agent (2026-10-27). The L0 rows run on `Oracle.step` (the step that the commands call, `PickLoop` uses `Oracle.step_probed`), as the old `PickTest` rows do.

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/PickTest.roc`, expect "R-C15 R-C12 R-C16 ..." (18 rows) | `Oracle.step` with `exclude`: no pattern; `owner/repo`; `owner/*`; upper case; the first match is in the note; same owner and another repo; another owner; a repo name that is only a prefix; a release with no name (gitlab URL); a snapshot before the release (with and without other releases); the header value with and without a pattern; a named version (R-C7 note only); the wrong kind (R-C4); the range (R-C1); `min-release-age` 0; a held slot | R-C15, R-C12, R-C16, R-C9, R-DT4, R-C4, R-C1, R-C7, R-SP1 |
| L0 | `PickTest`, expect "R-C16 R-C15 R-C7 ..." (9 rows) | `Pick.chosen_for` with `exclude`: young and excluded (`Move`): the note; first match; `Keep`: none; old: none; exactly `min_age` old: none; named and excluded: the R-C7 note; young and not excluded: none; another owner: none; a new entry: the note, `Move("")` | R-C16, R-C7, R-C15 |
| L0 | `PickTest`, expect "R-UP1 R-C15 ..." (6 rows) | `Pick.newest` and `Pick.newest_in` with `exclude`: with and without a pattern; a range; a snapshot | R-UP1, R-C15, R-DT4, R-C1 |
| L0 | `tests/unit/OutdatedTest.roc`, expect "R-C15 R-C12 R-UP1 ..." (10 rows) | `Outdated.versions` with `exclude`: `wanted` and `latest` include the young release; case; another repo and owner; the range; the snapshot; the header value | R-C15, R-C12, R-UP1, R-DT4, R-C9 |
| L0 | `tests/unit/OracleTest.roc`, 2 new expects (9 + 5 rows) | Rows for `OracleRequest.request_of` (it builds the solver slots with `solver_slot`; the test does not fix the signature of `solver_slot`): the time that the solver sees. A pattern: 0 for every matching candidate; no pattern or another owner or repo: the real time; a snapshot 4 days ago: the candidates after it keep their time, the others get 0; a candidate exactly at the snapshot gets 0; a closed slot has no candidate; 2 slots by name. Then `Oracle.step` over that request: no pattern 2.3.0; a pattern the young 2.4.0 with the note of the real age; a pattern and a snapshot 2 days ago 2.3.0; 10 days ago the header value; another owner 2.3.0 | R-C15, R-DT4, R-C9, R-C16 |
| L0 | `tests/unit/ResolvebaseTest.roc` (new, in driver `l0-6.roc`), 12 rows | `ResolveBase.settings_of`: the union (project first), a text once, an empty list removes nothing, `min-release-age` of `talon.toml` replaces `config.toml` and the list stays the union, `0d` and a list, no list, the same for `update` and `upgrade` | R-C14, R-C7, R-C11, R-LY4 |
| L2 | `resolve/rs-exclude-age` (6 runs, home with `config.toml` `["acme/parser"]`) | Run 1: `install` of a new key, 1.2.0 (1 day old) chosen, one note. Run 2 (union): project `min-release-age = "5d"` and `["zed/lib"]`, config `acme/parser`: both new keys get the young release and a note. Run 3: snapshot before the release: 1.1.0, no note. Run 4: the header holds the young release: nothing to change. Run 5: workspace, list in the root file, member `a` gets the young release. Run 6: the key in a member file: exit 19 | R-C14, R-C15, R-C16, R-C9, R-DT4, R-WS5, R-C11, R-C12, R-SE19 |
| L2 | `resolve/rs-exclude-age-none` (3 runs, no `config.toml`) | Run 1: no list, 1.1.0, no note. Run 2: list in `talon.toml` only: 1.2.0 with the note. Run 3: project `0d` and a list: 1.2.0, no note | R-C15, R-C14, R-C7, R-C11, R-SE3 |
| L2 | `upgrade/ug5-exclude` (2 runs) | Run 1: `config.toml` `["acme/pfx"]`: the platform moves to the young 0.2.2 with a note, json stays at 3.0.2 (3.1.0 is young, other repo). Run 2: project list `["acme/json"]` joined with config: json 3.1.0 and pf 0.2.2, two notes. Run 3 (`--dry-run --json`, p3): the two notes are entries of `data.notes` with no prefix, before the platform notice | R-UP1, R-C15, R-C16, R-C14, R-SE19 |
| L2 | `update/up2-exclude` (2 runs) | Run 1: `update json` takes the young 2.2.0 with the note. Run 2: `update` with no name: no note for json | R-UP1, R-C15, R-C16, R-C9 |
| L2 | `outdated/od3-exclude` (2 runs) | The table and `--json` show the young release as `wanted` of parser. No note | R-C15, R-C16, R-C14, R-J3 |
| L3 | `scenarios/update/up3-exclude-age` (2 runs, real Fx, `TALON_NOW`, fake API) | Run 1: `acme/*` in `config.toml`, `tln update parser` takes 1.2.0 (1 day old), note, exit 0. Run 2: `*/*` in `config.toml`: exit 19 with the message, no new request in `http.log` | R-C15, R-C16, R-C13, R-EV22 |

Edits of old tests (TW21): `exclude: []` next to `min_age` in the inputs of `Oracle.step` (type `OracleBase.Input`: `OracleTest` 2 places, `OraclefreeTest`, `OracledomainTest`, `OracleprobeTest`, `PickclosureTest` 2 places, `PickmovesTest`, `PickTest`), in the input of `Lags.of` (`UpgradeTest`, type `Lags.Input`: the code agent must add the field there too) and in the input of `Outdated.versions` (`OutdatedTest`). No expected value changes. No expected file of an old L2 or L3 case changes.

Deviations from the first list of this section:

| No | Deviation | Reason |
| --- | --- | --- |
| 1 | `rs-exclude-age` is split in two cases (`rs-exclude-age`, `rs-exclude-age-none`). | A `resolve` case has one home, so one `config.toml`. |
| 2 | `ug5-exclude` has the second run with the union, in place of "a package of another owner does not move" as a separate run. Run 1 already shows both. | One world, two runs. |
| 3 | The L0 rows of `step` call `Oracle.step`, not `Pick.step`. | The old `PickTest` rows do so, and the commands call `Oracle.step_probed`. `Pick.step` has no test caller. |
| 4 | (Replaced by the review, Q1.) The note R-C16 is now a `note:` line on stdout and an entry of `data.notes` (no prefix). | Review C1. |
| 5 | `Lags.Input` gets `exclude` (type of `UpgradeTest`). | `Lags` calls `Pick.newest`. |

### After the review (2026-10-27): what the test agent changes

| No | Change | Rule ids |
| --- | --- | --- |
| 1 | (done) The expected files of `rs-exclude-age`, `rs-exclude-age-none`, `ug5-exclude`, `up2-exclude` and the L3 `up3-exclude-age`: the note moves from `stderr` (bare text) to `stdout` as `note: <text>`, in the place of the R-C7 note (before `check:`), and `--json` runs have it in `data.notes` without the prefix. The InstallFlow line `fx.err!` and the omission in `InstallPlan.pick_notes_of` of the reference are not kept. | R-C16, R-C7, R-J2 |
| 2 | (done: `OracleTest`) New L0 rows for `OracleRequest.solver_slot` (and `request_of`): an excluded young candidate has time 0; a candidate that no pattern matches keeps its time; an excluded candidate after the snapshot keeps its time; one exactly at the snapshot gets 0; the header value is unchanged. A `Solver` search over a request built with `exclude: ["acme/*"]` picks the young release; without the pattern the older one; with a snapshot before the release the older one. The old hack of the reference (the solver age test in `OracleRequest` that ignores the snapshot) is not the answer. | R-C15, R-DT4, R-C9 |
| 3 | (done: the `PickTest` snapshot rows stay and pass through `Age.seen` in the reference) `Oracle.step` rows of `PickTest` that cover the snapshot with a pattern stay, and now they pass through `solver_slot` and `Age.seen` and not through a copy of the test. | R-DT4 |

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| The note (R-C16) | `note: acme/json 2.3.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*`. `<id>` is the alias of the first use or the key of a want, as in the R-C7 note (`Pick.chosen_for` today). A `note:` line on stdout, in the place of the R-C7 note. |
| `--json` | No new field: `data.notes` gets the text without the prefix, as it does for the R-C7 note. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| Tools (`tool install`, `x`, `[tools]`) | 083 |
| Compilers (the nightly of the resolve, `NightlyPlan`) | 084. A resolve that needs a young compiler uses 084. |
| `init` | 085 |
| The registry side | The age is a client rule (R-C7). The registry gives no age filter. |

## 7. Questions (TW17)

| No | Point | Why it is open | Options (not chosen) |
| --- | --- | --- | --- |
| Q1 | Stream of the note R-C16. | Answered by the review (2026-10-27): the note goes where the R-C7 note goes, a `note:` line on stdout and an entry of `data.notes` with `--json`, in the R-C7 form. R-C16 is changed. | (closed) |
| Q2 | The solver age test (`packages/resolve/Domain.roc`, rule 4, `hidden`). | Answered by the review (2026-10-27): `packages/resolve` stays unchanged. `OracleRequest.solver_slot` maps the time of each candidate with `Age.seen`. See section 3a for the reasons. | (closed) |

## 8. Disputes (from the code agent)

None. One decision, no test changed: `tests/unit/ResolvebaseTest.roc` (slice 082) builds a `ResolveBase.Request` with no field `fixed`, and `tests/commands/L2Resolve.roc` (slice 085) builds one with `fixed: []`. Both must compile. `ResolveBase.settings_of` now takes an open record (`{ command, strategy, nightly, .. }`), the only fields that it reads, so the test record with no `fixed` fits. `Request` has `fixed : List(Str)` as slice 085 says. (An optional field `fixed ?: List(Str)` was tried first: a closed record that a test function returns does not fit it.)

## 9. Revert check (TW12), planned: 9 mutations

| No | Mutation | Test that must fail |
| --- | --- | --- |
| m1 | `is_hidden` ignores `exclude` | `PickTest` `step`, L2 `rs-exclude-age` run 1 |
| m2 | `is_hidden` matches the owner only (`acme/other` is excluded by `acme/lib`) | `PickTest` `step` |
| m3 | A matching release is also exempt from the snapshot | `PickTest` `step` (snapshot row), L2 run 4 |
| m4 | `chosen_for` gives the note for a `Keep` | `PickTest` `chosen_for`, L2 run 5 |
| m5 | `chosen_for` gives the exclude note for a named version | `PickTest` `chosen_for` |
| m6 | `settings_of` takes the project list only (replace) | `ResolvebaseTest`, L2 run 3 |
| m7 | `Outdated.versions` does not pass `exclude` | `OutdatedTest`, L2 `od3-exclude` |
| m8 | `solver_slot` maps the time of a candidate after the snapshot to 0 | `OracleTest` `solver_slot`, L2 `rs-exclude-age` run 3 |
| m9 | `solver_slot` does not use `Age.seen` (the solver hides the young release) | `OracleTest`, L2 `rs-exclude-age` run 1 |

## 10. Verify results

Code agent, 2026-10-27.

| File | Change |
| --- | --- |
| `Pick.roc` | `Step`, `step`, `empty_domain`, `newest`, `newest_in` get `exclude`. `is_hidden` uses `Age.hides`. `chosen_for` gets `exclude`: the R-C7 note for a named young version, else for a change (not `Keep`) `Age.note` with the name of `Ident.of_url(url)` |
| `OracleRequest.roc` | `solver_slot(slot, i, { second, snapshot, exclude })`: the time of each candidate is `Age.seen`. `packages/resolve` is not changed |
| `OracleBase.roc`, `OracleSearch.roc`, `PickIndex.roc`, `PickLoop.roc`, `PickFlow.roc`, `Lags.roc` | `exclude` next to `min_age` |
| `ResolveBase.roc` | `Settings.exclude` = `Age.join` of the project and `config.toml` lists. `settings_of` takes an open record (section 8) |
| `Outdated.roc`, `OutdatedFlow.roc` | `exclude` in `versions` and the ctx |

The note needs no new print code: `Chosen.note` goes to the R-C7 note place (stdout `note:` line, `data.notes`).

| Check | Result |
| --- | --- |
| L0 `PickTest`, `OutdatedTest`, `ResolvebaseTest`, `UpgradeTest`, `OracleTest`, the other Oracle files, `PickclosureTest`, `PickmovesTest` | pass (72 tests in one driver with `AgeTest`, `IntentTest`) |
| L2 `rs-exclude-age`, `rs-exclude-age-none`, `ug5-exclude`, `up2-exclude`, `od3-exclude`; L3 `update/up3-exclude-age` | pass |
| Full suite | `scripts/test.sh` (all steps, as `.github/workflows/ci.yml` for Linux), run twice at the end (code of 081 to 085 together), with the default locale (`en_US.UTF-8`) and with `LC_ALL=C`: check, fmt, l0, l1, l3 and selftest pass; l2 had 232 passed and 2 failed (D1 of slice 081). After the D1 fix and Q-C1 (2026-10-27): every step passes, l2 234 passed. l0 takes 16 to 18 s (over the budget of 10 s: a WARN, not a failure). |

Revert check: 9 of 9 caught.

| No | Mutation | Result |
| --- | --- | --- |
| m1 | `is_hidden` ignores `exclude` | `PickTest` (2 fail). L2 `rs-exclude-age` does not see it: the real flow uses the solver (`Age.seen`) |
| m2 | `matches` ignores the repo | `PickTest`: 1 fails |
| m3 | a matching release skips the snapshot in `is_hidden` | `PickTest`/`OutdatedTest`: 2 fail. L2 does not see it (same reason as m1) |
| m4 | `chosen_for` gives the note for a `Keep` | `PickTest`: 2 fail. L2 `rs-exclude-age` does not see it |
| m5 | `chosen_for` gives the exclude note for a named version | `PickTest`: 2 fail |
| m6 | `settings_of` takes the project list only | `ResolvebaseTest`, L2 `rs-exclude-age` |
| m7 | `Outdated.versions` does not pass `exclude` | `OutdatedTest`, L2 `od3-exclude` |
| m8 | `solver_slot` ignores the snapshot (time 0 after it) | `OracleTest`/`PickTest`: 3 fail, L2 `rs-exclude-age` |
| m9 | `solver_slot` does not use `Age.seen` | L2 `rs-exclude-age`, `rs-exclude-age-none`, `ug5-exclude` |

## 11. Red output (test agent, 2026-10-27, round 2)

The repo `cli/` is not changed. A private reference is in `research/slice-082-revert/reference/` (a copy of `cli/`, `packages/` and the L0 and `tests/commands/*.roc` files, with the code of this slice and `Age` with `Age.seen` from slice 081). `packages/resolve` is unchanged there. `OracleRequest.solver_slot` maps the time of each candidate with `Age.seen`, as section 3a says; the old hack is gone. The note of R-C16 joins the R-C7 notes with no new print code. Keep the reference until the review is applied.

| Check | Result |
| --- | --- |
| Reference, L0 (`PickTest`, `OutdatedTest`, `ResolvebaseTest`, `UpgradeTest`, `OracleTest` and the 5 other Oracle files): `roc test` | 51 tests passed |
| Repo, the same files (a driver that imports them) | Compile errors, no run. First error: `type mismatch` at `tests/unit/OracledomainTest.roc:91:64`: the input record has `exclude`, `OracleBase.Input` has not. The same for the other Oracle files, `Pick.chosen_for`, `Pick.newest`, `Outdated.versions`, `OracleRequest.request_of`, `ResolveBase.settings_of`, and `type not determined` in `PickTest`. Drivers `l0-1`, `l0-6` and `l0-8` do not compile until the code lands. |
| `roc fmt --check tests/unit/*.roc` | valid |
| L2 with the prebuilt old `l2` (all cases) | 207 passed, 24 failed. The 24 are the new exclude cases of slices 081 to 085 (mine: `rs-exclude-age`, `rs-exclude-age-none`, `ug5-exclude`, `up2-exclude`, `od3-exclude`). Reason for mine: the old code warns `unknown key min-release-age-exclude` and hides the young release (the older release, no note, `data.notes` has no exclude note). No old case fails. |
| L3 with the old `tln` | The new cases fail. `fx/pl1-probe-pool` failed once under load (a timing case) and passed alone; it is not related. |
| L2 with the `l2` built from the reference | The 5 new cases pass. The expected files were made with it, and every changed file was read. Old cases pass (215 in the earlier run). |
| L3 with `tln` from the reference | `update/up3-exclude-age` passes |

Expected files of L2 and L3 come from the reference. A check against the design text: each note has the form of R-C16 (`<id> <version> is <n>d old (min-release-age <m>d), not hidden by min-release-age-exclude: <pattern>`), the stdout line has the prefix `note: `, the entry of `data.notes` has not, and the order in `data.notes` is: pick notes, then the platform notice.

## 12. Revert check results (reference, hand mutations, each run once)

| No | Mutation | Failing tests |
| --- | --- | --- |
| m1 | `Pick.is_hidden` ignores `exclude` | 2 L0 expects (round 1) |
| m6 | `settings_of` takes the project list only | `ResolvebaseTest` (round 1) |
| m8 | `Age.seen` ignores the snapshot (a candidate after it gets 0) | 3 L0 expects (`OracleTest`), L2 `rs-exclude-age` |
| m9 | `solver_slot` gives the real time (no `Age.seen`) | 3 L0 expects, L2 `rs-exclude-age`, `rs-exclude-age-none`, `ug5-exclude` |

Questions: none new. Q1 and Q2 are closed by the review.
