# 079b The `PATH` `roc` is a selected compiler for the tool flows

Phase: P1. Status: done

Slice 079b is the plan row 079b of `PLAN-P1.md` (section 2c). It closes dispute D1 of slice 079 (manager, 2026-10-26: the test is wrong under the Q3 decision). `ToolCompiler.selected_of` (pure, L0) is done in slice 079. This slice wires the `PATH` `roc` id into the flows. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files and the private reference are in `research/slice-079b-revert/`.

## 1. Rules

| Rule | Text (short) | Where |
| --- | --- | --- |
| R-T30 | The selected compiler of a tool command is the one that ranks 2, 6 and 7 give (a tool has no project ranks). A `roc` on `PATH` counts when its id is a nightly tag or a release (R-SO10). It is tried first when a toolchain dir has that id. | `ToolFlow.selected_for!` |
| R-SO10 | A `roc` with a nightly or release id counts as an installed compiler with that id. | same |
| R-SO7, R-SO2 | The first rank that gives a compiler wins: `ROC_TOOLCHAIN` (2), then `default-roc` (6), then `PATH` (7). | same |
| R-SO15, R-NI17 | A download of step 4 (or of `tool update` and `tool rebuild`) sets `default-roc` only when no compiler is selected. A `PATH` `roc` is a selected compiler, so nothing is set and the prompt has no line `It becomes the default compiler.` | `ToolCompilerFlow`, `ToolUpdateFlow.defaulted!` |

## 2. The wiring (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `ToolFlow.selected_for` | It becomes `selected_for! : Fx, ToolBuild.Facts => Str` (the reference). `ROC_TOOLCHAIN` not empty, or `facts.selected` (`default-roc`) not empty: `ToolCompiler.selected_of` with `path: Err(NoCompiler)` and no call. Else `OnPath.file!(fx, facts.roots)` (the calls `path_roc`, `read_files path-roc.json` and, the first time, `roc version` and `write_atomic path-roc.json`, slice 022b), its `id` is the `path` of `selected_of`. The lookup is lazy on purpose: a rank above 7 decides without it (R-SO7), so the cases with `default-roc` or `ROC_TOOLCHAIN` keep their `calls.log`. |
| 2 | `ToolFlow.choose!` | `selected: ToolFlow.selected_for!(fx, facts)`. The call comes once for each choice (each tool, each attempt of the build). The first call writes the cache `path-roc.json`, so the next calls read it only. |
| 3 | `ToolUpdateFlow.defaulted!` | `ToolFlow.selected_for!(fx, base)` in place of the pure function, after a download. |

The call order is fixed by the `calls.log` files (the code agent follows the files, not this table).

## 3. Difference from the list of the manager

The manager named `tc1-order`, `ti3-compiler` and `ti2-refusals` as the files that get a `path_roc` call. With the lazy lookup (rank 7 after rank 6), `tc1-order` and `ti3-compiler` have `default-roc`, so they do not change. These cases change instead (all `calls.log`): `ti2-refusals` (3 runs: no default before run 7), `ptool/pt3-move`, `tool/tc2-nothing`, `tg1-git`, `tk1-takeover`, `tr1-rebuild`, `tu1-update`, `x/x3-project`, and `ti4-nothing` (the case of the dispute). Question Q1 asks whether the lookup must be always (the reading of the manager list) or lazy (this slice).

## 4. Tests

| Layer | Case | Content | Rule ids |
| --- | --- | --- | --- |
| L2 new | `tool/tc3-path-roc` (3 runs) | `config.toml` has no `default-roc`, the `PATH` `roc` has the id C (installed, not the newest). Run 1: `tool install acme/two`: one `path_roc` lookup, the round of checks is C, A, B, D (the selected one first), C passes, the build runs with C, no default write. Run 2: `three` with `ROC_TOOLCHAIN` = B: rank 2 wins, no `path_roc` call, the round is B, A, C, D. Run 3: `dl --roc pinned`: `path_roc` from the cache, the pin is downloaded, no default is written (the `PATH` `roc` is selected). | R-T30 R-SO10 R-SO7 R-SO2 R-SO15 R-T17 R-T19 R-T16 |
| L2 changed | `tool/ti4-nothing` (`calls.log`, `rules`) | Run 1: the `PATH` `roc` (`nightly-2026-10-14-38a3029`, not installed) is selected: the question has no `It becomes the default compiler.` line, and `config.toml` is not read before the prompt. One `path_roc` lookup comes first (runs 2 and 3 have the cached lookup). | R-T15 R-NI8 R-T30 R-SO15 R-SO10 |
| L2 changed | `tool/ti2-refusals`, `tc2-nothing`, `tg1-git`, `tk1-takeover`, `tr1-rebuild`, `tu1-update`, `ptool/pt3-move`, `x/x3-project` (`calls.log`) | Each choice with no default and no `ROC_TOOLCHAIN` has the call `path_roc` (and, the first time, the other calls of slice 022b). Stdout, stderr, exit code and tree do not change. In `pt3-move` the first lookup comes earlier in the file, so its `roc version` call moves. | R-T30 R-SO10 |
| L3 changed | `tools/ti1-tool-install`, `ti2-tool-compiler`, `ti3-tool-git`, `tx1-x-run`, `ptools/pt1-flow`, `pt2-x`, `run/rn1-flow` (`expect/roc.log`) | The real `tln` runs `roc version` once on the fake `roc` of `PATH`. One new line `version` in each `roc.log`. Nothing else changes. | R-T30 R-SO10 |

Test counts: 1 new L2 case (3 runs), 9 changed L2 files (8 `calls.log` and the `rules` of `ti4`), 7 changed L3 `roc.log` files. L0: no change (`selected_of` and `try_order` have their rows in slice 079).

