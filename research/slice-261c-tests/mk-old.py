#!/usr/bin/env python3
# Slice 261c (test agent): the 3 old L2 cases on the built-in default registry whose runs write a new value from a registry answer get a fake log
# (tests/tools/mk-log.mjs) and a TALON_LOG_KEY with the name of the built-in key (it replaces the built-in key, R-LV5): registry/rg2-config-direct (run 3),
# registry/rg2-default-registry (runs 1 and 3), registry/rg2-example-add-short (runs 1 and 2).
# Step `fix`: the fake log and the key. Step `expect <work root>`: the hand-written insert of the check calls into expect/calls.log (by the rules of
# docs/slices/261-log-inclusion-proofs.md section 14.3) and the tree diff with the copies of R-IX8 (from the work dir of a run of the code before 261c).
import json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REG = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "registry.roc-talon.org"
J25 = "github.com/acme/json/releases/download/{v}/ 2.1.0 4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq 1790337600000"
P33 = "github.com/acme/pfx/releases/download/{v}/ 0.1.1 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK 1789905600000"
R35 = "github.com/acme/parser/releases/download/{v}/ 1.2.0 EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt 1791201600000"
K1 = "github.com/acme/known/releases/download/{v}/ 1.0.0 5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV 1790848800000"
K2 = "github.com/acme/known/releases/download/{v}/ 1.1.0 24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL 1790848800000"
BIG = {"host": HOST, "index_dir": "https_registry.roc-talon.org", "leaves": {"25": J25, "33": P33, "35": R35}, "serve": [{"file": "checkpoint", "size": 36}]}
SMALL = {"host": HOST, "index_dir": "https_registry.roc-talon.org", "leaves": {"1": K1, "2": K2}, "serve": [{"file": "checkpoint", "size": 3}]}
# case: (spec, {run number: 'fresh' | 'kept'}, tiles)
CASES = {
    "rg2-config-direct": (BIG, {3: "fresh"}, ["tile/entries/000.p/36", "tile/0/000.p/36"]),
    "rg2-default-registry": (BIG, {1: "fresh", 3: "kept"}, ["tile/entries/000.p/36", "tile/0/000.p/36"]),
    "rg2-example-add-short": (SMALL, {1: "fresh", 2: "kept"}, ["tile/entries/000.p/3", "tile/0/000.p/3"]),
}

step = sys.argv[1]
if step == "fix":
    for name, (spec, _, _) in CASES.items():
        d = os.path.join(REG, name)
        with open(os.path.join(d, "mk-log.json"), "w") as f:
            f.write(json.dumps(spec, indent=1) + "\n")
        line = subprocess.run(["node", os.path.join(ROOT, "tests/tools/mk-log.mjs"), d], check=True, capture_output=True, text=True).stdout.strip()
        env = open(os.path.join(d, "fx/env")).read()
        if "TALON_LOG_KEY=" not in env:
            with open(os.path.join(d, "fx/env"), "a") as f:
                f.write(line + "\n")
    print("ok")
elif step == "expect":
    wroot = os.path.abspath(sys.argv[2])
    from mkexpectlib import Log, runs_of, post_end, copies_of, put, read  # noqa: E402
    log = Log("https://registry.roc-talon.org", "https_registry.roc-talon.org")
    for name, (spec, plan, tiles) in CASES.items():
        d = os.path.join(REG, name)
        runs = runs_of(read(os.path.join(d, "expect/calls.log")).split("\n")[:-1])
        out = []
        for i, run in enumerate(runs, 1):
            k = post_end(run) if i in plan else len(run)
            insert = []
            if plan.get(i) == "fresh":
                insert = log.read_kept() + log.get_checkpoint() + log.read_copies(tiles) + log.fetch(tiles) + log.write(tiles)
            elif plan.get(i) == "kept":
                insert = log.read_kept() + log.read_copies(tiles)
            out += run[:k] + insert + run[k:]
        put(os.path.join(d, "expect/calls.log"), "\n".join(out) + "\n")
        w = os.path.join(wroot, "registry_" + name)
        size = spec["serve"][0]["size"]
        cps = copies_of(d, size, "https_registry.roc-talon.org", spec["leaves"])
        cps[".local/share/talon/log/https_registry.roc-talon.org/checkpoint"] = read(os.path.join(d, "fx/http", HOST, "log/checkpoint"))
        for rel, text in cps.items():
            put(os.path.join(w, "home", rel), text)
        diff = subprocess.run(["bash", "-c", f'. "{ROOT}/tests/lib.sh"; tree_diff "{w}"'], check=True, capture_output=True, text=True).stdout
        put(os.path.join(d, "expect/tree.diff"), diff)
    print("ok")
