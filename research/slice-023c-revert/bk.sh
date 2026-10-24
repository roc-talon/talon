#!/usr/bin/env bash
# Copy each file to research/slice-023c-revert/before/<same path> once (before the first change of the slice).
cd "$(dirname "$0")/../.." || exit 1
for f in "$@"; do
  d=research/slice-023c-revert/before/$f
  [ -e "$d" ] && continue
  mkdir -p "$(dirname "$d")"
  cp -a "$f" "$d"
done
