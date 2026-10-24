#!/usr/bin/env python3
# Slice 032, gap rows of the test agent: apply one mutation of agent-mutate.py, run only the test that must see it, restore the file from code-final/ and cmp.
# Usage: gap-mutate.py [id ...]. One step at a time.
import os, subprocess, shutil, filecmp, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
FINAL = 'research/slice-032-revert/code-final/'
L = 'cli/lib/'
G = [
 ('b18', L+'BuildSkip.roc', 'counts.skipped >= counts.apps Skipped', 'counts.skipped > 0 Skipped', 'l0 buildskip'),
 ('w1', L+'InstallFlow.roc', 'apps: members.count_if(|m| m.kind == App)', 'apps: members.len()', 'l2 ladder/bs2'),
 ('w3', L+'RemoveFlow.roc', 'skipped: done.skipped', 'skipped: 0', 'l2 ladder/bs2'),
 ('l6', L+'Ladder.roc', 'count: second.count, used: verdict.used, dir: copy', 'count: second.count, used: match verdict.used { Ok(_) => Err(NotScanned), Err(e) => Err(e) }, dir: copy', 'l2 ladder/bs2'),
 ('f8', L+'BuildFlow.roc', 'text: run.output.stderr, dir: run.dir', 'text: "", dir: run.dir', 'l2 ladder/bs3'),
 ('f9', L+'BuildFlow.roc', 'dir: run.dir, pkgs: run.pkgs })\n\t\t\tmatch', 'dir: run.pkgs, pkgs: run.pkgs })\n\t\t\tmatch', 'l2 ladder/bs3'),
 ('n8', 'cli/RealDb.roc', 'DO UPDATE SET outcome = excluded.outcome, modules = excluded.modules"', 'DO UPDATE SET modules = excluded.modules"', 'l3 update/bs2-build-fail-replaced'),
]
def sh(c):
    p = subprocess.run(c, shell=True, capture_output=True, text=True, executable='/bin/bash')
    return p.returncode, p.stdout + p.stderr
want = sys.argv[1:]
for id, path, old, new, step in G:
    if want and id not in want:
        continue
    text = open(path).read()
    if text.count(old) != 1:
        print(id, 'BAD MUTATION', text.count(old)); continue
    open(path, 'w').write(text.replace(old, new))
    try:
        kind, _, arg = step.partition(' ')
        if kind == 'l0':
            rc, log = sh('. scripts/env.sh; $ROC test tests/unit/%s.roc --no-cache' % arg)
            res = 'caught' if rc != 0 and 'failed' in log else ('INVALID' if rc != 0 else 'NOT CAUGHT')
        elif kind == 'l2':
            rc, log = sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2 2>&1 | tail -3; test ${PIPESTATUS[0]} = 0')
            if rc != 0:
                res = 'INVALID (does not compile)'
            else:
                rc, log = sh('. scripts/env.sh; L2BIN=$WORK/bin/l2 tests/commands/run.sh %s' % arg)
                res = 'caught' if rc != 0 else 'NOT CAUGHT'
        else:
            rc, log = sh('. scripts/env.sh; tests/run.sh %s' % arg)
            res = 'caught' if rc != 0 and 'FAIL' in log else ('INVALID' if rc != 0 else 'NOT CAUGHT')
    finally:
        shutil.copyfile(FINAL + path[len('cli/'):] if False else FINAL + path, path)
    same = filecmp.cmp(FINAL + path, path, shallow=False)
    print(id, step, res, 'restored' if same else 'NOT RESTORED', flush=True)
sh('. scripts/env.sh; $ROC build tests/commands/main.roc --opt=dev --output=$WORK/bin/l2')
