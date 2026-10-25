#!/usr/bin/env python3
"""Revert check of slice 049 (test agent): 10 mutations of the private reference (installed in cli/lib by install-ref.sh) on the most tricky behaviors. Each mutation breaks one file in one small way,
runs only the test that must see it, prints the result and puts the file back. Run from the repo root: sh research/slice-049-revert/install-ref.sh; python3 research/slice-049-revert/mutants.py [number ...]
After the run: sh research/slice-049-revert/restore.sh (stubs back). Never a full sweep."""
import os, re, subprocess, sys

ROOT = os.getcwd()
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
L0_5 = f"XDG_CACHE_HOME=$PWD/.work/cache ROC_CACHE_DIR=$PWD/.work/cache/roc {ROC} test tests/unit/l0-5.roc"
XC = "cli/lib/XCache.roc"
XT = "cli/lib/XTake.roc"
XF = "cli/lib/XFlow.roc"
XI = "cli/lib/XCacheIo.roc"

# (number, what, file, [(old, new)], command, the test that must see it)
M = [
    (1, "an installed tool and an entry of the same version: the entry wins (R-B1: the installed tool wins a tie)", XC,
     [("\t\t\t\t\t_ => Ok(held)", "\t\t\t\t\tSame => Ok(have)\n\t\t\t\t\t_ => Ok(held)")],
     "tests/commands/run.sh x/x1-run", "L0 XCacheTest choose, L2 x1 run 8 (baz runs from talon/x)"),
    (2, "online, the winner needs not be a candidate of the release list (R-B3)", XC,
     [("Online(on) => if on.listed.contains(winner.version) winner.choice else NoMatch", "Online(_) => winner.choice")],
     "tests/commands/run.sh x/x1-run tool/tk1-takeover", "L0 XCacheTest choose, L2 x1 run 9, tk1 run 6"),
    (3, "a selector matches any version online (R-B2: the selector must mean the version of the build)", XC,
     [("Online(on) => version == on.first", "Online(_) => Bool.True")],
     "tests/commands/run.sh x/x1-run tool/tk1-takeover", "L0 XCacheTest choose, L2 x1 run 4 and 6, tk1 run 5"),
    (4, "versions are compared by the first number only (R-B1: the highest version wins)", XC,
     [("if x < y Before else if x > y After else compare_versions(xs, ys)", "if x < y Before else if x > y After else Same")],
     L0_5, "L0 XCacheTest choose, is_older"),
    (5, "the sha256 of the entry binary is not compared before the move (R-B4, Q-T3)", XT,
     [("Ok(sha) => if sha != hit.entry.sha256 {", "Ok(sha) => if Bool.False and sha != hit.entry.sha256 {")],
     "tests/commands/run.sh tool/tk1-takeover", "L2 tk1 run 10 (exit 16, no move)"),
    (6, "the entry dir is not deleted after a take-over by move (R-B4: one owner)", XT,
     [("if take_how == Move {", "if take_how == Copy {")],
     "tests/commands/run.sh tool/tk1-takeover", "L2 tk1 runs 1 to 4 (calls.log: delete) and tree.diff"),
    (7, "a run of a cached entry does not write the new last_run (R-GC7 needs it)", XF,
     [("\t\t\tXCacheIo.touch!(fx, hit, Clock.format_utc(facts.now))?\n\t\t\texec!(fx, ctx, XCacheIo.bin_of({ found: hit, os: facts.os }))\n\t\t}\n\t\tNoMatch", "\t\t\texec!(fx, ctx, XCacheIo.bin_of({ found: hit, os: facts.os }))\n\t\t}\n\t\tNoMatch")],
     "tests/commands/run.sh x/x1-run", "L2 x1 run 5 (calls.log: write_atomic, tree.diff: last_run)"),
    (8, "gc removes an entry that is exactly as old as the gc age (R-GC7, R-GC9: older than the age)", XC,
     [("now > time and now - time > span", "now > time and now - time >= span")],
     "tests/commands/run.sh gc/gc4-x", "L0 XCacheTest expired, L2 gc4 (the boundary entry)"),
    (9, "offline, a range or `latest` selector matches any build (Q-O2: only an exact version matches)", XC,
     [("\t\t\tExact(wanted) => version == wanted\n\t\t\t_ => Bool.False", "\t\t\tExact(wanted) => version == wanted\n\t\t\t_ => Bool.True")],
     L0_5, "L0 XCacheTest choose offline"),
    (10, "the loser of a race keeps its temp dir (R-CC11)", XI,
     [("\t\t\tErr(Exists) => {\n\t\t\t\t_ = fx.delete!([lay.temp])\n\t\t\t}", "\t\t\tErr(Exists) => {}")],
     "tests/commands/run.sh x/x1-run", "L2 x1 run 9 (calls.log: delete of the temp dir)"),
    (11, "gc removes an entry dir with no manifest (Q-G1: it stays)", XC,
     [("\tErr(_) => Bool.False\n}", "\tErr(_) => Bool.True\n}")],
     "tests/commands/run.sh gc/gc4-x", "L0 XCacheTest expired, L2 gc4 (the dir `nomanifest`)"),
]


def run(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, executable="/bin/bash")
    return p.returncode, p.stdout + p.stderr


def main():
    want = [int(a) for a in sys.argv[1:]]
    for num, what, path, edits, cmd, expect in M:
        if want and num not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        mutated = original
        for o, n in edits:
            assert mutated.count(o) == 1, f"mutation {num}: old text found {mutated.count(o)} times"
            mutated = mutated.replace(o, n, 1)
        try:
            open(full, "w").write(mutated)
            rc, out = run(cmd)
        finally:
            open(full, "w").write(original)
        fails = [l.strip()[:120] for l in out.splitlines() if l.startswith("FAIL") or re.match(r"^\s+\d+ failed", l) or "compiler errors" in l or l.startswith("commands:") or l.startswith("scenarios:")][:5]
        where = sorted(set(re.findall(r"X\w+Test\.roc:\d+", out)))[:3]
        if where:
            fails.append("at " + ", ".join(where))
        print(f"{num}\t{'CAUGHT' if rc != 0 else 'NOT CAUGHT'}\t{what}\t(expected: {expect})\t{' | '.join(fails)}", flush=True)


main()
