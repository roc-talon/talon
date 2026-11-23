"""Slice 262b (B11, R-CM6): mark the anchor rows of `tln outdated` expected files.
Human: the `wanted` cell of the row of an anchored alias gets ` (pinned)`, columns re-aligned (width = longest + 2).
JSON: the package item of that alias gets "pinned":"=<v>" after new_series.
Usage: python3 outdated_pinned.py <file> <alias>=<pin> ..."""
import re, sys
def table(lines, pins):
    rows = [re.split(r" {2,}", l.strip()) for l in lines]
    for r in rows[1:]:
        if r[0] in pins:
            r[2] = r[2] + " (pinned)"
    n = len(rows[0])
    w = [max(len(r[i]) for r in rows) + 2 for i in range(n - 1)]
    return ["  " + "".join(r[i].ljust(w[i]) for i in range(n - 1)) + r[n - 1] for r in rows]
def fix(path, pins):
    src = open(path).read().split("\n")
    out, i = [], 0
    while i < len(src):
        l = src[i]
        if l.startswith("  package  current"):
            block = [l]; i += 1
            while i < len(src) and src[i].startswith("  ") and not src[i].startswith("  fixed:") and not src[i].startswith("  all packages"):
                block.append(src[i]); i += 1
            assert table(block, {}) == block, ("re-layout differs", path, block)
            out += table(block, pins); continue
        if l.startswith('{"schema":1,"command":"outdated"'):
            for a, v in pins.items():
                pat = re.compile(r'(\{"alias":"%s",[^{}]*"new_series":(?:true|false))' % re.escape(a))
                l, n = pat.subn(r'\1,"pinned":"%s"' % v, l)
        out.append(l); i += 1
    open(path, "w").write("\n".join(out))
p = sys.argv[1]
fix(p, dict(a.split("=", 1) for a in sys.argv[2:]))
