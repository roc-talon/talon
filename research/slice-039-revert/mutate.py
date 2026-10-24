#!/usr/bin/env python3
"""Revert check of the reference code of slice 039 (TW12, filtered runs only, no full sweep).

The tree must hold the reference (research/slice-039-revert/reference/). For each mutation: one small change in one file of cli/lib, a `roc check`,
then only the tests that must see it. CAUGHT = a test fails or times out. The file is put back after each mutation.
Usage: python3 -I research/slice-039-revert/mutate.py [id ...]   (from the repo root)
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 180, "l2": 600}

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("N1", "NightlyPlan.roc", [("(have(id) or is_newest(id))", "(have(id) or is_newest(id) or Bool.True)")], ["l0:nightlyplan", "l2:upgrade/ur1"], "U5 (c): a compiler that is not installed is askable"),
    ("N2", "NightlyPlan.roc", [("now: f.now, min_age: f.min_age, snapshot: f.snapshot, keep: [] })\n		fits", "now: f.now, min_age: 0, snapshot: f.snapshot, keep: [] })\n		fits")], ["l0:nightlyplan"], "R-C7: min-release-age does not hide an installed compiler"),
    ("N3", "Oracle.roc", [("slots.append(roc_slot(values))", "[roc_slot(values)].concat(slots)")], ["l0:oraclefree", "l2:upgrade/ur1"], "R-SP13: the compiler is the first slot, not the last"),
    ("N4", "PickFlow.roc", [("None => NightlyOnly", "None => Upgrade")], ["l2:upgrade/ur1"], "R-SP8: upgrade roc frees the packages"),
    ("N5", "Upgrade.roc", [("if opts.no_check and NightlyPlan.scope(opts.names).nightly == Free {", "if opts.no_check and opts.names.is_empty() and !opts.dry_run {")], ["l0:upgrade", "l2:upgrade/ur1"], "R-UP9: --no-check with the name roc is allowed"),
    ("N6", "NightlyPlan.roc", [("if Pin.same_id(h, n) Err(Same) else Ok(n)", "if Pin.same_id(h, n) and Bool.False Err(Same) else Ok(n)")], ["l0:nightlyplan", "l2:upgrade/ug1"], "R-RP1: the pin is written when it does not change"),
    ("N7", "InstallFlow.roc", [("	if free_nightly {\n		match decision.held {", "	if free_nightly and request.names.is_empty() {\n		match decision.held {")], ["l2:upgrade/ur1"], "R-UP6: the range gate stops a free nightly"),
    ("N8", "NightlyFlow.roc", [("} else if !run.baseline {", "} else if !run.baseline or Bool.True {")], ["l2:upgrade/ur2"], "R-DL1: the baseline has no prompt of its own, N is named alone"),
    ("N9", "NightlyFlow.roc", [("free: if only_held Err(Held) else Ok(picked.askable)", "free: if only_held and Bool.False Err(Held) else Ok(picked.askable)")], ["l2:upgrade/ug2"], "the old probes of upgrade change when N is H"),
    ("N10", "InstallWrite.roc", [("Ok(_) => facts.decision.held.map_err(|_| None)\n", "Ok(_) => Err(None)\n")], ["l2:upgrade/ur1"], "R-BL3: the baseline of the ladder is not H"),
    ("N11", "NightlyFlow.roc", [('if request.names.contains("roc") {', 'if request.names.contains("roc") and Bool.False {')], ["l2:upgrade/ur3"], "Q1: upgrade roc degrades when the list cannot be read"),
    ("N12", "NightlyPlan.roc", [("differ = f.free and texts.len() >= 2", "differ = f.free and texts.len() >= 2 and Bool.False")], ["l0:nightlyplan", "l2:upgrade/ur1"], "Q3: different pins stop a free nightly"),
    ("N13", "NightlyPlan.roc", [("if Pin.same_id(h, n) and !f.unify Err(Same) else Ok(n)", "if Pin.same_id(h, n) Err(Same) else Ok(n)")], ["l0:nightlyplan", "l2:upgrade/ur1"], "Q3: the result H is not written to the members with another pin"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        path = os.path.join(ROOT, LIB, fname)
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
                open(path, "w").write(orig)


main()
