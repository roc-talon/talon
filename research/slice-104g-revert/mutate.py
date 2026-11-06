#!/usr/bin/env python3
# Revert checks (TW12) of slice 104g against the private reference. Run from the repo root. Problem.roc of the package is restored at the end.
import subprocess, shutil, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
REF = "research/slice-104g-revert/reference/Problem.roc"
DST = "packages/records/Problem.roc"
keep = open(DST).read()
src = open(REF).read()
M = [
 ("M1 a minimum of a wrong type makes the body BadJson (the original fault)", "Ok(v) => v.minimum\n\t\t\t\t\tErr(_) => Err(Missing)", "Ok(v) => v.minimum\n\t\t\t\t\tErr(_) => return Err(BadJson(\"minimum\"))"),
 ("M2 a text minimum is dropped", "(_, Ok(m), _, _) => Minimum(m)", "(_, Ok(_), _, _) => None"),
 ("M3 a title of a wrong type makes the body BadJson", "Ok(v) => v.title\n\t\t\t\t\tErr(_) => Err(Missing)", "Ok(v) => v.title\n\t\t\t\t\tErr(_) => return Err(BadJson(\"title\"))"),
 ("M4 field and limit are not read together (a bad limit gives limit 0)", "(_, _, Ok(f), Ok(l)) => Limit({ field: f, limit: l })", "(_, _, Ok(f), _) => Limit({ field: f, limit: limit ?? 0 })"),
 ("M5 an issues_url of a wrong type makes the body BadJson", "Ok(v) => v.issues_url\n\t\t\t\t\tErr(_) => Err(Missing)", "Ok(v) => v.issues_url\n\t\t\t\t\tErr(_) => return Err(BadJson(\"issues_url\"))"),
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
