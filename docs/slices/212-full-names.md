# 212 Full names, new repositories

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 212 of `PLAN-P2-CLI.md`. With a registry, a full name `owner/repo` in `tln add`, `tln tool install` and `tln x` reads `GET /v1/packages/{owner}/{repo}/releases` (Registry R-AP1). A 404 is a repository that the registry did not index yet (R-AD35, Design Q34): the privacy guard, the GitHub release list, the selector, the ingest of each candidate, then R-AP1 again. `--snapshot log:N` sends no ingest and stops with exit 2 (R-AD36). `--offline` sends no request (R-AD37).

## How the existing direct mode reads the release list (checked first)

| Piece | Where | Used here |
| --- | --- | --- |
| The list call, cache pages, token rules, rate limit, `Link: rel="next"` (R-DI2, R-DI12, R-DI13) | `Github.releases!` (`cli/lib/Github.roc`) | Called as it is |
| Draft, prerelease, the one `<hash>.tar.zst` asset, the URL and `X.Y.Z` (R-DI3 to R-DI5), the warning of 2 assets, R-DI15 | `Index.candidates` (`cli/lib/Index.roc`) | Called as it is. `PickIndex.index!` (the `Direct` branch) makes the same 2 calls, but it works on a `ResolveBase.Request` and returns a `Candidates` record with no URL list for an ingest, so `FullName.read!` calls the 2 functions itself |
| The selector (Exact, Range, none) | `ToolInstall.pick` step 1 has the rule inline (and `Add`/`PickFlow` have their own) | `FullName.select` (new): the same rule, as one pure function with the order of step 3 |

## Scope

| In | Out (where) |
| --- | --- |
| New module `cli/lib/FullName.roc` (in `main.roc`): `select`, `way`, `compiler_only`, `skip_warning`, `unindexed_warning`, `after_ingests`, `no_candidate`, `not_indexed`, `snapshot_stop`, `still_missing`, `read!` | The call of `read!` inside `tln add`, `tln tool install` and `tln x`, the parse of the selector, the use of the answer as the index of the command: slice 206b (no command can pick a registry before slices 206b and 224) |
| R-AD35 steps 1 to 4 in order, with the guard before the first request (R-RG4), step 2 stop cases, step 3 ingest newest first with one `http_all!` of limit 4, 409 and 422 skip with a warning, 429 exit 15, step 4 R-AP1 again with `no-cache` and the largest bookmark | Output of a whole command, `--json` `data` of the ingest (CLI 3): slice 206b |
| R-AD36 (`log:N`: no ingest, exit 2), R-AD37 (`--offline`: no request, exit 15 with no copy) | `--snapshot log:N` when R-AP1 answers 200 but the log hides all releases (slice 207) |
| R-AP1, R-SC3, R-SC4 (the registry reads of `tool install` and `x`) | An L3 case with the real `curl` children (slice 200 `hw2`, `hw3`) |

## Rules

R-AD35, R-AD36, R-AD37, R-AP1, R-SC3, R-SC4, R-DI2 to R-DI5. As used: R-AP65, R-SL6 to R-SL11, R-AD2, R-RG4, R-RG6, R-AP9, R-AP23, R-AP25, R-AP28, R-AP34, R-AP41 row 5, R-AP43, R-AP45, R-DA8, R-DA9, R-DI6, R-DI12, R-IX3, R-IX6, R-SL3 to R-SL5, R-E6, R-EC2, R-EC18, R-T10, Design Q34, Q224 to Q229, Q420 to Q425.

## Reuse of slice 208

| Function of 208 | Here |
| --- | --- |
| `UnknownValues.ingest_requests` | Used as it is: `Post`, `<origin>/v1/releases`, `User-Agent` and `Content-Type` only, the body `{"url":...}`, `timeout_s` 20 |
| `UnknownValues.ingest_verdict` | Used for 200 and 201 (`Indexed` with the bookmark) and 429 (exit 15 with `Retry-After`). 409 and 422 are handled before it (`FullName.skip_warning`), because R-AD35 step 3 prints a warning that names the error type, where the verdict of 208 gives `Archive` with no text |
| `UnknownValues.largest` | Used as it is |
| `UnknownValues.unindexed_warning` | Not used: its text says "Talon reads the archive", which is wrong for a full name. `FullName.unindexed_warning` (new) has the text of Design Q398 |
| `UnknownValues.again_headers` | Not used: it is for the closure `POST` (it has `Content-Type`). The second read is a `GET`: `RegistryCache.get!` with `newest` and `bookmark` gives `User-Agent`, `Cache-Control: no-cache`, `Talon-Bookmark` and no `If-None-Match` (R-AP43) |
| `UnknownValues.settle!` | Not used: it is for the closure answer. The curl check text is the same |
| `RegistryCache.get!`, `PrivacyGuard.check!`, `Registry.releases_of_repo_url`, `Registry.refuse` | Used as they are |

