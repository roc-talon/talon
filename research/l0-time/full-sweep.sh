#!/usr/bin/env bash
# Full test.sh runs (the prototype copy) with a unit list and L0_THREADS. Usage: full-sweep.sh "<N> <T>" ...  Prints the l0 line of each run.
HERE=$(cd "$(dirname "$0")" && pwd)
for cfg in "$@"; do
    set -- $cfg
    for i in 1 2; do
        printf 'N=%s T=%s run%s ' "$1" "$2" "$i"
        UNIT_LIST=$HERE/exp3/$1/unit-list.txt L0_THREADS=$2 "$HERE/test-proto.sh" 2>&1 | grep -E "^l0 |FAIL"
    done
done
