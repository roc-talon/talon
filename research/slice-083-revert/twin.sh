#!/usr/bin/env bash
# Test-agent helper of slice 083: run the old code on a "twin" of an L2 case. The twin has the young releases made old (the old code then picks them
# as the new code picks them with a pattern) and no `min-release-age-exclude` line. Usage: twin.sh <area/case> [UPDATE]
# The twin is in $TWIN (default /tmp/claude-1000/twin). Output: the twin expect files are in $TWIN/<area/case>/expect.
set -eu
ROOT=/home/george/dev/Karakatiza666/talon
TWIN=${TWIN:-/tmp/claude-1000/twin}
rm -rf "$TWIN/$1"; mkdir -p "$TWIN/$(dirname "$1")"
cp -a "$ROOT/tests/commands/cases/$1" "$TWIN/$1"
# young dates (2026-10-14, 2026-10-15) become old (2026-09-02)
# 2026-10-14 becomes 2026-09-02 and 2026-10-15 becomes 2026-09-03 (the time of the day stays), in the release lists only. `finish.sh` maps them back.
grep -rl 'published_at' "$TWIN/$1/fx" 2>/dev/null | grep -E "${TWIN_OWNERS:-/repos/(acme|roc-talon)/}" | xargs -r sed -i -E 's/"published_at":"2026-10-14/"published_at":"2026-09-02/g; s/"published_at":"2026-10-15/"published_at":"2026-09-03/g'
# the lines min-release-age-exclude stay: the old code warns about them, and finish.sh takes those warnings away
CASES=$TWIN UPDATE=1 L2BIN=$ROOT/.work/bin/l2 JOBS=2 "$ROOT/tests/commands/run.sh" "$(basename "$1")"
