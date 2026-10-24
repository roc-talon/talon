#!/usr/bin/env python3
"""Revert check of the code of slice 018b (TW12). Small mutations of the workflows and scripts, filtered runs only.

A copy of each changed file is in research/slice-018b-revert/code-after/. Each mutation starts with a restore of all files from the copy
(so a kill is safe), makes one change, runs the checks that should catch it, and restores. At the end the files are compared with the copy.

Usage: python3 -I research/slice-018b-revert/code-mutate.py [id ...]     (from the repo root)
Checks: ciscan:<yaml|fast|nightly|pin|portable> (tests/tools/ciscan.py), selftest (tests/selftest.sh, rows `net tag` and `budget`).
"""
import filecmp, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COPY = os.path.join(ROOT, "research/slice-018b-revert/code-after")
FILES = ["scripts/env.sh", "scripts/test.sh", "scripts/get-roc.sh", "tests/run.sh", "tests/commands/run.sh",
         ".github/workflows/ci.yml", ".github/workflows/nightly.yml", "TESTING.md"]
CI, NI, TS, RS, GR, ENV = ".github/workflows/ci.yml", ".github/workflows/nightly.yml", "scripts/test.sh", "tests/run.sh", "scripts/get-roc.sh", "scripts/env.sh"

# (id, file, [(old, new)], [checks], what the change breaks)
M = [
    ("E1", ENV, [("nightly-2026-10-14-38a3029}", "nightly-2026-10-15-38e6c42}")], ["ciscan:pin"], "the pin is another tag"),
    ("E2", ENV, [("cloudflare-workers/.cache/nightlies/$ROC_TAG/roc", "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")], ["ciscan:pin"], "ROC has the tag text, a second place of the pin"),
    ("G1", GR, [("#!/usr/bin/env bash", "#!/bin/bash")], ["ciscan:pin"], "get-roc.sh has the old shebang"),
    ("G2", GR, [("windows_x86_64", "windows_amd64")], ["ciscan:pin"], "the Windows target name is wrong"),
    ("G3", GR, [('[ "$got" = "$want" ] ||', 'true ||')], [], "no sha256 check (a static row cannot see it: checked by hand)"),
    ("T1", TS, [("""awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'""", """[ "$(echo "$1 > $2" | bc)" = 1 ]""")], ["ciscan:portable"], "bc is back in over()"),
    ("T2", TS, [("exit !(a > b)", "exit !(a < b)")], ["selftest:budget"], "over() is reversed"),
    ("T3", TS, [("#!/usr/bin/env bash", "#!/bin/bash")], ["ciscan:portable"], "test.sh has the old shebang"),
    ("R1", RS, [("""    case " $tags " in *" net "*) [ "${NET:-0}" = 1 ] || return 2 ;; esac\n""", "")], ["selftest:net tag"], "the tag net is not skipped"),
    ("R2", RS, [('"${NET:-0}" = 1', '"${NET:-1}" = 1')], ["selftest:net tag"], "NET is on by default"),
    ("R3", "tests/commands/run.sh", [("#!/usr/bin/env bash", "#!/bin/bash")], ["ciscan:portable"], "commands/run.sh has the old shebang"),
    ("C1", CI, [("            steps: check fmt l0", "            steps: ''")], ["ciscan:fast"], "the Windows job runs all steps"),
    ("C2", CI, [("        shell: bash\n        run: scripts/test.sh", "        run: scripts/test.sh"), ("    defaults:\n      run:\n        shell: bash\n", "")], ["ciscan:fast"], "the test step has the default shell (PowerShell on Windows)"),
    ("C3", CI, [("          sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0\n", "")], ["ciscan:fast"], "no sysctl for bubblewrap"),
    ("C4", CI, [("      - name: Test\n        shell: bash\n", "      - name: Test\n        shell: bash\n        env:\n          OPT: speed\n")], ["ciscan:fast"], "the fast job sets OPT"),
    ("C5", CI, [("key: roc-${{ runner.os }}-${{ runner.arch }}-${{ env.ROC_TAG }}", "key: roc-${{ runner.arch }}-${{ env.ROC_TAG }}")], ["ciscan:pin"], "the binary cache key has no runner.os"),
    ("C6", CI, [("key: roc-${{ runner.os }}-${{ runner.arch }}-${{ env.ROC_TAG }}", "key: roc-${{ runner.os }}-${{ runner.arch }}\n          restore-keys: roc-")], ["ciscan:pin"], "the binary cache restores another tag"),
    ("C7", CI, [("brew install bash coreutils findutils diffutils gnu-sed", "brew install bash coreutils findutils gnu-sed")], ["ciscan:portable"], "the macOS step lacks diffutils"),
    ("C8", CI, [("actions/checkout@v4", "actions/checkout@main")], ["ciscan:yaml"], "an action is not pinned"),
    ("C9", CI, [("        run: echo \"ROC=$(scripts/get-roc.sh)\" >> \"$GITHUB_ENV\"", "        run: echo \"ROC=$PWD/cloudflare-workers/.cache/nightlies/x/roc\" >> \"$GITHUB_ENV\"")], ["ciscan:pin"], "no get-roc step, a local path"),
    ("N1", NI, [("          NET: 1\n", "          NET: 0\n")], ["ciscan:nightly"], "the nightly run has no NET=1"),
    ("N2", NI, [("  workflow_dispatch:\n", "  workflow_dispatch:\n  push:\n")], ["ciscan:nightly"], "the nightly run starts on each push"),
    ("N3", NI, [("  contents: read", "  contents: write")], ["ciscan:yaml"], "write permission"),
    ("N4", NI, [("      - name: Test\n", "      - name: Cache of the packages\n        uses: actions/cache@v4\n        with:\n          path: .work/cache/roc\n          key: roc-pkgs-${{ runner.os }}-x\n\n      - name: Test\n")], ["ciscan:nightly"], "the nightly run caches the packages"),
]


