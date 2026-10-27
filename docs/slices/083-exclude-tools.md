# 083 The exclude list in the tool selection

Phase: P1. Status: done (code agent, 2026-10-27)

Slice 083 is the plan row 083 of `PLAN-P1.md` (section 2d). It needs slice 081 (`Age`, the key). Source: Decision 1 of the user (2026-10-27), `DESIGN-GAPS-2026-10-27.md` (A5, A7, A8). The design is R-C15 (rows for tools and Talon), R-C14, R-C16, R-T9, R-PT4, R-S2.
Scope: the release that `tln tool install`, `tln x`, `tln tool update` (also `tln tool update talon`) and the `[tools]` entries of `install`, `update` and `upgrade` select. Resolve is in 082, compilers in 084, `init` in 085.

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-T9, R-C15 | With no selector, `@latest`, a range or a series, a release of a repository that a pattern matches is not hidden by the age. The pattern compares `owner/repo` of the tool. An exact version is named: no age rule, and the existing R-T9 note (young: `... was released at ...`). | L0 `ToolTest` (`ToolInstall.pick`); L2 `tool/ti6-exclude` |
| R-T9 (Talon), R-S2, R-C15 | `tln tool update talon` compares `roc-talon/talon`. `roc-talon/*` and `roc-talon/talon` match. `Current` still wins over a downgrade. | L0 `TalonUpdateTest`; L2 `tool/ts10-exclude-talon` |
| R-PT4, R-C14 | A `[tools]` entry: the list is the union of `[resolution]` of the root file and `config.toml`. | L2 `ptool/pt5-exclude` |
| R-C14 | `tool install`, `x`, `tool update`: no project `talon.toml` is read for `min-release-age` today, so the list is `config.toml` only. | L2 `tool/ti6-exclude` run 3 |
| R-C16 | One `note:` line on stderr (the place of the R-T9 age note) when Talon newly selects a young release that only a pattern kept: a tool built, updated, or locked into a `url`. No note when nothing changes: the tool is installed at that version and stays (`Keep`, `up to date`), or `tool update talon` finds the installed version is the newest (`Current`). A named version: the R-T9 note only. `--quiet` hides it (R-FL4). | L0 `ToolTest` (`kept`); L2 `ti6-exclude` runs 1, 3, 4, `tu4c-exclude-keep`, `ts10c-exclude-current` |
| R-C15 (does not change) | The snapshot (only for the `[tools]` entries: `--snapshot` stays a usage error for `tool install`, `x` and `tool update`), the app-bundle rule (R-T10), the yank (R-B3) and the draft rule (R-DI3) still apply. | L0 `ToolTest`; L2 `ptool/pt5c-exclude-hidden` |
| R-T9 | The install scripts make no list call: `install.sh` is unchanged. | none (no code) |

## 2. Public signatures

| Module | Change | Rule |
| --- | --- | --- |
| `ToolInstall.pick` | Input gets `exclude : List(Str)`. Step 4 (the age drop) keeps a candidate when `!Age.hides({ now, min_age, published_at, exclude, name: Ok(facts.name) })`. Step 3 (`Exact`) is unchanged. | R-T9, R-C15 |
| `ToolInstall.Picked` | New field `kept : Try(Str, [None])`: `Age.note` for the first candidate of `order`, only for the selectors of step 4 (not `Exact`). `Err(None)` otherwise. | R-C16 |
| `TalonUpdate.pick` | Input gets `exclude : List(Str)`. The age drop uses `Age.hides` with the name `Ok(TalonUpdate.name)`. | R-T9, R-S2 |
| `TalonUpdate` result | A new pure function `TalonUpdate.kept_note : { release : Release, now : U64, min_age : U64, exclude : List(Str) } -> Try(Str, [None])`, the `Age.note` with the id `roc-talon/talon` and the version of the release. The flow prints it for `Newer`. | R-C16 |
| `ToolBuild.Facts`, `ToolFlow.Machine`, `ToolsStep.Ctx` | New field `exclude : List(Str)` next to `min_age` | R-C14 |

