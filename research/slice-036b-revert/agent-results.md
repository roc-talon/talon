# Slice 036b revert check (code agent)

Run: `python3 -I research/slice-036b-revert/agent-mutate.py` from the repo root. Log: `agent-mutate.log`. 10 mutations, filtered runs only.

| Id | File | Change | Test | Result |
| --- | --- | --- | --- | --- |
| B1 | `cli/lib/Oracle.roc` | `Off` lookup ignores `looked` | L0 `oracleprobe` | caught |
| B2 | `cli/lib/Oracle.roc` | conflict term of place 0 for each slot | L0 `oracleprobe` | caught |
| B3 | `cli/lib/PickLoop.roc` | budget `started: 0` | L2 `probe/lp1-loop` | caught |
| B4 | `cli/lib/PickLoop.roc` | no rekey to the id of the started compiler | L2 `probe/pb1-ladder` | caught |
| B5 | `cli/lib/InstallFlow.roc` | whole tuple always dropped | L2 `probe/lp1-loop` | caught |
| B6 | `cli/lib/InstallFlow.roc` | count of the dropped tuple not carried | L2 `probe/lp1-loop` | caught |
| B7 | `cli/lib/InstallFlow.roc` | the last failure is the final one | L2 `bs3-build-record`, `ld-ladder-flow`, `un1-units` | caught |
| B8 | `cli/lib/Ladder.roc` | the ladder asks the db for the keys of the loop | L2 `lp1-loop`, `rs-new-toml`, `ld-ladder-flow` | caught |
| B9 | `cli/lib/LadderJudge.roc` | a new error in a hash blames the whole tuple | L2 `probe/lp1-loop` | caught |
| B10 | `cli/lib/Units.roc` | a unit fail of the ladder blames the whole tuple | L2 `un1-units`, `ld-ladder-flow`, `bs3-build-record`, `lp1-loop` | NOT CAUGHT: test gap (needs a used module that fails, 036b2) |

After the run the 11 files equal `code-final.sha256`.
