#!/bin/sh
# swap.sh ref|stub: copy the reference bodies or the stubs of slice 028 into cli/lib/ (4 files: Gc, CacheGc, Intent, Temp).
# Run.roc, main.roc, Base.roc and ResolveBase.roc are the same in both sets. `diff -r` against the other set shows the difference.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
case "${1:-}" in ref) S=reference ;; stub) S=stubs ;; *) echo "usage: swap.sh ref|stub" >&2; exit 2 ;; esac
for f in cli/lib/Gc.roc cli/lib/CacheGc.roc cli/lib/Intent.roc cli/lib/Temp.roc; do cp "$ROOT/research/slice-028-revert/$S/$f" "$ROOT/$f"; done
echo "cli/lib has the $S files"
