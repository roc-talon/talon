# Slice 038, code agent: filtered revert check of the code (about 10 mutations of the tricky behaviors).
# Each mutation changes one line of cli/lib/<file>, runs the 3 L0 files of the slice, and when none fails, the L2 cases `upgrade/` and `resolve/rs-new-toml`
# (dev build with --no-cache). The file is put back from research/slice-038-revert/code-final/ after each run.
# Run: python3 -I research/slice-038-revert/agent-mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
final = os.path.join(root, 'research/slice-038-revert/code-final/cli/lib')
roc = os.environ.get('ROC') or os.path.join(root, 'cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
FILES = ['ranges', 'vars', 'upgrade']
M = [
 ('A1', 'Vars.roc', 'free = indexed and (if all !anchor else is_named)\n\t\t\tmovable', 'free = indexed and (all or is_named)\n\t\t\tmovable', 'an anchor is free when no name is given (R-UP1)'),
 ('A2', 'Vars.roc', 'if free or movable { ..variable, ranges: [] }', 'if free { ..variable, ranges: [] }', 'a movable variable keeps its ranges (R-SP23)'),
 ('A3', 'Ranges.roc', '${if body.ends_with(".*") ".*" else ""}', '${if body.ends_with(".*") "" else ""}', 'the wildcard end is lost (R-UP5)'),
 ('A4', 'Lags.roc', 'm == "main.roc" or modules.contains(m))', 'm == "main.roc" or modules.contains(m) or m != "")', 'a fail row of a module that the app does not use is a reason (R-UM1)'),
 ('A5', 'Lags.roc', 'if found.any(|f| f.path == hit.path and f.key == mv.alias) {', 'if found.any(|f| f.path == hit.path and f.key == mv.alias and f.version == "-") {', '2 members under one file give 2 pairs for one key (R-SP25)'),
 ('A6', 'InstallPlan.roc', 'Update => latest(u.alias)', 'Update => latest(u.alias) and Bool.False', 'update X@latest does not rewrite the range (R-UP11)'),
 ('A7', 'InstallPlan.roc', 'if request.command == Upgrade and ResolveBase.new_series(s, c) edits', 'if request.command == Upgrade and !ResolveBase.new_series(s, c) edits', 'the suffix new series is on the wrong lines (R-UP3)'),
 ('A8', 'PickFlow.roc', 'Upgrade => Lags.of({', 'Upgrade | Update => Lags.of({', 'update reports lags too (R-UP10)'),
 ('A9', 'ResolveBase.roc', 'Err(Unset) => if request.command == Upgrade Highest else', 'Err(Unset) => if request.command == Install Highest else', 'upgrade uses the strategy of talon.toml (Q2)'),
 ('A10', 'InstallWrite.roc', 'Ok(old) => if old == p.value "" else', 'Ok(old) => if old == "-" "" else', 'the toml line has (was ...) also when the value is the same (Q6)'),
]
want = sys.argv[1:] or [m[0] for m in M]
def run_l0():
    out = {}
    for f in FILES:
        r = subprocess.run(['timeout', '300', roc, 'test', '--no-cache', '--jobs=1', f'tests/unit/{f}.roc'], cwd=root, capture_output=True, text=True)
        txt = r.stdout + r.stderr
        out[f] = 'pass' if 'passed' in txt and r.returncode == 0 else ('compile' if 'compiler error' in txt and ' 0 compiler errors' not in txt else 'FAIL')
    return out
def run_l2():
    b = subprocess.run(['timeout', '900', roc, 'build', 'tests/commands/main.roc', '--no-cache', '--opt=dev', '--output=.work/bin/l2m'], cwd=root, capture_output=True, text=True)
    if b.returncode != 0:
        return 'compile'
    r = subprocess.run(['timeout', '600', 'tests/commands/run.sh', 'upgrade/', 'resolve/rs-new-toml'], cwd=root, capture_output=True, text=True, env={**os.environ, 'L2BIN': os.path.join(root, '.work/bin/l2m')})
    fails = [l.split()[1] for l in r.stdout.splitlines() if l.startswith('FAIL')]
    return 'pass' if 'commands: 4 passed' in r.stdout else 'FAIL ' + ','.join(fails)
for mid, name, old, new, what in M:
    if mid not in want:
        continue
    path = os.path.join(root, 'cli/lib', name)
    src = open(os.path.join(final, name)).read()
    if src.count(old) != 1:
        print(mid, 'NO MATCH', src.count(old)); continue
    open(path, 'w').write(src.replace(old, new))
    try:
        l0 = run_l0()
        caught = [k for k, v in l0.items() if v != 'pass']
        l2 = '-'
        if not caught:
            l2 = run_l2()
        print(f'{mid}\t{what}\tl0 caught by: {",".join(caught) or "none"} {l0}\tl2: {l2}', flush=True)
    finally:
        shutil.copy(os.path.join(final, name), path)
