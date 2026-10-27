# 086 The project settings in the compiler pick of R-SO14 (`tln path`, `install --frozen`)

Phase: P1. Status: green (code agent, 2026-10-27). Was: review (test agent, 2026-10-27). The user approved the first case and the findings; the review asked for 2 more cases (findings 1 and 3) and approved the reading of R-C15 for `--frozen`.

Slice 086 closes a gap of slice 084 (section 10, "Q-C1 code", the `PathFlow.roc` row): `tln path <alias>` gives the R-SO14 pick `exclude: []` (`cli/lib/PathFlow.roc:80-82`), so the list of `[resolution]` of the project does not reach the pick. No test covered it. The test agent also checked the `min-release-age` value of that pick (R-C7 sources), because R-C15 says that the list applies with the same sources. The review extended the scope: the project `min-release-age` in the R-SO14 pick of a command that uses `ResolveBase.no_rank` (`install --frozen`), and the project `nightly` switch (R-NS9) in the R-SO14 pick.

## 1. What the design says

| Point | Rule | Text (short) |
| --- | --- | --- |
| `tln path` uses a project | R-PD14, R-PTH4 (`DESIGN-CLI.md:206`, `:456`) | `path` is in the list of the commands that use a project. |
| It fetches as `install --frozen` | R-PTH2 (`DESIGN-CLI.md:454`), R-LF1 (`DESIGN-RESOLUTION.md:667`), R-FE4 (`DESIGN-CLI.md:1447`) | With no compiler installed, the fetch uses R-SO14: "a compiler that suits the project of the command". |
| The pick of R-SO14 uses the lists of the command | R-C15, last row (`DESIGN-RESOLUTION.md:114`) | "the latest in the channel ... for R-SO14": "The lists that the command has for `min-release-age`". |
| The two lists are joined | R-C14 (`DESIGN-RESOLUTION.md:96-103`) | The union of `config.toml` and `[resolution]` of `talon.toml`. "A command with no project in scope reads `config.toml` only". `path` has a project in scope. |
| The age of a project | R-C7 (`DESIGN-RESOLUTION.md:69`), R-LY4 (`DESIGN-CLI.md:928`) | Sources, from high to low: `talon.toml` `[resolution]`, `config.toml`, the default `2d`. "Both also apply where Talon selects a compiler by itself (R-NS3)". |
| The note | R-C16 (`DESIGN-RESOLUTION.md:129-133`) | "the pick of R-SO14" gets the note. |
| The channel of the pick is the `nightly` switch | R-SO14 (`DESIGN-RESOLUTION.md:707`), R-SO15 (`:709`), R-NS8 to R-NS11 (`:42-45`) | R-SO14 picks "the newest compiler in the channel". R-SO15: "The channel is the `nightly` switch (R-NS8 to R-NS11)". Sources: environment, then `talon.toml` `[toolchain] nightly`, then `config.toml`, then `true`. |
| The switch off | R-NS2 (`DESIGN-RESOLUTION.md:50`) | The domain is the releases only. Talon knows no release source, so "a command that must select a compiler stops with exit code 10 (`no_tuple`), and the error names the switch and its source". |

Result: the design is clear. The pick of R-SO14 in a project command (`tln path`, `install --frozen` and the other users of `ResolveBase.no_rank`) uses the joined list (project and `config.toml`), the `min-release-age` of the project `talon.toml` before the one of `config.toml`, and the `nightly` switch of the project `talon.toml` before the one of `config.toml`. No TW17 question.

Reading, approved by the user at the review (2026-10-27), also recorded in `DESIGN-GAPS-2026-10-27.md` (C2, Q8): R-C15 "The list does not change these rules" names `tln install --frozen` ("They make no list call and no choice"). This row is for the packages only: `--frozen` resolves nothing. The compiler pick of R-SO14 in a `--frozen` fetch is a list call and a choice, and the last row of the R-C15 place table and the R-C16 table name it. `tln install --frozen` already passes the project list today (`ResolveBase.no_rank`, `cli/lib/ResolveBase.roc:105`).

`tln path` already reads the `talon.toml` of the project: `Project.find!` reads each `talon.toml` of the walk (`cli/lib/Project.roc:158`, the `toml` field of `Project`). The comment of `PathFlow.roc:80` ("`tln path` reads no `talon.toml`") is not correct. The new case shows the read (`read_files $PROJECT/p1/talon.toml`) in its `calls.log`. The code needs no new `Fx` call.

