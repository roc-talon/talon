# 206g Registry compiler list in the roc commands

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 206g of `PLAN-P2-CLI.md`. It closes Q4 of slice 206f (`206f-registry-names.md`): `roc install`, `roc use`, `roc default`, `roc update`, the proxy and `init` list compilers from GitHub even when `config.toml` has a registry (`RocUse` has `registry: Off`; the other callers of `RocInstall.offer!` give no `list`). The slices 206e2 and 206e2b did the same for the resolve commands (`206e2-registry-compiler-list.md`, `206e2b-registry-list-reads.md`).

## Rules

R-CV1, R-IX4, R-IX6, R-CV5 (CLI 6.2, 7.3), Design Q467, Q489, Q490, Q541. As used: R-RG1, R-CV3, R-CV6, R-E6, R-SH4 detail 11, R-RU1, R-SO15, R-SO13, R-PX4.

| Rule | Text (short) | Test of this slice |
| --- | --- | --- |
| R-CV1 | With a registry the list of compilers is `GET /v1/toolchains`. With no readable list the rule of `direct` applies (Q489) | all 8 cases |
| R-IX4 | One read for the command (`after=<largest>`); the kept rows `toolchains.json` serve the later reads. Nothing is written when no row is new | `cv1-proxy-range`, `sh62-no-send-init` (2 reads, 1 request) |
| R-IX6 | `--offline`: no request, the kept rows at any age; no `index:` line for the list (Q490) | `ix6-roc-update-offline` |
| R-CV5 | A download from the registry list has `sha256_source` `registry` | `sh62-no-send-roc-install`, `sh62-no-send-roc-update`, `sh62-no-send-init`, `cv1-roc-use`, `cv1-roc-default`, `cv1-proxy-range` |
| Q541 | A command that read only the compiler list sends no queue (R-SH4 detail 11) | the 3 `sh62-*` guards stay (no queue line) |

## Scope

| In | Out |
| --- | --- |
| The compiler list read of `roc install` (`RocInstall.offer!`), `roc update` (`@latest`), `roc default` and `roc use` (a compiler that is not installed), the proxy (rank 3 offer, rank 4 `range_id!`) and `init` (the pick and the offer of the first probe): with a registry it is `GET /v1/toolchains`, with the source `registry` in the pins and in `.talon.json` | `direct` (unchanged: the cases of `roc/`, `proxy/`, `init/` stay green) |
| `--offline` with a registry: the kept `toolchains.json` | The rule when no copy exists (Q489, done in 206e2): not changed |
| The unreadable list (an error answer): the rule of `direct` (exit 15 for a command that must choose) | The platform and package release lists of `init` (they are GitHub lists today; question Q1). `tln setup`, `tool`, `x`, `probe`, `publish --probe-downloads` and `link`/`git` installs (their list reads are another slice) |
| The 3 `sh62-*` guards: the registry calls change, the queue calls stay absent (Q541) | `--snapshot log:N` for the roc commands (the commands have no such flag today) |

## Flow as read

The registry setting of a run is R-RG1: `--registry`, `TALON_REGISTRY`, the key `registry` of `config.toml`, else `direct`. The proxy has no flag, so it reads the variable and the key. The cases set the key.

| # | Run | Reading |
| --- | --- | --- |
| 1 | Registry, online, the command reads the list once (`roc install`, `roc update`, `roc default`, `roc use`) | The calls of the list: `read_files` of `toolchains.json`, `http_get <origin>/v1/toolchains?after=0`, `write_atomic` of `toolchains.json`, `db_query` and `db_write` of `pinned` (source `registry`, R-CV6). No `list_dirs`, no `programs gh`, no GitHub call. The download has the `size` of the row; `.talon.json` has `sha256_source` `registry` |
| 2 | Registry, online, the command reads the list twice (the proxy at rank 4: `range_id!`, then the offer; `init`: the pick, then the offer of the first probe) | Read 1 as row 1. Read 2 is the kept file: `read_files` of `toolchains.json`, `list_dirs` of the registry dir, `db_query` of `pinned`; no request (R-IX4) |
| 3 | Registry, `--offline`, a kept `toolchains.json` | The first read is the kept file at any age: `read_files`, `list_dirs` of the registry dir, `db_query`, `db_write` (the first sighting of the rows, as `registry/ix6-offline-upgrade`). No request, no GitHub cache, no exit 15, no `index:` line (Q490) |
| 4 | Registry, online, `GET /v1/toolchains` answers 404 (not problem details) | A command that must choose (`roc install <id>`) fails with the failure of the list: exit 15, `tln: error[network]: http://127.0.0.1:9 answered 404 and the answer is not problem details. Check the registry setting.` (the text of `registry/cv1-upgrade-unread` run 2). Nothing else happens after the request |

