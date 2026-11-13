# Slice 244d mutation check (TW12)

Script: `research/slice-244d-revert/mutate.sh [mutant names]`. Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-244d-mut/`, deleted at the end; the working tree is not changed). Each test run is capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one mutant at a time. L2 binary built with `--opt=dev`. Tests per mutant: l0-9 and `tests/commands/run.sh audit/ update/au7 registry/au7 registry/fe10 fetch/`; for mutants in shared code (Walk, PickFlow, PickIndex, InstallFlow, VerifyFlow) also `install/ update/ resolve/ moves/ index/` (the leak check). Baseline: l0-9 187 passed; L2 56 passed (the wide set). No cap hit, no mutant looped.

Result: 12 mutants. 8 caught, 4 NOT caught (G1 to G4).

| # | Mutant (place) | Behavior | Caught by |
| --- | --- | --- | --- |
| e1 | `AuditResolve.warn!`: no direct warning at all | 1 the feed | L2 update/au7-direct-series, au7-direct-held-move |
| e2 | `AuditCheck.resolve_direct`: `asset-replaced` with a new hash gives a line | 2 | L0 c3, L2 au7-direct-series |
| e3 | `Walk.run!`: a leaf in every command (`leaf` default True) | 3 only `tln audit` makes a leaf | NOT caught (G1) |
| e4 | `AuditReport.data`: the gone note missing from `--json` | output | L0, L2 ad12-archive-gone |
| e5 | `AuditReport.text`: the gone note missing from the human text | output | L0, L2 ad12, ad13 |
| e6 | `Fetch.gone_url`: any status of a download makes a leaf | 6 only a 404 | NOT caught (G2) |
| e7 | `PickFlow.search!`: the pages of the second search (held move) are dropped | held move | L2 update/au7-direct-held-move |
| e8 | `PickIndex.index!`: the pages of a fetched list are not kept | 1 | L2 au7-direct-series, au7-direct-held-move and 17 shared cases (fetch/fe-flows, install/, moves/, resolve/, update/): the field is also used there |
| e9 | `VerifyFlow.verified!`: the lists are not fed | 1 (verify) | NOT caught (G3) |
| e10 | `InstallFlow.finish!`: the lists are not fed | 1 (install, update) | L2 au7-direct-series, au7-direct-held-move |
| e11 | `AuditResolve.warn!`: `--offline` (kept pages) prints direct warnings | Q-244d-3, Q622 item 1 | NOT caught (G4) |
| e12 | `AuditFlow.gone_of`: the note names the entries that are not gone | 4 | L2 ad12, ad13 and all 9 other `audit/` cases (they print no note, or the wrong one) |

Not mutated: behaviors 4 (the leaf keeps its own finding) and 5 (the deps of a leaf are not walked) have no single-line mutant that ends: a `sed` that re-asks the gone id (`asked = ids`) makes `level!` recurse forever (a loop, not a result), and the finding of a leaf comes from the list or the guard, which e12 and ad12/ad13 cover through the report. Their L2 `calls.log` (ad12) fixes the calls.

## Gaps (not caught)

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | e3 (leaf for every command) | A resolve 404 comes in `Gather` of the pick, before any `Walk.run!` with `leaf`; no case has a 404 archive in a command that only walks (`ls`, `why`, `outdated`). | L2: `tln ls` (or `tln why`) with `direct` and a header archive that is not in the cache and answers 404. Expect exit 15 and `download of ... failed: 404 (...)`, and no `not checked` note. |
| G2 | e6 (any status is a leaf) | Q-244d-1 says: no case for another status. | L2 `audit/`: as ad12 but the download answers 500 (and one with a transport error). Expect exit 15 (or 16), no leaf, no note. L0 on `Fetch.gone_url`: messages with 404, 500, no digits, `Run tln audit` text; only the 404 gives the URL. |
| G3 | e9 (verify is not fed) | No L2 case of `verify` with `direct` and a finding; the comment of the slice says `verify` is a review point. | L2 `verify/au7-direct`: copy of `update/au7-direct-series` with `verify`. Expect the same `warning:` lines on stderr. |
| G4 | e11 (`--offline` prints warnings) | No case runs a resolve with `direct` and `--offline` and kept pages. It may also be that offline resolves have no `Pages` (then the mutant is equivalent for the fixtures). | L2: `update --offline` with `direct` after a run that kept the pages. Expect no `warning:` line and no request. |

## Update: re-run of e3, e6, e9 and e11 after the new tests

The test agent added audit/ad16-why-404 (G1), audit/ad14-archive-500 and ad15-archive-net plus L0 d2 on `Fetch.gone_url` (G2), verify/au7-direct (G3) and update/au7-direct-offline (G4). verify/au7-direct also found a code bug (an empty head in the R-AU7 line of a transitive entry, also in the 244c registry path; new test registry/au7-transitive); the code agent fixed it.

`mutate2.sh base e3 e6 e9 e11` (the same script with `verify/au7` in `T`; log `run2.log`). Fix to both scripts: the compiler was the Worker pin (`nightly-2026-11-06`); it is now `$ROC` of scripts/env.sh (the CLI pin, `ROC_TAG`). With the Worker pin the mirror did not compile after the bug fix. Baseline: l0-9 189 passed, L2 62 passed.

| Mutant | Before | After | Caught by |
| --- | --- | --- | --- |
| e3 (a leaf in every command) | NOT caught | caught | L2 audit/ad16-why-404 |
| e6 (any status makes a leaf) | NOT caught | caught | L0 d2, L2 audit/ad14-archive-500 |
| e9 (verify is not fed) | NOT caught | caught | L2 verify/au7-direct |
| e11 (--offline prints direct warnings) | NOT caught | caught | L2 update/au7-direct-offline |

G1 to G4 are closed. All 12 mutants are caught.
