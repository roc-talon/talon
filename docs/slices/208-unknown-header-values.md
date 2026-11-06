# 208 Unknown header values

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 208 of `PLAN-P2-CLI.md`. A header hash that the closure answer lists in `unknown` (Registry R-AP17) is a value that the registry does not index. Registry R-AP28 gives 3 cases, checked in this order: 1 the label with another hash (warning, no ingest), 2 an ingest of each public `github.com` URL at the same time, then the closure query again once, 3 the archive (R-DI7). A 409 `label-conflict` to an ingest is case 1 (R-AP65 source 2).

## Scope

| In | Out (where) |
| --- | --- |
| New module `cli/lib/UnknownValues.roc` (in `main.roc`): `classify`, `label_warning`, `ingest_requests`, `ingest_verdict`, `largest`, `again_headers`, `anchor_note`, `settle!` | The call of `settle!` inside the commands (where the closure query of a command is made, and what a `Label` or `Archive` value does to the facts of the solver): slice 206b (no command can pick a registry before slices 206b and 224) |
| R-AP28 cases 1 to 3 in order, R-AP65 sources 1 and 2, the second query with `Cache-Control: no-cache` and the largest `Talon-Bookmark` (R-AP41 row 5, R-AP43) | The ingest of a full name that has no release in the registry (R-AD35, R-AD36): slice 212. It can reuse `ingest_requests`, `ingest_verdict`, `largest` and the `http_all!` call |
| R-DA8: up to 4 ingests at the same time with `Fx.http_all!`, no credential header, `programs!(["curl"])` first (Design Q229), exit 18 without `curl` | The printing of `fixed: not in the registry index` by `tln update`, `tln upgrade`, `tln outdated`: slices 206b and 210. Here only the decision `anchor_note` |
| R-AP25 (client): a 429 of an ingest stops the command with exit 15 | The time in the message of a 429 (R-AP25): question Q4 |
| The privacy guard is not called here: the closure query ran it for each `github.com` group and hash (R-AP28, slice 203) | `curl` check text, `--offline` (no registry request, R-AD37) |

## Rules

R-AP28, R-AP65, R-PU40, R-DI7, R-DI11 (registry part), R-AP9 (client part), R-AP25 (client part), R-ID7. As used: R-AP41 row 5, R-AP43, R-AP45, R-AP59, R-AP17, R-AP18, R-AP34 (an ingest is sent once), R-DA8, R-DA9, R-RG4, R-AD35 step 3, R-AD36, R-C9, R-IX3, R-EC18, R-E6, Design Q122, Q164, Q224 to Q229.

## Decisions (pure, L0) and flow (L2)

| Name | Signature | Rule |
| --- | --- | --- |
| `UnknownValues.classify` | `{ unknown, urls, releases, snapshot } -> List({ hash, url, case })`, `case` is `Label({ other })`, `Ingest` or `Archive` | R-AP28, R-AP65 source 1, R-PU40, R-RG4 |
| `UnknownValues.label_warning` | `{ url, hash, other : Try(Str, [None]) } -> Str` | R-AP28 case 1, R-AP65 |
| `UnknownValues.ingest_requests` | `{ origin, version, urls } -> List(<http_send! request>)` | R-AP9, R-AP28 case 2, R-DA8 rule 1, R-AP45, R-AP23 |
| `UnknownValues.ingest_verdict` | `{ origin, version, result : Try(<answer>, [Timeout, Failed(Str)]) } -> Try([Indexed({ bookmark }), Label, Archive, Unindexed({ what })], Fail)` | R-AP28, R-AP65 source 2, R-AP25, R-AP41 row 5, Q421, Q424 |
| `UnknownValues.unindexed_warning` | `{ url, what } -> Str` | Q421 |
| `UnknownValues.largest` | `List(Str) -> Try(Str, [None])` | R-AP41 row 5 |
| `UnknownValues.again_headers` | `{ version, bookmark : Try(Str, [None]) } -> List((Str, Str))` | R-AP28 case 2, R-AP43, R-AP41 row 5, R-AP45 |
| `UnknownValues.anchor_note` | `{ end, url, releases } -> Try(Str, [None])` | R-AP28 (text after the table), R-DI11 (registry), Q425 |
| `Registry.refuse` (slice 201 module) | new optional field `retry_after ?: Str`. The body is not changed yet: with no field or a bad value it is as before | R-AP25, Q424 |
| `UnknownValues.settle!` | `Fx, { origin, version, roots, facts, first, urls, snapshot } => Try({ answer, values }, Fail)` | R-AP28, R-AP65, R-DA8, R-AP34, R-AP18 |

