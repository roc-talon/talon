# 225 Default registry, P2 exit

Phase: P2 (CLI client). Status: tests written (test agent), waits for the human review (TW24) and the code agent.

Plan row 225 of `PLAN-P2-CLI.md`. The built-in default of the registry setting changes from `direct` to the registry URL `https://registry.roc-talon.org` (R-RG2, Design Q207, Q208). This is the client part of the P2 exit (Design 7). The slice also holds the design examples of CLI 1 and CLI 3 that need P2 (TW16), and L4 cases with the real Worker on the edge (tag `net`).

## Rules

R-RG1, R-RG2, R-RG7 (rows 3 and 7), R-RG8, R-RG9, Design 7 P2 exit (client part), TW16. Named in the tests as used: R-AL2, R-AP16, R-DT5, R-RG4, R-IX1, R-AD34, R-AD35, R-AP1, R-AP2, R-AP5, R-AP9, R-AP13, R-AP23, R-CV1, R-J3, R-AP37, R-SH7, R-SH12, R-PUB1, R-PUB4.

## The flow as I read it

| # | Reading | Source |
| --- | --- | --- |
| R1 | The default is one constant: `https://registry.roc-talon.org`. It is in the base URL form of Q207 (no path, no port, no trailing `/`). `Registry.base` does not change it | R-RG2, R-RG7 row 7 |
| R2 | Two places read the setting and fall to the default: `IndexQuery.setting` (the `?? Direct` of its last arm, also used by `IndexQuery.list_source`) and `Net.registry` (the arm `Err(Unset) => Direct`). Both give the registry URL when nothing is set. A text `direct` at any level (flag, `TALON_REGISTRY`, `config.toml`) still gives `Direct` | R-RG1, R-RG2 |
| R3 | A command that sends no registry request for its own work (`list`, `cache`, `tool list`, `path`) does not read the setting, so the default changes nothing for it | R-RG7 row 6 |
| R4 | The index dir of the default is `talon/index/registry/https_registry.roc-talon.org/` | R-IX1, R-RG7 row 7 |
| R5 | The Worker setting `AUDIENCE` in `worker/wrangler.toml` and the constant are one text. A change of one needs the change of the other (and a Talon release) | R-RG8 |
| R6 | A user who set no registry moves to the registry with the release of Talon that has the constant (`tln tool update talon`, 6.5). A user who wants `direct` sets it in `config.toml` | R-RG2 |
| R7 | The L3 runner sets `TALON_REGISTRY=direct` (TESTING.md 3.2), so no L3 case changes. The L2 cases have no such default: a case whose command reads the setting and sets no registry gets the new default | TESTING.md 3.2 |

## Tests

| Layer | Case | Rules | Red state now |
| --- | --- | --- | --- |
| L0 | `tests/unit/IndexqueryTest.roc` (driver `l0-6`) expect 1: nothing set gives the default, the other 6 precedence rows are as before | R-RG1, R-RG2 | fails (`direct`) |
| L0 | same file, expect 2: the default is a URL and `Registry.base` keeps it | R-RG2, R-RG7 rows 3, 7 | fails |
| L0 | same file, expect 3: `IndexQuery.list_source` with nothing set is a `Registry` of the default, with `direct` it is `Direct` | R-RG2, R-CV1 | fails |
| L0 | same file, expect 4: the default text of `IndexQuery.setting` is the `AUDIENCE` line of `worker/wrangler.toml` (the file is embedded) | R-RG8 | fails |
| L0 | `tests/unit/NetTest.roc` (driver `l0-1`): the `Net.registry` rows: nothing gives `Url(default)`, `direct` in `config.toml` gives `Direct` | R-RG1, R-RG2 | fails |
| L2 | `registry/rg2-default-registry` (3 runs): no registry anywhere: the closure POST goes to `https://registry.roc-talon.org`, the index dir is `https_registry.roc-talon.org`; `TALON_REGISTRY=direct` gives the direct calls; the default host in upper case with port 443 and a trailing `/` is the same host | R-RG2, R-RG7, R-RG1, R-RG8, R-AL2, R-AP16, R-DT5, R-RG4, R-IX3 | fails (run 1: exit 2, `direct has no log`) |
| L2 | `registry/rg2-config-direct` (3 runs): `registry = "direct"` in `config.toml` keeps `direct` (no request to the host; `--snapshot log:30` is exit 2); `--registry <default>` over it | R-RG2, R-RG1, R-RG7 | passes now (a guard of the "user who wants direct" rule) |
| L2 | `registry/rg2-example-add-short` (2 runs): the design example `tln add parser@2.0.0` (CLI 1) and its JSON form (CLI 3), with the default registry: short name, guard, R-AP1, closure. The expected files have the text of the code (question Q1) | R-RG2, R-AD34, R-AD35, R-AD2, R-AP16, R-DT5, R-J3, R-SN1 | fails (exit 2: `known is a short name, and GitHub has no index of short names`: the default is `direct`) |
| L2 | `registry/rg9-default-down` (1 run, `--json --quiet`): the default does not answer (no DNS) at the first registry request: fall back to direct, exit 0, the warning also with `--quiet`, `data.notes[]` has the note `registry-direct` | R-RG9, R-RG2, R-FL4, R-J3, R-DI14 | fails (exit 15 with the old message) |
| L2 | `registry/rg9-closure-503`: the default answers 503: fall back, exit 0, the warning (cause `503 busy`) | R-RG9, R-RG2 | fails (exit 15) |
| L2 | `registry/rg9-toolchains-down`: `tln roc update`, the toolchain read has no answer: the whole run is direct, the list comes from GitHub, the compiler is installed, exit 0, the warning | R-RG9, R-CV1, R-IX4, R-CM15 | fails (exit 15) |
| L2 | `registry/rg9-closure-429`: the default answers 429: no fall back, exit 15 (R-E6) | R-RG9, R-E6, R-AP25 | passes now (guard) |
| L2 | `registry/rg9-set-down` (2 runs): a set registry (`TALON_REGISTRY`, `--registry`) gives no answer: exit 15, message with the URL, the source and the fix | R-RG9, R-RG1, R-E6 | passes now (guard) |
| L2 | `registry/rg9-later-down`: the short name is answered, then the release read has no answer: exit 15, no fall back | R-RG9, R-DI14, R-AD34, R-AD35 | fails (stderr: no source, no fix) |
| L2 | `registry/rg9-login-down`: `tln share login` with the default and no answer to `POST /v1/tokens`: exit 15, no fall back | R-RG9, R-SH10, R-SH7 | fails (stderr: no source, no fix) |
| L2 | 109 existing cases get the line `TALON_REGISTRY=direct` in `fx/env` (list below) | R-RG2 | pass before and after |
| L4 | `tests/scenarios/registry/rn1-add-short` (tag `net`): `tln add semver@0.2.0 --dry-run` on the real Worker: short name, guard (GitHub, no token), releases | R-RG1, R-RG7, R-AD34, R-AD35, R-AP1, R-RG4 | passes now (the Worker is deployed, the client reads a URL setting) |
| L4 | `rn2-add-closure` (tag `net`): `tln add Karakatiza666/roc-semver@0.2.0` writes the header, then `tln update --dry-run --json` sends the closure query (`data.snapshot` is `log:<n>`) | R-AD2, R-AP1, R-AL2, R-AP16, R-DT5 | passes now |
| L4 | `rn3-routes` (tag `net`, `curl`, no `tln`): artifacts, group read, toolchains, compat and the ingest of the release that is already in the registry (a repeat, no new row) | R-AP2, R-AP4, R-AP5, R-AP9, R-AP13, R-AP23 | passes now |
| L4 | `rn4-default-host` (tags `net exdev`: skipped): the same command as `rn1` with no `TALON_REGISTRY`, so the default host answers; the index dir name; `curl` to the host | R-RG2, R-RG7, R-RG8 | skipped |
| L4 | `rn5-login-jwt` (tags `net exdev`: skipped): `tln share login`, the JWT with `iss` and `aud` of the default host | R-AP37, R-SH7, R-SH12, R-RG8 | skipped |
| L4 | `rn6-publish-oidc` (tags `net exdev`: skipped): `tln publish` with a real OIDC token of a job | R-PUB1, R-PUB4, R-RG8 | skipped |