No stub crashes: the new fields are used by the flows; `kept_note` is a stub `crash "todo: slice 083"`.

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `ToolInstall.roc`: `pick`, `Picked` | As section 2. The doc table of `pick` (steps 3 to 5) names R-C15. |
| 2 | `TalonUpdate.roc`: `pick`, `kept_note` | As section 2 |
| 3 | `ToolFlow.roc`: `Machine`, the machine builder (line 201: `min_age: config.min_release_age ?? 172800`), `package_text!`/the pick call (line 130), `notes!` (prints `note: ${picked.kept}` on stderr after the R-T9 age note, hidden by `--quiet`; prints nothing when the flow ends with `Keep` or `up to date`) | `exclude: config.min_release_age_exclude` for a tool command outside a project. `notes!` prints `kept`. |
| 4 | `ToolBuild.Facts`, `XFlow.roc` (line 73, 95), `ToolUpdateFlow.roc` (line 210), `TalonUpdateFlow.roc` (line 91, prints `kept_note` for `Newer`), `ToolManageFlow.roc` (line 108), `RunTools.roc` (line 111) | Pass `exclude` where they pass `min_age` |
| 5 | `ToolsFlow.roc` (line 103: `Setting.pick` with the project `min_release_age` and the user value), `ToolsStep.roc` (`Ctx`, line 77, 215, 230) | `exclude: Age.join({ project: read.intent.resolution.min_release_age_exclude, user: config.min_release_age_exclude })` |

## 4. Tests

