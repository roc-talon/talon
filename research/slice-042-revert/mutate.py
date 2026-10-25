#!/usr/bin/env python3
"""Revert check of the reference code of slice 042 (TW12, filtered runs only, no full sweep).

The tree must hold the reference (research/slice-042-revert/reference/). For each mutation: one small change in one file of cli/lib, a `roc check`,
then only the tests that must see it. CAUGHT = a test fails or times out. The file is put back after each mutation.
Usage: python3 -I research/slice-042-revert/mutate.py [id ...]   (from the repo root)
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 180, "l2": 600}
PA1 = "l2:patch/pa1-flow"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("P1", "Diff.roc", [("if i - last - 1 <= 6 =>", "if i - last - 1 <= 7 =>")], ["l0:diff", PA1], "R-PA7: runs with 7 kept lines between them are one hunk"),
    ("P2", "Diff.roc", [("else \"${prefix}${text}\\n\\\\ No newline at end of file\\n\"", "else \"${prefix}${text}\\n\"")], ["l0:diff", PA1], "R-PA7: no marker for a line without a line end"),
    ("P3", "Diff.roc", [("new_start: if new_len == 0 new_count(before) else new_count(before) + 1,", "new_start: new_count(before) + 1,")], ["l0:diff", PA1], "R-PA7: an empty new side is numbered as a line"),
    ("P4", "Diff.roc", [("if $text.sublist({ start: $p, len: pattern.len() }) == pattern {", "if $text.sublist({ start: $p, len: pattern.len() }) == pattern and $p.to_i64_wrap() == expected {")], ["l0:diff"], "R-PA7: a hunk applies only at its own place (no offset)"),
    ("P5", "Diff.roc", [("Err(None) => return Err(NoFit)", "Err(None) => {}")], ["l0:diff"], "R-PA7: a hunk that does not fit is skipped and the file is written"),
    ("P6", "Diff.roc", [("Ok(t) => if t.content == f.content Ok(Remove) else Err(NoFit)", "Ok(t) => if t.path == f.path Ok(Remove) else Err(NoFit)")], ["l0:diff"], "R-PA7: a changed file is deleted"),
    ("P7", "Diff.roc", [("Ok(f) => if f.content == base Ok(copy_what(copy)) else Err(NoFit)", "Ok(f) => if f.content == base or f.content != base Ok(copy_what(copy)) else Err(NoFit)")], ["l0:diff"], "R-PA7: a binary file is replaced when the target has other bytes"),
    ("P8", "Diff.roc", [("stop = if g.last + 3 < ops.len() g.last + 3 else ops.len() - 1", "stop = if g.last + 2 < ops.len() g.last + 2 else ops.len() - 1")], ["l0:diff", PA1], "R-PA7: 2 lines of context after a change"),
    ("P9", "PatchCmd.roc", [("		if picked.is_platform {", "		if picked.is_platform and picked.alias == \"\" {")], ["l0:removal", PA1], "R-PA8: the platform is copied"),
    ("P10", "PatchCmd.roc", [("		refuse = |text| Err({ fail: Fail.new(Usage, text), block: \"\" })", "		refuse = |text| Err({ fail: Fail.new(Environment, text), block: \"\" })")], ["l0:removal", PA1], "R-EC2, R-PA14: a refusal is not a usage failure (exit code)"),
    ("P11", "PatchFlow.roc", [("		[Ok(_)] => return Err(PatchCmd.exists(place.dir))", "		[Ok(_)] => {}")], [PA1], "R-PA1: an existing copy is overwritten"),
    ("P12", "IntentEdit.roc", [("start = if facts.text.is_empty() \"[patch]\\n\" else facts.text", "start = facts.text")], ["l0:intent", PA1], "R-PA9: the first entry of a new file is a [patch.alias] table"),
    ("P13", "Listing.roc", [("mark = if row.direct and patched.contains(row.alias)", "mark = if patched.contains(row.alias)")], ["l0:listing"], "R-CM9: a package that is not a header entry has the mark patched"),
    ("P14", "PatchFlow.roc", [("base: target.hash })?", "base: place.entry_path })?")], [PA1, "l0:intent"], "R-PA1: the base of the entry is not the hash"),
    ("P15", "PatchFlow.roc", [("		Err(_) => return Err(Fail.new(Usage, \"${target.alias} has no patch.", "		Err(_) => return Err(Fail.new(Environment, \"${target.alias} has no patch.")], [PA1], "R-PA3, R-EC2 (Q1): --diff with no [patch] key is not exit 2"),
    ("P16", "PatchFlow.roc", [("(Copy, \"\") => return Err(Fail.new(Usage,", "(Copy, \"\") => return Err(Fail.new(Environment,")], [PA1], "R-PA3, R-EC2 (Q1): --diff with no copy dir is not exit 2"),
    ("P17", "Diff.roc", [("Ok(q) if abs_diff(q, expected) <= abs_diff($p, expected) => Ok(q)", "Ok(q) if abs_diff(q, expected) < abs_diff($p, expected) => Ok(q)")], ["l0:diff"], "R-PA7 (Q2): a tie takes the last place"),
    ("P18", "Diff.roc", [("Ok(q) if abs_diff(q, expected) <= abs_diff($p, expected) => Ok(q)", "Ok(q) if abs_diff(q, expected) <= abs_diff($p, expected) and q == 0 => Ok(q)")], ["l0:diff"], "R-PA7 (Q2): the nearest place does not win"),
    ("P19", "IntentEdit.roc", [("written = if present Toml.replace(doc, [\"patch\", facts.alias], entry) else Toml.insert", "written = if present Toml.insert(doc, [\"patch\", facts.alias], entry) else Toml.insert")], ["l0:intent"], "R-PA1 (Q3): a key that is there is not replaced"),
    ("P20", "Diff.roc", [("		Ok(_) => Err(NoFit)\n	}\n	Delete(f)", "		Ok(_) => Ok(copy_what(f.content))\n	}\n	Delete(f)")], ["l0:diff"], "R-PA7 (Q4): an Add overwrites a file that the target has"),
    ("P21", "Diff.roc", [("Ok(t) => if t.content == f.content Ok(Remove) else Err(NoFit)", "Ok(t) => if t.path == f.path Ok(Remove) else Err(NoFit)")], ["l0:diff"], "R-PA7 (Q4): a Delete removes a file with other content (was P6)"),
    ("P22", "Diff.roc", [("		Err(_) => Err(NoFit)\n	}\n}\n\nold_side", "		Err(_) => Ok(Remove)\n	}\n}\n\nold_side")], ["l0:diff"], "R-PA7 (Q4): a Delete of a missing file is done"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        path = os.path.join(ROOT, LIB, fname)
        orig = open(path).read()
        text = orig
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            try:
                built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if built.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                open(path, "w").write(orig)


main()
