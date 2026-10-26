#!/usr/bin/env python3
"""Writes the given files, the fx files, the entry and the rules of the L2 cases of slice 051 (`tln tool remove talon`): rm1-default, rm2-options, rm3-windows, rm4-stops. It also changes the old case tool/tm1-manage (run 5: `tool rm talon` is no failure any more).
It writes no `expect/` file (the runner does, with UPDATE=1, and the agent reads each one: TW21). Usage: python3 research/slice-051-revert/gen-remove.py (from the repo root)."""
import hashlib, json, os, shutil

ROOT = "tests/commands/cases/tool"
TLN = "tln 0.3.1\n"
OLDROC = "the roc that was here before tln setup\n"


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def talon_entry(os_name="linux"):
    target = "x64win" if os_name == "windows" else "x64musl"
    asset = "tln-x64win.exe" if os_name == "windows" else "tln-x64musl"
    return {
        "name": "roc-talon/talon",
        "source": {"kind": "prebuilt", "version": "0.3.1", "url": f"https://github.com/roc-talon/talon/releases/download/v0.3.1/{asset}"},
        "build": {"hashes": [], "nightly": "", "target": target},
        "sha256": sha(TLN),
        "libs": [],
        "installed_at": "2026-09-01T12:00:00Z",
    }


def tool_entry(name):
    return {
        "name": f"acme/{name}",
        "source": {"kind": "release", "version": "1.0.0", "url": f"https://github.com/acme/{name}/releases/download/1.0.0/H.tar.zst"},
        "build": {"hashes": ["H1"], "nightly": "nightly-2026-10-14-38a3029", "target": "x64musl"},
        "sha256": sha(name),
        "libs": [],
        "installed_at": "2026-09-02T08:00:00Z",
    }


BASHRC = '# my bashrc\nexport PATH="$HOME/.local/bin:$PATH" # talon: added by tln setup\nalias ll=\'ls -l\'\n'
ZSHRC = "# my zshrc\nalias la='ls -a'\n"


def meta(id_, compat, extra=""):
    c = "null" if compat is None else f'"{compat}"'
    return f'{{"format":1,"id":"{id_}","url":"http://127.0.0.1:1/dl/{id_}","sha256":"00","sha256_source":"github-digest","typed":"{id_}","compat":{c},"installed_at":"2026-10-20T12:00:00Z","published_at":"2026-10-14T15:00:00Z"{extra}}}\n'


def home(h, *, os_name="linux", tools=("foo", "bar", "baz"), tln_entry=TLN, roc_entry=TLN, roc_old=True, bashrc=True, compilers=True, w_home="{w}/home"):
    """The tree of one home `h` (a dir under given/). The bin dir is `<h>/.local/bin`. On Windows it is `<h>\\.local\\bin`, a dir of the home with a backslash in its name (R-LY8)."""
    exe = ".exe" if os_name == "windows" else ""
    data = f"{h}/.local/share/talon"
    b = f"{h}\\.local\\bin" if os_name == "windows" else f"{h}/.local/bin"
    put(f"{data}/bin/tln{exe}", TLN)
    put(f"{b}/tln{exe}", tln_entry)
    put(f"{b}/roc{exe}", roc_entry)
    if roc_old:
        put(f"{b}/roc.old{exe}", OLDROC)
    tools_obj = {"talon": talon_entry(os_name)}
    for t in tools:
        put(f"{data}/bin/{t}{exe}", f"{t} binary\n")
        # baz is not Talon's: its bin dir entry is another file (R-ST6, R-ST11)
        put(f"{b}/{t}{exe}", f"{t} binary\n" if t != "baz" else "another baz\n")
        tools_obj[t] = tool_entry(t)
    put(f"{data}/tools.json", json.dumps({"format": 1, "tools": tools_obj}, separators=(",", ":")) + "\n")
    put(f"{data}/share.json", '{"format":1,"contributor":"0123456789abcdef0123456789abcdef"}\n')
    put(f"{h}/.config/talon/config.toml", 'default-roc = "nightly-2026-10-14-38a3029"\n')
    cache = f"{h}/.cache/roc"
    if compilers:
        put(f"{cache}/toolchains/nightly-2026-10-14-38a3029/roc", "fake roc\n")
        put(f"{cache}/toolchains/nightly-2026-10-14-38a3029/.talon.json", meta("nightly-2026-10-14-38a3029", "c1"))
        put(f"{cache}/toolchains/nightly-2026-09-01-abcdef0/roc", "fake roc\n")
        put(f"{cache}/toolchains/nightly-2026-09-01-abcdef0/.talon.json", meta("nightly-2026-09-01-abcdef0", "c2"))
        put(f"{cache}/toolchains/git-ab12cd34/roc", "fake roc\n")
        put(f"{cache}/toolchains/git-ab12cd34/.talon.json", meta("git-ab12cd34", None))
        # a link: only .talon.json in the dir, the target is a file of the user that Talon never removes (R-RM2)
        put(f"{cache}/toolchains/link-mine/.talon.json", '{"format":1,"id":"link-mine","kind":"link","path":"' + w_home + '/src/roc/zig-out/bin/roc","installed_at":"2026-10-20T12:00:00Z"}\n')
        put(f"{h}/src/roc/zig-out/bin/roc", "my own roc build\n")
        put(f"{cache}/toolchains/zig-0.17.0/zig", "fake zig\n")
        put(f"{cache}/compat-c1/cache.bin", "build cache of c1\n")
        put(f"{cache}/compat-c2/cache.bin", "build cache of c2\n")
    # what roc owns and Talon never removes (R-RM1): packages, the build cache of a compiler that Talon did not install
    put(f"{cache}/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN/main.roc", "package main\n")
    put(f"{cache}/compat-other/keep.bin", "build cache of another compiler\n")
    put(f"{cache}/talon/compat.db", "db\n")
    put(f"{cache}/talon/projects.json", '{"format":1,"projects":[]}\n')
    put(f"{cache}/talon/index/nightlies.json", "[]\n")
    put(f"{cache}/talon/x/0123abcd/manifest.json", '{"format":1}\n')
    put(f"{cache}/talon/x/0123abcd/xapp", "x app binary\n")
    if bashrc:
        put(f"{h}/.bashrc", BASHRC)
    put(f"{h}/.zshrc", ZSHRC)


