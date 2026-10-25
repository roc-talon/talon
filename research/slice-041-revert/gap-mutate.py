#!/usr/bin/env python3
"""Gap step of slice 041: one hand mutation for each gap row. The file is put back from code-final/ after each run."""
import os, shutil, subprocess
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ENV = dict(os.environ)
F = os.path.join(ROOT, "cli/lib/Init.roc")
GOOD = os.path.join(ROOT, "research/slice-041-revert/code-final/cli/lib/Init.roc")
M = [
    ("G1", 'Err(NoRelease) => Err(Fail.new(Usage, "no release of', 'Err(NoRelease) => Err(Fail.new(Network, "no release of', "no release old enough: kind and text"),
    ("G2", 'Cached(t) => fx.err!("${Github.offline_line(t)}\\n")', 'Cached(_) => {}', "the offline line of init is not printed (0 lines)"),
]
for mid, old, new, what in M:
    text = open(GOOD).read()
    assert text.count(old) == 1, mid
    open(F, "w").write(text.replace(old, new))
    try:
        r = subprocess.run(["tests/commands/run.sh", "init/it1-app"], cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=600)
        print(f"{mid}: {'CAUGHT' if r.returncode else 'NOT CAUGHT'} ({what})", flush=True)
    finally:
        shutil.copy(GOOD, F)
