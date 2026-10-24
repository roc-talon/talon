#!/usr/bin/env python3
# Makes the fixtures of the L2 case tests/commands/cases/gc/gc3-caches (slice 028b). Run from the repo root: python3 research/slice-028b-revert/mk-fixtures.py
# The times are in fx/mtimes (the fake gives them to list_dirs! and tree_info!). C is the clock of the fake (default 1792065600, 2026-10-15T12:00:00Z).
import os, shutil

ROOT = "tests/commands/cases/gc/gc3-caches"
C = 1792065600
DAY = 86400
AGE = 30 * DAY
OLD = 1000000000

PF = "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"
CORE = "https://github.com/acme/core/releases/download/1.0.0/8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r.tar.zst"
TEXT = "https://github.com/acme/text/releases/download/1.0.0/4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN.tar.zst"
OLDDEP = "https://github.com/acme/lex/releases/download/1.0.0/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst"
P1, P2, P3 = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw", "8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r", "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"
P4, P5, P6 = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc", "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq", "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA"
P7, P8, P9 = "8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f", "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL", "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"

mtimes = []


def put(path, text, mtime=None):
    full = os.path.join(ROOT, "given", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)
    if mtime is not None:
        mtimes.append((path.split("/", 1)[1] if False else path, mtime))


def pkg(deps):
    if not deps:
        return "package [Lib] {}\n"
    return "package [Lib] {\n" + "".join('\t%s: "%s",\n' % d for d in deps) + "}\n"


def proj(extra):
    return 'app [main!] {\n\tpf: platform "%s",\n%s}\n\nmain! = |_args| Ok({})\n' % (PF, "".join('\t%s: "%s",\n' % d for d in extra))


def meta(id_, compat, at):
    return '{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":"%s","installed_at":"%s"}\n' % (id_, id_, id_, compat, at)


if os.path.isdir(ROOT):
    shutil.rmtree(ROOT)
os.makedirs(ROOT)
open(os.path.join(ROOT, "entry"), "w").write("commands")

H = "home/.cache/roc"
B = "home/.cache/roc-builds"
# Toolchains of the first home: the default, an old one that nothing pins, a pinned one.
for id_, compat, used in [("nightly-2026-10-14-38a3029", "38a3029", "2026-10-21T00:00:00Z"), ("nightly-2026-08-01-aaaaaaa", "aaaaaaa", "2026-08-02T10:00:00Z"), ("nightly-2026-09-30-bbbbbbb", "bbbbbbb", "2026-08-02T10:00:00Z")]:
    put("%s/toolchains/%s/roc" % (H, id_), "roc\n")
    put("%s/toolchains/%s/.talon.json" % (H, id_), meta(id_, compat, "2026-07-01T00:00:00Z"))
    put("%s/toolchains/%s/.last-use" % (H, id_), used + "\n")
put("home/.config/talon/config.toml", 'default-roc = "nightly-2026-10-14-38a3029"\n')
# Build-cache dirs in ROC_CACHE_DIR (the run sets it to $HOME/.cache/roc-builds).
put(B + "/compat-aaaaaaa/cache.bin", "build cache of a removed compiler\n", C - 100)
put(B + "/compat-bbbbbbb/cache.bin", "old build cache of a kept compiler\n", OLD)
put(B + "/compat-young/cache.bin", "young build cache\n", C - 10 * DAY)
put(B + "/compat-mixed/old.bin", "one old file in a dir\n", OLD)
put(B + "/compat-mixed/deep/new.bin", "one young file deep in the same dir\n", C - 3600)
put(B + "/compat-exact/x.bin", "exactly the age\n", C - AGE)
put(B + "/compat-over/x.bin", "one second more than the age\n", C - AGE - 1)
put(B + "/compat-future/x.bin", "a time in the future\n", C + 5000)
put(B + "/nightly-2025-01-01-abc1234/c.bin", "an old nightly build cache\n", OLD)
put(B + "/nightly-2025-01-01-abc1234/deep/d.bin", "second file of it\n", OLD + 5)
put(B + "/debug-9999999/e.bin", "an old debug build cache\n", OLD)
put(B + "/nightly-2026-10-01-def5678/f.bin", "a young nightly build cache\n", C - 2 * DAY)
put(B + "/other-old/old.bin", "not a build cache dir\n", OLD)
put(B + "/compat-file", "a file, not a dir\n", OLD)
# Packages. P1 is used by pa (live) and names P3. P2 is named by pa and is not in the cache (never fetched). P9 is named only by pold, which is too old.
put(H + "/packages/%s/main.roc" % P1, pkg([("text", TEXT)]), OLD)
put(H + "/packages/%s.deps.json" % P1, "{}\n", OLD)
put(H + "/packages/%s/main.roc" % P3, pkg([]), OLD)
put(H + "/packages/%s/main.roc" % P4, pkg([]), OLD)
put(H + "/packages/%s/deep/x.roc" % P4, "module []\n", OLD)
put(H + "/packages/%s.deps.json" % P4, "{}\n", OLD)
put(H + "/packages/%s/main.roc" % P5, pkg([]), C - 3600)
put(H + "/packages/%s/main.roc" % P6, pkg([]), OLD)
put(H + "/packages/%s/deep/touched.roc" % P6, "module []\n", C - 100)
put(H + "/packages/%s/main.roc" % P7, pkg([]), C - DAY)
put(H + "/packages/%s/main.roc" % P8, pkg([]), C - DAY - 1)
put(H + "/packages/%s/main.roc" % P9, pkg([]), OLD)
put(H + "/packages/h1.0123456789abcdef.tmp", "partial\n", OLD)
# Projects: pa is live and pins bbbbbbb. pold was last used 82 days before TALON_NOW, so it protects nothing.
put("home/.cache/roc/talon/projects.json", '{"format":1,"projects":[{"path":"{w}/project/pa/main.roc","last_use":1792540800},{"path":"{w}/project/pold/main.roc","last_use":1785542400}]}\n')
put("project/pa/main.roc", proj([("core", CORE), ("roc", "nightly-2026-09-30-bbbbbbb")]))
put("project/pold/main.roc", 'app [main!] {\n\tpf: platform "%s",\n}\n\nmain! = |_args| Ok({})\n' % OLDDEP)
# The second home (a dir in home/, so that the runner puts the path of the project in its projects.json): gc-age is 7 days and ROC_CACHE_DIR is not set, so the build-cache dirs are in the cache root. No packages dir, so no walk of the closure and no read of a package, although the live project pa names packages.
put("home/h2/.config/talon/config.toml", 'default-roc = "nightly-2026-10-14-38a3029"\ngc-age = "7d"\n')
put("home/h2/.cache/roc/toolchains/nightly-2026-10-14-38a3029/roc", "roc\n")
put("home/h2/.cache/roc/toolchains/nightly-2026-10-14-38a3029/.talon.json", meta("nightly-2026-10-14-38a3029", "38a3029", "2026-07-01T00:00:00Z"))
put("home/h2/.cache/roc/toolchains/nightly-2026-10-14-38a3029/.last-use", "2026-10-21T00:00:00Z\n")
put("home/h2/.cache/roc/talon/projects.json", '{"format":1,"projects":[{"path":"{w}/project/pa/main.roc","last_use":1792540800}]}\n')
put("home/h2/.cache/roc/compat-ten/x.bin", "ten days old\n", C - 10 * DAY)
put("home/h2/.cache/roc/compat-five/x.bin", "five days old\n", C - 5 * DAY)

