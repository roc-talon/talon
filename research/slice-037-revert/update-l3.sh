#!/usr/bin/env bash
# Slice 037: change the expected files of old L3 cases on purpose (TW21). Usage: update-l3.sh <case> ...
# The expect/ dir is in before/ already (copied once). Run it with the reference in cli/lib (swap.sh reference).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
cd "$ROOT" || exit 1
for c in "$@"; do
    src=tests/scenarios/$c/expect
    dst=$HERE/before/$src
    [ -d "$dst" ] || { mkdir -p "$dst"; cp -a "$src/." "$dst/"; }
    UPDATE=1 tests/run.sh "$c" > /dev/null 2>&1
    diff -ru "$dst" "$src" || true
done
