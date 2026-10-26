#!/usr/bin/env python3
"""Writes the given files and the cmd of the L3 case tools/rm1-remove-talon and tools/rm2-remove-all (slice 051, `tln tool remove talon` with the real Fx). It writes no expect/ file (tests/run.sh with UPDATE=1 does, and the agent reads each one: TW21).
Usage: python3 research/slice-051-revert/gen-l3.py (from the repo root)."""
import hashlib, json, os, shutil

ROOT = "tests/scenarios/tools"
TLN = "#!/bin/sh\necho 'tln 0.3.1'\n"
OLDROC = "#!/bin/sh\necho 'the roc that was here before tln setup'\n"


def put(path, text, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
    if mode:
        os.chmod(path, mode)


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def meta(id_, compat):
    c = "null" if compat is None else f'"{compat}"'
    return f'{{"format":1,"id":"{id_}","url":"http://127.0.0.1:1/dl/{id_}","sha256":"00","sha256_source":"github-digest","typed":"{id_}","compat":{c},"installed_at":"2026-10-20T12:00:00Z","published_at":"2026-10-14T15:00:00Z"}}\n'


def talon_entry():
    return {"name": "roc-talon/talon", "source": {"kind": "prebuilt", "version": "0.3.1", "url": "https://github.com/roc-talon/talon/releases/download/v0.3.1/tln-x64musl"}, "build": {"hashes": [], "nightly": "", "target": "x64musl"}, "sha256": sha(TLN), "libs": [], "installed_at": "2026-09-01T12:00:00Z"}


def tool_entry(name):
    return {"name": f"acme/{name}", "source": {"kind": "release", "version": "1.0.0", "url": f"https://github.com/acme/{name}/releases/download/1.0.0/H.tar.zst"}, "build": {"hashes": ["H1"], "nightly": "nightly-2026-10-14-38a3029", "target": "x64musl"}, "sha256": sha(name), "libs": [], "installed_at": "2026-09-02T08:00:00Z"}


def home(h):
    data = f"{h}/.local/share/talon"
    b = f"{h}/.local/bin"
    put(f"{data}/bin/tln", TLN, 0o755)
    put(f"{b}/tln", TLN, 0o755)  # the cmd makes these hard links of the data file
    put(f"{b}/roc", TLN, 0o755)
    put(f"{b}/roc.old", OLDROC, 0o755)
    tools = {"talon": talon_entry()}
    for t in ("foo", "bar", "baz"):
        put(f"{data}/bin/{t}", f"#!/bin/sh\necho '{t} 1.0.0'\n", 0o755)
        put(f"{b}/{t}", f"#!/bin/sh\necho '{t} 1.0.0'\n" if t != "baz" else "#!/bin/sh\necho 'another baz'\n", 0o755)
        tools[t] = tool_entry(t)
    put(f"{data}/tools.json", json.dumps({"format": 1, "tools": tools}, separators=(",", ":")) + "\n")
    put(f"{data}/share.json", '{"format":1,"contributor":"0123456789abcdef0123456789abcdef"}\n')
    put(f"{h}/.config/talon/config.toml", 'default-roc = "nightly-2026-10-14-38a3029"\n')
    cache = f"{h}/.cache/roc"
    for id_, c in (("nightly-2026-10-14-38a3029", "c1"), ("nightly-2026-09-01-abcdef0", "c2"), ("git-ab12cd34", None)):
        put(f"{cache}/toolchains/{id_}/roc", "fake roc\n", 0o755)
        put(f"{cache}/toolchains/{id_}/.talon.json", meta(id_, c))
    put(f"{cache}/toolchains/zig-0.17.0/zig", "fake zig\n", 0o755)
    put(f"{cache}/compat-c1/cache.bin", "build cache of c1\n")
    put(f"{cache}/compat-c2/cache.bin", "build cache of c2\n")
    put(f"{cache}/compat-other/keep.bin", "build cache of another compiler\n")
    put(f"{cache}/packages/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN/main.roc", "package main\n")
    put(f"{cache}/talon/compat.db", "db\n")
    put(f"{cache}/talon/index/nightlies.json", "[]\n")
    put(f"{cache}/talon/x/0123abcd/xapp", "x app binary\n")
    put(f"{h}/.bashrc", '# my bashrc\nexport PATH="$HOME/.local/bin:$PATH" # talon: added by tln setup\nalias ll=\'ls -l\'\n')
    put(f"{h}/.zshrc", "# my zshrc\nalias la='ls -a'\n")


COMMON = r'''export TALON_NOW=2026-10-15T12:00:00Z
st() { echo "== $*"; if "$@"; then echo "exit 0"; else echo "exit $?"; fi; }
B=$HOME/.local/bin
DB=$XDG_DATA_HOME/talon/bin
C=$XDG_CACHE_HOME/roc
J=$XDG_DATA_HOME/talon/tools.json
linked() { if [ ! -e "$1" ] || [ ! -e "$2" ]; then echo "$1 or $2 is gone"; elif [ "$1" -ef "$2" ]; then echo "$1 and $2 are one file"; else echo "$1 and $2 are two files"; fi; }
state() {
  echo "bin dir:"; ls -A $B
  echo "data bin dir:"; ls -A $DB 2> /dev/null || echo "(gone)"
  echo "compilers:"; ls -A $C/toolchains 2> /dev/null || echo "(gone)"
  echo "cache of roc:"; ls -A $C
  echo "config: $(ls -A $HOME/.config 2> /dev/null | tr '\n' ' ')"
}
# the entries of Talon and of the tools foo and bar are hard links of the files in the data bin dir (R-ST13); baz is another file (R-ST6, R-ST11)
ln -f $DB/tln $B/tln
ln -f $DB/tln $B/roc
ln -f $DB/foo $B/foo
ln -f $DB/bar $B/bar
'''


def case(name, head, body):
    d = f"{ROOT}/{name}"
    shutil.rmtree(f"{d}/given", ignore_errors=True)
    put(f"{d}/cmd", head + COMMON + body)
    home(f"{d}/given/home")


case(
    "rm1-remove-talon",
    """# R-S5 R-RM1 R-RM2 R-RM3 R-RM4 R-RM5 R-RM6 R-RM7 R-RM9 R-RM10 R-NI10 R-ST11 R-ST13 (slice 051): `tln tool remove talon` end to end with the real Fx (the real sha256 of the entries, `rename`, `delete`, `tree_info`, the locks). The home has Talon 0.3.1 (the data file `tln`, the entries `tln` and `roc` as hard links of it, `roc.old` that `tln setup` made),
# the tools foo and bar (entries are hard links of the data files) and baz (its entry is another file), 2 nightlies, a git build and Zig 0.17.0, the build caches of the 2 nightlies and of another compiler, a package, the Talon data and `.bashrc` with the line of `tln setup`.
""",
    r'''
echo "-- 1: --dry-run prints the 4 groups with the sizes and removes nothing (R-RM4). The state after it is the state before it."
st tln tool remove talon --dry-run
state
echo "-- 2: with no terminal the answer is option 1 (R-RM3): Talon, the compilers and the Talon data go, the tools stay. The entries tln and roc and the data file tln are gone, roc.old is roc again (R-RM6, R-RM5)."
echo "-- The packages and the build cache of the compiler that Talon did not install stay (R-RM1). The entry talon is not in tools.json, the other entries are (R-RM7). The profile line stays (R-RM8)."
st tln tool remove talon
state
cat $B/roc
ls $C/packages $C/compat-other
linked $DB/foo $B/foo
linked $DB/bar $B/bar
cat $J
grep -c 'talon: added by tln setup' $HOME/.bashrc || true
$B/foo
$B/baz
''',
)

case(
    "rm2-remove-all",
    """# R-RM3 R-RM8 R-RM9 R-RM10 R-RM5 R-RM6 R-ST4 R-ST6 R-ST11 R-NI10 R-B6 (slice 051): `tln tool remove talon --remove-tools` (option 2) end to end with the real Fx. The home is the home of `tools/rm1-remove-talon`.
# The tools foo and bar go with their entries (hard links of the data files). The entry baz is another file, so it stays with a warning (R-ST6). tools.json goes, the PATH line of `.bashrc` goes (R-ST4), and roc.old is roc again.
""",
    r'''
echo "-- 1: option 2 with a flag. The tools go (the data files and the entries that are Talon's), baz stays with a warning, tools.json is gone, the PATH line is gone from .bashrc, the other lines stay."
st tln tool remove talon --remove-tools
state
cat $B/roc
ls $XDG_DATA_HOME
ls $C/packages $C/compat-other
cat $HOME/.bashrc
cat $B/baz
''',
)
