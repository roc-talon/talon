#!/usr/bin/env python3
"""Revert check of slice 018 (TW12): small mutations of the test harness.
Usage: research/slice-018-revert/code-mutate.py
Keeps a copy of the 5 changed files in code-before/. Before each mutation, and at the end, the copy is written back
(so a killed run leaves the files right after the next start). Each mutation runs tests/selftest.sh (the 7 new rows).
Writes code-results.md."""
import os, shutil, subprocess, sys, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.join(ROOT, 'research', 'slice-018-revert')
COPY = os.path.join(HERE, 'code-before')
FILES = ['scripts/env.sh', 'scripts/test.sh', 'tests/lib.sh', 'tests/run.sh', 'tests/commands/run.sh']

def save():
    if os.path.isdir(COPY):
        return  # an earlier (maybe killed) run: the copy is the truth
    for f in FILES:
        os.makedirs(os.path.dirname(os.path.join(COPY, f)), exist_ok=True)
        shutil.copy(os.path.join(ROOT, f), os.path.join(COPY, f))

def restore():
    for f in FILES:
        shutil.copy(os.path.join(COPY, f), os.path.join(ROOT, f))

# (id, rule, file, old, new, what)
M = [
 ('M1', 'TW25', 'scripts/env.sh', 'WORK=${WORK:-$ROOT/.work}', 'WORK=$ROOT/.work', 'env.sh sets WORK always'),
 ('M2', 'TW25', 'tests/lib.sh', 'exit 2 ;;', 'exit 1 ;;', 'bad OPT exits 1, not 2'),
 ('M3', 'TW25', 'tests/lib.sh', 'OPT=${OPT:-dev}', 'OPT=${OPT:-speed}', 'default OPT is speed'),
 ('M4', 'TW25', 'scripts/test.sh', '"$ROC" build "$2" --opt="$OPT" --output=', '"$ROC" build "$2" --output=', 'test.sh builds with no --opt'),
 ('M5', 'TW25', 'scripts/test.sh', '\ncheck_opt\n', '\n', 'test.sh does not check OPT'),
 ('M6', 'TW25', 'tests/run.sh', '--opt="$OPT" --output="$BIN/flowprobe"', '--output="$BIN/flowprobe"', 'run.sh flowprobe build has no --opt'),
 ('M7', 'TW25', 'tests/run.sh', '\ncheck_opt\n', '\n', 'run.sh does not check OPT'),
 ('M8', 'TW25', 'tests/commands/run.sh', '--opt="$OPT" --output="$BIN"', '--output="$BIN"', 'commands/run.sh build has no --opt'),
 ('M9', 'TW25', 'tests/commands/run.sh', '\ncheck_opt\n', '\n', 'commands/run.sh does not check OPT'),
 ('M10', 'TW27', 'tests/run.sh', '[ "${SLOW:-0}" = 1 ] || return 2', 'return 2', 'SLOW=1 is ignored'),
 ('M11', 'TW27', 'tests/run.sh', 'for t in windows exdev; do', 'for t in windows; do', 'exdev tag no longer skipped'),
 ('M12', 'TW20', 'scripts/test.sh', 'xargs -0 -P "$(parallel_jobs)" -I{} bash -c \'\n        n=${1//', 'xargs -0 -P 1 -I{} bash -c \'\n        n=${1//', 'l0 runs one file at a time'),
 ('M13', 'TW20', 'scripts/test.sh', 'xargs -0 -P "$(parallel_jobs)" -I{} bash -c \'\n        n=${1//', 'xargs -0 -P 64 -I{} bash -c \'\n        n=${1//', 'l0 ignores JOBS'),
 ('M14', 'TW20', 'scripts/test.sh', '            echo "$f: FAILED"; cat "$dir/$n.log"; rc=1', '            echo "$f: FAILED"; cat "$dir/$n.log"', 'a failed l0 file does not fail the step'),
 ('M15', 'TW20', 'scripts/test.sh', '    for f in "${UNIT[@]}"; do\n        n=$(l0_name', '    for f in $(printf "%s\\n" "${UNIT[@]}" | sort -r); do\n        n=$(l0_name', 'l0 log in reverse order'),
 ('M16', 'TW26', 'scripts/test.sh', '"${TIME[$s]}" "${BUDGET[$s]:-}"; done', '"${TIME[$s]}"; done', 'no budget column'),
 ('M17', 'TW26', 'scripts/test.sh', '[l2]=30', '[l2]=31', 'l2 budget 31'),
 ('M18', 'TW26', 'scripts/test.sh', 'over "$run_s" "$BUDGET_ALL" &&', 'false &&', 'no total warning'),
 ('M19', 'TW26', 'scripts/test.sh', '[ -n "${BUDGET[$s]:-}" ] && over "${RAW[$s]}" "${BUDGET[$s]}" &&', 'false &&', 'no step warning'),
 ('M20', 'TW26', 'scripts/test.sh', 'BUDGET_ALL=${BUDGET_TOTAL:-180}', 'BUDGET_ALL=180', 'BUDGET_TOTAL ignored'),
 ('M21', 'TW26', 'scripts/test.sh', 'echo "WARN $s: ${TIME[$s]} s is over the budget of ${BUDGET[$s]} s (TW20)"', 'echo "WARN $s: ${TIME[$s]} s is over the budget of ${BUDGET[$s]} s (TW20)"; total=1', 'a step warning fails the run'),
]

def main():
    save()
    restore()
    rows, caught = [], 0
    for (mid, rule, f, old, new, what) in M:
        restore()
        path = os.path.join(ROOT, f)
        s = open(path).read()
        if s.count(old) != 1:
            rows.append((mid, rule, what, 'MUTATION DID NOT APPLY (%d matches)' % s.count(old)))
            continue
        open(path, 'w').write(s.replace(old, new))
        try:
            env = dict(os.environ, SELFTEST_L2BIN=os.path.join(ROOT, '.work/bin/l2'))
            r = subprocess.run(['timeout', '300', os.path.join(ROOT, 'tests/selftest.sh')], cwd=ROOT, env=env,
                               capture_output=True, text=True)
            out = r.stdout + r.stderr
            fails = re.findall(r'^SELFTEST FAIL: (.*)$', out, re.M)
            if r.returncode != 0 and fails:
                caught += 1
                rows.append((mid, rule, what, 'caught: ' + '; '.join(x.split(':')[0] for x in fails)))
            elif r.returncode != 0:
                rows.append((mid, rule, what, 'selftest exit %d, no row text (crash?)' % r.returncode))
            else:
                rows.append((mid, rule, what, 'NOT CAUGHT'))
        finally:
            restore()
    same = all(open(os.path.join(ROOT, f)).read() == open(os.path.join(COPY, f)).read() for f in FILES)
    with open(os.path.join(HERE, 'code-results.md'), 'w') as o:
        o.write('# Slice 018 revert check of the code (harness)\n\nCaught %d of %d. Files equal to the copy after the run: %s.\n\n' % (caught, len(M), same))
        o.write('| # | Rule | Mutation | Result (the selftest rows that failed) |\n| --- | --- | --- | --- |\n')
        for r in rows:
            o.write('| %s | %s | %s | %s |\n' % r)
    print(open(os.path.join(HERE, 'code-results.md')).read())
    sys.exit(0 if same else 1)

main()
