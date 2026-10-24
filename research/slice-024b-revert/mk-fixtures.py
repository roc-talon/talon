#!/usr/bin/env python3
"""Writes the given/ and fx/ files of the L2 cases of slice 024b: link/lk1-link, proxy/lk2-run-link, and the runs 10 and 11 that are added to probe/pb1-ladder.
The expected files are not made here: they come from the private reference (research/slice-024b-revert/reference/) and are read by eye (TW21).
Run: python3 -I research/slice-024b-revert/mk-fixtures.py"""
import os
import shutil

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tests", "commands", "cases")


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def meta(id, installed, published=None):
    p = "" if published is None else ',"published_at":"%s"' % published
    return ('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":null,"installed_at":"%s"%s}\n'
            % (id, id, id, installed, p))


def link_meta(id, path, installed="2026-10-21T09:30:00Z"):
    return '{"format":1,"id":"%s","path":"%s","installed_at":"%s"}\n' % (id, path, installed)


def copy_meta(id, source, installed="2026-10-20T08:00:00Z"):
    return '{"format":1,"id":"%s","source":"%s","installed_at":"%s"}\n' % (id, source, installed)


def toolchain(home, id, text=None, roc="fake"):
    d = os.path.join(home, ".cache/roc/toolchains", id)
    if roc is not None:
        put(os.path.join(d, "roc"), roc)
    if text is not None:
        put(os.path.join(d, ".talon.json"), text)


def case(base, name, entry):
    d = os.path.join(ROOT, base, name)
    for sub in ("given", "fx"):
        shutil.rmtree(os.path.join(d, sub), ignore_errors=True)
    put(os.path.join(d, "entry"), entry)
    return d


NIGHTLY = "nightly-2026-10-14-38a3029"

