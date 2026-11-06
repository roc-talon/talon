#!/usr/bin/env python3
# Revert checks (TW12) of slice 104e against the private reference. Run from the repo root.
# The Compat.roc of the 104f reference is put in the package during the run, so the baseline has no failed test. All files are restored at the end.
import subprocess, shutil, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
REFD = "research/slice-104e-revert/reference/"
PKG = "packages/records/"
saved = open(PKG + "Compat.roc").read()
shutil.copy("research/slice-104f-revert/reference/Compat.roc", PKG + "Compat.roc")
def put(name, text): open(PKG + name, "w").write(text)
for n in ["Index", "Toolchain", "Short", "Account"]: shutil.copy(f"{REFD}{n}.roc", f"{PKG}{n}.roc")
M = [
 ("M1 Index.Releases: checked before releases", "Index.roc", '"{\\"releases\\":${releases_text(a.releases)},\\"checked\\":${checked},\\"repos\\":${repos_text(a.repos)}}"', '"{\\"checked\\":${checked},\\"releases\\":${releases_text(a.releases)},\\"repos\\":${repos_text(a.repos)}}"'),
 ("M2 Toolchain row in alphabetical order", "Toolchain.roc", "encode_row = |r| \"{\\\"tag\\\"", "encode_row = |r| Json.to_str(r)\n\n\tunused_row = |r| \"{\\\"tag\\\""),
 ("M3 Short: moved_from written as null for none", "Short.roc", 'Err(None) => ""\n\t\t}\n\t\t"{\\"first_log_index\\"', 'Err(None) => ",\\"moved_from\\":null"\n\t\t}\n\t\t"{\\"first_log_index\\"'),
 ("M4 Index.Releases: checked none written as []", "Index.roc", 'Err(None) => "null"', 'Err(None) => "[]"'),
 ("M5 Account tracker: last_time optional", "Account.roc", "last_time : Nullable(U64) }", "last_time : Try(Nullable(U64), [Missing]) }"),
 ("M6 Short: unknown state read as active", "Short.roc", 'other => Err(BadJson("unknown state ${other}"))', "_ => Ok(Active)"),
 ("M7 Index.Page: repos before releases", "Index.roc", '"{\\"releases\\":${releases_text(a.releases)},\\"repos\\":${repos_text(a.repos)}}"\n\n\tdecode_page', '"{\\"repos\\":${repos_text(a.repos)},\\"releases\\":${releases_text(a.releases)}}"\n\n\tdecode_page'),
]
def run():
    r = subprocess.run([ROC, "test", PKG + "tests/w0.roc", "--no-cache"], capture_output=True, text=True)
    out = r.stdout + r.stderr
    return r.returncode, out
rc, out = run()
print("baseline rc", rc, re.findall(r"(\d+) (?:passed|failed)", out))
for name, f, old, new in M:
    src = open(f"{REFD}{f}").read()
    if src.count(old) != 1: print(name, "SKIP", src.count(old)); continue
    m = src.replace(old, new)
    if name.startswith("M5"):
        m = m.replace("last_time: Nullable.read(w.last_time) }", "last_time: Nullable.read_opt(w.last_time) }").replace("last_time: Nullable.write(t.last_time) }", "last_time: Nullable.write_opt(t.last_time) }")
    put(f, m)
    rc, out = run()
    comp = re.search(r"(\d+) compiler errors", out)
    st = "COMPILE-ERROR" if "Compilation failed" in out or (comp and comp.group(1) != "0") else ("CAUGHT" if rc else "NOT CAUGHT")
    print(f"{name} | {st} | failed={re.findall(r'(\d+) failed', out)}")
    shutil.copy(f"{REFD}{f}", PKG + f)
open(PKG + "Compat.roc", "w").write(saved)
