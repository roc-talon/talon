#!/usr/bin/env python3
"""Slice 056c: mutations of the tricky parts of the code agent (run from the repo root).
Each mutation changes one small thing in a file of cli/lib, runs the one test that must see it, and puts the file back.
Usage: python3 research/slice-056-revert/agent-mutate-c.py [id ...]
A mutation is caught when its test result differs from the baseline: an L0 failing set that is not the baseline set, or an L2 case that fails.
"""
import re
import subprocess
import sys

ROOT = "/home/george/dev/Karakatiza666/talon"
L0 = "bash research/slice-056-revert/l0.sh l0-8.roc 600"
# The expects of ToolsplanTest that stay red after 056c (7, 8, 9, 11, 15 belong to later parts).
BASE_L0 = {185, 268}

MUTANTS = [
    ("C1", "split: a name that is an alias and a key is a tool (no failure)", "cli/lib/ToolsPlan.roc",
     'if is_key and is_alias {', 'if is_key and is_alias and name == "" {', "pt3-move"),
    ("C1b", "split: the same mutation, seen by the L0 expects", "cli/lib/ToolsPlan.roc",
     'if is_key and is_alias {', 'if is_key and is_alias and name == "" {', "L0"),
    ("C2", "split: the name before the @ is read as the key (a name with a selector is a tool)", "cli/lib/ToolsPlan.roc",
     'if name.contains("@") {\n\t\t\t\t$header = $header.append(name)\n\t\t\t} else {\n\t\t\t\tis_key = facts.keys.contains(name)',
     'if name.contains("@@") {\n\t\t\t\t$header = $header.append(name)\n\t\t\t} else {\n\t\t\t\tis_key = facts.keys.contains(name.split_on("@").first() ?? name)', "L0"),
    ("C3", "upgrade takes the release inside the range of the ref (as update)", "cli/lib/ToolsPlan.roc",
     'Upgrade => Err(None)', 'Upgrade if facts.ref == "" => Err(None)', "pt3-move"),
    ("C3b", "upgrade takes the release inside the range, seen by the L0 expects", "cli/lib/ToolsPlan.roc",
     'Upgrade => Err(None)', 'Upgrade if facts.ref == "" => Err(None)', "L0"),
    ("C4", "upgrade does not change the range of the ref", "cli/lib/ToolsPlan.roc",
     'Ok(Range(_)) => Ranges.rewrite({ range: after, version: facts.version }).map_ok(|moved| "${name}@${moved}")', 'Ok(Range(_)) => Ok(facts.ref)', "pt3-move"),
    ("C5", "a range with no form moves the tool all the same (the note is printed, the tool is built)", "cli/lib/ToolsStep.roc",
     '				return Ok(kept)\n', '				entry.ref\n', "pt3-move"),
    ("C6", "the header flow runs when the names are keys of [tools] only", "cli/lib/InstallFlow.roc",
     'outcome = if plan.header resolve!', 'outcome = if plan.header or !plan.header resolve!', "pt3-move"),
    ("C7", "update with a name that is no key runs the tools step for each entry", "cli/lib/InstallFlow.roc",
     'phase: if split.tools.is_empty() Err(None) else Ok(phase)', 'phase: Ok(phase)', "pt3-move"),
    ("C8", "nothing to change is printed when the tools changed (update)", "cli/lib/InstallFlow.roc",
     'if plan.phase.is_ok() and !step.changed and !header_changed(outcome) {', 'if plan.phase.is_ok() and (step.changed or !step.changed) and !header_changed(outcome) {', "pt3-move"),
    ("C9", "nothing to change is not printed when only the tools stay (update fmt at the newest)", "cli/lib/InstallFlow.roc",
     'if plan.phase.is_ok() and !step.changed and !header_changed(outcome) {', 'if plan.phase.is_ok() and !step.changed and !header_changed(outcome) and request.names.is_empty() {', "pt3-move"),
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
