#!/usr/bin/env python3
# Makes the fixtures of the L2 case tests/commands/cases/clean/cn1-clean (slice 029). Run from the repo root: python3 -I research/slice-029-revert/mk-fixtures.py
# The expected files are not made here: they come from the private reference, and they are read by eye (TW21).
import os, shutil

ROOT = "tests/commands/cases/clean/cn1-clean"

PKG1 = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"
PKG2 = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"


def put(path, text):
    full = os.path.join(ROOT, "given", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)


if os.path.isdir(ROOT):
    shutil.rmtree(ROOT)
os.makedirs(ROOT)
open(os.path.join(ROOT, "entry"), "w").write("commands")

# The first home. ROC_CACHE_DIR is $HOME/.cache/roc-builds in the runs of this home, so the build-cache dirs are not in the cache root.
C = "home/.cache/roc"
B = "home/.cache/roc-builds"
# What `clean` removes with no flag (R-GC12): the index and the x builds.
put(C + "/talon/index/releases.json", '{"page":1,"etag":"abc"}\n')
put(C + "/talon/index/nightlies.json", '{"page":2}\n')
put(C + "/talon/x/0123abcd/tln-app", "binary of an app that tln x built\n")
put(C + "/talon/x/0123abcd/manifest.json", '{"format":1}\n')
# What `clean --all` removes besides (R-GC13): packages, and the build-cache dirs.
put(C + "/packages/%s/main.roc" % PKG1, "package [Lib] {}\n")
put(C + "/packages/%s/deep/x.roc" % PKG1, "module []\n")
put(C + "/packages/%s.deps.json" % PKG1, "{}\n")
put(C + "/packages/%s/main.roc" % PKG2, "package [Lib] {}\n")
put(B + "/compat-aaaaaaa/cache.bin", "compat cache of aaaaaaa\n")
put(B + "/compat-bbbbbbb/objects/o1.bin", "objects of bbbbbbb, a compiler that is installed\n")
put(B + "/nightly-2025-01-01-abc1234/c.bin", "old nightly cache\n")
put(B + "/debug-9999999/e.bin", "old debug cache\n")
# What stays always (R-GC12, R-GC13, R-GC14): toolchains, tools, settings, compat.db, projects.json. And in the build root a dir that is no build cache, and a file with a build-cache name.
put(C + "/toolchains/nightly-2026-10-14-38a3029/roc", "fake roc\n")
put(C + "/toolchains/nightly-2026-10-14-38a3029/.talon.json", '{"format":1,"id":"nightly-2026-10-14-38a3029","compat":"bbbbbbb"}\n')
put(C + "/talon/compat.db", "sqlite\n")
put(C + "/talon/projects.json", '{"format":1,"projects":[]}\n')
put(B + "/other-old/old.bin", "not a build cache dir\n")
put(B + "/compat-file", "a file, not a dir\n")
put("home/.local/share/talon/tools.json", '{"format":1,"tools":[]}\n')
put("home/.local/share/talon/bin/mytool", "a tool binary\n")
put("home/.config/talon/config.toml", 'default-roc = "nightly-2026-10-14-38a3029"\n')

# The second home (HOME=$HOME/h2): no ROC_CACHE_DIR, so the build root is the cache root, and its toolchains, talon and packages dirs are no build-cache dirs.
H = "home/h2/.cache/roc"
put(H + "/talon/index/page.json", '{"page":1}\n')
put(H + "/compat-ten/x.bin", "compat cache of ten\n")
put(H + "/compat-file", "a file, not a dir\n")
put(H + "/toolchains/nightly-2026-10-09-258ab27/roc", "fake roc\n")
put(H + "/talon/compat.db", "sqlite\n")

# The third home (HOME=$HOME/h3): the fake refuses to delete the x dir (fx/delete), the index goes.
H3 = "home/h3/.cache/roc"
put(H3 + "/talon/index/page.json", '{"page":1}\n')
put(H3 + "/talon/x/0123abcd/tln-app", "binary of an app that tln x built\n")

# The fourth home (HOME=$HOME/h4): the fake cannot measure the x dir (fx/treeinfo: Denied), so it has no size.
H4 = "home/h4/.cache/roc"
put(H4 + "/talon/index/page.json", '{"page":1}\n')
put(H4 + "/talon/x/0123abcd/tln-app", "binary of an app that tln x built\n")

