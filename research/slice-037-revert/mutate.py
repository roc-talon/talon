# Slice 037: filtered revert check of the private reference. Each mutation changes one place of cli/lib/<file> (the reference is in the tree),
# runs the L0 files of the slice, then the L2 cases probe/pc1-targets and probe/pc2-range when L0 did not catch it, and puts the file back from reference/.
# Run: python3 -I research/slice-037-revert/mutate.py [id ...]
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ref = os.path.join(root, 'research/slice-037-revert/reference/cli/lib')
roc = os.environ.get('ROC') or os.path.join(root, 'cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
FILES = ['proberange', 'probecmd']
M = [
 ('M1', 'ProbeRange.roc', 'if oldest_first places else places.rev()', 'if oldest_first places else places', 'the first round asks the oldest releases, not the newest (R-PB3 "starts at the newest")'),
 ('M2', 'ProbeRange.roc', '[m // 4, m // 2, 3 * m // 4]', '[0, m // 2, m - 1]', 'the picks of a round are not the quartile places (R-PP2)'),
 ('M3', 'ProbeRange.roc', 'real: q == 0 or real_fail_at(q - 1) }', 'real: Bool.True }', 'the lower end is always real (R-PB4)'),
 ('M4', 'ProbeRange.roc', 'f.hash == input.hash and f.target == "any" and', 'f.target == "any" and', 'a row of another hash is read'),
 ('M5', 'ProbeRange.roc', 'f.hash == input.hash and f.target == "any" and', 'f.hash == input.hash and', 'a row of another target is read (R-LD2)'),
 ('M6', 'ProbeRange.roc', '''has_fact = |cell| match cell {
	RealPass => Bool.True
	RealFail => Bool.True
	Fault => Bool.True''', '''has_fact = |cell| match cell {
	RealPass => Bool.True
	RealFail => Bool.True
	Fault => Bool.False''', 'a hang or a crash is asked again (R-EP5)'),
 ('M7', 'ProbeRange.roc', 'let_real_fail', None, ''),
 ('M8', 'ProbeCmd.roc', 'else if unknown == 1 {', 'else if unknown == 7 {', 'one unknown end gives no exit 12 (R-PB4)'),
 ('M9', 'ProbeCmd.roc', 'if listing.any(|e| e.is_dir and e.name == hash) {', 'if listing.any(|e| e.is_dir and e.name == "x") {', 'a bundle is unbundled again when its dir is there (R-FE3)'),
 ('M10', 'ProbeCmd.roc', 'var $facts = Facts.load!(fx, { roots: request.roots, keys })?', 'var $facts = Facts.load!(fx, { roots: request.roots, keys })?.keep_if(|_| Bool.False)', 'the range search does not read the known facts (R-AL4)'),
 ('M11', 'ProbeCmd.roc', 'allowed.contains(id) and installed.contains(id)', 'allowed.len() >= 0 and installed.contains(id)', 'nightly = false and min-release-age do not limit the candidates (R-NS3, R-C7)'),
 ('M12', 'ProbeCmd.roc', 'rows: [fact], existing: Replace', 'rows: [fact], existing: Keep', 'a known fact is not replaced by a new probe (R-P4)'),
 ('M13', 'ProbeCmd.roc', 'if passed and kind == App {', 'if (passed or kind == App) and kind == App {', 'the build runs after a failed check'),
 ('M14', 'ProbeCmd.roc', 'if given("--share") {', 'if given("--share-x") {', '--share with direct is not exit 2 (R-PB6)'),
 ('M15', 'ProbeCmd.roc', 'installed.contains(id)', 'Bool.True', 'a compiler that is not installed is asked (no download in 037a, R-NI4)'),
 ('M16', 'ProbeCmd.roc', 'if facts.installed.contains(facts.selected) {', 'if facts.installed.contains("x") {', 'the selected compiler does not unbundle (R-FE4 rule 1)'),
 ('M17', 'ProbeCmd.roc', 'times: [] }) == After id else best', 'times: [] }) == Before id else best', 'the oldest installed compiler unbundles (R-FE4 rule 2)'),
 ('M18', 'ProbeCmd.roc', 'argv: [run.program, "unbundle"', 'argv: ["roc", "unbundle"', 'roc by name unbundles (R-FE4)'),
]
want = sys.argv[1:] or [m[0] for m in M if m[4]]
def run_l0():
    out = {}
    for f in FILES:
        r = subprocess.run([roc, 'test', '--jobs=1', f'tests/unit/{f}.roc'], cwd=root, capture_output=True, text=True, timeout=300)
        txt = r.stdout + r.stderr
        out[f] = 'compile' if ('unused variable' in txt or 'compiler error' in txt and ' 0 compiler errors' not in txt or 'Compilation failed' in txt) else ('pass' if 'passed' in txt and r.returncode == 0 else 'FAIL')
    return out
def run_l2():
    b = subprocess.run([roc, 'build', 'tests/commands/main.roc', '--opt=dev', '--output=.work/bin/l2m'], cwd=root, capture_output=True, text=True, timeout=400)
    if b.returncode != 0:
        return 'compile'
    r = subprocess.run(['tests/commands/run.sh', 'probe/pc1-targets', 'probe/pc2-range'], cwd=root, capture_output=True, text=True, timeout=300, env={**os.environ, 'L2BIN': os.path.join(root, '.work/bin/l2m')})
    return 'pass' if 'commands: 2 passed' in r.stdout else 'FAIL'
for mid, name, old, new, what in M:
    if mid not in want or new is None:
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
        print(f"{mid}\t{what}\tl0: {l0}\tl2: {l2}", flush=True)
    finally:
        shutil.copy(os.path.join(ref, name), path)
