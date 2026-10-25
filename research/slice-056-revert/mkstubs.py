#!/usr/bin/env python3
"""Makes the stubs of slice 056 from the private reference (research/slice-056-revert/reference/lib): the doc comments and the signatures stay, each body of a public function is `crash "todo: slice 056"`,
the private helpers after the module block are removed (the type aliases that the signatures use stay), and the imports that nothing uses are removed. New modules: ToolsToml, ToolsPlan, ToolsCmd, ToolsStep, ToolsFlow, ToolsHeld.
Run.roc, main.roc and Args.roc: the reference files (the dispatch of `--tool`, the 6 new exposes, `--tool` in `Args.allows`). Intent.roc: the file of before with the field `tools : List(ToolsToml.Entry)` that has the value `[]` (the table is read by the code agent).
InstallFlow, Resolve, Install, Update, XTake, Gc, CacheGc and XCacheIo: the files of before (the code agent changes them: the slice file lists the changes). Run from the repo root."""
import re, os
REF = "research/slice-056-revert/reference/lib"
BEF = "research/slice-056-revert/before/cli/lib"
OUT = "research/slice-056-revert/stubs/lib"
os.makedirs(OUT, exist_ok=True)
MSG = 'crash "todo: slice 056"'


def stub_block(lines):
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


def finish(imports, block, aliases):
    text = "\n".join(block) + "\n"
    used_aliases = [a for a in aliases if re.search(r"\b" + a.split(" ")[0] + r"\b", text)]
    text += "\n" + "\n\n".join(used_aliases) + ("\n" if used_aliases else "")
    code = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("##"))
    used = [l for l in imports if re.search(r"\b" + l.split()[1].split(".")[-1] + r"\b", code)]
    return "\n".join(used) + "\n\n" + text


def module_of(path):
    lines = open(path).read().split("\n")
    end = next(i for i, l in enumerate(lines) if l == "}")
    imports = [l for l in lines if l.startswith("import ")]
    start = next(i for i, l in enumerate(lines) if not l.startswith("import ") and l != "")
    aliases = [l for l in lines[end + 1:] if re.match(r"^[A-Z][A-Za-z]* : ", l)]
    return imports, lines[start:end + 1], aliases


for n in ("ToolsToml", "ToolsPlan", "ToolsCmd", "ToolsStep", "ToolsFlow", "ToolsHeld"):
    imports, block, aliases = module_of(f"{REF}/{n}.roc")
    open(f"{OUT}/{n}.roc", "w").write(finish(imports, stub_block(block), aliases))

for n in ("InstallFlow", "Resolve", "Install", "Update", "XTake", "Gc", "CacheGc", "XCacheIo"):
    open(f"{OUT}/{n}.roc", "w").write(open(f"{BEF}/{n}.roc").read())
for n in ("Run", "main", "Args"):
    open(f"{OUT}/{n}.roc", "w").write(open(f"{REF}/{n}.roc").read())

# Intent: before, with the field `tools` (value `[]`).
s = open(f"{BEF}/Intent.roc").read()
s = s.replace("import Text\n", "import Text\nimport ToolsToml\n", 1)
s = s.replace("\tpatches : List(PatchEntry),\n", "\tpatches : List(PatchEntry),\n\n\t## Slice 056 (R-PT1, R-PT2): the entries of `[tools]` (`ToolsToml.read_table`), in the order of their lines. An entry is `{ key, ref, url, line }` (`url` is `Err(Unset)` until `tln install` writes it).\n\ttools : List(ToolsToml.Entry),\n", 1)
s = s.replace("\t\t\tpatches: read_patches(doc),\n", "\t\t\tpatches: read_patches(doc),\n\t\t\ttools: [],\n", 1)
assert "tools: []," in s and "tools : List(ToolsToml.Entry)" in s
open(f"{OUT}/Intent.roc", "w").write(s)
print("stubs written")

# The new modules are formatted with `roc fmt` (the checks of `scripts/test.sh fmt` read cli/lib).
import subprocess
ROC = "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
subprocess.run([ROC, "fmt"] + [f"{OUT}/{n}.roc" for n in ("ToolsToml", "ToolsPlan", "ToolsCmd", "ToolsStep", "ToolsFlow", "ToolsHeld")], check=True)
