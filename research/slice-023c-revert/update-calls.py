#!/usr/bin/env python3
"""Slice 023c: change the expected files of the 17 L2 cases that run a probe, and the refusal text of 3 cases.
Usage: update-calls.py [--check]   (--check prints what would change and writes nothing)

For each case in CASES:
  expect/calls.log
    1. each line `  probe <dir> <compiler> <rest>` becomes `  probe <dir> <compiler> <program> <rest>`, and one line
       `    env XDG_CACHE_HOME=$HOME/.cache ROC_CACHE_DIR=$HOME/.cache/roc TALON_IN_PROXY=1` follows it.
       <program> is the file of the roc on PATH: `$HOME/bin/roc` for the entry `resolve` (the harness word `compiler=<id>`),
       else the first `file` row of fx/path-roc.
    2. a run that starts the ladder (a `random` line right before a `copy_tree` or `make_dirs` line) gets
       `list_dirs $HOME/.cache/roc/toolchains` and `canonical $HOME/.cache $HOME/.cache/roc` before the first such `random`
       (steps 0a and 0c of Ladder.run! and Ladder.verify!).
    3. a run that the ladder refuses (stderr has the P0 text "is not installed. This version of tln runs only the roc on PATH")
       gets `list_dirs $HOME/.cache/roc/toolchains` at its end (step 0a, then the refusal of step 0b).
    4. a probe whose compiler id is a dir of given/home/.cache/roc/toolchains (an installed compiler) runs
       `$HOME/.cache/roc/toolchains/<id>/roc`, and `write_atomic $HOME/.cache/roc/toolchains/<id>/.last-use` comes before each
       `probes <n>` line of it (R-CC9). Its expect/tree.diff gets one new-file hunk for each such `.last-use` (before the first `project/` hunk).
  expect/stderr: the P0 refusal text becomes `the compiler <id> is not installed. Run: tln roc install <id>.`
"""
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASES = """roc/so1-ranks resolve/rs-new-toml resolve/rs-install-add-key resolve/rs-workspace-shared-group resolve/rs-update-scope
resolve/rs-highest-use resolve/rs-unmanaged gaps/g1-slice009 ladder/ld-no-check-refuse ladder/ld-ladder-flow remove/rm1-flow
workspace/ws2-verify-members verify/vf1-flow install/in1-flow update/up1-flow moves/hm1-noninteractive moves/hm2-interactive""".split()
BASE = os.path.join(ROOT, "tests/commands/cases")
LIST = "list_dirs $HOME/.cache/roc/toolchains"
CANON = "canonical $HOME/.cache $HOME/.cache/roc"
ENV = "    env XDG_CACHE_HOME=$HOME/.cache ROC_CACHE_DIR=$HOME/.cache/roc TALON_IN_PROXY=1"
OLD = re.compile(r"the compiler (\S+) is not installed\. This version of tln runs only the roc on PATH[^.\n]*\.")
NEW = r"the compiler \1 is not installed. Run: tln roc install \1."


def installed_of(case):
    d = f"{BASE}/{case}/given/home/.cache/roc/toolchains"
    if not os.path.isdir(d):
        return set()
    return {n for n in os.listdir(d) if os.path.isdir(f"{d}/{n}") and not n.endswith((".tmp", ".lock"))}


def program_of(case):
    entry = open(f"{BASE}/{case}/entry").read().strip()
    if entry == "resolve":
        return "$HOME/bin/roc"
    for line in open(f"{BASE}/{case}/fx/path-roc"):
        w = line.split()
        if len(w) >= 2 and w[0] == "file":
            return w[1]
    raise SystemExit(f"{case}: no file row in fx/path-roc")


def run_starts(case, lines):
    entry = open(f"{BASE}/{case}/entry").read().strip()
    starts = []
    for i, l in enumerate(lines):
        if entry == "commands":
            if l == "args":
                starts.append(i)
        elif l.startswith("canonical ") and i + 1 < len(lines) and lines[i + 1].startswith("list_dirs ") and \
                lines[i + 1][len("list_dirs "):] == os.path.dirname(l[len("canonical "):]):
            starts.append(i)
    return starts


