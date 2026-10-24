#!/usr/bin/env python3
# Slice 022b: the one-time edit of the old L2 `calls.log` files and L3 `roc.log` files (TW21: only the outputs that the slice changes).
# L2: the 3 lines `programs roc`, `spawn_all limit=1`, `  job - roc version` of the compiler step become the calls of the launcher test (R-SO9).
#     The first run of a case that has a roc on PATH runs `roc version` and writes the cache. Each later run reads the cache.
#     A case with no roc on PATH (the `programs roc` line is not followed by a spawn) has only `path_roc`.
# L3: `roc version` runs once for a case (the cache is in the HOME of the case), so only the first `version` line stays.
import sys, os, glob
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = "$HOME/.cache/roc/talon/path-roc.json"
FILE = "/fake/bin/roc"
for path in sorted(glob.glob(f"{root}/tests/commands/cases/*/*/expect/calls.log")):
    lines = open(path).read().split("\n")
    out, i, ran = [], 0, False
    changed = False
    while i < len(lines):
        if lines[i] == "programs roc":
            changed = True
            has_roc = i + 2 < len(lines) and lines[i + 1] == "spawn_all limit=1" and lines[i + 2] == "  job - roc version"
            out.append("path_roc")
            if has_roc:
                out.append(f"read_files {CACHE}")
                if not ran:
                    out += ["spawn_all limit=1", f"  job - {FILE} version", f"write_atomic {CACHE}"]
                    ran = True
                i += 3
            else:
                i += 1
            continue
        out.append(lines[i])
        i += 1
    if changed:
        open(path, "w").write("\n".join(out))
        case = os.path.dirname(os.path.dirname(path))
        if ran:
            with open(f"{case}/fx/path-roc", "w") as f:
                f.write("# slice 022b: a tln of 5000 bytes and a roc of 1000 bytes. The sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n")
            print("case with a roc:", os.path.relpath(case, root))
        else:
            print("case with no roc:", os.path.relpath(case, root))
for path in sorted(glob.glob(f"{root}/tests/scenarios/*/*/expect/roc.log")):
    lines = open(path).read().split("\n")
    if "version" not in lines:
        continue
    seen = False
    out = []
    for l in lines:
        if l == "version":
            if seen:
                continue
            seen = True
        out.append(l)
    open(path, "w").write("\n".join(out))
    print("L3:", os.path.relpath(path, root))

# L3 `verify/vf1-verify` prints the sorted roc.log into stdout: the 6 `version` lines became 1 (edited by `sed -i 55,59d` on the expected stdout).
