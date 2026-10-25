#!/usr/bin/env bash
# Run `roc test` on each file of a list (one path per line, relative to the repo root) and print the sum of the tests that roc reports ("All (N) tests passed").
# Usage: count-roc-tests.sh <list-file>. Prints "<file> <N>" for each file and "total <N>", and "not-passed <n>" for the files that did not pass.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
cd "$ROOT" || exit 1
out=$(mktemp -d)
export ROC out
tr '\n' '\0' < "$1" | xargs -0 -P 12 -I{} bash -c 'n=${1//\//_}; "$ROC" test "$1" --no-cache --jobs=1 > "$out/$n.log" 2>&1; echo $? > "$out/$n.rc"' _ {}
total=0; bad=0
while read -r f; do
    n=${f//\//_}
    c=$(grep -ho 'All ([0-9]*) tests passed' "$out/$n.log" | grep -o '[0-9]*' | head -n 1)
    [ "$(cat "$out/$n.rc")" = 0 ] || bad=$((bad + 1))
    echo "$f ${c:-0}"
    total=$((total + ${c:-0}))
done < "$1"
echo "total $total"
echo "not-passed $bad"
rm -rf "$out"
