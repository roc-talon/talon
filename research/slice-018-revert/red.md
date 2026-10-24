# Red run of the slice 018 selftest rows (2026-10-22)

Command: scripts/test.sh on the tree with the new rows and the old harness. All steps pass except selftest (7 rows fail, 24 pass: the 24 are the old rows).

```text
SELFTEST FAIL: OPT unset: each roc build must have --opt=dev (test.sh 4 builds, run.sh 3, commands/run.sh 1)
SELFTEST FAIL: OPT=speed: each roc build must have --opt=speed
SELFTEST FAIL: OPT=fast: exit 2 with 'OPT must be dev or speed', no build
SELFTEST FAIL: the table of test.sh needs the budget column: check 10, fmt 5, l0 10, l2 30, l3 60
SELFTEST FAIL: slow tag: skipped in the fast set, run with SLOW=1 (slow/bad fails, windows stays skipped)
SELFTEST FAIL: l0 in parallel: exit != 0, 'lock.roc: FAILED' with its output, 49 passes, sorted, 2 to 4 at one time (max seen: 1)
SELFTEST FAIL: budget: WARN fmt over its share, WARN total over the whole, no WARN under, exit 0 each time
selftest: 24 passed, 7 failed


step       result seconds
check      pass   6.4
fmt        pass   0.2
l0         pass   16.5
l2         pass   75.4
l3         pass   9.3
selftest   FAIL   21.0
```