`rn7-toolchains` runs `tln upgrade roc --dry-run --no-check`: `tln roc update` reads the list but has no dry-run form (it installs the newest compiler), and `roc list --available` does not exist.

Skip reason of `rn4`, `rn5`, `rn6` (also in the file `skip-reason` of each case): registry.roc-talon.org does not resolve yet (zone on Porkbun). The runner has no tag that skips with a reason. They have the tags `net blocked` (G-C229): the runner always skips them and prints `blocked: <first line of skip-reason>`. `rn7-toolchains` (skip-reason: no toolchain row until the compat bot runs) is the 4th blocked case. Remove `blocked` when the cause is gone.

The L4 cases use `TALON_REGISTRY=https://talon-registry.bellup.workers.dev` (the deployed Worker, no audience) from `given/env`. They check facts (exit code, the hash, the line `resolved at log:`), not the whole text, because the answers have live values. The only write to the live registry is the ingest of `rn3`: a public release that is already there (Karakatiza666/roc-semver 0.2.0, hash `BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i`). No GitHub token is used: the case gets `GITHUB_TOKEN` and `GH_TOKEN` only from the caller (R-RG3, tests/run.sh), and the run of this slice had none.

## Existing L2 cases that relied on the default `direct`

With the change, 109 of 515 cases failed (checked in a private copy of the code with the 2 edits, deleted). All the 109 are fixed in the tests with one line, `TALON_REGISTRY=direct`, at the end of `fx/env` (the case keeps its meaning: R-RG1 gives `direct` as the winner, as the L3 runner does, TESTING.md 3.2). A `env:TALON_REGISTRY=` word of a command line still replaces it.

| Area | Cases |
| --- | --- |
| tool | 19 |
| roc | 19 |
| upgrade | 14 |
| init | 7 |
| patch, evidence, consent | 4 each |
| target, share, ptool, proxy, probe, outdated, moves | 3 each |
| x, workspace, verify, install, closure | 2 each |
| update, remove, prompt, ladder, gaps, fetch, clean | 1 each |

The full list is `git diff --name-only -- tests/commands/cases '*/fx/env'`. The copy of the code with the change passed all 517 cases (515 old, 2 new).

## Output (proposed, TW24)

