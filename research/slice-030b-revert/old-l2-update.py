#!/usr/bin/env python3
"""Slice 030b: the compat.db calls change the expected files of the old L2 cases that read the compiler list (`Nightlies.list!`).
Usage (repo root, the private reference in cli/):  python3 -I research/slice-030b-revert/old-l2-update.py update|check [snapshot dir]
  update   runs `UPDATE=1 tests/commands/run.sh` for the cases in CASES. Before it, each expected file that exists is copied to research/slice-030b-revert/before/<path> (once).
  check    compares the expected files with the snapshot (a copy of tests/ before the slice) and lists, for each changed case and file, the files that differ from the snapshot after the allowed lines are removed from the new file:
             calls.log: a line `db_query <path> busy_ms=5000 format=1 pinned=<n>` or `db_write ...` (an added line only; no line is removed)
             tree.diff: a line of the file `compat.tsv` (added only)
           The output ends with the table of the cases (added db lines, added tsv lines). A line of another kind is printed as `UNEXPECTED`."""
import os, re, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASES = "consent/dl1-resolve consent/dl2-verify-workspace consent/dl3-rank4 proxy/px2-install roc/bs1-base roc/bs2-no-pin roc/bs3-range roc/df1-default roc/ri1-flow roc/up1-update roc/us1-use roc/us3-step".split()
BASE = os.path.join(ROOT, "tests/commands/cases")
BEFORE = os.path.join(ROOT, "research/slice-030b-revert/before/tests/commands/cases")
FILES = ["calls.log", "tree.diff", "stdout", "stderr", "exit"]

def update():
    for case in CASES:
        for f in FILES:
            src = os.path.join(BASE, case, "expect", f)
            dst = os.path.join(BEFORE, case, "expect", f)
            if os.path.exists(src) and not os.path.exists(dst):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy(src, dst)
    env = dict(os.environ, UPDATE="1")
    subprocess.run([os.path.join(ROOT, "tests/commands/run.sh")] + CASES, cwd=ROOT, env=env, check=True)

def lines(path):
    return open(path).read().split("\n") if os.path.exists(path) else []

def check(snap):
    """The new file, without the allowed lines, must be the old file. calls.log: no `db_query`/`db_write` line of compat.db. tree.diff: no section of the file `compat.tsv`."""
    db = re.compile(r"^db_(query|write) \S+/talon/compat\.db busy_ms=5000 format=1 (pinned|facts)=\d+( existing=\w+)?$")
    rows = []
    bad = 0
    for case in CASES:
        counts = {}
        for f in FILES:
            old = lines(os.path.join(snap, "commands/cases", case, "expect", f))
            new = lines(os.path.join(BASE, case, "expect", f))
            if f == "calls.log":
                kept = [l for l in new if not db.match(l)]
                counts[f] = len(new) - len(kept)
            elif f == "tree.diff":
                kept, skip = [], False
                for l in new:
                    if l.startswith("--- "):
                        skip = l.endswith("/compat.tsv")
                    if skip:
                        counts[f] = counts.get(f, 0) + 1
                    else:
                        kept.append(l)
            else:
                kept = new
            if kept != old:
                bad += 1
                print("UNEXPECTED %s/%s differs from the old file after the allowed lines are removed" % (case, f))
        rows.append((case, counts.get("calls.log", 0), counts.get("tree.diff", 0)))
    print("%-34s %8s %10s" % ("case", "db lines", "tsv lines"))
    for r in rows:
        print("%-34s %8d %10d" % r)
    print("unexpected differences: %d" % bad)
    return bad

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode == "update":
        update()
    else:
        sys.exit(1 if check(sys.argv[2]) else 0)
