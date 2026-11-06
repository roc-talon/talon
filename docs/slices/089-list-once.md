# 089 One read of the compiler list

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Source: `PLAN-P1.md` 5b, slice 039c review Q3 ("the compiler list is read at most once for the command"), and the last paragraph of the test agent note of `039c-nightly-moves.md`. Slice 039c made the second search reuse `Probed.listed`. The free-nightly plan (`NightlyFlow.plan!`, step 1) and the oracle loop (`PickLoop.wide!`) still read the list one after the other.

## 1. What the rules say

| Rule | Text (short) |
| --- | --- |
| R-UP6 | Bare `tln upgrade` and `upgrade roc` free the nightly: the compiler list gives N and the downloads |
| R-EP10, R-EP11 | The oracle loop reads D, the compiler list, once, when a failure needs it (`Wide`) |
| R-DI2 | The list comes from the index cache (then `compat.db`, slice 030b) |
| 039c D3, Q3 | At most one read of the list for the command |

The slice is a fix of a command flow, so the rule "at most one read" is a decision of slice 039c and not a design id. No new design text is needed (the manager rule of 039c review).

## 2. The mark of one read

One read of the list (`Nightlies.list!`) writes these calls to `calls.log`: `platform`, `list_dirs <cache>/talon/index/github/roc-lang/nightlies`, then `read_files` of the page (cache hit) or `http_get` and `write_atomic` (a miss), then `db_query ... pinned=<n>`. The case counts the `list_dirs ...roc-lang/nightlies` line.

## 3. Public signature

No public signature changes in the tests. The reference (private) uses this shape, and the code agent is free to choose another:

| Part | Reference |
| --- | --- |
| `NightlyFlow.Plan` | a new field `releases : Try(List(Nightlies.Release), [NotRead])`. `Ok(list)` when `known!` ran. `Ok([])` when the list could not be read (so the loop does not read again: `PickLoop.releases!` gives `[]` for an unreadable list too). `InstallFlow` gives `Err(NotRead)` for a plan that read nothing (no free nightly) |
| `InstallFlow.resolve!` | starts the first search with `Probed.listed` set to `plan.releases` (`PickLoop.start` sets `Err(NotRead)`) |
| `PickLoop.wide!` | no change: it already uses `probed.listed` when it is `Ok` (slice 039c) |

## 4. Tests

| Layer | Case | Rule ids |
| --- | --- | --- |
| L2 | `tests/commands/cases/upgrade/ug6-list-once` (new, 1 run). The world of `upgrade/ur4-candidate` run 2 (project `pp`, pin H, lib 1.1.0 fails on n12, so the nightly moves to n11 and the loop needs D). One `list_dirs ...roc-lang/nightlies` in `calls.log` | R-UP6, R-DI2, R-EP10, R-EP11 |
| L2 | 12 old cases: only `expect/calls.log` changes (see section 6) | the rules of each case |

The expected `calls.log` of the new case has one list read, from the plan (`platform`, `list_dirs`, `http_get`, `write_atomic`, `db_query pinned`). Today it has a second read with `read_files` of the cache page: the stdout, the exit code and the tree diff are the same.

Red output (`tests/commands/run.sh`, current code): `commands: 226 passed, 13 failed`: `upgrade/ug6-list-once` and the 12 cases of section 6. For `ug6-list-once`, `Fx calls differs`: the actual log has 4 more lines (`platform`, `list_dirs ...nightlies`, `read_files ...1.meta ...1.json`, `db_query ... pinned=6`).

## 5. Output

No change of output text, `--json` or exit code.

## 6. Old expected files that change (TW21, for the human review)

How they were made: the private reference ran the whole L2 set, and `UPDATE=1` wrote the 12 files that differ. The diff of each file was read: only whole groups of 4 lines are removed (`platform`, `list_dirs ...nightlies`, `read_files` (or the 3 calls of a miss), `db_query ... pinned=<n>`). No line is added, and no `stdout`, `stderr`, `exit` or `tree.diff` differs. Copies of the old files: `research/slice-089-revert/before/tests/commands/cases/<case>/expect/`.

