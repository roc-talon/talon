# 084 The exclude list for the compilers that Talon selects

Phase: P1. Status: done (code agent, 2026-10-27). Q-C1 is closed.

Slice 084 is the plan row 084 of `PLAN-P1.md` (section 2d). It needs slice 081 (`Age`, the key) and the settings of slice 082 (`ResolveBase.Settings.exclude`). Source: Decision 1 of the user (2026-10-27), `DESIGN-GAPS-2026-10-27.md` (A6, Q1). The design is R-C15 (last row and the paragraph "Compilers"), R-NS3, R-RU1, R-ST16, R-SO14, R-UP6, R-C16.
Scope: every place where Talon selects a compiler by itself and `min-release-age` applies (R-NS3): the resolver and `upgrade` (the free nightly), `init` (its compiler step), `tln roc update`, `@latest`, `@+N` and `@-N`, rank 4 (the `[toolchain] roc` range), probe searches (`probe --range`), the latest in the channel for `tln setup` (R-ST16) and for R-SO14.

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-C15 (compilers) | A nightly has the name `roc-lang/nightlies`. A release has the name `roc-lang/roc`. A pattern that matches the name lifts the age for that compiler. So `roc-lang/nightlies`, `roc-lang/roc` and `roc-lang/*` do. `acme/*` does not. | L0 `AgecompilerTest`, `NightliesTest` `visible`, `ToolchainTest` |
| R-NS3, R-RU1 | `tln roc update` takes the newest nightly that the switch and the age rule allow, the pattern included. `... is the newest` when it is installed. | L0 `ToolchainTest`; L2 `roc/up2-exclude` (also the `--quiet` run), L3 `compilers/ru2-exclude-age` |
| R-ST16, R-SO14 | `tln setup` and the pick of R-SO14 take the latest compiler in the channel with the pattern included. Setup writes `default-roc` and does not fail. | L0 `ToolchainTest` (`latest`); L2 `setup/st11-exclude` |
| R-UP6, R-SP8 | The free nightly of `upgrade` and the compilers of the second search (`NightlyPlan.pick`, `optional`, `movable`) use the same rule. | L0 `NightlyplanTest`; L2 `upgrade/ur8-exclude-nightly` |
| R-SL7 | The relative steps `@+N`, `@-N` and `@latest` use the domain with the pattern included. | L0 `ToolchainTest` (`range_allowed`); L2 `roc/us6-exclude-steps` |
| R-PB3, R-NS3 | The candidates of `probe --range` are the compilers that the switch and the age allow, the pattern included. | L0 `ToolchainTest` `domain` rows (`ProbeSearch.allowed` is `Toolchain.domain.auto`, no other pure function); L2 `probe/pc3-exclude` |
| R-C15 (does not change) | The snapshot time hides a matching compiler after it. The switch, the `[toolchain] roc` range and the draft and prerelease rule (R-CV1) still apply. A named compiler (R-NS4) was never hidden. | L0 `NightliesTest`, `ToolchainTest` |
| R-C16 | One `note:` line when Talon newly selects a young compiler that only a pattern kept: `<tag> is <n>d old (min-release-age <m>d), not hidden by min-release-age-exclude: <pattern>`. No version in the text. It is also printed for a range pick (rank 4), `roc use @latest`, `@+N` and `@-N`, and for the pick of R-SO14, also when the compiler is installed already, unless the selection changes nothing (the `roc:` pin or `default-roc` already equals it). | L0 `ToolchainTest` (`kept_note`); L2 `up2-exclude`, `us6-exclude-steps`, `st11-exclude`, `ur8-exclude-nightly`, and the rows of Q-T1 to Q-T3 below |
| R-C14 | A command with a project reads `[resolution]` of the project and `config.toml`. Others read `config.toml`. | L2 `ur8-exclude-nightly` (project), `up2-exclude` (config) |

## 2. Public signatures (no stubs in `cli/`: the test agent did not change `cli/`, so the tests fail to compile until the code agent adds the fields and functions)

