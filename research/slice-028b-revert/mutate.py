#!/usr/bin/env python3
"""Revert check of the tests of slice 028b (TW12) against the private reference. Filtered runs only, one after another (no full sweep, no parallel roc builds).

For each mutation: put the reference (research/slice-028b-revert/reference) into cli/, change one small thing, `roc check cli/main.roc`, then run the layers of the mutation in order.
The first layer that fails ends the run of that mutation (caught). A layer over its timeout counts as caught (a loop). At the end the reference is put back.
Layers: l0 = tests/unit/gc.roc, l2 = tests/commands/run.sh gc/, l3 = tests/run.sh cache/gc1-real fx/tr1 (builds tln and fxprobe).

Usage (from the repo root): python3 -I research/slice-028b-revert/mutate.py [id ...]   (no id: all)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut028b"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15", JOBS="4")
REF = os.path.join(ROOT, "research/slice-028b-revert/reference")
FILES = ["cli/lib/Gc.roc", "cli/lib/CacheGc.roc", "cli/RealFiles.roc", "cli/lib/Toolchain.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
GC, CG, RF, TC = "cli/lib/Gc.roc", "cli/lib/CacheGc.roc", "cli/RealFiles.roc", "cli/lib/Toolchain.roc"

# id, rule, file, old text, new text, layers in order
M = [
    ("N01", "R-GC4", GC, "} else if facts.from_release {", "} else if facts.from_release and facts.file.is_empty() {", "l0"),
    ("N02", "R-GC4", GC, "Done(Text.sorted_unique(ids.keep_oks(", "Done(Text.sorted_unique(ids.drop_first(1).keep_oks(", "l0"),
    ("N03", "R-GC4", GC, "missing = ids.keep_if(|id| !have.contains(id))", "missing = ids.keep_if(|id| !have.contains(id) and !id.starts_with(\"/\"))", "l0"),
    ("N04", "R-GC4", GC, "Ok(_) => Ok(entry.value)\n", "Ok(_) => Err(Skip)\n", "l0"),
    ("N05", "R-GC4", GC, "Ok(text) => edges_of({ file: project.path, from_release: Bool.False, text })", "Ok(text) => edges_of({ file: project.path, from_release: Bool.True, text })", "l0"),
    ("N06", "R-GC4", GC, " and !Text.last_segment(e.path).contains(\".\") and", " and", "l0"),
    ("N07", "R-GC4", GC, " and !facts.protected.contains(Text.last_segment(e.path)))", ")", "l0"),
    ("N08", "R-GC3", GC, " and !facts.owned.contains(e.path))", ")", "l0"),
    ("N09", "R-GC2", GC, '["compat-", "nightly-", "debug-"]', '["compat-", "nightly-"]', "l0"),
    ("N10", "R-GC3", GC, "name.count_utf8_bytes() > prefix.count_utf8_bytes()", "name.count_utf8_bytes() >= prefix.count_utf8_bytes()", "l0"),
    ("N11", "R-GC4", GC, "Text.dir_of(e.path) == facts.roots.pkgs", "Text.dir_of(e.path) == facts.roots.cache", "l0"),
    ("N12", "R-GC11", GC, ".concat(plain(facts.compat))\n\t\t.concat(plain(facts.stale))", ".concat(plain(facts.stale))\n\t\t.concat(plain(facts.compat))", "l0"),
    ("N13", "R-GC9", GC, "Ok(tree) => is_over(tree.newest, facts.now, facts.span)", "Ok(tree) => is_over(tree.newest, facts.now, facts.span + 1)", "l0"),
    ("N14", "R-GC1", GC, "\t\t\t\tErr(_) => Bool.False\n\t\t\t}\n\t\t\tErr(_) => Bool.False", "\t\t\t\tErr(_) => Bool.True\n\t\t\t}\n\t\t\tErr(_) => Bool.False", "l0"),
    ("N15", "R-GC1", GC, "\t\t\t\tErr(_) => Bool.False\n\t\t\t}\n\t\t\tErr(_) => Bool.False", "\t\t\t\tErr(_) => Bool.False\n\t\t\t}\n\t\t\tErr(_) => Bool.True", "l0"),
    ("N16", "R-GC11", GC, "bytes: tree.size }", "bytes: tree.size + 1 }", "l0"),
    ("N17", "R-GC11", GC, "removed_sizes = |done| unique(done.toolchains", "removed_sizes = |done| (done.toolchains", "l0"),
    ("N18", "R-GC11", GC, 'if done.dry_run "would free" else "freed"', '"freed"', "l0"),
    ("N19", "R-GC11", GC, "total = if removed_sizes(done).is_empty() []", "total = if done.sizes.is_empty() []", "l0 l2"),
    ("N20", "R-OUT2", GC, "done.compat.concat(done.stale).concat(done.builds).concat(done.pkgs)", "done.compat.concat(done.builds).concat(done.stale).concat(done.pkgs)", "l0"),
    ("N21", "R-OUT4", GC, '("freed", JsonDoc.Num(Gc.freed(done).to_i64_wrap())),', '("freed", JsonDoc.Num(0)),', "l0"),
    ("N22", "R-OUT4", GC, "JsonDoc.Arr(removed_sizes(done).map(", "JsonDoc.Arr(done.sizes.map(", "l0"),
    ("N23", "R-GC3", CG, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", "l2"),
    ("N24", "R-GC4", CG, "protected = if has_pkgs protect!(fx, roots, known.live, []) else []", "protected = if has_pkgs or !known.live.is_empty() protect!(fx, roots, known.live, []) else []", "l2"),
    ("N25", "R-GC4", CG, "everything = stale.concat(builds)", "everything = builds.concat(stale)", "l2"),
    ("N26", "R-GC4", CG, '[dir, "${dir}.deps.json"]', "[dir]", "l2"),
    ("N27", "R-GC9", CG, "now: clocks.real, span: age })", "now: clocks.real, span: 2592000 })", "l2"),
    ("N28", "R-GC4", CG, "now: clocks.real, span: 86400 })", "now: clocks.real, span: age })", "l2"),
    ("N29", "R-EV22", CG, "now: clocks.real, span: age })", "now: clocks.now, span: age })", "l2"),
    ("N30", "R-GC3", CG, "protected, owned })", "protected, owned: [] })", "l2"),
    ("N31", "R-GC4", CG, "protect!(fx, roots, known.live, []) else []", "protect!(fx, roots, [], []) else []", "l2"),
    ("N32", "R-GC11", CG, "ran: Bool.True, toolchains: going, skipped: [], compat: owned, stale, builds, pkgs,", "ran: Bool.True, toolchains: going, skipped: [], compat: owned, stale, builds: [], pkgs,", "l2"),
    ("N33", "R-GC11", CG, "measured = if asked.is_empty() [] else asked.map2(", "measured = if asked.len() < 2 [] else asked.map2(", "l2"),
    ("N35", "R-GC1", RF, "sum + f.size", "sum + f.size + 1", "l3"),
    ("N36", "R-GC1", RF, "if f.time > top f.time else top", "if f.time < top f.time else top", "l3"),
    ("N37", "R-GC1", RF, "newest: (ns // 1_000_000_000).to_u64_wrap(), size: 0 })", "newest: (ns // 2_000_000_000).to_u64_wrap(), size: 0 })", "l3"),
    ("N38", "R-GC1", RF, "\tOk(IsFile) => match (Path.time_modified!(path), Path.size_in_bytes!(path)) {", "\tOk(IsFile) | Ok(IsSymLink) => match (Path.time_modified!(path), Path.size_in_bytes!(path)) {", "l3"),
    ("N39", "R-GC11", RF, "Err(PathErr(err, _)) => Err(RealBase.file_err(err))\n\tOk(IsFile)", "Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))\n\tOk(IsFile)", "l3"),
    ("S1", "R-GC11", TC, "} else if bytes < 999_950_000 {", "} else if bytes < 1_000_000_000 {", "l0t"),
    ("S2", "R-GC11", TC, "(bytes + 50_000_000) // 100_000_000", "bytes // 100_000_000", "l0t"),
    ("S3", "R-GC11", TC, 'tenths_text((bytes + 50_000_000) // 100_000_000)} GB"', 'tenths_text((bytes + 50_000_000) // 100_000_000)} MB"', "l0t"),
    ("S4", "R-GC11", TC, "} else if bytes < 999_950_000 {", "} else if bytes < 999_000_000 {", "l0t"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(REF, f), os.path.join(ROOT, f))


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0t":
            r = sh(f"{ROC} test tests/unit/toolchain.roc --no-cache", TIMEOUT["l0"])
            if r.returncode != 0:
                return True, "unit/toolchain"
            r = sh(f"{ROC} test tests/unit/gc.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/gc"
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/gc.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/gc"
        if layer == "l2":
            r = sh("tests/commands/run.sh gc/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 gc/"
        r = sh("tests/run.sh cache/gc1-real fx/tr1", TIMEOUT["l3"])
        return r.returncode != 0, "l3 cache/gc1-real fx/tr1"
    except subprocess.TimeoutExpired:
        return True, f"{layer} timeout"


def main():
    want = sys.argv[1:]
    os.makedirs(WORKD, exist_ok=True)
    results = []
    for entry in M:
        mid, rule, name, old, new = entry[:5]
        layers = entry[5].split()
        if want and mid not in want:
            continue
        restore()
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
                results.append((mid, rule, name, "DID NOT COMPILE", check.stdout[:200].replace("\n", " ")))
                print(mid, "DID NOT COMPILE", check.stdout[:200].replace("\n", " "), flush=True)
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
            restore()
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-028b-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
