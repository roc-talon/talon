#!/usr/bin/env python3
"""Revert check of slice 018b. Usage: python3 mutate.py <tree> [net]
<tree> is a copy of the repo with research/slice-018b-revert/reference/ laid over it (the reference is the private
shape of the workflows and the script changes). Each mutation changes one file of the tree, runs the check that
must catch it (tests/tools/ciscan.py, or the selftest for `net`), and restores the file. A mutation that no check
catches is printed as NOT CAUGHT."""
import subprocess, sys, os

T = sys.argv[1]
WF = ".github/workflows/"
# (id, file, old, new, check)
M = [
    ("M01 no windows entry", WF + "ci.yml", "          - os: windows-latest\n            steps: check fmt l0\n", "", "fast"),
    ("M02 windows runs all steps", WF + "ci.yml", "steps: check fmt l0", 'steps: ""', "fast"),
    ("M03 macos runs a subset", WF + "ci.yml", "          - os: macos-latest\n            steps: \"\"", "          - os: macos-latest\n            steps: l0", "fast"),
    ("M04 test step without shell bash", WF + "ci.yml", "        run: scripts/test.sh ${{ matrix.steps }}\n        shell: bash\n", "        run: scripts/test.sh ${{ matrix.steps }}\n", "fast"),
    ("M05 OPT in the fast job", WF + "ci.yml", "      GH_TOKEN: ${{ github.token }}\n", "      GH_TOKEN: ${{ github.token }}\n      OPT: speed\n", "fast"),
    ("M06 SLOW inline in the fast job", WF + "ci.yml", "run: scripts/test.sh ${{ matrix.steps }}", "run: SLOW=1 scripts/test.sh ${{ matrix.steps }}", "fast"),
    ("M07 no pull_request", WF + "ci.yml", "  pull_request:\n", "", "fast"),
    ("M08 no bubblewrap step", WF + "ci.yml", "sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0\n        shell: bash\n      - name: Tools (macOS)", "true\n        shell: bash\n      - name: Tools (macOS)", "fast"),
    ("M09 runs-on fixed", WF + "ci.yml", "    runs-on: ${{ matrix.os }}", "    runs-on: ubuntu-latest", "fast"),
    ("M10 test step has fixed args", WF + "ci.yml", "scripts/test.sh ${{ matrix.steps }}", "scripts/test.sh check fmt l0", "fast"),
    ("M11 nightly without SLOW", WF + "nightly.yml", "          SLOW: 1\n", "", "nightly"),
    ("M12 nightly without NET", WF + "nightly.yml", "          NET: 1\n", "", "nightly"),
    ("M13 nightly OPT dev", WF + "nightly.yml", "OPT: speed", "OPT: dev", "nightly"),
    ("M14 nightly without cron", WF + "nightly.yml", "  schedule:\n    - cron: '17 2 * * *'\n", "", "nightly"),
    ("M15 nightly on push", WF + "nightly.yml", "  workflow_dispatch:\n", "  workflow_dispatch:\n  push:\n", "nightly"),
    ("M16 nightly without token", WF + "nightly.yml", "          GITHUB_TOKEN: ${{ github.token }}\n", "", "nightly"),
    ("M17 nightly with package cache", WF + "nightly.yml", "      - name: Install roc", "      - uses: actions/cache@v4\n        with:\n          path: .work/cache/roc\n          key: roc-pkgs-${{ runner.os }}-x\n      - name: Install roc", "nightly"),
    ("M18 nightly without REAL_ROC", WF + "nightly.yml", "          REAL_ROC: 1\n", "", "nightly"),
    ("M19 env.sh without ROC_TAG", "scripts/env.sh", "ROC_TAG=${ROC_TAG:-nightly-2026-10-14-38a3029}\n", "", "pin"),
    ("M20 env.sh ROC ignores the tag", "scripts/env.sh", "nightlies/$ROC_TAG/roc", "nightlies/nightly-2026-10-14-38a3029/roc", "pin"),
    ("M21 env.sh other tag", "scripts/env.sh", "ROC_TAG:-nightly-2026-10-14-38a3029", "ROC_TAG:-nightly-2026-10-15-38e6c42", "pin"),
    ("M22 literal tag in ci.yml", WF + "ci.yml", "      - name: Pinned roc tag\n", "      - name: Pinned roc tag nightly-2026-10-14-38a3029\n", "pin"),
    ("M23 cloudflare path in nightly", WF + "nightly.yml", "        run: scripts/test.sh\n", "        run: scripts/test.sh # cloudflare-workers/.cache\n", "pin"),
    ("M24 binary cache key without tag", WF + "ci.yml", "key: roc-${{ runner.os }}-${{ runner.arch }}-${{ env.ROC_TAG }}", "key: roc-${{ runner.os }}-${{ runner.arch }}", "pin"),
    ("M25 binary cache restore-keys", WF + "ci.yml", "          key: roc-${{ runner.os }}-${{ runner.arch }}-${{ env.ROC_TAG }}\n", "          key: roc-${{ runner.os }}-${{ runner.arch }}-${{ env.ROC_TAG }}\n          restore-keys: roc-\n", "pin"),
    ("M26 package cache key without hash", WF + "ci.yml", "key: roc-pkgs-${{ runner.os }}-${{ steps.urls.outputs.hash }}", "key: roc-pkgs-${{ runner.os }}", "pin"),
    ("M27 cache key without runner.os", WF + "ci.yml", "key: roc-pkgs-${{ runner.os }}-", "key: roc-pkgs-", "pin"),
    ("M28 no get-roc step", WF + "ci.yml", "scripts/get-roc.sh", "echo no", "pin"),
    ("M29 get-roc not writing ROC", WF + "ci.yml", 'echo "ROC=$(scripts/get-roc.sh)" >> "$GITHUB_ENV"', 'scripts/get-roc.sh', "pin"),
    ("M30 get-roc has a literal tag", "scripts/get-roc.sh", "# Install the pinned", "# nightly-2026-10-14-38a3029 Install the pinned", "pin"),
    ("M31 get-roc without Windows", "scripts/get-roc.sh", "windows_x86_64", "windows", "pin"),
    ("M32 get-roc not executable", "scripts/get-roc.sh", None, "chmod-", "pin"),
    ("M33 test.sh with bc", "scripts/test.sh", "awk -v a=\"$(date +%s.%N)\" -v b=\"$RUN_START\" 'BEGIN { print a - b }'", "echo \"$(date +%s.%N) - $RUN_START\" | bc", "portable"),
    ("M34 test.sh bin bash shebang", "scripts/test.sh", "#!/usr/bin/env bash", "#!/bin/bash", "portable"),
    ("M35 run.sh bin bash shebang", "tests/run.sh", "#!/usr/bin/env bash", "#!/bin/bash", "portable"),
    ("M36 brew without findutils", WF + "ci.yml", "coreutils findutils diffutils", "coreutils diffutils", "portable"),
    ("M37 brew without bash", WF + "ci.yml", "brew install bash ", "brew install ", "portable"),
    ("M38 no GITHUB_PATH on macOS", WF + "ci.yml", 'echo "$(brew --prefix coreutils)/libexec/gnubin" >> "$GITHUB_PATH"\n          echo "$(brew --prefix findutils)/libexec/gnubin" >> "$GITHUB_PATH"\n', "", "portable"),
    ("M39 action not pinned", WF + "ci.yml", "actions/checkout@v4", "actions/checkout@main", "yaml"),
    ("M40 no permissions", WF + "nightly.yml", "permissions:\n  contents: read\n", "", "yaml"),
    ("M41 no timeout", WF + "ci.yml", "    timeout-minutes: 30\n", "", "yaml"),
    ("M42 write permission", WF + "ci.yml", "  contents: read", "  contents: write", "yaml"),
    ("M43 yaml tab", WF + "nightly.yml", "    runs-on: ubuntu-latest", "\truns-on: ubuntu-latest", "yaml"),
    ("M44 workflow missing", WF + "nightly.yml", None, "delete", "yaml"),
    ("M45 net skip removed from run.sh", "tests/run.sh", '    case " $tags " in *" net "*) [ "${NET:-0}" = 1 ] || return 2 ;; esac\n', "", "net"),
    ("M46 net skipped even with NET=1", "tests/run.sh", '[ "${NET:-0}" = 1 ] || return 2', "return 2", "net"),
    ("M47 SLOW=1 runs net", "tests/run.sh", '*" net "*) [ "${NET:-0}" = 1 ]', '*" net "*) [ "${NET:-0}${SLOW:-0}" != 00 ]', "net"),
]
only_net = len(sys.argv) > 2 and sys.argv[2] == "net"
bad = 0
for mid, f, old, new, chk in M:
    if (chk == "net") != only_net:
        continue
    p = os.path.join(T, f)
    orig = open(p).read()
    mode = os.stat(p).st_mode
    if old is None and new == "chmod-":
        os.chmod(p, 0o644)
    elif old is None and new == "delete":
        os.remove(p)
    else:
        assert old in orig, mid
        open(p, "w").write(orig.replace(old, new, 1))
    if chk == "net":
        r = subprocess.run([os.path.join(T, "scripts/test.sh"), "selftest"], cwd=T, capture_output=True, text=True)
        caught = "SELFTEST FAIL: net tag" in r.stdout
    else:
        r = subprocess.run(["python3", "-I", os.path.join(T, "tests/tools/ciscan.py"), chk, T], capture_output=True, text=True)
        caught = r.returncode == 1
    if old is None and new == "delete":
        open(p, "w").write(orig)
    else:
        open(p, "w").write(orig)
    os.chmod(p, mode)
    print(("caught     " if caught else "NOT CAUGHT ") + mid)
    bad += not caught
print("not caught: %d" % bad)
