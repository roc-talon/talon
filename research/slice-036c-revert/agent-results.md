# Slice 036c revert check (code agent)

Run: `python3 -I research/slice-036c-revert/agent-mutate.py` from the repo root. Log: `agent-mutate.log`. 11 mutations, filtered runs only.

| Id | File | Change | Test | Result |
| --- | --- | --- | --- | --- |
| C1 | `cli/lib/OracleDomain.roc` | assumed pass on each compiler of D | L0 `oracledomain` | caught |
| C2 | `cli/lib/OracleDomain.roc` | an inferred fact replaces the assumed pass | L0 `oracledomain` | caught |
| C3 | `cli/lib/Oracle.roc` | the hint is the newest nightly | L0 `oracledomain` | caught |
| C4 | `cli/lib/Oracle.roc` | `Wide` with no probe cause | L0 `oracledomain` | caught |
| C5 | `cli/lib/Oracle.roc` | `Wide` for a `Pairs` of `Allowed` | L0 `oracledomain` | caught |
| C6 | `cli/lib/Oracle.roc` | no `Wide` before a lookup round of `Off` | L0 `oracledomain` | caught |
| C7 | `cli/lib/OracleDomain.roc` | H not in D is not degraded | L0 `oracledomain` | caught |
| C8 | `cli/lib/Oracle.roc` | the hint refuses a header that was not read | L0 `oracledomain` | caught |
| C9 | `cli/lib/Explain.roc` | the `stop using` option is repeated | L0 `explain` | caught |
| C10 | `cli/lib/PickLoop.roc` | `wide!` loads the keys that were looked up | L2 `probe/dm1-domain` | caught |
| C11 | `cli/lib/PickLoop.roc` | a list without H is read as D | L2 `probe/dm1-domain` | caught |

After the run the 5 files equal `code-final.sha256`. No mutation survived.