| Module | Change | Rule |
| --- | --- | --- |
| `Age.compiler_name` | New: `Str -> Str`. `roc-lang/nightlies` when `Pin.is_nightly(id)`, else `roc-lang/roc`. | R-C15 |
| `Nightlies.visible` | Input gets `exclude : List(Str)`. A release is visible when it is in `keep`, or when it is not after the snapshot and `!Age.hides({ now, min_age, published_at, exclude, name: Ok(Age.compiler_name(r.id)) })`. | R-C7, R-C15 |
| `Toolchain.domain`, `latest`, `range_pick`, `range_allowed` | Input gets `exclude : List(Str)` and passes it to `Nightlies.visible` | R-NS3, R-C15 |
| `Toolchain.kept_note` | New: `{ id : Str, releases : List(Nightlies.Release), now : U64, min_age : U64, exclude : List(Str) } -> Try(Str, [None])`. The release with that id gives `published_at`; `Age.note` with `version: ""` and the name `Ok(Age.compiler_name(id))`. `Err(None)` when the id is not in the list. | R-C16 |
| `NightlyPlan.pick`, `optional`, `movable` | Input gets `exclude : List(Str)` | R-UP6, R-RP4 |
| `ProbeSearch` run record, `ProbeRange` input (where `min_age` is passed) | `exclude : List(Str)` | R-PB3 |
| `Base.Loaded`, `RocInstall` (`range_id!` input, the `min_age` of the flow, the setup `latest`), `NoRank` (line 115), `ResolveSelect` (line 108), `ProbeFlow` (line 165), `NightlyFlow`, `RocManage` | `exclude` next to `min_age`. A command with a project uses `ResolveBase.Settings.exclude`. A command with no project uses `config.min_release_age_exclude`. | R-C14 |

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Age.roc` | `compiler_name` |
| 2 | `Nightlies.roc`: `visible` | As section 2. The doc comment names R-C15. The list order stays. |
| 3 | `Toolchain.roc`: `domain`, `latest`, `range_pick`, `range_allowed`, `kept_note` | As section 2 |
| 4 | `NightlyPlan.roc`, `NightlyFlow.roc` (lines 65, 98, 126) | `exclude: ctx.settings.exclude` |
| 5 | `RocInstall.roc` (lines 72, 83, 129, 155: the `min_age` of `roc update`, `@latest`, `range_id!`, setup), `RocManage.roc`, `NoRank.roc` (line 115), `Base.roc` (`Loaded.min_age`, line 282, and `listed!`), `ResolveSelect.roc`, `ProbeFlow.roc`, `ProbeSearch.roc`, `ProbeRange.roc` | Pass `exclude` where they pass `min_age`. Config-only commands read `config.min_release_age_exclude`. |
| 6 | The notes | `Toolchain.kept_note` gives the text without the prefix. The command that newly selects the compiler prints `note: <text>` once, before the download line (R-NI6): `RocInstall.flow!` (`roc update`), `RocUse`/`ManageUse` (`roc use @latest`, `@+N`, `@-N`, also when the compiler is installed; not when the pin already equals it), `ResolveSelect.choose!` and `Base.listed!` (rank 4, a range pick), `NoRank.pick`/`HeldRoc` (R-SO14), `NightlyFlow.pick!` (the free nightly), `SetupFlow` (the default). `roc` commands and setup print it on stderr; the resolve commands add it to the notes of the report (stdout, `data.notes`). `--quiet` hides it (R-FL4). A named compiler (R-NS4) and a compiler that ranks 1 to 7 select without a new choice print none. |

## 4. Tests

Layers: L0 pure (`roc test`), L2 command cases (`tests/commands/cases`), L3 scenarios (`tests/scenarios`). Written by the test agent (2026-10-27). Counts: 7 new L0 `expect`s (about 90 rows), 8 new L2 cases (29 runs), 1 new L3 case (5 runs).

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/AgecompilerTest.roc` (new; driver `l0-2.roc`) 2 `expect`s | `Age.compiler_name`: both nightly tag forms give `roc-lang/nightlies`, `0.1.0` and `0.12.3` give `roc-lang/roc`. 10 rows with `Age.matches`: `roc-lang/nightlies`, `roc-lang/*` (Q1) and `ROC-LANG/NIGHTLIES` match a nightly; `roc-lang/roc` and `acme/*` do not; no prefix match; the mirror rows for a release | R-C15, R-C12 |
| L0 | `NightliesTest` `visible` (1 new `expect`, 20 rows) | 3 nightlies (3 days, 1.5 days, 12 hours) and a release: no pattern, the 3 pattern forms, other case, `roc-lang/roc` and `acme/*` and a prefix and a bad pattern (not a match), the release rows, the order of the list, empty list, `min_age` 0, the snapshot before and at the time of a nightly (a pattern does not show a nightly after the snapshot), `keep` | R-C15, R-C7, R-DT4, R-C9 |
| L0 | `ToolchainTest` `domain`, `latest` (1 new `expect`, 17 rows) | `auto` and `latest` with and without the pattern, the switch off, `min_age` 0, empty list, all young. `named` does not change. `auto` is the `allowed` list of `ProbeSearch` | R-NS3, R-C15, R-C7, R-SO14, R-ST16, R-PB3, R-RU1 |
| L0 | `ToolchainTest` `range_pick`, `range_allowed` (1 new `expect`, 16 rows) | the young nightly with the pattern; a range that only the young one meets; `Exactly` still cuts; the switch off; the snapshot; a semver range with a young release (`roc-lang/roc`) | R-NS3, R-NS7, R-C15, R-DT4, R-SO13, R-SL7 |
| L0 | `ToolchainTest` `kept_note` (1 new `expect`, 14 rows) | the text with no version, `1d` and `0d`, the first matching pattern as written, a release, `min-release-age 5d`; `Err(None)` for the wrong name, no pattern, old, exactly the age, `min_age` 0, unknown id, empty list | R-C16 |
| L0 | `NightlyplanTest` `pick`, `optional`, `movable` (1 new `expect`, 22 rows) | the young nightly n6 is N with the pattern; the optional compilers below it; a held move may take an installed n6; `roc-lang/roc` and `acme/*` change nothing; the switch, the range and the snapshot still cut | R-UP6, R-RP4, R-C15, R-C7, R-C9, R-NS3, R-NS7, R-DT4 |
| L2 | `roc/up2-exclude` (new, 6 runs) | `roc update`, TALON_NOW 2026-10-19T15:00Z (the nightly of 10-17 is exactly 2 days old, 10-18 is 1 day old). Run 1: no list, 10-17. Run 2: `roc-lang/nightlies`, a person, 10-18 and the note. Run 3: `roc-lang/roc`, 10-17. Run 4: `roc-lang/*`, 10-18 installed already: `is the newest`, no note. Run 5: CI, the note before the line `downloading`. Run 6: `--quiet`: no note, the line `downloading` stays | R-RU1, R-NS3, R-C15, R-C16, R-C12, R-FL4 |
| L2 | `roc/us6-exclude-steps` (new, 6 runs; the slice had 2) | `roc use @latest` and `@+1`. Run 1: no list, 10-17. Run 2: no list, the pin is 10-17, `@+1`: exit 2. Run 3: `roc-lang/nightlies`, `@latest` is the young nightly, which is not installed: the note, a prompt, a download. Run 4: `roc-lang/*`, `@+1` from 10-17 is the young nightly. Run 5 (review C4): the young nightly is installed, the pin is 10-16: the note, no download, the pin is written. Run 6: the same again: `already`, nothing written, no note | R-SL7, R-NS3, R-C15, R-C16 |
| L2 | `setup/st11-exclude` (new, 4 runs) | `setup`, nothing installed, no default. Run 1: `roc-lang/nightlies`, the 36 hours old nightly is `default-roc`, with the note. Run 2: no list. Run 3: `roc-lang/roc` and `acme/*`: the older one. Run 4: `roc-lang/*` and `nightly = false`: no default. No download | R-ST16, R-SO14, R-C15, R-C16, R-NS3 |
| L2 | `upgrade/ur8-exclude-nightly` (new, 5 runs) | `upgrade roc`, the world of `ur1-roc`. Run 1: the list in the project `talon.toml`, a person: N is the young nightly, prompt, note, the pin moves. Run 2: the list in `config.toml` only (`roc-lang/*`). Run 3: `acme/*` only: N is 10-12. Run 4: the project has `roc-lang/roc` and `acme/*`: no match. Run 5: `--json`: `data.notes` holds the note without the prefix (the first matching pattern is the one of the project) | R-UP6, R-NI12, R-C14, R-C15, R-C16, R-C12 |
| L2 | `probe/pc3-exclude` (new, 3 runs) | `probe parser2 --range` with `min-release-age = "7d"`. Run 1: no list, n8 to n10 hidden. Run 2: `roc-lang/roc` and `acme/*`, the same. Run 3 (last, the facts of run 3 stay in the db): `roc-lang/nightlies`, n8 to n10 are asked, both ends real, exit 0 | R-PB3, R-NS3, R-C7, R-C14, R-C15 |
| L2 | `norank/nr2-exclude` (new, 8 runs; Q-T3) | `NoRank.pick` (R-SO14): nothing installed, no default, TALON_NOW 2026-10-20T15:00Z. Run 1: pattern in the project, no fact: the young nightly 10-19 and the note on stderr. Run 2: no list: 10-18, no note. Run 3: the list in `config.toml` only: the young nightly and the note. Run 4: `roc-lang/roc` and `acme/*`: 10-18. Run 5: facts exist: the older compiler of the facts (N2), no note. The harness word `config:<file>` (new, in `L2NoRank.roc`) writes the file as `config.toml` of the run | R-SO14, R-C14, R-C15, R-C16, R-C12, R-NS3 Q-C1 (runs 6 to 8): run 6 the list in the project only (harness word `exclude:`), no config.toml: the young nightly, the note, the default. Run 7: the union (project `acme/*`, config.toml `roc-lang/nightlies`): the young nightly with the note. Run 8: project `acme/*` only: the older nightly, no note. |
| L2 | `consent/dl4-rank4-exclude` (new, 5 runs; Q-T1, Q-T5) | Rank 4: the project has `[toolchain] roc = ">=nightly-2026-10-13-0000000"`, no pin, TALON_NOW 2026-10-19T15:00Z, CI with `--allow-downloads`. Run 1: no list: 10-17, no note. Run 2: the list in the project: the young nightly 10-18, the `note:` line on stdout, the pin written. Run 3: the same again: `nothing to change`, no note. Run 4: the list in `config.toml` only: the same pick and note. Run 5: `--json`: `data.notes` has the note without the prefix (Q-T5) | R-SO13, R-C14, R-C15, R-C16, R-C12, R-NS3, R-NS7 |
| L3 | `scenarios/compilers/ru2-exclude-age` (new, 5 runs; the slice had 2) | `tln roc update`, real Fx, real curl and tar, fake server (the young nightly is 36 hours old). Run 1: no list. Run 2: `roc-lang/nightlies`: installed, the note before the download line. Run 3: `roc-lang/roc`. Run 4: `Roc-Lang/*` with `--json`. Run 5: `--quiet` | R-RU1, R-C15, R-C16, R-C12, R-FL4 |

