# 104i `is_platform` in `Artifact.Dep`

Phase: P2. Status: review (tests red, 2026-11-03). Model for the code: Sonnet medium. About 6 lines in `packages/records/Artifact.roc`. Plan row: `docs/registry/PLAN.md` 104i. The CLI slice 206 and the Worker slice 125 wait for it. Design: Design Q251, Registry R-AP81, R-AP49 (Dep table), R-RE19, R-PU38 row 13, R-AP51.

## Rules

| Rule | Effect in this package |
| --- | --- |
| R-AP81, R-AP49 | `Artifact.Dep` and `Artifact.DepWire` get `is_platform : Bool`. `true` for the platform entry of a package or platform header, `false` for each other dep. The wire name is `is_platform`: `platform` is a reserved word in Roc. |
| R-AP49 member order | The derived codec writes the members in alphabetical order, so `is_platform` is after `hash` and before `series`: `alias`, `group`, `hash`, `is_platform`, `series`, `url`, `version`. |
| R-AP51 | The member is required on decode. A missing member, `null`, a number, a text, an object or a list is `BadJson`. An unknown member of a dep is ignored. |
| R-PK7 | The tests run on both nightlies. |

## Stub

`Artifact.roc` has the new field in `Dep` and `DepWire` (with the comment). `to_wire` and `from_wire` set `is_platform: crash "todo"` (the code agent writes `d.is_platform` in both). Every test that has a dep fails with `todo`.

## Tests

| File | Case | Rules |
| --- | --- | --- |
| `tests/WireTest.roc` | The `artifact_row` has 3 deps (`local`, `pf` with `true`, `semver`): the old encode, round trip and sort tests now carry the member. | R-AP49, R-AP81 |
| `tests/WireTest.roc` | New: the exact bytes of a package with a platform dep and a plain dep (member after `hash`, `true` and `false`, deps sorted by alias), the decode of it, and the empty `deps` text. | R-AP49, R-AP81 |
| `tests/WireTest.roc` | New: a missing, null, numeric (`1`, `0`), text, object or list `is_platform` is `BadJson`. An unknown member is ignored. | R-AP51 |
| `tests/AnswerTest.roc` | The `detail_bodies` fixtures (R-AP2, W2 bodies of 106) get `"is_platform":false` after `hash` of each dep, and `true` for dep `b` of the first body (`research/slice-104e-revert/gen.py` does the insert, because the Worker sends no member before slice 125). Decode then encode gives the same bytes. The structural check reads the mark. | R-AP73, R-AP49, R-AP81 |

Q400 test (added): one `expect` in `WireTest.roc`: an artifact with 2 marked deps and an app record with a marked dep decode and encode again with the marks unchanged.

Red: 83 tests on both nightlies: 74 pass, 10 fail, all with `todo` (the tests that decode or encode a dep). The closure answer vector has `artifacts: []`, so it does not change.

## Private reference and revert checks

Reference: `research/slice-104i-revert/reference/Artifact.roc` (the stub with `d.is_platform` in the two places): all 83 tests pass on both nightlies. `research/slice-104i-revert/mutate.py`: M1 the encoder always writes `false`, M2 the encoder inverts the mark, M3 the decoder drops the mark, M4 the mark is optional on decode (missing is `false`). All 4 caught. The package file is restored.

## Questions

| # | Question | Effect |
| --- | --- | --- |
| Q400 | R-AP81 says that at most one dep is the platform entry, but it does not say that the decoder refuses an artifact with 2 marked deps (or a marked dep in an app). The client takes the first marked dep (CLI R-C3). Should `Artifact.decode` give `BadJson` for 2 marks? | Answered (Design Q400, Registry R-AP81): no refusal in the decoder. Test change: add one `expect` in `WireTest` that a record with 2 marked deps, and an app record with a marked dep, decode and encode again with the marks as sent (no `BadJson`). The Worker check (422 for 2 platform entries) is a test of slice 125, not of this slice. |

## Code and results (code agent, 2026-11-03)

| Item | Result |
| --- | --- |
| Code | In `Artifact.to_wire` and `Artifact.from_wire` the dep member is `is_platform: d.is_platform` (2 places). The derived codec makes it required and boolean, after `hash`. The decoder refuses nothing more (Q400). |
| Lines | `packages/records/Artifact.roc`: 97 lines. |
| `roc test packages/records/tests/w0.roc` | All 83 pass on nightly-2026-10-14-38a3029 and on nightly-2026-10-31-f7bef6b. |
| `roc fmt --check packages/records/` | Clean on both. |
