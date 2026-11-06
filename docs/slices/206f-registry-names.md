# 206f Registry for names, refusal gone

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 206f of `PLAN-P2-CLI.md`. Slices 211 (short names) and 212 (`FullName.read!`) built the registry reads of a name, and no command calls them. This slice wires them into `add`, `install <names>`, `tool install` and `x`, removes the P0 refusal of `--registry` (`Opts.check_registry`, `Opts.reads_registry`), and checks `config.toml` for the commands that make no index call. It also adds the guard of 206e4 (Q541) for the commands that send no share queue.

## Rules

R-AD35, R-AD36, R-AD37, R-SN4, R-RG7 (row 6) (Design 7.3). As used: R-AD2, R-AD3 to R-AD5, R-AD34, R-I8, R-SC3, R-SC4, R-AP1, R-AP9, R-AP25, R-AP34, R-AP52, R-RG1, R-RG4, R-RG5, R-DA8, R-DI12, R-DI14, R-IX3, R-IX6, R-IX7, R-E6, R-EC2, R-TF4, R-AU6, R-LF1, R-T10, R-SL3, R-SL12, R-SH2, R-SH4, R-CV1. Design Q396 to Q399, Q430, Q439, Q533, Q534, Q541.
Slices read: 206e, 206e4, 211, 212, `PLAN-P2-CLI.md` row 206f.

## Scope

| # | Part | Where |
| --- | --- | --- |
| 1 | `add` and `install <names>` with a full name: `FullName.read!` (guard, R-AP1, on a 404 the GitHub list and the ingests), the `NoMatch` text of `add` (Q430), R-AD36, R-AD37, a first R-AP1 read with a 5xx, a 429 or a 3xx | `Install`, `PickFlow` |
| 2 | `install <short name>` and `add <short name>` with a registry: one `?short=` request (R-AD34, `ShortNames.lookup!`, `Lookup.registry_all`) | `Install`, `PickFlow` |
| 3 | `tool install <full name>` and `x <full name>`: `FullName.read!` where `Github.releases!` was called, the `NoMatch` texts of the commands (Q430) | `ToolFlow`, `XFlow` |
| 4 | `Opts.check_registry` and `Opts.reads_registry` go for every command. A command that makes no index call does not read `--registry` (R-RG7 row 6). `install --frozen` makes no index call (R-AU6) | `Opts` |
| 5 | A bad `registry` in `config.toml` is exit 19 for a command that makes no index call, as each other key of R-TF4 (R-RG7 row 6) | `ConfigToml` or the load |
| 6 | An L3 case with the real `curl` child (the ingest of R-AD35 step 3) | `tln` |
| 7 | A guard: `roc update`, `roc install` and `init` with a registry send no share queue (Q534, Q541) | none (passes before the code) |

## The flow as I read it

