#!/usr/bin/env python3
"""Gap check of slice 034 (test agent, 2026-10-23): m27, m49 (the texts of agent-mutate.py) and C3 (a conflict with no terms is ignored).
Each change goes over a copy of code-final/, then the L0 file `solver.roc` must fail. At the end code-final/ is copied back over the package."""
import os, subprocess, shutil
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-034-revert/code-final/packages/resolve")
DST = os.path.join(ROOT, "packages/resolve")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, ROC=ROC)
M = [
    ("m27", "the platform check holds with 2 platform slots (the first)", "(Ok(url), [pl]) =>", "(Ok(url), [pl, ..]) =>"),
    ("m49", "Need names a release twice", "if acc.contains(id) acc else acc.append(id)", "acc.append(id)"),
    ("c3", "a conflict with no terms is ignored", "if joined.any(|l| l.set.is_empty()) Err(Never) else Ok(joined)", "if lits.is_empty() or joined.any(|l| l.set.is_empty()) Err(Never) else Ok(joined)"),
]
def sh(c):
    return subprocess.run(c, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=60)
def restore():
    for f in ("Domain.roc", "Solver.roc"):
        shutil.copyfile(os.path.join(FINAL, f), os.path.join(DST, f))
try:
    for mid, what, old, new in M:
        restore()
        src = open(os.path.join(FINAL, "Solver.roc")).read()
        assert src.count(old) == 1, mid
        open(os.path.join(DST, "Solver.roc"), "w").write(src.replace(old, new))
        chk = sh([ROC, "check", "packages/resolve/main.roc"])
        if chk.returncode != 0:
            print(mid, "DOES NOT COMPILE", chk.stdout[-400:]); continue
        t = sh([ROC, "test", "packages/resolve/tests/solver.roc", "--no-cache"])
        labels = [l for l in (t.stdout + t.stderr).splitlines() if l.startswith("[dbg] [\"")]
        print(mid, what, "L0=" + ("caught" if t.returncode != 0 else "MISSED"), labels[:2], flush=True)
finally:
    restore()
