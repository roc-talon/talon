# Slice 250 mutation check (TW12, the yank filter: R-C6, R-C9, R-B3, Q630)

Script: `research/slice-250-revert/mutate.sh [mutant names]` (pattern of slice 249). Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-250-mut/`, deleted at the end; the working tree is not changed); a `cmp` check reports "SED DID NOT APPLY" (none did). Compiler: `$ROC` of `scripts/env.sh`. Each test run holds `.tmp/heavy.lock` and runs capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one at a time. Tests per mutant: the `l0-1` driver and `tests/commands/run.sh registry/ update/ install/ add/ x/ patch/ index/ tool/`. In `run.log` a failed expect prints `exit=1 ... 0 compiler errors`; a pass prints `All (225) tests passed`. Baseline: l0-1 225 passed, L2 242 passed. No cap hit, no loop.

Result: 14 mutants. 7 caught, 7 NOT caught (G1 to G6; q13 and q14 are one group). No mutant is proven equivalent, but q13, q14 and part of q1 depend on `Domain.with_header` (see the note).

| # | Mutant (place) | Behavior | Result |
| --- | --- | --- | --- |
| q1a | `ClosureIndex.live`: a held yanked row stays without the hash matching | B2 | caught: l0-1 only (L2 passes) |
| q1b | `live`: ... without the version matching | B2 | NOT caught (G1) |
| q1c | `live`: ... without the URL form matching | B2 | NOT caught (G1) |
| q2 | `live` drops nothing (filter off) | B1 | caught: l0-1, L2 yf1, yf2, yf4, yf7 |
| q3 | `dropped`: the count is one too high | B11 | caught: L2 yf4-update-named-yanked, yf7-offline-yanked-count (not L0) |
| q4 | `Pick.with_yanked`: a count of 0 prints `, 0 yanked` | B11 | caught: l0-1 only |
| q5 | `Pick.with_yanked`: the total does not count the yanked | B11 | caught: l0-1, L2 yf4, yf7 |
| q6 | `PickFlow.with_yanked_count`: the offline count is lost (0) | B11 | caught: L2 yf7-offline-yanked-count (not L0) |
| q7 | `FullName.closure_item`: falls back to yanked rows for a version or range | Q630-2 | caught: l0-1, L2 yf6-add-named-yanked |
| q8 | `PickFlow.each_yanked_check`: also fires with a selector | B10 | NOT caught (G2) |
| q9 | `PickFlow`: the close versions of `no_match` include the yanked rows | B9 | NOT caught (G3) |
| q10 | `XCmd.reuse_note`: prints the no-data note with a registry | B7 | caught: l0-1, L2 yf3-x-yanked |
| q11 | `PatchApply`: the held URL is not given to the index (`[]`) | patch | NOT caught (G4) |
| q12 | `each_yanked_check`: a withdrawn row does not count as "yanked" | B10 | NOT caught (G5) |
| q13 | `PickIndex.counted!`: no held URLs for an answer | B3 | NOT caught (G6) |
| q14 | `PickIndex.counted!`: no held URLs for a kept copy (offline) | B3 | NOT caught (G6) |

Note on q1, q13, q14: `Domain.with_header` adds the header value to the domain as a candidate with `published_at: 0` when the index list does not hold it. So a header value on a yanked release stays in the domain even when `live` dropped its row; the visible difference is only its date (and a count). That is why these mutants pass L2. If the design needs the real `published_at` of a header value (min-release-age, `outdated`), G1 and G6 are real gaps. If it does not, they are dead conditions and the code agent can simplify.

## Gaps (not caught)

| # | Mutants | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | q1b, q1c (`live`: version and URL form conditions) | The L0 `live` rows have no decoy: a held URL of the same hash but another version or another URL form. | L0 `ClosureIndex.live` rows: (a) a yanked row `acme/known@1.1.0` and `held` with the same hash and form but version 1.2.0: the row is dropped; (b) the same hash and version in another URL form (another tag form): the row is dropped; (c) all three equal: the row stays (B2 "label of `drop_labels`"). |
| G2 | q8 (`each_yanked_check` with a selector) | yf5 has no selector. With a selector the right text is the `NoMatch` text (B9), but no case has a name whose releases are all yanked and a selector. | L2 `registry/yf5b-add-each-yanked-version`: `add acme/gone@1.0.0` where every release is yanked. Expect exit 2 with the no-match text (and no `each release is yanked`), and the same for `acme/gone@latest` expecting the each-yanked text. |
| G3 | q9 (close versions include yanked) | No case has a closure item with a selector that matches nothing and a yanked release in the list; yf6 uses another path (`Add.no_release`). | L2 `install` (or `update`) of `acme/known@9.9.9` with a yanked 1.1.0 in the answer. Expect the close versions without 1.1.0. |
| G4 | q11 (`PatchApply` known `[]`) | No `patch/` case has a patch entry on a yanked release. | L2 `patch/`: a `[patch]` entry whose URL is a yanked release of the registry. Expect the patch applies (no `no release` stop) because the entry URL is held. |
| G5 | q12 (a withdrawn row in `each_yanked_check`) | yf5 has only `yanked: true` rows. | L2 `registry/yf5c-add-each-withdrawn`: every row `withdrawn` (one `yanked`, one `deleted`). Expect the each-yanked text, exit 2. Or an L0 on `each_yanked_check` (make it testable) with a mixed list. |
| G6 | q13, q14 (held URLs not given to `live` in `counted!`) | See the note above: `Domain.with_header` hides the difference. | L2 `update`: a header on a yanked release with `min-release-age` and a newer live release that is too young. Expect the header value kept (R-C9), and that the date of the header value is the real date (for example in the `outdated` or `--json` output), not 0. If no output shows it, drop the `held` argument for the answer path. |

## Round 2 (2026-11-17): the tests for G1 to G6

New tests: L0 `YankfilterTest.roc` (3 `expect`s, G1), L2 `registry/yf5b-add-each-yanked-version` (G2), `yf8-add-nomatch-close` (G3), `yf9-patch-yanked` (G4), `yf5c-add-each-withdrawn` (G5), `yf10-update-held-count` and `yf11-offline-held-count` (G6). Baseline of the code: l0-1 228 pass; L2 of the groups: 247 pass, 1 fail (`yf9`, a code bug or design gap, see the slice file section 14). Log: `.tmp/mut2.log` (same lines as below).

| Mutant | Result now |
| --- | --- |
| q1b | caught: l0-1 (exit=1) |
| q1c | caught: l0-1 (exit=1) |
| q8 | caught: L2 yf5b |
| q9 | caught: L2 yf5b, yf8 |
| q11 | NOT caught, and not catchable: `PatchApply` passes the header URL (`entry.url`) as `known`. A base that needs a lookup is not in the cache, so it is never the header release. `known` holds no base. With `[]` or with the URL, the result is the same (`yf9` fails in both: it also fails on the code). The argument has no effect for the yank. |
| q12 | caught: L2 yf5c |
| q13 | caught: L2 yf10 (the count of a held yanked value) |
| q14 | caught: L2 yf11 |

`yf9` fails in every run, also on the unchanged code, so it is no signal for the mutants. G6 note: `held` is not dead in `counted!`: it keeps a held yanked value out of the count (yf10, yf11).
