#!/usr/bin/env python3
"""Writes the given, fx, entry and rules files of the L2 cases of slice 050c (no expect/ files: `UPDATE=1 tests/commands/run.sh tool/dl` writes them with the reference, and the agent reads each one, TW21).
Cases: tool/dl1-sweep, tool/dl1b-denied, tool/dl2-tool-windows. Also the L3 case tools/dl1-linux-keeps-del and fx/wi1-real-fx-windows (cmd and given). Run from the repo root: python3 research/slice-050c-revert/gen-del.py"""
import os, shutil

CASES = "tests/commands/cases/tool/"
L3 = "tests/scenarios/"


def put(path, text, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)
    if mode:
        os.chmod(path, mode)


def fresh(path):
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(path)


ENV = "HOME={w}/home\nUSERPROFILE={w}/home/u\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n"

# ---------------------------------------------------------------- dl1-sweep
d = CASES + "dl1-sweep/"
fresh(d)
put(d + "entry", "commands\n")
put(d + "fx/platform", "os=windows arch=x64\n")
put(d + "fx/env", ENV)
put(d + "fx/commands", "\n".join([
    "--version env:USERPROFILE={w}/nowhere",
    "--version env:HOME=",
    "--version",
    "tool list",
    "@roc --version",
    "no-such-command",
]) + "\n")
B = d + "given/home/u\\.local\\bin/"  # the bin dir of Windows: the name has `\` (as in ts5-windows)
D = d + "given/home/.local/share/talon/bin/"
for name in ["tln.exe", "roc.exe"]:
    put(B + name, "tln\n")
for name in ["foo.0123456789abcdef.del", "tln.fedcba9876543210.del", "notes.del", "up.0123456789ABCDEF.del", "old.0123456789abcdef.del.tmp"]:
    put(B + name, "stale\n")
put(B + "dirdel.0123456789abcdef.del/keep.txt", "a dir with a .del name stays\n")
for name in ["tln.exe", "foo.exe"]:
    put(D + name, "tln\n")
for name in ["tln.1111111111111111.del", "roc.old.2222222222222222.del"]:
    put(D + name, "stale\n")
put(d + "rules", """Slice 050c, the sweep of `.del` files at each start of `tln` on Windows (R-ST10). The fake machine is `os=windows arch=x64`. The bin dir of Windows is `<USERPROFILE>\\.local\\bin` (R-LY8): in the case it is the dir `home/u\\.local\\bin` (a name with `\\`, in `home/`, so the tree diff shows it). The data bin dir is `home/.local/share/talon/bin`. Start state: the bin dir has `tln.exe`, `roc.exe`, 2 `.del` files (`foo.0123456789abcdef.del`, `tln.fedcba9876543210.del`), 3 names that are no `.del` file (`notes.del`, `up.0123456789ABCDEF.del` with upper case, `old.0123456789abcdef.del.tmp`) and a dir `dirdel.0123456789abcdef.del`. The data bin dir has `tln.exe`, `foo.exe` and 2 `.del` files (`tln.1111111111111111.del`, `roc.old.2222222222222222.del`).

The sweep is the first thing of each run: `env_all`, one `list_dirs` with the dirs (the bin dir, then the data bin dir), one `delete` with the files (in the order of the dirs, byte order in each dir), then the `args` of the command. `windows!` is not in `calls.log`. The sweep prints nothing and never changes the exit code.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `--version` with `USERPROFILE={w}/nowhere` | the bin dir is not there (`list_dirs` gives `NotFound`): no failure. The 2 `.del` files of the data bin dir go. Exit 0 | R-ST10 |
| 2 | `--version` with an empty `HOME` | no data bin dir (the roots need `HOME`): only the bin dir is listed. Its 2 `.del` files go, the 3 other names and the dir stay | R-ST10 |
| 3 | `--version` | both dirs are listed, nothing is left to delete: no `delete` call | R-ST10 |
| 4 | `tool list` | the sweep is first, also for a command (no `.del` file: no `delete` call) | R-ST10 |
| 5 | `@roc --version` | the `roc` proxy is a start of `tln` too (R-ST8): the sweep runs before the proxy | R-ST10, R-ST8 |
| 6 | `no-such-command` | a usage failure (exit 2) is also a start | R-ST10 |
""")

