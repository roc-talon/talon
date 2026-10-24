#!/usr/bin/env python3
"""Revert check of the code of slice 036b (TW12, filtered runs only, user rule 2026-10-23: about 5 to 10 tricky mutations).

For each mutation: the file is copied from `code-final/`, one small change is made, and only the tests that must see it run:
an L0 file (`roc test`) or the L2 cases with a filter (`tests/commands/run.sh <filter>`). CAUGHT = a test fails, or the run ends by the timeout (a loop).
The file is put back from `code-final/` after each mutation. At the end the files are compared with `code-final.sha256` (run from the repo root).
Usage (repo root): python3 -I research/slice-036b-revert/agent-mutate.py [id ...]
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "research/slice-036b-revert")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
O, PL, IF, LD, LJ, UN = "cli/lib/Oracle.roc", "cli/lib/PickLoop.roc", "cli/lib/InstallFlow.roc", "cli/lib/Ladder.roc", "cli/lib/LadderJudge.roc", "cli/lib/Units.roc"
PROBE = "tests/unit/oracleprobe.roc"

# (id, file, old, new, test, what the change breaks). A test is an L0 file or ("l2", [filter, ...]).
M = [
    ("B1", O, '!compat.looked.any(|k| k.hash == hash_of(url) and k.nightly == nightly and k.target == "any"),', "Bool.True,", PROBE, "R-LF2: `Off` looks up a release again that was looked up"),
    ("B2", O, "slot_name(t.at), ids: [t.id]", "slot_name(0), ids: [t.id]", PROBE, "R-AL5: a conflict of the ladder names the place of its slot"),
    ("B3", PL, "started: probed.count, fixed: 0", "started: 0, fixed: 0", ("l2", ["probe/lp1-loop"]), "R-P5: the budget does not count the probes that ran"),
    ("B4", PL, "rekey({ ..probed, started: Ok(started) }, held, started.id)", "rekey({ ..probed, started: Ok(started) }, held, held)", ("l2", ["probe/pb1-ladder"]), "R-CV1: the facts of the held spelling get no id of the started compiler"),
    ("B5", IF, "tried: picked.probed.tried.append(dropped(picked.chosen, again.blamed))", "tried: picked.probed.tried.append(dropped(picked.chosen, []))", ("l2", ["probe/lp1-loop"]), "R-AL6, Q2: a ladder failure always drops the whole tuple"),
    ("B6", IF, "count: again.probes, tried", "count: picked.probed.count, tried", ("l2", ["probe/lp1-loop"]), "R-P5: the probes of a dropped tuple are not counted"),
    ("B7", IF, "Err(other) => if other.kind == NoTuple Err(first) else Err(other)", "Err(other) => Err(other)", ("l2", ["ladder/bs3-build-record", "ladder/ld-ladder-flow", "probe/un1-units"]), "R-PH13: the final failure is the last, not the first"),
    ("B8", LD, "keep_if(|key| !loop.looked.contains(key))", "keep_if(|key| !loop.looked.contains(key) or Bool.True)", ("l2", ["probe/lp1-loop", "resolve/rs-new-toml", "ladder/ld-ladder-flow"]), "R-AL4: the ladder asks the db again for the keys of the loop"),
    ("B9", LJ, 'whole-app check found new errors in ${blames(in_hashes, owners)}", hashes_of(in_hashes)))', 'whole-app check found new errors in ${blames(in_hashes, owners)}", []))', ("l2", ["probe/lp1-loop"]), "D10: a new error in a hash blames the whole tuple"),
    ("B10", UN, "rows.map(|(hash, _)| hash)))", "[]))", ("l2", ["probe/un1-units", "ladder/ld-ladder-flow", "ladder/bs3-build-record", "probe/lp1-loop"]), "D10: a unit fail of the ladder blames the whole tuple"),
]


def sh(*a, **k):
    return subprocess.run(a, cwd=ROOT, capture_output=True, text=True, **k)


def run(test):
    try:
        if isinstance(test, tuple):
            r = sh("tests/commands/run.sh", *test[1], timeout=900)
        else:
            r = sh(ROC, "test", test, "--no-cache", timeout=120)
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
    print(sh("sha256sum", "-c", "research/slice-036b-revert/code-final.sha256").stdout.strip())


main()
