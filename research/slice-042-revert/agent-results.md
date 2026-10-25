# Revert check of slice 042 (code agent)

| Id | Mutation | Result |
| --- | --- | --- |
| P1 | 7 kept lines between 2 runs of changes are one hunk | caught (exit 1) by test tests/unit/diff.roc |
| P2 | 2 lines of context after the last change | caught (exit 1) by test tests/unit/diff.roc |
| P3 | 2 places at the same distance: the last one wins | caught (exit 1) by test tests/unit/diff.roc |
| P4 | the first place wins, not the nearest | caught (exit 1) by test tests/unit/diff.roc |
| P5 | a hunk that does not fit is skipped, the file is written | caught (exit 1) by test tests/unit/diff.roc |
| P6 | no marker after a line with no line end | caught (exit 1) by test tests/unit/diff.roc |
| P7 | an Add overwrites a file that the target has | caught (exit 1) by test tests/unit/diff.roc |
| P8 | inserted lines come before deleted lines of a run | caught (exit 1) by test tests/unit/diff.roc |
| P8b | the same, seen by the L1 target | caught (exit 1) by scripts/test.sh l1 |
| P9 | an existing copy dir is overwritten | caught (exit 1) by scripts/test.sh l2 |
| P10 | the platform is copied | caught (exit 1) by test tests/unit/removal.roc |
| P11 | a package that no header names has the mark patched | caught (exit 1) by test tests/unit/listing.roc |
| P12 | the base of the entry is not the hash | caught (exit 1) by scripts/test.sh l2 |
| P13 | the first entry of a new file is [patch.json] | caught (exit 1) by test tests/unit/intent.roc |

Code after the runs: same as code-final (sha256sum -c: all OK)
