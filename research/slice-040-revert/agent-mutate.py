#!/usr/bin/env python3
"""Revert check of the code agent for slice 040 (TW12). Run from anywhere.
Usage: agent-mutate.py M1 [M2 ...]   (only the ids that you name run)
For each id: restore code-final, change the code in one small way, run the named tests, restore code-final.
Tests: l0 = roc test tests/unit/outdated.roc, l2 = tests/commands/run.sh outdated.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-040-revert/code-final")
FILES = ["cli/lib/Outdated.roc", "cli/lib/OutdatedFlow.roc", "cli/lib/Pick.roc", "cli/lib/Ls.roc"]
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")

# id: (file, old, new, tests, text)
M = {
    "M1": ("cli/lib/Outdated.roc", "slot(x.ranges, Index.in_group", "slot([], Index.in_group", ["l0", "l2"], "wanted ignores the ranges"),
    "M2": ("cli/lib/Outdated.roc", "ctx = { now: x.now, min_age: x.min_age,", "ctx = { now: x.now, min_age: 0,", ["l0", "l2"], "min-release-age hides nothing"),
    "M3": ("cli/lib/Outdated.roc", "x.list.keep_if(|c| c.ident.group.form == current.group.form)", "x.list.keep_if(|c| c.ident.group == current.group)", ["l0", "l2"], "latest stays in the series of current"),
    "M4": ("cli/lib/Outdated.roc", "row.current != row.wanted or row.current != row.latest", "row.current != row.wanted", ["l0", "l2"], "behind ignores latest"),
    "M5": ("cli/lib/OutdatedFlow.roc", "releases = if behind.is_empty() []", "releases = if shown.is_empty() []", ["l2"], "the compiler list is read also when no row is behind"),
    "M6": ("cli/lib/OutdatedFlow.roc", "built = Vars.build({ members: loaded.members, priority", "built = Vars.build({ members: loaded.members.keep_if(|m| start.project.file.is_err() or Ok(m.file) == start.project.file), priority", ["l2"], "Vars.build over the shown members only (Q8)"),
    "M7": ("cli/lib/Outdated.roc", "if end.real end.id else \"${end.id}?\"", "end.id", ["l0", "l2"], "an end that is no real fact has no ?"),
    "M8": ("cli/lib/OutdatedFlow.roc", "shown = (if named.is_empty() loaded.members else named).map(|m| m.file)", "shown = (if named.is_empty() loaded.members else loaded.members).map(|m| m.file)", ["l2"], "the current member does not limit the members"),
    "M15": ("cli/lib/OutdatedFlow.roc", "(Ok(name), Ok(first)) => {", "(Ok(name), Ok(_)) => {\n\t\tfirst = v.uses.first() ?? { file, alias: \"\", url: \"\", version: \"\" }", ["l2"], "alias and current are of the first use of any member"),
    "M9": ("cli/lib/OutdatedFlow.roc", "	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?\n", "", ["l2"], "the project is not recorded"),
    "M10": ("cli/lib/OutdatedFlow.roc", "names = vars.keep_oks(|v| indexed_name(v))", "names = built.vars.keep_oks(|v| indexed_name(v))", ["l2"], "the index is read for the groups of members that are not shown"),
    "M11": ("cli/lib/OutdatedFlow.roc", "fixed: hosts.fold([], |seen, host| if seen.contains(host) seen else seen.append(host))", "fixed: hosts", ["l2"], "a fixed host that 2 groups have is listed twice"),
    "M12": ("cli/lib/Outdated.roc", "Known(NoPass) => \"none known\"", "Known(NoPass) => \"-\"", ["l0", "l2"], "no real pass gives - in place of none known"),
    "M13": ("cli/lib/Outdated.roc", "x.domain.is_empty() Unread", "x.domain.is_empty() Known(NoPass)", ["l0", "l2"], "an empty compiler list gives none known in place of -"),
    "M14": ("cli/lib/Outdated.roc", "cell.concat(\" \".repeat(width + 2 -", "cell.concat(\" \".repeat(width + 1 -", ["l0", "l2"], "the padding is 1 space"),
}

def restore():
    for f in FILES:
        shutil.copyfile(os.path.join(FINAL, f), os.path.join(ROOT, f))

def run(cmd, limit):
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=limit)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return 124, "timed out"

def main():
    env = os.environ
    for mid in sys.argv[1:]:
        f, old, new, tests, text = M[mid]
        restore()
        path = os.path.join(ROOT, f)
        src = open(path).read()
        if src.count(old) != 1:
            print(f"{mid}: old text found {src.count(old)} times"); continue
        open(path, "w").write(src.replace(old, new))
        results = []
        for t in tests:
            if t == "l0":
                rc, out = run(["bash", "-c", f". scripts/env.sh && {ROC} test tests/unit/outdated.roc --no-cache"], 120)
            else:
                rc, out = run(["bash", "-c", "tests/commands/run.sh outdated"], 300)
            compile_error = "compile" in out.lower() and rc != 0 and "passed" not in out and "FAIL" not in out and "fail" not in out.split("\n")[0].lower()
            results.append(f"{t}: {'pass' if rc == 0 else 'FAIL(rc=' + str(rc) + ')'}")
            tail = "\n".join(out.strip().split("\n")[-6:])
            print(f"--- {mid} {t} rc={rc}\n{tail}")
        print(f"=== {mid} ({text}): " + ", ".join(results), flush=True)
    restore()

main()
