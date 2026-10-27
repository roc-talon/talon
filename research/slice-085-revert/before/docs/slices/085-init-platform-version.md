# 085 `tln init --platform owner/repo@<version>`, and the exclude list in `init`

Phase: P1. Status: scope

Slice 085 is the plan row 085 of `PLAN-P1.md` (section 2d). It needs slice 081 (`Age`) and slice 082 (`ResolveBase.Settings.exclude`, the notes of the resolve). Source: Decision 2 of the user (2026-10-27), `DESIGN-GAPS-2026-10-27.md` (part B), and the `init` row of A5. The design is R-IN1, R-IN2, R-IN8, R-IN9, R-IN10, R-CM1 (`DESIGN-CLI.md`, section 5 and 1), R-SP23 (`DESIGN-RESOLUTION.md`, section 9), R-C15, R-C16.

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-IN9 (1) | `--platform owner/repo@<version>`: the version has 3 parts (`Selector` `Exact`). A range, a series, `latest`, a nightly tag, a relative step, a git ref or an empty text: exit 2, `'<selector>' is not an exact version: use owner/repo@1.2.3, or owner/repo for the newest release`. This check runs before any read. | L0 `InitTest` (`read`); L2 `init/it5-version` runs 4, 5 |
| R-IN9 (2) | The version is not in the release list, or the release is a draft, a prerelease or yanked: exit 2, `owner/repo has no release <version>`, nothing is written. | L0 `InitTest` (`named`); L2 `it5-version` run 6 |
| R-IN9 (3) | A named release is not hidden by `min-release-age` or by `min-release-age-exclude`. When it is younger than `min-release-age`: one note on stderr, `<owner/repo> <version> was released at <time>, less than min-release-age ago. It is used because the version is named.` | L0 `InitTest` (`named` note); L2 `it5-version` runs 2, 3 |
| R-IN9 (name) | `--platform` with a `/`-less name, 2 or more `/`, an empty part: exit 2, `'<text>' is not a platform name: use owner/repo or owner/repo@1.2.3` (the text of today gets the second form). With the template `package`: exit 2 first (today's check 4). | L0 `InitTest` (`read`) |
| R-IN10 (1, 2) | The start entry is the URL form of the named release. The resolve is the flow of `tln upgrade roc`: the platform is held and not movable, the nightly is free. The `roc:` pin is the newest nightly that passes the ladder with that platform. No nightly passes: exit 10 (`no_tuple`), the files of the run are removed (R-IN7). | L0 `VarsTest` (`fixed`); L2 `it5-version` runs 1, 7 |
| R-SP23 | The platform that `init` names with a version is never movable. The other held variables stay movable (nothing else is held in `init`). | L0 `VarsTest`/`PickmovesTest` |
| R-IN10 (3) | The template text follows the repository: `roc-lang/basic-cli@0.25.0` gives the basic-cli template. Another repository gives the stub of R-IN8. | L2 `it5-version` run 8 |
| R-IN10 (4) | The CI file is the same as for a run with no version. | L2 `it5-version` run 1 (`tree.diff`) |
| R-C15 (init row), R-C16 | The start release (no version) is not hidden by the age when a pattern matches `owner/repo`. One note on stderr for a young start release that only the pattern kept. `Init.start` reads `config.toml` (the new project has no `talon.toml`, R-IN5). | L0 `InitTest` (`start`, `start_note`); L2 `init/it6-exclude` |
| R-IN1, R-IN2 | `--platform owner/repo` (no version): unchanged except for the exclude list. | L2 `it2-platform`, `it3-platform-moved` (unchanged) |
| R-C7, R-C9, R-T9 | A named version: no age rule, a note with the age (the form of R-T9). | L0, L2 as above |

## 2. Public signatures (stubs `crash "todo: slice 085"` where new)

| Module | Change | Rule |
| --- | --- | --- |
| `Init.Plan` | New field `version : Try(Str, [Unset])`. `named` stays the `owner/repo` part. | R-IN9 |
| `Init.read` | Checks, in order: 1 operands, 2 template, 3 `--ci`, 4 `--platform` with `package`, **5** the platform text: split at the first `@`; the name part is `owner/repo` (two non-empty parts, no other `@`), else `'<text>' is not a platform name: use owner/repo or owner/repo@1.2.3`, **6** the part after `@`: `Selector.parse(text, Bool.False)` must be `Ok(Exact(v))`, else the R-IN9 (1) message (an empty text too). | R-IN9 |
| `Init.start` | Input gets `exclude : List(Str)`. `visible` uses `!Age.hides(...)` with the name `Ok(facts.name)`. | R-C15 |
| `Init.start_note` | New: `{ name : Str, chosen : Index.Candidate, now : U64, min_age : U64, exclude : List(Str) } -> Try(Str, [None])`. `Age.note` with the id `name` and the version of the candidate. | R-C16 |
| `Init.named` | New: `{ name : Str, list : List(Index.Candidate), version : Str, now : U64, min_age : U64 } -> Try({ candidate : Index.Candidate, note : Try(Str, [None]) }, [NoVersion])`. The candidates with `ident.version == version` (`Index.candidates` has dropped drafts and prereleases), the URL form of the newest of them (`Index.new_entry`, R-DI6), `Index.order(.., Highest)` first. `note` is `Ok(text)` when `published_at + min_age > now` (R-IN9 (3)); the time is `Clock.format_utc`. `Err(NoVersion)` for an empty result. | R-IN9, R-DI3 |
| `ResolveBase.Request`, `Update.resolve!` (`which` record), `Vars` scope | New field `fixed : List(Str)`: aliases that are never movable (R-SP23). `Vars.movable_of` gives False for them. Every other caller passes `[]`. | R-SP23, R-IN10 |

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Init.roc`: `Plan`, `read`, `is_full_name` (it stays for the name part), `start`, `start_note`, `named` | As section 2. `Args.roc` needs no change: `--platform` is a flag with a value for `init` already. |
| 2 | `Init.roc`: `start_url!` | Reads `config.toml` (`RocInstall.read_config!`). With `plan.version` `Ok(v)`: `Init.named`, `NoVersion` is the exit 2 failure `<name> has no release <v>`, the note goes to stderr. Else `Init.start` with `exclude: config.min_release_age_exclude` and `Init.start_note` on stderr. The `min-release-age` failure `no release of <name> is old enough for min-release-age` stays. |
| 3 | `Init.roc`: `make!`, `after_first!` | A named version: `names: ["roc"]` and `fixed: ["pf"]` for `Update.resolve!` (the alias of the platform entry, `pf`). Step 6b (the platform moved: make the stub again) cannot happen and is skipped. No version: `names: []` and `fixed: []` as today. |
| 4 | `Update.roc` (`resolve!`, `request_of`), `ResolveBase.Request`, `Vars.roc` (`movable_of` and the scope builders at lines 286 to 306) | The field `fixed` as section 2 |
| 5 | `Init.roc` doc comment (the steps table) | Steps 4 and 6 name R-IN9, R-IN10 |

## 4. Tests

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `InitTest` `read` rows (new and changed) | `--platform acme/pfx@1.2.0` gives `named` `acme/pfx`, `version` `Ok("1.2.0")`. `acme/pfx` gives `version` `Err(Unset)`. `acme/pfx@1.2`, `@^1`, `@latest`, `@nightly-2026-10-09-258ab27`, `@-1`, `@+2`, `@abc1234`, `@` : the R-IN9 (1) message. `acme/pfx@1.2.0@x`, `acme`, `acme/`, `/pfx`, `a/b/c`, `acme/pfx@1.2.0/x`: the name message with `or owner/repo@1.2.3`. `package --platform acme/pfx@1.2.0`: the `package` message (check 4 first) | R-IN9, R-IN1 |
| L0 | `InitTest` `named` rows | A list of 3 releases: the exact one is chosen although a newer one exists; the URL form is the R-DI6 form; a young one gives the note text (with the `Clock.format_utc` time); an old one gives `Err(None)`; a missing version gives `Err(NoVersion)`; a version in two series is not possible, so no row; an excluded owner (`exclude` is not an input) gives the same note | R-IN9, R-DI6 |
| L0 | `InitTest` `start`, `start_note` rows | The existing rows with `exclude: []`. New: a young newest release is the start with `["acme/*"]`, and not without. `start_note` gives the R-C16 text for it, and `Err(None)` for an old one. A pattern of another owner: the old release | R-C15, R-C16, R-IN1 |
| L0 | `VarsTest` / `PickmovesTest` (the file that tests `Vars.scope`) | `fixed: ["pf"]`: the platform is held and not movable; `fixed: []`: movable as today (`NightlyOnly` mode) | R-SP23, R-SP8 |
| L2 | `init/it5-version` (new, 9 runs) | Run 1: `init --platform acme/pfx@1.2.0`, 1.3.0 exists and is old: `pf` is 1.2.0, the pin is the newest nightly that passes with it (an older nightly than the newest: the fake probe fails the newest), the CI file is written, no note. Run 2: 1.2.0 is 1 day old: the note, same result. Run 3: the same with `acme/*` in `config.toml`: the same note (no exclude note). Run 4: `@1.2`, `@^1`, `@latest`: exit 2, no `fetch`, no file. Run 5: `@nightly-2026-10-09-258ab27`, `@-1`, `@`: exit 2. Run 6: `@9.9.9`: exit 2, `acme/pfx has no release 9.9.9`, no file. Run 7: no nightly passes with 1.2.0 (the fake probe fails all): exit 10, the blame, `main.roc` removed, the platform not moved although 1.3.0 passes. Run 8: `--platform roc-lang/basic-cli@0.25.0`: the basic-cli template. Run 9: `--json`: `data.written` as for a run with no version; the note on stderr | R-IN9, R-IN10, R-IN7, R-IN6, R-IN1, R-C9, R-SP23 |
| L2 | `init/it6-exclude` (new, 2 runs) | `init --platform acme/pfx`, the newest platform release is 1 day old, `config.toml` has `acme/*`: the start is the young release, the note on stderr, the ladder passes. Run 2: no pattern: the start is the older release | R-C15, R-C16, R-IN2 |
| L2 | `init/it2-platform`, `it3-platform-moved` (unchanged) | They must still pass: `--platform acme/pfx` with no version | R-IN1, R-IN8 |
| L3 | `scenarios/init/it1-platform-version` (new dir, 3 runs, real Fx, fake roc, fake API) | Run 1: `tln init --platform acme/pfx@1.2.0`: exit 0, `main.roc` has the `pf` URL of 1.2.0, the `roc:` pin, the CI file. Run 2: `@^1`: exit 2, no file. Run 3: `@9.9.9`: exit 2 | R-IN9, R-IN10, R-EC2 |

Edits of old tests (TW21): the `Init.Plan` literals in `InitTest` get `version: Err(Unset)`; the inputs of `Init.start` get `exclude: []`. Two expected texts of old cases may change: the check-5 message in `init/it*` cases that print `is not a platform name` (the text gets `or owner/repo@1.2.3`). The test agent reads each changed file (TW21).

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| Not an exact version | `tln: error[usage]: '^1' is not an exact version: use owner/repo@1.2.3, or owner/repo for the newest release` (exit 2) |
| Not a platform name | `tln: error[usage]: 'acme' is not a platform name: use owner/repo or owner/repo@1.2.3` (exit 2) |
| No such release | `tln: error[usage]: acme/pfx has no release 9.9.9` (exit 2) |
| The age note of a named release | `acme/pfx 1.2.0 was released at 2026-10-26T09:30:00Z, less than min-release-age ago. It is used because the version is named.` on stderr (the form of `ToolInstall.age_note`) |
| The note of a start release kept by a pattern (R-C16) | `acme/pfx 1.3.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*` on stderr |
| `--json` | No new field. `data.written` is as today. |
| No nightly passes with the named platform | The blame of the ladder (R-AL), exit 10, as `tln upgrade roc` |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| Ranges, series and `@latest` for `init --platform` | Decision B1: exact only. A later change can add them. |
| `tln add --platform owner/repo[@sel]` | Unchanged (R-AD29): it takes any selector. |
| A template for each version of `roc-lang/basic-cli` | B6: the ladder decides. |
| A flag to write the `talon.toml` with a range | `init` writes no `talon.toml` (R-IN5). |

## 7. Questions (TW17)

None. The human can change B1 (exact only) and B6 at the review.

## 8. Disputes (from the code agent)

None yet.

## 9. Revert check (TW12), planned: 7 mutations

| No | Mutation | Test that must fail |
| --- | --- | --- |
| m1 | `read` accepts a range as a version | `InitTest` `read`, L2 `it5-version` run 4 |
| m2 | `named` applies `min-release-age` (a young named release has no candidate) | `InitTest` `named`, L2 run 2 |
| m3 | The resolve of `init` has `names: []` with a version (the platform moves to 1.3.0) | L2 `it5-version` run 7, L3 run 1 |
| m4 | `fixed` is ignored (the platform is movable) | `VarsTest`, L2 run 7 |
| m5 | A named release gets the exclude note as well as the age note | `InitTest` `named`, L2 run 3 |
| m6 | `Init.start` ignores `exclude` | `InitTest` `start`, L2 `it6-exclude` run 1 |
| m7 | A missing version writes `main.roc` before the stop | L2 `it5-version` run 6 (`tree.diff`) |

## 10. Verify results

To fill at step 4.