Deviations from the first plan of this table:

| No | Plan | Written | Reason |
| --- | --- | --- | --- |
| d1 | `AgeTest` `compiler_name` | `AgecompilerTest` (new file) | `AgeTest` is a file of slice 081. A file for each slice keeps the slices separable. |
| d2 | `ProbesearchTest` row | `ToolchainTest` `domain` rows, and L2 `pc3-exclude` | `ProbeSearch.allowed` is `Toolchain.domain(...).auto`. No pure function of `ProbeSearch` exists. |
| d3 | `us6-exclude-steps` 2 runs, `ru2-exclude-age` 2 runs | 4 and 5 runs | More rules (Q1, `Exactly`, `--quiet`). A run needs its own `HOME` for a config: the L2 entry `commands` takes `env:HOME=` for each run. |
| d4 | `pc3-exclude` 1 run | 3 runs | A control run with no list and a run with patterns that do not match. |
| d5 | `up2-exclude` 3 runs | 6 runs | The installed-already row (no note), the note before the download line in CI, and `--quiet`. |
| d6 | `us6-exclude-steps` 4 runs, `ur8-exclude-nightly` 4 runs | 6 and 5 runs | Review C4 (2026-10-27): the installed compiler with a pin write, the repeat without a note, and `--json` `data.notes`. |
| d7 | no case for the nr and rank 4 notes | `norank/nr2-exclude`, `consent/dl4-rank4-exclude` | Q-T1 and Q-T3 are closed (review C4). |

