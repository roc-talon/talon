#!/usr/bin/env bash
# Runs the 5 mutations of slice 109b against the reference (W0 for m2 m4, W2 toolchains for all). Output: mutations.log
HERE=$(cd "$(dirname "$0")" && pwd)
: > "$HERE/mutations.log"
for m in m1-size-in-leaf m2-zero-size-accepted m3-size-after-published m4-fraction-size-accepted m5-later-put-rewrites-size; do
  echo "=== $m" >> "$HERE/mutations.log"
  w=w2; case $m in m2*|m4*|m3*) w=all;; esac
  MUTATE=$HERE/mutations/$m.py bash "$HERE/ref.sh" $w toolchains 2>&1 | grep -E "^(FAIL|w2:)|tests (passed|failed)|FAIL|PASSED|passed|failed|error" | cut -c1-220 >> "$HERE/mutations.log"
done
echo ALLDONE >> "$HERE/mutations.log"
