#!/usr/bin/env python3
# Revert check (TW12) for slice 104. Run from the repo root: python3 research/slice-104-revert-check/mutate.py
# One mutation at a time. The file is restored from keep/ after each run.
import subprocess, shutil, os, re
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
PKG = "packages/records"
KEEP = "research/slice-104-revert-check/keep"
OUT = "research/slice-104-revert-check/out"
M = [
 ("M1 null written as an absent member (write_opt for tag)", "Release.roc", "tag: Nullable.write(r.tag),", "tag: Nullable.write_opt(r.tag),"),
 ("M2 null rejected on decode (Nullable.parser_for reads inner first)", "Nullable.roc", "Ok(rest) => Ok({ value: Nullable.(Err(None)), rest })", "Ok(_) => {\n\t\t\t\tparsed = inner(state)?\n\t\t\t\tOk({ value: Nullable.(Ok(parsed.value)), rest: parsed.rest })\n\t\t\t}"),
 ("M3 deps not sorted by alias", "Artifact.roc", "r.deps.sort_with(|a, b| compare(a.alias, b.alias)).map(", "r.deps.map("),
 ("M4 target_names not sorted", "Artifact.roc", "target_names: r.target_names.sort_with(compare),", "target_names: r.target_names,"),
 ("M5 unknown kind accepted as app", "Artifact.roc", 'other => Err(BadJson("unknown kind ${other}"))', "other => Ok(App)"),
 ("M6 upper-case sha accepted", "Id.roc", "else if (b >= 97 and b <= 102) Ok(b - 87)", "else if (b >= 97 and b <= 102) Ok(b - 87) else if (b >= 65 and b <= 70) Ok(b - 55)"),
 ("M7 6-digit sha accepted", "Id.roc", "if bytes.len() == 7 {", "if bytes.len() == 7 or bytes.len() == 6 {"),
 ("M8 2026-02-30 accepted (February has 30 days)", "Id.roc", "if (leap) 29 else 28", "if (leap) 30 else 30"),
 ("M9 target code 11 to 20 off by one", "Code.roc", "hit: if (n == name) Ok(acc.i) else acc.hit", "hit: if (n == name) Ok(if (acc.i >= 11 and acc.i <= 20) acc.i + 1 else acc.i) else acc.hit"),
 ("M10 unknown problem type rejected (R-AP52)", "Problem.roc", "\t\t\tOk(w) => {\n\t\t\t\textra", "\t\t\tOk(w) if kind_from_uri(w.type).is_err() => Err(BadJson(\"unknown type\"))\n\t\t\tOk(w) => {\n\t\t\t\textra"),
 ("M11 unknown repo state accepted (R-AP51)", "Closure.roc", 'other => Err(bad("state", other))\n\t\t\t\t}?\n\t\t\t\tOk({ name: r.name', 'other => Ok(Active)\n\t\t\t\t}?\n\t\t\t\tOk({ name: r.name'),
 ("M12 ms time wrong (state_at times 1000 on encode)", "Closure.roc", "\t\tstate_at: r.state_at,\n\t})", "\t\tstate_at: r.state_at * 1000,\n\t})"),
 ("M13 missing title accepted as empty is the code (control: title required)", "Problem.roc", 'title: w.title ?? ""', 'title: w.title ?? "x"'),
]
for name, f, old, new in M:
    p = f"{PKG}/{f}"
    src = open(f"{KEEP}/{f}").read()
    n = src.count(old)
    if n != 1:
        print(f"{name}: SKIP, pattern found {n} times"); continue
    line = src[:src.index(old)].count("\n") + 1
    open(p, "w").write(src.replace(old, new))
    r = subprocess.run([ROC, "test", f"{PKG}/tests/w0.roc", "--no-cache"], capture_output=True, text=True)
    out = r.stdout + r.stderr
    open(f"{OUT}/{name.split()[0]}.txt", "w").write(out)
    shutil.copy(f"{KEEP}/{f}", p)
    fails = sorted(set(re.findall(r"(?:FAILED|failed)[^\n]*", out)))[:3]
    status = "COMPILE-ERROR" if re.search(r"error|ERROR", out) and not re.search(r"\d+ failed|FAILED", out) else ("CAUGHT" if r.returncode != 0 else "NOT CAUGHT")
    print(f"{name} | {f}:{line} | {status} | rc={r.returncode}")
