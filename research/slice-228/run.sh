#!/usr/bin/env bash
# CPU check of slice 228: Sorted.sort_with against List.sort_with, natively (--opt=speed), with both compilers of scripts/env.sh.
# Usage: research/slice-228/run.sh      Env: SORTED=<file> (default packages/records/Sorted.roc), BEST=<n> runs for each cell (default 5).
# It prints a table: microseconds for one sort, for each compiler, shape and row count. A measure, not a test: it never fails on a number.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
ROC_WORKER=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
SORTED=${SORTED:-$ROOT/packages/records/Sorted.roc}
BEST=${BEST:-5}
D=$WORK/slice-228
rm -rf "$D"; mkdir -p "$D"
cp "$HERE/bench.roc" "$D/bench.roc"; cp "$SORTED" "$D/Sorted.roc"
now() { date +%s%N; }
# best <exe> <variant> <shape> <rows> <reps>: the least wall time (ns) of BEST runs.
best() {
    local b=0 s t i
    for ((i = 0; i < BEST; i++)); do
        s=$(now); "$@" > /dev/null; t=$(($(now) - s))
        if [ "$b" = 0 ] || [ "$t" -lt "$b" ]; then b=$t; fi
    done
    echo "$b"
}
echo "sorted source: $SORTED"
printf '%-24s %-7s %6s %6s %12s %12s %8s\n' compiler shape rows reps builtin_us own_us own/builtin
for pair in "cli:$ROC" "worker:$ROC_WORKER"; do
    name=${pair%%:*}; roc=${pair#*:}
    (cd "$D" && "$roc" build --opt=speed --output="$D/bench-$name" bench.roc > /dev/null)
    for shape in pair record; do
        for cfg in "500 4000" "5000 300"; do
            set -- $cfg; rows=$1; reps=$2
            base=$(best "$D/bench-$name" none $shape "$rows" "$reps")
            b=$(best "$D/bench-$name" builtin $shape "$rows" "$reps")
            o=$(best "$D/bench-$name" own $shape "$rows" "$reps")
            awk -v n="$name" -v s="$shape" -v r="$rows" -v p="$reps" -v b="$b" -v o="$o" -v z="$base" 'BEGIN { bu = (b - z) / p / 1000; ou = (o - z) / p / 1000; printf "%-24s %-7s %6d %6d %12.1f %12.1f %8.2f\n", n, s, r, p, bu, ou, (bu > 0 ? ou / bu : 0) }'
        done
    done
done
