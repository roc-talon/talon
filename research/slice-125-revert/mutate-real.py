#!/usr/bin/env python3
# TW12 revert check of slice 125 on the REAL code (the code agent's green work), on a BUILD COPY only. The repo is not changed.
#   python3 research/slice-125-revert/mutate-real.py <copy-dir> base M1 M2 ...
# <copy-dir> has worker/, sql/, packages/, scripts/, tests/lib.sh and a link cloudflare-workers (made by rsync from the repo).
# Each mutant changes one file in the copy, runs its layer, and restores the file. W2 builds app.wasm with --opt=speed (scripts/test.sh wbuild w2).
import os, re, subprocess, sys

COPY = os.path.abspath(sys.argv[1])
os.chdir(COPY)
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
# (name, layer, file, old, new, model). Each old text occurs once in the real file.
M = [
 ("M1", "w0", "worker/lib/ArchiveRead.roc", "$deps = $deps.append(dep_of(entry.name, entry.value, entry.is_platform)?)", "$deps = $deps.append(dep_of(entry.name, entry.value, kind != App)?)", "every dep of a package is marked"),
 ("M2", "w0", "worker/lib/ArchiveRead.roc", "if $platforms.len() >= 2 {", "if $platforms.len() >= 3 {", "2 platform entries pass (count off by one)"),
 ("M3", "w0", "worker/lib/ArchiveRead.roc", "\t\t\tif entry.is_platform {\n\t\t\t\t$platforms", "\t\t\tif entry.is_platform and kind != App {\n\t\t\t\t$platforms", "the count ignores the platform entries of an app"),
 ("M4", "w1", "worker/sql/closure/deps.sql", "dp.platform AS is_platform", "(a.platform IS NOT NULL) AS is_platform", "closure deps reads the owner artifact platform column"),
 ("M5", "w2", "worker/IngestRoutes.roc", "d.url, if (d.is_platform) 1 else 0),", "d.url, 0),", "the ingest writes platform 0"),
 ("M6", "w0", "worker/lib/Reads.roc", "is_platform: dep.is_platform,", "is_platform: !dep.is_platform,", "dep_of_row inverts the mark"),
 ("M7", "w2", "worker/ReadRoutes.roc", "d.url AS url, d.platform AS is_platform FROM", "d.url AS url, 0 AS is_platform FROM", "the read route selects 0 for the mark"),
]
def sh(c):
    r = subprocess.run(c, shell=True, capture_output=True, text=True); return r.returncode, r.stdout + r.stderr
def run(layer):
    if layer == "w0":
        rc, out = sh(f"{ROC} test worker/tests/unit/w0.roc --no-cache")
        fails = [l for l in out.split("\n") if "✗" in l]
        bad = sorted({re.search(r"(\w+Test\.roc:\d+)", l).group(1) for l in fails if "ReconcileTest" not in l and re.search(r"(\w+Test\.roc:\d+)", l)})
        comp = re.search(r"(\d+) compiler errors", out)
        if comp and comp.group(1) != "0": bad.append("COMPILE ERROR")
        return bad
    if layer == "w1":
        rc, out = sh("node sql/tests/run.mjs"); return [l.split(" (")[0] for l in out.split("\n") if l.startswith("FAIL")]
    sh("scripts/test.sh wbuild w2")
    log = open(".work/logs/w2.log").read()
    return [l.split(" (")[0] for l in log.split("\n") if l.startswith("FAIL ") and not l.startswith("FAIL reconcile/")]
for n in sys.argv[2:]:
    if n == "base":
        print("base", "w0", run("w0"), "w1", run("w1")); sys.stdout.flush(); continue
    if n == "base2":
        print("base w2", run("w2")); sys.stdout.flush(); continue
    name, layer, f, old, new, what = next(x for x in M if x[0] == n)
    src = open(f).read()
    if src.count(old) != 1: print(n, "SKIP", src.count(old)); continue
    open(f, "w").write(src.replace(old, new))
    try: bad = run(layer)
    finally: open(f, "w").write(src)
    print(f"{n} | {layer} | {'CAUGHT' if bad else 'NOT CAUGHT'} | {what} | {bad[:4]}"); sys.stdout.flush()
