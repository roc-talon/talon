#!/usr/bin/env bash
# Runs the mutations one after the other (a build for each, 1 to 2 min). Output: mutations/w2-results.txt. Usage: run_w2_mutations.sh name...
cd "$(dirname "$0")"
: > mutations/w2-results.txt
for m in "$@"; do
  echo "== $m" >> mutations/w2-results.txt
  ROC_MUT=$m MUTATE_PY=$PWD/mutations/roc.py ./ref.sh all account 2>&1 | grep "^PASS\|^FAIL\|w2:\|is not in\|error\|passed\|failed" >> mutations/w2-results.txt
done
echo done >> mutations/w2-results.txt