def case(name, rules, commands, env, extra=None):
    d = f"{ROOT}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    put(f"{d}/entry", "commands\n")
    put(f"{d}/rules", rules)
    put(f"{d}/fx/commands", "".join(c + "\n" for c in commands))
    put(f"{d}/fx/env", "".join(e + "\n" for e in env))
    return d


# rm1-default: the default (option 1), the dry run, the prompt (cancel, an invalid answer, Enter), and a second run after the removal.
d = case(
    "rm1-default",
    """Slice 051, `tln tool remove talon` (entry `commands`). One home (Linux): Talon 0.3.1 (the entry `talon` of `tools.json`), the tools foo and bar (their bin dir entries are Talon's) and baz (its bin dir entry is another file), 2 nightlies and a git build and a link (`link-mine`, its target is a file of the user) and Zig 0.17.0,
the build caches `compat-c1` and `compat-c2` of the 2 nightlies and `compat-other` (a compiler that Talon did not install), a package, the Talon data (`talon/` in the cache, `config.toml`, `share.json`), `roc.old` (`tln setup` moved a `roc` there). `~/.bashrc` has the line of `tln setup`.
The bin dir entries `tln` and `roc` and the file `tln` of the data bin dir have the same text (Talon's, R-ST11).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool remove talon --dry-run` | the 4 groups with their sizes, nothing is removed (no prompt, no lock, no write): Talon, tools, compilers, Talon data, each `remove` or `keep` of option 1 | R-RM4, R-RM3, R-RM7 to R-RM10 |
| 2 | `tool rm talon --remove-tools --dry-run --json` | the same for option 2 (`--remove-tools`): the verbs change, the text is on stderr and the envelope is on stdout | R-RM4, R-RM3, R-J3, R-OUT4 |
| 3 | `tool remove talon` in a terminal, the answer `4` | the screen of the design, the question on stderr, Cancel: `cancelled: nothing was removed`, exit 0, no lock and no change | R-NI10, R-NR2, R-S5 |
| 4 | `tool remove talon` in a terminal, the answers `x` and then Enter | an answer that is no option is asked again, Enter is option 1: the removal. Order of the calls: the compilers and the Zig (each under its lock, renamed to a trash name, the trash dir and the compat dir deleted), `tools.json` without the entry `talon` (under its lock), the Talon data (one delete), the entry `roc`, `roc.old` back to `roc`, the entry `tln` and the file `tln` (the last path). foo, bar, baz, their entries and the packages stay. The link target stays | R-S5, R-RM1, R-RM2, R-RM3, R-RM5, R-RM6, R-RM7, R-RM9, R-RM10, R-NI10, R-ST11 |
| 5 | `tool remove talon` (CI) | Talon is gone already: no compiler, no entry, no data. Each path is gone, the run does not fail. The answer line of option 1 (no person) | R-RM3, R-NM6, R-ST11 |
""",
    ["tool remove talon --dry-run", "tool rm talon --remove-tools --dry-run --json", "env:CI=false tool remove talon", "env:CI=false tool remove talon", "tool remove talon"],
    ["HOME={w}/home", "CI=true"],
)
home(f"{d}/given/home")
put(f"{d}/fx/tty", "stdin=true\nstderr=true\n")
put(f"{d}/fx/answers", "4\nx\n\n")

