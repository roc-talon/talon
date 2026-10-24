# Slice 037c: filtered revert check of the private reference (TW12, the user rule of 2026-10-23: about 5 to 10 mutations, no full sweep).
# Each mutation changes one place of cli/lib/<file> (the reference is in the tree), runs the L0 files of the slice, then the L2 cases probe/pd1-downloads and probe/pc2-range
# when L0 did not catch it, and puts the file back from reference/.   Run: python3 -I research/slice-037c-revert/mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ref = os.path.join(root, 'research/slice-037c-revert/reference/cli/lib')
roc = os.environ.get('ROC') or os.path.join(root, 'cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
FILES = ['consent', 'probecmd']
M = [
 ('M1', 'ProbeCmd.roc', 'flag: request.downloads.probe,', 'flag: request.downloads.allow,', '--allow-downloads is the opt-in of the optional downloads (R-DL5: it answers a required download only)'),
 ('M2', 'ProbeSearch.roc', ['Consent.optional_round({ ids: wanted,', 'if wanted.is_empty() {'], ['Consent.optional_round({ ids: ids,', 'if ids.is_empty() {'], 'the download is planned before the budget: a download with no room for its probe (R-P5)'),
 ('M3', 'ProbeSearch.roc', 'left = if run.probe.max_toolchains > state.tried run.probe.max_toolchains - state.tried else 0', 'left = run.probe.max_toolchains + state.tried - state.tried', 'the cap does not count the tries of earlier rounds (R-DL6)'),
 ('M4', 'ProbeSearch.roc', 'removed: state.removed.concat(plan.dropped).concat(got.failed)', 'removed: state.removed.concat(plan.dropped)', 'a release whose download failed is asked again (R-P3)'),
 ('M5', 'ProbeSearch.roc', 'askable = allowed.keep_if(|id| run.installed.contains(id))', 'askable = allowed.keep_if(|id| run.installed.contains(id) or run.yes)', 'phase 1 asks a release that is not installed when --yes is set: no installed-first order (R-P5)'),
 ('M6', 'Consent.roc', '} else if run.yes or flag_is_yes(run.flag) {', '} else if flag_is_yes(run.flag) {', '--yes is not an opt-in (R-NM8, R-NI4)'),
 ('M7', 'Consent.roc', 'if run.count == 0 {', 'if run.count == 7 {', 'a count of 0 is offered (R-DL6)'),
 ('M8', 'Consent.roc', 'dropped: missing.drop_first(run.left),', 'dropped: [],', 'the ids that the cap drops are not listed (R-DL6)'),
 ('M9', 'ProbeSearch.roc', 'if run.probe.max_toolchains > 0 and !state.capped.is_empty() {', 'if !state.capped.is_empty() {', 'the note of the cap shows with a cap of 0 (R-DL6: nothing is offered)'),
 ('M10', 'ProbeSearch.roc', 'downloads: state.downloads + got.installed.len(),', 'downloads: state.downloads,', 'data.downloads does not count the downloads'),
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
    return 'pass' if 'commands: 2 passed' in r.stdout else 'FAIL'
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
        l0 = run_l0()
        caught = [k for k, v in l0.items() if v != 'pass']
        l2 = '-'
        if not caught or any(v == 'compile' for v in l0.values()):
            l2 = run_l2()
        print(mid, 'l0:', l0, 'l2:', l2, '|', what, flush=True)
    finally:
        shutil.copy(os.path.join(ref, name), path)