Reading that the tests fix:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | The URL of a hash | The entry whose `Ident.of_url` has this hash. `unknown` is in the order of `hashes` (R-AP59), and the values keep the order of `unknown` |
| 2 | Case 1, source 1 | The answer has a release row with the group of the URL (`Ident.of_url(..).group.form`) and the same version, and another hash. For any host. It is before case 2 and also holds with `--snapshot log:N` (R-AP65: with case 3 conditions the client sees case 1 from source 1 only) |
| 3 | Case 2 | A `github.com` release asset URL of a repository that the guard checks (`PrivacyGuard.repos_to_check` of `Url(url)` gives one repository), and no `--snapshot log:N`. The guard already ran for every such URL in the closure query, and it stops the command for a private repository, so each of them is public here |
| 4 | Case 3 | Any other URL (another host, a loopback host, `raw.githubusercontent.com`) and each URL with `--snapshot log:N`. No ingest (R-PU40, R-AD36) |
| 5 | The ingest request | `Post`, `<origin>/v1/releases`, the headers of `Registry.headers({ version, body: Json })` and nothing else (R-DA8 rule 1: no `Authorization`, no `Talon-Contributor`), the body `{"url":"<url>"}`, `timeout_s` 20 (Q1) |
| 6 | The answer of an ingest | 200 or 201: `Indexed`, with the value of `Talon-Bookmark` (name in any case, white space cut, an empty value is none). 409 with the type `label-conflict`: `Label` (R-AP65 source 2). 409 with another type or with no problem details, 422 and another 4xx: `Archive`, with no exit code. 429: failure of kind `network` (exit 15) at once |
| 7 | The second query | Sent once, only when at least one ingest answered 200 or 201 (R-AP65). The same body as the first query. Headers in the order `User-Agent`, `Content-Type`, `Cache-Control: no-cache`, `Talon-Bookmark: <largest>` (Q3). R-AP18 check on its answer. No second try (R-AP34). The result `answer` is this answer |
| 8 | The order of the calls | Warnings of source 1 (stderr), then (only with an `Ingest` value) one `programs curl`, one `http_all` with limit 4 and `tmp_dir` `<cache>/talon/tmp`, the warnings of the 409 answers, then the second query |
| 9 | No `curl` | Exit 18, kind `environment`, the text names `curl`. No request |
| 10 | `anchor_note` | For an `Archive` value: `fixed: not in the registry index` when the answer has no row of the group of the URL, else none. For `Indexed`: none |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/UnknownvaluesTest.roc` (driver `l0-1.roc`): `classify` for case 2 (order of `unknown`), case 3 (another host, loopback, `raw.githubusercontent.com`), `--snapshot log:N`, case 1 (with another hash; with a snapshot; for another host), the label needs the group and the version, the URL of each value | R-AP28, R-AP65, R-PU40, R-DI7, R-DI11, R-ID7, R-RG4 |
| L0 | `label_warning` with the hash and without it | R-AP28, R-AP65 |
| L0 | `ingest_requests`: method, URL, the 2 headers, the body, the timeout; no credential header | R-AP9, R-DA8, R-AP45, R-AP23, Q228 |
| L0 | `ingest_verdict`: 200 and 201 with the bookmark (name in any case, white space, none, empty), 409 `label-conflict`, 409 `id-collision`, 409 with no problem details, 422, 429 | R-AP28, R-AP65, R-AP25, R-AP41 |
| L0 | `largest`: not the first and not the last, the second segment, one, none. `again_headers` | R-AP41 row 5, R-AP43, R-AP28 |
| L0 | `anchor_note`: no row of the group, an empty answer, a row of the group (another version), `Indexed` | R-AP28, R-DI11, R-C9 |
| L2 | `registry/ap28-unknown-values` (entry `registry`, word `settle`): 4 runs. Run 1: 5 unknown values in the order A, D (example.org), B, E (label with another hash), C: one warning, one `programs curl`, one `http_all limit=4` with 3 POSTs in the order A, B, C, the answers 201, 200, 201 with 3 bookmarks, the second query once with the same body and the largest bookmark (the middle one in time and in value order: not the first, not the last). Run 2: a 409 `label-conflict` (label, a warning with no hash of the registry) and a 201: the second query with the bookmark of the 201 only. Run 3: 409 `id-collision` and 422: both archive, no warning, no second query. Run 4: `snapshot-log`: a github URL gets no ingest, no `programs` call, no `http_all`; a label value keeps its warning | R-AP28, R-AP65, R-AP9, R-AP41, R-AP43, R-DA8, R-AP34, R-AP18, R-AP17, R-AP59, R-ID7, R-IX3, R-PU40, R-DI7, R-DI11, R-RG4, R-AD35, R-AD36 |
| L2 | `registry/ap28-no-curl`: one github value, no `curl` (no `fx/programs`): `programs curl`, exit 18, no `http_all` | R-DA8, R-EC18, R-AP28, Q229 |
| L2 | `registry/ap28-rate-limited`: 201 then 429 with `Retry-After: 30`: exit 15, the message has `Try again in 30 s.`, no second query | R-AP25, R-AD35, R-AP28, R-E6, R-AP34, Q424 |
| L2 | `registry/ap28-other-answers`: run 1 (Q421): an ingest with a 502 and an ingest with no answer: 2 warnings, both archive, exit 0, no second query. Run 2 (Q423): 2 ingests with 200 and 201 and no bookmark: the second query has `no-cache` and no `Talon-Bookmark`; its answer still lists Y: Y ends as archive, no third query | R-AP28, R-AP34, R-AP43, R-AP41, Q421, Q423 |
| L0 | New `expect`s (Q ids in the comments): `ingest_verdict` of `Timeout`, `Failed`, 502, 302, 202 (`Unindexed`) and of 400, 403 (`Archive`); `unindexed_warning`; 429 with `Retry-After` (30, 120 with white space and lower-case name), without it, `soon`, `1.5`; `largest` with 2 widths (Q422); `again_headers` with no bookmark (Q423); `anchor_note` of a `Label` value (Q425) | Q421, Q422, Q423, Q424, Q425 |
| L0 | `tests/unit/RegistryTest.roc` (slice 201 file, driver `l0-8.roc`): `Registry.refuse` of a 429 with `retry_after` `30`, ` 7 `, `soon`, `1.5`, empty, and without the field; a 502 ignores it | R-AP25, Q424 |

New word of the entry `registry` (`tests/commands/L2Registry.roc`, doc table): `settle entry=<url>... [snapshot-log]`. The first query has no groups and no window. The fixtures and the hand-written expect files are made by `research/slice-208-revert/mkcases.py` (not from a run, TW21). The ingest routes of a case are the files `releases.POST`, `releases.POST.2`, ... in the order of the requests (the fake counts across the runs of a case); each route requires `content-type`, and `require-none` of `authorization` and `talon-contributor`, so a request with a credential gets 599 and the case fails.

## Not tested here: list for slice 206b (no choice made)

| # | Part | Why |
| --- | --- | --- |
| 1 | Where a command calls `ClosureIndex.query!` and then `settle!`, and the `urls` it passes (the header values that are URLs) | No command can select a registry before slices 206b and 224 |
| 2 | What the solver does with a `Label` end (case 1) and an `Archive` end: the read of the facts from the archive (R-DI7, `Gather`) and the domain of the value (R-C9). A `Label` value reads its facts from the archive as case 3 (Design Q425) | The facts step is in the commands |
| 3 | The print of the `fixed: not in the registry index` line by `tln update`, `tln upgrade` and `tln outdated`, with `anchor_note` | Their output code |
| 4 | The privacy guard before the closure query of a command (done in slice 203; the command order guard, closure, `settle!`) | Whole command |
| 5 | `--snapshot log:N` of a whole command: `snapshot-log` is only the flag of `settle!` | Whole command |
| 6 | An L3 case with the real `curl` children for the ingests (R-DA8) | Real `Fx` jobs: slice 200 `hw2`, `hw3` |

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-1.roc` | 117 pass, 49 fail: each `UnknownvaluesTest` expect, `todo: slice 208` |
| `roc test tests/unit/l0-8.roc` | 144 pass, 2 fail: the 2 `RegistryTest` expects of a 429 with a valid `Retry-After` (`Registry.refuse` has the argument and the old body: red until code) |
| `tests/commands/run.sh registry` | 15 pass, 4 fail: `registry/ap28-unknown-values`, `ap28-no-curl`, `ap28-rate-limited`, `ap28-other-answers` (`[ROC CRASHED] todo: slice 208`) |
| `scripts/test.sh check fmt` | pass |