def restore():
    for f in FILES:
        shutil.copy2(os.path.join(COPY, f), os.path.join(ROOT, f))


def run(check):
    kind, arg = check.split(":", 1)
    if kind == "ciscan":
        p = subprocess.run(["python3", "-I", "tests/tools/ciscan.py", arg, "."], cwd=ROOT, capture_output=True, text=True)
        return ("ciscan " + arg) if p.returncode != 0 else None
    env = dict(os.environ, SELFTEST_L2BIN=os.path.join(ROOT, ".work/bin/l2"))
    p = subprocess.run(["tests/selftest.sh"], cwd=ROOT, capture_output=True, text=True, env=env, timeout=300)
    hits = [l for l in p.stdout.splitlines() if l.startswith("SELFTEST FAIL: " + arg)]
    return ("selftest row %s" % arg) if hits else None


def main():
    want = sys.argv[1:]
    restore()
    caught = 0
    total = 0
    for mid, f, edits, checks, what in M:
        if want and mid not in want:
            continue
        total += 1
        restore()
        path = os.path.join(ROOT, f)
        t = open(path, encoding="utf-8").read()
        for old, new in edits:
            assert t.count(old) == 1, "%s: pattern not found once: %r" % (mid, old)
            t = t.replace(old, new)
        open(path, "w", encoding="utf-8").write(t)
        hit = None
        try:
            for c in checks:
                hit = run(c)
                if hit:
                    break
        finally:
            restore()
        caught += 1 if hit else 0
        print("%-3s %-10s %-34s %s" % (mid, "CAUGHT" if hit else "NOT CAUGHT", hit or "-", what), flush=True)
    restore()
    same = all(filecmp.cmp(os.path.join(COPY, f), os.path.join(ROOT, f), shallow=False) and
               os.stat(os.path.join(COPY, f)).st_mode == os.stat(os.path.join(ROOT, f)).st_mode for f in FILES)
    print("caught %d of %d. files equal to the copy: %s" % (caught, total, same))


main()