Edits of old tests (TW21): the inputs of `Nightlies.visible`, the `Toolchain` functions, `NightlyPlan` and `ProbeSearch` get `exclude: []`. This is mechanical. No expected file of an old L2 or L3 case changes. The L2 harness `tests/commands/L2NoRank.roc` gets one word, `config:<file>`, which writes `<w>/<file>` as the `config.toml` of the run (backup in `research/slice-084-revert/before/tests/commands/`; the signature of `NoRank.ensure!` is unchanged).

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| The note | `note: nightly-2026-10-13-91fa0c2 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: roc-lang/nightlies`. The `roc` commands, `tln setup` and the pick of `NoRank` print it on stderr with the prefix `note: ` before the download line, as the rank 6 note (080) is printed. The commands of the resolve (`upgrade`, `install`, the held nightly of `NightlyFlow`) add it to the notes of the report: a `note:` line on stdout, and `data.notes` with `--json` without the prefix (as 082). |
| `tln roc update` when the young nightly is installed already | `nightly-2026-10-13-91fa0c2 is the newest` (R-RU1, unchanged), no note |
| `--json` | No new field. The resolve commands put the note in `data.notes` (without the prefix). The `roc` commands, `setup` and `NoRank` have no `data.notes` for this note: it stays on stderr. The rank 4 pick of a resolve command (`update` with a project range) prints a `note:` line on stdout in the reference. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| Local builds (`git-*`, `link-*`, `copy-*`) | Never hidden by the age (R-NS6) |
| A source of compiler releases (`roc-lang/roc`) | Talon has none yet (R-NS2). `compiler_name` and its test row are ready for it. |
| Q1 of the record (wildcards never match compilers) | The human decides at the review. If yes: one more test row, and `Age.matches` gets no change; `Nightlies.visible` uses an exact-name compare. |

