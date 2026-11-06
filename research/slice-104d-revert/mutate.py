#!/usr/bin/env python3
# Revert checks (TW12) of slice 104d against the private reference. Run from the repo root.
import subprocess, shutil, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
REF = "research/slice-104d-revert/reference/Compat.roc"
DST = "packages/records/Compat.roc"
src = open(REF).read()
M = [
 ("R1 source found by a text search", 'if Nullable.read_opt(w.source) != Err(None) or w.source.is_ok() {', 'if text.contains("\\"source\\":") {'),
 ("R1b (same: the row check is removed too)", 'else if w.rows.any(|r| r.source.is_ok()) {', 'else if Bool.False {'),
 ("R2 error_digest optional", "error_digest : Nullable(Str), source", "error_digest : Try(Nullable(Str), [Missing]), source"),
 ("R3 null digest written as empty text", "error_digest: Nullable.write(r.error_digest) }),", "error_digest: Nullable.write(Ok(r.error_digest ?? \"\")) }),"),
 ("R4 sweep written as null", "sweep: Nullable.write_opt(post.sweep),", "sweep: Ok(Nullable.write(post.sweep)),"),
]
for name, old, new in M:
    m = src.replace(old, new)
    if name.startswith("R2"):
        m = m.replace("error_digest: Nullable.read(r.error_digest) }),\n\t\t\t\t\t\tsweep", "error_digest: Nullable.read_opt(r.error_digest) }),\n\t\t\t\t\t\tsweep")
    if m == src:
        print(name, "SKIP"); continue
    open(DST, "w").write(m)
    r = subprocess.run([ROC, "test", "packages/records/tests/w0.roc", "--no-cache"], capture_output=True, text=True)
    out = r.stdout + r.stderr
    st = "COMPILE-ERROR" if "compiler errors" in out and not re.search(r"[1-9]\d* compiler errors|0 compiler", out) or re.search(r"── ✗ (?!fail)", out) else ("CAUGHT" if r.returncode else "NOT CAUGHT")
    print(f"{name} | {st} | {re.findall(r'(\d+) failed', out)}")
shutil.copy(REF, DST)
