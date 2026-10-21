#!/usr/bin/env python3
"""Revert check of the slice 017 tests (TW12, no full sweep).

A private reference of the slice is in cli/ (the test agent wrote it, and deleted it after this run). This script puts one small change in it, runs only the tests
that should catch the change, and puts the file back. A change is CAUGHT when a test fails.

Usage: python3 -I research/slice-017-revert/mutate.py [id ...]     (from the repo root, with the reference in cli/)
Output: one line for each change: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"

# (id, file, [(old, new)], tests, what the change breaks)
M = [
    ("S1", "Pick.roc", [("order = moving.concat(others)", "order = others.concat(moving)")], ["l0:pickmoves"], "R-SP24: the movable slots are not first in the search"),
    ("S2", "Pick.roc", [("Highest => here.concat(higher).concat(lower)", "Highest => here.concat(lower).concat(higher)")], ["l0:pickmoves"], "R-SP24: Highest goes down first"),
    ("S3", "Pick.roc", [("Lowest => here.concat(lower).concat(higher)", "Lowest => here.concat(higher).concat(lower)")], ["l0:pickmoves"], "R-SP24: Lowest goes up first"),
    ("S4", "Pick.roc", [("in_range = if open all.keep_if", "in_range = if slot.hold == Free all.keep_if")], ["l0:pickmoves"], "R-C1 does not apply to a movable slot"),
    ("S5", "Pick.roc", [("visible = if open in_range.keep_if", "visible = if slot.hold == Free in_range.keep_if")], ["l0:pickmoves"], "R-C7 does not apply to a movable slot"),
    ("S6", "Pick.roc", [(" or (a.c.ident.group == b.c.ident.group and a.c.url != b.c.url)", "")], ["l0:pickmoves", "l2:moves/"], "2 slots of one group can have 2 values"),
    ("S7", "Pick.roc", [("Ok(files) => files.is_empty() or files.contains(m.file)", "Ok(files) => files.is_empty() or files.contains(m.file) or !files.is_empty()")], ["l0:pickclosure", "l2:workspace/"], "Q1: each member has all slots"),
    ("S8", "Pick.roc", [("if results.any(", "if results.take_first(1).any(")], ["l0:pickclosure", "l2:workspace/"], "P11: only the first member is checked"),
    ("S9", "Pick.roc", [("Fine(ids.fold([], |found, id| if found.contains(id) found else found.append(id)))", "Fine(ids)")], ["l0:pickclosure"], "P5: the Need list has repeats"),
    ("S10", "Pick.roc", [("(Movable, Move(old)) => Ok({ id: slot.id", "(_, Move(old)) => Ok({ id: slot.id")], ["l0:pickmoves"], "a free slot that moves has a row of moves"),
    ("S11", "Pick.roc", [("needs ${slot.id} ${platform_version", "needs ${slot.id} >= ${platform_version")], ["l0:pickmoves"], "the text of the R-C3 reason"),
    ("V1", "Vars.roc", [(" and !variable.ranges.any(|r| r.range.starts_with(\"=\"))", "")], ["l0:vars"], "R-SP23: an anchor is movable"),
    ("V2", "Vars.roc", [("!free and variable.host == Indexed and", "!free and")], ["l0:vars"], "R-SP23: a fixed host is movable"),
    ("V3", "Vars.roc", [("movable: movable_of(variable, outside_range(variable)), any_series", "movable: Bool.False, any_series")], ["l0:vars", "l2:moves/hm2"], "R-SP19: nothing is movable in install"),
    ("V4", "Vars.roc", [("w.members.len() >= 2 and w.stale == Err(None)", "w.members.len() >= 2")], ["l0:vars"], "R-I8: a stale key stops install"),
    ("B1", "ResolveBase.roc", [("if request.command == Install {\n\t\t\tVars.check_keys", "if request.command == Install or request.command == Update {\n\t\t\tVars.check_keys")], ["l2:workspace/"], "R-WS6: update stops for the key"),
    ("F1", "PickFlow.roc", [("if !second_wanted(stuck.fail, scoped) return", "if !second_wanted(stuck.fail, []) return")], ["l2:moves/", "l3:in1-workspace-frozen-rename"], "R-SP16: no second search"),
    ("F2", "PickFlow.roc", [("_ => fresh_version(asked, v.name)", "_ => Err(None)")], ["l2:moves/hm1", "l3:in1-workspace-frozen-rename"], "R-C7: the named version is hidden for the held group"),
    ("F3", "PickFlow.roc", [("match PickLoop.run!(fx, request, second, stuck.facts, stuck.paths) {", "match PickLoop.run!(fx, request, second, prepared.facts, []) {")], ["l2:moves/"], "R-AL8: the second search reads the files again"),
    ("F4", "PickFlow.roc", [("!(m.file == current and replaced.contains(r.alias))", "!((m.file == current or m.file != current) and replaced.contains(r.alias))")], ["l2:workspace/"], "K3: the replaced alias is dropped in each member"),
    ("F5", "PickFlow.roc", [("members: s.variable.uses.map(|u| u.file).fold(no_names, |files, file| if files.contains(file) files else files.append(file)),", "members: s.variable.uses.map(|u| u.file).take_first(1),")], ["l2:moves/hm1"], "R-SP25: the move writes one member only (the report)"),
    ("F6", "PickFlow.roc", [("else if s.movable Movable else Held", "else Held")], ["l2:moves/", "l3:in1-workspace-frozen-rename"], "R-SP23: no slot is movable"),
    ("I1", "InstallFlow.roc", [("	if request.dry_run return Ok({})\n	done = match", "	done = match")], ["l2:moves/hm1"], "R-SP26: --dry-run asks"),
    ("I2", "InstallFlow.roc", [("if done.answer == Yes Ok({}) else Err(Consent.declined(moves))", "if done.answer == Yes or done.answer != Yes Ok({}) else Err(Consent.declined(moves))")], ["l2:moves/hm2"], "R-NI3: the answer No writes"),
    ("I3", "InstallFlow.roc", [("Err(fail) => return Err({ ..fail, details: Ok(consent.details) })", "Err(fail) => return Err(fail)")], ["l2:moves/hm1"], "R-J5: no details in the failure"),
    ("I4", "InstallFlow.roc", [("	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision })?\n	confirm_moves!(fx, request, moves)?\n", "	confirm_moves!(fx, request, moves)?\n	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision })?\n")], ["l2:moves/"], "R-SP16: the prompt is before the ladder"),
    ("I5", "InstallFlow.roc", [("pick_notes = chosen.keep_oks(|c| c.note).fold(no_names, |found, text| if found.contains(text) found else found.append(text))", "pick_notes = chosen.keep_oks(|c| c.note)")], ["l2:moves/hm1"], "the note of the named version is printed twice"),
    ("C1", "Consent.roc", [("\\n  writes ${Str.join_with(m.members, \", \")}", "")], ["l0:consent", "l2:moves/"], "R-SP25: the report has no files"),
    ("C2", "Consent.roc", [("text = if moves.len() == 1 \"the held variable", "text = if moves.len() >= 1 \"the held variable")], ["l0:consent"], "the text of the failure for 2 variables"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh", arg]
    else:
        cmd = ["tests/run.sh", arg]
    r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True)
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
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})")
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            try:
                built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if built.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n"," "), flush=True)
                    continue
                caught_by = []
                for t in tests:
                    failed, out = run(t)
                    if failed:
                        caught_by.append(t)
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {', '.join(caught_by) or '-'} ({what})", flush=True)
            finally:
                open(path, "w").write(orig)


main()
