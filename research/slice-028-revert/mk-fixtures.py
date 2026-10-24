#!/usr/bin/env python3
"""Writes the given/ and fx/ files of the L2 cases of slice 028 (gc/gc1-select, gc/gc2-busy) and the given/ files of the L3 case (cache/gc1-real).
The expected files are not made here: they come from the private reference (research/slice-028-revert/reference/) and are read by eye (TW21).
Run: python3 -I research/slice-028-revert/mk-fixtures.py"""
import calendar
import os
import shutil
import time

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tests")
HEADER = 'app [main!] {{\n\tpf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",{roc}\n}}\n\nmain! = |_args| Ok({{}})\n'


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def epoch(text):
    return calendar.timegm(time.strptime(text, "%Y-%m-%dT%H:%M:%SZ"))


def meta(id, installed, compat=None):
    c = "null" if compat is None else '"%s"' % compat
    return ('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":%s,"installed_at":"%s"}\n'
            % (id, id, id, c, installed))


def toolchain(home, id, text=None, last_use=None):
    d = os.path.join(home, ".cache/roc/toolchains", id)
    put(os.path.join(d, "roc"), "fake")
    if text is not None:
        put(os.path.join(d, ".talon.json"), text)
    if last_use is not None:
        put(os.path.join(d, ".last-use"), last_use + "\n")


def compat(home, id):
    put(os.path.join(home, ".cache/roc", "compat-" + id, "cache.bin"), "build cache")


def project(base, name, pin):
    roc = "" if pin is None else '\n\troc: "%s",' % pin
    put(os.path.join(base, name, "main.roc"), HEADER.format(roc=roc))


def case(d, entry):
    for sub in ("given", "fx"):
        shutil.rmtree(os.path.join(d, sub), ignore_errors=True)
    if entry:
        put(os.path.join(d, "entry"), entry)


# ---- L2 gc1-select. TALON_NOW is 2026-10-22T12:00:00Z (1792670400). fx/clock is not set: the real time of the fake is 1792065600 (2026-10-15T12:00:00Z), 7 days before.
D = os.path.join(ROOT, "commands/cases/gc/gc1-select")
case(D, "commands")
H = os.path.join(D, "given/home")
P = os.path.join(D, "given/project")
put(os.path.join(H, ".config/talon/config.toml"), '# my settings\ndefault-roc = "nightly-2026-October-14-38a3029"   # the default\n')
toolchain(H, "nightly-2026-08-01-aaaaaaa", meta("nightly-2026-08-01-aaaaaaa", "2026-08-01T00:00:00Z", "aaaaaaa"), "2026-08-02T10:00:00Z")
toolchain(H, "nightly-2026-10-02-bbbbbbb", meta("nightly-2026-10-02-bbbbbbb", "2026-08-05T00:00:00Z", "bbbbbbb"), "2026-10-12T00:00:00Z")
toolchain(H, "nightly-2026-10-03-ccccccc", meta("nightly-2026-10-03-ccccccc", "2026-08-06T00:00:00Z", "ccccccc"), "2026-08-11T00:00:00Z")
toolchain(H, "nightly-2026-09-10-ddddddd", meta("nightly-2026-09-10-ddddddd", "2026-09-10T00:00:00Z"), "2026-10-12T00:00:00Z")
toolchain(H, "nightly-2026-10-14-38a3029", meta("nightly-2026-10-14-38a3029", "2026-07-01T00:00:00Z", "38a3029"), "2026-07-01T00:00:00Z")
toolchain(H, "nightly-2026-08-20-fffffff", meta("nightly-2026-08-20-fffffff", "2026-08-20T00:00:00Z"), "2026-10-22T00:00:00Z")
toolchain(H, "git-dd03c09e", '{"format":1,"id":"git-dd03c09e","installed_at":"2026-06-01T00:00:00Z","compat":null}\n')
toolchain(H, "link-dev", '{"format":1,"id":"link-dev","path":"{w}/project/roc-src/zig-out/bin/roc","installed_at":"2026-06-01T00:00:00Z"}\n', "2026-06-02T00:00:00Z")
toolchain(H, "copy-fix-1", None, "2026-06-03T00:00:00Z")
toolchain(H, "nightly-2026-09-01-9999999", meta("nightly-2026-09-01-9999999", "2026-09-01T00:00:00Z"))
toolchain(H, "nightly-2026-10-21-8888888", meta("nightly-2026-10-21-8888888", "2026-10-21T20:00:00Z"))
toolchain(H, "nightly-2026-06-01-7777777")
toolchain(H, "nightly-2026-08-12-5555555", meta("nightly-2026-08-12-5555555", "2026-08-12T00:00:00Z", "5555555"), "2026-08-20T00:00:00Z")
toolchain(H, "nightly-2026-05-01-6666666", meta("nightly-2026-05-01-6666666", "2026-05-01T00:00:00Z", "6666666"), "2026-05-02T00:00:00Z")
for id in ("aaaaaaa", "ccccccc", "6666666", "other", "bbbbbbb", "5555555"):
    compat(H, id)
