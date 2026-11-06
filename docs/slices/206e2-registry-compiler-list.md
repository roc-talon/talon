# 206e2 Registry compiler list in the resolve commands

Phase: P2 (CLI client). Status: done (closed 2026-11-03). D1 and D2 go to plan row 206e2b.

Plan row 206e2 of `PLAN-P2-CLI.md`. Sub-slice 2 of the 206e split. It uses the registry list of slice 204 (`Nightlies.list_registry!`) and the query step of slices 206b, 206d, 206d2, 206e.

## Rules

R-CV1, R-AP16 (`compilers`, `groups` of `tln outdated`), R-AP74 (row 4) (CLI 6.2, 7.3; Registry 4.1), Design Q460. As used: R-CV3, R-CV5, R-CV6, R-IX4, R-AP19, R-AP80, R-UP1, R-UP6, R-SO14, R-SO19, R-SO22 to R-SO24, R-CM6, R-DI1, R-NS2, R-DT3, R-DT5, R-AP28, R-SP16, R-SP23, R-SP24, R-E7.

## Scope

| In | Out (where) |
| --- | --- |
| `Opts.reads_registry`: no P0 refusal for `upgrade` with a free nightly (no names, `roc`, `X roc`) and for `outdated` | `install <names>`, `install --frozen`: 206f. `init` (it runs the flow of `upgrade`): stays `Off` (plan note P2) |
| `upgrade` with a free nightly: `NightlyFlow` reads the registry list, the window of the query is `Free` (R-AP16) | `tln roc ...`, the proxy, `tln tool`, `tln setup`, `tln probe`: other command lines, not in the plan row |
| Each other compiler list read of a registry run: `HeldRoc.picked!` (`NoRank.offer!`), `RocInstall.offer!` (from `NightlyFlow` and from `Start` at the first probe), `PickLoop.releases!` (the domain D). One read for the command (R-IX4) | The evidence of the answer in the probes (`read_all!`, `hinted!`, `Matrix`): 206e3 |
| `.talon.json` of a compiler from a registry row: `sha256_source` `registry` (R-CV5) | The facts of the `nightly range` column of `outdated` from the answer (`runs`): 206e3 (plan note P1) |
| `outdated` (`OutdatedFlow`): the setting, the registry list before the query, the query with the groups of the rows and the `Report` window, the index from the answer | Index notes in `outdated` (R-AP30): 206e4 |
| Q460: an L2 case with an R-AP28 ingest and a held move | |

## Flow as read

### `tln upgrade` with a free nightly, with a registry

| Step | Call | Rule |
| --- | --- | --- |
| 1 | The load, the setting (`InstallFlow.with_setting`): `Read` | R-RG1 |
| 2 | `NightlyFlow.plan!`: the list is `Nightlies.list_registry!` (`GET /v1/toolchains?after=<largest>`, `toolchains.json`, the pins with source `registry`). `log:N` hides the rows above N (R-AP19) | R-CV1, R-IX4, R-DT3 |
| 3 | The offer and the download of N: the release of the registry row (URL from the tag and the asset name, `size`, `sha256`, R-AP80, R-CV3). No second list read in the command | R-CV1, R-IX4, R-CV5 |
| 4 | The query: `compilers` is the `Free` window (`ClosureRequest.Free`): the oldest and the newest compiler that the switch, the `[toolchain] roc` range, `min-release-age` and the snapshot allow | R-AP16 |
| 5 | The rest as `upgrade <names>` (206e) | |

### `tln install`, `update`, `upgrade` with no compiler selected, with a registry

`HeldRoc.picked!` picks the id from the registry list (R-SO23). The window of the query is that id (`Held`). At the first probe, `Start` offers the download from the same rows (R-SO22). The domain D of the oracle loop (`PickLoop.releases!`) is the same list. The command sends one `GET /v1/toolchains` (R-IX4: "each command that needs the compiler list sends one read").

### `tln outdated` with a registry