| # | Reading | Source |
| --- | --- | --- |
| R1 | `add` and `install <names>` read the registry setting after the load of the project files and `config.toml` (`IndexQuery.setting`), as `update` does. A name that is a header alias or a path is not looked up in the registry. | 206b, 206e |
| R2 | Order for a name that is not a full name and not an alias: one `?short=` request for all short names of the command (R-I8: all keys first, nothing written), then `FullName.read!` for each full name in the order of the names. A failure of the short names (no match, 2 or more matches, `--offline` with no copy) stops the command with exit 2 or 15 before any other registry call. | R-AD34, R-I8, 211 |
| R3 | `FullName.read!` runs before the first closure query, because the group of `tln add` is known only after R-AP1 (R-AP16 names "the group of `tln add`"). A failure of `read!` ends the command: no closure query, no write of the project file. The guard (R-RG4) is part of `read!`. | R-AD35, R-AP16 |
| R4 | `NoMatch` is the text of the command (Q430): `add` gives `Add.no_release` with the close versions of R-SL12 (`no release of acme/known matches '9.9.9'. Close versions: 1.1.0, 1.0.0.`), `tool install` and `x` give `ToolInstall.pick` (`acme/foo has no release 9.9.9`). Exit 2. No ingest and no GitHub list. | Q430 |
| R5 | `tool install` and `x` use R-AP1 where `direct` uses the GitHub list, and nothing else changes: the bundle is fetched and its header read for the kind (R-T10), the build, the output. They send no closure query (Q534: not in the list of the commands that send). The registry R-AP1 record has no kind, so the archive is the source of the kind. | R-SC3, R-SC4, R-T10, Q534 |
| R6 | A registry flag is not read by a command that makes no index call, and the P0 refusal is gone: `remove nope --registry ftp://bad` is `'nope' is not in the project` (exit 2). `install --frozen --registry <url>` makes no registry request. | R-RG7 row 6, R-AU6 |
| R7 | A bad `registry` text in `config.toml` is exit 19 (`input`) when the file is read, before the names of the command are looked up. The message is the one of `IndexQuery.setting`: `<path>:<line>: registry: '<text>' is not a registry URL. <forms>`. | R-RG7 row 6, R-TF4 |
| R8 | The calls of the guard and of R-AP1 inside a command are the calls of the word `fullname` of slice 212 (the guard: `read_files` of `repo.json`, `http_get` of `/repos/<o>/<r>`, `write_atomic`; R-AP1: `list_dirs`, `http_get`, `write_atomic` of the copy). With `GITHUB_TOKEN` or `TALON_GITHUB_API` set there is no `programs gh`. | 203, 212 |
| R9 | `tty` is not read in a registry run of a project that `projects.json` has, and is read in a first run (the pattern of `registry/al2-install-query` run 2 and `share/sh51-send-install`). | observed in the existing cases |

## Tests

| Layer | Case | Checks |
| --- | --- | --- |
| L0 | `tests/unit/OptsTest.roc`: `install` and `add` with names, `--frozen`, a good and a bad `--registry`: no failure of `Opts.read`; the next check is the first failure | R-RG7, R-FL5, R-AD2, R-AD34 |
| L0 | `tests/unit/RemovalTest.roc` (`remove`, `patch`), `ListingTest.roc` (`list`), `ProbecmdTest.roc` (`probe` with no `--share`): the old rows that expected the P0 refusal now expect no failure | R-RG7 row 6 |
| L2 | `registry/ad35-add-nomatch`: `add acme/known@9.9.9`, R-AP1 answers 200, `NoMatch`: the text of `add` with the close versions, exit 2, no closure, no GitHub list | R-AD35, R-SL12, Q430 |
| L2 | `registry/ad36-add-snapshot`: `add acme/snap --snapshot log:40`, R-AP1 answers 404: exit 2, no GitHub list, no ingest | R-AD36, Q396 |
| L2 | `registry/ad37-add-offline`: `add acme/off --offline`, no copy: exit 15, no request | R-AD37, R-DI12 |
| L2 | `registry/ad35-add-ingest-429`: 404, the GitHub list, `programs curl`, 2 ingests (201, 429): exit 15, no second read | R-AD35, R-AP25, R-DA8 |
| L2 | `registry/e6-add-first-read` (3 runs): the first R-AP1 read gets 502, 429, 302: exit 15 each, the text of the registry error | R-E6, R-AP34, R-IX7 |
| L2 | `registry/sn6-install-short` (2 runs): `install Parser` (2 matches, the block, exit 2) and `install pars` (no match, `?q=` suggestions, exit 2) | R-AD34, R-AD4, R-AD5, R-I8 |
| L2 | `registry/sc3-tool-install`: `tool install acme/foo` with a registry: the run 1 of `tool/ti1-install` with the release list from R-AP1 | R-SC3, R-AD35, R-T10 |
| L2 | `registry/sc3-tool-nomatch`: `tool install acme/foo@9.9.9`: `acme/foo has no release 9.9.9`, exit 2 | R-SC3, Q430 |
| L2 | `registry/sc4-x-registry`: `x acme/foo -- a b`: the run 1 of `x/x1-run` with R-AP1 | R-SC4, R-AD35 |
| L2 | `registry/sc4-x-nomatch`: `x acme/foo@9.9.9`: exit 2 | R-SC4, Q430 |
| L2 | `registry/rg7-no-refusal` (2 runs): `remove nope --registry ftp://bad` and a good URL: no refusal, the run of the direct code | R-RG7 row 6 |
| L2 | `registry/rg7-remove-bad-config`: `registry = "ftp://bad"` in `config.toml`: `remove nope` is exit 19, before the names | R-RG7 row 6, R-TF4 |
| L2 | `registry/rg7-frozen-flag` (2 runs): `install --frozen --registry <url>` (good, bad): no refusal, no request, the run of `closure/cl3-frozen-none` | R-AU6, R-RG7, R-LF1 |
| L2 | `share/sh62-no-send-roc-update`, `-roc-install`, `-init`: a registry, `share = true`, a queue row: no queue call. Guards: they pass before the code | R-SH4, Q534, Q541 |
| L3 | `tests/scenarios/add/ad3-registry-ingest-skip`: `tln add acme/lib --registry $TALON_HTTP`, real `curl`, fake registry and GitHub: the request log, the body of the ingest, exit 2 | R-AD35, R-DA8, R-RG7 row 1 |

