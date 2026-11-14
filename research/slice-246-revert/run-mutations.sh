#!/usr/bin/env bash
# Usage: run-mutations.sh m1 m3 ...   One at a time, each with a time limit and a memory cap (machine rules). Logs: mut-<m>.log
HERE=$(cd "$(dirname "$0")" && pwd)
for m in "$@"; do
  systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 env MUTATE=mutations/$m.py "$HERE/ref.sh" all > "$HERE/mut-$m.log" 2>&1
  echo "$m exit $?" >> "$HERE/mut-done.txt"
  rm -rf "$HERE/refbuild-$m"
done
