#!/usr/bin/env python3
"""Revert check of the private reference of slice 040 (TW12; the user rule of 2026-10-23: about 5 to 10 mutations, filtered runs, no full sweep).

The tree must hold the reference (`research/slice-040-revert/mode.sh ref`). For each mutation: one small change in one file, a `roc check`, then only the tests that must see it.
CAUGHT = a test fails. Each listed test runs, so the result names every test that sees the change. The file is put back after each mutation.
Usage: python3 -I research/slice-040-revert/mutate.py [id ...]   (from the repo root)
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 180, "l2": 600}
L0 = "l0:outdated"
OD1 = "l2:outdated/od1-table"
OD2 = "l2:outdated/od2-edges"
OUT = "cli/lib/Outdated.roc"
FLOW = "cli/lib/OutdatedFlow.roc"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("M1", OUT, [("wanted = best(input.ranges, Index.in_group", "wanted = best([], Index.in_group")], [L0, OD1], "R-C1: `wanted` ignores the ranges (the key of talon.toml, the anchor, the implied range)"),
    ("M2", OUT, [("ctx = { now: input.now, min_age: input.min_age,", "ctx = { now: input.now, min_age: 0,")], [L0, OD1], "R-C7: min-release-age hides nothing"),
    ("M3", OUT, [("latest = best([], input.list.keep_if(|c| c.ident.group.form == ident.group.form))", "latest = best([], Index.in_group({ list: input.list, group: ident.group }))")], [L0, OD1], "R-UP12: `latest` stays in the series of the header value"),
    ("M4", OUT, [("behind = |row| row.current != row.wanted or row.current != row.latest", "behind = |row| row.current != row.wanted")], [L0, OD1], "Outdated.behind: a package that is behind only in `latest` has no row"),
    ("M4b", FLOW, [("is_behind = |b| b.current != b.wanted or b.current != b.latest", "is_behind = |b| b.current != b.wanted")], [L0, OD1], "the flow shows no row for a package that is behind only in `latest`"),
    ("M5", FLOW, [("domain = if behind.is_empty() [] else Nightlies", "domain = if behind.len() > 100 [] else Nightlies")], [OD1], "R-DI1: the compiler list and the db are read also when no row is behind"),
    ("M7", OUT, [('end_text = |end| if end.real end.id else "${end.id}?"', "end_text = |end| end.id")], [L0, OD1, OD2], "R-PB4: an end that is not a real fact has no mark"),
    ("M8", FLOW, [("shown = if named.is_empty() loaded.members else named", "shown = if named.len() > 9 named else loaded.members")], [OD2], "R-PD5: a current member does not limit the report"),
    ("M9", FLOW, [("fx.out!(Outdated.text(member))", "Common.shown_fx(fx, args).out!(Outdated.text(member))")], [OD1], "R-FL4: `--quiet` hides the table"),
    ("M10", FLOW, [("	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?\n", "")], [OD1, OD2], "R-PD9: the project is not recorded"),
    ("M14", OUT, [("range_of = |input| if input.domain.is_empty() {\n\t\tUnread\n\t} else {", "range_of = |input| if input.hash == \"-\" {\n\t\tUnread\n\t} else {")], [L0, OD1], "an empty compiler list gives `none known` in place of `-`"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind[:2]])
    except subprocess.TimeoutExpired:
        return True
    return r.returncode != 0


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        path = os.path.join(ROOT, fname)
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
                check = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if check.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + check.stdout[:300].replace("\n", " "), flush=True)
                    continue
                seen = [t for t in tests if run(t)]
                print(f"{mid}: {'CAUGHT' if seen else 'NOT CAUGHT'} by {', '.join(seen) or '-'} ({what})", flush=True)
            finally:
                open(path, "w").write(orig)


main()
