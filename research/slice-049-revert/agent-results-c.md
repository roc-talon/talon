# Revert check 049c (code agent)

| Mutation | Layer | Result |
| --- | --- | --- |
| 0 baseline (no mutation) | l0 | equal |
| 0 baseline (no mutation) | l2 | equal |
| 1 GC age boundary: an entry that is exactly as old as the age goes | l0 | caught by XCacheTest.roc:319 |
| 2 an entry whose manifest cannot be read (no manifest) goes | l0 | caught by XCacheTest.roc:319 |
| 3 an entry with a newer format or a manifest that does not parse goes | l0 | caught by XCacheTest.roc:319 |
| 4 the age is measured with the real clock, not with the time of Talon (last_run vs TALON_NOW) | l3 | caught by tools/tx1-x-run |
| 5 the expired x dirs are not in the tree_info call (no size, not in builds) | l2 | caught by gc/gc4-x |
