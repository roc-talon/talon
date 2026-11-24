# 261d mutation check (TW12), nightly-2026-11-13-03dce41, 2026-11-24

`mutate.sh` runs each mutant in a mirror under `.tmp/261d-mut-<stamp>/`: `roc test tests/unit/l0-9.roc`, then the L2 cases `logproof/` and the old cases
`registry/sc3-tool-install`, `registry/sc4-x-registry`, `registry/cv1-roc-default`, `tool/tk1-takeover`, `roc/up1-update`, `x/x1-run`. Each run is capped (16G, no swap), flocked and limited to 300 s.
The reference (no change) passes all runs.

| Mutant | Change | First run | After the gap tests |
| --- | --- | --- | --- |
| tool-never-match | `tool!` finds no row (always skips) | killed: lp16, lp16b to lp16f | killed |
| tool-group-only | the row by group only (any version) | killed: lp16b, lp16c | killed |
| tool-registry-skipped | `log_base` gives no registry for a registry list | killed: lp16, lp16b to lp16f | killed |
| tool-after-build | the tool check after `compile!` | killed: lp16, lp16b, lp16c | killed |
| x-not-checked | no check in `XFlow.build!` | killed: lp16d | killed |
| takeover-not-checked | no check in `XTake.online!` | killed: lp16e, lp16f | killed |
| compiler-tag-only | the row by tag only (any target) | killed: lp17e (gap test 1, made before the run) | killed |
| compiler-largest-index | the row with the largest log index | SURVIVED | killed: lp17f (gap test 2) |
| compiler-no-row-skips | no row matches, so no check | killed: lp17, lp17b to lp17e | killed |
| compiler-registry-skipped | a registry list is not checked | killed: lp17, lp17b to lp17e | killed |
| compiler-install-only | no check for `@...` texts (`roc update`) | killed: lp17d | killed |
| leaf-no-sha256 | `check_leaf` compares the leaf sha256 with itself | killed: l0-9, lp17b, lp17e | killed |
| leaf-release-compare | `check_leaf` uses the release compare for a compiler | killed: l0-9, lp17, lp17c, lp17d | killed |

Not run as a mutant: "a direct list gets checked". A direct list has no rows (`rows: []` in `ToolFlow.release_list_with!` and in `Nightlies.via`), so `tool!` finds no row and the compiler branch is `Direct`. A wrong check is not possible there, so this mutant is equivalent by construction.

Gap tests (both in `research/slice-261d-tests/mk-cases.py`; the expected files are made from the run of the code before 261d by `mk-expect.py`):

| Case | What it pins | Rule |
| --- | --- | --- |
| `logproof/lp17e-other-target` | A row of the same tag for macos_apple_silicon (log index 15, valid leaf) and a bad leaf at 20 (linux): T1 at 20 | R-LV2, R-CV2 |
| `logproof/lp17f-duplicate-row` | A later linux row of the same tag and sha256 (log index 25) with a bad leaf: the check proves 20, the row whose sha256 the download uses; exit 0 | R-LV2, R-CV6 |
