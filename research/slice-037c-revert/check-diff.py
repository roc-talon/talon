# Slice 037c: the allowed changes of the expected files of probe/pc2-range, and nothing else (TW21).
# stdout: the `--json` line of run E has `,"downloads":0` at the end of `details`. stderr: the line `skipped 1 compiler download (73.0 MB), pass --probe-downloads` before the failure of runs C, D and E. calls.log, exit, tree.diff: no change.
import difflib, os, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
old = os.path.join(root, 'research/slice-037c-revert/before/tests/commands/cases/probe/pc2-range/expect')
new = os.path.join(root, 'tests/commands/cases/probe/pc2-range/expect')
SKIP = 'skipped 1 compiler download (73.0 MB), pass --probe-downloads'
ok = True
for f in ('stdout', 'stderr', 'calls.log', 'exit', 'tree.diff'):
    a = open(os.path.join(old, f)).read().splitlines()
    b = open(os.path.join(new, f)).read().splitlines()
    d = [l for l in difflib.unified_diff(a, b, lineterm='', n=0) if not l.startswith(('---', '+++', '@@'))]
    plus = [l[1:] for l in d if l.startswith('+')]
    minus = [l[1:] for l in d if l.startswith('-')]
    if f == 'stdout':
        good = len(minus) == 1 and len(plus) == 1 and plus[0] == minus[0].replace('"probes":0}}}', '"probes":0,"downloads":0}}}')
    elif f == 'stderr':
        good = not minus and plus == [SKIP] * 3
    else:
        good = not d
    print(f, 'ok' if good else 'UNEXPECTED', len(minus), 'removed', len(plus), 'added')
    ok = ok and good
sys.exit(0 if ok else 1)
