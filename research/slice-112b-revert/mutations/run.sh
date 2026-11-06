#!/usr/bin/env bash
# Runs each mutation (5 at a time); each must make W0 or W2 (ingest-limits) fail. Output: mutations/out/<m>.log, a summary line for each.
HERE=$(cd "$(dirname "$0")/.." && pwd)
run() { m=$1; MUTATE=mutations/$m.py W0_TAIL=400 "$HERE/ref.sh" all ingest-limits > "$HERE/mutations/out/$m.log" 2>&1; rc=$?; if [ $rc -ne 0 ]; then echo "$m: caught ($(grep -cE '^FAIL|✗ fail' "$HERE/mutations/out/$m.log") failures)"; else echo "$m: NOT CAUGHT"; fi; rm -rf "$HERE/refbuild-$m"; }
export -f run; export HERE
ls "$HERE/mutations" | sed -n 's/\.py$//p' | xargs -P 5 -I{} bash -c 'run {}'
