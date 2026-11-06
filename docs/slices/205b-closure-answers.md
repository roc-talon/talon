# 205b Closure answers

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Follow-up of slices 201 (`cli/lib/Registry.roc`) and 205 (`cli/lib/ClosureRequest.roc`). Their open questions G-C24 to G-C29 have design answers: DESIGN-REGISTRY.md R-AP74 (rows 1 to 7), R-AP16 (`hashes`), R-AP61, R-AP60, R-AP57, and DESIGN.md Q194 to Q199. Pure, L0 only. Tests are in `tests/unit/RegistryTest.roc` and `tests/unit/ClosurerequestTest.roc` (driver `l0-8.roc`).

## Rules

R-AP74, R-AP16, R-AP60, R-AP61, R-AP57 (row 1 only: nightlies), R-E6, R-J7, R-AP52, R-NS2, R-EC10, R-WS2, R-SP23.

## Answers and where they are tested

| Question | Answer | Test |
| --- | --- | --- |
| G-C24 (Q194, 201 Q2) | `POST /v1/closure` is a read: 400 and 413 are exit 1, any other 4xx is exit 15, a body that is not a problem is exit 15 | `RegistryTest` table, 13 new rows with method `Query` |
| G-C25 (Q195, 201 Q3) | `unsupported-client` with no `minimum`: exit 1, text `tln <v> is too old for <base URL>: update to the newest version`. A `minimum` that is not text is read as missing | `RegistryTest` texts, and one separate `expect` for the non-text case |
| G-C26 (Q196, 205 Q2) | `range` is the distinct ranges, first-appearance order, joined with `, `. `*` is dropped. No range left: omitted | `ClosurerequestTest`, `join_ranges` |
| G-C27 (Q197, 205 Q3) | A command that must choose a compiler: no query, exit 10. A report-only command: no `compilers`. An empty window is never sent | `ClosurerequestTest`, `Report`, `no_compiler` |
| G-C28 (Q198, 205 Q4) | `hashes` has each header entry that has a hash, also when its group is in `groups`, each hash once, first-appearance order | `ClosurerequestTest`, first `expect` (changed row) |
| G-C29 (Q199, 205 Q5) | Nightlies only. A held release pin is a missing end (R-AP60) | The `Held("0.1.0")` row (already there). No new row |
| TW24 addition | A body that is not a problem: `details` has `status` only | Slice 201 already did this (`d3`). New rows `d5`, `d6` give the same for `Query` |
| Q208 (default registry URL) | The exact name is not given | 201 and 205 have no default-registry constant. Nothing is tested |

## Public signatures (changed or new)

| Name | Change |
| --- | --- |
| `Registry.Method` | `[Get, Query, Post, Put, Delete]`. `Query` is `POST /v1/closure`. `refuse` treats `Post`, `Put` and `Delete` as a write (exit 20), and `Get` and `Query` as a read. Stub state: the type has the new tag, the body of `refuse` is old code, so the `Query` rows fail with a wrong value |
| `ClosureRequest.Window` | New tag `Report(Domain)`: as `Free`, for a command that only reports. No compiler stays: `compilers` is `Err(None)` (no member), not `Err(NoCompiler)`. `Free` with no compiler stays `Err(NoCompiler)` (the command stops). The arm in `window_of` is `crash "todo: slice 205b"` |
| `ClosureRequest.join_ranges` | `List(Str) -> Try(Str, [None])` (stub) |
| `ClosureRequest.no_compiler` | `Domain -> Fail` (stub): kind `NoTuple` (exit 10), the message names the first cause in this order: the list is empty, the `nightly` switch, the `[toolchain] roc` range, `min-release-age`, the snapshot |

## Changed reading of slice 205 (reading 2)

`hashes` is now one hash for each distinct hash of the entries, first appearance order (205 kept repeats). The doc comment of `ClosureRequest.request` still says "a repeated hash is repeated": the code agent must change it. The row of `ClosurerequestTest` that kept the repeat `[h_cli, h_json, h_cli]` now has `[h_cli, h_json]`.

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `RegistryTest` table: 13 `Query` rows (400 and 413 exit 1, 401 to 422, 429, 502 exit 15, bodies that are not problems exit 15) | R-E6, R-AP74 row 1, R-AP52 |
| L0 | `RegistryTest` details: `Query` with and without a problem body | R-J7, R-AP74 rows 1 and 7 |
| L0 | `RegistryTest` texts: no `minimum` (text and exit 1), `minimum` with `Query` | R-AP74 row 2 |
| L0 | `RegistryTest` non-text `minimum` (separate `expect`) | R-AP74 row 2 |
| L0 | `ClosurerequestTest` hashes: repeat removed, same hash in another URL, order of first appearance, hash kept when its group is in `groups` | R-AP16, R-AP74 row 5 |
| L0 | `ClosurerequestTest` `Report`: as `Free` when a compiler stays, no member when none stays (6 causes), body text, `Free` still stops, never an empty window | R-AP74 row 4, R-AP61, R-AP16 |
| L0 | `ClosurerequestTest` `no_compiler`: exit 10 and the text for each of 6 causes, first cause wins | R-AP74 row 4, R-NS2, R-EC10 |
| L0 | `ClosurerequestTest` `join_ranges`: one, two, order, duplicates, comma-list range, `*`, only `*`, empty | R-AP74 row 3, R-WS2, R-SP23 |

