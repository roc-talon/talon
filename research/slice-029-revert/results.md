| Id | Rule | File | Result | First failing test |
| --- | --- | --- | --- | --- |
| C01 | R-GC13 | cli/lib/Clean.roc | caught | unit/clean |
| C02 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C03 | R-CM17 | cli/lib/Clean.roc | caught | unit/clean |
| C04 | R-GC12 | cli/lib/Clean.roc | caught | unit/clean |
| C05 | R-GC13 | cli/lib/Clean.roc | caught | unit/clean |
| C06 | R-GC13 | cli/lib/Clean.roc | caught | unit/clean |
| C07 | R-GC13 | cli/lib/Clean.roc | caught | unit/clean |
| C08 | R-GC13 | cli/lib/Clean.roc | caught | unit/clean |
| C09 | R-GC13 | cli/lib/Clean.roc | caught | unit/clean |
| C10 | R-GC12 | cli/lib/Clean.roc | caught | unit/clean |
| C11 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C12 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C13 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C14 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C15 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C16 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C17 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C18 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C19 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C20 | R-J3 | cli/lib/Clean.roc | caught | unit/clean |
| C21 | R-OUT4 | cli/lib/Clean.roc | caught | unit/clean |
| C22 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C23 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C24 | R-GC14 | cli/lib/Clean.roc | caught | unit/clean |
| C25 | R-NI7 | cli/lib/Consent.roc | caught | unit/consent |
| C26 | R-NR3 | cli/lib/Consent.roc | caught | unit/consent |
| C27 | R-NR2 | cli/lib/Consent.roc | caught | unit/consent |
| C28 | R-NI7 | cli/lib/Consent.roc | caught | unit/consent |
| G01 | R-GC13 | cli/lib/Gc.roc | caught | unit/clean |
| W01 | R-GC13 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W02 | R-GC14 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W03 | R-GC14 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W04 | R-NR1 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W05 | R-NM8 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W06 | R-J3 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W07 | R-GC14 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W08 | R-NI7 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W09 | R-NR2 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W10 | R-GC12 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W11 | R-GC14 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W12 | R-J3 | cli/lib/CacheClean.roc | NOT CAUGHT (first run, before the `--json --quiet` run was added to the L2 case) |  |
| W13 | R-GC14 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W14 | R-GC12 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| W15 | R-NI7 | cli/lib/CacheClean.roc | equal change (not a test gap): `Out.show` shows an answer line for any `quiet` | none |
| W16 | R-GC13 | cli/lib/CacheClean.roc | caught | l2 clean/ |
| L01 | R-GC13 | cli/lib/CacheClean.roc | caught | l3 cache/cl |
| L02 | R-NI7 | cli/lib/CacheClean.roc | caught | l3 cache/cl |
| L03 | R-GC13 | cli/lib/CacheClean.roc | caught | l3 cache/cl |
| L04 | R-NM8 | cli/lib/CacheClean.roc | caught | l3 cache/cl |
| L05 | R-GC14 | cli/lib/CacheClean.roc | caught | l3 cache/cl |
| L06 | R-GC14 | cli/lib/CacheClean.roc | caught | l3 cache/cl |
| W12 | R-J3 | cli/lib/CacheClean.roc | caught (after the run with --json --quiet was added) | l2 clean/ |
| K01 | R-CC10 | cli/lib/CacheClean.roc | caught (after Q2: no lock) | l2 clean/ |
| K02 | R-CC10 | cli/lib/CacheClean.roc | caught (the lock of another item) | l2 clean/ |
| K03 | R-CC3 | cli/lib/CacheClean.roc | caught (the prompt under the lock) | l2 clean/ |
| K04 | R-CC10 | cli/lib/CacheClean.roc | caught (a dry run takes the lock) | l2 clean/ |
| W02, W07, W11, W13 | R-GC14 | cli/lib/CacheClean.roc | caught again after Q2 (W11 has the new text of the line) | l2 clean/ |
