# 038 `tln upgrade` for packages

Phase: P1. Status: done

Slice 038 is the plan row 038 of `PLAN-P1.md`. It needs 034 to 037d (done). `tln upgrade roc` (the free nightly, R-UP6, R-UP9, the optional downloads, the one prompt) is slice 039, not this slice.

The private reference has 368 added lines of code (without comments and empty lines): `Upgrade.roc` 92, `Lags.roc` 147, `Ranges.rewrite` 38, `InstallFlow` 30, `PickFlow` 19, `Vars` 14, `ResolveBase` 9, `Pick.newest` 8, `PickAsk` 6, `Run` 3, `main` 2. The row said about 380. This is under 450, so there is no split. The reference was deleted at the review (2026-10-24, after the changes of the review: +28 lines for `Lags.stuck`, `Lags.was`, the line `(was ...)`, the strategy of `upgrade` and the selector failure).

## 1. Scope

| Item | Where | Rule | In this slice |
| --- | --- | --- | --- |
| The command `upgrade`: names, flags, `--strategy lowest` is exit 2, `--frozen` is exit 2, the name `roc` is "not built yet" | `Upgrade.read`, `Upgrade.run!` | R-CM5, R-UP8, R-FL13 | yes |
| All packages are free (no names) or the named ones (names). An anchor is held unless named. A fixed host stays held | `Vars.scope` arm `Upgrade` | R-SP6, R-SP7, R-UP1, R-VA5, R-DI11 | yes |
| The domain has no package range. A held variable that moves has no range | `Vars.scope` (`ranges: []`, `any_series`) | R-UP1, R-SP23 | yes |
| A move to another series is a replace under the same alias, with the warning R-C8 | `ResolveBase.new_series`, the edit line | R-UP3 | yes |
| A held variable that has to move: report, consent, rewrite | `PickFlow`, `InstallFlow` (the code of slice 017) | R-UP4, R-SP16, R-SP17, R-SP25 | yes |
| The range rewrite in `talon.toml` | `Ranges.rewrite`, `Lags.rewrites`, `InstallFlow` | R-UP5, R-UP11 | yes |
| The report of the variables that did not get their newest release | `Lags.of`, `Lags.note`, `InstallFlow` | R-UP2 | yes |
| The rows of the table for `update` and `upgrade` (the package columns) | the above | R-UP10 to R-UP13 | yes. The nightly column (free) is slice 039 |
| `upgrade roc`, the free nightly, `--no-check` with a free nightly, the one prompt R-NI12 | none | R-UP6, R-UP9, R-SP8, R-SP9, R-SP12, R-SP13 | no (slice 039) |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo"`)

| Name | Signature | File |
| --- | --- | --- |
| `Upgrade.read` | `Args -> Try({ opts : Opts }, Fail)` | `cli/lib/Upgrade.roc:25` |
| `Upgrade.run!` | `Fx, Args => I32` | `cli/lib/Upgrade.roc:30` |
| `Lags.Lag` | `{ alias : Str, newest : Str, got : Str, why : Str }` | `cli/lib/Lags.roc:11` |
| `Lags.of` | `Lags.Input -> List(Lags.Lag)`, the input is `{ slots, chosen, facts, now, min_age, snapshot, compiler, checks, used }` | `cli/lib/Lags.roc:26` |
| `Lags.note` | `Lags.Lag -> Str` | `cli/lib/Lags.roc:30` |
| `Lags.stuck` | `{ members, moves } -> List(Str)`: the notes for the keys that stay (Q1 (b)) | `cli/lib/Lags.roc` |
| `Lags.was` | `{ members, path, key } -> Try(Str, [None])`: the old value of a key (Q6 (a)) | `cli/lib/Lags.roc` |
| `Lags.rewrites` | `{ members, moves : List({ file, alias, version }) } -> List({ path, key, value })` | `cli/lib/Lags.roc:36` |
| `Ranges.rewrite` | `{ range : Str, version : Str } -> Try(Str, [NoForm])` | `cli/lib/Ranges.roc:53` |
| `Vars.scope` | the tag `Upgrade` in `command` (stub: `crash "todo"` in the arm) | `cli/lib/Vars.roc:108`, `:265` |
| `ResolveBase.Request.command` | `[Install, Update, Upgrade]` | `cli/lib/ResolveBase.roc:45` |
| `ResolveBase.Finish` | new field `lags : List(Lags.Lag)` (stub: `PickFlow` sets `[]`) | `cli/lib/ResolveBase.roc:133` |
| `ResolveBase.new_series` | `Vars.Scoped, Pick.Chosen -> Bool` (the chosen release is in another group than the variable) | `cli/lib/ResolveBase.roc:268` |
| `Run.run!` | dispatches `args.command == ["upgrade"]` to `Upgrade.run!` | `cli/lib/Run.roc:69` |