## Decisions (pure, L0) and flow (L2)

| Name | Signature | Rule |
| --- | --- | --- |
| `FullName.select` | `{ list : List(Index.Candidate), selector : Try(Selector, [None]) } -> List(Index.Candidate)` | R-AD35 steps 1 and 3, R-SL3 to R-SL5, R-DI10 |
| `FullName.skip_warning` | `{ name, tag, status, body } -> Try(Str, [NotSkipped])` | R-AD35 step 3 |
| `FullName.way` | `Try(Selector, [None]) -> [Registry, Compiler, Source]` | R-AD35 step 1, Q397, R-SL6 to R-SL11 |
| `FullName.compiler_only` | `{ name, text } -> Fail` (kind `Usage`) | Q397 |
| `FullName.unindexed_warning` | `{ name, tag, what } -> Str` | R-AD35 step 3, Q398 |
| `FullName.after_ingests` | `{ indexed, skipped, other } -> [Ask, NotIndexed, NoCandidate]` | R-AD35 step 4, Q399, R-AP65 |
| `FullName.not_indexed` | `{ name } -> Fail` (kind `Network`) | Q399 |
| `FullName.no_candidate` | `{ name } -> Fail` (kind `Usage`), no selector | R-AD35 step 2 and step 4, R-T10, Q430 |
| `FullName.snapshot_stop` | `{ name, size } -> Fail` (kind `Usage`) | R-AD36 |
| `FullName.still_missing` | `{ name } -> Fail` (kind `Network`) | R-AD35 step 4 |
| `FullName.read!` | `Fx, { net, roots, origin, version, now, offline, name, selector : FullName.Typed, snapshot, known } => Try([Found(WireIndex.Releases), NoMatch, SourceBuild], Fail)` | R-AD35 to R-AD37, R-RG4, R-AP1 |

