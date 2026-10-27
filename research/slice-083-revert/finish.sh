#!/usr/bin/env bash
# Test-agent helper of slice 083: copy the expect files of the twin run to the real case. The dates of the twin are mapped back (2026-09-02 -> 2026-10-14, 2026-09-03 -> 2026-10-15).
# The notes are added by hand after this (the design text), so the new files are the design output, not the output of the old code. Usage: finish.sh <area/case>
set -eu
ROOT=/home/george/dev/Karakatiza666/talon
TWIN=${TWIN:-/tmp/claude-1000/twin}
mkdir -p "$ROOT/tests/commands/cases/$1/expect"
for f in stdout stderr exit calls.log tree.diff; do
    if [ -f "$TWIN/$1/expect/$f" ]; then
        { sed -E 's/2026-09-02/2026-10-14/g; s/2026-09-03/2026-10-15/g' "$TWIN/$1/expect/$f" | grep -v 'warning: .*unknown key .*min-release-age-exclude' || true; } > "$ROOT/tests/commands/cases/$1/expect/$f"
    fi
done
