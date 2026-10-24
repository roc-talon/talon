#!/bin/bash
# Slice 039c: put the private reference (ref) or the stubs (stub) in the tree.
# ref : each file of research/slice-039c-revert/reference/ is copied over the file of the tree.
# stub: each file of reference/ gets the file of stubs/ (the stub with the docs), else the file of before/ (the old file).
# Usage: research/slice-039c-revert/flip.sh ref|stub
cd "$(dirname "$0")/../.." || exit 1
R=research/slice-039c-revert
case "${1:-}" in
  ref) ( cd $R/reference && find . -type f | sort ) | while read -r f; do cp -a "$R/reference/$f" "$f"; done ;;
  stub) ( cd $R/reference && find . -type f | sort ) | while read -r f; do
          if [ -f "$R/stubs/$f" ]; then cp -a "$R/stubs/$f" "$f"; else cp -a "$R/before/$f" "$f"; fi
        done ;;
  *) echo "usage: flip.sh ref|stub"; exit 2 ;;
esac
