#!/usr/bin/env python3
# Revert checks (TW12) of slice 104i against the private reference. Run from the repo root. Artifact.roc of the package is restored at the end.
import subprocess, shutil, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
REF = "research/slice-104i-revert/reference/Artifact.roc"
DST = "packages/records/Artifact.roc"
keep = open(DST).read()
src = open(REF).read()
W = "url: d.url, is_platform: d.is_platform }"
M = [
 ("M1 encode always writes false", "series: Nullable.write(d.series), version: Nullable.write(d.version), " + W, "series: Nullable.write(d.series), version: Nullable.write(d.version), url: d.url, is_platform: Bool.False }"),
 ("M2 encode writes the mark inverted", "series: Nullable.write(d.series), version: Nullable.write(d.version), " + W, "series: Nullable.write(d.series), version: Nullable.write(d.version), url: d.url, is_platform: !d.is_platform }"),
 ("M3 decode drops the mark (always false)", "series: Nullable.read(d.series), version: Nullable.read(d.version), " + W, "series: Nullable.read(d.series), version: Nullable.read(d.version), url: d.url, is_platform: Bool.False }"),
 ("M4 the mark is optional on decode (missing is false)", "url : Str, is_platform : Bool }\n\tWire", "url : Str, is_platform : Try(Bool, [Missing]) }\n\tWire"),
]
def run():
    r = subprocess.run([ROC, "test", "packages/records/tests/w0.roc", "--no-cache"], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr
shutil.copy(REF, DST)
rc, out = run(); print("reference rc", rc, re.findall(r"All \((\d+)\)", out))
for name, old, new in M:
    if src.count(old) != 1: print(name, "SKIP", src.count(old)); continue
    m = src.replace(old, new)
    if name.startswith("M4"):
        m = m.replace("url: d.url, is_platform: d.is_platform }),\n\t\ttarget_names: r.target_names.sort_with(compare)", "url: d.url, is_platform: Ok(d.is_platform) }),\n\t\ttarget_names: r.target_names.sort_with(compare)").replace("url: d.url, is_platform: d.is_platform }),\n\t\t\ttarget_names: w.target_names", "url: d.url, is_platform: d.is_platform ?? Bool.False }),\n\t\t\ttarget_names: w.target_names")
    open(DST, "w").write(m)
    rc, out = run()
    comp = re.search(r"(\d+) compiler errors", out)
    st = "COMPILE-ERROR" if "Compilation failed" in out or (comp and comp.group(1) != "0") else ("CAUGHT" if rc else "NOT CAUGHT")
    print(f"{name} | {st} | failed={re.findall(r'(\d+) failed', out)}")
open(DST, "w").write(keep)