| Text | Form |
| --- | --- |
| R-RG9 stop of a command that needs a registry (proposal, Q602) | `tln: error[network]: the registry <url> (<source>) gave no answer: <cause>.` and `... answered <status>: <detail>.`: the URL and the source, and NO sentence about `direct`. For `share login`, `logout`, `forget`, `probe --share`, `publish`, `yank`, `move`. `publish` keeps its form: `the registry <url> (<source>) gave no answer 4 times: <cause>. The publish may be done. Run the command again.` |
| R-RG9 fall back warning (proposal, Q601 item 3) | `warning: the default registry <url> does not answer (<cause>): this run uses GitHub (direct)` on stderr, also with `--quiet`. `<cause>` is `could not resolve host: <host>` or, for a 5xx, `<status> <word>` (`503 busy`). With `--json`: `data.notes[]` item `{"kind":"registry-direct","registry":"<url>","cause":"<cause>"}` (before the other notes), and `error.details.notes` for a failed run |
| R-RG9 stop of a set registry, and of a later failure (proposal) | `tln: error[network]: the registry <url> (<source>) gave no answer: <cause>. Use --registry direct, or registry = "direct" in config.toml, to read GitHub in place of it.` `<source>` is `the built-in default`, `--registry`, `TALON_REGISTRY` or `config.toml`. Now the code prints `the registry <url> gave no answer: <cause>. Try again later.` |
| New text of the code | none. The default changes a value, not a text. The messages of R-RG7 row 6 name the source (`--registry`, `TALON_REGISTRY`, `config.toml`), never the default |
| The design example `tln add parser@2.0.0` (CLI 1) | The code prints `matched "known": acme/known`, `<path>: <alias> = "=1.1.0"` lines, and `resolved at log:50, 0 probes`. The example of the design has `resolved 4 packages in 41ms (log:184467)`, `probed 3 times on 1 nightly (0 downloads)`, `matched "parser" to <name>`. See question Q1 |
| The JSON example (CLI 3) | The code gives `data.snapshot`, `log_size`, `probes`, `downloads`, `dry_run`, `check`, `build`, `added`, `moved`, `kept`, `pinned`, `toml`, `renamed`, `notes`, `written`. The example shows `snapshot`, `probes`, `downloads`, `added` (the example says "data fields are shortened") |

## Out of scope

| Item | Why |
| --- | --- |
| The check of the live default host (R-RG8) | The host does not resolve yet. Cases `rn4` to `rn6` wait |
| The audience cases (login JWT, publish with OIDC) | Same reason. They also need a person (login) and a GitHub Actions job (publish) |
| A fallback to `direct` when the registry host does not answer | The design does not say (question Q3) |
| `tln tool update talon` and the release that carries the constant | CLI 6.5, other slices |
| The probe line (`probed 3 times on 1 nightly`) of the example | It needs unit probes in a registry run. The L2 world uses `--no-check` (as `registry/ad35-add-latest`) |

## Questions (TW17)

