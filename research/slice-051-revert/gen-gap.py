#!/usr/bin/env python3
"""Gap step of slice 051: writes the given files, the fx files, the entry and the rules of the L2 case tool/rm5-win-path (the user Path on Windows: R-RM8, R-ST4, R-HF11, R-EC18). It uses the helpers of gen-remove.py (its head, up to the first case). It writes no expect/ file.
Usage: python3 research/slice-051-revert/gen-gap.py (from the repo root)."""
src = open("research/slice-051-revert/gen-remove.py").read()
exec(src.split("# rm1-default:")[0])

d = case(
    "rm5-win-path",
    """Slice 051 gap step, `tln tool remove talon` on Windows: the user `Path` (R-RM8, R-ST4, R-HF11, R-EC18). The fake machine is `os=windows arch=x64`. One home for each run (`HOME` and `USERPROFILE` are `{w}/home/u<n>` dirs), the same tree as `rm3-windows` (one tool `foo`).

| Run | Home | Words | Result | Rules |
| --- | --- | --- | --- | --- |
| 1 | u3 | `tool rm talon` (CI, option 1) | The tools stay, so the `PATH` entry stays: no `exec` of `powershell` in `calls.log` and no line `removed ... from the user Path`. The compilers and the Talon data go, the files of Talon are renamed and the cleanup is started as in `rm3-windows` | R-RM8, R-ST4, R-RM3 |
| 2 | u4 | `tool rm talon --remove-tools` with a `powershell` that is not on `PATH` (`fx/exec`: `notstarted`) | R-EC18: exit 18, the text names `powershell`. Option 2 stops at the `Path` step: no Talon data delete, no rename of a `.exe`, no `spawn_detached`. Talon is last, so `tln` and `roc` are still there and the command can run again | R-EC18, R-HF11, R-ST4, R-RM5 |
""",
    ["env:HOME={w}/home/u3 env:USERPROFILE={w}/home/u3 tool rm talon", "env:HOME={w}/home/u4 env:USERPROFILE={w}/home/u4 tool rm talon --remove-tools"],
    ["CI=true", "TALON_NOW=2026-10-15T12:00:00Z"],
)
home(f"{d}/given/home/u3", os_name="windows", tools=("foo",), bashrc=False, w_home="{w}/home/u3")
home(f"{d}/given/home/u4", os_name="windows", tools=("foo",), bashrc=False, w_home="{w}/home/u4")
put(f"{d}/fx/platform", "os=windows arch=x64\n")
put(f"{d}/fx/exec", "# R-EC18: powershell is not on PATH. The needle is the program of the first word of the exec of the user Path (the detached cmd.exe of run 1 has no such word).\npowershell\tnotstarted:no powershell\n")
