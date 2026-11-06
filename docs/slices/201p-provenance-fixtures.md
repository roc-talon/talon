# 201p Provenance in CLI fixtures

Phase: P2. Status: done. Reason: records slice 122 (`docs/slices/122-provenance.md`) adds the required member `provenance` to each release record (R-AP49, R-PU15).

## Files changed

None. No CLI test or fixture holds a release record. The `research/slice-201p-revert/before/` folder holds no copy, because no file changed.

## What was checked

| Place | Result |
| --- | --- |
| `tests/unit/ClosurerequestTest.roc` | `rows` are R-AP5 toolchain rows (`id`, `published_at`, `log_index`), not releases |
| `tests/unit/RegtoolchainsTest.roc` | Toolchain rows (`tag`, `target`, `asset_name`, `sha256`, `size`, `published_at`, `log_index`). Not releases |
| `tests/unit/ShortnamesTest.roc` | `first_log_index` of package hits. Not releases |
| `tests/unit/ClosureTest.roc`, `PickTest.roc` | No `log_index` and no `Release.Row` or `Release.Wire` |
| `tests/commands/L2Registry.roc` | Prints toolchain rows |
| `tests/commands/cases/registry/*/fx/http/` | Answers of `/v1/toolchains` and `/v1/packages` (toolchain rows, short names). `ap24-read-cache` has only the GitHub list `"releases":[]` |
| Other cases with `"release"` | `ptool/*` manifests: package source kind, not records |
| `cli/` | No use of `Release.Row`, `Release.Wire`, `Closure.Answer` |

## Result (2026-11-02)

| Check | Result |
| --- | --- |
| `roc test tests/unit/l0-N.roc --no-cache`, N = 5 to 8 | Compile and pass |
| N = 1 to 3 | Do not compile. Cause: `packages/records/Code.roc:112` (`via_sort`, `.sort()` on `Str`: no `order_relative_to`). This is the code of slice 122, in work. Not a fixture problem |
| N = 4 | Fails. Cause: `ToolbinlistTest`, `ToolbincheckTest`, `ToolbinuseTest`, `ShareTest` (the tool-flow slices 092 and 093, in work). Not a fixture problem |
| `tests/commands/run.sh registry/` | 6 passed, 0 failed |

## Rows that wait

| Row | Waits for |
| --- | --- |
| l0-1, l0-2, l0-3 (compile) | 122 green (`Code.via_sort`) |
| l0-4 | Slices 092 and 093 |

When the CLI client reads a release (`Release.Wire` decode, slice 201 follow-ups, R-AP51), its fixtures need `provenance`, for example `["ingest"]`, or `["oidc","ingest"]` for a published release, between `log_index` and `published_at`.
