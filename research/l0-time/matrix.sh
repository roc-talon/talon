#!/usr/bin/env bash
# For each "<N> <T>": write N drivers (gen-drivers.sh), run 2 cold full runs with L0_THREADS=T. Output: one line "N T l0-seconds" for each run. Usage: matrix.sh <out> "<N> <T>" ...
HERE=$(cd "$(dirname "$0")" && pwd)
out=$1; shift
for cfg in "$@"; do
    set -- $cfg
    rm -f "$HERE"/../../tests/unit/l0-*.roc
    "$HERE/gen-drivers.sh" "$1"
    L0_THREADS=$2 "$HERE/full-runs.sh" 2 "$HERE/matrix-tmp.txt"
    grep '^l0 ' "$HERE/matrix-tmp.txt" | awk -v n="$1" -v t="$2" '{ print "N=" n, "T=" t, "l0=" $3 }' >> "$out"
done