The wiring is not stubbed: `PickFlow.prepare!` (the pick command `Upgrade`), `ResolveBase.settings_of` (`upgrade` ignores `[resolution] strategy` of the file: `Highest`, Q2), `PickFlow.search!` (call `Lags.of` for `Upgrade`, store it in `facts.lags`), `InstallFlow.finish!` (the ` new series` suffix, the `note:` lines of the lags and of `Lags.stuck`, the pairs of `Lags.rewrites`), `InstallWrite.write!` (the toml line ends with `(was "<old>")` from `Lags.was` when the key had another value), and `PickAsk` (the checks `request.command == Update` become `!= Install`). Section 9 has the list.

## 3. Rules of the command

| # | Rule | Source |
| --- | --- | --- |
| 1 | `upgrade` with no names frees each `Indexed` variable, except an anchor (a range that starts with `=`) and a fixed host. With names, only the named variables are free (an anchor too). A named fixed host stays held | R-SP6, R-SP7, R-UP1, R-VA5, R-DI11 |
| 2 | A free variable has no range, its domain is every release of every series (`any_series`), and `min-release-age` and the header value rules stay (R-C6, R-C7, R-C9) | R-UP1, R-UP12 |
| 3 | A held variable that is not an anchor is movable. If no tuple exists with the held values fixed, the second search moves it (consent R-NI3), and its ranges are `[]` | R-SP23, R-SP16, R-SP17, R-UP4 |
| 4 | A moved variable in another series is a replace under the same alias. Its edit line ends with ` new series`. The warning R-C8 is the one of slice 034 | R-UP3 |
| 5 | The key of `talon.toml` for a moved alias gets the range of `Ranges.rewrite`. A range that admits the new version stays. No key is added. No file is created | R-UP5, R-SP25 |
| 6 | `update X@latest` follows R-UP5 too. `update` and `update X` do not change `talon.toml` | R-UP11, R-UP10 |
| 7 | The free variables that did not get their newest release are `note:` lines, in the order of the slots, with the first reason of the table of `Lags.of` | R-UP2 |
| 8 | `--strategy lowest` is exit 2. `--frozen` is exit 2 | R-UP8, R-FL13 |
| 9 | The nightly is held (slice 039 frees it) | R-UP12, R-UP13 |

`Ranges.rewrite` (rule 5):

| Range | New version | Result | Note |
| --- | --- | --- | --- |
| `^2.1` | `3.0.2` | `^3.0` | the parts are taken from the new version, the number of parts stays |
| `^0.25` | `0.26.1` | `^0.26` | |
| `0.25.*` | `0.26.1` | `0.26.*` | the wildcard end stays |
| `1.0.*` | `1.2.0` | `1.2.*` | |
| `2` | `3.0.2` | `3` | |
| `^2.1.3` | `3.0.2` | `^3.0.2` | |
| `~1.4` | `2.0.0` | `~2.0` | |
| `=2.0.0` | `3.0.2` | `=3.0.2` | an anchor is an anchor of the new version |
| `^2.1` | `2.5.0` | `^2.1` | it admits the version: no change |
| `>=1.2, <1.5` | `3.0.2` | `Err(NoForm)` | question Q1 |

`Lags.of` (rule 7). The newest release `n` is the first of the domain of the slot with no range (`Pick` rules 1, 3, 4, 5, order `Highest`). A slot with `hold` other than `Free`, an empty domain, and a slot whose chosen release is `n` give no lag. The first reason that holds:

| # | Reason | `why` |
| --- | --- | --- |
| 1 | The db has a real row of `n` on the held compiler `H` that touches the app: a hang, a crash, a fail with no module, a fail with `main.roc`, a fail with a module that `used` lists for `n` (R-UM1, R-EP7) | `fails the unit check on <H>`, `hangs the unit check on <H>`, `crashes the unit check on <H>` |
| 2 | `n` is a package and its header names a platform URL that is not the chosen URL of the platform slot (R-C3) | `needs <alias of the platform slot> <version that n names>` |
| 3 | The header of `n` has a dep in the group of another slot, with a version above the chosen version of that slot (R-C2) | `needs <alias of that slot> >= <dep version>` |
| 4 | `n` is a platform and a chosen package names another platform URL (R-C3) | `<alias> <chosen version> needs <alias of n> <version that it names>` |
| 5 | None of these | `it does not fit the closure of the tuple` |

