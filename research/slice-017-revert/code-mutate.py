#!/usr/bin/env python3
"""Revert check of the code of slice 017 (TW12, filtered runs only, no full sweep).

For each mutation: one small change in one file of cli/lib, a `roc check`, then only the tests that should catch it. The first test that fails ends the run of that mutation
(CAUGHT). A test that runs longer than the timeout counts as CAUGHT (a loop). The file is put back after each mutation.

Usage: python3 -I research/slice-017-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("P1", "Pick.roc", [("front.concat(back).map(", "back.concat(front).map(")], ["l0:pickmoves"], "R-SP24: the movable slots are last in the second search"),
    ("P2", "Pick.roc", [("Highest => own.concat(higher).concat(lower)", "Highest => own.concat(lower).concat(higher)")], ["l0:pickmoves"], "R-SP24: Highest goes down first"),
    ("P3", "Pick.roc", [("Lowest => own.concat(lower).concat(higher)", "Lowest => own.concat(higher).concat(lower)")], ["l0:pickmoves"], "R-SP24: Lowest goes up first"),
    ("P4", "Pick.roc", [("in_range = if open all.keep_if", "in_range = if slot.hold == Free all.keep_if")], ["l0:pickmoves"], "R-C1 does not apply to a movable slot"),
    ("P5", "Pick.roc", [("(a.c.ident.group == b.c.ident.group and a.c.url != b.c.url) or ", "")], ["l0:pickmoves", "l2:moves/"], "R-WS2: 2 slots of one group can have 2 values"),
    ("P6", "Pick.roc", [('p.files.is_empty() or m.file == "" or p.files.contains(m.file)', 'p.files.is_empty() or m.file == "" or !p.files.is_empty()')], ["l0:pickclosure"], "Q1: each member has all slots"),
    ("P7", "Pick.roc", [("Fine(ids.fold([], |found, id| if found.contains(id) found else found.append(id)))", "Fine(ids)")], ["l0:pickclosure"], "P5: the Need list has repeats"),
    ("P8", "Pick.roc", [("in_order = picked.sort_with(|a, b| if a.slot < b.slot Before else if a.slot > b.slot After else Same)", "in_order = picked")], ["l0:pickmoves"], "the result is in the order of the search, not of the slots"),
    ("P9", "Pick.roc", [("Ok(current) if slot.hold == Movable and current != c.url", "Ok(current) if current != c.url")], ["l0:pickmoves"], "R-SP16: a free slot that moves has a row of moves"),
    ("P10", "Pick.roc", [("rows.keep_if(|(_, x)| Ident.of_url(x.url).map_ok(|ident| ident.group) == group)", "rows.keep_if(|(s, _)| s.id == slot.id)")], ["l0:pickmoves"], "R-C1: only the ranges of the slot, not of its group"),
    ("V1", "Vars.roc", [(' and !variable.ranges.any(|r| r.range.starts_with("="))', "")], ["l0:vars"], "R-SP23: an anchor is movable"),
    ("V2", "Vars.roc", [("!free and variable.host == Indexed and", "!free and")], ["l0:vars"], "R-SP23: a fixed host is movable"),
    ("V3", "Vars.roc", [("w.members.len() >= 2 and w.stale == Err(None)", "w.members.len() >= 2")], ["l0:vars"], "R-I8: a stale key stops install"),
    ("R1", "ResolveBase.roc", [("if role == Lock and request.command == Install {", "if role == Lock {")], ["l2:workspace/ws1"], "R-WS6: update stops for the key"),
    ("F1", "PickMoves.roc", [("fail.kind == NoTuple and", "fail.kind == Usage and")], ["l2:moves/", "l3:install/in1-workspace-frozen-rename"], "R-SP16: no second search"),
    ("F2", "PickFlow.roc", [("Ok({ fresh: { selector: Ok(Exact(version)), .. }, .. }) => Ok(version)", "Ok({ fresh: { selector: Ok(Exact(_version)), .. }, .. }) => Err(None)")], ["l2:moves/hm1", "l3:install/in1-workspace-frozen-rename"], "R-C7: the named version is hidden for the held group"),
    ("F3", "PickFlow.roc", [("PickLoop.run!(fx, request, again, stuck.facts, stuck.paths)", "PickLoop.run!(fx, request, again, prepared.facts, [])")], ["l2:moves/"], "R-AL8: the second search reads the files again"),
    ("F4", "PickFlow.roc", [("else if s.movable Movable else Held", "else Held")], ["l2:moves/", "l3:install/in1-workspace-frozen-rename"], "R-SP23: no slot is movable"),
    ("F5", "PickFlow.roc", [("or found.any(|c| c.name == name) names else", "or found.any(|c| c.name == \"\") names else")], ["l2:moves/"], "R-DI1: the index of a free group is read a second time"),
    ("F6", "PickMoves.roc", [("uses.fold([], |found, u| if found.contains(u.file) found else found.append(u.file))", "uses.take_first(1).map(|u| u.file)")], ["l2:moves/"], "R-SP25: the move writes one member only (the report)"),
    ("I1", "InstallFlow.roc", [("	if request.dry_run return Ok({})\n	done = match", "	done = match")], ["l2:moves/"], "R-SP26: --dry-run asks"),
    ("I2", "InstallFlow.roc", [("if done.answer == Yes Ok({}) else Err(Consent.declined(moves))", "if done.answer == Yes or done.answer != Yes Ok({}) else Err(Consent.declined(moves))")], ["l2:moves/"], "R-NI3: the answer No writes"),
    ("I3", "InstallFlow.roc", [("Err(fail) => return Err({ ..fail, details: Ok(consent.details) })", "Err(fail) => return Err(fail)")], ["l2:moves/"], "R-J5: no details in the failure"),
    ("I4", "InstallFlow.roc", [("	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision })?\n	confirm_moves!(fx, request, moves)?\n", "	confirm_moves!(fx, request, moves)?\n	ran = if changes.is_empty() no_ran else ladder!(fx, request, loaded, { scoped, news, chosen, changes, decision })?\n")], ["l2:moves/"], "R-SP16: the prompt is before the ladder"),
    ("I5", "InstallFlow.roc", [("pick_notes = chosen.keep_oks(|c| c.note).fold(no_names, |found, note| if found.contains(note) found else found.append(note))", "pick_notes = chosen.keep_oks(|c| c.note)")], ["l2:moves/"], "the note of the named version is printed twice"),
    ("C1", "Consent.roc", [('\\n  writes ${Str.join_with(m.members, ", ")}', "")], ["l0:consent"], "R-SP25: the report has no files"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    else:
        cmd = ["tests/run.sh"] + arg.split()
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
