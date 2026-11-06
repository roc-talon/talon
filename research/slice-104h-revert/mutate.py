#!/usr/bin/env python3
# Revert checks (TW12) of slice 104h against the private reference. Run from the repo root. Toolchain.roc of the package is restored at the end.
import subprocess, shutil, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
REF = "research/slice-104h-revert/reference/Toolchain.roc"
DST = "packages/records/Toolchain.roc"
keep = open(DST).read()
src = open(REF).read()
M = [
 ("M1 size after published_at", '\\"sha256\\":${sha},\\"size\\":${r.size.to_str()},\\"published_at\\":${r.published_at.to_str()},', '\\"sha256\\":${sha},\\"published_at\\":${r.published_at.to_str()},\\"size\\":${r.size.to_str()},'),
 ("M2 size written as text", '\\"size\\":${r.size.to_str()}', '\\"size\\":\\"${r.size.to_str()}\\"'),
 ("M3 size written from log_index", '\\"size\\":${r.size.to_str()}', '\\"size\\":${r.log_index.to_str()}'),
 ("M4 a url member is written", '\\"size\\":${r.size.to_str()},', '\\"size\\":${r.size.to_str()},\\"url\\":\\"u\\",'),
]
def run():
    r = subprocess.run([ROC, "test", "packages/records/tests/w0.roc", "--no-cache"], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr
shutil.copy(REF, DST)
rc, out = run(); print("reference rc", rc, re.findall(r"All \((\d+)\)", out))
for name, old, new in M:
    if src.count(old) != 1: print(name, "SKIP", src.count(old)); continue
    open(DST, "w").write(src.replace(old, new))
    rc, out = run()
    comp = re.search(r"(\d+) compiler errors", out)
    st = "COMPILE-ERROR" if "Compilation failed" in out or (comp and comp.group(1) != "0") else ("CAUGHT" if rc else "NOT CAUGHT")
    print(f"{name} | {st} | failed={re.findall(r'(\d+) failed', out)}")
open(DST, "w").write(keep)