Reading that the tests fix:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | The order of the calls | Guard (`read_files` of `repo.json`, then the request of `/repos/<o>/<r>` and a write, or no call when kept), R-AP1 (`list_dirs`, `http_get`), then only on a 404: the GitHub list (`list_dirs`, `http_get`, `write_atomic`), `programs curl`, one `http_all limit=4`, R-AP1 again (`http_get`, `write_atomic` of the copy). The guard is before the first R-AP1 request, also when R-AP1 answers 200 (R-RG4, R-AD35 first sentence) |
| 2 | Private or unknown repository | The guard stops (exit 2, R-RG6) before any R-AP1 request. The texts are those of slice 203 |
| 3 | R-AP1 answers 200 | The decoded answer is the result. No GitHub list, no `programs curl`, no ingest. The copy is kept (R-IX3) |
| 4 | The order of the ingests | `published_at` newest first. Candidates with one time keep the page order. Not the version order. One `http_all!` call for all (limit 4), so more than 4 candidates are 4 at one time (R-DA8) |
| 5 | 409 and 422 | Skipped with a warning (any `type`, also no problem details). The command goes on. Exit code 0 |
| 6 | The second read | Only when at least one ingest answered 200 or 201 (Q399). The bookmark is the `largest` of the bookmarks of the 200 and 201 answers. No bookmark: `no-cache` only. Else no read: only 409 and 422 skips give exit 2 with `no_candidate`; one or more other answers give exit 15 with `not_indexed` |
| 7 | `--snapshot log:N` | After the 404, exit 2, with no GitHub read, no ingest, no second read (Q396) |
| 10 | The selector forms (Q397) | `way` before any call: a nightly tag or a relative step is exit 2 with no request, a git ref or a sha that is no version, range or series is `SourceBuild` with no request. A selector that keeps no candidate is `NoMatch` (the command gives its own text, Q430). A digits-only sha is a series, so `Registry` |
| 11 | The other ingest answers (Q398) | A 5xx, a 3xx, a 202, no answer: skip with the warning of `unindexed_warning`. Another 4xx: skip, no warning. Both count as `other` |
| 8 | `--offline` | No guard request (R-RG4), R-AP1 uses the copy only. No copy: exit 15, the text of `Github.no_page_failure` (R-DI12, R-IX6). No GitHub read, no ingest |
| 9 | No `curl` | Exit 18 (kind `environment`), after the GitHub read and before any ingest (Q229) |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/FullnameTest.roc` (driver `l0-1.roc`): `select` (newest first by time, ties keep the page order, `latest` is no selector, exact, range, nothing left, empty list), `way` (none, version, range, series, `latest`: registry; nightly tag, relative step: compiler; `--git`, sha: source; digits-only sha: registry), `compiler_only`, `skip_warning` (409 and 422 with type, 409 with no problem details, 200 201 429 500 404 are not skips), `unindexed_warning`, `after_ingests` (the count cases), `not_indexed`, `no_candidate` (exit 2, text), `snapshot_stop` (exit 2, text), `still_missing` (exit 15, text) | R-AD35, R-AD36, R-SL3 to R-SL11, R-DI10, R-T10, Q397 to Q399, Q430 |
| L2 | `registry/ad35-ingest` (entry `registry`, word `fullname`): the whole path with 9 GitHub releases (draft, prerelease, 2 assets with a warning, no `X.Y.Z`), 5 ingests newest first with 201, 409, 200, 422, 201, the 2 skip warnings, the second read with the largest bookmark in the middle | R-AD35, R-AD2, R-SC3, R-SC4, R-RG4, R-AP1, R-AP9, R-AP41, R-AP43, R-DI2 to R-DI5, R-DA8, R-DA9, R-AP45, R-AP23, R-AP34, R-IX3 |
| L2 | `registry/ad35-selector`: 3 runs: `^1` (2 ingests), `1.0.0` (1 ingest), `9.9.9` (`no match`, no curl, no POST) | R-AD35, R-SL3 to R-SL5, R-DI6, R-AP41, R-DA8 |
| L2 | `registry/ad35-still-404`: 201 and the second read is 404: exit 15 | R-AD35 step 4, R-AP43, R-E6 |
| L2 | `registry/ad35-rate-limited`: 201 then 429 with `Retry-After: 30`: exit 15, no second read | R-AP25, R-AD35 step 3, R-AP34 |
| L2 | `registry/ad36-snapshot`: `log=40`: exit 2, no GitHub list, no POST | R-AD36, R-RG4 |
| L2 | `registry/ad35-stop-cases`: private repository and a 404 name (the guard, no R-AP1 request), a public repository with no candidate (draft, prerelease, no package asset): exit 2 | R-AD35 step 2, R-RG4, R-RG6, R-EC2, R-DI3, R-DI4, R-T10 |
| L2 | `registry/ad35-no-curl`: no `curl`: exit 18, no POST | R-DA8, R-EC18, Q229 |
| L2 | `registry/ad35-other-answers` (Q398): 201, 502, 403, no answer, 202: 3 warnings (502, no answer, 202), none for the 403, the second read with the bookmark of the 201, exit 0 | R-AD35 step 3, R-AP28, R-AP34, Q398 |
| L2 | `registry/ad35-no-ingested` (Q399): run 1 a 409 and a 422: exit 2, no second read. Run 2 a 409 and a 502: exit 15, no second read | R-AD35 step 4, R-AP65, R-AP43, Q399 |
| L2 | `registry/ad35-way` (Q397): a nightly tag and a relative step: exit 2, no call at all; a sha: `source build`, no call | R-AD35 step 1, R-SL6 to R-SL11, Q397 |
| L2 | `registry/ad35-known`: R-AP1 answers 200: guard, copy, no ingest | R-AD35, R-AP1, R-IX3 |
| L2 | `registry/ad37-offline`: `offline`, no copy: exit 15, no request | R-AD37, R-DI12, R-IX6 |

New word of the entry `registry` (`tests/commands/L2Registry.roc`, doc table): `fullname <owner/repo> [sel=<text>] [log=<n>] [offline]`. The fixtures and the hand-written expect files are made by `research/slice-212-revert/mkcases.py` (not from a run, TW21). The R-AP1 routes are `releases` (the first read, 404) and `releases.2` (the read after the ingests, which requires `cache-control: no-cache`, the `talon-bookmark` and no `if-none-match`). The ingest routes are `releases.POST`, `releases.POST.2`, ... in the order of the requests of the case, each with `require-none` of `authorization` and `talon-contributor`.

## Not tested here: list for slice 206b (no choice made)

| # | Part | Why |
| --- | --- | --- |
| 1 | Where `add`, `tool install` and `x` call `FullName.read!`: after the parse of the ref and the short-name lookup (slice 211), with the selector and `known` of the command | No command can select a registry before slices 206b and 224 |
| 2 | What the command does with the answer: `ClosureIndex.candidates` for the name, the pick, `--as`, the header write | Whole command |
| 3 | The print of the ingest warnings and of the stop inside the output of a command, and `--json` `data` | Output code of the commands |
| 4 | The text of a command for `NoMatch` (`Add.no_release` with close versions, the text of `tool install` and `x`), the source build after `SourceBuild`, and the tests of the selector case (Q430) | Whole command |
| 5 | A first R-AP1 read that answers 5xx, 429 or 3xx (`Registry.refuse` or `RegistryCache.unusable`, R-E6) | The same code as every registry read (slice 202); no new rule |
| 6 | An L3 case with the real `curl` children | Real `Fx` jobs: slice 200 `hw2`, `hw3` |

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-1.roc` | 166 pass, 32 fail: each `FullnameTest` expect, `todo: slice 212` |
| `tests/commands/run.sh` | 276 pass, 12 fail: the 12 new `registry/ad3*` cases (`[ROC CRASHED] todo: slice 212`) |
| `scripts/test.sh check fmt` | pass |
| `MISSING=1 scripts/rules.sh` on the rules of the slice | no rule without a test |

