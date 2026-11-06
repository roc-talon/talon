#!/usr/bin/env bash
# Runs the W2 mutations of mutations/ (3 at a time) on the private reference. Logs: mut-<m>.log. Usage: run-mutations.sh m1 m3 ...
cd "$(dirname "$0")" || exit 1
n=0
for m in "$@"; do
  ( MUTATE=mutations/$m.py ./ref.sh w2 publish/ > mut-$m.log 2>&1; rm -rf refbuild-$m ) &
  n=$((n + 1))
  [ $((n % 3)) -eq 0 ] && wait
done
wait
echo finished > mut-done.txt
