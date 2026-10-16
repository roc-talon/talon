"""Cross-checks the hand-written L0 cases of roc-toml with Python tomllib.
Usage: python3 -I check_cases.py <roc-toml dir>. Prints each case where
tomllib disagrees (tomllib is TOML 1.0.0 in CPython 3.11 to 3.13)."""
import re, sys, tomllib
from pathlib import Path

def unroc(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\":
            n = s[i + 1]
            if n == "u":
                j = s.index(")", i)
                out.append(chr(int(s[i + 3 : j], 16))); i = j + 1; continue
            out.append({"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "$": "$"}[n]); i += 2; continue
        out.append(c); i += 1
    return "".join(out)

LIT = r'"((?:[^"\\]|\\.)*)"'
root = Path(sys.argv[1])
cases = []
for name, pre in (("values.roc", "v = "), ("structure.roc", "")):
    for ln, line in enumerate((root / "tests" / name).read_text().splitlines(), 1):
        for fn, ok in (("bad", False), ("v", True), ("tbl", True), ("err_line", False), ("get", True)):
            for m in re.finditer(r"\b%s\(%s" % (fn, LIT), line):
                cases.append((name, ln, pre + unroc(m.group(1)), ok))
        m = re.search(r"Toml\.parse\(%s\)\.is_err\(\)" % LIT, line)
        if m:
            cases.append((name, ln, unroc(m.group(1)), False))
bad = 0
for name, ln, text, ok in cases:
    try:
        tomllib.loads(text); got = True
    except tomllib.TOMLDecodeError:
        got = False
    if got != ok:
        bad += 1; print("DISAGREE %s:%d expect_ok=%s %r" % (name, ln, ok, text))
print("cases %d, disagree %d" % (len(cases), bad))

# The expected texts of the edit tests must be valid TOML too.
bad2 = n2 = 0
for name in ("edit.roc", "entries.roc"):
    for ln, line in enumerate((root / "tests" / name).read_text().splitlines(), 1):
        for m in re.finditer(r'== %s' % LIT, line):
            text = unroc(m.group(1))
            if text in ("NoEntry", "KeyExists", "NotATable", "ERR"):
                continue
            n2 += 1
            try:
                tomllib.loads(text)
            except tomllib.TOMLDecodeError as e:
                bad2 += 1; print("INVALID %s:%d %r %s" % (name, ln, text, e))
print("edit texts %d, invalid %d" % (n2, bad2))