## Expected exits (read, TW21)

`ap28-unknown-values`: `expect/exit` 0, no failure line in stdout, 4 runs (5, 2, 2, 2 `value` lines; `log_size` 25, 31, 40, 60). The stderr has 3 warnings (runs 1, 2, 4), none in run 3. `ap28-no-curl`: `expect/exit` 0 (the app returns 0; the failure is the line `exit 18` of the entry), stderr one line. `ap28-rate-limited`: `exit 15` in stdout, stderr one line (`Try again in 30 s.`). `ap28-other-answers`: `expect/exit` 0, no `exit` line, 2 warnings on stderr (run 1), none in run 2, stdout 2 runs (`log_size` 70, 81). All 4 were also run with a private reference: green, with the expect files written by hand from the rules before.

## Revert check

`research/slice-208-revert/`: `before/` (the stub), `mkcases.py`, `results.txt`. A private reference and 11 mutations were run (second round after Q420 to Q425: a new reference, deleted, and N1 to N4 in `results.txt`, all caught: a 5xx that is archive with no warning, an indexed value that stays indexed when it is still unknown, no time in the 429 message, an extra bookmark header) on a private copy of the tree (then deleted, TW18): reference green (L0 and the 3 L2 cases), each mutation caught.

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `largest` takes the first bookmark | L0, `ap28-unknown-values` |
| M2 | `classify` ignores the snapshot | L0, `ap28-unknown-values` |
| M3 | A github URL is never `Label` (case 2 before case 1) | L0, `ap28-unknown-values` |
| M4 | The label ignores the version | L0, `ap28-unknown-values` |
| M5 | A 409 `label-conflict` is archive (R-AP65 source 2) | L0, `ap28-unknown-values` |
| M6 | A 429 does not stop | L0, `ap28-rate-limited` |
| M7 | The second query is sent with no indexed ingest | `ap28-unknown-values` run 3 |
| M8 | `http_all!` with limit 1 | 2 L2 cases |
| M9 | An ingest carries `Talon-Contributor` | L0, 2 L2 cases |
| M10 | The second query has no `no-cache` | L0, `ap28-unknown-values` |
| M11 | `anchor_note` ignores the rows of the group | L0 |

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| Case 1, source 1 (stderr) | `warning: acme/lib 1.1.0: the registry has this release with the hash <other>, the header has <hash>. Talon does not use the registry's release for this value. Ask the author to release a new version.` (the form of the R-DI15 warning in CLI 3) |
| Case 1, source 2 (409) | The same with `another hash` in place of `the hash <other>` (the 409 does not name it, Q164) |
| An ingest of case 3 (409 `id-collision`, 422, other 4xx) | No text (the design says "no ingest, archive", and R-AD35 step 3 has a warning only for a full name) |
| An ingest with no answer, a 5xx, a 3xx or a 202 (Q421, new) | `warning: <url>: the registry did not index this release (<status or no answer>). Talon reads the archive.` |
| Check of the proposals (Design Q421 to Q424) | The two case 1 texts, the no warning for a 4xx of case 3, the no-curl text and the `fixed` note agree with the design. The 429 text becomes `tln: error[network]: the registry answered 429 (/errors/rate-limited). Try again in <n> s.` (without `Retry-After`: `Try again later.`) |
| No `curl` | `tln: error[environment]: curl is not on PATH. Talon needs curl to send the ingests at the same time.` |
| A 429 | `tln: error[network]: the registry answered 429 (/errors/rate-limited). Try again in <n> s.` (`Try again later.` with no valid `Retry-After`, Q424) |
| The note of an anchor | `fixed: not in the registry index` (the design gives this text) |

