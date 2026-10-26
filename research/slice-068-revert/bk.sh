#!/usr/bin/env bash
# bk.sh <path>...: copy each existing file (or dir) to before/<path> once, before the first change (slice 068). A path that does not exist goes to before/NEW.txt (a dir: add its files).
cd "$(dirname "$0")/../.." || exit 1
B=research/slice-068-revert/before
for p in "$@"; do
  if [ -e "$p" ]; then
    [ -e "$B/$p" ] || { mkdir -p "$B/$(dirname "$p")"; cp -a "$p" "$B/$p"; }
  else
    grep -qxF "$p" "$B/NEW.txt" 2>/dev/null || echo "$p" >> "$B/NEW.txt"
  fi
done
