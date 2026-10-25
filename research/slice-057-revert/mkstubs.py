#!/usr/bin/env python3
"""Makes the stubs of slice 057 from the reference modules: the text up to the end of the module block, each function body replaced by `crash "todo: slice 057"`, private helpers cut.
Usage: python3 research/slice-057-revert/mkstubs.py   (reads research/slice-057-revert/reference/cli/lib, writes research/slice-057-revert/stubs/cli/lib)"""
import re, os
SRC = "research/slice-057-revert/reference/cli/lib/"
DST = "research/slice-057-revert/stubs/cli/lib/"
os.makedirs(DST, exist_ok=True)
for name in ["ScriptsToml", "RunCmd", "RunPlan", "RunFind", "RunTools", "RunFlow"]:
    lines = open(SRC + name + ".roc").read().split("\n")
    out = []
    i = 0
    in_mod = False
    while i < len(lines):
        l = lines[i]
        if re.match(r"^\w+ :: \[\]\.\{", l):
            in_mod = True
        if in_mod and l == "}":
            out.append("}")
            break
        m = re.match(r"^\t([a-z_]+!?) = \|(.*?)\| ", l) if in_mod else None
        if m:
            params = ", ".join("_" + p.strip().rstrip("!") if p.strip() else p for p in m.group(2).split(","))
            out.append(f"\t{m.group(1)} = |{params}| crash \"todo: slice 057\"")
            while i < len(lines) and lines[i] != "" and lines[i] != "}":
                i += 1
            continue
        out.append(l)
        i += 1
    open(DST + name + ".roc", "w").write("\n".join(out) + "\n")