## Tests

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| L2 | `share/sh62-no-send-roc-install` (changed, 1 run): `roc install nightly-2026-10-09-258ab27`, a registry, `share = true`. The route `v1/toolchains?after=0` (10 rows, the sizes and digests of the old GitHub list) replaces the GitHub route. `calls.log`: the 6 GitHub list lines become the 5 registry lines of row 1. `tree.diff`: `toolchains.json`, the pins with source `registry`, `.talon.json` `sha256_source` `registry`. stdout, stderr, exit: unchanged. No queue line | R-CV1, R-IX4, R-CV5, R-SH4 (Q541) |
| L2 | `share/sh62-no-send-roc-update` (changed, 1 run): `roc update`, 12 rows. As above, for the `@latest` read | R-CV1, R-IX4, R-CV5, R-RU1, Q541 |
| L2 | `share/sh62-no-send-init` (changed, 1 run): `cwd:i1 init`, 6 rows. The first read is the request, the offer of the first probe is the kept file (row 2). The GitHub list of `basic-cli` (the platform) stays | R-CV1, R-IX4, R-CV5, Q541 |
| L2 | `registry/cv1-roc-use` (new, 1 run): `roc use <N> --file p6/main.roc`, N is the one download (run 5 of `roc/us1-use`), 12 rows. One `GET /v1/toolchains`, no GitHub call, `sha256_source` `registry` | R-CV1, R-IX4, R-CV5 |
| L2 | `registry/cv1-roc-default` (new, 1 run): `roc default <N>`, N is missing, no default yet (R-SO15), 3 rows. As above | R-CV1, R-IX4, R-CV5, R-SO15 |
| L2 | `registry/cv1-proxy-range` (new, 1 run): `@roc check p2/main.roc`, rank 4 with a range, a person answers Enter. The list is read for the range, and for the offer: ONE request (row 2) | R-CV1, R-IX4, R-CV5, R-SO13, R-PX4 |
| L2 | `registry/ix6-roc-update-offline` (new, 1 run): `roc update --offline`, a kept `toolchains.json` (12 rows), the newest allowed compiler installed and the default. No request; text `<id> is the newest`; no `index:` line | R-IX6, R-IX4, R-CV1, R-RU1, Q490 |
| L2 | `registry/cv1-roc-install-unread` (new, 1 run): `roc install <id>`, the route is missing (404). Exit 15, the text of row 4, one request, nothing written | R-CV1, R-E6, Q489 |
| L0 | None. No pure decision changes: the source of a read is a function of the request (`ResolveBase.list_first`, `list_later`) and the calls show it. A new `expect` would pin a name that the code agent may choose again | |

How the expected files were made (TW21). The fixtures and the expect files are made by `research/slice-206g-revert/mkcases.py` (no code of `cli/` is used). The registry rows are the Linux asset of each release of the old GitHub list of the same world (the same tag, size, digest and date), so the sizes of the prompts, the counts `pinned=<n>` and the tree of the compilers stay equal. For the 4 new cases with a world, the expect files are those of the direct run of that world in a private tree (`research/slice-206g-revert/ref/`, a test binary of the current code, deleted at the end), with one change: each read of the compiler list is the registry read of rows 1 to 3 (the calls are copied from the cases of 206e2 and 206e2b: `registry/cv1-held-offer`, `registry/ix6-offline-upgrade`). `registry/cv1-roc-install-unread` is written by hand from the prefix of the guard and `registry/cv1-upgrade-unread`. The old expect files of the 3 guards are in `research/slice-206g-revert/before/`. Each file was read.

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `scripts/test.sh l0` | fails only in driver 5 (`todo: slice 209b`, `MatrixTest`: another agent) |
| `scripts/test.sh l2` | 462 pass, 10 fail: the 8 cases above and `registry/sm6-bot-fail`, `registry/sm6-bot-fail-update` (slice 209b) |
| `scripts/test.sh l3` | pass |
| The 7 online cases | `exit 2`, `tln: error[usage]: no GitHub repository roc-lang/nightlies ...` (the code reads the GitHub list, which the case has no more); the calls show `list_dirs`, `programs gh`, `http_get api.github.com/...` where the registry read is expected |
| `registry/ix6-roc-update-offline` | `exit 15`, `no cached list of compilers and --offline is set`: the code reads the GitHub cache, not the kept rows |

