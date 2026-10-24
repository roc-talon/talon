#!/bin/bash
# Slice 039b: copy a file to research/slice-039b-revert/before/<same path> once (before the first change). A new file goes to NEW.txt.
# Usage: research/slice-039b-revert/bk.sh <path> [<path> ...]   (paths relative to the repo root)
cd "$(dirname "$0")/../.." || exit 1
B=research/slice-039b-revert/before
for f in "$@"; do
  if [ -e "$f" ]; then
    [ -e "$B/$f" ] || { mkdir -p "$B/$(dirname "$f")"; cp -a "$f" "$B/$f"; }
  else
    grep -qxF "$f" "$B/NEW.txt" 2>/dev/null || { mkdir -p "$B"; echo "$f" >> "$B/NEW.txt"; }
  fi
done
