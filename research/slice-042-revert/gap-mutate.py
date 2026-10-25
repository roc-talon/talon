#!/usr/bin/env python3
"""Gap mutations of slice 042 (hand mutations of the code of the code agent, filtered runs only). Run from the repo root. The file is put back after each one."""
import os, subprocess, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
M = [
    ("G1", "Diff.roc", "		if fits(lines, old, $p) {\n			d = ", "		if fits(lines, old, $p) and $p.to_i64_wrap() >= spot.wanted {\n			d = ", ["l0:diff"], "Q2: a fit before the wanted line is ignored"),
    ("G2", "Diff.roc", "			if !$found or d < $dist {", "			if !$found or (d < $dist and d > 100000) {", ["l0:diff"], "Q2: the first fit wins, not the nearest"),
    ("G3", "Intent.roc", "		Value.Table(t) => match (t.get(\"path\"), t.get(\"base\")) {", "		Value.Table(t) if !doc.to_str().contains(\"[patch.\") => match (t.get(\"path\"), t.get(\"base\")) {", ["l0:intent"], "D10: the table form [patch.json] is not read"),
    ("G4", "PatchFlow.roc", "			Err(_) => return Err(Fail.new(Environment, \"cannot read ${a.path}\"))", "			Err(_) => return Err(Fail.new(Usage, \"cannot read ${a.path}\"))", ["l2:patch/pa1-flow"], "Q7: a missing base dir is not an Environment failure"),
]
def run(t):
    k, _, a = t.partition(":")
    cmd = [ROC, "test", f"tests/unit/{a}.roc", "--no-cache"] if k == "l0" else ["tests/commands/run.sh", a]
    r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=600)
    return r.returncode != 0
want = set(sys.argv[1:])
for mid, f, old, new, tests, what in M:
    if want and mid not in want: continue
    path = os.path.join(ROOT, "cli/lib", f); orig = open(path).read()
    if orig.count(old) != 1: print(mid, "BAD EDIT", orig.count(old)); continue
    open(path, "w").write(orig.replace(old, new))
    try:
        c = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
        if c.returncode != 0: print(mid, "DID NOT COMPILE", c.stdout[:300].replace("\n", " ")); continue
        by = next((t for t in tests if run(t)), None)
        print(f"{mid}: {'CAUGHT by ' + by if by else 'NOT CAUGHT'} ({what})", flush=True)
    finally:
        open(path, "w").write(orig)
