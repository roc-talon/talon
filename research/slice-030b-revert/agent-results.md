| Id | Rule | File | Result | First failing test |
| --- | --- | --- | --- | --- |
| F01 | R-CV6 | cli/lib/Facts.roc | caught | l0 unit/pins (rerun with a changed mutation, the first form had a warning) |
| F02 | R-CV6 | cli/lib/Facts.roc | caught | l0 unit/pins |
| F03 | R-CV6 | cli/lib/Facts.roc | caught | l0 unit/pins |
| F04 | R-CV6 | cli/lib/Facts.roc | caught | l2 consent/dl1-resolve consent/dl3-rank4 roc/up1-update |
| F05 | R-CV6 | cli/lib/Facts.roc | caught | l2 roc/up1-update roc/us1-use |
| F06 | R-CV6 | cli/lib/Facts.roc | caught | l2 roc/up1-update roc/us1-use |
| F07 | R-CC8 | cli/lib/Facts.roc | caught | l3 compilers/cv1-first-seen |
| F08 | R-CC8 | cli/lib/Facts.roc | caught | l3 compilers/cv1-first-seen |
| F09 | R-TF3 | cli/lib/Facts.roc | caught | l3 compilers/cv1-first-seen |
| F10 | R-CC8 | cli/lib/Facts.roc | caught | l3 (a failing case of the L2 or L3 run) |
| F11 | R-CV6 | cli/lib/Facts.roc | caught | l2 roc/up1-update roc/us1-use |
| F12 | R-CC8 | cli/lib/Facts.roc | caught | l3 (a failing case of the L2 or L3 run) |
| F13 | R-CC8 | cli/lib/Facts.roc | caught | l2 roc/cv1-pins |
| N01 | R-CV3 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| N02 | R-CV4 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| N03 | R-CV8 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| N04 | R-CV6 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| N05 | R-CV6 | cli/lib/Nightlies.roc | caught | l3 (a failing case of the L2 or L3 run) |
| N06 | R-CV6 | cli/lib/Nightlies.roc | caught | l3 compilers/cv1-first-seen |
| N07 | R-CV3 | cli/lib/Nightlies.roc | caught | l2 roc/cv1-pins roc/df1-default roc/ri1-flow |
| N08 | R-CV6 | cli/lib/Nightlies.roc | caught | l2 roc/cv1-pins |
| A01 | R-CV6 | cli/lib/Nightlies.roc | caught | l0 unit/pins (rerun, the first form had an unused variable) |
| A02 | R-CV6 | cli/lib/Nightlies.roc | NOT CAUGHT | equivalent change: `auto_with_base` also keeps only ids of `auto` or the base, and `auto` has no changed tag |
| A03 | R-CV1 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| A04 | R-NS1 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| A05 | R-CV6 | cli/lib/RocInstall.roc | caught | l2 roc/cv1-pins |
| A06 | R-C9 | cli/lib/Nightlies.roc | caught | l0 unit/pins |
| T01 | R-CV6 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| T02 | R-SC10 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| T03 | R-CV1 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| T04 | R-SC10 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| T05 | R-CV6 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| T06 | R-CV6 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| T07 | R-CV6 | cli/lib/Toolchain.roc | caught | l0 unit/pins |
| R01 | R-CV6 | cli/lib/RocInstall.roc | caught | l2 roc/cv1-pins compilers/cv1-first-seen |
| R02 | R-CV6 | cli/lib/RocInstall.roc | caught | l2 roc/cv1-pins compilers/cv1-first-seen |
| R03 | R-CV6 | cli/lib/RocInstall.roc | caught | l2 roc/cv1-pins compilers/cv1-first-seen |
| R04 | R-CV6 | cli/lib/RocInstall.roc | caught | l2 roc/cv1-pins |
| R05 | R-CV6 | cli/lib/RocInstall.roc | caught | l3 compilers/cv1-first-seen |
| R06 | R-CV6 | cli/lib/RocInstall.roc | caught | l3 compilers/cv1-first-seen |

Code after the run equals code-final/: True