## Questions

| # | Question | State |
| --- | --- | --- |
| Q1 | The timeout of an ingest request. R-AP34, R-DA9 and R-AD35 give none, and an ingest reads GitHub and the asset on the Worker | Answered (Design Q420, Registry R-AP28): 20 s, as the tests use. No test change |
| Q2 | An ingest with no answer (`Timeout`, `Failed`), a 5xx answer, a 3xx or a 202. R-AP28 names only 200, 201, 409, 422 and "another 4xx"; R-AP34 says an ingest "stops at once", R-AD35 step 3 does not say what it does with a 5xx | Answered (Design Q421, Registry R-AP28): case 3 for that URL, with one warning (the URL and the status or `no answer`) for no answer, a 5xx, a 3xx and a 202; other 4xx: case 3, no warning; no retry. Test change: `ingest_verdict` gets these verdicts; new L0 `expect`s for the 5 answers; new L2 run (5xx and a timeout in one run, the archive read, the warning, exit 0) |
| Q3 | (a) What does "largest" `Talon-Bookmark` mean (R-AP41 row 5)? A D1 bookmark is an opaque text. The tests use bookmarks of one width in lower-case hex segments, where the byte order and the order of the numbers agree. (b) The order of the headers of the second query (`Registry.headers` gives `User-Agent`, `Content-Type`; `RegistryCache.read_headers` gives `Cache-Control` then `Talon-Bookmark`) | (a) Answered (Design Q422, Registry R-AP28): the longer text is larger, then byte order. Test change: `largest` gets an `expect` with bookmarks of 2 widths. (b) Accepted: the header order is not a contract, the proposal stays for the tests |
| Q4 | R-AP25: the message of a 429 gives "the time when it can try again". `Registry.refuse` has no header of the answer, so it cannot give it | Answered (Design Q424, Registry R-AP28): `Registry.refuse` gets the `Retry-After` value. Test change: the L2 case `ap28-rate-limited` has a `Retry-After: 30` and expects `Try again in 30 s.`; an L0 `expect` for a missing and a non-numeric value. Slice 201 changes the signature of `Registry.refuse` (its L0 tests get the argument) |
| Q5 | After the second query a hash can still be in `unknown` (the ingest answered 200 but the answer does not have it). Also: all ingests answered 200 with no `Talon-Bookmark`: is the second query sent, and with `no-cache` only? R-AP65 says "only when at least one ingest answered 200 or 201" | Answered (Design Q423, Registry R-AP28): the hash is case 3, no third query; with no bookmark the second query has `no-cache` only. Test change: an L2 run with 2 ingests answering 200 with no `Talon-Bookmark` (the second query has no bookmark header), and one with a hash still in `unknown` after it (archive, no third query) |
| Q6 | The facts of a `Label` value (case 1) and the `fixed` note for it: R-AP28 reads the archive for case 3, and R-AP65 applies case 3 "with case 3 conditions" only. Does case 1 read the archive, and does it give the anchor note when the group has no row? | Answered (Design Q425, Registry R-AP28): case 1 reads the facts from the archive like case 3, and has the anchor note by the case 3 rule. Test change: `settle!` reports `Label` with the case 3 fact source; `anchor_note` gets an `expect` for a `Label` value with no release of its group in the answer |

