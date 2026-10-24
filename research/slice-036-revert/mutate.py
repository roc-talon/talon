#!/usr/bin/env python3
"""Revert check of the tests of slice 036 (TW12, filtered runs, no full sweep).

The reference files are put in the tree, then for each mutation: one small change, a `roc check`-free run of only the tests that should catch it.
CAUGHT = a test fails or runs longer than the timeout. At the end the stubs are put back.
Usage (repo root): python3 -I research/slice-036-revert/mutate.py [id ...]
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME="/tmp/claude-1000/xdg", ROC_CACHE_DIR="/tmp/claude-1000/roccache")
O, S = "cli/lib/Oracle.roc", "packages/resolve/Solver.roc"
ORC, MOV = "tests/unit/oracle.roc", "packages/resolve/tests/moves.roc"
CLO, PIK, PMV = "tests/unit/pickclosure.roc", "tests/unit/pick.roc", "tests/unit/pickmoves.roc"

# (id, file, old, new, tests, what the change breaks)
M = [
    ("O1", O, "Problem => search(input, extra.append(done.map(|c| { name: c.name, ids: [c.id], sign: In })))", "Problem => Fail(failure_of(input))", [CLO, ORC], "R-AL9: a closure problem is no conflict, the step gives up"),
    ("O2", O, "conflicts: same_group(slots).concat(extra)", "conflicts: extra", [ORC], "R-WS2: the conflict of 2 slots of one group is dropped (the closure walk finds it later, 2^16 tuples)"),
    ("O3", O, "moves = if input.second input.slots", "moves = if Bool.False input.slots", [PMV, ORC], "R-SP24: no movable slot goes first"),
    ("O4", O, "open = slot.hold == Free or (slot.hold == Movable and input.second)", "open = slot.hold == Free or slot.hold == Movable", [PMV, ORC], "R-SP1/R-C9: a movable slot is open in the first search"),
    ("O5", O, "facts: req.facts.concat(asks.keep_oks(|a| guess_of(input, a)))", "facts: req.facts", [CLO, PIK], "R-AL8: the Need list has the slot releases only (no optimistic tuple)"),
    ("O6", O, "name: name_of(i),", "name: slot.id,", [ORC], "R-WS8: slot names by id, not by place"),
    ("O7", O, "Ok(fail) => fail\n", "Ok(_) => Fail.new(NoTuple, \"x\")\n", [PIK, PMV], "R-PH10: the text of an empty domain is lost"),
    ("S1", S, "Highest => own.concat(higher).concat(lower)", "Highest => own.concat(lower).concat(higher)", [MOV, PMV], "R-SP24: Highest goes down first"),
    ("S2", S, "Lowest => own.concat(lower).concat(higher)", "Lowest => own.concat(higher).concat(lower)", [MOV, PMV], "R-SP24: Lowest goes up first"),
    ("S3", S, "match search(req, first.concat(rest), moved) {", "match search(req, rest.concat(first), moved) {", [MOV, PMV], "R-SP24: the movable slots are last in the search"),
    ("S4", S, "Need(asks) => Need(in_slot_order(req.slots, asks))", "Need(asks) => Need(asks)", [MOV], "R-DT2: the Need list is in the order of the search"),
    ("S5", S, "own = asc.keep_if(|x| x.c.id == cur)", "own = []", [MOV, PMV], "R-SP24: current is not first"),
]


def sh(*a):
    return subprocess.run(a, cwd=ROOT, capture_output=True, text=True)


def run(test):
    try:
        r = subprocess.run([ROC, "test", test, "--no-cache"], cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=240)
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr).strip().splitlines()[-1][:100] if (r.stdout + r.stderr).strip() else ""


def main():
    want = sys.argv[1:]
    sh(os.path.join(ROOT, "research/slice-036-revert/swap.sh"), "ref")
    for (mid, f, old, new, tests, why) in M:
        if want and mid not in want:
            continue
        src = os.path.join(ROOT, "research/slice-036-revert/reference", f)
        text = open(src).read()
        if text.count(old) != 1:
            print(f"{mid}: BAD MUTATION (old text found {text.count(old)} times)")
            continue
        open(os.path.join(ROOT, f), "w").write(text.replace(old, new))
        verdict = "NOT CAUGHT"
        for t in tests:
            bad, line = run(t)
            if bad:
                verdict = f"CAUGHT by {t}"
                break
        print(f"{mid}: {verdict}  ({why})", flush=True)
        shutil.copyfile(src, os.path.join(ROOT, f))
    sh(os.path.join(ROOT, "research/slice-036-revert/swap.sh"), "stub")


main()
