# Revert check of the code, slice 022b (37 mutations, see code-mutate.py)

Rule: a mutation is CAUGHT when a listed test fails. Only the tests that should catch it were run (no full sweep). The script put all files back from `code-final/` before each mutation and compared them at the end: SAME (run.log for all, run2.log for P18, I7 and F1 after their first edit did not compile or was not caught; the id P2 is not used).

Result: caught 35 of 37. Not caught: I7, I8.

| Not caught | Why |
| --- | --- |
| I7 (`Install.on_path!` reads the cache when `found` is `[]`) | No L2 case runs a command with no `roc` file on `PATH` (the 13 cases that call `path_roc` all have a `roc`). The rule is the first row of the calls table (slice 022b section 4) and N2. A case with an `install` run and the default `fx/path-roc` that expects the one call `path_roc` would catch it. |
| I8 (a failed `sha256_file!` does not end the walk) | No test has a `sha256_file` that fails. The design gives no rule for it (decision D12 of the code agent). A case with `fx/sha256` that gives `Err` would catch it. |

| Id | Result |
| --- | --- |
| P1 | CAUGHT by l0:pathroc (R-SO9: tln is hashed before the file) |
| P3 | CAUGHT by l0:pathroc (R-SO9: a smaller file is hashed) |
| P4 | CAUGHT by l0:pathroc (R-SO9: equal sha256 is not the launcher) |
| P5 | CAUGHT by l0:pathroc (R-SO9: the sha256 is not compared) |
| P6 | CAUGHT by l0:pathroc (R-SO9: the key has no mtime) |
| P7 | CAUGHT by l0:pathroc (R-SO9: the key has no size) |
| P8 | CAUGHT by l0:pathroc (R-SO9: the key has no path) |
| P9 | CAUGHT by l0:pathroc (R-SO9: a NoId row runs again) |
| P10 | CAUGHT by l0:pathroc (R-SO11: a local build is a compiler) |
| P11 | CAUGHT by l0:pathroc (R-SO9: a bad text leaves no run mark) |
| P12 | CAUGHT by l0:pathroc (R-SO9: a row of an older file is kept) |
| P13 | CAUGHT by l0:pathroc (R-SO9: 2 rows for one path) |
| P14 | CAUGHT by l0:pathroc (R-TF2: add_sha drops the unknown fields) |
| P15 | CAUGHT by l0:pathroc (R-TF2: finish drops the unknown fields) |
| P16 | CAUGHT by l0:pathroc (R-TF3: format 2 is read) |
| P17 | CAUGHT by l0:pathroc (D10: id null is corrupt) |
| P19 | CAUGHT by l0:pathroc (R-TF2: read drops the top fields) |
| P20 | CAUGHT by l0:pathroc (R-TF1: the key order of a row) |
| P21 | CAUGHT by l0:pathroc (D10: NoId is not written) |
| P22 | CAUGHT by l0:pathroc (R-TF3: a newer file is written) |
| P23 | CAUGHT by l0:pathroc (R-TF6: a corrupt file is not made again) |
| P24 | CAUGHT by l0:pathroc (R-SO9: the file is written when no row changed) |
| P25 | CAUGHT by l0:pathroc (R-TF3: a warning for a newer file) |
| I1 | CAUGHT by l2:roc/so9-launcher (D5: roc version by name) |
| I2 | CAUGHT by l2:roc/so9-launcher (R-SO9: the cache is not written) |
| I3 | CAUGHT by l2:roc/so9-launcher (R-SO9: the cache is not read) |
| I4 | CAUGHT by l3:compilers/so9-launcher (R-TF6: no warning) |
| I5 | CAUGHT by l3:compilers/so9-launcher (R-TF2: the top fields are lost) |
| I6 | CAUGHT by l3:compilers/so9-launcher (N6: a failed run leaves no row) |
| I8 | NOT CAUGHT by - (a failed hash ends the walk) |
| F2 | CAUGHT by l3:fx/so9-real-fx-path-roc (N3: a file that cannot run counts) |
| F3 | CAUGHT by l3:fx/so9-real-fx-path-roc (N3: a directory counts) |
| F4 | CAUGHT by l3:fx/so9-real-fx-path-roc (N3: the mtime is not in seconds) |
| F5 | CAUGHT by l3:fx/so9-real-fx-path-roc (R-SO9: the order of PATH) |
| P18 | CAUGHT by l0:pathroc (R-TF2: read drops the row fields) |
| F1 | CAUGHT by l3:fx/so9-real-fx-path-roc (N3: a link is not resolved) |
| I7 | NOT CAUGHT by - (N2: the cache is read when no roc is on PATH) |
