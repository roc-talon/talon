#!/usr/bin/env python3
"""Revert check of the private reference (TW12): each mutation changes one small thing in the reference code (which is in cli/lib/ while this runs),
then runs the layers that should catch it. The file is put back after each one. Filtered runs only (no full sweep).
Usage: python3 -I research/slice-028-revert/mutate.py [id ...]   Output: one line per mutation, and results.md (results-partial.md with ids).
The reference must be in cli/lib/ (`research/slice-028-revert/swap.sh ref`). WORK is .work-028."""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work-028"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="15")
GC = "cli/lib/Gc.roc"
CG = "cli/lib/CacheGc.roc"
TE = "cli/lib/Temp.roc"
IN = "cli/lib/Intent.roc"

# id, file, old text, new text, layers that must catch it (l0, l2, l3)
M = [
    ("M01", GC, 'tln cache gc takes no operand, got ${many.len().to_str()}', 'tln cache gc takes no operand, got ${(many.len() + 1).to_str()}', "l0 l2"),
    ("M02", GC, 'flag == "--dry-run"', 'flag == "--json"', "l0 l2 l3"),
    ("M03", GC, 'Err(Unset) => 2592000', 'Err(Unset) => 604800', "l0 l2"),
    ("M04", GC, 'stays: !is_older(entry.last_use, facts.now, facts.age) and has_header(entry.path, got)', 'stays: has_header(entry.path, got)', "l0 l2 l3"),
    ("M05", GC, 'Err(NotFound) => Bool.False', 'Err(NotFound) => Bool.True', "l0 l2 l3"),
    ("M06", GC, 'Err(_) => Bool.True\n}', 'Err(_) => Bool.False\n}', "l0"),
    ("M07", GC, 'now > at and now - at > limit', 'now > at and now - at >= limit', "l0"),
    ("M08", GC, '(Link, _) | (Copy, _) => Keep(Hand)', '(Link, _) => Keep(Hand)', "l0 l2"),
    ("M09", GC, '''if row.is_default {
				Keep(Default)
			} else if''', '''if row.is_default and row.id.is_empty() {
				Keep(Default)
			} else if''', "l0 l2 l3"),
    ("M10", GC, 'else Keep(NoTime)', 'else Remove', "l0 l2"),
    ("M11", GC, '!is_older(at, facts.now, 86400)', '!is_older(at, facts.now, 3600)', "l0 l2"),
    ("M12", GC, 'Err(Unknown) => row.installed_at', 'Err(Unknown) => Err(Unknown)', "l0 l2"),
    ("M13", GC, '} else if pinned {', '} else if pinned and !is_older(at, facts.now, facts.age) {', "l0 l2 l3"),
    ("M14", GC, 'pinned = !Manage.pinned_by({ id: row.id, projects: facts.projects }).is_empty()', 'pinned = !Manage.pinned_by({ id: row.id, projects: facts.projects }).is_empty() and row.id.is_empty()', "l0 l2 l3"),
    ("M15", GC, '\t\troots.pkgs,\n', '', "l0 l2"),
    ("M16", GC, 'path: Text.join(dir, e.name)', 'path: Text.join(dir, "${e.name}x")', "l0"),
    ("M17", GC, 'verb = if done.dry_run "would remove" else "removed"', 'verb = "removed"', "l0 l2 l3"),
    ("M18", GC, '["another tln cache gc runs\\n"]', '["another gc runs\\n"]', "l0 l2 l3"),
    ("M19", GC, '("dry_run", JsonDoc.Flag(done.dry_run)),\n\t\t\t("ran", JsonDoc.Flag(done.ran)),', '("ran", JsonDoc.Flag(done.ran)),\n\t\t\t("dry_run", JsonDoc.Flag(done.dry_run)),', "l0 l2"),
    ("M20", GC, 'if done.dry_run shown.append("dry run: nothing was removed\\n") else shown', 'shown', "l0 l2 l3"),
    ("M21", TE, 'or registry or', 'or (registry and name.is_empty()) or', "l0 l2"),
    ("M22", TE, 'registry = !e.is_dir and', 'registry =', "l0"),
    ("M23", IN, '"gc-age",\n\t\t\t\t|v|', '"gc-ages",\n\t\t\t\t|v|', "l0 l2 l3"),
    ("M24", CG, 'now: clocks.real })', 'now: clocks.now })', "l2 l3"),
    ("M25", CG, 'choices = Gc.toolchains({ rows, projects: judged.live, now: clocks.now, age })', 'choices = Gc.toolchains({ rows, projects: judged.live, now: clocks.real, age })', "l2"),
    ("M26", CG, 'if plan.dry_run {\n\t\twork!(fx, roots, plan, clocks)', 'if plan.dry_run and env.is_empty() {\n\t\twork!(fx, roots, plan, clocks)', "l2"),
    ("M27", CG, 'match fx.with_lock!(item, NoWait, || trash!(fx, item, one.compat)) {', 'match fx.with_lock!(item, Wait, || trash!(fx, item, one.compat)) {', "l2 l3"),
    ("M28", CG, '_ = fx.delete!([trash].concat(compat))', '_ = fx.delete!([trash].concat(compat.drop_first(1)))', "l2 l3"),
    ("M29", CG, '\t\t\t_ = fx.delete!(stale)', '\t\t\t_ = {}', "l2 l3"),
    ("M30", CG, '\t\tprune!(fx, roots, judged.gone)?\n', '', "l2 l3"),
    ("M31", CG, 'valid = entries.map(|entry| entry.path).keep_if(|each| !gone.contains(each))', 'valid = entries.map(|entry| entry.path).concat(gone.keep_if(|each| each.is_empty()))', "l2 l3"),
    ("M32", CG, '\tentries = Projects.entries({ path, text })?\n\treads = if', '\tentries = match Projects.entries({ path, text }) {\n\t\tOk(found) => found\n\t\tErr(_) => []\n\t}\n\treads = if', "l2"),
    ("M33", CG, 'shown = Common.shown_fx(fx, args)', 'shown = fx', "l2"),
    ("M34", CG, 'compat: doomed.join_map(|item| item.compat), stale, projects: judged.gone })\n\t} else', 'compat: [], stale, projects: judged.gone })\n\t} else', "l2 l3"),
    ("M35", CG, 'config = RocInstall.read_config!(fx, roots)?', 'config = match RocInstall.read_config!(fx, roots) {\n\t\tOk(found) => found\n\t\tErr(_) => { nightly: Err(Unset), min_release_age: Err(Unset), default_roc: Err(Unset), gc_age: Err(Unset) }\n\t}', "l2"),
    ("M36", CG, 'Item.Gc), NoWait', 'Item.Index), NoWait', "l2 l3"),
    ("M37", CG, 'Err(Busy) => Ok({ dry_run: Bool.False, ran: Bool.False,', 'Err(Busy) => Ok({ dry_run: Bool.False, ran: Bool.True,', "l2 l3"),
    ("M38", CG, 'doomed = ids_out.map(', 'doomed = ids_out.keep_if(|id| id != "git-dd03c09e").map(', "l2"),
    ("M40", GC, '} else if !is_older(at, facts.now, facts.age) {\n\t\t\t\tKeep(Used)', '} else if !is_older(at, facts.now, facts.age) and at == 0 {\n\t\t\t\tKeep(Used)', "l0 l2 l3"),
    ("M41", GC, '} else if !is_older(at, facts.now, facts.age) {\n\t\t\t\tKeep(Used)', '} else if !is_older(at, facts.now, 2592000) {\n\t\t\t\tKeep(Used)', "l0 l3"),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, **kw)