Red result (`roc test tests/unit/l0-8.roc`, log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red205b.log`): 114 pass, 7 fail.

| Fail | Reason |
| --- | --- |
| `ClosurerequestTest` hashes | Wrong value (repeat kept) |
| `ClosurerequestTest` `Report` | `todo: slice 205b` |
| `ClosurerequestTest` `no_compiler` | `todo: slice 205b` |
| `ClosurerequestTest` `join_ranges` | `todo: slice 205b` |
| `RegistryTest` table | Wrong value (`Query` 4xx gives 20) |
| `RegistryTest` texts | Wrong value (no `minimum` gives the generic text) |
| `RegistryTest` non-text `minimum` | `records.Problem.decode` gives `NotProblem` today (exit 15). See Q6 |

Revert check (`research/slice-205b-revert/before/`, the reference is deleted): the reference was green (120 pass) except the non-text `minimum` row (Q6). 4 mutations, each caught by one `expect`:

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `join_ranges` keeps `*` | `join_ranges` row |
| M2 | `join_ranges` keeps repeats | `join_ranges` row |
| M3 | `hashes` keeps repeats | hashes row |
| M4 | `no_compiler` names the range cause before the switch | `no_compiler` row |

## Output (proposed, R-OUT2, TW24)

| Case | Kind | Message |
| --- | --- | --- |
| `unsupported-client`, no `minimum` | internal (1) | `tln <version> is too old for <origin>: update to the newest version` (the text is in R-AP74 row 2) |
| No compiler, list empty | no_tuple (10) | `no compiler is left: the compiler list of the registry is empty` |
| No compiler, switch off | no_tuple (10) | `no compiler is left: the registry lists nightlies only and the nightly switch is off` |
| No compiler, range | no_tuple (10) | `no compiler is left: the [toolchain] roc range <range> matches no nightly` |
| No compiler, age | no_tuple (10) | `no compiler is left: min-release-age hides each compiler` |
| No compiler, snapshot | no_tuple (10) | `no compiler is left: the snapshot hides each compiler` |

The order of the causes when two hold is a proposal too (R-AP74 row 4 names the 4 causes but not the order).

## Out of scope

| Item | Reason |
| --- | --- |
| The flow that calls `no_compiler` (no query, exit 10) and the choice of `Free` or `Report` for a command | Slice 206 and the command slices |
| Which variables give which groups and ranges (the caller of `join_ranges`) | Slice 206 |
| The default registry URL constant | Q208: no name yet. 201 and 205 have no such constant |
| A release row in the compiler list | Q199: P2 lists nightlies only. The list never has a release row, so no test |

## Questions

| # | Question | State |
| --- | --- | --- |
| Q6 | A `minimum` that is not text (R-AP74 row 2) must be read as missing, but `records.Problem.decode` gives an error for it, so `Registry.problem` gives `NotProblem` and the exit code is 15. The fix is in `packages/records` (decode a non-text `minimum` as `Err(Missing)`) with its own test in the records slice. The test agent did not edit `packages/records` | Open, for the manager |

## Disputes (from the code agent)

None. Q6 (non-text `minimum`) stays red: it needs `packages/records`, asked of the TalonRegistry manager. Green result: 120 pass, 1 fail (Q6 row), `roc check cli/main.roc` and `tests/commands/main.roc` clean, `roc fmt --check` clean.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo: slice 205b"` | None |
| `roc test tests/unit/l0-8.roc --no-cache` | 120 of 121 pass. The Q6 row (non-text `minimum`) passes after records 104g (Q250). The 1 failure is `ShareTest.roc:233`, a red test of slice 214 (in work). |
| Revert check | Test step: M1 to M4 caught. |
| Design | R-AP74 now states the cause order, the comma-list range rule and the hash dedupe (TalonRegistry, 2026-11-02). |