# rm2-options: the 3 answer flags, --yes, and the 2 flags together. One home for each run.
d = case(
    "rm2-options",
    """Slice 051, `tln tool remove talon`: the options and the flags (entry `commands`). One home for each run (`HOME={w}/home/h<n>`), all in CI (no prompt).

| Run | Home | Words | Result | Rules |
| --- | --- | --- | --- | --- |
| 1 | h1 | `tool rm talon --remove-tools --json` | option 2: the compilers, the Talon data and the tools go. Each tool whose bin dir entry is Talon's (foo, bar) loses the entry and the file, baz keeps its entry (not Talon's: warning) and loses its file. `tools.json` is deleted (the files first, `tools.json` last in one delete). The 3 profiles are read, the line of `tln setup` is removed from `~/.bashrc` (one write), `~/.zshrc` has no such line (no write). The text is on stderr, the envelope on stdout | R-RM3, R-RM7 to R-RM10, R-ST4, R-ST6, R-ST11, R-NI10, R-J3 |
| 2 | h2 | `tool rm talon --keep-all` | option 3: only Talon goes. The compilers, the Talon data and the tools stay, `tools.json` has no entry `talon`. The path of each compiler that stays is printed (`kept <id>: <path>`: a link prints its target; `link-system` has `roc.old` as its target, which moves back, so its path is the new one: `roc`). The entry `tln` is another file: it stays, with the warning, and the file `tln` of the data bin dir goes. `roc.old` goes back to `roc` | R-RM3, R-RM6, R-RM7, R-ST6, R-ST11, R-NI10 |
| 3 | h3 | `tool rm talon --remove-tools --keep-all` | the 2 flags are a usage failure, exit 2, no call after `args` | R-RM3, R-NI10, R-FL12 |
| 4 | h4 | `tool rm talon --yes` in a terminal | `--yes` is option 1: no `tty` call, no `ask` call, the answer line on stderr. The `roc` entry is another file (the user put it there after `tln setup`): it stays with the warning, and `roc.old` stays where it is | R-RM3, R-NM8, R-NM6, R-ST6, R-RM6 |
| 5 | h5 | `tool rm talon --remove-tools --yes` in a terminal | the answer flag wins over `--yes` (R-NM10): option 2. Only the tools foo and bar are there: the same removal as run 1, no `~/.bashrc` (a missing profile is no failure). No `roc.old` and no compilers | R-RM3, R-NM10, R-RM8 |
""",
    [
        "env:HOME={w}/home/h1 tool rm talon --remove-tools --json",
        "env:HOME={w}/home/h2 tool rm talon --keep-all",
        "env:HOME={w}/home/h3 tool rm talon --remove-tools --keep-all",
        "env:HOME={w}/home/h4 env:CI=false tool rm talon --yes",
        "env:HOME={w}/home/h5 env:CI=false tool rm talon --remove-tools --yes",
    ],
    ["CI=true"],
)
home(f"{d}/given/home/h1", w_home="{w}/home/h1")
home(f"{d}/given/home/h2", tln_entry="not the tln of Talon\n", w_home="{w}/home/h2")
# R-RM6: `tln setup` made the compiler `link-system` for the old roc (R-ST2): its target is `roc.old`, which moves back to `roc`
put(f"{d}/given/home/h2/.cache/roc/toolchains/link-system/.talon.json", '{"format":1,"id":"link-system","kind":"link","path":"{w}/home/h2/.local/bin/roc.old","installed_at":"2026-10-20T12:00:00Z"}\n')
home(f"{d}/given/home/h3", w_home="{w}/home/h3")
home(f"{d}/given/home/h4", roc_entry="a roc that the user put here\n", w_home="{w}/home/h4")
home(f"{d}/given/home/h5", tools=("foo", "bar"), roc_old=False, bashrc=False, compilers=False, w_home="{w}/home/h5")
put(f"{d}/fx/tty", "stdin=true\nstderr=true\n")

