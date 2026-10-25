#!/usr/bin/env bash
# swap.sh stub|check: put the stub files of slice 054 into cli/lib, or compare the tree with them (run from anywhere).
# stub: each file that has a stub gets the stub. Each other file of before/cli/lib (a file that the slice changes and has no stub) gets the state before the slice.
# check: lists the files of cli/lib that differ from the stubs, and from before/ for a file with no stub.
# (The private reference was deleted at the review, 2026-10-24.)
cd "$(dirname "$0")/../.." || exit 1
R=research/slice-054-revert
case "${1:-}" in
  stub)
    (cd $R/stubs && find . -type f | sort) | while read -r f; do cp "$R/stubs/$f" "$f"; done
    (cd $R/before && find ./cli/lib -type f | sort) | while read -r f; do [ -e "$R/stubs/$f" ] || cp "$R/before/$f" "$f"; done ;;
  check)
    (cd $R/stubs && find . -type f | sort | while read -r f; do cmp -s "$f" "../../../$f" || echo "differs: $f"; done)
    (cd $R/before && find ./cli/lib -type f | sort | while read -r f; do [ -e "../stubs/$f" ] || cmp -s "$f" "../../../$f" || echo "differs from before: $f"; done) ;;
  *) echo "usage: swap.sh stub|check"; exit 2 ;;
esac
