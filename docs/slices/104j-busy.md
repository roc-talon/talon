# 104j `Busy` in `Problem.Kind`

Phase: P2. Status: review (tests red, 2026-11-03). Model for the code: Sonnet medium. About 3 lines in `packages/records/Problem.roc`. Plan row: `docs/registry/PLAN.md` 104j. Design: Design Q440, Registry R-AP21 (the `/errors/busy` row), R-AP82 (the `on_trap` table), R-AP52.

## Rules

| Rule | Effect in this package |
| --- | --- |
| R-AP21, R-AP82 | `Problem.Kind` gets the tag `Busy` (last, so the list has 18 tags): type `/errors/busy`, status 503. The `title` and `detail` of a trap answer are text that the body carries. |
| R-AP52 | An older `tln` reads the type as unknown. This package reads it as a known kind: `kind_from_uri("/errors/busy")` is `Ok(Busy)`. |
| R-PK7 | The tests run on both nightlies. |

## Stub

`Problem.roc`: the tag is in `Kind`, and `row(Busy)` is `crash "todo"`. The list `kinds` of `kind_from_uri` does not have `Busy` yet, so `kind_from_uri("/errors/busy")` is `Err(UnknownType)` (a wrong value). The code agent writes the arm `Busy => (k, "/errors/busy", 503)` and adds `Busy` to the list.

## Tests (`tests/ProblemTest.roc`)

| Case | Rules |
| --- | --- |
| The table of 17 rows has the 18th row `(Busy, "/errors/busy", 503)`: type, status, and the kind from the type (the two old `expect`s on the table check it). | R-AP21 |
| New `expect`: a trap body decodes with its text kept; `kind_from_uri`, `type_uri` and `status` of `Busy`; the encoder writes the type; decode after encode gives the same body. | R-AP21, R-AP82, R-AP52 |

Red: 84 tests on both nightlies: 81 pass, 3 fail (the table `expect` with `todo`, the kind-from-type `expect` with a wrong value, the new `expect` with `todo`). `roc fmt --check` is clean.

## Other builds (checked 2026-11-03)

No file of `worker/` or `cli/` imports `records.Problem`: `worker/lib/Problem.roc` has its own `Problem.Kind` (slice 101), and the `records` modules do not use `Problem.Kind`. So the new tag does not change a match in the Worker or the CLI. The only exhaustive `match` on `Kind` is `row` in `packages/records/Problem.roc`, and the stub has the arm. `scripts/test.sh check w0` result is in the final report.

## Private reference and revert checks

`research/slice-104j-revert/reference/Problem.roc` (the arm and the list entry written): 84 tests pass on both nightlies. `research/slice-104j-revert/mutate.py`: M1 status 500, M2 the type of `internal`, M3 `kind_from_uri` without `Busy`. All 3 caught on both nightlies. The package file is the stub again.

## Questions

None.

## Code and results (code agent, 2026-11-03)

| Item | Result |
| --- | --- |
| Code | `Problem.row(Busy)` is `/errors/busy`, 503. `Busy` is added to the kind list of `kind_from_uri`. |
| `roc test packages/records/tests/w0.roc` | All 84 pass on nightly-2026-10-14-38a3029 and on nightly-2026-10-31-f7bef6b. |
| `roc fmt --check packages/records/` | Clean on both. |
