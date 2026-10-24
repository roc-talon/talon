#!/bin/sh
# swap.sh ref|stub: copy the reference bodies or the stubs of slice 027 into cli/ (3 files). `diff -r` against the other set shows the difference.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
case "${1:-}" in ref) S=reference ;; stub) S=stubs ;; *) echo "usage: swap.sh ref|stub" >&2; exit 2 ;; esac
for f in cli/lib/Setup.roc cli/lib/Consent.roc cli/RealFiles.roc; do cp "$ROOT/research/slice-027-revert/$S/$f" "$ROOT/$f"; done
echo "cli/ now has the $S files"
