#!/usr/bin/env python3
"""Slice 056d: mutations of the tricky parts of the code agent (run from the repo root).
Each mutation changes one small thing in a file of cli/lib, runs the one test that must see it, and puts the file back.
Usage: python3 research/slice-056-revert/agent-mutate-d.py [id ...]
A mutation is caught when its test result differs from the baseline: an L0 failing set that is not the baseline set, or an L2 case that fails.
"""
import re
import subprocess
import sys

ROOT = "/home/george/dev/Karakatiza666/talon"
L0 = "bash research/slice-056-revert/l0.sh l0-8.roc 600"
# The expects of ToolsplanTest that stay red after 056d (7, 8, 9, 11, 15 belong to later parts).
BASE_L0 = set()

MUTANTS = [
    ("D1", "GC does not keep the package dirs that [tools] of a live project names", "cli/lib/CacheGc.roc",
     'protected: facts.protected.concat(held), owned', 'protected: facts.protected, owned', "gc5-project-tools"),
    ("D2", "GC does not keep the x entries that [tools] of a live project names", "cli/lib/CacheGc.roc",
     'x_dirs = expired(held)', 'x_dirs = expired([])', "gc5-project-tools"),
    ("D3", "held_hashes: the walk does not stop at the file with [workspace]", "cli/lib/ToolsPlan.roc",
     'Ok(Value.Table(_)) => here', 'Ok(Value.Table(_)) => here.concat(walk_hashes(rest, reads))', "L0"),
    ("D4", "held_hashes: a project that is not a member of the workspace above it keeps nothing (the walk stops at the first candidate that was read)", "cli/lib/ToolsPlan.roc",
     '_ => here.concat(walk_hashes(rest, reads))', '_ => here', "L0"),
    ("D5", "held_paths: a path twice, not in byte order", "cli/lib/ToolsPlan.roc",
     'held_paths = |facts| Text.sorted_unique(facts.files.join_map(|file| candidates_of(file)))', 'held_paths = |facts| facts.files.join_map(|file| candidates_of(file))', "L0"),
    ("D6", "the take-over always moves (the entry of a project tool is not kept)", "cli/lib/XTake.roc",
     'project_uses: held.contains(entry.bundle)', 'project_uses: held.contains(entry.bundle) and entry.bundle == ""', "tk2-takeover-project"),
    ("D7", "the take-over reads no project (the held hashes are empty)", "cli/lib/XTake.roc",
     'held = ToolsHeld.all!(fx, facts.roots)?', 'held = ToolsHeld.all!(fx, facts.roots)?.drop_first(99)', "tk2-takeover-project"),
    ("D8", "GC: a talon.toml entry of projects.json is judged as a header (it goes)", "cli/lib/Gc.roc",
     'Ok(text) => if entry.path == "talon.toml" or entry.path.ends_with("/talon.toml") {', 'Ok(text) => if entry.path == "talon.toml" or entry.path.ends_with("/talon.tomlx") {', "gc5-project-tools"),
    ("D8b", "GC: a talon.toml entry is judged as a header, seen by the L0 expects", "cli/lib/Gc.roc",
     'Ok(text) => if entry.path == "talon.toml" or entry.path.ends_with("/talon.toml") {', 'Ok(text) => if entry.path == "talon.toml" or entry.path.ends_with("/talon.tomlx") {', "L0"),
    ("D9", "GC reads [tools] only when a package dir would go (an x entry alone does not)", "cli/lib/CacheGc.roc",
     '(!expired([]).is_empty() or !open.pkgs.is_empty())', '(!open.pkgs.is_empty())', "gc/"),
    ("D10", "GC reads [tools] of a project that is not live too (entries of projects.json)", "cli/lib/CacheGc.roc",
     'projects = known.live.map(|project| project.path)', 'projects = known.live.map(|project| project.path).concat(known.gone)', "gc5-project-tools"),
]


def sh(cmd):
    r = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, timeout=900)
    return r.returncode, r.stdout + r.stderr


def l0_failed(out):
    return {int(m) for m in re.findall(r"ToolsplanTest\.roc:(\d+):\d+", out)}, "compiler error" in out and "0 compiler errors" not in out


def run(m):
    mid, desc, path, old, new, test = m
    full = f"{ROOT}/{path}"
    text = open(full).read()
    if text.count(old) != 1:
        return f"{mid}: OLD TEXT NOT UNIQUE ({text.count(old)})"
    try:
        open(full, "w").write(text.replace(old, new))
        if test.startswith("L0"):
            _, out = sh(L0)
            failed, cerr = l0_failed(out)
            caught = cerr or failed != BASE_L0
            detail = "compiler error" if cerr else f"failing expects {sorted(failed - BASE_L0)} new, {sorted(BASE_L0 - failed)} fixed"
        else:
            rc, out = sh(f"tests/commands/run.sh {test}")
            if "build of the L2 app failed" in out:
                return f"{mid}: INVALID (the mutation does not compile)"
            caught = rc != 0
            detail = "FAIL" if caught else "pass"
        return f"{mid}: {'CAUGHT' if caught else 'NOT CAUGHT'} by {test} ({detail}): {desc}"
    finally:
        open(full, "w").write(text)


if __name__ == "__main__":
    want = sys.argv[1:]
    for m in MUTANTS:
        if want and m[0] not in want:
            continue
        print(run(m), flush=True)
