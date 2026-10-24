#!/usr/bin/env python3
"""Revert check of the code of slice 039a (TW12, filtered runs only, no full sweep).

The tree must hold the final code (research/slice-039-revert/code-final/, code-final.sha256). For each mutation: copy the final file over cli/lib, one small change, a `roc check`,
then only the tests that must see it. CAUGHT = a test fails or times out. The final file is copied back after each mutation.
Usage: python3 -I research/slice-039-revert/agent-mutate.py [id ...]   (from the repo root)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
FINAL = os.path.join(ROOT, "research/slice-039-revert/code-final", LIB)
TIMEOUT = {"l0": 180, "l2": 600}

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("A1", "NightlyPlan.roc", [("(have(id) or is_newest(id))", "(have(id) or is_newest(id) or Bool.True)")], ["l0:nightlyplan", "l2:upgrade/ur1"], "U5 (c): a compiler that is not installed is askable"),
    ("A2", "NightlyPlan.roc", [("== After text else best)", "== Before text else best)")], ["l0:nightlyplan", "l2:upgrade/ur1"], "Q3: H is the oldest pin, not the newest"),
    ("A3", "Oracle.roc", [("on = { ..compat, compiler: run.nightly }", "on = compat")], ["l0:oraclefree", "l0:oracle", "l2:upgrade/ur1"], "the scan and the lookups use H, not the compiler of the tuple"),
    ("A4", "PickLoop.roc", [("	if started.installed.contains(id) {", "	if started.installed.contains(id) and Bool.False {")], ["l2:upgrade/ur1"], "R-CC9: no .last-use for the other compiler of a probe round"),
    ("A5", "PickLoop.roc", [("of = |p| if Pin.same_id(p.nightly, started.id) started.id else p.nightly", "of = |p| p.nightly")], ["l2:probe/pb1"], "R-CV1: 2 spellings of the started compiler are 2 compilers"),
    ("A6", "Ladder.roc", [("Ok(found) if request.loop.base.is_err() => found", "Ok(found) if request.loop.base.is_err() or Bool.True => found")], ["l2:upgrade/ur1"], "the ladder starts no candidate compiler"),
    ("A7", "InstallFlow.roc", [("ladder_decision = if moved.is_ok() { ..decision, writes: [] } else decision", "ladder_decision = if moved.is_ok() and Bool.False { ..decision, writes: [] } else decision")], ["l2:upgrade/ur1", "l2:upgrade/ur2"], "the pin of Pin.decide is a second op of the candidate header"),
    ("A8", "InstallFlow.roc", [("downloads: ladder_ran.downloads + after.downloads }", "downloads: ladder_ran.downloads }")], ["l2:upgrade/ur1"], "data.downloads has no download of the plan"),
    ("A9", "NightlyFlow.roc", [("	if !run.base.is_empty() {", "	if !run.base.is_empty() or Bool.True {")], ["l2:upgrade/ur2", "l2:upgrade/ur1"], "R-NI12: N alone is asked as a required download (TALON_AUTO_INSTALL=no refuses it)"),
    ("A10", "PickLoop.roc", [("wants_domain = |setup, probed| setup.free.is_ok() and", "wants_domain = |setup, probed| setup.free.is_ok() and Bool.False and")], ["l2:upgrade/ur1"], "D is not read before the first step of a free compiler"),
    ("A11", "PickAsk.roc", [('request.names.keep_if(|name| name != "roc") else request.names {', 'request.names else request.names {')], ["l2:upgrade/ur1"], "the word roc is a package name"),
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
        shutil.copyfile(os.path.join(FINAL, fname), path)
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
                shutil.copyfile(os.path.join(FINAL, fname), path)
        shutil.copyfile(os.path.join(FINAL, fname), path)


main()
