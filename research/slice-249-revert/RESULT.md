# Slice 249 mutation check (TW12, `tln yank` and the audit yank data)

Script: `research/slice-249-revert/mutate.sh [mutant names]` (pattern of slice 248). Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-249-mut/`, deleted at the end; the working tree is not changed); a `cmp` check says "SED DID NOT APPLY" when the edit changed nothing (none did). `y12` and `y12j` edit 2 files. Compiler: `$ROC` of `scripts/env.sh` (`ROC=${ROC249:-$ROC}`). Each test run holds `.tmp/heavy.lock` and runs capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one at a time. Tests per mutant: drivers `l0-6` and `l0-9`, and `tests/commands/run.sh yank/ audit/ registry/au7 update/au7 verify/au7 publish/`. Real exit codes are in `run.log` (`exit=1` with `0 compiler errors` is a failed expect, not a compile error). Baseline: l0-6 163 passed, l0-9 189 passed, L2 70 passed. No cap hit, no loop.

Result: 17 mutants. 14 caught, 3 NOT caught (y1, y5, y6: gaps G1 to G3), 0 equivalent. Two of the caught ones are caught at one layer only (y10, y13: weak spots W1, W2).

| # | Mutant (place) | Behavior | Result |
| --- | --- | --- | --- |
| y1 | `YankFlow`: `undo_reason` after the reason check | B4, Q629-2 order | NOT caught (G1) |
| y2 | `YankFlow`: `GITHUB_REPOSITORY` before `undo_reason` | B4 | caught: L2 yk13-undo-reason |
| y3 | `Yank.check_reason`: 500 bytes is too long (`>=`) | B5 limit | caught: l0-6 (L2 passes) |
| y3b | `check_reason`: 501 bytes is good (`> limit + 1`) | B5 limit | caught: l0-6, L2 yk4-reason-checks |
| y4 | `check_reason`: U+007F is not a control character | B5 Cc | caught: l0-6 |
| y5 | `YankCheck.release`: the tag match ignores case | exact tag (Q629-7) | NOT caught (G2) |
| y6 | `YankCheck.release`: 2 rows with one tag give the first (not exit 1) | B6 | NOT caught (G3) |
| y7 | `YankCheck.request`: the PUT body never has the reason | B1 | caught: l0-6, L2 yk1, yk2, yk7, yk8, yk9 |
| y7b | `request`: the DELETE has a JSON content type | B2 | caught: l0-6, L2 yk1, yk2, yk7, yk8, yk9, yk10 |
| y8 | `YankFlow`: the R-AP1 read may use the cache (no `newest`) | B1 fresh read | caught: L2, 10 yank cases (not L0) |
| y9 | `YankFlow`: a 401 repeats the old token | B10 | caught: L2 yk8-renew-401 |
| y10 | `YankCheck.failure`: the no-answer text of an undo says "yank" | B11 | caught: l0-6. L2 passes (W1) |
| y11a | `YankCheck.release`: the R-AP1 stop has direct advice (`needs` false) | B7 | caught: l0-6, L2 yk11 |
| y11b | `YankFlow`: the same in `get_needs!` | B7 | caught: L2 yk11-registry-no-answer (L0 cannot: flow) |
| y12 | audit: a registry prints the no-yank note (text) | B13 | caught: l0-9, L2 8 audit cases |
| y12j | audit: a registry has `no-yank-data` in `--json` notes | B13 | caught: l0-9, L2 5 audit cases |
| y13 | `AuditReport.fix`: a successor does not change the fix (the successor text is off) | B15 | caught: l0-9 only. L2 passes (W2) |

## Gaps (not equivalent, not caught)

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | y1 (`undo_reason` after `reason`) | The expects and yk13 give `--undo` with a good reason (or none), so the order of the two checks is never seen. A mistake would show only with `--undo --reason` of a bad reason. | L2 `yank/yk13-undo-reason`, a run: `--undo --reason <501 bytes>` (and one with a tab). Expect the text `tln yank --undo takes no --reason` (undo first), not the length or control-char text. An L0 expect is not possible (flow order). |
| G2 | y5 (tag match ignores case) | No release row in an L0 or L2 test has a tag that differs only in case from the operand. | L0 `YankCheck.release`: rows `v1.0.0` and a typed `V1.0.0` (and `v1.0.0` typed `V1.0.0` in an answer with only `V1.0.0`): expect the `no indexed release` Usage failure. |
| G3 | y6 (2 rows, one tag, give the first) | The `release` expects (3) have 0 or 1 row for the tag. | L0 `YankCheck.release`: a 200 body with 2 rows of the same tag (log indexes 4 and 9). Expect kind `Internal` (exit 1) and the text with both log indexes. |

## Weak spots

| # | Note | Suggested test |
| --- | --- | --- |
| W1 | y10 is caught at L0 only: `yk10-retries-exhausted` uses `--undo` with 503 busy answers, not with no answer. | L2: a copy of yk10 with `--undo` and 4 times no answer. Expect `The undo may be done.` |
| W2 | y13 is caught at L0 only (l0-9). No L2 audit case has a finding with a successor in the fix. | L2 `audit/`: a `repo-missing` or `moved` finding with a successor; expect `tln update <alias>` in the `fix:` line. |

## Re-run after the new tests (test agent, 2026-11-16)

New tests: L0 `YankcheckTest.roc` (case-sensitive tag, 2 rows with one tag), L2 `yank/yk13-undo-reason` runs 5 and 6, `yank/yk14-undo-no-answer`, `audit/au13-successor-fix` (with a new function `au13_successor_fix` in `tests/tools/mk-audit.py`). Command: `mutate.sh y1 y5 y6 y10 y13`, capped and under flock. Log: `.tmp/mut249.log`.

| # | Result | Caught by |
| --- | --- | --- |
| y1 | caught (was G1) | L2 `yank/yk13-undo-reason` |
| y5 | caught (was G2) | l0-6 (the new case-sensitive expect). L2 passes (no case has a tag that differs by case) |
| y6 | caught (was G3) | l0-6 (the new 2-row expect). L2 passes |
| y10 | caught at 2 layers (was W1) | l0-6 and L2 `yank/yk14-undo-no-answer` |
| y13 | caught at 2 layers (was W2) | l0-9 and L2 `audit/au13-successor-fix` |

Result: 17 mutants, 17 caught, 0 not caught. Gaps G1 to G3 and weak spots W1, W2 are closed. The unmutated base: `yank/` and `audit/` L2 32 of 32, l0-6 165 of 165.