The tool and `x` cases are run 1 of `tool/ti1-install` and `x/x1-run`: a baseline of the current code (`UPDATE=1` on a copy in `research/slice-206f-revert/ref/`, now deleted), with the 3 calls of the GitHub list replaced by the calls of the guard and R-AP1 and the tree diff changed to match. The `rg7-*` cases take the expected files of a direct run of the same world with no flag. The add and short-name cases are hand-written from the first-run prefix of that baseline and the calls of the existing `fullname` and `short` cases. The fixture generator is `research/slice-206f-revert/mkcases.py` (a record: it needs the baselines of `ref/`).

## Proposals (R-OUT2, TW24)

No new text. Each failure text is an existing text: `Add.no_release` and `ToolInstall.pick` (Q430), the texts of `FullName` (slice 212), `Lookup.registry` (slice 211), the registry errors of slice 202, `IndexQuery.setting` (206b). The one new combination is exit 19 (`input`) for the config check of R7.

## Expected exits (read, TW21)

| Case | Exit |
| --- | --- |
| `ad35-add-nomatch` | 2 (no match, Q430) |
| `ad36-add-snapshot` | 2 (R-AD36) |
| `ad37-add-offline` | 15 (R-AD37, R-DI12) |
| `ad35-add-ingest-429` | 15 (R-AP25) |
| `e6-add-first-read` | 15, 15, 15 (502, 429, 302; R-E6, R-IX7) |
| `sn6-install-short` | 2, 2 (R-AD4, R-AD5) |
| `sc3-tool-install` | 0 (`installed foo 1.1.0`) |
| `sc3-tool-nomatch`, `sc4-x-nomatch` | 2 (Q430) |
| `sc4-x-registry` | 3 (the exit code of the app, R-X4) |
| `rg7-no-refusal` | 2, 2 (`'nope' is not in the project`) |
| `rg7-remove-bad-config` | 19 (R-TF4) |
| `rg7-frozen-flag` | 13, 13 (`TALON_AUTO_INSTALL=no` refuses the download; the registry flag is not read) |
| `sh62-*` | 0 |
| L3 `ad3-registry-ingest-skip` | 2 (no candidate left after the 409) |

The app exit in L2 is 0 in each case (the `exit <n>` line of the entry is the code).

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `scripts/test.sh l0` | 6 failures, all of this slice (OptsTest 2, RemovalTest 2, ListingTest 1, ProbecmdTest 1): the P0 refusal text where the new row has no failure |
| `scripts/test.sh l2` | 13 new cases fail: a registry in `add` and `tool install` and `x` is ignored (the direct flow runs: `no GitHub repository ...`, `--snapshot log:40 needs a registry`, the GitHub list), `install <short name>` says `GitHub has no index of short names`, `--registry` is refused (`rg7-no-refusal`, `rg7-frozen-flag`), the bad `config.toml` is not read (`rg7-remove-bad-config`). The 3 `sh62` guards pass. The other failures are the smoke cases of slice 218 |
| `scripts/test.sh l3` | `add/ad3-registry-ingest-skip` fails (the P0 refusal). `fx/sq3-real-fx-smoke` is slice 218 |
| `MISSING=1 scripts/rules.sh R-AD35 R-AD36 R-AD37 R-SN4 R-RG7 R-AU6` | no id with no test |

