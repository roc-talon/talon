#!/usr/bin/env python3
"""Revert check of slice 059: python3 research/slice-059-revert/mut.py <id> ... (from the repo root, with the reference in: ref-on.sh).
Each id: put the reference in, apply the replaces (each old text must be found the given number of times), run l0 (scripts/test.sh l0), l2 (x/) and l3 (ptools/pt2-x), put the reference back.
Prints one line for each id and layer: killed (a test failed), SURVIVED, or INVALID (a warning or a compile error). The log is mut-<id>.log."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, "../.."))
M = {
 "m1-key-matches-repo-name": [("cli/lib/XProject.roc", 'find_first(|e| e.key == facts.ref.name)', 'find_first(|e| e.key == facts.ref.name or Text.last_segment(ToolsToml.app_of(e.ref)) == facts.ref.name)', 1)],
 "m2-selector-ignored": [("cli/lib/XProject.roc", "Ok(_) => Err(None)\n\t\tErr(None) => match facts.ref.form {", "Ok(_) | Err(None) => match facts.ref.form {", 1),
                          ("cli/lib/XProject.roc", "Ok(_) => return Ok(Err(Miss))\n\t\t\tErr(None) => {}", "Ok(_) => {}\n\t\t\tErr(None) => {}", 1)],
 "m3-no-record": [("cli/lib/XProject.roc", "Known.record!(fx, { roots, files: RunSteps.record_files!(fx, scan, found), now })?", "_ = RunSteps.record_files!(fx, scan, found)", 1)],
 "m4-args-dropped": [("cli/lib/XProject.roc", "argv: [got.bin].concat(plan.args)", "argv: [got.bin]", 1)],
 "m5-no-url-is-miss": [("cli/lib/XProject.roc", "Err(Unset) => return Err(RunTools.no_url({ path: tools_path, key: hit.entry.key }))", "Err(Unset) => return Ok(Err(Miss))", 1)],
 "m6-standalone-uses-root-table": [("cli/lib/XProject.roc", "tools_path = Text.join(found.tools_dir, \"talon.toml\")", "tools_dir = match scan.root {\n\t\t\tOk(r) => r\n\t\t\tErr(_) => found.tools_dir\n\t\t}\n\t\ttools_path = Text.join(tools_dir, \"talon.toml\")", 1),
                                   ("cli/lib/XProject.roc", "scan.walk.find_first(|d| d.dir == found.tools_dir)", "scan.walk.find_first(|d| d.dir == tools_dir)", 1)],
 "m7-no-app-file-records-main": [("cli/lib/RunSteps.roc", 'Text.join(found.dir, if has_main "main.roc" else "talon.toml")', 'Text.join(found.dir, if has_main or !has_main "main.roc" else "talon.toml")', 1)],
 "m8-key-form-skips-project": [("cli/lib/XFlow.roc", "Ok(plan) => match XProject.run!(fx, args, plan) {", "Ok(plan) => match (match plan.ref.form {\n\t\t\tBare => Ok(Err(Miss))\n\t\t\t_ => XProject.run!(fx, args, plan)\n\t\t}) {", 1)],
}
for mid in sys.argv[1:]:
    subprocess.run([os.path.join(HERE, "ref-on.sh")], check=True)
    ok = True
    for f, old, new, n in M[mid]:
        p = os.path.join(T, f)
        s = open(p).read()
        if s.count(old) != n:
            print(mid, f"BAD PATTERN {s.count(old)}"); ok = False; break
        open(p, "w").write(s.replace(old, new))
    if not ok:
        continue
    res = {}
    log = open(os.path.join(HERE, f"mut-{mid}.log"), "w")
    try:
        for name, cmd in [("l0", ["scripts/test.sh", "l0"]), ("l2", ["tests/commands/run.sh", "x/"]), ("l3", ["tests/run.sh", "ptools/pt2-x"])]:
            r = subprocess.run(cmd, cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            log.write(f"=== {name} exit {r.returncode}\n{r.stdout}\n")
            bad = ("unused" in r.stdout or "known at compile time" in r.stdout or "WARNING" in r.stdout or "duplicate definition" in r.stdout or "compiler errors\n" in r.stdout and "0 compiler errors" not in r.stdout or "CompileError" in r.stdout)
            res[name] = ("INVALID(warning or compile error)" if bad else "killed") if r.returncode != 0 else "SURVIVED"
    finally:
        subprocess.run([os.path.join(HERE, "ref-on.sh")], check=True)
    print(mid, res, flush=True)
