# Slice 036c: filtered revert check of the private reference. Each mutation changes one line of cli/lib/<file> (the reference is in the tree),
# runs the L0 files of the slice (and the case probe/dm1-domain when asked), and puts the file back from reference/.
# Run: python3 -I research/slice-036c-revert/mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ref = os.path.join(root, 'research/slice-036c-revert/reference')
roc = os.environ.get('ROC') or os.path.join(root, 'cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
FILES = ['explain', 'oracledomain', 'oracleprobe']
M = [
 ('M1', 'Oracle.roc', 'assume and n == held and now.contains(url)', 'assume and now.contains(url)', 'D2 revisit: the assumed pass on every compiler of D'),
 ('M2', 'Oracle.roc', 'Err(None) => if assumed {', 'Err(None) => if assumed and compat.inferred.is_empty() {', 'an inferred fact replaces the assumed pass'),
 ('M3', 'Oracle.roc', 'domain.keep_if(|n| n != held and compat.checks.any(|f| f.nightly == n)).find_first(', 'domain.keep_if(|n| n != held and compat.checks.any(|f| f.nightly == n)).rev().find_first(', 'the hint is the newest nightly, not the oldest'),
 ('M4', 'Oracle.roc', 'compiler: Ok(n), probes: Allowed, inferred: [], conflicts: [] }', 'compiler: Ok(n), probes: Allowed, inferred: compat.inferred, conflicts: [] }', 'the hint reads inferred facts'),
 ('M5', 'Oracle.roc', 'if needs_wide(compat) and has_probe(why) Wide', 'if needs_wide(compat) Wide', 'Wide for a failure with no probe cause'),
 ('M6', 'Oracle.roc', 'fetch_first(input, pairs_of(input, asks))\n\t}\n\tDone', 'if needs_wide(compat) Wide else fetch_first(input, pairs_of(input, asks))\n\t}\n\tDone', 'Wide for a Pairs of Allowed'),
 ('M7', 'Oracle.roc', 'pairs => if needs_wide(compat) Wide else Pairs(pairs)', 'pairs => Pairs(pairs)', 'Off does not ask for D before a lookup round'),
 ('M8', 'Oracle.roc', 'Ok(domain) => if domain.contains(held) domain else [held]', 'Ok(domain) => domain', 'H not in D is not degraded to [H]'),
 ('M10', 'Explain.roc', 'c.from != c.to or !c.inferred.is_empty()', 'c.from != c.to', 'no cause line for an inferred fail on H alone'),
 ('M14', 'Oracle.roc', 'added = ids.keep_if(|id| Ident.of_url(id).is_ok() and', 'added = ids.keep_if(|id| Ident.of_url(id).is_err() and', 'the hint does not accept a header that was not read'),
 ('M13', 'PickLoop.roc', 'keys = domain_keys(input, ids).keep_if(|key| !probed.looked.contains(key))', 'keys = domain_keys(input, ids)', 'wide! asks the db again for the keys that were looked up'),
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
    subprocess.run([roc, 'build', 'tests/commands/main.roc', '--opt=dev', '--output=.work/bin/l2m'], cwd=root, capture_output=True, text=True, timeout=400)
    r = subprocess.run(['tests/commands/run.sh', 'probe/dm1-domain'], cwd=root, capture_output=True, text=True, timeout=300, env={**os.environ, 'L2BIN': os.path.join(root, '.work/bin/l2m')})
    return 'pass' if 'commands: 1 passed' in r.stdout else 'FAIL'
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
        print(f'{mid}\t{what}\tl0 caught by: {",".join(caught) or "none"}\tl2 dm1: {l2}', flush=True)
    finally:
        shutil.copy(os.path.join(ref, name), path)
