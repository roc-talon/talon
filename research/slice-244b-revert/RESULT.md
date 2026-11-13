# Slice 244b mutation check (TW12)

Script: `research/slice-244b-revert/mutate.sh [mutant names]`. Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-244b-mut/`, deleted at the end; the working tree is not changed). Each test run is capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one mutant at a time. L2 binary built with `--opt=dev`. Tests per mutant: the l0-9 driver and `tests/commands/run.sh audit/`; for the mutants in `Github.roc` and `PrivacyGuard.roc` also `index/` and `registry/` (the leak check). Baseline: l0-9 180 passed, L2 `audit/ index/ registry/` 139 passed. No cap hit, no mutant looped.

Result: 14 mutants. 12 caught, 2 NOT caught (G1, G2). No equivalent mutant.

| # | Mutant (place) | Behavior | Caught by |
| --- | --- | --- | --- |
| d1 | `direct_finding`: `prerelease` wins over `asset-replaced` | R-AU13 order (direct) | NOT caught (G1) |
| d2 | `direct_finding`: a draft is the release | R-DI3 | L0 b1 |
| d3 | `direct_finding`: `v2.1.0` is the tag `2.1.0` | R-DI3 | L0 b1 |
| d4 | `direct_finding`: `new_hash` with 1 or more other assets | R-DI15, Q-244b-2 | L0 b1 |
| d5 | `direct_finding`: the header asset and another is `asset-replaced` | R-DI4, Q-244b-2 | L0 b1 |
| d6 | `moved_to`: the same name in another case is a successor | Q-244b-1 | L0 b1 |
| d7 | `repos_of`: a repository listed twice | R-DI2, R-DI11 | L0 b2 |
| d8 | `of_guarded`: a refused repository is not counted | Q620 item 9 | L0 b4, L2 ad9-guard |
| d9 | `AuditFlow.registry!`: the hashes of a refused repository stay in the query | Q620, R-RG4 | L2 ad9-guard (L0 cannot: flow code) |
| d10a | `PrivacyGuard.guard!`: collect mode stops on a refusal | Q620 | L2 ad9-guard |
| d10b | `PrivacyGuard.guard!`: `check!` does not stop on a refusal (leak) | R-RG4 | L2 registry/rg4-guard, registry/ad35-stop-cases |
| d11 | `Github.fetch!`: a 404 is `gone` for any command (leak) | Q-244b-1 | L2 index/di-list-flow, registry/rg9-add-full-down |
| d12 | `Github.fetch!`: a redirect to any location is followed | Q-244b-1 (same API base only) | NOT caught (G2) |
| d13 | `Github.fetch!`: the pages of a redirected list are written to the cache | Q-244b-1 | L2 audit/ad1-direct |

Note: for d10a and d10b the l0-9 run says "All (180) tests passed" with exit 2 (the compiler warns about the unused or constant `collect` flag). That is not a test result.

## Gaps (not equivalent, not caught)

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | d1 (`prerelease` before `asset-replaced`) | b1 has a prerelease row, a draft and prerelease row, and a redirect row with prerelease and a replaced asset (the redirect row then gives `prerelease` or `asset-replaced` by the successor field, not by the order of a plain list). No row has a non-redirected release that is a prerelease AND has no header asset. | L0 b1: a row `prerelease: true`, assets without the header hash, one other asset. Expect `AssetReplaced` with that new hash (R-AU13: asset-replaced before prerelease). |
| G2 | d12 (the redirect is followed to any location) | No case has a 301 with a `Location` on another API base, so the base check is never used. This is the case that would send the token to a foreign host. | L2 `audit/` case (or an L0 on `Github`): the first page answers 301 with `Location: https://evil.example/repositories/42/releases...`. Expect no second `http_get` and exit 15 (`status_failure`, as other commands), or the finding that Q-244b-1 gives. Also a 301 with no `Location` header. |

## Update: re-run of d1 and d12 after the new tests

`mutate.sh d1 d12` (same caps, no outer scope; log `run2.log`). The test agent added L0 b1 row 10b (G1) and the L2 cases audit/ad10-redirect-host and ad11-redirect-none (G2).

| Mutant | Before | After | Caught by |
| --- | --- | --- | --- |
| d1 (`prerelease` before `asset-replaced`) | NOT caught | caught | L0 (1 failed) |
| d12 (a redirect to any location is followed) | NOT caught | caught | L2 audit/ad10-redirect-host |

G1 and G2 are closed. All 14 mutants are caught.
