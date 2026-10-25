#!/usr/bin/env python3
"""Revert check of slice 042 (code agent). One small break at a time, only the test that must see it.
Run from the repo root: python3 research/slice-042-revert/agent-mutate.py
Each file is put back from research/slice-042-revert/code-final/ after each run, and the sha256 file is checked at the end."""
import os, shutil, subprocess, sys

ROOT = os.getcwd()
FINAL = "research/slice-042-revert/code-final"
ROC = "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
UNIT = lambda f: [ROC, "test", f"tests/unit/{f}.roc"]
L2 = ["scripts/test.sh", "l2"]
L1 = ["scripts/test.sh", "l1"]

# (id, file, old text, new text, test command, what the break is)
M = [
    ("P1", "cli/lib/Diff.roc", "i - g.last <= 7", "i - g.last <= 8", UNIT("diff"), "7 kept lines between 2 runs of changes are one hunk"),
    ("P2", "cli/lib/Diff.roc", "len: g.last + 4 - start", "len: g.last + 3 - start", UNIT("diff"), "2 lines of context after the last change"),
    ("P3", "cli/lib/Diff.roc", "if !$found or d < $dist {", "if !$found or d <= $dist {", UNIT("diff"), "2 places at the same distance: the last one wins"),
    ("P4", "cli/lib/Diff.roc", "if $p.to_i64_wrap() >= spot.wanted {\n\t\t\t\tbreak", "if Bool.True {\n\t\t\t\tbreak", UNIT("diff"), "the first place wins, not the nearest"),
    ("P5", "cli/lib/Diff.roc", "Err(NoFit) => Err(path)", "Err(NoFit) => Ok({ path, what: Write(text) })", UNIT("diff"), "a hunk that does not fit is skipped, the file is written"),
    ("P6", "cli/lib/Diff.roc", 'else "${prefix}${text}\\n\\\\ No newline at end of file\\n"', 'else "${prefix}${text}\\n"', UNIT("diff"), "no marker after a line with no line end"),
    ("P7", "cli/lib/Diff.roc", "Ok(_) => Err(file.path)", "Ok(_) => Ok(written(file.path, file.content))", UNIT("diff"), "an Add overwrites a file that the target has"),
    ("P8", "cli/lib/Diff.roc", "cell($i, $j - 1) >= cell($i - 1, $j)", "cell($i, $j - 1) > cell($i - 1, $j)", UNIT("diff"), "inserted lines come before deleted lines of a run"),
    ("P8b", "cli/lib/Diff.roc", "cell($i, $j - 1) >= cell($i - 1, $j)", "cell($i, $j - 1) > cell($i - 1, $j)", L1, "the same, seen by the L1 target"),
    ("P9", "cli/lib/PatchFlow.roc", "_ => return Err(PatchCmd.exists(place.dir))", "_ => {}", L2, "an existing copy dir is overwritten"),
    ("P10", "cli/lib/PatchCmd.roc", "if row.is_platform {", "if Bool.False {", UNIT("removal"), "the platform is copied"),
    ("P11", "cli/lib/Listing.roc", "row.direct and patched.contains(row.alias)", "patched.contains(row.alias)", UNIT("listing"), "a package that no header names has the mark patched"),
    ("P12", "cli/lib/PatchFlow.roc", "base: facts.target.hash })?", "base: facts.target.url })?", L2, "the base of the entry is not the hash"),
    ("P13", "cli/lib/IntentEdit.roc", 'if facts.text == "" {', "if Bool.False {", UNIT("intent"), "the first entry of a new file is [patch.json]"),
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

sha = subprocess.run(["sha256sum", "-c", "research/slice-042-revert/code-final.sha256"], capture_output=True, text=True)
print(sha.stdout, sha.stderr)
with open("research/slice-042-revert/agent-results.md", "w") as f:
    f.write("# Revert check of slice 042 (code agent)\n\n| Id | Mutation | Result |\n| --- | --- | --- |\n")
    for r in rows:
        f.write("| %s | %s | %s |\n" % r)
    f.write("\nCode after the runs: %s\n" % ("same as code-final (sha256sum -c: all OK)" if sha.returncode == 0 else "DIFFERENT: " + sha.stdout))
sys.exit(0 if sha.returncode == 0 else 1)