## 2. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-PTH2, R-FE4, R-SO14, R-SO23 | `tln path` of a missing release, nothing installed: Talon picks a compiler (the latest in the channel when no hash has a fact), downloads it, makes it the default and runs `roc unbundle` with it. | L2 `path/pt2-exclude` runs 1 to 3 |
| R-C14, R-C15 | The list of `[resolution]` of the project reaches the pick. | L2 `path/pt2-exclude` run 1 |
| R-C7, R-LY4 | The `min-release-age` of the project `talon.toml` replaces `config.toml` (and the default) for the pick. | L2 `path/pt2-exclude` run 3 |
| R-C16 | The note when only a pattern keeps the young nightly. No note with `0d`. | L2 `path/pt2-exclude` runs 1 and 3, `closure/cl4-frozen-age` run 1 |
| R-C7, R-LY4, R-LF1 (finding 1) | The same for `install --frozen` (`ResolveBase.no_rank`, then `NoRank.offer!`): the project `min-release-age = "0d"` lets the pick take the young nightly. | L2 `closure/cl4-frozen-age` |
| R-NS9, R-NS2, R-NS8, R-SO15 (finding 3) | The project `[toolchain] nightly = false` empties the channel of the pick: exit 10 that names the switch and its source. `TALON_NIGHTLY=1` has priority over it. | L2 `path/pt3-nightly-switch` |

## 3. Tests

| Layer | Case | What | Rule ids |
| --- | --- | --- | --- |
| L2 | `tests/commands/cases/path/pt2-exclude` (new, entry `commands`, 3 runs, one home each) | TALON_NOW 2026-10-20T15:00:00Z. The list of nightlies of `norank/nr2-exclude`: N4 `nightly-2026-10-19-0badf00` is 1 day old, N3 `nightly-2026-10-18-5349569` is exactly 2 days old. The projects p1, p2, p3 have the header of `closure/cl3-frozen-none` p1 (the platform pfx and the package core). `tln path core` with `TALON_AUTO_INSTALL=yes`. No `compat.db` fact for the hashes. Run 1: p1 `talon.toml` has `[resolution] min-release-age-exclude = ["roc-lang/nightlies"]`, no `config.toml`: N4, the note on stderr before the download line, the default, `roc unbundle` with N4. Run 2 (control): p2 has no `talon.toml`: N3, no note. Run 3: p3 `talon.toml` has `[resolution] min-release-age = "0d"`, no `config.toml`: N4, no note. | R-PTH2, R-SO14, R-SO23, R-FE4, R-C7, R-C14, R-C15, R-C16, R-NS3, R-PD14 |
| L2 | `tests/commands/cases/closure/cl4-frozen-age` (new, 2 runs, one home each; review, finding 1) | The world of `closure/cl3-frozen-none` (p1: the platform pfx and the package core, no pin, nothing in the cache, `--allow-downloads`) with the 4 nightlies of `norank/nr2-exclude`, no fact, TALON_NOW 2026-10-20T15:00:00Z. Run 1: p1 `talon.toml` has `[resolution] min-release-age = "0d"`, no `config.toml`: N4 is downloaded, it becomes `default-roc`, both unbundles use it, `the header satisfies talon.toml`, no note. Run 2 (control): p2 has no `talon.toml`: N3. | R-SO14, R-SO23, R-C7, R-LY4, R-C15, R-C16, R-LF1, R-FE4, R-NS3 |
| L2 | `tests/commands/cases/path/pt3-nightly-switch` (new, 2 runs, one home each; review, finding 3) | The world of `path/pt2-exclude`. Run 1: p1 `talon.toml` has `[toolchain] nightly = false`, no `config.toml`: exit 10, `tln: error[no_tuple]: no compiler release is known, and nightly is false (set by [toolchain] nightly in talon.toml)`. The list of nightlies is read, then nothing is downloaded, no default is written, core is not fetched. Run 2 (control): the same project with `TALON_NIGHTLY=1` (R-NS8 has priority): N3, the download, the default. | R-NS9, R-NS8, R-NS2, R-NS11, R-SO14, R-SO15, R-PTH2, R-FE4 |

How the expected files were made (the same method for the 3 cases): the test agent ran the case with the current code and a world that is green today (the list in `config.toml` of `home`, `min-release-age = "0d"` in `config.toml` of `home3`, and a `talon.toml` with only a comment in p1 and p3, so the `Fx` calls are the same). `UPDATE=1` wrote the expected files. Then the values moved to the project `talon.toml` files, and the one change of `expect/tree.diff` was made by hand: `config.toml` of `home` is a new file with only `default-roc`. `calls.log` does not change: `config.toml` is read in both worlds, and a read of a missing file is the same call. `cl4-frozen-age`: `min-release-age = "0d"` in `config.toml` of `home`, then moved to p1 `talon.toml` (the same one-hunk change of `tree.diff`). `pt3-nightly-switch`: `nightly = false` in `config.toml` of `home`, then moved to p1 `talon.toml`; the source text of the error changed by hand from `nightly in config.toml` to `[toolchain] nightly in talon.toml` (the text of `Pin.source_text` for `Toml`, `cli/lib/Pin.roc:237`, a proposal, R-OUT2). `config.toml` is not written in that run, so `tree.diff` does not change.

