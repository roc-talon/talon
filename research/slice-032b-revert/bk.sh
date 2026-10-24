#!/usr/bin/env bash
# Copy each file or dir to research/slice-032b-revert/before/<same path> once (before the first change of the slice).
cd "$(dirname "$0")/../.." || exit 1
for f in "$@"; do
  d=research/slice-032b-revert/before/$f
  [ -e "$d" ] && continue
  mkdir -p "$(dirname "$d")"
  cp -a "$f" "$d"
done
