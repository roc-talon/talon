#!/usr/bin/env python3
"""Revert check of the code of slice 037 (TW12, filtered runs only, user rule 2026-10-23: about 5 to 10 tricky mutations).

For each mutation: the file is copied from `code-final/`, one small change is made, and only the tests that must see it run:
an L0 file (`roc test`) or the L2 cases with a filter (`tests/commands/run.sh <case>`). CAUGHT = a test fails, or the run ends by the timeout.
A change that only gives a compiler error is BAD (it does not test a behavior). The file is put back from `code-final/` after each mutation.
At the end the files are compared with `code-final.sha256` (run from the repo root).
Usage (repo root): python3 -I research/slice-037-revert/agent-mutate.py [id ...]
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "research/slice-037-revert")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
R, C, S, U, B = "cli/lib/ProbeRange.roc", "cli/lib/ProbeCmd.roc", "cli/lib/ProbeSearch.roc", "cli/lib/ProbeUnit.roc", "cli/lib/ProbeBundle.roc"
RANGE, CMD = "tests/unit/proberange.roc", "tests/unit/probecmd.roc"
PC1 = ("l2", ["probe/pc1-targets"])
PC2 = ("l2", ["probe/pc2-range"])

# (id, file, old, new, test, what the change breaks)
M = [
    ("P1", R, "above.rev().take_first(3)", "above.take_first(3)", RANGE, "the first round asks the oldest releases, not the newest (R-PB3)"),
    ("P2", R, "[m / 4, m / 2, 3 * m / 4]", "[0, m / 2, m - 1]", RANGE, "the picks of a round are not the quartile places (R-PP2)"),
    ("P3", R, "Pass | Fail | Fault => Bool.True", "Pass | Fail => Bool.True", RANGE, "a hang or a crash is asked again (R-EP5)"),
    ("P4", C, "match [from, to].count_if(|end| !end.real) {", "match [from, to].count_if(|end| !end.real and !from.real and !to.real) {", CMD, "one unknown end gives no exit 12 (R-PB4)"),
    ("P5", B, "e.is_dir and e.name == run.hash", 'e.is_dir and e.name == "x"', PC1, "a bundle is unbundled again when its dir is there (R-FE3)"),
    ("P6", S, "started: state.probes,", "started: 0,", PC2, "the budget does not count the probes that started (R-P5, R-PP4)"),
    ("P7", S, "askable = allowed.keep_if(|id| run.installed.contains(id))", "askable = allowed", PC2, "a compiler that is not installed is asked (R-NI4)"),
    ("P8", U, "if passed and target.kind == App {", "if (passed or target.kind == App) and target.kind == App {", PC1, "the build runs after a failed check (R-LD5)"),
    ("P9", U, "rows: results.facts, existing: Replace", "rows: results.facts, existing: Keep", PC1, "a known fact is not replaced by a new probe (R-P4)"),
    ("P10", S, 'target: "any" }) })?', 'target: "any" }).keep_if(|_| Bool.False) })?', PC2, "the range search does not read the known facts (R-AL4)"),
]


def sh(*a, **k):
    return subprocess.run(a, cwd=ROOT, capture_output=True, text=True, **k)


def run(test):
    try:
        if isinstance(test, tuple):
            b = sh(ROC, "build", "tests/commands/main.roc", "--opt=dev", "--output=.work/bin/l2m", timeout=600)
            if b.returncode != 0:
                return None, "compile error"
            r = subprocess.run(["tests/commands/run.sh", *test[1]], cwd=ROOT, capture_output=True, text=True, timeout=900, env={**os.environ, "L2BIN": os.path.join(ROOT, ".work/bin/l2m")})
        else:
            r = sh(ROC, "test", test, "--no-cache", timeout=180)
    except subprocess.TimeoutExpired:
        return True, "timeout"
    txt = r.stdout + r.stderr
    out = txt.strip().splitlines()
    if "compiler error" in txt.lower() and "0 compiler errors" not in txt.lower() or "unused variable" in txt:
        return None, "compile error"
    fails = [l for l in out if l.startswith("FAIL ")]
    return r.returncode != 0, (", ".join(fails) or (out[-1] if out else ""))[:160]


def restore(f):
    shutil.copyfile(os.path.join(HERE, "code-final", f), os.path.join(ROOT, f))


def main():
    want = sys.argv[1:]
    for (mid, f, old, new, test, why) in M:
        if want and mid not in want:
            continue
        restore(f)
        text = open(os.path.join(ROOT, f)).read()
        if text.count(old) != 1:
            print(f"{mid}: BAD MUTATION (old text found {text.count(old)} times)")
            continue
        open(os.path.join(ROOT, f), "w").write(text.replace(old, new))
        bad, line = run(test)
        word = "BAD (does not compile)" if bad is None else ("CAUGHT" if bad else "NOT CAUGHT")
        print(f"{mid}: {word} ({line})  [{why}]", flush=True)
        restore(f)
    print(sh("sha256sum", "-c", "research/slice-037-revert/code-final.sha256").stdout.strip())


main()
