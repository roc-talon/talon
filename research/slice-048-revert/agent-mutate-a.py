#!/usr/bin/env python3
"""Revert check of slice 048, part 048a (the code agent). Run from the repo root.

Each mutation breaks one small thing of the live code in cli/lib, runs only the test that must see it,
and puts the file back from research/slice-048-revert/code-final-a/. At the end, `sha256sum -c` of
code-final-a.sha256 shows that the code is the same as before the mutations.

L0 tests that fail on `todo` of parts 048b and 048c are the baseline: a mutation is caught by L0 only when
a line of a test fails that is not in the baseline. L2: the case name has to fail.
"""
import re
import shutil
import subprocess
import sys

LIB = "cli/lib/"
FINAL = "research/slice-048-revert/code-final-a/"
ENV = ". scripts/env.sh; "

# The baseline of L0: tests that fail because of the stubs of 048b and 048c (line of the `expect`).
BASE = {
    "tests/unit/l0-3.roc": {36, 88, 105, 119, 140, 157, 173, 189, 236},
    "tests/unit/l0-4.roc": {192, 216, 241, 261, 278, 309},
}

MUTATIONS = [
    # (name, file, old, new, [tests])
    (
        "M1 a sha selector with no --git is not a git source",
        "ToolGit.roc",
        "(Full, Ok(GitSha(ref)), Ok({ before, after })) => Ok((parsed",
        "(Full, Ok(GitRef(ref)), Ok({ before, after })) => Ok((parsed",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tg1-git")],
    ),
    (
        "M2 the same commit is not needed for Keep (any git tool is Present)",
        "ToolGit.roc",
        "Git(git) if git.commit == facts.sha => Keep",
        "Git(git) => Keep",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tg1-git")],
    ),
    (
        "M3 a git install keeps a release tool (no replace, R-T27)",
        "ToolGit.roc",
        "\t\t\t_ => Build\n\t\t}\n\t\tErr(None) => Build",
        "\t\t\tRelease(rel) => Keep(rel.version)\n\t\t}\n\t\tErr(None) => Build",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tg1-git")],
    ),
    (
        "M4 the source is fetched before the check of the bin dir entry",
        "ToolGitFlow.roc",
        "\tToolBuild.entry_verdict!(fx, facts)?\n\tToolGitFlow.check_curl!(fx, facts.net)?\n\tmade = ToolGitFlow.source!(fx, facts, { source: plan.source, sha, path: plan.path })?\n",
        "\tToolGitFlow.check_curl!(fx, facts.net)?\n\tmade = ToolGitFlow.source!(fx, facts, { source: plan.source, sha, path: plan.path })?\n\tToolBuild.entry_verdict!(fx, facts)?\n",
        [("l2", "tg2-gitstops")],
    ),
    (
        "M5 wget is accepted for the source archive (curl only, R-DA3)",
        "ToolGitFlow.roc",
        "\t\t\tWget => Err(ToolGit.needs_curl({}))",
        "\t\t\tWget => Ok({})",
        [("l2", "tg2-gitstops")],
    ),
    (
        "M6 --offline is checked after the commit request",
        "ToolGitFlow.roc",
        "\tif args.offline return Err(GitRef.offline_failure(plan.source))\n\tsha = ToolGitFlow.head!(fx, facts.net, plan.source, facts.now)?\n",
        "\tsha = ToolGitFlow.head!(fx, facts.net, plan.source, facts.now)?\n\tif args.offline return Err(GitRef.offline_failure(plan.source))\n",
        [("l2", "tg2-gitstops")],
    ),
    (
        "M7 the temp dir of the source is not deleted after a failure",
        "ToolGitFlow.roc",
        "\t\t\tErr(fail) => {\n\t\t\t\t_ = fx.delete!([lay.temp])\n\t\t\t\tErr(fail)\n\t\t\t}",
        "\t\t\tErr(fail) => Err(fail)",
        [("l2", "tg2-gitstops"), ("l2", "tg1-git")],
    ),
    (
        "M8 --path may have a .. part (R-SE12)",
        "ToolGit.roc",
        " or text.split_on(\"/\").any(|part| part == \"..\")",
        "",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tg2-gitstops")],
    ),
    (
        "M9 tools.json has no path of a git tool",
        "ToolsJson.roc",
        "Ok(path) => Obj(head.append((\"path\", Text(path))))",
        "Ok(_) => Obj(head)",
        [("l0", "tests/unit/l0-3.roc"), ("l2", "tg1-git")],
    ),
]


def sh(cmd):
    r = subprocess.run(["bash", "-c", ENV + cmd], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def run_l0(driver):
    code, out = sh(f'"$ROC" test {driver}')
    failed = {int(m) for m in re.findall(r"✗ fail [─]+ tests/unit/\w+\.roc:(\d+):\d+", out)}
    extra = failed - BASE[driver]
    if "compiler error" in out and re.search(r"[1-9]\d* compiler errors", out):
        return True, "compiler errors"
    return bool(extra), f"new failing lines {sorted(extra)}" if extra else "no new failure"


def run_l2(case):
    code, out = sh(f"tests/commands/run.sh {case}")
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
    code, out = sh("sha256sum -c research/slice-048-revert/code-final-a.sha256")
    same = code == 0
    print("code is the same as before the mutations:", same)
    with open("research/slice-048-revert/agent-results-a.md", "w") as f:
        f.write("# Revert check, slice 048 part 048a (code agent)\n\n| Mutation | Caught by |\n| --- | --- |\n")
        for name, caught in results:
            f.write(f"| {name} | {caught} |\n")
        n = sum(1 for _, c in results if not c.startswith(("not caught", "NOT APPLIED")))
        f.write(f"\nCaught {n} of {len(results)}. Code the same as before: {same}.\n")
    sys.exit(0 if same else 1)


main()