## Code

| File | Change |
| --- | --- |
| `cli/lib/UnknownValues.roc` | The 9 stubs of the tables (`crash "todo: slice 208"`) |
| `cli/lib/Registry.roc` | `refuse` and `problem_fail` get the optional field `retry_after ?: Str` (docs and types, no body change). The 5 callers need no change to compile. The code agent writes the 429 text and passes the header in `ClosureIndex.query!`, `LogSnapshot.second!`, `ShortNames`, `RegistryToolchains` and `settle!` |
| `tests/unit/RegistryTest.roc` | The new 429 expects |
| `cli/lib/main.roc` | `UnknownValues` in the package list |
| `tests/unit/UnknownvaluesTest.roc`, `tests/unit/l0-1.roc` | The L0 tests and the driver import |
| `tests/commands/L2Registry.roc` | The word `settle` and `end_text` (test code) |
| `tests/commands/cases/registry/ap28-unknown-values/`, `ap28-no-curl/`, `ap28-rate-limited/`, `ap28-other-answers/` | The L2 cases |

### Code result

| File | Change |
| --- | --- |
| `cli/lib/UnknownValues.roc` | The 9 bodies and private helpers |
| `cli/lib/Registry.roc` | 429 message with `retry_after` (`wait_text`), new `retry_after_of` |
| `cli/lib/ClosureIndex.roc`, `LogSnapshot.roc`, `RegistryToolchains.roc`, `ShortNames.roc` | Pass `Retry-After` into `refuse` |
| `cli/lib/RegistryCache.roc` | The `Answer` of `get!` has a new field `headers` (for ShortNames) |
| `cli/lib/ClosureIndex.roc`, `LogSnapshot.roc` | New shared `ClosureIndex.send!` (check, one send, errors with Retry-After, decode, one_state), used by `query!`, `LogSnapshot.second!` and `settle!` |


