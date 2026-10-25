#!/usr/bin/env python3
"""Revert check of slice 058 (code agent). Run from the repo root: python3 research/slice-058-revert/agent-mutate.py [name ...]
Each mutation changes one small thing in a file of cli/lib, checks that the code still compiles, runs L0, then L2, then L3 (filtered) until one fails,
and puts the file back from code-final/. At the end `sha256sum -c code-final.sha256` must pass."""
import os, subprocess, sys, shutil

ROOT = os.getcwd()
FINAL = "research/slice-058-revert/code-final"
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))

# (name, file, old, new)
MUTATIONS = [
    ("m1-ties-largest-first", "RunEach.roc",
     "ready_first(links, [], Text.sorted_unique(facts.nodes))", "ready_first(links, [], Text.sorted_unique(facts.nodes).rev())"),
    ("m2-path-entry-dir-edge-off", "RunEach.roc",
     "Err(_) => match list.find_first(|n| n.dir == Text.dir_of(path)) {\n\t\tOk(n) => Ok(n.dir)\n\t\tErr(_) => Err(NoNode)\n\t}",
     "Err(_) => Err(NoNode)"),
    ("m3-after-edges-dropped", "RunEach.roc",
     "Ok(found.concat(links))\n\t},\n)\n\n# The edges sorted", "Ok(found.concat(links.keep_if(|e| e.from != n.dir)))\n\t},\n)\n\n# The edges sorted"),
    ("m4-cycle-starts-at-largest", "RunEach.roc",
     "on_cycle = left.keep_if(|n| reach(links, n).contains(n))", "on_cycle = left.keep_if(|n| reach(links, n).contains(n)).rev()"),
    ("m5-skip-direct-only", "RunEach.roc",
     "behind = reach(facts.edges, facts.node)", "behind = facts.edges.keep_if(|e| e.from == facts.node).map(|e| e.to)"),
    ("m6-exit-code-of-last-failure", "RunEachFlow.roc",
     "if $first == 0 {", "if $first >= 0 {"),
    ("m7-cannot-start-stops-run", "RunEachFlow.roc",
     "Err(fail) => Common.failed!(fx, args, fail)", "Err(fail) => return Err(fail)"),
    ("m8-args-not-on-last-step", "RunEachFlow.roc",
     "args: run.cmd.args, dir, stop", "args: [], dir, stop"),
    ("m9-standalone-not-a-stop", "RunEach.roc",
     "if nearest != facts.root and !facts.nodes.contains(nearest) Ok(nearest) else Err(None)", "if nearest != facts.root and !facts.nodes.contains(nearest) Err(None) else Err(None)"),
    ("m10-farthest-talon-toml-is-the-node", "RunEach.roc",
     "match first_file(facts.files, candidates(facts.root, member)) {", "match first_file(facts.files, candidates(facts.root, member).rev()) {"),
    ("m11-root-may-have-run-table", "Intent.roc",
     'role == Root and name == "run"', 'role == Member and name == "run"'),
]

def sh(cmd, timeout=900):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr

def main():
    want = sys.argv[1:]
    for name, file, old, new in MUTATIONS:
        if want and name not in want:
            continue
        path = f"cli/lib/{file}"
        with open(path) as f:
            text = f.read()
        if text.count(old) != 1:
            print(name, "BAD PATTERN", text.count(old)); continue
        with open(path, "w") as f:
            f.write(text.replace(old, new))
        try:
            rc, out = sh(f"{ROC} check cli/lib/main.roc")
            if rc != 0:
                print(name, "INVALID (does not compile)"); continue
            result = "NOT CAUGHT"
            for layer, cmd in (("l0", f"{ROC} test tests/unit/l0-7.roc"), ("l2", "tests/commands/run.sh run/rn4"), ("l3", "tests/run.sh run/rn2-each")):
                rc, out = sh(cmd)
                if rc != 0:
                    result = f"killed by {layer}"; break
            print(name, result, flush=True)
        finally:
            shutil.copy(f"{FINAL}/{path}", path)

main()