## Out of scope

The success path of `add` with a registry and of `install <short name>` with one match (they need the closure query: Q1). The ingest of `tool install` and `x` with `--snapshot` and `--offline` (the same `FullName.read!`, tested by slice 212). `tool update`, `tool rebuild`, `run` and the build of a project tool with a registry. The registry compiler list for `roc ...` and `init` (Q4). `tln audit`.

## Questions (stop until answered)

Manager (2026-11-03): Q1 to Q3 went to TalonRegistry as G-C175 to G-C177. Q4 is a defect of R-CV1, not a question: plan row 206g.

| # | Question | Not tested | Answer and test change |
| --- | --- | --- | --- |
| Q1 | `tln add <full name>` with a registry, the part after R-AP1: what does the closure query carry for the group of `tln add` (R-AP16: "the group of `tln add`"): the `series` and the `range` (a selector `@^2`, an exact version, no selector: all series?), and does the pick take the candidates and facts of the new name from the closure answer or from the R-AP1 answer plus the archive (R-DI7)? A short name with one match goes on as a full name, so it has the same question. | The success path of `add` and of `install <short name>`: the closure body, the `matched` line, the written header | Answered (Q545, R-AD35 step 5): the query has `{group}` with `series`, `range` or neither by the selector; candidates and facts come from the closure answer. Test change: new L2 `registry/ad35-add-closure` (`add acme/known@^2`: the POST has `groups` `[{group, range: "^2"}]`, the written header from the answer, the `matched` line for a short name) and `ad35-add-series` (`add acme/known@2`: `series`), `ad35-add-latest` (`add acme/known`: neither). The success path is no longer out of scope |
| Q2 | Which commands that make no index call read `config.toml`, so the check of R-RG7 row 6 reaches them? R-TF4 checks "each known key" of a file that the command reads. The test fixes `remove`. A command that reads no `config.toml` (for example `list`) cannot stop for a bad `registry`. Is that the intended reading, or must each command read the file for this key? | `list`, `cache`, `tool list`, `share *` with a bad `registry` in `config.toml` | Answered (Q546): only the commands that read the file for a key of their own; no new read. Test change: `rg7-remove-bad-config` stays. Add L2 `rg7-list-bad-config` (`list` with `registry = "ftp://bad"`: exit 0, no read of `config.toml`) and `rg7-share-bad-config` (`share` with the same: exit 19) |
| Q3 | `tool install` and `x`: where does the kind of a candidate come from with a registry? I read it as the archive header (R-T10, R-DI7) as in `direct`, because the R-AP1 record has no kind and Q534 says these commands send no closure query. If the closure `artifacts` should give it, the commands send a closure query and then send the share queue (R-SH4 detail 11). | The source of the kind: a case where the registry and the archive differ | Answered (Q547): the archive header; no closure query; no share queue in 206f (wired with the tool-build facts). Test change: none for the kind (the cases `sc3-*`, `sc4-*` are right); `sh62-*` guards stay. Add to `sc3-tool-install` a check that the `calls.log` has no `POST /v1/closure` |
| Q4 | `roc install`, `roc use`, `roc default`, `roc update`, the proxy and `init`: R-CV1 says "With a registry, Talon lists the compiler releases with `GET /v1/toolchains`". In the code `RocUse` has `registry: Off`, so these commands list from GitHub even with a registry in `config.toml`. Do they read the registry list (and which slice)? The `sh62` guards fix only that they send no queue. | The registry compiler list of these commands | Not a question: plan row 206g (R-CV1 stands). No test change in this slice |

## Doubts (a reading that the code agent may dispute)

