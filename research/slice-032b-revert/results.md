| id | rule | result | first failing line |
| --- | --- | --- | --- |
| e1 | R-EF1 | caught | l0:evidence 1 failed |
| e2 | R-EF1 | caught | l0:evidence 1 failed |
| e3 | R-EF1 | caught | l0:evidence 1 failed |
| e4 | R-EF1 | caught | l0:evidence 1 failed |
| e5 | R-EF1 | caught | l0:evidence 1 failed |
| e6 | R-EF1 | NOT CAUGHT |  |
| e7 | R-EF1 | caught | l0:evidence 1 failed |
| e8 | R-EF3 | caught | l0:evidence 1 failed |
| e9 | R-EF3 | caught | l0:evidence 1 failed |
| e10 | R-EF1 | caught | l0:evidence 1 failed |
| e11 | R-EF1 | caught | l0:evidence 1 failed |
| e12 | R-EF1 | caught | l0:evidence 1 failed |
| e13 | R-EF3 | caught | l0:evidence 2 failed |
| e14 | R-CM7 | caught | l0:evidence 2 failed |
| e15 | R-CM7 | caught | l0:evidence 2 failed |
| e16 | R-UM1 | caught | l0:evidence 1 failed |
| e17 | R-CM7 | caught | l0:evidence 1 failed |
| e18 | R-CM7 | caught | l0:evidence 1 failed |
| e19 | R-EF1 | caught | l0:evidence 2 failed |
| e20 | R-OUT4 | caught | l0:evidence 2 failed |
| e21 | R-OUT4 | caught | l0:evidence 2 failed |
| e22 | R-OUT4 | caught | l0:evidence 1 failed |
| e23 | R-OUT4 | caught | l0:evidence 2 failed |
| e24 | R-UM1 | caught | l0:evidence 1 failed |
| e25 | R-UM1 | caught | l0:evidence 1 failed |
| e26 | R-UM1 | caught | l0:evidence 1 failed |
| e27 | R-UM1 | NOT CAUGHT |  |
| e28 | R-UM1 | caught | l0:evidence 1 failed |
| e29 | R-UM1 | caught | l0:evidence 1 failed |
| e30 | R-UM1 | caught | l0:evidence 1 failed |
| e31 | R-UM1 | caught | l0:evidence 1 failed |
| w1 | R-CM7 | caught | l0:evidence 1 failed |
| w2 | R-OUT4 | caught | l0:evidence 1 failed |
| w3 | R-OUT4 | caught | l0:evidence 1 failed |
| w4 | R-CM7 | INVALID (does not compile) | l2 build |
| f1 | R-SO20 | caught | l2 evidence/ev1-why |
| f2 | R-SO2 | caught | l2 evidence/ev1-why |
| f3 | R-SO7 | caught | l2 evidence/ev1-why, evidence/ev2-no-compiler |
| f4 | R-EF1 | caught | l2 evidence/ev1-why |
| f5 | R-EF1 | caught | l2 evidence/ev1-why |
| f6 | E3 | caught | l2 closure/cl2-chain, evidence/ev1-why |
| f7 | E5 | caught | l2 evidence/ev1-why |
| f8 | E5 | caught | l2 evidence/ev1-why |
| f9 | E2 | INVALID (does not compile) | l2 build |
| f10 | R-UM1 | caught | l2 evidence/ev1-why |
| f11 | R-UM1 | INVALID (does not compile) | l2 build |
| f12 | R-UM1 | INVALID (does not compile) | l2 build |
| f13 | E1 | NOT CAUGHT |  |
| f14 | E2 | INVALID (does not compile) | l2 build |
| f15 | R-H4 | NOT CAUGHT |  |
| l1 | E5 | caught | l2 ladder/bs2-build-skip-verify |
| l2 | E5 | caught | l2 evidence/ev3-summary |
| l3 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| l4 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un3-verify-units |
| l6 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| l7 | E5 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un3-verify-units |
| l5 | E4 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units, probe/un3-verify-units |
| u1 | R-UM1 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units, probe/un3-verify-units |
| u2 | R-P6 | NOT CAUGHT |  |
| u3 | R-UM1 | caught | l2 evidence/ev3-summary, ladder/bs2-build-skip-verify, probe/un1-units |
| s1 | E1 | caught | l2 evidence/ev2-no-compiler |
| s2 | R-SO7 | caught | l2 evidence/ev1-why, evidence/ev3-summary, install/in1-flow, ladder/bs2-build-skip-verify, ladder/ld-no-check-refuse, probe |

## Second round (after the first run: 2 new rows in `evidence` 1 and 6, and 4 changes that did not compile were redone)

| id | rule | result | first failing line |
| --- | --- | --- | --- |
| e6 | R-EF1 | NOT CAUGHT in round 1, then caught: a row was added to `evidence` 1 (rank 4 in the other tag form) | l0:evidence 1 failed |
| e27 | R-UM1 | NOT CAUGHT in round 1, then caught: the rows for a hang and a crash have modules now (a fail only gives a note) | l0:evidence 1 failed |
| w4 | R-CM7 | caught (the first form had an unused variable) | l2 evidence/ev1-why |
| f9 | E2 | caught (the first form had an unused variable) | l2 closure/cl2-chain, evidence/ev1-why |
| f11 | R-UM1 | caught (the first form had an unused variable) | l2 evidence/ev1-why |
| f12 | R-UM1 | caught (the first form had an unused variable) | l2 evidence/ev1-why |
| f4b | R-EF1 | caught on the real binary (the pin is not read) | l3 why/wy2-evidence |
| f5b | R-EF1 | caught on the real binary (the key has another target) | l3 why/wy2-evidence |

Not caught, and not a test gap (equivalent changes): f13 (the compiler of a member that no entry has: the entry exists for each shown member), f15 (`Ident.of_url` of a path or a foreign value is `Err`, so the `Release` test is not needed for the hash), u2 (`Evidence.ignored` with an empty baseline: a module that the baseline explains is a module that the app uses, so the scan has it in `used`, and `ignored` leaves it out for that reason. L0 `evidence` 5 has the pure rule, mutation e26). f14 was dropped (it did not compile in any form).
