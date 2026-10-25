#!/usr/bin/env python3
"""Revert check of slice 048, part 048b (the code agent). Run from the repo root.

Each mutation breaks one small thing of the live code in cli/lib, runs only the test that must see it,
and puts the file back from research/slice-048-revert/code-final-b/. At the end, `sha256sum -c` of
code-final-b.sha256 shows that the code is the same as before the mutations.

L0: the only test that fails in the final state is ToolSourceTest 7 (`way`, `moved`: 048c, line 192). A mutation
is caught by L0 only when another line fails, or the compile fails. L2: the case name has to fail.
"""
import re
import shutil
import subprocess
import sys

LIB = "cli/lib/"
FINAL = "research/slice-048-revert/code-final-b/"
ENV = ". scripts/env.sh; "

BASE = {
    "tests/unit/l0-3.roc": set(),
    "tests/unit/l0-4.roc": {192},
}

L2 = [("l2", "tm1-manage"), ("l2", "tr1-rebuild"), ("l2", "tr2-rebuildstops")]

MUTATIONS = [
    # (name, file, old, new, [tests])
    (
        "M1 rm writes tools.json before it deletes the files (D12)",
        "ToolManageFlow.roc",
        "\tfor result in fx.delete!(gone) {\n\t\tmatch result {\n\t\t\tOk(_) | Err(NotFound) => {}\n\t\t\tErr(err) => return Err(Fail.new(Environment, \"cannot delete a file of ${tool.key}: ${Str.inspect(err)}\"))\n\t\t}\n\t}\n\tSetupIo.write_file!(fx, paths.tools_file, updated)?\n",
        "\tSetupIo.write_file!(fx, paths.tools_file, updated)?\n\tfor result in fx.delete!(gone) {\n\t\tmatch result {\n\t\t\tOk(_) | Err(NotFound) => {}\n\t\t\tErr(err) => return Err(Fail.new(Environment, \"cannot delete a file of ${tool.key}: ${Str.inspect(err)}\"))\n\t\t}\n\t}\n",
        [("l2", "tm1-manage")],
    ),
    (
        "M2 rm deletes a bin dir entry that is not Talon's (R-ST11)",
        "ToolManage.roc",
        "\t\t\tOk(old) if old == sha => Remove\n\t\t\t_ => Keep\n",
        "\t\t\tOk(old) if old == sha => Remove\n\t\t\t_ => Remove\n",
        [("l0", "tests/unit/l0-3.roc"), ("l2", "tm1-manage")],
    ),
    (
        "M3 rm takes no lock of tools.json (R-CC6)",
        "ToolManageFlow.roc",
        "\tfx.locked!(tools_file, || remove_locked!(fx, tool, paths))\n",
        "\tremove_locked!(fx, tool, paths)\n",
        [("l2", "tm1-manage")],
    ),
    (
        "M4 rebuild builds with the pin of the header, not the recorded compiler (R-T5)",
        "ToolUpdateFlow.roc",
        "id: tool.nightly, temp }",
        "id: bundle.pin ?? tool.nightly, temp }",
        [("l2", "tr1-rebuild")],
    ),
    (
        "M5 rebuild with no name does not take all tools (D1)",
        "ToolUpdateFlow.roc",
        "\t\tErr(None) => machine.tools\n",
        "\t\tErr(None) => []\n",
        [("l2", "tr1-rebuild"), ("l2", "tr2-rebuildstops")],
    ),
    (
        "M6 the plan does not stop at the first failure (Q-U2)",
        "ToolUpdateFlow.roc",
        "\t\t\t\tclean!(fx, $jobs)\n\t\t\t\treturn Err(fail)\n",
        "\t\t\t\tclean!(fx, $jobs)\n\t\t\t\tif tool.key == \"\" return Err(fail)\n",
        [("l2", "tr2-rebuildstops")],
    ),
    (
        "M7 the foreign text of rebuild names --as (Q-U3)",
        "ToolUpdate.roc",
        "Move or remove that file, then run the command again.\")",
        "Use --as <name> to install under another name.\")",
        [("l0", "tests/unit/l0-4.roc"), ("l2", "tr2-rebuildstops")],
    ),
    (
        "M8 the source of the manifest is read after the check of the bin dir entry (pure checks first)",
        "ToolUpdateFlow.roc",
        "\torigin = ToolUpdate.origin(tool)?\n\tmatch ToolBuild.entry_state!(fx, facts)? {\n\t\tMake => {}\n\t\tForeign => return Err(ToolUpdate.foreign_failure(Text.join(facts.bin, facts.file)))\n\t}\n",
        "\tmatch ToolBuild.entry_state!(fx, facts)? {\n\t\tMake => {}\n\t\tForeign => return Err(ToolUpdate.foreign_failure(Text.join(facts.bin, facts.file)))\n\t}\n\torigin = ToolUpdate.origin(tool)?\n",
        [("l2", "tr2-rebuildstops")],
    ),
    (
        "M9 the downloads count a compiler twice",
        "ToolUpdate.roc",
        "if facts.installed.contains(id) or found.contains(id) found else found.append(id)",
        "if facts.installed.contains(id) found else found.append(id)",
        [("l0", "tests/unit/l0-4.roc")],
    ),
    (
        "M10 the scratch dirs of the git sources are not deleted (R-CC2)",
        "ToolUpdateFlow.roc",
        "\tif !temps.is_empty() {\n\t\t_ = fx.delete!(temps)\n\t}\n",
        "\tif temps.is_empty() {\n\t\t_ = fx.delete!(temps)\n\t}\n",
        [("l2", "tr1-rebuild"), ("l2", "tr2-rebuildstops")],
    ),
    (
        "M11 drop removes the other tools (R-B6)",
        "ToolsJson.roc",
        "without = pairs.keep_if(|(key, _)| key != facts.key)",
        "without = pairs.keep_if(|(key, _)| key == facts.key)",
        [("l0", "tests/unit/l0-3.roc")],
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
    code, out = sh("sha256sum -c research/slice-048-revert/code-final-b.sha256")
    same = code == 0
    print("code is the same as before the mutations:", same)
    with open("research/slice-048-revert/agent-results-b.md", "w") as f:
        f.write("# Revert check, slice 048 part 048b (code agent)\n\n| Mutation | Caught by |\n| --- | --- |\n")
        for name, caught in results:
            f.write(f"| {name} | {caught} |\n")
        n = sum(1 for _, c in results if not c.startswith(("not caught", "NOT APPLIED")))
        f.write(f"\nCaught {n} of {len(results)}. Code the same as before: {same}.\n")
    sys.exit(0 if same else 1)


main()
