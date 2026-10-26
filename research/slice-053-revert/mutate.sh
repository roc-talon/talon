#!/bin/bash
# Slice 053 revert check. Usage: research/slice-053-revert/mutate.sh <id>   (it builds a mutated copy of cli/ in research/slice-053-revert/mut/ and runs the L4 case ex2 with it)
# mut/ is a copy of cli/ and packages/ made at the start. The mutation is one edit of one line (docs/slices/053-p1-exit.md section 10). The original is copied back from `cli/` after each run.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
M=$HERE/mut
id=$1
[ -d "$M/cli" ] || { mkdir -p "$M"; cp -a "$ROOT/cli" "$ROOT/packages" "$M/"; }
cp "$ROOT/cli/RealFiles.roc" "$M/cli/RealFiles.roc"
cp "$ROOT/cli/lib/Gc.roc" "$M/cli/lib/Gc.roc"
cp "$ROOT/cli/lib/CacheGc.roc" "$M/cli/lib/CacheGc.roc"
cp "$ROOT/cli/lib/Explain.roc" "$M/cli/lib/Explain.roc"
cp "$ROOT/cli/lib/Pick.roc" "$M/cli/lib/Pick.roc"
python3 -I "$HERE/mutate.py" "$id" "$M"
mkdir -p "$HERE/bin-$id"
"$ROC" build "$M/cli/main.roc" --no-cache --opt="${OPT:-dev}" --output="$HERE/bin-$id/tln" > "$HERE/bin-$id.log" 2>&1 || { echo "build failed"; tail -5 "$HERE/bin-$id.log"; exit 1; }
