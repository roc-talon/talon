#!/usr/bin/env python3
"""Undo update-calls.py on the expected calls.log files (the inverse of the 3 changes), to compare with git and to make the before copies."""
import os, re, sys
sys.argv = ["x", "--check"]
src = open(os.path.join(os.path.dirname(__file__), "update-calls.py")).read().replace("\nmain()\n", "\n")
g = {"__name__": "lib", "__file__": os.path.join(os.path.dirname(os.path.abspath(__file__)), "update-calls.py")}
exec(src, g)
LIST, CANON, ENV, BASE, CASES = g["LIST"], g["CANON"], g["ENV"], g["BASE"], g["CASES"]
for case in CASES:
    p = f"{BASE}/{case}/expect/calls.log"
    lines = open(p).read().split("\n")
    out, i = [], 0
    while i < len(lines):
        l = lines[i]
        if l == ENV:
            i += 1
            continue
        if l == LIST and i + 1 < len(lines) and lines[i + 1] == CANON:
            i += 2
            continue
        if l == LIST and case in ("gaps/g1-slice009", "ladder/ld-no-check-refuse"):
            i += 1
            continue
        m = re.match(r"^  probe (\S+) (\S+) (\S+) (.*)$", l)
        out.append(f"  probe {m.group(1)} {m.group(2)} {m.group(4)}" if m else l)
        i += 1
    open(p, "w").write("\n".join(out))