| # | Question | Test change |
| --- | --- | --- |
| Q1 (answered Q599, G-C228: the design example now equals the code text; `rg2-example-add-short` stays, checked against the CLI 1 example: same command shape, `matched`, `resolved at log:<n>, 0 probes`) | The design examples of CLI 1 (`tln add parser@2.0.0`) and CLI 3 (JSON) have text that the code does not print (see Output). TW16 says the example is a case, and "If the design changes the example, the case changes". Which one changes: the example (to the text of the code) or the code (to the text of the example)? The slice does not choose: `rg2-example-add-short` has the text of the code, as the precedent of slice 053 (finding F2) | The expected files of `rg2-example-add-short` and one test of the code agent, after the answer |
| Q2 (answered G-C229: tag `blocked`; `rn4` to `rn7` use `net blocked`) | The runner `tests/run.sh` has no tag that skips a case with a printed reason. The 3 cases that wait for the host use `net exdev`, which is wrong in name. May the owner of `tests/run.sh` add a tag (for example `blocked`, with the text of `skip-reason`)? | Replace the tag `exdev` in 3 `tags` files |
| Q3 (answered Q600, R-RG9: exit 15, no fall back, URL and source named, the fix `--registry direct` or `registry = "direct"`; case `rg9-default-down`) | The default registry host does not answer (no DNS, a failed zone, an outage). The design does not say what a command does: stop with exit 15 (R-E6) with the registry URL named, or fall back to `direct` for this command. Until then each command that reads the default stops as a command with a set registry stops | L2 case, after the answer |
| Q4 (G-C231: goes to the user; Q600 says the release waits for the host) | R-RG2 says the user moves to the registry with `tln tool update talon`. Between the release that carries the constant and the day that `registry.roc-talon.org` resolves, the default breaks each command that reads it. Should the release of Talon wait for the host (a release step), or is a user of that window expected to set `direct`? | None (a release rule) |
| Q5 (answered G-C232: `rn3` stays curl only; blocked case `rn7-toolchains`, no seed of the live D1) | `tln roc` reads of the compiler list (R-CV1) use the same default. The live Worker has no toolchain row (`GET /v1/toolchains?after=0` gives `{"toolchains":[],"more":false}`), so no `tln` command can be tested for the toolchains route with real data. `rn3` checks the route with `curl` only. Should the Worker get a row first (slice 109 data), or is this enough? | An L4 case with a `tln` command, after the answer |

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-6.roc` | 4 of 134 fail: the 4 new expects of `IndexqueryTest` (the default is still `direct`) |
| `roc test tests/unit/l0-1.roc` | 1 of 204 fails: `NetTest` registry rows |
| `tests/commands/run.sh rg2-` | `rg2-default-registry` and `rg2-example-add-short` fail (run 1: exit 2 `snapshot log:30 needs a registry: direct has no log`; the example: exit 2, a short name needs a registry). `rg2-config-direct` passes (guard) |
| `NET=1 OPT=speed tests/run.sh registry/rn` (one live run, no token) | `rn3` pass (all 5 routes, the ingest repeat answered 200). `rn1` and `rn2` failed on 3 faults of the case files (a hash that `--dry-run` does not print, the expected `roc.log` and `tree.diff`, and a text line of `update` that I guessed). The 3 are fixed in the files, and NOT run again (one live run only). `rn4` to `rn6` skipped |
| `MISSING=1 scripts/rules.sh R-RG` | no id with no test |

## Code (code agent)

| File | Change |
| --- | --- |
| `cli/lib/Help.roc` | New constant `Help.default_registry` = `https://registry.roc-talon.org` (R-RG2, Q207, Q208). Help is imported by `Net` and `IndexQuery` with no import cycle |
| `cli/lib/IndexQuery.roc` | `setting`: the last arm gives `Registry(Help.default_registry)`. New `IndexQuery.source` (the place of the setting: `--registry`, `TALON_REGISTRY`, `config.toml`, `the built-in default`) |
| `cli/lib/Net.roc` | `Net.registry`: `Err(Unset)` gives `Url(Help.default_registry)` |
| `cli/lib/Registry.roc` | New `Registry.no_answer_from` (R-RG9): rewrites a `no_answer` failure with the source and the way to `direct`. Other failures stay |
| `cli/lib/ResolveBase.roc` | `Query` has the new field `source : Str` |
| `cli/lib/InstallFlow.roc` | `with_setting` fills `source`. The `Offline` row gives `"the registry setting"` (no request is sent) |
| `cli/lib/PickFlow.roc` | `query!` maps the failure of `ClosureIndex.query!` with `Registry.no_answer_from` |

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-6.roc`, `l0-1.roc` | pass |
| `tests/commands/run.sh rg2- rg9` | 4 of 4 pass |
| `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2` | all pass (l0 15.5 s, over the 10 s budget: WARN only) |
| `JOBS=1 scripts/test.sh l3` | pass (82.3 s, over the 60 s budget: WARN only) |

Known gap (not a dispute): R-RG9 names the source only for the closure query (`PickFlow.query!`). A registry read of the compiler list (`RegistryToolchains.list!`, `RegistryCache`) and a 5xx answer (`Registry.refuse`) keep the old text without the source. The design text of R-RG9 covers them. No test shows them yet.

### Round 2 (stopped by the manager, design change)

State: STOPPED, NOT FINISHED. `roc check cli/main.roc` fails (1 error, `cli/lib/RocInstall.roc:156`: `range_id!` has a `registry` record with no `source`). No test was run after round 2. Do not make `rg9-*` green against the old expects: R-RG9 changes (the default host with no answer goes on in `direct`, not exit 15).

| File | Round 2 edit | State |
| --- | --- | --- |
| `cli/lib/Registry.roc` | `no_answer_from` removed. `no_answer` and `refuse` take `source ?: Str`. New `Registry.stop_text` (one text). 5xx with a source gives the stop text | done, not checked alone |
| `cli/lib/ClosureIndex.roc` | `query!` and `send!` take `source ?:` and pass it to `no_answer` and `refuse` | done |
| `cli/lib/LogSnapshot.roc`, `cli/lib/UnknownValues.roc` | `second!` and `settle!` pass `source` | done |
| `cli/lib/PickFlow.roc` | `Second` has `source`. `query!`, `settle!` and `second!` get `query.source`. The `Registry` import and the `map_err` are removed | done |
| `cli/lib/RegistryToolchains.roc` | `list!`, `fetch_pages!`, `fetch_page!`, `offline_list!` take `source ?:` | done |
| `cli/lib/Nightlies.roc` | `Source.Registry` has `source : Str`. `list_registry!` takes `source ?:` | done |
| `cli/lib/IndexQuery.roc`, `cli/lib/ResolveBase.roc` | `list_source` and the `Registry(..)` rows fill `source` (Offline row: `""`, no request is sent so no message reaches a user) | done |
| `cli/lib/RocInstall.roc` | `range_id!` passes `source: r.source` | BROKEN: the `registry` record of `range_id!` (annotation line 143 and the `Ok({ origin, version, log })` at line 150) needs a `source` field |

Round 2 update: the tree compiles again. `RocInstall.range_id!` has `source` in its `registry` record, and `ResolveSelect.registry_of` gives `source` (`IndexQuery.source`, or `query.source` for a `Read`). No fall back to `direct` was added. Run `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt l0 l2`: check pass, fmt pass, l0 pass, l2 519 pass and 2 fail (`registry/ap23-http-writes`, `registry/dt3-update-range-log`). The 2 fail alone again too. They read `toolchains?after=40` and `log_index` values that differ from the code (`after=41`): the fake routes of slice 224 are being edited in `tests/commands/cases/registry/*/fx/http` (git diff shows them changed), not a fault of this code. The 3 `rg9-*` cases passed in this run.

## Round 3 (R-RG9 changed by the user, Q600, Q601)

Only the built-in default falls back to direct, at the first registry request of the run. A set registry, a later failure, a command that needs a registry, a 429 and a 4xx are exit 15. The 7 cases above are the 7 rows of Q601. The expected files of `rg9-default-down`, `rg9-closure-503` and `rg9-toolchains-down` are a proposal built by hand from the direct runs (`registry/rg2-default-registry` run 2, `roc/up1-update` run 1, a `--json` direct run) after the failed registry call: the code agent may dispute the order of the calls. Doubts: D1 the cause text of a 5xx; D2 the guard runs before the failed closure POST (as the code does now); D3 `rg9-toolchains-down` installs a compiler (the fake jobs), as `roc update` does.

### Round 3 (code agent): R-RG9 fall back

| Part | Where | State |
| --- | --- | --- |
| Structured cause | `Fail.fallback` (`Ok(cause)`), set by `Registry.no_answer` and `Registry.refuse` (5xx) only when the source is `Help.default_source`. No message is parsed. `Registry.stop_text` is the one text of the stop | done |
| First closure query | `PickFlow.query!`: on `fallback` it prints the warning, sets `request.registry` to the new `Fell({ registry, cause })` and goes on as `direct` | done |
| First compiler list | `Nightlies.list_of!`: on `fallback` (and no `--snapshot log:N`) it prints the warning and reads the GitHub list. New field `via` gives the `digest` source (`github-digest` after a fall back) | done |
| `--json` note | `InstallFlow.Done.fell`, `Update.with_direct_note`: `registry-direct` is the first of `data.notes` | done for `update` (the path of the case). `add`, `install`, `upgrade`, `verify` print no note yet: they do not use `Update.print!`. `error.details.notes` is not done |
| Source in the stop text | closure queries (first, second, settle), toolchain list, short names and full names (`get_via!`, `lookup_via!`, `read_via!`), `share login` | done. Other registry reads (`share logout`, `forget`, `probe --share`, `publish`, ingest) still print the text with no source |
| Fall back at the short-name read of `add` (the first request of `add known@..`) | not done: `PickAsk.short_names!` has no way to change the request. The case `rg9-later-down` passes because the later read fails with the source text |
| Optional `source ?:` | A test passes a record in a variable, and an optional field is accepted only in a record literal. So `get!`, `lookup!`, `read!` keep their facts and call `get_via!`, `lookup_via!`, `read_via!` | done |

Results: `tests/commands/run.sh rg9 rg2-`: 10 of 10 pass. `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2`: check, fmt, selftest, l0 pass, l2 524 pass and 1 fail. `JOBS=1 scripts/test.sh l3`: pass. `ap23-http-writes` and `dt3-update-range-log` passed in this run.

## Disputes (from the code agent)

| # | Case | Dispute |
| --- | --- | --- |
| D1 | `share/sh27-login-no-answer` | The case has `TALON_REGISTRY=http://127.0.0.1:9` (a set registry) and expects `the registry http://127.0.0.1:9 gave no answer: no answer in 20 s. Try again later.` R-RG9 says a set registry gives a message with its source and the fix, and `rg9-login-down` expects that text for the default. The code gives `... (TALON_REGISTRY) gave no answer: ... Use --registry direct, ...` for both. The expected stderr of `sh27` needs the R-RG9 text, or R-RG9 must say that `share login` keeps the short text for a set registry. I did not change the test or bend the code |

## Round 4 (the parts of R-RG9 that no case checked)

| Layer | Case | Rules | Red state now |
| --- | --- | --- | --- |
| L2 | `registry/rg9-short-down` (2 runs): `tln add known@1.1.0` with the default; the short-name read is the first registry request and has no answer: fall back to direct, which has no short names: exit 2 with the text of direct, after the warning. Run 2 (`--json`): a run that fails after the fall back has the note in `error.details.notes` | R-RG9, R-AD34, R-J3, R-J5 (Q601 items 1, 3, 5) | fails: exit 15, no fall back for the short-name read (and no note) |
| L2 | `registry/rg9-install-note`: `tln install --json` (not `update`) with the default and no answer to the closure query: the note `registry-direct` is the first entry of `data.notes` | R-RG9, R-J3, R-AL2 (Q601 item 3) | fails: the run falls back and prints the warning, but `data.notes` is `[]` |
| L2 | `registry/rg9-logout-down`: `tln share logout` with the default and no answer to `DELETE /v1/tokens`: exit 15, the stop message with the URL, `(the built-in default)` and the fix | R-RG9, R-SH9, R-AP38, R-E6 (Q601 item 4) | fails: stderr lacks the source and the fix |

The expected files of `rg9-short-down` are a proposal built from the current calls (the registry attempt, then the direct stop: the direct run of the same commands has the same calls without the attempt) and the direct texts. The expected files of `rg9-install-note` are the current output with the note added.

The 5 existing cases `share/sh47-delete-fails`, `registry/ap24-read-cache`, `registry/ap20-closure-errors`, `registry/ap5-toolchain-rows`, `probe/ps4-share-answers` pass now with the OLD text (`the registry <url> gave no answer: <cause>. Try again later.`): the current build does not give them the R-RG9 text for a registry that the user set. I kept their expects. They are targets for the code agent: each stop on a registry read of a set registry needs `(<source>)` and the fix. `share/sh41-status-get-fails` is a warning and stays.

### Round 4 (code agent)

| Target | Change | State |
| --- | --- | --- |
| `rg9-short-down` | `PickAsk.short_names!` falls back on `Fail.fallback`: warning, no entries, `fell`. `PickAsk.asked!` gives `Asked.fell` and puts the note on a later failure (`Fail.with_fell`). `PickFlow.prepare!` sets the request to `Fell` and the index to `Direct` | pass |
| `rg9-install-note` and the note for each command | One place for success: `Out.with_fell_note` (used by `Update.print!`, `Install`, `Verify`; they have `done.fell` from `ResolveBase.fell_of`). One place for failure: new `Fail.fell`, put in `error.details.notes` by `Out.error_doc`; set by `Fail.with_fell` in `InstallFlow` and `VerifyFlow`. `outdated` and `why` still print no note (they have no `Done.fell`) | pass for update, install, add, upgrade, init, verify. Open: outdated, why |
| `rg9-logout-down` | `ShareAccountFlow.Start.setting` goes to `ShareAccount.delete_answer` (logout and forget) | pass |
| Source on each registry stop of a set registry | `probe --share` (`ProbeShareFlow.check!` returns `setting`; `Input.setting ?:`), `publish` (`PublishFlow.Run.setting`, `Publish.failure`), `share login`, `share logout`, `share forget`, closure queries, toolchain list, short and full names, `init`, `tool install` | done. `share status` (tracker read) keeps the short warning text on purpose (`sh41`) |

The old names `RegistryCache.get!`, `FullName.read!`, `ShortNames.lookup!` (empty source): in `cli/` only `ClosureIndex.roc:275` calls `RegistryCache.get!` (an offline read of kept files: no request, no stop text). All other real paths call `get_via!`, `read_via!`, `lookup_via!` with the real source. `tests/commands/L2Registry.roc` calls the 4 old names (lines 71, 157, 195, 336).

Cases whose expected text changes with this code (not edited; the test agent updates them):

| Case | New stderr line |
| --- | --- |
| `probe/ps9-share-command-fails` | `tln: error[network]: the registry http://127.0.0.1:9 (config.toml) answered 503: the registry is busy. Use --registry direct, or registry = "direct" in config.toml, to read GitHub in place of it.` (was `the registry is busy (503). Try again later.`) |
| `share/sh47-delete-fails` (line 1) | `tln: error[network]: the registry http://127.0.0.1:9 (TALON_REGISTRY) gave no answer: no answer in 20 s. Use --registry direct, or registry = "direct" in config.toml, to read GitHub in place of it.` |
| `share/sh47-delete-fails` (line 3, a 502 with detail `D`) | `tln: error[network]: the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 502: D. Use --registry direct, or registry = "direct" in config.toml, to read GitHub in place of it.` (the 429 line stays) |
| `registry/ap20-closure-errors`, `registry/ap24-read-cache`, `registry/ap5-toolchain-rows`, `probe/ps4-share-answers` | pass with the OLD text: their test apps (`tests/commands/L2Registry.roc`, `L2ProbeShare.roc`) call the functions with no source. They need the test app to pass the real source (the code gives the R-RG9 text when it gets one) |

Results: `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2`: check, fmt, selftest, l0 pass; l2 526 pass, 2 fail (`ps9-share-command-fails`, `sh47-delete-fails`: the new text above). `JOBS=1 scripts/test.sh l3`: pass. The 3 `rg9-*` cases of round 4 pass. D1 (`sh27`) no longer fails.

## Round 5

| Layer | Case | Rules | State |
| --- | --- | --- | --- |
| L2 | `probe/ps9-share-command-fails`, `share/sh47-delete-fails` (lines 1 and 3): the stderr is now the R-RG9 text of a set registry (`(config.toml)` and `(TALON_REGISTRY)`, the fix). Nothing else changed in the output (checked in the diff). R-RG9 added to the rule ids | R-RG9, R-E6 | pass |
| L2 | `registry/ap24-read-cache` (the no-answer line), `probe/ps4-share-answers` (503, no answer, connection refused): the test apps `tests/commands/L2Registry.roc` and `L2ProbeShare.roc` now pass the source `TALON_REGISTRY` (`get_via!`, `lookup_via!`, `read_via!`, `setting`: they model a registry that a person set, the origin is fixed). Only those lines of the expects changed | R-RG9 | pass |
| L2 | `registry/ap20-closure-errors`, `registry/ap5-toolchain-rows` | R-RG9 | unchanged: they pass with the old text, so their paths do not use the 4 functions of the apps (the closure query and the toolchain read have their own calls). Targets for a later change of the app or the code, to be named by the manager |
| L2 | `registry/rg9-add-full-down`: `tln add acme/known@1.1.0` with the default and no answer at the R-AP1 read (after the guard): fall back to direct. The fake GitHub has no release list, so direct stops with its text, exit 2, after the warning | R-RG9, R-AD35, R-AP1, R-DI2 | fails (exit 15, no fall back) |
| L2 | `registry/rg9-outdated-note`: `tln outdated --json` after a fall back: the note `registry-direct` is in `data.notes` (a new member after `members`: `outdated` has only `members` and `index_notes` now) | R-RG9, R-J3 | fails (warning only, no note member) |

Not written, with the reason:

| Item | Reason |
| --- | --- |
| `why` after a fall back | `why` reads no registry in the current design (Design Q209 is open), so there is no fall back to show |
| Publish retry with no answer | Question Q6 below |
| Ingest stop on a set registry (5xx or no answer) | Question Q7 below |

| # | Question | Test change |
| --- | --- | --- |
| Q6 (answered Q602, G-C233: URL and source, no fix, for publish, yank, move, share login, logout, forget, probe --share; publish keeps its form with the source added) | R-PUB4 item 9 keeps the form `<Registry.refuse text> after 4 requests` for a 429 or a 503 after the retries of R-AP34, and the "may be done" text of item 6 for a cut request. R-RG9 says each stop on a set registry has the URL, the source and the fix. Do the publish texts get the source and the fix too, and where (`... after 4 requests. Use --registry direct ...`)? A publish needs a registry, so `direct` cannot be the fix of a publish: should the fix part be left out for `publish`, `yank` and `move`? | A case `publish/...` after the answer |
| Q7 (answered Q603, G-C234: the ingest warning does not change, no case) | R-AD35 and Registry R-AP28 (Q421): an ingest with no answer or a 5xx is a warning with the URL (case 3), the command goes on, the exit code does not change. Only a 429 stops (exit 15). So an ingest has no stop text with the source for a 5xx or no answer. Is the warning also given the source, or does it stay as it is? | A case after the answer |
| Q8 (answered Q604, G-C235: a new member `notes` after `members`; `why` gets nothing) | `tln outdated --json` has `index_notes` for its notes (R-AP30). R-RG9 says `data.notes[]`. Is the note a new member `notes`, or an item of `index_notes` (its items have `kind`, `name`, `checked_at`, `text`)? The case has a new member `notes` | The expect of `rg9-outdated-note` |

## Round 6 (Q602 to Q604)

| Layer | Case | Rules | State |
| --- | --- | --- | --- |
| L2 | The stderr of `registry/rg9-login-down`, `registry/rg9-logout-down`, `share/sh27-login-no-answer`, `share/sh47-delete-fails` (2 lines), `probe/ps9-share-command-fails` and `probe/ps4-share-answers` has no fix sentence (the rest of each line is unchanged). Other cases with the fix sentence keep it: `rg9-later-down`, `rg9-set-down` (commands that can run direct) and `ap24-read-cache` | R-RG9 | the first 5 fail now (the code still prints the fix); `ps4` passes (its path already has no fix) |
| L2 | `publish/rg9-publish-no-answer`: 4 requests with no answer on a set registry (`TALON_REGISTRY`): exit 15, `gave no answer 4 times: <cause>. The publish may be done. Run the command again.` with `(TALON_REGISTRY)` after the URL, no fix | R-RG9, R-PUB4 items 6 and 9, R-AP34, R-E6 | fails (the text has no source) |

R-PUB4 item 9 gives the form `after 4 requests` for a 429 or a 503 and item 6 gives the "may be done" text for a cut request. The code prints `gave no answer 4 times` for no answer (case `publish/pu7-retries-exhausted` has `answered 502 (...) 4 times`); the new case keeps that form and adds the source. `pu7-retries-exhausted` (a 502 four times on a set registry) is not changed here: it has no source in its text either, so the code agent's change for Q602 will change it too (the manager decides).

Round 6b: `publish/pu7-retries-exhausted` (a 502 four times on a set registry) now expects `the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 502 (/errors/upstream) 4 times. Try again later.` (URL and source, no fix; R-RG9 added to its rule ids). No other `publish` case has a stop on a no-answer or a 5xx without the source (the other `the registry` lines are answers of 4xx or usage stops), and there are no `yank` or `move` L2 cases.

### Rounds 5 and 6 (code agent)

| Part | Where | State |
| --- | --- | --- |
| One place for the first-request fall back | New `cli/lib/Fallback.roc`: `Fallback.decide!(fx, fail, origin)` gives the warning and `Fell`, or the failure. Used by `PickAsk.short_names!`, `PickFlow.fresh_items!` (full names), `PickFlow.query!` (closure) and `Nightlies.list_of!` (compiler list). The warning text is only in `Fallback` | done |
| Only the first request falls back (R-RG9 row 2) | `Asked.answered`, `fresh_items!` and `query!` take a `first` flag (no earlier registry answer). `Nightlies.Source.Registry.first` (`ResolveBase.no_answer_yet`: the index is no `Answer`). A later failure is exit 15 with the source text (`rg9-later-down`) | done |
| `rg9-add-full-down` | the full-name read falls back, then the run is `direct` | pass |
| Q602 stop text | One text: `Registry.stop_text` with the flag `needs`. `needs` true (publish, share login, logout, forget, probe --share) gives URL and source with no fix sentence. A read that `direct` can do keeps the fix sentence | done |
| Q602 publish | `Publish.failure` puts ` (<source>)` after the URL for the retry texts (`who`, `Publish.source_text`) | done |
| Q603 | the ingest is not changed | done |
| Q604 | `Out.with_fell_member`: member `notes` after `members` in `outdated --json`. `OutdatedFlow.flow!` gives `fell` | pass |

Known gap: when the compiler list falls back first (`Nightlies.list_of!`) a later closure query of the same run, in a flow that reads the list before the query (`outdated`, `update` with a free compiler), still asks the registry again, and falls back again with a second warning. The state of a fall back in `list_of!` does not reach the request. A case with this order does not exist.

Results: `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2`: 530 pass, 1 fail. `JOBS=1 scripts/test.sh l3`: pass.

Dispute D2: `probe/ps5-share-batches` expects `tln: error[network]: the registry is busy (503). Try again later.` for `probe --share` with `TALON_REGISTRY` set. Q602 says `probe --share` names the URL and the source with no fix. The code gives `tln: error[network]: the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 503: the registry is busy.` The expected stderr of the case needs this line.

## Round 7

| Layer | Case | Rules | State |
| --- | --- | --- | --- |
| L2 | `probe/ps5-share-batches`: the 503 line is `the registry http://127.0.0.1:9 (TALON_REGISTRY) answered 503: the registry is busy.` (the only change of its output; R-RG9 not in its rules line before, now added). Dispute D2 resolved | R-RG9, Q602 | passes now |
| L2 | `registry/rg9-list-then-closure`: `tln outdated` (the Report window, a free nightly) with the default registry. The compiler list read (`GET /v1/toolchains?after=0`) is the first registry request and has no answer: the whole run is direct: one warning, NO closure POST, exit 0. `upgrade roc` was tried first and dropped: its direct run downloads a compiler (the fake sha256 differs, exit 16). The expected `calls.log` is a proposal: the current prefix up to the failed list read, then the direct run (the nightlies list, then the package lists), the order after the list read is a guess | R-RG9, R-DI14, R-CV1, R-AL2 | fails: the code asks the registry again (guard, closure POST) after the failed list read |

### Round 7 (code agent)

| Part | Where | State |
| --- | --- | --- |
| The list fall back reaches the request | `Nightlies.list_of!` gives `fell`. `PickLoop.first_releases!` gives `{ releases, fell }`. `ResolveBase.routed(request, fell)` is the one place that makes a request `direct` (`Fell`); `PickFlow` (short names, full names) and `OutdatedFlow` use it. After the list fall back, `outdated` sends no guard and no closure POST, and prints one warning | done for `outdated` |
| Same order in `NightlyFlow.plan!` (`update` and `upgrade` with a free compiler) | not wired: its plan has no field for `fell`. The case for this order does not exist | open |

`registry/rg9-list-then-closure`: stderr, stdout and the registry calls are as expected (one warning, no registry call after the list read). Only the position of 2 calls differs.

## Disputes (round 7)

| # | Case | Dispute |
| --- | --- | --- |
| D3 | `registry/rg9-list-then-closure` `expect/calls.log` | The case expects `db_query compat.db pinned=12` and `db_write` after the 3 package release reads. The code does them right after the GitHub nightlies list: `Nightlies.list!` pins the list rows in the same step (`Nightlies.list_registry!` does the same after the registry rows, slice 204). The order of the 2 db calls is no design rule (R-CV3 gives no order against the package reads). I did not change the code or the case. The expected `calls.log` needs the 2 lines after `write_atomic .../index/github/roc-lang/nightlies/1.json ...`, or the design must say the order |

Results: `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2`: 531 pass, 1 fail (`rg9-list-then-closure`, D3). `JOBS=1 scripts/test.sh l3`: pass.

## Round 8

| Item | Result |
| --- | --- |
| D3 (order of the pin lines) | In the plain direct run of the same command (and in `outdated/od1-table`) `db_query ... pinned=` and `db_write` come right after `write_atomic .../index/github/roc-lang/nightlies/1.json`. The 2 lines are moved there in the expected `calls.log` of `registry/rg9-list-then-closure`, before the package release lists |
| `rg9-update-list-then-closure` | Not written. `tln update` does not read the compiler list in a world that avoids a download: `NightlyFlow.plan!` is called for `upgrade` with a free nightly only (`InstallFlow.roc` line 241, 267), and `update` holds the pin. With an installed compiler (a pin on PATH or no pin) a trial run made no `GET /v1/toolchains` at all. The list is read by `update` only when a compiler must be offered, that is, downloaded (`registry/cv1-held-offer`, `cv1-held-pick`). `upgrade roc` downloads in direct mode (fake sha256, exit 16). `outdated` (round 7) is the case that shows the order |

## Round 8b

| Layer | Case | Rules | State |
| --- | --- | --- | --- |
| L2 | `registry/rg9-upgrade-list-then-closure`: `tln upgrade roc` (a free nightly, `NightlyFlow.plan!`) with the default registry and no answer to `GET /v1/toolchains?after=0`: the whole run is direct, one warning, the GitHub nightly list, the fake download (the digest of the GitHub list is the fake sha256, as in `roc/up1-update`), no guard and no closure POST, exit 0 | R-RG9, R-DI14, R-CV1, R-CV3, R-AL2 | fails: exit 15, `no cached list of compilers and --offline is set` after the warning |

The expected calls are the plain direct run of the same world with the 3 lines of the failed list read after `platform`. This replaces the round 8 remark that no world avoids a download: in L2 the downloads are fakes.

### Round 8 (code agent)

`NightlyFlow.plan!` carries `fell`: `NightlyFlow.listed!` gives `{ releases, fell }`; the plan routes the request with `ResolveBase.routed` (so the offers read the GitHub list, not the kept registry list) and gives `Plan.fell`; `InstallFlow` routes the request again before the closure query (`after_plan`). The cause of the old exit 15 (`no cached list of compilers and --offline is set`) was the offer of the new compiler: it still read the kept registry file after the fall back. `registry/rg9-upgrade-list-then-closure` passes. The gap of round 7 (`NightlyFlow.plan!` not wired) is closed. No dispute.

Results: `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2`: all pass (l2 with no failure). `JOBS=1 scripts/test.sh l3`: pass.

## Round 9 (the zone moved: https://registry.roc-talon.org serves the Worker)

| Case | Change | Live result (one run, `NET=1 OPT=speed`, no GitHub token) |
| --- | --- | --- |
| `rn1`, `rn2`, `rn3` | `TALON_REGISTRY=https://registry.roc-talon.org` in place of the workers.dev address. They keep the explicit setting (R-RG1 priority 2), so they stay independent of the default | pass (the fixes of round 2 hold) |
| `rn4-default-host` | tags `net` only, no `skip-reason`. The case removes `TALON_REGISTRY`, so it uses the default: the add, the index dir `https_registry.roc-talon.org`, and `curl` of `/v1/toolchains?after=0` gives 200 (R-RG2, R-RG7, R-RG8). `expect/roc.log` added, the hash check removed (as `rn1`) | pass |
| `rn5`, `rn6` | still `net blocked`: "needs a real GitHub token (R-CT8 OAuth App or an Actions OIDC token); no test gives one" | SKIP |
| `rn7` | still `net blocked`: "no toolchain row until the compat bot runs" | SKIP |

The ingest of `rn3` sent only the release that is already there (Karakatiza666/roc-semver 0.2.0): a repeat, no new row.

## Close (manager, 2026-11-06)

| Item | State |
| --- | --- |
| Default | `https://registry.roc-talon.org` (`Help.default_registry`, R-RG2, Q208) |
| R-RG9 | The user's rule (Q600 to Q604): only the built-in default falls back to direct, only at the first registry request; one warning; the `registry-direct` note. A set registry, a later failure and a registry-only command give exit 15 with the URL and the source |
| Mutations | 5 of 5 caught (`research/slice-225-revert/mutate.sh`): m1 a set registry falls back (rg9-set-down), m2 a 429 falls back (rg9-closure-429), m3 a later read falls back (rg9-later-down), m4 no route to direct after the list fall back (rg9-list-then-closure, rg9-upgrade-list-then-closure), m5 the fix sentence for registry-only commands (rg9-logout-down, sh27) |
| Final suite | check, fmt, selftest, l0, l2, l3, l3w pass (time budget warnings only, TW20). `MISSING=1 scripts/rules.sh R-RG`: no rule without a test |
| Exits read | The expected exits of the rg2-* and rg9-* cases agree with the rules (rg2-config-direct run 2 exit 2 is the R-SP log refusal of `direct`) |
| L4 net | rn1 to rn4 pass against `https://registry.roc-talon.org` (one run). rn5 and rn6 are blocked (they need a real GitHub token). rn7 is blocked (no toolchain row until the compat bot runs) |
| Release | The release that sets the default waits for the host (G-C231, Q600). The host now resolves |
| Open, for the user | The proposed texts (TW24): the fall back warning, the stop message with and without the fix, the publish form with the source, the `notes` member of `outdated --json` |

Status: done.