os.makedirs(os.path.join(ROOT, "fx"))
BD = "env:ROC_CACHE_DIR={w}/home/.cache/roc-builds"
commands = [
    "# R-GC12, R-GC14, R-CM17: a dry run with no flag. It lists the index and the x builds with their sizes (no packages, no build cache), the total, and the last line. Calls: args, env_all, one tree_info of the 2 paths. No list_dirs, no tty, no ask, no delete (nothing is removed, and the prompt is not shown).",
    BD + " cache clean --dry-run",
    "# R-GC13, R-GC14: a dry run with --all. One list_dirs of the build root, then one tree_info. The list: the index, x, the packages dir, then the build-cache dirs in byte order. compat-bbbbbbb (the build cache of the installed compiler) is in it. other-old (no build-cache name) and compat-file (a file) are not asked. Toolchains, tools and compat.db are in no list.",
    BD + " cache clean --all --dry-run",
    "# R-GC14, R-J3, R-OUT4: the same with --json. The text goes to stderr, stdout has only the envelope (dry_run true, removed false, items with bytes, freed).",
    BD + " cache clean --all --dry-run --json",
    "# R-J3, answer of the user (slice 007 D4): --json with --quiet gives the envelope only. Stdout has the envelope (no --all: the index and x), stderr has no line.",
    BD + " cache clean --dry-run --json --quiet",
    "# R-CM17: an operand is a usage failure (exit 2). The only call is args: the check comes before the environment.",
    BD + " cache clean packages",
    "# R-NI7, R-NR2: in a terminal (CI=false, fx/tty) the prompt is asked with the count and the size, the default is Yes. The answer n (fx/answers, line 1): the line nothing was removed, exit 0, no delete. The calls have tty and ask, no delete.",
    BD + " env:CI=false cache clean --all",
    "# R-NI7, R-GC12: the answer Enter (an empty line) is the default Yes. One delete under the lock talon/gc (R-CC10: lock nowait held, delete, unlock; the lock comes after the question: R-CC3 point 5) with the index and the x dir (no --all: the packages and the build caches stay). The tree diff shows only these 2 dirs gone.",
    BD + " env:CI=false cache clean",
    "# R-GC14, R-GC12: the index and x are gone already (NotFound is no item) and no --all: nothing to remove, exit 0. No list_dirs (no --all), no prompt, no delete. The calls end after tree_info.",
    BD + " cache clean",
    "# R-GC14, R-NM6, R-J3, R-NR1, R-GC13: in a terminal (CI=false, fx/tty) but with --json there is no person, so the answer is Yes with no prompt: the answer line on stderr, no tty call, no ask call. One delete under the lock talon/gc with the packages dir and the 4 build-cache dirs. The text goes to stderr, the envelope has the 5 items. Toolchains, tools, settings and compat.db stay.",
    BD + " env:CI=false cache clean --all --json",
    "# R-GC14: nothing is left (packages and the build-cache dirs are gone, no path exists): the line nothing to remove, exit 0, no prompt and no delete. The calls end after tree_info.",
    BD + " cache clean --all",
    "# R-GC14, R-NI7, R-NR2: the fourth home. tree_info cannot measure the x dir (Denied), so it is an item with no size (Q5): the question counts 2 dirs and the size of the index only (the count is the number of items, not of sizes). The answer n (the third answer): nothing is removed, no lock.",
    "env:HOME={w}/home/h4 env:CI=false cache clean",
    "# R-GC14, R-CC3, R-CC5, R-CC10: the third home. A GC holds the lock talon/gc (fx/locks): clean prints the line waiting for another tln on stderr, waits, then deletes under the lock. The fake refuses to delete the x dir (fx/delete): the failure of kind environment, exit 18, no report on stdout, the lock is released. The one delete call had both paths, so the index is gone and x stays.",
    "env:HOME={w}/home/h3 cache clean",
    "# R-GC13, R-NI7, R-NM8, R-CC10: the second home. The build root is the cache root, so its dirs packages, toolchains and talon are no build-cache dir, and compat-file is a file. --yes answers the prompt in a terminal: no tty call, no ask call. The answer line is on stderr and --quiet does not hide it (R-FL4). --quiet hides stdout. Removed: the index and compat-ten.",
    "env:HOME={w}/home/h2 env:CI=false cache clean --all --yes --quiet",
]
open(os.path.join(ROOT, "fx/commands"), "w").write("\n".join(commands) + "\n")
open(os.path.join(ROOT, "fx/env"), "w").write("HOME={w}/home\nCI=true\n")
open(os.path.join(ROOT, "fx/tty"), "w").write("stdin=true\nstderr=true\n")
open(os.path.join(ROOT, "fx/answers"), "w").write("n\n\nn\n")
open(os.path.join(ROOT, "fx/locks"), "w").write("busy h3/.cache/roc/talon/gc\n")
open(os.path.join(ROOT, "fx/treeinfo"), "w").write("denied h4/.cache/roc/talon/x\n")
open(os.path.join(ROOT, "fx/delete"), "w").write("denied h3/.cache/roc/talon/x\n")
