#!/usr/bin/env python3
# Revert checks (TW12) of slice 125 against the private reference (research/slice-125-revert/reference/). Run from the repo root.
# The reference is the code agent's work in a private copy. This script copies the reference files over the worker stubs, runs the checks of one layer,
# applies one mutation to a copy, runs again, and restores the stub files at the end (also on an error).
#   python3 research/slice-125-revert/mutate.py ref          the reference alone: W0 and W1 (and W2 with W2=1)
#   python3 research/slice-125-revert/mutate.py M1 M2 ...    the named mutants (W0 and W1: fast. M5 needs W2=1: it builds app.wasm)
import os, re, shutil, subprocess, sys

ROOT = os.getcwd()
REF = "research/slice-125-revert/reference/"
FILES = [
    "worker/lib/ArchiveRead.roc", "worker/lib/Reads.roc", "worker/lib/Ingest.roc",
    "worker/ReadRoutes.roc", "worker/IngestRoutes.roc", "worker/sql/closure/deps.sql",
]
ROC = "cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc"
KEEP = "/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/9aeaf22a-88c8-48a0-a914-95b4756582b5/scratchpad/stubs-125/"

# (name, layer, file, old text in the reference, new text, what it models)
MUTANTS = [
    ("M1", "w0", "worker/lib/ArchiveRead.roc",
     "$deps = $deps.append(dep_of(entry.name, entry.value, entry.is_platform)?)",
     "$deps = $deps.append(dep_of(entry.name, entry.value, kind != App)?)",
     "every dep of a package is marked (not only the platform entry)"),
    ("M2", "w0", "worker/lib/ArchiveRead.roc",
     "if $platforms.len() > 1 {",
     "if $platforms.len() > 2 {",
     "the count check is off by one: 2 platform entries pass"),
    ("M3", "w0", "worker/lib/ArchiveRead.roc",
     "\t\t\tif entry.is_platform {\n\t\t\t\t$platforms = $platforms.append(entry.name)\n\t\t\t}\n",
     "\t\t\tif entry.is_platform and kind != App {\n\t\t\t\t$platforms = $platforms.append(entry.name)\n\t\t\t}\n",
     "the count ignores the platform entries of an app (an app with 2 platform entries passes)"),
    ("M4", "w1", "worker/sql/closure/deps.sql",
     "dp.platform AS is_platform",
     "(a.platform IS NOT NULL) AS is_platform",
     "the closure deps statement reads the platform column of the owner artifact, not of the dep row"),
    ("M5", "w2", "worker/IngestRoutes.roc",
     "d.url, if (d.is_platform) 1 else 0),",
     "d.url, 0),",
     "the ingest writes platform 0 for every dep"),
    ("M6", "w0", "worker/lib/Reads.roc",
     "is_platform: dep.is_platform,",
     "is_platform: !dep.is_platform,",
     "dep_of_row inverts the mark"),
]

def sh(cmd, env=None):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, env={**os.environ, **(env or {})})
    return r.returncode, r.stdout + r.stderr

def layer_run(layer):
    # Each layer is run by scripts/test.sh. w0 includes the paused slice 119 tests (ReconcileTest): their failures are known, so the check counts the test names.
    if layer == "w0":
        rc, out = sh(f"{ROC} test worker/tests/unit/w0.roc --no-cache")
        bad = sorted(set(re.findall(r"worker/tests/unit/(?!ReconcileTest)(\w+Test\.roc:\d+)", "\n".join(l for l in out.split("\n") if "✗" in l))))
        comp = re.search(r"(\d+) compiler errors", out)
        return (not bad and not (comp and comp.group(1) != "0")), bad or (["COMPILE ERROR"] if comp and comp.group(1) != "0" else [])
    if layer == "w1":
        rc, out = sh("node sql/tests/run.mjs")
        bad = [l for l in out.split("\n") if l.startswith("FAIL")]
        return rc == 0, bad
    if layer == "w2":
        # The cases of reconcile/ (slice 119, paused) fail on the stubs: they are not counted.
        sh("scripts/test.sh wbuild w2")
        log = open(".work/logs/w2.log").read()
        bad = [l.split(" (")[0] for l in log.split("\n") if l.startswith("FAIL ") and not l.startswith("FAIL reconcile/")]
        return not bad, bad[:6]

def main():
    names = sys.argv[1:] or ["ref"]
    os.makedirs(KEEP, exist_ok=True)
    for f in FILES:
        d = KEEP + f
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy(f, d)
    try:
        for f in FILES:
            shutil.copy(REF + f, f)
        for n in names:
            if n == "ref":
                layers = ["w0", "w1"] + (["w2"] if os.environ.get("W2") else [])
                for l in layers:
                    ok, bad = layer_run(l)
                    print(f"ref {l}: {'PASS' if ok else 'FAIL'} {bad}")
                continue
            m = next(x for x in MUTANTS if x[0] == n)
            _, layer, f, old, new, what = m
            src = open(REF + f).read()
            if src.count(old) != 1:
                print(n, "SKIP", src.count(old)); continue
            open(f, "w").write(src.replace(old, new))
            ok, bad = layer_run(layer)
            print(f"{n} | {layer} | {'NOT CAUGHT' if ok else 'CAUGHT'} | {what} | {bad[:3]}")
            shutil.copy(REF + f, f)
    finally:
        for f in FILES:
            shutil.copy(KEEP + f, f)
        print("stub files restored")

main()
