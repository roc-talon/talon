#!/usr/bin/env python3
"""Revert check of slice 019. Usage: mutate.py <id>|restore. Each id mutates the current code (after a restore) in place.
The pristine files are kept in the scratch dir given by $MUT_BACKUP (default the scratchpad)."""
import os, shutil, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BK = os.environ.get("MUT_BACKUP", "the scratchpad")
FILES = ["cli/lib/ResolveBase.roc", "cli/lib/VerifyFlow.roc", "scripts/get-roc.sh"]
MUT = {
    # F5, R-SE7: the repeated platform note stays
    "F5": ("cli/lib/ResolveBase.roc",
           ".fold(no_names, |found, text| if found.contains(text) found else found.append(text))",
           ".fold(no_names, |found, text| found.append(text))"),
    # F12, R-CM11: `replace` is not made unique
    "F12": ("cli/lib/VerifyFlow.roc",
            ".fold(no_replace, |found, r| if found.contains(r) found else found.append(r))",
            ".fold(no_replace, |found, r| found.append(r))"),
    # C9, R-PD5: `verify --file <member>` checks all members
    "C9": ("cli/lib/VerifyFlow.roc",
           "if named.is_empty() all else named",
           "if named.len() >= 0 all else named"),
    # G3, R-CV3: no sha256 compare
    "G3": ("scripts/get-roc.sh",
           '[ "$got" = "$want" ] || fail',
           'true || fail'),
}
def restore():
    for f in FILES:
        shutil.copy2(os.path.join(BK, f), os.path.join(ROOT, f))
if not os.path.isdir(BK):
    for f in FILES:
        os.makedirs(os.path.dirname(os.path.join(BK, f)), exist_ok=True)
        shutil.copy2(os.path.join(ROOT, f), os.path.join(BK, f))
restore()
if sys.argv[1] != "restore":
    f, old, new = MUT[sys.argv[1]]
    p = os.path.join(ROOT, f)
    s = open(p).read()
    assert s.count(old) == 1, (sys.argv[1], s.count(old))
    open(p, "w").write(s.replace(old, new))
