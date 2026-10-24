#!/usr/bin/env bash
# Run `roc check` and `roc test` on each variant (copies of tests/unit/why.roc) and print the exit codes.
# Usage: research/check-speed/run.sh
. "$(dirname "$0")/../../scripts/env.sh"
cd "$ROOT" || exit 1
for f in clean warn_unused_var warn_unused_import err_type err_unknown_name; do
    "$ROC" check --no-cache research/check-speed/$f.roc > /dev/null 2>&1; c=$?
    "$ROC" test --no-cache research/check-speed/$f.roc > /dev/null 2>&1; t=$?
    echo "$f: check=$c test=$t"
done