# ---- link/lk1-link: the commands roc link and roc link --copy (R-R12, R-R13, R-LK2, R-LK4, R-CM15, R-FL12, R-CC1, R-CC3, R-J3)
d = case("link", "lk1-link", "commands")
h = os.path.join(d, "given/home")
toolchain(h, NIGHTLY, meta(NIGHTLY, "2026-10-20T12:00:00Z", "2026-10-14T13:00:00Z"))
toolchain(h, "copy-fix-1", copy_meta("copy-fix-1", "{w}/project/roc-src/old/roc"), roc="old copy")
p = os.path.join(d, "given/project")
put(os.path.join(p, "roc-src/zig-out/bin/roc"), "new build\n")
put(os.path.join(p, "roc-src/other/roc"), "other build\n")
put(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put(os.path.join(d, "fx/locks"), "busy toolchains/link-dev6\n")
put(os.path.join(d, "fx/commands"), """# R-R12, R-LK4: a link. The path is made absolute from the current directory. No copy and no link of the file system: the dir has only .talon.json, made in a temp dir and renamed (R-CC1, R-CC4 step 6).
roc link dev roc-src/zig-out/bin/roc
# R-LK2: the name exists: exit 2, nothing is written. For a link there is no --force (R-FL12 names --force for roc link --copy, question Q1).
roc link dev roc-src/zig-out/bin/roc
# R-LK2: copy-fix-1 exists (given): exit 2, and the text names --force
roc link --copy fix-1 roc-src/zig-out/bin/roc
# R-R13, R-LK2: a copy. copy_file! into the temp dir (roc), then .talon.json last, then the rename.
roc link --copy fix-2 roc-src/zig-out/bin/roc
# R-LK2: --force replaces a copy: the old dir goes to the trash name, the new dir takes its place, the trash is deleted. --json: the envelope only on stdout (R-J3).
roc link --copy --force fix-1 roc-src/other/roc --json
# R-FL12 (R-LK2 names --force for --copy only), R-CM15: exit 2 for each of these. No call of the effects.
roc link --force dev3 roc-src/zig-out/bin/roc
roc link dev
roc link a b c
roc link bad/name roc-src/zig-out/bin/roc
# R-R12: the target is missing: exit 2, before any lock
roc link dev4 roc-src/missing
# R-CC1: the copy of a directory fails (the fake copy_file! says Other): the temp dir is deleted, no item, exit 18
roc link --copy dev5 roc-src
# R-CC3, R-CC5: the lock of the item is busy (fx/locks): the line waiting for another tln, then the wait lock. --quiet hides the stdout line (R-FL4).
roc link dev6 roc-src/zig-out/bin/roc --quiet
# R-LY1, R-LK4, R-LK2: roc list reads installed_at of the new .talon.json and shows the kinds
roc ls
""")

# ---- proxy/lk2-run-link: the proxy runs the target of a link (R-LK4, R-R5, R-LK3, R-PX2)
d = case("proxy", "lk2-run-link", "commands")
h = os.path.join(d, "given/home")
toolchain(h, NIGHTLY, meta(NIGHTLY, "2026-10-20T12:00:00Z", "2026-10-14T13:00:00Z"))
toolchain(h, "link-dev", link_meta("link-dev", "{w}/project/roc-src/zig-out/bin/roc"), roc=None)
toolchain(h, "link-moved", link_meta("link-moved", "{w}/project/roc-src/gone/roc"), roc=None)
toolchain(h, "link-bad", '{"format":1,"id":"link-bad","installed_at":"2026-10-21T09:30:00Z"}\n', roc=None)
toolchain(h, "link-new", '{"format":2,"id":"link-new","path":"/x/roc"}\n', roc=None)
toolchain(h, "copy-fix-1", copy_meta("copy-fix-1", "{w}/project/roc-src/zig-out/bin/roc"), roc="copy of a build")
put(os.path.join(h, ".cache/roc/toolchains/link-gone/.last-use"), "2026-10-01T00:00:00Z\n")
put(os.path.join(h, ".config/talon/config.toml"), 'default-roc = "link-dev"\n')
put(os.path.join(d, "given/project/roc-src/zig-out/bin/roc"), "new build\n")
put(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put(os.path.join(d, "fx/exec"), "# the target of link-moved is gone: the child cannot start (R-E1)\ngone/roc\tnotstarted:NotFound\n")
put(os.path.join(d, "fx/commands"), """# R-LK4, R-R5, R-PX2: rank 1. link-dev is a link: its .talon.json is read (one read_files), the program is the target path, not toolchains/link-dev/roc. .last-use is written for link-dev (R-CC9).
@roc +link-dev version
# R-R5: rank 6, the global default is a link. The same program.
@roc version
# R-R5, R-LK3, R-LK2: rank 2, a copy. No read of .talon.json: the copy is toolchains/copy-fix-1/roc, as for a nightly.
@roc version env:ROC_TOOLCHAIN=copy-fix-1
# R-PX7, R-LK4: TALON_PROXY=0 still finds the target (it is the program), and sets only TALON_IN_PROXY. No clock, no .last-use.
@roc +link-dev version env:TALON_PROXY=0
# R-TF1, R-TF6, R-EC19: .talon.json has no path: exit 19, the file is named. No .last-use, no canonical, no exec.
@roc +link-bad version
# R-TF3: a format that this tln does not know: exit 19
@roc +link-new version
# R-LK4, R-EC18: the dir of the link has no .talon.json: exit 18, the text says how to link again
@roc +link-gone version
# R-LK4, R-E1: the target was deleted. The proxy does not look at the file: the start fails (exit 18), the text names the path.
@roc +link-moved version
""")

# ---- probe/pb1-ladder: the runs 10 and 11 (R-R4, R-LK3, R-LK4): a probe runs the target of a link, and a header that has no pin gets no pin for a local build
d = os.path.join(ROOT, "probe", "pb1-ladder")
h = os.path.join(d, "given/home")
toolchain(h, "link-dev", link_meta("link-dev", "{w}/project/roc-src/zig-out/bin/roc"), roc=None)
toolchain(h, "copy-fix-1", copy_meta("copy-fix-1", "{w}/project/roc-src/zig-out/bin/roc"), roc="copy of a build")
put(os.path.join(d, "given/project/roc-src/zig-out/bin/roc"), "new build\n")
for n in ("p10", "p11"):
    for f in ("main.roc", "talon.toml"):
        shutil.copyfile(os.path.join(d, "given/project/p7", f), os.path.join(d, "given/project", n, f)) if os.path.isdir(os.path.join(d, "given/project", n)) else (os.makedirs(os.path.join(d, "given/project", n)), shutil.copyfile(os.path.join(d, "given/project/p7", f), os.path.join(d, "given/project", n, f)))
runs = open(os.path.join(d, "fx/runs")).read()
extra = ["update json file=p10/main.roc toolchain=link-dev compiler=nightly-2026-10-14-38a3029", "update json file=p11/main.roc toolchain=copy-fix-1 compiler=nightly-2026-10-14-38a3029"]
for line in extra:
    if line not in runs:
        runs = runs.rstrip("\n") + "\n" + line + "\n"
put(os.path.join(d, "fx/runs"), runs)
rules = open(os.path.join(d, "rules")).read()
note = ("Slice 024b, R-R4 R-LK3 R-LK4 R-R5: run 10 (p10): no pin, `ROC_TOOLCHAIN` is `link-dev`, a link. `Launch.program!` reads its `.talon.json` (one `read_files`, before the `canonical` of step 0c), the probes run the target path, `.last-use` of `link-dev` is written before each round, "
        "and the header gets no `roc:` entry (R-R4: a local build is never the pin, R-H6 keeps the header as it is). Run 11 (p11): the same for `copy-fix-1`, a copy: no read of `.talon.json`, the program is `toolchains/copy-fix-1/roc`, no `roc:` entry (R-LK3).\n")
if "Slice 024b" not in rules:
    put(os.path.join(d, "rules"), rules.rstrip("\n") + "\n" + note)
