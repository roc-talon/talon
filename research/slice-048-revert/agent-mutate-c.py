#!/usr/bin/env python3
"""Revert check of slice 048, part 048c (the code agent). Run from the repo root.

Each mutation breaks one small thing of the live code in cli/lib, runs only the test that must see it,
and puts the file back from research/slice-048-revert/code-final/. At the end, `sha256sum -c` of
code-final.sha256 shows that the code is the same as before the mutations.

L0: no test fails in the final state. A mutation is caught by L0 when a line fails or the compile fails. L2: the case name has to fail.
"""
import re
import shutil
import subprocess
import sys

LIB = "cli/lib/"
FINAL = "research/slice-048-revert/code-final/"
ENV = ". scripts/env.sh; "

BASE = {
    "tests/unit/l0-3.roc": set(),
    "tests/unit/l0-4.roc": set(),
}

MUTATIONS = [
    # (name, file, old, new, [tests])
    (
        "M1 a branch whose head moved is up to date (no new build)",
        "ToolUpdate.roc",
        "\t\tGit(git) if git.commit == facts.sha => Same\n\t\t_ => Moved\n",
        "\t\tGit(_) => Same\n\t\t_ => Moved\n",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tu1-update")],
    ),
    (
        "M2 a sha-pinned ref is a branch (the head is requested, R-SL10)",
        "ToolUpdate.roc",
        "bytes.len() >= 7 and",
        "bytes.len() >= 40 and",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tu1-update")],
    ),
    (
        "M3 a release tool is compared with no selector (any build is enough, not the newest release)",
        "ToolUpdateFlow.roc",
        "\tselector = Ok(Selector.Latest)\n",
        "\tselector = Err(None)\n",
        [("l2", "tu1-update")],
    ),
    (
        "M4 a release tool is always built (no up to date)",
        "ToolUpdateFlow.roc",
        "first: newest.ident.version })",
        "first: \"\" })",
        [("l2", "tu1-update")],
    ),
    (
        "M5 the pinned text has no key prefix",
        "ToolUpdate.roc",
        "\"${facts.key}: pinned to commit ${short(facts.commit)}\"",
        "\"pinned to commit ${short(facts.commit)}\"",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tu1-update")],
    ),
    (
        "M6 the consent stop does not stop: the builds start (consent before any build)",
        "ToolUpdateFlow.roc",
        "\t\tErr(fail) => Err(fail)\n\t}\n\tclean!(fx, jobs)",
        "\t\tErr(_) => build_all!(fx, args, items, kind)\n\t}\n\tclean!(fx, jobs)",
        [("l2", "tu1-update")],
    ),
    (
        "M7 update builds with the recorded compiler, not the pin of the new header (R-T24)",
        "ToolUpdateFlow.roc",
        "\tid = pin_of(tool, bundle)?\n",
        "\tid = tool.nightly\n",
        [("l2", "tu1-update")],
    ),
]


def sh(cmd):
    r = subprocess.run(["bash", "-c", ENV + cmd], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def run_l0(driver):
    code, out = sh(f'"$ROC" test {driver}')
    failed = {int(m) for m in re.findall(r"✗ fail [─]+ tests/unit/\w+\.roc:(\d+):\d+", out)}
    extra = failed - BASE[driver]
    if re.search(r"[1-9]\d* compiler errors", out) or (code not in (0, 1) and not failed):
        return True, "compiler errors"
    return bool(extra), f"new failing lines {sorted(extra)}" if extra else "no new failure"


def run_l2(case):
    code, out = sh(f"tests/commands/run.sh tool/{case}")
    bad = f"FAIL tool/{case}" in out
    return bad, "FAIL" if bad else "pass"


def main():
    results = []
    for name, file, old, new, tests in MUTATIONS:
        path = LIB + file
        text = open(path).read()
        if text.count(old) != 1:
            results.append((name, f"NOT APPLIED ({text.count(old)} matches)"))
            continue
        open(path, "w").write(text.replace(old, new))
        caught = "not caught"
        try:
            for kind, what in tests:
                ok, note = run_l0(what) if kind == "l0" else run_l2(what)
                if ok:
                    caught = f"{kind} {what}: {note}"
                    break
        finally:
            shutil.copyfile(FINAL + file, path)
        results.append((name, caught))
        print(name, "->", caught, flush=True)
    code, out = sh("sha256sum -c research/slice-048-revert/code-final.sha256")
    same = code == 0
    print("code is the same as before the mutations:", same)
    with open("research/slice-048-revert/agent-results-c.md", "w") as f:
        f.write("# Revert check, slice 048 part 048b (code agent)\n\n| Mutation | Caught by |\n| --- | --- |\n")
        for name, caught in results:
            f.write(f"| {name} | {caught} |\n")
        n = sum(1 for _, c in results if not c.startswith(("not caught", "NOT APPLIED")))
        f.write(f"\nCaught {n} of {len(results)}. Code the same as before: {same}.\n")
    sys.exit(0 if same else 1)


main()
