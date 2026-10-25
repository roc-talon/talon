# Revert check, slice 048 part 048a (code agent)

| Mutation | Caught by |
| --- | --- |
| M1 a sha selector with no --git is not a git source | l0 tests/unit/l0-4.roc: new failing lines [33] |
| M2 the same commit is not needed for Keep (any git tool is Present) | l0 tests/unit/l0-4.roc: new failing lines [121] |
| M3 a git install keeps a release tool (no replace, R-T27) | l0 tests/unit/l0-4.roc: new failing lines [121] |
| M4 the source is fetched before the check of the bin dir entry | l2 tg2-gitstops: FAIL |
| M5 wget is accepted for the source archive (curl only, R-DA3) | l2 tg2-gitstops: FAIL |
| M6 --offline is checked after the commit request | l2 tg2-gitstops: FAIL |
| M7 the temp dir of the source is not deleted after a failure | l2 tg2-gitstops: FAIL |
| M8 --path may have a .. part (R-SE12) | l0 tests/unit/l0-4.roc: new failing lines [33] |
| M9 tools.json has no path of a git tool | l0 tests/unit/l0-3.roc: new failing lines [213] |

Caught 9 of 9. Code the same as before: True.
