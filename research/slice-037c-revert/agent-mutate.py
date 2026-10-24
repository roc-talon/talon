# Slice 037c, code agent: filtered revert check (TW12, user rule of 2026-10-23: about 5 to 10 mutations, no full sweep).
# Each mutation changes one place of cli/lib/<file> (the final code is in code-final/), runs the L0 files of the slice (only for a file that the unit tests import),
# then the L2 cases probe/pd1-downloads and probe/pc2-range when L0 did not catch it, and puts the file back from code-final/.
# Run: python3 -I research/slice-037c-revert/agent-mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ref = os.path.join(root, 'research/slice-037c-revert/code-final/cli/lib')
roc = os.environ.get('ROC') or os.path.join(root, 'cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
FILES = ['consent', 'probecmd']
M = [
 ('A1', 'ProbeCmd.roc', 'flag: request.downloads.probe,', 'flag: request.downloads.allow,', '--allow-downloads is the opt-in of the optional downloads (R-DL5)'),
 ('A2', 'ProbeSearch.roc', 'askable = allowed.keep_if(|id| run.installed.contains(id))', 'askable = allowed.keep_if(|id| run.installed.contains(id) or run.yes)', 'phase 1 asks a release that is not installed when --yes is set (R-P5 installed first)'),
 ('A3', 'ProbeSearch.roc', 'left: run.probe.max_toolchains - state.tried,', 'left: run.probe.max_toolchains,', 'the cap does not count the tries of earlier rounds (R-DL6)'),
 ('A4', 'ProbeSearch.roc', 'removed: step.state.removed.concat(step.got.failed).concat(step.plan.dropped),', 'removed: step.state.removed.concat(step.plan.dropped),', 'a release whose download failed is asked again (R-P3)'),
 ('A5', 'ProbeSearch.roc', ['Consent.optional_round({ ids: wanted,', 'if wanted.is_empty() {'], ['Consent.optional_round({ ids: ids,', 'if ids.is_empty() {'], 'the download is planned before the budget (R-P5)'),
 ('A6', 'ProbeSearch.roc', 'failed: $got.failed.append(item.id), tried: $got.tried + 1 }', 'failed: $got.failed.append(item.id) }', 'a failed try does not count for the cap (Q3, R-DL6)'),
 ('A7', 'ProbeSearch.roc', 'if run.probe.max_toolchains > 0 and last.dropped > 0 {', 'if last.dropped > 0 {', 'the cap note shows with a cap of 0 (R-DL6)'),
 ('A8', 'ProbeSearch.roc', 'tried: $got.tried + 1, downloads: $got.downloads + 1 }', 'tried: $got.tried + 1, downloads: $got.downloads }', 'data.downloads does not count (R-J3)'),
 ('A9', 'ProbeSearch.roc', 'Nothing => Ok({ ..state, dropped: state.dropped + plan.dropped.len() })', 'Nothing => Ok(state)', 'the ids that the cap drops in the last round are not counted (cap note)'),
 ('A10', 'ProbeSearch.roc', 'if room.cut Ok(next) else more!(fx, run, world, wide, next)', 'more!(fx, run, world, wide, next)', 'a round cut by the budget is followed by another round (R-P5)'),
 ('A11', 'Consent.roc', 'fetch_ids = missing.take_first(run.left)', 'fetch_ids = missing.take_first(run.left + 1)', 'the cap allows one more download than it says (R-DL6)'),
]
want = sys.argv[1:] or [m[0] for m in M]
def run_l0():
    out = {}
    for f in FILES:
        r = subprocess.run([roc, 'test', '--jobs=1', f'tests/unit/{f}.roc'], cwd=root, capture_output=True, text=True, timeout=300)
        txt = r.stdout + r.stderr
        out[f] = 'compile' if ('unused variable' in txt or 'Compilation failed' in txt or 'compiler error' in txt and ' 0 compiler errors' not in txt) else ('pass' if 'passed' in txt and r.returncode == 0 else 'FAIL')
    return out
def run_l2():
    b = subprocess.run([roc, 'build', 'tests/commands/main.roc', '--opt=dev', '--output=.work/bin/l2m'], cwd=root, capture_output=True, text=True, timeout=400)
    if b.returncode != 0:
        return 'compile'
    r = subprocess.run(['tests/commands/run.sh', 'probe/pd1-downloads', 'probe/pc2-range'], cwd=root, capture_output=True, text=True, timeout=300, env={**os.environ, 'L2BIN': os.path.join(root, '.work/bin/l2m')})
    return 'pass' if 'commands: 2 passed' in r.stdout else 'FAIL ' + ' '.join(l for l in r.stdout.splitlines() if 'FAIL' in l or 'fail' in l)[:200]
for mid, name, old, new, what in M:
    if mid not in want:
        continue
    path = os.path.join(root, 'cli/lib', name)
    src = open(os.path.join(ref, name)).read()
    olds, news = (old, new) if isinstance(old, list) else ([old], [new])
    if any(src.count(o) != 1 for o in olds):
        print(mid, 'NO MATCH', [src.count(o) for o in olds]); continue
    for o, n in zip(olds, news):
        src = src.replace(o, n)
    open(path, 'w').write(src)
    try:
        l0 = run_l0() if name != 'ProbeSearch.roc' else {}
        caught = [k for k, v in l0.items() if v != 'pass']
        l2 = '-'
        if not caught or any(v == 'compile' for v in l0.values()):
            l2 = run_l2()
        print(mid, 'l0:', l0, 'l2:', l2, '|', what, flush=True)
    finally:
        shutil.copy(os.path.join(ref, name), path)