| # | Doubt |
| --- | --- |
| D1 | The calls of `add` after the load (R2, R3, R8): the exact order and the number of calls between the read of the three files and the guard are readings. The tool and `x` cases are safer: they differ from a real direct run only by the lines of the release list. |
| D2 | `install <short name>` reads `?short=` right after the load and before any other call (no guard call, R-RG4). Block and failure line order on stderr is that of the word `short` of slice 211 (the block, then the error line). |
| D3 | The config check of exit 19 comes right after the read of the three files and ends the command with no other call (R7). |
| D4 | R9 (`tty`) is read from the existing cases. A first run of `add` has `tty`, a later run of a registry project has none. |
| D5 | The L3 case is hand-written: the request log (4 lines), the file `http-bodies/4`, the 4 hunks of the tree diff (the page and its `etag`, `repo.json`, `projects.json`). One candidate, because the order of the 2 `curl` requests of `http_all!` is not fixed. |
| D6 | `sc4-x-registry` keeps the exit 3 of the app (`exit 3` in stdout), as run 1 of `x/x1-run`. |

## Round 2 (test agent, Design Q545 to Q547)

| Case | Checks |
| --- | --- |
| `registry/ad35-add-closure` (`add acme/known@^1`), `ad35-add-series` (`@1`), `ad35-add-latest` (no selector) | Q545: R-AP1 (200), then one closure query with one item `{group}` and `range` `^1`, `series` `1`, or neither. `hashes` is the platform hash, the window is the `roc:` pin. No archive read, no GitHub list. Output `+ known: acme/known 1.1.0`, `resolved at log:50, 0 probes`, exit 0. The names differ from the manager's list: the fixture repository has only series 1 |
| `registry/sn6-install-short-one` | Q545, R-AD3: `install known`: `?short=known`, one match, the line `matched "known": acme/known` first on stdout (D2), then the same as `add acme/known`. Exit 0 |
| `registry/rg7-list-bad-config` | Q546 guard: `list` with `registry = "ftp://bad"` is exit 0 (current code). Doubt: the combined project read already names `config.toml` in calls.log; the check of the registry text must not run for `list` |
| `registry/rg7-share-bad-config` | Q546: `share` with the same config is exit 19, the text of `rg7-remove-bad-config`, calls: the config read only. Hand-written |
| `registry/sc3-tool-install` | Q547: the calls.log has no closure POST and no queue call (it is the full expected log, so a request would fail the case) |

Expected exits read: the 4 add cases 0, `rg7-list-bad-config` 0, `rg7-share-bad-config` 19 (stdout `exit 19`). The 4 add cases were made by hand (the calls are readings: the closure guard is one `read_files` of `known` and `pfx` `repo.json`, then the POST, then nothing). No private reference was kept.


## Code

| File | Change |
| --- | --- |
| `cli/lib/Opts.roc` | `check_registry` and `reads_registry` removed. `Opts.read` does not look at `--registry`. |
| `cli/lib/Removal.roc` | Doc row of the P0 refusal changed (no code). |
| `cli/lib/Install.roc` | `registry` of the request is `Setting(args.registry)` for `install` and `add` with or without names. `Off` only for `--frozen` (R-AU6). |
| `cli/lib/PickAsk.roc` | `short_names!`: one `ShortNames.lookup!` for all short names of the command (`Lookup.needs_registry`), `Lookup.registry_all`, the `matched` lines on stdout at once, the block on stderr for a failure. `asked!` uses the entry of the short name in place of `Lookup.find`. Only `Install` with a registry (`Read` or `Offline`). |
| `cli/lib/FullName.roc` | New pure `closure_item` (Q545): the group of the kept R-AP1 releases and `series` / `range` / neither. `series_of`. |
| `cli/lib/PickFlow.roc` | `fresh_items!`: `FullName.read!` for each new full name before the first closure query (R-AD35 to R-AD37, R-AP1 first read errors by `read!`), then the items go after `IndexQuery.groups(scoped)` in `query!`. `no_match` gives `Add.no_release` (Q430). `known` moved up. Candidates and facts come from the closure answer as before (`PickIndex.index!` `Answer`, `read_releases!`). |
| `cli/lib/ToolFlow.roc` | `Machine.registry` (the key of `config.toml` that step 3 read). `gather_with!`. `release_list_with!`: with a registry (`IndexQuery.setting`) the list is `FullName.read!` + `ClosureIndex.candidates` (no closure query, no archive change); `direct` is `release_list!`. `release_list_with_for!` for `x`. A `NoMatch` is an empty list: `ToolInstall.pick` gives the text of Q430. |
| `cli/lib/XFlow.roc` | Calls `ToolFlow.release_list_with_for!`. |
| `cli/lib/RemoveFlow.roc` | After `load!`: `IndexQuery.setting` with the `config` layer only (no flag, no env): a bad `registry` is exit 19 before the names (Q546). |
| `cli/lib/Share.roc` | `Share.setting` checks the form of `registry` with `IndexQuery.setting` (exit 19, Q546). All `share *` commands read the file for `share`. |
| `cli/lib/ConfigToml.roc` | Comment only. |