Result: `scripts/test.sh check fmt l0 l2 l3` pass.

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-208-revert/code-final.sha256` | 7 of 7 OK |
| `todo: slice 208` in `cli/` | None |
| `scripts/test.sh check fmt l0 l2 l3` | All pass (l0 10.2 s, a TW20 warning on a loaded machine) |
| Slice cases | L0 `UnknownvaluesTest` and the 7 new `RegistryTest` expects green. L2 `ap28-unknown-values`, `ap28-no-curl`, `ap28-rate-limited`, `ap28-other-answers` green; all 19 registry cases green. |
| Expected exits | `ap28-no-curl`: 18 (Q229). `ap28-rate-limited`: 15 (429, Q421, with `Try again in 30 s.`, Q424). The others exit 0. |
| Revert check | 15 of 15 caught (test step: 11, then N1 to N4) |
| Review changes | `RegistryCache.Answer` has `headers` (kept copies `[]`), so every 429 path reads `Retry-After`. One shared `ClosureIndex.send!` does the closure request for `query!`, `LogSnapshot.second!` and `settle!`. |
| Design answers | Q420 to Q425 |
| Moved out | Slice 206b: the call of `query!` then `settle!` in commands, `Label` and `Archive` ends in the solver and `Gather`, the `fixed:` line in commands. |

