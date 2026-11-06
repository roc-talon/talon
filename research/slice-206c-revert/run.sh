#!/bin/bash
# Revert check of slice 206c: each mutation replaces cli/lib/ClosureIndex.roc, l0-8 runs, the file is restored.
cd "$(dirname "$0")/../.." || exit 1; . scripts/env.sh
T=cli/lib/ClosureIndex.roc; D=research/slice-206c-revert
cp $T $D/.saved

cp $D/reference/ClosureIndex.roc $T; r=$("$ROC" test tests/unit/l0-8.roc 2>&1 | grep -c "✗ fail"); echo "reference: failing=$r" > $D/results.txt
i=1; while IFS= read -r n; do cp $D/m$i.roc $T; r=$("$ROC" test tests/unit/l0-8.roc 2>&1 | grep -c "✗ fail"); echo "$n: failing=$r" >> $D/results.txt; i=$((i+1)); done < $D/names.txt
cp $D/.saved $T; rm $D/.saved
