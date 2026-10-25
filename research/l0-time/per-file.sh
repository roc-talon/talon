#!/usr/bin/env bash
# One run of each unit file alone (no other load), `--jobs=$1` (default 1). Output: "<ms> <expects> <imports> <file>", slowest first.
# Usage: research/l0-time/per-file.sh [threads] > out.txt
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
cd "$ROOT" || exit 1
t=${1:-1}
for f in $({ ls tests/unit/*.roc; ls packages/*/tests/*.roc; } | sort -u); do
    s=$(date +%s%N)
    "$ROC" test "$f" --no-cache --jobs="$t" > /dev/null 2>&1
    ms=$(( ($(date +%s%N) - s) / 1000000 ))
    echo "$ms $(grep -c '^expect' "$f") $(grep -c '^import' "$f") $f"
done | sort -rn
