# Slice 036b revert check (about 10 mutations of the reference, not a full sweep). Run: python3 -I research/slice-036b-revert/mutate.py [name ...]
# Each mutation changes one file in cli/lib, runs the L0 file oracleprobe.roc and all L2 cases, then copies the reference back.
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ref = os.path.join(root, 'research/slice-036b-revert/reference/cli/lib')
env = dict(os.environ)
roc = '/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc'
M = [
 ('no-assumed-pass', 'Oracle.roc', 'assumed = input.slots.join_map(current_of).keep_if(|url| !real.any(|c| c.id == url)).map(', 'assumed = input.slots.join_map(current_of).keep_if(|url| !real.any(|c| c.id == url) and Bool.False).map('),
 ('off-still-probes', 'PickLoop.roc', 'if !rows.is_empty() or setup.probes == Off or unknown.is_empty() {', 'if !rows.is_empty() or unknown.is_empty() {'),
 ('budget-not-counted', 'PickLoop.roc', 'started: known.count, fixed: 0', 'started: 0, fixed: 0'),
 ('no-rekey', 'PickLoop.roc', 'moved = rekey(known, old, started.id)', 'moved = rekey(known, old, old)'),
 ('blame-whole-tuple', 'InstallFlow.roc', 'tried: run.tried.append(dropped(picked.chosen, again.blamed)),', 'tried: run.tried.append(dropped(picked.chosen, [])),'),
 ('last-failure-not-first', 'InstallFlow.roc', 'if fail.kind == NoTuple return Err(first) else return Err(fail)', 'if fail.kind == Usage return Err(first) else return Err(fail)'),
 ('ladder-reprobes-loop', 'Ladder.roc', '.keep_if(|key| !loop.looked.contains(key))', '.keep_if(|key| loop.looked.contains(key) or Bool.True)'),
 ('module-fail-touches', 'Oracle.roc', 'outcome: f.outcome, modules: f.modules, source: Real }', 'outcome: f.outcome, modules: [], source: Real }'),
 ('count-not-carried', 'InstallFlow.roc', 'probed: { ..picked.probed, count: again.probes } }', 'probed: picked.probed }'),
 ('second-search-restarts', 'PickFlow.roc', 'paths: stuck.paths, probed: stuck.probed }) {', 'paths: stuck.paths, probed: run.from.probed }) {'),
 ('verify-probes-in-loop', 'VerifyFlow.roc', 'snapshot, Err(NoCompiler))?', 'snapshot, start.decision.held)?'),
]
want = sys.argv[1:]
def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, cwd=root, capture_output=True, text=True, **kw)
for name, f, old, new in M:
    if want and name not in want:
        continue
    path = os.path.join(root, 'cli/lib', f)
    text = open(ref + '/' + f).read()
    if text.count(old) != 1:
        print(name, 'NO MATCH', text.count(old)); continue
    open(path, 'w').write(text.replace(old, new))
    try:
        l0 = sh(f'. scripts/env.sh && $ROC test tests/unit/oracleprobe.roc 2>&1 | tail -4')
        l0_out = l0.stdout
        l0_kill = 'failed' in l0_out and '0 failed' not in l0_out or 'Compilation failed' in l0_out or 'error' in l0_out.lower()
        l2 = sh('. scripts/env.sh && tests/commands/run.sh 2>&1')
        fails = [l[5:] for l in l2.stdout.splitlines() if l.startswith('FAIL ')]
        build = 'build of the L2 app failed' in l2.stdout
        print(f'{name}: L0 {"KILLED" if l0_kill else "alive"}; L2 {"BUILD FAILED" if build else str(len(fails)) + " fail"}: {", ".join(fails[:8])}', flush=True)
    finally:
        shutil.copy(ref + '/' + f, path)