A release with no header fact skips the reasons 2 and 3. A fail row of a module that the app does not use is no reason. With no compiler (`compiler: Err(None)`), reason 1 is skipped.

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/ranges.roc` expect 3 (14 rows) | `Ranges.rewrite`: forms, anchor, wildcard, admits, `NoForm` | R-UP5 |
| L0 | `tests/unit/vars.roc` expect 7 (6 rows) | `Vars.scope` with `Upgrade`: no names, anchor held with note, named anchor, named var, movable with no range, fixed host, unknown name | R-SP6 R-SP7 R-UP1 R-VA5 R-DI11 R-SP23 R-UP12 R-UP13 |
| L0 | `tests/unit/upgrade.roc` expect 1 (15 rows) | `Upgrade.read`: names, flags, `lowest`, `--frozen`, a selector, `roc`, the order of the checks | R-UP8 R-CM5 R-FL5 R-FL10 R-FL13 R-SP8 R-SP9 R-SL5 |
| L0 | `tests/unit/upgrade.roc` expect 2 (15 slots, 2 lists of reasons) | `Lags.of`: all 5 reasons, the order, a hidden newest, a held and a movable slot, a header with no fact, a fail row of an unused module, no compiler, `Lags.note` | R-UP2 R-UP1 R-C2 R-C3 R-C7 R-EP7 R-UM1 R-SP23 |
| L0 | `tests/unit/upgrade.roc` expect 3 (9 rows) | `Lags.rewrites`: forms, name form, no key, no file, `NoForm`, 2 members, no move | R-UP5 R-SP25 R-WS1 R-I2 |
| L0 | `tests/unit/upgrade.roc` expect 4 (7 rows `Lags.stuck`, 4 rows `Lags.was`) | the note for a key that stays (Q1 b), no note when the range admits, no key, no file, one note per key, order; the old value of a key (Q6 a) | R-UP5 R-SP25 R-I2 |
| L2 | `upgrade/ug1-flow` run 1 | no `talon.toml`: all free, new series, the warning R-C8, no file created | R-SP6 R-UP1 R-UP3 R-UP5 R-C8 R-C6 |
| L2 | same, run 2 | comment, unknown key, anchor held with its note, keys `^3.0` and `0.2.*` | R-UP1 R-UP5 R-VA5 |
| L2 | same, run 3 | named anchor is free, key `=2.0.0` | R-SP7 R-VA5 R-UP5 |
| L2 | same, run 4 | `upgrade json`: the key `acme/json@^2.1` keeps its name | R-SP7 R-UP5 |
| L2 | same, run 5 | `--strategy lowest`: exit 2 | R-UP8 |
| L2 | same, run 6 | workspace: the root key once, no key for the alias `j2` | R-SP25 R-WS1 R-UP5 |
| L2 | same, run 7 | `update`: the key does not change | R-UP10 |
| L2 | same, run 8 | `update json@latest` with a key: `^3.0` | R-UP11 R-SL5 |
| L2 | same, run 9 | `update json@latest` with no file: no file created | R-UP11 R-UP5 |
| L2 | same, run 10 | `upgrade --dry-run --json` | R-CM5 R-J3 |
| L2 | same (`ug1-flow`), run 11 | a key with no form: the note, the key stays (Q1 b) | R-UP5 |
| L2 | same, run 12 | `[resolution] strategy = "lowest"` is ignored; the line ends with `(was "^2.1")` (Q2 a, Q6 a) | R-UP8 R-UP5 |
| L2 | `upgrade/ug2-lag` run 1 | the 3 lags: dep of a held anchor, unit fail, platform of a new series | R-UP2 R-C2 R-C3 R-UM1 R-EP7 |
| L2 | same, run 2 | `--json`: the lags are in `notes` | R-UP2 R-J3 |
| L2 | same, run 3 | `update`: no lag notes | R-UP10 |
| L2 | `upgrade/ug3-move` run 1 | a held variable has to move: report, exit 13 (non-interactive) | R-UP4 R-SP16 R-SP17 |
| L2 | same, run 2 | `--yes`: both move, keys `^2.0` and `1.2.*` | R-UP4 R-SP25 R-UP5 R-SP23 |

L0 expects: `ranges.roc` +1, `vars.roc` +1, `upgrade.roc` 4 (a new file, 277 lines, about 1.1 s alone in `roc test`; the step l0 grows from 7.5 s to 8.3 s of 10 s). Deep cases: 3 (`ug1-flow` 12 runs, `ug2-lag` 3 runs, `ug3-move` 2 runs). L3 has no new scenario: L2 runs the whole `Run.run!`.

The 3 cases are 3 and not 1 because the worlds differ (ug2 needs a hard unit fail and a platform of a new series, ug3 needs a hand-edited header, ug1 has the big world of the range rewrite). Some of the first runs with one case crashed only because of the cache (section 8, C1).

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| Moved line of `upgrade` into another group | `  ~ <alias>: <name> <old> -> <new> new series` (`update` has no suffix) | ug1 runs 1 to 4, ug2, ug3 |
| Held anchor (no names) | `<alias>: anchor, held`, in the place of the fixed-host line R-DI11 (first lines, before the platform notes) | ug1 run 2 |
| Lag | `note: <alias> <newest> is not used, <got> is chosen: <why>`, after the platform notes. It is in `data.notes` of `--json` (no new field) | ug2 runs 1 and 2 |
| Toml line | `<path>: <key> = "<value>" (was "<old>")` when the key had another value (Q6 (a), the example of Resolution 10). A new key has no suffix. `--json` `toml` has no new field | ug1 runs 2 to 4, 6, 8, 12, ug3 run 2, and the old case `resolve/rs-new-toml` |
| `--strategy lowest` | `tln: error[usage]: --strategy lowest does not work with tln upgrade: upgrade only moves up`, exit 2 | ug1 run 5, upgrade.roc |
| `--frozen` | `tln: error[usage]: flag '--frozen' works only for tln install with no names` (the text of `update`) | upgrade.roc |
| Selector | `tln: error[usage]: tln upgrade does not take a selector: '<name>'. Use tln update <name>` | upgrade.roc |
| Key that stays | `note: talon.toml: <key>: the range does not admit <version>, change it by hand`, after the lag notes. In `data.notes`. No toml line for the key | ug1 run 11 |
| `upgrade roc` | `tln: error[internal]: tln upgrade roc is not built yet` (until slice 039) | upgrade.roc |
| `--json` | `"command":"upgrade"`, the fields of `update` | ug1 run 10 |
| Held move, no consent | the report of slice 017, exit 13 | ug3 run 1 |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | The nightly is held in `upgrade` and `upgrade X`. The name `roc` is an Internal failure "not built yet" | free the nightly now (R-UP6 and R-UP9 need the downloads and the prompt of slice 039) |
| D2 | The newest release for the lag is the first of the domain of the slot with no range. A young release is no candidate (R-C7), so no lag | report a hidden release as a lag |
| D3 | A lag is a `note:` line with the reason in a fixed order (section 3). No new JSON field | a new `lags` field in the envelope |
| D4 | The rewrite keeps the prefix, the number of parts and the wildcard end. An anchor becomes `=<new>` | always `^<major>.<minor>` |
| D5 | Only keys of `[dependencies]` are rewritten | `[overrides]` too (Q3) |
| D6 | `update X@latest` rewrites the range (R-UP11 says "follows R-UP5") | rewrite for each selector |
| D7 | A held variable that moved (R-UP4) is rewritten as a free variable is (R-SP25) | leave the key |
| D8 | ` new series` appears for `upgrade` only. `update` output does not change, so no old expected file changes | the suffix for `update X@latest` too |
| D9 | R-UP4 reading: with all held values fixed a tuple exists in almost all projects, because the header value is always in the domain (R-C9). So a held variable moves only when the header has no tuple (the hand-edited header of `ug3-move`), or when the user names it. The lag note reports the held anchor or the held variable as the reason | free the movable variables in the first search (it contradicts R-SP15) |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-UP6, R-UP9, R-SP8, R-SP9, R-SP12, R-SP13 and the nightly column of R-UP12, R-UP13 | slice 039 |
| Out 2 | R-UP7 (budget, exit 12) | done in 036b; the loop is the same |
| Out 3 | R-PA4 (patched entries) | slice 043 |
| Out 4 | `--no-check` with `upgrade` | R-UP9 is for a free nightly. In 038 the nightly is held, so the flag works as in `update`. No test |

| Id | Question | Options |
| --- | --- | --- |
| Q1 | A range with no form in R-UP5 (`>=1.2, <1.5`, a list) that does not admit the new version | Answered (b), see the review: note `talon.toml: <key>: the range does not admit <version>, change it by hand`, the key stays |
| Q2 | `[resolution] strategy = "lowest"` in `talon.toml` or in the config, and `tln upgrade` | Answered (a): ignored, `Highest` |
| Q3 | A key of `[overrides]` for a moved alias | Answered (a): not rewritten |
| Q4 | `tln upgrade X@sel` (a selector) | Answered (a): usage failure |
| Q5 | R-UP8 "upgrade only moves up": a variable can move down when the header has no tuple | Answered (a): allowed |
| Q6 | `(was "<old>")` in the toml line | Answered (a): added |
| Q7 | The text of the R-UP2 report | Accepted as a proposal |

## 8. Compiler and tool limits met (for the manager and the code agent)

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | The roc object cache (`.work/cache/roc/compat-*/objects-v7`, nightly-2026-10-14-38a3029): when the sources change between 2 `roc build --opt=dev` runs with one cache, the new test app can be bad. The L2 app crashes with "boxy runtime list comparator ordering layout failed" or a segmentation fault (stack in `roc_boxy_list_sort_with`, `roc_builtins_str_to_utf8`, `roc_builtins_list_decref_with`, from `Oracle.step_with`). It looked like a codegen bug: one dead function, or 2 lines in a doc comment, changed the result, and `--opt=speed` passed. The cause is the cache | With a bad cache, 37 to 42 of 93 old L2 cases crash, also with the stubs. With `objects-v7` removed, the reference passes all 93 cases in dev, and the stubs pass 90 (3 new fail with `todo`). `prune_roc_objects` of `tests/lib.sh` keeps the 3 newest files of each dir, which may also leave a bad mix | Before a run after many edits: `rm -rf .work/cache/roc/compat-*/objects-v7` (this was done before the red run). `research/slice-038-revert/crash-repro/repro.sh` shows it. Report to the roc team and to the owner of `scripts/test.sh` (TW25 asks for a report of a dev and speed difference) |
| C2 | A `?` closure with mixed error tags, and `keep_oks(|r| r).first()` on a list of `Try`, crashed the app (a runtime error in `Lags.of`) | the reference uses nested `match` | use nested `match` |
| C3 | `Ok({ opts })` is a block | write `Ok({ opts: opts })` | same |

## 9. Notes for the code agent

| Topic | Note |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/upgrade/*/rules` has the text of each run |
| `Vars.scope` | The `Upgrade` arm of `scoped_one`: `anchor` is a range with a `=` prefix. `free = indexed and (if no names: not anchor, else named)`. `movable` as `Update`. `variable` has `ranges: []` when free or movable (the reference writes the record in full). `any_series` is `free`. The note: the fixed-host line when no names or named, else for a held anchor with no names `<alias>: anchor, held` |
| `Pick` | `Lags.of` needs the newest release of a slot. The reference added `Pick.newest : Slot, { now, min_age, snapshot, facts } -> Try(Index.Candidate, [None])` (8 lines): a `Step` with the one slot and `Highest`, then `domain_of(...).ordered.first()` |
| `PickFlow` | `prepare!`: the pick command is `Upgrade` for `Upgrade`. `search!`: `Lags.of` for `Upgrade` only (`update` gives `[]`, tested by ug2 run 3), with `looped.chosen`, `looped.facts`, `looped.probed.compiler/checks/used` |
| `InstallFlow` | The ` new series` suffix for `Upgrade` and `ResolveBase.new_series`. The `note:` lines of `facts.lags` after the platform notes, in `Outcome.notes` after the platform notes and before `plan.notes`. `pairs` gets `Lags.rewrites` for the moved variables of `Upgrade`, and for the aliases named with `@latest` in `update` (`asked.picks`, `Latest`; a `match`, `==` on a `Try` does not compile) |
| `PickAsk` | `request.command == Update` becomes `request.command != Install` (3 places) |
| `Upgrade.run!` | The steps of `Update.run!` without the picker. `Upgrade.read` removes `--frozen` before `Opts.read`, so the failure text of `Opts.read` comes first |
| Review changes | `Lags.stuck` (Q1 b) and `Lags.was` (Q6 a) are pure and tested at L0. `InstallFlow.finish!` prints `Lags.stuck` as `note:` lines after the lag notes and adds them to `Outcome.notes` after the lag notes (the same moves as the pairs: `moves_of` in the reference). `InstallWrite.write!` appends ` (was \"<old>\")` when `Lags.was` is `Ok` and differs from the new value. `ResolveBase.settings_of`: for `Upgrade` the strategy is `Highest` when no flag is given. `Upgrade.read`: a name with `@` is a usage failure (after the `lowest` check, before `roc`) |
| Files | New: `cli/lib/Upgrade.roc`, `cli/lib/Lags.roc` (they are in the stubs). `Lags` is separate from `Upgrade` because `Upgrade` imports `Resolve`, which imports `PickFlow` |

