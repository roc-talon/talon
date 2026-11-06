# 206i Registry platform read in `tln init`

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 206i of `PLAN-P2-CLI.md`. Design Q560: with a registry, `init` reads its platform as `add` does (R-AP1, the ingest on a 404, R-AD35, the closure query), not from the GitHub release list. Then `init` sent a closure query, so it joins R-SH4 detail 11 (Q541), and the guard `share/sh62-no-send-init` changes: it now sends. Slice 206g did the compiler list of `init` (`206g-roc-commands-registry-list.md`). Slice 206f did the same read for `add` (`206f-registry-names.md`, `FullName.read!`).

## Rules

R-IN1, R-IN9, R-IN10 (CLI 5), R-AD35 step 5 (CLI 3), R-SH4 detail 11 and 12 (CLI 1), Design Q545, Q555, Q560, Q541. As used: R-IN2, R-IN6, R-IN7, R-IN8, R-AP1, R-AP16, R-AP74, R-RG4, R-CV1, R-IX4, R-SP8, R-SP23, R-UP3, R-SH2, R-SH3, R-SM3, R-DT5, R-EC2.
Slices read: 206f, 206g, 081 to 085 (`init --platform owner/repo@version`), 206e4 (queue), 218 (smoke), `PLAN-P2-CLI.md` row 206i.

| Rule | Text (short) | Test of this slice |
| --- | --- | --- |
| R-IN1 | With a registry the platform is read as a full name of `add` is (Q560) | all 3 cases |
| R-IN9 | `owner/repo@<version>`: the version is in the release list, else `owner/repo has no release <version>`, exit 2 (R-EC2) | `in1-init-version`, `in2-init-no-release` |
| R-IN10 | The named release is held (R-SP23), the nightly is free, the start header has its URL | `in1-init-version` |
| R-AD35 step 5, Q555 | A free platform: the closure item is `{group}` with no `range` (as `add` with no selector) | `sh62-no-send-init` |
| R-SH4 detail 11, 12 | A command that sent a closure query sends the queue; the unit fact of the ladder is queued; the smoke build runs (R-SM3) | `sh62-no-send-init` |

## Scope

| # | Part | Where |
| --- | --- | --- |
| 1 | `init` (app) with a registry, no `--platform` or `--platform owner/repo`: `FullName.read!` of the platform (guard, R-AP1, on a 404 the ingest) replaces the GitHub release list at the start. The start release is the newest that `min-release-age` allows, from the R-AP1 list | `Init`, `InstallFlow`, `Update.resolve!` |
| 2 | `init --platform owner/repo@version` with a registry: the same read; the version is looked up in the R-AP1 list (`NoMatch`: R-IN9 (2) text, exit 2, no file) | `Init` |
| 3 | The resolve of `init` with a registry sends one closure query (the platform group when free, `groups` [] when held, the hash of the start release, the free compiler window). The candidates and facts of the platform come from the answer. `init` no longer turns the registry into `Compilers` only (206g) | `InstallFlow`, `ResolveBase` |
| 4 | `init` joins R-SH4 detail 11: the queue step after the facts write, the smoke build, the send. Output, exit code and `--json` do not change | `InstallFlow`, `Share` |

## The flow as I read it