## 7. Questions (TW17)

Q-T1 to Q-T4 are closed. New points for the human review (no choice made by the test agent):

| No | Point | What the tests assume |
| --- | --- | --- |
| Q-T1 | The note of a compiler that rank 4 (`range_id!`, the `[toolchain] roc` range) or `Base.listed!` picks | **Closed (review, 2026-10-27):** the note is printed when the pick is new (R-C16). Section 3 item 6 lists these places too (`ResolveSelect.choose!`, `Base.listed!`). The test agent adds a row: a project `talon.toml` with `[toolchain] roc = ">=nightly-..."` or a series range, no pin, no compiler installed in the range, a young nightly kept by the pattern: the note, once. A second run with the pin written: no note. |
| Q-T2 | `tln roc use @latest` or `@+N` when the young compiler is installed already | **Closed (review, 2026-10-27):** `roc use` writes a pin, so the selection is new. The note is printed, also when the compiler is installed already. No note when the pin already equals it (nothing changes). `tln roc update` with the young nightly installed already prints `... is the newest` and no note (it changes nothing). The test agent adds rows to `us6-exclude-steps`: `roc use @latest` with the young nightly installed: the note, the pin written; the same again: no note. |
| Q-T3 | A note of `NoRank.pick` (R-SO14, a project command that downloads the latest compiler) | **Closed (review, 2026-10-27):** the note is printed (R-C16). The test agent adds an L2 case in `norank/` (new, for example `nr2-exclude`): nothing installed, no default, a project command (`verify` or `install` with a check), a young nightly kept by the pattern: the pick is the young nightly, one `note:` line, the download and the default as in `nr1-order`. Without the pattern: the older nightly, no note. |
| Q-T4 | `Age.hides` with `min_age` 0 and `published_at` after `now` | **Settled:** `Age.hides` is False for `min_age` 0, also for a future `published_at` (slice 081 row). Old tests (`ToolchainTest` `range_pick`) have `now` = 1_000_000 and 2026 dates with `min_age` 0, and expect the release to be visible (R-C7: `"0d"` hides nothing). So `Age.hides` must give False for `min_age` 0, also for a future `published_at`. Slice 081 has the same row. |

