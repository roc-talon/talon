#!/usr/bin/env bash
# backup.sh <file>...: copy each file that exists to before/<same path> once (before the first change), or add it to NEW.txt when it does not exist (slice 054 boundary).
cd "$(dirname "$0")/../.." || exit 1
B=research/slice-054-revert/before
for f in "$@"; do
  if [ -e "$B/$f" ]; then continue; fi
  if [ -e "$f" ]; then mkdir -p "$B/$(dirname "$f")"; cp -a "$f" "$B/$f"; else grep -qxF "$f" "$B/NEW.txt" 2>/dev/null || echo "$f" >> "$B/NEW.txt"; fi
done
