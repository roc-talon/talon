#!/usr/bin/env bash
# swap.sh stub|check: put the stub files of slice 055 into cli/lib, or list the files of cli/lib that differ from the stubs (run from anywhere).
# (The private reference was deleted at the review, 2026-10-24.)
cd "$(dirname "$0")/../.." || exit 1
R=research/slice-055-revert
case "${1:-}" in
  stub) (cd $R/stubs && find . -type f | sort) | while read -r f; do cp "$R/stubs/$f" "$f"; done ;;
  check) (cd $R/stubs && find . -type f | sort | while read -r f; do cmp -s "$f" "../../../$f" || echo "differs: $f"; done) ;;
  *) echo "usage: swap.sh stub|check"; exit 2 ;;
esac