| Q-T5 | Where the rank 4 note goes, and the list of `norank/nr2-exclude` | **Answered (review, 2026-10-27):** for a resolve command with a rank 4 pick, the note is a `note:` line on stdout and an entry of `data.notes` (no prefix) with `--json`. `consent/dl4-rank4-exclude` run 5 shows it. The `Proxy` rank 4 pick (the `roc` launcher) prints no note and has no test. `norank/nr2-exclude` covers a project list through the R-SO14 pick as before: the harness keeps the signature of `NoRank.ensure!`, so its list is in `config.toml` (`config:<file>`) or in the project. In the reference the note travels in `ResolveBase.Selected.note`; `InstallFlow` prints it and adds it to the notes after the note of the pin. Other resolve commands that call `ranged!` (for example `verify`, `remove`) print no note in the reference: they have no test. |

## 8. Disputes (from the code agent)

None. Two decisions, and one question:

| No | Point | What the code does |
| --- | --- | --- |
| C1 | `ResolveBase.Selected` gets no `note` field (the private reference has one) | `tests/unit/ResolvebaseTest.roc` builds a `Loaded` with `selected: { id, from }`, so a new field does not compile. The note of a rank 4 pick goes out of `ResolveSelect.select_noted!` (new; `select!` keeps its signature) as `range_note` of `ResolveLoad.prepared!`, then `InstallFlow.resolve!` adds it after the note of the pin (stdout and `data.notes`). |
| C2 | The note of the free nightly of `upgrade` | `NightlyFlow` gives it in `Plan.note` when N (the newest compiler that the age and the pattern allow) is not H, before the search. If the search then keeps an older compiler, the note names N. The tests (`ur8-exclude-nightly`) want the note before `check:`. |
| Q-C1 (TW17) | R-C14 for `NoRank.pick` (R-SO14) in a project command | `NoRank.offer!` reads `config.toml` only: `NoRank.ensure!` (signature fixed by the L2 harness) has no field for the project list. A pattern in `[resolution]` of the project does not reach R-SO14. The test `nr2-exclude` puts its list in `config.toml`. Not decided by the code agent. | **Answered (R-C14), tests added by the test agent (2026-10-27):** the project list joins the user list. The harness `tests/commands/L2NoRank.roc` (and `tests/commands/main.roc`, 2 literals) now builds `NoRank.Run` with a new field `exclude : List(Str)` (the `[resolution]` list of the project, empty outside a project). **The code must:** (1) `NoRank.Run : { scope, exclude : List(Str), downloads }`; (2) `NoRank.offer!` input gets `exclude : List(Str)` (`ensure!` passes `facts.run.exclude`; `pick_id!` and its callers pass the list they have) and computes `exclude = Age.join({ project: run.exclude, user: config.min_release_age_exclude })`; (3) every place that builds a `NoRank.Run` or `Download(...)` fallback (`ResolveBase.no_rank`, `Init`, `PathFlow`, `Fetch` callers) sets `exclude` from `intent.resolution.min_release_age_exclude` of the project (`[]` with no project). Until then the L2 app does not compile (the field is unknown). A private reference of this change is in `research/slice-084-revert/reference-qc1/` (minimal: `exclude: []` at the callers).

## 9. Revert check (TW12), planned: 9 mutations (m7 to m9 ran once in the private reference: each made the named cases fail)

| No | Mutation | Test that must fail |
| --- | --- | --- |
| m1 | `Nightlies.visible` ignores `exclude` | `NightliesTest`, L2 `up2-exclude` run 2 |
| m2 | `compiler_name` always gives `roc-lang/roc` | `AgeTest`, `NightliesTest` |
| m3 | A matching nightly also skips the snapshot | `NightliesTest` |
| m4 | `latest` (setup, R-SO14) is not passed `exclude` | `ToolchainTest`, L2 `st11-exclude` |
| m5 | `NightlyPlan.pick` is not passed `exclude` | `NightlyplanTest`, L2 `ur8-exclude-nightly` |
| m6 | The note is printed after the download line | L2 `up2-exclude` run 2 |
| m7 | `--quiet` does not hide the note | L2 `up2-exclude` run 6 |
| m8 | The note has no prefix `note: ` | L2 `up2-exclude`, `us6-exclude-steps` |
| m9 | `roc use` prints the note when the pin already equals | L2 `us6-exclude-steps` run 6 |

