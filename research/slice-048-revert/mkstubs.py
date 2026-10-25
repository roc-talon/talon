#!/usr/bin/env python3
"""Makes the stubs of slice 048 from the private reference (research/slice-048-revert/reference/lib): the doc comments and the signatures stay, each body of a public function is `crash "todo: slice 048"`,
the private helpers after the module block are removed, and the imports that nothing uses are removed. ToolsJson: the file of before the slice (before/) with the stubs of `Tool`, `manifest`, `put` and `drop` added.
Run: Run.roc of before with the new dispatches, but `tool install` stays `ToolFlow.run!` (the code agent changes it to `ToolGitFlow.run!`). ToolBuild and ToolFlow: the files of before (the code agent changes them: the slice file lists the changes).
Run from the repo root."""
import re, os
REF = "research/slice-048-revert/reference/lib"
BEF = "research/slice-048-revert/before/cli/lib"
OUT = "research/slice-048-revert/stubs/lib"
os.makedirs(OUT, exist_ok=True)
MSG = 'crash "todo: slice 048"'


def stub_block(lines):
    """lines: the module block (from after the imports to the closing `}`)."""
    res = []
    i = 0
    while i < len(lines):
        l = lines[i]
        m = re.match(r"^\t([a-z_]+!?) = \|([^|]*)\|", l)
        if m:
            params = m.group(2)
            ps = ", ".join((p.strip() if p.strip().startswith("_") else "_" + p.strip()) for p in params.split(",")) if params.strip() else ""
            res.append(f"\t{m.group(1)} = |{ps}| {MSG}")
            i += 1
            while i < len(lines) and not (lines[i] == "}" or (lines[i] == "" and i + 1 < len(lines) and (lines[i + 1].startswith("\t##") or lines[i + 1] == "}"))):
                i += 1
            continue
        res.append(l)
        i += 1
    return res


def finish(imports, block):
    text = "\n".join(block) + "\n"
    code = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("##"))
    used = [l for l in imports if re.search(r"\b" + l.split()[1] + r"\b", code)]
    return "\n".join(used) + "\n\n" + text


def module_of(path):
    lines = open(path).read().split("\n")
    end = next(i for i, l in enumerate(lines) if l == "}")
    imports = [l for l in lines if l.startswith("import ")]
    start = next(i for i, l in enumerate(lines) if not l.startswith("import ") and l != "")
    return imports, lines[start:end + 1]


for n in ("ToolGit", "ToolManage", "ToolUpdate", "ToolGitFlow", "ToolManageFlow", "ToolUpdateFlow"):
    imports, block = module_of(f"{REF}/{n}.roc")
    open(f"{OUT}/{n}.roc", "w").write(finish(imports, stub_block(block)))

# ToolsJson: before + the new public items.
r_imports, r_block = module_of(f"{REF}/ToolsJson.roc")
b_text = open(f"{BEF}/ToolsJson.roc").read().split("\n")
b_end = next(i for i, l in enumerate(b_text) if l == "}")
first = next(i for i, l in enumerate(r_block) if l.startswith("\t## Slice 048"))
added = stub_block(r_block[first:])  # up to and including the closing `}`
added = added[:-1]  # drop the `}`
merged = b_text[:b_end] + [""] + added + b_text[b_end:]
open(f"{OUT}/ToolsJson.roc", "w").write("\n".join(merged))
print("stubs written")