## Expected exits (read, TW21)

| Case | `expect/exit` | Lines in stdout and stderr |
| --- | --- | --- |
| `ad35-ingest` | 0 | No `exit` line. `releases 3`. stderr: 3 warnings (2 assets, 409, 422) |
| `ad35-selector` | 0 | Runs 1 and 2 `releases 2` and `releases 1`. Run 3 `no match`, no stderr |
| `ad35-other-answers` | 0 | `releases 1`, stderr 3 warnings |
| `ad35-no-ingested` | 0 | Run 1 `exit 2` (2 warnings, no-candidate text), run 2 `exit 15` (2 warnings, not-indexed text) |
| `ad35-way` | 0 | Runs 1 and 2 `exit 2`, run 3 `source build`, `calls.log` empty after `env_all` |
| `ad35-still-404` | 0 | `exit 15`, stderr: the registry has no release yet |
| `ad35-rate-limited` | 0 | `exit 15`, stderr: `Try again in 30 s.` |
| `ad36-snapshot` | 0 | `exit 2`, stderr: no release in the log at size 40 |
| `ad35-stop-cases` | 0 | 3 runs, each `exit 2` (private, 404 name, no candidate) |
| `ad35-no-curl` | 0 | `exit 18`, stderr names curl |
| `ad35-known` | 0 | `releases 2`, no stderr |
| `ad37-offline` | 0 | `exit 15`, stderr names `--offline` |

The app exit is 0 in each case (the failure is the line `exit <code>` of the entry, as in slice 208). No expected failure was baked in by `UPDATE=1`: no run used it. All 12 cases and the L0 file were also run with a private reference: green.

## Revert check