# ---------------------------------------------------------------- dl1b-denied
d = CASES + "dl1b-denied/"
fresh(d)
put(d + "entry", "commands\n")
put(d + "fx/platform", "os=windows arch=x64\n")
put(d + "fx/env", ENV)
put(d + "fx/commands", "--version\n--version\ntool list\n")
put(d + "fx/delete", "denied tln.0123456789abcdef.del\n")
B = d + "given/home/u\\.local\\bin/"
D = d + "given/home/.local/share/talon/bin/"
put(B + "tln.exe", "tln\n")
put(B + "tln.0123456789abcdef.del", "running\n")
put(D + "tln.exe", "tln\n")
put(D + "ok.1111111111111111.del", "stale\n")
put(d + "rules", """Slice 050c, a `.del` file that cannot be deleted (R-ST10: "A delete fails while the file runs, and the next start tries again"). The fake machine is `os=windows arch=x64`. `fx/delete` says `denied tln.0123456789abcdef.del`: the delete of that file gives `Denied`, as Windows does for a running `.exe`. The bin dir has `tln.exe` and the file `tln.0123456789abcdef.del`, the data bin dir has `tln.exe` and `ok.1111111111111111.del`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `--version` | the sweep deletes both files in one `delete` call. `ok.1111111111111111.del` goes, the other stays (`Denied`). No text on stderr, exit 0: a failed delete is no failure | R-ST10 |
| 2 | `--version` | the next start tries again: one `delete` call with the file that stays, again `Denied`, again no text and exit 0 | R-ST10 |
| 3 | `tool list` | the same for a command: the command runs as usual (exit 0) | R-ST10 |
""")

# ---------------------------------------------------------------- dl2-tool-windows
SRC = CASES + "tr1-rebuild/"
d = CASES + "dl2-tool-windows/"
fresh(d)
put(d + "entry", "commands\n")
shutil.copytree(SRC + "fx", d + "fx")
os.remove(d + "fx/env") if os.path.exists(d + "fx/env") else None
put(d + "fx/env", ENV)
put(d + "fx/platform", "os=windows arch=x64\n")
put(d + "fx/commands", "tool rebuild foo\ntool rm foo\n")
put(d + "fx/probes", "# One row for each build, in order (the build probe of run 1).\n0\t../fixtures/check/out/build-pass.stdout\t-\tfile:{out}\n")
shutil.copytree(SRC + "given/home/.cache", d + "given/home/.cache")
tools = open(SRC + "given/home/.local/share/talon/tools.json").read()
import json
doc = json.loads(tools)
doc["tools"] = {"foo": doc["tools"]["foo"]}
doc["tools"]["foo"]["build"]["target"] = "x64win"
put(d + "given/home/.local/share/talon/tools.json", json.dumps(doc, separators=(",", ":")) + "\n")
put(d + "given/home/.local/share/talon/bin/foo.exe", "old foo\n")
put(d + "given/home/u\\.local\\bin/foo.exe", "old foo\n")
put(d + "rules", """Slice 050c, the `.del` renames of an ordinary tool on Windows (R-ST10). The fake machine is `os=windows arch=x64`, so the files of the tool `foo` have `.exe`. The bin dir of Windows is `<USERPROFILE>\\.local\\bin` (R-LY8): in the case it is the dir `home/u\\.local\\bin` (a name with `\\`, in `home/`, so the tree diff shows it). The data bin file `foo.exe` and the entry `foo.exe` of the bin dir are one file (the same text `old foo`, so the entry is Talon's, R-ST11). The rest is the home of `tool/tr1-rebuild` with the tool `foo` only. `fx/random` is not set, so every `random!` gives `0123456789abcdef`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool rebuild foo` | the same calls as `tool/tr1-rebuild` run 1 up to the lock. Under the lock, after the check of the entry and before the copy of the build: one `random!`, then `rename!` of the data file `foo.exe` and of the entry `foo.exe` to `foo.0123456789abcdef.del` (in the data bin dir and in the bin dir, in this order). Then the new file and the entry are made as before. The 2 `.del` files stay (no delete call) | R-ST10, R-S3, R-T7, R-ST9 |
| 2 | `tool rm foo` | the sweep at the start deletes the 2 `.del` files of run 1. Then the removal: under the lock one `random!`, `rename!` of the entry and of the data file to `foo.0123456789abcdef.del` (the entry first), one `delete!` of the 2 new `.del` files, then `tools.json` is written without `foo`. The files are gone | R-ST10, R-B6, R-ST11 |
""")