| # | Reading | Source |
| --- | --- | --- |
| R1 | The platform read comes where the GitHub list came: after `read_files` of `main.roc` (R-IN7 check first), before the second `read_files` of `config.toml` and the first write. The calls are the calls of the word `fullname` (slice 212): `read_files` of the guard copy `index/github/<o>/<r>/repo.json`, `programs gh` (no token), `http_get /repos/<o>/<r>`, `write_atomic`; then `list_dirs` of `index/registry/<origin dir>/get`, `http_get /v1/packages/<o>/<r>/releases`, `write_atomic` of the copy `get/<sha256 of the path, 32 hex>.json` and `.meta` | 206f R8, 212 |
| R2 | The GitHub list of the platform is not read, also for `roc-lang/basic-cli`. The cases have no route for it, so a call is a 404 | Q560 |
| R3 | The start release is the newest of the R-AP1 list that `min-release-age` allows (0.25.0: 0.26.0 is 1 day old). A named version is used as it is (R-IN9 (3), R-IN10 (1)) | R-IN1, R-IN10 |
| R4 | The resolve is the one of `init` today (the compiler list read and kept, the download prompt, then the ladder), with one closure query between the download and the facts query. The query body is: `compilers` from the oldest row of the compiler list to the newest that the age allows (as `registry/cv1-upgrade-free`), `groups` `[{"group": <group of the platform>}]` for a free platform (no `range`, no `series`: Q545 "no selector", R-UP3), `groups` `[]` for a named version (R-IN10 (2): the flow of `upgrade roc`, no package is free, as `registry/cv1-upgrade-free`), `hashes` the platform hash of the start header. The guard of the query is one `read_files` of the kept `repo.json` | Q545, Q555, Q560, R-IN10 |
| R5 | The facts query is for the candidates of the answer times the rows of the compiler list: 3 releases x 6 rows (`facts=18`) for a free platform, 1 x 6 for a named release (`facts=6`, as `init/it5-version` run 8). With no `runs` in the answer, the ladder is the one of today: 4 probes | R-IN2 |
| R6 | `resolved at log:<log_size>` in place of the clock time (registry run, R-DT5, as every registry run) | R-DT5 |
| R7 | With sharing on, the queue steps are those of `share/sh60-ladder-share`: after the facts write of the unit probe `platform`, `db_query pinned=1`, `clock`, `db_write queue=1`. The app build fact is not queued (R-SH3 filter 2). After the work (the CI file), the smoke build of the key that the ladder built (R-SM3: platform hash, N, `x64musl`), its queue step, the send. The answer of the fake registry is 503, so the 3 rows stay | R-SH4 12, R-SM3 |

## Tests

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| L2 | `share/sh62-no-send-init` (changed, 1 run): `cwd:i1 init`, a registry, `share = true`, a queue row. The GitHub list route of basic-cli is removed; routes added: the guard, R-AP1 (3 releases), the closure answer (3 releases, 3 platform artifacts, no runs), `POST /v1/compat` (503). Expected: the calls of R1 to R7, stdout with `resolved at log:60, 4 probes`, `tree.diff` with the guard copy, the R-AP1 copy, `share_queue.tsv` (3 rows), `smoke.tsv`; no `1.json` of the GitHub list | R-IN1, R-AD35, R-SH4, R-SH3, R-SM3, R-CV1, R-IX4 |
| L2 | `registry/in1-init-version` (new, 1 run): `init --platform roc-lang/basic-cli@0.24.0`, `share = false`. The world of sh62. Named release held: `groups` [], the hash of 0.24.0, `facts=6`; the header has the URL of 0.24.0 (not the default 0.25.0) and the basic-cli template. No queue call, no smoke build, no send | R-IN1, R-IN9, R-IN10, R-SP23, R-IN8 |
| L2 | `registry/in2-init-no-release` (new, 1 run): `init --platform roc-lang/basic-cli@9.9.9`: R-AP1 has 0.24.0, 0.25.0, 0.26.0. Exit 2, `roc-lang/basic-cli has no release 9.9.9`, no closure query, no file of the project, no compiler call | R-IN9 (2), R-IN7, R-EC2 |
| L2 | `registry/in3-init-package` (new, 1 run, Q564): `init package`, a registry, `share = true`, a queue row. One `GET /v1/toolchains?after=0`, the download prompt, 2 probes, no platform read, no closure query, no queue call, no send; `share_queue.tsv` unchanged. Exit 0. Written by hand from the sh62 pre-change calls and `init/it1-app` run 6; it passes before the code (a guard, like the old sh62) | R-IN1, R-SH4 (Q541, Q564), R-CV1 |
| L0 | None. No pure decision is new: the closure item of a free platform is `FullName.closure_item` (206f) and the pick is `Init.start` | |

How the expected files were made (TW21). No private reference was built: the code does not read the registry for `init` yet, so a reference run would show the GitHub flow. The files are made by `research/slice-206i-revert/mkcases.py` from the pre-change files of sh62 (kept in `research/slice-206i-revert/before/`): the list lines are replaced by the lines of R1, the facts lines by R4, the queue and send lines of R7 are copied from `share/sh60-ladder-share` and `share/sh58-send-upgrade-roc`, and the hash of `in1` is that of 0.24.0. The fixtures (R-AP1 answer, closure answers, guard answer) are by hand, with the rows of the old GitHub list of basic-cli (same hashes and dates). Each expected file was read.

## Proposals (R-OUT2, TW24)

No new text and no new `--json` field. The failure text of `in2` is the text of R-IN9 (2). The `resolved at log:60` line is the registry form of the existing line.

