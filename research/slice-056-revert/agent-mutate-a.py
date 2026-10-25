#!/usr/bin/env python3
"""Slice 056a: mutations of the tricky parts of the code agent (run from the repo root).
Each mutation changes one small thing in a file of cli/lib, runs the one test that must see it, and puts the file back.
Usage: python3 research/slice-056-revert/agent-mutate-a.py [id ...]
A mutation is caught when its test result differs from the baseline: an L0 failing set that is not the baseline set, or an L2 case that fails.
"""
import re
import subprocess
import sys

ROOT = "/home/george/dev/Karakatiza666/talon"
L0 = "bash research/slice-056-revert/l0.sh l0-8.roc 600"
# The expects of ToolsplanTest that stay red after 056a (7, 8, 9, 11, 15 belong to later parts).
BASE_L0 = {127, 136, 148, 185, 268}

MUTANTS = [
    ("A1", "put: any text is replaced by a new table (the other bytes are lost)", "cli/lib/ToolsToml.roc",
     'if facts.text == "" {', 'if facts.text == "" or facts.text != "" {', "pt1-add"),
    ("A1b", "put: the same mutation, seen by the L0 expects", "cli/lib/ToolsToml.roc",
     'if facts.text == "" {', 'if facts.text == "" or facts.text != "" {', "L0"),
    ("A2", "add_ref: no selector writes name@<version> with no caret", "cli/lib/ToolsPlan.roc",
     '_ => "${facts.name}@^${facts.version}"', '_ => "${facts.name}@${facts.version}"', "pt1-add"),
    ("A3", "no_project is never true (no talon.toml in the current directory)", "cli/lib/ToolsPlan.roc",
     'starts_with("no project file found. Checked:")', 'starts_with("no project file found. Checked:x")', "pt1-add"),
    ("A3b", "no_project is never true, seen by the L0 expects", "cli/lib/ToolsPlan.roc",
     'starts_with("no project file found. Checked:")', 'starts_with("no project file found. Checked:x")', "L0"),
    ("A4", "D1: add --tool takes --no-pin", "cli/lib/ToolsCmd.roc",
     '["--tool", "--as", "--snapshot", "--dry-run", "--allow-downloads"]', '["--tool", "--as", "--no-pin", "--snapshot", "--dry-run", "--allow-downloads"]', "pt1-add"),
    ("A4b", "D1: add --tool takes --no-pin, seen by the L0 expects", "cli/lib/ToolsCmd.roc",
     '["--tool", "--as", "--snapshot", "--dry-run", "--allow-downloads"]', '["--tool", "--as", "--no-pin", "--snapshot", "--dry-run", "--allow-downloads"]', "L0"),
    ("A5", "a key of another app acts as an update", "cli/lib/ToolsFlow.roc",
     'if ToolsToml.app_of(entry.ref) == name {', 'if ToolsToml.app_of(entry.ref) == name or entry.key == key {', "pt1-add"),
    ("A6", "--dry-run writes the file", "cli/lib/ToolsStep.roc",
     'if changes.is_empty() or ctx.dry_run return Ok({})', 'if changes.is_empty() return Ok({})', "pt1-add"),
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
