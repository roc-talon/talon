#!/usr/bin/env python3
"""One mutation of the reference: python3 mut.py <id> ... Puts the reference in, applies the mutation (one exact replace, in the live file), runs l0 (all), l2 `run/rn4` and l3 `run/rn2-each`, then puts the reference back (ref-on.sh).
Prints one line for each id: the id, and for each layer 'killed' (a test failed) or 'SURVIVED'. The log is in mut-<id>.log."""
import subprocess, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, "../.."))
M = {
 "m1-ties-largest-first": ("cli/lib/RunEach.roc", "match settle(Text.sorted(facts.nodes), facts.edges, [])", "match settle(Text.sorted(facts.nodes).rev(), facts.edges, [])"),
 "m2-header-edges-off": ("cli/lib/RunEach.roc", "Ok(all.concat(hits.keep_if(|dir| dir != node.dir).map(", "Ok(all.concat(hits.keep_if(|dir| dir != node.dir and dir.is_empty()).map("),
 "m3-after-ignored": ("cli/lib/RunEach.roc", "Ok(all.append({ from: node.dir, to: target, kind: After }))", "Ok(all)"),
 "m4-cycle-allowed": ("cli/lib/RunEach.roc", "Err(_) => Err(left)", "Err(_) => Ok(done.concat(left))"),
 "m5-no-skip": ("cli/lib/RunEach.roc", "Ok(f) => Ok(f)\n\t\tErr(_) => Err(None)", "Ok(_) => Err(None)\n\t\tErr(_) => Err(None)"),
 "m6-last-failure-code": ("cli/lib/RunEachFlow.roc", "Ok(c) => Ok(c)\n\t\t\t\t\t\tErr(None) => Ok(code)", "Ok(_) => Ok(code)\n\t\t\t\t\t\tErr(None) => Ok(code)"),
 "m7-skip-direct-only": ("cli/lib/RunEach.roc", "reaches(facts.edges, [facts.node], [], f)", "facts.edges.any(|e| e.from == facts.node and e.to == f)"),
 "m8-list-never-json": ("cli/lib/RunEachFlow.roc", "if args.json {\n\t\t\t\t\tfx.out!(Out.json_ok({ command: args.typed, data: RunEach.list_data", "if args.yes {\n\t\t\t\t\tfx.out!(Out.json_ok({ command: args.typed, data: RunEach.list_data"),
 "m9-standalone-is-node": ("cli/lib/RunEach.roc", "dirs = Text.sorted_unique(owners.map(|o| o.dir))", "dirs = Text.sorted_unique(owners.map(|o| o.dir).concat(facts.files.keep_if(|f| f.text.is_ok()).map(|f| Text.dir_of(f.path))))"),
 "m10-no-stop-at-failure": ("cli/lib/RunEachFlow.roc", "if !run.keep_going return code", "if !run.keep_going and code == 0 return code"),
 "m11-keep-going-alone-ok": ("cli/lib/RunCmd.roc", "if keep_going and !each {", "if keep_going and !each and args.yes {"),
 "r1-q3-standalone-no-stop": ("cli/lib/RunEach.roc", "Err(None) else Ok(dir)", "Err(None) else Err(None)"),
 "r2-q4-header-kind-input": ("cli/lib/RunEach.roc", "Err(fail) => Err(Fail.new(Usage, fail.message))", "Err(fail) => Err(Fail.new(Input, fail.message))"),
 "r3-q5-run-unknown-key": ("cli/lib/Intent.roc", ".concat(unknown_keys(doc, \"run\", [\"after\"])),", ","),
 "m12-failed-node-no-skip-record": ("cli/lib/RunEachFlow.roc", "$failed = $failed.append(plan.dir)", "$failed = $failed"),
}
for mid in sys.argv[1:]:
    f, old, new = M[mid]
    subprocess.run([os.path.join(HERE, "ref-on.sh")], check=True)
    p = os.path.join(T, f)
    s = open(p).read()
    assert s.count(old) == 1, f"{mid}: old text found {s.count(old)} times"
    open(p, "w").write(s.replace(old, new))
    res = {}
    log = open(os.path.join(HERE, f"mut-{mid}.log"), "w")
    try:
        for name, cmd in [("l0", ["scripts/test.sh", "l0"]), ("l2", ["tests/commands/run.sh", "run/rn4"]), ("l3", ["tests/run.sh", "run/rn2-each"])]:
            r = subprocess.run(cmd, cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            log.write(f"=== {name} exit {r.returncode}\n{r.stdout}\n")
            bad = ("unused" in r.stdout or "known at compile time" in r.stdout or "WARNING" in r.stdout or "duplicate definition" in r.stdout)
            res[name] = ("INVALID(warning)" if bad else "killed") if r.returncode != 0 else "SURVIVED"
    finally:
        subprocess.run([os.path.join(HERE, "ref-on.sh")], check=True)
    print(mid, res, flush=True)
