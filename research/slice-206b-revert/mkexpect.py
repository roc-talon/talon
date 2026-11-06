#!/usr/bin/env python3
"""Slice 206b: the expect files of registry/al2-update-query, written by hand from the rules (TW21), not from a run.
Run 1 is the direct path (flag `direct` wins, R-RG1): its calls are the calls of the direct code, which this slice does not change
(`base-run1-calls.log`, `base-run1-tree.diff`: the direct run of the same case before the slice)."""
import os

HERE = os.path.dirname(__file__)
CASE = os.path.join(HERE, "..", "..", "tests", "commands", "cases", "registry", "al2-update-query")

def read(name):
    with open(os.path.join(HERE, name)) as f:
        return f.read()

def write(name, text):
    with open(os.path.join(CASE, "expect", name), "w") as f:
        f.write(text)

PIN = "nightly-2026-10-14-38a3029"
H = {"pf": "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL", "json": "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21", "parser": "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"}

def grp(repo, rng, series):
    return '{"group":"github.com/acme/%s/releases/download/{v}/","range":"%s","series":"%s"}' % (repo, rng, series)

# R-AP16, R-DI1, R-AP74 rows 3 and 5: the free variables of `update` (all, priority order: packages, then the platform), each with its
# series (R-ID2: a group is the URL form and the series) and its one range (the implied range, R-I4); the hashes of the header entries in header order.
BODY = '{"compilers":{"from":"%s","to":"%s"},"groups":[%s],"hashes":["%s","%s","%s"]}' % (
    PIN, PIN,
    ",".join([grp("json", ">=2.0.0, <3.0.0", "2"), grp("parser", ">=1.0.0, <2.0.0", "1"), grp("pfx", ">=0.1.0, <0.2.0", "0.1")]),
    H["pf"], H["json"], H["parser"])

START = """args
env_all
{tty}env_all
clock
cwd
canonical $PROJECT/u1/main.roc
list_dirs $PROJECT/u1
list_dirs $PROJECT
read_files $PROJECT/u1/main.roc
canonical $PROJECT/u1/main.roc
lock $HOME/.cache/roc/talon/projects.json nowait: held
list_dirs $HOME/.cache/roc/talon
read_files $HOME/.cache/roc/talon/projects.json
unlock $HOME/.cache/roc/talon/projects.json
path_roc
read_files $HOME/.cache/roc/talon/path-roc.json
read_files $PROJECT/u1/main.roc $PROJECT/u1/talon.toml $HOME/.config/talon/config.toml
"""

GUARD_READ = "read_files $HOME/.cache/roc/talon/index/github/acme/json/repo.json $HOME/.cache/roc/talon/index/github/acme/parser/repo.json $HOME/.cache/roc/talon/index/github/acme/pfx/repo.json\n"

def post(origin):
    return "http_send POST %s/v1/closure timeout=20\n  User-Agent: tln/0.0.1\n  Content-Type: application/json\n  <body> %s\n" % (origin, BODY)

run1 = read("base-run1-calls.log")
run2 = (START.format(tty="") + GUARD_READ
        + "programs gh\nhttp_get https://api.github.com/repos/acme/parser\n  User-Agent: tln/0.0.1\n"
        + "write_atomic $HOME/.cache/roc/talon/index/github/acme/parser/repo.json\n"
        + post("http://127.0.0.1:9"))
run3 = START.format(tty="tty\n")
run4 = START.format(tty="tty\n")
run5 = (START.format(tty="tty\n") + GUARD_READ + post("http://localhost:9")
        + "read_files $PROJECT/u1/main.roc\nwrite_atomic $PROJECT/u1/main.roc\n")
write("calls.log", run1 + run2 + run3 + run4 + run5)

MOVED_ALL = """note: platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1
check: skipped
$PROJECT/u1/main.roc
  ~ json: acme/json 2.0.0 -> 2.1.0
  ~ parser: acme/parser 1.0.0 -> 1.2.0
  ~ pf: acme/pfx 0.1.0 -> 0.1.1
"""
ENVELOPE = ('{"schema":1,"command":"update","ok":true,"data":{"snapshot":"log:30","probes":0,"downloads":0,"dry_run":true,"check":"skipped","build":"skipped",'
            '"added":[],"moved":[{"alias":"json","from":{"name":"acme/json","version":"2.0.0"},"to":{"name":"acme/json","version":"2.1.0"}}],'
            '"kept":[],"pinned":null,"toml":[],"renamed":[],"notes":[],"written":[]},"error":null}\n')