`research/slice-212-revert/`: `before/FullName.roc` (the stub), `mkcases.py`, `mutate.py`, `results.txt`. A private reference and 12 hand mutations, run on a private copy of the tree (then deleted, TW18): reference green (183 L0, 28 L2 registry cases), each mutation caught. Second round after the answers (a new reference, deleted, and `mutate.py` deleted): reference 198 L0, 31 L2 registry cases; N1 to N6 all caught (below).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | Oldest first | L0, 3 L2 cases |
| M2, M2b | An exact selector, or a range, is ignored | L0, `ad35-selector` |
| M3 | A 422 is not skipped with a warning | L0, `ad35-ingest` |
| M4 | No privacy guard | 8 L2 cases |
| M5 | The second read has no bookmark | 3 L2 cases |
| M6 | A 429 does not stop | `ad35-rate-limited` |
| M7 | The snapshot stop is after the GitHub read | `ad36-snapshot` |
| M8 | The first read ignores `--offline` | `ad37-offline` |
| M9 | The ingests run one at a time | 4 L2 cases |
| M10 | Equal times in the reverse page order | L0 |
| N1 | R-AP1 is read again after every ingest step (Q399) | `ad35-no-ingested` |
| N2 | A 5xx is not counted as another answer (Q398, Q399) | `ad35-no-ingested` |
| N3, N4 | A sha, or a nightly tag, is a registry name (Q397) | L0, `ad35-way` |
| N5 | Only 409 and 422 skips give exit 15 (Q399) | L0, `ad35-no-ingested` |
| N6 | Another 4xx gets a warning (Q398) | `ad35-other-answers` |

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| A skipped 409 or 422 (stderr) | `warning: <owner>/<repo> <tag>: skipped, the registry answered <status> (<type>).` (no `(<type>)` when the answer has no problem details) |
| 2 package assets (R-DI4, stderr) | The text of `Index.candidates`: `warning: <owner>/<repo> <tag>: the release has 2 package assets (<hash>, <hash>). It is not a candidate.` |
| No candidate, no selector (exit 2), also when each ingest was a 409 or 422 | `<name> has no release that Talon can use. A release needs one <hash>.tar.zst asset and must not be a draft or a prerelease.` (with a selector: the text of the command, slice 206b) |
| A nightly tag or a relative step (exit 2) | `<name>@<text>: a nightly tag and a relative step name a compiler release. <name> is not a compiler.` |
| A 5xx, 3xx, 202 or no answer of an ingest (stderr) | `warning: <owner>/<repo> <tag>: skipped, the registry did not index this release (<status or no answer>).` |
| Nothing indexed and one or more other answers (exit 15, Q399) | `the registry did not index <name> now. Run the command again in a moment.` |
| `log:N` (exit 2) | `<name> has no release in the log at size <N>. A snapshot sends no ingest.` |
| Still 404 (exit 15) | `the registry has no release of <name> yet. The registry is indexing the repository: run the command again in a moment.` |
| 429 (exit 15) | `the registry answered 429 (/errors/rate-limited). Try again in <n> s.` (Q424, slice 208) |
| No `curl` (exit 18) | `curl is not on PATH. Talon needs curl to send the ingests at the same time.` (slice 208) |
| Private, unknown (exit 2) | The texts of slice 203 |
| Offline, no copy (exit 15) | The text of `Github.no_page_failure` |

## Questions (all answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | R-AD36: with `--snapshot log:N` and a 404, does Talon read the GitHub release list before it stops? The rule says only "sends no ingest" and "the command stops with exit code 2"; the message needs no GitHub data. | Answered (Design Q396): no GitHub read. `ad36-snapshot` stays |
| Q2 | R-AD35 step 1: "the selector of the command". For `Nightly`, `Step`, `GitSha` and `GitRef` (R-SL6 to R-SL10) on a full name of `add`, `tool install` or `x`: does the registry path run at all, and which candidates does the selector keep? R-SL10 takes a sha as a git ref only "when no release matches", so it needs the list. | Answered (Design Q397): see `way`. L0 cases and `ad35-way` added |
| Q3 | R-AD35 step 3 names 200 and 201 (indexed), 409 and 422 (skip with a warning), 429 (exit 15). It does not say what Talon does with another answer of an ingest: a 5xx, a 3xx, a 202, no answer, or another 4xx (400, 401, 403, 404). Registry R-AP28 case 2 (Q421) has a rule for the closure: a warning and the archive for 5xx, 3xx, 202, no answer, and no warning for another 4xx. For a full name there is no archive read. | Answered (Design Q398): the verdicts of Q421. `ad35-other-answers` added |
| Q4 | R-AD35 step 4: is R-AP1 asked again when no ingest answered 200 or 201 (for example each was a 409 or 422, or all were `Unindexed`)? Registry R-AP65 sends the second closure query only after a 200 or 201, but step 4 of R-AD35 has no such condition, and the "still 404" text says "the registry indexes the repository", which is wrong when nothing was indexed. | Answered (Design Q399): no read without a 200 or 201. `ad35-no-ingested` added |
| Q5 | Which text does a command give when the selector keeps no candidate (step 2): the proposal of `FullName.no_candidate`, or the text of its own command (`Add.no_release` with close versions, `ToolInstall.pick`: `<name> has no release <v>`)? | Answered (Design Q430): the text of each command, slice 206b. `no_candidate` has no selector; `read!` gives `NoMatch` for a selector that keeps nothing (a shape proposal for 206b) |