Written by the test agent (2026-10-27). Layers: L0 (`roc test`), L2 (`tests/commands/cases`), L3 (`tests/scenarios`). The slice has 5 L0 `expect`s (53 rows), 11 L2 cases (20 runs) and 1 L3 case (2 runs). The review of 2026-10-27 (C1, C3, C4 of `DESIGN-GAPS-2026-10-27.md`) added the `note: ` prefix and the cases `tu4c-exclude-keep`, `ts10c-exclude-current` and run 3 of `pt5b`.
A case with the mark "guard" passes with the code before this slice and stays green after it. It keeps a negative rule (the age still hides) from breaking. Every other case is red now.

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/ToolTest.roc`, expect 1 (17 rows) | `ToolInstall.pick` of `acme/app` (1.4.0 is 1 day old, 1.3.0 and 1.2.0 are old). No pattern: 1.3.0 first. `acme/app`, `acme/*`, `ACME/APP`, a second pattern in the list: 1.4.0 first. `acme/other`, `other/*`, `acme/ap`: 1.3.0 first. A range `^1.3` and a series `^1` with a pattern. `@latest` with and without a pattern. `Exact("1.4.0")` with and without a pattern: `young` true, the same order. No release fits the range: the usage text | R-T9, R-C15, R-C12, R-C7 |
| L0 | `ToolTest`, expect 2 (4 rows) | All releases young: no pattern and a pattern of another owner give `no release of acme/app is old enough for min-release-age`. A pattern gives the newest. `min_age` 0 with a pattern | R-T9, R-C15, R-C7 |
| L0 | `ToolTest`, expect 3 (10 rows) | `Picked.kept`: the note text for 1.4.0 (`acme/app 1.4.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*`), the pattern as written, the first pattern that matches, `@latest`, a range. `Err(None)` for: no pattern, no match, an old first candidate, `Exact` (with and without a pattern) | R-C16, R-C7, R-T9 |
| L0 | `tests/unit/TalonUpdateTest.roc`, expect 1 (14 rows) | `TalonUpdate.pick`: `roc-talon/talon`, `roc-talon/*`, `ROC-TALON/TALON` and a second pattern keep a young release. `acme/*` and `roc-talon/other` do not. Only young releases: the usage text without a pattern, the release with a pattern. `Current` wins when the installed version is the newest or above. A young release with no asset is no candidate. No release with the asset | R-T9, R-S2, R-C15, R-C12 |
| L0 | `TalonUpdateTest`, expect 2 (8 rows) | `TalonUpdate.kept_note`: the text with the id `roc-talon/talon` and the version of the release; `0d` for 3 hours; the first pattern that matches; `Err(None)` for no pattern, another owner, an old release, `min_age` 0 | R-C16, R-T9, R-S2 |
| L2 | `tool/ti6-exclude` (4 runs, entry `commands`) | `config.toml` has `acme/*`. Run 1 `tool install acme/app`: 1.4.0 is built, one `note:` line before the platform line. Run 2 `x acme/xtool`: the same (30 hours old, `1d`). Run 3 `tool install acme/named@1.4.0`: only the R-T9 age note. Run 4 `tool install beta/tool`: the young 2.1.0 is hidden, 2.0.0 is built, no note. The project dir has a `talon.toml` with `beta/*`: a tool command does not read it, so run 4 is not changed | R-T9, R-C14, R-C15, R-C16, R-C12, R-SE19 |
| L2 | `tool/ti6b-exclude-none` (2 runs, guard) | No list in `config.toml`. The project `talon.toml` has `acme/*` and is not read. Run 1: 1.3.0 is built, no note. Run 2: the named 1.4.0, only the age note | R-T9, R-C14, R-C15, R-SE19 |
| L2 | `tool/tu4-exclude` (1 run) | `tool update app` with `acme/*`: `updated app 1.3.0 to 1.4.0 (acme/app)` and the note | R-T9, R-C15, R-C16 |
| L2 | `tool/tu4c-exclude-keep` (2 runs) | The list is `acme/*` and `tools.json` has `app` 1.4.0, the young newest release. Run 1 `tool update app`: `app 1.4.0 is up to date`, no note (`Keep`). Run 2 `tool install acme/app`: `app 1.4.0 is installed`, no note. Without the pattern both runs would see 1.3.0 as the newest | R-C16, R-T9, R-C15, R-B1 |
| L2 | `tool/tu4b-exclude-none` (1 run, guard) | No list: `app 1.3.0 is up to date` | R-T9, R-C15 |
| L2 | `tool/ts10-exclude-talon` (1 run) | `tool update talon` with `roc-talon/*`: the target is v0.3.5 (1 day old), the note is the first line of stderr, then the steps of `ts1-update` run 1 | R-T9, R-S2, R-C15, R-C16 |
| L2 | `tool/ts10c-exclude-current` (1 run) | `tool update talon` with `roc-talon/*`; the installed version 0.3.5 is the young newest release: `talon 0.3.5 is up to date`, no download, no note (`Current`) | R-C16, R-T9, R-S2 |
| L2 | `tool/ts10b-exclude-other` (1 run) | The list is `acme/*`: the target is v0.3.4, no note | R-T9, R-S2, R-C12, R-C15 |
| L2 | `ptool/pt5-exclude` (2 runs) | The list is in the root `talon.toml` (`[resolution]`), `config.toml` has none. Run 1 `update --tool`: foo moves to 1.1.0 (1 day old), one note. Run 2 `install --file w2/m1/main.roc`: a member file with the key: exit 19 (R-WS5, the existing text; this run is a guard) | R-PT4, R-C14, R-C15, R-C16, R-WS5, R-SE19 |
| L2 | `ptool/pt5b-exclude-config` (3 runs) | The list is in `config.toml` (`acme/*`), the project has `other/*`: the union. Run 1 `update --tool`: foo moves to 1.1.0, the `note:` line names `acme/*`. Run 2 `install --file p3/main.roc`: an entry with a `ref` and no `url`: the same union, `locked tool foo 1.1.0`, the note again. Run 3: the same command again, the `url` is in place: `nothing to change`, no note | R-PT4, R-C14, R-C15, R-C16, R-C12 |
| L2 | `ptool/pt5c-exclude-hidden` (2 runs) | Run 1 `update --tool --snapshot 2026-10-12T00:00:00Z`: the list is `acme/*` but the snapshot is before 1.1.0: `nothing to change`. Run 2: the list is `other/*`: `nothing to change` | R-PT4, R-C15, R-C7, R-DT3 |
| L3 | `scenarios/tools/ti4-exclude-age` (2 runs) | Real Fx, real `roc unbundle`, fake API. Release 1.1.0 of `acme/foo` is 1 day old, `config.toml` has `acme/*`. Run 1: it is built, the `note:` line is on stderr only. Run 2 (`tool remove foo`, then `install --quiet`): no note | R-T9, R-C15, R-C16, R-FL4, R-SE19 |

Edits of old tests (TW21): `tests/unit/ToolTest.roc` (the `pick` call of the old expect gets `exclude: []`) and `tests/unit/TalonUpdateTest.roc` (the `pick` call gets `exclude: []`). No other old test builds `ToolInstall.pick`, `TalonUpdate.pick`, `Picked`, `ToolBuild.Facts`, `ToolFlow.Machine` or `ToolsStep.Ctx` (checked by grep over `tests/`). No expected file of an old L2 or L3 case changes. Copies of the old files are in `research/slice-083-revert/before/`.

### Deviations from the first test table

| No | First table | Written | Reason |
| --- | --- | --- | --- |
| 1 | `ti6-exclude` run 6, a `--snapshot` time before 1.4.0 | Dropped (review, 2026-10-27). Snapshot against a pattern is tested through `[tools]` only: `ptool/pt5c-exclude-hidden` run 1 | `tool install`, `x` and `tool update` do not resolve, so `--snapshot` stays a usage error there (R-EC2, `Args.roc`). Only the `[tools]` entries take `--snapshot` (R-PT4). Question Q1 (closed) |
| 2 | `ti6-exclude` runs 2 and 3 (one config) | Cases `ti6-exclude` (list in `config.toml`) and `ti6b-exclude-none` (no list) | The L2 entry `commands` has one home (one `config.toml`) for all runs |
| 3 | `ti6-exclude` run 3: a `talon.toml` with the list in the current dir | The project dir of `ti6-exclude` has `beta/*` and run 4 builds the old 2.0.0; `ti6b-exclude-none` has `acme/*` and run 1 builds 1.3.0 | A tool command reads `config.toml` only (R-C14) |
| 4 | `ti6-exclude` run 5: an exact version with and without a pattern | Run 3 of `ti6-exclude` (with a pattern) and run 2 of `ti6b-exclude-none` (without) | One home for each case |
| 5 | `tu4-exclude` (2 runs), `ts10-exclude-talon` (2 runs) | Cases `tu4-exclude` / `tu4b-exclude-none` / `tu4c-exclude-keep` and `ts10-exclude-talon` / `ts10b-exclude-other` / `ts10c-exclude-current` | One home for each case |
| 6 | `pt5-exclude` (2 runs: the root list, the config list, a member file) | Three cases `pt5-exclude`, `pt5b-exclude-config`, `pt5c-exclude-hidden` | One home for each case. `pt5b` also checks `install` of an entry with no `url` (`ToolsStep.ctx_of`, the second place of the union) |
| 7 | L0: `ToolTest` rows for "a snapshot-hidden release is not in the list" | None | The caller does that (`ToolsPlan.visible`); the L2 run `pt5c` run 1 tests it |

## 4a. How the expected files were made

The code of the slice does not exist, so no run can write the L2 and L3 expected files. The method (helpers in `research/slice-083-revert/`: `twin.sh`, `finish.sh`, `addnote.py`, `mkcase.py`):

| Step | Action |
| --- | --- |
| 1 | The case has the young release and the list. A "twin" of the case has the young release made old (2026-10-14 to 2026-09-02) and keeps the rest. The old code picks the same release in the twin as the new code picks with the pattern. |
| 2 | The twin runs on the old `l2` or `tln` binary with `UPDATE=1`. |
| 3 | `finish.sh` copies the expected files and maps the dates back (the cached release list is in `tree.diff`). It takes away the warning `unknown key min-release-age-exclude` (the new code knows the key). |
| 4 | `addnote.py` puts the note line into `expect/stderr`, as slice section 5 gives it. |
| 5 | Check with a private reference (section 10): all 11 L2 cases and the L3 case are green with it. |

## 5a. Proposals that the test agent fixed (TW24)

| Item | What is in the expected files |
| --- | --- |
| Place of the note in `tool install`, `x`, `tool update`, `[tools]` | The line of `Picked.kept` is printed by `ToolFlow.notes!` after the age note of a named version, before the `platform` line. After the review (2026-10-27) it has the prefix `note: ` (R-C16). The expected `stderr` of `ti6-exclude`, `tu4-exclude`, `ts10-exclude-talon`, `pt5-exclude`, `pt5b-exclude-config` and L3 `ti4-exclude-age` has it. |
| Place of the note in `tool update talon` | The first line of stderr of the run, before any download line and before `note: attestation not checked` (Q2, closed) |
| Place of the note for the `[tools]` entries of `install`, `update`, `upgrade` | On stderr with the prefix `note: `, from `ToolFlow.notes!` (the place where the age note of an entry that names a version goes today). Not in stdout and not in `data.notes`. Question Q4 |
| `--quiet` | The kept note is not printed with `--quiet`. (The age note of a named version is printed with `--quiet` today: the test does not change that.) |
| A `[tools]` entry that is `Keep` (cached build) | `pt5b` run 2 locks a `url` into the entry (a write): the note stays. A `Keep` with no write prints no note (Q3, closed) |

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| The note | `note: acme/app 1.4.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*`, on stderr, in the place of the R-T9 age note (`ToolFlow.notes!`), before the `platform` line (R-SE8). `--quiet` hides it. A tool command has no `data.notes`. |
| `--json` | No new field. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The resolve (packages, platform) | 082 |
| The compiler that a tool build uses | 084 |
| `install.sh`, `install.ps1` | They make no list call (R-T9). |

## 7. Questions (TW17)

| No | Question | State |
| --- | --- | --- |
| Q1 | `--snapshot` for `tool install`, `x` and `tool update` | Closed (review, C3): it stays a usage error. Tested through `[tools]` only (`pt5c`). |
| Q2 | Where does `tool update talon` print the kept note? | Closed: on stderr with the prefix `note: `, first line of the run. |
| Q3 | A selected release that is installed already (`Keep`, `up to date`, `Current`) | Closed (review, C4): no note when nothing changes. Tests: `tu4c-exclude-keep`, `ts10c-exclude-current`, `pt5b` run 3. |
| Q4 | The `[tools]` entries of `install`, `update` and `upgrade`: where is the kept note? | Closed (review 2026-10-27, rule: the same place as the existing age note of that command): stderr with the prefix `note: `, as written in `pt5-exclude` and `pt5b-exclude-config`. The text is a proposal (TW24). |

### Rows the test agent added after the review (2026-10-27): done

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L2 | `tool/ts10c-exclude-current` (new) | `tool update talon` with `roc-talon/*`; the installed version is the young newest release: `Current`, `up to date`, no note | R-C16, R-T9, R-S2 |
| L2 | `tool/tu4c-exclude-keep` (new) | `tool update app` with `acme/*`; the installed 1.4.0 is the young newest: `up to date`, no note. Also `tool install acme/app` when 1.4.0 is installed already: `Keep`, no note | R-C16, R-T9, R-B1 |
| L2 | `ptool/pt5b-exclude-config` (existing) | Keep the note in run 2 (a `url` is written). Add a run 3: `install` again with the `url` in place: nothing changes, no note | R-C16, R-PT4 |
| L2/L3 | the cases with the note | The note has the prefix `note: ` in `expect/stderr` | R-C16 |

## 8. Disputes (from the code agent)

None.

## 9. Revert check (TW12), planned: 6 mutations

| No | Mutation | Test that must fail |
| --- | --- | --- |
| m1 | `ToolInstall.pick` step 4 ignores `exclude` | `ToolTest`, L2 `ti6-exclude` run 1 |
| m2 | `ToolInstall.pick` applies the age to `Exact` | `ToolTest` (the `Exact` row) |
| m3 | `TalonUpdate.pick` compares another name than `roc-talon/talon` | `TalonUpdateTest`, L2 `ts10-exclude-talon` |
| m4 | `kept` is set for `Exact` | `ToolTest` `kept`, L2 `ti6-exclude` run 5 |
| m5 | `ToolsFlow` uses the root list only (no union with `config.toml`) | L2 `pt5-exclude` run 2 |
| m6 | `notes!` ignores `--quiet` for the new note | L3 `ti4-exclude-age` run 2 |

## 10. Red output and private reference

Red now (the code of the slice does not exist). The test agent changed no file in `cli/`. Old tests: with the old binaries (`.work/bin/l2`, `.work/bin/tln`) all old L2 and L3 cases pass; the cases that fail are the new `*exclude*` and `it1-platform-version` cases of the slices 081 to 085 (two L3 cases of the `fx` area failed once under `JOBS=4` and passed alone: timing under load, not related).

| Layer | Result now |
| --- | --- |
| L0 | `roc test tests/unit/l0-1.roc` does not compile. First errors: `TalonUpdateTest.roc:147:37 lib.TalonUpdate.kept_note does not exist`, `ToolTest.roc:133:49 type mismatch` (the field `exclude` of `ToolInstall.pick`), `ToolTest.roc:171:55`, `ToolTest.roc:220:27` (`Picked` has no `kept`). The driver also shows the errors of the files of other slices. |
| L2 | 9 of the 11 cases fail with a wrong output: the missing `note:` line, the old release (`installed app 1.3.0`, `app 1.3.0 is up to date`, a build instead of `up to date`) and the warning `unknown key min-release-age-exclude`. 2 cases are guards and pass: `ti6b-exclude-none`, `tu4b-exclude-none`. |
| L3 | `tools/ti4-exclude-age` fails: the old code hides the young 1.1.0, picks 1.0.0 (no bundle in the server) and exits 1. |

Private reference (kept in `research/slice-083-revert/reference/`, not the answer for the code agent): `cli/lib` with `Age.roc` of slice 081 and the changes of this slice (`ToolInstall.pick` and `Picked.kept`, `TalonUpdate.pick` and `kept_note`, the field `exclude` in `ToolBuild.Facts`, `ToolFlow.Machine`, `ToolsStep.Ctx`, the callers, `notes!` with `args`, the line `note: <text>` unless `--quiet`). Results with it:

| Layer | Result |
| --- | --- |
| L0 | `roc test` of the two unit modules: all 34 expects of the two files pass (the 5 new ones and 29 old ones; `research/slice-083-revert/reference/tests/unit/l0-s083.roc`) |
| L2 | An `l2` app built from the reference: the 11 cases of this slice pass |
| L3 | A `tln` built from the reference: `tools/ti4-exclude-age` passes |

Hand mutations in the reference (each one made a test fail, then the code was put back): `ToolInstall.pick` ignores `exclude` (`ToolTest` expect 1); the kept note ignores `--quiet` (L3 `ti4-exclude-age`); `ToolsFlow` takes the project list only (L2 `pt5b-exclude-config` run 1); `ToolsStep.ctx_of` takes the project list only (L2 `pt5b-exclude-config` run 2); the note is printed before the `Keep` check of `tool update` and for `Current` of `tool update talon` (L2 `tu4c-exclude-keep`, `ts10c-exclude-current`, `tu4-exclude`).

## 11. Verify results

Code agent, 2026-10-27.

| File | Change |
| --- | --- |
| `ToolInstall.roc` | `pick` gets `exclude`; step 4 drops a candidate when `Age.hides` (name `Ok(name)`); `Picked.kept` is `Age.note` of the first candidate (step 4 only) |
| `TalonUpdate.roc` | `pick` gets `exclude` (name `roc-talon/talon`); `kept_note` |
| `TalonUpdateFlow.roc` | `kept_note!`: the note on stderr for `Newer` (also with `--from-source`), first line of the run, hidden by `--quiet`; none for `Current` |
| `ToolFlow.roc` | `Machine.exclude` (`config.toml` only); `notes!` and `notes_for!` get `Args` and print `note: <kept>` after the R-T9 note unless `--quiet`. A `Keep` returns before `notes!` |
| `ToolBuild.roc`, `XFlow.roc`, `ToolUpdateFlow.roc`, `ToolManageFlow.roc`, `RunTools.roc` | `exclude` next to `min_age` |
| `ToolsFlow.roc`, `ToolsStep.roc` | `[tools]`: the union (`Age.join` in `ToolsFlow`, `settings.exclude` in `ToolsStep.ctx_of`) |

| Check | Result |
| --- | --- |
| L0 `ToolTest`, `TalonUpdateTest` | 34 tests pass |
| L2 the 11 cases of section 4; L3 `tools/ti4-exclude-age` | pass |
| Full suite | `scripts/test.sh` (all steps, as `.github/workflows/ci.yml` for Linux), run twice at the end (code of 081 to 085 together), with the default locale (`en_US.UTF-8`) and with `LC_ALL=C`: check, fmt, l0, l1, l3 and selftest pass; l2 had 232 passed and 2 failed (D1 of slice 081). After the D1 fix and Q-C1 (2026-10-27): every step passes, l2 234 passed. l0 takes 16 to 18 s (over the budget of 10 s: a WARN, not a failure). |

Revert check: 6 of 6 caught.

| No | Mutation | Result |
| --- | --- | --- |
| m1 | step 4 ignores `exclude` | `ToolTest` (3 fail), L2 `ti6-exclude` |
| m2 | the age applies to `Exact` | `ToolTest`: 2 fail |
| m3 | `TalonUpdate.pick` compares `roc-talon/other` | `TalonUpdateTest`: 1 fails. L2 `ts10-exclude-talon` does not see it (its pattern is `roc-talon/*`) |
| m4 | `kept` is set for `Exact` | `ToolTest`, L2 `ti6-exclude` |
| m5 | `ToolsFlow` takes the root list only | L2 `pt5b-exclude-config` |
| m6 | `notes!` ignores `--quiet` | L3 `ti4-exclude-age` |
