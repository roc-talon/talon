#!/usr/bin/env python3
"""Revert check of the tests of slice 029 (TW12) against the private reference. Filtered runs only, one after another (no full sweep, no parallel roc builds).

For each mutation: put the reference (research/slice-029-revert/reference) into cli/, change one small thing, `roc check cli/main.roc`, then run the layers of the mutation in order.
The first layer that fails ends the run of that mutation (caught). A layer over its timeout counts as caught (a loop). At the end the reference is put back (and swap.sh stub puts the stubs).
Layers: l0 = tests/unit/clean.roc and consent.roc, l2 = tests/commands/run.sh clean/, l3 = tests/run.sh cache/cl (builds tln and fxprobe).

Usage (from the repo root): python3 -I research/slice-029-revert/mutate.py [id ...]   (no id: all)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work/mut029"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15", JOBS="4")
REF = os.path.join(ROOT, "research/slice-029-revert/reference")
FILES = ["cli/lib/Gc.roc", "cli/lib/Clean.roc", "cli/lib/CacheClean.roc", "cli/lib/Consent.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
GC, CL, CC, CO = FILES

# id, rule, file, old text, new text, layers in order
M = [
    ("C01", "R-GC13", CL, 'name == "--all")', 'name == "--al")', "l0"),
    ("C02", "R-GC14", CL, 'name == "--dry-run")', 'name == "--dryrun")', "l0"),
    ("C03", "R-CM17", CL, "got ${many.len().to_str()}", "got ${(many.len() + 1).to_str()}", "l0"),
    ("C04", "R-GC12", CL, '[Roots.item(facts.roots, Index), Text.join(facts.roots.cache, "talon/x")]', '[Text.join(facts.roots.cache, "talon/x"), Roots.item(facts.roots, Index)]', "l0"),
    ("C05", "R-GC13", CL, "[facts.roots.pkgs].concat(Text.sorted_unique(dirs))", "[].concat(Text.sorted_unique(dirs))", "l0"),
    ("C06", "R-GC13", CL, "keep_if(|one| one.is_dir and Gc.is_build_name", "keep_if(|one| Gc.is_build_name", "l0"),
    ("C07", "R-GC13", CL, "[facts.roots.pkgs].concat(Text.sorted_unique(dirs))", "[facts.roots.pkgs].concat(dirs)", "l0"),
    ("C08", "R-GC13", CL, "more = if facts.all {", "more = if facts.all or !facts.builds.is_empty() {", "l0"),
    ("C09", "R-GC13", CL, "Gc.is_build_name(Text.last_segment(one.path))", 'Text.last_segment(one.path).starts_with("compat-")', "l0"),
    ("C10", "R-GC12", CL, 'Text.join(facts.roots.cache, "talon/x")]', 'Text.join(facts.roots.cache, "talon/xx")]', "l0"),
    ("C11", "R-GC14", CL, "Err(NotFound) => Bool.False\n\t\t\t\t_ => Bool.True", "Err(NotFound) => Bool.True\n\t\t\t\t_ => Bool.True", "l0"),
    ("C12", "R-GC14", CL, "Err(NotFound) => Bool.False\n\t\t\t\t_ => Bool.True", "Err(NotFound) => Bool.False\n\t\t\t\tOk(_) => Bool.True\n\t\t\t\tErr(_) => Bool.False", "l0"),
    ("C13", "R-GC14", CL, "Nothing | Declined => 0", "Nothing => 0", "l0"),
    ("C14", "R-GC14", CL, "total + one.bytes)", "total + one.bytes + 1)", "l0"),
    ("C15", "R-GC14", CL, 'verb = if done.outcome == DryRun "would remove" else "removed"', 'verb = "removed"', "l0"),
    ("C16", "R-GC14", CL, 'append("dry run: nothing was removed\\n")', 'append("dry run: nothing removed\\n")', "l0"),
    ("C17", "R-GC14", CL, "total = if done.sizes.is_empty() {", "total = if done.paths.is_empty() {", "l0"),
    ("C18", "R-GC14", CL, 'Declined => ["nothing was removed\\n"]', 'Declined => ["nothing to remove\\n"]', "l0"),
    ("C19", "R-GC14", CL, '[if done.outcome == DryRun "would free ', '[if done.outcome == DryRun "would free: ', "l0"),
    ("C20", "R-J3", CL, '("removed", JsonDoc.Flag(done.outcome == Removed))', '("removed", JsonDoc.Flag(done.outcome != Nothing))', "l0"),
    ("C21", "R-OUT4", CL, "Err(_) => JsonDoc.Null", "Err(_) => JsonDoc.Num(0)", "l0"),
    ("C22", "R-GC14", CL, "Err(NotFound) => Err(Skip)", 'Err(NotFound) => Ok(Fail.new(Environment, "gone"))', "l0"),
    ("C23", "R-GC14", CL, "Fail.new(Environment, \"cannot remove", "Fail.new(Internal, \"cannot remove", "l0"),
    ("C24", "R-GC14", CL, "match bad.first() {", "match bad.last() {", "l0"),
    ("C25", "R-NI7", CO, 'id: "cache-clean",\n\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: Yes,', 'id: "cache-clean",\n\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: No,', "l0"),
    ("C26", "R-NR3", CO, 'id: "cache-clean",\n\t\t\tkind: Default,', 'id: "cache-clean",\n\t\t\tkind: Required(["--yes"]),', "l0"),
    ("C27", "R-NR2", CO, 'question: "Remove ${what}, ${size}?",', 'question: "Remove ${what}?",', "l0"),
    ("C28", "R-NI7", CO, 'plural(facts.count, "dir", "dirs")', 'plural(facts.count, "dirs", "dirs")', "l0"),
    ("W01", "R-GC13", CC, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", "l2 l3"),
    ("W02", "R-GC14", CC, "if plan.dry_run return Ok(done(DryRun))", "if plan.dry_run and plan.all and found.paths.is_empty() return Ok(done(DryRun))", "l2 l3"),
    ("W03", "R-GC14", CC, "if found.paths.is_empty() return Ok(done(Nothing))", "if found.paths.is_empty() and plan.all return Ok(done(Nothing))", "l2"),
    ("W04", "R-NR1", CC, "json: args.json })", "json: Bool.False })", "l2"),
    ("W05", "R-NM8", CC, "yes: args.yes,", "yes: Bool.False,", "l2 l3"),
    ("W06", "R-J3", CC, "shown = Common.shown_fx(fx, args)", "shown = fx", "l2"),
    ("W07", "R-GC14", CC, "fx.delete!(found.paths)", "fx.delete!(found.paths.rev())", "l2"),
    ("W08", "R-NI7", CC, "if asked.answer == Yes {", "if asked.answer != Yes {", "l2 l3"),
    ("W09", "R-NR2", CC, "size: Clean.freed(done(Removed))", "size: 0", "l2"),
    ("W10", "R-GC12", CC, "builds = if plan.all Gc.entries", "builds = if plan.all or plan.dry_run Gc.entries", "l2"),
    ("W11", "R-GC14", CC, "fx.locked!(Roots.item(roots, Gc), || Clean.check({ paths: found.paths, results: fx.delete!(found.paths) }))?", "_ = fx.locked!(Roots.item(roots, Gc), || Clean.check({ paths: found.paths, results: fx.delete!(found.paths) }))", "l2"),
    ("W12", "R-J3", CC, "if args.json {\n\t\tfx.out!(", "if args.json and !args.quiet {\n\t\tfx.out!(", "l2"),
    ("W13", "R-GC14", CC, "Ok(done(Declined))", "Ok(done(Removed))", "l2 l3"),
    ("W14", "R-GC12", CC, "infos = fx.tree_info!(asks.map(|ask| ask.path))", "infos = fx.tree_info!(asks.map(|ask| ask.path).keep_if(|path| !path.ends_with(\"/talon/x\")))", "l2"),
    ("W15", "R-NI7", CC, "quiet: args.quiet,", "quiet: Bool.True,", "l2"),
    ("W16", "R-GC13", CC, "roots = Roots.from_env(env)?", "roots = Roots.from_env(env.keep_if(|(name, _)| name != \"ROC_CACHE_DIR\"))?", "l2 l3"),
    ("L01", "R-GC13", CC, "fx.list_dirs!([roots.build])", "fx.list_dirs!([roots.cache])", "l3"),
    ("L02", "R-NI7", CC, "if asked.answer == Yes {", "if asked.answer != Yes {", "l3"),
    ("L03", "R-GC13", CC, "roots = Roots.from_env(env)?", "roots = Roots.from_env(env.keep_if(|(name, _)| name != \"ROC_CACHE_DIR\"))?", "l3"),
    ("L04", "R-NM8", CC, "yes: args.yes,", "yes: Bool.False,", "l3"),
    ("L05", "R-GC14", CC, "Ok(done(Declined))", "Ok(done(Removed))", "l3"),
    ("L06", "R-GC14", CC, "if plan.dry_run return Ok(done(DryRun))", "if plan.dry_run and plan.all and found.paths.is_empty() return Ok(done(DryRun))", "l3"),
    ("K01", "R-CC10", CC, 'fx.locked!(Roots.item(roots, Gc), || Clean.check({ paths: found.paths, results: fx.delete!(found.paths) }))?', "Clean.check({ paths: found.paths, results: fx.delete!(found.paths) })?", "l2"),
    ("K02", "R-CC10", CC, "fx.locked!(Roots.item(roots, Gc),", "fx.locked!(Roots.item(roots, ProjectsJson),", "l2"),
    ("K03", "R-CC3", CC, "asked = Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })?", "asked = fx.locked!(Roots.item(roots, Gc), || Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) }))?", "l2"),
    ("K04", "R-CC10", CC, "if plan.dry_run return Ok(done(DryRun))", "if plan.dry_run {\n\t\t_ = fx.locked!(Roots.item(roots, Gc), || Ok({}))\n\t\treturn Ok(done(DryRun))\n\t}", "l2"),
    ("G01", "R-GC13", GC, '["compat-", "nightly-", "debug-"]', '["compat-", "nightly-"]', "l0"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def restore():
    for f in FILES:
        shutil.copy(os.path.join(REF, f), os.path.join(ROOT, f))


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
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-029-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
