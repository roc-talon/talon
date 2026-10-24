#!/bin/bash
# The fast set (TW20): check, fmt check, L0, L2, L3 fast, and the self-test of the runners.
# Exit 0 only when every step passes. L1 (roc-fuzz) joins when the first target exists.
# Usage: scripts/test.sh [step ...]    steps: check fmt l0 l2 l3 selftest (default: all)
#        VERBOSE=1                     print the log of each step, not only of a failed one
#        ROC=<path>                    another compiler (default: the pinned nightly, scripts/env.sh)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
cd "$ROOT" || exit 1
LOGS=$WORK/logs
mkdir -p "$LOGS"
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(check fmt l0 l2 l3 selftest)

# Roc files with a header: the apps and packages of Talon.
mapfile -t APPS < <({ echo cli/main.roc; echo cli/fxprobe.roc; echo cli/flowprobe.roc; echo cli/lib/main.roc; echo tests/commands/main.roc
    ls packages/*/main.roc 2> /dev/null; ls packages/*/tests/*.roc 2> /dev/null; ls tests/unit/*.roc; } | sort -u)
mapfile -t UNIT < <({ ls tests/unit/*.roc; ls packages/*/tests/*.roc; } 2> /dev/null | sort -u)

step_check() { # exit 0 only for "No errors found": a warning (exit 2) is a failure
    local rc=0 f
    for f in "${APPS[@]}"; do
        "$ROC" check "$f" || { echo "^^^ roc check $f (exit $?)"; rc=1; }
    done
    return $rc
}
# The files under `given/` and `tests/fixtures/` are fixtures: some are not valid Roc on purpose (a bad header, slice 002; a syntax error, slice 006), and their line numbers are in the expected outputs.
step_fmt() { "$ROC" fmt --check $(find cli tests $(ls -d packages 2> /dev/null) -name '*.roc' -not -path '*/given/*' -not -path 'tests/fixtures/*' | sort); }
step_l0() {
    local rc=0 f log=$LOGS/l0-one.log
    for f in "${UNIT[@]}"; do
        # roc test exits 1 on a failed expect and on a compile error
        if "$ROC" test "$f" --no-cache > "$log" 2>&1; then
            echo "$f: $(grep -h 'passed' "$log" | head -n 1)"
        else
            echo "$f: FAILED"; cat "$log"; rc=1
        fi
    done
    return $rc
}
step_l2() { wait_build l2 && L2BIN=$WORK/bin/l2 tests/commands/run.sh; }
step_l3() { wait_build tln && wait_build fxprobe && wait_build flowprobe && TLN=$WORK/bin/tln tests/run.sh; }
step_selftest() { wait_build l2 && SELFTEST_L2BIN=$WORK/bin/l2 tests/selftest.sh; }

# The slow part of L2, L3 and the self-test is `roc build` of the test apps (about 30 s each). So the builds start
# together at the start (the machine has many cores), and each build is made once: the self-test shares the L2 app.
# build_start <name> <main.roc>: build $WORK/bin/<name> in the background. wait_build <name>: wait for it, print the log of a failure.
declare -A BUILD_PID
build_start() {
    ( "$ROC" build "$2" --output="$WORK/bin/$1" > "$LOGS/build-$1.log" 2>&1; echo $? > "$LOGS/build-$1.rc" ) &
    BUILD_PID[$1]=$!
}
wait_build() {
    [ -n "${BUILD_PID[$1]:-}" ] || return 0
    wait "${BUILD_PID[$1]}"
    [ "$(cat "$LOGS/build-$1.rc")" = 0 ] || { echo "build of $1 failed:"; cat "$LOGS/build-$1.log"; return 1; }
}

declare -A RESULT TIME
total=0
for s in "${STEPS[@]}"; do
    case $s in
    l2 | selftest) [ -z "${BUILD_PID[l2]:-}" ] && build_start l2 tests/commands/main.roc ;;
    l3) build_start tln cli/main.roc; build_start fxprobe cli/fxprobe.roc; build_start flowprobe cli/flowprobe.roc ;;
    esac
done
for s in "${STEPS[@]}"; do
    start=$(date +%s.%N)
    "step_$s" > "$LOGS/$s.log" 2>&1
    rc=$?
    TIME[$s]=$(printf '%.1f' "$(echo "$(date +%s.%N) - $start" | bc)")
    if [ $rc -eq 0 ]; then
        RESULT[$s]=pass
        [ "${VERBOSE:-0}" = 1 ] && cat "$LOGS/$s.log"
    else
        RESULT[$s]=FAIL
        total=1
        echo "== $s: FAIL (log: $LOGS/$s.log)"
        tail -n "${TAIL:-60}" "$LOGS/$s.log"
    fi
done
echo
printf '%-10s %-6s %s\n' step result seconds
for s in "${STEPS[@]}"; do printf '%-10s %-6s %s\n' "$s" "${RESULT[$s]}" "${TIME[$s]}"; done
exit $total