Copies: `research/slice-206f-revert/code-final/` and `code-final.sha256`.

## Disputes (from the code agent)

All the failing cases below fail only on the lines named here. The rest of each case matches.

| # | Case | Rule | Line | Reading |
| --- | --- | --- | --- | --- |
| C1 | `registry/ad35-add-closure`, `ad35-add-series` | R-AD26, R-AD35 step 5 | `expect/stdout`: after `  + known: acme/known 1.1.0` the code prints `$PROJECT/p1/talon.toml: known = "^1"` | `add X@^1` and `add X@1` write the key `known = "^1"` (R-SL15: `1` gives `^1`). The same line is in `consent/dl1-resolve` and `ev3-summary`. The case has no such line. |
| C2 | `registry/ad35-add-closure`, `-series`, `-latest`, `sn6-install-short-one`; L3 `add/ad3-registry-ingest-skip` | R-CC6 (file form) | `expect/tree.diff`: after the `projects.json` hunk the line `\ No newline at end of file` | `Known.record!` writes `projects.json` with a final line end (the hunk of `registry/al2-update-query` has no such line). Delete that line from each of the 5 files. |
| C3 | `registry/ad35-add-nomatch` | R-AD35, Q430 | `expect/stderr` is empty | The text `tln: error[usage]: no release of acme/known matches '9.9.9'. Close versions: 1.1.0, 1.0.0.` is on stderr, as `ad36-add-snapshot` and `sc3-tool-nomatch` have their texts. The slice file (R4) names this text. |
| C4 | `registry/e6-add-first-read` (runs 2, 3), `sn6-install-short` (run 2) | R-HF1, R-SH11 (D4, R9) | `expect/calls.log`: no `tty` after `env_all` of the later runs | `FirstRunFlow.before!` calls `tty` in each run that is not `--json` and not `--yes`-skipped. `registry/al2-install-query` has `tty` in the runs 1, 2 and 4 (run 3 is `--json`). R9 is not true: a project that `projects.json` has does not skip it. Add the line `tty` after the first `env_all` of those runs. |
| C5 | L3 `add/ad3-registry-ingest-skip` | fake server (`tests/tools/fakehttp.py`) | `given/http/api/repos/acme/lib/@` and `lib.meta` | The route `/api/repos/acme/lib` is the file `lib`, but `lib/` is a dir (the release list is under it). The body in `lib/@` is never served, so the guard fails: `the answer of GitHub ... has no member private`, exit 15. With `lib.meta` changed to `body @<fixture file>` (tried in a copy under the scratchpad with the `@` file as the fixture) the case gives the expected exit, stdout, stderr, request log and body; only C2 stays. A fixture file for the repo answer is needed in `tests/fixtures`. |

## Review notes (code agent)

