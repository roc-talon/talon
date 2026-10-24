#!/usr/bin/env python3
"""Revert check of the reference code of slice 039c (TW12, filtered runs only, no full sweep).

The tree must hold the reference (research/slice-039c-revert/reference/, `flip.sh ref`). For each mutation: one small change in one file, a `roc check`,
then only the tests that must see it. CAUGHT = a test fails or times out. The file is put back after each mutation.
Usage: python3 -I research/slice-039c-revert/mutate.py [id ...]   (from the repo root)
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 180, "l2": 600}
UR6 = "l2:upgrade/ur6-moves"
LIB = "cli/lib/"
SOLVER = "packages/resolve/Solver.roc"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("P1", LIB + "PickFlow.roc", [("nightly_moves = request.command == Upgrade and", "nightly_moves = request.command != Install and")], [UR6], "R-RP2, R-SP23: `update` moves the nightly too"),
    ("P2", SOLVER, [("{ ..asc, vals: if req.rules.strategy == Highest own.concat(higher).concat(lower) else own.concat(lower).concat(higher) }\n}\n\nmoved_package", "{ ..asc, vals: if req.rules.strategy == Highest own.concat(lower).concat(higher) else own.concat(higher).concat(lower) }\n}\n\nmoved_package")], ["l0f:packages/resolve/tests/moves.roc"], "R-SP24: a movable compiler takes the nearest lower compilers first with Highest"),
    ("P3", LIB + "Oracle.roc", [("OracleRequest.movable_of(input).append(OracleRequest.roc_name), [], OracleHint.hint)\n	}\n\n	## The step of slice 036", "OracleRequest.movable_of(input), [], OracleHint.hint)\n	}\n\n	## The step of slice 036")], ["l0:oraclefree", UR6], "R-RP4: the compiler is not movable in the second search (it is free: the newest compiler that works)"),
    ("P4", LIB + "NightlyPlan.roc", [("Ok(n) => if Pin.same_id(f.held, n) Err(Same) else Ok({ alias: \"roc\"", "Ok(n) => if f.held == n Err(Same) else Ok({ alias: \"roc\"")], ["l0:nightlyplan"], "R-CV1: a tuple on H in the other tag form is a move"),
    ("P5", LIB + "Lags.roc", [("Pin.order({ a: g, b: n, times: [] }) == Before {", "Pin.order({ a: g, b: n, times: [] }) != Same {")], ["l0:upgrade"], "R-UP2: a lag also when the compiler is newer than N"),
    ("P6", LIB + "Lags.roc", [("first_ok(real.concat(f.releases.map(|r| inferred_reason({ compiler: f.compiler, used: f.used, inferred: f.inferred }, r))))", "first_ok(real)")], ["l0:upgrade", UR6], "R-EP14: no reason from an inferred fail"),
    ("P7", LIB + "PickLoop.roc", [("wants_domain = |setup, probed| (setup.free.is_ok() or setup.movable.is_ok()) and", "wants_domain = |setup, probed| setup.free.is_ok() and")], [UR6], "the compiler list D is not read before the second search: the movable nightly has only H"),
    ("P8", LIB + "PickFlow.roc", [("members: ready.loaded.members.map(|m| m.file) })", "members: ready.loaded.members.take_first(1).map(|m| m.file) })")], [UR6], "R-SP25: the move of the nightly lists only the first member"),
    ("P9", LIB + "NightlyFlow.roc", [("NightlyPlan.moved_to({ free: request.command == Upgrade, unify: differ, held, nightly })", "NightlyPlan.moved_to({ free: is_free(request), unify: differ, held, nightly })")], [UR6], "R-RP4: the pin of a held move is not written"),
    ("P10", LIB + "PickFlow.roc", [("roc = if nightly_moves NightlyPlan.roc_move(", "roc = if nightly_moves or request.command == Upgrade NightlyPlan.roc_move(")], [UR6], "R-SP9: the free nightly is named as a held variable in the report and the prompt"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l0f":
        cmd = [ROC, "test", arg, "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind[:2]])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        path = os.path.join(ROOT, fname)
        orig = open(path).read()
        text = orig
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            try:
                check = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if check.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + check.stdout[:300].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                open(path, "w").write(orig)


main()