| Case | Groups removed |
| --- | --- |
| `init/it1-app` | 11 |
| `init/it2-platform` | 5 |
| `init/it3-platform-moved` | 1 |
| `init/it5-version` | 6 |
| `init/it6-exclude` | 5 |
| `init/it6b-exclude-young-move` | 1 |
| `upgrade/ur1-roc` | 13 |
| `upgrade/ur2-consent` | 5 |
| `upgrade/ur4-candidate` | 2 |
| `upgrade/ur5-optional` | 16 |
| `upgrade/ur6-moves` | 4 |
| `upgrade/ur8-exclude-nightly` | 5 |

`init` is in the list because `tln init` also frees the nightly (R-UP6 flow through `InstallFlow`).

With the reference, the L3 cases that have a `nightlies` route in `expect/http.log` (20 cases, plus `update/`, `probe/`, `compilers/`, `init/`) all pass: no L3 file changes. The code agent must still run the L3 fast set.

## 7. Out of scope

| Item | Reason |
| --- | --- |
| Other readers of the list in one command (`NoRank`, `Base.listed!`, `RocInstall`, `Proxy`) | The task names the pair `plan!` and `wide!`. A list read by one of these flows has its own count in the old cases (for example `tool/tu1-update`, `roc/us1-use`) |
| An unreadable list with a `Wide` step (a second failed read) | No test world reaches it: M1 of section 9 is not caught. It needs a case where the list is missing and a probe fails on H |

## 8. Questions (stop until answered)

None. The rule is the 039c decision D3, and the 12 files of section 6 are for the review.

## 9. Revert check

The private reference is deleted (manager rule). It changed `NightlyFlow.roc` and `InstallFlow.roc` as in section 3. With it the whole L2 set passed (239 passed).

| # | Mutation of the reference | Result |
| --- | --- | --- |
| M1 | `plan!` gives `releases: Err(NotRead)` when the list cannot be read | not caught by any test (the loop never reaches `Wide` in `ur3-list` and `pa2-resolve`). Not a behavior of a tested world. Listed in section 7 |
| M2 | `PickLoop.wide!` ignores `probed.listed` (always reads) | caught by `ug6-list-once` and `ur4-candidate` |

The files before the slice: `research/slice-089-revert/before/`.

## 10. Code agent result (2026-11-02)

| Item | Result |
| --- | --- |
| Code | The way of section 3, with these names. `NightlyFlow.Plan.releases : Try(List(Nightlies.Release), [NotRead])` (`Ok(list)` after `known!`, `Ok([])` for an unreadable list, `Err(NotRead)` for a plan with no read). `InstallFlow.listed_start` sets `Probed.listed` from it for the first search. `PickLoop` has no change. Files: `cli/lib/NightlyFlow.roc`, `cli/lib/InstallFlow.roc`. A copy is in `research/slice-089-revert/code-final/` with `code-final.sha256` |
| L2 | `tests/commands/run.sh`: 239 passed, 0 failed (`ug6-list-once` and the 12 old cases pass) |
| L3 | `scripts/test.sh l3`: pass (21.5 s) |
| Not wired | The unreadable list with a `Wide` step (section 7): the code gives `Ok([])` as the reference did, no test reaches it |

Revert check (3 mutations, run with `tests/commands/run.sh ug6 ur4`, 2 cases fail for each): `listed_start` never sets the list, `PickLoop.wide!` ignores `probed.listed`, `plan!` gives `Err(NotRead)`. Caught 3 of 3. The files are equal to `code-final/`.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo` of this slice | None |
| Tests (code agent run) | check, fmt pass. L0 driver of the slice passes. L2 239 of 239. L3 fast set pass. The only L0 failures are the red tests of slice 092. |
| Follow-up | 088b: move the callers with `fx` to `Roots.of_run!`. The config and data fallback on Windows waits for the design answer of G-C14. |
