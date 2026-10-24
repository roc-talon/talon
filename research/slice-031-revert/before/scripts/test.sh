#!/usr/bin/env bash
# The fast set (TW20): check, fmt check, L0, L2, L3 fast, and the self-test of the runners.
# Exit 0 only when every step passes. L1 (roc-fuzz) joins when the first target exists.
# Usage: scripts/test.sh [step ...]    steps: check fmt l0 l2 l3 selftest (default: all)
#        VERBOSE=1                     print the log of each step, not only of a failed one
#        ROC=<path>                    another compiler (default: the pinned nightly, scripts/env.sh)
#        OPT=dev|speed                 build mode of the test binaries (default dev; speed is LLVM; another value: exit 2, TW25)
#        SLOW=1                        also run the L3 cases with the tag slow (TW27; tests/run.sh reads it)
#        JOBS=<n>                      L0 files and L2/L3 cases at the same time (default: the CPU count)
#        BUDGET_<STEP>=<s>             change the budget of one step for this run (CHECK FMT L0 L1 L2 L3 SELFTEST, TW26)
#        BUDGET_TOTAL=<s>              the budget of the whole run (default 180, TW20)
#        TEST_MEM_GB=<n>               the memory that this run may use (default: a third of MemAvailable). Jobs of roc = min(CPUs, (budget - reserve) / per-job peak).
#                                      The peaks (1 GB for check and l0, 2 GB for a build) and the object cache rule are in research/test-memory/RESULTS.md.
#        OBJ_KEEP=<n>                  files kept in each dir of the roc object cache (default 3). A large cache makes `roc check` use 14 GB.
# The table has the budget of each step. With OPT=dev, a step over its budget, or a run over BUDGET_TOTAL, gives a WARN line (exit code 0).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
. "$ROOT/tests/lib.sh"
check_opt
RUN_START=$(date +%s.%N)
cd "$ROOT" || exit 1
prune_roc_objects
LOGS=$WORK/logs
mkdir -p "$LOGS"
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(check fmt l0 l2 l3 selftest)

# Roc files with a header: the apps and packages of Talon. The unit files (UNIT) are not here: `roc test` in the l0 step fails on every error
# and on every warning that `roc check` reports for them (exit 1 and exit 2, research/check-speed/RESULTS.md), so a second compile in `check` finds nothing new.
# tests/selftest.sh has the rows that keep this true (slice P1 section 5).
mapfile -t UNIT < <({ ls tests/unit/*.roc; ls packages/*/tests/*.roc; } 2> /dev/null | sort -u)
mapfile -t APPS < <({ echo cli/main.roc; echo cli/fxprobe.roc; echo cli/flowprobe.roc; echo cli/lib/main.roc; echo tests/commands/main.roc
    ls packages/*/main.roc 2> /dev/null; } | sort -u)

