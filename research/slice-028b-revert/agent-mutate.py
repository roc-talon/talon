#!/usr/bin/env python3
"""Revert check of the code of slice 028b (TW12), by the code agent. Filtered runs only, one after another (no full sweep, no parallel roc builds).

For each mutation: put code-final/ into cli/, change one small thing, `roc check cli/main.roc`, then run the layers of the mutation in order.
The first layer that fails ends the run of that mutation (caught). A layer over its timeout counts as caught (a loop). At the end the code is put back and compared with code-final/.
Layers: l0 = tests/unit/gc.roc, l2 = tests/commands/run.sh gc/, l3 = tests/run.sh cache/gc1-real fx/tr1 (builds tln and fxprobe).

Usage (from the repo root): python3 -I research/slice-028b-revert/agent-mutate.py [id ...]   (no id: all)
"""
import filecmp, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut028b-agent"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15", JOBS="4")
REF = os.path.join(ROOT, "research/slice-028b-revert/code-final")
FILES = ["cli/lib/Gc.roc", "cli/lib/CacheGc.roc", "cli/RealFiles.roc", "cli/lib/Toolchain.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
GC, CG, RF, TC = "cli/lib/Gc.roc", "cli/lib/CacheGc.roc", "cli/RealFiles.roc", "cli/lib/Toolchain.roc"

# id, rule, file, old text, new text, layers in order
L = "l0 l2 l3"
L2 = "l2 l3"
L3 = "l3"
M = [
    ("G01", "R-GC4", GC, "release: Ident.of_url(node.id).is_ok() })", "release: Bool.False })", L),
    ("G02", "R-GC4", GC, "Done(Text.sorted_unique(edges.keep_oks(|id| Ident.of_url(id).map_ok(|ident| ident.hash))))", "Done(edges.keep_oks(|id| Ident.of_url(id).map_ok(|ident| ident.hash)))", L),
    ("G03", "R-GC4", GC, "need = once(edges.keep_if(|id| !known.contains(id)))", "need = edges.keep_if(|id| !known.contains(id))", L),
    ("G04", "R-GC4", GC, 'else if facts.value.contains("://") or facts.release {', "else if facts.release {", L),
    ("C01", "R-GC4", GC, '!name.contains(".") and !facts.protected.contains(name)', "!facts.protected.contains(name)", L),
    ("C02", "R-GC4", GC, '!name.contains(".") and !facts.protected.contains(name)', '!name.contains(".")', L),
    ("C03", "R-GC4", GC, "Text.dir_of(one.path) == facts.roots.pkgs", "Text.dir_of(one.path) == facts.roots.build", L),
    ("C05", "R-GC3", GC, " and !facts.owned.contains(one.path))", ")", L),
    ("C06", "R-GC3", GC, "name.count_utf8_bytes() > prefix.count_utf8_bytes()", "name.count_utf8_bytes() >= prefix.count_utf8_bytes()", L),
    ("A01", "R-GC11", GC, ".concat(facts.compat.concat(facts.stale).concat(facts.builds).concat(facts.pkgs)", ".concat(facts.stale.concat(facts.compat).concat(facts.builds).concat(facts.pkgs)", L),
    ("E01", "R-GC9", GC, "Ok(tree) => is_over(tree.newest, facts.now, facts.span)", "Ok(tree) => is_over(tree.newest, facts.now, facts.span + 1)", L),
    ("E02", "R-GC1", GC, "\t\t\t\tErr(_) => Bool.False\n\t\t\t}\n\t\t\tErr(_) => Bool.False", "\t\t\t\tErr(_) => Bool.True\n\t\t\t}\n\t\t\tErr(_) => Bool.False", L),
    ("S01", "R-GC11", GC, "bytes: tree.size }", "bytes: tree.size + 1 }", L),
    ("F01", "R-GC11", GC, "counted = |done| once(done.toolchains.concat(paths_of(done)))", "counted = |done| (done.toolchains.concat(paths_of(done)))", L),
    ("R01", "R-GC11", GC, 'if done.dry_run "would free', 'if !done.dry_run "would free', L),
    ("R02", "R-OUT2", GC, 'nothing.concat(total).append("dry run: nothing was removed\\n")', 'nothing.append("dry run: nothing was removed\\n").concat(total)', L),
    ("R03", "R-GC11", GC, "total = if counted(done).is_empty() {", "total = if done.sizes.is_empty() {", L),
    ("R04", "R-OUT2", GC, "done.compat.concat(done.stale).concat(done.builds).concat(done.pkgs)", "done.compat.concat(done.builds).concat(done.stale).concat(done.pkgs)", L),
    ("D01", "R-OUT4", GC, '("freed", JsonDoc.Num(Gc.freed(done).to_i64_wrap())),', '("freed", JsonDoc.Num(0)),', L),
    ("W01", "R-GC3", CG, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", L2),
    ("W02", "R-GC4", CG, "if open.pkgs.is_empty() [] else", "if open.pkgs.is_empty() and facts.live.is_empty() [] else", L2),
    ("W03", "R-GC4", CG, "gone = stale.concat(aged.builds)", "gone = aged.builds.concat(stale)", L2),
    ("W04", "R-GC4", CG, '[dir, "${dir}.deps.json"]', "[dir]", L2),
    ("W05", "R-GC9", CG, "span: facts.age })", "span: 2592000 })", L2),
    ("W06", "R-EV22", CG, "now: facts.clocks.real, span: facts.age })", "now: facts.clocks.now, span: facts.age })", L2),
    ("W07", "R-GC3", CG, "builds: facts.builds, protected: facts.protected, owned: facts.compat })", "builds: facts.builds, protected: facts.protected, owned: [] })", L2),
    ("W08", "R-GC4", CG, "protect!(fx, roots, { live: known.live, entries })", "protect!(fx, roots, { live: [], entries })", L2),
    ("W09", "R-GC11", CG, "compat, stale, builds: aged.builds, pkgs: aged.pkgs, projects: known.gone, sizes: aged.sizes })\n\t}", "compat, stale, builds: [], pkgs: aged.pkgs, projects: known.gone, sizes: aged.sizes })\n\t}", L2),
    ("W10", "R-GC4", CG, "ids.map(|id| Gather.file_of(roots, id))", "ids", L2),
    ("W11", "R-GC1", CG, "if !gone.is_empty() {", "if gone.is_empty() {", L2),
    ("W12", "R-GC4", CG, "Gc.expired({ dirs: candidates.pkgs,", "Gc.expired({ dirs: candidates.builds,", L2),
    ("W14", "R-GC11", CG, "sizes: Gc.sizes(measured),", "sizes: [],", L2),
    ("T01", "R-GC11", RF, "sum + one.size", "sum + one.size + 1", L3),
    ("T02", "R-GC3", RF, "if one.time > top one.time else top", "if one.time < top one.time else top", L3),
    ("T03", "R-GC3", RF, "Ok(IsDir) => Ok({ newest: seconds_of!(Path.utf8(text)), size: 0 })", "Ok(IsDir) => Ok({ newest: 0, size: 0 })", L3),
    ("T04", "R-GC4", RF, "Ok(IsFile) => Ok([{ time: seconds_of!(path), size: bytes_of!(path) }])", "Ok(IsFile) | Ok(IsSymLink) => Ok([{ time: seconds_of!(path), size: bytes_of!(path) }])", L3),
    ("T05", "R-GC4", RF, "Err(PathErr(err, _)) => Err(RealBase.file_err(err))\n\t\tOk(IsFile)", "Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))\n\t\tOk(IsFile)", L3),
    ("T06", "R-GC11", RF, "Err(err) => return Err(err)", "Err(_) => {}", L3),
    ("Z01", "R-GC11", TC, "} else if bytes < 999_950_000 {", "} else if bytes < 1_000_000_000 {", "l0t"),
    ("Z02", "R-GC11", TC, "(bytes + 50_000_000) // 100_000_000", "bytes // 100_000_000", "l0t"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(REF, f), os.path.join(ROOT, f))


def same():
    return all(filecmp.cmp(os.path.join(REF, f), os.path.join(ROOT, f), shallow=False) for f in FILES)


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
    restore()
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
    print("code equals code-final:", same(), flush=True)
    out = "agent-results.md" if not want else "agent-results-partial.md"
    with open(os.path.join(ROOT, "research/slice-028b-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
