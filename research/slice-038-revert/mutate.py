# Slice 038: filtered revert check of the private reference. The tree must hold the reference (research/slice-038-revert/reference/).
# Each mutation changes one line of cli/lib/<file>, runs the 3 L0 files of the slice, and when none fails, the L2 cases `upgrade/` with a speed build (the object cache of dev builds went bad after each change)
#. The file is put back from reference/ after each run.
# Run: python3 -I research/slice-038-revert/mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ref = os.path.join(root, 'research/slice-038-revert/reference')
roc = os.environ.get('ROC') or os.path.join(root, 'cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
FILES = ['ranges', 'vars', 'upgrade']
M = [
 ('M1', 'Vars.roc', 'free = indexed and (if all !anchor else is_named)', 'free = indexed and (all or is_named)', 'an anchor is free when no name is given (R-UP1)'),
 ('M2', 'Vars.roc', 'if free or movable { group:', 'if movable { group:', 'a free variable keeps its ranges (R-UP1)'),
 ('M3', 'Vars.roc', 'if free or movable { group:', 'if free { group:', 'a movable variable keeps its ranges (R-SP23)'),
 ('M4', 'Ranges.roc', 'else if facts.range.starts_with("=") {', 'else if facts.range.starts_with("==") {', 'an anchor is not rewritten to =<new> (R-UP5)'),
 ('M6', 'Ranges.roc', 'if Ranges.admits({ ranges: [facts.range], version: facts.version }) {', 'if Bool.False {', 'a range that admits the version is rewritten (R-UP5)'),
 ('M7', 'Lags.roc', 'Ok(pair) => if found.any(|p| p.path == pair.path and p.key == pair.key) found else found.append(pair)', 'Ok(pair) => found.append(pair)', 'two members under one file give two pairs for one key (R-SP25)'),
 ('M8', 'Lags.roc', 'Ok(name) => "${name}@${range}"', 'Ok(_) => range', 'the name form loses its name (R-I2)'),
 ('M9', 'Lags.roc', 'Fail => if touches Ok("fails the unit check on ${held}") else Err(No)', 'Fail => Ok("fails the unit check on ${held}")', 'a fail row of a module that the app does not use is a reason (R-UM1)'),
 ('M10', 'Lags.roc', 'if slot.hold != Free {', 'if slot.hold == Held {', 'a movable variable can be a lag (R-SP23)'),
 ('M11', 'InstallFlow.roc', '(request.command == Upgrade or s.variable.uses.any(|u| latest.contains(u.alias)))', '(request.command == Upgrade or s.variable.uses.any(|u| latest.contains(u.alias)) and Bool.False)', 'update X@latest does not rewrite the range (R-UP11)'),
 ('M12', 'InstallFlow.roc', 'if request.command == Upgrade and ResolveBase.new_series(s, c) {', 'if request.command == Upgrade {', 'each move of upgrade ends with new series (R-UP3)'),
 ('M13', 'PickFlow.roc', 'lags = if request.command == Upgrade {', 'lags = if request.command != Install {', 'update reports lags too (R-UP10)'),
 ('M14', 'InstallFlow.roc', 'notes: pick_notes.concat(platform_notes).concat(lag_notes).concat(plan.notes)', 'notes: pick_notes.concat(platform_notes).concat(plan.notes)', 'the lags are not in the notes of --json (R-J3)'),
 ('M16', 'Lags.roc', 'Err(NoForm) => Ok("talon.toml: ${move.alias}: the range does not admit', 'Err(NoForm) => Err(NoNote) # ("talon.toml: ${move.alias}: the range does not admit', 'a key with no form gets no note (Q1 b)'),
 ('M17', 'InstallWrite.roc', 'Ok(old_value) => if old_value == p.value "" else', 'Ok(old_value) => if old_value == old_value "" else', 'the toml line has no (was ...) (Q6)'),
 ('M18', 'ResolveBase.roc', 'Err(Unset) => if request.command == Upgrade Highest else', 'Err(Unset) => if request.command == Install Highest else', 'upgrade uses the strategy of talon.toml (Q2)'),
 ('M19', 'Upgrade.roc', 'match opts.names.find_first(|name| name.contains("@")) {', 'match opts.names.find_first(|name| name.contains("@@")) {', 'upgrade accepts a selector (Q4)'),
 ('M15', 'PickFlow.roc', 'command = if request.command == Upgrade Upgrade else if request.command == Install and', 'command = if request.command == Install and', 'the scope of upgrade is the scope of update (R-SP6)'),
]
want = sys.argv[1:] or [m[0] for m in M]
def run_l0():
    out = {}
    for f in FILES:
        r = subprocess.run([roc, 'test', '--jobs=1', f'tests/unit/{f}.roc'], cwd=root, capture_output=True, text=True, timeout=300)
        txt = r.stdout + r.stderr
        out[f] = 'pass' if 'passed' in txt and r.returncode == 0 else ('compile' if 'compiler error' in txt and ' 0 compiler errors' not in txt else 'FAIL')
    return out
def run_l2():
    subprocess.run('rm -rf .work/cache/roc/compat-*/objects-v7', shell=True, cwd=root)
    b = subprocess.run([roc, 'build', 'tests/commands/main.roc', '--opt=dev', '--output=.work/bin/l2m'], cwd=root, capture_output=True, text=True, timeout=900)
    if b.returncode != 0:
        return 'compile'
    r = subprocess.run(['tests/commands/run.sh', 'upgrade/', 'resolve/rs-new-toml'], cwd=root, capture_output=True, text=True, timeout=600, env={**os.environ, 'L2BIN': os.path.join(root, '.work/bin/l2m')})
    fails = [l.split()[1] for l in r.stdout.splitlines() if l.startswith('FAIL')]
    return 'pass' if 'commands: 4 passed' in r.stdout else 'FAIL ' + ','.join(fails)
for mid, name, old, new, what in M:
    if mid not in want:
        continue
    path = os.path.join(root, 'cli/lib', name)
    src = open(os.path.join(ref, name)).read()
    if src.count(old) != 1:
        print(mid, 'NO MATCH', src.count(old)); continue
    open(path, 'w').write(src.replace(old, new))
    try:
        l0 = run_l0()
        caught = [k for k, v in l0.items() if v != 'pass']
        l2 = '-'
        if not caught:
            l2 = run_l2()
        print(f'{mid}\t{what}\tl0 caught by: {",".join(caught) or "none"}\tl2: {l2}', flush=True)
    finally:
        shutil.copy(os.path.join(ref, name), path)
