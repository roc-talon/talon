# Slice 032 revert check (TW12)

One change at a time in the private reference (`reference/cli/lib/`, in the tree during the run), by `mutate.py`. Each change ran the steps that can see it: the L0 file `buildskip`, L2 (all cases), or L3 (`update/bs1-build-skip`, `remove/rm1`). The reference is restored after each change (`cmp` with `reference/` shows no difference).
Logs: `mutate-f.log`, `mutate-f2.log` (the `b` rows were run from the console, the same script).

| id | rule | change | result | first failing |
| --- | --- | --- | --- | --- |
| b1 | R-BS2 | digest: no sort | caught | l0 buildskip |
| b2 | R-BS2 | digest: no unique | caught | l0 buildskip |
| b3 | R-BS2 | digest: no line end after a hash | caught | l0 buildskip |
| b4 | R-BS2 | digest: the module path is in the text | caught | l0 buildskip |
| b5 | R-ID6 | target of linux x64 is x64glibc | caught | l0 buildskip |
| b6 | R-ID6 | windows arm64 has a target | caught | l0 buildskip |
| b7 | R-ID6 | the platform is the first node that is not a platform | caught | l0 buildskip |
| b8 | R-ID6 | the compiler is not in the key | caught | l0 buildskip |
| b9 | R-BS1 | the digest is not compared | caught | l0 buildskip |
| b10 | R-BS2 | a fail, hang or crash row can skip | caught | l0 buildskip |
| b11 | R-BS1 | a pass with no digest can skip (digest of the candidate empty too) | NOT CAUGHT at first, then caught: a row was added to `buildskip` 3 | l0 buildskip |
| b12 | R-ID6 | the target is not in the match | caught | l0 buildskip |
| b13 | R-ID6 | the compiler is not in the match | caught | l0 buildskip |
| b14 | R-ID6 | the platform hash is not in the match | caught | l0 buildskip |
| b15 | R-P4 | the row has no digest | caught | l0 buildskip |
| b16 | R-P4 | the row is a fail | caught | l0 buildskip |
| b17 | R-BS2 | the text of the skipped line | caught | l0 buildskip |
| f1 | R-LD7 | `before!` calls `platform!` when the closure has no platform (`roc use`) | caught | l2 resolve/rs-highest-use |
| f2 | R-BS2 | the scan runs again after the verdict did it | caught | l2 ladder/bs2-build-skip-verify |
| f3 | R-BS1 | the query has no key | caught | l2 consent/dl1-resolve |
| f4 | R-BS2 | the digest ignores the used modules | caught | l2 ladder/bs1-build-skip |
| f5 | R-P4 | the row is written with `Keep` | caught | l2 consent/dl1-resolve |
| f6 | R-P4 | no row is written | caught | l2 consent/dl1-resolve |
| f8a, f8b | R-PP4 | a skipped build counts as a probe (`run!`, `verify!`) | caught | l2 install/in1-flow, ladder/bs2-build-skip-verify |
| f9a, f9b | R-BS1 | the skip works with `--no-probe` only | caught | l2 install/in1-flow, consent/dl2-verify-workspace |
| f10a, f10b | R-BS2 | the line of a skip is `build: passed` | caught | l2 install/in1-flow, consent/dl2-verify-workspace |
| f11 | R-OUT4 | `verify` gives `build: Passed` for a skip | caught | l2 ladder/bs2-build-skip-verify |
| f12 | R-EF2 | `--no-probe` has no key (no skip) | caught | l2 ladder/bs1-build-skip |
| f13 | R-BS2 | the verdict gives no scan result | caught | l2 ladder/bs2-build-skip-verify |
| f14 | R-BS2 | no row is written after a pass | caught | l2 consent/dl2-verify-workspace |
| f15 | R-LD5 | the row is written before the judgment of the build | caught | l2 ladder/ld-ladder-flow |
| f16 | R-BS2 | `install` and `update` give `build: Passed` for a skip | NOT CAUGHT at first, then caught: `update/bs1-build-skip` got a `--dry-run --json` run | l3 update/bs1-build-skip |
| f17 | R-BS2 | `remove` gives `build: Passed` for a skip | caught | l3 remove/rm1-remove-entries |
| f19 | R-ID6 | the target is a constant, not `platform!` | caught | l2 consent/dl1-resolve |

Result: 37 changes, 37 caught. 2 were not caught at first (b11, f16): each got a test row (see the rows above). The 3 changes that only the new cases catch (f2, f11, f12) are in `bs1-build-skip` and `bs2-build-skip-verify`.

## Manager review round (2026-10-23): changed rows, one change at a time

| id | rule | change | result |
| --- | --- | --- | --- |
| n1 | R-BS2 | decide: a fail, hang or crash of the digest does not block | caught: l0:buildskip 1 failed |
| n2 | R-BS2 | decide: only a fail blocks (a hang and a crash do not) | caught: l0:buildskip 1 failed |
| n3 | R-BS2 | decide: the digest of the row is not compared | caught: l0:buildskip 1 failed |
| n4 | R-BS1 | decide: a pass with no digest can skip | caught: l0:buildskip 1 failed |
| n5 | R-BS2 | decide: a fail of another digest blocks | caught: l0:buildskip 1 failed |
| n6 | R-P4 | Facts.of_probe: a build fail has no closure | caught: l0:facts 1 failed |
| n7 | R-P3 | Facts.of_probe: a build hang has no closure | caught: l0:facts 1 failed |
| n8 | R-P3 | Facts.of_probe: a build crash has no closure | caught: l0:facts 1 failed |
| n9 | R-BS2 | BuildFlow.after!: only a pass is recorded | caught: l2 FAIL ladder/bs3-build-record |
| n10 | R-P4 | BuildFlow.after!: the row is written with Keep | caught (the first entry matched 2 places, then rewritten): l2 consent/dl1-resolve |
| n11 | R-BS2 | Ladder (update path): the record is written after the verdict of the build (a failed build is not recorded) | caught: l2 FAIL ladder/bs3-build-record |
| n12 | R-BS2 | Ladder (verify path): the record is written after the verdict of the build | NOT CAUGHT at first (the verify path had no failing build): run 7 was added to `bs2-build-skip-verify`, then caught: l2 ladder/bs2-build-skip-verify |
| n13 | R-P4 | Db.fact_order: the closure is not in the order of the rows | caught: l0:db 1 failed |
| n14 | R-BS2 | RealDb: the primary key and the upsert are (hash, nightly, target) again | caught: l3 FAIL update/bs1-build-skip |
| n15 | R-BS2 | FakeDb: the closure is not in the primary key | caught: l2 FAIL ladder/bs1-build-skip |
| n16 | R-P4 | BuildSkip.row: no digest in the row | caught: l0:buildskip 1 failed |
| n17 | R-ID6 | BuildSkip.row: the target is `any` | caught: l0:buildskip 1 failed |
| n18 | R-P3 | BuildSkip.row: the class is always Pass | caught: l0:buildskip 1 failed |
| n19 | R-P4 | BuildSkip.row: the errors are dropped (no module of the platform) | caught: l0:buildskip 1 failed |

Result: 19 changes, 19 caught. 1 was not caught at first (n12), and got a test (run 7 of `bs2-build-skip-verify`).
The older changes b1 to b17 and f1 to f19 of the first round are valid for the unchanged code (`decide` and `row` changed: b9 to b16 are replaced by n1 to n5 and n16 to n19; f14 and f15 by n9, n11, n12). The first round is in the table above in this file.