# ---------------------------------------------------------------- dl3-rename-edges (gap step)
d = CASES + "dl3-rename-edges/"
fresh(d)
put(d + "entry", "commands\n")
shutil.copytree(CASES + "dl2-tool-windows/fx", d + "fx")
put(d + "fx/commands", "tool rebuild bar\ntool rebuild foo\n")
put(d + "fx/probes", "# One row for each build, in order (run 1, run 2).\n0\t../fixtures/check/out/build-pass.stdout\t-\tfile:{out}\n0\t../fixtures/check/out/build-pass.stdout\t-\tfile:{out}\n")
put(d + "fx/rename", "exists .del\n")
shutil.copytree(CASES + "dl2-tool-windows/given/home/.cache", d + "given/home/.cache")
doc = json.loads(open(CASES + "dl2-tool-windows/given/home/.local/share/talon/tools.json").read())
bar = json.loads(json.dumps(doc["tools"]["foo"]))
bar["name"] = "acme/bar"
doc["tools"]["bar"] = bar
put(d + "given/home/.local/share/talon/tools.json", json.dumps(doc, separators=(",", ":")) + "\n")
put(d + "given/home/.local/share/talon/bin/foo.exe", "old foo\n")
put(d + "given/home/u\\.local\\bin/foo.exe", "old foo\n")
put(d + "rules", """Slice 050c gap step, 2 edges of the `.del` renames of a tool on Windows (R-ST10, D8, Q-R1). The home is that of `tool/dl2-tool-windows`, with 2 tools: `foo` has its data file and its entry (`foo.exe`, the same text), `bar` has neither (a manifest entry whose files are gone). `fx/rename` says `exists .del`: a `rename!` whose target ends with `.del` gives `Exists` and moves nothing.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool rebuild bar` | no file exists, so no `.del` rename and no second `random!` (D8: the one `random!` is for the temp dir of the build). The files of `bar` are made. Exit 0 | R-ST10, D8 |
| 2 | `tool rebuild foo` | under the lock the first rename (the data file to `foo.<hex>.del`) gives `Exists`: exit 18 `cannot move <from> to <to>: Exists`. Nothing is renamed, the old `foo.exe` files stay, `tools.json` is not written, the temp dir is deleted | R-ST10, R-CC2, R-CC6, Q-R1 |
""")

# ---------------------------------------------------------------- L3
d = L3 + "tools/dl1-linux-keeps-del/"
fresh(d)
put(d + "cmd", """# R-ST10 (slice 050c): on Linux and macOS there is no `.del` file, and no start of `tln` deletes one. A `.del` file in the bin dir and in the data bin dir is a normal file there: it stays after a command.
# The sweep is for Windows only (`Fx.windows!`, the real `Fx` with no Talon logic). The L2 cases `tool/dl1-sweep` and `tool/dl1b-denied` test the sweep with the fake machine `os=windows`.
export TALON_NOW=2026-10-15T12:00:00Z
st() { echo "== $*"; if "$@"; then echo "exit 0"; else echo "exit $?"; fi; }
B=$HOME/.local/bin
DB=$XDG_DATA_HOME/talon/bin
mkdir -p $B $DB
echo stale > $B/tln.0123456789abcdef.del
echo stale > $DB/foo.fedcba9876543210.del
st tln --version
st tln tool list
echo "bin dir:"; ls -A $B
echo "data bin dir:"; ls -A $DB
""")
put(d + "expect/exit", "0\n")
d = L3 + "fx/wi1-real-fx-windows/"
fresh(d)
put(d + "cmd", """# R-ST10 TW4 (slice 050c): windows! of the real Fx, with `fxprobe` (no Talon logic in it). On this machine (the fast set runs on Linux and macOS) the answer is false. The answer for Windows is tested by the L2 cases with the fake machine `os=windows`.
FX=$(command -v fxprobe)
$FX windows
""")
put(d + "expect/exit", "0\n")
print("ok")
