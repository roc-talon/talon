#!/usr/bin/env bash
# N full runs of scripts/test.sh. Cold: the l0 order file ($WORK/l0-times) is removed before each run (the l0 step uses `roc test --no-cache`, so the runner keeps no other l0 cache).
# Usage: full-runs.sh <N> <out-file>
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
cd "$ROOT" || exit 1
for i in $(seq 1 "$1"); do
    rm -f "$WORK/l0-times"
    echo "== run $i $(date +%T)"
    scripts/test.sh 2>&1 | tail -n 14
done > "$2" 2>&1
