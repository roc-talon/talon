#!/usr/bin/env python3
"""Revert check of the code of slice 029b (TW12), by the code agent. One small change at a time, filtered layers, one build after another.

Before each mutation code-final/ is copied into cli/lib/, so a kill leaves the final code in place. At the end the final code is copied back and compared.
Layers: l0 = tests/unit/cacheview.roc, l2 = tests/commands/run.sh cache/, l3 = tests/run.sh cache/cv.
The first failing layer ends the run of a mutation (caught). A layer over its timeout counts as caught (a loop).
Usage (from the repo root): python3 -I research/slice-029b-revert/agent-mutate.py [id ...]   (no id: all)
"""
import filecmp, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut029b-agent"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15", JOBS="4")
FINAL = os.path.join(ROOT, "research/slice-029b-revert/code-final")
CV, CS, CL, CC = "cli/lib/CacheView.roc", "cli/lib/CacheShow.roc", "cli/lib/Clean.roc", "cli/lib/CacheClean.roc"
FILES = [CV, CS, CL, CC]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}

# id, rule, file, old text, new text, layers in order
M = [
    ("A01", "R-CM17", CV, "[] => Ok({})\n\t\tmany", '[] => Err(Fail.new(Usage, "x"))\n\t\tmany', "l0 l2"),
    ("A02", "R-CM17", CV, "got ${many.len().to_str()}", "got ${(many.len() + 1).to_str()}", "l0"),
    ("A03", "R-CM17", CV, 'Str.join_with(args.command, " ")', '"cache"', "l0"),
    ("A04", "R-CM17", CV, "Fail.new(Usage,", "Fail.new(Environment,", "l0"),
    ("A05", "R-OUT2", CV, 'dir_report = |cache| ["${cache}\\n"]', 'dir_report = |cache| ["${cache}"]', "l0"),
    ("A06", "R-OUT4", CV, '("path", JsonDoc.Text(cache))', '("dir", JsonDoc.Text(cache))', "l0"),
    ("A07", "R-OUT2", CV, '["nothing to clean\\n"]', '["nothing to remove\\n"]', "l0"),
    ("A08", "R-OUT2", CV, 'items = listed.paths.map(|path| "${path}${Clean.size_suffix(listed.sizes, path)}\\n")', 'items = listed.paths.map(|path| "${path}\\n")', "l0"),
    ("A09", "R-OUT2", CV, "if listed.sizes.is_empty() items else", "if listed.paths.is_empty() items else", "l0"),
    ("A10", "R-OUT2", CV, '"total ${Toolchain', '"freed ${Toolchain', "l0"),
    ("A11", "R-OUT2", CV, "sum + one.bytes)", "sum + one.bytes + 1)", "l0"),
    ("A12", "R-OUT2", CV, 'items = listed.paths.map(|path| "${path}${Clean.size_suffix', 'items = listed.paths.rev().map(|path| "${path}${Clean.size_suffix', "l0"),
    ("A13", "R-OUT4", CL, "Err(_) => JsonDoc.Null", "Err(_) => JsonDoc.Num(0)", "l0"),
    ("A14", "R-OUT4", CV, '("total", JsonDoc.Num(total(listed.sizes).to_i64_wrap()))', '("total", JsonDoc.Num(listed.sizes.len().to_i64_wrap()))', "l0"),
    ("A15", "R-OUT4", CV, '("path", JsonDoc.Text(path)), ("bytes"', '("item", JsonDoc.Text(path)), ("bytes"', "l0"),
    ("A16", "R-LY1", CS, "CacheView.dir_report(roots.cache), CacheView.dir_data(roots.cache)", "CacheView.dir_report(roots.build), CacheView.dir_data(roots.build)", "l2 l3"),
    ("A17", "R-LY1", CS, "CacheView.dir_data(roots.cache))", "CacheView.dir_data(roots.build))", "l2 l3"),
    ("A18", "R-FL4", CS, "\t} else {\n\t\tfor line in lines {", "\t} else if !args.quiet {\n\t\tfor line in lines {", "l2 l3"),
    ("A19", "R-J3", CS, "\t\tfx.out!(Out.json_ok({ command: args.typed, data }))\n\t} else {", "\t\tfx.out!(Out.json_ok({ command: args.typed, data }))\n\t\tfor line in lines {\n\t\t\tfx.err!(line)\n\t\t}\n\t} else {", "l2"),
    ("A20", "R-J3", CS, "command: args.typed", 'command: "cache"', "l2"),
    ("A21", "R-GC13", CC, "Clean.asks({ roots, all, builds })", "Clean.asks({ roots, all: Bool.False, builds })", "l2 l3"),
    ("A22", "R-LY1", CC, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", "l2 l3"),
    ("A23", "R-CC10", CC, "\t\tbuilds = if all", "\t\t_ = fx.lock!(Roots.item(roots, Gc), NoWait)\n\t\tbuilds = if all", "l2"),
    ("A24", "R-CM17", CS, "\t\t\tOk(roots) => print!(fx, args, CacheView.dir_report(roots.cache), CacheView.dir_data(roots.cache))", "\t\t\tOk(roots) => {\n\t\t\t\t_ = fx.make_dirs!([roots.cache])\n\t\t\t\tprint!(fx, args, CacheView.dir_report(roots.cache), CacheView.dir_data(roots.cache))\n\t\t\t}", "l2"),
    ("A25", "R-GC13", CC, "\t\tbuilds = if all", "\t\t_ = fx.clock!()\n\t\tbuilds = if all", "l2"),
    ("A26", "R-GC13", CC, "fx.tree_info!(asks.map(|ask| ask.path))", "fx.tree_info!(asks.map(|ask| ask.path).take_first(2))", "l2 l3"),
    ("A27", "R-CM17", CS, "list! = |fx, args| match CacheView.read(args) {", "list! = |fx, args| match CacheView.read({ ..args, operands: [] }) {", "l2"),
    ("A28", "R-OUT2", CL, '" (${Toolchain.size_text(one.bytes)})"', '" [${Toolchain.size_text(one.bytes)}]"', "l0"),
    ("A29", "R-GC13", CC, "builds = if all Gc", "builds = if !all Gc", "l2 l2c"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def put():
    for f in FILES:
        shutil.copy(os.path.join(FINAL, os.path.basename(f)), os.path.join(ROOT, f))


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/cacheview.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/cacheview"
        if layer == "l2c":
            r = sh("tests/commands/run.sh clean/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 clean/"
        if layer == "l2":
            r = sh("tests/commands/run.sh cache/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 cache/"
        r = sh("tests/run.sh cache/cv", TIMEOUT["l3"])
        return r.returncode != 0, "l3 cache/cv"
    except subprocess.TimeoutExpired:
        return True, f"{layer} timeout"


def main():
    want = sys.argv[1:]
    os.makedirs(WORKD, exist_ok=True)
    results = []
    for entry in M:
        mid, rule, name, old, new = entry[:5]
        layers = os.environ.get("ONLY", entry[5]).split()
        if want and mid not in want:
            continue
        put()
        path = os.path.join(ROOT, name)
        text = open(path).read()
        if text.count(old) != 1:
            results.append((mid, rule, name, "BAD EDIT (%d matches)" % text.count(old), ""))
            print(mid, "BAD EDIT", text.count(old), flush=True)
            continue
        open(path, "w").write(text.replace(old, new))
        try:
            check = sh(f"{ROC} check cli/main.roc", 300)
            if check.returncode != 0 or "warning" in check.stdout.lower():
                results.append((mid, rule, name, "DID NOT COMPILE", check.stdout[:300].replace("\n", " ")))
                print(mid, "DID NOT COMPILE", check.stdout[:300].replace("\n", " "), flush=True)
                continue
            caught = ""
            for layer in layers:
                failed, what = run_layer(layer)
                if failed:
                    caught = what
                    break
            state = "caught" if caught else "NOT CAUGHT"
            results.append((mid, rule, name, state, caught))
            print(mid, rule, name, state, caught, flush=True)
        finally:
            put()
    put()
    same = all(filecmp.cmp(os.path.join(FINAL, os.path.basename(f)), os.path.join(ROOT, f), shallow=False) for f in FILES)
    print("final code restored, same:", same, flush=True)
    out = "agent-results.md" if not want else "agent-results-partial.md"
    with open(os.path.join(ROOT, "research/slice-029b-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
