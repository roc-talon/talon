| Id | Rule | File | Result | First failing test |
| --- | --- | --- | --- | --- |
| D02 | R-P4 | cli/lib/Db.roc | caught | unit/db |
| D04 | R-P4 | cli/lib/Db.roc | caught | unit/db |
| D05 | R-P4 | cli/lib/Db.roc | caught | unit/db |
| D07 | R-PK7 | cli/lib/Db.roc | caught | unit/db |
| D09 | R-PK7 | cli/lib/Db.roc | caught | unit/db |
| D13 | R-TF3 | cli/lib/Db.roc | caught | unit/db |
| D14 | R-TF3 | cli/lib/Db.roc | caught | unit/db |
| D16 | R-CC8 | cli/lib/Db.roc | caught | unit/db |
| D18 | R-CC8 | cli/lib/Db.roc | caught | unit/db |
| F01 | R-P4 | cli/lib/Facts.roc | caught | unit/facts |
| F02 | R-P4 | cli/lib/Facts.roc | caught | unit/facts |
| F03 | R-P3 | cli/lib/Facts.roc | caught | unit/facts |
| F04 | R-P4 | cli/lib/Facts.roc | caught | unit/facts |
| F08 | R-EF1 | cli/lib/Facts.roc | caught | unit/facts |
| F10 | R-CV6 | cli/lib/Facts.roc | caught | unit/facts |
| F13 | R-EF1 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| F14 | R-CC8 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| F16 | R-CC8 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| F18 | R-CV6 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| F22 | R-CC8 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| F23 | R-TF3 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| F24 | R-CV6 | cli/lib/Facts.roc | caught | l2 db/cc1-store |
| X01 | R-CC8 | cli/RealDb.roc | caught | l3 fx/db |
| X04 | R-TF3 | cli/RealDb.roc | caught | l3 fx/db |
| X05 | R-TF1 | cli/RealDb.roc | caught | l3 fx/db |
| X07 | R-CV6 | cli/RealDb.roc | caught | l3 fx/db |
| X08 | R-CC8 | cli/RealDb.roc | caught | l3 fx/db |
| X09 | R-CC8 | cli/RealDb.roc | caught | l3 fx/db |
| X10 | R-CC8 | cli/RealDb.roc | caught | l3 fx/db |
| X12 | R-CC8 | cli/RealDb.roc | caught | l3 fx/db |
| X14 | R-P4 | cli/RealDb.roc | caught | l3 fx/db |
| X16 | R-TF3 | cli/RealDb.roc | caught | l3 fx/db |
| X19 | R-TF1 | cli/RealDb.roc | caught | l3 fx/db |
| X23 | R-CC8 | cli/RealDb.roc | NOT CAUGHT |  |
| X24 | R-EF1 | cli/RealDb.roc | caught | l3 fx/db |
| X06 | R-TF2 | cli/RealDb.roc | caught | l3 fx/db |
| X13 | R-P4 | cli/RealDb.roc | caught | l3 fx/db |
| X17 | R-CC8 | cli/RealDb.roc | caught | l3 fx/db |

C5 follow-up (comment in `RealDb.select!` only, SQLite 3.49.1, limit 32766 measured): code-final refreshed, no mutation rerun. Compare after the run: cli equals code-final.
