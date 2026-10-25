#!/usr/bin/env python3
"""Revert check of slice 043 (code agent). One small break at a time, only the test that must see it.
Run from the repo root: python3 research/slice-043-revert/agent-mutate.py
Each file is put back from research/slice-043-revert/code-final/ after each run, and the sha256 file is checked at the end."""
import os, shutil, subprocess, sys

ROOT = os.getcwd()
FINAL = "research/slice-043-revert/code-final"
ROC = "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
UNIT = lambda f: [ROC, "test", f"tests/unit/{f}.roc"]
L3 = ["scripts/test.sh", "l3"]
L2 = ["scripts/test.sh", "l2"]
L1 = ["scripts/test.sh", "l1"]

# (id, file, old text, new text, test command, what the break is)
M = [
    ("A1", "cli/lib/Vars.roc", "free = indexed and (is_named or (all and !variable.patched))", "free = indexed and (all or is_named)", UNIT("l0-2"), "update with no names frees a patched entry"),
    ("A2", "cli/lib/Vars.roc", "!free and variable.host == Indexed and !variable.patched and", "!free and variable.host == Indexed and", UNIT("l0-2"), "a held patched entry is movable"),
    ("A3", "cli/lib/Patched.roc", "(url != e.url or install)", "(url != e.url)", UNIT("l0-1"), "tln install does not rebase a stale patch (Patched.need)"),
    ("A4", "cli/lib/Patched.roc", "if applied.failed.is_empty() Ok(applied.done) else Err(applied.failed)", "Ok(applied.done)", UNIT("l0-1"), "a diff that does not apply is no failure"),
    ("A5", "cli/lib/InstallFlow.roc", "if !stale.is_empty() {\n\t\treturn Err(Patched.stale_fail({ entries: stale, by: Frozen }))", "if stale.is_empty() and !stale.is_empty() {\n\t\treturn Err(Patched.stale_fail({ entries: stale, by: Frozen }))", L2, "install --frozen has no stale check (exit 14)"),
    ("A6", "cli/lib/Proxy.roc", "if !off and !loaded.patch.stale.is_empty() {", "if loaded.patch.stale.is_empty() and !loaded.patch.stale.is_empty() {", L2, "the proxy does not stop on a stale patch"),
    ("A6b", "cli/lib/Proxy.roc", "if !off and !loaded.patch.stale.is_empty() {", "if loaded.patch.stale.is_empty() and !loaded.patch.stale.is_empty() {", L3, "the proxy does not stop on a stale patch (real launcher)"),
    ("A7", "cli/lib/Proxy.roc", "if !off and !loaded.patch.stale.is_empty() {", "if !loaded.patch.stale.is_empty() {", L2, "TALON_PROXY=0 checks a stale patch"),
    ("A8", "cli/lib/LadderPlan.roc", "if i == 0 more(spec, x.base) else more(spec, x.candidate)", "more(spec, x.candidate)", UNIT("l0-1"), "the baseline check gets the pairs of the candidate"),
    ("A9", "cli/lib/Patched.roc", "x.args.take_first(i).concat(flags).concat(x.args.drop_first(i))", "x.args.concat(flags)", UNIT("l0-1"), "the proxy flags go after --"),
    ("A10", "cli/lib/InstallWrite.roc", "IntentEdit.spans({ text, keys }).concat(IntentEdit.table_spans({ text, keys: patch_keys }))", "IntentEdit.spans({ text, keys })", L2, "the Guard of the base write has no span of the [patch] entry"),
    ("A11", "cli/lib/PatchApply.roc", "\t\t\tif !request.dry_run {", "\t\t\tif Bool.True {", L2, "--dry-run replaces the copy"),
    ("A12", "cli/lib/PatchApply.roc", "dirs: [cached(entry.base), entry.dir, cached(found.hash)]", "dirs: [cached(found.hash), entry.dir, cached(found.hash)]", L2, "the diff is made against the new release, not the base"),
    ("A13", "cli/lib/InstallWrite.roc", "base: r.hash }))", "base: r.entry.base }))", L2, "base is not set to the new hash"),
    ("A14", "cli/lib/PatchApply.roc", "Ok(m) => { old: m.found.url, new: Text.join(m.temp, Text.last_segment(e.file)) }", "Ok(_) => { old: e.url, new: e.file }", L2, "the candidate probes get the copy, not the temp tree"),
    ("A15", "cli/lib/PatchApply.roc", "Ok(root) => {\n\t\t\t_ = fx.delete!([root])\n\t\t}", "Ok(_) => {}", L2, "the temp root is not deleted"),
]

def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    return p.returncode, (p.stdout + p.stderr)

rows = []
only = sys.argv[1:]
for mid, path, old, new, cmd, what in M:
    if only and mid not in only:
        continue
    src = open(os.path.join(FINAL, path)).read()
    if src.count(old) != 1:
        rows.append((mid, what, "BAD MUTATION: old text found %d times" % src.count(old)))
        continue
    open(path, "w").write(src.replace(old, new))
    try:
        rc, out = run(cmd)
    finally:
        shutil.copyfile(os.path.join(FINAL, path), path)
    lines = [l for l in out.splitlines() if l.strip()]
    if rc == 0:
        verdict = "NOT CAUGHT"
    elif "error" in out.lower() and ("compile" in out.lower() or "──" in out) and "FAIL" not in out and "failed" not in out.lower().replace("0 failed", ""):
        verdict = "DID NOT COMPILE (check)"
    else:
        verdict = "caught (exit %d)" % rc
    rows.append((mid, what, verdict + " by " + " ".join(cmd[-2:])))
    print(mid, verdict, flush=True)

sha = subprocess.run(["sha256sum", "-c", "research/slice-043-revert/code-final.sha256"], capture_output=True, text=True)
print(sha.stdout, sha.stderr)
with open("research/slice-043-revert/agent-results.md", "w") as f:
    f.write("# Revert check of slice 043 (code agent)\n\n| Id | Mutation | Result |\n| --- | --- | --- |\n")
    for r in rows:
        f.write("| %s | %s | %s |\n" % r)
    f.write("\nCode after the runs: %s\n" % ("same as code-final (sha256sum -c: all OK)" if sha.returncode == 0 else "DIFFERENT: " + sha.stdout))
sys.exit(0 if sha.returncode == 0 else 1)