def transform(case):
    path = f"{BASE}/{case}/expect/calls.log"
    lines = open(path).read().split("\n")
    trailing = lines[-1] == ""
    if trailing:
        lines = lines[:-1]
    program = program_of(case)
    stderr_path = f"{BASE}/{case}/expect/stderr"
    refused = len(OLD.findall(open(stderr_path).read())) if os.path.exists(stderr_path) else 0
    out, ladders = [], 0
    installed = installed_of(case)
    used = []
    for j, l in enumerate(lines):
        # the first member of a ladder run: the `random` that comes before `copy_tree` (install) or `make_dirs` (verify) and does not come
        # right after the `delete` of the member before it
        if l == "random" and j + 1 < len(lines) and lines[j + 1].split(" ")[0] in ("copy_tree", "make_dirs") and \
                not (j > 0 and lines[j - 1].startswith("delete ")):
            out += [LIST, CANON]
            ladders += 1
        if l.startswith("probes ") and j + 1 < len(lines):
            m = re.match(r"^  probe (\S+) (\S+) ", lines[j + 1])
            if m and m.group(2) in installed:
                out.append(f"write_atomic $HOME/.cache/roc/toolchains/{m.group(2)}/.last-use")
                if m.group(2) not in used:
                    used.append(m.group(2))
        m = re.match(r"^  probe (\S+) (\S+) (.*)$", l)
        if m:
            prog = f"$HOME/.cache/roc/toolchains/{m.group(2)}/roc" if m.group(2) in installed else program
            out += [f"  probe {m.group(1)} {m.group(2)} {prog} {m.group(3)}", ENV]
        else:
            out.append(l)
    transform.used = used
    return path, out, trailing, ladders, refused


def clock_of(case):
    # the time of the run: 1792065600 is the default of the fake clock and of the harness word `now=`
    import datetime
    return datetime.datetime.fromtimestamp(1792065600, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main():
    check = "--check" in sys.argv
    for case in CASES:
        path, out, trailing, ladders, refused = transform(case)
        # refusal runs: the order of the refused runs is the order of the runs that end without a ladder and with exit 13
        lines_out = out
        if refused:
            exit_path = f"{BASE}/{case}/expect/stdout"
            blocks = re.split(r"(?m)^== ", open(exit_path).read())[1:]
            entry = open(f"{BASE}/{case}/entry").read().strip()
            starts = run_starts(case, lines_out)
            starts.append(len(lines_out))
            assert len(blocks) == len(starts) - 1, (case, len(blocks), len(starts) - 1)
            res, done = lines_out[:starts[0]], 0
            for (a, b), block in zip(zip(starts, starts[1:]), blocks):
                run = lines_out[a:b]
                ladder = any(l.startswith("  probe ") for l in run) or (LIST in run)
                res += run
                if block.rstrip().endswith("exit 13") and not ladder and done < refused:
                    res.append(LIST)
                    done += 1
            assert done == refused, (case, done, refused)
            lines_out = res
        text = "\n".join(lines_out) + ("\n" if trailing else "")
        if transform.used:
            when = clock_of(case)
            tp = f"{BASE}/{case}/expect/tree.diff"
            hunks = "".join(f"--- home/.cache/roc/toolchains/{i}/.last-use\n+++ home/.cache/roc/toolchains/{i}/.last-use\n@@ -0,0 +1 @@\n+{when}\n"
                            for i in sorted(transform.used))
            t = open(tp).read()
            k = t.find("--- project/")
            n = (t[:k] + hunks + t[k:]) if k >= 0 else t + hunks
            print(f"  tree.diff: {len(transform.used)} .last-use hunk(s)")
            if not check:
                open(tp, "w").write(n)
        old = open(path).read()
        print(f"{case}: ladder runs {ladders}, refusals {refused}, lines {len(old.splitlines())} -> {len(text.splitlines())}")
        if not check:
            open(path, "w").write(text)
        sp = f"{BASE}/{case}/expect/stderr"
        if os.path.exists(sp):
            t = open(sp).read()
            n = OLD.sub(NEW, t)
            if n != t and not check:
                open(sp, "w").write(n)
    # the L3 case that has the P0 text
    for rel in ["tests/scenarios/verify/vf1-verify/expect/stderr"]:
        sp = os.path.join(ROOT, rel)
        t = open(sp).read()
        n = OLD.sub(NEW, t)
        print(f"{rel}: {len(OLD.findall(t))} refusal text(s)")
        if n != t and not check:
            open(sp, "w").write(n)


main()
