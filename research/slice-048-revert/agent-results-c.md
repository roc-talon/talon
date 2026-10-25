# Revert check, slice 048 part 048b (code agent)

| Mutation | Caught by |
| --- | --- |
| M1 a branch whose head moved is up to date (no new build) | l0 tests/unit/l0-4.roc: new failing lines [192] |
| M2 a sha-pinned ref is a branch (the head is requested, R-SL10) | l0 tests/unit/l0-4.roc: new failing lines [192] |
| M3 a release tool is compared with no selector (any build is enough, not the newest release) | l2 tu1-update: FAIL |
| M4 a release tool is always built (no up to date) | l2 tu1-update: FAIL |
| M5 the pinned text has no key prefix | l0 tests/unit/l0-4.roc: new failing lines [216] |
| M6 the consent stop does not stop: the builds start (consent before any build) | l2 tu1-update: FAIL |
| M7 update builds with the recorded compiler, not the pin of the new header (R-T24) | l2 tu1-update: FAIL |

Caught 7 of 7. Code the same as before: True.
