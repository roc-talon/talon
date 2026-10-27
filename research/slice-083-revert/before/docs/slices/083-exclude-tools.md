# 083 The exclude list in the tool selection

Phase: P1. Status: scope

Slice 083 is the plan row 083 of `PLAN-P1.md` (section 2d). It needs slice 081 (`Age`, the key). Source: Decision 1 of the user (2026-10-27), `DESIGN-GAPS-2026-10-27.md` (A5, A7, A8). The design is R-C15 (rows for tools and Talon), R-C14, R-C16, R-T9, R-PT4, R-S2.
Scope: the release that `tln tool install`, `tln x`, `tln tool update` (also `tln tool update talon`) and the `[tools]` entries of `install`, `update` and `upgrade` select. Resolve is in 082, compilers in 084, `init` in 085.

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-T9, R-C15 | With no selector, `@latest`, a range or a series, a release of a repository that a pattern matches is not hidden by the age. The pattern compares `owner/repo` of the tool. An exact version is named: no age rule, and the existing R-T9 note (young: `... was released at ...`). | L0 `ToolTest` (`ToolInstall.pick`); L2 `tool/ti6-exclude` |
| R-T9 (Talon), R-S2, R-C15 | `tln tool update talon` compares `roc-talon/talon`. `roc-talon/*` and `roc-talon/talon` match. `Current` still wins over a downgrade. | L0 `TalonUpdateTest`; L2 `tool/ts10-exclude-talon` |
| R-PT4, R-C14 | A `[tools]` entry: the list is the union of `[resolution]` of the root file and `config.toml`. | L2 `ptool/pt5-exclude` |
| R-C14 | `tool install`, `x`, `tool update`: no project `talon.toml` is read for `min-release-age` today, so the list is `config.toml` only. | L2 `tool/ti6-exclude` run 3 |
| R-C16 | One note on stderr for a chosen young release that only a pattern kept. A named version: the R-T9 note only. `--quiet` hides it (R-FL4). | L0 `ToolTest` (`kept`); L2 `ti6-exclude` runs 1, 4, 5 |
| R-C15 (does not change) | The snapshot, the app-bundle rule (R-T10), the yank (R-B3) and the draft rule (R-DI3) still apply. | L0 `ToolTest`; L2 `ti6-exclude` run 6 |
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
| 3 | `ToolFlow.roc`: `Machine`, the machine builder (line 201: `min_age: config.min_release_age ?? 172800`), `package_text!`/the pick call (line 130), `notes!` (prints `picked.kept` on stderr after the R-T9 age note, hidden by `--quiet`) | `exclude: config.min_release_age_exclude` for a tool command outside a project. `notes!` prints `kept`. |
| 4 | `ToolBuild.Facts`, `XFlow.roc` (line 73, 95), `ToolUpdateFlow.roc` (line 210), `TalonUpdateFlow.roc` (line 91, prints `kept_note` for `Newer`), `ToolManageFlow.roc` (line 108), `RunTools.roc` (line 111) | Pass `exclude` where they pass `min_age` |
| 5 | `ToolsFlow.roc` (line 103: `Setting.pick` with the project `min_release_age` and the user value), `ToolsStep.roc` (`Ctx`, line 77, 215, 230) | `exclude: Age.join({ project: read.intent.resolution.min_release_age_exclude, user: config.min_release_age_exclude })` |

