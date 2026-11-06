#!/usr/bin/env bash
# Copies each given path (relative to the repo root) to before/<path>, once. Usage: bk.sh path...
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
for p in "$@"; do
  d="$ROOT/research/slice-122-revert/before/$p"
  if [ -d "$ROOT/$p" ]; then [ -e "$d" ] || { mkdir -p "$(dirname "$d")"; cp -r "$ROOT/$p" "$d"; }
  elif [ -e "$ROOT/$p" ]; then [ -e "$d" ] || { mkdir -p "$(dirname "$d")"; cp "$ROOT/$p" "$d"; }
  fi
done
