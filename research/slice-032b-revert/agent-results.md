| id | rule | result | first failing line |
| --- | --- | --- | --- |
| e1 | R-EF1 | caught | l0:evidence 1 failed |
| e2 | R-EF1 | caught | l0:evidence 1 failed |
| e3 | R-EF1 | caught | l0:evidence 1 failed |
| e4 | R-EF3 | caught | l0:evidence 1 failed |
| e6 | R-EF1 | caught | l0:evidence 1 failed |
| e8 | R-EF1 | caught | l0:evidence 1 failed |
| e9 | R-EF1 | caught | l0:evidence 1 failed |
| e10 | R-EF1 | caught | l0:evidence 1 failed |
| e11 | R-EF3 | caught | l0:evidence 2 failed |
| e12 | R-EF3 | caught | l0:evidence 2 failed |
| e13 | R-CM7 | caught | l0:evidence 2 failed |
| e14 | R-UM1 | caught | l0:evidence 1 failed |
| e15 | R-CM7 | caught | l0:evidence 1 failed |
| e16 | R-CM7 | caught | l0:evidence 1 failed |
| e18 | R-OUT4 | caught | l0:evidence 2 failed |
| e19 | R-OUT4 | caught | l0:evidence 2 failed |
| e20 | R-OUT4 | caught | l0:evidence 1 failed |
| e21 | R-OUT4 | caught | l0:evidence 2 failed |
| e22 | R-UM1 | caught | l0:evidence 1 failed |
| e23 | R-UM1 | caught | l0:evidence 1 failed |
| e24 | R-P6 | caught | l0:evidence 1 failed |
| e25 | R-UM1 | caught | l0:evidence 1 failed |
| e26 | R-UM1 | caught | l0:evidence 1 failed |
| e28 | R-UM1 | caught | l0:evidence 1 failed |
| e29 | R-UM1 | caught | l0:evidence 1 failed |
| w1 | R-CM7 | caught | l0:evidence 1 failed |
| w2 | R-OUT4 | caught | l0:evidence 1 failed |
| w4 | R-CM7 | caught | l2 evidence/ev1-why |
| w5 | R-TF3 | caught | l2 evidence/ev1-why |
| f1 | R-SO20 | caught | l2 evidence/ev1-why |
| f2 | R-SO2 | caught | l2 evidence/ev1-why |
| f3 | R-SO7 | INVALID (does not compile) | l2 build  If you don't need this variable, prefix it with an underscore like _$asked to suppress this warning.  ── ● unconditional condition ──────────────────── cli/lib/EvidenceFlow.roc:112:8  This if conditi |
| f4 | R-SO7 | caught | l2 evidence/ev1-why |
| f5 | R-EF1 | INVALID (does not compile) | l2 build ── ● unused variable ─────────────────────────── cli/lib/EvidenceFlow.roc:132:11  Variable path is defined here and then never used.  |hash, (path, read)| (         ^^^^  If you don't need this variab |
| f6 | R-EF1 | caught | l2 evidence/ev1-why |
| f7 | E3 | caught | l2 closure/cl2-chain, evidence/ev1-why |
| f8 | E5 | caught | l2 evidence/ev1-why |
| f9 | E5 | caught | l2 evidence/ev1-why |
| f10 | E2 | caught | l2 closure/cl2-chain, evidence/ev1-why |
| f11 | R-UM1 | INVALID (does not compile) | l2 build ── ● unused variable ─────────────────────────── cli/lib/EvidenceFlow.roc:150:22  Variable s is defined here and then never used.  (Ok(m), Ok(h), Ok(s)) => {                   ^  If you don't need thi |
| f12 | R-UM1 | caught | l2 evidence/ev1-why |
| f13 | R-UM1 | caught | l2 evidence/ev1-why |
| f14 | R-H4 | INVALID (does not compile) | l2 build ── ● unconditional condition ──────────────────── cli/lib/EvidenceFlow.roc:51:15  This if condition is known at compile time, so this conditional will always make the same choice.  hash = if Bool.True |
| f15 | R-TF3 | caught | l2 evidence/ev1-why |
| l1 | E5 | caught | l2 ladder/bs2-build-skip-verify |
| l2 | E5 | caught | l2 evidence/ev3-summary |
| l3 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| l4 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un3-verify-units |
| l5 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| l6 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un3-verify-units |
| l7 | E4 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units, probe/un3-verify-units |
| l8 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| u1 | R-UM1 | INVALID (does not compile) | l2 build suppress this warning.  ── ● unused variable ─────────────────────────────── cli/lib/UnitFlow.roc:163:20  Variable run is defined here and then never used.  ignored_of = |ctx, run, scanned| match scan |
| u2 | R-P6 | NOT CAUGHT |  |
| u3 | R-UM1 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| u5 | R-UM1 | caught | l2 evidence/ev3-summary, ladder/bs1-build-skip, ladder/bs2-build-skip-verify, ladder/bs3-build-record, ladder/ld-ladder-flow, probe/un1-units,  |
| s1 | E1 | caught | l2 evidence/ev2-no-compiler |
| s2 | R-SO7 | caught | l2 evidence/ev1-why, evidence/ev3-summary, install/in1-flow, ladder/bs2-build-skip-verify, ladder/ld-no-check-refuse, probe/un3-verify-units, r |

Second form of the 5 changes that did not compile (f3, f5, f11, f14, u1):

| id | rule | result | first failing line |
| --- | --- | --- | --- |
| f3b | R-SO7 | NOT CAUGHT |  |
| f5b | R-EF1 | caught | l2 evidence/ev1-why |
| f11b | R-UM1 | caught | l2 evidence/ev1-why |
| f14b | R-H4 | NOT CAUGHT |  |
| u1b | R-UM1 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units, probe/un3-verify-units |

Not caught:

| id | Kind | Reason |
| --- | --- | --- |
| u2 | test gap | `UnitFlow.verdict!` gives the baseline to `Evidence.ignored`. With an empty baseline the L0 rows (e24) fail, but no L2 case has a fail with 2 modules where the baseline explains one and the app does not use the other. The L2 case `un1` run 2 has a fail that the baseline explains in full, so the scan does not run |
| f3b | test gap (known, slice section 11) | `path_roc` is asked once for the run. No L2 case has 2 member files, so no test counts the calls with 2 members |
| f14b | equivalent | `Ident.of_url` of a `Path` row or a `Foreign` row is `Err`, so the test `kind == Release` is not needed for the hash |
