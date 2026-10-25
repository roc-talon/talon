#!/usr/bin/env python3
"""Makes the stubs of slice 049 from the private reference (research/slice-049-revert/reference/lib): the doc comments and the signatures stay, each body of a public function is `crash "todo: slice 049"`,
the private helpers after the module block are removed, and the imports that nothing uses are removed. New modules: XCache, XCmd, XCacheIo, XTake, XFlow. Run.roc and main.roc: the reference files (the dispatch of `x` and the 5 new exposes).
ToolFlow, ToolBuild and CacheGc: the files of before (the code agent changes them: the slice file lists the changes).
Run from the repo root."""
import re, os
REF = "research/slice-049-revert/reference/lib"
BEF = "research/slice-049-revert/before/cli/lib"
OUT = "research/slice-049-revert/stubs/lib"
os.makedirs(OUT, exist_ok=True)
MSG = 'crash "todo: slice 049"'


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
        m = re.match(r'^\t([a-z_]+) = "', l)
        if m:
            res.append(f'\t{m.group(1)} = "todo: slice 049"')
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


for n in ("XCache", "XCmd", "XCacheIo", "XTake", "XFlow"):
    imports, block = module_of(f"{REF}/{n}.roc")
    open(f"{OUT}/{n}.roc", "w").write(finish(imports, stub_block(block)))

# ToolFlow, ToolBuild, CacheGc: the files of before (the code agent changes them: the slice file lists the changes). Run.roc and main.roc keep the new dispatch and exposes (they are not in before/ by name).
for n in ("ToolFlow", "ToolBuild", "CacheGc"):
    open(f"{OUT}/{n}.roc", "w").write(open(f"{BEF}/{n}.roc").read())
for n in ("Run", "main"):
    open(f"{OUT}/{n}.roc", "w").write(open(f"{REF}/{n}.roc").read())
print("stubs written")
