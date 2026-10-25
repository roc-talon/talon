#!/usr/bin/env bash
# N full runs of the OLD l0 step (86 files, one `roc test` for each file, 1 thread each): test-proto.sh is scripts/test.sh as it was, with the unit list of unit-list-before.txt
# (the copies in research/l0-time/before/tests/unit, which reach cli/ and tests/fixtures through symlinks). The l0 order file is removed before each run (cold). Usage: full-runs-before.sh <N> <out-file>
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
cd "$ROOT" || exit 1
for i in $(seq 1 "$1"); do
    rm -f "$WORK/l0-times"
    echo "== run $i $(date +%T)"
    UNIT_LIST=$HERE/unit-list-before.txt "$HERE/test-proto.sh" 2>&1 | tail -n 14
done > "$2" 2>&1