No edit of an old test.

## 4. Red output (test agent, 2026-10-27)

`tests/commands/run.sh path/ closure/` (the `l2` app built from the current code): `commands: 4 passed, 3 failed` (`path/pt1-entry` and the 3 old `closure/` cases pass).

```text
FAIL path/pt2-exclude
  stderr differs: expected `note: nightly-2026-10-19-0badf00 is 1d old (min-release-age 2d), not hidden by min-release-age-exclude: roc-lang/nightlies` and `downloading nightly-2026-10-19-0badf00`; actual `downloading nightly-2026-10-18-5349569` in runs 1 and 3
  Fx calls differ: the lock, the download, the extract and the `roc unbundle` use nightly-2026-10-18-5349569
```

Runs 1 and 3 fail for the right reason (the age hides N4: the project list and the project age do not reach the pick). Run 2 passes.

```text
FAIL closure/cl4-frozen-age
  stderr: -downloading nightly-2026-10-19-0badf00 (73.0 MB), the default compiler
          +downloading nightly-2026-10-18-5349569 (73.0 MB), the default compiler   (run 1)
FAIL path/pt3-nightly-switch
  stdout: -exit 10   +exit 0   (run 1)
  stderr: -tln: error[no_tuple]: no compiler release is known, and nightly is false (set by [toolchain] nightly in talon.toml)
          +downloading nightly-2026-10-18-5349569 (73.0 MB), the default compiler
```

`cl4-frozen-age` run 1 fails because `NoRank.offer!` takes `min_age` from `config.toml` only. `pt3-nightly-switch` run 1 fails because `NoRank.offer!` gives `Pin.switch` no `talon.toml` value (`toml: Err(Unset)`), so the switch stays on. The control runs pass.

## 5. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `cli/lib/PathFlow.roc:80-82` | Pass the `[resolution]` list of the project `talon.toml` (the text is in `start.project.toml`, no new `Fx` call). A bad pattern is exit 19 (R-C13), as in the other project commands. |
| 2 | `cli/lib/NoRank.roc:116` (`offer!`) | `min_age` reads `config.toml` only today, for every command. R-C7: the project value comes first. This change also changes the R-SO14 pick of `install`, `outdated`, `list`, `why`, `patch`, `verify`, `remove` (their `ResolveBase.no_rank`) and of the proxy. Tests: `path/pt2-exclude` run 3, `closure/cl4-frozen-age` run 1. |
| 2b | `cli/lib/NoRank.roc:109` (`offer!`) | `Pin.switch` gets `toml: Err(Unset)`. R-NS9: the `[toolchain] nightly` of the project `talon.toml` comes after the environment and before `config.toml`. Test: `path/pt3-nightly-switch` run 1. The same change reaches the other users of `ResolveBase.no_rank` and the proxy. |
| 3 | The L2 harness | `tests/commands/L2NoRank.roc` and `tests/commands/main.roc` build `NoRank.Run` as a record literal `{ scope, exclude, downloads }`. A new required field (the project age, the project switch) breaks their compile, and the code agent must not edit tests (TW18). A field with a default value (`?? ...`), or another way to pass the age and the switch, keeps them as they are. |

## 6. Output (proposed, TW24)

No new text. The note is the R-C16 text of slice 084, on stderr, as `norank/nr2-exclude` prints it. The exit 10 error of `pt3-nightly-switch` is the existing text of `Toolchain.pick_failed` (`cli/lib/Toolchain.roc:170`) with the existing source text `[toolchain] nightly in talon.toml` (`Pin.source_text`): a proposal (R-OUT2), for the human to accept.

## 7. Out of scope (found, not tested)

| Item | Why |
| --- | --- |
| The project switch and the project age in the other users of `ResolveBase.no_rank` (`outdated`, `list`, `why`, `patch`, `verify`, `remove`) and the proxy | Changes 2 and 2b of section 5 reach them. One case for each finding is in this slice, as the review asked. |
| A workspace (R-WS5: the list of the root `talon.toml`) | The `toml` field of `Project` comes from `nearest_toml` for a member (`cli/lib/Project.roc:123-127`). The test agent did not check that it is the root file. One more run can follow if the review asks. |