C = read("../../tests/commands/cases/registry/al2-update-query/fx/commands").splitlines()
stdout = ("== %s\n" % C[0] + MOVED_ALL + "resolved at 2026-10-15T12:00:00Z, 0 probes\ndry run: nothing was written\nexit 0\n"
          + "== %s\n" % C[1] + ENVELOPE + "exit 0\n"
          + "== %s\nexit 2\n" % C[2]
          + "== %s\nexit 2\n" % C[3]
          + "== %s\n" % C[4] + MOVED_ALL + "resolved at log:50, 0 probes\nexit 0\n")
write("stdout", stdout)

FORMS = "Use direct, an https:// URL, or an http:// URL of 127.0.0.1, [::1] or localhost, with no path."
stderr = ("check: skipped\n$PROJECT/u1/main.roc\n  ~ json: acme/json 2.0.0 -> 2.1.0\nresolved at log:30, 0 probes\ndry run: nothing was written\n"
          + "tln: error[usage]: TALON_REGISTRY 'ftp://127.0.0.1:9' is not a registry URL. %s\n" % FORMS
          + "tln: error[usage]: --registry 'http://example.org' is not a registry URL. %s\n" % FORMS)
write("stderr", stderr)
write("exit", "0\n")

repo = """--- home/.cache/roc/talon/index/github/acme/parser/repo.json
+++ home/.cache/roc/talon/index/github/acme/parser/repo.json
@@ -0,0 +1 @@
+{"id":2,"full_name":"acme/parser","private":false,"fork":false}
\\ No newline at end of file
"""
base = read("base-run1-tree.diff")
# LC_ALL=C order: .../acme/parser/1.json, .../acme/parser/repo.json, .../acme/pfx/1.json
cut = base.index("--- home/.cache/roc/talon/index/github/acme/pfx/1.json")
write("tree.diff", base[:cut] + repo + base[cut:] + read("main-hunk.diff"))

# Case 2 (Design Q437, Q438): registry/al2-update-window. No pin, no compiler on PATH, --no-check, --dry-run.
CASE = os.path.join(HERE, "..", "..", "tests", "commands", "cases", "registry", "al2-update-window")
# Q437, R-AP74 row 4: no compiler id, so no `compilers` member.
BODY2 = '{"groups":[%s],"hashes":["%s","%s","%s"]}' % (
    ",".join([grp("json", ">=2.0.0, <3.0.0", "2"), grp("parser", ">=1.0.0, <2.0.0", "1"), grp("pfx", ">=0.1.0, <0.2.0", "0.1")]),
    H["pf"], H["json"], H["parser"])
def start2(first):
    return ("args\nenv_all\ntty\nenv_all\nclock\ncwd\ncanonical $PROJECT/u1/main.roc\nlist_dirs $PROJECT/u1\nlist_dirs $PROJECT\nread_files $PROJECT/u1/main.roc\n"
            "canonical $PROJECT/u1/main.roc\nlock $HOME/.cache/roc/talon/projects.json nowait: held\nlist_dirs $HOME/.cache/roc/talon\n"
            "read_files $HOME/.cache/roc/talon/projects.json\n" + ("write_atomic $HOME/.cache/roc/talon/projects.json\n" if first else "")
            + "unlock $HOME/.cache/roc/talon/projects.json\npath_roc\n"
            "read_files $PROJECT/u1/main.roc $PROJECT/u1/talon.toml $HOME/.config/talon/config.toml\nlist_dirs $HOME/.cache/roc/toolchains\n")
POST2 = "http_send POST http://127.0.0.1:9/v1/closure timeout=20\n  User-Agent: tln/0.0.1\n  Content-Type: application/json\n  <body> %s\n" % BODY2
write("calls.log", start2(True) + GUARD_READ + POST2 + start2(False) + GUARD_READ + POST2)
C2 = read("../../tests/commands/cases/registry/al2-update-window/fx/commands").splitlines()
# Q438, R-DT5: a time snapshot with a registry prints both. 2026-10-01 hides parser 1.2.0 (2026-10-05): parser 1.1.0.
write("stdout", "== %s\n" % C2[0] + MOVED_ALL + "resolved at log:50, 0 probes\ndry run: nothing was written\nexit 0\n"
      + "== %s\n" % C2[1] + MOVED_ALL.replace("1.0.0 -> 1.2.0", "1.0.0 -> 1.1.0") + "resolved at 2026-10-01T00:00:00Z (log:50), 0 probes\ndry run: nothing was written\nexit 0\n")
write("stderr", "")
write("exit", "0\n")
write("tree.diff", '--- home/.cache/roc/talon/projects.json\n+++ home/.cache/roc/talon/projects.json\n@@ -0,0 +1 @@\n+{"format":1,"projects":[{"path":"$PROJECT/u1/main.roc","last_use":1792065600}]}\n')
