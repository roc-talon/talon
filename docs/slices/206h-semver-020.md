# Slice 206h: roc-semver 0.2.0

## Scope

Move the CLI and the resolve package from roc-semver 0.1.0 to 0.2.0 by release URL (R-GP3). 0.2.0 adds only `key_bounds`. No path entry (R-GP1 to R-GP7). No test edit.

## Changes

| File | Line | Change |
|---|---|---|
| cli/lib/main.roc | 259 | `semver:` URL 0.1.0 to 0.2.0 (hash BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i) |
| packages/resolve/main.roc | 13 | same |

No other live .roc file outside research/ uses the 0.1.0 URL. worker/ already uses 0.2.0.

## Test results

| Step | Result |
|---|---|
| check, fmt, selftest, l0, l2 (JOBS=3) | pass |
| l3 (JOBS=1) | pass, 100 scenarios passed, 0 failed, 10 skipped |
| resolve tests (ROC_TAG) | conflicts 6, domain 2, moves 5, solver 5: all pass |

The first l3 run failed with a syntax error in tests/run.sh (a parallel session was editing that file). The rerun passed.

## Status

Done.
