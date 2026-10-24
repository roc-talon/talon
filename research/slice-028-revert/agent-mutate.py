#!/usr/bin/env python3
"""Revert check of the code of slice 028 part a (TW12), by the code agent. Filtered runs only (no full sweep).

For each mutation: restore code-final/ into cli/lib, change one small thing, `roc check cli/lib/main.roc`, then run the layers of the mutation in order.
The first layer that fails ends the run of that mutation (CAUGHT). A layer over its timeout counts as CAUGHT (a loop). At the end the code is restored and compared with code-final/.
Layers: l0 = tests/unit/{gc,temp,intent}.roc, l2 = tests/commands/run.sh gc/, l3 = tests/run.sh cache/gc1-real (builds tln, fxprobe, flowprobe).

Usage (from the repo root): python3 -I research/slice-028-revert/agent-mutate.py [id ...]
Output: one line for each mutation, and agent-results.md (agent-results-partial.md when ids are given).
"""
import filecmp, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut028"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15")
FINAL = os.path.join(ROOT, "research/slice-028-revert/code-final/cli/lib")
FILES = ["Gc", "CacheGc", "Intent", "Temp", "Trash", "Known", "Manage", "RocManage", "main"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
GC, CG, TE, IN, TR, KN = "Gc", "CacheGc", "Temp", "Intent", "Trash", "Known"

# id, rule, file, old text, new text, layers in order
M = [
    ("M01", "R-GC11", GC, "got ${many.len().to_str()}", "got ${(many.len() + 1).to_str()}", "l0 l2"),
    ("M02", "R-GC11", GC, 'name == "--dry-run"', 'name == "--json"', "l0 l2"),
    ("M03", "R-GC9", GC, "set ?? 2592000", "set ?? 604800", "l0 l2"),
    ("M04", "R-PD13", GC, "if is_over(entry.last_use, now, age) {", "if is_over(entry.last_use, now, age + 1) {", "l0 l2"),
    ("M05", "R-PD13", GC, "Err(NotFound) => Gone", "Err(NotFound) => Live", "l0 l2 l3"),
    ("M06", "R-PD12", GC, "\t\tErr(_) => Live\n", "\t\tErr(_) => Gone\n", "l0"),
    ("M07", "R-GC9", GC, "now > time and now - time > span", "now > time and now - time >= span", "l0"),
    ("M08", "R-PD13", GC, "\t\t\tErr(_) => Gone\n", "\t\t\tErr(_) => Live\n", "l0 l2"),
    ("M09", "R-GC5", GC, "row.kind == Link or row.kind == Copy", "row.kind == Link", "l0 l2"),
    ("M10", "R-GC5", GC, "} else if row.is_default {", "} else if row.is_default and row.id.is_empty() {", "l0 l2"),
    ("M11", "R-GC5", GC, "Err(Unknown) => Keep(NoTime)", "Err(Unknown) => Remove", "l0 l2"),
    ("M12", "R-CC10", GC, "Ok(used) => if !is_over(used, facts.now, 86400) {", "Ok(used) => if !is_over(used, facts.now, 3600) {", "l0 l2"),
    ("M13", "R-GC9", GC, "Err(Unknown) => row.installed_at", "Err(Unknown) => Err(Unknown)", "l0 l2"),
    ("M14", "R-GC5", GC, "} else if !Manage.pinned_by({ id: row.id, projects: facts.projects }).is_empty() {", "} else if !Manage.pinned_by({ id: row.id, projects: facts.projects }).is_empty() and row.id.is_empty() {", "l0 l2 l3"),
    ("M15", "R-GC9", GC, "} else if !is_over(used, facts.now, facts.age) {", "} else if !is_over(used, facts.now, 2592000) {", "l0 l3"),
    ("M16", "R-GC5", GC, "\t\t} else {\n\t\t\tRemove\n", "\t\t} else {\n\t\t\tKeep(Used)\n", "l0 l2"),
    ("M17", "R-CC2", GC, '"packages", "talon"', '"talon"', "l0 l2"),
    ("M18", "R-CC2", GC, "path: Text.join(dir, e.name)", 'path: Text.join(dir, "${e.name}x")', "l0"),
    ("M19", "R-GC11", GC, 'verb = if done.dry_run "would remove" else "removed"', 'verb = "removed"', "l0 l2"),
    ("M20", "R-CC10", GC, '["another tln cache gc runs\\n"]', '["another gc runs\\n"]', "l0 l2"),
    ("M21", "R-J3", GC, '("dry_run", JsonDoc.Flag(done.dry_run)),\n\t\t\t("ran", JsonDoc.Flag(done.ran)),', '("ran", JsonDoc.Flag(done.ran)),\n\t\t\t("dry_run", JsonDoc.Flag(done.dry_run)),', "l0 l2"),
    ("M22", "R-GC11", GC, 'nothing.append("dry run: nothing was removed\\n")', "nothing", "l0 l2"),
    ("M23", "R-CC10", GC, "toolchain ${id}: an install holds it", "toolchain ${id}: busy", "l0 l2"),
    ("M24", "R-GC6", TE, "\tregistry = !e.is_dir and name.ends_with", "\tregistry = name.ends_with", "l0"),
    ("M25", "R-GC6", TE, "or probe_copy or registry", "or probe_copy or (registry and name.is_empty())", "l0 l2"),
    ("M26", "R-GC9", IN, '"gc-age",\n\t\t\t\t|v|', '"gc-ages",\n\t\t\t\t|v|', "l0 l2"),
    ("M27", "R-GC9", IN, "gc_age: gc_age.value", "gc_age: Err(Unset)", "l0 l2"),
    ("M28", "R-EV22", CG, "now: clocks.real })", "now: clocks.now })", "l2 l3"),
    ("M29", "R-EV22", CG, "projects: known.live, now: clocks.now, age })", "projects: known.live, now: clocks.real, age })"),
    ("M30", "R-GC11", CG, "if plan.dry_run {\n\t\twork!", "if plan.dry_run and env.is_empty() {\n\t\twork!", "l2"),
    ("M31", "R-CC10", CG, "NoWait, || Trash.move!", "Wait, || Trash.move!", "l2 l3"),
    ("M32", "R-GC6", CG, "\t\t_ = fx.delete!(stale)\n", "\t\t_ = {}\n", "l2 l3"),
    ("M33", "R-PD13", CG, "\tprune!(fx, roots, { now: clocks.now, gone: known.gone })?\n", "", "l2 l3"),
    ("M34", "R-PD13", CG, "keep_if(|path| !facts.gone.contains(path))", "keep_if(|path| path.is_empty() or !facts.gone.contains(path)).concat(facts.gone)", "l2 l3"),
    ("M35", "R-CC10", CG, "Roots.item(roots, Gc), NoWait", "Roots.item(roots, Index), NoWait", "l2 l3"),
    ("M36", "R-CC10", CG, "Err(Busy) => Ok({ dry_run: Bool.False, ran: Bool.False,", "Err(Busy) => Ok({ dry_run: Bool.False, ran: Bool.True,", "l2 l3"),
    ("M37", "R-J3", CG, "shown = Common.shown_fx(fx, args)", "shown = fx", "l2"),
    ("M38", "R-CC10", CG, "\t\t\t\t$busy = $busy.append(each.id)\n", "\t\t\t\t$busy = $busy\n", "l2 l3"),
    ("M39", "R-GC3", CG, "$compat = $compat.concat(each.compat.map_ok(|c| [Roots.item(roots, Compat(c))]) ?? [])", "$compat = $compat", "l2 l3"),
    ("M40", "R-GC3", CG, "compat = going.keep_oks(|id| compat_of(id).map_ok(|c| Roots.item(roots, Compat(c))))", "compat = going.keep_oks(|id| compat_of(id).map_ok(|c| Roots.item(roots, Compat(c)))).drop_first(1)", "l2"),
    ("M41", "R-GC5", CG, "choice.verdict == Remove", 'choice.id != "git-dd03c09e" and choice.verdict == Remove', "l2"),
    ("M42", "R-GC3", TR, "_ = fx.delete!([trash].concat(compat_dir))", "_ = fx.delete!([trash].concat(compat_dir.drop_first(1)))", "l2 l3"),
    ("M43", "R-CC10", TR, "to: trash }) {", "to: facts.item }) {", "l2"),
    ("M44", "R-PD12", KN, "[Err(NotFound)] => Ok([])", '[Err(NotFound)] => Err(Fail.new(Environment, "no projects.json"))', "l2"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(FINAL, f + ".roc"), os.path.join(ROOT, "cli/lib", f + ".roc"))


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0":
            for f in ("gc", "temp", "intent"):
                r = sh(f"{ROC} test tests/unit/{f}.roc --no-cache", TIMEOUT["l0"])
                if r.returncode != 0:
                    return True, f"unit/{f}"
            return False, ""
        if layer == "l2":
            r = sh("tests/commands/run.sh gc/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 gc/"
        r = sh("tests/run.sh cache/gc1-real", TIMEOUT["l3"])
        return r.returncode != 0, "l3 cache/gc1-real"
    except subprocess.TimeoutExpired:
        return True, f"{layer} timeout"


def main():
    want = sys.argv[1:]
    os.makedirs(WORKD, exist_ok=True)
    restore()
    results = []
    for entry in M:
        mid, rule, name, old, new = entry[:5]
        layers = entry[5].split() if len(entry) > 5 else ["l2"]
        if want and mid not in want:
            continue
        restore()
        path = os.path.join(ROOT, "cli/lib", name + ".roc")
        text = open(path).read()
        if text.count(old) != 1:
            results.append((mid, rule, name, "BAD EDIT (%d matches)" % text.count(old), ""))
            print(mid, "BAD EDIT", text.count(old), flush=True)
            continue
        open(path, "w").write(text.replace(old, new))
        try:
            check = sh(f"{ROC} check cli/lib/main.roc", 300)
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
    same = all(filecmp.cmp(os.path.join(FINAL, f + ".roc"), os.path.join(ROOT, "cli/lib", f + ".roc"), shallow=False) for f in FILES)
    print("code equals code-final:", same, flush=True)
    out = "agent-results.md" if not want else "agent-results-partial.md"
    with open(os.path.join(ROOT, "research/slice-028-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