os.makedirs(os.path.join(ROOT, "fx"), exist_ok=True)
open(os.path.join(ROOT, "fx", "env"), "w").write("HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
with open(os.path.join(ROOT, "fx", "mtimes"), "w") as f:
    for path, t in mtimes:
        f.write("%s %d\n" % (path.split("/", 3)[-1] if path.startswith("home") else path, t))

with open(os.path.join(ROOT, "fx", "commands"), "w") as f:
    f.write("""# R-GC11, R-GC1, R-GC2, R-GC3, R-GC4, R-GC9, R-EV22 (slice 028b): a dry run. ROC_CACHE_DIR is $HOME/.cache/roc-builds, so the build-cache dirs are not in the cache root. gc-age is 30 days (the default). The clock of the fake is 2026-10-15 (the time of a file), TALON_NOW is 7 days later (the time of a toolchain and of a project).
# Toolchains: aaaaaaa goes (no pin, used in August) and its compat dir goes with it whatever the age of its files (R-GC3 first sentence). The default and bbbbbbb (pa pins it) stay.
# Build-cache dirs: compat-bbbbbbb (a compiler that stays, but no file changed for years: "another dir", R-GC3), nightly-2025-01-01-abc1234 and debug-9999999 (R-GC2), compat-over (1 s more than the age) go.
#   compat-young (10 days), compat-mixed (one old file and one young file deep in it: the newest file decides, nothing inside is removed, R-GC1), compat-exact (exactly the age), compat-future, nightly-2026-10-01-def5678 stay. other-old is no build-cache dir (the name) and compat-file is a file: they are not asked.
# Packages (the real clock, 1 day): P1 (pa uses it) and P3 (P1 names it) stay though old. P2 (pa names it) is not in the cache and is never fetched. P4 (old, nothing uses it, with its .deps.json) goes. P5 (changed 1 hour ago), P6 (one file changed 100 s ago), P7 (exactly 1 day) stay. P8 (1 s more than a day) goes.
#   P9 is named only by pold, which was last used 82 days before TALON_NOW: it protects nothing, so P9 goes (R-GC4: a project used in the GC age).
# The temp h1.0123456789abcdef.tmp is a stale temp (R-GC6). Every removed item has a size (the real size of the fixture files), the total follows.
env:ROC_CACHE_DIR={w}/home/.cache/roc-builds cache gc --dry-run
# R-J3, R-OUT4: the same with --json. The text goes to stderr, stdout has only the envelope with builds, packages, sizes and freed.
env:ROC_CACHE_DIR={w}/home/.cache/roc-builds cache gc --dry-run --json
# R-CC10, R-GC2, R-GC3, R-GC4, R-GC1: the real run. aaaaaaa is renamed to .trash and deleted with compat-aaaaaaa. Then one delete: the stale temp, the build dirs (whole dirs, never a file inside a dir that stays), and for each package its dir and its .deps.json. Then projects.json (pold leaves).
env:ROC_CACHE_DIR={w}/home/.cache/roc-builds cache gc
# The second run removes nothing: the dirs that stay are asked again (tree_info), no delete.
env:ROC_CACHE_DIR={w}/home/.cache/roc-builds cache gc
# R-GC9, R-GC3: the second home. gc-age is 7 days, ROC_CACHE_DIR is not set (the build-cache dirs are in the cache root, which GC lists once more). compat-ten goes (10 days), compat-five stays (5 days). No packages dir: no walk, no read of a package, although pa is live and names packages.
env:HOME={w}/home/h2 cache gc
""")
