#!/usr/bin/env python3
"""Revert check of slice 046: each mutant changes one tricky behavior of the private reference in cli/lib, runs the filtered tests (l0, then l2, then l3) and puts the reference back.
Run from the repo root: python3 research/slice-046-revert/mutants.py [number ...]. The output is `research/slice-046-revert/mutants.log`. Never the full sweep.
A mutant is (number, text, file, [(old, new), ...], steps). `steps` are the steps that run (default l0, l2, l3 in this order until one kills)."""
import subprocess, sys, os, shutil, re
ROC = os.path.abspath("cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.abspath(".work/cache"), ROC_CACHE_DIR=os.path.abspath(".work/cache/roc"), OPT="dev")
ALL = ("l0", "l2", "l3")
M = [
 (1, "pick: a release is visible when published_at + min_age < now (the boundary is hidden)", "ToolInstall.roc", [("c.published_at + facts.min_age <= facts.now", "c.published_at + facts.min_age < facts.now")], ALL),
 (2, "reuse: @latest or a range keeps the installed version whatever the newest release is", "ToolInstall.roc", [("Ok(_) => if facts.first == version Keep(version) else Build", "Ok(_) => Keep(version)")], ALL),
 (3, "reuse: a git tool is kept (a release install does not replace it)", "ToolInstall.roc", [("Git(_) => Build", 'Git(_) => Keep("git")')], ALL),
 (4, "finish!: no check of the binary name under the lock", "ToolFlow.roc", [("\tcheck_names(entries, run.key, run.name)?\n\thow =", "\thow =")], ALL),
 (5, "entry_verdict!: a foreign bin dir entry is overwritten", "ToolFlow.roc", [("Foreign => Err(ToolInstall.foreign_failure(layout.entry))", "Foreign => Ok({})")], ALL),
 (6, "verdict: an entry with no old binary is Talon's", "ToolInstall.roc", [("NoSource => match facts.have {\n\t\t\t\tAbsent => Make\n\t\t\t\t_ => Foreign\n\t\t\t}", "NoSource => Make")], ALL),
 (7, "want: --roc pinned is not the consent", "ToolInstall.roc", [("Pinned => Ok(Yes)", "Pinned => Err(NoFlag)")], ALL),
 (8, "add: a replaced tool loses the fields that tln does not know", "ToolsJson.roc", [("(key, merged(old, doc))", "(key, doc)")], ALL),
 (9, "first_app!: a bundle that is no app is taken", "ToolFlow.roc", [("if header.kind == App {", "if Bool.True {")], ALL),
 (10, "the lock of tools.json is held during the build, not for the last step only (R-CC6)", "ToolFlow.roc",
  [("fx.locked!(run.tools_path, || finish!(fx, run, { bundle: facts.bundle, id: facts.id, layout: facts.layout, version: facts.version, hashes }))", "finish!(fx, run, { bundle: facts.bundle, id: facts.id, layout: facts.layout, version: facts.version, hashes })"),
   ("result = make!(fx, run, { bundle, id, layout, version })", "result = fx.locked!(run.tools_path, || make!(fx, run, { bundle, id, layout, version }))")], ("l3",)),
 (11, "no early check of the bin dir entry (review of Q8): the build runs before the stop", "ToolFlow.roc", [("\tentry_verdict!(fx, run)?\n\tif picked.young {", "\tif picked.young {")], ALL),
 (12, "no check of the bin dir entry under the lock (review of Q8)", "ToolFlow.roc", [("\tentry_verdict!(fx, run)?\n\tmatch fx.make_dirs!([layout.data_bin, layout.bin])", "\tmatch fx.make_dirs!([layout.data_bin, layout.bin])")], ALL),
 (13, "native: a platform with one wasm name is refused (any, not all)", "ToolInstall.roc", [("names.all(|n| n.starts_with(\"wasm\"))", "names.any(|n| n.starts_with(\"wasm\"))")], ALL),
 (14, "no check of the platform (R-T2)", "ToolFlow.roc", [("\tcheck_platform!(fx, run, bundle)?\n", "")], ALL),
]
def sh(*a, **k): return subprocess.run(a, env=ENV, capture_output=True, text=True, **k)
want = [int(x) for x in sys.argv[1:]]
log = open("research/slice-046-revert/mutants.log", "a")
for n, what, f, pairs, steps in M:
    if want and n not in want: continue
    path = "cli/lib/" + f
    ref = "research/slice-046-revert/reference/lib/" + f
    src = open(ref).read()
    bad = [o for o, _ in pairs if src.count(o) != 1]
    if bad:
        log.write(f"{n}\t{what}\tSKIPPED: old text found {src.count(bad[0])} times\n"); log.flush(); continue
    mut = src
    for o, nw in pairs: mut = mut.replace(o, nw)
    open(path, "w").write(mut)
    result = "SURVIVED"
    for step in steps:
        cmd = {"l0": [ROC, "test", "tests/unit/l0-1.roc"], "l2": ["tests/commands/run.sh", "tool/"], "l3": ["tests/run.sh", "tools/"]}[step]
        r = sh(*cmd)
        out = r.stdout + r.stderr
        if r.returncode != 0:
            broke = re.search(r"[1-9]\d* compiler error", out) or "build of tln failed" in out or "Compilation failed" in out or "roc test failed to build" in out or "UNRECOGNIZED" in out
            result = f"KILLED by {step}" if not broke else f"BUILD-ERROR in {step}"
            break
    shutil.copy(ref, path)
    log.write(f"{n}\t{what}\t{result}\n"); log.flush()
