#!/usr/bin/env python3
# Revert checks (TW12) of slice 257a: the most tricky behaviors only. Each mutant is one change of the private reference (reference/Tlog.roc);
# the W0 tests of packages/records must fail for each. Run from the repo root, in a capped scope:
#   flock .tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 900 python3 research/slice-257a-revert/mutate.py
# Each `roc test` run has a time limit of 120 s. packages/records/Tlog.roc is put back as it was at the end.
import os, re, subprocess
R = "research/slice-257a-revert/"
D = "packages/records/Tlog.roc"
ref = open(R + "reference/Tlog.roc").read()
keep = open(D).read()
M = [
    ("M1 tlog index is idx (no - 1)", "else (idx - 1).to_u64_try()", "else idx.to_u64_try()"),
    ("M2 a full tile has the suffix .p/256", "if (t.width >= 256) \"\" else", "if (t.width > 256) \"\" else"),
    ("M3 an x before the last group too", "x = if ($i < last) \"x\" else \"\"", "x = if ($i <= last) \"x\" else \"\""),
    ("M4 key id without the 0x0A byte", "concat([10, 1])", "concat([1])"),
    ("M5 signed note without the empty line", "\"${text}\\n— ${name}", "\"${text}— ${name}"),
    ("M6 node hash prefix 0x00 (as a leaf)", "Crypto.SHA256.hash([1].concat(l)", "Crypto.SHA256.hash([0].concat(l)"),
    ("M7 growth writes the partial tile of a level that did not change", "\t\tif co == cn {\n\t\t\t[]", "\t\tif co == cn and cn % 256 == 0 {\n\t\t\t[]"),
    ("M8 MTH splits at the largest power of 2 not above n", "while $k * 2 < n {", "while $k * 2 <= n {"),
    ("M9 bundle length little-endian", "acc.append((e.len() // 256).to_u8_wrap()).append((e.len() % 256).to_u8_wrap())", "acc.append((e.len() % 256).to_u8_wrap()).append((e.len() // 256).to_u8_wrap())"),
    ("M10 base64 decode accepts non-zero padding bits", "if bits.drop_first(whole).any(|b| b != 0) {", "if Bool.False {"),
]
roc_tags = [("cli", os.environ.get("ROC_TAG", "nightly-2026-10-14-38a3029")), ("worker", os.environ.get("ROC_TAG_WORKER", "nightly-2026-11-06-34f137a"))]
env = dict(os.environ, TMPDIR=os.path.abspath(".tmp/tmp"))
def run(roc):
    try:
        r = subprocess.run([roc, "test", "packages/records/tests/w0.roc", "--no-cache"], capture_output=True, text=True, timeout=120, env=env)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 124, "timeout"
try:
    for name, tag in roc_tags:
        roc = f"cloudflare-workers/.cache/nightlies/{tag}/roc"
        open(D, "w").write(ref)
        rc, out = run(roc)
        print(f"{name} {tag}: reference rc={rc} {re.findall(r'All \((\d+)\) tests passed', out)}", flush=True)
        for label, old, new in M:
            if ref.count(old) != 1:
                print(f"  {label} | SKIP (no unique match)", flush=True)
                continue
            open(D, "w").write(ref.replace(old, new))
            rc, out = run(roc)
            comp = "Compilation failed" in out or re.search(r"[1-9]\d* compiler errors", out)
            st = "TIMEOUT" if rc == 124 else "COMPILE-ERROR" if comp else ("CAUGHT" if rc else "NOT CAUGHT")
            print(f"  {label} | {st} | failed={re.findall(r'(\d+) failed', out)}", flush=True)
finally:
    open(D, "w").write(keep)