## Expected exits (read, TW21)

| Case | Exit | Reason |
| --- | --- | --- |
| `sh62-no-send-roc-install` | 0 | the download is the command (`roc install` names it): prompt `[Y/n]`, Enter |
| `sh62-no-send-roc-update` | 0 | as above for `@latest` |
| `sh62-no-send-init` | 0 | as before: check and build pass |
| `cv1-roc-use` | 0 | the check and the build pass; the pin is written |
| `cv1-roc-default` | 0 | stderr is the compat warning of the world (the fake `roc check` touches no compat dir), as `roc/df1-default` |
| `cv1-proxy-range` | 0 | the fake `roc check` exits 0 |
| `ix6-roc-update-offline` | 0 | `is the newest`; no stderr |
| `cv1-roc-install-unread` | 15 | R-E6: a registry answer that is not problem details is exit 15 (`network`); the rule of `direct` for a list that cannot be read and a command that must choose (Q489) |

## Output (proposed, R-OUT2)

No new text and no new `--json` field. The texts are those of 206e2, 206e2b and the old roc commands.

## Out of scope

`direct`; `tln setup`, `tool`, `x`, `probe`, `publish`, `link`, `git` installs; the platform and package release lists of `init`; the no-copy rule (Q489); `--snapshot` for the roc commands; the first-run share consent (the cases carry `share = true` and a `share.json`, as the guards, so it does not enter).

## Questions (stop until answered)

| # | Question | Answer and test change |
| --- | --- | --- |
| Q1 | `init` with a registry reads the releases of the platform (and the `basic-cli` list) from GitHub (`api.github.com/.../basic-cli/releases`). R-DI1 and R-AL2 name `GET /v1/packages/{owner}/{repo}/releases` for the resolve commands. Does `init` read the platform releases from the registry too, and in which slice? The case `sh62-no-send-init` keeps the GitHub list of the platform (the reading of the plan row: compilers only). A design answer may change that part of the guard  | Answered (Q560): yes, in a later slice (new plan row); 206g keeps the GitHub list of the platform. Test change: none in this slice (`sh62-no-send-init` stays as written, its basic-cli GitHub list stays). The later slice changes it: R-AP1 and the closure query for the platform, and `init` then sends the queue (Q541) |
| Q2 | The proxy runs for each `roc ...` call of the user. With the registry key now read by the proxy, R-RG7 row 6 says a bad `registry` value in `config.toml` is exit 19 for each command that reads `config.toml` for a key of its own (the proxy reads `min-release-age`). Is it right that a bad `registry` value makes `roc` fail with exit 19 in the proxy, also when the call needs no compiler list? No case tests it. If the answer is no (the proxy ignores a bad value and reads `direct`), the code needs this rule  | Answered (Q561): the proxy checks the key only when it needs the list; a bad value is then exit 19. Test change: new L2 `proxy/px-bad-registry-plain` (`roc version` through the proxy with an installed compiler and `registry = "ftp://bad"`: runs, exit 0) and `cv1-proxy-range-bad-registry` (a range with no installed compiler: exit 19, no request) |

## Doubts (no test)

| # | Doubt |
| --- | --- |
| D1 | The order of the calls in a registry read (`read_files` of the file first, `list_dirs` of the registry dir after `read_files` in a kept read) is copied from the cases of 206e2b. The roc commands may place the first read differently (for example a `list_dirs` of `toolchains/` before it): the cases keep the order of the old GitHub read, with the list lines replaced one for one |
| D2 | `ix6-roc-update-offline` expects the first-sighting `db_write` of the `pinned` rows in an offline run, as `ix6-offline-upgrade` (206e2b D2): the design says "no request", not "no write" |
| D3 | `roc use` reads the list once (the offer of the new compiler), so the case shows one request, not the second (kept) read of R-IX4. The kept second read is in `cv1-proxy-range` and `sh62-no-send-init` |
| D4 | The registry setting comes from the key of `config.toml` in every case. The flag and the variable (R-RG1) are not tested for the roc commands: the priority code is shared (`Setting`), tested by 206b |
| D5 | `registry/cv1-roc-install-unread`: the error text is the one of `registry/cv1-upgrade-unread` (the failure of `RegistryToolchains`). `roc install` may print it in another frame (it is a `Fail`, the same printer) |