# The calls run in parallel (at most JOBS), as l0 does. The report is in the order of APPS.
# cli/main.roc goes first and alone: it fills the roc cache with the modules that the other apps share. With a cold cache (after an edit in cli/lib)
# the 5 apps at the same time took 8.5 s, and this order 5 s (research/check-speed/RESULTS.md).
step_check() {
    local rc=0 f n dir=$LOGS/check
    rm -rf "$dir"
    mkdir -p "$dir"
    check_one() {
        n=${1//\//_}
        "$ROC" check "$1" > "$2/$n.log" 2>&1; echo $? > "$2/$n.rc"
    }
    check_one cli/main.roc "$dir"
    export -f check_one
    export ROC
    printf '%s\0' "${APPS[@]}" | grep -zv '^cli/main.roc$' | xargs -0 -P "$(roc_jobs 0 "$CHECK_MB")" -I{} bash -c 'check_one "$1" "$2"' _ {} "$dir"
    for f in "${APPS[@]}"; do
        n=$(l0_name "$f")
        [ "$(cat "$dir/$n.rc")" = 0 ] && continue
        cat "$dir/$n.log"
        echo "^^^ roc check $f (exit $(cat "$dir/$n.rc"))"
        rc=1
    done
    return $rc
}
# The files under `given/` and `tests/fixtures/` are fixtures: some are not valid Roc on purpose (a bad header, slice 002; a syntax error, slice 006), and their line numbers are in the expected outputs.
step_fmt() { "$ROC" fmt --check $(find cli tests $(ls -d packages 2> /dev/null) -name '*.roc' -not -path '*/given/*' -not -path 'tests/fixtures/*' | sort); }
# The files run in parallel (at most JOBS). The report is in the order of UNIT.
l0_name() { echo "${1//\//_}"; }
step_l0() {
    local rc=0 f n dir=$LOGS/l0
    rm -rf "$dir"
    mkdir -p "$dir"
    printf '%s\0' "${UNIT[@]}" | xargs -0 -P "$(roc_jobs "$BUILD_RESERVE_MB" "$CHECK_MB")" -I{} bash -c '
        n=${1//\//_}
        # roc test exits 1 on a failed expect and on a compile error
        "$ROC" test "$1" --no-cache > "$2/$n.log" 2>&1; echo $? > "$2/$n.rc"' _ {} "$dir"
    for f in "${UNIT[@]}"; do
        n=$(l0_name "$f")
        if [ "$(cat "$dir/$n.rc")" = 0 ]; then
            echo "$f: $(grep -h 'passed' "$dir/$n.log" | head -n 1)"
        else
            echo "$f: FAILED"; cat "$dir/$n.log"; rc=1
        fi
    done
    return $rc
}
step_l2() { wait_build l2 && L2BIN=$WORK/bin/l2 tests/commands/run.sh; }
step_l3() { wait_build tln && wait_build fxprobe && wait_build flowprobe && TLN=$WORK/bin/tln tests/run.sh; }
step_selftest() { wait_build l2 && SELFTEST_L2BIN=$WORK/bin/l2 tests/selftest.sh; }

# The slow part of L2, L3 and the self-test is `roc build` of the test apps (LLVM: 90 s each, --opt=dev: 2 to 5 s). So the builds start
# together at the start (the machine has many cores), and each build is made once: the self-test shares the L2 app.
# A build uses up to BUILD_MB of memory, so at most BUILD_JOBS run at the same time (4 with the default budget).
# build_start <name> <main.roc> adds a build to the list. build_launch starts the list in the background. wait_build <name>: wait for it, print the log of a failure.
CHECK_MB=1000 BUILD_MB=2000
declare -A BUILD_WANT
BUILD_LIST=()
BUILD_RESERVE_MB=0
build_start() { rm -f "$LOGS/build-$1.rc"; BUILD_WANT[$1]=1; BUILD_LIST+=("$1 $2"); }
build_one() { # build_one <name> <main.roc>
    "$ROC" build "$2" --opt="$OPT" --output="$WORK/bin/$1" > "$LOGS/build-$1.log" 2>&1
    echo $? > "$LOGS/build-$1.rc"
}
build_launch() {
    [ ${#BUILD_LIST[@]} -gt 0 ] || return 0
    local n
    n=$(roc_jobs 0 "$BUILD_MB")
    [ "$n" -gt ${#BUILD_LIST[@]} ] && n=${#BUILD_LIST[@]}
    export -f build_one
    export ROC OPT WORK LOGS
    ( printf '%s\n' "${BUILD_LIST[@]}" | xargs -P "$n" -L1 bash -c 'build_one "$@"' _ ) &
    BUILD_PID=$!
}
wait_build() {
    [ -n "${BUILD_WANT[$1]:-}" ] || return 0
    until [ -f "$LOGS/build-$1.rc" ]; do
        kill -0 "${BUILD_PID:-}" 2> /dev/null || [ -f "$LOGS/build-$1.rc" ] || { echo "build of $1 did not run"; return 1; }
        sleep 0.05
    done
    [ "$(cat "$LOGS/build-$1.rc")" = 0 ] || { echo "build of $1 failed:"; cat "$LOGS/build-$1.log"; return 1; }
}

# The budget of each step in seconds (TW26). BUDGET_<STEP> changes one for this run.
declare -A BUDGET=([check]=10 [fmt]=5 [l0]=10 [l1]=60 [l2]=30 [l3]=60 [selftest]=20)
for s in "${!BUDGET[@]}"; do
    v=BUDGET_${s^^}
    [ -n "${!v:-}" ] && BUDGET[$s]=${!v}
done
BUDGET_ALL=${BUDGET_TOTAL:-180}
over() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; } # over <seconds> <budget>

declare -A RESULT TIME RAW
total=0
plan_builds() {
    local s
    for s in "${STEPS[@]}"; do
        case $s in
        l2 | selftest) [ -z "${BUILD_WANT[l2]:-}" ] && build_start l2 tests/commands/main.roc ;;
        l3) build_start tln cli/main.roc; build_start fxprobe cli/fxprobe.roc; build_start flowprobe cli/flowprobe.roc ;;
        esac
    done
    # The l0 step runs while the builds run: it keeps their memory free.
    local n
    n=$(roc_jobs 0 "$BUILD_MB")
    [ "$n" -gt ${#BUILD_LIST[@]} ] && n=${#BUILD_LIST[@]}
    BUILD_RESERVE_MB=$((n * BUILD_MB))
}
plan_builds
start_builds() { build_launch; }
# The check step goes first when it is the first step: it runs alone (3 s). With the builds at the same time (the machine has all its cores busy) it took 13 s and went over its budget.
[ "${STEPS[0]}" = check ] || start_builds
for s in "${STEPS[@]}"; do
    start=$(date +%s.%N)
    "step_$s" > "$LOGS/$s.log" 2>&1
    rc=$?
    [ "$s" = check ] && [ "${STEPS[0]}" = check ] && start_builds
    RAW[$s]=$(awk -v a="$(date +%s.%N)" -v b="$start" 'BEGIN { printf "%.3f", a - b }')
    TIME[$s]=$(printf '%.1f' "${RAW[$s]}")
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
printf '%-10s %-6s %-8s %s\n' step result seconds budget
for s in "${STEPS[@]}"; do printf '%-10s %-6s %-8s %s\n' "$s" "${RESULT[$s]}" "${TIME[$s]}" "${BUDGET[$s]:-}"; done
# The WARN lines are for OPT=dev only (TW26): the LLVM build of OPT=speed is slow on purpose.
if [ "$OPT" = dev ]; then
    for s in "${STEPS[@]}"; do
        [ -n "${BUDGET[$s]:-}" ] && over "${RAW[$s]}" "${BUDGET[$s]}" &&
            echo "WARN $s: ${TIME[$s]} s is over the budget of ${BUDGET[$s]} s (TW20)"
    done
    run_s=$(awk -v a="$(date +%s.%N)" -v b="$RUN_START" 'BEGIN { printf "%.3f", a - b }')
    over "$run_s" "$BUDGET_ALL" && echo "WARN total: $(printf '%.1f' "$run_s") s is over $BUDGET_ALL s (TW20)"
fi
exit $total
