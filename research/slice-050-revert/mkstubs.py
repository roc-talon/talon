#!/usr/bin/env python3
"""Makes the stubs of slice 050 from the reference (deleted at the review): TalonUpdate and TalonUpdateFlow (the module block up to its closing brace, each function body replaced by `crash "todo: slice 050a"` (TalonUpdate, ToolsJson) or `"todo: slice 050b"` (TalonUpdateFlow), private helpers cut),
ToolsJson (the 049-state file with the types `TalonSource` and `Talon` and the 2 stubs `talon` and `put_talon` inside the module), main.roc and Run.roc (complete wiring, complete as in the reference).
ToolManage, ToolManageFlow, ToolUpdateFlow, ToolBuild stay as before (the code agent writes their changes, parts 050a and 050b). Usage: python3 research/slice-050-revert/mkstubs.py (from the repo root)."""
import re, os
SRC = "research/slice-050-revert/reference/cli/lib/"
BEF = "research/slice-050-revert/before/cli/lib/"
DST = "research/slice-050-revert/stubs/cli/lib/"
os.makedirs(DST, exist_ok=True)


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


# TalonUpdate: the imports that the signatures need
s = stub_module(open(SRC + "TalonUpdate.roc").read(), "todo: slice 050a")
imports = "import Args\nimport Fail\nimport GitRef\nimport Setup\nimport ToolUpdate\nimport ToolsJson\n"
body = s.split("\n## The pure decisions", 1)[1]
s = imports + "\n## The pure decisions" + body
# `is_target` stays complete: `Run.run!` calls it for each `tool update`, so a stub would break the old tests
s = s.replace('\tis_target = |_args| crash "todo: slice 050a"', '\tis_target = |args| match args.operands {\n\t\t[one] => one == "talon" or one == "roc-talon/talon"\n\t\t_ => Bool.False\n\t}')
open(DST + "TalonUpdate.roc", "w").write(s)

# TalonUpdateFlow: only update!, its doc comment, and a note for the code agent
s = stub_module(open(SRC + "TalonUpdateFlow.roc").read(), "todo: slice 050b")
head = s.split("\n## The command `tln tool update talon", 1)[1]
note = "\n## Part 050b (this module): the prebuilt path (steps 1 to 3 and 5 to 12) and `--from-source` (steps 4 and 4b to 4g: the private `source!` and `built!`, the public `ToolUpdateFlow.consent_for!`, the layout key of `ToolBuild.attempt!`). Part 050a (`TalonUpdate`, `ToolsJson`, `ToolManage`, `ToolManageFlow`) comes first."
s = "import Args\nimport Fx\n\n## The command `tln tool update talon" + head
s = s.replace("TalonUpdateFlow :: [].{", note.strip() + "\nTalonUpdateFlow :: [].{", 1)
open(DST + "TalonUpdateFlow.roc", "w").write(s)

# ToolsJson: before + the Slice 050 block, stubbed, before the closing brace of the module
ref = open(SRC + "ToolsJson.roc").read()
start = ref.index("\t## Slice 050 (CLI 6.5, R-IS6")
end_ = ref.index("\n}\n", start)
block = ref[start:end_ + 1]
block = stub_module("X :: [].{\n" + block + "}\n", "todo: slice 050a").split("\n", 1)[1].rsplit("}", 1)[0]
bef = open(BEF + "ToolsJson.roc").read()
mark = "\t}\n}\n\n# The `tools` object of the fields"
assert mark in bef
bef = bef.replace(mark, "\t}\n\n" + block.rstrip("\n") + "\n}\n\n# The `tools` object of the fields", 1)
open(DST + "ToolsJson.roc", "w").write(bef)

# wiring: complete as in the reference
for name in ["main", "Run"]:
    open(DST + name + ".roc", "w").write(open(SRC + name + ".roc").read())
