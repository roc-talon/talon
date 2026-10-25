# Revert check of slice 045 (code agent)

| Id | Mutation | Result |
| --- | --- | --- |
| G1 | the id has 7 characters, not 8 (R-R1) | caught (exit 1) by test tests/unit/l0-3.roc |
| G2 | the commit request sends no token (review Q1) | caught (exit 1) by tests/commands/run.sh roc/gi1-install |
| G3 | gh is asked also when a variable or the test API gives the token | caught (exit 1) by tests/commands/run.sh roc/gi1-install |
| G4 | the nightly note accepts the tag sha anywhere in the commit (R-R2) | caught (exit 1) by test tests/unit/l0-3.roc |
| G5 | newest ignores the time: the last row wins (R-R5, R-R6) | caught (exit 1) by test tests/unit/l0-3.roc |
| G6 | a typed sha does not match the full sha of a build (review Q6) | caught (exit 1) by test tests/unit/l0-3.roc |
| G7 | wget is allowed for a source archive (R-DA3, R-SE12) | caught (exit 1) by tests/commands/run.sh roc/gi1-install |
| G8 | the scratch dir stays after a failed build (R-CC2) | caught (exit 1) by tests/commands/run.sh roc/gi2-zig |
| G9 | the first git build is not made the default (R-SO15) | caught (exit 1) by tests/commands/run.sh roc/gi2-zig |
| G10 | --offline stops after the commit request, not before (R-DI12) | caught (exit 1) by tests/commands/run.sh roc/gi1-install |
| G11 | a 422 is not a usage failure | caught (exit 1) by test tests/unit/l0-3.roc |
| G12 | no check for the dir under the lock (R-CC4 step 4) | caught (exit 1) by tests/commands/run.sh roc/gi2-zig |

Code after the runs: same as code-final (sha256sum -c: all OK)
