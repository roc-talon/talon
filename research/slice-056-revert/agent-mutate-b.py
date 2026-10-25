#!/usr/bin/env python3
"""Slice 056b: mutations of the tricky parts of the code agent (run from the repo root).
Each mutation changes one small thing in a file of cli/lib, runs the one test that must see it, and puts the file back.
Usage: python3 research/slice-056-revert/agent-mutate-b.py [id ...]
A mutation is caught when its test result differs from the baseline: an L0 failing set that is not the baseline set, or an L2 case that fails.
"""
import re
import subprocess
import sys

ROOT = "/home/george/dev/Karakatiza666/talon"
L0 = "bash research/slice-056-revert/l0.sh l0-8.roc 600"
# The expects of ToolsplanTest that stay red after 056b (7, 8, 9, 11, 15 belong to later parts).
BASE_L0 = {127, 148, 185, 268}

MUTANTS = [
    ("B1", "frozen_check: an entry with no url is no finding (exit 14 is lost)", "cli/lib/ToolsPlan.roc",
     'Err(Unset) => Ok("tools.${entry.key} has no url")', 'Err(Unset) => Err(Locked)', "pt2-install"),
    ("B1b", "frozen_check: an entry with no url is no finding, seen by the L0 expects", "cli/lib/ToolsPlan.roc",
     'Err(Unset) => Ok("tools.${entry.key} has no url")', 'Err(Unset) => Err(Locked)', "L0"),
    ("B2", "frozen_check: the range of the ref is not checked", "cli/lib/ToolsPlan.roc",
     'Ok(ident) => if !admits(entry.ref, ident.version) {', 'Ok(ident) => if !admits(entry.ref, ident.version) and entry.key == "" {', "pt2-install"),
    ("B3", "--frozen runs no tools step (a tool with no binary is not built)", "cli/lib/InstallFlow.roc",
     '_ = tools_after!(fx, tools, { request, loaded, phase })?', '_ = tools_after!(fx, tools, { request, loaded, phase: Err(None) })?', "pt2-install"),
    ("B4", "has_file: a directory with the name of the binary counts", "cli/lib/XCacheIo.roc",
     '!e.is_dir and (e.name == repo', '(e.name == repo', "pt2-install"),
    ("B5", "has_file: any file that is not the manifest counts (slice 049 state)", "cli/lib/XCacheIo.roc",
     '!e.is_dir and (e.name == repo or e.name == "${repo}.exe")', '!e.is_dir and (e.name != "manifest.json" or e.name == repo)', "pt2-install"),
    ("B6", "--dry-run builds (ensure! ignores dry_run)", "cli/lib/ToolsStep.roc",
     'if ctx.dry_run return Ok({ built: Bool.False, would: Bool.True, added: [] })', 'if ctx.dry_run and !ctx.dry_run return Ok({ built: Bool.False, would: Bool.True, added: [] })', "pt2-install"),
    ("B7", "--allow-downloads does not answer the compiler download", "cli/lib/ToolsStep.roc",
     'allow: request.downloads.allow == Ok(Yes),', 'allow: Bool.False,', "pt2-install"),
    ("B8", "D16: nothing to change ignores the tools step", "cli/lib/InstallFlow.roc",
     'if phase.is_ok() and !step.changed and !header_changed(outcome) {', 'if phase.is_ok() and (step.changed or !step.changed) and !header_changed(outcome) {', "pt2-install"),
    ("B9", "D16: the header flow prints nothing to change before the tools", "cli/lib/InstallFlow.roc",
     'if text == "nothing to change\\n" {}', 'if text == "nothing to change\\nx" {}', "pt2-install"),
    ("B10", "a build that does not pass is taken as a pass (nothing stops the write)", "cli/lib/ToolsStep.roc",
     'match attempt.class {', 'match { ..attempt, class: Pass }.class {', "pt1-add"),
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