## Expected exits (read, TW21)

| Case | Exit | Reason |
| --- | --- | --- |
| `sh62-no-send-init` | 0 | the check and the build pass; the send never changes the exit code (R-SH4) |
| `in1-init-version` | 0 | as sh62 with a named release |
| `in2-init-no-release` | 2 | no release 9.9.9 (R-IN9 (2), R-EC2) |

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| The 3 cases | `exit 2`, `tln: error[usage]: no GitHub repository roc-lang/basic-cli (a private repository needs a token)`: the code reads the GitHub list (the route is gone) where the guard and R-AP1 are expected |

## Out of scope

`init --offline` and `init --snapshot` with a registry (the same `FullName.read!`: `add --offline` is `ad37-add-offline`). The ingest on a 404, the 5xx, 429 and 3xx answers of R-AP1 for `init` (`FullName.read!` is tested by slices 206f and 212). `init --platform` of another repository (the stub template, R-IN8): the read is the same, the ladder with a failing unit check is `init/it5-version`. A closure answer with `runs` or `bot` rows (fewer probes: Q560 says so, `registry/ef1-rank2-ladder` tests the ladder side). `--json` of `init`. `direct` (the cases of `init/` stay green).

## Questions (stop until answered)

| # | Question | Not tested | Answer and test change |
| --- | --- | --- | --- |
| Q1 | `init package` with a registry: there is no platform, so there is no R-AP1 read and no group. Does it still send a closure query (`groups` [] and `hashes` [], only to get the compiler window rows) and so send the queue, or is it a command that read only the compiler list (R-SH4 detail 11, Q541)? | `init package` with a registry | Q564: no closure query and no queue send; only `GET /v1/toolchains?after=<largest>` (and its pages). New L2 case: `init package` with a registry, one toolchains read and no other registry call. |
| Q2 | `init --platform owner/repo@<version>` with a registry: the closure item of the named release. R-IN10 (2) says the resolve is the flow of `upgrade roc` with the platform held, so `groups` [] and the hash only (as `registry/cv1-upgrade-free`). Q560 says "the closure query with the group of the newest release" and Q555 gives `range` `=1.2.3` for a version selector of `add`. Which one: `groups` [] and `hashes` [the named release], or `groups` [{group, `range` `=<version>`}] and the same hash? `in1-init-version` follows R-IN10 (2) (`groups` []); the line of the POST body is the only line that depends on the answer | The body of the closure query for a named release | Q565: `groups` `[]` and `hashes` `[<hash>]` (R-IN10 (2)). Requests: guard, R-AP1, toolchains, the closure `POST`, the queue send. `in1-init-version` stays. |

## Doubts (a reading that the code agent may dispute)

| # | Doubt |
| --- | --- |
| D8 | `in3-init-package`: with no closure query the stdout line is `resolved at 2026-10-15T12:00:00Z, 2 probes` (the time, as before), not `log:<n>`. The calls are sh62 without the platform, facts and build lines |
| D1 | The order of the calls: R1 puts the guard and R-AP1 at the place of the GitHub list (before the second `read_files` of `config.toml`), and R4 puts the closure query where the kept-list read and the facts query were. The guard `read_files` before the POST is one read of the kept `repo.json` of the platform (as `registry/ad35-add-closure`); the hash of the start header names the same repository |
| D2 | The compiler window of the query: from the oldest row (`nightly-2026-10-08-8c8c8c8`) to the newest row that the age allows (`nightly-2026-10-12-2a2a2a2`). I read it from `registry/cv1-upgrade-free` (a free nightly). `init` may use the baseline compiler or the downloaded N for one end |
| D3 | `facts=18` and `facts=6`: copied from the direct runs (3 and 1 candidates x 6 rows of the list, with the row that min-release-age hides). With the closure answer the key set may differ |
| D4 | In `in2-init-no-release` the second `read_files` of `config.toml` after the R-AP1 read is copied from `init/it5-version` run 6 (the min-release-age read of the start). It may not run before the `NoMatch` stop |
| D5 | `sh62`: the queue step has one fact (the unit fact of 4oYD). The baseline and the app build are not queued (R-SH3 filter 2). The smoke build is one probe with `--target=x64musl` and `timeout=9` (`probe.timeout` of the case). The `x64musl` target is in `target_names` of the artifact (R-SM3, filter 7). I read that `init` is a command of R-SM3 ("the command built a key with ladder step 3") |
| D6 | `sh62` and the `share.json` round: the fake answers 503, so no `unqueue`, no totals. This keeps the case small. The 201 path is in `sh60-ladder-share` |
| D7 | `programs gh` runs because the case has no token (as the old guard). A token would add the `Authorization` line of the guard |

