#!/usr/bin/env python3
"""Gap step of slice 050: writes the given, fx, entry and rules of 2 new L2 cases, `ts5b-winfresh` and `ts7-badentry` (no `expect/`: the runner writes it with UPDATE=1 and the agent reads it, TW21).
It uses the helpers of gen-talon.py (the text up to the first case) and does not write the old cases. Usage: python3 research/slice-050-revert/gen-gap.py (from the repo root)."""
import json, os, shutil

src = open("research/slice-050-revert/gen-talon.py").read()
exec(src.split("# ts1-update: the prebuilt path")[0])

# ts5b-winfresh: Windows, nothing is installed yet (no tools.json, no data file, no entry): no file is replaced, so no `.del` rename (R-ST10: a file is renamed before it is replaced).
name = "ts5b-winfresh"
d = f"{ROOT}/{name}"
shutil.rmtree(d, ignore_errors=True)
put(f"{d}/entry", "commands\n")
put(
    f"{d}/rules",
    """Slice 050 gap step, `tln tool update talon` on Windows with nothing installed (R-ST10). The fake machine is `os=windows arch=x64`. The home has no `tools.json`, no `<data>/bin/tln.exe` and no bin dir entry: no file is replaced, so tln renames nothing to `.del` (a `rename` of a file that is not there would fail).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | the download, the checks, no `chmod`, no `.del` rename, the rename of the temp file to `<data>/bin/tln.exe`, the entries `tln.exe` and `roc.exe` made (hard link to a temp name, rename), `tools.json` is made with the entry `talon`. `updated talon 0.0.0 to 0.3.4 (roc-talon/talon)` | R-ST10, R-ST9, R-S3, R-HF2, Q-M1 |
""",
)
home = f"{d}/given/home"
put(f"{home}/.keep", "")
put(f"{d}/fx/commands", "tool update talon\n")
put(f"{d}/fx/env", "HOME={w}/home\nUSERPROFILE={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n")
put(f"{d}/fx/programs", "curl\nwget\n")
put(f"{d}/fx/platform", "os=windows arch=x64\n")
put(f"{d}/fx/mtimes", "talon/1.meta 1792065600\n")
rels = [release("v0.3.4", "2026-10-01T12:00:00Z", assets=("tln-x64win.exe", "sha256sums.txt"))]
put(f"{d}/fx/http/api.github.com/repos/roc-talon/talon/releases?per_page=100", json.dumps(rels, separators=(",", ":")) + "\n")
put(f"{d}/fx/src/bin-0.3.4", binary("0.3.4"))
put(f"{d}/fx/src/sums-0.3.4", f"{sha(binary('0.3.4'))}  tln-x64win.exe\n")
put(
    f"{d}/fx/jobs",
    jobs_text(
        [
            ("v0.3.4/sha256sums.txt", "0", "-", "-", "copy:{out}={w}/fx/src/sums-0.3.4"),
            ("v0.3.4/tln-x64win.exe", "0", "-", "-", "copy:{out}={w}/fx/src/bin-0.3.4"),
            ("--version", "0", "tln 0.3.4", "-", "-"),
        ]
    ),
)

# ts7-badentry: the entry `talon` is not an object. The commands that read the entry stop with exit 19 and name the file (R-TF6).
name = "ts7-badentry"
d = f"{ROOT}/{name}"
shutil.rmtree(d, ignore_errors=True)
put(f"{d}/entry", "commands\n")
put(
    f"{d}/rules",
    """Slice 050 gap step, a `tools.json` with an entry `talon` that is not an object (`"talon":5`) and the tool `gp` (R-TF6: a Talon file with content that does not parse stops the command with exit 19 and names the file). `tool update talon` and `tool update` read the entry `talon` (`ToolManageFlow.machine!`). `tool list` is not a run of this case: the code skips the key `talon` and lists `gp` with exit 0, and the design does not say if that is right (question Q-B1 of the slice file). No request, no write.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | exit 19 `<path>: tool talon: is not an object`, no request | R-TF6, R-S2 |
| 2 | `tool update` | exit 19, the same line | R-TF6, R-T25 |
""",
)
home = f"{d}/given/home"
put(f"{home}/.local/share/talon/tools.json", tools_json(5, gp=True) + "\n")
put(f"{d}/fx/commands", "tool update talon\ntool update\n")
put(f"{d}/fx/env", "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n")
put(f"{d}/fx/programs", "curl\nwget\n")
print("ok")