## 10. Verify results

Code agent, 2026-10-27.

| File | Change |
| --- | --- |
| `Age.roc` | `compiler_name` |
| `Nightlies.roc` | `visible` gets `exclude`; the age test is `Age.hides` with `Age.compiler_name`; the snapshot and `keep` stay |
| `Toolchain.roc` | `domain`, `latest`, `range_pick`, `range_allowed` get `exclude`; `kept_note` |
| `NightlyPlan.roc`, `NightlyFlow.roc` | `exclude` in `pick`, `optional`, `movable`; `Plan.note` (decision C2) |
| `RocInstall.roc` | `offer_noted!` (`offer!` keeps its signature): the note for `@latest` and the steps; `range_id!` gives `{ id, note }`; `latest!` gives `{ id, note }`; `print_note!` (`note: ` prefix, `--quiet`); `roc install` prints the note before the download |
| `RocManage.roc` | `roc update`: the note before the download line; none when installed |
| `RocUse.roc` | `named!` gives the note; printed after the no-change return (also when the compiler is installed) |
| `SetupFlow.roc` | the note of the latest compiler before `first_default!` |
| `NoRank.roc` | `Run.exclude` (the project list, `[]` outside a project); `offer!` and `pick_id!` take `exclude`, `offer!` uses `Age.join` of it and `config.toml` (Q-C1); the note before the download |
| `ResolveSelect.roc`, `ResolveLoad.roc`, `InstallFlow.roc` | the rank 4 note (decision C1) |
| `Base.roc`, `ProbeFlow.roc`, `ProbeSearch.roc`, `Proxy.roc`, `cli/flowprobe.roc` | `exclude` next to `min_age` (the proxy rank 4 pick prints no note) |

| Check | Result |
| --- | --- |
| L0 `AgecompilerTest`, `NightliesTest`, `NightlyplanTest`, `ToolchainTest`, `NoRankTest`, `ProxyTest` | 56 tests pass |
| L2 the 8 cases of section 4; L3 `compilers/ru2-exclude-age` | pass |
| Full suite | `scripts/test.sh` (all steps, as `.github/workflows/ci.yml` for Linux), run twice at the end (code of 081 to 085 together), with the default locale (`en_US.UTF-8`) and with `LC_ALL=C`: check, fmt, l0, l1, l3 and selftest pass; l2 had 232 passed and 2 failed (D1 of slice 081). After the D1 fix and Q-C1 (2026-10-27): every step passes, l2 234 passed. l0 takes 16 to 18 s (over the budget of 10 s: a WARN, not a failure). |

Revert check: 9 of 9 caught.

| No | Mutation | Result |
| --- | --- | --- |
| m1 | `Nightlies.visible` ignores `exclude` | `NightliesTest`, L2 `roc/up2-exclude` |
| m2 | `compiler_name` always `roc-lang/roc` | `AgecompilerTest`, `NightliesTest`: 3 fail |
| m3 | a matching nightly skips the snapshot | `NightliesTest` |
| m4 | `latest` gets no `exclude` | `ToolchainTest`, L2 `st11-exclude` |
| m5 | `NightlyPlan.pick` gets no `exclude` | `NightlyplanTest`, L2 `ur8-exclude-nightly` |
| m6 | `roc update` prints the note after the download line | L2 `roc/up2-exclude` |
| m7 | `--quiet` does not hide the note | L2 `roc/up2-exclude` |
| m8 | the note has no `note: ` prefix | L2 `roc/up2-exclude`, `us6-exclude-steps` |
| m9 | `roc use` prints the note when the pin already equals | L2 `us6-exclude-steps` |

### Q-C1 code (code agent, 2026-10-27)

