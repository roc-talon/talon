#!/usr/bin/env bash
# The fast set (TW20): check, fmt check, L0, L1, L2, L3 fast, and the self-test of the runners.
# Exit 0 only when every step passes.
# Usage: scripts/test.sh [step ...]    steps: check fmt l0 l1 l2 l3 selftest (default: all, with l1 last: its builds start at the start and take 30 s, so l1 waits for no build)
#        VERBOSE=1                     print the log of each step, not only of a failed one
#        ROC=<path>                    another compiler (default: the pinned nightly, scripts/env.sh)
#        OPT=dev|speed                 build mode of the test binaries (default dev; speed is LLVM; another value: exit 2, TW25)
#        SLOW=1                        also run the L3 cases with the tag slow (TW27; tests/run.sh reads it)
#        JOBS=<n>                      L0 files, L1 targets and L2/L3 cases at the same time (default: the CPU count)
#        L1_RUNS=<n>                   inputs for each roc-fuzz target (default: the line `# l1-runs: <n>` of the target file, else 20000: a fixed count, TW6). L1_SEED=<n>: the seed (default 1).
#        L1_DIR=<dir>                  the dir of the targets (default tests/fuzz)
#        L1_HOST=<system>-<arch>       the system for the l1 support check (default: uname -s and uname -m). roc-fuzz has a platform for Linux-x86_64 and Darwin-arm64 only: another system skips l1.
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
[ ${#STEPS[@]} -eq 0 ] && STEPS=(check fmt l0 l2 l3 selftest l1)

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
# L1 (TESTING.md 4): the roc-fuzz targets `tests/fuzz/*.roc`, one process for each target, at most JOBS at the same time. A target is built with `roc build --fuzz`, which needs LLVM
# (`--opt=dev` gives an error), so the build is always `--opt=speed` and does not follow OPT. It runs the count of the target (l1_runs_of) with the seed L1_SEED (TW6: a fixed count, no `--time`), in its own dir
# `$WORK/l1/<name>/` that is new for each run (the corpus `.roc-fuzz/` is made there, never in the repo, and a run never starts from an old corpus). A failure saves the input under
# `$WORK/l1/<name>/art/`: the report names the file and the command that replays it. TW5: the minimized input becomes an `expect` of L0 before the fix.
# The run count of one target: L1_RUNS when it is set (the nightly run sets a long one for all targets), else the line `# l1-runs: <n>` of the target file, else 20000.
# A target with a costly property keeps its own small count in the fast set (TESTING.md 1: the long runs are for the nightly run).
L1_SEED=${L1_SEED:-1}
L1_DIR=${L1_DIR:-tests/fuzz}
l1_runs_of() {
    local n
    [ -n "${L1_RUNS:-}" ] && { echo "$L1_RUNS"; return; }
    n=$(sed -n 's/^# l1-runs: \([0-9][0-9]*\)$/\1/p' "$1" | head -n 1)
    echo "${n:-20000}"
}
l1_targets() { # the targets of the step, nothing on a system that has no roc-fuzz platform
    case ${L1_HOST:-$(uname -s)-$(uname -m)} in
    Linux-x86_64 | Darwin-arm64) ls "$L1_DIR"/*.roc 2> /dev/null | sort ;;
    esac
}
# The builds start with the other builds (plan_builds), so the LLVM build of a target runs while check, fmt and l0 run. The dirs are new for each run (the corpus `.roc-fuzz/` is made there,
# never in the repo, and a run never starts from an old corpus).
l1_build() { # l1_build <target.roc> <dir>
    local name d
    name=$(basename "$1" .roc)
    d=$2/$name
    mkdir -p "$d"
    "$ROC" build --fuzz --opt=speed "$1" --output="$d/target" > "$d/build.log" 2>&1
    echo $? > "$d/build.rc"
}
l1_run() { # l1_run <target.roc> <dir>: wait for the build, run the target with its count. The exit code is in <dir>/<name>/run.rc
    local name d runs
    name=$(basename "$1" .roc)
    d=$2/$name
    until [ -f "$d/build.rc" ]; do
        kill -0 "${BUILD_PID:-}" 2> /dev/null || [ -f "$d/build.rc" ] || return 0
        sleep 0.05
    done
    [ "$(cat "$d/build.rc")" = 0 ] || return 0
    runs=$(l1_runs_of "$1")
    ( cd "$d" && ./target run --runs="$runs" --seed="$L1_SEED" --artifact-dir="$d/art" > "$d/run.log" 2>&1; echo $? > "$d/run.rc" )
}
step_l1() {
    local rc=0 f name d dir=$WORK/l1 targets
    mapfile -t targets < <(l1_targets)
    if [ ${#targets[@]} -eq 0 ]; then
        case ${L1_HOST:-$(uname -s)-$(uname -m)} in
        Linux-x86_64 | Darwin-arm64) echo "l1: no target in $L1_DIR" ;;
        *) echo "l1: skipped, roc-fuzz has no platform for ${L1_HOST:-$(uname -s)-$(uname -m)}" ;;
        esac
        return 0
    fi
    export -f l1_run l1_runs_of
    export ROC L1_RUNS L1_SEED BUILD_PID
    printf '%s\0' "${targets[@]}" | xargs -0 -P "${#targets[@]}" -I{} bash -c 'l1_run "$1" "$2"' _ {} "$dir"
    for f in "${targets[@]}"; do
        name=$(basename "$f" .roc)
        d=$dir/$name
        if [ ! -f "$d/build.rc" ]; then
            echo "$f: FAILED, no result"; rc=1
        elif [ "$(cat "$d/build.rc")" != 0 ]; then
            echo "$f: FAILED, the build"; cat "$d/build.log"; rc=1
        elif [ "$(cat "$d/run.rc" 2> /dev/null)" = 0 ]; then
            echo "$f: $(grep -h '^Done' "$d/run.log" | head -n 1)"
        else
            echo "$f: FAILED (exit $(cat "$d/run.rc" 2> /dev/null), seed $L1_SEED, $(l1_runs_of "$f") runs)"
            grep -v -e '^INFO' -e '^#' -e '^"' -e '^######' "$d/run.log" | head -n 40
            for a in "$d"/art/*; do
                [ -f "$a" ] && echo "replay: $d/target replay $a"
            done
            rc=1
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
build_one() { # build_one <name> <main.roc>. A name l1-<target> is an L1 target: `roc build --fuzz` in its own dir under $WORK/l1 (LLVM only, it does not follow OPT)
    if [ "${1#l1-}" != "$1" ]; then
        l1_build "$2" "$WORK/l1"
        cp "$WORK/l1/${1#l1-}/build.rc" "$LOGS/build-$1.rc"
        return 0
    fi
    "$ROC" build "$2" --opt="$OPT" --output="$WORK/bin/$1" > "$LOGS/build-$1.log" 2>&1
    echo $? > "$LOGS/build-$1.rc"
}
build_launch() {
    [ ${#BUILD_LIST[@]} -gt 0 ] || return 0
    local n
    n=$(roc_jobs 0 "$BUILD_MB")
    [ "$n" -gt ${#BUILD_LIST[@]} ] && n=${#BUILD_LIST[@]}
    export -f build_one l1_build
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
        l1) rm -rf "$WORK/l1"; mkdir -p "$WORK/l1"
            while read -r t; do [ -n "$t" ] && build_start "l1-$(basename "$t" .roc)" "$t"; done < <(l1_targets) ;;
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
