#!/usr/bin/env python3
# Revert checks (TW12) of slice 104f against the private reference. Run from the repo root.
import subprocess, shutil, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
REF = "research/slice-104f-revert/reference/Compat.roc"
DST = "packages/records/Compat.roc"
src = open(REF).read()
M = [
 ("A answer members in alphabetical order", 'encode_hint_answer = |a| {', 'encode_hint_answer = |a| Json.to_str(a)\n\tunused_hint_answer = |a| {'),
 ("B hint post accepts error_digest in a row", '\t\t\t\tif (w.rows.any(|r| r.error_digest.is_ok())) return Err(BadJson("member error_digest is not allowed in a row"))\n', ''),
 ("C answer item has reason before row", '"{\\"row\\":${s.row.to_str()},\\"reason\\":${Json.to_str(s.reason)}}"', '"{\\"reason\\":${Json.to_str(s.reason)},\\"row\\":${s.row.to_str()}}"'),
 ("D publish fact accepts hash", '\t\t\t\tif (facts.map_ok(|fs| fs.any(|f| f.hash.is_ok())) == Ok(Bool.True)) return Err(BadJson("member hash is not allowed in a fact"))\n', ''),
 ("E publish writes compat null for none", 'compat: Nullable.write_opt(p.compat.map_ok(|fs| fs.map(|f| { nightly: f.nightly, target: f.target, result: f.result, error_digest: Nullable.write(f.error_digest) }))),', 'compat: Ok(Nullable.write(p.compat.map_ok(|fs| fs.map(|f| { nightly: f.nightly, target: f.target, result: f.result, error_digest: Nullable.write(f.error_digest) })))),'),
 ("F answer leaves out empty skipped", '\\"skipped\\":[${Str.join_with(items, ",")}]}"', '${if items.is_empty() "" else ",\\"skipped\\":[${Str.join_with(items, ",")}]"}}"'),
 ("G hint post accepts sweep", '\t\t\t\tif (w.sweep.is_ok()) return Err(BadJson("member sweep is for the compat bot"))\n', ''),
]
for name, old, new in M:
    if src.count(old) != 1:
        print(name, "SKIP", src.count(old)); continue
    m = src.replace(old, new)
    if name.startswith("F"):
        m = m.replace('"{\\"written\\":${a.written.to_str()},\\"first\\":${a.first.to_str()},', '"{\\"written\\":${a.written.to_str()},\\"first\\":${a.first.to_str()}')
    open(DST, "w").write(m)
    r = subprocess.run([ROC, "test", "packages/records/tests/w0.roc", "--no-cache"], capture_output=True, text=True)
    out = r.stdout + r.stderr
    comp = re.search(r"(\d+) compiler errors", out)
    st = "COMPILE-ERROR" if (comp and comp.group(1) != "0") or "Compilation failed" in out else ("CAUGHT" if r.returncode else "NOT CAUGHT")
    print(f"{name} | {st} | failed={re.findall(r'(\d+) failed', out)}")
shutil.copy(REF, DST)
