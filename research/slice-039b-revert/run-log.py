#!/usr/bin/env python3
# Print the calls of run N of a case: python3 -I research/slice-039b-revert/run-log.py <case> <N> [grep]
import sys, os
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
case, n = sys.argv[1], int(sys.argv[2])
lines = open(f'{root}/tests/commands/cases/{case}/expect/calls.log').read().split('\n')
runs, cur = [], None
for l in lines:
    if l == 'args':
        cur = []
        runs.append(cur)
    if cur is not None:
        cur.append(l)
pat = sys.argv[3] if len(sys.argv) > 3 else None
for l in runs[n - 1]:
    if pat is None or pat in l:
        print(l[:220])
