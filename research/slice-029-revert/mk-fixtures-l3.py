#!/usr/bin/env python3
# Makes the fixtures of the L3 cases tests/scenarios/cache/cl1-real and cl2-prompt-tty (slice 029). Run from the repo root: python3 -I research/slice-029-revert/mk-fixtures-l3.py
# The L3 runner sets ROC_CACHE_DIR to $HOME/.cache/roc (the cache root), so the build-cache dirs of cl1-real are in the cache root unless a part sets ROC_CACHE_DIR.
import os, shutil

P1 = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"
P2 = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"


def put(root, path, text):
    full = os.path.join(root, "given/home", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)


def store(root, small):
    C = ".cache/roc"
    put(root, C + "/talon/index/releases.json", '{"page":1,"etag":"abc"}\n')
    put(root, C + "/talon/x/0123abcd/tln-app", "binary of an app that tln x built\n")
    put(root, C + "/talon/x/0123abcd/manifest.json", '{"format":1}\n')
    put(root, C + "/packages/%s/main.roc" % P1, "package [Lib] {}\n")
    put(root, C + "/packages/%s.deps.json" % P1, "{}\n")
    put(root, C + "/compat-aaaaaaa/cache.bin", "compat cache of aaaaaaa\n")
    put(root, C + "/toolchains/nightly-2026-10-14-38a3029/roc", "fake roc\n")
    put(root, C + "/toolchains/nightly-2026-10-14-38a3029/.talon.json", '{"format":1,"id":"nightly-2026-10-14-38a3029","compat":"aaaaaaa"}\n')
    put(root, C + "/talon/compat.db", "sqlite\n")
    put(root, C + "/talon/projects.json", '{"format":1,"projects":[]}\n')
    put(root, ".local/share/talon/tools.json", '{"format":1,"tools":[]}\n')
    put(root, ".local/share/talon/bin/mytool", "a tool binary\n")
    put(root, ".local/bin/myapp", "an app that roc install made\n")
    put(root, ".config/talon/config.toml", 'default-roc = "nightly-2026-10-14-38a3029"\n')
    if not small:
        put(root, C + "/packages/%s/deep/x.roc" % P2, "module []\n")
        put(root, C + "/nightly-2025-01-01-abc1234/c.bin", "old nightly cache\n")
        put(root, C + "/debug-9999999/e.bin", "old debug cache\n")
        put(root, C + "/compat-file", "a file, not a dir\n")
        # The second build root, for the part that sets ROC_CACHE_DIR.
        B = ".cache/roc-builds"
        put(root, B + "/compat-bbbbbbb/objects/o1.bin", "objects of bbbbbbb\n")
        put(root, B + "/nightly-2025-02-02-def5678/c.bin", "old nightly cache in the build root\n")
        put(root, B + "/debug-8888888/e.bin", "old debug cache in the build root\n")
        put(root, B + "/other-old/old.bin", "not a build cache dir\n")


for name, small in (("cl1-real", False), ("cl2-prompt-tty", True)):
    root = "tests/scenarios/cache/" + name
    if os.path.isdir(os.path.join(root, "given")):
        shutil.rmtree(os.path.join(root, "given"))
    os.makedirs(os.path.join(root, "given/home"), exist_ok=True)
    store(root, small)
