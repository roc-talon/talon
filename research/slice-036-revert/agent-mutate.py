#!/usr/bin/env python3
"""Revert check of the code of slice 036 (TW12, filtered runs only, no full sweep, user rule 2026-10-23).

For each mutation: the file is copied from `code-final/`, one small change is made, and only the tests that should catch it run.
CAUGHT = a test fails, or it runs longer than the timeout (a loop). The file is put back from `code-final/` after each mutation.
At the end the 4 files are compared with `code-final.sha256`.
Usage (repo root): python3 -I research/slice-036-revert/agent-mutate.py [id ...]
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "research/slice-036-revert")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
CACHE = os.environ.get("MUT_CACHE", "/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/cache")
ENV = dict(os.environ, XDG_CACHE_HOME=CACHE, ROC_CACHE_DIR=CACHE + "/roc")
O, S = "cli/lib/Oracle.roc", "packages/resolve/Solver.roc"
ORC, MOV = "tests/unit/oracle.roc", "packages/resolve/tests/moves.roc"
CLO, PIK, PMV = "tests/unit/pickclosure.roc", "tests/unit/pick.roc", "tests/unit/pickmoves.roc"

# (id, file, old, new, tests, what the change breaks)
M = [
    ("A1", O, "Problem => search(input, req, movable, tried.append(chosen.map(|c| { name: c.name, ids: [c.id], sign: In })))", 'Problem => Fail(Fail.new(NoTuple, "x"))', [CLO, ORC], "R-AL9: a closure problem is no conflict, the step gives up"),
    ("A2", O, "conflicts: same_group(slots),", "conflicts: [],", [ORC], "R-WS2, D7: no pair conflict for slots of one group"),
    ("A3", O, "movable_of = |input| if input.second", "movable_of = |input| if Bool.False", [PMV, ORC], "R-SP24: no movable slot goes first"),
    ("A4", O, "open = slot.hold == Free or (slot.hold == Movable and second)", "open = slot.hold == Free or slot.hold == Movable", [PMV, ORC], "R-SP1, R-C9: a movable slot is open in the first search"),
    ("A5", O, "Ok(slot) => if slot.kind == Platform Platform else Package", "Ok(_) => Package", [ORC, PIK], "D3: the optimistic fact of a platform slot has the kind Package"),
    ("A6", O, "name: slot_name(i),", "name: slot.id,", [ORC], "R-WS8, D6: slot names by id, not by place"),
    ("A7", O, "published_at: slot.candidates.find_first(|x| x.url == c.id).map_ok(|x| x.published_at) ?? 0,", "published_at: 0,", [PIK, ORC], "R-C7: the note of a named version that is too young is lost"),
    ("S1", S, "ask = |asks| Need(if any_moved asks_in_slot_order(order, vars, asks) else asks)", "ask = |asks| Need(asks)", [MOV], "R-DT2: the Need list is in the order of the search"),
    ("S2", S, "back = |items| if any_moved in_slot_order(order, items) else items", "back = |items| items", [MOV, PMV], "R-DT2: the Done list is in the order of the search"),
    ("S3", S, "moved = |slot| slot.kind != Compiler and movable.contains(slot.name)", "moved = |slot| movable.contains(slot.name)", [MOV], "R-SP23: the compiler slot is movable"),
]


def sh(*a):
    return subprocess.run(a, cwd=ROOT, capture_output=True, text=True)


def run(test):
    try:
        r = subprocess.run([ROC, "test", test, "--no-cache"], cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired:
        return True, "timeout"
    out = (r.stdout + r.stderr).strip().splitlines()
    return r.returncode != 0, out[-1][:100] if out else ""


def restore(f):
    shutil.copyfile(os.path.join(HERE, "code-final", f), os.path.join(ROOT, f))


def main():
    want = sys.argv[1:]
    os.makedirs(CACHE, exist_ok=True)
    for (mid, f, old, new, tests, why) in M:
        if want and mid not in want:
            continue
        restore(f)
        text = open(os.path.join(ROOT, f)).read()
        if text.count(old) != 1:
            print(f"{mid}: BAD MUTATION (old text found {text.count(old)} times)")
            continue
        open(os.path.join(ROOT, f), "w").write(text.replace(old, new))
        verdict = "NOT CAUGHT"
        for t in tests:
            bad, line = run(t)
            if bad:
                verdict = f"CAUGHT by {t} ({line})"
                break
        print(f"{mid}: {verdict}  [{why}]", flush=True)
        restore(f)
    r = sh("sha256sum", "-c", "research/slice-036-revert/code-final.sha256")
    print(r.stdout.strip())


main()
