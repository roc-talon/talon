#!/usr/bin/env bash
# Slice 032: change the expected files of old L3 cases on purpose (TW21). Usage: update-l3.sh <case> ...
# The expect/ dir goes to before/ first (once), then tests/run.sh writes the actual output (UPDATE=1).
# check-diff3.py then lists each changed line that is not of an allowed kind. Run it with the reference in the tree.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
cd "$ROOT" || exit 1
. scripts/env.sh
for c in "$@"; do
    src=tests/scenarios/$c/expect
    dst=$HERE/before/$src
    if [ ! -d "$dst" ]; then
        mkdir -p "$dst"
        cp -a "$src/." "$dst/"
    fi
    UPDATE=1 tests/run.sh "$c" > /dev/null 2>&1
    python3 -I "$HERE/check-diff3.py" "$dst" "$src" "$c"
done