## 10. Changed old tests (TW21)

| Case | File | Change | Reason |
| --- | --- | --- | --- |
| `resolve/rs-new-toml` | `expect/stdout` (1 line) | `$PROJECT/talon.toml: json = "^2.2"` becomes `... json = "^2.2" (was "=2.2.0")` | Q6 (a): a toml line for a key that had another value ends with `(was "<old>")`. The case rewrites the key `=2.2.0` with `update json@...`. Copy of the old file: `research/slice-038-revert/before/tests/commands/cases/resolve/rs-new-toml/expect/stdout` |

No other old L2 or L3 case changes (the reference passed all 93 L2 cases and all L3 with the new line). The old L0 files `ranges.roc` and `vars.roc` got one new `expect` each (copies in `before/`).

## 11. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Baseline (before, `baseline-run.log`) | all pass: check 1.3, fmt 0.2, l0 7.5, l2 1.9, l3 9.9, selftest 10.8, l1 30.9 |
| Red (stubs, `red-run.log`, after `rm -rf .work/cache/roc/compat-*/objects-v7`, after the review) | l0: `ranges.roc` expect 3, `vars.roc` expect 7 (6 of 7 pass) and `upgrade.roc` (4 of 4) fail with `todo`. l2: `ug1-flow`, `ug2-lag`, `ug3-move` fail (`[ROC CRASHED] todo`), `resolve/rs-new-toml` fails on the new `(was "=2.2.0")` (a wrong value, Q6), the other 89 old cases pass. check, fmt, l3, selftest, l1 pass |
| Green (reference, `green-run.log`) | all steps pass in dev: check 1.1, fmt 0.1, l0 8.3, l2 8.2 (93 cases), l3 9.8, selftest 10.9, l1 25.6 (budgets 10, 5, 10, 30, 60, 20, 60). `OPT=speed` l2 and l3 pass too (`ref-run-speed.log`). The expected files of the 3 new cases come from the speed build |

