#!/usr/bin/env bash
# swap.sh stub|check: put the stub files of slice 043 into cli/lib (run from anywhere). `check` compares the tree with the stubs.
cd "$(dirname "$0")/../.." || exit 1
R=research/slice-043-revert
case "${1:-}" in
  stub) src=$R/stubs ;;
  check) (cd $R/stubs && find . -type f | sort | while read -r f; do cmp -s "$f" "../../../$f" || echo "differs: $f"; done); exit 0 ;;
  *) echo "usage: swap.sh stub|check"; exit 2 ;;
esac
(cd "$src" && find . -type f | sort) | while read -r f; do cp "$src/$f" "$f"; done
