# 085 `tln init --platform owner/repo@<version>`, and the exclude list in `init`

Phase: P1. Status: review (tests written, red; test agent, 2026-10-27)

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
| `Init.read` | Checks, in order: 1 operands, 2 template, 3 `--ci`, 4 `--platform` with `package`, **5** the platform text, read whole (review, 2026-10-27: the reading of the test agent, T2): the part before the first `@` is `owner/repo` (exactly two non-empty parts at one `/`), and the text has at most one `@`; else `'<text>' is not a platform name: use owner/repo or owner/repo@1.2.3`. So `acme/pfx@1.2.0/x`, `acme/@1.2.0`, `a/b/c@^1` and `acme/pfx@1.2.0@x` are name errors, and `acme/pfx@` is a version error. **6** the part after `@`: `Selector.parse(text, Bool.False)` must be `Ok(Exact(v))`, else the R-IN9 (1) message (an empty text too). | R-IN9 |
| `Init.start` | Input gets `exclude : List(Str)`. `visible` uses `!Age.hides(...)` with the name `Ok(facts.name)`. | R-C15 |
| `Init.start_note` | New: `{ name : Str, chosen : Index.Candidate, now : U64, min_age : U64, exclude : List(Str) } -> Try(Str, [None])`. `Age.note` with the id `name` and the version of the candidate (the text without the prefix). It is a note of the run only when the resolve keeps the start release in the header (a move prints the note of slice 082 for the new release). | R-C16 |
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