Red-run fail output (the first lines of each):

```
tests/unit/ranges.roc: FAILED   Roc application crashed with this message:  todo
tests/unit/upgrade.roc: FAILED  Roc application crashed with this message:  todo   (3 expects)
tests/unit/vars.roc: 6 passed, 1 failed  (the Upgrade scope expect: todo)
FAIL upgrade/ug1-flow  the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL upgrade/ug2-lag   the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL upgrade/ug3-move  the test app wrote no exit file (exit 1): [ROC CRASHED] todo
commands: 90 passed, 3 failed
```

Revert check: 14 mutations at the first review and 4 more after it (M16 to M19) of the reference (`research/slice-038-revert/mutate.py`, logs `mutate-1.log`, `mutate-2.log`), filtered runs only. L0 is the 3 files; L2 is the 3 cases with a speed build, run only when L0 did not fail.

| Id | Mutation | Result |
| --- | --- | --- |
| M1 | an anchor is free when no name is given | caught (`vars.roc`) |
| M2 | a free variable keeps its ranges | caught (`vars.roc`) |
| M3 | a movable variable keeps its ranges | caught (`vars.roc`) |
| M4 | an anchor is not rewritten to `=<new>` | caught (`ranges.roc`, `upgrade.roc`) |
| M6 | a range that admits the version is rewritten | caught (`ranges.roc`) |
| M7 | 2 members under one file give 2 pairs for one key | caught (`upgrade.roc`) |
| M8 | the name form loses its name | caught (`upgrade.roc`) |
| M9 | a fail row of a module that the app does not use is a reason | caught (`upgrade.roc`) |
| M10 | a movable variable can be a lag | L0 has no second search, so a movable slot has its current value as the domain: the mutant is equal there. Caught by `ug3-move` |
| M11 | `update X@latest` does not rewrite the range | caught (`ug1-flow` run 8). The first form of the mutation made a warning, so it was done again |
| M12 | each move of `upgrade` ends with ` new series` | caught (`ug2-lag`, `ug3-move`) |
| M13 | `update` reports lags too | survived the first run. Run 3 of `ug2-lag` (`update`, no lag notes) was added, then caught |
| M14 | the lags are not in `notes` of `--json` | caught (`ug2-lag` run 2) |
| M15 | the scope of `upgrade` is the scope of `update` | caught (all 3 cases). The first form made a warning, so it was done again |

