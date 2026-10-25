# Revert check 049a (code agent)

| Mutation | Layer | Result |
| --- | --- | --- |
| 0 baseline (no mutation) | l0 | baseline equal |
| 0 baseline (no mutation) | mini | 0 mini cases failed (want 0) |
| 1 digest without the bundle hash (D1) | l0 | caught by XCacheTest.roc:65 |
| 2 an entry dir may have a dot in its name (a stale temp dir is an entry) | l0 | caught by XCacheTest.roc:88 |
| 3 a manifest with a newer format is deleted, not ignored | l0 | caught by XCacheTest.roc:136, XCacheTest.roc:164 |
| 4 an entry with no binary is a match (has_bin true) | mini | caught by the mini case x/x1-b |
| 5 the manifest of a build has no last_run | mini | caught by the mini case x/x1-a, x/x1-b |
| 6 the loser of a race keeps its temp dir (Exists) | mini | caught by the mini case x/x1-a, x/x1-b |
| 7 the exit code of the app is not the exit code of tln x | mini | caught by the mini case x/x1-a |
| 8 the dir with no binary is not deleted before the rename (stale ignored) | mini | caught by the mini case x/x1-b |
| 9 the temp dir of the build stays after a pass | mini | caught by the mini case x/x1-a, x/x1-b |
| 10 the words after -- are not given to the app | mini | caught by the mini case x/x1-a |
