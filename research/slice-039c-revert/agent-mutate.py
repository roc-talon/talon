#!/usr/bin/env python3
"""Revert check of the code of slice 039c by the code agent (TW12, filtered runs only, no full sweep).

Before each mutation the file is restored from research/slice-039c-revert/code-final/ (repo-relative paths). After the run, the same copy is put back and
`code-final.sha256` is checked from the repo root. CAUGHT = a test fails or times out.
Usage: python3 -I research/slice-039c-revert/agent-mutate.py [id ...]   (from the repo root)
"""
import hashlib, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
FINAL = os.path.join(ROOT, "research/slice-039c-revert/code-final")
LIB = "cli/lib/"
SOLVER = "packages/resolve/Solver.roc"
TIMEOUT = {"l0": 180, "l2": 600}
UR6 = "l2:upgrade/ur6-moves"
UG3 = "l2:upgrade/ug3-move"
MOVES = "l0f:packages/resolve/tests/moves.roc"

# (id, file (repo-relative), [(old, new)], [tests], what the change breaks)
M = [
    ("B1", SOLVER, [("asc.vals.take_first(at).rev()", "asc.vals.take_first(at)")], [MOVES], "R-SP24: the lower compilers of a movable compiler are in the order of D, not the nearest first"),
    ("B2", SOLVER, [("moved = |slot| movable.contains(slot.name) and (slot.kind != Compiler or slot.current.is_ok())", "moved = |slot| movable.contains(slot.name)")], [MOVES], "R-SP23: a compiler slot with no current is movable"),
    ("B3", LIB + "NightlyPlan.roc", [("fit = |id| Pin.same_id(id, f.held) or (not_older(id) and (have(id) or extra == Ok(id)))", "fit = |id| Pin.same_id(id, f.held) or ((not_older(id) or have(id)) and (have(id) or extra == Ok(id)))")], ["l0:nightlyplan"], "D2: a compiler older than H is a value of the movable nightly"),
    ("B4", LIB + "Lags.roc", [("match first_ok(f.releases.map(reason)) {", "match first_ok(f.releases.map(guess)) {"), ("Err(None) => first_ok(f.releases.map(guess))", "Err(None) => first_ok(f.releases.map(reason))")], ["l0:upgrade"], "R-EP14: an inferred fail wins over a real row of a later release"),
    ("B5", LIB + "Lags.roc", [("why = blame({ releases: f.releases, compiler: newest,", "why = blame({ releases: f.releases, compiler: got,")], ["l0:upgrade"], "R-UP2: the lag reason is blamed on the chosen compiler, not on N"),
    ("B6", LIB + "InstallFlow.roc", [("Ok(held_move) => Ok(held_move.to)", "Ok(_) => Err(Same)")], [UR6], "R-RP4: the pin of a held nightly move is not written"),
    ("B7", LIB + "PickLoop.roc", [("		Ok(list) => list\n		Err(NotRead) => PickLoop.releases!(fx, request)\n	}\n	next =", "		Ok(_) => PickLoop.releases!(fx, request)\n		Err(NotRead) => PickLoop.releases!(fx, request)\n	}\n	next =")], [UR6, UG3], "Q3, D3: `wide!` reads the compiler list again"),
    ("B8", LIB + "NightlyFlow.roc", [("if run.releases.is_empty() return [run.held]", "if run.releases.len() > 999 return [run.held]")], [UG3], "D3: the installed compilers are read when the list is empty"),
    ("B9", LIB + "PickFlow.roc", [("nightly == Held and ready.setup.held.is_ok()", "nightly != Free and ready.setup.held.is_ok() or request.command == Upgrade")], [UR6], "R-UP13: a free nightly (`upgrade X roc`) is a held move"),
    ("B10", LIB + "PickLoop.roc", [("wants_domain = |setup, probed| (setup.free.is_ok() or setup.movable.is_ok()) and", "wants_domain = |setup, probed| setup.free.is_ok() and")], [UR6], "the compiler list D is not read before the second search: the movable nightly has only H"),
]


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def restore(fname):
    shutil.copyfile(os.path.join(FINAL, fname), os.path.join(ROOT, fname))


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
        restore(fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            try:
                built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if built.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                restore(fname)
    bad = subprocess.run("sha256sum -c research/slice-039c-revert/code-final.sha256 | grep -v ': OK$'", shell=True, cwd=ROOT, capture_output=True, text=True).stdout
    print("final compare:", "SAME" if not bad else "DIFFERENT\n" + bad, flush=True)


main()
