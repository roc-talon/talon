#!/usr/bin/env python3
"""Revert check of slice 048 (test agent): 10 mutations of the private reference (installed in cli/lib by reference.sh) on the most tricky behaviors. Each mutation breaks one file in one small way,
runs only the test that must see it, prints the result and puts the file back. Run from the repo root: sh research/slice-048-revert/reference.sh; python3 research/slice-048-revert/mutants.py [number ...]
After the run: sh research/slice-048-revert/restore.sh (stubs back). Never a full sweep."""
import os, re, subprocess, sys

ROOT = os.getcwd()
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
L0_3 = f"XDG_CACHE_HOME=$PWD/.work/cache ROC_CACHE_DIR=$PWD/.work/cache/roc {ROC} test tests/unit/l0-3.roc"
L0_4 = f"XDG_CACHE_HOME=$PWD/.work/cache ROC_CACHE_DIR=$PWD/.work/cache/roc {ROC} test tests/unit/l0-4.roc"
UF = "cli/lib/ToolUpdateFlow.roc"
MF = "cli/lib/ToolManageFlow.roc"
GF = "cli/lib/ToolGitFlow.roc"
U = "cli/lib/ToolUpdate.roc"
G = "cli/lib/ToolGit.roc"

# (number, what, file, [(old, new)], command, the test that must see it)
M = [
    (1, "rebuild builds with the pin of the header, not the compiler of tools.json (R-T5)", UF,
     [("Ok(Build({ tool, facts, bundle, id: tool.nightly, temp: Err(None), how: Rebuilt }))", "Ok(Build({ tool, facts, bundle, id: bundle.pin ?? tool.nightly, temp: Err(None), how: Rebuilt }))")],
     "tests/commands/run.sh tool/tr1-rebuild", "L2 tr1 run 1 (the compiler of the build, and the line)"),
    (2, "update of a commit asks for the head (R-T24: no change, no request)", UF,
     [("\tCommit => Ok(settled(tool, Pinned))", "\tCommit => {\n\t\t_ = ToolGitFlow.head!(fx, facts.net, git_source(tool)?, facts.now)\n\t\tOk(settled(tool, Pinned))\n\t}")],
     "tests/commands/run.sh tool/tu1-update", "L2 tu1 run 6 (calls.log)"),
    (3, "update builds a branch tool when the head is the installed commit (R-T24)", UF,
     [("ToolUpdate.moved({ tool, sha })", "ToolUpdate.moved({ tool, sha: \"x\" })")],
     "tests/commands/run.sh tool/tu1-update", "L2 tu1 run 3 (gs is rebuilt)"),
    (4, "rm deletes a bin dir entry that is not Talon's (R-ST6, R-B6)", MF,
     [("\t\t_ => [data_file]", "\t\t_ => [entry, data_file]")],
     "tests/commands/run.sh tool/tm1-manage", "L2 tm1 runs 8, 9 (tree.diff)"),
    (5, "rm writes tools.json before it deletes the files (R-B6, order)", MF,
     [("\tfor result in fx.delete!(paths) {", "\tearly = ToolsJson.drop({ path: tools_file, text, key: run.key })?\n\tSetupIo.write_file!(fx, tools_file, early)?\n\tfor result in fx.delete!(paths) {")],
     "tests/commands/run.sh tool/tm1-manage", "L2 tm1 run 7 (calls.log: write_atomic before delete)"),
    (6, "rm does not take the lock of tools.json (R-CC6)", MF,
     [("fx.locked!(Roots.item(roots, Item.ToolsJson), || removed!(fx, { roots, bin, file, key: tool.key }))", "removed!(fx, { roots, bin, file, key: tool.key })")],
     "tests/commands/run.sh tool/tm1-manage", "L2 tm1 run 7 (no lock line)"),
    (7, "the same compiler is counted twice for the downloads (one prompt for the distinct ids, R-T25)", U,
     [("if facts.installed.contains(id) or kept.contains(id) kept", "if facts.installed.contains(id) kept")],
     L0_4, "L0 ToolSourceTest downloads"),
    (8, "--path is not checked (R-SE12)", G,
     [("if trimmed.is_empty() or text.starts_with(\"/\") or parts.any(|p| p == \"..\" or p.is_empty()) {", "if Bool.False {")],
     L0_4, "L0 ToolSourceTest read, L2 tg2 run 6"),
    (9, "tools.json records the commit as the ref (R-T23: the ref that the user typed)", GF,
     [("source: Git({ commit: want.sha, ref: want.source.ref })", "source: Git({ commit: want.sha, ref: want.sha })")],
     "tests/commands/run.sh tool/tg1-git", "L2 tg1 run 1 (tree.diff)"),
    (10, "the scratch dir of a git install is not deleted after the build (R-CC2)", GF,
     [("\t_ = fx.delete!([fetched.temp])\n\tOk({ done: built?", "\tOk({ done: built?")],
     "tests/commands/run.sh tool/tg1-git", "L2 tg1 run 1 (calls.log: delete)"),
]


def run(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, executable="/bin/bash")
    return p.returncode, p.stdout + p.stderr


def main():
    want = [int(a) for a in sys.argv[1:]]
    for num, what, path, edits, cmd, expect in M:
        if want and num not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        mutated = original
        for o, n in edits:
            assert mutated.count(o) == 1, f"mutation {num}: old text found {mutated.count(o)} times"
            mutated = mutated.replace(o, n, 1)
        try:
            open(full, "w").write(mutated)
            rc, out = run(cmd)
        finally:
            open(full, "w").write(original)
        fails = [l.strip()[:120] for l in out.splitlines() if l.startswith("FAIL") or re.match(r"^\s+\d+ failed", l) or "compiler errors" in l or l.startswith("commands:") or l.startswith("scenarios:")][:4]
        where = sorted(set(re.findall(r"Tool\w+Test\.roc:\d+", out)))[:3]
        if where:
            fails.append("at " + ", ".join(where))
        print(f"{num}\t{'CAUGHT' if rc != 0 else 'NOT CAUGHT'}\t{what}\t(expected: {expect})\t{' | '.join(fails)}", flush=True)


main()
