# Revert check 049b (code agent)

| Mutation | Layer | Result |
| --- | --- | --- |
| 0 baseline (no mutation) | l0 | equal |
| 0 baseline (no mutation) | l2 | equal |
| 1 tie rule: an entry wins over an installed tool of the same version | l0 | caught by XCacheTest.roc:223, XCacheTest.roc:275 |
| 2 selector: a selector matches any version online | l0 | caught by XCacheTest.roc:223 |
| 3 R-B3: the winner needs not be a candidate of the list | l0 | caught by XCacheTest.roc:223 |
| 4 offline: a range or latest matches any build | l0 | caught by XCacheTest.roc:275 |
| 5 versions compare as text (1.9.0 is above 1.10.0) | l0 | caught by XCacheTest.roc:223, XCacheTest.roc:300 |
| 6 D4: the sha256 of the entry is checked after the move | l2 | caught by tool/tk1-takeover |
| 7 NC3: a project uses every entry (the take-over copies and keeps the entry) | l2 | caught by tool/tk1-takeover |
| 8 a run of a cached entry does not write last_run | l2 | caught by x/x1-run, x/x2-offline |
| 9 offline with no flag and no person runs the entry (the prompt answer is ignored) | l2 | caught by x/x2-offline |
