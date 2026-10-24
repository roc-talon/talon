#!/usr/bin/env python3
"""Revert check of the reference code of slice 039b (TW12, filtered runs only, no full sweep).

The tree must hold the reference (research/slice-039b-revert/reference/). For each mutation: one small change in one file of cli/lib, a `roc check`,
then only the tests that must see it. CAUGHT = a test fails or times out. The file is put back after each mutation.
Usage: python3 -I research/slice-039b-revert/mutate.py [id ...]   (from the repo root)
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 180, "l2": 600}
UR5 = "l2:upgrade/ur5-optional"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("O1", "PickOptional.roc", [("open: [] }, pairs: round.pairs.keep_if(|p| !state.open.contains(p.nightly)) })\n			}\n			Download", "open: state.open.keep_if(|id| !wanted.contains(id)) }, pairs: round.pairs.keep_if(|p| !state.open.contains(p.nightly)) })\n			}\n			Download")], [UR5], "R-DL4: a skip removes only the compilers that the round wanted: the line shows again"),
    ("O2", "PickOptional.roc", [("else request.downloads.probe\n", "else request.downloads.probe.on_err(|_| request.downloads.allow)\n")], [UR5], "R-DL5: --allow-downloads is an opt-in for an optional download"),
    ("O3", "PickOptional.roc", [("flag = if request.dry_run Err(NoFlag) else request.downloads.probe", "flag = request.downloads.probe"), ("yes = request.prompt.yes and !request.dry_run", "yes = request.prompt.yes")], [UR5], "R-LF4: --dry-run does not answer No to an optional download"),
    ("O4", "PickOptional.roc", [("$state = { ..$state, tried: $state.tried + 1 }\n				$failed", "$state = { ..$state, tried: $state.tried }\n				$failed")], [UR5], "R-DL6: a failed try does not count for the cap"),
    ("O5", "PickLoop.roc", [("	budget = match Units.budget({ max, started: probed.count, fixed: 0, wanted: pairs.len() }) {", "	early = PickOptional.step!(fx, request, { settings: setup.settings, sizes: setup.optional.sizes, pairs: pairs }, probed.optional)?\n	budget = match Units.budget({ max, started: probed.count, fixed: 0, wanted: pairs.len() }) {"), ("stepped = PickOptional.step!(fx, request, { settings: setup.settings, sizes: setup.optional.sizes, pairs: pairs.take_first(budget.run) }, probed.optional)?", "stepped = { state: early.state, pairs: early.pairs.take_first(budget.run) }")], [UR5], "R-P5: the download is made before the budget check (a download for a probe that cannot start)"),
    ("O6", "PickOptional.roc", [("left = round.settings.max_toolchains - state.tried", "left = round.settings.max_toolchains")], [UR5], "R-DL6: the cap does not count the tries of earlier rounds"),
    ("O7", "InstallFlow.roc", [("ladder_ran.downloads + after.downloads + probed.optional.downloads", "ladder_ran.downloads + after.downloads")], [UR5], "R-J3: data.downloads does not count the optional downloads"),
    ("O8", "PickOptional.roc", [("wanted = round.pairs.map(|p| p.nightly).fold([], |found, id| if found.contains(id) found else found.append(id)).keep_if(|id| state.open.contains(id))", "wanted = state.open")], [UR5], "R-DL2: with the opt-in, every open compiler is downloaded, also when no pair needs it"),
    ("O9", "PickLoop.roc", [(".concat(probed.optional.got))", ")")], [UR5], "a compiler that the search downloaded is no value of the compiler slot"),
    ("O10", "NightlyPlan.roc", [("not_older(id) and !have(id) and !is_newest(id) and !Pin.same_id(id, f.held))\n		sizes", "not_older(id) and (!have(id) or Bool.True) and !is_newest(id) and !Pin.same_id(id, f.held))\n		sizes")], ["l0:nightlyplan"], "R-UP6, R-NI4: an installed compiler is optional (a download of it)"),
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
