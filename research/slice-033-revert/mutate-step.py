#!/usr/bin/env python3
"""Revert check of the l1 step (TW12): each mutation changes one thing in scripts/test.sh, then `scripts/test.sh selftest` must fail
(the rows `s_l1` of tests/selftest.sh). The file is copied back from test.sh.final after each run and at the end.
Usage: mutate-step.py [id ...]"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-033-revert/test.sh.final")
DST = os.path.join(ROOT, "scripts/test.sh")
M = [
    ("t1", "the fuzz build follows OPT", '--fuzz --opt=speed "$1"', '--fuzz --opt="$OPT" "$1"'),
    ("t2", "no --fuzz in the build", 'build --fuzz --opt=speed', 'build --opt=speed'),
    ("t3", "--time in place of --runs", '--runs="$L1_RUNS"', '--time=5'),
    ("t4", "no seed", ' --seed="$L1_SEED"', ''),
    ("t5", "the target runs in the repo dir", '( cd "$d" && ./target run', '( ./target run'),
    ("t6", "an old run dir stays", '    rm -rf "$dir"\n    mkdir -p "$dir"\n    export -f fuzz_one', '    mkdir -p "$dir"\n    export -f fuzz_one'),
    ("t7", "no skip on another system", 'Linux-x86_64 | Darwin-arm64) ;;', '*) ;;'),
    ("t8", "a failing run does not fail the step", '            done\n            rc=1\n', '            done\n'),
    ("t9", "no replay line", 'echo "replay: $d/target replay $a"', 'true'),
    ("t10", "a failing build does not fail the step", 'echo "$f: FAILED, the build"; cat "$d/build.log"; rc=1', 'echo "$f: FAILED, the build"; cat "$d/build.log"'),
    ("t11", "l1 is not a default step", 'STEPS=(check fmt l0 l1 l2 l3 selftest)', 'STEPS=(check fmt l0 l2 l3 selftest)'),
    ("t12", "the libFuzzer noise stays in the report", "grep -v -e '^INFO' -e '^#' -e '^\"' -e '^######' \"$d/run.log\" | head -n 40", 'head -n 40 "$d/run.log"'),
    ("t13", "Darwin-arm64 is not supported", 'Linux-x86_64 | Darwin-arm64) ;;', 'Linux-x86_64) ;;'),
    ("t14", "the budget of l1 is 90", '[l1]=60', '[l1]=90'),
    ("t15", "the default runs are 5", 'L1_RUNS=${L1_RUNS:-20000}', 'L1_RUNS=${L1_RUNS:-5}'),
    ("t16", "the skip is a failure", 'echo "l1: skipped, roc-fuzz has no platform for $host"; return 0', 'echo "l1: skipped, roc-fuzz has no platform for $host"; return 1'),
]
want = sys.argv[1:]
ref = open(FINAL).read()
try:
    for mid, what, old, new in M:
        if want and mid not in want:
            continue
        if ref.count(old) != 1:
            print(f"{mid} SKIP: old text occurs {ref.count(old)} times")
            continue
        open(DST, "w").write(ref.replace(old, new))
        syn = subprocess.run(["bash", "-n", DST], capture_output=True, text=True)
        if syn.returncode != 0:
            print(f"{mid} {what}: SYNTAX ERROR {syn.stderr[:200]}")
            continue
        r = subprocess.run(["scripts/test.sh", "selftest"], cwd=ROOT, capture_output=True, text=True)
        fails = [l for l in r.stdout.splitlines() if l.startswith("SELFTEST FAIL")]
        print(f"{mid} {what}: {'caught' if r.returncode != 0 else 'MISSED'} ({len(fails)} rows)  {fails[0][:150] if fails else ''}", flush=True)
finally:
    shutil.copyfile(FINAL, DST)
print("restored:", open(DST).read() == ref)
