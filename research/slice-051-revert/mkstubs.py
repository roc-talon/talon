#!/usr/bin/env python3
"""Makes the stubs of slice 051 from the reference (deleted at the review): TalonRemove (the module block up to its closing brace, each function body replaced by `crash "todo: slice 051a"`, private helpers cut, `is_target` complete: `Run.run!` calls it for each `tool remove`),
TalonRemoveFlow (`remove!` is `crash "todo: slice 051b"`), Setup (the state before slice 051 and the 2 stubs `profiles` and `profile_strip`), RealFx (the state before slice 051 and the field `spawn_detached!` with a stub body, `todo: slice 051c`),
Fx, main and Run (complete wiring, as in the reference). ToolManage is the file before slice 051 (the code agent writes its change, part 051a). Usage: python3 research/slice-051-revert/mkstubs.py (from the repo root)."""
import re, os
SRC = "research/slice-051-revert/reference/cli/"
BEF = "research/slice-051-revert/before/cli/"
DST = "research/slice-051-revert/stubs/cli/"
os.makedirs(DST + "lib", exist_ok=True)


def stub_module(text, todo):
    lines = text.split("\n")
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
            out.append(f'\t{m.group(1)} = |{params}| crash "{todo}"')
            while i < len(lines) and lines[i] != "" and lines[i] != "}":
                i += 1
            continue
        out.append(l)
        i += 1
    return "\n".join(out) + "\n"


# TalonRemove: the same imports as the reference (a stub that does not use an import is a warning: `Prompt`, `Roots`, ... are in the signatures, `Compiler`, `Text`, `ToolInstall` and `Toolchain` are not)
s = stub_module(open(SRC + "lib/TalonRemove.roc").read(), "todo: slice 051a")
body = s.split("\n## The pure decisions", 1)[1]
used = [n for n in ["Answer", "Args", "Compiler", "Fail", "JsonDoc", "Prompt", "Roots", "Setup", "Text", "Toolchain", "ToolInstall"] if re.search(r"\b" + n + r"\b", body)]
s = "".join(f"import {n}\n" for n in used) + "\n## The pure decisions" + body
s = s.replace('\tis_target = |_args| crash "todo: slice 051a"', '\tis_target = |args| match args.operands {\n\t\t[one] => one == "talon" or one == "roc-talon/talon"\n\t\t_ => Bool.False\n\t}')
open(DST + "lib/TalonRemove.roc", "w").write(s)

# TalonRemoveFlow
s = stub_module(open(SRC + "lib/TalonRemoveFlow.roc").read(), "todo: slice 051b")
head = s.split("\n## The command `tln tool remove talon", 1)[1]
note = "## Part 051b (this module): the command code (the order of the removal, the prompt, the checks, `unix!`). `windows!` is part 051c: in 051b it is `crash \"todo: slice 051c\"` (with `RealFx.spawn_detached!`). Part 051a (`TalonRemove`, `Setup.profiles`, `Setup.profile_strip`, `ToolManage`) comes first."
s = "import Args\nimport Fx\n\n## The command `tln tool remove talon" + head
s = s.replace("TalonRemoveFlow :: [].{", note + "\nTalonRemoveFlow :: [].{", 1)
open(DST + "lib/TalonRemoveFlow.roc", "w").write(s)

# Setup: before + the 2 stubs
ref = open(SRC + "lib/Setup.roc").read()
start = ref.index("\t## R-RM8, R-ST4: the 3 profiles")
end_ = ref.index("\n\n", ref.index("\tprofile_strip = ")) + 1
block = stub_module("X :: [].{\n" + ref[start:end_] + "}\n", "todo: slice 051a").split("\n", 1)[1].rsplit("}", 1)[0]
bef = open(BEF + "lib/Setup.roc").read()
pos = bef.index("\n", bef.index("\n\n", bef.index("\t\tShell"))) if False else None
mark_at = ref.index(ref[start:end_])
prefix = ref[:start]
assert bef.startswith(prefix), "Setup before and reference differ before the block"
open(DST + "lib/Setup.roc", "w").write(prefix + block.rstrip("\n") + "\n\n" + bef[len(prefix):])

# RealFx: before + the field and a stub body
bef = open(BEF + "RealFx.roc").read()
bef = bef.replace("\texec_in!: exec_in!,\n}", "\texec_in!: exec_in!,\n\tspawn_detached!: spawn_detached!,\n}", 1)
stub = '''## Slice 051, R-RM5: one child that goes on after `tln` ends. `Cmd.spawn!` of basic-cli ends the child when its handle is released, so the real call needs a launcher (`sh -c` and `&`, `cmd.exe /d /c start "" /b`): see Q-RM1 of the slice file. Part 051c.
spawn_detached! : { argv : List(Str), env : List((Str, Str)) } => Try({}, [NotStarted(Str)])
spawn_detached! = |_run| crash "todo: slice 051c"

'''
at = bef.index("cwd! : () => Str")
open(DST + "RealFx.roc", "w").write(bef[:at] + stub + bef[at:])

for name in ["Fx", "main", "Run"]:
    open(DST + "lib/" + name + ".roc", "w").write(open(SRC + "lib/" + name + ".roc").read())

# ToolManage: the state before slice 051 (the code agent writes the change)
open(DST + "lib/ToolManage.roc", "w").write(open(BEF + "lib/ToolManage.roc").read())
