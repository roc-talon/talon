#!/usr/bin/env python3
"""Makes the stubs of slice 046 from the private reference (research/slice-046-revert/reference/lib): the doc comments and the signatures stay, each body of a public function is `crash "todo: slice 046"`,
the private helpers after the module are removed, and the imports that nothing uses are removed. Run from the repo root."""
import re, os
REF = "research/slice-046-revert/reference/lib"
OUT = "research/slice-046-revert/stubs/lib"
def stub(name):
    lines = open(f"{REF}/{name}.roc").read().split("\n")
    # the module block ends at the first line `}` at column 0
    end = next(i for i, l in enumerate(lines) if l == "}")
    head, body = lines[:end + 1], lines[:end + 1]
    out = []
    i = 0
    imports = [l for l in lines if l.startswith("import ")]
    body_lines = lines[:end + 1]
    # skip the imports
    start = next(i for i, l in enumerate(body_lines) if not l.startswith("import "))
    res = []
    i = start
    while i < len(body_lines):
        l = body_lines[i]
        m = re.match(r"^\t([a-z_]+!?) = \|([^|]*)\|", l)
        if m:
            fname, params = m.group(1), m.group(2)
            ps = ", ".join("_" + p.strip() for p in params.split(",")) if params.strip() else ""
            res.append(f"\t{fname} = |{ps}| crash \"todo: slice 046\"")
            i += 1
            # skip the rest of the body: until a line that is a blank line followed by a doc comment or the closing brace
            while i < len(body_lines) and not (body_lines[i] == "}" or (body_lines[i] == "" and i + 1 < len(body_lines) and (body_lines[i + 1].startswith("\t##") or body_lines[i + 1] == "}"))):
                i += 1
            continue
        res.append(l)
        i += 1
    text = "\n".join(res) + "\n"
    code = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("##"))
    used = [l for l in imports if re.search(r"\b" + l.split()[1] + r"\b", code)]
    return "\n".join(used) + "\n" + text
for n in ("ToolsJson", "ToolInstall", "ToolFlow"):
    open(f"{OUT}/{n}.roc", "w").write(stub(n))
print("stubs written")
