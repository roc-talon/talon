# Slice 036b2 revert check of the code agent: mutations of cli/lib, one at a time.
# Each run: put back the final code, apply one change, run L0 oracleprobe and L2 (all cases), put back the final code.
# Run from the repo root: python3 -I research/slice-036b2-revert/agent-mutate.py [id ...]
import os, shutil, subprocess, sys
ROC = '/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc'
final = 'research/slice-036b2-revert/code-final/cli/lib/'
muts = [
 ('A1', 'Oracle', 'Ok(f) => f.outcome == Fail and !f.modules.is_empty()', 'Ok(f) => f.outcome == Pass and !f.modules.is_empty()', 'no scan is ever asked for'),
 ('A2', 'InstallFlow', 'probed = { ..picked.probed, count: again.probes,', 'probed = { ..picked.probed, used: [], count: again.probes,', 'the scan results are lost when the ladder drops a tuple'),
 ('A3', 'Oracle', '.append("main.roc") })', ' })', 'main.roc is not used by every release'),
 ('A4', 'PickLoop', 'alias: slot.id, files:', 'alias: "", files:', 'the entries of the scan have no alias'),
 ('A5', 'InstallFlow', 'for note in pick_notes.keep_if(|n| !seen.contains("note: ${n}")) {', 'for note in pick_notes.keep_if(|n| !seen.contains("${n}!")) {', 'Q7: a pick note prints again'),
 ('A6', 'InstallFlow', 'seen: run.seen.concat(pre_lines(request, loaded, picked.facts, picked.chosen)) })', 'seen: [] })', 'Q7: the seen lines are not carried to the next tuple'),
 ('A7', 'PickFlow', 'probed: looped.probed,', 'probed: { ..looped.probed, count: 0 },', 'the count of the second search is not carried to the ladder'),
 ('A8', 'Oracle', 'map_ok(|u| u.modules) ?? []', 'map_ok(|u| u.modules.drop_first(u.modules.len())) ?? []', 'the used modules of the scan are ignored'),
 ('A9', 'PickLoop', 'used.keep_if(|u| u.hash == hash_of(id))', 'used.keep_if(|u| u.hash != "")', 'the modules of all scanned releases go to each id'),
 ('A10', 'Oracle', '.fold([], |found, id| if found.contains(id) found else found.append(id))\n\t\t\t.keep_if(|id| needs_scan', '.keep_if(|id| needs_scan', 'a release in 2 slots is scanned twice (no repeat in ids)'),
]
want = sys.argv[1:]
def put_back():
    for f in os.listdir(final):
        shutil.copyfile(final + f, 'cli/lib/' + f)
for mid, mod, old, new, what in muts:
    if want and mid not in want:
        continue
    put_back()
    path = os.path.join('cli/lib', mod + '.roc')
    keep = open(path).read()
    assert keep.count(old) == 1, (mid, keep.count(old))
    open(path, 'w').write(keep.replace(old, new))
    try:
        l0 = subprocess.run(['timeout', '150', ROC, 'test', 'tests/unit/oracleprobe.roc'], capture_output=True, text=True)
        l2 = subprocess.run(['timeout', '300', 'scripts/test.sh', 'l2'], capture_output=True, text=True)
        l2fail = [l[5:] for l in (l2.stdout + l2.stderr).splitlines() if l.startswith('FAIL ')]
        res = 'CAUGHT' if (l0.returncode != 0 or l2.returncode != 0) else 'NOT CAUGHT'
        line = '%s %s: %s | l0 rc=%d | l2 rc=%d %s' % (mid, res, what, l0.returncode, l2.returncode, ','.join(l2fail))
    finally:
        put_back()
    print(line, flush=True)
