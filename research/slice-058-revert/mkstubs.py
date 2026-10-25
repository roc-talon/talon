#!/usr/bin/env python3
"""Makes the stubs of slice 058 from the reference: RunEach and RunEachFlow (the text up to the end of the module block, each function body replaced by `crash "todo: slice 058"`, private helpers cut), RunCmd (the 057 body, with the 2 new fields False),
RunFlow (the 057 file with the dispatch of `--each`), Args and main.roc (complete). Usage: python3 research/slice-058-revert/mkstubs.py (from the repo root)."""
import re, os
SRC = "research/slice-058-revert/reference/cli/lib/"
BEF = "research/slice-058-revert/before/cli/lib/"
DST = "research/slice-058-revert/stubs/cli/lib/"
os.makedirs(DST, exist_ok=True)
SCAN = "{ walk : List({ dir : Str, names : List(Str), toml : Try(Str, [None]) }), root : Try(Str, [NoWorkspace]), members : List(Str) }"
for name in ["RunEach", "RunEachFlow"]:
    lines = open(SRC + name + ".roc").read().split("\n")
    out, i, in_mod = [], 0, False
    while i < len(lines):
        l = lines[i]
        if re.match(r"^\w+ :: \[\]\.\{", l):
            in_mod = True
        if in_mod and l == "}":
            out.append("}")
            break
        m = re.match(r"^\t([a-z_]+!?) = \|(.*?)\| ", l) if in_mod else None
        if m:
            params = ", ".join("_" + p.strip().rstrip("!") if p.strip() else p for p in m.group(2).split(","))
            out.append(f"\t{m.group(1)} = |{params}| crash \"todo: slice 058\"")
            while i < len(lines) and lines[i] != "" and lines[i] != "}":
                i += 1
            continue
        out.append(l)
        i += 1
    text = "\n".join(out) + "\n"
    text = text.replace("import RunSteps\n", "").replace("RunSteps.Scan", SCAN)
    open(DST + name + ".roc", "w").write(text)
# RunCmd: the 057 body, the 2 new fields are False
s = open(BEF + "RunCmd.roc").read()
ref = open(SRC + "RunCmd.roc").read()
s = s.replace("Cmd : { name : Try(Str, [None]), args : List(Str) }", "Cmd : { name : Try(Str, [None]), args : List(Str), each : Bool, keep_going : Bool }")
s = s.replace("Ok({ name: Err(None), args: [] })", "Ok({ name: Err(None), args: [], each: Bool.False, keep_going: Bool.False })")
s = s.replace("Ok({ name: Ok(name), args: args.passthrough })", "Ok({ name: Ok(name), args: args.passthrough, each: Bool.False, keep_going: Bool.False })")
ref_doc = ref.split("	## Slice 058 (R-RUN13")[1].split("	## One operand is the name as typed")[0]
s = s.replace("	## One operand is the name as typed", "	## Slice 058 (R-RUN13" + ref_doc + "	## One operand is the name as typed", 1)
open(DST + "RunCmd.roc", "w").write(s)
# RunFlow: the 057 file with the dispatch
s = open(BEF + "RunFlow.roc").read()
s = s.replace("import RunFind\n", "import RunEachFlow\nimport RunFind\n")
s = s.replace("	scan = Project.scan!(fx, { start: cwd, home })?\n", "	scan = Project.scan!(fx, { start: cwd, home })?\n	if cmd.each {\n		return RunEachFlow.run!(fx, args, cmd, { env, roots, now, scan }, tln)\n	}\n")
s = s.replace("RunFlow :: [].{", "## Slice 058: with `--each` (`cmd.each`), `flow!` calls `RunEachFlow.run!` right after `Project.scan!` (before the search for the script, R-RUN12 does not apply to `--each`). That module needs the plan and the steps of this module (`plan!`, `steps!`, `derived`, `exec!`, `find_entry`, `tool_run`, `known_files`):\n## move them to a new module (for example `RunSteps`) that both import, so that no module imports a module that imports it and each module stays under 490 lines.\nRunFlow :: [].{", 1)
open(DST + "RunFlow.roc", "w").write(s)
# Args and main.roc: the reference files
open(DST + "Args.roc", "w").write(open(SRC + "Args.roc").read())
m = open(SRC + "main.roc").read().replace("\t\tRunSteps,\n", "")
open(DST + "main.roc", "w").write(m)
