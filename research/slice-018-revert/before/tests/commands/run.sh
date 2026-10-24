#!/bin/bash
# L2 runner: command code with the fake Fx, in a compiled basic-cli test app (TESTING.md 2.4).
# Usage: tests/commands/run.sh [filter ...]
#   UPDATE=1       write the actual output to expect/ (TW21)
#   CASES=<dir>    another case tree (the self-test of the runner uses it)
#   L2BIN=<file>   use this test app, do not build one
#   JOBS=<n>       cases at the same time
# A case is a dir `<area>/<id>-<name>/` that has a file `entry`. The work dir is $TMPDIR/talon-l2/<case>/.
#   entry           the entry of tests/commands/main.roc: run | prompt | harness (one word)
#   fx/             the answers of the fake Fx (the table is in tests/commands/FakeFx.roc)
#   given/home/, given/project/   the start state of the dirs (the fake Fx works in them)
#   expect/stdout, expect/stderr, expect/exit, expect/calls.log, expect/tree.diff
# calls.log has one line for each Fx call, in order. A missing expected file is an empty file (exit: 0).
set -u
SELF=$(cd "$(dirname "$0")" && pwd)
. "$SELF/../../scripts/env.sh"
. "$SELF/../lib.sh"
CASES=${CASES:-$SELF/cases}
CASEROOT=${TMPDIR:-/tmp}/talon-l2

run_case() {
    local dir=$1 bin=$2 name W entry
    name=${dir#"$CASES"/}
    W=$CASEROOT/$(echo "$name" | tr / _)
    rm -rf "$W"
    mkdir -p "$W/home" "$W/project" "$W/out" "$W/fx"
    ln -s "$SELF/../fixtures" "$W/fixtures" # the real roc outputs of tests/fixtures/check/out, for the answers of the fake probes! (slice 006)
    [ -d "$dir/given" ] && cp -a "$dir/given/." "$W/"
    [ -d "$dir/fx" ] && cp -a "$dir/fx/." "$W/fx/"
    mkdir -p "$W/orig" && cp -a "$W/home" "$W/orig/home" && cp -a "$W/project" "$W/orig/project"
    entry=$(cat "$dir/entry")
    "$bin" "$W" "$entry" > "$W/out/app.log" 2>&1
    local app_rc=$?
    [ -f "$W/out/exit" ] || { echo "  the test app wrote no exit file (exit $app_rc):"; sed -e 's/^/    /' "$W/out/app.log"; return 1; }
    for f in stdout stderr calls.log; do
        touch "$W/out/$f"
        normalize "$W" < "$W/out/$f" > "$W/out/$f.n"
    done
    tree_diff "$W" > "$W/out/tree.diff"
    local ex=$dir/expect
    if [ "${UPDATE:-0}" = 1 ]; then
        update_file "$ex/stdout" "$W/out/stdout.n" optional
        update_file "$ex/stderr" "$W/out/stderr.n" optional
        update_file "$ex/exit" "$W/out/exit"
        update_file "$ex/calls.log" "$W/out/calls.log.n" optional
        update_file "$ex/tree.diff" "$W/out/tree.diff"
        return 0
    fi
    if [ -f "$ex/exit" ]; then cp "$ex/exit" "$W/out/exit.expected"; else echo 0 > "$W/out/exit.expected"; fi
    local fail=0 report=$W/out/report
    : > "$report"
    compare_file "exit code" "$W/out/exit.expected" "$W/out/exit" >> "$report" || fail=1
    compare_file "stdout" "$ex/stdout" "$W/out/stdout.n" >> "$report" || fail=1
    compare_file "stderr" "$ex/stderr" "$W/out/stderr.n" >> "$report" || fail=1
    compare_file "Fx calls" "$ex/calls.log" "$W/out/calls.log.n" >> "$report" || fail=1
    compare_file "file tree" "$ex/tree.diff" "$W/out/tree.diff" >> "$report" || fail=1
    if [ $fail = 1 ]; then cat "$report"; return 1; fi
    return 0
}

if [ "${1:-}" = --case ]; then
    run_case "$3" "$2"
    exit $?
fi

BIN=${L2BIN:-$WORK/bin/l2}
if [ -z "${L2BIN:-}" ]; then
    "$ROC" build "$SELF/main.roc" --output="$BIN" > "$WORK/build-l2.log" 2>&1 ||
        { echo "build of the L2 app failed:"; cat "$WORK/build-l2.log"; exit 1; }
fi

mapfile -t ALL < <(find "$CASES" -name entry -type f -printf '%h\n' | sort)
SEL=()
for c in "${ALL[@]}"; do
    rel=${c#"$CASES"/}
    if [ $# -eq 0 ]; then SEL+=("$c"); continue; fi
    for f in "$@"; do
        case $rel in *"$f"*) SEL+=("$c"); break ;; esac
    done
done
if [ ${#SEL[@]} -eq 0 ]; then echo "commands: no case matches"; exit 1; fi

mkdir -p "$CASEROOT"
RESULTS=$(mktemp -d)
printf '%s\0' "${SEL[@]}" |
    xargs -0 -P "$(parallel_jobs)" -I{} bash -c '
        out=$("$0" --case "$1" "$2" 2>&1); rc=$?
        n=$(echo "${2#"$3"/}" | tr / _)
        printf "%s\n" "$out" > "$4/$n.out"; echo $rc > "$4/$n.rc"' "$0" "$BIN" {} "$CASES" "$RESULTS"

pass=0 failed=0
for c in "${SEL[@]}"; do
    rel=${c#"$CASES"/}
    n=$(echo "$rel" | tr / _)
    if [ "$(cat "$RESULTS/$n.rc")" = 0 ]; then
        pass=$((pass + 1))
    else
        failed=$((failed + 1)); echo "FAIL $rel"; sed -e 's/^/  /' "$RESULTS/$n.out"
    fi
done
rm -rf "$RESULTS"
echo "commands: $pass passed, $failed failed"
[ $failed -eq 0 ]
