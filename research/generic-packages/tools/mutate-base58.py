#!/usr/bin/env python3
# Plant one mutation at a time in package/Base58.roc, run the L0 test apps and
# the fuzz targets, restore the file, and print one result line per mutation.
import os, re, shutil, subprocess, sys, filecmp

HERE = os.path.dirname(os.path.abspath(__file__))
TALON = os.path.normpath(os.path.join(HERE, "../../.."))
# The package checkout is next to the Talon checkout.
REPO = os.environ.get("REPO", os.path.join(os.path.dirname(TALON), "roc-base58"))
ROC = os.environ.get("ROC", os.path.join(TALON, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
SRC = os.path.join(REPO, "package/Base58.roc")
ORIG = sys.argv[1]  # the copy of package/Base58.roc from step 0
W = os.path.join(REPO, ".work")
env = dict(os.environ, XDG_CACHE_HOME=W + "/xdg", ROC_CACHE_DIR=W + "/xdg/roc")

M = [
    ("M1 alphabet order (A,B swapped)", 'alphabet = "123456789ABCDEF', 'alphabet = "123456789BACDEF'),
    ("M2 encode: no leading `1` for zero bytes", "zeros = count_leading(bytes, 0)\n", "zeros = count_leading(bytes, 0) * 0\n"),
    ("M3 encode: one `1` too many for zero bytes", "List.repeat('1', zeros)", "List.repeat('1', zeros + zeros.min(1))"),
    ("M4 decode: no zero byte for leading `1`", "List.repeat(0, zeros).concat", "List.repeat(0, 0).concat"),
    ("M5 decode: each digit 0 (not only leading) is a zero byte", "zeros = count_leading(values, 0)", "zeros = values.count_if(|v| v == 0)"),
    ("M6 InvalidChar index + 1", "=> Err(InvalidChar(index))", "=> Err(InvalidChar(index + 1))"),
    ("M7 InvalidChar: last bad byte, not first", "chars.find_first_index(|c| digit_value(c).is_err())", "chars.find_last_index(|c| digit_value(c).is_err())"),
    ("M8 decode: trim whitespace at start and end", "chars = text.to_utf8()", "chars = text.trim().to_utf8()"),
    ("M9 decode: skip space inside", "chars = text.to_utf8()", "chars = text.to_utf8().drop_if(|c| c == ' ')"),
    ("M10 limit: > to >= (1024 rejected)", "if length > max_text_len {", "if length >= max_text_len {"),
    ("M11 limit value 1024 to 1025", "max_text_len = 1024", "max_text_len = 1025"),
    ("M12 TooLong payload is the limit, not the length", "return Err(TooLong(length))", "return Err(TooLong(max_text_len))"),
    ("M13 limit counts characters (ASCII-only count)", "length = text.count_utf8_bytes()", "length = text.to_utf8().count_if(|c| c < 0x80 or c >= 0xC0)"),
    ("M14 alphabet check before length check",
     "\t\tlength = text.count_utf8_bytes()\n\t\tif length > max_text_len {\n\t\t\treturn Err(TooLong(length))\n\t\t}\n\t\tchars = text.to_utf8()\n\t\tmatch chars.find_first_index(|c| digit_value(c).is_err()) {\n\t\t\tOk(index) => Err(InvalidChar(index))\n",
     "\t\tlength = text.count_utf8_bytes()\n\t\tchars = text.to_utf8()\n\t\tmatch chars.find_first_index(|c| digit_value(c).is_err()) {\n\t\t\tOk(index) => Err(InvalidChar(index))\n\t\t\tErr(NotFound) if length > max_text_len => Err(TooLong(length))\n"),
    ("M15 encode: [] gives `1`", "Str.from_utf8_lossy(List.repeat('1', zeros).concat(chars))", "Str.from_utf8_lossy(if bytes.is_empty() ['1'] else List.repeat('1', zeros).concat(chars))"),
    ("M16 decode: empty text is an error", "\t\tchars = text.to_utf8()\n", "\t\tif length == 0 {\n\t\t\treturn Err(InvalidChar(0))\n\t\t}\n\t\tchars = text.to_utf8()\n"),
    ("M17 encode: least significant digit first (no rev)", "chars = digits.rev().map", "chars = digits.map"),
    ("M18 decode: bytes little-endian (no rev)", "concat(bytes.rev())", "concat(bytes)"),
    ("M19 mul_add: carry drops the last digit", "\twhile $carry > 0 {", "\twhile $carry > radix {"),
]

only = sys.argv[2:]
tests = sorted(f for f in os.listdir(REPO + "/tests") if f.endswith(".roc"))
fuzz = sorted(f[:-4] for f in os.listdir(REPO + "/fuzz") if f.endswith(".roc"))
orig = open(ORIG).read()
for name, old, new in M:
    if only and name.split()[0] not in only:
        continue
    assert filecmp.cmp(SRC, ORIG, shallow=False), "source changed before " + name
    assert orig.count(old) == 1, name + ": old text count " + str(orig.count(old))
    open(SRC, "w").write(orig.replace(old, new))
    res = []
    chk = subprocess.run([ROC, "check", "package/main.roc"], cwd=REPO, env=env, capture_output=True, text=True)
    if chk.returncode != 0:
        res.append("CHECK-ERROR")
    for t in tests:
        p = subprocess.run([ROC, "test", "tests/" + t, "--no-cache"], cwd=REPO, env=env, capture_output=True, text=True)
        out = p.stdout + p.stderr
        m = re.search(r"(\d+) of (\d+) tests? failed|(\d+) failed", out)
        if p.returncode != 0:
            fl = re.findall(r"tests/" + re.escape(t) + r":(\d+)", out)
            res.append(f"{t}:{m.group(0) if m else 'fail'} lines={sorted(set(int(x) for x in fl))}")
    for f in fuzz:
        b = subprocess.run([ROC, "build", "--fuzz", f"fuzz/{f}.roc", f"--output={W}/fuzz/m-{f}"], cwd=REPO, env=env, capture_output=True, text=True)
        if b.returncode != 0:
            res.append(f"{f}:build-fail")
            continue
        shutil.rmtree(f"{W}/fuzz/mart-{f}", ignore_errors=True)
        os.makedirs(f"{W}/fuzz/mart-{f}", exist_ok=True)
        r = subprocess.run([f"{W}/fuzz/m-{f}", "run", "--runs=20000", "--seed=1", "--time=0", f"--artifact-dir={W}/fuzz/mart-{f}"], cwd=REPO, env=env, capture_output=True, text=True)
        if r.returncode != 0:
            res.append(f"{f}:fuzz-fail(exit {r.returncode})")
    shutil.copyfile(ORIG, SRC)
    assert filecmp.cmp(SRC, ORIG, shallow=False)
    print(f"{name} || {'; '.join(res) if res else 'NOT CAUGHT'}", flush=True)