| File | Change |
| --- | --- |
| `NoRank.roc` | `Run : { scope, exclude, downloads }`; `offer!` and `pick_id!` get `exclude`; `offer!`: `Age.join({ project: run.exclude, user: config.min_release_age_exclude })`; `ensure!` passes `facts.run.exclude` |
| `ResolveBase.roc` | `no_rank`: `exclude` is `intent.resolution.min_release_age_exclude` |
| `HeldRoc.roc` | `pick_id!` gets `run.exclude` |
| `Base.roc`, `Proxy.roc` | `read_toml` also gives the `[resolution]` list of the `talon.toml` that it reads already (no new `Fx` call). `Loaded.exclude` is the union with `config.toml`. The proxy passes it to `range_id!` (rank 4) and to `pick_id!` (R-SO14) |
| `Init.roc`, `ToolFlow.roc` | `exclude: []` (`Outside`) |
| `PathFlow.roc` | `exclude: []`: `tln path` reads no `talon.toml`, and a new read would change its calls. So the project list does not reach R-SO14 in `tln path`. No test covers it. |

| Check | Result |
| --- | --- |
| `scripts/test.sh`, default locale and `LC_ALL=C` | rc=0 both: check, fmt, l0, l1, l2 (234 passed), l3 (88 passed, 3 skipped), selftest. l0 takes 11 s (WARN, budget 10 s) |
| Mutation `offer!` ignores the project list (`project: []` in the join) | L2 `norank/nr2-exclude` fails. Code put back, `diff -r`: the same |

## 11. Red output (test agent, 2026-10-27)

The repo has no code of this slice and no stub, so the L0 files fail to compile:

| Check | Result |
| --- | --- |
| `roc test` of a driver with `AgecompilerTest`, `NightliesTest`, `NightlyplanTest`, `ToolchainTest` | compile errors: `The package import lib.Age does not name a public module`, `Age.compiler_name does not exist`, `Age.matches does not exist`, and `type mismatch` at each call of `Nightlies.visible`, `Toolchain.domain`, `Toolchain.latest`, `Toolchain.range_pick` and `NightlyPlan.pick` (the record has the field `exclude`; the function does not take it). `Toolchain.kept_note` is missing too. |
| L2 (old `l2` binary) | `roc/up2-exclude`, `roc/us6-exclude-steps`, `setup/st11-exclude`, `upgrade/ur8-exclude-nightly`, `probe/pc3-exclude` fail: a warning `unknown key min-release-age-exclude`, and the older compiler is chosen. The 8 new cases in `roc/`, `setup/`, `probe/`, `upgrade/`, `norank/` and `consent/` (`dl4-rank4-exclude`, `nr2-exclude` included) fail with the older compiler chosen (the age rule hides the young nightly). `upgrade/ug5-exclude` is of slice 082. The 60 other cases of these six folders pass. |
| L3 (old `tln`) | `compilers/ru2-exclude-age` fails (same reason). The 21 old cases of `compilers/` pass. |

The old tests of `NightliesTest`, `ToolchainTest` and `NightlyplanTest` got `exclude: []` in their inputs (mechanical, no expected value changed). They compile again with the code of the slice only.

## 12. Private reference (test agent)

`research/slice-084-revert/reference/` is a copy of `cli/` with the minimal code of slices 081 and 084 (`Age.compiler_name`, `exclude` in `Nightlies.visible`, `Toolchain`, `NightlyPlan`, `ProbeSearch`, `Base`, `RocInstall` (the note is a field `note` of the `Present` and `Download` offers with the prefix `note: `, printed on stderr by `roc update`, `roc install`, `roc use` (after the no-change return) and `setup` unless `--quiet`; `range_id!` gives `{ id, note }`; `ResolveSelect` prints it on stdout; `NightlyFlow` puts it in `Plan.note`), `NoRank`, `NightlyFlow`, `ResolveBase.Settings.exclude`). It is a guide, not the answer. With it: the 4 L0 files pass (44 tests in the driver), the 8 L2 cases and the L3 case pass (`upgrade/ug5-exclude` fails there: it is of slice 082), and the expected files of the L2 and L3 cases come from it (every file was read). Five hand mutations in the reference: `Nightlies.visible` ignores `exclude` and `compiler_name` always `roc-lang/roc` made 4 L0 tests fail each. `--quiet` ignored (m7) made `roc/up2-exclude` fail. A note without the prefix (m8) made `roc/up2-exclude` and `roc/us6-exclude-steps` fail. A note when the pin already equals (m9) made `roc/us6-exclude-steps` fail. Keep the directory until the manager's review is applied (manager rule, 2026-10-25). The pre-slice copies of the changed test files are in `research/slice-084-revert/before/`.
