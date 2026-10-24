#!/usr/bin/env python3
"""Revert check of the code of slice 029 (TW12), by the code agent. One small change at a time, filtered layers, one build after another.

Before each mutation the final code (research/slice-029-revert/code-final/) is copied into cli/, so a kill leaves the final code in place. At the end it is copied back and compared.
Layers: l0 = tests/unit/clean.roc and consent.roc, l2 = tests/commands/run.sh clean/, l3 = tests/run.sh cache/cl.
The first failing layer ends the run of a mutation (caught). A layer over its timeout counts as caught (a loop).
Usage (from the repo root): python3 -I research/slice-029-revert/agent-mutate.py [id ...]   (no id: all)
"""
import filecmp, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut029"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15", JOBS="4")
FINAL = os.path.join(ROOT, "research/slice-029-revert/code-final")
FILES = ["cli/lib/Gc.roc", "cli/lib/Clean.roc", "cli/lib/CacheClean.roc", "cli/lib/Consent.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
GC, CL, CC, CO = FILES

# id, rule, file, old text, new text, layers in order
M = [
    ("M01", "R-GC13", CL, 'flag_set(args, "--all")', 'flag_set(args, "--al")', "l0"),
    ("M02", "R-GC14", CL, 'flag_set(args, "--dry-run")', 'flag_set(args, "--dryrun")', "l0"),
    ("M03", "R-CM17", CL, "got ${many.len().to_str()}", "got ${(many.len() + 1).to_str()}", "l0"),
    ("M04", "R-GC12", CL, '[Roots.item(facts.roots, Index), Text.join(facts.roots.cache, "talon/x")]', '[Text.join(facts.roots.cache, "talon/x"), Roots.item(facts.roots, Index)]', "l0"),
    ("M05", "R-GC13", CL, "always.append(facts.roots.pkgs).concat(", "always.concat(", "l0"),
    ("M06", "R-GC13", CL, "keep_if(|one| one.is_dir and Gc.is_build_name", "keep_if(|one| Gc.is_build_name", "l0"),
    ("M07", "R-GC13", CL, "concat(Text.sorted_unique(dirs))", "concat(dirs)", "l0"),
    ("M08", "R-GC13", CL, "if facts.all always.append", "if facts.all or !facts.builds.is_empty() always.append", "l0"),
    ("M09", "R-GC13", CL, "Gc.is_build_name(Text.last_segment(one.path))", 'Text.last_segment(one.path).starts_with("compat-")', "l0"),
    ("M10", "R-GC12", CL, 'Text.join(facts.roots.cache, "talon/x")]', 'Text.join(facts.roots.cache, "talon/xx")]', "l0"),
    ("M11", "R-GC14", CL, "Err(NotFound) => Bool.False\n\t\t\t\t_ => Bool.True", "Err(NotFound) => Bool.True\n\t\t\t\t_ => Bool.True", "l0"),
    ("M12", "R-GC14", CL, "Err(NotFound) => Bool.False\n\t\t\t\t_ => Bool.True", "Err(NotFound) => Bool.False\n\t\t\t\tOk(_) => Bool.True\n\t\t\t\tErr(_) => Bool.False", "l0"),
    ("M13", "R-GC14", CL, "Nothing | Declined => 0\n\t\tDryRun | Removed", "Nothing => 0\n\t\tDeclined | DryRun | Removed", "l0"),
    ("M14", "R-GC14", CL, "total + one.bytes)", "total + one.bytes + 1)", "l0"),
    ("M15", "R-GC14", CL, 'lines(done, "would remove", "would free")', 'lines(done, "removed", "would free")', "l0"),
    ("M16", "R-GC14", CL, 'append("dry run: nothing was removed\\n")', 'append("dry run: nothing removed\\n")', "l0"),
    ("M17", "R-GC14", CL, "if done.sizes.is_empty() items", "if done.paths.is_empty() items", "l0"),
    ("M18", "R-GC14", CL, 'Declined => ["nothing was removed\\n"]', 'Declined => ["nothing to remove\\n"]', "l0"),
    ("M19", "R-J3", CL, '("removed", JsonDoc.Flag(done.outcome == Removed))', '("removed", JsonDoc.Flag(done.outcome != Nothing))', "l0"),
    ("M20", "R-OUT4", CL, "Err(_) => JsonDoc.Null", "Err(_) => JsonDoc.Num(0)", "l0"),
    ("M21", "R-GC14", CL, "Err(NotFound) => Err(Skip)", 'Err(NotFound) => Ok("gone")', "l0"),
    ("M22", "R-GC14", CL, "Fail.new(Environment, first)", "Fail.new(Internal, first)", "l0"),
    ("M23", "R-GC14", CL, "match failures {", "match failures.rev() {", "l0"),
    ("M24", "R-NI7", CO, 'id: "cache-clean",\n\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: Yes,', 'id: "cache-clean",\n\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: No,', "l0"),
    ("M25", "R-NR3", CO, 'id: "cache-clean",\n\t\t\tkind: Default,', 'id: "cache-clean",\n\t\t\tkind: Required(["--yes"]),', "l0"),
    ("M26", "R-NR2", CO, 'question: "Remove ${what}, ${size}?",', 'question: "Remove ${what}?",', "l0"),
    ("M27", "R-NI7", CO, 'plural(facts.count, "dir", "dirs")', 'plural(facts.count, "dirs", "dirs")', "l0"),
    ("M28", "R-GC13", GC, '["compat-", "nightly-", "debug-"].any(|prefix| name.starts_with(prefix) and name.count_utf8_bytes() > prefix', '["compat-", "nightly-"].any(|prefix| name.starts_with(prefix) and name.count_utf8_bytes() > prefix', "l0"),
    ("M29", "R-GC13", GC, "name.count_utf8_bytes() > prefix.count_utf8_bytes())", "name.count_utf8_bytes() >= prefix.count_utf8_bytes())", "l0"),
    ("W01", "R-GC13", CC, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", "l2 l3"),
    ("W02", "R-GC14", CC, "} else if plan.dry_run {", "} else if plan.dry_run and plan.all {", "l2 l3"),
    ("W03", "R-GC14", CC, "if found.paths.is_empty() {", "if found.paths.is_empty() and plan.all {", "l2"),
    ("W04", "R-NR1", CC, "json: args.json })", "json: Bool.False })", "l2"),
    ("W05", "R-NM8", CC, "yes: args.yes,", "yes: Bool.False,", "l2 l3"),
    ("W06", "R-J3", CC, "shown = Common.shown_fx(fx, args)", "shown = fx", "l2"),
    ("W07", "R-GC14", CC, "fx.delete!(paths)", "fx.delete!(paths.rev())", "l2"),
    ("W08", "R-NI7", CC, "if asked.answer == Yes {", "if asked.answer != Yes {", "l2 l3"),
    ("W09", "R-NR2", CC, "size: Clean.freed(done) })", "size: 0 })", "l2"),
    ("W10", "R-GC12", CC, "builds = if plan.all Gc.entries", "builds = if plan.all or plan.dry_run Gc.entries", "l2"),
    ("W11", "R-GC14", CC, "\t\t\tremove!(fx, roots, found.paths)?\n", "\t\t\t_ = remove!(fx, roots, found.paths)\n", "l2"),
    ("W12", "R-J3", CC, "if args.json {\n\t\tfx.out!(", "if args.json and !args.quiet {\n\t\tfx.out!(", "l2"),
    ("W13", "R-GC14", CC, "Ok({ ..done, outcome: Declined })", "Ok(done)", "l2 l3"),
    ("W14", "R-GC12", CC, "infos = fx.tree_info!(asks.map(|ask| ask.path))", 'infos = fx.tree_info!(asks.map(|ask| ask.path).keep_if(|path| !path.ends_with("/talon/x")))', "l2"),
    ("W15", "R-LY1", CC, "roots = Roots.from_env(env)?", 'roots = Roots.from_env(env.keep_if(|(name, _)| name != "ROC_CACHE_DIR"))?', "l2 l3"),
    ("W16", "R-NM6", CC, "flag: Err(NoFlag) })?", "flag: Ok(Yes) })?", "l2 l3"),
    ("W17", "R-NI7", CC, "count: found.paths.len(),", "count: found.sizes.len(),", "l2 l3"),
    ("K01", "R-CC10", CC, "remove! = |fx, roots, paths| fx.locked!(\n\tRoots.item(roots, Gc),\n\t|| {\n\t\tresults = fx.delete!(paths)\n\t\tClean.check({ paths, results })\n\t},\n)", "remove! = |fx, roots, paths| {\n\t_ = Roots.item(roots, Gc)\n\tClean.check({ paths, results: fx.delete!(paths) })\n}", "l2"),
    ("K02", "R-CC10", CC, "\tRoots.item(roots, Gc),\n\t||", "\tRoots.item(roots, ProjectsJson),\n\t||", "l2"),
    ("K03", "R-CC3", CC, "asked = Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })?", "asked = fx.locked!(Roots.item(roots, Gc), || Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) }))?", "l2"),
    ("K04", "R-CC10", CC, "\t\tOk({ ..done, outcome: DryRun })", "\t\t_ = fx.locked!(Roots.item(roots, Gc), || Ok({}))\n\t\tOk({ ..done, outcome: DryRun })", "l2"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(FINAL, f), os.path.join(ROOT, f))


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/clean.roc --no-cache", TIMEOUT["l0"])
            if r.returncode != 0:
                return True, "unit/clean"
            r = sh(f"{ROC} test tests/unit/consent.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/consent"
        if layer == "l2":
            r = sh("tests/commands/run.sh clean/", TIMEOUT["l2"])
            return r.returncode != 0, "l2 clean/"
        r = sh("tests/run.sh cache/cl", TIMEOUT["l3"])
        return r.returncode != 0, "l3 cache/cl"
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
    same = all(filecmp.cmp(os.path.join(FINAL, f), os.path.join(ROOT, f), shallow=False) for f in FILES)
    print("code equals code-final:", same, flush=True)
    out = "agent-results.md" if not want else "agent-results-partial.md"
    with open(os.path.join(ROOT, "research/slice-029-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
