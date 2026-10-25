#!/usr/bin/env python3
"""Revert check of slice 047 (test agent): 10 mutations of the private reference (installed in cli/lib by reference.sh). Each mutation breaks one file in one small way,
runs only the test that must see it, prints the result and puts the file back. Run from the repo root: python3 research/slice-047-revert/mutants.py [number ...]
After the run: sh research/slice-047-revert/restore.sh (stubs back). Never a full sweep."""
import os, re, subprocess, sys

ROOT = os.getcwd()
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
L0_5 = f"XDG_CACHE_HOME=$PWD/.work/cache ROC_CACHE_DIR=$PWD/.work/cache/roc {ROC} test tests/unit/l0-5.roc"
L2 = "tests/commands/run.sh tool/ti3-compiler tool/ti4-nothing"
L3 = "tests/run.sh tools/ti2-tool-compiler"
C = "cli/lib/ToolCompiler.roc"
T = "cli/lib/ToolTry.roc"
W = "cli/lib/ToolCompilerFlow.roc"

# (number, what, file, [(old, new)], command, the test that must see it)
M = [
    (1, "the digest ignores the hashes of the header (only the bundle)", C,
     [("facts.hashes.append(facts.bundle).map(|hash| { hash, path: \"\" })", "[facts.bundle].map(|hash| { hash, path: \"\" })")], L0_5, "L0 ToolCompilerTest 2"),
    (2, "the evidence takes the oldest release with a pass (not the first in the order)", C,
     [("run.ids.find_first(", "run.ids.find_last(")], L0_5, "L0 ToolCompilerTest 3, L2 ti3 run 1"),
    (3, "a fail row does not block a pass of the same digest", C,
     [("BuildSkip.decide({ facts: run.facts,", "BuildSkip.decide({ facts: run.facts.keep_if(|f| f.outcome == Pass),")], L0_5, "L0 ToolCompilerTest 3"),
    (4, "--roc installed does not win over --yes", C,
     [("\t\tInstalled => TryInstalled\n\t\t_ => {", "\t\tInstalled => if run.yes Download else TryInstalled\n\t\t_ => {")], L0_5, "L0 ToolCompilerTest 5"),
    (5, "the checks of option 2 run one by one (a probes! call for each)", T,
     [("outputs = fx.probes!({ pool: 12, specs })\n", "var $outs = []\n\t\tfor s in specs {\n\t\t\t$outs = $outs.concat(fx.probes!({ pool: 12, specs: [s] }))\n\t\t}\n\t\toutputs = $outs\n")], L2, "L2 ti3 runs 2, 3, 4 (probes 4), L3 step 1 (the barrier)"),
    (6, "no db_write after the round of checks", T,
     [("_ = Facts.save!(fx, { roots: run.roots, rows, existing: Replace })?\n", "_ = rows\n")], L2, "L2 ti3 runs 2, 3, 4"),
    (7, "a build that does not pass stops option 2 (no next release)", T,
     [("if $won.is_empty() {", "if $won.is_empty() and $first {")], L2, "L2 ti3 run 2 (C is never built)"),
    (8, "option 2 is allowed with no installed release", C,
     [("Option(2) => facts.installed > 0", "Option(2) => Bool.True")], L0_5, "L0 ToolCompilerTest 7, L2 ti4 run 1"),
    (9, "the prompt after option 2 offers option 2 again", W,
     [("count = if st.tried.is_empty() ask.ids.len() else 0", "count = ask.ids.len()")], L2, "L2 ti3 run 4"),
    (10, "tty is asked at once (not lazily)", W,
     [("\tmode = match decide(base) {\n\t\tNeedTty => Mode.with_tty(base, fx.tty!())\n\t\t_ => base\n\t}", "\tmode = Mode.with_tty(base, fx.tty!())")], L2, "L2 ti3 runs 1, 6 (no tty line)"),
    (11, "a flag removes the evidence pass (evidence only for no flag)", W,
     [("\tkeys = ToolCompiler.evidence_keys({ pf: run.pf, target: run.target, ids: ask.ids })", "\tkeys = if run.roc == Auto ToolCompiler.evidence_keys({ pf: run.pf, target: run.target, ids: ask.ids }) else []")], L2, "L2 ti3 run 6"),
    (12, "the build fact of the tries is not written", T,
     [("_ = Facts.save!(fx, { roots: run.roots, rows: [row], existing: Replace })?\n", "_ = row\n")], L2, "L2 ti3 run 2"),
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
            rc, out = run(os.environ.get("MUT_CMD") or cmd)
        finally:
            open(full, "w").write(original)
        fails = [l.strip()[:120] for l in out.splitlines() if l.startswith("FAIL") or re.match(r"^\s+\d+ failed", l) or "compiler errors" in l or l.startswith("commands:") or l.startswith("scenarios:")][:4]
        where = sorted(set(re.findall(r"ToolCompilerTest\.roc:\d+", out)))[:3]
        if where:
            fails.append("at " + ", ".join(where))
        print(f"{num}\t{'CAUGHT' if rc != 0 else 'NOT CAUGHT'}\t{what}\t(expected: {expect})\t{' | '.join(fails)}", flush=True)

main()
