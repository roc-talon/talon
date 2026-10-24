#!/bin/sh
# swap.sh ref|stub: copy the reference bodies or the stubs of slice 028b into cli/ (Gc, CacheGc, RealFiles, Toolchain).
# The reference is private (the manager deletes it). `diff -r reference stubs` shows the difference.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
case "${1:-}" in ref) S=reference ;; stub) S=stubs ;; *) echo "usage: swap.sh ref|stub" >&2; exit 2 ;; esac
for f in cli/lib/Gc.roc cli/lib/CacheGc.roc cli/RealFiles.roc cli/lib/Toolchain.roc; do cp "$ROOT/research/slice-028b-revert/$S/$f" "$ROOT/$f"; done
echo "cli has the $S files"