# rm3-windows: the renames, the PATH entry, the detached cleanup (R-RM5), and a cleanup that does not start.
d = case(
    "rm3-windows",
    """Slice 051, `tln tool remove talon` on Windows (R-RM5, R-ST10, R-HF11). The fake machine is `os=windows arch=x64`. The bin dir of Windows is `<USERPROFILE>\\.local\\bin`: the dir `u1\\.local\\bin` (a name with `\\`) in the home. The files have `.exe`. One home for each run (`HOME` and `USERPROFILE` are `{w}/home/u<n>` dirs).

| Run | Home | Words | Result | Rules |
| --- | --- | --- | --- | --- |
| 1 | u1 | `tool rm talon --remove-tools` | option 2: the compilers, the tools (files, entries, `tools.json`), the user `Path` (one `exec!` of `powershell` with the script of `Setup.windows_path` `Remove`), the Talon data. Then Talon: one `random!`, each running file is renamed to `<name>.<hex>.del` (`roc.exe`, `tln.exe`, then `<data bin>/tln.exe`), `roc.old.exe` goes back to `roc.exe`, and one detached `cmd.exe /d /c` waits and deletes the 3 `.del` files (`spawn_detached`, the files are in `TALON_DEL_1` to `TALON_DEL_3`). The `.del` files are in the tree: no delete call for them | R-RM5, R-RM6, R-RM8, R-ST10, R-HF11, R-ST4 |
| 2 | u2 | `tool rm talon --keep-all` | the entry `roc.exe` is another file (the user put it there): it stays with the warning, and `roc.old.exe` stays. Only 2 files are renamed (`tln.exe` and the data file), so the cleanup has 2 files. It does not start (`fx/exec`: `notstarted`): the renamed files stay, the warning on stderr names them, exit 0. Option 3: no PATH change (no `exec` call) | R-RM5, R-RM3, R-RM6, R-ST6, R-ST10 |
""",
    ["env:HOME={w}/home/u1 env:USERPROFILE={w}/home/u1 tool rm talon --remove-tools", "env:HOME={w}/home/u2 env:USERPROFILE={w}/home/u2 tool rm talon --keep-all"],
    ["CI=true", "TALON_NOW=2026-10-15T12:00:00Z"],
)
home(f"{d}/given/home/u1", os_name="windows", tools=("foo",), bashrc=False, w_home="{w}/home/u1")
home(f"{d}/given/home/u2", os_name="windows", tools=("foo",), bashrc=False, roc_entry="a roc.exe that the user put here\n", w_home="{w}/home/u2")
put(f"{d}/fx/platform", "os=windows arch=x64\n")
put(f"{d}/fx/exec", "# R-RM5: the detached cleanup of the second home does not start. The needle is the end of the script of 2 files (the first home has 3 files).\n" + "\"%TALON_DEL_2%\" >nul\tnotstarted:no cmd.exe\n")

# rm4-stops: a delete that is refused ends the run, and Talon stays.
d = case(
    "rm4-stops",
    """Slice 051, `tln tool remove talon`: a stop in the middle (entry `commands`). One home (Linux), the same tree as `rm1-default`. `fx/delete` refuses `share.json` (`Denied`).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool rm talon` | option 1 (CI). The compilers and `tools.json` go as in `rm1-default`, then the one `delete!` of the Talon data fails for `share.json` (the other 2 paths are deleted): exit 18 `cannot delete <path>: Denied`. Talon is last: the entries `tln` and `roc`, `roc.old` and the file `tln` of the data bin dir are all still there, so `tln tool remove talon` can run again. No report on stdout | R-RM5, R-RM10, R-ST6 |
""",
    ["tool remove talon"],
    ["HOME={w}/home", "CI=true"],
)
home(f"{d}/given/home")
put(f"{d}/fx/delete", "denied /talon/share.json\n")

# tm1-manage (old case): run 5 was `tool rm talon` (is not built yet). It is a command now. The run is `tool rm talon foo` (2 operands: exit 2).
p = f"{ROOT}/tm1-manage"
shutil.copytree("research/slice-051-revert/before/tests/commands/cases/tool/tm1-manage", p, dirs_exist_ok=True)  # the old state first: the generator can run again
s = open(f"{p}/fx/commands").read()
assert "tool rm talon\n" in s
open(f"{p}/fx/commands", "w").write(s.replace("tool rm talon\n", "tool rm talon foo\n", 1))
s = open(f"{p}/rules").read()
old = "| 5 | `tool rm talon` | `talon` is slices 050 and 051: exit 2 `is not built yet`, no call | R-CM16 |"
assert old in s
open(f"{p}/rules", "w").write(s.replace(old, "| 5 | `tool rm talon foo` | 2 operands: exit 2 `takes one tool, got 2`, no call. (`tool rm talon` is slice 051: `rm1-default`) | R-CM16 |"))
