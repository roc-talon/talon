# Slice 036b2 revert check: 9 mutations of the private reference (research/slice-036b2-revert/reference/), one at a time.
# Each runs the L0 file oracleprobe and L2 (all cases, 1.4 s after the build). The file is put back after each run.
# Run from the repo root: python3 -I research/slice-036b2-revert/mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.getcwd()
ref = 'research/slice-036b2-revert/reference/cli/lib/'
env = dict(os.environ)
muts = [
 ('M1', 'Oracle', 'Ok(f) => f.outcome == Fail and !f.modules.is_empty()', 'Ok(f) => f.outcome == Pass and !f.modules.is_empty()', 'no scan is ever asked for'),
 ('M2', 'InstallFlow', 'probed = { ..picked.probed, count: again.probes,', 'probed = { ..picked.probed, used: [], count: again.probes,', 'the scan results are lost when the ladder drops a tuple'),
 ('M3', 'Oracle', '{ id: url, modules: scanned.append("main.roc") }', '{ id: url, modules: scanned }', 'main.roc is not used by every release'),
 ('M4', 'Oracle', 'and !f.modules.is_empty() and !f.modules.contains("main.roc")', 'and !f.modules.contains("main.roc")', 'a hard fail (no module) is scanned'),
 ('M5', 'Oracle', 'and !f.modules.contains("main.roc") and !compat.used.any', 'and !compat.used.any', 'a fail in main.roc is scanned'),
 ('M6', 'PickLoop', 'alias: slot.id, value: c.url', 'alias: "", value: c.url', 'the entries of the scan have no alias'),
 ('M8', 'InstallFlow', 'for note in pick_notes.keep_if(|n| !seen.contains(n)) {', 'for note in pick_notes.keep_if(|n| !seen.contains("${n}!")) {', 'Q7: a line before the ladder prints again'),
 ('M9', 'PickFlow', 'probed: looped.probed,', 'probed: { ..looped.probed, count: 0 },', 'the count of the second search is not carried to the ladder'),
 ('M11', 'Oracle', 'map_ok(|u| u.modules) ?? []', 'map_ok(|u| u.modules.drop_first(u.modules.len())) ?? []', 'the used modules of the scan are ignored'),
]
want = sys.argv[1:]
out = []
for mid, mod, old, new, what in muts:
    if want and mid not in want:
        continue
    path = os.path.join('cli/lib', mod + '.roc')
    keep = open(path).read()
    assert keep.count(old) == 1, (mid, keep.count(old))
    open(path, 'w').write(keep.replace(old, new))
    try:
        l0 = subprocess.run(['timeout', '150', os.environ['ROC'], 'test', 'tests/unit/oracleprobe.roc'], capture_output=True, text=True)
        l2 = subprocess.run(['timeout', '300', 'scripts/test.sh', 'l2'], capture_output=True, text=True)
        l2fail = [l[5:] for l in l2.stdout.splitlines() if l.startswith('FAIL ')]
        res = 'CAUGHT' if (l0.returncode != 0 or l2.returncode != 0) else 'NOT CAUGHT'
        line = '%s %s: %s | l0 rc=%d | l2 rc=%d %s' % (mid, res, what, l0.returncode, l2.returncode, ','.join(l2fail))
    finally:
        open(path, 'w').write(keep)
    print(line, flush=True)
    out.append(line)
