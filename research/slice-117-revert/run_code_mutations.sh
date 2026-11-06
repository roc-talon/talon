#!/usr/bin/env bash
# TW12 revert check of the real code (slice 117): one build for each mutation, on a copy of worker/. Output: mutations/code-results.txt. Usage: run_code_mutations.sh name...
cd "$(dirname "$0")"
: > mutations/code-results.txt
for m in "$@"; do
  echo "== $m" >> mutations/code-results.txt
  NOREF=1 ROC_MUT=$m MUTATE_PY=$PWD/mutations/code.py ./ref.sh all account 2>&1 | grep "^PASS\|^FAIL\|w2:\|occurs\|error\|passed\|failed\|Compilation" >> mutations/code-results.txt
done
echo done >> mutations/code-results.txt