| M16 | a key with no form gets no note (Q1 b, review) | caught (`upgrade.roc`) |
| M17 | the toml line has no `(was ...)` (Q6 a, review) | caught (`rs-new-toml`, `ug1-flow`, `ug3-move`) |
| M18 | `upgrade` uses the strategy of the file (Q2 a, review) | caught (`ug1-flow` run 12) |
| M19 | `upgrade` accepts a selector (Q4 a, review) | caught (`upgrade.roc`) |

No mutant survives, except the equal mutant M10 at L0. M16 to M19 are from the review (`mutate-3.log`, dev build with a clean object cache). The reference was deleted at the review.

## 12. Files

| File | Lines | State |
| --- | --- | --- |
| `docs/slices/038-upgrade.md` | this file | new |
| `cli/lib/Upgrade.roc` | 32 | new, stub |
| `cli/lib/Lags.roc` | 50 | new, stub |
| `cli/lib/Ranges.roc`, `Vars.roc`, `ResolveBase.roc`, `PickFlow.roc`, `Run.roc`, `main.roc` | stubs and types | changed (copies in `research/slice-038-revert/before/`) |
| `tests/unit/upgrade.roc` | 277 | new |
| `tests/unit/ranges.roc`, `tests/unit/vars.roc` | +24, +77 | changed |
| `tests/commands/cases/upgrade/{ug1-flow,ug2-lag,ug3-move}/` | 12, 3, 2 runs | new |
| `research/slice-038-revert/` | | `before/`, `reference/`, `stubs/`, `gen-ug.py`, `mutate.py`, `crash-repro/`, logs |

