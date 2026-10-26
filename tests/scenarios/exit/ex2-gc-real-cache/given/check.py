"""Helper of the case exit/ex2-gc-real-cache (slice 053). It only reads. No third-party module.

Usage: python3 -I check.py <label> <gc json file> <cache root> <expected dirs file> <expected package hashes file> <freed file>

It compares the `--json` answer of `tln cache gc` with the sets that the case computed from the files of the copy. It prints one line for each comparison:
`<label>: <what>: yes`, or `no` and the difference. The lines have no machine value (no name, no size, no count), so the expected file is the same on each machine.
"""
import json
import os
import sys

label, jpath, root, dirs_file, pkgs_file, freed_file = sys.argv[1:7]
doc = json.load(open(jpath))
data = doc["data"]
want_dirs = sorted(open(dirs_file).read().split())
want_pkgs = sorted(open(pkgs_file).read().split())
got_dirs = sorted(os.path.basename(p) for p in data["builds"])
got_pkgs = sorted(os.path.basename(p) for p in data["packages"])


def tree_bytes(path):
    n = 0
    for base, _dirs, files in os.walk(path):
        for f in files:
            p = os.path.join(base, f)
            if not os.path.islink(p):
                n += os.path.getsize(p)
    return n


def show(what, ok, extra=""):
    print("%s: %s: %s" % (label, what, "yes" if ok else "no"))
    if not ok:
        print(extra)


show("the json answer is ok", doc["ok"] is True and doc["command"] == "cache gc")
show("build dirs: the listed ones are the old ones", got_dirs == want_dirs, "  want %s\n  got  %s" % (want_dirs, got_dirs))
show("packages: the listed ones are the old ones", got_pkgs == want_pkgs, "  want %d, got %d" % (len(want_pkgs), len(got_pkgs)))
sized = {os.path.basename(s["item"]): s["bytes"] for s in data["sizes"]}
show("each listed item has a size", sorted(sized) == sorted(want_dirs + want_pkgs))
if data["dry_run"]:
    # The items are still there: the sum of the file sizes. The number goes in the freed file, for the real run.
    total = sum(tree_bytes(os.path.join(root, d)) for d in want_dirs) + sum(tree_bytes(os.path.join(root, "packages", h)) for h in want_pkgs)
    show("freed is the sum of the file sizes of the listed items", data["freed"] == total, "  want %d, got %d" % (total, data["freed"]))
    open(freed_file, "w").write("%d\n" % data["freed"])
else:
    want = int(open(freed_file).read())
    show("freed is the number of the dry run", data["freed"] == want, "  want %d, got %d" % (want, data["freed"]))
