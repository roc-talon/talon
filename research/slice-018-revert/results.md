# Revert check of the slice 018 selftest rows (2026-10-22)

The test agent wrote a private reference of the harness change (about 70 lines in `scripts/test.sh`, `scripts/env.sh`, `tests/lib.sh`, `tests/run.sh`, `tests/commands/run.sh`). The reference is deleted: the files are back to the copies in `before/`. With the reference:

| Run | Result |
| --- | --- |
| `tests/selftest.sh` | 31 passed, 0 failed (24 old rows, 7 new rows) |
| `scripts/test.sh` (dev builds) | all steps pass in 30 s (before: 118 s). l0 3.6 s, l2 0.5 s, l3 9.3 s, selftest 13.1 s |

Each mutation of the reference below was run alone against `tests/selftest.sh`. All 21 make a new row fail.

| Mutation of the reference | Row that fails |
| --- | --- |
| OPT default is speed | OPT unset |
| flag text is always `--opt=dev` | OPT=speed |
| a bad OPT value is accepted | OPT=fast |
| `scripts/test.sh` builds without the flag | OPT unset, OPT=speed |
| `tests/run.sh` builds `flowprobe` without the flag | OPT unset, OPT=speed |
| `tests/commands/run.sh` builds without the flag | OPT unset, OPT=speed |
| `env.sh` ignores `WORK` | OPT unset, OPT=speed |
| `SLOW=1` is ignored | slow tag |
| `SLOW=1` also runs the `windows` tag | slow tag |
| L0 runs with `-P 1` | l0 in parallel (max seen 1) |
| L0 runs with `-P 0` (no limit) | l0 in parallel (max seen 50) |
| a failed L0 file does not fail the step | l0 in parallel |
| a failed L0 file is not named | l0 in parallel |
| the L0 log is in reverse order | l0 in parallel |
| no warning for a step | budget |
| a warning for every step | budget |
| `BUDGET_FMT` is ignored | budget |
| no warning for the total | budget |
| a warning makes the exit code 1 | budget |
| the table has no budget column | table |
| default budget of l2 is 60 | table |
