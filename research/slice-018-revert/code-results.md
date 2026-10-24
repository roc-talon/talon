# Slice 018 revert check of the code (harness)

Caught 20 of 21. Files equal to the copy after the run: True.

| # | Rule | Mutation | Result (the selftest rows that failed) |
| --- | --- | --- | --- |
| M1 | TW25 | env.sh sets WORK always | caught: OPT unset; OPT=speed |
| M2 | TW25 | bad OPT exits 1, not 2 | caught: OPT=fast |
| M3 | TW25 | default OPT is speed | caught: OPT unset |
| M4 | TW25 | test.sh builds with no --opt | caught: OPT unset; OPT=speed |
| M5 | TW25 | test.sh does not check OPT | caught: OPT unset; OPT=fast |
| M6 | TW25 | run.sh flowprobe build has no --opt | caught: OPT unset; OPT=speed |
| M7 | TW25 | run.sh does not check OPT | caught: OPT unset; OPT=fast |
| M8 | TW25 | commands/run.sh build has no --opt | caught: OPT unset; OPT=speed |
| M9 | TW25 | commands/run.sh does not check OPT | caught: OPT unset; OPT=fast |
| M10 | TW27 | SLOW=1 is ignored | caught: slow tag |
| M11 | TW27 | exdev tag no longer skipped | NOT CAUGHT |
| M12 | TW20 | l0 runs one file at a time | caught: l0 in parallel |
| M13 | TW20 | l0 ignores JOBS | caught: l0 in parallel |
| M14 | TW20 | a failed l0 file does not fail the step | caught: l0 in parallel |
| M15 | TW20 | l0 log in reverse order | caught: l0 in parallel |
| M16 | TW26 | no budget column | caught: the table of test.sh needs the budget column |
| M17 | TW26 | l2 budget 31 | caught: the table of test.sh needs the budget column |
| M18 | TW26 | no total warning | caught: budget |
| M19 | TW26 | no step warning | caught: budget |
| M20 | TW26 | BUDGET_TOTAL ignored | caught: budget |
| M21 | TW26 | a step warning fails the run | caught: budget |