| # | Note |
| --- | --- |
| N1 | Group choice (Q545): the group of the kept R-AP1 release with the largest `published_at`, preferring a release that is not yanked and not withdrawn. Q545 says "the group of the releases that the selector keeps" and does not say which one for two groups. `range` of a version selector is the range of the new entry (`=1.2.3`), not the bare text. No test fixes either. Answered (Q555): the group is the one of the newest by `published_at` then `log_index`, not yanked and not withdrawn; the range `=1.2.3` is right. Test change: new L2 `registry/ad35-add-two-groups` (R-AP1 with 2 groups: the POST has the group of the newest release), and `ad35-add-closure` pins `range: "=1.2.3"` for `add acme/known@1.2.3`. The series case of Q545 pins `range: "^2"`, not `series` (change `ad35-add-series`). |
| N2 | `FullName.read!` gives `NoMatch` (the GitHub list kept nothing) with no versions, so `add` gives `no release of <name> matches '<text>'.` with no close versions in that case. A 200 answer with no kept release has the versions (the tested case). |
| N3 | `tool install` and `x` drop yanked rows of R-AP1 and pass `pages: []` (the asset digests of the R-PT20 check come from GitHub pages; a registry list has none). `--snapshot` is not read by these commands. |
| N4 | A name of the form `host/path` with a registry reaches `FullName.read!` and gets `'<name>' is not a full name owner/repo` (kind `Usage`). The design does not say more. |
| N5 | `tool update`, `tool rebuild`, `run` and the tools step keep the GitHub list (out of scope). |
| N6 | `Share.setting` is used also by the first-run prompt (`FirstRunFlow`), so a bad `registry` in `config.toml` stops that step with exit 19 as well (R-TF4 for a file that the step reads). Answered (Q556): the prompt checks the `share` key only. Test change: new L2 `rg7-firstrun-bad-registry` (interactive first run of `list` with `registry = "ftp://bad"`: the prompt, exit 0) and `rg7-share-bad-share-key` (`share = "yes"`: exit 19). |
| N7 | Run result: `scripts/test.sh check l0` pass; `fmt` fails only for `cli/lib/BuildFlow.roc` (not a file of this slice); `l2`: only the 7 cases of C1 to C4 and the slice 218 cases `share/sh70` to `sh78` fail; `l3`: only `add/ad3-registry-ingest-skip` (C2, C5). |

## Code, round 2 (Design Q555, Q556)

| File | Change |
| --- | --- |
| `cli/lib/FullName.roc` | `closure_item`: a series selector gives `range` (`^1`), never `series` (Q555). The tie of the newest release goes to the larger `log_index`. `series_of` removed. |
| `cli/lib/Share.roc` | New `setting_share` (no check of `registry`). `setting` is `setting_share` plus the check (exit 19), for `share *`. |
| `cli/lib/FirstRunFlow.roc` | Uses `Share.setting_share` (Q556): a bad `registry` does not stop the first-run prompt. |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206f-revert/code-final.sha256` | OK, 12 files |
| `grep "todo: slice 206f" cli/` | nothing |
| Expected exits (read in the test reports) | `add` success cases 0; `ad35-add-nomatch`, `ad36`, `sn6-install-short` 2; `ad37`, `ad35-add-ingest-429`, `e6-add-first-read` 15; `rg7-remove-bad-config`, `rg7-share-bad-config` 19 (Q546); `rg7-frozen-flag` 13; `rg7-list-bad-config`, `rg7-firstrun-bad-registry` 0 (Q546, Q556); `sc4-x-registry` 3 (the app's own code). Each is the rule of its run |
| Disputes C1 to C5 | all accepted: faults in hand-written expected files and one L3 fixture (fixed by the test agent) |
| `scripts/test.sh check fmt l0 l2 l3` (`JOBS=3 TEST_TIMEOUT=400`, loaded machine) | all pass, with slice 218 in the tree |
| P0 refusal | `Opts.check_registry` is gone; old P0 rows in OptsTest, RemovalTest, ListingTest, ProbecmdTest, WhyTest now expect the new rule |
| Design answers | Q545 to Q547, Q555, Q556 |
| Follow-up | plan row 206g (the `roc` commands still list compilers from GitHub, R-CV1) |
