#!/usr/bin/env python3
"""Gap tests of slice 056 (TESTING.md 7.1 step 5): one hand mutation of the code for each gap test, filtered runs, then the live files are put back and compared with code-final/.
Run from the repo root: python3 research/slice-056-revert/gap-mutate.py [name ...]. The result goes to research/slice-056-revert/gap-results.md."""
import subprocess, sys, glob, os

BASE = "research/slice-056-revert"
M = [
    ("G1-update-header-name", "InstallFlow", "phase: if split.tools.is_empty() Err(None) else Ok(phase)", "phase: Ok(phase)", "pt3-move"),
    ("G2-gc-read-package-only", "CacheGc", "(!expired([]).is_empty() or !open.pkgs.is_empty())", "(!open.pkgs.is_empty())", "gc6-held-no-package"),
    ("G3-held-uses-read-table", "ToolsPlan",
     'hashes_of = |doc| match Toml.get(doc, ["tools"]) {\n\tOk(Value.Table(tools)) => tools.to_list().keep_oks(\n\t\t|(_, entry)| match entry {\n\t\t\tValue.Table(fields) => match fields.get("url") {\n\t\t\t\tOk(Value.String(url)) => Ident.of_url(url).map_ok(|ident| ident.hash).map_err(|Foreign| NoHash)\n\t\t\t\t_ => Err(NoHash)\n\t\t\t}\n\t\t\t_ => Err(NoHash)\n\t\t},\n\t)\n\t_ => []\n}',
     'hashes_of = |doc| ToolsToml.read_table(doc).value.keep_oks(\n\t|e| match e.url {\n\t\tOk(url) => Ident.of_url(url).map_ok(|ident| ident.hash).map_err(|Foreign| NoHash)\n\t\tErr(Unset) => Err(NoHash)\n\t},\n)', "L0"),
]
want = sys.argv[1:]
log = open(f"{BASE}/gap-results.md", "a")


def run(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def same():
    return all(open(f).read() == open("cli/lib/" + os.path.basename(f)).read() for f in glob.glob(f"{BASE}/code-final/*.roc"))


for name, mod, old, new, tests in M:
    if want and name not in want:
        continue
    path = f"cli/lib/{mod}.roc"
    original = open(path).read()
    assert original.count(old) == 1, (name, original.count(old))
    open(path, "w").write(original.replace(old, new))
    try:
        rc, out = run(f"{BASE}/chk.sh 5")
        if "No errors found" not in out:
            line = f"{name}: does not compile: {out[:200]}"
        elif tests == "L0":
            l0 = run(f"{BASE}/l0.sh l0-8.roc 400")[1]
            line = f"{name}: l0={'caught' if 'failed' in l0 and ' 0 failed' not in l0 else 'MISSED'}"
        else:
            l2 = run(f"tests/commands/run.sh {tests}")[1]
            fails = [l.strip() for l in l2.split("\n") if l.startswith("FAIL")]
            line = f"{name}: l2={fails or 'MISSED'}"
    finally:
        open(path, "w").write(original)
    line += f" | live files equal code-final: {same()}"
    print(line)
    log.write(line + "\n")
    log.flush()