## Code

| File | Change |
| --- | --- |
| `cli/lib/IndexQuery.roc` | New `list_source`: `setting` then `Nightlies.Source` (`Registry` with `kept` for a later read or `--offline`, R-IX4, R-IX6) |
| `cli/lib/RocInstall.roc` | `offer!`, `offer_noted!`, `fetch_optional!` take `registry ?: [Off, First(flag), Later(flag)]`: the source is from `config.toml` (read already), `TALON_REGISTRY` and the flag. `range_id!` takes `config ?:` (the key `registry`): the form is checked after `platform!` (Q561) |
| `cli/lib/RocManage.roc`, `cli/lib/RocUse.roc` | `roc install` (`flow!`), `roc update`, `roc default`, `roc use`: `First(args.registry)`. `roc use` baselines: `Later` when the new compiler read the list (download or step), else `First` |
| `cli/lib/Base.roc` | `Loaded.config_registry` (the key `registry` of `config.toml`) |
| `cli/lib/Proxy.roc` | rank 4 passes `config` to `range_id!`; rank 6 pick calls `IndexQuery.list_source` (checks the form there); the offer is `First`, or `Later` after rank 4 or the pick |
| `cli/lib/ResolveBase.roc` | New `registry` variant `Compilers(Query)`: a registry for the compiler list only. `list_first`, `list_later`, `listed` handle it |
| `cli/lib/InstallFlow.roc`, `cli/lib/Update.roc` | `compilers_only`: `init` (`fresh`) turns `Read` (or `--offline` `Offline`) into `Compilers`. `init` keeps the GitHub platform list (Q560) |

Review notes:
- Q561: the proxy checks the `registry` form only when it needs the list (rank 4, the pick, an offer). A plain `roc` call never checks it.
- `Update.resolve!` no longer sets `registry: Off` for `init`.
- The rank 6 pick (`NoRank.pick_id!`) and `roc use` baselines are wired by the same rule; no test covers them.
- `init --offline` with a registry: index stays `Offline`, the compiler list is the kept file. No test.

## Disputes (from the code agent)

| Case | Rule | Dispute |
| --- | --- | --- |
| `registry/cv1-proxy-range-bad-registry` | R-RG7 row 6, Q561 | `expect/calls.log` ends with `platform`, then `read_files .../toolchains.json`, then exit 19. The check of the form must come before any read of the registry file (no source is known yet, so `read_files` of its path cannot be made). The code gives `platform` and then exit 19, without that `read_files`. The last line looks wrong |
| `share/sh5-first-skips` | R-CV1 | The case has `registry` in `config.toml`; `@roc --version` expects the GitHub list (`exit 2`, `no GitHub repository roc-lang/nightlies`). With a registry the proxy reads `GET /v1/toolchains` (exit 15, `answered 404`). The expected files are from before this slice |

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206g-revert/code-final.sha256` | OK, 9 files |
| Expected exits (read) | `cv1-roc-use`, `cv1-roc-default`, `cv1-proxy-range`, `ix6-roc-update-offline`, `px-bad-registry-plain` 0; `cv1-roc-install-unread` 15 (Q489, the rule of `direct`); `cv1-proxy-range-bad-registry` 19 (Q561). The `sh62-*` guards: no queue send |
| Disputes | 1 (`cv1-proxy-range-bad-registry`: no `toolchains.json` read before the check) and 2 (`sh5-first-skips`: older than R-CV1 in the proxy) accepted. `sh5` keeps its purpose (no consent ask) with an installed compiler |
| `scripts/test.sh check fmt l0 l2` (`JOBS=3 TEST_TIMEOUT=400`) and `l3` (`JOBS=1`) | all pass, with slice 209b code in the tree. L3 with 2 or 3 jobs failed other scenarios at random on the loaded machine (temp dir collisions); one job passes |
| Design answers | Q560, Q561 |
| Follow-up | plan row 206i (`init` reads its platform from the registry, Q560) |