def run_layers(layers):
    """Returns the layers that failed."""
    failed = []
    if "l0" in layers:
        bad = False
        for f in ("gc", "temp", "intent"):
            r = sh(f"{ROC} test tests/unit/{f}.roc --no-cache")
            if r.returncode != 0:
                bad = True
        if bad:
            failed.append("l0")
    if "l2" in layers:
        r = sh("tests/commands/run.sh gc/")
        if r.returncode != 0:
            failed.append("l2")
    if "l3" in layers:
        b = sh(f"{ROC} build cli/main.roc --opt=dev --output={WORKD}/mut/tln && {ROC} build cli/fxprobe.roc --opt=dev --output={WORKD}/mut/fxprobe")
        if b.returncode != 0:
            failed.append("l3(build)")
        else:
            r = sh(f"TLN={WORKD}/mut/tln tests/run.sh cache/")
            if r.returncode != 0:
                failed.append("l3")
    return failed


def main():
    want = sys.argv[1:]
    os.makedirs(WORKD + "/mut", exist_ok=True)
    results = []
    for mid, path, old, new, layers in M:
        if want and mid not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        if old not in original:
            results.append((mid, "NOT APPLIED", layers, ""))
            print(mid, "NOT APPLIED")
            continue
        shutil.copy(full, full + ".orig")
        open(full, "w").write(original.replace(old, new, 1))
        try:
            check = sh(f"{ROC} check cli/main.roc")
            if check.returncode != 0:
                results.append((mid, "DOES NOT COMPILE", layers, check.stdout[-300:].replace("\n", " ")))
                print(mid, "DOES NOT COMPILE")
            else:
                failed = run_layers(layers.split()) if layers else []
                missing = [l for l in layers.split() if l not in failed]
                state = "caught" if not missing and layers else ("not tested" if not layers else "NOT CAUGHT by " + " ".join(missing))
                results.append((mid, state, layers, " ".join(failed)))
                print(mid, state, "(failed:", " ".join(failed) + ")", flush=True)
        finally:
            shutil.move(full + ".orig", full)
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-028-revert", out), "w") as f:
        f.write("| Id | Result | Layers that must catch it | Layers that failed |\n| --- | --- | --- | --- |\n")
        for mid, state, layers, failed in results:
            f.write(f"| {mid} | {state} | {layers} | {failed} |\n")


main()
