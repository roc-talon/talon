# Slice 262 mutation check (TW12, Design Q642, G-C272), 2026-11-23

`mutate.sh` (mutants in `mutants.py`) copies cli/, tests/unit and the L2 app to the mirror `.tmp/slice-262-mut/`, applies one mutant, and runs only its L0 driver and its L2 cases (capped 16G, no swap, flocked, timeout 600, TMPDIR in .tmp, OPT=dev). The real cli/ is not changed.
Compiler: nightly-2026-10-14-38a3029. `base` (no change): l0-1, l0-2, l0-5, l0-9 pass, L2 120 of 120 cases pass.

| Mutant | Change | L0 | L2 | Result |
| --- | --- | --- | --- | --- |
| m1-table-not-first | Args.suggest: the table is read only when the edit distance finds nothing | ArgsTest:252 fails (also 2 warnings) | help/hp3-did-you-mean fails | killed |
| m2-limit-length-off-by-one | Args.suggest: limit 1 for a word of 5 letters (`<= 5`) | passed (first run) | 27 cases pass | SURVIVED, then gap test: killed by ArgsTest:252 |
| m3-ignore-not-repeatable | Args.repeated: `--ignore` counts as a repeat | ArgsTest:323 fails | 46 cases pass | killed (L0 only) |
| m4-repeat-before-not-for | Args.finish: the repeat is checked before "not for" (Q262-9) | ArgsTest:306 fails | help/hp2-repeated-flag fails | killed |
| m5-anchor-note-for-upgrade | InstallFlow: the anchor note also for upgrade (R1) | l0-5 passes | upgrade/ug1-flow fails | killed (L2 only) |
| m6-held-line-for-override | Vars.scoped_one: an override anchor gets the held line (D1) | l0-2 passes | probe/dm1-domain fails | killed (L2 only) |
| m7-pinned-mark-not-behind | Outdated.table_lines: `(pinned)` also on an unpinned row with current = wanted | OutdatedTest:148 fails | outdated/od1-table fails | killed |
| m8-line-b-with-roc-toolchain | ManageUpdate.project_hint: line B also when ROC_TOOLCHAIN selects | RocUpdateHintTest:9 fails | roc/up3-project-hint fails | killed |

Gap test for m2 (tests/unit/ArgsTest.roc, the R-CM27 expect): `verfi` (5 letters, 2 edits: a swap and an insert) gives the hint `verify`, and `lxsx` (4 letters, 2 edits from `list` and from `ls`) gives no hint. Rerun: base passes, m2 is killed.

Notes:
- m3 and m6 are killed by one level only (m3 by L0, m6 by one L2 case, dm1-domain). They are not survivors, so no gap test was added.
- m1 also gives 2 compiler warnings (the mutant makes a constant `match`). A real expect failure (ArgsTest:252) and hp3 kill it too, so the warnings alone do not decide the result.
