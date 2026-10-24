#!/usr/bin/env python3
"""Gap tests of slice 033 (test agent, 2026-10-23): the mutations e16, e34 and e35 of agent-mutate.py, applied by hand to the final code.
For each: compile check, the L0 file (must fail), the l1 step (result shown). The file is copied back from code-final/ (never deleted)."""
import os, subprocess, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(ROOT)
E = 'cli/lib/Epochs.roc'
FINAL = 'research/slice-033-revert/code-final/cli/lib/Epochs.roc'
ROC = os.environ.get('ROC', ROOT + '/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc')
M = [
 ('e16', '(Ok(x), Ok(y)) if x == y => [b, a]', '(Ok(_), Ok(_)) => [b, a]'),
 ('e34', '\t_ => Err(NotInD)\n}', '\t(Ok(lo), Err(_)) => Ok((lo, 99))\n\t_ => Err(NotInD)\n}'),
 ('e35', '\t_ => Err(NotInD)\n}', '\t(Err(_), Ok(hi)) => Ok((0, hi))\n\t_ => Err(NotInD)\n}'),
]
ref = open(FINAL).read()
try:
    for mid, old, new in M:
        assert ref.count(old) == 1, mid
        open(E, 'w').write(ref.replace(old, new))
        chk = subprocess.run([ROC, 'check', 'cli/lib/main.roc'], capture_output=True, text=True)
        l0 = subprocess.run([ROC, 'test', 'tests/unit/epochs.roc', '--no-cache'], capture_output=True, text=True)
        l1 = subprocess.run(['scripts/test.sh', 'l1'], capture_output=True, text=True)
        print(f"{mid}: compile rc={chk.returncode} L0={'caught' if l0.returncode else 'MISSED'} L1={'caught' if l1.returncode else 'MISSED'}", flush=True)
finally:
    shutil.copyfile(FINAL, E)
print('restored:', open(E).read() == ref)
