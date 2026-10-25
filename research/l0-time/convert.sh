#!/usr/bin/env bash
# Convert each unit app file tests/unit/<x>.roc into the type module tests/unit/<X>Test.roc: the line `app [...]` goes away, and the line `main! = |_args| Ok({})` becomes the
# type line `<X>Test :: [].{}` (a headerless file must define the type of its file name). No other line changes. The old file is moved (copies are in research/l0-time/before/tests/unit/).
set -eu
cd "$(dirname "$0")/../.."
for f in tests/unit/[a-z]*.roc; do
    b=$(basename "$f" .roc)
    M="$(tr a-z A-Z <<< "${b:0:1}")${b:1}Test"
    grep -q '^app \[main!\] { lib: "../../cli/lib/main.roc" }$' "$f" || { echo "bad header: $f"; exit 1; }
    [ "$(grep -c '^main! = |_args| Ok({})$' "$f")" = 1 ] || { echo "bad main!: $f"; exit 1; }
    awk -v M="$M" 'NR == 1 { getline; next } /^main! = \|_args\| Ok\(\{\}\)$/ { print M " :: [].{}"; next } { print }' "$f" > "tests/unit/$M.roc"
    rm "$f"
done
