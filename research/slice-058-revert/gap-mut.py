#!/usr/bin/env python3
"""Gap step of slice 058: one hand mutation of the live code (exact replace), a filtered run, then the file is put back and `sha256sum -c code-final.sha256` must be OK.
Usage: python3 research/slice-058-revert/gap-mut.py <id> (from the repo root). The log is in gap-<id>.log."""
import subprocess, sys, os, shutil
T = os.getcwd()
H = "research/slice-058-revert/"
M = {
 "g1-dir-clause": ("cli/lib/RunEach.roc", "Err(_) => match list.find_first(|n| n.dir == Text.dir_of(path)) {", "Err(_) => match list.find_first(|n| n.dir == \"-\") {", ["l0"]),
 "g2-loop-not-shortest": ("cli/lib/RunEach.roc", "steps = frontier.join_map(|item| links.keep_if(|e| e.from == item.at).map(|e| { at: e.to, via: item.via.append(e) }))", "steps = frontier.take_first(1).join_map(|item| links.keep_if(|e| e.from == item.at).map(|e| { at: e.to, via: item.via.append(e) }))", ["l0"]),
 "g4-plan-lazily": ("cli/lib/RunEachFlow.roc", [("\t\tflats = RunSteps.plan!(fx, { name: run.name, args: run.cmd.args, dir, stop: space.root }, files)?\n\t\t$planned = $planned.append({ dir, flats })", "\t\tflats = if dir == \"\" RunSteps.plan!(fx, { name: run.name, args: run.cmd.args, dir, stop: space.root }, files)? else []\n\t\t$planned = $planned.append({ dir, flats })"), ("\t\t\t\tfx.err!(\"running ${label(node.dir)}\\n\")\n\t\t\t\tcode = match RunSteps.steps!(fx, args, { name: run.name, ready: space.ready }, node.flats, tln) {", "\t\t\t\tfx.err!(\"running ${label(node.dir)}\\n\")\n\t\t\t\tlazy = RunSteps.plan!(fx, { name: run.name, args: run.cmd.args, dir: node.dir, stop: space.root }, RunSteps.known_files(run.start.scan))?\n\t\t\t\tcode = match RunSteps.steps!(fx, args, { name: run.name, ready: space.ready }, lazy, tln) {")], ["l2"]),
 "g3-after-before-headers": ("cli/lib/RunEach.roc", "by_path = path_edges(facts.nodes, facts.headers)?\n\t\tby_after = after_edges(facts.nodes)?", "by_after = after_edges(facts.nodes)?\n\t\tby_path = path_edges(facts.nodes, facts.headers)?", ["l0"]),
}
mid = sys.argv[1]
f, old, new, layers = M[mid] if len(M[mid]) == 4 else (M[mid][0], None, None, M[mid][2])
pairs = M[mid][1] if len(M[mid]) == 3 else [(old, new)]
p = os.path.join(T, f)
backup = open(p).read()
mutated = backup
for o, n in pairs:
    assert mutated.count(o) == 1, f"{mid}: old text found {mutated.count(o)} times"
    mutated = mutated.replace(o, n)
open(p, "w").write(mutated)
log = open(H + f"gap-{mid}.log", "w")
res = {}
try:
    for name in layers:
        cmd = {"l0": ["scripts/test.sh", "l0"], "l2": ["tests/commands/run.sh", "run/rn4"]}[name]
        r = subprocess.run(cmd, cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        log.write(f"=== {name} exit {r.returncode}\n{r.stdout}\n")
        res[name] = "killed" if r.returncode != 0 else "SURVIVED"
finally:
    open(p, "w").write(backup)
chk = subprocess.run(["sha256sum", "-c", H + "code-final.sha256"], cwd=T, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print(mid, res, "sha256:", "OK" if chk.returncode == 0 else "CHANGED\n" + chk.stdout, flush=True)
