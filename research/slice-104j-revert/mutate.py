#!/usr/bin/env python3
# Revert checks (TW12) of slice 104j against the private reference. Run from the repo root. Problem.roc of the package is restored at the end.
import subprocess, shutil, re
REF = "research/slice-104j-revert/reference/Problem.roc"
DST = "packages/records/Problem.roc"
keep = open(DST).read()
src = open(REF).read()
M = [
 ("M1 busy has status 500", 'Busy => (k, "/errors/busy", 503)', 'Busy => (k, "/errors/busy", 500)'),
 ("M2 busy has the type of internal", 'Busy => (k, "/errors/busy", 503)', 'Busy => (k, "/errors/internal", 503)'),
 ("M3 kind_from_uri does not know busy", "RateLimited, Internal, Upstream, Busy]", "RateLimited, Internal, Upstream]"),
]
for tag in ("nightly-2026-10-14-38a3029", "nightly-2026-10-31-f7bef6b"):
    roc = f"cloudflare-workers/.cache/nightlies/{tag}/roc"
    def run():
        r = subprocess.run([roc, "test", "packages/records/tests/w0.roc", "--no-cache"], capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr
    shutil.copy(REF, DST)
    rc, out = run(); print(tag, "reference rc", rc, re.findall(r"All \((\d+)\)", out))
    for name, old, new in M:
        if src.count(old) != 1: print(name, "SKIP", src.count(old)); continue
        open(DST, "w").write(src.replace(old, new))
        rc, out = run()
        comp = re.search(r"(\d+) compiler errors", out)
        st = "COMPILE-ERROR" if "Compilation failed" in out or (comp and comp.group(1) != "0") else ("CAUGHT" if rc else "NOT CAUGHT")
        print(f"  {name} | {st} | failed={re.findall(r'(\d+) failed', out)}")
open(DST, "w").write(keep)