| Step | Call | Rule |
| --- | --- | --- |
| 1 | The load, the setting (`--registry`, `TALON_REGISTRY`, `config.toml`) | R-RG1 |
| 2 | The registry list, before the query. Also when no row is behind: the window needs it | R-CV1, R-AP16 |
| 3 | The guard (`IndexQuery.sources`), then one closure query: `groups` = `IndexQuery.report_groups` of the shown variables, `hashes` of the header, `compilers` = `Report` window (no member when no compiler is allowed: no stop, R-AP74 row 4) | R-AP16, R-AP74, R-RG4 |
| 4 | `PickIndex.index!` with the `Answer` index (no GitHub release list). The `range` column uses the registry list as D | R-DI1, R-CM6 |

## Reading that the tests fix

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Groups of `outdated` | Registry R-AP16 lists "the rows of `tln outdated`" in `groups`. The `latest` column is every series with no range (`Outdated.versions`, R-UP1), and R-AP16 says: no `series` is all series, no `range` is every release ("where R-UP1 says that the range does not apply"). So each group has no `series` and no `range`. `wanted` is computed by the client from the same list. Plan note P2 of 206e is checked: it agrees with the design |
| 2 | The list before the query in `outdated` | The window of R-AP16 needs the list, so the list is read before the query in each registry run, not only when a row is behind |
| 3 | One list read | R-IX4 (Design Q222): one read with `after=<largest>` for each command. The offers and the domain use the rows of that read |
| 4 | `Free` window ends | R-AP16 text: the allowed compilers, not only the compilers at or above H. In `cv1-upgrade-free` run 1 the window is 2026-10-12 .. 2026-10-16 (H is 2026-10-14) |
| 5 | Two series of one form in `outdated` | One group text is sent once (a repeated group adds nothing to the answer) |
| 6 | Q460 | The second query of a held move after an R-AP28 case 2 ingest is hidden above the `log_size` of the answer of `settle!`, and that size is printed |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/UpgradeTest.roc` (driver `l0-1.roc`), changed expect: `upgrade`, `upgrade roc`, `upgrade json roc` take a registry URL | R-FL5, R-RG1, R-CV1, R-AP16, R-UP6 |
| L0 | `tests/unit/OutdatedTest.roc` (driver `l0-1.roc`), changed expect: `outdated --registry <url>` passes; with a name the failure is `takes no name` | R-FL5, R-RG1, R-CV1, R-AP16 |
| L0 | `tests/unit/IndexqueryTest.roc` (driver `l0-6.roc`), 2 new expects: `IndexQuery.report_groups` (indexed and named only, order of the variables, no series, no range, one group for each form); no variable gives `[]` | R-AP16, R-CM6, R-UP1, R-DI1, R-DI11, R-AP74 |
| L2 | `registry/cv1-upgrade-free` (new, 2 runs, `rules` has the detail) | R-CV1, R-CV3, R-CV5, R-CV6, R-IX4, R-AP16, R-AP19, R-AP74, R-UP6, R-DT3, R-DT5 |
| L2 | `registry/cv1-held-pick` (new, 1 run) | R-CV1, R-CV3, R-CV5, R-IX4, R-SO14, R-SO19, R-SO22 to R-SO24, R-AP16 |
| L2 | `registry/cv1-outdated-query` (new, 2 runs) | R-CV1, R-CM6, R-AP16, R-AP74, R-DI1, R-UP1, R-NS2, R-RG4, R-E7 |
| L2 | `registry/sp24-ingest-held-move` (new, 1 run, Q460) | R-AP28, R-AP16, R-SP16, R-SP23, R-SP24, R-AP19, R-DT5 |
| L2 | `registry/cv1-upgrade-unread` (new, round 2, Design Q489, 2 runs): bare `upgrade` with a registry list that cannot be read (404): the note `the compiler list could not be read; roc stays <H>`, the `Held` window, the packages upgrade, exit 0; `upgrade roc`: exit 15 with the failure of the list, no query | R-CV1, R-AP74, R-UP6, R-AP16, R-E6 |
| L2 | `registry/ix6-offline-range` (changed, round 2, Q489): exit 15, `tln: error[network]: no cached list of compilers and --offline is set` (was exit 10, the `ClosureRequest.no_compiler` text). Calls and tree unchanged | R-IX6, R-AP74 |
| L2 | `registry/al2-upgrade-query` (changed): run 4 (`upgrade` with no names stays direct) removed; `cv1-upgrade-free` replaces it. Runs 1 to 3 unchanged (checked with `diff`) | |

The fixtures are made by `research/slice-206e2-revert/mkcases.py`. The expect files came from a run of a private reference, then each line was read against the rules. One change by hand: the `.talon.json` line of the 2 cases with a download has `"sha256_source":"registry"` (R-CV5); the reference wrote `github-digest`.

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `l0-1.roc` | 2 fail: `UpgradeTest`, `OutdatedTest` (the P0 refusal) |
| `l0-6.roc` | 2 fail: the 2 `report_groups` expects (`todo: slice 206e2`) |
| `l0-7.roc` | Only `ShareaccountTest` (slice 220, another agent) |
| `tests/commands/run.sh` | Fail: `cv1-upgrade-free`, `cv1-held-pick`, `cv1-outdated-query` (the runs go direct: GitHub lists, no POST or no `Free`/`Report` window), and `share/sh33` to `sh39` (slice 220). `sp24-ingest-held-move` already passes: the code of 206d2 keeps Q460 by the rule |
| `l3` | pass |
| `MISSING=1 scripts/rules.sh R-CV1 R-AP16 R-AP74 R-CV5 R-IX4` | none missing |

## Expected exits (read, TW21)

| Case | Runs |
| --- | --- |
| `cv1-upgrade-free` | 0 (pin moves to 2026-10-16, stderr `downloading nightly-2026-10-16-5e6f7a8 (1.0 KB)`), 0 (`nothing to change`) |
| `cv1-held-pick` | 0 (moves, `+ roc: nightly-2026-10-13-5e6f7a8`, the download line on stderr) |
| `cv1-outdated-query` | 0, 0 (R-E7) |
| `sp24-ingest-held-move` | 0 (`~ pf ... (held)`, `resolved at log:52`) |
| `al2-upgrade-query` | 0, 0, 0 |

`tree.diff`: `projects.json`, `toolchains.json`, the pins of `compat.tsv` with source `registry`, the installed compiler (and `default-roc` in `config.toml`, R-SO24), the kept guard answer of `acme/parser`.

## Code shape

| Name | Kind | State |
| --- | --- | --- |
| `IndexQuery.report_groups : List(Vars.Var) -> List(ClosureRequest.Group)` | Pure, new | Stub `crash "todo: slice 206e2"` |
| `Opts.reads_registry`, `Update.request_of` (`init` stays `Off`), `NightlyFlow`, `HeldRoc.picked!` / `NoRank.offer!`, `RocInstall.offer!`, `Start`, `PickLoop.releases!`, `InstallFlow.resolve!` / `PickFlow.query!` (the `Free` window), `OutdatedFlow`, `Toolchain.meta` (the source) | Command code | Code agent |

## Revert check

`research/slice-206e2-revert/`: `before/` (the code files and the changed test files before the slice, and `al2-upgrade-query`), `mkcases.py`. No mutation run was made in this step (see Doubts).

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| All lines of the new cases | The texts of `direct` and of 206e. No new text and no new `--json` field |
| `.talon.json` | `sha256_source` `registry` (the word of R-CV5) |

## Out of scope

`init` with a registry, the other command lines of the scope table, the evidence of the answer (206e3), the index notes and the share hooks (206e4).

## Questions (stop until answered)

| # | Question |
| --- | --- |
| Q1 | `tln upgrade` with no names and a registry, when the registry list cannot be read (an error answer, or `--offline` with no `toolchains.json`): does the nightly stay H with the note `the compiler list could not be read; roc stays <H>` and a `Held` window (as `direct`, Q1 of slice 039), or does the command stop with exit 10 (R-AP74 row 4 "the compiler list is empty", Design Q467 "exit 10 if a compiler must be chosen")? `upgrade roc` already fails when the list cannot be read. No test fixes it. |
| Answer | (a) (Design Q489, Registry R-AP74 row 4): the nightly stays H, the note, a `Held` window, as `direct`. Test change: add an L2 case: `upgrade` with a registry and an error answer for `GET /v1/toolchains` (and one `--offline` with no `toolchains.json`): exit 0, the note in stdout and `data.notes`, `roc:` unchanged, the packages upgrade; and `upgrade roc` with the same: exit 15 with the failure of the list. The text of the note is the one of slice 039 |

Plan notes for the manager (not design questions):

| # | Point |
| --- | --- |
| P1 | The `nightly range` column of `outdated` reads its facts from `compat.db` (as before). The `runs` of the answer as its evidence belong with 206e3 |
| P2 | `init` runs the flow of `upgrade`: it keeps `registry: Off` in this slice (it was not in the row). A later row decides it |
| P3 | `PickLoop.releases!` from `held_nightly!` (`upgrade X` with a held move of the nightly) has no own case; `cv1-held-pick` covers the `wide!` path |

## Code

| File | Change |
| --- | --- |
| `cli/lib/IndexQuery.roc` | `report_groups`: one group for each `Indexed` variable with a name, in order, each URL form once, no `series`, no `range` |
| `cli/lib/Opts.roc` | `reads_registry`: `upgrade` (any operands) and `outdated` pass. `init`, `install <names>`, `install --frozen` keep the P0 text |
| `cli/lib/Update.roc` | `request_of`: `registry: Setting(args.registry)` for each line. `resolve!`: `init` (`fresh`) sets `Off` (plan note P2) |
| `cli/lib/Nightlies.roc` | New `Source` (`Direct`, `Registry({ origin, version, log, kept })`), `list_of!` (`list!` or `list_registry!`; `kept` reads the kept file only, no request) and `digest_source` (R-CV5) |
| `cli/lib/ResolveBase.roc` | `Query`: `pin` is replaced by `window : ClosureRequest.Window`, new `listed : Bool`. New `list_first`, `list_later`, `listed`, `compiler_domain` (the domain of a `Free` or `Report` window). `ladder_downloads` sets `list: list_later(request)` |
| `cli/lib/InstallFlow.roc` | `with_setting`: `window: None, listed: false`. `picked!` gives the request back as `listed` after `HeldRoc.picked!`. `run!`: a range pick of `prepared!` that read the registry list makes the request `listed`. `resolve!`: the window is `Free` (the plan read a list that is not empty), else `Held(H)`; `listed` after the plan read |
| `cli/lib/NightlyFlow.roc` | `listed!` uses `list_of!` with `list_first`. `offers!` passes the kept registry list (no second request) |
| `cli/lib/HeldRoc.roc`, `cli/lib/NoRank.roc` | `picked!` passes `list_first` to `NoRank.pick_id!`. `NoRank.offer!` and `pick_id!` take `list ?: Nightlies.Source` (left out: `Direct`) and set the source of the `.talon.json` |
| `cli/lib/RocInstall.roc` | `offer!`, `offer_noted!`, `fetch_optional!` take `list ?: Nightlies.Source`. `Ctx.source` goes to `Toolchain.meta_from`. `range_id!` (Q489): a `Missing` registry list is `Toolchain.offline_no_list` (exit 15); exit 10 stays for a list that was read and is empty |
| `cli/lib/Toolchain.roc` | New `meta_from(facts, source)`: `sha256_source` is `github-digest` or `registry`. `meta` is `meta_from(facts, GithubDigest)` (its record type stays: `ToolchainTest` binds it) |
| `cli/lib/Start.roc` | `Downloads` has `list ?: Nightlies.Source`. The offer of the first probe uses it |
| `cli/lib/PickLoop.roc` | `releases!` uses `list_later`. New `first_releases!` (`list_first`, for `outdated`) |
| `cli/lib/PickOptional.roc` | `fetch!` passes `list_later` to `fetch_optional!` |
| `cli/lib/PickFlow.roc` | `query!` takes the groups and uses `query.window`. New public `report_query!` (the guard, one query, `settle!`, for `outdated`) |
| `cli/lib/OutdatedFlow.roc` | The setting (`InstallFlow.setting_of`). With `Read`: the registry list first (`first_releases!`), then `report_query!` with `report_groups` and the `Report` window, then the index from the answer; that list is D (no second read) |
| `cli/lib/ResolveSelect.roc`, `cli/lib/ResolveLoad.roc` | `select_noted!`, `ranged!`, `prepared!` give `listed` (the range pick read the registry list) |
| `cli/lib/VerifyFlow.roc` | `window: Held(id)` or `None` (was `pin`) |
| `cli/lib/RocUse.roc` | `named!`: the record of `offer_noted!` is written at the call (a bound record has no optional field) |

Notes for the review:

| # | Point |
| --- | --- |
| 1 | One read for each command (R-IX4): the first read (`HeldRoc.picked!`, `NightlyFlow.plan!`, `range_id!`, the list of `outdated`) asks the registry. Then the request is `listed`, and each later read (`PickLoop.releases!`, the offers of the plan and of the first probe, the optional compilers) reads the kept `toolchains.json` with no request (the calls `read_files`, `list_dirs`, `db_query` of the expect files) |
| 2 | A later read in a registry run with no first read (a held compiler that is installed, so no pick) stays `Direct` (the GitHub list), as before the slice: `registry/sp24-held-move-drop` (slice 206d2) fixes a GitHub list for D in that run. R-CV1 reads as the registry list there too. See Doubt D1 |
| 3 | Q489 (G-C123): the bare `upgrade` path was already the `direct` rule in `NightlyFlow.plan!` (the note, `free: Held`, `releases: Ok([])`). With an unread list the window is `Held(H)`, because `releases` is empty. `upgrade roc` returns the failure of the list (exit 15). `range_id!` now gives exit 15 offline with no kept rows (`ix6-offline-range`) |
| 4 | The `Free` domain uses the releases after the `log:N` hide of the read, so its `snapshot` is only a time (`log_index` is not read). Changed tags (R-CV6) are not in it |
| 5 | The optional record field `list ?:` keeps each other caller of `offer!`, `Start.run!` and `NoRank` unchanged (`Direct`) |

Doubts (no test, no change made):

| # | Doubt |
| --- | --- |
| D1 | Note 2: should a registry run read the registry list for D and for the probe offer also when no earlier read was made? Then `sp24-held-move-drop` must change |
| D2 | `--offline` with a registry: `with_setting` gives `Off` with the index `Offline(origin)`, so `HeldRoc.picked!`, `NightlyFlow.plan!` and `PickLoop.releases!` read the GitHub cache (`direct`), not the kept `toolchains.json` of R-IX6. Only `range_id!` (before `with_setting`) reads the kept rows. No case covers it |
| D3 | `outdated` with a registry list that cannot be read: the list is `[]` (as `PickLoop.releases!` before the slice: no failure), so the query has no `compilers` member and the `nightly range` column has no D. No case covers it. Q489 is about `upgrade` only |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206e2-revert/code-final.sha256` | OK, 20 files |
| `grep "todo: slice 206e2" cli/` | nothing |
| Expected exits (read) | `cv1-upgrade-free` 0, 0; `cv1-held-pick` 0; `cv1-outdated-query` 0, 0; `cv1-upgrade-unread` 0, 15 (Q489: `upgrade roc` with an unreadable list); `ix6-offline-range` 15 (Q489 changes Q467); `sp24-ingest-held-move` 0 |
| `scripts/test.sh check fmt l0 l2 l3` | all pass (L2 347 pass), with slice 220 code in the tree |
| Q489 (G-C123) | done in this slice: bare `upgrade` keeps H with the note and a `Held` window; `upgrade roc` exit 15; `range_id!` offline with no copy exit 15 |
| D1 | Defect, not a question: R-CV1 says that with a registry the list is `GET /v1/toolchains`. A registry run with no earlier list read (a held installed compiler) still reads the GitHub list in `PickLoop.releases!` and the offers. `sp24-held-move-drop` pins the GitHub read and must change. Plan row 206e2b |
| D2 | Defect: R-IX6 says `--offline` with a registry uses the kept rows of `toolchains.json`. `HeldRoc`, `NightlyFlow` and `PickLoop` read the GitHub cache. Plan row 206e2b |
| D3 | Accepted: R-IX6 (Q467, Q489) says that with no readable list "the rule of `direct` applies"; `outdated` keeps its `direct` behaviour (empty compiler domain, no `compilers` member) |
