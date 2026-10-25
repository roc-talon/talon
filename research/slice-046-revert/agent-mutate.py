#!/usr/bin/env python3
"""MUT_CMD=<command> replaces the test command of the chosen mutation (used for the L3 run of mutation 4).
Revert check of slice 046 (code agent). Each mutation breaks cli/lib in one small way, runs only the test that must see it,
records the result, and puts the file back. Run from the repo root: python3 research/slice-046-revert/agent-mutate.py [number ...]
The final check: sha256sum -c research/slice-046-revert/code-final.sha256"""
import os, subprocess, sys

ROOT = os.getcwd()
L0 = "ROC=cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc; XDG_CACHE_HOME=$PWD/.work/cache ROC_CACHE_DIR=$PWD/.work/cache/roc $ROC test tests/unit/l0-1.roc"
L2 = "tests/commands/run.sh tool/ti2-refusals"
L2A = "tests/commands/run.sh tool/ti1-install"
L3 = "tests/run.sh tools/ti1-tool-install"
F = "cli/lib/ToolFlow.roc"
I = "cli/lib/ToolInstall.roc"
J = "cli/lib/ToolsJson.roc"

# (number, what, file, old text, new text, command, the test that must see it)
M = [
    (1, "no early check of the bin dir entry (before the download and the build)", F,
     "\tnotes!(fx, facts, picked, newest)\n\tentry_verdict!(fx, facts)?\n", "\tnotes!(fx, facts, picked, newest)\n", L2, "L2 tool/ti2-refusals run 10"),
    (2, "no check of the bin dir entry under the lock", F,
     "\tentry_verdict!(fx, facts)?\n\tsha = write_binary!", "\tsha = write_binary!", L2, "L2 tool/ti2-refusals run 12"),
    (3, "no binary name check under the lock (a taken name is free)", F,
     "\t\tTaken(other) => return Err(ToolInstall.clash_failure({ key: facts.key, taken: other.name, name: facts.name }))\n\t\tElsewhere(other) => return Err(ToolInstall.elsewhere_failure({ key: other.key, name: facts.name }))\n\t\tSame(old)",
     "\t\tTaken(_) => Installed\n\t\tElsewhere(_) => Installed\n\t\tSame(old)", L2, "L2 tool/ti2-refusals run 9"),
    (4, "the lock of tools.json is held during the build (the lock moves from the install to the whole build step)", F,
     [("\tfx.locked!(Roots.item(ctx.facts.roots, Item.ToolsJson), || install!(fx, ctx))\n}", "\tinstall!(fx, ctx)\n}"),
      ("\tresult = built!(fx, { facts, bundle: chosen.bundle, id: chosen.id, layout }, spec)\n",
       "\tresult = fx.locked!(Roots.item(facts.roots, Item.ToolsJson), || built!(fx, { facts, bundle: chosen.bundle, id: chosen.id, layout }, spec))\n")],
     None, L2A, "L2 tool/ti1-install (the lock line is before the probe), L3 step 4"),
    (5, "native: one wasm name refuses the platform (any for all)", I,
     "names.all(|name| name.starts_with(\"wasm\"))", "names.any(|name| name.starts_with(\"wasm\"))", L0, "L0 ToolTest 14"),
    (6, "no check of the platform", F,
     "\tcheck_platform!(fx, args, facts, bundle)?\n", "", L2, "L2 tool/ti2-refusals run 11"),
    (7, "min-release-age does not hide a release (no name, no range)", I,
     "visible = kept.keep_if(|c| !young(c))", "visible = kept", L0, "L0 ToolTest 3"),
    (8, "a replaced tool loses the fields that tln does not know", J,
     "(key, merge(doc, built))", "(key, built_doc(built))", L0, "L0 ToolTest 12"),
    (9, "a range or @latest keeps the installed version whatever the newest release is", I,
     "Ok(_) => if facts.first == rel.version Keep(rel.version) else Build", "Ok(_) => Keep(rel.version)", L0, "L0 ToolTest 4"),
    (10, "an entry with no old binary is Talon's", I,
     "Err(NotFound) => Foreign\n\t\t}\n\t}\n\n\t## R-T28, R-NM11, R-CC6: the failure of a binary name", "Err(NotFound) => Make\n\t\t}\n\t}\n\n\t## R-T28, R-NM11, R-CC6: the failure of a binary name", L0, "L0 ToolTest 7"),
    (11, "no lock of tools.json at all for the last step", F,
     "\tfx.locked!(Roots.item(ctx.facts.roots, Item.ToolsJson), || install!(fx, ctx))\n}", "\tinstall!(fx, ctx)\n}", L2A, "L2 tool/ti1-install (the lock lines)"),
    (12, "the key ignores the installed key (an app installed with --as is installed again under its repo name)", F,
     "\t\t\tOk(installed) => installed\n", "\t\t\tOk(_) => ToolInstall.key({ plan, name })\n", L2A, "L2 tool/ti1-install run 7"),
    (13, "the default branch request sends no token", F,
     [("\tgh = match facts.net.token {\n\t\tAskGh => Github.ask_gh!(fx)\n\t\t_ => Err(None)\n\t}\n\ttoken = Net.token({ plan: facts.net.token, gh })\n", "\ttoken = Err(None)\n")],
     None, L2, "L2 tool/ti2-refusals run 3"),
]

def run(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, executable="/bin/bash")
    return p.returncode, p.stdout + p.stderr

def main():
    want = [int(a) for a in sys.argv[1:]]
    for num, what, path, old, new, cmd, expect in M:
        if want and num not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        edits = old if new is None else [(old, new)]
        mutated = original
        for o, n in edits:
            assert mutated.count(o) == 1, f"mutation {num}: old text found {mutated.count(o)} times"
            mutated = mutated.replace(o, n, 1)
        try:
            open(full, "w").write(mutated)
            rc, out = run(os.environ.get('MUT_CMD') or cmd)
        finally:
            open(full, "w").write(original)
        fails = [l.strip() for l in out.splitlines() if l.startswith("FAIL") or "FAILED" in l or "failed" in l.lower()][:3]
        import re
        where = sorted(set(re.findall(r"ToolTest\.roc:\d+", out)))[:3]
        if where:
            fails.append("at " + ", ".join(where))
        print(f"{num}\t{'CAUGHT' if rc != 0 else 'NOT CAUGHT'}\t{what}\t(expected: {expect})\t{' | '.join(fails)}", flush=True)

main()