Answers (design agent, 2026-11-03):

| G-C | Design Q | Answer | Test change |
| --- | --- | --- | --- |
| G-C73 (Q1) | Q396 | No GitHub read: stop at the 404 with exit 2 (CLI R-AD36) | None: `ad36-snapshot` stays |
| G-C74 (Q2) | Q397 | Version, range, series, `latest`: keep the matches. Nightly tag, relative step: exit 2 before any request. `--git` and a sha that is not a version, range or series: a source build, no registry path. Digits only read as a series first. | New L0 cases of `FullName.select` for the 4 forms. The reference "keep all" is not correct. |
| G-C75 (Q3) | Q398 | The verdicts of Q421: a warning and a skip for 5xx, 3xx, 202, no answer; a skip with no warning for another 4xx; 429 exit 15 | New L2 case: one 5xx ingest gives the warning |
| G-C76 (Q4) | Q399 | No second read without a 200 or 201. Only 409 and 422: exit 2, no-candidate text. Another answer among them: exit 15, "the registry did not index <name> now, run the command again" (proposal). | New L2 cases: all 409, and one 5xx with no 200 or 201. The reference "always asks again" changes. |
| G-C77 (Q5) | Q430 | The text of each command; `FullName.no_candidate` only with no selector. Slice 206b. | The selector-case texts of the L0 and L2 tests change in 206b |
| Output | Q430 | The other proposals agree with the design | None |

## Code

| File | Change |
| --- | --- |
| `cli/lib/FullName.roc` | The 11 stubs (`crash "todo: slice 212"`) with the docs of the tables above |
| `cli/lib/main.roc` | `FullName` in the package list |
| `tests/unit/FullnameTest.roc`, `tests/unit/l0-1.roc` | The L0 tests and the driver import |
| `tests/commands/L2Registry.roc` | The word `fullname` (test code) |
| `tests/commands/cases/registry/ad35-ingest/`, `ad35-selector/`, `ad35-still-404/`, `ad35-rate-limited/`, `ad36-snapshot/`, `ad35-stop-cases/`, `ad35-no-curl/`, `ad35-known/`, `ad37-offline/`, `ad35-other-answers/`, `ad35-no-ingested/`, `ad35-way/` | The L2 cases |

## Code result

| File | Change |
| --- | --- |
| `cli/lib/FullName.roc` | The 11 stubs now have bodies. `select` sorts with the page index as the tie key. `read!` follows steps 0 to 8 and reuses `Github.releases!`, `Index.candidates`, `UnknownValues.ingest_requests`, `ingest_verdict`, `largest`, `RegistryCache.get!`, `PrivacyGuard.check!`, `Registry.refuse` |
| Result | `scripts/test.sh check fmt l0 l2 l3`: all pass |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-212-revert/code-final.sha256` | 1 of 1 OK (`FullName.roc`) |
| `todo: slice 212` in `cli/` | None |
| `scripts/test.sh check fmt l0 l2 l3` | All pass |
| Slice cases | L0 `FullnameTest` green. L2 12 cases (`ad35-*`, `ad36-snapshot`, `ad37-offline`) green. |
| Expected exits | 18: no curl (Q229). 15: 429, still 404, not indexed now (Q399), offline with no kept copy (R-DI12). 2: snapshot stop (Q396), nightly tag or relative step (Q397), only 409/422 skips (Q399), stop cases. The others exit 0. |
| Revert check | 18 of 18 caught (test step) |
| Code review notes | A 409 never reaches the `Label` verdict (`skip_warning` takes 409 and 422 first). `Archive` (another 4xx) is "other" with no warning (Q398). A name that is not `owner/repo` gives a Usage failure (not reachable for a full name). |
| Design answers | Q396 to Q399, Q430; output proposals accepted |
| Open for 206b | A selector on a name with no usable release gives `NoMatch`; the command prints its own text (Q430). No test yet. |
| Moved out | Slice 206b: `read!` in `add`, `tool install`, `x`, the commands' `NoMatch` texts, the source-build path after `SourceBuild`. |