## Code

| File | Change |
| --- | --- |
| `cli/lib/Init.roc` | `start_url!` reads `config.toml` first, then `IndexQuery.setting` (flag, `TALON_REGISTRY`, key `registry`). `Direct`: `github_list!` (the old GitHub read). `Registry`: `registry_list!` = `FullName.read!` (guard, R-AP1, ingest on a 404) and `ClosureIndex.candidates` (yanked dropped). A named version is the typed selector `Exact`; no row is `NoVersion` (R-IN9 (2)). `after_first!` ends with `ShareHook.send!(fx, done.ran, 0)`; `run!` uses `ShareHook.failed!` |
| `cli/lib/InstallFlow.roc` | `compilers_only(request, fresh, has_platform)`: an `init` of an app keeps `Read` (closure query with the platform group or hash). `init package` stays `Compilers` (Q564: no closure query, no queue send) |

Copies: `research/slice-206i-revert/code-final/` and `code-final.sha256`.

Review notes:
- The closure body, the window, the facts query, the queue and the smoke build come from the existing flow (`Update.resolve!` with `Read`): no new code for them.
- `in3-init-package` is green with no change.

## Disputes (from the code agent)

| # | Case | Rule | Line | Reading |
| --- | --- | --- | --- | --- |
| C1 | `registry/in1`, `in2`, `share/sh62` (and all of `init/it1` to `it6b`) | R-RG1, Q560 | `read_files $HOME/.config/talon/config.toml` after the R-AP1 write | The registry is the key `registry` of `config.toml` (R-RG1), so the file must be read before the guard: no other source of it exists at that point (the first `read_files` after `tty` is the first-run prompt, only in an interactive run). The code reads `config.toml` right after `main.roc`, before the guard (`direct` too, as it cannot know). With the line moved there, the 3 registry cases and these 7 direct cases differ only by that one line (each run of `it1`, `it2`, `it5`: the line goes up before `list_dirs .../index/github/...`). `in2`: the read happens before the `NoMatch` stop (D4), so it is not after R-AP1 |
| C2 | `registry/in1`, `share/sh62` | R-AL8 source 2, R-IX4 | `random`, `list_dirs $HOME/.cache/roc/packages`, `read_files .../packages/<hash>/main.roc` after `facts=N` | The closure answer has the platform artifact, so the facts need no archive read (the lines are copied from the direct run, as D3 says). The registry runs of `sh60` and `cv1-upgrade-free` have no such read before the first probe. The code makes no such call |
| C3 | `registry/in1` | R-SM3 (digest) | `tree.diff` line `fact FYkF6... x64musl pass <digest>` | The digest `33126c41...` is the one of `4oYDdx...` in `sh62`. The code gives `f58af1a30a24231550b067b8e3c34a04d758ea54a16c9a86710d0c1b8f537c6e` for `FYkF6...` (the digest depends on the hash) |

## Verify results (code agent)

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `l0` | pass (20.7 s, TW20 warning) |
| `l2` | 469 pass, 10 fail: `registry/in1`, `in2`, `share/sh62` (C1 to C3), `init/it1`, `it2`, `it3`, `it4`, `it5`, `it6`, `it6b` (C1 only) |
| `l3` (`JOBS=1`) | pass |
| `registry/in3-init-package` | pass |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206i-revert/code-final.sha256` | OK |
| Expected exits (read) | `sh62-no-send-init` 0 (now sends, Q541, Q560); `in1-init-version` 0; `in2-init-no-release` 2 (R-IN9 (2)); `in3-init-package` 0 (no closure query, no send, Q564) |
| Disputes C1 to C3 | accepted. C1 moved the `config.toml` read before the registry choice (R-RG1), also in the 7 direct `init/` cases (only that line moved; checked against `before2/`). C2: no platform archive read with a closure answer (R-AL8 source 2). C3: the 0.24.0 digest |
| `scripts/test.sh check fmt l0 l2` (`JOBS=3 TEST_TIMEOUT=400`) and `l3` (`JOBS=1`) | all pass |
| Design answers | Q560, Q564, Q565 |
| Not tested | `init --offline` with a registry for an app |