The `rules` files of the 9 changed L2 cases have a line `Slice 079b ...` (TW21). Each old `expect/` is in `research/slice-079b-revert/before/`. I read each diff.

## 5. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| The question of `ti4-nothing` run 1 | No line `It becomes the default compiler.` (the design says the prompt adds this line only when the compiler becomes the default, R-NI8, R-SO15). |
| New text | None. |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| The unpack of the app bundle (R-FE4) with a `PATH` `roc` that is installed | `Fetch.unbundler` (slice 060) takes `default-roc`, else the newest installed compiler, else `PATH`. `tc3` shows it (A unpacks, C builds). It is R-FE4, not R-T30. |
| A `PATH` `roc` with a local build id (`debug-<sha>`) | `PathRoc.usable` gives `NoCompiler` (L0 of slice 022b): not selected and not tried. No new case. |
| `x` and the project tool build | They share `ToolFlow.choose!` (`x3-project`, `pt3-move`). |
| `tool update` with a `PATH` `roc` selected and a download | The default is not set (`defaulted!` uses `selected_for!`). Mutation n5 shows that the calls differ; no case has a `PATH` `roc` and a download in `tool update`. |

## 7. Questions (TW17)

| Id | Question | Options | Recommended |
| --- | --- | --- | --- |
| Q1 | The manager list says `tc1-order`, `ti3-compiler` and `ti2-refusals` get a `path_roc` call. Does the lookup of the `PATH` `roc` run always, or only when ranks 2 and 6 give nothing? | (a) Lazy: only when `ROC_TOOLCHAIN` and `default-roc` are empty (this slice: R-SO7, the first rank that gives a compiler wins). (b) Always: one more call in each choice, also with a default. | (a). Rank 7 cannot change the result when rank 6 gives one, and (a) keeps 2 old `calls.log` files. |

## 8. Red output

With the old code (the reference away). The 078b reference is in the tree for this table (it changes `ti2` only).

| Step | Result |
| --- | --- |
| check, fmt | pass |
| l0 | pass |
| l2 | FAIL, 10 cases: `tool/tc3-path-roc` (new), `ti4-nothing`, `ti2-refusals`, `tc2-nothing`, `tg1-git`, `tk1-takeover`, `tr1-rebuild`, `tu1-update`, `ptool/pt3-move`, `x/x3-project` (no `path_roc` call) |
| l3 | FAIL, 7 scenarios (`roc.log` lacks `version`) |
| selftest, l1 | pass |

With the private reference: `scripts/test.sh` passes (check, fmt, l0, l2, l3, selftest, l1).

Overlap with slice 078b: `tool/ti2-refusals/expect/calls.log` has the changes of both slices. It is green only with the code of both. `tool/ti5-stale-recorded` (078b) has `default-roc` in its `config.toml`, so it does not depend on this slice.

## 9. Revert check (TW12)

5 changes of the reference, one at a time (`research/slice-079b-revert/mutate.py`). All are caught.

| Id | Change | Caught by |
| --- | --- | --- |
| n1 | `selected_for!` makes the lookup but gives `""` (PATH never selects) | `tc3-path-roc`, `ti4-nothing` |
| n2 | The lookup also runs with a `default-roc` | `tc1-order`, `ti3-compiler`, `ti1-install`, `pt1-add`, `pt2-install`, `x1-run`, 6 more (`calls.log`) |
| n3 | The lookup also runs with `ROC_TOOLCHAIN` | `tc3-path-roc` run 2 |
| n5 | `defaulted!` (`tool update`, `rebuild`) does not look at `PATH` | `tr1-rebuild`, `tu1-update` |
| n6 | `choose!` does not look at `PATH` | `tc3-path-roc`, `ti4-nothing`, `tc2-nothing`, `tg1-git`, 4 more |

## Review (manager, 2026-10-26)

| Item | Result |
| --- | --- |
| Q1 | Lazy. The `PATH` `roc` is rank 7 of Resolution 13: read it only when `ROC_TOOLCHAIN` and `default-roc` give nothing. |
| Output proposals | Accepted: no default line in `ti4-nothing` run 1. |
| Changed files that differ from the manager list | Accepted. |
| Next | Code agent: green. |

The private reference and `mutate.py` are deleted. `research/slice-079b-revert/before/` stays.

## Disputes (from the code agent)

None.

## Verify results (code agent)

Code: `ToolFlow.selected_for!` (lazy `OnPath.file!` only when `ROC_TOOLCHAIN` and `default-roc` are empty), `ToolFlow.choose!` and `ToolUpdateFlow.defaulted!` call it. No dispute, no question.

`scripts/test.sh` exit 0 (check, fmt, l0, l2, l3, selftest, l1), run once with the code of the 3 slices 078b, 079b and 072d. Revert check: `research/slice-072d-revert/agent-mutate.py` (filtered L2 runs, one change at a time; the file goes back from a copy after each run). Result: caught 4 of 4.

| Id | Change | Result |
| --- | --- | --- |
| b1 | The lookup runs when only one of the ranks 2 and 6 is empty | `tc1-order`, `ti3-compiler` (calls) |
| b2 | The `PATH` id never selects | `tc3-path-roc`, `ti4-nothing` |
| b3 | The lookup also runs with `default-roc` empty and `ROC_TOOLCHAIN` set | `tc3-path-roc` run 2 |
| b4 | `defaulted!` does not look at `PATH` | `tr1-rebuild`, `tu1-update` |

The code is the same as before the mutations (`sha256sum -c` of `research/slice-079b-revert/code-final.sha256` against `cli/lib`; the copy is in `research/slice-079b-revert/code-final/`).

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Disputes, questions | none |