Layers: L0 pure (`roc test`), L2 command cases (`tests/commands/cases`), L3 scenario (`tests/scenarios`). The test agent wrote them against the signatures of section 2 and of slice 081 (`Age`).

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/InitTest.roc`, expect "old checks" (changed) | The old `read` rows. The 3 name messages (`pfx`, `a/b/c`, `/pfx`) get the second form `or owner/repo@1.2.3`. The row `acme/pfx@1` moves to the next expect (it is a version now). | R-CM1, R-IN1, R-IN6, R-EC2, R-IN9 |
| L0 | `InitTest`, expect "read with version" (new, 23 rows) | `acme/pfx@1.2.0` gives name `acme/pfx` and version `1.2.0`; no version gives `-`; `--platform=...@0.26.0` form. Not exact: `@1.2`, `@1`, `@^1`, `@latest`, `@nightly-2026-10-09-258ab27`, `@-1`, `@+2`, `@abc1234`, `@` (empty): the R-IN9 (1) message with the text after `@`. Not a name: `@1.2.0@x`, `acme`, `acme/`, `/pfx`, `a/b/c`, `@1.2.0/x`, `acme/@1.2.0`, `a/b/c@^1` (the name check comes first): the name message. `package --platform acme/pfx@1.2.0` and `@^1`: the `package` message (check 4 first). | R-IN9, R-IN1, R-EC2, R-SL3, R-SL15 |
| L0 | `InitTest`, expect "named" (new, 12 rows) | `Init.named`: the exact release is chosen although a newer one exists; a young one gives the R-T9 note with the `Clock.format_utc` time; a release at exactly `min_age` and `min_age` 0 give no note; one second younger gives the note; the URL form of the newest candidate of that version (two forms, both orders); a missing version, `0.25` (not a full version) and an empty list give `NoVersion`. There is no `exclude` input, so no exclude note. | R-IN9, R-IN10, R-DI6, R-DI3, R-C7, R-C9, R-T9 |
| L0 | `InitTest`, expect "start with exclude" (new, 14 + 8 rows) | `Init.start` with `exclude`: `roc-lang/*`, `roc-lang/basic-cli` and `ROC-LANG/BASIC-CLI` keep the 1-day-old newest release; another repo, another owner, a prefix owner, bad patterns do not; the second pattern matches; `min_age` 0 and an old release change nothing; all young. `Init.start_note`: the R-C16 text, the first matching pattern as written, `Err(None)` for an old release, no match, no pattern and `min_age` 0; `no release` when `start` finds none. The old `start` rows pass `exclude: []` (mechanical). | R-C15, R-C16, R-C12, R-C7, R-IN1, R-IN2 |
| L0 | `tests/unit/VarsTest.roc`, expect "fixed" (new, 4 rows) | `Vars.scope` with `fixed`: `NightlyOnly` with `fixed: ["pf"]` gives a platform that is held and not movable, while the others stay movable; `fixed: []` as before; an unknown alias changes nothing; two fixed aliases. All other `Vars.scope` calls got `fixed: []` (mechanical). | R-SP23, R-IN10, R-SP8 |
| L2 | `init/it5-version` (new, 13 runs = lines `v1` to `v9` of `fx/commands`; one home for each run that needs its own state) | v1 `acme/pfx@1.2.0` (1.3.0 exists): `pf` is 1.2.0, the pin is n11 because the fake unit check fails 1.2.0 on n12 (an older nightly than the newest), the CI file is written, no note. v2 `acme/pfy@1.2.0`, 1 day old: the R-T9 note on stderr, pin n12. v3 the same with `acme/*` in `config.toml`: the same note, no exclude note. v4a to v4c `@1.2`, `@^1`, `@latest` and v5a to v5c `@nightly-...`, `@-1`, `@` (empty): exit 2, the only `Fx` call is `args`. v6 `@9.9.9`: exit 2 `acme/pfx has no release 9.9.9`, no file. v7 `acme/pfz@1.2.0` fails on every compiler (1.3.0 would pass): exit 10 with the blame, `main.roc` removed, the platform not moved. v8 `roc-lang/basic-cli@0.25.0` (0.26.0 young and newer): the hello world template, pin n12. v9 `--json` with a young named release: `data.written` as for no version, note on stderr. | R-IN9, R-IN10, R-IN7, R-IN6, R-IN1, R-IN8, R-C7, R-C9, R-T9, R-SP23, R-EC2 |
| L2 | `init/it6-exclude` (new, 3 runs) | `init --platform acme/pfy`, newest release 1 day old. x1 `config.toml` with `acme/*`: start 1.2.0, the R-C16 note, pin n12, and the tree diff has no `min-release-age-exclude` (init writes no key). x2 no list: start 1.1.0, no note. x3 a list of another owner and another repo (`other/*`, `acme/other`): start 1.1.0, no note. | R-C15, R-C16, R-C12, R-IN1, R-IN2, R-SE19 |
| L2 | `init/it1-app`, `it2-platform`, `it3-platform-moved`, `it4-nocompiler` (unchanged) | Must still pass. No expected file changed: no old L2 or L3 case prints `is not a platform name`. | R-IN1, R-IN8 |
| L2 | `tests/commands/L2Resolve.roc` (mechanical) | The `Resolve.Request` literal gets `fixed: []`. | R-SP23 |
| L3 | `scenarios/init/it1-platform-version` (new, 3 runs, real Fx, fake `roc`, fake release server, fake compilers n12 and n11 in the home) | Run 1 `acme/pfx@1.2.0`: exit 0, `main.roc` has the 1.2.0 URL of `pf` and the pin n11 (n12 fails the check of the platform dir), the CI file, the compiler runs. Run 2 `@^1`: exit 2, no file, no compiler run. Run 3 `@9.9.9`: exit 2, no file. | R-IN9, R-IN10, R-IN7, R-IN6, R-EC2 |

Edits of old tests (TW21): `InitTest` (`exclude: []` in `start_view`, the 3 name messages, the `acme/pfx@1` row moved), `VarsTest` and `FrozenTest` (`fixed: []` in every `Vars.scope` input), `tests/commands/L2Resolve.roc` (`fixed: []`). No expected file of an L2 or L3 case changed. The edits make the old files fail to compile until the code adds the fields (`fixed`, `exclude`): this is the red state.

Deviations from the first plan of this section (all listed for the review):

| No | Deviation | Reason |
| --- | --- | --- |
| T1 | The L2 case `it5-version` has 13 runs, not 9: the checks of runs 4 and 5 are 3 lines each (one selector for each line). `it6-exclude` has a third run (x3). | One selector for each run shows each message. |
| T2 | `Init.read` check 5 reads the whole text: 2 parts at the `/`, no empty owner or repo, at most one `@`. So `acme/pfx@1.2.0/x` and `acme/@1.2.0` are name errors, and `acme/pfx@` (empty version) is a version error. | Section 4 of the first draft lists `acme/pfx@1.2.0/x` as a name error. A rule "split at the first `@`, check the name part only" would give a version error for it. The test follows the list. |
| T3 | `Vars.scope` gets the input field `fixed : List(Str)` (aliases). | Section 2 says "Vars scope" has the field; the tests use it in `Vars.scope({ command, names, selectors, fixed, vars })`. |
| T4 | The L2 homes use the setup of `it1-app` run 5: `default-roc` names a compiler that is not installed (n9), so the baseline is not n12. In L3 `default-roc` is n11 (installed): with n12 as the baseline the check of the platform fails the baseline and the run stops with exit 10. | The ladder tests the baseline compiler first. |
| T5 | Slice 085 section 4 named `PickmovesTest` / `VarsTest`. The `fixed` rows are in `VarsTest` only (the owner of `PickmovesTest` is slice 082). | Separate files for each slice. |
| T6 | The expected L2 and L3 files were made with a private reference (code of this slice in `research/slice-085-revert/reference/`), and every expected file was read against the design. The reference has `Init.read`, `Init.named`, `Init.start` with `Age.hides`, `Init.start_note`, `fixed` in `Vars`, `ResolveBase.Request`, `Update.resolve!` and `Init.start_url!`. It uses the `Age` and the config key of the reference of slice 081. | TW18: the test agent shows that the tests can pass. |

## Red output (test agent, 2026-10-27)

The repo (code unchanged) against the new tests:

| Layer | Result |
| --- | --- |
| L0 | `l0-3.roc` (`InitTest`, `FrozenTest`, `VarsTest`): compile errors. `lib.Init.named does not exist`, `lib.Init.start_note does not exist`, `FrozenTest.roc:44: Vars.scope: the argument has the field fixed that the function does not take`, `InitTest.roc:24: Init.start: no field exclude`. 0 tests run. |
| L2 app | `roc check tests/commands/main.roc`: `L2Resolve.roc:39: type mismatch, the Resolve.Request literal has the field fixed`. So the whole L2 app does not compile until the code adds `Request.fixed`. With the old binary (`.work/bin/l2`): `init/it5-version` and `init/it6-exclude` fail with wrong output (`exit 2` and the old name message for the valid versions; the `unknown key min-release-age-exclude` warning and the wrong platform release), `it1-app`, `it2-platform`, `it3-platform-moved`, `it4-nocompiler` pass. |
| L3 | With the old `tln` (`.work/bin/tln`): `init/it1-platform-version` fails (exit 2 in run 1, the old name message). |

With the private reference: `roc test` of `InitTest`, `VarsTest` and `FrozenTest` passes (19 tests), the L2 app builds, all `init/*` L2 cases and the L3 case pass, and the old L2 cases pass.

Hand mutation (reference only, then put back): `fixed` ignored in `Init.after_first!` (`fixed: []`). `init/it5-version` v7 fails: the platform moves from 1.2.0 to 1.3.0 and the run stops with `exit 13` (`moving the held variable pf needs consent`) in place of `exit 10`.

## Files kept

`research/slice-085-revert/before/` has the old files (`NEW.txt` lists the new ones). `research/slice-085-revert/reference/` is the private reference (code, a driver `tests/unit/mine.roc`, the binaries `l2` and `bin/`). Keep it until the review is applied.

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| Not an exact version | `tln: error[usage]: '^1' is not an exact version: use owner/repo@1.2.3, or owner/repo for the newest release` (exit 2) |
| Not a platform name | `tln: error[usage]: 'acme' is not a platform name: use owner/repo or owner/repo@1.2.3` (exit 2) |
| No such release | `tln: error[usage]: acme/pfx has no release 9.9.9` (exit 2) |
| The age note of a named release | `acme/pfx 1.2.0 was released at 2026-10-26T09:30:00Z, less than min-release-age ago. It is used because the version is named.` on stderr (the form of `ToolInstall.age_note`) |
| The note of a start release kept by a pattern (R-C16) | `note: acme/pfx 1.3.0 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: acme/*`. `start_url!` returns the text and the flow adds it to the notes that `Update.print!` prints: a `note:` line in the human output, and an entry of `data.notes` with `--json`, without the prefix (the place of the notes of the flow, as 082). The age note of a named release (R-IN9) stays the R-T9 form on stderr. |
| `--json` | No new field. `data.written` is as today. |
| No nightly passes with the named platform | The blame of the ladder (R-AL), exit 10, as `tln upgrade roc` |

### After the review (2026-10-27): what the test agent changes

| No | Change | Rule ids |
| --- | --- | --- |
| 1 | `it6-exclude` x1 and the L0 note rows: the expected R-C16 note moves from bare stderr text to the notes of the flow: `note: <text>` in the human output (stdout, before `check:`/the created lines, with the notes of the resolve), and with `--json` in `data.notes`. The R-IN9 named-age note of `it5-version` v2 and v3 stays on stderr, bare. | R-C16, R-IN9 |
| 2 | New row in `it6-exclude` (x4): the newest platform release is young and kept by the pattern, but the resolve moves the platform to another release (the ladder fails the start release): no note for the start release; the note of 082 for the release that is in the header, if it is young and kept. | R-C16, R-IN2 |
| 3 | `Init.read` rows of T2 stay as written (the reading is accepted). | R-IN9 |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| Ranges, series and `@latest` for `init --platform` | Decision B1: exact only. A later change can add them. |
| `tln add --platform owner/repo[@sel]` | Unchanged (R-AD29): it takes any selector. |
| A template for each version of `roc-lang/basic-cli` | B6: the ladder decides. |
| A flag to write the `talon.toml` with a range | `init` writes no `talon.toml` (R-IN5). |

## 7. Questions (TW17)

None from the design. The human can change B1 (exact only) and B6 at the review. For the review of the tests: T2 (the reading of check 5: accepted, review of 2026-10-27) and the proposal that the platform alias in `fixed` is `pf`, the alias of the platform entry that `init` writes (section 3, row 3).

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
