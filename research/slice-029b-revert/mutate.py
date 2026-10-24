#!/usr/bin/env python3
"""Revert check of the tests of slice 029b (TW12), by the test agent. One small change at a time, filtered layers, one build after another.

Before each mutation the private reference (research/slice-029b-revert/reference/) is copied into cli/lib/, so a kill leaves the reference in place. At the end the stubs are copied back.
Layers: l0 = tests/unit/cacheview.roc, l2 = tests/commands/run.sh cache/, l3 = tests/run.sh cache/cv.
The first failing layer ends the run of a mutation (caught). A layer over its timeout counts as caught (a loop).
Usage (from the repo root): python3 -I research/slice-029b-revert/mutate.py [id ...]   (no id: all)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut029b"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15", JOBS="4")
REF = os.path.join(ROOT, "research/slice-029b-revert/reference")
STUBS = os.path.join(ROOT, "research/slice-029b-revert/stubs")
CV, CS = "cli/lib/CacheView.roc", "cli/lib/CacheShow.roc"
FILES = [CV, CS]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}

# id, rule, file, old text, new text, layers in order
M = [
    ("V01", "R-CM17", CV, "got ${many.len().to_str()}", "got ${(many.len() + 1).to_str()}", "l0"),
    ("V02", "R-CM17", CV, 'Str.join_with(args.command, " ")', '"cache"', "l0"),
    ("V03", "R-OUT2", CV, 'dir_report = |cache| ["${cache}\\n"]', 'dir_report = |cache| ["${cache}"]', "l0"),
    ("V04", "R-OUT4", CV, '("path", JsonDoc.Text(cache))', '("dir", JsonDoc.Text(cache))', "l0"),
    ("V05", "R-OUT2", CV, '["nothing to clean\\n"]', '["nothing to remove\\n"]', "l0"),
    ("V06", "R-OUT2", CV, 'items = listed.paths.map(|path| "${path}${size_suffix(listed.sizes, path)}\\n")', 'items = listed.paths.map(|path| "${path}\\n")', "l0"),
    ("V07", "R-OUT2", CV, "if listed.sizes.is_empty() items else", "if listed.paths.is_empty() items else", "l0"),
    ("V08", "R-OUT2", CV, '"total ${Toolchain', '"freed ${Toolchain', "l0"),
    ("V09", "R-OUT2", CV, "sum + one.bytes)", "sum + one.bytes + 1)", "l0"),
    ("V10", "R-OUT2", CV, 'items = listed.paths.map(|path| "${path}${size_suffix', 'items = listed.paths.rev().map(|path| "${path}${size_suffix', "l0"),
    ("V11", "R-OUT4", CV, "Err(_) => JsonDoc.Null", "Err(_) => JsonDoc.Num(0)", "l0"),
    ("V12", "R-OUT4", CV, '("total", JsonDoc.Num', '("sum", JsonDoc.Num', "l0"),
    ("V13", "R-OUT4", CV, '("path", JsonDoc.Text(path)), ("bytes"', '("item", JsonDoc.Text(path)), ("bytes"', "l0"),
    ("V14", "R-OUT4", CV, "JsonDoc.Num(total(listed).to_i64_wrap())", "JsonDoc.Num(listed.sizes.len().to_i64_wrap())", "l0"),
    ("V15", "R-OUT2", CV, 'if listed.paths.is_empty() {\n\t\t["nothing', 'if listed.sizes.is_empty() {\n\t\t["nothing', "l0"),
    ("S01", "R-LY1", CS, "print!(fx, args, CacheView.dir_report(roots.cache), CacheView.dir_data(roots.cache))", "print!(fx, args, CacheView.dir_report(roots.build), CacheView.dir_data(roots.build))", "l2 l3"),
    ("S02", "R-LY1", CS, "CacheView.dir_data(roots.cache))", "CacheView.dir_data(roots.build))", "l2 l3"),
    ("S03", "R-FL4", CS, "} else {\n\tfor line in lines {", "} else if !args.quiet {\n\tfor line in lines {", "l2 l3"),
    ("S04", "R-J3", CS, "\tfx.out!(Out.json_ok({ command: args.typed, data }))\n} else {", "\tfx.out!(Out.json_ok({ command: args.typed, data }))\n\tfor line in lines {\n\t\tfx.err!(line)\n\t}\n} else {", "l2"),
    ("S05", "R-GC13", CS, "Clean.asks({ roots, all: Bool.True, builds })", "Clean.asks({ roots, all: Bool.False, builds })", "l2 l3"),
    ("S06", "R-LY1", CS, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", "l2 l3"),
    ("S07", "R-CC10", CS, "\tbuilds = Gc.entries(", "\t_ = fx.lock!(Roots.item(roots, Gc), NoWait)\n\tbuilds = Gc.entries(", "l2"),
    ("S08", "R-CM17", CS, "\t\t\tOk(roots) => {\n\t\t\t\tprint!(fx, args, CacheView.dir_report", "\t\t\tOk(roots) => {\n\t\t\t\t_ = fx.make_dirs!([roots.cache])\n\t\t\t\tprint!(fx, args, CacheView.dir_report", "l2"),
    ("S09", "R-J3", CS, "command: args.typed", 'command: "cache"', "l2"),
    ("S10", "R-GC13", CS, "listed! = |fx| {\n", "listed! = |fx| {\n\t_ = fx.clock!()\n", "l2"),
    ("S11", "R-FL4", CS, "\t\t\t\tprint!(fx, args, CacheView.list_report(listed), CacheView.list_data(listed))", "\t\t\t\tprint!({ ..fx, out!: |text| if args.quiet {} else fx.out!(text) }, args, CacheView.list_report(listed), CacheView.list_data(listed))", "l2 l3"),
    ("S12", "R-CM17", CS, "Ok({}) => match listed!(fx) {", "Ok({}) => match listed!({ ..fx, tree_info!: |paths| fx.tree_info!(paths.take_first(2)) }) {", "l2 l3"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def put(src_dir):
    for f in FILES:
        shutil.copy(os.path.join(src_dir, os.path.basename(f)), os.path.join(ROOT, f))


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/cacheview.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/cacheview"
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
        put(REF)
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
            put(REF)
    put(STUBS)
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-029b-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