## 8. Questions (TW17)

None.

## 9. Disputes (from the code agent)

## 10. Verify results

Code agent, 2026-10-27. No edit under `tests/`.

| # | File | Change |
| --- | --- | --- |
| 1 | `cli/lib/NoRank.roc:38-45` | `Run` gets the optional field `toml ?: NoRank.Toml` (`{ min_age, nightly }`, both `Try(_, [Unset])`) and `no_toml`. An optional field, so the record literals of `tests/commands/L2NoRank.roc` and `tests/commands/main.roc` compile as they are (a `??` default is only allowed on a nominal record). |
| 2 | `cli/lib/NoRank.roc:119`, `:126` (`offer!`) | The switch is `Pin.switch` with `toml: run.toml.nightly` (R-NS9). The age is `Setting.pick` with `project: run.toml.min_age` before `config.toml` (R-C7, R-LY4). `ensure!` (`:171`) passes `run.?toml ?? no_toml`; `pick_id!` gets a `toml` field. |
| 3 | `cli/lib/ResolveBase.roc:106` (`no_rank`) | `toml` is `[resolution] min-release-age` and `[toolchain] nightly` of `loaded.intent`, next to the list that was there. All users of `no_rank` get it. |
| 4 | `cli/lib/HeldRoc.roc:32` | `pick_id!` gets `run.?toml`. |
| 5 | `cli/lib/Project.roc:163-174`, `:283-320` | `find!` and `find_loose!` use the new private `search!`, which also gives the text of the `talon.toml` of the project from the read of the walk (`toml_text`). New `find_text!`. No new `Fx` call. |
| 6 | `cli/lib/Install.roc:72-96` | New `begin_toml!` (`begin!` plus that text). `begin!` keeps its type. `begin_loose!` gets a field `found`. |
| 7 | `cli/lib/PathFlow.roc:59`, `:71`, `:83-85`, `:94-108` | `project_toml`: `Intent.read` of that text (role `Member` for a member `talon.toml` of a workspace, as `ResolveLoad`), only for a release entry. It gives the list, the age and the switch to `Download`. A file that is not valid is exit 19. Warnings of `Intent.read` are not printed (as the proxy). The wrong comment is replaced. |
| 8 | `cli/lib/Base.roc:284`, `:352-366`; `cli/lib/Proxy.roc:290` | Proxy: `read_toml` also gives `[resolution] min-release-age`, and `Loaded.min_age` is project, then `config.toml`, then 2d (R-C7). `picked!` passes `toml: { min_age: Ok(loaded.min_age), nightly: loaded.toml_nightly }`. Note: `Loaded.min_age` is also the age of `ranged!` (R-SO13), so the proxy range pick now uses the project age too. No test covers the proxy part. |

| Check | Result |
| --- | --- |
| L2 filtered `tests/commands/run.sh path/ closure/ norank/` | 9 passed, 0 failed (`pt2-exclude`, `pt3-nightly-switch`, `cl4-frozen-age` green) |
| Full suite `scripts/test.sh`, default locale (`en_US.UTF-8`) and `LC_ALL=C` | Both exit 0: check, fmt, l0, l1, l2 (237 passed), l3 (88 passed), selftest pass. l0 11 to 12 s: WARN over the budget of 10 s (as in 081 to 085), not a failure. |

Revert check: 6 of 6 caught. Script and results: `research/slice-086-revert/mutate.py`, `results.txt` (no binaries).

| No | Mutation | Result |
| --- | --- | --- |
| m1 | `offer!` ignores the project age (`project: Err(Unset)`) | L2 `pt2-exclude`, `cl4-frozen-age` |
| m2 | `offer!` ignores the project switch (`toml: Err(Unset)`) | L2 `pt3-nightly-switch` |
| m3 | `PathFlow.project_toml` gives `exclude: []` | L2 `pt2-exclude` |
| m4 | `Project.toml_text` never finds the text | L2 `pt2-exclude`, `pt3-nightly-switch` |
| m5 | `ResolveBase.no_rank` drops the project age | L2 `cl4-frozen-age` |
| m6 | `ensure!` drops `run.toml` | L2 `pt2-exclude`, `pt3-nightly-switch`, `cl4-frozen-age` |

Not covered by a test (out of scope, section 7): the switch through `ResolveBase.no_rank` (only the age has a case), the proxy (`Proxy.picked!`, and `ranged!` through `Base.Loaded.min_age`), the role of a workspace member `talon.toml` in `path`.
