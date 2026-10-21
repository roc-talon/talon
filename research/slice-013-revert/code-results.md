| Id | Rules | Result |
| --- | --- | --- |
| N1 | R-SO20 | caught by l0:pin |
| N2 | R-SO20 R-SP1 | caught by l0:pin |
| V1 | R-SO21 | caught by l0:pin |
| E1 | R-SO19 | caught by l0:pin |
| SAME | R-SO20 | caught by l0:pin (first try: compile error, row changed) |
| S1 | R-SO22 R-H6 | caught by l0:pin |
| X1 | R-SO19 | caught by l0:pin |
| X2 | R-SO19 | caught by l0:pin |
| T1 | R-SO20 | caught by l0:pin (first try: the pattern hit a doc line, row changed) |
| G5 | R-SO19 G5 | caught by l2:ladder/ld-no-check-refuse (first try: the row gated the pin id, no bug, row changed) |
| NS4 | R-NS4 R-SO21 | caught by l3:verify/vf1-verify |
| EL | R-SO19 | caught by l3:verify/vf1-verify |
| PA | R-SO13 | caught by l2:resolve/rs-no-compiler |
| RO | R-SO21 | caught by l3:verify/vf1-verify (first try: compile error, row changed) |
| R1 | R-RP2 R-SO17 | caught by l2:resolve/rs-failures |
| R2 | R-RP2 | caught by l3:remove/rm2-workspace (first try: compile error, row changed) |
| R3 | R-RP2 Q37 | caught by l3:remove/rm2-workspace |
| WI | R-SO19 R-SO20 | caught by l3:verify/vf1-verify |
| WU | R-SO20 | caught by l3:update/up1-update-entries |
| WR | R-SO20 | caught by l3:remove/rm2-workspace |
| WV | R-SO21 | caught by l3:verify/vf1-verify |
| C1 | R-SO22 R-PH7 | caught by l3:update/up1-update-entries |
| C2 | R-SO22 R-LF1 | caught by l3:install/in1-workspace-frozen-rename |
| NR | R-SO20 (remove) | caught by l3:remove/rm2-workspace |
| NI | R-SO20 (install) | caught by l2:ladder/ld-no-check-refuse |
| N3 | R-NS9 R-NS10 | caught by l3:verify/vf1-verify |
| FD | R-SO19 R-RP3 | NOT CAUGHT (equal in P0: a write follows a passed probe, so the held id is the roc on PATH) |
| VH | R-SO21 | caught by l3:verify/vf1-verify (first try: compile error, row changed) |
