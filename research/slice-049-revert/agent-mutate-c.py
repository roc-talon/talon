#!/usr/bin/env python3
"""Revert check of slice 049 part 049c (code agent). Run from the repo root.

Each mutation breaks the code in one small way, runs the layer that must see it, and puts the file back.
  l0  scripts/test.sh l0: caught when a failing test appears that the baseline does not have
      (baseline: none, all tests pass)
  l3  scripts/test.sh l3: caught when a scenario fails (baseline: none)
  l2  scripts/test.sh l2: caught when a case fails that the baseline does not have (baseline: none)
Results go to research/slice-049-revert/agent-results-c.md.
"""
import re, subprocess

R = "research/slice-049-revert"
BASE_L0 = set()
BASE_L2 = set()

# (name, layer, file, [(old, new), ...])
MUTANTS = [
    ("1 GC age boundary: an entry that is exactly as old as the age goes", "l0", "cli/lib/XCache.roc",
     [("facts.now - last > facts.age", "facts.now - last >= facts.age")]),
    ("2 an entry whose manifest cannot be read (no manifest) goes", "l0", "cli/lib/XCache.roc",
     [("			Err(_) => Err(Stays)\n		},\n	)", "			Err(_) => Ok(dir)\n		},\n	)")]),
    ("3 an entry with a newer format or a manifest that does not parse goes", "l0", "cli/lib/XCache.roc",
     [("				_ => Err(Stays)\n			}\n			Err(_)", "				_ => Ok(dir)\n			}\n			Err(_)")]),
    ("4 the age is measured with the real clock, not with the time of Talon (last_run vs TALON_NOW)", "l3", "cli/lib/CacheGc.roc",
     [("now: facts.clocks.now, age: facts.age })", "now: facts.clocks.real, age: facts.age })")]),
    ("5 the expired x dirs are not in the tree_info call (no size, not in builds)", "l2", "cli/lib/CacheGc.roc",
     [("builds: candidates.builds.concat(x_dirs), pkgs", "builds: candidates.builds, pkgs")]),
]


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def l0():
    sh("scripts/test.sh l0")
    log = open(".work/logs/l0.log").read()
    return set(re.findall(r"tests/unit/((?:XCacheTest|XCmdTest)\.roc:\d+):\d+", log))


def l2():
    sh("scripts/test.sh l2")
    log = open(".work/logs/l2.log").read()
    return set(re.findall(r"^FAIL (\S+)", log, re.M))


def l3():
    sh("scripts/test.sh l3")
    log = open(".work/logs/l3.log").read()
    return set(re.findall(r"^FAIL (\S+)", log, re.M))


def main():
    rows = [("0 baseline (no mutation)", "l0", "equal" if l0() == BASE_L0 else "DIFFERENT"),
            ("0 baseline (no mutation)", "l2", "equal" if l2() == BASE_L2 else "DIFFERENT")]
    for name, layer, path, pairs in MUTANTS:
        orig = open(path).read()
        s = orig
        ok = True
        for old, new in pairs:
            if s.count(old) != 1:
                ok = False
            s = s.replace(old, new)
        if not ok:
            rows.append((name, layer, "MUTATION DID NOT APPLY"))
            continue
        open(path, "w").write(s)
        try:
            got = {"l0": l0, "l2": l2, "l3": l3}[layer]()
            extra = sorted(got)
            rows.append((name, layer, "caught by " + ", ".join(extra) if extra else "NOT CAUGHT"))
        finally:
            open(path, "w").write(orig)
    with open(R + "/agent-results-c.md", "w") as f:
        f.write("# Revert check 049c (code agent)\n\n| Mutation | Layer | Result |\n| --- | --- | --- |\n")
        for r in rows:
            f.write("| %s | %s | %s |\n" % r)
    print(open(R + "/agent-results-c.md").read())


main()