## Review (manager, 2026-10-24)

Accepted, with 2 changes (Q1 and Q6). The answers:

| Id | Answer |
| --- | --- |
| Q1 | (b). A key whose range has no form of R-UP5 and does not admit the new version gets the note `talon.toml: <key>: the range does not admit <version>, change it by hand` (TW24 text), and the key stays. A silent key would make the next `update` fail with no reason. If the range still admits the new version, no note. Tests: `Lags.stuck` rows (L0), `ug1-flow` run 11 |
| Q2 | (a). `upgrade` ignores a config `strategy = "lowest"` and uses `Highest` (R-UP8 names the flag only). Test: `ug1-flow` run 12 |
| Q3 | (a). `[overrides]` keys are not rewritten |
| Q4 | (a). `upgrade X@sel` is a usage failure. Test: `upgrade.roc` expect 1 |
| Q5 | (a). Allowed: with a header that has no tuple, a variable can move down |
| Q6 | (a). Follow the example of Resolution 10: `(was "<old>")` on the toml line. Tests: `Lags.was` rows (L0), L2 toml lines. One old case changes (section 10) |
| Q7 | The lag text of section 3 is accepted as a proposal |
| D1 to D9 | Accepted, with the TW24 texts |
| Cache | The finding about the roc object cache (section 8, C1) is accepted. The manager starts a separate test-infrastructure task. `scripts/test.sh` and `tests/lib.sh` are not changed in this slice |

Test agent, after the review: the 2 changes and the answers Q2, Q4 are in the tests and the stubs (the reference had them, one hand mutation each: M16, M17, and M18, M19 for Q2 and Q4). The reference is deleted. The object cache was cleared (`rm -rf .work/cache/roc/compat-*/objects-v7`) before the red run, which is in `research/slice-038-revert/red-run.log`.

## Code result (code agent, 2026-10-24)

`scripts/test.sh` exits 0 (dev): check 1.1 s, fmt 0.1, l0 8.0 (budget 10), l2 2.7 (93 cases), l3 9.7, selftest 10.9, l1 30.5. `OPT=speed scripts/test.sh` exits 0 too (l0 9.4, l2 181.7 over budget for the known reason).

| File | Lines | What |
| --- | --- | --- |
| `cli/lib/Upgrade.roc` | 69 | `read` (checks 1 to 5 of the doc), `run!` (`Update.begin!`, `Update.resolve!` with `Upgrade`, `Update.print!`) |
| `cli/lib/Lags.roc` | 231 | `of`, `note`, `rewrites`, `stuck`, `was` |
| `cli/lib/Ranges.roc` | 86 | `rewrite` |
| `cli/lib/Vars.roc` | 302 | the arm `Upgrade` of `scoped_one` |
| `cli/lib/Pick.roc` | 443 | new `newest` (as section 9) and `newer` (a public name for `is_newer`, used by `Lags`) |
| `cli/lib/Update.roc` | 195 | `begin!`, `resolve!` and `print!` are now public methods (they were steps of the private `flow!` and a private `print!`); `request_of` takes the command. The behavior of `update` does not change |
| `cli/lib/ResolveBase.roc` | 351 | `new_series`, `settings_of` (`Upgrade` has `Highest` when no flag, Q2) |
| `cli/lib/PickFlow.roc` | 224 | the pick command `Upgrade`, `Lags.of` in `search!` for `Upgrade` only |
| `cli/lib/PickAsk.roc` | 229 | `request.command == Update` became `!= Install` (6 places: the scope, the entities, the lookup, the unmanaged entry, a new name, the name). The note said 3 |
| `cli/lib/InstallPlan.roc` | 304 | new `moves_of`, `upgrade_notes`, `marked`; `pre_lines` has the upgrade notes (a dropped tuple does not print them again) |
| `cli/lib/InstallFlow.roc` | 179 | ` new series` suffix, the `note:` lines after the platform notes, `Lags.rewrites` in the pairs, the notes in `Outcome.notes` |
| `cli/lib/InstallWrite.roc` | 171 | `(was "<old>")` from `Lags.was` (Q6) |