## 4. Tests

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `ToolTest` `pick` rows (new) | List of 3 releases of `acme/app`: 1.4.0 (1 day old), 1.3.0, 1.2.0 (old). No pattern: 1.3.0 first. `["acme/app"]`, `["acme/*"]`, `["ACME/APP"]`: 1.4.0 first. `["acme/other"]`, `["other/*"]`: 1.3.0. A range `^1.3` and a series `1` with a pattern: the newest in the range. `@latest` with a pattern: 1.4.0. `Exact("1.4.0")` with and without a pattern: `young` true, the same order, `kept` `Err(None)` | R-T9, R-C15 |
| L0 | `ToolTest` `pick` rows | All releases young and no pattern: `no release of acme/app is old enough for min-release-age`. All young and a pattern: the newest. A snapshot-hidden release (the list that the caller passes) is not in the list: the caller test is L2 `ti6-exclude` run 6 | R-T9, R-C15 |
| L0 | `ToolTest` `kept` rows | `Picked.kept` has the note text for 1.4.0 (`acme/app 1.4.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*`). `Err(None)` when the first candidate is old, or no pattern matches, or `Exact` | R-C16 |
| L0 | `TalonUpdateTest` `pick` rows | `roc-talon/talon`, `roc-talon/*` and `ROC-TALON/TALON` keep a young newest release; `acme/*` does not; `Current` (the installed version is the newest) is unchanged; the asset rule is unchanged. `kept_note` rows | R-T9, R-S2, R-C16 |
| L2 | `tool/ti6-exclude` (new, 6 runs) | Run 1: `tool install acme/app`, `config.toml` has `acme/*`, the newest release is 1 day old: it builds 1.4.0, the note is on stderr before the build lines. Run 2: no pattern: it builds 1.3.0, no note. Run 3: a `talon.toml` with the list in the current dir does not change a tool command (config only). Run 4: `x acme/app` with the pattern: 1.4.0 with the note. Run 5: `tool install acme/app@1.4.0` with and without a pattern: only the R-T9 note, no exclude note. Run 6: a `--snapshot` time before 1.4.0: 1.3.0 | R-T9, R-C14, R-C15, R-C16 |
| L2 | `tool/tu4-exclude` (new, 2 runs) | `tool update app`: the installed 1.3.0, a young 1.4.0, a pattern: it updates, with the note. Without a pattern: `up to date` | R-T9, R-C15, R-C16 |
| L2 | `tool/ts10-exclude-talon` (new, 2 runs) | `tool update talon` with `roc-talon/*` in `config.toml`: the young release is the target, with the note. With `acme/*`: not | R-T9, R-S2, R-C15 |
| L2 | `ptool/pt5-exclude` (new, 2 runs) | `[tools]` with `ref = "acme/app@^1"` and a `url`: `tln update` moves the url to the young release when the root `[resolution]` has the pattern; the same when only `config.toml` has it; a pattern in a member file: exit 19 (R-WS5) | R-PT4, R-C14, R-C15 |
| L3 | `scenarios/tools/ti4-exclude-age` (new, 2 runs, real Fx, `TALON_NOW` fixed, fake API) | Run 1: `tln tool install acme/app` with the pattern: the young release is built, the note is on stderr. Run 2: `--quiet`: no note | R-T9, R-C16, R-FL4 |

Edits of old tests (TW21): the inputs of `ToolInstall.pick` and `TalonUpdate.pick`, and the `Picked`, `ToolBuild.Facts`, `ToolFlow.Machine`, `ToolsStep.Ctx` literals get `exclude: []` (and `kept: Err(None)`). This is mechanical. No expected file of an L2 or L3 case changes.

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| The note | `acme/app 1.4.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*`, on stderr, in the place of the R-T9 age note (`ToolFlow.notes!`), before the `platform` line (R-SE8). `--quiet` hides it. |
| `--json` | No new field. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The resolve (packages, platform) | 082 |
| The compiler that a tool build uses | 084 |
| `install.sh`, `install.ps1` | They make no list call (R-T9). |

## 7. Questions (TW17)

None.

## 8. Disputes (from the code agent)

None yet.

## 9. Revert check (TW12), planned: 6 mutations

| No | Mutation | Test that must fail |
| --- | --- | --- |
| m1 | `ToolInstall.pick` step 4 ignores `exclude` | `ToolTest`, L2 `ti6-exclude` run 1 |
| m2 | `ToolInstall.pick` applies the age to `Exact` | `ToolTest` (the `Exact` row) |
| m3 | `TalonUpdate.pick` compares another name than `roc-talon/talon` | `TalonUpdateTest`, L2 `ts10-exclude-talon` |
| m4 | `kept` is set for `Exact` | `ToolTest` `kept`, L2 `ti6-exclude` run 5 |
| m5 | `ToolsFlow` uses the root list only (no union with `config.toml`) | L2 `pt5-exclude` run 2 |
| m6 | `notes!` ignores `--quiet` for the new note | L3 `ti4-exclude-age` run 2 |

## 10. Verify results

To fill at step 4.
