#!/usr/bin/env python3
"""Revert check of the code of slice 036c (TW12, filtered runs only, user rule 2026-10-23: about 5 to 10 tricky mutations).

For each mutation: the file is copied from `code-final/`, one small change is made, and only the tests that must see it run:
an L0 file (`roc test`) or the L2 case with a filter (`tests/commands/run.sh <filter>`). CAUGHT = a test fails, or the run ends by the timeout.
The file is put back from `code-final/` after each mutation. At the end the files are compared with `code-final.sha256` (run from the repo root).
Usage (repo root): python3 -I research/slice-036c-revert/agent-mutate.py [id ...]
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "research/slice-036c-revert")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
O, OD, PL, EX = "cli/lib/Oracle.roc", "cli/lib/OracleDomain.roc", "cli/lib/PickLoop.roc", "cli/lib/Explain.roc"
DOM, EXP = "tests/unit/oracledomain.roc", "tests/unit/explain.roc"
DM1 = ("l2", ["probe/dm1-domain"])

# (id, file, old, new, test, what the change breaks)
M = [
    ("C1", OD, "(x.assumed.map_ok(|held| held == nightly) ?? Bool.False)", "x.assumed.is_ok()", DOM, "D2 revisit: the assumed pass on every compiler of D"),
    ("C2", OD, "and (x.assumed.map_ok(|held| held == nightly) ?? Bool.False) {", "and (x.assumed.map_ok(|held| held == nightly) ?? Bool.False) and x.inferred.is_empty() {", DOM, "an inferred fact replaces the assumed pass"),
    ("C3", O, "d.keep_if(|n| n != held).find_first(", "d.keep_if(|n| n != held).rev().find_first(", DOM, "the hint is the newest nightly, not the oldest"),
    ("C4", O, "if wants_domain(compat) and has_probe(why) Wide", "if wants_domain(compat) Wide", DOM, "Wide for a failure with no probe cause"),
    ("C5", O, "fetch_first(input, pairs_of(input, asks))\n\t}", "if wants_domain(compat) Wide else fetch_first(input, pairs_of(input, asks))\n\t}", DOM, "Wide for a Pairs of Allowed"),
    ("C6", O, "pairs => if wants_domain(compat) Wide else Pairs(pairs)", "pairs => Pairs(pairs)", DOM, "Off does not ask for D before a lookup round"),
    ("C7", OD, "Ok(d) if d.contains(held) => d", "Ok(d) => d", DOM, "H not in D is not degraded to [H]"),
    ("C8", O, "Need(ids) => rounds > 0 and settled(", "Need(ids) => rounds > 3 and settled(", DOM, "the hint does not accept a header that was not read"),
    ("C9", EX, "found.contains(s) found else found.append(s)", 'found.contains("") found else found.append(s)', EXP, "the option to stop using a module is repeated"),
    ("C10", PL, ".keep_if(|key| !looked.contains(key))", "", DM1, "wide! asks the db again for the keys that were looked up"),
    ("C11", PL, "Ok(releases) if releases.any(|r| r.id == held) => {", "Ok(releases) if !releases.is_empty() => {", DM1, "a list without H is read as D"),
]


def sh(*a, **k):
    return subprocess.run(a, cwd=ROOT, capture_output=True, text=True, **k)


def run(test):
    try:
        if isinstance(test, tuple):
            sh(ROC, "build", "tests/commands/main.roc", "--opt=dev", "--output=.work/bin/l2m", timeout=600)
            r = subprocess.run(["tests/commands/run.sh", *test[1]], cwd=ROOT, capture_output=True, text=True, timeout=900, env={**os.environ, "L2BIN": os.path.join(ROOT, ".work/bin/l2m")})
        else:
            r = sh(ROC, "test", test, "--no-cache", timeout=180)
    except subprocess.TimeoutExpired:
        return True, "timeout"
    out = (r.stdout + r.stderr).strip().splitlines()
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
        print(f"{mid}: {'CAUGHT' if bad else 'NOT CAUGHT'} ({line})  [{why}]", flush=True)
        restore(f)
    print(sh("sha256sum", "-c", "research/slice-036c-revert/code-final.sha256").stdout.strip())


main()
