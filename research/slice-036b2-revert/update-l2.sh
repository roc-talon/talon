#!/usr/bin/env bash
# Slice 036b2: change the expected files of old L2 cases on purpose (TW21). Usage: update-l2.sh <case> ...
# For each case: the expect/ dir goes to before/ first (once), then the L2 runner writes the actual output (UPDATE=1).
# Then check-diff.py lists each changed line that is not of an allowed kind. Run it with the reference in the tree.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
cd "$ROOT" || exit 1
. scripts/env.sh
for c in "$@"; do
    src=tests/commands/cases/$c/expect
    dst=$HERE/before/$src
    if [ ! -d "$dst" ]; then
        mkdir -p "$dst"
        cp -a "$src/." "$dst/"
    fi
    UPDATE=1 L2BIN=$WORK/bin/l2 tests/commands/run.sh "$c" > /dev/null 2>&1
    python3 -I "$HERE/check-diff.py" "$dst" "$src" "$c"
done
