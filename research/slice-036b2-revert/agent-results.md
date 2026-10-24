# Slice 036b2 code agent results

Revert check: caught 8 of 10 (agent-mutate.py, agent-mutate.log). The code after the runs equals code-final (sha256 check from the repo root: all OK).

| Id | Result |
| --- | --- |
| A1 to A8 | caught (L0 oracleprobe or L2) |
| A9 | not caught: test gap (no case scans 2 releases in one call) |
| A10 | not caught: equivalent (a repeat id gives equal rows) |
