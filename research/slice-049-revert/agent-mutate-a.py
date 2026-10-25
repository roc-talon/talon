#!/usr/bin/env python3
"""Revert check of slice 049 part 049a (code agent). Run from the repo root.

Each mutation breaks the code in one small way, runs the test that must see it, and puts the file back.
  l0     scripts/test.sh l0: caught when a failing test appears that the baseline does not have
         (the baseline is the 6 tests of 049b and 049c that stay red: XCacheTest 223, 275, 300, 319 and XCmdTest 62, 78)
  mini   scripts/test.sh l2 (it builds the L2 app), then the 2 scratch cases of mini-a/ (expect/ made from the
         checked 049a code: runs 1, 4, 10, 11, 12 and 13, 9, 6 of x/x1-run) with L2BIN: caught when a case fails
Results go to research/slice-049-revert/agent-results-a.md.
"""
import os, re, shutil, subprocess, sys

ROOT = os.getcwd()
R = "research/slice-049-revert"
BASE_L0 = {"XCacheTest.roc:223", "XCacheTest.roc:275", "XCacheTest.roc:300", "XCacheTest.roc:319", "XCmdTest.roc:62", "XCmdTest.roc:78"}

MUTANTS = [
    ("1 digest without the bundle hash (D1)", "l0", "cli/lib/XCache.roc",
     '"${facts.name}\\n${facts.bundle}\\n${Str.join_with', '"${facts.name}\\n${Str.join_with'),
    ("2 an entry dir may have a dot in its name (a stale temp dir is an entry)", "l0", "cli/lib/XCache.roc",
     ' and !Text.last_segment(e.path).contains(".")', ''),
    ("3 a manifest with a newer format is deleted, not ignored", "l0", "cli/lib/XCache.roc",
     'Ok(Ignore) => Ignore', 'Ok(Ignore) => bad'),
    ("4 an entry with no binary is a match (has_bin true)", "mini", "cli/lib/XCacheIo.roc",
     'Ok(found) => found.any(|e| e.name != "manifest.json")', 'Ok(_) => Bool.True'),
    ("5 the manifest of a build has no last_run", "mini", "cli/lib/XFlow.roc",
     'last_run: Clock.format_utc(facts.now) }', 'last_run: "" }'),
    ("6 the loser of a race keeps its temp dir (Exists)", "mini", "cli/lib/XCacheIo.roc",
     '''			Err(Exists) => {
				_ = fx.delete!([lay.temp])
				Ok(made)
			}''', '''			Err(Exists) => Ok(made)'''),
    ("7 the exit code of the app is not the exit code of tln x", "mini", "cli/lib/XFlow.roc",
     'Ok(code) => Ok(code)\n\tErr(NotStarted', 'Ok(_) => Ok(0)\n\tErr(NotStarted'),
    ("8 the dir with no binary is not deleted before the rename (stale ignored)", "mini", "cli/lib/XCacheIo.roc",
     'if facts.stale.contains(lay.dir) {', 'if facts.stale.contains(lay.dir) and lay.dir == "" {'),
    ("9 the temp dir of the build stays after a pass", "mini", "cli/lib/XFlow.roc",
     '\t\t\t_ = fx.delete!([attempt.layout.temp])\n', ''),
    ("10 the words after -- are not given to the app", "mini", "cli/lib/XCmd.roc",
     'args: args.passthrough })', 'args: [] })'),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, **kw)


def l0_failures():
    sh("scripts/test.sh l0")
    log = open(".work/logs/l0.log").read()
    got = set(re.findall(r"tests/unit/((?:XCacheTest|XCmdTest)\.roc:\d+):\d+", log))
    return got, False


def mini_fails():
    sh("scripts/test.sh l2")
    out = sh("CASES=%s/mini-a L2BIN=%s/.work/bin/l2 tests/commands/run.sh" % (R, ROOT))
    m = re.search(r"commands: (\d+) passed, (\d+) failed", out.stdout + out.stderr)
    return (int(m.group(2)) if m else -1), (out.stdout + out.stderr)


def main():
    results = []
    # the baseline
    got, bad = l0_failures()
    results.append(("0 baseline (no mutation)", "l0", "baseline " + ("equal" if got == BASE_L0 and not bad else "DIFFERENT: %s" % sorted(got ^ BASE_L0))))
    n, _ = mini_fails()
    results.append(("0 baseline (no mutation)", "mini", "%d mini cases failed (want 0)" % n))
    for name, kind, path, old, new in MUTANTS:
        orig = open(path).read()
        if orig.count(old) != 1:
            results.append((name, kind, "MUTATION DID NOT APPLY (%d matches)" % orig.count(old)))
            continue
        open(path, "w").write(orig.replace(old, new))
        try:
            if kind == "l0":
                got, bad = l0_failures()
                extra = sorted(got - BASE_L0)
                caught = bool(extra) or bad
                results.append((name, kind, "caught by " + (", ".join(extra) or "a compile error") if caught else "NOT CAUGHT"))
            else:
                n, text = mini_fails()
                if n > 0:
                    cases = re.findall(r"FAIL (\S+)", text)
                    results.append((name, kind, "caught by the mini case " + ", ".join(cases)))
                elif n < 0:
                    results.append((name, kind, "the build broke (%s)" % text.strip()[:100]))
                else:
                    results.append((name, kind, "NOT CAUGHT"))
        finally:
            open(path, "w").write(orig)
    with open(R + "/agent-results-a.md", "w") as f:
        f.write("# Revert check 049a (code agent)\n\n| Mutation | Layer | Result |\n| --- | --- | --- |\n")
        for r in results:
            f.write("| %s | %s | %s |\n" % r)
    print(open(R + "/agent-results-a.md").read())


main()