Decisions that the slice does not fix:

| Topic | Choice | Rejected |
| --- | --- | --- |
| Where `Upgrade.run!` gets the steps of `Update` | public `Update.begin!`, `Update.resolve!`, `Update.print!` (one source for both commands) | a copy of the steps in `Upgrade.roc` (the brief says reuse, no copy) |
| Moves for the rewrite (`InstallPlan.moves_of`) | only the uses whose URL changes. `update`: the aliases named with `@latest` | the uses of a variable that stays (a stale key of a variable at its newest release is not rewritten) |
| `Lags.of` slots | `ready.input.slots` of the first search. A held or movable slot is never a lag, so the second search needs none | the slots of the second search |
| A move is `Set` (not `Replace`) | the same op as `update X@sel` (R-UP3 "replace under the same alias" is the result: the warning R-C8 comes from the closure notes) | `Replace` (only for an unmanaged value) |

No test, fixture or expected file was changed (no dispute rows). No compiler bug found. The limits of section 8 were met only as noted there (nested `match` in `Lags.first_ok`, `Ok({ opts: opts })`).

## Verify results (code agent)

Revert check (TW12), filtered runs only: `research/slice-038-revert/agent-mutate.py`, results in `agent-results.md`, log `agent-mutate.log`. Caught 9 of 10. After the run `sha256sum -c research/slice-038-revert/code-final.sha256` is 12 of 12 OK.

| Id | Mutation | Result |
| --- | --- | --- |
| A1 | an anchor is free when no name is given | caught (`vars.roc`) |
| A2 | a movable variable keeps its ranges | caught (`vars.roc`) |
| A3 | the wildcard end is lost | caught (`ranges.roc`, `upgrade.roc`) |
| A4 | a fail row of an unused module is a reason | caught (`upgrade.roc`) |
| A5 | 2 members under one file give 2 pairs | caught (`upgrade.roc`) |
| A6 | `update X@latest` does not rewrite the range | caught (`ug1-flow` run 8) |
| A7 | ` new series` on the wrong lines | caught (`ug1-flow`, `ug2-lag`, `ug3-move`) |
| A8 | `update` reports lags | caught (`rs-new-toml`, `ug1-flow`, `ug2-lag`) |
| A9 | `upgrade` uses the strategy of the file | caught (`ug1-flow` run 12) |
| A10 | `(was ...)` when the new value equals the old value | closed by the gap test (section "Gap tests"): `ug1-flow` run 13. Hand mutation A10: the run fails with `json = "^2.1" (was "^2.1")`. |

## Gap tests (test agent, 2026-10-24)

| Gap | Test | Check |
| --- | --- | --- |
| A10: `InstallWrite.was_text` prints `(was "<old>")` when the new value equals the old value | `upgrade/ug1-flow` run 13: `update json@^2.1 parser@^1` over `json = "^2.1"` and `parser = "=1.0.0"`. The key of json gets the value that it has already. The key of parser changes, so the file is written and both lines print (a toml line prints only for a changed file, so one equal key alone shows no line). Expected: `json = "^2.1"` with no suffix, and `parser = "^1" (was "=1.0.0")`. Rule text in `ug1-rules.txt` and the case `rules`; the expected files of the other 12 runs did not change | A10 applied by hand (`old == p.value` becomes `old == "-"`, `--no-cache` dev build): the case fails with `+json = "^2.1" (was "^2.1")`. Restored from `code-final/`: `sha256sum -c code-final.sha256` is OK for each file, `scripts/test.sh` exits 0 (check 1.1, fmt 0.1, l0 7.7, l2 3.2, l3 9.7, selftest 10.8, l1 30.9) |

Only tests and this file were edited: `tests/commands/cases/upgrade/ug1-flow/` (the new project `p11`, the run, the rules) and `research/slice-038-revert/gen-ug.py`, `ug1-rules.txt`.

## Close (manager, 2026-10-24)

The code decisions are accepted (Upgrade reuses the public steps of Update; Pick.newer; the moves of the rewrite; the upgrade notes in `pre_lines`). The code agent ran 10 targeted mutations: 9 caught, A10 closed by `ug1-flow` run 13. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 7.7 s). The roc object cache bug found in this slice is fixed in the test scripts (`--no-cache`, research/roc-object-cache/). Status: done.
