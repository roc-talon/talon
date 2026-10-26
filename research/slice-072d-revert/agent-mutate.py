#!/usr/bin/env python3
"""Revert check of the code agent for the slices 078b, 079b and 072d (TW12): one small change at a time,
only the L2 cases that must see it (tests/commands/run.sh <filter>), then the file is put back from a copy.
Usage: research/slice-072d-revert/agent-mutate.py [id ...]"""
import subprocess, sys, shutil, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
L = "cli/lib/"
M = [
 ("a1", "078b: the record is ignored (entry_read!)", L+"ToolBuild.roc", "key == name.drop_suffix(\".exe\")", "key == name.drop_suffix(\".exe\") and Bool.False", ["tool/ti5", "tool/tk3"]),
 ("a2", "078b: install! reads tools.json again", L+"ToolBuild.roc", "ToolBuild.entry_read!(fx, facts, Text(text))?", "ToolBuild.entry_read!(fx, facts, Fresh)?", ["tool/ti5"]),
 ("a3", "078b: states! looks up roc by the name tln", L+"TalonUpdateFlow.roc", "roc: ToolBuild.verdict_in(pairs, { name: roc,", "roc: ToolBuild.verdict_in(pairs, { name: tln,", ["tool/ts9"]),
 ("a4", "078b: tool remove ignores the record", L+"ToolManageFlow.roc", "recorded: ToolBuild.recorded(pairs, paths.file) })", "recorded: ToolBuild.recorded(pairs.take_first(0), paths.file) })", ["tool/tm2"]),
 ("a5", "078b: tool remove talon ignores the record", L+"TalonRemoveFlow.roc", "recorded: ToolBuild.recorded(scene.records, name) })", "recorded: ToolBuild.recorded(scene.records.take_first(0), name) })", ["tool/rm7"]),
 ("b1", "079b: PATH lookup always runs", L+"ToolFlow.roc", "if env.is_empty() and facts.selected.is_empty() OnPath", "if env.is_empty() or facts.selected.is_empty() OnPath", ["tool/tc1", "tool/ti3"]),
 ("b2", "079b: PATH never selects", L+"ToolFlow.roc", "ToolCompiler.selected_of({ env, default: facts.selected, path })", "ToolCompiler.selected_of({ env, default: facts.selected, path: path.map_ok(|_| \"\") })", ["tool/tc3", "tool/ti4"]),
 ("b3", "079b: PATH lookup also with ROC_TOOLCHAIN", L+"ToolFlow.roc", "if env.is_empty() and facts.selected.is_empty() OnPath", "if facts.selected.is_empty() OnPath", ["tool/tc3"]),
 ("b4", "079b: defaulted! does not look at PATH", L+"ToolUpdateFlow.roc", "selected: ToolFlow.selected_for!(fx, base)", "selected: base.selected", ["tool/tr1", "tool/tu1"]),
 ("c1", "072d: --no-check stops at no compiler", L+"ResolveBase.roc", "				_ => Ok({})\n			}", "				LockNoCheck => Err(Compiler.failure(NoCompiler))\n				Verify => Ok({})\n			}", ["remove/rm3"]),
 ("c2", "072d: verify stops at no compiler", L+"ResolveBase.roc", "				_ => Ok({})\n			}", "				Verify => Err(Compiler.failure(NoCompiler))\n				LockNoCheck => Ok({})\n			}", ["verify/vn1", "probe/pn1"]),
 ("c3", "072d: step (b) goes on after a non-pass", L+"HeldRoc.roc", "if fact.outcome != Pass return", "if fact.outcome != Pass and $count > 100 return", ["verify/vn1", "probe/pn1", "roc/us4"]),
 ("c4", "072d: step (b) ignores the budget in the units", L+"HeldRoc.roc", "		if $count >= req.left return Ok({ passed: Bool.False, probes: $count })\n		fact", "		fact", ["verify/vn1"]),
 ("c5", "072d: step (b) counts a failed check or build as a pass", L+"HeldRoc.roc", "(Pass, Ok(built)) => built.class == Pass", "(Pass, Ok(built)) => built.class == Pass or Bool.True", ["verify/vn1", "probe/pn1", "roc/us4"]),
 ("c5b", "072d: step (b) counts a failed check as a pass", L+"HeldRoc.roc", "			_ => Bool.False\n			}\n			Ok({ passed", "			_ => Bool.True\n			}\n			Ok({ passed", ["verify/vn1", "probe/pn1", "roc/us4"]),
 ("c6", "072d: probe has no pick", L+"ProbeFlow.roc", "held = HeldRoc.held!(fx, request, prepared.loaded, prepared.decision.held)?", "held = prepared.decision.held ?? \"\"", ["probe/pn1"]),
 ("c7", "072d: roc use has no pick", L+"RocUse.roc", "Ok(Ok(HeldRoc.held!(fx, request, members, selected)?))", "Ok(selected)", ["roc/us4"]),
 ("c8", "072d: verify has no pick", L+"VerifyFlow.roc", "held = HeldRoc.held!(fx, request, loaded, decision.held)?", "held = decision.held ?? \"\"", ["verify/vn1"]),
]
os.chdir(ROOT)
want = sys.argv[1:]
for mid, text, path, old, new, filt in M:
    if want and mid not in want: continue
    src = open(path).read()
    if src.count(old) < 1:
        print(mid, "OLD TEXT NOT FOUND"); continue
    backup = path + ".agent-orig"
    shutil.copy(path, backup)
    try:
        open(path, "w").write(src.replace(old, new, 1))
        r = subprocess.run(["tests/commands/run.sh"] + filt, capture_output=True, text=True)
        last = [l for l in (r.stdout + r.stderr).splitlines() if l.strip()][-3:]
        out = r.stdout + r.stderr
        stop = "while successfully building" in out or "ERROR" in out and "commands:" not in out
        print(mid, text, "->", "BUILD STOP (no valid result)" if stop else ("CAUGHT" if r.returncode != 0 else "NOT CAUGHT"), "|", " / ".join(last)[:160])
    finally:
        shutil.move(backup, path)
    assert open(path).read() == src