t = os.path.join(H, ".cache/roc/toolchains")
put(os.path.join(t, "zig-0.17.0/zig"), "fake")
put(os.path.join(t, "nightly-2026-10-11-1a2b3c4.fedcba9876543210.tmp/roc"), "partial")
put(os.path.join(t, "nightly-2026-09-05-4444444.0123456789abcdef.trash/roc"), "left by a crash")
put(os.path.join(t, "nightly-2026-09-06-3333333.1123456789abcdef.trash/roc"), "left by a crash a short time ago")
c = os.path.join(H, ".cache/roc")
put(os.path.join(c, "packages/h1.0123456789abcdef.tmp"), "partial")
put(os.path.join(c, "packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA/main.roc"), "package\n")
put(os.path.join(c, "talon/projects.json.fedcba9876543210.tmp"), "partial")
put(os.path.join(c, "talon/tmp/0123456789abcdef/main.roc"), "a probe copy that a crash left\n")
put(os.path.join(c, "talon/tmp/1123456789abcdef/main.roc"), "a probe copy of a run that is young\n")
put(os.path.join(c, "talon/tmp/2123456789abcdef.locks"), "{w}/home/.cache/roc/toolchains/x\n")
put(os.path.join(c, "talon/tmp/3123456789abcdef.locks"), "{w}/home/.cache/roc/toolchains/y\n")
project(P, "pa", "nightly-2026-October-02-bbbbbbb")
project(P, "pb", "nightly-2026-10-03-ccccccc")
project(P, "pold", "nightly-2026-08-12-5555555")
put(os.path.join(P, "pplain/main.roc"), "just some text, no header\n")
put(os.path.join(P, "roc-src/zig-out/bin/roc"), "fake")
entries = [("pa", "2026-10-21T00:00:00Z"), ("pb", "2026-10-18T00:00:00Z"), ("pgone", "2026-10-20T00:00:00Z"), ("pold", "2026-08-01T00:00:00Z"), ("pplain", "2026-10-20T00:00:00Z")]
put(os.path.join(c, "talon/projects.json"), '{"format":1,"projects":[%s]}\n' % ",".join('{"path":"{w}/project/%s/main.roc","last_use":%d}' % (n, epoch(d)) for n, d in entries))
# home2: a projects.json that does not parse. home3: a gc-age that is not a number of days.
H2 = os.path.join(D, "given/home2")
toolchain(H2, "nightly-2026-08-01-aaaaaaa", meta("nightly-2026-08-01-aaaaaaa", "2026-08-01T00:00:00Z", "aaaaaaa"), "2026-08-02T10:00:00Z")
put(os.path.join(H2, ".cache/roc/talon/projects.json"), '{"format":1,"projects":[{"path":\n')
H3 = os.path.join(D, "given/home3")
toolchain(H3, "nightly-2026-08-01-aaaaaaa", meta("nightly-2026-08-01-aaaaaaa", "2026-08-01T00:00:00Z", "aaaaaaa"), "2026-08-02T10:00:00Z")
put(os.path.join(H3, ".config/talon/config.toml"), '# the age\ngc-age = "30"\n')
# home4: gc-age is 0 days. Only the last day (R-CC10) keeps a compiler that nothing pins, and the default.
H4 = os.path.join(D, "given/home4")
put(os.path.join(H4, ".config/talon/config.toml"), 'gc-age = "0d"\ndefault-roc = "nightly-2026-10-14-38a3029"\n')
toolchain(H4, "nightly-2026-08-20-fffffff", meta("nightly-2026-08-20-fffffff", "2026-08-20T00:00:00Z"), "2026-10-22T00:00:00Z")
toolchain(H4, "nightly-2026-09-11-eeeeeee", meta("nightly-2026-09-11-eeeeeee", "2026-09-11T00:00:00Z"), "2026-10-19T00:00:00Z")
toolchain(H4, "nightly-2026-10-14-38a3029", meta("nightly-2026-10-14-38a3029", "2026-07-01T00:00:00Z"), "2026-07-01T00:00:00Z")
put(os.path.join(D, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put(os.path.join(D, "fx/locks"), "busy toolchains/nightly-2026-05-01-6666666\n")
clock = 1792065600
young = clock - 7200
old = 1000000000
mt = [
    ("toolchains/nightly-2026-10-11-1a2b3c4.fedcba9876543210.tmp", old),
    ("toolchains/nightly-2026-09-05-4444444.0123456789abcdef.trash", old),
    ("toolchains/nightly-2026-09-06-3333333.1123456789abcdef.trash", young),
    ("packages/h1.0123456789abcdef.tmp", old),
    ("talon/projects.json.fedcba9876543210.tmp", old),
    ("talon/tmp/0123456789abcdef", old),
    ("talon/tmp/1123456789abcdef", young),
    ("talon/tmp/2123456789abcdef.locks", old),
    ("talon/tmp/3123456789abcdef.locks", young),
]
put(os.path.join(D, "fx/mtimes"), "".join("%s %d\n" % row for row in mt))
put(os.path.join(D, "fx/commands"), """# R-CM17, R-GC11, R-GC5, R-GC6, R-GC3, R-GC9, R-EV22, D17: a dry run. Nothing is removed and no lock is taken. TALON_NOW (2026-10-22) is the time for the toolchains and the projects, the clock of the fake (2026-10-15) is the time for the temps.
# The default age is 30 days. Toolchains that go: git-dd03c09e (no pin, installed 2026-06-01), 6666666 (old, a lock holds it in the next runs), aaaaaaa (old, no pin), 5555555 (last use 2026-08-20, only an old project pins it, so it pins nothing), 9999999 (no .last-use: installed_at, old).
# Toolchains that stay: bbbbbbb (pinned), ccccccc (pinned by pb, last use 2026-08-11: a pin keeps at any age), ddddddd (no pin, used 10 days ago: used in the age), the default (config.toml has the other tag form), fffffff and 8888888 (used in the last day), 7777777 (no time), link-dev and copy-fix-1 (made by hand), zig-0.17.0 (no compiler).
cache gc --dry-run
# R-J3: the same with --json. The text goes to stderr, stdout has only the envelope.
cache gc --dry-run --json
# R-CC10, R-CC2, R-PD13: the real run. The GC lock, then for each toolchain its own lock (6666666 is busy: skipped), the rename to .trash, the delete with the compat dir. Then the stale temps (one delete), then projects.json (pold, pgone, pplain leave).
cache gc
# R-GC6: the second run removes nothing, and 6666666 is skipped again.
cache gc
# R-CM15: no operand.
cache gc nightly-2026-08-01-aaaaaaa
# R-TF6: a projects.json that does not parse. Exit 19. The pins are not known, so nothing is removed.
env:HOME={w}/home2 cache gc
# R-TF4: a gc-age that is not a number of days. Exit 19.
env:HOME={w}/home3 cache gc
# R-GC9, R-CC10, D17: gc-age is 0 days. A compiler that nothing pins and that was used 3 days ago goes (eeeeeee). The one used 12 hours ago stays: the last day is the floor (fffffff). The default stays.
env:HOME={w}/home4 cache gc --dry-run
""")

# ---- L2 gc2-busy
D = os.path.join(ROOT, "commands/cases/gc/gc2-busy")
case(D, "commands")
H = os.path.join(D, "given/home")
put(os.path.join(H, ".config/talon/config.toml"), 'default-roc = "nightly-2026-10-14-38a3029"\n')
toolchain(H, "nightly-2026-08-01-aaaaaaa", meta("nightly-2026-08-01-aaaaaaa", "2026-08-01T00:00:00Z", "aaaaaaa"), "2026-08-02T10:00:00Z")
toolchain(H, "nightly-2026-10-14-38a3029", meta("nightly-2026-10-14-38a3029", "2026-07-01T00:00:00Z", "38a3029"), "2026-07-01T00:00:00Z")
compat(H, "aaaaaaa")
put(os.path.join(D, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put(os.path.join(D, "fx/locks"), "busy talon/gc\n")
put(os.path.join(D, "fx/commands"), """# R-CC10: another tln cache gc holds the lock of the item talon/gc. The line, exit 0, nothing else (no read, no list, no delete).
cache gc
# R-CC10, R-J3: the same with --json. The envelope has ran false and empty lists.
cache gc --json
# R-GC11 (Q4): a dry run takes no lock, so it prints what it would remove while the other GC runs.
cache gc --dry-run
# R-CM15: the operand is refused before any lock.
cache gc nightly
""")

# ---- L3 cache/gc1-real. The cmd file is written by hand. The given/ files: the store, the config, the project files. The temps, the trash dirs, the locks and the times of `touch` are made by the cmd.
D = os.path.join(ROOT, "scenarios/cache/gc1-real")
for sub in ("given",):
    shutil.rmtree(os.path.join(D, sub), ignore_errors=True)
H = os.path.join(D, "given/home")
P = os.path.join(D, "given/project")
put(os.path.join(H, ".config/talon/config.toml"), '# my settings\ngc-age = "7d"   # shorter than the default\ndefault-roc = "nightly-2026-October-14-38a3029"\n')
toolchain(H, "nightly-2026-08-01-aaaaaaa", meta("nightly-2026-08-01-aaaaaaa", "2026-08-01T00:00:00Z", "aaaaaaa"), "2026-08-02T10:00:00Z")
toolchain(H, "nightly-2026-10-02-bbbbbbb", meta("nightly-2026-10-02-bbbbbbb", "2026-08-05T00:00:00Z", "bbbbbbb"), "2026-10-12T00:00:00Z")
toolchain(H, "nightly-2026-10-03-ccccccc", meta("nightly-2026-10-03-ccccccc", "2026-08-06T00:00:00Z", "ccccccc"), "2026-10-19T00:00:00Z")
toolchain(H, "nightly-2026-09-10-ddddddd", meta("nightly-2026-09-10-ddddddd", "2026-09-10T00:00:00Z", "ddddddd"), "2026-10-12T00:00:00Z")
toolchain(H, "nightly-2026-09-11-eeeeeee", meta("nightly-2026-09-11-eeeeeee", "2026-09-11T00:00:00Z", "eeeeeee"), "2026-10-19T00:00:00Z")
toolchain(H, "nightly-2026-10-14-38a3029", meta("nightly-2026-10-14-38a3029", "2026-07-01T00:00:00Z", "38a3029"), "2026-07-01T00:00:00Z")
toolchain(H, "nightly-2026-05-01-6666666", meta("nightly-2026-05-01-6666666", "2026-05-01T00:00:00Z", "6666666"), "2026-05-02T10:00:00Z")
toolchain(H, "link-dev", '{"format":1,"id":"link-dev","path":"ROC_SRC","installed_at":"2026-06-01T00:00:00Z"}\n', "2026-06-02T00:00:00Z")
for id in ("aaaaaaa", "bbbbbbb", "ccccccc", "ddddddd", "eeeeeee", "6666666", "other"):
    compat(H, id)
put(os.path.join(H, ".cache/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA/main.roc"), "package\n")
put(os.path.join(H, ".cache/roc/compat-other/deep/entry.bin"), "build cache\n")
put(os.path.join(H, ".local/bin/myapp"), "an app that roc install made\n")
project(P, "pa", "nightly-2026-October-02-bbbbbbb")
project(P, "pb", "nightly-2026-10-03-ccccccc")
project(P, "pold", "nightly-2026-08-12-5555555")
put(os.path.join(P, "roc-src/roc"), "fake")
print("written")
