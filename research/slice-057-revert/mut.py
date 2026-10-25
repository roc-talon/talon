#!/usr/bin/env python3
"""One mutation of the reference: python3 mut.py <id>. Puts the reference in, applies the mutation (one exact replace, in the live file), runs l0 (all), l2 `run/` and l3 `run/rn1`, `fx/px2`, then puts the reference back (ref-on.sh).
Prints one line: the id, and for each layer 'killed' (a test failed) or 'SURVIVED'. The log is in mut-<id>.log."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, "../.."))
M = {
 "m1-args-all-steps": ("cli/lib/RunPlan.roc", "mine = if $at + 1 == count args else []", "mine = if $at + 1 == count or count > 0 args else []"),
 "m2-walk-no-stop": ("cli/lib/RunFind.roc", "_ => Err(Stop(not_found(facts, here)))", "_ => search(facts, above, here)"),
 "m3-nc4-no-probe": ("cli/lib/RunFind.roc", "if !asked.is_empty() {\n\t\t\t\treturn Err(Need(asked))\n\t\t\t}", "if asked.len() > 100 {\n\t\t\t\treturn Err(Need(asked))\n\t\t\t}"),
 "m4-in-outside-ok": ("cli/lib/RunPlan.roc", "if !inside {", "if !inside and dir.is_empty() {"),
 "m5-path-over-key": ("cli/lib/RunPlan.roc", "[first, .. as rest] => if facts.keys.contains(first) {", "[first, .. as rest] => if facts.keys.contains(\"${first}#\") {"),
 "m6-exit-code-lost": ("cli/lib/RunFlow.roc", "if code != 0 return Ok(code)", "if code != 0 return Ok(1)"),
 "m7-record-after-fail-skipped": ("cli/lib/RunFlow.roc", "record!(fx, start, scan.walk, found)?\n", ""),
 "m8-cycle-check-off": ("cli/lib/RunPlan.roc", "if chain.contains(place) {", "if chain.contains(place) and place.name.is_empty() {"),
 "m9-roc-no-dashdash": ("cli/lib/RunPlan.roc", "Ok(Roc([first, \"--\"].concat(rest)))", "Ok(Roc([first].concat(rest)))"),
 "m10-shell-word-allowed": ("cli/lib/ScriptsToml.roc", "refused = |word| [\"|\", \"&&\", \"||\", \";\", \">\", \">>\", \"<\", \"&\"].contains(word) or", "refused = |word| [\"|\", \"&&\", \"||\", \";\", \">>\", \"<\", \"&\"].contains(word) or"),
 "q1-no-name-args-ok": ("cli/lib/RunCmd.roc", "if args.passthrough.is_empty() {", "if args.passthrough.is_empty() or args.operands.is_empty() {"),
 "q2-no-url-internal": ("cli/lib/RunTools.roc", "Fail.new(Frozen, \"the [tools] of", "Fail.new(Internal, \"the [tools] of"),
 "q3a-quote-splits-word": ("cli/lib/ScriptsToml.roc", "walk({ ..s, mode: Double, open: Bool.True, quoted: Bool.True }, rest)", "walk({ ..flush(s), mode: Double, open: Bool.True, quoted: Bool.True }, rest)"),
 "q3b-unclosed-ok": ("cli/lib/ScriptsToml.roc", "_ => Err(Unclosed)", "_ => Ok(flush(s).out)"),
 "q6-allow-downloads-text": ("cli/lib/RunTools.roc", "Err(fail) => return Err(RunTools.stop(fail))", "Err(fail) => return Err(fail)"),
}
mid = sys.argv[1]
f, old, new = M[mid]
subprocess.run([os.path.join(HERE, "ref-on.sh")], check=True)
p = os.path.join(T, f)
s = open(p).read()
assert s.count(old) == 1, f"{mid}: old text found {s.count(old)} times"
open(p, "w").write(s.replace(old, new))
res = {}
log = open(os.path.join(HERE, f"mut-{mid}.log"), "w")
try:
    for name, cmd in [("l0", ["scripts/test.sh", "l0"]), ("l2", ["tests/commands/run.sh", "run/"]), ("l3", ["tests/run.sh", "run/rn1", "fx/px2"])]:
        r = subprocess.run(cmd, cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        log.write(f"=== {name} exit {r.returncode}\n{r.stdout}\n")
        bad = ("unused" in r.stdout or "known at compile time" in r.stdout or "WARNING" in r.stdout)
        res[name] = ("INVALID(warning)" if bad else "killed") if r.returncode != 0 else "SURVIVED"
finally:
    subprocess.run([os.path.join(HERE, "ref-on.sh")], check=True)
print(mid, res)
