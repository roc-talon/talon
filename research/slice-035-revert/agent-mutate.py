#!/usr/bin/env python3
"""Revert check of slice 035, code agent. A few small changes of the tricky behaviors, one at a time, over the final code (code-final/).
Each change: restore all files, apply, `roc check`, the L0 files conflicts and solver (timeout 25 s each: a search that does not end is a catch),
and the L1 target (build --fuzz, 8000 runs, seed 1) only when L0 does not catch it. At the end the final code is copied back and compared with code-final.sha256.
Usage: agent-mutate.py [id ...]. Output goes to stdout (redirect it)."""
import os, re, shutil, subprocess, sys, time
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REV = os.path.join(ROOT, "research/slice-035-revert")
FILES = ["packages/resolve/Solver.roc", "packages/resolve/Search.roc", "packages/resolve/main.roc", "packages/resolve/Domain.roc"]
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
SCR = "/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/l1m"
ENV = dict(os.environ, ROC=ROC)

# (id, what, module, old text (once in the file), new text)
M = [
    ("m01", "conflict resolution: the back-jump goes to the level of the satisfier, not below it", "Search", "Learned({ rows, back: prev })", "Learned({ rows, back: e.level })"),
    ("m02", "conflict resolution: it never resolves, it learns the conflict row itself (the search does not end)", "Search", "if prev < e.level {", "if prev < e.level or prev >= 0 {"),
    ("m03", "conflict resolution: the union term of a resolvent uses `and` (an unsound resolvent)", "Search", "t.set.contains(x) or s.set.contains(x)", "t.set.contains(x) and s.set.contains(x)"),
    ("m04", "conflict resolution: the previous satisfier of the term itself is not read", "Search", "prev = U64.max(others_level, prior_level(trail, init, top_at, top, s))", "prev = others_level"),
    ("m05", "unit propagation: a false lit does not stop a row", "Search", "if classes.any(|(_, c)| c == Contra) {", "if classes.any(|(l, c)| c == Contra and l.v > 999) {"),
    ("m06", "R-EP8: B better than A gives `Done` with B (no second pass)", "Solver", "[] => if ta == tb Done(chosen(vars, tb)) else finish(tb)", "[] => Done(chosen(vars, tb))"),
    ("m07", "R-EP8: the `Fail` and the B search read the inferred checks (an inferred fact decides alone)", "Solver", "incs = table(Real)", "incs = table(All)"),
    ("m08", "R-EP9: `Off` reads real facts only", "Solver", "incs = table(All)\n\t\t\t\tmatch solve(vars, incs) {\n\t\t\t\t\tNoTuple(f) => Fail(why_of(vars, incs, f.rows, f.last))\n\t\t\t\t\tFound(t) => finish(t)", "incs = table(Real)\n\t\t\t\tmatch solve(vars, incs) {\n\t\t\t\t\tNoTuple(f) => Fail(why_of(vars, incs, f.rows, f.last))\n\t\t\t\t\tFound(t) => finish(t)"),
    ("m09", "R-EP9: `Off` asks for probes", "Solver", "if compat.probes == Allowed dedupe(", "if compat.probes == Allowed or compat.probes == Off dedupe("),
    ("m10", "Why: `Derived` names the first step twice", "Solver", "Derived(a, b) => Derived(at(a), at(b))", "Derived(a, b) => Derived(at(a), at(a + b - b))"),
    ("m11", "R-EP7: a run does not end at a pass (a pass is a touch)", "Solver", "if c.outcome == Fail and (env.mode == All or is_real)", "if (c.outcome == Fail or c.outcome == Pass) and (env.mode == All or is_real)"),
]

def sh(cmd, timeout):
    try:
        return subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None

def restore():
    for f in FILES:
        shutil.copyfile(os.path.join(REV, "code-final", f), os.path.join(ROOT, f))

_m = re.search(r"^# l1-runs: ([0-9]+)$", open(os.path.join(ROOT, "tests/fuzz/pubgrub.roc")).read(), re.M)
RUNS = os.environ.get("L1_RUNS") or (_m.group(1) if _m else "20000")

def l1():
    shutil.rmtree(SCR, ignore_errors=True)
    os.makedirs(SCR)
    b = sh([ROC, "build", "--fuzz", "--opt=speed", "tests/fuzz/pubgrub.roc", "--output=" + SCR + "/t"], 300)
    if b is None or b.returncode != 0:
        return "BUILD FAILED"
    try:
        r = subprocess.run([SCR + "/t", "run", "--runs=" + RUNS, "--seed=1", "--artifact-dir=" + SCR + "/art"], cwd=SCR, capture_output=True, text=True, timeout=200)
    except subprocess.TimeoutExpired:
        return "caught (timeout)"
    if r.returncode == 0:
        return "MISSED"
    lines = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("[roc crashed]")]
    return "caught: " + (lines[0][:150] if lines else "exit %d" % r.returncode)

def main():
    want = set(sys.argv[1:])
    try:
        for mid, what, name, old, new in M:
            if want and mid not in want:
                continue
            restore()
            path = os.path.join(ROOT, "packages/resolve/%s.roc" % name)
            text = open(path).read()
            if text.count(old) != 1:
                print(mid, "BAD TEXT: %d matches" % text.count(old), flush=True)
                continue
            t0 = time.time()
            open(path, "w").write(text.replace(old, new))
            chk = sh([ROC, "check", "packages/resolve/main.roc"], 120)
            if chk is None or chk.returncode != 0:
                print(mid, what, "DOES NOT COMPILE", ((chk.stdout + chk.stderr)[:500] if chk else "timeout"), flush=True)
                continue
            res = []
            for f in ("conflicts", "solver"):
                t = sh([ROC, "test", "packages/resolve/tests/%s.roc" % f, "--no-cache"], 25)
                if t is None:
                    res.append(f + ":timeout")
                elif t.returncode != 0:
                    labels = [l for l in (t.stdout + t.stderr).splitlines() if l.startswith("[dbg] [\"")]
                    res.append(f + ":caught" + (" " + labels[0][:100] if labels else ""))
                else:
                    res.append(f + ":pass")
            caught = any("caught" in r or "timeout" in r for r in res)
            line = "%s %s | L0 %s" % (mid, what, "; ".join(res))
            if not caught:
                line += " | L1 " + l1()
            print(line, "(%.0f s)" % (time.time() - t0), flush=True)
    finally:
        restore()
        r = subprocess.run("sha256sum -c research/slice-035-revert/code-final.sha256", shell=True, cwd=ROOT, capture_output=True, text=True)
        print("final code restored:", r.returncode == 0, r.stdout.replace("\n", " "), flush=True)

main()
